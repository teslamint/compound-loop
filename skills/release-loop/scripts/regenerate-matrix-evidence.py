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

from phase_artifact_core import ArtifactBlocked
from phase_artifact_core import guard as guard_phase_artifact_path


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
    transition: tuple(
        "matrix_" + transition + "_" + outcome.replace("-", "_")
        for outcome in OUTCOMES
    )
    for transition in TRANSITIONS
}
RECORD_SCHEMA = "matrix-evidence/v3"
AUTHORITY_SCHEMA = "matrix-evidence-authority/v3"
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


def physical_guard(repo, relative, allowed_root=None):
    allowed = allowed_root or ".release-loop"
    try:
        return guard_phase_artifact_path(
            repo,
            canonical(relative).as_posix(),
            canonical(allowed).as_posix(),
            allow_root=relative == allowed,
        )
    except ArtifactBlocked as exc:
        raise Blocked(str(exc)) from exc


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


def journal_state(repo, root):
    path = physical_guard(repo, (root / ".phase-artifact-ownership.json").relative_to(repo).as_posix(), root.relative_to(repo).as_posix())
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


def validate_owned(repo, root, path, expected):
    path = physical_guard(repo, path.relative_to(repo).as_posix(), root.relative_to(repo).as_posix())
    if path.is_symlink() or not path.is_file() or digest(path) != expected:
        raise Blocked("matrix evidence digest mismatch: " + path.as_posix())
    state = journal_state(repo, root)
    if state["owned"].get(root_key(root, path)) != expected:
        raise Blocked("matrix evidence is not publisher-owned: " + path.as_posix())


def record_target(root, transition, outcome):
    return root / "evidence" / UNIT[transition] / (transition + "-v3-" + outcome + ".md")


def contains_placeholder(value):
    if isinstance(value, str):
        return value == "..." or re.search(r"<[^>]+>", value) is not None
    if isinstance(value, list):
        return any(contains_placeholder(item) for item in value)
    if isinstance(value, dict):
        return any(contains_placeholder(key) or contains_placeholder(item) for key, item in value.items())
    return False


def validate_fixture_binding(record, path):
    identity = record["root_identity"]
    if not isinstance(identity, dict) or set(identity) != {"primary_root", "roots"}:
        raise Blocked("matrix evidence root identity invalid: " + path.as_posix())
    roots = identity["roots"]
    if not isinstance(roots, list) or not roots:
        raise Blocked("matrix evidence root identity invalid: " + path.as_posix())
    root_paths = []
    root_kinds = {}
    for row in roots:
        if not isinstance(row, dict) or set(row) != {"kind", "repo", "progress_records"} or not isinstance(row["progress_records"], list):
            raise Blocked("matrix evidence root identity invalid: " + path.as_posix())
        if row["kind"] not in {"git", "fixture"}:
            raise Blocked("matrix evidence root identity invalid: " + path.as_posix())
        root_paths.append(row["repo"])
        root_kinds[row["repo"]] = row["kind"]
    if len(root_paths) != len(set(root_paths)) or identity["primary_root"] not in root_paths:
        raise Blocked("matrix evidence root identity invalid: " + path.as_posix())
    if root_kinds[identity["primary_root"]] != "git" or sum(kind == "fixture" for kind in root_kinds.values()) != 1:
        raise Blocked("matrix evidence fixture root invalid: " + path.as_posix())
    root_set = set(root_paths)
    for field in ("pre_state", "post_state", "target_inventory"):
        value = record[field]
        if not isinstance(value, dict) or set(value) != root_set:
            raise Blocked("matrix evidence root inventory mismatch: " + path.as_posix())
    for root in root_paths:
        post = record["post_state"][root]
        if not isinstance(post, dict) or record["target_inventory"][root] != post.get("inventory"):
            raise Blocked("matrix evidence target inventory mismatch: " + path.as_posix())
    command = record["command_or_injection"]
    if not isinstance(command, dict) or not isinstance(command.get("inner_trace"), list):
        raise Blocked("matrix evidence command trace invalid: " + path.as_posix())
    referenced_roots = set()
    for trace in command["inner_trace"]:
        required_trace = {
            "argv", "cwd", "exit_status", "path_bindings", "root_pre_state",
            "root_post_state", "stdout", "stderr",
        }
        if not isinstance(trace, dict) or set(trace) != required_trace or not isinstance(trace.get("argv"), list):
            raise Blocked("matrix evidence command trace invalid: " + path.as_posix())
        argv = trace["argv"]
        for option in ("--repo", "--base-repo"):
            if option in argv:
                index = argv.index(option)
                if index + 1 >= len(argv) or argv[index + 1] not in root_set:
                    raise Blocked("matrix evidence trace root mismatch: " + path.as_posix())
                referenced_roots.add(argv[index + 1])
        trace_roots = set(trace["root_pre_state"])
        if trace_roots != set(trace["root_post_state"]) or not trace_roots.issubset(root_set):
            raise Blocked("matrix evidence trace inventory missing: " + path.as_posix())
        expected_options = {
            option
            for option in ("--progress-path", "--source", "--target", "--marker-path", "--destination")
            if option in argv
        }
        bindings = trace["path_bindings"]
        if not isinstance(bindings, list) or {binding.get("option") for binding in bindings if isinstance(binding, dict)} != expected_options:
            raise Blocked("matrix evidence trace path missing: " + path.as_posix())
        for binding in bindings:
            if set(binding) != {"option", "raw", "owner", "physical", "pre", "post"}:
                raise Blocked("matrix evidence trace path invalid: " + path.as_posix())
            owner = binding["owner"]
            if owner not in trace_roots or owner not in root_set:
                raise Blocked("matrix evidence trace root mismatch: " + path.as_posix())
            referenced_roots.add(owner)
            if not isinstance(binding["pre"], dict) or not isinstance(binding["post"], dict):
                raise Blocked("matrix evidence trace path inventory missing: " + path.as_posix())
            option_index = argv.index(binding["option"])
            if option_index + 1 >= len(argv) or argv[option_index + 1] != binding["raw"]:
                raise Blocked("matrix evidence trace path mismatch: " + path.as_posix())
            try:
                relative = Path(binding["physical"]).resolve(strict=False).relative_to(Path(owner)).as_posix()
            except ValueError as exc:
                raise Blocked("matrix evidence trace path escaped root: " + path.as_posix()) from exc
            for phase, state_field in (("pre", "root_pre_state"), ("post", "root_post_state")):
                snapshot = trace[state_field][owner]
                inventory = {
                    row["path"]: row
                    for row in snapshot.get("inventory", [])
                    if isinstance(row, dict) and "path" in row
                }
                observed = binding[phase]
                row = inventory.get(relative)
                if observed.get("exists"):
                    if row is None or row.get("kind") != observed.get("kind") or row.get("sha256_or_target") != observed.get("sha256_or_target"):
                        raise Blocked("matrix evidence trace path inventory mismatch: " + path.as_posix())
                elif row is not None:
                    raise Blocked("matrix evidence trace missing-path mismatch: " + path.as_posix())
    fixture_roots = {root for root, kind in root_kinds.items() if kind == "fixture"}
    if not root_set.issubset(referenced_roots | {identity["primary_root"]} | fixture_roots):
        raise Blocked("matrix evidence sibling root omitted: " + path.as_posix())
    next_invocation = record["next_invocation"]
    if (
        not isinstance(next_invocation, dict)
        or set(next_invocation) != {"action", "exit_status", "result"}
        or not isinstance(next_invocation["exit_status"], int)
        or not isinstance(next_invocation["result"], str)
    ):
        raise Blocked("matrix evidence next invocation invalid: " + path.as_posix())
    structured = {
        key: record[key]
        for key in (
            "root_identity", "pre_state", "post_state", "target_inventory",
            "next_invocation", "mechanism_check", "stub_identity", "plan_row", "new_id",
        )
    }
    if contains_placeholder(structured):
        raise Blocked("matrix evidence placeholder forbidden: " + path.as_posix())


def validate_record(repo, root, path, transition, outcome):
    path = physical_guard(repo, path.relative_to(repo).as_posix(), root.relative_to(repo).as_posix())
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
    if record["transition"] != transition + "-v3" or record["outcome"] != outcome:
        raise Blocked("matrix evidence record identity mismatch: " + path.as_posix())
    if (
        record["new_id"] != transition + "-v3"
        or record["plan_row"] != PLAN_ROWS[transition]
        or record["plan"] != "docs/plans/2026-08-23-001-fix-run-artifact-integrity-plan.md"
        or not isinstance(record["supersedes"], list)
    ):
        raise Blocked("matrix evidence plan identity invalid: " + path.as_posix())
    if not isinstance(record["target_inventory"], dict) or not isinstance(record["command_or_injection"], dict):
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
    validate_fixture_binding(record, path)
    expected = digest(path)
    validate_owned(repo, root, path, expected)
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
    validate_owned(repo, root, target, payload["sha256"])
    return payload["sha256"]


def stale_paths(root):
    paths = [root / "evidence/matrix-authority-v2.json"]
    for transition in TRANSITIONS:
        for outcome in OUTCOMES:
            paths.append(root / "evidence" / UNIT[transition] / (transition + "-v2-" + outcome + ".md"))
    return paths


def replacement_entries(records, stale):
    if stale.name == "matrix-authority-v2.json":
        return records
    match = re.fullmatch(r"(T[1-6])-v2-(success|forced-failure|rerun|compensation|headless|cancellation)\.md", stale.name)
    if match is None:
        raise Blocked("matrix authority stale path invalid: " + stale.as_posix())
    transition, outcome = match.groups()
    return [row for row in records if row["transition"] == transition + "-v3" and row["outcome"] == outcome]


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
    expected_identities = [(transition + "-v3", outcome) for transition in TRANSITIONS for outcome in OUTCOMES]
    if sorted(identities) != sorted(expected_identities) or len(set(identities)) != len(identities):
        raise Blocked("matrix authority duplicate or missing record")
    record_paths = set()
    for row in records:
        if set(row) != {"transition", "outcome", "path", "sha256"} or not SHA.fullmatch(row["sha256"]):
            raise Blocked("matrix authority record invalid")
        target = physical_guard(repo, row["path"], root.relative_to(repo).as_posix())
        base_transition = row["transition"][:-3] if row["transition"].endswith("-v3") else ""
        if base_transition not in TRANSITIONS:
            raise Blocked("matrix authority record transition invalid")
        expected = record_target(root, base_transition, row["outcome"])
        if target != expected or target in record_paths:
            raise Blocked("matrix authority duplicate or chained record")
        record_paths.add(target)
        observed, _ = validate_record(repo, root, target, base_transition, row["outcome"])
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
        stale = physical_guard(repo, row["stale_path"], root.relative_to(repo).as_posix())
        if stale in seen_stale or stale in record_paths:
            raise Blocked("matrix authority duplicate or chained supersession")
        seen_stale.add(stale)
        if stale.is_symlink() or not stale.is_file() or digest(stale) != row["stale_sha256"]:
            raise Blocked("matrix authority stale digest mismatch")
        validate_owned(repo, root, stale, row["stale_sha256"])
        replacements = row["replacements"]
        expected_replacements = replacement_entries(records, stale)
        if replacements != expected_replacements:
            raise Blocked("matrix authority replacement mismatch")
    if seen_stale != set(expected_stale):
        raise Blocked("matrix authority missing supersession")
    authority_sha = digest(path)
    validate_owned(repo, root, path, authority_sha)
    return authority


def generate(repo, progress_path, test_root):
    progress = physical_guard(repo, progress_path)
    values = progress_values(progress)
    artifact_root = values.get("artifact_root")
    if not artifact_root:
        raise Blocked("matrix evidence artifact root missing")
    root = physical_guard(repo, artifact_root, artifact_root)
    if progress.parent != root:
        raise Blocked("matrix evidence progress/root mismatch")
    plan_path = "docs/plans/2026-08-23-001-fix-run-artifact-integrity-plan.md"
    addendum_path = "docs/deviations/2026-08-24-final-review-integrity-correction-019.md"
    source_commit = run(test_root, "git", "rev-parse", "HEAD")
    if run(test_root, "git", "log", "-1", "--format=%G?", source_commit) != "G":
        raise Blocked("matrix evidence signed source commit required")
    addendum_commit = run(test_root, "git", "log", "-1", "--format=%H", "--", addendum_path)
    if not COMMIT.fullmatch(addendum_commit):
        raise Blocked("matrix evidence addendum commit missing")
    if run(test_root, "git", "log", "-1", "--format=%G?", addendum_commit) != "G":
        raise Blocked("matrix evidence signed addendum commit required")
    authority_path = physical_guard(repo, (root / "evidence/matrix-authority-v3.json").relative_to(repo).as_posix(), artifact_root)
    if authority_path.exists():
        authority = validate_authority(repo, root, authority_path)
        return {"manifest": authority_path.relative_to(repo).as_posix(), "record_count": len(authority["records"]), "state": "reused"}
    for stale in stale_paths(root):
        stale = physical_guard(repo, stale.relative_to(repo).as_posix(), artifact_root)
        if not stale.is_file():
            raise Blocked("matrix authority stale evidence missing: " + stale.as_posix())
        validate_owned(repo, root, stale, digest(stale))
    records = []
    failure_after = os.environ.get("RUN_ARTIFACT_MATRIX_TEST_FAIL_AFTER")
    if failure_after is not None and (not failure_after.isdigit() or int(failure_after) < 1):
        raise Blocked("matrix evidence invalid test interruption")
    for transition in TRANSITIONS:
        for index, outcome in enumerate(OUTCOMES):
            case = CASES[transition][index]
            command = ("bash", "scripts/test-run-artifact-integrity.sh", case)
            target = physical_guard(repo, record_target(root, transition, outcome).relative_to(repo).as_posix(), artifact_root)
            if target.exists() or target.is_symlink():
                record_sha, record = validate_record(repo, root, target, transition, outcome)
                if record["addendum_commit"] != addendum_commit or record["source_commit"] != source_commit:
                    raise Blocked("matrix evidence partial generation commit mismatch: " + target.as_posix())
                records.append({"transition": transition + "-v3", "outcome": outcome, "path": target.relative_to(repo).as_posix(), "sha256": record_sha})
                continue
            observation_path = physical_guard(repo, (root / ".tmp" / (transition + "-v3-" + outcome + "-observation.json")).relative_to(repo).as_posix(), artifact_root)
            history_dir = physical_guard(repo, (root / ".tmp" / (transition + "-v3-" + outcome + "-history")).relative_to(repo).as_posix(), artifact_root)
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
            if observation.get("schema") != "matrix-fixture-observation/v2" or observation.get("case") != case:
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
            source = physical_guard(repo, (root / ".tmp" / (transition + "-v3-" + outcome + ".tmp")).relative_to(repo).as_posix(), artifact_root)
            source.parent.mkdir(parents=True, exist_ok=True)
            relevant_stale = []
            for stale in stale_paths(root):
                if stale.name == transition + "-v2-" + outcome + ".md":
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
                "new_id": transition + "-v3",
                "next_invocation": observation["next_invocation"],
                "outcome": outcome,
                "plan": plan_path,
                "plan_row": PLAN_ROWS[transition],
                "post_state": observation["post_states"],
                "pre_state": observation["pre_states"],
                "root_identity": {"primary_root": observation["primary_root"], "roots": observation["roots"]},
                "schema": RECORD_SCHEMA,
                "source_commit": source_commit,
                "stub_identity": observation["stub_identity"],
                "supersedes": relevant_stale,
                "target_inventory": observation["target_inventories"],
                "timestamp_utc": observation["timestamp_utc"],
                "transition": transition + "-v3",
            }
            source.write_text(json.dumps(record, sort_keys=True, separators=(",", ":")) + "\n", encoding="utf-8")
            record_sha = publish(test_root, repo, progress_path, root, source, target)
            records.append({"transition": transition + "-v3", "outcome": outcome, "path": target.relative_to(repo).as_posix(), "sha256": record_sha})
            if failure_after is not None and len(records) == int(failure_after):
                raise Blocked("injected matrix evidence interruption")
    supersedes = []
    for stale in stale_paths(root):
        stale = physical_guard(repo, stale.relative_to(repo).as_posix(), artifact_root)
        if not stale.is_file():
            raise Blocked("matrix authority stale evidence missing: " + stale.as_posix())
        supersedes.append({
            "replacements": replacement_entries(records, stale),
            "stale_path": stale.relative_to(repo).as_posix(),
            "stale_sha256": digest(stale),
        })
    authority = {"records": records, "schema": AUTHORITY_SCHEMA, "supersedes": supersedes}
    source = physical_guard(repo, (root / ".tmp/matrix-authority-v3.tmp").relative_to(repo).as_posix(), artifact_root)
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
