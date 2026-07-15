#!/usr/bin/env bash
# Fixture harness for the terminal-signal drift check (scripts/validate.sh
# check 6.). Each case copies the current worktree into a disposable
# mktemp -d directory, applies one mutation (or none), runs
# `bash scripts/validate.sh` from the copy, and asserts on exit code and
# output. Never mutates the real skills/ or schemas/ files.
#
# Manual invocation only: not wired into scripts/validate.sh or any CI.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL_COUNT=0

setup_copy() {
  local dir
  dir="$(mktemp -d 2>&1)" || { echo "  harness error: mktemp -d failed: $dir" >&2; return 1; }
  cp -r "$ROOT/." "$dir/"
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
case_a() {
  local dir out code result=0
  dir="$(setup_copy)" || return 1
  out="$(cd "$dir" && bash scripts/validate.sh 2>&1)"; code=$?
  [[ $code -eq 0 ]] || { echo "  expected exit 0, got $code"; result=1; }
  assert_contains "$out" "ok:   terminal signal lines match schemas/headless-contract.md" "ok-line" || result=1
  rm -rf "$dir"
  return $result
}

# --- Case B: one-byte drift in skills/compound/SKILL.md:77 ---
case_b() {
  local dir out code result=0
  dir="$(setup_copy)" || return 1
  python3 - "$dir/skills/compound/SKILL.md" <<'PY'
import sys
path = sys.argv[1]
lines = open(path, encoding="utf-8").read().split("\n")
i = 76  # 0-indexed line 77
assert "`Documentation complete — <path>`" in lines[i], "fixture assumption broken: expected span not found on line 77"
lines[i] = lines[i].replace("Documentation complete — <path>", "Documentation complet — <path>", 1)
open(path, "w", encoding="utf-8").write("\n".join(lines))
PY
  out="$(cd "$dir" && bash scripts/validate.sh 2>&1)"; code=$?
  [[ $code -ne 0 ]] || { echo "  expected nonzero exit, got 0"; result=1; }
  assert_contains "$out" "[signal-drift]" "reported by the new check specifically" || result=1
  assert_contains "$out" "skills/compound/SKILL.md:77" "file:line" || result=1
  rm -rf "$dir"
  return $result
}

# --- Case C: one-byte drift in skills/compound-refresh/SKILL.md:77 ---
case_c() {
  local dir out code result=0
  dir="$(setup_copy)" || return 1
  python3 - "$dir/skills/compound-refresh/SKILL.md" <<'PY'
import sys
path = sys.argv[1]
lines = open(path, encoding="utf-8").read().split("\n")
i = 76  # 0-indexed line 77
assert "`Refresh complete — <n> applied, <n> recommended`" in lines[i], "fixture assumption broken: expected span not found on line 77"
lines[i] = lines[i].replace("Refresh complete — <n> applied, <n> recommended", "Refresh complet — <n> applied, <n> recommended", 1)
open(path, "w", encoding="utf-8").write("\n".join(lines))
PY
  out="$(cd "$dir" && bash scripts/validate.sh 2>&1)"; code=$?
  [[ $code -ne 0 ]] || { echo "  expected nonzero exit, got 0"; result=1; }
  assert_contains "$out" "[signal-drift]" "reported by the new check specifically" || result=1
  assert_contains "$out" "skills/compound-refresh/SKILL.md:77" "file:line" || result=1
  rm -rf "$dir"
  return $result
}

# --- Case D: one-byte drift in skills/retrospective/SKILL.md:77 (cross-quoted compound line) ---
case_d() {
  local dir out code result=0
  dir="$(setup_copy)" || return 1
  python3 - "$dir/skills/retrospective/SKILL.md" <<'PY'
import sys
path = sys.argv[1]
lines = open(path, encoding="utf-8").read().split("\n")
i = 76  # 0-indexed line 77 - the cross-quoted `compound` triplet in Phase 7
assert "`Documentation complete — <path>`" in lines[i], "fixture assumption broken: expected span not found on line 77"
lines[i] = lines[i].replace("Documentation complete — <path>", "Documentation complet — <path>", 1)
open(path, "w", encoding="utf-8").write("\n".join(lines))
PY
  out="$(cd "$dir" && bash scripts/validate.sh 2>&1)"; code=$?
  [[ $code -ne 0 ]] || { echo "  expected nonzero exit, got 0"; result=1; }
  assert_contains "$out" "[signal-drift]" "reported by the new check specifically" || result=1
  assert_contains "$out" "skills/retrospective/SKILL.md:77" "file:line" || result=1
  assert_contains "$out" "producer 'compound'" "correct producer guessed from candidate's own word, not the file it lives in" || result=1
  rm -rf "$dir"
  return $result
}

# --- Case E: schemas/headless-contract.md emptied ---
# Note: existing check 2 (`[ -s schemas/headless-contract.md ]`) already fails
# on an emptied contract file today, before check 6 exists — verified by
# running this case pre-implementation. The `[signal-drift]` tag is what
# distinguishes "check 6 itself handled this gracefully" from "a pre-existing,
# unrelated check happened to also fire" — without it this case would show a
# false green today for the wrong reason.
case_e() {
  local dir out code result=0
  dir="$(setup_copy)" || return 1
  : > "$dir/schemas/headless-contract.md"
  out="$(cd "$dir" && bash scripts/validate.sh 2>&1)"; code=$?
  [[ $code -ne 0 ]] || { echo "  expected nonzero exit, got 0"; result=1; }
  assert_contains "$out" "FAIL:" "named fail" || result=1
  assert_contains "$out" "[signal-drift]" "check 6 itself (not just pre-existing check 2) reports this" || result=1
  assert_contains "$out" "schemas/headless-contract.md" "names the malformed file" || result=1
  assert_not_contains "$out" "Traceback" "no python traceback" || result=1
  rm -rf "$dir"
  return $result
}

# --- Case F: deleted signal line (coverage pass) ---
case_f() {
  local dir out code result=0
  dir="$(setup_copy)" || return 1
  python3 - "$dir/skills/compound/SKILL.md" <<'PY'
import sys
path = sys.argv[1]
text = open(path, encoding="utf-8").read()
clause = "`Documentation skipped — <reason>` (e.g. no solved problem found), "
assert clause in text, "fixture assumption broken: expected clause not found"
open(path, "w", encoding="utf-8").write(text.replace(clause, "", 1))
PY
  out="$(cd "$dir" && bash scripts/validate.sh 2>&1)"; code=$?
  [[ $code -ne 0 ]] || { echo "  expected nonzero exit, got 0"; result=1; }
  assert_contains "$out" "[signal-drift]" "reported by the new check specifically" || result=1
  assert_contains "$out" "producer 'compound'" "names the uncovered producer" || result=1
  assert_contains "$out" "state 'skipped'" "names the uncovered state" || result=1
  rm -rf "$dir"
  return $result
}

# --- Case G: missing consumer file ---
# Note: existing check 3 (skill-frontmatter roster check) already fails when
# skills/retrospective/SKILL.md is missing today, before check 6 exists —
# verified by running this case pre-implementation. Same `[signal-drift]`
# rationale as Case E.
case_g() {
  local dir out code result=0
  dir="$(setup_copy)" || return 1
  rm -f "$dir/skills/retrospective/SKILL.md"
  out="$(cd "$dir" && bash scripts/validate.sh 2>&1)"; code=$?
  [[ $code -ne 0 ]] || { echo "  expected nonzero exit, got 0"; result=1; }
  assert_contains "$out" "FAIL:" "named fail" || result=1
  assert_contains "$out" "[signal-drift]" "check 6 itself (not just pre-existing check 3) reports this" || result=1
  assert_contains "$out" "skills/retrospective/SKILL.md" "names the missing file" || result=1
  assert_not_contains "$out" "Traceback" "no python traceback" || result=1
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

echo
if [[ $FAIL_COUNT -eq 0 ]]; then
  echo "ALL CASES PASSED"
  exit 0
else
  echo "$FAIL_COUNT case(s) FAILED"
  exit 1
fi
