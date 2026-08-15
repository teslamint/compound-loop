---
schema: plan/v1
title: Make the planning schema portable and verify body_seal values
type: fix
status: draft
date: 2026-08-14
execution: code
origin: docs/specs/2026-08-14-schema-reference-and-seal-verification-design.md
---

# Goal

Make the planning skill self-contained, preserve standalone behavior in its three external plan consumers, and make the shipped validator verify canonical `body_seal` values. Preserve every unrelated validator and skill behavior.

# Architecture notes

- `skills/planning/schemas/plan-schema.md` becomes the only full plan-schema SSOT. The repository-root copy is removed.
- Planning resolves schema references from its skill root. External consumers inline only the fields and invariants they execute; the sibling planning schema is optional context.
- `compute_body_seal(text: str) -> str` is the sole shipped-validator digest function. It uses UTF-8 text read with universal-newline translation, `text.split('---', 2)[2]`, UTF-8 encoding, and SHA-256 lowercase hexadecimal.
- The validator and repository check 14 remain behaviorally identical for seal format, absence, correct value, and mismatch. No delimiter guard or new line-ending rule is introduced.
- Existing validator changes on this branch were written before approval. Treat them as an untrusted candidate diff: tests introduced by U3 must fail against that candidate before implementation, then the unit removes or rewrites every change not required by this plan.
- Commit-capable implementation workers receive `SSH_AUTH_SOCK`; after every unit commit the orchestrator records `git log -1 --format=%G?` and treats `N` or an empty signature status as a unit concern rather than silently claiming the signed-commit convention held.
- Dependency-safe execution order is `U2 → U1 → U3 → U4`: external consumers stop requiring the repository-root schema before U1 removes it.

# Assumption Recheck

Origin spec retains no live assumptions; no assumption recheck required.

# File structure

## Planning-owned contract and standalone packaging

- Move `schemas/plan-schema.md` to `skills/planning/schemas/plan-schema.md`.
- Modify `skills/planning/SKILL.md` and `skills/planning/references/deepening.md` to use planning-root-local `schemas/plan-schema.md`.
- Modify schema-path consumers in `scripts/validate.sh`.
- Modify `scripts/test-plugin-skill-discovery.sh` and create `scripts/test-planning-schema-portability.sh` for the standalone planning fixture.

## External consumer subsets

- Modify `skills/implementing/SKILL.md` with approved-only eligibility, unit handoff fields, execution-mode selection, seal/history checks, and the adoption-migration exception.
- Modify `skills/release-loop/SKILL.md` with the `--skip-plan` minimum contract and validator fallback.
- Modify `skills/retrospective/SKILL.md` with origin, applicability, and frontmatter-only terminal transition rules.
- Create `scripts/test-plan-consumer-portability.sh` to validate standalone consumer contract coverage without a sibling planning skill.

## Shipped seal verification

- Modify `skills/planning/scripts/validate-plan-frontmatter.py` with canonical value verification and strict CLI argument/error behavior.
- Modify `scripts/test-plan-frontmatter.sh` with shipped-validator seal and CLI cases while preserving all existing cases.

## Parity, migration, and review enforcement

- Modify `scripts/validate.sh` check 14 only for the moved schema path and parity integration required by the approved spec.
- Modify `scripts/test-body-seal.sh` with validator/check-14 parity and adoption-migration fixtures.
- Modify `skills/planning/schemas/plan-schema.md` with the complete creation, verification, tamper-evidence, and migration contract.
- Modify `skills/reviewing/SKILL.md` to recognize the baseline-proven adoption migration as the only seal-only exception to deepening.
- Defer the current CHANGELOG entry to Shipping per the planning workflow's anti-expansion rule.

Historical plans, specs, retrospectives, reviews, solution documents, and prior CHANGELOG sections that cite `schemas/plan-schema.md` remain unchanged as historical evidence.

# Scenario coverage map

| Scenario | Ordered unit chain | Walking evidence |
|---|---|---|
| S1 Standalone planning skill | U1 → U3 → U4 | `scripts/test-planning-schema-portability.sh`: copy only planning, resolve schema, print seal, validate sealed plan — Covers S1 |
| S2 Standalone consumer skill | U2 → U4 | `scripts/test-plan-consumer-portability.sh`: implementing, release-loop, and retrospective base branches plus implementing adoption-migration branches run without planning sibling — Covers S2 |
| S3 Existing sealed plan migration | U2 → U1 → U3 → U4 | `scripts/test-body-seal.sh` and `scripts/test-plan-consumer-portability.sh`: unchanged-baseline migration accepted; changed-body migration rejected — Covers S3 |

# Implementation Units

## U1: Relocate the schema SSOT and prove planning portability

Execution note: test-first

Files:
  Create: `skills/planning/schemas/plan-schema.md`, `scripts/test-planning-schema-portability.sh`
  Modify: `skills/planning/SKILL.md`, `skills/planning/references/deepening.md`, `scripts/validate.sh`, `scripts/test-plugin-skill-discovery.sh`
  Delete: `schemas/plan-schema.md`
  Test: `scripts/test-planning-schema-portability.sh`, `scripts/test-plugin-skill-discovery.sh`, `scripts/validate.sh`

Interfaces:
  Consumes: U2's non-load-bearing external consumers; existing `plan/v1` schema contents; planning-root-relative path `schemas/plan-schema.md`
  Produces: one canonical file at `skills/planning/schemas/plan-schema.md`; repository validation using `skills/planning/schemas/plan-schema.md`; standalone planning artifact with no repository-root dependency; active-path allowlist covering planning SKILL, deepening reference, planning validator, three external consumers, and `scripts/validate.sh`

Test scenarios:
  happy: a temporary copy containing only `skills/planning/` resolves `schemas/plan-schema.md` and the validator script
  edge: repository validation reads the moved schema for hard-floor numbering and reference checks
  error: removing the local schema from the temporary planning copy causes a named portability failure
  integration: the standalone planning copy creates a draft fixture and locates every planning-local schema reference — Covers S1

Steps:
  1. Write `scripts/test-planning-schema-portability.sh` with an explicit inventory of every backticked planning-local file reference and an active-path allowlist for the current schema consumers. Extend plugin discovery so a planning-only copy fails because `skills/planning/schemas/plan-schema.md` is absent.
  2. Run `bash scripts/test-planning-schema-portability.sh` and `bash scripts/test-plugin-skill-discovery.sh`; confirm failure names the missing planning-local schema and each unresolved inventory entry.
  3. Move the schema without changing its contents; update planning-local references and every live `scripts/validate.sh` schema path. The allowlist rejects old-path use in active consumers and deliberately excludes historical evidence documents.
  4. Run `bash scripts/test-planning-schema-portability.sh`, `bash scripts/test-plugin-skill-discovery.sh`, and `bash scripts/validate.sh`; confirm the standalone and full-checkout paths pass.
  5. Before dispatching a commit-capable worker, pass the orchestrator's `SSH_AUTH_SOCK`. Commit `fix(planning): Move plan schema into planning skill`, then run `git log -1 --format=%G?`. `N` or an empty result returns `DONE_WITH_CONCERNS` and blocks unit completion until a signed replacement or explicit user exception is recorded.

Acceptance: exactly one full `plan-schema.md` exists in active contract paths; the explicit inventory resolves inside a planning-only copy; the active allowlist contains no stale schema path; `bash scripts/validate.sh` passes; the unit report records a non-`N`, non-empty commit signature result or an explicit user exception.

## U2: Inline load-bearing contracts in standalone consumers

Execution note: test-first

Files:
  Create: `scripts/test-plan-consumer-portability.sh`
  Modify: `skills/implementing/SKILL.md`, `skills/release-loop/SKILL.md`, `skills/retrospective/SKILL.md`
  Test: `scripts/test-plan-consumer-portability.sh`

Interfaces:
  Consumes: `plan/v1` required fields; statuses `draft | approved | done | superseded`; execution values; `origin`; `completed_by`; canonical seal algorithm from the approved spec; U1 consumes this unit's non-load-bearing external consumers before removing the root schema
  Produces: implementing approved-only and unit-dispatch subset; release-loop `--skip-plan` minimum validator/fallback; retrospective frontmatter-only terminal transition subset; shared-literal drift check that reads `skills/planning/schemas/plan-schema.md` when present and otherwise the pre-move `schemas/plan-schema.md`

Decision branch matrix:

| Consumer | Branches and expected result |
|---|---|
| implementing | schema `plan/v1` proceeds; missing/unknown schema rejects; `approved` proceeds; `draft` rejects pending approval; `done` rejects naming `completed_by` or its missing-evidence violation; `superseded` rejects naming `superseded_by`; missing/unknown status rejects; correct seal proceeds; malformed/mismatch rejects with stored/computed values; never-sealed proceeds; removed seal rejects; every post-approval reseal requires interactive deepening until U4 adds the tested adoption exception; code/non-code selects the existing matching unit flow |
| release-loop | each missing required field rejects by field name; `plan/v1`+`approved` proceeds; unknown schema or non-approved status rejects; available sibling validator must exit 0; absent sibling uses the local minimum-field fallback |
| retrospective | repo-relative origin resolves or the existing no-plan fallback applies; post-contract approved plan flips only `status`/`completed_by`; pre-contract/non-approved plan does not flip; missing landed commit rejects; multi-plan coverage applies the same rule to every plan; body or any other frontmatter mutation rejects |

Test scenarios:
  happy: every matrix branch with an accepted result is present in the standalone skill and shared literals match the sibling SSOT when installed
  edge: implementing distinguishes never-sealed history from removed seal; retrospective handles multi-plan and pre-contract cases
  error: independently deleting each required invariant or drifting each shared field/status/seal literal produces a file, consumer, branch, and expected-result diagnostic
  integration: all three copied skills pass every matrix branch with no `skills/planning/` sibling, then pass shared-literal comparison when the sibling is added — Covers S2

Steps:
  1. Write `scripts/test-plan-consumer-portability.sh` from the complete decision branch matrix. Add one positive assertion per branch, one independent deletion mutation per required invariant, and shared-literal comparisons for required fields, statuses, schema version, seal format, and seal extraction against the SSOT. Run it; confirm current load-bearing references and omitted branches fail by consumer and branch.
  2. Update implementing with every implementing matrix branch, full unit handoff fields, code/non-code selection, approval-history seal removal detection, and the default interactive-deepening-only reseal rule. U4 owns the adoption exception after its oracle exists.
  3. Update release-loop with every release-loop matrix branch, sibling-validator preference, and standalone fallback.
  4. Update retrospective with every retrospective matrix branch and strict body/other-frontmatter immutability.
  5. Run `bash scripts/test-plan-consumer-portability.sh`; confirm every positive, deletion, and drift mutation case passes. Pass `SSH_AUTH_SOCK` to the commit-capable worker, commit `fix(skills): Inline standalone plan consumer contracts`, and run `git log -1 --format=%G?`. `N` or empty returns `DONE_WITH_CONCERNS` and blocks completion until a signed replacement or explicit user exception.

Acceptance: every branch matrix row is independently asserted; each shared literal is derived from or compared with the sibling SSOT; standalone copies need no full schema; the unit report records a non-`N`, non-empty signature result or explicit user exception.

## U3: Add canonical seal value verification to the shipped validator

Execution note: test-first

Files:
  Modify: `skills/planning/scripts/validate-plan-frontmatter.py`, `scripts/test-plan-frontmatter.sh`, `scripts/test-planning-schema-portability.sh`
  Test: `scripts/test-plan-frontmatter.sh`, `scripts/test-planning-schema-portability.sh`

Interfaces:
  Consumes: `text` produced by `open(path, encoding="utf-8", newline=None).read()`; optional frontmatter `body_seal`
  Produces: `compute_body_seal(text: str) -> str`; `check_schema(data: dict, repo_root: str, text: str) -> list[str]`; CLI forms `<plan-path>` and `--print-seal <plan-path>` with exits 0 success, 1 content/extraction failure, 2 usage/missing-file failure

Test scenarios:
  happy: correct stored seal validates and `--print-seal` equals an independent Python computation
  edge: CRLF input receives the same digest under universal-newline text semantics; every no-seal fixture preserves pristine exit status, stdout, and stderr byte-for-byte
  error: arbitrary 64-hex seal, one-byte body mutation, malformed seal, impossible extraction, missing print path, extra CLI argument, and a cwd file literally named `--print-seal` produce the specified result
  integration: in a copy containing only `skills/planning/`, create a draft, compute its seal with `--print-seal`, insert that seal with `status: approved`, and validate the sealed plan normally — Covers S1

Steps:
  1. Materialize the pristine validator from commit `86586a0` into the disposable test directory. Add a format-only bypass fixture that passes that pristine validator but must fail the final validator. Dual-run every no-seal fixture through pristine and candidate validators, comparing exit status, stdout, and stderr byte-for-byte.
  2. Add candidate-specific red fixtures for the unapproved delimiter guard, failed extraction returning empty success, and bare `--print-seal` ambiguity when a same-named cwd file exists. Run them against the current candidate and confirm each fails for its named defect; do not expect the already-implemented mismatch check to provide the candidate red state.
  3. Diff the validator against `86586a0`. Restore every unrelated function and diagnostic byte-for-byte; remove the delimiter guard and every line-ending restriction.
  4. Implement `compute_body_seal`, pass text into `check_schema`, compare a valid stored digest, and parse only the two accepted CLI forms. Failed extraction returns exit 1 with stderr; usage errors return exit 2; no failing path succeeds with empty output.
  5. Extend `scripts/test-planning-schema-portability.sh` to execute the planning-only draft → `--print-seal` → approved sealed plan → normal validation round-trip.
  6. Run `bash scripts/test-plan-frontmatter.sh` and `bash scripts/test-planning-schema-portability.sh`. Confirm the standalone round-trip passes, every new case passes, all 26 pristine-passing cases retain byte-identical results, and pre-existing case 20 remains the sole unchanged failure. Pass `SSH_AUTH_SOCK`, commit `fix(planning): Verify body seal values in shipped validator`, and run `git log -1 --format=%G?`; `N` or empty blocks unit completion pending signed replacement or explicit user exception.

Acceptance: the pristine format-only bypass is rejected; planning-only seal print/validation succeeds; candidate-only defects are removed; every no-seal result is byte-identical to `86586a0`; case20 is the sole unchanged pre-existing failure; signature evidence is non-`N`/non-empty or carries explicit user exception.

## U4: Align parity, migration, and seal-history review

Execution note: test-first

Files:
  Modify: `skills/planning/schemas/plan-schema.md`, `skills/implementing/SKILL.md`, `skills/reviewing/SKILL.md`, `scripts/validate.sh`, `scripts/test-body-seal.sh`, `scripts/test-plan-consumer-portability.sh`
  Test: `scripts/test-body-seal.sh`, `scripts/test-plan-consumer-portability.sh`, `scripts/validate.sh`

Interfaces:
  Consumes: U1's moved schema/path contract; U2's default deepening-only implementing rule and consumer harness; U3 `compute_body_seal` behavior; consuming-repository baseline commit; plan path; stored seal; explicit user migration approval
  Produces: complete Body seal guide; validator/check-14 shared fixture parity; executable documented migration comparison; implementing/reviewing exception limited to baseline-proven migration

Parity fixture table:

| Shape | Expected shared verdict |
|---|---|
| correct seal | pass with identical digest |
| absent seal | pass/skip |
| malformed seal | fail format |
| valid-format mismatch | fail with identical computed digest |
| one-byte mutation | fail with identical computed digest |
| CRLF input | same digest after universal-newline read |
| impossible canonical extraction | both implementations fail with the same extraction verdict and asserted diagnostic |

Adoption migration branch matrix:

| Branch | Expected result |
|---|---|
| explicit user approval, named baseline and plan, baseline-identical canonical body, old/new seals, reproduction command | implementing and reviewing allow one adoption reseal |
| changed body or missing baseline | reject with baseline/body diagnostic |
| missing user approval, plan path, seal pair, or reproduction command | reject naming the missing evidence |
| any later ordinary post-adoption reseal | reject unless authorized by interactive deepening |

Test scenarios:
  happy: every parity-table fixture and every currently sealed plan receives the specified shared verdict; complete adoption evidence is allowed once
  edge: unsealed historical plan remains skipped; CRLF digest matches; never-sealed plans remain distinct from removed seals
  error: extraction fails in both implementations; every invalid adoption branch rejects; later ordinary reseal remains actionable
  integration: baseline-identical migration passes the documented oracle, implementing, reviewing, and then both seal validators — Covers S2, Covers S3

Steps:
  1. Extend `scripts/test-body-seal.sh` with the complete parity table, every current plan, and a disposable-git `run_adoption_migration_fixture` implementing the six matrix outcomes below. Extend `scripts/test-plan-consumer-portability.sh` with every adoption branch and one independent evidence-deletion mutation per required field. Run both; confirm extraction parity, adoption branches, and durable-outcome probes fail for missing implementation.
  2. Create a disposable git repository fixture with a committed baseline plan. The schema's marked migration-check Python block accepts `<baseline-commit> <plan-path>`, reads `git show <baseline>:<path>` and the current file using UTF-8/universal-newline semantics, extracts both canonical bodies, exits 0 only when equal, and exits 1 with named changed-body or missing-baseline diagnostics. The test extracts that marked block verbatim and executes it for unchanged, changed, and missing-baseline cases.
  3. Expand the moved schema with exact text-read semantics, a real digest, independent and validator commands, tamper-evidence limits, the marked executable migration check, the baseline-proven exception, and the matrix's fail-closed rerun/compensation rules. Change check 14 so impossible extraction fails with the same verdict as U3 rather than skipping.
  4. Update implementing and reviewing so only a user-approved adoption carrying every matrix field avoids the default unauthorized-reseal finding. Require fresh approval after interruption and preserve interactive deepening as the only later reseal path.
  5. Run `bash scripts/test-body-seal.sh`, `bash scripts/test-plan-consumer-portability.sh`, and `bash scripts/validate.sh`; write exactly six canonical records at `.release-loop/evidence/U4/adoption-reseal-<outcome>.md`. Every record contains plan and matrix-row identity, source commit, fixture identity/timestamp, disposable root, complete configured target inventory, applicable stub identity or a concrete not-applicable reason, boundary sentinel, pre-state, exact command/injection, exit status, concise sanitized output, post-state, relevant next-invocation result, and a mechanism check proving the intended boundary fired. Records may link optional bounded raw `.txt` captures in the same directory. Confirm parity-table, current-corpus, adoption mutation, migration, and all durable outcomes pass. Pass `SSH_AUTH_SOCK`, commit `fix(schema): Document and enforce portable body seals`, and run `git log -1 --format=%G?`; `N` or empty blocks completion pending signed replacement or explicit user exception.

Acceptance: both implementations agree on every parity shape including extraction failure; planning consumers reject every invalid adoption shape; the documented command proves unchanged baseline body; all six `.release-loop/evidence/U4/adoption-reseal-<outcome>.md` records contain the mandatory isolation, transition, next-invocation, and mechanism fields and match the matrix; later ordinary reseals still reject; signature evidence is non-`N`/non-empty or carries explicit user exception.

# Mutation/failure-state matrix

Durable transition: one user-approved adoption changes only `body_seal` and records the migration evidence in a commit. Transition identity is the tuple `(baseline commit, plan path, old seal, new seal)`. The migration operator owns compensation; U4 implements the contract; `scripts/test-body-seal.sh` owns disposable-git evidence under `.release-loop/evidence/U4/`.

| Outcome class | Pre-state | Action or injected boundary | Exact expected durable state | Owning unit | Evidence owner |
|---|---|---|---|---|---|
| success | Clean HEAD at adoption target; canonical baseline/current bodies equal; explicit approval captured | Verify tuple, replace only `body_seal`, commit required R5 fields | HEAD advances once; commit diff contains only the seal line; commit message records the exact tuple, command, and approval; worktree clean | U4 | `scripts/test-body-seal.sh` → `adoption-reseal-success.md` |
| forced failure | Same as success | `run_adoption_migration_fixture` injects failure immediately after the seal write and before commit | HEAD unchanged; worktree has exactly one modified plan and a one-line `body_seal` diff; no migration commit exists | U4 | `scripts/test-body-seal.sh` → `adoption-reseal-forced-failure.md` |
| rerun | Forced-failure state remains | Invoke migration again before compensation, then compensate and retry with fresh approval | First rerun fails closed without another write or commit; after restore and fresh approval, one success commit exists with no duplicate transition | U4 | `scripts/test-body-seal.sh` → `adoption-reseal-rerun.md` |
| rollback or compensation | Forced-failure dirty worktree; HEAD unchanged | Migration operator restores only the target plan to HEAD | Plan bytes and worktree equal pre-transition state; HEAD unchanged; no migration commit | U4 | `scripts/test-body-seal.sh` → `adoption-reseal-compensation.md` |
| headless | Clean pre-state but no first-hand explicit approval | Invoke adoption procedure unattended | Exit nonzero before seal write; HEAD and worktree unchanged; diagnostic names missing approval | U4 | `scripts/test-body-seal.sh` → `adoption-reseal-headless.md` |
| cancellation or abort | Cancellation before write, or after write before commit | Stop before write; for post-write cancellation invoke the same operator-owned compensation | Pre-write cancellation leaves clean state; post-write cancellation first shows the forced-failure state and ends at the compensated clean state; no commit | U4 | `scripts/test-body-seal.sh` → `adoption-reseal-cancellation.md` |

# Carry-forward trigger audit


## Fired triggers

| Tracker row | Trigger class | What fired it | Disposition |
|---|---|---|---|
| Forced-failure matrices can omit exact partial durable state (row 55) | event-based | The adoption exception authorizes a seal mutation and commit across an interruption boundary | Folded into U4 and the mutation/failure-state matrix: all six outcomes have exact git state, executable injection, compensation ownership, and retained evidence |
| Review verifies conformance instead of attacking the claimed invariant (row 59) | event-based | The deliverable is an integrity/verification mechanism | Folded into U3: arbitrary 64-hex digest is the cheapest artifact satisfying the old check while violating the body-integrity intent, and the new test requires rejection |
| Finding severity follows code blast radius rather than threatened criterion (row 60) | event-based | This cycle reviews the seal-verification mechanism | Plan-review mandate: any hole permitting a wrong body to pass seal verification is P1 or higher regardless of diff size |
| Dispatched commit agents lack `SSH_AUTH_SOCK` (row 62) | event-based | Implementing will dispatch commit-capable unit workers | Folded into every unit's local commit step and Acceptance: pass the socket, record `%G?`, and block on `N`/empty unless the user grants an explicit exception |

## Unobservable drift-based triggers

None.

Audited ROADMAP.md at 1ee2875: 9 open rows, 4 fired, 0 unobservable.

Rows 53, 54, 57, 58, and 61 did not fire because this plan has no post-Retro criterion, shipping cleanup change, post-merge loop artifact, interview/review dispatch-contract change, or human-only success criterion.

# Deferred to Follow-Up Work

- Current CHANGELOG entry: Shipping adds the issue #14 summary after the implementation and final review establish the exact shipped behavior, per planning's anti-expansion rule.

# Open unknowns

## Planning-time

None.

## Implementation-time

- The release version containing the migration contract is assigned by Shipping. Migration eligibility is anchored to the consuming repository's explicitly recorded pre-upgrade baseline commit, not to an assumed version number.
- Exact line numbers in moved files are resolved after U1; all unit instructions use structural section/function names rather than stale line numbers.
