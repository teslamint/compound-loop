# Deviation Addendum 023: Review Evidence Transactions

_Recorded 2026-08-24 during CodeRabbit review round three, before corrective implementation._

## Original contract

Addendum 022 stores the archive manifest digest in the publisher journal.
The archive rejects a manifest without that ownership record.

The fix-event migration binds each row to one publisher-owned fixer report.
The progress schema requires a round-specific review result path.

## Discovered gaps

The archive writes the final manifest before it records ownership.
A crash between those writes leaves an unowned manifest that cannot resume.

The migration validator permits a source result or adoption file as a fixer report.
It also permits two rows or another event to share one fixer report path.

## Manifest transaction decision

Write the manifest source under the active root's `.tmp` directory.
Record its source, destination, and SHA-256 as a journal pending row.

Rename the source to the destination only after the pending write succeeds.
Finalize manifest ownership and clear pending after the rename.

Resume accepts only that exact pending source and target pair.
It validates the digest and completes the missing rename or ownership write.

Reject an unowned manifest without the matching pending row.
Keep the manifest key reserved from the ordinary phase publisher.

## Fixer report decision

Require every fixer report path to differ from its adoption and source review paths.
Track one owner for every existing and proposed event result path.

Reject duplicate ownership across existing events or migration rows.
Allow an exact replay when the same event ID owns the same path.

Preserve the existing type, digest, signature, source, and publisher ownership checks.

## Observable behavior

- A crash after pending creation resumes from the temporary manifest.
- A crash after manifest rename finalizes journal ownership on resume.
- A manifest without ownership or pending state remains blocked.
- Source and adoption paths cannot serve as fixer reports.
- Two migration rows cannot share a fixer report.
- Another event cannot own the same fixer report path.
- An exact migration replay remains valid.

## Safety and consent boundaries

Both transitions modify repository-local evidence only.
They grant no push, merge, publication, or deletion authority.

Invalid or ambiguous states fail before another archive move or ledger edit.

## Verification

- `archive_manifest_pending_recovery` covers both interruption boundaries.
- The case covers legacy and scoped roots.
- Reserved-target tests block ordinary manifest publication.
- `fix_event_migration_validation` covers source and adoption reuse.
- The migration case covers existing-event and cross-row duplicates.
- Existing replay, signature, digest, and path attacks remain green.

## Traceability

- Manifest ownership: `docs/deviations/2026-08-24-archive-manifest-ownership-022.md`.
- Approved plan: `docs/plans/2026-08-23-001-fix-run-artifact-integrity-plan.md`.
- PR review threads: `3842667480` and `3842667488`.
- Affected archive code: `skills/release-loop/scripts/run-artifact-integrity.py`.
- Affected migration code: `skills/release-loop/scripts/validate-fix-event-migration.py`.
- Regression suite: `scripts/test-run-artifact-integrity.sh`.
