# Deviation Addendum 020: Archive Destination Manifest

_Recorded 2026-08-24 during PR #22 review, before corrective implementation._

## Original contract

The approved plan defines T5 as one terminal archive transition.
The transition persists one destination and moves `progress.md` last.

Addendum 019 permits an interrupted archive to resume from one publisher journal.
It validates owned finals across the source and destination roots.

## Discovered gap

The destination can contain an unrelated entry before the first move.
The journal validation does not cover an unowned entry such as `foreign.md`.

The archive moves each source child by name.
An unrelated destination name causes no collision and remains in the terminal archive.

A static name allowlist is insufficient.
Legacy runs can contain valid artifacts that predate the publisher journal.

## Decision

Create `.archive-source-manifest.json` in the selected destination before the first move.
The manifest records every source child path, entry kind, and file SHA-256.

Write the manifest through one temporary file and an atomic rename.
Reject a non-empty destination that has no manifest.

On resume, read the same manifest.
Compare it with the exact union of remaining source entries and moved destination entries.

Reject every missing, changed, duplicate, symlinked, unsupported, or additional entry.
Do not move another child after a mismatch.

Keep the manifest in the terminal archive.
Move `progress.md` last as before.

## Observable behavior

- A foreign entry blocks the first archive attempt.
- A foreign entry blocks an interrupted archive resume.
- A changed source or destination file blocks resume.
- Removing the foreign entry permits the same destination to resume.
- Valid legacy artifacts do not require publisher ownership.
- Legacy and scoped archives use the same manifest contract.

## Safety and consent boundaries

The manifest controls repository-local archive files only.
It grants no push, merge, publication, or deletion authority.

The archive preserves source progress after every validation failure.
An operator must remove or reconcile a foreign entry before retry.

## Verification

- `archive_destination_foreign_entry` covers legacy and scoped runs.
- The case rejects a foreign entry before the first move.
- The case injects an interruption after manifest creation.
- The case rejects a foreign entry after that interruption.
- The case removes the foreign entry and completes the same destination.
- Existing archive interruption and tamper cases remain green.

## Traceability

- Approved specification: `docs/specs/2026-08-23-run-artifact-integrity-design.md`.
- Approved plan: `docs/plans/2026-08-23-001-fix-run-artifact-integrity-plan.md`.
- Prior archive correction: `docs/deviations/2026-08-24-final-review-integrity-correction-019.md`.
- PR review thread: `3842169303`.
- Affected code: `skills/release-loop/scripts/run-artifact-integrity.py`.
- Regression suite: `scripts/test-run-artifact-integrity.sh`.
