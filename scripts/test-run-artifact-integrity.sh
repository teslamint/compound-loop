#!/usr/bin/env bash
# Disposable fixture coverage for release-loop run-scope integrity.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

case_name="${1:-scope}"

python3 - "$case_name" "$ROOT" <<'PY'
from __future__ import annotations

import hashlib
import importlib.util
import json
import os
from datetime import datetime, timezone
from pathlib import Path
import shutil
import shlex
import subprocess
import sys
import tempfile


CASE = sys.argv[1]
ROOT = Path(sys.argv[2])
COMMAND_TRACE: list[dict[str, object]] = []


def read_contract(relative: str) -> str:
    try:
        return (ROOT / relative).read_text(encoding="utf-8")
    except OSError:
        print(f"FAIL: [run-artifact-integrity] missing or unreadable contract: {relative}", file=sys.stderr)
        raise SystemExit(1)


SKILL = read_contract("skills/release-loop/SKILL.md")
SCHEMA = read_contract("skills/release-loop/references/progress-schema.md")
ARCHIVE = read_contract("skills/release-loop/references/resume-and-archive.md")
HOOKS = read_contract("skills/release-loop/references/transition-hooks.md")
CLI = ROOT / "skills/release-loop/scripts/run-artifact-integrity.py"
IMPLEMENTING_CLI = ROOT / "skills/implementing/scripts/phase-artifact-integrity.py"
RELEASE_CORE = ROOT / "skills/release-loop/scripts/phase_artifact_core.py"
IMPLEMENTING_CORE = ROOT / "skills/implementing/scripts/phase_artifact_core.py"
EVIDENCE_CLI = ROOT / "skills/release-loop/scripts/regenerate-matrix-evidence.py"
FIX_MIGRATION_CLI = ROOT / "skills/release-loop/scripts/validate-fix-event-migration.py"
PHASE_CONSUMERS = {
    name: read_contract(f"skills/{name}/SKILL.md")
    for name in ("planning", "implementing", "reviewing", "shipping", "retrospective")
}
PLAN_SCHEMA = read_contract("skills/planning/schemas/plan-schema.md")
IMPLEMENTING = PHASE_CONSUMERS["implementing"]
REVIEWING = PHASE_CONSUMERS["reviewing"]
MERGE_PIPELINE = read_contract("skills/reviewing/references/merge-pipeline.md")
RETRO_TEMPLATE = read_contract("schemas/retro-template.md")

CASES = (
    "new_scoped_run",
    "scope_preparation_crash",
    "archive_scoped_run",
    "legacy_publish_then_archive",
    "archive_pending_publication",
    "interrupted_legacy_published_archive",
    "archive_requires_persisted_destination",
    "archive_incomplete_run",
    "archive_incomplete_missing_phase",
    "archive_incomplete_missing_phase_status",
    "archive_incomplete_unknown_phase",
    "archive_incomplete_unknown_phase_status",
    "archive_evidence_mutants",
    "one_live_record",
    "multiple_live_records",
    "valid_legacy_record",
    "unknown_schema_with_valid_record",
    "symlink_progress_rejected",
    "legacy_scoped_ambiguity",
    "scoped_feature_mismatch",
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
    "handoff_same_checkout",
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
    "all_consumers_one_root",
    "stateless_no_evidence",
    "legacy_resume_guarded",
    "legacy_tracked_self_ledger_only",
    "tracked_legacy_preserved",
    "tracked_selected_target",
    "index_only_sibling",
    "symlink_sibling_parent",
    "dangling_sibling_parent",
    "foreign_same_byte",
    "missing_progress_publish",
    "ambiguous_progress_publish",
    "mismatched_progress_publish",
    "publish_target_escape",
    "invalid_publish_source",
    "publisher_core_parity",
    "publisher_atomic_recovery",
    "publisher_journal_collisions",
    "publisher_semantics_attacks",
    "publisher_target_prefix_attacks",
    "publish_cancellation",
    "stateful_scoped_lifecycle",
    "matrix_evidence_regeneration",
    "fix_event_migration_validation",
)

CONSUMER_CASES = (
    "all_consumers_one_root",
    "stateless_no_evidence",
    "legacy_resume_guarded",
    "legacy_tracked_self_ledger_only",
    "tracked_legacy_preserved",
    "tracked_selected_target",
    "index_only_sibling",
    "symlink_sibling_parent",
    "dangling_sibling_parent",
    "foreign_same_byte",
    "missing_progress_publish",
    "ambiguous_progress_publish",
    "mismatched_progress_publish",
    "publish_target_escape",
    "invalid_publish_source",
    "publisher_core_parity",
    "publisher_atomic_recovery",
    "publisher_journal_collisions",
    "publisher_semantics_attacks",
    "publisher_target_prefix_attacks",
    "publish_cancellation",
    "stateful_scoped_lifecycle",
)

REVIEW_CASES = (
    "review_event_lifecycle",
    "event_replay",
    "matching_started_result",
    "deferred_then_fixed",
    "phase_gate_reuse",
    "outside_diff_inventory_complete",
    "event_conflict",
    "completed_result_missing",
    "completed_digest_mismatch",
    "fix_cannot_mark_fixed",
    "outside_diff_missing_disposition",
    "standalone_and_reuse",
    "inventory_omitted_row",
    "inventory_extra_row",
    "wrong_source_re_review",
    "unrelated_later_review",
    "finding_still_present",
    "severity_deferred_gate",
    "ordinal_gap_rejected",
    "completed_full_row",
    "clean_body_actionable_metadata",
    "actionable_body_clean_metadata",
    "delimiter_in_body",
    "legacy_source_adoption",
    "legacy_adoption_mismatch",
    "invalid_review_outcome",
    "actionable_phase_reuse",
    "blocked_phase_reuse",
    "source_review_self_fix",
)

HISTORY_CASES = (
    "authorized_rewrite_refresh",
    "descendant_head_invalidates",
    "unapproved_rewrite",
    "posthoc_divergence_detected",
    "mismatched_approval",
    "rewrite_conflict",
    "cancelled_approval_rejected",
    "fresh_review_after_rewrite",
    "shipping_command_invariance",
    "shipping_command_changed_axis",
)

RETRO_CASES = (
    "retro_structured_metrics",
    "legacy_partial_metrics",
    "legacy_partial_missing_timestamp",
    "legacy_partial_empty_timestamp",
    "legacy_partial_invalid_timestamp",
    "retro_stale_range",
    "facilitator_artifact_missing",
    "facilitator_artifact_changed",
    "facilitator_receipt_conflict",
    "facilitator_journal_conflict",
    "facilitator_artifact_unpublished",
    "unknown_count_completeness",
)

LIFECYCLE_CASES = ("full_lifecycle",)
FULL_GATE_REPORT = "evidence/U5/full-validation-gate.md"

FULL_VALIDATION_COMMANDS = (
    "bash scripts/test-body-seal.sh",
    "bash scripts/test-final-action-skip.sh",
    "bash scripts/test-manifest-version-sync.sh",
    "bash scripts/test-plan-consumer-portability.sh",
    "bash scripts/test-plan-frontmatter.sh",
    "bash scripts/test-planning-schema-portability.sh",
    "bash scripts/test-plugin-skill-discovery.sh",
    "bash scripts/test-python-compatibility.sh all",
    "bash scripts/test-python-compatibility.sh fixtures",
    "bash scripts/test-release-loop-worktree-default.sh",
    "bash scripts/test-release-publication.sh all",
    "bash scripts/test-retro-format-drift.sh",
    "bash scripts/test-signal-drift.sh",
    "bash scripts/test-run-artifact-integrity.sh all",
    "bash scripts/validate.sh",
    "git diff --check",
)


INVOCATIONS = (
    ("skill-initialize", SKILL, 'python3 "$release_loop_skill_root/scripts/run-artifact-integrity.py" initialize --repo . --feature <feature_slug>'),
    ("skill-discover", SKILL, 'python3 "$release_loop_skill_root/scripts/run-artifact-integrity.py" discover --repo . --progress-path <repo-relative-progress-path>'),
    ("archive", ARCHIVE, 'python3 "$release_loop_skill_root/scripts/run-artifact-integrity.py" archive --repo . --progress-path <repo-relative-progress-path> --destination <repo-relative-archive-path>'),
    ("handoff", HOOKS, 'python3 "$release_loop_skill_root/scripts/run-artifact-integrity.py" handoff --repo <source-worktree> --base-repo <base-checkout> --progress-path <repo-relative-progress-path>'),
    ("phase-packet", SKILL, 'progress_path: <repo-relative-progress-path>'),
    ("phase-publisher", SKILL, 'python3 "$release_loop_skill_root/scripts/run-artifact-integrity.py" publish --repo . --progress-path <repo-relative-progress-path> --source <repo-relative-temporary-path> --target <repo-relative-final-path>'),
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


def new_history_repo(tmp: Path, conflict: bool = False, name: str = "repo") -> Path:
    repo = new_repo(tmp, name)
    git(repo, "branch", "-M", "main")
    git(repo, "checkout", "-qb", "origin-main-work")
    if conflict:
        (repo / "README.md").write_text("remote\n", encoding="utf-8")
        git(repo, "add", "README.md")
    else:
        (repo / "remote.txt").write_text("remote\n", encoding="utf-8")
        git(repo, "add", "remote.txt")
    git(repo, "commit", "-qm", "remote base")
    remote_head = git(repo, "rev-parse", "HEAD")
    git(repo, "update-ref", "refs/remotes/origin/main", remote_head)
    git(repo, "checkout", "-q", "main")
    (repo / "local.txt").write_text("local\n", encoding="utf-8")
    git(repo, "add", "local.txt")
    git(repo, "commit", "-qm", "local base")
    git(repo, "checkout", "-qb", "feat/fixture")
    if conflict:
        (repo / "README.md").write_text("feature\n", encoding="utf-8")
        git(repo, "add", "README.md")
    else:
        (repo / "feature.txt").write_text("feature\n", encoding="utf-8")
        git(repo, "add", "feature.txt")
    git(repo, "commit", "-qm", "feature")
    git(repo, "branch", "-D", "origin-main-work")
    return repo


def git_show(source_root: Path, revision: str, path: str) -> str:
    result = subprocess.run(
        ("git", "show", f"{revision}:{path}"),
        cwd=source_root,
        check=True,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    return result.stdout


def shipping_command_blocks(text: str) -> dict[str, object]:
    merge_section = text.split("## Step 7: Merge Gate", 1)[1].split("## Step 8: Cleanup", 1)[0]
    cleanup_section = text.split("## Step 8: Cleanup", 1)[1].split("## Handoff", 1)[0]
    merge = tuple(
        line for line in merge_section.splitlines()
        if line.startswith("gh pr merge ")
    )
    ordering = tuple(
        line for line in cleanup_section.splitlines()
        if line.startswith("Merge ordering invariant")
    )
    commands = tuple(
        token for line in cleanup_section.splitlines()
        for index, token in enumerate(line.split("`"))
        if index % 2 == 1 and (token.startswith("git ") or token.startswith("gh "))
    )
    if len(merge) != 1 or len(ordering) != 1:
        raise AssertionError("shipping command block extraction failed")
    return {"merge": merge, "cleanup": (ordering, commands)}


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
    COMMAND_TRACE.append({
        "argv": [sys.executable, str(cli), command, *args],
        "cwd": str(cwd),
        "exit_status": result.returncode,
        "stdout": result.stdout[-1000:],
        "stderr": result.stderr[-1000:],
    })
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


def matrix_fixture_snapshot(repo: Path) -> dict[str, object]:
    inventory = []
    for path in sorted(repo.rglob("*")):
        if ".git" in path.relative_to(repo).parts:
            continue
        relative = path.relative_to(repo).as_posix()
        inventory.append({
            "path": relative,
            "kind": "symlink" if path.is_symlink() else "file" if path.is_file() else "directory",
            "sha256_or_target": (
                os.readlink(path) if path.is_symlink()
                else hashlib.sha256(path.read_bytes()).hexdigest() if path.is_file()
                else None
            ),
        })
    return {
        "head": git(repo, "rev-parse", "HEAD"),
        "index": git(repo, "write-tree"),
        "status": git(repo, "status", "--short"),
        "inventory": inventory,
    }


def write_matrix_observation(
    case: str,
    repo: Path,
    pre_state: dict[str, object],
    sent: Path,
    before: bytes,
) -> None:
    selected = os.environ.get("RUN_ARTIFACT_MATRIX_OBSERVATION")
    if selected is None:
        return
    target = Path(selected)
    after = sent.read_bytes()
    roots = sorted(
        path.relative_to(repo).as_posix()
        for path in (repo / ".release-loop").glob("**/progress.md")
        if path.is_file()
    ) if (repo / ".release-loop").is_dir() else []
    observation = {
        "schema": "matrix-fixture-observation/v1",
        "case": case,
        "disposable_root": str(repo),
        "progress_records": roots,
        "pre_state": pre_state,
        "post_state": matrix_fixture_snapshot(repo),
        "command_trace": COMMAND_TRACE,
        "boundary_sentinel": {
            "path": str(sent),
            "pre_sha256": hashlib.sha256(before).hexdigest(),
            "post_sha256": hashlib.sha256(after).hexdigest(),
            "unchanged": after == before,
        },
        "stub_identity": "not applicable; disposable local Git and filesystem only",
        "next_invocation": ["bash", "scripts/test-run-artifact-integrity.sh", case],
        "mechanism_check": "all case assertions completed and the boundary sentinel stayed byte-identical",
        "timestamp_utc": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    }
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(json.dumps(observation, sort_keys=True, separators=(",", ":")) + "\n", encoding="utf-8")


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
    mode: str = "completed",
) -> list[str]:
    if destination is not None and persist_authority:
        persist_archive_evidence(repo / progress_path, destination, mode)
    args = ["--repo", str(repo), "--progress-path", progress_path]
    if destination is not None:
        args.extend(("--destination", destination))
    payload = run_cli(
        "archive",
        *args,
        failure="archive-after-first" if fail_after_first else None,
    )
    assert set(payload) == {"archive_path", "moved", "progress_path", "state"}, payload
    expected_state = "archived" if mode == "completed" else "archived-incomplete"
    assert payload["state"] == expected_state, payload
    return list(payload["moved"])


def persist_archive_evidence(path: Path, destination: str, mode: str) -> None:
    text = path.read_text(encoding="utf-8")
    assert "archive-destination:" not in text
    if mode == "completed":
        text = text.replace("phase: implement\n", "phase: done\n", 1)
        text = text.replace("phase_status: in-progress\n", "phase_status: complete\n", 1)
        marker = f"- 2026-08-23T00:00:01Z retro: archive-destination: {destination}\n"
    elif mode == "incomplete":
        marker = f"- 2026-08-23T00:00:01Z archived-incomplete: archive-destination: {destination}\n"
    else:
        raise AssertionError(f"unknown fixture archive mode: {mode}")
    path.write_text(text + marker, encoding="utf-8")


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


def require_phase_consumer_contract() -> None:
    shared = ("exact repo-relative `progress_path`", "`artifact_root = dirname(progress_path)`")
    missing = [f"{name}: {fragment}" for name, text in PHASE_CONSUMERS.items() for fragment in shared if fragment not in text]
    required = (
        (PHASE_CONSUMERS["planning"], "<artifact_root>/evidence/U<N>/"),
        (PHASE_CONSUMERS["implementing"], "<artifact_root>/briefs/U<N>-brief.md"),
        (PHASE_CONSUMERS["implementing"], "<artifact_root>/reports/U<N>-report.md"),
        (PHASE_CONSUMERS["implementing"], "<artifact_root>/reviews/U<N>-diff.txt"),
        (PHASE_CONSUMERS["reviewing"], "<artifact_root>/evidence/U<N>/"),
        (PLAN_SCHEMA, "<artifact_root>/evidence/U<N>/"),
        (PLAN_SCHEMA, "executable probe"),
        (PLAN_SCHEMA, "exact partial durable state"),
        (PLAN_SCHEMA, "compensation owner"),
    )
    missing.extend(fragment for text, fragment in required if fragment not in text)
    if missing:
        raise AssertionError("fixed-root consumer contract: " + " | ".join(missing))


def publish_phase_artifact(
    repo: Path,
    progress_path: Path,
    relative: str,
    content: bytes,
    failure: str | None = None,
) -> Path:
    root = progress_path.parent
    source = root / ".tmp" / (relative.replace("/", "-") + ".tmp")
    source.parent.mkdir(parents=True, exist_ok=True)
    source.write_bytes(content)
    payload = run_cli(
        "publish",
        "--repo", str(repo),
        "--progress-path", progress_path.relative_to(repo).as_posix(),
        "--source", source.relative_to(repo).as_posix(),
        "--target", (root / relative).relative_to(repo).as_posix(),
        failure=failure,
    )
    assert set(payload) == {"progress_path", "sha256", "state", "target"}, payload
    assert payload["state"] in {"published", "reused"}, payload
    return repo / str(payload["target"])


def publish_from_cli(repo: Path, progress_path: Path, relative: str, content: bytes, cli: Path, failure: str | None = None) -> dict[str, object]:
    source = progress_path.parent / ".tmp" / (relative.replace("/", "-") + ".tmp")
    source.parent.mkdir(parents=True, exist_ok=True)
    if not source.exists():
        source.write_bytes(content)
    return run_cli(
        "publish",
        "--repo", str(repo),
        "--progress-path", progress_path.relative_to(repo).as_posix(),
        "--source", source.relative_to(repo).as_posix(),
        "--target", (progress_path.parent / relative).relative_to(repo).as_posix(),
        failure=failure,
        cli=cli,
    )


def require_review_contract() -> None:
    required = (
        (SCHEMA, "review_events:"),
        (SCHEMA, "finding_dispositions:"),
        (SCHEMA, "review_counts:"),
        (SCHEMA, "<kind>:<subject>:<ordinal>"),
        (SCHEMA, "completed review result missing"),
        (SCHEMA, "completed review digest mismatch"),
        (IMPLEMENTING, "Allocate and persist the review event before dispatch"),
        (IMPLEMENTING, "reviewer body verbatim"),
        (IMPLEMENTING, "Only the verifying re-review operation writes `fixed`"),
        (REVIEWING, "cheapest artifact that satisfies every written check"),
        (REVIEWING, "phase-gate reuse does not allocate another event"),
        (MERGE_PIPELINE, "review-body and outside-diff"),
        (MERGE_PIPELINE, "allowed disposition"),
    )
    missing = [fragment for text, fragment in required if fragment not in text]
    if missing:
        raise AssertionError("missing sealed-review contract: " + " | ".join(missing))


def require_history_contract() -> None:
    shipping = PHASE_CONSUMERS["shipping"]
    required = (
        (SCHEMA, "current_commit_range:"),
        (SCHEMA, "review_gate:"),
        (SCHEMA, "stale-commit-range"),
        (SKILL, "Any head change clears `review_gate`"),
        (IMPLEMENTING, "equals the current full `HEAD`"),
        (REVIEWING, "equals the current full `HEAD`"),
        (shipping, "current-session USER rewrite approval"),
        (shipping, "exact rewrite command"),
        (shipping, "post-mutation result"),
        (shipping, "stale-commit-range"),
    )
    missing = [fragment for text, fragment in required if fragment not in text]
    if missing:
        raise AssertionError("missing exact-head history contract: " + " | ".join(missing))


def require_retro_contract() -> None:
    retrospective = PHASE_CONSUMERS["retrospective"]
    required = (
        (retrospective, "unit_passes + final_passes + standalone_passes"),
        (retrospective, "lower bound since `counting_started_at`"),
        (retrospective, "unknown `completeness` value blocks"),
        (retrospective, "stale-commit-range"),
        (retrospective, "reviews/facilitator/round-<N>.md"),
        (retrospective, "Persist every facilitator round verbatim"),
        (retrospective, "publisher receipt path and SHA-256"),
        (retrospective, "ownership journal"),
        (retrospective, "same persisted edit"),
        (retrospective, "valid ISO-8601 UTC timestamp"),
        (retrospective, "full_validation_gate"),
        (retrospective, "sixteen exact commands"),
        (RETRO_TEMPLATE, "Review rounds (unit / final / standalone)"),
        (RETRO_TEMPLATE, "Internal findings (fixed / deferred)"),
        (RETRO_TEMPLATE, "Pull request comments (fixed / deferred)"),
        (RETRO_TEMPLATE, "Count completeness"),
    )
    missing = [fragment for text, fragment in required if fragment not in text]
    if missing:
        raise AssertionError("missing structured Retro contract: " + " | ".join(missing))


def reviewer_output(
    outcome: str,
    review_body: tuple[str, ...] = (),
    outside_diff: tuple[str, ...] = (),
    severity: str = "P1",
    tail: bytes = b"",
) -> bytes:
    inventory = [
        *({"fingerprint": fingerprint, "severity": severity, "source": "review-body"} for fingerprint in review_body),
        *({"fingerprint": fingerprint, "severity": severity, "source": "outside-diff"} for fingerprint in outside_diff),
    ]
    manifest = {"finding_inventory": inventory, "outcome": outcome, "schema": "review-body/v1"}
    return json.dumps(manifest, sort_keys=True, separators=(",", ":")).encode() + b"\n" + tail


class ReviewFixture:
    SOURCE_KINDS = frozenset(("unit", "final", "standalone"))

    def __init__(self, repo: Path, progress_path: Path) -> None:
        self.repo = repo
        self.progress_path = progress_path
        self.events: list[dict[str, object]] = []
        self.dispositions: dict[str, dict[str, str | None]] = {}
        self.persisted_writes = 0
        self._progress_prefix = progress_path.read_text(encoding="utf-8")
        self._persist()

    def _persist(self) -> None:
        state = {
            "finding_dispositions": self.dispositions,
            "review_counts": self.counts(),
            "review_events": self.events,
        }
        rendered = json.dumps(state, sort_keys=True, separators=(",", ":"))
        self.progress_path.write_text(
            self._progress_prefix + "\n## Review Fixture State\n\n```json\n" + rendered + "\n```\n",
            encoding="utf-8",
        )
        self.persisted_writes += 1

    def event(self, event_id: str) -> dict[str, object]:
        matches = [event for event in self.events if event["id"] == event_id]
        if len(matches) != 1:
            raise Blocked(f"review event conflict: {event_id}")
        return matches[0]

    def allocate(
        self,
        kind: str,
        subject: str,
        head: str,
        re_review_of: str | None = None,
        source_review_event: str | None = None,
    ) -> dict[str, object]:
        if kind not in {"unit", "fix", "final", "standalone"}:
            raise Blocked(f"unknown review event kind: {kind}")
        siblings = [event for event in self.events if event["kind"] == kind and event["subject"] == subject]
        ordinals = sorted(int(event["ordinal"]) for event in siblings)
        if ordinals != list(range(1, len(ordinals) + 1)):
            raise Blocked(f"review event ordinal gap: {kind}:{subject}")
        started = [event for event in siblings if event["state"] == "started"]
        if started:
            if len(started) != 1:
                raise Blocked(f"review event conflict: {kind}:{subject}")
            event = started[0]
            if event["reviewed_head"] != head or event["re_review_of"] != re_review_of or event["source_review_event"] != source_review_event:
                raise Blocked(f"review event conflict: {event['id']}")
            return event
        ordinal = len(siblings) + 1
        if re_review_of is not None:
            if kind not in self.SOURCE_KINDS:
                raise Blocked("only source review kinds may re-review")
            source = self.event(re_review_of)
            if source["state"] != "complete" or source["kind"] != kind or source["subject"] != subject:
                raise Blocked("re-review source mismatch")
            if int(source["ordinal"]) != ordinal - 1:
                raise Blocked("re-review source order mismatch")
        if kind == "fix":
            if not isinstance(source_review_event, str) or self.event(source_review_event)["state"] != "complete":
                raise Blocked("fix source review mismatch")
        elif source_review_event is not None:
            raise Blocked("non-fix event has fix source")
        event_id = f"{kind}:{subject}:{ordinal}"
        result_path = self.progress_path.parent / f"reviews/events/{kind}-{subject}-{ordinal}.md"
        event: dict[str, object] = {
            "id": event_id,
            "kind": kind,
            "subject": subject,
            "ordinal": ordinal,
            "state": "started",
            "reviewed_head": head,
            "result_path": result_path.relative_to(self.repo).as_posix(),
            "result_sha256": None,
            "outcome": None,
            "finding_inventory": [],
            "source_review_event": source_review_event,
            "re_review_of": re_review_of,
            "source_adoption_path": None,
            "source_adoption_sha256": None,
        }
        self.events.append(event)
        self._persist()
        assert event_id in self.progress_path.read_text(encoding="utf-8")
        return event

    def _result_path(self, event: dict[str, object]) -> Path:
        return self.repo / str(event["result_path"])

    def _result_relative(self, event: dict[str, object]) -> str:
        return self._result_path(event).relative_to(self.progress_path.parent).as_posix()

    def _body_manifest(self, reviewer_body: bytes) -> dict[str, object]:
        first_line = reviewer_body.split(b"\n", 1)[0]
        try:
            manifest = json.loads(first_line)
        except (UnicodeDecodeError, json.JSONDecodeError) as exc:
            raise Blocked("reviewer body manifest invalid") from exc
        if set(manifest) != {"schema", "outcome", "finding_inventory"} or manifest["schema"] != "review-body/v1":
            raise Blocked("reviewer body manifest invalid")
        if manifest["outcome"] not in {"clean", "actionable", "blocked"}:
            raise Blocked(f"reviewer body outcome invalid: {manifest['outcome']}")
        return manifest

    def _wrapper(self, event: dict[str, object], reviewer_body: bytes) -> bytes:
        manifest = self._body_manifest(reviewer_body)
        metadata = {
            "body_length": len(reviewer_body),
            "body_sha256": hashlib.sha256(reviewer_body).hexdigest(),
            "event_id": event["id"],
            "finding_inventory": manifest["finding_inventory"],
            "outcome": manifest["outcome"],
            "re_review_of": event["re_review_of"],
            "reviewed_head": event["reviewed_head"],
            "schema": "review-result/v1",
        }
        return json.dumps(metadata, sort_keys=True, separators=(",", ":")).encode() + b"\n" + reviewer_body

    def _parse_wrapper(self, event: dict[str, object], payload: bytes) -> tuple[dict[str, object], bytes]:
        if b"\n" not in payload:
            raise Blocked(f"review result wrapper invalid: {event['id']}")
        header, reviewer_body = payload.split(b"\n", 1)
        try:
            metadata = json.loads(header)
        except (UnicodeDecodeError, json.JSONDecodeError) as exc:
            raise Blocked(f"review result wrapper invalid: {event['id']}") from exc
        required = {"schema", "event_id", "reviewed_head", "outcome", "finding_inventory", "re_review_of", "body_length", "body_sha256"}
        if set(metadata) != required or metadata["schema"] != "review-result/v1":
            raise Blocked(f"review result wrapper invalid: {event['id']}")
        if metadata["event_id"] != event["id"] or metadata["reviewed_head"] != event["reviewed_head"]:
            raise Blocked(f"review result wrapper identity mismatch: {event['id']}")
        if metadata["re_review_of"] != event["re_review_of"]:
            raise Blocked(f"review result wrapper re-review mismatch: {event['id']}")
        if metadata["body_length"] != len(reviewer_body) or metadata["body_sha256"] != hashlib.sha256(reviewer_body).hexdigest():
            raise Blocked(f"review result wrapper body mismatch: {event['id']}")
        manifest = self._body_manifest(reviewer_body)
        if metadata["outcome"] != manifest["outcome"] or metadata["finding_inventory"] != manifest["finding_inventory"]:
            raise Blocked(f"review result wrapper manifest mismatch: {event['id']}")
        inventory = metadata["finding_inventory"]
        if not isinstance(inventory, list):
            raise Blocked(f"review result wrapper invalid: {event['id']}")
        fingerprints = []
        for row in inventory:
            if not isinstance(row, dict) or set(row) != {"fingerprint", "severity", "source"}:
                raise Blocked(f"review result wrapper invalid: {event['id']}")
            if row["severity"] not in {"P0", "P1", "P2", "P3"} or row["source"] not in {"structured", "review-body", "outside-diff"}:
                raise Blocked(f"review result wrapper invalid: {event['id']}")
            fingerprints.append(row["fingerprint"])
        if len(fingerprints) != len(set(fingerprints)):
            raise Blocked(f"review result wrapper duplicate finding: {event['id']}")
        return metadata, reviewer_body

    def complete(
        self,
        event_id: str,
        reviewer_body: bytes,
    ) -> dict[str, object]:
        event = self.event(event_id)
        wrapper = self._wrapper(event, reviewer_body)
        if event["state"] == "complete":
            self.verify_result(event_id)
            if self._result_path(event).read_bytes() != wrapper:
                raise Blocked(f"review-event-conflict: {event_id}")
            return event
        try:
            payload = publish_from_cli(self.repo, self.progress_path, self._result_relative(event), wrapper, IMPLEMENTING_CLI)
        except Blocked as exc:
            raise Blocked(f"review-event-conflict: {event_id}: {exc}") from exc
        metadata, observed_body = self._parse_wrapper(event, wrapper)
        assert observed_body == reviewer_body, "verbatim reviewer body changed"
        event["state"] = "complete"
        event["result_sha256"] = str(payload["sha256"])
        event["outcome"] = metadata["outcome"]
        event["finding_inventory"] = metadata["finding_inventory"]
        self._persist()
        return event

    def recover(self, event_id: str) -> str:
        event = self.event(event_id)
        if event["state"] == "complete":
            self.verify_result(event_id)
            return "complete"
        result_path = self._result_path(event)
        if not result_path.exists():
            return "redispatch"
        journal_path = self.progress_path.parent / ".phase-artifact-ownership.json"
        if not journal_path.is_file():
            raise Blocked(f"review-event-conflict: {event_id}")
        journal = json.loads(journal_path.read_text(encoding="utf-8"))
        digest = hashlib.sha256(result_path.read_bytes()).hexdigest()
        if journal.get("owned", {}).get(self._result_relative(event)) != digest:
            raise Blocked(f"review-event-conflict: {event_id}")
        metadata, _ = self._parse_wrapper(event, result_path.read_bytes())
        event["state"] = "complete"
        event["result_sha256"] = digest
        event["outcome"] = metadata["outcome"]
        event["finding_inventory"] = metadata["finding_inventory"]
        self._persist()
        return "recovered"

    def verify_result(self, event_id: str) -> tuple[dict[str, object], bytes]:
        event = self.event(event_id)
        if event["state"] != "complete":
            raise Blocked(f"review event incomplete: {event_id}")
        result_path = self._result_path(event)
        if not result_path.is_file():
            raise Blocked(f"completed review result missing: {event_id}")
        payload = result_path.read_bytes()
        if hashlib.sha256(payload).hexdigest() != event["result_sha256"]:
            raise Blocked(f"completed review digest mismatch: {event_id}")
        metadata, reviewer_body = self._parse_wrapper(event, payload)
        if metadata["outcome"] != event["outcome"] or metadata["finding_inventory"] != event["finding_inventory"]:
            raise Blocked(f"review result ledger mismatch: {event_id}")
        return metadata, reviewer_body

    def counts(self) -> dict[str, int]:
        complete = [event for event in self.events if event["state"] == "complete"]
        return {
            "unit_passes": sum(event["kind"] == "unit" for event in complete),
            "fix_rounds": sum(event["kind"] == "fix" for event in complete),
            "final_passes": sum(event["kind"] == "final" for event in complete),
            "standalone_passes": sum(event["kind"] == "standalone" for event in complete),
            "findings_fixed": sum(row["status"] == "fixed" for row in self.dispositions.values()),
            "findings_deferred": sum(row["status"] == "deferred" for row in self.dispositions.values()),
        }

    def _sealed_finding(self, fingerprint: str) -> tuple[dict[str, str], str]:
        for event in self.events:
            if event["state"] != "complete":
                continue
            metadata = self._source_metadata(event)
            for row in metadata["finding_inventory"]:
                if row["fingerprint"] == fingerprint:
                    return row, str(event["id"])
        raise Blocked(f"unknown finding fingerprint: {fingerprint}")

    def adopt_legacy_source(
        self,
        event_id: str,
        outcome: str,
        inventory: list[dict[str, str]],
    ) -> None:
        event = self.event(event_id)
        result_path = self._result_path(event)
        if event["state"] != "complete" or not result_path.is_file():
            raise Blocked("legacy source adoption result missing")
        digest = hashlib.sha256(result_path.read_bytes()).hexdigest()
        if digest != event["result_sha256"]:
            raise Blocked("legacy source adoption result mismatch")
        adoption = {
            "finding_inventory": inventory,
            "outcome": outcome,
            "result_path": event["result_path"],
            "result_sha256": digest,
            "reviewed_head": event["reviewed_head"],
            "schema": "review-legacy-source-adoption/v1",
            "source_event": event_id,
        }
        content = json.dumps(adoption, sort_keys=True, separators=(",", ":")).encode() + b"\n"
        relative = f"reviews/adoptions/{event_id.replace(':', '-')}.json"
        payload = publish_from_cli(self.repo, self.progress_path, relative, content, IMPLEMENTING_CLI)
        event["source_adoption_path"] = str(payload["target"])
        event["source_adoption_sha256"] = str(payload["sha256"])
        self._persist()

    def _source_metadata(self, event: dict[str, object]) -> dict[str, object]:
        try:
            metadata, _ = self.verify_result(str(event["id"]))
            return metadata
        except Blocked as wrapper_error:
            adoption_path = event.get("source_adoption_path")
            adoption_sha = event.get("source_adoption_sha256")
            if not isinstance(adoption_path, str) or not isinstance(adoption_sha, str):
                raise wrapper_error
            path = self.repo / adoption_path
            if not path.is_file() or hashlib.sha256(path.read_bytes()).hexdigest() != adoption_sha:
                raise Blocked("legacy source adoption integrity mismatch")
            try:
                adoption = json.loads(path.read_text(encoding="utf-8"))
            except json.JSONDecodeError as exc:
                raise Blocked("legacy source adoption invalid") from exc
            expected = {
                "schema": "review-legacy-source-adoption/v1",
                "source_event": event["id"],
                "result_path": event["result_path"],
                "result_sha256": event["result_sha256"],
                "reviewed_head": event["reviewed_head"],
                "outcome": adoption.get("outcome"),
                "finding_inventory": adoption.get("finding_inventory"),
            }
            if adoption != expected:
                raise Blocked("legacy source adoption metadata mismatch")
            result_path = self.repo / str(event["result_path"])
            if not result_path.is_file() or hashlib.sha256(result_path.read_bytes()).hexdigest() != event["result_sha256"]:
                raise Blocked("legacy source adoption result mismatch")
            return adoption

    def set_disposition(self, fingerprint: str, status: str, event_id: str, rationale: str | None = None) -> None:
        event = self.event(event_id)
        if event["state"] != "complete":
            raise Blocked(f"disposition event incomplete: {event_id}")
        if event["kind"] == "fix":
            raise Blocked("fix event cannot change disposition")
        if status != "deferred":
            raise Blocked("fixed requires verifying re-review")
        if status == "deferred" and not rationale:
            raise Blocked(f"deferred finding requires rationale: {fingerprint}")
        row, introduced_by = self._sealed_finding(fingerprint)
        current = self.dispositions.get(fingerprint)
        if current is not None and current["status"] == "fixed":
            raise Blocked(f"fixed finding is terminal: {fingerprint}")
        self.dispositions[fingerprint] = {
            "status": status,
            "severity": row["severity"],
            "introduced_by": current["introduced_by"] if current else introduced_by,
            "resolved_by": event_id,
            "rationale": rationale,
        }
        self._persist()

    def verify_re_review(self, event_id: str) -> None:
        event = self.event(event_id)
        self.verify_result(event_id)
        source_id = event["re_review_of"]
        if event["kind"] not in self.SOURCE_KINDS or not isinstance(source_id, str):
            raise Blocked("only explicit verifying re-review may mark fixed")
        source = self.event(source_id)
        if source["kind"] != event["kind"] or source["subject"] != event["subject"] or int(source["ordinal"]) + 1 != int(event["ordinal"]):
            raise Blocked("re-review source mismatch")
        source_metadata = self._source_metadata(source)
        current_metadata, _ = self.verify_result(event_id)
        current = {row["fingerprint"] for row in current_metadata["finding_inventory"]}
        for row in source_metadata["finding_inventory"]:
            fingerprint = str(row["fingerprint"])
            if fingerprint in current:
                raise Blocked(f"re-review finding still present: {fingerprint}")
            prior = self.dispositions.get(fingerprint)
            self.dispositions[fingerprint] = {
                "status": "fixed",
                "severity": row["severity"],
                "introduced_by": prior["introduced_by"] if prior else source_id,
                "resolved_by": event_id,
                "rationale": None,
            }
        self._persist()

    def clean_gate(self, event_id: str) -> None:
        event = self.event(event_id)
        result_path = self._result_path(event)
        if not result_path.is_file():
            raise Blocked(f"completed review result missing: {event_id}")
        payload = result_path.read_bytes()
        if hashlib.sha256(payload).hexdigest() != event["result_sha256"]:
            raise Blocked(f"completed review digest mismatch: {event_id}")
        metadata, _ = self._parse_wrapper(event, payload)
        sealed_rows = {
            (str(row["fingerprint"]), str(row["source"]), str(row["severity"]))
            for row in metadata["finding_inventory"]
        }
        recorded_rows = {
            (str(row["fingerprint"]), str(row["source"]), str(row["severity"]))
            for row in event["finding_inventory"]
        }
        omitted = sorted(sealed_rows - recorded_rows)
        extra = sorted(recorded_rows - sealed_rows)
        if omitted or extra:
            raise Blocked(f"finding inventory mismatch: omitted={omitted}; extra={extra}")
        for fingerprint, _, severity in sorted(sealed_rows):
            disposition = self.dispositions.get(fingerprint)
            if disposition is None:
                raise Blocked(f"finding lacks terminal disposition: {fingerprint}")
            if disposition["severity"] != severity:
                raise Blocked(f"finding disposition severity mismatch: {fingerprint}")
            if disposition["status"] == "fixed":
                continue
            if severity == "P3" and disposition["status"] == "deferred" and disposition["rationale"]:
                continue
            raise Blocked(f"{severity} finding remains actionable: {fingerprint}")

    def reuse_phase_gate(self, event_id: str) -> dict[str, object]:
        event = self.event(event_id)
        metadata, _ = self.verify_result(event_id)
        if metadata["outcome"] != "clean":
            raise Blocked(f"phase-gate reuse requires clean outcome: {metadata['outcome']}")
        self.clean_gate(event_id)
        return event


class HistoryFixture:
    def __init__(self, repo: Path, progress_path: Path, base_branch: str, session: str) -> None:
        self.repo = repo
        self.progress_path = progress_path
        self.base_branch = base_branch
        self.session = session
        self.current_commit_range = self.git_range()
        head = self.current_commit_range["head"]
        self.review_counts = {
            "unit_passes": 2,
            "fix_rounds": 1,
            "final_passes": 1,
            "standalone_passes": 0,
            "findings_fixed": 1,
            "findings_deferred": 0,
        }
        self.review_events: list[dict[str, object]] = [
            {"id": "final:branch:1", "kind": "final", "outcome": "clean", "reviewed_head": head},
        ]
        self.review_gate: dict[str, str | None] = {"event_id": "final:branch:1", "head": head}
        self.rewrite_approvals: list[dict[str, object]] = []
        self.rewrite_results: list[dict[str, object]] = []
        self.command_calls = 0
        self.last_command: dict[str, object] | None = None
        self.persisted_writes = 0
        self._progress_prefix = progress_path.read_text(encoding="utf-8")
        self._persist()

    def git_range(self) -> dict[str, str]:
        return {
            "base": git(self.repo, "merge-base", self.base_branch, "HEAD"),
            "head": git(self.repo, "rev-parse", "HEAD"),
        }

    def _persist(self) -> None:
        state = {
            "current_commit_range": self.current_commit_range,
            "review_counts": self.review_counts,
            "review_events": self.review_events,
            "review_gate": self.review_gate,
            "rewrite_approvals": self.rewrite_approvals,
            "rewrite_results": self.rewrite_results,
        }
        rendered = json.dumps(state, sort_keys=True, separators=(",", ":"))
        self.progress_path.write_text(
            self._progress_prefix + "\n## History Fixture State\n\n```json\n" + rendered + "\n```\n",
            encoding="utf-8",
        )
        self.persisted_writes += 1

    def _is_ancestor(self, old: str, new: str) -> bool:
        result = subprocess.run(
            ("git", "merge-base", "--is-ancestor", old, new),
            cwd=self.repo,
            check=False,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        return result.returncode == 0

    def refresh(self) -> None:
        observed = self.git_range()
        if observed == self.current_commit_range:
            return
        if not self._is_ancestor(str(self.current_commit_range["head"]), observed["head"]):
            raise Blocked("stale-commit-range")
        self.current_commit_range = observed
        self.review_gate = {"event_id": None, "head": None}
        self._persist()

    def approve(self, command: str, target_base: str) -> dict[str, object]:
        if self.git_range() != self.current_commit_range:
            raise Blocked("stale-commit-range")
        approval: dict[str, object] = {
            "id": f"rewrite:{len(self.rewrite_approvals) + 1}",
            "state": "active",
            "approver": "USER",
            "session": self.session,
            "timestamp": "2026-08-24T00:00:00Z",
            "old_range": dict(self.current_commit_range),
            "command": command,
            "target_base": target_base,
        }
        self.rewrite_approvals.append(approval)
        self._persist()
        return approval

    def _active_approval(self, command: str, target_base: str) -> dict[str, object]:
        matches = [
            row for row in self.rewrite_approvals
            if row["state"] == "active"
            and row["approver"] == "USER"
            and row["session"] == self.session
            and row["command"] == command
            and row["target_base"] == target_base
            and row["old_range"] == self.current_commit_range
        ]
        if len(matches) != 1 or self.git_range() != self.current_commit_range:
            raise Blocked("stale-commit-range")
        return matches[0]

    def run_fixture_rewrite(self, command: str) -> int:
        args = shlex.split(command)
        if args[:3] != ["git", "rebase", "--onto"]:
            raise AssertionError(f"unexpected fixture rewrite command: {command}")
        self.command_calls += 1
        result = subprocess.run(
            tuple(args),
            cwd=self.repo,
            check=False,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        self.last_command = {
            "command": command,
            "exit_status": result.returncode,
            "stdout": result.stdout[-1000:],
            "stderr": result.stderr[-1000:],
        }
        return result.returncode

    def rewrite(self, command: str, target_base: str) -> dict[str, object]:
        approval = self._active_approval(command, target_base)
        old_range = dict(self.current_commit_range)
        exit_status = self.run_fixture_rewrite(command)
        verification_command = f"git merge-base {self.base_branch} HEAD && git rev-parse HEAD"
        if exit_status == 0:
            observed = self.git_range()
            approval["state"] = "consumed"
            result: dict[str, object] = {
                "approval_id": approval["id"],
                "state": "success",
                "exit_status": 0,
                "verification_command": verification_command,
                "old_range": old_range,
                "new_range": observed,
            }
            self.current_commit_range = observed
        else:
            git(self.repo, "rebase", "--abort")
            observed = self.git_range()
            if observed != old_range:
                raise AssertionError(f"rebase abort did not restore range: {observed}")
            approval["state"] = "failed"
            result = {
                "approval_id": approval["id"],
                "state": "failed",
                "exit_status": exit_status,
                "verification_command": verification_command,
                "old_range": old_range,
                "new_range": observed,
            }
        self.review_gate = {"event_id": None, "head": None}
        self.rewrite_results.append(result)
        self._persist()
        return result

    def cancel(self, approval_id: str) -> dict[str, object]:
        matches = [row for row in self.rewrite_approvals if row["id"] == approval_id and row["state"] == "active"]
        if len(matches) != 1:
            raise Blocked("stale-commit-range")
        approval = matches[0]
        approval["state"] = "cancelled"
        result: dict[str, object] = {
            "approval_id": approval_id,
            "state": "cancelled",
            "exit_status": None,
            "verification_command": None,
            "old_range": dict(self.current_commit_range),
            "new_range": dict(self.current_commit_range),
        }
        self.rewrite_results.append(result)
        self._persist()
        return result

    def complete_review(self, event_id: str, reviewed_head: str) -> dict[str, object]:
        if reviewed_head != git(self.repo, "rev-parse", "HEAD"):
            raise Blocked("review gate head mismatch")
        kind = event_id.split(":", 1)[0]
        if kind not in {"final", "standalone"}:
            raise Blocked("review gate event kind mismatch")
        event = {"id": event_id, "kind": kind, "outcome": "clean", "reviewed_head": reviewed_head}
        self.review_events.append(event)
        self.review_gate = {"event_id": event_id, "head": reviewed_head}
        self._persist()
        return event

    def phase_gate(self, event_id: str) -> bool:
        current_head = git(self.repo, "rev-parse", "HEAD")
        matches = [row for row in self.review_events if row["id"] == event_id]
        if len(matches) != 1:
            raise Blocked("review gate event missing")
        event = matches[0]
        expected = {"event_id": event_id, "head": current_head}
        if event["kind"] not in {"final", "standalone"} or event["outcome"] != "clean":
            raise Blocked("review gate event invalid")
        if event["reviewed_head"] != current_head or self.review_gate != expected:
            raise Blocked("review gate head mismatch")
        return True


class RetroFixture:
    def __init__(
        self,
        repo: Path,
        progress_path: Path,
        reviews: ReviewFixture,
        current_range: dict[str, str],
        completeness: str | None,
        counting_started_at: str | None,
        pr_fixed: int = 0,
        pr_deferred: int = 0,
    ) -> None:
        self.repo = repo
        self.progress_path = progress_path
        self.reviews = reviews
        self.current_range = current_range
        self.completeness = completeness
        self.counting_started_at = counting_started_at
        self.pr_fixed = pr_fixed
        self.pr_deferred = pr_deferred
        self.facilitator_receipts: dict[int, dict[str, str]] = {}
        self.metric_state_writes = 0

    @staticmethod
    def valid_utc_timestamp(value: object) -> bool:
        if not isinstance(value, str) or not value.endswith("Z"):
            return False
        try:
            parsed = datetime.strptime(value, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=timezone.utc)
        except ValueError:
            return False
        return parsed.isoformat().replace("+00:00", "Z") == value

    def adopt_legacy_partial(self) -> str:
        if self.completeness is not None or self.counting_started_at is not None:
            raise Blocked("legacy review count adoption conflict")
        timestamp = datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")
        assert self.valid_utc_timestamp(timestamp)
        self.completeness = "partial"
        self.counting_started_at = timestamp
        state = {
            "completeness": self.completeness,
            "counting_started_at": self.counting_started_at,
        }
        with self.progress_path.open("a", encoding="utf-8") as handle:
            handle.write("\n## Retro Fixture Metric State\n\n```json\n")
            handle.write(json.dumps(state, sort_keys=True, separators=(",", ":")))
            handle.write("\n```\n")
        self.metric_state_writes += 1
        return timestamp

    def publish_facilitator_round(self, ordinal: int, body: bytes) -> Path:
        if ordinal in self.facilitator_receipts:
            raise Blocked("facilitator receipt conflict")
        relative = f"reviews/facilitator/round-{ordinal}.md"
        payload = publish_from_cli(self.repo, self.progress_path, relative, body, CLI)
        path = self.repo / str(payload["target"])
        assert path.read_bytes() == body
        self.facilitator_receipts[ordinal] = {
            "path": relative,
            "sha256": str(payload["sha256"]),
        }
        return path

    def verify_facilitator_rounds(self, expected_facilitator_rounds: int) -> None:
        expected_ordinals = set(range(1, expected_facilitator_rounds + 1))
        if set(self.facilitator_receipts) != expected_ordinals:
            raise Blocked("facilitator artifact missing")
        journal_path = self.progress_path.parent / ".phase-artifact-ownership.json"
        try:
            journal = json.loads(journal_path.read_text(encoding="utf-8"))
        except (OSError, UnicodeError, json.JSONDecodeError) as exc:
            raise Blocked("facilitator journal conflict") from exc
        if not isinstance(journal, dict) or not isinstance(journal.get("owned"), dict):
            raise Blocked("facilitator journal conflict")
        for ordinal in sorted(expected_ordinals):
            receipt = self.facilitator_receipts[ordinal]
            expected_path = f"reviews/facilitator/round-{ordinal}.md"
            if set(receipt) != {"path", "sha256"} or receipt["path"] != expected_path:
                raise Blocked("facilitator receipt conflict")
            journal_sha = journal["owned"].get(expected_path)
            if journal_sha is None:
                raise Blocked("facilitator journal conflict")
            if journal_sha != receipt["sha256"]:
                raise Blocked("facilitator receipt conflict")
            target = self.progress_path.parent / expected_path
            if not target.is_file() or target.is_symlink():
                raise Blocked("facilitator artifact unpublished")
            if hashlib.sha256(target.read_bytes()).hexdigest() != receipt["sha256"]:
                raise Blocked("facilitator artifact changed")

    def render_metrics(self, expected_facilitator_rounds: int) -> str:
        if self.current_range != {
            "base": git(self.repo, "merge-base", "main", "HEAD"),
            "head": git(self.repo, "rev-parse", "HEAD"),
        }:
            raise Blocked("stale-commit-range")
        if self.completeness not in {"exact", "partial"}:
            if self.completeness is None:
                raise Blocked("review count completeness missing")
            raise Blocked(f"unknown review count completeness: {self.completeness}")
        if self.completeness == "partial" and not self.valid_utc_timestamp(self.counting_started_at):
            raise Blocked("invalid counting_started_at")
        self.verify_facilitator_rounds(expected_facilitator_rounds)
        counts = self.reviews.counts()
        rounds = counts["unit_passes"] + counts["final_passes"] + counts["standalone_passes"]
        completeness = "exact"
        if self.completeness == "partial":
            completeness = f"partial — lower bound since {self.counting_started_at}"
        return (
            "| Metric | Value |\n"
            "|---|---|\n"
            f"| Review rounds (unit / final / standalone) | {rounds} "
            f"({counts['unit_passes']} / {counts['final_passes']} / {counts['standalone_passes']}) |\n"
            f"| Fix rounds | {counts['fix_rounds']} |\n"
            f"| Internal findings (fixed / deferred) | {counts['findings_fixed']} / {counts['findings_deferred']} |\n"
            f"| Pull request comments (fixed / deferred) | {self.pr_fixed} / {self.pr_deferred} |\n"
            f"| Count completeness | {completeness} |\n"
        )


def verify_owned_receipt(
    repo: Path,
    progress_path: Path,
    receipt: dict[str, str],
    diagnostic: str,
) -> bytes:
    if set(receipt) != {"path", "sha256"}:
        raise Blocked(f"{diagnostic} receipt conflict")
    journal_path = progress_path.parent / ".phase-artifact-ownership.json"
    try:
        journal = json.loads(journal_path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        raise Blocked(f"{diagnostic} journal conflict") from exc
    owned = journal.get("owned") if isinstance(journal, dict) else None
    if not isinstance(owned, dict) or owned.get(receipt["path"]) != receipt["sha256"]:
        raise Blocked(f"{diagnostic} journal conflict")
    target = progress_path.parent / receipt["path"]
    if not target.is_file() or target.is_symlink():
        raise Blocked(f"{diagnostic} unpublished")
    payload = target.read_bytes()
    if hashlib.sha256(payload).hexdigest() != receipt["sha256"]:
        raise Blocked(f"{diagnostic} changed")
    return payload


def full_gate_receipt(repo: Path, progress_path: Path) -> dict[str, str]:
    journal_path = progress_path.parent / ".phase-artifact-ownership.json"
    try:
        journal = json.loads(journal_path.read_text(encoding="utf-8"))
        digest = journal["owned"][FULL_GATE_REPORT]
    except (OSError, KeyError, TypeError, json.JSONDecodeError) as exc:
        raise Blocked("full-validation-gate receipt missing") from exc
    return {"path": FULL_GATE_REPORT, "sha256": str(digest)}


def validate_full_gate_report(payload: bytes) -> None:
    try:
        text = payload.decode("utf-8")
    except UnicodeDecodeError as exc:
        raise Blocked("full-validation-gate report invalid") from exc
    if "Result: 16/16 exact commands exited zero." not in text:
        raise Blocked("full-validation-gate report incomplete")
    captured = next((line for line in text.splitlines() if line.startswith("- Captured: `")), "")
    timestamps = [part for part in captured.split("`") if part.endswith("Z")]
    if len(timestamps) != 2 or not all(RetroFixture.valid_utc_timestamp(value) for value in timestamps):
        raise Blocked("full-validation-gate timestamp invalid")
    for ordinal, command in enumerate(FULL_VALIDATION_COMMANDS, 1):
        prefix = f"| {ordinal} | `{command}` | 0 |"
        if not any(line.startswith(prefix) for line in text.splitlines()):
            raise Blocked(f"full-validation-gate command mismatch: {ordinal}")


def render_full_gate_report(rows: list[dict[str, object]], started: str, finished: str) -> bytes:
    lines = [
        "# U5 exact full-validation gate",
        "",
        "- Plan: `docs/plans/2026-08-23-001-fix-run-artifact-integrity-plan.md`, U5 step 4.",
        f"- Captured: `{started}` through `{finished}`.",
        "- Checkout: `feat/run-artifact-integrity`; disposable fixture targets only; no hosted mutation.",
        "",
        "| # | Exact command | Exit | Bounded result |",
        "|---|---|---:|---|",
    ]
    for row in rows:
        summary = str(row["summary"]).replace("\n", " / ").replace("|", "\\|").replace("`", "'")
        lines.append(f"| {row['ordinal']} | `{row['command']}` | {row['exit']} | `{summary}` |")
    lines.extend(("", "Result: 16/16 exact commands exited zero.", ""))
    return "\n".join(lines).encode("utf-8")


def run_full_validation_gate() -> dict[str, str]:
    progress_path = ROOT / os.environ.get("RUN_ARTIFACT_FULL_GATE_PROGRESS_PATH", ".release-loop/progress.md")
    existing = progress_path.parent / FULL_GATE_REPORT
    if existing.exists():
        receipt = full_gate_receipt(ROOT, progress_path)
        validate_full_gate_report(verify_owned_receipt(ROOT, progress_path, receipt, "full-validation-gate"))
        return receipt
    started = datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")
    rows: list[dict[str, object]] = []
    for ordinal, command in enumerate(FULL_VALIDATION_COMMANDS, 1):
        result = subprocess.run(
            shlex.split(command),
            cwd=ROOT,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            check=False,
        )
        bounded = result.stdout.strip()[-500:] or "no output"
        rows.append({"ordinal": ordinal, "command": command, "exit": result.returncode, "summary": bounded})
        if result.returncode != 0:
            raise Blocked(f"full-validation-gate command failed: {ordinal}: {command}")
    finished = datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")
    report = render_full_gate_report(rows, started, finished)
    payload = publish_from_cli(ROOT, progress_path, FULL_GATE_REPORT, report, CLI)
    receipt = {"path": FULL_GATE_REPORT, "sha256": str(payload["sha256"])}
    validate_full_gate_report(verify_owned_receipt(ROOT, progress_path, receipt, "full-validation-gate"))
    return receipt


def record_ae(evidence: dict[str, str], number: int, assertion: bool, observation: str) -> None:
    key = f"AE{number}"
    if key in evidence:
        raise AssertionError(f"duplicate AE evidence: {key}")
    assert assertion, f"{key} failed: {observation}"
    evidence[key] = observation


def history_snapshot(repo: Path, history: HistoryFixture) -> dict[str, object]:
    refs = git(repo, "for-each-ref", "--format=%(refname)=%(objectname)").splitlines()
    return {
        "head": git(repo, "rev-parse", "HEAD"),
        "range": dict(history.current_commit_range),
        "counts": dict(history.review_counts),
        "gate": dict(history.review_gate),
        "refs": refs,
        "status": git(repo, "status", "--porcelain"),
    }


def write_history_evidence(
    name: str,
    repo: Path,
    history: HistoryFixture,
    pre_state: dict[str, object],
    sentinel_path: Path,
    sentinel_before: bytes,
    command: str,
) -> None:
    evidence_dir = os.environ.get("RUN_ARTIFACT_EVIDENCE_DIR")
    if evidence_dir is None:
        return
    label = os.environ.get("RUN_ARTIFACT_EVIDENCE_LABEL", name)
    outcome = os.environ.get("RUN_ARTIFACT_EVIDENCE_OUTCOME", label)
    diagnostics = {
        "unapproved_rewrite": (1, "stale-commit-range", "approval guard rejected before command; command_calls=0", "fresh approval is required"),
        "posthoc_divergence_detected": (1, "stale-commit-range", "non-descendant refresh guard detected the changed HEAD", "authorized recovery is required"),
        "mismatched_approval": (1, "stale-commit-range", "exact-command approval comparison rejected before command", "fresh exact approval is required"),
        "cancelled_approval_rejected": (1, "stale-commit-range", "cancelled approval rejected before retry command", "fresh approval allocated a distinct ID"),
        "fresh_review_after_rewrite": (0, "fresh exact-head standalone review accepted", "old gate rejected, new exact-head gate accepted", "phase gate passes"),
    }
    if history.last_command is None:
        inner_exit, output, mechanism, next_result = diagnostics.get(name, (0, "", "local transition completed", "not applicable"))
        command_record = command
    else:
        inner_exit = int(history.last_command["exit_status"])
        output = (str(history.last_command["stdout"]) + str(history.last_command["stderr"])).strip()[-1000:]
        mechanism = "real git rebase boundary returned the recorded status"
        next_result = "fresh exact-head review required" if inner_exit == 0 else "git rebase --abort restored the old range; fresh approval required"
        command_record = str(history.last_command["command"])
    post_state = history_snapshot(repo, history)
    source_commit = git(ROOT, "rev-parse", "HEAD")
    sentinel_after = sentinel_path.read_bytes()
    content = (
        f"# T3 {outcome}\n\n"
        f"- Approved artifact: `docs/plans/2026-08-23-001-fix-run-artifact-integrity-plan.md`, T3 `authorized-history-rewrite`, outcome `{outcome}`.\n"
        f"- Source commit and timestamp: `{source_commit}`; `{subprocess.run(('date', '-u', '+%Y-%m-%dT%H:%M:%SZ'), check=True, text=True, stdout=subprocess.PIPE).stdout.strip()}`.\n"
        f"- Fixture identity: case `{name}`; disposable root `{repo}`.\n"
        f"- Complete configured target inventory: repository `{repo}`; base `main`; target base `origin/main`; feature `feat/fixture`; pre refs `{json.dumps(pre_state['refs'], separators=(',', ':'))}`; post refs `{json.dumps(post_state['refs'], separators=(',', ':'))}`; remotes `[]`.\n"
        "- Stub identity: not applicable because T3 invokes only local Git and configures no API, process stub, bare remote, or network target.\n"
        f"- Boundary sentinel: `{sentinel_path}`; pre SHA-256 `{hashlib.sha256(sentinel_before).hexdigest()}`; post SHA-256 `{hashlib.sha256(sentinel_after).hexdigest()}`; unchanged `{sentinel_after == sentinel_before}`.\n"
        f"- Pre-state: `{json.dumps(pre_state, sort_keys=True, separators=(',', ':'))}`.\n"
        f"- Exact command or injection: `{command_record}`; case injection `{name}`.\n"
        f"- Numeric inner exit: `{inner_exit}`. Bounded output (last 1000 characters): `{output}`.\n"
        f"- Post-state: `{json.dumps(post_state, sort_keys=True, separators=(',', ':'))}`.\n"
        f"- Relevant next invocation: {next_result}.\n"
        f"- Mechanism check: {mechanism}; external sentinel remained byte-identical.\n"
    )
    target = Path(evidence_dir) / f"{label}.md"
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(content, encoding="utf-8")


def populate_retro_reviews(repo: Path, path: Path) -> ReviewFixture:
    reviews = ReviewFixture(repo, path)
    head = git(repo, "rev-parse", "HEAD")
    first = reviews.allocate("unit", "U1", head)
    reviews.complete(str(first["id"]), reviewer_output("actionable", review_body=("fp-retro",)))
    fix = reviews.allocate("fix", "U1", head, source_review_event=str(first["id"]))
    reviews.complete(str(fix["id"]), reviewer_output("clean"))
    second = reviews.allocate("unit", "U1", head, re_review_of=str(first["id"]))
    reviews.complete(str(second["id"]), reviewer_output("clean"))
    reviews.verify_re_review(str(second["id"]))
    final = reviews.allocate("final", "branch", head)
    reviews.complete(str(final["id"]), reviewer_output("clean"))
    standalone = reviews.allocate("standalone", "branch", head)
    reviews.complete(str(standalone["id"]), reviewer_output("clean"))
    return reviews


def run_retro_case(name: str, tmp: Path, sent: Path, before: bytes) -> None:
    require_retro_contract()
    repo = new_history_repo(tmp)
    path = initialize(repo, "alpha")
    reviews = populate_retro_reviews(repo, path)
    current_range = {
        "base": git(repo, "merge-base", "main", "HEAD"),
        "head": git(repo, "rev-parse", "HEAD"),
    }
    retro = RetroFixture(
        repo,
        path,
        reviews,
        current_range,
        "exact",
        "2026-08-24T00:00:00Z",
        pr_fixed=3,
        pr_deferred=1,
    )

    if name == "retro_structured_metrics":
        retro.publish_facilitator_round(1, b"accepted: exact structured evidence\n")
        expected = retro.render_metrics(1)
        narrative = "- review round one passed\n- fixed one review finding\n"
        path.write_text(path.read_text(encoding="utf-8") + narrative, encoding="utf-8")
        with_narrative = retro.render_metrics(1)
        path.write_text(path.read_text(encoding="utf-8").replace(narrative, ""), encoding="utf-8")
        without_narrative = retro.render_metrics(1)
        assert with_narrative == without_narrative == expected
        assert "| Review rounds (unit / final / standalone) | 4 (2 / 1 / 1) |" in expected
        assert "| Fix rounds | 1 |" in expected
        assert "| Internal findings (fixed / deferred) | 1 / 0 |" in expected
        assert "| Pull request comments (fixed / deferred) | 3 / 1 |" in expected
    elif name == "legacy_partial_metrics":
        retro.completeness = None
        retro.counting_started_at = None
        before_writes = retro.metric_state_writes
        timestamp = retro.adopt_legacy_partial()
        assert retro.metric_state_writes == before_writes + 1
        persisted = path.read_text(encoding="utf-8")
        assert json.dumps(
            {"completeness": "partial", "counting_started_at": timestamp},
            sort_keys=True,
            separators=(",", ":"),
        ) in persisted
        retro.publish_facilitator_round(1, b"accepted: legacy lower bound\n")
        rendered = retro.render_metrics(1)
        assert f"partial — lower bound since {timestamp}" in rendered
        assert "| Review rounds (unit / final / standalone) | 4 (2 / 1 / 1) |" in rendered
    elif name in {
        "legacy_partial_missing_timestamp",
        "legacy_partial_empty_timestamp",
        "legacy_partial_invalid_timestamp",
    }:
        retro.completeness = "partial"
        retro.counting_started_at = {
            "legacy_partial_missing_timestamp": None,
            "legacy_partial_empty_timestamp": "",
            "legacy_partial_invalid_timestamp": "2026-08-24 00:00:00",
        }[name]
        try:
            retro.render_metrics(0)
        except Blocked as exc:
            assert str(exc) == "invalid counting_started_at"
        else:
            raise AssertionError(f"{name} did not block")
    elif name == "retro_stale_range":
        (repo / "later.txt").write_text("later\n", encoding="utf-8")
        git(repo, "add", "later.txt")
        git(repo, "commit", "-qm", "later")
        try:
            retro.render_metrics(0)
        except Blocked as exc:
            assert str(exc) == "stale-commit-range"
        else:
            raise AssertionError("stale Retro range did not block")
    elif name == "facilitator_artifact_missing":
        try:
            retro.render_metrics(1)
        except Blocked as exc:
            assert str(exc) == "facilitator artifact missing"
        else:
            raise AssertionError("missing facilitator artifact supported a metric claim")
    elif name == "facilitator_artifact_changed":
        target = retro.publish_facilitator_round(1, b"accepted: immutable\n")
        target.write_bytes(b"changed\n")
        try:
            retro.render_metrics(1)
        except Blocked as exc:
            assert str(exc) == "facilitator artifact changed"
        else:
            raise AssertionError("changed facilitator artifact supported a metric claim")
    elif name == "facilitator_receipt_conflict":
        retro.publish_facilitator_round(1, b"accepted: receipt\n")
        retro.facilitator_receipts[1]["sha256"] = "0" * 64
        try:
            retro.render_metrics(1)
        except Blocked as exc:
            assert str(exc) == "facilitator receipt conflict"
        else:
            raise AssertionError("conflicting facilitator receipt supported a metric claim")
    elif name == "facilitator_journal_conflict":
        retro.publish_facilitator_round(1, b"accepted: journal\n")
        journal = path.parent / ".phase-artifact-ownership.json"
        state = json.loads(journal.read_text(encoding="utf-8"))
        state["owned"].pop("reviews/facilitator/round-1.md")
        journal.write_text(json.dumps(state, sort_keys=True, separators=(",", ":")) + "\n", encoding="utf-8")
        try:
            retro.render_metrics(1)
        except Blocked as exc:
            assert str(exc) == "facilitator journal conflict"
        else:
            raise AssertionError("conflicting facilitator journal supported a metric claim")
    elif name == "facilitator_artifact_unpublished":
        retro.facilitator_receipts[1] = {
            "path": "reviews/facilitator/round-1.md",
            "sha256": hashlib.sha256(b"never published\n").hexdigest(),
        }
        journal = path.parent / ".phase-artifact-ownership.json"
        state = json.loads(journal.read_text(encoding="utf-8"))
        state["owned"]["reviews/facilitator/round-1.md"] = retro.facilitator_receipts[1]["sha256"]
        journal.write_text(json.dumps(state, sort_keys=True, separators=(",", ":")) + "\n", encoding="utf-8")
        try:
            retro.render_metrics(1)
        except Blocked as exc:
            assert str(exc) == "facilitator artifact unpublished"
        else:
            raise AssertionError("unpublished facilitator artifact supported a metric claim")
    elif name == "unknown_count_completeness":
        retro.completeness = "estimated"
        try:
            retro.render_metrics(0)
        except Blocked as exc:
            assert str(exc) == "unknown review count completeness: estimated"
        else:
            raise AssertionError("unknown completeness did not block")
    elif name == "full_lifecycle":
        ae_evidence: dict[str, str] = {}
        for relative in ("briefs/U1-brief.md", "reports/U1-report.md", "evidence/U1/T6-success.md"):
            publish_phase_artifact(repo, path, relative, (relative + "\n").encode())
        scoped_artifacts = all((path.parent / relative).is_file() for relative in ("briefs/U1-brief.md", "reports/U1-report.md", "evidence/U1/T6-success.md"))
        scoped_artifacts = scoped_artifacts and (path.parent / "reviews/events/unit-U1-1.md").is_file()
        scoped_artifacts = scoped_artifacts and not any((repo / f".release-loop/{name}").exists() for name in ("briefs", "reports", "reviews", "evidence"))
        record_ae(ae_evidence, 1, scoped_artifacts, "all applicable artifacts stayed in the selected scope")

        legacy_repo = new_repo(tmp, "legacy-proof")
        legacy = legacy_repo / ".release-loop/reports/U1-report.md"
        legacy.parent.mkdir(parents=True)
        legacy.write_bytes(b"legacy\n")
        git(legacy_repo, "add", "-f", legacy.relative_to(legacy_repo).as_posix())
        git(legacy_repo, "commit", "-qm", "legacy")
        blob = legacy.read_bytes()
        scoped = initialize(legacy_repo, "proof")
        publish_phase_artifact(legacy_repo, scoped, "reports/U1-report.md", b"scoped\n")
        legacy_preserved = legacy.read_bytes() == blob and git(legacy_repo, "status", "--porcelain", "--", legacy.relative_to(legacy_repo).as_posix()) == ""
        record_ae(ae_evidence, 2, legacy_preserved, "tracked legacy index/worktree bytes and status stayed unchanged")

        collision_repo = new_repo(tmp, "collision-proof")
        orphan = collision_repo / ".release-loop/runs/collision/orphan.txt"
        orphan.parent.mkdir(parents=True)
        orphan.write_text("orphan\n", encoding="utf-8")
        assert_blocked_preserves(lambda: initialize(collision_repo, "collision"), sent, before, "artifact scope collision")
        tracked_repo = new_repo(tmp, "tracked-collision-proof")
        tracked = tracked_repo / ".release-loop/runs/tracked/report.md"
        tracked.parent.mkdir(parents=True)
        tracked.write_text("tracked\n", encoding="utf-8")
        git(tracked_repo, "add", "-f", tracked.relative_to(tracked_repo).as_posix())
        git(tracked_repo, "commit", "-qm", "tracked collision")
        assert_blocked_preserves(lambda: initialize(tracked_repo, "tracked"), sent, before, "artifact scope collision")
        record_ae(ae_evidence, 3, orphan.is_file() and tracked.is_file(), "ignored orphan and tracked selected-scope collisions both blocked before write")

        exact_counts = reviews.counts() == {
            "unit_passes": 2,
            "fix_rounds": 1,
            "final_passes": 1,
            "standalone_passes": 1,
            "findings_fixed": 1,
            "findings_deferred": 0,
        }
        record_ae(ae_evidence, 4, exact_counts, "actionable, fix, clean re-review, final, and standalone counters matched")
        recovered = reviews.allocate("unit", "U2", git(repo, "rev-parse", "HEAD"))
        wrapper = reviews._wrapper(recovered, reviewer_output("clean"))
        publish_from_cli(repo, path, reviews._result_relative(recovered), wrapper, IMPLEMENTING_CLI)
        recovered_once = reviews.recover(str(recovered["id"])) == "recovered"
        corrupt_event = reviews.event("final:branch:1")
        corrupt_path = reviews._result_path(corrupt_event)
        original_result = corrupt_path.read_bytes()
        corrupt_path.write_bytes(b"corrupt\n")
        corruption_blocked = False
        try:
            reviews.verify_result(str(corrupt_event["id"]))
        except Blocked as exc:
            corruption_blocked = "digest mismatch" in str(exc)
        corrupt_path.write_bytes(original_result)
        collision_event = reviews.allocate("unit", "U3", git(repo, "rev-parse", "HEAD"))
        collision_body = reviewer_output("clean", tail=b"first\n")
        publish_from_cli(repo, path, reviews._result_relative(collision_event), reviews._wrapper(collision_event, collision_body), IMPLEMENTING_CLI)
        collision_blocked = False
        try:
            reviews.complete(str(collision_event["id"]), reviewer_output("clean", tail=b"different\n"))
        except Blocked as exc:
            collision_blocked = "review-event-conflict" in str(exc)
        record_ae(ae_evidence, 5, recovered_once and corruption_blocked and collision_blocked, "matching recovery succeeded; corruption and conflicting immutable results blocked")
        record_ae(ae_evidence, 6, reviews.dispositions["fp-retro"]["status"] == "fixed", "only the verifying re-review fixed the source fingerprint")
        record_ae(ae_evidence, 7, reviews.counts()["standalone_passes"] == 1, "standalone dispatch counted once while reuse added no event")

        rewrite_repo = new_history_repo(tmp, conflict=False, name="rewrite-proof")
        rewrite_path = initialize(rewrite_repo, "rewrite")
        history = HistoryFixture(rewrite_repo, rewrite_path, "main", "fixture-session")
        command = 'git rebase --onto "origin/main" "main" "feat/fixture"'
        try:
            history.rewrite(command, "origin/main")
        except Blocked as exc:
            assert str(exc) == "stale-commit-range" and history.command_calls == 0
        else:
            raise AssertionError("unapproved full-lifecycle rewrite executed")
        record_ae(ae_evidence, 9, history.command_calls == 0, "unapproved non-descendant rewrite blocked before command execution")
        old_gate = dict(history.review_gate)
        history.approve(command, "origin/main")
        history.rewrite(command, "origin/main")
        record_ae(ae_evidence, 8, history.current_commit_range == history.git_range(), "approved rewrite refreshed both full object IDs without changing prior counts")
        gate_invalidated = old_gate["head"] != history.current_commit_range["head"] and history.review_gate == {"event_id": None, "head": None}
        record_ae(ae_evidence, 10, gate_invalidated, "rewritten head cleared the exact-head review gate")

        retro.publish_facilitator_round(1, b"accepted: full lifecycle\n")
        rendered = retro.render_metrics(1)
        record_ae(ae_evidence, 11, "| Count completeness | exact |" in rendered, "Retro rendered exact structured totals after receipt verification")
        source = path.parent / ".tmp/outside.tmp"
        source.parent.mkdir(parents=True, exist_ok=True)
        source.write_bytes(b"outside\n")
        assert_blocked_preserves(
            lambda: run_cli(
                "publish", "--repo", str(repo),
                "--progress-path", path.relative_to(repo).as_posix(),
                "--source", source.relative_to(repo).as_posix(),
                "--target", str(sent),
            ),
            sent,
            before,
            "path boundary",
        )
        legacy_boundary_repo = new_repo(tmp, "legacy-boundary")
        legacy_progress = legacy_boundary_repo / ".release-loop/progress.md"
        legacy_progress.parent.mkdir()
        legacy_progress.write_text(progress("legacy", ".release-loop"), encoding="utf-8")
        legacy_source = legacy_progress.parent / ".tmp/outside.tmp"
        legacy_source.parent.mkdir()
        legacy_source.write_bytes(b"outside\n")
        assert_blocked_preserves(
            lambda: run_cli("publish", "--repo", str(legacy_boundary_repo), "--progress-path", ".release-loop/progress.md", "--source", ".release-loop/.tmp/outside.tmp", "--target", str(sent)),
            sent,
            before,
            "path boundary",
        )
        archive_boundary_repo = new_repo(tmp, "archive-boundary")
        archive_progress = initialize(archive_boundary_repo, "archive")
        assert_blocked_preserves(
            lambda: archive_scope(archive_boundary_repo, archive_progress.relative_to(archive_boundary_repo).as_posix(), str(sent), persist_authority=False),
            sent,
            before,
            "path boundary",
        )
        handoff_boundary_repo = new_repo(tmp, "handoff-boundary")
        handoff_progress = initialize(handoff_boundary_repo, "handoff")
        handoff_base = new_repo(tmp, "handoff-boundary-base")
        assert_blocked_preserves(
            lambda: handoff_scope(handoff_boundary_repo, handoff_base, handoff_progress.relative_to(handoff_boundary_repo).as_posix(), marker_path=str(sent)),
            sent,
            before,
            "path boundary",
        )
        record_ae(ae_evidence, 12, sent.read_bytes() == before, "scoped, legacy, archive, and handoff outside-root attacks preserved the sentinel")

        root_progress = ROOT / ".release-loop/progress.md"
        root_receipt = full_gate_receipt(ROOT, root_progress)
        root_report = verify_owned_receipt(ROOT, root_progress, root_receipt, "full-validation-gate")
        validate_full_gate_report(root_report)
        fixture_payload = publish_from_cli(repo, path, FULL_GATE_REPORT, root_report, CLI)
        fixture_receipt = {"path": FULL_GATE_REPORT, "sha256": str(fixture_payload["sha256"])}
        validate_full_gate_report(verify_owned_receipt(repo, path, fixture_receipt, "full-validation-gate"))
        record_ae(ae_evidence, 13, fixture_receipt["sha256"] == root_receipt["sha256"], "immutable packaged full-gate receipt proves all sixteen exact commands exited zero")

        publish_phase_artifact(repo, path, "reports/retro.md", rendered.encode())
        base = new_repo(tmp, "base")
        handoff_scope(repo, base, path.relative_to(repo).as_posix())
        base_progress = base / path.relative_to(repo)
        destination = ".release-loop/archive/2026-08-24-alpha"
        archive_scope(base, base_progress.relative_to(base).as_posix(), destination)
        archived = base / destination
        assert (archived / "progress.md").is_file()
        assert (archived / "reviews/facilitator/round-1.md").read_bytes() == b"accepted: full lifecycle\n"
        assert set(ae_evidence) == {f"AE{number}" for number in range(1, 14)}, ae_evidence
    else:
        raise AssertionError(f"unknown Retro case: {name}")
    assert sent.read_bytes() == before


def run_case(name: str) -> None:
    require_contract(check_invocations=name == "operative_contract_mutation")
    with tempfile.TemporaryDirectory(prefix=f"run-artifact-{name}-") as tmp_name:
        tmp = Path(tmp_name)
        sent, before = sentinel(tmp)
        if name in RETRO_CASES + LIFECYCLE_CASES:
            run_retro_case(name, tmp, sent, before)
            return
        if name in HISTORY_CASES:
            require_history_contract()
            conflict = name == "rewrite_conflict"
            repo = new_history_repo(tmp, conflict=conflict)
            path = initialize(repo, "alpha")
            history = HistoryFixture(repo, path, "main", "fixture-session")
            matrix_pre_state = matrix_fixture_snapshot(repo)
            command = 'git rebase --onto "origin/main" "main" "feat/fixture"'
            counts_before = dict(history.review_counts)
            old_range = dict(history.current_commit_range)
            pre_observation = history_snapshot(repo, history)

            if name == "authorized_rewrite_refresh":
                approval = history.approve(command, "origin/main")
                approval_write = history.persisted_writes
                result = history.rewrite(command, "origin/main")
                assert approval_write < history.persisted_writes
                assert approval["state"] == "consumed" and result["state"] == "success"
                assert result["exit_status"] == 0
                assert history.current_commit_range == history.git_range()
                assert history.current_commit_range != old_range
                assert history.review_counts == counts_before
                assert history.review_gate == {"event_id": None, "head": None}
            elif name == "descendant_head_invalidates":
                (repo / "descendant.txt").write_text("descendant\n", encoding="utf-8")
                git(repo, "add", "descendant.txt")
                git(repo, "commit", "-qm", "descendant")
                history.refresh()
                assert history.current_commit_range == history.git_range()
                assert history.current_commit_range["base"] == old_range["base"]
                assert history.review_gate == {"event_id": None, "head": None}
            elif name == "unapproved_rewrite":
                head_before = git(repo, "rev-parse", "HEAD").encode()
                range_before = json.dumps(history.current_commit_range, sort_keys=True, separators=(",", ":")).encode()
                counts_bytes_before = json.dumps(history.review_counts, sort_keys=True, separators=(",", ":")).encode()
                gate_before = json.dumps(history.review_gate, sort_keys=True, separators=(",", ":")).encode()
                try:
                    history.rewrite(command, "origin/main")
                except Blocked as exc:
                    assert str(exc) == "stale-commit-range"
                else:
                    raise AssertionError("missing approval did not block before rewrite")
                assert history.command_calls == 0
                assert git(repo, "rev-parse", "HEAD").encode() == head_before
                assert json.dumps(history.current_commit_range, sort_keys=True, separators=(",", ":")).encode() == range_before
                assert json.dumps(history.review_counts, sort_keys=True, separators=(",", ":")).encode() == counts_bytes_before
                assert json.dumps(history.review_gate, sort_keys=True, separators=(",", ":")).encode() == gate_before
            elif name == "posthoc_divergence_detected":
                history.run_fixture_rewrite(command)
                try:
                    history.refresh()
                except Blocked as exc:
                    assert str(exc) == "stale-commit-range"
                else:
                    raise AssertionError("unapproved non-descendant rewrite did not block")
                assert history.current_commit_range == old_range
                assert history.review_counts == counts_before
            elif name == "mismatched_approval":
                history.approve(command + " --empty=drop", "origin/main")
                head_before = git(repo, "rev-parse", "HEAD")
                try:
                    history.rewrite(command, "origin/main")
                except Blocked as exc:
                    assert str(exc) == "stale-commit-range"
                else:
                    raise AssertionError("mismatched rewrite approval did not block")
                assert git(repo, "rev-parse", "HEAD") == head_before
                assert history.current_commit_range == old_range
            elif name == "rewrite_conflict":
                history.approve(command, "origin/main")
                result = history.rewrite(command, "origin/main")
                assert result["state"] == "failed" and int(result["exit_status"]) != 0
                assert git(repo, "status", "--porcelain") == ""
                assert history.current_commit_range == old_range == history.git_range()
                assert history.review_gate == {"event_id": None, "head": None}
            elif name == "cancelled_approval_rejected":
                approval = history.approve(command, "origin/main")
                cancelled = history.cancel(str(approval["id"]))
                assert cancelled["state"] == "cancelled" and approval["state"] == "cancelled"
                head_before = git(repo, "rev-parse", "HEAD")
                try:
                    history.rewrite(command, "origin/main")
                except Blocked as exc:
                    assert str(exc) == "stale-commit-range"
                else:
                    raise AssertionError("cancelled approval authorized retry")
                assert git(repo, "rev-parse", "HEAD") == head_before
                assert history.current_commit_range == old_range
                fresh = history.approve(command, "origin/main")
                assert fresh["id"] != approval["id"]
            elif name == "fresh_review_after_rewrite":
                assert history.phase_gate("final:branch:1")
                history.approve(command, "origin/main")
                history.rewrite(command, "origin/main")
                try:
                    history.phase_gate("final:branch:1")
                except Blocked as exc:
                    assert str(exc) == "review gate head mismatch"
                else:
                    raise AssertionError("old-head review gate survived rewrite")
                event = history.complete_review("standalone:branch:1", git(repo, "rev-parse", "HEAD"))
                assert history.phase_gate(str(event["id"]))
            elif name in {"shipping_command_invariance", "shipping_command_changed_axis"}:
                baseline = git_show(ROOT, "5f3036b767a5e951aa0ab711832daa24c64915d1", "skills/shipping/SKILL.md")
                observed = PHASE_CONSUMERS["shipping"]
                if name == "shipping_command_changed_axis":
                    observed = observed.replace(
                        "gh pr merge <number> --squash --delete-branch [--auto]",
                        "gh pr merge <number> --merge --delete-branch [--auto]",
                        1,
                    )
                baseline_commands = shipping_command_blocks(baseline)
                observed_commands = shipping_command_blocks(observed)
                if name == "shipping_command_invariance":
                    assert observed_commands == baseline_commands
                else:
                    assert observed_commands != baseline_commands
                    assert observed_commands["cleanup"] == baseline_commands["cleanup"]
            assert sent.read_bytes() == before
            write_history_evidence(name, repo, history, pre_observation, sent, before, command)
            write_matrix_observation(name, repo, matrix_pre_state, sent, before)
            return
        repo = new_repo(tmp)
        matrix_pre_state = matrix_fixture_snapshot(repo)

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
        elif name == "legacy_publish_then_archive":
            legacy = repo / ".release-loop/progress.md"
            legacy.parent.mkdir()
            legacy.write_text(progress("legacy", ".release-loop"), encoding="utf-8")
            payload = publish_from_cli(repo, legacy, "reports/U1.md", b"owned\n", CLI)
            assert payload["state"] == "published"
            journal = legacy.parent / ".phase-artifact-ownership.json"
            temporary = legacy.parent / ".tmp"
            assert journal.is_file() and temporary.is_dir()
            destination = ".release-loop/archive/2026-08-23-legacy-owned"
            order = archive_scope(repo, str(legacy.relative_to(repo)), destination)
            archived = repo / destination
            assert order[-1] == "progress.md"
            assert (archived / ".phase-artifact-ownership.json").is_file()
            assert (archived / ".tmp").is_dir()
            assert not journal.exists() and not temporary.exists()
            assert not any(
                child.name in {".phase-artifact-ownership.json", ".phase-artifact-ownership.json.tmp", ".tmp"}
                for child in (repo / ".release-loop").iterdir()
            )
        elif name == "archive_pending_publication":
            legacy = repo / ".release-loop/progress.md"
            legacy.parent.mkdir()
            legacy.write_text(progress("legacy", ".release-loop"), encoding="utf-8")
            source = legacy.parent / ".tmp/reports-U1.md.tmp"
            try:
                publish_from_cli(
                    repo,
                    legacy,
                    "reports/U1.md",
                    b"pending\n",
                    CLI,
                    "publish-after-prepare",
                )
            except Blocked as exc:
                assert "injected publish interruption" in str(exc), str(exc)
            else:
                raise AssertionError("publisher did not leave a pending transaction")
            destination = ".release-loop/archive/2026-08-23-legacy-pending"
            persist_archive_evidence(legacy, destination, "completed")
            before_progress = legacy.read_bytes()
            assert_blocked_preserves(
                lambda: archive_scope(
                    repo,
                    str(legacy.relative_to(repo)),
                    destination,
                    persist_authority=False,
                ),
                sent,
                before,
                "pending publication",
            )
            assert legacy.read_bytes() == before_progress
            assert source.is_file()
            assert not (repo / destination).exists()
        elif name == "interrupted_legacy_published_archive":
            legacy = repo / ".release-loop/progress.md"
            legacy.parent.mkdir()
            legacy.write_text(progress("legacy", ".release-loop"), encoding="utf-8")
            publish_from_cli(repo, legacy, "reports/U1.md", b"owned\n", CLI)
            destination = ".release-loop/archive/2026-08-23-legacy-published-interrupted"
            persist_archive_evidence(legacy, destination, "completed")
            try:
                archive_scope(
                    repo,
                    str(legacy.relative_to(repo)),
                    destination,
                    fail_after_first=True,
                    persist_authority=False,
                )
            except Blocked as exc:
                assert "injected archive interruption" in str(exc)
            else:
                raise AssertionError("published legacy archive did not interrupt")
            assert not (legacy.parent / ".tmp").exists()
            assert archive_scope(repo, str(legacy.relative_to(repo)), None)[-1] == "progress.md"
            archived = repo / destination
            assert (archived / ".phase-artifact-ownership.json").is_file()
            assert (archived / "reports/U1.md").is_file()
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
        elif name == "archive_incomplete_run":
            path = initialize(repo, "alpha")
            destination = ".release-loop/archive/2026-08-23-alpha-incomplete"
            archive_scope(
                repo,
                str(path.relative_to(repo)),
                destination,
                mode="incomplete",
            )
            archived = repo / destination / "progress.md"
            text = archived.read_text(encoding="utf-8")
            assert "phase: implement\n" in text
            assert "phase_status: in-progress\n" in text
            assert f"archived-incomplete: archive-destination: {destination}" in text
        elif name in {
            "archive_incomplete_missing_phase",
            "archive_incomplete_missing_phase_status",
            "archive_incomplete_unknown_phase",
            "archive_incomplete_unknown_phase_status",
        }:
            path = initialize(repo, "alpha")
            destination = ".release-loop/archive/2026-08-23-alpha-incomplete"
            text = path.read_text(encoding="utf-8")
            if name == "archive_incomplete_missing_phase":
                text = text.replace("phase: implement\n", "", 1)
                diagnostic = "invalid incomplete phase: missing"
            elif name == "archive_incomplete_missing_phase_status":
                text = text.replace("phase_status: in-progress\n", "", 1)
                diagnostic = "invalid incomplete phase_status: missing"
            elif name == "archive_incomplete_unknown_phase":
                text = text.replace("phase: implement\n", "phase: unknown\n", 1)
                diagnostic = "invalid incomplete phase: unknown"
            else:
                text = text.replace("phase_status: in-progress\n", "phase_status: unknown\n", 1)
                diagnostic = "invalid incomplete phase_status: unknown"
            path.write_text(
                text + f"- 2026-08-23T00:00:01Z archived-incomplete: archive-destination: {destination}\n",
                encoding="utf-8",
            )
            source_before = path.read_bytes()
            assert_blocked_preserves(
                lambda: archive_scope(
                    repo,
                    str(path.relative_to(repo)),
                    destination,
                    persist_authority=False,
                    mode="incomplete",
                ),
                sent,
                before,
                diagnostic,
            )
            assert path.read_bytes() == source_before
            assert not (repo / destination).exists()
        elif name == "archive_evidence_mutants":
            destination = ".release-loop/archive/2026-08-23-alpha"
            completed_nonterminal = new_repo(tmp, "completed-nonterminal")
            completed_path = initialize(completed_nonterminal, "alpha")
            completed_path.write_text(
                completed_path.read_text(encoding="utf-8")
                + f"- 2026-08-23T00:00:01Z retro: archive-destination: {destination}\n",
                encoding="utf-8",
            )
            assert_blocked_preserves(
                lambda: archive_scope(
                    completed_nonterminal,
                    str(completed_path.relative_to(completed_nonterminal)),
                    destination,
                    persist_authority=False,
                ),
                sent,
                before,
                "missing persisted phase evidence",
            )

            incomplete_terminal = new_repo(tmp, "incomplete-terminal")
            incomplete_path = initialize(incomplete_terminal, "alpha")
            text = incomplete_path.read_text(encoding="utf-8")
            text = text.replace("phase: implement\n", "phase: done\n", 1)
            text = text.replace("phase_status: in-progress\n", "phase_status: complete\n", 1)
            incomplete_path.write_text(
                text + f"- 2026-08-23T00:00:01Z archived-incomplete: archive-destination: {destination}\n",
                encoding="utf-8",
            )
            assert_blocked_preserves(
                lambda: archive_scope(
                    incomplete_terminal,
                    str(incomplete_path.relative_to(incomplete_terminal)),
                    destination,
                    persist_authority=False,
                    mode="incomplete",
                ),
                sent,
                before,
                "incomplete marker requires nonterminal phase",
            )

            duplicate = new_repo(tmp, "duplicate-marker")
            duplicate_path = initialize(duplicate, "alpha")
            persist_archive_evidence(duplicate_path, destination, "completed")
            duplicate_path.write_text(
                duplicate_path.read_text(encoding="utf-8")
                + f"- 2026-08-23T00:00:02Z archived-incomplete: archive-destination: {destination}\n",
                encoding="utf-8",
            )
            assert_blocked_preserves(
                lambda: archive_scope(
                    duplicate,
                    str(duplicate_path.relative_to(duplicate)),
                    destination,
                    persist_authority=False,
                ),
                sent,
                before,
                "multiple persisted archive markers",
            )

            mismatch = new_repo(tmp, "marker-mismatch")
            mismatch_path = initialize(mismatch, "alpha")
            persist_archive_evidence(mismatch_path, destination, "completed")
            assert_blocked_preserves(
                lambda: archive_scope(
                    mismatch,
                    str(mismatch_path.relative_to(mismatch)),
                    ".release-loop/archive/different",
                    persist_authority=False,
                ),
                sent,
                before,
                "stored=",
            )
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
        elif name == "scoped_feature_mismatch":
            path = repo / ".release-loop/runs/alpha/progress.md"
            path.parent.mkdir(parents=True)
            path.write_text(progress("beta", ".release-loop/runs/alpha"), encoding="utf-8")
            before_progress = path.read_bytes()
            assert_blocked_preserves(lambda: discover(repo), sent, before, "feature does not match scope alpha")
            assert_blocked_preserves(
                lambda: discover(repo, str(path.relative_to(repo))),
                sent,
                before,
                "feature does not match scope alpha",
            )
            assert_blocked_preserves(
                lambda: archive_scope(
                    repo,
                    str(path.relative_to(repo)),
                    ".release-loop/archive/2026-08-23-alpha",
                    persist_authority=False,
                ),
                sent,
                before,
                "feature does not match scope alpha",
            )
            assert path.read_bytes() == before_progress
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
        elif name == "handoff_same_checkout":
            path = initialize(repo, "alpha")
            source_before = path.read_bytes()
            marker = repo / ".release-loop/.handoff/alpha.json"
            assert_blocked_preserves(
                lambda: handoff_scope(repo, repo, str(path.relative_to(repo))),
                sent,
                before,
                "source and base resolve to same checkout",
            )
            assert path.read_bytes() == source_before
            assert not marker.exists()
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
                mutations = [""]
                changed = invocation.replace("run-artifact-integrity.py", "changed-run-artifact.py")
                if changed != invocation:
                    mutations.append(changed)
                for mutation in mutations:
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
        elif name == "all_consumers_one_root":
            require_phase_consumer_contract()
            path = initialize(repo, "alpha")
            targets = (
                "briefs/U1-brief.md",
                "reports/U1-report.md",
                "reviews/U1-diff.txt",
                "evidence/U1/T6-success.md",
            )
            for relative in targets:
                published = publish_phase_artifact(repo, path, relative, relative.encode("utf-8") + b"\n")
                assert published.parent == path.parent / Path(relative).parent
            assert not (repo / ".release-loop/briefs").exists()
            assert not (repo / ".release-loop/reports").exists()
            assert not (repo / ".release-loop/reviews").exists()
            assert not (repo / ".release-loop/evidence").exists()
        elif name == "stateless_no_evidence":
            require_phase_consumer_contract()
            path = initialize(repo, "alpha")
            publish_phase_artifact(repo, path, "briefs/U1-brief.md", b"stateless\n")
            assert not (path.parent / "evidence").exists()
            assert not (repo / ".release-loop/evidence").exists()
        elif name == "legacy_resume_guarded":
            require_phase_consumer_contract()
            path = repo / ".release-loop/progress.md"
            path.parent.mkdir()
            path.write_text(progress("legacy", ".release-loop"), encoding="utf-8")
            path.write_text(path.read_text(encoding="utf-8") + "- legacy update\n", encoding="utf-8")
            report = publish_phase_artifact(repo, path, "reports/U1-report.md", b"owned\n")
            assert report == repo / ".release-loop/reports/U1-report.md"
            assert publish_phase_artifact(repo, path, "reports/U1-report.md", b"owned\n") == report
            assert_blocked_preserves(
                lambda: publish_phase_artifact(repo, path, "reports/U1-report.md", b"different\n"),
                sent,
                before,
                "artifact ownership",
            )
        elif name == "tracked_legacy_preserved":
            require_phase_consumer_contract()
            legacy = repo / ".release-loop/reports/U1-report.md"
            legacy.parent.mkdir(parents=True)
            legacy.write_bytes(b"tracked legacy\n")
            git(repo, "add", "-f", str(legacy.relative_to(repo)))
            git(repo, "commit", "-qm", "tracked legacy")
            head = git(repo, "rev-parse", "HEAD")
            index = git(repo, "write-tree")
            blob = legacy.read_bytes()
            status = git(repo, "status", "--porcelain", "--", str(legacy.relative_to(repo)))
            path = initialize(repo, "alpha")
            publish_phase_artifact(repo, path, "reports/U1-report.md", b"scoped\n")
            assert git(repo, "rev-parse", "HEAD") == head
            assert git(repo, "write-tree") == index
            assert legacy.read_bytes() == blob
            assert git(repo, "status", "--porcelain", "--", str(legacy.relative_to(repo))) == status
        elif name == "legacy_tracked_self_ledger_only":
            path = repo / ".release-loop/progress.md"
            path.parent.mkdir()
            path.write_text(progress("legacy", ".release-loop"), encoding="utf-8")
            git(repo, "add", "-f", str(path.relative_to(repo)))
            git(repo, "commit", "-qm", "tracked legacy ledger")
            path.write_text(path.read_text(encoding="utf-8") + "- allowed self update\n", encoding="utf-8")
            assert "allowed self update" in path.read_text(encoding="utf-8")
            sibling = path.parent / "reports/U1-report.md"
            sibling.parent.mkdir()
            sibling.write_bytes(b"tracked sibling\n")
            git(repo, "add", "-f", str(sibling.relative_to(repo)))
            assert_blocked_preserves(
                lambda: publish_phase_artifact(repo, path, "reports/U1-report.md", b"new\n"),
                sent,
                before,
                "artifact target collision",
            )
        elif name == "tracked_selected_target":
            require_phase_consumer_contract()
            path = initialize(repo, "alpha")
            target = path.parent / "reports/U1-report.md"
            target.parent.mkdir()
            target.write_bytes(b"tracked selected\n")
            git(repo, "add", "-f", str(target.relative_to(repo)))
            git(repo, "commit", "-qm", "tracked selected")
            head = git(repo, "rev-parse", "HEAD")
            index = git(repo, "write-tree")
            blob = target.read_bytes()
            assert_blocked_preserves(
                lambda: publish_phase_artifact(repo, path, "reports/U1-report.md", b"overwrite\n"),
                sent,
                before,
                "artifact target collision",
            )
            assert git(repo, "rev-parse", "HEAD") == head
            assert git(repo, "write-tree") == index
            assert target.read_bytes() == blob
            temporary = path.parent / ".tmp/reports-U1-report.md.tmp"
            assert temporary.read_bytes() == b"overwrite\n"
            temporary.unlink()
            assert not temporary.exists()
        elif name == "index_only_sibling":
            path = initialize(repo, "alpha")
            target = path.parent / "reports/U1-report.md"
            target.parent.mkdir()
            target.write_bytes(b"index only\n")
            git(repo, "add", "-f", str(target.relative_to(repo)))
            target.unlink()
            assert_blocked_preserves(
                lambda: publish_phase_artifact(repo, path, "reports/U1-report.md", b"new\n"),
                sent,
                before,
                "artifact target collision",
            )
            assert not target.exists()
        elif name in {"symlink_sibling_parent", "dangling_sibling_parent"}:
            path = initialize(repo, "alpha")
            parent = path.parent / "reports"
            if name == "symlink_sibling_parent":
                outside = tmp / "outside-reports"
                outside.mkdir()
                parent.symlink_to(outside, target_is_directory=True)
            else:
                parent.symlink_to(tmp / "missing-reports", target_is_directory=True)
            assert_blocked_preserves(
                lambda: publish_phase_artifact(repo, path, "reports/U1-report.md", b"new\n"),
                sent,
                before,
                "path boundary",
            )
        elif name == "foreign_same_byte":
            path = initialize(repo, "alpha")
            target = path.parent / "reports/U1-report.md"
            target.parent.mkdir()
            target.write_bytes(b"same\n")
            assert_blocked_preserves(
                lambda: publish_phase_artifact(repo, path, "reports/U1-report.md", b"same\n"),
                sent,
                before,
                "artifact ownership",
            )
        elif name == "missing_progress_publish":
            missing = repo / ".release-loop/runs/alpha/progress.md"
            missing.parent.mkdir(parents=True)
            assert_blocked_preserves(
                lambda: publish_phase_artifact(repo, missing, "reports/U1-report.md", b"new\n"),
                sent,
                before,
                "invalid progress",
            )
        elif name == "ambiguous_progress_publish":
            first = initialize(repo, "alpha")
            initialize(repo, "beta")
            assert_blocked_preserves(
                lambda: run_cli("publish", "--repo", str(repo), "--source", str(first), "--target", "reports/U1.md"),
                sent,
                before,
                "progress-path",
            )
        elif name == "mismatched_progress_publish":
            path = initialize(repo, "alpha")
            path.write_text(path.read_text(encoding="utf-8").replace("artifact_root: .release-loop/runs/alpha", "artifact_root: .release-loop/runs/beta"), encoding="utf-8")
            assert_blocked_preserves(
                lambda: publish_phase_artifact(repo, path, "reports/U1-report.md", b"new\n"),
                sent,
                before,
                "artifact_root",
            )
        elif name == "publish_cancellation":
            path = initialize(repo, "alpha")
            target = path.parent / "reports/U1-report.md"
            assert_blocked_preserves(
                lambda: publish_phase_artifact(
                    repo,
                    path,
                    "reports/U1-report.md",
                    b"cancelled\n",
                    failure="publish-after-prepare",
                ),
                sent,
                before,
                "injected publish interruption",
            )
            temporary = path.parent / ".tmp/reports-U1-report.md.tmp"
            assert temporary.read_bytes() == b"cancelled\n"
            assert not target.exists()
            journal = path.parent / ".phase-artifact-ownership.json"
            assert json.loads(journal.read_text(encoding="utf-8"))["pending"] is not None
            compensated = run_cli(
                "compensate",
                "--repo", str(repo),
                "--progress-path", path.relative_to(repo).as_posix(),
            )
            assert compensated["state"] == "compensated"
            assert not temporary.exists() and json.loads(journal.read_text(encoding="utf-8"))["pending"] is None
        elif name == "publish_target_escape":
            path = initialize(repo, "alpha")
            for target in (str(sent), ".release-loop/runs/alpha/../escaped.md"):
                source = path.parent / ".tmp/escape.tmp"
                source.parent.mkdir(parents=True, exist_ok=True)
                source.write_bytes(b"escape\n")
                assert_blocked_preserves(
                    lambda target=target, source=source: run_cli(
                        "publish",
                        "--repo", str(repo),
                        "--progress-path", path.relative_to(repo).as_posix(),
                        "--source", source.relative_to(repo).as_posix(),
                        "--target", target,
                    ),
                    sent,
                    before,
                    "path boundary",
                )
        elif name == "invalid_publish_source":
            path = initialize(repo, "alpha")
            root = path.parent
            outside_tmp = root / "source.md"
            outside_tmp.write_bytes(b"source\n")
            assert_blocked_preserves(
                lambda: run_cli(
                    "publish", "--repo", str(repo),
                    "--progress-path", path.relative_to(repo).as_posix(),
                    "--source", outside_tmp.relative_to(repo).as_posix(),
                    "--target", (root / "reports/U1.md").relative_to(repo).as_posix(),
                ),
                sent,
                before,
                "artifact",
            )
            tracked_source = root / ".tmp/tracked.tmp"
            tracked_source.parent.mkdir()
            tracked_source.write_bytes(b"tracked\n")
            git(repo, "add", "-f", str(tracked_source.relative_to(repo)))
            assert_blocked_preserves(
                lambda: run_cli(
                    "publish", "--repo", str(repo),
                    "--progress-path", path.relative_to(repo).as_posix(),
                    "--source", tracked_source.relative_to(repo).as_posix(),
                    "--target", (root / "reports/U1.md").relative_to(repo).as_posix(),
                ),
                sent,
                before,
                "artifact",
            )
            final_in_tmp = root / ".tmp/final.md"
            source = root / ".tmp/source.tmp"
            source.write_bytes(b"final\n")
            assert_blocked_preserves(
                lambda: run_cli(
                    "publish", "--repo", str(repo),
                    "--progress-path", path.relative_to(repo).as_posix(),
                    "--source", source.relative_to(repo).as_posix(),
                    "--target", final_in_tmp.relative_to(repo).as_posix(),
                ),
                sent,
                before,
                "artifact",
            )
        elif name == "publisher_core_parity":
            assert RELEASE_CORE.read_bytes() == IMPLEMENTING_CORE.read_bytes()
            observed = []
            journals = []
            for label, cli in (("release", CLI), ("implementing", IMPLEMENTING_CLI)):
                candidate = new_repo(tmp, label)
                candidate_progress = initialize(candidate, "alpha")
                payload = publish_from_cli(candidate, candidate_progress, "reports/U1.md", b"parity\n", cli)
                observed.append((payload["state"], payload["sha256"], Path(str(payload["target"])).name))
                journals.append((candidate_progress.parent / ".phase-artifact-ownership.json").read_bytes())
            assert observed[0] == observed[1]
            assert journals[0] == journals[1]
        elif name == "publisher_atomic_recovery":
            failures = (
                "publish-before-prepare",
                "publish-after-prepare",
                "publish-after-final",
                "publish-before-finalize",
            )
            for endpoint, cli in (("release", CLI), ("implementing", IMPLEMENTING_CLI)):
                for failure in failures:
                    candidate = new_repo(tmp, endpoint + "-" + failure)
                    candidate_progress = initialize(candidate, "alpha")
                    source = candidate_progress.parent / ".tmp/reports-U1.md.tmp"
                    target = candidate_progress.parent / "reports/U1.md"
                    journal = candidate_progress.parent / ".phase-artifact-ownership.json"
                    try:
                        publish_from_cli(candidate, candidate_progress, "reports/U1.md", b"atomic\n", cli, failure)
                    except Blocked as exc:
                        assert "injected publish interruption" in str(exc), str(exc)
                    else:
                        raise AssertionError(f"{endpoint}/{failure} did not interrupt")
                    if failure == "publish-before-prepare":
                        assert source.is_file() and not target.exists() and not journal.exists()
                        payload = publish_from_cli(candidate, candidate_progress, "reports/U1.md", b"atomic\n", cli)
                    elif failure == "publish-after-prepare":
                        state = json.loads(journal.read_text(encoding="utf-8"))
                        assert state["pending"] is not None and source.is_file() and not target.exists()
                        if endpoint == "release":
                            compensated = run_cli("compensate", "--repo", str(candidate), "--progress-path", candidate_progress.relative_to(candidate).as_posix(), cli=cli)
                            assert compensated["state"] == "compensated"
                            assert not source.exists() and json.loads(journal.read_text(encoding="utf-8"))["pending"] is None
                            source.parent.mkdir(parents=True, exist_ok=True)
                            source.write_bytes(b"atomic\n")
                        payload = publish_from_cli(candidate, candidate_progress, "reports/U1.md", b"atomic\n", cli)
                    else:
                        state = json.loads(journal.read_text(encoding="utf-8"))
                        assert state["pending"] is not None and target.is_file() and not source.exists()
                        payload = run_cli(
                            "publish",
                            "--repo", str(candidate),
                            "--progress-path", candidate_progress.relative_to(candidate).as_posix(),
                            "--source", source.relative_to(candidate).as_posix(),
                            "--target", target.relative_to(candidate).as_posix(),
                            cli=cli,
                        )
                    assert payload["state"] == "published"
                    final_state = json.loads(journal.read_text(encoding="utf-8"))
                    assert final_state["pending"] is None and final_state["owned"]["reports/U1.md"] == payload["sha256"]
        elif name == "publisher_journal_collisions":
            for suffix in ("journal", "journal-temp"):
                candidate = new_repo(tmp, suffix)
                candidate_progress = initialize(candidate, "alpha")
                relative = ".release-loop/runs/alpha/.phase-artifact-ownership.json" + (".tmp" if suffix == "journal-temp" else "")
                collision = candidate / relative
                collision.parent.mkdir(parents=True, exist_ok=True)
                collision.write_bytes(b"collision\n")
                git(candidate, "add", "-f", relative)
                collision.unlink()
                assert_blocked_preserves(
                    lambda candidate=candidate, candidate_progress=candidate_progress: publish_from_cli(candidate, candidate_progress, "reports/U1.md", b"journal\n", CLI),
                    sent,
                    before,
                    "artifact ownership",
                )
        elif name == "publisher_semantics_attacks":
            control_targets = (
                "progress.md",
                ".phase-artifact-ownership.json",
                ".phase-artifact-ownership.json.tmp",
                ".tmp",
                ".tmp/final.md",
            )
            for endpoint, cli in (("release", CLI), ("implementing", IMPLEMENTING_CLI)):
                for index, target_key in enumerate(control_targets):
                    candidate = new_repo(tmp, f"{endpoint}-control-{index}")
                    candidate_progress = initialize(candidate, "alpha")
                    progress_before = candidate_progress.read_bytes()
                    target = candidate_progress.parent / target_key
                    source = candidate_progress.parent / f".tmp/control-{index}.tmp"
                    source.parent.mkdir(parents=True, exist_ok=True)
                    source.write_bytes(b"control\n")
                    assert_blocked_preserves(
                        lambda candidate=candidate, candidate_progress=candidate_progress, source=source, target=target, cli=cli: run_cli(
                            "publish", "--repo", str(candidate),
                            "--progress-path", candidate_progress.relative_to(candidate).as_posix(),
                            "--source", source.relative_to(candidate).as_posix(),
                            "--target", target.relative_to(candidate).as_posix(),
                            cli=cli,
                        ),
                        sent,
                        before,
                        "",
                    )
                    assert candidate_progress.read_bytes() == progress_before
        elif name == "publisher_target_prefix_attacks":
            forbidden = ("runs/foreign.md", "archive/foreign.md", ".handoff/foreign.md", "other/foreign.md")
            for endpoint, cli in (("release", CLI), ("implementing", IMPLEMENTING_CLI)):
                for shape in ("requested", "owned", "pending"):
                    for index, target_key in enumerate(forbidden):
                        candidate = new_repo(tmp, f"{endpoint}-{shape}-{index}")
                        legacy = candidate / ".release-loop/progress.md"
                        legacy.parent.mkdir()
                        legacy.write_text(progress("legacy", ".release-loop"), encoding="utf-8")
                        protected = legacy.parent / "protected.txt"
                        protected.write_bytes(b"PROTECTED\n")
                        source = legacy.parent / ".tmp/source.tmp"
                        source.parent.mkdir()
                        source.write_bytes(b"payload\n")
                        journal = legacy.parent / ".phase-artifact-ownership.json"
                        requested_key = target_key if shape == "requested" else "reports/U1.md"
                        if shape == "owned":
                            journal.write_text(json.dumps({"schema": "phase-artifact-ownership/v1", "owned": {target_key: hashlib.sha256(b"payload\n").hexdigest()}, "pending": None}, sort_keys=True, separators=(",", ":")) + "\n", encoding="utf-8")
                        elif shape == "pending":
                            journal.write_text(json.dumps({"schema": "phase-artifact-ownership/v1", "owned": {}, "pending": {"source": ".tmp/source.tmp", "target": target_key, "sha256": hashlib.sha256(b"payload\n").hexdigest()}}, sort_keys=True, separators=(",", ":")) + "\n", encoding="utf-8")
                        progress_before = legacy.read_bytes()
                        assert_blocked_preserves(
                            lambda candidate=candidate, legacy=legacy, source=source, requested_key=requested_key, cli=cli: run_cli(
                                "publish", "--repo", str(candidate),
                                "--progress-path", legacy.relative_to(candidate).as_posix(),
                                "--source", source.relative_to(candidate).as_posix(),
                                "--target", (legacy.parent / requested_key).relative_to(candidate).as_posix(),
                                cli=cli,
                            ),
                            sent,
                            before,
                            "artifact ownership",
                        )
                        assert legacy.read_bytes() == progress_before
                        assert protected.read_bytes() == b"PROTECTED\n"

                attacks = ("source-progress", "source-tracked", "source-owned", "target-temp", "traversal", "same-path")
                for attack in attacks:
                    candidate = new_repo(tmp, f"{endpoint}-{attack}")
                    candidate_progress = initialize(candidate, "alpha")
                    root = candidate_progress.parent
                    source = root / ".tmp/source.tmp"
                    source.parent.mkdir(parents=True, exist_ok=True)
                    source.write_bytes(b"pending\n")
                    source_key = ".tmp/source.tmp"
                    target_key = "reports/U1.md"
                    owned = {}
                    if attack == "source-progress": source_key = "progress.md"
                    elif attack == "source-tracked": git(candidate, "add", "-f", source.relative_to(candidate).as_posix())
                    elif attack == "source-owned": owned[source_key] = "0" * 64
                    elif attack == "target-temp": target_key = ".tmp/final.md"
                    elif attack == "traversal": source_key = ".tmp/../progress.md"
                    elif attack == "same-path": target_key = source_key
                    journal = root / ".phase-artifact-ownership.json"
                    journal.write_text(json.dumps({
                        "schema": "phase-artifact-ownership/v1",
                        "owned": owned,
                        "pending": {"source": source_key, "target": target_key, "sha256": hashlib.sha256(b"pending\n").hexdigest()},
                    }, sort_keys=True, separators=(",", ":")) + "\n", encoding="utf-8")
                    progress_before = candidate_progress.read_bytes()
                    assert_blocked_preserves(
                        lambda candidate=candidate, candidate_progress=candidate_progress, source=source, root=root, cli=cli: run_cli(
                            "publish", "--repo", str(candidate),
                            "--progress-path", candidate_progress.relative_to(candidate).as_posix(),
                            "--source", source.relative_to(candidate).as_posix(),
                            "--target", (root / "reports/U1.md").relative_to(candidate).as_posix(),
                            cli=cli,
                        ),
                        sent,
                        before,
                        "",
                    )
                    assert candidate_progress.read_bytes() == progress_before
        elif name == "stateful_scoped_lifecycle":
            require_phase_consumer_contract()
            path = initialize(repo, "alpha")
            for relative in (
                "briefs/U1-brief.md",
                "reports/U1-report.md",
                "reviews/U1-diff.txt",
                "evidence/U1/T6-success.md",
            ):
                publish_phase_artifact(repo, path, relative, relative.encode("utf-8") + b"\n")
            base = new_repo(tmp, "base")
            result = handoff_scope(repo, base, str(path.relative_to(repo)))
            assert result["cleanup_permitted"] is True
            base_progress = base / ".release-loop/runs/alpha/progress.md"
            archive_scope(base, str(base_progress.relative_to(base)), ".release-loop/archive/2026-08-23-alpha")
            assert not (base / ".release-loop/progress.md").exists()
            assert (base / ".release-loop/archive/2026-08-23-alpha/progress.md").is_file()
        elif name == "matrix_evidence_regeneration":
            path = initialize(repo, "alpha")
            stale = (
                "evidence/U1/matrix.md",
                *(f"evidence/U2/T6-{outcome}.md" for outcome in ("success", "forced-failure", "rerun", "compensation", "headless", "cancellation")),
                *(f"evidence/U4/T3-{outcome}.md" for outcome in ("success", "forced-failure", "rerun", "compensation", "headless", "cancellation")),
                *(f"evidence/U4/round2/T3-{outcome}.md" for outcome in ("success", "forced-failure", "rerun", "compensation", "headless", "cancellation")),
            )
            for index, relative in enumerate(stale):
                target = path.parent / relative
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_text(f"stale-{index}\n", encoding="utf-8")
            result = subprocess.run(
                (
                    sys.executable,
                    str(EVIDENCE_CLI),
                    "--repo", str(repo),
                    "--progress-path", path.relative_to(repo).as_posix(),
                ),
                cwd=ROOT,
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                check=False,
            )
            assert result.returncode == 0, result.stderr
            payload = json.loads(result.stdout)
            assert payload["state"] == "published" and payload["record_count"] == 36
            manifest = path.parent / "evidence/matrix-authority-v2.json"
            authority = json.loads(manifest.read_text(encoding="utf-8"))
            assert len(authority["records"]) == 36 and len(authority["supersedes"]) == len(stale)
            before_manifest = manifest.read_bytes()

            def assert_authority_blocked(label: str, diagnostic: str) -> None:
                attack = subprocess.run(
                    (
                        sys.executable,
                        str(EVIDENCE_CLI),
                        "--repo", str(repo),
                        "--progress-path", path.relative_to(repo).as_posix(),
                    ),
                    cwd=ROOT,
                    text=True,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE,
                    check=False,
                )
                assert attack.returncode != 0 and diagnostic in attack.stderr, (label, attack.stderr)

            missing = json.loads(before_manifest)
            missing["records"].pop()
            manifest.write_text(json.dumps(missing, sort_keys=True, separators=(",", ":")) + "\n", encoding="utf-8")
            assert_authority_blocked("missing", "record count")
            duplicate = json.loads(before_manifest)
            duplicate["records"][1] = dict(duplicate["records"][0])
            manifest.write_text(json.dumps(duplicate, sort_keys=True, separators=(",", ":")) + "\n", encoding="utf-8")
            assert_authority_blocked("duplicate", "duplicate")
            chained = json.loads(before_manifest)
            chained["supersedes"][0]["stale_path"] = chained["records"][0]["path"]
            manifest.write_text(json.dumps(chained, sort_keys=True, separators=(",", ":")) + "\n", encoding="utf-8")
            assert_authority_blocked("chained", "chained")
            mismatch = json.loads(before_manifest)
            mismatch["records"][0]["sha256"] = "0" * 64
            manifest.write_text(json.dumps(mismatch, sort_keys=True, separators=(",", ":")) + "\n", encoding="utf-8")
            assert_authority_blocked("manifest-digest", "digest mismatch")
            manifest.write_bytes(before_manifest)
            dirty_record = repo / authority["records"][0]["path"]
            record_bytes = dirty_record.read_bytes()
            dirty_payload = json.loads(record_bytes)
            dirty_payload["bounded_output"] += "dirty"
            dirty_record.write_text(json.dumps(dirty_payload, sort_keys=True, separators=(",", ":")) + "\n", encoding="utf-8")
            assert_authority_blocked("dirty-record", "publisher-owned")
            dirty_record.write_bytes(record_bytes)
            dirty_stale = path.parent / stale[0]
            stale_bytes = dirty_stale.read_bytes()
            dirty_stale.write_bytes(stale_bytes + b"dirty\n")
            assert_authority_blocked("dirty-stale", "stale digest mismatch")
            dirty_stale.write_bytes(stale_bytes)
            manifest.write_bytes(before_manifest)
            replay = subprocess.run(
                (
                    sys.executable,
                    str(EVIDENCE_CLI),
                    "--repo", str(repo),
                    "--progress-path", path.relative_to(repo).as_posix(),
                ),
                cwd=ROOT,
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                check=False,
            )
            assert replay.returncode == 0, replay.stderr
            assert json.loads(replay.stdout)["state"] == "reused"
            assert manifest.read_bytes() == before_manifest
        elif name == "fix_event_migration_validation":
            path = initialize(repo, "alpha")
            head = git(repo, "rev-parse", "HEAD")
            source_result = publish_from_cli(repo, path, "reviews/events/U3-round1.md", b"source-review\n", CLI)
            fixer_report = publish_from_cli(repo, path, "reports/U3-fix-migration.md", b"fixer-report\n", CLI)
            progress_text = path.read_text(encoding="utf-8") + (
                "\nreview_counts:\n"
                "  completeness: partial\n"
                "  counting_started_at: 2026-08-24T00:00:00Z\n"
                "  unit_passes: 1\n"
                "  fix_rounds: 0\n"
                "  final_passes: 0\n"
                "  standalone_passes: 0\n"
                "  findings_fixed: 0\n"
                "  findings_deferred: 0\n"
                "review_events:\n"
                "  - id: unit:U3:1\n"
                "    kind: unit\n"
                "    subject: U3\n"
                "    ordinal: 1\n"
                "    state: complete\n"
                f"    reviewed_head: {head}\n"
                f"    result_path: {source_result['target']}\n"
                f"    result_sha256: {source_result['sha256']}\n"
                "    outcome: blocked\n"
                "    source_review_event: null\n"
                "    re_review_of: null\n"
                "    source_adoption_path: null\n"
                "    source_adoption_sha256: null\n"
            )
            path.write_text(progress_text, encoding="utf-8")
            spec = importlib.util.spec_from_file_location("fix_event_migration", FIX_MIGRATION_CLI)
            assert spec is not None and spec.loader is not None
            migration = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(migration)

            base_row = {
                "fix_commit": head,
                "fixer_report_path": fixer_report["target"],
                "fixer_report_sha256": fixer_report["sha256"],
                "id": "fix:U3:1",
                "ordinal": 1,
                "reviewed_head": head,
                "source_review_event": "unit:U3:1",
                "subject": "U3",
            }

            def publish_adoption(label: str, rows: list[dict[str, object]]) -> str:
                adoption = {
                    "counting_started_at": "2026-08-24T00:00:00Z",
                    "progress_path": path.relative_to(repo).as_posix(),
                    "rows": rows,
                    "schema": "review-fix-event-migration/v1",
                }
                payload = publish_from_cli(
                    repo,
                    path,
                    f"reviews/adoptions/{label}.json",
                    json.dumps(adoption, sort_keys=True, separators=(",", ":")).encode() + b"\n",
                    CLI,
                )
                return str(payload["target"])

            adoption_path = publish_adoption("fix-history-valid", [base_row])
            accepted = migration.validate_migration(repo, path.relative_to(repo).as_posix(), adoption_path, lambda _: "G")
            assert accepted["state"] == "new" and accepted["events"][0]["id"] == "fix:U3:1"
            assert accepted["review_counts"]["fix_rounds"] == 1

            attacks = []
            wrong_source = dict(base_row)
            wrong_source["source_review_event"] = "unit:U9:1"
            attacks.append(("wrong-source", [wrong_source], lambda _: "G", "source review"))
            wrong_digest = dict(base_row)
            wrong_digest["fixer_report_sha256"] = "0" * 64
            attacks.append(("wrong-digest", [wrong_digest], lambda _: "G", "digest"))
            missing_report = dict(base_row)
            missing_report["fixer_report_path"] = ".release-loop/runs/alpha/reports/missing.md"
            attacks.append(("missing-report", [missing_report], lambda _: "G", "fixer report"))
            attacks.append(("unsigned", [base_row], lambda _: "U", "signed"))
            attacks.append(("duplicate", [base_row, dict(base_row)], lambda _: "G", "duplicate"))
            for label, rows, signature, diagnostic in attacks:
                candidate = publish_adoption("fix-history-" + label, rows)
                try:
                    migration.validate_migration(repo, path.relative_to(repo).as_posix(), candidate, signature)
                except migration.Blocked as exc:
                    assert diagnostic in str(exc), (label, str(exc))
                else:
                    raise AssertionError(label + " migration attack passed")
            try:
                migration.validate_migration(repo, path.relative_to(repo).as_posix(), "reviews/adoptions/missing.json", lambda _: "G")
            except migration.Blocked as exc:
                assert "adoption" in str(exc)
            else:
                raise AssertionError("missing migration adoption passed")

            event = accepted["events"][0]
            path.write_text(path.read_text(encoding="utf-8") + (
                f"  - id: {event['id']}\n"
                "    kind: fix\n"
                f"    subject: {event['subject']}\n"
                f"    ordinal: {event['ordinal']}\n"
                "    state: complete\n"
                f"    reviewed_head: {event['reviewed_head']}\n"
                f"    result_path: {event['result_path']}\n"
                f"    result_sha256: {event['result_sha256']}\n"
                "    outcome: clean\n"
                "    finding_inventory: []\n"
                f"    source_review_event: {event['source_review_event']}\n"
                "    re_review_of: null\n"
                f"    source_adoption_path: {event['source_adoption_path']}\n"
                f"    source_adoption_sha256: {event['source_adoption_sha256']}\n"
            ), encoding="utf-8")
            replay = migration.validate_migration(repo, path.relative_to(repo).as_posix(), adoption_path, lambda _: "G")
            assert replay["state"] == "reused" and replay["review_counts"]["fix_rounds"] == 1
        elif name in REVIEW_CASES:
            require_review_contract()
            path = initialize(repo, "alpha")
            reviews = ReviewFixture(repo, path)
            head = git(repo, "rev-parse", "HEAD")
            output = reviewer_output("clean", tail=b'{"verdict":"clean"}\nreviewer tail preserved\n')

            if name == "review_event_lifecycle":
                first = reviews.allocate("unit", "U1", head)
                reviews.complete(str(first["id"]), reviewer_output("actionable", review_body=("fp-review",)))
                fix = reviews.allocate("fix", "U1", head, source_review_event="unit:U1:1")
                reviews.complete(str(fix["id"]), reviewer_output("clean"))
                second = reviews.allocate("unit", "U1", head, re_review_of="unit:U1:1")
                reviews.complete(str(second["id"]), output)
                reviews.verify_re_review(str(second["id"]))
                final = reviews.allocate("final", "branch", head)
                reviews.complete(str(final["id"]), output)
                assert reviews.counts() == {
                    "unit_passes": 2,
                    "fix_rounds": 1,
                    "final_passes": 1,
                    "standalone_passes": 0,
                    "findings_fixed": 1,
                    "findings_deferred": 0,
                }
                assert reviews.dispositions["fp-review"]["status"] == "fixed"
            elif name == "event_replay":
                first = reviews.allocate("unit", "U1", head)
                writes = reviews.persisted_writes
                replay = reviews.allocate("unit", "U1", head)
                assert replay is first and reviews.persisted_writes == writes and len(reviews.events) == 1
                reviews.complete(str(first["id"]), output)
                assert reviews.complete(str(first["id"]), output) is first
                assert reviews.counts()["unit_passes"] == 1
            elif name == "matching_started_result":
                event = reviews.allocate("unit", "U1", head)
                wrapper = reviews._wrapper(event, output)
                publish_from_cli(repo, path, reviews._result_relative(event), wrapper, IMPLEMENTING_CLI)
                assert event["state"] == "started"
                assert reviews.recover(str(event["id"])) == "recovered"
                assert event["result_sha256"] == hashlib.sha256(wrapper).hexdigest()
                assert reviews.counts()["unit_passes"] == 1
            elif name == "deferred_then_fixed":
                first = reviews.allocate("unit", "U1", head)
                reviews.complete(str(first["id"]), reviewer_output("actionable", review_body=("fp-deferred",)))
                reviews.set_disposition("fp-deferred", "deferred", str(first["id"]), "triaged for later work")
                second = reviews.allocate("unit", "U1", head, re_review_of="unit:U1:1")
                reviews.complete(str(second["id"]), output)
                reviews.verify_re_review(str(second["id"]))
                assert reviews.dispositions["fp-deferred"] == {
                    "status": "fixed",
                    "severity": "P1",
                    "introduced_by": "unit:U1:1",
                    "resolved_by": "unit:U1:2",
                    "rationale": None,
                }
            elif name == "phase_gate_reuse":
                final = reviews.allocate("final", "branch", head)
                reviews.complete(str(final["id"]), output)
                before_events = list(reviews.events)
                assert reviews.reuse_phase_gate(str(final["id"])) is final
                assert reviews.events == before_events and reviews.counts()["final_passes"] == 1
            elif name == "outside_diff_inventory_complete":
                event = reviews.allocate("final", "branch", head)
                reviews.complete(str(event["id"]), reviewer_output("actionable", review_body=("fp-body",), outside_diff=("fp-outside",), severity="P3"))
                reviews.set_disposition("fp-body", "deferred", str(event["id"]), "accepted minor residual")
                reviews.set_disposition("fp-outside", "deferred", str(event["id"]), "accepted outside-diff residual")
                reviews.clean_gate(str(event["id"]))
            elif name == "event_conflict":
                event = reviews.allocate("unit", "U1", head)
                first = reviewer_output("clean", tail=b"first result\n")
                wrapper = reviews._wrapper(event, first)
                publish_from_cli(repo, path, reviews._result_relative(event), wrapper, IMPLEMENTING_CLI)
                try:
                    reviews.complete(str(event["id"]), reviewer_output("clean", tail=b"different result\n"))
                except Blocked as exc:
                    assert str(exc).startswith("review-event-conflict: unit:U1:1:"), str(exc)
                else:
                    raise AssertionError("conflicting immutable result did not block")
            elif name == "completed_result_missing":
                event = reviews.allocate("unit", "U1", head)
                reviews.complete(str(event["id"]), output)
                reviews._result_path(event).unlink()
                try:
                    reviews.verify_result(str(event["id"]))
                except Blocked as exc:
                    assert str(exc) == "completed review result missing: unit:U1:1"
                else:
                    raise AssertionError("missing completed result did not block")
            elif name == "completed_digest_mismatch":
                event = reviews.allocate("unit", "U1", head)
                reviews.complete(str(event["id"]), output)
                reviews._result_path(event).write_bytes(b"mutated\n")
                try:
                    reviews.verify_result(str(event["id"]))
                except Blocked as exc:
                    assert str(exc) == "completed review digest mismatch: unit:U1:1"
                else:
                    raise AssertionError("mismatched completed result did not block")
            elif name == "fix_cannot_mark_fixed":
                first = reviews.allocate("unit", "U1", head)
                reviews.complete(str(first["id"]), reviewer_output("actionable", review_body=("fp-fix",)))
                fix = reviews.allocate("fix", "U1", head, source_review_event="unit:U1:1")
                reviews.complete(str(fix["id"]), output)
                try:
                    reviews.set_disposition("fp-fix", "fixed", str(fix["id"]))
                except Blocked as exc:
                    assert str(exc) == "fix event cannot change disposition"
                else:
                    raise AssertionError("fix event marked a finding fixed")
            elif name == "outside_diff_missing_disposition":
                event = reviews.allocate("final", "branch", head)
                reviews.complete(str(event["id"]), reviewer_output("actionable", outside_diff=("fp-outside",)))
                try:
                    reviews.clean_gate(str(event["id"]))
                except Blocked as exc:
                    assert str(exc) == "finding lacks terminal disposition: fp-outside"
                else:
                    raise AssertionError("outside-diff finding without disposition did not block")
            elif name == "standalone_and_reuse":
                standalone = reviews.allocate("standalone", "branch", head)
                reviews.complete(str(standalone["id"]), output)
                assert reviews.reuse_phase_gate(str(standalone["id"])) is standalone
                assert reviews.counts() == {
                    "unit_passes": 0,
                    "fix_rounds": 0,
                    "final_passes": 0,
                    "standalone_passes": 1,
                    "findings_fixed": 0,
                    "findings_deferred": 0,
                }
            elif name == "inventory_omitted_row":
                event = reviews.allocate("final", "branch", head)
                reviews.complete(str(event["id"]), reviewer_output("actionable", outside_diff=("fp-omitted",), severity="P3"))
                reviews.set_disposition("fp-omitted", "deferred", str(event["id"]), "minor")
                event["finding_inventory"] = []
                try:
                    reviews.clean_gate(str(event["id"]))
                except Blocked as exc:
                    assert "omitted" in str(exc), str(exc)
                else:
                    raise AssertionError("omitted sealed-result inventory row did not block")
            elif name == "inventory_extra_row":
                event = reviews.allocate("final", "branch", head)
                reviews.complete(str(event["id"]), output)
                event["finding_inventory"] = [{"fingerprint": "fp-extra", "severity": "P1", "source": "outside-diff"}]
                try:
                    reviews.clean_gate(str(event["id"]))
                except Blocked as exc:
                    assert "extra" in str(exc), str(exc)
                else:
                    raise AssertionError("extra recorded inventory row did not block")
            elif name in {"wrong_source_re_review", "unrelated_later_review", "finding_still_present"}:
                first = reviews.allocate("unit", "U1", head)
                reviews.complete(str(first["id"]), reviewer_output("actionable", review_body=("fp-source",)))
                source = "unit:U1:1" if name != "unrelated_later_review" else None
                second = reviews.allocate("unit", "U1", head, re_review_of=source)
                current = ("fp-source",) if name == "finding_still_present" else ()
                reviews.complete(str(second["id"]), reviewer_output("actionable" if current else "clean", review_body=current))
                if name == "wrong_source_re_review":
                    second["re_review_of"] = "unit:other:1"
                try:
                    reviews.verify_re_review(str(second["id"]))
                except Blocked:
                    pass
                else:
                    raise AssertionError(f"{name} re-review mutant did not block")
            elif name == "severity_deferred_gate":
                event = reviews.allocate("final", "branch", head)
                reviews.complete(str(event["id"]), reviewer_output("actionable", review_body=("fp-p1",)))
                reviews.set_disposition("fp-p1", "deferred", str(event["id"]), "not fixed")
                try:
                    reviews.clean_gate(str(event["id"]))
                except Blocked as exc:
                    assert "P1" in str(exc), str(exc)
                else:
                    raise AssertionError("deferred P1 finding satisfied clean")
            elif name == "ordinal_gap_rejected":
                first = reviews.allocate("unit", "U1", head)
                reviews.complete(str(first["id"]), output)
                corrupt = dict(first)
                corrupt["id"] = "unit:U1:3"
                corrupt["ordinal"] = 3
                reviews.events.append(corrupt)
                try:
                    reviews.allocate("unit", "U1", head)
                except Blocked as exc:
                    assert "ordinal gap" in str(exc), str(exc)
                else:
                    raise AssertionError("ordinal gap did not block")
            elif name == "completed_full_row":
                event = reviews.allocate("unit", "U1", head)
                reviews.complete(str(event["id"]), reviewer_output("actionable", review_body=("fp-full",)))
                assert event["outcome"] == "actionable"
                assert event["finding_inventory"] == [{"fingerprint": "fp-full", "severity": "P1", "source": "review-body"}]
            elif name in {"clean_body_actionable_metadata", "actionable_body_clean_metadata"}:
                event = reviews.allocate("unit", "U1", head)
                body = reviewer_output("clean") if name == "clean_body_actionable_metadata" else reviewer_output("actionable", review_body=("fp-live",))
                wrapper = reviews._wrapper(event, body)
                header, raw_body = wrapper.split(b"\n", 1)
                metadata = json.loads(header)
                if name == "clean_body_actionable_metadata":
                    metadata["outcome"] = "actionable"
                    metadata["finding_inventory"] = [{"fingerprint": "fp-fake", "severity": "P1", "source": "review-body"}]
                else:
                    metadata["outcome"] = "clean"
                    metadata["finding_inventory"] = []
                mutant = json.dumps(metadata, sort_keys=True, separators=(",", ":")).encode() + b"\n" + raw_body
                try:
                    reviews._parse_wrapper(event, mutant)
                except Blocked as exc:
                    assert "manifest mismatch" in str(exc), str(exc)
                else:
                    raise AssertionError(f"{name} mutant did not block")
            elif name == "delimiter_in_body":
                event = reviews.allocate("unit", "U1", head)
                body = reviewer_output("clean", tail=b"before\n--- reviewer body ---\nafter\n")
                reviews.complete(str(event["id"]), body)
                _, observed = reviews.verify_result(str(event["id"]))
                assert observed == body
            elif name in {"legacy_source_adoption", "legacy_adoption_mismatch"}:
                source = reviews.allocate("unit", "U3", head)
                legacy = b"P0: none\n\nP1 findings\n\n1. legacy finding\n\nSPEC_VERDICT: BLOCKED\nQUALITY_VERDICT: REQUEST_CHANGES\n"
                published = publish_from_cli(repo, path, reviews._result_relative(source), legacy, IMPLEMENTING_CLI)
                source["state"] = "complete"
                source["result_sha256"] = published["sha256"]
                source["outcome"] = "blocked"
                source["finding_inventory"] = [{"fingerprint": "fp-legacy", "source": "structured"}]
                reviews._persist()
                adopted_inventory = [{"fingerprint": "fp-legacy", "severity": "P1", "source": "structured"}]
                reviews.adopt_legacy_source(str(source["id"]), "blocked", adopted_inventory)
                if name == "legacy_adoption_mismatch":
                    original_path = source["source_adoption_path"]
                    source["source_adoption_path"] = ".release-loop/reviews/adoptions/wrong.json"
                    try:
                        reviews._source_metadata(source)
                    except Blocked as exc:
                        assert "adoption integrity mismatch" in str(exc), str(exc)
                    else:
                        raise AssertionError("legacy adoption path mismatch did not block")
                    source["source_adoption_path"] = original_path
                    source["result_sha256"] = "0" * 64
                    try:
                        reviews._source_metadata(source)
                    except Blocked as exc:
                        assert "mismatch" in str(exc), str(exc)
                    else:
                        raise AssertionError("legacy adoption source SHA mismatch did not block")
                else:
                    second = reviews.allocate("unit", "U3", head, re_review_of=str(source["id"]))
                    reviews.complete(str(second["id"]), reviewer_output("clean"))
                    reviews.verify_re_review(str(second["id"]))
                    assert reviews.dispositions["fp-legacy"]["status"] == "fixed"
                    assert reviews._result_path(source).read_bytes() == legacy
            elif name == "invalid_review_outcome":
                event = reviews.allocate("final", "branch", head)
                try:
                    reviews.complete(str(event["id"]), reviewer_output("fixed"))
                except Blocked as exc:
                    assert "outcome" in str(exc), str(exc)
                else:
                    raise AssertionError("invalid review outcome did not block")
            elif name in {"actionable_phase_reuse", "blocked_phase_reuse"}:
                event = reviews.allocate("final", "branch", head)
                if name == "actionable_phase_reuse":
                    reviews.complete(str(event["id"]), reviewer_output("actionable", review_body=("fp-phase",), severity="P3"))
                    reviews.set_disposition("fp-phase", "deferred", str(event["id"]), "minor residual")
                else:
                    reviews.complete(str(event["id"]), reviewer_output("blocked"))
                try:
                    reviews.reuse_phase_gate(str(event["id"]))
                except Blocked as exc:
                    assert "clean" in str(exc), str(exc)
                else:
                    raise AssertionError(f"{name} reused a non-clean result")
            elif name == "source_review_self_fix":
                event = reviews.allocate("unit", "U1", head)
                reviews.complete(str(event["id"]), reviewer_output("actionable", review_body=("fp-self",)))
                try:
                    reviews.set_disposition("fp-self", "fixed", str(event["id"]))
                except Blocked as exc:
                    assert "verifying re-review" in str(exc), str(exc)
                else:
                    raise AssertionError("source review marked its own finding fixed")
        else:
            raise AssertionError(f"unknown case: {name}")
        write_matrix_observation(name, repo, matrix_pre_state, sent, before)


if CASE == "scope":
    selected = CASES
elif CASE == "all":
    selected = CASES + REVIEW_CASES + HISTORY_CASES + RETRO_CASES
elif CASE == "consumers":
    selected = CONSUMER_CASES
elif CASE == "reviews":
    selected = REVIEW_CASES
elif CASE == "history":
    selected = HISTORY_CASES
elif CASE == "retro":
    selected = RETRO_CASES
elif CASE == "lifecycle":
    selected = LIFECYCLE_CASES
elif CASE == "full_validation_gate":
    try:
        receipt = run_full_validation_gate()
        print(f"ok:   [run-artifact-integrity] full_validation_gate receipt={receipt['path']} sha256={receipt['sha256']}")
        run_case("full_lifecycle")
    except Exception as exc:
        print(f"FAIL: [run-artifact-integrity] full_validation_gate: {exc}")
        raise SystemExit(1)
    print("ok:   [run-artifact-integrity] full_lifecycle")
    raise SystemExit(0)
elif CASE in CASES + REVIEW_CASES + HISTORY_CASES + RETRO_CASES + LIFECYCLE_CASES:
    selected = (CASE,)
else:
    print("usage: bash scripts/test-run-artifact-integrity.sh <scope|all|consumers|reviews|history|retro|lifecycle|full_validation_gate|case>", file=sys.stderr)
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
