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
  if python3 "$validator" --mode auto "$fixture" >/dev/null 2>&1; then
    fail "$label"
  else
    pass "$label"
  fi
}

DESIGNING="$REPO_ROOT/skills/designing/SKILL.md"
PLANNING="$REPO_ROOT/skills/planning/SKILL.md"
DESIGN_VALIDATOR="$REPO_ROOT/skills/designing/scripts/validate-auto-artifact.py"
PLAN_VALIDATOR="$REPO_ROOT/skills/planning/scripts/validate-auto-artifact.py"

require_literal "$DESIGNING" "mode: auto" "designing declares auto mode"
require_literal "$DESIGNING" "Assumptions and Preconditions" "designing declares assumptions section"
require_literal "$DESIGNING" "## Trade-offs" "designing declares trade-offs section"
require_literal "$DESIGNING" "validate-auto-artifact.py" "designing invokes standalone validator"
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
Measured by: `bash scripts/test-auto-artifact-contract.sh`; negative controls must fail.
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
## Architecture notes
The selected fixture option is structured.
## Success Criteria
Measured by: `bash scripts/test-auto-artifact-contract.sh`; negative controls must fail.
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

mutate "$TMP_ROOT/auto-spec.md" "$TMP_ROOT/missing-mode.md" "mode: auto" ""
expect_reject "$DESIGN_VALIDATOR" "$TMP_ROOT/missing-mode.md" "missing mode is rejected"
mutate "$TMP_ROOT/auto-spec.md" "$TMP_ROOT/missing-assumptions.md" "## Assumptions and Preconditions" "## Preconditions"
expect_reject "$DESIGN_VALIDATOR" "$TMP_ROOT/missing-assumptions.md" "missing assumptions section is rejected"
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
mutate "$TMP_ROOT/auto-spec.md" "$TMP_ROOT/unrelated-control.md" "negative controls" "source control"
expect_reject "$DESIGN_VALIDATOR" "$TMP_ROOT/unrelated-control.md" "unrelated control phrase is rejected"
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
