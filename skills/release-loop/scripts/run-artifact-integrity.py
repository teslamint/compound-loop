#!/usr/bin/env python3
"""Validate and perform repository-local release-loop artifact transitions."""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path, PurePosixPath

from phase_artifact_core import ArtifactBlocked
from phase_artifact_core import JOURNAL_NAME
from phase_artifact_core import compensate as compensate_phase_artifact
from phase_artifact_core import git_tracked as phase_artifact_git_tracked
from phase_artifact_core import publish as publish_phase_artifact
from phase_artifact_core import read_journal as read_phase_artifact_journal
from phase_artifact_core import sha256 as phase_artifact_sha256
from phase_artifact_core import validate_pending_files as validate_phase_artifact_pending
from phase_artifact_core import write_journal as write_phase_artifact_journal

SCHEMA_VERSION = "release-loop/v1"
ARCHIVE_MANIFEST_NAME = ".archive-source-manifest.json"
ARCHIVE_MANIFEST_SOURCE = ".tmp/archive-source-manifest.tmp"
ARCHIVE_MANIFEST_SCHEMA = "archive-source-manifest/v1"
FEATURE_PATTERN = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")
PHASES = frozenset(("design", "plan", "implement", "review", "ship", "retro", "done", "blocked"))
PHASE_STATUSES = frozenset(("in-progress", "waiting-user", "blocked", "complete"))
TEST_FAILURE_ENV = "RUN_ARTIFACT_INTEGRITY_TEST_FAIL"
TEST_FAILURES = frozenset((
    "archive-after-first",
    "archive-after-journal",
    "archive-after-manifest-prepare",
    "archive-after-manifest-final",
    "handoff-after-marker",
    "publish-before-final",
))


class Blocked(RuntimeError):
    """A named fail-closed result."""


class Parser(argparse.ArgumentParser):
    def error(self, message: str) -> None:
        raise Blocked(f"invalid arguments: {message}")


def reject(kind: str, detail: str) -> None:
    raise Blocked(f"{kind}: {detail}")


def repo_relative(value: str) -> PurePosixPath:
    path = PurePosixPath(value)
    if path.is_absolute() or not path.parts or ".." in path.parts:
        reject("path boundary", value)
    return path


def is_within(path: Path, root: Path) -> bool:
    try:
        path.relative_to(root)
    except ValueError:
        return False
    return True


def guard(repo: Path, relative: str, allowed_root: str, allow_root: bool = False) -> Path:
    repo = repo.resolve(strict=True)
    rel = repo_relative(relative)
    allowed_rel = repo_relative(allowed_root)
    if rel != allowed_rel and not is_within(Path(*rel.parts), Path(*allowed_rel.parts)):
        reject("path boundary", f"{relative} outside {allowed_root}")
    if rel == allowed_rel and not allow_root:
        reject("path boundary", f"{relative} must name a child of {allowed_root}")
    cursor = repo
    for part in rel.parts:
        cursor = cursor / part
        if cursor.is_symlink():
            reject("path boundary", f"symlink component {cursor.relative_to(repo).as_posix()}")
        if cursor.exists() and not is_within(cursor.resolve(), repo):
            reject("path boundary", f"outside repository {relative}")
    parent = cursor if cursor.exists() and cursor.is_dir() else cursor.parent
    if not is_within(parent.resolve(strict=False), repo):
        reject("path boundary", f"outside repository {relative}")
    return cursor


def frontmatter(path: Path) -> tuple[dict[str, str], str]:
    if path.is_symlink():
        reject("path boundary", f"symlink progress {path}")
    if not path.is_file():
        reject("invalid progress", str(path))
    text = path.read_text(encoding="utf-8")
    if not text.startswith("---\n") or "\n---\n" not in text[4:]:
        reject("invalid progress", str(path))
    block = text.split("---", 2)[1]
    values = {}
    for line in block.splitlines():
        if ":" not in line:
            continue
        key, value = line.split(":", 1)
        values[key.strip()] = value.strip()
    schema = values.get("schema", "")
    if schema != SCHEMA_VERSION:
        reject("unknown schema", schema or "missing")
    feature = values.get("feature", "")
    if not FEATURE_PATTERN.fullmatch(feature) or feature == "resume":
        reject("invalid progress", f"feature {feature!r}")
    return values, text


def validate_progress(
    repo: Path,
    relative: str,
    expected_feature: str | None = None,
) -> tuple[Path, dict[str, str], str]:
    path, expected_root, scope_feature = progress_location(repo, relative)
    values, text = frontmatter(path)
    if values.get("artifact_root") != expected_root:
        reject("path boundary", f"artifact_root {values.get('artifact_root', '')}")
    if scope_feature is not None and values.get("feature") != scope_feature:
        reject("invalid progress", f"feature does not match scope {scope_feature}")
    if expected_feature is not None and values.get("feature") != expected_feature:
        reject("invalid progress", f"feature does not match {expected_feature}")
    return path, values, text


def progress_location(repo: Path, relative: str) -> tuple[Path, str, str | None]:
    rel = repo_relative(relative)
    if rel == PurePosixPath(".release-loop/progress.md"):
        path = guard(repo, relative, ".release-loop")
        expected_root = ".release-loop"
        scope_feature = None
    elif (
        len(rel.parts) == 4
        and rel.parts[:2] == (".release-loop", "runs")
        and rel.name == "progress.md"
    ):
        scope = PurePosixPath(*rel.parts[:-1]).as_posix()
        path = guard(repo, relative, scope)
        expected_root = scope
        scope_feature = rel.parts[2]
    else:
        reject("path boundary", f"invalid progress path {relative}")
    return path, expected_root, scope_feature


def git_tracked(repo: Path, relative: str) -> list[str]:
    result = subprocess.run(
        ("git", "ls-files", "--", relative),
        cwd=repo,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if result.returncode != 0:
        reject("artifact scope collision", "git index unavailable")
    return [line for line in result.stdout.splitlines() if line]


def filesystem_entries(repo: Path, scope: Path) -> list[str]:
    if not scope.exists():
        return []
    return [child.relative_to(repo).as_posix() for child in scope.rglob("*")]


def initialize(repo: Path, feature: str, selected: str | None = None) -> tuple[Path, str]:
    repo = repo.resolve(strict=True)
    if not FEATURE_PATTERN.fullmatch(feature) or feature == "resume":
        reject("invalid feature", feature)
    expected = f".release-loop/runs/{feature}/progress.md"
    relative = selected or expected
    repo_relative(relative)
    if relative != expected:
        reject("path boundary", f"progress path does not match run identity: {relative}")
    scope_rel = f".release-loop/runs/{feature}"
    target = guard(repo, relative, scope_rel)
    scope = target.parent
    fs_entries = filesystem_entries(repo, scope)
    tracked_entries = git_tracked(repo, scope_rel)
    collisions = sorted(set(fs_entries + tracked_entries))
    if target.is_file() and not target.is_symlink() and collisions == [relative] and not tracked_entries:
        validate_progress(repo, relative, feature)
        return target, "resume"
    if collisions:
        reject("artifact scope collision", ", ".join(collisions))
    scope.mkdir(parents=True, exist_ok=True)
    return target, "new"


def discover(repo: Path, exact: str | None = None) -> tuple[str, Path | None]:
    repo = repo.resolve(strict=True)
    records = []
    legacy = repo / ".release-loop/progress.md"
    if legacy.is_symlink():
        reject("path boundary", ".release-loop/progress.md")
    if legacy.exists():
        records.append(validate_progress(repo, ".release-loop/progress.md")[0])
    runs = repo / ".release-loop/runs"
    if runs.is_symlink():
        reject("path boundary", ".release-loop/runs")
    if runs.is_dir():
        for scope in sorted(runs.iterdir()):
            if scope.is_symlink():
                reject("path boundary", scope.relative_to(repo).as_posix())
            candidate = scope / "progress.md"
            if candidate.is_symlink():
                reject("path boundary", candidate.relative_to(repo).as_posix())
            if candidate.exists():
                relative = candidate.relative_to(repo).as_posix()
                records.append(validate_progress(repo, relative)[0])
    if exact is not None:
        selected = validate_progress(repo, exact)[0]
        if selected not in records:
            reject("invalid progress", exact)
        return "resume", selected
    if len(records) == 1:
        return "resume", records[0]
    if len(records) > 1:
        paths = ", ".join(path.relative_to(repo).as_posix() for path in records)
        reject("multiple valid live records require exact progress path", paths)
    return "new", None


def archive_evidence(text: str) -> tuple[str | None, str | None]:
    completed = re.findall(
        r"^- \d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z retro: archive-destination: (\S+)\s*$",
        text,
        re.MULTILINE,
    )
    incomplete = re.findall(
        r"^- \d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z archived-incomplete: archive-destination: (\S+)\s*$",
        text,
        re.MULTILINE,
    )
    if len(completed) + len(incomplete) > 1:
        reject("archive destination conflict", "multiple persisted archive markers")
    if completed:
        return "completed", completed[0]
    if incomplete:
        return "incomplete", incomplete[0]
    return None, None


def move_one(source: Path, destination: Path) -> None:
    target = destination / source.name
    if target.exists() or target.is_symlink():
        reject("archive destination conflict", target.as_posix())
    shutil.move(str(source), str(target))


def archive_manifest_entries(root: Path, children: list[Path]) -> list[dict[str, object]]:
    entries = []
    for child in children:
        paths = [child]
        if child.is_dir() and not child.is_symlink():
            paths.extend(sorted(child.rglob("*")))
        for path in paths:
            if path.is_symlink():
                reject("path boundary", f"symlink component {path}")
            relative = path.relative_to(root).as_posix()
            if path.is_dir():
                entries.append({"kind": "directory", "path": relative})
            elif path.is_file():
                entries.append({"kind": "file", "path": relative, "sha256": phase_artifact_sha256(path)})
            else:
                reject("archive destination conflict", f"unsupported source entry {relative}")
    return sorted(entries, key=lambda row: str(row["path"]))


def read_archive_manifest(path: Path) -> dict[str, object]:
    try:
        manifest = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        raise Blocked("archive destination conflict: invalid source manifest") from exc
    if (
        not isinstance(manifest, dict)
        or set(manifest) != {"schema", "entries"}
        or manifest.get("schema") != ARCHIVE_MANIFEST_SCHEMA
        or not isinstance(manifest.get("entries"), list)
    ):
        reject("archive destination conflict", "invalid source manifest")
    return manifest


def prepare_archive_manifest(
    source: Path,
    children: list[Path],
    progress: Path,
    destination: Path,
    journal: Path,
    journal_temporary: Path,
    publication: dict[str, object],
) -> None:
    manifest_path = destination / ARCHIVE_MANIFEST_NAME
    temporary = source / ARCHIVE_MANIFEST_SOURCE
    pending = publication["pending"]
    if pending is not None:
        expected = {"source": ARCHIVE_MANIFEST_SOURCE, "target": ARCHIVE_MANIFEST_NAME}
        if any(pending[key] != value for key, value in expected.items()):
            reject("archive destination conflict", "different pending publication")
        digest = pending["sha256"]
        source_exists = temporary.is_file() and not temporary.is_symlink()
        target_exists = manifest_path.is_file() and not manifest_path.is_symlink()
        if source_exists == target_exists:
            reject("archive destination conflict", "inconsistent manifest publication")
        candidate = temporary if source_exists else manifest_path
        if phase_artifact_sha256(candidate) != digest:
            reject("archive destination conflict", "archive manifest pending digest mismatch")
        if source_exists:
            os.replace(temporary, manifest_path)
        owned = dict(publication["owned"])
        recorded = owned.get(ARCHIVE_MANIFEST_NAME)
        if recorded is not None and recorded != digest:
            reject("archive destination conflict", "archive manifest ownership conflict")
        owned[ARCHIVE_MANIFEST_NAME] = digest
        write_phase_artifact_journal(
            journal,
            journal_temporary,
            {"schema": publication["schema"], "owned": owned, "pending": None},
        )
        publication["owned"] = owned
        publication["pending"] = None
    elif manifest_path.exists() or manifest_path.is_symlink():
        if manifest_path.is_symlink() or not manifest_path.is_file():
            reject("archive destination conflict", manifest_path.as_posix())
        recorded = publication["owned"].get(ARCHIVE_MANIFEST_NAME)
        if recorded != phase_artifact_sha256(manifest_path):
            reject("archive destination conflict", "archive manifest ownership mismatch")
        if temporary.exists() or temporary.is_symlink():
            reject("archive destination conflict", temporary.as_posix())
    else:
        if temporary.exists() or temporary.is_symlink():
            reject("archive destination conflict", temporary.as_posix())
        existing = list(destination.iterdir())
        if existing:
            reject("archive destination conflict", existing[0].as_posix())
        manifest_children = [child for child in children if child.name != JOURNAL_NAME]
        manifest = {"schema": ARCHIVE_MANIFEST_SCHEMA, "entries": archive_manifest_entries(source, [*manifest_children, progress])}
        temporary.parent.mkdir(parents=True, exist_ok=True)
        temporary.write_text(json.dumps(manifest, sort_keys=True, separators=(",", ":")) + "\n", encoding="utf-8")
        digest = phase_artifact_sha256(temporary)
        manifest_pending = {"source": ARCHIVE_MANIFEST_SOURCE, "target": ARCHIVE_MANIFEST_NAME, "sha256": digest}
        write_phase_artifact_journal(
            journal,
            journal_temporary,
            {"schema": publication["schema"], "owned": dict(publication["owned"]), "pending": manifest_pending},
        )
        publication["pending"] = manifest_pending
        if test_failure("archive-after-manifest-prepare"):
            reject("injected archive interruption", ARCHIVE_MANIFEST_NAME)
        os.replace(temporary, manifest_path)
        if test_failure("archive-after-manifest-final"):
            reject("injected archive interruption", ARCHIVE_MANIFEST_NAME)
        owned = dict(publication["owned"])
        if ARCHIVE_MANIFEST_NAME in owned:
            reject("archive destination conflict", "archive manifest ownership conflict")
        owned[ARCHIVE_MANIFEST_NAME] = digest
        write_phase_artifact_journal(
            journal,
            journal_temporary,
            {"schema": publication["schema"], "owned": owned, "pending": None},
        )
        publication["owned"] = owned
        publication["pending"] = None
    manifest = read_archive_manifest(manifest_path)
    destination_children = [
        child
        for child in destination.iterdir()
        if child.name not in {ARCHIVE_MANIFEST_NAME, JOURNAL_NAME}
    ]
    source_children = [child for child in children if child.name != JOURNAL_NAME]
    source_entries = [*source_children, progress] if progress.exists() else source_children
    observed = archive_manifest_entries(source, source_entries) + archive_manifest_entries(destination, destination_children)
    observed.sort(key=lambda row: str(row["path"]))
    if observed != manifest["entries"]:
        reject("archive destination conflict", "source manifest mismatch")


def validate_archive_publication(
    repo: Path,
    source_root: str,
    destination_root: str,
) -> tuple[Path, Path, dict[str, object]]:
    states = []
    source_state = None
    for root in (source_root, destination_root):
        journal, temporary, state = read_phase_artifact_journal(repo, root)
        if root == source_root:
            source_state = (journal, temporary, state)
        if journal.exists():
            states.append((root, journal, temporary, state))
    if len(states) > 1:
        reject("archive destination conflict", "publisher journal exists in source and destination")
    if not states:
        assert source_state is not None
        return source_state
    journal_root, journal, temporary, state = states[0]
    pending = state["pending"]
    if pending is not None:
        archive_pending = (
            journal_root == source_root
            and pending["source"] == ARCHIVE_MANIFEST_SOURCE
            and pending["target"] == ARCHIVE_MANIFEST_NAME
        )
        if not archive_pending:
            validate_phase_artifact_pending(repo, journal_root, state)
            reject("archive destination conflict", "pending publication requires recovery or compensation")
        pending_source = guard(repo, f"{source_root}/{ARCHIVE_MANIFEST_SOURCE}", source_root)
        pending_target = guard(repo, f"{destination_root}/{ARCHIVE_MANIFEST_NAME}", destination_root)
        source_exists = pending_source.is_file() and not pending_source.is_symlink()
        target_exists = pending_target.is_file() and not pending_target.is_symlink()
        if source_exists == target_exists:
            reject("archive destination conflict", "inconsistent manifest publication")
        candidate = pending_source if source_exists else pending_target
        relative = candidate.relative_to(repo).as_posix()
        if phase_artifact_git_tracked(repo, relative) or phase_artifact_sha256(candidate) != pending["sha256"]:
            reject("archive destination conflict", "archive manifest pending digest mismatch")
    for key, expected in state["owned"].items():
        candidates = []
        for root in (source_root, destination_root):
            candidate = guard(repo, f"{root}/{key}", root)
            if candidate.exists() or candidate.is_symlink():
                candidates.append(candidate)
        if len(candidates) != 1:
            reject("artifact ownership", f"owned final invalid {key}")
        candidate = candidates[0]
        relative = candidate.relative_to(repo).as_posix()
        if (
            candidate.is_symlink()
            or not candidate.is_file()
            or phase_artifact_git_tracked(repo, relative)
            or phase_artifact_sha256(candidate) != expected
        ):
            reject("artifact ownership", f"owned final invalid {key}")
    return journal, temporary, state


def validate_archive_contract(
    repo: Path,
    values: dict[str, str],
    text: str,
    requested_destination: str | None,
) -> tuple[str, str]:
    mode, stored = archive_evidence(text)
    if requested_destination is not None:
        guard(repo, requested_destination, ".release-loop/archive")
    if stored is None:
        reject("archive destination conflict", "missing persisted destination")
    if mode == "completed":
        if values.get("phase") != "done" or values.get("phase_status") != "complete":
            reject("archive destination conflict", "missing persisted phase evidence")
    else:
        phase = values.get("phase")
        phase_status = values.get("phase_status")
        if phase not in PHASES:
            reject("archive destination conflict", f"invalid incomplete phase: {phase or 'missing'}")
        if phase_status not in PHASE_STATUSES:
            reject(
                "archive destination conflict",
                f"invalid incomplete phase_status: {phase_status or 'missing'}",
            )
        if phase == "done" or phase_status == "complete":
            reject("archive destination conflict", "incomplete marker requires nonterminal phase")
    if requested_destination is not None and stored != requested_destination:
        reject(
            "archive destination conflict",
            f"stored={stored} requested={requested_destination}",
        )
    if mode is None:
        reject("archive destination conflict", "missing persisted archive mode")
    return mode, stored


def recover_terminal_archive(
    repo: Path,
    progress_path: str,
    destination: str | None,
) -> tuple[str, list[str], str]:
    progress_file, source_rel, scope_feature = progress_location(repo, progress_path)
    if destination is None:
        reject("invalid progress", str(progress_file))
    destination_path = guard(repo, destination, ".release-loop/archive")
    archived_progress = guard(repo, f"{destination}/progress.md", destination)
    values, text = frontmatter(archived_progress)
    if values.get("artifact_root") != source_rel:
        reject("path boundary", f"artifact_root {values.get('artifact_root', '')}")
    if scope_feature is not None and values.get("feature") != scope_feature:
        reject("invalid progress", f"feature does not match scope {scope_feature}")
    mode, selected = validate_archive_contract(repo, values, text, destination)
    _, _, publication = validate_archive_publication(repo, source_rel, selected)
    if publication["pending"] is not None:
        reject("archive destination conflict", "terminal archive has pending publication")
    manifest = read_archive_manifest(destination_path / ARCHIVE_MANIFEST_NAME)
    destination_children = [
        child
        for child in destination_path.iterdir()
        if child.name not in {ARCHIVE_MANIFEST_NAME, JOURNAL_NAME}
    ]
    if archive_manifest_entries(destination_path, destination_children) != manifest["entries"]:
        reject("archive destination conflict", "source manifest mismatch")
    source = guard(repo, source_rel, source_rel, allow_root=True)
    if source_rel != ".release-loop" and source.exists():
        if not source.is_dir():
            reject("archive destination conflict", source.as_posix())
        remaining = list(source.iterdir())
        if remaining:
            reject("archive destination conflict", remaining[0].as_posix())
        source.rmdir()
    state = "archived" if mode == "completed" else "archived-incomplete"
    return selected, [], state


def archive(
    repo: Path,
    progress_path: str,
    destination: str | None = None,
) -> tuple[str, list[str], str]:
    repo = repo.resolve(strict=True)
    inject_after_first = test_failure("archive-after-first")
    inject_after_journal = test_failure("archive-after-journal")
    progress_file, _, _ = progress_location(repo, progress_path)
    if not progress_file.exists():
        return recover_terminal_archive(repo, progress_path, destination)
    progress_file, values, text = validate_progress(repo, progress_path)
    mode, selected = validate_archive_contract(repo, values, text, destination)
    destination_path = guard(repo, selected, ".release-loop/archive")
    source_rel = values["artifact_root"]
    journal, journal_temporary, publication = validate_archive_publication(repo, source_rel, selected)
    if source_rel == ".release-loop":
        guard(repo, progress_path, ".release-loop")
        source = repo / ".release-loop"
        children = []
        controls = (source / ".tmp", journal) if journal.parent == source else (source / ".tmp",)
        for child in controls:
            if child.exists() or child.is_symlink():
                guard(repo, child.relative_to(repo).as_posix(), ".release-loop")
                children.append(child)
        for name in ("briefs", "reports", "reviews", "evidence"):
            child = source / name
            if child.exists() or child.is_symlink():
                guard(repo, child.relative_to(repo).as_posix(), ".release-loop")
                children.append(child)
        for child in sorted(source.glob("progress.md.corrupt-*")):
            guard(repo, child.relative_to(repo).as_posix(), ".release-loop")
            children.append(child)
    else:
        source = guard(repo, source_rel, source_rel, allow_root=True)
        children = [child for child in sorted(source.iterdir()) if child.name != "progress.md"]
        for child in children:
            guard(repo, child.relative_to(repo).as_posix(), source_rel)
    archive_temporary_root = guard(repo, f"{source_rel}/.tmp", source_rel)
    manifest_owned = ARCHIVE_MANIFEST_NAME in publication["owned"]
    if not archive_temporary_root.exists() and not manifest_owned:
        archive_temporary_root.mkdir(parents=True, exist_ok=True)
    if archive_temporary_root.exists() and archive_temporary_root not in children:
        children.insert(0, archive_temporary_root)
    destination_path.mkdir(parents=True, exist_ok=True)
    prepare_archive_manifest(
        source,
        children,
        progress_file,
        destination_path,
        journal,
        journal_temporary,
        publication,
    )
    if journal.parent == source and journal.exists() and journal not in children:
        children.append(journal)
    order = []
    for child in children:
        move_one(child, destination_path)
        order.append(child.name)
        if inject_after_first:
            reject("injected archive interruption", child.name)
        if inject_after_journal and child.name == JOURNAL_NAME:
            reject("injected archive interruption", child.name)
    move_one(progress_file, destination_path)
    order.append("progress.md")
    if source_rel != ".release-loop":
        source.rmdir()
    state = "archived" if mode == "completed" else "archived-incomplete"
    return selected, order, state


def tree_manifest(root: Path) -> dict[str, bytes | None]:
    manifest = {}
    for path in sorted(root.rglob("*")):
        if path.is_symlink():
            reject("path boundary", f"symlink component {path}")
        relative = path.relative_to(root).as_posix()
        manifest[relative] = None if path.is_dir() else path.read_bytes()
    return manifest


def copy_missing(source: Path, target: Path) -> None:
    source_manifest = tree_manifest(source)
    target_manifest = tree_manifest(target) if target.exists() else {}
    extras = sorted(set(target_manifest) - set(source_manifest))
    mismatches = sorted(
        key
        for key in set(target_manifest) & set(source_manifest)
        if target_manifest[key] != source_manifest[key]
    )
    if extras or mismatches:
        reject("handoff target mismatch", ", ".join(extras + mismatches))
    target.mkdir(parents=True, exist_ok=True)
    for relative, data in source_manifest.items():
        destination = target / relative
        if data is None:
            destination.mkdir(parents=True, exist_ok=True)
        elif relative not in target_manifest:
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_bytes(data)


def handoff(
    repo: Path,
    base_repo: Path,
    progress_path: str,
    marker_path: str | None = None,
) -> tuple[Path, Path]:
    repo = repo.resolve(strict=True)
    base_repo = base_repo.resolve(strict=True)
    if repo == base_repo:
        reject("handoff owner conflict", "source and base resolve to same checkout")
    inject_after_marker = test_failure("handoff-after-marker")
    progress_file, values, _ = validate_progress(repo, progress_path)
    artifact_root = values["artifact_root"]
    if artifact_root == ".release-loop":
        reject("path boundary", "legacy handoff requires an explicit legacy destination contract")
    source = guard(repo, artifact_root, artifact_root, allow_root=True)
    run_id = values["feature"]
    marker_relative = marker_path or f".release-loop/.handoff/{run_id}.json"
    marker = guard(base_repo, marker_relative, ".release-loop/.handoff")
    destination = guard(
        base_repo,
        artifact_root,
        f".release-loop/runs/{run_id}",
        allow_root=True,
    )
    expected = {
        "schema": "release-loop-handoff/v1",
        "feature": run_id,
        "progress_path": progress_file.relative_to(repo).as_posix(),
        "artifact_root": artifact_root,
        "source_worktree": str(repo),
        "base_owner": str(base_repo),
        "destination": artifact_root,
    }
    if marker.exists():
        try:
            observed = json.loads(marker.read_text(encoding="utf-8"))
        except (OSError, UnicodeError, json.JSONDecodeError):
            reject("handoff owner mismatch", marker_relative)
        if any(observed.get(key) != value for key, value in expected.items()):
            reject("handoff owner mismatch", marker_relative)
    else:
        marker.parent.mkdir(parents=True, exist_ok=True)
        marker.write_text(
            json.dumps({**expected, "status": "incomplete"}, sort_keys=True) + "\n",
            encoding="utf-8",
        )
    if inject_after_marker:
        reject("injected handoff interruption", marker_relative)
    copy_missing(source, destination)
    if tree_manifest(source) != tree_manifest(destination):
        reject("handoff target mismatch", artifact_root)
    state, selected = discover(base_repo, f"{artifact_root}/progress.md")
    if state != "resume" or selected != destination / "progress.md":
        reject("handoff resume verification", artifact_root)
    marker.write_text(
        json.dumps({**expected, "status": "complete"}, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    return marker, selected


def test_failure(name: str) -> bool:
    selected = os.environ.get(TEST_FAILURE_ENV)
    if selected is not None and selected not in TEST_FAILURES:
        reject("invalid test failure", selected)
    return selected == name


def parser() -> Parser:
    root = Parser(description=__doc__)
    subparsers = root.add_subparsers(dest="command", required=True)

    initialize_parser = subparsers.add_parser("initialize")
    initialize_parser.add_argument("--repo", required=True)
    initialize_parser.add_argument("--feature", required=True)
    initialize_parser.add_argument("--progress-path")

    discover_parser = subparsers.add_parser("discover")
    discover_parser.add_argument("--repo", required=True)
    discover_parser.add_argument("--progress-path")

    archive_parser = subparsers.add_parser("archive")
    archive_parser.add_argument("--repo", required=True)
    archive_parser.add_argument("--progress-path", required=True)
    archive_parser.add_argument("--destination")

    handoff_parser = subparsers.add_parser("handoff")
    handoff_parser.add_argument("--repo", required=True)
    handoff_parser.add_argument("--base-repo", required=True)
    handoff_parser.add_argument("--progress-path", required=True)
    handoff_parser.add_argument("--marker-path")

    publish_parser = subparsers.add_parser("publish")
    publish_parser.add_argument("--repo", required=True)
    publish_parser.add_argument("--progress-path", required=True)
    publish_parser.add_argument("--source", required=True)
    publish_parser.add_argument("--target", required=True)

    compensate_parser = subparsers.add_parser("compensate")
    compensate_parser.add_argument("--repo", required=True)
    compensate_parser.add_argument("--progress-path", required=True)
    return root


def execute(arguments: argparse.Namespace) -> dict[str, object]:
    repo = Path(arguments.repo).resolve(strict=True)
    if arguments.command == "initialize":
        progress, state = initialize(repo, arguments.feature, arguments.progress_path)
        return {
            "artifact_root": progress.parent.relative_to(repo).as_posix(),
            "progress_path": progress.relative_to(repo).as_posix(),
            "state": state,
        }
    if arguments.command == "discover":
        state, progress = discover(repo, arguments.progress_path)
        return {
            "progress_path": None if progress is None else progress.relative_to(repo).as_posix(),
            "state": state,
        }
    if arguments.command == "archive":
        archive_path, moved, state = archive(
            repo,
            arguments.progress_path,
            arguments.destination,
        )
        return {
            "archive_path": archive_path,
            "moved": moved,
            "progress_path": f"{archive_path}/progress.md",
            "state": state,
        }
    if arguments.command == "handoff":
        base_repo = Path(arguments.base_repo).resolve(strict=True)
        marker, progress = handoff(
            repo,
            base_repo,
            arguments.progress_path,
            arguments.marker_path,
        )
        return {
            "cleanup_permitted": True,
            "marker_path": marker.relative_to(base_repo).as_posix(),
            "progress_path": progress.relative_to(base_repo).as_posix(),
            "state": "complete",
        }
    if arguments.command == "publish":
        target, digest, state = publish_phase_artifact(
            repo,
            arguments.progress_path,
            arguments.source,
            arguments.target,
        )
        return {
            "progress_path": arguments.progress_path,
            "sha256": digest,
            "state": state,
            "target": target.relative_to(repo).as_posix(),
        }
    if arguments.command == "compensate":
        state = compensate_phase_artifact(repo, arguments.progress_path)
        return {"progress_path": arguments.progress_path, "state": state}
    reject("invalid arguments", f"unknown command {arguments.command}")


def main() -> int:
    try:
        arguments = parser().parse_args()
        payload = execute(arguments)
    except (Blocked, ArtifactBlocked, OSError, UnicodeError) as exc:
        message = str(exc)
        if not isinstance(exc, (Blocked, ArtifactBlocked)):
            message = f"filesystem error: {message}"
        print(message, file=sys.stderr)
        return 1
    print(json.dumps(payload, sort_keys=True, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
