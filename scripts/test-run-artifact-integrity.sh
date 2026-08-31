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
import re
from datetime import datetime, timezone
from pathlib import Path
import shutil
import shlex
import subprocess
import sys
import tempfile
import time


CASE = sys.argv[1]
ROOT = Path(sys.argv[2])
COMMAND_TRACE: list[dict[str, object]] = []
DISPOSABLE_REPOS: list[Path] = []
DISPOSABLE_PRE_STATES: dict[str, dict[str, object]] = {}
MATRIX_MECHANISM = ""
MATRIX_NEXT_INVOCATION: dict[str, object] = {}
MATRIX_EXTERNAL_ROOT: Path | None = None
MATRIX_EXTERNAL_PRE_STATE: dict[str, object] = {}


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
sys.path.insert(0, str(CLI.parent))
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
    "archive_journal_resume_tamper",
    "archive_destination_foreign_entry",
    "archive_manifest_pending_recovery",
    "archive_progress_commit_recovery",
    "archive_requires_persisted_destination",
    "archive_incomplete_run",
    "legacy_archive_recovery_request",
    "legacy_archive_recovery_lifecycle",
    "legacy_archive_recovery_success",
    "legacy_archive_recovery_requires_terminal_evidence",
    "legacy_archive_recovery_rejects_unmerged_ship",
    "legacy_archive_recovery_rejects_unexecuted_final_action",
    "legacy_archive_recovery_rejects_uncommitted_retro",
    "legacy_archive_recovery_rejects_retro_before_ship",
    "legacy_archive_recovery_rejects_wrong_final_action_kind",
    "legacy_archive_recovery_rejects_draft_plan",
    "legacy_archive_recovery_rejects_plan_seal_mismatch",
    "legacy_archive_recovery_rejects_missing_introduction_object",
    "legacy_archive_recovery_ancestor_replacement",
    "legacy_archive_recovery_resume_after_g0",
    "legacy_archive_recovery_resume_after_receipt",
    "legacy_archive_recovery_resume_after_g1",
    "legacy_archive_recovery_resume_after_g2",
    "legacy_archive_recovery_resume_after_g3",
    "legacy_archive_recovery_generation_tamper",
    "legacy_archive_recovery_rejects_tampered_g0_result",
    "legacy_archive_recovery_rejects_tampered_receipt",
    "legacy_archive_recovery_rejects_tampered_g1",
    "legacy_archive_recovery_rejects_tampered_g2",
    "legacy_archive_recovery_rejects_tampered_g3",
    "legacy_archive_recovery_restore_rejects_deleted_gate_receipt",
    "legacy_archive_recovery_restore_rejects_tampered_gate_receipt",
    "legacy_archive_recovery_rejects_foreign_destination_before_g1",
    "legacy_archive_recovery_rejects_backup_change_before_copy",
    "legacy_archive_recovery_rejects_source_change_before_copy",
    "legacy_archive_recovery_target_create_swap",
    "legacy_archive_recovery_before_g1_ancestor",
    "legacy_archive_recovery_cleanup_foreign_preserves_g3",
    "legacy_archive_recovery_resume_after_cleanup_one",
    "legacy_archive_recovery_progress_after_binding_swap",
    "legacy_archive_recovery_rejects_concurrent_restore",
    "legacy_archive_recovery_records_rejected_audit",
    "legacy_archive_recovery_backup_revalidates_gate_receipt",
    "legacy_archive_recovery_rejects_unsafe_journal_entries",
    "legacy_archive_recovery_resumes_archive_publication_faults",
    "legacy_archive_recovery_resumes_atomic_temp_publications",
    "legacy_archive_recovery_rejects_terminal_evidence_mutants",
    "legacy_archive_recovery_serializes_audit_and_restore",
    "legacy_archive_recovery_parser_provenance_matrix",
    "legacy_archive_recovery_resumes_after_gate_receipt",
    "legacy_archive_recovery_resumes_after_destination_mkdir",
    "legacy_archive_recovery_completed_archive_is_idempotent",
    "legacy_archive_recovery_rejects_foreign_publication_temporaries",
    "legacy_archive_recovery_resumes_owned_prefix_temporary",
    "legacy_archive_recovery_blocks_generation_change_before_progress_replace",
    "legacy_archive_recovery_blocks_foreign_partial_destination_before_mutation",
    "legacy_archive_recovery_preserves_nonmanifest_owned_journal_row",
    "legacy_archive_recovery_rejects_reserved_payload_collisions",
    "legacy_archive_recovery_rejects_frontmatter_shadowing",
    "legacy_archive_recovery_revalidates_completed_owned_rows",
    "legacy_archive_recovery_markdown_heading_boundaries",
    "legacy_archive_recovery_rejects_plan_frontmatter_attacks",
    "legacy_archive_recovery_rejects_body_structural_authority",
    "legacy_archive_recovery_timestamps_each_generation",
    "legacy_archive_recovery_rejects_invalid_terminal_updated",
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
    "legacy_handoff_success",
    "legacy_handoff_v1_ownership",
    "legacy_handoff_v1_success",
    "legacy_handoff_v1_partial_directory_rerun",
    "legacy_handoff_v1_destination_mismatch",
    "legacy_handoff_v1_symlinks",
    "legacy_handoff_source_changed",
    "legacy_handoff_complete_rerun",
    "legacy_handoff_cli_contract",
    "legacy_handoff_incomplete_rerun",
    "legacy_handoff_collision",
    "legacy_handoff_index_collision",
    "legacy_handoff_destination_attacks",
    "legacy_handoff_source_persistent_children",
    "legacy_handoff_symlinks",
    "legacy_handoff_marker_schema",
    "legacy_handoff_complete_destination_regression",
    "legacy_handoff_preserves_recovery_roots",
    "legacy_handoff_partial_directory_rerun",
    "archive_direct_escape",
    "archive_parent_escape",
    "archive_wrong_family",
    "legacy_direct_escape",
    "legacy_parent_escape",
    "handoff_direct_escape",
    "handoff_parent_escape",
    "handoff_wrong_family",
    "operative_contract_mutation",
    "shipping_cleanup_contract_mutation",
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
    "matrix_generator_parent_symlink",
    "fix_migration_parent_symlink",
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
MATRIX_PROBE_CASES = tuple(
    f"matrix_{transition}_{outcome.replace('-', '_')}"
    for transition in ("T1", "T2", "T3", "T4", "T5", "T6")
    for outcome in ("success", "forced-failure", "rerun", "compensation", "headless", "cancellation")
)
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
    ("legacy-handoff", HOOKS, 'python3 "$release_loop_skill_root/scripts/run-artifact-integrity.py" handoff --repo <source-worktree> --base-repo <base-checkout> --progress-path <repo-relative-progress-path> --legacy-destination .release-loop'),
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
        (selected["SCHEMA"], "Legacy records require `artifact_root: .release-loop`."),
        (selected["SCHEMA"], "The four ordinary lifecycle artifact-root families are"),
        (
            selected["SCHEMA"],
            "`recovery-authority/` and `recovery-backups/` are fixed internal persistent recovery families",
        ),
        (selected["SCHEMA"], "They are never active transfer roots."),
        (selected["SCHEMA"], "Reject every symlink in each existing source or destination component"),
        (selected["ARCHIVE"], "Move scoped `progress.md` last as the archive commit point."),
        (selected["ARCHIVE"], "reuse the exact recorded archive destination"),
        (selected["ARCHIVE"], "Mid-move cancellation leaves the selected progress record in the source scope."),
        (selected["HOOKS"], "`.release-loop/.handoff` is the fixed handoff root"),
        (selected["HOOKS"], "Make the base owner discover and resume that exact progress path."),
        (selected["HOOKS"], "Cancellation preserves the source worktree."),
        (selected["HOOKS"], "are never active transfer bytes"),
        (selected["HOOKS"], "`recovery-authority/` and `recovery-backups/` are persistent siblings"),
        (selected["HOOKS"], "At the source, legacy handoff rejects every persistent sibling"),
        (selected["SKILL"], "adds `--legacy-destination .release-loop`"),
        (selected["SKILL"], "directory containing the loaded `SKILL.md`"),
        (selected["SKILL"], "temporary regular file under `<artifact_root>/.tmp/`"),
        (selected["SCHEMA"], "temporary path under `<artifact_root>/.tmp/`"),
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
    resolved = repo.resolve(strict=True)
    DISPOSABLE_REPOS.append(resolved)
    DISPOSABLE_PRE_STATES[str(resolved)] = matrix_fixture_snapshot(resolved)
    return resolved


def add_recovery_provenance(
    repo: Path,
    progress_path: Path,
    *,
    install_alternate: bool = True,
    plan_variant: str = "approved",
) -> None:
    introduction = "08e12a82752847b3bead5a96fd251b4ad58eae1b"
    approval = "295909c66be802fd8ce5c37d91367da11fd93acd"
    plan_frontmatter_variants = {
        "missing-body-seal",
        "duplicate-body-seal",
        "mismatch-body-seal",
        "duplicate-status",
        "delimiter-body-seal-shadow",
        "delimiter-status-shadow",
    }
    if plan_variant in plan_frontmatter_variants:
        plan_path = "docs/plans/recovery-provenance-fixture.md"
        contract = HOOKS
        body = "# Recovery Provenance Fixture\n\nThis approved plan records fixture work.\n"
        body_digest = hashlib.sha256(("\n" + body).encode("utf-8")).hexdigest()
        frontmatter = [
            "schema: plan/v1",
            "title: Recovery provenance fixture",
            "type: feat",
            "status: approved",
            f"body_seal: {body_digest}",
        ]
        if plan_variant == "missing-body-seal":
            frontmatter = [line for line in frontmatter if not line.startswith("body_seal:")]
        elif plan_variant == "duplicate-body-seal":
            frontmatter.append(f"body_seal: {body_digest}")
        elif plan_variant == "mismatch-body-seal":
            frontmatter[-1] = "body_seal: " + ("0" * 64 if body_digest != "0" * 64 else "1" * 64)
        elif plan_variant == "duplicate-status":
            frontmatter.append("status: approved")
        elif plan_variant in {"delimiter-body-seal-shadow", "delimiter-status-shadow"}:
            shadow = (
                "body_seal: " + "0" * 64
                if plan_variant == "delimiter-body-seal-shadow"
                else "status: draft"
            )
            deceptive_body = f"\n{shadow}\n---\n{body}"
            body_digest = hashlib.sha256(deceptive_body.encode("utf-8")).hexdigest()
            frontmatter[-1] = f"body_seal: {body_digest}"
            frontmatter.append("note: ---")
        plan_file = repo / plan_path
        plan_file.parent.mkdir(parents=True, exist_ok=True)
        if plan_variant in {"delimiter-body-seal-shadow", "delimiter-status-shadow"}:
            plan_text = "---\n" + "\n".join(frontmatter) + f"\n{shadow}\n---\n" + body
        else:
            plan_text = "---\n" + "\n".join(frontmatter) + "\n---\n" + body
        plan_file.write_text(plan_text, encoding="utf-8")
        git(repo, "add", plan_path)
        git(repo, "commit", "-qm", f"fixture plan {plan_variant}")
        approval = git(repo, "rev-parse", "HEAD")
        source_objects = Path(git(ROOT, "rev-parse", "--git-path", "objects")).resolve()
        alternates = repo / ".git/objects/info/alternates"
        alternates.parent.mkdir(parents=True, exist_ok=True)
        alternates.write_text(f"{source_objects}\n", encoding="utf-8")
        git(repo, "replace", "--graft", introduction, approval)
        git(repo, "merge-base", "--is-ancestor", approval, introduction)
        seal = body_digest
    elif plan_variant == "draft":
        plan_path = "docs/plans/2026-07-16-001-feat-signal-drift-check-plan.md"
    elif plan_variant in {
        "approved",
        "seal-mismatch",
        "approval-equals-introduction",
        "nonancestor-approval",
        "approval-blob-mismatch",
        "post-introduction-absence",
    }:
        plan_path = "docs/plans/2026-08-23-001-fix-run-artifact-integrity-plan.md"
    elif plan_variant not in plan_frontmatter_variants:
        raise AssertionError(f"unknown recovery plan variant: {plan_variant}")
    if plan_variant == "approval-equals-introduction":
        approval = introduction
    elif plan_variant in {"nonancestor-approval", "post-introduction-absence"}:
        approval = git(ROOT, "rev-parse", "HEAD")
    if plan_variant not in plan_frontmatter_variants:
        plan_blob = subprocess.run(
            ("git", "show", f"{approval}:{plan_path}"),
            cwd=ROOT,
            stdout=subprocess.PIPE,
            check=True,
        ).stdout
        plan_text = plan_blob.decode("utf-8")
        seal = hashlib.sha256(plan_text.split("---", 2)[2].encode("utf-8")).hexdigest()
        if plan_variant in {"seal-mismatch", "approval-blob-mismatch"}:
            seal = "0" * 64 if seal != "0" * 64 else "1" * 64
    if install_alternate:
        source_objects = Path(git(ROOT, "rev-parse", "--git-path", "objects")).resolve()
        alternates = repo / ".git/objects/info/alternates"
        alternates.parent.mkdir(parents=True, exist_ok=True)
        alternates.write_text(f"{source_objects}\n", encoding="utf-8")
    text = progress_path.read_text(encoding="utf-8")
    text = text.replace(
        "phase: implement\n",
        f"plan: {plan_path}\n"
        f"plan_approval_commit: {approval}\n"
        f"plan_seal: {seal}\n"
        f"contract_introduction_commit: {introduction}\n"
        "phase: implement\n",
        1,
    )
    progress_path.write_text(text, encoding="utf-8")


def add_recovery_terminal_evidence(
    repo: Path,
    progress_path: Path,
    *,
    retro_before_ship: bool = False,
) -> None:
    git(repo, "branch", "-M", "main")
    retro_path = repo / "docs/retros/2026-08-30-fixture-retro.md"
    if retro_before_ship:
        retro_path.parent.mkdir(parents=True, exist_ok=True)
        retro_path.write_text("# Fixture Retro\n\nCommitted recovery evidence.\n", encoding="utf-8")
        git(repo, "add", str(retro_path.relative_to(repo)))
        git(repo, "commit", "-qm", "fixture retro before ship")
        retro_commit = git(repo, "rev-parse", "HEAD")
    git(repo, "checkout", "-qb", "feat/fixture")
    (repo / "feature.txt").write_text("merged feature\n", encoding="utf-8")
    git(repo, "add", "feature.txt")
    git(repo, "commit", "-qm", "fixture feature")
    git(repo, "checkout", "-q", "main")
    git(repo, "merge", "--ff-only", "feat/fixture")
    ship_commit = git(repo, "rev-parse", "HEAD")
    if not retro_before_ship:
        retro_path.parent.mkdir(parents=True, exist_ok=True)
        retro_path.write_text("# Fixture Retro\n\nCommitted recovery evidence.\n", encoding="utf-8")
        git(repo, "add", str(retro_path.relative_to(repo)))
        git(repo, "commit", "-qm", "fixture retro")
        retro_commit = git(repo, "rev-parse", "HEAD")
    text = progress_path.read_text(encoding="utf-8")
    text = text.replace("phase: implement\n", "phase: retro\n", 1)
    text = text.replace("branch: feat/fixture\n", "branch: main\n", 1)
    text = text.replace(
        "flags: []\n",
        "flags: []\n"
        "retro: docs/retros/2026-08-30-fixture-retro.md\n"
        "ship_approved: {by: user, at: 2026-08-30T04:56:00Z, conditions: \"CI green, no open P0\"}\n"
        "merged: true\n",
        1,
    )
    text = text.replace("  status: predicted\n", "  status: executed\n", 1)
    text = text.replace("  command: null\n", "  command: git merge --ff-only feat/fixture\n", 1)
    terminal_updated = "2026-08-30T04:57:00Z" if retro_before_ship else "2026-08-30T04:59:00Z"
    text = text.replace("updated: 2026-08-23T00:00:00Z\n", f"updated: {terminal_updated}\n", 1)
    text = text.replace("  updated: 2026-08-23T00:00:00Z\n", "  updated: 2026-08-30T04:57:00Z\n", 1)
    if retro_before_ship:
        text += (
            f"- 2026-08-30T04:55:00Z retro: committed ({retro_commit})\n"
            f"- 2026-08-30T04:57:00Z ship: merged ({ship_commit})\n"
        )
    else:
        text += (
            f"- 2026-08-30T04:57:00Z ship: merged ({ship_commit})\n"
            f"- 2026-08-30T04:59:00Z retro: committed ({retro_commit})\n"
        )
    progress_path.write_text(text, encoding="utf-8")


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


def write_legacy(repo: Path, feature: str = "legacy") -> Path:
    legacy = repo / ".release-loop/progress.md"
    legacy.parent.mkdir(parents=True, exist_ok=True)
    legacy.write_text(progress(feature, ".release-loop"), encoding="utf-8")
    return legacy


def write_legacy_v1(repo: Path, feature: str = "legacy") -> Path:
    legacy = write_legacy(repo, feature)
    root = legacy.parent / "v1"
    root.mkdir()
    for name in ("pilot-approval.md", "full-approval.md", "generation-receipt.md"):
        (root / name).write_text(f"# {name}\n", encoding="utf-8")
    receipt_digests = {}
    for name in ("pilot", "full"):
        prefix = f"# {name} receipt\n\n- verdict: pass\n- receipt_sha256_scope: canonical bytes before this field\n"
        digest = hashlib.sha256(prefix.encode()).hexdigest()
        (root / f"{name}-receipt.md").write_text(
            prefix + f"- receipt_sha256: {digest}\n", encoding="utf-8"
        )
        receipt_digests[name] = digest
    manifest = root / "generation-manifest.sha256"
    manifest.write_text("0" * 64 + "  generated.txt\n", encoding="utf-8")
    generation_digest = hashlib.sha256(manifest.read_bytes()).hexdigest()
    blocks = (
        "v1:\n"
        "  status: accepted\n"
        "  pilot_approval_path: .release-loop/v1/pilot-approval.md\n"
        "  pilot_receipt_path: .release-loop/v1/pilot-receipt.md\n"
        f"  pilot_receipt_sha256: {receipt_digests['pilot']}\n"
        "  full_approval_path: .release-loop/v1/full-approval.md\n"
        "  full_receipt_path: .release-loop/v1/full-receipt.md\n"
        f"  full_receipt_sha256: {receipt_digests['full']}\n"
        "  generation_receipt_path: .release-loop/v1/generation-receipt.md\n"
        "  generation_manifest_path: .release-loop/v1/generation-manifest.sha256\n"
        f"  generation_manifest_sha256: {generation_digest}\n"
        "  accepted_at: 2026-08-23T00:00:00Z\n"
        "pre_merge_verification:\n"
        "  id: V1\n"
        "  status: accepted\n"
        f"  generation_sha256: {generation_digest}\n"
        "  updated: 2026-08-23T00:00:00Z\n"
    )
    legacy.write_text(legacy.read_text(encoding="utf-8").replace("final_action:\n", blocks + "final_action:\n"), encoding="utf-8")
    return legacy


def populate_legacy_active_state(root: Path) -> None:
    (root / ".tmp").mkdir(parents=True, exist_ok=True)
    (root / ".tmp/scratch.tmp").write_text("scratch\n", encoding="utf-8")
    (root / ".phase-artifact-ownership.json").write_text(
        '{"schema":"phase-artifact-ownership/v1","owned":{},"pending":null}\n', encoding="utf-8"
    )
    for name in ("briefs", "reports", "reviews", "evidence"):
        directory = root / name
        directory.mkdir(parents=True, exist_ok=True)
        (directory / f"{name[:-1]}.md").write_text(f"{name}\n", encoding="utf-8")
    (root / "progress.md.corrupt-2026-08-24T000000Z").write_text("corrupt\n", encoding="utf-8")


class Blocked(RuntimeError):
    pass


def is_relative_to(path: Path, root: Path) -> bool:
    try:
        path.relative_to(root)
    except ValueError:
        return False
    return True


def run_cli(
    command: str,
    *args: str,
    failure: str | None = None,
    cli: Path = CLI,
    cwd: Path = ROOT,
    environment_overrides: dict[str, str] | None = None,
) -> dict[str, object]:
    if not cli.is_file():
        raise AssertionError(f"packaged run-artifact CLI absent: {cli}")
    environment = os.environ.copy()
    if environment_overrides is not None:
        environment.update(environment_overrides)
    if failure is not None:
        environment["RUN_ARTIFACT_INTEGRITY_TEST_FAIL"] = failure
    argv = [sys.executable, str(cli), command, *args]
    option_values = {args[index]: args[index + 1] for index in range(len(args) - 1) if args[index].startswith("--")}
    trace_roots = [
        (
            Path(option_values[option])
            if Path(option_values[option]).is_absolute()
            else Path(cwd) / option_values[option]
        ).resolve(strict=True)
        for option in ("--repo", "--base-repo")
        if option in option_values
    ]

    def observe_path(path: Path) -> dict[str, object]:
        if path.is_symlink():
            return {"exists": True, "kind": "symlink", "sha256_or_target": os.readlink(path)}
        if path.is_file():
            return {"exists": True, "kind": "file", "sha256_or_target": hashlib.sha256(path.read_bytes()).hexdigest()}
        if path.is_dir():
            return {"exists": True, "kind": "directory", "sha256_or_target": None}
        return {"exists": False, "kind": "missing", "sha256_or_target": None}

    path_bindings = []
    primary = trace_roots[0] if trace_roots else None
    base = trace_roots[1] if len(trace_roots) > 1 else None
    for option in ("--progress-path", "--source", "--target", "--marker-path", "--destination"):
        if option not in option_values:
            continue
        raw = option_values[option]
        candidate = Path(raw)
        owner = base if option == "--marker-path" and base is not None else primary
        if candidate.is_absolute():
            physical = candidate
            owner = next((root for root in trace_roots if is_relative_to(candidate, root)), None)
        elif owner is not None:
            physical = owner / candidate
        else:
            physical = Path(cwd) / candidate
        if owner is not None and not is_relative_to(physical.resolve(strict=False), owner):
            owner = None
        if owner is None and MATRIX_EXTERNAL_ROOT is not None and is_relative_to(
            physical.resolve(strict=False), MATRIX_EXTERNAL_ROOT
        ):
            owner = MATRIX_EXTERNAL_ROOT
        path_bindings.append({
            "option": option,
            "raw": raw,
            "owner": str(owner) if owner is not None else "external",
            "physical": str(physical),
            "pre": observe_path(physical),
        })
    external_roots = {
        str(binding["owner"])
        for binding in path_bindings
        if binding["owner"] not in {"external", *(str(root) for root in trace_roots)}
    }
    root_pre_state = {str(root): matrix_fixture_snapshot(root) for root in trace_roots}
    root_pre_state.update({root: fixture_root_snapshot(Path(root)) for root in external_roots})
    result = subprocess.run(
        tuple(argv),
        cwd=cwd,
        env=environment,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    for binding in path_bindings:
        binding["post"] = observe_path(Path(str(binding["physical"])))
    root_post_state = {str(root): matrix_fixture_snapshot(root) for root in trace_roots}
    root_post_state.update({root: fixture_root_snapshot(Path(root)) for root in external_roots})
    COMMAND_TRACE.append({
        "argv": argv,
        "cwd": str(cwd),
        "exit_status": result.returncode,
        "path_bindings": path_bindings,
        "root_pre_state": root_pre_state,
        "root_post_state": root_post_state,
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


def fixture_root_snapshot(root: Path) -> dict[str, object]:
    inventory = []
    for path in sorted(root.rglob("*")):
        relative_path = path.relative_to(root)
        if ".git" in relative_path.parts:
            continue
        relative = relative_path.as_posix()
        inventory.append({
            "path": relative,
            "kind": "symlink" if path.is_symlink() else "file" if path.is_file() else "directory",
            "sha256_or_target": (
                os.readlink(path) if path.is_symlink()
                else hashlib.sha256(path.read_bytes()).hexdigest() if path.is_file()
                else None
            ),
        })
    return {"head": None, "index": None, "status": None, "inventory": inventory}


def filesystem_manifest(root: Path) -> dict[str, tuple[str, bytes | str | None]]:
    manifest = {}
    for path in sorted(root.rglob("*")):
        relative = path.relative_to(root).as_posix()
        if path.is_symlink():
            manifest[relative] = ("symlink", os.readlink(path))
        elif path.is_file():
            manifest[relative] = ("file", path.read_bytes())
        else:
            manifest[relative] = ("directory", None)
    return manifest


def fixture_generation_sha256(root: Path, progress_override: bytes | None = None) -> str:
    entries: list[dict[str, object]] = []
    for path in sorted(root.rglob("*")):
        relative = path.relative_to(root).as_posix()
        assert not path.is_symlink(), f"generation contains symlink: {relative}"
        if path.is_dir():
            entries.append({"kind": "directory", "path": relative})
        else:
            data = progress_override if relative == "progress.md" and progress_override is not None else path.read_bytes()
            entries.append({
                "kind": "file",
                "path": relative,
                "sha256": hashlib.sha256(data).hexdigest(),
            })
    encoded = json.dumps({"entries": entries}, sort_keys=True, separators=(",", ":")) + "\n"
    return hashlib.sha256(encoded.encode("utf-8")).hexdigest()


def archive_payload_generation_sha256(manifest_path: Path) -> str:
    raw = manifest_path.read_bytes()
    manifest = json.loads(raw)
    assert manifest.get("schema") == "archive-source-manifest/v1", manifest
    assert isinstance(manifest.get("entries"), list), manifest
    assert raw == (json.dumps(manifest, sort_keys=True, separators=(",", ":")) + "\n").encode("utf-8")
    encoded = json.dumps({"entries": manifest["entries"]}, sort_keys=True, separators=(",", ":")) + "\n"
    return hashlib.sha256(encoded.encode("utf-8")).hexdigest()


def recovery_progress_lines(text: str) -> tuple[str, ...]:
    markers = (
        "retro: archive-destination:",
        "legacy_archive_recovery: staged:",
        "legacy-pre-archive-verification: accepted:",
        "legacy_archive_recovery: completed:",
    )
    return tuple(line for line in text.splitlines() if any(marker in line for marker in markers))


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
    DISPOSABLE_PRE_STATES[str(repo)] = pre_state
    roots = []
    pre_states = {}
    post_states = {}
    target_inventories = {}
    for candidate in DISPOSABLE_REPOS:
        candidate_key = str(candidate)
        candidate_post = matrix_fixture_snapshot(candidate)
        progress_records = sorted(
            path.relative_to(candidate).as_posix()
            for path in (candidate / ".release-loop").glob("**/progress.md")
            if path.is_file()
        ) if (candidate / ".release-loop").is_dir() else []
        roots.append({"kind": "git", "repo": candidate_key, "progress_records": progress_records})
        pre_states[candidate_key] = DISPOSABLE_PRE_STATES[candidate_key]
        post_states[candidate_key] = candidate_post
        target_inventories[candidate_key] = candidate_post["inventory"]
    if MATRIX_EXTERNAL_ROOT is not None:
        external_key = str(MATRIX_EXTERNAL_ROOT)
        external_post = fixture_root_snapshot(MATRIX_EXTERNAL_ROOT)
        roots.append({"kind": "fixture", "repo": external_key, "progress_records": []})
        pre_states[external_key] = MATRIX_EXTERNAL_PRE_STATE
        post_states[external_key] = external_post
        target_inventories[external_key] = external_post["inventory"]
    observation = {
        "schema": "matrix-fixture-observation/v2",
        "case": case,
        "primary_root": str(repo),
        "roots": sorted(roots, key=lambda row: row["repo"]),
        "pre_states": pre_states,
        "post_states": post_states,
        "target_inventories": target_inventories,
        "command_trace": COMMAND_TRACE,
        "boundary_sentinel": {
            "path": str(sent),
            "pre_sha256": hashlib.sha256(before).hexdigest(),
            "post_sha256": hashlib.sha256(after).hexdigest(),
            "unchanged": after == before,
        },
        "stub_identity": "not applicable; disposable local Git and filesystem only",
        "next_invocation": MATRIX_NEXT_INVOCATION or {"action": ["bash", "scripts/test-run-artifact-integrity.sh", case], "exit_status": 0, "result": "probe completed"},
        "mechanism_check": MATRIX_MECHANISM or "all case assertions completed and the boundary sentinel stayed byte-identical",
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


def recovery_gate(repo: Path) -> Path:
    gate = initialize(repo, "gate")
    gate.write_text(
        gate.read_text(encoding="utf-8").replace(
            "phase: implement\nphase_status: in-progress\n",
            "phase: implement\nphase_status: waiting-user\n",
            1,
        ).replace(
            "final_action:\n",
            "recovery_gate:\n"
            "  id: legacy-archive-recovery-approval\n"
            "  issued_at: 2026-08-30T05:00:00Z\n"
            "  expected_answer_class: approve-exact-recovery-or-cancel\n"
            "final_action:\n",
            1,
        ),
        encoding="utf-8",
    )
    return gate


def recovery_archive(
    repo: Path,
    terminal_variant: str = "valid",
    *,
    extra_payload: bool = False,
    install_alternate: bool = True,
    plan_variant: str = "approved",
    frontmatter_variant: str | None = None,
) -> tuple[str, Path]:
    archived_source = initialize(repo, "alpha")
    add_recovery_provenance(
        repo,
        archived_source,
        install_alternate=install_alternate,
        plan_variant=plan_variant,
    )
    add_recovery_terminal_evidence(
        repo,
        archived_source,
        retro_before_ship=terminal_variant == "retro-before-ship",
    )
    text = archived_source.read_text(encoding="utf-8")
    if terminal_variant == "unmerged-ship":
        text = text.replace("merged: true\n", "merged: false\n", 1)
    elif terminal_variant == "unexecuted-final-action":
        text = text.replace("  status: executed\n", "  status: predicted\n", 1)
    elif terminal_variant == "uncommitted-retro":
        uncommitted = repo / "docs/retros/2026-08-30-uncommitted-retro.md"
        uncommitted.write_text("# Uncommitted Retro\n", encoding="utf-8")
        text = text.replace(
            "retro: docs/retros/2026-08-30-fixture-retro.md\n",
            "retro: docs/retros/2026-08-30-uncommitted-retro.md\n",
            1,
        )
    elif terminal_variant == "wrong-final-action-kind":
        text = text.replace("  kind: merge-to-base\n", "  kind: publish-release\n", 1)
    elif terminal_variant == "same-ship-retro-commit":
        ship_match = re.search(r"ship: merged \(([0-9a-f]{40})\)", text)
        assert ship_match is not None
        text = re.sub(
            r"retro: committed \([0-9a-f]{40}\)",
            f"retro: committed ({ship_match.group(1)})",
            text,
            count=1,
        )
    elif terminal_variant == "ship-approval-shape":
        text = text.replace(
            'ship_approved: {by: user, at: 2026-08-30T04:56:00Z, conditions: "CI green, no open P0"}\n',
            "ship_approved: approved\n",
            1,
        )
    elif terminal_variant == "ship-approval-by":
        text = text.replace("ship_approved: {by: user,", "ship_approved: {by: automation,", 1)
    elif terminal_variant == "ship-approval-time":
        text = text.replace(
            "ship_approved: {by: user, at: 2026-08-30T04:56:00Z,",
            "ship_approved: {by: user, at: not-a-timestamp,",
            1,
        )
    elif terminal_variant == "retro-before-ship":
        pass
    elif terminal_variant != "valid":
        raise AssertionError(f"unknown recovery terminal variant: {terminal_variant}")
    if frontmatter_variant is not None:
        field, shape = frontmatter_variant.rsplit("-", 1)
        field_lines = {
            "phase_status": "phase_status: in-progress",
            "merged": "merged: true",
            "branch": "branch: main",
            "base_branch": "base_branch: main",
            "ship_approved": 'ship_approved: {by: user, at: 2026-08-30T04:56:00Z, conditions: "CI green, no open P0"}',
        }
        original = field_lines[field]
        invalid = {
            "phase_status": "complete",
            "merged": "false",
            "branch": "wrong-branch",
            "base_branch": "wrong-base",
            "ship_approved": "approved",
        }[field]
        if shape == "nested":
            text = text.replace(original + "\n", f"shadow_{field}:\n  {field}: {invalid}\n", 1)
        elif shape == "duplicate":
            text = text.replace(original + "\n", original + f"\n{field}: {invalid}\n", 1)
        else:
            raise AssertionError(f"unknown frontmatter shape: {shape}")
    archived_source.write_text(text, encoding="utf-8")
    if extra_payload:
        reports = archived_source.parent / "reports"
        reports.mkdir()
        (reports / "evidence.md").write_bytes(b"RECOVERY PAYLOAD\n")
    destination = ".release-loop/archive/2026-08-30-alpha-incomplete"
    archive_scope(repo, str(archived_source.relative_to(repo)), destination, mode="incomplete")
    return destination, recovery_gate(repo)


def prepare_recovery_for_restore(
    repo: Path,
    recovery_id: str,
) -> tuple[str, Path, Path]:
    destination, gate = recovery_archive(repo)
    run_cli(
        "request-legacy-archive", "--repo", str(repo), "--recovery-id", recovery_id,
        "--progress-path", f"{destination}/progress.md", "--gate-progress-path",
        str(gate.relative_to(repo)), "--session", "fixture-session",
    )
    authority = repo / f".release-loop/recovery-authority/{recovery_id}"
    approve_recovery_fixture(repo, recovery_id, authority, gate)
    run_cli("backup-legacy-archive", "--repo", str(repo), "--recovery-id", recovery_id)
    run_cli("audit-legacy-archive", "--repo", str(repo), "--recovery-id", recovery_id)
    backup = repo / f".release-loop/recovery-backups/{recovery_id}"
    return destination, authority, backup


def approve_recovery_fixture(
    repo: Path,
    recovery_id: str,
    authority: Path,
    gate: Path,
) -> None:
    write_recovery_gate_approval_fixture(authority, gate)
    run_cli("request-legacy-archive", "--repo", str(repo), "--recovery-id", recovery_id, "--publish-approval")


def write_recovery_gate_approval_fixture(authority: Path, gate: Path) -> None:
    gate.write_text(
        gate.read_text(encoding="utf-8").replace(
            "final_action:\n",
            "recovery_gate_receipt:\n"
            "  gate_id: legacy-archive-recovery-approval\n"
            "  gate_issued_at: 2026-08-30T05:00:00Z\n"
            "  answer: approved\n"
            "  session: fixture-session\n"
            "  nonce: fixture-nonce\n"
            f"  request_sha256: {hashlib.sha256((authority / 'request.json').read_bytes()).hexdigest()}\n"
            "  reserved_at: 2026-08-30T05:01:00Z\n"
            "final_action:\n",
            1,
        ),
        encoding="utf-8",
    )


def audit_rejected_recovery_fixture(
    repo: Path,
    recovery_id: str,
    destination: str,
    gate: Path,
) -> tuple[Path, Path]:
    requested = run_cli(
        "request-legacy-archive", "--repo", str(repo), "--recovery-id", recovery_id,
        "--progress-path", f"{destination}/progress.md",
        "--gate-progress-path", str(gate.relative_to(repo)), "--session", "fixture-session",
    )
    assert requested == {"recovery_id": recovery_id, "state": "requested"}, requested
    authority = repo / f".release-loop/recovery-authority/{recovery_id}"
    backup = repo / f".release-loop/recovery-backups/{recovery_id}"
    approve_recovery_fixture(repo, recovery_id, authority, gate)
    backed_up = run_cli(
        "backup-legacy-archive", "--repo", str(repo), "--recovery-id", recovery_id,
    )
    assert backed_up["state"] == "backed-up", backed_up
    audited = run_cli(
        "audit-legacy-archive", "--repo", str(repo), "--recovery-id", recovery_id,
    )
    assert audited["state"] == "audited", audited
    assert audited["verdict"] == "rejected", audited
    audit = json.loads((authority / "audit.json").read_bytes())
    assert audit["schema"] == "legacy-archive-recovery-audit/v1", audit
    assert audit["verdict"] == "rejected", audit
    return authority, backup


def handoff_scope(
    repo: Path,
    base_repo: Path,
    progress_path: str,
    marker_path: str | None = None,
    fail_after_marker: bool = False,
    legacy_destination: str | None = None,
    failure: str | None = None,
) -> dict[str, object]:
    args = [
        "--repo", str(repo),
        "--base-repo", str(base_repo),
        "--progress-path", progress_path,
    ]
    if marker_path is not None:
        args.extend(("--marker-path", marker_path))
    if legacy_destination is not None:
        args.extend(("--legacy-destination", legacy_destination))
    selected_failure = failure or ("handoff-after-marker" if fail_after_marker else None)
    payload = run_cli(
        "handoff",
        *args,
        failure=selected_failure,
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


def assert_blocked_snapshots(action, source: Path, base: Path, diagnostic: str) -> None:
    source_before = matrix_fixture_snapshot(source)
    base_before = matrix_fixture_snapshot(base)
    try:
        action()
    except Blocked as exc:
        assert diagnostic in str(exc), str(exc)
    else:
        raise AssertionError("attack did not block")
    assert matrix_fixture_snapshot(source) == source_before
    assert matrix_fixture_snapshot(base) == base_before


def require_phase_consumer_contract(texts: dict[str, str] | None = None) -> None:
    selected = texts or PHASE_CONSUMERS
    shared = ("exact repo-relative `progress_path`", "`artifact_root = dirname(progress_path)`")
    missing = [f"{name}: {fragment}" for name, text in selected.items() for fragment in shared if fragment not in text]
    required = (
        (selected["planning"], "<artifact_root>/evidence/U<N>/"),
        (selected["implementing"], "<artifact_root>/briefs/U<N>-brief.md"),
        (selected["implementing"], "<artifact_root>/reports/U<N>-report.md"),
        (selected["implementing"], "<artifact_root>/reviews/U<N>-diff.txt"),
        (selected["implementing"], "<artifact_root>/.tmp/U<N>-brief.tmp"),
        (selected["implementing"], "<artifact_root>/.tmp/U<N>-report.tmp"),
        (selected["implementing"], "<artifact_root>/.tmp/U<N>-<transition-id>-<outcome>.tmp"),
        (selected["implementing"], "<artifact_root>/.tmp/U<N>-diff.tmp"),
        (selected["implementing"], "<artifact_root>/.tmp/branch-diff.tmp"),
        (selected["implementing"], "publish each temporary artifact"),
        (selected["reviewing"], "<artifact_root>/evidence/U<N>/"),
        (selected["shipping"], "cleanup_permitted: true"),
        (selected["shipping"], ".release-loop/.handoff/<feature>.json"),
        (selected["shipping"], "exact base discovery of `.release-loop/progress.md`"),
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
        (MERGE_PIPELINE, "temporary path under `<artifact_root>/.tmp/`"),
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


def run_matrix_probe(name: str, tmp: Path, sent: Path, before: bytes) -> None:
    global MATRIX_MECHANISM, MATRIX_NEXT_INVOCATION, MATRIX_EXTERNAL_ROOT, MATRIX_EXTERNAL_PRE_STATE
    _, transition, outcome_token = name.split("_", 2)
    outcome = outcome_token.replace("_", "-")

    def blocked(action, diagnostic: str) -> str:
        try:
            action()
        except Blocked as exc:
            assert diagnostic in str(exc), str(exc)
            return str(exc)
        raise AssertionError(f"{transition}/{outcome} did not block")

    if transition == "T3":
        repo = new_history_repo(tmp, conflict=outcome in {"forced-failure", "compensation"})
    else:
        repo = new_repo(tmp)
    pre_state = matrix_fixture_snapshot(repo)
    MATRIX_EXTERNAL_ROOT = tmp.resolve(strict=True)
    MATRIX_EXTERNAL_PRE_STATE = fixture_root_snapshot(MATRIX_EXTERNAL_ROOT)

    if transition == "T1":
        if outcome == "success":
            path = initialize(repo, "alpha")
            assert path.is_file() and not (repo / ".release-loop/progress.md").exists()
            MATRIX_MECHANISM = "T1-v3 success created one exact scoped progress record and no legacy record"
        elif outcome == "forced-failure":
            occupied = repo / ".release-loop/runs/alpha/occupied.txt"
            occupied.parent.mkdir(parents=True)
            occupied.write_bytes(b"occupied\n")
            blocked(lambda: prepare_scope(repo, "alpha"), "artifact scope collision")
            assert not (occupied.parent / "progress.md").exists()
            MATRIX_MECHANISM = "T1-v3 forced failure rejected an occupied scope before progress publication"
        elif outcome == "rerun":
            path, state = prepare_scope(repo, "alpha")
            assert state == "new" and path.parent.is_dir() and not any(path.parent.iterdir())
            assert prepare_scope(repo, "alpha") == (path, "new")
            path.write_text(progress("alpha", ".release-loop/runs/alpha"), encoding="utf-8")
            assert prepare_scope(repo, "alpha") == (path, "resume")
            MATRIX_MECHANISM = "T1-v3 rerun reused the same empty scope and then resumed one published record"
        elif outcome == "compensation":
            path, state = prepare_scope(repo, "alpha")
            assert state == "new" and not path.exists() and not any(path.parent.iterdir())
            path.parent.rmdir()
            assert not path.parent.exists() and not (repo / ".release-loop/progress.md").exists()
            MATRIX_MECHANISM = "T1-v3 compensation removed only the proven empty pre-publication scope"
        elif outcome == "headless":
            initialize(repo, "alpha")
            initialize(repo, "beta")
            blocked(lambda: discover(repo), "multiple valid live records")
            assert len(list((repo / ".release-loop/runs").glob("*/progress.md"))) == 2
            MATRIX_MECHANISM = "T1-v3 headless selection blocked on two valid records without choosing either"
        else:
            path, state = prepare_scope(repo, "alpha")
            assert state == "new" and not path.exists()
            path.parent.rmdir()
            assert not path.parent.exists()
            retry_path, retry_state = prepare_scope(repo, "alpha")
            assert retry_path == path and retry_state == "new" and not retry_path.exists()
            MATRIX_MECHANISM = "T1-v3 cancellation removed only the empty scope and the same scope prepared again"

    elif transition == "T6":
        path = initialize(repo, "alpha")
        root = path.parent
        if outcome == "success":
            payload = publish_from_cli(repo, path, "reports/U1.md", b"success\n", CLI)
            assert payload["state"] == "published" and (root / "reports/U1.md").is_file()
            MATRIX_MECHANISM = "T6-v3 success published one journal-owned sibling under the selected root"
        elif outcome == "forced-failure":
            target = root / "reports/U1.md"
            target.parent.mkdir()
            target.write_bytes(b"tracked\n")
            git(repo, "add", "-f", target.relative_to(repo).as_posix())
            blocked(lambda: publish_from_cli(repo, path, "reports/U1.md", b"new\n", CLI), "artifact target collision")
            assert target.read_bytes() == b"tracked\n"
            MATRIX_MECHANISM = "T6-v3 forced failure preserved a tracked sibling collision byte-for-byte"
        elif outcome == "rerun":
            first = publish_from_cli(repo, path, "reports/U1.md", b"same\n", CLI)
            second = publish_from_cli(repo, path, "reports/U1.md", b"same\n", CLI)
            assert first["sha256"] == second["sha256"] and second["state"] == "reused"
            MATRIX_MECHANISM = "T6-v3 rerun reused one matching owned final without allocating another target"
        elif outcome == "compensation":
            blocked(
                lambda: publish_from_cli(repo, path, "reports/U1.md", b"pending\n", CLI, "publish-after-prepare"),
                "injected publish interruption",
            )
            result = run_cli("compensate", "--repo", str(repo), "--progress-path", path.relative_to(repo).as_posix())
            assert result["state"] == "compensated" and not (root / "reports/U1.md").exists()
            MATRIX_MECHANISM = "T6-v3 compensation removed only the journal-bound pending source"
        elif outcome == "headless":
            source = root / ".tmp/headless.tmp"
            source.parent.mkdir()
            source.write_bytes(b"headless\n")
            blocked(
                lambda: run_cli(
                    "publish", "--repo", str(repo),
                    "--progress-path", ".release-loop/progress.md",
                    "--source", source.relative_to(repo).as_posix(),
                    "--target", (root / "reports/U1.md").relative_to(repo).as_posix(),
                ),
                "invalid progress",
            )
            assert source.is_file() and not (root / "reports/U1.md").exists()
            MATRIX_MECHANISM = "T6-v3 headless publication blocked on the missing exact progress path before sibling write"
        else:
            source = root / ".tmp/cancelled.tmp"
            source.parent.mkdir()
            source.write_bytes(b"cancelled\n")
            source.unlink()
            assert not (root / "reports/U1.md").exists() and not (root / ".phase-artifact-ownership.json").exists()
            MATRIX_MECHANISM = "T6-v3 cancellation before prepare left no journal, temporary source, or final"

    elif transition == "T2":
        path = initialize(repo, "alpha")
        reviews = ReviewFixture(repo, path)
        head = git(repo, "rev-parse", "HEAD")
        event = reviews.allocate("unit", "U1", head)
        if outcome == "success":
            reviews.complete(str(event["id"]), reviewer_output("clean"))
            assert event["state"] == "complete" and reviews.counts()["unit_passes"] == 1
            MATRIX_MECHANISM = "T2-v3 success sealed one result and completed the reserved event once"
        elif outcome == "forced-failure":
            final = reviews._result_path(event)
            final.parent.mkdir(parents=True, exist_ok=True)
            final.write_bytes(b"foreign-result\n")
            blocked(lambda: reviews.complete(str(event["id"]), reviewer_output("clean")), "review-event-conflict")
            assert event["state"] == "started" and reviews.counts()["unit_passes"] == 0
            MATRIX_MECHANISM = "T2-v3 forced failure kept the event started when a foreign final occupied its path"
        elif outcome == "rerun":
            assert reviews.recover(str(event["id"])) == "redispatch"
            replay = reviews.allocate("unit", "U1", head)
            assert replay is event and len(reviews.events) == 1
            reviews.complete(str(event["id"]), reviewer_output("clean"))
            MATRIX_MECHANISM = "T2-v3 rerun redispatched the same started ID and completed it once"
        elif outcome == "compensation":
            temporary = path.parent / ".tmp/unit-U1-1.tmp"
            temporary.parent.mkdir(exist_ok=True)
            temporary.write_bytes(b"owned-temporary\n")
            temporary.unlink()
            assert event["state"] == "started" and not reviews._result_path(event).exists()
            MATRIX_MECHANISM = "T2-v3 compensation removed only the event temporary and preserved the started event"
        elif outcome == "headless":
            before_counts = reviews.counts()
            assert reviews.recover(str(event["id"])) == "redispatch"
            assert event["state"] == "started" and reviews.counts() == before_counts
            MATRIX_MECHANISM = "T2-v3 headless missing-worker output returned redispatch with the event still started"
        else:
            assert event["state"] == "started" and reviews.counts()["unit_passes"] == 0
            assert not reviews._result_path(event).exists()
            assert reviews.recover(str(event["id"])) == "redispatch"
            MATRIX_MECHANISM = "T2-v3 cancellation preserved the started event and its next recovery returned redispatch"

    elif transition == "T3":
        path = initialize(repo, "alpha")
        history = HistoryFixture(repo, path, "main", "matrix-v3-session")
        command = 'git rebase --onto "origin/main" "main" "feat/fixture"'
        old_range = dict(history.current_commit_range)
        if outcome == "success":
            approval = history.approve(command, "origin/main")
            result = history.rewrite(command, "origin/main")
            assert approval["state"] == "consumed" and result["state"] == "success"
            assert history.current_commit_range != old_range
            MATRIX_MECHANISM = "T3-v3 success persisted approval before rewrite and refreshed the verified range"
        elif outcome == "forced-failure":
            history.approve(command, "origin/main")
            result = history.rewrite(command, "origin/main")
            assert result["state"] == "failed" and history.current_commit_range == old_range == history.git_range()
            MATRIX_MECHANISM = "T3-v3 forced failure aborted the conflict and retained the exact old range"
        elif outcome == "rerun":
            cancelled = history.approve(command, "origin/main")
            history.cancel(str(cancelled["id"]))
            fresh = history.approve(command, "origin/main")
            assert fresh["id"] != cancelled["id"]
            result = history.rewrite(command, "origin/main")
            assert result["state"] == "success"
            MATRIX_MECHANISM = "T3-v3 rerun required fresh approval after cancellation and then succeeded"
        elif outcome == "compensation":
            history.approve(command, "origin/main")
            result = history.rewrite(command, "origin/main")
            assert result["state"] == "failed" and git(repo, "status", "--porcelain") == ""
            assert history.current_commit_range == old_range
            MATRIX_MECHANISM = "T3-v3 compensation ran the exact abort and verified the unchanged old range"
        elif outcome == "headless":
            blocked(lambda: history.rewrite(command, "origin/main"), "stale-commit-range")
            assert history.command_calls == 0 and history.current_commit_range == old_range
            MATRIX_MECHANISM = "T3-v3 headless rewrite blocked before command execution without USER approval"
        else:
            approval = history.approve(command, "origin/main")
            result = history.cancel(str(approval["id"]))
            assert result["state"] == "cancelled" and history.command_calls == 0
            assert history.current_commit_range == old_range
            MATRIX_MECHANISM = "T3-v3 cancellation recorded a terminal result without executing the rewrite"

    elif transition == "T4":
        path = initialize(repo, "alpha")
        publish_phase_artifact(repo, path, "reports/U1.md", b"handoff\n")
        base = new_repo(tmp, "handoff-base")
        if outcome == "success":
            result = handoff_scope(repo, base, path.relative_to(repo).as_posix())
            assert result["cleanup_permitted"] and (base / path.relative_to(repo)).is_file()
            MATRIX_MECHANISM = "T4-v3 success transferred the exact scope and permitted source cleanup"
        elif outcome == "forced-failure":
            outside = tmp / "handoff-outside"
            outside.mkdir()
            release_root = base / ".release-loop"
            release_root.mkdir()
            (release_root / "runs").symlink_to(outside, target_is_directory=True)
            blocked(lambda: handoff_scope(repo, base, path.relative_to(repo).as_posix()), "path boundary")
            assert path.is_file() and not any(outside.iterdir())
            MATRIX_MECHANISM = "T4-v3 forced failure rejected a symlinked base-owner destination before transfer"
        elif outcome == "rerun":
            blocked(
                lambda: handoff_scope(repo, base, path.relative_to(repo).as_posix(), fail_after_marker=True),
                "injected handoff interruption",
            )
            result = handoff_scope(repo, base, path.relative_to(repo).as_posix())
            assert result["cleanup_permitted"]
            MATRIX_MECHANISM = "T4-v3 rerun reused the exact owner marker and completed the partial transfer"
        elif outcome == "compensation":
            target = base / path.relative_to(repo)
            target.parent.mkdir(parents=True)
            target.write_text(progress("alpha", ".release-loop/runs/alpha") + "mismatch\n", encoding="utf-8")
            blocked(lambda: handoff_scope(repo, base, path.relative_to(repo).as_posix()), "handoff target mismatch")
            assert path.is_file() and target.is_file()
            MATRIX_MECHANISM = "T4-v3 compensation preserved source and mismatched destination for manual recovery"
        elif outcome == "headless":
            result = handoff_scope(repo, base, path.relative_to(repo).as_posix())
            marker = json.loads(result["marker"].read_text(encoding="utf-8"))
            assert marker["source_worktree"] == str(repo) and result["cleanup_permitted"]
            MATRIX_MECHANISM = "T4-v3 headless local handoff proved both owners and completed without an outward target"
        else:
            blocked(
                lambda: handoff_scope(repo, base, path.relative_to(repo).as_posix(), fail_after_marker=True),
                "injected handoff interruption",
            )
            assert path.is_file() and (base / ".release-loop/.handoff/alpha.json").is_file()
            resumed = handoff_scope(repo, base, path.relative_to(repo).as_posix())
            assert resumed["cleanup_permitted"]
            MATRIX_MECHANISM = "T4-v3 cancellation retained the source and the same owner marker resumed successfully"

    else:
        path = initialize(repo, "alpha")
        publish_phase_artifact(repo, path, "reports/U1.md", b"archive\n")
        destination = ".release-loop/archive/2026-08-24-matrix-v3-" + outcome
        if outcome == "forced-failure":
            persist_archive_evidence(path, destination, "completed")
            outside = tmp / "archive-outside"
            outside.mkdir()
            archive_root = repo / ".release-loop/archive"
            archive_root.symlink_to(outside, target_is_directory=True)
            blocked(
                lambda: archive_scope(repo, path.relative_to(repo).as_posix(), destination, persist_authority=False),
                "path boundary",
            )
            assert path.is_file() and not any(outside.iterdir())
            MATRIX_MECHANISM = "T5-v3 forced failure rejected a symlinked archive destination before a move"
        elif outcome in {"rerun", "compensation", "cancellation"}:
            persist_archive_evidence(path, destination, "completed")
            blocked(
                lambda: archive_scope(
                    repo, path.relative_to(repo).as_posix(), destination,
                    fail_after_first=True, persist_authority=False,
                ),
                "injected archive interruption",
            )
            assert path.is_file()
            if outcome == "cancellation":
                assert archive_scope(repo, path.relative_to(repo).as_posix(), None)[-1] == "progress.md"
                MATRIX_MECHANISM = "T5-v3 cancellation left progress as commit point and the same destination resumed successfully"
            else:
                assert archive_scope(repo, path.relative_to(repo).as_posix(), None)[-1] == "progress.md"
                MATRIX_MECHANISM = (
                    "T5-v3 rerun reused the persisted destination and moved only remaining children"
                    if outcome == "rerun"
                    else "T5-v3 compensation finished the same terminal destination without reverse movement"
                )
        else:
            archive_scope(repo, path.relative_to(repo).as_posix(), destination)
            assert not path.exists() and (repo / destination / "progress.md").is_file()
            MATRIX_MECHANISM = (
                "T5-v3 success moved progress last into one exact complete archive"
                if outcome == "success"
                else "T5-v3 headless local archive completed after exact root and destination validation"
            )

    if transition == "T2":
        MATRIX_NEXT_INVOCATION = {
            "action": "recover or resume " + str(event["id"]),
            "exit_status": 0,
            "result": MATRIX_MECHANISM,
        }
    elif transition == "T3":
        MATRIX_NEXT_INVOCATION = {
            "action": command,
            "exit_status": 1 if outcome in {"forced-failure", "compensation", "headless"} else 0,
            "result": MATRIX_MECHANISM,
        }
    elif transition == "T6" and outcome == "cancellation":
        MATRIX_NEXT_INVOCATION = {
            "action": "resume with the same exact progress path after cancellation",
            "exit_status": 0,
            "result": MATRIX_MECHANISM,
        }
    elif COMMAND_TRACE:
        trace = COMMAND_TRACE[-1]
        MATRIX_NEXT_INVOCATION = {
            "action": trace["argv"],
            "exit_status": trace["exit_status"],
            "result": (trace["stdout"] or trace["stderr"] or MATRIX_MECHANISM)[-1000:],
        }
    else:
        MATRIX_NEXT_INVOCATION = {
            "action": ["bash", "scripts/test-run-artifact-integrity.sh", name],
            "exit_status": 0,
            "result": MATRIX_MECHANISM,
        }
    assert sent.read_bytes() == before
    write_matrix_observation(name, repo, pre_state, sent, before)


def run_case(name: str) -> None:
    global MATRIX_MECHANISM, MATRIX_NEXT_INVOCATION, MATRIX_EXTERNAL_ROOT, MATRIX_EXTERNAL_PRE_STATE
    COMMAND_TRACE.clear()
    DISPOSABLE_REPOS.clear()
    DISPOSABLE_PRE_STATES.clear()
    MATRIX_MECHANISM = ""
    MATRIX_NEXT_INVOCATION = {}
    MATRIX_EXTERNAL_ROOT = None
    MATRIX_EXTERNAL_PRE_STATE = {}
    require_contract(check_invocations=name == "operative_contract_mutation")
    with tempfile.TemporaryDirectory(prefix=f"run-artifact-{name}-") as tmp_name:
        tmp = Path(tmp_name)
        sent, before = sentinel(tmp)
        if name in MATRIX_PROBE_CASES:
            run_matrix_probe(name, tmp, sent, before)
            return
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
        elif name == "archive_journal_resume_tamper":
            for mode in ("legacy", "scoped"):
                candidate = new_repo(tmp, "journal-tamper-" + mode)
                if mode == "legacy":
                    candidate_progress = candidate / ".release-loop/progress.md"
                    candidate_progress.parent.mkdir()
                    candidate_progress.write_text(progress("legacy", ".release-loop"), encoding="utf-8")
                else:
                    candidate_progress = initialize(candidate, "alpha")
                publish_from_cli(candidate, candidate_progress, "reports/U1.md", b"owned-before-archive\n", CLI)
                destination = ".release-loop/archive/2026-08-24-journal-tamper-" + mode
                persist_archive_evidence(candidate_progress, destination, "completed")
                result = subprocess.run(
                    (
                        sys.executable, str(CLI), "archive",
                        "--repo", str(candidate),
                        "--progress-path", candidate_progress.relative_to(candidate).as_posix(),
                        "--destination", destination,
                    ),
                    cwd=ROOT,
                    env={**os.environ, "RUN_ARTIFACT_INTEGRITY_TEST_FAIL": "archive-after-journal"},
                    text=True,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE,
                    check=False,
                )
                assert result.returncode != 0 and "injected archive interruption" in result.stderr
                archived_journal = candidate / destination / ".phase-artifact-ownership.json"
                source_final = candidate_progress.parent / "reports/U1.md"
                assert archived_journal.is_file() and source_final.is_file() and candidate_progress.is_file()
                source_final.write_bytes(b"tampered-after-journal\n")
                progress_before = candidate_progress.read_bytes()
                assert_blocked_preserves(
                    lambda candidate=candidate, candidate_progress=candidate_progress, destination=destination: archive_scope(
                        candidate,
                        candidate_progress.relative_to(candidate).as_posix(),
                        destination,
                        persist_authority=False,
                    ),
                    sent,
                    before,
                    "owned final invalid",
                )
                assert candidate_progress.read_bytes() == progress_before
                assert archived_journal.is_file()
                source_final.write_bytes(b"owned-before-archive\n")
                assert archive_scope(
                    candidate,
                    candidate_progress.relative_to(candidate).as_posix(),
                    destination,
                    persist_authority=False,
                )[-1] == "progress.md"
                assert (candidate / destination / "reports/U1.md").is_file()
        elif name == "archive_destination_foreign_entry":
            for mode in ("legacy", "scoped"):
                candidate = new_repo(tmp, "archive-foreign-" + mode)
                if mode == "legacy":
                    candidate_progress = candidate / ".release-loop/progress.md"
                    candidate_progress.parent.mkdir()
                    candidate_progress.write_text(progress("legacy", ".release-loop"), encoding="utf-8")
                else:
                    candidate_progress = initialize(candidate, "alpha")
                publish_from_cli(candidate, candidate_progress, "reports/U1.md", b"owned\n", CLI)
                destination = ".release-loop/archive/2026-08-24-foreign-" + mode
                persist_archive_evidence(candidate_progress, destination, "completed")
                destination_path = candidate / destination
                destination_path.mkdir(parents=True)
                forged_manifest = destination_path / ".archive-source-manifest.json"
                forged_manifest.write_text(
                    json.dumps({"entries": [], "schema": "archive-source-manifest/v1"}, sort_keys=True, separators=(",", ":")) + "\n",
                    encoding="utf-8",
                )
                assert_blocked_preserves(
                    lambda candidate=candidate, candidate_progress=candidate_progress, destination=destination: archive_scope(
                        candidate,
                        candidate_progress.relative_to(candidate).as_posix(),
                        destination,
                        persist_authority=False,
                    ),
                    sent,
                    before,
                    "archive manifest ownership",
                )
                forged_manifest.unlink()
                foreign = destination_path / "foreign.md"
                foreign.write_bytes(b"FOREIGN\n")
                progress_before = candidate_progress.read_bytes()
                assert_blocked_preserves(
                    lambda candidate=candidate, candidate_progress=candidate_progress, destination=destination: archive_scope(
                        candidate,
                        candidate_progress.relative_to(candidate).as_posix(),
                        destination,
                        persist_authority=False,
                    ),
                    sent,
                    before,
                    "archive destination conflict",
                )
                assert candidate_progress.read_bytes() == progress_before
                assert foreign.read_bytes() == b"FOREIGN\n"
                foreign.unlink()
                destination_path.rmdir()
                try:
                    archive_scope(
                        candidate,
                        candidate_progress.relative_to(candidate).as_posix(),
                        destination,
                        fail_after_first=True,
                        persist_authority=False,
                    )
                except Blocked as exc:
                    assert "injected archive interruption" in str(exc)
                else:
                    raise AssertionError("archive did not interrupt after manifest creation")
                manifest = destination_path / ".archive-source-manifest.json"
                assert manifest.is_file() and candidate_progress.is_file()
                progress_bytes = candidate_progress.read_bytes()
                manifest_bytes = manifest.read_bytes()
                coordinated_progress = progress_bytes + b"\n# COORDINATED TAMPER\n"
                coordinated_manifest = json.loads(manifest_bytes)
                progress_row = next(row for row in coordinated_manifest["entries"] if row["path"] == "progress.md")
                progress_row["sha256"] = hashlib.sha256(coordinated_progress).hexdigest()
                candidate_progress.write_bytes(coordinated_progress)
                manifest.write_text(json.dumps(coordinated_manifest, sort_keys=True, separators=(",", ":")) + "\n", encoding="utf-8")
                assert_blocked_preserves(
                    lambda candidate=candidate, candidate_progress=candidate_progress: archive_scope(
                        candidate,
                        candidate_progress.relative_to(candidate).as_posix(),
                        None,
                        persist_authority=False,
                    ),
                    sent,
                    before,
                    "owned final invalid .archive-source-manifest.json",
                )
                candidate_progress.write_bytes(progress_bytes)
                manifest.write_bytes(manifest_bytes)
                candidate_progress.write_bytes(progress_bytes + b"\n# TAMPERED BODY\n")
                assert_blocked_preserves(
                    lambda candidate=candidate, candidate_progress=candidate_progress: archive_scope(
                        candidate,
                        candidate_progress.relative_to(candidate).as_posix(),
                        None,
                        persist_authority=False,
                    ),
                    sent,
                    before,
                    "archive destination conflict",
                )
                candidate_progress.write_bytes(progress_bytes)
                missing_progress = candidate_progress.with_name("progress.md.missing")
                candidate_progress.rename(missing_progress)
                assert_blocked_preserves(
                    lambda candidate=candidate, candidate_progress=candidate_progress: archive_scope(
                        candidate,
                        candidate_progress.relative_to(candidate).as_posix(),
                        None,
                        persist_authority=False,
                    ),
                    sent,
                    before,
                    "invalid progress",
                )
                missing_progress.rename(candidate_progress)
                duplicate_progress = destination_path / "progress.md"
                duplicate_progress.write_bytes(progress_bytes)
                assert_blocked_preserves(
                    lambda candidate=candidate, candidate_progress=candidate_progress: archive_scope(
                        candidate,
                        candidate_progress.relative_to(candidate).as_posix(),
                        None,
                        persist_authority=False,
                    ),
                    sent,
                    before,
                    "archive destination conflict",
                )
                duplicate_progress.unlink()
                foreign.write_bytes(b"FOREIGN-AFTER-INTERRUPTION\n")
                assert_blocked_preserves(
                    lambda candidate=candidate, candidate_progress=candidate_progress: archive_scope(
                        candidate,
                        candidate_progress.relative_to(candidate).as_posix(),
                        None,
                        persist_authority=False,
                    ),
                    sent,
                    before,
                    "archive destination conflict",
                )
                foreign.unlink()
                assert archive_scope(
                    candidate,
                    candidate_progress.relative_to(candidate).as_posix(),
                    None,
                    persist_authority=False,
                )[-1] == "progress.md"
        elif name == "archive_manifest_pending_recovery":
            for mode in ("legacy", "scoped"):
                for failure in ("archive-after-manifest-prepare", "archive-after-manifest-final"):
                    candidate = new_repo(tmp, "manifest-pending-" + mode + "-" + failure)
                    if mode == "legacy":
                        candidate_progress = candidate / ".release-loop/progress.md"
                        candidate_progress.parent.mkdir()
                        candidate_progress.write_text(progress("legacy", ".release-loop"), encoding="utf-8")
                    else:
                        candidate_progress = initialize(candidate, "alpha")
                    publish_from_cli(candidate, candidate_progress, "reports/U1.md", b"owned\n", CLI)
                    destination = ".release-loop/archive/2026-08-24-" + mode + "-" + failure
                    persist_archive_evidence(candidate_progress, destination, "completed")
                    interrupted = subprocess.run(
                        (
                            sys.executable,
                            str(CLI),
                            "archive",
                            "--repo",
                            str(candidate),
                            "--progress-path",
                            candidate_progress.relative_to(candidate).as_posix(),
                            "--destination",
                            destination,
                        ),
                        cwd=ROOT,
                        env={**os.environ, "RUN_ARTIFACT_INTEGRITY_TEST_FAIL": failure},
                        text=True,
                        stdout=subprocess.PIPE,
                        stderr=subprocess.PIPE,
                        check=False,
                    )
                    assert interrupted.returncode != 0 and "injected archive interruption" in interrupted.stderr
                    source_root = candidate_progress.parent
                    destination_path = candidate / destination
                    source_manifest = source_root / ".tmp/archive-source-manifest.tmp"
                    final_manifest = destination_path / ".archive-source-manifest.json"
                    journal = json.loads((source_root / ".phase-artifact-ownership.json").read_text(encoding="utf-8"))
                    assert journal["pending"]["source"] == ".tmp/archive-source-manifest.tmp"
                    assert journal["pending"]["target"] == ".archive-source-manifest.json"
                    if failure == "archive-after-manifest-prepare":
                        assert source_manifest.is_file() and not final_manifest.exists()
                    else:
                        assert not source_manifest.exists() and final_manifest.is_file()
                    assert archive_scope(
                        candidate,
                        candidate_progress.relative_to(candidate).as_posix(),
                        None,
                        persist_authority=False,
                    )[-1] == "progress.md"
                    archived_journal = json.loads((destination_path / ".phase-artifact-ownership.json").read_text(encoding="utf-8"))
                    assert archived_journal["pending"] is None
                    assert archived_journal["owned"][".archive-source-manifest.json"] == hashlib.sha256(final_manifest.read_bytes()).hexdigest()
        elif name == "archive_progress_commit_recovery":
            for mode in ("legacy", "scoped"):
                candidate = new_repo(tmp, "progress-commit-" + mode)
                if mode == "legacy":
                    candidate_progress = candidate / ".release-loop/progress.md"
                    candidate_progress.parent.mkdir()
                    candidate_progress.write_text(progress("legacy", ".release-loop"), encoding="utf-8")
                else:
                    candidate_progress = initialize(candidate, "alpha")
                publish_from_cli(candidate, candidate_progress, "reports/U1.md", b"owned\n", CLI)
                destination = ".release-loop/archive/2026-08-24-progress-commit-" + mode
                persist_archive_evidence(candidate_progress, destination, "completed")
                progress_relative = candidate_progress.relative_to(candidate).as_posix()
                source_root = candidate_progress.parent
                assert archive_scope(
                    candidate,
                    progress_relative,
                    destination,
                    persist_authority=False,
                )[-1] == "progress.md"
                archived_progress = candidate / destination / "progress.md"
                progress_bytes = archived_progress.read_bytes()
                if mode == "scoped":
                    source_root.mkdir(parents=True)
                assert_blocked_preserves(
                    lambda candidate=candidate, progress_relative=progress_relative: archive_scope(
                        candidate,
                        progress_relative,
                        None,
                        persist_authority=False,
                    ),
                    sent,
                    before,
                    "invalid progress",
                )
                archived_progress.write_bytes(progress_bytes + b"\n# TAMPERED AFTER COMMIT\n")
                assert_blocked_preserves(
                    lambda candidate=candidate, progress_relative=progress_relative, destination=destination: archive_scope(
                        candidate,
                        progress_relative,
                        destination,
                        persist_authority=False,
                    ),
                    sent,
                    before,
                    "archive destination conflict",
                )
                archived_progress.write_bytes(progress_bytes)
                if mode == "scoped":
                    foreign = source_root / "foreign.md"
                    foreign.write_bytes(b"FOREIGN\n")
                    assert_blocked_preserves(
                        lambda candidate=candidate, progress_relative=progress_relative, destination=destination: archive_scope(
                            candidate,
                            progress_relative,
                            destination,
                            persist_authority=False,
                        ),
                        sent,
                        before,
                        "archive destination conflict",
                    )
                    foreign.unlink()
                    source_root.rmdir()
                    source_root.write_bytes(b"FOREIGN ROOT\n")
                    assert_blocked_preserves(
                        lambda candidate=candidate, progress_relative=progress_relative, destination=destination: archive_scope(
                            candidate,
                            progress_relative,
                            destination,
                            persist_authority=False,
                        ),
                        sent,
                        before,
                        "archive destination conflict",
                    )
                    source_root.unlink()
                    source_root.mkdir()
                assert archive_scope(
                    candidate,
                    progress_relative,
                    destination,
                    persist_authority=False,
                ) == []
                if mode == "scoped":
                    assert not source_root.exists()
                else:
                    assert source_root.is_dir()
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
        elif name == "legacy_archive_recovery_request":
            archived_source = initialize(repo, "alpha")
            add_recovery_provenance(repo, archived_source)
            add_recovery_terminal_evidence(repo, archived_source)
            destination = ".release-loop/archive/2026-08-30-alpha-incomplete"
            archive_scope(
                repo,
                str(archived_source.relative_to(repo)),
                destination,
                mode="incomplete",
            )
            gate = initialize(repo, "gate")
            gate_text = gate.read_text(encoding="utf-8")
            gate_text = gate_text.replace(
                "phase: implement\nphase_status: in-progress\n",
                "phase: implement\nphase_status: waiting-user\n",
                1,
            ).replace(
                "final_action:\n",
                "recovery_gate:\n"
                "  id: legacy-archive-recovery-approval\n"
                "  issued_at: 2026-08-30T05:00:00Z\n"
                "  expected_answer_class: approve-exact-recovery-or-cancel\n"
                "final_action:\n",
                1,
            )
            gate.write_text(gate_text, encoding="utf-8")
            payload = run_cli(
                "request-legacy-archive",
                "--repo", str(repo),
                "--recovery-id", "recovery-alpha",
                "--progress-path", f"{destination}/progress.md",
                "--gate-progress-path", str(gate.relative_to(repo)),
                "--session", "fixture-session",
            )
            assert payload["recovery_id"] == "recovery-alpha", payload
            assert payload["state"] == "requested", payload
            authority = repo / ".release-loop/recovery-authority/recovery-alpha"
            backup = repo / ".release-loop/recovery-backups/recovery-alpha"
            assert (authority / "request.json").is_file(), authority
            assert backup.is_dir() and not any(backup.iterdir()), backup
            gate.write_text(
                gate.read_text(encoding="utf-8").replace(
                    "final_action:\n",
                    "recovery_gate_receipt:\n"
                    "  gate_id: legacy-archive-recovery-approval\n"
                    "  gate_issued_at: 2026-08-30T05:00:00Z\n"
                    "  answer: approved\n"
                    "  session: fixture-session\n"
                    "  nonce: fixture-nonce\n"
                    f"  request_sha256: {hashlib.sha256((authority / 'request.json').read_bytes()).hexdigest()}\n"
                    "  reserved_at: 2026-08-30T05:01:00Z\n"
                    "final_action:\n",
                    1,
                ),
                encoding="utf-8",
            )
            approved = run_cli(
                "request-legacy-archive",
                "--repo", str(repo),
                "--recovery-id", "recovery-alpha",
                "--publish-approval",
            )
            assert approved == {"recovery_id": "recovery-alpha", "state": "approved"}, approved
            assert (authority / "gate-receipt.json").is_file()
            assert (authority / "approval.json").is_file()
        elif name in {"legacy_archive_recovery_lifecycle", "legacy_archive_recovery_success"}:
            archived_source = initialize(repo, "alpha")
            add_recovery_provenance(repo, archived_source)
            add_recovery_terminal_evidence(repo, archived_source)
            destination = ".release-loop/archive/2026-08-30-alpha-incomplete"
            archive_scope(repo, str(archived_source.relative_to(repo)), destination, mode="incomplete")
            source_archive = repo / destination
            source_archive_before = filesystem_manifest(source_archive)
            source_manifest = source_archive / ".archive-source-manifest.json"
            source_manifest_sha256 = hashlib.sha256(source_manifest.read_bytes()).hexdigest()
            expected_g0_sha256 = archive_payload_generation_sha256(source_manifest)
            gate = initialize(repo, "gate")
            gate_text = gate.read_text(encoding="utf-8").replace(
                "phase: implement\nphase_status: in-progress\n",
                "phase: implement\nphase_status: waiting-user\n",
                1,
            ).replace(
                "final_action:\n",
                "recovery_gate:\n"
                "  id: legacy-archive-recovery-approval\n"
                "  issued_at: 2026-08-30T05:00:00Z\n"
                "  expected_answer_class: approve-exact-recovery-or-cancel\n"
                "final_action:\n",
                1,
            )
            gate.write_text(gate_text, encoding="utf-8")
            run_cli(
                "request-legacy-archive", "--repo", str(repo), "--recovery-id", "recovery-alpha",
                "--progress-path", f"{destination}/progress.md", "--gate-progress-path",
                str(gate.relative_to(repo)), "--session", "fixture-session",
            )
            gate.write_text(
                gate.read_text(encoding="utf-8").replace(
                    "final_action:\n",
                    "recovery_gate_receipt:\n"
                    "  gate_id: legacy-archive-recovery-approval\n"
                    "  gate_issued_at: 2026-08-30T05:00:00Z\n"
                    "  answer: approved\n"
                    "  session: fixture-session\n"
                    "  nonce: fixture-nonce\n"
                    f"  request_sha256: {hashlib.sha256((repo / '.release-loop/recovery-authority/recovery-alpha/request.json').read_bytes()).hexdigest()}\n"
                    "  reserved_at: 2026-08-30T05:01:00Z\n"
                    "final_action:\n",
                    1,
                ),
                encoding="utf-8",
            )
            run_cli("request-legacy-archive", "--repo", str(repo), "--recovery-id", "recovery-alpha", "--publish-approval")
            backup_result = run_cli("backup-legacy-archive", "--repo", str(repo), "--recovery-id", "recovery-alpha")
            assert backup_result["state"] == "backed-up", backup_result
            audit_result = run_cli("audit-legacy-archive", "--repo", str(repo), "--recovery-id", "recovery-alpha")
            assert audit_result["verdict"] == "accepted", audit_result
            restore_result = run_cli("restore-legacy-archive", "--repo", str(repo), "--recovery-id", "recovery-alpha")
            assert restore_result["state"] == "archived", restore_result
            assert filesystem_manifest(source_archive) == source_archive_before
            assert not (repo / ".release-loop/runs/alpha").exists()
            request = json.loads(
                (repo / ".release-loop/recovery-authority/recovery-alpha/request.json").read_bytes()
            )
            completed = repo / (
                f".release-loop/archive/{request['issued_at'][:10]}-"
                f"{request['feature']}-recovered/progress.md"
            )
            assert completed.is_file()
            assert (repo / destination / "progress.md").is_file()
            completed_text = completed.read_text(encoding="utf-8")
            assert f"archived-incomplete: archive-destination: {destination}" in completed_text
            assert "legacy_archive_recovery: staged:" in completed_text
            assert "legacy-pre-archive-verification: accepted:" in completed_text
            assert "legacy_archive_recovery: completed:" in completed_text
            authority = repo / ".release-loop/recovery-authority/recovery-alpha"
            receipt = json.loads((authority / "receipt.json").read_text(encoding="utf-8"))
            executor_result = json.loads((authority / "executor-result.json").read_text(encoding="utf-8"))
            assert receipt["approval_sha256"] == hashlib.sha256((authority / "approval.json").read_bytes()).hexdigest()
            assert receipt["source_archive_manifest_sha256"] == source_manifest_sha256
            assert executor_result["restored_root_sha256"] == expected_g0_sha256
            assert receipt["g0_sha256"] == expected_g0_sha256
            assert f"receipt-sha256={hashlib.sha256((authority / 'receipt.json').read_bytes()).hexdigest()}" in completed_text
        elif name == "legacy_archive_recovery_requires_terminal_evidence":
            archived_source = initialize(repo, "alpha")
            add_recovery_provenance(repo, archived_source)
            destination = ".release-loop/archive/2026-08-30-alpha-incomplete"
            archive_scope(repo, str(archived_source.relative_to(repo)), destination, mode="incomplete")
            gate = initialize(repo, "gate")
            gate.write_text(
                gate.read_text(encoding="utf-8").replace(
                    "phase: implement\nphase_status: in-progress\n",
                    "phase: implement\nphase_status: waiting-user\n",
                    1,
                ).replace(
                    "final_action:\n",
                    "recovery_gate:\n"
                    "  id: legacy-archive-recovery-approval\n"
                    "  issued_at: 2026-08-30T05:00:00Z\n"
                    "  expected_answer_class: approve-exact-recovery-or-cancel\n"
                    "final_action:\n",
                    1,
                ),
                encoding="utf-8",
            )
            archive_root = repo / destination
            archive_before = filesystem_manifest(archive_root)
            authority, backup = audit_rejected_recovery_fixture(
                repo,
                "recovery-ineligible",
                destination,
                gate,
            )
            assert (authority / "audit.json").is_file(), authority
            assert (authority / "backup.json").is_file(), authority
            assert filesystem_manifest(archive_root) == archive_before, archive_root
            assert not (repo / ".release-loop/runs/alpha").exists(), repo
        elif name in {
            "legacy_archive_recovery_rejects_unmerged_ship",
            "legacy_archive_recovery_rejects_unexecuted_final_action",
            "legacy_archive_recovery_rejects_uncommitted_retro",
            "legacy_archive_recovery_rejects_retro_before_ship",
            "legacy_archive_recovery_rejects_wrong_final_action_kind",
        }:
            terminal_variant = {
                "legacy_archive_recovery_rejects_unmerged_ship": "unmerged-ship",
                "legacy_archive_recovery_rejects_unexecuted_final_action": "unexecuted-final-action",
                "legacy_archive_recovery_rejects_uncommitted_retro": "uncommitted-retro",
                "legacy_archive_recovery_rejects_retro_before_ship": "retro-before-ship",
                "legacy_archive_recovery_rejects_wrong_final_action_kind": "wrong-final-action-kind",
            }[name]
            destination, gate = recovery_archive(repo, terminal_variant)
            archive_root = repo / destination
            archive_before = filesystem_manifest(archive_root)
            recovery_id = terminal_variant
            authority, backup = audit_rejected_recovery_fixture(
                repo,
                recovery_id,
                destination,
                gate,
            )
            assert filesystem_manifest(archive_root) == archive_before
            assert (authority / "audit.json").is_file()
            assert (authority / "backup.json").is_file()
            assert not (repo / ".release-loop/runs/alpha").exists()
        elif name in {
            "legacy_archive_recovery_rejects_draft_plan",
            "legacy_archive_recovery_rejects_plan_seal_mismatch",
        }:
            plan_variant = {
                "legacy_archive_recovery_rejects_draft_plan": "draft",
                "legacy_archive_recovery_rejects_plan_seal_mismatch": "seal-mismatch",
            }[name]
            destination, gate = recovery_archive(repo, plan_variant=plan_variant)
            archive_root = repo / destination
            archive_before = filesystem_manifest(archive_root)
            recovery_id = plan_variant
            authority, backup = audit_rejected_recovery_fixture(
                repo,
                recovery_id,
                destination,
                gate,
            )
            assert filesystem_manifest(archive_root) == archive_before
            assert (authority / "audit.json").is_file()
            assert (authority / "backup.json").is_file()
            assert not (repo / ".release-loop/runs/alpha").exists()
        elif name == "legacy_archive_recovery_rejects_missing_introduction_object":
            destination, gate = recovery_archive(repo, install_alternate=False)
            assert not (repo / ".git/objects/info/alternates").exists()
            archive_root = repo / destination
            archive_before = filesystem_manifest(archive_root)
            authority, backup = audit_rejected_recovery_fixture(
                repo,
                "missing-introduction-object",
                destination,
                gate,
            )
            assert filesystem_manifest(archive_root) == archive_before
            assert (authority / "audit.json").is_file()
            assert (authority / "backup.json").is_file()
            assert not (repo / ".release-loop/runs/alpha").exists()
        elif name == "legacy_archive_recovery_ancestor_replacement":
            destination, authority, backup = prepare_recovery_for_restore(repo, "recovery-ancestor")
            archive_root = repo / destination
            archive_before = filesystem_manifest(archive_root)
            backup_before = filesystem_manifest(backup)
            external = tmp / "external-recovery-target"
            (external / "nested").mkdir(parents=True)
            (external / "sentinel.txt").write_bytes(b"EXTERNAL RECOVERY SENTINEL\n")
            (external / "nested/kept.txt").write_bytes(b"KEEP\n")
            external_before = filesystem_manifest(external)
            MATRIX_EXTERNAL_ROOT = external
            MATRIX_EXTERNAL_PRE_STATE = fixture_root_snapshot(external)
            assert_blocked_preserves(
                lambda: run_cli(
                    "restore-legacy-archive", "--repo", str(repo), "--recovery-id", "recovery-ancestor",
                    failure="recovery-before-copy-ancestor",
                    environment_overrides={"RUN_ARTIFACT_INTEGRITY_TEST_REPLACE_TARGET": str(external)},
                ),
                sent,
                before,
                "path boundary",
            )
            runs_root = repo / ".release-loop/runs"
            assert runs_root.is_symlink(), "ancestor-replacement hook did not replace the runs root"
            assert Path(os.readlink(runs_root)).resolve() == external.resolve()
            assert filesystem_manifest(external) == external_before
            assert filesystem_manifest(archive_root) == archive_before
            assert filesystem_manifest(backup) == backup_before
            assert not (authority / "executor-result.json").exists()
            assert not (authority / "receipt.json").exists()
        elif name in {
            "legacy_archive_recovery_resume_after_g0",
            "legacy_archive_recovery_resume_after_receipt",
            "legacy_archive_recovery_resume_after_g1",
            "legacy_archive_recovery_resume_after_g2",
            "legacy_archive_recovery_resume_after_g3",
        }:
            stage = name[len("legacy_archive_recovery_resume_"):]
            hook = "recovery-" + stage.replace("after_", "after-")
            recovery_id = "resume-" + stage.replace("_", "-")
            destination, authority, backup = prepare_recovery_for_restore(repo, recovery_id)
            archive_root = repo / destination
            archive_before = filesystem_manifest(archive_root)
            backup_before = filesystem_manifest(backup)
            expected_g0_sha256 = archive_payload_generation_sha256(
                archive_root / ".archive-source-manifest.json"
            )
            assert_blocked_preserves(
                lambda: run_cli(
                    "restore-legacy-archive", "--repo", str(repo), "--recovery-id", recovery_id,
                    failure=hook,
                ),
                sent,
                before,
                "injected recovery interruption",
            )
            result_path = authority / "executor-result.json"
            receipt_path = authority / "receipt.json"
            target_progress = repo / ".release-loop/runs/alpha/progress.md"
            assert result_path.is_file(), f"{stage} did not preserve the G0 result"
            assert target_progress.is_file(), f"{stage} did not preserve restored progress"
            assert receipt_path.is_file() is (stage != "after_g0")
            result_before = result_path.read_bytes()
            receipt_before = receipt_path.read_bytes() if receipt_path.is_file() else None
            result_payload = json.loads(result_before)
            assert result_payload["restored_root_sha256"] == expected_g0_sha256
            if receipt_before is not None:
                assert json.loads(receipt_before)["g0_sha256"] == expected_g0_sha256
            interrupted_text = target_progress.read_text(encoding="utf-8")
            interrupted_lines = recovery_progress_lines(interrupted_text)
            interrupted_progress = target_progress.read_bytes()
            assert interrupted_text.count("archived-incomplete: archive-destination:") == 1
            g1_sha256 = None
            g2_sha256 = None
            if stage in {"after_g0", "after_receipt"}:
                assert "legacy_archive_recovery: staged:" not in interrupted_text
                assert "legacy-pre-archive-verification: accepted:" not in interrupted_text
                assert "legacy_archive_recovery: completed:" not in interrupted_text
            elif stage == "after_g1":
                assert interrupted_text.count("legacy_archive_recovery: staged:") == 1
                assert interrupted_text.count("retro: archive-destination:") == 1
                assert "legacy-pre-archive-verification: accepted:" not in interrupted_text
                assert "phase: retro\n" in interrupted_text
                assert "phase_status: in-progress\n" in interrupted_text
                g1_sha256 = fixture_generation_sha256(target_progress.parent)
            elif stage == "after_g2":
                assert interrupted_text.count("legacy_archive_recovery: staged:") == 1
                assert interrupted_text.count("legacy-pre-archive-verification: accepted:") == 1
                assert "legacy_archive_recovery: completed:" not in interrupted_text
                assert "phase: retro\n" in interrupted_text
                assert "phase_status: in-progress\n" in interrupted_text
                accepted_line = next(
                    line for line in interrupted_lines
                    if "legacy-pre-archive-verification: accepted:" in line
                )
                g1_progress = interrupted_text.replace(accepted_line + "\n", "", 1).encode("utf-8")
                reconstructed_g1_sha256 = fixture_generation_sha256(
                    target_progress.parent,
                    progress_override=g1_progress,
                )
                assert f"g1-sha256={reconstructed_g1_sha256}" in accepted_line
                g2_sha256 = fixture_generation_sha256(target_progress.parent)
            else:
                assert interrupted_text.count("legacy_archive_recovery: staged:") == 1
                assert interrupted_text.count("legacy-pre-archive-verification: accepted:") == 1
                assert interrupted_text.count("legacy_archive_recovery: completed:") == 1
                assert "phase: done\n" in interrupted_text
                assert "phase_status: complete\n" in interrupted_text
            if stage in {"after_g1", "after_g2"}:
                staged_destination = re.search(
                    r"retro: archive-destination: (\S+)",
                    interrupted_text,
                )
                assert staged_destination is not None
                assert_blocked_preserves(
                    lambda: run_cli(
                        "archive", "--repo", str(repo),
                        "--progress-path", str(target_progress.relative_to(repo)),
                        "--destination", staged_destination.group(1),
                    ),
                    sent,
                    before,
                    "recovery archive state",
                )
                assert target_progress.read_bytes() == interrupted_progress
            resumed = run_cli(
                "restore-legacy-archive", "--repo", str(repo), "--recovery-id", recovery_id,
            )
            assert resumed["state"] == "archived", resumed
            assert result_path.read_bytes() == result_before
            if receipt_before is not None:
                assert receipt_path.read_bytes() == receipt_before
            assert filesystem_manifest(archive_root) == archive_before
            assert filesystem_manifest(backup) == backup_before
            completed = repo / str(resumed["progress_path"])
            if stage == "after_g3":
                assert completed.read_bytes() == interrupted_progress
            completed_text = completed.read_text(encoding="utf-8")
            completed_lines = recovery_progress_lines(completed_text)
            for line in interrupted_lines:
                assert completed_lines.count(line) == 1, line
            assert completed_text.count("archived-incomplete: archive-destination:") == 1
            assert completed_text.count("legacy_archive_recovery: staged:") == 1
            assert completed_text.count("legacy-pre-archive-verification: accepted:") == 1
            assert completed_text.count("legacy_archive_recovery: completed:") == 1
            receipt_sha256 = hashlib.sha256(receipt_path.read_bytes()).hexdigest()
            receipt_payload = json.loads(receipt_path.read_bytes())
            assert receipt_payload["g0_sha256"] == expected_g0_sha256
            staged_line = next(line for line in completed_lines if "legacy_archive_recovery: staged:" in line)
            destination_line = next(line for line in completed_lines if "retro: archive-destination:" in line)
            accepted_line = next(
                line for line in completed_lines
                if "legacy-pre-archive-verification: accepted:" in line
            )
            completed_line = next(line for line in completed_lines if "legacy_archive_recovery: completed:" in line)
            completed_destination = re.search(r"retro: archive-destination: (\S+)", destination_line)
            assert completed_destination is not None
            assert resumed["progress_path"] == completed_destination.group(1) + "/progress.md"
            for line in (staged_line, destination_line):
                assert f"receipt-sha256={receipt_sha256}" in line
                assert f"g0-sha256={expected_g0_sha256}" in line
                assert completed_destination.group(1) in line
            assert f"receipt-sha256={receipt_sha256}" in accepted_line
            if g1_sha256 is not None:
                assert f"g1-sha256={g1_sha256}" in accepted_line
            if g2_sha256 is not None:
                assert f"g2-sha256={g2_sha256}" in completed_line
        elif name == "legacy_archive_recovery_generation_tamper":
            destination, authority, backup = prepare_recovery_for_restore(repo, "recovery-generation-tamper")
            archive_root = repo / destination
            archive_before = filesystem_manifest(archive_root)
            backup_before = filesystem_manifest(backup)
            assert_blocked_preserves(
                lambda: run_cli(
                    "restore-legacy-archive", "--repo", str(repo), "--recovery-id", "recovery-generation-tamper",
                    failure="recovery-after-g1",
                ),
                sent,
                before,
                "injected recovery interruption",
            )
            target_progress = repo / ".release-loop/runs/alpha/progress.md"
            target_progress.write_text(
                target_progress.read_text(encoding="utf-8") + "\n# TAMPERED RECOVERY GENERATION\n",
                encoding="utf-8",
            )
            tampered_progress = target_progress.read_bytes()
            result_path = authority / "executor-result.json"
            receipt_path = authority / "receipt.json"
            result_before = result_path.read_bytes()
            receipt_before = receipt_path.read_bytes()
            assert_blocked_preserves(
                lambda: run_cli(
                    "restore-legacy-archive", "--repo", str(repo), "--recovery-id", "recovery-generation-tamper",
                ),
                sent,
                before,
                "recovery generation",
            )
            assert target_progress.read_bytes() == tampered_progress
            assert result_path.read_bytes() == result_before
            assert receipt_path.read_bytes() == receipt_before
            assert filesystem_manifest(archive_root) == archive_before
            assert filesystem_manifest(backup) == backup_before
        elif name in {
            "legacy_archive_recovery_rejects_tampered_g0_result",
            "legacy_archive_recovery_rejects_tampered_receipt",
            "legacy_archive_recovery_rejects_tampered_g1",
            "legacy_archive_recovery_rejects_tampered_g2",
            "legacy_archive_recovery_rejects_tampered_g3",
        }:
            tamper_stage = name[len("legacy_archive_recovery_rejects_tampered_"):]
            hook = {
                "g0_result": "recovery-after-g0",
                "receipt": "recovery-after-receipt",
                "g1": "recovery-after-g1",
                "g2": "recovery-after-g2",
                "g3": "recovery-after-g3",
            }[tamper_stage]
            recovery_id = "tamper-" + tamper_stage.replace("_", "-")
            destination, authority, backup = prepare_recovery_for_restore(repo, recovery_id)
            archive_root = repo / destination
            archive_before = filesystem_manifest(archive_root)
            backup_before = filesystem_manifest(backup)
            assert_blocked_preserves(
                lambda: run_cli(
                    "restore-legacy-archive", "--repo", str(repo), "--recovery-id", recovery_id,
                    failure=hook,
                ),
                sent,
                before,
                "injected recovery interruption",
            )
            request = json.loads((authority / "request.json").read_bytes())
            recovered = repo / (
                f".release-loop/archive/{request['issued_at'][:10]}-"
                f"{request['feature']}-recovered"
            )
            if tamper_stage in {"g1", "g2", "g3"}:
                assert recovered.is_dir(), recovered
                recovered_before = filesystem_manifest(recovered)
                assert set(recovered_before) == {
                    ".legacy-archive-recovery-reservation.json"
                }, recovered_before
            else:
                assert not recovered.exists(), recovered
                recovered_before = None
            target_progress = repo / ".release-loop/runs/alpha/progress.md"
            result_path = authority / "executor-result.json"
            receipt_path = authority / "receipt.json"
            if tamper_stage == "g0_result":
                mutated_path = result_path
                payload = json.loads(mutated_path.read_bytes())
                payload["restored_root_sha256"] = "0" * 64
                mutated_path.write_text(
                    json.dumps(payload, sort_keys=True, separators=(",", ":")) + "\n",
                    encoding="utf-8",
                )
            elif tamper_stage == "receipt":
                mutated_path = receipt_path
                payload = json.loads(mutated_path.read_bytes())
                payload["g0_sha256"] = "0" * 64
                mutated_path.write_text(
                    json.dumps(payload, sort_keys=True, separators=(",", ":")) + "\n",
                    encoding="utf-8",
                )
            else:
                mutated_path = target_progress
                digest_key = {
                    "g1": "receipt-sha256",
                    "g2": "g1-sha256",
                    "g3": "g2-sha256",
                }[tamper_stage]
                mutated_text, replacements = re.subn(
                    rf"{digest_key}=[0-9a-f]{{64}}",
                    f"{digest_key}={'0' * 64}",
                    target_progress.read_text(encoding="utf-8"),
                    count=1,
                )
                assert replacements == 1, f"missing {digest_key} mutation target"
                target_progress.write_text(mutated_text, encoding="utf-8")
            mutated_bytes = mutated_path.read_bytes()
            assert_blocked_preserves(
                lambda: run_cli(
                    "restore-legacy-archive", "--repo", str(repo), "--recovery-id", recovery_id,
                ),
                sent,
                before,
                "recovery restore" if tamper_stage == "receipt" else "recovery generation",
            )
            assert mutated_path.read_bytes() == mutated_bytes
            assert filesystem_manifest(archive_root) == archive_before
            assert filesystem_manifest(backup) == backup_before
            if recovered_before is None:
                assert not recovered.exists(), recovered
            else:
                assert filesystem_manifest(recovered) == recovered_before
        elif name in {
            "legacy_archive_recovery_restore_rejects_deleted_gate_receipt",
            "legacy_archive_recovery_restore_rejects_tampered_gate_receipt",
        }:
            recovery_id = (
                "deleted-gate-receipt"
                if name.endswith("deleted_gate_receipt")
                else "tampered-gate-receipt"
            )
            destination, authority, backup = prepare_recovery_for_restore(repo, recovery_id)
            archive_root = repo / destination
            archive_before = filesystem_manifest(archive_root)
            backup_before = filesystem_manifest(backup)
            gate_receipt = authority / "gate-receipt.json"
            if name.endswith("deleted_gate_receipt"):
                gate_receipt.unlink()
                diagnostic = "recovery authority"
            else:
                payload = json.loads(gate_receipt.read_bytes())
                payload["answer"] = "cancelled"
                gate_receipt.write_text(
                    json.dumps(payload, sort_keys=True, separators=(",", ":")) + "\n",
                    encoding="utf-8",
                )
                diagnostic = "recovery restore"
            request = json.loads((authority / "request.json").read_bytes())
            recovered = repo / (
                f".release-loop/archive/{request['issued_at'][:10]}-"
                f"{request['feature']}-recovered"
            )
            assert_blocked_preserves(
                lambda: run_cli(
                    "restore-legacy-archive", "--repo", str(repo), "--recovery-id", recovery_id,
                ),
                sent,
                before,
                diagnostic,
            )
            assert filesystem_manifest(archive_root) == archive_before
            assert filesystem_manifest(backup) == backup_before
            assert not (repo / ".release-loop/runs/alpha").exists()
            assert not (authority / "executor-started.json").exists()
            assert not (authority / "executor-result.json").exists()
            assert not (authority / "receipt.json").exists()
            assert not recovered.exists()
        elif name == "legacy_archive_recovery_rejects_foreign_destination_before_g1":
            recovery_id = "foreign-destination"
            destination, authority, backup = prepare_recovery_for_restore(repo, recovery_id)
            archive_root = repo / destination
            archive_before = filesystem_manifest(archive_root)
            backup_before = filesystem_manifest(backup)
            expected_g0_sha256 = archive_payload_generation_sha256(
                archive_root / ".archive-source-manifest.json"
            )
            request = json.loads((authority / "request.json").read_bytes())
            recovered = repo / (
                f".release-loop/archive/{request['issued_at'][:10]}-"
                f"{request['feature']}-recovered"
            )
            assert_blocked_preserves(
                lambda: run_cli(
                    "restore-legacy-archive", "--repo", str(repo),
                    "--recovery-id", recovery_id,
                    failure="recovery-after-receipt",
                ),
                sent,
                before,
                "injected recovery interruption",
            )
            receipt_digest = hashlib.sha256((authority / "receipt.json").read_bytes()).hexdigest()
            recovered.mkdir()
            reservation = {
                "schema": "legacy-archive-recovery-reservation/v1",
                "recovery_id": recovery_id,
                "receipt_sha256": receipt_digest,
                "g0_sha256": expected_g0_sha256,
                "destination": recovered.relative_to(repo).as_posix(),
            }
            (recovered / ".legacy-archive-recovery-reservation.json").write_text(
                json.dumps(reservation, sort_keys=True, separators=(",", ":")) + "\n",
                encoding="utf-8",
            )
            (recovered / "foreign.txt").write_bytes(b"FOREIGN DESTINATION\n")
            foreign_before = filesystem_manifest(recovered)
            assert_blocked_preserves(
                lambda: run_cli(
                    "restore-legacy-archive", "--repo", str(repo),
                    "--recovery-id", recovery_id,
                ),
                sent,
                before,
                "recovery archive",
            )
            target = repo / ".release-loop/runs/alpha"
            target_progress = target / "progress.md"
            target_text = target_progress.read_text(encoding="utf-8")
            assert fixture_generation_sha256(target) == expected_g0_sha256
            assert target_progress.read_bytes() == (backup / "progress.md").read_bytes()
            assert "phase: retro\n" in target_text
            assert "phase_status: in-progress\n" in target_text
            assert "legacy_archive_recovery: staged:" not in target_text
            assert "legacy-pre-archive-verification: accepted:" not in target_text
            assert "legacy_archive_recovery: completed:" not in target_text
            result = json.loads((authority / "executor-result.json").read_bytes())
            receipt = json.loads((authority / "receipt.json").read_bytes())
            assert result["restored_root_sha256"] == expected_g0_sha256
            assert receipt["g0_sha256"] == expected_g0_sha256
            assert filesystem_manifest(recovered) == foreign_before
            assert filesystem_manifest(archive_root) == archive_before
            assert filesystem_manifest(backup) == backup_before
        elif name in {
            "legacy_archive_recovery_rejects_backup_change_before_copy",
            "legacy_archive_recovery_rejects_source_change_before_copy",
        }:
            selector = "backup" if "backup_change" in name else "source"
            recovery_id = f"{selector}-change-before-copy"
            destination, authority, backup = prepare_recovery_for_restore(repo, recovery_id)
            archive_root = repo / destination
            archive_before = filesystem_manifest(archive_root)
            backup_before = filesystem_manifest(backup)
            request = json.loads((authority / "request.json").read_bytes())
            recovered = repo / (
                f".release-loop/archive/{request['issued_at'][:10]}-"
                f"{request['feature']}-recovered"
            )
            assert_blocked_preserves(
                lambda: run_cli(
                    "restore-legacy-archive", "--repo", str(repo), "--recovery-id", recovery_id,
                    failure="recovery-before-copy-source-change",
                    environment_overrides={"RUN_ARTIFACT_INTEGRITY_TEST_MUTATE_SOURCE": selector},
                ),
                sent,
                before,
                "recovery restore",
            )
            archive_after = filesystem_manifest(archive_root)
            backup_after = filesystem_manifest(backup)
            selected_before = backup_before if selector == "backup" else archive_before
            selected_after = backup_after if selector == "backup" else archive_after
            assert set(selected_after) == set(selected_before)
            for relative, entry in selected_before.items():
                if relative == "progress.md":
                    assert selected_after[relative] == (
                        "file",
                        entry[1] + b"\n# INJECTED SOURCE CHANGE\n",
                    )
                else:
                    assert selected_after[relative] == entry
            if selector == "backup":
                assert archive_after == archive_before
            else:
                assert backup_after == backup_before
            target = repo / ".release-loop/runs/alpha"
            assert target.is_dir() and filesystem_manifest(target) == {}
            assert (authority / "executor-started.json").is_file()
            assert not (authority / "executor-result.json").exists()
            assert not (authority / "receipt.json").exists()
            assert not recovered.exists()
        elif name == "legacy_archive_recovery_target_create_swap":
            recovery_id = "target-create-swap"
            destination, authority, backup = prepare_recovery_for_restore(repo, recovery_id)
            archive_root = repo / destination
            archive_before = filesystem_manifest(archive_root)
            backup_before = filesystem_manifest(backup)
            external = tmp / "external-created-target"
            (external / "nested").mkdir(parents=True)
            (external / "sentinel.txt").write_bytes(b"CREATED TARGET SENTINEL\n")
            (external / "nested/kept.txt").write_bytes(b"KEEP CREATED TARGET\n")
            external_before = filesystem_manifest(external)
            MATRIX_EXTERNAL_ROOT = external
            MATRIX_EXTERNAL_PRE_STATE = fixture_root_snapshot(external)
            assert_blocked_preserves(
                lambda: run_cli(
                    "restore-legacy-archive", "--repo", str(repo), "--recovery-id", recovery_id,
                    failure="recovery-target-create-swap",
                    environment_overrides={"RUN_ARTIFACT_INTEGRITY_TEST_REPLACE_TARGET": str(external)},
                ),
                sent,
                before,
                "path boundary",
            )
            target = repo / ".release-loop/runs/alpha"
            displaced = repo / f".release-loop/runs/alpha.created-{recovery_id}"
            assert target.is_dir() and not target.is_symlink()
            assert displaced.is_dir() and filesystem_manifest(displaced) == {}
            assert (target.stat().st_dev, target.stat().st_ino) != (
                displaced.stat().st_dev,
                displaced.stat().st_ino,
            )
            assert filesystem_manifest(target) == external_before
            assert filesystem_manifest(external) == external_before
            assert filesystem_manifest(archive_root) == archive_before
            assert filesystem_manifest(backup) == backup_before
            assert (authority / "executor-started.json").is_file()
            assert not (authority / "executor-result.json").exists()
            assert not (authority / "receipt.json").exists()
            assert not (repo / ".release-loop/archive/2026-08-30-alpha-recovered").exists()
        elif name == "legacy_archive_recovery_before_g1_ancestor":
            recovery_id = "before-g1-ancestor"
            destination, authority, backup = prepare_recovery_for_restore(repo, recovery_id)
            archive_root = repo / destination
            archive_before = filesystem_manifest(archive_root)
            backup_before = filesystem_manifest(backup)
            expected_g0_sha256 = archive_payload_generation_sha256(
                archive_root / ".archive-source-manifest.json"
            )
            external = tmp / "external-before-g1"
            (external / "nested").mkdir(parents=True)
            (external / "sentinel.txt").write_bytes(b"BEFORE G1 SENTINEL\n")
            (external / "nested/kept.txt").write_bytes(b"KEEP BEFORE G1\n")
            external_before = filesystem_manifest(external)
            MATRIX_EXTERNAL_ROOT = external
            MATRIX_EXTERNAL_PRE_STATE = fixture_root_snapshot(external)
            assert_blocked_preserves(
                lambda: run_cli(
                    "restore-legacy-archive", "--repo", str(repo), "--recovery-id", recovery_id,
                    failure="recovery-before-g1-ancestor",
                    environment_overrides={"RUN_ARTIFACT_INTEGRITY_TEST_REPLACE_TARGET": str(external)},
                ),
                sent,
                before,
                "path boundary",
            )
            runs_root = repo / ".release-loop/runs"
            displaced_runs = repo / (
                ".release-loop/runs.recovery-displaced-"
                f"recovery-before-g1-ancestor-{recovery_id}"
            )
            retained_target = displaced_runs / "alpha"
            retained_progress = retained_target / "progress.md"
            retained_text = retained_progress.read_text(encoding="utf-8")
            assert runs_root.is_symlink() and Path(os.readlink(runs_root)).resolve() == external.resolve()
            assert fixture_generation_sha256(retained_target) == expected_g0_sha256
            assert retained_progress.read_bytes() == (backup / "progress.md").read_bytes()
            assert "phase: retro\n" in retained_text
            assert "phase_status: in-progress\n" in retained_text
            assert "legacy_archive_recovery: staged:" not in retained_text
            assert "legacy-pre-archive-verification: accepted:" not in retained_text
            assert "legacy_archive_recovery: completed:" not in retained_text
            result = json.loads((authority / "executor-result.json").read_bytes())
            receipt = json.loads((authority / "receipt.json").read_bytes())
            assert result["restored_root_sha256"] == expected_g0_sha256
            assert receipt["g0_sha256"] == expected_g0_sha256
            assert filesystem_manifest(external) == external_before
            assert filesystem_manifest(archive_root) == archive_before
            assert filesystem_manifest(backup) == backup_before
            request = json.loads((authority / "request.json").read_bytes())
            recovered = repo / (
                f".release-loop/archive/{request['issued_at'][:10]}-"
                f"{request['feature']}-recovered"
            )
            if recovered.exists():
                assert set(filesystem_manifest(recovered)) == {
                    ".legacy-archive-recovery-reservation.json"
                }
        elif name == "legacy_archive_recovery_cleanup_foreign_preserves_g3":
            recovery_id = "cleanup-foreign-preserves-g3"
            destination, authority, backup = prepare_recovery_for_restore(repo, recovery_id)
            archive_root = repo / destination
            archive_before = filesystem_manifest(archive_root)
            backup_before = filesystem_manifest(backup)
            assert_blocked_preserves(
                lambda: run_cli(
                    "restore-legacy-archive", "--repo", str(repo), "--recovery-id", recovery_id,
                    failure="recovery-after-g3",
                ),
                sent,
                before,
                "injected recovery interruption",
            )
            target = repo / ".release-loop/runs/alpha"
            g3_before = filesystem_manifest(target)
            g3_progress = (target / "progress.md").read_bytes()
            result_path = authority / "executor-result.json"
            receipt_path = authority / "receipt.json"
            result_before = result_path.read_bytes()
            receipt_before = receipt_path.read_bytes()
            assert_blocked_preserves(
                lambda: run_cli(
                    "restore-legacy-archive", "--repo", str(repo), "--recovery-id", recovery_id,
                    failure="recovery-before-cleanup-foreign",
                ),
                sent,
                before,
                "recovery archive",
            )
            g3_after = filesystem_manifest(target)
            assert set(g3_after) == {*g3_before, ".injected-foreign-cleanup"}
            for relative, entry in g3_before.items():
                assert g3_after[relative] == entry
            assert g3_after[".injected-foreign-cleanup"] == ("file", b"FOREIGN\n")
            assert (target / "progress.md").read_bytes() == g3_progress
            assert result_path.read_bytes() == result_before
            assert receipt_path.read_bytes() == receipt_before
            assert filesystem_manifest(archive_root) == archive_before
            assert filesystem_manifest(backup) == backup_before
        elif name == "legacy_archive_recovery_resume_after_cleanup_one":
            recovery_id = "resume-after-cleanup-one"
            destination, authority, backup = prepare_recovery_for_restore(repo, recovery_id)
            archive_root = repo / destination
            archive_before = filesystem_manifest(archive_root)
            backup_before = filesystem_manifest(backup)
            request = json.loads((authority / "request.json").read_bytes())
            recovered = repo / (
                f".release-loop/archive/{request['issued_at'][:10]}-"
                f"{request['feature']}-recovered"
            )
            assert_blocked_preserves(
                lambda: run_cli(
                    "restore-legacy-archive", "--repo", str(repo), "--recovery-id", recovery_id,
                    failure="recovery-after-cleanup-one",
                ),
                sent,
                before,
                "injected recovery interruption",
            )
            target = repo / ".release-loop/runs/alpha"
            cleanup = repo / (
                ".release-loop/runs/.alpha.legacy-recovery-cleanup-"
                f"{recovery_id}"
            )
            destination_before = filesystem_manifest(recovered)
            destination_identity = (recovered.stat().st_dev, recovered.stat().st_ino)
            expected_g3 = {
                relative: entry
                for relative, entry in destination_before.items()
                if relative not in {
                    ".archive-source-manifest.json",
                    ".legacy-archive-recovery-reservation.json",
                    ".phase-artifact-ownership.json",
                }
            }
            assert not target.exists(), target
            assert cleanup.is_dir() and not cleanup.is_symlink(), cleanup
            partial_target = filesystem_manifest(cleanup)
            assert set(partial_target) < set(expected_g3), (partial_target, expected_g3)
            missing_entries = set(expected_g3) - set(partial_target)
            assert len(missing_entries) == 1, missing_entries
            for relative, entry in partial_target.items():
                assert expected_g3[relative] == entry, relative
            result_path = authority / "executor-result.json"
            receipt_path = authority / "receipt.json"
            result_before = result_path.read_bytes()
            receipt_before = receipt_path.read_bytes()
            resumed = run_cli(
                "restore-legacy-archive", "--repo", str(repo), "--recovery-id", recovery_id,
            )
            assert resumed["state"] == "archived", resumed
            assert resumed["progress_path"] == recovered.relative_to(repo).as_posix() + "/progress.md"
            assert not target.exists(), target
            assert not cleanup.exists(), cleanup
            assert (recovered.stat().st_dev, recovered.stat().st_ino) == destination_identity
            destination_after = filesystem_manifest(recovered)
            reservation = ".legacy-archive-recovery-reservation.json"
            assert reservation in destination_before, destination_before
            assert set(destination_after) == set(destination_before) - {reservation}, destination_after
            for relative, entry in destination_after.items():
                assert destination_before[relative] == entry, relative
            assert result_path.read_bytes() == result_before, result_path
            assert receipt_path.read_bytes() == receipt_before, receipt_path
            assert filesystem_manifest(archive_root) == archive_before, archive_root
            assert filesystem_manifest(backup) == backup_before, backup
        elif name == "legacy_archive_recovery_progress_after_binding_swap":
            recovery_id = "progress-after-binding-swap"
            destination, authority, backup = prepare_recovery_for_restore(repo, recovery_id)
            archive_root = repo / destination
            archive_before = filesystem_manifest(archive_root)
            backup_before = filesystem_manifest(backup)
            expected_g0_sha256 = archive_payload_generation_sha256(
                archive_root / ".archive-source-manifest.json"
            )
            external = tmp / "external-progress-after-binding"
            external.mkdir()
            external_sentinel = external / "sentinel.txt"
            external_sentinel.write_bytes(b"PROGRESS BINDING SENTINEL\n")
            sentinel_before = external_sentinel.read_bytes()
            MATRIX_EXTERNAL_ROOT = external
            MATRIX_EXTERNAL_PRE_STATE = fixture_root_snapshot(external)
            assert_blocked_preserves(
                lambda: run_cli(
                    "restore-legacy-archive", "--repo", str(repo), "--recovery-id", recovery_id,
                    failure="recovery-progress-after-binding-swap",
                    environment_overrides={"RUN_ARTIFACT_INTEGRITY_TEST_REPLACE_TARGET": str(external)},
                ),
                sent,
                before,
                "path boundary",
            )
            target = repo / ".release-loop/runs/alpha"
            retained_target = external / f"{recovery_id}-retained-target"
            retained_progress = retained_target / "progress.md"
            retained_text = retained_progress.read_text(encoding="utf-8")
            assert external_sentinel.read_bytes() == sentinel_before
            assert target.is_dir() and filesystem_manifest(target) == {}
            assert fixture_generation_sha256(retained_target) == expected_g0_sha256
            assert retained_progress.read_bytes() == (backup / "progress.md").read_bytes()
            assert "phase: retro\n" in retained_text
            assert "phase_status: in-progress\n" in retained_text
            assert "legacy_archive_recovery: staged:" not in retained_text
            assert "retro: archive-destination:" not in retained_text
            assert "legacy-pre-archive-verification: accepted:" not in retained_text
            assert "legacy_archive_recovery: completed:" not in retained_text
            result = json.loads((authority / "executor-result.json").read_bytes())
            receipt = json.loads((authority / "receipt.json").read_bytes())
            assert result["restored_root_sha256"] == expected_g0_sha256
            assert receipt["g0_sha256"] == expected_g0_sha256
            assert filesystem_manifest(archive_root) == archive_before
            assert filesystem_manifest(backup) == backup_before
        elif name == "legacy_archive_recovery_rejects_concurrent_restore":
            recovery_id = "concurrent-restore"
            destination, authority, backup = prepare_recovery_for_restore(repo, recovery_id)
            archive_root = repo / destination
            archive_before = filesystem_manifest(archive_root)
            backup_before = filesystem_manifest(backup)
            assert_blocked_preserves(
                lambda: run_cli(
                    "restore-legacy-archive", "--repo", str(repo), "--recovery-id", recovery_id,
                    failure="recovery-after-g0",
                ),
                sent,
                before,
                "injected recovery interruption",
            )
            assert (authority / "executor-result.json").is_file()
            assert not (authority / "receipt.json").exists()
            target = repo / ".release-loop/runs/alpha"
            request = json.loads((authority / "request.json").read_bytes())
            recovered = repo / (
                f".release-loop/archive/{request['issued_at'][:10]}-"
                f"{request['feature']}-recovered"
            )
            assert not recovered.exists(), recovered
            control = tmp / "concurrent-restore-lock-control"
            control.mkdir()
            ready = control / "ready"
            release = control / "release"
            first_environment = os.environ.copy()
            first_environment["RUN_ARTIFACT_INTEGRITY_TEST_HOLD_RECOVERY_LOCK"] = str(control)
            first = subprocess.Popen(
                (
                    sys.executable,
                    str(CLI),
                    "restore-legacy-archive",
                    "--repo",
                    str(repo),
                    "--recovery-id",
                    recovery_id,
                ),
                cwd=ROOT,
                env=first_environment,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
            )
            try:
                deadline = time.monotonic() + 5
                while not ready.is_file():
                    if first.poll() is not None:
                        first_stdout, first_stderr = first.communicate()
                        raise AssertionError(
                            "first restore exited before holding recovery lock: "
                            f"stdout={first_stdout!r} stderr={first_stderr!r}"
                        )
                    if time.monotonic() >= deadline:
                        raise AssertionError("first restore did not report held recovery lock")
                    time.sleep(0.01)
                authority_locked = filesystem_manifest(authority)
                target_locked = filesystem_manifest(target)
                destination_locked = filesystem_manifest(recovered) if recovered.exists() else None
                assert_blocked_preserves(
                    lambda: run_cli(
                        "restore-legacy-archive", "--repo", str(repo), "--recovery-id", recovery_id,
                    ),
                    sent,
                    before,
                    "recovery restore",
                )
                assert filesystem_manifest(authority) == authority_locked
                assert filesystem_manifest(target) == target_locked
                if destination_locked is None:
                    assert not recovered.exists(), recovered
                else:
                    assert filesystem_manifest(recovered) == destination_locked
                assert filesystem_manifest(archive_root) == archive_before
                assert filesystem_manifest(backup) == backup_before
                release.write_bytes(b"release\n")
                first_stdout, first_stderr = first.communicate(timeout=10)
                assert first.returncode == 0, (first.returncode, first_stdout, first_stderr)
                assert first_stderr == "", first_stderr
                first_payload = json.loads(first_stdout)
                assert first_stdout == (
                    json.dumps(first_payload, sort_keys=True, separators=(",", ":")) + "\n"
                )
                assert first_payload["state"] == "archived", first_payload
            finally:
                if not release.exists():
                    release.write_bytes(b"release\n")
                if first.poll() is None:
                    first.kill()
                    first.communicate()
            assert not target.exists(), target
            destination_identity = (recovered.stat().st_dev, recovered.stat().st_ino)
            destination_after_first = filesystem_manifest(recovered)
            authority_after_first = filesystem_manifest(authority)
            resumed = run_cli(
                "restore-legacy-archive", "--repo", str(repo), "--recovery-id", recovery_id,
            )
            assert resumed["state"] == "archived", resumed
            assert (recovered.stat().st_dev, recovered.stat().st_ino) == destination_identity
            assert filesystem_manifest(recovered) == destination_after_first
            assert filesystem_manifest(authority) == authority_after_first
            assert filesystem_manifest(archive_root) == archive_before
            assert filesystem_manifest(backup) == backup_before
        elif name == "legacy_archive_recovery_records_rejected_audit":
            for variant, options in (
                ("ineligible", {"terminal_variant": "unmerged-ship"}),
                ("provenance", {"plan_variant": "seal-mismatch"}),
            ):
                candidate = new_repo(tmp, f"rejected-audit-{variant}")
                recovery_id = f"rejected-{variant}"
                destination, gate = recovery_archive(candidate, **options)
                archive_root = candidate / destination
                archive_before = filesystem_manifest(archive_root)
                requested = run_cli(
                    "request-legacy-archive", "--repo", str(candidate),
                    "--recovery-id", recovery_id,
                    "--progress-path", f"{destination}/progress.md",
                    "--gate-progress-path", str(gate.relative_to(candidate)),
                    "--session", "fixture-session",
                )
                assert requested == {"recovery_id": recovery_id, "state": "requested"}, requested
                authority = candidate / f".release-loop/recovery-authority/{recovery_id}"
                backup = candidate / f".release-loop/recovery-backups/{recovery_id}"
                request_path = authority / "request.json"
                request = json.loads(request_path.read_bytes())
                assert request["schema"] == "legacy-archive-recovery-request/v1", request
                assert request["archived_progress_path"] == f"{destination}/progress.md", request
                assert request["archive_destination"] == destination, request
                assert request["restore_target"] == ".release-loop/runs/alpha", request
                assert request["plan_path"] and request["plan_seal"], request
                assert filesystem_manifest(backup) == {}
                approve_recovery_fixture(candidate, recovery_id, authority, gate)
                backed_up = run_cli(
                    "backup-legacy-archive", "--repo", str(candidate), "--recovery-id", recovery_id,
                )
                assert backed_up["state"] == "backed-up", backed_up
                audited = run_cli(
                    "audit-legacy-archive", "--repo", str(candidate), "--recovery-id", recovery_id,
                )
                assert audited["state"] == "audited", audited
                assert audited["verdict"] == "rejected", audited
                audit_path = authority / "audit.json"
                audit_bytes = audit_path.read_bytes()
                audit = json.loads(audit_bytes)
                assert audit_bytes == (
                    json.dumps(audit, sort_keys=True, separators=(",", ":")) + "\n"
                ).encode("utf-8")
                assert audit["schema"] == "legacy-archive-recovery-audit/v1", audit
                assert audit["verdict"] == "rejected", audit
                assert audit["request_sha256"] == hashlib.sha256(request_path.read_bytes()).hexdigest()
                assert filesystem_manifest(archive_root) == archive_before
                audit_before = audit_path.read_bytes()
                assert_blocked_preserves(
                    lambda: run_cli(
                        "restore-legacy-archive", "--repo", str(candidate),
                        "--recovery-id", recovery_id,
                    ),
                    sent,
                    before,
                    "recovery restore",
                )
                assert audit_path.read_bytes() == audit_before
                assert not (candidate / ".release-loop/runs/alpha").exists()
        elif name == "legacy_archive_recovery_backup_revalidates_gate_receipt":
            for mutation in ("deleted", "tampered"):
                candidate = new_repo(tmp, f"backup-gate-receipt-{mutation}")
                recovery_id = f"backup-gate-{mutation}"
                destination, gate = recovery_archive(candidate)
                run_cli(
                    "request-legacy-archive", "--repo", str(candidate),
                    "--recovery-id", recovery_id,
                    "--progress-path", f"{destination}/progress.md",
                    "--gate-progress-path", str(gate.relative_to(candidate)),
                    "--session", "fixture-session",
                )
                authority = candidate / f".release-loop/recovery-authority/{recovery_id}"
                backup = candidate / f".release-loop/recovery-backups/{recovery_id}"
                approve_recovery_fixture(candidate, recovery_id, authority, gate)
                authority_before = filesystem_manifest(authority)
                archive_root = candidate / destination
                archive_before = filesystem_manifest(archive_root)
                gate_receipt = authority / "gate-receipt.json"
                if mutation == "deleted":
                    gate_receipt.unlink()
                else:
                    receipt = json.loads(gate_receipt.read_bytes())
                    receipt["answer"] = "cancelled"
                    gate_receipt.write_text(
                        json.dumps(receipt, sort_keys=True, separators=(",", ":")) + "\n",
                        encoding="utf-8",
                    )
                mutated_authority = filesystem_manifest(authority)
                assert filesystem_manifest(backup) == {}
                assert_blocked_preserves(
                    lambda: run_cli(
                        "backup-legacy-archive", "--repo", str(candidate),
                        "--recovery-id", recovery_id,
                    ),
                    sent,
                    before,
                    "recovery backup",
                )
                assert filesystem_manifest(backup) == {}
                assert not (authority / "backup.json").exists()
                assert filesystem_manifest(authority) == mutated_authority
                assert filesystem_manifest(archive_root) == archive_before
                assert authority_before != mutated_authority
        elif name == "legacy_archive_recovery_rejects_unsafe_journal_entries":
            for mutation in ("unsafe-path", "missing-final", "digest-mismatch"):
                candidate = new_repo(tmp, f"unsafe-journal-{mutation}")
                recovery_id = f"unsafe-journal-{mutation}"
                destination, gate = recovery_archive(candidate)
                archive_root = candidate / destination
                journal_path = archive_root / ".phase-artifact-ownership.json"
                journal = json.loads(journal_path.read_bytes())
                if mutation == "unsafe-path":
                    journal["owned"]["../outside"] = "0" * 64
                elif mutation == "missing-final":
                    journal["owned"]["reports/missing.md"] = "0" * 64
                else:
                    journal["owned"]["progress.md"] = "0" * 64
                journal_path.write_text(
                    json.dumps(journal, sort_keys=True, separators=(",", ":")) + "\n",
                    encoding="utf-8",
                )
                archive_before = filesystem_manifest(archive_root)
                assert_blocked_preserves(
                    lambda: run_cli(
                        "request-legacy-archive", "--repo", str(candidate),
                        "--recovery-id", recovery_id,
                        "--progress-path", f"{destination}/progress.md",
                        "--gate-progress-path", str(gate.relative_to(candidate)),
                        "--session", "fixture-session",
                    ),
                    sent,
                    before,
                    "archive destination conflict",
                )
                assert filesystem_manifest(archive_root) == archive_before
                assert not (candidate / f".release-loop/recovery-authority/{recovery_id}").exists()
                assert not (candidate / f".release-loop/recovery-backups/{recovery_id}").exists()
        elif name == "legacy_archive_recovery_rejects_terminal_evidence_mutants":
            for variant in (
                "same-ship-retro-commit",
                "ship-approval-shape",
                "ship-approval-by",
                "ship-approval-time",
            ):
                candidate = new_repo(tmp, f"terminal-mutant-{variant}")
                recovery_id = f"terminal-mutant-{variant}"
                destination, gate = recovery_archive(candidate, terminal_variant=variant)
                archive_root = candidate / destination
                archive_before = filesystem_manifest(archive_root)
                requested = run_cli(
                    "request-legacy-archive", "--repo", str(candidate),
                    "--recovery-id", recovery_id,
                    "--progress-path", f"{destination}/progress.md",
                    "--gate-progress-path", str(gate.relative_to(candidate)),
                    "--session", "fixture-session",
                )
                assert requested["state"] == "requested", requested
                authority = candidate / f".release-loop/recovery-authority/{recovery_id}"
                approve_recovery_fixture(candidate, recovery_id, authority, gate)
                run_cli(
                    "backup-legacy-archive", "--repo", str(candidate), "--recovery-id", recovery_id,
                )
                audited = run_cli(
                    "audit-legacy-archive", "--repo", str(candidate), "--recovery-id", recovery_id,
                )
                assert audited["verdict"] == "rejected", audited
                audit_path = authority / "audit.json"
                audit = json.loads(audit_path.read_bytes())
                assert audit["verdict"] == "rejected", audit
                assert filesystem_manifest(archive_root) == archive_before
                assert not (candidate / ".release-loop/runs/alpha").exists()
        elif name == "legacy_archive_recovery_serializes_audit_and_restore":
            recovery_id = "audit-restore-lock"
            destination, gate = recovery_archive(repo)
            run_cli(
                "request-legacy-archive", "--repo", str(repo), "--recovery-id", recovery_id,
                "--progress-path", f"{destination}/progress.md",
                "--gate-progress-path", str(gate.relative_to(repo)), "--session", "fixture-session",
            )
            authority = repo / f".release-loop/recovery-authority/{recovery_id}"
            backup = repo / f".release-loop/recovery-backups/{recovery_id}"
            approve_recovery_fixture(repo, recovery_id, authority, gate)
            run_cli("backup-legacy-archive", "--repo", str(repo), "--recovery-id", recovery_id)
            archive_root = repo / destination
            control = tmp / "audit-restore-lock-control"
            control.mkdir()
            ready = control / "ready"
            release = control / "release"
            audit_environment = os.environ.copy()
            audit_environment["RUN_ARTIFACT_INTEGRITY_TEST_HOLD_RECOVERY_LOCK"] = str(control)
            auditor = subprocess.Popen(
                (
                    sys.executable,
                    str(CLI),
                    "audit-legacy-archive",
                    "--repo",
                    str(repo),
                    "--recovery-id",
                    recovery_id,
                ),
                cwd=ROOT,
                env=audit_environment,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
            )
            try:
                deadline = time.monotonic() + 5
                while not ready.is_file():
                    if auditor.poll() is not None:
                        audit_stdout, audit_stderr = auditor.communicate()
                        raise AssertionError(
                            "audit exited before holding recovery lock: "
                            f"stdout={audit_stdout!r} stderr={audit_stderr!r}"
                        )
                    if time.monotonic() >= deadline:
                        raise AssertionError("audit did not report held recovery lock")
                    time.sleep(0.01)
                authority_locked = filesystem_manifest(authority)
                backup_locked = filesystem_manifest(backup)
                archive_locked = filesystem_manifest(archive_root)
                assert not (repo / ".release-loop/runs/alpha").exists()
                assert not (repo / ".release-loop/archive/2026-08-30-alpha-recovered").exists()
                assert_blocked_preserves(
                    lambda: run_cli(
                        "restore-legacy-archive", "--repo", str(repo), "--recovery-id", recovery_id,
                    ),
                    sent,
                    before,
                    "recovery restore",
                )
                assert filesystem_manifest(authority) == authority_locked
                assert filesystem_manifest(backup) == backup_locked
                assert filesystem_manifest(archive_root) == archive_locked
                assert not (repo / ".release-loop/runs/alpha").exists()
                assert not (repo / ".release-loop/archive/2026-08-30-alpha-recovered").exists()
                release.write_bytes(b"release\n")
                audit_stdout, audit_stderr = auditor.communicate(timeout=10)
                assert auditor.returncode == 0, (auditor.returncode, audit_stdout, audit_stderr)
                assert audit_stderr == "", audit_stderr
                audit_payload = json.loads(audit_stdout)
                assert audit_payload["verdict"] == "accepted", audit_payload
            finally:
                if not release.exists():
                    release.write_bytes(b"release\n")
                if auditor.poll() is None:
                    auditor.kill()
                    auditor.communicate()
            restored = run_cli(
                "restore-legacy-archive", "--repo", str(repo), "--recovery-id", recovery_id,
            )
            assert restored["state"] == "archived", restored
        elif name == "legacy_archive_recovery_resumes_archive_publication_faults":
            reservation_repo = new_repo(tmp, "resume-reservation-temp")
            reservation_id = "resume-reservation-temp"
            destination, authority, backup = prepare_recovery_for_restore(
                reservation_repo,
                reservation_id,
            )
            archive_root = reservation_repo / destination
            archive_before = filesystem_manifest(archive_root)
            backup_before = filesystem_manifest(backup)
            assert_blocked_preserves(
                lambda: run_cli(
                    "restore-legacy-archive", "--repo", str(reservation_repo),
                    "--recovery-id", reservation_id,
                    failure="recovery-after-receipt",
                ),
                sent,
                before,
                "injected recovery interruption",
            )
            request = json.loads((authority / "request.json").read_bytes())
            recovered = reservation_repo / (
                f".release-loop/archive/{request['issued_at'][:10]}-"
                f"{request['feature']}-recovered"
            )
            assert_blocked_preserves(
                lambda: run_cli(
                    "restore-legacy-archive", "--repo", str(reservation_repo),
                    "--recovery-id", reservation_id,
                    failure="recovery-reservation-temp-only",
                ),
                sent,
                before,
                "injected recovery interruption",
            )
            reservation_identity = (recovered.stat().st_dev, recovered.stat().st_ino)
            assert set(filesystem_manifest(recovered)) == {
                ".legacy-archive-recovery-reservation.json.tmp"
            }
            resumed = run_cli(
                "restore-legacy-archive", "--repo", str(reservation_repo),
                "--recovery-id", reservation_id,
            )
            assert resumed["state"] == "archived", resumed
            assert (recovered.stat().st_dev, recovered.stat().st_ino) == reservation_identity
            assert not (reservation_repo / ".release-loop/runs/alpha").exists()
            assert filesystem_manifest(archive_root) == archive_before
            assert filesystem_manifest(backup) == backup_before

            for stage, hook in (
                ("manifest", "recovery-archive-manifest-only"),
                ("journal", "recovery-archive-journal-only"),
                ("payload", "recovery-archive-payload-mid-file"),
                ("progress", "recovery-archive-before-progress"),
            ):
                candidate = new_repo(tmp, f"resume-archive-{stage}")
                recovery_id = f"resume-archive-{stage}"
                destination, gate = recovery_archive(candidate, extra_payload=True)
                run_cli(
                    "request-legacy-archive", "--repo", str(candidate),
                    "--recovery-id", recovery_id,
                    "--progress-path", f"{destination}/progress.md",
                    "--gate-progress-path", str(gate.relative_to(candidate)),
                    "--session", "fixture-session",
                )
                authority = candidate / f".release-loop/recovery-authority/{recovery_id}"
                backup = candidate / f".release-loop/recovery-backups/{recovery_id}"
                approve_recovery_fixture(candidate, recovery_id, authority, gate)
                run_cli(
                    "backup-legacy-archive", "--repo", str(candidate),
                    "--recovery-id", recovery_id,
                )
                run_cli(
                    "audit-legacy-archive", "--repo", str(candidate),
                    "--recovery-id", recovery_id,
                )
                archive_root = candidate / destination
                archive_before = filesystem_manifest(archive_root)
                backup_before = filesystem_manifest(backup)
                assert_blocked_preserves(
                    lambda candidate=candidate, recovery_id=recovery_id: run_cli(
                        "restore-legacy-archive", "--repo", str(candidate),
                        "--recovery-id", recovery_id,
                        failure="recovery-after-g3",
                    ),
                    sent,
                    before,
                    "injected recovery interruption",
                )
                target = candidate / ".release-loop/runs/alpha"
                expected_g3 = filesystem_manifest(target)
                request = json.loads((authority / "request.json").read_bytes())
                recovered = candidate / (
                    f".release-loop/archive/{request['issued_at'][:10]}-"
                    f"{request['feature']}-recovered"
                )
                result_before = (authority / "executor-result.json").read_bytes()
                receipt_before = (authority / "receipt.json").read_bytes()
                assert_blocked_preserves(
                    lambda candidate=candidate, recovery_id=recovery_id, hook=hook: run_cli(
                        "restore-legacy-archive", "--repo", str(candidate),
                        "--recovery-id", recovery_id,
                        failure=hook,
                    ),
                    sent,
                    before,
                    "injected recovery interruption",
                )
                partial = filesystem_manifest(recovered)
                control_names = {
                    ".archive-source-manifest.json",
                    ".legacy-archive-recovery-reservation.json",
                    ".phase-artifact-ownership.json",
                }
                if stage == "manifest":
                    assert set(partial) == {
                        ".archive-source-manifest.json",
                        ".legacy-archive-recovery-reservation.json",
                    }, partial
                elif stage == "journal":
                    assert set(partial) == control_names, partial
                else:
                    published_payload = {
                        relative: entry
                        for relative, entry in partial.items()
                        if relative not in control_names
                    }
                    if stage == "payload":
                        assert published_payload, partial
                        assert set(published_payload) < set(expected_g3), partial
                    else:
                        assert set(published_payload) == set(expected_g3) - {"progress.md"}, partial
                    for relative, entry in published_payload.items():
                        assert expected_g3[relative] == entry, relative
                destination_identity = (recovered.stat().st_dev, recovered.stat().st_ino)
                resumed = run_cli(
                    "restore-legacy-archive", "--repo", str(candidate),
                    "--recovery-id", recovery_id,
                )
                assert resumed["state"] == "archived", resumed
                assert (recovered.stat().st_dev, recovered.stat().st_ino) == destination_identity
                completed = filesystem_manifest(recovered)
                completed_payload = {
                    relative: entry
                    for relative, entry in completed.items()
                    if relative not in {
                        ".archive-source-manifest.json",
                        ".phase-artifact-ownership.json",
                    }
                }
                assert completed_payload == expected_g3
                assert not target.exists(), target
                assert (authority / "executor-result.json").read_bytes() == result_before
                assert (authority / "receipt.json").read_bytes() == receipt_before
                assert filesystem_manifest(archive_root) == archive_before
                assert filesystem_manifest(backup) == backup_before
        elif name == "legacy_archive_recovery_resumes_atomic_temp_publications":
            receipt_repo = new_repo(tmp, "resume-receipt-temp")
            receipt_id = "resume-receipt-temp"
            destination, authority, backup = prepare_recovery_for_restore(receipt_repo, receipt_id)
            archive_root = receipt_repo / destination
            archive_before = filesystem_manifest(archive_root)
            backup_before = filesystem_manifest(backup)
            assert_blocked_preserves(
                lambda: run_cli(
                    "restore-legacy-archive", "--repo", str(receipt_repo),
                    "--recovery-id", receipt_id,
                    failure="recovery-receipt-temp-only",
                ),
                sent,
                before,
                "injected recovery interruption",
            )
            target = receipt_repo / ".release-loop/runs/alpha"
            target_before = filesystem_manifest(target)
            assert (authority / ".receipt.json.tmp").is_file()
            assert not (authority / "receipt.json").exists()
            resumed = run_cli(
                "restore-legacy-archive", "--repo", str(receipt_repo),
                "--recovery-id", receipt_id,
            )
            assert resumed["state"] == "archived", resumed
            assert not (authority / ".receipt.json.tmp").exists()
            assert not target.exists()
            assert target_before
            assert filesystem_manifest(archive_root) == archive_before
            assert filesystem_manifest(backup) == backup_before

            for generation, setup_hook, fault_hook in (
                ("g1", "recovery-after-receipt", "recovery-progress-g1-temp-only"),
                ("g2", "recovery-after-g1", "recovery-progress-g2-temp-only"),
                ("g3", "recovery-after-g2", "recovery-progress-g3-temp-only"),
            ):
                candidate = new_repo(tmp, f"resume-{generation}-temp")
                recovery_id = f"resume-{generation}-temp"
                destination, authority, backup = prepare_recovery_for_restore(candidate, recovery_id)
                archive_root = candidate / destination
                archive_before = filesystem_manifest(archive_root)
                backup_before = filesystem_manifest(backup)
                assert_blocked_preserves(
                    lambda candidate=candidate, recovery_id=recovery_id, setup_hook=setup_hook: run_cli(
                        "restore-legacy-archive", "--repo", str(candidate),
                        "--recovery-id", recovery_id,
                        failure=setup_hook,
                    ),
                    sent,
                    before,
                    "injected recovery interruption",
                )
                target = candidate / ".release-loop/runs/alpha"
                progress_before = (target / "progress.md").read_bytes()
                result_before = (authority / "executor-result.json").read_bytes()
                receipt_before = (authority / "receipt.json").read_bytes()
                assert_blocked_preserves(
                    lambda candidate=candidate, recovery_id=recovery_id, fault_hook=fault_hook: run_cli(
                        "restore-legacy-archive", "--repo", str(candidate),
                        "--recovery-id", recovery_id,
                        failure=fault_hook,
                    ),
                    sent,
                    before,
                    "injected recovery interruption",
                )
                temporary = target / ".progress.md.recovery.tmp"
                assert temporary.is_file(), temporary
                assert (target / "progress.md").read_bytes() == progress_before
                assert temporary.read_bytes() != progress_before
                resumed = run_cli(
                    "restore-legacy-archive", "--repo", str(candidate),
                    "--recovery-id", recovery_id,
                )
                assert resumed["state"] == "archived", resumed
                assert not target.exists(), target
                assert (authority / "executor-result.json").read_bytes() == result_before
                assert (authority / "receipt.json").read_bytes() == receipt_before
                assert filesystem_manifest(archive_root) == archive_before
                assert filesystem_manifest(backup) == backup_before
        elif name == "legacy_archive_recovery_parser_provenance_matrix":
            spec = importlib.util.spec_from_file_location("recovery_parser_matrix", CLI)
            assert spec is not None and spec.loader is not None
            integrity = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(integrity)
            exact_heading = (
                "## Release-loop pre-archive verification V2: Verify the archived generation\n\n"
            )
            exact = exact_heading + integrity.CONTRACT_V2_BODY
            large_version = "9" * 512
            parser_matrix = (
                ("exact-v2", exact, "supported", "2"),
                ("v2-title", exact.replace("Verify the archived generation", "Verify an archive"), "unverifiable", "2"),
                ("v2-body", exact + " changed", "unverifiable", "2"),
                ("v3", "## Release-loop pre-archive verification V3: Future\n", "unsupported-version", "3"),
                ("large", f"## Release-loop pre-archive verification V{large_version}: Future\n", "unsupported-version", large_version),
                ("v0", "## Release-loop pre-archive verification V0: Invalid\n", "malformed", None),
                ("v00", "## Release-loop pre-archive verification V00: Invalid\n", "malformed", None),
                ("v02", "## Release-loop pre-archive verification V02: Invalid\n", "malformed", None),
                ("missing-colon", "## Release-loop pre-archive verification V2 Verify\n", "malformed", None),
                ("extra-colon", "## Release-loop pre-archive verification V2:: Verify\n", "malformed", None),
                ("missing-title", "## Release-loop pre-archive verification V2:\n", "malformed", None),
                ("case-near", "## RELEASE LOOP PRE ARCHIVE VERIFICATION V2: Verify\n", "malformed", None),
                ("separator-near", "## Release_loop-pre.archive verification V2: Verify\n", "malformed", None),
                ("one-edit", "## Release-loop pre-archive verificatio V2: Verify\n", "malformed", None),
                ("two-edit", "## Release-loop pre-archive verificati V2: Verify\n", "malformed", None),
                ("body-only", "The release-loop pre-archive verification V2 contract is discussed here.\n", "absent-legacy-shape", None),
                ("duplicate-mixed", exact + "\n## Release-loop pre-archive verification V3: Future\n", "duplicate", None),
                ("duplicate-malformed", "## Release-loop pre-archive verification V0 Invalid\n\n## Release-loop pre-archive verification V02 Invalid\n", "duplicate", None),
            )
            for label, text, classification, parsed_version in parser_matrix:
                observed = integrity.classify_pre_archive_contract(text)
                assert isinstance(observed, dict), (label, observed)
                assert observed["classification"] == classification, (label, observed)
                assert observed["parsed_version"] == parsed_version, (label, observed)
                assert (classification == "absent-legacy-shape") == (label == "body-only")

            for variant in (
                "approval-equals-introduction",
                "nonancestor-approval",
                "approval-blob-mismatch",
                "post-introduction-absence",
            ):
                candidate = new_repo(tmp, f"provenance-matrix-{variant}")
                recovery_id = f"provenance-{variant}"
                destination, gate = recovery_archive(candidate, plan_variant=variant)
                archive_root = candidate / destination
                archive_before = filesystem_manifest(archive_root)
                requested = run_cli(
                    "request-legacy-archive", "--repo", str(candidate),
                    "--recovery-id", recovery_id,
                    "--progress-path", f"{destination}/progress.md",
                    "--gate-progress-path", str(gate.relative_to(candidate)),
                    "--session", "fixture-session",
                )
                assert requested["state"] == "requested", requested
                authority = candidate / f".release-loop/recovery-authority/{recovery_id}"
                approve_recovery_fixture(candidate, recovery_id, authority, gate)
                run_cli(
                    "backup-legacy-archive", "--repo", str(candidate), "--recovery-id", recovery_id,
                )
                audited = run_cli(
                    "audit-legacy-archive", "--repo", str(candidate), "--recovery-id", recovery_id,
                )
                assert audited["verdict"] == "rejected", (variant, audited)
                audit = json.loads((authority / "audit.json").read_bytes())
                assert audit["verdict"] == "rejected", (variant, audit)
                if variant == "post-introduction-absence":
                    request = json.loads((authority / "request.json").read_bytes())
                    plan_text = subprocess.run(
                        ("git", "show", f"HEAD:{request['plan_path']}"),
                        cwd=ROOT,
                        stdout=subprocess.PIPE,
                        check=True,
                    ).stdout.decode("utf-8")
                    classified = integrity.classify_pre_archive_contract(plan_text)
                    assert classified["classification"] == "absent-legacy-shape", classified
                assert filesystem_manifest(archive_root) == archive_before
                assert not (candidate / ".release-loop/runs/alpha").exists()
        elif name == "legacy_archive_recovery_resumes_after_gate_receipt":
            recovery_id = "resume-after-gate-receipt"
            destination, gate = recovery_archive(repo)
            run_cli(
                "request-legacy-archive", "--repo", str(repo), "--recovery-id", recovery_id,
                "--progress-path", f"{destination}/progress.md",
                "--gate-progress-path", str(gate.relative_to(repo)), "--session", "fixture-session",
            )
            authority = repo / f".release-loop/recovery-authority/{recovery_id}"
            backup = repo / f".release-loop/recovery-backups/{recovery_id}"
            write_recovery_gate_approval_fixture(authority, gate)
            assert_blocked_preserves(
                lambda: run_cli(
                    "request-legacy-archive", "--repo", str(repo),
                    "--recovery-id", recovery_id, "--publish-approval",
                    failure="recovery-after-gate-receipt",
                ),
                sent,
                before,
                "injected recovery interruption",
            )
            gate_receipt = authority / "gate-receipt.json"
            gate_receipt_before = gate_receipt.read_bytes()
            assert not (authority / "approval.json").exists()
            assert filesystem_manifest(backup) == {}
            approved = run_cli(
                "request-legacy-archive", "--repo", str(repo),
                "--recovery-id", recovery_id, "--publish-approval",
            )
            assert approved == {"recovery_id": recovery_id, "state": "approved"}, approved
            assert gate_receipt.read_bytes() == gate_receipt_before
            approval = json.loads((authority / "approval.json").read_bytes())
            assert approval["gate_receipt_sha256"] == hashlib.sha256(gate_receipt_before).hexdigest()
            run_cli("backup-legacy-archive", "--repo", str(repo), "--recovery-id", recovery_id)
            audited = run_cli(
                "audit-legacy-archive", "--repo", str(repo), "--recovery-id", recovery_id,
            )
            assert audited["verdict"] == "accepted", audited
        elif name == "legacy_archive_recovery_resumes_after_destination_mkdir":
            recovery_id = "resume-after-destination-mkdir"
            destination, authority, backup = prepare_recovery_for_restore(repo, recovery_id)
            archive_root = repo / destination
            archive_before = filesystem_manifest(archive_root)
            backup_before = filesystem_manifest(backup)
            assert_blocked_preserves(
                lambda: run_cli(
                    "restore-legacy-archive", "--repo", str(repo), "--recovery-id", recovery_id,
                    failure="recovery-after-receipt",
                ),
                sent,
                before,
                "injected recovery interruption",
            )
            target = repo / ".release-loop/runs/alpha"
            target_before = filesystem_manifest(target)
            request = json.loads((authority / "request.json").read_bytes())
            recovered = repo / (
                f".release-loop/archive/{request['issued_at'][:10]}-"
                f"{request['feature']}-recovered"
            )
            assert_blocked_preserves(
                lambda: run_cli(
                    "restore-legacy-archive", "--repo", str(repo), "--recovery-id", recovery_id,
                    failure="recovery-after-destination-mkdir",
                ),
                sent,
                before,
                "injected recovery interruption",
            )
            destination_identity = (recovered.stat().st_dev, recovered.stat().st_ino)
            assert filesystem_manifest(recovered) == {}
            assert filesystem_manifest(target) == target_before
            resumed = run_cli(
                "restore-legacy-archive", "--repo", str(repo), "--recovery-id", recovery_id,
            )
            assert resumed["state"] == "archived", resumed
            assert (recovered.stat().st_dev, recovered.stat().st_ino) == destination_identity
            assert not target.exists(), target
            assert filesystem_manifest(archive_root) == archive_before
            assert filesystem_manifest(backup) == backup_before
        elif name == "legacy_archive_recovery_completed_archive_is_idempotent":
            recovery_id = "completed-archive-idempotent"
            destination, authority, backup = prepare_recovery_for_restore(repo, recovery_id)
            source_archive = repo / destination
            source_before = filesystem_manifest(source_archive)
            backup_before = filesystem_manifest(backup)
            restored = run_cli(
                "restore-legacy-archive", "--repo", str(repo), "--recovery-id", recovery_id,
            )
            assert restored["state"] == "archived", restored
            completed_progress = repo / str(restored["progress_path"])
            completed_root = completed_progress.parent
            completed_identity = (completed_root.stat().st_dev, completed_root.stat().st_ino)
            completed_before = filesystem_manifest(completed_root)
            authority_before = filesystem_manifest(authority)
            moved = archive_scope(
                repo,
                completed_progress.relative_to(repo).as_posix(),
                completed_root.relative_to(repo).as_posix(),
                persist_authority=False,
            )
            assert moved == [], moved
            assert (completed_root.stat().st_dev, completed_root.stat().st_ino) == completed_identity
            assert filesystem_manifest(completed_root) == completed_before
            assert filesystem_manifest(authority) == authority_before
            assert filesystem_manifest(source_archive) == source_before
            assert filesystem_manifest(backup) == backup_before
        elif name == "legacy_archive_recovery_rejects_foreign_publication_temporaries":
            for shape in ("exact", "prefix"):
                candidate = new_repo(tmp, f"foreign-publication-{shape}")
                recovery_id = f"foreign-publication-{shape}"
                destination, authority, backup = prepare_recovery_for_restore(candidate, recovery_id)
                source_archive = candidate / destination
                source_before = filesystem_manifest(source_archive)
                backup_before = filesystem_manifest(backup)
                assert_blocked_preserves(
                    lambda candidate=candidate, recovery_id=recovery_id: run_cli(
                        "restore-legacy-archive", "--repo", str(candidate),
                        "--recovery-id", recovery_id, failure="recovery-after-g3",
                    ),
                    sent,
                    before,
                    "injected recovery interruption",
                )
                target = candidate / ".release-loop/runs/alpha"
                progress_bytes = (target / "progress.md").read_bytes()
                request = json.loads((authority / "request.json").read_bytes())
                recovered = candidate / (
                    f".release-loop/archive/{request['issued_at'][:10]}-"
                    f"{request['feature']}-recovered"
                )
                temporary = recovered / (
                    ".legacy-archive-recovery-pending-"
                    + hashlib.sha256(b"progress.md").hexdigest()
                    + ".tmp"
                )
                temporary.write_bytes(
                    progress_bytes if shape == "exact" else progress_bytes[: len(progress_bytes) // 2]
                )
                destination_before = filesystem_manifest(recovered)
                target_before = filesystem_manifest(target)
                authority_before = filesystem_manifest(authority)
                assert_blocked_preserves(
                    lambda candidate=candidate, recovery_id=recovery_id: run_cli(
                        "restore-legacy-archive", "--repo", str(candidate),
                        "--recovery-id", recovery_id,
                    ),
                    sent,
                    before,
                    "foreign publication temporary",
                )
                assert filesystem_manifest(recovered) == destination_before
                assert filesystem_manifest(target) == target_before
                assert filesystem_manifest(authority) == authority_before
                assert filesystem_manifest(source_archive) == source_before
                assert filesystem_manifest(backup) == backup_before
        elif name == "legacy_archive_recovery_resumes_owned_prefix_temporary":
            recovery_id = "owned-prefix-temporary"
            destination, authority, backup = prepare_recovery_for_restore(repo, recovery_id)
            source_archive = repo / destination
            source_before = filesystem_manifest(source_archive)
            backup_before = filesystem_manifest(backup)
            assert_blocked_preserves(
                lambda: run_cli(
                    "restore-legacy-archive", "--repo", str(repo), "--recovery-id", recovery_id,
                    failure="recovery-after-g3",
                ),
                sent,
                before,
                "injected recovery interruption",
            )
            target = repo / ".release-loop/runs/alpha"
            request = json.loads((authority / "request.json").read_bytes())
            recovered = repo / (
                f".release-loop/archive/{request['issued_at'][:10]}-"
                f"{request['feature']}-recovered"
            )
            assert_blocked_preserves(
                lambda: run_cli(
                    "restore-legacy-archive", "--repo", str(repo), "--recovery-id", recovery_id,
                    failure="recovery-archive-payload-prefix-temp-only",
                ),
                sent,
                before,
                "injected recovery interruption",
            )
            temporaries = list(recovered.rglob(".legacy-archive-recovery-pending-*.tmp"))
            assert len(temporaries) == 1, temporaries
            temporary_before = temporaries[0].read_bytes()
            assert temporary_before
            assert temporary_before != (target / "progress.md").read_bytes()
            destination_identity = (recovered.stat().st_dev, recovered.stat().st_ino)
            resumed = run_cli(
                "restore-legacy-archive", "--repo", str(repo), "--recovery-id", recovery_id,
            )
            assert resumed["state"] == "archived", resumed
            assert (recovered.stat().st_dev, recovered.stat().st_ino) == destination_identity
            assert not list(recovered.rglob(".legacy-archive-recovery-pending-*.tmp"))
            assert not target.exists(), target
            assert filesystem_manifest(source_archive) == source_before
            assert filesystem_manifest(backup) == backup_before
        elif name == "legacy_archive_recovery_blocks_generation_change_before_progress_replace":
            recovery_id = "progress-precommit-generation-change"
            destination, authority, backup = prepare_recovery_for_restore(repo, recovery_id)
            source_archive = repo / destination
            source_before = filesystem_manifest(source_archive)
            backup_before = filesystem_manifest(backup)
            assert_blocked_preserves(
                lambda: run_cli(
                    "restore-legacy-archive", "--repo", str(repo), "--recovery-id", recovery_id,
                    failure="recovery-progress-before-replace-generation-change",
                ),
                sent,
                before,
                "recovery generation",
            )
            target = repo / ".release-loop/runs/alpha"
            progress_text = (target / "progress.md").read_text(encoding="utf-8")
            assert "legacy_archive_recovery: staged:" not in progress_text
            assert "retro: archive-destination:" not in progress_text
            assert (target / ".injected-generation-change").read_bytes() == b"GENERATION CHANGE\n"
            assert filesystem_manifest(source_archive) == source_before
            assert filesystem_manifest(backup) == backup_before
        elif name == "legacy_archive_recovery_blocks_foreign_partial_destination_before_mutation":
            recovery_id = "foreign-partial-destination"
            destination, authority, backup = prepare_recovery_for_restore(repo, recovery_id)
            source_archive = repo / destination
            source_before = filesystem_manifest(source_archive)
            backup_before = filesystem_manifest(backup)
            assert_blocked_preserves(
                lambda: run_cli(
                    "restore-legacy-archive", "--repo", str(repo), "--recovery-id", recovery_id,
                    failure="recovery-after-g3",
                ),
                sent,
                before,
                "injected recovery interruption",
            )
            target = repo / ".release-loop/runs/alpha"
            target_before = filesystem_manifest(target)
            assert_blocked_preserves(
                lambda: run_cli(
                    "restore-legacy-archive", "--repo", str(repo), "--recovery-id", recovery_id,
                    failure="recovery-archive-payload-mid-file",
                ),
                sent,
                before,
                "injected recovery interruption",
            )
            request = json.loads((authority / "request.json").read_bytes())
            recovered = repo / (
                f".release-loop/archive/{request['issued_at'][:10]}-"
                f"{request['feature']}-recovered"
            )
            (recovered / "foreign-entry").write_bytes(b"FOREIGN\n")
            destination_before = filesystem_manifest(recovered)
            authority_before = filesystem_manifest(authority)
            assert_blocked_preserves(
                lambda: run_cli(
                    "restore-legacy-archive", "--repo", str(repo), "--recovery-id", recovery_id,
                ),
                sent,
                before,
                "foreign",
            )
            assert filesystem_manifest(recovered) == destination_before
            assert filesystem_manifest(target) == target_before
            assert filesystem_manifest(authority) == authority_before
            assert filesystem_manifest(source_archive) == source_before
            assert filesystem_manifest(backup) == backup_before
        elif name == "legacy_archive_recovery_preserves_nonmanifest_owned_journal_row":
            recovery_id = "preserve-existing-owned-row"
            destination, gate = recovery_archive(repo, extra_payload=True)
            source_archive = repo / destination
            source_journal = json.loads(
                (source_archive / ".phase-artifact-ownership.json").read_bytes()
            )
            owned_path = "reports/evidence.md"
            owned_digest = hashlib.sha256(
                (source_archive / owned_path).read_bytes()
            ).hexdigest()
            source_journal["owned"][owned_path] = owned_digest
            (source_archive / ".phase-artifact-ownership.json").write_text(
                json.dumps(source_journal, sort_keys=True, separators=(",", ":")) + "\n",
                encoding="utf-8",
            )
            assert source_journal["owned"][owned_path] == owned_digest
            run_cli(
                "request-legacy-archive", "--repo", str(repo), "--recovery-id", recovery_id,
                "--progress-path", f"{destination}/progress.md", "--gate-progress-path",
                str(gate.relative_to(repo)), "--session", "fixture-session",
            )
            authority = repo / f".release-loop/recovery-authority/{recovery_id}"
            approve_recovery_fixture(repo, recovery_id, authority, gate)
            run_cli("backup-legacy-archive", "--repo", str(repo), "--recovery-id", recovery_id)
            run_cli("audit-legacy-archive", "--repo", str(repo), "--recovery-id", recovery_id)
            restored = run_cli(
                "restore-legacy-archive", "--repo", str(repo), "--recovery-id", recovery_id,
            )
            assert restored["state"] == "archived", restored
            recovered = repo / str(restored["progress_path"]).rsplit("/", 1)[0]
            final_journal = json.loads(
                (recovered / ".phase-artifact-ownership.json").read_bytes()
            )
            assert final_journal["owned"][owned_path] == owned_digest
            assert (recovered / owned_path).read_bytes() == b"RECOVERY PAYLOAD\n"
        elif name == "legacy_archive_recovery_rejects_reserved_payload_collisions":
            collision_paths = (
                ".legacy-archive-recovery-reservation.json",
                ".legacy-archive-recovery-reservation.json.tmp",
                ".progress.md.recovery.tmp",
                ".archive-source-manifest.json.recovery.tmp",
                ".phase-artifact-ownership.json.recovery.tmp",
                ".legacy-archive-recovery-owner-foreign.json",
                ".legacy-archive-recovery-pending-" + "0" * 64 + ".tmp",
                "reports/.legacy-archive-recovery-owner-nested.json",
                "reports/.legacy-archive-recovery-pending-" + "1" * 64 + ".tmp",
            )
            for index, collision in enumerate(collision_paths):
                candidate = new_repo(tmp, f"reserved-payload-{index}")
                recovery_id = f"reserved-payload-{index}"
                destination, gate = recovery_archive(candidate, extra_payload=True)
                archive_root = candidate / destination
                collision_path = archive_root / collision
                collision_path.parent.mkdir(parents=True, exist_ok=True)
                collision_path.write_bytes(b"COLLISION\n")
                manifest_path = archive_root / ".archive-source-manifest.json"
                manifest = json.loads(manifest_path.read_bytes())
                existing = {str(row["path"]) for row in manifest["entries"]}
                for parent in collision_path.relative_to(archive_root).parents:
                    parent_text = parent.as_posix()
                    if parent_text not in {".", ""} and parent_text not in existing:
                        manifest["entries"].append({"kind": "directory", "path": parent_text})
                        existing.add(parent_text)
                manifest["entries"] = [row for row in manifest["entries"] if row["path"] != collision]
                manifest["entries"].append({
                    "kind": "file",
                    "path": collision,
                    "sha256": hashlib.sha256(b"COLLISION\n").hexdigest(),
                })
                manifest["entries"].sort(key=lambda row: str(row["path"]))
                manifest_path.write_text(
                    json.dumps(manifest, sort_keys=True, separators=(",", ":")) + "\n",
                    encoding="utf-8",
                )
                journal_path = archive_root / ".phase-artifact-ownership.json"
                journal = json.loads(journal_path.read_bytes())
                journal["owned"][".archive-source-manifest.json"] = hashlib.sha256(
                    manifest_path.read_bytes()
                ).hexdigest()
                journal_path.write_text(
                    json.dumps(journal, sort_keys=True, separators=(",", ":")) + "\n",
                    encoding="utf-8",
                )
                archive_before = filesystem_manifest(archive_root)
                authority = candidate / f".release-loop/recovery-authority/{recovery_id}"
                backup = candidate / f".release-loop/recovery-backups/{recovery_id}"
                assert_blocked_preserves(
                    lambda candidate=candidate, recovery_id=recovery_id, destination=destination, gate=gate: run_cli(
                        "request-legacy-archive", "--repo", str(candidate),
                        "--recovery-id", recovery_id,
                        "--progress-path", f"{destination}/progress.md",
                        "--gate-progress-path", str(gate.relative_to(candidate)),
                        "--session", "fixture-session",
                    ),
                    sent,
                    before,
                    "reserved",
                )
                assert not authority.exists(), (collision, authority)
                assert not backup.exists(), (collision, backup)
                assert filesystem_manifest(archive_root) == archive_before
        elif name == "legacy_archive_recovery_rejects_frontmatter_shadowing":
            for field in ("phase_status", "merged", "branch", "base_branch", "ship_approved"):
                for shape in ("nested", "duplicate"):
                    candidate = new_repo(tmp, f"frontmatter-terminal-{field}-{shape}")
                    recovery_id = f"frontmatter-{field.replace('_', '-')}-{shape}"
                    destination, gate = recovery_archive(candidate)
                    archive_root = candidate / destination
                    progress_path = archive_root / "progress.md"
                    progress_text = progress_path.read_text(encoding="utf-8")
                    original = {
                        "phase_status": "phase_status: in-progress",
                        "merged": "merged: true",
                        "branch": "branch: main",
                        "base_branch": "base_branch: main",
                        "ship_approved": 'ship_approved: {by: user, at: 2026-08-30T04:56:00Z, conditions: "CI green, no open P0"}',
                    }[field]
                    invalid = {
                        "phase_status": "complete",
                        "merged": "false",
                        "branch": "wrong-branch",
                        "base_branch": "wrong-base",
                        "ship_approved": "approved",
                    }[field]
                    if shape == "nested":
                        progress_text = progress_text.replace(
                            original + "\n", f"shadow_{field}:\n  {field}: {invalid}\n", 1,
                        )
                    else:
                        progress_text = progress_text.replace(
                            original + "\n", original + f"\n{field}: {invalid}\n", 1,
                        )
                    progress_path.write_text(progress_text, encoding="utf-8")
                    manifest_path = archive_root / ".archive-source-manifest.json"
                    manifest = json.loads(manifest_path.read_bytes())
                    progress_row = next(row for row in manifest["entries"] if row["path"] == "progress.md")
                    progress_row["sha256"] = hashlib.sha256(progress_path.read_bytes()).hexdigest()
                    manifest_path.write_text(
                        json.dumps(manifest, sort_keys=True, separators=(",", ":")) + "\n",
                        encoding="utf-8",
                    )
                    journal_path = archive_root / ".phase-artifact-ownership.json"
                    journal = json.loads(journal_path.read_bytes())
                    journal["owned"][".archive-source-manifest.json"] = hashlib.sha256(
                        manifest_path.read_bytes()
                    ).hexdigest()
                    journal_path.write_text(
                        json.dumps(journal, sort_keys=True, separators=(",", ":")) + "\n",
                        encoding="utf-8",
                    )
                    authority = candidate / f".release-loop/recovery-authority/{recovery_id}"
                    backup = candidate / f".release-loop/recovery-backups/{recovery_id}"
                    if field == "phase_status" or shape == "duplicate":
                        assert_blocked_preserves(
                            lambda candidate=candidate, recovery_id=recovery_id, destination=destination, gate=gate: run_cli(
                                "request-legacy-archive", "--repo", str(candidate),
                                "--recovery-id", recovery_id,
                                "--progress-path", f"{destination}/progress.md",
                                "--gate-progress-path", str(gate.relative_to(candidate)),
                                "--session", "fixture-session",
                            ),
                            sent,
                            before,
                            "invalid recovery packet",
                        )
                        assert not authority.exists(), (field, shape, authority)
                        assert not backup.exists(), (field, shape, backup)
                    else:
                        requested = run_cli(
                            "request-legacy-archive", "--repo", str(candidate),
                            "--recovery-id", recovery_id,
                            "--progress-path", f"{destination}/progress.md",
                            "--gate-progress-path", str(gate.relative_to(candidate)),
                            "--session", "fixture-session",
                        )
                        assert requested["state"] == "requested", (field, shape, requested)
                        approve_recovery_fixture(candidate, recovery_id, authority, gate)
                        run_cli(
                            "backup-legacy-archive", "--repo", str(candidate),
                            "--recovery-id", recovery_id,
                        )
                        audited = run_cli(
                            "audit-legacy-archive", "--repo", str(candidate),
                            "--recovery-id", recovery_id,
                        )
                        assert audited["verdict"] == "rejected", (field, shape, audited)
            candidate = new_repo(tmp, "frontmatter-terminal-delimiter")
            recovery_id = "frontmatter-terminal-delimiter"
            destination, gate = recovery_archive(candidate)
            archive_root = candidate / destination
            progress_path = archive_root / "progress.md"
            progress_text = progress_path.read_text(encoding="utf-8").replace(
                "\n---\n",
                "\nnote: ---\nphase_status: complete\n---\n",
                1,
            )
            progress_path.write_text(progress_text, encoding="utf-8")
            manifest_path = archive_root / ".archive-source-manifest.json"
            manifest = json.loads(manifest_path.read_bytes())
            progress_row = next(row for row in manifest["entries"] if row["path"] == "progress.md")
            progress_row["sha256"] = hashlib.sha256(progress_path.read_bytes()).hexdigest()
            manifest_path.write_text(
                json.dumps(manifest, sort_keys=True, separators=(",", ":")) + "\n",
                encoding="utf-8",
            )
            journal_path = archive_root / ".phase-artifact-ownership.json"
            journal = json.loads(journal_path.read_bytes())
            journal["owned"][".archive-source-manifest.json"] = hashlib.sha256(
                manifest_path.read_bytes()
            ).hexdigest()
            journal_path.write_text(
                json.dumps(journal, sort_keys=True, separators=(",", ":")) + "\n",
                encoding="utf-8",
            )
            authority = candidate / f".release-loop/recovery-authority/{recovery_id}"
            backup = candidate / f".release-loop/recovery-backups/{recovery_id}"
            assert_blocked_preserves(
                lambda: run_cli(
                    "request-legacy-archive", "--repo", str(candidate),
                    "--recovery-id", recovery_id,
                    "--progress-path", f"{destination}/progress.md",
                    "--gate-progress-path", str(gate.relative_to(candidate)),
                    "--session", "fixture-session",
                ),
                sent,
                before,
                "invalid recovery packet",
            )
            assert not authority.exists(), authority
            assert not backup.exists(), backup
            for shape in ("nested", "duplicate", "delimiter"):
                candidate = new_repo(tmp, f"frontmatter-gate-{shape}")
                recovery_id = f"frontmatter-gate-{shape}"
                destination, gate = recovery_archive(candidate)
                gate_text = gate.read_text(encoding="utf-8")
                if shape == "nested":
                    gate_text = gate_text.replace(
                        "phase_status: waiting-user\n",
                        "shadow_phase_status:\n  phase_status: waiting-user\n",
                        1,
                    )
                else:
                    if shape == "duplicate":
                        gate_text = gate_text.replace(
                            "phase_status: waiting-user\n",
                            "phase_status: waiting-user\nphase_status: complete\n",
                            1,
                        )
                    else:
                        gate_text = gate_text.replace(
                            "\n---\n",
                            "\nnote: ---\n"
                            "recovery_gate:\n"
                            "  id: legacy-archive-recovery-approval\n"
                            "  issued_at: 2026-08-30T05:00:00Z\n"
                            "  expected_answer_class: approve-exact-recovery-or-cancel\n"
                            "---\n",
                            1,
                        )
                gate.write_text(gate_text, encoding="utf-8")
                authority = candidate / f".release-loop/recovery-authority/{recovery_id}"
                backup = candidate / f".release-loop/recovery-backups/{recovery_id}"
                assert_blocked_preserves(
                    lambda candidate=candidate, recovery_id=recovery_id, destination=destination, gate=gate: run_cli(
                        "request-legacy-archive", "--repo", str(candidate),
                        "--recovery-id", recovery_id,
                        "--progress-path", f"{destination}/progress.md",
                        "--gate-progress-path", str(gate.relative_to(candidate)),
                        "--session", "fixture-session",
                    ),
                    sent,
                    before,
                    "recovery gate",
                )
                assert not authority.exists(), authority
                assert not backup.exists(), backup
        elif name == "legacy_archive_recovery_revalidates_completed_owned_rows":
            recovery_id = "revalidate-completed-owned-row"
            destination, gate = recovery_archive(repo, extra_payload=True)
            source_archive = repo / destination
            source_journal_path = source_archive / ".phase-artifact-ownership.json"
            source_journal = json.loads(source_journal_path.read_bytes())
            source_journal["owned"]["reports/evidence.md"] = hashlib.sha256(
                (source_archive / "reports/evidence.md").read_bytes()
            ).hexdigest()
            source_journal_path.write_text(
                json.dumps(source_journal, sort_keys=True, separators=(",", ":")) + "\n",
                encoding="utf-8",
            )
            run_cli(
                "request-legacy-archive", "--repo", str(repo), "--recovery-id", recovery_id,
                "--progress-path", f"{destination}/progress.md", "--gate-progress-path",
                str(gate.relative_to(repo)), "--session", "fixture-session",
            )
            authority = repo / f".release-loop/recovery-authority/{recovery_id}"
            approve_recovery_fixture(repo, recovery_id, authority, gate)
            run_cli("backup-legacy-archive", "--repo", str(repo), "--recovery-id", recovery_id)
            run_cli("audit-legacy-archive", "--repo", str(repo), "--recovery-id", recovery_id)
            restored = run_cli("restore-legacy-archive", "--repo", str(repo), "--recovery-id", recovery_id)
            completed = repo / str(restored["progress_path"]).rsplit("/", 1)[0]
            journal_path = completed / ".phase-artifact-ownership.json"
            journal = json.loads(journal_path.read_bytes())
            assert journal["owned"].pop("reports/evidence.md")
            journal_path.write_text(
                json.dumps(journal, sort_keys=True, separators=(",", ":")) + "\n",
                encoding="utf-8",
            )
            completed_before = filesystem_manifest(completed)
            authority_before = filesystem_manifest(authority)
            assert_blocked_preserves(
                lambda: run_cli("restore-legacy-archive", "--repo", str(repo), "--recovery-id", recovery_id),
                sent,
                before,
                "archive",
            )
            assert filesystem_manifest(completed) == completed_before
            assert filesystem_manifest(authority) == authority_before
        elif name == "legacy_archive_recovery_markdown_heading_boundaries":
            spec = importlib.util.spec_from_file_location("recovery_heading_boundaries", CLI)
            assert spec is not None and spec.loader is not None
            integrity = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(integrity)
            exact_title = "Release-loop pre-archive verification V2: Verify the archived generation"
            malformed_title = "Release-loop pre-archive verification V02 Invalid"
            cases = (
                ("fenced", f"```markdown\n## {malformed_title}\n```\n", "absent-legacy-shape"),
                ("atx-1", f" # {malformed_title}\n", "malformed"),
                ("atx-2", f"  ## {malformed_title}\n", "malformed"),
                ("atx-3", f"   ## {malformed_title}\n", "malformed"),
                ("setext-equals", f"{malformed_title}\n===\n", "malformed"),
                ("setext-dashes", f"{malformed_title}\n---\n", "malformed"),
                ("supported-atx-3", f"   ## {exact_title}\n\n{integrity.CONTRACT_V2_BODY}", "supported"),
            )
            for label, text, expected in cases:
                observed = integrity.classify_pre_archive_contract(text)
                assert observed["classification"] == expected, (label, observed)
        elif name == "legacy_archive_recovery_rejects_plan_frontmatter_attacks":
            for variant in (
                "missing-body-seal",
                "duplicate-body-seal",
                "mismatch-body-seal",
                "duplicate-status",
                "delimiter-body-seal-shadow",
                "delimiter-status-shadow",
            ):
                candidate = new_repo(tmp, f"plan-frontmatter-{variant}")
                recovery_id = f"plan-frontmatter-{variant}"
                destination, gate = recovery_archive(candidate, plan_variant=variant)
                archive_root = candidate / destination
                archive_before = filesystem_manifest(archive_root)
                requested = run_cli(
                    "request-legacy-archive", "--repo", str(candidate),
                    "--recovery-id", recovery_id,
                    "--progress-path", f"{destination}/progress.md",
                    "--gate-progress-path", str(gate.relative_to(candidate)),
                    "--session", "fixture-session",
                )
                assert requested["state"] == "requested", (variant, requested)
                authority = candidate / f".release-loop/recovery-authority/{recovery_id}"
                backup = candidate / f".release-loop/recovery-backups/{recovery_id}"
                approve_recovery_fixture(candidate, recovery_id, authority, gate)
                run_cli("backup-legacy-archive", "--repo", str(candidate), "--recovery-id", recovery_id)
                request = json.loads((authority / "request.json").read_bytes())
                git(
                    candidate,
                    "merge-base",
                    "--is-ancestor",
                    str(request["plan_approval_commit"]),
                    str(request["contract_introduction_commit"]),
                )
                audited = run_cli(
                    "audit-legacy-archive", "--repo", str(candidate), "--recovery-id", recovery_id,
                )
                assert audited["verdict"] == "rejected", (variant, audited)
                audit = json.loads((authority / "audit.json").read_bytes())
                assert audit["failure"]["class"] == "recovery provenance", (variant, audit)
                expected_detail = {
                    "missing-body-seal": "body_seal",
                    "duplicate-body-seal": "body_seal",
                    "mismatch-body-seal": "sealed plan bytes mismatch",
                    "duplicate-status": "status",
                    "delimiter-body-seal-shadow": "body_seal",
                    "delimiter-status-shadow": "status",
                }[variant]
                assert expected_detail in audit["failure"]["detail"].lower(), (variant, audit)
                audit_before = (authority / "audit.json").read_bytes()
                assert_blocked_preserves(
                    lambda candidate=candidate, recovery_id=recovery_id: run_cli(
                        "restore-legacy-archive", "--repo", str(candidate),
                        "--recovery-id", recovery_id,
                    ),
                    sent,
                    before,
                    "recovery restore",
                )
                assert (authority / "audit.json").read_bytes() == audit_before
                assert filesystem_manifest(archive_root) == archive_before
                assert not (candidate / ".release-loop/runs/alpha").exists()
                assert filesystem_manifest(backup)
        elif name == "legacy_archive_recovery_rejects_body_structural_authority":
            def body_block(text: str, block_name: str, duplicate: bool) -> str:
                lines = text.splitlines(keepends=True)
                start = next(index for index, line in enumerate(lines) if line == f"{block_name}:\n")
                end = start + 1
                while end < len(lines) and lines[end].startswith("  "):
                    end += 1
                block = "".join(lines[start:end])
                if not duplicate:
                    del lines[start:end]
                return "".join(lines).rstrip("\n") + "\n\n" + block

            def reseal_archive_progress(archive_root: Path) -> None:
                progress_path = archive_root / "progress.md"
                manifest_path = archive_root / ".archive-source-manifest.json"
                manifest = json.loads(manifest_path.read_bytes())
                progress_row = next(row for row in manifest["entries"] if row["path"] == "progress.md")
                progress_row["sha256"] = hashlib.sha256(progress_path.read_bytes()).hexdigest()
                manifest_path.write_text(
                    json.dumps(manifest, sort_keys=True, separators=(",", ":")) + "\n",
                    encoding="utf-8",
                )
                journal_path = archive_root / ".phase-artifact-ownership.json"
                journal = json.loads(journal_path.read_bytes())
                journal["owned"][".archive-source-manifest.json"] = hashlib.sha256(
                    manifest_path.read_bytes()
                ).hexdigest()
                journal_path.write_text(
                    json.dumps(journal, sort_keys=True, separators=(",", ":")) + "\n",
                    encoding="utf-8",
                )

            for block_name in ("recovery_gate", "final_action"):
                for duplicate in (False, True):
                    label = "duplicate" if duplicate else "body-only"
                    candidate = new_repo(tmp, f"body-structure-{block_name}-{label}")
                    recovery_id = f"body-{block_name.replace('_', '-')}-{label}"
                    destination, gate = recovery_archive(candidate)
                    if block_name == "recovery_gate":
                        gate.write_text(
                            body_block(gate.read_text(encoding="utf-8"), block_name, duplicate),
                            encoding="utf-8",
                        )
                    else:
                        archive_root = candidate / destination
                        progress_path = archive_root / "progress.md"
                        progress_path.write_text(
                            body_block(progress_path.read_text(encoding="utf-8"), block_name, duplicate),
                            encoding="utf-8",
                        )
                        reseal_archive_progress(archive_root)
                    authority = candidate / f".release-loop/recovery-authority/{recovery_id}"
                    backup = candidate / f".release-loop/recovery-backups/{recovery_id}"
                    if block_name == "recovery_gate":
                        if duplicate:
                            requested = run_cli(
                                "request-legacy-archive", "--repo", str(candidate),
                                "--recovery-id", recovery_id,
                                "--progress-path", f"{destination}/progress.md",
                                "--gate-progress-path", str(gate.relative_to(candidate)),
                                "--session", "fixture-session",
                            )
                            assert requested["state"] == "requested", (label, requested)
                        else:
                            assert_blocked_preserves(
                                lambda candidate=candidate, recovery_id=recovery_id, destination=destination, gate=gate: run_cli(
                                    "request-legacy-archive", "--repo", str(candidate),
                                    "--recovery-id", recovery_id,
                                    "--progress-path", f"{destination}/progress.md",
                                    "--gate-progress-path", str(gate.relative_to(candidate)),
                                    "--session", "fixture-session",
                                ),
                                sent,
                                before,
                                "recovery gate",
                            )
                            assert not authority.exists(), (block_name, label, authority)
                            assert not backup.exists(), (block_name, label, backup)
                    else:
                        requested = run_cli(
                            "request-legacy-archive", "--repo", str(candidate),
                            "--recovery-id", recovery_id,
                            "--progress-path", f"{destination}/progress.md",
                            "--gate-progress-path", str(gate.relative_to(candidate)),
                            "--session", "fixture-session",
                        )
                        assert requested["state"] == "requested", (label, requested)
                        approve_recovery_fixture(candidate, recovery_id, authority, gate)
                        run_cli(
                            "backup-legacy-archive", "--repo", str(candidate),
                            "--recovery-id", recovery_id,
                        )
                        audited = run_cli(
                            "audit-legacy-archive", "--repo", str(candidate),
                            "--recovery-id", recovery_id,
                        )
                        if duplicate:
                            assert audited["verdict"] == "accepted", (label, audited)
                        else:
                            assert audited["verdict"] == "rejected", (label, audited)
                            audit_before = (authority / "audit.json").read_bytes()
                            assert_blocked_preserves(
                                lambda candidate=candidate, recovery_id=recovery_id: run_cli(
                                    "restore-legacy-archive", "--repo", str(candidate),
                                    "--recovery-id", recovery_id,
                                ),
                                sent,
                                before,
                                "recovery restore",
                            )
                            assert (authority / "audit.json").read_bytes() == audit_before

            for duplicate in (False, True):
                label = "duplicate" if duplicate else "body-only"
                candidate = new_repo(tmp, f"body-structure-receipt-{label}")
                recovery_id = f"body-receipt-{label}"
                destination, gate = recovery_archive(candidate)
                run_cli(
                    "request-legacy-archive", "--repo", str(candidate),
                    "--recovery-id", recovery_id,
                    "--progress-path", f"{destination}/progress.md",
                    "--gate-progress-path", str(gate.relative_to(candidate)),
                    "--session", "fixture-session",
                )
                authority = candidate / f".release-loop/recovery-authority/{recovery_id}"
                write_recovery_gate_approval_fixture(authority, gate)
                gate.write_text(
                    body_block(gate.read_text(encoding="utf-8"), "recovery_gate_receipt", duplicate),
                    encoding="utf-8",
                )
                if duplicate:
                    approved = run_cli(
                        "request-legacy-archive", "--repo", str(candidate),
                        "--recovery-id", recovery_id, "--publish-approval",
                    )
                    assert approved["state"] == "approved", approved
                else:
                    authority_before = filesystem_manifest(authority)
                    assert_blocked_preserves(
                        lambda candidate=candidate, recovery_id=recovery_id: run_cli(
                            "request-legacy-archive", "--repo", str(candidate),
                            "--recovery-id", recovery_id, "--publish-approval",
                        ),
                        sent,
                        before,
                        "recovery gate",
                    )
                    assert filesystem_manifest(authority) == authority_before
                    assert not (authority / "approval.json").exists()
        elif name == "legacy_archive_recovery_timestamps_each_generation":
            spec = importlib.util.spec_from_file_location("recovery_timestamp_fixture", CLI)
            assert spec is not None and spec.loader is not None
            integrity = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(integrity)
            recovery_id = "generation-timestamps"
            destination, authority, backup = prepare_recovery_for_restore(repo, recovery_id)
            source_archive = repo / destination
            source_before = filesystem_manifest(source_archive)
            backup_before = filesystem_manifest(backup)
            request = json.loads((authority / "request.json").read_bytes())
            issued = datetime.fromisoformat(str(request["issued_at"]).replace("Z", "+00:00"))
            target = repo / ".release-loop/runs/alpha"
            temporary = target / ".progress.md.recovery.tmp"

            def evidence_timestamp(text: str, token: str) -> datetime:
                matches = re.findall(rf"^- ([^ ]+) {re.escape(token)}", text, re.MULTILINE)
                assert len(matches) == 1, (token, matches)
                return datetime.fromisoformat(matches[0].replace("Z", "+00:00"))

            def top_updated(text: str) -> datetime:
                frontmatter = text.split("---", 2)[1]
                matches = [
                    line.split(":", 1)[1].strip()
                    for line in frontmatter.splitlines()
                    if line.startswith("updated:")
                ]
                assert len(matches) == 1, matches
                return datetime.fromisoformat(matches[0].replace("Z", "+00:00"))

            generations: list[tuple[str, bytes, datetime]] = []
            for stage, hook, token in (
                ("g1", "recovery-progress-g1-temp-only", "legacy_archive_recovery: staged:"),
                ("g2", "recovery-progress-g2-temp-only", "legacy-pre-archive-verification: accepted:"),
                ("g3", "recovery-progress-g3-temp-only", "legacy_archive_recovery: completed:"),
            ):
                assert_blocked_preserves(
                    lambda hook=hook: run_cli(
                        "restore-legacy-archive", "--repo", str(repo),
                        "--recovery-id", recovery_id, failure=hook,
                    ),
                    sent,
                    before,
                    "injected recovery interruption",
                )
                assert temporary.is_file(), (stage, temporary)
                temporary_bytes = temporary.read_bytes()
                temporary_text = temporary_bytes.decode("utf-8")
                timestamp = evidence_timestamp(temporary_text, token)
                assert top_updated(temporary_text) == timestamp, (stage, temporary_text)
                assert timestamp >= issued, (stage, issued, timestamp)
                if generations:
                    prior_stage, prior_bytes, prior_timestamp = generations[-1]
                    assert timestamp >= prior_timestamp, (prior_stage, stage, prior_timestamp, timestamp)
                    assert (target / "progress.md").read_bytes() == prior_bytes
                    assert temporary_text.count(token) == 1, (stage, temporary_text)
                    target_fd = os.open(target, os.O_RDONLY | getattr(os, "O_DIRECTORY", 0))
                    try:
                        predecessor = integrity.recovery_generation_at(
                            target_fd,
                            exclude=integrity.RECOVERY_TRANSIENT_NAMES,
                        )
                    finally:
                        os.close(target_fd)
                    assert f"{prior_stage}-sha256={predecessor}" in temporary_text, (
                        stage,
                        predecessor,
                        temporary_text,
                    )
                generations.append((stage, temporary_bytes, timestamp))

            resumed = run_cli(
                "restore-legacy-archive", "--repo", str(repo), "--recovery-id", recovery_id,
            )
            assert resumed["state"] == "archived", resumed
            completed = repo / str(resumed["progress_path"])
            completed_text = completed.read_text(encoding="utf-8")
            assert completed.read_bytes() == generations[-1][1]
            for _stage, _bytes, timestamp in generations:
                assert completed_text.count(timestamp.isoformat().replace("+00:00", "Z")) >= 1
            assert not target.exists(), target
            assert filesystem_manifest(source_archive) == source_before
            assert filesystem_manifest(backup) == backup_before

            rollback_repo = new_repo(tmp, "generation-timestamp-rollback")
            rollback_id = "generation-timestamp-rollback"
            rollback_destination, rollback_authority, rollback_backup = prepare_recovery_for_restore(
                rollback_repo,
                rollback_id,
            )
            assert_blocked_preserves(
                lambda: run_cli(
                    "restore-legacy-archive", "--repo", str(rollback_repo),
                    "--recovery-id", rollback_id,
                    failure="recovery-progress-g1-temp-only",
                ),
                sent,
                before,
                "injected recovery interruption",
            )
            rollback_target = rollback_repo / ".release-loop/runs/alpha"
            rollback_temporary = rollback_target / ".progress.md.recovery.tmp"
            rollback_progress = (rollback_target / "progress.md").read_text(encoding="utf-8")
            prior_updated_match = re.search(r"^updated: (\S+)$", rollback_progress, re.MULTILINE)
            assert prior_updated_match is not None
            prior_updated = prior_updated_match.group(1)
            temporary_text = rollback_temporary.read_text(encoding="utf-8")
            generated = evidence_timestamp(temporary_text, "legacy_archive_recovery: staged:")
            generated_text = generated.isoformat().replace("+00:00", "Z")
            issued_text = str(json.loads((rollback_authority / "request.json").read_bytes())["issued_at"])
            assert datetime.fromisoformat(prior_updated.replace("Z", "+00:00")) < datetime.fromisoformat(
                issued_text.replace("Z", "+00:00")
            )
            rollback_temporary.write_text(
                temporary_text.replace(generated_text, prior_updated),
                encoding="utf-8",
            )
            target_before = filesystem_manifest(rollback_target)
            authority_before = filesystem_manifest(rollback_authority)
            backup_before = filesystem_manifest(rollback_backup)
            archive_before = filesystem_manifest(rollback_repo / rollback_destination)
            assert_blocked_preserves(
                lambda: run_cli(
                    "restore-legacy-archive", "--repo", str(rollback_repo),
                    "--recovery-id", rollback_id,
                ),
                sent,
                before,
                "transition timestamp precedes prior write",
            )
            assert filesystem_manifest(rollback_target) == target_before
            assert filesystem_manifest(rollback_authority) == authority_before
            assert filesystem_manifest(rollback_backup) == backup_before
            assert filesystem_manifest(rollback_repo / rollback_destination) == archive_before
        elif name == "legacy_archive_recovery_rejects_invalid_terminal_updated":
            for variant in (
                "missing",
                "malformed",
                "future",
                "approval-after-final-action",
                "final-action-before-ship",
                "final-action-after-ship",
                "ship-after-retro",
                "updated-before-retro",
                "updated-after-retro",
            ):
                candidate = new_repo(tmp, f"terminal-updated-{variant}")
                recovery_id = f"terminal-updated-{variant}"
                destination, gate = recovery_archive(candidate)
                archive_root = candidate / destination
                progress_path = archive_root / "progress.md"
                progress_text = progress_path.read_text(encoding="utf-8")
                if variant == "missing":
                    progress_text = progress_text.replace("updated: 2026-08-30T04:59:00Z\n", "", 1)
                elif variant == "malformed":
                    progress_text = progress_text.replace(
                        "updated: 2026-08-30T04:59:00Z\n",
                        "updated: not-a-timestamp\n",
                        1,
                    )
                elif variant == "future":
                    progress_text = progress_text.replace(
                        "updated: 2026-08-30T04:59:00Z\n",
                        "updated: 9999-12-31T23:59:59Z\n",
                        1,
                    )
                elif variant == "approval-after-final-action":
                    progress_text = progress_text.replace(
                        "ship_approved: {by: user, at: 2026-08-30T04:56:00Z,",
                        "ship_approved: {by: user, at: 2026-08-30T04:58:00Z,",
                        1,
                    )
                elif variant == "final-action-before-ship":
                    progress_text = progress_text.replace(
                        "  updated: 2026-08-30T04:57:00Z\n",
                        "  updated: 2026-08-30T04:56:30Z\n",
                        1,
                    )
                elif variant == "final-action-after-ship":
                    progress_text = progress_text.replace(
                        "  updated: 2026-08-30T04:57:00Z\n",
                        "  updated: 2026-08-30T04:58:00Z\n",
                        1,
                    )
                elif variant == "ship-after-retro":
                    progress_text = progress_text.replace(
                        "- 2026-08-30T04:57:00Z ship: merged (",
                        "- 2026-08-30T05:00:00Z ship: merged (",
                        1,
                    )
                elif variant == "updated-before-retro":
                    progress_text = progress_text.replace(
                        "updated: 2026-08-30T04:59:00Z\n",
                        "updated: 2026-08-30T04:58:00Z\n",
                        1,
                    )
                elif variant == "updated-after-retro":
                    progress_text = progress_text.replace(
                        "updated: 2026-08-30T04:59:00Z\n",
                        "updated: 2026-08-30T05:00:00Z\n",
                        1,
                    )
                progress_path.write_text(progress_text, encoding="utf-8")
                manifest_path = archive_root / ".archive-source-manifest.json"
                manifest = json.loads(manifest_path.read_bytes())
                progress_row = next(row for row in manifest["entries"] if row["path"] == "progress.md")
                progress_row["sha256"] = hashlib.sha256(progress_path.read_bytes()).hexdigest()
                manifest_path.write_text(
                    json.dumps(manifest, sort_keys=True, separators=(",", ":")) + "\n",
                    encoding="utf-8",
                )
                journal_path = archive_root / ".phase-artifact-ownership.json"
                journal = json.loads(journal_path.read_bytes())
                journal["owned"][".archive-source-manifest.json"] = hashlib.sha256(
                    manifest_path.read_bytes()
                ).hexdigest()
                journal_path.write_text(
                    json.dumps(journal, sort_keys=True, separators=(",", ":")) + "\n",
                    encoding="utf-8",
                )
                archive_before = filesystem_manifest(archive_root)
                requested = run_cli(
                    "request-legacy-archive", "--repo", str(candidate),
                    "--recovery-id", recovery_id,
                    "--progress-path", f"{destination}/progress.md",
                    "--gate-progress-path", str(gate.relative_to(candidate)),
                    "--session", "fixture-session",
                )
                assert requested["state"] == "requested", (variant, requested)
                authority = candidate / f".release-loop/recovery-authority/{recovery_id}"
                backup = candidate / f".release-loop/recovery-backups/{recovery_id}"
                approve_recovery_fixture(candidate, recovery_id, authority, gate)
                run_cli("backup-legacy-archive", "--repo", str(candidate), "--recovery-id", recovery_id)
                audited = run_cli(
                    "audit-legacy-archive", "--repo", str(candidate), "--recovery-id", recovery_id,
                )
                assert audited["verdict"] == "rejected", (variant, audited)
                audit_before = (authority / "audit.json").read_bytes()
                authority_before = filesystem_manifest(authority)
                backup_before = filesystem_manifest(backup)
                assert not (authority / "executor-result.json").exists()
                assert not (authority / "receipt.json").exists()
                assert not (candidate / ".release-loop/runs/alpha").exists()
                assert_blocked_preserves(
                    lambda candidate=candidate, recovery_id=recovery_id: run_cli(
                        "restore-legacy-archive", "--repo", str(candidate),
                        "--recovery-id", recovery_id,
                    ),
                    sent,
                    before,
                    "recovery restore",
                )
                assert (authority / "audit.json").read_bytes() == audit_before
                assert filesystem_manifest(authority) == authority_before
                assert filesystem_manifest(backup) == backup_before
                assert filesystem_manifest(archive_root) == archive_before
                assert not (authority / "executor-result.json").exists()
                assert not (authority / "receipt.json").exists()
                assert not (candidate / ".release-loop/runs/alpha").exists()
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
        elif name == "legacy_handoff_success":
            source = repo
            base = new_repo(tmp, "base")
            legacy_path = write_legacy(source, "legacy")
            populate_legacy_active_state(legacy_path.parent)
            archive_control = base / ".release-loop/archive/2026-01-01-alpha"
            archive_control.mkdir(parents=True)
            (archive_control / "kept.txt").write_text("kept\n", encoding="utf-8")
            archive_control_before = (archive_control / "kept.txt").read_bytes()
            result = handoff_scope(source, base, str(legacy_path.relative_to(source)), legacy_destination=".release-loop")
            assert result["cleanup_permitted"] is True
            assert discover(base, ".release-loop/progress.md") == ("resume", base / ".release-loop/progress.md")
            source_manifest = filesystem_manifest(source / ".release-loop")
            base_manifest = filesystem_manifest(base / ".release-loop")
            for relative, value in source_manifest.items():
                assert base_manifest[relative] == value, relative
            assert (archive_control / "kept.txt").read_bytes() == archive_control_before
            marker = base / ".release-loop/.handoff/legacy.json"
            payload = json.loads(marker.read_text(encoding="utf-8"))
            assert payload["schema"] == "release-loop-handoff/v2", payload
            assert payload["status"] == "complete", payload
            assert payload["destination"] == ".release-loop", payload
            assert set(payload) == {
                "schema", "feature", "progress_path", "artifact_root",
                "source_worktree", "base_owner", "destination", "manifest_sha256", "status",
            }, payload
        elif name == "legacy_handoff_v1_ownership":
            valid_source = repo
            valid_base = new_repo(tmp, "v1-valid-base")
            valid_progress = write_legacy_v1(valid_source)
            (valid_progress.parent / "v1/history").mkdir()
            (valid_progress.parent / "v1/history/prior.md").write_text("prior\n", encoding="utf-8")
            result = handoff_scope(
                valid_source, valid_base, str(valid_progress.relative_to(valid_source)),
                legacy_destination=".release-loop",
            )
            assert result["cleanup_permitted"] is True
            assert filesystem_manifest(valid_source / ".release-loop/v1") == filesystem_manifest(
                valid_base / ".release-loop/v1"
            )

            pre_v1_source = new_repo(tmp, "v1-pre-v1-source")
            pre_v1_base = new_repo(tmp, "v1-pre-v1-base")
            pre_v1_progress = write_legacy(pre_v1_source)
            assert handoff_scope(
                pre_v1_source, pre_v1_base, str(pre_v1_progress.relative_to(pre_v1_source)),
                legacy_destination=".release-loop",
            )["cleanup_permitted"] is True

            def rejected_v1(slug, mutate, diagnostic="legacy V1 ownership"):
                source = new_repo(tmp, f"v1-reject-source-{slug}")
                base = new_repo(tmp, f"v1-reject-base-{slug}")
                progress_path = write_legacy_v1(source)
                mutate(source, progress_path)
                source_before = filesystem_manifest(source)
                base_before = filesystem_manifest(base)
                marker = base / ".release-loop/.handoff/legacy.json"
                try:
                    handoff_scope(
                        source, base, str(progress_path.relative_to(source)),
                        legacy_destination=".release-loop",
                    )
                except Blocked as exc:
                    assert diagnostic in str(exc), str(exc)
                else:
                    raise AssertionError(f"V1 ownership case {slug} did not block")
                assert not marker.exists(), slug
                assert filesystem_manifest(source) == source_before, slug
                assert filesystem_manifest(base) == base_before, slug

            def edit_progress(path, old, new):
                path.write_text(path.read_text(encoding="utf-8").replace(old, new, 1), encoding="utf-8")

            def replace_digest(path, prefix):
                lines = path.read_text(encoding="utf-8").splitlines(keepends=True)
                matches = [index for index, line in enumerate(lines) if line.startswith(prefix)]
                assert len(matches) == 1, (path, prefix, matches)
                lines[matches[0]] = prefix + "1" * 64 + "\n"
                path.write_text("".join(lines), encoding="utf-8")

            def remove_progress_block(path, name):
                lines = path.read_text(encoding="utf-8").splitlines(keepends=True)
                start = lines.index(f"{name}:\n")
                end = start + 1
                while end < len(lines) and lines[end].startswith("  "):
                    end += 1
                path.write_text("".join(lines[:start] + lines[end:]), encoding="utf-8")

            def remove_all_ownership(source, path):
                remove_progress_block(path, "v1")
                remove_progress_block(path, "pre_merge_verification")

            mutations = (
                ("unowned-tree", remove_all_ownership),
                ("ownership-without-official", lambda source, path: edit_progress(path, "pre_merge_verification:\n", "pre_merge_verification_missing:\n")),
                ("accepted-without-ownership", lambda source, path: edit_progress(path, "v1:\n", "v1_missing:\n")),
                ("accepted-without-tree", lambda source, path: shutil.rmtree(source / ".release-loop/v1")),
                ("started", lambda source, path: edit_progress(path, "  status: accepted\n", "  status: started\n")),
                ("official-started", lambda source, path: edit_progress(path, "pre_merge_verification:\n  id: V1\n  status: accepted\n", "pre_merge_verification:\n  id: V1\n  status: started\n")),
                ("duplicate-top", lambda source, path: edit_progress(path, "final_action:\n", "v1:\n  status: accepted\nfinal_action:\n")),
                ("duplicate-top-v1-whitespace", lambda source, path: edit_progress(path, "final_action:\n", "shadow: sentinel\nv1 :\n  status: started\nfinal_action:\n")),
                ("duplicate-top-pre-merge-whitespace", lambda source, path: edit_progress(path, "final_action:\n", "shadow: sentinel\npre_merge_verification :\n  status: started\nfinal_action:\n")),
                ("duplicate-top-v1-nbsp", lambda source, path: edit_progress(path, "final_action:\n", "shadow: sentinel\nv1\N{NO-BREAK SPACE}:\n  status: started\nfinal_action:\n")),
                ("duplicate-top-pre-merge-nbsp", lambda source, path: edit_progress(path, "final_action:\n", "shadow: sentinel\npre_merge_verification\N{NO-BREAK SPACE}:\n  status: started\nfinal_action:\n")),
                ("duplicate-top-v1-leading-space", lambda source, path: edit_progress(path, "final_action:\n", "shadow: sentinel\n v1:\n  status: started\nfinal_action:\n")),
                ("duplicate-top-pre-merge-leading-space", lambda source, path: edit_progress(path, "final_action:\n", "shadow: sentinel\n pre_merge_verification:\n  status: started\nfinal_action:\n")),
                ("duplicate-top-v1-leading-tab", lambda source, path: edit_progress(path, "final_action:\n", "shadow: sentinel\n\tv1:\n  status: started\nfinal_action:\n")),
                ("duplicate-top-pre-merge-leading-tab", lambda source, path: edit_progress(path, "final_action:\n", "shadow: sentinel\n\tpre_merge_verification:\n  status: started\nfinal_action:\n")),
                ("duplicate-nested", lambda source, path: edit_progress(path, "  accepted_at:", "  status: accepted\n  accepted_at:")),
                ("malformed-indent", lambda source, path: edit_progress(path, "  pilot_approval_path:", " pilot_approval_path:")),
                ("missing-key", lambda source, path: edit_progress(path, "  accepted_at: 2026-08-23T00:00:00Z\n", "")),
                ("empty-key", lambda source, path: edit_progress(path, "  accepted_at: 2026-08-23T00:00:00Z", "  accepted_at:")),
                ("unknown-key", lambda source, path: edit_progress(path, "  accepted_at:", "  unknown: value\n  accepted_at:")),
                ("alias-path", lambda source, path: edit_progress(path, "pilot-approval.md", "v1/pilot-approval.md")),
                ("renamed-path", lambda source, path: edit_progress(path, "pilot-approval.md", "pilot-approval-renamed.md")),
                ("outside-path", lambda source, path: edit_progress(path, ".release-loop/v1/pilot-approval.md", "../pilot-approval.md")),
                ("duplicate-path", lambda source, path: edit_progress(path, ".release-loop/v1/full-approval.md", ".release-loop/v1/pilot-approval.md")),
                ("unexpected-child", lambda source, path: (source / ".release-loop/v1/foreign.md").write_text("foreign\n", encoding="utf-8")),
                ("missing-file", lambda source, path: (source / ".release-loop/v1/full-approval.md").unlink()),
                ("invalid-digest", lambda source, path: edit_progress(path, "  pilot_receipt_sha256: ", "  pilot_receipt_sha256: xyz # ")),
                ("ledger-receipt-mismatch", lambda source, path: replace_digest(path, "  pilot_receipt_sha256: ")),
                ("embedded-receipt-mismatch", lambda source, path: replace_digest(source / ".release-loop/v1/full-receipt.md", "- receipt_sha256: ")),
                ("computed-receipt-mismatch", lambda source, path: edit_progress(source / ".release-loop/v1/pilot-receipt.md", "- verdict: pass\n", "- verdict: changed\n")),
                ("generation-ledger-mismatch", lambda source, path: edit_progress(path, "  generation_sha256: ", "  generation_sha256: " + "0" * 64 + " # ")),
                ("generation-file-mismatch", lambda source, path: (source / ".release-loop/v1/generation-manifest.sha256").write_text("changed\n", encoding="utf-8")),
                ("root-symlink", lambda source, path: ((source / ".release-loop/v1").rename(source / ".release-loop/v1-real"), (source / ".release-loop/v1").symlink_to(source / ".release-loop/v1-real", target_is_directory=True))),
                ("file-symlink", lambda source, path: ((source / ".release-loop/v1/pilot-approval.md").unlink(), (source / ".release-loop/v1/pilot-approval.md").symlink_to(source / "README.md"))),
            )
            for slug, mutate in mutations:
                rejected_v1(slug, mutate)
        elif name == "legacy_handoff_v1_success":
            source = repo
            base = new_repo(tmp, "v1-success-base")
            legacy_path = write_legacy_v1(source)
            history = legacy_path.parent / "v1/history/nested"
            history.mkdir(parents=True)
            (history / "prior.md").write_bytes(b"prior\x00bytes\n")
            source_manifest = filesystem_manifest(legacy_path.parent / "v1")
            result = handoff_scope(
                source, base, str(legacy_path.relative_to(source)),
                legacy_destination=".release-loop",
            )
            assert result["cleanup_permitted"] is True
            assert filesystem_manifest(base / ".release-loop/v1") == source_manifest
            assert (base / ".release-loop/progress.md").read_bytes() == legacy_path.read_bytes()
            assert discover(base, ".release-loop/progress.md") == (
                "resume", base / ".release-loop/progress.md",
            )
        elif name == "legacy_handoff_v1_partial_directory_rerun":
            source = repo
            base = new_repo(tmp, "v1-partial-base")
            legacy_path = write_legacy_v1(source)
            history = legacy_path.parent / "v1/history"
            history.mkdir()
            (history / "prior.md").write_text("prior\n", encoding="utf-8")
            source_before = matrix_fixture_snapshot(source)
            try:
                handoff_scope(
                    source, base, str(legacy_path.relative_to(source)),
                    legacy_destination=".release-loop", failure="handoff-after-copy-one-file",
                )
            except Blocked as exc:
                assert "injected handoff interruption" in str(exc), str(exc)
            else:
                raise AssertionError("V1 file-level interruption did not fire")
            assert matrix_fixture_snapshot(source) == source_before
            marker = base / ".release-loop/.handoff/legacy.json"
            marker_before_retry = marker.read_bytes()
            assert json.loads(marker_before_retry)["status"] == "incomplete"
            partial = filesystem_manifest(base / ".release-loop/v1")
            complete = filesystem_manifest(source / ".release-loop/v1")
            assert partial and partial != complete
            assert all(complete.get(relative) == value for relative, value in partial.items())
            result = handoff_scope(
                source, base, str(legacy_path.relative_to(source)),
                legacy_destination=".release-loop",
            )
            assert result["cleanup_permitted"] is True
            assert filesystem_manifest(base / ".release-loop/v1") == complete
        elif name == "legacy_handoff_v1_destination_mismatch":
            markerless_source = new_repo(tmp, "v1-mismatch-source-markerless")
            markerless_base = new_repo(tmp, "v1-mismatch-base-markerless")
            markerless_progress = write_legacy_v1(markerless_source)
            markerless_target = markerless_base / ".release-loop/v1"
            markerless_target.mkdir(parents=True)
            (markerless_target / "pilot-approval.md").write_bytes(
                (markerless_source / ".release-loop/v1/pilot-approval.md").read_bytes()
            )
            assert_blocked_snapshots(
                lambda: handoff_scope(
                    markerless_source, markerless_base,
                    str(markerless_progress.relative_to(markerless_source)),
                    legacy_destination=".release-loop",
                ),
                markerless_source, markerless_base, "collision",
            )
            assert not (markerless_base / ".release-loop/.handoff/legacy.json").exists()

            index_source = new_repo(tmp, "v1-mismatch-source-markerless-index")
            index_base = new_repo(tmp, "v1-mismatch-base-markerless-index")
            index_progress = write_legacy_v1(index_source)
            indexed = index_base / ".release-loop/v1/index-only.md"
            indexed.parent.mkdir(parents=True)
            indexed.write_text("indexed\n", encoding="utf-8")
            git(index_base, "add", "-f", str(indexed.relative_to(index_base)))
            indexed.unlink()
            indexed.parent.rmdir()
            assert not (index_base / ".release-loop/v1").exists()
            assert_blocked_snapshots(
                lambda: handoff_scope(
                    index_source, index_base, str(index_progress.relative_to(index_source)),
                    legacy_destination=".release-loop",
                ),
                index_source, index_base, "collision",
            )
            assert not (index_base / ".release-loop/.handoff/legacy.json").exists()
            for mutation in ("changed", "extra", "index-only"):
                source = new_repo(tmp, f"v1-mismatch-source-{mutation}")
                base = new_repo(tmp, f"v1-mismatch-base-{mutation}")
                legacy_path = write_legacy_v1(source)
                try:
                    handoff_scope(
                        source, base, str(legacy_path.relative_to(source)),
                        legacy_destination=".release-loop", failure="handoff-after-copy-one-file",
                    )
                except Blocked:
                    pass
                else:
                    raise AssertionError("V1 file-level interruption did not fire")
                if mutation == "changed":
                    partial_file = next(
                        path for path in (base / ".release-loop/v1").rglob("*")
                        if path.is_file()
                    )
                    partial_file.write_bytes(b"changed\n")
                elif mutation == "extra":
                    (base / ".release-loop/v1/extra.md").write_text("extra\n", encoding="utf-8")
                else:
                    indexed = base / ".release-loop/v1/index-only.md"
                    indexed.write_text("indexed\n", encoding="utf-8")
                    git(base, "add", "-f", str(indexed.relative_to(base)))
                    indexed.unlink()
                assert_blocked_snapshots(
                    lambda: handoff_scope(
                        source, base, str(legacy_path.relative_to(source)),
                        legacy_destination=".release-loop",
                    ),
                    source, base, "collision" if mutation == "index-only" else "mismatch",
                )
        elif name == "legacy_handoff_v1_symlinks":
            for mutation in ("root", "nested"):
                source = new_repo(tmp, f"v1-symlink-source-{mutation}")
                base = new_repo(tmp, f"v1-symlink-base-{mutation}")
                legacy_path = write_legacy_v1(source)
                if mutation == "root":
                    root = source / ".release-loop/v1"
                    root.rename(source / ".release-loop/v1-real")
                    root.symlink_to(source / ".release-loop/v1-real", target_is_directory=True)
                else:
                    history = source / ".release-loop/v1/history"
                    history.mkdir()
                    (history / "linked.md").symlink_to(source / "README.md")
                assert_blocked_snapshots(
                    lambda: handoff_scope(
                        source, base, str(legacy_path.relative_to(source)),
                        legacy_destination=".release-loop",
                    ),
                    source, base, "V1 root" if mutation == "root" else "symlink",
                )
                assert not (base / ".release-loop/.handoff/legacy.json").exists()

            destination_root_source = new_repo(tmp, "v1-destination-root-symlink-source")
            destination_root_base = new_repo(tmp, "v1-destination-root-symlink-base")
            destination_root_progress = write_legacy_v1(destination_root_source)
            destination_real = destination_root_base / ".release-loop/v1-real"
            destination_real.mkdir(parents=True)
            (destination_root_base / ".release-loop/v1").symlink_to(
                destination_real, target_is_directory=True
            )
            assert_blocked_snapshots(
                lambda: handoff_scope(
                    destination_root_source, destination_root_base,
                    str(destination_root_progress.relative_to(destination_root_source)),
                    legacy_destination=".release-loop",
                ),
                destination_root_source, destination_root_base, "symlink",
            )
            assert not (destination_root_base / ".release-loop/.handoff/legacy.json").exists()

            destination_nested_source = new_repo(tmp, "v1-destination-nested-symlink-source")
            destination_nested_base = new_repo(tmp, "v1-destination-nested-symlink-base")
            destination_nested_progress = write_legacy_v1(destination_nested_source)
            try:
                handoff_scope(
                    destination_nested_source, destination_nested_base,
                    str(destination_nested_progress.relative_to(destination_nested_source)),
                    legacy_destination=".release-loop", failure="handoff-after-copy-one-file",
                )
            except Blocked:
                pass
            else:
                raise AssertionError("V1 file-level interruption did not fire")
            nested_link = destination_nested_base / ".release-loop/v1/linked.md"
            nested_link.symlink_to(destination_nested_base / "README.md")
            assert_blocked_snapshots(
                lambda: handoff_scope(
                    destination_nested_source, destination_nested_base,
                    str(destination_nested_progress.relative_to(destination_nested_source)),
                    legacy_destination=".release-loop",
                ),
                destination_nested_source, destination_nested_base, "symlink",
            )
        elif name == "legacy_handoff_source_changed":
            source = repo
            base = new_repo(tmp, "v1-source-changed-base")
            legacy_path = write_legacy_v1(source)
            try:
                handoff_scope(
                    source, base, str(legacy_path.relative_to(source)),
                    legacy_destination=".release-loop", failure="handoff-after-copy-one-file",
                )
            except Blocked:
                pass
            else:
                raise AssertionError("V1 file-level interruption did not fire")
            (source / ".release-loop/v1/generation-receipt.md").write_text("changed\n", encoding="utf-8")
            assert_blocked_snapshots(
                lambda: handoff_scope(
                    source, base, str(legacy_path.relative_to(source)),
                    legacy_destination=".release-loop",
                ),
                source, base, "active manifest changed",
            )
        elif name == "legacy_handoff_complete_rerun":
            source = repo
            base = new_repo(tmp, "v1-complete-rerun-base")
            legacy_path = write_legacy_v1(source)
            first = handoff_scope(
                source, base, str(legacy_path.relative_to(source)),
                legacy_destination=".release-loop",
            )
            before = filesystem_manifest(base / ".release-loop")
            second = handoff_scope(
                source, base, str(legacy_path.relative_to(source)),
                legacy_destination=".release-loop",
            )
            assert first["cleanup_permitted"] is True and second["cleanup_permitted"] is True
            assert filesystem_manifest(base / ".release-loop") == before
        elif name == "legacy_handoff_cli_contract":
            missing_source = new_repo(tmp, "cli-missing-source")
            missing_base = new_repo(tmp, "cli-missing-base")
            missing_legacy = write_legacy(missing_source, "legacy")
            assert_blocked_preserves(
                lambda: handoff_scope(missing_source, missing_base, str(missing_legacy.relative_to(missing_source))),
                sent, before, "path boundary",
            )
            ok_source = new_repo(tmp, "cli-ok-source")
            ok_base = new_repo(tmp, "cli-ok-base")
            ok_legacy = write_legacy(ok_source, "legacy")
            ok_result = handoff_scope(ok_source, ok_base, str(ok_legacy.relative_to(ok_source)), legacy_destination=".release-loop")
            assert ok_result["cleanup_permitted"] is True
            wrong_source = new_repo(tmp, "cli-wrong-source")
            wrong_base = new_repo(tmp, "cli-wrong-base")
            wrong_legacy = write_legacy(wrong_source, "legacy")
            assert_blocked_preserves(
                lambda: handoff_scope(wrong_source, wrong_base, str(wrong_legacy.relative_to(wrong_source)), legacy_destination="other"),
                sent, before, "path boundary",
            )
            scoped_source = new_repo(tmp, "cli-scoped-source")
            scoped_base = new_repo(tmp, "cli-scoped-base")
            scoped_path = initialize(scoped_source, "alpha")
            assert_blocked_preserves(
                lambda: handoff_scope(scoped_source, scoped_base, str(scoped_path.relative_to(scoped_source)), legacy_destination=".release-loop"),
                sent, before, "path boundary",
            )
            marker_source = new_repo(tmp, "cli-marker-source")
            marker_base = new_repo(tmp, "cli-marker-base")
            marker_legacy = write_legacy(marker_source, "legacy")
            assert_blocked_preserves(
                lambda: handoff_scope(
                    marker_source, marker_base, str(marker_legacy.relative_to(marker_source)),
                    marker_path=".release-loop/.handoff/other.json", legacy_destination=".release-loop",
                ),
                sent, before, "path boundary",
            )
        elif name == "legacy_handoff_incomplete_rerun":
            source = repo
            base = new_repo(tmp, "base")
            legacy_path = write_legacy(source, "legacy")
            (legacy_path.parent / "reports").mkdir()
            (legacy_path.parent / "reports/U1.md").write_text("done\n", encoding="utf-8")
            try:
                handoff_scope(
                    source, base, str(legacy_path.relative_to(source)),
                    legacy_destination=".release-loop", failure="handoff-after-copy-one",
                )
            except Blocked as exc:
                assert "injected handoff interruption" in str(exc)
            else:
                raise AssertionError("legacy handoff interruption did not fire")
            marker = base / ".release-loop/.handoff/legacy.json"
            assert marker.is_file()
            payload = json.loads(marker.read_text(encoding="utf-8"))
            assert payload["status"] == "incomplete", payload
            assert (base / ".release-loop/progress.md").read_bytes() == legacy_path.read_bytes()
            assert not (base / ".release-loop/reports").exists()
            result = handoff_scope(source, base, str(legacy_path.relative_to(source)), legacy_destination=".release-loop")
            assert result["cleanup_permitted"] is True
            payload_after = json.loads(marker.read_text(encoding="utf-8"))
            assert payload_after["status"] == "complete", payload_after
            assert (base / ".release-loop/reports/U1.md").read_text(encoding="utf-8") == "done\n"
            assert discover(base, ".release-loop/progress.md")[0] == "resume"
        elif name == "legacy_handoff_collision":
            source = repo
            base = new_repo(tmp, "base")
            legacy_path = write_legacy(source, "legacy")
            base_legacy = write_legacy(base, "other")
            base_before = base_legacy.read_bytes()
            source_before = legacy_path.read_bytes()
            assert_blocked_preserves(
                lambda: handoff_scope(source, base, str(legacy_path.relative_to(source)), legacy_destination=".release-loop"),
                sent, before, "legacy handoff collision",
            )
            marker = base / ".release-loop/.handoff/legacy.json"
            assert not marker.exists()
            assert base_legacy.read_bytes() == base_before
            assert legacy_path.read_bytes() == source_before
        elif name == "legacy_handoff_index_collision":
            source = repo
            base = new_repo(tmp, "base")
            legacy_path = write_legacy(source, "legacy")
            tracked = base / ".release-loop/briefs/tracked.md"
            tracked.parent.mkdir(parents=True)
            tracked.write_text("tracked\n", encoding="utf-8")
            git(base, "add", "-f", str(tracked.relative_to(base)))
            tracked.unlink()
            tracked.parent.rmdir()
            status_before = git(base, "status", "--porcelain")
            assert_blocked_preserves(
                lambda: handoff_scope(source, base, str(legacy_path.relative_to(source)), legacy_destination=".release-loop"),
                sent, before, "legacy handoff collision",
            )
            marker = base / ".release-loop/.handoff/legacy.json"
            assert not marker.exists()
            assert git(base, "status", "--porcelain") == status_before
            assert not tracked.exists()
        elif name == "legacy_handoff_destination_attacks":
            source = repo
            base = new_repo(tmp, "base")
            legacy_path = write_legacy(source, "legacy")
            (legacy_path.parent / "briefs").mkdir()
            (legacy_path.parent / "briefs/U1.md").write_text("brief\n", encoding="utf-8")
            try:
                handoff_scope(
                    source, base, str(legacy_path.relative_to(source)),
                    legacy_destination=".release-loop", failure="handoff-after-copy-one",
                )
            except Blocked as exc:
                assert "injected handoff interruption" in str(exc)
            else:
                raise AssertionError("legacy handoff interruption did not fire")
            marker = base / ".release-loop/.handoff/legacy.json"
            assert marker.is_file()
            outside = tmp / "outside-destination-attack"
            outside.mkdir()
            evil = base / ".release-loop/briefs/evil"
            evil.symlink_to(outside, target_is_directory=True)
            assert_blocked_preserves(
                lambda: handoff_scope(source, base, str(legacy_path.relative_to(source)), legacy_destination=".release-loop"),
                sent, before, "path boundary",
            )
            payload = json.loads(marker.read_text(encoding="utf-8"))
            assert payload["status"] == "incomplete", payload
            assert not (base / ".release-loop/progress.md").exists()
        elif name == "legacy_handoff_source_persistent_children":
            for label in (
                "archive",
                ".handoff",
                "runs",
                "recovery-authority",
                "recovery-backups",
                "unexpected",
            ):
                slug = label.lstrip(".")
                fresh_source = new_repo(tmp, f"persistent-source-{slug}")
                fresh_base = new_repo(tmp, f"persistent-base-{slug}")
                legacy_path = write_legacy(fresh_source, "legacy")
                child_dir = legacy_path.parent / label
                child_dir.mkdir(parents=True)
                (child_dir / "file.txt").write_text("persistent\n", encoding="utf-8")
                source_before = filesystem_manifest(legacy_path.parent)
                base_before = filesystem_manifest(fresh_base / ".release-loop")
                try:
                    handoff_scope(fresh_source, fresh_base, str(legacy_path.relative_to(fresh_source)), legacy_destination=".release-loop")
                except Blocked as exc:
                    assert "legacy handoff source" in str(exc), str(exc)
                    assert f".release-loop/{label}" in str(exc), str(exc)
                else:
                    raise AssertionError(f"persistent child {label} did not block")
                assert filesystem_manifest(legacy_path.parent) == source_before
                assert filesystem_manifest(fresh_base / ".release-loop") == base_before
        elif name == "legacy_handoff_symlinks":
            outside = tmp / "outside-legacy-symlink"
            outside.mkdir()
            source_a = new_repo(tmp, "legacy-symlink-source-a")
            base_a = new_repo(tmp, "legacy-symlink-base-a")
            legacy_a = write_legacy(source_a, "legacy")
            (legacy_a.parent / "briefs").symlink_to(outside, target_is_directory=True)
            assert_blocked_preserves(
                lambda: handoff_scope(source_a, base_a, str(legacy_a.relative_to(source_a)), legacy_destination=".release-loop"),
                sent, before, "path boundary",
            )
            source_b = new_repo(tmp, "legacy-symlink-source-b")
            base_b = new_repo(tmp, "legacy-symlink-base-b")
            legacy_b = write_legacy(source_b, "legacy")
            loop_b = base_b / ".release-loop"
            loop_b.mkdir(parents=True, exist_ok=True)
            (loop_b / ".handoff").symlink_to(outside, target_is_directory=True)
            assert_blocked_preserves(
                lambda: handoff_scope(source_b, base_b, str(legacy_b.relative_to(source_b)), legacy_destination=".release-loop"),
                sent, before, "path boundary",
            )
            source_c = new_repo(tmp, "legacy-symlink-source-c")
            base_c = new_repo(tmp, "legacy-symlink-base-c")
            legacy_c = write_legacy(source_c, "legacy")
            (base_c / ".release-loop").symlink_to(outside, target_is_directory=True)
            assert_blocked_preserves(
                lambda: handoff_scope(source_c, base_c, str(legacy_c.relative_to(source_c)), legacy_destination=".release-loop"),
                sent, before, "path boundary",
            )
        elif name == "legacy_handoff_marker_schema":
            def marker_case(slug, payload_overrides=None, drop_keys=()):
                marker_source = new_repo(tmp, f"marker-schema-source-{slug}")
                marker_base = new_repo(tmp, f"marker-schema-base-{slug}")
                marker_legacy = write_legacy(marker_source, "legacy")
                populate_legacy_active_state(marker_legacy.parent)
                marker = marker_base / ".release-loop/.handoff/legacy.json"
                marker.parent.mkdir(parents=True)
                base_payload = {
                    "schema": "release-loop-handoff/v2",
                    "feature": "legacy",
                    "progress_path": ".release-loop/progress.md",
                    "artifact_root": ".release-loop",
                    "source_worktree": str(marker_source),
                    "base_owner": str(marker_base),
                    "destination": ".release-loop",
                    "manifest_sha256": "0" * 64,
                    "status": "incomplete",
                }
                if payload_overrides:
                    base_payload.update(payload_overrides)
                for key in drop_keys:
                    base_payload.pop(key, None)
                marker.write_text(json.dumps(base_payload, sort_keys=True) + "\n", encoding="utf-8")
                before_bytes = marker.read_bytes()
                try:
                    handoff_scope(marker_source, marker_base, str(marker_legacy.relative_to(marker_source)), legacy_destination=".release-loop")
                except Blocked as exc:
                    assert "legacy handoff marker" in str(exc), str(exc)
                else:
                    raise AssertionError(f"marker schema case {slug} did not block")
                assert marker.read_bytes() == before_bytes

            marker_case("unknown-schema", {"schema": "release-loop-handoff/v1"})
            marker_case("bogus-schema", {"schema": "bogus"})
            marker_case("missing-key", drop_keys=("status",))
            marker_case("bad-status", {"status": "in-progress"})

            forge_source = new_repo(tmp, "marker-schema-forge-source")
            forge_base = new_repo(tmp, "marker-schema-forge-base")
            forge_legacy = write_legacy(forge_source, "legacy")
            (forge_legacy.parent / "reports").mkdir()
            (forge_legacy.parent / "reports/U1.md").write_text("done\n", encoding="utf-8")
            handoff_scope(forge_source, forge_base, str(forge_legacy.relative_to(forge_source)), legacy_destination=".release-loop")
            (forge_base / ".release-loop/reports/U1.md").unlink()
            forge_marker = forge_base / ".release-loop/.handoff/legacy.json"
            marker_before = forge_marker.read_bytes()
            try:
                handoff_scope(forge_source, forge_base, str(forge_legacy.relative_to(forge_source)), legacy_destination=".release-loop")
            except Blocked as exc:
                assert "legacy handoff collision" in str(exc), str(exc)
            else:
                raise AssertionError("forged-complete desync did not block")
            assert forge_marker.read_bytes() == marker_before
        elif name == "legacy_handoff_complete_destination_regression":
            source = repo
            base = new_repo(tmp, "base")
            legacy_path = write_legacy(source, "legacy")
            (legacy_path.parent / "reports").mkdir()
            (legacy_path.parent / "reports/U1.md").write_text("done\n", encoding="utf-8")
            first = handoff_scope(source, base, str(legacy_path.relative_to(source)), legacy_destination=".release-loop")
            assert first["cleanup_permitted"] is True
            marker = base / ".release-loop/.handoff/legacy.json"
            marker_bytes = marker.read_bytes()
            second = handoff_scope(source, base, str(legacy_path.relative_to(source)), legacy_destination=".release-loop")
            assert second["cleanup_permitted"] is True
            assert marker.read_bytes() == marker_bytes

            for mutation in ("absent", "subset", "mismatch"):
                mutation_source = new_repo(tmp, f"regression-source-{mutation}")
                mutation_base = new_repo(tmp, f"regression-base-{mutation}")
                mutation_legacy = write_legacy(mutation_source, "legacy")
                (mutation_legacy.parent / "reports").mkdir()
                (mutation_legacy.parent / "reports/U1.md").write_text("done\n", encoding="utf-8")
                handoff_scope(mutation_source, mutation_base, str(mutation_legacy.relative_to(mutation_source)), legacy_destination=".release-loop")
                if mutation == "absent":
                    shutil.rmtree(mutation_base / ".release-loop/reports")
                elif mutation == "subset":
                    (mutation_base / ".release-loop/reports/U1.md").unlink()
                else:
                    (mutation_base / ".release-loop/progress.md").write_bytes(b"tampered\n")
                mutation_marker = mutation_base / ".release-loop/.handoff/legacy.json"
                marker_before = mutation_marker.read_bytes()
                try:
                    handoff_scope(mutation_source, mutation_base, str(mutation_legacy.relative_to(mutation_source)), legacy_destination=".release-loop")
                except Blocked as exc:
                    assert "legacy handoff collision" in str(exc), str(exc)
                else:
                    raise AssertionError(f"destination {mutation} mutation did not block")
                assert mutation_marker.read_bytes() == marker_before
        elif name == "legacy_handoff_preserves_recovery_roots":
            source = repo
            base = new_repo(tmp, "base-recovery-roots")
            legacy_path = write_legacy(source, "legacy")
            (legacy_path.parent / "reports").mkdir()
            (legacy_path.parent / "reports/U1.md").write_text("done\n", encoding="utf-8")
            for family in ("recovery-authority", "recovery-backups"):
                root = base / ".release-loop" / family / "existing"
                root.mkdir(parents=True)
                (root / "record.json").write_text(f"{family}\n", encoding="utf-8")
            before = {
                family: filesystem_manifest(base / ".release-loop" / family)
                for family in ("recovery-authority", "recovery-backups")
            }
            for family, expected in before.items():
                control = tmp / f"{family}-manifest-control"
                shutil.copytree(base / ".release-loop" / family, control)
                record = control / "existing/record.json"
                changed = bytearray(record.read_bytes())
                changed[0] ^= 1
                record.write_bytes(changed)
                observed = filesystem_manifest(control)
                assert set(observed) == set(expected)
                assert expected["existing/record.json"][0] == "file"
                assert observed["existing/record.json"][0] == "file"
                expected_payload = expected["existing/record.json"][1]
                observed_payload = observed["existing/record.json"][1]
                assert isinstance(expected_payload, bytes)
                assert isinstance(observed_payload, bytes)
                assert len(observed_payload) == len(expected_payload)
                assert sum(
                    left != right
                    for left, right in zip(
                        expected_payload,
                        observed_payload,
                    )
                ) == 1
                assert observed != expected
            handoff_scope(source, base, str(legacy_path.relative_to(source)), legacy_destination=".release-loop")
            after = {
                family: filesystem_manifest(base / ".release-loop" / family)
                for family in ("recovery-authority", "recovery-backups")
            }
            assert after == before, (before, after)
        elif name == "legacy_handoff_partial_directory_rerun":
            source = repo
            base = new_repo(tmp, "base")
            legacy_path = write_legacy(source, "legacy")
            (legacy_path.parent / "briefs").mkdir()
            (legacy_path.parent / "briefs/a.md").write_text("a\n", encoding="utf-8")
            (legacy_path.parent / "briefs/b.md").write_text("b\n", encoding="utf-8")
            try:
                handoff_scope(
                    source, base, str(legacy_path.relative_to(source)),
                    legacy_destination=".release-loop", failure="handoff-after-copy-one",
                )
            except Blocked as exc:
                assert "injected handoff interruption" in str(exc)
            else:
                raise AssertionError("legacy handoff interruption did not fire")
            marker = base / ".release-loop/.handoff/legacy.json"
            payload = json.loads(marker.read_text(encoding="utf-8"))
            assert payload["status"] == "incomplete", payload
            assert (base / ".release-loop/briefs/a.md").read_text(encoding="utf-8") == "a\n"
            assert (base / ".release-loop/briefs/b.md").read_text(encoding="utf-8") == "b\n"
            assert not (base / ".release-loop/progress.md").exists()
            (base / ".release-loop/briefs/b.md").unlink()
            result = handoff_scope(source, base, str(legacy_path.relative_to(source)), legacy_destination=".release-loop")
            assert result["cleanup_permitted"] is True
            payload_after = json.loads(marker.read_text(encoding="utf-8"))
            assert payload_after["status"] == "complete", payload_after
            assert (base / ".release-loop/briefs/a.md").read_text(encoding="utf-8") == "a\n"
            assert (base / ".release-loop/briefs/b.md").read_text(encoding="utf-8") == "b\n"
            assert discover(base, ".release-loop/progress.md")[0] == "resume"
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
                    texts[key] = texts[key].replace(invocation, mutation)
                    assert texts[key] != baseline[key], f"structural mutation target absent: {name_label}"
                    try:
                        require_contract(texts)
                    except AssertionError as exc:
                        assert name_label in str(exc), str(exc)
                    else:
                        raise AssertionError(f"structural invocation mutation escaped: {name_label}")
            for label, fragment in (
                (
                    "ordinary-lifecycle-root-families",
                    "The four ordinary lifecycle artifact-root families are",
                ),
                (
                    "internal-recovery-root-families",
                    "`recovery-authority/` and `recovery-backups/` are fixed internal persistent recovery families",
                ),
                (
                    "internal-recovery-nontransfer",
                    "They are never active transfer roots.",
                ),
                (
                    "recovery-persistent-families",
                    "`recovery-authority/` and `recovery-backups/` are persistent siblings",
                ),
                (
                    "recovery-source-rejection",
                    "At the source, legacy handoff rejects every persistent sibling",
                ),
            ):
                texts = dict(baseline)
                key = "SCHEMA" if fragment in baseline["SCHEMA"] else "HOOKS"
                texts[key] = texts[key].replace(fragment, "", 1)
                assert texts[key] != baseline[key], f"structural mutation target absent: {label}"
                try:
                    require_contract(texts)
                except AssertionError as exc:
                    assert fragment in str(exc), str(exc)
                else:
                    raise AssertionError(f"structural prose mutation escaped: {label}")
        elif name == "shipping_cleanup_contract_mutation":
            require_phase_consumer_contract()
            baseline = dict(PHASE_CONSUMERS)
            fragments = (
                ("shipping-cleanup-permitted", "shipping", "cleanup_permitted: true"),
                ("shipping-complete-marker", "shipping", ".release-loop/.handoff/<feature>.json"),
                ("shipping-base-discovery", "shipping", "exact base discovery of `.release-loop/progress.md`"),
            )
            for label, key, fragment in fragments:
                assert fragment in baseline[key], f"missing baseline fragment: {label}"
                texts = dict(baseline)
                texts[key] = texts[key].replace(fragment, "", 1)
                assert texts[key] != baseline[key], f"structural mutation target absent: {label}"
                try:
                    require_phase_consumer_contract(texts)
                except AssertionError as exc:
                    assert fragment in str(exc), str(exc)
                else:
                    raise AssertionError(f"structural cleanup mutation escaped: {label}")
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
            assert RELEASE_CORE.read_text(encoding="utf-8").count("def scoped_artifact_key(") == 1
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
                ".archive-source-manifest.json",
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
                "evidence/matrix-authority-v2.json",
                *(
                    f"evidence/{unit}/{transition}-v2-{outcome}.md"
                    for transition, unit in (("T1", "U1"), ("T2", "U3"), ("T3", "U4"), ("T4", "U1"), ("T5", "U1"), ("T6", "U2"))
                    for outcome in ("success", "forced-failure", "rerun", "compensation", "headless", "cancellation")
                ),
            )
            for index, relative in enumerate(stale):
                publish_from_cli(repo, path, relative, f"stale-{index}\n".encode(), CLI)
            real_git = shutil.which("git")
            assert real_git is not None
            signature_git_dir = tmp / "signature-git"
            signature_git_dir.mkdir()
            signature_git = signature_git_dir / "git"
            signature_git.write_text(
                "#!/usr/bin/env python3\n"
                "import os\n"
                "import sys\n"
                f"real_git = {real_git!r}\n"
                "args = sys.argv[1:]\n"
                "if args == ['rev-parse', 'HEAD'] and os.path.realpath(os.getcwd()) == os.path.realpath(os.environ['MATRIX_TEST_SOURCE_ROOT']):\n"
                "    print(os.environ['MATRIX_TEST_SOURCE_COMMIT'])\n"
                "    raise SystemExit(0)\n"
                "if args == ['log', '-1', '--format=%H', '--', 'docs/deviations/2026-08-24-final-review-integrity-correction-019.md']:\n"
                "    print(os.environ['MATRIX_TEST_ADDENDUM_COMMIT'])\n"
                "    raise SystemExit(0)\n"
                "if args and args[0] == 'log' and '--format=%G?' in args:\n"
                "    commit = args[-1]\n"
                "    if commit == os.environ['MATRIX_TEST_SOURCE_COMMIT']:\n"
                "        print(os.environ['MATRIX_TEST_SOURCE_STATUS'])\n"
                "        raise SystemExit(0)\n"
                "    if commit == os.environ['MATRIX_TEST_ADDENDUM_COMMIT']:\n"
                "        print(os.environ['MATRIX_TEST_ADDENDUM_STATUS'])\n"
                "        raise SystemExit(0)\n"
                "    print('unexpected signature commit: ' + commit, file=sys.stderr)\n"
                "    raise SystemExit(2)\n"
                "os.execv(real_git, [real_git, *args])\n",
                encoding="utf-8",
            )
            signature_git.chmod(0o755)
            source_commit = "1" * 40
            addendum_commit = "2" * 40
            unknown_commit = "3" * 40
            probe_environment = {
                **os.environ,
                "MATRIX_TEST_SOURCE_COMMIT": source_commit,
                "MATRIX_TEST_SOURCE_ROOT": str(ROOT),
                "MATRIX_TEST_SOURCE_STATUS": "G",
                "MATRIX_TEST_ADDENDUM_COMMIT": addendum_commit,
                "MATRIX_TEST_ADDENDUM_STATUS": "E",
            }

            def probe_signature(commit: str):
                return subprocess.run(
                    (str(signature_git), "log", "-1", "--format=%G?", commit),
                    env=probe_environment,
                    text=True,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE,
                    check=False,
                )

            assert [probe_signature(source_commit).stdout.strip() for _ in range(2)] == ["G", "G"]
            assert [probe_signature(addendum_commit).stdout.strip() for _ in range(2)] == ["E", "E"]
            assert probe_signature(unknown_commit).returncode != 0

            def run_evidence(source_status: str = "G", addendum_status: str = "G", failure_after: str | None = None):
                environment = os.environ.copy()
                environment.update({
                    "PATH": str(signature_git_dir) + os.pathsep + environment.get("PATH", ""),
                    "MATRIX_TEST_SOURCE_COMMIT": source_commit,
                    "MATRIX_TEST_SOURCE_ROOT": str(ROOT),
                    "MATRIX_TEST_SOURCE_STATUS": source_status,
                    "MATRIX_TEST_ADDENDUM_COMMIT": addendum_commit,
                    "MATRIX_TEST_ADDENDUM_STATUS": addendum_status,
                })
                if failure_after is None:
                    environment.pop("RUN_ARTIFACT_MATRIX_TEST_FAIL_AFTER", None)
                else:
                    environment["RUN_ARTIFACT_MATRIX_TEST_FAIL_AFTER"] = failure_after
                return subprocess.run(
                    (
                        sys.executable,
                        str(EVIDENCE_CLI),
                        "--repo", str(repo),
                        "--progress-path", path.relative_to(repo).as_posix(),
                    ),
                    cwd=ROOT,
                    env=environment,
                    text=True,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE,
                    check=False,
                )

            source_rejected = run_evidence(source_status="E")
            assert source_rejected.returncode != 0 and source_rejected.stderr.strip() == "matrix evidence signed source commit required"
            addendum_rejected = run_evidence(addendum_status="E")
            assert addendum_rejected.returncode != 0 and addendum_rejected.stderr.strip() == "matrix evidence signed addendum commit required"
            interrupted = run_evidence(failure_after="5")
            assert interrupted.returncode != 0 and "injected matrix evidence interruption" in interrupted.stderr
            result = run_evidence()
            assert result.returncode == 0, result.stderr
            payload = json.loads(result.stdout)
            assert payload["state"] == "published" and payload["record_count"] == 36
            manifest = path.parent / "evidence/matrix-authority-v3.json"
            authority = json.loads(manifest.read_text(encoding="utf-8"))
            assert len(authority["records"]) == 36 and len(authority["supersedes"]) == len(stale)
            before_manifest = manifest.read_bytes()

            def assert_authority_blocked(label: str, diagnostic: str) -> None:
                attack = run_evidence()
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
            sibling_row = next(
                row for row in authority["records"]
                if row["transition"] == "T4-v3" and row["outcome"] == "success"
            )
            sibling_record = repo / sibling_row["path"]
            sibling_bytes = sibling_record.read_bytes()
            sibling_payload = json.loads(sibling_bytes)
            omitted_root = next(
                row["repo"] for row in sibling_payload["root_identity"]["roots"]
                if row["kind"] == "git" and row["repo"] != sibling_payload["root_identity"]["primary_root"]
            )
            sibling_payload["root_identity"]["roots"] = [
                row for row in sibling_payload["root_identity"]["roots"] if row["repo"] != omitted_root
            ]
            sibling_record.write_text(json.dumps(sibling_payload, sort_keys=True, separators=(",", ":")) + "\n", encoding="utf-8")
            assert_authority_blocked("omitted-sibling-root", "root inventory mismatch")
            sibling_record.write_bytes(sibling_bytes)
            placeholder_record = repo / authority["records"][0]["path"]
            placeholder_bytes = placeholder_record.read_bytes()
            placeholder_payload = json.loads(placeholder_bytes)
            placeholder_payload["stub_identity"] = "<stub>"
            placeholder_record.write_text(json.dumps(placeholder_payload, sort_keys=True, separators=(",", ":")) + "\n", encoding="utf-8")
            assert_authority_blocked("placeholder", "placeholder forbidden")
            placeholder_record.write_bytes(placeholder_bytes)
            external_row = next(
                row for row in authority["records"]
                if row["transition"] == "T5-v3" and row["outcome"] == "forced-failure"
            )
            external_record = repo / external_row["path"]
            external_bytes = external_record.read_bytes()
            external_payload = json.loads(external_bytes)
            external_binding = next(
                binding
                for trace in external_payload["command_or_injection"]["inner_trace"]
                for binding in trace["path_bindings"]
                if binding["owner"] == next(
                    root["repo"] for root in external_payload["root_identity"]["roots"] if root["kind"] == "fixture"
                )
            )
            external_binding["owner"] = "external"
            external_record.write_text(json.dumps(external_payload, sort_keys=True, separators=(",", ":")) + "\n", encoding="utf-8")
            assert_authority_blocked("unbound-external", "trace root mismatch")
            external_record.write_bytes(external_bytes)
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
            journal_path = path.parent / ".phase-artifact-ownership.json"
            journal_bytes = journal_path.read_bytes()
            journal_payload = json.loads(journal_bytes)
            journal_payload["owned"].pop(stale[1])
            journal_path.write_text(json.dumps(journal_payload, sort_keys=True, separators=(",", ":")) + "\n", encoding="utf-8")
            assert_authority_blocked("unowned-stale", "publisher-owned")
            journal_path.write_bytes(journal_bytes)
            manifest.write_bytes(before_manifest)
            replay = run_evidence()
            assert replay.returncode == 0, replay.stderr
            assert json.loads(replay.stdout)["state"] == "reused"
            assert manifest.read_bytes() == before_manifest
        elif name == "fix_event_migration_validation":
            path = initialize(repo, "alpha")
            head = git(repo, "rev-parse", "HEAD")
            source_result = publish_from_cli(repo, path, "reviews/events/U3-round1.md", b"source-review\n", CLI)
            second_source_result = publish_from_cli(repo, path, "reviews/events/U4-round1.md", b"second-source-review\n", CLI)
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
                "  - id: unit:U4:1\n"
                "    kind: unit\n"
                "    subject: U4\n"
                "    ordinal: 1\n"
                "    state: complete\n"
                f"    reviewed_head: {head}\n"
                f"    result_path: {second_source_result['target']}\n"
                f"    result_sha256: {second_source_result['sha256']}\n"
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
            for invalid_ordinal in (None, "not-an-integer", True, False, 1.0, 0, -1, "01", "+1", " 1"):
                try:
                    migration.normalized_existing({"ordinal": invalid_ordinal})
                except migration.Blocked as exc:
                    assert "ledger ordinal invalid" in str(exc)
                else:
                    raise AssertionError("invalid ledger ordinal did not block")

            invalid_head = dict(base_row)
            invalid_head["reviewed_head"] = "-"
            invalid_head_path = publish_adoption("fix-history-invalid-head", [invalid_head])
            valid_progress = path.read_text(encoding="utf-8")
            path.write_text(valid_progress.replace(f"    reviewed_head: {head}\n", "    reviewed_head: -\n", 1), encoding="utf-8")
            try:
                migration.validate_migration(repo, path.relative_to(repo).as_posix(), invalid_head_path, lambda _: "G")
            except migration.Blocked as exc:
                assert "full reviewed head required" in str(exc), str(exc)
            else:
                raise AssertionError("invalid reviewed head reached Git")
            path.write_text(valid_progress, encoding="utf-8")

            for label, invalid_ordinal in (("true", True), ("false", False), ("float", 1.0), ("negative", -1), ("zero", 0)):
                invalid_row = dict(base_row)
                invalid_row["ordinal"] = invalid_ordinal
                candidate = publish_adoption("fix-history-invalid-ordinal-" + label, [invalid_row])
                try:
                    migration.validate_migration(repo, path.relative_to(repo).as_posix(), candidate, lambda _: "G")
                except migration.Blocked as exc:
                    assert "row ordinal invalid" in str(exc), (label, str(exc))
                else:
                    raise AssertionError(label + " adoption ordinal passed")

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
            source_report = dict(base_row)
            source_report["fixer_report_path"] = source_result["target"]
            source_report["fixer_report_sha256"] = source_result["sha256"]
            attacks.append(("source-report", [source_report], lambda _: "G", "not round-specific"))
            adoption_report = dict(base_row)
            adoption_report["fixer_report_path"] = (path.parent / "reviews/adoptions/fix-history-adoption-report.json").relative_to(repo).as_posix()
            attacks.append(("adoption-report", [adoption_report], lambda _: "G", "not round-specific"))
            for label, invalid_path in (("null", None), ("number", 7)):
                invalid_report_path = dict(base_row)
                invalid_report_path["fixer_report_path"] = invalid_path
                attacks.append(("invalid-report-path-" + label, [invalid_report_path], lambda _: "G", "fixer report path invalid"))
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
            duplicate_report_row = {
                **base_row,
                "id": "fix:U4:1",
                "subject": "U4",
                "source_review_event": "unit:U4:1",
            }
            duplicate_report_adoption = publish_adoption("fix-history-duplicate-report", [base_row, duplicate_report_row])
            try:
                migration.validate_migration(repo, path.relative_to(repo).as_posix(), duplicate_report_adoption, lambda _: "G")
            except migration.Blocked as exc:
                assert "duplicate fixer report path" in str(exc), str(exc)
            else:
                raise AssertionError("two migration rows reused one fixer report")

            progress_without_owner_conflict = path.read_text(encoding="utf-8")
            path.write_text(progress_without_owner_conflict + (
                "  - id: standalone:other:1\n"
                "    kind: standalone\n"
                "    subject: other\n"
                "    ordinal: 1\n"
                "    state: complete\n"
                f"    reviewed_head: {head}\n"
                f"    result_path: {fixer_report['target']}\n"
                f"    result_sha256: {fixer_report['sha256']}\n"
                "    outcome: clean\n"
                "    finding_inventory: []\n"
                "    source_review_event: null\n"
                "    re_review_of: null\n"
                "    source_adoption_path: null\n"
                "    source_adoption_sha256: null\n"
            ), encoding="utf-8")
            try:
                migration.validate_migration(repo, path.relative_to(repo).as_posix(), adoption_path, lambda _: "G")
            except migration.Blocked as exc:
                assert "duplicate fixer report path" in str(exc), str(exc)
            else:
                raise AssertionError("existing event result path was reused")
            path.write_text(progress_without_owner_conflict, encoding="utf-8")
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
        elif name == "matrix_generator_parent_symlink":
            outside = tmp / "matrix-generator-external"
            root = outside / "runs/alpha"
            root.mkdir(parents=True)
            external_progress = root / "progress.md"
            external_progress.write_text(progress("alpha", ".release-loop/runs/alpha"), encoding="utf-8")
            sentinel_file = outside / "sentinel.txt"
            sentinel_file.write_bytes(b"EXTERNAL-MATRIX-SENTINEL\n")
            before_tree = filesystem_manifest(outside)
            (repo / ".release-loop").symlink_to(outside, target_is_directory=True)
            attack = subprocess.run(
                (
                    sys.executable,
                    str(EVIDENCE_CLI),
                    "--repo", str(repo),
                    "--progress-path", ".release-loop/runs/alpha/progress.md",
                ),
                cwd=ROOT,
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                check=False,
            )
            assert attack.returncode != 0 and "path boundary" in attack.stderr
            assert filesystem_manifest(outside) == before_tree
        elif name == "fix_migration_parent_symlink":
            outside = tmp / "fix-migration-external"
            root = outside / "runs/alpha"
            root.mkdir(parents=True)
            external_progress = root / "progress.md"
            head = git(repo, "rev-parse", "HEAD")
            source = root / "reviews/events/U3-round1.md"
            report = root / "reports/U3-fix.md"
            source.parent.mkdir(parents=True)
            report.parent.mkdir(parents=True)
            source.write_bytes(b"source\n")
            report.write_bytes(b"report\n")
            source_sha = hashlib.sha256(source.read_bytes()).hexdigest()
            report_sha = hashlib.sha256(report.read_bytes()).hexdigest()
            progress_text = progress("alpha", ".release-loop/runs/alpha") + (
                "\nreview_counts:\n"
                "  completeness: partial\n"
                "  counting_started_at: 2026-08-24T00:00:00Z\n"
                "review_events:\n"
                "  - id: unit:U3:1\n"
                "    kind: unit\n"
                "    subject: U3\n"
                "    ordinal: 1\n"
                "    state: complete\n"
                f"    reviewed_head: {head}\n"
                "    result_path: .release-loop/runs/alpha/reviews/events/U3-round1.md\n"
                f"    result_sha256: {source_sha}\n"
                "    outcome: blocked\n"
                "    finding_inventory: []\n"
            )
            external_progress.write_text(progress_text, encoding="utf-8")
            adoption = root / "reviews/adoptions/fix-history.json"
            adoption.parent.mkdir(parents=True)
            adoption_payload = {
                "counting_started_at": "2026-08-24T00:00:00Z",
                "progress_path": ".release-loop/runs/alpha/progress.md",
                "rows": [{
                    "fix_commit": head,
                    "fixer_report_path": ".release-loop/runs/alpha/reports/U3-fix.md",
                    "fixer_report_sha256": report_sha,
                    "id": "fix:U3:1",
                    "ordinal": 1,
                    "reviewed_head": head,
                    "source_review_event": "unit:U3:1",
                    "subject": "U3",
                }],
                "schema": "review-fix-event-migration/v1",
            }
            adoption.write_text(json.dumps(adoption_payload, sort_keys=True, separators=(",", ":")) + "\n", encoding="utf-8")
            adoption_sha = hashlib.sha256(adoption.read_bytes()).hexdigest()
            journal = {
                "owned": {
                    "reports/U3-fix.md": report_sha,
                    "reviews/adoptions/fix-history.json": adoption_sha,
                    "reviews/events/U3-round1.md": source_sha,
                },
                "pending": None,
                "schema": "phase-artifact-ownership/v1",
            }
            (root / ".phase-artifact-ownership.json").write_text(
                json.dumps(journal, sort_keys=True, separators=(",", ":")) + "\n",
                encoding="utf-8",
            )
            before_tree = filesystem_manifest(outside)
            (repo / ".release-loop").symlink_to(outside, target_is_directory=True)
            spec = importlib.util.spec_from_file_location("fix_event_migration_symlink", FIX_MIGRATION_CLI)
            assert spec is not None and spec.loader is not None
            migration = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(migration)
            try:
                migration.validate_migration(
                    repo,
                    ".release-loop/runs/alpha/progress.md",
                    ".release-loop/runs/alpha/reviews/adoptions/fix-history.json",
                    lambda _: "G",
                )
            except migration.Blocked as exc:
                assert "path boundary" in str(exc)
            else:
                raise AssertionError("parent-symlink migration escaped the repository")
            assert filesystem_manifest(outside) == before_tree
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
    selected = CASES + REVIEW_CASES + HISTORY_CASES + RETRO_CASES + MATRIX_PROBE_CASES
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
elif CASE in CASES + REVIEW_CASES + HISTORY_CASES + RETRO_CASES + LIFECYCLE_CASES + MATRIX_PROBE_CASES:
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
