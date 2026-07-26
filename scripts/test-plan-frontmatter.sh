#!/usr/bin/env bash
# Fixture harness for skills/planning/scripts/validate-plan-frontmatter.py.
# Each case writes a plan fixture (and any origin/superseded_by target files)
# under a disposable mktemp -d directory's docs/plans/, runs the validator
# against it, and asserts on exit code plus a stderr substring naming the
# offending field for failure cases. Fixtures live under <tmp>/docs/plans/ so
# the validator's own repo-root derivation (ascend to the nearest ancestor
# containing a docs/ directory) lands on <tmp>, independent of CWD.
#
# Manual invocation only: not wired into scripts/validate.sh or any CI.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VALIDATOR="$ROOT/skills/planning/scripts/validate-plan-frontmatter.py"
FAIL_COUNT=0

setup_dir() {
  local dir
  dir="$(mktemp -d 2>&1)" || { echo "  harness error: mktemp -d failed: $dir" >&2; return 1; }
  mkdir -p "$dir/docs/plans"
  printf '%s\n' "$dir"
}

# run_validator <plan-path>: sets RV_CODE, RV_STDOUT, RV_STDERR.
run_validator() {
  local plan_path="$1" out_file err_file
  out_file="$(mktemp)"
  err_file="$(mktemp)"
  python3 "$VALIDATOR" "$plan_path" >"$out_file" 2>"$err_file"
  RV_CODE=$?
  RV_STDOUT="$(cat "$out_file")"
  RV_STDERR="$(cat "$err_file")"
  rm -f "$out_file" "$err_file"
}

assert_contains() {
  local haystack="$1" needle="$2" label="$3"
  if [[ "$haystack" == *"$needle"* ]]; then
    return 0
  fi
  echo "  assertion failed ($label): expected output to contain: $needle"
  echo "  actual: $haystack"
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

# --- valid cases (exit 0) ---

case_01_draft_full_six() {
  local dir plan result=0
  dir="$(setup_dir)" || return 1
  plan="$dir/docs/plans/case-01.md"
  cat >"$plan" <<'EOF'
---
schema: plan/v1
title: Case 01 Plan
type: feat
status: draft
date: 2026-07-27
execution: code
---

# Case 01
EOF
  run_validator "$plan"
  [[ $RV_CODE -eq 0 ]] || { echo "  expected exit 0, got $RV_CODE"; result=1; }
  assert_contains "$RV_STDOUT" "OK:" "stdout OK" || result=1
  rm -rf "$dir"
  return $result
}

case_02_approved() {
  local dir plan result=0
  dir="$(setup_dir)" || return 1
  plan="$dir/docs/plans/case-02.md"
  cat >"$plan" <<'EOF'
---
schema: plan/v1
title: Case 02 Plan
type: feat
status: approved
date: 2026-07-27
execution: code
---
EOF
  run_validator "$plan"
  [[ $RV_CODE -eq 0 ]] || { echo "  expected exit 0, got $RV_CODE"; result=1; }
  assert_contains "$RV_STDOUT" "OK:" "stdout OK" || result=1
  rm -rf "$dir"
  return $result
}

case_03_done_with_completed_by() {
  local dir plan result=0
  dir="$(setup_dir)" || return 1
  plan="$dir/docs/plans/case-03.md"
  cat >"$plan" <<'EOF'
---
schema: plan/v1
title: Case 03 Plan
type: feat
status: done
date: 2026-07-27
execution: code
completed_by: abc1234
---
EOF
  run_validator "$plan"
  [[ $RV_CODE -eq 0 ]] || { echo "  expected exit 0, got $RV_CODE"; result=1; }
  assert_contains "$RV_STDOUT" "OK:" "stdout OK" || result=1
  rm -rf "$dir"
  return $result
}

case_04_superseded_with_existing_target() {
  local dir plan successor result=0
  dir="$(setup_dir)" || return 1
  successor="$dir/docs/plans/case-04-successor.md"
  cat >"$successor" <<'EOF'
---
schema: plan/v1
title: Case 04 Successor
type: feat
status: draft
date: 2026-07-27
execution: code
---
EOF
  plan="$dir/docs/plans/case-04.md"
  cat >"$plan" <<'EOF'
---
schema: plan/v1
title: Case 04 Plan
type: feat
status: superseded
date: 2026-07-27
execution: code
superseded_by: docs/plans/case-04-successor.md
---
EOF
  run_validator "$plan"
  [[ $RV_CODE -eq 0 ]] || { echo "  expected exit 0, got $RV_CODE"; result=1; }
  assert_contains "$RV_STDOUT" "OK:" "stdout OK" || result=1
  rm -rf "$dir"
  return $result
}

case_05_legacy_six_keys() {
  local dir plan result=0
  dir="$(setup_dir)" || return 1
  plan="$dir/docs/plans/case-05.md"
  cat >"$plan" <<'EOF'
---
schema: plan/v1
title: Case 05 Legacy Plan
type: chore
status: approved
date: 2026-07-27
execution: non-code
---
EOF
  run_validator "$plan"
  [[ $RV_CODE -eq 0 ]] || { echo "  expected exit 0, got $RV_CODE"; result=1; }
  assert_contains "$RV_STDOUT" "OK:" "stdout OK" || result=1
  rm -rf "$dir"
  return $result
}

case_06_unknown_fields_ok() {
  local dir plan result=0
  dir="$(setup_dir)" || return 1
  plan="$dir/docs/plans/case-06.md"
  cat >"$plan" <<'EOF'
---
schema: plan/v1
title: Case 06 Plan
type: feat
status: draft
date: 2026-07-27
execution: code
deepened: true
never_seen_key: whatever
---
EOF
  run_validator "$plan"
  [[ $RV_CODE -eq 0 ]] || { echo "  expected exit 0, got $RV_CODE"; result=1; }
  assert_contains "$RV_STDOUT" "OK:" "stdout OK" || result=1
  rm -rf "$dir"
  return $result
}

# --- invalid cases (exit 1, stderr names the field) ---

case_07_status_in_progress() {
  local dir plan result=0
  dir="$(setup_dir)" || return 1
  plan="$dir/docs/plans/case-07.md"
  cat >"$plan" <<'EOF'
---
schema: plan/v1
title: Case 07 Plan
type: feat
status: in-progress
date: 2026-07-27
execution: code
---
EOF
  run_validator "$plan"
  [[ $RV_CODE -eq 1 ]] || { echo "  expected exit 1, got $RV_CODE"; result=1; }
  assert_contains "$RV_STDERR" "status" "names field" || result=1
  rm -rf "$dir"
  return $result
}

case_08_status_abandoned() {
  local dir plan result=0
  dir="$(setup_dir)" || return 1
  plan="$dir/docs/plans/case-08.md"
  cat >"$plan" <<'EOF'
---
schema: plan/v1
title: Case 08 Plan
type: feat
status: abandoned
date: 2026-07-27
execution: code
---
EOF
  run_validator "$plan"
  [[ $RV_CODE -eq 1 ]] || { echo "  expected exit 1, got $RV_CODE"; result=1; }
  assert_contains "$RV_STDERR" "status" "names field" || result=1
  rm -rf "$dir"
  return $result
}

case_09_done_without_completed_by() {
  local dir plan result=0
  dir="$(setup_dir)" || return 1
  plan="$dir/docs/plans/case-09.md"
  cat >"$plan" <<'EOF'
---
schema: plan/v1
title: Case 09 Plan
type: feat
status: done
date: 2026-07-27
execution: code
---
EOF
  run_validator "$plan"
  [[ $RV_CODE -eq 1 ]] || { echo "  expected exit 1, got $RV_CODE"; result=1; }
  assert_contains "$RV_STDERR" "completed_by" "names field" || result=1
  rm -rf "$dir"
  return $result
}

case_10_superseded_without_superseded_by() {
  local dir plan result=0
  dir="$(setup_dir)" || return 1
  plan="$dir/docs/plans/case-10.md"
  cat >"$plan" <<'EOF'
---
schema: plan/v1
title: Case 10 Plan
type: feat
status: superseded
date: 2026-07-27
execution: code
---
EOF
  run_validator "$plan"
  [[ $RV_CODE -eq 1 ]] || { echo "  expected exit 1, got $RV_CODE"; result=1; }
  assert_contains "$RV_STDERR" "superseded_by" "names field" || result=1
  rm -rf "$dir"
  return $result
}

case_11_superseded_by_missing_path() {
  local dir plan result=0
  dir="$(setup_dir)" || return 1
  plan="$dir/docs/plans/case-11.md"
  cat >"$plan" <<'EOF'
---
schema: plan/v1
title: Case 11 Plan
type: feat
status: superseded
date: 2026-07-27
execution: code
superseded_by: docs/plans/does-not-exist.md
---
EOF
  run_validator "$plan"
  [[ $RV_CODE -eq 1 ]] || { echo "  expected exit 1, got $RV_CODE"; result=1; }
  assert_contains "$RV_STDERR" "superseded_by" "names field" || result=1
  rm -rf "$dir"
  return $result
}

case_12_origin_missing_path() {
  local dir plan result=0
  dir="$(setup_dir)" || return 1
  plan="$dir/docs/plans/case-12.md"
  cat >"$plan" <<'EOF'
---
schema: plan/v1
title: Case 12 Plan
type: feat
status: draft
date: 2026-07-27
execution: code
origin: docs/specs/does-not-exist.md
---
EOF
  run_validator "$plan"
  [[ $RV_CODE -eq 1 ]] || { echo "  expected exit 1, got $RV_CODE"; result=1; }
  assert_contains "$RV_STDERR" "origin" "names field" || result=1
  rm -rf "$dir"
  return $result
}

case_13_schema_wrong_version() {
  local dir plan result=0
  dir="$(setup_dir)" || return 1
  plan="$dir/docs/plans/case-13.md"
  cat >"$plan" <<'EOF'
---
schema: plan/v2
title: Case 13 Plan
type: feat
status: draft
date: 2026-07-27
execution: code
---
EOF
  run_validator "$plan"
  [[ $RV_CODE -eq 1 ]] || { echo "  expected exit 1, got $RV_CODE"; result=1; }
  assert_contains "$RV_STDERR" "schema" "names field" || result=1
  rm -rf "$dir"
  return $result
}

case_14_missing_schema() {
  local dir plan result=0
  dir="$(setup_dir)" || return 1
  plan="$dir/docs/plans/case-14.md"
  cat >"$plan" <<'EOF'
---
title: Case 14 Plan
type: feat
status: draft
date: 2026-07-27
execution: code
---
EOF
  run_validator "$plan"
  [[ $RV_CODE -eq 1 ]] || { echo "  expected exit 1, got $RV_CODE"; result=1; }
  assert_contains "$RV_STDERR" "schema" "names field" || result=1
  rm -rf "$dir"
  return $result
}

case_15_missing_title() {
  local dir plan result=0
  dir="$(setup_dir)" || return 1
  plan="$dir/docs/plans/case-15.md"
  cat >"$plan" <<'EOF'
---
schema: plan/v1
type: feat
status: draft
date: 2026-07-27
execution: code
---
EOF
  run_validator "$plan"
  [[ $RV_CODE -eq 1 ]] || { echo "  expected exit 1, got $RV_CODE"; result=1; }
  assert_contains "$RV_STDERR" "title" "names field" || result=1
  rm -rf "$dir"
  return $result
}

case_16_missing_type() {
  local dir plan result=0
  dir="$(setup_dir)" || return 1
  plan="$dir/docs/plans/case-16.md"
  cat >"$plan" <<'EOF'
---
schema: plan/v1
title: Case 16 Plan
status: draft
date: 2026-07-27
execution: code
---
EOF
  run_validator "$plan"
  [[ $RV_CODE -eq 1 ]] || { echo "  expected exit 1, got $RV_CODE"; result=1; }
  assert_contains "$RV_STDERR" "type" "names field" || result=1
  rm -rf "$dir"
  return $result
}

case_17_missing_status() {
  local dir plan result=0
  dir="$(setup_dir)" || return 1
  plan="$dir/docs/plans/case-17.md"
  cat >"$plan" <<'EOF'
---
schema: plan/v1
title: Case 17 Plan
type: feat
date: 2026-07-27
execution: code
---
EOF
  run_validator "$plan"
  [[ $RV_CODE -eq 1 ]] || { echo "  expected exit 1, got $RV_CODE"; result=1; }
  assert_contains "$RV_STDERR" "status" "names field" || result=1
  rm -rf "$dir"
  return $result
}

case_18_missing_date() {
  local dir plan result=0
  dir="$(setup_dir)" || return 1
  plan="$dir/docs/plans/case-18.md"
  cat >"$plan" <<'EOF'
---
schema: plan/v1
title: Case 18 Plan
type: feat
status: draft
execution: code
---
EOF
  run_validator "$plan"
  [[ $RV_CODE -eq 1 ]] || { echo "  expected exit 1, got $RV_CODE"; result=1; }
  assert_contains "$RV_STDERR" "date" "names field" || result=1
  rm -rf "$dir"
  return $result
}

case_19_missing_execution() {
  local dir plan result=0
  dir="$(setup_dir)" || return 1
  plan="$dir/docs/plans/case-19.md"
  cat >"$plan" <<'EOF'
---
schema: plan/v1
title: Case 19 Plan
type: feat
status: draft
date: 2026-07-27
---
EOF
  run_validator "$plan"
  [[ $RV_CODE -eq 1 ]] || { echo "  expected exit 1, got $RV_CODE"; result=1; }
  assert_contains "$RV_STDERR" "execution" "names field" || result=1
  rm -rf "$dir"
  return $result
}

case_20_execution_invalid() {
  local dir plan result=0
  dir="$(setup_dir)" || return 1
  plan="$dir/docs/plans/case-20.md"
  cat >"$plan" <<'EOF'
---
schema: plan/v1
title: Case 20 Plan
type: feat
status: draft
date: 2026-07-27
execution: ops
---
EOF
  run_validator "$plan"
  [[ $RV_CODE -eq 1 ]] || { echo "  expected exit 1, got $RV_CODE"; result=1; }
  assert_contains "$RV_STDERR" "execution" "names field" || result=1
  rm -rf "$dir"
  return $result
}

case_21_type_invalid() {
  local dir plan result=0
  dir="$(setup_dir)" || return 1
  plan="$dir/docs/plans/case-21.md"
  cat >"$plan" <<'EOF'
---
schema: plan/v1
title: Case 21 Plan
type: unknown
status: draft
date: 2026-07-27
execution: code
---
EOF
  run_validator "$plan"
  [[ $RV_CODE -eq 1 ]] || { echo "  expected exit 1, got $RV_CODE"; result=1; }
  assert_contains "$RV_STDERR" "type" "names field" || result=1
  rm -rf "$dir"
  return $result
}

case_22_malformed_date() {
  local dir plan result=0
  dir="$(setup_dir)" || return 1
  plan="$dir/docs/plans/case-22.md"
  cat >"$plan" <<'EOF'
---
schema: plan/v1
title: Case 22 Plan
type: feat
status: draft
date: 2026-7-27
execution: code
---
EOF
  run_validator "$plan"
  [[ $RV_CODE -eq 1 ]] || { echo "  expected exit 1, got $RV_CODE"; result=1; }
  assert_contains "$RV_STDERR" "date" "names field" || result=1
  rm -rf "$dir"
  return $result
}

case_23_unquoted_hash_parser_safety() {
  local dir plan result=0
  dir="$(setup_dir)" || return 1
  plan="$dir/docs/plans/case-23.md"
  cat >"$plan" <<'EOF'
---
schema: plan/v1
title: Case 23 Plan # trailing comment-looking text
type: feat
status: draft
date: 2026-07-27
execution: code
---
EOF
  run_validator "$plan"
  [[ $RV_CODE -eq 1 ]] || { echo "  expected exit 1, got $RV_CODE"; result=1; }
  assert_contains "$RV_STDERR" "title" "names field" || result=1
  rm -rf "$dir"
  return $result
}

# --- usage cases (exit 2) ---

case_24_no_argument() {
  local result=0
  run_validator_no_arg() {
    local out_file err_file
    out_file="$(mktemp)"
    err_file="$(mktemp)"
    python3 "$VALIDATOR" >"$out_file" 2>"$err_file"
    RV_CODE=$?
    RV_STDOUT="$(cat "$out_file")"
    RV_STDERR="$(cat "$err_file")"
    rm -f "$out_file" "$err_file"
  }
  run_validator_no_arg
  [[ $RV_CODE -eq 2 ]] || { echo "  expected exit 2, got $RV_CODE"; result=1; }
  return $result
}

case_25_nonexistent_file() {
  local dir plan result=0
  dir="$(setup_dir)" || return 1
  plan="$dir/docs/plans/does-not-exist.md"
  run_validator "$plan"
  [[ $RV_CODE -eq 2 ]] || { echo "  expected exit 2, got $RV_CODE"; result=1; }
  rm -rf "$dir"
  return $result
}

# --- additional parser-safety / origin-resolution cases ---

case_26_colon_space_parser_safety() {
  local dir plan result=0
  dir="$(setup_dir)" || return 1
  plan="$dir/docs/plans/case-26.md"
  cat >"$plan" <<'EOF'
---
schema: plan/v1
title: Case 26 Plan: a nested-looking value
type: feat
status: draft
date: 2026-07-27
execution: code
---
EOF
  run_validator "$plan"
  [[ $RV_CODE -eq 1 ]] || { echo "  expected exit 1, got $RV_CODE"; result=1; }
  assert_contains "$RV_STDERR" "title" "names field" || result=1
  rm -rf "$dir"
  return $result
}

case_27_origin_resolves() {
  local dir plan spec result=0
  dir="$(setup_dir)" || return 1
  mkdir -p "$dir/docs/specs"
  spec="$dir/docs/specs/case-27-spec.md"
  cat >"$spec" <<'EOF'
# Case 27 Spec
EOF
  plan="$dir/docs/plans/case-27.md"
  cat >"$plan" <<'EOF'
---
schema: plan/v1
title: Case 27 Plan
type: feat
status: draft
date: 2026-07-27
execution: code
origin: docs/specs/case-27-spec.md
---
EOF
  run_validator "$plan"
  [[ $RV_CODE -eq 0 ]] || { echo "  expected exit 0, got $RV_CODE"; result=1; }
  assert_contains "$RV_STDOUT" "OK:" "stdout OK" || result=1
  rm -rf "$dir"
  return $result
}

run_case 01 case_01_draft_full_six
run_case 02 case_02_approved
run_case 03 case_03_done_with_completed_by
run_case 04 case_04_superseded_with_existing_target
run_case 05 case_05_legacy_six_keys
run_case 06 case_06_unknown_fields_ok
run_case 07 case_07_status_in_progress
run_case 08 case_08_status_abandoned
run_case 09 case_09_done_without_completed_by
run_case 10 case_10_superseded_without_superseded_by
run_case 11 case_11_superseded_by_missing_path
run_case 12 case_12_origin_missing_path
run_case 13 case_13_schema_wrong_version
run_case 14 case_14_missing_schema
run_case 15 case_15_missing_title
run_case 16 case_16_missing_type
run_case 17 case_17_missing_status
run_case 18 case_18_missing_date
run_case 19 case_19_missing_execution
run_case 20 case_20_execution_invalid
run_case 21 case_21_type_invalid
run_case 22 case_22_malformed_date
run_case 23 case_23_unquoted_hash_parser_safety
run_case 24 case_24_no_argument
run_case 25 case_25_nonexistent_file
run_case 26 case_26_colon_space_parser_safety
run_case 27 case_27_origin_resolves

echo
if [[ $FAIL_COUNT -eq 0 ]]; then
  echo "ALL CASES PASSED"
  exit 0
else
  echo "$FAIL_COUNT case(s) FAILED"
  exit 1
fi
