#!/usr/bin/env python3
"""Publish one authoritative executable record for every transition outcome."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import subprocess
import sys
from pathlib import Path, PurePosixPath


OUTCOMES = ("success", "forced-failure", "rerun", "compensation", "headless", "cancellation")
TRANSITIONS = ("T1", "T2", "T3", "T4", "T5", "T6")
UNIT = {"T1": "U1", "T2": "U3", "T3": "U4", "T4": "U1", "T5": "U1", "T6": "U2"}
PLAN_ROWS = {
    "T1": "T1 initialize-run-scope",
    "T2": "T2 publish-review-result-and-ledger-event",
    "T3": "T3 authorized-history-rewrite",
    "T4": "T4 handoff-active-scope",
    "T5": "T5 archive-run-scope",
    "T6": "T6 publish-scoped-phase-artifact",
}
CASES = {
    "T1": ("new_scoped_run", "occupied_scope_blocked", "scope_preparation_crash", "archive_incomplete_run", "multiple_live_records", "scope_preparation_crash"),
    "T2": ("review_event_lifecycle", "event_conflict", "matching_started_result", "completed_result_missing", "standalone_and_reuse", "matching_started_result"),
    "T3": ("authorized_rewrite_refresh", "rewrite_conflict", "cancelled_approval_rejected", "rewrite_conflict", "unapproved_rewrite", "cancelled_approval_rejected"),
    "T4": ("handoff_success", "handoff_symlink", "handoff_incomplete_rerun", "handoff_mismatch_preserves_both", "handoff_success", "handoff_incomplete_rerun"),
    "T5": ("archive_scoped_run", "archive_symlink", "interrupted_archive", "interrupted_archive", "archive_scoped_run", "interrupted_archive"),
    "T6": ("all_consumers_one_root", "tracked_selected_target", "publisher_atomic_recovery", "publish_cancellation", "ambiguous_progress_publish", "publish_cancellation"),
}
RECORD_SCHEMA = "matrix-evidence/v2"
AUTHORITY_SCHEMA = "matrix-evidence-authority/v2"
TIMESTAMP = re.compile(r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$")
SHA = re.compile(r"^[0-9a-f]{64}$")
COMMIT = re.compile(r"^[0-9a-f]{40}$")


class Blocked(RuntimeError):
    pass


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def canonical(relative):
    path = PurePosixPath(relative)
    if path.is_absolute() or not path.parts or ".." in path.parts or path.as_posix() != relative:
        raise Blocked("matrix evidence path invalid: " + relative)
    return path


def progress_values(path):
    text = path.read_text(encoding="utf-8")
    if not text.startswith("---\n") or "\n---\n" not in text[4:]:
        raise Blocked("matrix evidence progress invalid")
    values = {}
    for line in text.split("---", 2)[1].splitlines():
        if ":" in line:
            key, value = line.split(":", 1)
            values[key.strip()] = value.strip()
    return values


def run(repo, *args):
    result = subprocess.run(args, cwd=str(repo), text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)
    if result.returncode:
        raise Blocked("matrix evidence command failed: " + " ".join(args) + ": " + result.stderr.strip())
    return result.stdout.strip()


def journal_state(root):
    path = root / ".phase-artifact-ownership.json"
    if path.is_symlink() or not path.is_file():
        raise Blocked("matrix evidence ownership journal missing")
    try:
        state = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        raise Blocked("matrix evidence ownership journal invalid") from exc
    if state.get("schema") != "phase-artifact-ownership/v1" or not isinstance(state.get("owned"), dict) or state.get("pending") is not None:
        raise Blocked("matrix evidence ownership journal invalid")
    return state


def root_key(root, path):
    return path.relative_to(root).as_posix()


def validate_owned(root, path, expected):
    if path.is_symlink() or not path.is_file() or digest(path) != expected:
        raise Blocked("matrix evidence digest mismatch: " + path.as_posix())
    state = journal_state(root)
    if state["owned"].get(root_key(root, path)) != expected:
        raise Blocked("matrix evidence is not publisher-owned: " + path.as_posix())


def record_target(root, transition, outcome):
    return root / "evidence" / UNIT[transition] / (transition + "-v2-" + outcome + ".md")


def validate_record(root, path, transition, outcome):
    try:
        record = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        raise Blocked("matrix evidence record invalid: " + path.as_posix()) from exc
    required = {
        "schema", "plan", "plan_row", "transition", "outcome", "new_id",
        "supersedes", "addendum_commit", "source_commit", "root_identity",
        "target_inventory", "command_or_injection", "exit_status", "bounded_output",
        "pre_state", "post_state", "timestamp_utc", "stub_identity",
        "boundary_sentinel", "next_invocation", "mechanism_check",
    }
    if set(record) != required or record.get("schema") != RECORD_SCHEMA:
        raise Blocked("matrix evidence record invalid: " + path.as_posix())
    if record["transition"] != transition + "-v2" or record["outcome"] != outcome:
        raise Blocked("matrix evidence record identity mismatch: " + path.as_posix())
    if (
        record["new_id"] != transition + "-v2"
        or record["plan_row"] != PLAN_ROWS[transition]
        or record["plan"] != "docs/plans/2026-08-23-001-fix-run-artifact-integrity-plan.md"
        or not isinstance(record["supersedes"], list)
    ):
        raise Blocked("matrix evidence plan identity invalid: " + path.as_posix())
    if not isinstance(record["root_identity"], dict) or set(record["root_identity"]) != {"disposable_root", "progress_records"}:
        raise Blocked("matrix evidence root identity invalid: " + path.as_posix())
    if not isinstance(record["target_inventory"], list) or not isinstance(record["command_or_injection"], dict):
        raise Blocked("matrix evidence command inventory invalid: " + path.as_posix())
    if not isinstance(record["exit_status"], int) or not isinstance(record["bounded_output"], str) or len(record["bounded_output"]) > 4000:
        raise Blocked("matrix evidence result invalid: " + path.as_posix())
    if (
        not isinstance(record["pre_state"], dict)
        or not isinstance(record["post_state"], dict)
        or not TIMESTAMP.fullmatch(record["timestamp_utc"])
        or not isinstance(record["boundary_sentinel"], dict)
        or not record["boundary_sentinel"].get("unchanged")
        or not COMMIT.fullmatch(record["addendum_commit"])
        or not COMMIT.fullmatch(record["source_commit"])
    ):
        raise Blocked("matrix evidence state invalid: " + path.as_posix())
    expected = digest(path)
    validate_owned(root, path, expected)
    return expected, record


def publish(test_root, repo, progress_path, root, source, target):
    cli = test_root / "skills/release-loop/scripts/run-artifact-integrity.py"
    result = subprocess.run(
        (
            sys.executable, str(cli), "publish", "--repo", str(repo),
            "--progress-path", progress_path, "--source", source.relative_to(repo).as_posix(),
            "--target", target.relative_to(repo).as_posix(),
        ),
        cwd=str(test_root), text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False,
    )
    if result.returncode:
        raise Blocked("matrix evidence publication failed: " + result.stderr.strip())
    payload = json.loads(result.stdout)
    validate_owned(root, target, payload["sha256"])
    return payload["sha256"]


def stale_paths(root):
    paths = [root / "evidence/U1/matrix.md"]
    for outcome in OUTCOMES:
        paths.append(root / ("evidence/U2/T6-" + outcome + ".md"))
        paths.append(root / ("evidence/U4/T3-" + outcome + ".md"))
        paths.append(root / ("evidence/U4/round2/T3-" + outcome + ".md"))
    return paths


def replacement_entries(records, stale):
    if stale.as_posix().endswith("evidence/U1/matrix.md"):
        return [row for row in records if row["transition"] in {"T1-v2", "T4-v2", "T5-v2"}]
    name = stale.name
    transition = "T6" if "/U2/" in stale.as_posix() else "T3"
    outcome = name[len(transition) + 1:-3]
    return [row for row in records if row["transition"] == transition + "-v2" and row["outcome"] == outcome]


def validate_authority(repo, root, path):
    try:
        authority = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        raise Blocked("matrix authority invalid") from exc
    if set(authority) != {"schema", "records", "supersedes"} or authority.get("schema") != AUTHORITY_SCHEMA:
        raise Blocked("matrix authority invalid")
    records = authority["records"]
    if not isinstance(records, list) or len(records) != len(TRANSITIONS) * len(OUTCOMES):
        raise Blocked("matrix authority record count invalid")
    identities = [(row.get("transition"), row.get("outcome")) for row in records if isinstance(row, dict)]
    expected_identities = [(transition + "-v2", outcome) for transition in TRANSITIONS for outcome in OUTCOMES]
    if sorted(identities) != sorted(expected_identities) or len(set(identities)) != len(identities):
        raise Blocked("matrix authority duplicate or missing record")
    record_paths = set()
    for row in records:
        if set(row) != {"transition", "outcome", "path", "sha256"} or not SHA.fullmatch(row["sha256"]):
            raise Blocked("matrix authority record invalid")
        target = repo / canonical(row["path"])
        base_transition = row["transition"][:-3] if row["transition"].endswith("-v2") else ""
        if base_transition not in TRANSITIONS:
            raise Blocked("matrix authority record transition invalid")
        expected = record_target(root, base_transition, row["outcome"])
        if target != expected or target in record_paths:
            raise Blocked("matrix authority duplicate or chained record")
        record_paths.add(target)
        observed, _ = validate_record(root, target, base_transition, row["outcome"])
        if observed != row["sha256"]:
            raise Blocked("matrix authority record digest mismatch")
    supersedes = authority["supersedes"]
    expected_stale = stale_paths(root)
    if not isinstance(supersedes, list) or len(supersedes) != len(expected_stale):
        raise Blocked("matrix authority supersession count invalid")
    seen_stale = set()
    for row in supersedes:
        if not isinstance(row, dict) or set(row) != {"stale_path", "stale_sha256", "replacements"}:
            raise Blocked("matrix authority supersession invalid")
        stale = repo / canonical(row["stale_path"])
        if stale in seen_stale or stale in record_paths:
            raise Blocked("matrix authority duplicate or chained supersession")
        seen_stale.add(stale)
        if stale.is_symlink() or not stale.is_file() or digest(stale) != row["stale_sha256"]:
            raise Blocked("matrix authority stale digest mismatch")
        replacements = row["replacements"]
        expected_replacements = replacement_entries(records, stale)
        if replacements != expected_replacements:
            raise Blocked("matrix authority replacement mismatch")
    if seen_stale != set(expected_stale):
        raise Blocked("matrix authority missing supersession")
    authority_sha = digest(path)
    validate_owned(root, path, authority_sha)
    return authority


def generate(repo, progress_path, test_root):
    progress = repo / canonical(progress_path)
    if progress.is_symlink():
        raise Blocked("matrix evidence progress symlink")
    values = progress_values(progress)
    artifact_root = values.get("artifact_root")
    if not artifact_root:
        raise Blocked("matrix evidence artifact root missing")
    root = repo / canonical(artifact_root)
    if progress.parent != root:
        raise Blocked("matrix evidence progress/root mismatch")
    plan_path = "docs/plans/2026-08-23-001-fix-run-artifact-integrity-plan.md"
    addendum_path = "docs/deviations/2026-08-24-final-review-integrity-migration-018.md"
    source_commit = run(test_root, "git", "rev-parse", "HEAD")
    addendum_commit = run(test_root, "git", "log", "-1", "--format=%H", "--", addendum_path)
    if not COMMIT.fullmatch(addendum_commit):
        raise Blocked("matrix evidence addendum commit missing")
    if run(test_root, "git", "log", "-1", "--format=%G?", addendum_commit) != "G":
        raise Blocked("matrix evidence signed addendum commit required")
    authority_path = root / "evidence/matrix-authority-v2.json"
    if authority_path.exists():
        authority = validate_authority(repo, root, authority_path)
        return {"manifest": authority_path.relative_to(repo).as_posix(), "record_count": len(authority["records"]), "state": "reused"}
    for target in [record_target(root, transition, outcome) for transition in TRANSITIONS for outcome in OUTCOMES]:
        if target.exists():
            raise Blocked("matrix evidence partial generation requires manual repair: " + target.as_posix())
    records = []
    for transition in TRANSITIONS:
        for index, outcome in enumerate(OUTCOMES):
            case = CASES[transition][index]
            command = ("bash", "scripts/test-run-artifact-integrity.sh", case)
            observation_path = root / ".tmp" / (transition + "-" + outcome + "-observation.json")
            history_dir = root / ".tmp" / (transition + "-" + outcome + "-history")
            environment = os.environ.copy()
            environment["RUN_ARTIFACT_MATRIX_OBSERVATION"] = str(observation_path)
            if transition == "T3":
                environment["RUN_ARTIFACT_EVIDENCE_DIR"] = str(history_dir)
                environment["RUN_ARTIFACT_EVIDENCE_LABEL"] = transition + "-" + outcome
                environment["RUN_ARTIFACT_EVIDENCE_OUTCOME"] = outcome
            result = subprocess.run(command, cwd=str(test_root), env=environment, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)
            output = (result.stdout + result.stderr)[-4000:]
            if result.returncode:
                raise Blocked("matrix evidence probe failed: " + case + ": " + output)
            if not observation_path.is_file():
                raise Blocked("matrix evidence fixture observation missing: " + case)
            observation = json.loads(observation_path.read_text(encoding="utf-8"))
            if observation.get("schema") != "matrix-fixture-observation/v1" or observation.get("case") != case:
                raise Blocked("matrix evidence fixture observation invalid: " + case)
            history_output = ""
            if history_dir.is_dir():
                history_files = sorted(history_dir.glob("*.md"))
                if len(history_files) != 1:
                    raise Blocked("matrix evidence history observation invalid: " + case)
                history_output = history_files[0].read_text(encoding="utf-8")
            observation_path.unlink()
            if history_dir.is_dir():
                for child in history_dir.iterdir():
                    child.unlink()
                history_dir.rmdir()
            target = record_target(root, transition, outcome)
            source = root / ".tmp" / (transition + "-" + outcome + "-v2.tmp")
            source.parent.mkdir(parents=True, exist_ok=True)
            relevant_stale = []
            for stale in stale_paths(root):
                if stale.name == "matrix.md" and transition in {"T1", "T4", "T5"}:
                    relevant_stale.append({"path": stale.relative_to(repo).as_posix(), "sha256": digest(stale)})
                elif transition == "T6" and "/U2/" in stale.as_posix() and stale.name == transition + "-" + outcome + ".md":
                    relevant_stale.append({"path": stale.relative_to(repo).as_posix(), "sha256": digest(stale)})
                elif transition == "T3" and "/U4/" in stale.as_posix() and stale.name == transition + "-" + outcome + ".md":
                    relevant_stale.append({"path": stale.relative_to(repo).as_posix(), "sha256": digest(stale)})
            inner_exit = next(
                (int(row["exit_status"]) for row in observation["command_trace"] if int(row["exit_status"]) != 0),
                result.returncode,
            )
            history_exit = re.search(r"Numeric inner exit: `?(-?[0-9]+)`?", history_output)
            if history_exit:
                inner_exit = int(history_exit.group(1))
            record = {
                "addendum_commit": addendum_commit,
                "boundary_sentinel": observation["boundary_sentinel"],
                "bounded_output": (output + "\n" + history_output)[-4000:],
                "command_or_injection": {"argv": list(command), "case": case, "inner_trace": observation["command_trace"], "outer_test_exit": result.returncode},
                "exit_status": inner_exit,
                "mechanism_check": observation["mechanism_check"],
                "new_id": transition + "-v2",
                "next_invocation": observation["next_invocation"],
                "outcome": outcome,
                "plan": plan_path,
                "plan_row": PLAN_ROWS[transition],
                "post_state": observation["post_state"],
                "pre_state": observation["pre_state"],
                "root_identity": {"disposable_root": observation["disposable_root"], "progress_records": observation["progress_records"]},
                "schema": RECORD_SCHEMA,
                "source_commit": source_commit,
                "stub_identity": observation["stub_identity"],
                "supersedes": relevant_stale,
                "target_inventory": observation["post_state"]["inventory"],
                "timestamp_utc": observation["timestamp_utc"],
                "transition": transition + "-v2",
            }
            source.write_text(json.dumps(record, sort_keys=True, separators=(",", ":")) + "\n", encoding="utf-8")
            record_sha = publish(test_root, repo, progress_path, root, source, target)
            records.append({"transition": transition + "-v2", "outcome": outcome, "path": target.relative_to(repo).as_posix(), "sha256": record_sha})
    supersedes = []
    for stale in stale_paths(root):
        if not stale.is_file():
            raise Blocked("matrix authority stale evidence missing: " + stale.as_posix())
        supersedes.append({
            "replacements": replacement_entries(records, stale),
            "stale_path": stale.relative_to(repo).as_posix(),
            "stale_sha256": digest(stale),
        })
    authority = {"records": records, "schema": AUTHORITY_SCHEMA, "supersedes": supersedes}
    source = root / ".tmp/matrix-authority-v2.tmp"
    source.write_text(json.dumps(authority, sort_keys=True, separators=(",", ":")) + "\n", encoding="utf-8")
    publish(test_root, repo, progress_path, root, source, authority_path)
    validate_authority(repo, root, authority_path)
    return {"manifest": authority_path.relative_to(repo).as_posix(), "record_count": len(records), "state": "published"}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", required=True)
    parser.add_argument("--progress-path", required=True)
    args = parser.parse_args()
    try:
        repo = Path(args.repo).resolve(strict=True)
        test_root = Path(__file__).resolve().parents[3]
        payload = generate(repo, args.progress_path, test_root)
    except (Blocked, OSError, UnicodeError, ValueError, json.JSONDecodeError) as exc:
        print(str(exc), file=sys.stderr)
        return 1
    print(json.dumps(payload, sort_keys=True, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
