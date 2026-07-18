---
title: Approved-Artifact Truth Maintenance
status: draft
date: 2026-07-18
schema: spec/v1
---

# Approved-Artifact Truth Maintenance Design

_Created 2026-07-18._

## Overview

Make live assumptions and post-approval behavior drift auditable without
rewriting the historical artifact that was approved. Designing retains the
evidence behind live claims, planning rechecks those claims, and implementation
review requires a committed deviation addendum before accepting observable
behavior that contradicts or extends the approved contract.

## User Scenarios

### S1: A designer makes a live assumption

A designer claims that a repository or runtime condition is true. The approved
spec retains the claim, exact command, observation timestamp, evidence source,
and result so a zero-context planner can inspect what was verified instead of
trusting the phrase "verified live."

### S2: A planner finds that reality changed

A planner reruns every live-assumption command from the approved spec. When the
result contradicts the approved claim, the planner preserves the spec, commits
a deviation addendum, and references both the original claim and current
evidence before the plan can be finalized and committed.

### S3: Review discovers necessary observable behavior

An implementer or reviewer discovers a required recovery branch, gate, side
effect, terminal outcome, or other user-visible behavior absent from the
approved artifacts. The implementation-review handoff blocks acceptance of
that behavior until a deviation addendum is committed and linked to its
verification evidence.

### S4: An internal refactor stays lightweight

A reviewer confirms that a change preserves interfaces, state transitions,
persistence, consent boundaries, and terminal behavior. No deviation addendum
is required because the approved observable contract did not change.

## Assumptions and Preconditions

These claims were checked against the live repository before this draft was
written.

| Claim | Command | Observed at | Observed result | Evidence source |
|---|---|---|---|---|
| The approved-artifact carry-forward row is still open. | `rg -n "Approved-artifact truth maintenance" ROADMAP.md` | `2026-07-18T18:50:20+09:00` | One open P2 row at `ROADMAP.md:39`. | Working tree at base commit `21eb4db` |
| Existing generalized guidance already defines addendum contents and triggers. | `rg -n "A useful addendum contains|Require a deviation addendum" docs/solutions/workflow-issues/review-introduced-state-machine-deviation.md` | `2026-07-18T18:50:20+09:00` | Both the seven-part content list and trigger rule are present. | `docs/solutions/workflow-issues/review-introduced-state-machine-deviation.md` at `21eb4db` |
| Designing verifies named examples but does not retain a structured evidence record for every live assumption. | `rg -n "Empirical grounding|Assumptions and Preconditions|timestamp|evidence source" skills/designing/SKILL.md skills/designing/references/spec-template.md` | `2026-07-18T18:50:20+09:00` | Empirical grounding exists; no required assumption-evidence record exists. | Source skills at `21eb4db` |
| Planning researches current state but does not rerun each approved live assumption or require an addendum on contradiction. | `rg -n "live assumption|recheck|deviation addendum" skills/planning/SKILL.md schemas/plan-schema.md` | `2026-07-18T18:50:20+09:00` | No matches. | Source guidance at `21eb4db` |
| Implementation review handles plan conflicts but does not require committed deviation evidence before accepting new observable behavior. | `rg -n "Plan-mandated conflicts|deviation addendum" skills/implementing/SKILL.md skills/reviewing/SKILL.md` | `2026-07-18T18:50:20+09:00` | The conflict rule exists; no addendum rule exists. | Source skills at `21eb4db` |
| The incomplete-release example is a real approved-artifact deviation, not a hypothetical. | `sed -n '71,81p' docs/specs/2026-07-16-release-skill-design.md; sed -n '203,208p' docs/plans/2026-07-16-002-feat-release-skill-plan.md; sed -n '39,47p' docs/solutions/workflow-issues/review-introduced-state-machine-deviation.md` | `2026-07-18T18:50:20+09:00` | The approved architecture goes directly from commit to tag, the planned Preflight omits untagged-release recovery, and the solution records the review-discovered intermediate state. | All three artifacts at `21eb4db` |

Evidence retention must never commit secrets, credentials, personal data, or
unbounded command output. A concise result or a reference to a committed,
sanitized evidence artifact is sufficient when raw output is unsafe or large.

## Scope

### In

- Require specs that make live assumptions to retain claim, command,
  observation time, evidence source, and concise result.
- Require planning to rerun every retained live-assumption command and record a
  match, contradiction, or unavailable outcome.
- Define contradiction and review-introduced observable behavior as addendum
  triggers while preserving approved specs and plans unchanged.
- Establish one discoverable addendum location under `docs/deviations/` and
  reference the existing generalized solution for required contents.
- Update implementation-review and final-review handoffs so affected behavior
  cannot pass without a committed addendum and linked evidence.
- Use the existing incomplete-release recovery example to prove when the rule
  applies, rather than duplicating its guidance.

### Out

- Rewriting previously approved specs or plans to match later reality.
- Requiring addenda for internal refactors with no observable contract change.
- Defining the full mutation/failure-state matrix or retained-fixture protocol;
  that is ROADMAP carry-forward item 2 and receives its own lifecycle arc next.
- Removing either ROADMAP row; reconciliation remains owned by a future retro.
- Adding a new dependency or changing runtime product behavior.

## Architecture

The guidance forms one evidence chain:

1. **Design evidence packet** — `designing` and its spec template define the
   minimum retained fields for every live assumption. The record may be inline
   or point to a committed sanitized artifact.
2. **Planning recheck** — when an origin spec contains retained live
   assumptions, `planning` and the plan schema require an Assumption Recheck
   section. Each row maps an approved claim to fresh command evidence and one
   outcome: match, contradiction, or unavailable. A plan without an origin
   spec, or whose origin spec retains no live assumptions, records that fact in
   the section instead of inventing evidence. Contradictions block plan
   finalization and commit until an addendum exists; unavailable evidence
   remains an explicit planning-time unknown unless the user accepts a narrower
   claim.
3. **Deviation addendum** — the canonical path is
   `docs/deviations/YYYY-MM-DD-<topic>-NNN.md`. The artifact identifies the
   approved source and follows the content contract already defined in
   `docs/solutions/workflow-issues/review-introduced-state-machine-deviation.md`.
   The original approved artifacts remain unchanged.
4. **Implementation-review handoff** — `implementing` checks every accepted
   review-driven behavior change against the approved spec, plan, and existing
   addenda. Observable drift blocks unit or branch acceptance until the
   addendum commit exists.
5. **Review completeness** — `reviewing` treats the approved spec, plan, and
   referenced addenda as one requirements set. A missing addendum for confirmed
   observable drift remains actionable and prevents a clean verdict.

An **observable behavior change** includes state-machine branches, durable
intermediate states, recovery or retry semantics, gates and consent boundaries,
persistent side effects, terminal outcomes, and invariants used to recognize
prior work. This definition is promoted from the existing solution document.

## Integration

- `designing` produces evidence-bearing specs for `planning`.
- `planning` produces a plan plus any contradiction addenda for
  `implementing` and `reviewing`.
- `implementing` passes the approved artifact set and addendum references to
  task and final reviewers.
- `reviewing` verifies both historical truth and operational truth before
  returning `clean`.

## Testing

- Run `bash scripts/validate.sh` after every skills or schema commit.
- Use targeted searches to prove all four lifecycle surfaces contain their
  required handoff rule and link to the existing solution guidance.
- Walk the existing incomplete-release recovery example: the approved release
  design and plan omit incomplete-release recovery, while the solution records
  the review-introduced recovery branch. The new rules must classify that case
  as addendum-required and an internal prose-only refactor as exempt.
- Self-review the addendum location and field names for consistency across
  designing, planning, implementing, reviewing, and the plan schema.

## Risks

- **Evidence bloat or leakage** — retain concise, sanitized results and permit
  committed evidence references instead of raw output.
- **Ceremony for harmless edits** — scope the trigger to observable behavior
  and keep internal refactors exempt.
- **Historical rewriting** — state explicitly that approved artifacts remain
  unchanged and addenda are separate commits.
- **Item 2 scope absorption** — mention verification changes only as an
  addendum field inherited from existing guidance; leave matrix structure and
  forced-failure evidence requirements to the next designing cycle.

## Success Criteria

1. Live assumptions have a durable evidence contract in designing and a fresh
   recheck contract in planning.
   - **Measured by**: `rg -n "Live assumption evidence|Assumption Recheck" skills/designing/SKILL.md skills/designing/references/spec-template.md skills/planning/SKILL.md schemas/plan-schema.md` returns the named guidance in both producer phases.
2. Contradictions preserve approved artifacts and require a committed deviation
   addendum before plan finalization.
   - **Measured by**: a reviewer checks the planning guidance and plan schema for all three invariants: rerun the retained command, do not rewrite the approved artifact, and block finalization and commit until the addendum commit exists.
3. Review-introduced observable behavior cannot pass implementation or final
   review without a committed addendum.
   - **Measured by**: `rg -n "deviation addendum|observable behavior" skills/implementing/SKILL.md skills/reviewing/SKILL.md` shows the blocking handoff in both skills, and the release-recovery worked example is classified as addendum-required.
4. The implementation promotes rather than duplicates the existing generalized
   guidance.
   - **Measured by**: every lifecycle rule links to `docs/solutions/workflow-issues/review-introduced-state-machine-deviation.md`, while no new document restates its seven-part addendum list.
5. Existing structural and terminal-signal contracts remain valid.
   - **Measured by**: `bash scripts/validate.sh` exits 0 after each commit touching `skills/` or `schemas/`.
6. Item 2 remains independently designable.
   - **Measured by**: the item 1 diff contains no required matrix schema or forced-failure fixture protocol beyond references already present in the generalized solution.

## Open Decisions

- **Scope boundary for the overlapping carry-forward item** — approval of this
  spec confirms that item 1 may require an addendum to name verification
  changes, but the success/forced-failure/rerun/rollback/headless matrix and
  retained fixture evidence remain entirely in item 2's subsequent design.
  The user resolves this at the spec gate.
