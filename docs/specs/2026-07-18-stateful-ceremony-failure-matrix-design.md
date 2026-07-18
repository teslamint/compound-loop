---
title: Stateful Ceremony Mutation and Failure-State Matrix
status: approved
date: 2026-07-18
schema: spec/v1
---

# Stateful Ceremony Mutation and Failure-State Matrix Design

_Created 2026-07-18._

## Overview

Move state-transition defects from late branch review into planning and unit
acceptance. Every stateful ceremony will map its durable transitions across
success, forced failure, rerun, rollback or compensating recovery, headless,
and cancellation or abort outcomes, then retain disposable fixture evidence
that reviewers can inspect before a unit passes.

## User Scenarios

### S1: A planner maps a stateful ceremony

A planner recognizes that a workflow writes a durable artifact before later
steps can fail. The plan lists every durable transition and supplies one outcome
for success, forced failure, rerun, rollback or compensating recovery,
headless, and cancellation or abort execution before implementation units are
finalized.

### S2: An implementer proves failure behavior safely

An implementer runs every applicable matrix cell in a disposable fixture,
injects the named failure at the intended boundary, and retains commands,
status, and post-state evidence under `.release-loop/evidence/` without touching
a real default branch, remote, publication, payment, or production system.

### S3: A unit reviewer verifies the matrix instead of trusting prose

A reviewer receives the plan matrix and retained evidence with the unit diff.
The unit cannot pass while an applicable cell lacks evidence, the fixture failed
for an unrelated reason, or the observed post-state differs from the matrix.

### S4: A release planner covers local and outward states

A planner uses the committed example to walk release commit creation,
pre-tag verification, annotated tag creation, commit/tag publication, and
release-page publication. The example distinguishes reversible local states
from externally visible states that require compensation rather than pretending
rollback can erase them.

## Assumptions and Preconditions

The following live assumptions were checked on the current feature branch
before this draft was written.

| Claim | Command | Observed at | Observed result | Evidence source |
|---|---|---|---|---|
| The mutation/failure-state carry-forward row remains open. | `rg -n "Mutation/failure-state matrix" ROADMAP.md` | `2026-07-18T19:43:11+09:00` | One open P2 row at `ROADMAP.md:40`. | Working tree at `776108c` |
| The existing deviation solution contains only a compact prevention matrix, not the required outcome-column planning contract. | `sed -n '154,170p' docs/solutions/workflow-issues/review-introduced-state-machine-deviation.md` | `2026-07-18T19:43:11+09:00` | The example has State, Forced failure, and Expected next invocation columns; it asks for interactive, headless, cancellation, rerun, and rollback outcomes in prose. | Solution document at `776108c` |
| Planning, implementing, and reviewing do not yet require a mutation/failure-state matrix or retained fixture evidence. | `rg -n "Mutation/failure-state matrix|retained fixture evidence|durable transition" skills/planning/SKILL.md schemas/plan-schema.md skills/implementing/SKILL.md skills/reviewing/SKILL.md` | `2026-07-18T19:43:11+09:00` | No matches. | Source guidance at `776108c` |
| Release already implements the local commit → verify → tag boundary used by the example. | `sed -n '416,452p' skills/release/SKILL.md` | `2026-07-18T19:43:11+09:00` | Execute creates the release commit, runs pre-tag verification, creates an annotated tag, then runs tag-only verification with explicit failure states. | `skills/release/SKILL.md` at `776108c` |
| Release deliberately does not publish, so publication states can be illustrative without expanding the release skill. | `sed -n '8,12p' skills/release/SKILL.md` | `2026-07-18T19:43:11+09:00` | The skill never pushes and never creates a GitHub release. | `skills/release/SKILL.md` at `776108c` |
| The lifecycle already retains briefs, reports, and review diffs under `.release-loop/`, but has no evidence path. | `rg -n "release-loop/(briefs|reports|reviews|evidence)" skills/implementing/SKILL.md` | `2026-07-18T19:43:11+09:00` | Brief, report, and review paths exist; no evidence path exists. | `skills/implementing/SKILL.md` at `776108c` |

## Scope

### In

- Define a stateful ceremony and durable transition for planning purposes.
- Require a matrix row for every durable transition with success,
  forced-failure, rerun, rollback or compensation, headless, and cancellation
  or abort outcomes.
- Permit an explicit not-applicable result only with a concrete reason tied to
  the ceremony's interface or irreversibility boundary.
- Require disposable fixture evidence under
  `.release-loop/evidence/U<N>/` before an affected unit review can pass.
- Pass the matrix and evidence path through implementing's unit and final review
  handoffs.
- Require reviewing to verify failure injection, exit status, post-state,
  rerun/rollback semantics, and that the intended mechanism—not an unrelated
  existing failure—produced the result.
- Add one committed planning reference example covering release commit →
  pre-tag verification → annotated tag plus commit/tag and release-page
  publication states.

### Out

- Changing `skills/release/SKILL.md` or implementing outward publication.
- Executing forced failures against a real default branch, remote, publication,
  payment, deployment, or production system.
- Requiring rollback to erase irreversible external state; compensating action
  and explicit manual recovery are valid outcomes.
- Requiring headless execution where no headless interface exists; the matrix
  must record why it is not applicable rather than leave the cell blank.
- Removing the ROADMAP row; the next retro owns reconciliation.
- Adding dependencies or a machine-readable matrix schema in this iteration.

## Architecture

### Planning contract

A **stateful ceremony** is a multi-step workflow in which a durable side effect
can succeed before the ceremony reaches its terminal success state. A
**durable transition** creates, changes, publishes, or deletes state that a
later process can observe: a file, commit, tag, database row, remote ref,
deployment, payment, external request, or publication.

For each transition the plan records:

- transition ID, pre-state, action, and expected durable post-state;
- success outcome;
- forced-failure injection and expected post-failure state;
- next-invocation/rerun behavior and idempotency expectation;
- rollback, compensation, or explicit no-safe-rollback behavior; and
- headless outcome, including retained handoff artifacts and prohibited side
  effects; and
- cancellation or abort outcome, including the durable state left behind and
  whether a later invocation resumes, repairs, or restarts.

The matrix is conditional: plans with no stateful ceremony state that no durable
transition matrix is required. Once any durable transition exists, every row
and outcome column is mandatory; `not applicable` needs a concrete reason.

### Evidence contract

Affected units retain one evidence record per applicable matrix cell at
`.release-loop/evidence/U<N>/<transition-id>-<outcome>.md`. Each record contains:

- plan and matrix-row identity, source commit, fixture identifier, and timestamp;
- isolation proof: disposable fixture root, every configured remote or endpoint,
  stub identity where applicable, and a sentinel/assertion proving all writable
  or reachable targets stay inside the fixture boundary;
- exact command or injection hook and intended failure boundary;
- pre-state fingerprint;
- exit status plus concise sanitized stdout/stderr result;
- post-state inspection;
- rerun, rollback/compensation, headless, or cancellation result as applicable;
  and
- a mechanism check proving the expected boundary—not an unrelated validator or
  setup failure—caused the observed result.

Evidence may point to larger sanitized fixture artifacts in the same evidence
directory. It must never contain secrets or exercise a real outward system.

### Review contract

`implementing` passes the plan matrix, unit diff, and unit evidence directory to
task review, then passes the accumulated evidence directories to final branch
review. `reviewing` treats a missing applicable cell, unsafe fixture, wrong
failure mechanism, unexpected post-state, or unproved rerun/recovery outcome as
actionable. Review must inspect the isolation proof before running or accepting
fixture evidence. A unit with a durable transition cannot pass review merely
because its happy-path test succeeds.

### Worked example

`skills/planning/references/stateful-ceremony-matrix-example.md` provides a
planning example, not product behavior. It covers:

1. release commit creation;
2. pre-tag verification after the commit exists;
3. annotated tag creation and tag-only verification;
4. commit and tag publication, including a partial push; and
5. release-page publication and post-publication verification.

The example uses a disposable local bare remote and a stubbed publication
fixture. It never instructs an implementer to push or publish for real.

## Integration

- `planning` and `schemas/plan-schema.md` produce the matrix and unit mapping.
- `implementing` produces retained fixture evidence and carries it into review.
- `reviewing` validates matrix completeness and evidence truth before returning
  a clean verdict.
- The existing deviation-addendum rule applies if implementation or review adds
  a new transition or changes an outcome after plan approval.

## Testing

- Walk a no-stateful-ceremony plan and confirm it records the explicit fallback.
- Walk the committed release example and confirm all five transitions have all
  six outcome classes, with concrete not-applicable reasons where needed.
- Inspect one forced-failure record and confirm the intended injection boundary,
  nonzero status, post-state, and next invocation are retained.
- Inspect one publication partial-failure row and confirm rollback is expressed
  as compensation or repair rather than history erasure.
- Run targeted searches for the matrix, evidence directory, and unit-review
  blocking rule across planning, implementing, and reviewing.
- Run `bash scripts/validate.sh` after every commit touching skills or schemas.

## Risks

- **Matrix theater** — require post-state evidence and a mechanism check, not
  prose-only cells.
- **Unsafe failure injection** — fixtures must be disposable and isolated from
  default branches and outward systems, with retained proof of the fixture root,
  configured targets, stub identity, and boundary sentinel.
- **Evidence bloat or leakage** — retain concise sanitized records under the
  ignored lifecycle directory and forbid credentials or raw unbounded output.
- **Irreversible-state fiction** — allow compensation or manual repair where
  rollback cannot erase a publication, payment, or deployment.
- **Over-application** — allow a verified no-stateful-ceremony fallback for leaf
  changes with no durable transitions.
- **Overlap with item 1** — use the committed deviation-addendum rule only when
  the approved matrix changes; do not duplicate its content contract.

## Success Criteria

1. Stateful plans contain a complete durable-transition matrix, while
   stateless plans contain an explicit fallback.
   - **Measured by**: `rg -n "Mutation/failure-state matrix|no stateful ceremony|durable transition" skills/planning/SKILL.md schemas/plan-schema.md` shows both the conditional trigger and complete-row rule.
2. Every durable transition accounts for success, forced failure, rerun,
   rollback or compensation, headless behavior, and cancellation or abort.
   - **Measured by**: a reviewer checks the planning rule and committed example for all six named outcome columns and rejects blank cells or unexplained not-applicable values.
3. Affected unit reviews require retained disposable fixture evidence before
   passing.
   - **Measured by**: `rg -n "release-loop/evidence|fixture evidence|cannot pass" skills/implementing/SKILL.md skills/reviewing/SKILL.md` shows evidence production, handoff, and the blocking review rule.
4. The example covers commit → verify → tag and publication partial states
   without changing release behavior.
   - **Measured by**: the committed reference includes release commit, pre-tag verification, annotated tag, commit/tag publication, and release-page publication rows; `git diff 776108c..HEAD -- skills/release/SKILL.md` is empty for the item 2 range.
5. Retained evidence proves the intended failure mechanism and observed
   post-state without touching a real outward system.
   - **Measured by**: the review rule requires fixture identity, disposable root, configured target inventory, boundary sentinel, failure injection, exit status, post-state, and mechanism check for each applicable forced-failure record.
6. Existing structural and terminal-signal contracts remain valid.
   - **Measured by**: `bash scripts/validate.sh` exits 0 after each commit touching `skills/` or `schemas/`.
7. ROADMAP bookkeeping remains unchanged.
   - **Measured by**: `git diff main...HEAD -- ROADMAP.md` is empty.

## Open Decisions

None. Publication is example-only, irreversible transitions use compensation or
manual repair, and the evidence directory is local lifecycle state rather than
a committed product artifact.
