---
schema: plan/v1
title: Default worktree isolation for release-loop
type: feat
status: approved
date: 2026-08-05
execution: code
origin: docs/specs/2026-08-05-default-worktree-isolation-design.md
body_seal: b333f207b8842bc5b664e9610db87326aebac5a2a1b524e026f73fc967908a66
---

# Default Worktree Isolation Plan

## Goal

Make isolated worktrees the default workspace for new release loops.
Keep explicit current-checkout requests and skip-based resumes as exceptions.

## Architecture notes

- `release-loop` owns the default workspace policy.
- `worktree-isolation` remains the only owner of detection and creation behavior.
- The release loop passes a declared isolated-worktree preference to that skill.
- A focused shell test protects the procedural contract through `scripts/validate.sh`.
- No flag is added because user instructions already provide the opt-out interface.
- One implementation unit keeps the red test and minimal contract change in one green commit.
- Known Pattern: `docs/solutions/workflow-issues/procedural-skill-text-stateful-archive-contract.md` requires runtime-effect analysis for procedural text.

## Assumption Recheck

The origin spec retains two live assumptions. Both commands were rerun at `2026-08-05T02:08:08Z`.

| Approved claim | Fresh evidence | Outcome |
|---|---|---|
| The current release loop makes isolation conditional. | `rg -n "worktree-isolation|isolation is wanted" skills/release-loop/SKILL.md` returned Starting step 4 with `when isolation is wanted`. | match |
| The isolation skill honors a declared user preference. | `sed -n '1,120p' skills/worktree-isolation/SKILL.md` shows preference detection, consent only when absent, and in-place behavior after decline. | match |

## File structure

- `skills/release-loop/SKILL.md` — default isolation policy and both exceptions.
- `scripts/test-release-loop-worktree-default.sh` — focused procedural contract regression.
- `scripts/validate.sh` — aggregate invocation of the focused regression.

## Scenario coverage map

| S-ID | Unit chain | Integration test scenario |
|---|---|---|
| S1 start a normal release loop | U1 | Focused test requires the default-isolation sentence. `Covers S1` |
| S2 request in-place work | U1 | Focused test requires the explicit current-checkout exception. `Covers S2` |
| S3 resume existing work | U1 | Focused test requires the skip-based resume exception. `Covers S3` |

## Implementation Units

Order: U1.

The single unit is deliberate. The test, validator hook, and contract sentence form one atomic behavior change.

## U1: Default-isolation contract and regression guard

Execution note: test-first
Files:
  Create: scripts/test-release-loop-worktree-default.sh
  Modify: skills/release-loop/SKILL.md, scripts/validate.sh
  Test: scripts/test-release-loop-worktree-default.sh
Interfaces:
  Consumes: the `## Starting a new loop` section in `skills/release-loop/SKILL.md`
  Produces: `bash scripts/test-release-loop-worktree-default.sh` with exit 0 and one `ok:` line
Test scenarios:
  happy: the starting contract declares `worktree-isolation` as the default. `Covers S1`
  edge: the starting contract honors an explicit request to use the current checkout. `Covers S2`
  error: the test exits nonzero when `when isolation is wanted` remains or a required sentence is absent.
  integration: `scripts/validate.sh` runs the focused test and preserves the skip-based resume exception. `Covers S3`
Steps:
  1. Create `scripts/test-release-loop-worktree-default.sh` with section-scoped exact assertions for all three scenarios.
  2. Run `bash scripts/test-release-loop-worktree-default.sh`; confirm failure because the old conditional contract remains.
  3. Add the focused test to `scripts/validate.sh` without changing unrelated checks.
  4. Replace Starting step 4 with the default, explicit current-checkout exception, and skip-based resume exception.
  5. Run the focused test; confirm exit 0 and its `ok:` line.
  6. Run `./scripts/validate.sh`; confirm `ALL CHECKS PASSED`.
  7. Record branch, worktree, focused-test, and validator evidence under `.release-loop/evidence/U1/worktree-default.txt`.
  8. Commit: `feat(release-loop): Default new work to isolated worktrees`
Acceptance: `bash scripts/test-release-loop-worktree-default.sh` and `./scripts/validate.sh` both exit 0.

## Mutation/failure-state matrix

The changed procedural contract authorizes one durable transition through the existing `worktree-isolation` skill.
The matrix follows `skills/planning/references/stateful-ceremony-matrix-example.md`.
Post-approval behavioral changes require the addendum defined by `docs/solutions/workflow-issues/review-introduced-state-machine-deviation.md`.

| Transition identity | Pre-state | Action | Expected post-state | Owning unit | Evidence owner |
|---|---|---|---|---|---|
| T1 — initialize an isolated feature workspace | A new loop has a validated slug but no feature branch or worktree. | `release-loop` invokes `worktree-isolation` with a declared isolated-worktree preference. | The feature branch is checked out in an isolated workspace, or the existing skill reports its documented fallback. | U1 | U1 writes `.release-loop/evidence/U1/worktree-default.txt`. |

| Outcome class | T1 behavior and evidence |
|---|---|
| Success | The current loop records `feat/default-worktree-isolation`, its linked worktree path, focused-test output, and validator output. |
| Forced failure | Use only a disposable repository under `/tmp`. Pre-create a non-empty destination before `git worktree add`. Record the nonzero status and prove no external remote exists. The existing isolation skill owns the fallback response. |
| Rerun | Existing-isolation detection compares the Git directory and common directory. A rerun reuses the detected worktree and does not nest another one. |
| Rollback or compensation | Keep the feature branch as the durable recovery point. Remove only a disposable failed worktree after its files are preserved. Real worktree cleanup remains outside this feature. |
| Headless | An unattended new loop uses the same declared default. If the harness blocks creation, the existing skill reports the sandbox fallback and works in place. |
| Cancellation or abort | A cancellation after creation leaves the branch and worktree intact. Resume uses the recorded branch instead of creating a replacement. |

## Carry-forward trigger audit

| Tracker row | Trigger class | What fired it | Disposition |
|---|---|---|---|
| Procedural skill text can authorize durable state transitions even when the tracked diff is documentation-only. | event-based | This planning cycle changes procedural text that authorizes branch and worktree creation. | Fold into U1 through the mutation/failure-state matrix and retained evidence. |

The post-Retro criterion row is event-based and did not fire.
This spec defines no criterion that runs after Retro.

Audited ROADMAP.md at `a7fb66a015afe2016c6f157d2bfe917ab162b000`: 2 open rows, 1 fired, 0 unobservable.

## Deferred to Follow-Up Work

None.

## Open unknowns

**Planning-time**: none.

**Implementation-time**: none.
