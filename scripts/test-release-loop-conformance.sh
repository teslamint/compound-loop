#!/usr/bin/env bash
# Release-loop cross-harness conformance evaluator.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODE="${1:-}"

case "$MODE" in
  static-inventory|static|fixture|gate|preflight|resource|live-pilot|live) ;;
  *)
    echo "usage: bash scripts/test-release-loop-conformance.sh <static-inventory|static|fixture|gate|preflight|resource|live-pilot|live>" >&2
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
]
expected_results = ["conformant", "pass", "expected-reject"]
expected_case_contracts = {
    "L1-full-lifecycle": (
        "live",
        ["design", "plan", "implement", "review", "ship", "retro", "archive"],
        "conformant",
        ["delete-design-user-gate", "missing-pending-gate", "unknown-pending-gate", "already-approved-pending-gate", "unknown-pending-answer", "nonmonotonic-pending-answer", "nonmonotonic-pending-outcome", "malformed-pending-outcome", "missing-pending-outcome-log"],
        ["design-user-gate", "phase-order", "final-action", "retro-required", "archive-complete", "pending-gate-state"],
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
        ["reenter-premerge-shipping"],
        ["resume-after-merge", "no-premerge-reentry", "retro-required"],
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


def validate_policy_files(fixture_root):
    policy_root = data_root / "policies"
    claude_path = policy_root / "claude-settings.json"
    codex_path = policy_root / "codex.rules"
    claude = load_json(claude_path)
    if claude.get("enableAllProjectMcpServers") is not False:
        fail("Claude policy enables project MCP")
    denied = set(claude.get("permissions", {}).get("deny", []))
    allowed = set(claude.get("permissions", {}).get("allow", []))
    required_denials = {"WebFetch", "WebSearch", "Bash(curl:*)", "Bash(ssh:*)", "Bash(npm publish:*)"}
    if not required_denials <= denied:
        fail("Claude policy denial inventory mismatch")
    if allowed != {"Read", "Write", "Edit", "Glob", "Grep", "Bash(.conformance/bin/fixture-exec:*)"}:
        fail("Claude policy allow inventory mismatch")
    if not {"Bash(git:*)", "Bash(gh:*)"} <= denied:
        fail("Claude policy raw command denial mismatch")
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
    settings_target = fixture_root / ".claude" / "settings.json"
    rules_target = fixture_root / ".codex" / "rules" / "conformance.rules"
    settings_target.parent.mkdir(parents=True)
    rules_target.parent.mkdir(parents=True)
    shutil.copyfile(claude_path, settings_target)
    shutil.copyfile(codex_path, rules_target)
    empty_mcp = fixture_root / "empty-mcp.json"
    empty_mcp.write_text("{}\n", encoding="utf-8")
    for source, target in ((claude_path, settings_target), (codex_path, rules_target)):
        if hashlib.sha256(source.read_bytes()).digest() != hashlib.sha256(target.read_bytes()).digest():
            fail("fixture policy copy digest mismatch")
    return 3


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
        "codex", "exec", "--json", "--ignore-user-config",
        "--model", model, "--approve-for-me", "--sandbox", "workspace-write",
        "--cd", str(fixture_root), "--output-last-message", str(result_path), "-",
    ]


def build_codex_resume(model, session_id):
    return ["codex", "exec", "resume", "--json", "--ignore-user-config", "--model", model, session_id, "-"]


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
        rules_path = fixture_root / ".codex" / "rules" / "conformance.rules"
        mcp_path = fixture_root / "empty-mcp.json"
        policy_digests = {
            path: hashlib.sha256(path.read_bytes()).hexdigest()
            for path in (settings_path, rules_path, mcp_path)
        }
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
            "codex", "exec", "--json", "--ignore-user-config", "--model", codex_model,
            "--approve-for-me", "--sandbox", "workspace-write", "--cd", str(fixture_root),
            "--output-last-message", str(codex_result), "-",
        ]
        expected_codex_resume = [
            "codex", "exec", "resume", "--json", "--ignore-user-config", "--model", codex_model, codex_id, "-",
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
    session_marker,
    session_started,
    observed_at,
    used_nonces,
):
    required = {
        "schema", "gate_kind", "command_sha256", "models", "caps", "approved_at",
        "session_marker", "nonce", "status",
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


def consume_paid_receipt_file(
    receipt_path,
    nonce_ledger_path,
    command,
    gate_kind,
    models,
    caps,
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
        invariant = validate_paid_receipt(
            receipt,
            command,
            gate_kind,
            models,
            caps,
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
    }


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


def signal_pids(pids, signal_value):
    for pid in sorted(pids):
        try:
            os.kill(pid, signal_value)
        except (ProcessLookupError, PermissionError):
            pass


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
        signal_pids(observed_descendants, signal.SIGTERM)
        term_sent = True
        deadline = time.monotonic() + term_grace
        while process.poll() is None and time.monotonic() < deadline:
            time.sleep(0.01)
        try:
            os.killpg(process.pid, signal.SIGKILL)
            kill_sent = True
        except ProcessLookupError:
            pass
        signal_pids(observed_descendants, signal.SIGKILL)
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
    claude_costs = [Decimal(str(row["observed_cost"])) for row in pilot_results if row["harness"] == "claude" and row.get("observed_cost") is not None]
    observed_claude = max(claude_costs) if claude_costs else Decimal(pilot_caps["claude_max_invocation_usd"])
    expected_per_harness = 12
    full_total_budget = observed_claude * expected_per_harness * 2
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


def write_json_atomic(path, value, allowed_root):
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
        os.fchmod(descriptor, 0o600)
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
        "claude_settings_sha256", "codex_rules_sha256", "models", "cli_versions", "results_sha256",
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
    }


def process_proof_complete(proof):
    required = {"leader_waited", "pgid_absent", "descendants_absent", "escaped_descendants_absent"}
    return isinstance(proof, dict) and required <= proof.keys() and all(proof[key] is True for key in required)


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
        "escaped_descendants_absent": proof["descendants_absent"],
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


def execute_paid_schedule(mode_name, caps, models, launcher, state_path=None, state_root=None):
    cases = ["L1-full-lifecycle"] if mode_name == "live-pilot" else [
        "L1-full-lifecycle", "L2-mid-loop-resume", "L3-post-merge-resume", "L4-degraded-dispatch"
    ]
    repetitions = 1 if mode_name == "live-pilot" else 3
    ledger = new_resource_ledger(caps)
    results = []
    process_proofs = []
    command_audit = []
    started = time.monotonic()

    def persist_state(status, generation_sha256=None):
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
        write_json_atomic(state_path, state, state_root)

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
                    int(time.monotonic() - started),
                )
                if invariant is not None:
                    fail(invariant)
                session_proofs = []

                def before_invocation(turn_id, session_elapsed=0):
                    start_invariant = invocation_start_invariant(
                        ledger,
                        caps,
                        harness,
                        1,
                        session_elapsed,
                        int(time.monotonic() - started),
                    )
                    if start_invariant is not None:
                        fail(start_invariant)
                    if harness == "claude":
                        reservation_invariant = reserve_claude(ledger, caps, turn_id)
                        if reservation_invariant is not None:
                            fail(reservation_invariant)
                    ledger["active_process"] = {"invocation_id": turn_id, "status": "launch-intent"}
                    persist_state("running")

                def after_invocation(turn_id, proof, observed_cost, observed_tokens, session_elapsed=0):
                    if not process_proof_complete(proof):
                        fail("process-exit-proof-incomplete")
                    session_proofs.append(proof)
                    process_proofs.append(proof)
                    ledger["active_process"] = None
                    if harness == "claude":
                        settlement_invariant = settle_claude(ledger, turn_id, observed_cost)
                    else:
                        settlement_invariant = record_codex_usage(ledger, caps, turn_id, observed_tokens)
                    if settlement_invariant is not None:
                        fail(settlement_invariant)
                    persist_state("running")
                    elapsed_invariant = invocation_start_invariant(
                        ledger,
                        caps,
                        harness,
                        1,
                        session_elapsed,
                        int(time.monotonic() - started),
                    )
                    if elapsed_invariant in {"session-timeout-exhausted", "total-wall-time-exhausted"}:
                        fail(elapsed_invariant)

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
                    if harness == "claude" and ledger["claude_active"] is not None:
                        active_id = ledger["claude_active"]["call_id"]
                        settle_claude(ledger, active_id, None)
                    raise
                if not session_proofs:
                    fail("process-exit-proof-missing")
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
        fail("paid schedule unsettled")
    if mode_name == "live-pilot" and validate_pilot_results(results) is not None:
        fail(validate_pilot_results(results))
    if mode_name == "live" and validate_strata(results) is not None:
        fail(validate_strata(results))
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
    artifacts = {
        "results.json": results,
        "resource-ledger.json": normalized_resource_ledger(ledger),
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
        approval_packet = {
            "schema": "release-loop-full-run-approval/v1",
            "pilot_results_sha256": object_digest(results),
            "pilot_settlement_sha256": object_digest(normalized_resource_ledger(ledger)),
            "full_command": shlex.join(derived_full_command),
            "full_command_sha256": paid_command_digest(derived_full_command),
            "models": models,
            "caps": derived_caps,
            "codex_hard_dollar_cap": "unavailable-observed-token-cap-enforced",
        }
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


def write_adapter_supervisor(path):
    source = f'''#!{sys.executable}
import base64
import json
import os
from pathlib import Path
import selectors
import signal
import subprocess
import sys
import time

spec = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
summary_path = Path(sys.argv[2])
stdin_bytes = base64.b64decode(spec["stdin_base64"])
process = subprocess.Popen(
    spec["argv"], cwd=spec["cwd"], env=spec["env"],
    stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
)
process.stdin.write(stdin_bytes)
process.stdin.close()
selector = selectors.DefaultSelector()
selector.register(process.stdout, selectors.EVENT_READ, "stdout")
selector.register(process.stderr, selectors.EVENT_READ, "stderr")
buffers = {{"stdout": bytearray(), "stderr": bytearray()}}
started = time.monotonic()
overflow = False
timed_out = False
while selector.get_map():
    if time.monotonic() - started > spec["timeout"]:
        process.kill()
        timed_out = True
    for key, _ in selector.select(0.1):
        chunk = os.read(key.fileobj.fileno(), 8192)
        if not chunk:
            selector.unregister(key.fileobj)
            continue
        buffers[key.data].extend(chunk)
        if len(buffers["stdout"]) + len(buffers["stderr"]) > spec["output_cap"]:
            process.kill()
            overflow = True
    if (overflow or timed_out) and process.poll() is not None:
        continue
returncode = process.wait()
summary = {{
    "returncode": returncode,
    "stdout_base64": base64.b64encode(bytes(buffers["stdout"][:spec["output_cap"]])).decode(),
    "stderr_base64": base64.b64encode(bytes(buffers["stderr"][:spec["output_cap"]])).decode(),
    "overflow": overflow,
    "timed_out": timed_out,
}}
summary_path.write_text(json.dumps(summary, sort_keys=True) + "\\n", encoding="utf-8")
'''
    path.write_text(source, encoding="utf-8")
    path.chmod(0o755)


def managed_adapter_call(command, cwd, env, stdin_bytes, timeout_seconds, work_root):
    import base64
    supervisor = work_root / "adapter-supervisor.py"
    spec_path = work_root / f"adapter-spec-{uuid.uuid4().hex}.json"
    summary_path = work_root / f"adapter-summary-{uuid.uuid4().hex}.json"
    write_adapter_supervisor(supervisor)
    spec = {
        "argv": command,
        "cwd": str(cwd),
        "env": env,
        "stdin_base64": base64.b64encode(stdin_bytes).decode(),
        "timeout": timeout_seconds,
        "output_cap": 65536,
    }
    write_json_atomic(spec_path, spec, work_root)
    proof = managed_process(
        [sys.executable, str(supervisor), str(spec_path), str(summary_path)],
        timeout_seconds + 2,
        table_reader=process_table,
    )
    if not proof["reaped"] or not proof["process_group_reaped"] or not proof["descendants_absent"]:
        fail("adapter process proof incomplete")
    summary = json.loads(read_bounded_file(summary_path, work_root, 200000))
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
        "escaped_descendants_absent": proof["descendants_absent"],
        "timed_out": proof["timed_out"],
        "term_sent": proof["term_sent"],
        "kill_sent": proof["kill_sent"],
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
    env = {
        "PATH": f"{bin_path}:{Path(git_path).parent}:{Path(claude_path).parent}:{Path(codex_path).parent}:/usr/bin:/bin",
        "HOME": str(home_path),
        "TMPDIR": str(temp_path),
        "LC_ALL": "C",
        "LANG": "C",
        "GIT_CONFIG_NOSYSTEM": "1",
        "GIT_TERMINAL_PROMPT": "0",
    }
    git_fixture_command(git_path, env, run_root, "clone", "--bare", str(root), str(origin_path))
    git_fixture_command(git_path, env, run_root, "clone", str(origin_path), str(repo_path))
    for key, value in (
        ("user.name", "Conformance Fixture"), ("user.email", "fixture@example.invalid"),
        ("core.autocrlf", "false"), ("core.safecrlf", "false"), ("commit.gpgsign", "false"),
    ):
        git_fixture_command(git_path, env, repo_path, "config", key, value)
    validate_policy_files(repo_path)
    source_snapshot = adapter_source_snapshot(root)
    policy_digests = {
        path: hashlib.sha256(path.read_bytes()).hexdigest()
        for path in (
            repo_path / ".claude/settings.json",
            repo_path / ".codex/rules/conformance.rules",
            repo_path / "empty-mcp.json",
        )
    }
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
    for harness in ("claude", "codex"):
        auth_command = [claude_path, "auth", "status"] if harness == "claude" else [codex_path, "login", "status"]
        auth = run_bounded(auth_command, repo_path, env, output_cap=8192, timeout=10)
        if auth.returncode != 0 or ("false" in auth.stdout.lower()) or ("not logged" in auth.stdout.lower()):
            fail("auth-isolation-unavailable")
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
    call_spec["after_invocation"](
        initial_turn_id, proof, initial_cost, initial_tokens, time.monotonic() - actual_session_started
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
        call_spec["after_invocation"](
            resume_turn_id,
            resume_proof,
            resume_cost,
            resume_tokens,
            time.monotonic() - actual_session_started,
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
        "escaped_descendants_absent": all(proof["escaped_descendants_absent"] for proof in proofs),
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
            "wrapper_audit_sha256": hashlib.sha256(wrapper_audit_path.read_bytes()).hexdigest()
            if wrapper_audit_path.is_file() else None,
            "gh_audit_sha256": hashlib.sha256(gh_audit_path.read_bytes()).hexdigest()
            if gh_audit_path.is_file() else None,
        },
    }


def validate_resource_group():
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
    session_marker = "resource-session"
    session_started = "2026-08-24T06:00:00Z"
    observed_at = "2026-08-24T06:01:00Z"
    used_nonces = set()
    pilot = pilot_command(caps, models)
    pilot_caps = {**caps, "max_concurrency": 1, "total_wall_time": caps["session_timeout"] * 2}
    parsed_pilot, parsed_models, parsed_caps = parse_paid_mode("live-pilot", pilot[3:])
    if parsed_pilot != pilot or parsed_models != models or parsed_caps != pilot_caps:
        fail("resource pilot command parser mismatch")
    receipt = {
        "schema": "release-loop-paid-receipt/v1",
        "gate_kind": "live-pilot",
        "command_sha256": paid_command_digest(pilot),
        "models": models,
        "caps": pilot_caps,
        "approved_at": "2026-08-24T06:00:30Z",
        "session_marker": session_marker,
        "nonce": "a" * 32,
        "status": "approved",
    }
    if validate_paid_receipt(
        receipt, pilot, "live-pilot", models, pilot_caps, session_marker, session_started, observed_at, used_nonces
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
        write_json_atomic(receipt_path, receipt, receipt_temp_root)
        durable_receipt, durable_consumption = consume_paid_receipt_file(
            receipt_path,
            nonce_path,
            pilot,
            "live-pilot",
            models,
            pilot_caps,
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

    full_receipt = copy.deepcopy(receipt)
    full_receipt.update(
        gate_kind="live",
        command_sha256=paid_command_digest(full_command),
        caps=caps,
        nonce="b" * 32,
    )
    if validate_paid_receipt(
        full_receipt, full_command, "live", models, caps, session_marker, session_started, observed_at, used_nonces
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
        [sys.executable, "-c", "import time; time.sleep(5)"], 0.05, table_reader=empty_process_table
    )
    if not timeout["timed_out"] or not timeout["reaped"] or not timeout["process_group_reaped"]:
        fail("resource timeout process control failed")
    process_controls += 1
    resistant = managed_process(
        [sys.executable, "-c", "import signal,time; signal.signal(signal.SIGTERM, signal.SIG_IGN); time.sleep(5)"],
        0.05,
        0.05,
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
        0.2,
        0.05,
        table_reader=scripted_process_table,
    )
    if not escaped["timed_out"] or not escaped["descendants_absent"] or not escaped["observed_descendants"]:
        fail("resource escaped descendant control failed")
    if escaped_pid_file.exists():
        escaped_pid_file.unlink()
    process_controls += 1
    process_proof = [normal, timeout, resistant, escaped]
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
        pilot_entry_receipt = {**receipt, "nonce": "2" * 32}
        write_json_atomic(paid_root / "live-pilot-receipt.json", pilot_entry_receipt, paid_root)
        pilot_entry = run_paid_mode_entry(
            "live-pilot",
            pilot[3:],
            fake_paid_launcher,
            paid_root,
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
        if approval_packet.get("full_command") != pilot_entry["full_command"]:
            fail("resource full-run approval packet mismatch")
        try:
            run_paid_mode_entry(
                "live-pilot",
                pilot[3:],
                fake_paid_launcher,
                paid_root,
                session_marker,
                session_started,
                observed_at,
            )
        except ValueError as exc:
            if "paid-receipt-reused" not in str(exc):
                fail(f"resource paid entry reuse diagnostic mismatch: {exc}")
        else:
            fail("resource paid pilot entry reused receipt")
        full_entry_receipt = {**full_receipt, "nonce": "3" * 32}
        write_json_atomic(paid_root / "live-receipt.json", full_entry_receipt, paid_root)
        full_entry = run_paid_mode_entry(
            "live",
            full_command[3:],
            fake_paid_launcher,
            paid_root,
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
        None, pilot, "live-pilot", models, pilot_caps, session_marker, session_started, observed_at, used_nonces
    ) != "paid-receipt-shape":
        fail("resource missing receipt accepted")
    negatives += 1
    for label, mutant, expected in (
        ("stale", {**receipt, "approved_at": "2026-08-24T05:59:59Z", "nonce": "c" * 32}, "paid-receipt-stale"),
        ("command", {**receipt, "command_sha256": "0" * 64, "nonce": "d" * 32}, "paid-receipt-command"),
        ("session", {**receipt, "session_marker": "other", "nonce": "e" * 32}, "paid-receipt-session"),
        ("models", {**receipt, "models": {"claude": "other", "codex": models["codex"]}, "nonce": "f" * 32}, "paid-receipt-models"),
        ("caps", {**receipt, "caps": {**caps, "max_turns_per_session": 5}, "nonce": "1" * 32}, "paid-receipt-caps"),
    ):
        actual = validate_paid_receipt(
            mutant, pilot, "live-pilot", models, pilot_caps, session_marker, session_started, observed_at, used_nonces
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

    for launcher, diagnostic in (
        (failed_pilot_launcher, "pilot-infrastructure-failure"),
        (nonconformant_pilot_launcher, "pilot-conformance-failure"),
    ):
        try:
            execute_paid_schedule("live-pilot", pilot_caps, models, launcher)
        except ValueError as exc:
            if diagnostic not in str(exc):
                fail(f"resource pilot failure diagnostic mismatch: {exc}")
        else:
            fail(f"resource pilot failure accepted: {diagnostic}")
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
    if policy.get("state") != "bootstrap":
        fail("bootstrap policy state mismatch")
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
    roadmap = (root / "ROADMAP.md").read_text(encoding="utf-8")
    if f"| {policy.get('roadmap_item')} |" not in roadmap:
        fail("bootstrap ROADMAP item missing")

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
if mode in {"live-pilot", "live"}:
    parse_paid_mode(mode, mode_args)
    live_evidence_root = root / ".release-loop/evidence"
    live_receipt_path = live_evidence_root / f"{mode}-receipt.json"
    if not live_receipt_path.is_file():
        fail("paid-call-receipt missing")
    live_session_marker = os.environ.get("CONFORMANCE_RELEASE_SESSION_MARKER")
    live_session_started = os.environ.get("CONFORMANCE_RELEASE_SESSION_STARTED")
    if not live_session_marker or parse_gate_timestamp(live_session_started) is None:
        fail("paid-call-session-identity missing")
    process_table()
    live_observed_at = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    live_result = run_paid_mode_entry(
        mode,
        mode_args,
        actual_paid_launcher,
        live_evidence_root,
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
if mode in {"live-pilot", "live"}:
    print(
        f"ok:   release-loop {mode} results={len(live_result['results'])} "
        f"generation={live_result['generation_sha256']} path={live_result['generation_path']}"
    )
    if live_result["full_command"]:
        print(f"full-run-command: {live_result['full_command']}")
        print("codex-hard-dollar-cap: unavailable; observed-token cap enforced")
PY
