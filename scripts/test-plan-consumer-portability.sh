#!/usr/bin/env bash
# Standalone contract harness for implementing, release-loop, and retrospective.
# The fixture copies the real skill files, deliberately omits skills/planning/, and
# then adds the sibling schema only for shared-literal parity checks.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL_COUNT=0
PASS_COUNT=0

pass() {
  echo "  PASS: $1"
  PASS_COUNT=$((PASS_COUNT + 1))
}

fail() {
  echo "  FAIL: $1"
  FAIL_COUNT=$((FAIL_COUNT + 1))
}


assert_absent() {
  local label="$1" file="$2" needle="$3"
  if grep -Fq -- "$needle" "$file"; then
    fail "$label — found forbidden '$needle'"
  else
    pass "$label"
  fi
}

copy_consumers() {
  local d
  d="$(mktemp -d)" || return 1
  mkdir -p "$d/skills/implementing" "$d/skills/release-loop" "$d/skills/retrospective"
  cp "$ROOT/skills/implementing/SKILL.md" "$d/skills/implementing/SKILL.md"
  cp "$ROOT/skills/release-loop/SKILL.md" "$d/skills/release-loop/SKILL.md"
  cp "$ROOT/skills/retrospective/SKILL.md" "$d/skills/retrospective/SKILL.md"
  printf '%s\n' "$d"
}

# Each row is independently asserted and independently mutated below. Keep each
# needle on one prose line so the deletion test cannot accidentally remove another
# branch's evidence.
IMPLEMENTING_BRANCHES=(
  'schema/accepted|The only accepted plan schema is `plan/v1`; a missing or unknown `schema` rejects before execution.'
  'status/approved|A plan with `status: approved` proceeds to contradiction scanning and unit dispatch.'
  'status/draft|A plan with `status: draft` rejects with a pending-approval diagnostic.'
  'status/done|A plan with `status: done` rejects and names its recorded `completed_by` commit.'
  'status/done-missing-evidence|A `done` plan missing `completed_by` rejects as a terminal-state validator violation; never invent a commit.'
  'status/superseded|A plan with `status: superseded` rejects and names its `superseded_by` successor path.'
  'status/missing-unknown|A missing or unknown `status` rejects before any unit is executed.'
  'seal/correct|A correctly formatted and matching `body_seal` proceeds after stored-versus-computed comparison.'
  'seal/malformed-mismatch|A malformed or mismatched `body_seal` rejects and reports both stored and computed values.'
  'seal/never-sealed|An approved plan that was never sealed remains valid when its approval history contains no `body_seal`.'
  'seal/removed|An approved plan whose approval history contained a seal but whose current frontmatter removed it rejects as a removed-seal violation.'
  'seal/reseal|Every post-approval re-seal requires interactive deepening; U4 adoption migration is not an exception in this consumer.'
  'units/full-handoff|Each dispatched unit consumes its full handoff: exact values and signatures, `Files`, `Interfaces`, `Test scenarios`, and `Execution note`.'
  'execution/code|`execution: code` selects the existing code-unit flow.'
  'execution/non-code|`execution: non-code` selects the existing non-code-unit flow.'
)

RELEASE_BRANCHES=(
  'required/schema|`--skip-plan` rejects a missing required `schema` field by naming `schema`.'
  'required/title|`--skip-plan` rejects a missing required `title` field by naming `title`.'
  'required/type|`--skip-plan` rejects a missing required `type` field by naming `type`.'
  'required/status|`--skip-plan` rejects a missing required `status` field by naming `status`.'
  'required/date|`--skip-plan` rejects a missing required `date` field by naming `date`.'
  'required/execution|`--skip-plan` rejects a missing required `execution` field by naming `execution`.'
  'eligibility/schema-status|`--skip-plan` proceeds only for `schema: plan/v1` with `status: approved`.'
  'eligibility/unknown-schema|`--skip-plan` rejects an unknown schema version.'
  'eligibility/non-approved|`--skip-plan` rejects every non-approved status.'
  'validator/available|When the sibling planning validator is available, `--skip-plan` runs it and requires exit 0.'
  'validator/fallback|When the sibling planning validator is absent, `--skip-plan` uses the local minimum-field fallback and still rejects unknown schema versions.'
)

RETROSPECTIVE_BRANCHES=(
  'origin/repo-relative|`origin` is resolved as a repo-relative spec path, while the existing no-plan fallback applies when no plan exists.'
  'transition/approved-post-contract|Only a post-contract plan with `status: approved` may transition to `status: done`.'
  'transition/frontmatter-only|The terminal transition mutates only frontmatter `status` and `completed_by`.'
  'transition/landed-commit|`completed_by` must name the landed base-branch commit; a missing landed commit rejects.'
  'transition/pre-contract|A pre-contract plan is never retroactively flipped, even when a retro covers it.'
  'transition/non-approved|A non-approved plan does not flip to `done`.'
  'transition/multi-plan|When a retro covers multiple plans, apply the same applicability and approved-status rule to every plan.'
  'transition/body-immutable|Retrospective never changes the plan body.'
  'transition/frontmatter-immutable|Retrospective rejects any frontmatter mutation other than `status` and `completed_by`.'
)

check_contract() {
  local consumer="$1" file="$2" branch needle
  local ok=0
  while IFS='|' read -r branch needle; do
    [ -z "$branch" ] && continue
    if ! grep -Fq -- "$needle" "$file"; then
      echo "MISSING consumer=$consumer branch=$branch expected=$needle"
      ok=1
    fi
  done < <(case "$consumer" in
    implementing) printf '%s\n' "${IMPLEMENTING_BRANCHES[@]}" ;;
    release-loop) printf '%s\n' "${RELEASE_BRANCHES[@]}" ;;
    retrospective) printf '%s\n' "${RETROSPECTIVE_BRANCHES[@]}" ;;
  esac)
  return "$ok"
}

mutate_delete_needle() {
  local file="$1" needle="$2"
  python3 - "$file" "$needle" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
needle = sys.argv[2]
lines = path.read_text(encoding="utf-8").splitlines(keepends=True)
remaining = [line for line in lines if needle not in line]
if len(remaining) == len(lines):
    raise SystemExit(2)
path.write_text("".join(remaining), encoding="utf-8")
PY
}

run_deletion_mutations() {
  local consumer="$1" source="$2" branch needle d out
  while IFS='|' read -r branch needle; do
    [ -z "$branch" ] && continue
    d="$(mktemp -d)"
    cp "$source" "$d/SKILL.md"
    mutate_delete_needle "$d/SKILL.md" "$needle"
    out="$(check_contract "$consumer" "$d/SKILL.md" 2>&1)"
    if [ "$?" -ne 0 ] && printf '%s\n' "$out" | grep -Fq "MISSING consumer=$consumer branch=$branch"; then
      pass "$consumer deletion mutation → branch=$branch diagnostic"
    else
      fail "$consumer deletion mutation → branch=$branch diagnostic"
      printf '    mutation output: %s\n' "$out"
    fi
    rm -rf "$d"
  done < <(case "$consumer" in
    implementing) printf '%s\n' "${IMPLEMENTING_BRANCHES[@]}" ;;
    release-loop) printf '%s\n' "${RELEASE_BRANCHES[@]}" ;;
    retrospective) printf '%s\n' "${RETROSPECTIVE_BRANCHES[@]}" ;;
  esac)
}

schema_path_for() {
  local fixture="$1"
  if [ -f "$fixture/skills/planning/schemas/plan-schema.md" ]; then
    printf '%s\n' "$fixture/skills/planning/schemas/plan-schema.md"
  elif [ -f "$fixture/schemas/plan-schema.md" ]; then
    printf '%s\n' "$fixture/schemas/plan-schema.md"
  else
    return 1
  fi
}

schema_literal() {
  local schema="$1" kind="$2"
  python3 - "$schema" "$kind" <<'PY'
from pathlib import Path
import re
import sys

text = Path(sys.argv[1]).read_text(encoding="utf-8")
kind = sys.argv[2]
patterns = {
    "required": r"^([a-z_]+): .+$",
    "schema": r"^schema:\s+(plan/v1)\s+#",
    "status": r"^status:\s+([^#]+?)\s+#",
    "execution": r"^execution:\s+([^#]+?)\s+#",
    "seal-format": r"^body_seal:\s+<([^>]+)>\s+#",
    "extraction": r"text\.split\('---', 2\)\[2\]",
}
if kind == "required":
    in_frontmatter = False
    optional = {"origin", "deepened", "body_seal", "completed_by", "superseded_by"}
    values = []
    for line in text.splitlines():
        if line.strip() == "```yaml":
            in_frontmatter = True
            continue
        if in_frontmatter and line.strip() == "```":
            break
        if in_frontmatter:
            match = re.match(patterns[kind], line)
            if match and match.group(1) not in optional:
                values.append(match.group(1))
    print("|".join(values))
    raise SystemExit(0)
if kind == "extraction":
    match = re.search(patterns[kind], text)
    if not match:
        raise SystemExit(1)
    print(match.group(0))
    raise SystemExit(0)
match = re.search(patterns[kind], text, re.MULTILINE)
if not match:
    raise SystemExit(1)
print(match.group(1).strip())
PY
}

shared_check() {
  local fixture="$1" schema consumer file field
  local drift_count=0
  schema="$(schema_path_for "$fixture")" || {
    echo "MISSING shared SSOT in fixture: skills/planning/schemas/plan-schema.md or schemas/plan-schema.md"
    return 1
  }
  local required schema_version statuses execution seal_format extraction
  required="$(schema_literal "$schema" required)"
  schema_version="$(schema_literal "$schema" schema)"
  statuses="$(schema_literal "$schema" status)"
  execution="$(schema_literal "$schema" execution)"
  seal_format="$(schema_literal "$schema" seal-format)"
  extraction="$(schema_literal "$schema" extraction)"
  for consumer in implementing release-loop retrospective; do
    file="$fixture/skills/$consumer/SKILL.md"
    IFS='|' read -r -a required_fields <<< "$required"
    for field in "${required_fields[@]}"; do
      if ! grep -Fq -- "Required frontmatter field: \`$field\`." "$file"; then
        echo "DRIFT consumer=$consumer field=$field expected=required"
        drift_count=$((drift_count + 1))
      else
        PASS_COUNT=$((PASS_COUNT + 1))
      fi
    done
    if ! grep -Fq -- "Schema version literal: \`$schema_version\`." "$file"; then
      echo "DRIFT consumer=$consumer field=schema-version expected=$schema_version"
      drift_count=$((drift_count + 1))
    else
      PASS_COUNT=$((PASS_COUNT + 1))
    fi
    if ! grep -Fq -- "Status literals: \`$statuses\`." "$file"; then
      echo "DRIFT consumer=$consumer field=statuses expected=$statuses"
      drift_count=$((drift_count + 1))
    else
      PASS_COUNT=$((PASS_COUNT + 1))
    fi
    if ! grep -Fq -- "Execution literals: \`$execution\`." "$file"; then
      echo "DRIFT consumer=$consumer field=execution expected=$execution"
      drift_count=$((drift_count + 1))
    else
      PASS_COUNT=$((PASS_COUNT + 1))
    fi
    if ! grep -Fq -- "Seal format literal: \`$seal_format\`." "$file"; then
      echo "DRIFT consumer=$consumer field=seal-format expected=$seal_format"
      drift_count=$((drift_count + 1))
    else
      PASS_COUNT=$((PASS_COUNT + 1))
    fi
    if ! grep -Fq -- "Seal extraction literal: \`$extraction\`." "$file"; then
      echo "DRIFT consumer=$consumer field=seal-extraction expected=$extraction"
      drift_count=$((drift_count + 1))
    else
      PASS_COUNT=$((PASS_COUNT + 1))
    fi
  done
  if [ "$drift_count" -ne 0 ]; then
    return 1
  fi
  return 0
}


# --- Integration fixture: real copied skills, no planning sibling ---
echo "Fixture A: standalone consumers without skills/planning/"
fixture="$(copy_consumers)"
if [ -d "$fixture/skills/planning" ]; then
  fail "standalone fixture omits skills/planning/"
else
  pass "standalone fixture omits skills/planning/"
fi
for consumer in implementing release-loop retrospective; do
  file="$fixture/skills/$consumer/SKILL.md"
  assert_absent "$consumer has no load-bearing root schema reference" "$file" 'schemas/plan-schema.md'
  if check_contract "$consumer" "$file"; then
    pass "$consumer decision matrix is complete"
  else
    fail "$consumer decision matrix is complete (consumer=$consumer)"
  fi
done
run_deletion_mutations implementing "$fixture/skills/implementing/SKILL.md"
run_deletion_mutations release-loop "$fixture/skills/release-loop/SKILL.md"
run_deletion_mutations retrospective "$fixture/skills/retrospective/SKILL.md"
rm -rf "$fixture"

# --- Integration fixture: add sibling SSOT and compare every shared literal ---
echo "Fixture B: sibling SSOT parity with pre-/post-move fallback"
fixture="$(copy_consumers)"
ssot=""
if [ -f "$ROOT/skills/planning/schemas/plan-schema.md" ]; then
  ssot="$ROOT/skills/planning/schemas/plan-schema.md"
elif [ -f "$ROOT/schemas/plan-schema.md" ]; then
  ssot="$ROOT/schemas/plan-schema.md"
fi
if [ -z "$ssot" ]; then
  fail "shared SSOT fallback finds skills/planning/schemas/plan-schema.md or schemas/plan-schema.md"
else
  mkdir -p "$fixture/skills/planning/schemas"
  cp "$ssot" "$fixture/skills/planning/schemas/plan-schema.md"
  if shared_check "$fixture"; then
    pass "shared literals match sibling SSOT at $ssot"
  else
    fail "shared literals match sibling SSOT at $ssot"
  fi
  # Explicitly exercise fallback resolution too: remove the moved sibling and
  # provide the pre-move root path, then compare again.
  rm -rf "$fixture/skills/planning"
  mkdir -p "$fixture/schemas"
  cp "$ssot" "$fixture/schemas/plan-schema.md"
  if shared_check "$fixture"; then
    pass "shared literals match pre-move root SSOT fallback"
  else
    fail "shared literals match pre-move root SSOT fallback"
  fi
  rm -rf "$fixture/skills/planning" "$fixture/schemas"
  mkdir -p "$fixture/skills/planning/schemas"
  cp "$ssot" "$fixture/skills/planning/schemas/plan-schema.md"
  # Drift mutations run against the real copied file and must name the consumer
  # and field rather than merely failing generically.
  for field in schema-version statuses execution seal-format seal-extraction; do
    case "$field" in
      schema-version) old='Schema version literal: `plan/v1`.'; new='Schema version literal: `plan/v999`.' ;;
      statuses) old='Status literals: `draft | approved | done | superseded`.'; new='Status literals: `draft | approved | done | archived`.' ;;
      execution) old='Execution literals: `code | non-code | ops`.'; new='Execution literals: `code | non-code | shell`.' ;;
      seal-format) old='Seal format literal: `64-char lowercase hex SHA-256`.'; new='Seal format literal: `64-char uppercase hex SHA-256`.' ;;
      seal-extraction) old="Seal extraction literal: \`text.split('---', 2)[2]\`."; new="Seal extraction literal: \`text.split('---', 1)[1]\`." ;;
    esac
    cp "$fixture/skills/implementing/SKILL.md" "$fixture/skills/implementing/SKILL.md.orig"
    python3 - "$fixture/skills/implementing/SKILL.md" "$old" "$new" <<'PY'
from pathlib import Path
import sys
path = Path(sys.argv[1])
old, new = sys.argv[2:]
text = path.read_text(encoding="utf-8")
if old not in text:
    raise SystemExit(2)
path.write_text(text.replace(old, new, 1), encoding="utf-8")
PY
    out="$(shared_check "$fixture" 2>&1)"
    if printf '%s\n' "$out" | grep -Fq "DRIFT consumer=implementing field=$field"; then
      pass "shared-literal drift mutation → field=$field diagnostic"
    else
      fail "shared-literal drift mutation → field=$field diagnostic"
      printf '    mutation output: %s\n' "$out"
    fi
    mv "$fixture/skills/implementing/SKILL.md.orig" "$fixture/skills/implementing/SKILL.md"
  done
fi
rm -rf "$fixture"

echo "Summary: $PASS_COUNT passed, $FAIL_COUNT failed"
if [ "$FAIL_COUNT" -ne 0 ]; then
  exit 1
fi
exit 0
