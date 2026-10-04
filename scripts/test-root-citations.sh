#!/usr/bin/env bash
# Fixture harness for the shared-reference citation check (scripts/validate.sh
# check 5a.). Extracts that check's Python body from validate.sh, runs it
# against a disposable mktemp -d tree holding one skill line per case, and
# asserts pass or fail. Never mutates the real skills/ or references/ files.
#
# Manual invocation only: not wired into scripts/validate.sh or any CI.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL_COUNT=0

CHECK="$(awk '/^# 5a\./{found=1; next} found && /<<'\''PY'\''/{body=1; next} body && /^PY$/{exit} body' "$ROOT/scripts/validate.sh")"
if [[ -z "$CHECK" ]]; then
  echo "harness error: check 5a body not found in scripts/validate.sh" >&2
  exit 1
fi

run_line() {
  local line="$1" dir out code
  dir="$(mktemp -d 2>&1)" || { echo "  harness error: mktemp -d failed: $dir" >&2; return 2; }
  mkdir -p "$dir/references" "$dir/skills/demo"
  : > "$dir/references/dispatch-degradation.md"
  : > "$dir/references/question-tools.md"
  printf '%s\n' "$line" > "$dir/skills/demo/SKILL.md"
  out="$(python3 - "$dir" <<<"$CHECK" 2>&1)"; code=$?
  rm -rf "$dir"
  printf '%s\n' "$out"
  return $code
}

expect() {
  local want="$1" label="$2" line="$3" out code
  out="$(run_line "$line")"; code=$?
  if [[ $code -eq 2 ]]; then
    echo "Case $label: FAIL (harness)"; FAIL_COUNT=$((FAIL_COUNT + 1)); return
  fi
  if [[ "$want" == pass && $code -eq 0 ]] || [[ "$want" == fail && $code -ne 0 && "$out" == *"without naming the plugin root"* ]]; then
    echo "Case $label: pass"
  else
    echo "Case $label: FAIL (expected $want, exit $code)"
    printf '  %s\n' "$out"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
}

expect pass "at the plugin root"       'Follow `references/question-tools.md` at the plugin root.'
expect pass "(plugin root)"            'Follow `references/question-tools.md` (plugin root) for the table.'
expect pass "(plugin root; ...)"       'Per `references/dispatch-degradation.md` (plugin root; native parallel first).'
expect pass "(repo root, shared)"      'Per `references/dispatch-degradation.md` (repo root, shared): dispatch.'
expect pass "(repo-root shared ...)"   'Follow `references/dispatch-degradation.md` (repo-root shared reference) unmodified.'
expect pass "./ form qualified"        'Follow `./references/question-tools.md` at the plugin root.'
expect pass "both qualified"           'See `references/question-tools.md` (plugin root) and `references/dispatch-degradation.md` (plugin root).'
expect pass "longer path not a cite"   'The copy at `skills/demo/references/question-tools.md` is removed.'
expect fail "bare"                     'Follow `references/question-tools.md` for the table.'
expect fail "./ form bare"             'Follow `./references/question-tools.md` for the table.'
expect fail "marker elsewhere on line" 'Follow `references/question-tools.md`; the plugin root holds other files.'
expect fail "one of two qualified"     'See `references/question-tools.md` and `references/dispatch-degradation.md` (plugin root).'

echo
if [[ $FAIL_COUNT -eq 0 ]]; then
  echo "ALL CASES PASSED"
else
  echo "$FAIL_COUNT CASE(S) FAILED"
  exit 1
fi
