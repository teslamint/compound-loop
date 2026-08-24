# Deviation Addendum 019: Final Review Integrity Correction

_Recorded 2026-08-24 during final branch review round two, before corrective implementation._

## Original contract

Addendum 018 introduced a fix-event adoption and version-two matrix evidence.
It also required the archive to move publisher control state into the terminal archive.

The implementation passed its initial disposable fixtures. A fresh final review found five incomplete integrity boundaries.

## Discovered gaps

An interrupted archive can move its journal before `progress.md`. The next invocation then reads an empty source journal.
It does not validate the journal already present in the destination.

Version-two matrix records capture only the primary disposable repository. Some transitions use a base owner or another sibling repository.
Their command traces can therefore name roots and paths that have no matching pre-state or post-state inventory.

The evidence generator and fix-event validator inspect only their final path components. A parent symlink can redirect reads or pre-publication writes outside the repository.

The version-two generator maps several matrix outcomes to cases that test a different outcome. T2 headless evidence does not test missing worker output.

## Corrective contract

### Archive authority

Archive resume accepts exactly one ownership journal. The journal can be in the source root or the recorded destination root.

Validate every owned final across both roots. Each owned path must exist in exactly one root with the recorded digest.
Reject a missing, duplicate, tracked, symlinked, or changed owned final before another move.

Validate both legacy and scoped roots. A journal-first interruption followed by source-final tampering must block.
Restoring the recorded bytes must permit the same destination to finish.

### Shared physical boundary

The evidence generator and migration validator use `phase_artifact_core.guard`. They do not define separate physical-boundary implementations.

Guard the progress path and artifact root before the first read. Guard every journal, adoption, report, temporary, observation, history, record, and authority path.
Reject a symlink in any existing parent component before an external write or trusted read.

### Version-three evidence

Version-two artifacts remain immutable. Publish a new `matrix-evidence-authority/v3` manifest.

Use transition IDs `T1-v3` through `T6-v3`. Name each record `<transition-id>-<outcome>.md`.
Publish all 36 records through the packaged publisher.

The version-three manifest supersedes the version-two authority and its 36 records. It binds every stale path and replacement path to exact SHA-256 values.

Each record declares every disposable repository used by its probe. It stores root-specific pre-state, post-state, and target inventory.
Each inner command trace stores root-specific pre-state and post-state at command time.

Bind every progress, source, target, marker, and destination argument to its command-time path observation. This includes temporary sources that disappear before the final case snapshot.

Reject an omitted sibling root or path binding. Reject placeholder root or inventory values.

### Outcome-specific probes

Register one probe for every transition and outcome pair. Do not relabel an adjacent case as another matrix outcome.

Each probe asserts the exact approved pre-state, action, partial state, next invocation, and boundary mechanism.
T2 headless must allocate one started event before dispatch. Missing worker output must leave that same event started with unchanged counters.

The evidence record uses its probe's exact mechanism and next invocation. It does not substitute a generic success statement.

## Verification

Run these commands:

```sh
bash scripts/test-run-artifact-integrity.sh archive_journal_resume_tamper
bash scripts/test-run-artifact-integrity.sh matrix_generator_parent_symlink
bash scripts/test-run-artifact-integrity.sh fix_migration_parent_symlink
bash scripts/test-run-artifact-integrity.sh matrix_T2_headless
bash scripts/test-run-artifact-integrity.sh matrix_evidence_regeneration
bash scripts/test-run-artifact-integrity.sh all
bash scripts/test-python-compatibility.sh all
bash scripts/validate.sh
git diff --check
```
