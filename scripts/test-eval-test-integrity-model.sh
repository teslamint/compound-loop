#!/usr/bin/env bash
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
python3 - "$ROOT" <<'PY'
import hashlib
import json
import os
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

call_log = None

def call(args, expected=0):
    env = dict(os.environ, C2TI_FAKE_LOG=str(call_log)) if call_log else None
    result = subprocess.run([sys.executable, str(script)] + args, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, env=env)
    if (result.returncode == 0) != (expected == 0):
        raise AssertionError("unexpected exit %d: %s\n%s" % (result.returncode, result.stdout, result.stderr))
    return result

with tempfile.TemporaryDirectory(prefix="c2ti-model-test-") as temporary:
    base = pathlib.Path(temporary)
    call_log = base / "calls.log"
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
        "import json, os, sys\n"
        "request = json.load(sys.stdin)\n"
        "open(os.environ['C2TI_FAKE_LOG'], 'a').write('call\\n')\n"
        "source = request['messages'][1]['content']\n"
        "findings = [] if 'clean.py' in source else [{'integrity_class':'network-isolation','severity':'P1','line':1,'evidence':'network call'}]\n"
        "print(json.dumps({'findings': findings}))\n",
        encoding="utf-8",
    )
    import shlex
    fake_command = shlex.quote(sys.executable) + " " + shlex.quote(str(fake))
    responses_dir = base / "run-1"
    call(["run", "--plan", str(plan_path), "--command", fake_command, "--approval", approval, "--responses", str(responses_dir)])
    # run's stored responses are the ones score evaluates, and they pass.
    call(["score", "--plan", str(plan_path), "--responses", str(responses_dir), "--corpus", str(corpus)])
    # A second run never mixes into an existing response directory.
    calls_before = call_log.read_text().count("call")
    rerun = call(["run", "--plan", str(plan_path), "--command", fake_command, "--approval", approval, "--responses", str(responses_dir)], expected=1)
    assert "already exists" in rerun.stderr, rerun.stderr
    assert call_log.read_text().count("call") == calls_before, "rerun called the model before refusing"
    # A run that fails part-way leaves no response directory to score.
    failing = base / "failing_model.py"
    failing.write_text(
        "import json, sys\n"
        "request = json.load(sys.stdin)\n"
        "if 'clean.py' in request['messages'][1]['content']:\n"
        "    sys.exit(3)\n"
        "print(json.dumps({'findings': []}))\n",
        encoding="utf-8",
    )
    partial_dir = base / "run-partial"
    call(["run", "--plan", str(plan_path), "--command", shlex.quote(sys.executable) + " " + shlex.quote(str(failing)), "--approval", approval, "--responses", str(partial_dir)], expected=1)
    assert not partial_dir.exists(), "failed run left a scorable response directory"
    assert not partial_dir.with_name(partial_dir.name + ".partial").exists(), "failed run left its partial directory"

    # A request file changed after approval is refused before any call.
    tamper_req_dir = base / "tamper-request"
    call(["plan", "--corpus", str(corpus), "--out", str(tamper_req_dir)])
    tamper_req_plan = tamper_req_dir / "plan.json"
    tamper_req_approval = hashlib.sha256(tamper_req_plan.read_bytes()).hexdigest()
    tampered_request = json.loads((tamper_req_dir / "requests/CASE-SECRET-1.json").read_text(encoding="utf-8"))
    tampered_request["messages"][1]["content"] += "\n# changed after approval"
    (tamper_req_dir / "requests/CASE-SECRET-1.json").write_text(json.dumps(tampered_request), encoding="utf-8")
    calls_before = call_log.read_text().count("call")
    tamper_run = call(["run", "--plan", str(tamper_req_plan), "--command", fake_command, "--approval", tamper_req_approval, "--responses", str(base / "tamper-request-out")], expected=1)
    assert "digest mismatch" in tamper_run.stderr, tamper_run.stderr
    assert call_log.read_text().count("call") == calls_before, "tampered plan reached the model"
    assert not (base / "tamper-request-out").exists()

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
    # Extra files and unknown classes are not silently accepted.
    extra = base / "extra"
    extra.mkdir()
    good_finding = json.dumps({"findings": [{"integrity_class": "network-isolation", "severity": "P1", "line": 1, "evidence": "network call"}]})
    for name, body in (("CASE-SECRET-1.json", good_finding), ("CASE-SECRET-CLEAN.json", '{"findings": []}'), ("CASE-OTHER.json", '{"findings": []}')):
        (extra / name).write_text(body, encoding="utf-8")
    extra_result = call(["score", "--plan", str(plan_path), "--responses", str(extra), "--corpus", str(corpus)], expected=1)
    assert "unexpected files" in extra_result.stderr, extra_result.stderr
    unknown = base / "unknown-class"
    unknown.mkdir()
    (unknown / "CASE-SECRET-1.json").write_text(json.dumps({"findings": [{"integrity_class": "network-isolation", "severity": "P1", "line": 1, "evidence": "network call"}, {"integrity_class": "made-up", "severity": "P1", "line": 1, "evidence": "x"}]}), encoding="utf-8")
    (unknown / "CASE-SECRET-CLEAN.json").write_text('{"findings": []}', encoding="utf-8")
    unknown_result = call(["score", "--plan", str(plan_path), "--responses", str(unknown), "--corpus", str(corpus)], expected=1)
    assert "malformed-or-missing" in unknown_result.stdout, unknown_result.stdout
    # A non-string class is reported as malformed, not a crash.
    odd = base / "odd-class"
    odd.mkdir()
    (odd / "CASE-SECRET-1.json").write_text(json.dumps({"findings": [{"integrity_class": ["x"], "severity": "P1", "line": 1, "evidence": "x"}]}), encoding="utf-8")
    (odd / "CASE-SECRET-CLEAN.json").write_text('{"findings": []}', encoding="utf-8")
    odd_result = call(["score", "--plan", str(plan_path), "--responses", str(odd), "--corpus", str(corpus)], expected=1)
    assert "malformed-or-missing" in odd_result.stdout and "Traceback" not in odd_result.stderr

    # The scored corpus must be exactly the approved plan's cases.
    subset = base / "subset.json"
    subset.write_text(json.dumps({"schema": "c2-ti/v1", "classes": classes, "cases": [cases[0]]}), encoding="utf-8")
    subset_dir = base / "subset-responses"
    subset_dir.mkdir()
    (subset_dir / "CASE-SECRET-1.json").write_text(good_finding, encoding="utf-8")
    subset_result = call(["score", "--plan", str(plan_path), "--responses", str(subset_dir), "--corpus", str(subset)], expected=1)
    assert "do not match the plan" in subset_result.stderr, subset_result.stderr


    cross = base / "cross"
    cross.mkdir()
    (cross / "CASE-SECRET-1.json").write_text(json.dumps({"findings": [{"integrity_class": "assertion-specificity", "severity": "P2", "line": 1, "evidence": "wrong class"}]}), encoding="utf-8")
    (cross / "CASE-SECRET-CLEAN.json").write_text('{"findings": []}', encoding="utf-8")
    cross_result = call(["score", "--plan", str(plan_path), "--responses", str(cross), "--corpus", str(corpus)], expected=1)
    cross_report = json.loads(cross_result.stdout)
    assert cross_report["false_positive_count"] == 1

    # Determinism compares detected seed ids, as issue #28 requires; every
    # repeat is also scored on its own.
    def write_repeat(name, seed_findings, clean_findings):
        directory = base / name
        directory.mkdir()
        (directory / "CASE-SECRET-1.json").write_text(json.dumps({"findings": seed_findings}), encoding="utf-8")
        (directory / "CASE-SECRET-CLEAN.json").write_text(json.dumps({"findings": clean_findings}), encoding="utf-8")
        return directory
    hit = {"integrity_class": "network-isolation", "severity": "P1", "line": 1, "evidence": "network call"}
    noise = {"integrity_class": "assertion-specificity", "severity": "P2", "line": 1, "evidence": "noise"}
    clean_fp = {"integrity_class": "network-isolation", "severity": "P1", "line": 1, "evidence": "false alarm"}
    # A seed detected in one repeat and missed in another is a mismatch.
    flip = call(["score", "--plan", str(plan_path), "--responses", str(write_repeat("flip-a", [hit], [])), str(write_repeat("flip-b", [], [])), "--corpus", str(corpus), "--repeat", "2"], expected=1)
    assert json.loads(flip.stdout)["repeat_mismatches"] == ["CASE-SECRET-1"], flip.stdout
    # An extra non-seed class varying across repeats is not a seed mismatch;
    # it is counted against that repeat's precision instead.
    extra_class = call(["score", "--plan", str(plan_path), "--responses", str(write_repeat("noise-a", [hit], [])), str(write_repeat("noise-b", [hit, noise], [])), "--corpus", str(corpus), "--repeat", "2"], expected=1)
    extra_report = json.loads(extra_class.stdout)
    assert extra_report["repeat_mismatches"] == [], extra_class.stdout
    assert [item["precision"] for item in extra_report["repeats"]] == [1.0, 0.5], extra_class.stdout
    # The headline describes the same repeat as the headline precision.
    assert extra_report["headline_repeat"] == 2, extra_class.stdout
    assert extra_report["false_positive_count"] == 1 and extra_report["true_positive_count"] == 1, extra_class.stdout
    # Every headline figure describes the headline repeat; worst figures are separate.
    assert extra_report["positive_recall"] == extra_report["repeats"][1]["positive_recall"], extra_class.stdout
    assert extra_report["worst"]["precision"] == 0.5, extra_class.stdout
    # A clean-case P0/P1 false positive in a later repeat fails the gate.
    late_fp = call(["score", "--plan", str(plan_path), "--responses", str(write_repeat("late-a", [hit], [])), str(write_repeat("late-b", [hit], [clean_fp])), "--corpus", str(corpus), "--repeat", "2"], expected=1)
    late_report = json.loads(late_fp.stdout)
    assert late_report["repeat_mismatches"] == [], late_fp.stdout
    assert [item["clean_negative_p0_p1_false_positives"] for item in late_report["repeats"]] == [0, 1], late_fp.stdout
    assert late_report["worst"]["clean_negative_p0_p1_false_positives"] == 1, late_fp.stdout
    assert late_report["headline_repeat"] == 2, late_fp.stdout
    assert late_report["clean_negative_p0_p1_false_positives"] == 1, late_fp.stdout
    # Identical passing repeats pass.
    call(["score", "--plan", str(plan_path), "--responses", str(write_repeat("same-a", [hit], [])), str(write_repeat("same-b", [hit], [])), "--corpus", str(corpus), "--repeat", "2"])
    # The same directory cannot stand in for several repeats.
    call(["score", "--plan", str(plan_path), "--responses", str(good), str(good), "--corpus", str(corpus), "--repeat", "2"], expected=1)

    # Case ids and plan entries become file names; a traversal id must be
    # rejected before anything is written outside the plan directory.
    escape = base / "escape-target"
    evil_corpus = base / "evil.json"
    evil_case = dict(cases[0], id="../../escape-target")
    evil_case["expected_findings"] = [{"seed_id": evil_case["id"], "severity": "P1"}]
    evil_corpus.write_text(json.dumps({"schema": "c2-ti/v1", "classes": classes, "cases": [evil_case]}), encoding="utf-8")
    call(["plan", "--corpus", str(evil_corpus), "--out", str(base / "evil-plan" / "x")], expected=1)
    assert not list(base.rglob("escape-target*")), "plan wrote outside its directory"

    tampered_dir = base / "tampered"
    call(["plan", "--corpus", str(corpus), "--out", str(tampered_dir)])
    tampered_path = tampered_dir / "plan.json"
    tampered = json.loads(tampered_path.read_text(encoding="utf-8"))
    tampered["requests"][0]["case_id"] = "../../escape-target"
    tampered_path.write_text(json.dumps(tampered), encoding="utf-8")
    tampered_approval = hashlib.sha256(tampered_path.read_bytes()).hexdigest()
    call(["run", "--plan", str(tampered_path), "--command", fake_command, "--approval", tampered_approval, "--responses", str(base / "tampered-out")], expected=1)
    assert not list(base.rglob("escape-target*")), "run wrote outside its directory"

# The adapter refuses HTTP redirects, so the bearer token never follows one.
import http.server
import threading

seen_auth = []

class Handler(http.server.BaseHTTPRequestHandler):
    def do_POST(self):
        self.send_response(302)
        self.send_header("Location", "http://127.0.0.1:%d/elsewhere" % self.server.server_address[1])
        self.end_headers()

    def do_GET(self):
        seen_auth.append(self.headers.get("Authorization"))
        self.send_response(200)
        self.end_headers()
        self.wfile.write(b'{"choices":[{"message":{"content":"{}"}}]}')

    def log_message(self, *args):
        pass

server = http.server.HTTPServer(("127.0.0.1", 0), Handler)
thread = threading.Thread(target=server.serve_forever, daemon=True)
thread.start()
try:
    env = dict(os.environ, C2TI_MODEL_BASE_URL="http://127.0.0.1:%d/v1" % server.server_address[1], C2TI_MODEL="m", C2TI_MODEL_TOKEN="sentinel-token")
    adapter = subprocess.run([sys.executable, str(root / "scripts/model-chat-adapter.py")], input=b'{"messages": []}', env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=30)
finally:
    server.shutdown()
assert adapter.returncode != 0, "adapter followed a redirect"
assert seen_auth == [], "bearer token was sent to the redirect target"
assert b"sentinel-token" not in adapter.stdout + adapter.stderr

print("ALL MODEL EVALUATOR FIXTURES PASSED")
PY
