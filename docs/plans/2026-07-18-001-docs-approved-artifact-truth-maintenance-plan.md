---
schema: plan/v1
title: Add approved-artifact truth-maintenance guidance
type: docs
status: approved
date: 2026-07-18
execution: non-code
origin: docs/specs/2026-07-18-approved-artifact-truth-maintenance-design.md
---

# Implementation Plan: Approved-Artifact Truth Maintenance

## Goal

Make live-assumption evidence durable from design through planning, and make a
committed deviation addendum a prerequisite for accepting post-approval
observable behavior drift. Preserve approved specs and plans as historical
records and reuse the existing generalized deviation guidance.

## Architecture notes

- **Known Pattern — empirical grounding**:
  `docs/solutions/workflow-issues/spec-review-empirical-grounding-gap.md`
  already requires live verification of named examples. U1 extends that rule
  from one-off examples to a retained evidence record for live assumptions.
- **Known Pattern — deviation addenda**:
  `docs/solutions/workflow-issues/review-introduced-state-machine-deviation.md`
  already owns the addendum content contract, trigger examples, and
  incomplete-release recovery example. U2 and U3 link to it rather than
  restating its seven-part list.
- **Historical and operational truth remain separate**: approved specs and
  plans are never edited to erase a later contradiction. A committed artifact
  under `docs/deviations/YYYY-MM-DD-<topic>-NNN.md` records the operational
  change.
- **No new generic human gate**: contradictions block plan finalization and
  commit. The first-hand plan approval requested for this dogfood run is an
  execution constraint for this session, not a permanent change to
  `planning`'s gate model.
- **Item 2 stays separate**: this plan does not define a matrix schema or a
  retained forced-failure fixture protocol. It only preserves the existing
  solution's statement that an addendum names verification changes.
- **Post-approval deviation**: external plan review restored standing feedback
  from commit `a8a1318`: every spec needs an Assumptions and Preconditions
  section even when it has no live assumptions. The approved spec made only the
  evidence table conditional, so
  `docs/deviations/2026-07-18-approved-artifact-truth-maintenance-001.md`
  records the expanded observable contract without rewriting the spec.

## Assumption Recheck

Rechecked at `2026-07-18T18:55:58+09:00` on branch
`feat/process-guidance` at commit `fd9e211`.

| Approved claim | Fresh command evidence | Outcome |
|---|---|---|
| The carry-forward row is open. | `rg -n "Approved-artifact truth maintenance" ROADMAP.md` returned the P2 row at line 39. | match |
| Existing generalized guidance defines addendum contents and triggers. | `rg -n "A useful addendum contains|Require a deviation addendum" docs/solutions/workflow-issues/review-introduced-state-machine-deviation.md` returned lines 63 and 109. | match |
| Designing lacks a structured retained evidence record for every live assumption. | `rg -n "Empirical grounding|Assumptions and Preconditions|timestamp|evidence source" skills/designing/SKILL.md skills/designing/references/spec-template.md` returned only the empirical-grounding rule. | match |
| Planning lacks live-assumption recheck and contradiction-addendum rules. | `rg -n "live assumption|recheck|deviation addendum" skills/planning/SKILL.md schemas/plan-schema.md` returned no matches. | match |
| Implementation review lacks a committed-addendum prerequisite. | `rg -n "Plan-mandated conflicts|deviation addendum" skills/implementing/SKILL.md skills/reviewing/SKILL.md` returned only the existing plan-conflict rule. | match |
| Incomplete-release recovery is a real post-approval deviation. | The retained `sed` commands from the spec again showed direct commit-to-tag approved behavior and the solution's review-discovered untagged-release state. | match |

No live-assumption recheck produced a contradiction or unavailable result.
External plan review did introduce the always-present section behavior absent
from the approved spec, so deviation addendum 001 is required and committed
before this plan is finalized.

## File structure

- `skills/designing/SKILL.md` — require retained live-assumption evidence during
  design and empirical review.
- `skills/designing/references/spec-template.md` — give specs the exact evidence
  record shape and safe-retention boundary.
- `skills/planning/SKILL.md` — rerun retained commands, classify outcomes, and
  route contradictions to a committed addendum before plan finalization.
- `schemas/plan-schema.md` — make Assumption Recheck a durable plan section with
  a zero-assumption fallback.
- `skills/implementing/SKILL.md` — add the unit/final-review handoff prerequisite
  and pass the full approved artifact set to reviewers.
- `skills/reviewing/SKILL.md` — include deviation addenda in requirements
  completeness and prevent `clean` when confirmed observable drift lacks one.

## Scenario coverage map

| Scenario | Unit chain | Observable verification |
|---|---|---|
| S1 — designer makes a live assumption | U1 | A reader following `designing` and the spec template always encounters Assumptions and Preconditions, then creates a sanitized evidence row with claim, command, observation time, result, and source when live assumptions exist. |
| S2 — planner finds reality changed | U1 → U2 | A reviewer walks one match, one contradiction, one unavailable result, and the no-origin/zero-assumption fallback through the planning rules. |
| S3 — review discovers necessary observable behavior | U2 → U3 | The existing incomplete-release recovery example is classified as addendum-required before unit or branch acceptance. |
| S4 — internal refactor stays lightweight | U3 | The reviewing rule exempts a change that preserves interfaces, state transitions, persistence, consent boundaries, and terminal behavior. |

## Global constraints

- Do not modify or remove either ROADMAP carry-forward row.
- Do not define item 2's matrix schema or retained forced-failure fixture
  protocol in item 1.
- Do not duplicate the seven-part addendum guidance; link to
  `docs/solutions/workflow-issues/review-introduced-state-machine-deviation.md`.
- Do not commit secrets, credentials, personal data, or unbounded command
  output as assumption evidence.
- Run `bash scripts/validate.sh` before and after every commit that changes a
  file under `skills/` or `schemas/`.
- Never inline-backtick a concrete terminal-signal instantiation in a consumer
  skill; use only canonical placeholder forms if a signal must be mentioned.
- Do not push.

## Implementation Units

## U1: Retain live-assumption evidence in design artifacts
Files:
  Create/Modify: `skills/designing/SKILL.md`, `skills/designing/references/spec-template.md`
Steps:
  1. Add a Live assumption evidence rule to `skills/designing/SKILL.md` that requires claim, exact command, observation timestamp, concise result, and evidence source for each live assumption.
  2. Require empirical review to rerun or inspect the retained command and forbid secrets, personal data, and unbounded raw output in committed evidence.
  3. Make the Assumptions and Preconditions section mandatory in `skills/designing/references/spec-template.md`, require an explicit none-fallback when no live assumptions exist, and make only the five-field evidence table conditional on live assumptions.
  4. Self-review against spec S1, the Assumptions and Preconditions contract, and the no-live-assumption case; run `bash scripts/validate.sh`.
  5. Commit with a docs-scoped conventional message, then rerun `bash scripts/validate.sh` against the committed tree.
Acceptance: targeted search finds the always-present section rule, explicit none-fallback, five evidence fields, and safe-retention boundary; `bash scripts/validate.sh` exits 0 before and after commit.

## U2: Recheck approved assumptions during planning
Files:
  Create/Modify: `skills/planning/SKILL.md`, `schemas/plan-schema.md`
Steps:
  1. Add planning guidance that reruns every retained live-assumption command from an origin spec and records match, contradiction, or unavailable.
  2. Make contradiction block plan finalization and commit until a separate committed addendum exists under `docs/deviations/`; keep unavailable evidence as a planning-time unknown unless the user narrows the claim.
  3. Add Assumption Recheck to the plan schema, including explicit no-origin and zero-retained-assumption text, and link the existing solution as the addendum content authority.
  4. Self-review match, contradiction, unavailable, no-origin, and zero-assumption flows against S2; run `bash scripts/validate.sh`.
  5. Commit with a docs-scoped conventional message, then rerun `bash scripts/validate.sh` against the committed tree.
Acceptance: a reviewer can walk all five flows without inventing a gate or rewriting an approved artifact; `bash scripts/validate.sh` exits 0 before and after commit.

## U3: Gate observable deviations at implementation review
Files:
  Create/Modify: `skills/implementing/SKILL.md`, `skills/reviewing/SKILL.md`
Steps:
  1. Extend implementing's task and final-review handoffs to pass the approved spec, plan, referenced addenda, and current diff as one artifact set.
  2. Require a committed deviation addendum before accepting confirmed observable behavior absent from or contradictory to the approved artifacts; preserve the existing human decision rule for plan-mandated conflicts.
  3. Extend reviewing's Requirements Completeness context so a missing addendum for confirmed observable drift remains actionable and prevents a clean verdict.
  4. Link the existing solution for the observable-behavior definition, addendum contents, incomplete-release worked example, and internal-refactor exemption instead of copying them.
  5. Self-review S3 and S4, run targeted searches, and run `bash scripts/validate.sh`.
  6. Commit with a docs-scoped conventional message, then rerun `bash scripts/validate.sh` against the committed tree.
Acceptance: the incomplete-release example requires an addendum, the internal-refactor example does not, both handoffs name the full artifact set, and `bash scripts/validate.sh` exits 0 before and after commit.

## Deferred to Follow-Up Work

- ROADMAP item 2: the mutation/failure-state matrix and retained disposable
  evidence protocol, executed immediately after item 1 completes its review.
- ROADMAP row removal, owned by the next retro's carry-forward reconciliation.
- A machine-readable deviation schema or validator; the current requirement is
  a committed Markdown artifact following existing generalized guidance.

## Open unknowns

- **Planning-time**: none. The first-hand spec gate settled the only scope fork
  by keeping item 2 separate.
- **Implementation-time**: exact insertion points within each skill may shift
  during editing, but the named producer/consumer contracts and files are fixed.
