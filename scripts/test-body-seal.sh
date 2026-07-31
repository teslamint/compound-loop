#!/usr/bin/env bash
# Fixture harness for validate.sh check 14 (body-seal integrity).
# Each case writes a plan fixture under a disposable mktemp -d directory's
# docs/plans/, runs validate.sh in that scratch copy, and asserts on exit
# code plus output substrings. Negative fixtures live in the scratch copy,
# never in the real docs/plans/.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL_COUNT=0
PASS_COUNT=0

setup_scratch() {
  local d
  d="$(mktemp -d)" || { echo "harness error: mktemp -d failed" >&2; return 1; }
  # Minimal repo structure so validate.sh checks 1-13 don't interfere
  mkdir -p "$d/scripts" "$d/docs/plans" "$d/schemas" "$d/skills/planning/scripts" \
           "$d/skills/planning/references" "$d/skills/compound/scripts" \
           "$d/skills/implementing" "$d/skills/reviewing" \
           "$d/skills/shipping" "$d/skills/shipping/references" \
           "$d/skills/retrospective" "$d/skills/release" \
           "$d/skills/designing" "$d/skills/release-loop/references" \
           "$d/.claude-plugin" "$d/.codex-plugin" "$d/docs/retros"
  # Copy essential files so other checks pass
  cp "$ROOT/.claude-plugin/plugin.json" "$d/.claude-plugin/" 2>/dev/null || true
  cp "$ROOT/.codex-plugin/plugin.json" "$d/.codex-plugin/" 2>/dev/null || true
  cp "$ROOT/schemas/"*.md "$d/schemas/" 2>/dev/null || true
  cp "$ROOT/schemas/"*.json "$d/schemas/" 2>/dev/null || true
  cp "$ROOT/PRINCIPLES.md" "$d/" 2>/dev/null || true
  cp "$ROOT/scripts/validate.sh" "$d/scripts/"
  # Copy skills so signal-drift, headless-contract, etc. checks pass
  for skill_dir in planning implementing reviewing shipping retrospective \
                   release designing release-loop compound; do
    if [ -d "$ROOT/skills/$skill_dir" ]; then
      cp -r "$ROOT/skills/$skill_dir/"* "$d/skills/$skill_dir/" 2>/dev/null || true
    fi
  done
  printf '%s\n' "$d"
}

write_plan() {
  local dir="$1" name="$2" frontmatter="$3" body="$4"
  cat > "$dir/docs/plans/$name" <<EOF
---
$frontmatter
---
$body
EOF
}

compute_seal() {
  local dir="$1" name="$2"
  local file="$dir/docs/plans/$name"
  python3 -c "
import hashlib
text = open('$file', encoding='utf-8').read()
body = text.split('---', 2)[2]
print(hashlib.sha256(body.encode('utf-8')).hexdigest())
"
}

run_validate() {
  local d="$1"
  bash "$d/scripts/validate.sh" 2>&1
}

assert_seal_verified() {
  local label="$1" out="$2" rc="$3" expect_verified="$4" expect_skipped="$5"
  local seal_line
  seal_line="$(echo "$out" | grep '\[body-seal\]' | grep -v FAIL | head -1)"
  if echo "$out" | grep -q 'FAIL: \[body-seal\]'; then
    echo "  FAIL: $label — unexpected body-seal FAIL line"
    echo "  output: $(echo "$out" | grep 'body-seal' | head -3)"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  elif echo "$seal_line" | grep -q "${expect_verified} verified, ${expect_skipped} skipped"; then
    echo "  PASS: $label"
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    echo "  FAIL: $label — expected ${expect_verified} verified, ${expect_skipped} skipped"
    echo "  got: $seal_line"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
}

assert_seal_fail() {
  local label="$1" out="$2" rc="$3"
  if [ "$rc" -ne 0 ] && echo "$out" | grep -q 'FAIL: \[body-seal\]'; then
    echo "  PASS: $label"
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    echo "  FAIL: $label — expected nonzero exit with FAIL: [body-seal]"
    echo "  exit=$rc output: $(echo "$out" | grep 'body-seal' | head -3)"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
}

# --- Fixture A: correct body_seal → PASS ---
echo "Fixture A: plan with correct body_seal"
d="$(setup_scratch)"
write_plan "$d" "test-sealed.md" \
  "schema: plan/v1
title: Test sealed plan
type: feat
status: approved
date: 2026-07-31
execution: code" \
  "
## Goal

This is a test plan with a correct body seal.
"
seal="$(compute_seal "$d" "test-sealed.md")"
# Rewrite with seal in frontmatter
write_plan "$d" "test-sealed.md" \
  "schema: plan/v1
title: Test sealed plan
type: feat
status: approved
date: 2026-07-31
execution: code
body_seal: $seal" \
  "
## Goal

This is a test plan with a correct body seal.
"
out="$(run_validate "$d")"; rc=$?
assert_seal_verified "correct body_seal → 1 verified, 0 skipped" "$out" "$rc" "1" "0"
rm -rf "$d"

# --- Fixture A2: golden-hash round-trip (write, seal, verify, re-read) ---
echo "Fixture A2: golden-hash round-trip"
d="$(setup_scratch)"
write_plan "$d" "test-golden.md" \
  "schema: plan/v1
title: Golden hash
type: feat
status: approved
date: 2026-07-31
execution: code" \
  "
## Goal

Fixed body for golden-hash round-trip.
"
golden="$(compute_seal "$d" "test-golden.md")"
# Re-seal: compute again independently to prove determinism
golden2="$(compute_seal "$d" "test-golden.md")"
if [ "$golden" != "$golden2" ]; then
  echo "  FAIL: golden-hash — non-deterministic: $golden vs $golden2"
  FAIL_COUNT=$((FAIL_COUNT + 1))
else
  write_plan "$d" "test-golden.md" \
    "schema: plan/v1
title: Golden hash
type: feat
status: approved
date: 2026-07-31
execution: code
body_seal: $golden" \
    "
## Goal

Fixed body for golden-hash round-trip.
"
  out="$(run_validate "$d")"; rc=$?
  assert_seal_verified "golden-hash round-trip → 1 verified" "$out" "$rc" "1" "0"
fi
rm -rf "$d"

# --- Fixture B: wrong body_seal → FAIL ---
echo "Fixture B: plan with wrong body_seal"
d="$(setup_scratch)"
write_plan "$d" "test-tampered.md" \
  "schema: plan/v1
title: Test tampered plan
type: feat
status: approved
date: 2026-07-31
execution: code
body_seal: 0000000000000000000000000000000000000000000000000000000000000000" \
  "
## Goal

This body does not match the fake seal above.
"
out="$(run_validate "$d")"; rc=$?
assert_seal_fail "wrong body_seal → FAIL line" "$out" "$rc"
rm -rf "$d"

# --- Fixture C: no body_seal → skip ---
echo "Fixture C: plan without body_seal"
d="$(setup_scratch)"
write_plan "$d" "test-unsealed.md" \
  "schema: plan/v1
title: Test unsealed plan
type: feat
status: approved
date: 2026-07-31
execution: code" \
  "
## Goal

This plan has no body_seal field.
"
out="$(run_validate "$d")"; rc=$?
assert_seal_verified "no body_seal → 0 verified, 1 skipped" "$out" "$rc" "0" "1"
rm -rf "$d"

# --- Fixture D: frontmatter mutation only (S8) → still verified ---
echo "Fixture D: sealed plan with frontmatter-only mutation (terminal-state flip)"
d="$(setup_scratch)"
write_plan "$d" "test-terminal.md" \
  "schema: plan/v1
title: Test terminal flip
type: feat
status: approved
date: 2026-07-31
execution: code" \
  "
## Goal

This plan will get a terminal-state flip.
"
seal="$(compute_seal "$d" "test-terminal.md")"
# Rewrite with seal, then mutate frontmatter only (done + completed_by)
write_plan "$d" "test-terminal.md" \
  "schema: plan/v1
title: Test terminal flip
type: feat
status: done
date: 2026-07-31
execution: code
body_seal: $seal
completed_by: abc123def" \
  "
## Goal

This plan will get a terminal-state flip.
"
out="$(run_validate "$d")"; rc=$?
assert_seal_verified "frontmatter-only mutation → 1 verified, 0 skipped" "$out" "$rc" "1" "0"
rm -rf "$d"

echo
echo "Results: $PASS_COUNT passed, $FAIL_COUNT failed"
if [ "$FAIL_COUNT" -gt 0 ]; then
  exit 1
fi
