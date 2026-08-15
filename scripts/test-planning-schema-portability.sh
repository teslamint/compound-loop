#!/usr/bin/env bash
# Test the planning skill as a standalone package.
# This is intentionally RED against the root-only schema layout and GREEN after relocation.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS_COUNT=0
FAIL_COUNT=0
TMP_ROOT=""

pass() {
  printf '  PASS: %s\n' "$1"
  PASS_COUNT=$((PASS_COUNT + 1))
}

fail() {
  printf '  FAIL: %s\n' "$1"
  FAIL_COUNT=$((FAIL_COUNT + 1))
}

resolve_local_schema() {
  local path="$1"
  if [[ ! -s "$path" ]]; then
    printf 'planning-local-schema — missing skills/planning/schemas/plan-schema.md\n' >&2
    return 1
  fi
}

skip() {
  printf '  SKIP: %s\n' "$1"
}

cleanup() {
  if [[ -n "$TMP_ROOT" && -d "$TMP_ROOT" ]]; then
    rm -rf -- "$TMP_ROOT"
  fi
}
trap cleanup EXIT HUP INT TERM

if ! command -v python3 >/dev/null 2>&1; then
  fail 'harness/setup — python3 is required'
  exit 1
fi

if [[ ! -d "$ROOT/skills/planning" ]]; then
  fail 'harness/setup — skills/planning is missing'
  exit 1
fi

# The root copy is the pre-move oracle when it is still present. After relocation,
# recover the same bytes from repository history so parity remains meaningful.
ORACLE="$ROOT/schemas/plan-schema.md"

TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/planning-schema-portability.XXXXXX" 2>/dev/null)"
if [[ -z "$TMP_ROOT" || ! -d "$TMP_ROOT" ]]; then
  fail 'harness/setup — mktemp -d failed'
  exit 1
fi

if [[ ! -s "$ORACLE" ]]; then
  ORACLE_FROM_GIT="$TMP_ROOT/pre-move-plan-schema.md"
  ORACLE_COMMIT=""
  while IFS= read -r candidate; do
    if git -C "$ROOT" show "$candidate:schemas/plan-schema.md" >"$ORACLE_FROM_GIT" 2>/dev/null; then
      ORACLE_COMMIT="$candidate"
      break
    fi
  done < <(git -C "$ROOT" rev-list --first-parent HEAD -- schemas/plan-schema.md)
  if [[ -n "$ORACLE_COMMIT" && -s "$ORACLE_FROM_GIT" ]]; then
    ORACLE="$ORACLE_FROM_GIT"
  else
    fail 'harness/setup — pre-move schema oracle is missing from the worktree and git history'
    exit 1
  fi
fi

mkdir -p "$TMP_ROOT/skills"
if ! cp -R "$ROOT/skills/planning" "$TMP_ROOT/skills/"; then
  fail 'harness/setup — could not create planning-only copy'
  exit 1
fi

PLANNING_COPY="$TMP_ROOT/skills/planning"
LOCAL_SCHEMA="$PLANNING_COPY/schemas/plan-schema.md"
LOCAL_VALIDATOR="$PLANNING_COPY/scripts/validate-plan-frontmatter.py"

if [[ -e "$TMP_ROOT/schemas/plan-schema.md" ]]; then
  fail 'standalone-fixture — unexpectedly contains repository-root schemas/plan-schema.md'
else
  pass 'standalone-fixture — contains only the planning skill and its fixture files'
fi

local_schema_output=""
if local_schema_output="$(resolve_local_schema "$LOCAL_SCHEMA" 2>&1)"; then
  pass 'planning-local-schema — skills/planning/schemas/plan-schema.md resolves'
  SCHEMA_PRESENT=1
else
  fail "$local_schema_output"
  SCHEMA_PRESENT=0
fi

if [[ -s "$LOCAL_VALIDATOR" ]]; then
  pass 'planning-local-validator — scripts/validate-plan-frontmatter.py resolves'
else
  fail 'planning-local-validator — missing scripts/validate-plan-frontmatter.py'
fi

# Explicit inventory of package-owned paths. The two shared references named in
# the skill files (references/question-tools.md and references/dispatch-degradation.md)
# are deliberately not inventory entries: they are repository-root shared inputs,
# not planning-package files.
# The final column is the expected number of occurrences in the source file.
INVENTORY=(
  'skills/planning/SKILL.md|schemas/plan-schema.md|schemas/plan-schema.md|9'
  'skills/planning/SKILL.md|references/deepening.md|references/deepening.md|1'
  'skills/planning/SKILL.md|references/stateful-ceremony-matrix-example.md|references/stateful-ceremony-matrix-example.md|1'
  'skills/planning/SKILL.md|python3 skills/planning/scripts/validate-plan-frontmatter.py <plan-path>|scripts/validate-plan-frontmatter.py|1'
  'skills/planning/references/deepening.md|schemas/plan-schema.md|schemas/plan-schema.md|1'
)

for entry in "${INVENTORY[@]}"; do
  IFS='|' read -r source span local_path expected_count <<< "$entry"
  source_path="$ROOT/$source"
  standalone_source="$PLANNING_COPY/${source#skills/planning/}"
  if [[ ! -f "$source_path" || ! -f "$standalone_source" ]]; then
    fail "planning-local-inventory — source missing: $source"
    continue
  fi

  detail=""
  if ! detail="$(python3 - "$standalone_source" "$span" "$PLANNING_COPY" "$local_path" "$expected_count" <<'PY'
from pathlib import Path
import sys

source, span, planning_copy, local_path, expected_count = sys.argv[1:]
text = Path(source).read_text(encoding="utf-8")
occurrences = text.count(f"`{span}`")
if occurrences != int(expected_count):
    print(
        f"expected {expected_count} backticked occurrences, found {occurrences}: `{span}`"
    )
    raise SystemExit(1)

target = Path(planning_copy) / local_path
if not target.is_file():
    print(f"target missing in planning-only copy: {local_path}")
    raise SystemExit(1)
if target.stat().st_size == 0:
    print(f"target is empty in planning-only copy: {local_path}")
    raise SystemExit(1)
PY
)"; then
    fail "planning-local-inventory — $source -> $local_path${detail:+ — $detail}"
  else
    pass "planning-local-inventory — $source -> $local_path"
  fi
done

if [[ "$SCHEMA_PRESENT" -eq 1 ]]; then
  if cmp -s "$ORACLE" "$LOCAL_SCHEMA"; then
    pass 'schema-byte-parity — planning-local schema matches the pre-move schema oracle'
  else
    fail 'schema-byte-parity — planning-local schema differs from the pre-move schema oracle'
  fi
else
  skip 'schema-byte-parity — deferred until planning-local-schema is present'
fi

# Exercise the validator resolved from the planning-only copy against a minimal
# draft fixture. No repository-root schema is available in this fixture.
DRAFT="$TMP_ROOT/docs/plans/standalone-draft.md"
mkdir -p "$(dirname "$DRAFT")"
cat > "$DRAFT" <<'EOF'
---
schema: plan/v1
title: Standalone planning fixture
type: fix
status: draft
date: 2026-08-15
execution: code
---

# Goal

Standalone validator resolution fixture.
EOF

if [[ -s "$LOCAL_VALIDATOR" ]]; then
  validator_output=""
  if validator_output="$(python3 "$LOCAL_VALIDATOR" "$DRAFT" 2>&1)"; then
    pass 'planning-local-validator — standalone draft resolves and validates'
  else
    fail "planning-local-validator — standalone draft failed${validator_output:+ — $validator_output}"
  fi
fi

# Active paths are intentionally allowlisted. Historical plans/specs/retros/
# reviews/solutions and CHANGELOG are not scanned because their old references
# are preserved evidence, not live resolution paths.
ACTIVE_PATHS=(
  'skills/planning/SKILL.md'
  'skills/planning/references/deepening.md'
  'skills/planning/scripts/validate-plan-frontmatter.py'
  'skills/implementing/SKILL.md'
  'skills/release-loop/SKILL.md'
  'skills/retrospective/SKILL.md'
  'scripts/validate.sh'
)

if [[ "$SCHEMA_PRESENT" -eq 1 ]]; then
  allowlist_output=""
  if ! allowlist_output="$(python3 - "$ROOT" "${ACTIVE_PATHS[@]}" <<'PY'
from pathlib import Path
import re
import sys

root = Path(sys.argv[1])
active_paths = sys.argv[2:]
direct_root_schema = re.compile(r"(?<!skills/planning/)schemas/plan-schema\.md")
split_root_schema = re.compile(
    r'(?:\broot|\$ROOT|\bROOT)\s*/\s*["\']schemas["\']\s*/\s*["\']plan-schema\.md["\']'
)
explicit_package_schema = re.compile(r"skills/planning/schemas/plan-schema\.md")
failures = []

for relative in active_paths:
    path = root / relative
    if not path.is_file():
        failures.append(f"active path missing: {relative}")
        continue
    text = path.read_text(encoding="utf-8")
    for line_number, line in enumerate(text.splitlines(), 1):
        if relative.startswith("skills/planning/"):
            # These files resolve schemas/plan-schema.md relative to the skill
            # package. Explicit repository-root/package paths are stale here.
            if explicit_package_schema.search(line) or split_root_schema.search(line):
                failures.append(f"{relative}:{line_number}: stale root-schema use: {line.strip()}")
        elif direct_root_schema.search(line) or split_root_schema.search(line):
            failures.append(f"{relative}:{line_number}: stale root-schema use: {line.strip()}")

if failures:
    print("\n".join(failures))
    raise SystemExit(1)
PY
)"; then
    fail "active-path-allowlist — stale schema references remain${allowlist_output:+ — $allowlist_output}"
  else
    pass 'active-path-allowlist — live consumers contain no stale root-schema use'
  fi
else
  skip 'active-path-allowlist — deferred until planning-local-schema is present'
fi

if [[ "$SCHEMA_PRESENT" -eq 1 ]]; then
  SCHEMA_BACKUP="$TMP_ROOT/plan-schema.backup"
  if ! mv "$LOCAL_SCHEMA" "$SCHEMA_BACKUP" || [[ -e "$LOCAL_SCHEMA" ]] || [[ ! -s "$SCHEMA_BACKUP" ]]; then
    fail 'planning-local-schema-missing-mutation — setup did not remove exactly the local schema'
  else
    mutation_output=""
    if mutation_output="$(resolve_local_schema "$LOCAL_SCHEMA" 2>&1)"; then
      fail 'planning-local-schema-missing-mutation — missing schema was accepted'
    elif [[ "$mutation_output" == 'planning-local-schema — missing skills/planning/schemas/plan-schema.md' ]]; then
      pass 'planning-local-schema-missing-mutation — named missing-schema failure returned nonzero'
    else
      fail "planning-local-schema-missing-mutation — unexpected diagnostic: $mutation_output"
    fi
    if ! mv "$SCHEMA_BACKUP" "$LOCAL_SCHEMA" || [[ ! -s "$LOCAL_SCHEMA" ]]; then
      fail 'planning-local-schema-missing-mutation — local schema restore failed'
    fi
  fi
else
  skip 'planning-local-schema-missing-mutation — deferred until planning-local-schema is present'
fi

echo
echo "Planning schema portability: $PASS_COUNT checks passed, $FAIL_COUNT failures"
if [[ "$FAIL_COUNT" -gt 0 ]]; then
  exit 1
fi
echo 'ALL CHECKS PASSED'
