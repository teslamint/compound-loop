# Deviation Addendum 004: Explicit Feature Selector for Archived Resume

_Recorded 2026-08-03 during U2 review, before the corrective implementation._

## Original contract

The approved specification requires an archive lookup when `progress.md` is absent.
The lookup must match the requested loop's `feature:` value.

The approved plan repeats this requirement in U2.
The existing invocation contract only says to append `resume`.
It does not define a feature selector for that form.

## Discovered contradiction

U2 review found that bare `resume` cannot supply the required archive lookup key.
The contradiction appears only when `progress.md` is absent.
A live record already supplies its own `feature:` value.

The same review found an unreachable missing-file branch after an unconditional file read.
That ordering defect does not change the approved contract.

## Decision

The user selected an explicit feature selector on 2026-08-03.
Use `$release-loop <feature> resume` when `progress.md` is absent.

If the user invokes bare `resume`, ask one blocking question for the feature.
Do not search the archive before the user supplies that value.

Bare `resume` remains valid when `progress.md` exists.
The live record remains the source of its feature value.

## Necessity

The archive can contain records for many completed loops.
Selecting the newest record can resume the wrong loop.
Inferring a value from the branch can fail on unrelated or nonstandard branches.

An explicit selector preserves the approved exact-match rule.
It also prevents silent guesses when the durable working record is absent.

## Observable behavior

- A missing `progress.md` plus an explicit feature starts the matching archive lookup.
- A missing `progress.md` plus bare `resume` opens one blocking selector question.
- A matching completed record reports completion and its archive path.
- No matching record enters the existing git-evidence reconstruction path.
- Reconstruction archives only when git evidence proves completion.
- Incomplete reconstructed work resumes at its reconstructed phase and unit.

## Safety and consent boundaries

The selector question performs no file move, commit, push, merge, or network action.
Cancellation leaves repository and archive state unchanged.

An unattended caller without a selector returns blocked context.
It must not infer a selector or choose the newest archive.
Existing merge and outward-publication gates remain unchanged.

## Verification changes

- Success: explicit feature plus a completed archive reports that archive path.
- Missing input: bare resume plus no live record blocks before archive lookup.
- Rerun: the same explicit feature reports the same completed archive.
- No match: reconstruction follows git evidence and does not archive incomplete work.
- Headless: missing selector returns blocked context without a guess.
- Cancellation: the selector question causes no mutation.
- Rollback: not applicable because selector resolution performs no mutation.

## Traceability

- Approved specification: `docs/specs/2026-08-03-archive-on-loop-completion-design.md`.
- Approved plan: `docs/plans/2026-08-03-001-feat-archive-on-loop-completion-plan.md`.
- Initial U2 implementation: commit `1fd7f80`.
- Review findings: `.release-loop/reviews/U2-review.md`, findings 1 and 2.
- User decision: `Require feature`, selected at the U2 plan-conflict gate on 2026-08-03.
- Affected file: `skills/release-loop/SKILL.md`.
- Corrective implementation must cite this addendum and pass U2 re-review.
- Addendum authority: `docs/solutions/workflow-issues/review-introduced-state-machine-deviation.md`.
