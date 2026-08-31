---
schema: plan/v1
title: Legacy Archived-Incomplete Recovery
type: fix
status: approved
date: 2026-08-30
execution: code
origin: docs/specs/2026-08-29-legacy-archived-incomplete-recovery-design.md
body_seal: 452ead5118bfe6ebf25b7f1b8e3c6a6c7f8f40658432712e3e7b45d361c762ac
---

# Legacy Archived-Incomplete Recovery Plan

## Goal

Recover one eligible scoped `archived-incomplete` release-loop run without
weakening ordinary pre-archive validation. Preserve the source archive and
make every recovery mutation attributable to one approved packet.

## Architecture notes

- `run-artifact-integrity.py` owns archive selection, root initialization,
  gate-ledger receipt validation, approval publication, backup, audit,
  exclusive execution, restore, and recovery-only archive supersession.
  Ordinary archive behavior remains unchanged.
- Recovery accepts an archived `progress.md` below `.release-loop/archive/`.
  It derives the restore target only from that archive's pinned original
  artifact root. That root must be `.release-loop/runs/<feature>`. A legacy
  `.release-loop` root is rejected before any recovery write because its
  persistent siblings make absent-root restore impossible.
- The authority chain is request, gate-receipt snapshot, approval, backup,
  accepted audit, create-exclusive executor claim, result, and receipt. Every
  record is canonical JSON, create-once, and digest-pinned to its predecessors.
- Restore creates the exact absent scoped root exclusively, rejects `EEXIST`,
  revalidates audit-pinned backup bytes, and writes `progress.md` last.
- Every recovery read or write stays below verified repository directory file
  descriptors. Components use `openat`/`mkdirat` with no-follow and exclusive
  flags plus descriptor stat checks; a post-check ancestor replacement cannot
  redirect a write outside the repository.
- Authority-root initialization is one atomic directory claim. Its claimant
  alone creates an empty backup container; a failure publishes terminal
  `initialization-result.json` and consumes the ID. The backup stage copies
  bytes only after approval. A copy without `backup.json` is ambiguous and
  requires operator resolution before a new ID. Every authority
  record publishes its final path with create-exclusive semantics after a
  durable temporary write; replacement is forbidden and a concurrent final
  record must match exactly or block.
- The pre-archive parser classifies headings before any recovery decision.
  Only lexical absence plus strict pre-V2 Git provenance can use recovery.
- Recovery reads authority fields only from column-zero frontmatter keys. It
  rejects duplicate top-level keys and ignores nested keys for that authority.
- Recovery reads structured gate and final-action blocks only from frontmatter.
  Body examples and duplicates cannot supply or override authority.
- One shared parser recognizes only exact frontmatter delimiter lines. Scalar
  values containing `---` cannot hide later duplicate authority.
- Audit requires one approved status and one stored body seal in the historical
  plan frontmatter. The stored seal must match its body and the request pin.
- Audit pins one audit timestamp. It validates the terminal lifecycle timeline
  through the request timestamp before it can accept restore authority.
- Recovery reserves transaction basenames at every payload depth. It also
  derives the final journal from the pinned source and compares exact bytes.
- Recovery recognizes G1/G2/G3 as an exception to ordinary mixed-marker
  rejection. It never lets G1 or G2 enter the completed archive move.
- Known Pattern: `docs/solutions/workflow-issues/loop-deliverable-in-disposable-state.md`
  requires separate durable recovery and user authority.
- Known Pattern: `docs/solutions/workflow-issues/procedural-skill-text-stateful-archive-contract.md`
  requires identity before mutation and executable interruption evidence.

## Assumption Recheck

| Approved claim | Fresh command evidence | Outcome |
| --- | --- | --- |
| The artifact CLI has no restore command. | `python3 skills/release-loop/scripts/run-artifact-integrity.py --help` listed only initialize, discover, archive, handoff, publish, and compensate on 2026-08-30. | match |
| V2 acceptance is required before done. | `rg -n 'V2 acceptance is required before' skills/release-loop/references/progress-schema.md` found line 168 on 2026-08-30. | match |
| Missing V2 leaves the loop live. | The retained `rg` command found the live-and-resumable rule in `transition-hooks.md:32` on 2026-08-30. | match |
| Commit `08e12a8` introduced the V2 heading. | The retained `git show` command found the exact V2 heading at line 28 on 2026-08-30. | match |

## File structure

| File | Responsibility |
| --- | --- |
| `skills/release-loop/scripts/run-artifact-integrity.py` | Request CLI with gate-ledger validation, recovery records, backup/audit/restore commands, strict parser, archive supersession, and persistent-root guards. |
| `scripts/test-run-artifact-integrity.sh` | Disposable end-to-end recovery, interruption, integrity, path, and handoff-invariance fixtures. |
| `scripts/test-release-loop-conformance.sh` | Contract classification and terminal-gate fixtures. |
| `skills/release-loop/references/progress-schema.md` | Recovery receipt and recovery-only terminal exception. |
| `skills/release-loop/references/transition-hooks.md` | Version registry and legacy validation ordering. |
| `skills/release-loop/references/resume-and-archive.md` | Discovery, recovery resume points, and supersession behavior. |
| `skills/release-loop/SKILL.md` | USER recovery gate and command sequencing. |

## Scenario coverage map

| S-ID | Unit chain | Integration evidence |
| --- | --- | --- |
| S1 | U1 -> U3 | `legacy_archive_recovery_success` records request, gate-bound approval, backup, and accepted audit. Covers S1. |
| S2 | U1 -> U3 -> U2 | `legacy_archive_recovery_success` restores G0, reaches G3, and archives to the reserved destination. Covers S2. |
| S3 | U1 -> U3 -> U2 | rejection fixtures preserve archive and backup for invalid packet, changed bytes, occupied root, and all ineligible classifications. Covers S3. |
| S4 | U1 -> U3 -> U2 | claim, cancellation, post-claim failure, and rerun fixtures preserve an ambiguous attempt. Covers S4. |
| S5 | U1 -> U2 -> U3 -> U4 | conformance fixtures prove ordinary V2 and normal lifecycle rules remain unchanged. Covers S5. |

## Implementation Units

### U1: Define recovery packet classification and authority records
Execution note: test-first
Files:
  Create: none
  Modify: `skills/release-loop/scripts/run-artifact-integrity.py`, `scripts/test-run-artifact-integrity.sh`
  Test: `scripts/test-run-artifact-integrity.sh`
Interfaces:
  Consumes: one repository-relative archived progress path, one request-pinned live gate-progress path, session identity, sealed plan, and V2 introduction commit
  Produces: immutable request or terminal initialization result, immutable `gate-receipt.json` plus `approval.json` from `request-legacy-archive --publish-approval` with no approval inputs, closed contract classification, and immutable backup and audit records
Test scenarios:
  happy: `request-legacy-archive --progress-path <archived-progress-path> --gate-progress-path <live-gate-progress-path> --session <id>` selects one archived scoped packet, derives its only restore target, claims roots, and publishes a request. A gate-owned receipt then lets `--publish-approval`, backup, and audit complete. Covers S1.
  edge: Exact V2, invalid V2, V3, large versions, malformed headings, duplicates, and body-only mentions produce closed classifications. Fenced pseudo-headings, indented ATX headings, and Setext headings test Markdown boundaries.
  error: Invalid progress selection rejects. Nested, duplicate, delimiter-shadowed, or body-only authority rejects. Missing, duplicate, or mismatched plan seals reject. Invalid provenance, terminal timestamp order, roots, publications, and symlink races reject without restore.
  integration: backup then audit returns fixed JSON keys and preserves the source archive. Covers S1, S3, S5.
Steps:
  1. Add failing request fixtures for canonical archive and gate-progress paths plus `--session`, zero/multiple/non-scoped/escape selection, archive-to-target derivation, concurrent authority-root claim, backup-container failure, consumed-ID rerun, and malformed existing roots. Add classification, provenance, and authority-chain fixtures. Run them; record RED because recovery commands do not exist.
  2. Add one exact-line frontmatter parser, strict Markdown heading classification, and version registry helpers. Ignore fenced code. Recognize indented ATX and Setext candidates. Use canonical decimal strings, exact V2 validation, and fail-closed precedence.
  3. Implement `request-legacy-archive`: resolve and pin exactly one archived terminal packet and one live gate-progress record. Derive the only scoped target from the archive manifest. Claim the authority root with `mkdirat` exclusive semantics. Only that claimant creates an empty backup container. On container failure publish terminal `initialization-result.json`; reject every later use of that ID.
  4. Implement `request-legacy-archive --publish-approval`. It accepts only `--repo` and `--recovery-id`. It reads the request-pinned gate ledger, rejects caller-supplied answer, receipt, digest, and replacement-path inputs, verifies the request digest/session/gate ID/nonce/timestamps and ledger digest, then publishes canonical `gate-receipt.json` and `approval.json` through the descriptor-safe create-exclusive protocol. `approval.json` pins the snapshot path and digest.
  5. After approval, publish canonical backup and audit records through a durable temporary file and create-exclusive final path. A failed backup copy or `backup.json` publication records no accepted audit and blocks same-ID retry. Audit rehashes and parses `gate-receipt.json`; it never reads the cleared live ledger.
  6. Validate the historical plan's unique approved status, stored seal, and calculated body digest. Validate the terminal Ship and Retro timestamp chain through request and audit. Validate the source manifest, exact journal, reserved payload namespace, entries, and tree digest before audit acceptance.
  7. Add deterministic pre-create and pre-copy ancestor-replacement hooks. Each symlink-race fixture verifies a repository-external sentinel tree digest is unchanged, then rejects legacy roots, path escapes, symlinks, Git object failures, replacements, duplicate records, and nonmatching gate receipts before a target write.
  8. Run the U1 fixtures and `bash scripts/test-run-artifact-integrity.sh`. Commit: `feat(release-loop): gate legacy archive recovery`.
Acceptance: every known classification and both unresolved and out-of-set parser outcomes have a named rejection or consumer path. Future or inconsistent terminal timestamps reject before executor artifacts or restore bytes exist. Changed source/archive inputs yield nonzero output and unchanged archive bytes.

### U2: Restore verified scoped bytes and supersede archive evidence
Execution note: test-first
Files:
  Create: none
  Modify: `skills/release-loop/scripts/run-artifact-integrity.py`, `scripts/test-run-artifact-integrity.sh`
  Test: `scripts/test-run-artifact-integrity.sh`
Interfaces:
  Consumes: accepted audit, verified backup, absent scoped target, and executor claim
  Produces: G0 result, receipt R, G1/G2/G3 states, and one recovery-valid completed archive
Test scenarios:
  happy: `legacy_archive_recovery_success` creates an exclusive target, restores progress last, and reaches G3. Covers S2.
  edge: Resume from result-only, R-only, G1-only, G2-only, and G3-during-move reuses the recorded identity and destination. A progress-temporary retry reuses its durable timestamp.
  error: An occupied root, ancestor race, changed backup, duplicate claim, stale receipt, mixed marker, foreign destination, or pending publication blocks. A deleted completed-journal row also blocks before mutation.
  integration: fault cases preserve source/archive/backup and never permit ordinary archive for G1 or G2. Covers S2, S3, S4.
Steps:
  1. Add RED fixtures for exclusive target creation, post-audit mutation, progress-last ordering, each G0-G3 resume point, and executor interruption.
  2. Implement the exclusive executor claim and restore through verified directory descriptors. Recheck audit-pinned backup bytes immediately before copy, create the scoped root with `mkdirat` exclusive semantics, and publish result only after the restored-tree digest matches.
  3. Publish the executor result and receipt with the create-exclusive protocol. Implement recovery-only G1/G2/G3 validators. Each generation fetches a fresh timestamp, updates `updated`, and records its predecessor value. G1 cannot precede the request. A retry adopts exact durable temporary bytes only when its timestamp satisfies that bound.
  4. Add fault injection at pre-claim, post-claim, pre-copy, and mid-copy boundaries. The ancestor-symlink attack verifies an external sentinel tree remains byte-identical. Preserve partial state, forbid automatic claim reuse, and require a new recovery ID after operator resolution.
  5. Run the U2 cases and `bash scripts/test-run-artifact-integrity.sh`. Commit: `feat(release-loop): restore verified legacy archives`.
Acceptance: successful recovery writes one completed archive with accountable G0-G3 history. Each changed-axis guard fails without JSON success and preserves its source archive and recovery backup.

### U3: Publish lifecycle contracts and conformance gates
Execution note: test-first
Files:
  Create: none
  Modify: `skills/release-loop/references/progress-schema.md`, `skills/release-loop/references/transition-hooks.md`, `skills/release-loop/references/resume-and-archive.md`, `skills/release-loop/SKILL.md`, `scripts/test-release-loop-conformance.sh`, `scripts/test-run-artifact-integrity.sh`
  Test: `scripts/test-release-loop-conformance.sh`, `scripts/test-run-artifact-integrity.sh`
Interfaces:
  Consumes: one request record, first-hand current-session USER answer, reserved gate-answer receipt, V<N> declaration, and CLI JSON result
  Produces: create-once gate-bound approval record, one documented USER gate, command sequence, terminal exception, and closed conformance verdict
Test scenarios:
  happy: the release-loop orchestrator writes one receipt in the request-pinned gate ledger after a first-hand current-session answer. `--publish-approval` snapshots it before the gate clears, then publishes approval before backup. A recovery receipt permits the terminal route. Covers S1, S2.
  edge: documented command uses no caller-supplied digest or path replacement; unchanged prose contract passes its fixture.
  error: ordinary V2, V3, malformed, duplicate, stale, missing, and override receipts fail the recovery exception. Covers S3, S5.
  integration: conformance verifies normal V2 transition remains required outside the narrow receipt route. Covers S5.
Steps:
  1. Add failing conformance and prose-contract controls plus one-byte mutations. Run them; record RED because all current terminal rules require literal V2.
  2. Update schema and transition contracts with the version registry, classifier order, receipt references, recovery gate, and only-G3 archive rule.
  3. Extend the progress contract with the recovery gate and its receipt fields. Update the release-loop gate handler to issue that gate in the request-pinned ledger, receive the first-hand answer, write the standard at-most-once receipt, and invoke `request-legacy-archive --publish-approval` without an answer flag or free-form approval data. The CLI snapshots the parsed receipt and pre-clear ledger digest in immutable `gate-receipt.json`, then pins that path and digest in `approval.json`. The gate clears only after both files exist. Test cancellation, duplicate publication, snapshot digest mismatch, unrelated/replayed/swapped receipts, direct caller-supplied approval rejection, and that Python validates receipt custody without claiming to authenticate the human.
  4. Update resume/archive instructions with backup-audit-restore ordering, same-ID resume states, fresh USER approval rule, and no generic reversal.
  5. Run `bash scripts/test-release-loop-conformance.sh` and contract cases. Commit: `docs(release-loop): govern legacy archive recovery`.
Acceptance: the recovery exception accepts one eligible receipt and rejects every ordinary or malformed substitute; the unchanged lifecycle contract remains green.

### U4: Preserve recovery roots across legacy handoff
Execution note: test-first
Files:
  Create: none
  Modify: `skills/release-loop/scripts/run-artifact-integrity.py`, `scripts/test-run-artifact-integrity.sh`
  Test: `scripts/test-run-artifact-integrity.sh`
Interfaces:
  Consumes: an unrelated legacy handoff source with active bytes only and a base checkout already containing recovery-backups and recovery-authority siblings
  Produces: handoff manifest excluding those siblings while retaining their byte-identical trees
Test scenarios:
  happy: unrelated legacy handoff preserves both recovery root families already present in the base checkout. Covers S5.
  edge: scoped handoff remains limited to its selected root.
  error: recovery siblings in a legacy source worktree still reject as non-active source bytes.
  integration: manifest and tree-digest comparison proves persistent siblings survive a handoff. Covers S5.
Steps:
  1. Add a failing handoff invariance fixture with both recovery root families in the base checkout and an unchanged source control. Run it; record RED because the persistent-root allowlist is incomplete.
  2. Extend only base persistent-sibling recognition and manifest exclusion. Keep legacy source rejection and scoped behavior unchanged.
  3. Compare same-kind recovery trees before and after handoff: identical pair equals; one changed payload pair differs at its payload digest.
  4. Run `bash scripts/test-run-artifact-integrity.sh`, `bash scripts/validate.sh`, and `bash scripts/test-plan-consumer-portability.sh`. Commit: `fix(release-loop): preserve recovery roots during handoff`.
Acceptance: recovery roots are absent from active manifests yet byte-identical after handoff; source-root and scoped controls retain their existing rejection behavior.

## Mutation/failure-state matrix

All transitions use disposable local repositories; no outward publication occurs.

| ID | Owner | Pre-state -> action -> post-state | Success | Forced failure | Rerun | Compensation | Headless | Cancellation |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| T1 | U1 request/approval/backup/audit | selected archived progress plus live gate ledger -> authority-root claim -> empty backup container -> request -> gate receipt -> `gate-receipt.json` and `approval.json` -> gate clear -> backup copy and `backup.json` -> accepted audit | Immutable chain pins the archive packet, derived target, pre-clear gate-ledger digest, receipt snapshot, complete backup, and audit. | Container failure writes terminal initialization result. Invalid selection, receipt, snapshot, provenance, copy, or `backup.json` publication leaves no audit acceptance. | Existing claim or initialization result blocks that ID. A started backup without `backup.json` is ambiguous and blocks automatic retry. | Preserve archive and roots. The operator resolves an ambiguous container before a new ID. | Allowed; local request, receipt validation, backup, and audit only. | Cancellation records a cancelled gate result and starts no backup copy. |
| T2 | U2 claim/restore | accepted audit -> exclusive claim/copy -> G0 result | One claim, absent root, verified G0. | Mid-copy injection leaves claim and partial root. | Claim blocks automatic retry. | Operator resolves partial root then obtains new ID. | Allowed; local CLI only. | Pre-claim leaves target absent; post-claim preserves state. |
| T3 | U2 supersession | G0 -> R/G1/G2/G3 -> completed archive | Final move occurs only at G3. | Inject after each generation; source archive remains. | Resume consumes stored ID/destination only. | Preserve incomplete source and persistent evidence. | Allowed; no outward action. | Stop at current generation without archive move. |
| T4 | U4 handoff | base persistent recovery roots plus active-only source -> unrelated handoff -> retained base roots | Trees and active manifest meet invariants. | One changed base payload digest fails fixture. | Re-run observes identical retained trees. | No automatic deletion. | Allowed; fixture-local. | Preserve source and persistent roots. |

## Carry-forward trigger audit

| Tracker row | Trigger class | What fired it | Disposition |
| --- | --- | --- | --- |
| ROADMAP 55 post-Retro criterion | event-based | No post-Retro criterion is declared. | Deferred: not applicable. |
| ROADMAP 56 matrix precision | edit-based | No planning contract file changes. | Deferred: this plan supplies explicit partial states. |
| ROADMAP 57-60 interview, review, signing | edit/event-based | No matching protocol or dispatched committer changes. | Deferred: unrelated. |
| ROADMAP 61 retro merge | event-based | Historical record; no cleanup action is planned. | Deferred: preserve state. |
| ROADMAP 62 merge cleanup | edit-based | No merge command changes. | Deferred: unrelated. |
| ROADMAP 63 body-seal publisher | edit-based | File is not planned. | Deferred: unrelated. |
| ROADMAP 64 Shipping merge gate | edit-based | No merge-gate change. | Deferred: unrelated. |
| ROADMAP 66 raw merged-result traces | event-based | No new merged-result failure. | Deferred: condition not observed. |
| ROADMAP 67 legacy handoff cases | edit-based | U4 edits the named harness. | Fold as U4; add the missing test coverage where applicable. |
| ROADMAP 68 mid-copy recovery injection | edit-based | U2 adds recovery fault injection. | Fold as U2; use archive-restore copy granularity. |
| ROADMAP 69 review completeness | event-based | No review phase sets exact completeness. | Deferred: future review event. |

Audited `ROADMAP.md` at `9277104`: 15 open rows, 2 fired, 0 unobservable.

## Deferred to Follow-Up Work

- General recovery for legacy `.release-loop` roots; it needs a separate target-root design.
- Any migration or automatic registration of V3 or later contracts.

## Open unknowns

**Planning-time:** none.

**Implementation-time:** exact helper names and fixture dispatch placement. The
CLI names, authority schemas, ordering, rejection conditions, and tests above
remain fixed.
