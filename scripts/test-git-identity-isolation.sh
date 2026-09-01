#!/usr/bin/env bash
# Unit tests for the Git identity boundary used by validation scripts.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL_COUNT=0

setup_repo() {
  local dir
  dir="$(mktemp -d 2>&1)" || { echo "  harness error: mktemp -d failed: $dir" >&2; return 1; }
  git -C "$dir" init -q || { rm -rf "$dir"; return 1; }
  git -C "$dir" config user.name "Canonical Fixture" || { rm -rf "$dir"; return 1; }
  git -C "$dir" config user.email "canonical@example.invalid" || { rm -rf "$dir"; return 1; }
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

assert_equal() {
  local actual="$1" expected="$2" label="$3"
  if [[ "$actual" == "$expected" ]]; then
    return 0
  fi
  echo "  assertion failed ($label): expected '$expected', got '$actual'"
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

case_identity_preserved() {
  local dir before after
  dir="$(setup_repo)" || return 1
  before="$(git_identity_baseline "$dir")"
  after="$(git_identity_baseline "$dir")"
  rm -rf "$dir"
  [[ "$after" == "$before" ]]
}

case_identity_mutation_detected() {
  local dir before out code
  dir="$(setup_repo)" || return 1
  before="$(git_identity_baseline "$dir")"
  git -C "$dir" config user.name fixture
  out="$(git_identity_unchanged "$dir" "$before" 2>&1)"; code=$?
  rm -rf "$dir"
  [[ $code -ne 0 ]] && assert_contains "$out" "[git-identity] local user.name/user.email changed during validation" "mutation diagnostic"
}

case_email_mutation_detected() {
  local dir before out code
  dir="$(setup_repo)" || return 1
  before="$(git_identity_baseline "$dir")"
  git -C "$dir" config user.email fixture@example.invalid
  out="$(git_identity_unchanged "$dir" "$before" 2>&1)"; code=$?
  rm -rf "$dir"
  [[ $code -ne 0 ]] && assert_contains "$out" "[git-identity] local user.name/user.email changed during validation" "email mutation diagnostic"
}

case_bare_repository_skipped() {
  local dir baseline
  dir="$(mktemp -d)" || return 1
  git -C "$dir" init --bare -q || { rm -rf "$dir"; return 1; }
  baseline="$(git_identity_baseline "$dir")"
  rm -rf "$dir"
  assert_equal "$baseline" "" "bare repository skipped"
}

case_metadata_less_child_skipped() {
  local dir baseline
  dir="$(setup_repo)" || return 1
  mkdir "$dir/fixture"
  baseline="$(git_identity_baseline "$dir/fixture")"
  rm -rf "$dir"
  assert_equal "$baseline" "" "metadata-less child skipped"
}

# shellcheck source=scripts/git-identity-invariant.sh
source "$ROOT/scripts/git-identity-invariant.sh"

run_case identity-preserved case_identity_preserved
run_case identity-mutation-detected case_identity_mutation_detected
run_case bare-repository-skipped case_bare_repository_skipped
run_case metadata-less-child-skipped case_metadata_less_child_skipped
run_case email-mutation-detected case_email_mutation_detected

if [[ $FAIL_COUNT -eq 0 ]]; then
  echo "ALL GIT IDENTITY ISOLATION CHECKS PASSED"
  exit 0
fi

echo "$FAIL_COUNT Git identity isolation check(s) failed"
exit 1
