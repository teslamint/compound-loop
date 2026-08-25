---
title: Legacy Handoff Contract
status: draft
date: 2026-08-25
schema: spec/v1
---

# Legacy Handoff Contract Design

_Created 2026-08-25._

## Overview

Add a shared compound-loop handoff contract for selected legacy ledgers.
The contract transfers one active legacy ledger to the base checkout safely.
It preserves the source worktree until the base owner can resume the ledger.

## User Scenarios

### S1: Resume a legacy run after merge

The release-loop operator merges a feature branch that owns `.release-loop/progress.md`.
The base checkout has archives but no active legacy ledger.
The operator runs the explicit legacy handoff command.
The base checkout resumes the exact ledger before cleanup.

### S2: Reject a competing legacy ledger

The base checkout already has an active legacy progress record or an unowned active child.
The handoff command rejects before it writes a marker or copies data.
The source worktree remains unchanged.

### S3: Resume an interrupted handoff

The handoff writes an owner marker and stops before the copy completes.
The next invocation validates the same marker and source manifest.
It copies only missing bytes to the recorded destination.

### S4: Preserve completed archives

The base checkout already contains `.release-loop/archive/` entries.
The legacy handoff transfers only active ledger state.
It does not copy, overwrite, or select an existing archive.

## Scope

### In

- Add an explicit legacy destination argument to the shared handoff CLI.
- Define `.release-loop/` as the only accepted legacy destination.
- Permit one active legacy ledger in the base checkout.
- Allow existing archive and handoff-marker directories at that destination.
- Persist an owner marker before a legacy transfer.
- Compare active-state manifests before cleanup is permitted.
- Verify base discovery selects `.release-loop/progress.md` after transfer.
- Add success, collision, interruption, and symlink fixtures.
- Update release-loop and Ship contracts with the legacy handoff procedure.

### Out

- Per-project handoff configuration.
- Multiple active legacy ledgers in one base checkout.
- A migration that rewrites a legacy ledger into a scoped ledger.
- Archive format changes.
- Deleting the existing preserved archive worktree in this feature.

## Assumptions and Preconditions

| Claim | Command | Observed at | Observed result | Evidence source |
|---|---|---|---|---|
| The current shared CLI rejects legacy handoff before marker creation. | `python3 skills/release-loop/scripts/run-artifact-integrity.py handoff --repo <legacy-worktree> --base-repo <base> --progress-path .release-loop/progress.md` | `2026-08-25T10:12:21+09:00` | It returned `legacy handoff requires an explicit legacy destination contract`. | Archived run-artifact recovery ledger |
| The base root can retain archives without an active progress record. | `ls -la .release-loop` | `2026-08-25T10:12:21+09:00` | The base root contained only `archive/`. | Base checkout |

## Architecture

The handoff CLI remains the authority for source and destination validation.
The caller passes `--legacy-destination .release-loop` for a legacy source.
The CLI rejects every other legacy destination.

The source and destination have two child classes.
Persistent base children are `archive/`, `.handoff/`, and `runs/`.
The handoff never copies or changes persistent base children.
The source rejects `runs/`, `archive/`, `.handoff/`, and every other unknown
child before marker creation. A legacy source must contain only active state.

The active legacy set is `progress.md`, `.tmp/`,
`.phase-artifact-ownership.json`, `briefs/`, `reports/`, `reviews/`,
`evidence/`, and `progress.md.corrupt-*` files.
The base rejects every unowned active child outside the persistent set.

The manifest contains sorted relative paths, entry kinds, and file SHA-256 values.
Its digest is SHA-256 of compact UTF-8 JSON with sorted keys and no whitespace.
The CLI computes it before marker creation.
Each retry recomputes the source manifest.
The retry rejects a changed source or a destination byte mismatch.

The CLI writes `.release-loop/.handoff/<feature>.json` before it copies data.
The marker records the source worktree, base owner, feature, progress path,
destination, and active manifest digest.

The marker state and destination state form a closed recovery table:

| Marker | Destination active state | Result |
|---|---|---|
| absent | absent | Create an incomplete marker. Start the transfer. |
| absent | any active entry | Reject as foreign state. |
| matching incomplete | exact subset | Copy only missing matching entries. |
| matching incomplete | exact complete set | Verify discovery. Mark complete. Return success. |
| matching incomplete | mismatch | Reject and preserve both roots. |
| matching complete | exact complete set | Verify discovery. Return idempotent success. |
| matching complete | any other state | Reject and preserve both roots. Cleanup remains forbidden. |
| corrupt or foreign | any | Reject and preserve both roots. |

The base checkout must discover `.release-loop/progress.md` after a complete transfer.
The CLI recomputes the source manifest immediately before it marks the transfer
complete. It rejects when that digest differs from the marker digest.
The CLI marks the transfer complete only after the active manifests match.
Only a completed matching marker permits source worktree cleanup.

The base collision check uses the filesystem and Git index union.
It rejects a tracked, index-only, or filesystem active path before marker creation.

## Interface

The `handoff` command gains `--legacy-destination <repo-relative-path>`.
The argument is required when `artifact_root: .release-loop`.
Its only valid value is `.release-loop`.
Scoped handoff rejects this argument.

The transition-hook packet names this argument for legacy records.
The Ship resume path rejects a legacy record when the marker is missing, foreign, partial, or mismatched.

## Testing

- Add a legacy handoff success fixture with a base archive control.
- Add a legacy active-progress collision fixture.
- Add a legacy foreign-active-child collision fixture.
- Add a wrong-destination fixture.
- Add an interrupted legacy transfer fixture.
- Add a marker mismatch fixture.
- Add a destination symlink fixture.
- Add a source-change-after-marker fixture.
- Add source persistent-child rejection fixtures for `archive/`, `.handoff/`, and `runs/`.
- Add a one-child-copy interruption fixture.
- Add a complete-marker destination-regression fixture.
- Add tracked and index-only destination collision fixtures.
- Add CLI compatibility fixtures for missing, literal, wrong, and scoped arguments.
- Keep scoped handoff controls unchanged.
- Run the focused handoff cases, `scripts/test-run-artifact-integrity.sh all`, and `scripts/validate.sh`.

## Risks

| Risk | Mitigation |
|---|---|
| A base archive is copied or overwritten. | Exclude persistent children from the active manifest and reject archive target collisions. |
| A second active legacy run replaces the first. | Reject root progress and unowned active children before marker creation. |
| A retry adopts a different source. | Bind source path and manifest digest in the marker. |
| A caller uses an arbitrary destination. | Accept only the literal `.release-loop` legacy destination. |
| Cleanup deletes evidence after a partial transfer. | Permit cleanup only after marker completion and exact base discovery. |

## Success Criteria

1. A legacy handoff transfers one active ledger to the base root while leaving existing archives unchanged.
   - **Measured by**: `bash scripts/test-run-artifact-integrity.sh legacy_handoff_success` exits 0 and checks the archive control digest.
2. A base active legacy ledger or foreign active child blocks before marker creation and preserves both roots.
   - **Measured by**: `bash scripts/test-run-artifact-integrity.sh legacy_handoff_collision && bash scripts/test-run-artifact-integrity.sh legacy_handoff_index_collision` exits 0.
3. A retry resumes only a matching marker and unchanged active manifest.
   - **Measured by**: `bash scripts/test-run-artifact-integrity.sh legacy_handoff_incomplete_rerun && bash scripts/test-run-artifact-integrity.sh legacy_handoff_source_changed` exits 0.
4. A complete marker and exact destination return idempotent success.
   - **Measured by**: `bash scripts/test-run-artifact-integrity.sh legacy_handoff_complete_rerun && bash scripts/test-run-artifact-integrity.sh legacy_handoff_complete_destination_regression` exits 0. The latter verifies rejection, preservation of both roots, and `cleanup_permitted=false` for absent, subset, and mismatched destination state.
5. Invalid legacy destinations and symlinked destination components fail before a copy.
   - **Measured by**: `bash scripts/test-run-artifact-integrity.sh legacy_handoff_destination_attacks` exits 0.
6. The new CLI argument accepts only the legacy literal and rejects all incompatible calls.
   - **Measured by**: `bash scripts/test-run-artifact-integrity.sh legacy_handoff_cli_contract` exits 0.
7. Scoped handoff behavior remains unchanged.
   - **Measured by**: `bash scripts/test-run-artifact-integrity.sh handoff_success && bash scripts/test-run-artifact-integrity.sh handoff_incomplete_rerun` exits 0.
8. Existing repository behavior remains green.
   - **Measured by**: `bash scripts/test-run-artifact-integrity.sh all && bash scripts/validate.sh` exits 0.

## Open Decisions

None.
