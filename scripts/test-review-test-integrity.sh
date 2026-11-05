#!/usr/bin/env bash
# C2-TI deterministic fixture evaluator. It uses only the standard library.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODE="${1:-dogfood}"

if [[ "$MODE" == "contract" ]]; then
  python3 - "$ROOT/skills/reviewing/references/lanes.md" "$ROOT/skills/reviewing/SKILL.md" "$ROOT/skills/reviewing/references/test-integrity.md" "$ROOT/skills/reviewing/references/merge-pipeline.md" <<'PY'
import sys
from pathlib import Path

text = "\n".join(Path(path).read_text(encoding="utf-8") for path in sys.argv[1:])
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
    "every phase-gate review",
    "test-integrity-run/v1",
    "missing, cancelled, or malformed",
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
corpus_path = Path(os.environ.get("C2_TI_CORPUS", root / "tests/conformance/review/test-integrity-corpus.json"))
schema_path = root / "schemas/lane-findings.schema.json"

if mode not in {"dogfood", "seeded", "clean", "isolation", "records", "record"}:
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
CLASS_SEVERITY = {
    "network-isolation": "P1",
    "shared-temporary-directories": "P1",
    "verifier-fail-open": "P1",
    "assertion-specificity": "P2",
    "hidden-environment-dependencies": "P1",
    "fixture-git-signing-hooks": "P1",
}
classes = {item["id"]: item for item in corpus.get("classes", [])}
if set(classes) != class_ids:
    raise SystemExit(f"C2-TI class inventory mismatch: {sorted(classes)}")
for class_id, severity in CLASS_SEVERITY.items():
    if classes[class_id].get("severity") != severity:
        raise SystemExit(f"C2-TI corpus class severity disagrees with analyzer for {class_id}")

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
    if len([case for case in members if case["kind"] == "seed"]) < 2:
        raise SystemExit(f"C2-TI requires at least two seeds for {class_id}")
if len([case for case in cases if case["kind"] == "clean"]) < 1:
    raise SystemExit("C2-TI requires at least one clean fixture")
extra_holdouts = []
holdout_path = os.environ.get("C2_TI_HOLDOUTS")
if holdout_path:
    extra = json.loads(Path(holdout_path).read_text(encoding="utf-8"))
    if extra.get("schema") != "c2-ti/v1":
        raise SystemExit("C2-TI holdout corpus schema is unknown")
    extra_holdouts = extra.get("cases", [])
    if any(case.get("kind") != "holdout" for case in extra_holdouts):
        raise SystemExit("C2-TI external corpus may contain holdouts only")
    known_ids = set(case_ids)
    for case in extra_holdouts:
        if case.get("id") in known_ids or case.get("class") not in class_ids:
            raise SystemExit(f"C2-TI invalid or duplicate external holdout: {case.get('id')}")
        known_ids.add(case["id"])
        if not isinstance(case.get("source"), str) or not case["source"] or not isinstance(case.get("expected_findings"), list):
            raise SystemExit(f"C2-TI malformed external holdout: {case.get('id')}")
    for class_id in class_ids:
        members = [case for case in extra_holdouts if case["class"] == class_id]
        if not any(case["expected_findings"] for case in members) or not any(not case["expected_findings"] for case in members):
            raise SystemExit(f"C2-TI external holdouts require positive and negative cases for {class_id}")

PROBES = {
    "network-isolation": (
        re.compile(r"\b(?:requests|httpx|urllib\.request|aiohttp)\.(?:get|post|put|delete|request|urlopen|urlretrieve)\s*\("),
        re.compile(r"\b(?:socket\.(?:create_connection|socket|connect)|create_connection|urlopen|urlretrieve)\s*\("),
        re.compile(r"\b(?:curl|wget|ssh|scp|sftp|nc|ncat|netcat|ping|ftp)\b.{0,180}(?:https?://|ftp://|\s-[A-Za-z]*[pP]|@[\w.-]+)"),
        re.compile(r"\b(?:pip|pip3|uv|npm|npx|yarn|pnpm)\s+(?:install|download|add|exec)\b"),
        re.compile(r"\b(?:git|git-remote-[\w-]+)\b.{0,160}\b(?:clone|fetch|pull|push)\b.{0,160}(?:https?://|ssh://|git@)"),
        re.compile(r"subprocess\.(?:run|call|Popen|check_call|check_output)\s*\([^)]*(?:curl|wget|ssh|scp|pip|uv|npm|https?://)"),
    ),
    "shared-temporary-directories": (
        re.compile(r"(?:[\"']|Path\s*\()/?(?:tmp|var/tmp)/[^\"']+"),
        re.compile(r"tempfile\.gettempdir\(\)(?!\s*/\s*(?:tempfile\.)?mkdtemp)"),
        re.compile(r"(?:mkdir(?:\s+-p)?|Path\([^)]*\)\.mkdir)[^\n]*(?:/tmp/|/var/tmp/|(?:integration|project|fixture|test|output|cache)[-_](?:artifacts|data|dir|root|path|files))"),
        re.compile(r"(?:shutil\.)?rmtree\(\s*[\"'](?:/tmp|/var/tmp|fixture|test|output|cache|repo)[^\"']*[\"']"),
        re.compile(r"\brm\s+-[^\n]*\s(?:/tmp|/var/tmp|[\"']?(?:fixture|test|output|cache|repo)[-_](?:dir|root|path|files))"),
        re.compile(r"(?:fixture|output|cache|repo)[-_](?:dir|root|path|socket|log|repo)\s*=\s*(?:[\"']|Path\s*\()"),
    ),
    "verifier-fail-open": (
        re.compile(r"except(?:\s+[^:]+)?:\s*(?:return\s+(?:True|['\"](?:clean|pass|success)['\"]|\[\])|pass)\b"),
        re.compile(r"subprocess\.(?:run|call|check_call|check_output)\([^\n]*\bcheck\s*=\s*False"),
        re.compile(r"(?:verdict|status|result)\s*=\s*['\"](?:clean|pass|success)['\"]"),
        re.compile(r"(?:return|default)\s*[:=]\s*(?:True|['\"](?:clean|pass|success)['\"]|\[\])"),
        re.compile(r"\|\|\s*true\b"),
        re.compile(r"\b(?:except|catch)\b[^\n]*(?:Exception|Error)[^\n]*(?:continue|pass|return\s+None|return\s+True)"),
        re.compile(r"\b(?:result|completed|response)\s*=\s*subprocess\.(?:run|call)\s*\("),
    ),
    "assertion-specificity": (
        re.compile(r"^\s*assert\s+(?:True|False|[A-Za-z_]\w*(?:\.[A-Za-z_]\w*)?)\s*(?:#.*)?$"),
        re.compile(r"^\s*assert\s+['\"][^'\"]+['\"]\s+in\s+[^#]+$"),
        re.compile(r"^\s*assert\s+[^#]*(?:stdout|stderr|output)\s+in\s+[^#]+$"),
        re.compile(r"^\s*assert\s+len\([^)]*\)\s*>\s*0\s*(?:#.*)?$"),
        re.compile(r"^\s*assert\s+[^#]*\.exit_code\s*(?:==\s*0)?\s*(?:#.*)?$"),
        re.compile(r"\bgrep\s+-q\s+['\"][^'\"]+['\"]"),
    ),
    "hidden-environment-dependencies": (
        re.compile(r"os\.environ\[\s*['\"](?:HOME|PATH|TMPDIR|SSH_AUTH_SOCK|HTTP_PROXY|HTTPS_PROXY|ALL_PROXY|NO_PROXY|GPG_TTY|LANG|LC_ALL|LC_CTYPE|TZ|GIT_CONFIG_[A-Z_]+|[A-Z_]*(?:TOKEN|KEY|PASSWORD))['\"]\s*\]"),
        re.compile(r"os\.(?:getenv|environ\.get)\(\s*['\"](?:HOME|PATH|TMPDIR|SSH_AUTH_SOCK|HTTP_PROXY|HTTPS_PROXY|ALL_PROXY|NO_PROXY|GPG_TTY|LANG|LC_ALL|LC_CTYPE|TZ|GIT_CONFIG_[A-Z_]+|[A-Z_]*(?:TOKEN|KEY|PASSWORD))['\"]"),
        re.compile(r"\bPath\.home\s*\("),
        re.compile(r"\b(?:os\.path\.expanduser|expanduser)\s*\("),
        re.compile(r"\b(?:getpass\.get(?:user|pass)|getuser)\s*\("),
        re.compile(r"\b(?:shutil\.which|which)\s*\("),
        re.compile(r"\bcommand\s+-v\s+[A-Za-z0-9_.+-]+"),
        re.compile(r"\b(?:locale\.getpreferredencoding|locale\.getlocale|time\.tzname|datetime\.now)\s*\("),
        re.compile(r"\b(?:env|printenv)\s+(?:HOME|PATH|TMPDIR|LANG|LC_ALL|TZ|HTTP_PROXY|HTTPS_PROXY|ALL_PROXY|NO_PROXY)\b"),
        re.compile(r"\bgit\s+config\s+(?:--global|--system)\b"),
    ),
    "fixture-git-signing-hooks": (
        re.compile(r"['\"]git['\"].{0,140}['\"]config['\"].{0,140}['\"]--(?:global|system)['\"]"),
        re.compile(r"\bgit\s+config\s+(?:--global|--system)\b"),
    ),
}
def validate_json_schema(value, schema, path="root"):
    expected_type = schema.get("type")
    if expected_type:
        types = {expected_type} if isinstance(expected_type, str) else set(expected_type)

        def matches(type_name):
            if type_name == "object":
                return isinstance(value, dict)
            if type_name == "array":
                return isinstance(value, list)
            if type_name == "string":
                return isinstance(value, str)
            if type_name == "integer":
                return isinstance(value, int) and not isinstance(value, bool)
            if type_name == "boolean":
                return isinstance(value, bool)
            if type_name == "null":
                return value is None
            return True

        if not any(matches(type_name) for type_name in types):
            raise AssertionError(f"C2-TI schema: {path} has an invalid type")
    if "enum" in schema and value not in schema["enum"]:
        raise AssertionError(f"C2-TI schema: {path} has an invalid enum value")
    if isinstance(value, str) and "maxLength" in schema and len(value) > schema["maxLength"]:
        raise AssertionError(f"C2-TI schema: {path} exceeds maxLength")
    if isinstance(value, int) and "minimum" in schema and value < schema["minimum"]:
        raise AssertionError(f"C2-TI schema: {path} is below minimum")
    if isinstance(value, list):
        if "minItems" in schema and len(value) < schema["minItems"]:
            raise AssertionError(f"C2-TI schema: {path} has too few items")
        item_schema = schema.get("items")
        if item_schema:
            for index, item in enumerate(value):
                validate_json_schema(item, item_schema, f"{path}[{index}]")
    if isinstance(value, dict):
        for key in schema.get("required", []):
            if key not in value:
                raise AssertionError(f"C2-TI schema: {path} missing {key}")
        for key, property_schema in schema.get("properties", {}).items():
            if key in value:
                validate_json_schema(value[key], property_schema, f"{path}.{key}")


def validate_envelope(envelope):
    validate_json_schema(envelope, lane_schema, "envelope")
    if envelope["reviewer"] != "test-integrity":
        raise AssertionError("C2-TI schema: invalid reviewer")
    for finding in envelope["findings"]:
        if not finding["evidence"] or not finding["why_it_matters"]:
            raise AssertionError("C2-TI schema: detail field is empty")


def finding_for(case, class_id, line_number, source_line):
    severity = CLASS_SEVERITY[class_id]
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
    # The case ID identifies its seeded defect; cross-class matches are distinct
    # observations and therefore cannot be mistaken for expected true positives.
    seed_id = case["id"] if case.get("class") == class_id else f"{case['id']}@{class_id}"
    return {
        "seed_id": seed_id,
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


def analyze(case):
    findings = []
    source_lines = case["source"].splitlines()
    output_asserted = any(
        re.search(r"^\s*assert\s+[^#]*(?:stdout|stderr|output)[^#]*(?:==|!=)", line)
        for line in source_lines
    )
    for class_id, patterns in PROBES.items():
        for line_number, source_line in enumerate(source_lines, 1):
            if class_id == "assertion-specificity" and output_asserted and ".exit_code" in source_line:
                continue
            if any(pattern.search(source_line) for pattern in patterns):
                findings.append(finding_for(case, class_id, line_number, source_line))
    joined_source = case["source"]
    if re.search(r"except\s+(?:Exception|BaseException|\w+Error)\s*:\s*\n(?:[ \t]+[^\n]*\n)*[ \t]+return\s+(?:True|['\"](?:clean|pass|success)['\"]|\[\])", joined_source):
        line_number = next((i for i, line in enumerate(source_lines, 1) if re.search(r"except\s+(?:Exception|BaseException|\w+Error)", line)), None)
        if line_number is not None and not any(f["integrity_class"] == "verifier-fail-open" for f in findings):
            findings.append(finding_for(case, "verifier-fail-open", line_number, source_lines[line_number - 1]))
    git_source = case["source"]
    git_setup = re.search(r"\bgit\b.*\b(?:init|commit)\b(?![.\w])", git_source)
    hooks_unverified = not re.search(r"\bcore\.hooksPath\b", git_source) or (
        re.search(r"\bcore\.hooksPath\s*=\s*(?:\"\"|''|(?=\s+-c))", git_source)
        and not re.search(r"iterdir\(\)\)\s*==\s*\[\]", git_source)
    )
    if git_setup and hooks_unverified and not any(f["integrity_class"] == "fixture-git-signing-hooks" for f in findings):
        git_line = next((i for i, line in enumerate(source_lines, 1) if re.search(r"\bgit\b.*\b(?:init|commit)\b", line)), None)
        if git_line is not None:
            findings.append(finding_for(case, "fixture-git-signing-hooks", git_line, source_lines[git_line - 1]))
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
    if case["expected_findings"]:
        expected_severity = {
            item["seed_id"]: item["severity"] for item in case["expected_findings"]
        }
        class_severity = CLASS_SEVERITY[case["class"]]
        if any(severity != class_severity for severity in expected_severity.values()):
            raise AssertionError(
                f"C2-TI case {case['id']} expected severity disagrees with class "
                f"{case['class']} ({class_severity})"
            )
        for finding in envelope["findings"]:
            if finding["severity"] != expected_severity[finding["seed_id"]]:
                raise AssertionError(
                    f"C2-TI case {case['id']} severity mismatch for "
                    f"{finding['seed_id']}: expected {expected_severity[finding['seed_id']]}, "
                    f"got {finding['severity']}"
                )
    return envelope


def validate_run_record(record):
    if not isinstance(record, dict) or record.get("schema") != "test-integrity-run/v1":
        raise AssertionError("C2-TI run record missing or malformed")
    if not isinstance(record.get("run_id"), str) or not record["run_id"]:
        raise AssertionError("C2-TI run record identity is malformed")
    if record.get("event_id") != os.environ.get("COMPOUND_LOOP_TEST_INTEGRITY_EVENT_ID"):
        raise AssertionError("C2-TI run record event does not match current review event")
    if record.get("reviewed_head") != os.environ.get("COMPOUND_LOOP_TEST_INTEGRITY_REVIEWED_HEAD"):
        raise AssertionError("C2-TI run record head does not match current reviewed head")
    if record.get("status") != "complete":
        raise AssertionError("C2-TI run record is not complete")
    if not isinstance(record.get("raw_evidence"), list):
        raise AssertionError("C2-TI run record raw evidence is malformed")
    if not isinstance(record.get("normalized_findings"), list):
        raise AssertionError("C2-TI run record findings are malformed")
    for index, finding in enumerate(record["normalized_findings"]):
        validate_json_schema(finding, lane_schema["properties"]["findings"]["items"], f"normalized_findings[{index}]")


def load_run_record(path):
    record = json.loads(Path(path).read_text(encoding="utf-8"))
    validate_run_record(record)
    return record


if mode == "record":
    record_path = os.environ.get("COMPOUND_LOOP_TEST_INTEGRITY_RECORD")
    if not record_path:
        raise SystemExit("C2-TI record mode requires COMPOUND_LOOP_TEST_INTEGRITY_RECORD")
    try:
        load_run_record(record_path)
    except (OSError, json.JSONDecodeError, AssertionError) as error:
        raise SystemExit(str(error))
    print("C2-TI persisted run record: complete")
    raise SystemExit(0)

if mode == "records":
    with tempfile.TemporaryDirectory(prefix="c2-ti-record-") as temp_root:
        os.environ["COMPOUND_LOOP_TEST_INTEGRITY_EVENT_ID"] = "current-event"
        os.environ["COMPOUND_LOOP_TEST_INTEGRITY_REVIEWED_HEAD"] = "current-head"
        missing_path = Path(temp_root) / "missing.json"
        invalid_records = (
            {"schema": "test-integrity-run/v1", "run_id": "run-1", "event_id": "current-event", "reviewed_head": "current-head",
             "status": "cancelled", "raw_evidence": [], "normalized_findings": []},
            {"schema": "test-integrity-run/v1", "run_id": "run-1", "event_id": "current-event", "reviewed_head": "current-head",
             "status": "complete", "raw_evidence": {}, "normalized_findings": []},
            {"schema": "test-integrity-run/v1", "run_id": "run-1", "event_id": "current-event", "reviewed_head": "current-head",
             "status": "complete", "raw_evidence": [], "normalized_findings": [1, "x", {}]},
            {"schema": "test-integrity-run/v1", "run_id": "run-1", "event_id": "old-event", "reviewed_head": "current-head",
             "status": "complete", "raw_evidence": [], "normalized_findings": []},
            {"schema": "test-integrity-run/v1", "run_id": "run-1", "event_id": "current-event", "reviewed_head": "old-head",
             "status": "complete", "raw_evidence": [], "normalized_findings": []},
        )
        try:
            load_run_record(missing_path)
        except FileNotFoundError:
            pass
        else:
            raise AssertionError("C2-TI missing run record unexpectedly passed")
        for index, record in enumerate(invalid_records):
            record_path = Path(temp_root) / f"invalid-{index}.json"
            record_path.write_text(json.dumps(record), encoding="utf-8")
            try:
                load_run_record(record_path)
            except (json.JSONDecodeError, AssertionError):
                continue
            raise AssertionError(f"C2-TI accepted invalid run record: {record!r}")
    print("C2-TI run-record fail-closed cases: missing=blocked cancelled=blocked malformed=blocked stale-event=blocked stale-head=blocked")
    raise SystemExit(0)


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
holdout_results = {case["id"]: check_case(case) for case in extra_holdouts}
for case in extra_holdouts:
    print(f"holdout {case['id']}: pass")
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
    p0_p1 = sum(
        finding["severity"] in {"P0", "P1"}
        for envelope in first.values()
        for finding in envelope["findings"]
    )
    print(
        f"clean-fixture: cases={len(selected)} P0/P1 findings={p0_p1}; "
        "repeated-runs=3; fingerprints=equal"
    )
    raise SystemExit(0)

if mode == "seeded":
    seed_count = sum(case["kind"] == "seed" for case in selected)
    positive_count = sum(bool(case["expected_findings"]) for case in extra_holdouts)
    negative_count = sum(not case["expected_findings"] for case in cases if case["kind"] == "holdout") + sum(not case["expected_findings"] for case in extra_holdouts)
    print(f"seeded-defects: seeds={seed_count} positive_holdouts={positive_count} negative_holdouts={negative_count}; schema=valid")
    raise SystemExit(0)

seed_cases = [case for case in cases if case["kind"] == "seed"]
base_holdouts = [case for case in cases if case["kind"] == "holdout"]
positive_holdouts = [case for case in base_holdouts + extra_holdouts if case["expected_findings"]]
negative_holdouts = [case for case in base_holdouts + extra_holdouts if not case["expected_findings"]]
seed_expected = {case["id"]: CLASS_SEVERITY[case["class"]] for case in seed_cases}
holdout_expected = {case["id"]: CLASS_SEVERITY[case["class"]] for case in positive_holdouts}
expected = {**seed_expected, **holdout_expected}
actual = [finding for envelope in first.values() for finding in envelope["findings"]]
actual.extend(finding for result in holdout_results.values() for finding in result["findings"])
holdout_actual = [finding for case in base_holdouts for finding in first[case["id"]]["findings"]]
holdout_actual.extend(finding for result in holdout_results.values() for finding in result["findings"])
found_ids = {finding["seed_id"] for finding in actual if finding["seed_id"] in expected and finding["severity"] == expected[finding["seed_id"]]}
true_positives = len(found_ids)
false_positives = len(actual) - true_positives
false_negatives = len(expected) - true_positives
precision = true_positives / (true_positives + false_positives) if actual else 1.0
seed_recall = len(found_ids.intersection(seed_expected)) / len(seed_expected) if seed_expected else 1.0
positive_ids = set(holdout_expected)
holdout_found = {finding["seed_id"] for finding in holdout_actual if finding["seed_id"] in positive_ids and finding["severity"] == holdout_expected[finding["seed_id"]]}
holdout_tp = len(holdout_found)
holdout_fp = len(holdout_actual) - holdout_tp
positive_holdout_recall = holdout_tp / len(positive_ids) if positive_ids else None
holdout_precision = holdout_tp / (holdout_tp + holdout_fp) if holdout_tp + holdout_fp else None
high_expected = {
    seed_id for seed_id, severity in seed_expected.items() if severity in {"P0", "P1"}
}
high_found = found_ids.intersection(high_expected)
high_recall = len(high_found) / len(high_expected) if high_expected else 1.0
if seed_recall < 1.0:
    raise AssertionError(f"C2-TI seed recall below 100%: {seed_recall:.1%}")
if positive_holdout_recall is not None and positive_holdout_recall < 1.0:
    raise AssertionError(
        f"C2-TI positive-holdout recall below 100%: {positive_holdout_recall:.1%}"
    )
if high_recall < 1.0:
    raise AssertionError(f"C2-TI P0/P1 seed recall below 100%: {high_recall:.1%}")
if precision < 0.90:
    raise AssertionError(f"C2-TI precision below 90%: {precision:.1%}")
clean_cases = [case for case in cases if case["kind"] == "clean"]
for clean in clean_cases:
    if any(
        finding["severity"] in {"P0", "P1"}
        for finding in analyze(clean)["findings"]
    ):
        raise AssertionError(f"C2-TI clean fixture {clean['id']} has a P0/P1 finding")

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
    seed = next(case for case in seed_cases if case["class"] == class_id)
    matching_lines = [
        line for line in seed["source"].splitlines()
        if any(pattern.search(line) for pattern in PROBES[class_id])
    ]
    if not matching_lines:
        raise AssertionError(
            f"C2-TI mutation setup failed: no seeded defect line in {seed['id']}"
        )
    source_lines = seed["source"].splitlines()
    source_lines.remove(matching_lines[0])
    mutated = {**seed, "source": "\n".join(source_lines) + "\n"}
    try:
        check_case(mutated)
    except AssertionError as error:
        if seed["id"] not in str(error):
            raise AssertionError(
                f"C2-TI mutation setup failure for {seed['id']}: {error}"
            ) from error
        print(f"mutation-guard {class_id}: killed by removing {seed['id']} defect line")
    else:
        raise AssertionError(
            f"C2-TI mutation guard survived removal of {seed['id']} defect line"
        )
record_contract = subprocess.run(
    ["bash", str(root / "scripts/test-review-test-integrity.sh"), "records"],
    cwd=root,
    stdout=subprocess.PIPE,
    stderr=subprocess.STDOUT,
    text=True,
    check=False,
)
if record_contract.returncode != 0:
    raise AssertionError("C2-TI record fail-closed evaluator failed:\n" + record_contract.stdout)
print(record_contract.stdout.strip())
isolation_audit()
holdout_recall_display = f"{positive_holdout_recall:.1%}" if positive_holdout_recall is not None else "not-evaluated"
holdout_precision_display = f"{holdout_precision:.1%}" if holdout_precision is not None else "not-evaluated"
print(
    "metrics: "
    f"seeds={len(seed_expected)} seed_recall={seed_recall:.1%} "
    f"positive_holdouts={len(holdout_expected)} negative_holdouts={len(negative_holdouts)} "
    f"positive_holdout_recall={holdout_recall_display} holdout_precision={holdout_precision_display} "
    f"true_positive={true_positives} false_positive={false_positives} "
    f"false_negative={false_negatives} precision={precision:.1%} "
    f"p0_p1_seed_recall={high_recall:.1%} "
    f"clean_p0_p1=0 repeated_runs=3 fingerprints=equal schema=valid "
    "network_calls=0 model_calls=0"
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
