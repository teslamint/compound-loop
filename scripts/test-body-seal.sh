#!/usr/bin/env bash
# U4 red/green harness for the shipped validator and repository check 14.
# Every fixture is disposable; expected digests come from an independent oracle.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS_COUNT=0
FAIL_COUNT=0

pass() { echo "  PASS: $1"; PASS_COUNT=$((PASS_COUNT + 1)); }
fail() { echo "  FAIL: $1"; FAIL_COUNT=$((FAIL_COUNT + 1)); }

setup_scratch() {
  local d
  d="$(mktemp -d)" || { echo "harness error: mktemp -d failed" >&2; return 1; }
  mkdir -p "$d/scripts" "$d/docs/plans" "$d/docs/specs" \
    "$d/schemas" "$d/skills/planning/scripts" "$d/skills/planning/schemas" \
    "$d/skills/planning/references" "$d/skills/compound/scripts" \
    "$d/skills/implementing" "$d/skills/reviewing" "$d/skills/shipping" \
    "$d/skills/shipping/references" "$d/skills/retrospective" \
    "$d/skills/release" "$d/skills/designing" "$d/skills/release-loop/references" \
    "$d/skills/compound" "$d/.claude-plugin" "$d/.codex-plugin" "$d/docs/retros"
  # Start from a validation-sufficient disposable snapshot. The fixture plan
  # is then added to the copied corpus, so checks 1–13 and 15 remain real.
  cp -R "$ROOT/skills/"* "$d/skills/" 2>/dev/null || true
  cp -R "$ROOT/schemas/"* "$d/schemas/" 2>/dev/null || true
  cp -R "$ROOT/docs/"* "$d/docs/" 2>/dev/null || true
  cp "$ROOT/scripts/"*.sh "$d/scripts/" 2>/dev/null || true
  cp "$ROOT/CHANGELOG.md" "$ROOT/ROADMAP.md" "$ROOT/CONCEPTS.md" "$d/" 2>/dev/null || true
  cp "$ROOT/.claude-plugin/plugin.json" "$d/.claude-plugin/" 2>/dev/null || true
  cp "$ROOT/.codex-plugin/plugin.json" "$d/.codex-plugin/" 2>/dev/null || true
  cp "$ROOT/PRINCIPLES.md" "$d/" 2>/dev/null || true
  printf '%s\n' "$d"
}

write_plan() {
  local dir="$1" name="$2" frontmatter="$3" body="$4"
  printf '%s\n' '---' "$frontmatter" '---' "$body" >"$dir/docs/plans/$name"
}

write_plan_bytes() {
  local path="$1" contents="$2"
  CONTENTS="$contents" python3 - "$path" <<'PY'
import os
import sys
from pathlib import Path
Path(sys.argv[1]).write_bytes(os.environ["CONTENTS"].encode("utf-8"))
PY
}

# This oracle is deliberately separate from the validator and from the
# migration block. It reads with newline=None, uses the literal split, and
# hashes UTF-8 bytes.
independent_digest() {
  local path="$1"
  python3 - "$path" <<'PY'
import hashlib
import sys
with open(sys.argv[1], encoding="utf-8", newline=None) as handle:
    text = handle.read()
body = text.split("---", 2)[2]
print(hashlib.sha256(body.encode("utf-8")).hexdigest())
PY
}

# A second implementation catches a fixture or oracle that accidentally uses
# raw CRLF bytes instead of universal-newline text semantics.
independent_digest_crosscheck() {
  local path="$1"
  python3 - "$path" <<'PY'
import hashlib
import sys
with open(sys.argv[1], "rb") as handle:
    raw = handle.read()
text = raw.decode("utf-8").replace("\r\n", "\n").replace("\r", "\n")
body = text.split("---", 2)[2]
print(hashlib.sha256(body.encode("utf-8")).hexdigest())
PY
}

run_validate() { bash "$1/scripts/validate.sh" 2>&1; }
run_shipped() { python3 "$1/skills/planning/scripts/validate-plan-frontmatter.py" "$2" 2>&1; }
run_shipped_print() { python3 "$1/skills/planning/scripts/validate-plan-frontmatter.py" --print-seal "$2" 2>&1; }

assert_contains() {
  local label="$1" output="$2" needle="$3"
  if printf '%s\n' "$output" | grep -Fq -- "$needle"; then
    pass "$label"
  else
    fail "$label — missing '$needle'"
    printf '    output: %s\n' "$(printf '%s' "$output" | tr '\n' ' ' | cut -c1-360)"
  fi
}

assert_not_contains() {
  local label="$1" output="$2" needle="$3"
  if printf '%s\n' "$output" | grep -Fq -- "$needle"; then
    fail "$label — unexpected '$needle'"
  else
    pass "$label"
  fi
}

assert_rc() {
  local label="$1" expected="$2" actual="$3"
  if [ "$expected" -eq "$actual" ]; then pass "$label"; else fail "$label — expected exit $expected, got $actual"; fi
}

assert_digest_in() {
  local label="$1" output="$2" digest="$3"
  if printf '%s\n' "$output" | grep -Fq -- "$digest"; then pass "$label"; else fail "$label — computed digest $digest absent"; fi
}

assert_parity_case() {
  local label="$1" d="$2" name="$3" expected="$4" expected_digest="${5:-}"
  local path="$d/docs/plans/$name" check_out shipped_out print_out check_rc shipped_rc print_rc
  check_out="$(run_validate "$d")"; check_rc=$?
  shipped_out="$(run_shipped "$d" "$path")"; shipped_rc=$?
  case "$expected" in
    pass)
      assert_rc "$label/check14 exit" 0 "$check_rc"
      assert_rc "$label/shipped validator exit" 0 "$shipped_rc"
      assert_contains "$label/check14 success" "$check_out" "[body-seal]"
      assert_not_contains "$label/check14 no failure" "$check_out" "FAIL: [body-seal]"
      assert_contains "$label/shipped success" "$shipped_out" "OK:"
      print_out="$(run_shipped_print "$d" "$path")"; print_rc=$?
      assert_rc "$label/shipped print-seal exit" 0 "$print_rc"
      assert_contains "$label/shipped print-seal digest" "$print_out" "$expected_digest"
      ;;
    absent)
      assert_rc "$label/check14 exit" 0 "$check_rc"
      assert_rc "$label/shipped validator exit" 0 "$shipped_rc"
      assert_contains "$label/check14 skip" "$check_out" "skipped"
      assert_contains "$label/shipped success" "$shipped_out" "OK:"
      ;;
    malformed)
      assert_rc "$label/check14 exit" 1 "$check_rc"
      assert_rc "$label/shipped validator exit" 1 "$shipped_rc"
      assert_contains "$label/check14 format verdict" "$check_out" "FAIL: [body-seal]"
      assert_contains "$label/check14 format diagnostic" "$check_out" "body_seal"
      assert_contains "$label/shipped format diagnostic" "$shipped_out" "body_seal"
      ;;
    mismatch)
      assert_rc "$label/check14 exit" 1 "$check_rc"
      assert_rc "$label/shipped validator exit" 1 "$shipped_rc"
      assert_contains "$label/check14 mismatch verdict" "$check_out" "FAIL: [body-seal]"
      assert_contains "$label/shipped mismatch verdict" "$shipped_out" "body_seal"
      assert_digest_in "$label/check14 computed digest" "$check_out" "$expected_digest"
      assert_digest_in "$label/shipped computed digest" "$shipped_out" "$expected_digest"
      ;;
    extraction)
      assert_rc "$label/check14 exit" 1 "$check_rc"
      print_out="$(run_shipped_print "$d" "$path")"; print_rc=$?
      assert_rc "$label/shipped print exit" 1 "$print_rc"
      assert_contains "$label/check14 extraction verdict" "$check_out" "extract"
      assert_contains "$label/shipped print extraction verdict" "$print_out" "extract"
      assert_contains "$label/check14 body-seal diagnostic" "$check_out" "body_seal"
      assert_contains "$label/shipped body-seal diagnostic" "$print_out" "body_seal"
      ;;
  esac
}

# --- Seven-shape parity table -------------------------------------------------
echo "Fixture group: seven-shape validator/check14 parity"

# Correct seal and absent seal are separate states. The correct fixture includes
# an inline delimiter in the body to prove literal split(..., 2) behavior.
d="$(setup_scratch)"
write_plan "$d" "correct.md" "schema: plan/v1
title: Correct
 type: feat
status: approved
date: 2026-08-15
execution: code" "
## Goal

correct body

---

body text after an inline delimiter
"
# Remove the accidental indentation in the field fixture without touching body.
sed -i.bak 's/^ type:/type:/' "$d/docs/plans/correct.md"; rm -f "$d/docs/plans/correct.md.bak"
correct_digest="$(independent_digest "$d/docs/plans/correct.md")"
correct_digest_2="$(independent_digest_crosscheck "$d/docs/plans/correct.md")"
if [ "$correct_digest" = "$correct_digest_2" ]; then pass "correct/oracle independent digest agreement"; else fail "correct/oracle independent digest agreement"; fi
python3 - "$d/docs/plans/correct.md" "$correct_digest" <<'PY'
import sys
from pathlib import Path
path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
path.write_text(text.replace("execution: code\n---", "execution: code\nbody_seal: " + sys.argv[2] + "\n---"), encoding="utf-8")
PY
assert_parity_case "correct seal" "$d" correct.md pass "$correct_digest"
rm -rf "$d"

# U2 regression: repeated independent seal computation remains deterministic.
d="$(setup_scratch)"
write_plan "$d" "golden.md" "schema: plan/v1
title: Golden
type: feat
status: approved
date: 2026-08-15
execution: code" "
## Goal

golden-hash body
"
golden_one="$(independent_digest "$d/docs/plans/golden.md")"
golden_two="$(independent_digest "$d/docs/plans/golden.md")"
if [ "$golden_one" = "$golden_two" ]; then pass "U2 golden-hash determinism"; else fail "U2 golden-hash determinism"; fi
python3 - "$d/docs/plans/golden.md" "$golden_one" <<'PY'
import sys
from pathlib import Path
path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
path.write_text(text.replace("execution: code\n---", "execution: code\nbody_seal: " + sys.argv[2] + "\n---"), encoding="utf-8")
PY
assert_parity_case "U2 golden-hash round-trip" "$d" golden.md pass "$golden_one"
rm -rf "$d"

# U2 regression: mutable terminal frontmatter does not alter a sealed body.
d="$(setup_scratch)"
write_plan "$d" "terminal.md" "schema: plan/v1
title: Terminal
type: feat
status: approved
date: 2026-08-15
execution: code" "
## Goal

terminal-state body
"
terminal_seal="$(independent_digest "$d/docs/plans/terminal.md")"
write_plan "$d" "terminal.md" "schema: plan/v1
title: Terminal
type: feat
status: done
date: 2026-08-15
execution: code
body_seal: $terminal_seal
completed_by: 0123456789abcdef0123456789abcdef01234567" "
## Goal

terminal-state body
"
assert_parity_case "U2 terminal-state frontmatter mutation" "$d" terminal.md pass "$terminal_seal"
rm -rf "$d"

d="$(setup_scratch)"
write_plan "$d" "absent.md" "schema: plan/v1
title: Absent
type: feat
status: approved
date: 2026-08-15
execution: code" "
## Goal

historical unsealed plan
"
assert_parity_case "absent seal" "$d" absent.md absent
rm -rf "$d"

d="$(setup_scratch)"
write_plan "$d" "malformed.md" "schema: plan/v1
title: Malformed
type: feat
status: approved
date: 2026-08-15
execution: code
body_seal: not-a-seal" "
## Goal

malformed seal
"
assert_parity_case "malformed seal" "$d" malformed.md malformed
rm -rf "$d"

d="$(setup_scratch)"
write_plan "$d" "mismatch.md" "schema: plan/v1
title: Mismatch
type: feat
status: approved
date: 2026-08-15
execution: code
body_seal: 0000000000000000000000000000000000000000000000000000000000000000" "
## Goal

valid-format mismatch
"
mismatch_digest="$(independent_digest "$d/docs/plans/mismatch.md")"
assert_parity_case "valid-format mismatch" "$d" mismatch.md mismatch "$mismatch_digest"
rm -rf "$d"

d="$(setup_scratch)"
write_plan "$d" "one-byte.md" "schema: plan/v1
title: One byte
type: feat
status: approved
date: 2026-08-15
execution: code" "
## Goal

one byte before sealing
"
one_byte_seal="$(independent_digest "$d/docs/plans/one-byte.md")"
python3 - "$d/docs/plans/one-byte.md" "$one_byte_seal" <<'PY'
import sys
from pathlib import Path
path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
path.write_text(text.replace("execution: code\n---", "execution: code\nbody_seal: " + sys.argv[2] + "\n---"), encoding="utf-8")
path.write_text(path.read_text(encoding="utf-8").replace("one byte before sealing", "one byte after sealing"), encoding="utf-8")
PY
one_byte_digest="$(independent_digest "$d/docs/plans/one-byte.md")"
assert_parity_case "one-byte body mutation" "$d" one-byte.md mismatch "$one_byte_digest"
rm -rf "$d"

d="$(setup_scratch)"
crlf_path="$d/docs/plans/crlf.md"
crlf_body=$'\r\n## Goal\r\n\r\nCRLF body\r\n'
crlf_fm=$'schema: plan/v1\r\ntitle: CRLF\r\ntype: feat\r\nstatus: approved\r\ndate: 2026-08-15\r\nexecution: code\r\n'
write_plan_bytes "$crlf_path" $'---\r\n'"${crlf_fm}"$'---'"${crlf_body}"
crlf_digest="$(independent_digest "$crlf_path")"
crlf_digest_2="$(independent_digest_crosscheck "$crlf_path")"
if [ "$crlf_digest" = "$crlf_digest_2" ]; then pass "CRLF universal-newline oracle agreement"; else fail "CRLF universal-newline oracle agreement"; fi
python3 - "$crlf_path" "$crlf_digest" <<'PY'
import sys
from pathlib import Path
path = Path(sys.argv[1])
raw = path.read_bytes().decode("utf-8")
raw = raw.replace("execution: code\r\n---", "execution: code\r\nbody_seal: " + sys.argv[2] + "\r\n---")
path.write_bytes(raw.encode("utf-8"))
PY
assert_parity_case "CRLF input" "$d" crlf.md pass "$crlf_digest"
rm -rf "$d"

d="$(setup_scratch)"
# --print-seal reaches canonical extraction before frontmatter parsing, allowing
# this deliberately impossible body extraction to exercise both implementations.
write_plan_bytes "$d/docs/plans/impossible.md" $'---\nschema: plan/v1\ntitle: Impossible\ntype: feat\nstatus: approved\ndate: 2026-08-15\nexecution: code\nbody_seal: 0000000000000000000000000000000000000000000000000000000000000000\n'
assert_parity_case "impossible canonical extraction" "$d" impossible.md extraction
rm -rf "$d"

# --- Current sealed corpus ----------------------------------------------------
echo "Fixture group: every currently sealed plan"
corpus_dir="$(setup_scratch)"
corpus_count=0
for source in "$ROOT"/docs/plans/*.md; do
  [ -f "$source" ] || continue
  if grep -q '^body_seal:' "$source"; then
    name="$(basename "$source")"
    cp "$source" "$corpus_dir/docs/plans/$name"
    corpus_count=$((corpus_count + 1))
    stored="$(sed -n 's/^body_seal:[[:space:]]*//p' "$source" | tr -d '\r' | head -1)"
    expected="$(independent_digest "$corpus_dir/docs/plans/$name" 2>/dev/null || true)"
    if [ -n "$expected" ] && [ "$stored" = "$expected" ]; then
      pass "current corpus independent seal $name"
    else
      fail "current corpus independent seal $name — stored=$stored computed=$expected"
    fi
    shipped="$(run_shipped_print "$corpus_dir" "$corpus_dir/docs/plans/$name")"; shipped_rc=$?
    assert_rc "current corpus shipped validator $name" 0 "$shipped_rc"
    assert_contains "current corpus shipped output $name" "$shipped" "$expected"
  fi
done
corpus_out="$(run_validate "$corpus_dir")"; corpus_rc=$?
assert_rc "current corpus check14 exit" 0 "$corpus_rc"
if [ "$corpus_count" -gt 0 ]; then
  assert_contains "current corpus check14 verified count" "$corpus_out" "$corpus_count verified"
else
  fail "current corpus has at least one sealed plan"
fi
rm -rf "$corpus_dir"

# --- Extract and execute the marked migration oracle -------------------------
echo "Fixture group: executable schema migration-check block"
migration_root="$(mktemp -d)"
MIGRATION_ROOT="$migration_root" SCHEMA_PATH="$ROOT/skills/planning/schemas/plan-schema.md" python3 - <<'PY'
import os
import re
import sys
from pathlib import Path

schema = Path(os.environ["SCHEMA_PATH"])
if not schema.is_file():
    print("RED migration-oracle/missing-schema", file=sys.stderr)
    raise SystemExit(10)
with open(schema, encoding="utf-8", newline=None) as handle:
    text = handle.read()
start = "<!-- body-seal-migration-check:begin -->"
end = "<!-- body-seal-migration-check:end -->"
if text.count(start) != 1 or text.count(end) != 1 or text.index(start) >= text.index(end):
    print("RED migration-oracle/marker-pair — expected exactly one ordered marker pair", file=sys.stderr)
    raise SystemExit(11)
section = text.split(start, 1)[1].split(end, 1)[0]
fences = re.findall(r"```python\n(.*?)\n```", section, re.DOTALL)
if len(fences) != 1 or section.count("```") != 2:
    print("RED migration-oracle/fence-count — expected exactly one fenced python block", file=sys.stderr)
    raise SystemExit(12)
Path(os.environ["MIGRATION_ROOT"], "migration-check.py").write_text(fences[0] + "\n", encoding="utf-8")
print(Path(os.environ["MIGRATION_ROOT"], "migration-check.py"))
PY
oracle_extract_rc=$?
if [ "$oracle_extract_rc" -eq 0 ]; then
  git -C "$migration_root" init -q
  git -C "$migration_root" config user.email fixture@example.invalid
  git -C "$migration_root" config user.name "Migration Fixture"
  mkdir -p "$migration_root/docs/plans"
  write_plan "$migration_root" "migration.md" "schema: plan/v1
title: Migration
 type: feat
status: approved
date: 2026-08-15
execution: code" "
## Goal

baseline body
"
  sed -i.bak 's/^ type:/type:/' "$migration_root/docs/plans/migration.md"; rm -f "$migration_root/docs/plans/migration.md.bak"
  git -C "$migration_root" add docs/plans/migration.md
  git -C "$migration_root" commit -qm "fixture baseline"
  baseline="$(git -C "$migration_root" rev-parse HEAD)"
  set +e
  unchanged_out="$(cd "$migration_root" && python3 migration-check.py "$baseline" docs/plans/migration.md 2>&1)"; unchanged_rc=$?
  set -e
  if [ "$unchanged_rc" -eq 0 ]; then pass "migration oracle unchanged baseline"; else fail "migration oracle unchanged baseline — $unchanged_out"; fi
  printf '\nchanged byte\n' >>"$migration_root/docs/plans/migration.md"
  set +e
  changed_out="$(cd "$migration_root" && python3 migration-check.py "$baseline" docs/plans/migration.md 2>&1)"; changed_rc=$?
  set -e
  assert_rc "migration oracle changed body exit" 1 "$changed_rc"
  assert_contains "migration oracle changed-body diagnostic" "$changed_out" "changed-body"
  set +e
  missing_out="$(cd "$migration_root" && python3 migration-check.py deadbeefdeadbeefdeadbeefdeadbeefdeadbeef docs/plans/migration.md 2>&1)"; missing_rc=$?
  set -e
  assert_rc "migration oracle missing baseline exit" 1 "$missing_rc"
  assert_contains "migration oracle missing-baseline diagnostic" "$missing_out" "missing-baseline"
else
  fail "migration oracle extraction and execution — marker/fence contract absent"
fi
rm -rf "$migration_root"
set +e

# --- Disposable Git adoption transition fixture -----------------------------
run_adoption_migration_fixture() {
  local fixture_root
  fixture_root="$(mktemp -d)" || { fail "adoption fixture setup"; return; }
  ROOT_FOR_ADOPTION="$ROOT" FIXTURE_ROOT="$fixture_root" python3 - <<'PY'
from __future__ import annotations

import hashlib
import json
import os
import re
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

root = Path(os.environ["ROOT_FOR_ADOPTION"])
fixture_root = Path(os.environ["FIXTURE_ROOT"])
evidence_root = fixture_root / ".release-loop" / "evidence" / "U4"
evidence_root.mkdir(parents=True)
start = "<!-- body-seal-migration-check:begin -->"
end = "<!-- body-seal-migration-check:end -->"
schema_path = root / "skills/planning/schemas/plan-schema.md"
if schema_path.is_file():
    with open(schema_path, encoding="utf-8", newline=None) as handle:
        schema_text = handle.read()
else:
    schema_text = ""
marker_ok = False
if schema_text.count(start) == 1 and schema_text.count(end) == 1:
    marker_ok = schema_text.index(start) < schema_text.index(end)
section = schema_text.split(start, 1)[1].split(end, 1)[0] if marker_ok else ""
fenced = re.findall(r"```python\n(.*?)\n```", section, re.DOTALL)
block_ok = marker_ok and len(fenced) == 1 and section.count("```") == 2

OUTCOMES = ("success", "forced-failure", "rerun", "compensation", "headless", "cancellation")
TARGET = "docs/plans/adoption.md"

def git(repo: Path, *args: str, check: bool = True, strip: bool = True) -> str:
    result = subprocess.run(["git", "-C", str(repo), *args], text=True, capture_output=True)
    if check and result.returncode:
        raise RuntimeError((result.stderr or result.stdout).strip()[:300])
    return result.stdout.strip() if strip else result.stdout

def digest_text(text: str) -> str:
    return hashlib.sha256(text.split("---", 2)[2].encode("utf-8")).hexdigest()

def state(repo: Path, pre_bytes: bytes) -> dict:
    head = git(repo, "rev-parse", "HEAD")
    status = git(repo, "status", "--porcelain", strip=False).rstrip("\n")
    plan = repo / TARGET
    diff = git(repo, "diff", "--no-ext-diff", "--unified=0", "--", TARGET)
    return {
        "head": head,
        "status": status,
        "plan_sha256": hashlib.sha256(plan.read_bytes()).hexdigest() if plan.exists() else "missing",
        "plan_equals_pre": plan.read_bytes() == pre_bytes if plan.exists() else False,
        "diff": diff,
        "dirty_target_only": status == f" M {TARGET}",
    }

def new_repo(outcome: str) -> tuple[Path, str, str, str, bytes, str, bytes]:
    repo = fixture_root / ("repo-" + outcome)
    (repo / "docs/plans").mkdir(parents=True)
    git(repo, "init", "-q")
    git(repo, "config", "user.email", "fixture@example.invalid")
    git(repo, "config", "user.name", "Adoption Fixture")
    body = "\n## Goal\n\nimmutable baseline body\n"
    old = "0" * 64
    plan_text = "---\nschema: plan/v1\ntitle: Adoption\ntype: feat\nstatus: approved\ndate: 2026-08-15\nexecution: code\nbody_seal: " + old + "\n---" + body
    (repo / TARGET).write_text(plan_text, encoding="utf-8")
    (repo / "sentinel.txt").write_text("BOUNDARY_SENTINEL_UNTOUCHED\n", encoding="utf-8")
    sentinel_bytes = (repo / "sentinel.txt").read_bytes()
    git(repo, "add", ".")
    git(repo, "commit", "-qm", "fixture adoption baseline")
    baseline = git(repo, "rev-parse", "HEAD")
    pre_bytes = (repo / TARGET).read_bytes()
    with open(repo / TARGET, encoding="utf-8", newline=None) as handle:
        current = handle.read()
    new = digest_text(current)
    command = f"python3 migration-check.py {baseline} {TARGET}"
    return repo, baseline, old, new, pre_bytes, command, sentinel_bytes

def write_seal(repo: Path, new: str) -> None:
    path = repo / TARGET
    with open(path, encoding="utf-8", newline=None) as handle:
        text = handle.read()
    text = re.sub(r"(?m)^body_seal:.*$", "body_seal: " + new, text, count=1)
    path.write_text(text, encoding="utf-8")

def transition(repo: Path, baseline: str, old: str, new: str, command: str, approval: str | None, injection: str | None) -> tuple[int, str]:
    if not approval:
        return 1, "missing-approval"
    if git(repo, "status", "--porcelain"):
        return 1, "rerun-fail-closed"
    with open(repo / TARGET, encoding="utf-8", newline=None) as handle:
        current = handle.read()
    baseline_text = git(repo, "show", f"{baseline}:{TARGET}", strip=False)
    if digest_text(current) != digest_text(baseline_text):
        return 1, "changed-body"
    if new != digest_text(current):
        return 1, "new-seal-mismatch"
    if injection == "pre-write-cancel":
        return 1, "pre-write-cancel"
    write_seal(repo, new)
    if injection in {"forced-failure", "post-write-cancel"}:
        return 1, injection
    message = (f"adoption reseal\n\nbaseline={baseline}\nplan={TARGET}\nold-seal={old}\n"
               f"new-seal={new}\nreproduction-command={command}\napproval={approval}\n")
    git(repo, "add", TARGET)
    git(repo, "commit", "-qm", message)
    return 0, "committed"

def assert_success(repo: Path, baseline: str, pre: bytes, old: str, new: str, command: str) -> tuple[bool, str]:
    current = state(repo, pre)
    commit = current["head"]
    parent = git(repo, "rev-parse", f"{commit}^")
    changed = set(git(repo, "diff-tree", "--no-commit-id", "--name-only", "-r", commit).splitlines())
    diff = git(repo, "diff", "--no-ext-diff", "--unified=0", parent, commit, "--", TARGET)
    message = git(repo, "show", "-s", "--format=%B", commit)
    ok = (baseline != commit and current["status"] == "" and changed == {TARGET}
          and diff.count("+body_seal: ") == 1 and diff.count("-body_seal: ") == 1
          and "baseline=" + baseline in message and "plan=" + TARGET in message
          and "old-seal=" + old in message and "new-seal=" + new in message
          and "reproduction-command=" + command in message
          and "approval=first-hand-explicit" in message)
    return ok, "success-state" if ok else "success-state-mismatch"

def markdown(outcome: str, baseline: str, repo: Path, pre: dict, command: str, rc: int, output: str, post: dict, next_result: str, mechanism: str, sentinel: Path, sentinel_check: dict) -> str:
    timestamp = datetime.now(timezone.utc).isoformat()
    inventory = [str(fixture_root), str(repo), str(repo / ".git"), str(repo / TARGET),
                 str(root / "skills/planning/schemas/plan-schema.md"), str(evidence_root), str(sentinel),
                 "remote=none", "outward-stub=not-applicable"]
    safe_output = " ".join(output.split())[:360].replace("|", "/")
    return f"""# U4 adoption reseal — {outcome}

- plan identity: `{TARGET}`
- matrix-row identity: `U4/adoption-reseal-{outcome}`
- source commit: `{baseline}`
- fixture identity and timestamp: `adoption-{outcome}` / `{timestamp}`
- disposable root: `{fixture_root}`
- complete configured target inventory: `{json.dumps(inventory)}`
- applicable stub identity or not-applicable reason: `not-applicable — local git only; no outward stub`
- boundary sentinel: `{sentinel}` / post-check=`{json.dumps(sentinel_check, sort_keys=True)}`
- pre-state: `{json.dumps(pre, sort_keys=True)}`
- exact command/injection: `{command}` / `outcome={outcome}`
- exit status: `{rc}`
- concise sanitized output: `{safe_output}`
- post-state: `{json.dumps(post, sort_keys=True)}`
- relevant next-invocation result: `{next_result}`
- mechanism check: `{mechanism}`
"""

failures = 0
for outcome in OUTCOMES:
    repo, baseline, old, new, pre_bytes, command, sentinel_expected = new_repo(outcome)
    sentinel = repo / "sentinel.txt"
    pre = state(repo, pre_bytes)
    rc = 1
    output = ""
    next_result = "not applicable"
    mechanism = "not-fired"
    if not block_ok:
        output = "missing migration-check block or marker/fence contract"
        mechanism = "BLOCKED: migration oracle contract absent"
        print(f"RED adoption-reseal-{outcome}/missing-migration-check", file=sys.stderr)
        failures += 1
    elif outcome == "success":
        rc, output = transition(repo, baseline, old, new, command, "first-hand-explicit", None)
        ok, mechanism = assert_success(repo, baseline, pre_bytes, old, new, command) if rc == 0 else (False, output)
        if not ok:
            print(f"RED adoption-reseal-{outcome}/{mechanism}", file=sys.stderr)
            failures += 1
    elif outcome == "forced-failure":
        rc, output = transition(repo, baseline, old, new, command, "first-hand-explicit", "forced-failure")
        post = state(repo, pre_bytes)
        ok = rc != 0 and post["head"] == baseline and post["dirty_target_only"] and post["diff"].count("+body_seal: ") == 1 and post["diff"].count("-body_seal: ") == 1
        mechanism = "forced-failure-after-seal-before-commit" if ok else "forced-failure-boundary-missed"
        if not ok:
            print(f"RED adoption-reseal-{outcome}/{mechanism}", file=sys.stderr)
            failures += 1
    elif outcome == "rerun":
        rc, output = transition(repo, baseline, old, new, command, "first-hand-explicit", "forced-failure")
        forced = state(repo, pre_bytes)
        rerun_rc, rerun_output = transition(repo, baseline, old, new, command, "first-hand-explicit", None)
        next_result = f"rerun rc={rerun_rc} output={rerun_output}"
        git(repo, "restore", "--source", "HEAD", "--", TARGET)
        rc, output = transition(repo, baseline, old, new, command, "fresh-approval-after-interruption", None)
        post = state(repo, pre_bytes)
        ok = (forced["dirty_target_only"] and rerun_rc != 0 and rerun_output == "rerun-fail-closed"
              and rc == 0 and post["status"] == ""
              and git(repo, "rev-list", "--count", f"{baseline}..HEAD") == "1")
        mechanism = "rerun-fail-closed-then-compensated-fresh-approval" if ok else "rerun-boundary-missed"
        if not ok:
            print(f"RED adoption-reseal-{outcome}/{mechanism}", file=sys.stderr)
            failures += 1
    elif outcome == "compensation":
        rc, output = transition(repo, baseline, old, new, command, "first-hand-explicit", "forced-failure")
        git(repo, "restore", "--source", "HEAD", "--", TARGET)
        post = state(repo, pre_bytes)
        ok = rc != 0 and post["head"] == baseline and post["plan_equals_pre"] and post["status"] == ""
        next_result = "operator-owned target-only compensation restored clean state"
        mechanism = "target-only-compensation" if ok else "compensation-boundary-missed"
        if not ok:
            print(f"RED adoption-reseal-{outcome}/{mechanism}", file=sys.stderr)
            failures += 1
    elif outcome == "headless":
        rc, output = transition(repo, baseline, old, new, command, None, None)
        post = state(repo, pre_bytes)
        ok = rc != 0 and output == "missing-approval" and post["head"] == baseline and post["status"] == "" and post["plan_equals_pre"]
        mechanism = "headless-rejected-before-seal-write" if ok else "headless-boundary-missed"
        if not ok:
            print(f"RED adoption-reseal-{outcome}/{mechanism}", file=sys.stderr)
            failures += 1
    elif outcome == "cancellation":
        rc, output = transition(repo, baseline, old, new, command, "first-hand-explicit", "pre-write-cancel")
        pre_cancel = state(repo, pre_bytes)
        post_rc, post_output = transition(repo, baseline, old, new, command, "first-hand-explicit", "post-write-cancel")
        forced = state(repo, pre_bytes)
        git(repo, "restore", "--source", "HEAD", "--", TARGET)
        post = state(repo, pre_bytes)
        next_result = f"pre-write rc={rc} output={output}; post-write rc={post_rc} output={post_output}; compensated clean={post['status']==''}"
        ok = (rc != 0 and output == "pre-write-cancel" and pre_cancel["status"] == ""
              and post_rc != 0 and forced["dirty_target_only"]
              and post["status"] == "" and post["head"] == baseline)
        mechanism = "pre-write-cancel-and-post-write-forced-failure-compensation" if ok else "cancellation-boundary-missed"
        if not ok:
            print(f"RED adoption-reseal-{outcome}/{mechanism}", file=sys.stderr)
            failures += 1
    else:
        post = state(repo, pre_bytes)
    if outcome == "success":
        post = state(repo, pre_bytes)
    elif outcome not in {"rerun", "compensation", "headless", "cancellation"}:
        post = state(repo, pre_bytes)
    sentinel_observed = sentinel.read_bytes() if sentinel.exists() else b""
    sentinel_check = {
        "expected_sha256": hashlib.sha256(sentinel_expected).hexdigest(),
        "observed_sha256": hashlib.sha256(sentinel_observed).hexdigest(),
        "unchanged": sentinel_observed == sentinel_expected,
    }
    if not sentinel_check["unchanged"]:
        print(f"RED adoption-reseal-{outcome}/boundary-sentinel-mutated", file=sys.stderr)
        failures += 1
    record = markdown(outcome, baseline, repo, pre, command, rc, output, post, next_result, mechanism, sentinel, sentinel_check)
    (evidence_root / f"adoption-reseal-{outcome}.md").write_text(record, encoding="utf-8")

records = sorted(evidence_root.glob("adoption-reseal-*.md"))
expected_names = sorted(f"adoption-reseal-{outcome}.md" for outcome in OUTCOMES)
if [record.name for record in records] != expected_names:
    print("RED adoption-evidence/exactly-six-records", file=sys.stderr)
    failures += 1
mandatory = ("plan identity:", "matrix-row identity:", "source commit:", "fixture identity and timestamp:",
             "disposable root:", "complete configured target inventory:", "applicable stub identity or not-applicable reason:",
             "boundary sentinel:", "pre-state:", "exact command/injection:", "exit status:", "concise sanitized output:",
             "post-state:", "relevant next-invocation result:", "mechanism check:")
for record in records:
    text = record.read_text(encoding="utf-8")
    missing = [field for field in mandatory if field not in text]
    if missing:
        print(f"RED adoption-evidence/{record.name}/missing={','.join(missing)}", file=sys.stderr)
        failures += 1
if failures or not block_ok:
    raise SystemExit(1)

canonical_root = root / ".release-loop" / "evidence" / "U4"
expected_canonical = {f"adoption-reseal-{outcome}.md" for outcome in OUTCOMES}
existing = {path.name for path in canonical_root.glob("adoption-reseal-*.md")} if canonical_root.is_dir() else set()
if existing and existing != expected_canonical:
    print("RED adoption-evidence/stale-or-incomplete-canonical-records — refusing overwrite", file=sys.stderr)
    raise SystemExit(1)
canonical_root.parent.mkdir(parents=True, exist_ok=True)
staged = canonical_root.parent / f".U4-evidence-stage-{os.getpid()}"
if staged.exists():
    print("RED adoption-evidence/stale-stage", file=sys.stderr)
    raise SystemExit(1)
staged.mkdir()
for record in records:
    (staged / record.name).write_bytes(record.read_bytes())
if canonical_root.exists():
    for record in staged.iterdir():
        os.replace(record, canonical_root / record.name)
    staged.rmdir()
else:
    os.replace(staged, canonical_root)
PY
  local rc=$?
  rm -rf "$fixture_root"
  if [ "$rc" -eq 0 ]; then pass "adoption migration fixture six durable outcomes"; else fail "adoption migration fixture six durable outcomes — named RED above"; fi
}

run_adoption_migration_fixture

echo
echo "Results: $PASS_COUNT passed, $FAIL_COUNT failed"
if [ "$FAIL_COUNT" -gt 0 ]; then exit 1; fi
exit 0
