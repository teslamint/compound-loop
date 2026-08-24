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

SCHEMA_VERSION = "release-loop/v1"
FEATURE_PATTERN = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")
PHASES = frozenset(("design", "plan", "implement", "review", "ship", "retro", "done", "blocked"))
PHASE_STATUSES = frozenset(("in-progress", "waiting-user", "blocked", "complete"))
TEST_FAILURE_ENV = "RUN_ARTIFACT_INTEGRITY_TEST_FAIL"
TEST_FAILURES = frozenset(("archive-after-first", "archive-after-journal", "handoff-after-marker", "publish-before-final"))


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
    rel = repo_relative(relative)
    if rel == PurePosixPath(".release-loop/progress.md"):
        path = guard(repo, relative, ".release-loop")
        expected_root = ".release-loop"
    elif (
        len(rel.parts) == 4
        and rel.parts[:2] == (".release-loop", "runs")
        and rel.name == "progress.md"
    ):
        scope = PurePosixPath(*rel.parts[:-1]).as_posix()
        path = guard(repo, relative, scope)
        expected_root = scope
    else:
        reject("path boundary", f"invalid progress path {relative}")
    values, text = frontmatter(path)
    if values.get("artifact_root") != expected_root:
        reject("path boundary", f"artifact_root {values.get('artifact_root', '')}")
    if expected_root != ".release-loop":
        scope_feature = rel.parts[2]
        if values.get("feature") != scope_feature:
            reject("invalid progress", f"feature does not match scope {scope_feature}")
    if expected_feature is not None and values.get("feature") != expected_feature:
        reject("invalid progress", f"feature does not match {expected_feature}")
    return path, values, text


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


def validate_archive_publication(
    repo: Path,
    source_root: str,
    destination_root: str,
) -> Path:
    states = []
    for root in (source_root, destination_root):
        journal, _, state = read_phase_artifact_journal(repo, root)
        if journal.exists():
            states.append((root, journal, state))
    if len(states) > 1:
        reject("archive destination conflict", "publisher journal exists in source and destination")
    if not states:
        return guard(repo, f"{source_root}/{JOURNAL_NAME}", source_root)
    journal_root, journal, state = states[0]
    validate_phase_artifact_pending(repo, journal_root, state)
    if state["pending"] is not None:
        reject("archive destination conflict", "pending publication requires recovery or compensation")
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
    return journal


def archive(
    repo: Path,
    progress_path: str,
    destination: str | None = None,
) -> tuple[str, list[str], str]:
    repo = repo.resolve(strict=True)
    inject_after_first = test_failure("archive-after-first")
    inject_after_journal = test_failure("archive-after-journal")
    progress_file, values, text = validate_progress(repo, progress_path)
    mode, stored = archive_evidence(text)
    if destination is not None:
        guard(repo, destination, ".release-loop/archive")
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
    if stored is not None and destination is not None and stored != destination:
        reject("archive destination conflict", f"stored={stored} requested={destination}")
    selected = stored
    destination_path = guard(repo, selected, ".release-loop/archive")
    source_rel = values["artifact_root"]
    journal = validate_archive_publication(repo, source_rel, selected)
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
    destination_path.mkdir(parents=True, exist_ok=True)
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
