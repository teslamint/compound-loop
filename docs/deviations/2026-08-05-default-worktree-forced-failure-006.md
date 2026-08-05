# Deviation Addendum 006: Default Worktree Forced-Failure State

_Recorded 2026-08-05 during U1 review, before release._

## Original contract

The approved specification makes isolated worktrees the default for new release loops.
It keeps worktree creation behavior outside this feature.

The approved plan delegates creation to `worktree-isolation`.
Its forced-failure matrix injects a non-empty destination in a disposable repository.
The approved artifacts do not define the resulting branch state or rerun result.

## Discovered state

U1 fixture evidence ran `git worktree add <path> -b feat/forced-failure`.
The destination already existed and was not empty.

Git created the branch before it rejected the destination.
The failed command left the branch without a linked worktree.

A blind rerun with `-b` failed because the branch already existed.
Reattaching the branch without `-b` recovered the disposable fixture.

## Decision

Record the inherited failure state without changing the creation algorithm.
The approved specification excludes changes to that algorithm.

The release-loop contract continues to delegate creation to `worktree-isolation`.
A separate feature must own any automatic orphan-branch recovery.

## Necessity

Default isolation makes the existing creation path the normal path.
Review therefore requires operational truth for its durable failure state.

Removing the default would reject the approved user request.
Changing creation recovery here would exceed the approved scope.

## Observable behavior

- A destination failure can leave the requested feature branch behind.
- A blind rerun with `-b` can fail on that existing branch.
- Manual compensation can attach the existing branch without `-b`.
- Successful creation and existing-worktree detection remain unchanged.
- The release loop still reports the existing skill's sandbox fallback when applicable.

## Safety and consent boundaries

The forced-failure and compensation checks use disposable repositories under `/tmp`.
Each fixture has no configured remote and uses `LOCAL_ONLY_NO_REMOTE` as its boundary sentinel.

This addendum authorizes no push, merge, branch deletion, or real worktree removal.
It grants no new user-consent exception.

## Verification changes

- Retain the failed command, exit status, and exact Git error.
- Verify that the branch exists after the destination failure.
- Verify that a blind `-b` rerun fails on the existing branch.
- Verify that attaching the existing branch without `-b` succeeds.
- Run an unattended disposable release loop through the Design gate.
- Verify that the unattended run creates one isolated worktree with no fallback.

## Traceability

- Approved specification: `docs/specs/2026-08-05-default-worktree-isolation-design.md`.
- Approved plan: `docs/plans/2026-08-05-001-feat-default-worktree-isolation-plan.md`.
- Initial implementation: commit `1d1b6e9`.
- Opt-out correction: commit `682a677`.
- Review finding: `.release-loop/reviews/U1-review-round1.md`, finding 1.
- Forced-failure evidence: `.release-loop/evidence/U1/T1-forced-failure.md`.
- Headless evidence: `.release-loop/evidence/U1/T1-headless.md`.
- Affected runtime contract: `skills/release-loop/SKILL.md`.
- Addendum authority: `docs/solutions/workflow-issues/review-introduced-state-machine-deviation.md`.
