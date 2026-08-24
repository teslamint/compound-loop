#!/usr/bin/env bash
# Disposable fixture coverage for release-loop run-scope integrity.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

case_name="${1:-scope}"

python3 - "$case_name" "$ROOT" <<'PY'
from __future__ import annotations

import hashlib
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
IMPLEMENTING_CLI = ROOT / "skills/implementing/scripts/phase-artifact-integrity.py"
RELEASE_CORE = ROOT / "skills/release-loop/scripts/phase_artifact_core.py"
IMPLEMENTING_CORE = ROOT / "skills/implementing/scripts/phase_artifact_core.py"
PHASE_CONSUMERS = {
    name: (ROOT / f"skills/{name}/SKILL.md").read_text(encoding="utf-8")
    for name in ("planning", "implementing", "reviewing", "shipping", "retrospective")
}
PLAN_SCHEMA = (ROOT / "skills/planning/schemas/plan-schema.md").read_text(encoding="utf-8")
IMPLEMENTING = PHASE_CONSUMERS["implementing"]
REVIEWING = PHASE_CONSUMERS["reviewing"]
MERGE_PIPELINE = (ROOT / "skills/reviewing/references/merge-pipeline.md").read_text(encoding="utf-8")

CASES = (
    "new_scoped_run",
    "scope_preparation_crash",
    "archive_scoped_run",
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
        (IMPLEMENTING, "Only the explicit source re-review may set `fixed`"),
        (REVIEWING, "cheapest artifact that satisfies every written check"),
        (REVIEWING, "phase-gate reuse does not allocate another event"),
        (MERGE_PIPELINE, "review-body and outside-diff"),
        (MERGE_PIPELINE, "allowed disposition"),
    )
    missing = [fragment for text, fragment in required if fragment not in text]
    if missing:
        raise AssertionError("missing sealed-review contract: " + " | ".join(missing))


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
            self.set_disposition(fingerprint, "fixed", event_id)

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
        else:
            raise AssertionError(f"unknown case: {name}")


if CASE == "scope":
    selected = CASES
elif CASE == "all":
    selected = CASES + REVIEW_CASES
elif CASE == "consumers":
    selected = CONSUMER_CASES
elif CASE == "reviews":
    selected = REVIEW_CASES
elif CASE in CASES + REVIEW_CASES:
    selected = (CASE,)
else:
    print("usage: bash scripts/test-run-artifact-integrity.sh <scope|all|consumers|reviews|case>", file=sys.stderr)
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
