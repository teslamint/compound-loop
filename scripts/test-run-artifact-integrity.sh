#!/usr/bin/env bash
# Disposable fixture coverage for release-loop run-scope integrity.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

case_name="${1:-scope}"

python3 - "$case_name" "$ROOT" <<'PY'
from __future__ import annotations

import json
import os
from pathlib import Path
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
CLI = ROOT / "skills/release-loop/scripts/run-artifact-integrity.py"

CASES = (
    "new_scoped_run",
    "scope_preparation_crash",
    "archive_scoped_run",
    "archive_requires_persisted_destination",
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
    "external_cwd_portability",
    "feature_worktree_owns_scope",
    "resume_skip_no_new_worktree",
    "stateful_scoped_lifecycle",
)


INVOCATIONS = (
    ("skill-initialize", SKILL, 'python3 "$release_loop_skill_root/scripts/run-artifact-integrity.py" initialize --repo . --feature <feature_slug>'),
    ("skill-discover", SKILL, 'python3 "$release_loop_skill_root/scripts/run-artifact-integrity.py" discover --repo . --progress-path <repo-relative-progress-path>'),
    ("archive", ARCHIVE, 'python3 "$release_loop_skill_root/scripts/run-artifact-integrity.py" archive --repo . --progress-path <repo-relative-progress-path> --destination <repo-relative-archive-path>'),
    ("handoff", HOOKS, 'python3 "$release_loop_skill_root/scripts/run-artifact-integrity.py" handoff --repo <source-worktree> --base-repo <base-checkout> --progress-path <repo-relative-progress-path>'),
)


def require_contract(texts: dict[str, str] | None = None, check_invocations: bool = True) -> None:
    selected = texts or {"SKILL": SKILL, "SCHEMA": SCHEMA, "ARCHIVE": ARCHIVE, "HOOKS": HOOKS}
    required = (
        (selected["SKILL"], ".release-loop/runs/<feature_slug>/progress.md"),
        (selected["SKILL"], "Exactly one valid live record resumes without another selector."),
        (selected["SKILL"], "Multiple valid live records require one exact repo-relative progress path."),
        (selected["SKILL"], "An occupied scope without one matching valid progress record is an artifact-scope collision"),
        (selected["SKILL"], "A published progress record remains resumable."),
        (selected["SCHEMA"], "artifact_root: .release-loop/runs/<feature_slug>"),
        (selected["SCHEMA"], "The four closed physical-root families are"),
        (selected["SCHEMA"], "Reject every symlink in each existing source or destination component"),
        (selected["ARCHIVE"], "Move scoped `progress.md` last as the archive commit point."),
        (selected["ARCHIVE"], "reuse the exact recorded archive destination"),
        (selected["ARCHIVE"], "Mid-move cancellation leaves the selected progress record in the source scope."),
        (selected["HOOKS"], "`.release-loop/.handoff` is the fixed handoff root"),
        (selected["HOOKS"], "Make the base owner discover and resume that exact progress path."),
        (selected["HOOKS"], "Cancellation preserves the source worktree."),
        (selected["SKILL"], "directory containing the loaded `SKILL.md`"),
    )
    missing = [fragment for text, fragment in required if fragment not in text]
    if check_invocations:
        for name, original, invocation in INVOCATIONS:
            key = "SKILL" if original == SKILL else "ARCHIVE" if original == ARCHIVE else "HOOKS"
            if invocation not in selected[key]:
                missing.append(f"{name}: {invocation}")
        order = (
            selected["SKILL"].find(" discover --repo ."),
            selected["SKILL"].find("Create a feature branch from HEAD via `worktree-isolation`"),
            selected["SKILL"].find(" initialize --repo ."),
            selected["SKILL"].find("Write one complete schema-conformant record"),
        )
        if -1 in order or tuple(sorted(order)) != order:
            missing.append("new-run order: discover -> worktree-isolation -> initialize -> complete ledger")
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
        "started: 2026-08-23T00:00:00Z\n"
        "updated: 2026-08-23T00:00:00Z\n"
        "branch: feat/fixture\n"
        "base_branch: main\n"
        "flags: []\n"
        "final_action:\n"
        "  kind: merge-to-base\n"
        "  status: predicted\n"
        "  command: null\n"
        "  marker: null\n"
        "  updated: 2026-08-23T00:00:00Z\n"
        "---\n"
        "\n## Log\n"
        "\n- 2026-08-23T00:00:00Z initialize: complete record published\n"
    )


class Blocked(RuntimeError):
    pass


def run_cli(
    command: str,
    *args: str,
    failure: str | None = None,
    cli: Path = CLI,
    cwd: Path = ROOT,
) -> dict[str, object]:
    if not cli.is_file():
        raise AssertionError(f"packaged run-artifact CLI absent: {cli}")
    environment = os.environ.copy()
    if failure is not None:
        environment["RUN_ARTIFACT_INTEGRITY_TEST_FAIL"] = failure
    result = subprocess.run(
        (sys.executable, str(cli), command, *args),
        cwd=cwd,
        env=environment,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if result.returncode != 0:
        assert result.stdout == "", f"blocked CLI wrote stdout: {result.stdout!r}"
        diagnostic = result.stderr.rstrip("\n")
        assert diagnostic and "\n" not in diagnostic, f"diagnostic must be one line: {result.stderr!r}"
        raise Blocked(diagnostic)
    assert result.stderr == "", f"successful CLI wrote stderr: {result.stderr!r}"
    assert result.stdout.endswith("\n") and result.stdout.count("\n") == 1, result.stdout
    payload = json.loads(result.stdout)
    canonical = json.dumps(payload, sort_keys=True, separators=(",", ":")) + "\n"
    assert result.stdout == canonical, f"non-canonical JSON: {result.stdout!r}"
    return payload


def prepare_scope(repo: Path, feature: str, selected: str | None = None) -> tuple[Path, str]:
    args = ["--repo", str(repo), "--feature", feature]
    if selected is not None:
        args.extend(("--progress-path", selected))
    payload = run_cli("initialize", *args)
    assert set(payload) == {"artifact_root", "progress_path", "state"}, payload
    assert payload["state"] in {"new", "resume"}, payload
    return repo / str(payload["progress_path"]), str(payload["state"])


def initialize(repo: Path, feature: str, selected: str | None = None) -> Path:
    path, state = prepare_scope(repo, feature, selected)
    if state == "new":
        assert path.parent.is_dir() and not any(path.parent.iterdir()), path.parent
        path.write_text(progress(feature, path.parent.relative_to(repo).as_posix()), encoding="utf-8")
    else:
        assert state == "resume" and path.is_file(), (state, path)
    return path


def discover(repo: Path, exact: str | None = None) -> tuple[str, Path | None]:
    args = ["--repo", str(repo)]
    if exact is not None:
        args.extend(("--progress-path", exact))
    payload = run_cli("discover", *args)
    assert set(payload) == {"progress_path", "state"}, payload
    assert payload["state"] in {"new", "resume"}, payload
    progress_path = payload["progress_path"]
    return str(payload["state"]), None if progress_path is None else repo / str(progress_path)


def archive_scope(
    repo: Path,
    progress_path: str,
    destination: str | None,
    fail_after_first: bool = False,
    persist_authority: bool = True,
) -> list[str]:
    if destination is not None and persist_authority:
        path = repo / progress_path
        text = path.read_text(encoding="utf-8")
        assert "archive-destination:" not in text
        text = text.replace("phase: implement\n", "phase: done\n", 1)
        text = text.replace("phase_status: in-progress\n", "phase_status: complete\n", 1)
        text += f"- 2026-08-23T00:00:01Z retro: archive-destination: {destination}\n"
        path.write_text(text, encoding="utf-8")
    args = ["--repo", str(repo), "--progress-path", progress_path]
    if destination is not None:
        args.extend(("--destination", destination))
    payload = run_cli(
        "archive",
        *args,
        failure="archive-after-first" if fail_after_first else None,
    )
    assert set(payload) == {"archive_path", "moved", "progress_path", "state"}, payload
    assert payload["state"] == "archived", payload
    return list(payload["moved"])


def handoff_scope(
    repo: Path,
    base_repo: Path,
    progress_path: str,
    marker_path: str | None = None,
    fail_after_marker: bool = False,
) -> dict[str, object]:
    args = [
        "--repo", str(repo),
        "--base-repo", str(base_repo),
        "--progress-path", progress_path,
    ]
    if marker_path is not None:
        args.extend(("--marker-path", marker_path))
    payload = run_cli(
        "handoff",
        *args,
        failure="handoff-after-marker" if fail_after_marker else None,
    )
    assert set(payload) == {"cleanup_permitted", "marker_path", "progress_path", "state"}, payload
    assert payload["state"] == "complete" and payload["cleanup_permitted"] is True, payload
    return {
        "cleanup_permitted": True,
        "marker": base_repo / str(payload["marker_path"]),
        "progress": base_repo / str(payload["progress_path"]),
    }


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
    require_contract(check_invocations=name == "operative_contract_mutation")
    with tempfile.TemporaryDirectory(prefix=f"run-artifact-{name}-") as tmp_name:
        tmp = Path(tmp_name)
        repo = new_repo(tmp)
        sent, before = sentinel(tmp)

        if name == "new_scoped_run":
            path = initialize(repo, "alpha")
            assert path.relative_to(repo).as_posix() == ".release-loop/runs/alpha/progress.md"
            assert not (repo / ".release-loop/progress.md").exists()
        elif name == "scope_preparation_crash":
            path, state = prepare_scope(repo, "alpha")
            assert state == "new"
            assert path.parent.is_dir() and not any(path.parent.iterdir())
            assert not path.exists()
            retry_path, retry_state = prepare_scope(repo, "alpha")
            assert (retry_path, retry_state) == (path, "new")
            assert not retry_path.exists()
            retry_path.write_text(progress("alpha", ".release-loop/runs/alpha"), encoding="utf-8")
            assert prepare_scope(repo, "alpha") == (retry_path, "resume")
        elif name == "archive_scoped_run":
            path = initialize(repo, "alpha")
            (path.parent / "reports").mkdir()
            (path.parent / "reports/U1.md").write_text("done\n", encoding="utf-8")
            order = archive_scope(repo, str(path.relative_to(repo)), ".release-loop/archive/2026-08-23-alpha")
            assert order[-1] == "progress.md"
            assert not path.exists()
        elif name == "archive_requires_persisted_destination":
            path = initialize(repo, "alpha")
            before_progress = path.read_bytes()
            destination = ".release-loop/archive/2026-08-23-alpha"
            assert_blocked_preserves(
                lambda: archive_scope(
                    repo,
                    str(path.relative_to(repo)),
                    destination,
                    persist_authority=False,
                ),
                sent,
                before,
                "missing persisted destination",
            )
            assert path.read_bytes() == before_progress
            assert not (repo / destination).exists()
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
                action = lambda: archive_scope(repo, ".release-loop/runs/alpha/progress.md", ".release-loop/archive/2026-08-23-alpha", persist_authority=False)
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
                action = lambda: archive_scope(repo, str(path.relative_to(repo)), str(sent), persist_authority=False)
            elif name == "archive_parent_escape":
                action = lambda: archive_scope(repo, str(path.relative_to(repo)), ".release-loop/archive/../escaped", persist_authority=False)
            elif name == "archive_wrong_family":
                action = lambda: archive_scope(repo, str(path.relative_to(repo)), ".release-loop/escaped/archive", persist_authority=False)
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
            baseline = {"SKILL": SKILL, "SCHEMA": SCHEMA, "ARCHIVE": ARCHIVE, "HOOKS": HOOKS}
            for name_label, original, invocation in INVOCATIONS:
                key = "SKILL" if original == SKILL else "ARCHIVE" if original == ARCHIVE else "HOOKS"
                for mutation in ("", invocation.replace("run-artifact-integrity.py", "changed-run-artifact.py")):
                    texts = dict(baseline)
                    texts[key] = texts[key].replace(invocation, mutation, 1)
                    assert texts[key] != baseline[key], f"structural mutation target absent: {name_label}"
                    try:
                        require_contract(texts)
                    except AssertionError as exc:
                        assert name_label in str(exc), str(exc)
                    else:
                        raise AssertionError(f"structural invocation mutation escaped: {name_label}")
        elif name == "external_cwd_portability":
            plugin_root = tmp / "plugin-root"
            copied_skill_root = plugin_root / "skills/release-loop"
            shutil.copytree(ROOT / "skills/release-loop", copied_skill_root)
            consumer = new_repo(tmp, "consumer")
            loaded_skill = copied_skill_root / "SKILL.md"
            release_loop_skill_root = loaded_skill.parent
            payload = run_cli(
                "initialize",
                "--repo", ".",
                "--feature", "portable",
                cli=release_loop_skill_root / "scripts/run-artifact-integrity.py",
                cwd=consumer,
            )
            assert payload == {
                "artifact_root": ".release-loop/runs/portable",
                "progress_path": ".release-loop/runs/portable/progress.md",
                "state": "new",
            }
            progress_path = consumer / str(payload["progress_path"])
            assert progress_path.parent.is_dir() and not progress_path.exists()
            progress_path.write_text(progress("portable", str(payload["artifact_root"])), encoding="utf-8")
            assert not (plugin_root / ".release-loop").exists()
        elif name == "feature_worktree_owns_scope":
            base = repo
            feature = tmp / "feature-worktree"
            git(base, "worktree", "add", "-q", "-b", "feat/alpha", str(feature))
            feature = feature.resolve(strict=True)
            path = initialize(feature, "alpha")
            assert not (base / ".release-loop").exists()
            files = sorted(
                item.relative_to(feature).as_posix()
                for item in (feature / ".release-loop").rglob("*")
                if item.is_file()
            )
            assert files == [".release-loop/runs/alpha/progress.md"], files
            assert path == feature / files[0]
        elif name == "resume_skip_no_new_worktree":
            base = repo
            path = initialize(base, "alpha")
            before_worktrees = git(base, "worktree", "list", "--porcelain")
            assert discover(base, str(path.relative_to(base))) == ("resume", path)
            assert prepare_scope(base, "alpha", str(path.relative_to(base))) == (path, "resume")
            after_worktrees = git(base, "worktree", "list", "--porcelain")
            assert after_worktrees == before_worktrees
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
