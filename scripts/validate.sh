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
for s in skills/planning/schemas/plan-schema.md schemas/retro-template.md schemas/headless-contract.md; do
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
    if len(set(levels)) != 5:
        fail(
            f"{TEMPLATE}: expected 5 distinct independence levels on the "
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
    if len(set(verdicts)) != 4:
        fail(
            f"{TEMPLATE}: expected 4 distinct backticked verdict forms on the "
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

# The probes contract carries the verdict forms of every rung, so every
# template level is asserted against it — not the list-final value alone.
# This supersedes the earlier list-final scope
# (docs/plans/2026-08-14-001-fix-retro-interview-integrity-plan.md).
probes_text = consumers.get(PROBES)
if probes_text is not None:
    for level in levels:
        if not boundary_search(level, probes_text):
            fail(f"independence level '{level}' from {TEMPLATE} not found in {PROBES}")

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

metric_rows = (
    "Review rounds (unit / final / standalone)",
    "Fix rounds",
    "Internal findings (fixed / deferred)",
    "Pull request comments (fixed / deferred)",
    "Count completeness",
)
for label in metric_rows:
    matches = [line for line in lines if line.startswith(f"| {label} |")]
    if len(matches) != 1:
        fail(f"{TEMPLATE}: expected exactly one release-data row '{label}', found {len(matches)}")

metric_contract = (
    "unit_passes + final_passes + standalone_passes",
    "lower bound since `counting_started_at`",
    "unknown `completeness` value blocks",
    "stale-commit-range",
    "reviews/facilitator/round-<N>.md",
    "Persist every facilitator round verbatim",
)
if skill_text is not None:
    for fragment in metric_contract:
        if fragment not in skill_text:
            fail(f"{SKILL}: structured release-data contract missing '{fragment}'")

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
schema_path = root / "skills" / "planning" / "schemas" / "plan-schema.md"

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
    check_contiguity(schema_int_items, "skills/planning/schemas/plan-schema.md hard-floor items")
else:
    fail("skills/planning/schemas/plan-schema.md: '## Document body — hard floor' section not found")

all_files = {
    "skills/planning/SKILL.md": skill_text,
    "skills/planning/references/deepening.md": deepening_text,
    "skills/planning/schemas/plan-schema.md": schema_text,
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
        fail(f"skills/planning/schemas/plan-schema.md:{line}: 'item {ref}' references nonexistent hard-floor item")

if failures:
    print("\n".join(failures))
    sys.exit(1)
print(
    f"ok:   {TAG} planning references valid: "
    f"{len(skill_steps)} steps, {len(deep_int_steps)} deepening sections, "
    f"{len(schema_items)} hard-floor items"
)
PY

# 14. Plan corpus: body-seal integrity
python3 - "$ROOT" <<'PY' || FAIL=1
import hashlib, re, sys, pathlib

root = pathlib.Path(sys.argv[1])
TAG = "[body-seal]"
plans_dir = root / "docs" / "plans"

if not plans_dir.is_dir():
    print(f"ok:   {TAG} no docs/plans/ directory — skipped")
    sys.exit(0)

plans = sorted(plans_dir.glob("*.md"))
if not plans:
    print(f"ok:   {TAG} no plan files — skipped")
    sys.exit(0)

def extract_frontmatter(text):
    lines = text.split("\n")
    if not lines or lines[0].rstrip() != "---":
        raise ValueError("file does not start with '---' frontmatter delimiter line")

    end_idx = None
    for i in range(1, len(lines)):
        if lines[i].rstrip() == "---":
            end_idx = i
            break
    if end_idx is None:
        raise ValueError("frontmatter not closed (no '---' line after the opening delimiter)")

    return lines[1:end_idx]

def unquote(value):
    if len(value) >= 2 and value[0] == value[-1] and value[0] in "\"'":
        return value[1:-1]
    return value

def body_seal_scalar(fm_lines):
    value = None
    current_key = None
    for line in fm_lines:
        stripped = line.lstrip()
        if not stripped or stripped.startswith("#"):
            continue
        if line.startswith((" ", "\t")):
            if stripped.startswith("- ") and current_key == "body_seal":
                item = unquote(stripped[2:].strip())
                if isinstance(value, list):
                    value.append(item)
                else:
                    value = [item]
            continue
        if ":" not in line:
            continue
        key, _, raw = line.partition(":")
        current_key = key.strip()
        if current_key != "body_seal":
            continue
        raw = raw.strip()
        value = unquote(raw) if raw else []
    return value

failures = []
checked = 0
skipped = 0

for plan in plans:
    rel = plan.relative_to(root)
    with open(plan, encoding="utf-8", newline=None) as handle:
        text = handle.read()

    try:
        fm_lines = extract_frontmatter(text)
    except ValueError:
        failures.append(
            f"FAIL: {TAG} {rel}: body_seal extraction failed: "
            "canonical body requires two '---' delimiters"
        )
        continue

    stored = body_seal_scalar(fm_lines)
    if stored is None or stored == "":
        skipped += 1
        continue

    if not isinstance(stored, str):
        failures.append(
            f"FAIL: {TAG} {rel}: body_seal present but non-scalar: "
            "expected a scalar value"
        )
        continue

    if not re.fullmatch(r"[0-9a-f]{64}", stored):
        failures.append(
            f"FAIL: {TAG} {rel}: body_seal present but malformed: '{stored}'"
        )
        continue

    try:
        body = text.split('---', 2)[2]
    except IndexError:
        failures.append(
            f"FAIL: {TAG} {rel}: 'body_seal' extraction failed: "
            "canonical body requires two '---' delimiters"
        )
        continue

    computed = hashlib.sha256(body.encode("utf-8")).hexdigest()

    if stored != computed:
        failures.append(
            f"FAIL: {TAG} {rel}: body_seal mismatch "
            f"expected={stored} actual={computed}"
        )
    else:
        checked += 1

if failures:
    print("\n".join(failures))
    sys.exit(1)
print(
    f"ok:   {TAG} body-seal integrity: "
    f"{checked} verified, {skipped} skipped (no seal)"
)
PY

# 15. Release-loop new-work workspace policy
if ! bash "$ROOT/scripts/test-release-loop-worktree-default.sh"; then
  FAIL=1
fi

# 16. Review-remediated planning and Ship contracts
python3 - "$ROOT" <<'PY' || FAIL=1
import hashlib
import os
import pathlib
import re
import subprocess
import sys
import tempfile

root = pathlib.Path(sys.argv[1])
TAG = "[review-remediation]"
failures = []

def load(relative):
    path = root / relative
    if not path.is_file():
        failures.append(f"FAIL: {TAG} {relative} missing")
        return ""
    return path.read_text(encoding="utf-8")

def require(relative, text, needle):
    if needle not in text:
        failures.append(f"FAIL: {TAG} {relative} missing contract: {needle}")

def reject(relative, text, needle):
    if needle in text:
        failures.append(f"FAIL: {TAG} {relative} retains contradictory contract: {needle}")

def raw_sha256(relative):
    path = root / relative
    if not path.is_file():
        return ""
    return hashlib.sha256(path.read_bytes()).hexdigest()

def operative_markdown(text):
    without_comments = re.sub(r"(?s)<!--.*?-->", "", text)
    operative = []
    fence_character = None
    fence_length = 0
    for line in without_comments.splitlines(keepends=True):
        if fence_character is None:
            opener = re.match(r"^[ \t]{0,3}(`{3,}|~{3,})(.*?)(?:\r?\n)?$", line)
            if opener and (
                opener.group(1)[0] == "~" or "`" not in opener.group(2)
            ):
                fence_character = opener.group(1)[0]
                fence_length = len(opener.group(1))
                continue
            operative.append(line)
            continue

        closer = re.match(r"^[ \t]{0,3}(`{3,}|~{3,})[ \t]*(?:\r?\n)?$", line)
        if (
            closer
            and closer.group(1)[0] == fence_character
            and len(closer.group(1)) >= fence_length
        ):
            fence_character = None
            fence_length = 0
    return "".join(operative)

def unique_section(relative, text, heading):
    matches = re.findall(
        rf"(?ms)^{re.escape(heading)}\n(.*?)(?=^## |\Z)",
        operative_markdown(text),
    )
    if len(matches) != 1:
        failures.append(
            f"FAIL: {TAG} {relative} expected one operative {heading} section"
        )
        return ""
    return matches[0]

planning_rel = "skills/planning/SKILL.md"
planning = load(planning_rel)
discrimination = re.findall(r"^- \*\*Discrimination check\*\*.*$", planning, re.M)
if len(discrimination) != 1:
    failures.append(f"FAIL: {TAG} {planning_rel} expected one Discrimination check bullet")
else:
    for clause in (
        "same comparison domain as the step's real comparands",
        "same command, pipeline, or computation",
        "When the real comparands are artifacts",
        "effect-bearing signal, field, or subartifact",
    ):
        require(planning_rel, discrimination[0], clause)
for clause in (
    "Both pairs use the same artifact kinds as the step's real comparands",
    "Different artifact kinds in the real comparands or either fixture pair fail this check outright",
):
    reject(planning_rel, planning, clause)

loop_rel = "skills/release-loop/SKILL.md"
loop = load(loop_rel)
transition_contract = re.findall(r"^Before either family runs,.*$", loop, re.M)
if len(transition_contract) != 1:
    failures.append(f"FAIL: {TAG} {loop_rel} expected one transition contract paragraph")
else:
    for clause in (
        "A declined, deferred, relayed, or headless outward transition leaves Ship blocked",
        "a matrix-permitted local transition may complete headlessly",
    ):
        require(loop_rel, transition_contract[0], clause)
reject(loop_rel, loop, "decline, deferral, relayed approval, or headless mode leaves Ship blocked")
if re.search(r"(?is)(?:scan|glob|discover).{0,100}docs/deviations/", loop):
    failures.append(f"FAIL: {TAG} {loop_rel} permits automatic deviation discovery")
for clause in (
    "never overrides a transition by discovery alone",
    "current-session USER approves the exact committed addendum path and whole-file SHA-256",
    "exactly one matching approval line for the current session",
    "Retain prior-session approval lines as history but ignore them",
    "transition-override-approved",
):
    require(loop_rel, loop, clause)

shipping_rel = "skills/shipping/SKILL.md"
shipping = load(shipping_rel)
merge_gate = unique_section(shipping_rel, shipping, "## Step 7: Merge Gate")
cleanup = unique_section(shipping_rel, shipping, "## Step 8: Cleanup")

persist_contract = re.findall(
    r"^\*\*Persist before the gate resolves\*\*:.*$",
    merge_gate,
    re.M,
)
if len(persist_contract) != 1:
    failures.append(
        f"FAIL: {TAG} {shipping_rel} expected one operative pre-gate persistence paragraph"
    )
else:
    for clause in (
        "On every merge path, append a separate `merged-result-verification-command` record",
        "before presenting the merge gate",
        "Sink by mode:",
        "`release-loop` -> `.release-loop/progress.md`",
        "standalone -> the worktree's git-dir state",
    ):
        require(shipping_rel, persist_contract[0], clause)
    if persist_contract[0].count("merged-result-verification-command") != 1:
        failures.append(
            f"FAIL: {TAG} {shipping_rel} expected one pre-gate replay-command record"
        )

cleanup_intro = re.findall(
    r"^For \*\*every merge outcome\*\*, merged-result verification is an executable prerequisite for cleanup:$",
    cleanup,
    re.M,
)
if len(cleanup_intro) != 1:
    failures.append(
        f"FAIL: {TAG} {shipping_rel} expected one all-merge cleanup prerequisite"
    )

numbered_steps = re.findall(r"^([1-4])\. (.*)$", cleanup, re.M)
if [number for number, _ in numbered_steps] != ["1", "2", "3", "4"]:
    failures.append(
        f"FAIL: {TAG} {shipping_rel} expected ordered merged-result steps 1-4"
    )
else:
    step_contracts = dict(numbered_steps)
    for clause in (
        "non-empty, non-`null`",
        "merged commit SHA",
        "A missing SHA blocks",
    ):
        require(shipping_rel, step_contracts["1"], clause)
    for clause in (
        "fast-forward only",
        "Confirm that `git rev-parse HEAD` equals the merged commit SHA",
        "a checkout mismatch blocks",
    ):
        require(shipping_rel, step_contracts["2"], clause)
    for clause in (
        "exact verification command",
        "persisted before the merge gate",
        "no narrower, reconstructed, or substitute command",
    ):
        require(shipping_rel, step_contracts["3"], clause)
    for clause in (
        "When invoked by `release-loop` with one or more eligible approved-plan pre-removal transitions",
        "success record to `progress.md`",
    ):
        require(shipping_rel, step_contracts["4"], clause)

cleanup_contract = re.findall(
    r"^Every merge path MUST complete steps 1-3 successfully \*\*before cleanup\*\*\..*$",
    cleanup,
    re.M,
)
if len(cleanup_contract) != 1:
    failures.append(
        f"FAIL: {TAG} {shipping_rel} expected one operative all-merge completion paragraph"
    )
else:
    for clause in (
        "Missing SHA, checkout mismatch, absent or ambiguous command evidence, or failed verification blocks cleanup",
        "Step 4 applies only",
        "before persisting any approved-plan transition start",
        "blocks every pre-removal transition and, on this release-loop path, cleanup",
        "Standalone `shipping` reads the command from its existing git-dir record",
        "typed `discard` path remains separate",
    ):
        require(shipping_rel, cleanup_contract[0], clause)

for contradiction in (
    r"(?i)\b(?:may|can)\b[^\n]{0,120}\b(?:reconstruct(?:ed)?|substitute)\b",
    r"(?i)\b(?:approved-plan )?transition start\b[^\n]{0,120}\bbefore\b[^\n]{0,120}\b(?:verification|success)",
    r"(?i)\bstandalone\b[^\n]{0,120}\b(?:skip|without)\b[^\n]{0,120}\b(?:verification|replay)\b",
):
    if re.search(contradiction, cleanup):
        failures.append(
            f"FAIL: {TAG} {shipping_rel} retains contradictory cleanup ordering"
        )

reject(
    shipping_rel,
    cleanup,
    "Standalone `shipping` without an eligible approved-plan transition still verifies the merged result under Step 1 before cleanup",
)

packet_rel = "docs/issue-closures/2026-08-15-issues-11-and-12-command.md"
payload_rel = "docs/issue-closures/2026-08-15-issue-11.md"
plan_rel = "docs/plans/2026-08-15-001-fix-planning-discrimination-and-verdict-coverage-plan.md"
addendum_rel = "docs/deviations/2026-08-15-pr15-review-remediation-013.md"
packet = load(packet_rel)
payload = load(payload_rel)
plan = load(plan_rel)
addendum = load(addendum_rel)

for heading in (
    "## Original contract",
    "## Discovered contradictions",
    "## Necessity",
    "## Decision",
    "## Observable behavior",
    "## Safety and consent boundaries",
    "## Verification changes",
    "## Traceability",
):
    require(addendum_rel, addendum, heading)
for clause in (
    "Preparation evidence — first-hand consent still required. This file authorizes no command.",
    "git show HEAD:docs/issue-closures/2026-08-15-issue-11.md",
    "git show HEAD:docs/issue-closures/2026-08-15-issue-12.md",
):
    require(packet_rel, packet, clause)

override_blocks = re.findall(
    r"^### Transition override R2\s*\n(.*?)(?=^### |^## |\Z)",
    addendum,
    re.M | re.S,
)
if len(override_blocks) != 1:
    failures.append(f"FAIL: {TAG} {addendum_rel} expected one Transition override R2 block")
override = override_blocks[0] if len(override_blocks) == 1 else ""

def override_field(name):
    values = re.findall(rf"^- {re.escape(name)}: `([^`]+)`$", override, re.M)
    if len(values) != 1:
        failures.append(f"FAIL: {TAG} {addendum_rel} expected one override field: {name}")
        return ""
    return values[0]

override_plan = override_field("Plan")
transition = override_field("Transition")
target = override_field("Target")
replaced = override_field("Replaces-SHA-256")
replacement = override_field("Replacement-SHA-256")
payload_pin = override_field("Issue-11-payload-SHA-256")
if override_plan != plan_rel:
    failures.append(f"FAIL: {TAG} R2 override plan '{override_plan}' != '{plan_rel}'")
if transition != "R2":
    failures.append(f"FAIL: {TAG} override transition '{transition}' != 'R2'")
if target != packet_rel:
    failures.append(f"FAIL: {TAG} R2 override target '{target}' != '{packet_rel}'")
for name, value in (
    ("Replaces-SHA-256", replaced),
    ("Replacement-SHA-256", replacement),
    ("Issue-11-payload-SHA-256", payload_pin),
):
    if value and not re.fullmatch(r"[0-9a-f]{64}", value):
        failures.append(f"FAIL: {TAG} {addendum_rel} {name} is not a SHA-256 digest")
r2_sections = re.findall(
    r"^## Release-loop post-Ship completion transition R2:.*?(?=^## |\Z)",
    plan,
    re.M | re.S,
)
if len(r2_sections) != 1:
    failures.append(f"FAIL: {TAG} {plan_rel} expected one sealed R2 section")
elif replaced and f"packet SHA-256 `{replaced}`" not in r2_sections[0]:
    failures.append(f"FAIL: {TAG} sealed R2 section does not name replaced packet digest")
if replacement and raw_sha256(packet_rel) != replacement:
    failures.append(f"FAIL: {TAG} packet raw-byte digest does not match R2 replacement")
if payload_pin and raw_sha256(payload_rel) != payload_pin:
    failures.append(f"FAIL: {TAG} issue-11 payload raw-byte digest does not match addendum pin")
if payload_pin and payload_pin not in packet:
    failures.append(f"FAIL: {TAG} packet does not pin current issue-11 payload")

packet_body_match = re.fullmatch(r".*?```bash\n(.*)\n```\n?", packet, re.S)
if not packet_body_match:
    failures.append(f"FAIL: {TAG} {packet_rel} does not contain one extractable bash body")
else:
    packet_body = packet_body_match.group(1)
    preflight = (
        'status_11=$(comment_status 11 "$PAYLOAD_11")',
        "state_11=$(issue_state 11)",
        'status_12=$(comment_status 12 "$PAYLOAD_12")',
        "state_12=$(issue_state 12)",
    )
    mutations = (
        "gh issue comment 11",
        "gh issue close 11",
        "gh issue comment 12",
        "gh issue close 12",
    )
    if all(item in packet_body for item in preflight + mutations):
        if max(packet_body.index(item) for item in preflight) > min(
            packet_body.index(item) for item in mutations
        ):
            failures.append(f"FAIL: {TAG} packet mutates before all issue preflights finish")

    def run_packet_fixture(tamper_pin=False, tamper_worktree=False, fail_issue=""):
        with tempfile.TemporaryDirectory(prefix="review-remediation-") as tmp:
            fixture = pathlib.Path(tmp)
            fixture_payloads = fixture / "docs" / "issue-closures"
            fixture_payloads.mkdir(parents=True)
            for source_name in (
                "2026-08-15-issue-11.md",
                "2026-08-15-issue-12.md",
            ):
                source = root / "docs" / "issue-closures" / source_name
                (fixture_payloads / source_name).write_bytes(source.read_bytes())
            if tamper_pin:
                tampered = fixture_payloads / "2026-08-15-issue-11.md"
                tampered.write_bytes(tampered.read_bytes() + b"\ntampered\n")
            for args in (
                ("git", "init", "-q"),
                ("git", "config", "user.email", "fixture@example.invalid"),
                ("git", "config", "user.name", "Fixture"),
                ("git", "config", "commit.gpgsign", "false"),
                ("git", "add", "docs"),
                ("git", "commit", "-qm", "fixture"),
            ):
                subprocess.run(
                    args,
                    cwd=fixture,
                    check=True,
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL,
                )
            if tamper_worktree:
                tampered = fixture_payloads / "2026-08-15-issue-11.md"
                tampered.write_bytes(tampered.read_bytes() + b"\nworking-tree-only\n")
            fixture_bin = fixture / "bin"
            fixture_bin.mkdir()
            gh_stub = fixture_bin / "gh"
            gh_stub.write_text(
                """#!/usr/bin/env python3
import json
import os
import pathlib
import sys
args = sys.argv[1:]
with pathlib.Path(os.environ["GH_LOG"]).open("a") as log:
    log.write(" ".join(args) + "\\n")
if args[:2] != ["issue", "view"]:
    raise SystemExit(0)
issue = args[2]
if issue == os.environ.get("GH_FAIL_VIEW"):
    raise SystemExit(92)
payload = pathlib.Path("docs/issue-closures") / f"2026-08-15-issue-{issue}.md"
if os.environ.get("GH_FIXTURE_STATE") == "OPEN_ABSENT":
    print(json.dumps({"state": "OPEN", "comments": []}))
else:
    print(json.dumps({
        "state": "CLOSED",
        "comments": [{"body": payload.read_text().rstrip("\\n")}],
    }))
""",
                encoding="utf-8",
            )
            gh_stub.chmod(0o755)
            gh_log = fixture / "gh.log"
            env = os.environ.copy()
            env.update({
                "BASH_ENV": "/dev/null",
                "GH_FAIL_VIEW": fail_issue,
                "GH_FIXTURE_STATE": "OPEN_ABSENT" if fail_issue else "CLOSED_PRESENT",
                "GH_LOG": str(gh_log),
                "PATH": f"{fixture_bin}{os.pathsep}{env['PATH']}",
            })
            result = subprocess.run(
                ("bash", "-c", packet_body),
                cwd=fixture,
                env=env,
                text=True,
                capture_output=True,
            )
            calls = gh_log.read_text(encoding="utf-8").splitlines() if gh_log.exists() else []
            return result, calls

    clean_result, clean_calls = run_packet_fixture()
    if clean_result.returncode != 0:
        failures.append(f"FAIL: {TAG} clean merged-base packet fixture failed")
    if any(call.startswith(("issue comment ", "issue close ")) for call in clean_calls):
        failures.append(f"FAIL: {TAG} clean packet fixture performed an unexpected mutation")
    pin_result, pin_calls = run_packet_fixture(tamper_pin=True)
    if pin_result.returncode == 0 or "payload hash mismatch" not in pin_result.stderr:
        failures.append(f"FAIL: {TAG} tampered packet fixture did not fail on its payload pin")
    if pin_calls:
        failures.append(f"FAIL: {TAG} tampered packet fixture reached gh before hash failure")
    worktree_result, worktree_calls = run_packet_fixture(tamper_worktree=True)
    if worktree_result.returncode == 0:
        failures.append(f"FAIL: {TAG} working-tree/HEAD payload mismatch unexpectedly succeeded")
    if worktree_calls:
        failures.append(f"FAIL: {TAG} working-tree/HEAD mismatch reached gh before cmp failure")
    read_failure_result, read_failure_calls = run_packet_fixture(fail_issue="12")
    if read_failure_result.returncode == 0:
        failures.append(f"FAIL: {TAG} late issue preflight read failure unexpectedly succeeded")
    if any(call.startswith(("issue comment ", "issue close ")) for call in read_failure_calls):
        failures.append(f"FAIL: {TAG} packet mutated before late issue read failure")

if failures:
    print("\n".join(failures))
    sys.exit(1)
print(f"ok:   {TAG} planning and Ship review contracts present")
PY

# Run-scope discovery, closed-root, handoff, and archive fixtures.
if ! bash "$ROOT/scripts/test-run-artifact-integrity.sh" scope; then
  FAIL=1
fi
if ! bash "$ROOT/scripts/test-run-artifact-integrity.sh" retro; then
  FAIL=1
fi

echo
if [ "$FAIL" -eq 0 ]; then
  echo "ALL CHECKS PASSED"
else
  echo "CHECKS FAILED"
  exit 1
fi
