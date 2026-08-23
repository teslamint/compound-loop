"""Atomic phase-artifact publication shared by packaged local CLIs."""

from __future__ import annotations

import hashlib
import json
import os
import re
import subprocess
from pathlib import Path, PurePosixPath

SCHEMA_VERSION = "release-loop/v1"
JOURNAL_SCHEMA = "phase-artifact-ownership/v1"
JOURNAL_NAME = ".phase-artifact-ownership.json"
CONTROL_NAMES = frozenset(("progress.md", JOURNAL_NAME, JOURNAL_NAME + ".tmp"))
TARGET_PREFIXES = frozenset(("briefs", "reports", "reviews", "evidence"))
FAILURE_ENV = "RUN_ARTIFACT_INTEGRITY_TEST_FAIL"
FAILURES = frozenset((
    "publish-before-prepare",
    "publish-after-prepare",
    "publish-after-final",
    "publish-before-finalize",
))
FEATURE_PATTERN = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")
SHA_PATTERN = re.compile(r"^[0-9a-f]{64}$")


class ArtifactBlocked(RuntimeError):
    """A fail-closed phase-artifact result."""


def reject(kind: str, detail: str) -> None:
    raise ArtifactBlocked(f"{kind}: {detail}")


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
    allowed = repo_relative(allowed_root)
    if rel != allowed and not is_within(Path(*rel.parts), Path(*allowed.parts)):
        reject("path boundary", f"{relative} outside {allowed_root}")
    if rel == allowed and not allow_root:
        reject("path boundary", f"{relative} must name a child")
    cursor = repo
    for part in rel.parts:
        cursor = cursor / part
        if cursor.is_symlink():
            reject("path boundary", f"symlink component {cursor.relative_to(repo).as_posix()}")
        if cursor.exists() and not is_within(cursor.resolve(), repo):
            reject("path boundary", f"outside repository {relative}")
    if not is_within(cursor.parent.resolve(strict=False), repo):
        reject("path boundary", f"outside repository {relative}")
    return cursor


def git_tracked(repo: Path, relative: str) -> list[str]:
    result = subprocess.run(
        ("git", "ls-files", "--", relative),
        cwd=repo,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if result.returncode:
        reject("artifact ownership", "git index unavailable")
    return [line for line in result.stdout.splitlines() if line]


def frontmatter(path: Path) -> dict[str, str]:
    if path.is_symlink() or not path.is_file():
        reject("invalid progress", str(path))
    text = path.read_text(encoding="utf-8")
    if not text.startswith("---\n") or "\n---\n" not in text[4:]:
        reject("invalid progress", str(path))
    values = {}
    for line in text.split("---", 2)[1].splitlines():
        if ":" in line:
            key, value = line.split(":", 1)
            values[key.strip()] = value.strip()
    return values


def validate_progress(repo: Path, relative: str) -> tuple[Path, dict[str, str]]:
    rel = repo_relative(relative)
    if rel == PurePosixPath(".release-loop/progress.md"):
        root = ".release-loop"
    elif len(rel.parts) == 4 and rel.parts[:2] == (".release-loop", "runs") and rel.name == "progress.md":
        root = PurePosixPath(*rel.parts[:-1]).as_posix()
    else:
        reject("path boundary", f"invalid progress path {relative}")
    path = guard(repo, relative, root)
    values = frontmatter(path)
    if values.get("schema") != SCHEMA_VERSION:
        reject("unknown schema", values.get("schema", "missing"))
    feature = values.get("feature", "")
    if not FEATURE_PATTERN.fullmatch(feature) or feature == "resume":
        reject("invalid progress", f"feature {feature!r}")
    if values.get("artifact_root") != root:
        reject("path boundary", f"artifact_root {values.get('artifact_root', '')}")
    if root != ".release-loop" and feature != rel.parts[2]:
        reject("invalid progress", "feature does not match scope")
    return path, values


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def empty_journal() -> dict[str, object]:
    return {"schema": JOURNAL_SCHEMA, "owned": {}, "pending": None}


def canonical_artifact_key(value: str, role: str) -> str:
    path = repo_relative(value)
    canonical = path.as_posix()
    if canonical != value:
        reject("artifact ownership", f"non-canonical {role} path {value}")
    if role == "source":
        if len(path.parts) < 2 or path.parts[0] != ".tmp":
            reject("artifact ownership", f"source outside .tmp {value}")
    else:
        if len(path.parts) < 2 or path.parts[0] not in TARGET_PREFIXES or (len(path.parts) == 1 and path.name in CONTROL_NAMES):
            reject("artifact ownership", f"reserved target {value}")
    return canonical


def validate_pending_row(pending: dict[str, str], owned: dict[str, str]) -> None:
    source = canonical_artifact_key(pending["source"], "source")
    target = canonical_artifact_key(pending["target"], "target")
    if source == target:
        reject("artifact ownership", "pending source equals target")
    if source in owned:
        reject("artifact ownership", "pending source is already owned")


def journal_paths(repo: Path, root: str) -> tuple[Path, Path]:
    journal = guard(repo, f"{root}/{JOURNAL_NAME}", root)
    temporary = guard(repo, f"{root}/{JOURNAL_NAME}.tmp", root)
    for path in (journal, temporary):
        relative = path.relative_to(repo).as_posix()
        if git_tracked(repo, relative):
            reject("artifact ownership", f"tracked journal path {relative}")
        if path.is_symlink() or (path.exists() and not path.is_file()):
            reject("artifact ownership", f"journal collision {relative}")
    if temporary.exists():
        reject("artifact ownership", f"journal temporary collision {temporary.relative_to(repo).as_posix()}")
    return journal, temporary


def read_journal(repo: Path, root: str) -> tuple[Path, Path, dict[str, object]]:
    journal, temporary = journal_paths(repo, root)
    if not journal.exists():
        return journal, temporary, empty_journal()
    try:
        payload = json.loads(journal.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError):
        reject("artifact ownership", "invalid journal")
    if not isinstance(payload, dict) or set(payload) != {"schema", "owned", "pending"}:
        reject("artifact ownership", "invalid journal shape")
    if payload["schema"] != JOURNAL_SCHEMA or not isinstance(payload["owned"], dict):
        reject("artifact ownership", "invalid journal shape")
    if any(not isinstance(k, str) or not isinstance(v, str) or not SHA_PATTERN.fullmatch(v) for k, v in payload["owned"].items()):
        reject("artifact ownership", "invalid owned row")
    for key in payload["owned"]:
        canonical_artifact_key(key, "target")
    pending = payload["pending"]
    if pending is not None:
        if not isinstance(pending, dict) or set(pending) != {"source", "target", "sha256"}:
            reject("artifact ownership", "invalid pending row")
        if any(not isinstance(pending[key], str) for key in pending) or not SHA_PATTERN.fullmatch(pending["sha256"]):
            reject("artifact ownership", "invalid pending row")
        validate_pending_row(pending, payload["owned"])
    return journal, temporary, payload


def validate_owned_finals(repo: Path, root: str, state: dict[str, object]) -> None:
    for key, digest in state["owned"].items():
        target = guard(repo, f"{root}/{key}", root)
        relative = target.relative_to(repo).as_posix()
        if git_tracked(repo, relative) or target.is_symlink() or not target.is_file() or sha256(target) != digest:
            reject("artifact ownership", f"owned final invalid {key}")


def validate_pending_files(repo: Path, root: str, state: dict[str, object]) -> None:
    pending = state["pending"]
    if pending is None:
        return
    source = guard(repo, f"{root}/{pending['source']}", root)
    target = guard(repo, f"{root}/{pending['target']}", root)
    source_relative = source.relative_to(repo).as_posix()
    source_exists = source.is_file() and not source.is_symlink()
    target_exists = target.is_file() and not target.is_symlink()
    if source_exists:
        if git_tracked(repo, source_relative) or sha256(source) != pending["sha256"]:
            reject("artifact ownership", "pending source invalid")
    if target_exists and sha256(target) != pending["sha256"]:
        reject("artifact ownership", "pending final invalid")
    if source_exists == target_exists:
        reject("artifact ownership", "inconsistent pending transaction")


def write_journal(journal: Path, temporary: Path, payload: dict[str, object]) -> None:
    if temporary.exists() or temporary.is_symlink():
        reject("artifact ownership", "journal temporary collision")
    temporary.write_text(json.dumps(payload, sort_keys=True, separators=(",", ":")) + "\n", encoding="utf-8")
    os.replace(temporary, journal)


def selected_failure() -> str | None:
    value = os.environ.get(FAILURE_ENV)
    if value is not None and value not in FAILURES:
        reject("invalid test failure", value)
    return value


def publish(repo: Path, progress_relative: str, source_relative: str, target_relative: str) -> tuple[Path, str, str]:
    repo = repo.resolve(strict=True)
    _, values = validate_progress(repo, progress_relative)
    root = values["artifact_root"]
    source_key = canonical_artifact_key(PurePosixPath(source_relative).relative_to(PurePosixPath(root)).as_posix() if PurePosixPath(root) in PurePosixPath(source_relative).parents else source_relative, "source")
    target_key = canonical_artifact_key(PurePosixPath(target_relative).relative_to(PurePosixPath(root)).as_posix() if PurePosixPath(root) in PurePosixPath(target_relative).parents else target_relative, "target")
    if source_key == target_key:
        reject("artifact ownership", "source equals target")
    source = guard(repo, source_relative, root)
    target = guard(repo, target_relative, root)
    temp_root = guard(repo, f"{root}/.tmp", root)
    if not is_within(source, temp_root) or source == temp_root or git_tracked(repo, source_relative):
        reject("artifact source", source_relative)
    if is_within(target, temp_root):
        reject("artifact target", target_relative)
    if git_tracked(repo, target_relative):
        reject("artifact target collision", target_relative)
    journal, journal_temp, state = read_journal(repo, root)
    validate_owned_finals(repo, root, state)
    validate_pending_files(repo, root, state)
    if source_key in state["owned"]:
        reject("artifact source", "source is already owned")
    pending = state["pending"]
    failure = selected_failure()

    if pending is not None:
        expected = {"source": source_key, "target": target_key}
        if any(pending[key] != value for key, value in expected.items()):
            reject("artifact ownership", "different pending transaction")
        digest = pending["sha256"]
        source_exists = source.is_file() and not source.is_symlink()
        target_exists = target.is_file() and not target.is_symlink()
        if source_exists and not target_exists:
            if sha256(source) != digest:
                reject("artifact ownership", "pending source digest mismatch")
        elif target_exists and not source_exists:
            if sha256(target) != digest:
                reject("artifact ownership", "pending final digest mismatch")
            owned = dict(state["owned"])
            owned[target_key] = digest
            write_journal(journal, journal_temp, {"schema": JOURNAL_SCHEMA, "owned": owned, "pending": None})
            return target, digest, "published"
        else:
            reject("artifact ownership", "inconsistent pending transaction")
    else:
        if not source.is_file() or source.is_symlink():
            reject("artifact source", source_relative)
        digest = sha256(source)
        recorded = state["owned"].get(target_key)
        if target.exists() or target.is_symlink():
            if target.is_file() and not target.is_symlink() and recorded == digest and sha256(target) == digest:
                source.unlink()
                return target, digest, "reused"
            reject("artifact ownership", target_relative)
        if recorded is not None:
            reject("artifact ownership", "owned final missing")
        if failure == "publish-before-prepare":
            reject("injected publish interruption", target_relative)
        pending = {"source": source_key, "target": target_key, "sha256": digest}
        write_journal(journal, journal_temp, {"schema": JOURNAL_SCHEMA, "owned": dict(state["owned"]), "pending": pending})
        if failure == "publish-after-prepare":
            reject("injected publish interruption", target_relative)

    target.parent.mkdir(parents=True, exist_ok=True)
    os.replace(source, target)
    if failure == "publish-after-final":
        reject("injected publish interruption", target_relative)
    if sha256(target) != digest:
        reject("artifact ownership", "final digest mismatch")
    if failure == "publish-before-finalize":
        reject("injected publish interruption", target_relative)
    owned = dict(state["owned"])
    owned[target_key] = digest
    write_journal(journal, journal_temp, {"schema": JOURNAL_SCHEMA, "owned": owned, "pending": None})
    return target, digest, "published"


def compensate(repo: Path, progress_relative: str) -> str:
    repo = repo.resolve(strict=True)
    _, values = validate_progress(repo, progress_relative)
    root = values["artifact_root"]
    journal, journal_temp, state = read_journal(repo, root)
    pending = state["pending"]
    if pending is None:
        reject("artifact ownership", "no pending transaction")
    source = guard(repo, f"{root}/{pending['source']}", root)
    target = guard(repo, f"{root}/{pending['target']}", root)
    source_relative = source.relative_to(repo).as_posix()
    if pending["source"] in state["owned"] or git_tracked(repo, source_relative) or source.is_symlink() or not source.is_file() or target.exists() or target.is_symlink() or sha256(source) != pending["sha256"]:
        reject("artifact ownership", "pending transaction is not compensable")
    source.unlink()
    write_journal(journal, journal_temp, {"schema": JOURNAL_SCHEMA, "owned": dict(state["owned"]), "pending": None})
    return "compensated"
