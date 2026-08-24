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
expected_live = {
    "L1-full-lifecycle",
    "L2-mid-loop-resume",
    "L3-post-merge-resume",
    "L4-degraded-dispatch",
}
expected_static = {
    "SC2-reject-a-different-kind",
    "SC2-reject-b-unstable-invariance",
    "SC2-reject-c-irrelevant-axis",
    "SC2-reject-d-metadata-only",
    "SC2-guard-reject",
    "SC2-accept-controlled-pairs",
    "parser-contradictory-substitute-command",
    "parser-fence-relocation",
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

    if len(case_ids) != len(set(case_ids)):
        fail("duplicate case ID")
    actual_live = {case["id"] for case in cases if case["kind"] == "live"}
    actual_static = {case["id"] for case in cases if case["kind"] == "static"}
    if actual_live != expected_live:
        fail("live case inventory mismatch")
    if actual_static != expected_static:
        fail("static case inventory mismatch")
    unreachable = sorted(graders - referenced_graders)
    if unreachable:
        fail(f"unreachable grader: {unreachable[0]}")
    return cases


def validate_golden():
    source = root / "skills/release-loop/SKILL.md"
    source_digest = hashlib.sha256(source.read_bytes()).hexdigest()
    expected_paths = set()
    for harness in ("claude", "codex"):
        for case_id in sorted(expected_live):
            path = data_root / "golden" / harness / f"{case_id}.json"
            expected_paths.add(path)
            packet = load_json(path)
            required = {
                "schema",
                "harness",
                "case_id",
                "payload_mode",
                "skill_source",
                "skill_sha256",
                "prompt",
                "scripted_answers",
            }
            missing = sorted(required - packet.keys()) if isinstance(packet, dict) else ["object"]
            if missing:
                fail(f"golden {harness}/{case_id} missing field: {missing[0]}")
            if packet["schema"] != "release-loop-golden-input/v1":
                fail(f"golden {harness}/{case_id} has unknown schema")
            if packet["harness"] != harness or packet["case_id"] != case_id:
                fail(f"golden {harness}/{case_id} identity mismatch")
            if packet["payload_mode"] != "exact-current-skill-bytes":
                fail(f"golden {harness}/{case_id} payload mode mismatch")
            if packet["skill_source"] != "skills/release-loop/SKILL.md":
                fail(f"golden {harness}/{case_id} skill source mismatch")
            if packet["skill_sha256"] != source_digest:
                fail(f"golden {harness}/{case_id} skill digest mismatch")
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

    actual_paths = set((data_root / "golden").glob("*/*.json"))
    if actual_paths != expected_paths:
        fail("golden file inventory mismatch")


corpus = load_json(corpus_path)
cases = validate_corpus(corpus)
validate_golden()

negative_probes = []
for label, mutate, diagnostic in (
    ("unknown-schema", lambda value: value.__setitem__("schema", "release-loop-conformance-corpus/v2"), "unknown corpus schema"),
    ("duplicate-case", lambda value: value["cases"].append(copy.deepcopy(value["cases"][0])), "duplicate case ID"),
    ("missing-field", lambda value: value["cases"][0].pop("events"), "missing field: events"),
    ("unknown-verdict", lambda value: value["cases"][0].__setitem__("expected_outcome", "maybe"), "unknown verdict"),
    ("missing-verdict", lambda value: value["cases"][0].pop("expected_outcome"), "missing field: expected_outcome"),
    ("unreachable-grader", lambda value: value["grader_inventory"].append("never-called"), "unreachable grader"),
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
    f"negative={len(negative_probes)}"
)
PY
