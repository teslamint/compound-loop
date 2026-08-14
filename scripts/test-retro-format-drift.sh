#!/usr/bin/env bash
# Fixture harness for the retro interview format-drift check
# (scripts/validate.sh check 9; committed red before that check landed —
# see plan U4/U5). Each case copies the current worktree into a disposable
# mktemp -d directory, applies one mutation (or none), runs
# `bash scripts/validate.sh` from the copy, and asserts on exit code and
# output. Never mutates the real skills/ or schemas/ files.
#
# Manual invocation only: not wired into scripts/validate.sh or any CI.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL_COUNT=0

TEMP_DIRS=()
cleanup() {
  local d
  for d in ${TEMP_DIRS[@]+"${TEMP_DIRS[@]}"}; do
    [[ -d "$d" ]] && rm -rf "$d"
  done
}
trap cleanup EXIT

setup_copy() {
  local dir
  dir="$(mktemp -d 2>&1)" || { echo "  harness error: mktemp -d failed: $dir" >&2; return 1; }
  cp -r "$ROOT/." "$dir/" || { echo "  harness error: worktree copy failed" >&2; rm -rf "$dir"; return 1; }
  rm -rf "$dir/.git"
  printf '%s\n' "$dir"
}

assert_contains() {
  local haystack="$1" needle="$2" label="$3"
  if [[ "$haystack" == *"$needle"* ]]; then
    return 0
  fi
  echo "  assertion failed ($label): expected output to contain: $needle"
  return 1
}

assert_not_contains() {
  local haystack="$1" needle="$2" label="$3"
  if [[ "$haystack" != *"$needle"* ]]; then
    return 0
  fi
  echo "  assertion failed ($label): expected output NOT to contain: $needle"
  return 1
}

# A FAIL: line that itself names the given string — a passing run's ok-lines
# also mention these file paths, so a bare substring check would be vacuous.
assert_fail_naming() {
  local haystack="$1" name="$2" label="$3"
  if grep -q "FAIL:.*${name}" <<<"$haystack"; then
    return 0
  fi
  echo "  assertion failed ($label): expected a FAIL: line naming: $name"
  return 1
}

run_case() {
  local name="$1"
  shift
  echo "Case $name:"
  if "$@"; then
    echo "  pass"
  else
    echo "  FAIL"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
}

# --- Case A: clean repo, no mutation ---
# Red until check 9 exists: validate.sh exits 0 but never prints the check-9
# ok-line, so the ok-line assertion fails.
case_a() {
  local dir out code result=0
  dir="$(setup_copy)" || return 1
  TEMP_DIRS+=("$dir")
  out="$(cd "$dir" && bash scripts/validate.sh 2>&1)"; code=$?
  [[ $code -eq 0 ]] || { echo "  expected exit 0, got $code"; result=1; }
  assert_contains "$out" "ok:   retro interview format: template and skill prose agree" "ok-line" || result=1
  rm -rf "$dir"
  return $result
}

# --- Case B: independence-level vocabulary drift in the template ---
# Mutates only the `- Independence level:` line of schemas/retro-template.md
# (`self-checklist` -> `self-check`), leaving the later prose occurrence
# intact, so the drift is a level-vocabulary mismatch against
# skills/retrospective/SKILL.md's closed four-value list.
# Red until check 9 exists: validate.sh still reports ALL CHECKS PASSED.
case_b() {
  local dir out code result=0
  dir="$(setup_copy)" || return 1
  TEMP_DIRS+=("$dir")
  python3 - "$dir/schemas/retro-template.md" <<'PY' || { echo "  harness error: fixture mutation failed (see traceback above) -- fixture assumption likely broken"; rm -rf "$dir"; return 1; }
import sys
path = sys.argv[1]
lines = open(path, encoding="utf-8").read().split("\n")
idx = [i for i, l in enumerate(lines) if l.startswith("- Independence level:")]
assert len(idx) == 1, "fixture assumption broken: expected exactly one Independence level line"
i = idx[0]
assert "self-checklist" in lines[i], "fixture assumption broken: self-checklist not on the Independence level line"
lines[i] = lines[i].replace("self-checklist", "self-check", 1)
open(path, "w", encoding="utf-8").write("\n".join(lines))
PY
  out="$(cd "$dir" && bash scripts/validate.sh 2>&1)"; code=$?
  [[ $code -ne 0 ]] || { echo "  expected nonzero exit, got 0"; result=1; }
  assert_fail_naming "$out" "schemas/retro-template.md" "FAIL line names the template" || result=1
  assert_fail_naming "$out" "self-check" "FAIL line names the mismatched level value" || result=1
  rm -rf "$dir"
  return $result
}

# --- Case C: `self-attested` vocabulary deleted from the skill prose ---
# Removes every `self-attested` occurrence (backticks included — dropping only
# the inner text would leave an empty backtick pair that de-pairs the file's
# remaining spans and trips pre-existing check 6 instead) from
# skills/retrospective/SKILL.md, so the template's verdict vocabulary
# references a value the skill prose no longer defines. Red until check 9
# exists: validate.sh still reports ALL CHECKS PASSED.
case_c() {
  local dir out code result=0
  dir="$(setup_copy)" || return 1
  TEMP_DIRS+=("$dir")
  python3 - "$dir/skills/retrospective/SKILL.md" <<'PY' || { echo "  harness error: fixture mutation failed (see traceback above) -- fixture assumption likely broken"; rm -rf "$dir"; return 1; }
import sys
path = sys.argv[1]
text = open(path, encoding="utf-8").read()
assert "`self-attested`" in text, "fixture assumption broken: backticked self-attested not found in skill prose"
text = text.replace("`self-attested`", "")
assert "self-attested" not in text, "fixture assumption broken: a non-backticked self-attested occurrence remains"
open(path, "w", encoding="utf-8").write(text)
PY
  out="$(cd "$dir" && bash scripts/validate.sh 2>&1)"; code=$?
  [[ $code -ne 0 ]] || { echo "  expected nonzero exit, got 0"; result=1; }
  assert_fail_naming "$out" "skills/retrospective/SKILL.md" "FAIL line names the skill file" || result=1
  rm -rf "$dir"
  return $result
}

# --- Case D: entire Interview Transcript section deleted from the template ---
# Removes everything from the `## Interview Transcript` heading up to (not
# including) the next `## ` heading. Check 9 must report the missing section
# gracefully — no Python traceback. Red until check 9 exists: validate.sh
# still reports ALL CHECKS PASSED.
case_d() {
  local dir out code result=0
  dir="$(setup_copy)" || return 1
  TEMP_DIRS+=("$dir")
  python3 - "$dir/schemas/retro-template.md" <<'PY' || { echo "  harness error: fixture mutation failed (see traceback above) -- fixture assumption likely broken"; rm -rf "$dir"; return 1; }
import sys
path = sys.argv[1]
text = open(path, encoding="utf-8").read()
heading = "## Interview Transcript"
assert text.count(heading) == 1, "fixture assumption broken: expected exactly one Interview Transcript heading"
start = text.index(heading)
end = text.index("\n## ", start)
assert end > start, "fixture assumption broken: no following section heading"
open(path, "w", encoding="utf-8").write(text[:start] + text[end + 1:])
PY
  out="$(cd "$dir" && bash scripts/validate.sh 2>&1)"; code=$?
  [[ $code -ne 0 ]] || { echo "  expected nonzero exit, got 0"; result=1; }
  assert_fail_naming "$out" "schemas/retro-template.md" "FAIL line names the template" || result=1
  assert_not_contains "$out" "Traceback" "no python traceback" || result=1
  rm -rf "$dir"
  return $result
}

# --- Case E: `no evidenced answer` deleted from the probes contract ---
# Removes every `no evidenced answer` occurrence from
# skills/retrospective/references/interview-probes.md (the phrase sits inside
# backticked verdict spans, so removing it leaves backtick pairing intact),
# so the template's verdict vocabulary loses its probes-contract anchor.
# Red until check 9 exists: validate.sh still reports ALL CHECKS PASSED.
case_e() {
  local dir out code result=0
  dir="$(setup_copy)" || return 1
  TEMP_DIRS+=("$dir")
  python3 - "$dir/skills/retrospective/references/interview-probes.md" <<'PY' || { echo "  harness error: fixture mutation failed (see traceback above) -- fixture assumption likely broken"; rm -rf "$dir"; return 1; }
import sys
path = sys.argv[1]
text = open(path, encoding="utf-8").read()
assert "no evidenced answer" in text, "fixture assumption broken: no evidenced answer not found in probes contract"
open(path, "w", encoding="utf-8").write(text.replace("no evidenced answer", ""))
PY
  out="$(cd "$dir" && bash scripts/validate.sh 2>&1)"; code=$?
  [[ $code -ne 0 ]] || { echo "  expected nonzero exit, got 0"; result=1; }
  assert_fail_naming "$out" "skills/retrospective/references/interview-probes.md" "FAIL line names the probes file" || result=1
  rm -rf "$dir"
  return $result
}

# Case F: consumer file missing entirely -- check 9 must emit a named FAIL
# ("missing or unreadable"), never a traceback (plan U5 error scenario).
case_f() {
  local dir out code result=0
  dir="$(setup_copy)" || return 1
  TEMP_DIRS+=("$dir")
  rm "$dir/skills/retrospective/references/interview-probes.md" || { echo "  harness error: fixture deletion failed"; rm -rf "$dir"; return 1; }
  out="$(cd "$dir" && bash scripts/validate.sh 2>&1)"; code=$?
  [[ $code -ne 0 ]] || { echo "  expected nonzero exit, got 0"; result=1; }
  assert_fail_naming "$out" "skills/retrospective/references/interview-probes.md" "FAIL line names the missing probes file" || result=1
  assert_not_contains "$out" "Traceback" "no Python traceback" || result=1
  rm -rf "$dir"
  return $result
}

# --- Case G: template+SKILL co-rename of the degraded rung ---
# Renames `self-checklist` to `solo-checklist` in both schemas/retro-template.md
# and skills/retrospective/SKILL.md, leaving interview-probes.md on the stale
# name — the co-drift class deviation addendum 003 covers. Red until check 9
# validates the list-final level against the probes contract: the co-renamed
# copy passes validate.sh because level assertions stop at SKILL.md.
case_g() {
  local dir out code result=0
  dir="$(setup_copy)" || return 1
  TEMP_DIRS+=("$dir")
  python3 - "$dir" <<'PY' || { echo "  harness error: fixture mutation failed (see traceback above) -- fixture assumption likely broken"; rm -rf "$dir"; return 1; }
import sys, pathlib
root = pathlib.Path(sys.argv[1])
for rel in ("schemas/retro-template.md", "skills/retrospective/SKILL.md"):
    path = root / rel
    text = path.read_text(encoding="utf-8")
    assert "self-checklist" in text, f"fixture assumption broken: self-checklist not found in {rel}"
    path.write_text(text.replace("self-checklist", "solo-checklist"), encoding="utf-8")
probes = (root / "skills/retrospective/references/interview-probes.md").read_text(encoding="utf-8")
assert "self-checklist" in probes, "fixture assumption broken: self-checklist not found in probes contract"
PY
  out="$(cd "$dir" && bash scripts/validate.sh 2>&1)"; code=$?
  [[ $code -ne 0 ]] || { echo "  expected nonzero exit, got 0"; result=1; }
  assert_fail_naming "$out" "skills/retrospective/references/interview-probes.md" "FAIL line names the probes file" || result=1
  assert_fail_naming "$out" "solo-checklist" "FAIL line names the missing level value" || result=1
  rm -rf "$dir"
  return $result
}

# --- Case H: template has only 3 independence levels (malformation guard) ---
case_h() {
  local dir out code result=0
  dir="$(setup_copy)" || return 1
  TEMP_DIRS+=("$dir")
  python3 - "$dir/schemas/retro-template.md" <<'PY' || { echo "  harness error: fixture mutation failed"; rm -rf "$dir"; return 1; }
import sys
path = sys.argv[1]
text = open(path, encoding="utf-8").read()
text = text.replace("| self-checklist", "", 1)
open(path, "w", encoding="utf-8").write(text)
PY
  out="$(cd "$dir" && bash scripts/validate.sh 2>&1)"; code=$?
  [[ $code -ne 0 ]] || { echo "  expected nonzero exit, got 0"; result=1; }
  assert_fail_naming "$out" "expected 5 distinct independence levels" "FAIL names the level-count guard" || result=1
  rm -rf "$dir"
  return $result
}

# --- Case I: template has only 2 verdict forms (malformation guard) ---
case_i() {
  local dir out code result=0
  dir="$(setup_copy)" || return 1
  TEMP_DIRS+=("$dir")
  python3 - "$dir/schemas/retro-template.md" <<'PY' || { echo "  harness error: fixture mutation failed"; rm -rf "$dir"; return 1; }
import sys, re
path = sys.argv[1]
text = open(path, encoding="utf-8").read()
text = text.replace("`self-attested`", "", 1)
open(path, "w", encoding="utf-8").write(text)
PY
  out="$(cd "$dir" && bash scripts/validate.sh 2>&1)"; code=$?
  [[ $code -ne 0 ]] || { echo "  expected nonzero exit, got 0"; result=1; }
  assert_fail_naming "$out" "expected 4 distinct backticked verdict forms" "FAIL names the verdict-count guard" || result=1
  rm -rf "$dir"
  return $result
}

# --- Case J: template missing `Verdict cell values:` line (malformation guard) ---
case_j() {
  local dir out code result=0
  dir="$(setup_copy)" || return 1
  TEMP_DIRS+=("$dir")
  python3 - "$dir/schemas/retro-template.md" <<'PY' || { echo "  harness error: fixture mutation failed"; rm -rf "$dir"; return 1; }
import sys
path = sys.argv[1]
lines = open(path, encoding="utf-8").read().split("\n")
lines = [l for l in lines if not l.startswith("Verdict cell values:")]
open(path, "w", encoding="utf-8").write("\n".join(lines))
PY
  out="$(cd "$dir" && bash scripts/validate.sh 2>&1)"; code=$?
  [[ $code -ne 0 ]] || { echo "  expected nonzero exit, got 0"; result=1; }
  assert_fail_naming "$out" "expected exactly one 'Verdict cell values:' line" "FAIL names the verdict-line guard" || result=1
  rm -rf "$dir"
  return $result
}

# --- Case C1: `not-probed (no narrative warranted)` deleted from the skill prose ---
# Removes the backticked occurrence (backticks included — dropping only the
# inner text would leave an empty backtick pair that de-pairs the file's
# remaining spans and trips pre-existing check 6 instead) from
# skills/retrospective/SKILL.md. Regression guard for the fifth level value:
# check 9 must name the skill file and the missing level.
case_c1() {
  local dir out code result=0
  dir="$(setup_copy)" || return 1
  TEMP_DIRS+=("$dir")
  python3 - "$dir/skills/retrospective/SKILL.md" <<'PY' || { echo "  harness error: fixture mutation failed (see traceback above) -- fixture assumption likely broken"; rm -rf "$dir"; return 1; }
import sys
path = sys.argv[1]
text = open(path, encoding="utf-8").read()
assert "`not-probed (no narrative warranted)`" in text, "fixture assumption broken: backticked not-probed level not found in skill prose"
text = text.replace("`not-probed (no narrative warranted)`", "")
assert "not-probed (no narrative warranted)" not in text, "fixture assumption broken: a non-backticked not-probed level occurrence remains"
open(path, "w", encoding="utf-8").write(text)
PY
  out="$(cd "$dir" && bash scripts/validate.sh 2>&1)"; code=$?
  [[ $code -ne 0 ]] || { echo "  expected nonzero exit, got 0"; result=1; }
  assert_fail_naming "$out" "skills/retrospective/SKILL.md" "FAIL line names the skill file" || result=1
  assert_fail_naming "$out" "not-probed (no narrative warranted)" "FAIL line names the missing level value" || result=1
  rm -rf "$dir"
  return $result
}

# --- Case C2: `not-probed (no narrative warranted)` deleted from the probes contract ---
# Same removal against skills/retrospective/references/interview-probes.md.
# Regression guard for the fifth level value on the probes side.
case_c2() {
  local dir out code result=0
  dir="$(setup_copy)" || return 1
  TEMP_DIRS+=("$dir")
  python3 - "$dir/skills/retrospective/references/interview-probes.md" <<'PY' || { echo "  harness error: fixture mutation failed (see traceback above) -- fixture assumption likely broken"; rm -rf "$dir"; return 1; }
import sys
path = sys.argv[1]
text = open(path, encoding="utf-8").read()
assert "not-probed (no narrative warranted)" in text, "fixture assumption broken: not-probed level not found in the probes contract"
text = text.replace("not-probed (no narrative warranted)", "")
open(path, "w", encoding="utf-8").write(text)
PY
  out="$(cd "$dir" && bash scripts/validate.sh 2>&1)"; code=$?
  [[ $code -ne 0 ]] || { echo "  expected nonzero exit, got 0"; result=1; }
  assert_fail_naming "$out" "skills/retrospective/references/interview-probes.md" "FAIL line names the probes file" || result=1
  assert_fail_naming "$out" "not-probed (no narrative warranted)" "FAIL line names the missing level value" || result=1
  rm -rf "$dir"
  return $result
}

# --- Case C3: a non-final level deleted from the probes contract ---
# Removes `in-thread (approximated independence)` from
# skills/retrospective/references/interview-probes.md. The list-final level
# stays intact, so a positional rule that inspects only the last value passes
# the mutated tree. Discrimination case: check 9 must assert every level
# against the probes contract, not the final one.
case_c3() {
  local dir out code result=0
  dir="$(setup_copy)" || return 1
  TEMP_DIRS+=("$dir")
  python3 - "$dir/skills/retrospective/references/interview-probes.md" <<'PY' || { echo "  harness error: fixture mutation failed (see traceback above) -- fixture assumption likely broken"; rm -rf "$dir"; return 1; }
import sys
path = sys.argv[1]
text = open(path, encoding="utf-8").read()
assert "in-thread (approximated independence)" in text, "fixture assumption broken: in-thread level not found in the probes contract"
text = text.replace("in-thread (approximated independence)", "in-thread")
open(path, "w", encoding="utf-8").write(text)
PY
  out="$(cd "$dir" && bash scripts/validate.sh 2>&1)"; code=$?
  [[ $code -ne 0 ]] || { echo "  expected nonzero exit, got 0"; result=1; }
  assert_fail_naming "$out" "skills/retrospective/references/interview-probes.md" "FAIL line names the probes file" || result=1
  assert_fail_naming "$out" "in-thread (approximated independence)" "FAIL line names the missing level value" || result=1
  rm -rf "$dir"
  return $result
}

# --- Case C4: clean repo carrying five levels, no mutation ---
# Check 9 passes an unmutated tree once the fifth level exists in every
# consumer file.
case_c4() {
  local dir out code result=0
  dir="$(setup_copy)" || return 1
  TEMP_DIRS+=("$dir")
  out="$(cd "$dir" && bash scripts/validate.sh 2>&1)"; code=$?
  [[ $code -eq 0 ]] || { echo "  expected exit 0, got $code"; result=1; }
  assert_contains "$out" "ok:   retro interview format: template and skill prose agree" "ok-line" || result=1
  rm -rf "$dir"
  return $result
}

run_case A case_a
run_case B case_b
run_case C case_c
run_case D case_d
run_case E case_e
run_case F case_f
run_case G case_g
run_case H case_h
run_case I case_i
run_case J case_j
run_case C1 case_c1
run_case C2 case_c2
run_case C3 case_c3
run_case C4 case_c4

echo
if [[ $FAIL_COUNT -eq 0 ]]; then
  echo "ALL CASES PASSED"
  exit 0
else
  echo "$FAIL_COUNT case(s) FAILED"
  exit 1
fi
