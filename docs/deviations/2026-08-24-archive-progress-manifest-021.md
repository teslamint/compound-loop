# Deviation Addendum 021: Archive Progress Manifest

_Recorded 2026-08-24 during post-feedback review, before corrective implementation._

## Original contract

Addendum 020 creates one archive source manifest before the first move.
The manifest seals source children and validates their source-destination union on resume.

The archive moves `progress.md` last as the terminal commit point.

## Discovered gap

The initial manifest excludes `progress.md` because the move list excludes it.
A caller can change valid progress body bytes after an interruption.

The progress parser and archive marker still pass.
The archive can then move the changed ledger into terminal state.

## Decision

Include `progress.md` in the source manifest with its SHA-256.
Keep it outside the ordinary child move order.

Before every resumed move, require progress in exactly one root.
Require its bytes to match the manifest.

Reject a changed, missing, duplicated, symlinked, or unsupported progress entry.
Continue to move the valid progress file last.

## Observable behavior

- A changed progress body blocks archive resume.
- Missing source progress blocks archive selection.
- Duplicate destination progress blocks resume.
- Restored progress bytes permit the same destination to finish.
- The manifest remains in the terminal archive.

## Safety and consent boundaries

The correction performs repository-local validation only.
It grants no outward action or deletion authority.

Every failed check preserves the selected source state.

## Verification

- Extend `archive_destination_foreign_entry` for progress body tampering.
- Cover missing source progress and duplicate destination progress.
- Restore the exact bytes and complete the same destination.
- Keep all legacy, scoped, interruption, and journal-tamper cases green.

## Traceability

- Prior correction: `docs/deviations/2026-08-24-archive-destination-manifest-020.md`.
- Approved plan: `docs/plans/2026-08-23-001-fix-run-artifact-integrity-plan.md`.
- Standalone review event: `standalone:branch:3`.
- Affected code: `skills/release-loop/scripts/run-artifact-integrity.py`.
- Regression suite: `scripts/test-run-artifact-integrity.sh`.
