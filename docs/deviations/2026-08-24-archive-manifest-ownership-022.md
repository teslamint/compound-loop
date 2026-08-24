# Deviation Addendum 022: Archive Manifest Ownership

_Recorded 2026-08-24 during post-feedback review, before corrective implementation._

## Original contract

Addendum 021 includes `progress.md` in the archive source manifest.
Archive resume compares the manifest with the current source-destination union.

## Discovered gap

The destination manifest has no source-owned digest anchor.
A caller can change progress bytes and update the manifest to match.

A forged manifest can also exist before the first move.
Self-consistent bytes do not prove that the archive command created the manifest.

## Decision

Record the manifest path and SHA-256 in the source publisher journal before the first move.
Use the exact key `.archive-source-manifest.json`.

Allow the journal reader to validate this archive-only ownership key.
Keep the ordinary phase publisher from targeting that reserved key.

Exclude the publisher journal from the manifest entries.
This rule prevents a manifest-journal digest cycle.

Move the journal before `progress.md` as before.
Resume accepts a manifest only when the journal records its exact digest.

Reject a missing, changed, unowned, duplicated, or conflicting manifest.
Reject a forged manifest before union validation.

## Observable behavior

- Coordinated manifest and progress tampering blocks.
- Manifest-only tampering blocks.
- A pre-move forged manifest blocks.
- The packaged publisher cannot publish the reserved manifest key.
- A valid manifest and journal move to the same terminal archive.
- Legacy runs without a journal receive one archive authority journal.

## Safety and consent boundaries

The journal update is repository-local and atomic.
It grants no outward action or deletion authority.

A failed ownership check preserves the source progress record.

## Verification

- Extend `archive_destination_foreign_entry` with coordinated tampering.
- Cover a pre-move forged manifest without a journal anchor.
- Keep progress-only and destination-foreign attacks green.
- Add the manifest key to publisher reserved-target attacks.
- Keep legacy, scoped, journal-split, and interrupted resume cases green.

## Traceability

- Prior correction: `docs/deviations/2026-08-24-archive-progress-manifest-021.md`.
- Approved plan: `docs/plans/2026-08-23-001-fix-run-artifact-integrity-plan.md`.
- Standalone review event: `standalone:branch:4`.
- Affected code: `skills/release-loop/scripts/run-artifact-integrity.py`.
- Shared journal code: `skills/release-loop/scripts/phase_artifact_core.py`.
- Regression suite: `scripts/test-run-artifact-integrity.sh`.
