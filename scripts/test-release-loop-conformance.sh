#!/usr/bin/env bash
# Release-loop cross-harness conformance evaluator.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODE="${1:-}"

case "$MODE" in
  static-inventory) ;;
  *)
    echo "usage: bash scripts/test-release-loop-conformance.sh static-inventory" >&2
    exit 2
    ;;
esac

python3 - "$ROOT" <<'PY'
import copy
import hashlib
import json
from pathlib import Path
import sys

root = Path(sys.argv[1])
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


corpus = load_json(corpus_path)
cases = validate_corpus(corpus)
validate_golden()

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
PY
