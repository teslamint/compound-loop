#!/usr/bin/env bash
# Disposable fixture coverage for release-loop run-scope integrity.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

case_name="${1:-scope}"

python3 - "$case_name" "$ROOT" <<'PY'
from __future__ import annotations

import os
from pathlib import Path, PurePosixPath
import shutil
import subprocess
import sys
import tempfile


CASE = sys.argv[1]
ROOT = Path(sys.argv[2])
SKILL = (ROOT / "skills/release-loop/SKILL.md").read_text(encoding="utf-8")
SCHEMA = (ROOT / "skills/release-loop/references/progress-schema.md").read_text(encoding="utf-8")
ARCHIVE = (ROOT / "skills/release-loop/references/resume-and-archive.md").read_text(encoding="utf-8")
HOOKS = (ROOT / "skills/release-loop/references/transition-hooks.md").read_text(encoding="utf-8")

CASES = (
    "new_scoped_run",
    "archive_scoped_run",
    "one_live_record",
    "multiple_live_records",
    "valid_legacy_record",
    "interrupted_archive",
    "ignored_orphan",
    "occupied_scope_blocked",
    "tracked_scope_target",
    "absolute_outside_root",
    "relative_parent_escape",
    "scoped_symlink",
    "legacy_symlink",
    "archive_symlink",
    "handoff_symlink",
    "handoff_success",
    "stateful_scoped_lifecycle",
)


class Blocked(RuntimeError):
    pass


def require_contract() -> None:
    required = (
        (SKILL, ".release-loop/runs/<feature_slug>/progress.md"),
        (SKILL, "Exactly one valid live record resumes without another selector."),
        (SKILL, "Multiple valid live records require one exact repo-relative progress path."),
        (SKILL, "An occupied scope without one matching valid progress record is an artifact-scope collision"),
        (SKILL, "A published progress record remains resumable."),
        (SCHEMA, "artifact_root: .release-loop/runs/<feature_slug>"),
        (SCHEMA, "The four closed physical-root families are"),
        (SCHEMA, "Reject every symlink in each existing source or destination component"),
        (ARCHIVE, "Move scoped `progress.md` last as the archive commit point."),
        (ARCHIVE, "reuse the exact recorded archive destination"),
        (ARCHIVE, "Mid-move cancellation leaves the selected progress record in the source scope."),
        (HOOKS, "`.release-loop/.handoff` is the only handoff root"),
        (HOOKS, "Validate every existing source and destination component before transfer."),
        (HOOKS, "Cancellation preserves the source worktree."),
    )
    missing = [fragment for text, fragment in required if fragment not in text]
    if missing:
        raise AssertionError("missing run-scope contract: " + " | ".join(missing))


def git(repo: Path, *args: str) -> str:
    result = subprocess.run(
        ("git", *args),
        cwd=repo,
        check=True,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    return result.stdout.strip()


def new_repo(tmp: Path, name: str = "repo") -> Path:
    repo = tmp / name
    repo.mkdir()
    git(repo, "init", "-q")
    git(repo, "config", "user.name", "Fixture")
    git(repo, "config", "user.email", "fixture@example.invalid")
    git(repo, "config", "core.autocrlf", "false")
    git(repo, "config", "core.safecrlf", "false")
    git(repo, "config", "commit.gpgsign", "false")
    (repo / ".gitignore").write_text(".release-loop/\n", encoding="utf-8")
    (repo / "README.md").write_text("fixture\n", encoding="utf-8")
    git(repo, "add", ".gitignore", "README.md")
    git(repo, "commit", "-qm", "fixture")
    return repo


def progress(feature: str, artifact_root: str) -> str:
    return (
        "---\n"
        "schema: release-loop/v1\n"
        f"feature: {feature}\n"
        f"artifact_root: {artifact_root}\n"
        "phase: implement\n"
        "phase_status: in-progress\n"
        "---\n"
    )


def valid_progress(path: Path, feature: str | None = None) -> bool:
    if not path.is_file() or path.is_symlink():
        return False
    text = path.read_text(encoding="utf-8")
    if "schema: release-loop/v1" not in text:
        return False
    return feature is None or f"feature: {feature}\n" in text


def repo_relative(value: str) -> PurePosixPath:
    path = PurePosixPath(value)
    if path.is_absolute() or not path.parts or ".." in path.parts:
        raise Blocked(f"path boundary: {value}")
    return path


def is_within(path: Path, root: Path) -> bool:
    try:
        path.relative_to(root)
    except ValueError:
        return False
    return True


def guard_components(repo: Path, relative: str, allowed_root: str) -> Path:
    rel = repo_relative(relative)
    allowed = repo / repo_relative(allowed_root)
    cursor = repo
    for part in rel.parts:
        cursor = cursor / part
        if cursor.is_symlink():
            raise Blocked(f"path boundary: symlink component {cursor.relative_to(repo)}")
        if cursor.exists() and not is_within(cursor.resolve(), repo.resolve()):
            raise Blocked(f"path boundary: outside repository {cursor}")
    if not is_within(cursor.absolute(), allowed.absolute()):
        raise Blocked(f"path boundary: {relative} outside {allowed_root}")
    parent = cursor if cursor.exists() and cursor.is_dir() else cursor.parent
    if not is_within(parent.resolve(strict=False), repo.resolve()):
        raise Blocked(f"path boundary: {relative} outside repository")
    return cursor


def tracked(repo: Path, relative: str) -> list[str]:
    out = git(repo, "ls-files", "--", relative)
    return [line for line in out.splitlines() if line]


def initialize(repo: Path, feature: str, selected: str | None = None) -> Path:
    relative = selected or f".release-loop/runs/{feature}/progress.md"
    expected = f".release-loop/runs/{feature}/progress.md"
    repo_relative(relative)
    if relative != expected:
        raise Blocked(f"progress path does not match run identity: {relative}")
    target = guard_components(repo, relative, f".release-loop/runs/{feature}")
    scope = target.parent
    if scope.exists():
        entries = sorted(p for p in scope.iterdir())
        if entries and not (len(entries) == 1 and valid_progress(target, feature)):
            names = ", ".join(str(p.relative_to(repo)) for p in entries)
            raise Blocked(f"artifact scope collision: {names}")
    if tracked(repo, str(scope.relative_to(repo))):
        raise Blocked(f"artifact scope collision: tracked {scope.relative_to(repo)}")
    scope.mkdir(parents=True, exist_ok=True)
    if not target.exists():
        target.write_text(progress(feature, str(scope.relative_to(repo))), encoding="utf-8")
    return target


def discover(repo: Path, exact: str | None = None) -> tuple[str, Path | None]:
    candidates: list[Path] = []
    legacy = repo / ".release-loop/progress.md"
    if valid_progress(legacy):
        candidates.append(legacy)
    runs = repo / ".release-loop/runs"
    if runs.is_dir() and not runs.is_symlink():
        for candidate in sorted(runs.glob("*/progress.md")):
            if valid_progress(candidate):
                candidates.append(candidate)
    if exact is not None:
        selected = guard_components(repo, exact, ".release-loop")
        if selected not in candidates:
            raise Blocked(f"selected progress path is not a valid live record: {exact}")
        return "resume", selected
    if len(candidates) == 1:
        return "resume", candidates[0]
    if len(candidates) > 1:
        raise Blocked("multiple valid live records require exact progress path")
    return "new", None


def archive_scope(repo: Path, feature: str, destination: str) -> list[str]:
    source_rel = f".release-loop/runs/{feature}"
    source = guard_components(repo, source_rel, source_rel)
    dest = guard_components(repo, destination, destination)
    dest.mkdir(parents=True, exist_ok=True)
    order: list[str] = []
    for child in sorted(source.iterdir()):
        if child.name == "progress.md":
            continue
        shutil.move(str(child), dest / child.name)
        order.append(child.name)
    shutil.move(str(source / "progress.md"), dest / "progress.md")
    order.append("progress.md")
    source.rmdir()
    return order


def sentinel(tmp: Path) -> tuple[Path, bytes]:
    path = tmp / "external-sentinel"
    before = b"EXTERNAL_SENTINEL_UNCHANGED\n"
    path.write_bytes(before)
    return path, before


def assert_blocked_preserves(action, sentinel_path: Path, before: bytes, diagnostic: str = "") -> None:
    try:
        action()
    except Blocked as exc:
        if diagnostic:
            assert diagnostic in str(exc), str(exc)
    else:
        raise AssertionError("attack did not block")
    assert sentinel_path.read_bytes() == before


def run_case(name: str) -> None:
    require_contract()
    with tempfile.TemporaryDirectory(prefix=f"run-artifact-{name}-") as tmp_name:
        tmp = Path(tmp_name)
        repo = new_repo(tmp)
        sent, before = sentinel(tmp)

        if name == "new_scoped_run":
            path = initialize(repo, "alpha")
            assert path.relative_to(repo).as_posix() == ".release-loop/runs/alpha/progress.md"
            assert not (repo / ".release-loop/progress.md").exists()
        elif name == "archive_scoped_run":
            path = initialize(repo, "alpha")
            (path.parent / "reports").mkdir()
            (path.parent / "reports/U1.md").write_text("done\n", encoding="utf-8")
            order = archive_scope(repo, "alpha", ".release-loop/archive/2026-08-23-alpha")
            assert order[-1] == "progress.md"
            assert not path.exists()
        elif name == "one_live_record":
            path = initialize(repo, "alpha")
            state, selected = discover(repo)
            assert (state, selected) == ("resume", path)
        elif name == "multiple_live_records":
            first = initialize(repo, "alpha")
            second = initialize(repo, "beta")
            assert_blocked_preserves(lambda: discover(repo), sent, before, "multiple valid live records")
            assert discover(repo, str(second.relative_to(repo))) == ("resume", second)
            assert first.exists()
        elif name == "valid_legacy_record":
            legacy = repo / ".release-loop/progress.md"
            legacy.parent.mkdir()
            legacy.write_text(progress("legacy", ".release-loop"), encoding="utf-8")
            assert discover(repo) == ("resume", legacy)
        elif name == "interrupted_archive":
            path = initialize(repo, "alpha")
            destination = ".release-loop/archive/2026-08-23-alpha"
            dest = repo / destination
            dest.mkdir(parents=True)
            (dest / "reports").mkdir()
            assert archive_scope(repo, "alpha", destination)[-1] == "progress.md"
        elif name in {"ignored_orphan", "occupied_scope_blocked"}:
            orphan = repo / ".release-loop/runs/alpha/orphan.txt"
            orphan.parent.mkdir(parents=True)
            orphan.write_text("orphan\n", encoding="utf-8")
            assert_blocked_preserves(lambda: initialize(repo, "alpha"), sent, before, "artifact scope collision")
            assert orphan.read_text(encoding="utf-8") == "orphan\n"
            if name == "occupied_scope_blocked":
                assert_blocked_preserves(lambda: initialize(repo, "alpha"), sent, before, "artifact scope collision")
                orphan.unlink()
                assert initialize(repo, "alpha").is_file()
        elif name == "tracked_scope_target":
            target = repo / ".release-loop/runs/alpha/owned.txt"
            target.parent.mkdir(parents=True)
            target.write_text("tracked\n", encoding="utf-8")
            git(repo, "add", "-f", str(target.relative_to(repo)))
            git(repo, "commit", "-qm", "tracked collision")
            head = git(repo, "rev-parse", "HEAD")
            index = git(repo, "write-tree")
            blob = target.read_bytes()
            status = git(repo, "status", "--porcelain", "--", str(target.relative_to(repo)))
            assert_blocked_preserves(lambda: initialize(repo, "alpha"), sent, before, "artifact scope collision")
            assert git(repo, "rev-parse", "HEAD") == head
            assert git(repo, "write-tree") == index
            assert target.read_bytes() == blob
            assert git(repo, "status", "--porcelain", "--", str(target.relative_to(repo))) == status
        elif name == "absolute_outside_root":
            assert_blocked_preserves(lambda: initialize(repo, "alpha", str(sent)), sent, before, "path boundary")
        elif name == "relative_parent_escape":
            assert_blocked_preserves(lambda: initialize(repo, "alpha", "../progress.md"), sent, before, "path boundary")
        elif name in {"scoped_symlink", "legacy_symlink", "archive_symlink", "handoff_symlink"}:
            outside = tmp / "outside"
            outside.mkdir()
            if name == "scoped_symlink":
                runs = repo / ".release-loop/runs"
                runs.parent.mkdir()
                runs.symlink_to(outside, target_is_directory=True)
                action = lambda: initialize(repo, "alpha")
            elif name == "legacy_symlink":
                loop = repo / ".release-loop"
                loop.mkdir()
                (loop / "progress.md").symlink_to(sent)
                action = lambda: guard_components(repo, ".release-loop/progress.md", ".release-loop")
            elif name == "archive_symlink":
                initialize(repo, "alpha")
                archive = repo / ".release-loop/archive"
                archive.symlink_to(outside, target_is_directory=True)
                action = lambda: archive_scope(repo, "alpha", ".release-loop/archive/2026-08-23-alpha")
            else:
                loop = repo / ".release-loop"
                loop.mkdir(exist_ok=True)
                (loop / ".handoff").symlink_to(outside, target_is_directory=True)
                action = lambda: guard_components(repo, ".release-loop/.handoff/alpha", ".release-loop/.handoff")
            assert_blocked_preserves(action, sent, before, "path boundary")
        elif name == "handoff_success":
            path = initialize(repo, "alpha")
            marker = guard_components(repo, ".release-loop/.handoff/alpha", ".release-loop/.handoff")
            marker.parent.mkdir(parents=True, exist_ok=True)
            marker.write_text(str(path.relative_to(repo)) + "\n", encoding="utf-8")
            assert marker.read_text(encoding="utf-8").strip() == ".release-loop/runs/alpha/progress.md"
        elif name == "stateful_scoped_lifecycle":
            path = initialize(repo, "alpha")
            for child in ("briefs", "reports", "reviews", "evidence"):
                directory = path.parent / child
                directory.mkdir()
                (directory / "owned.md").write_text(child + "\n", encoding="utf-8")
            marker = guard_components(repo, ".release-loop/.handoff/alpha", ".release-loop/.handoff")
            marker.parent.mkdir(parents=True)
            marker.write_text(str(path.relative_to(repo)) + "\n", encoding="utf-8")
            archive_scope(repo, "alpha", ".release-loop/archive/2026-08-23-alpha")
            assert not (repo / ".release-loop/progress.md").exists()
            assert (repo / ".release-loop/archive/2026-08-23-alpha/progress.md").is_file()
        else:
            raise AssertionError(f"unknown case: {name}")


if CASE == "scope":
    selected = CASES
elif CASE in CASES:
    selected = (CASE,)
else:
    print("usage: bash scripts/test-run-artifact-integrity.sh <scope|case>", file=sys.stderr)
    raise SystemExit(2)

failures = 0
for name in selected:
    try:
        run_case(name)
    except Exception as exc:
        failures += 1
        print(f"FAIL: [run-artifact-integrity] {name}: {exc}")
    else:
        print(f"ok:   [run-artifact-integrity] {name}")

raise SystemExit(1 if failures else 0)
PY
