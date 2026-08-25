# Deviation Addendum 024: Archive Progress Commit Recovery

_Recorded 2026-08-24 during CodeRabbit review round four, before corrective implementation._

## Original contract

The archive moves `progress.md` last as its terminal commit point.
Interrupted reruns finish the same persisted destination.

The destination manifest binds the source progress bytes.
The publisher journal binds the manifest and every published artifact.

## Discovered gap

A process can stop after moving `progress.md` but before removing a scoped source directory or returning success.

The next archive invocation validates the now-missing source progress first.
It cannot validate the completed destination or finish scoped source cleanup.

## Decision

Treat an explicit canonical destination as terminal recovery authority when the source progress is absent.

Validate the destination progress frontmatter, artifact root, feature identity, phase state, and persisted destination marker.
Validate the publisher journal and the complete destination manifest before cleanup.

For a scoped run, remove the source directory only when it is empty.
Reject a non-empty, symlinked, corrupt, mismatched, or ambiguous state.

Normal pre-commit interruption recovery still reads the destination from live source progress.
Terminal recovery requires the caller to repeat the exact canonical destination.

## Observable behavior

- A completed legacy archive returns the same terminal result on an exact retry.
- A completed scoped archive removes an empty source directory left after the progress commit point.
- Changed destination progress blocks terminal recovery.
- A foreign scoped source entry blocks cleanup and remains unchanged.
- Missing explicit destination keeps the existing fail-closed behavior.

## Safety and consent boundaries

The recovery changes repository-local archive state only.
It grants no push, merge, publication, or deletion authority.

Scoped cleanup removes only one validated empty run directory.
Every non-empty or unverified source remains untouched.

## Verification

- `archive_progress_commit_recovery` covers legacy and scoped terminal retries.
- The case mutates destination progress and expects rejection.
- The case injects a foreign scoped source entry and expects preservation.
- Existing pre-commit interruption and manifest transaction cases remain green.

## Traceability

- Prior transaction: `docs/deviations/2026-08-24-review-evidence-transactions-023.md`.
- Progress manifest: `docs/deviations/2026-08-24-archive-progress-manifest-021.md`.
- Approved plan: `docs/plans/2026-08-23-001-fix-run-artifact-integrity-plan.md`.
- PR review thread: `3843114995`.
- Affected code: `skills/release-loop/scripts/run-artifact-integrity.py`.
- Regression suite: `scripts/test-run-artifact-integrity.sh`.
