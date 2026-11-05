#!/usr/bin/env python3
"""Plan, execute, and score model-based test-integrity reviews."""
import argparse
import hashlib
import json
import os
import re
import shlex
import subprocess
import sys
import time
from pathlib import Path

CHECKS_PATH = Path(__file__).resolve().parents[1] / "skills/reviewing/references/test-integrity.md"
SEVERITIES = ("P0", "P1", "P2", "P3")
# Case ids become file names under the plan directory; allow no path syntax.
CASE_ID = re.compile(r"[A-Za-z0-9][A-Za-z0-9._-]{0,127}")
TIMEOUT_SECONDS = 120


def fail(message):
    print("ERROR: " + message, file=sys.stderr)
    raise SystemExit(1)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def load_json(path):
    try:
        with open(path, "r", encoding="utf-8") as stream:
            return json.load(stream)
    except (OSError, ValueError) as exc:
        fail("cannot read JSON file %s: %s" % (path, exc))


def corpus_cases(paths):
    cases = []
    seen = set()
    classes = {}
    for path in paths:
        corpus = load_json(path)
        if corpus.get("schema") != "c2-ti/v1" or not isinstance(corpus.get("cases"), list):
            fail("invalid c2-ti/v1 corpus: " + str(path))
        for item in corpus.get("classes", []):
            if isinstance(item, dict) and item.get("id"):
                classes[item["id"]] = item.get("severity")
        for case in corpus["cases"]:
            if not isinstance(case, dict) or not all(key in case for key in ("id", "class", "kind", "file", "source", "expected_findings")):
                fail("invalid case in corpus: " + str(path))
            case_id = case["id"]
            if not isinstance(case_id, str) or not CASE_ID.fullmatch(case_id) or ".." in case_id or case_id in seen:
                fail("invalid or duplicate case id: " + repr(case_id))
            seen.add(case_id)
            cases.append(case)
    cases.sort(key=lambda case: case["id"])
    return cases, classes


def checks_text():
    text = CHECKS_PATH.read_text(encoding="utf-8")
    start = text.index("## Checks\n")
    end = text.find("\n## ", start + len("## Checks\n"))
    return text[start:] if end < 0 else text[start:end] + "\n"


def make_request(case, checks):
    system = checks + '\nReturn only JSON with this shape: {"findings":[{"integrity_class":"<one of: network-isolation, shared-temporary-directories, verifier-fail-open, assertion-specificity, hidden-environment-dependencies, fixture-git-signing-hooks>","severity":"P0|P1|P2|P3","line":1,"evidence":"<string>"}]}. Use an empty findings list when no integrity defect is present.'
    user = "Fixture file: " + case["file"] + "\n\nSource:\n" + case["source"]
    return {"messages": [{"role": "system", "content": system}, {"role": "user", "content": user}]}


def plan(args):
    cases, _ = corpus_cases(args.corpus)
    out = Path(args.out)
    requests = out / "requests"
    requests.mkdir(parents=True, exist_ok=True)
    checks = checks_text()
    entries = []
    total_bytes = 0
    for case in cases:
        payload = (json.dumps(make_request(case, checks), ensure_ascii=False, indent=2) + "\n").encode("utf-8")
        path = requests / (case["id"] + ".json")
        path.write_bytes(payload)
        total_bytes += len(payload)
        entries.append({"case_id": case["id"], "request": "requests/" + path.name, "sha256": digest(payload), "bytes": len(payload)})
    manifest = {"schema": "c2-ti-model-plan/v1", "request_count": len(entries), "total_bytes": total_bytes, "requests": entries}
    (out / "plan.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print("planned %d requests (%d bytes)" % (len(entries), total_bytes))


def run(args):
    plan_path = Path(args.plan).resolve()
    plan_bytes = plan_path.read_bytes()
    if args.approval != digest(plan_bytes):
        fail("approval digest does not match plan.json")
    try:
        argv = shlex.split(args.command)
    except ValueError as exc:
        fail("invalid command template: " + str(exc))
    if not argv:
        fail("command must not be empty")
    manifest = json.loads(plan_bytes.decode("utf-8"))
    responses = plan_path.parent / "responses"
    responses.mkdir(parents=True, exist_ok=True)
    for entry in manifest.get("requests", []):
        case_id = entry.get("case_id")
        if not isinstance(case_id, str) or not CASE_ID.fullmatch(case_id) or ".." in case_id or entry.get("request") != "requests/" + case_id + ".json":
            fail("invalid plan entry: " + repr(case_id))
        request_path = plan_path.parent / entry["request"]
        request_bytes = request_path.read_bytes()
        if digest(request_bytes) != entry.get("sha256"):
            fail("request digest mismatch: " + entry["case_id"])
        try:
            result = subprocess.run(argv, input=request_bytes, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=args.timeout, check=False)
            raw = result.stdout
            if result.returncode != 0:
                fail("command failed for case %s (exit %d)" % (entry["case_id"], result.returncode))
        except subprocess.TimeoutExpired:
            fail("command timed out for case " + entry["case_id"])
        (responses / (entry["case_id"] + ".json")).write_bytes(raw)
    print("stored %d raw responses in %s" % (len(manifest.get("requests", [])), responses))


def parse_findings(path):
    try:
        raw = path.read_text(encoding="utf-8")
        value = json.loads(raw)
        if isinstance(value, dict) and "result" in value:
            value = value["result"]
            if isinstance(value, str):
                value = json.loads(value)
        if not isinstance(value, dict) or not isinstance(value.get("findings"), list):
            return None
        found = []
        for finding in value["findings"]:
            if not isinstance(finding, dict):
                return None
            cls, severity = finding.get("integrity_class"), finding.get("severity")
            line, evidence = finding.get("line"), finding.get("evidence")
            if not isinstance(cls, str) or not isinstance(severity, str) or severity not in SEVERITIES:
                return None
            if not isinstance(line, int) or isinstance(line, bool) or line < 1 or not isinstance(evidence, str):
                return None
            found.append(finding)
        return found
    except (OSError, UnicodeError, ValueError):
        return None


def score(args):
    cases, classes = corpus_cases(args.corpus)
    response_dirs = [Path(item) for item in args.responses]
    if len(response_dirs) != args.repeat:
        fail("--repeat %d requires exactly %d response directories" % (args.repeat, args.repeat))
    if args.repeat < 1:
        fail("--repeat must be at least 1")
    predictions = []
    malformed = []
    details = []
    for response_dir in response_dirs:
        batch = {}
        for case in cases:
            findings = parse_findings(response_dir / (case["id"] + ".json"))
            if findings is None:
                malformed.append({"case_id": case["id"], "response_dir": str(response_dir)})
                batch[case["id"]] = None
            else:
                batch[case["id"]] = findings
        predictions.append(batch)
    repeat_mismatch = []
    if args.repeat > 1:
        for case in cases:
            sets = [None if batch[case["id"]] is None else sorted(set(f["integrity_class"] for f in batch[case["id"]])) for batch in predictions]
            if any(item != sets[0] for item in sets[1:]):
                repeat_mismatch.append(case["id"])
    tp = fp = expected_positive = p01_tp = p01_expected = p01_negative_fp = severity_match = predicted_count = 0
    per_class = {}
    for class_id, class_severity in sorted(classes.items()):
        per_class[class_id] = {"expected": 0, "true_positive": 0, "false_positive": 0, "severity_agreement": 0}
    for case in cases:
        expected = bool(case["expected_findings"])
        class_id = case["class"]
        class_severity = classes.get(class_id)
        if expected:
            expected_positive += 1
            per_class.setdefault(class_id, {"expected": 0, "true_positive": 0, "false_positive": 0, "severity_agreement": 0})["expected"] += 1
            if class_severity in ("P0", "P1"):
                p01_expected += 1
        findings = predictions[0][case["id"]]
        if findings is None:
            details.append({"case_id": case["id"], "status": "malformed-or-missing"})
            continue
        predicted = set(f["integrity_class"] for f in findings)
        predicted_count += len(findings)
        if expected and class_id in predicted:
            tp += 1
            per_class[class_id]["true_positive"] += 1
            if class_severity in ("P0", "P1"):
                p01_tp += 1
            if any(f["integrity_class"] == class_id and f["severity"] == class_severity for f in findings):
                severity_match += 1
                per_class[class_id]["severity_agreement"] += 1
        for f in findings:
            pred_class = f["integrity_class"]
            correct = expected and pred_class == class_id
            if not correct:
                fp += 1
                per_class.setdefault(pred_class, {"expected": 0, "true_positive": 0, "false_positive": 0, "severity_agreement": 0})["false_positive"] += 1
                if not expected and f["severity"] in ("P0", "P1"):
                    p01_negative_fp += 1
            if pred_class not in classes:
                # Unknown class identifiers are malformed schema values.
                malformed.append({"case_id": case["id"], "reason": "unknown class " + pred_class})
        details.append({"case_id": case["id"], "expected_class": class_id if expected else None, "predicted_classes": sorted(predicted)})
    precision = float(tp) / predicted_count if predicted_count else (1.0 if expected_positive == 0 else 0.0)
    recall = float(tp) / expected_positive if expected_positive else 1.0
    p01_recall = float(p01_tp) / p01_expected if p01_expected else 1.0
    report = {"positive_recall": recall, "p0_p1_recall": p01_recall, "precision": precision, "clean_negative_p0_p1_false_positives": p01_negative_fp, "malformed_responses": malformed, "repeat_mismatches": repeat_mismatch, "severity_agreement_count": severity_match, "predicted_finding_count": predicted_count, "true_positive_count": tp, "false_positive_count": fp, "per_class": per_class, "cases": details}
    print(json.dumps(report, indent=2, sort_keys=True))
    if p01_recall < 1.0 or precision < 0.90 or p01_negative_fp or malformed or repeat_mismatch:
        raise SystemExit(1)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="action", required=True)
    plan_parser = sub.add_parser("plan")
    plan_parser.add_argument("--corpus", action="append", required=True)
    plan_parser.add_argument("--out", required=True)
    plan_parser.set_defaults(func=plan)
    run_parser = sub.add_parser("run")
    run_parser.add_argument("--plan", required=True)
    run_parser.add_argument("--command", required=True)
    run_parser.add_argument("--approval", required=True)
    run_parser.add_argument("--timeout", type=float, default=TIMEOUT_SECONDS)
    run_parser.set_defaults(func=run)
    score_parser = sub.add_parser("score")
    score_parser.add_argument("--plan", required=True)
    score_parser.add_argument("--responses", nargs="+", required=True)
    score_parser.add_argument("--corpus", action="append", required=True)
    score_parser.add_argument("--repeat", type=int, default=1)
    score_parser.set_defaults(func=score)
    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
