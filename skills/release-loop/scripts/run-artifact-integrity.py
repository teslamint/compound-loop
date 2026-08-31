#!/usr/bin/env python3
"""Validate and perform repository-local release-loop artifact transitions."""

from __future__ import annotations

import argparse
import fcntl
import hashlib
import json
import os
import re
import shutil
import stat
import subprocess
import sys
import time
from collections.abc import Callable
from datetime import datetime, timezone
from pathlib import Path, PurePosixPath

from phase_artifact_core import JOURNAL_NAME, ArtifactBlocked
from phase_artifact_core import canonical_artifact_key as canonical_phase_artifact_key
from phase_artifact_core import compensate as compensate_phase_artifact
from phase_artifact_core import git_tracked as phase_artifact_git_tracked
from phase_artifact_core import publish as publish_phase_artifact
from phase_artifact_core import read_journal as read_phase_artifact_journal
from phase_artifact_core import sha256 as phase_artifact_sha256
from phase_artifact_core import (
    validate_pending_files as validate_phase_artifact_pending,
)
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
    "handoff-after-copy-one",
    "publish-before-final",
    "recovery-backup-create",
    "recovery-before-copy-ancestor",
    "recovery-after-g0",
    "recovery-after-receipt",
    "recovery-after-g1",
    "recovery-after-g2",
    "recovery-after-g3",
    "recovery-target-create-swap",
    "recovery-before-g1-ancestor",
    "recovery-before-cleanup-foreign",
    "recovery-before-copy-source-change",
    "recovery-after-cleanup-one",
    "recovery-progress-after-binding-swap",
    "recovery-reservation-temp-only",
    "recovery-archive-manifest-only",
    "recovery-archive-journal-only",
    "recovery-archive-payload-mid-file",
    "recovery-archive-before-progress",
    "recovery-receipt-temp-only",
    "recovery-progress-g1-temp-only",
    "recovery-progress-g2-temp-only",
    "recovery-progress-g3-temp-only",
    "recovery-after-gate-receipt",
    "recovery-after-destination-mkdir",
    "recovery-archive-payload-prefix-temp-only",
    "recovery-progress-before-replace-generation-change",
))

RECOVERY_AUTHORITY_ROOT = ".release-loop/recovery-authority"
RECOVERY_BACKUP_ROOT = ".release-loop/recovery-backups"
RECOVERY_REQUEST_SCHEMA = "legacy-archive-recovery-request/v1"
RECOVERY_GATE_RECEIPT_SCHEMA = "legacy-archive-recovery-gate-receipt/v1"
RECOVERY_APPROVAL_SCHEMA = "legacy-archive-recovery-approval/v1"
RECOVERY_INITIALIZATION_SCHEMA = "legacy-archive-recovery-initialization/v1"
RECOVERY_GATE_ID = "legacy-archive-recovery-approval"
RECOVERY_GATE_ANSWER_CLASS = "approve-exact-recovery-or-cancel"
LEGACY_DESTINATION = ".release-loop"
LEGACY_MARKER_SCHEMA = "release-loop-handoff/v2"
LEGACY_ACTIVE_ALL = frozenset(("progress.md", ".tmp", JOURNAL_NAME, "briefs", "reports", "reviews", "evidence", "v1"))
LEGACY_PERSISTENT_NAMES = frozenset((
    "archive", ".handoff", "runs", "recovery-authority", "recovery-backups",
))
LEGACY_MARKER_KEYS = frozenset((
    "schema", "feature", "progress_path", "artifact_root",
    "source_worktree", "base_owner", "destination", "manifest_sha256", "status",
))
LEGACY_MARKER_STATUSES = frozenset(("incomplete", "complete"))
SHA_PATTERN = re.compile(r"^[0-9a-f]{64}$")
RECOVERY_ID_PATTERN = FEATURE_PATTERN
RECOVERY_CONTROL_NAMES = frozenset((ARCHIVE_MANIFEST_NAME, JOURNAL_NAME))
RECOVERY_RESERVATION_NAME = ".legacy-archive-recovery-reservation.json"
RECOVERY_PROGRESS_TEMP_NAME = ".progress.md.recovery.tmp"
RECOVERY_TRANSIENT_NAMES = frozenset((RECOVERY_PROGRESS_TEMP_NAME,))
RECOVERY_ARCHIVE_CONTROL_NAMES = RECOVERY_CONTROL_NAMES | frozenset((RECOVERY_RESERVATION_NAME,))
RECOVERY_RESERVED_PAYLOAD_NAMES = frozenset((
    RECOVERY_RESERVATION_NAME,
    RECOVERY_RESERVATION_NAME + ".tmp",
    RECOVERY_PROGRESS_TEMP_NAME,
    ARCHIVE_MANIFEST_NAME + ".recovery.tmp",
    JOURNAL_NAME + ".recovery.tmp",
))
RECOVERY_TIMESTAMP_PATTERN = r"\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z"
DIRECTORY_OPEN_FLAGS = (
    os.O_RDONLY
    | getattr(os, "O_DIRECTORY", 0)
    | getattr(os, "O_NOFOLLOW", 0)
)
FILE_READ_FLAGS = os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0)
CONTRACT_HEADING_TOKEN = "releaseloopprearchiveverification"
CONTRACT_HEADING_RE = re.compile(
    r"^## Release-loop pre-archive verification V([1-9][0-9]*): (.+)$"
)
CONTRACT_V2_TITLE = "Verify the archived generation"
CONTRACT_V2_BODY = (
    "After Retro commits and archive evidence is staged, keep the live progress "
    "record nonterminal. Run the approved plan's V2 section against the exact "
    "persisted archive destination, tracked baseline, and matching handoff. "
    "Persist V2 acceptance and mark only that handoff consumed before setting "
    "`phase: done`. Move `progress.md` last. A missing marker, digest mismatch, "
    "incomplete generation, failed validation, or foreign destination leaves the "
    "loop live and resumable."
)
CONTRACT_INTRODUCTION_COMMIT = "08e12a82752847b3bead5a96fd251b4ad58eae1b"
V1_PRE_MERGE_KEYS = frozenset(("id", "status", "generation_sha256", "updated"))
V1_OWNERSHIP_PATHS = {
    "pilot_approval_path": ".release-loop/v1/pilot-approval.md",
    "pilot_receipt_path": ".release-loop/v1/pilot-receipt.md",
    "full_approval_path": ".release-loop/v1/full-approval.md",
    "full_receipt_path": ".release-loop/v1/full-receipt.md",
    "generation_receipt_path": ".release-loop/v1/generation-receipt.md",
    "generation_manifest_path": ".release-loop/v1/generation-manifest.sha256",
}
V1_OWNERSHIP_KEYS = frozenset((
    "status", *V1_OWNERSHIP_PATHS, "pilot_receipt_sha256", "full_receipt_sha256",
    "generation_manifest_sha256", "accepted_at",
))


class Blocked(RuntimeError):
    """A named fail-closed result."""


class Parser(argparse.ArgumentParser):
    def error(self, message: str) -> None:
        raise Blocked(f"invalid arguments: {message}")


def reject(kind: str, detail: str) -> None:
    raise Blocked(f"{kind}: {detail}")


def _ascii_heading_prefix(heading: str) -> str:
    return "".join(character.lower() for character in heading if character.isascii() and character.isalnum())


def _levenshtein(left: str, right: str) -> int:
    previous = list(range(len(right) + 1))
    for left_index, left_character in enumerate(left, 1):
        current = [left_index]
        for right_index, right_character in enumerate(right, 1):
            current.append(min(
                current[-1] + 1,
                previous[right_index] + 1,
                previous[right_index - 1] + (left_character != right_character),
            ))
        previous = current
    return previous[-1]


def _markdown_headings(text: str) -> list[tuple[int, int, str, str]]:
    lines = text.splitlines()
    headings: list[tuple[int, int, str, str]] = []
    fenced_lines: set[int] = set()
    fence_character: str | None = None
    fence_length = 0
    for line_number, line in enumerate(lines):
        if fence_character is not None:
            fenced_lines.add(line_number)
            closing = re.fullmatch(
                rf" {{0,3}}{re.escape(fence_character)}{{{fence_length},}}[ \t]*",
                line,
            )
            if closing is not None:
                fence_character = None
                fence_length = 0
            continue
        opening = re.match(r"^ {0,3}(`{3,}|~{3,})(.*)$", line)
        if opening is not None:
            marker, info = opening.groups()
            if marker[0] != "`" or "`" not in info:
                fenced_lines.add(line_number)
                fence_character = marker[0]
                fence_length = len(marker)

    for line_number, line in enumerate(lines):
        if line_number in fenced_lines:
            continue
        atx = re.match(r"^ {0,3}(#{1,6})[ \t]+(.+?)[ \t]*$", line)
        if atx is not None:
            _marker, content = atx.groups()
            headings.append((line_number, line_number + 1, line.lstrip(" "), content))
            continue
        if (
            line_number == 0
            or not re.fullmatch(r" {0,3}(?:=+|-+)[ \t]*", line)
            or line_number - 1 in fenced_lines
        ):
            continue
        title = lines[line_number - 1]
        if not title.strip() or len(title) - len(title.lstrip(" ")) > 3:
            continue
        headings.append((line_number - 1, line_number + 1, title.lstrip(" "), title.strip()))
    return sorted(headings, key=lambda heading: (heading[0], heading[1]))


def _contract_heading_candidates(text: str) -> list[tuple[int, int, str]]:
    candidates = []
    for line_number, body_start, heading, content in _markdown_headings(text):
        normalized = _ascii_heading_prefix(content)
        candidate = any(
            _levenshtein(CONTRACT_HEADING_TOKEN, normalized[:length]) <= 2
            for length in range(max(1, len(CONTRACT_HEADING_TOKEN) - 2), len(CONTRACT_HEADING_TOKEN) + 3)
            if len(normalized) >= length
        )
        if candidate:
            candidates.append((line_number, body_start, heading))
    return candidates


def _contract_body(text: str, heading_line: int, body_start: int) -> str:
    lines = text.splitlines()
    end = len(lines)
    for next_heading, _next_body, _heading, _content in _markdown_headings(text):
        if next_heading > heading_line:
            end = next_heading
            break
    return "\n".join(lines[body_start:end]).strip()


def classify_pre_archive_contract(text: str) -> dict[str, str | None]:
    """Classify the closed heading contract used by legacy recovery."""
    candidates = _contract_heading_candidates(text)
    if len(candidates) > 1:
        return {"classification": "duplicate", "parsed_version": None, "heading": None}
    if not candidates:
        return {"classification": "absent-legacy-shape", "parsed_version": None, "heading": None}
    line_number, body_start, heading = candidates[0]
    match = CONTRACT_HEADING_RE.fullmatch(heading)
    if match is None:
        return {"classification": "malformed", "parsed_version": None, "heading": heading}
    parsed_version, title = match.groups()
    if parsed_version != "2":
        return {"classification": "unsupported-version", "parsed_version": parsed_version, "heading": heading}
    if title != CONTRACT_V2_TITLE or _contract_body(text, line_number, body_start) != CONTRACT_V2_BODY:
        return {"classification": "unverifiable", "parsed_version": parsed_version, "heading": heading}
    return {"classification": "supported", "parsed_version": parsed_version, "heading": heading}


def repo_relative(value: str) -> PurePosixPath:
    path = PurePosixPath(value)
    if path.is_absolute() or not path.parts or ".." in path.parts:
        reject("path boundary", value)
    return path


def validate_recovery_payload_namespace(
    entries: list[dict[str, object]],
    *,
    failure_kind: str,
) -> None:
    for entry in entries:
        relative = entry.get("path")
        if not isinstance(relative, str):
            reject(failure_kind, "invalid recovery payload path")
        for name in PurePosixPath(relative).parts:
            reserved = (
                name in RECOVERY_RESERVED_PAYLOAD_NAMES
                or (
                    name.startswith(".legacy-archive-recovery-owner-")
                    and name.endswith(".json")
                )
                or (
                    name.startswith(".legacy-archive-recovery-pending-")
                    and name.endswith(".tmp")
                )
            )
            if reserved:
                reject(failure_kind, f"reserved recovery payload path {relative}")


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


def split_frontmatter(
    text: str,
    *,
    failure_kind: str,
    detail: str,
) -> tuple[str, str]:
    if not text.startswith("---\n"):
        reject(failure_kind, detail)
    closing = text.find("\n---\n", 4)
    if closing < 0:
        reject(failure_kind, detail)
    return text[3 : closing + 1], text[closing + 4 :]


def parse_frontmatter(
    text: str,
    source: str,
    *,
    duplicate_kind: str = "invalid progress",
) -> tuple[dict[str, str], str]:
    block, _body = split_frontmatter(
        text,
        failure_kind="invalid progress",
        detail=source,
    )
    values = {}
    for line in block.splitlines():
        if not line or line[0].isspace():
            continue
        if ":" not in line:
            continue
        key, value = line.split(":", 1)
        key = key.strip()
        if key in values:
            reject(duplicate_kind, f"duplicate top-level field {key}")
        values[key] = value.strip()
    schema = values.get("schema", "")
    if schema != SCHEMA_VERSION:
        reject("unknown schema", schema or "missing")
    feature = values.get("feature", "")
    if not FEATURE_PATTERN.fullmatch(feature) or feature == "resume":
        reject("invalid progress", f"feature {feature!r}")
    return values, text


def frontmatter(path: Path) -> tuple[dict[str, str], str]:
    if path.is_symlink():
        reject("path boundary", f"symlink progress {path}")
    if not path.is_file():
        reject("invalid progress", str(path))
    return parse_frontmatter(path.read_text(encoding="utf-8"), str(path))


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


def legacy_active_name(name: str) -> bool:
    return name in LEGACY_ACTIVE_ALL or name.startswith("progress.md.corrupt-")


def legacy_scan_children(repo: Path, container: Path, *, allow_persistent: bool) -> list[Path]:
    if not container.exists():
        return []
    children = []
    for child in sorted(container.iterdir()):
        relative = child.relative_to(repo).as_posix()
        guard(repo, relative, ".release-loop")
        name = child.name
        if legacy_active_name(name):
            children.append(child)
        elif allow_persistent and name in LEGACY_PERSISTENT_NAMES:
            continue
        else:
            kind = "legacy handoff collision" if allow_persistent else "legacy handoff source"
            reject(kind, f"unexpected entry {relative}")
    return children


def legacy_manifest_digest(entries: list[dict[str, object]]) -> str:
    return hashlib.sha256(json.dumps(entries, sort_keys=True, separators=(",", ":")).encode()).hexdigest()


def structured_progress_blocks(text: str) -> dict[str, dict[str, str] | None]:
    frontmatter_text = text.split("---", 2)[1]
    selected = {"pre_merge_verification": None, "v1": None}
    active = None
    for line in frontmatter_text.splitlines():
        top = re.fullmatch(r"([A-Za-z0-9_]+):(.*)", line)
        if top:
            active = None
            name, suffix = top.groups()
            if name in selected:
                if selected[name] is not None:
                    reject("legacy V1 ownership", f"duplicate block {name}")
                if suffix.strip():
                    reject("legacy V1 ownership", f"malformed block {name}")
                selected[name] = {}
                active = name
            continue
        if active is None:
            continue
        nested = re.fullmatch(r"  ([A-Za-z0-9_]+):(?: (.*))?", line)
        if nested is None:
            reject("legacy V1 ownership", f"malformed indentation in {active}")
        key, value = nested.groups()
        mapping = selected[active]
        assert mapping is not None
        if key in mapping:
            reject("legacy V1 ownership", f"duplicate key {active}.{key}")
        mapping[key] = value or ""
    return selected


def validate_v1_receipt(path: Path, expected_digest: str, label: str) -> None:
    try:
        payload = path.read_bytes()
        text = payload.decode("utf-8")
    except (OSError, UnicodeError):
        reject("legacy V1 ownership", f"unreadable {label} receipt")
    scope_lines = re.findall(r"^- receipt_sha256_scope: (.*)$", text, re.MULTILINE)
    digest_lines = re.findall(r"^- receipt_sha256: (.*)$", text, re.MULTILINE)
    marker = b"- receipt_sha256:"
    if scope_lines != ["canonical bytes before this field"] or len(digest_lines) != 1 or payload.count(marker) != 1:
        reject("legacy V1 ownership", f"malformed {label} receipt")
    embedded = digest_lines[0]
    computed = hashlib.sha256(payload.split(marker, 1)[0]).hexdigest()
    if not SHA_PATTERN.fullmatch(embedded) or len({expected_digest, embedded, computed}) != 1:
        reject("legacy V1 ownership", f"{label} receipt digest mismatch")


def validate_legacy_v1_ownership(repo: Path, text: str) -> None:
    blocks = structured_progress_blocks(text)
    pre_merge = blocks["pre_merge_verification"]
    ownership = blocks["v1"]
    root = repo / ".release-loop/v1"
    root_present = root.exists() or root.is_symlink()
    if pre_merge is None and ownership is None and not root_present:
        return
    if pre_merge is None or ownership is None:
        reject("legacy V1 ownership", "official acceptance, ownership, and V1 tree must agree")
    if set(pre_merge) != V1_PRE_MERGE_KEYS or any(not value for value in pre_merge.values()):
        reject("legacy V1 ownership", "invalid pre_merge_verification keys")
    if set(ownership) != V1_OWNERSHIP_KEYS or any(not value for value in ownership.values()):
        reject("legacy V1 ownership", "invalid v1 keys")
    if pre_merge["id"] != "V1" or pre_merge["status"] != "accepted":
        reject("legacy V1 ownership", "pre_merge_verification is not accepted V1")
    if ownership["status"] != "accepted":
        reject("legacy V1 ownership", "v1 ownership is not accepted")
    digests = (
        pre_merge["generation_sha256"], ownership["generation_manifest_sha256"],
        ownership["pilot_receipt_sha256"], ownership["full_receipt_sha256"],
    )
    if any(not SHA_PATTERN.fullmatch(digest) for digest in digests):
        reject("legacy V1 ownership", "invalid digest")
    if pre_merge["generation_sha256"] != ownership["generation_manifest_sha256"]:
        reject("legacy V1 ownership", "generation digest mismatch")
    if any(ownership[key] != expected for key, expected in V1_OWNERSHIP_PATHS.items()):
        reject("legacy V1 ownership", "non-canonical ownership path")
    if len({ownership[key] for key in V1_OWNERSHIP_PATHS}) != len(V1_OWNERSHIP_PATHS):
        reject("legacy V1 ownership", "duplicate ownership path")
    if root.is_symlink() or not root.is_dir():
        reject("legacy V1 ownership", "missing or invalid V1 root")
    expected_children = {PurePosixPath(path).name for path in V1_OWNERSHIP_PATHS.values()}
    observed_children = {child.name for child in root.iterdir()}
    extras = observed_children - expected_children - {"history"}
    missing = expected_children - observed_children
    if extras or missing:
        reject("legacy V1 ownership", "unexpected or missing V1 child")
    history = root / "history"
    if history.exists() or history.is_symlink():
        if history.is_symlink() or not history.is_dir():
            reject("legacy V1 ownership", "invalid V1 history")
        tree_manifest(history)
    paths = {}
    for key, relative in V1_OWNERSHIP_PATHS.items():
        candidate = repo / relative
        if candidate.is_symlink() or not candidate.is_file():
            reject("legacy V1 ownership", f"missing regular file {relative}")
        candidate = guard(repo, relative, ".release-loop/v1")
        paths[key] = candidate
    validate_v1_receipt(paths["pilot_receipt_path"], ownership["pilot_receipt_sha256"], "pilot")
    validate_v1_receipt(paths["full_receipt_path"], ownership["full_receipt_sha256"], "full")
    if phase_artifact_sha256(paths["generation_manifest_path"]) != ownership["generation_manifest_sha256"]:
        reject("legacy V1 ownership", "generation manifest digest mismatch")


def legacy_is_subset(observed: list[dict[str, object]], full: list[dict[str, object]]) -> bool:
    return all(entry in full for entry in observed)


def legacy_read_marker(marker: Path, expected_fields: dict[str, str]) -> dict[str, str]:
    if marker.is_symlink() or not marker.is_file():
        reject("legacy handoff marker", marker.as_posix())
    try:
        payload = json.loads(marker.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError):
        reject("legacy handoff marker", f"unreadable {marker.as_posix()}")
    if not isinstance(payload, dict) or set(payload) != LEGACY_MARKER_KEYS:
        reject("legacy handoff marker", f"invalid marker shape {marker.as_posix()}")
    if any(not isinstance(value, str) for value in payload.values()):
        reject("legacy handoff marker", f"invalid marker shape {marker.as_posix()}")
    if payload["schema"] != LEGACY_MARKER_SCHEMA:
        reject("legacy handoff marker", f"unknown marker schema {marker.as_posix()}")
    if payload["destination"] != LEGACY_DESTINATION:
        reject("legacy handoff marker", f"unknown destination {marker.as_posix()}")
    if not SHA_PATTERN.fullmatch(payload["manifest_sha256"]):
        reject("legacy handoff marker", f"invalid digest {marker.as_posix()}")
    if payload["status"] not in LEGACY_MARKER_STATUSES:
        reject("legacy handoff marker", f"invalid status {marker.as_posix()}")
    for key, value in expected_fields.items():
        if payload[key] != value:
            reject("handoff owner mismatch", marker.as_posix())
    return payload


def legacy_write_marker(marker: Path, payload: dict[str, str]) -> None:
    marker.write_text(json.dumps(payload, sort_keys=True, separators=(",", ":")) + "\n", encoding="utf-8")


def legacy_git_active_paths(repo: Path) -> list[str]:
    tracked = git_tracked(repo, ".release-loop")
    active = []
    for relative in tracked:
        parts = PurePosixPath(relative).parts
        if len(parts) >= 2 and legacy_active_name(parts[1]):
            active.append(relative)
    return active


def legacy_copy_child(child: Path, destination_root: Path) -> None:
    destination_root.mkdir(parents=True, exist_ok=True)
    target = destination_root / child.name
    if target.exists() or target.is_symlink():
        reject("handoff target mismatch", target.as_posix())
    if child.is_dir():
        target.mkdir(parents=True)
        for path in sorted(child.rglob("*")):
            if path.is_symlink():
                reject("path boundary", f"symlink component {path}")
            relative = path.relative_to(child)
            destination = target / relative
            if path.is_dir():
                destination.mkdir(parents=True, exist_ok=True)
            else:
                destination.parent.mkdir(parents=True, exist_ok=True)
                destination.write_bytes(path.read_bytes())
    else:
        target.write_bytes(child.read_bytes())


def legacy_handoff(
    repo: Path,
    base_repo: Path,
    progress_file: Path,
    values: dict[str, str],
    marker_relative: str,
) -> tuple[Path, Path]:
    run_id = values["feature"]
    validate_legacy_v1_ownership(repo, progress_file.read_text(encoding="utf-8"))
    marker = guard(base_repo, marker_relative, ".release-loop/.handoff")
    source = repo / ".release-loop"
    source_children = legacy_scan_children(repo, source, allow_persistent=False)
    manifest_entries = archive_manifest_entries(source, source_children)
    digest = legacy_manifest_digest(manifest_entries)
    destination = base_repo / ".release-loop"
    expected_fields = {
        "schema": LEGACY_MARKER_SCHEMA,
        "feature": run_id,
        "progress_path": progress_file.relative_to(repo).as_posix(),
        "artifact_root": ".release-loop",
        "source_worktree": str(repo),
        "base_owner": str(base_repo),
        "destination": LEGACY_DESTINATION,
    }
    if marker.exists():
        payload = legacy_read_marker(marker, expected_fields)
        if payload["manifest_sha256"] != digest:
            reject("legacy handoff source", "active manifest changed since marker creation")
        destination_children = legacy_scan_children(base_repo, destination, allow_persistent=True)
        observed_entries = archive_manifest_entries(destination, destination_children)
        if payload["status"] == "complete":
            if observed_entries != manifest_entries:
                reject("legacy handoff collision", "destination active state no longer matches complete marker")
            return legacy_confirm(base_repo, destination, marker)
        if not legacy_is_subset(observed_entries, manifest_entries):
            reject("handoff target mismatch", ".release-loop")
    else:
        destination_children = legacy_scan_children(base_repo, destination, allow_persistent=True)
        if destination_children or legacy_git_active_paths(base_repo):
            reject("legacy handoff collision", "base active legacy state already present")
        marker.parent.mkdir(parents=True, exist_ok=True)
        legacy_write_marker(marker, {**expected_fields, "manifest_sha256": digest, "status": "incomplete"})
    present_names = {child.name for child in destination_children}
    inject_after_copy = test_failure("handoff-after-copy-one")
    for child in source_children:
        if child.name not in present_names:
            legacy_copy_child(child, destination)
        elif child.is_dir():
            copy_missing(child, destination / child.name)
        else:
            continue
        if inject_after_copy:
            reject("injected handoff interruption", child.name)
    recheck_entries = archive_manifest_entries(source, legacy_scan_children(repo, source, allow_persistent=False))
    if legacy_manifest_digest(recheck_entries) != digest:
        reject("legacy handoff source", "active manifest changed during transfer")
    dest_children = legacy_scan_children(base_repo, destination, allow_persistent=True)
    dest_entries = archive_manifest_entries(destination, dest_children)
    if dest_entries != manifest_entries:
        reject("handoff target mismatch", ".release-loop")
    confirmed = legacy_confirm(base_repo, destination, marker)
    legacy_write_marker(marker, {**expected_fields, "manifest_sha256": digest, "status": "complete"})
    return confirmed


def legacy_confirm(base_repo: Path, destination: Path, marker: Path) -> tuple[Path, Path]:
    state, selected = discover(base_repo, ".release-loop/progress.md")
    if state != "resume" or selected != destination / "progress.md":
        reject("handoff resume verification", ".release-loop")
    return marker, selected


def canonical_json(payload: dict[str, object]) -> bytes:
    return (json.dumps(payload, sort_keys=True, separators=(",", ":")) + "\n").encode("utf-8")


def utc_now() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def open_repo_descriptor(repo: Path) -> int:
    return os.open(repo, DIRECTORY_OPEN_FLAGS)


def open_dir_chain(root_fd: int, relative: str) -> int:
    rel = repo_relative(relative)
    current = os.dup(root_fd)
    try:
        for part in rel.parts:
            child = os.open(part, DIRECTORY_OPEN_FLAGS, dir_fd=current)
            os.close(current)
            current = child
        return current
    except (FileNotFoundError, NotADirectoryError, OSError):
        os.close(current)
        raise


def ensure_dir_chain(root_fd: int, relative: str) -> int:
    rel = repo_relative(relative)
    current = os.dup(root_fd)
    try:
        for part in rel.parts:
            try:
                child = os.open(part, DIRECTORY_OPEN_FLAGS, dir_fd=current)
            except FileNotFoundError:
                try:
                    os.mkdir(part, mode=0o700, dir_fd=current)
                except FileExistsError:
                    pass
                os.fsync(current)
                created = os.stat(part, dir_fd=current, follow_symlinks=False)
                child = os.open(part, DIRECTORY_OPEN_FLAGS, dir_fd=current)
                opened = os.fstat(child)
                if (created.st_dev, created.st_ino) != (opened.st_dev, opened.st_ino):
                    os.close(child)
                    reject("path boundary", f"directory changed while opening {relative}")
            os.close(current)
            current = child
        return current
    except (NotADirectoryError, OSError):
        os.close(current)
        raise


def create_dir_exclusive(root_fd: int, relative: str) -> tuple[int, int]:
    rel = repo_relative(relative)
    if len(rel.parts) < 2:
        reject("path boundary", relative)
    parent_relative = PurePosixPath(*rel.parts[:-1]).as_posix()
    parent_fd = open_dir_chain(root_fd, parent_relative)
    try:
        child_fd = create_and_open_directory_at(parent_fd, rel.parts[-1])
    except Exception:
        os.close(parent_fd)
        raise
    return parent_fd, child_fd


def create_and_open_directory_at(parent_fd: int, name: str) -> int:
    os.mkdir(name, mode=0o700, dir_fd=parent_fd)
    os.fsync(parent_fd)
    created = os.stat(name, dir_fd=parent_fd, follow_symlinks=False)
    if not stat.S_ISDIR(created.st_mode):
        reject("path boundary", f"created entry is not a directory {name}")
    child_fd = os.open(name, DIRECTORY_OPEN_FLAGS, dir_fd=parent_fd)
    opened = os.fstat(child_fd)
    if (created.st_dev, created.st_ino) != (opened.st_dev, opened.st_ino):
        os.close(child_fd)
        reject("path boundary", f"created directory changed while opening {name}")
    return child_fd


def descriptor_matches(root_fd: int, relative: str, expected_fd: int) -> bool:
    try:
        observed_fd = open_dir_chain(root_fd, relative)
    except (FileNotFoundError, NotADirectoryError, OSError):
        return False
    try:
        expected = os.fstat(expected_fd)
        observed = os.fstat(observed_fd)
        return (expected.st_dev, expected.st_ino) == (observed.st_dev, observed.st_ino)
    finally:
        os.close(observed_fd)


def require_descriptor_binding(root_fd: int, relative: str, expected_fd: int) -> None:
    if not descriptor_matches(root_fd, relative, expected_fd):
        reject("path boundary", f"replaced ancestor for {relative}")


def _open_parent_fd(root_fd: int, relative: str) -> tuple[int, str]:
    rel = repo_relative(relative)
    if len(rel.parts) == 1:
        return os.dup(root_fd), rel.name
    return open_dir_chain(root_fd, PurePosixPath(*rel.parts[:-1]).as_posix()), rel.name


def _read_fd(file_fd: int) -> bytes:
    chunks = []
    while True:
        chunk = os.read(file_fd, 1024 * 1024)
        if not chunk:
            break
        chunks.append(chunk)
    return b"".join(chunks)


def read_file_at(root_fd: int, relative: str) -> bytes:
    parent_fd, name = _open_parent_fd(root_fd, relative)
    file_fd = -1
    try:
        file_fd = os.open(name, FILE_READ_FLAGS, dir_fd=parent_fd)
        observed = os.fstat(file_fd)
        if not stat.S_ISREG(observed.st_mode):
            reject("path boundary", f"non-regular file {relative}")
        return _read_fd(file_fd)
    except UnicodeError:
        reject("path boundary", f"unreadable file {relative}")
    finally:
        if file_fd >= 0:
            os.close(file_fd)
        os.close(parent_fd)


def file_sha256_at(root_fd: int, relative: str) -> str:
    return hashlib.sha256(read_file_at(root_fd, relative)).hexdigest()


def _write_all(file_fd: int, data: bytes) -> None:
    offset = 0
    while offset < len(data):
        offset += os.write(file_fd, data[offset:])


def recovery_publication_claim(
    relative: str,
    recovery_id: str,
    data: bytes,
) -> tuple[str, bytes]:
    canonical = repo_relative(relative).as_posix()
    if canonical != relative:
        reject("recovery archive", f"non-canonical publication path {relative}")
    token = hashlib.sha256(relative.encode("utf-8")).hexdigest()
    return (
        f".legacy-archive-recovery-owner-{token}.json",
        canonical_json({
            "schema": "legacy-archive-recovery-publication-claim/v1",
            "recovery_id": recovery_id,
            "path": relative,
            "sha256": hashlib.sha256(data).hexdigest(),
        }),
    )


def write_file_exclusive_at(
    directory_fd: int,
    name: str,
    data: bytes,
    *,
    mutation_guard: Callable[[], None] | None = None,
) -> None:
    file_fd = -1
    try:
        if mutation_guard is not None:
            mutation_guard()
        file_fd = os.open(
            name,
            os.O_WRONLY | os.O_CREAT | os.O_EXCL | getattr(os, "O_NOFOLLOW", 0),
            0o600,
            dir_fd=directory_fd,
        )
        _write_all(file_fd, data)
        os.fsync(file_fd)
    finally:
        if file_fd >= 0:
            os.close(file_fd)
    os.fsync(directory_fd)


def publish_resumable_file_at(
    directory_fd: int,
    final_name: str,
    temporary_name: str,
    data: bytes,
    *,
    mutation_guard: Callable[[], None] | None = None,
    failure_after_temporary: str | None = None,
    failure_kind: str = "recovery publication",
    allow_partial_resume: bool = False,
    retain_temporary: bool = False,
    resume_guard: Callable[[], None] | None = None,
    ownership_claim_name: str | None = None,
    ownership_claim_data: bytes | None = None,
    failure_after_partial_temporary: str | None = None,
) -> bool:
    """Publish exact bytes once and resume an owned durable temporary."""

    def observed(name: str) -> tuple[os.stat_result, bytes] | None:
        try:
            entry = os.stat(name, dir_fd=directory_fd, follow_symlinks=False)
        except FileNotFoundError:
            return None
        if not stat.S_ISREG(entry.st_mode):
            reject(failure_kind, f"non-regular publication entry {name}")
        file_fd = -1
        try:
            file_fd = os.open(name, FILE_READ_FLAGS, dir_fd=directory_fd)
            opened = os.fstat(file_fd)
            if (opened.st_dev, opened.st_ino) != (entry.st_dev, entry.st_ino):
                reject(failure_kind, f"publication entry changed while opening {name}")
            data = _read_fd(file_fd)
            current = os.stat(name, dir_fd=directory_fd, follow_symlinks=False)
            if (current.st_dev, current.st_ino) != (opened.st_dev, opened.st_ino):
                reject(failure_kind, f"publication entry changed while reading {name}")
            return opened, data
        finally:
            if file_fd >= 0:
                os.close(file_fd)

    def unlink_observed(name: str, expected: os.stat_result) -> None:
        retained_fd = -1
        try:
            retained_fd = os.open(name, FILE_READ_FLAGS, dir_fd=directory_fd)
            retained = os.fstat(retained_fd)
            current = os.stat(name, dir_fd=directory_fd, follow_symlinks=False)
            identity = (expected.st_dev, expected.st_ino)
            if (
                (retained.st_dev, retained.st_ino) != identity
                or (current.st_dev, current.st_ino) != identity
            ):
                reject(failure_kind, f"publication entry changed before cleanup {name}")
            os.unlink(name, dir_fd=directory_fd)
        finally:
            if retained_fd >= 0:
                os.close(retained_fd)

    if (ownership_claim_name is None) != (ownership_claim_data is None):
        reject(failure_kind, "incomplete publication ownership claim")

    claim = observed(ownership_claim_name) if ownership_claim_name is not None else None
    try:
        os.stat(temporary_name, dir_fd=directory_fd, follow_symlinks=False)
        temporary_preexisting = True
    except FileNotFoundError:
        temporary_preexisting = False
    if temporary_preexisting:
        if ownership_claim_name is not None and claim is None:
            reject(failure_kind, f"foreign publication temporary {temporary_name}")
        if resume_guard is None:
            reject(failure_kind, f"unowned publication temporary {temporary_name}")
        resume_guard()
    if claim is not None:
        if resume_guard is None:
            reject(failure_kind, f"unowned publication claim {ownership_claim_name}")
        resume_guard()
        _claim_stat, claim_data = claim
        if claim_data != ownership_claim_data:
            reject(failure_kind, f"foreign publication claim {ownership_claim_name}")
    if mutation_guard is not None:
        mutation_guard()
    final = observed(final_name)
    temporary = observed(temporary_name)
    if final is not None:
        final_stat, final_data = final
        if final_data != data:
            reject(failure_kind, f"changed final publication {final_name}")
        if temporary is not None:
            temporary_stat, temporary_data = temporary
            if temporary_data != data or (
                temporary_stat.st_dev,
                temporary_stat.st_ino,
            ) != (final_stat.st_dev, final_stat.st_ino):
                reject(failure_kind, f"foreign publication temporary {temporary_name}")
            if mutation_guard is not None:
                mutation_guard()
            if not retain_temporary:
                if temporary_preexisting and resume_guard is not None:
                    resume_guard()
                unlink_observed(temporary_name, temporary_stat)
                os.fsync(directory_fd)
        if claim is not None and not retain_temporary:
            claim_stat, _claim_data = claim
            if resume_guard is not None:
                resume_guard()
            unlink_observed(str(ownership_claim_name), claim_stat)
            os.fsync(directory_fd)
        return False

    if claim is None and ownership_claim_name is not None and ownership_claim_data is not None:
        write_file_exclusive_at(
            directory_fd,
            ownership_claim_name,
            ownership_claim_data,
            mutation_guard=mutation_guard,
        )
        claim = observed(ownership_claim_name)
        if claim is None or claim[1] != ownership_claim_data:
            reject(failure_kind, f"publication claim collision {ownership_claim_name}")
    if temporary is None:
        temporary_fd = -1
        try:
            if mutation_guard is not None:
                mutation_guard()
            temporary_fd = os.open(
                temporary_name,
                os.O_WRONLY | os.O_CREAT | os.O_EXCL | getattr(os, "O_NOFOLLOW", 0),
                0o600,
                dir_fd=directory_fd,
            )
            if failure_after_partial_temporary is not None and test_failure(
                failure_after_partial_temporary
            ):
                partial_length = max(1, len(data) // 2)
                _write_all(temporary_fd, data[:partial_length])
                os.fsync(temporary_fd)
                reject("injected recovery interruption", f"after partial {temporary_name}")
            _write_all(temporary_fd, data)
            os.fsync(temporary_fd)
        finally:
            if temporary_fd >= 0:
                os.close(temporary_fd)
    else:
        temporary_stat, temporary_data = temporary
        if not data.startswith(temporary_data):
            reject(failure_kind, f"changed publication temporary {temporary_name}")
        if len(temporary_data) < len(data):
            if not allow_partial_resume:
                reject(failure_kind, f"incomplete publication temporary {temporary_name}")
            if resume_guard is not None:
                resume_guard()
            temporary_fd = -1
            try:
                if mutation_guard is not None:
                    mutation_guard()
                temporary_fd = os.open(
                    temporary_name,
                    os.O_WRONLY | os.O_APPEND | getattr(os, "O_NOFOLLOW", 0),
                    dir_fd=directory_fd,
                )
                opened = os.fstat(temporary_fd)
                if (opened.st_dev, opened.st_ino) != (
                    temporary_stat.st_dev,
                    temporary_stat.st_ino,
                ) or opened.st_size != len(temporary_data):
                    reject(failure_kind, f"replaced publication temporary {temporary_name}")
                _write_all(temporary_fd, data[len(temporary_data):])
                os.fsync(temporary_fd)
            finally:
                if temporary_fd >= 0:
                    os.close(temporary_fd)
    os.fsync(directory_fd)
    if failure_after_temporary is not None and test_failure(failure_after_temporary):
        reject("injected recovery interruption", f"after {temporary_name}")
    if mutation_guard is not None:
        mutation_guard()
    try:
        os.link(
            temporary_name,
            final_name,
            src_dir_fd=directory_fd,
            dst_dir_fd=directory_fd,
            follow_symlinks=False,
        )
    except FileExistsError:
        pass
    final = observed(final_name)
    temporary = observed(temporary_name)
    if final is None or temporary is None:
        reject(failure_kind, f"publication collision {final_name}")
    final_stat, final_data = final
    temporary_stat, temporary_data = temporary
    if (
        final_data != data
        or temporary_data != data
        or (final_stat.st_dev, final_stat.st_ino)
        != (temporary_stat.st_dev, temporary_stat.st_ino)
    ):
        reject(failure_kind, f"publication collision {final_name}")
    os.fsync(directory_fd)
    if mutation_guard is not None:
        mutation_guard()
    if not retain_temporary:
        if temporary_preexisting and resume_guard is not None:
            resume_guard()
        unlink_observed(temporary_name, temporary_stat)
        os.fsync(directory_fd)
        if claim is not None:
            claim_stat, _claim_data = claim
            if resume_guard is not None:
                resume_guard()
            unlink_observed(str(ownership_claim_name), claim_stat)
            os.fsync(directory_fd)
    return True


def replace_file_at(
    directory_fd: int,
    name: str,
    data: bytes,
    *,
    mutation_guard: Callable[[], None] | None = None,
    failure_after_temporary: str | None = None,
    precommit_guard: Callable[[], None] | None = None,
    resume_guard: Callable[[], None] | None = None,
) -> None:
    temporary = f".{name}.recovery.tmp"
    try:
        temporary_stat = os.stat(temporary, dir_fd=directory_fd, follow_symlinks=False)
    except FileNotFoundError:
        temporary_stat = None
    if temporary_stat is None:
        temporary_fd = -1
        try:
            if mutation_guard is not None:
                mutation_guard()
            temporary_fd = os.open(
                temporary,
                os.O_WRONLY | os.O_CREAT | os.O_EXCL | getattr(os, "O_NOFOLLOW", 0),
                0o600,
                dir_fd=directory_fd,
            )
            _write_all(temporary_fd, data)
            os.fsync(temporary_fd)
        finally:
            if temporary_fd >= 0:
                os.close(temporary_fd)
    else:
        if resume_guard is None:
            reject("recovery generation", f"unowned progress temporary {temporary}")
        resume_guard()
        if not stat.S_ISREG(temporary_stat.st_mode):
            reject("recovery generation", f"non-regular progress temporary {temporary}")
        temporary_data = read_file_at(directory_fd, temporary)
        if not data.startswith(temporary_data):
            reject("recovery generation", f"changed progress temporary {temporary}")
        if len(temporary_data) < len(data):
            temporary_fd = -1
            try:
                if mutation_guard is not None:
                    mutation_guard()
                temporary_fd = os.open(
                    temporary,
                    os.O_WRONLY | os.O_APPEND | getattr(os, "O_NOFOLLOW", 0),
                    dir_fd=directory_fd,
                )
                opened = os.fstat(temporary_fd)
                if (opened.st_dev, opened.st_ino) != (
                    temporary_stat.st_dev,
                    temporary_stat.st_ino,
                ) or opened.st_size != len(temporary_data):
                    reject("recovery generation", f"replaced progress temporary {temporary}")
                _write_all(temporary_fd, data[len(temporary_data):])
                os.fsync(temporary_fd)
            finally:
                if temporary_fd >= 0:
                    os.close(temporary_fd)
    os.fsync(directory_fd)
    if failure_after_temporary is not None and test_failure(failure_after_temporary):
        reject("injected recovery interruption", f"after {temporary}")
    if mutation_guard is not None:
        mutation_guard()
    if precommit_guard is not None:
        precommit_guard()
    os.replace(temporary, name, src_dir_fd=directory_fd, dst_dir_fd=directory_fd)
    os.fsync(directory_fd)
    if mutation_guard is not None:
        mutation_guard()
    committed = read_file_at(directory_fd, name)
    if committed != data:
        reject("recovery generation", f"changed committed progress {name}")


def publish_record_at(
    authority_fd: int,
    name: str,
    payload: dict[str, object],
    *,
    mutation_guard: Callable[[], None] | None = None,
) -> str:
    if "/" in name or name in {"", ".", ".."}:
        reject("recovery authority", f"invalid record name {name}")
    target = name
    temporary = f".{name}.tmp"
    data = canonical_json(payload)
    try:
        os.stat(target, dir_fd=authority_fd, follow_symlinks=False)
    except FileNotFoundError:
        pass
    else:
        reject("recovery authority", f"record collision {name}")
    published = publish_resumable_file_at(
        authority_fd,
        target,
        temporary,
        data,
        mutation_guard=mutation_guard,
        failure_kind="recovery authority",
    )
    if not published:
        reject("recovery authority", f"record collision {name}")
    return hashlib.sha256(data).hexdigest()


def publish_bound_record_at(
    repo_fd: int,
    authority_relative: str,
    authority_fd: int,
    name: str,
    payload: dict[str, object],
) -> str:
    def mutation_guard() -> None:
        require_descriptor_binding(repo_fd, authority_relative, authority_fd)

    digest = publish_record_at(
        authority_fd,
        name,
        payload,
        mutation_guard=mutation_guard,
    )
    mutation_guard()
    return digest


def read_json_record_at(
    authority_fd: int,
    name: str,
    schema: str,
) -> tuple[dict[str, object], str]:
    try:
        data = read_file_at(authority_fd, name)
        payload = json.loads(data.decode("utf-8"))
    except (FileNotFoundError, OSError, UnicodeError, json.JSONDecodeError):
        reject("recovery authority", f"invalid or missing {name}")
    if not isinstance(payload, dict) or payload.get("schema") != schema:
        reject("recovery authority", f"invalid {name} schema")
    if canonical_json(payload) != data:
        reject("recovery authority", f"non-canonical {name}")
    return payload, hashlib.sha256(data).hexdigest()


def optional_json_record_at(
    authority_fd: int,
    name: str,
    schema: str,
) -> tuple[dict[str, object], str] | None:
    try:
        os.stat(name, dir_fd=authority_fd, follow_symlinks=False)
    except FileNotFoundError:
        return None
    return read_json_record_at(authority_fd, name, schema)


def validate_recovery_id(recovery_id: str) -> None:
    if not RECOVERY_ID_PATTERN.fullmatch(recovery_id) or recovery_id == "resume":
        reject("invalid recovery id", recovery_id)


def acquire_recovery_lock(
    repo_fd: int,
    authority_relative: str,
    authority_fd: int,
    operation: str,
) -> None:
    require_descriptor_binding(repo_fd, authority_relative, authority_fd)
    try:
        fcntl.flock(authority_fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        reject(operation, "recovery id is already executing")
    require_descriptor_binding(repo_fd, authority_relative, authority_fd)


def validate_linked_publication_temporary(
    directory_fd: int,
    final_name: str,
    temporary_name: str,
    expected_sha256: str,
    *,
    required: bool,
    failure_kind: str,
) -> os.stat_result | None:
    try:
        temporary = os.stat(temporary_name, dir_fd=directory_fd, follow_symlinks=False)
    except FileNotFoundError:
        if required:
            reject(failure_kind, f"missing transaction marker {temporary_name}")
        return None
    try:
        final = os.stat(final_name, dir_fd=directory_fd, follow_symlinks=False)
    except FileNotFoundError:
        reject(failure_kind, f"transaction marker lacks final {final_name}")
    if (
        not stat.S_ISREG(temporary.st_mode)
        or not stat.S_ISREG(final.st_mode)
        or (temporary.st_dev, temporary.st_ino) != (final.st_dev, final.st_ino)
    ):
        reject(failure_kind, f"invalid transaction marker {temporary_name}")
    final_data = read_file_at(directory_fd, final_name)
    temporary_data = read_file_at(directory_fd, temporary_name)
    if (
        final_data != temporary_data
        or hashlib.sha256(final_data).hexdigest() != expected_sha256
    ):
        reject(failure_kind, f"changed transaction marker {temporary_name}")
    return temporary


def unlink_linked_publication_temporary(
    directory_fd: int,
    temporary_name: str,
    expected: os.stat_result,
    *,
    failure_kind: str,
) -> None:
    retained_fd = -1
    try:
        retained_fd = os.open(temporary_name, FILE_READ_FLAGS, dir_fd=directory_fd)
        retained = os.fstat(retained_fd)
        current = os.stat(temporary_name, dir_fd=directory_fd, follow_symlinks=False)
        identity = (expected.st_dev, expected.st_ino)
        if (
            (retained.st_dev, retained.st_ino) != identity
            or (current.st_dev, current.st_ino) != identity
        ):
            reject(failure_kind, f"transaction marker changed before cleanup {temporary_name}")
        os.unlink(temporary_name, dir_fd=directory_fd)
        os.fsync(directory_fd)
    finally:
        if retained_fd >= 0:
            os.close(retained_fd)


def _progress_frontmatter_block(text: str) -> str:
    block, _body = split_frontmatter(
        text,
        failure_kind="recovery gate",
        detail="progress frontmatter is missing",
    )
    return block


def _indented_block(text: str, name: str) -> dict[str, str]:
    lines = _progress_frontmatter_block(text).splitlines()
    header_pattern = re.compile(rf"^{re.escape(name)}[ \t]*:")
    header_indices = [index for index, line in enumerate(lines) if header_pattern.match(line)]
    if any(lines[index] != f"{name}:" for index in header_indices):
        reject("recovery gate", f"malformed {name}")
    occurrences = [index for index in header_indices if lines[index] == f"{name}:"]
    if len(occurrences) > 1:
        reject("recovery gate", f"duplicate {name}")
    for index, line in enumerate(lines):
        if line != f"{name}:":
            continue
        values: dict[str, str] = {}
        for child in lines[index + 1:]:
            if not child.startswith("  "):
                break
            if ":" not in child[2:]:
                reject("recovery gate", f"malformed {name}")
            key, value = child[2:].split(":", 1)
            if not key or key in values:
                reject("recovery gate", f"malformed {name}")
            values[key] = value.strip()
        return values
    reject("recovery gate", f"missing {name}")
    return {}


def _utc_timestamp(value: str, field: str) -> None:
    try:
        parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        reject("recovery gate", f"invalid {field}")
    if parsed.tzinfo is None:
        reject("recovery gate", f"invalid {field}")


def read_recovery_gate(
    repo: Path,
    relative: str,
    session: str,
    require_receipt: bool = True,
    expected_request_sha256: str | None = None,
    repo_fd: int | None = None,
) -> tuple[Path, dict[str, str]]:
    if repo_fd is None:
        path, values, text = validate_progress(repo, relative)
        ledger_sha256 = phase_artifact_sha256(path)
    else:
        rel = repo_relative(relative)
        if (
            len(rel.parts) != 4
            or rel.parts[:2] != (".release-loop", "runs")
            or rel.name != "progress.md"
        ):
            reject("path boundary", f"invalid gate progress path {relative}")
        data = read_file_at(repo_fd, relative)
        try:
            text = data.decode("utf-8")
        except UnicodeError:
            reject("invalid progress", relative)
        values, _ = parse_frontmatter(
            text,
            relative,
            duplicate_kind="recovery gate",
        )
        expected_root = PurePosixPath(*rel.parts[:-1]).as_posix()
        if values.get("artifact_root") != expected_root or values.get("feature") != rel.parts[2]:
            reject("path boundary", f"invalid gate progress identity {relative}")
        path = repo / relative
        ledger_sha256 = hashlib.sha256(data).hexdigest()
    if values.get("phase_status") != "waiting-user":
        reject("recovery gate", "gate ledger is not waiting-user")
    pending = _indented_block(text, "recovery_gate")
    required_pending = {"id", "issued_at", "expected_answer_class"}
    required_receipt = {"gate_id", "gate_issued_at", "answer", "reserved_at"}
    if set(pending) != required_pending:
        reject("recovery gate", "invalid gate record shape")
    frontmatter_text = _progress_frontmatter_block(text)
    if not require_receipt and re.search(
        r"^recovery_gate_receipt[ \t]*:",
        frontmatter_text,
        re.MULTILINE,
    ):
        reject("recovery gate", "answer receipt already reserved")
    try:
        receipt = _indented_block(text, "recovery_gate_receipt")
    except Blocked:
        if require_receipt:
            raise
        if pending["id"] != RECOVERY_GATE_ID or pending["expected_answer_class"] != RECOVERY_GATE_ANSWER_CLASS:
            reject("recovery gate", "unexpected gate")
        _utc_timestamp(pending["issued_at"], "issued_at")
        if not session or any(character.isspace() or character in "/\\" for character in session):
            reject("recovery gate", "invalid session")
        return path, {"gate_id": pending["id"], "issued_at": pending["issued_at"], "ledger_sha256": ledger_sha256}
    allowed_receipt = {"gate_id", "gate_issued_at", "answer", "reserved_at", "session", "nonce", "request_sha256"}
    if set(receipt) - allowed_receipt:
        reject("recovery gate", "invalid gate record shape")
    if set(receipt) != required_receipt | {"session", "nonce", "request_sha256"}:
        reject("recovery gate", "invalid gate receipt shape")
    if pending["id"] != "legacy-archive-recovery-approval" or receipt["gate_id"] != pending["id"]:
        reject("recovery gate", "unexpected gate id")
    if pending["expected_answer_class"] != "approve-exact-recovery-or-cancel":
        reject("recovery gate", "unexpected answer class")
    if receipt["gate_issued_at"] != pending["issued_at"]:
        reject("recovery gate", "gate issue timestamp mismatch")
    if receipt["answer"] != "approved":
        reject("recovery gate", "answer is not approved")
    for field in ("issued_at", "gate_issued_at", "reserved_at"):
        _utc_timestamp((pending if field == "issued_at" else receipt)[field], field)
    issued_at = datetime.fromisoformat(pending["issued_at"].replace("Z", "+00:00"))
    reserved_at = datetime.fromisoformat(receipt["reserved_at"].replace("Z", "+00:00"))
    if reserved_at < issued_at:
        reject("recovery gate", "reservation precedes gate issue")
    if receipt["session"] != session:
        reject("recovery gate", "session mismatch")
    if expected_request_sha256 is not None and receipt.get("request_sha256") != expected_request_sha256:
        reject("recovery gate", "request digest mismatch")
    if not session or any(character.isspace() or character in "/\\" for character in session):
        reject("recovery gate", "invalid session")
    gate_values = {
        "gate_id": pending["id"],
        "issued_at": pending["issued_at"],
        "reserved_at": receipt["reserved_at"],
        "answer": receipt["answer"],
    }
    if "nonce" in receipt:
        if not receipt["nonce"]:
            reject("recovery gate", "empty answer nonce")
        gate_values["nonce"] = receipt["nonce"]
    gate_values["ledger_sha256"] = ledger_sha256
    if "request_sha256" in receipt:
        gate_values["request_sha256"] = receipt["request_sha256"]
    return path, gate_values


def _git_output(repo: Path, *arguments: str) -> bytes:
    result = subprocess.run(
        ("git", *arguments),
        cwd=repo,
        capture_output=True,
        check=False,
    )
    if result.returncode != 0:
        reject("recovery eligibility", "required Git evidence is unavailable")
    return result.stdout


def _recovery_eligibility_timestamp(value: str, field: str) -> datetime:
    try:
        parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        reject("recovery eligibility", f"{field} timestamp is invalid")
    if parsed.tzinfo is None:
        reject("recovery eligibility", f"{field} timestamp is invalid")
    return parsed


def validate_recovery_terminal_evidence(
    repo: Path,
    values: dict[str, str],
    text: str,
    request_issued: str,
    audit_timestamp: str,
) -> dict[str, str]:
    if values.get("phase") != "retro" or values.get("phase_status") != "in-progress":
        reject("recovery eligibility", "run is not at committed Retro")
    updated = values.get("updated", "")
    if re.fullmatch(RECOVERY_TIMESTAMP_PATTERN, updated) is None:
        reject("recovery eligibility", "updated timestamp is invalid")
    updated_at = _recovery_eligibility_timestamp(updated, "updated")
    if values.get("merged") != "true":
        reject("recovery eligibility", "Ship merge is not recorded")
    if values.get("branch") != values.get("base_branch"):
        reject("recovery eligibility", "merged branch is not the base branch")
    ship_approval = values.get("ship_approved", "")
    ship_approval_match = re.fullmatch(
        r'\{by: (user|auto), at: ([^,{}]+), conditions: "([^"\n]+)"\}',
        ship_approval,
    )
    if ship_approval_match is None:
        reject("recovery eligibility", "Ship approval shape is invalid")
    ship_approved = ship_approval_match.group(2)
    ship_approved_at = _recovery_eligibility_timestamp(ship_approved, "Ship approval")
    try:
        final_action = _indented_block(text, "final_action")
    except Blocked:
        reject("recovery eligibility", "final action is malformed")
    if set(final_action) != {"kind", "status", "command", "marker", "updated"}:
        reject("recovery eligibility", "final action shape is invalid")
    if (
        final_action.get("kind") != "merge-to-base"
        or final_action.get("status") != "executed"
        or final_action.get("command") in {None, "", "null"}
    ):
        reject("recovery eligibility", "final action was not executed")
    final_action_updated = _recovery_eligibility_timestamp(
        final_action["updated"],
        "final action",
    )
    retro = values.get("retro", "")
    retro_rel = repo_relative(retro)
    if len(retro_rel.parts) != 3 or retro_rel.parts[:2] != ("docs", "retros") or retro_rel.suffix != ".md":
        reject("recovery eligibility", "Retro path is invalid")
    retro_records = re.findall(
        r"^-[ \t]+(\S+)[ \t]+retro: committed \(([0-9a-f]{40})\)\s*$",
        text,
        re.MULTILINE,
    )
    ship_records = re.findall(
        r"^-[ \t]+(\S+)[ \t]+ship: merged \(([0-9a-f]{40})\)\s*$",
        text,
        re.MULTILINE,
    )
    if len(retro_records) != 1 or len(ship_records) != 1:
        reject("recovery eligibility", "Ship and Retro commit evidence must be unique")
    ship_merged = ship_records[0][0]
    retro_committed = retro_records[0][0]
    ship_merged_at = _recovery_eligibility_timestamp(ship_merged, "Ship merge Log")
    retro_committed_at = _recovery_eligibility_timestamp(retro_committed, "Retro commit Log")
    request_issued_at = _recovery_eligibility_timestamp(request_issued, "request issue")
    audit_at = _recovery_eligibility_timestamp(audit_timestamp, "audit")
    timeline = (
        ship_approved_at,
        final_action_updated,
        ship_merged_at,
        retro_committed_at,
        updated_at,
        request_issued_at,
        audit_at,
    )
    if any(timeline[index + 1] < timeline[index] for index in range(len(timeline) - 1)):
        reject("recovery eligibility", "terminal evidence timestamps are non-monotonic")
    if final_action_updated != ship_merged_at or retro_committed_at != updated_at:
        reject("recovery eligibility", "atomic terminal evidence timestamps differ")
    head = _git_output(repo, "rev-parse", "HEAD").decode("ascii").strip()
    retro_commit = retro_records[0][1]
    ship_commit = ship_records[0][1]
    if ship_commit == retro_commit:
        reject("recovery eligibility", "Ship and Retro commits must be distinct")
    for commit, label in ((ship_commit, "Ship"), (retro_commit, "Retro")):
        result = subprocess.run(
            ("git", "merge-base", "--is-ancestor", commit, head),
            cwd=repo,
            capture_output=True,
            check=False,
        )
        if result.returncode != 0:
            reject("recovery eligibility", f"{label} commit is not retained in HEAD")
    ship_before_retro = subprocess.run(
        ("git", "merge-base", "--is-ancestor", ship_commit, retro_commit),
        cwd=repo,
        capture_output=True,
        check=False,
    )
    if ship_before_retro.returncode != 0:
        reject("recovery eligibility", "Retro commit does not descend from merged Ship")
    head_blob = _git_output(repo, "show", f"HEAD:{retro_rel.as_posix()}")
    retro_blob = _git_output(repo, "show", f"{retro_commit}:{retro_rel.as_posix()}")
    if head_blob != retro_blob:
        reject("recovery eligibility", "Retro bytes changed after the recorded commit")
    return {
        "ship_commit": ship_commit,
        "retro_path": retro_rel.as_posix(),
        "retro_commit": retro_commit,
        "retro_sha256": hashlib.sha256(retro_blob).hexdigest(),
        "eligibility_head": head,
        "final_action_command": final_action["command"],
        "ship_approved_at": ship_approved,
        "final_action_updated": final_action["updated"],
        "ship_merged_at": ship_merged,
        "retro_committed_at": retro_committed,
        "terminal_updated_at": updated,
        "request_issued_at": request_issued,
    }


def read_archive_manifest_bytes(data: bytes) -> dict[str, object]:
    try:
        manifest = json.loads(data.decode("utf-8"))
    except (UnicodeError, json.JSONDecodeError):
        reject("archive destination conflict", "invalid source manifest")
    if (
        not isinstance(manifest, dict)
        or set(manifest) != {"schema", "entries"}
        or manifest.get("schema") != ARCHIVE_MANIFEST_SCHEMA
        or not isinstance(manifest.get("entries"), list)
        or canonical_json(manifest) != data
    ):
        reject("archive destination conflict", "invalid source manifest")
    return manifest


def validate_recovery_archive_controls(
    archive_fd: int,
    manifest_data: bytes,
) -> str:
    manifest_digest = hashlib.sha256(manifest_data).hexdigest()
    try:
        journal_data = read_file_at(archive_fd, JOURNAL_NAME)
    except FileNotFoundError:
        reject("archive destination conflict", "missing ownership journal")
    try:
        journal = json.loads(journal_data.decode("utf-8"))
    except (UnicodeError, json.JSONDecodeError):
        reject("archive destination conflict", "invalid ownership journal")
    if (
        not isinstance(journal, dict)
        or set(journal) != {"schema", "owned", "pending"}
        or journal.get("schema") != "phase-artifact-ownership/v1"
        or not isinstance(journal.get("owned"), dict)
        or journal.get("pending") is not None
        or journal["owned"].get(ARCHIVE_MANIFEST_NAME) != manifest_digest
        or canonical_json(journal) != journal_data
    ):
        reject("archive destination conflict", "invalid ownership journal")
    for relative, expected_digest in journal["owned"].items():
        if (
            not isinstance(relative, str)
            or not isinstance(expected_digest, str)
            or not SHA_PATTERN.fullmatch(expected_digest)
        ):
            reject("archive destination conflict", "invalid ownership journal row")
        try:
            canonical = repo_relative(relative).as_posix()
        except Blocked:
            reject("archive destination conflict", f"unsafe ownership path {relative}")
        if canonical != relative:
            reject("archive destination conflict", f"non-canonical ownership path {relative}")
        try:
            canonical_phase_artifact_key(relative, "target")
        except ArtifactBlocked:
            reject("archive destination conflict", f"invalid ownership target {relative}")
        try:
            observed_digest = file_sha256_at(archive_fd, relative)
        except (FileNotFoundError, NotADirectoryError, OSError, Blocked):
            reject("archive destination conflict", f"invalid owned final {relative}")
        if observed_digest != expected_digest:
            reject("archive destination conflict", f"owned final digest mismatch {relative}")
    return hashlib.sha256(journal_data).hexdigest()


def recovery_archive_journal_bytes(
    source_journal_data: bytes,
    expected_entries: list[dict[str, object]],
    manifest_digest: str,
) -> bytes:
    try:
        source_journal = json.loads(source_journal_data.decode("utf-8"))
    except (UnicodeError, json.JSONDecodeError):
        reject("recovery archive", "source ownership journal is invalid")
    if (
        not isinstance(source_journal, dict)
        or set(source_journal) != {"schema", "owned", "pending"}
        or source_journal.get("schema") != "phase-artifact-ownership/v1"
        or not isinstance(source_journal.get("owned"), dict)
        or source_journal.get("pending") is not None
        or canonical_json(source_journal) != source_journal_data
    ):
        reject("recovery archive", "source ownership journal is invalid")
    payload_digests = {
        str(entry["path"]): str(entry["sha256"])
        for entry in expected_entries
        if entry.get("kind") == "file"
    }
    owned: dict[str, str] = {}
    for relative, digest in source_journal["owned"].items():
        if relative == ARCHIVE_MANIFEST_NAME:
            continue
        if payload_digests.get(str(relative)) != digest:
            reject("recovery archive", f"owned final changed before archive {relative}")
        owned[str(relative)] = str(digest)
    owned[ARCHIVE_MANIFEST_NAME] = manifest_digest
    return canonical_json({
        "schema": "phase-artifact-ownership/v1",
        "owned": owned,
        "pending": None,
    })


def validate_recovery_archive_snapshot(
    root_fd: int,
    expected_manifest_sha256: object,
    expected_journal_sha256: object,
    *,
    failure_kind: str,
) -> list[dict[str, object]]:
    if (
        not isinstance(expected_manifest_sha256, str)
        or not SHA_PATTERN.fullmatch(expected_manifest_sha256)
        or not isinstance(expected_journal_sha256, str)
        or not SHA_PATTERN.fullmatch(expected_journal_sha256)
    ):
        reject(failure_kind, "archive control digest is invalid")
    try:
        manifest_data = read_file_at(root_fd, ARCHIVE_MANIFEST_NAME)
        if hashlib.sha256(manifest_data).hexdigest() != expected_manifest_sha256:
            reject(failure_kind, "archive manifest digest mismatch")
        manifest = read_archive_manifest_bytes(manifest_data)
        payload_entries = recovery_tree_at(root_fd, exclude=RECOVERY_CONTROL_NAMES)
        if payload_entries != manifest["entries"]:
            reject(failure_kind, "archive payload does not match manifest")
        validate_recovery_payload_namespace(
            payload_entries,
            failure_kind=failure_kind,
        )
        journal_digest = validate_recovery_archive_controls(root_fd, manifest_data)
        if journal_digest != expected_journal_sha256:
            reject(failure_kind, "ownership journal digest mismatch")
        return recovery_tree_at(root_fd)
    except (FileNotFoundError, NotADirectoryError, OSError):
        reject(failure_kind, "archive snapshot is unavailable")
    return []


def validate_archived_recovery_packet(repo: Path, relative: str) -> dict[str, object]:
    rel = repo_relative(relative)
    if len(rel.parts) != 4 or rel.parts[:2] != (".release-loop", "archive") or rel.name != "progress.md":
        reject("path boundary", f"archived progress must be scoped: {relative}")
    destination = PurePosixPath(*rel.parts[:-1]).as_posix()
    repo_fd = open_repo_descriptor(repo)
    archive_fd = -1
    try:
        archive_fd = open_dir_chain(repo_fd, destination)
        progress_data = read_file_at(archive_fd, "progress.md")
        try:
            progress_text = progress_data.decode("utf-8")
        except UnicodeError:
            reject("invalid progress", relative)
        values, text = parse_frontmatter(
            progress_text,
            relative,
            duplicate_kind="invalid recovery packet",
        )
        if values.get("artifact_root") is None:
            reject("path boundary", "missing original artifact root")
        source_rel = values["artifact_root"]
        source_root = PurePosixPath(source_rel)
        if len(source_root.parts) != 3 or source_root.parts[:2] != (".release-loop", "runs"):
            reject("path boundary", f"restore target must be scoped: {source_rel}")
        if source_root.parts[2] != values.get("feature"):
            reject("invalid progress", "feature does not match restore target")
        mode, stored = archive_evidence(text)
        if mode != "incomplete" or stored != destination:
            reject("invalid recovery packet", "archive is not archived-incomplete")
        if values.get("phase") not in PHASES or values.get("phase") == "done":
            reject("invalid recovery packet", "incomplete archive phase is invalid")
        if values.get("phase_status") not in PHASE_STATUSES or values.get("phase_status") == "complete":
            reject("invalid recovery packet", "incomplete archive status is invalid")
        manifest_data = read_file_at(archive_fd, ARCHIVE_MANIFEST_NAME)
        manifest = read_archive_manifest_bytes(manifest_data)
        payload_entries = recovery_tree_at(archive_fd, exclude=RECOVERY_CONTROL_NAMES)
        if payload_entries != manifest["entries"]:
            reject("archive destination conflict", "source manifest mismatch")
        validate_recovery_payload_namespace(
            payload_entries,
            failure_kind="invalid recovery packet",
        )
        ownership_digest = validate_recovery_archive_controls(archive_fd, manifest_data)
        try:
            target_fd = open_dir_chain(repo_fd, source_rel)
        except FileNotFoundError:
            target_fd = -1
        if target_fd >= 0:
            os.close(target_fd)
            reject("recovery eligibility", "restore target is occupied")
        require_descriptor_binding(repo_fd, destination, archive_fd)
    finally:
        if archive_fd >= 0:
            os.close(archive_fd)
        os.close(repo_fd)
    return {
        "archived_progress_path": relative,
        "archive_destination": destination,
        "archive_manifest_path": f"{destination}/{ARCHIVE_MANIFEST_NAME}",
        "archive_manifest_sha256": hashlib.sha256(manifest_data).hexdigest(),
        "ownership_journal_sha256": ownership_digest,
        "original_artifact_root": source_rel,
        "restore_target": source_rel,
        "feature": values["feature"],
        "mode": "archived-incomplete",
        "plan_path": values.get("plan") or values.get("plan_path"),
        "plan_seal": values.get("body_seal") or values.get("plan_seal"),
        "plan_approval_commit": values.get("plan_approval_commit") or values.get("approval_commit"),
        "contract_introduction_commit": CONTRACT_INTRODUCTION_COMMIT,
    }


def request_legacy_archive(
    repo: Path,
    recovery_id: str,
    progress_path: str | None,
    gate_progress_path: str | None,
    session: str | None,
) -> dict[str, object]:
    if progress_path is None or gate_progress_path is None or session is None:
        reject("invalid arguments", "request mode requires progress, gate progress, and session")
    validate_recovery_id(recovery_id)
    packet = validate_archived_recovery_packet(repo, progress_path)
    repo_fd = open_repo_descriptor(repo)
    authority_family_fd = -1
    backup_family_fd = -1
    authority_fd = -1
    backup_fd = -1
    try:
        gate_path, gate = read_recovery_gate(
            repo,
            gate_progress_path,
            session,
            require_receipt=False,
            repo_fd=repo_fd,
        )
        authority_relative = f"{RECOVERY_AUTHORITY_ROOT}/{recovery_id}"
        backup_relative = f"{RECOVERY_BACKUP_ROOT}/{recovery_id}"
        if git_tracked(repo, authority_relative) or git_tracked(repo, backup_relative):
            reject("recovery authority", f"tracked recovery root {recovery_id}")
        try:
            authority_family_fd = ensure_dir_chain(repo_fd, RECOVERY_AUTHORITY_ROOT)
            backup_family_fd = ensure_dir_chain(repo_fd, RECOVERY_BACKUP_ROOT)
        except OSError:
            reject("path boundary", "recovery family ancestor is not a directory")
        try:
            require_descriptor_binding(repo_fd, RECOVERY_AUTHORITY_ROOT, authority_family_fd)
            authority_fd = create_and_open_directory_at(authority_family_fd, recovery_id)
        except FileExistsError:
            reject("recovery authority", f"recovery id already claimed {recovery_id}")
        try:
            if test_failure("recovery-backup-create"):
                raise OSError("injected recovery backup-root creation failure")
            require_descriptor_binding(repo_fd, RECOVERY_BACKUP_ROOT, backup_family_fd)
            backup_fd = create_and_open_directory_at(backup_family_fd, recovery_id)
        except OSError as exc:
            require_descriptor_binding(repo_fd, authority_relative, authority_fd)
            publish_bound_record_at(repo_fd, authority_relative, authority_fd, "initialization-result.json", {
                "schema": RECOVERY_INITIALIZATION_SCHEMA,
                "recovery_id": recovery_id,
                "authority_root": authority_relative,
                "failure_class": "backup-root-creation-failed",
                "detail": str(exc),
                "issued_at": utc_now(),
            })
            reject("recovery initialization", "backup root creation failed")
        request = {
            "schema": RECOVERY_REQUEST_SCHEMA,
            "recovery_id": recovery_id,
            **packet,
            "gate_progress_path": gate_path.relative_to(repo).as_posix(),
            "gate_progress_sha256": gate["ledger_sha256"],
            "gate_id": gate["gate_id"],
            "gate_issued_at": gate["issued_at"],
            "answer_reservation_nonce": gate.get("nonce"),
            "session_id": session,
            "authority_root": authority_relative,
            "backup_root": backup_relative,
            "issued_at": utc_now(),
        }
        require_descriptor_binding(repo_fd, authority_relative, authority_fd)
        require_descriptor_binding(repo_fd, backup_relative, backup_fd)
        publish_bound_record_at(repo_fd, authority_relative, authority_fd, "request.json", request)
        require_descriptor_binding(repo_fd, authority_relative, authority_fd)
        require_descriptor_binding(repo_fd, backup_relative, backup_fd)
    finally:
        for descriptor in (backup_fd, authority_fd, backup_family_fd, authority_family_fd, repo_fd):
            if descriptor >= 0:
                os.close(descriptor)
    return {"recovery_id": recovery_id, "state": "requested"}


def publish_recovery_approval(repo: Path, recovery_id: str) -> dict[str, object]:
    validate_recovery_id(recovery_id)
    repo_fd = open_repo_descriptor(repo)
    authority_fd = -1
    authority_relative = f"{RECOVERY_AUTHORITY_ROOT}/{recovery_id}"
    try:
        try:
            authority_fd = open_dir_chain(repo_fd, authority_relative)
        except OSError:
            reject("recovery authority", "request is unavailable")
        request, request_digest = read_json_record_at(authority_fd, "request.json", RECOVERY_REQUEST_SCHEMA)
        gate_relative = str(request.get("gate_progress_path", ""))
        gate_path, gate = read_recovery_gate(
            repo,
            gate_relative,
            str(request.get("session_id", "")),
            expected_request_sha256=request_digest,
            repo_fd=repo_fd,
        )
        if gate["gate_id"] != request.get("gate_id") or gate["issued_at"] != request.get("gate_issued_at"):
            reject("recovery gate", "receipt does not match request")
        snapshot = {
            "schema": RECOVERY_GATE_RECEIPT_SCHEMA,
            "request_sha256": request_digest,
            "gate_progress_path": gate_path.relative_to(repo).as_posix(),
            "gate_progress_sha256": gate["ledger_sha256"],
            "session_id": request["session_id"],
            "gate_id": gate["gate_id"],
            "gate_issued_at": gate["issued_at"],
            "answer": gate["answer"],
            "answer_reservation_nonce": gate.get("nonce"),
            "reserved_at": gate["reserved_at"],
        }
        require_descriptor_binding(repo_fd, authority_relative, authority_fd)
        existing_snapshot = optional_json_record_at(
            authority_fd,
            "gate-receipt.json",
            RECOVERY_GATE_RECEIPT_SCHEMA,
        )
        snapshot_published = existing_snapshot is None
        if existing_snapshot is None:
            snapshot_digest = publish_bound_record_at(
                repo_fd,
                authority_relative,
                authority_fd,
                "gate-receipt.json",
                snapshot,
            )
        else:
            existing_payload, snapshot_digest = existing_snapshot
            if existing_payload != snapshot:
                reject("recovery gate", "existing gate receipt differs from live receipt")
        require_descriptor_binding(repo_fd, authority_relative, authority_fd)
        if snapshot_published and test_failure("recovery-after-gate-receipt"):
            reject("injected recovery interruption", "after gate receipt")
        approval = {
            "schema": RECOVERY_APPROVAL_SCHEMA,
            "request_sha256": request_digest,
            "gate_receipt_path": f"{authority_relative}/gate-receipt.json",
            "gate_receipt_sha256": snapshot_digest,
        }
        require_descriptor_binding(repo_fd, authority_relative, authority_fd)
        publish_bound_record_at(repo_fd, authority_relative, authority_fd, "approval.json", approval)
        require_descriptor_binding(repo_fd, authority_relative, authority_fd)
    finally:
        if authority_fd >= 0:
            os.close(authority_fd)
        os.close(repo_fd)
    return {"recovery_id": recovery_id, "state": "approved"}


def _recovery_excluded(relative: str, exclude: frozenset[str]) -> bool:
    return relative in exclude or any(relative.startswith(prefix + "/") for prefix in exclude)


def recovery_tree_at(
    root_fd: int,
    *,
    exclude: frozenset[str] = frozenset(),
    progress_override: bytes | None = None,
) -> list[dict[str, object]]:
    entries: list[dict[str, object]] = []

    def walk(directory_fd: int, prefix: PurePosixPath) -> None:
        for name in sorted(os.listdir(directory_fd)):
            relative_path = prefix / name
            relative = relative_path.as_posix()
            if _recovery_excluded(relative, exclude):
                continue
            observed = os.stat(name, dir_fd=directory_fd, follow_symlinks=False)
            if stat.S_ISLNK(observed.st_mode):
                reject("path boundary", f"symlink component {relative}")
            if stat.S_ISDIR(observed.st_mode):
                entries.append({"kind": "directory", "path": relative})
                child_fd = os.open(name, DIRECTORY_OPEN_FLAGS, dir_fd=directory_fd)
                try:
                    opened = os.fstat(child_fd)
                    if (opened.st_dev, opened.st_ino) != (observed.st_dev, observed.st_ino):
                        reject("recovery generation", f"directory changed during scan {relative}")
                    walk(child_fd, relative_path)
                finally:
                    os.close(child_fd)
            elif stat.S_ISREG(observed.st_mode):
                file_fd = os.open(name, FILE_READ_FLAGS, dir_fd=directory_fd)
                try:
                    opened = os.fstat(file_fd)
                    if (opened.st_dev, opened.st_ino) != (observed.st_dev, observed.st_ino):
                        reject("recovery generation", f"file changed during scan {relative}")
                    data = _read_fd(file_fd)
                finally:
                    os.close(file_fd)
                if relative == "progress.md" and progress_override is not None:
                    data = progress_override
                entries.append({
                    "kind": "file",
                    "path": relative,
                    "sha256": hashlib.sha256(data).hexdigest(),
                })
            else:
                reject("recovery backup", f"unsupported entry {relative}")

    walk(root_fd, PurePosixPath())
    return sorted(entries, key=lambda row: str(row["path"]))


def recovery_generation_at(
    root_fd: int,
    *,
    exclude: frozenset[str] = frozenset(),
    progress_override: bytes | None = None,
) -> str:
    entries = recovery_tree_at(
        root_fd,
        exclude=exclude,
        progress_override=progress_override,
    )
    return hashlib.sha256(canonical_json({"entries": entries})).hexdigest()


def _copy_regular_file(
    source_fd: int,
    target_fd: int,
    name: str,
    relative: str,
    *,
    allow_existing: bool,
    resumable_publication: bool,
    publication_recovery_id: str | None,
    publication_resume_guard: Callable[[], None] | None,
    source_guard: Callable[[], None] | None,
    target_mutation_guard: Callable[[], None] | None,
) -> bool:
    if source_guard is not None:
        source_guard()
    input_fd = os.open(name, FILE_READ_FLAGS, dir_fd=source_fd)
    try:
        source_stat = os.fstat(input_fd)
        if not stat.S_ISREG(source_stat.st_mode):
            reject("recovery backup", f"unsupported entry {relative}")
        data = _read_fd(input_fd)
    finally:
        os.close(input_fd)
    if resumable_publication:
        if publication_recovery_id is None:
            reject("recovery archive", "missing publication recovery id")
        temporary = (
            ".legacy-archive-recovery-pending-"
            + hashlib.sha256(relative.encode("utf-8")).hexdigest()
            + ".tmp"
        )
        claim_name, claim_data = recovery_publication_claim(
            relative,
            publication_recovery_id,
            data,
        )
        return publish_resumable_file_at(
            target_fd,
            name,
            temporary,
            data,
            mutation_guard=target_mutation_guard,
            failure_kind="recovery archive",
            allow_partial_resume=True,
            resume_guard=publication_resume_guard,
            ownership_claim_name=claim_name,
            ownership_claim_data=claim_data,
            failure_after_partial_temporary=(
                "recovery-archive-payload-prefix-temp-only"
                if relative == "progress.md"
                else None
            ),
        )
    try:
        write_file_exclusive_at(
            target_fd,
            name,
            data,
            mutation_guard=target_mutation_guard,
        )
        return True
    except FileExistsError:
        if not allow_existing:
            reject("restore target", f"entry collision {relative}")
        if read_file_at(target_fd, name) != data:
            reject("recovery archive", f"changed existing entry {relative}")
        return False


def copy_recovery_tree_at(
    source_fd: int,
    target_fd: int,
    *,
    exclude: frozenset[str] = frozenset(),
    progress_last: bool = False,
    allow_existing: bool = False,
    resumable_publication: bool = False,
    publication_recovery_id: str | None = None,
    failure_after_first_file: str | None = None,
    failure_before_progress: str | None = None,
    publication_resume_guard: Callable[[], None] | None = None,
    source_guard: Callable[[], None] | None = None,
    target_mutation_guard: Callable[[], None] | None = None,
) -> list[dict[str, object]]:
    if source_guard is not None:
        source_guard()
    expected = recovery_tree_at(source_fd, exclude=exclude)

    published_entries = 0

    def walk(source_directory_fd: int, target_directory_fd: int, prefix: PurePosixPath) -> None:
        nonlocal published_entries
        if source_guard is not None:
            source_guard()
        names = sorted(os.listdir(source_directory_fd))
        if progress_last and not prefix.parts and "progress.md" in names:
            names.remove("progress.md")
            names.append("progress.md")
        for name in names:
            relative_path = prefix / name
            relative = relative_path.as_posix()
            if _recovery_excluded(relative, exclude):
                continue
            source_stat = os.stat(name, dir_fd=source_directory_fd, follow_symlinks=False)
            if stat.S_ISLNK(source_stat.st_mode):
                reject("path boundary", f"symlink component {relative}")
            if stat.S_ISDIR(source_stat.st_mode):
                published_directory = False
                try:
                    if target_mutation_guard is not None:
                        target_mutation_guard()
                    os.mkdir(name, mode=0o700, dir_fd=target_directory_fd)
                    os.fsync(target_directory_fd)
                    published_directory = True
                except FileExistsError:
                    if not allow_existing:
                        reject("restore target", f"entry collision {relative}")
                if published_directory:
                    published_entries += 1
                    if (
                        failure_after_first_file is not None
                        and published_entries == 1
                        and test_failure(failure_after_first_file)
                    ):
                        reject("injected recovery interruption", "after one payload publication")
                source_child_fd = os.open(name, DIRECTORY_OPEN_FLAGS, dir_fd=source_directory_fd)
                try:
                    target_child_fd = os.open(name, DIRECTORY_OPEN_FLAGS, dir_fd=target_directory_fd)
                except Exception:
                    os.close(source_child_fd)
                    raise
                try:
                    opened = os.fstat(source_child_fd)
                    if (opened.st_dev, opened.st_ino) != (source_stat.st_dev, source_stat.st_ino):
                        reject("recovery generation", f"directory changed during copy {relative}")
                    walk(source_child_fd, target_child_fd, relative_path)
                finally:
                    os.close(source_child_fd)
                    os.close(target_child_fd)
            elif stat.S_ISREG(source_stat.st_mode):
                if (
                    failure_before_progress is not None
                    and relative == "progress.md"
                    and test_failure(failure_before_progress)
                ):
                    reject("injected recovery interruption", "before progress publication")
                published = _copy_regular_file(
                    source_directory_fd,
                    target_directory_fd,
                    name,
                    relative,
                    allow_existing=allow_existing,
                    resumable_publication=resumable_publication,
                    publication_recovery_id=publication_recovery_id,
                    publication_resume_guard=publication_resume_guard,
                    source_guard=source_guard,
                    target_mutation_guard=target_mutation_guard,
                )
                if published:
                    published_entries += 1
                    if (
                        failure_after_first_file is not None
                        and published_entries == 1
                        and test_failure(failure_after_first_file)
                    ):
                        reject("injected recovery interruption", "after one payload publication")
            else:
                reject("recovery backup", f"unsupported entry {relative}")

    walk(source_fd, target_fd, PurePosixPath())
    if target_mutation_guard is not None:
        target_mutation_guard()
    observed = recovery_tree_at(target_fd, exclude=exclude)
    if observed != expected:
        reject("recovery generation", "copied tree does not match source")
    return expected


def remove_expected_recovery_tree_at(
    root_fd: int,
    expected_entries: list[dict[str, object]],
    *,
    prefix: PurePosixPath | None = None,
    mutation_guard: Callable[[], None] | None = None,
) -> None:
    if prefix is None:
        prefix = PurePosixPath()
    direct: dict[str, dict[str, object]] = {}
    for entry in expected_entries:
        relative = PurePosixPath(str(entry["path"]))
        if relative.parent == prefix:
            direct[relative.name] = entry
    for name in sorted(direct):
        entry = direct[name]
        try:
            observed = os.stat(name, dir_fd=root_fd, follow_symlinks=False)
        except FileNotFoundError:
            continue
        relative = prefix / name
        if entry["kind"] == "directory":
            if not stat.S_ISDIR(observed.st_mode):
                reject("recovery archive", f"cleanup kind mismatch {relative.as_posix()}")
            child_fd = os.open(name, DIRECTORY_OPEN_FLAGS, dir_fd=root_fd)
            try:
                opened = os.fstat(child_fd)
                if (opened.st_dev, opened.st_ino) != (observed.st_dev, observed.st_ino):
                    reject("recovery archive", f"cleanup directory changed {relative.as_posix()}")
                remove_expected_recovery_tree_at(
                    child_fd,
                    expected_entries,
                    prefix=relative,
                    mutation_guard=mutation_guard,
                )
                if os.listdir(child_fd):
                    reject("recovery archive", f"foreign cleanup entry under {relative.as_posix()}")
                if mutation_guard is not None:
                    mutation_guard()
                current = os.stat(name, dir_fd=root_fd, follow_symlinks=False)
                if (current.st_dev, current.st_ino) != (opened.st_dev, opened.st_ino):
                    reject("recovery archive", f"cleanup directory replaced {relative.as_posix()}")
                os.rmdir(name, dir_fd=root_fd)
            finally:
                os.close(child_fd)
        elif entry["kind"] == "file":
            if not stat.S_ISREG(observed.st_mode):
                reject("recovery archive", f"cleanup kind mismatch {relative.as_posix()}")
            file_fd = os.open(name, FILE_READ_FLAGS, dir_fd=root_fd)
            try:
                opened = os.fstat(file_fd)
                if (opened.st_dev, opened.st_ino) != (observed.st_dev, observed.st_ino):
                    reject("recovery archive", f"cleanup file changed {relative.as_posix()}")
                digest = hashlib.sha256(_read_fd(file_fd)).hexdigest()
            finally:
                os.close(file_fd)
            if digest != entry.get("sha256"):
                reject("recovery archive", f"cleanup digest mismatch {relative.as_posix()}")
            if mutation_guard is not None:
                mutation_guard()
            current = os.stat(name, dir_fd=root_fd, follow_symlinks=False)
            if (current.st_dev, current.st_ino) != (opened.st_dev, opened.st_ino):
                reject("recovery archive", f"cleanup file replaced {relative.as_posix()}")
            os.unlink(name, dir_fd=root_fd)
        else:
            reject("recovery archive", f"unsupported cleanup entry {relative.as_posix()}")
        if test_failure("recovery-after-cleanup-one"):
            reject("injected recovery interruption", "after one cleanup entry")
    if prefix == PurePosixPath() and os.listdir(root_fd):
        reject("recovery archive", "foreign entry appeared during cleanup")
    os.fsync(root_fd)


def recovery_cleanup_location(target_relative: str, recovery_id: str) -> tuple[str, str, str]:
    target = repo_relative(target_relative)
    parent = PurePosixPath(*target.parts[:-1]).as_posix()
    name = f".{target.name}.legacy-recovery-cleanup-{recovery_id}"
    return parent, name, f"{parent}/{name}"


def recovery_entries_are_subset(
    observed: list[dict[str, object]],
    expected: list[dict[str, object]],
) -> bool:
    expected_by_path = {str(entry["path"]): entry for entry in expected}
    return len(expected_by_path) == len(expected) and all(
        expected_by_path.get(str(entry["path"])) == entry
        for entry in observed
    )


def cleanup_recovery_target(
    repo_fd: int,
    target_parent_fd: int,
    target_fd: int,
    target_relative: str,
    expected_entries: list[dict[str, object]],
    recovery_id: str,
) -> None:
    parent_relative, cleanup_name, cleanup_relative = recovery_cleanup_location(
        target_relative,
        recovery_id,
    )
    cleanup_fd = -1
    target_name = repo_relative(target_relative).name
    if target_fd >= 0:
        try:
            os.stat(cleanup_name, dir_fd=target_parent_fd, follow_symlinks=False)
        except FileNotFoundError:
            pass
        else:
            reject("recovery archive", "cleanup locus is already occupied")
        require_descriptor_binding(repo_fd, target_relative, target_fd)
        require_descriptor_binding(repo_fd, parent_relative, target_parent_fd)
        current = os.stat(target_name, dir_fd=target_parent_fd, follow_symlinks=False)
        retained = os.fstat(target_fd)
        if (current.st_dev, current.st_ino) != (retained.st_dev, retained.st_ino):
            reject("recovery archive", "cleanup target identity mismatch")
        os.rename(target_name, cleanup_name, src_dir_fd=target_parent_fd, dst_dir_fd=target_parent_fd)
        os.fsync(target_parent_fd)
        cleanup_fd = os.open(cleanup_name, DIRECTORY_OPEN_FLAGS, dir_fd=target_parent_fd)
        opened = os.fstat(cleanup_fd)
        if (opened.st_dev, opened.st_ino) != (retained.st_dev, retained.st_ino):
            reject("recovery archive", "cleanup isolation identity mismatch")
    else:
        try:
            os.stat(target_name, dir_fd=target_parent_fd, follow_symlinks=False)
        except FileNotFoundError:
            pass
        else:
            reject("recovery archive", "canonical target reappeared during cleanup resume")
        try:
            cleanup_fd = os.open(cleanup_name, DIRECTORY_OPEN_FLAGS, dir_fd=target_parent_fd)
        except FileNotFoundError:
            return
    try:
        def mutation_guard() -> None:
            require_descriptor_binding(repo_fd, cleanup_relative, cleanup_fd)

        mutation_guard()
        remaining = recovery_tree_at(cleanup_fd)
        if not recovery_entries_are_subset(remaining, expected_entries):
            reject("recovery archive", "cleanup locus contains foreign or changed entries")
        remove_expected_recovery_tree_at(
            cleanup_fd,
            expected_entries,
            mutation_guard=mutation_guard,
        )
        mutation_guard()
        os.rmdir(cleanup_name, dir_fd=target_parent_fd)
        os.fsync(target_parent_fd)
    finally:
        os.close(cleanup_fd)


def backup_legacy_archive(repo: Path, recovery_id: str) -> dict[str, object]:
    validate_recovery_id(recovery_id)
    repo_fd = open_repo_descriptor(repo)
    authority_fd = -1
    backup_fd = -1
    source_fd = -1
    authority_relative = f"{RECOVERY_AUTHORITY_ROOT}/{recovery_id}"
    try:
        authority_fd = open_dir_chain(repo_fd, authority_relative)
        request, request_digest = read_json_record_at(authority_fd, "request.json", RECOVERY_REQUEST_SCHEMA)
        approval, _approval_digest = read_json_record_at(authority_fd, "approval.json", RECOVERY_APPROVAL_SCHEMA)
        if set(approval) != {"schema", "request_sha256", "gate_receipt_path", "gate_receipt_sha256"}:
            reject("recovery backup", "approval shape mismatch")
        if approval.get("request_sha256") != request_digest:
            reject("recovery backup", "approval does not pin request")
        try:
            gate_receipt, gate_receipt_digest = read_json_record_at(
                authority_fd,
                "gate-receipt.json",
                RECOVERY_GATE_RECEIPT_SCHEMA,
            )
            validate_gate_receipt_snapshot(request, gate_receipt, request_digest)
        except Blocked as exc:
            reject("recovery backup", f"invalid gate receipt: {exc}")
        if (
            approval.get("gate_receipt_path")
            != f"{authority_relative}/gate-receipt.json"
            or approval.get("gate_receipt_sha256") != gate_receipt_digest
        ):
            reject("recovery backup", "approval gate receipt pin mismatch")
        backup_relative = str(request.get("backup_root", ""))
        source_relative = str(request.get("archive_destination", ""))
        if backup_relative != f"{RECOVERY_BACKUP_ROOT}/{recovery_id}":
            reject("recovery backup", "backup root identity mismatch")
        backup_fd = open_dir_chain(repo_fd, backup_relative)
        source_fd = open_dir_chain(repo_fd, source_relative)
        if os.listdir(backup_fd):
            reject("recovery backup", "backup root is not empty and unambiguous")
        if test_failure("recovery-backup-create"):
            reject("recovery backup", "injected backup interruption")
        require_descriptor_binding(repo_fd, authority_relative, authority_fd)
        require_descriptor_binding(repo_fd, backup_relative, backup_fd)
        require_descriptor_binding(repo_fd, source_relative, source_fd)
        expected_journal = request.get("ownership_journal_sha256")
        source_entries = validate_recovery_archive_snapshot(
            source_fd,
            request.get("archive_manifest_sha256"),
            expected_journal,
            failure_kind="recovery backup",
        )
        copy_recovery_tree_at(
            source_fd,
            backup_fd,
            progress_last=True,
            source_guard=lambda: require_descriptor_binding(repo_fd, source_relative, source_fd),
            target_mutation_guard=lambda: require_descriptor_binding(
                repo_fd,
                backup_relative,
                backup_fd,
            ),
        )
        entries = validate_recovery_archive_snapshot(
            backup_fd,
            request.get("archive_manifest_sha256"),
            expected_journal,
            failure_kind="recovery backup",
        )
        if entries != source_entries:
            reject("recovery backup", "backup bytes do not match source")
        payload = {
            "schema": "legacy-archive-recovery-backup/v1",
            "request_sha256": request_digest,
            "backup_root": backup_relative,
            "source_manifest_sha256": request["archive_manifest_sha256"],
            "ownership_journal_sha256": expected_journal,
            "entries": entries,
            "tree_sha256": hashlib.sha256(canonical_json({"entries": entries})).hexdigest(),
        }
        require_descriptor_binding(repo_fd, authority_relative, authority_fd)
        require_descriptor_binding(repo_fd, backup_relative, backup_fd)
        require_descriptor_binding(repo_fd, source_relative, source_fd)
        publish_bound_record_at(repo_fd, authority_relative, authority_fd, "backup.json", payload)
        require_descriptor_binding(repo_fd, authority_relative, authority_fd)
        require_descriptor_binding(repo_fd, backup_relative, backup_fd)
        require_descriptor_binding(repo_fd, source_relative, source_fd)
    except (FileNotFoundError, NotADirectoryError):
        reject("recovery backup", "required recovery root is unavailable")
    finally:
        for descriptor in (source_fd, backup_fd, authority_fd, repo_fd):
            if descriptor >= 0:
                os.close(descriptor)
    return {"backup_path": backup_relative, "recovery_id": recovery_id, "state": "backed-up"}


def validate_gate_receipt_snapshot(
    request: dict[str, object],
    receipt: dict[str, object],
    request_digest: str,
) -> None:
    expected_fields = {
        "schema",
        "request_sha256",
        "gate_progress_path",
        "gate_progress_sha256",
        "session_id",
        "gate_id",
        "gate_issued_at",
        "answer",
        "answer_reservation_nonce",
        "reserved_at",
    }
    if set(receipt) != expected_fields:
        reject("recovery audit", "gate receipt shape mismatch")
    if (
        receipt.get("request_sha256") != request_digest
        or receipt.get("gate_progress_path") != request.get("gate_progress_path")
        or receipt.get("session_id") != request.get("session_id")
        or receipt.get("gate_id") != request.get("gate_id")
        or receipt.get("gate_issued_at") != request.get("gate_issued_at")
        or receipt.get("answer") != "approved"
        or not isinstance(receipt.get("answer_reservation_nonce"), str)
        or not receipt.get("answer_reservation_nonce")
        or not isinstance(receipt.get("gate_progress_sha256"), str)
        or not SHA_PATTERN.fullmatch(str(receipt.get("gate_progress_sha256")))
    ):
        reject("recovery audit", "gate receipt mismatch")
    try:
        issued = datetime.fromisoformat(str(receipt["gate_issued_at"]).replace("Z", "+00:00"))
        reserved = datetime.fromisoformat(str(receipt["reserved_at"]).replace("Z", "+00:00"))
    except ValueError:
        reject("recovery audit", "gate receipt timestamp mismatch")
    if issued.tzinfo is None or reserved.tzinfo is None or reserved < issued:
        reject("recovery audit", "gate receipt timestamp mismatch")


def audit_legacy_archive(repo: Path, recovery_id: str) -> dict[str, object]:
    validate_recovery_id(recovery_id)
    repo_fd = open_repo_descriptor(repo)
    authority_fd = -1
    backup_fd = -1
    archive_fd = -1
    authority_relative = f"{RECOVERY_AUTHORITY_ROOT}/{recovery_id}"
    try:
        authority_fd = open_dir_chain(repo_fd, authority_relative)
        acquire_recovery_lock(
            repo_fd,
            authority_relative,
            authority_fd,
            "recovery audit",
        )
        hold_recovery_lock_for_test()
        request, request_digest = read_json_record_at(authority_fd, "request.json", RECOVERY_REQUEST_SCHEMA)
        approval, approval_digest = read_json_record_at(authority_fd, "approval.json", RECOVERY_APPROVAL_SCHEMA)
        receipt, gate_receipt_digest = read_json_record_at(
            authority_fd,
            "gate-receipt.json",
            RECOVERY_GATE_RECEIPT_SCHEMA,
        )
        backup, backup_digest = read_json_record_at(
            authority_fd,
            "backup.json",
            "legacy-archive-recovery-backup/v1",
        )
        if approval.get("request_sha256") != request_digest:
            reject("recovery audit", "request digest mismatch")
        expected_receipt_path = f"{authority_relative}/gate-receipt.json"
        if approval.get("gate_receipt_path") != expected_receipt_path or approval.get("gate_receipt_sha256") != gate_receipt_digest:
            reject("recovery audit", "approval receipt pin mismatch")
        validate_gate_receipt_snapshot(request, receipt, request_digest)
        backup_relative = str(backup.get("backup_root", ""))
        archive_relative = str(request.get("archive_destination", ""))
        if backup_relative != request.get("backup_root"):
            reject("recovery audit", "backup root mismatch")
        backup_fd = open_dir_chain(repo_fd, backup_relative)
        archive_fd = open_dir_chain(repo_fd, archive_relative)
        expected_manifest = request.get("archive_manifest_sha256")
        expected_journal = request.get("ownership_journal_sha256")
        entries = validate_recovery_archive_snapshot(
            backup_fd,
            expected_manifest,
            expected_journal,
            failure_kind="recovery audit",
        )
        tree_digest = hashlib.sha256(canonical_json({"entries": entries})).hexdigest()
        if entries != backup.get("entries") or backup.get("tree_sha256") != tree_digest:
            reject("recovery audit", "backup tree digest mismatch")
        archive_entries = validate_recovery_archive_snapshot(
            archive_fd,
            expected_manifest,
            expected_journal,
            failure_kind="recovery audit",
        )
        if (
            archive_entries != entries
            or backup.get("source_manifest_sha256") != expected_manifest
            or backup.get("ownership_journal_sha256") != expected_journal
        ):
            reject("recovery audit", "archive and backup bytes differ")
        progress_data = read_file_at(archive_fd, "progress.md")
        try:
            progress_text = progress_data.decode("utf-8")
        except UnicodeError:
            reject("recovery audit", "archived progress is unreadable")
        progress_values, _ = parse_frontmatter(progress_text, str(request.get("archived_progress_path", "")))
        terminal: dict[str, str] | None = None
        provenance: dict[str, str] | None = None
        classification: str | None = None
        parsed_version: str | None = None
        failure: dict[str, str] | None = None
        verdict = "accepted"
        audit_timestamp = utc_now()
        try:
            provenance = validate_recovery_provenance(repo, request)
            classification = provenance["classification"]
            parsed_version = provenance["parsed_version"]
            if classification != "absent-legacy-shape":
                reject("recovery audit", f"classification is not eligible: {classification}")
            terminal = validate_recovery_terminal_evidence(
                repo,
                progress_values,
                progress_text,
                str(request.get("issued_at", "")),
                audit_timestamp,
            )
        except Blocked as exc:
            verdict = "rejected"
            message = str(exc)
            failure_class, separator, detail = message.partition(":")
            failure = {
                "class": failure_class.strip() or "recovery audit",
                "detail": (detail if separator else message).strip()[:512],
            }
        payload = {
            "schema": "legacy-archive-recovery-audit/v1",
            "request_sha256": request_digest,
            "approval_sha256": approval_digest,
            "gate_receipt_sha256": gate_receipt_digest,
            "backup_sha256": backup_digest,
            "classification": classification,
            "parsed_version": parsed_version,
            "eligibility": terminal,
            "provenance": provenance,
            "failure": failure,
            "verdict": verdict,
            "auditor": "run-artifact-integrity.py",
            "timestamp": audit_timestamp,
        }
        require_descriptor_binding(repo_fd, authority_relative, authority_fd)
        require_descriptor_binding(repo_fd, backup_relative, backup_fd)
        require_descriptor_binding(repo_fd, archive_relative, archive_fd)
        publish_bound_record_at(repo_fd, authority_relative, authority_fd, "audit.json", payload)
        require_descriptor_binding(repo_fd, authority_relative, authority_fd)
        require_descriptor_binding(repo_fd, backup_relative, backup_fd)
        require_descriptor_binding(repo_fd, archive_relative, archive_fd)
    except (FileNotFoundError, NotADirectoryError):
        reject("recovery audit", "required recovery root is unavailable")
    finally:
        for descriptor in (archive_fd, backup_fd, authority_fd, repo_fd):
            if descriptor >= 0:
                os.close(descriptor)
    return {
        "audit_path": f"{authority_relative}/audit.json",
        "recovery_id": recovery_id,
        "state": "audited",
        "verdict": verdict,
    }


def _append_progress_line(text: str, line: str) -> str:
    return text.rstrip("\n") + "\n" + line + "\n"


def _replace_progress_field(text: str, name: str, value: str) -> str:
    block, body = split_frontmatter(
        text,
        failure_kind="recovery generation",
        detail="progress frontmatter is missing",
    )
    lines = block.splitlines()
    indices = [index for index, line in enumerate(lines) if line.startswith(f"{name}:")]
    if len(indices) != 1:
        reject("recovery generation", f"invalid top-level field {name}")
    lines[indices[0]] = f"{name}: {value}"
    return "---" + "\n".join(lines) + "\n---" + body


def _top_level_progress_value(text: str, name: str) -> str:
    block, _body = split_frontmatter(
        text,
        failure_kind="recovery generation",
        detail="progress frontmatter is missing",
    )
    matches = [
        line.split(":", 1)[1].strip()
        for line in block.splitlines()
        if line.startswith(f"{name}:")
    ]
    if len(matches) != 1:
        reject("recovery generation", f"invalid top-level field {name}")
    return matches[0]


def _recovery_timestamp(value: str, detail: str) -> datetime:
    if re.fullmatch(RECOVERY_TIMESTAMP_PATTERN, value) is None:
        reject("recovery generation", detail)
    try:
        parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        reject("recovery generation", detail)
    return parsed


def _recovery_event_timestamp(text: str, marker: str) -> str:
    matches = _progress_matches(
        text,
        rf"^- ({RECOVERY_TIMESTAMP_PATTERN}) {re.escape(marker)}",
    )
    if len(matches) != 1:
        reject("recovery generation", f"invalid {marker} timestamp evidence")
    value = matches[0].group(1)
    _recovery_timestamp(value, f"invalid {marker} timestamp")
    return value


def recovery_progress_transition_timestamp(
    target_fd: int,
    marker: str,
    minimum: str,
) -> str:
    try:
        temporary_text = read_file_at(
            target_fd,
            RECOVERY_PROGRESS_TEMP_NAME,
        ).decode("utf-8")
    except FileNotFoundError:
        value = utc_now()
    except UnicodeError:
        reject("recovery generation", "progress temporary is not UTF-8")
    else:
        value = _recovery_event_timestamp(temporary_text, marker)
    if _recovery_timestamp(value, "invalid transition timestamp") < _recovery_timestamp(
        minimum,
        "invalid prior transition timestamp",
    ):
        reject("recovery generation", "transition timestamp precedes prior write")
    return value


def replace_recovery_progress_generation(
    repo_fd: int,
    target_relative: str,
    target_fd: int,
    expected_generation: str,
    data: bytes,
    *,
    after_binding: Callable[[], None] | None = None,
    failure_after_temporary: str | None = None,
) -> None:
    def mutation_guard() -> None:
        require_descriptor_binding(repo_fd, target_relative, target_fd)

    def generation_guard() -> None:
        mutation_guard()
        if test_failure("recovery-progress-before-replace-generation-change"):
            marker = ".injected-generation-change"
            try:
                marker_data = read_file_at(target_fd, marker)
            except FileNotFoundError:
                write_file_exclusive_at(
                    target_fd,
                    marker,
                    b"GENERATION CHANGE\n",
                    mutation_guard=mutation_guard,
                )
            else:
                if marker_data != b"GENERATION CHANGE\n":
                    reject("invalid test failure", "generation marker collision")
        if recovery_generation_at(
            target_fd,
            exclude=RECOVERY_TRANSIENT_NAMES,
        ) != expected_generation:
            reject("recovery generation", "generation changed before progress commit")
        mutation_guard()

    mutation_guard()
    if recovery_generation_at(
        target_fd,
        exclude=RECOVERY_TRANSIENT_NAMES,
    ) != expected_generation:
        reject("recovery generation", "generation changed before atomic progress update")
    if after_binding is not None:
        after_binding()
    mutation_guard()
    replace_file_at(
        target_fd,
        "progress.md",
        data,
        mutation_guard=mutation_guard,
        failure_after_temporary=failure_after_temporary,
        precommit_guard=generation_guard,
        resume_guard=generation_guard,
    )
    mutation_guard()


def _remove_progress_line(text: str, line: str) -> str:
    line = line.rstrip("\r\n")
    candidate = line + "\n"
    if text.count(candidate) != 1:
        reject("recovery generation", f"recovery evidence is not unique: {line}")
    return text.replace(candidate, "", 1)


def _progress_matches(text: str, pattern: str) -> list[re.Match[str]]:
    return list(re.finditer(pattern, text, re.MULTILINE))


def recovery_progress_state(
    root_fd: int,
    text: str,
    request: dict[str, object],
    receipt: dict[str, object],
    receipt_digest: str,
    *,
    generation_exclude: frozenset[str] = frozenset(),
) -> tuple[str, str | None, dict[str, str]]:
    generation_exclude = generation_exclude | RECOVERY_TRANSIENT_NAMES
    values, _ = parse_frontmatter(text, str(request.get("restore_target", "")) + "/progress.md")
    incomplete = _progress_matches(
        text,
        rf"^- ({RECOVERY_TIMESTAMP_PATTERN}) archived-incomplete: archive-destination: (\S+)\s*$",
    )
    destination_markers = _progress_matches(
        text,
        rf"^- ({RECOVERY_TIMESTAMP_PATTERN}) retro: archive-destination: (\S+) "
        rf"recovery-id=({FEATURE_PATTERN.pattern[1:-1]}) receipt-sha256=([0-9a-f]{{64}}) "
        rf"g0-sha256=([0-9a-f]{{64}})\s*$",
    )
    staged = _progress_matches(
        text,
        rf"^- ({RECOVERY_TIMESTAMP_PATTERN}) legacy_archive_recovery: staged: "
        rf"recovery-id=({FEATURE_PATTERN.pattern[1:-1]}) receipt-sha256=([0-9a-f]{{64}}) "
        rf"g0-sha256=([0-9a-f]{{64}}) destination=(\S+) prior-updated=(\S+)\s*$",
    )
    accepted = _progress_matches(
        text,
        rf"^- ({RECOVERY_TIMESTAMP_PATTERN}) legacy-pre-archive-verification: accepted: "
        rf"recovery-id=({FEATURE_PATTERN.pattern[1:-1]}) receipt-sha256=([0-9a-f]{{64}}) "
        rf"g1-sha256=([0-9a-f]{{64}}) destination=(\S+) source=(\S+) "
        rf"prior-updated=(\S+)\s*$",
    )
    completed = _progress_matches(
        text,
        rf"^- ({RECOVERY_TIMESTAMP_PATTERN}) legacy_archive_recovery: completed: "
        rf"recovery-id=({FEATURE_PATTERN.pattern[1:-1]}) receipt-sha256=([0-9a-f]{{64}}) "
        rf"g2-sha256=([0-9a-f]{{64}}) destination=(\S+) prior-phase=(\S+) "
        rf"prior-status=(\S+) prior-updated=(\S+)\s*$",
    )
    if len(incomplete) != 1 or incomplete[0].group(2) != request.get("archive_destination"):
        reject("recovery generation", "original incomplete archive marker changed")
    evidence_counts = tuple(map(len, (destination_markers, staged, accepted, completed)))
    if evidence_counts == (0, 0, 0, 0):
        if values.get("phase") == "done" or values.get("phase_status") == "complete":
            reject("recovery generation", "G0 is unexpectedly terminal")
        if recovery_generation_at(root_fd, exclude=generation_exclude) != receipt.get("g0_sha256"):
            reject("recovery generation", "G0 digest mismatch")
        return "g0", None, values
    if len(destination_markers) != 1 or len(staged) != 1:
        reject("recovery generation", "G1 evidence is incomplete or duplicated")
    marker = destination_markers[0]
    stage = staged[0]
    destination = marker.group(2)
    expected_tuple = (
        str(request.get("recovery_id")),
        receipt_digest,
        str(receipt.get("g0_sha256")),
    )
    if marker.groups()[2:] != expected_tuple or stage.groups()[1:4] != expected_tuple:
        reject("recovery generation", "G1 receipt or G0 pin mismatch")
    if (
        stage.group(1) != marker.group(1)
        or stage.group(5) != destination
        or destination == request.get("archive_destination")
    ):
        reject("recovery generation", "G1 destination mismatch")
    if _recovery_timestamp(
        stage.group(1),
        "invalid G1 timestamp",
    ) < _recovery_timestamp(stage.group(6), "invalid G0 updated timestamp"):
        reject("recovery generation", "G1 timestamp precedes G0")
    if _recovery_timestamp(
        stage.group(1),
        "invalid G1 timestamp",
    ) < _recovery_timestamp(str(request.get("issued_at", "")), "invalid request timestamp"):
        reject("recovery generation", "G1 timestamp precedes request")

    current_text = text
    if completed:
        if len(completed) != 1 or len(accepted) != 1:
            reject("recovery generation", "G3 evidence is incomplete or duplicated")
        completion = completed[0]
        if (
            completion.group(2) != request.get("recovery_id")
            or completion.group(3) != receipt_digest
            or completion.group(5) != destination
            or values.get("phase") != "done"
            or values.get("phase_status") != "complete"
            or values.get("updated") != completion.group(1)
            or completion.group(8) != accepted[0].group(1)
        ):
            reject("recovery generation", "G3 evidence mismatch")
        g2_text = _remove_progress_line(current_text, completion.group(0))
        g2_text = _replace_progress_field(g2_text, "phase", completion.group(6))
        g2_text = _replace_progress_field(g2_text, "phase_status", completion.group(7))
        g2_text = _replace_progress_field(g2_text, "updated", completion.group(8))
        observed_g2 = recovery_generation_at(
            root_fd,
            exclude=generation_exclude,
            progress_override=g2_text.encode("utf-8"),
        )
        if observed_g2 != completion.group(4):
            reject("recovery generation", f"G2 digest mismatch expected={completion.group(4)} observed={observed_g2}")
        current_text = g2_text
    elif values.get("phase") == "done" or values.get("phase_status") == "complete":
        reject("recovery generation", "intermediate recovery is terminal")

    if accepted:
        if len(accepted) != 1:
            reject("recovery generation", "G2 evidence is duplicated")
        acceptance = accepted[0]
        if (
            acceptance.group(2) != request.get("recovery_id")
            or acceptance.group(3) != receipt_digest
            or acceptance.group(5) != destination
            or acceptance.group(6) != request.get("archive_destination")
            or acceptance.group(7) != stage.group(1)
        ):
            reject("recovery generation", "G2 evidence mismatch")
        g1_text = _remove_progress_line(current_text, acceptance.group(0))
        g1_text = _replace_progress_field(g1_text, "updated", acceptance.group(7))
        if recovery_generation_at(
            root_fd,
            exclude=generation_exclude,
            progress_override=g1_text.encode("utf-8"),
        ) != acceptance.group(4):
            reject("recovery generation", "G1 digest mismatch")
        current_text = g1_text
    elif completed:
        reject("recovery generation", "G3 lacks G2 acceptance")

    if accepted and _recovery_timestamp(
        accepted[0].group(1),
        "invalid G2 timestamp",
    ) < _recovery_timestamp(stage.group(1), "invalid G1 timestamp"):
        reject("recovery generation", "G2 timestamp precedes G1")
    if completed and _recovery_timestamp(
        completed[0].group(1),
        "invalid G3 timestamp",
    ) < _recovery_timestamp(accepted[0].group(1), "invalid G2 timestamp"):
        reject("recovery generation", "G3 timestamp precedes G2")
    expected_updated = (
        completed[0].group(1)
        if completed
        else accepted[0].group(1)
        if accepted
        else stage.group(1)
    )
    if values.get("updated") != expected_updated:
        reject("recovery generation", "current updated timestamp does not match generation")
    g0_text = _remove_progress_line(current_text, marker.group(0))
    g0_text = _remove_progress_line(g0_text, stage.group(0))
    g0_text = _replace_progress_field(g0_text, "updated", stage.group(6))
    if recovery_generation_at(
        root_fd,
        exclude=generation_exclude,
        progress_override=g0_text.encode("utf-8"),
    ) != receipt.get("g0_sha256"):
        reject("recovery generation", "G0 reconstruction mismatch")
    if completed:
        return "g3", destination, values
    if accepted:
        return "g2", destination, values
    return "g1", destination, values


def recovery_destination(request: dict[str, object]) -> str:
    issued_at = str(request.get("issued_at", ""))
    date = issued_at[:10]
    if not re.fullmatch(r"\d{4}-\d{2}-\d{2}", date):
        reject("recovery restore", "request timestamp is invalid")
    return f".release-loop/archive/{date}-{request['feature']}-recovered"


def inject_recovery_ancestor_replacement(
    repo: Path,
    recovery_id: str,
    failure: str = "recovery-before-copy-ancestor",
) -> None:
    if not test_failure(failure):
        return
    replacement = os.environ.get("RUN_ARTIFACT_INTEGRITY_TEST_REPLACE_TARGET", "")
    external = Path(replacement)
    if not external.is_absolute() or not external.is_dir() or external.is_symlink():
        reject("invalid test failure", "replacement target must be an existing absolute directory")
    runs = repo / ".release-loop/runs"
    displaced = repo / f".release-loop/runs.recovery-displaced-{failure}-{recovery_id}"
    if displaced.exists() or displaced.is_symlink():
        reject("invalid test failure", "replacement displacement already exists")
    os.rename(runs, displaced)
    os.symlink(str(external), runs, target_is_directory=True)


def inject_recovery_target_create_swap(
    repo: Path,
    recovery_id: str,
    target_relative: str,
) -> None:
    if not test_failure("recovery-target-create-swap"):
        return
    replacement = os.environ.get("RUN_ARTIFACT_INTEGRITY_TEST_REPLACE_TARGET", "")
    external = Path(replacement)
    if not external.is_absolute() or not external.is_dir() or external.is_symlink():
        reject("invalid test failure", "replacement target must be an existing absolute directory")
    target = repo / target_relative
    if not target.is_dir() or target.is_symlink():
        reject("invalid test failure", "created target is unavailable")
    displaced = target.with_name(target.name + f".created-{recovery_id}")
    os.rename(target, displaced)
    shutil.copytree(external, target)


def inject_recovery_source_change(backup_fd: int, source_archive_fd: int) -> None:
    if not test_failure("recovery-before-copy-source-change"):
        return
    selected = os.environ.get("RUN_ARTIFACT_INTEGRITY_TEST_MUTATE_SOURCE", "backup")
    if selected == "backup":
        selected_fd = backup_fd
    elif selected == "source":
        selected_fd = source_archive_fd
    else:
        reject("invalid test failure", "source mutation selector must be backup or source")
    progress_data = read_file_at(selected_fd, "progress.md")
    replace_file_at(selected_fd, "progress.md", progress_data + b"\n# INJECTED SOURCE CHANGE\n")


def inject_recovery_progress_after_binding_swap(
    repo: Path,
    recovery_id: str,
    target_relative: str,
) -> None:
    if not test_failure("recovery-progress-after-binding-swap"):
        return
    replacement = os.environ.get("RUN_ARTIFACT_INTEGRITY_TEST_REPLACE_TARGET", "")
    external = Path(replacement)
    if not external.is_absolute() or not external.is_dir() or external.is_symlink():
        reject("invalid test failure", "replacement target must be an existing absolute directory")
    target = repo / target_relative
    displaced = external / f"{recovery_id}-retained-target"
    if displaced.exists() or displaced.is_symlink():
        reject("invalid test failure", "retained target displacement already exists")
    os.rename(target, displaced)
    os.mkdir(target, mode=0o700)


def hold_recovery_lock_for_test() -> None:
    selected = os.environ.get("RUN_ARTIFACT_INTEGRITY_TEST_HOLD_RECOVERY_LOCK")
    if selected is None:
        return
    control = Path(selected)
    if not control.is_absolute() or not control.is_dir() or control.is_symlink():
        reject("invalid test failure", "recovery lock control must be an absolute real directory")
    ready = control / "ready"
    release = control / "release"
    ready_fd = -1
    try:
        ready_fd = os.open(
            ready,
            os.O_WRONLY | os.O_CREAT | os.O_EXCL | getattr(os, "O_NOFOLLOW", 0),
            0o600,
        )
        _write_all(ready_fd, b"ready\n")
        os.fsync(ready_fd)
    except FileExistsError:
        reject("invalid test failure", "recovery lock ready marker already exists")
    finally:
        if ready_fd >= 0:
            os.close(ready_fd)
    for _attempt in range(200):
        if release.is_file() and not release.is_symlink():
            return
        time.sleep(0.05)
    reject("invalid test failure", "recovery lock release marker timed out")


def validate_or_publish_recovery_receipt(
    repo_fd: int,
    authority_relative: str,
    authority_fd: int,
    restored_root_fd: int,
    request: dict[str, object],
    request_digest: str,
    approval_digest: str,
    audit_digest: str,
    backup_digest: str,
    result: dict[str, object],
    result_digest: str,
) -> tuple[dict[str, object], str, bool]:
    expected = {
        "schema": "legacy-archive-recovery-receipt/v1",
        "request_sha256": request_digest,
        "approval_sha256": approval_digest,
        "audit_sha256": audit_digest,
        "backup_sha256": backup_digest,
        "source_archive_manifest_sha256": request["archive_manifest_sha256"],
        "executor_result_sha256": result_digest,
        "plan_seal": request["plan_seal"],
        "restored_root": request["restore_target"],
        "g0_sha256": result["restored_root_sha256"],
        "pre_receipt_generation_sha256": result["restored_root_sha256"],
        "source_archive_destination": request["archive_destination"],
        "original_phase": result["original_phase"],
        "original_phase_status": result["original_phase_status"],
        "outcome": "success",
    }
    data = canonical_json(expected)
    def mutation_guard() -> None:
        require_descriptor_binding(repo_fd, authority_relative, authority_fd)

    def receipt_resume_guard() -> None:
        mutation_guard()
        expected_records = {
            "request.json": request_digest,
            "approval.json": approval_digest,
            "audit.json": audit_digest,
            "backup.json": backup_digest,
            "executor-result.json": result_digest,
        }
        for record_name, expected_digest in expected_records.items():
            if file_sha256_at(authority_fd, record_name) != expected_digest:
                reject("recovery restore", f"receipt predecessor changed {record_name}")
        if (
            restored_root_fd < 0
            or recovery_generation_at(
                restored_root_fd,
                exclude=RECOVERY_TRANSIENT_NAMES,
            )
            != result["restored_root_sha256"]
        ):
            reject("recovery restore", "receipt temporary lacks its G0 generation")
        mutation_guard()

    existing = optional_json_record_at(
        authority_fd,
        "receipt.json",
        "legacy-archive-recovery-receipt/v1",
    )
    if existing is not None:
        payload, digest = existing
        if payload != expected:
            reject("recovery restore", "receipt pins do not match recovery authority")
        try:
            os.stat(".receipt.json.tmp", dir_fd=authority_fd, follow_symlinks=False)
        except FileNotFoundError:
            pass
        else:
            publish_resumable_file_at(
                authority_fd,
                "receipt.json",
                ".receipt.json.tmp",
                data,
                mutation_guard=mutation_guard,
                failure_kind="recovery restore",
                allow_partial_resume=True,
                retain_temporary=True,
                resume_guard=receipt_resume_guard,
            )
        return payload, digest, False
    if restored_root_fd < 0:
        reject("recovery restore", "restored generation is missing before receipt publication")
    if recovery_generation_at(restored_root_fd) != result["restored_root_sha256"]:
        reject("recovery generation", "pre-receipt G0 digest mismatch")
    published = publish_resumable_file_at(
        authority_fd,
        "receipt.json",
        ".receipt.json.tmp",
        data,
        mutation_guard=mutation_guard,
        failure_after_temporary="recovery-receipt-temp-only",
        failure_kind="recovery restore",
        allow_partial_resume=True,
        retain_temporary=True,
        resume_guard=receipt_resume_guard,
    )
    mutation_guard()
    return expected, hashlib.sha256(data).hexdigest(), published


def validate_pinned_recovery_sources(
    backup_fd: int,
    source_archive_fd: int,
    backup: dict[str, object],
    request: dict[str, object],
) -> list[dict[str, object]]:
    expected_manifest = request.get("archive_manifest_sha256")
    expected_journal = request.get("ownership_journal_sha256")
    backup_entries = validate_recovery_archive_snapshot(
        backup_fd,
        expected_manifest,
        expected_journal,
        failure_kind="recovery restore",
    )
    backup_tree_digest = hashlib.sha256(canonical_json({"entries": backup_entries})).hexdigest()
    if backup.get("entries") != backup_entries or backup.get("tree_sha256") != backup_tree_digest:
        reject("recovery restore", "audit-pinned backup changed")
    source_entries = validate_recovery_archive_snapshot(
        source_archive_fd,
        expected_manifest,
        expected_journal,
        failure_kind="recovery restore",
    )
    if source_entries != backup_entries:
        reject("recovery restore", "source incomplete archive changed")
    return [
        entry
        for entry in backup_entries
        if not _recovery_excluded(str(entry["path"]), RECOVERY_CONTROL_NAMES)
    ]


def reserve_recovery_destination(
    repo_fd: int,
    authority_fd: int,
    authority_relative: str,
    archive_family_fd: int,
    destination: str,
    request: dict[str, object],
    receipt_digest: str,
    g0_sha256: str,
    *,
    allow_archive_entries: bool,
) -> int:
    destination_rel = repo_relative(destination)
    if len(destination_rel.parts) != 3 or destination_rel.parts[:2] != (".release-loop", "archive"):
        reject("path boundary", destination)
    expected = canonical_json({
        "schema": "legacy-archive-recovery-reservation/v1",
        "recovery_id": request["recovery_id"],
        "receipt_sha256": receipt_digest,
        "g0_sha256": g0_sha256,
        "destination": destination,
    })
    destination_fd = -1
    require_descriptor_binding(repo_fd, authority_relative, authority_fd)
    require_descriptor_binding(repo_fd, ".release-loop/archive", archive_family_fd)
    try:
        created = False
        try:
            destination_fd = create_and_open_directory_at(archive_family_fd, destination_rel.name)
            created = True
        except FileExistsError:
            destination_fd = os.open(destination_rel.name, DIRECTORY_OPEN_FLAGS, dir_fd=archive_family_fd)
        require_descriptor_binding(repo_fd, destination, destination_fd)
        if created and test_failure("recovery-after-destination-mkdir"):
            reject("injected recovery interruption", "after destination mkdir")
        reservation_temporary = RECOVERY_RESERVATION_NAME + ".tmp"
        destination_names = set(os.listdir(destination_fd))
        reservation_exists = RECOVERY_RESERVATION_NAME in destination_names
        receipt_marker = validate_linked_publication_temporary(
            authority_fd,
            "receipt.json",
            ".receipt.json.tmp",
            receipt_digest,
            required=not reservation_exists,
            failure_kind="recovery archive",
        )
        allowed = {RECOVERY_RESERVATION_NAME, reservation_temporary}
        if not allow_archive_entries and destination_names - allowed:
            reject("recovery archive", "reserved destination contains foreign entries")
        def destination_guard() -> None:
            require_descriptor_binding(repo_fd, destination, destination_fd)

        def reservation_resume_guard() -> None:
            require_descriptor_binding(repo_fd, authority_relative, authority_fd)
            destination_guard()
            validate_linked_publication_temporary(
                authority_fd,
                "receipt.json",
                ".receipt.json.tmp",
                receipt_digest,
                required=True,
                failure_kind="recovery archive",
            )
            destination_guard()

        publish_resumable_file_at(
            destination_fd,
            RECOVERY_RESERVATION_NAME,
            reservation_temporary,
            expected,
            mutation_guard=destination_guard,
            failure_after_temporary="recovery-reservation-temp-only",
            failure_kind="recovery archive",
            allow_partial_resume=True,
            resume_guard=reservation_resume_guard,
        )
        destination_guard()
        require_descriptor_binding(repo_fd, authority_relative, authority_fd)
        if receipt_marker is not None:
            unlink_linked_publication_temporary(
                authority_fd,
                ".receipt.json.tmp",
                receipt_marker,
                failure_kind="recovery archive",
            )
            require_descriptor_binding(repo_fd, authority_relative, authority_fd)
        if not allow_archive_entries and set(os.listdir(destination_fd)) != {
            RECOVERY_RESERVATION_NAME
        }:
            reject("recovery archive", "reserved destination contains foreign entries")
        return destination_fd
    except Exception:
        if destination_fd >= 0:
            os.close(destination_fd)
        raise


def validate_recovery_destination_reservation(
    repo_fd: int,
    destination_fd: int,
    destination: str,
    request: dict[str, object],
    receipt_digest: str,
    g0_sha256: str,
) -> None:
    expected = canonical_json({
        "schema": "legacy-archive-recovery-reservation/v1",
        "recovery_id": request["recovery_id"],
        "receipt_sha256": receipt_digest,
        "g0_sha256": g0_sha256,
        "destination": destination,
    })
    require_descriptor_binding(repo_fd, destination, destination_fd)
    if read_file_at(destination_fd, RECOVERY_RESERVATION_NAME) != expected:
        reject("recovery archive", "destination reservation changed")


def finalize_recovery_archive(
    repo_fd: int,
    target_parent_fd: int,
    target_fd: int,
    target_relative: str,
    destination_fd: int,
    destination: str,
    expected_entries: list[dict[str, object]],
    request: dict[str, object],
    receipt_digest: str,
    g0_sha256: str,
    source_journal_data: bytes,
    commit_guard: Callable[[], object],
) -> str:
    destination_rel = repo_relative(destination)
    if len(destination_rel.parts) != 3 or destination_rel.parts[:2] != (".release-loop", "archive"):
        reject("path boundary", destination)
    validate_recovery_payload_namespace(
        expected_entries,
        failure_kind="recovery archive",
    )
    manifest_data = canonical_json({"schema": ARCHIVE_MANIFEST_SCHEMA, "entries": expected_entries})
    manifest_digest = hashlib.sha256(manifest_data).hexdigest()
    journal_data = recovery_archive_journal_bytes(
        source_journal_data,
        expected_entries,
        manifest_digest,
    )
    def destination_guard() -> None:
        require_descriptor_binding(repo_fd, destination, destination_fd)

    if target_fd >= 0:
        require_descriptor_binding(repo_fd, target_relative, target_fd)
    validate_recovery_destination_reservation(
        repo_fd,
        destination_fd,
        destination,
        request,
        receipt_digest,
        g0_sha256,
    )

    def archive_resume_guard() -> None:
        destination_guard()
        validate_recovery_destination_reservation(
            repo_fd,
            destination_fd,
            destination,
            request,
            receipt_digest,
            g0_sha256,
        )
        commit_guard()
        destination_guard()

    publication_claims: set[str] = set()

    def validate_existing_publication(
        final_name: str,
        temporary_name: str,
        expected_data: bytes,
    ) -> None:
        claim_name, claim_data = recovery_publication_claim(
            final_name,
            str(request["recovery_id"]),
            expected_data,
        )
        claim_relative = (PurePosixPath(final_name).parent / claim_name).as_posix()
        publication_claims.add(claim_relative)
        try:
            final_stat = os.stat(final_name, dir_fd=destination_fd, follow_symlinks=False)
        except FileNotFoundError:
            final_stat = None
        try:
            temporary_stat = os.stat(
                temporary_name,
                dir_fd=destination_fd,
                follow_symlinks=False,
            )
        except FileNotFoundError:
            temporary_stat = None
        try:
            claim_stat = os.stat(
                claim_relative,
                dir_fd=destination_fd,
                follow_symlinks=False,
            )
        except FileNotFoundError:
            claim_stat = None
        if final_stat is not None and read_file_at(destination_fd, final_name) != expected_data:
            reject("recovery archive", f"changed partial final {final_name}")
        if temporary_stat is not None:
            if claim_stat is None:
                reject("recovery archive", f"foreign publication temporary {temporary_name}")
            archive_resume_guard()
            temporary_data = read_file_at(destination_fd, temporary_name)
            if not expected_data.startswith(temporary_data):
                reject("recovery archive", f"changed partial temporary {temporary_name}")
            if final_stat is not None and (
                final_stat.st_dev,
                final_stat.st_ino,
            ) != (temporary_stat.st_dev, temporary_stat.st_ino):
                reject("recovery archive", f"foreign partial temporary {temporary_name}")
        if claim_stat is not None:
            archive_resume_guard()
            if read_file_at(destination_fd, claim_relative) != claim_data:
                reject("recovery archive", f"foreign publication claim {claim_relative}")

    manifest_temporary = ARCHIVE_MANIFEST_NAME + ".recovery.tmp"
    journal_temporary = JOURNAL_NAME + ".recovery.tmp"
    manifest_claim = recovery_publication_claim(
        ARCHIVE_MANIFEST_NAME,
        str(request["recovery_id"]),
        manifest_data,
    )
    journal_claim = recovery_publication_claim(
        JOURNAL_NAME,
        str(request["recovery_id"]),
        journal_data,
    )
    validate_existing_publication(
        ARCHIVE_MANIFEST_NAME,
        manifest_temporary,
        manifest_data,
    )
    validate_existing_publication(JOURNAL_NAME, journal_temporary, journal_data)
    payload_temporaries: set[str] = set()
    if target_fd >= 0:
        for entry in expected_entries:
            if entry.get("kind") != "file":
                continue
            relative = str(entry["path"])
            relative_path = PurePosixPath(relative)
            temporary_name = (
                ".legacy-archive-recovery-pending-"
                + hashlib.sha256(relative.encode("utf-8")).hexdigest()
                + ".tmp"
            )
            temporary_relative = (relative_path.parent / temporary_name).as_posix()
            payload_temporaries.add(temporary_relative)
            validate_existing_publication(
                relative,
                temporary_relative,
                read_file_at(target_fd, relative),
            )
    excluded_partial = frozenset({
        *RECOVERY_ARCHIVE_CONTROL_NAMES,
        manifest_temporary,
        journal_temporary,
        *payload_temporaries,
        *publication_claims,
    })
    observed_partial = recovery_tree_at(destination_fd, exclude=excluded_partial)
    if not recovery_entries_are_subset(observed_partial, expected_entries):
        reject("recovery archive", "partial destination contains foreign entries")
    publish_resumable_file_at(
        destination_fd,
        ARCHIVE_MANIFEST_NAME,
        manifest_temporary,
        manifest_data,
        mutation_guard=destination_guard,
        failure_kind="recovery archive",
        allow_partial_resume=True,
        resume_guard=archive_resume_guard,
        ownership_claim_name=manifest_claim[0],
        ownership_claim_data=manifest_claim[1],
    )
    if test_failure("recovery-archive-manifest-only"):
        reject("injected recovery interruption", "after archive manifest")
    publish_resumable_file_at(
        destination_fd,
        JOURNAL_NAME,
        journal_temporary,
        journal_data,
        mutation_guard=destination_guard,
        failure_kind="recovery archive",
        allow_partial_resume=True,
        resume_guard=archive_resume_guard,
        ownership_claim_name=journal_claim[0],
        ownership_claim_data=journal_claim[1],
    )
    if test_failure("recovery-archive-journal-only"):
        reject("injected recovery interruption", "after archive journal")
    if target_fd >= 0:
        require_descriptor_binding(repo_fd, target_relative, target_fd)
        destination_guard()
        copy_recovery_tree_at(
            target_fd,
            destination_fd,
            exclude=RECOVERY_ARCHIVE_CONTROL_NAMES,
            progress_last=True,
            allow_existing=True,
            resumable_publication=True,
            publication_recovery_id=str(request["recovery_id"]),
            failure_after_first_file="recovery-archive-payload-mid-file",
            failure_before_progress="recovery-archive-before-progress",
            publication_resume_guard=archive_resume_guard,
            source_guard=lambda: require_descriptor_binding(repo_fd, target_relative, target_fd),
            target_mutation_guard=destination_guard,
        )
    if recovery_tree_at(destination_fd, exclude=RECOVERY_ARCHIVE_CONTROL_NAMES) != expected_entries:
        reject("recovery archive", "completed archive bytes do not match G3")
    commit_guard()
    destination_guard()
    if target_fd >= 0 and test_failure("recovery-before-cleanup-foreign"):
        write_file_exclusive_at(target_fd, ".injected-foreign-cleanup", b"FOREIGN\n")
    if target_fd >= 0 and recovery_tree_at(target_fd) != expected_entries:
        reject("recovery archive", "target changed before cleanup")
    cleanup_recovery_target(
        repo_fd,
        target_parent_fd,
        target_fd,
        target_relative,
        expected_entries,
        str(request["recovery_id"]),
    )
    cleanup_parent, cleanup_name, _cleanup_relative = recovery_cleanup_location(
        target_relative,
        str(request["recovery_id"]),
    )
    require_descriptor_binding(
        repo_fd,
        cleanup_parent,
        target_parent_fd,
    )
    for residue in (repo_relative(target_relative).name, cleanup_name):
        try:
            os.stat(residue, dir_fd=target_parent_fd, follow_symlinks=False)
        except FileNotFoundError:
            continue
        reject("recovery archive", f"recovery cleanup residue remains: {residue}")
    commit_guard()
    if (
        read_file_at(destination_fd, ARCHIVE_MANIFEST_NAME) != manifest_data
        or read_file_at(destination_fd, JOURNAL_NAME) != journal_data
        or recovery_tree_at(destination_fd, exclude=RECOVERY_ARCHIVE_CONTROL_NAMES)
        != expected_entries
    ):
        reject("recovery archive", "archive changed before cleanup commit")
    destination_guard()
    os.unlink(RECOVERY_RESERVATION_NAME, dir_fd=destination_fd)
    os.fsync(destination_fd)
    destination_guard()
    if recovery_tree_at(destination_fd, exclude=RECOVERY_CONTROL_NAMES) != expected_entries:
        reject("recovery archive", "completed archive changed at commit")
    return manifest_digest


def validate_recovery_archive_at(
    repo_fd: int,
    destination_fd: int,
    destination: str,
    request: dict[str, object],
    receipt: dict[str, object],
    receipt_digest: str,
    source_journal_data: bytes,
    *,
    reserved: bool,
) -> tuple[str, list[dict[str, object]]]:
    names = set(os.listdir(destination_fd))
    if (RECOVERY_RESERVATION_NAME in names) != reserved:
        reject("recovery archive", "archive reservation state mismatch")
    manifest_data = read_file_at(destination_fd, ARCHIVE_MANIFEST_NAME)
    manifest = read_archive_manifest_bytes(manifest_data)
    excluded = RECOVERY_ARCHIVE_CONTROL_NAMES if reserved else RECOVERY_CONTROL_NAMES
    if recovery_tree_at(destination_fd, exclude=excluded) != manifest["entries"]:
        reject("recovery archive", "completed archive manifest mismatch")
    validate_recovery_payload_namespace(
        manifest["entries"],
        failure_kind="recovery archive",
    )
    manifest_digest = hashlib.sha256(manifest_data).hexdigest()
    expected_journal_data = recovery_archive_journal_bytes(
        source_journal_data,
        manifest["entries"],
        manifest_digest,
    )
    if read_file_at(destination_fd, JOURNAL_NAME) != expected_journal_data:
        reject("recovery archive", "ownership journal differs from pinned source")
    validate_recovery_archive_controls(destination_fd, manifest_data)
    progress_text = read_file_at(destination_fd, "progress.md").decode("utf-8")
    state, stored, _values = recovery_progress_state(
        destination_fd,
        progress_text,
        request,
        receipt,
        receipt_digest,
        generation_exclude=excluded,
    )
    if state != "g3" or stored != destination:
        reject("recovery archive", "completed recovery state is invalid")
    require_descriptor_binding(repo_fd, destination, destination_fd)
    return manifest_digest, manifest["entries"]


def restore_legacy_archive(repo: Path, recovery_id: str) -> dict[str, object]:
    validate_recovery_id(recovery_id)
    repo_fd = open_repo_descriptor(repo)
    authority_fd = -1
    backup_fd = -1
    source_archive_fd = -1
    target_parent_fd = -1
    target_fd = -1
    archive_family_fd = -1
    destination_fd = -1
    authority_relative = f"{RECOVERY_AUTHORITY_ROOT}/{recovery_id}"
    try:
        authority_fd = open_dir_chain(repo_fd, authority_relative)
        acquire_recovery_lock(
            repo_fd,
            authority_relative,
            authority_fd,
            "recovery restore",
        )
        hold_recovery_lock_for_test()
        request, request_digest = read_json_record_at(authority_fd, "request.json", RECOVERY_REQUEST_SCHEMA)
        approval, approval_digest = read_json_record_at(authority_fd, "approval.json", RECOVERY_APPROVAL_SCHEMA)
        gate_receipt, gate_receipt_digest = read_json_record_at(
            authority_fd,
            "gate-receipt.json",
            RECOVERY_GATE_RECEIPT_SCHEMA,
        )
        audit, audit_digest = read_json_record_at(
            authority_fd,
            "audit.json",
            "legacy-archive-recovery-audit/v1",
        )
        backup, backup_digest = read_json_record_at(
            authority_fd,
            "backup.json",
            "legacy-archive-recovery-backup/v1",
        )
        if (
            approval.get("request_sha256") != request_digest
            or approval.get("gate_receipt_path") != f"{authority_relative}/gate-receipt.json"
            or approval.get("gate_receipt_sha256") != gate_receipt_digest
            or audit.get("verdict") != "accepted"
            or audit.get("request_sha256") != request_digest
            or audit.get("approval_sha256") != approval_digest
            or audit.get("gate_receipt_sha256") != gate_receipt_digest
            or audit.get("backup_sha256") != backup_digest
        ):
            reject("recovery restore", "accepted authority chain does not match request")
        validate_gate_receipt_snapshot(request, gate_receipt, request_digest)
        backup_relative = str(request.get("backup_root", ""))
        source_archive_relative = str(request.get("archive_destination", ""))
        target_relative = str(request.get("restore_target", ""))
        if (
            backup_relative != f"{RECOVERY_BACKUP_ROOT}/{recovery_id}"
            or target_relative != f".release-loop/runs/{request.get('feature')}"
        ):
            reject("recovery restore", "recovery root identity mismatch")
        backup_fd = open_dir_chain(repo_fd, backup_relative)
        source_archive_fd = open_dir_chain(repo_fd, source_archive_relative)

        def validate_restore_sources() -> list[dict[str, object]]:
            require_descriptor_binding(repo_fd, backup_relative, backup_fd)
            require_descriptor_binding(repo_fd, source_archive_relative, source_archive_fd)
            return validate_pinned_recovery_sources(
                backup_fd,
                source_archive_fd,
                backup,
                request,
            )

        expected_payload = validate_restore_sources()
        source_journal_data = read_file_at(source_archive_fd, JOURNAL_NAME)
        target_parent_relative = PurePosixPath(*repo_relative(target_relative).parts[:-1]).as_posix()
        target_parent_fd = open_dir_chain(repo_fd, target_parent_relative)
        archive_family_fd = open_dir_chain(repo_fd, ".release-loop/archive")
        started = optional_json_record_at(
            authority_fd,
            "executor-started.json",
            "legacy-archive-recovery-executor-start/v1",
        )
        result_record = optional_json_record_at(
            authority_fd,
            "executor-result.json",
            "legacy-archive-recovery-executor-result/v1",
        )
        destination = recovery_destination(request)
        if result_record is None:
            if started is not None:
                reject("recovery restore", "executor claim is ambiguous without a result")
            try:
                target_fd = os.open(repo_relative(target_relative).name, DIRECTORY_OPEN_FLAGS, dir_fd=target_parent_fd)
            except FileNotFoundError:
                target_fd = -1
            if target_fd >= 0:
                reject("recovery restore", "restore target is occupied")
            started_payload = {
                "schema": "legacy-archive-recovery-executor-start/v1",
                "audit_sha256": audit_digest,
                "backup_sha256": backup_digest,
                "recovery_id": recovery_id,
                "process_id": os.getpid(),
                "started_at": utc_now(),
            }
            require_descriptor_binding(repo_fd, authority_relative, authority_fd)
            started_digest = publish_bound_record_at(
                repo_fd,
                authority_relative,
                authority_fd,
                "executor-started.json",
                started_payload,
            )
            require_descriptor_binding(repo_fd, authority_relative, authority_fd)
            require_descriptor_binding(repo_fd, target_parent_relative, target_parent_fd)
            target_name = repo_relative(target_relative).name
            os.mkdir(target_name, mode=0o700, dir_fd=target_parent_fd)
            os.fsync(target_parent_fd)
            created_target = os.stat(target_name, dir_fd=target_parent_fd, follow_symlinks=False)
            inject_recovery_target_create_swap(repo, recovery_id, target_relative)
            target_fd = os.open(target_name, DIRECTORY_OPEN_FLAGS, dir_fd=target_parent_fd)
            opened_target = os.fstat(target_fd)
            if (created_target.st_dev, created_target.st_ino) != (opened_target.st_dev, opened_target.st_ino):
                reject("path boundary", "created restore target changed while opening")
            inject_recovery_ancestor_replacement(repo, recovery_id)
            require_descriptor_binding(repo_fd, target_relative, target_fd)
            inject_recovery_source_change(backup_fd, source_archive_fd)
            if validate_restore_sources() != expected_payload:
                reject("recovery restore", "pinned payload changed before copy")
            copy_recovery_tree_at(
                backup_fd,
                target_fd,
                exclude=RECOVERY_CONTROL_NAMES,
                progress_last=True,
                source_guard=lambda: require_descriptor_binding(repo_fd, backup_relative, backup_fd),
                target_mutation_guard=lambda: require_descriptor_binding(
                    repo_fd,
                    target_relative,
                    target_fd,
                ),
            )
            if recovery_tree_at(target_fd) != expected_payload:
                reject("recovery restore", "restored payload differs from audited backup")
            validate_restore_sources()
            progress_data = read_file_at(target_fd, "progress.md")
            progress_values, _ = parse_frontmatter(progress_data.decode("utf-8"), target_relative + "/progress.md")
            g0 = recovery_generation_at(target_fd)
            result = {
                "schema": "legacy-archive-recovery-executor-result/v1",
                "started_sha256": started_digest,
                "backup_sha256": backup_digest,
                "outcome": "success",
                "restored_root": target_relative,
                "restored_root_sha256": g0,
                "original_phase": progress_values["phase"],
                "original_phase_status": progress_values["phase_status"],
                "finished_at": utc_now(),
            }
            require_descriptor_binding(repo_fd, authority_relative, authority_fd)
            require_descriptor_binding(repo_fd, backup_relative, backup_fd)
            require_descriptor_binding(repo_fd, source_archive_relative, source_archive_fd)
            require_descriptor_binding(repo_fd, target_relative, target_fd)
            result_digest = publish_bound_record_at(
                repo_fd,
                authority_relative,
                authority_fd,
                "executor-result.json",
                result,
            )
            require_descriptor_binding(repo_fd, authority_relative, authority_fd)
            if test_failure("recovery-after-g0"):
                reject("injected recovery interruption", "after G0")
        else:
            result, result_digest = result_record
            if started is None:
                reject("recovery restore", "executor result lacks its started claim")
            started_payload, started_digest = started
            if (
                result.get("started_sha256") != started_digest
                or result.get("backup_sha256") != backup_digest
                or result.get("outcome") != "success"
                or result.get("restored_root") != target_relative
            ):
                reject("recovery restore", "executor result pin mismatch")
            try:
                target_fd = os.open(repo_relative(target_relative).name, DIRECTORY_OPEN_FLAGS, dir_fd=target_parent_fd)
            except FileNotFoundError:
                target_fd = -1
            if target_fd >= 0:
                require_descriptor_binding(repo_fd, target_relative, target_fd)
        approval_record, observed_approval_digest = read_json_record_at(
            authority_fd,
            "approval.json",
            RECOVERY_APPROVAL_SCHEMA,
        )
        observed_gate_receipt, observed_gate_receipt_digest = read_json_record_at(
            authority_fd,
            "gate-receipt.json",
            RECOVERY_GATE_RECEIPT_SCHEMA,
        )
        if (
            approval_record != approval
            or observed_approval_digest != approval_digest
            or observed_gate_receipt != gate_receipt
            or observed_gate_receipt_digest != gate_receipt_digest
        ):
            reject("recovery restore", "approval changed during restore")
        validate_gate_receipt_snapshot(request, observed_gate_receipt, request_digest)
        validate_restore_sources()
        receipt, receipt_digest, published_receipt = validate_or_publish_recovery_receipt(
            repo_fd,
            authority_relative,
            authority_fd,
            target_fd,
            request,
            request_digest,
            approval_digest,
            audit_digest,
            backup_digest,
            result,
            result_digest,
        )
        require_descriptor_binding(repo_fd, authority_relative, authority_fd)
        if published_receipt and test_failure("recovery-after-receipt"):
            reject("injected recovery interruption", "after receipt")
        if target_fd < 0:
            destination_fd = open_dir_chain(repo_fd, destination)
            destination_names = set(os.listdir(destination_fd))
            if RECOVERY_RESERVATION_NAME not in destination_names:
                _parent, cleanup_name, _cleanup_relative = recovery_cleanup_location(
                    target_relative,
                    recovery_id,
                )
                try:
                    os.stat(cleanup_name, dir_fd=target_parent_fd, follow_symlinks=False)
                except FileNotFoundError:
                    pass
                else:
                    reject("recovery archive", "cleanup residue lacks its reservation")
                manifest_digest, _entries = validate_recovery_archive_at(
                    repo_fd,
                    destination_fd,
                    destination,
                    request,
                    receipt,
                    receipt_digest,
                    source_journal_data,
                    reserved=False,
                )
                return {
                    "archive_manifest_sha256": manifest_digest,
                    "progress_path": destination + "/progress.md",
                    "recovery_id": recovery_id,
                    "state": "archived",
                }
            validate_recovery_destination_reservation(
                repo_fd,
                destination_fd,
                destination,
                request,
                receipt_digest,
                str(receipt["g0_sha256"]),
            )
            _reserved_digest, expected_g3_entries = validate_recovery_archive_at(
                repo_fd,
                destination_fd,
                destination,
                request,
                receipt,
                receipt_digest,
                source_journal_data,
                reserved=True,
            )
            manifest_digest = finalize_recovery_archive(
                repo_fd,
                target_parent_fd,
                target_fd,
                target_relative,
                destination_fd,
                destination,
                expected_g3_entries,
                request,
                receipt_digest,
                str(receipt["g0_sha256"]),
                source_journal_data,
                validate_restore_sources,
            )
            completed_digest, _completed_entries = validate_recovery_archive_at(
                repo_fd,
                destination_fd,
                destination,
                request,
                receipt,
                receipt_digest,
                source_journal_data,
                reserved=False,
            )
            if completed_digest != manifest_digest:
                reject("recovery archive", "archive manifest changed after cleanup commit")
            return {
                "archive_manifest_sha256": manifest_digest,
                "progress_path": destination + "/progress.md",
                "recovery_id": recovery_id,
                "state": "archived",
            }
        inject_recovery_ancestor_replacement(
            repo,
            recovery_id,
            "recovery-before-g1-ancestor",
        )
        progress_text = read_file_at(target_fd, "progress.md").decode("utf-8")
        state, selected_destination, values = recovery_progress_state(
            target_fd,
            progress_text,
            request,
            receipt,
            receipt_digest,
        )
        if selected_destination is not None and selected_destination != destination:
            reject("recovery archive", "recorded destination differs from reservation")
        destination_fd = reserve_recovery_destination(
            repo_fd,
            authority_fd,
            authority_relative,
            archive_family_fd,
            destination,
            request,
            receipt_digest,
            str(receipt["g0_sha256"]),
            allow_archive_entries=state == "g3",
        )
        if state == "g0":
            validate_restore_sources()
            validate_recovery_destination_reservation(
                repo_fd,
                destination_fd,
                destination,
                request,
                receipt_digest,
                str(receipt["g0_sha256"]),
            )
            selected_destination = destination
            prior_updated = _top_level_progress_value(progress_text, "updated")
            request_issued = str(request.get("issued_at", ""))
            minimum_updated = prior_updated
            if _recovery_timestamp(
                request_issued,
                "invalid request timestamp",
            ) > _recovery_timestamp(prior_updated, "invalid G0 updated timestamp"):
                minimum_updated = request_issued
            timestamp = recovery_progress_transition_timestamp(
                target_fd,
                "legacy_archive_recovery: staged:",
                minimum_updated,
            )
            staged_line = (
                f"- {timestamp} legacy_archive_recovery: staged: recovery-id={recovery_id} "
                f"receipt-sha256={receipt_digest} g0-sha256={receipt['g0_sha256']} "
                f"destination={selected_destination} prior-updated={prior_updated}"
            )
            destination_line = (
                f"- {timestamp} retro: archive-destination: {selected_destination} "
                f"recovery-id={recovery_id} receipt-sha256={receipt_digest} "
                f"g0-sha256={receipt['g0_sha256']}"
            )
            g1_text = _replace_progress_field(progress_text, "updated", timestamp)
            g1_text = _append_progress_line(g1_text, staged_line)
            g1_text = _append_progress_line(g1_text, destination_line)
            replace_recovery_progress_generation(
                repo_fd,
                target_relative,
                target_fd,
                str(receipt["g0_sha256"]),
                g1_text.encode("utf-8"),
                after_binding=lambda: inject_recovery_progress_after_binding_swap(
                    repo,
                    recovery_id,
                    target_relative,
                ),
                failure_after_temporary="recovery-progress-g1-temp-only",
            )
            progress_text = g1_text
            state = "g1"
            if test_failure("recovery-after-g1"):
                reject("injected recovery interruption", "after G1")
        if state == "g1":
            validate_restore_sources()
            validate_recovery_destination_reservation(
                repo_fd,
                destination_fd,
                destination,
                request,
                receipt_digest,
                str(receipt["g0_sha256"]),
            )
            g1 = recovery_generation_at(target_fd, exclude=RECOVERY_TRANSIENT_NAMES)
            prior_updated = _top_level_progress_value(progress_text, "updated")
            timestamp = recovery_progress_transition_timestamp(
                target_fd,
                "legacy-pre-archive-verification: accepted:",
                prior_updated,
            )
            accepted_line = (
                f"- {timestamp} legacy-pre-archive-verification: accepted: "
                f"recovery-id={recovery_id} receipt-sha256={receipt_digest} "
                f"g1-sha256={g1} destination={selected_destination} "
                f"source={request['archive_destination']} prior-updated={prior_updated}"
            )
            g2_text = _replace_progress_field(progress_text, "updated", timestamp)
            g2_text = _append_progress_line(g2_text, accepted_line)
            replace_recovery_progress_generation(
                repo_fd,
                target_relative,
                target_fd,
                g1,
                g2_text.encode("utf-8"),
                failure_after_temporary="recovery-progress-g2-temp-only",
            )
            progress_text = g2_text
            state = "g2"
            if test_failure("recovery-after-g2"):
                reject("injected recovery interruption", "after G2")
        if state == "g2":
            validate_restore_sources()
            validate_recovery_destination_reservation(
                repo_fd,
                destination_fd,
                destination,
                request,
                receipt_digest,
                str(receipt["g0_sha256"]),
            )
            g2 = recovery_generation_at(target_fd, exclude=RECOVERY_TRANSIENT_NAMES)
            prior_phase = values["phase"]
            prior_status = values["phase_status"]
            prior_updated = _top_level_progress_value(progress_text, "updated")
            timestamp = recovery_progress_transition_timestamp(
                target_fd,
                "legacy_archive_recovery: completed:",
                prior_updated,
            )
            g3_text = _replace_progress_field(progress_text, "phase", "done")
            g3_text = _replace_progress_field(g3_text, "phase_status", "complete")
            g3_text = _replace_progress_field(g3_text, "updated", timestamp)
            completed_line = (
                f"- {timestamp} legacy_archive_recovery: completed: recovery-id={recovery_id} "
                f"receipt-sha256={receipt_digest} g2-sha256={g2} "
                f"destination={selected_destination} prior-phase={prior_phase} "
                f"prior-status={prior_status} prior-updated={prior_updated}"
            )
            g3_text = _append_progress_line(g3_text, completed_line)
            replace_recovery_progress_generation(
                repo_fd,
                target_relative,
                target_fd,
                g2,
                g3_text.encode("utf-8"),
                failure_after_temporary="recovery-progress-g3-temp-only",
            )
            progress_text = g3_text
            state = "g3"
            if test_failure("recovery-after-g3"):
                reject("injected recovery interruption", "after G3")
        expected_g3_entries = recovery_tree_at(target_fd)
        verified_state, verified_destination, _ = recovery_progress_state(
            target_fd,
            progress_text,
            request,
            receipt,
            receipt_digest,
        )
        if verified_state != "g3" or verified_destination != destination:
            reject("recovery restore", "only G3 may enter recovery archive")
        validate_restore_sources()
        require_descriptor_binding(repo_fd, authority_relative, authority_fd)
        require_descriptor_binding(repo_fd, backup_relative, backup_fd)
        require_descriptor_binding(repo_fd, source_archive_relative, source_archive_fd)
        require_descriptor_binding(repo_fd, target_relative, target_fd)
        manifest_digest = finalize_recovery_archive(
            repo_fd,
            target_parent_fd,
            target_fd,
            target_relative,
            destination_fd,
            destination,
            expected_g3_entries,
            request,
            receipt_digest,
            str(receipt["g0_sha256"]),
            source_journal_data,
            validate_restore_sources,
        )
        completed_digest, _completed_entries = validate_recovery_archive_at(
            repo_fd,
            destination_fd,
            destination,
            request,
            receipt,
            receipt_digest,
            source_journal_data,
            reserved=False,
        )
        if completed_digest != manifest_digest:
            reject("recovery archive", "archive manifest changed after cleanup commit")
        validate_restore_sources()
        return {
            "archive_manifest_sha256": manifest_digest,
            "progress_path": destination + "/progress.md",
            "recovery_id": recovery_id,
            "state": "archived",
        }
    except (FileNotFoundError, NotADirectoryError):
        reject("recovery restore", "required recovery root is unavailable")
    finally:
        for descriptor in (
            destination_fd,
            archive_family_fd,
            target_fd,
            target_parent_fd,
            source_archive_fd,
            backup_fd,
            authority_fd,
            repo_fd,
        ):
            if descriptor >= 0:
                os.close(descriptor)


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


def git_blob(repo: Path, revision: str, relative: str) -> bytes:
    result = subprocess.run(
        ("git", "show", f"{revision}:{relative}"),
        cwd=repo,
        capture_output=True,
        check=False,
    )
    if result.returncode != 0:
        reject("recovery provenance", f"missing Git blob {revision}:{relative}")
    return result.stdout


def require_commit(repo: Path, revision: str) -> None:
    result = subprocess.run(
        ("git", "cat-file", "-e", f"{revision}^{{commit}}"),
        cwd=repo,
        capture_output=True,
        check=False,
    )
    if result.returncode != 0:
        reject("recovery provenance", f"missing Git commit {revision}")


def require_ancestor(repo: Path, ancestor: str, descendant: str) -> None:
    result = subprocess.run(
        ("git", "merge-base", "--is-ancestor", ancestor, descendant),
        cwd=repo,
        capture_output=True,
        check=False,
    )
    if result.returncode != 0:
        reject("recovery provenance", "plan approval is not before contract introduction")


def validate_recovery_provenance(repo: Path, request: dict[str, object]) -> dict[str, str]:
    plan_path = request.get("plan_path")
    plan_seal = request.get("plan_seal")
    approval_commit = request.get("plan_approval_commit")
    introduction_commit = request.get("contract_introduction_commit")
    if not all(isinstance(value, str) and value for value in (plan_path, plan_seal, approval_commit, introduction_commit)):
        reject("recovery provenance", "sealed plan and contract commits are required")
    plan_rel = repo_relative(str(plan_path)).as_posix()
    if not SHA_PATTERN.fullmatch(str(plan_seal)):
        reject("recovery provenance", "invalid plan seal")
    if not re.fullmatch(r"[0-9a-f]{40}", str(approval_commit)) or not re.fullmatch(r"[0-9a-f]{40}", str(introduction_commit)):
        reject("recovery provenance", "invalid Git commit")
    require_commit(repo, str(approval_commit))
    require_commit(repo, str(introduction_commit))
    if str(approval_commit) == str(introduction_commit):
        reject("recovery provenance", "plan approval equals contract introduction")
    require_ancestor(repo, str(approval_commit), str(introduction_commit))
    plan_blob = git_blob(repo, str(approval_commit), plan_rel)
    plan_text = plan_blob.decode("utf-8")
    plan_frontmatter, plan_body = split_frontmatter(
        plan_text,
        failure_kind="recovery provenance",
        detail="sealed plan frontmatter is missing",
    )
    frontmatter_lines = plan_frontmatter.splitlines()

    def plan_scalar(name: str) -> str:
        header = re.compile(rf"^{re.escape(name)}[ \t]*:")
        matches = [line for line in frontmatter_lines if header.match(line)]
        if len(matches) != 1 or not matches[0].startswith(f"{name}:"):
            reject("recovery provenance", f"plan {name} must be one top-level scalar")
        value = matches[0].split(":", 1)[1].strip()
        if not value:
            reject("recovery provenance", f"plan {name} must be one top-level scalar")
        return value

    plan_digest = hashlib.sha256(plan_body.encode("utf-8")).hexdigest()
    if plan_scalar("status") != "approved":
        reject("recovery provenance", "plan status is not approved")
    stored_plan_seal = plan_scalar("body_seal")
    if not SHA_PATTERN.fullmatch(stored_plan_seal):
        reject("recovery provenance", "stored plan seal is invalid")
    if stored_plan_seal != plan_digest or stored_plan_seal != str(plan_seal):
        reject("recovery provenance", "sealed plan bytes mismatch")
    introduction_blob = git_blob(repo, str(introduction_commit), "skills/release-loop/references/transition-hooks.md").decode("utf-8")
    heading = f"## Release-loop pre-archive verification V2: {CONTRACT_V2_TITLE}"
    if heading not in introduction_blob or CONTRACT_V2_BODY not in introduction_blob:
        reject("recovery provenance", "contract introduction bytes mismatch")
    classification = classify_pre_archive_contract(plan_text)
    return {
        "plan_path": plan_rel,
        "plan_seal": str(plan_seal),
        "plan_approval_commit": str(approval_commit),
        "contract_introduction_commit": str(introduction_commit),
        "verdict": "accepted",
        "classification": str(classification["classification"]),
        "parsed_version": classification["parsed_version"],
    }


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
    *,
    allow_recovery_terminal: bool = False,
) -> tuple[str, str]:
    recovery_ids = re.findall(
        r"^-[ \t]+\S+[ \t]+legacy_archive_recovery: staged: recovery-id=([a-z0-9]+(?:-[a-z0-9]+)*)\b",
        text,
        re.MULTILINE,
    )
    if recovery_ids:
        if len(recovery_ids) != 1:
            reject("recovery archive state", "recovery staging evidence is duplicated")
        recovery_id = recovery_ids[0]
        repo_fd = open_repo_descriptor(repo)
        authority_fd = -1
        root_fd = -1
        try:
            authority_fd = open_dir_chain(repo_fd, f"{RECOVERY_AUTHORITY_ROOT}/{recovery_id}")
            request, _request_digest = read_json_record_at(authority_fd, "request.json", RECOVERY_REQUEST_SCHEMA)
            receipt, receipt_digest = read_json_record_at(
                authority_fd,
                "receipt.json",
                "legacy-archive-recovery-receipt/v1",
            )
            root_candidates = [str(values.get("artifact_root", ""))]
            if requested_destination is not None:
                root_candidates.append(requested_destination)
            selected_root = ""
            for candidate in root_candidates:
                try:
                    root_fd = open_dir_chain(repo_fd, candidate)
                    selected_root = candidate
                    break
                except (FileNotFoundError, NotADirectoryError, OSError):
                    root_fd = -1
            if root_fd < 0:
                reject("recovery archive state", "recovery generation root is unavailable")
            state, stored, _ = recovery_progress_state(
                root_fd,
                text,
                request,
                receipt,
                receipt_digest,
                generation_exclude=(
                    RECOVERY_CONTROL_NAMES
                    if selected_root == requested_destination
                    else frozenset()
                ),
            )
            if state != "g3":
                reject("recovery archive state", f"{state.upper()} is nonterminal")
            if not allow_recovery_terminal:
                reject("recovery archive state", "G3 requires restore-legacy-archive")
            if requested_destination is not None and stored != requested_destination:
                reject("recovery archive state", "G3 destination mismatch")
            return "completed", str(stored)
        finally:
            if root_fd >= 0:
                os.close(root_fd)
            if authority_fd >= 0:
                os.close(authority_fd)
            os.close(repo_fd)
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
    if destination is None:
        reject("invalid progress", progress_path)
    destination_path = guard(repo, destination, ".release-loop/archive")
    archived_progress = guard(repo, f"{destination}/progress.md", destination)
    if progress_path == f"{destination}/progress.md":
        values, text = frontmatter(archived_progress)
        source_rel = values.get("artifact_root", "")
        source_path = repo_relative(source_rel)
        if (
            len(source_path.parts) != 3
            or source_path.parts[:2] != (".release-loop", "runs")
        ):
            reject("path boundary", f"artifact_root {source_rel}")
        scope_feature = source_path.parts[2]
    else:
        _, source_rel, scope_feature = progress_location(repo, progress_path)
        values, text = frontmatter(archived_progress)
    if values.get("artifact_root") != source_rel:
        reject("path boundary", f"artifact_root {values.get('artifact_root', '')}")
    if scope_feature is not None and values.get("feature") != scope_feature:
        reject("invalid progress", f"feature does not match scope {scope_feature}")
    mode, selected = validate_archive_contract(
        repo,
        values,
        text,
        destination,
        allow_recovery_terminal=True,
    )
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
    if destination is not None and progress_path == f"{destination}/progress.md":
        return recover_terminal_archive(repo, progress_path, destination)
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
    legacy_destination: str | None = None,
) -> tuple[Path, Path]:
    repo = repo.resolve(strict=True)
    base_repo = base_repo.resolve(strict=True)
    if repo == base_repo:
        reject("handoff owner conflict", "source and base resolve to same checkout")
    progress_file, values, _ = validate_progress(repo, progress_path)
    artifact_root = values["artifact_root"]
    run_id = values["feature"]
    if artifact_root == ".release-loop":
        if legacy_destination != LEGACY_DESTINATION:
            reject("path boundary", "legacy handoff requires --legacy-destination .release-loop")
        canonical_marker = f".release-loop/.handoff/{run_id}.json"
        if marker_path is not None and marker_path != canonical_marker:
            reject("path boundary", f"legacy marker path must be {canonical_marker}")
        return legacy_handoff(repo, base_repo, progress_file, values, canonical_marker)
    if legacy_destination is not None:
        reject("path boundary", "scoped handoff must not pass --legacy-destination")
    inject_after_marker = test_failure("handoff-after-marker")
    source = guard(repo, artifact_root, artifact_root, allow_root=True)
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
    handoff_parser.add_argument("--legacy-destination")

    publish_parser = subparsers.add_parser("publish")
    publish_parser.add_argument("--repo", required=True)
    publish_parser.add_argument("--progress-path", required=True)
    publish_parser.add_argument("--source", required=True)
    publish_parser.add_argument("--target", required=True)

    compensate_parser = subparsers.add_parser("compensate")
    compensate_parser.add_argument("--repo", required=True)
    compensate_parser.add_argument("--progress-path", required=True)

    recovery_parser = subparsers.add_parser("request-legacy-archive")
    recovery_parser.add_argument("--repo", required=True)
    recovery_parser.add_argument("--recovery-id", required=True)
    recovery_parser.add_argument("--progress-path")
    recovery_parser.add_argument("--gate-progress-path")
    recovery_parser.add_argument("--session")
    recovery_parser.add_argument("--publish-approval", action="store_true")

    backup_parser = subparsers.add_parser("backup-legacy-archive")
    backup_parser.add_argument("--repo", required=True)
    backup_parser.add_argument("--recovery-id", required=True)

    audit_parser = subparsers.add_parser("audit-legacy-archive")
    audit_parser.add_argument("--repo", required=True)
    audit_parser.add_argument("--recovery-id", required=True)

    restore_parser = subparsers.add_parser("restore-legacy-archive")
    restore_parser.add_argument("--repo", required=True)
    restore_parser.add_argument("--recovery-id", required=True)
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
            arguments.legacy_destination,
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
    if arguments.command == "request-legacy-archive":
        if arguments.publish_approval:
            if any(value is not None for value in (
                arguments.progress_path,
                arguments.gate_progress_path,
                arguments.session,
            )):
                reject("invalid arguments", "approval publication accepts only --repo and --recovery-id")
            return publish_recovery_approval(repo, arguments.recovery_id)
        return request_legacy_archive(
            repo,
            arguments.recovery_id,
            arguments.progress_path,
            arguments.gate_progress_path,
            arguments.session,
        )
    if arguments.command == "backup-legacy-archive":
        return backup_legacy_archive(repo, arguments.recovery_id)
    if arguments.command == "audit-legacy-archive":
        return audit_legacy_archive(repo, arguments.recovery_id)
    if arguments.command == "restore-legacy-archive":
        return restore_legacy_archive(repo, arguments.recovery_id)
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
