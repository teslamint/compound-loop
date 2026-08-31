---
title: Legacy Handoff V1 Evidence
status: draft
date: 2026-08-31
schema: spec/v1
---

# Legacy Handoff V1 Evidence Design

_Created 2026-08-31._

## Overview

Legacy handoff rejects `.release-loop/v1` even though Ship stores required V1 evidence there.
Treat that exact directory as active legacy state.
Transfer and archive it under the existing lifecycle contract.

## User Scenarios

### S1: Transfer accepted V1 evidence

A legacy release-loop reaches Ship with accepted V1 receipts and a generation manifest.
The operator runs the existing legacy handoff command.
The base checkout receives the ledger and the exact `.release-loop/v1` tree.

### S2: Resume an interrupted V1 transfer

The handoff stops after copying one file inside the V1 tree.
The operator repeats the same command.
The handoff validates the marker and source manifest before it copies missing bytes.

### S3: Reject unsafe V1 state

The V1 directory contains a symlink, or the destination contains foreign V1 bytes.
The handoff rejects the transfer and preserves both roots.
Cleanup remains forbidden.

### S4: Preserve persistent legacy children

The base checkout contains archives, handoff markers, or scoped runs.
The handoff ignores these persistent children.
The source still rejects these persistent children.

### S5: Archive completed V1 evidence

Retro completes after the base resumes the transferred legacy ledger.
The archive procedure moves the V1 tree with the other run-bound active state.
No orphan V1 directory blocks the next legacy handoff.

### S6: Reject missing or malformed V1 ownership

An accepted V1 ledger references missing ownership metadata, an outside path, or a mismatched digest.
The handoff rejects before marker creation.
The source and base remain unchanged.

## Scope

### In

- Add `v1` to the closed active legacy child set.
- Parse the V1 and pre-merge blocks structurally before marker creation.
- Validate V1 ownership metadata against the accepted pre-merge record.
- Bind every V1 directory and file to the existing SHA-256 manifest.
- Add a deterministic file-level interruption inside recursive directory copy.
- Reuse the existing partial-directory recovery logic for V1 retries.
- Preserve source and destination symlink checks.
- Preserve destination collision checks.
- Move V1 with the selected ledger during a legacy terminal archive.
- Add focused success, interruption, mismatch, symlink, and archive tests.
- Update the transition contract to identify V1 as active legacy state.

### Out

- A generic extension directory or configurable allowlist.
- A legacy-to-scoped ledger migration.
- Changes to the V1 evidence schema or authority rules.
- Changes to handoff marker or scoped-run semantics.
- Deletion or movement of V1 evidence before a successful handoff.

## Assumptions and Preconditions

| Claim | Command | Observed at | Observed result | Evidence source |
|---|---|---|---|---|
| Legacy handoff excludes `v1` from active state. | `sed -n '44,48p' skills/release-loop/scripts/run-artifact-integrity.py` | `2026-08-31T01:57:27Z` | `LEGACY_ACTIVE_ALL` omits `v1`. | Working tree at `59dcff6` |
| Ship requires V1 evidence under `.release-loop/v1`. | `rg -n '\.release-loop/v1' /Users/teslamint/.t3/worktrees/resume/t3code-754baa7d/.release-loop/progress.md` | `2026-08-31T01:57:27Z` | The accepted ledger references pilot, full, receipt, and generation files under that directory. | Resume portfolio worktree ledger |
| The observed handoff blocks on that directory. | `rg -n 'unexpected source entry \.release-loop/v1' /Users/teslamint/.t3/worktrees/resume/t3code-754baa7d/.release-loop/progress.md` | `2026-08-31T01:57:27Z` | The Ship log records the exact legacy handoff rejection. | Resume portfolio worktree ledger |
| Issue #31 requires missing and malformed V1 coverage. | `gh issue view 31 --json body` | `2026-08-31T02:04:13Z` | The acceptance criteria require valid transfer, byte equality, exact resume, missing artifacts, malformed artifacts, and collisions. | GitHub issue #31 |

## Architecture

The handoff CLI remains the only transfer authority.
The active legacy child set gains the exact name `v1`.
No prefix, pattern, or project configuration can extend the set.

V1 gains a versioned ownership check before handoff marker creation.
`pre_merge_verification` remains the only acceptance authority.
The `v1` block contains ownership metadata and does not grant acceptance.
The parser rejects duplicate keys, malformed indentation, and partial structured blocks.
Duplicate detection applies within each mapping.
The same nested key name in different mappings is not a duplicate.

`pre_merge_verification` has exactly four required keys: `id`, `status`,
`generation_sha256`, and `updated`.
The `updated` timestamp records recency but grants no authority.

The `v1` ownership block requires `status`, six path keys, two receipt digest keys,
`generation_manifest_sha256`, and `accepted_at`.
The `accepted_at` timestamp records history but grants no authority.
Both blocks reject missing, empty, duplicate, or unknown keys.

An accepted record requires `pre_merge_verification.id: V1` and `status: accepted`.
Its generation digest must equal the ownership block's generation digest.
The ownership block must also record `status: accepted`.

The six ownership paths are distinct canonical literals:

- `.release-loop/v1/pilot-approval.md`
- `.release-loop/v1/pilot-receipt.md`
- `.release-loop/v1/full-approval.md`
- `.release-loop/v1/full-receipt.md`
- `.release-loop/v1/generation-receipt.md`
- `.release-loop/v1/generation-manifest.sha256`

Each path must be a regular file with no symlink component.
The V1 root permits only these six files and the optional `history` directory.
Aliases, renamed files, and unexpected direct children fail closed.

Pilot and full receipts use their existing `receipt_sha256_scope` rule.
The recorded digest covers canonical bytes before the `receipt_sha256` field.
The ledger digest, embedded receipt digest, and computed canonical-prefix digest must match.
The generation manifest uses whole-file SHA-256.
Approval files and the generation receipt have no ledger digest.
The handoff checks their ownership and presence but does not invent a content digest.

The optional `.release-loop/v1/history` directory remains owned V1 state.
The active manifest binds its complete tree.
The handoff applies this state table:

| Pre-merge block | Ownership block | V1 directory | Result |
|---|---|---|---|
| absent | absent | absent | Allow a pre-V1 legacy handoff. |
| absent | present | any | Reject inconsistent ownership. |
| absent | absent | present | Reject unowned V1 state. |
| started | any | any | Reject because V1 is not accepted. |
| accepted | missing, partial, or non-accepted | any | Reject missing ownership proof. |
| accepted | accepted and matching | absent or malformed | Reject missing or malformed ownership. |
| accepted | accepted and matching | exact valid tree | Continue to manifest and handoff. |

An official accepted block without the ownership block fails closed.
This behavior protects evidence that the handoff cannot reconstruct.

The existing recursive manifest includes the complete V1 tree.
Each entry records its relative path, kind, and file digest.
The existing marker binds the resulting manifest digest.

The existing copy and retry path handles V1 like `briefs` or `evidence`.
A retry fills only missing entries in an existing matching directory.
It rejects extra entries and changed file bytes.

A test-only failure hook stops after one regular file copy inside a directory.
The hook creates a real partial V1 directory without changing production behavior.

Persistent children remain `archive`, `.handoff`, and `runs`.
The base skips them during collision scans.
The source rejects them before marker creation.

The legacy archive moves V1 with the other run-bound active children.
It moves `progress.md` last as the archive commit point.
An interrupted archive retains the existing recovery behavior.

## Interface

The CLI syntax does not change:

```text
run-artifact-integrity.py handoff \
  --repo <source-worktree> \
  --base-repo <base-checkout> \
  --progress-path .release-loop/progress.md \
  --legacy-destination .release-loop
```

The command transfers `.release-loop/v1` when that directory exists.
The command remains compatible when no V1 directory exists.
An invalid V1 ownership record fails before the handoff writes a marker.

Malformed V1 evidence means malformed ownership metadata, path shape, digest shape,
receipt canonical-prefix digest, or generation manifest digest.
It does not mean semantic revalidation of undigested approval or generation receipt content.
Such validation requires a separate V1 authority contract.

## Testing

- Add a fixture that transfers a nested V1 evidence tree.
- Add `handoff-after-copy-one-file` for deterministic mid-directory interruption.
- Add a fixture that uses that hook inside the V1 tree and resumes.
- Cover marker absence with filesystem and index-only foreign V1 state.
- Cover an incomplete marker with subset, extra-entry, and changed-byte V1 state.
- Cover source and destination V1 root and nested symlinks.
- Cover duplicate keys, malformed indentation, partial blocks, and block digest disagreement.
- Cover missing required V1 files, outside-root paths, invalid digests, and digest mismatches.
- Cover canonical-prefix receipt mutations and whole-file generation manifest mutations.
- Cover ledger, embedded, and computed receipt digest mismatches independently.
- Cover aliases, renamed files, and unexpected V1 direct children.
- Cover an existing V1 directory without accepted V1 ledger evidence.
- Cover every row in the pre-merge, ownership, and directory state table.
- Assert marker preservation, both-root preservation, and denied cleanup on every rejection.
- Add a fixture that archives V1 after a completed legacy run.
- Register every new selector in `CASES` and its `run_case` dispatch branch.
- Verify that `all` executes every new selector.
- Keep persistent-child rejection tests unchanged.
- Keep legacy handoff behavior without V1 unchanged.
- Run the focused handoff cases and the complete artifact-integrity suite.
- Run the repository validation gate.

## Risks

| Risk | Mitigation |
|---|---|
| An arbitrary directory gains transfer authority. | Add only the exact child name `v1` to the closed set. |
| A retry accepts incomplete V1 evidence. | Require exact source and destination manifests before completion. |
| Foreign destination evidence is overwritten. | Preserve subset, mismatch, and collision rejection. |
| A symlink escapes the repository boundary. | Preserve recursive source and destination symlink checks. |
| A directory name grants authority to malformed evidence. | Require official acceptance, structured ownership metadata, canonical paths, and existing digest rules. |
| Handoff invents new V1 authority semantics. | Do not semantically validate content that the accepted ledger does not digest. |
| V1 remains after terminal archive. | Move V1 before the archive commits by moving `progress.md`. |
| Existing legacy runs change behavior without V1. | Retain current fixtures as compatibility controls. |

## Success Criteria

1. Legacy handoff transfers a nested `.release-loop/v1` tree and permits cleanup.
   - **Measured by**: `bash scripts/test-run-artifact-integrity.sh legacy_handoff_v1_success` exits 0.
2. An interrupted V1 directory transfer resumes with exact manifest equality.
   - **Measured by**: `bash scripts/test-run-artifact-integrity.sh legacy_handoff_v1_partial_directory_rerun` exits 0.
3. Foreign or changed V1 destination bytes block cleanup and preserve both roots.
   - **Measured by**: `bash scripts/test-run-artifact-integrity.sh legacy_handoff_v1_destination_mismatch` exits 0.
4. V1 symlinks fail before cleanup authority is returned.
   - **Measured by**: `bash scripts/test-run-artifact-integrity.sh legacy_handoff_v1_symlinks` exits 0.
5. A completed legacy archive moves V1 and commits by moving `progress.md` last.
   - **Measured by**: `bash scripts/test-run-artifact-integrity.sh legacy_archive_v1_evidence` exits 0.
6. Missing or malformed accepted V1 ownership blocks before marker creation.
   - **Measured by**: `bash scripts/test-run-artifact-integrity.sh legacy_handoff_v1_ownership` exits 0.
7. Every new selector is registered and included in the aggregate suite.
   - **Measured by**: `bash scripts/test-run-artifact-integrity.sh all` exits 0 after executing all six named cases.
8. Existing legacy handoff controls remain green.
   - **Measured by**: `bash scripts/test-run-artifact-integrity.sh legacy_handoff_success && bash scripts/test-run-artifact-integrity.sh legacy_handoff_source_persistent_children` exits 0.
9. The complete artifact-integrity and repository gates remain green.
   - **Measured by**: `bash scripts/test-run-artifact-integrity.sh all && bash scripts/validate.sh` exits 0.

## Open Decisions

None.
