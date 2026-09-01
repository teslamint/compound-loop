#!/usr/bin/env bash
# Fixture tests for the protected-branch commit identity policy.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
POLICY="$ROOT/scripts/check-commit-identity.sh"
FAIL_COUNT=0

setup_repo() {
  local dir
  dir="$(mktemp -d)" || return 1
  git -C "$dir" init -q || { rm -rf "$dir"; return 1; }
  git -C "$dir" config user.name "Canonical Fixture" || { rm -rf "$dir"; return 1; }
  git -C "$dir" config user.email "canonical@example.invalid" || { rm -rf "$dir"; return 1; }
  git -C "$dir" config commit.gpgsign false || { rm -rf "$dir"; return 1; }
  printf 'base\n' >"$dir/file"
  git -C "$dir" add file && git -C "$dir" commit -qm base || { rm -rf "$dir"; return 1; }
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

case_normal_identity_accepted() {
  local dir base out code
  dir="$(setup_repo)" || return 1
  base="$(git -C "$dir" rev-parse HEAD)"
  printf 'normal\n' >>"$dir/file"
  git -C "$dir" add file && git -C "$dir" commit -qm normal || { rm -rf "$dir"; return 1; }
  out="$(cd "$dir" && "$POLICY" "$base" HEAD 2>&1)"; code=$?
  rm -rf "$dir"
  [[ $code -eq 0 ]] && assert_contains "$out" "commit identities accepted" "normal identity"
}

case_fixture_author_rejected() {
  local dir base out code
  dir="$(setup_repo)" || return 1
  base="$(git -C "$dir" rev-parse HEAD)"
  git -C "$dir" config user.name fixture
  git -C "$dir" config user.email fixture@example.invalid
  printf 'fixture author\n' >>"$dir/file"
  git -C "$dir" add file && git -C "$dir" commit -qm fixture || { rm -rf "$dir"; return 1; }
  out="$(cd "$dir" && "$POLICY" "$base" HEAD 2>&1)"; code=$?
  rm -rf "$dir"
  [[ $code -ne 0 ]] && assert_contains "$out" "fixture identity" "fixture author diagnostic"
}

case_fixture_committer_rejected() {
  local dir base out code
  dir="$(setup_repo)" || return 1
  base="$(git -C "$dir" rev-parse HEAD)"
  printf 'fixture committer\n' >>"$dir/file"
  git -C "$dir" add file || { rm -rf "$dir"; return 1; }
  GIT_COMMITTER_NAME=fixture GIT_COMMITTER_EMAIL=fixture@example.invalid git -C "$dir" commit -qm committer || { rm -rf "$dir"; return 1; }
  out="$(cd "$dir" && "$POLICY" "$base" HEAD 2>&1)"; code=$?
  rm -rf "$dir"
  [[ $code -ne 0 ]] && assert_contains "$out" "fixture identity" "fixture committer diagnostic"
}

case_diverged_branch_accepted() {
  local dir base branch out code
  dir="$(setup_repo)" || return 1
  branch="$(git -C "$dir" symbolic-ref --short HEAD)"
  git -C "$dir" checkout -qb feature || { rm -rf "$dir"; return 1; }
  printf 'feature\n' >>"$dir/file"
  git -C "$dir" add file && git -C "$dir" commit -qm feature || { rm -rf "$dir"; return 1; }
  git -C "$dir" checkout -q "$branch" || { rm -rf "$dir"; return 1; }
  printf 'main\n' >>"$dir/file"
  git -C "$dir" add file && git -C "$dir" commit -qm main || { rm -rf "$dir"; return 1; }
  base="$(git -C "$dir" rev-parse HEAD)"
  out="$(cd "$dir" && "$POLICY" "$base" feature 2>&1)"; code=$?
  rm -rf "$dir"
  [[ $code -eq 0 ]] && assert_contains "$out" "commit identities accepted" "diverged branch"
}

run_case normal-identity-accepted case_normal_identity_accepted
run_case fixture-author-rejected case_fixture_author_rejected
run_case fixture-committer-rejected case_fixture_committer_rejected
run_case diverged-branch-accepted case_diverged_branch_accepted

if [[ $FAIL_COUNT -eq 0 ]]; then
  echo "ALL COMMIT IDENTITY POLICY CHECKS PASSED"
  exit 0
fi

echo "$FAIL_COUNT commit identity policy check(s) failed"
exit 1
