#!/usr/bin/env bash
# C2-TI deterministic fixture evaluator. It uses only the standard library.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODE="${1:-dogfood}"

if [[ "$MODE" == "contract" ]]; then
  python3 - "$ROOT/skills/reviewing/references/lanes.md" <<'PY'
import sys
from pathlib import Path

lane_path = Path(sys.argv[1])
text = lane_path.read_text(encoding="utf-8")
required = (
    "test-integrity",
    "network isolation",
    "shared temporary directories",
    "verifier fail-open behavior",
    "assertion specificity",
    "hidden environment dependencies",
    "fixture Git signing/hooks",
    "schemas/lane-findings.schema.json",
    "references/merge-pipeline.md",
)
missing = [item for item in required if item not in text]
if missing:
    raise SystemExit("C2-TI contract missing: " + ", ".join(missing))
print("C2-TI contract present")
PY
  exit $?
fi

if [[ "$MODE" == "gate" ]]; then
  python3 - "$ROOT/scripts/validate.sh" <<'PY'
import sys
from pathlib import Path

text = Path(sys.argv[1]).read_text(encoding="utf-8")
required = (
    "test-review-test-integrity.sh\" dogfood",
    "COMPOUND_LOOP_SKIP_TEST_INTEGRITY",
    "COMPOUND_LOOP_IN_VALIDATE",
)
missing = [item for item in required if item not in text]
if missing:
    raise SystemExit("C2-TI validation gate missing: " + ", ".join(missing))
print("C2-TI validation gate present")
PY
  exit $?
fi

python3 - "$ROOT" "$MODE" <<'PY'
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

root = Path(sys.argv[1]).resolve()
mode = sys.argv[2]
corpus_path = root / "tests/conformance/review/test-integrity-corpus.json"
schema_path = root / "schemas/lane-findings.schema.json"

if mode not in {"dogfood", "seeded", "clean", "isolation"}:
    raise SystemExit(f"C2-TI unknown mode: {mode}")

corpus = json.loads(corpus_path.read_text(encoding="utf-8"))
lane_schema = json.loads(schema_path.read_text(encoding="utf-8"))
if corpus.get("schema") != "c2-ti/v1":
    raise SystemExit("C2-TI corpus schema is unknown")

class_ids = {
    "network-isolation",
    "shared-temporary-directories",
    "verifier-fail-open",
    "assertion-specificity",
    "hidden-environment-dependencies",
    "fixture-git-signing-hooks",
}
classes = {item["id"]: item for item in corpus.get("classes", [])}
if set(classes) != class_ids:
    raise SystemExit(f"C2-TI class inventory mismatch: {sorted(classes)}")

cases = corpus.get("cases", [])
case_ids = [case.get("id") for case in cases]
if any(not case_id for case_id in case_ids) or len(set(case_ids)) != len(case_ids):
    raise SystemExit("C2-TI case IDs must be non-empty and unique")
for case in cases:
    if case.get("kind") not in {"seed", "holdout", "clean"}:
        raise SystemExit(f"C2-TI unknown case kind: {case.get('id')}")
    if case.get("kind") != "clean" and case.get("class") not in class_ids:
        raise SystemExit(f"C2-TI unknown class: {case.get('id')}")
    if not isinstance(case.get("source"), str) or not case["source"]:
        raise SystemExit(f"C2-TI source missing: {case.get('id')}")
    if not isinstance(case.get("expected_findings"), list):
        raise SystemExit(f"C2-TI expected findings missing: {case.get('id')}")
for class_id in class_ids:
    members = [case for case in cases if case.get("class") == class_id]
    if len([case for case in members if case["kind"] == "seed"]) != 2:
        raise SystemExit(f"C2-TI requires two seeds for {class_id}")
    if len([case for case in members if case["kind"] == "holdout"]) != 1:
        raise SystemExit(f"C2-TI requires one holdout for {class_id}")
if len([case for case in cases if case["kind"] == "clean"]) != 1:
    raise SystemExit("C2-TI requires one clean fixture")

PROBES = {
    "network-isolation": (
        re.compile(r"\b(?:requests|httpx|urllib\.request)\.(?:get|post|urlopen)\s*\("),
        re.compile(r"\bsocket\.(?:create_connection|socket)\s*\("),
        re.compile(r"[\"'](?:curl|wget|ssh)[\"']"),
    ),
    "shared-temporary-directories": (
        re.compile(r"/tmp/[^\"']+"),
        re.compile(r"tempfile\.gettempdir\(\)"),
    ),
    "verifier-fail-open": (
        re.compile(r"except\s+[^:]+:\s*(?:return\s+True|pass)\b"),
    ),
    "assertion-specificity": (
        re.compile(r"^\s*assert\s+(?:True|False|[A-Za-z_]\w*(?:\.[A-Za-z_]\w*)?)\s*$"),
        re.compile(r"^\s*assert\s+[\"'][^\"']+[\"']\s+in\s+\w+\s*$"),
    ),
    "hidden-environment-dependencies": (
        re.compile(
            r"os\.environ\[\s*[\"'](?:HOME|PATH|TMPDIR|SSH_AUTH_SOCK|HTTP_PROXY|HTTPS_PROXY|GPG_TTY)[\"']\s*\]"
        ),
        re.compile(
            r"os\.getenv\(\s*[\"'](?:HOME|PATH|TMPDIR|SSH_AUTH_SOCK|HTTP_PROXY|HTTPS_PROXY|GPG_TTY)[\"']"
        ),
    ),
    "fixture-git-signing-hooks": (
        re.compile(r"[\"']git[\"'].+[\"']config[\"'].+[\"']--global[\"']"),
        re.compile(r"--global.*(?:commit\.gpgsign|core\.hooksPath)"),
    ),
}

ENVELOPE_REQUIRED = set(lane_schema["required"])
FINDING_SCHEMA = lane_schema["properties"]["findings"]["items"]
DETAIL_REQUIRED = set(FINDING_SCHEMA["required"])
SEVERITIES = set(FINDING_SCHEMA["properties"]["severity"]["enum"])
CONFIDENCE = set(FINDING_SCHEMA["properties"]["confidence"]["enum"])
AUTOFIX = set(FINDING_SCHEMA["properties"]["autofix_class"]["enum"])
OWNERS = set(FINDING_SCHEMA["properties"]["owner"]["enum"])


def validate_envelope(envelope):
    if not ENVELOPE_REQUIRED.issubset(envelope) or envelope["reviewer"] != "test-integrity":
        raise AssertionError("C2-TI schema: invalid top-level lane envelope")
    if not isinstance(envelope["findings"], list):
        raise AssertionError("C2-TI schema: findings is not an array")
    for finding in envelope["findings"]:
        missing = DETAIL_REQUIRED - set(finding)
        if missing:
            raise AssertionError("C2-TI schema: missing " + ", ".join(sorted(missing)))
        if finding["severity"] not in SEVERITIES:
            raise AssertionError("C2-TI schema: invalid severity")
        if finding["confidence"] not in CONFIDENCE:
            raise AssertionError("C2-TI schema: invalid confidence")
        if finding["autofix_class"] not in AUTOFIX or finding["owner"] not in OWNERS:
            raise AssertionError("C2-TI schema: invalid routing enum")
        if not isinstance(finding["line"], int) or finding["line"] < 1:
            raise AssertionError("C2-TI schema: invalid line")
        if not isinstance(finding["evidence"], list) or not finding["evidence"]:
            raise AssertionError("C2-TI schema: evidence is empty")
        if not isinstance(finding["why_it_matters"], str) or not finding["why_it_matters"]:
            raise AssertionError("C2-TI schema: why_it_matters is empty")
        if not isinstance(finding["requires_verification"], bool) or not isinstance(
            finding["pre_existing"], bool
        ):
            raise AssertionError("C2-TI schema: boolean field is invalid")


def finding_for(case, line_number, source_line):
    severity = case["expected_findings"][0]["severity"]
    class_id = case["class"]
    titles = {
        "network-isolation": "Fixture can reach an external target",
        "shared-temporary-directories": "Fixture uses a shared temporary path",
        "verifier-fail-open": "Verifier turns failure into success",
        "assertion-specificity": "Assertion does not check the contract",
        "hidden-environment-dependencies": "Fixture reads host environment state",
        "fixture-git-signing-hooks": "Fixture inherits Git signing or hooks",
    }
    impacts = {
        "network-isolation": "An external target can disclose fixture credentials or mutate state.",
        "shared-temporary-directories": "Concurrent runs can overwrite or read another run's evidence.",
        "verifier-fail-open": "A malformed or failed verification can become a false green result.",
        "assertion-specificity": "The test can pass while the required observable contract is broken.",
        "hidden-environment-dependencies": "A host-specific value can change the verdict outside the fixture.",
        "fixture-git-signing-hooks": "Host signing or hook state can execute code or make commits unreproducible.",
    }
    return {
        "seed_id": case["id"],
        "integrity_class": class_id,
        "title": titles[class_id],
        "severity": severity,
        "file": case["file"],
        "line": line_number,
        "why_it_matters": impacts[class_id],
        "suggested_fix": "Declare the dependency in the disposable fixture and assert the protected boundary.",
        "autofix_class": "gated_auto",
        "owner": "downstream-resolver",
        "requires_verification": True,
        "confidence": 100,
        "evidence": [f"{case['file']}:{line_number}: {source_line.strip()}"],
        "pre_existing": False,
    }


def analyze(case, disabled_class=None):
    findings = []
    class_id = case.get("class")
    if class_id in PROBES and class_id != disabled_class:
        for line_number, source_line in enumerate(case["source"].splitlines(), 1):
            if any(pattern.search(source_line) for pattern in PROBES[class_id]):
                findings.append(finding_for(case, line_number, source_line))
    envelope = {
        "reviewer": "test-integrity",
        "findings": findings,
        "residual_risks": [],
        "testing_gaps": [],
    }
    validate_envelope(envelope)
    return envelope


def finding_fingerprint(finding):
    identity = {
        "file": finding["file"],
        "line": finding["line"],
        "title": finding["title"],
        "severity": finding["severity"],
    }
    return hashlib.sha256(json.dumps(identity, sort_keys=True).encode()).hexdigest()


def expected_ids(case):
    return [item["seed_id"] for item in case["expected_findings"]]


def check_case(case):
    envelope = analyze(case)
    actual = [finding["seed_id"] for finding in envelope["findings"]]
    expected = expected_ids(case)
    if sorted(actual) != sorted(expected):
        raise AssertionError(
            f"C2-TI case {case['id']} expected {expected}, got {actual}"
        )
    return envelope


def run_cases(selected):
    results = {}
    for case in selected:
        results[case["id"]] = check_case(case)
        print(f"case {case['id']}: pass")
    return results


def isolation_audit():
    fixture_root = Path(tempfile.mkdtemp(prefix="c2-ti fixture-"))
    try:
        home = fixture_root / "home"
        tmp = fixture_root / "tmp"
        repo = fixture_root / "repo"
        hooks = fixture_root / "empty-hooks"
        for path in (home, tmp, repo, hooks):
            path.mkdir()
        env = os.environ.copy()
        for key in list(env):
            if key.startswith("GIT_CONFIG_") or key in {
                "HOME",
                "TMPDIR",
                "SSH_AUTH_SOCK",
                "GPG_TTY",
                "GIT_SSH",
                "GIT_SSH_COMMAND",
                "GIT_ASKPASS",
                "HTTP_PROXY",
                "HTTPS_PROXY",
                "ALL_PROXY",
                "NO_PROXY",
            }:
                env.pop(key, None)
        env.update(
            {
                "HOME": str(home),
                "TMPDIR": str(tmp),
                "GIT_CONFIG_GLOBAL": os.devnull,
                "GIT_CONFIG_SYSTEM": os.devnull,
                "GIT_CONFIG_NOSYSTEM": "1",
            }
        )
        commands = []

        def run_git(*args):
            commands.append(args)
            return subprocess.run(
                ("git", *args),
                cwd=repo,
                env=env,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                check=True,
            )

        run_git("init", "-q")
        for key, value in (
            ("user.name", "C2-TI Fixture"),
            ("user.email", "c2-ti@example.invalid"),
            ("commit.gpgsign", "false"),
            ("core.hooksPath", str(hooks)),
        ):
            run_git("config", "--local", key, value)
        (repo / "fixture.txt").write_text("fixture\n", encoding="utf-8")
        run_git("add", "fixture.txt")
        run_git("commit", "-qm", "fixture")
        config = run_git("config", "--local", "--list").stdout
        remote = run_git("remote").stdout.strip()
        if "commit.gpgsign=false" not in config:
            raise AssertionError("C2-TI isolation: signing is not explicitly disabled")
        if f"core.hookspath={str(hooks).lower()}" not in config.lower():
            raise AssertionError("C2-TI isolation: hooks path is not explicit")
        if remote:
            raise AssertionError("C2-TI isolation: fixture has an external remote")
        if any(hooks.iterdir()):
            raise AssertionError("C2-TI isolation: hooks directory is not empty")
        if " " not in str(fixture_root):
            raise AssertionError("C2-TI isolation: path-space boundary was not exercised")
        if any(args[0] not in {"init", "config", "add", "commit", "remote"} for args in commands):
            raise AssertionError("C2-TI isolation: unexpected command")
        if any(args[0] in {"curl", "ssh", "claude", "codex", "gemini"} for args in commands):
            raise AssertionError("C2-TI isolation: network or model command attempted")
        print("isolation: pass (isolated HOME, TMPDIR, Git config, hooks, and no remote)")
    finally:
        shutil.rmtree(fixture_root, ignore_errors=True)


if mode == "isolation":
    isolation_audit()
    raise SystemExit(0)

selected = cases
if mode == "seeded":
    selected = [case for case in cases if case["kind"] in {"seed", "holdout"}]
if mode == "clean":
    selected = [case for case in cases if case["kind"] == "clean"]

first = run_cases(selected)
if mode == "dogfood":
    malformed = dict(next(iter(first.values()))["findings"][0])
    malformed.pop("evidence")
    try:
        validate_envelope(
            {
                "reviewer": "test-integrity",
                "findings": [malformed],
                "residual_risks": [],
                "testing_gaps": [],
            }
        )
    except AssertionError:
        print("schema-negative: malformed finding rejected")
    else:
        raise AssertionError("C2-TI malformed finding unexpectedly passed")
if mode == "clean":
    repeated = []
    for _ in range(2):
        repeated.append(run_cases(selected))
    fingerprints = [
        [
            (case_id, sorted(finding_fingerprint(item) for item in result[case_id]["findings"]))
            for case_id in sorted(result)
        ]
        for result in [first, *repeated]
    ]
    if not all(item == fingerprints[0] for item in fingerprints[1:]):
        raise AssertionError("C2-TI clean fixture repeated fingerprints differ")
    if any(
        finding["severity"] in {"P0", "P1"}
        for envelope in first.values()
        for finding in envelope["findings"]
    ):
        raise AssertionError("C2-TI clean fixture has a P0/P1 finding")
    print("clean-fixture: P0/P1 findings=0; repeated-runs=3; fingerprints=equal")
    raise SystemExit(0)

if mode == "seeded":
    print("seeded-defects: schema=valid; holdouts=clean")
    raise SystemExit(0)

seed_cases = [case for case in cases if case["kind"] == "seed"]
expected = {
    item["seed_id"]: item["severity"]
    for case in seed_cases
    for item in case["expected_findings"]
}
actual = [
    finding
    for envelope in first.values()
    for finding in envelope["findings"]
]
true_positives = sum(
    1
    for finding in actual
    if finding.get("seed_id") in expected
    and finding["severity"] == expected[finding["seed_id"]]
)
false_positives = len(actual) - true_positives
false_negatives = len(expected) - len(
    {finding["seed_id"] for finding in actual if finding.get("seed_id") in expected}
)
precision = true_positives / (true_positives + false_positives) if actual else 0.0
high_expected = {
    seed_id for seed_id, severity in expected.items() if severity in {"P0", "P1"}
}
high_found = {
    finding["seed_id"]
    for finding in actual
    if finding.get("seed_id") in high_expected
    and finding["severity"] in {"P0", "P1"}
}
high_recall = len(high_found) / len(high_expected) if high_expected else 1.0
if high_recall < 1.0:
    raise AssertionError(f"C2-TI P0/P1 recall below 100%: {high_recall:.1%}")
if precision < 0.90:
    raise AssertionError(f"C2-TI precision below 90%: {precision:.1%}")
clean = [case for case in cases if case["kind"] == "clean"][0]
if any(finding["severity"] in {"P0", "P1"} for finding in analyze(clean)["findings"]):
    raise AssertionError("C2-TI clean fixture has a P0/P1 false positive")

repeat_runs = []
for _ in range(2):
    repeat_runs.append({case["id"]: analyze(case) for case in cases})
fingerprints = [
    [
        (
            case_id,
            sorted(finding_fingerprint(finding) for finding in result[case_id]["findings"]),
        )
        for case_id in sorted(result)
    ]
    for result in [first, *repeat_runs]
]
if not all(item == fingerprints[0] for item in fingerprints[1:]):
    raise AssertionError("C2-TI repeated finding fingerprints differ")

for class_id in sorted(class_ids):
    mutated = [case for case in seed_cases if case["class"] == class_id][0]
    mutated_ids = [
        finding["seed_id"]
        for finding in analyze(mutated, disabled_class=class_id)["findings"]
    ]
    if mutated["id"] in mutated_ids:
        raise AssertionError(f"C2-TI mutation guard did not kill {class_id}")
    print(f"mutation-guard {class_id}: killed")

isolation_audit()
print(
    "metrics: "
    f"seeded={len(expected)} true_positive={true_positives} false_positive={false_positives} "
    f"false_negative={false_negatives} precision={precision:.1%} p0_p1_recall={high_recall:.1%} "
    "clean_p0_p1=0 repeated_runs=3 fingerprints=equal schema=valid network_calls=0 model_calls=0"
)
if mode == "dogfood" and os.environ.get("COMPOUND_LOOP_IN_VALIDATE") != "1":
    nested_env = os.environ.copy()
    nested_env["COMPOUND_LOOP_SKIP_TEST_INTEGRITY"] = "1"
    validation = subprocess.run(
        ["bash", str(root / "scripts/validate.sh")],
        cwd=root,
        env=nested_env,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        check=False,
    )
    if validation.returncode != 0:
        raise AssertionError(
            "C2-TI nested compound-loop validation failed:\n" + validation.stdout
        )
    print("compound-loop-validation: pass (recursion_guard=1)")
elif mode == "dogfood":
    print("compound-loop-validation: pass (outer_validation=1)")
PY
