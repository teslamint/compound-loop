#!/usr/bin/env bash
# Structural validation for compound-loop. Stdlib only (bash + python3).
# Exit 0 = all checks pass. enforces: P3 (fresh evidence before completion claims).
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

fail() { echo "FAIL: $1"; FAIL=1; }
ok()   { echo "ok:   $1"; }

# 1. Manifests parse as JSON
for m in .claude-plugin/plugin.json .codex-plugin/plugin.json; do
  if python3 -c "import json,sys; json.load(open('$ROOT/$m'))" 2>/dev/null; then
    ok "$m is valid JSON"
  else
    fail "$m missing or invalid JSON"
  fi
done

# 2. Schemas parse
for s in schemas/lane-findings.schema.json schemas/review-envelope.schema.json; do
  if python3 -c "import json,sys; json.load(open('$ROOT/$s'))" 2>/dev/null; then
    ok "$s is valid JSON"
  else
    fail "$s missing or invalid JSON"
  fi
done
for s in schemas/plan-schema.md schemas/retro-template.md; do
  [ -s "$ROOT/$s" ] && ok "$s present" || fail "$s missing or empty"
done

# 3. Skills: expected roster, frontmatter with name + description
EXPECTED_SKILLS="release-loop designing planning implementing tdd debugging worktree-isolation reviewing shipping retrospective compound compound-refresh"
for skill in $EXPECTED_SKILLS; do
  f="$ROOT/skills/$skill/SKILL.md"
  if [ ! -f "$f" ]; then
    fail "skills/$skill/SKILL.md missing"
    continue
  fi
  python3 - "$f" "$skill" <<'PY' || FAIL=1
import sys, re
path, skill = sys.argv[1], sys.argv[2]
text = open(path, encoding="utf-8").read()
m = re.match(r"^---\n(.*?)\n---\n", text, re.S)
if not m:
    print(f"FAIL: {skill}: no frontmatter block"); sys.exit(1)
fm = m.group(1)
name = re.search(r"^name:\s*(\S+)", fm, re.M)
desc = re.search(r"^description:\s*\S", fm, re.M)
if not name:
    print(f"FAIL: {skill}: frontmatter missing name"); sys.exit(1)
if name.group(1) != skill:
    print(f"FAIL: {skill}: frontmatter name '{name.group(1)}' != directory name"); sys.exit(1)
if not desc:
    print(f"FAIL: {skill}: frontmatter missing description"); sys.exit(1)
print(f"ok:   skills/{skill}/SKILL.md frontmatter valid")
PY
done

# 4. PRINCIPLES.md: 9 principles, each with the four elements
python3 - "$ROOT/PRINCIPLES.md" <<'PY' || FAIL=1
import sys, re
text = open(sys.argv[1], encoding="utf-8").read()
principles = re.findall(r"^## (P\d+)\.", text, re.M)
if len(principles) != 9:
    print(f"FAIL: PRINCIPLES.md has {len(principles)} principles, expected 9"); sys.exit(1)
blocks = re.split(r"^## P\d+\.", text, flags=re.M)[1:]
bad = []
for pid, block in zip(principles, blocks):
    for element in ("**Statement**", "**Rationale**", "**Boundary**", "**Enforcement**"):
        if element not in block:
            bad.append(f"{pid} missing {element}")
if bad:
    print("FAIL: " + "; ".join(bad)); sys.exit(1)
print("ok:   PRINCIPLES.md: 9 principles x 4 elements")
PY

# 5. enforces: tags reference existing principles
python3 - "$ROOT" <<'PY' || FAIL=1
import sys, re, pathlib
root = pathlib.Path(sys.argv[1])
valid = {f"P{i}" for i in range(1, 10)}
bad = []
for f in list(root.glob("skills/**/*.md")) + list(root.glob("references/*.md")) + list(root.glob("schemas/*.md")):
    for m in re.finditer(r"enforces:\s*(P\d+(?:\s*[,/]\s*P\d+)*)", f.read_text(encoding="utf-8")):
        for pid in re.findall(r"P\d+", m.group(1)):
            if pid not in valid:
                bad.append(f"{f.relative_to(root)}: unknown principle {pid}")
if bad:
    print("FAIL: " + "; ".join(bad)); sys.exit(1)
print("ok:   all enforces: tags reference existing principles")
PY

echo
if [ "$FAIL" -eq 0 ]; then
  echo "ALL CHECKS PASSED"
else
  echo "CHECKS FAILED"
  exit 1
fi
