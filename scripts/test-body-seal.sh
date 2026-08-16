#!/usr/bin/env bash
# U4 red/green harness for the shipped validator and repository check 14.
# Every fixture is disposable; expected digests come from an independent oracle.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS_COUNT=0
FAIL_COUNT=0

pass() { echo "  PASS: $1"; PASS_COUNT=$((PASS_COUNT + 1)); }
fail() { echo "  FAIL: $1"; FAIL_COUNT=$((FAIL_COUNT + 1)); }

setup_scratch() {
  local d
  d="$(mktemp -d)" || { echo "harness error: mktemp -d failed" >&2; return 1; }
  mkdir -p "$d/scripts" "$d/docs/plans" "$d/docs/specs" \
    "$d/schemas" "$d/skills/planning/scripts" "$d/skills/planning/schemas" \
    "$d/skills/planning/references" "$d/skills/compound/scripts" \
    "$d/skills/implementing" "$d/skills/reviewing" "$d/skills/shipping" \
    "$d/skills/shipping/references" "$d/skills/retrospective" \
    "$d/skills/release" "$d/skills/designing" "$d/skills/release-loop/references" \
    "$d/skills/compound" "$d/.claude-plugin" "$d/.codex-plugin" "$d/docs/retros"
  # Start from a validation-sufficient disposable snapshot. The fixture plan
  # is then added to the copied corpus, so checks 1–13 and 15 remain real.
  cp -R "$ROOT/skills/"* "$d/skills/" 2>/dev/null || true
  cp -R "$ROOT/schemas/"* "$d/schemas/" 2>/dev/null || true
  cp -R "$ROOT/docs/"* "$d/docs/" 2>/dev/null || true
  cp "$ROOT/scripts/"*.sh "$d/scripts/" 2>/dev/null || true
  cp "$ROOT/CHANGELOG.md" "$ROOT/ROADMAP.md" "$ROOT/CONCEPTS.md" "$d/" 2>/dev/null || true
  cp "$ROOT/.claude-plugin/plugin.json" "$d/.claude-plugin/" 2>/dev/null || true
  cp "$ROOT/.codex-plugin/plugin.json" "$d/.codex-plugin/" 2>/dev/null || true
  cp "$ROOT/PRINCIPLES.md" "$d/" 2>/dev/null || true
  printf '%s\n' "$d"
}

write_plan() {
  local dir="$1" name="$2" frontmatter="$3" body="$4"
  printf '%s\n' '---' "$frontmatter" '---' "$body" >"$dir/docs/plans/$name"
}

write_plan_bytes() {
  local path="$1" contents="$2"
  CONTENTS="$contents" python3 - "$path" <<'PY'
import os
import sys
from pathlib import Path
Path(sys.argv[1]).write_bytes(os.environ["CONTENTS"].encode("utf-8"))
PY
}

# This oracle is deliberately separate from the validator and from the
# migration block. It reads with newline=None, uses the literal split, and
# hashes UTF-8 bytes.
independent_digest() {
  local path="$1"
  python3 - "$path" <<'PY'
import hashlib
import sys
with open(sys.argv[1], encoding="utf-8", newline=None) as handle:
    text = handle.read()
body = text.split("---", 2)[2]
print(hashlib.sha256(body.encode("utf-8")).hexdigest())
PY
}

# A second implementation catches a fixture or oracle that accidentally uses
# raw CRLF bytes instead of universal-newline text semantics.
independent_digest_crosscheck() {
  local path="$1"
  python3 - "$path" <<'PY'
import hashlib
import sys
with open(sys.argv[1], "rb") as handle:
    raw = handle.read()
text = raw.decode("utf-8").replace("\r\n", "\n").replace("\r", "\n")
body = text.split("---", 2)[2]
print(hashlib.sha256(body.encode("utf-8")).hexdigest())
PY
}

run_validate() { bash "$1/scripts/validate.sh" 2>&1; }
run_shipped() { python3 "$1/skills/planning/scripts/validate-plan-frontmatter.py" "$2" 2>&1; }
run_shipped_print() { python3 "$1/skills/planning/scripts/validate-plan-frontmatter.py" --print-seal "$2" 2>&1; }

assert_contains() {
  local label="$1" output="$2" needle="$3"
  if printf '%s\n' "$output" | grep -Fq -- "$needle"; then
    pass "$label"
  else
    fail "$label — missing '$needle'"
    printf '    output: %s\n' "$(printf '%s' "$output" | tr '\n' ' ' | cut -c1-360)"
  fi
}

assert_not_contains() {
  local label="$1" output="$2" needle="$3"
  if printf '%s\n' "$output" | grep -Fq -- "$needle"; then
    fail "$label — unexpected '$needle'"
  else
    pass "$label"
  fi
}

assert_rc() {
  local label="$1" expected="$2" actual="$3"
  if [ "$expected" -eq "$actual" ]; then pass "$label"; else fail "$label — expected exit $expected, got $actual"; fi
}

assert_digest_in() {
  local label="$1" output="$2" digest="$3"
  if printf '%s\n' "$output" | grep -Fq -- "$digest"; then pass "$label"; else fail "$label — computed digest $digest absent"; fi
}

assert_parity_case() {
  local label="$1" d="$2" name="$3" expected="$4" expected_digest="${5:-}"
  local path="$d/docs/plans/$name" check_out shipped_out print_out check_rc shipped_rc print_rc
  check_out="$(run_validate "$d")"; check_rc=$?
  shipped_out="$(run_shipped "$d" "$path")"; shipped_rc=$?
  case "$expected" in
    pass)
      assert_rc "$label/check14 exit" 0 "$check_rc"
      assert_rc "$label/shipped validator exit" 0 "$shipped_rc"
      assert_contains "$label/check14 success" "$check_out" "[body-seal]"
      assert_not_contains "$label/check14 no failure" "$check_out" "FAIL: [body-seal]"
      assert_contains "$label/shipped success" "$shipped_out" "OK:"
      print_out="$(run_shipped_print "$d" "$path")"; print_rc=$?
      assert_rc "$label/shipped print-seal exit" 0 "$print_rc"
      assert_contains "$label/shipped print-seal digest" "$print_out" "$expected_digest"
      ;;
    absent)
      assert_rc "$label/check14 exit" 0 "$check_rc"
      assert_rc "$label/shipped validator exit" 0 "$shipped_rc"
      assert_contains "$label/check14 skip" "$check_out" "skipped"
      assert_contains "$label/shipped success" "$shipped_out" "OK:"
      ;;
    non_scalar)
      assert_rc "$label/check14 exit" 1 "$check_rc"
      assert_rc "$label/shipped validator exit" 1 "$shipped_rc"
      assert_contains "$label/check14 non-scalar verdict" "$check_out" "FAIL: [body-seal]"
      assert_contains "$label/check14 non-scalar diagnostic" "$check_out" "body_seal"
      assert_contains "$label/shipped non-scalar diagnostic" "$shipped_out" "body_seal"
      assert_contains "$label/shipped scalar diagnostic" "$shipped_out" "must be a scalar value"
      ;;
    malformed)
      assert_rc "$label/check14 exit" 1 "$check_rc"
      assert_rc "$label/shipped validator exit" 1 "$shipped_rc"
      assert_contains "$label/check14 format verdict" "$check_out" "FAIL: [body-seal]"
      assert_contains "$label/check14 format diagnostic" "$check_out" "body_seal"
      assert_contains "$label/shipped format diagnostic" "$shipped_out" "body_seal"
      ;;
    mismatch)
      assert_rc "$label/check14 exit" 1 "$check_rc"
      assert_rc "$label/shipped validator exit" 1 "$shipped_rc"
      assert_contains "$label/check14 mismatch verdict" "$check_out" "FAIL: [body-seal]"
      assert_contains "$label/shipped mismatch verdict" "$shipped_out" "body_seal"
      assert_digest_in "$label/check14 computed digest" "$check_out" "$expected_digest"
      assert_digest_in "$label/shipped computed digest" "$shipped_out" "$expected_digest"
      ;;
    extraction)
      assert_rc "$label/check14 exit" 1 "$check_rc"
      print_out="$(run_shipped_print "$d" "$path")"; print_rc=$?
      assert_rc "$label/shipped print exit" 1 "$print_rc"
      assert_contains "$label/check14 extraction verdict" "$check_out" "extract"
      assert_contains "$label/shipped print extraction verdict" "$print_out" "extract"
      assert_contains "$label/check14 body-seal diagnostic" "$check_out" "body_seal"
      assert_contains "$label/shipped print body-seal diagnostic" "$print_out" "body_seal"
      ;;
  esac
}

# --- Seven-shape parity table -------------------------------------------------
echo "Fixture group: seven-shape validator/check14 parity"

# Correct seal and absent seal are separate states. The correct fixture includes
# an inline delimiter in the body to prove literal split(..., 2) behavior.
d="$(setup_scratch)"
write_plan "$d" "correct.md" "schema: plan/v1
title: Correct
type: feat
status: approved
date: 2026-08-15
execution: code" "
## Goal

correct body

---

body text after an inline delimiter
"
correct_digest="$(independent_digest "$d/docs/plans/correct.md")"
correct_digest_2="$(independent_digest_crosscheck "$d/docs/plans/correct.md")"
if [ "$correct_digest" = "$correct_digest_2" ]; then pass "correct/oracle independent digest agreement"; else fail "correct/oracle independent digest agreement"; fi
python3 - "$d/docs/plans/correct.md" "$correct_digest" <<'PY'
import sys
from pathlib import Path
path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
path.write_text(text.replace("execution: code\n---", "execution: code\nbody_seal: " + sys.argv[2] + "\n---"), encoding="utf-8")
PY
assert_parity_case "correct seal" "$d" correct.md pass "$correct_digest"
rm -rf "$d"

# U2 regression: repeated independent seal computation remains deterministic.
d="$(setup_scratch)"
write_plan "$d" "golden.md" "schema: plan/v1
title: Golden
type: feat
status: approved
date: 2026-08-15
execution: code" "
## Goal

golden-hash body
"
golden_one="$(independent_digest "$d/docs/plans/golden.md")"
golden_two="$(independent_digest "$d/docs/plans/golden.md")"
if [ "$golden_one" = "$golden_two" ]; then pass "U2 golden-hash determinism"; else fail "U2 golden-hash determinism"; fi
python3 - "$d/docs/plans/golden.md" "$golden_one" <<'PY'
import sys
from pathlib import Path
path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
path.write_text(text.replace("execution: code\n---", "execution: code\nbody_seal: " + sys.argv[2] + "\n---"), encoding="utf-8")
PY
assert_parity_case "U2 golden-hash round-trip" "$d" golden.md pass "$golden_one"
rm -rf "$d"

# U2 regression: mutable terminal frontmatter does not alter a sealed body.
d="$(setup_scratch)"
write_plan "$d" "terminal.md" "schema: plan/v1
title: Terminal
type: feat
status: approved
date: 2026-08-15
execution: code" "
## Goal

terminal-state body
"
terminal_seal="$(independent_digest "$d/docs/plans/terminal.md")"
write_plan "$d" "terminal.md" "schema: plan/v1
title: Terminal
type: feat
status: done
date: 2026-08-15
execution: code
body_seal: $terminal_seal
completed_by: 0123456789abcdef0123456789abcdef01234567" "
## Goal

terminal-state body
"
assert_parity_case "U2 terminal-state frontmatter mutation" "$d" terminal.md pass "$terminal_seal"
rm -rf "$d"

d="$(setup_scratch)"
write_plan "$d" "absent.md" "schema: plan/v1
title: Absent
type: feat
status: approved
date: 2026-08-15
execution: code" "
## Goal

historical unsealed plan
"
assert_parity_case "absent seal" "$d" absent.md absent
rm -rf "$d"
# RED parity fixture: a parser-valid quoted canonical seal must be accepted
# identically by check 14 and the shipped validator.
d="$(setup_scratch)"
write_plan "$d" "quoted.md" "schema: plan/v1
title: Quoted
type: feat
status: approved
date: 2026-08-15
execution: code" "
## Goal

quoted canonical body
"
quoted_digest="$(independent_digest "$d/docs/plans/quoted.md")"
python3 - "$d/docs/plans/quoted.md" "$quoted_digest" <<'PY'
import sys
from pathlib import Path
path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
path.write_text(
    text.replace(
        "execution: code\n---",
        'execution: code\nbody_seal: "' + sys.argv[2] + '"\n---',
    ),
    encoding="utf-8",
)
PY
assert_parity_case "quoted canonical seal" "$d" quoted.md pass "$quoted_digest"
rm -rf "$d"

# RED parity fixture: a quoted empty scalar is the shipped validator's
# unsealed/absent state and must not be treated as malformed by check 14.
d="$(setup_scratch)"
write_plan "$d" "quoted-empty.md" "schema: plan/v1
title: Quoted empty
type: feat
status: approved
date: 2026-08-15
execution: code
body_seal: \"\"" "
## Goal

quoted empty seal
"
assert_parity_case "quoted empty seal" "$d" quoted-empty.md absent
rm -rf "$d"

# A bare empty value is the shipped parser's list placeholder, not an
# unsealed scalar. Keep this separate from quoted-empty to guard parser parity.
d="$(setup_scratch)"
write_plan "$d" "bare-empty.md" "schema: plan/v1
title: Bare empty
type: feat
status: approved
date: 2026-08-15
execution: code
body_seal:" "
## Goal

bare empty seal
"
assert_parity_case "bare empty seal" "$d" bare-empty.md non_scalar
rm -rf "$d"

# A block sequence is also non-scalar and must fail through each implementation
# instead of being skipped as an empty seal.
d="$(setup_scratch)"
write_plan "$d" "list-valued.md" "schema: plan/v1
title: List-valued
type: feat
status: approved
date: 2026-08-15
execution: code
body_seal:
  - not-a-seal" "
## Goal

list-valued seal
"
assert_parity_case "list-valued seal" "$d" list-valued.md non_scalar
rm -rf "$d"

# RED parity fixture: an earlier scalar containing --- must not hide a later
# mismatching seal from check 14's delimiter-line frontmatter parser.
d="$(setup_scratch)"
write_plan "$d" "embedded-delimiter.md" "schema: plan/v1
title: \"contains --- marker\"
type: feat
status: approved
date: 2026-08-15
execution: code
body_seal: 0000000000000000000000000000000000000000000000000000000000000000" "
## Goal

embedded delimiter mismatch
"
embedded_digest="$(independent_digest "$d/docs/plans/embedded-delimiter.md")"
assert_parity_case "embedded delimiter before mismatching seal" "$d" embedded-delimiter.md mismatch "$embedded_digest"
rm -rf "$d"


d="$(setup_scratch)"
write_plan "$d" "malformed.md" "schema: plan/v1
title: Malformed
type: feat
status: approved
date: 2026-08-15
execution: code
body_seal: not-a-seal" "
## Goal

malformed seal
"
assert_parity_case "malformed seal" "$d" malformed.md malformed
rm -rf "$d"

d="$(setup_scratch)"
write_plan "$d" "mismatch.md" "schema: plan/v1
title: Mismatch
type: feat
status: approved
date: 2026-08-15
execution: code
body_seal: 0000000000000000000000000000000000000000000000000000000000000000" "
## Goal

valid-format mismatch
"
mismatch_digest="$(independent_digest "$d/docs/plans/mismatch.md")"
assert_parity_case "valid-format mismatch" "$d" mismatch.md mismatch "$mismatch_digest"
rm -rf "$d"

d="$(setup_scratch)"
write_plan "$d" "one-byte.md" "schema: plan/v1
title: One byte
type: feat
status: approved
date: 2026-08-15
execution: code" "
## Goal

one-byte token: A
"
one_byte_seal="$(independent_digest "$d/docs/plans/one-byte.md")"
one_byte_mutation_info="$(python3 - "$d/docs/plans/one-byte.md" "$one_byte_seal" <<'PY'
import sys
from pathlib import Path
path = Path(sys.argv[1])
raw = path.read_bytes()
sealed = raw.replace(
    b"execution: code\n---",
    b"execution: code\nbody_seal: " + sys.argv[2].encode("ascii") + b"\n---",
    1,
)
before = sealed
needle = b"one-byte token: A"
replacement = b"one-byte token: B"
if before.count(needle) != 1 or len(needle) != len(replacement):
    raise SystemExit("RED one-byte fixture setup")
after = before.replace(needle, replacement, 1)
differing = sum(left != right for left, right in zip(before, after))
if len(after) != len(before) or differing != 1:
    raise SystemExit("RED one-byte mutation must change exactly one byte")
path.write_bytes(after)
print(f"byte-length={len(before)} differing-bytes={differing}")
PY
)"
assert_contains "one-byte exact mutation" "$one_byte_mutation_info" "byte-length="
assert_contains "one-byte exact mutation count" "$one_byte_mutation_info" "differing-bytes=1"
one_byte_digest="$(independent_digest "$d/docs/plans/one-byte.md")"
assert_parity_case "one-byte body mutation" "$d" one-byte.md mismatch "$one_byte_digest"
rm -rf "$d"

d="$(setup_scratch)"
crlf_path="$d/docs/plans/crlf.md"
crlf_body=$'\r\n## Goal\r\n\r\nCRLF body\r\n'
crlf_fm=$'schema: plan/v1\r\ntitle: CRLF\r\ntype: feat\r\nstatus: approved\r\ndate: 2026-08-15\r\nexecution: code\r\n'
write_plan_bytes "$crlf_path" $'---\r\n'"${crlf_fm}"$'---'"${crlf_body}"
crlf_digest="$(independent_digest "$crlf_path")"
crlf_digest_2="$(independent_digest_crosscheck "$crlf_path")"
if [ "$crlf_digest" = "$crlf_digest_2" ]; then pass "CRLF universal-newline oracle agreement"; else fail "CRLF universal-newline oracle agreement"; fi
python3 - "$crlf_path" "$crlf_digest" <<'PY'
import sys
from pathlib import Path
path = Path(sys.argv[1])
raw = path.read_bytes().decode("utf-8")
raw = raw.replace("execution: code\r\n---", "execution: code\r\nbody_seal: " + sys.argv[2] + "\r\n---")
path.write_bytes(raw.encode("utf-8"))
PY
assert_parity_case "CRLF input" "$d" crlf.md pass "$crlf_digest"
rm -rf "$d"

d="$(setup_scratch)"
# --print-seal reaches canonical extraction before frontmatter parsing, allowing
# this deliberately impossible body extraction to exercise both implementations.
write_plan_bytes "$d/docs/plans/impossible.md" $'---\nschema: plan/v1\ntitle: Impossible\ntype: feat\nstatus: approved\ndate: 2026-08-15\nexecution: code\nbody_seal: 0000000000000000000000000000000000000000000000000000000000000000\n'
assert_parity_case "impossible canonical extraction" "$d" impossible.md extraction
rm -rf "$d"

# --- Current sealed corpus ----------------------------------------------------
echo "Fixture group: every currently sealed plan"
corpus_dir="$(setup_scratch)"
corpus_count=0
for source in "$ROOT"/docs/plans/*.md; do
  [ -f "$source" ] || continue
  if grep -q '^body_seal:' "$source"; then
    name="$(basename "$source")"
    cp "$source" "$corpus_dir/docs/plans/$name"
    corpus_count=$((corpus_count + 1))
    stored="$(sed -n 's/^body_seal:[[:space:]]*//p' "$source" | tr -d '\r' | head -1)"
    expected="$(independent_digest "$corpus_dir/docs/plans/$name" 2>/dev/null || true)"
    if [ -n "$expected" ] && [ "$stored" = "$expected" ]; then
      pass "current corpus independent seal $name"
    else
      fail "current corpus independent seal $name — stored=$stored computed=$expected"
    fi
    shipped="$(run_shipped_print "$corpus_dir" "$corpus_dir/docs/plans/$name")"; shipped_rc=$?
    assert_rc "current corpus shipped validator $name" 0 "$shipped_rc"
    assert_contains "current corpus shipped output $name" "$shipped" "$expected"
  fi
done
corpus_out="$(run_validate "$corpus_dir")"; corpus_rc=$?
assert_rc "current corpus check14 exit" 0 "$corpus_rc"
if [ "$corpus_count" -gt 0 ]; then
  assert_contains "current corpus check14 verified count" "$corpus_out" "$corpus_count verified"
else
  fail "current corpus has at least one sealed plan"
fi
rm -rf "$corpus_dir"

# --- Extract and execute the marked migration oracle -------------------------
echo "Fixture group: executable schema migration-check block"
migration_root="$(mktemp -d)"
MIGRATION_ROOT="$migration_root" SCHEMA_PATH="$ROOT/skills/planning/schemas/plan-schema.md" python3 - <<'PY'
import os
import re
import sys
from pathlib import Path

schema = Path(os.environ["SCHEMA_PATH"])
if not schema.is_file():
    print("RED migration-oracle/missing-schema", file=sys.stderr)
    raise SystemExit(10)
with open(schema, encoding="utf-8", newline=None) as handle:
    text = handle.read()
start = "<!-- body-seal-migration-check:begin -->"
end = "<!-- body-seal-migration-check:end -->"
if text.count(start) != 1 or text.count(end) != 1 or text.index(start) >= text.index(end):
    print("RED migration-oracle/marker-pair — expected exactly one ordered marker pair", file=sys.stderr)
    raise SystemExit(11)
section = text.split(start, 1)[1].split(end, 1)[0]
fences = re.findall(r"```python\n(.*?)\n```", section, re.DOTALL)
if len(fences) != 1 or section.count("```") != 2:
    print("RED migration-oracle/fence-count — expected exactly one fenced python block", file=sys.stderr)
    raise SystemExit(12)
Path(os.environ["MIGRATION_ROOT"], "migration-check.py").write_text(fences[0] + "\n", encoding="utf-8")
print(Path(os.environ["MIGRATION_ROOT"], "migration-check.py"))
PY
oracle_extract_rc=$?
if [ "$oracle_extract_rc" -eq 0 ]; then
  git -C "$migration_root" init -q
  git -C "$migration_root" config user.email fixture@example.invalid
  git -C "$migration_root" config user.name "Migration Fixture"
  mkdir -p "$migration_root/docs/plans"
  write_plan "$migration_root" "migration.md" "schema: plan/v1
title: Migration
type: feat
status: approved
date: 2026-08-15
execution: code" "
## Goal

baseline body
"
  git -C "$migration_root" add docs/plans/migration.md
  git -C "$migration_root" commit -qm "fixture baseline"
  baseline="$(git -C "$migration_root" rev-parse HEAD)"
  object_format="$(git -C "$migration_root" rev-parse --show-object-format 2>/dev/null || true)"
  case "$object_format" in
    sha1) expected_baseline_length=40 ;;
    sha256) expected_baseline_length=64 ;;
    *) expected_baseline_length=0 ;;
  esac
  baseline_length="${#baseline}"
  object_id_length="$expected_baseline_length"
  if [ "$object_id_length" -le 0 ]; then
    object_id_length="$baseline_length"
  fi
  printf -v missing_baseline '%*s' "$object_id_length" ''
  missing_baseline="${missing_baseline// /d}"
  short_baseline="${baseline:0:$((object_id_length - 1))}"
  if [[ "$baseline" =~ ^[0-9a-f]+$ ]]; then
    baseline_value_class="lowercase-full-hex"
  else
    baseline_value_class="not-lowercase-full-hex"
  fi
  if [ "$expected_baseline_length" -gt 0 ] && [ "$baseline_length" -eq "$expected_baseline_length" ] && [ "$baseline_value_class" = "lowercase-full-hex" ]; then
    pass "migration baseline class len=$baseline_length value-class=$baseline_value_class object-format=$object_format"
  else
    fail "migration baseline class len=$baseline_length value-class=$baseline_value_class object-format=$object_format expected-length=$expected_baseline_length"
  fi
  set +e
  unchanged_out="$(cd "$migration_root" && python3 migration-check.py "$baseline" docs/plans/migration.md 2>&1)"; unchanged_rc=$?
  assert_not_contains "migration oracle unchanged baseline avoids invalid-baseline" "$unchanged_out" "invalid-baseline"
  set -e
  if [ "$unchanged_rc" -eq 0 ]; then pass "migration oracle unchanged baseline"; else fail "migration oracle unchanged baseline — $unchanged_out"; fi
  printf '%s\n' 'malformed current canonical text' >"$migration_root/docs/plans/migration.md"
  set +e
  malformed_current_out="$(cd "$migration_root" && python3 migration-check.py "$baseline" docs/plans/migration.md 2>&1)"; malformed_current_rc=$?
  set -e
  assert_rc "migration oracle malformed current canonical text exit" 1 "$malformed_current_rc"
  assert_contains "migration oracle malformed current extraction diagnostic" "$malformed_current_out" "body_seal extraction failed: canonical body requires two '---' delimiters"
  assert_not_contains "migration oracle malformed current no traceback" "$malformed_current_out" "Traceback"
  git -C "$migration_root" restore --source HEAD -- docs/plans/migration.md
  printf '%s\n' 'malformed baseline canonical text' >"$migration_root/docs/plans/migration.md"
  git -C "$migration_root" add docs/plans/migration.md
  git -C "$migration_root" commit -qm "fixture malformed baseline"
  malformed_baseline="$(git -C "$migration_root" rev-parse HEAD)"
  git -C "$migration_root" restore --source "$baseline" -- docs/plans/migration.md
  set +e
  malformed_baseline_out="$(cd "$migration_root" && python3 migration-check.py "$malformed_baseline" docs/plans/migration.md 2>&1)"; malformed_baseline_rc=$?
  set -e
  assert_rc "migration oracle malformed baseline canonical text exit" 1 "$malformed_baseline_rc"
  assert_contains "migration oracle malformed baseline extraction diagnostic" "$malformed_baseline_out" "body_seal extraction failed: canonical body requires two '---' delimiters"
  assert_not_contains "migration oracle malformed baseline no traceback" "$malformed_baseline_out" "Traceback"
  git -C "$migration_root" restore --source "$baseline" -- docs/plans/migration.md
  printf '\nchanged byte\n' >>"$migration_root/docs/plans/migration.md"
  set +e
  changed_out="$(cd "$migration_root" && python3 migration-check.py "$baseline" docs/plans/migration.md 2>&1)"; changed_rc=$?
  set -e
  assert_rc "migration oracle changed body exit" 1 "$changed_rc"
  assert_contains "migration oracle changed-body diagnostic" "$changed_out" "changed-body"
  set +e
  missing_out="$(cd "$migration_root" && python3 migration-check.py "$missing_baseline" docs/plans/migration.md 2>&1)"; missing_rc=$?
  set -e
  assert_rc "migration oracle missing baseline exit" 1 "$missing_rc"
  assert_contains "migration oracle missing-baseline diagnostic" "$missing_out" "missing-baseline"
  git -C "$migration_root" restore --source "$baseline" -- docs/plans/migration.md
  set +e
  option_out="$(cd "$migration_root" && python3 migration-check.py --not-a-commit docs/plans/migration.md 2>&1)"; option_rc=$?
  set -e
  assert_rc "migration oracle option-like baseline exit" 1 "$option_rc"
  assert_contains "migration oracle option-like baseline diagnostic" "$option_out" "invalid-baseline"
  absolute_plan="$migration_root/docs/plans/migration.md"
  set +e
  absolute_out="$(cd "$migration_root" && python3 migration-check.py "$baseline" "$absolute_plan" 2>&1)"; absolute_rc=$?
  set -e
  assert_rc "migration oracle absolute plan path exit" 1 "$absolute_rc"
  assert_contains "migration oracle absolute plan path diagnostic" "$absolute_out" "invalid-plan-path"
  set +e
  traversal_out="$(cd "$migration_root" && python3 migration-check.py "$baseline" ../docs/plans/migration.md 2>&1)"; traversal_rc=$?
  set -e
  assert_rc "migration oracle traversal plan path exit" 1 "$traversal_rc"
  assert_contains "migration oracle traversal plan path diagnostic" "$traversal_out" "invalid-plan-path"
  ln -s docs/plans/migration.md "$migration_root/migration-link.md"
  set +e
  symlink_out="$(cd "$migration_root" && python3 migration-check.py "$baseline" migration-link.md 2>&1)"; symlink_rc=$?
  set -e
  assert_rc "migration oracle symlink plan path exit" 1 "$symlink_rc"
  assert_contains "migration oracle symlink plan path diagnostic" "$symlink_out" "symlink-plan-path"
  set +e
  short_out="$(cd "$migration_root" && python3 migration-check.py "$short_baseline" docs/plans/migration.md 2>&1)"; short_rc=$?
  set -e
  assert_rc "migration oracle short baseline exit" 1 "$short_rc"
  assert_contains "migration oracle short baseline diagnostic" "$short_out" "invalid-baseline"
  uppercase_baseline="A${baseline:1}"
  set +e
  uppercase_out="$(cd "$migration_root" && python3 migration-check.py "$uppercase_baseline" docs/plans/migration.md 2>&1)"; uppercase_rc=$?
  set -e
  assert_rc "migration oracle uppercase baseline exit" 1 "$uppercase_rc"
  assert_contains "migration oracle uppercase baseline diagnostic" "$uppercase_out" "invalid-baseline"
  blob_baseline="$(git -C "$migration_root" hash-object -w "$migration_root/docs/plans/migration.md")"
  set +e
  blob_out="$(cd "$migration_root" && python3 migration-check.py "$blob_baseline" docs/plans/migration.md 2>&1)"; blob_rc=$?
  set -e
  assert_rc "migration oracle exact-length blob baseline exit" 1 "$blob_rc"
  assert_contains "migration oracle exact-length blob baseline diagnostic" "$blob_out" "missing-baseline"
  tree_baseline="$(git -C "$migration_root" rev-parse "$baseline^{tree}")"
  set +e
  tree_out="$(cd "$migration_root" && python3 migration-check.py "$tree_baseline" docs/plans/migration.md 2>&1)"; tree_rc=$?
  set -e
  assert_rc "migration oracle exact-length non-commit baseline exit" 1 "$tree_rc"
  assert_contains "migration oracle exact-length non-commit baseline diagnostic" "$tree_out" "missing-baseline"
  set +e
  missing_path_out="$(cd "$migration_root" && python3 migration-check.py "$baseline" docs/plans/missing.md 2>&1)"; missing_path_rc=$?
  set -e
  assert_rc "migration oracle missing target path exit" 1 "$missing_path_rc"
  assert_contains "migration oracle missing target path diagnostic" "$missing_path_out" "invalid-plan-path"
  set +e
  directory_path_out="$(cd "$migration_root" && python3 migration-check.py "$baseline" docs/plans 2>&1)"; directory_path_rc=$?
  set -e
  assert_rc "migration oracle directory target path exit" 1 "$directory_path_rc"
  assert_contains "migration oracle directory target path diagnostic" "$directory_path_out" "invalid-plan-path"
  ln -s docs "$migration_root/linked-root"
  set +e
  intermediate_symlink_out="$(cd "$migration_root" && python3 migration-check.py "$baseline" linked-root/plans/migration.md 2>&1)"; intermediate_symlink_rc=$?
  set -e
  assert_rc "migration oracle intermediate symlink path exit" 1 "$intermediate_symlink_rc"
  assert_contains "migration oracle intermediate symlink path diagnostic" "$intermediate_symlink_out" "symlink-plan-path"
  cr_path=$'docs/plans/control\r.md'
  lf_path=$'docs/plans/control\n.md'
  cp "$migration_root/docs/plans/migration.md" "$migration_root/$cr_path"
  cp "$migration_root/docs/plans/migration.md" "$migration_root/$lf_path"
  git -C "$migration_root" add -- "$cr_path" "$lf_path"
  git -C "$migration_root" commit -qm "fixture control-bearing paths"
  control_baseline="$(git -C "$migration_root" rev-parse HEAD)"
  mkdir -p "$migration_root/no-git-bin"
  git_probe="$migration_root/git-probe"
  cat >"$migration_root/no-git-bin/git" <<'SH'
#!/bin/sh
printf '%s\n' accessed >"$MIGRATION_GIT_PROBE"
exit 97
SH
  chmod +x "$migration_root/no-git-bin/git"
  for control_kind in cr lf; do
    if [ "$control_kind" = cr ]; then
      control_path="$cr_path"
    else
      control_path="$lf_path"
    fi
    rm -f "$git_probe"
    set +e
    control_out="$(cd "$migration_root" && env MIGRATION_GIT_PROBE="$git_probe" PATH="$migration_root/no-git-bin:$PATH" python3 migration-check.py "$control_baseline" "$control_path" 2>&1)"; control_rc=$?
    set -e
    assert_rc "migration oracle $control_kind-bearing plan path exit" 1 "$control_rc"
    assert_contains "migration oracle $control_kind-bearing plan path diagnostic" "$control_out" "invalid-plan-path"
    assert_not_contains "migration oracle $control_kind-bearing plan path no traceback" "$control_out" "Traceback"
    if [ -e "$git_probe" ]; then
      fail "migration oracle $control_kind-bearing plan path rejects before Git access"
    else
      pass "migration oracle $control_kind-bearing plan path rejects before Git access"
    fi
  done
  # UTF-8 byte escapes keep these U+0085/U+2028/U+2029 path fixtures portable across Bash versions.
  u0085_path=$'docs/plans/control\xc2\x85.md'
  u2028_path=$'docs/plans/control\xe2\x80\xa8.md'
  u2029_path=$'docs/plans/control\xe2\x80\xa9.md'
  cp "$migration_root/docs/plans/migration.md" "$migration_root/$u0085_path"
  cp "$migration_root/docs/plans/migration.md" "$migration_root/$u2028_path"
  cp "$migration_root/docs/plans/migration.md" "$migration_root/$u2029_path"
  git -C "$migration_root" add -- "$u0085_path" "$u2028_path" "$u2029_path"
  git -C "$migration_root" commit -qm "fixture Unicode line-separator paths"
  unicode_baseline="$(git -C "$migration_root" rev-parse HEAD)"
  for unicode_kind in u0085 u2028 u2029; do
    case "$unicode_kind" in
      u0085) unicode_path="$u0085_path" ;;
      u2028) unicode_path="$u2028_path" ;;
      u2029) unicode_path="$u2029_path" ;;
    esac
    rm -f "$git_probe"
    set +e
    unicode_out="$(cd "$migration_root" && env MIGRATION_GIT_PROBE="$git_probe" PATH="$migration_root/no-git-bin:$PATH" python3 migration-check.py "$unicode_baseline" "$unicode_path" 2>&1)"; unicode_rc=$?
    set -e
    assert_rc "migration oracle $unicode_kind plan path exit" 1 "$unicode_rc"
    assert_contains "migration oracle $unicode_kind plan path diagnostic" "$unicode_out" "invalid-plan-path"
    assert_not_contains "migration oracle $unicode_kind plan path no traceback" "$unicode_out" "Traceback"
    if [ -e "$git_probe" ]; then
      fail "migration oracle $unicode_kind plan path rejects before Git access"
    else
      pass "migration oracle $unicode_kind plan path rejects before Git access"
    fi
  done
  cp "$migration_root/docs/plans/migration.md" "$migration_root/-migration.md"
  git -C "$migration_root" add -- -migration.md
  git -C "$migration_root" commit -qm "dash-leading path fixture"
  dash_baseline="$(git -C "$migration_root" rev-parse HEAD)"
  set +e
  dash_out="$(cd "$migration_root" && python3 migration-check.py "$dash_baseline" -migration.md 2>&1)"; dash_rc=$?
  set -e
  assert_rc "migration oracle dash-leading regular path exit" 0 "$dash_rc"
  assert_contains "migration oracle dash-leading regular path diagnostic" "$dash_out" "unchanged-body"
else
  fail "migration oracle extraction and execution — marker/fence contract absent"
fi
rm -rf "$migration_root"
set +e

# --- Disposable Git adoption transition fixture -----------------------------
run_adoption_migration_fixture() {
  local fixture_root
  fixture_root="$(mktemp -d)" || { fail "adoption fixture setup"; return; }
  ROOT_FOR_ADOPTION="$ROOT" FIXTURE_ROOT="$fixture_root" python3 - <<'PY'
from __future__ import annotations

import hashlib
import json
import os
import re
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

root = Path(os.environ["ROOT_FOR_ADOPTION"])
fixture_root = Path(os.environ["FIXTURE_ROOT"])
evidence_root = fixture_root / ".release-loop" / "evidence" / "U4"
evidence_root.mkdir(parents=True)
start = "<!-- body-seal-migration-check:begin -->"
end = "<!-- body-seal-migration-check:end -->"
schema_path = root / "skills/planning/schemas/plan-schema.md"
if schema_path.is_file():
    with open(schema_path, encoding="utf-8", newline=None) as handle:
        schema_text = handle.read()
else:
    schema_text = ""
marker_ok = False
if schema_text.count(start) == 1 and schema_text.count(end) == 1:
    marker_ok = schema_text.index(start) < schema_text.index(end)
section = schema_text.split(start, 1)[1].split(end, 1)[0] if marker_ok else ""
fenced = re.findall(r"```python\n(.*?)\n```", section, re.DOTALL)
block_ok = marker_ok and len(fenced) == 1 and section.count("```") == 2
checker_path = fixture_root / "migration-check.py"
if block_ok:
    checker_path.write_text(fenced[0] + "\n", encoding="utf-8")
source_result = subprocess.run(
    ["git", "-C", str(root), "rev-parse", "HEAD"],
    text=True,
    capture_output=True,
)
source_revision = source_result.stdout.strip() if source_result.returncode == 0 else "unavailable"

OUTCOMES = ("success", "forced-failure", "rerun", "compensation", "headless", "cancellation")
TARGET = "docs/plans/adoption.md"

checker_runs = []

def run_migration_checker(repo: Path, baseline: str, plan_path: str) -> tuple[int, str]:
    argv = ["python3", str(checker_path), baseline, plan_path]
    result = subprocess.run(argv, cwd=repo, text=True, capture_output=True)
    output = (result.stdout + result.stderr).strip()
    checker_runs.append({"argv": argv, "cwd": str(repo), "rc": result.returncode, "output": output})
    return result.returncode, output
def git(repo: Path, *args: str, check: bool = True, strip: bool = True) -> str:
    result = subprocess.run(["git", "-C", str(repo), *args], text=True, capture_output=True)
    if check and result.returncode:
        raise RuntimeError((result.stderr or result.stdout).strip()[:300])
    return result.stdout.strip() if strip else result.stdout

def digest_text(text: str) -> str:
    return hashlib.sha256(text.split("---", 2)[2].encode("utf-8")).hexdigest()

def state(repo: Path, pre_bytes: bytes) -> dict:
    head = git(repo, "rev-parse", "HEAD")
    status = git(repo, "status", "--porcelain", strip=False).rstrip("\n")
    plan = repo / TARGET
    diff = git(repo, "diff", "--no-ext-diff", "--unified=0", "--", TARGET)
    return {
        "head": head,
        "status": status,
        "plan_sha256": hashlib.sha256(plan.read_bytes()).hexdigest() if plan.exists() else "missing",
        "plan_equals_pre": plan.read_bytes() == pre_bytes if plan.exists() else False,
        "diff": diff,
        "dirty_target_only": status == f" M {TARGET}",
    }

def new_repo(outcome: str) -> tuple[Path, str, str, str, bytes, str, bytes]:
    repo = fixture_root / ("repo-" + outcome)
    (repo / "docs/plans").mkdir(parents=True)
    git(repo, "init", "-q")
    git(repo, "config", "user.email", "fixture@example.invalid")
    git(repo, "config", "user.name", "Adoption Fixture")
    body = "\n## Goal\n\nimmutable baseline body\n"
    old = "0" * 64
    plan_text = "---\nschema: plan/v1\ntitle: Adoption\ntype: feat\nstatus: approved\ndate: 2026-08-15\nexecution: code\nbody_seal: " + old + "\n---" + body
    (repo / TARGET).write_text(plan_text, encoding="utf-8")
    (repo / "sentinel.txt").write_text("BOUNDARY_SENTINEL_UNTOUCHED\n", encoding="utf-8")
    sentinel_bytes = (repo / "sentinel.txt").read_bytes()
    git(repo, "add", ".")
    git(repo, "commit", "-qm", "fixture adoption baseline")
    baseline = git(repo, "rev-parse", "HEAD")
    pre_bytes = (repo / TARGET).read_bytes()
    with open(repo / TARGET, encoding="utf-8", newline=None) as handle:
        current = handle.read()
    new = digest_text(current)
    command = f"python3 {checker_path} {baseline} {TARGET}"
    return repo, baseline, old, new, pre_bytes, command, sentinel_bytes

def write_seal(repo: Path, new: str) -> None:
    path = repo / TARGET
    with open(path, encoding="utf-8", newline=None) as handle:
        text = handle.read()
    text = re.sub(r"(?m)^body_seal:.*$", "body_seal: " + new, text, count=1)
    path.write_text(text, encoding="utf-8")

def transition(repo: Path, baseline: str, old: str, new: str, command: str, approval: str | None, injection: str | None, commit_approval: str | None = None) -> tuple[int, str]:
    if not approval:
        return 1, "missing-approval"
    if git(repo, "status", "--porcelain"):
        return 1, "rerun-fail-closed"
    checker_rc, checker_output = run_migration_checker(repo, baseline, TARGET)
    if checker_rc != 0:
        return checker_rc, f"migration-checker:{checker_output}"
    with open(repo / TARGET, encoding="utf-8", newline=None) as handle:
        current = handle.read()
    baseline_text = git(repo, "show", f"{baseline}:{TARGET}", strip=False)
    if digest_text(current) != digest_text(baseline_text):
        return 1, "changed-body"
    if new != digest_text(current):
        return 1, "new-seal-mismatch"
    if injection == "pre-write-cancel":
        return 1, "pre-write-cancel"
    write_seal(repo, new)
    if injection in {"forced-failure", "post-write-cancel"}:
        return 1, injection
    committed_approval = approval if commit_approval is None else commit_approval
    message = (f"adoption reseal\n\nbaseline={baseline}\nplan={TARGET}\nold-seal={old}\n"
               f"new-seal={new}\nreproduction-command={command}\napproval={committed_approval}\n")
    git(repo, "add", TARGET)
    git(repo, "commit", "-qm", message)
    return 0, "committed"

def verify_transition(repo: Path, baseline: str, old: str, new: str, command: str) -> tuple[bool, str]:
    current = state(repo, (repo / TARGET).read_bytes())
    commit = current["head"]
    try:
        parent = git(repo, "rev-parse", f"{commit}^")
    except RuntimeError:
        return False, "success-parent-missing"
    if parent != baseline:
        return False, "success-parent-mismatch"
    changed = set(git(repo, "diff-tree", "--no-commit-id", "--name-only", "-r", commit).splitlines())
    if changed != {TARGET} or current["status"] != "":
        return False, "success-tree-mismatch"
    parent_text = git(repo, "show", f"{parent}:{TARGET}", strip=False)
    current_text = git(repo, "show", f"{commit}:{TARGET}", strip=False)
    old_line = f"body_seal: {old}\n"
    new_line = f"body_seal: {new}\n"
    if parent_text.count(old_line) != 1 or current_text.count(new_line) != 1:
        return False, "success-seal-line-mismatch"
    if re.sub(r"(?m)^body_seal: [0-9a-f]{64}\n", "", parent_text, count=1) != re.sub(r"(?m)^body_seal: [0-9a-f]{64}\n", "", current_text, count=1):
        return False, "success-non-seal-bytes-changed"
    message = git(repo, "show", "-s", "--format=%B", commit, strip=False)
    expected = {
        "baseline": baseline,
        "plan": TARGET,
        "old-seal": old,
        "new-seal": new,
        "reproduction-command": command,
        "approval": "first-hand-explicit",
    }
    parsed: dict[str, str] = {}
    for line in message.splitlines():
        if "=" not in line:
            continue
        key, value = line.split("=", 1)
        if key not in expected or key in parsed:
            return False, "success-message-evidence-mismatch"
        parsed[key] = value
    if parsed != expected:
        return False, "success-message-evidence-mismatch"
    return True, "success-state"

def assert_success(repo: Path, baseline: str, pre: bytes, old: str, new: str, command: str) -> tuple[bool, str]:
    parent_bytes = git(repo, "show", f"{baseline}:{TARGET}", strip=False).encode("utf-8")
    if parent_bytes != pre:
        return False, "success-baseline-plan-mismatch"
    return verify_transition(repo, baseline, old, new, command)

def operator_restore(repo: Path) -> dict:
    argv = ["git", "-C", str(repo), "restore", "--source", "HEAD", "--", TARGET]
    result = subprocess.run(argv, text=True, capture_output=True)
    return {
        "argv": argv,
        "rc": result.returncode,
        "output": result.stdout + result.stderr,
    }


def durable_stage(stage_name: str, action: str, rc: int, output: str, state_value: dict, **details: object) -> dict:
    stage = {
        "stage": stage_name,
        "action": action,
        "rc": rc,
        "output": output,
        "state": state_value,
    }
    stage.update(details)
    return stage

def normalized_plan_bytes(data: bytes) -> bytes:
    return data.decode("utf-8").replace("\r\n", "\n").replace("\r", "\n").encode("utf-8")


def expected_seal_only_bytes(pre_bytes: bytes, old: str, new: str) -> bytes | None:
    normalized = normalized_plan_bytes(pre_bytes)
    pattern = re.compile(rb"(?m)^body_seal: [^\r\n]*\n")
    matches = list(pattern.finditer(normalized))
    old_line = f"body_seal: {old}\n".encode("ascii")
    if len(matches) != 1 or matches[0].group() != old_line:
        return None
    match = matches[0]
    new_line = f"body_seal: {new}\n".encode("ascii")
    return normalized[:match.start()] + new_line + normalized[match.end():]


def exact_seal_only_transition(pre_bytes: bytes, post_bytes: bytes, old: str, new: str) -> bool:
    expected = expected_seal_only_bytes(pre_bytes, old, new)
    normalized_post = normalized_plan_bytes(post_bytes)
    if expected is None or expected == normalized_plan_bytes(pre_bytes) or normalized_post != expected:
        return False
    pattern = re.compile(rb"(?m)^body_seal: [^\r\n]*\n")
    matches = list(pattern.finditer(normalized_post))
    new_line = f"body_seal: {new}\n".encode("ascii")
    return len(matches) == 1 and matches[0].group() == new_line


def mutate_title_frontmatter_body(repo: Path) -> None:
    path = repo / TARGET
    with open(path, encoding="utf-8", newline=None) as handle:
        text = handle.read()
    mutations = (
        ("title: Adoption\n", "title: Mutated Adoption\n"),
        ("execution: code\n", "execution: docs\nextra_frontmatter: mutation\n"),
        ("immutable baseline body\n", "immutable baseline body\nextra body mutation\n"),
    )
    for before, after in mutations:
        if text.count(before) != 1:
            raise RuntimeError("forced-state negative mutation fixture is ambiguous")
        text = text.replace(before, after, 1)
    path.write_text(text, encoding="utf-8")


def forced_failure_state(state_value: dict, baseline: str, pre_bytes: bytes, post_bytes: bytes, old: str, new: str) -> bool:
    return (
        state_value["head"] == baseline
        and state_value["status"] == f" M {TARGET}"
        and state_value["dirty_target_only"]
        and not state_value["plan_equals_pre"]
        and exact_seal_only_transition(pre_bytes, post_bytes, old, new)
    )


def markdown(outcome: str, baseline: str, repo: Path, pre: dict, command: str, rc: int, output: str, post: dict, next_result: str, stages: list[dict], mechanism: str, sentinel: Path, sentinel_check: dict, checker_log: list[dict]) -> str:
    timestamp = datetime.now(timezone.utc).isoformat()
    inventory = [str(fixture_root), str(repo), str(repo / ".git"), str(repo / TARGET),
                 str(root / "skills/planning/schemas/plan-schema.md"), str(evidence_root), str(sentinel),
                 "remote=none", "outward-stub=not-applicable"]
    safe_output = " ".join(output.split())[:360].replace("|", "/")
    stage_text = f"- durable stages: `{json.dumps(stages, sort_keys=True)}`\n" if stages else ""
    return f"""# U4 adoption reseal — {outcome}

- plan identity: `{TARGET}`
- matrix-row identity: `U4/adoption-reseal-{outcome}`
- source commit: `{source_revision}`
- fixture baseline commit: `{baseline}`
- fixture identity and timestamp: `adoption-{outcome}` / `{timestamp}`
- disposable root: `{fixture_root}`
- complete configured target inventory: `{json.dumps(inventory)}`
- applicable stub identity or not-applicable reason: `not-applicable — local git only; no outward stub`
- boundary sentinel: `{sentinel}` / post-check=`{json.dumps(sentinel_check, sort_keys=True)}`
- pre-state: `{json.dumps(pre, sort_keys=True)}`
- exact command/injection: `{command}` / `outcome={outcome}`
- migration checker invocation: `{json.dumps(checker_log, sort_keys=True)}`
- exit status: `{rc}`
- concise sanitized output: `{safe_output}`
- post-state: `{json.dumps(post, sort_keys=True)}`
{stage_text}- relevant next-invocation result: `{next_result}`
- mechanism check: `{mechanism}`
"""


failures = 0
for outcome in OUTCOMES:
    checker_runs = []
    repo, baseline, old, new, pre_bytes, command, sentinel_expected = new_repo(outcome)
    sentinel = repo / "sentinel.txt"
    pre = state(repo, pre_bytes)
    rc = 1
    output = ""
    next_result = "not applicable"
    stages = []
    mechanism = "not-fired"
    if not block_ok:
        output = "missing migration-check block or marker/fence contract"
        mechanism = "BLOCKED: migration oracle contract absent"
        print(f"RED adoption-reseal-{outcome}/missing-migration-check", file=sys.stderr)
        failures += 1
    elif outcome == "success":
        rc, output = transition(repo, baseline, old, new, command, "first-hand-explicit", None)
        ok, mechanism = assert_success(repo, baseline, pre_bytes, old, new, command) if rc == 0 else (False, output)
        if not ok:
            print(f"RED adoption-reseal-{outcome}/{mechanism}", file=sys.stderr)
            failures += 1
    elif outcome == "forced-failure":
        rc, output = transition(repo, baseline, old, new, command, "first-hand-explicit", "forced-failure")
        post = state(repo, pre_bytes)
        post_bytes = (repo / TARGET).read_bytes()
        genuine_forced = rc != 0 and forced_failure_state(post, baseline, pre_bytes, post_bytes, old, new)
        no_op_rejected = (
            not forced_failure_state(pre, baseline, pre_bytes, pre_bytes, old, new)
            and not exact_seal_only_transition(pre_bytes, pre_bytes, old, new)
        )
        mutation_error = ""
        try:
            mutate_title_frontmatter_body(repo)
            mutated = state(repo, pre_bytes)
            mutated_bytes = (repo / TARGET).read_bytes()
            mutation_rejected = (
                not forced_failure_state(mutated, baseline, pre_bytes, mutated_bytes, old, new)
                and not exact_seal_only_transition(pre_bytes, mutated_bytes, old, new)
            )
        except RuntimeError as exc:
            mutation_error = str(exc)
            mutation_rejected = False
        restore = operator_restore(repo)
        if restore["rc"] == 0:
            write_seal(repo, new)
        post = state(repo, pre_bytes)
        post_bytes = (repo / TARGET).read_bytes()
        ok = (
            genuine_forced
            and no_op_rejected
            and mutation_rejected
            and restore["rc"] == 0
            and forced_failure_state(post, baseline, pre_bytes, post_bytes, old, new)
        )
        mechanism = "exact-seal-only-dirty-state" if ok else "forced-state-boundary-missed"
        if mutation_error:
            output = f"{output} negative-mutation={mutation_error}"
        if not ok:
            print(f"RED adoption-reseal-{outcome}/{mechanism}", file=sys.stderr)
            failures += 1
    elif outcome == "rerun":
        forced_rc, forced_output = transition(repo, baseline, old, new, command, "first-hand-explicit", "forced-failure")
        forced = state(repo, pre_bytes)
        forced_bytes = (repo / TARGET).read_bytes()
        rerun_rc, rerun_output = transition(repo, baseline, old, new, command, "first-hand-explicit", None)
        rerun_after = state(repo, pre_bytes)
        restore = operator_restore(repo)
        compensated = state(repo, pre_bytes)
        fresh_approval = "fresh-approval-after-interruption"
        retry_rc, retry_output = transition(repo, baseline, old, new, command, fresh_approval, None, "first-hand-explicit")
        post = state(repo, pre_bytes)
        stages = [
            durable_stage("forced-failure", "seal-write-before-commit", forced_rc, forced_output, forced),
            durable_stage("rerun", "retry-while-target-dirty", rerun_rc, rerun_output, rerun_after),
            durable_stage(
                "compensation",
                "operator-restore-target-only",
                restore["rc"],
                restore["output"],
                compensated,
                argv=restore["argv"],
                result="clean-state-restored",
            ),
            durable_stage(
                "retry",
                "fresh-approval-success",
                retry_rc,
                retry_output,
                post,
                approval=fresh_approval,
                commit_approval="first-hand-explicit",
            ),
        ]
        rc, output = retry_rc, retry_output
        next_result = "fresh-approval retry committed after target-only restore"
        ok, mechanism = assert_success(repo, baseline, pre_bytes, old, new, command) if retry_rc == 0 else (False, retry_output)
        expected_restore_argv = ["git", "-C", str(repo), "restore", "--source", "HEAD", "--", TARGET]
        ok = (forced_rc != 0
              and forced_failure_state(forced, baseline, pre_bytes, forced_bytes, old, new)
              and rerun_rc != 0 and rerun_output == "rerun-fail-closed" and rerun_after == forced
              and restore["argv"] == expected_restore_argv and restore["rc"] == 0
              and compensated == pre and retry_rc == 0 and ok
              and git(repo, "rev-list", "--count", f"{baseline}..HEAD") == "1")
        if not ok:
            print(f"RED adoption-reseal-{outcome}/{mechanism}", file=sys.stderr)
            failures += 1
    elif outcome == "compensation":
        forced_rc, forced_output = transition(repo, baseline, old, new, command, "first-hand-explicit", "forced-failure")
        forced = state(repo, pre_bytes)
        forced_bytes = (repo / TARGET).read_bytes()
        restore = operator_restore(repo)
        post = state(repo, pre_bytes)
        stages = [
            durable_stage("forced-failure", "seal-write-before-commit", forced_rc, forced_output, forced),
            durable_stage(
                "compensation",
                "operator-restore-target-only",
                restore["rc"],
                restore["output"],
                post,
                argv=restore["argv"],
                result="clean-state-restored",
            ),
        ]
        rc, output = forced_rc, forced_output
        ok = (
            forced_rc != 0
            and forced_failure_state(forced, baseline, pre_bytes, forced_bytes, old, new)
            and restore["argv"] == ["git", "-C", str(repo), "restore", "--source", "HEAD", "--", TARGET]
            and restore["rc"] == 0
            and post == pre
        )
        next_result = "operator-owned target-only compensation restored clean state"
        mechanism = "target-only-compensation" if ok else "compensation-boundary-missed"
        if not ok:
            print(f"RED adoption-reseal-{outcome}/{mechanism}", file=sys.stderr)
            failures += 1
    elif outcome == "headless":
        rc, output = transition(repo, baseline, old, new, command, None, None)
        post = state(repo, pre_bytes)
        ok = rc != 0 and output == "missing-approval" and post["head"] == baseline and post["status"] == "" and post["plan_equals_pre"]
        mechanism = "headless-rejected-before-seal-write" if ok else "headless-boundary-missed"
        if not ok:
            print(f"RED adoption-reseal-{outcome}/{mechanism}", file=sys.stderr)
            failures += 1
    elif outcome == "cancellation":
        rc, output = transition(repo, baseline, old, new, command, "first-hand-explicit", "pre-write-cancel")
        pre_cancel = state(repo, pre_bytes)
        post_rc, post_output = transition(repo, baseline, old, new, command, "first-hand-explicit", "post-write-cancel")
        forced = state(repo, pre_bytes)
        forced_bytes = (repo / TARGET).read_bytes()
        restore = operator_restore(repo)
        post = state(repo, pre_bytes)
        stages = [
            durable_stage("pre-write-cancel", "cancel-before-seal-write", rc, output, pre_cancel, result="clean-state-preserved"),
            durable_stage("forced-failure", "seal-write-before-cancel-return", post_rc, post_output, forced),
            durable_stage(
                "compensation",
                "operator-restore-target-only",
                restore["rc"],
                restore["output"],
                post,
                argv=restore["argv"],
                result="clean-state-restored",
            ),
        ]
        next_result = "post-write forced state compensated to clean state"
        ok = (rc != 0 and output == "pre-write-cancel" and pre_cancel == pre
              and post_rc != 0
              and forced_failure_state(forced, baseline, pre_bytes, forced_bytes, old, new)
              and restore["argv"] == ["git", "-C", str(repo), "restore", "--source", "HEAD", "--", TARGET]
              and restore["rc"] == 0 and post == pre)
        mechanism = "pre-write-cancel-and-post-write-forced-failure-compensation" if ok else "cancellation-boundary-missed"
        if not ok:
            print(f"RED adoption-reseal-{outcome}/{mechanism}", file=sys.stderr)
            failures += 1
    else:
        post = state(repo, pre_bytes)
    if outcome == "success":
        post = state(repo, pre_bytes)
    elif outcome not in {"rerun", "compensation", "headless", "cancellation"}:
        post = state(repo, pre_bytes)
    if outcome in {"rerun", "compensation", "cancellation"}:
        expected_stages = {
            "rerun": ("forced-failure", "rerun", "compensation", "retry"),
            "compensation": ("forced-failure", "compensation"),
            "cancellation": ("pre-write-cancel", "forced-failure", "compensation"),
        }[outcome]
        if tuple(stage["stage"] for stage in stages) != expected_stages:
            print(f"RED adoption-reseal-{outcome}/stage-sequence-mismatch", file=sys.stderr)
            failures += 1
    sentinel_observed = sentinel.read_bytes() if sentinel.exists() else b""
    sentinel_check = {
        "expected_sha256": hashlib.sha256(sentinel_expected).hexdigest(),
        "observed_sha256": hashlib.sha256(sentinel_observed).hexdigest(),
        "unchanged": sentinel_observed == sentinel_expected,
    }
    if not sentinel_check["unchanged"]:
        print(f"RED adoption-reseal-{outcome}/boundary-sentinel-mutated", file=sys.stderr)
        failures += 1
    record = markdown(outcome, baseline, repo, pre, command, rc, output, post, next_result, stages, mechanism, sentinel, sentinel_check, checker_runs)
    (evidence_root / f"adoption-reseal-{outcome}.md").write_text(record, encoding="utf-8")

records = sorted(evidence_root.glob("adoption-reseal-*.md"))
expected_names = sorted(f"adoption-reseal-{outcome}.md" for outcome in OUTCOMES)
if [record.name for record in records] != expected_names:
    print("RED adoption-evidence/exactly-six-records", file=sys.stderr)
    failures += 1
mandatory = ("plan identity:", "matrix-row identity:", "source commit:", "fixture identity and timestamp:",
             "disposable root:", "complete configured target inventory:", "applicable stub identity or not-applicable reason:",
             "boundary sentinel:", "pre-state:", "exact command/injection:", "exit status:", "concise sanitized output:",
             "post-state:", "relevant next-invocation result:", "mechanism check:")
for record in records:
    text = record.read_text(encoding="utf-8")
    missing = [field for field in mandatory if field not in text]
    if missing:
        print(f"RED adoption-evidence/{record.name}/missing={','.join(missing)}", file=sys.stderr)
        failures += 1
    if record.name in {"adoption-reseal-rerun.md", "adoption-reseal-compensation.md", "adoption-reseal-cancellation.md"} and "- durable stages: `" not in text:
        print(f"RED adoption-evidence/{record.name}/missing=durable stages:", file=sys.stderr)
        failures += 1
if failures or not block_ok:
    raise SystemExit(1)

canonical_root = root / ".release-loop" / "evidence" / "U4"
expected_canonical = {f"adoption-reseal-{outcome}.md" for outcome in OUTCOMES}
existing = {path.name for path in canonical_root.glob("adoption-reseal-*.md")} if canonical_root.is_dir() else set()
if existing and existing != expected_canonical:
    print("RED adoption-evidence/stale-or-incomplete-canonical-records — refusing overwrite", file=sys.stderr)
    raise SystemExit(1)
canonical_root.parent.mkdir(parents=True, exist_ok=True)
staged = canonical_root.parent / f".U4-evidence-stage-{os.getpid()}"
if staged.exists():
    print("RED adoption-evidence/stale-stage", file=sys.stderr)
    raise SystemExit(1)
staged.mkdir()
for record in records:
    (staged / record.name).write_bytes(record.read_bytes())
if canonical_root.exists():
    for record in staged.iterdir():
        os.replace(record, canonical_root / record.name)
    staged.rmdir()
else:
    os.replace(staged, canonical_root)
PY
  local rc=$?
  rm -rf "$fixture_root"
  if [ "$rc" -eq 0 ]; then pass "adoption migration fixture six durable outcomes"; else fail "adoption migration fixture six durable outcomes — named RED above"; fi
}

run_adoption_migration_fixture

echo
echo "Results: $PASS_COUNT passed, $FAIL_COUNT failed"
if [ "$FAIL_COUNT" -gt 0 ]; then exit 1; fi
exit 0
