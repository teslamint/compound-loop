---
schema: plan/v1
title: Require stateful ceremony mutation and failure-state matrices
type: docs
status: approved
date: 2026-07-18
execution: non-code
origin: docs/specs/2026-07-18-stateful-ceremony-failure-matrix-design.md
---

# Implementation Plan: Stateful Ceremony Failure Matrices

## Goal

Require planners to enumerate every durable transition and its success,
forced-failure, rerun, rollback or compensation, headless, and cancellation or
abort outcomes. Require implementers and reviewers to retain and inspect safe
disposable fixture evidence before affected units pass.

## Architecture notes

- **Known Pattern — state-machine deviation**:
  `docs/solutions/workflow-issues/review-introduced-state-machine-deviation.md`
  already contains the compact release prevention matrix and addendum trigger.
  This plan promotes that pattern into planning and review contracts without
  copying the addendum content list.
- **Producer before consumer**: U1 commits the complete worked example first;
  U2 can then link a real reference from planning and the plan schema; U3 carries
  the resulting matrix and evidence into implementation review.
- **Evidence is lifecycle state**: records live under
  `.release-loop/evidence/U<N>/`, beside briefs, reports, and review diffs. They
  remain available through unit and final review without becoming product docs
  or leaking raw fixture output into git.
- **Isolation is proven, not asserted**: each applicable evidence record names
  the disposable fixture root, all configured remotes/endpoints, stub identity,
  and a boundary sentinel before reviewers accept or execute it.
- **Irreversible outcomes use compensation**: a publication, payment, or
  deployment may have no safe rollback. The matrix records repair,
  compensation, or manual recovery rather than claiming history can be erased.
- **Publication stays illustrative**: the example uses a local bare remote and
  stub publication fixture. `skills/release/SKILL.md` remains local-only and is
  not modified.

## Assumption Recheck

Rechecked at `2026-07-18T19:53:16+09:00` on branch
`feat/process-guidance` at commit `79013c2`.

| Approved claim | Fresh command evidence | Outcome |
|---|---|---|
| The carry-forward row remains open. | `rg -n "Mutation/failure-state matrix" ROADMAP.md` returned the P2 row at line 40. | match |
| Existing solution guidance has a compact prevention matrix but not the full outcome-column contract. | `sed -n '154,170p' docs/solutions/workflow-issues/review-introduced-state-machine-deviation.md` again showed three columns plus prose asking for headless, cancellation, rerun, and rollback outcomes. | match |
| Planning, implementing, and reviewing still lack the item 2 rule. | `rg -n "Mutation/failure-state matrix|retained fixture evidence|durable transition" skills/planning/SKILL.md schemas/plan-schema.md skills/implementing/SKILL.md skills/reviewing/SKILL.md` returned no matches. | match |
| Release contains the local commit → verify → tag state model used by the example. | `sed -n '416,452p' skills/release/SKILL.md` showed release commit creation, pre-tag verification, annotated tag creation, tag-only verification, and their failure states. | match |
| Release remains local-only. | `sed -n '8,12p' skills/release/SKILL.md` stated that it never pushes or creates a GitHub release. | match |
| `.release-loop/` has brief, report, and review paths but no evidence path. | `rg -n "release-loop/(briefs|reports|reviews|evidence)" skills/implementing/SKILL.md` returned the first three and no evidence path. | match |

No contradiction or unavailable result exists, so no new deviation addendum is
required before this plan is finalized.

## Mutation/failure-state matrix

This implementation changes lifecycle guidance and a committed example only;
its deliverable behavior does not execute a product or operational ceremony and
introduces no durable runtime transition. The units therefore use the explicit
fallback: **no stateful ceremony in the deliverable; no mutation/failure-state
matrix is required for this plan's own execution.** U1 authors the reusable
matrix that future stateful plans must apply.

## File structure

- `skills/planning/references/stateful-ceremony-matrix-example.md` — complete
  release commit → verify → tag and publication-state worked example.
- `skills/planning/SKILL.md` — stateful-ceremony detection, matrix authoring,
  applicability, and self-review rules.
- `schemas/plan-schema.md` — conditional hard-floor matrix section and explicit
  stateless fallback.
- `skills/implementing/SKILL.md` — evidence-record production plus task/final
  review handoff paths.
- `skills/reviewing/SKILL.md` — matrix/evidence completeness, isolation, failure
  mechanism, and post-state verification before clean verdicts.

## Scenario coverage map

| Scenario | Unit chain | Observable verification |
|---|---|---|
| S1 — planner maps a stateful ceremony | U1 → U2 | A reader classifies the worked release flow as stateful and fills every transition row and all six outcome columns using the planning rule. |
| S2 — implementer proves failure behavior safely | U2 → U3 | A reader follows implementing guidance to retain a forced-failure record with fixture identity, isolation proof, injection, exit status, post-state, mechanism check, and next-invocation result. |
| S3 — unit reviewer verifies the matrix | U2 → U3 | A reviewer rejects a missing cell, unsafe target, unrelated failure mechanism, unexpected post-state, or absent applicable evidence before returning clean. |
| S4 — release planner covers local and outward states | U1 | The committed example walks release commit, pre-tag verification, annotated tag, partial commit/tag publication, and release-page publication with all six outcomes. |

## Global constraints

- Do not modify or remove either ROADMAP carry-forward row.
- Do not modify `skills/release/SKILL.md` or implement outward publication.
- Do not execute a forced failure against a real default branch, remote,
  publication, payment, deployment, or production system.
- Use only disposable local fixtures, local bare remotes, and stub publication
  endpoints in the worked example.
- Retained evidence must be concise and sanitized; never store credentials,
  personal data, or unbounded raw output.
- Run `bash scripts/validate.sh` before and after every commit that changes a
  file under `skills/` or `schemas/`.
- Never inline-backtick a concrete terminal-signal instantiation in a consumer
  skill; use only canonical placeholder forms if a signal must be mentioned.
- Preserve item 1's approved-artifact and deviation-addendum rules.
- Do not push.

## Implementation Units

## U1: Commit the stateful release and publication matrix example
Files:
  Create/Modify: `skills/planning/references/stateful-ceremony-matrix-example.md`
Steps:
  1. Define the example's safety boundary: disposable repository, local bare remote, stub publication endpoint, no credentials, and a boundary sentinel proving no real target is reachable.
  2. Add five rows for release commit creation, pre-tag verification, annotated tag plus tag-only verification, commit/tag publication including partial push, and release-page publication plus post-publication verification.
  3. Give every row six explicit outcomes: success, forced failure with expected post-state, rerun/idempotency, rollback or compensation, headless, and cancellation or abort; use a concrete not-applicable reason instead of a blank cell.
  4. For each forced failure, name the intended injection boundary and the retained evidence fields that distinguish it from an unrelated setup or validator failure.
  5. Self-review against S4, all six outcome classes, irreversible-publication compensation, and the no-real-outward-action boundary; run `bash scripts/validate.sh`.
  6. Commit with a docs-scoped conventional message, then rerun `bash scripts/validate.sh` against the committed tree.
Acceptance: the file contains five transition rows, six filled outcome columns per row, isolation proof requirements, local/stub fixture instructions, and no real push/publication command; `bash scripts/validate.sh` exits 0 before and after commit.

## U2: Require the matrix during planning
Files:
  Create/Modify: `skills/planning/SKILL.md`, `schemas/plan-schema.md`
Steps:
  1. Define stateful ceremony and durable transition using the approved spec's observable-side-effect boundary.
  2. Add a conditional Mutation/failure-state matrix section that requires transition identity, pre/action/post state, and all six outcome columns for every durable transition; require a concrete reason for not-applicable cells.
  3. Add the exact stateless fallback to the plan schema and require each stateful row to map to the unit that produces its fixture evidence.
  4. Link `skills/planning/references/stateful-ceremony-matrix-example.md` and the existing deviation solution; state that a post-approval row/outcome change triggers item 1's addendum rule.
  5. Extend planning self-review to walk completeness, irreversibility, safe failure injection, and unit/evidence ownership; run `bash scripts/validate.sh`.
  6. Commit with a docs-scoped conventional message, then rerun `bash scripts/validate.sh` against the committed tree.
Acceptance: planning and schema contain the trigger, fallback, six outcome classes, no-blank rule, unit/evidence mapping, and links to both existing authorities; `bash scripts/validate.sh` exits 0 before and after commit.

## U3: Retain and review disposable fixture evidence
Files:
  Create/Modify: `skills/implementing/SKILL.md`, `skills/reviewing/SKILL.md`
Steps:
  1. Require affected units to write one sanitized record per applicable matrix cell under `.release-loop/evidence/U<N>/<transition-id>-<outcome>.md` before task review.
  2. Require each record to contain plan/row identity, source commit, fixture identity, timestamp, isolation proof, pre-state, exact injection/command, exit status, concise output, post-state, relevant next-invocation result, and mechanism check.
  3. Pass the plan matrix and unit evidence directory to task review, and accumulated evidence directories to final branch review; keep stateless units on the explicit no-evidence fallback.
  4. Make reviewing keep a finding actionable and prevent clean when an applicable cell/evidence record is missing, isolation is unproved, a real target is possible, the wrong mechanism failed, or observed state/rerun/recovery differs from the plan.
  5. Require review to treat an approved-matrix row/outcome change as an observable deviation under item 1; run targeted searches and `bash scripts/validate.sh`.
  6. Commit with a docs-scoped conventional message, then rerun `bash scripts/validate.sh` against the committed tree.
Acceptance: implementing and reviewing name the evidence path, complete record fields, task/final handoffs, stateless fallback, isolation and mechanism gates, and deviation trigger; `bash scripts/validate.sh` exits 0 before and after commit.

## Deferred to Follow-Up Work

- A machine-readable matrix schema and automated completeness validator.
- Outward publication automation for `release`; this item supplies only the
  planning example for a future separately approved feature.
- ROADMAP row removal, owned by the next retro's carry-forward reconciliation.

## Open unknowns

- **Planning-time**: none. The approved spec resolves cancellation, isolation,
  irreversible compensation, evidence location, and publication-example scope.
- **Implementation-time**: exact prose insertion points in the three lifecycle
  skills may shift during editing; the file and handoff contracts are fixed.
