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
for s in schemas/plan-schema.md schemas/retro-template.md schemas/headless-contract.md; do
  [ -s "$ROOT/$s" ] && ok "$s present" || fail "$s missing or empty"
done

# 3. Skills: expected roster, frontmatter with name + description
EXPECTED_SKILLS="release-loop designing planning implementing tdd debugging worktree-isolation reviewing shipping retrospective compound compound-refresh release"
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
    try:
        text = f.read_text(encoding="utf-8")
    except OSError as exc:
        bad.append(f"{f.relative_to(root)}: unreadable ({exc.strerror or exc})")
        continue
    for m in re.finditer(r"enforces:\s*(P\d+(?:\s*[,/]\s*P\d+)*)", text):
        for pid in re.findall(r"P\d+", m.group(1)):
            if pid not in valid:
                bad.append(f"{f.relative_to(root)}: unknown principle {pid}")
if bad:
    print("FAIL: " + "; ".join(bad)); sys.exit(1)
print("ok:   all enforces: tags reference existing principles")
PY

# 6. Terminal signal lines in consumer SKILL.md files match schemas/headless-contract.md
python3 - "$ROOT" <<'PY' || FAIL=1
import re, sys, pathlib

root = pathlib.Path(sys.argv[1])
TAG = "[signal-drift]"
failures = []

def fail(msg):
    failures.append(f"FAIL: {TAG} {msg}")

contract_path = root / "schemas/headless-contract.md"
try:
    contract_text = contract_path.read_text(encoding="utf-8")
except OSError:
    fail("schemas/headless-contract.md missing or unreadable")
    contract_text = None

canonical = {}  # producer -> {state: canonical text}
if contract_text is not None:
    for producer in ("compound", "compound-refresh", "retrospective", "release", "release publish"):
        pattern = (
            r"^\|\s*`" + re.escape(producer) + r"`\s*\|\s*`([^`]+)`\s*\|\s*`([^`]+)`\s*\|\s*`([^`]+)`\s*\|\s*$"
        )
        m = re.search(pattern, contract_text, re.M)
        if m:
            canonical[producer] = {
                "success": m.group(1),
                "skipped": m.group(2),
                "failed": m.group(3),
            }
    flat = [(p, s, t) for p, states in canonical.items() for s, t in states.items()]
    distinct = {t for _, _, t in flat}
    if len(flat) != 15 or len(distinct) != 15:
        fail(
            f"schemas/headless-contract.md did not yield exactly 15 canonical, "
            f"pairwise-distinct signal lines (found {len(flat)}, {len(distinct)} distinct)"
        )
        canonical = {}

seen = set()
candidate_re = re.compile(r"`([^`]+)`")
state_re = re.compile(r"^(Documentation|Refresh|Retrospective|Release|Publication)\s+(complete|skipped|failed)\b", re.I)
state_key = {"complete": "success", "skipped": "skipped", "failed": "failed"}
producer_key = {"documentation": "compound", "refresh": "compound-refresh", "retrospective": "retrospective", "release": "release", "publication": "release publish"}

consumer_files = [
    "skills/compound/SKILL.md",
    "skills/compound-refresh/SKILL.md",
    "skills/retrospective/SKILL.md",
    "skills/release/SKILL.md",
]

if canonical:
    for rel in consumer_files:
        path = root / rel
        try:
            text = path.read_text(encoding="utf-8")
        except OSError:
            fail(f"{rel} missing or unreadable")
            continue
        for m in candidate_re.finditer(text):
            span = m.group(1)
            sm = state_re.match(span)
            if not sm:
                continue
            producer = producer_key[sm.group(1).lower()]
            state = state_key[sm.group(2).lower()]
            triplet = canonical.get(producer)
            if triplet is None:
                continue
            line = text.count("\n", 0, m.start()) + 1
            if span == triplet[state]:
                seen.add((producer, state))
            else:
                fail(
                    f"{rel}:{line}: signal text mismatch — found {span!r}, "
                    f"expected one of producer '{producer}': "
                    f"success={triplet['success']!r} skipped={triplet['skipped']!r} failed={triplet['failed']!r}"
                )

    for producer, states in canonical.items():
        for state, text_ in states.items():
            if (producer, state) not in seen:
                fail(
                    f"canonical line not found in any consumer file — "
                    f"producer '{producer}' state '{state}': {text_!r}"
                )

if failures:
    print("\n".join(failures))
    sys.exit(1)
print("ok:   terminal signal lines match schemas/headless-contract.md: 15 canonical pairwise-distinct signals")
PY

# 7. Plugin manifest versions are valid SemVer 2.0.0 strings and agree
python3 - "$ROOT" <<'PY' || FAIL=1
import json
import pathlib
import re
import sys

root = pathlib.Path(sys.argv[1])
tag = "[manifest-version]"
manifest_paths = (
    ".claude-plugin/plugin.json",
    ".codex-plugin/plugin.json",
)

core = r"(?:0|[1-9][0-9]*)"
prerelease_id = r"(?:0|[1-9][0-9]*|[0-9A-Za-z-]*[A-Za-z-][0-9A-Za-z-]*)"
semver = re.compile(
    rf"{core}\.{core}\.{core}"
    rf"(?:-{prerelease_id}(?:\.{prerelease_id})*)?"
    r"(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?"
)

failures = []
versions = {}

for rel in manifest_paths:
    path = root / rel
    try:
        with path.open(encoding="utf-8") as stream:
            manifest = json.load(stream)
    except FileNotFoundError:
        failures.append(f"FAIL: {tag} {rel}: file missing")
        continue
    except json.JSONDecodeError as exc:
        failures.append(
            f"FAIL: {tag} {rel}: invalid JSON at line {exc.lineno}, column {exc.colno}"
        )
        continue
    except UnicodeError as exc:
        failures.append(f"FAIL: {tag} {rel}: invalid JSON encoding ({exc})")
        continue
    except OSError as exc:
        failures.append(f"FAIL: {tag} {rel}: unreadable ({exc.strerror or exc})")
        continue

    if not isinstance(manifest, dict):
        failures.append(
            f"FAIL: {tag} {rel}: version=<unavailable>; manifest root must be an object"
        )
        continue
    if "version" not in manifest:
        failures.append(f"FAIL: {tag} {rel}: version=<missing>")
        continue

    version = manifest["version"]
    if not isinstance(version, str):
        failures.append(
            f"FAIL: {tag} {rel}: version={version!r}; expected a SemVer 2.0.0 string"
        )
        continue
    if semver.fullmatch(version) is None:
        failures.append(
            f"FAIL: {tag} {rel}: version={version!r}; not a valid SemVer 2.0.0 string"
        )
        continue
    versions[rel] = version

if failures:
    print("\n".join(failures))
    sys.exit(1)

claude_path, codex_path = manifest_paths
claude_version = versions[claude_path]
codex_version = versions[codex_path]
if claude_version != codex_version:
    print(
        f"FAIL: {tag} manifest version mismatch: "
        f"{claude_path}={claude_version!r}; {codex_path}={codex_version!r}"
    )
    sys.exit(1)

print(f"ok:   plugin manifest versions agree: {claude_version}")
PY

# 8. Declared Python endpoints compile every registered Python artifact
if ! PYTHON_SUPPORT_FILE="$ROOT/schemas/python-support.json" \
  bash "$ROOT/scripts/test-python-compatibility.sh" all; then
  FAIL=1
fi

# 9. Retro interview format: template vocabulary matches skill prose
python3 - "$ROOT" <<'PY' || FAIL=1
import re, sys, pathlib

root = pathlib.Path(sys.argv[1])
TAG = "[retro-format]"
TEMPLATE = "schemas/retro-template.md"
SKILL = "skills/retrospective/SKILL.md"
PROBES = "skills/retrospective/references/interview-probes.md"
failures = []

def fail(msg):
    failures.append(f"FAIL: {TAG} {msg}")

def finish():
    if failures:
        print("\n".join(failures))
        sys.exit(1)
    print("ok:   retro interview format: template and skill prose agree")
    sys.exit(0)

def boundary_search(value, text):
    # Boundary-aware: a naive substring check would let a template value that
    # is a prefix of the consumer's word (e.g. 'self-check' vs 'self-checklist')
    # pass silently.
    pattern = r"(?<![\w-])" + re.escape(value) + r"(?![\w-])"
    return re.search(pattern, text) is not None

try:
    template_text = (root / TEMPLATE).read_text(encoding="utf-8")
except OSError:
    fail(f"{TEMPLATE} missing or unreadable")
    finish()

if "## Interview Transcript" not in template_text:
    fail(f"{TEMPLATE}: '## Interview Transcript' heading missing")
    finish()

lines = template_text.split("\n")

LEVEL_PREFIX = "- Independence level:"
level_lines = [l for l in lines if l.startswith(LEVEL_PREFIX)]
levels = []
if len(level_lines) != 1:
    fail(f"{TEMPLATE}: expected exactly one '{LEVEL_PREFIX}' line, found {len(level_lines)}")
else:
    levels = [v.strip() for v in level_lines[0][len(LEVEL_PREFIX):].split("|")]
    levels = [v for v in levels if v]
    if len(set(levels)) != 4:
        fail(
            f"{TEMPLATE}: expected 4 distinct independence levels on the "
            f"'{LEVEL_PREFIX}' line, found {len(set(levels))}: {levels!r}"
        )
        levels = []

VERDICT_PREFIX = "Verdict cell values:"
verdict_lines = [l for l in lines if l.startswith(VERDICT_PREFIX)]
verdicts = []
if len(verdict_lines) != 1:
    fail(f"{TEMPLATE}: expected exactly one '{VERDICT_PREFIX}' line, found {len(verdict_lines)}")
else:
    verdicts = re.findall(r"`([^`]+)`", verdict_lines[0])
    if len(set(verdicts)) != 3:
        fail(
            f"{TEMPLATE}: expected 3 distinct backticked verdict forms on the "
            f"'{VERDICT_PREFIX}' line, found {len(set(verdicts))}: {verdicts!r}"
        )
        verdicts = []

consumers = {}
for rel in (SKILL, PROBES):
    try:
        consumers[rel] = (root / rel).read_text(encoding="utf-8")
    except OSError:
        fail(f"{rel} missing or unreadable")

skill_text = consumers.get(SKILL)
if skill_text is not None:
    for level in levels:
        if not boundary_search(level, skill_text):
            fail(f"independence level '{level}' from {TEMPLATE} not found in {SKILL}")

# The probes contract cites exactly one rung — the degraded self-checklist
# mode, the list-final value. A template+SKILL co-rename of that rung would
# otherwise pass while the probes contract keeps the stale name
# (docs/deviations/2026-07-21-check9-probes-level-scope-003.md).
probes_text = consumers.get(PROBES)
if probes_text is not None and levels:
    degraded = levels[-1]
    if not boundary_search(degraded, probes_text):
        fail(f"independence level '{degraded}' from {TEMPLATE} not found in {PROBES}")

# The stable vocabulary anchor of a verdict form is its text before any
# parenthetical (e.g. 'no evidenced answer (3 rejections): <verbatim>'
# anchors on 'no evidenced answer'). Each anchor must appear in both the
# skill prose and the probes contract.
anchors = []
for form in verdicts:
    anchor = form.split("(")[0].strip().rstrip(":").strip()
    if anchor and anchor not in anchors:
        anchors.append(anchor)
for rel in (SKILL, PROBES):
    text = consumers.get(rel)
    if text is None:
        continue
    for anchor in anchors:
        if not boundary_search(anchor, text):
            fail(f"verdict vocabulary '{anchor}' from {TEMPLATE} not found in {rel}")

finish()
PY

# 10. Plan corpus: every docs/plans/*.md passes the plan/v1 frontmatter validator
PLAN_TOTAL=0
PLAN_OK=0
for f in "$ROOT"/docs/plans/*.md; do
  [ -e "$f" ] || continue
  PLAN_TOTAL=$((PLAN_TOTAL + 1))
  if err="$(python3 "$ROOT/skills/planning/scripts/validate-plan-frontmatter.py" "$f" 2>&1 >/dev/null)"; then
    PLAN_OK=$((PLAN_OK + 1))
  else
    fail "[plan-frontmatter] $err"
  fi
done
if [ "$PLAN_TOTAL" -eq 0 ]; then
  fail "[plan-frontmatter] no plan files found"
else
  ok "[plan-frontmatter] $PLAN_OK plans valid"
fi

# 11. final_action shape in active progress.md (conditional — file is gitignored working state)
python3 - "$ROOT" <<'PY' || FAIL=1
import re, sys, pathlib

root = pathlib.Path(sys.argv[1])
TAG = "[final-action]"
progress = root / ".release-loop" / "progress.md"

if not progress.exists():
    print(f"ok:   {TAG} no active progress.md — skipped")
    sys.exit(0)

text = progress.read_text(encoding="utf-8")
fm_match = re.match(r"^---\n(.*?)\n---\n", text, re.S)
if not fm_match:
    print(f"FAIL: {TAG} .release-loop/progress.md has no frontmatter block")
    sys.exit(1)

fm = fm_match.group(1)
fa_match = re.search(r"^final_action:\s*$", fm, re.M)
if not fa_match:
    print(f"ok:   {TAG} no final_action block — skipped")
    sys.exit(0)

fa_lines = []
for line in fm[fa_match.end():].split("\n"):
    if line and not line.startswith("  "):
        break
    if line.startswith("  "):
        fa_lines.append(line)

REQUIRED = {"kind", "status", "command", "updated"}
OPTIONAL = {"marker"}
ALLOWED = REQUIRED | OPTIONAL
KIND_VALUES = {"merge-to-base"}
STATUS_VALUES = {"predicted", "determined", "executed"}

failures = []
found_keys = set()
for line in fa_lines:
    km = re.match(r"^\s+(\w+):", line)
    if km:
        key = km.group(1)
        value = line.split(":", 1)[1].strip()
        found_keys.add(key)
        if key not in ALLOWED:
            failures.append(f"unknown final_action key '{key}'")
        elif key == "kind" and value not in KIND_VALUES:
            failures.append(f"final_action.kind '{value}' not in {KIND_VALUES}")
        elif key == "status" and value not in STATUS_VALUES:
            failures.append(f"final_action.status '{value}' not in {STATUS_VALUES}")

missing = REQUIRED - found_keys
if missing:
    failures.append(f"missing required keys: {', '.join(sorted(missing))}")

if failures:
    for f in failures:
        print(f"FAIL: {TAG} {f}")
    sys.exit(1)

print(f"ok:   {TAG} final_action shape valid ({', '.join(sorted(found_keys))})")
PY

# 12. Carry-forward T-ID referential integrity in retro docs
python3 - "$ROOT" <<'PY' || FAIL=1
import re, sys, pathlib

root = pathlib.Path(sys.argv[1])
TAG = "[cf-tid]"
retro_dir = root / "docs" / "retros"
failures = []

def fail(msg):
    failures.append(f"FAIL: {TAG} {msg}")

if not retro_dir.is_dir():
    print(f"ok:   {TAG} no docs/retros/ directory — skipped")
    sys.exit(0)

checked = 0
for retro in sorted(retro_dir.glob("*-retro.md")):
    text = retro.read_text(encoding="utf-8")
    rel = retro.relative_to(root)

    if "## Interview Transcript" not in text or "## Carry-forward from previous retro" not in text:
        continue

    transcript_start = text.index("## Interview Transcript")
    transcript_section = text[transcript_start:]
    next_h2 = re.search(r"\n## (?!Interview Transcript)", transcript_section)
    if next_h2:
        transcript_section = transcript_section[:next_h2.start()]

    transcript_tids = set()
    phase4_tids = set()
    for m in re.finditer(
        r"^\|\s*(T\d+)\s*\|[^|]*\|[^|]*(\d+)[^|]*\|", transcript_section, re.M
    ):
        tid = m.group(1)
        transcript_tids.add(tid)
        phase_text = m.group(2)
        if phase_text == "4":
            phase4_tids.add(tid)
    for m in re.finditer(
        r"^\|\s*(T\d+)\s*\|\s*—\s*\|\s*(\d+)\s*\|", transcript_section, re.M
    ):
        tid = m.group(1)
        transcript_tids.add(tid)
        if m.group(2) == "4":
            phase4_tids.add(tid)

    if not transcript_tids:
        continue

    cf_start = text.index("## Carry-forward from previous retro")
    cf_section = text[cf_start:]
    next_h2 = re.search(r"\n## (?!Carry-forward from previous retro)", cf_section)
    if next_h2:
        cf_section = cf_section[:next_h2.start()]

    cf_tid_refs = re.findall(r"\(T(\d+)\)", cf_section)
    cf_tid_set = {f"T{n}" for n in cf_tid_refs}

    for tid in sorted(cf_tid_set):
        if tid not in transcript_tids:
            fail(f"{rel}: carry-forward cites {tid} but no such T-ID in interview transcript")

    table_rows = re.findall(r"^\|[^|]+\|[^|]+\|[^|]+\|$", cf_section, re.M)
    has_data_rows = False
    for row in table_rows:
        cells = [c.strip() for c in row.strip("|").split("|")]
        if len(cells) >= 1:
            item = cells[0].strip()
            if item and not re.match(r"^[-—]+$", item) and not item.lower().startswith("item") and "(none" not in item.lower():
                has_data_rows = True
                break

    if has_data_rows and phase4_tids and not phase4_tids.intersection(cf_tid_set):
        fail(
            f"{rel}: Phase 4 probes {sorted(phase4_tids)} exist but none cited "
            f"in carry-forward Evidence cells"
        )

    checked += 1

if failures:
    print("\n".join(failures))
    sys.exit(1)
print(f"ok:   {TAG} carry-forward T-ID integrity: {checked} retro docs checked")
PY

# 13. Planning step/item numbering contiguity and reference resolution
python3 - "$ROOT" <<'PY' || FAIL=1
import re, sys, pathlib

root = pathlib.Path(sys.argv[1])
TAG = "[plan-refs]"
failures = []

def fail(msg):
    failures.append(f"FAIL: {TAG} {msg}")

def check_contiguity(numbers, label):
    if not numbers:
        fail(f"{label}: no numbered items found")
        return
    for i in range(len(numbers) - 1):
        if numbers[i + 1] != numbers[i] + 1:
            fail(f"{label}: gap between {numbers[i]} and {numbers[i + 1]}")

skill_path = root / "skills" / "planning" / "SKILL.md"
deepening_path = root / "skills" / "planning" / "references" / "deepening.md"
schema_path = root / "schemas" / "plan-schema.md"

for p in (skill_path, deepening_path, schema_path):
    if not p.exists():
        fail(f"{p.relative_to(root)} missing")

if failures:
    print("\n".join(failures))
    sys.exit(1)

skill_text = skill_path.read_text(encoding="utf-8")
deepening_text = deepening_path.read_text(encoding="utf-8")
schema_text = schema_path.read_text(encoding="utf-8")

skill_steps = set()
skill_int_steps = []
for m in re.finditer(r"^## (\d+[a-z]?)\.\ ", skill_text, re.M):
    step = m.group(1)
    skill_steps.add(step)
    if step.isdigit():
        skill_int_steps.append(int(step))
skill_int_steps.sort()
check_contiguity(skill_int_steps, "skills/planning/SKILL.md steps")

deep_int_steps = []
for m in re.finditer(r"^## (\d+)\.\ ", deepening_text, re.M):
    deep_int_steps.append(int(m.group(1)))
deep_int_steps.sort()
check_contiguity(deep_int_steps, "skills/planning/references/deepening.md sections")

schema_items = set()
schema_int_items = []
hf_match = re.search(r"## Document body — hard floor\n\n(.*?)(?=\n## )", schema_text, re.S)
if hf_match:
    for m in re.finditer(r"^(\d+)\.\s+\*\*", hf_match.group(1), re.M):
        n = int(m.group(1))
        schema_items.add(str(n))
        schema_int_items.append(n)
    schema_int_items.sort()
    check_contiguity(schema_int_items, "schemas/plan-schema.md hard-floor items")
else:
    fail("schemas/plan-schema.md: '## Document body — hard floor' section not found")

all_files = {
    "skills/planning/SKILL.md": skill_text,
    "skills/planning/references/deepening.md": deepening_text,
    "schemas/plan-schema.md": schema_text,
}
for ref_dir in (root / "skills" / "planning" / "references").iterdir():
    if ref_dir.suffix == ".md" and ref_dir.name != "deepening.md":
        rel = str(ref_dir.relative_to(root))
        all_files[rel] = ref_dir.read_text(encoding="utf-8")

for rel, text in all_files.items():
    for m in re.finditer(r"\bstep (\d+[a-z]?)\b", text, re.I):
        ref = m.group(1).lower()
        if ref not in skill_steps:
            line = text[:m.start()].count("\n") + 1
            fail(f"{rel}:{line}: 'step {ref}' references nonexistent planning step")

for m in re.finditer(r"\bitem (\d+)", schema_text, re.I):
    ref = m.group(1)
    if ref not in schema_items:
        line = schema_text[:m.start()].count("\n") + 1
        fail(f"schemas/plan-schema.md:{line}: 'item {ref}' references nonexistent hard-floor item")

if failures:
    print("\n".join(failures))
    sys.exit(1)
print(
    f"ok:   {TAG} planning references valid: "
    f"{len(skill_steps)} steps, {len(deep_int_steps)} deepening sections, "
    f"{len(schema_items)} hard-floor items"
)
PY

echo
if [ "$FAIL" -eq 0 ]; then
  echo "ALL CHECKS PASSED"
else
  echo "CHECKS FAILED"
  exit 1
fi
