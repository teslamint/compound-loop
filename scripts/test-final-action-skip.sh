#!/usr/bin/env bash
# Fixture test for validate.sh check 11 skip-path: when no
# .release-loop/progress.md exists, check 11 must print "skipped"
# and validate.sh must still pass overall.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0
FAIL_COUNT=0

setup_copy() {
  local dir
  dir="$(mktemp -d 2>&1)" || { echo "  harness error: mktemp -d failed: $dir" >&2; return 1; }
  cp -r "$ROOT/." "$dir/"
  rm -rf "$dir/.git" "$dir/.release-loop"
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

# Case A: no .release-loop/ directory — check 11 skips
echo "Case A: no .release-loop/ — check 11 should skip"
COPY="$(setup_copy)"
if [ -z "$COPY" ]; then
  echo "  SKIP (setup_copy failed)"
else
  OUT="$(bash "$COPY/scripts/validate.sh" 2>&1)"
  RC=$?
  if [ "$RC" -eq 0 ] \
    && assert_contains "$OUT" "[final-action] no active progress.md — skipped" "skip message" \
    && assert_contains "$OUT" "ALL CHECKS PASSED" "overall pass"; then
    echo "  PASS"
    PASS=$((PASS + 1))
  else
    echo "  FAIL (rc=$RC)"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
  rm -rf "$COPY"
fi

echo
echo "$PASS passed, $FAIL_COUNT failed"
[ "$FAIL_COUNT" -eq 0 ]
