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
PRISTINE_COMMIT="86586a0"
FAIL_COUNT=0
PARITY_MODE=1
PARITY_FAILED=0
RV_CODE=0
RV_STDOUT=""
RV_STDERR=""
RV_STDOUT_FILE=""
RV_STDERR_FILE=""
PV_CODE=0
PV_STDOUT=""
PV_STDERR=""
PV_STDOUT_FILE=""
PV_STDERR_FILE=""

cleanup_capture_files() {
  rm -f "${RV_STDOUT_FILE:-}" "${RV_STDERR_FILE:-}" \
    "${PV_STDOUT_FILE:-}" "${PV_STDERR_FILE:-}"
  RV_STDOUT_FILE=""
  RV_STDERR_FILE=""
  PV_STDOUT_FILE=""
  PV_STDERR_FILE=""
}

materialize_pristine() {
  local dir="$1" pristine_dir="$dir/pristine"
  mkdir -p "$pristine_dir" || return 1
  if ! git -C "$ROOT" show \
    "$PRISTINE_COMMIT:skills/planning/scripts/validate-plan-frontmatter.py" \
    >"$pristine_dir/validate-plan-frontmatter.py"; then
    echo "  harness error: could not materialize pristine validator" >&2
    return 1
  fi
  chmod +x "$pristine_dir/validate-plan-frontmatter.py"
}

pristine_for_plan() {
  local plan_path="$1" fixture_root
  fixture_root="$(cd "$(dirname "$plan_path")/../.." && pwd)" || return 1
  printf '%s/pristine/validate-plan-frontmatter.py\n' "$fixture_root"
}

setup_dir() {
  local dir
  dir="$(mktemp -d 2>&1)" || { echo "  harness error: mktemp -d failed: $dir" >&2; return 1; }
  mkdir -p "$dir/docs/plans" || return 1
  if ! materialize_pristine "$dir"; then
    rm -rf "$dir"
    return 1
  fi
  printf '%s\n' "$dir"
}

run_pristine_at() {
  local pristine="$1" cwd="$2" out_file err_file
  shift 2
  out_file="$(mktemp)"
  err_file="$(mktemp)"
  if (cd "$cwd" && python3 "$pristine" "$@") >"$out_file" 2>"$err_file"; then
    PV_CODE=0
  else
    PV_CODE=$?
  fi
  PV_STDOUT="$(cat "$out_file")"
  PV_STDERR="$(cat "$err_file")"
  PV_STDOUT_FILE="$out_file"
  PV_STDERR_FILE="$err_file"
}

run_validator_at() {
  local pristine="$1" cwd="$2" out_file err_file pristine_out pristine_err
  shift 2
  cleanup_capture_files
  out_file="$(mktemp)"
  err_file="$(mktemp)"
  if (cd "$cwd" && python3 "$VALIDATOR" "$@") >"$out_file" 2>"$err_file"; then
    RV_CODE=0
  else
    RV_CODE=$?
  fi
  RV_STDOUT="$(cat "$out_file")"
  RV_STDERR="$(cat "$err_file")"
  RV_STDOUT_FILE="$out_file"
  RV_STDERR_FILE="$err_file"

  if [[ "$PARITY_MODE" -eq 1 ]]; then
    pristine_out="$(mktemp)"
    pristine_err="$(mktemp)"
    if (cd "$cwd" && python3 "$pristine" "$@") >"$pristine_out" 2>"$pristine_err"; then
      PV_CODE=0
    else
      PV_CODE=$?
    fi
    PV_STDOUT="$(cat "$pristine_out")"
    PV_STDERR="$(cat "$pristine_err")"
    PV_STDOUT_FILE="$pristine_out"
    PV_STDERR_FILE="$pristine_err"
    if [[ "$RV_CODE" -ne "$PV_CODE" ]] \
      || ! cmp -s "$RV_STDOUT_FILE" "$PV_STDOUT_FILE" \
      || ! cmp -s "$RV_STDERR_FILE" "$PV_STDERR_FILE"; then
      PARITY_FAILED=1
      echo "  no-seal parity mismatch: candidate and pristine differ byte-for-byte"
    fi
  fi
}

run_validator() {
  local plan_path="$1" pristine
  pristine="$(pristine_for_plan "$plan_path")" || return 1
  run_validator_at "$pristine" "$(pwd)" "$@"
}
run_pristine_for_plan() {
  local plan_path="$1" pristine
  pristine="$(pristine_for_plan "$plan_path")" || return 1
  run_pristine_at "$pristine" "$(pwd)" "$plan_path"
}


assert_exact_stdout() {
  local expected="$1" label="$2" expected_file
  expected_file="$(mktemp)"
  printf '%s\n' "$expected" >"$expected_file"
  if cmp -s "$RV_STDOUT_FILE" "$expected_file"; then
    rm -f "$expected_file"
    return 0
  fi
  echo "  assertion failed ($label): stdout was not exactly one expected line"
  echo "  actual: $RV_STDOUT"
  rm -f "$expected_file"
  return 1
}

python_digest() {
  python3 - "$1" <<'PY'
import hashlib
import sys

with open(sys.argv[1], encoding="utf-8", newline=None) as handle:
    text = handle.read()
print(hashlib.sha256(text.split("---", 2)[2].encode("utf-8")).hexdigest())
PY
}

replace_seal_placeholder() {
  python3 - "$1" "$2" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
seal = sys.argv[2]
with path.open("r", encoding="utf-8", newline="") as handle:
    text = handle.read()
placeholder = "body_seal: " + ("0" * 64)
if placeholder not in text:
    raise SystemExit("body_seal placeholder missing")
text = text.replace(placeholder, f"body_seal: {seal}", 1)
with path.open("w", encoding="utf-8", newline="") as handle:
    handle.write(text)
PY
}

write_sealed_plan() {
  local plan="$1" title="$2" body="$3"
  cat >"$plan" <<EOF
---
schema: plan/v1
title: $title
type: feat
status: approved
date: 2026-08-15
execution: code
body_seal: 0000000000000000000000000000000000000000000000000000000000000000
---

$body
EOF
}

run_case() {
  local name="$1"
  shift
  PARITY_MODE=1
  PARITY_FAILED=0
  cleanup_capture_files
  echo "Case $name:"
  if "$@"; then
    if [[ "$PARITY_FAILED" -eq 1 ]]; then
      echo "  FAIL"
      FAIL_COUNT=$((FAIL_COUNT + 1))
    else
      echo "  pass"
    fi
  else
    echo "  FAIL"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
  cleanup_capture_files
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
execution: batch
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
  local dir pristine result=0
  dir="$(setup_dir)" || return 1
  pristine="$dir/pristine/validate-plan-frontmatter.py"
  run_validator_at "$pristine" "$dir"
  [[ $RV_CODE -eq 2 ]] || { echo "  expected exit 2, got $RV_CODE"; result=1; }
  rm -rf "$dir"
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
case_28_delimiter_guard_red() {
  local dir plan seal actual result=0 pristine
  dir="$(setup_dir)" || return 1
  plan="$dir/docs/plans/case-28.md"
  pristine="$dir/pristine/validate-plan-frontmatter.py"
  cat >"$plan" <<'EOF'
---
schema: plan/v1
title: "Case 28 --- inline delimiter"
type: feat
status: approved
date: 2026-08-15
execution: code
body_seal: 0000000000000000000000000000000000000000000000000000000000000000
---

The body is otherwise valid.
EOF
  seal="$(python_digest "$plan")" || { rm -rf "$dir"; return 1; }
  replace_seal_placeholder "$plan" "$seal" || { rm -rf "$dir"; return 1; }
  actual="$(python_digest "$plan")" || { rm -rf "$dir"; return 1; }

  PARITY_MODE=0
  run_validator "$plan"
  [[ $RV_CODE -eq 1 ]] || {
    echo "  expected canonical extraction mismatch exit 1, got $RV_CODE"
    result=1
  }
  assert_contains "$RV_STDERR" "'body_seal' mismatch" \
    "canonical extraction mismatch diagnostic" || result=1
  assert_contains "$RV_STDERR" "expected=$seal" "stored canonical seal" || result=1
  assert_contains "$RV_STDERR" "actual=$actual" "computed canonical seal" || result=1
  if [[ "$RV_STDERR" == *"Frontmatter contains '---' delimiters"* \
    || "$RV_STDERR" == *"Closing frontmatter delimiter"* ]]; then
    echo "  candidate RED: delimiter guard diagnostic replaced canonical mismatch"
    result=1
  fi

  run_pristine_at "$pristine" "$(pwd)" "$plan"
  [[ $PV_CODE -eq 0 ]] || {
    echo "  fixture error: pristine format-only validator rejected delimiter-inline plan"
    result=1
  }
  rm -rf "$dir"
  return $result
}

case_29_correct_seal() {
  local dir plan seal result=0
  dir="$(setup_dir)" || return 1
  plan="$dir/docs/plans/case-29.md"
  write_sealed_plan "$plan" "Case 29 Plan" "The canonical body is sealed."
  seal="$(python_digest "$plan")" || { rm -rf "$dir"; return 1; }
  replace_seal_placeholder "$plan" "$seal" || { rm -rf "$dir"; return 1; }
  PARITY_MODE=0
  run_validator "$plan"
  [[ $RV_CODE -eq 0 ]] || { echo "  expected correct seal to validate, got $RV_CODE"; result=1; }
  assert_contains "$RV_STDOUT" "OK:" "correct seal stdout" || result=1
  rm -rf "$dir"
  return $result
}

case_30_independent_python_digest_parity() {
  local dir plan seal pristine result=0
  dir="$(setup_dir)" || return 1
  plan="$dir/docs/plans/case-30.md"
  pristine="$dir/pristine/validate-plan-frontmatter.py"
  cat >"$plan" <<'EOF'
---
schema: plan/v1
title: Case 30 Unicode Plan
type: feat
status: draft
date: 2026-08-15
execution: code
---

Independent digest parity: café, 東京, and 한국어.
EOF
  seal="$(python_digest "$plan")" || { rm -rf "$dir"; return 1; }
  PARITY_MODE=0
  run_validator_at "$pristine" "$(pwd)" --print-seal "$plan"
  [[ $RV_CODE -eq 0 ]] || { echo "  expected print-seal exit 0, got $RV_CODE"; result=1; }
  assert_exact_stdout "$seal" "independent Python digest parity" || result=1
  PARITY_MODE=1
  run_validator_at "$pristine" "$(pwd)" "$plan"
  [[ $RV_CODE -eq 0 ]] || { echo "  expected no-seal normal validation exit 0, got $RV_CODE"; result=1; }
  [[ $PARITY_FAILED -eq 0 ]] || { echo "  no-seal independent digest fixture lost pristine parity"; result=1; }
  rm -rf "$dir"
  return $result
}

case_31_crlf_universal_newline_parity() {
  local dir plan seal pristine result=0
  dir="$(setup_dir)" || return 1
  plan="$dir/docs/plans/case-31-crlf.md"
  pristine="$dir/pristine/validate-plan-frontmatter.py"
  python3 - "$plan" <<'PY'
from pathlib import Path
import sys

text = (
    "---\r\n"
    "schema: plan/v1\r\n"
    "title: Case 31 CRLF Plan\r\n"
    "type: feat\r\n"
    "status: approved\r\n"
    "date: 2026-08-15\r\n"
    "execution: code\r\n"
    "body_seal: " + ("0" * 64) + "\r\n"
    "---\r\n"
    "\r\n"
    "CRLF body line.\r\n"
)
with open(sys.argv[1], "w", encoding="utf-8", newline="") as handle:
    handle.write(text)
PY
  seal="$(python_digest "$plan")" || { rm -rf "$dir"; return 1; }
  replace_seal_placeholder "$plan" "$seal" || { rm -rf "$dir"; return 1; }
  PARITY_MODE=0
  run_validator_at "$pristine" "$(pwd)" --print-seal "$plan"
  [[ $RV_CODE -eq 0 ]] || { echo "  expected CRLF print-seal exit 0, got $RV_CODE"; result=1; }
  assert_exact_stdout "$seal" "CRLF universal-newline digest parity" || result=1
  run_validator_at "$pristine" "$(pwd)" "$plan"
  [[ $RV_CODE -eq 0 ]] || { echo "  expected CRLF normal validation exit 0, got $RV_CODE"; result=1; }
  rm -rf "$dir"
  return $result
}

case_32_arbitrary_format_only_bypass() {
  local dir plan arbitrary actual result=0
  dir="$(setup_dir)" || return 1
  plan="$dir/docs/plans/case-32.md"
  arbitrary="ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff"
  write_sealed_plan "$plan" "Case 32 Arbitrary Seal" "The arbitrary seal must not bypass value verification."
  replace_seal_placeholder "$plan" "$arbitrary" || { rm -rf "$dir"; return 1; }
  run_pristine_for_plan "$plan"
  [[ $PV_CODE -eq 0 ]] || {
    echo "  expected pristine format-only validator to accept arbitrary 64-hex seal, got $PV_CODE"
    result=1
  }
  PARITY_MODE=0
  run_validator "$plan"
  actual="$(python_digest "$plan")" || { rm -rf "$dir"; return 1; }
  [[ $RV_CODE -eq 1 ]] || { echo "  expected arbitrary seal mismatch exit 1, got $RV_CODE"; result=1; }
  assert_contains "$RV_STDERR" "'body_seal' mismatch" "arbitrary seal mismatch diagnostic" || result=1
  assert_contains "$RV_STDERR" "expected=$arbitrary" "stored arbitrary seal" || result=1
  assert_contains "$RV_STDERR" "actual=$actual" "computed arbitrary seal" || result=1
  rm -rf "$dir"
  return $result
}

case_33_one_byte_body_mutation() {
  local dir plan original actual result=0
  dir="$(setup_dir)" || return 1
  plan="$dir/docs/plans/case-33.md"
  write_sealed_plan "$plan" "Case 33 Mutation Plan" "The body starts in a sealed state."
  original="$(python_digest "$plan")" || { rm -rf "$dir"; return 1; }
  replace_seal_placeholder "$plan" "$original" || { rm -rf "$dir"; return 1; }
  python3 - "$plan" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
with path.open("r", encoding="utf-8", newline="") as handle:
    text = handle.read()
needle = "The body starts in a sealed state."
if needle not in text:
    raise SystemExit("body mutation needle missing")
with path.open("w", encoding="utf-8", newline="") as handle:
    handle.write(text.replace(needle, "The body starts in a sealed state!", 1))
PY
  PARITY_MODE=0
  run_validator "$plan"
  actual="$(python_digest "$plan")" || { rm -rf "$dir"; return 1; }
  [[ $RV_CODE -eq 1 ]] || { echo "  expected body mutation exit 1, got $RV_CODE"; result=1; }
  assert_contains "$RV_STDERR" "'body_seal' mismatch" "body mutation mismatch diagnostic" || result=1
  assert_contains "$RV_STDERR" "expected=$original" "original body seal" || result=1
  assert_contains "$RV_STDERR" "actual=$actual" "mutated body seal" || result=1
  rm -rf "$dir"
  return $result
}

case_34_malformed_seal() {
  local dir plan result=0
  dir="$(setup_dir)" || return 1
  plan="$dir/docs/plans/case-34.md"
  write_sealed_plan "$plan" "Case 34 Malformed Seal" "Malformed seals retain the format diagnostic."
  replace_seal_placeholder "$plan" "not-a-seal" || { rm -rf "$dir"; return 1; }
  PARITY_MODE=0
  run_validator "$plan"
  [[ $RV_CODE -eq 1 ]] || { echo "  expected malformed seal exit 1, got $RV_CODE"; result=1; }
  assert_contains "$RV_STDERR" "body_seal" "malformed seal format diagnostic" || result=1
  run_pristine_for_plan "$plan"
  if [[ $PV_CODE -ne "$RV_CODE" ]]; then
    echo "  malformed seal return code changed from pristine: candidate=$RV_CODE pristine=$PV_CODE"
    result=1
  fi
  if ! cmp -s "$RV_STDOUT_FILE" "$PV_STDOUT_FILE"; then
    echo "  malformed seal stdout changed from pristine"
    result=1
  fi
  if ! cmp -s "$RV_STDERR_FILE" "$PV_STDERR_FILE"; then
    echo "  malformed seal stderr changed from pristine"
    result=1
  fi
  rm -rf "$dir"
  return $result
}

case_35_impossible_extraction_red() {
  local dir plan pristine result=0
  dir="$(setup_dir)" || return 1
  plan="$dir/docs/plans/case-35-impossible.md"
  pristine="$dir/pristine/validate-plan-frontmatter.py"
  printf 'not a frontmatter plan\n' >"$plan"
  PARITY_MODE=0
  run_validator_at "$pristine" "$(pwd)" --print-seal "$plan"
  [[ $RV_CODE -eq 1 ]] || {
    echo "  candidate RED: failed extraction returns successful empty output (got exit $RV_CODE)"
    result=1
  }
  [[ ! -s "$RV_STDOUT_FILE" ]] || {
    echo "  candidate RED: failed extraction printed successful output"
    result=1
  }
  assert_contains "$RV_STDERR" "body_seal" "named body-seal extraction diagnostic" || result=1
  assert_contains "$RV_STDERR" "extract" "body-seal extraction failure detail" || result=1
  rm -rf "$dir"
  return $result
}

case_36_missing_print_path() {
  local dir pristine result=0
  dir="$(setup_dir)" || return 1
  pristine="$dir/pristine/validate-plan-frontmatter.py"
  PARITY_MODE=0
  run_validator_at "$pristine" "$dir" --print-seal
  [[ $RV_CODE -eq 2 ]] || { echo "  expected missing print path exit 2, got $RV_CODE"; result=1; }
  rm -rf "$dir"
  return $result
}

case_37_extra_cli_argument() {
  local dir plan pristine result=0
  dir="$(setup_dir)" || return 1
  plan="$dir/docs/plans/case-37.md"
  pristine="$dir/pristine/validate-plan-frontmatter.py"
  cat >"$plan" <<'EOF'
---
schema: plan/v1
title: Case 37 Plan
type: feat
status: draft
date: 2026-08-15
execution: code
---
EOF
  PARITY_MODE=0
  run_validator_at "$pristine" "$(pwd)" --print-seal "$plan" unexpected
  [[ $RV_CODE -eq 2 ]] || { echo "  expected extra argument exit 2, got $RV_CODE"; result=1; }
  rm -rf "$dir"
  return $result
}

case_38_cwd_print_seal_ambiguity_red() {
  local dir pristine result=0
  dir="$(setup_dir)" || return 1
  pristine="$dir/pristine/validate-plan-frontmatter.py"
  cat >"$dir/--print-seal" <<'EOF'
---
schema: plan/v1
title: Case 38 CWD Named Plan
type: feat
status: draft
date: 2026-08-15
execution: code
---
EOF
  PARITY_MODE=0
  run_validator_at "$pristine" "$dir" --print-seal
  [[ $RV_CODE -eq 2 ]] || {
    echo "  candidate RED: bare --print-seal becomes ambiguous when cwd file exists (got exit $RV_CODE)"
    result=1
  }
  rm -rf "$dir"
  return $result
}

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
run_case 28 case_28_delimiter_guard_red
run_case 29 case_29_correct_seal
run_case 30 case_30_independent_python_digest_parity
run_case 31 case_31_crlf_universal_newline_parity
run_case 32 case_32_arbitrary_format_only_bypass
run_case 33 case_33_one_byte_body_mutation
run_case 34 case_34_malformed_seal
run_case 35 case_35_impossible_extraction_red
run_case 36 case_36_missing_print_path
run_case 37 case_37_extra_cli_argument
run_case 38 case_38_cwd_print_seal_ambiguity_red

echo
if [[ $FAIL_COUNT -eq 0 ]]; then
  echo "ALL CASES PASSED"
  exit 0
else
  echo "$FAIL_COUNT case(s) FAILED"
  exit 1
fi
