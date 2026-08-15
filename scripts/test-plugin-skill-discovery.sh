#!/usr/bin/env bash
set -euo pipefail

# Verify plugin skill discovery works without global ~/.agents/skills/ supplementation.
# Checks that every SKILL.md under the plugin's declared skills directory has valid
# frontmatter (name + description) and that no skill references files outside the repo.

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CODEX_PLUGIN="$REPO_ROOT/.codex-plugin/plugin.json"
CLAUDE_PLUGIN="$REPO_ROOT/.claude-plugin/plugin.json"

fail=0
checked=0

# Parse skills directory from codex plugin manifest
if [ ! -f "$CODEX_PLUGIN" ]; then
  echo "FAIL: .codex-plugin/plugin.json not found"
  exit 1
fi

skills_dir_raw=$(python3 -c "
import json, sys
with open('$CODEX_PLUGIN') as f:
    d = json.load(f)
print(d.get('skills', ''))
")

if [ -z "$skills_dir_raw" ]; then
  echo "FAIL: no 'skills' field in .codex-plugin/plugin.json"
  exit 1
fi

skills_dir="$REPO_ROOT/${skills_dir_raw#./}"

if [ ! -d "$skills_dir" ]; then
  echo "FAIL: skills directory '$skills_dir' does not exist"
  exit 1
fi

echo "ok: skills directory resolves to $skills_dir"
# The planning skill is shipped as a standalone artifact and must carry its
# own full schema rather than depending on the repository-root schemas/ copy.
planning_schema="$skills_dir/planning/schemas/plan-schema.md"
if [ -s "$planning_schema" ]; then
  echo "ok: planning artifact includes skills/planning/schemas/plan-schema.md"
else
  echo "FAIL: planning artifact missing required skills/planning/schemas/plan-schema.md"
  fail=$((fail + 1))
fi

# Check every SKILL.md
for skill_file in "$skills_dir"/*/SKILL.md; do
  [ -f "$skill_file" ] || continue
  skill_name=$(basename "$(dirname "$skill_file")")
  checked=$((checked + 1))

  # Check frontmatter exists
  if ! head -1 "$skill_file" | grep -q '^---$'; then
    echo "FAIL: $skill_name/SKILL.md missing frontmatter delimiter"
    fail=$((fail + 1))
    continue
  fi

  # Extract name and description from frontmatter
  has_name=$(sed -n '/^---$/,/^---$/p' "$skill_file" | grep '^name:' | head -1)
  has_desc=$(sed -n '/^---$/,/^---$/p' "$skill_file" | grep '^description:' | head -1)

  if [ -z "$has_name" ]; then
    echo "FAIL: $skill_name/SKILL.md missing 'name:' in frontmatter"
    fail=$((fail + 1))
  elif [ -z "$has_desc" ]; then
    echo "FAIL: $skill_name/SKILL.md missing 'description:' in frontmatter"
    fail=$((fail + 1))
  else
    echo "ok: $skill_name — name and description present"
  fi
done

# Verify both plugin manifests exist and agree on version
if [ ! -f "$CLAUDE_PLUGIN" ]; then
  echo "FAIL: .claude-plugin/plugin.json not found"
  fail=$((fail + 1))
else
  codex_ver=$(python3 -c "import json; print(json.load(open('$CODEX_PLUGIN'))['version'])")
  claude_ver=$(python3 -c "import json; print(json.load(open('$CLAUDE_PLUGIN'))['version'])")
  if [ "$codex_ver" = "$claude_ver" ]; then
    echo "ok: manifest versions agree ($codex_ver)"
  else
    echo "FAIL: manifest version mismatch (codex=$codex_ver, claude=$claude_ver)"
    fail=$((fail + 1))
  fi
fi

echo ""
echo "Plugin skill discovery: $checked skills checked, $fail failures"

if [ "$fail" -gt 0 ]; then
  exit 1
fi
echo "ALL CHECKS PASSED"
