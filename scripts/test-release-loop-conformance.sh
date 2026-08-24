#!/usr/bin/env bash
# Release-loop cross-harness conformance evaluator.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODE="${1:-}"

case "$MODE" in
  static-inventory|static|fixture) ;;
  *)
    echo "usage: bash scripts/test-release-loop-conformance.sh <static-inventory|static|fixture>" >&2
    exit 2
    ;;
esac

python3 - "$ROOT" "$MODE" <<'PY'
import copy
import hashlib
import json
import os
from pathlib import Path
import re
import selectors
import shutil
import subprocess
import sys
import tempfile
import time

root = Path(sys.argv[1])
mode = sys.argv[2]
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
]
expected_results = ["conformant", "pass", "expected-reject"]
expected_case_contracts = {
    "L1-full-lifecycle": (
        "live",
        ["design", "plan", "implement", "review", "ship", "retro", "archive"],
        "conformant",
        ["delete-design-user-gate"],
        ["design-user-gate", "phase-order", "final-action", "retro-required", "archive-complete"],
    ),
    "L2-mid-loop-resume": (
        "live",
        ["resume", "implement", "review", "ship", "retro", "archive"],
        "conformant",
        ["replay-completed-phase"],
        ["resume-source-truth", "no-phase-replay", "terminal-evidence"],
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


def run_bounded(argv, cwd, env, output_cap=65536, timeout=10):
    process = subprocess.Popen(argv, cwd=str(cwd), env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
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
for target in (repo, origin, wrapper):
    target.relative_to(root)
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
target = os.environ["CONFORMANCE_GIT"] if args[0] == "git" else os.environ["CONFORMANCE_GH"]
os.execv(target, [target, *args[1:]])
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
    unrelated = copy.deepcopy(mutation_rows[4])
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
PY
