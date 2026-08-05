#!/usr/bin/env bash
# Structural regression for release-loop's default workspace policy.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILL="$ROOT/skills/release-loop/SKILL.md"
FAIL=0

fail() {
  echo "FAIL: [release-loop-worktree-default] $1"
  FAIL=1
}

section="$(awk '
  /^## Starting a new loop$/ { found=1; next }
  found && /^## / { exit }
  found { print }
' "$SKILL")"

[[ -n "$section" ]] || fail "Starting a new loop section missing or empty"

for required in \
  'Create a feature branch from HEAD via `worktree-isolation` by default.' \
  'Honor an explicit user request to work in the current checkout instead.' \
  'Treat an explicit request not to create a new worktree as the same exception.' \
  'Do not create a new branch or worktree when `--skip-*` resumes an existing branch.'
do
  [[ "$section" == *"$required"* ]] || fail "required contract missing: $required"
done

[[ "$section" != *'when isolation is wanted'* ]] \
  || fail "old opt-in isolation contract remains"

if [[ "$FAIL" -ne 0 ]]; then
  exit 1
fi

echo "ok:   release-loop defaults new work to isolated worktrees"
