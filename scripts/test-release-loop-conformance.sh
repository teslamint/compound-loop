#!/usr/bin/env bash
# Release-loop cross-harness conformance evaluator.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODE="${1:-}"

case "$MODE" in
  static-inventory|static|fixture|gate|preflight|resource|transition|prepare-pilot|install-full-approval|live-pilot|live|handoff|publish-baseline|verify-archive) ;;
  *)
    echo "usage: bash scripts/test-release-loop-conformance.sh <static-inventory|static|fixture|gate|preflight|resource|transition|prepare-pilot|install-full-approval|live-pilot|live|handoff|publish-baseline|verify-archive>" >&2
    exit 2
    ;;
esac

python3 - "$ROOT" "$MODE" "${@:2}" <<'PY'
import copy
from datetime import datetime
from datetime import timezone
from decimal import Decimal
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import selectors
import shlex
import shutil
import signal
import stat
import subprocess
import sys
import tempfile
import time
import uuid

root = Path(sys.argv[1])
mode = sys.argv[2]
mode_args = sys.argv[3:]
data_root = root / "tests/conformance/release-loop"
ADAPTER_OUTPUT_CAP = 1048576
ADAPTER_SUMMARY_CAP = 1500000
ADAPTER_HANDSHAKE_TIMEOUT = 2
ADAPTER_TERM_GRACE = 0.2
ADAPTER_GROUP_ABSENCE_TIMEOUT = 1
GOVERNED_HARD_CAP_COMPONENTS = None
GOVERNED_HARD_CAP_PROOF_PATH = None
corpus_path = data_root / "corpus.json"
expected_graders = [
    "design-user-gate",
    "phase-order",
    "final-action",
    "retro-required",
    "archive-complete",
    "resume-source-truth",
    "no-phase-replay",
    "terminal-evidence",
    "resume-after-merge",
    "no-premerge-reentry",
    "degradation-complete",
    "no-coverage-drop",
    "same-gates",
    "sc2-comparison",
    "sc2-guard",
    "operative-section-parser",
    "pending-gate-state",
    "transition-state",
]
expected_results = ["conformant", "pass", "expected-reject"]
expected_case_contracts = {
    "L1-full-lifecycle": (
        "live",
        ["design", "plan", "implement", "review", "ship", "retro", "archive"],
        "conformant",
        ["delete-design-user-gate", "missing-pending-gate", "unknown-pending-gate", "already-approved-pending-gate", "unknown-pending-answer", "nonmonotonic-pending-answer", "nonmonotonic-pending-outcome", "malformed-pending-outcome", "missing-pending-outcome-log", "skip-v1-before-ship"],
        ["design-user-gate", "phase-order", "final-action", "retro-required", "archive-complete", "pending-gate-state", "transition-state"],
    ),
    "L2-mid-loop-resume": (
        "live",
        ["resume", "implement", "review", "ship", "retro", "archive"],
        "conformant",
        ["replay-completed-phase", "mismatched-pending-gate", "mismatched-pending-answer-class", "stale-pending-gate", "duplicate-pending-answer", "duplicate-pending-gate-record"],
        ["resume-source-truth", "no-phase-replay", "terminal-evidence", "pending-gate-state"],
    ),
    "L3-post-merge-resume": (
        "live",
        ["resume", "post-ship-completion", "retro", "archive"],
        "conformant",
        ["reenter-premerge-shipping", "skip-v2-before-done", "mismatched-generation-chain", "early-handoff-consumption"],
        ["resume-after-merge", "no-premerge-reentry", "retro-required", "transition-state"],
    ),
    "L4-degraded-dispatch": (
        "live",
        ["design", "plan", "implement-degraded", "review-degraded", "ship", "retro", "archive"],
        "conformant",
        ["drop-work-without-subagents"],
        ["degradation-complete", "no-coverage-drop", "same-gates"],
    ),
    "SC2-reject-a-different-kind": (
        "static", ["different-artifact-kind"], "expected-reject", ["different-artifact-kind"], ["sc2-comparison"]
    ),
    "SC2-reject-b-unstable-invariance": (
        "static", ["unstable-invariance-output"], "expected-reject", ["unstable-invariance-output"], ["sc2-comparison"]
    ),
    "SC2-reject-c-irrelevant-axis": (
        "static", ["irrelevant-changed-axis"], "expected-reject", ["irrelevant-changed-axis"], ["sc2-comparison"]
    ),
    "SC2-reject-d-metadata-only": (
        "static", ["metadata-only-difference"], "expected-reject", ["metadata-only-difference"], ["sc2-comparison"]
    ),
    "SC2-guard-reject": (
        "static", ["always-passing-guard"], "expected-reject", ["always-passing-guard"], ["sc2-guard"]
    ),
    "SC2-accept-controlled-pairs": (
        "static", ["controlled-same-kind-pairs"], "pass", ["controlled-same-kind-pairs"], ["sc2-comparison"]
    ),
    "parser-contradictory-substitute-command": (
        "static", ["contradictory-substitute-command"], "expected-reject", ["contradictory-substitute-command"], ["operative-section-parser"]
    ),
    "parser-fence-relocation": (
        "static", ["fence-relocation"], "expected-reject", ["fence-relocation"], ["operative-section-parser"]
    ),
}
expected_live = {case_id for case_id, contract in expected_case_contracts.items() if contract[0] == "live"}
expected_static = set(expected_case_contracts) - expected_live
expected_golden_contracts = {
    "L1-full-lifecycle": (
        "Run the complete release-loop lifecycle in the disposable fixture. Stop only at recorded USER gates and finish with an archived Retro.",
        [
            {"gate_id": "design-approval", "phase": "design", "expected_answer_class": "approve-spec-or-request-revision", "answer": "approve"},
            {"gate_id": "ship-approval", "phase": "ship", "expected_answer_class": "merge-or-nonmerge-disposition", "answer": "merge"},
        ],
    ),
    "L2-mid-loop-resume": (
        "Resume the supplied partial release-loop ledger. Preserve completed phases and finish the remaining lifecycle.",
        [
            {"gate_id": "ship-approval", "phase": "ship", "expected_answer_class": "merge-or-nonmerge-disposition", "answer": "merge"},
        ],
    ),
    "L3-post-merge-resume": (
        "Resume the supplied merged Ship ledger. Do not re-enter pre-merge shipping. Complete post-Ship work, Retro, and archive.",
        [],
    ),
    "L4-degraded-dispatch": (
        "Run the release-loop with native subagents unavailable. Use the documented degraded tier without dropping work or gates.",
        [
            {"gate_id": "design-approval", "phase": "design", "expected_answer_class": "approve-spec-or-request-revision", "answer": "approve"},
            {"gate_id": "ship-approval", "phase": "ship", "expected_answer_class": "merge-or-nonmerge-disposition", "answer": "merge"},
        ],
    ),
}
expected_materialization = {
    "read_mode": "bytes",
    "digest": "sha256",
    "insertion": "verbatim",
}
required_case_fields = {
    "schema",
    "id",
    "kind",
    "events",
    "expected_outcome",
    "eligible_mutations",
    "required_graders",
}


def fail(message):
    raise ValueError(message)


def load_json(path):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        fail(f"missing file: {path.relative_to(root)}")
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        fail(f"invalid JSON: {path.relative_to(root)}: {exc}")


def unique_strings(values, label):
    if not isinstance(values, list) or not values or not all(isinstance(v, str) and v for v in values):
        fail(f"{label} must be a non-empty string list")
    if len(values) != len(set(values)):
        fail(f"duplicate {label}")
    return set(values)


def validate_corpus(data):
    if not isinstance(data, dict):
        fail("corpus root must be an object")
    if data.get("schema") != "release-loop-conformance-corpus/v1":
        fail("unknown corpus schema")
    if data.get("harnesses") != ["claude", "codex"]:
        fail("harness inventory must be exactly claude,codex")
    if data.get("result_classes") != expected_results:
        fail("semantic contract mismatch: result classes")
    graders = unique_strings(data.get("grader_inventory"), "grader ID")
    results = unique_strings(data.get("result_classes"), "result class")
    cases = data.get("cases")
    if not isinstance(cases, list) or not cases:
        fail("cases must be a non-empty list")

    case_ids = []
    referenced_graders = set()
    for index, case in enumerate(cases):
        if not isinstance(case, dict):
            fail(f"case {index} must be an object")
        missing = sorted(required_case_fields - case.keys())
        if missing:
            fail(f"case {index} missing field: {missing[0]}")
        if case["schema"] != "conformance-case/v1":
            fail(f"case {case['id']} has unknown schema")
        case_id = case["id"]
        if not isinstance(case_id, str) or not case_id:
            fail(f"case {index} has invalid ID")
        case_ids.append(case_id)
        expected_contract = expected_case_contracts.get(case_id)
        if expected_contract is None:
            fail(f"semantic contract mismatch: unknown case {case_id}")
        if case["kind"] not in {"live", "static"}:
            fail(f"case {case_id} has unknown kind")
        if case["expected_outcome"] not in results:
            fail(f"case {case_id} has unknown verdict")
        events = case["events"]
        if not isinstance(events, list) or not events:
            fail(f"case {case_id} has no events")
        for sequence, event in enumerate(events, 1):
            if not isinstance(event, dict) or event.get("sequence") != sequence:
                fail(f"case {case_id} has invalid event sequence")
            if not isinstance(event.get("type"), str) or not isinstance(event.get("value"), str):
                fail(f"case {case_id} has invalid event")
        unique_strings(case["eligible_mutations"], f"mutation ID for {case_id}")
        case_graders = unique_strings(case["required_graders"], f"grader ID for {case_id}")
        unknown_graders = sorted(case_graders - graders)
        if unknown_graders:
            fail(f"case {case_id} references unknown grader: {unknown_graders[0]}")
        referenced_graders.update(case_graders)
        expected_kind, expected_values, expected_outcome, expected_mutations, expected_required_graders = expected_contract
        expected_event_type = "lifecycle" if expected_kind == "live" else "fixture"
        expected_events = [
            {"sequence": sequence, "type": expected_event_type, "value": value}
            for sequence, value in enumerate(expected_values, 1)
        ]
        actual_contract = (
            case["kind"],
            case["events"],
            case["expected_outcome"],
            case["eligible_mutations"],
            case["required_graders"],
        )
        expected_full_contract = (
            expected_kind,
            expected_events,
            expected_outcome,
            expected_mutations,
            expected_required_graders,
        )
        if actual_contract != expected_full_contract:
            fail(f"semantic contract mismatch: {case_id}")

    if len(case_ids) != len(set(case_ids)):
        fail("duplicate case ID")
    if case_ids != list(expected_case_contracts):
        fail("semantic contract mismatch: case order")
    actual_live = {case["id"] for case in cases if case["kind"] == "live"}
    actual_static = {case["id"] for case in cases if case["kind"] == "static"}
    if actual_live != expected_live:
        fail("live case inventory mismatch")
    if actual_static != expected_static:
        fail("static case inventory mismatch")
    unreachable = sorted(graders - referenced_graders)
    if unreachable:
        fail(f"unreachable grader: {unreachable[0]}")
    if data.get("grader_inventory") != expected_graders:
        fail("semantic contract mismatch: grader inventory")
    return cases


def validate_golden_packet(packet, harness, case_id, source_bytes):
    required = {
        "schema",
        "harness",
        "case_id",
        "payload_mode",
        "skill_source",
        "skill_sha256",
        "skill_materialization",
        "prompt",
        "scripted_answers",
    }
    missing = sorted(required - packet.keys()) if isinstance(packet, dict) else ["object"]
    if missing:
        fail(f"golden {harness}/{case_id} missing field: {missing[0]}")
    if set(packet) != required:
        fail(f"golden semantic contract mismatch: {harness}/{case_id} fields")
    if packet["schema"] != "release-loop-golden-input/v1":
        fail(f"golden {harness}/{case_id} has unknown schema")
    if packet["harness"] != harness or packet["case_id"] != case_id:
        fail(f"golden {harness}/{case_id} identity mismatch")
    if packet["payload_mode"] != "exact-current-skill-bytes":
        fail(f"golden {harness}/{case_id} payload mode mismatch")
    if packet["skill_source"] != "skills/release-loop/SKILL.md":
        fail(f"golden {harness}/{case_id} skill source mismatch")
    source_digest = hashlib.sha256(source_bytes).hexdigest()
    if packet["skill_sha256"] != source_digest:
        fail(f"golden semantic contract mismatch: {harness}/{case_id} skill digest")
    if packet["skill_materialization"] != expected_materialization:
        fail(f"golden semantic contract mismatch: {harness}/{case_id} materialization")
    if not isinstance(packet["prompt"], str) or not packet["prompt"]:
        fail(f"golden {harness}/{case_id} prompt missing")
    answers = packet["scripted_answers"]
    if not isinstance(answers, list):
        fail(f"golden {harness}/{case_id} answers must be a list")
    seen_gates = set()
    for answer in answers:
        if not isinstance(answer, dict):
            fail(f"golden {harness}/{case_id} answer must be an object")
        fields = {"gate_id", "phase", "expected_answer_class", "answer"}
        if fields - answer.keys():
            fail(f"golden {harness}/{case_id} answer missing field")
        gate_id = answer["gate_id"]
        if gate_id in seen_gates:
            fail(f"golden {harness}/{case_id} duplicate gate answer")
        seen_gates.add(gate_id)
        allowed = {
            "design-approval": ("design", "approve-spec-or-request-revision", {"approve", "revise"}),
            "ship-approval": ("ship", "merge-or-nonmerge-disposition", {"merge", "nonmerge"}),
        }
        if gate_id not in allowed:
            fail(f"golden {harness}/{case_id} unknown gate")
        phase, answer_class, answer_values = allowed[gate_id]
        if answer["phase"] != phase or answer["expected_answer_class"] != answer_class:
            fail(f"golden {harness}/{case_id} gate contract mismatch")
        if answer["answer"] not in answer_values:
            fail(f"golden {harness}/{case_id} unknown gate answer")
    if (packet["prompt"], packet["scripted_answers"]) != expected_golden_contracts[case_id]:
        fail(f"golden semantic contract mismatch: {harness}/{case_id} prompt or gates")


def validate_golden():
    source = root / "skills/release-loop/SKILL.md"
    source_bytes = source.read_bytes()
    expected_paths = set()
    for harness in ("claude", "codex"):
        for case_id in sorted(expected_live):
            path = data_root / "golden" / harness / f"{case_id}.json"
            expected_paths.add(path)
            packet = load_json(path)
            validate_golden_packet(packet, harness, case_id, source_bytes)

    actual_paths = set((data_root / "golden").glob("*/*.json"))
    if actual_paths != expected_paths:
        fail("golden file inventory mismatch")


def section_text(text, heading):
    lines = text.splitlines()
    try:
        start = lines.index(heading)
    except ValueError:
        fail(f"source heading missing: {heading}")
    level = len(heading) - len(heading.lstrip("#"))
    end = len(lines)
    for index in range(start + 1, len(lines)):
        line = lines[index]
        if line.startswith("#"):
            candidate_level = len(line) - len(line.lstrip("#"))
            if candidate_level <= level:
                end = index
                break
    return "\n".join(lines[start:end])


def sc2_invariant(fixture):
    pairs = []
    for pair_name in ("invariance", "changed"):
        pair = fixture.get(pair_name)
        if not isinstance(pair, dict):
            return "sc2-fixture"
        artifacts = []
        for side in ("left", "right"):
            artifact = pair.get(side)
            if not isinstance(artifact, dict):
                return "sc2-fixture"
            if set(artifact) != {"kind", "comparison", "effect", "metadata"}:
                return "sc2-fixture"
            artifacts.append(artifact)
        pairs.append(artifacts)

    artifacts = [artifact for pair in pairs for artifact in pair]
    if len({artifact["kind"] for artifact in artifacts}) != 1:
        return "sc2-same-kind"
    if pairs[0][0]["comparison"] != pairs[0][1]["comparison"]:
        return "sc2-invariance"
    if fixture.get("changed_axis") != fixture.get("effect_axis"):
        return "sc2-axis"
    if pairs[1][0]["comparison"] == pairs[1][1]["comparison"]:
        return "sc2-changed-output"
    if pairs[1][0]["effect"] == pairs[1][1]["effect"]:
        return "sc2-effect-signal"
    return None


def operative_commands(document):
    if not isinstance(document, str):
        return None
    commands = []
    fence_char = None
    fence_length = 0
    for line in document.splitlines():
        stripped = line.lstrip()
        match = re.match(r"^(`{3,}|~{3,})(?:[^`~]*)$", stripped)
        if match:
            marker = match.group(1)
            if fence_char is None:
                fence_char = marker[0]
                fence_length = len(marker)
            elif marker[0] == fence_char and len(marker) >= fence_length:
                fence_char = None
                fence_length = 0
            continue
        if fence_char is None and line.startswith("Run: "):
            commands.append(line[len("Run: "):])
    return commands


def validate_source_section(clause, section):
    literal = clause.get("text")
    if not isinstance(literal, str) or section.count(literal) != 1:
        fail(f"source clause missing or ambiguous: {clause.get('id')}")
    digest = hashlib.sha256(section.encode()).hexdigest()
    if digest != clause.get("sha256"):
        fail(f"source clause digest drift: {clause.get('id')}")
    return digest


def validate_source_generation(generation, policy_generation, corpus_generation):
    if generation != policy_generation:
        fail("bootstrap source generation mismatch")
    if generation != corpus_generation:
        fail("corpus source generation mismatch")


def path_is_inside(root_path, candidate_path):
    try:
        candidate_path.resolve(strict=True).relative_to(root_path.resolve(strict=True))
    except (FileNotFoundError, ValueError):
        return False
    return True


def safe_repo_path(repo_path, value):
    if not value or value.startswith("-"):
        return False
    candidate = Path(value)
    if candidate.is_absolute():
        return False
    try:
        resolved = (repo_path / candidate).resolve(strict=False)
        resolved.relative_to(repo_path.resolve(strict=True))
    except ValueError:
        return False
    target = repo_path / candidate
    return not target.exists() or path_is_inside(repo_path, target)


def validate_git_command(argv, fixture_root, repo_path):
    if "-c" in argv[1:]:
        return False, "git-config-override"
    if any("credential" in arg.lower() or arg.startswith("ext::") for arg in argv[1:]):
        return False, "git-indirect-access"
    if argv in (["git", "status"], ["git", "status", "--short"], ["git", "status", "--short", "--branch"]):
        return True, "fixture-git-status"
    if argv in (["git", "diff"], ["git", "diff", "--check"], ["git", "diff", "--stat"], ["git", "diff", "--cached"]):
        return True, "fixture-git-diff"
    if argv == ["git", "log", "--oneline"]:
        return True, "fixture-git-log"
    if len(argv) >= 3 and argv[1] == "add" and all(safe_repo_path(repo_path, value) for value in argv[2:]):
        return True, "fixture-git-add"
    if len(argv) == 4 and argv[1:3] == ["commit", "-m"] and argv[3]:
        return True, "fixture-git-commit"
    if argv[1:3] == ["remote", "add"]:
        return False, "remote-add"
    if argv == ["git", "remote", "get-url", "origin"]:
        return True, "fixture-git-origin-read"
    if len(argv) in {3, 4} and argv[1] == "ls-remote" and argv[2] == "origin":
        return True, "fixture-git-ls-remote"
    if len(argv) in {3, 4} and argv[1] == "rev-parse":
        safe_values = {"HEAD", "--show-toplevel", "--git-dir", "--abbrev-ref"}
        if argv[2] in safe_values and (len(argv) == 3 or argv[2:] == ["--abbrev-ref", "HEAD"]):
            return True, "fixture-git-rev-parse"
    if len(argv) >= 2 and argv[1] == "push":
        if len(argv) == 4:
            remote, branch = argv[2:]
        elif len(argv) == 5 and argv[2] == "-u":
            remote, branch = argv[3:]
        else:
            return False, "git-push-shape"
        if remote != "origin" or not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._/-]*", branch):
            return False, "non-fixture-push"
        origin = subprocess.run(
            ["git", "remote", "get-url", "origin"],
            cwd=str(repo_path),
            check=False,
            capture_output=True,
            text=True,
        )
        if origin.returncode != 0:
            return False, "origin-missing"
        if not path_is_inside(fixture_root, Path(origin.stdout.strip())):
            return False, "origin-outside-fixture"
        return True, "fixture-git-push"
    return False, "unknown-git-call"


def validate_gh_command(argv, fixture_root):
    if argv == ["gh", "auth", "status"]:
        return True, "fixture-gh-auth"
    if argv == ["gh", "repo", "view", "--json", "viewerPermission"]:
        return True, "fixture-gh-repo"
    if len(argv) == 7 and argv[1:3] == ["pr", "create"] and argv[3] == "--title" and argv[5] in {"--body", "--body-file"}:
        if argv[5] == "--body-file" and not path_is_inside(fixture_root, Path(argv[6])):
            return False, "gh-body-outside-fixture"
        return bool(argv[4] and argv[6]), "fixture-gh-pr-create"
    if argv in (["gh", "pr", "checks", "1"], ["gh", "pr", "checks", "1", "--watch"]):
        return True, "fixture-gh-checks"
    if argv == ["gh", "pr", "view", "1", "--json", "mergeCommit", "--jq", ".mergeCommit.oid // empty"]:
        return True, "fixture-gh-pr-view"
    if len(argv) == 6 and argv[1:4] == ["pr", "comment", "1"] and argv[4] == "--body" and argv[5]:
        return True, "fixture-gh-comment"
    if argv in (
        ["gh", "pr", "merge", "1", "--squash", "--delete-branch"],
        ["gh", "pr", "merge", "1", "--squash", "--delete-branch", "--auto"],
    ):
        return True, "fixture-gh-merge"
    if argv in (
        ["gh", "api", "repos/{owner}/{repo}/pulls/1/reviews", "--jq", "length"],
        ["gh", "api", "repos/{owner}/{repo}/pulls/1/comments", "--jq", "length"],
    ):
        return True, "fixture-gh-api"
    if len(argv) == 7 and argv[1:3] == ["api", "graphql"] and argv[3:5] == ["-F", "number=1"] and argv[5] == "-f" and argv[6].startswith("query="):
        return True, "fixture-gh-graphql"
    if argv == ["gh", "run", "view", "1", "--log-failed"]:
        return True, "fixture-gh-run"
    return False, "unknown-gh-call"


def command_policy(argv, fixture_root, repo_path, env):
    if not isinstance(argv, list) or not argv or not all(isinstance(arg, str) for arg in argv):
        return False, "invalid-command"
    command = argv[0]
    if command == ".conformance/bin/fixture-exec":
        wrapper = repo_path / command
        if not path_is_inside(repo_path, wrapper) or wrapper.is_symlink():
            return False, "fixture-wrapper-invalid"
        expected_digest = env.get("CONFORMANCE_WRAPPER_SHA256")
        if not expected_digest or hashlib.sha256(wrapper.read_bytes()).hexdigest() != expected_digest:
            return False, "fixture-wrapper-drift"
        if len(argv) < 2:
            return False, "fixture-wrapper-empty"
        nested = argv[1:]
        if nested[0] == "git":
            return validate_git_command(nested, fixture_root, repo_path)
        if nested[0] == "gh":
            return validate_gh_command(nested, fixture_root)
        return False, "fixture-wrapper-command"
    if command != Path(command).name:
        return False, "absolute-command"
    if command in {"git", "gh", "curl", "ssh", "env", "sh", "bash", "python", "python3"}:
        return False, "forbidden-command"
    if command in {"npm", "pnpm", "yarn"} and "publish" in argv[1:]:
        return False, "publish-command"
    return False, "unknown-command"


def run_bounded(argv, cwd, env, output_cap=65536, timeout=10, input_bytes=None):
    process = subprocess.Popen(
        argv,
        cwd=str(cwd),
        env=env,
        stdin=subprocess.PIPE if input_bytes is not None else subprocess.DEVNULL,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    if input_bytes is not None:
        process.stdin.write(input_bytes)
        process.stdin.close()
    streams = selectors.DefaultSelector()
    streams.register(process.stdout, selectors.EVENT_READ, "stdout")
    streams.register(process.stderr, selectors.EVENT_READ, "stderr")
    output = {"stdout": bytearray(), "stderr": bytearray()}
    started = time.monotonic()
    try:
        while streams.get_map():
            if time.monotonic() - started > timeout:
                process.kill()
                process.wait()
                fail("fixture subprocess timeout")
            for key, _ in streams.select(0.1):
                chunk = os.read(key.fileobj.fileno(), 8192)
                if not chunk:
                    streams.unregister(key.fileobj)
                    continue
                output[key.data].extend(chunk)
                if len(output["stdout"]) + len(output["stderr"]) > output_cap:
                    process.kill()
                    process.wait()
                    fail("fixture subprocess output exceeded cap")
        returncode = process.wait()
    finally:
        streams.close()
    return subprocess.CompletedProcess(
        argv,
        returncode,
        output["stdout"].decode("utf-8", errors="replace"),
        output["stderr"].decode("utf-8", errors="replace"),
    )


def run_audited(argv, cwd, env, fixture_root, repo_path, audit, expect_success=True, before_execute=None):
    allowed, reason = command_policy(argv, fixture_root, repo_path, env)
    row = {"argv": argv, "allowed": allowed, "executed": False, "reason": reason}
    audit.append(row)
    if allowed and before_execute is not None:
        before_execute()
        allowed, reason = command_policy(argv, fixture_root, repo_path, env)
        row.update(allowed=allowed, reason=reason)
    if not allowed:
        if expect_success:
            fail(f"command policy rejected required command: {reason}")
        return None
    row["executed"] = True
    result = run_bounded(argv, cwd, env)
    if expect_success and result.returncode != 0:
        fail(f"fixture command failed: {argv}: {result.stderr.strip()}")
    if not expect_success and result.returncode == 0:
        fail(f"fixture command unexpectedly passed: {argv}")
    return result


def write_fixture_wrapper(path):
    source = r'''#!/usr/bin/env python3
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys

wrapper = Path(__file__).resolve(strict=True)
expected_digest = os.environ.get("CONFORMANCE_WRAPPER_SHA256")
if not expected_digest or hashlib.sha256(wrapper.read_bytes()).hexdigest() != expected_digest:
    raise SystemExit("fixture wrapper digest mismatch")
root = Path(os.environ["CONFORMANCE_FIXTURE_ROOT"]).resolve(strict=True)
repo = Path(os.environ["CONFORMANCE_FIXTURE_REPO"]).resolve(strict=True)
origin = Path(os.environ["CONFORMANCE_FIXTURE_ORIGIN"]).resolve(strict=True)
gh_path = Path(os.environ["CONFORMANCE_GH"])
if gh_path.is_symlink():
    raise SystemExit("fixture gh simulator digest mismatch")
gh_path = gh_path.resolve(strict=True)
for target in (repo, origin, wrapper, gh_path):
    target.relative_to(root)
gh_source = gh_path.read_bytes()
if hashlib.sha256(gh_source).hexdigest() != os.environ.get("CONFORMANCE_GH_SHA256"):
    raise SystemExit("fixture gh simulator digest mismatch")
args = sys.argv[1:]

blocked_env = {
    "GIT_CONFIG", "GIT_CONFIG_COUNT", "GIT_DIR", "GIT_WORK_TREE", "GIT_SSH", "GIT_SSH_COMMAND",
    "GIT_EXTERNAL_DIFF", "SSH_ASKPASS", "GIT_ASKPASS",
}
if blocked_env & os.environ.keys() or any(key.startswith("GIT_CONFIG_KEY_") for key in os.environ):
    raise SystemExit("fixture runtime state rejected")
config_result = subprocess.run(
    [os.environ["CONFORMANCE_GIT"], "config", "--local", "--list"],
    cwd=str(repo), check=True, capture_output=True, text=True,
)
config = dict(line.split("=", 1) for line in config_result.stdout.splitlines() if "=" in line)
blocked_config = ("credential.", "alias.", "url.", "http.", "filter.", "protocol.")
if any(key.startswith(blocked_config) for key in config):
    raise SystemExit("fixture runtime state rejected")
for key in ("core.hookspath", "core.fsmonitor", "diff.external", "remote.origin.uploadpack", "remote.origin.receivepack"):
    if key in config:
        raise SystemExit("fixture runtime state rejected")
if Path(config.get("remote.origin.url", "")).resolve(strict=True) != origin:
    raise SystemExit("fixture runtime state rejected")
hooks = repo / ".git" / "hooks"
if any(path.is_file() and os.access(str(path), os.X_OK) and not path.name.endswith(".sample") for path in hooks.iterdir()):
    raise SystemExit("fixture runtime state rejected")

def inside(candidate):
    try:
        candidate.resolve(strict=True).relative_to(root)
    except (FileNotFoundError, ValueError):
        return False
    return True

def safe_repo_path(value):
    candidate = Path(value)
    if not value or value.startswith("-") or candidate.is_absolute():
        return False
    try:
        target = (repo / candidate).resolve(strict=False)
        target.relative_to(repo)
    except ValueError:
        return False
    return not target.exists() or inside(target)

def git_allowed():
    if "-c" in args[1:] or any("credential" in value.lower() or value.startswith("ext::") for value in args[1:]):
        return False
    if args in (["git", "status"], ["git", "status", "--short"], ["git", "status", "--short", "--branch"]):
        return True
    if args in (["git", "diff"], ["git", "diff", "--check"], ["git", "diff", "--stat"], ["git", "diff", "--cached"]):
        return True
    if args == ["git", "log", "--oneline"] or args == ["git", "remote", "get-url", "origin"]:
        return True
    if len(args) >= 3 and args[1] == "add" and all(safe_repo_path(value) for value in args[2:]):
        return True
    if len(args) == 4 and args[1:3] == ["commit", "-m"] and args[3]:
        return True
    if len(args) in {3, 4} and args[1] == "ls-remote" and args[2] == "origin":
        return True
    if len(args) in {3, 4} and args[1] == "rev-parse":
        return args[2] in {"HEAD", "--show-toplevel", "--git-dir"} or args[2:] == ["--abbrev-ref", "HEAD"]
    if len(args) == 4 and args[1] == "push":
        remote, branch = args[2:]
    elif len(args) == 5 and args[1:3] == ["push", "-u"]:
        remote, branch = args[3:]
    else:
        return False
    if remote != "origin" or not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._/-]*", branch):
        return False
    configured = subprocess.run(
        [os.environ["CONFORMANCE_GIT"], "remote", "get-url", "origin"],
        cwd=str(repo), check=False, capture_output=True, text=True,
    )
    return configured.returncode == 0 and Path(configured.stdout.strip()).resolve(strict=True) == origin and inside(origin)

def gh_allowed():
    if args == ["gh", "auth", "status"] or args == ["gh", "repo", "view", "--json", "viewerPermission"]:
        return True
    if len(args) == 7 and args[1:3] == ["pr", "create"] and args[3] == "--title" and args[5] in {"--body", "--body-file"}:
        return bool(args[4] and args[6]) and (args[5] != "--body-file" or inside(Path(args[6])))
    if args in (["gh", "pr", "checks", "1"], ["gh", "pr", "checks", "1", "--watch"]):
        return True
    if args == ["gh", "pr", "view", "1", "--json", "mergeCommit", "--jq", ".mergeCommit.oid // empty"]:
        return True
    if len(args) == 6 and args[1:4] == ["pr", "comment", "1"] and args[4] == "--body" and args[5]:
        return True
    if args in (
        ["gh", "pr", "merge", "1", "--squash", "--delete-branch"],
        ["gh", "pr", "merge", "1", "--squash", "--delete-branch", "--auto"],
    ):
        return True
    if args in (
        ["gh", "api", "repos/{owner}/{repo}/pulls/1/reviews", "--jq", "length"],
        ["gh", "api", "repos/{owner}/{repo}/pulls/1/comments", "--jq", "length"],
    ):
        return True
    if len(args) == 7 and args[1:3] == ["api", "graphql"] and args[3:6] == ["-F", "number=1", "-f"]:
        return args[6].startswith("query=")
    return args == ["gh", "run", "view", "1", "--log-failed"]

if not args or (args[0] == "git" and not git_allowed()) or (args[0] == "gh" and not gh_allowed()) or args[0] not in {"git", "gh"}:
    raise SystemExit("fixture command rejected")
with (root / "wrapper-audit.jsonl").open("a", encoding="utf-8") as handle:
    handle.write(json.dumps({"argv": args}, sort_keys=True) + "\n")
if args[0] == "git":
    target = os.environ["CONFORMANCE_GIT"]
    os.execv(target, [target, *args[1:]])
python_target = os.environ["CONFORMANCE_PYTHON"]
os.execv(python_target, [python_target, "-c", gh_source.decode("utf-8"), *args[1:]])
'''
    path.parent.mkdir(parents=True)
    path.write_text(source, encoding="utf-8")
    path.chmod(0o755)


def write_gh_simulator(path):
    source = r'''#!/usr/bin/env python3
import json
import os
from pathlib import Path
import subprocess
import sys

root = Path(os.environ["CONFORMANCE_FIXTURE_ROOT"]).resolve(strict=True)
repo = Path(os.environ["CONFORMANCE_FIXTURE_REPO"]).resolve(strict=True)
origin = Path(os.environ["CONFORMANCE_FIXTURE_ORIGIN"]).resolve(strict=True)
for target in (repo, origin):
    target.relative_to(root)
state_path = root / "gh-state.json"
log_path = root / "gh-audit.jsonl"
args = sys.argv[1:]
with log_path.open("a", encoding="utf-8") as handle:
    handle.write(json.dumps({"argv": args}, sort_keys=True) + "\n")
state = json.loads(state_path.read_text(encoding="utf-8"))

def save():
    state_path.write_text(json.dumps(state, sort_keys=True) + "\n", encoding="utf-8")

def git(*git_args, cwd=repo):
    return subprocess.run(
        [os.environ["CONFORMANCE_GIT"], *git_args],
        cwd=str(cwd),
        env=os.environ,
        check=True,
        capture_output=True,
        text=True,
    ).stdout.strip()

if args[:2] == ["auth", "status"]:
    print("fixture authentication active")
elif args[:2] == ["repo", "view"]:
    print(json.dumps({"viewerPermission": "ADMIN"}))
elif args[:2] == ["pr", "create"]:
    if state.get("pr"):
        raise SystemExit("PR already exists")
    state["pr"] = {"number": 1, "head": "feat/fuzz-fixture", "merged": False, "merge_sha": None}
    save()
    print("https://fixture.invalid/pull/1")
elif args[:2] == ["pr", "checks"]:
    if not state.get("pr"):
        raise SystemExit("PR missing")
    print("fixture-check pass")
elif args[:2] == ["pr", "comment"]:
    if not state.get("pr"):
        raise SystemExit("PR missing")
    print("commented")
elif args[:2] == ["run", "view"]:
    print("fixture run passed")
elif args and args[0] == "api":
    if len(args) > 1 and args[1] == "graphql":
        print(json.dumps({"data": {"repository": {"pullRequest": {"reviewThreads": {"nodes": []}}}}}))
    elif "--jq" in args:
        print("0")
    else:
        print("[]")
elif args[:2] == ["pr", "view"]:
    merge_sha = (state.get("pr") or {}).get("merge_sha")
    if "--jq" in args:
        print(merge_sha or "")
    else:
        print(json.dumps({"mergeCommit": {"oid": merge_sha} if merge_sha else None}))
elif args[:2] == ["pr", "merge"]:
    pr = state.get("pr")
    if not pr or pr["merged"]:
        raise SystemExit("PR unavailable")
    merge_repo = root / "merge-work"
    git("clone", str(origin), str(merge_repo), cwd=root)
    git("config", "user.name", "Conformance Fixture", cwd=merge_repo)
    git("config", "user.email", "fixture@example.invalid", cwd=merge_repo)
    git("config", "commit.gpgsign", "false", cwd=merge_repo)
    git("checkout", "main", cwd=merge_repo)
    git("merge", "--squash", "origin/feat/fuzz-fixture", cwd=merge_repo)
    git("commit", "-m", "fixture squash merge", cwd=merge_repo)
    git("push", "origin", "main", cwd=merge_repo)
    if "--delete-branch" in args:
        git("push", "origin", "--delete", "feat/fuzz-fixture", cwd=merge_repo)
    pr["merged"] = True
    pr["merge_sha"] = git("rev-parse", "HEAD", cwd=merge_repo)
    save()
    print("merged")
else:
    raise SystemExit("unsupported fixture gh call")
'''
    path.write_text(source, encoding="utf-8")
    path.chmod(0o755)


def validate_gh_simulator(path):
    if path.is_symlink() or not path.is_file() or not os.access(str(path), os.X_OK):
        fail("fixture gh simulator missing")


def claude_policy_paths(fixture_root, feature_root, template):
    if template:
        return "__FIXTURE_ROOT__", "__FEATURE_ROOT__"
    return str(fixture_root.resolve(strict=True)), str(feature_root.resolve(strict=True))


def validate_claude_policy_document(claude, fixture_root, feature_root, template=False, guard_path=None):
    fixture_value, feature_value = claude_policy_paths(fixture_root, feature_root, template)
    guard_value = "__PATH_GUARD__" if template else shlex.quote(str(guard_path.resolve(strict=True)))
    if set(claude) != {"enableAllProjectMcpServers", "permissions", "sandbox", "hooks"}:
        fail("Claude policy shape mismatch")
    if claude.get("enableAllProjectMcpServers") is not False:
        fail("Claude policy enables project MCP")
    permissions = claude.get("permissions", {})
    if set(permissions) != {"allow", "deny"}:
        fail("Claude policy permission shape mismatch")
    denied = set(permissions.get("deny", []))
    allowed = set(permissions.get("allow", []))
    required_denials = {
        "WebFetch", "WebSearch", "Bash(curl:*)", "Bash(ssh:*)", "Bash(npm publish:*)",
        "Read(~/.claude.json)", "Read(~/.claude/**)", "Read(~/.codex/**)", "Read(~/.ssh/**)",
        "Read(~/.config/gh/**)", "Read(~/.netrc)", "Read(~/.aws/**)",
        "Read(~/.config/gcloud/**)", "Read(~/.kube/**)",
    }
    if not required_denials <= denied:
        fail("Claude policy denial inventory mismatch")
    required_allows = {
        f"Read(/{fixture_value}/**)", f"Read(/{feature_value}/**)",
        f"Write(/{fixture_value}/**)", f"Edit(/{fixture_value}/**)",
        "Bash(.conformance/bin/fixture-exec:*)",
    }
    if allowed != required_allows or {"Read", "Write", "Edit"} & allowed:
        fail("Claude policy allow inventory mismatch")
    if not {"Bash(git:*)", "Bash(gh:*)"} <= denied:
        fail("Claude policy raw command denial mismatch")
    sandbox = claude.get("sandbox", {})
    if set(sandbox) != {
        "enabled", "failIfUnavailable", "autoAllowBashIfSandboxed",
        "allowUnsandboxedCommands", "filesystem", "credentials"
    }:
        fail("Claude policy sandbox shape mismatch")
    if sandbox.get("enabled") is not True or sandbox.get("failIfUnavailable") is not True:
        fail("Claude policy sandbox enforcement mismatch")
    if sandbox.get("allowUnsandboxedCommands") is not False:
        fail("Claude policy unsandboxed escape enabled")
    if sandbox.get("autoAllowBashIfSandboxed") is not False:
        fail("Claude policy sandbox Bash auto-allow enabled")
    filesystem = sandbox.get("filesystem", {})
    if filesystem != {
        "denyRead": ["~/"],
        "allowRead": [fixture_value, feature_value],
        "denyWrite": ["~/"],
        "allowWrite": [fixture_value],
    }:
        fail("Claude policy filesystem boundary mismatch")
    credentials = sandbox.get("credentials", {})
    credential_files = {
        "~/.claude.json", "~/.claude", "~/.codex", "~/.ssh", "~/.config/gh",
        "~/.netrc", "~/.aws", "~/.config/gcloud", "~/.kube",
    }
    credential_env = {
        "ANTHROPIC_API_KEY", "CLAUDE_CODE_OAUTH_TOKEN", "OPENAI_API_KEY", "CODEX_API_KEY",
        "GH_TOKEN", "GITHUB_TOKEN", "AWS_ACCESS_KEY_ID", "AWS_SECRET_ACCESS_KEY",
        "AWS_SESSION_TOKEN", "GOOGLE_APPLICATION_CREDENTIALS", "NPM_TOKEN",
    }
    if set(credentials) != {"files", "envVars"}:
        fail("Claude policy credential shape mismatch")
    if credentials.get("files") != [
        {"path": path, "mode": "deny"} for path in (
            "~/.claude.json", "~/.claude", "~/.codex", "~/.ssh", "~/.config/gh",
            "~/.netrc", "~/.aws", "~/.config/gcloud", "~/.kube",
        )
    ] or {row.get("path") for row in credentials.get("files", [])} != credential_files:
        fail("Claude policy credential file inventory mismatch")
    if credentials.get("envVars") != [
        {"name": name, "mode": "deny"} for name in (
            "ANTHROPIC_API_KEY", "CLAUDE_CODE_OAUTH_TOKEN", "OPENAI_API_KEY", "CODEX_API_KEY",
            "GH_TOKEN", "GITHUB_TOKEN", "AWS_ACCESS_KEY_ID", "AWS_SECRET_ACCESS_KEY",
            "AWS_SESSION_TOKEN", "GOOGLE_APPLICATION_CREDENTIALS", "NPM_TOKEN",
        )
    ] or {row.get("name") for row in credentials.get("envVars", [])} != credential_env:
        fail("Claude policy credential environment inventory mismatch")
    if claude.get("hooks") != {
        "PreToolUse": [{
            "matcher": "Read|Edit|Write|Glob|Grep",
            "hooks": [{"type": "command", "command": guard_value}],
        }]
    }:
        fail("Claude policy path guard mismatch")


def materialize_claude_policy(claude, fixture_root, feature_root, guard_path):
    fixture_value, feature_value = claude_policy_paths(fixture_root, feature_root, False)
    encoded = json.dumps(claude)
    encoded = encoded.replace("__FIXTURE_ROOT__", fixture_value).replace("__FEATURE_ROOT__", feature_value)
    encoded = encoded.replace("__PATH_GUARD__", shlex.quote(str(guard_path.resolve(strict=True))))
    return json.loads(encoded)


def write_claude_path_guard(path, fixture_root, feature_root):
    fixture_value = str(fixture_root.resolve(strict=True))
    feature_value = str(feature_root.resolve(strict=True))
    source = f'''#!{sys.executable}
import json
from pathlib import Path
import sys

fixture_root = Path({fixture_value!r})
feature_root = Path({feature_value!r})
read_tools = {{"Read", "Glob", "Grep"}}
write_tools = {{"Edit", "Write"}}

try:
    request = json.load(sys.stdin)
    tool_name = request["tool_name"]
    tool_input = request["tool_input"]
    cwd = Path(request["cwd"]).resolve(strict=True)
    if tool_name in {{"Read", "Edit", "Write"}}:
        raw_path = tool_input["file_path"]
    elif tool_name in {{"Glob", "Grep"}}:
        raw_path = tool_input.get("path", str(cwd))
    else:
        raise ValueError("unknown tool")
    candidate = Path(raw_path)
    if not candidate.is_absolute():
        candidate = cwd / candidate
    resolved = candidate.resolve(strict=False)
    pattern_values = []
    if tool_name == "Glob":
        pattern_values.append(tool_input["pattern"])
    if tool_name == "Grep" and "glob" in tool_input:
        pattern_values.append(tool_input["glob"])
    unsafe_pattern = any(
        not isinstance(pattern, str)
        or Path(pattern).is_absolute()
        or pattern.startswith("~")
        or ".." in Path(pattern).parts
        for pattern in pattern_values
    )
except (KeyError, OSError, TypeError, ValueError, json.JSONDecodeError):
    print("blocked: malformed conformance file-tool path", file=sys.stderr)
    raise SystemExit(2)

roots = (fixture_root,) if tool_name in write_tools else (fixture_root, feature_root)
protected_write_paths = (
    fixture_root / ".claude",
    fixture_root / ".codex",
    fixture_root / ".conformance" / "bin",
    fixture_root / ".git",
    fixture_root / "empty-mcp.json",
)
protected_write = tool_name in write_tools and any(
    resolved == protected or protected in resolved.parents for protected in protected_write_paths
)
if (
    tool_name not in read_tools | write_tools
    or not any(resolved == root or root in resolved.parents for root in roots)
    or unsafe_pattern
    or protected_write
):
    print("blocked: path outside conformance boundary", file=sys.stderr)
    raise SystemExit(2)
raise SystemExit(0)
'''
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(source, encoding="utf-8")
    path.chmod(0o500)
    metadata = path.lstat()
    if not stat.S_ISREG(metadata.st_mode) or metadata.st_nlink != 1 or metadata.st_mode & 0o077:
        fail("Claude policy path guard identity mismatch")


def validate_policy_files(fixture_root, feature_root=root):
    policy_root = data_root / "policies"
    claude_path = policy_root / "claude-settings.json"
    codex_path = policy_root / "codex.rules"
    codex_profile_source = policy_root / "codex-profile.toml"
    claude = load_json(claude_path)
    guard_path = fixture_root / ".claude" / "hooks" / "conformance-path-guard"
    write_claude_path_guard(guard_path, fixture_root, feature_root)
    validate_claude_policy_document(claude, fixture_root, feature_root, template=True)
    runtime_claude = materialize_claude_policy(claude, fixture_root, feature_root, guard_path)
    validate_claude_policy_document(runtime_claude, fixture_root, feature_root, guard_path=guard_path)
    codex = codex_path.read_text(encoding="utf-8")
    for literal in (
        'prefix_rule(pattern=[".conformance/bin/fixture-exec"], decision="allow")',
        'prefix_rule(pattern=["git"], decision="forbidden")',
        'prefix_rule(pattern=["gh"], decision="forbidden")',
        'prefix_rule(pattern=["curl"], decision="forbidden")',
        'prefix_rule(pattern=["ssh"], decision="forbidden")',
        'prefix_rule(pattern=["npm", "publish"], decision="forbidden")',
    ):
        if codex.count(literal) != 1:
            fail("Codex policy literal mismatch")
    codex_executable = shutil.which("codex")
    if not codex_executable:
        fail("Codex profile executable unavailable")
    codex_link = Path(codex_executable).absolute()
    codex_bin_dir = codex_link.parent
    codex_runtime_root = codex_link.resolve(strict=True).parent.parent
    profile_template = codex_profile_source.read_text(encoding="utf-8")
    expected_profile_template = '''default_permissions = "conformance"
approval_policy = "on-request"
approvals_reviewer = "auto_review"

[permissions.conformance.filesystem]
":minimal" = "read"
"__CODEX_BIN_DIR__" = "read"
"__CODEX_RUNTIME_ROOT__" = "read"
"__FEATURE_ROOT__" = "read"

[permissions.conformance.filesystem.":workspace_roots"]
"." = "write"
'''
    if profile_template != expected_profile_template:
        fail("Codex permission profile template mismatch")
    runtime_profile = profile_template
    for placeholder, value in (
        ("__CODEX_BIN_DIR__", str(codex_bin_dir)),
        ("__CODEX_RUNTIME_ROOT__", str(codex_runtime_root)),
        ("__FEATURE_ROOT__", str(feature_root.resolve(strict=True))),
    ):
        runtime_profile = runtime_profile.replace(placeholder, value)
    if "__" in runtime_profile:
        fail("Codex permission profile materialization mismatch")
    settings_target = fixture_root / ".claude" / "settings.json"
    rules_target = fixture_root / ".codex" / "rules" / "conformance.rules"
    profile_target = fixture_root / ".codex" / "conformance.config.toml"
    settings_target.parent.mkdir(parents=True, exist_ok=True)
    rules_target.parent.mkdir(parents=True)
    write_json_atomic(settings_target, runtime_claude, fixture_root)
    shutil.copyfile(codex_path, rules_target)
    profile_target.write_text(runtime_profile, encoding="utf-8")
    profile_target.chmod(0o400)
    empty_mcp = fixture_root / "empty-mcp.json"
    empty_mcp.write_text('{"mcpServers": {}}\n', encoding="utf-8")
    for source, target in ((codex_path, rules_target),):
        if hashlib.sha256(source.read_bytes()).digest() != hashlib.sha256(target.read_bytes()).digest():
            fail("fixture policy copy digest mismatch")
    return 5


def validate_fixture():
    fixture_path = None
    host_origin_result = subprocess.run(
        ["git", "remote", "get-url", "origin"],
        cwd=str(root),
        check=False,
        capture_output=True,
        text=True,
    )
    host_origin = host_origin_result.stdout.strip() if host_origin_result.returncode == 0 else ""
    with tempfile.TemporaryDirectory(prefix="release-loop fixture ;[] ") as temp_path:
        fixture_root = Path(temp_path)
        fixture_path = fixture_root
        if not any(character in fixture_root.name for character in " ;[]"):
            fail("fixture root lacks path metacharacters")
        home = fixture_root / "home"
        temp_dir = fixture_root / "tmp"
        bin_dir = fixture_root / "bin"
        repo_path = fixture_root / "repo"
        origin_path = fixture_root / "origin.git"
        for path in (home, temp_dir, bin_dir, repo_path):
            path.mkdir()
        git_path = shutil.which("git")
        if not git_path:
            fail("git unavailable")
        env = {
            "PATH": f"{bin_dir}:{Path(git_path).parent}:/usr/bin:/bin",
            "HOME": str(home),
            "TMPDIR": str(temp_dir),
            "GIT_CONFIG_NOSYSTEM": "1",
            "GIT_TERMINAL_PROMPT": "0",
            "LC_ALL": "C",
            "CONFORMANCE_FIXTURE_ROOT": str(fixture_root),
            "CONFORMANCE_FIXTURE_REPO": str(repo_path),
            "CONFORMANCE_FIXTURE_ORIGIN": str(origin_path),
            "CONFORMANCE_GIT": git_path,
        }
        gh_path = bin_dir / "gh"
        try:
            validate_gh_simulator(gh_path)
        except ValueError as exc:
            if "fixture gh simulator missing" not in str(exc):
                fail(f"fixture simulator diagnostic mismatch: {exc}")
        else:
            fail("missing fixture simulator was accepted")
        write_gh_simulator(gh_path)
        validate_gh_simulator(gh_path)
        env["CONFORMANCE_GH"] = str(gh_path)
        env["CONFORMANCE_GH_SHA256"] = hashlib.sha256(gh_path.read_bytes()).hexdigest()
        env["CONFORMANCE_PYTHON"] = sys.executable
        wrapper_path = repo_path / ".conformance" / "bin" / "fixture-exec"
        write_fixture_wrapper(wrapper_path)
        env["CONFORMANCE_WRAPPER_SHA256"] = hashlib.sha256(wrapper_path.read_bytes()).hexdigest()
        policy_count = validate_policy_files(repo_path)
        (fixture_root / "gh-state.json").write_text("{}\n", encoding="utf-8")
        audit = []

        def internal_git(*args, cwd=repo_path):
            result = run_bounded([git_path, *args], cwd, env)
            audit.append({"argv": ["git", *args], "allowed": True, "executed": True, "reason": "fixture-setup"})
            if result.returncode != 0:
                fail(f"fixture setup failed: {args}: {result.stderr.strip()}")
            return result.stdout.strip()

        internal_git("init", "--bare", str(origin_path), cwd=fixture_root)
        internal_git("init")
        with (repo_path / ".git" / "info" / "exclude").open("a", encoding="utf-8") as handle:
            handle.write(".conformance/\n.claude/\n.codex/\nempty-mcp.json\n")
        for key, value in (
            ("user.name", "Conformance Fixture"),
            ("user.email", "fixture@example.invalid"),
            ("core.autocrlf", "false"),
            ("core.safecrlf", "false"),
            ("commit.gpgsign", "false"),
        ):
            internal_git("config", key, value)
        (repo_path / "payload.txt").write_text("base\n", encoding="utf-8")
        internal_git("add", "payload.txt")
        internal_git("commit", "-m", "fixture base")
        internal_git("branch", "-M", "main")
        internal_git("remote", "add", "origin", str(origin_path))
        internal_git("push", "-u", "origin", "main")
        base_sha = internal_git("rev-parse", "HEAD")
        internal_git("checkout", "-b", "feat/fuzz-fixture")
        (repo_path / "payload.txt").write_text("feature\n", encoding="utf-8")
        internal_git("add", "payload.txt")
        internal_git("commit", "-m", "fixture feature")
        feature_sha = internal_git("rev-parse", "HEAD")

        config = dict(
            line.split("=", 1)
            for line in internal_git("config", "--local", "--list").splitlines()
            if "=" in line
        )
        expected_config = {
            "user.name": "Conformance Fixture",
            "user.email": "fixture@example.invalid",
            "core.autocrlf": "false",
            "core.safecrlf": "false",
            "commit.gpgsign": "false",
        }
        if any(config.get(key) != value for key, value in expected_config.items()):
            fail("fixture Git config mismatch")
        if any(key.startswith("credential.") for key in config):
            fail("credential helper reached fixture")

        try:
            run_bounded([sys.executable, "-c", "import sys; sys.stdout.write('x' * 70000)"], repo_path, env)
        except ValueError as exc:
            if "output exceeded cap" not in str(exc):
                fail(f"fixture output-cap diagnostic mismatch: {exc}")
        else:
            fail("fixture output overflow was accepted")

        wrapper_command = [".conformance/bin/fixture-exec"]
        run_audited(
            wrapper_command + ["git", "push", "-u", "origin", "feat/fuzz-fixture"],
            repo_path,
            env,
            fixture_root,
            repo_path,
            audit,
        )
        gh_calls = (
            ["gh", "auth", "status"],
            ["gh", "repo", "view", "--json", "viewerPermission"],
            ["gh", "pr", "create", "--title", "fixture", "--body", "fixture"],
            ["gh", "pr", "checks", "1"],
            ["gh", "api", "repos/{owner}/{repo}/pulls/1/reviews", "--jq", "length"],
            ["gh", "api", "repos/{owner}/{repo}/pulls/1/comments", "--jq", "length"],
            ["gh", "api", "graphql", "-F", "number=1", "-f", "query=fixture"],
            ["gh", "pr", "merge", "1", "--squash", "--delete-branch"],
            ["gh", "pr", "view", "1", "--json", "mergeCommit", "--jq", ".mergeCommit.oid // empty"],
        )
        results = [
            run_audited(wrapper_command + call, repo_path, env, fixture_root, repo_path, audit)
            for call in gh_calls
        ]
        merge_sha = results[-1].stdout.strip()
        if not merge_sha or merge_sha in {base_sha, feature_sha}:
            fail("fixture squash merge identity mismatch")
        parent_line = internal_git("--git-dir", str(origin_path), "rev-list", "--parents", "-n", "1", merge_sha, cwd=fixture_root)
        if len(parent_line.split()) != 2:
            fail("fixture merge is not a squash commit")
        feature_tree = internal_git("--git-dir", str(origin_path), "rev-parse", f"{feature_sha}^{{tree}}", cwd=fixture_root)
        merge_tree = internal_git("--git-dir", str(origin_path), "rev-parse", f"{merge_sha}^{{tree}}", cwd=fixture_root)
        if feature_tree != merge_tree:
            fail("fixture squash merge tree mismatch")

        forbidden = (
            ["curl", "https://example.invalid"],
            ["ssh", "example.invalid"],
            ["npm", "publish"],
            [str(gh_path), "pr", "view", "1"],
            ["git", "status"],
            ["gh", "pr", "view", "1"],
            wrapper_command + ["git", "remote", "add", "outside", "https://example.invalid/repo.git"],
            wrapper_command + ["git", "push", "https://example.invalid/repo.git", "main"],
            ["sh", "-c", "git status"],
            ["env", "git", "status"],
            ["python3", "-c", "import socket"],
            wrapper_command + ["git", "-c", "credential.helper=x", "status"],
            wrapper_command + ["git", "credential", "fill"],
            wrapper_command + ["git", "clean", "-fdx"],
            wrapper_command + ["git", "push", "ext::ssh example.invalid", "main"],
            wrapper_command + ["git", "push", "origin", "--receive-pack=false", "main"],
            wrapper_command + ["gh", "release", "create", "v1"],
            wrapper_command + ["gh", "pr", "view", "1", "--repo", "outside/repo"],
            wrapper_command + ["gh", "pr", "merge", "1", "--squash", "--delete-branch", "--repo", "outside/repo"],
            wrapper_command + ["gh", "api", "--hostname", "example.invalid", "user"],
        )
        for command in forbidden:
            run_audited(command, repo_path, env, fixture_root, repo_path, audit, expect_success=False)

        wrapper_rejects = (
            wrapper_command + ["git", "push", "origin", "--receive-pack=false", "main"],
            wrapper_command + ["git", "ls-remote", "https://example.invalid/repo.git"],
            wrapper_command + ["gh", "pr", "view", "1", "--repo", "outside/repo"],
            wrapper_command + ["gh", "api", "--hostname", "example.invalid", "user"],
        )
        for command in wrapper_rejects:
            result = run_bounded(command, repo_path, env)
            if result.returncode == 0 or "fixture command rejected" not in result.stderr:
                fail(f"fixture wrapper negative probe was accepted: {command}")

        internal_git("config", "credential.helper", "fixture-should-reject")
        result = run_bounded(wrapper_command + ["git", "status"], repo_path, env)
        if result.returncode == 0 or "fixture runtime state rejected" not in result.stderr:
            fail("fixture credential-helper state was accepted")
        internal_git("config", "--unset", "credential.helper")
        hook_path = repo_path / ".git" / "hooks" / "pre-push"
        hook_path.write_text("#!/bin/sh\nexit 0\n", encoding="utf-8")
        hook_path.chmod(0o755)
        result = run_bounded(wrapper_command + ["git", "status"], repo_path, env)
        if result.returncode == 0 or "fixture runtime state rejected" not in result.stderr:
            fail("fixture executable hook state was accepted")
        hook_path.unlink()
        injected_env = dict(env)
        injected_env["GIT_CONFIG_COUNT"] = "1"
        result = run_bounded(wrapper_command + ["git", "status"], repo_path, injected_env)
        if result.returncode == 0 or "fixture runtime state rejected" not in result.stderr:
            fail("fixture Git environment injection was accepted")
        original_gh = gh_path.read_bytes()
        malicious_marker = fixture_root / "malicious-gh-executed"
        gh_path.write_text(
            "#!/usr/bin/env python3\nfrom pathlib import Path\nPath(%r).write_text('executed')\n" % str(malicious_marker),
            encoding="utf-8",
        )
        gh_path.chmod(0o755)
        result = run_bounded(wrapper_command + ["gh", "auth", "status"], repo_path, env)
        if result.returncode == 0 or "fixture gh simulator digest mismatch" not in result.stderr:
            fail("fixture gh simulator replacement was accepted")
        if malicious_marker.exists():
            fail("replacement gh simulator executed")
        gh_path.write_bytes(original_gh)
        gh_path.chmod(0o755)

        race_outside = fixture_root.parent / f"{fixture_root.name}-race-origin.git"
        race_outside.mkdir()

        def swap_origin_after_validation():
            internal_git("remote", "set-url", "origin", str(race_outside))

        run_audited(
            wrapper_command + ["git", "push", "origin", "main"],
            repo_path,
            env,
            fixture_root,
            repo_path,
            audit,
            expect_success=False,
            before_execute=swap_origin_after_validation,
        )
        if audit[-2]["executed"]:
            fail("fixture validate-then-swap command executed")
        internal_git("remote", "set-url", "origin", str(origin_path))
        race_outside.rmdir()

        inside_target = fixture_root / "inside-target"
        inside_target.mkdir()
        outside_target = fixture_root.parent / f"{fixture_root.name}-outside"
        outside_target.mkdir()
        if not path_is_inside(fixture_root, inside_target) or path_is_inside(fixture_root, outside_target):
            fail("fixture containment controlled pair failed")
        shutil.rmtree(inside_target)
        inside_target.symlink_to(outside_target, target_is_directory=True)
        if path_is_inside(fixture_root, inside_target):
            fail("fixture target replacement was accepted")
        outside_target.rmdir()

        gh_log = [json.loads(line) for line in (fixture_root / "gh-audit.jsonl").read_text(encoding="utf-8").splitlines()]
        executed_gh = [
            row for row in audit
            if row["executed"] and row["argv"][:2] == [".conformance/bin/fixture-exec", "gh"]
        ]
        if [row["argv"][2:] for row in executed_gh] != [row["argv"] for row in gh_log]:
            fail("fixture gh audit reconciliation mismatch")
        wrapper_log = [
            json.loads(line) for line in (fixture_root / "wrapper-audit.jsonl").read_text(encoding="utf-8").splitlines()
        ]
        executed_wrapper = [
            row for row in audit
            if row["executed"] and row["argv"][0] == ".conformance/bin/fixture-exec"
        ]
        if [row["argv"][1:] for row in executed_wrapper] != [row["argv"] for row in wrapper_log]:
            fail("fixture wrapper audit reconciliation mismatch")
        forbidden_rows = [row for row in audit if not row["allowed"]]
        if len(forbidden_rows) != len(forbidden) + 1:
            fail("fixture forbidden-command audit mismatch")
        forbidden_bytes = tuple(
            marker for marker in (host_origin, "https://github.com/real/repository.git", "ghp_fixture_secret") if marker
        )
        for path in fixture_root.rglob("*"):
            if path.is_file() and any(marker.encode() in path.read_bytes() for marker in forbidden_bytes):
                fail("host origin or credential marker entered fixture")
        summary = (len(gh_log), len(forbidden_rows), policy_count, len(audit))
    if fixture_path.exists():
        fail("fixture cleanup failed")
    return summary


def build_claude_initial(feature_root, model, settings_path, mcp_path, budget, prompt, session_id):
    return [
        "claude", "--print", "--output-format", "stream-json", "--verbose",
        "--session-id", session_id,
        "--plugin-dir", str(feature_root),
        "--model", model,
        "--settings", str(settings_path),
        "--setting-sources", "project",
        "--strict-mcp-config", "--mcp-config", str(mcp_path),
        "--no-chrome", "--permission-mode", "dontAsk",
        "--max-budget-usd", budget,
        prompt,
    ]


def build_claude_resume(feature_root, model, settings_path, mcp_path, budget, prompt, session_id):
    return [
        "claude", "--print", "--output-format", "stream-json", "--verbose",
        "--resume", session_id,
        "--plugin-dir", str(feature_root),
        "--model", model,
        "--settings", str(settings_path),
        "--setting-sources", "project",
        "--strict-mcp-config", "--mcp-config", str(mcp_path),
        "--no-chrome", "--permission-mode", "dontAsk",
        "--max-budget-usd", budget,
        prompt,
    ]


def build_codex_initial(fixture_root, model, result_path):
    return [
        "codex", "--profile", "conformance", "exec", "--json", "--ignore-user-config",
        "--model", model,
        "--cd", str(fixture_root), "--output-last-message", str(result_path), "-",
    ]


def build_codex_resume(model, session_id):
    return [
        "codex", "--profile", "conformance", "exec", "resume", "--json", "--ignore-user-config",
        "--model", model, session_id, "-",
    ]


def require_adapter_array(actual, expected, label):
    if actual != expected:
        fail(f"{label} argv mismatch")


def adapter_source_snapshot(feature_root):
    paths = []
    for relative in (".claude-plugin/plugin.json", ".codex-plugin/plugin.json", "PRINCIPLES.md"):
        path = feature_root / relative
        if path.is_file():
            paths.append(path)
    for directory in ("skills", "references", "schemas"):
        source_root = feature_root / directory
        if source_root.is_dir():
            paths.extend(path for path in source_root.rglob("*") if path.is_file())
    snapshot = {}
    for path in sorted(paths):
        if path.is_symlink():
            fail("preflight source symlink")
        relative = str(path.relative_to(feature_root))
        snapshot[relative] = hashlib.sha256(path.read_bytes()).hexdigest()
    if not snapshot or "skills/release-loop/SKILL.md" not in snapshot:
        fail("preflight source set incomplete")
    return snapshot


def verify_preflight_inputs(feature_root, source_snapshot, policy_digests):
    if adapter_source_snapshot(feature_root) != source_snapshot:
        fail("preflight source set changed")
    for path, digest in policy_digests.items():
        if hashlib.sha256(path.read_bytes()).hexdigest() != digest:
            fail("preflight policy changed")


def run_adapter_checked(command, cwd, env, input_bytes, feature_root, source_snapshot, policy_digests):
    verify_preflight_inputs(feature_root, source_snapshot, policy_digests)
    try:
        return run_bounded(command, cwd, env, input_bytes=input_bytes)
    finally:
        verify_preflight_inputs(feature_root, source_snapshot, policy_digests)


def read_bounded_file(path, allowed_root, size_cap=65536, after_open=None):
    try:
        path.parent.resolve(strict=True).relative_to(allowed_root.resolve(strict=True))
    except (FileNotFoundError, ValueError):
        fail("bounded result outside fixture")
    if not hasattr(os, "O_NOFOLLOW"):
        fail("bounded result no-follow unavailable")
    flags = os.O_RDONLY | os.O_NOFOLLOW
    try:
        descriptor = os.open(str(path), flags)
    except (FileNotFoundError, OSError):
        fail("bounded result missing or unsafe")
    try:
        metadata = os.fstat(descriptor)
        if not stat.S_ISREG(metadata.st_mode):
            fail("bounded result is not regular")
        if metadata.st_nlink != 1:
            fail("bounded result has multiple links")
        if metadata.st_size > size_cap:
            fail("bounded result exceeded cap")
        if after_open is not None:
            after_open()
        chunks = []
        remaining = size_cap + 1
        while remaining:
            chunk = os.read(descriptor, min(8192, remaining))
            if not chunk:
                break
            chunks.append(chunk)
            remaining -= len(chunk)
        payload = b"".join(chunks)
        if len(payload) > size_cap:
            fail("bounded result exceeded cap")
        try:
            return payload.decode("utf-8")
        except UnicodeDecodeError:
            fail("bounded result is not UTF-8")
    finally:
        os.close(descriptor)


def parse_session_id(output, harness):
    identities = []
    for line in output.splitlines():
        try:
            event = json.loads(line)
        except json.JSONDecodeError:
            fail(f"{harness} malformed session event")
        if harness == "claude" and event.get("type") == "system" and event.get("subtype") == "init":
            identities.append(event.get("session_id"))
        if harness == "codex" and event.get("type") == "thread.started":
            identities.append(event.get("thread_id"))
    if len(identities) != 1 or not isinstance(identities[0], str):
        fail(f"{harness} session identity missing or ambiguous")
    try:
        import uuid
        uuid.UUID(identities[0])
    except (ValueError, TypeError):
        fail(f"{harness} malformed session identity")
    return identities[0]


def write_fake_adapter(path, harness):
    source = f'''#!{sys.executable}
import hashlib
import json
import os
from pathlib import Path
import sys

harness = {harness!r}
args = sys.argv[1:]
stdin_bytes = sys.stdin.buffer.read()
capture_path = Path(os.environ["CONFORMANCE_CAPTURE"])
record = {{
    "harness": harness,
    "argv": args,
    "cwd": str(Path.cwd()),
    "stdin_sha256": hashlib.sha256(stdin_bytes).hexdigest(),
    "stdin_size": len(stdin_bytes),
    "environment_names": sorted(os.environ),
}}
with capture_path.open("a", encoding="utf-8") as handle:
    handle.write(json.dumps(record, sort_keys=True) + "\\n")

auth_command = (harness == "claude" and args == ["auth", "status"]) or (harness == "codex" and args == ["login", "status"])
if auth_command:
    auth_mode = os.environ.get("CONFORMANCE_AUTH_MODE")
    if auth_mode == "brokered":
        print(json.dumps({{"loggedIn": True, "method": "brokered"}}))
        raise SystemExit(0)
    if auth_mode == "missing":
        print(json.dumps({{"loggedIn": False, "method": "none"}}))
        raise SystemExit(0)
    print("auth isolation unreadable", file=sys.stderr)
    raise SystemExit(2)

mode = os.environ.get("CONFORMANCE_FAKE_MODE", "normal")
if mode == "source-write":
    target = Path(os.environ["CONFORMANCE_MUTATION_TARGET"])
    target.write_bytes(target.read_bytes() + b"\\nmutated")
if mode == "unbounded":
    sys.stdout.write("x" * 70000)
    raise SystemExit(0)
if mode == "malformed-output":
    print("not-json")
    raise SystemExit(0)

if harness == "claude":
    if "--session-id" in args:
        identity = args[args.index("--session-id") + 1]
    elif "--resume" in args:
        identity = args[args.index("--resume") + 1]
    else:
        identity = "missing"
    if mode == "malformed-id":
        identity = "not-a-uuid"
    print(json.dumps({{"type": "system", "subtype": "init", "session_id": identity}}))
else:
    identity = "22222222-2222-4222-8222-222222222222"
    if mode == "malformed-id":
        identity = "not-a-uuid"
    if "--output-last-message" in args:
        result_path = Path(args[args.index("--output-last-message") + 1])
        result_value = "x" * 70000 if mode == "oversized-result" else "fake codex result\\n"
        result_path.write_text(result_value, encoding="utf-8")
    print(json.dumps({{"type": "thread.started", "thread_id": identity}}))
'''
    path.write_text(source, encoding="utf-8")
    path.chmod(0o755)


def closed_adapter_env(fake_bin, isolated_home, temp_dir, capture_path, auth_mode="brokered", fake_mode="normal"):
    return {
        "PATH": f"{fake_bin}:/usr/bin:/bin",
        "HOME": str(isolated_home),
        "TMPDIR": str(temp_dir),
        "LC_ALL": "C",
        "LANG": "C",
        "CONFORMANCE_CAPTURE": str(capture_path),
        "CONFORMANCE_AUTH_MODE": auth_mode,
        "CONFORMANCE_FAKE_MODE": fake_mode,
    }


def probe_fake_auth(harness, env, cwd):
    command = [harness, "auth", "status"] if harness == "claude" else [harness, "login", "status"]
    result = run_bounded(command, cwd, env)
    if result.returncode != 0:
        return False
    try:
        status = json.loads(result.stdout)
    except json.JSONDecodeError:
        return False
    return status == {"loggedIn": True, "method": "brokered"}


def adapter_packet(golden, feature_root):
    source_path = (feature_root / golden["skill_source"]).resolve(strict=True)
    source_bytes = source_path.read_bytes()
    packet = {
        "schema": "release-loop-adapter-packet/v1",
        "prompt": golden["prompt"],
        "scripted_answers": golden["scripted_answers"],
        "feature_source": str(source_path),
        "skill_sha256": hashlib.sha256(source_bytes).hexdigest(),
        "skill_bytes": source_bytes.decode("utf-8"),
    }
    return (json.dumps(packet, sort_keys=True, ensure_ascii=False) + "\n").encode("utf-8")


def validate_preflight():
    fixture_path = None
    with tempfile.TemporaryDirectory(prefix="release-loop preflight ;[] ") as temp_path:
        fixture_root = Path(temp_path)
        fixture_path = fixture_root
        fake_bin = fixture_root / "bin"
        isolated_home = fixture_root / "home"
        temp_dir = fixture_root / "tmp"
        result_dir = fixture_root / "results"
        for path in (fake_bin, isolated_home, temp_dir, result_dir):
            path.mkdir()
        capture_path = fixture_root / "adapter-capture.jsonl"
        write_fake_adapter(fake_bin / "claude", "claude")
        write_fake_adapter(fake_bin / "codex", "codex")
        validate_policy_files(fixture_root)
        settings_path = fixture_root / ".claude" / "settings.json"
        guard_path = fixture_root / ".claude" / "hooks" / "conformance-path-guard"
        rules_path = fixture_root / ".codex" / "rules" / "conformance.rules"
        codex_profile_path = fixture_root / ".codex" / "conformance.config.toml"
        mcp_path = fixture_root / "empty-mcp.json"
        if not codex_profile_path.is_file() or "__" in codex_profile_path.read_text(encoding="utf-8"):
            fail("Codex permission profile missing or unmaterialized")
        if mcp_path.read_bytes() != b'{"mcpServers": {}}\n':
            fail("Claude empty MCP contract mismatch")
        policy_digests = {
            path: hashlib.sha256(path.read_bytes()).hexdigest()
            for path in (settings_path, guard_path, rules_path, codex_profile_path, mcp_path)
        }
        real_claude = shutil.which("claude")
        if not real_claude:
            fail("Claude policy doctor unavailable")
        doctor_env = dict(os.environ)
        doctor_env["HOME"] = str(isolated_home)
        doctor_env["TMPDIR"] = str(temp_dir)
        doctor_env.pop("CLAUDE_CONFIG_DIR", None)
        doctor = run_bounded(
            [real_claude, "--settings", str(settings_path), "--setting-sources", "project", "doctor"],
            fixture_root,
            doctor_env,
            output_cap=65536,
            timeout=30,
        )
        doctor_output = (doctor.stdout + doctor.stderr).lower()
        if doctor.returncode != 0 or any(marker in doctor_output for marker in ("unknown setting", "invalid setting")):
            fail("Claude policy doctor rejected runtime settings")
        source_path = root / "skills/release-loop/SKILL.md"
        source_digest = hashlib.sha256(source_path.read_bytes()).hexdigest()
        source_snapshot = adapter_source_snapshot(root)
        golden_claude = load_json(data_root / "golden/claude/L1-full-lifecycle.json")
        golden_codex = load_json(data_root / "golden/codex/L1-full-lifecycle.json")
        claude_id = "11111111-1111-4111-8111-111111111111"
        codex_id = "22222222-2222-4222-8222-222222222222"
        claude_model = "claude-fixture-model"
        codex_model = "codex-fixture-model"
        claude_initial = build_claude_initial(
            root, claude_model, settings_path, mcp_path, "1.00", golden_claude["prompt"], claude_id
        )
        claude_resume = build_claude_resume(
            root, claude_model, settings_path, mcp_path, "1.00", "approve", claude_id
        )
        codex_result = result_dir / "codex-last.txt"
        codex_initial = build_codex_initial(fixture_root, codex_model, codex_result)
        codex_resume = build_codex_resume(codex_model, codex_id)
        expected_claude_initial = [
            "claude", "--print", "--output-format", "stream-json", "--verbose",
            "--session-id", claude_id, "--plugin-dir", str(root), "--model", claude_model,
            "--settings", str(settings_path), "--setting-sources", "project",
            "--strict-mcp-config", "--mcp-config", str(mcp_path), "--no-chrome",
            "--permission-mode", "dontAsk", "--max-budget-usd", "1.00", golden_claude["prompt"],
        ]
        expected_claude_resume = [
            "claude", "--print", "--output-format", "stream-json", "--verbose",
            "--resume", claude_id, "--plugin-dir", str(root), "--model", claude_model,
            "--settings", str(settings_path), "--setting-sources", "project",
            "--strict-mcp-config", "--mcp-config", str(mcp_path), "--no-chrome",
            "--permission-mode", "dontAsk", "--max-budget-usd", "1.00", "approve",
        ]
        expected_codex_initial = [
            "codex", "--profile", "conformance", "exec", "--json", "--ignore-user-config",
            "--model", codex_model, "--cd", str(fixture_root),
            "--output-last-message", str(codex_result), "-",
        ]
        expected_codex_resume = [
            "codex", "--profile", "conformance", "exec", "resume", "--json", "--ignore-user-config",
            "--model", codex_model, codex_id, "-",
        ]
        for label, actual, expected in (
            ("Claude initial", claude_initial, expected_claude_initial),
            ("Claude resume", claude_resume, expected_claude_resume),
            ("Codex initial", codex_initial, expected_codex_initial),
            ("Codex resume", codex_resume, expected_codex_resume),
        ):
            require_adapter_array(actual, expected, label)
        codex_stdin = adapter_packet(golden_codex, root)
        claude_stdin = b""
        sensitive_names = {
            "GH_TOKEN", "GITHUB_TOKEN", "ANTHROPIC_API_KEY", "OPENAI_API_KEY", "CODEX_API_KEY",
            "GIT_CONFIG", "GIT_CONFIG_COUNT", "GIT_SSH", "GIT_SSH_COMMAND", "SSH_AUTH_SOCK", "SSH_ASKPASS",
        }
        env = closed_adapter_env(fake_bin, isolated_home, temp_dir, capture_path)
        if sensitive_names & env.keys() or any(name.startswith("GIT_CONFIG_") for name in env):
            fail("preflight inherited credential environment")
        credential_paths = (
            isolated_home / ".config/gh/hosts.yml",
            isolated_home / ".claude/.credentials.json",
            isolated_home / ".codex/auth.json",
            isolated_home / ".ssh",
        )
        if any(path.exists() for path in credential_paths):
            fail("preflight credential path reachable")
        if not probe_fake_auth("claude", env, fixture_root) or not probe_fake_auth("codex", env, fixture_root):
            fail("auth-isolation-unavailable")

        commands = (
            ("claude", claude_initial, claude_stdin, claude_id),
            ("claude", claude_resume, b"", claude_id),
            ("codex", codex_initial, codex_stdin, codex_id),
            ("codex", codex_resume, b"approve\n", codex_id),
        )
        for harness, command, stdin_bytes, expected_id in commands:
            result = run_adapter_checked(
                command, fixture_root, env, stdin_bytes, root, source_snapshot, policy_digests
            )
            if result.returncode != 0:
                fail(f"{harness} fake adapter failed")
            if parse_session_id(result.stdout, harness) != expected_id:
                fail(f"{harness} session identity mismatch")
        if read_bounded_file(codex_result, result_dir) != "fake codex result\n":
            fail("Codex bounded result missing")
        packet = json.loads(codex_stdin)
        if packet["skill_bytes"].encode("utf-8") != source_path.read_bytes():
            fail("Codex stdin skill bytes mismatch")
        if packet["feature_source"] != str(source_path.resolve(strict=True)):
            fail("Codex feature source mismatch")
        if packet["skill_sha256"] != source_digest:
            fail("Codex stdin source digest mismatch")
        verify_preflight_inputs(root, source_snapshot, policy_digests)

        captures = [json.loads(line) for line in capture_path.read_text(encoding="utf-8").splitlines()]
        adapter_captures = [row for row in captures if row["argv"] not in (["auth", "status"], ["login", "status"])]
        if len(adapter_captures) != 4 or any(sensitive_names & set(row["environment_names"]) for row in captures):
            fail("preflight adapter audit mismatch")
        expected_arrays = [
            expected_claude_initial[1:], expected_claude_resume[1:],
            expected_codex_initial[1:], expected_codex_resume[1:],
        ]
        if [row["argv"] for row in adapter_captures] != expected_arrays:
            fail("preflight adapter argv mismatch")
        expected_stdin = [b"", b"", codex_stdin, b"approve\n"]
        if [row["stdin_sha256"] for row in adapter_captures] != [hashlib.sha256(value).hexdigest() for value in expected_stdin]:
            fail("preflight adapter stdin mismatch")
        if any(Path(row["cwd"]).resolve() != fixture_root.resolve() for row in captures):
            fail("preflight adapter cwd mismatch")

        negatives = 0
        external_result = fixture_root.parent / f"{fixture_root.name}-external-result"
        external_result.write_text("external\n", encoding="utf-8")
        codex_result.unlink()
        codex_result.symlink_to(external_result)
        try:
            read_bounded_file(codex_result, result_dir)
        except ValueError as exc:
            if "bounded result missing or unsafe" not in str(exc):
                fail(f"result symlink diagnostic mismatch: {exc}")
        else:
            fail("result symlink accepted")
        finally:
            codex_result.unlink()
            codex_result.write_text("fake codex result\n", encoding="utf-8")
        negatives += 1

        codex_result.unlink()
        os.link(external_result, codex_result)
        try:
            read_bounded_file(codex_result, result_dir)
        except ValueError as exc:
            if "bounded result has multiple links" not in str(exc):
                fail(f"result hardlink diagnostic mismatch: {exc}")
        else:
            fail("result hardlink accepted")
        finally:
            codex_result.unlink()
            codex_result.write_text("fake codex result\n", encoding="utf-8")
        negatives += 1

        replacement_result = fixture_root.parent / f"{fixture_root.name}-replacement-result"
        replacement_result.write_text("y" * 70000, encoding="utf-8")

        def replace_result_after_open():
            codex_result.unlink()
            codex_result.symlink_to(replacement_result)

        try:
            if read_bounded_file(codex_result, result_dir, after_open=replace_result_after_open) != "fake codex result\n":
                fail("post-open result replacement changed descriptor bytes")
        finally:
            if codex_result.exists() or codex_result.is_symlink():
                codex_result.unlink()
            codex_result.write_text("fake codex result\n", encoding="utf-8")
            if external_result.exists():
                external_result.unlink()
            if replacement_result.exists():
                replacement_result.unlink()
        negatives += 1

        missing_env = closed_adapter_env(fake_bin, isolated_home, temp_dir, capture_path, auth_mode="missing")
        if probe_fake_auth("claude", missing_env, fixture_root):
            fail("missing auth fixture accepted")
        negatives += 1
        unreadable_env = closed_adapter_env(fake_bin, isolated_home, temp_dir, capture_path, auth_mode="unreadable")
        if probe_fake_auth("codex", unreadable_env, fixture_root):
            fail("unreadable auth fixture accepted")
        negatives += 1
        malformed_env = closed_adapter_env(fake_bin, isolated_home, temp_dir, capture_path, fake_mode="malformed-id")
        malformed = run_adapter_checked(
            claude_initial, fixture_root, malformed_env, b"", root, source_snapshot, policy_digests
        )
        try:
            parse_session_id(malformed.stdout, "claude")
        except ValueError as exc:
            if "malformed session identity" not in str(exc):
                fail(f"malformed identity diagnostic mismatch: {exc}")
        else:
            fail("malformed session identity accepted")
        negatives += 1
        wrong_resume = list(codex_resume)
        wrong_resume.remove("--ignore-user-config")
        try:
            require_adapter_array(wrong_resume, expected_codex_resume, "Codex resume")
        except ValueError as exc:
            if "Codex resume argv mismatch" not in str(exc):
                fail(f"wrong resume diagnostic mismatch: {exc}")
        else:
            fail("wrong resume flags accepted")
        negatives += 1
        drift_bytes = settings_path.read_bytes()
        settings_path.write_bytes(drift_bytes + b"\n")
        try:
            verify_preflight_inputs(root, source_snapshot, policy_digests)
        except ValueError as exc:
            if "preflight policy changed" not in str(exc):
                fail(f"policy drift diagnostic mismatch: {exc}")
        else:
            fail("policy drift accepted")
        settings_path.write_bytes(drift_bytes)
        negatives += 1
        source_copy_root = fixture_root / "source-copy"
        for relative in source_snapshot:
            target = source_copy_root / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(root / relative, target)
        source_copy_snapshot = adapter_source_snapshot(source_copy_root)
        source_copy = source_copy_root / "skills/release-loop/SKILL.md"
        source_copy.chmod(0o444)
        source_copy.parent.chmod(0o555)
        write_env = closed_adapter_env(fake_bin, isolated_home, temp_dir, capture_path, fake_mode="source-write")
        write_env["CONFORMANCE_MUTATION_TARGET"] = str(source_copy)
        write_command = build_claude_initial(
            source_copy_root, claude_model, settings_path, mcp_path, "1.00", golden_claude["prompt"], claude_id
        )
        try:
            write_result = run_adapter_checked(
                write_command,
                fixture_root,
                write_env,
                b"",
                source_copy_root,
                source_copy_snapshot,
                policy_digests,
            )
        except ValueError as exc:
            fail(f"source-write mutant crossed sandbox boundary: {exc}")
        finally:
            source_copy.parent.chmod(0o755)
            source_copy.chmod(0o644)
        if write_result.returncode == 0 or adapter_source_snapshot(source_copy_root) != source_copy_snapshot:
            fail("source-write mutant was accepted")
        negatives += 1
        unbounded_env = closed_adapter_env(fake_bin, isolated_home, temp_dir, capture_path, fake_mode="unbounded")
        try:
            run_adapter_checked(
                codex_initial, fixture_root, unbounded_env, codex_stdin, root, source_snapshot, policy_digests
            )
        except ValueError as exc:
            if "output exceeded cap" not in str(exc):
                fail(f"unbounded output diagnostic mismatch: {exc}")
        else:
            fail("unbounded adapter output accepted")
        negatives += 1
        malformed_output_env = closed_adapter_env(fake_bin, isolated_home, temp_dir, capture_path, fake_mode="malformed-output")
        malformed_output = run_adapter_checked(
            codex_initial, fixture_root, malformed_output_env, codex_stdin, root, source_snapshot, policy_digests
        )
        try:
            parse_session_id(malformed_output.stdout, "codex")
        except ValueError as exc:
            if "malformed session event" not in str(exc):
                fail(f"malformed output diagnostic mismatch: {exc}")
        else:
            fail("malformed adapter output accepted")
        negatives += 1
        oversized_result_env = closed_adapter_env(
            fake_bin, isolated_home, temp_dir, capture_path, fake_mode="oversized-result"
        )
        oversized = run_adapter_checked(
            codex_initial, fixture_root, oversized_result_env, codex_stdin, root, source_snapshot, policy_digests
        )
        if oversized.returncode != 0:
            fail("oversized result fixture failed before result validation")
        try:
            read_bounded_file(codex_result, result_dir)
        except ValueError as exc:
            if "bounded result exceeded cap" not in str(exc):
                fail(f"oversized result diagnostic mismatch: {exc}")
        else:
            fail("oversized result file accepted")
        negatives += 1
        summary = (2, 4, negatives, len(captures))
    if fixture_path.exists():
        fail("preflight cleanup failed")
    return summary


resource_cap_keys = {
    "max_turns_per_session",
    "per_turn_timeout",
    "session_timeout",
    "max_infrastructure_retries",
    "max_concurrency",
    "codex_observed_token_cap",
    "total_wall_time",
    "claude_total_budget_usd",
    "claude_max_invocation_usd",
}


def paid_command_digest(command):
    return hashlib.sha256((json.dumps(command, separators=(",", ":")) + "\n").encode()).hexdigest()


def validate_resource_caps(caps):
    if not isinstance(caps, dict) or set(caps) != resource_cap_keys:
        return "resource-cap-shape"
    integer_keys = resource_cap_keys - {"claude_total_budget_usd", "claude_max_invocation_usd"}
    if any(not isinstance(caps[key], int) or caps[key] <= 0 for key in integer_keys - {"max_infrastructure_retries"}):
        return "resource-cap-value"
    if not isinstance(caps["max_infrastructure_retries"], int) or caps["max_infrastructure_retries"] < 0:
        return "resource-cap-value"
    try:
        total = Decimal(caps["claude_total_budget_usd"])
        maximum = Decimal(caps["claude_max_invocation_usd"])
    except Exception:
        return "resource-cap-value"
    if total <= 0 or maximum <= 0 or maximum > total:
        return "resource-cap-value"
    return None


def validate_paid_receipt(
    receipt,
    command,
    gate_kind,
    expected_models,
    expected_caps,
    expected_auth_brokers,
    expected_source_identity,
    expected_approval_packet_sha256,
    session_marker,
    session_started,
    observed_at,
    used_nonces,
):
    required = {
        "schema", "gate_kind", "command_sha256", "models", "caps", "approved_at",
        "auth_brokers", "source_identity", "approval_packet_sha256", "session_marker", "nonce", "status",
    }
    if not isinstance(receipt, dict) or set(receipt) != required:
        return "paid-receipt-shape"
    if receipt["schema"] != "release-loop-paid-receipt/v1" or receipt["gate_kind"] != gate_kind:
        return "paid-receipt-gate"
    if receipt["status"] != "approved":
        return "paid-receipt-consumed"
    if receipt["command_sha256"] != paid_command_digest(command):
        return "paid-receipt-command"
    if receipt["session_marker"] != session_marker:
        return "paid-receipt-session"
    if not isinstance(receipt["models"], dict) or set(receipt["models"]) != {"claude", "codex"}:
        return "paid-receipt-models"
    if not all(isinstance(value, str) and value for value in receipt["models"].values()):
        return "paid-receipt-models"
    if receipt["models"] != expected_models:
        return "paid-receipt-models"
    cap_invariant = validate_resource_caps(receipt["caps"])
    if cap_invariant is not None:
        return cap_invariant
    if receipt["caps"] != expected_caps:
        return "paid-receipt-caps"
    if receipt["auth_brokers"] != expected_auth_brokers:
        return "paid-receipt-auth-brokers"
    if not isinstance(expected_auth_brokers, dict) or set(expected_auth_brokers) != {"claude", "codex"}:
        return "paid-receipt-auth-brokers"
    if any(not re.fullmatch(r"[0-9a-f]{64}", str(value)) for value in expected_auth_brokers.values()):
        return "paid-receipt-auth-brokers"
    if receipt["source_identity"] != expected_source_identity:
        return "paid-receipt-source"
    if not isinstance(expected_source_identity, dict) or set(expected_source_identity) != {
        "snapshot_sha256", "head_sha", "plan_body_seal"
    }:
        return "paid-receipt-source"
    if not re.fullmatch(r"[0-9a-f]{64}", str(expected_source_identity["snapshot_sha256"])):
        return "paid-receipt-source"
    if not re.fullmatch(r"[0-9a-f]{40,64}", str(expected_source_identity["head_sha"])):
        return "paid-receipt-source"
    if not re.fullmatch(r"[0-9a-f]{64}", str(expected_source_identity["plan_body_seal"])):
        return "paid-receipt-source"
    if receipt["approval_packet_sha256"] != expected_approval_packet_sha256:
        return "paid-receipt-approval-packet"
    if not re.fullmatch(r"[0-9a-f]{64}", str(expected_approval_packet_sha256)):
        return "paid-receipt-approval-packet"
    approved = parse_gate_timestamp(receipt["approved_at"])
    started = parse_gate_timestamp(session_started)
    observed = parse_gate_timestamp(observed_at)
    if None in {approved, started, observed} or not started <= approved <= observed:
        return "paid-receipt-stale"
    nonce = receipt["nonce"]
    if not isinstance(nonce, str) or not re.fullmatch(r"[0-9a-f]{32}", nonce):
        return "paid-receipt-nonce"
    if nonce in used_nonces:
        return "paid-receipt-reused"
    return None


def consume_paid_receipt(receipt, used_nonces):
    if receipt.get("status") != "approved" or receipt.get("nonce") in used_nonces:
        return None, "paid-receipt-reused"
    consumed = copy.deepcopy(receipt)
    consumed["status"] = "consumed"
    used_nonces.add(consumed["nonce"])
    return consumed, None


def parse_flag_pairs(arguments, required_flags):
    if len(arguments) % 2:
        fail("paid command flag missing value")
    parsed = {}
    for index in range(0, len(arguments), 2):
        flag, value = arguments[index:index + 2]
        if flag not in required_flags or flag in parsed or not value:
            fail("paid command flag mismatch")
        parsed[flag] = value
    if set(parsed) != required_flags:
        fail("paid command flag inventory mismatch")
    return parsed


def parse_paid_mode(mode_name, arguments):
    if mode_name == "live-pilot":
        required = {
            "--harness", "--case", "--claude-model", "--codex-model", "--claude-total-budget-usd",
            "--claude-max-invocation-usd", "--max-turns", "--per-turn-timeout",
            "--codex-observed-token-cap", "--max-infrastructure-retries", "--session-timeout",
        }
    else:
        required = {
            "--cases", "--repetitions", "--claude-model", "--codex-model", "--max-turns-per-session",
            "--per-turn-timeout", "--session-timeout", "--max-infrastructure-retries", "--max-concurrency",
            "--codex-observed-token-cap", "--total-wall-time", "--claude-total-budget-usd",
            "--claude-max-invocation-usd",
        }
    parsed = parse_flag_pairs(arguments, required)
    if mode_name == "live-pilot":
        if parsed["--harness"] != "all" or parsed["--case"] != "L1-full-lifecycle":
            fail("pilot scope mismatch")
        max_turns = parsed["--max-turns"]
        max_concurrency = "1"
        total_wall = str(int(parsed["--session-timeout"]) * 2)
    else:
        if parsed["--cases"] != "L1-full-lifecycle,L2-mid-loop-resume,L3-post-merge-resume,L4-degraded-dispatch":
            fail("live case scope mismatch")
        if parsed["--repetitions"] != "3":
            fail("live repetition mismatch")
        max_turns = parsed["--max-turns-per-session"]
        max_concurrency = parsed["--max-concurrency"]
        total_wall = parsed["--total-wall-time"]
    try:
        caps = {
            "max_turns_per_session": int(max_turns),
            "per_turn_timeout": int(parsed["--per-turn-timeout"]),
            "session_timeout": int(parsed["--session-timeout"]),
            "max_infrastructure_retries": int(parsed["--max-infrastructure-retries"]),
            "max_concurrency": int(max_concurrency),
            "codex_observed_token_cap": int(parsed["--codex-observed-token-cap"]),
            "total_wall_time": int(total_wall),
            "claude_total_budget_usd": parsed["--claude-total-budget-usd"],
            "claude_max_invocation_usd": parsed["--claude-max-invocation-usd"],
        }
    except ValueError:
        fail("paid command numeric flag invalid")
    invariant = validate_resource_caps(caps)
    if invariant is not None:
        fail(invariant)
    models = {"claude": parsed["--claude-model"], "codex": parsed["--codex-model"]}
    command = ["bash", "scripts/test-release-loop-conformance.sh", mode_name, *arguments]
    return command, models, caps


def build_paid_approval_packet(mode_name, command, models, caps, auth_brokers, source_identity, pilot_evidence=None):
    return {
        "schema": "release-loop-paid-approval/v1",
        "gate_kind": mode_name,
        "command": shlex.join(command),
        "command_sha256": paid_command_digest(command),
        "models": models,
        "caps": caps,
        "auth_brokers": auth_brokers,
        "source_identity": source_identity,
        "adapter_eligibility_sha256": adapter_eligibility_proof_digest(current_adapter_eligibility()),
        "codex_hard_dollar_cap": "unavailable-observed-token-cap-enforced",
        "pilot_evidence": pilot_evidence,
    }


def validate_paid_approval_packet(packet, mode_name, command, models, caps, auth_brokers, source_identity):
    expected = build_paid_approval_packet(
        mode_name,
        command,
        models,
        caps,
        auth_brokers,
        source_identity,
        packet.get("pilot_evidence") if isinstance(packet, dict) else None,
    )
    if not isinstance(packet, dict) or set(packet) != set(expected):
        return "paid-approval-packet-shape"
    if packet != expected:
        return "paid-approval-packet-mismatch"
    if mode_name == "live-pilot" and packet["pilot_evidence"] is not None:
        return "paid-approval-packet-pilot-evidence"
    if mode_name == "live":
        evidence = packet["pilot_evidence"]
        if not isinstance(evidence, dict) or set(evidence) != {"results_sha256", "settlement_sha256"}:
            return "paid-approval-packet-pilot-evidence"
        if any(not re.fullmatch(r"[0-9a-f]{64}", str(value)) for value in evidence.values()):
            return "paid-approval-packet-pilot-evidence"
    return None


def read_paid_approval_packet(path, allowed_root, mode_name, command, models, caps, auth_brokers, source_identity):
    payload = read_bounded_file(path, allowed_root, 1048576).encode("utf-8")
    try:
        packet = json.loads(payload)
    except json.JSONDecodeError:
        fail("paid-approval-packet-JSON")
    invariant = validate_paid_approval_packet(
        packet, mode_name, command, models, caps, auth_brokers, source_identity
    )
    if invariant is not None:
        fail(invariant)
    return packet, hashlib.sha256(payload).hexdigest()


def consume_paid_receipt_file(
    receipt_path,
    nonce_ledger_path,
    command,
    gate_kind,
    models,
    caps,
    auth_brokers,
    source_identity,
    source_identity_reader,
    approval_packet_sha256,
    approval_packet_reader,
    session_marker,
    session_started,
    observed_at,
    allowed_root,
):
    lock_path = nonce_ledger_path.with_suffix(".lock")
    lock_path.parent.mkdir(parents=True, exist_ok=True)
    if lock_path.is_symlink():
        fail("paid receipt lock is symlink")
    if not hasattr(os, "O_NOFOLLOW"):
        fail("paid receipt no-follow unavailable")
    lock_descriptor = os.open(str(lock_path), os.O_CREAT | os.O_RDWR | os.O_NOFOLLOW, 0o600)
    try:
        fcntl.flock(lock_descriptor, fcntl.LOCK_EX)
        receipt_bytes = read_bounded_file(receipt_path, allowed_root, 65536).encode("utf-8")
        try:
            receipt = json.loads(receipt_bytes)
        except json.JSONDecodeError:
            fail("paid receipt JSON invalid")
        if nonce_ledger_path.exists():
            nonce_ledger = json.loads(read_bounded_file(nonce_ledger_path, allowed_root, 1048576))
        else:
            nonce_ledger = {"schema": "release-loop-paid-nonces/v1", "consumptions": []}
        if (
            not isinstance(nonce_ledger, dict)
            or nonce_ledger.get("schema") != "release-loop-paid-nonces/v1"
            or not isinstance(nonce_ledger.get("consumptions"), list)
        ):
            fail("paid nonce ledger invalid")
        used_nonces = {row.get("nonce") for row in nonce_ledger["consumptions"] if isinstance(row, dict)}
        if source_identity_reader() != source_identity:
            fail("paid-receipt-source")
        if approval_packet_reader() != approval_packet_sha256:
            fail("paid-receipt-approval-packet")
        invariant = validate_paid_receipt(
            receipt,
            command,
            gate_kind,
            models,
            caps,
            auth_brokers,
            source_identity,
            approval_packet_sha256,
            session_marker,
            session_started,
            observed_at,
            used_nonces,
        )
        if invariant is not None:
            fail(invariant)
        consumption = {
            "nonce": receipt["nonce"],
            "receipt_sha256": hashlib.sha256(receipt_bytes).hexdigest(),
            "command_sha256": paid_command_digest(command),
            "consumed_at": observed_at,
            "session_marker": session_marker,
        }
        nonce_ledger["consumptions"].append(consumption)
        write_json_atomic(nonce_ledger_path, nonce_ledger, allowed_root)
        return receipt, consumption
    finally:
        fcntl.flock(lock_descriptor, fcntl.LOCK_UN)
        os.close(lock_descriptor)


def new_resource_ledger(caps):
    invariant = validate_resource_caps(caps)
    if invariant is not None:
        fail(invariant)
    return {
        "claude_remaining": Decimal(caps["claude_total_budget_usd"]),
        "claude_spent": Decimal("0"),
        "claude_active": None,
        "codex_tokens": 0,
        "active_process": None,
        "calls": [],
        "overrun": None,
        "budget_frozen": False,
    }


def current_adapter_eligibility():
    return {
        "schema": "release-loop-adapter-eligibility/v1",
        "adapter": "claude-cli",
        "eligible": False,
        "failure": "claude-hard-budget-unavailable",
    }


def require_current_adapter_eligibility():
    eligibility = current_adapter_eligibility()
    if eligibility.get("eligible") is not True:
        fail(eligibility.get("failure", "adapter-ineligible"))
    proof = eligibility.get("proof")
    invariant = validate_adapter_eligibility_proof(
        proof,
        GOVERNED_HARD_CAP_COMPONENTS,
        GOVERNED_HARD_CAP_PROOF_PATH,
    )
    if invariant is not None:
        fail(invariant)
    if eligibility.get("proof_sha256") != adapter_eligibility_proof_digest(proof):
        fail("adapter-eligibility-proof-digest")
    return eligibility


def validate_adapter_eligibility_proof(record, component_paths, proof_path):
    required = {"schema", "eligible", "adapter", "enforcer", "verifier", "mechanism", "proof_sha256"}
    if not isinstance(record, dict) or set(record) != required:
        return "adapter-eligibility-proof-shape"
    if record["schema"] != "release-loop-adapter-eligibility-proof/v1" or record["eligible"] is not True:
        return "adapter-eligibility-proof-state"
    if not isinstance(component_paths, dict) or set(component_paths) != {"adapter", "enforcer", "verifier"}:
        return "adapter-eligibility-proof-components"
    for component in ("adapter", "enforcer", "verifier"):
        value = record.get(component)
        if not isinstance(value, dict) or set(value) != {"identity", "version", "sha256"}:
            return f"adapter-eligibility-proof-{component}"
        if not all(isinstance(value[key], str) and value[key] for key in ("identity", "version")):
            return f"adapter-eligibility-proof-{component}"
        path = Path(component_paths[component])
        if path.is_symlink() or not path.is_file():
            return f"adapter-eligibility-proof-{component}"
        if hashlib.sha256(path.read_bytes()).hexdigest() != value["sha256"]:
            return f"adapter-eligibility-proof-{component}"
    if record["verifier"]["identity"] != "release-loop-hard-budget-verifier/v1":
        return "adapter-eligibility-proof-verifier"
    if not isinstance(record["mechanism"], str) or not record["mechanism"]:
        return "adapter-eligibility-proof-mechanism"
    proof_path = Path(proof_path)
    if proof_path.is_symlink() or not proof_path.is_file():
        return "adapter-eligibility-proof-artifact"
    if hashlib.sha256(proof_path.read_bytes()).hexdigest() != record["proof_sha256"]:
        return "adapter-eligibility-proof-artifact"
    if (
        GOVERNED_HARD_CAP_COMPONENTS is None
        or GOVERNED_HARD_CAP_PROOF_PATH is None
        or component_paths != GOVERNED_HARD_CAP_COMPONENTS
        or proof_path != GOVERNED_HARD_CAP_PROOF_PATH
    ):
        return "adapter-eligibility-proof-untrusted"
    return None


def adapter_eligibility_proof_digest(record):
    return hashlib.sha256((json.dumps(record, sort_keys=True, separators=(",", ":")) + "\n").encode()).hexdigest()


def reserve_claude(ledger, caps, call_id):
    if ledger["claude_active"] is not None:
        return "claude-reservation-overlap"
    amount = Decimal(caps["claude_max_invocation_usd"])
    if ledger["claude_remaining"] < amount:
        return "claude-budget-exhausted"
    ledger["claude_remaining"] -= amount
    ledger["claude_active"] = {"call_id": call_id, "reserved": amount}
    return None


def settle_claude(ledger, call_id, observed_cost):
    active = ledger.get("claude_active")
    if not active or active["call_id"] != call_id:
        return "claude-reservation-missing"
    reserved = active["reserved"]
    charge = reserved if observed_cost is None else Decimal(str(observed_cost))
    if charge < 0 or charge > reserved:
        return "claude-settlement-invalid"
    ledger["claude_spent"] += charge
    ledger["claude_remaining"] += reserved - charge
    ledger["claude_active"] = None
    ledger["calls"].append({"harness": "claude", "call_id": call_id, "charge": str(charge)})
    return None


def extract_claude_accounting(stdout, stderr, fixture_root, host_home):
    terminal_results = []
    for line in stdout.splitlines():
        try:
            event = json.loads(line)
        except json.JSONDecodeError:
            continue
        if event.get("type") != "result":
            continue
        subtype = event.get("subtype")
        cost = event.get("total_cost_usd")
        if not isinstance(subtype, str) or not isinstance(cost, (int, float, str)):
            continue
        parsed_cost = Decimal(str(cost))
        if not parsed_cost.is_finite() or parsed_cost < 0:
            fail("claude-accounting-cost-invalid")
        terminal_results.append((subtype, parsed_cost))
    if len(terminal_results) > 1:
        overruns = [row for row in terminal_results if row[0] == "error_max_budget_usd"]
        if not overruns:
            fail("claude-terminal-result-duplicate")
        result_subtype, parsed_actual = max(overruns, key=lambda row: row[1])
    elif terminal_results:
        result_subtype, parsed_actual = terminal_results[0]
    else:
        result_subtype, parsed_actual = None, None
    trust_warning = None
    fixture_text = str(Path(fixture_root).resolve())
    home_text = str(Path(host_home).resolve())
    expected_warning = (
        r"Ignoring (?P<count>[1-9][0-9]*) permissions\.allow entries from \.claude/settings\.json: "
        r"this workspace has not been trusted\. Run Claude Code interactively here once and accept the trust "
        r"dialog, or set projects\[\"" + re.escape(fixture_text) + r"\"\]\.hasTrustDialogAccepted: true in "
        + re.escape(home_text) + r"/\.claude\.json\."
    )
    for line in stderr.splitlines():
        if re.fullmatch(expected_warning, line):
            trust_warning = "workspace-untrusted-project-allows-ignored"
    return {
        "reported_actual": str(parsed_actual) if parsed_actual is not None else None,
        "result_subtype": result_subtype,
        "trust_warning": trust_warning,
    }


def close_claude_overrun(ledger, call_id, accounting):
    active = ledger.get("claude_active")
    if not active or active.get("call_id") != call_id:
        fail("claude-reservation-missing")
    reserved = active["reserved"]
    reported_actual = Decimal(str(accounting.get("reported_actual")))
    if (
        accounting.get("result_subtype") != "error_max_budget_usd"
        or not reported_actual.is_finite()
        or reported_actual <= reserved
    ):
        fail("claude-overrun-evidence-invalid")
    total_before = ledger["claude_remaining"] + reserved
    raw_remaining = total_before - reported_actual
    remaining_after = max(Decimal("0"), raw_remaining)
    record = {
        "call_id": call_id,
        "reserved": str(reserved),
        "reported_actual": str(reported_actual),
        "difference": str(reported_actual - reserved),
        "total_before": str(total_before),
        "raw_remaining": str(raw_remaining),
        "remaining_after": str(remaining_after),
        "result_subtype": "error_max_budget_usd",
        "trust_warning": accounting.get("trust_warning"),
        "retryable": False,
        "budget_frozen": True,
    }
    ledger["claude_spent"] += reported_actual
    ledger["claude_remaining"] = remaining_after
    ledger["claude_active"] = None
    ledger["active_process"] = None
    ledger["overrun"] = record
    ledger["budget_frozen"] = True
    ledger["calls"].append({"harness": "claude", "call_id": call_id, "overrun": record})
    return record


def record_codex_usage(ledger, caps, call_id, observed_tokens):
    if not isinstance(observed_tokens, int) or observed_tokens < 0:
        return "codex-token-observation-invalid"
    if ledger["codex_tokens"] + observed_tokens > caps["codex_observed_token_cap"]:
        return "codex-token-cap-exhausted"
    ledger["codex_tokens"] += observed_tokens
    ledger["calls"].append({"harness": "codex", "call_id": call_id, "tokens": observed_tokens})
    return None


def invocation_start_invariant(
    ledger,
    caps,
    harness,
    turns,
    session_elapsed,
    total_elapsed,
    retry_count=0,
    prior_failure=None,
):
    if ledger.get("active_process") is not None:
        return "process-still-active"
    if harness == "claude" and ledger.get("claude_active") is not None:
        return "claude-reservation-unsettled"
    if harness == "codex" and ledger.get("active_codex", 0) >= caps["max_concurrency"]:
        return "codex-concurrency-cap"
    if turns > caps["max_turns_per_session"]:
        return "turn-cap-exhausted"
    if session_elapsed > caps["session_timeout"]:
        return "session-timeout-exhausted"
    if total_elapsed > caps["total_wall_time"]:
        return "total-wall-time-exhausted"
    if retry_count:
        if prior_failure != "infrastructure":
            return "conformance-retry-forbidden"
        if retry_count > caps["max_infrastructure_retries"]:
            return "infrastructure-retry-cap"
    return None


def process_table(_root_pid=None):
    result = subprocess.run(
        ["ps", "-axo", "pid=,ppid=,pgid="],
        check=False,
        capture_output=True,
        text=True,
        timeout=2,
    )
    if result.returncode != 0:
        fail("process-table-unavailable")
    table = {}
    for line in result.stdout.splitlines():
        fields = line.split()
        if len(fields) != 3 or not all(field.isdigit() for field in fields):
            continue
        pid, parent, group = map(int, fields)
        table[pid] = {"parent": parent, "group": group}
    return table


def descendant_pids(root_pid, table):
    descendants = set()
    frontier = {root_pid}
    while frontier:
        children = {pid for pid, row in table.items() if row["parent"] in frontier and pid not in descendants}
        descendants.update(children)
        frontier = children
    return descendants


def pid_exists(pid):
    try:
        os.kill(pid, 0)
    except ProcessLookupError:
        return False
    except PermissionError:
        return True
    return True


def managed_process(command, timeout_seconds, term_grace=0.2, table_reader=process_table):
    process = subprocess.Popen(
        command,
        stdin=subprocess.DEVNULL,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        start_new_session=True,
    )
    started = time.monotonic()
    term_sent = False
    kill_sent = False
    observed_descendants = set()

    def read_table():
        try:
            return table_reader(process.pid)
        except Exception:
            if process.poll() is None:
                try:
                    os.killpg(process.pid, signal.SIGKILL)
                except ProcessLookupError:
                    pass
                process.wait(timeout=2)
            raise

    while process.poll() is None and time.monotonic() - started < timeout_seconds:
        table = read_table()
        observed_descendants.update(descendant_pids(process.pid, table))
        time.sleep(0.05)
    if process.poll() is None:
        table = read_table()
        observed_descendants.update(descendant_pids(process.pid, table))
        os.killpg(process.pid, signal.SIGTERM)
        term_sent = True
        deadline = time.monotonic() + term_grace
        while process.poll() is None and time.monotonic() < deadline:
            time.sleep(0.01)
        try:
            os.killpg(process.pid, signal.SIGKILL)
            kill_sent = True
        except ProcessLookupError:
            pass
    returncode = process.wait(timeout=2)
    absence_deadline = time.monotonic() + 1
    remaining_descendants = set(observed_descendants)
    while remaining_descendants and time.monotonic() < absence_deadline:
        current = read_table()
        remaining_descendants &= current.keys()
        if remaining_descendants:
            time.sleep(0.05)
    current = read_table()
    group_absent = not any(row["group"] == process.pid for row in current.values())
    return {
        "pid": process.pid,
        "returncode": returncode,
        "timed_out": term_sent,
        "term_sent": term_sent,
        "kill_sent": kill_sent,
        "reaped": process.poll() is not None,
        "process_group_reaped": group_absent,
        "descendants_absent": not remaining_descendants,
        "observed_descendants": sorted(observed_descendants),
    }


def pilot_command(caps, models):
    return [
        "bash", "scripts/test-release-loop-conformance.sh", "live-pilot",
        "--harness", "all", "--case", "L1-full-lifecycle",
        "--claude-model", models["claude"], "--codex-model", models["codex"],
        "--claude-total-budget-usd", caps["claude_total_budget_usd"],
        "--claude-max-invocation-usd", caps["claude_max_invocation_usd"],
        "--max-turns", str(caps["max_turns_per_session"]),
        "--per-turn-timeout", str(caps["per_turn_timeout"]),
        "--codex-observed-token-cap", str(caps["codex_observed_token_cap"]),
        "--max-infrastructure-retries", str(caps["max_infrastructure_retries"]),
        "--session-timeout", str(caps["session_timeout"]),
    ]


def full_run_command(caps, models):
    return [
        "bash", "scripts/test-release-loop-conformance.sh", "live",
        "--cases", "L1-full-lifecycle,L2-mid-loop-resume,L3-post-merge-resume,L4-degraded-dispatch",
        "--repetitions", "3", "--claude-model", models["claude"], "--codex-model", models["codex"],
        "--max-turns-per-session", str(caps["max_turns_per_session"]),
        "--per-turn-timeout", str(caps["per_turn_timeout"]),
        "--session-timeout", str(caps["session_timeout"]),
        "--max-infrastructure-retries", str(caps["max_infrastructure_retries"]),
        "--max-concurrency", str(caps["max_concurrency"]),
        "--codex-observed-token-cap", str(caps["codex_observed_token_cap"]),
        "--total-wall-time", str(caps["total_wall_time"]),
        "--claude-total-budget-usd", caps["claude_total_budget_usd"],
        "--claude-max-invocation-usd", caps["claude_max_invocation_usd"],
    ]


def derive_full_run_caps(pilot_caps, pilot_results, pilot_ledger):
    if validate_pilot_results(pilot_results) is not None:
        fail(validate_pilot_results(pilot_results))
    max_turns = max(int(row.get("turns") or 0) for row in pilot_results)
    max_elapsed = max(float(row.get("elapsed_seconds") or 0) for row in pilot_results)
    codex_tokens = sum(int(row.get("observed_tokens") or 0) for row in pilot_results if row["harness"] == "codex")
    expected_per_harness = 12
    pilot_claude_sessions = sum(1 for row in pilot_results if row["harness"] == "claude")
    if pilot_claude_sessions != 1:
        fail("pilot Claude session count mismatch")
    settled_per_session = pilot_ledger["claude_spent"] / pilot_claude_sessions
    full_total_budget = settled_per_session * expected_per_harness * 2
    if full_total_budget < Decimal(pilot_caps["claude_max_invocation_usd"]):
        full_total_budget = Decimal(pilot_caps["claude_max_invocation_usd"])
    return {
        "max_turns_per_session": max(1, max_turns + 1),
        "per_turn_timeout": max(1, int(max_elapsed * 2) + 1),
        "session_timeout": max(1, int(max_elapsed * 3) + 1),
        "max_infrastructure_retries": pilot_caps["max_infrastructure_retries"],
        "max_concurrency": 1,
        "codex_observed_token_cap": max(1, codex_tokens * expected_per_harness * 2),
        "total_wall_time": max(1, int(max_elapsed * 24 * 2) + 1),
        "claude_total_budget_usd": f"{full_total_budget:.2f}",
        "claude_max_invocation_usd": pilot_caps["claude_max_invocation_usd"],
    }


def validate_strata(results):
    expected = {
        (harness, case_id, repetition)
        for harness in ("claude", "codex")
        for case_id in ("L1-full-lifecycle", "L2-mid-loop-resume", "L3-post-merge-resume", "L4-degraded-dispatch")
        for repetition in range(1, 4)
    }
    identities = {(row.get("harness"), row.get("case_id"), row.get("repetition")) for row in results}
    if identities != expected or len(results) != 24:
        return "live-strata-incomplete"
    for row in results:
        if row.get("infrastructure_status") != "pass":
            return "live-infrastructure-failure"
        if row.get("verdict") not in {"conformant", "nonconformant"}:
            return "live-verdict-unknown"
        if row["verdict"] != "conformant":
            return "live-conformance-failure"
    return None


def validate_pilot_results(results):
    if len(results) != 2 or {row.get("harness") for row in results} != {"claude", "codex"}:
        return "pilot-incomplete"
    if any(row.get("case_id") != "L1-full-lifecycle" or row.get("repetition") != 1 for row in results):
        return "pilot-incomplete"
    if any(row.get("infrastructure_status") != "pass" for row in results):
        return "pilot-infrastructure-failure"
    if any(row.get("verdict") != "conformant" for row in results):
        return "pilot-conformance-failure"
    return None


def object_digest(value):
    return hashlib.sha256((json.dumps(value, sort_keys=True, separators=(",", ":")) + "\n").encode()).hexdigest()


def write_json_atomic(path, value, allowed_root, mode_bits=0o600):
    path.parent.mkdir(parents=True, exist_ok=True)
    try:
        path.parent.resolve(strict=True).relative_to(allowed_root.resolve(strict=True))
    except (FileNotFoundError, ValueError):
        fail("atomic JSON path outside allowed root")
    if path.is_symlink():
        fail("atomic JSON target is symlink")
    payload = (json.dumps(value, sort_keys=True, indent=2) + "\n").encode("utf-8")
    descriptor, temporary_name = tempfile.mkstemp(prefix=f".{path.name}.", dir=str(path.parent))
    temporary_path = Path(temporary_name)
    try:
        os.fchmod(descriptor, mode_bits)
        written = 0
        while written < len(payload):
            written += os.write(descriptor, payload[written:])
        os.fsync(descriptor)
        os.close(descriptor)
        descriptor = None
        os.replace(str(temporary_path), str(path))
        directory_descriptor = os.open(str(path.parent), os.O_RDONLY)
        try:
            os.fsync(directory_descriptor)
        finally:
            os.close(directory_descriptor)
    finally:
        if descriptor is not None:
            os.close(descriptor)
        if temporary_path.exists():
            temporary_path.unlink()


def write_bytes_atomic(path, payload, allowed_root, mode_bits=0o600):
    path.parent.mkdir(parents=True, exist_ok=True)
    try:
        path.parent.resolve(strict=True).relative_to(allowed_root.resolve(strict=True))
    except (FileNotFoundError, ValueError):
        fail("atomic bytes path outside allowed root")
    if path.is_symlink():
        fail("atomic bytes target is symlink")
    descriptor, temporary_name = tempfile.mkstemp(prefix=f".{path.name}.", dir=str(path.parent))
    temporary_path = Path(temporary_name)
    try:
        os.fchmod(descriptor, mode_bits)
        written = 0
        while written < len(payload):
            written += os.write(descriptor, payload[written:])
        os.fsync(descriptor)
        os.close(descriptor)
        descriptor = None
        os.replace(str(temporary_path), str(path))
        directory_descriptor = os.open(str(path.parent), os.O_RDONLY)
        try:
            os.fsync(directory_descriptor)
        finally:
            os.close(directory_descriptor)
    finally:
        if descriptor is not None:
            os.close(descriptor)
        if temporary_path.exists():
            temporary_path.unlink()


def artifact_has_secret(value):
    serialized = json.dumps(value, sort_keys=True)
    return bool(re.search(r"(api[_-]?key|access[_-]?token|refresh[_-]?token|password|credential|ghp_[A-Za-z0-9])", serialized, re.IGNORECASE))


def generation_manifest(models, results, full_command, receipt, ledger, process_proof):
    source_snapshot = adapter_source_snapshot(root)
    plugin_digest = hashlib.sha256(
        (json.dumps(source_snapshot, sort_keys=True, separators=(",", ":")) + "\n").encode()
    ).hexdigest()
    result_digest = object_digest(results)
    command_audit = [{"harness": row["harness"], "call_id": row["call_id"]} for row in ledger["calls"]]
    settlement = {
        "claude_remaining": str(ledger["claude_remaining"]),
        "claude_spent": str(ledger["claude_spent"]),
        "claude_active": ledger["claude_active"],
        "codex_tokens": ledger["codex_tokens"],
    }
    for artifact in (results, command_audit, settlement, process_proof):
        if artifact_has_secret(artifact):
            fail("generation artifact contains secret material")
    return {
        "schema": "release-loop-generation/v1",
        "plugin_sha256": plugin_digest,
        "source_manifest_sha256": hashlib.sha256((data_root / "source-manifest.json").read_bytes()).hexdigest(),
        "corpus_sha256": hashlib.sha256((data_root / "corpus.json").read_bytes()).hexdigest(),
        "mutations_sha256": hashlib.sha256((data_root / "mutations.json").read_bytes()).hexdigest(),
        "claude_settings_sha256": hashlib.sha256((data_root / "policies/claude-settings.json").read_bytes()).hexdigest(),
        "codex_rules_sha256": hashlib.sha256((data_root / "policies/codex.rules").read_bytes()).hexdigest(),
        "codex_profile_sha256": hashlib.sha256((data_root / "policies/codex-profile.toml").read_bytes()).hexdigest(),
        "models": models,
        "cli_versions": {"claude": "fake-2.1.241", "codex": "fake-0.149.1"},
        "results_sha256": result_digest,
        "command_sha256": paid_command_digest(full_command),
        "command_audit_sha256": object_digest(command_audit),
        "receipt_sha256": object_digest(receipt),
        "caps_settlement_sha256": object_digest(settlement),
        "process_proof_sha256": object_digest(process_proof),
        "codex_hard_dollar_cap": "unavailable-observed-token-cap-enforced",
    }


def validate_generation_manifest(manifest):
    required = {
        "schema", "plugin_sha256", "source_manifest_sha256", "corpus_sha256", "mutations_sha256",
        "claude_settings_sha256", "codex_rules_sha256", "codex_profile_sha256",
        "models", "cli_versions", "results_sha256",
        "command_sha256", "command_audit_sha256", "receipt_sha256", "caps_settlement_sha256",
        "process_proof_sha256", "codex_hard_dollar_cap",
    }
    if not isinstance(manifest, dict) or set(manifest) != required:
        return "generation-manifest-shape"
    if manifest["schema"] != "release-loop-generation/v1":
        return "generation-manifest-schema"
    digest_keys = {key for key in required if key.endswith("sha256")}
    if any(not re.fullmatch(r"[0-9a-f]{64}", str(manifest[key])) for key in digest_keys):
        return "generation-manifest-digest"
    if manifest["codex_hard_dollar_cap"] != "unavailable-observed-token-cap-enforced":
        return "generation-manifest-codex-cap"
    if artifact_has_secret(manifest):
        return "generation-manifest-secret"
    return None


def normalized_resource_ledger(ledger):
    active = ledger["claude_active"]
    if active is not None:
        active = {**active, "reserved": str(active["reserved"])}
    return {
        "claude_remaining": str(ledger["claude_remaining"]),
        "claude_spent": str(ledger["claude_spent"]),
        "claude_active": active,
        "codex_tokens": ledger["codex_tokens"],
        "active_process": ledger["active_process"],
        "calls": ledger["calls"],
        "overrun": ledger.get("overrun"),
        "budget_frozen": ledger.get("budget_frozen", False),
    }


def process_proof_complete(proof):
    required_true = {"leader_waited", "pgid_absent", "descendants_absent"}
    return (
        isinstance(proof, dict)
        and required_true <= proof.keys()
        and all(proof[key] is True for key in required_true)
        and proof.get("observed_escape_detected") is False
    )


def empty_process_table(_root_pid):
    return {}


def fake_paid_launcher(call_spec):
    turn_id = f"{call_spec['call_id']}:turn-1"
    call_spec["before_invocation"](turn_id, 0)
    proof = managed_process([sys.executable, "-c", "raise SystemExit(0)"], 2, table_reader=empty_process_table)
    complete_proof = {
        "invocation_id": call_spec["call_id"],
        "leader_waited": proof["reaped"],
        "pgid_absent": proof["process_group_reaped"],
        "descendants_absent": proof["descendants_absent"],
        "observed_escape_detected": not proof["descendants_absent"],
        "timed_out": proof["timed_out"],
        "term_sent": proof["term_sent"],
        "kill_sent": proof["kill_sent"],
    }
    call_spec["after_invocation"](
        turn_id,
        complete_proof,
        "0.05" if call_spec["harness"] == "claude" else None,
        100 if call_spec["harness"] == "codex" else None,
        0,
    )
    return {
        "infrastructure_status": "pass",
        "verdict": "conformant",
        "observed_cost": "0.05" if call_spec["harness"] == "claude" else None,
        "observed_tokens": 100 if call_spec["harness"] == "codex" else None,
        "turns": 1,
        "elapsed_seconds": 0.1,
        "process_proof": complete_proof,
        "command_audit": {
            "invocation_id": call_spec["call_id"],
            "harness": call_spec["harness"],
            "case_id": call_spec["case_id"],
            "repetition": call_spec["repetition"],
        },
    }


def execute_paid_schedule(
    mode_name,
    caps,
    models,
    launcher,
    state_path=None,
    state_root=None,
    clock=time.monotonic,
    state_writer=write_json_atomic,
):
    cases = ["L1-full-lifecycle"] if mode_name == "live-pilot" else [
        "L1-full-lifecycle", "L2-mid-loop-resume", "L3-post-merge-resume", "L4-degraded-dispatch"
    ]
    repetitions = 1 if mode_name == "live-pilot" else 3
    ledger = new_resource_ledger(caps)
    results = []
    process_proofs = []
    command_audit = []
    started = clock()

    def persist_state(status, generation_sha256=None, failure=None):
        if state_path is None:
            return
        state = {
            "schema": "release-loop-paid-state/v1",
            "mode": mode_name,
            "status": status,
            "resource_ledger": normalized_resource_ledger(ledger),
            "result_count": len(results),
            "process_proof_count": len(process_proofs),
            "command_audit_count": len(command_audit),
            "generation_sha256": generation_sha256,
        }
        if failure is not None:
            state["failure"] = failure
        state_writer(state_path, state, state_root)

    def reject_schedule(reason):
        status = "failed-active-process" if ledger["active_process"] is not None else "failed"
        persist_state(status, failure=reason)
        fail(reason)

    if state_path is not None and state_path.exists():
        existing = json.loads(read_bounded_file(state_path, state_root, 1048576))
        if existing.get("status") != "complete" or existing.get("resource_ledger", {}).get("active_process") is not None:
            fail("orphan-process-state")
    persist_state("running")
    for harness in ("claude", "codex"):
        for case_id in cases:
            for repetition in range(1, repetitions + 1):
                call_id = f"{harness}:{case_id}:{repetition}"
                invariant = invocation_start_invariant(
                    ledger,
                    caps,
                    harness,
                    1,
                    0,
                    int(clock() - started),
                )
                if invariant is not None:
                    reject_schedule(invariant)
                session_proofs = []

                def before_invocation(turn_id, session_elapsed=0):
                    start_invariant = invocation_start_invariant(
                        ledger,
                        caps,
                        harness,
                        1,
                        session_elapsed,
                        int(clock() - started),
                    )
                    if start_invariant is not None:
                        reject_schedule(start_invariant)
                    if harness == "claude":
                        reservation_invariant = reserve_claude(ledger, caps, turn_id)
                        if reservation_invariant is not None:
                            reject_schedule(reservation_invariant)
                    ledger["active_process"] = {"invocation_id": turn_id, "status": "launch-intent"}
                    persist_state("running")

                def after_invocation(
                    turn_id,
                    proof,
                    observed_cost,
                    observed_tokens,
                    session_elapsed=0,
                    claude_accounting=None,
                ):
                    if not process_proof_complete(proof):
                        reject_schedule("process-exit-proof-incomplete")
                    session_proofs.append(proof)
                    process_proofs.append(proof)
                    ledger["active_process"] = None
                    if harness == "claude":
                        active = ledger.get("claude_active")
                        if (
                            claude_accounting is not None
                            and active is not None
                            and claude_accounting.get("result_subtype") == "error_max_budget_usd"
                            and Decimal(str(claude_accounting.get("reported_actual"))) > active["reserved"]
                        ):
                            close_claude_overrun(ledger, turn_id, claude_accounting)
                            persist_state("failed", failure="claude-hard-budget-overrun")
                            fail("claude-hard-budget-overrun")
                        settlement_invariant = settle_claude(ledger, turn_id, observed_cost)
                    else:
                        settlement_invariant = record_codex_usage(ledger, caps, turn_id, observed_tokens)
                    if settlement_invariant is not None:
                        reject_schedule(settlement_invariant)
                    persist_state("running")
                    elapsed_invariant = invocation_start_invariant(
                        ledger,
                        caps,
                        harness,
                        1,
                        session_elapsed,
                        int(clock() - started),
                    )
                    if elapsed_invariant in {"session-timeout-exhausted", "total-wall-time-exhausted"}:
                        reject_schedule(elapsed_invariant)

                try:
                    outcome = launcher(
                        {
                            "call_id": call_id,
                            "harness": harness,
                            "case_id": case_id,
                            "repetition": repetition,
                            "models": models,
                            "caps": caps,
                            "before_invocation": before_invocation,
                            "after_invocation": after_invocation,
                        }
                    )
                except Exception:
                    if ledger.get("budget_frozen") is True and ledger.get("overrun") is not None:
                        try:
                            persist_state("failed", failure="claude-hard-budget-overrun")
                        except Exception:
                            pass
                        fail("claude-hard-budget-overrun")
                    if harness == "claude" and ledger["claude_active"] is not None:
                        active_id = ledger["claude_active"]["call_id"]
                        settle_claude(ledger, active_id, None)
                    existing_failure = None
                    if state_path is not None and state_path.exists():
                        existing_state = json.loads(read_bounded_file(state_path, state_root, 1048576))
                        if str(existing_state.get("status", "")).startswith("failed"):
                            existing_failure = existing_state.get("failure")
                    if existing_failure is None:
                        persist_state(
                            "failed-active-process" if ledger["active_process"] is not None else "failed",
                            failure="scheduler-exception",
                        )
                    raise
                if not session_proofs:
                    reject_schedule("process-exit-proof-missing")
                command_audit.append(outcome["command_audit"])
                results.append(
                    {
                        "harness": harness,
                        "case_id": case_id,
                        "repetition": repetition,
                        "infrastructure_status": outcome["infrastructure_status"],
                        "verdict": outcome["verdict"],
                        "turns": outcome.get("turns"),
                        "elapsed_seconds": outcome.get("elapsed_seconds"),
                        "observed_cost": outcome.get("observed_cost"),
                        "observed_tokens": outcome.get("observed_tokens"),
                    }
                )
    if ledger["active_process"] is not None or ledger["claude_active"] is not None:
        reject_schedule("paid schedule unsettled")
    pilot_invariant = validate_pilot_results(results) if mode_name == "live-pilot" else None
    if pilot_invariant is not None:
        reject_schedule(pilot_invariant)
    live_invariant = validate_strata(results) if mode_name == "live" else None
    if live_invariant is not None:
        reject_schedule(live_invariant)
    persist_state("sessions-complete")
    return results, ledger, process_proofs, command_audit


def finalize_generation_directory(
    target,
    mode_name,
    models,
    exact_command,
    receipt,
    consumption,
    results,
    ledger,
    process_proofs,
    command_audit,
    approval_packet=None,
):
    target.mkdir(parents=True, exist_ok=False)
    persisted_ledger = normalized_resource_ledger(ledger)
    persisted_ledger["approved_caps"] = receipt["caps"]
    artifacts = {
        "results.json": results,
        "resource-ledger.json": persisted_ledger,
        "process-proofs.json": process_proofs,
        "command-audit.json": command_audit,
        "receipt-consumption.json": consumption,
    }
    if approval_packet is not None:
        artifacts["full-run-approval.json"] = approval_packet
    for name, value in artifacts.items():
        if artifact_has_secret(value):
            fail(f"generation artifact rejected: {name}")
        write_json_atomic(target / name, value, target)
    source_snapshot = adapter_source_snapshot(root)
    manifest = {
        "schema": "release-loop-generation/v1",
        "mode": mode_name,
        "plugin_sha256": object_digest(source_snapshot),
        "source_manifest_sha256": hashlib.sha256((data_root / "source-manifest.json").read_bytes()).hexdigest(),
        "corpus_sha256": hashlib.sha256((data_root / "corpus.json").read_bytes()).hexdigest(),
        "mutations_sha256": hashlib.sha256((data_root / "mutations.json").read_bytes()).hexdigest(),
        "claude_settings_sha256": hashlib.sha256((data_root / "policies/claude-settings.json").read_bytes()).hexdigest(),
        "codex_rules_sha256": hashlib.sha256((data_root / "policies/codex.rules").read_bytes()).hexdigest(),
        "codex_profile_sha256": hashlib.sha256((data_root / "policies/codex-profile.toml").read_bytes()).hexdigest(),
        "models": models,
        "cli_versions": {"claude": "2.1.241", "codex": "0.149.1"},
        "command_sha256": paid_command_digest(exact_command),
        "receipt_sha256": object_digest(receipt),
        "receipt_consumption_sha256": hashlib.sha256((target / "receipt-consumption.json").read_bytes()).hexdigest(),
        "results_sha256": hashlib.sha256((target / "results.json").read_bytes()).hexdigest(),
        "caps_settlement_sha256": hashlib.sha256((target / "resource-ledger.json").read_bytes()).hexdigest(),
        "process_proof_sha256": hashlib.sha256((target / "process-proofs.json").read_bytes()).hexdigest(),
        "command_audit_sha256": hashlib.sha256((target / "command-audit.json").read_bytes()).hexdigest(),
        "codex_hard_dollar_cap": "unavailable-observed-token-cap-enforced",
    }
    if approval_packet is not None:
        manifest["full_run_approval_sha256"] = hashlib.sha256(
            (target / "full-run-approval.json").read_bytes()
        ).hexdigest()
    write_json_atomic(target / "manifest.json", manifest, target)
    manifest_digest = hashlib.sha256((target / "manifest.json").read_bytes()).hexdigest()
    complete = {"schema": "release-loop-generation-complete/v1", "manifest_sha256": manifest_digest}
    write_json_atomic(target / "complete.json", complete, target)
    return manifest_digest


def verify_complete_generation(target):
    if not (target / "complete.json").is_file():
        return "generation-complete-missing"
    complete = json.loads(read_bounded_file(target / "complete.json", target, 65536))
    if complete.get("schema") != "release-loop-generation-complete/v1":
        return "generation-complete-shape"
    manifest_path = target / "manifest.json"
    if hashlib.sha256(manifest_path.read_bytes()).hexdigest() != complete.get("manifest_sha256"):
        return "generation-complete-manifest"
    manifest = json.loads(read_bounded_file(manifest_path, target, 1048576))
    artifact_map = {
        "results_sha256": "results.json",
        "caps_settlement_sha256": "resource-ledger.json",
        "process_proof_sha256": "process-proofs.json",
        "command_audit_sha256": "command-audit.json",
        "receipt_consumption_sha256": "receipt-consumption.json",
    }
    if "full_run_approval_sha256" in manifest:
        artifact_map["full_run_approval_sha256"] = "full-run-approval.json"
    for key, name in artifact_map.items():
        if hashlib.sha256((target / name).read_bytes()).hexdigest() != manifest.get(key):
            return "generation-complete-artifact"
    results = json.loads(read_bounded_file(target / "results.json", target, 1048576))
    if manifest.get("mode") == "live" and validate_strata(results) is not None:
        return validate_strata(results)
    proofs = json.loads(read_bounded_file(target / "process-proofs.json", target, 1048576))
    if not proofs or not all(process_proof_complete(proof) for proof in proofs):
        return "generation-complete-process-proof"
    ledger = json.loads(read_bounded_file(target / "resource-ledger.json", target, 1048576))
    if ledger.get("active_process") is not None or ledger.get("claude_active") is not None:
        return "generation-complete-unsettled"
    return None


def run_paid_mode_entry(
    mode_name,
    arguments,
    launcher,
    evidence_root,
    auth_brokers,
    source_identity,
    source_identity_reader,
    approval_packet_sha256,
    approval_packet_reader,
    session_marker,
    session_started,
    observed_at,
):
    exact_command, models, caps = parse_paid_mode(mode_name, arguments)
    receipt_path = evidence_root / f"{mode_name}-receipt.json"
    nonce_path = evidence_root / "paid-nonces.json"
    receipt, consumption = consume_paid_receipt_file(
        receipt_path,
        nonce_path,
        exact_command,
        mode_name,
        models,
        caps,
        auth_brokers,
        source_identity,
        source_identity_reader,
        approval_packet_sha256,
        approval_packet_reader,
        session_marker,
        session_started,
        observed_at,
        evidence_root,
    )
    state_path = evidence_root / f"{mode_name}-state-{receipt['nonce']}.json"
    results, ledger, process_proofs, command_audit = execute_paid_schedule(
        mode_name, caps, models, launcher, state_path=state_path, state_root=evidence_root
    )
    approval_packet = None
    derived_full_command = None
    if mode_name == "live-pilot":
        derived_caps = derive_full_run_caps(caps, results, ledger)
        derived_full_command = full_run_command(derived_caps, models)
        pilot_settlement = normalized_resource_ledger(ledger)
        pilot_settlement["approved_caps"] = caps
        approval_packet = build_paid_approval_packet(
            "live",
            derived_full_command,
            models,
            derived_caps,
            auth_brokers,
            source_identity,
            {
                "results_sha256": object_digest(results),
                "settlement_sha256": object_digest(pilot_settlement),
            },
        )
    generation_root = evidence_root / f"{mode_name}-generation-{receipt['nonce']}"
    generation_digest = finalize_generation_directory(
        generation_root,
        mode_name,
        models,
        exact_command,
        receipt,
        consumption,
        results,
        ledger,
        process_proofs,
        command_audit,
        approval_packet,
    )
    if verify_complete_generation(generation_root) is not None:
        fail("paid generation verification failed")
    completed_state = json.loads(read_bounded_file(state_path, evidence_root, 1048576))
    completed_state["status"] = "complete"
    completed_state["generation_sha256"] = generation_digest
    write_json_atomic(state_path, completed_state, evidence_root)
    return {
        "results": results,
        "generation_path": str(generation_root),
        "generation_sha256": generation_digest,
        "full_command": shlex.join(derived_full_command) if derived_full_command is not None else None,
    }


def prepare_pilot_approval(arguments, evidence_root, auth_brokers, source_identity):
    command, models, caps = parse_paid_mode("live-pilot", arguments)
    packet = build_paid_approval_packet(
        "live-pilot", command, models, caps, auth_brokers, source_identity
    )
    path = evidence_root / "live-pilot-approval.json"
    payload = (json.dumps(packet, sort_keys=True, indent=2) + "\n").encode("utf-8")
    write_bytes_atomic(path, payload, evidence_root)
    verified_packet, digest = read_paid_approval_packet(
        path, evidence_root, "live-pilot", command, models, caps, auth_brokers, source_identity
    )
    if verified_packet != packet:
        fail("pilot approval packet persistence mismatch")
    return path, digest, shlex.join(command), packet


def install_full_approval(arguments, evidence_root, auth_brokers, source_identity):
    parsed = parse_flag_pairs(arguments, {"--generation", "--approved-sha256"})
    generation_path = Path(parsed["--generation"])
    if not generation_path.is_absolute():
        generation_path = root / generation_path
    try:
        generation_path = generation_path.resolve(strict=True)
        generation_path.relative_to(evidence_root.resolve(strict=True))
    except (FileNotFoundError, ValueError):
        fail("full approval generation outside evidence")
    if verify_complete_generation(generation_path) is not None:
        fail("full approval generation incomplete")
    generation_manifest_value = json.loads(
        read_bounded_file(generation_path / "manifest.json", generation_path, 1048576)
    )
    if generation_manifest_value.get("mode") != "live-pilot":
        fail("full approval requires pilot generation")
    generation_results = json.loads(
        read_bounded_file(generation_path / "results.json", generation_path, 1048576)
    )
    generation_ledger = json.loads(
        read_bounded_file(generation_path / "resource-ledger.json", generation_path, 1048576)
    )
    source_path = generation_path / "full-run-approval.json"
    payload = read_bounded_file(source_path, generation_path, 1048576).encode("utf-8")
    digest = hashlib.sha256(payload).hexdigest()
    if digest != parsed["--approved-sha256"]:
        fail("full approval USER digest mismatch")
    packet = json.loads(payload)
    command = shlex.split(packet.get("command", ""))
    if command[:3] != ["bash", "scripts/test-release-loop-conformance.sh", "live"]:
        fail("full approval command mismatch")
    exact_command, models, caps = parse_paid_mode("live", command[3:])
    invariant = validate_paid_approval_packet(
        packet, "live", exact_command, models, caps, auth_brokers, source_identity
    )
    if invariant is not None:
        fail(invariant)
    expected_pilot_evidence = {
        "results_sha256": object_digest(generation_results),
        "settlement_sha256": object_digest(generation_ledger),
    }
    if packet.get("pilot_evidence") != expected_pilot_evidence:
        fail("full approval pilot evidence mismatch")
    pilot_invariant = validate_pilot_results(generation_results)
    if pilot_invariant is not None:
        fail(pilot_invariant)
    pilot_caps = generation_ledger.get("approved_caps")
    if validate_resource_caps(pilot_caps) is not None:
        fail("full approval pilot caps missing")
    try:
        pilot_ledger_for_derivation = {
            "claude_spent": Decimal(generation_ledger["claude_spent"]),
        }
    except (KeyError, ArithmeticError):
        fail("full approval pilot settlement invalid")
    derived_caps = derive_full_run_caps(pilot_caps, generation_results, pilot_ledger_for_derivation)
    derived_command = full_run_command(derived_caps, models)
    if caps != derived_caps or exact_command != derived_command:
        fail("full approval command not pilot-derived")
    target = evidence_root / "live-approval.json"
    write_bytes_atomic(target, payload, evidence_root)
    installed = read_bounded_file(target, evidence_root, 1048576).encode("utf-8")
    if installed != payload or hashlib.sha256(installed).hexdigest() != digest:
        fail("full approval install bytes mismatch")
    return target, digest, packet["command"], packet


def generation_allowed_names(manifest):
    names = {
        "results.json", "resource-ledger.json", "process-proofs.json", "command-audit.json",
        "receipt-consumption.json", "manifest.json", "complete.json",
    }
    if manifest.get("mode") == "live-pilot":
        names.add("full-run-approval.json")
    return names


def verified_generation_tree(generation_root, allowed_extra=frozenset()):
    generation_root = Path(generation_root)
    if generation_root.is_symlink():
        fail("generation root unsafe")
    try:
        generation_root = generation_root.resolve(strict=True)
    except FileNotFoundError:
        fail("generation missing")
    if generation_root.is_symlink() or not generation_root.is_dir():
        fail("generation root unsafe")
    if verify_complete_generation(generation_root) is not None:
        fail("generation incomplete")
    manifest = json.loads(read_bounded_file(generation_root / "manifest.json", generation_root, 1048576))
    actual_names = set()
    rows = []
    for path in generation_root.rglob("*"):
        if path.is_symlink():
            fail("generation symlink rejected")
        if path.is_dir():
            continue
        relative = str(path.relative_to(generation_root))
        if relative.startswith("../") or any(ord(character) < 32 for character in relative):
            fail("generation path rejected")
        actual_names.add(relative)
        if relative in allowed_extra:
            continue
        rows.append(
            {
                "path": relative,
                "size": path.stat().st_size,
                "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
            }
        )
    if actual_names != generation_allowed_names(manifest) | set(allowed_extra):
        fail("generation file inventory mismatch")
    rows.sort(key=lambda row: row["path"])
    manifest_digest = hashlib.sha256((generation_root / "manifest.json").read_bytes()).hexdigest()
    tree_digest = object_digest(rows)
    return {"root": generation_root, "manifest": manifest, "manifest_sha256": manifest_digest, "tree_sha256": tree_digest, "files": rows}


def git_common_directory(repository_root):
    result = subprocess.run(
        ["git", "rev-parse", "--git-common-dir"],
        cwd=str(repository_root),
        check=False,
        capture_output=True,
        text=True,
        timeout=10,
    )
    if result.returncode != 0:
        fail("transition repository identity unavailable")
    common = Path(result.stdout.strip())
    if not common.is_absolute():
        common = repository_root / common
    return common.resolve(strict=True)


def existing_path_has_symlink(base_root, target_path):
    try:
        relative = target_path.relative_to(base_root)
    except ValueError:
        return True
    current = base_root
    for part in relative.parts:
        current = current / part
        if current.exists() or current.is_symlink():
            if current.is_symlink():
                return True
        else:
            break
    return False


def verify_handoff_directory(handoff_root):
    if not handoff_root.is_dir() or handoff_root.is_symlink():
        fail("handoff missing or unsafe")
    owner = json.loads(read_bounded_file(handoff_root / "owner.json", handoff_root, 65536))
    handoff_manifest = json.loads(read_bounded_file(handoff_root / "handoff-manifest.json", handoff_root, 1048576))
    if owner.get("schema") != "release-loop-handoff-owner/v1" or handoff_manifest.get("schema") != "release-loop-handoff/v1":
        fail("handoff metadata invalid")
    extras = {"owner.json", "handoff-manifest.json"}
    if (handoff_root / "consumed.json").is_file():
        extras.add("consumed.json")
    generation = verified_generation_tree(handoff_root, extras)
    if handoff_manifest.get("generation_manifest_sha256") != generation["manifest_sha256"]:
        fail("handoff generation digest mismatch")
    if handoff_manifest.get("generation_tree_sha256") != generation["tree_sha256"]:
        fail("handoff tree digest mismatch")
    if handoff_manifest.get("files") != generation["files"]:
        fail("handoff file manifest mismatch")
    return generation, owner, handoff_manifest


def install_base_generation_from_handoff(handoff_root, target):
    handoff_generation, _, _ = verify_handoff_directory(handoff_root)
    if target.exists():
        existing = verified_generation_tree(target)
        if existing["manifest_sha256"] != handoff_generation["manifest_sha256"]:
            fail("base generation existing target mismatch")
        return existing
    target.parent.mkdir(parents=True, exist_ok=True)
    staging = target.parent / f".{target.name}.partial"
    if staging.exists() and (staging.is_symlink() or not staging.is_dir()):
        fail("base generation staging unsafe")
    staging.mkdir(exist_ok=True)
    owner_path = staging / "owner.json"
    owner = {
        "schema": "release-loop-base-generation-owner/v1",
        "generation_manifest_sha256": handoff_generation["manifest_sha256"],
    }
    if owner_path.exists():
        if json.loads(read_bounded_file(owner_path, staging, 65536)) != owner:
            fail("base generation staging owner mismatch")
    else:
        write_json_atomic(owner_path, owner, staging)
    for row in handoff_generation["files"]:
        if row["path"] == "complete.json":
            continue
        write_bytes_atomic(staging / row["path"], (handoff_root / row["path"]).read_bytes(), staging)
    write_bytes_atomic(staging / "complete.json", (handoff_root / "complete.json").read_bytes(), staging)
    owner_path.unlink()
    os.replace(str(staging), str(target))
    installed = verified_generation_tree(target)
    if installed["manifest_sha256"] != handoff_generation["manifest_sha256"]:
        fail("base generation installation mismatch")
    return installed


def install_handoff(feature_root, base_root, generation_root, handoff_name, fail_at=None):
    feature_argument = Path(feature_root)
    base_argument = Path(base_root)
    if feature_argument.is_symlink() or base_argument.is_symlink():
        fail("handoff root or name invalid")
    feature_root = feature_argument.resolve(strict=True)
    base_root = base_argument.resolve(strict=True)
    if not re.fullmatch(r"[a-z0-9]+(?:-[a-z0-9]+)*", handoff_name):
        fail("handoff root or name invalid")
    if git_common_directory(feature_root) != git_common_directory(base_root):
        fail("handoff foreign repository")
    generation = verified_generation_tree(generation_root)
    try:
        generation["root"].relative_to((feature_root / ".release-loop/evidence").resolve(strict=True))
    except (FileNotFoundError, ValueError):
        fail("handoff generation outside feature evidence")
    if generation["manifest"].get("mode") != "live":
        fail("handoff requires full live generation")
    handoff_parent = base_root / ".release-loop/.handoff"
    handoff_parent.mkdir(parents=True, exist_ok=True)
    target = handoff_parent / handoff_name
    if target.exists():
        existing, owner, _ = verify_handoff_directory(target)
        if owner.get("handoff_name") != handoff_name or existing["manifest_sha256"] != generation["manifest_sha256"]:
            fail("handoff existing target mismatch")
        return target, generation["manifest_sha256"], "existing"
    staging = handoff_parent / f".{handoff_name}.partial"
    if staging.exists() and (staging.is_symlink() or not staging.is_dir()):
        fail("handoff staging unsafe")
    staging.mkdir(exist_ok=True)
    owner_path = staging / "owner.json"
    owner = {
        "schema": "release-loop-handoff-owner/v1",
        "handoff_name": handoff_name,
        "feature_common_dir_sha256": hashlib.sha256(str(git_common_directory(feature_root)).encode()).hexdigest(),
        "base_common_dir_sha256": hashlib.sha256(str(git_common_directory(base_root)).encode()).hexdigest(),
    }
    if owner_path.exists():
        if json.loads(read_bounded_file(owner_path, staging, 65536)) != owner:
            fail("handoff staging owner mismatch")
    else:
        write_json_atomic(owner_path, owner, staging)
    for row in generation["files"]:
        if row["path"] == "complete.json":
            continue
        source_path = generation["root"] / row["path"]
        target_path = staging / row["path"]
        write_bytes_atomic(target_path, source_path.read_bytes(), staging)
    write_json_atomic(
        staging / "handoff-manifest.json",
        {
            "schema": "release-loop-handoff/v1",
            "generation_manifest_sha256": generation["manifest_sha256"],
            "generation_tree_sha256": generation["tree_sha256"],
            "files": generation["files"],
        },
        staging,
    )
    if fail_at == "after-copy-before-complete":
        fail("injected handoff interruption")
    write_bytes_atomic(staging / "complete.json", (generation["root"] / "complete.json").read_bytes(), staging)
    os.replace(str(staging), str(target))
    installed, _, _ = verify_handoff_directory(target)
    if installed["manifest_sha256"] != generation["manifest_sha256"]:
        fail("handoff installation mismatch")
    return target, generation["manifest_sha256"], "installed"


def tracked_tree_clean(repository_root, allowed_paths=()):
    result = subprocess.run(
        ["git", "status", "--porcelain"],
        cwd=str(repository_root),
        check=False,
        capture_output=True,
        text=True,
        timeout=10,
    )
    if result.returncode != 0:
        return False
    allowed = {str(path) for path in allowed_paths}
    for line in result.stdout.splitlines():
        path = line[3:]
        if path not in allowed and not path.startswith(".release-loop/"):
            return False
    return True


def publish_baseline_transition(base_root, handoff_root, archive_source, baseline_path, policy_path, roadmap_path, validator):
    base_argument = Path(base_root)
    if base_argument.is_symlink():
        fail("baseline base root unsafe")
    base_root = base_argument.resolve(strict=True)
    handoff_root = handoff_root.resolve(strict=True)
    archive_argument = Path(archive_source)
    expected_archive_source = base_root / ".release-loop/evidence/live-generation"
    archive_source = archive_argument.resolve(strict=False)
    if archive_source != expected_archive_source:
        fail("baseline archive source path mismatch")
    if archive_argument.is_symlink() or existing_path_has_symlink(base_argument.absolute(), archive_argument.absolute()):
        fail("baseline archive source unsafe")
    baseline_path = baseline_path.resolve(strict=False)
    policy_path = policy_path.resolve(strict=True)
    roadmap_path = roadmap_path.resolve(strict=True)
    for path in (baseline_path, policy_path, roadmap_path):
        try:
            path.resolve(strict=False).relative_to(base_root)
        except ValueError:
            fail("baseline target outside base")
    handoff_generation, _, handoff_manifest = verify_handoff_directory(handoff_root)
    archive_generation = install_base_generation_from_handoff(handoff_root, archive_source)
    if archive_generation["manifest_sha256"] != handoff_generation["manifest_sha256"]:
        fail("baseline archive source mismatch")
    baseline_relative = baseline_path.relative_to(base_root)
    policy_relative = policy_path.relative_to(base_root)
    roadmap_relative = roadmap_path.relative_to(base_root)
    allowed_dirty = [baseline_relative, policy_relative, roadmap_relative]
    if not tracked_tree_clean(base_root, allowed_dirty):
        fail("baseline target tree dirty")

    def head_bytes(relative_path):
        result = subprocess.run(
            ["git", "show", f"HEAD:{relative_path}"],
            cwd=str(base_root),
            check=False,
            capture_output=True,
        )
        return result.stdout if result.returncode == 0 else None

    head_policy_bytes = head_bytes(policy_relative)
    head_roadmap_bytes = head_bytes(roadmap_relative)
    if head_policy_bytes is None or head_roadmap_bytes is None:
        fail("baseline HEAD inputs missing")
    head_policy = json.loads(head_policy_bytes)
    roadmap_row = "| Conformance suite |"
    if head_policy.get("state") == "enforced":
        if not tracked_tree_clean(base_root):
            fail("baseline enforced tree dirty")
        policy = load_json(policy_path)
        baseline = load_json(baseline_path)
        if (
            hashlib.sha256(baseline_path.read_bytes()).hexdigest() != policy.get("baseline_sha256")
            or baseline.get("generation_manifest_sha256") != handoff_generation["manifest_sha256"]
            or roadmap_row in roadmap_path.read_text(encoding="utf-8")
        ):
            fail("baseline enforced state mismatch")
        if validator(base_root) != "ALL CHECKS PASSED":
            fail("baseline final validation failed")
        return baseline["generation_manifest_sha256"], baseline
    head_roadmap_text = head_roadmap_bytes.decode("utf-8")
    if head_policy.get("state") != "bootstrap" or head_roadmap_text.count(roadmap_row) != 1:
        fail("baseline ROADMAP row missing or ambiguous")
    corpus_value = load_json(base_root / "tests/conformance/release-loop/corpus.json")
    baseline = {
        "schema": "release-loop-baseline/v1",
        "generation_manifest_sha256": handoff_generation["manifest_sha256"],
        "generation_tree_sha256": handoff_generation["tree_sha256"],
        "source_generation": corpus_value["source_generation"],
        "corpus_sha256": hashlib.sha256((base_root / "tests/conformance/release-loop/corpus.json").read_bytes()).hexdigest(),
        "mutations_sha256": hashlib.sha256((base_root / "tests/conformance/release-loop/mutations.json").read_bytes()).hexdigest(),
        "handoff_manifest_sha256": hashlib.sha256((handoff_root / "handoff-manifest.json").read_bytes()).hexdigest(),
    }
    baseline_bytes = (json.dumps(baseline, sort_keys=True, indent=2) + "\n").encode("utf-8")
    enforced_policy = {
        "schema": "release-loop-baseline-policy/v1",
        "state": "enforced",
        "baseline": str(baseline_relative),
        "baseline_sha256": hashlib.sha256(baseline_bytes).hexdigest(),
        "source_generation": baseline["source_generation"],
        "generation_manifest_sha256": baseline["generation_manifest_sha256"],
        "roadmap_item": "Conformance suite",
    }
    policy_bytes = (json.dumps(enforced_policy, sort_keys=True, indent=2) + "\n").encode("utf-8")
    new_roadmap_lines = [line for line in head_roadmap_text.splitlines() if not line.startswith(roadmap_row)]
    roadmap_bytes = ("\n".join(new_roadmap_lines) + "\n").encode()
    original_baseline = head_bytes(baseline_relative)
    current_baseline = baseline_path.read_bytes() if baseline_path.is_file() else None
    current_policy = policy_path.read_bytes()
    current_roadmap = roadmap_path.read_bytes()
    states = (
        current_baseline in {original_baseline, baseline_bytes},
        current_policy in {head_policy_bytes, policy_bytes},
        current_roadmap in {head_roadmap_bytes, roadmap_bytes},
    )
    if not all(states):
        fail("baseline owned partial mismatch")
    progress_tuple = (
        current_baseline == baseline_bytes,
        current_policy == policy_bytes,
        current_roadmap == roadmap_bytes,
    )
    if progress_tuple not in {(False, False, False), (True, False, False), (True, True, False), (True, True, True)}:
        fail("baseline partial order mismatch")
    write_bytes_atomic(baseline_path, baseline_bytes, base_root, 0o644)
    write_bytes_atomic(policy_path, policy_bytes, base_root, 0o644)
    write_bytes_atomic(roadmap_path, roadmap_bytes, base_root, 0o644)
    validation_result = validator(base_root)
    if validation_result != "ALL CHECKS PASSED":
        fail("baseline final validation failed")
    return baseline["generation_manifest_sha256"], baseline


def progress_frontmatter_region(text_value):
    lines = text_value.splitlines(keepends=True)
    normalized = [line.rstrip("\r\n") for line in lines]
    fence_indices = [index for index, line in enumerate(normalized) if line == "---"]
    if not lines or normalized[0] != "---" or len(fence_indices) < 2 or fence_indices[0] != 0:
        fail("archive progress frontmatter missing")
    start = len(lines[0])
    end = sum(len(line) for line in lines[:fence_indices[1]])
    return text_value[start:end], start, end


def progress_frontmatter_scalar(text_value, key):
    frontmatter, _, _ = progress_frontmatter_region(text_value)
    matches = re.findall(rf"(?m)^{re.escape(key)}: ([^\n]+)$", frontmatter)
    if len(matches) != 1:
        fail(f"archive progress duplicate or missing field: {key}")
    return matches[0]


def mark_v2_acceptance(progress_path, generation_digest, archive_root, observed_at):
    text_value = progress_path.read_text(encoding="utf-8")
    expected_destination = f"archive-destination: {archive_root}"
    if text_value.count(expected_destination) != 1:
        fail("archive destination evidence mismatch")
    phase = progress_frontmatter_scalar(text_value, "phase")
    phase_status = progress_frontmatter_scalar(text_value, "phase_status")
    if phase not in {"retro", "done"}:
        fail("archive V2 phase mismatch")
    record_pattern = re.compile(
        r"(?m)^archive_verification:\n"
        r"  id: (?P<id>[^\n]+)\n"
        r"  status: (?P<status>[^\n]+)\n"
        r"  generation_sha256: (?P<digest>[^\n]+)\n"
        r"  archive_root: (?P<root>[^\n]+)\n"
        r"  updated: (?P<updated>[^\n]+)$"
    )
    frontmatter, frontmatter_start, _ = progress_frontmatter_region(text_value)
    records = list(record_pattern.finditer(frontmatter))
    if len(records) != 1:
        fail("archive V2 record missing or duplicate")
    record = records[0]
    if (
        record.group("id") != "V2"
        or record.group("digest") != generation_digest
        or record.group("root") != archive_root
        or parse_gate_timestamp(record.group("updated")) is None
    ):
        fail("archive V2 record mismatch")
    if record.group("status") == "accepted":
        if f"V2 accepted generation={generation_digest}" not in text_value:
            fail("archive V2 accepted digest mismatch")
        return
    if record.group("status") != "started" or phase != "retro" or phase_status != "in-progress":
        fail("archive V2 nonterminal state mismatch")
    replacement = record.group(0).replace("  status: started\n", "  status: accepted\n", 1)
    record_start = frontmatter_start + record.start()
    record_end = frontmatter_start + record.end()
    text_value = text_value[:record_start] + replacement + text_value[record_end:]
    text_value = text_value.rstrip() + (
        f"\n- {observed_at} archive: V2 accepted generation={generation_digest} archive_root={archive_root}\n"
    )
    write_bytes_atomic(progress_path, text_value.encode("utf-8"), progress_path.parent)


def require_terminal_archived_progress(archive_root, digest, relative_archive):
    archived_progress = archive_root / "progress.md"
    mark_v2_acceptance(archived_progress, digest, relative_archive, "")
    text_value = archived_progress.read_text(encoding="utf-8")
    if (
        progress_frontmatter_scalar(text_value, "phase") != "done"
        or progress_frontmatter_scalar(text_value, "phase_status") != "complete"
        or f"V2 accepted generation={digest}" not in text_value
    ):
        fail("handoff cleanup terminal progress missing")
    return archived_progress


def remove_consumed_handoff_after_terminal(base_root, archive_root, handoff_root, digest, fail_at=None):
    expected_parent = (base_root / ".release-loop/.handoff").resolve(strict=True)
    try:
        handoff_root.resolve(strict=True).relative_to(expected_parent)
    except (FileNotFoundError, ValueError):
        fail("handoff cleanup target mismatch")
    consumed = load_json(handoff_root / "consumed.json")
    if (
        consumed.get("generation_manifest_sha256") != digest
        or consumed.get("archive_root") != str(archive_root.relative_to(base_root))
    ):
        fail("handoff cleanup consumed marker mismatch")
    relative_archive = str(archive_root.relative_to(base_root))
    require_terminal_archived_progress(archive_root, digest, relative_archive)
    tombstone_name = f".{handoff_root.name}.cleanup-{digest[:12]}"
    tombstone = expected_parent / tombstone_name
    cleanup_receipt_path = archive_root / "evidence/handoff-cleanup.json"
    cleanup_receipt = {
        "schema": "release-loop-handoff-cleanup/v1",
        "handoff_name": handoff_root.name,
        "generation_manifest_sha256": digest,
        "archive_root": relative_archive,
        "tombstone_name": tombstone_name,
    }
    if cleanup_receipt_path.is_file():
        if load_json(cleanup_receipt_path) != cleanup_receipt:
            fail("handoff cleanup receipt mismatch")
    else:
        write_json_atomic(cleanup_receipt_path, cleanup_receipt, archive_root)
    if tombstone.exists() and handoff_root.exists():
        fail("handoff cleanup target ambiguous")
    if handoff_root.exists():
        os.replace(str(handoff_root), str(tombstone))
        directory_descriptor = os.open(str(expected_parent), os.O_RDONLY)
        try:
            os.fsync(directory_descriptor)
        finally:
            os.close(directory_descriptor)
    if fail_at == "after-rename":
        fail("injected handoff cleanup interruption")
    if tombstone.exists():
        if tombstone.is_symlink() or tombstone.parent.resolve(strict=True) != expected_parent:
            fail("handoff cleanup tombstone unsafe")
        shutil.rmtree(tombstone)
    directory_descriptor = os.open(str(expected_parent), os.O_RDONLY)
    try:
        os.fsync(directory_descriptor)
    finally:
        os.close(directory_descriptor)


def finish_absent_handoff_cleanup(base_root, archive_root, handoff_argument, digest):
    relative_archive = str(archive_root.relative_to(base_root))
    require_terminal_archived_progress(archive_root, digest, relative_archive)
    cleanup_receipt_path = archive_root / "evidence/handoff-cleanup.json"
    if not cleanup_receipt_path.is_file():
        fail("handoff cleanup receipt missing")
    receipt = load_json(cleanup_receipt_path)
    expected_tombstone = f".{handoff_argument.name}.cleanup-{digest[:12]}"
    if receipt != {
        "schema": "release-loop-handoff-cleanup/v1",
        "handoff_name": handoff_argument.name,
        "generation_manifest_sha256": digest,
        "archive_root": relative_archive,
        "tombstone_name": expected_tombstone,
    }:
        fail("handoff cleanup receipt mismatch")
    handoff_parent = (base_root / ".release-loop/.handoff").resolve(strict=True)
    tombstone = handoff_parent / expected_tombstone
    if tombstone.exists():
        if tombstone.is_symlink() or tombstone.parent.resolve(strict=True) != handoff_parent:
            fail("handoff cleanup tombstone unsafe")
        shutil.rmtree(tombstone)
        directory_descriptor = os.open(str(handoff_parent), os.O_RDONLY)
        try:
            os.fsync(directory_descriptor)
        finally:
            os.close(directory_descriptor)


def verify_archive_transition(base_root, archive_root, baseline_path, handoff_root, observed_at):
    base_root = base_root.resolve(strict=True)
    archive_root = archive_root.resolve(strict=True)
    try:
        archive_root.relative_to((base_root / ".release-loop/archive").resolve(strict=True))
    except ValueError:
        fail("archive root outside archive tree")
    handoff_argument = Path(handoff_root)
    expected_handoff_parent = (base_root / ".release-loop/.handoff").resolve(strict=True)
    if handoff_argument.is_symlink() or existing_path_has_symlink(
        base_root, handoff_argument.absolute()
    ):
        fail("archive handoff path mismatch")
    try:
        handoff_parent = handoff_argument.parent.resolve(strict=True)
    except FileNotFoundError:
        fail("archive handoff path mismatch")
    if handoff_parent != expected_handoff_parent or handoff_argument.parent != base_root / ".release-loop/.handoff":
        fail("archive handoff path mismatch")
    baseline = load_json(baseline_path)
    staged_generation = verified_generation_tree(archive_root / "evidence/live-generation")
    digest = staged_generation["manifest_sha256"]
    if baseline.get("generation_manifest_sha256") != digest:
        fail("archive generation digest mismatch")
    live_progress_path = base_root / ".release-loop/progress.md"
    progress_path = live_progress_path if live_progress_path.is_file() else archive_root / "progress.md"
    if not progress_path.is_file():
        fail("archive progress evidence missing")
    relative_archive = str(archive_root.relative_to(base_root))
    if not handoff_argument.exists():
        if live_progress_path.is_file():
            fail("archive handoff missing before terminal move")
        finish_absent_handoff_cleanup(base_root, archive_root, handoff_argument, digest)
        return digest
    handoff_root = handoff_argument.resolve(strict=True)
    handoff_generation, _, _ = verify_handoff_directory(handoff_root)
    if handoff_generation["manifest_sha256"] != digest:
        fail("archive generation digest mismatch")
    consumed_path = handoff_root / "consumed.json"
    if consumed_path.is_file():
        consumed = load_json(consumed_path)
        if consumed.get("generation_manifest_sha256") != digest or consumed.get("archive_root") != relative_archive:
            fail("archive consumed marker mismatch")
        mark_v2_acceptance(progress_path, digest, relative_archive, observed_at)
        if not live_progress_path.is_file():
            remove_consumed_handoff_after_terminal(base_root, archive_root, handoff_root, digest)
        return digest
    mark_v2_acceptance(progress_path, digest, relative_archive, observed_at)
    consumed = {
        "schema": "release-loop-handoff-consumed/v1",
        "generation_manifest_sha256": digest,
        "archive_root": relative_archive,
        "consumed_at": observed_at,
    }
    write_json_atomic(consumed_path, consumed, handoff_root)
    return digest


def repository_validator(repository_root):
    result = run_bounded(
        ["bash", "scripts/validate.sh"],
        repository_root,
        {"PATH": os.environ.get("PATH", "/usr/bin:/bin"), "HOME": os.environ.get("HOME", ""), "LC_ALL": "C"},
        output_cap=1048576,
        timeout=30,
    )
    if result.returncode == 0 and "ALL CHECKS PASSED" in result.stdout:
        return "ALL CHECKS PASSED"
    return "VALIDATION FAILED"


def run_handoff_mode(arguments):
    parsed = parse_flag_pairs(arguments, {"--feature-root", "--base-root", "--generation", "--handoff-name"})
    feature_root = Path(parsed["--feature-root"])
    base_root = Path(parsed["--base-root"])
    if not feature_root.is_absolute():
        feature_root = root / feature_root
    if not base_root.is_absolute():
        base_root = root / base_root
    generation = Path(parsed["--generation"])
    if not generation.is_absolute():
        generation = feature_root / generation
    return install_handoff(feature_root, base_root, generation, parsed["--handoff-name"])


def run_publish_baseline_mode(arguments):
    parsed = parse_flag_pairs(
        arguments, {"--handoff", "--archive-source", "--baseline", "--policy", "--roadmap"}
    )
    def rooted(value):
        path = Path(value)
        return path if path.is_absolute() else root / path
    return publish_baseline_transition(
        root,
        rooted(parsed["--handoff"]),
        rooted(parsed["--archive-source"]),
        rooted(parsed["--baseline"]),
        rooted(parsed["--policy"]),
        rooted(parsed["--roadmap"]),
        repository_validator,
    )


def run_verify_archive_mode(arguments):
    parsed = parse_flag_pairs(arguments, {"--archive-root", "--baseline", "--handoff"})
    def rooted(value):
        path = Path(value)
        return path if path.is_absolute() else root / path
    observed_at = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    return verify_archive_transition(
        root,
        rooted(parsed["--archive-root"]),
        rooted(parsed["--baseline"]),
        rooted(parsed["--handoff"]),
        observed_at,
    )


def validate_transition_group():
    with tempfile.TemporaryDirectory(prefix="release-loop transition ;[] ") as temp_value:
        temp_root = Path(temp_value)
        base_root = temp_root / "base"
        feature_root = temp_root / "feature"
        base_root.mkdir()
        git_env = {
            "PATH": os.environ.get("PATH", "/usr/bin:/bin"),
            "HOME": str(temp_root / "home"),
            "LC_ALL": "C",
            "GIT_CONFIG_NOSYSTEM": "1",
        }
        (temp_root / "home").mkdir()

        def git(cwd, *args):
            result = run_bounded(["git", *args], cwd, git_env, output_cap=65536, timeout=20)
            if result.returncode != 0:
                fail(f"transition fixture Git failed: {args}: {result.stderr.strip()}")
            return result.stdout.strip()

        git(base_root, "init")
        for key, value in (
            ("user.name", "Transition Fixture"), ("user.email", "fixture@example.invalid"),
            ("commit.gpgsign", "false"), ("core.autocrlf", "false"), ("core.safecrlf", "false"),
        ):
            git(base_root, "config", key, value)
        data_dir = base_root / "tests/conformance/release-loop"
        data_dir.mkdir(parents=True)
        for name in ("corpus.json", "mutations.json", "baseline-policy.json"):
            shutil.copyfile(data_root / name, data_dir / name)
        shutil.copyfile(root / "ROADMAP.md", base_root / "ROADMAP.md")
        (base_root / "unrelated.txt").write_text("clean\n", encoding="utf-8")
        (base_root / ".gitignore").write_text(".release-loop/\n", encoding="utf-8")
        git(base_root, "add", ".")
        git(base_root, "commit", "-m", "fixture base")
        git(base_root, "worktree", "add", "-b", "feat-transition", str(feature_root))

        caps = {
            "max_turns_per_session": 2, "per_turn_timeout": 1, "session_timeout": 2,
            "max_infrastructure_retries": 0, "max_concurrency": 1,
            "codex_observed_token_cap": 5000, "total_wall_time": 60,
            "claude_total_budget_usd": "2.00", "claude_max_invocation_usd": "0.25",
        }
        models = {"claude": "fixture-claude", "codex": "fixture-codex"}
        results, ledger, proofs, audit = execute_paid_schedule("live", caps, models, fake_paid_launcher)
        generation_root = feature_root / ".release-loop/evidence/live-generation"
        receipt = {"caps": caps, "nonce": "a" * 32}
        finalize_generation_directory(
            generation_root,
            "live",
            models,
            full_run_command(caps, models),
            receipt,
            {"nonce": receipt["nonce"], "consumed_at": "2026-08-24T07:00:00Z"},
            results,
            ledger,
            proofs,
            audit,
        )
        generation = verified_generation_tree(generation_root)
        controls = 0
        negatives = 0
        try:
            install_handoff(
                feature_root,
                base_root,
                generation_root,
                "fuzz-testing",
                fail_at="after-copy-before-complete",
            )
        except ValueError as exc:
            if "injected handoff interruption" not in str(exc):
                fail(f"transition handoff interruption diagnostic mismatch: {exc}")
        else:
            fail("transition handoff interruption accepted")
        negatives += 1
        handoff_root, handoff_digest, disposition = install_handoff(
            feature_root, base_root, generation_root, "fuzz-testing"
        )
        if disposition != "installed" or handoff_digest != generation["manifest_sha256"]:
            fail("transition handoff control failed")
        controls += 1
        _, repeated_digest, repeated_disposition = install_handoff(
            feature_root, base_root, generation_root, "fuzz-testing"
        )
        if repeated_disposition != "existing" or repeated_digest != handoff_digest:
            fail("transition handoff idempotence failed")
        controls += 1
        feature_link = temp_root / "feature-link"
        base_link = temp_root / "base-link"
        feature_link.symlink_to(feature_root, target_is_directory=True)
        base_link.symlink_to(base_root, target_is_directory=True)
        for linked_feature, linked_base, name in (
            (feature_link, base_root, "feature-link"),
            (feature_root, base_link, "base-link"),
        ):
            try:
                install_handoff(linked_feature, linked_base, generation_root, name)
            except ValueError as exc:
                if "handoff root or name invalid" not in str(exc):
                    fail(f"transition root symlink diagnostic mismatch: {exc}")
            else:
                fail("transition worktree root symlink accepted")
            negatives += 1
        archive_source = base_root / ".release-loop/evidence/live-generation"
        baseline_path = data_dir / "baseline.json"
        policy_path = data_dir / "baseline-policy.json"
        roadmap_path = base_root / "ROADMAP.md"
        outside_archive_source = temp_root / "outside-live-generation"
        try:
            publish_baseline_transition(
                base_root,
                handoff_root,
                outside_archive_source,
                baseline_path,
                policy_path,
                roadmap_path,
                lambda _root: "ALL CHECKS PASSED",
            )
        except ValueError as exc:
            if "baseline archive source path mismatch" not in str(exc):
                fail(f"transition archive-source path diagnostic mismatch: {exc}")
        else:
            fail("transition outside archive source accepted")
        if outside_archive_source.exists():
            fail("transition outside archive source mutated")
        negatives += 1
        published_digest, baseline = publish_baseline_transition(
            base_root,
            handoff_root,
            archive_source,
            baseline_path,
            policy_path,
            roadmap_path,
            lambda _root: "ALL CHECKS PASSED",
        )
        if published_digest != handoff_digest or baseline["generation_manifest_sha256"] != handoff_digest:
            fail("transition baseline publication failed")
        controls += 1
        repeated_publish, _ = publish_baseline_transition(
            base_root,
            handoff_root,
            archive_source,
            baseline_path,
            policy_path,
            roadmap_path,
            lambda _root: "ALL CHECKS PASSED",
        )
        if repeated_publish != handoff_digest:
            fail("transition baseline idempotence failed")
        controls += 1
        unrelated_path = base_root / "unrelated.txt"
        unrelated_path.write_text("dirty\n", encoding="utf-8")
        try:
            publish_baseline_transition(
                base_root, handoff_root, archive_source, baseline_path, policy_path, roadmap_path,
                lambda _root: "ALL CHECKS PASSED",
            )
        except ValueError as exc:
            if "baseline target tree dirty" not in str(exc):
                fail(f"transition dirty target diagnostic mismatch: {exc}")
        else:
            fail("transition dirty baseline target accepted")
        unrelated_path.write_text("clean\n", encoding="utf-8")
        negatives += 1
        try:
            publish_baseline_transition(
                base_root, handoff_root, archive_source, baseline_path, policy_path, roadmap_path,
                lambda _root: "VALIDATION FAILED",
            )
        except ValueError as exc:
            if "baseline final validation failed" not in str(exc):
                fail(f"transition validation failure diagnostic mismatch: {exc}")
        else:
            fail("transition failed validation accepted")
        negatives += 1
        archive_root = base_root / ".release-loop/archive/2026-08-24-fuzz-testing"
        staged_generation = archive_root / "evidence/live-generation"
        staged_generation.parent.mkdir(parents=True)
        shutil.copytree(archive_source, staged_generation)
        progress_path = base_root / ".release-loop/progress.md"
        valid_progress_text = (
            "---\nphase: retro\nphase_status: in-progress\n"
            "archive_verification:\n  id: V2\n  status: started\n"
            f"  generation_sha256: {handoff_digest}\n  archive_root: {archive_root.relative_to(base_root)}\n"
            "  updated: 2026-08-24T07:00:00Z\n---\n\n## Log\n"
            f"- 2026-08-24T07:00:00Z retro: archive-destination: {archive_root.relative_to(base_root)}\n"
        )
        progress_path.write_text(valid_progress_text, encoding="utf-8")
        v2_block_match = re.search(
            r"(?m)^archive_verification:\n(?:  [^\n]+\n){4}  updated: [^\n]+$",
            valid_progress_text,
        )
        if not v2_block_match:
            fail("transition V2 block fixture missing")
        v2_block = v2_block_match.group(0)
        body_progress = archive_root / "body-v2-progress.md"
        body_only_v2 = valid_progress_text.replace(v2_block, "", 1).rstrip() + "\n\n" + v2_block + "\n"
        body_progress.write_text(body_only_v2, encoding="utf-8")
        try:
            mark_v2_acceptance(
                body_progress, handoff_digest, str(archive_root.relative_to(base_root)), "2026-08-24T07:00:01Z"
            )
        except ValueError as exc:
            if "archive V2 record missing or duplicate" not in str(exc):
                fail(f"transition body-only V2 diagnostic mismatch: {exc}")
        else:
            fail("transition body-only V2 accepted")
        negatives += 1
        duplicate_body_v2 = valid_progress_text.rstrip() + "\n\n" + v2_block + "\n"
        body_progress.write_text(duplicate_body_v2, encoding="utf-8")
        mark_v2_acceptance(
            body_progress, handoff_digest, str(archive_root.relative_to(base_root)), "2026-08-24T07:00:01Z"
        )
        if body_progress.read_text(encoding="utf-8").count("  status: accepted") != 1:
            fail("transition body duplicate changed authoritative count")
        controls += 1
        wrong_baseline_path = data_dir / "wrong-baseline.json"
        wrong_baseline = copy.deepcopy(baseline)
        wrong_baseline["generation_manifest_sha256"] = "0" * 64
        write_json_atomic(wrong_baseline_path, wrong_baseline, base_root, 0o644)
        try:
            verify_archive_transition(
                base_root, archive_root, wrong_baseline_path, handoff_root, "2026-08-24T07:00:01Z"
            )
        except ValueError as exc:
            if "archive generation digest mismatch" not in str(exc):
                fail(f"transition archive mismatch diagnostic mismatch: {exc}")
        else:
            fail("transition archive digest mismatch accepted")
        negatives += 1
        progress_path.write_text(
            valid_progress_text.replace("phase_status: in-progress", "phase_status: waiting-user"),
            encoding="utf-8",
        )
        try:
            verify_archive_transition(
                base_root, archive_root, baseline_path, handoff_root, "2026-08-24T07:00:01Z"
            )
        except ValueError as exc:
            if "archive V2 nonterminal state mismatch" not in str(exc):
                fail(f"transition waiting-user V2 diagnostic mismatch: {exc}")
        else:
            fail("transition waiting-user V2 accepted")
        progress_path.write_text(valid_progress_text, encoding="utf-8")
        negatives += 1
        progress_path.write_text(valid_progress_text.replace("  id: V2", "  id: V1"), encoding="utf-8")
        try:
            verify_archive_transition(
                base_root, archive_root, baseline_path, handoff_root, "2026-08-24T07:00:01Z"
            )
        except ValueError as exc:
            if "archive V2 record mismatch" not in str(exc):
                fail(f"transition V2 record diagnostic mismatch: {exc}")
        else:
            fail("transition mismatched V2 record accepted")
        progress_path.write_text(valid_progress_text, encoding="utf-8")
        negatives += 1
        verified_digest = verify_archive_transition(
            base_root,
            archive_root,
            baseline_path,
            handoff_root,
            "2026-08-24T07:00:01Z",
        )
        if verified_digest != handoff_digest:
            fail("transition archive verification failed")
        controls += 1
        if verify_archive_transition(
            base_root, archive_root, baseline_path, handoff_root, "2026-08-24T07:00:02Z"
        ) != handoff_digest:
            fail("transition archive idempotence failed")
        controls += 1
        archived_progress = archive_root / "progress.md"
        archived_text = progress_path.read_text(encoding="utf-8").replace(
            "phase: retro\nphase_status: in-progress", "phase: done\nphase_status: complete"
        )
        archived_progress.write_text(archived_text, encoding="utf-8")
        progress_path.unlink()
        try:
            remove_consumed_handoff_after_terminal(
                base_root, archive_root, handoff_root, handoff_digest, fail_at="after-rename"
            )
        except ValueError as exc:
            if "injected handoff cleanup interruption" not in str(exc):
                fail(f"transition cleanup interruption diagnostic mismatch: {exc}")
        else:
            fail("transition cleanup interruption accepted")
        if handoff_root.exists():
            fail("transition cleanup tombstone rename failed")
        negatives += 1
        if verify_archive_transition(
            base_root, archive_root, baseline_path, handoff_root, "2026-08-24T07:00:03Z"
        ) != handoff_digest:
            fail("transition moved progress resume failed")
        if handoff_root.exists():
            fail("transition consumed handoff cleanup failed")
        terminal_progress_text = archived_progress.read_text(encoding="utf-8")
        archived_progress.write_text(
            terminal_progress_text.replace(
                "phase: done\nphase_status: complete", "phase: retro\nphase_status: in-progress"
            ),
            encoding="utf-8",
        )
        try:
            verify_archive_transition(
                base_root, archive_root, baseline_path, handoff_root, "2026-08-24T07:00:04Z"
            )
        except ValueError as exc:
            if "handoff cleanup terminal progress missing" not in str(exc):
                fail(f"transition absent handoff terminal diagnostic mismatch: {exc}")
        else:
            fail("transition absent handoff nonterminal progress accepted")
        archived_progress.write_text(terminal_progress_text, encoding="utf-8")
        negatives += 1
        handoff_root.symlink_to(archive_source, target_is_directory=True)
        try:
            verify_archive_transition(
                base_root, archive_root, baseline_path, handoff_root, "2026-08-24T07:00:04Z"
            )
        except ValueError as exc:
            if "archive handoff path mismatch" not in str(exc):
                fail(f"transition V2 handoff symlink diagnostic mismatch: {exc}")
        else:
            fail("transition V2 handoff symlink accepted")
        handoff_root.unlink()
        negatives += 1
        duplicate_terminal = terminal_progress_text.replace(
            "phase_status: complete", "phase_status: complete\nphase: retro"
        )
        archived_progress.write_text(duplicate_terminal, encoding="utf-8")
        try:
            verify_archive_transition(
                base_root, archive_root, baseline_path, handoff_root, "2026-08-24T07:00:04Z"
            )
        except ValueError as exc:
            if "archive progress duplicate or missing field: phase" not in str(exc):
                fail(f"transition duplicate terminal diagnostic mismatch: {exc}")
        else:
            fail("transition duplicate terminal phase accepted")
        archived_progress.write_text(terminal_progress_text, encoding="utf-8")
        negatives += 1
        for malformed_fence in ("---evil", "----"):
            malformed_progress = terminal_progress_text.replace("\n---\n\n## Log", f"\n{malformed_fence}\n\n## Log", 1)
            archived_progress.write_text(malformed_progress, encoding="utf-8")
            try:
                verify_archive_transition(
                    base_root, archive_root, baseline_path, handoff_root, "2026-08-24T07:00:04Z"
                )
            except ValueError as exc:
                if "archive progress frontmatter missing" not in str(exc):
                    fail(f"transition malformed fence diagnostic mismatch: {exc}")
            else:
                fail("transition malformed frontmatter fence accepted")
            negatives += 1
        archived_progress.write_text(terminal_progress_text, encoding="utf-8")
        body_rule_text = terminal_progress_text.rstrip() + "\n\n---\n\nbody separator\n"
        archived_progress.write_text(body_rule_text, encoding="utf-8")
        if verify_archive_transition(
            base_root, archive_root, baseline_path, handoff_root, "2026-08-24T07:00:04Z"
        ) != handoff_digest:
            fail("transition LF body fence rejected")
        controls += 1
        archived_progress.write_bytes(body_rule_text.replace("\n", "\r\n").encode("utf-8"))
        if verify_archive_transition(
            base_root, archive_root, baseline_path, handoff_root, "2026-08-24T07:00:04Z"
        ) != handoff_digest:
            fail("transition CRLF body fence rejected")
        controls += 1
        archived_progress.write_text(terminal_progress_text, encoding="utf-8")
        if verify_archive_transition(
            base_root, archive_root, baseline_path, handoff_root, "2026-08-24T07:00:04Z"
        ) != handoff_digest:
            fail("transition post-cleanup resume failed")
        controls += 1

        extra_generation = temp_root / "extra-generation"
        shutil.copytree(generation_root, extra_generation)
        (extra_generation / "unexpected.txt").write_text("unexpected\n", encoding="utf-8")
        try:
            verified_generation_tree(extra_generation)
        except ValueError as exc:
            if "inventory mismatch" not in str(exc):
                fail(f"transition extra-file diagnostic mismatch: {exc}")
        else:
            fail("transition extra generation file accepted")
        negatives += 1
        symlink_generation = temp_root / "symlink-generation"
        shutil.copytree(generation_root, symlink_generation)
        (symlink_generation / "alias").symlink_to(symlink_generation / "manifest.json")
        try:
            verified_generation_tree(symlink_generation)
        except ValueError as exc:
            if "symlink rejected" not in str(exc):
                fail(f"transition symlink diagnostic mismatch: {exc}")
        else:
            fail("transition generation symlink accepted")
        negatives += 1
        root_symlink = temp_root / "generation-root-link"
        root_symlink.symlink_to(generation_root, target_is_directory=True)
        try:
            verified_generation_tree(root_symlink)
        except ValueError as exc:
            if "generation root unsafe" not in str(exc):
                fail(f"transition root symlink diagnostic mismatch: {exc}")
        else:
            fail("transition generation root symlink accepted")
        negatives += 1
        external_generation = temp_root / "external-generation"
        shutil.copytree(generation_root, external_generation)
        try:
            install_handoff(feature_root, base_root, external_generation, "external-generation")
        except ValueError as exc:
            if "outside feature evidence" not in str(exc):
                fail(f"transition generation containment diagnostic mismatch: {exc}")
        else:
            fail("transition external generation accepted")
        negatives += 1
        foreign_root = temp_root / "foreign"
        foreign_root.mkdir()
        git(foreign_root, "init")
        try:
            install_handoff(feature_root, foreign_root, generation_root, "foreign")
        except ValueError as exc:
            if "foreign repository" not in str(exc):
                fail(f"transition foreign repository diagnostic mismatch: {exc}")
        else:
            fail("transition foreign repository accepted")
        negatives += 1
        if generation["manifest_sha256"] == hashlib.sha256(
            ((generation_root / "manifest.json").read_bytes() + b"changed")
        ).hexdigest():
            fail("transition changed manifest comparison failed")
        controls += 1
        return controls, negatives, handoff_digest


def write_adapter_supervisor(path):
    source = f'''#!{sys.executable}
import base64
import json
import os
from pathlib import Path
import selectors
import signal
import stat
import subprocess
import sys
import time
import traceback

spec = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
summary_path = Path(sys.argv[2])
error_path = Path(spec["error_path"])

def report_exception(exception_type, exception, exception_traceback):
    error_path.write_text(
        "".join(traceback.format_exception(exception_type, exception, exception_traceback)),
        encoding="utf-8",
    )

sys.excepthook = report_exception
stdin_bytes = base64.b64decode(spec["stdin_base64"])
launcher_source = (
    "import json,os,signal,sys,tempfile\\n"
    "from pathlib import Path\\n"
    "record_path=Path(sys.argv[1]);nonce=sys.argv[2];watch_fd=int(sys.argv[3]);target=sys.argv[4:]\\n"
    "payload=(json.dumps(dict(nonce=nonce,pid=os.getpid(),pgid=os.getpgrp(),sid=os.getsid(0)),"
    "sort_keys=True)+'\\\\n').encode()\\n"
    "descriptor,temporary=tempfile.mkstemp(prefix='.adapter-group-',dir=str(record_path.parent))\\n"
    "try:\\n"
    " os.fchmod(descriptor,0o400)\\n"
    " written=0\\n"
    " while written<len(payload): written+=os.write(descriptor,payload[written:])\\n"
    " os.fsync(descriptor);os.close(descriptor);descriptor=None\\n"
    " os.replace(temporary,record_path)\\n"
    " directory=os.open(str(record_path.parent),os.O_RDONLY)\\n"
    " try: os.fsync(directory)\\n"
    " finally: os.close(directory)\\n"
    "finally:\\n"
    " if descriptor is not None: os.close(descriptor)\\n"
    " if os.path.exists(temporary): os.unlink(temporary)\\n"
    "watcher=os.fork()\\n"
    "if watcher==0:\\n"
    " for descriptor in (0,1,2):\\n"
    "  try: os.close(descriptor)\\n"
    "  except OSError: pass\\n"
    " while os.read(watch_fd,1): pass\\n"
    " os.killpg(os.getpgrp(),signal.SIGKILL)\\n"
    " os._exit(125)\\n"
    "os.close(watch_fd)\\n"
    "if os.read(0,1)!=b'R': raise SystemExit(125)\\n"
    "os.execvpe(target[0],target,os.environ)\\n"
)
watch_read, watch_write = os.pipe()
process = subprocess.Popen(
    [sys.executable, "-c", launcher_source, spec["process_group_path"],
     spec["process_group_nonce"], str(watch_read), *spec["argv"]],
    cwd=spec["cwd"], env=spec["env"],
    stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
    start_new_session=True,
    pass_fds=(watch_read,),
)
os.close(watch_read)
record_path = Path(spec["process_group_path"])
record_deadline = time.monotonic() + spec["handshake_timeout"]
while not record_path.is_file() and process.poll() is None and time.monotonic() < record_deadline:
    time.sleep(0.01)
try:
    record = json.loads(record_path.read_text(encoding="utf-8"))
    metadata = record_path.stat()
    if (
        set(record) != {{"nonce", "pid", "pgid", "sid"}}
        or record["nonce"] != spec["process_group_nonce"]
        or record["pid"] != process.pid
        or record["pgid"] != process.pid
        or record["sid"] != process.pid
        or stat.S_IMODE(metadata.st_mode) != 0o400
        or metadata.st_uid != os.getuid()
        or os.getpgid(process.pid) != process.pid
        or os.getsid(process.pid) != process.pid
    ):
        raise ValueError("adapter process group handshake mismatch")
except Exception:
    try:
        os.killpg(process.pid, signal.SIGKILL)
    except ProcessLookupError:
        pass
    process.wait()
    raise
process.stdin.write(b"R" + stdin_bytes)
process.stdin.close()
selector = selectors.DefaultSelector()
selector.register(process.stdout, selectors.EVENT_READ, "stdout")
selector.register(process.stderr, selectors.EVENT_READ, "stderr")
buffers = {{"stdout": bytearray(), "stderr": bytearray()}}
started = time.monotonic()
overflow = False
timed_out = False
term_sent = False
kill_sent = False

def process_group_exists():
    try:
        os.killpg(process.pid, 0)
    except ProcessLookupError:
        return False
    except PermissionError:
        return True
    return True

def signal_process_group(signal_value):
    try:
        os.killpg(process.pid, signal_value)
    except (ProcessLookupError, PermissionError):
        return False
    return True

def terminate_process_group(graceful):
    global term_sent, kill_sent
    if graceful and signal_process_group(signal.SIGTERM):
        term_sent = True
        deadline = time.monotonic() + spec["term_grace"]
        while time.monotonic() < deadline:
            process.poll()
            time.sleep(0.01)
    if signal_process_group(signal.SIGKILL):
        kill_sent = True

while selector.get_map():
    if not timed_out and time.monotonic() - started > spec["timeout"]:
        terminate_process_group(True)
        timed_out = True
    for key, _ in selector.select(0.1):
        chunk = os.read(key.fileobj.fileno(), 8192)
        if not chunk:
            selector.unregister(key.fileobj)
            continue
        retained = len(buffers["stdout"]) + len(buffers["stderr"])
        remaining = max(0, spec["output_cap"] - retained)
        buffers[key.data].extend(chunk[:remaining])
        if not overflow and len(chunk) > remaining:
            terminate_process_group(False)
            overflow = True
    if (overflow or timed_out) and process.poll() is not None:
        continue
returncode = process.wait()
os.close(watch_write)
absence_deadline = time.monotonic() + spec["group_absence_timeout"]
while process_group_exists() and time.monotonic() < absence_deadline:
    time.sleep(0.01)
summary = {{
    "returncode": returncode,
    "stdout_base64": base64.b64encode(bytes(buffers["stdout"])).decode(),
    "stderr_base64": base64.b64encode(bytes(buffers["stderr"])).decode(),
    "overflow": overflow,
    "timed_out": timed_out,
    "term_sent": term_sent,
    "kill_sent": kill_sent,
    "process_group_absent": not process_group_exists(),
}}
summary_path.write_text(json.dumps(summary, sort_keys=True) + "\\n", encoding="utf-8")
'''
    path.write_text(source, encoding="utf-8")
    path.chmod(0o755)


def managed_adapter_call(command, cwd, env, stdin_bytes, timeout_seconds, work_root, table_reader=process_table):
    import base64
    supervisor = work_root / "adapter-supervisor.py"
    spec_path = work_root / f"adapter-spec-{uuid.uuid4().hex}.json"
    summary_path = work_root / f"adapter-summary-{uuid.uuid4().hex}.json"
    error_path = work_root / f"adapter-error-{uuid.uuid4().hex}"
    process_group_path = work_root / f"adapter-process-group-{uuid.uuid4().hex}"
    process_group_nonce = uuid.uuid4().hex
    write_adapter_supervisor(supervisor)
    spec = {
        "argv": command,
        "cwd": str(cwd),
        "env": env,
        "stdin_base64": base64.b64encode(stdin_bytes).decode(),
        "timeout": timeout_seconds,
        "handshake_timeout": ADAPTER_HANDSHAKE_TIMEOUT,
        "term_grace": ADAPTER_TERM_GRACE,
        "group_absence_timeout": ADAPTER_GROUP_ABSENCE_TIMEOUT,
        "output_cap": ADAPTER_OUTPUT_CAP,
        "process_group_path": str(process_group_path),
        "process_group_nonce": process_group_nonce,
        "error_path": str(error_path),
    }
    write_json_atomic(spec_path, spec, work_root)
    proof = managed_process(
        [sys.executable, str(supervisor), str(spec_path), str(summary_path)],
        timeout_seconds
        + ADAPTER_HANDSHAKE_TIMEOUT
        + ADAPTER_TERM_GRACE
        + ADAPTER_GROUP_ABSENCE_TIMEOUT
        + 1,
        table_reader=table_reader,
    )
    target_group_absent = True
    record_deadline = time.monotonic() + ADAPTER_HANDSHAKE_TIMEOUT
    while not process_group_path.is_file() and time.monotonic() < record_deadline:
        time.sleep(0.01)
    if process_group_path.is_file():
        group_record = json.loads(read_bounded_file(process_group_path, work_root, 512))
        if (
            set(group_record) != {"nonce", "pid", "pgid", "sid"}
            or group_record["nonce"] != process_group_nonce
            or not all(isinstance(group_record[key], int) for key in ("pid", "pgid", "sid"))
            or group_record["pid"] <= 1
            or group_record["pid"] != group_record["pgid"]
            or group_record["pid"] != group_record["sid"]
        ):
            fail("adapter process group record invalid")
        group_metadata = process_group_path.stat()
        if stat.S_IMODE(group_metadata.st_mode) != 0o400 or group_metadata.st_uid != os.getuid():
            fail("adapter process group record unsafe")
        target_group = group_record["pgid"]
        if target_group == os.getpgrp():
            fail("adapter process group record unsafe")
        try:
            if os.getpgid(group_record["pid"]) != target_group or os.getsid(group_record["pid"]) != target_group:
                fail("adapter process group identity changed")
            os.killpg(target_group, 0)
        except ProcessLookupError:
            pass
        except PermissionError:
            target_group_absent = False
        else:
            target_group_absent = False
        absence_deadline = time.monotonic() + ADAPTER_GROUP_ABSENCE_TIMEOUT
        while time.monotonic() < absence_deadline:
            try:
                os.killpg(target_group, 0)
            except ProcessLookupError:
                break
            except PermissionError:
                target_group_absent = False
            time.sleep(0.01)
        try:
            os.killpg(target_group, 0)
        except ProcessLookupError:
            target_group_absent = True
        except PermissionError:
            target_group_absent = False
        else:
            target_group_absent = False
    if not target_group_absent:
        fail("adapter process group survived cleanup")
    if not proof["reaped"] or not proof["process_group_reaped"] or not proof["descendants_absent"]:
        fail("adapter process proof incomplete")
    if not summary_path.is_file():
        detail = read_bounded_file(error_path, work_root, 4096).strip() if error_path.is_file() else "no detail"
        fail(f"adapter supervisor failed: returncode={proof['returncode']}: {detail}")
    summary = json.loads(read_bounded_file(summary_path, work_root, ADAPTER_SUMMARY_CAP))
    if not summary.get("process_group_absent"):
        fail("adapter process group proof incomplete")
    if summary.get("overflow"):
        fail("adapter output exceeded cap")
    if summary.get("timed_out") or proof["timed_out"]:
        fail("adapter session timeout")
    stdout = base64.b64decode(summary["stdout_base64"]).decode("utf-8", errors="replace")
    stderr = base64.b64decode(summary["stderr_base64"]).decode("utf-8", errors="replace")
    normalized_proof = {
        "leader_waited": proof["reaped"],
        "pgid_absent": proof["process_group_reaped"],
        "descendants_absent": proof["descendants_absent"],
        "observed_escape_detected": not proof["descendants_absent"],
        "timed_out": proof["timed_out"],
        "term_sent": proof["term_sent"] or summary.get("term_sent", False),
        "kill_sent": proof["kill_sent"] or summary.get("kill_sent", False),
    }
    return subprocess.CompletedProcess(command, summary["returncode"], stdout, stderr), normalized_proof


def git_fixture_command(git_path, env, cwd, *arguments):
    result = run_bounded([git_path, *arguments], cwd, env, output_cap=65536, timeout=20)
    if result.returncode != 0:
        fail(f"live fixture Git failed: {arguments}: {result.stderr.strip()}")
    return result.stdout.strip()


def progress_pending_gate(progress_path, expected_answer):
    if not progress_path.is_file():
        return None, "pending-gate-missing"
    text_value = progress_path.read_text(encoding="utf-8")
    pattern = re.compile(
        r"(?m)^pending_gate:\n  id: (?P<id>[^\n]+)\n  issued_at: (?P<issued>[^\n]+)\n"
        r"  expected_answer_class: (?P<class>[^\n]+)$"
    )
    matches = list(pattern.finditer(text_value))
    if len(matches) != 1:
        return None, "pending-gate-missing-or-duplicate"
    match = matches[0]
    if "gate_answer_receipt:" in text_value:
        return None, "pending-gate-answer-reserved"
    if match.group("id") != expected_answer["gate_id"] or match.group("class") != expected_answer["expected_answer_class"]:
        return None, "pending-gate-mismatch"
    phase_match = re.search(r"(?m)^phase: ([^\n]+)$", text_value)
    if not phase_match or phase_match.group(1) != expected_answer["phase"]:
        return None, "pending-gate-phase"
    status_match = re.search(r"(?m)^phase_status: ([^\n]+)$", text_value)
    if not status_match or status_match.group(1) != "waiting-user":
        return None, "pending-gate-status"
    updated_match = re.search(r"(?m)^updated: ([^\n]+)$", text_value)
    issued_time = parse_gate_timestamp(match.group("issued"))
    updated_time = parse_gate_timestamp(updated_match.group(1)) if updated_match else None
    observed_time = datetime.now(timezone.utc)
    if issued_time is None or updated_time is None or issued_time != updated_time or issued_time > observed_time:
        return None, "pending-gate-stale"
    approval_field = "design_approved:" if expected_answer["gate_id"] == "design-approval" else "ship_approved:"
    if re.search(rf"(?m)^{approval_field}", text_value):
        return None, "pending-gate-already-approved"
    return {"issued_at": match.group("issued"), "text": text_value}, None


def reserve_progress_answer(progress_path, expected_answer, reserved_at):
    gate_state, invariant = progress_pending_gate(progress_path, expected_answer)
    if invariant is not None:
        fail(invariant)
    receipt_block = (
        "gate_answer_receipt:\n"
        f"  gate_id: {expected_answer['gate_id']}\n"
        f"  gate_issued_at: {gate_state['issued_at']}\n"
        f"  answer: {expected_answer['answer']}\n"
        f"  reserved_at: {reserved_at}\n\n"
    )
    text_value = gate_state["text"]
    marker = "final_action:"
    if marker in text_value:
        text_value = text_value.replace(marker, receipt_block + marker, 1)
    else:
        frontmatter_end = text_value.find("\n---", 4)
        if frontmatter_end < 0:
            fail("pending gate frontmatter missing")
        text_value = text_value[:frontmatter_end] + "\n" + receipt_block.rstrip() + text_value[frontmatter_end:]
    text_value = text_value.rstrip() + (
        f"\n- {reserved_at} gate: answer-reserved id={expected_answer['gate_id']} "
        f"answer={expected_answer['answer']}\n"
    )
    descriptor, temporary_name = tempfile.mkstemp(prefix=".progress-answer-", dir=str(progress_path.parent))
    temporary_path = Path(temporary_name)
    try:
        payload = text_value.encode("utf-8")
        written = 0
        while written < len(payload):
            written += os.write(descriptor, payload[written:])
        os.fsync(descriptor)
        os.close(descriptor)
        descriptor = None
        os.replace(str(temporary_path), str(progress_path))
    finally:
        if descriptor is not None:
            os.close(descriptor)
        if temporary_path.exists():
            temporary_path.unlink()


def extract_usage(output, harness):
    cost = Decimal("0")
    tokens = 0
    for line in output.splitlines():
        try:
            event = json.loads(line)
        except json.JSONDecodeError:
            continue
        if harness == "claude" and isinstance(event.get("total_cost_usd"), (int, float, str)):
            cost = max(cost, Decimal(str(event["total_cost_usd"])))
        usage = event.get("usage")
        if isinstance(usage, dict):
            tokens += sum(value for key, value in usage.items() if key.endswith("tokens") and isinstance(value, int))
    return (str(cost) if cost else None), tokens


def paid_auth_preflight():
    broker_variables = {
        "claude": "CONFORMANCE_CLAUDE_AUTH_BROKER",
        "codex": "CONFORMANCE_CODEX_AUTH_BROKER",
    }
    readiness = {}
    with tempfile.TemporaryDirectory(prefix="paid-auth-preflight-") as auth_temp:
        auth_root = Path(auth_temp)
        env = {
            "PATH": "/usr/bin:/bin",
            "HOME": str(auth_root),
            "TMPDIR": str(auth_root),
            "LC_ALL": "C",
            "LANG": "C",
        }
        for harness, variable in broker_variables.items():
            configured = os.environ.get(variable)
            if not configured:
                fail("auth-isolation-unavailable")
            configured_path = Path(configured)
            if not configured_path.is_absolute() or configured_path.is_symlink():
                fail("auth-isolation-unavailable")
            try:
                broker_path = configured_path.resolve(strict=True)
            except FileNotFoundError:
                fail("auth-isolation-unavailable")
            if not broker_path.is_file() or not os.access(str(broker_path), os.X_OK):
                fail("auth-isolation-unavailable")
            broker_bytes = broker_path.read_bytes()
            if len(broker_bytes) > 16777216:
                fail("auth-isolation-unavailable")
            private_broker = auth_root / f"{harness}-broker"
            private_broker.write_bytes(broker_bytes)
            private_broker.chmod(0o500)
            result = run_bounded(
                [str(private_broker), "status", "--json", "--harness", harness],
                auth_root,
                env,
                output_cap=8192,
                timeout=10,
            )
            if result.returncode != 0:
                fail("auth-isolation-unavailable")
            try:
                status = json.loads(result.stdout)
            except json.JSONDecodeError:
                fail("auth-isolation-unavailable")
            expected_status = {"authenticated": True, "harness": harness, "method": "brokered"}
            if harness == "claude":
                host_home = status.get("host_home")
                if not isinstance(host_home, str) or not Path(host_home).is_absolute():
                    fail("auth-isolation-unavailable")
                try:
                    resolved_host_home = Path(host_home).resolve(strict=True)
                except FileNotFoundError:
                    fail("auth-isolation-unavailable")
                expected_status["host_home"] = str(resolved_host_home)
            if status != expected_status:
                fail("auth-isolation-unavailable")
            readiness[harness] = {
                "bytes": broker_bytes,
                "sha256": hashlib.sha256(broker_bytes).hexdigest(),
            }
            if harness == "claude":
                readiness[harness]["host_home"] = expected_status["host_home"]
    return readiness


def paid_source_preflight():
    governed = [
        "scripts/test-release-loop-conformance.sh",
        ".claude-plugin/plugin.json",
        ".codex-plugin/plugin.json",
        "PRINCIPLES.md",
        "skills",
        "references",
        "schemas",
        "tests/conformance/release-loop",
    ]
    status = subprocess.run(
        ["git", "status", "--porcelain", "--", *governed],
        cwd=str(root),
        check=False,
        capture_output=True,
        text=True,
        timeout=10,
    )
    if status.returncode != 0 or status.stdout.strip():
        fail("paid-source-preflight-dirty")
    snapshot = adapter_source_snapshot(root)
    head = subprocess.run(
        ["git", "rev-parse", "HEAD"], cwd=str(root), check=True, capture_output=True, text=True, timeout=10
    ).stdout.strip()
    plan_path = root / "docs/plans/2026-08-24-001-feat-release-loop-conformance-fuzzing-plan.md"
    seal_match = re.search(r"(?m)^body_seal: ([0-9a-f]{64})$", plan_path.read_text(encoding="utf-8"))
    if not re.fullmatch(r"[0-9a-f]{40,64}", head) or not seal_match:
        fail("paid-source-preflight-identity")
    return {
        "snapshot": snapshot,
        "receipt": {
            "snapshot_sha256": object_digest(snapshot),
            "head_sha": head,
            "plan_body_seal": seal_match.group(1),
        },
    }


def build_live_adapter_env(bin_path, git_path, claude_path, codex_path, home_path, temp_path):
    return {
        "PATH": f"{bin_path}:{git_path.parent}:{claude_path.parent}:{codex_path.parent}:/usr/bin:/bin",
        "HOME": str(home_path),
        "TMPDIR": str(temp_path),
        "LC_ALL": "C",
        "LANG": "C",
        "GIT_CONFIG_NOSYSTEM": "1",
        "GIT_TERMINAL_PROMPT": "0",
    }


def actual_paid_launcher(call_spec):
    run_root = root / ".release-loop/evidence/live-runs" / uuid.uuid4().hex
    run_root.mkdir(parents=True)
    origin_path = run_root / "origin.git"
    repo_path = run_root / "repo"
    home_path = run_root / "home"
    temp_path = run_root / "tmp"
    bin_path = run_root / "bin"
    for path in (home_path, temp_path, bin_path):
        path.mkdir()
    git_path = shutil.which("git")
    claude_path = shutil.which("claude")
    codex_path = shutil.which("codex")
    if not git_path or not claude_path or not codex_path:
        fail("live adapter executable unavailable")
    env = build_live_adapter_env(
        bin_path, Path(git_path), Path(claude_path), Path(codex_path), home_path, temp_path
    )
    git_fixture_command(git_path, env, run_root, "clone", "--bare", str(root), str(origin_path))
    git_fixture_command(git_path, env, run_root, "clone", str(origin_path), str(repo_path))
    for key, value in (
        ("user.name", "Conformance Fixture"), ("user.email", "fixture@example.invalid"),
        ("core.autocrlf", "false"), ("core.safecrlf", "false"), ("commit.gpgsign", "false"),
    ):
        git_fixture_command(git_path, env, repo_path, "config", key, value)
    validate_policy_files(repo_path)
    source_snapshot = call_spec["expected_source_snapshot"]
    verify_preflight_inputs(root, source_snapshot, {})
    policy_digests = {
        path: hashlib.sha256(path.read_bytes()).hexdigest()
        for path in (
            repo_path / ".claude/settings.json",
            repo_path / ".claude/hooks/conformance-path-guard",
            repo_path / ".codex/rules/conformance.rules",
            repo_path / ".codex/conformance.config.toml",
            repo_path / "empty-mcp.json",
        )
    }
    codex_profile_path = repo_path / ".codex/conformance.config.toml"
    env.update(
        CONFORMANCE_CODEX_PROFILE_PATH=str(codex_profile_path),
        CONFORMANCE_CODEX_PROFILE_SHA256=hashlib.sha256(codex_profile_path.read_bytes()).hexdigest(),
    )
    gh_path = bin_path / "gh"
    write_gh_simulator(gh_path)
    validate_gh_simulator(gh_path)
    (run_root / "gh-state.json").write_text("{}\n", encoding="utf-8")
    wrapper_path = repo_path / ".conformance/bin/fixture-exec"
    write_fixture_wrapper(wrapper_path)
    env.update(
        CONFORMANCE_FIXTURE_ROOT=str(run_root),
        CONFORMANCE_FIXTURE_REPO=str(repo_path),
        CONFORMANCE_FIXTURE_ORIGIN=str(origin_path),
        CONFORMANCE_GIT=git_path,
        CONFORMANCE_GH=str(gh_path),
        CONFORMANCE_GH_SHA256=hashlib.sha256(gh_path.read_bytes()).hexdigest(),
        CONFORMANCE_PYTHON=sys.executable,
        CONFORMANCE_WRAPPER_SHA256=hashlib.sha256(wrapper_path.read_bytes()).hexdigest(),
    )
    private_brokers = {}
    for broker_harness, broker_bytes in call_spec["auth_broker_bytes"].items():
        private_path = run_root / f".{broker_harness}-auth-broker"
        private_path.write_bytes(broker_bytes)
        private_path.chmod(0o500)
        private_brokers[broker_harness] = private_path

    def verified_private_broker(broker_harness):
        private_path = private_brokers[broker_harness]
        if private_path.is_symlink():
            fail("auth-broker-identity-mismatch")
        metadata = private_path.stat()
        expected_digest = call_spec["auth_broker_digests"][broker_harness]
        if metadata.st_nlink != 1 or hashlib.sha256(private_path.read_bytes()).hexdigest() != expected_digest:
            fail("auth-broker-identity-mismatch")
        return str(private_path)

    harness = call_spec["harness"]
    case_id = call_spec["case_id"]
    golden = load_json(data_root / f"golden/{harness}/{case_id}.json")
    settings_path = repo_path / ".claude/settings.json"
    mcp_path = repo_path / "empty-mcp.json"
    result_path = run_root / "codex-last.txt"
    session_id = str(uuid.uuid4()) if harness == "claude" else None
    if harness == "claude":
        command = build_claude_initial(
            root, call_spec["models"]["claude"], settings_path, mcp_path,
            call_spec["caps"]["claude_max_invocation_usd"], golden["prompt"], session_id,
        )
        command[0] = claude_path
        stdin_bytes = b""
    else:
        command = build_codex_initial(repo_path, call_spec["models"]["codex"], result_path)
        command[0] = codex_path
        stdin_bytes = adapter_packet(golden, root)
    broker_path = verified_private_broker(harness)
    command = [broker_path, "--", *command]
    outputs = []
    proofs = []
    actual_session_started = time.monotonic()
    initial_turn_id = f"{call_spec['call_id']}:turn-1"
    call_spec["before_invocation"](initial_turn_id, 0)
    try:
        verify_preflight_inputs(root, source_snapshot, policy_digests)
        result, proof = managed_adapter_call(
            command, repo_path, env, stdin_bytes, call_spec["caps"]["per_turn_timeout"], run_root
        )
    finally:
        verify_preflight_inputs(root, source_snapshot, policy_digests)
    outputs.append(result.stdout)
    proofs.append(proof)
    if harness == "codex" and result.returncode == 0:
        read_bounded_file(result_path, run_root)
    initial_cost, initial_tokens = extract_usage(result.stdout, harness)
    initial_accounting = (
        extract_claude_accounting(
            result.stdout,
            result.stderr,
            repo_path,
            call_spec.get("claude_host_home", home_path),
        )
        if harness == "claude"
        else None
    )
    call_spec["after_invocation"](
        initial_turn_id,
        proof,
        initial_cost,
        initial_tokens,
        time.monotonic() - actual_session_started,
        initial_accounting,
    )
    if result.returncode != 0:
        return {
            "infrastructure_status": "failed", "verdict": "unknown", "observed_cost": None,
            "observed_tokens": 0, "turns": 1, "elapsed_seconds": time.monotonic() - actual_session_started,
            "process_proof": proof,
            "command_audit": {"invocation_id": call_spec["call_id"], "harness": harness, "turns": 1},
        }
    parsed_id = parse_session_id(result.stdout, harness)
    progress_path = repo_path / ".release-loop/progress.md"
    turns = 1
    infrastructure_status = "pass"
    for answer in golden["scripted_answers"]:
        turns += 1
        if turns > call_spec["caps"]["max_turns_per_session"]:
            fail("turn-cap-exhausted")
        reserved_at = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
        reserve_progress_answer(progress_path, answer, reserved_at)
        if harness == "claude":
            resume = build_claude_resume(
                root, call_spec["models"]["claude"], settings_path, mcp_path,
                call_spec["caps"]["claude_max_invocation_usd"], answer["answer"], parsed_id,
            )
            resume[0] = claude_path
            resume_input = b""
        else:
            resume = build_codex_resume(call_spec["models"]["codex"], parsed_id)
            resume[0] = codex_path
            resume_input = (answer["answer"] + "\n").encode()
        broker_path = verified_private_broker(harness)
        resume = [broker_path, "--", *resume]
        resume_turn_id = f"{call_spec['call_id']}:turn-{turns}"
        call_spec["before_invocation"](resume_turn_id, time.monotonic() - actual_session_started)
        try:
            verify_preflight_inputs(root, source_snapshot, policy_digests)
            resumed, resume_proof = managed_adapter_call(
                resume, repo_path, env, resume_input, call_spec["caps"]["per_turn_timeout"], run_root
            )
        finally:
            verify_preflight_inputs(root, source_snapshot, policy_digests)
        outputs.append(resumed.stdout)
        proofs.append(resume_proof)
        resume_cost, resume_tokens = extract_usage(resumed.stdout, harness)
        resume_accounting = (
            extract_claude_accounting(
                resumed.stdout,
                resumed.stderr,
                repo_path,
                call_spec.get("claude_host_home", home_path),
            )
            if harness == "claude"
            else None
        )
        call_spec["after_invocation"](
            resume_turn_id,
            resume_proof,
            resume_cost,
            resume_tokens,
            time.monotonic() - actual_session_started,
            resume_accounting,
        )
        if resumed.returncode != 0:
            infrastructure_status = "failed"
            break
    terminal_archive = list((repo_path / ".release-loop/archive").glob("*/progress.md")) if (repo_path / ".release-loop/archive").is_dir() else []
    verdict = "conformant" if infrastructure_status == "pass" and terminal_archive else (
        "unknown" if infrastructure_status != "pass" else "nonconformant"
    )
    observed_cost, observed_tokens = extract_usage("\n".join(outputs), harness)
    aggregate_proof = {
        "leader_waited": all(proof["leader_waited"] for proof in proofs),
        "pgid_absent": all(proof["pgid_absent"] for proof in proofs),
        "descendants_absent": all(proof["descendants_absent"] for proof in proofs),
        "observed_escape_detected": any(proof["observed_escape_detected"] for proof in proofs),
    }
    wrapper_audit_path = run_root / "wrapper-audit.jsonl"
    gh_audit_path = run_root / "gh-audit.jsonl"
    return {
        "infrastructure_status": infrastructure_status,
        "verdict": verdict,
        "observed_cost": observed_cost,
        "observed_tokens": observed_tokens,
        "turns": turns,
        "elapsed_seconds": time.monotonic() - actual_session_started,
        "process_proof": aggregate_proof,
        "command_audit": {
            "invocation_id": call_spec["call_id"],
            "harness": harness,
            "turns": turns,
            "codex_profile_sha256": policy_digests.get(codex_profile_path) if harness == "codex" else None,
            "wrapper_audit_sha256": hashlib.sha256(wrapper_audit_path.read_bytes()).hexdigest()
            if wrapper_audit_path.is_file() else None,
            "gh_audit_sha256": hashlib.sha256(gh_audit_path.read_bytes()).hexdigest()
            if gh_audit_path.is_file() else None,
        },
    }


def validate_resource_group():
    claude_policy_template = load_json(data_root / "policies/claude-settings.json")
    if claude_policy_template.get("sandbox", {}).get("autoAllowBashIfSandboxed") is not False:
        fail("resource Claude policy permits sandbox Bash auto-allow")
    policy_fixture_root = Path("/private/tmp/conformance-policy-fixture")
    policy_feature_root = Path("/private/tmp/conformance-policy-feature")
    policy_control = copy.deepcopy(claude_policy_template)
    validate_claude_policy_document(policy_control, policy_fixture_root, policy_feature_root, template=True)
    policy_mutations = (
        ("sandbox-disabled", lambda value: value["sandbox"].__setitem__("enabled", False)),
        ("sandbox-fallback", lambda value: value["sandbox"].__setitem__("failIfUnavailable", False)),
        ("unsandboxed-escape", lambda value: value["sandbox"].__setitem__("allowUnsandboxedCommands", True)),
        ("sandbox-bash-auto-allow", lambda value: value["sandbox"].__setitem__("autoAllowBashIfSandboxed", True)),
        ("home-readable", lambda value: value["sandbox"]["filesystem"].__setitem__("denyRead", [])),
        ("home-writable", lambda value: value["sandbox"]["filesystem"].__setitem__("denyWrite", [])),
        ("credential-file-readable", lambda value: value["sandbox"]["credentials"].__setitem__("files", [])),
        ("credential-env-readable", lambda value: value["sandbox"]["credentials"].__setitem__("envVars", [])),
        ("unscoped-edit", lambda value: value["permissions"]["allow"].append("Edit")),
        ("path-guard-missing", lambda value: value.__setitem__("hooks", {})),
    )
    for label, mutate in policy_mutations:
        mutant = copy.deepcopy(claude_policy_template)
        mutate(mutant)
        try:
            validate_claude_policy_document(mutant, policy_fixture_root, policy_feature_root, template=True)
        except ValueError as exc:
            if "Claude policy" not in str(exc):
                fail(f"resource Claude policy mutant diagnostic mismatch: {label}: {exc}")
        else:
            fail(f"resource Claude policy mutant accepted: {label}")
    with tempfile.TemporaryDirectory(prefix="claude-path-guard-", dir=str(root / ".release-loop/evidence/U6")) as guard_temp:
        guard_root = Path(guard_temp)
        guard_fixture = guard_root / "fixture"
        guard_feature = guard_root / "feature"
        guard_outside = guard_root / "outside"
        for path in (guard_fixture, guard_feature, guard_outside):
            path.mkdir()
        guard_path = guard_fixture / ".claude/hooks/conformance-path-guard"
        write_claude_path_guard(guard_path, guard_fixture, guard_feature)
        guard_cases = (
            ("read-fixture", "Read", {"file_path": str(guard_fixture / "state.md")}, 0),
            ("read-feature", "Read", {"file_path": str(guard_feature / "SKILL.md")}, 0),
            ("write-fixture", "Write", {"file_path": str(guard_fixture / "result.md")}, 0),
            ("write-feature", "Write", {"file_path": str(guard_feature / "SKILL.md")}, 2),
            ("write-guard", "Write", {"file_path": str(guard_path)}, 2),
            ("write-wrapper", "Edit", {"file_path": str(guard_fixture / ".conformance/bin/fixture-exec")}, 2),
            ("write-git", "Write", {"file_path": str(guard_fixture / ".git/config")}, 2),
            ("read-outside", "Read", {"file_path": str(guard_outside / "secret")}, 2),
            ("glob-outside", "Glob", {"path": str(guard_outside), "pattern": "**/*"}, 2),
            ("glob-absolute-pattern", "Glob", {"path": str(guard_fixture), "pattern": str(guard_outside / "**/*")}, 2),
            ("glob-parent-pattern", "Glob", {"path": str(guard_fixture), "pattern": "../outside/**/*"}, 2),
            ("glob-home-pattern", "Glob", {"path": str(guard_fixture), "pattern": "~/.ssh/**"}, 2),
            ("grep-outside", "Grep", {"path": str(guard_outside), "pattern": "token"}, 2),
            ("grep-absolute-glob", "Grep", {"path": str(guard_fixture), "pattern": "token", "glob": str(guard_outside / "*")}, 2),
            ("missing-path", "Read", {}, 2),
        )
        for label, tool_name, tool_input, expected_code in guard_cases:
            guard_input = json.dumps({
                "cwd": str(guard_fixture),
                "tool_name": tool_name,
                "tool_input": tool_input,
            }).encode()
            guarded = run_bounded([str(guard_path)], guard_fixture, {}, input_bytes=guard_input)
            if guarded.returncode != expected_code:
                fail(f"resource Claude path guard mismatch: {label}")
    live_env_control = build_live_adapter_env(
        Path("/private/tmp/bin"),
        Path("/usr/bin/git"),
        Path("/usr/local/bin/claude"),
        Path("/usr/local/bin/codex"),
        Path("/private/tmp/home"),
        Path("/private/tmp/session"),
    )
    if set(live_env_control) != {
        "PATH", "HOME", "TMPDIR", "LC_ALL", "LANG", "GIT_CONFIG_NOSYSTEM", "GIT_TERMINAL_PROMPT"
    } or "CLAUDE_CODE_SUBPROCESS_ENV_SCRUB" in live_env_control:
        fail("resource live adapter environment is not closed")
    with tempfile.TemporaryDirectory(prefix="adapter-cap-", dir=str(root / ".release-loop/evidence/U6")) as cap_temp:
        cap_root = Path(cap_temp)
        stdin_payload = b"adapter-handshake-input"
        stdin_result, _ = managed_adapter_call(
            [sys.executable, "-c", "import sys;sys.stdout.buffer.write(sys.stdin.buffer.read())"],
            cap_root,
            {"PATH": "/usr/bin:/bin"},
            stdin_payload,
            30,
            cap_root,
            table_reader=empty_process_table,
        )
        if stdin_result.returncode != 0 or stdin_result.stdout.encode() != stdin_payload:
            fail("resource adapter handshake consumed target stdin")
        below, _ = managed_adapter_call(
            [sys.executable, "-c", f"import sys;sys.stdout.write('x'*{ADAPTER_OUTPUT_CAP - 1})"],
            cap_root,
            {"PATH": "/usr/bin:/bin"},
            b"",
            30,
            cap_root,
            table_reader=empty_process_table,
        )
        if below.returncode != 0 or len(below.stdout) != ADAPTER_OUTPUT_CAP - 1:
            fail("resource adapter below-cap output rejected")
        exact_stdout = ADAPTER_OUTPUT_CAP // 2
        exact_stderr = ADAPTER_OUTPUT_CAP - exact_stdout
        exact, _ = managed_adapter_call(
            [
                sys.executable,
                "-c",
                f"import sys;sys.stdout.write('x'*{exact_stdout});sys.stderr.write('y'*{exact_stderr})",
            ],
            cap_root,
            {"PATH": "/usr/bin:/bin"},
            b"",
            30,
            cap_root,
            table_reader=empty_process_table,
        )
        if (
            exact.returncode != 0
            or exact.stdout != "x" * exact_stdout
            or exact.stderr != "y" * exact_stderr
        ):
            fail("resource adapter exact-cap output rejected")
        try:
            managed_adapter_call(
                [sys.executable, "-c", f"import sys;sys.stdout.write('x'*{ADAPTER_OUTPUT_CAP + 1})"],
                cap_root,
                {"PATH": "/usr/bin:/bin"},
                b"",
                30,
                cap_root,
                table_reader=empty_process_table,
            )
        except ValueError as exc:
            if "adapter output exceeded cap" not in str(exc):
                fail(f"resource adapter cap diagnostic mismatch: {exc}")
        else:
            fail("resource adapter above-cap output accepted")
        mixed_stream_bytes = ADAPTER_OUTPUT_CAP * 3 // 4
        try:
            managed_adapter_call(
                [
                    sys.executable,
                    "-c",
                    f"import sys;sys.stdout.write('x'*{mixed_stream_bytes});"
                    f"sys.stderr.write('y'*{mixed_stream_bytes})",
                ],
                cap_root,
                {"PATH": "/usr/bin:/bin"},
                b"",
                30,
                cap_root,
                table_reader=empty_process_table,
            )
        except ValueError as exc:
            if "adapter output exceeded cap" not in str(exc):
                fail(f"resource adapter mixed-stream diagnostic mismatch: {exc}")
        else:
            fail("resource adapter mixed-stream overflow accepted")
        descendant_pid_path = cap_root / "adapter-descendant.pid"
        descendant_code = (
            "import pathlib,subprocess,sys,time;"
            "child=subprocess.Popen([sys.executable,'-c','import time;time.sleep(3)']);"
            f"pathlib.Path({str(descendant_pid_path)!r}).write_text(str(child.pid));"
            f"sys.stdout.write('x'*{ADAPTER_OUTPUT_CAP + 1});sys.stdout.flush();time.sleep(3)"
        )
        try:
            managed_adapter_call(
                [sys.executable, "-c", descendant_code],
                cap_root,
                {"PATH": "/usr/bin:/bin"},
                b"",
                10,
                cap_root,
                table_reader=empty_process_table,
            )
        except ValueError as exc:
            if "adapter output exceeded cap" not in str(exc):
                fail(f"resource adapter descendant diagnostic mismatch: {exc}")
        else:
            fail("resource adapter descendant overflow accepted")
        descendant_pid = int(descendant_pid_path.read_text(encoding="utf-8"))
        descendant_deadline = time.monotonic() + 1
        while pid_exists(descendant_pid) and time.monotonic() < descendant_deadline:
            time.sleep(0.01)
        if pid_exists(descendant_pid):
            fail("resource adapter descendant survived overflow")
        timeout_term_path = cap_root / "adapter-timeout-term"
        timeout_pid_path = cap_root / "adapter-timeout.pid"
        timeout_code = (
            "import os,pathlib,signal,time;"
            f"term_path=pathlib.Path({str(timeout_term_path)!r});"
            f"pathlib.Path({str(timeout_pid_path)!r}).write_text(str(os.getpid()));"
            "signal.signal(signal.SIGTERM,lambda *_:term_path.write_text('term'));"
            "time.sleep(3)"
        )
        timeout_summaries = set(cap_root.glob("adapter-summary-*"))
        try:
            managed_adapter_call(
                [sys.executable, "-c", timeout_code],
                cap_root,
                {"PATH": "/usr/bin:/bin"},
                b"",
                2,
                cap_root,
                table_reader=empty_process_table,
            )
        except ValueError as exc:
            if "adapter session timeout" not in str(exc):
                fail(f"resource adapter timeout diagnostic mismatch: {exc}")
        else:
            fail("resource adapter timeout accepted")
        if not timeout_term_path.is_file():
            fail("resource adapter timeout skipped TERM grace")
        timeout_summary_paths = set(cap_root.glob("adapter-summary-*")) - timeout_summaries
        if len(timeout_summary_paths) != 1:
            fail("resource adapter timeout summary missing")
        timeout_summary = json.loads(read_bounded_file(timeout_summary_paths.pop(), cap_root, ADAPTER_SUMMARY_CAP))
        if not timeout_summary.get("term_sent") or not timeout_summary.get("kill_sent"):
            fail("resource adapter timeout signal proof incomplete")
        timeout_pid = int(timeout_pid_path.read_text(encoding="utf-8"))
        timeout_deadline = time.monotonic() + 1
        while pid_exists(timeout_pid) and time.monotonic() < timeout_deadline:
            time.sleep(0.01)
        if pid_exists(timeout_pid):
            fail("resource adapter survived timeout KILL")
        crash_pid_path = cap_root / "adapter-crash.pid"
        crash_child_pid_path = cap_root / "adapter-crash-child.pid"
        crash_code = (
            "import os,pathlib,subprocess,sys,time;"
            "child=subprocess.Popen([sys.executable,'-c','import time;time.sleep(3)']);"
            f"pathlib.Path({str(crash_pid_path)!r}).write_text(str(os.getpid()));"
            f"pathlib.Path({str(crash_child_pid_path)!r}).write_text(str(child.pid));"
            "os.kill(os.getppid(),9);time.sleep(3)"
        )
        try:
            managed_adapter_call(
                [sys.executable, "-c", crash_code],
                cap_root,
                {"PATH": "/usr/bin:/bin"},
                b"",
                10,
                cap_root,
                table_reader=empty_process_table,
            )
        except ValueError as exc:
            if "adapter supervisor failed" not in str(exc):
                fail(f"resource adapter supervisor crash diagnostic mismatch: {exc}")
        else:
            fail("resource adapter supervisor crash accepted")
        crash_pid = int(crash_pid_path.read_text(encoding="utf-8"))
        crash_child_pid = int(crash_child_pid_path.read_text(encoding="utf-8"))
        crash_deadline = time.monotonic() + ADAPTER_GROUP_ABSENCE_TIMEOUT
        while any(pid_exists(pid) for pid in (crash_pid, crash_child_pid)) and time.monotonic() < crash_deadline:
            time.sleep(0.01)
        if any(pid_exists(pid) for pid in (crash_pid, crash_child_pid)):
            fail("resource adapter group survived supervisor crash")
    caps = {
        "max_turns_per_session": 4,
        "per_turn_timeout": 30,
        "session_timeout": 120,
        "max_infrastructure_retries": 0,
        "max_concurrency": 2,
        "codex_observed_token_cap": 5000,
        "total_wall_time": 3600,
        "claude_total_budget_usd": "5.00",
        "claude_max_invocation_usd": "0.25",
    }
    models = {"claude": "claude-fixture-model", "codex": "codex-fixture-model"}
    auth_brokers = {"claude": "c" * 64, "codex": "d" * 64}
    source_identity = {
        "snapshot_sha256": "e" * 64,
        "head_sha": "f" * 40,
        "plan_body_seal": "a" * 64,
    }
    broker_test_root = root / ".release-loop/evidence/U6"
    broker_test_root.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="broker-test-", dir=str(broker_test_root)) as broker_temp:
        broker_root = Path(broker_temp)
        broker_paths = {}
        for harness in ("claude", "codex"):
            broker_path = broker_root / f"{harness}-broker"
            broker_path.write_text(
                f"#!{sys.executable}\nimport json,os,sys\n"
                f"harness={harness!r}\n"
                f"host_home={str(broker_root)!r}\n"
                "if sys.argv[1:3] == ['status','--json']:\n"
                " status={'authenticated':True,'harness':harness,'method':'brokered'}\n"
                " if harness=='claude': status['host_home']=host_home\n"
                " print(json.dumps(status)); raise SystemExit(0)\n"
                "if len(sys.argv)>1 and sys.argv[1]=='--': os.execv(sys.argv[2],[sys.argv[2],*sys.argv[3:]])\n"
                "raise SystemExit(2)\n",
                encoding="utf-8",
            )
            broker_path.chmod(0o755)
            broker_paths[harness] = broker_path
        old_brokers = {
            "CONFORMANCE_CLAUDE_AUTH_BROKER": os.environ.get("CONFORMANCE_CLAUDE_AUTH_BROKER"),
            "CONFORMANCE_CODEX_AUTH_BROKER": os.environ.get("CONFORMANCE_CODEX_AUTH_BROKER"),
        }
        os.environ["CONFORMANCE_CLAUDE_AUTH_BROKER"] = str(broker_paths["claude"])
        os.environ["CONFORMANCE_CODEX_AUTH_BROKER"] = str(broker_paths["codex"])
        try:
            broker_readiness = paid_auth_preflight()
            if {key: row["sha256"] for key, row in broker_readiness.items()} != {
                key: hashlib.sha256(path.read_bytes()).hexdigest() for key, path in broker_paths.items()
            }:
                fail("resource broker readiness mismatch")
            if broker_readiness["claude"].get("host_home") != str(broker_root.resolve()):
                fail("resource Claude broker host home mismatch")
            broker_marker = broker_root / "replacement-executed"
            broker_paths["claude"].write_text(
                f"#!{sys.executable}\nfrom pathlib import Path\nPath({str(broker_marker)!r}).write_text('executed')\n",
                encoding="utf-8",
            )
            broker_paths["claude"].chmod(0o755)
            verified_copy = broker_root / "verified-claude-broker"
            verified_copy.write_bytes(broker_readiness["claude"]["bytes"])
            verified_copy.chmod(0o500)
            verified_status = run_bounded(
                [str(verified_copy), "status", "--json", "--harness", "claude"],
                broker_root,
                {"PATH": "/usr/bin:/bin", "HOME": str(broker_root), "LC_ALL": "C", "LANG": "C"},
                output_cap=8192,
                timeout=10,
            )
            if verified_status.returncode != 0 or broker_marker.exists():
                fail("resource broker replacement bytes executed")
            del os.environ["CONFORMANCE_CLAUDE_AUTH_BROKER"]
            try:
                paid_auth_preflight()
            except ValueError as exc:
                if "auth-isolation-unavailable" not in str(exc):
                    fail(f"resource missing broker diagnostic mismatch: {exc}")
            else:
                fail("resource missing broker accepted")
        finally:
            for key, value in old_brokers.items():
                if value is None:
                    os.environ.pop(key, None)
                else:
                    os.environ[key] = value
    session_marker = "resource-session"
    session_started = "2026-08-24T06:00:00Z"
    observed_at = "2026-08-24T06:01:00Z"
    used_nonces = set()
    pilot = pilot_command(caps, models)
    pilot_caps = {**caps, "max_concurrency": 1, "total_wall_time": caps["session_timeout"] * 2}
    pilot_approval_packet = build_paid_approval_packet(
        "live-pilot", pilot, models, pilot_caps, auth_brokers, source_identity
    )
    pilot_approval_payload = (json.dumps(pilot_approval_packet, sort_keys=True, indent=2) + "\n").encode()
    pilot_approval_sha256 = hashlib.sha256(pilot_approval_payload).hexdigest()
    parsed_pilot, parsed_models, parsed_caps = parse_paid_mode("live-pilot", pilot[3:])
    if parsed_pilot != pilot or parsed_models != models or parsed_caps != pilot_caps:
        fail("resource pilot command parser mismatch")
    receipt = {
        "schema": "release-loop-paid-receipt/v1",
        "gate_kind": "live-pilot",
        "command_sha256": paid_command_digest(pilot),
        "models": models,
        "caps": pilot_caps,
        "auth_brokers": auth_brokers,
        "source_identity": source_identity,
        "approval_packet_sha256": pilot_approval_sha256,
        "approved_at": "2026-08-24T06:00:30Z",
        "session_marker": session_marker,
        "nonce": "a" * 32,
        "status": "approved",
    }
    if validate_paid_receipt(
        receipt, pilot, "live-pilot", models, pilot_caps, auth_brokers, source_identity, pilot_approval_sha256, session_marker, session_started, observed_at, used_nonces
    ) is not None:
        fail("resource pilot receipt control failed")
    consumed, invariant = consume_paid_receipt(receipt, used_nonces)
    if invariant is not None or consumed["status"] != "consumed":
        fail("resource pilot receipt consumption failed")
    receipt_test_root = root / ".release-loop/evidence/U6"
    receipt_test_root.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="receipt-test-", dir=str(receipt_test_root)) as receipt_temp:
        receipt_temp_root = Path(receipt_temp)
        receipt_path = receipt_temp_root / "receipt.json"
        nonce_path = receipt_temp_root / "nonces.json"
        approval_path = receipt_temp_root / "live-pilot-approval.json"
        write_json_atomic(receipt_path, receipt, receipt_temp_root)
        approval_path.write_bytes(pilot_approval_payload)
        durable_receipt, durable_consumption = consume_paid_receipt_file(
            receipt_path,
            nonce_path,
            pilot,
            "live-pilot",
            models,
            pilot_caps,
            auth_brokers,
            source_identity,
            lambda: source_identity,
            pilot_approval_sha256,
            lambda: hashlib.sha256(approval_path.read_bytes()).hexdigest(),
            session_marker,
            session_started,
            observed_at,
            receipt_temp_root,
        )
        if durable_receipt != receipt or durable_consumption["nonce"] != receipt["nonce"]:
            fail("resource durable receipt consumption failed")
        try:
            consume_paid_receipt_file(
                receipt_path,
                nonce_path,
                pilot,
                "live-pilot",
                models,
                pilot_caps,
                auth_brokers,
                source_identity,
                lambda: source_identity,
                pilot_approval_sha256,
                lambda: hashlib.sha256(approval_path.read_bytes()).hexdigest(),
                session_marker,
                session_started,
                observed_at,
                receipt_temp_root,
            )
        except ValueError as exc:
            if "paid-receipt-reused" not in str(exc):
                fail(f"resource durable receipt reuse diagnostic mismatch: {exc}")
        else:
            fail("resource durable receipt reused")
        concurrent_receipt = {**receipt, "nonce": "4" * 32}
        concurrent_receipt_path = receipt_temp_root / "concurrent-receipt.json"
        concurrent_nonce_path = receipt_temp_root / "concurrent-nonces.json"
        write_json_atomic(concurrent_receipt_path, concurrent_receipt, receipt_temp_root)
        children = []
        for _ in range(2):
            child_pid = os.fork()
            if child_pid == 0:
                try:
                    consume_paid_receipt_file(
                        concurrent_receipt_path,
                        concurrent_nonce_path,
                        pilot,
                        "live-pilot",
                        models,
                        pilot_caps,
                        auth_brokers,
                        source_identity,
                        lambda: source_identity,
                        pilot_approval_sha256,
                        lambda: hashlib.sha256(approval_path.read_bytes()).hexdigest(),
                        session_marker,
                        session_started,
                        observed_at,
                        receipt_temp_root,
                    )
                except ValueError as exc:
                    os._exit(2 if "paid-receipt-reused" in str(exc) else 3)
                os._exit(0)
            children.append(child_pid)
        statuses = []
        for child_pid in children:
            _, status = os.waitpid(child_pid, 0)
            statuses.append(os.WEXITSTATUS(status) if os.WIFEXITED(status) else 255)
        if sorted(statuses) != [0, 2]:
            fail(f"resource concurrent receipt consumption mismatch: {statuses}")
        source_race_receipt = {**receipt, "nonce": "7" * 32}
        source_race_path = receipt_temp_root / "source-race-receipt.json"
        source_race_nonces = receipt_temp_root / "source-race-nonces.json"
        write_json_atomic(source_race_path, source_race_receipt, receipt_temp_root)
        try:
            consume_paid_receipt_file(
                source_race_path,
                source_race_nonces,
                pilot,
                "live-pilot",
                models,
                pilot_caps,
                auth_brokers,
                source_identity,
                lambda: {**source_identity, "head_sha": "0" * 40},
                pilot_approval_sha256,
                lambda: hashlib.sha256(approval_path.read_bytes()).hexdigest(),
                session_marker,
                session_started,
                observed_at,
                receipt_temp_root,
            )
        except ValueError as exc:
            if "paid-receipt-source" not in str(exc):
                fail(f"resource source-under-lock diagnostic mismatch: {exc}")
        else:
            fail("resource source change under lock accepted")
        if source_race_nonces.exists():
            fail("resource source failure mutated nonce authority")
        approval_race_receipt = {**receipt, "nonce": "9" * 32}
        approval_race_path = receipt_temp_root / "approval-race-receipt.json"
        approval_race_nonces = receipt_temp_root / "approval-race-nonces.json"
        write_json_atomic(approval_race_path, approval_race_receipt, receipt_temp_root)
        try:
            consume_paid_receipt_file(
                approval_race_path,
                approval_race_nonces,
                pilot,
                "live-pilot",
                models,
                pilot_caps,
                auth_brokers,
                source_identity,
                lambda: source_identity,
                pilot_approval_sha256,
                lambda: "0" * 64,
                session_marker,
                session_started,
                observed_at,
                receipt_temp_root,
            )
        except ValueError as exc:
            if "paid-receipt-approval-packet" not in str(exc):
                fail(f"resource approval-under-lock diagnostic mismatch: {exc}")
        else:
            fail("resource approval packet change under lock accepted")
        if approval_race_nonces.exists():
            fail("resource approval failure mutated nonce authority")
    ledger = new_resource_ledger(pilot_caps)
    if reserve_claude(ledger, pilot_caps, "pilot-claude") is not None:
        fail("resource Claude pilot reservation failed")
    if settle_claude(ledger, "pilot-claude", "0.10") is not None:
        fail("resource Claude pilot settlement failed")
    if record_codex_usage(ledger, pilot_caps, "pilot-codex", 100) is not None:
        fail("resource Codex pilot settlement failed")
    full_command = full_run_command(caps, models)
    parsed_full, parsed_full_models, parsed_full_caps = parse_paid_mode("live", full_command[3:])
    if parsed_full != full_command or parsed_full_models != models or parsed_full_caps != caps:
        fail("resource full command parser mismatch")
    expected_flags = {
        "--cases", "--repetitions", "--claude-model", "--codex-model", "--max-turns-per-session",
        "--per-turn-timeout", "--session-timeout", "--max-infrastructure-retries", "--max-concurrency",
        "--codex-observed-token-cap", "--total-wall-time", "--claude-total-budget-usd",
        "--claude-max-invocation-usd",
    }
    if not expected_flags <= set(full_command):
        fail("resource full command flags missing")

    full_approval_packet = build_paid_approval_packet(
        "live",
        full_command,
        models,
        caps,
        auth_brokers,
        source_identity,
        {"results_sha256": "1" * 64, "settlement_sha256": "2" * 64},
    )
    full_approval_payload = (json.dumps(full_approval_packet, sort_keys=True, indent=2) + "\n").encode()
    full_approval_sha256 = hashlib.sha256(full_approval_payload).hexdigest()
    full_receipt = copy.deepcopy(receipt)
    full_receipt.update(
        gate_kind="live",
        command_sha256=paid_command_digest(full_command),
        caps=caps,
        approval_packet_sha256=full_approval_sha256,
        nonce="b" * 32,
    )
    if validate_paid_receipt(
        full_receipt, full_command, "live", models, caps, auth_brokers, source_identity, full_receipt["approval_packet_sha256"], session_marker, session_started, observed_at, used_nonces
    ) is not None:
        fail("resource full receipt control failed")
    consume_paid_receipt(full_receipt, used_nonces)
    results = []
    full_ledger = new_resource_ledger(caps)
    for harness in ("claude", "codex"):
        for case_id in ("L1-full-lifecycle", "L2-mid-loop-resume", "L3-post-merge-resume", "L4-degraded-dispatch"):
            for repetition in range(1, 4):
                call_id = f"{harness}:{case_id}:{repetition}"
                if harness == "claude":
                    if reserve_claude(full_ledger, caps, call_id) is not None:
                        fail("resource full Claude reservation failed")
                    if settle_claude(full_ledger, call_id, "0.05") is not None:
                        fail("resource full Claude settlement failed")
                elif record_codex_usage(full_ledger, caps, call_id, 100) is not None:
                    fail("resource full Codex settlement failed")
                results.append(
                    {
                        "harness": harness,
                        "case_id": case_id,
                        "repetition": repetition,
                        "infrastructure_status": "pass",
                        "verdict": "conformant",
                    }
                )
    if validate_strata(results) is not None:
        fail("resource full strata control failed")

    process_controls = 0
    normal = managed_process([sys.executable, "-c", "raise SystemExit(0)"], 1, table_reader=empty_process_table)
    if normal["returncode"] != 0 or not normal["reaped"] or normal["timed_out"] or not normal["process_group_reaped"]:
        fail("resource normal process control failed")
    process_controls += 1
    timeout = managed_process(
        [sys.executable, "-c", "import time; time.sleep(5)"], 1, table_reader=empty_process_table
    )
    if not timeout["timed_out"] or not timeout["reaped"] or not timeout["process_group_reaped"]:
        fail("resource timeout process control failed")
    process_controls += 1
    resistant = managed_process(
        [sys.executable, "-c", "import signal,time; signal.signal(signal.SIGTERM, signal.SIG_IGN); time.sleep(5)"],
        1,
        0.2,
        table_reader=empty_process_table,
    )
    if not resistant["kill_sent"] or not resistant["reaped"] or not resistant["process_group_reaped"]:
        fail("resource resistant process control failed")
    process_controls += 1
    escaped_pid_file = receipt_test_root / "escaped-child.pid"
    escaped_code = (
        "import pathlib,subprocess,sys,time; "
        "child=subprocess.Popen([sys.executable,'-c','import time; time.sleep(5)'],start_new_session=True); "
        f"pathlib.Path({str(escaped_pid_file)!r}).write_text(str(child.pid)); time.sleep(5)"
    )

    def scripted_process_table(root_pid):
        table = {}
        try:
            os.kill(root_pid, 0)
            table[root_pid] = {"parent": os.getpid(), "group": root_pid}
        except ProcessLookupError:
            pass
        if escaped_pid_file.is_file():
            child_pid = int(escaped_pid_file.read_text())
            try:
                os.kill(child_pid, 0)
                table[child_pid] = {"parent": root_pid, "group": child_pid}
            except ProcessLookupError:
                pass
        return table

    escaped = managed_process(
        [sys.executable, "-c", escaped_code],
        1,
        0.2,
        table_reader=scripted_process_table,
    )
    if not escaped["timed_out"] or escaped["descendants_absent"] or not escaped["observed_descendants"]:
        fail("resource escaped descendant control failed")
    escaped_child_pid = int(escaped_pid_file.read_text())
    try:
        os.kill(escaped_child_pid, signal.SIGKILL)
    except ProcessLookupError:
        pass
    escaped_deadline = time.monotonic() + 1
    while pid_exists(escaped_child_pid) and time.monotonic() < escaped_deadline:
        time.sleep(0.01)
    if pid_exists(escaped_child_pid):
        fail("resource escaped descendant fixture cleanup failed")
    if escaped_pid_file.exists():
        escaped_pid_file.unlink()
    process_controls += 1
    process_proof = [normal, timeout, resistant]
    manifest = generation_manifest(models, results, full_command, full_receipt, full_ledger, process_proof)
    if validate_generation_manifest(manifest) is not None:
        fail("resource generation manifest control failed")
    manifest_path = root / ".release-loop/evidence/U6/fake-generation.json"
    write_json_atomic(manifest_path, manifest, root / ".release-loop")
    persisted_manifest = json.loads(read_bounded_file(manifest_path, manifest_path.parent, 1048576))
    if persisted_manifest != manifest or validate_generation_manifest(persisted_manifest) is not None:
        fail("resource persisted generation manifest mismatch")

    scheduled_results, scheduled_ledger, scheduled_proofs, scheduled_audit = execute_paid_schedule(
        "live", caps, models, fake_paid_launcher
    )
    if validate_strata(scheduled_results) is not None or len(scheduled_proofs) != 24 or len(scheduled_audit) != 24:
        fail("resource scheduler integration failed")
    with tempfile.TemporaryDirectory(prefix="generation-test-", dir=str(receipt_test_root)) as generation_temp:
        generation_target = Path(generation_temp) / "generation"
        generation_digest = finalize_generation_directory(
            generation_target,
            "live",
            models,
            full_command,
            full_receipt,
            {"nonce": full_receipt["nonce"], "consumed_at": observed_at},
            scheduled_results,
            scheduled_ledger,
            scheduled_proofs,
            scheduled_audit,
        )
        if not re.fullmatch(r"[0-9a-f]{64}", generation_digest):
            fail("resource generation digest missing")
        if verify_complete_generation(generation_target) is not None:
            fail("resource complete generation verification failed")
        if verify_complete_generation(generation_target) is not None:
            fail("resource generation restart verification failed")
        results_bytes = (generation_target / "results.json").read_bytes()
        (generation_target / "results.json").write_bytes(results_bytes + b"\n")
        if verify_complete_generation(generation_target) != "generation-complete-artifact":
            fail("resource generation artifact drift accepted")
        (generation_target / "results.json").write_bytes(results_bytes)
        partial_target = Path(generation_temp) / "partial-generation"
        partial_target.mkdir()
        write_json_atomic(partial_target / "manifest.json", {"schema": "partial"}, partial_target)
        if verify_complete_generation(partial_target) != "generation-complete-missing":
            fail("resource incomplete generation accepted")

    with tempfile.TemporaryDirectory(prefix="paid-entry-test-", dir=str(receipt_test_root)) as paid_temp:
        paid_root = Path(paid_temp)
        prepared_path, prepared_digest, prepared_command, _ = prepare_pilot_approval(
            pilot[3:], paid_root, auth_brokers, source_identity
        )
        if prepared_digest != pilot_approval_sha256 or prepared_command != shlex.join(pilot):
            fail("resource pilot approval preparation mismatch")
        pilot_entry_receipt = {
            **receipt,
            "nonce": "2" * 32,
            "approval_packet_sha256": prepared_digest,
        }
        write_json_atomic(paid_root / "live-pilot-receipt.json", pilot_entry_receipt, paid_root)
        pilot_entry_approval = prepared_path
        pilot_entry = run_paid_mode_entry(
            "live-pilot",
            pilot[3:],
            fake_paid_launcher,
            paid_root,
            auth_brokers,
            source_identity,
            lambda: source_identity,
            pilot_approval_sha256,
            lambda: hashlib.sha256(pilot_entry_approval.read_bytes()).hexdigest(),
            session_marker,
            session_started,
            observed_at,
        )
        if len(pilot_entry["results"]) != 2 or not pilot_entry["full_command"]:
            fail("resource paid pilot entry integration failed")
        if pilot_entry["full_command"] == shlex.join(full_run_command(pilot_caps, models)):
            fail("resource pilot limits were not derived from evidence")
        approval_packet_path = Path(pilot_entry["generation_path"]) / "full-run-approval.json"
        approval_packet = json.loads(read_bounded_file(approval_packet_path, approval_packet_path.parent, 1048576))
        if approval_packet.get("command") != pilot_entry["full_command"]:
            fail("resource full-run approval packet mismatch")

        def missing_telemetry_launcher(call_spec):
            if call_spec["harness"] == "codex":
                return fake_paid_launcher(call_spec)
            last_proof = None
            for turn in range(1, 4):
                turn_id = f"{call_spec['call_id']}:turn-{turn}"
                call_spec["before_invocation"](turn_id, 0)
                raw_proof = managed_process(
                    [sys.executable, "-c", "raise SystemExit(0)"],
                    2,
                    table_reader=empty_process_table,
                )
                last_proof = {
                    "leader_waited": raw_proof["reaped"],
                    "pgid_absent": raw_proof["process_group_reaped"],
                    "descendants_absent": raw_proof["descendants_absent"],
                    "observed_escape_detected": not raw_proof["descendants_absent"],
                }
                call_spec["after_invocation"](turn_id, last_proof, None, None, 0)
            return {
                "infrastructure_status": "pass",
                "verdict": "conformant",
                "observed_cost": None,
                "observed_tokens": None,
                "turns": 3,
                "elapsed_seconds": 0.1,
                "process_proof": last_proof,
                "command_audit": {"invocation_id": call_spec["call_id"], "harness": "claude", "turns": 3},
            }

        missing_results, missing_ledger, _, _ = execute_paid_schedule(
            "live-pilot", pilot_caps, models, missing_telemetry_launcher
        )
        missing_caps = derive_full_run_caps(pilot_caps, missing_results, missing_ledger)
        if missing_caps["claude_total_budget_usd"] != "18.00":
            fail("resource missing-telemetry multi-turn budget mismatch")
        try:
            run_paid_mode_entry(
                "live-pilot",
                pilot[3:],
                fake_paid_launcher,
                paid_root,
                auth_brokers,
                source_identity,
                lambda: source_identity,
                pilot_approval_sha256,
                lambda: hashlib.sha256(pilot_entry_approval.read_bytes()).hexdigest(),
                session_marker,
                session_started,
                observed_at,
            )
        except ValueError as exc:
            if "paid-receipt-reused" not in str(exc):
                fail(f"resource paid entry reuse diagnostic mismatch: {exc}")
        else:
            fail("resource paid pilot entry reused receipt")
        generated_approval = Path(pilot_entry["generation_path"]) / "full-run-approval.json"
        generated_approval_digest = hashlib.sha256(generated_approval.read_bytes()).hexdigest()
        mutant_generation = paid_root / "mutant-pilot-generation"
        shutil.copytree(Path(pilot_entry["generation_path"]), mutant_generation)
        mutant_packet_path = mutant_generation / "full-run-approval.json"
        mutant_packet = json.loads(mutant_packet_path.read_text(encoding="utf-8"))
        mutant_packet["pilot_evidence"] = {"results_sha256": "0" * 64, "settlement_sha256": "0" * 64}
        write_json_atomic(mutant_packet_path, mutant_packet, mutant_generation)
        mutant_manifest_path = mutant_generation / "manifest.json"
        mutant_manifest = json.loads(mutant_manifest_path.read_text(encoding="utf-8"))
        mutant_manifest["full_run_approval_sha256"] = hashlib.sha256(mutant_packet_path.read_bytes()).hexdigest()
        write_json_atomic(mutant_manifest_path, mutant_manifest, mutant_generation)
        write_json_atomic(
            mutant_generation / "complete.json",
            {
                "schema": "release-loop-generation-complete/v1",
                "manifest_sha256": hashlib.sha256(mutant_manifest_path.read_bytes()).hexdigest(),
            },
            mutant_generation,
        )
        if verify_complete_generation(mutant_generation) is not None:
            fail("resource rebuilt mutant generation setup failed")
        try:
            install_full_approval(
                [
                    "--generation", str(mutant_generation),
                    "--approved-sha256", hashlib.sha256(mutant_packet_path.read_bytes()).hexdigest(),
                ],
                paid_root,
                auth_brokers,
                source_identity,
            )
        except ValueError as exc:
            if "full approval pilot evidence mismatch" not in str(exc):
                fail(f"resource pilot evidence diagnostic mismatch: {exc}")
        else:
            fail("resource arbitrary pilot evidence accepted")

        def rebuild_generation_commit(generation_path):
            manifest_path = generation_path / "manifest.json"
            manifest_value = json.loads(manifest_path.read_text(encoding="utf-8"))
            manifest_value["results_sha256"] = hashlib.sha256((generation_path / "results.json").read_bytes()).hexdigest()
            manifest_value["full_run_approval_sha256"] = hashlib.sha256(
                (generation_path / "full-run-approval.json").read_bytes()
            ).hexdigest()
            write_json_atomic(manifest_path, manifest_value, generation_path)
            write_json_atomic(
                generation_path / "complete.json",
                {
                    "schema": "release-loop-generation-complete/v1",
                    "manifest_sha256": hashlib.sha256(manifest_path.read_bytes()).hexdigest(),
                },
                generation_path,
            )

        failed_generation = paid_root / "failed-pilot-generation"
        shutil.copytree(Path(pilot_entry["generation_path"]), failed_generation)
        failed_results_path = failed_generation / "results.json"
        failed_results = json.loads(failed_results_path.read_text(encoding="utf-8"))
        failed_results[0]["infrastructure_status"] = "failed"
        failed_results[0]["verdict"] = "unknown"
        write_json_atomic(failed_results_path, failed_results, failed_generation)
        failed_packet_path = failed_generation / "full-run-approval.json"
        failed_packet = json.loads(failed_packet_path.read_text(encoding="utf-8"))
        failed_packet["pilot_evidence"]["results_sha256"] = object_digest(failed_results)
        write_json_atomic(failed_packet_path, failed_packet, failed_generation)
        rebuild_generation_commit(failed_generation)
        try:
            install_full_approval(
                [
                    "--generation", str(failed_generation),
                    "--approved-sha256", hashlib.sha256(failed_packet_path.read_bytes()).hexdigest(),
                ],
                paid_root,
                auth_brokers,
                source_identity,
            )
        except ValueError as exc:
            if "pilot-infrastructure-failure" not in str(exc):
                fail(f"resource failed pilot install diagnostic mismatch: {exc}")
        else:
            fail("resource failed pilot approval installed")

        unrelated_generation = paid_root / "unrelated-command-generation"
        shutil.copytree(Path(pilot_entry["generation_path"]), unrelated_generation)
        unrelated_packet_path = unrelated_generation / "full-run-approval.json"
        unrelated_packet = json.loads(unrelated_packet_path.read_text(encoding="utf-8"))
        unrelated_caps = {**unrelated_packet["caps"], "max_turns_per_session": unrelated_packet["caps"]["max_turns_per_session"] + 1}
        unrelated_command = full_run_command(unrelated_caps, models)
        unrelated_packet["caps"] = unrelated_caps
        unrelated_packet["command"] = shlex.join(unrelated_command)
        unrelated_packet["command_sha256"] = paid_command_digest(unrelated_command)
        write_json_atomic(unrelated_packet_path, unrelated_packet, unrelated_generation)
        rebuild_generation_commit(unrelated_generation)
        try:
            install_full_approval(
                [
                    "--generation", str(unrelated_generation),
                    "--approved-sha256", hashlib.sha256(unrelated_packet_path.read_bytes()).hexdigest(),
                ],
                paid_root,
                auth_brokers,
                source_identity,
            )
        except ValueError as exc:
            if "full approval command not pilot-derived" not in str(exc):
                fail(f"resource unrelated full command diagnostic mismatch: {exc}")
        else:
            fail("resource unrelated full command installed")
        full_entry_approval, installed_digest, installed_command, installed_packet = install_full_approval(
            ["--generation", pilot_entry["generation_path"], "--approved-sha256", generated_approval_digest],
            paid_root,
            auth_brokers,
            source_identity,
        )
        if installed_digest != generated_approval_digest or installed_command != pilot_entry["full_command"]:
            fail("resource full approval installation mismatch")
        installed_command_array = shlex.split(installed_command)
        installed_caps = installed_packet["caps"]
        full_entry_receipt = {
            **receipt,
            "gate_kind": "live",
            "command_sha256": paid_command_digest(installed_command_array),
            "caps": installed_caps,
            "approval_packet_sha256": installed_digest,
            "nonce": "3" * 32,
        }
        write_json_atomic(paid_root / "live-receipt.json", full_entry_receipt, paid_root)
        full_entry = run_paid_mode_entry(
            "live",
            installed_command_array[3:],
            fake_paid_launcher,
            paid_root,
            auth_brokers,
            source_identity,
            lambda: source_identity,
            installed_digest,
            lambda: hashlib.sha256(full_entry_approval.read_bytes()).hexdigest(),
            session_marker,
            session_started,
            observed_at,
        )
        if len(full_entry["results"]) != 24 or full_entry["full_command"] is not None:
            fail("resource paid full entry integration failed")

    negatives = 0
    def unavailable_process_table(_root_pid):
        fail("process-table-unavailable")

    try:
        managed_process(
            [sys.executable, "-c", "import time; time.sleep(5)"],
            1,
            table_reader=unavailable_process_table,
        )
    except ValueError as exc:
        if "process-table-unavailable" not in str(exc):
            fail(f"resource process-table diagnostic mismatch: {exc}")
    else:
        fail("resource unavailable process table accepted")
    negatives += 1
    if validate_paid_receipt(
        None, pilot, "live-pilot", models, pilot_caps, auth_brokers, source_identity, pilot_approval_sha256, session_marker, session_started, observed_at, used_nonces
    ) != "paid-receipt-shape":
        fail("resource missing receipt accepted")
    negatives += 1
    for label, mutant, expected in (
        ("stale", {**receipt, "approved_at": "2026-08-24T05:59:59Z", "nonce": "c" * 32}, "paid-receipt-stale"),
        ("command", {**receipt, "command_sha256": "0" * 64, "nonce": "d" * 32}, "paid-receipt-command"),
        ("session", {**receipt, "session_marker": "other", "nonce": "e" * 32}, "paid-receipt-session"),
        ("models", {**receipt, "models": {"claude": "other", "codex": models["codex"]}, "nonce": "f" * 32}, "paid-receipt-models"),
        ("caps", {**receipt, "caps": {**caps, "max_turns_per_session": 5}, "nonce": "1" * 32}, "paid-receipt-caps"),
        ("broker", {**receipt, "auth_brokers": {"claude": "0" * 64, "codex": auth_brokers["codex"]}, "nonce": "5" * 32}, "paid-receipt-auth-brokers"),
        ("source", {**receipt, "source_identity": {**source_identity, "head_sha": "0" * 40}, "nonce": "6" * 32}, "paid-receipt-source"),
        ("approval", {**receipt, "approval_packet_sha256": "0" * 64, "nonce": "8" * 32}, "paid-receipt-approval-packet"),
    ):
        actual = validate_paid_receipt(
            mutant, pilot, "live-pilot", models, pilot_caps, auth_brokers, source_identity, pilot_approval_sha256, session_marker, session_started, observed_at, used_nonces
        )
        if actual != expected:
            fail(f"resource receipt mutant mismatch: {label}")
        negatives += 1
    if consume_paid_receipt(receipt, used_nonces)[1] != "paid-receipt-reused":
        fail("resource reused receipt accepted")
    negatives += 1
    overlap = new_resource_ledger(caps)
    reserve_claude(overlap, caps, "one")
    if reserve_claude(overlap, caps, "two") != "claude-reservation-overlap":
        fail("resource overlapping Claude call accepted")
    negatives += 1
    exhausted = new_resource_ledger(caps)
    exhausted["claude_remaining"] = Decimal("0")
    if reserve_claude(exhausted, caps, "exhausted") != "claude-budget-exhausted":
        fail("resource exhausted Claude budget accepted")
    negatives += 1
    missing_telemetry = new_resource_ledger(caps)
    reserve_claude(missing_telemetry, caps, "missing")
    settle_claude(missing_telemetry, "missing", None)
    if missing_telemetry["claude_spent"] != Decimal(caps["claude_max_invocation_usd"]):
        fail("resource missing telemetry did not consume reservation")
    eligibility = current_adapter_eligibility()
    if eligibility != {
        "schema": "release-loop-adapter-eligibility/v1",
        "adapter": "claude-cli",
        "eligible": False,
        "failure": "claude-hard-budget-unavailable",
    }:
        fail("resource current adapter eligibility mismatch")
    try:
        require_current_adapter_eligibility()
    except ValueError as exc:
        if "claude-hard-budget-unavailable" not in str(exc):
            fail(f"resource adapter eligibility diagnostic mismatch: {exc}")
    else:
        fail("resource ineligible Claude adapter accepted")
    v1_eligibility_literal = (
        "Before every V1 preparation or resume, require the runner's closed `adapter_eligibility` result "
        "before reading or mutating an approval packet, receipt, nonce, or generation."
    )
    if (root / "skills/release-loop/SKILL.md").read_text(encoding="utf-8").count(v1_eligibility_literal) != 1:
        fail("resource V1 adapter eligibility source contract missing")
    with tempfile.TemporaryDirectory(prefix="eligibility-proof-", dir=str(root / ".release-loop/evidence/U6")) as proof_temp:
        proof_root = Path(proof_temp)
        component_paths = {}
        for component in ("adapter", "enforcer", "verifier"):
            component_path = proof_root / component
            component_path.write_text(component + "\n", encoding="utf-8")
            component_paths[component] = component_path
        proof_path = proof_root / "proof.json"
        proof_path.write_text('{"hard_cap":true}\n', encoding="utf-8")
        eligibility_proof = {
            "schema": "release-loop-adapter-eligibility-proof/v1",
            "eligible": True,
            "adapter": {
                "identity": "fixture-adapter",
                "version": "1",
                "sha256": hashlib.sha256(component_paths["adapter"].read_bytes()).hexdigest(),
            },
            "enforcer": {
                "identity": "fixture-enforcer",
                "version": "1",
                "sha256": hashlib.sha256(component_paths["enforcer"].read_bytes()).hexdigest(),
            },
            "verifier": {
                "identity": "release-loop-hard-budget-verifier/v1",
                "version": "1",
                "sha256": hashlib.sha256(component_paths["verifier"].read_bytes()).hexdigest(),
            },
            "mechanism": "fixture-hard-stop",
            "proof_sha256": hashlib.sha256(proof_path.read_bytes()).hexdigest(),
        }
        if (
            validate_adapter_eligibility_proof(eligibility_proof, component_paths, proof_path)
            != "adapter-eligibility-proof-untrusted"
        ):
            fail("resource ungoverned adapter eligibility proof accepted")
        if not re.fullmatch(r"[0-9a-f]{64}", adapter_eligibility_proof_digest(eligibility_proof)):
            fail("resource adapter eligibility proof digest mismatch")
        proof_mutations = []
        for component in ("adapter", "enforcer", "verifier"):
            for field in ("identity", "version", "sha256"):
                mutant = copy.deepcopy(eligibility_proof)
                mutant[component][field] = "0" * 64 if field == "sha256" else ""
                proof_mutations.append((f"{component}-{field}", mutant))
        for field, value in (
            ("schema", "unknown"),
            ("eligible", False),
            ("mechanism", ""),
            ("proof_sha256", "0" * 64),
        ):
            mutant = copy.deepcopy(eligibility_proof)
            mutant[field] = value
            proof_mutations.append((field, mutant))
        for label, mutant in proof_mutations:
            if validate_adapter_eligibility_proof(mutant, component_paths, proof_path) is None:
                fail(f"resource adapter eligibility proof mutant accepted: {label}")
        component_paths["adapter"].write_text("changed\n", encoding="utf-8")
        if validate_adapter_eligibility_proof(eligibility_proof, component_paths, proof_path) is None:
            fail("resource adapter eligibility launch-time mutation accepted")
    accounting_fixture_root = Path("/private/tmp/fixture root").resolve()
    accounting_host_home = Path("/Users/fixture-user").resolve()
    accounting_stdout = json.dumps({
        "type": "result",
        "subtype": "error_max_budget_usd",
        "total_cost_usd": 1.51532725,
    }) + "\n"
    accounting_stderr = (
        "Ignoring 5 permissions.allow entries from .claude/settings.json: this workspace has not been trusted. "
        "Run Claude Code interactively here once and accept the trust dialog, or set "
        f"projects[\"{accounting_fixture_root}\"].hasTrustDialogAccepted: true in "
        f"{accounting_host_home}/.claude.json.\n"
    )
    accounting = extract_claude_accounting(
        accounting_stdout,
        accounting_stderr,
        accounting_fixture_root,
        accounting_host_home,
    )
    if accounting != {
        "reported_actual": "1.51532725",
        "result_subtype": "error_max_budget_usd",
        "trust_warning": "workspace-untrusted-project-allows-ignored",
    }:
        fail("resource Claude accounting evidence mismatch")
    duplicate_non_overrun = (
        json.dumps({"type": "result", "subtype": "success", "total_cost_usd": 0.1}) + "\n"
        + json.dumps({"type": "result", "subtype": "success", "total_cost_usd": 0.2}) + "\n"
    )
    try:
        extract_claude_accounting(
            duplicate_non_overrun,
            "",
            accounting_fixture_root,
            accounting_host_home,
        )
    except ValueError as exc:
        if "claude-terminal-result-duplicate" not in str(exc):
            fail(f"resource Claude duplicate result diagnostic mismatch: {exc}")
    else:
        fail("resource Claude duplicate result accepted")
    overrun_with_duplicate = accounting_stdout + json.dumps({
        "type": "result", "subtype": "success", "total_cost_usd": 0.1,
    }) + "\n"
    if extract_claude_accounting(
        overrun_with_duplicate,
        accounting_stderr,
        accounting_fixture_root,
        accounting_host_home,
    ) != accounting:
        fail("resource Claude duplicate overrun lost primary failure")
    malformed_warning_accounting = extract_claude_accounting(
        accounting_stdout,
        accounting_stderr.rstrip() + " changed\n",
        accounting_fixture_root,
        accounting_host_home,
    )
    if (
        malformed_warning_accounting.get("reported_actual") != accounting["reported_actual"]
        or malformed_warning_accounting.get("result_subtype") != "error_max_budget_usd"
        or malformed_warning_accounting.get("trust_warning") is not None
    ):
        fail("resource Claude malformed trust warning masked overrun")
    overrun_caps = {**caps, "claude_total_budget_usd": "4.50", "claude_max_invocation_usd": "1.50"}
    overrun_ledger = new_resource_ledger(overrun_caps)
    overrun_ledger["claude_spent"] = Decimal("0.50")
    overrun_ledger["claude_remaining"] = Decimal("4.00")
    reserve_claude(overrun_ledger, overrun_caps, "overrun")
    overrun_ledger["active_process"] = {"invocation_id": "overrun", "status": "launch-intent"}
    overrun = close_claude_overrun(overrun_ledger, "overrun", accounting)
    if overrun != {
        "call_id": "overrun",
        "reserved": "1.50",
        "reported_actual": "1.51532725",
        "difference": "0.01532725",
        "total_before": "4.00",
        "raw_remaining": "2.48467275",
        "remaining_after": "2.48467275",
        "result_subtype": "error_max_budget_usd",
        "trust_warning": "workspace-untrusted-project-allows-ignored",
        "retryable": False,
        "budget_frozen": True,
    }:
        fail("resource Claude overrun record mismatch")
    if (
        overrun_ledger["claude_spent"] != Decimal("2.01532725")
        or overrun_ledger["claude_remaining"] != Decimal("2.48467275")
        or overrun_ledger["claude_active"] is not None
        or overrun_ledger["active_process"] is not None
        or overrun_ledger["overrun"] != overrun
    ):
        fail("resource Claude overrun ledger mismatch")
    authority_paths = (
        root / ".release-loop/evidence/live-pilot-approval.json",
        root / ".release-loop/evidence/live-pilot-receipt.json",
        root / ".release-loop/evidence/live-approval.json",
        root / ".release-loop/evidence/live-receipt.json",
        root / ".release-loop/evidence/paid-nonces.json",
    )
    authority_before = {path: path.read_bytes() if path.is_file() else None for path in authority_paths}
    for paid_mode in ("prepare-pilot", "install-full-approval", "live-pilot", "live"):
        rejected = run_bounded(
            ["bash", str(root / "scripts/test-release-loop-conformance.sh"), paid_mode],
            root,
            {"PATH": "/usr/bin:/bin", "LC_ALL": "C", "LANG": "C"},
            timeout=20,
        )
        if rejected.returncode == 0 or "claude-hard-budget-unavailable" not in rejected.stderr:
            fail(f"resource paid eligibility entrypoint mismatch: {paid_mode}")
    authority_after = {path: path.read_bytes() if path.is_file() else None for path in authority_paths}
    if authority_after != authority_before:
        fail("resource paid eligibility rejection mutated authority")
    with tempfile.TemporaryDirectory(prefix="overrun-state-", dir=str(root / ".release-loop/evidence/U6")) as state_temp:
        state_root = Path(state_temp)
        state_path = state_root / "state.json"

        def overrun_launcher(call_spec):
            turn_id = f"{call_spec['call_id']}:turn-1"
            call_spec["before_invocation"](turn_id, 0)
            raw_proof = managed_process(
                [sys.executable, "-c", "raise SystemExit(0)"],
                2,
                table_reader=empty_process_table,
            )
            proof = {
                "leader_waited": raw_proof["reaped"],
                "pgid_absent": raw_proof["process_group_reaped"],
                "descendants_absent": raw_proof["descendants_absent"],
                "observed_escape_detected": not raw_proof["descendants_absent"],
            }
            call_spec["after_invocation"](
                turn_id,
                proof,
                accounting["reported_actual"],
                0,
                0,
                accounting,
            )
            fail("resource overrun launcher continued")

        try:
            execute_paid_schedule(
                "live-pilot",
                overrun_caps,
                models,
                overrun_launcher,
                state_path=state_path,
                state_root=state_root,
            )
        except ValueError as exc:
            if "claude-hard-budget-overrun" not in str(exc):
                fail(f"resource overrun scheduler diagnostic mismatch: {exc}")
        else:
            fail("resource overrun scheduler accepted")
        overrun_state = json.loads(read_bounded_file(state_path, state_root, 1048576))
        if (
            overrun_state.get("status") != "failed"
            or overrun_state.get("failure") != "claude-hard-budget-overrun"
            or overrun_state.get("resource_ledger", {}).get("overrun", {}).get("retryable") is not False
            or overrun_state.get("resource_ledger", {}).get("budget_frozen") is not True
        ):
            fail("resource overrun state mismatch")
        frozen_state = state_path.read_bytes()
        try:
            execute_paid_schedule(
                "live-pilot",
                overrun_caps,
                models,
                overrun_launcher,
                state_path=state_path,
                state_root=state_root,
            )
        except ValueError as exc:
            if "orphan-process-state" not in str(exc):
                fail(f"resource overrun restart diagnostic mismatch: {exc}")
        else:
            fail("resource overrun restart accepted")
        if state_path.read_bytes() != frozen_state:
            fail("resource overrun restart mutated terminal state")
        retry_state_path = state_root / "retry-state.json"
        injected = {"failed": False}

        def fail_first_overrun_write(path, value, allowed_root):
            if (
                value.get("status") == "failed"
                and value.get("failure") == "claude-hard-budget-overrun"
                and not injected["failed"]
            ):
                injected["failed"] = True
                raise OSError("injected overrun state write failure")
            write_json_atomic(path, value, allowed_root)

        try:
            execute_paid_schedule(
                "live-pilot",
                overrun_caps,
                models,
                overrun_launcher,
                state_path=retry_state_path,
                state_root=state_root,
                state_writer=fail_first_overrun_write,
            )
        except ValueError as exc:
            if "claude-hard-budget-overrun" not in str(exc):
                fail(f"resource overrun write retry diagnostic mismatch: {exc}")
        else:
            fail("resource overrun write retry accepted")
        retried_state = json.loads(read_bounded_file(retry_state_path, state_root, 1048576))
        if (
            not injected["failed"]
            or retried_state.get("failure") != "claude-hard-budget-overrun"
            or retried_state.get("resource_ledger", {}).get("budget_frozen") is not True
        ):
            fail("resource overrun write retry state mismatch")
    codex_cap = new_resource_ledger(caps)
    if record_codex_usage(codex_cap, caps, "too-many", caps["codex_observed_token_cap"] + 1) != "codex-token-cap-exhausted":
        fail("resource Codex token overflow accepted")
    negatives += 1
    scheduler_mutants = (
        ("orphan", {"active_process": {"pid": 9}}, "claude", 1, 0, 0, 0, None, "process-still-active"),
        ("turns", {}, "codex", caps["max_turns_per_session"] + 1, 0, 0, 0, None, "turn-cap-exhausted"),
        ("session", {}, "codex", 1, caps["session_timeout"] + 1, 0, 0, None, "session-timeout-exhausted"),
        ("wall", {}, "codex", 1, 0, caps["total_wall_time"] + 1, 0, None, "total-wall-time-exhausted"),
        ("retry", {}, "codex", 1, 0, 0, 1, "infrastructure", "infrastructure-retry-cap"),
        ("conformance-retry", {}, "codex", 1, 0, 0, 1, "conformance", "conformance-retry-forbidden"),
        ("concurrency", {"active_codex": caps["max_concurrency"]}, "codex", 1, 0, 0, 0, None, "codex-concurrency-cap"),
    )
    for label, updates, harness, turns, session_elapsed, total_elapsed, retry_count, prior_failure, expected in scheduler_mutants:
        scheduler_ledger = new_resource_ledger(caps)
        scheduler_ledger.update(updates)
        actual = invocation_start_invariant(
            scheduler_ledger,
            caps,
            harness,
            turns,
            session_elapsed,
            total_elapsed,
            retry_count,
            prior_failure,
        )
        if actual != expected:
            fail(f"resource scheduler mutant mismatch: {label}")
        negatives += 1
    for label, mutate, expected in (
        ("incomplete", lambda value: value.pop(), "live-strata-incomplete"),
        ("infrastructure", lambda value: value[0].__setitem__("infrastructure_status", "failed"), "live-infrastructure-failure"),
        ("conformance", lambda value: value[0].__setitem__("verdict", "nonconformant"), "live-conformance-failure"),
        ("unknown", lambda value: value[0].__setitem__("verdict", "unknown"), "live-verdict-unknown"),
    ):
        mutant_results = copy.deepcopy(results)
        mutate(mutant_results)
        if validate_strata(mutant_results) != expected:
            fail(f"resource result mutant mismatch: {label}")
        negatives += 1
    manifest_mutant = copy.deepcopy(manifest)
    manifest_mutant.pop("results_sha256")
    if validate_generation_manifest(manifest_mutant) != "generation-manifest-shape":
        fail("resource manifest mutant accepted")
    negatives += 1

    def failed_pilot_launcher(call_spec):
        outcome = fake_paid_launcher(call_spec)
        outcome["infrastructure_status"] = "failed"
        outcome["verdict"] = "unknown"
        return outcome

    def nonconformant_pilot_launcher(call_spec):
        outcome = fake_paid_launcher(call_spec)
        outcome["verdict"] = "nonconformant"
        return outcome

    with tempfile.TemporaryDirectory(prefix="failed-paid-state-", dir=str(receipt_test_root)) as failed_temp:
        failed_root = Path(failed_temp)
        for launcher, diagnostic in (
            (failed_pilot_launcher, "pilot-infrastructure-failure"),
            (nonconformant_pilot_launcher, "pilot-conformance-failure"),
        ):
            failed_state = failed_root / f"{diagnostic}.json"
            try:
                execute_paid_schedule(
                    "live-pilot",
                    pilot_caps,
                    models,
                    launcher,
                    state_path=failed_state,
                    state_root=failed_root,
                )
            except ValueError as exc:
                if diagnostic not in str(exc):
                    fail(f"resource pilot failure diagnostic mismatch: {exc}")
            else:
                fail(f"resource pilot failure accepted: {diagnostic}")
            failed_value = json.loads(read_bounded_file(failed_state, failed_root, 1048576))
            if failed_value.get("status") != "failed" or failed_value.get("failure") != diagnostic:
                fail(f"resource pilot failure state mismatch: {diagnostic}")
            negatives += 1
        scheduler_failure_calls = {"start-cap": 0, "missing-proof": 0, "active-proof": 0, "callback-proof": 0}

        def no_proof_launcher(call_spec):
            scheduler_failure_calls["missing-proof"] += 1
            return {"command_audit": {}}

        def active_no_proof_launcher(call_spec):
            scheduler_failure_calls["active-proof"] += 1
            call_spec["before_invocation"](f"{call_spec['call_id']}:turn-1", 0)
            return {"command_audit": {}}

        def incomplete_callback_launcher(call_spec):
            scheduler_failure_calls["callback-proof"] += 1
            turn_id = f"{call_spec['call_id']}:turn-1"
            call_spec["before_invocation"](turn_id, 0)
            call_spec["after_invocation"](turn_id, {}, None, 0, 0)

        scheduler_failure_cases = (
            (
                "start-cap",
                {**pilot_caps, "total_wall_time": 1},
                lambda call_spec: scheduler_failure_calls.__setitem__(
                    "start-cap", scheduler_failure_calls["start-cap"] + 1
                ),
                "total-wall-time-exhausted",
                "failed",
                0,
                iter((0, 2)).__next__,
            ),
            (
                "missing-proof", pilot_caps, no_proof_launcher,
                "process-exit-proof-missing", "failed", 1, time.monotonic,
            ),
            (
                "active-proof",
                pilot_caps,
                active_no_proof_launcher,
                "process-exit-proof-missing",
                "failed-active-process",
                1,
                time.monotonic,
            ),
            (
                "callback-proof",
                pilot_caps,
                incomplete_callback_launcher,
                "process-exit-proof-incomplete",
                "failed-active-process",
                1,
                time.monotonic,
            ),
        )
        for label, failure_caps, launcher, diagnostic, expected_status, expected_calls, clock in scheduler_failure_cases:
            failed_state = failed_root / f"scheduler-{label}.json"
            try:
                execute_paid_schedule(
                    "live-pilot",
                    failure_caps,
                    models,
                    launcher,
                    state_path=failed_state,
                    state_root=failed_root,
                    clock=clock,
                )
            except ValueError as exc:
                if diagnostic not in str(exc):
                    fail(f"resource scheduler failure diagnostic mismatch: {label}: {exc}")
            else:
                fail(f"resource scheduler failure accepted: {label}")
            failed_value = json.loads(read_bounded_file(failed_state, failed_root, 1048576))
            if failed_value.get("status") != expected_status or failed_value.get("failure") != diagnostic:
                fail(f"resource scheduler failure state mismatch: {label}")
            if scheduler_failure_calls[label] != expected_calls:
                fail(f"resource scheduler launch count mismatch: {label}")
            negatives += 1
    with tempfile.TemporaryDirectory(prefix="live-gate-test-", dir=str(receipt_test_root)) as gate_temp:
        gate_path = Path(gate_temp) / "progress.md"
        expected_answer = {
            "gate_id": "design-approval",
            "phase": "design",
            "expected_answer_class": "approve-spec-or-request-revision",
            "answer": "approve",
        }
        valid_gate = (
            "---\nphase: design\nphase_status: waiting-user\nupdated: 2026-08-24T06:00:00Z\n"
            "pending_gate:\n  id: design-approval\n  issued_at: 2026-08-24T06:00:00Z\n"
            "  expected_answer_class: approve-spec-or-request-revision\n---\n\n## Log\n"
        )
        gate_path.write_text(valid_gate, encoding="utf-8")
        if progress_pending_gate(gate_path, expected_answer)[1] is not None:
            fail("resource valid live gate rejected")
        gate_path.write_text(valid_gate.replace("issued_at: 2026-08-24T06:00:00Z", "issued_at: malformed"), encoding="utf-8")
        if progress_pending_gate(gate_path, expected_answer)[1] != "pending-gate-stale":
            fail("resource malformed live gate accepted")
        gate_path.write_text(valid_gate.replace("issued_at: 2026-08-24T06:00:00Z", "issued_at: 2026-08-24T05:59:59Z"), encoding="utf-8")
        if progress_pending_gate(gate_path, expected_answer)[1] != "pending-gate-stale":
            fail("resource stale live gate accepted")
        negatives += 2
    return 24, negatives, process_controls, len(full_ledger["calls"]), pilot_entry["full_command"], manifest


gate_contracts = {
    "design-approval": ("design", "approve-spec-or-request-revision", "design_approved", {"approve", "revise"}),
    "ship-approval": ("ship", "merge-or-nonmerge-disposition", "ship_approved", {"merge", "nonmerge"}),
}


def parse_gate_timestamp(value):
    try:
        parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except (AttributeError, TypeError, ValueError):
        return None
    return parsed if parsed.tzinfo is not None else None


def pending_gate_invariant(state):
    pending = state.get("pending_gate")
    if pending is None:
        return "pending-gate-missing" if state.get("phase_status") == "waiting-user" else None
    gate_record_count = state.get("gate_record_count", 1)
    if not isinstance(gate_record_count, int) or gate_record_count < 1:
        return "pending-gate-record-count"
    if gate_record_count > 1:
        return "pending-gate-duplicate-record"
    if not isinstance(pending, dict) or set(pending) != {"id", "issued_at", "expected_answer_class"}:
        return "pending-gate-shape"
    gate_id = pending.get("id")
    if gate_id not in gate_contracts:
        return "pending-gate-unknown"
    phase, answer_class, approval_field, _ = gate_contracts[gate_id]
    if state.get("phase") != phase:
        return "pending-gate-phase"
    if pending.get("expected_answer_class") != answer_class:
        return "pending-gate-answer-class"
    if state.get("phase_status") != "waiting-user":
        return "pending-gate-status"
    timestamp = pending.get("issued_at")
    phase_entered = state.get("phase_entered_at")
    observed = state.get("observed_at")
    times = [parse_gate_timestamp(value) for value in (timestamp, phase_entered, observed)]
    if any(value is None for value in times):
        return "pending-gate-timestamp"
    issued_time, entered_time, observed_time = times
    if not entered_time <= issued_time <= observed_time:
        return "pending-gate-stale"
    approvals = state.get("approvals")
    if not isinstance(approvals, dict):
        return "pending-gate-approvals"
    if approval_field in approvals:
        return "pending-gate-already-approved"
    if state.get("gate_answer_receipt") is not None:
        return "pending-gate-answer-reserved"
    return None


def issue_pending_gate(phase, issued_at):
    gate_id = "design-approval" if phase == "design" else "ship-approval"
    expected_phase, answer_class, _, _ = gate_contracts[gate_id]
    if phase != expected_phase:
        fail("gate issue phase mismatch")
    return {
        "phase": phase,
        "phase_status": "waiting-user",
        "phase_entered_at": issued_at,
        "observed_at": issued_at,
        "pending_gate": {"id": gate_id, "issued_at": issued_at, "expected_answer_class": answer_class},
        "gate_record_count": 1,
        "approvals": {},
        "gate_answer_receipt": None,
        "gate_log": [{"event": "issued", "gate_id": gate_id, "at": issued_at}],
    }


def reserve_pending_answer(state, answer, reserved_at):
    invariant = pending_gate_invariant(state)
    if invariant is not None:
        return None, invariant
    gate_id = state["pending_gate"]["id"]
    _, _, _, answers = gate_contracts[gate_id]
    if answer not in answers:
        return None, "pending-gate-answer"
    issued_time = parse_gate_timestamp(state["pending_gate"]["issued_at"])
    reserved_time = parse_gate_timestamp(reserved_at)
    if issued_time is None or reserved_time is None or reserved_time < issued_time:
        return None, "pending-gate-answer-timestamp"
    reserved = copy.deepcopy(state)
    reserved["gate_answer_receipt"] = {
        "gate_id": gate_id,
        "gate_issued_at": state["pending_gate"]["issued_at"],
        "answer": answer,
        "reserved_at": reserved_at,
    }
    reserved.setdefault("gate_log", []).append(
        {"event": "answer-reserved", "gate_id": gate_id, "answer": answer, "at": reserved_at}
    )
    return reserved, None


def resolve_pending_gate(state, answered_at):
    pending = state.get("pending_gate")
    receipt = state.get("gate_answer_receipt")
    if not isinstance(pending, dict) or not isinstance(receipt, dict):
        return None, "pending-gate-answer-receipt"
    unreserved = copy.deepcopy(state)
    unreserved["gate_answer_receipt"] = None
    invariant = pending_gate_invariant(unreserved)
    if invariant is not None:
        return None, invariant
    gate_id = pending["id"]
    _, _, approval_field, answers = gate_contracts[gate_id]
    if set(receipt) != {"gate_id", "gate_issued_at", "answer", "reserved_at"}:
        return None, "pending-gate-answer-receipt"
    answer = receipt.get("answer")
    if receipt.get("gate_id") != gate_id or receipt.get("gate_issued_at") != pending.get("issued_at") or answer not in answers:
        return None, "pending-gate-answer-receipt"
    issued_time = parse_gate_timestamp(pending["issued_at"])
    reserved_time = parse_gate_timestamp(receipt["reserved_at"])
    answered_time = parse_gate_timestamp(answered_at)
    if None in {issued_time, reserved_time, answered_time} or not issued_time <= reserved_time <= answered_time:
        return None, "pending-gate-outcome-timestamp"
    resolved = copy.deepcopy(state)
    resolved["pending_gate"] = None
    resolved["gate_record_count"] = 0
    resolved["gate_answer_receipt"] = None
    resolved["phase_status"] = "in-progress"
    if answer in {"approve", "merge"}:
        resolved["approvals"][approval_field] = {"by": "user", "at": answered_at}
    resolved.setdefault("gate_log", []).append(
        {"event": "resolved", "gate_id": gate_id, "answer": answer, "at": answered_at}
    )
    return resolved, None


def resolved_gate_invariant(state, gate_id, answer):
    if state.get("pending_gate") is not None or state.get("gate_answer_receipt") is not None:
        return "pending-gate-outcome-clear"
    gate_log = state.get("gate_log")
    if not isinstance(gate_log, list) or len(gate_log) < 3:
        return "pending-gate-outcome-log"
    expected_events = ["issued", "answer-reserved", "resolved"]
    if [row.get("event") for row in gate_log[-3:]] != expected_events:
        return "pending-gate-outcome-log"
    outcome = gate_log[-1]
    if outcome.get("gate_id") != gate_id or outcome.get("answer") != answer or parse_gate_timestamp(outcome.get("at")) is None:
        return "pending-gate-outcome-log"
    return None


def grade_gate_fixture(mutation_id, fixture):
    if mutation_id == "unknown-pending-answer":
        return reserve_pending_answer(fixture, fixture["answer"], fixture["observed_at"])[1]
    if mutation_id == "nonmonotonic-pending-answer":
        issued = issue_pending_gate(fixture["phase"], fixture["issued_at"])
        return reserve_pending_answer(issued, fixture["answer"], fixture["reserved_at"])[1]
    if mutation_id in {"nonmonotonic-pending-outcome", "malformed-pending-outcome"}:
        issued = issue_pending_gate(fixture["phase"], fixture["issued_at"])
        reserved, invariant = reserve_pending_answer(issued, fixture["answer"], fixture["reserved_at"])
        if invariant is not None:
            return invariant
        return resolve_pending_gate(reserved, fixture["answered_at"])[1]
    if mutation_id == "missing-pending-outcome-log":
        issued = issue_pending_gate(fixture["phase"], fixture["issued_at"])
        reserved, invariant = reserve_pending_answer(issued, fixture["answer"], fixture["reserved_at"])
        if invariant is not None:
            return invariant
        resolved, invariant = resolve_pending_gate(reserved, fixture["answered_at"])
        if invariant is not None:
            return invariant
        resolved["gate_log"].pop()
        return resolved_gate_invariant(resolved, issued["pending_gate"]["id"], fixture["answer"])
    return pending_gate_invariant(fixture)


def transition_state_invariant(state):
    if state.get("review") == "clean" and state.get("next_phase") == "ship" and state.get("v1_status") != "accepted":
        return "v1-required-before-ship"
    if state.get("next_phase") == "done" and state.get("v2_status") != "accepted":
        return "v2-required-before-done"
    digests = state.get("generation_digests")
    if not isinstance(digests, list) or len(digests) != 4 or len(set(digests)) != 1:
        return "generation-chain-mismatch"
    if state.get("handoff_consumed") is True and state.get("v2_status") != "accepted":
        return "handoff-consumed-before-v2"
    return None


def validate_gate_group(mutation_rows):
    gate_rows = [row for row in mutation_rows if row.get("grader") == "pending-gate-state"]
    expected = {
        "missing-pending-gate": "pending-gate-missing",
        "unknown-pending-gate": "pending-gate-unknown",
        "already-approved-pending-gate": "pending-gate-already-approved",
        "unknown-pending-answer": "pending-gate-answer",
        "nonmonotonic-pending-answer": "pending-gate-answer-timestamp",
        "nonmonotonic-pending-outcome": "pending-gate-outcome-timestamp",
        "malformed-pending-outcome": "pending-gate-outcome-timestamp",
        "missing-pending-outcome-log": "pending-gate-outcome-log",
        "mismatched-pending-gate": "pending-gate-phase",
        "mismatched-pending-answer-class": "pending-gate-answer-class",
        "stale-pending-gate": "pending-gate-stale",
        "duplicate-pending-answer": "pending-gate-answer-reserved",
        "duplicate-pending-gate-record": "pending-gate-duplicate-record",
    }
    if {row["id"] for row in gate_rows} != set(expected):
        fail("pending gate mutation inventory mismatch")
    for row in gate_rows:
        actual = grade_gate_fixture(row["id"], row["fixture"])
        if actual != expected[row["id"]]:
            fail(f"pending gate mutation diagnostic mismatch: {row['id']}")
    controls = 0
    for phase, answers in (("design", ("approve", "revise")), ("ship", ("merge", "nonmerge"))):
        issued = issue_pending_gate(phase, "2026-08-24T04:00:00Z")
        if pending_gate_invariant(issued) is not None:
            fail(f"pending gate issue control failed: {phase}")
        controls += 1
        for answer in answers:
            reserved, invariant = reserve_pending_answer(issued, answer, "2026-08-24T04:00:01Z")
            if invariant is not None or pending_gate_invariant(reserved) != "pending-gate-answer-reserved":
                fail(f"pending gate reservation control failed: {phase}/{answer}")
            resolved, invariant = resolve_pending_gate(reserved, "2026-08-24T04:00:02Z")
            if (
                invariant is not None
                or resolved["pending_gate"] is not None
                or resolved["phase_status"] != "in-progress"
                or resolved_gate_invariant(resolved, issued["pending_gate"]["id"], answer) is not None
            ):
                fail(f"pending gate resolution control failed: {phase}/{answer}")
            controls += 1
    resume = issue_pending_gate("ship", "2026-08-24T04:00:00Z")
    resume["observed_at"] = "2026-08-24T04:01:00Z"
    if pending_gate_invariant(resume) is not None:
        fail("pending gate resume control failed")
    controls += 1
    reserved_resume, invariant = reserve_pending_answer(resume, "merge", "2026-08-24T04:00:01Z")
    if invariant is not None or pending_gate_invariant(reserved_resume) != "pending-gate-answer-reserved":
        fail("pending gate reserved resume control failed")
    controls += 1
    return len(gate_rows), controls


def grade_mutation(mutation, cases_by_id, clauses_by_id, disabled_graders=frozenset()):
    mutation_id = mutation["id"]
    case = cases_by_id[mutation["case_id"]]
    if mutation["grader"] in disabled_graders:
        return "infrastructure-error", mutation["grader"], "grader-disabled"
    if mutation_id == "delete-design-user-gate":
        clause = clauses_by_id["design-user-gate"]
        source = (root / clause["path"]).read_text(encoding="utf-8")
        mutated = source.replace(clause["text"], "", 1)
        rejected = clause["text"] not in mutated
        return ("expected-reject", "design-user-gate", "design-user-gate") if rejected else ("unexpected-pass", "design-user-gate", "none")
    if mutation_id == "replay-completed-phase":
        values = [event["value"] for event in case["events"]]
        mutated = values + [values[1]]
        rejected = len(mutated) != len(set(mutated))
        return ("expected-reject", "no-phase-replay", "no-phase-replay") if rejected else ("unexpected-pass", "no-phase-replay", "none")
    if mutation_id == "reenter-premerge-shipping":
        clause = clauses_by_id["resume-after-merge"]
        source = (root / clause["path"]).read_text(encoding="utf-8")
        mutated = source.replace("never re-enters pre-merge", "re-enters pre-merge", 1)
        rejected = clause["text"] not in mutated
        return ("expected-reject", "resume-after-merge", "resume-after-merge") if rejected else ("unexpected-pass", "resume-after-merge", "none")
    if mutation_id == "drop-work-without-subagents":
        values = [event["value"] for event in case["events"]]
        mutated = [value for value in values if value != "implement-degraded"]
        rejected = set(values) - set(mutated) == {"implement-degraded"}
        return ("expected-reject", "no-coverage-drop", "no-coverage-drop") if rejected else ("unexpected-pass", "no-coverage-drop", "none")
    fixture = mutation.get("fixture", {})
    if mutation["grader"] == "transition-state":
        invariant = transition_state_invariant(fixture)
        return ("expected-reject", "transition-state", invariant) if invariant else (
            "unexpected-pass", "transition-state", "none"
        )
    if mutation["grader"] == "pending-gate-state":
        invariant = grade_gate_fixture(mutation_id, fixture)
        return ("expected-reject", "pending-gate-state", invariant) if invariant else ("unexpected-pass", "pending-gate-state", "none")
    if mutation["grader"] == "sc2-comparison":
        invariant = sc2_invariant(fixture)
        if mutation_id == "controlled-same-kind-pairs":
            return ("pass", "sc2-comparison", "sc2-controlled-pairs") if invariant is None else ("unexpected-reject", "sc2-comparison", invariant)
        return ("expected-reject", "sc2-comparison", invariant) if invariant else ("unexpected-pass", "sc2-comparison", "none")
    if mutation["grader"] == "sc2-guard":
        pass_invariant = sc2_invariant(fixture.get("pass_fixture", {}))
        fail_invariant = sc2_invariant(fixture.get("fail_fixture", {}))
        discriminates = pass_invariant is None and fail_invariant is not None
        return ("expected-reject", "sc2-guard", "sc2-guard-discrimination") if discriminates else ("unexpected-pass", "sc2-guard", "none")
    if mutation_id == "contradictory-substitute-command":
        commands = operative_commands(fixture.get("document"))
        invalid = commands is not None and len(commands) > 1 and commands != [fixture.get("expected_command")]
        return ("expected-reject", "operative-section-parser", "parser-contradictory") if invalid else ("unexpected-pass", "operative-section-parser", "none")
    if mutation_id == "fence-relocation":
        commands = operative_commands(fixture.get("document"))
        invalid = commands is not None and fixture.get("expected_command") not in commands
        return ("expected-reject", "operative-section-parser", "parser-relocation") if invalid else ("unexpected-pass", "operative-section-parser", "none")
    fail(f"unknown mutation: {mutation_id}")


def validate_static(cases):
    mutations_path = data_root / "mutations.json"
    manifest_path = data_root / "source-manifest.json"
    policy_path = data_root / "baseline-policy.json"
    mutations = load_json(mutations_path)
    manifest = load_json(manifest_path)
    policy = load_json(policy_path)
    if mutations.get("schema") != "release-loop-mutations/v1":
        fail("unknown mutations schema")
    if manifest.get("schema") != "release-loop-source-manifest/v1":
        fail("unknown source manifest schema")
    if policy.get("schema") != "release-loop-baseline-policy/v1":
        fail("unknown baseline policy schema")
    policy_state = policy.get("state")
    roadmap = (root / "ROADMAP.md").read_text(encoding="utf-8")
    if policy_state == "bootstrap":
        if set(policy) != {
            "schema", "state", "approved_spec", "approved_spec_sha256", "source_generation", "roadmap_item"
        }:
            fail("bootstrap policy shape mismatch")
        if policy.get("approved_spec") != "docs/specs/2026-08-24-release-loop-conformance-fuzzing-design.md":
            fail("bootstrap spec path mismatch")
        if policy.get("roadmap_item") != "Conformance suite":
            fail("bootstrap ROADMAP item mismatch")
        spec_path = root / policy["approved_spec"]
        approved_spec_digest = "2cde033379b87d6c8eb92ea32ea3800a82625d86056da496343a91cf0bd8930b"
        if policy.get("approved_spec_sha256") != approved_spec_digest:
            fail("bootstrap policy spec digest mismatch")
        if hashlib.sha256(spec_path.read_bytes()).hexdigest() != approved_spec_digest:
            fail("bootstrap spec digest mismatch")
        if f"| {policy.get('roadmap_item')} |" not in roadmap:
            fail("bootstrap ROADMAP item missing")
    elif policy_state == "enforced":
        if set(policy) != {
            "schema", "state", "baseline", "baseline_sha256", "source_generation",
            "generation_manifest_sha256", "roadmap_item",
        }:
            fail("enforced policy shape mismatch")
        if policy.get("roadmap_item") != "Conformance suite" or "| Conformance suite |" in roadmap:
            fail("enforced ROADMAP state mismatch")
    else:
        fail("baseline policy state mismatch")

    clauses = manifest.get("clauses")
    if not isinstance(clauses, list) or not clauses:
        fail("source clauses missing")
    if manifest.get("digest_scope") != "heading-section":
        fail("source digest scope mismatch")
    clauses_by_id = {}
    sections_by_id = {}
    generation_rows = []
    for clause in clauses:
        clause_id = clause.get("id")
        if not clause_id or clause_id in clauses_by_id:
            fail("duplicate or missing clause ID")
        source_path = root / clause.get("path", "")
        source = source_path.read_text(encoding="utf-8")
        section = section_text(source, clause.get("heading", ""))
        digest = validate_source_section(clause, section)
        clauses_by_id[clause_id] = clause
        sections_by_id[clause_id] = section
        generation_rows.append(f"{clause_id}:{digest}")

    mutation_rows = mutations.get("mutations")
    if not isinstance(mutation_rows, list) or not mutation_rows:
        fail("mutation inventory missing")
    mutation_ids = [row.get("id") for row in mutation_rows]
    eligible = [mutation for case in cases for mutation in case["eligible_mutations"]]
    if mutation_ids != eligible:
        fail("mutation inventory does not match corpus eligibility")
    cases_by_id = {case["id"]: case for case in cases}
    expected_invariants = {
        "delete-design-user-gate": "design-user-gate",
        "replay-completed-phase": "no-phase-replay",
        "reenter-premerge-shipping": "resume-after-merge",
        "skip-v1-before-ship": "v1-required-before-ship",
        "skip-v2-before-done": "v2-required-before-done",
        "mismatched-generation-chain": "generation-chain-mismatch",
        "early-handoff-consumption": "handoff-consumed-before-v2",
        "drop-work-without-subagents": "no-coverage-drop",
        "missing-pending-gate": "pending-gate-missing",
        "unknown-pending-gate": "pending-gate-unknown",
        "already-approved-pending-gate": "pending-gate-already-approved",
        "unknown-pending-answer": "pending-gate-answer",
        "nonmonotonic-pending-answer": "pending-gate-answer-timestamp",
        "nonmonotonic-pending-outcome": "pending-gate-outcome-timestamp",
        "malformed-pending-outcome": "pending-gate-outcome-timestamp",
        "missing-pending-outcome-log": "pending-gate-outcome-log",
        "mismatched-pending-gate": "pending-gate-phase",
        "mismatched-pending-answer-class": "pending-gate-answer-class",
        "stale-pending-gate": "pending-gate-stale",
        "duplicate-pending-answer": "pending-gate-answer-reserved",
        "duplicate-pending-gate-record": "pending-gate-duplicate-record",
        "different-artifact-kind": "sc2-same-kind",
        "unstable-invariance-output": "sc2-invariance",
        "irrelevant-changed-axis": "sc2-axis",
        "metadata-only-difference": "sc2-effect-signal",
        "always-passing-guard": "sc2-guard-discrimination",
        "controlled-same-kind-pairs": "sc2-controlled-pairs",
        "contradictory-substitute-command": "parser-contradictory",
        "fence-relocation": "parser-relocation",
    }
    seen_graders = set()
    for mutation in mutation_rows:
        result, grader, invariant = grade_mutation(mutation, cases_by_id, clauses_by_id)
        if (
            result != mutation.get("expected")
            or grader != mutation.get("grader")
            or invariant != expected_invariants[mutation["id"]]
        ):
            fail(
                f"unexpected static result: {mutation.get('id')} "
                f"result={result} grader={grader} invariant={invariant}"
            )
        seen_graders.add(grader)
    required_static_graders = {
        grader
        for case in cases
        if case["kind"] == "static" or case["id"] in expected_live
        for grader in case["required_graders"]
        if grader in {row["grader"] for row in mutation_rows}
    }
    if seen_graders != required_static_graders:
        fail("static grader reachability mismatch")
    generation = hashlib.sha256(("\n".join(sorted(generation_rows)) + "\n").encode()).hexdigest()
    validate_source_generation(generation, policy.get("source_generation"), corpus.get("source_generation"))
    if policy_state == "enforced":
        baseline_path = root / policy.get("baseline", "")
        baseline = load_json(baseline_path)
        if baseline.get("schema") != "release-loop-baseline/v1":
            fail("enforced baseline schema mismatch")
        if set(baseline) != {
            "schema", "generation_manifest_sha256", "generation_tree_sha256", "source_generation",
            "corpus_sha256", "mutations_sha256", "handoff_manifest_sha256",
        }:
            fail("enforced baseline shape mismatch")
        if hashlib.sha256(baseline_path.read_bytes()).hexdigest() != policy.get("baseline_sha256"):
            fail("enforced baseline digest mismatch")
        if baseline.get("source_generation") != generation:
            fail("enforced baseline source generation mismatch")
        if baseline.get("generation_manifest_sha256") != policy.get("generation_manifest_sha256"):
            fail("enforced baseline generation mismatch")
        if baseline.get("corpus_sha256") != hashlib.sha256(corpus_path.read_bytes()).hexdigest():
            fail("enforced baseline corpus mismatch")
        if baseline.get("mutations_sha256") != hashlib.sha256(mutations_path.read_bytes()).hexdigest():
            fail("enforced baseline mutations mismatch")

    static_negative_probes = []
    unrelated = copy.deepcopy(next(row for row in mutation_rows if row["id"] == "different-artifact-kind"))
    for pair in unrelated["fixture"].values():
        if isinstance(pair, dict) and set(pair) == {"left", "right"}:
            pair["right"]["kind"] = pair["left"]["kind"]
    unrelated["fixture"]["invariance"]["right"]["comparison"] = {"digest": "unstable"}
    result, actual_grader, invariant = grade_mutation(unrelated, cases_by_id, clauses_by_id)
    if result == unrelated["expected"] and invariant == expected_invariants[unrelated["id"]]:
        fail("unrelated rejection probe was accepted")
    static_negative_probes.append("unrelated-rejection")
    unchanged_output = copy.deepcopy(
        next(row for row in mutation_rows if row["id"] == "controlled-same-kind-pairs")
    )
    unchanged_output["fixture"]["changed"]["right"]["comparison"] = copy.deepcopy(
        unchanged_output["fixture"]["changed"]["left"]["comparison"]
    )
    result, _, invariant = grade_mutation(unchanged_output, cases_by_id, clauses_by_id)
    if result == "pass" or invariant != "sc2-changed-output":
        fail("unchanged changed-axis output probe was accepted")
    static_negative_probes.append("changed-output")
    disabled_result = grade_mutation(
        next(row for row in mutation_rows if row["grader"] == "sc2-guard"),
        cases_by_id,
        clauses_by_id,
        {"sc2-guard"},
    )[0]
    if disabled_result != "infrastructure-error":
        fail("disabled grader probe was accepted")
    static_negative_probes.append("disabled-grader")
    parser_control = operative_commands(
        "## Operative commands\n\n```markdown\nRun: ignored-example\n```\n\nRun: canonical-command\n"
    )
    if parser_control != ["canonical-command"]:
        fail("operative parser control failed")
    static_negative_probes.append("parser-control")
    mutated_section = sections_by_id["design-user-gate"] + "\nDesign may be auto-skipped."
    try:
        validate_source_section(clauses_by_id["design-user-gate"], mutated_section)
    except ValueError as exc:
        if "source clause digest drift" not in str(exc):
            fail(f"source generation drift diagnostic mismatch: {exc}")
    else:
        fail("source generation drift probe was accepted")
    static_negative_probes.append("source-generation-drift")
    corpus_mutant = copy.deepcopy(corpus)
    corpus_mutant["source_generation"] = "0" * 64
    try:
        validate_source_generation(generation, policy.get("source_generation"), corpus_mutant["source_generation"])
    except ValueError as exc:
        if "corpus source generation mismatch" not in str(exc):
            fail(f"corpus generation drift diagnostic mismatch: {exc}")
    else:
        fail("corpus generation drift probe was accepted")
    static_negative_probes.append("corpus-generation-drift")
    policy_mutant = copy.deepcopy(policy)
    policy_mutant["source_generation"] = "0" * 64
    try:
        validate_source_generation(generation, policy_mutant["source_generation"], corpus.get("source_generation"))
    except ValueError as exc:
        if "bootstrap source generation mismatch" not in str(exc):
            fail(f"policy generation drift diagnostic mismatch: {exc}")
    else:
        fail("policy generation drift probe was accepted")
    static_negative_probes.append("policy-generation-drift")
    return len(mutation_rows), len(seen_graders), generation, len(static_negative_probes)


corpus = load_json(corpus_path)
cases = validate_corpus(corpus)
validate_golden()

if mode in {"prepare-pilot", "install-full-approval", "live-pilot", "live"}:
    require_current_adapter_eligibility()

if mode == "fixture":
    fixture_gh_calls, fixture_forbidden, fixture_policies, fixture_audit_rows = validate_fixture()
if mode == "gate":
    progress_contract = (root / "skills/release-loop/references/progress-schema.md").read_text(encoding="utf-8")
    if "pending_gate:" not in progress_contract:
        fail("pending_gate is undefined")
    gate_source_literals = {
        "skills/release-loop/SKILL.md": "Before answering a pending USER gate, require exactly one valid `pending_gate`",
        "skills/release-loop/references/progress-schema.md": "already-approved, or previously reserved state blocks without sending an answer",
        "skills/designing/SKILL.md": "pending_gate.id: design-approval",
        "skills/shipping/SKILL.md": "pending_gate.id: ship-approval",
    }
    for relative_path, literal in gate_source_literals.items():
        if (root / relative_path).read_text(encoding="utf-8").count(literal) != 1:
            fail(f"pending gate source contract mismatch: {relative_path}")
    gate_mutations, gate_controls = validate_gate_group(load_json(data_root / "mutations.json")["mutations"])
if mode == "preflight":
    preflight_adapters, preflight_calls, preflight_negatives, preflight_auth_events = validate_preflight()
if mode == "resource":
    (
        resource_sessions,
        resource_negatives,
        resource_process_controls,
        resource_calls,
        resource_full_command,
        resource_manifest,
    ) = validate_resource_group()
if mode == "transition":
    transition_controls, transition_negatives, transition_digest = validate_transition_group()
if mode == "handoff":
    handoff_path, handoff_digest, handoff_disposition = run_handoff_mode(mode_args)
if mode == "publish-baseline":
    baseline_digest, _ = run_publish_baseline_mode(mode_args)
if mode == "verify-archive":
    archive_digest = run_verify_archive_mode(mode_args)
if mode == "prepare-pilot":
    prepare_source = paid_source_preflight()
    prepare_auth = paid_auth_preflight()
    prepare_auth_digests = {harness: row["sha256"] for harness, row in prepare_auth.items()}
    prepare_path, prepare_digest, prepare_command, _ = prepare_pilot_approval(
        mode_args,
        root / ".release-loop/evidence",
        prepare_auth_digests,
        prepare_source["receipt"],
    )
if mode == "install-full-approval":
    install_source = paid_source_preflight()
    install_auth = paid_auth_preflight()
    install_auth_digests = {harness: row["sha256"] for harness, row in install_auth.items()}
    install_path, install_digest, install_command, _ = install_full_approval(
        mode_args,
        root / ".release-loop/evidence",
        install_auth_digests,
        install_source["receipt"],
    )
if mode in {"live-pilot", "live"}:
    live_command, live_models, live_caps = parse_paid_mode(mode, mode_args)
    live_evidence_root = root / ".release-loop/evidence"
    live_receipt_path = live_evidence_root / f"{mode}-receipt.json"
    if not live_receipt_path.is_file():
        fail("paid-call-receipt missing")
    live_session_marker = os.environ.get("CONFORMANCE_RELEASE_SESSION_MARKER")
    live_session_started = os.environ.get("CONFORMANCE_RELEASE_SESSION_STARTED")
    if not live_session_marker or parse_gate_timestamp(live_session_started) is None:
        fail("paid-call-session-identity missing")
    process_table()
    live_source_readiness = paid_source_preflight()
    live_auth_readiness = paid_auth_preflight()
    live_auth_brokers = {harness: row["sha256"] for harness, row in live_auth_readiness.items()}
    live_approval_path = live_evidence_root / f"{mode}-approval.json"
    if not live_approval_path.is_file():
        fail("paid-approval-packet missing")
    _, live_approval_sha256 = read_paid_approval_packet(
        live_approval_path,
        live_evidence_root,
        mode,
        live_command,
        live_models,
        live_caps,
        live_auth_brokers,
        live_source_readiness["receipt"],
    )

    def live_launcher(call_spec):
        enriched = copy.copy(call_spec)
        enriched["auth_broker_bytes"] = {
            harness: row["bytes"] for harness, row in live_auth_readiness.items()
        }
        enriched["auth_broker_digests"] = live_auth_brokers
        enriched["expected_source_snapshot"] = live_source_readiness["snapshot"]
        enriched["claude_host_home"] = live_auth_readiness["claude"]["host_home"]
        return actual_paid_launcher(enriched)

    live_observed_at = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    live_result = run_paid_mode_entry(
        mode,
        mode_args,
        live_launcher,
        live_evidence_root,
        live_auth_brokers,
        live_source_readiness["receipt"],
        lambda: paid_source_preflight()["receipt"],
        live_approval_sha256,
        lambda: read_paid_approval_packet(
            live_approval_path,
            live_evidence_root,
            mode,
            live_command,
            live_models,
            live_caps,
            live_auth_brokers,
            paid_source_preflight()["receipt"],
        )[1],
        live_session_marker,
        live_session_started,
        live_observed_at,
    )

if mode == "static":
    mutation_count, static_grader_count, source_generation, static_negative_count = validate_static(cases)

golden_source_bytes = (root / "skills/release-loop/SKILL.md").read_bytes()
golden_base = load_json(data_root / "golden/claude/L1-full-lifecycle.json")
golden_negative_probes = []
for label, mutate, source_bytes, diagnostic in (
    ("prompt-change", lambda value: value.__setitem__("prompt", "x"), golden_source_bytes, "golden semantic contract mismatch"),
    ("prompt-whitespace-change", lambda value: value.__setitem__("prompt", value["prompt"] + " "), golden_source_bytes, "golden semantic contract mismatch"),
    ("required-gates-empty", lambda value: value.__setitem__("scripted_answers", []), golden_source_bytes, "golden semantic contract mismatch"),
    (
        "extra-gate",
        lambda value: value["scripted_answers"].append(copy.deepcopy(value["scripted_answers"][0])),
        golden_source_bytes,
        "duplicate gate answer",
    ),
    ("payload-bytes-change", lambda value: None, golden_source_bytes + b"\n", "golden semantic contract mismatch"),
):
    mutant = copy.deepcopy(golden_base)
    mutate(mutant)
    try:
        validate_golden_packet(mutant, "claude", "L1-full-lifecycle", source_bytes)
    except ValueError as exc:
        if diagnostic not in str(exc):
            fail(f"golden negative probe {label} diagnostic mismatch: {exc}")
    else:
        fail(f"golden negative probe {label} was accepted")
    golden_negative_probes.append(label)

negative_probes = []
for label, mutate, diagnostic in (
    ("unknown-schema", lambda value: value.__setitem__("schema", "release-loop-conformance-corpus/v2"), "unknown corpus schema"),
    ("duplicate-case", lambda value: value["cases"].append(copy.deepcopy(value["cases"][0])), "duplicate case ID"),
    ("missing-field", lambda value: value["cases"][0].pop("events"), "missing field: events"),
    ("unknown-verdict", lambda value: value["cases"][0].__setitem__("expected_outcome", "maybe"), "unknown verdict"),
    ("missing-verdict", lambda value: value["cases"][0].pop("expected_outcome"), "missing field: expected_outcome"),
    ("unreachable-grader", lambda value: value["grader_inventory"].append("never-called"), "unreachable grader"),
    (
        "semantic-hollow",
        lambda value: [
            case.update(
                events=[{"sequence": 1, "type": "x", "value": "x"}],
                expected_outcome="pass",
                eligible_mutations=["x"],
                required_graders=["g"],
            )
            for case in value["cases"]
        ]
        + [value.update(grader_inventory=["g"], result_classes=["pass"])],
        "semantic contract mismatch",
    ),
    (
        "event-trace-change",
        lambda value: value["cases"][0]["events"][0].__setitem__("value", "skip-design"),
        "semantic contract mismatch",
    ),
    (
        "mutation-mapping-change",
        lambda value: value["cases"][0].__setitem__("eligible_mutations", ["unrelated"]),
        "semantic contract mismatch",
    ),
):
    mutant = copy.deepcopy(corpus)
    mutate(mutant)
    try:
        validate_corpus(mutant)
    except ValueError as exc:
        if diagnostic not in str(exc):
            fail(f"negative probe {label} diagnostic mismatch: {exc}")
    else:
        fail(f"negative probe {label} was accepted")
    negative_probes.append(label)

print(
    "ok:   release-loop conformance inventory "
    f"cases={len(cases)} live={len(expected_live)} static={len(expected_static)} "
    f"harnesses=2 golden=8 graders={len(corpus['grader_inventory'])} "
    f"negative={len(negative_probes) + len(golden_negative_probes)}"
)
if mode == "static":
    print(
        "ok:   release-loop static conformance "
        f"mutations={mutation_count} graders={static_grader_count} "
        f"negative={static_negative_count} source_generation={source_generation}"
    )
if mode == "fixture":
    print(
        "ok:   release-loop hermetic fixture "
        f"gh_calls={fixture_gh_calls} forbidden={fixture_forbidden} "
        f"policies={fixture_policies} audit_rows={fixture_audit_rows}"
    )
if mode == "gate":
    print(
        "ok:   release-loop pending gates "
        f"mutations={gate_mutations} controls={gate_controls}"
    )
if mode == "preflight":
    print(
        "ok:   release-loop zero-model preflight "
        f"adapters={preflight_adapters} calls={preflight_calls} "
        f"negative={preflight_negatives} auth_events={preflight_auth_events}"
    )
if mode == "resource":
    print(
        "ok:   release-loop resource engine "
        f"sessions={resource_sessions} calls={resource_calls} negative={resource_negatives} "
        f"process_controls={resource_process_controls} manifest={resource_manifest['results_sha256']}"
    )
    print(f"full-run-command: {resource_full_command}")
    print("codex-hard-dollar-cap: unavailable; observed-token cap enforced")
if mode == "transition":
    print(
        "ok:   release-loop transitions "
        f"controls={transition_controls} negative={transition_negatives} generation={transition_digest}"
    )
if mode == "handoff":
    print(
        f"ok:   handoff path={handoff_path} generation={handoff_digest} disposition={handoff_disposition}"
    )
if mode == "publish-baseline":
    print(f"ok:   baseline published generation={baseline_digest}")
if mode == "verify-archive":
    print(f"ok:   archive verified generation={archive_digest}")
if mode == "prepare-pilot":
    print(f"pilot-approval-packet: path={prepare_path} sha256={prepare_digest}")
    print(f"pilot-command: {prepare_command}")
    print("codex-hard-dollar-cap: unavailable; observed-token cap enforced")
if mode == "install-full-approval":
    print(f"full-approval-installed: path={install_path} sha256={install_digest}")
    print(f"full-command: {install_command}")
if mode in {"live-pilot", "live"}:
    print(
        f"ok:   release-loop {mode} results={len(live_result['results'])} "
        f"generation={live_result['generation_sha256']} path={live_result['generation_path']}"
    )
    if live_result["full_command"]:
        print(f"full-run-command: {live_result['full_command']}")
        print("codex-hard-dollar-cap: unavailable; observed-token cap enforced")
PY
