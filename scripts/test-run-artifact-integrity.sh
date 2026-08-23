#!/usr/bin/env bash
# Disposable fixture coverage for release-loop run-scope integrity.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

case_name="${1:-scope}"

python3 - "$case_name" "$ROOT" <<'PY'
from __future__ import annotations

from pathlib import Path
import re
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
    "unknown_schema_with_valid_record",
    "symlink_progress_rejected",
    "legacy_scoped_ambiguity",
    "interrupted_archive",
    "interrupted_legacy_archive",
    "ignored_orphan",
    "occupied_scope_blocked",
    "tracked_scope_target",
    "index_only_tracked_collision",
    "absolute_outside_root",
    "relative_parent_escape",
    "scoped_symlink",
    "legacy_symlink",
    "archive_symlink",
    "handoff_symlink",
    "handoff_success",
    "handoff_incomplete_rerun",
    "handoff_mismatch_preserves_both",
    "archive_direct_escape",
    "archive_parent_escape",
    "archive_wrong_family",
    "legacy_direct_escape",
    "legacy_parent_escape",
    "handoff_direct_escape",
    "handoff_parent_escape",
    "handoff_wrong_family",
    "operative_contract_mutation",
    "stateful_scoped_lifecycle",
)


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
        (HOOKS, "`.release-loop/.handoff` is the fixed handoff root"),
        (HOOKS, "Make the base owner discover and resume that exact progress path."),
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
    return repo.resolve(strict=True)


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


def load_operative_contract(text: str = SCHEMA) -> dict[str, object]:
    start = "<!-- run-artifact-integrity-check:begin -->"
    end = "<!-- run-artifact-integrity-check:end -->"
    if text.count(start) != 1 or text.count(end) != 1 or text.index(start) >= text.index(end):
        raise AssertionError("executable run-artifact contract absent")
    section = text.split(start, 1)[1].split(end, 1)[0]
    blocks = re.findall(r"```python\n(.*?)\n```", section, re.DOTALL)
    if len(blocks) != 1 or section.count("```") != 2:
        raise AssertionError("executable run-artifact contract must contain exactly one Python block")
    namespace: dict[str, object] = {"__name__": "run_artifact_contract"}
    exec(compile(blocks[0], "run-artifact-integrity-check.py", "exec"), namespace)
    required = ("Blocked", "initialize", "discover", "archive", "handoff")
    missing = [name for name in required if name not in namespace]
    if missing:
        raise AssertionError("executable run-artifact contract missing: " + ", ".join(missing))
    return namespace


OPERATIVE = load_operative_contract()
Blocked = OPERATIVE["Blocked"]
initialize = OPERATIVE["initialize"]
discover = OPERATIVE["discover"]
archive_scope = OPERATIVE["archive"]
handoff_scope = OPERATIVE["handoff"]


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
            order = archive_scope(repo, str(path.relative_to(repo)), ".release-loop/archive/2026-08-23-alpha")
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
        elif name == "unknown_schema_with_valid_record":
            valid = initialize(repo, "alpha")
            invalid = repo / ".release-loop/runs/beta/progress.md"
            invalid.parent.mkdir(parents=True)
            invalid.write_text(progress("beta", ".release-loop/runs/beta").replace("release-loop/v1", "release-loop/v999"), encoding="utf-8")
            assert_blocked_preserves(lambda: discover(repo), sent, before, "unknown schema")
            assert valid.exists() and invalid.exists()
        elif name == "symlink_progress_rejected":
            valid = initialize(repo, "alpha")
            linked = repo / ".release-loop/runs/beta/progress.md"
            linked.parent.mkdir(parents=True)
            linked.symlink_to(valid)
            assert_blocked_preserves(lambda: discover(repo), sent, before, "path boundary")
        elif name == "legacy_scoped_ambiguity":
            scoped = initialize(repo, "alpha")
            legacy = repo / ".release-loop/progress.md"
            legacy.write_text(progress("legacy", ".release-loop"), encoding="utf-8")
            assert_blocked_preserves(lambda: discover(repo), sent, before, "multiple valid live records require exact progress path")
            assert discover(repo, str(scoped.relative_to(repo))) == ("resume", scoped)
        elif name == "interrupted_archive":
            path = initialize(repo, "alpha")
            destination = ".release-loop/archive/2026-08-23-alpha"
            for child in ("briefs", "reports"):
                directory = path.parent / child
                directory.mkdir()
                (directory / "owned.md").write_text(child + "\n", encoding="utf-8")
            try:
                archive_scope(repo, str(path.relative_to(repo)), destination, fail_after_first=True)
            except Blocked as exc:
                assert "injected archive interruption" in str(exc)
            else:
                raise AssertionError("archive interruption did not fire")
            assert path.exists(), "progress must remain the source commit point"
            assert f"archive-destination: {destination}" in path.read_text(encoding="utf-8")
            order = archive_scope(repo, str(path.relative_to(repo)), None)
            assert order[-1] == "progress.md"
            assert (repo / destination / "progress.md").is_file()
        elif name == "interrupted_legacy_archive":
            legacy = repo / ".release-loop/progress.md"
            legacy.parent.mkdir()
            legacy.write_text(progress("legacy", ".release-loop"), encoding="utf-8")
            for child in ("briefs", "reports"):
                directory = legacy.parent / child
                directory.mkdir()
                (directory / "owned.md").write_text(child + "\n", encoding="utf-8")
            destination = ".release-loop/archive/2026-08-23-legacy"
            try:
                archive_scope(repo, str(legacy.relative_to(repo)), destination, fail_after_first=True)
            except Blocked as exc:
                assert "injected archive interruption" in str(exc)
            else:
                raise AssertionError("legacy archive interruption did not fire")
            assert legacy.exists()
            assert f"archive-destination: {destination}" in legacy.read_text(encoding="utf-8")
            assert archive_scope(repo, str(legacy.relative_to(repo)), None)[-1] == "progress.md"
            assert (repo / destination / "progress.md").is_file()
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
        elif name == "index_only_tracked_collision":
            target = repo / ".release-loop/runs/alpha/index-only.txt"
            target.parent.mkdir(parents=True)
            target.write_text("indexed\n", encoding="utf-8")
            git(repo, "add", "-f", str(target.relative_to(repo)))
            target.unlink()
            try:
                initialize(repo, "alpha")
            except Blocked as exc:
                assert str(exc) == "artifact scope collision: .release-loop/runs/alpha/index-only.txt", str(exc)
            else:
                raise AssertionError("index-only collision did not block")
            assert not target.exists()
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
                action = lambda: discover(repo)
            elif name == "archive_symlink":
                initialize(repo, "alpha")
                archive = repo / ".release-loop/archive"
                archive.symlink_to(outside, target_is_directory=True)
                action = lambda: archive_scope(repo, ".release-loop/runs/alpha/progress.md", ".release-loop/archive/2026-08-23-alpha")
            else:
                source = repo
                base = new_repo(tmp, "base")
                path = initialize(source, "alpha")
                loop = base / ".release-loop"
                loop.mkdir(exist_ok=True)
                (loop / ".handoff").symlink_to(outside, target_is_directory=True)
                action = lambda: handoff_scope(source, base, str(path.relative_to(source)))
            assert_blocked_preserves(action, sent, before, "path boundary")
        elif name == "handoff_success":
            source = repo
            base = new_repo(tmp, "base")
            path = initialize(source, "alpha")
            (path.parent / "reports").mkdir()
            (path.parent / "reports/U1.md").write_text("done\n", encoding="utf-8")
            result = handoff_scope(source, base, str(path.relative_to(source)))
            base_progress = base / ".release-loop/runs/alpha/progress.md"
            assert result["cleanup_permitted"] is True
            assert discover(base, str(base_progress.relative_to(base))) == ("resume", base_progress)
            assert (base / ".release-loop/runs/alpha/reports/U1.md").read_text(encoding="utf-8") == "done\n"
        elif name == "handoff_incomplete_rerun":
            source = repo
            base = new_repo(tmp, "base")
            path = initialize(source, "alpha")
            (path.parent / "reports").mkdir()
            (path.parent / "reports/U1.md").write_text("done\n", encoding="utf-8")
            try:
                handoff_scope(source, base, str(path.relative_to(source)), fail_after_marker=True)
            except Blocked as exc:
                assert "injected handoff interruption" in str(exc)
            else:
                raise AssertionError("handoff interruption did not fire")
            marker = base / ".release-loop/.handoff/alpha.json"
            assert marker.is_file()
            result = handoff_scope(source, base, str(path.relative_to(source)))
            assert result["cleanup_permitted"] is True
            assert discover(base, ".release-loop/runs/alpha/progress.md")[0] == "resume"
        elif name == "handoff_mismatch_preserves_both":
            source = repo
            base = new_repo(tmp, "base")
            path = initialize(source, "alpha")
            try:
                handoff_scope(source, base, str(path.relative_to(source)), fail_after_marker=True)
            except Blocked:
                pass
            target = base / ".release-loop/runs/alpha"
            target.mkdir(parents=True)
            (target / "foreign.txt").write_text("foreign\n", encoding="utf-8")
            source_before = path.read_bytes()
            target_before = (target / "foreign.txt").read_bytes()
            assert_blocked_preserves(lambda: handoff_scope(source, base, str(path.relative_to(source))), sent, before, "handoff target mismatch")
            assert path.read_bytes() == source_before
            assert (target / "foreign.txt").read_bytes() == target_before
        elif name in {
            "archive_direct_escape",
            "archive_parent_escape",
            "archive_wrong_family",
            "legacy_direct_escape",
            "legacy_parent_escape",
            "handoff_direct_escape",
            "handoff_parent_escape",
            "handoff_wrong_family",
        }:
            path = initialize(repo, "alpha")
            if name == "archive_direct_escape":
                action = lambda: archive_scope(repo, str(path.relative_to(repo)), str(sent))
            elif name == "archive_parent_escape":
                action = lambda: archive_scope(repo, str(path.relative_to(repo)), ".release-loop/archive/../escaped")
            elif name == "archive_wrong_family":
                action = lambda: archive_scope(repo, str(path.relative_to(repo)), ".release-loop/escaped/archive")
            elif name == "legacy_direct_escape":
                action = lambda: discover(repo, str(sent))
            elif name == "legacy_parent_escape":
                action = lambda: discover(repo, ".release-loop/../progress.md")
            else:
                base = new_repo(tmp, "base")
                if name == "handoff_direct_escape":
                    marker = str(sent)
                elif name == "handoff_parent_escape":
                    marker = ".release-loop/.handoff/../escaped.json"
                else:
                    marker = ".release-loop/escaped/alpha.json"
                action = lambda: handoff_scope(repo, base, str(path.relative_to(repo)), marker_path=marker)
            assert_blocked_preserves(action, sent, before, "path boundary")
        elif name == "operative_contract_mutation":
            mutated = SCHEMA.replace('SCHEMA_VERSION = "release-loop/v1"', 'SCHEMA_VERSION = "release-loop/v999"', 1)
            assert mutated != SCHEMA, "mutation target must exist in the operative block"
            contract = load_operative_contract(mutated)
            legacy = repo / ".release-loop/progress.md"
            legacy.parent.mkdir()
            legacy.write_text(progress("legacy", ".release-loop"), encoding="utf-8")
            try:
                contract["discover"](repo)
            except Exception as exc:
                assert "unknown schema" in str(exc), str(exc)
            else:
                raise AssertionError("operative contract mutation escaped the fixture")
        elif name == "stateful_scoped_lifecycle":
            path = initialize(repo, "alpha")
            for child in ("briefs", "reports", "reviews", "evidence"):
                directory = path.parent / child
                directory.mkdir()
                (directory / "owned.md").write_text(child + "\n", encoding="utf-8")
            base = new_repo(tmp, "base")
            result = handoff_scope(repo, base, str(path.relative_to(repo)))
            assert result["cleanup_permitted"] is True
            base_progress = base / ".release-loop/runs/alpha/progress.md"
            archive_scope(base, str(base_progress.relative_to(base)), ".release-loop/archive/2026-08-23-alpha")
            assert not (base / ".release-loop/progress.md").exists()
            assert (base / ".release-loop/archive/2026-08-23-alpha/progress.md").is_file()
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
