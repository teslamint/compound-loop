---
title: Legacy Archived-Incomplete Recovery
status: draft
date: 2026-08-29
schema: spec/v1
---

# Legacy Archived-Incomplete Recovery Design

_Created 2026-08-29._

## Overview

Add one governed recovery path for terminal `archived-incomplete` runs whose
sealed plans predate the pre-archive verification contract. The path creates a
verified backup, records separate recovery authority, restores verified bytes,
validates equivalent pre-archive evidence, and then uses the completed archive
operation.

## User Scenarios

### S1: Authorize and audit an eligible archive

A release-loop operator has a merged run with committed Retro evidence. Its
sealed plan has no pre-archive contract declaration. Its terminal archive is
`archived-incomplete`. The orchestrator issues a recovery gate for one exact
packet. After current-session USER approval, it creates a backup and runs one
read-only authority audit. The audit accepts only when every archive, plan,
path, and state predicate matches.

### S2: Restore and complete an eligible run

After an accepted audit, the orchestrator invokes:

```text
python3 run-artifact-integrity.py restore-legacy-archive \
  --repo . \
  --recovery-id <recovery_id>
```

The command claims the authority once, then restores the exact original
scoped artifact root. It restores `progress.md` last. It returns deterministic
JSON containing the restored progress path, archive manifest digest, and
state. The orchestrator records a `legacy_archive_recovery` receipt, validates
equivalent pre-archive evidence, and calls the completed archive operation.

### S3: Reject an ineligible or unsafe recovery

An operator supplies a plan with a supported, unsupported, malformed, or
duplicate pre-archive contract declaration. The same rejection applies to a
stale approval, changed archive bytes, invalid backup, or occupied restore
root. The applicable command fails before restoring bytes. The source archive
and backup remain available.

### S4: Preserve an interrupted executor for operator resolution

The sole executor fails, is cancelled, or stops without a terminal result.
Its create-once started claim consumes the authority. The archive and backup
remain intact. Automatic retry is blocked. The operator must resolve any
partial target before creating a new recovery ID and obtaining fresh approval.

### S5: Preserve ordinary lifecycle behavior

A normal run with a supported declaration continues to require that version's
ordinary acceptance. An absent declaration never grants recovery by itself.
Unknown future versions fail closed until an explicit validator supports them.
Normal archive, resume, handoff, transition override, and compensation behavior
stays unchanged unless a validated recovery receipt explicitly activates the
narrow archive-evidence supersession rule.

## Scope

### In

- R1: Define strict eligibility for one scoped terminal
  `archived-incomplete` record whose plan has an `absent-legacy-shape`
  pre-archive contract status and predates the contract introduction commit.
- R2: Define a current-session USER recovery gate for one exact packet.
- R3: Define backup, authority, audit, executor claim, result, and receipt
  artifacts under fixed repository-relative roots.
- R4: Add backup, audit, and restore CLI operations with deterministic JSON.
- R5: Enforce closed-root, no-symlink, manifest, ownership, destination, and
  atomic absent-target creation checks.
- R6: Define legacy-equivalent pre-archive validation and one archive-evidence
  supersession rule.
- R7: Add positive, rejection, interruption, cancellation, rerun, and
  invariance fixtures.
- R8: Document the difference between recovery, resume, incomplete archive,
  and transition override.

### Out

- Reversing arbitrary terminal archives.
- Recovering any plan classified as `supported`, `unsupported-version`,
  `malformed`, `duplicate`, or `unverifiable` for the pre-archive contract.
- Editing or resealing the approved plan.
- Treating recovery authority as merge, publication, or outward-action consent.
- Automatically retrying a claimed executor.
- Deleting the source archive or backup before final verification succeeds.

## Assumptions and Preconditions

| Claim | Command | Observed at | Observed result | Evidence source |
| --- | --- | --- | --- | --- |
| The artifact CLI has no restore command. | `python3 skills/release-loop/scripts/run-artifact-integrity.py --help` | `2026-08-29T13:40:26Z` | Commands exclude restore. | Worktree at `59dcff696ba2aa3bfa24a46ed77baee5c41c2ac6` |
| The progress contract requires V2 acceptance before `phase: done`. | `rg -n 'V2 acceptance is required before' skills/release-loop/references/progress-schema.md` | `2026-08-29T13:40:26Z` | One rule exists at line 168. | `skills/release-loop/references/progress-schema.md` |
| Missing V2 evidence leaves a run live and resumable. | `rg -n 'A missing marker.*leaves the loop live' skills/release-loop/references/transition-hooks.md` | `2026-08-29T13:40:26Z` | One rule exists at line 32. | `skills/release-loop/references/transition-hooks.md` |
| Commit `08e12a82752847b3bead5a96fd251b4ad58eae1b` introduced the governing V2 heading. | `git show 08e12a82752847b3bead5a96fd251b4ad58eae1b:skills/release-loop/references/transition-hooks.md \| rg -n '^## Release-loop pre-archive verification V2:'` | `2026-08-29T14:31:56Z` | The heading exists at line 28 of the committed file. | Git object `08e12a82752847b3bead5a96fd251b4ad58eae1b` |

The repository-relative root and Python 3.9 through 3.14 compatibility
contracts remain mandatory.

## Architecture

The recovery has six ordered stages. Each stage consumes immutable,
digest-pinned output from the previous stage.

1. **Approval** creates one request and one current-session USER answer for an
   exact recovery packet.
2. **Backup** copies the complete terminal archive to the fixed recovery backup
   root. It verifies payload entries and both archive control files.
3. **Authority audit** validates eligibility and every pinned input. It writes
   one immutable accepted or rejected verdict.
4. **Executor claim** uses create-exclusive semantics to write one immutable
   started claim before any restored-root mutation.
5. **Restore** revalidates the backup against the audit-pinned digests, then
   copies the verified bytes to an atomically created original scoped root and
   writes one immutable executor result. It restores `progress.md` last.
6. **Completion** records the recovery receipt, stages one final destination,
   validates equivalent pre-archive evidence, transitions to done, and invokes
   the completed archive move under the supersession rule.

The existing archive manifest and ownership journal remain the payload and
publisher authorities. Recovery adds no generic archive reversal primitive.
Transition override remains limited to changed literal artifacts with replaced
digests.

## Root Families and Identity

Recovery adds two closed physical-root families:

- backup root: `.release-loop/recovery-backups/<recovery_id>`;
- authority root: `.release-loop/recovery-authority/<recovery_id>`.

`recovery_id` uses the existing safe slug grammar. It is unique per approved
attempt. Request initialization requires both roots to be absent. Later
commands resume only the same ID and exact create-once chain. An unrelated or
malformed pre-existing root blocks. Neither root may contain a symlink. Every
parent must resolve beneath its fixed family.

The backup root contains a byte-preserving copy of the terminal archive. The
authority root contains create-once JSON artifacts. Both roots survive failed,
cancelled, ambiguous, and successful restore operations. Final terminal
verification may mark them retained; automatic deletion is outside this scope.

## Recovery Gate and Artifact Chain

The recovery gate is separate from design and Ship gates. Its identifier is
`legacy-archive-recovery-approval`. Its expected answer class is
`approve-exact-recovery-or-cancel`. Its answers are `approved` and `cancelled`.

The authority root contains this ordered chain:

1. `request.json`, schema `legacy-archive-recovery-request/v1`, pins the plan
   path and seal, archived progress path, archive destination, manifest digest,
   original artifact root, plan approval commit, contract introduction commit,
   recovery ID, mode, session ID, and `issued_at`.
2. `approval.json`, schema `legacy-archive-recovery-approval/v1`, pins the
   request digest, answer, USER approver, session ID, `answered_at`, and one
   at-most-once answer reservation.
3. `backup.json`, schema `legacy-archive-recovery-backup/v1`, pins the backup
   root, complete-tree digest, source manifest digest, ownership-journal
   digest, and each payload digest.
4. `audit.json`, schema `legacy-archive-recovery-audit/v1`, pins the three prior
   artifact digests, every eligibility result, the observed contract version
   and classification, provenance verdict, auditor identity, and timestamp.
5. `executor-started.json`, schema `legacy-archive-recovery-executor-start/v1`,
   pins the accepted audit digest, process identity, and start timestamp.
6. `executor-result.json`, schema `legacy-archive-recovery-executor-result/v1`,
   pins the started claim, outcome, restored-root digest when available, and
   finish timestamp.
7. `receipt.json`, schema `legacy-archive-recovery-receipt/v1`, pins the USER
   approval, audit, backup, archive, successful result, plan seal, restored
   root, and the pre-receipt restored-generation digest.

Every artifact uses canonical JSON and create-once publication. The executor
creates `executor-started.json` with `O_CREAT|O_EXCL` or an equivalent atomic
primitive. One winner may proceed. An existing claim blocks every executor,
including the creator on rerun. A started claim without a result is
`ambiguous`; it is never stale or automatically reclaimed.

The gate request is pending until `approval.json` exists. The orchestrator may
write `approval.json` only after it receives a current-session first-hand USER
answer issued after `issued_at`. Cancellation writes the answer and starts no
backup or audit.

The receipt never pins bytes that contain its own digest. The restore result
defines the pre-receipt generation before any recovery or terminal Log line is
added. The receipt pins that generation. Later progress-only records name the
receipt and describe their permitted difference from the restored generation.

The digest graph has no backward edge:

- `G0` is the complete restored-root digest immediately after restore;
- receipt `R` pins `G0` and lives outside the restored root;
- `G1` is the restored root after destination staging and pins `R`;
- `G2` is the root after legacy-equivalent pre-archive acceptance and pins
  `G1` and `R`;
- `G3` is the root after the atomic done transition and pins `G2`.

No artifact pins its own bytes or any later generation.

## Pre-Archive Contract Classification

The parser inspects Markdown headings only. It recognizes a versioned contract
declaration with this canonical heading syntax:

```text
## Release-loop pre-archive verification V<N>: <version-specific title>
```

`N` is a positive decimal integer without leading zeroes. `parsed_version` is
its canonical decimal string, not a machine integer. This representation
handles an arbitrarily large unknown version without overflow. The registry
pins each supported version's exact title and body validator.

The initial registry has one entry. Version `"2"` requires the exact title
`Verify the archived generation` and the existing V2 body validator. This
preserves the complete current heading. Adding V3 or a later version requires a
separate approved contract, exact title, validator, fixtures, and migration
rules. A higher number is never sufficient for acceptance.

A declaration candidate is a Markdown heading whose ASCII-lowercased,
alphanumeric-only heading text starts with
`releaseloopprearchiveverification`. It is also a candidate when the
Levenshtein distance between that canonical token and the normalized leading
substring is at most two. This near-match rule catches case, separator, and up
to two spelling errors. It is a conservative corruption diagnostic, not an
authority boundary. It applies only to headings; body mentions never become
declarations.

The parser returns one closed classification in this order:

- `duplicate`: more than one declaration candidate exists, regardless of each
  candidate's version or syntax;
- `absent-legacy-shape`: no declaration candidate exists;
- `malformed`: the sole matching heading violates canonical heading syntax;
- `unsupported-version`: the sole canonical heading names a positive version
  absent from the validator registry;
- `unverifiable`: the version is supported, but its body, sealed plan, or
  pinned contract cannot validate, including an exact-title mismatch;
- `supported`: the version-specific validator accepts the sole declaration.

Lexical `absent-legacy-shape` is necessary but never sufficient for recovery.
The audit also proves the sealed plan predates contract introduction. It
requires the pinned plan approval commit to differ from and be an ancestor of
`08e12a82752847b3bead5a96fd251b4ad58eae1b`. The plan blob at that approval
commit must match the requested plan path and validated body seal. The audit
also verifies that the introduction commit contains the exact registered V2
heading and contract bytes. Missing Git objects, equality, non-ancestry, blob
mismatch, or changed introduction bytes reject recovery.

The audit records classification, `parsed_version`, and each provenance result.
It stores `null` for the version when no canonical version can be extracted,
including absence and malformed headings. Each classification and every
registered version gets a fixture.

## CLI Interface

The three commands accept repository-relative inputs only:

```text
run-artifact-integrity.py backup-legacy-archive --repo . --recovery-id <id>
run-artifact-integrity.py audit-legacy-archive --repo . --recovery-id <id>
run-artifact-integrity.py restore-legacy-archive --repo . --recovery-id <id>
```

Each command resolves its inputs from the authority chain. It does not accept
replacement digests or paths on the command line. Backup success returns
`backup_path`, `recovery_id`, and `state`. Audit returns `audit_path`,
`recovery_id`, `state`, and `verdict`. Restore returns
`archive_manifest_sha256`, `progress_path`, `recovery_id`, and `state`.
Failures return nonzero, one stable diagnostic class, and no success JSON.

The audit reads archive, backup, plan, Git, and authority artifacts. Its only
write is its immutable verdict artifact. It never writes an archive, backup,
or active run byte.

## Archive-Evidence Supersession

The restored `G0` first preserves its one original `archived-incomplete` line.
The orchestrator publishes receipt `R` outside the restored root. It then
reserves one new terminal destination and atomically creates `G1` by appending
one `legacy_archive_recovery: staged` line and one normal
`retro: archive-destination` line. Both lines name `R`, `G0`, and the new
destination. The phase remains nonterminal, and no archive byte moves.

Legacy-equivalent pre-archive validation checks `G1`, `R`, the reserved
destination, and the source archive. Acceptance creates `G2` by appending one
`legacy-pre-archive-verification: accepted` line that names the `G1` and
receipt digests. Completion then creates `G3` by atomically setting
`phase: done` and `phase_status: complete` with its evidence line. Only `G3`
may enter the completed archive move. The move reuses the reserved destination
and moves `progress.md` last.

Ordinary archive validation still rejects mixed modes. Recovery validation
recognizes two narrow intermediate modes before it recognizes final
supersession:

- `recovery-staged` is `G1`: valid `R`, one incomplete marker, one completed
  destination marker, nonterminal phase, and no legacy-equivalent acceptance;
- `recovery-contract-accepted` is `G2`: the same tuple plus one valid
  acceptance, while the phase remains nonterminal.

Neither intermediate mode may call the archive move. Final supersession at
`G3` requires all these conditions:

- exactly one incomplete marker and one completed marker exist;
- exactly one valid recovery receipt pins the incomplete source archive;
- the receipt pins the restored root and pre-receipt generation;
- one legacy-equivalent pre-archive record pins `R` and `G1` before the done
  transition, while `R` independently pins `G0`;
- the completed destination differs from the incomplete source destination.

Under this exception, the incomplete marker remains immutable history and the
completed marker becomes the current archive mode. Any missing, duplicate,
stale, or mismatched item remains a mixed-mode failure. The source incomplete
archive remains available after final archive verification.

The recovery backup and authority families are persistent siblings of
`archive`, `.handoff`, and `runs`. Legacy handoff excludes them from active
transfer bytes at the base and rejects them in a source worktree. Scoped
handoff remains limited to its selected run root.

Resume uses these commit points:

- restore result without `R`: validate `G0`, then publish `R` once;
- `R` without `G1`: reuse the receipt and reserve one destination once;
- `G1` without `G2`: rerun only legacy-equivalent pre-archive validation;
- `G2` without `G3`: rerun only the atomic done transition;
- `G3` before or during the move: rerun the completed archive operation with
  the persisted destination.

Any digest mismatch, duplicate line, changed destination, or unexpected phase
blocks. No resume step reallocates an identity or destination.

## Integration

- `run-artifact-integrity.py` owns backup, audit, claim, restore, and archive
  supersession validation.
- `progress-schema.md` owns the recovery gate, receipt references, and terminal
  gate rule.
- `transition-hooks.md` owns version registry dispatch and legacy validation
  order.
- `resume-and-archive.md` owns discovery and operator-facing recovery behavior.
- `release-loop/SKILL.md` issues the gate and sequences the sole executor.
- The test harness owns disposable repositories and fault injection.

## Testing

Add one end-to-end fixture that first proves the current failure. It creates an
approved sealed plan without a pre-archive declaration, records merge and Retro
evidence, archives the run incomplete, and proves ordinary completion rejects
it.

The positive path proves approval, backup-first ordering, complete backup
validation, accepted audit, one atomic executor claim, progress-last restore,
legacy-equivalent validation, supersession, and final completed archive. It
compares payload entries against the source manifest. It validates the manifest
and ownership journal separately, then compares the backup's complete-tree
digest.

Negative fixtures cover invalid backups, payload or control-file mismatch,
pending publication, foreign destinations, symlinks, escapes, nonempty
targets, invalid plan seals, all ineligible contract classifications, supported
V2, unsupported V3, missing or stale approvals, rejected audits, duplicate
claims, stale receipts, and bypass attempts. Fault fixtures cover pre-claim
cancellation, post-claim failure, missing result, rerun blocking, and every
`G0` through `G3` completion commit point.

Parser fixtures assert classification, `parsed_version`, recovery eligibility,
and ordinary lifecycle result for each boundary:

- the exact current V2 heading and a valid body;
- supported V2 with an invalid title, body, seal, or pinned contract;
- canonical unsupported V3 and an arbitrarily large unsupported version;
- V0, V00, V02, missing or extra colon, and missing title;
- mixed V2 and V3 candidates;
- two malformed candidates;
- case, separator, and one- or two-edit near-match headings;
- a body-only mention with no declaration heading.

Provenance fixtures pair lexical absence with both outcomes. A pre-introduction
approval commit with matching plan bytes may continue. A post-introduction plan
with a three-edit damaged heading must reject even when lexical classification
returns `absent-legacy-shape`. Missing introduction objects, non-ancestor plan
approval, approval equal to the introduction commit, and approval-blob mismatch
also reject.

Mixed and malformed candidate pairs must classify as `duplicate` before any
per-heading validation. Only the body-only mention may classify as
`absent-legacy-shape` and proceed to the remaining recovery eligibility checks.

Existing tests must still reject `phase: done` without acceptance from the
declared supported contract. Existing archive, resume, handoff, override, and
compensation fixtures remain unchanged and pass.

One invariance fixture creates both recovery root families, then performs an
unrelated legacy handoff. The handoff must exclude those persistent siblings
from both active manifests and preserve their complete trees.

## Risks

- **Restore could overwrite live state.** Reject the target before the claim
  and before the first target write if it contains a selected active progress
  record or any other artifact. Create the absent exact scoped target with an
  atomic create-exclusive operation; `EEXIST` rejects. Recovery never restores
  into an existing active loop.
- **An invalid backup could cause corrupted bytes to be restored.** The audit
  independently validates payload entries, both control files, and the
  complete-tree digest against the source archive. Restore repeats those
  audit-pinned validations and writes only the verified bytes.
- **Concurrent restore attempts could split executor ownership.** Create one
  exclusive started claim before target mutation. Never reclaim it automatically.
- **An absent declaration could weaken the terminal gate.** Accept only a valid
  receipt for lexical absence plus pinned pre-introduction provenance. Keep
  every registered validator unchanged.
- **An unsupported version could dispatch to the wrong validator or bypass
  validation.** Classify it as `unsupported-version` and fail closed until an
  approved validator registers it.
- **Mixed archive markers could select the wrong current archive mode.** Require
  the exact supersession tuple and keep the incomplete source archive.
- **A receipt could be detached from its approved recovery packet.** Bind every
  chain artifact to the same session, request, immutable predecessors, paths,
  and content digests.

## Success Criteria

1. The pre-change failure is reproducible, and ordinary completion stays
   blocked without declared-contract acceptance.
   - **Measured by**: `bash scripts/test-run-artifact-integrity.sh` requires a
     missing-contract rejection before recovery.
2. One eligible archive completes through approval, backup, audit, restore,
   legacy-equivalent validation, supersession, and final archive.
   - **Measured by**: `bash scripts/test-run-artifact-integrity.sh` verifies
     every ordered artifact and one valid completed terminal archive.
3. Backup, restored, and re-archived bytes remain accountable.
   - **Measured by**: `bash scripts/test-run-artifact-integrity.sh` verifies
     payload equality, control digests, and the complete-tree digest.
4. Unsafe path, plan, authority, receipt, and executor states fail before
   unauthorized restore mutation.
   - **Measured by**: `bash scripts/test-run-artifact-integrity.sh` requires
     nonzero results and unchanged source archive and backup manifests.
5. The three CLI commands have deterministic output and stable diagnostics.
   - **Measured by**: `bash scripts/test-run-artifact-integrity.sh` checks exact
     JSON key sets and diagnostic classes.
6. An absent pre-archive contract has exactly one additional terminal
   acceptance route.
   - **Measured by**: `bash scripts/test-release-loop-conformance.sh` rejects
     missing, stale, ordinary-override, supported-V2, and unsupported-V3
     recovery receipts.
7. Recovery never overlaps an audit or second executor.
   - **Measured by**: `bash scripts/test-run-artifact-integrity.sh` proves audit
     completion precedes the claim and every repeated claim rejects.
8. Existing lifecycle contracts remain green.
   - **Measured by**: `bash scripts/validate.sh` and
     `bash scripts/test-plan-consumer-portability.sh` both exit zero.

## Open Decisions

None. Planning may choose internal helper boundaries. It must preserve every
schema, root, ordering rule, classification, and rejection case in this
specification.
