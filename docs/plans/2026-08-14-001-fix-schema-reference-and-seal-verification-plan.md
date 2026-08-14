---
schema: plan/v1
title: Fix unresolvable plugin-root references and verify body_seal values in shipped validator
type: fix
status: approved
date: 2026-08-14
execution: code
origin: .release-loop/briefs/schema-reference-and-seal-verification-spec.md
body_seal: b6e493f865f0e2950d7ea59d24bd75ed6dac68f297962aa23b179c1d241f1fd2
---

# Goal

Resolve issue #14: standardize how plugin-root files are referenced across skills, add path validation at build time, implement canonical body_seal value verification in the shipped validator, and document the migration path for consuming repositories.

# Architecture notes

- **Reference anchoring**: Use the existing "at the plugin root" convention (5 current instances) for all ~57 plugin-root references. This is prose-only and does not change path resolution in code.
- **Path validation**: Add a new check (~16) to `scripts/validate.sh` that scans all skill files for quoted reference paths and verifies they resolve (skill-local first, then plugin-root). Catches broken references at build time.
- **Body seal verification**: Implement the exact canonical extraction (`text.split('---', 2)[2]`) in `validate-plan-frontmatter.py` and add SHA-256 value verification alongside the existing format check. Mismatch is fatal.
- **Migration policy**: Consuming repos with non-canonical seals will fail after upgrade; must re-seal via interactive deepening or revert the body. No one-time exception is granted.

# Assumption Recheck

No origin spec with live assumptions. No assumption recheck required.

# File structure

Files to modify:
- `skills/**/SKILL.md` and `skills/**/references/*.md`: Add "(at the plugin root)" notation to ~57 references
- `scripts/validate.sh`: Add new check ~16 for reference resolution
- `skills/planning/scripts/validate-plan-frontmatter.py`: Add seal verification, --print-seal flag, tests
- `schemas/plan-schema.md`: Expand "Body seal" section with worked example and reproduction commands
- `skills/planning/SKILL.md`: Add pointer to --print-seal and note on re-sealing policy
- `CHANGELOG.md`: Document the seal verification addition and migration policy

# Scenario coverage map

Only user-facing scenario: a consuming repository author approves a plan and needs to compute/verify its seal.

| S-ID | Scenario | Unit chain | Evidence |
|------|----------|-----------|----------|
| S1   | Plan author computes seal at approval time and validates it round-trips | U3, U4, U5 | Spec document self-sealed, validator re-checks it correctly |

# Implementation Units

## U1: Add "(at the plugin root)" notation to ~57 references

- Grep all ~57 unanchored `schemas/` and `references/` references across `skills/**`
- For each plugin-root reference (not skill-local), add "(at the plugin root)" suffix outside backticks
- Verify existing 5 instances already follow this pattern
- Test: `validate.sh` check 16 (new, U2) passes all references

**No code changes; prose-only.**

## U2: Add reference-resolution validation check (~check 16) to `scripts/validate.sh`

- Read every SKILL.md and `references/*.md` file under `skills/`
- Extract all quoted paths matching `schemas/` or `references/` using regex
- For each path: try `skills/<skill>/references/<file>`, then `references/<file>`, then `schemas/<file>`, stop at first match
- If unresolvable: emit fatal error naming the skill, line, path, and checked locations
- Exit 0 if all references resolve
- Test fixtures: 
  - Correct reference resolves ✓
  - Unresolvable path fails with diagnostic ✓
  - Skill-local reference resolves before falling back to plugin-root ✓

## U3: Implement canonical body_seal extraction and verification in `validate-plan-frontmatter.py`

- Add `compute_body_seal(text: str) -> str`: implements `text.split('---', 2)[2]`, UTF-8 encode, SHA-256, lowercase hex
- Add guard: verify substring-split position aligns with line-based closing-delimiter (exact `---` after `rstrip()`), fail if divergent with clear diagnostic
- Replace format-only check at lines 209–213: keep format regex validation, add `compute_body_seal()` call and value comparison
- Mismatch → exit 1 with diagnostic: "body_seal mismatch: expected={stored} actual={computed}. Body was modified post-approval without re-sealing, or the seal was manually edited."
- Plans without `body_seal` skip verification (backward compatible)
- Test fixtures:
  - Correct seal passes ✓
  - Seal mismatch fails ✓
  - One-byte body mutation detected ✓
  - Frontmatter with `---` in a value is rejected ✓
  - Frontmatter with trailing whitespace on closing delimiter is rejected ✓
  - Missing `body_seal` skips check ✓
  - CRLF files reject with delimiter-ambiguity error ✓

## U4: Add `--print-seal` flag and tests to `validate-plan-frontmatter.py`

- Add CLI argument `--print-seal <plan>`: computes seal using `compute_body_seal()` and prints to stdout (64-hex or empty if no body)
- Test: `--print-seal` output is valid 64-hex, and re-running the validator on the same plan with that seal passes

## U5: Expand `schemas/plan-schema.md` "Body seal" section

- Keep existing definition of canonical extraction
- Add **Worked example**: show input bytes, step-by-step canonical extraction, SHA-256 computation, final 64-hex value
- Add **Reproduction commands**: copy-pasteable one-liners for Python (`python3 -c "import hashlib, sys; text = open('plan.md').read(); print(hashlib.sha256(text.split('---', 2)[2].encode()).hexdigest())"`) and shell + `openssl`
- Add **Migration note**: consuming repos with non-canonical or mismatched seals must re-seal via interactive deepening §6 or revert the body; no one-time exception granted

## U6: Update `skills/planning/SKILL.md` and `CHANGELOG.md`

- `skills/planning/SKILL.md`: Add pointer to `--print-seal` flag (section 17) and clarify that it is computation-verification only, not a re-seal path
- `CHANGELOG.md`: Add entry documenting seal value verification in `validate-plan-frontmatter.py` and migration policy for consuming repos

# Mutation/failure-state matrix

No stateful ceremonies involved. No mutations.

# Carry-forward trigger audit

No open carry-forward triggers.

# Deferred to Follow-Up Work

None.

# Open unknowns

Planning-time: all resolved.
Implementation-time: exact line number for new check ~16 in validate.sh (depends on validate.sh structure at implementation time).
