---
schema: plan/v1
title: Post-approval immutability enforcement and outward-publication recognition
type: feat
status: draft
date: 2026-07-31
execution: code
origin: docs/specs/2026-07-31-post-approval-immutability-design.md
---

## Goal

Add mechanical body-seal validation (validate.sh check 14) and cross-cutting skill-level immutability checks to enforce the existing plan-body immutability rule, and expand the stateful-ceremony definition to name outward-publication boundaries.

## Architecture notes

Body extraction rule: everything after the line matching the second `---` in the plan file, through EOF including trailing newline. The second `---` line itself is excluded. SHA-256 lowercase hex digest. Identical rule in planning (seal writer) and validate.sh (seal checker).

The seal proves body-matches-last-seal, not unchanged-since-approval. An agent that re-seals defeats check 14. The cross-cutting skill rules (implementing preflight, reviewing) defend against unauthorized re-sealing. Interactive deepening is the sole authorized re-seal path.

Outward-publication boundary is a recognition expansion of the existing stateful-ceremony definition, not a new mechanism. A plan whose units include outward transitions (push, release, visibility change) but carries the stateless fallback has a recognition error caught by reviewing.

Fixture mechanism for check 14: a separate harness script (`scripts/test-body-seal.sh`) using the `test-plan-frontmatter.sh` pattern — disposable `mktemp -d` directory with fixture plans, validate.sh run inside the scratch copy. Negative fixtures live in the scratch copy, not in `docs/plans/`, so they do not break the real validate.sh run.

Boundary interpreter coverage: validate.sh's Python heredocs are automatically tested when `test-python-compatibility.sh` runs `invoke_validation_fixture_repo` — it executes validate.sh under the boundary interpreters. No separate artifact registry entry is needed; the check 14 heredoc gets boundary-compiled as part of that existing flow.

## Assumption Recheck

| Claim | Fresh command | Fresh result | Outcome |
|---|---|---|---|
| plan-schema.md declares body immutability via "Mutable slots" | `grep -c "Mutable slots" schemas/plan-schema.md` | 1 | match |
| validate.sh check 10 validates plan frontmatter | `grep -c "Plan corpus" scripts/validate.sh` | 1 | match |
| 15 existing plans, 0 with body_seal (16 after this plan lands) | `ls docs/plans/*.md \| wc -l` and `grep -rl body_seal docs/plans/*.md \| wc -l` | 15 / 0 | match |
| validate.sh has 13 checks | `grep -c "^# [0-9]" scripts/validate.sh` | 13 | match |
| Auto deepening runs at step 15, approval at step 17 | `grep -n "^## 15\|^## 17" skills/planning/SKILL.md` | 157 / 165 | match |
| Reviewing Requirements Completeness at line 86 | `grep -n "Requirements Completeness" skills/reviewing/SKILL.md` | line 86 | match |
| Implementing preflight items 1-5 at lines 16-21 | Read `skills/implementing/SKILL.md:14-21` | 5 items confirmed | match |
| validate.sh heredocs get boundary-interpreter coverage via invoke_validation_fixture_repo | `grep -n "invoke_validation_fixture_repo" scripts/test-python-compatibility.sh` | line 554 context: runs validate.sh with PYTHON_OLDEST/PYTHON_NEWEST set | match |
| Fixture harness pattern: test-plan-frontmatter.sh uses mktemp -d scratch dir | `head -10 scripts/test-plan-frontmatter.sh` | Confirmed: "Each case writes a plan fixture under a disposable mktemp -d directory" | match |

## File structure

Create:
  - `scripts/test-body-seal.sh` — fixture harness for check 14 (disposable mktemp -d, same pattern as test-plan-frontmatter.sh)
Modify:
  - `schemas/plan-schema.md` — body_seal field, Mutable slots update
  - `scripts/validate.sh` — check 14 body-seal verification
  - `skills/planning/SKILL.md` — step 10 outward-publication, step 17 seal at approval
  - `skills/planning/references/deepening.md` — section 6 re-seal instruction for interactive mode
  - `skills/implementing/SKILL.md` — preflight item 2.5 immutability check
  - `skills/reviewing/SKILL.md` — Requirements Completeness extension
  - `CONCEPTS.md` — body seal, outward-publication boundary
  - `ROADMAP.md` — P2 row disposition

## Scenario coverage map

| S-ID | Unit chain | Verification |
|---|---|---|
| S1 (implementing preflight detects damage) | U4 | Judgment: reviewer confirms preflight names seal check, stop condition, remediation |
| S2 (validate.sh catches unsealed mutation) | U2 | Fixture: wrong body_seal → FAIL (test-body-seal.sh) |
| S3 (planning seals at approval) | U3 | Judgment: reviewer confirms step 17 prescribes seal computation at approval |
| S4 (interactive deepening re-seals) | U3 | Judgment: reviewer confirms deepening.md §6 names re-seal in same commit |
| S5 (outward-publication triggers matrix) | U3 | Judgment: reviewer confirms step 10 names outward-publication boundary |
| S6 (outward publication without matrix caught by review) | U5 | Judgment: reviewer confirms reviewing covers outward-publication recognition error |
| S7 (existing corpus passes) | U2 | Fixture: plan without body_seal → PASS skip (test-body-seal.sh); Covers S7 |
| S8 (terminal-state flip no mismatch) | U2 | Fixture: correct body_seal + mutable-slot-only change → PASS |

No stateful ceremony in the deliverable; no mutation/failure-state matrix required.

## Carry-forward trigger audit

Audited ROADMAP.md at `a039696`: 6 open carry-forward rows, 1 fired, 0 unobservable.

Open carry-forward triggers vs this plan's files:
- "Clean-environment Codex install check" — event-based (first external install), not fired
- "Interview protocol vocabulary gaps" — event-based (first real retro), not fired
- "Python 3.8 guard for validate-frontmatter.py" — edit-based on `validate-frontmatter.py` / `python-support.json`, not fired (this plan edits validate.sh, not validate-frontmatter.py)
- "Reserved designing cycle (P2)" — edit-based (next cycle crossing outward-publication boundary or first post-approval in-place edit). Fired by direct user request, not by its stated trigger — the P2 item was reserved for a designing cycle and explicitly requested. Disposition: fold-as-unit (U6), close as Done.
- "`execution: ops`" — event-based, not fired
- "Release headless-path non-authorization marker" — event-based, not fired

Audited ROADMAP.md at a039696: 6 open rows, 1 fired, 0 unobservable.

## U1: schemas/plan-schema.md + CONCEPTS.md — define body_seal and vocabulary
Execution note: skip-test-first (schema contract; U2's fixtures test the field)
Files:
  Modify: schemas/plan-schema.md, CONCEPTS.md
Steps:
  1. In `schemas/plan-schema.md` frontmatter block, add `body_seal` as optional field after `deepened`:
     ```yaml
     body_seal: <64-char lowercase hex SHA-256>  # optional; set at approval, verified by validate.sh check 14
     ```
  2. Update the "Mutable slots" line to include `body_seal` alongside status and terminal-state evidence: "the `status` field, its terminal-state evidence field, and `body_seal` are the plan's only mutable slots"
  3. Add a "Body seal" subsection after "Status lifecycle" explaining: computation input (after second `---`, through EOF), hash algorithm (SHA-256 lowercase hex), set at approval, re-sealable only by interactive deepening, absence is valid
  4. In `CONCEPTS.md` under "## Release ceremony" (not Plan lifecycle), add the following two entries. The working tree already has drafts under "## Plan lifecycle" — move "Body seal" and "Outward-publication boundary" to "## Release ceremony" where `Prepare-only` and `Deviation addendum` live:
     - **Body seal** — the SHA-256 hex digest of a plan's markdown body (after the closing frontmatter delimiter), stored in the frontmatter at approval. Proves body-matches-last-seal; does not prove unchanged-since-approval. A mutator that re-seals defeats the mechanical check — the cross-cutting skill rules are the defense against unauthorized re-sealing; interactive deepening is the sole authorized re-seal path.
     - **Outward-publication boundary** — any action that makes an artifact accessible outside the local repository's default branch: pushing to a remote, creating a remote repository, publishing to a registry, creating a platform release, changing repository visibility. A deliverable crossing this boundary constitutes a stateful ceremony and requires a mutation/failure-state matrix.
  5. Commit: "fix(schema): Add body_seal field and outward-publication boundary to plan-schema and CONCEPTS"
Acceptance: `grep -c "body_seal" schemas/plan-schema.md` → 3+; `grep -c "Body seal\|Outward-publication boundary" CONCEPTS.md` → 2+

## U2: validate.sh check 14 + test harness — body-seal verification
Execution note: test-first
Files:
  Modify: scripts/validate.sh
  Create: scripts/test-body-seal.sh
Interfaces:
  Consumes: plan files in docs/plans/*.md with optional body_seal frontmatter field
  Produces: ok/FAIL lines tagged `[body-seal]`
Test scenarios:
  happy: fixture plan with correct body_seal → ok line, exit 0
  edge: fixture plan without body_seal field → ok skip line, exit 0
  error: fixture plan with wrong body_seal (body modified after seal) → FAIL line naming path and mismatch, exit 1
  integration: existing plan corpus (all docs/plans/*.md, no body_seal) all skip → Covers S7
Steps:
  1. Create `scripts/test-body-seal.sh` following the `test-plan-frontmatter.sh` pattern:
     - `setup_dir()` creates a disposable `mktemp -d` with `docs/plans/` inside
     - Fixture A: write a plan with correct body_seal (compute SHA-256 of body, store in frontmatter) → run validate.sh in scratch dir → assert exit 0 and `[body-seal]` ok line
     - Fixture B: write a plan with wrong body_seal (compute SHA-256, then append text to body) → run validate.sh in scratch dir → assert exit 1 and `[body-seal] FAIL` line
     - Fixture C: write a plan without body_seal → run validate.sh in scratch dir → assert exit 0 and `[body-seal]` skip line
     - Clean up scratch dirs
  2. Write check 14 in `scripts/validate.sh` as a Python heredoc after check 13:
     - `# 14. Plan corpus: body-seal integrity`
     - TAG = "[body-seal]"
     - Iterate `docs/plans/*.md`
     - For each file: read content, split on `---` to extract frontmatter and body
     - If frontmatter has no `body_seal` key: print ok skip, continue
     - If present: extract body (everything after second `---`), compute `hashlib.sha256(body.encode()).hexdigest()`, compare to stored value
     - Mismatch → `FAIL: {TAG} {path}: body_seal mismatch expected={stored} actual={computed}`
     - Match → `ok: {TAG} {path}: body_seal verified`
  3. Run `bash scripts/test-body-seal.sh` → all 3 fixtures pass
  4. Run `bash scripts/validate.sh` → ALL CHECKS PASSED (existing corpus + this plan have no body_seal → all skip)
  5. Commit: "feat(validate): Add check 14 body-seal verification with test harness"
Acceptance: `bash scripts/test-body-seal.sh` → 3/3 pass; `bash scripts/validate.sh` → ALL CHECKS PASSED with `[body-seal]` ok lines; boundary interpreter coverage verified by existing `invoke_validation_fixture_repo` flow

## U3: skills/planning/SKILL.md + deepening.md — outward-publication recognition + seal at approval + re-seal carve-out
Execution note: skip-test-first (docs edit; spec SC5/SC3 rubrics are the verification)
Files:
  Modify: skills/planning/SKILL.md, skills/planning/references/deepening.md
Steps:
  1. In `skills/planning/SKILL.md` step 10 (Mutation/failure-state matrix), after the stateful-ceremony definition sentence ("A **stateful ceremony** is a workflow..."), add: "An **outward-publication boundary** — any action that makes an artifact accessible outside the local repository's default branch (pushing to a remote, creating a remote repository, publishing to a registry, creating a GitHub/platform release, changing repository visibility) — constitutes a stateful ceremony. A plan carrying the stateless fallback whose units include any of these transitions has a recognition error."
  2. In `skills/planning/SKILL.md` step 17 (Commit the plan), after the `status: approved` flip instruction ("only after they approve it, commit again — same file, `status: approved` only"), add: "In the same commit as the `status: approved` flip, compute the SHA-256 of the plan body (everything after the second `---` line, through EOF) and write `body_seal: <hex>` to the frontmatter. Run the validator on the sealed file."
  3. In `skills/planning/references/deepening.md` section 6 (Change discipline), add a bullet: "When deepening an already-approved plan (interactive mode), recompute the body SHA-256 and write a new `body_seal` in the same commit as the body changes — this is the sole authorized re-seal path. No other editing path may update `body_seal` after the initial approval."
  4. Commit: "feat(planning): Add outward-publication recognition, body-seal at approval, and deepening re-seal"
Acceptance: `grep -c "outward-publication boundary" skills/planning/SKILL.md` → 1+; `grep -c "body_seal" skills/planning/SKILL.md` → 1+; `grep -c "body_seal\|re-seal" skills/planning/references/deepening.md` → 1+

## U4: skills/implementing/SKILL.md — preflight immutability check
Execution note: skip-test-first (docs edit; spec SC6 rubric is the verification)
Files:
  Modify: skills/implementing/SKILL.md
Steps:
  1. After preflight item 2 (status check, line 17) and before item 3 (contradiction scan, line 18), insert a new paragraph as item 2.5: "**Body-seal check**: if the plan has a `body_seal` field, verify the current body matches it. Extract the body (everything after the second `---` line, through EOF), compute its SHA-256, and compare to the stored seal. Mismatch → stop with a named violation: report the plan path, expected vs actual hash, and direct to either a deviation addendum under `docs/deviations/` or a byte-exact revert. Only interactive deepening may re-seal an approved plan."
  2. Commit: "feat(implementing): Add body-seal preflight immutability check"
Acceptance: `grep -c "body_seal\|Body-seal check" skills/implementing/SKILL.md` → 1+

## U5: skills/reviewing/SKILL.md — immutability + outward-publication in review
Execution note: skip-test-first (docs edit; spec SC5/SC6 rubrics are the verification)
Files:
  Modify: skills/reviewing/SKILL.md
Steps:
  1. After the Requirements Completeness rule (line 86), add: "Plan-body immutability rule: a plan whose body has been modified post-approval — detected by body_seal mismatch, body diff against the approved commit, or an unauthorized re-seal (any re-seal not performed by interactive deepening) — is an actionable finding that blocks `clean`. Only interactive deepening is an authorized re-seal path."
  2. After or within the Stateful ceremony evidence gate (line 88), add: "Outward-publication recognition check: a plan carrying the stateless fallback ('No stateful ceremony') whose units include outward-publication transitions (push to remote, create remote repository, publish to registry, create platform release, change visibility) has a matrix-requirement gap that blocks `clean`."
  3. Commit: "feat(reviewing): Add body-immutability and outward-publication review rules"
Acceptance: `grep -c "body_seal\|immutability" skills/reviewing/SKILL.md` → 1+; `grep -c "outward-publication" skills/reviewing/SKILL.md` → 1+

## U6: ROADMAP.md — P2 row disposition + new carry-forward
Execution note: skip-test-first (tracker edit)
Files:
  Modify: ROADMAP.md
Steps:
  1. Mark the P2 "Reserved designing cycle" row as Done with the cycle name (post-approval-immutability-and-publication-ceremony). Note: closed by direct user request, not by the stated trigger firing — no deliverable in this cycle crosses an outward-publication boundary; the item was a reserved designing cycle explicitly requested by the user.
  2. Add a new carry-forward row: "Seal check in shipped validator: `validate-plan-frontmatter.py` does not verify body_seal; consuming repos get frontmatter validation but not body-seal enforcement" | origin: this cycle (spec Open Decision 2) | P3 | trigger: "First consuming-repo adoption of plan/v1 with body_seal fields". This row is pre-registered from the Deferred to Follow-Up Work section so retro reconciles rather than re-adding.
  3. Commit: "docs(roadmap): Close P2 row, add shipped-validator carry-forward"
Acceptance: `grep "Reserved designing cycle" ROADMAP.md` shows Done markup; new row present

## Deferred to Follow-Up Work

- Seal check in shipped validator (`validate-plan-frontmatter.py`) — per spec Open Decision 2, deferred to first consuming-repo adoption. Pre-registered in ROADMAP by U6 step 2.
- `body_seal` on spec documents — per spec Open Decision 1, deferred to first post-approval spec body edit
- Adding `validate.sh` to shipping's verification gate — shipping runs the project test suite, not validate.sh; adding it is a separate scope decision

## Open unknowns

### Planning-time (resolved)

None remaining.

### Implementation-time

- Exact Python heredoc indentation and TAG naming for check 14 — resolved at implementation by following check 12/13's pattern in validate.sh
