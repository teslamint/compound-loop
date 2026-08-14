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

# --- Phase 8 pre-commit checker -------------------------------------------
# A second implementation of the Phase 8 pre-commit rule that
# skills/retrospective/SKILL.md states in prose. It reads a disposable
# fixture retro document only; it never reads docs/retros/ and is not a
# repository linter.
#
#   check_retro_doc <retro-doc-path> [previous-retro-doc-path]
#     exit 0 -> accept
#     exit 1 -> reject; prints exactly one condition name on stdout
#     exit 2 -> document missing or unreadable; prints no condition name
#
# The optional second path is the previous retro document. Every condition
# function receives it as `$2`; the six conditions that only read the current
# document ignore it. An omitted or unreadable previous document leaves
# `phase4-unregistered` with nothing to compare, which it treats as satisfied.
#
# Conditions evaluate in RETRO_CONDITIONS order and the first failure is the
# one reported. Adding a condition is one array entry plus one
# cond_<name-with-underscores> function; nothing else changes.
RETRO_CONDITIONS=(phase8-headless phase8-capability W1 W2 W3 W4 phase4-unregistered)

# Level values are the case-sensitivity exception: they match exactly.
RETRO_DEGRADED_LEVELS=("in-thread (approximated independence)" "self-checklist")
RETRO_NOTPROBED_LEVEL="not-probed (no narrative warranted)"

RETRO_LEVEL=""
RETRO_ROUNDS_LINE=""
RETRO_DEGRADED=0
RETRO_NOTPROBED=0

retro_parse_doc() {
  local doc="$1" lvl
  RETRO_LEVEL=""
  RETRO_ROUNDS_LINE=""
  RETRO_DEGRADED=0
  RETRO_NOTPROBED=0
  [[ -r "$doc" ]] || return 1
  RETRO_LEVEL="$(sed -n 's/^- Independence level:[[:space:]]*//p' "$doc" | head -n 1)"
  RETRO_ROUNDS_LINE="$(sed -n '/^- Rounds used:/p' "$doc" | head -n 1)"
  for lvl in "${RETRO_DEGRADED_LEVELS[@]}"; do
    [[ "$RETRO_LEVEL" == "$lvl" ]] && RETRO_DEGRADED=1
  done
  [[ "$RETRO_LEVEL" == "$RETRO_NOTPROBED_LEVEL" ]] && RETRO_NOTPROBED=1
  return 0
}

# Data rows of a markdown table read from stdin: the pipe rows that follow the
# `---` separator row, which drops the header-label row by construction. A
# blank line ends the table.
table_data_rows() {
  awk '
    /^\|/ {
      if ($0 ~ /^\|[[:space:]:|-]+\|[[:space:]]*$/) { after = 1; next }
      if (after) print
      next
    }
    { after = 0 }
  '
}

# The last cell of a pipe row, trimmed.
last_cell() {
  local row="$1"
  row="${row%"${row##*[![:space:]]}"}"
  row="${row%|}"
  row="${row##*|}"
  row="${row#"${row%%[![:space:]]*}"}"
  row="${row%"${row##*[![:space:]]}"}"
  printf '%s\n' "$row"
}

# The first cell of a pipe row, trimmed.
first_cell() {
  local row="$1"
  row="${row#"${row%%[![:space:]]*}"}"
  row="${row#|}"
  row="${row%%|*}"
  row="${row#"${row%%[![:space:]]*}"}"
  row="${row%"${row##*[![:space:]]}"}"
  printf '%s\n' "$row"
}

# `headless` as a token on the rounds-used line, when the level is degraded.
cond_phase8_headless() {
  local _doc="$1"
  [[ $RETRO_DEGRADED -eq 1 ]] || return 0
  grep -Eqi '(^|[^[:alnum:]_-])headless([^[:alnum:]_-]|$)' <<<"$RETRO_ROUNDS_LINE" && return 1
  return 0
}

# Both facilitator-channel anchors on the rounds-used line, case-insensitively,
# when the level is degraded.
cond_phase8_capability() {
  local _doc="$1" line
  [[ $RETRO_DEGRADED -eq 1 ]] || return 0
  line="$(tr '[:upper:]' '[:lower:]' <<<"$RETRO_ROUNDS_LINE")"
  [[ "$line" == *"no subagent primitive"* ]] || return 1
  [[ "$line" == *"no external facilitator cli"* ]] || return 1
  return 0
}

# --- not-probed warrant conditions W1-W4 ----------------------------------
# All four gate on the exact level `not-probed (no narrative warranted)`: they
# are the warrant for that level alone, so any other level satisfies them
# vacuously. An absent field fails the condition it belongs to — absence of
# evidence never authorizes the cheapest level.

# W1: no Verdict cell of the Phase 3 table reads `Partially met` or `Not met`
# (casing of schemas/retro-template.md line 35, matched case-insensitively), or
# that same section states that no spec exists — the parenthetical form of
# schemas/retro-template.md line 37. The no-spec escape hatch is scoped to the
# section, like every other condition's read: an incidental sentence elsewhere
# in the document does not license the cheapest level. An absent section, and a
# present section carrying no data row, both fail when the statement is absent.
cond_W1() {
  local doc="$1" section rows row cell
  [[ $RETRO_NOTPROBED -eq 1 ]] || return 0
  section="$(extract_section "$doc" "## Success criteria: measured vs declared")"
  [[ -n "$section" ]] || return 1
  grep -qi 'no spec exists' <<<"$section" && return 0
  rows="$(table_data_rows <<<"$section")"
  [[ -n "$rows" ]] || return 1
  while IFS= read -r row; do
    [[ -n "$row" ]] || continue
    cell="$(last_cell "$row")"
    grep -Eqi 'partially met|not met' <<<"$cell" && return 1
  done <<<"$rows"
  return 0
}

# W2: the Phase 4 reconciliation bullet records registered N equal to
# accounted-for M. The degraded no-table fallback never satisfies W2, so a
# `registered 0, accounted for 0` produced by a missing table is a failure.
cond_W2() {
  local doc="$1" line n m
  [[ $RETRO_NOTPROBED -eq 1 ]] || return 0
  line="$(extract_section "$doc" "## Carry-forward from previous retro" \
    | grep -i '^- Reconciliation:' | head -n 1 | tr '[:upper:]' '[:lower:]')"
  [[ -n "$line" ]] || return 1
  [[ "$line" == *"degraded: previous retro has no registration table"* ]] && return 1
  [[ "$line" =~ registered\ ([0-9]+),\ accounted\ for\ ([0-9]+) ]] || return 1
  n="${BASH_REMATCH[1]}"
  m="${BASH_REMATCH[2]}"
  [[ "$n" -eq "$m" ]] || return 1
  return 0
}

# W3: the Findings section carries no entry outside the What Worked Well
# bucket. A `### ` sub-heading opens a bucket; a list item is an entry. An
# absent section fails: a document with no findings at all has not shown that
# it has no narrative, it has only declined to say.
cond_W3() {
  local doc="$1" section
  [[ $RETRO_NOTPROBED -eq 1 ]] || return 0
  section="$(extract_section "$doc" "## Findings")"
  [[ -n "$section" ]] || return 1
  awk '
    /^### / { bucket = tolower($0); sub(/^###[[:space:]]*/, "", bucket); next }
    /^[[:space:]]*[-*][[:space:]]/ { if (bucket != "what worked well") { found = 1; exit } }
    END { exit(found ? 1 : 0) }
  ' <<<"$section"
}

# W4, two paths. Zero transcript rows require both capability anchors on the
# rounds-used line — the same absent-capability claim `self-checklist` carries.
# A row-bearing transcript requires that no row records `self-attested`, which
# is never a valid not-probed verdict.
cond_W4() {
  local doc="$1" rows row cell
  [[ $RETRO_NOTPROBED -eq 1 ]] || return 0
  rows="$(extract_section "$doc" "## Interview Transcript" | table_data_rows)"
  if [[ -z "$rows" ]]; then
    local line
    line="$(tr '[:upper:]' '[:lower:]' <<<"$RETRO_ROUNDS_LINE")"
    [[ "$line" == *"no subagent primitive"* ]] || return 1
    [[ "$line" == *"no external facilitator cli"* ]] || return 1
    return 0
  fi
  while IFS= read -r row; do
    [[ -n "$row" ]] || continue
    cell="$(last_cell "$row" | tr '[:upper:]' '[:lower:]')"
    [[ "$cell" == *"self-attested"* ]] && return 1
  done <<<"$rows"
  return 0
}

# --- phase4-unregistered --------------------------------------------------
# Reconciliation by name, not by count. The registered set is the first cell of
# every data row of `## Carry-forward items registered` in the previous
# document; the accounted-for set is the first cell of every data row of
# `## Carry-forward from previous retro` in the current one. A current row
# naming an item the previous document never registered fails: it inflates the
# accounted-for count, and an inflated count can conceal a dropped item.
# Whitespace is stripped and the comparison is case-insensitive. With no
# previous document there is nothing to compare, so the condition is satisfied;
# a previous document that carries no registration table registers nothing, so
# any current data row fails.
cond_phase4_unregistered() {
  local doc="$1" prev="${2:-}" registered rows row name reg_names=""
  [[ -n "$prev" && -r "$prev" ]] || return 0
  rows="$(extract_section "$doc" "## Carry-forward from previous retro" | table_data_rows)"
  [[ -n "$rows" ]] || return 0
  registered="$(extract_section "$prev" "## Carry-forward items registered" | table_data_rows)"
  while IFS= read -r row; do
    [[ -n "$row" ]] || continue
    reg_names+=$'\n'"$(first_cell "$row" | tr '[:upper:]' '[:lower:]')"
  done <<<"$registered"
  while IFS= read -r row; do
    [[ -n "$row" ]] || continue
    name="$(first_cell "$row" | tr '[:upper:]' '[:lower:]')"
    [[ -n "$name" ]] || continue
    grep -qxF -- "$name" <<<"$reg_names" || return 1
  done <<<"$rows"
  return 0
}

check_retro_doc() {
  local doc="$1" prev="${2:-}" name fn
  retro_parse_doc "$doc" || return 2
  for name in "${RETRO_CONDITIONS[@]}"; do
    fn="cond_${name//-/_}"
    if ! "$fn" "$doc" "$prev"; then
      printf '%s\n' "$name"
      return 1
    fi
  done
  return 0
}

# Section scope: the text from a named `## ` heading up to the next `## `.
extract_section() {
  local file="$1" heading="$2"
  awk -v h="$heading" '
    $0 == h { inside = 1; print; next }
    inside && /^## / { exit }
    inside { print }
  ' "$file"
}

# Couples the checker to the prose that owns the rule. Scoped to the Phase 8
# section: two of these anchors also occur in the Phase 5 dispatch prose, so a
# file-wide check would stay green after the Phase 8 clause moved or weakened.
assert_phase8_anchors() {
  local dir="$1" section anchor
  section="$(extract_section "$dir/skills/retrospective/SKILL.md" "## Phase 8: Commit & Report")"
  if [[ -z "$section" ]]; then
    echo "  assertion failed (phase 8 anchors): Phase 8 section not found"
    return 1
  fi
  for anchor in "not an absent capability" "no subagent primitive" "no external facilitator CLI"; do
    if [[ "$section" != *"$anchor"* ]]; then
      echo "  assertion failed (phase 8 anchors): Phase 8 section missing anchor: $anchor"
      return 1
    fi
  done
  return 0
}

write_fixture_retro() {
  local doc="$1" level="$2" rounds="$3"
  cat >"$doc" <<MD
## Interview Transcript

- Independence level: $level
- Rounds used: $rounds

| ID | Round | Phase | Probe | Answer | Evidence | Verdict (verbatim) |
|---|---|---|---|---|---|---|
MD
}

# Couples the warrant conditions to the prose that owns them. Scoped to the
# warrant section: `W1` through `W4` are short tokens that a file-wide check
# would find elsewhere, and the coupling must break when the operative clause
# moves or weakens.
assert_warrant_anchors() {
  local dir="$1" section anchor
  section="$(extract_section "$dir/skills/retrospective/SKILL.md" "## Warrant for not-probed")"
  if [[ -z "$section" ]]; then
    echo "  assertion failed (warrant anchors): warrant section not found"
    return 1
  fi
  for anchor in W1 W2 W3 W4; do
    if [[ "$section" != *"$anchor"* ]]; then
      echo "  assertion failed (warrant anchors): warrant section missing anchor: $anchor"
      return 1
    fi
  done
  return 0
}

# Couples `cond_W1`'s section literal to the template that owns the heading
# (schemas/retro-template.md line 25). W1's fixtures and W1's extract call share
# one literal, so they agree with each other whatever that literal says; only
# this assertion can catch the two drifting away from the real template.
assert_measured_heading_anchor() {
  local dir="$1"
  if ! grep -qxF '## Success criteria: measured vs declared' "$dir/schemas/retro-template.md"; then
    echo "  assertion failed (measured heading anchor): template lacks the heading cond_W1 extracts"
    return 1
  fi
  return 0
}

# A full retro fixture: the measured-criteria table under the heading
# schemas/retro-template.md line 25 carries, carry-forward section with the
# reconciliation bullet, Findings buckets, and the Interview Transcript.
# Defaults satisfy all four warrant conditions; each case perturbs one field,
# which is what makes a rejection attributable to the condition it names.
#   --no-measured    omit the measured-criteria section entirely
#   --no-spec        replace the measured table with the template's no-spec
#                    parenthetical (schemas/retro-template.md line 37)
#   --stray-no-spec  append the no-spec statement OUTSIDE the measured section
#   --no-findings    omit the Findings section entirely
write_fixture_retro_full() {
  local doc="$1"; shift
  local level="not-probed (no narrative warranted)"
  local rounds="1 (one facilitator dispatch confirmed the judgment)"
  local measured="Met"
  local recon="registered 1, accounted for 1"
  local row_verdict="accepted"
  local extra_finding=0
  local no_measured=0 no_spec=0 stray_no_spec=0 no_findings=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --level) level="$2"; shift 2 ;;
      --rounds) rounds="$2"; shift 2 ;;
      --measured) measured="$2"; shift 2 ;;
      --recon) recon="$2"; shift 2 ;;
      --rows) row_verdict="$2"; shift 2 ;;
      --extra-finding) extra_finding=1; shift ;;
      --no-measured) no_measured=1; shift ;;
      --no-spec) no_spec=1; shift ;;
      --stray-no-spec) stray_no_spec=1; shift ;;
      --no-findings) no_findings=1; shift ;;
      *) echo "  harness error: unknown fixture option: $1" >&2; return 1 ;;
    esac
  done
  {
    if [[ $no_measured -eq 0 ]]; then
      cat <<MD
## Success criteria: measured vs declared

MD
      if [[ $no_spec -eq 1 ]]; then
        cat <<MD
(If no spec exists, state that explicitly and skip this section — do not reconstruct criteria after the fact.)

MD
      else
        cat <<MD
| # | Declared criterion | Measurement (command / rubric) | Measured result | Verdict |
|---|---|---|---|---|
| 1 | the warrant gates the fifth level | scripts/test-retro-format-drift.sh | verified: seven cases | $measured |

MD
      fi
    fi
    cat <<MD
## Carry-forward from previous retro

| Item | Status | Evidence |
|---|---|---|
| previous item | Done | commit abc1234 |

- Reconciliation: $recon
MD
    if [[ $no_findings -eq 0 ]]; then
      cat <<MD

## Findings

### What worked well
- **What happened**: the warrant gated the fifth level
  **Cites**: T1
MD
      if [[ $extra_finding -eq 1 ]]; then
        cat <<MD

### Process observations
- **What happened**: the checker grew four conditions
  **Cites**: T1
MD
      fi
    fi
    cat <<MD

## Interview Transcript

- Independence level: $level
- Rounds used: $rounds

| ID | Round | Phase | Probe | Answer | Evidence | Verdict (verbatim) |
|---|---|---|---|---|---|---|
MD
    if [[ "$row_verdict" != "none" ]]; then
      printf '| T1 | 1 | 5 | probe | answer | commit abc1234 | %s |\n' "$row_verdict"
    fi
    if [[ $stray_no_spec -eq 1 ]]; then
      printf '\n(An interview answer said no spec exists for the tooling.)\n'
    fi
  } >"$doc"
}

# Couples `cond_phase4_unregistered` to the prose that owns the rule. Scoped to
# the Phase 4 section: `registered` and `accounted for` also occur in the
# warrant section, so a file-wide check would stay green after the Phase 4
# clause moved or weakened.
assert_phase4_anchors() {
  local dir="$1" section anchor
  section="$(extract_section "$dir/skills/retrospective/SKILL.md" "## Phase 4: Carry-Forward Reconciliation")"
  if [[ -z "$section" ]]; then
    echo "  assertion failed (phase 4 anchors): Phase 4 section not found"
    return 1
  fi
  for anchor in "row by row, by name" "registered" "accounted for"; do
    if [[ "$section" != *"$anchor"* ]]; then
      echo "  assertion failed (phase 4 anchors): Phase 4 section missing anchor: $anchor"
      return 1
    fi
  done
  return 0
}

# The previous retro document: a registration table only, one row per name.
write_fixture_prev_retro() {
  local doc="$1"; shift
  {
    cat <<MD
## Carry-forward items registered

| Item | Type | Priority | Tracked at |
|---|---|---|---|
MD
    local item
    for item in "$@"; do
      printf '| %s | process | P2 | ROADMAP.md |\n' "$item"
    done
  } >"$doc"
}

# The current retro document, at a probed level so that only
# `phase4-unregistered` can speak: one carry-forward row per name, plus the
# reconciliation bullet.
write_fixture_current_retro() {
  local doc="$1" recon="$2"; shift 2
  {
    cat <<MD
## Carry-forward from previous retro

| Item | Status | Evidence |
|---|---|---|
MD
    local item
    for item in "$@"; do
      printf '| %s | Done | commit abc1234 |\n' "$item"
    done
    cat <<MD

- Reconciliation: $recon

## Interview Transcript

- Independence level: heterogeneous
- Rounds used: 1 (one facilitator dispatch)

| ID | Round | Phase | Probe | Answer | Evidence | Verdict (verbatim) |
|---|---|---|---|---|---|---|
| T1 | 1 | 4 | probe | answer | commit abc1234 | accepted |
MD
  } >"$doc"
}

assert_condition_name() {
  local actual="$1" expected="$2"
  if [[ "$actual" == "$expected" ]]; then
    return 0
  fi
  echo "  assertion failed (condition name): expected $expected, got: $actual"
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

# --- Case C5: degraded level justified by `mode:headless` ---
# The rounds-used line cites the flag instead of an absent capability. The
# checker must reject with `phase8-headless`.
case_c5() {
  local dir out code result=0
  dir="$(setup_copy)" || return 1
  TEMP_DIRS+=("$dir")
  write_fixture_retro "$dir/fixture-retro.md" "self-checklist" \
    "0 (mode:headless, so no facilitator was dispatched)"
  out="$(check_retro_doc "$dir/fixture-retro.md")"; code=$?
  [[ $code -eq 1 ]] || { echo "  expected exit 1, got $code"; result=1; }
  assert_condition_name "$out" "phase8-headless" || result=1
  assert_phase8_anchors "$dir" || result=1
  rm -rf "$dir"
  return $result
}

# --- Case C6: degraded level naming both absent facilitator channels ---
# The canonical accepted justification. The checker must accept.
case_c6() {
  local dir out code result=0
  dir="$(setup_copy)" || return 1
  TEMP_DIRS+=("$dir")
  write_fixture_retro "$dir/fixture-retro.md" "self-checklist" \
    "0 (no subagent primitive and no external facilitator CLI reachable in this harness)"
  out="$(check_retro_doc "$dir/fixture-retro.md")"; code=$?
  [[ $code -eq 0 ]] || { echo "  expected exit 0, got $code (condition: ${out:-none})"; result=1; }
  assert_phase8_anchors "$dir" || result=1
  rm -rf "$dir"
  return $result
}

# --- Case C7: degraded level naming only one absent channel ---
# Discrimination case: rung 1 of the dispatch ladder names an external CLI
# facilitator that does not depend on the subagent primitive, so an absent
# subagent primitive alone does not warrant `self-checklist`. The checker must
# reject with `phase8-capability`.
case_c7() {
  local dir out code result=0
  dir="$(setup_copy)" || return 1
  TEMP_DIRS+=("$dir")
  write_fixture_retro "$dir/fixture-retro.md" "self-checklist" \
    "0 (no subagent primitive in this harness)"
  out="$(check_retro_doc "$dir/fixture-retro.md")"; code=$?
  [[ $code -eq 1 ]] || { echo "  expected exit 1, got $code"; result=1; }
  assert_condition_name "$out" "phase8-capability" || result=1
  assert_phase8_anchors "$dir" || result=1
  rm -rf "$dir"
  return $result
}

# --- Case C8: not-probed on the dispatch path ---
# One confirmation row with verdict `accepted`, no degraded Phase 3 verdict, an
# agreeing reconciliation, and no finding outside What Worked Well. The
# checker must accept.
case_c8() {
  local dir out code result=0
  dir="$(setup_copy)" || return 1
  TEMP_DIRS+=("$dir")
  write_fixture_retro_full "$dir/fixture-retro.md" || { rm -rf "$dir"; return 1; }
  out="$(check_retro_doc "$dir/fixture-retro.md")"; code=$?
  [[ $code -eq 0 ]] || { echo "  expected exit 0, got $code (condition: ${out:-none})"; result=1; }
  assert_warrant_anchors "$dir" || result=1
  rm -rf "$dir"
  return $result
}

# --- Case C9: not-probed claimed over a `Not met` criterion ---
# A criterion the cycle did not meet is narrative material by definition. The
# checker must reject with `W1`.
case_c9() {
  local dir out code result=0
  dir="$(setup_copy)" || return 1
  TEMP_DIRS+=("$dir")
  write_fixture_retro_full "$dir/fixture-retro.md" \
    --measured "Not met — the checker never rejected a bare claim" || { rm -rf "$dir"; return 1; }
  out="$(check_retro_doc "$dir/fixture-retro.md")"; code=$?
  [[ $code -eq 1 ]] || { echo "  expected exit 1, got $code"; result=1; }
  assert_condition_name "$out" "W1" || result=1
  assert_warrant_anchors "$dir" || result=1
  assert_measured_heading_anchor "$dir" || result=1
  rm -rf "$dir"
  return $result
}

# --- Case C10: not-probed claimed over an unreconciled carry-forward ---
# Four items registered, three accounted for: the missing item is exactly what
# a probe would surface. The checker must reject with `W2`.
case_c10() {
  local dir out code result=0
  dir="$(setup_copy)" || return 1
  TEMP_DIRS+=("$dir")
  write_fixture_retro_full "$dir/fixture-retro.md" \
    --recon "registered 4, accounted for 3" || { rm -rf "$dir"; return 1; }
  out="$(check_retro_doc "$dir/fixture-retro.md")"; code=$?
  [[ $code -eq 1 ]] || { echo "  expected exit 1, got $code"; result=1; }
  assert_condition_name "$out" "W2" || result=1
  assert_warrant_anchors "$dir" || result=1
  rm -rf "$dir"
  return $result
}

# --- Case C12: not-probed with no dispatch and no capability claim ---
# The load-bearing case. Zero transcript rows and a rounds-used line carrying
# neither capability anchor is the incentive shape the fifth value risks
# creating: nothing to probe, asserted by the party who benefits from
# asserting it. The checker must reject with `W4`.
case_c12() {
  local dir out code result=0
  dir="$(setup_copy)" || return 1
  TEMP_DIRS+=("$dir")
  write_fixture_retro_full "$dir/fixture-retro.md" \
    --rows none --rounds "0 (nothing warranted probing)" || { rm -rf "$dir"; return 1; }
  out="$(check_retro_doc "$dir/fixture-retro.md")"; code=$?
  [[ $code -eq 1 ]] || { echo "  expected exit 1, got $code"; result=1; }
  assert_condition_name "$out" "W4" || result=1
  assert_warrant_anchors "$dir" || result=1
  rm -rf "$dir"
  return $result
}

# --- Case C13: not-probed on the no-channel path ---
# Zero transcript rows, but the rounds-used line carries both capability
# anchors — the same absent-capability claim `self-checklist` carries. The
# checker must accept.
case_c13() {
  local dir out code result=0
  dir="$(setup_copy)" || return 1
  TEMP_DIRS+=("$dir")
  write_fixture_retro_full "$dir/fixture-retro.md" --rows none \
    --rounds "0 (no subagent primitive and no external facilitator CLI reachable in this harness)" \
    || { rm -rf "$dir"; return 1; }
  out="$(check_retro_doc "$dir/fixture-retro.md")"; code=$?
  [[ $code -eq 0 ]] || { echo "  expected exit 0, got $code (condition: ${out:-none})"; result=1; }
  assert_warrant_anchors "$dir" || result=1
  rm -rf "$dir"
  return $result
}

# --- Case C14: not-probed confirmed by a self-attested row ---
# Discrimination case: a row exists, so the zero-row path never applies, but
# the row is the claimant's own verdict. The checker must reject with `W4`.
case_c14() {
  local dir out code result=0
  dir="$(setup_copy)" || return 1
  TEMP_DIRS+=("$dir")
  write_fixture_retro_full "$dir/fixture-retro.md" \
    --rows "self-attested" || { rm -rf "$dir"; return 1; }
  out="$(check_retro_doc "$dir/fixture-retro.md")"; code=$?
  [[ $code -eq 1 ]] || { echo "  expected exit 1, got $code"; result=1; }
  assert_condition_name "$out" "W4" || result=1
  assert_warrant_anchors "$dir" || result=1
  rm -rf "$dir"
  return $result
}

# --- Case C15: not-probed claimed alongside a Process Observations finding ---
# A finding outside What Worked Well is a narrative the retro already wrote.
# The checker must reject with `W3`.
case_c15() {
  local dir out code result=0
  dir="$(setup_copy)" || return 1
  TEMP_DIRS+=("$dir")
  write_fixture_retro_full "$dir/fixture-retro.md" \
    --extra-finding || { rm -rf "$dir"; return 1; }
  out="$(check_retro_doc "$dir/fixture-retro.md")"; code=$?
  [[ $code -eq 1 ]] || { echo "  expected exit 1, got $code"; result=1; }
  assert_condition_name "$out" "W3" || result=1
  assert_warrant_anchors "$dir" || result=1
  rm -rf "$dir"
  return $result
}

# --- Case C16: not-probed with the measured-criteria section absent ---
# Deleting the section is the cheapest way to hold no `Partially met` or
# `Not met` cell. An absent field fails the condition it belongs to, so the
# checker must reject with `W1` rather than pass vacuously.
case_c16() {
  local dir out code result=0
  dir="$(setup_copy)" || return 1
  TEMP_DIRS+=("$dir")
  write_fixture_retro_full "$dir/fixture-retro.md" \
    --no-measured || { rm -rf "$dir"; return 1; }
  out="$(check_retro_doc "$dir/fixture-retro.md")"; code=$?
  [[ $code -eq 1 ]] || { echo "  expected exit 1, got $code"; result=1; }
  assert_condition_name "$out" "W1" || result=1
  assert_warrant_anchors "$dir" || result=1
  assert_measured_heading_anchor "$dir" || result=1
  rm -rf "$dir"
  return $result
}

# --- Case C17: not-probed with the Findings section absent ---
# Same vacuity on the other side: a document that records no finding has not
# shown it has no narrative. The checker must reject with `W3`.
case_c17() {
  local dir out code result=0
  dir="$(setup_copy)" || return 1
  TEMP_DIRS+=("$dir")
  write_fixture_retro_full "$dir/fixture-retro.md" \
    --no-findings || { rm -rf "$dir"; return 1; }
  out="$(check_retro_doc "$dir/fixture-retro.md")"; code=$?
  [[ $code -eq 1 ]] || { echo "  expected exit 1, got $code"; result=1; }
  assert_condition_name "$out" "W3" || result=1
  assert_warrant_anchors "$dir" || result=1
  rm -rf "$dir"
  return $result
}

# --- Case C18: `Not met` cell plus a stray no-spec sentence ---
# The no-spec escape hatch belongs to the measured-criteria section. This
# fixture is C9 with the sentence appended after the transcript, where it
# cannot speak for the criteria table. The checker must still reject with `W1`.
case_c18() {
  local dir out code result=0
  dir="$(setup_copy)" || return 1
  TEMP_DIRS+=("$dir")
  write_fixture_retro_full "$dir/fixture-retro.md" \
    --measured "Not met — the checker never rejected a bare claim" \
    --stray-no-spec || { rm -rf "$dir"; return 1; }
  out="$(check_retro_doc "$dir/fixture-retro.md")"; code=$?
  [[ $code -eq 1 ]] || { echo "  expected exit 1, got $code"; result=1; }
  assert_condition_name "$out" "W1" || result=1
  assert_warrant_anchors "$dir" || result=1
  assert_measured_heading_anchor "$dir" || result=1
  rm -rf "$dir"
  return $result
}

# --- Case C19: no-spec statement inside the measured-criteria section ---
# The escape hatch itself, in the template's own parenthetical form
# (schemas/retro-template.md line 37): the section exists and carries no table.
# Discrimination case against C16 and C18 — scoping the check must not kill it.
case_c19() {
  local dir out code result=0
  dir="$(setup_copy)" || return 1
  TEMP_DIRS+=("$dir")
  write_fixture_retro_full "$dir/fixture-retro.md" \
    --no-spec || { rm -rf "$dir"; return 1; }
  out="$(check_retro_doc "$dir/fixture-retro.md")"; code=$?
  [[ $code -eq 0 ]] || { echo "  expected exit 0, got $code (condition: ${out:-none})"; result=1; }
  assert_warrant_anchors "$dir" || result=1
  assert_measured_heading_anchor "$dir" || result=1
  rm -rf "$dir"
  return $result
}

# --- Case C11: a carry-forward row the previous retro never registered ---
# The previous document registers four items and the current table holds four
# rows, so every count agrees. One registered name has been replaced by an
# unregistered one, which a count-only reconciliation cannot see. The checker
# must reject with `phase4-unregistered`.
case_c11() {
  local dir out code result=0
  dir="$(setup_copy)" || return 1
  TEMP_DIRS+=("$dir")
  write_fixture_prev_retro "$dir/fixture-prev-retro.md" \
    "checker grammar" "dispatch cap" "template drift" "warrant wording"
  write_fixture_current_retro "$dir/fixture-retro.md" "registered 4, accounted for 4" \
    "checker grammar" "dispatch cap" "template drift" "report formatting"
  out="$(check_retro_doc "$dir/fixture-retro.md" "$dir/fixture-prev-retro.md")"; code=$?
  [[ $code -eq 1 ]] || { echo "  expected exit 1, got $code"; result=1; }
  assert_condition_name "$out" "phase4-unregistered" || result=1
  assert_phase4_anchors "$dir" || result=1
  rm -rf "$dir"
  return $result
}

# --- Case C20: every current row reproduces a registered name ---
# The accepting counterpart of C11, with the same four registered items and no
# substitution. Discrimination case: the by-name comparison must not reject a
# reconciliation that is correct.
case_c20() {
  local dir out code result=0
  dir="$(setup_copy)" || return 1
  TEMP_DIRS+=("$dir")
  write_fixture_prev_retro "$dir/fixture-prev-retro.md" \
    "checker grammar" "dispatch cap" "template drift" "warrant wording"
  write_fixture_current_retro "$dir/fixture-retro.md" "registered 4, accounted for 4" \
    "Checker Grammar" "dispatch cap " " template drift" "warrant wording"
  out="$(check_retro_doc "$dir/fixture-retro.md" "$dir/fixture-prev-retro.md")"; code=$?
  [[ $code -eq 0 ]] || { echo "  expected exit 0, got $code (condition: ${out:-none})"; result=1; }
  rm -rf "$dir"
  return $result
}

# --- Case C21: the degraded reconciliation bullet under not-probed ---
# The template's degraded form records `registered 0, accounted for 0` with the
# suffix naming the missing registration table. An absent measurement is not a
# clean one, so the checker must reject with `W2`.
case_c21() {
  local dir out code result=0
  dir="$(setup_copy)" || return 1
  TEMP_DIRS+=("$dir")
  write_fixture_retro_full "$dir/fixture-retro.md" \
    --recon "registered 0, accounted for 0 — degraded: previous retro has no registration table" \
    || { rm -rf "$dir"; return 1; }
  out="$(check_retro_doc "$dir/fixture-retro.md")"; code=$?
  [[ $code -eq 1 ]] || { echo "  expected exit 1, got $code"; result=1; }
  assert_condition_name "$out" "W2" || result=1
  assert_warrant_anchors "$dir" || result=1
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
run_case C5 case_c5
run_case C6 case_c6
run_case C7 case_c7
run_case C8 case_c8
run_case C9 case_c9
run_case C10 case_c10
run_case C11 case_c11
run_case C12 case_c12
run_case C13 case_c13
run_case C14 case_c14
run_case C15 case_c15
run_case C16 case_c16
run_case C17 case_c17
run_case C18 case_c18
run_case C19 case_c19
run_case C20 case_c20
run_case C21 case_c21

echo
if [[ $FAIL_COUNT -eq 0 ]]; then
  echo "ALL CASES PASSED"
  exit 0
else
  echo "$FAIL_COUNT case(s) FAILED"
  exit 1
fi
