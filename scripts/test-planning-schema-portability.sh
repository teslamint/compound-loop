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

# Find the relocation commit first. Once it exists, parity is anchored to the
# move parent's old-root blob and the move commit's planning-local blob so later
# approved schema documentation changes do not freeze the harness forever.
if ! command -v git >/dev/null 2>&1; then
  fail 'harness/setup — git is required for schema history/oracle checks'
  exit 1
fi

ORACLE_MODE=""
ORACLE=""
MOVE_COMMIT=""
MOVE_PARENT=""
while IFS= read -r candidate; do
  parent="$(git -C "$ROOT" rev-parse "$candidate^" 2>/dev/null || true)"
  if [[ -n "$parent" ]] \
    && git -C "$ROOT" cat-file -e "$parent:schemas/plan-schema.md" 2>/dev/null \
    && git -C "$ROOT" cat-file -e "$candidate:skills/planning/schemas/plan-schema.md" 2>/dev/null; then
    MOVE_COMMIT="$candidate"
    MOVE_PARENT="$parent"
    break
  fi
done < <(git -C "$ROOT" rev-list --first-parent HEAD -- skills/planning/schemas/plan-schema.md)

if [[ -n "$MOVE_COMMIT" ]]; then
  ORACLE_MODE="git"
elif [[ -s "$ROOT/schemas/plan-schema.md" ]]; then
  # RED-phase fallback only: before the relocation commit exists, compare the
  # planning copy with the current root file that is about to be moved.
  ORACLE_MODE="worktree"
  ORACLE="$ROOT/schemas/plan-schema.md"
else
  fail 'harness/setup — no relocation commit and no pre-move root schema oracle'
  exit 1
fi

TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/planning-schema-portability.XXXXXX" 2>/dev/null)"
if [[ -z "$TMP_ROOT" || ! -d "$TMP_ROOT" ]]; then
  fail 'harness/setup — mktemp -d failed'
  exit 1
fi

if [[ "$ORACLE_MODE" == "git" ]]; then
  OLD_SCHEMA_ORACLE="$TMP_ROOT/pre-move-plan-schema.md"
  MOVE_SCHEMA_ORACLE="$TMP_ROOT/move-commit-plan-schema.md"
  if ! git -C "$ROOT" show "$MOVE_PARENT:schemas/plan-schema.md" >"$OLD_SCHEMA_ORACLE" 2>/dev/null \
    || [[ ! -s "$OLD_SCHEMA_ORACLE" ]]; then
    fail "harness/setup — move-parent oracle unavailable for $MOVE_PARENT"
    exit 1
  fi
  if ! git -C "$ROOT" show "$MOVE_COMMIT:skills/planning/schemas/plan-schema.md" >"$MOVE_SCHEMA_ORACLE" 2>/dev/null \
    || [[ ! -s "$MOVE_SCHEMA_ORACLE" ]]; then
    fail "harness/setup — move-commit schema unavailable for $MOVE_COMMIT"
    exit 1
  fi
fi

active_schema_output=""
if ! active_schema_output="$(python3 - "$ROOT" <<'PY'
from pathlib import Path
import sys

root = Path(sys.argv[1])
historical_prefixes = (
    ".git/",
    ".omc/",
    ".release-loop/",
    "docs/plans/",
    "docs/specs/",
    "docs/retros/",
    "docs/reviews/",
    "docs/solutions/",
)
active = []
for path in root.rglob("plan-schema.md"):
    if not path.is_file():
        continue
    relative = path.relative_to(root).as_posix()
    if relative.startswith(historical_prefixes):
        continue
    active.append(relative)

active.sort()
expected = ["skills/planning/schemas/plan-schema.md"]
if active != expected:
    print("expected exactly one active plan-schema.md at skills/planning/schemas/plan-schema.md")
    for relative in active:
        print(f"unexpected active plan-schema.md: {relative}")
    raise SystemExit(1)
PY
)"; then
  fail "active-schema-layout — $active_schema_output"
else
  pass 'active-schema-layout — exactly one active plan-schema.md is planning-local'
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

# Explicit inventory of package-owned paths. The schema source contributes two
# planning-local references as well as SKILL.md and deepening.md references.
# The two shared references named in the skill files
# (references/question-tools.md and references/dispatch-degradation.md) are
# deliberately not inventory entries: they are repository-root shared inputs,
# not planning-package files.
# The final column is the expected number of occurrences in the source file.
INVENTORY=(
  'skills/planning/SKILL.md|schemas/plan-schema.md|schemas/plan-schema.md|9'
  'skills/planning/SKILL.md|references/deepening.md|references/deepening.md|1'
  'skills/planning/SKILL.md|references/stateful-ceremony-matrix-example.md|references/stateful-ceremony-matrix-example.md|1'
  'skills/planning/SKILL.md|skills/planning/scripts/validate-plan-frontmatter.py|scripts/validate-plan-frontmatter.py|1'
  'skills/planning/references/deepening.md|schemas/plan-schema.md|schemas/plan-schema.md|1'
  'skills/planning/schemas/plan-schema.md|skills/planning/references/deepening.md|references/deepening.md|1'
  'skills/planning/schemas/plan-schema.md|skills/planning/references/stateful-ceremony-matrix-example.md|references/stateful-ceremony-matrix-example.md|1'
)

# Discover every path-like backticked package reference from the planning
# contract sources before resolving any declared target. The two shared root
# references are the only exclusions.
run_inventory_check() {
  python3 - "$PLANNING_COPY" "${INVENTORY[@]}" <<'PY'
from collections import Counter
from pathlib import Path
import re
import sys

planning_copy = Path(sys.argv[1])
declared_rows = sys.argv[2:]
discovery_sources = sorted(
    path for path in planning_copy.rglob("*.md")
    if path.is_file()
)
excluded = {
    "references/question-tools.md",
    "references/dispatch-degradation.md",
}
path_pattern = re.compile(
    r"(?<![\w./-])(?P<path>(?:skills/planning/)?"
    r"(?:schemas|references|scripts)/[A-Za-z0-9._<>/-]+)"
)
backtick_pattern = re.compile(r"`([^`]*)`")


def normalize(path: str) -> str:
    if path.startswith("skills/planning/"):
        return path[len("skills/planning/") :]
    return path


def is_local_candidate(raw_path: str, local_path: str) -> bool:
    if local_path in excluded:
        return False
    if raw_path.startswith("skills/planning/"):
        return True
    if local_path.startswith(("schemas/", "references/")):
        # Relative schema/reference paths are package-local candidates even
        # when their targets are currently missing.
        return True
    if local_path.startswith("scripts/"):
        # Unprefixed scripts/validate.sh-style commands may target a fixture
        # or repository root. Existing planning-local scripts remain local.
        return (planning_copy / local_path).is_file()
    return False


declared = Counter()
declaration_errors = []
for row in declared_rows:
    fields = row.split("|")
    if len(fields) != 4:
        declaration_errors.append(f"malformed declaration: {row}")
        continue
    source, span, local_path, count_text = fields
    try:
        count = int(count_text)
    except ValueError:
        declaration_errors.append(f"invalid count in declaration: {row}")
        continue
    normalized = normalize(span)
    if normalized != local_path:
        declaration_errors.append(
            f"span/path normalization mismatch: {source}|{span}|{local_path}"
        )
    key = (source, normalized)
    if key in declared:
        declaration_errors.append(f"duplicate declaration: {source}|{span}")
    declared[key] += count

discovered = Counter()
for path in discovery_sources:
    relative_to_planning = path.relative_to(planning_copy).as_posix()
    relative = f"skills/planning/{relative_to_planning}"
    text = path.read_text(encoding="utf-8")
    source_spans = backtick_pattern.findall(text)
    source_key = relative
    for source_span in source_spans:
        for match in path_pattern.finditer(source_span):
            raw_path = match.group("path")
            local_path = normalize(raw_path)
            if is_local_candidate(raw_path, local_path):
                discovered[(source_key, local_path)] += 1

if declaration_errors:
    print("\n".join(declaration_errors))
    raise SystemExit(1)

if discovered != declared:
    print("discovered-vs-declared planning-local inventory mismatch")
    for key in sorted(set(discovered) | set(declared)):
        found = discovered.get(key, 0)
        declared_count = declared.get(key, 0)
        if found != declared_count:
            print(f"{key[0]}|{key[1]}|discovered={found}|declared={declared_count}")
    raise SystemExit(1)
PY
}

if [[ "$SCHEMA_PRESENT" -eq 1 ]]; then
  inventory_output=""
  if ! inventory_output="$(run_inventory_check 2>&1)"; then
    fail "planning-local-inventory-completeness — $inventory_output"
  else
    pass 'planning-local-inventory-completeness — discovered and declared source/span/count sets match'
  fi
else
  skip 'planning-local-inventory-completeness — deferred until planning-local-schema is present'
fi

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
import re
import sys

source, span, planning_copy, local_path, expected_count = sys.argv[1:]
text = Path(source).read_text(encoding="utf-8")
source_spans = re.findall(r"`([^`]*)`", text)
occurrences = sum(source_span.count(span) for source_span in source_spans)
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
  MUTATION_SKILL="$PLANNING_COPY/SKILL.md"
  MUTATION_BACKUP="$TMP_ROOT/SKILL.md.inventory-backup"
  if ! cp "$MUTATION_SKILL" "$MUTATION_BACKUP"; then
    fail 'planning-local-inventory-missing-relative-mutation — fixture backup failed'
  else
    printf '\nInventory mutation probe: `references/new-local-reference.md`\n' >>"$MUTATION_SKILL"
    mutation_output=""
    if mutation_output="$(run_inventory_check 2>&1)"; then
      fail 'planning-local-inventory-missing-relative-mutation — missing reference was accepted'
    elif [[ "$mutation_output" == *'discovered-vs-declared planning-local inventory mismatch'* \
      && "$mutation_output" == *'references/new-local-reference.md'* ]]; then
      pass 'planning-local-inventory-missing-relative-mutation — missing relative reference was rejected'
    else
      fail "planning-local-inventory-missing-relative-mutation — unexpected diagnostic: $mutation_output"
    fi
    if ! mv "$MUTATION_BACKUP" "$MUTATION_SKILL"; then
      fail 'planning-local-inventory-missing-relative-mutation — fixture restore failed'
    fi
  fi
else
  skip 'planning-local-inventory-missing-relative-mutation — deferred until planning-local-schema is present'
fi

if [[ "$SCHEMA_PRESENT" -eq 1 ]]; then
  if [[ "$ORACLE_MODE" == "git" ]]; then
    if cmp -s "$OLD_SCHEMA_ORACLE" "$MOVE_SCHEMA_ORACLE"; then
      pass 'schema-byte-parity — move-parent old blob matches move-commit planning-local blob'
    else
      fail 'schema-byte-parity — move-parent old blob differs from move-commit planning-local blob'
    fi
  elif cmp -s "$ORACLE" "$LOCAL_SCHEMA"; then
    pass 'schema-byte-parity — planning-local schema matches the pre-move worktree oracle'
  else
    fail 'schema-byte-parity — planning-local schema differs from the pre-move worktree oracle'
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
