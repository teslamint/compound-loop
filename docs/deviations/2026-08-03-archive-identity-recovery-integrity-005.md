# Deviation Addendum 005: Archive Identity and Recovery Integrity

_Recorded 2026-08-03 during PR #3 review, before corrective implementation._

## Original contract

The approved specification defines one idempotent Loop archive procedure.
It stores completed and user-directed incomplete records in the same archive root.

The approved plan requires exact feature matching for missing-record resume.
Addendum 004 supplies the feature selector for that lookup.

The approved artifacts do not define five required details:

- a safe feature identity for branch and archive paths;
- a completed-record predicate and duplicate-match outcome;
- authoritative destination reuse after an interrupted move;
- a terminal home for corrupt-ledger backups; and
- an exact current-archive verification target.

## Discovered contradictions

PR #3 review found that raw feature input can escape the archive root.
The same value currently controls branch, ledger, lookup, and archive identity.

The resume text says "completed archives" without a complete predicate.
An archived incomplete record can share the requested feature.
Several completed records can also share that feature.

An interrupted rerun skips destination creation but does not require Log reuse.
A new collision suffix can split one loop across two archive directories.

Corruption recovery preserves `progress.md.corrupt-<timestamp>` in working state.
The archive move set omits those root-level recovery backups.

The planned final check uses a directory glob.
An older archive can satisfy that check instead of the current procedure result.

## Decision

### Feature identity

Define one `feature_slug` before any lookup or mutation.
It must match `^[a-z0-9]+(?:-[a-z0-9]+)*$`.
It must not equal the reserved standalone token `resume`.

Do not transform invalid input.
Ask an interactive caller for a conforming replacement.
Return blocked context for an unattended caller.

Store the exact slug in `feature:`.
Reuse it as the branch suffix, archive suffix, and resume lookup key.
Validate a stored slug before any archive lookup or move.
Treat an invalid stored slug as corrupt state.

### Completed archive lookup

A completed archive candidate must satisfy four conditions:

1. `feature:` exactly equals the validated selector.
2. `phase:` equals `done`.
3. `phase_status:` equals `complete`.
4. Its archive-destination Log entry names its containing archive directory.

One candidate reports completion and its path.
No candidate enters git-evidence reconstruction.
Several candidates stop with an ambiguity report.
The workflow never selects by traversal order or recency.

Legacy records without a valid destination Log do not qualify.
They remain available to the existing reconstruction path.

### Interrupted archive destination

The first archive attempt selects any collision suffix.
It writes the exact destination before it moves any file.

An interrupted rerun reads that Log entry as authoritative.
It must not calculate another suffix.
It moves only the paths that remain in working state.

### Corrupt-ledger backups

Move every root-level `progress.md.corrupt-*` file into the same archive.
Move these backups before the live `progress.md` commit point.
No backup is required for a loop that never created one.

### Final verification

Retain the exact archive path returned by the current procedure.
Do not rediscover the result with a glob or newest-directory rule.

Before reporting completion, verify these facts at that exact path:

- the live `.release-loop/progress.md` is absent;
- `feature:` equals `archive-on-loop-completion` for this loop;
- `phase:` equals `done`;
- `phase_status:` equals `complete`;
- `retro:` names the committed retro artifact;
- the Log names the exact archive destination; and
- the Log records the retro commit SHA.

## Necessity

Strict validation keeps file moves inside the declared archive root.
It also preserves exact identity across durable records and invocations.

The completion predicate prevents an incomplete archive from masking unfinished work.
The ambiguity outcome prevents a silent choice between durable records.

Destination reuse preserves one loop as one archive after interruption.
Moving recovery backups preserves the empty-working-set guarantee.

Exact-path verification proves this loop completed.
It cannot pass because an older record exists.

## Observable behavior

- Invalid or reserved feature input blocks before lookup or mutation.
- Invalid stored feature state blocks as corruption before archive work.
- Multiple qualifying completed archives return an ambiguity outcome.
- Legacy records without destination evidence enter reconstruction.
- Interrupted reruns reuse the recorded destination.
- Corrupt-ledger backups move into the same terminal archive.
- Completion reports cite the exact archive path that was verified.

## Safety and consent boundaries

Validation and lookup perform no outward action.
Invalid input causes no file lookup, branch creation, or file move.

The ambiguity branch performs no archive selection or mutation.
Cancellation leaves working and archive state unchanged.

Merge, push, and publication gates remain unchanged.
This addendum grants no authority for any outward action.

## Verification changes

- Accept a valid lowercase kebab slug.
- Reject empty, uppercase, separator, dot-segment, and reserved values.
- Reject an invalid slug stored in a live or reconstructed record.
- Prove zero, one, and multiple completed-candidate outcomes.
- Prove archived-incomplete records never qualify as completed.
- Prove legacy records without destination evidence enter reconstruction.
- Prove an interrupted rerun reuses its logged destination.
- Prove zero, one, and several corrupt backups preserve move ordering.
- Verify the exact current archive path after Retro.
- Verify done, complete, feature, destination, and retro commit evidence there.
- Prove headless invalid input and ambiguity return blocked context without mutation.

## Traceability

- Approved specification: `docs/specs/2026-08-03-archive-on-loop-completion-design.md`.
- Approved plan: `docs/plans/2026-08-03-001-feat-archive-on-loop-completion-plan.md`.
- Existing selector decision: `docs/deviations/2026-08-03-archive-resume-feature-selector-004.md`.
- Reviewed implementation head: `3254b44` on PR #3.
- Destination reuse and concept placement: thread `3701298279`.
- Corrupt-backup lifecycle: thread `3701298284`.
- Exact-path completion proof: thread `3701298290`.
- Completed-record predicate: thread `3701298292`.
- Feature path confinement: thread `3701298297`.
- Verification reports: `.release-loop/reports/pr3-thread-*.md`.
- Affected sources: `CONCEPTS.md`, `skills/release-loop/SKILL.md`, and `skills/release-loop/references/progress-schema.md`.
- Addendum authority: `docs/solutions/workflow-issues/review-introduced-state-machine-deviation.md`.
