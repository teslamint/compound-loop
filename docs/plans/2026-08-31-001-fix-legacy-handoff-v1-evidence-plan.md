---
schema: plan/v1
title: Legacy Handoff V1 Evidence
type: fix
status: draft
date: 2026-08-31
execution: code
origin: docs/specs/2026-08-31-legacy-handoff-v1-evidence-design.md
---

# Legacy Handoff V1 Evidence Implementation Plan

## Goal

Transfer accepted V1 evidence with a legacy release-loop ledger.
Reject unowned or malformed V1 state before marker creation.
Archive V1 with the completed ledger so no orphan blocks the next run.

## Architecture notes

- `pre_merge_verification` remains the sole acceptance authority.
- A dedicated structured frontmatter reader validates only the `pre_merge_verification` and `v1` mappings.
- The existing flat reader continues to serve unrelated progress fields.
- This targeted reader avoids changing established flat-field consumers while adding fail-closed nested validation without a YAML dependency.
- The ownership reader rejects duplicate, missing, empty, and unknown mapping keys.
- Six exact V1 file paths and optional `history/` form the closed V1 root.
- Receipt integrity uses ledger, embedded, and computed canonical-prefix digests.
- Generation manifest integrity uses whole-file SHA-256.
- The existing active manifest binds every transferred V1 byte.
- `handoff-after-copy-one-file` creates a real partial directory in disposable tests.
- Legacy archive moves V1 before the `progress.md` commit point.
- No dependency is added. Python standard-library parsing and hashing are sufficient.
- Known Pattern: `docs/solutions/workflow-issues/spec-measurement-contract-integrity.md` requires exact declared test selectors.
- Known Pattern: `docs/solutions/workflow-issues/procedural-skill-text-stateful-archive-contract.md` requires executable interruption and recovery evidence.

## Assumption Recheck

| Approved claim | Fresh command evidence | Outcome |
|---|---|---|
| Legacy active state excludes `v1`. | `sed -n '44,48p' skills/release-loop/scripts/run-artifact-integrity.py` at `2026-08-31T02:50:12Z` showed that `LEGACY_ACTIVE_ALL` omits `v1`. | match |
| Ship stores accepted ownership paths under `.release-loop/v1`. | `rg -n '\.release-loop/v1' /Users/teslamint/.t3/worktrees/resume/t3code-754baa7d/.release-loop/progress.md` at `2026-08-31T02:50:12Z` returned all six canonical paths. | match |
| The observed ledger records the exact V1 rejection. | `rg -n 'unexpected source entry \.release-loop/v1' /Users/teslamint/.t3/worktrees/resume/t3code-754baa7d/.release-loop/progress.md` at `2026-08-31T02:50:12Z` returned the Ship blocker. | match |
| Issue #31 requires valid transfer and malformed-state coverage. | `gh issue view 31 --json body --jq '.body'` at `2026-08-31T02:50:12Z` retained all five acceptance bullets. | match |

## File structure

| File | Responsibility |
|---|---|
| `skills/release-loop/scripts/run-artifact-integrity.py` | Structured V1 ownership validation, active-state classification, file-level fault injection, transfer, and archive selection. |
| `scripts/test-run-artifact-integrity.sh` | Exact selectors, disposable fixtures, state-table mutants, interruption probes, and aggregate registration. |
| `skills/release-loop/references/transition-hooks.md` | V1 ownership, transfer, and cleanup contract. |
| `skills/release-loop/references/resume-and-archive.md` | Legacy terminal archive ownership of V1. |
| `skills/release-loop/references/progress-schema.md` | Structured V1 ownership and acceptance relationship. |

Files run without planned edits: `skills/release-loop/SKILL.md`,
`skills/shipping/SKILL.md`, and `scripts/validate.sh`.

## Requirements-to-units trace

| Spec success criterion | Units |
|---|---|
| SC1 nested V1 transfer | U1, U2 |
| SC2 file-level interrupted resume | U2 |
| SC3 destination mismatch rejection | U2 |
| SC4 V1 symlink rejection | U1, U2 |
| SC5 terminal archive | U3 |
| SC6 V1 ownership rejection | U1 |
| SC7 aggregate selector registration | U1, U2, U3 |
| SC8 existing legacy controls | U2, U3 |
| SC9 complete validation | U3 |

## Scenario coverage map

| S-ID | Unit chain | Integration test scenario |
|---|---|---|
| S1 transfer accepted evidence | U1 -> U2 | `legacy_handoff_v1_success` validates ownership, transfers V1, compares manifests, and confirms exact base discovery. Covers S1. |
| S2 resume interrupted transfer | U2 | `legacy_handoff_v1_partial_directory_rerun` stops after one nested file and resumes the exact subset. Covers S2. |
| S3 reject unsafe V1 state | U1 -> U2 | `legacy_handoff_v1_ownership`, `legacy_handoff_v1_destination_mismatch`, and `legacy_handoff_v1_symlinks` preserve both roots without cleanup authority. Covers S3. |
| S4 preserve persistent children | U2 -> U3 | Existing persistent-child controls and `legacy_archive_v1_evidence` preserve `archive`, `.handoff`, and `runs`. Covers S4. |
| S5 archive completed evidence | U3 | `legacy_archive_v1_evidence` moves V1 before progress and leaves no active V1 orphan. Covers S5. |
| S6 reject malformed ownership | U1 | `legacy_handoff_v1_ownership` walks every ownership state-table row and digest mutant. Covers S6. |

## Implementation Units

Order: U1 -> U2 -> U3.
U1 defines the acceptance boundary.
U2 consumes it for handoff and recovery.
U3 closes the lifecycle through terminal archive and documentation.

## U1: Validate structured V1 ownership before marker creation

Execution note: test-first
Files:
  Create: none
  Modify: `skills/release-loop/scripts/run-artifact-integrity.py`, `scripts/test-run-artifact-integrity.sh`
  Test: `scripts/test-run-artifact-integrity.sh`
Interfaces:
  Consumes: UTF-8 `progress.md`, `pre_merge_verification`, `v1`, and `.release-loop/v1`
  Produces: validated V1 ownership metadata or one named blocked diagnostic before marker creation
Test scenarios:
  happy: `legacy_handoff_v1_ownership` accepts the exact six files, optional `history`, official acceptance, and three matching digests.
  edge: the same selector permits only `absent/absent/absent` pre-V1 compatibility and covers every state-table row.
  error: duplicate top-level ownership blocks, duplicate mapping keys, malformed indentation, missing or unknown keys, aliases, renamed files, outside paths, unexpected children, invalid digest shapes, and each receipt three-way mismatch block without a marker.
  integration: `legacy_handoff_v1_ownership` validates the real Issue #31 record shape before the transfer path. Covers S6. Covers SC6.
Steps:
  1. Register `legacy_handoff_v1_ownership` in `CASES` and its dispatch branch. Add disposable accepted, pre-V1, partial, duplicate top-level block, duplicate nested key, unknown, alias, path, child, symlink, and digest fixtures.
  2. Run `bash scripts/test-run-artifact-integrity.sh legacy_handoff_v1_ownership`; confirm RED because `v1` is rejected before ownership validation.
  3. Add a structured mapping reader for only `pre_merge_verification` and `v1`. Reject duplicate keys within a mapping while allowing the same nested key name across mappings.
  4. Validate the exact key sets, official acceptance relationship, six canonical distinct paths, optional `history`, regular-file boundary, receipt canonical-prefix digest equality, and whole-file manifest digest.
  5. Call ownership validation before legacy marker lookup or creation. Preserve the old path when all three V1 components are absent.
  6. Run the focused selector and existing legacy marker, schema, collision, and symlink controls. Commit: `fix(release-loop): validate legacy V1 ownership`.
Acceptance: the focused selector exits zero. Every rejected fixture proves no marker, unchanged source/base manifests, and no cleanup success payload.

## U2: Transfer and resume V1 under the active manifest

Execution note: test-first
Files:
  Create: none
  Modify: `skills/release-loop/scripts/run-artifact-integrity.py`, `scripts/test-run-artifact-integrity.sh`
  Test: `scripts/test-run-artifact-integrity.sh`
Interfaces:
  Consumes: validated V1 ownership, `legacy_handoff()`, `legacy_copy_child()`, and the handoff v2 marker
  Produces: exact V1 destination bytes, resumable partial directory state, or preserved blocked state
Test scenarios:
  happy: `legacy_handoff_v1_success` transfers nested V1 and optional history, returns cleanup authority, and discovers the exact base progress record.
  edge: `legacy_handoff_v1_partial_directory_rerun`, `legacy_handoff_source_changed`, and `legacy_handoff_complete_rerun` cover file-level interruption, changed source rejection, and complete idempotency.
  error: `legacy_handoff_v1_destination_mismatch` covers marker-absent filesystem/index V1, incomplete subset/extra/changed bytes; `legacy_handoff_v1_symlinks` covers source/base root and nested symlinks.
  integration: the success and partial selectors walk validated ownership through marker, recursive copy, retry, manifest equality, discovery, and cleanup authority. Covers S1, S2, S3. Covers SC1, SC2, SC3, SC4.
Steps:
  1. Register the six named U2 selectors in `CASES` and dispatch: V1 success, partial rerun, destination mismatch, symlinks, plus the missing `legacy_handoff_source_changed` and `legacy_handoff_complete_rerun` carry-forward selectors.
  2. Add RED fixtures with exact marker/source/base pre-state fingerprints. Require nonzero paths to prove no JSON cleanup result.
  3. Add exact `v1` active classification. Keep `archive`, `.handoff`, and `runs` persistent-only.
  4. Add `handoff-after-copy-one-file` inside recursive regular-file copy. Retain `handoff-after-copy-one` compatibility.
  5. Resume only exact destination subsets. Recompute source and destination manifests before completion. Reject extra, changed, index-only, and symlink states.
  6. Run all U2 selectors and existing legacy/scoped controls. Commit: `fix(release-loop): transfer legacy V1 evidence safely`.
Acceptance: all named U2 selectors and existing handoff controls exit zero. A success manifest is byte-identical. Every forced failure preserves its exact pre-state or documented partial subset.

## U3: Archive V1 and publish the lifecycle contract

Execution note: test-first
Files:
  Create: none
  Modify: `skills/release-loop/scripts/run-artifact-integrity.py`, `scripts/test-run-artifact-integrity.sh`, `skills/release-loop/references/transition-hooks.md`, `skills/release-loop/references/resume-and-archive.md`, `skills/release-loop/references/progress-schema.md`
  Test: `scripts/test-run-artifact-integrity.sh`, `scripts/validate.sh`
Interfaces:
  Consumes: a completed legacy ledger, validated V1 root, persisted archive destination, and archive publication journal
  Produces: terminal archive containing V1 and progress, progress-last commit semantics, the exact retained `archive_path`, and synchronized consumer documentation
Test scenarios:
  happy: `legacy_archive_v1_evidence` moves V1 and other active state into the exact terminal archive.
  edge: the existing first-child interruption moves only `.tmp`; rerun uses the same destination, then moves V1 and moves progress last.
  error: V1 archive symlink, changed source, foreign destination, and publication-journal mismatch preserve the selected progress record and block completion.
  integration: handoff success followed by base terminal archive leaves no active V1 orphan and preserves persistent children. Covers S4, S5. Covers SC5.
Steps:
  1. Register `legacy_archive_v1_evidence` in `CASES` and dispatch. Add success, first-child interruption, symlink, changed-source, foreign-destination, and journal-mismatch fixtures.
  2. Run the focused selector; confirm RED because legacy archive excludes `v1`.
  3. Add `v1` to legacy archive children after ownership validation. Preserve archive manifest publication and `progress.md` as the commit point. Retain and verify the exact terminal `archive_path` at the release-loop completion gate.
  4. Update the three reference documents with the exact ownership, digest, transfer, recovery, and terminal archive rules. Add contract mutation assertions to the focused selector.
  5. Run all six new selectors, both missing carry-forward selectors, existing legacy/scoped controls, `bash scripts/test-run-artifact-integrity.sh all`, and `bash scripts/validate.sh`.
  6. Commit: `fix(release-loop): archive legacy V1 evidence`.
Acceptance: focused archive cases pass. The aggregate suite executes every new selector. `bash scripts/validate.sh` prints `ALL CHECKS PASSED`.

## Mutation/failure-state matrix

Evidence root: `.release-loop/runs/legacy-handoff-v1-evidence/evidence/U<N>/`.
All probes use disposable repositories with local identity, disabled signing, and no remote.

| Transition | Success | Forced failure with expected post-state | Rerun | Rollback or compensation | Headless | Cancellation or abort | Owner / evidence |
|---|---|---|---|---|---|---|---|
| T1 V1 ownership admission | Exact accepted metadata returns validation and creates no marker. | Run `legacy_handoff_v1_ownership` with one-axis metadata mutants before marker creation. Exit is nonzero; source/base fingerprints and marker absence remain exact. The fixture root and named mutant prove the intended guard fired. | Repeating the rejected input returns the same diagnostic and unchanged fingerprints. | Remove only the disposable mutant or recreate the fixture. Production inputs are never modified. | Local validation has no outward target and may run headlessly with identical state. | Abort before validation changes nothing. Validation performs no durable write. | U1 / `evidence/U1/` |
| T2 legacy V1 handoff | Incomplete marker becomes complete only after exact transfer and base discovery. | Run `legacy_handoff_v1_partial_directory_rerun` with `handoff-after-copy-one-file`. Post-state is one incomplete owner marker plus an exact destination subset; source is unchanged. Mechanism evidence names the copied file and hook. | The same owner, source digest, and subset copy only missing bytes and complete once. Foreign or changed state blocks. | Preserve both roots and marker for retry. Manual removal is forbidden without owner and manifest proof. | The local transfer can run headlessly because fixtures have no remote or outward target. | Abort before marker changes nothing. Abort after marker preserves the incomplete marker and subset. | U2 / `evidence/U2/` |
| T3 legacy terminal archive | V1 and active children move to one persisted archive; progress moves last and the completion gate retains its exact `archive_path`. | Run `legacy_archive_v1_evidence` with `archive-after-first`. The existing hook fires after `.tmp`, so post-state is the persisted destination containing only `.tmp`, while source V1 and progress remain present. The hook and manifests prove the boundary. | The same destination resumes remaining children, moves V1, moves progress once, and reports the retained `archive_path`. | Preserve source progress, destination journal, and partial archive. Resume or perform owner-proven manual recovery; never allocate another suffix. | Archive is local-only and may run headlessly after proving no outward target. | Abort before the first move preserves source. Abort after `.tmp` preserves source V1 and progress plus the one-child destination. | U3 / `evidence/U3/` |

Changing a matrix row after approval requires the deviation process in
`docs/solutions/workflow-issues/review-introduced-state-machine-deviation.md`.

## Carry-forward trigger audit

| Tracker row | Trigger class | What fired it | Disposition |
|---|---|---|---|
| A success criterion that fires after Retro cannot be measured inside that Retro | event-based | The approved design declares terminal V1 archive proof after Retro. | Fold into U3: the release-loop completion gate retains and verifies the exact terminal `archive_path`; Retro does not claim this proof. |
| Forced-failure matrices can omit exact partial state and retain invalid shell syntax | edit-based, latched | PR #15 fired the row; this plan also defines a mutation/failure-state matrix. | Defer the reusable planning-contract change. This plan supplies executable probes, exact partial states, rerun behavior, and compensation owners without editing that contract. |
| Review verifies conformance instead of attacking the claimed invariant | edit-based, latched | PR #15 fired the row. | Defer because this plan does not edit the `reviewing` dispatch contract. The independent plan review still attacks the V1 ownership invariant. |
| Finding severity follows code blast radius instead of threatened success criteria | edit-based, latched | PR #15 fired the row. | Defer because this plan does not edit the review triage contract. |
| Dispatched committing agents lose `SSH_AUTH_SOCK` | edit-based, latched | PR #15 fired the row. | Fold into U1-U3 execution conditionally: any dispatched committer receives the socket explicitly and each resulting commit must report `%G? = G`. Inline commits do not activate this condition. |
| A retro committed on a feature branch must be merged or pushed with its ledger update | edit-based, latched | The run-artifact-integrity recovery fired the row. | Defer to the Shipping and Retro lifecycle because this implementation plan does not change that publication boundary. |
| `gh pr merge --delete-branch` can merge remotely before local cleanup fails | edit-based, latched | PRs #22 and #23 fired the row again. | Defer because this plan does not change Shipping merge commands. |
| Shipping lacks a per-fingerprint terminal-disposition gate | edit-based, latched | PR #22 partially fired the row. | Defer because this plan changes legacy artifact integrity, not the Shipping or release-loop merge gate. |
| Missing `legacy_handoff_source_changed` and `legacy_handoff_complete_rerun` cases | edit-based | The plan edits `scripts/test-run-artifact-integrity.sh` legacy handoff cases. | Fold into U2 so SC3 and SC4 receive their declared selectors. |
| Add `handoff-after-copy-one-file` | edit-based | The plan changes handoff fault injection and partial recovery. | Fold into U2 and T2 evidence. |

Audited `ROADMAP.md` at `59dcff696ba2aa3bfa24a46ed77baee5c41c2ac6`: 14 open rows, 10 fired, 0 unobservable.

## Deferred to Follow-Up Work

- Semantic validation of undigested approval and generation receipt content remains outside Issue #31. It requires a separate V1 authority design.
- Generic legacy-to-scoped migration remains excluded by the approved spec.
- Reusable forced-failure matrix syntax belongs to the next planning-contract change.
- Review invariant attacks and success-criterion severity belong to the next reviewing dispatch and triage contract changes.
- Retro publication and merge-command recovery belong to their next Shipping or Retro lifecycle changes.
- Shipping per-fingerprint terminal disposition remains tied to a future shipping merge-gate change.

## Open unknowns

### Planning-time

None.

### Implementation-time

- The structured parser helper name may follow the nearest local parser naming during U1.
- The exact failure diagnostic suffixes may follow existing `invalid progress` and `legacy handoff source` vocabulary.
