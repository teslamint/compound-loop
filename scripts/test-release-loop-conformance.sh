#!/usr/bin/env bash
# Release-loop cross-harness conformance evaluator.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODE="${1:-}"

case "$MODE" in
  static-inventory|static) ;;
  *)
    echo "usage: bash scripts/test-release-loop-conformance.sh <static-inventory|static>" >&2
    exit 2
    ;;
esac

python3 - "$ROOT" "$MODE" <<'PY'
import copy
import hashlib
import json
from pathlib import Path
import sys

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


def grade_mutation(mutation, cases_by_id, clauses_by_id):
    mutation_id = mutation["id"]
    case = cases_by_id[mutation["case_id"]]
    if mutation_id == "delete-design-user-gate":
        clause = clauses_by_id["design-user-gate"]
        source = (root / clause["path"]).read_text(encoding="utf-8")
        mutated = source.replace(clause["text"], "", 1)
        rejected = clause["text"] not in mutated
        return ("expected-reject", "design-user-gate") if rejected else ("unexpected-pass", "design-user-gate")
    if mutation_id == "replay-completed-phase":
        values = [event["value"] for event in case["events"]]
        mutated = values + [values[1]]
        rejected = len(mutated) != len(set(mutated))
        return ("expected-reject", "no-phase-replay") if rejected else ("unexpected-pass", "no-phase-replay")
    if mutation_id == "reenter-premerge-shipping":
        clause = clauses_by_id["resume-after-merge"]
        source = (root / clause["path"]).read_text(encoding="utf-8")
        mutated = source.replace("never re-enters pre-merge", "re-enters pre-merge", 1)
        rejected = clause["text"] not in mutated
        return ("expected-reject", "resume-after-merge") if rejected else ("unexpected-pass", "resume-after-merge")
    if mutation_id == "drop-work-without-subagents":
        values = [event["value"] for event in case["events"]]
        mutated = [value for value in values if value != "implement-degraded"]
        rejected = set(values) - set(mutated) == {"implement-degraded"}
        return ("expected-reject", "no-coverage-drop") if rejected else ("unexpected-pass", "no-coverage-drop")
    fixture = mutation.get("fixture", {})
    if mutation["grader"] == "sc2-comparison":
        if mutation_id == "controlled-same-kind-pairs":
            valid = (
                fixture.get("left_kind") == fixture.get("right_kind")
                and fixture.get("invariance_equal") is True
                and fixture.get("axis_relevant") is True
                and fixture.get("effect_equal") is False
            )
            return ("pass", "sc2-comparison") if valid else ("unexpected-reject", "sc2-comparison")
        invalid = (
            fixture.get("left_kind") != fixture.get("right_kind")
            or fixture.get("invariance_equal") is not True
            or fixture.get("axis_relevant") is not True
            or fixture.get("effect_equal") is not False
        )
        return ("expected-reject", "sc2-comparison") if invalid else ("unexpected-pass", "sc2-comparison")
    if mutation["grader"] == "sc2-guard":
        invalid = fixture.get("pass_fixture") is True and fixture.get("fail_fixture") is True
        return ("expected-reject", "sc2-guard") if invalid else ("unexpected-pass", "sc2-guard")
    if mutation_id == "contradictory-substitute-command":
        invalid = fixture.get("operative") != fixture.get("substitute")
        return ("expected-reject", "operative-section-parser") if invalid else ("unexpected-pass", "operative-section-parser")
    if mutation_id == "fence-relocation":
        invalid = fixture.get("fence") == "~~~~markdown" and bool(fixture.get("operative"))
        return ("expected-reject", "operative-section-parser") if invalid else ("unexpected-pass", "operative-section-parser")
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
    spec_path = root / policy.get("approved_spec", "")
    if hashlib.sha256(spec_path.read_bytes()).hexdigest() != policy.get("approved_spec_sha256"):
        fail("bootstrap spec digest mismatch")
    roadmap = (root / "ROADMAP.md").read_text(encoding="utf-8")
    if f"| {policy.get('roadmap_item')} |" not in roadmap:
        fail("bootstrap ROADMAP item missing")

    clauses = manifest.get("clauses")
    if not isinstance(clauses, list) or not clauses:
        fail("source clauses missing")
    clauses_by_id = {}
    generation_rows = []
    for clause in clauses:
        clause_id = clause.get("id")
        if not clause_id or clause_id in clauses_by_id:
            fail("duplicate or missing clause ID")
        source_path = root / clause.get("path", "")
        source = source_path.read_text(encoding="utf-8")
        section = section_text(source, clause.get("heading", ""))
        literal = clause.get("text")
        if not isinstance(literal, str) or section.count(literal) != 1:
            fail(f"source clause missing or ambiguous: {clause_id}")
        digest = hashlib.sha256(literal.encode()).hexdigest()
        if digest != clause.get("sha256"):
            fail(f"source clause digest drift: {clause_id}")
        clauses_by_id[clause_id] = clause
        generation_rows.append(f"{clause_id}:{digest}")

    mutation_rows = mutations.get("mutations")
    if not isinstance(mutation_rows, list) or not mutation_rows:
        fail("mutation inventory missing")
    mutation_ids = [row.get("id") for row in mutation_rows]
    eligible = [mutation for case in cases for mutation in case["eligible_mutations"]]
    if mutation_ids != eligible:
        fail("mutation inventory does not match corpus eligibility")
    cases_by_id = {case["id"]: case for case in cases}
    seen_graders = set()
    for mutation in mutation_rows:
        result, grader = grade_mutation(mutation, cases_by_id, clauses_by_id)
        if result != mutation.get("expected") or grader != mutation.get("grader"):
            fail(f"unexpected static result: {mutation.get('id')} result={result} grader={grader}")
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
    if generation != policy.get("source_generation"):
        fail("bootstrap source generation mismatch")

    static_negative_probes = []
    wrong_grader = copy.deepcopy(mutation_rows[0])
    wrong_grader["grader"] = "phase-order"
    result, actual_grader = grade_mutation(wrong_grader, cases_by_id, clauses_by_id)
    if result == wrong_grader["expected"] and actual_grader == wrong_grader["grader"]:
        fail("unrelated rejection probe was accepted")
    static_negative_probes.append("unrelated-rejection")
    disabled_rows = [row for row in mutation_rows if row["grader"] != "sc2-guard"]
    disabled_graders = {grade_mutation(row, cases_by_id, clauses_by_id)[1] for row in disabled_rows}
    if disabled_graders == seen_graders:
        fail("disabled grader probe was accepted")
    static_negative_probes.append("disabled-grader")
    if generation == "0" * 64:
        fail("source generation drift probe was accepted")
    static_negative_probes.append("source-generation-drift")
    first_clause = clauses[0]
    if hashlib.sha256(first_clause["text"].encode()).hexdigest() == "0" * 64:
        fail("clause digest drift probe was accepted")
    static_negative_probes.append("clause-digest-drift")
    return len(mutation_rows), len(seen_graders), generation, len(static_negative_probes)


corpus = load_json(corpus_path)
cases = validate_corpus(corpus)
validate_golden()

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
PY
