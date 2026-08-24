# Deviation Addendum 018: Final Review Integrity Migration

_Recorded 2026-08-24 during the final branch review, before corrective implementation._

## Reason

The first final branch review found three integrity gaps. The archive left publisher authority in the live root.
The ledger also omitted completed fixer batches. The matrix evidence had incomplete and competing records.

This addendum authorizes one fail-closed migration. It does not authorize a general ledger rewrite or artifact replacement.

## Archive repair

The archive command must validate the ownership journal before any move. A pending publication blocks the archive.

The archive moves the ownership journal and applicable temporary state. It moves `progress.md` last.

## Historical fix-event adoption

Use one `review-fix-event-migration/v1` adoption. Publish it under `reviews/adoptions/` with the packaged publisher.
Use the adjacent `.fix-events.json` file as the exact adoption source.

The adoption contains these six rows. Paths are relative to the repository root.

| ID | Source review | Signed fix commit | Publisher-owned fixer report | Report SHA-256 |
|---|---|---|---|---|
| `fix:U3:1` | `unit:U3:1` | `42cfea78fa9921240c2292c5e4742c18f2f0c831` | `.release-loop/evidence/U3/review-fix-round1.md` | `fab3e2dd2a9bf4e5a4268cfe918d102ba099d5486a7d5b3cef600212ed070fcf` |
| `fix:U3:2` | `unit:U3:2` | `26358849db7264ff2affd842f39c4d122f6ff2b1` | `.release-loop/evidence/U3/round2-fix.md` | `ca06de509aa87dd3b1cb1ff1086dfcd57fda5ae60d2b8859680e8f39186e73de` |
| `fix:U3:3` | `unit:U3:3` | `3ccb930aa939f9eaeb92846b005301a2e784c054` | `.release-loop/evidence/U3/post-cap.md` | `fd4d64466ad1c56a12f57abafc5d42c4526aef9c37176cea1f25a766f35af77a` |
| `fix:U3:4` | `unit:U3:4` | `37525927afe02bd0d919112447b62e31a815139e` | `.release-loop/evidence/U3/fresh-fix.md` | `17bb6be61ec018bea663bae39338a894120953673a5fb5d11e02dc50283c8b09` |
| `fix:U4:1` | `unit:U4:1` | `2ca4b970f0ea77ad5dfb701101121e509f99c363` | `.release-loop/reports/U4-round2-report.md` | `4891b1f3e34f36e4e097421e960503fc6a4573a88480cac89a28e24a9a55c86c` |
| `fix:U5:1` | `unit:U5:1` | `3f6157c42e84709d2761e4f4ef6ad51b866fc24a` | `.release-loop/reports/U5-round1-fix-report.md` | `80aa6d832c07221dfcabcd0be97373d9e0fa561994c20850e006e782a54fa246` |

Each row uses the source review's full `reviewed_head`. Each subject uses ordinal order without a gap.

The migrated event uses the legacy publisher-owned fixer report as `result_path`. It does not claim a review-result wrapper.
The immutable adoption is the integrity bridge for that exception. The event stores the adoption path and SHA-256.

Run `validate-fix-event-migration.py` before the ledger edit. The validator checks the adoption and every row.
It checks each source review result and its publisher ownership. It checks each full commit signature.
It also checks fixer report ownership and bytes.

The ledger edit appends the six complete fix events. Each event points to the adoption path and SHA-256.
Set `fix_rounds` to the derived lower bound. Keep `review_counts.completeness: partial` and the original counting timestamp.

An exact replay changes no row or count. Any mismatch blocks the migration.

## Matrix evidence generation

Run `regenerate-matrix-evidence.py` after this addendum commit. The command runs every probe in a disposable fixture.

The generator publishes 36 direct version-two records. Each transition has the six approved outcomes.

The new transition IDs are `T1-v2` through `T6-v2`. The record name is `<transition-id>-<outcome>.md`.
Use these unit directories:

- U1: T1, T4, and T5.
- U2: T6.
- U3: T2.
- U4: T3.

Each record contains the plan row and its new ID. It also contains the source and addendum commits.
The record identifies every stale path and SHA-256 that it replaces.

The record captures the actual disposable root and complete target inventory. It includes the applicable stub identity.
It records the boundary sentinel digests before and after the probe.

The record contains the exact command or injection and numeric exit. It retains bounded output and exact pre-state.
It also retains exact post-state, the next invocation, a UTC timestamp, and the mechanism check.

Publish one `matrix-evidence-authority/v2` manifest last. The manifest names all 36 records by path and SHA-256.
It supersedes the old U1 matrix, all six U2 records, and both six-record U4 sets.

The old files remain immutable history. Only the authority manifest selects current evidence.

Reject a missing record or stale file. Reject duplicate or chained authority entries.
Reject changed files and every digest mismatch.

## Verification

Run these commands:

```sh
bash scripts/test-run-artifact-integrity.sh legacy_publish_then_archive
bash scripts/test-run-artifact-integrity.sh archive_pending_publication
bash scripts/test-run-artifact-integrity.sh fix_event_migration_validation
bash scripts/test-run-artifact-integrity.sh matrix_evidence_regeneration
bash scripts/validate.sh
git diff --check
```
