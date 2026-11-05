#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/auto-artifact-contract.XXXXXX")"
trap 'rm -rf "$TMP_ROOT"' EXIT

failures=0

fail() {
  echo "not ok: $1"
  failures=$((failures + 1))
}

pass() {
  echo "ok: $1"
}

require_literal() {
  file="$1"
  literal="$2"
  label="$3"
  if python3 - "$file" "$literal" <<'PY'
import sys
from pathlib import Path
path, literal = sys.argv[1:]
raise SystemExit(0 if literal in Path(path).read_text(encoding="utf-8") else 1)
PY
  then
    pass "$label"
  else
    fail "$label"
  fi
}

require_order() {
  file="$1"
  first="$2"
  second="$3"
  label="$4"
  if python3 - "$file" "$first" "$second" <<'PY'
import sys
from pathlib import Path
text = Path(sys.argv[1]).read_text(encoding="utf-8")
first = text.find(sys.argv[2])
second = text.find(sys.argv[3])
raise SystemExit(0 if first >= 0 and second > first else 1)
PY
  then
    pass "$label"
  else
    fail "$label"
  fi
}

expect_accept() {
  validator="$1"
  mode="$2"
  fixture="$3"
  label="$4"
  if python3 "$validator" --mode "$mode" "$fixture" >/dev/null 2>&1; then
    pass "$label"
  else
    fail "$label"
  fi
}

expect_reject() {
  validator="$1"
  fixture="$2"
  label="$3"
  status=0
  err="$(python3 "$validator" --mode auto "$fixture" 2>&1 >/dev/null)" || status=$?
  if [ "$status" -eq 1 ] && printf '%s\n' "$err" | grep -q '^validate-auto-artifact: ' &&
     ! printf '%s\n' "$err" | grep -q 'Traceback'; then
    pass "$label"
  else
    fail "$label"
  fi
}


DESIGNING="$REPO_ROOT/skills/designing/SKILL.md"
PLANNING="$REPO_ROOT/skills/planning/SKILL.md"
DESIGN_VALIDATOR="$REPO_ROOT/skills/designing/scripts/validate-auto-artifact.py"
PLAN_VALIDATOR="$REPO_ROOT/skills/planning/scripts/validate-auto-artifact.py"
AUTHORITY_SPEC="$REPO_ROOT/docs/specs/2026-09-20-auto-plan-assumption-tradeoffs-coverage-authority-design.md"
require_literal "$DESIGNING" "progress_path" "designing pins release ledger path"
require_literal "$DESIGNING" "flags" "designing reads ledger flags"
require_literal "$DESIGNING" "--auto" "designing selects auto mode by flag"
require_literal "$DESIGNING" "symlinked" "designing rejects symlinked ledger"
require_literal "$DESIGNING" "out-of-root" "designing rejects ledger outside repository"

require_literal "$DESIGNING" "mode: auto" "designing declares auto mode"
require_literal "$DESIGNING" "Assumptions and Preconditions" "designing declares assumptions section"
require_literal "$DESIGNING" "## Trade-offs" "designing declares trade-offs section"
require_literal "$DESIGNING" "validate-auto-artifact.py" "designing invokes standalone validator"
for skill in "$DESIGNING" "$PLANNING"; do
  require_literal "$skill" '`## Non-goals` or `### Out`' "auto contract names accepted non-goals headings"
  require_literal "$skill" '`## Residual Risks`, `## Risks`, or `## Risks and Mitigations`' "auto contract names accepted risk headings"
  require_literal "$skill" "outside code fences" "auto contract states fenced text does not count"
  require_literal "$skill" '`Negative controls:`' "auto contract names the negative-control marker"
done
require_order "$DESIGNING" "## Assumptions and Preconditions" "## Step 9" "designing places assumptions before spec writing"
require_literal "$PLANNING" "mode: auto" "planning declares auto mode"
require_literal "$PLANNING" "Assumptions and Preconditions" "planning declares assumptions section"
require_literal "$PLANNING" "## Trade-offs" "planning declares trade-offs section"
require_literal "$PLANNING" "Assumption Recheck" "planning preserves assumption recheck"
require_literal "$PLANNING" "validate-auto-artifact.py" "planning invokes standalone validator"
require_order "$PLANNING" "## Assumptions and Preconditions" "## 5. File structure" "planning places assumptions before file mapping"
if [ -f "$DESIGN_VALIDATOR" ] && [ -f "$PLAN_VALIDATOR" ]; then
  pass "both standalone validators exist"
else
  fail "both standalone validators exist"
fi

if [ -f "$DESIGN_VALIDATOR" ] && [ -f "$PLAN_VALIDATOR" ] && cmp -s "$DESIGN_VALIDATOR" "$PLAN_VALIDATOR"; then
  pass "standalone validators are byte-identical"
else
  fail "standalone validators are byte-identical"
fi
if [ -f "$AUTHORITY_SPEC" ]; then
  require_literal "$AUTHORITY_SPEC" "assert flag_values == ['[--auto]']" \
    "coverage measurement asserts auto ledger flag"
  require_literal "$AUTHORITY_SPEC" "assert set(fields) == {'spec', 'plan'}" \
    "coverage measurement uses ledger spec and plan paths"
else
  pass "coverage authority fixture absent outside release run"
fi

cat >"$TMP_ROOT/auto-spec.md" <<'EOF'
---
schema: spec/v1
mode: auto
---
# Fixture
## Assumptions and Preconditions
| Claim | Command | Observed at | Observed result | Evidence source |
|---|---|---|---|---|
| Source is readable | `printf ok` | 2026-09-19T00:00:00Z | `ok` | fixture |
## Trade-offs
| Option | Metric it improves | Metric it degrades | Measured cost |
|---|---|---|---|
| Selected: structured | detection | prose size | `0` |
| Rejected: prose-only | patch size | detection | `1 control` |
## Non-goals
Historical interactive artifacts do not migrate.
## Residual Risks
Authors may still write vague evidence.
## Architecture
The selected fixture option is structured.
## Success Criteria
Measured by: `bash scripts/test-auto-artifact-contract.sh`.
Negative controls: mutated fixtures must be rejected.
The validator rejects malformed fixtures.
EOF

cat >"$TMP_ROOT/auto-plan.md" <<'EOF'
---
schema: plan/v1
mode: auto
---
# Fixture
## Assumptions and Preconditions
| Claim | Command | Observed at | Observed result | Evidence source |
|---|---|---|---|---|
| Source is readable | `printf ok` | 2026-09-19T00:00:00Z | `ok` | fixture |
## Trade-offs
| Option | Metric it improves | Metric it degrades | Measured cost |
|---|---|---|---|
| Selected: structured | detection | prose size | `0` |
| Rejected: prose-only | patch size | detection | `1 control` |
## Non-goals
Historical interactive artifacts do not migrate.
## Residual Risks
Authors may still write vague evidence.
## Assumption Recheck
The fixture command and timestamp remain current.
## Architecture notes
The selected fixture option is structured.
## Success Criteria
Measured by: `bash scripts/test-auto-artifact-contract.sh`.
Negative controls: mutated fixtures must be rejected.
## Implementation Units
The validator is a fixture dependency.

EOF
cat >"$TMP_ROOT/historical-spec.md" <<'EOF'
---
schema: spec/v1
---
# Historical fixture
## Architecture
Existing interactive content remains valid.
EOF

expect_accept "$DESIGN_VALIDATOR" auto "$TMP_ROOT/auto-spec.md" "compliant auto spec passes"
expect_accept "$PLAN_VALIDATOR" auto "$TMP_ROOT/auto-plan.md" "compliant auto plan passes"
expect_accept "$DESIGN_VALIDATOR" interactive "$TMP_ROOT/historical-spec.md" "historical no-mode spec passes outside auto"
expect_accept "$PLAN_VALIDATOR" interactive "$TMP_ROOT/historical-spec.md" "historical no-mode plan passes outside auto"

mutate() {
  source="$1"
  target="$2"
  old="$3"
  new="$4"
  python3 - "$source" "$target" "$old" "$new" <<'PY'
import sys
from pathlib import Path
source, target, old, new = sys.argv[1:]
text = Path(source).read_text(encoding="utf-8")
if old not in text:
    raise SystemExit(f"mutation target missing: {old}")
Path(target).write_text(text.replace(old, new, 1), encoding="utf-8")
PY
}

assert_command_accept() {
  command="$1"
  mutate "$TMP_ROOT/auto-spec.md" "$TMP_ROOT/arbitrary-command.md" \
    "bash scripts/test-auto-artifact-contract.sh" "$command"
  expect_accept "$DESIGN_VALIDATOR" auto "$TMP_ROOT/arbitrary-command.md" \
    "success criterion accepts $command"
}

mutate "$TMP_ROOT/auto-spec.md" "$TMP_ROOT/missing-mode.md" "mode: auto" ""
expect_reject "$DESIGN_VALIDATOR" "$TMP_ROOT/missing-mode.md" "missing mode is rejected"
mutate "$TMP_ROOT/auto-spec.md" "$TMP_ROOT/missing-assumptions.md" "## Assumptions and Preconditions" "## Preconditions"
expect_reject "$DESIGN_VALIDATOR" "$TMP_ROOT/missing-assumptions.md" "missing assumptions section is rejected"
mutate "$TMP_ROOT/auto-spec.md" "$TMP_ROOT/prose-command.md" "\`printf ok\`" "source is readable"
expect_reject "$DESIGN_VALIDATOR" "$TMP_ROOT/prose-command.md" "prose assumption command is rejected"
mutate "$TMP_ROOT/auto-spec.md" "$TMP_ROOT/bad-timestamp.md" "2026-09-19T00:00:00Z" "yesterday"
expect_reject "$DESIGN_VALIDATOR" "$TMP_ROOT/bad-timestamp.md" "non-timestamp assumption evidence is rejected"
mutate "$TMP_ROOT/auto-plan.md" "$TMP_ROOT/missing-recheck.md" "## Assumption Recheck" "## Recheck"
expect_reject "$PLAN_VALIDATOR" "$TMP_ROOT/missing-recheck.md" "missing plan assumption recheck is rejected"
mutate "$TMP_ROOT/auto-spec.md" "$TMP_ROOT/blank-assumption.md" "| Source is readable |" "|  |"
expect_reject "$DESIGN_VALIDATOR" "$TMP_ROOT/blank-assumption.md" "blank assumption cell is rejected"
mutate "$TMP_ROOT/auto-spec.md" "$TMP_ROOT/blank-tradeoff.md" "| Selected: structured |" "|  |"
expect_reject "$DESIGN_VALIDATOR" "$TMP_ROOT/blank-tradeoff.md" "blank trade-off cell is rejected"
mutate "$TMP_ROOT/auto-spec.md" "$TMP_ROOT/missing-status.md" "| Rejected: prose-only |" "| Alternative: prose-only |"
expect_reject "$DESIGN_VALIDATOR" "$TMP_ROOT/missing-status.md" "missing rejected status is rejected"
mutate "$TMP_ROOT/auto-spec.md" "$TMP_ROOT/missing-cost.md" "| \`0\` |" "| zero |"
expect_reject "$DESIGN_VALIDATOR" "$TMP_ROOT/missing-cost.md" "unquantified measured cost is rejected"
mutate "$TMP_ROOT/auto-spec.md" "$TMP_ROOT/missing-nongoals.md" "## Non-goals" "## Goals"
expect_reject "$DESIGN_VALIDATOR" "$TMP_ROOT/missing-nongoals.md" "missing non-goals is rejected"
mutate "$TMP_ROOT/auto-spec.md" "$TMP_ROOT/missing-risks.md" "## Residual Risks" "## Risk Notes"
expect_reject "$DESIGN_VALIDATOR" "$TMP_ROOT/missing-risks.md" "missing residual risks is rejected"
mutate "$TMP_ROOT/auto-spec.md" "$TMP_ROOT/missing-success.md" "## Success Criteria" "## Criteria"
expect_reject "$DESIGN_VALIDATOR" "$TMP_ROOT/missing-success.md" "missing success criteria is rejected"
mutate "$TMP_ROOT/auto-spec.md" "$TMP_ROOT/status-only.md" "| Selected: structured |" "| Selected: |"
expect_reject "$DESIGN_VALIDATOR" "$TMP_ROOT/status-only.md" "status-only selected row is rejected"
mutate "$TMP_ROOT/auto-spec.md" "$TMP_ROOT/missing-proving-command.md" "Measured by: \`bash scripts/test-auto-artifact-contract.sh\`" "Measured by this harness"
expect_reject "$DESIGN_VALIDATOR" "$TMP_ROOT/missing-proving-command.md" "missing proving command is rejected"
for non_command in 'progress_path' 'mode: auto'; do
  mutate "$TMP_ROOT/auto-spec.md" "$TMP_ROOT/non-command-span.md" \
    "Measured by: \`bash scripts/test-auto-artifact-contract.sh\`" "Measured by \`$non_command\`"
  expect_reject "$DESIGN_VALIDATOR" "$TMP_ROOT/non-command-span.md" "rejects non-command code span \`$non_command\`"
done
mutate "$TMP_ROOT/auto-spec.md" "$TMP_ROOT/unrelated-control.md" "Negative controls:" "Source controls:"
expect_reject "$DESIGN_VALIDATOR" "$TMP_ROOT/unrelated-control.md" "unrelated control phrase is rejected"
mutate "$TMP_ROOT/auto-spec.md" "$TMP_ROOT/prose-control.md" \
  "Negative controls: mutated fixtures must be rejected." "Negative controls must fail."
expect_reject "$DESIGN_VALIDATOR" "$TMP_ROOT/prose-control.md" "rejects prose without the Negative controls: marker"
for placeholder in '' 'none' 'None.' 'N/A' 'not required' 'not applicable' 'optional' 'TBD' '-' '**none**' '`N/A`' '_TBD_.'; do
  mutate "$TMP_ROOT/auto-spec.md" "$TMP_ROOT/placeholder-control.md" \
    "Negative controls: mutated fixtures must be rejected." "Negative controls: $placeholder"
  expect_reject "$DESIGN_VALIDATOR" "$TMP_ROOT/placeholder-control.md" "placeholder negative-control value is rejected: '$placeholder'"
done
for marker in '- **Negative controls:** mutated fixtures must not pass.' 'Negative control: one optional integration fixture must fail.'; do
  mutate "$TMP_ROOT/auto-spec.md" "$TMP_ROOT/marker-control.md" \
    "Negative controls: mutated fixtures must be rejected." "$marker"
  expect_accept "$DESIGN_VALIDATOR" auto "$TMP_ROOT/marker-control.md" "negative-control marker is accepted: $marker"
done
mutate "$TMP_ROOT/auto-spec.md" "$TMP_ROOT/fenced-control.md" \
  "Negative controls: mutated fixtures must be rejected." $'```\nNegative controls: mutated fixtures must be rejected.\n```'
expect_reject "$DESIGN_VALIDATOR" "$TMP_ROOT/fenced-control.md" "rejects fenced negative-control marker"
mutate "$TMP_ROOT/auto-plan.md" "$TMP_ROOT/plan-prose-control.md" \
  "Negative controls: mutated fixtures must be rejected." "Negative controls must fail."
expect_reject "$PLAN_VALIDATOR" "$TMP_ROOT/plan-prose-control.md" "rejects plan prose without the Negative controls: marker"
mutate "$TMP_ROOT/auto-spec.md" "$TMP_ROOT/no-live-malformed.md" \
  "| Source is readable |" "|  |"
mutate "$TMP_ROOT/no-live-malformed.md" "$TMP_ROOT/no-live-malformed.md" \
  "## Assumptions and Preconditions" $'## Assumptions and Preconditions\nno-live-assumptions'
expect_reject "$DESIGN_VALIDATOR" "$TMP_ROOT/no-live-malformed.md" "no-live marker does not bypass table validation"
mutate "$TMP_ROOT/auto-spec.md" "$TMP_ROOT/nongoals-subheading.md" \
  "## Non-goals" "### Out"
mutate "$TMP_ROOT/nongoals-subheading.md" "$TMP_ROOT/nongoals-subheading.md" \
  "Historical interactive artifacts do not migrate." $'### Additional scope\nThis text is not a non-goal.'
expect_reject "$DESIGN_VALIDATOR" "$TMP_ROOT/nongoals-subheading.md" "same-level subheading cannot satisfy empty Out section"
mutate "$TMP_ROOT/auto-spec.md" "$TMP_ROOT/fenced-heading.md" \
  "## Assumptions and Preconditions" $'````markdown\n## Assumptions and Preconditions\n| Claim | Command | Observed at | Observed result | Evidence source |\n| fake | `echo fake` | 2026-09-19T00:00:00Z | fake | fake |\n```\n````\n## Assumptions and Preconditions'
expect_accept "$DESIGN_VALIDATOR" auto "$TMP_ROOT/fenced-heading.md" "short fence marker does not close long fence"
mutate "$TMP_ROOT/auto-spec.md" "$TMP_ROOT/fenced-only-assumptions.md" \
  "## Assumptions and Preconditions" "## Preconditions"
mutate "$TMP_ROOT/fenced-only-assumptions.md" "$TMP_ROOT/fenced-only-assumptions.md" \
  "## Trade-offs" $'```\n## Assumptions and Preconditions\n| Claim | Command | Observed at | Observed result | Evidence source |\n| fake | `echo fake` | 2026-09-19T00:00:00Z | fake | fake |\n```\n## Trade-offs'
expect_reject "$DESIGN_VALIDATOR" "$TMP_ROOT/fenced-only-assumptions.md" "fenced headings and tables do not satisfy required sections"
mutate "$TMP_ROOT/auto-spec.md" "$TMP_ROOT/assumptions-after-success.md" \
  "## Assumptions and Preconditions" "## Preconditions"
mutate "$TMP_ROOT/assumptions-after-success.md" "$TMP_ROOT/assumptions-after-success.md" \
  "## Architecture" $'## Architecture\n## Assumptions and Preconditions'
expect_reject "$DESIGN_VALIDATOR" "$TMP_ROOT/assumptions-after-success.md" "assumptions after architecture are rejected"
mutate "$TMP_ROOT/auto-plan.md" "$TMP_ROOT/tradeoffs-after-units.md" "## Trade-offs" "## Tradeoffs"
mutate "$TMP_ROOT/tradeoffs-after-units.md" "$TMP_ROOT/tradeoffs-after-units.md" \
  "The validator is a fixture dependency." $'The validator is a fixture dependency.\n## Trade-offs'
expect_reject "$PLAN_VALIDATOR" "$TMP_ROOT/tradeoffs-after-units.md" "trade-offs after implementation units are rejected"
mutate "$TMP_ROOT/auto-plan.md" "$TMP_ROOT/quoted-mode-schema.md" "schema: plan/v1" 'schema: "plan/v1"'
mutate "$TMP_ROOT/quoted-mode-schema.md" "$TMP_ROOT/quoted-mode-schema.md" "mode: auto" 'mode: "auto"'
expect_accept "$PLAN_VALIDATOR" auto "$TMP_ROOT/quoted-mode-schema.md" "quoted plan mode and schema are normalized"
for proving_command in 'npm test' 'pytest tests/foo.py' 'go test ./...'; do
  assert_command_accept "$proving_command"
done
mutate "$TMP_ROOT/auto-spec.md" "$TMP_ROOT/duplicate-mode.md" "mode: auto" $'mode: auto\nmode: interactive'
expect_reject "$DESIGN_VALIDATOR" "$TMP_ROOT/duplicate-mode.md" "duplicate mode is rejected"
if python3 "$DESIGN_VALIDATOR" --mode atuo "$TMP_ROOT/auto-spec.md" >/dev/null 2>&1; then
  fail "unsupported mode is rejected"
else
  pass "unsupported mode is rejected"
fi

if bash "$REPO_ROOT/scripts/test-plugin-skill-discovery.sh" >/dev/null; then
  pass "plugin skill discovery remains green"
else
  fail "plugin skill discovery remains green"
fi

if [ "$failures" -ne 0 ]; then
  echo "FAILED: $failures contract checks"
  exit 1
fi

echo "ALL CHECKS PASSED"
