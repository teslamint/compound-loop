#!/usr/bin/env bash
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
python3 - "$ROOT" <<'PY'
import hashlib
import json
import pathlib
import subprocess
import sys
import tempfile

root = pathlib.Path(sys.argv[1])
script = root / "scripts/eval-test-integrity-model.py"
classes = [
    {"id": "network-isolation", "severity": "P1"},
    {"id": "assertion-specificity", "severity": "P2"},
]
cases = [
    {"id": "CASE-SECRET-1", "class": "network-isolation", "kind": "seed", "file": "fixture.py", "source": "requests.get('https://example.invalid')", "expected_findings": [{"seed_id": "CASE-SECRET-1", "severity": "P1"}]},
    {"id": "CASE-SECRET-CLEAN", "class": "network-isolation", "kind": "clean", "file": "clean.py", "source": "assert 1 == 1", "expected_findings": []},
]

def call(args, expected=0):
    result = subprocess.run([sys.executable, str(script)] + args, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if (result.returncode == 0) != (expected == 0):
        raise AssertionError("unexpected exit %d: %s\n%s" % (result.returncode, result.stdout, result.stderr))
    return result

with tempfile.TemporaryDirectory(prefix="c2ti-model-test-") as temporary:
    base = pathlib.Path(temporary)
    corpus = base / "corpus.json"
    corpus.write_text(json.dumps({"schema": "c2-ti/v1", "classes": classes, "cases": cases}), encoding="utf-8")
    plan_dir = base / "plan"
    call(["plan", "--corpus", str(corpus), "--out", str(plan_dir)])
    plan_path = plan_dir / "plan.json"
    manifest = json.loads(plan_path.read_text(encoding="utf-8"))
    assert manifest["request_count"] == 2
    request = json.loads((plan_dir / "requests/CASE-SECRET-1.json").read_text(encoding="utf-8"))
    encoded = json.dumps(request)
    for forbidden in ("CASE-SECRET-1", "seed_id", "expected_findings"):
        assert forbidden not in encoded, "prompt leaked " + forbidden
    user_content = request["messages"][1]["content"]
    assert "network-isolation" not in user_content
    assert "seed" not in user_content
    approval = hashlib.sha256(plan_path.read_bytes()).hexdigest()
    call(["run", "--plan", str(plan_path), "--command", "true", "--approval", "0" * 64], expected=1)
    fake = base / "fake_model.py"
    fake.write_text(
        "import json, sys\n"
        "request = json.load(sys.stdin)\n"
        "source = request['messages'][1]['content']\n"
        "findings = [] if 'clean.py' in source else [{'integrity_class':'network-isolation','severity':'P1','line':1,'evidence':'network call'}]\n"
        "print(json.dumps({'findings': findings}))\n",
        encoding="utf-8",
    )
    import shlex
    fake_command = shlex.quote(sys.executable) + " " + shlex.quote(str(fake))
    call(["run", "--plan", str(plan_path), "--command", fake_command, "--approval", approval])


    good = base / "good"
    good.mkdir()
    (good / "CASE-SECRET-1.json").write_text(json.dumps({"findings": [{"integrity_class": "network-isolation", "severity": "P1", "line": 1, "evidence": "network call"}]}), encoding="utf-8")
    (good / "CASE-SECRET-CLEAN.json").write_text('{"findings": []}', encoding="utf-8")
    call(["score", "--plan", str(plan_path), "--responses", str(good), "--corpus", str(corpus)])

    malformed = base / "malformed"
    malformed.mkdir()
    (malformed / "CASE-SECRET-1.json").write_text("not json", encoding="utf-8")
    call(["score", "--plan", str(plan_path), "--responses", str(malformed), "--corpus", str(corpus)], expected=1)
    missing = base / "missing"
    missing.mkdir()
    call(["score", "--plan", str(plan_path), "--responses", str(missing), "--corpus", str(corpus)], expected=1)

    cross = base / "cross"
    cross.mkdir()
    (cross / "CASE-SECRET-1.json").write_text(json.dumps({"findings": [{"integrity_class": "assertion-specificity", "severity": "P2", "line": 1, "evidence": "wrong class"}]}), encoding="utf-8")
    (cross / "CASE-SECRET-CLEAN.json").write_text('{"findings": []}', encoding="utf-8")
    cross_result = call(["score", "--plan", str(plan_path), "--responses", str(cross), "--corpus", str(corpus)], expected=1)
    cross_report = json.loads(cross_result.stdout)
    assert cross_report["false_positive_count"] == 1

    repeat_a = base / "repeat-a"
    repeat_b = base / "repeat-b"
    repeat_a.mkdir(); repeat_b.mkdir()
    for directory in (repeat_a, repeat_b):
        (directory / "CASE-SECRET-CLEAN.json").write_text('{"findings": []}', encoding="utf-8")
    (repeat_a / "CASE-SECRET-1.json").write_text('{"findings": []}', encoding="utf-8")
    (repeat_b / "CASE-SECRET-1.json").write_text(json.dumps({"findings": [{"integrity_class": "network-isolation", "severity": "P1", "line": 1, "evidence": "network call"}]}), encoding="utf-8")
    repeat_result = call(["score", "--plan", str(plan_path), "--responses", str(repeat_a), str(repeat_b), "--corpus", str(corpus), "--repeat", "2"], expected=1)
    assert "repeat_mismatches" in repeat_result.stdout

print("ALL MODEL EVALUATOR FIXTURES PASSED")
PY
