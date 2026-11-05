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
    responses_dir = base / "run-1"
    call(["run", "--plan", str(plan_path), "--command", fake_command, "--approval", approval, "--responses", str(responses_dir)])
    # run's stored responses are the ones score evaluates, and they pass.
    call(["score", "--plan", str(plan_path), "--responses", str(responses_dir), "--corpus", str(corpus)])
    # A second run never mixes into an existing response directory.
    call(["run", "--plan", str(plan_path), "--command", fake_command, "--approval", approval, "--responses", str(responses_dir)], expected=1)
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

    # A request file changed after approval is refused before any call.
    tamper_req_dir = base / "tamper-request"
    call(["plan", "--corpus", str(corpus), "--out", str(tamper_req_dir)])
    tamper_req_plan = tamper_req_dir / "plan.json"
    tamper_req_approval = hashlib.sha256(tamper_req_plan.read_bytes()).hexdigest()
    (tamper_req_dir / "requests/CASE-SECRET-1.json").write_text('{"messages": []}\n', encoding="utf-8")
    call(["run", "--plan", str(tamper_req_plan), "--command", fake_command, "--approval", tamper_req_approval, "--responses", str(base / "tamper-request-out")], expected=1)
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
    for name, body in (("CASE-SECRET-1.json", '{"findings": []}'), ("CASE-SECRET-CLEAN.json", '{"findings": []}'), ("CASE-OTHER.json", '{"findings": []}')):
        (extra / name).write_text(body, encoding="utf-8")
    call(["score", "--plan", str(plan_path), "--responses", str(extra), "--corpus", str(corpus)], expected=1)
    unknown = base / "unknown-class"
    unknown.mkdir()
    (unknown / "CASE-SECRET-1.json").write_text(json.dumps({"findings": [{"integrity_class": "made-up", "severity": "P1", "line": 1, "evidence": "x"}]}), encoding="utf-8")
    (unknown / "CASE-SECRET-CLEAN.json").write_text('{"findings": []}', encoding="utf-8")
    call(["score", "--plan", str(plan_path), "--responses", str(unknown), "--corpus", str(corpus)], expected=1)

    # The scored corpus must be exactly the approved plan's cases.
    subset = base / "subset.json"
    subset.write_text(json.dumps({"schema": "c2-ti/v1", "classes": classes, "cases": [cases[0]]}), encoding="utf-8")
    call(["score", "--plan", str(plan_path), "--responses", str(good), "--corpus", str(subset)], expected=1)


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
