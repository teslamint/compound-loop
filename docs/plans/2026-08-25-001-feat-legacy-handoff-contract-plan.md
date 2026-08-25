---
schema: plan/v1
title: Legacy Handoff Contract
type: feat
status: draft
date: 2026-08-25
execution: code
origin: docs/specs/2026-08-25-legacy-handoff-contract-design.md
---

# Legacy Handoff Contract Implementation Plan

## Goal

Make one selected legacy ledger transferable to the base checkout without
overwriting archives, adopting foreign state, or permitting cleanup after a
partial transfer. Keep the existing scoped handoff behavior unchanged.

## Architecture notes

- The shared CLI owns the legacy decision. A caller must pass the literal
  `--legacy-destination .release-loop`; a scoped source rejects that argument.
- Legacy active state is the closed allowlist `progress.md`, `.tmp/`,
  `.phase-artifact-ownership.json`, `briefs/`, `reports/`, `reviews/`,
  `evidence/`, and `progress.md.corrupt-*`. The source rejects persistent and
  unknown root children. The base preserves `archive/`, `.handoff/`, and `runs/`.
- A canonical active-state manifest uses compact, sorted UTF-8 JSON and SHA-256.
  It binds one marker to the source, base, destination, feature, and bytes.
- The marker is the retry authority. Incomplete markers resume only an exact
  subset. Complete markers return success only for the exact complete set.
- A legacy marker has exactly the `release-loop-handoff/v2` schema, owner fields,
  literal destination, status, and lowercase 64-hex manifest digest. Its path is
  fixed to `.release-loop/.handoff/<feature>.json`; legacy callers cannot choose it.
- The CLI verifies source bytes again before completion and verifies base
  discovery before returning `cleanup_permitted: true`.
- No new dependency is needed. The standard library and the existing disposable
  fixture harness provide parsing, hashing, Git-index checks, and fault injection.
- Known Pattern: `docs/solutions/workflow-issues/loop-deliverable-in-disposable-state.md`
  requires manifest-verified state handoff before cleanup.
- Known Pattern: `docs/solutions/workflow-issues/procedural-skill-text-stateful-archive-contract.md`
  requires durable identity before mutation and executable interruption paths.

## Global constraints

- Preserve the archived original worktree and every existing archive entry.
- Add each failing fixture before the implementation that satisfies it.
- Use disposable local Git repositories with pinned identity, disabled signing,
  and disabled CRLF conversion.
- Reject a filesystem or Git-index collision before marker creation.
- Reject a symlink in every source or destination manifest component before hash,
  copy, discovery, or marker completion.
- Do not change archive format, scoped destination semantics, merge commands,
  or project-local configuration.
- Keep the legacy marker below the fixed `.release-loop/.handoff` root.
- Every guard gets an unchanged control and a one-axis attack using the same
  fixture artifact class.

## Assumption Recheck

| Approved claim | Fresh command evidence | Outcome |
|---|---|---|
| Current shared CLI rejects legacy handoff before marker creation. | A disposable source with `artifact_root: .release-loop` ran `handoff --repo <source> --base-repo <base> --progress-path .release-loop/progress.md` at `2026-08-25T10:59:53Z`. It returned `path boundary: legacy handoff requires an explicit legacy destination contract`. | match |
| The base root can retain archives without an active legacy record. | `ls -la /Users/teslamint/workspace/compound-loop/.release-loop` at `2026-08-25T10:59:53Z` listed only `archive/`. | match |

## File structure

| File | Responsibility |
|---|---|
| `skills/release-loop/scripts/run-artifact-integrity.py` | Legacy-only destination validation, active manifest creation, marker state transition, and result reporting. |
| `scripts/test-run-artifact-integrity.sh` | Disposable fixture controls and attacks for the CLI and contract text. |
| `skills/release-loop/references/transition-hooks.md` | Exact legacy invocation and pre-cleanup marker requirements. |
| `skills/release-loop/SKILL.md` | Release-loop handoff packet and Ship-resume rule for legacy records. |
| `skills/shipping/SKILL.md` | Ship cleanup prerequisite that requires a complete matching legacy marker. |

Files run without planned edits: `scripts/validate.sh`,
`skills/release-loop/references/progress-schema.md`, and
`skills/release-loop/references/resume-and-archive.md`.

## Requirements-to-units trace

| Spec success criterion | Units |
|---|---|
| SC1 archive-preserving success | U1, U2 |
| SC2 collision rejection | U1 |
| SC3 matching retry only | U1 |
| SC4 complete-marker idempotency | U1 |
| SC5 destination and symlink rejection | U1 |
| SC6 command-line contract | U1 |
| SC7 scoped control | U1 |
| SC8 full validation | U2 |

## Scenario coverage map

| S-ID | Unit chain | Integration test scenario |
|---|---|---|
| S1 resume after merge | U1 -> U2 | `legacy_handoff_success` transfers active bytes, preserves an archive digest, and makes the base discover `.release-loop/progress.md`. Covers S1. |
| S2 competing ledger | U1 -> U2 | `legacy_handoff_collision` and `legacy_handoff_index_collision` reject base active or foreign state before a marker write. Covers S2. |
| S3 interrupted handoff | U1 -> U2 | `legacy_handoff_incomplete_rerun` injects after one copy, then resumes only the recorded matching transfer. Covers S3. |
| S4 completed archives | U1 -> U2 | `legacy_handoff_success` compares the existing archive digest before and after the legacy handoff. Covers S4. |

## Implementation Units

Order: U1 -> U2. U1 is one atomic public CLI transition. U2 documents only the
verified command and cleanup outcome from U1.

## U1: Implement the complete safe legacy handoff transition

Execution note: test-first
Files:
  Create: none
  Modify: `skills/release-loop/scripts/run-artifact-integrity.py`, `scripts/test-run-artifact-integrity.sh`
  Test: `scripts/test-run-artifact-integrity.sh`
Interfaces:
  Consumes: `handoff(repo, base_repo, progress_path, marker_path, legacy_destination)` and a legacy ledger with `artifact_root: .release-loop`
  Produces: canonical active manifest digest, exact `.release-loop/.handoff/<feature>.json`, complete legacy base record, or named blocked diagnostic without cleanup authority
Test scenarios:
  happy: `legacy_handoff_success` transfers every allowlisted class, preserves an archive digest, discovers base legacy progress, and returns a complete marker.
  edge: `legacy_handoff_cli_contract` covers missing, literal, wrong, and scoped `--legacy-destination`, plus omitted-canonical and explicit-noncanonical legacy marker paths; `legacy_handoff_incomplete_rerun` resumes one copied child only.
  error: `legacy_handoff_collision`, `legacy_handoff_index_collision`, `legacy_handoff_destination_attacks`, `legacy_handoff_source_persistent_children`, `legacy_handoff_symlinks`, `legacy_handoff_marker_schema`, and `legacy_handoff_complete_destination_regression` preserve both roots and return no success payload.
  integration: `legacy_handoff_success` and `legacy_handoff_incomplete_rerun` walk S1-S4 with archive, marker, retry, discovery, and cleanup-authority assertions. Covers S1, S2, S3, S4.
Steps:
  1. Add the full legacy fixture family and optional `legacy_destination` test helper argument. Cover every allowed class, source and destination nested symlinks, Git-index collisions, source change, one-child interruption, and exact complete rerun. Run them and record RED because legacy sources are rejected.
  2. Add `--legacy-destination` to the parser. Require literal `.release-loop` for legacy roots; reject it for scoped roots. For legacy calls, derive `.release-loop/.handoff/<feature>.json` when `--marker-path` is omitted and reject only an explicit noncanonical override.
  3. Add one active-manifest helper. It enumerates only `progress.md`, `.tmp/`, `.phase-artifact-ownership.json`, `briefs/`, `reports/`, `reviews/`, `evidence/`, and `progress.md.corrupt-*`; rejects every nested source or destination symlink before hashing; and checks the filesystem plus Git index before marker creation.
  4. Define a legacy-only marker with exactly these keys: `schema`, `feature`, `progress_path`, `artifact_root`, `source_worktree`, `base_owner`, `destination`, `manifest_sha256`, and `status`. Require every value to be a string, `schema: release-loop-handoff/v2`, literal destination, lowercase 64-hex digest, and `status` in `incomplete | complete`. Reject unknown, missing, forged-complete, or invalid-status markers.
  5. Implement one atomic legacy path: write the incomplete canonical marker, copy only an exact subset, recheck source digest, verify base discovery, and write complete. Add `handoff-after-copy-one`. A nonzero result emits no JSON payload, so cleanup authority is absent; blocked fixtures assert that fact and preserve both roots.
  6. Run every U1 case, `bash scripts/test-run-artifact-integrity.sh all`, and `bash scripts/validate.sh`. Commit: `feat(release-loop): make legacy handoff recoverable`.
Acceptance: all legacy cases, `handoff_success`, `handoff_incomplete_rerun`, `bash scripts/test-run-artifact-integrity.sh all`, and `bash scripts/validate.sh` exit zero. The unchanged archive control matches its pre-transfer SHA-256. The matching marker returns success twice. Every changed-axis marker, source, destination, index, or symlink case exits nonzero with no JSON success payload.

## U2: Publish the legacy handoff and cleanup procedure

Execution note: test-first
Files:
  Create: none
  Modify: `skills/release-loop/references/transition-hooks.md`, `skills/release-loop/SKILL.md`, `skills/shipping/SKILL.md`, `scripts/test-run-artifact-integrity.sh`
  Test: `scripts/test-run-artifact-integrity.sh`, `scripts/validate.sh`
Interfaces:
  Consumes: a selected progress record, its `artifact_root`, and the CLI JSON result
  Produces: one literal legacy handoff command and one Ship cleanup prerequisite
Test scenarios:
  happy: contract fixture finds the literal legacy command and the complete-marker cleanup rule.
  edge: contract fixture accepts the scoped command without `--legacy-destination` and the legacy command with the literal.
  error: one-byte command and cleanup-condition mutations fail the contract fixture while the unchanged control passes.
  integration: `legacy_handoff_success` proves the documented command produces the documented result. Covers S1, S4.
Steps:
  1. Add contract controls and one-byte mutations to the fixture suite. Run them and record RED because existing transition text has no legacy argument or complete-marker rule.
  2. Update transition hooks and release-loop orchestration. Legacy records pass `--legacy-destination .release-loop`; scoped records omit it. State that archives, markers, and runs are never active transfer bytes.
  3. Update Ship. Require a matching complete marker, exact base discovery, and `cleanup_permitted: true` before local worktree cleanup. Preserve both roots on cancellation or any non-complete result.
  4. Run the contract cases, `bash scripts/test-run-artifact-integrity.sh all`, and `bash scripts/validate.sh`. Commit: `docs(shipping): require complete legacy handoff before cleanup`.
Acceptance: the unchanged command pair compares equal, each one-byte mutation compares different in its command or cleanup-condition signal, and the complete suite exits zero.

## Mutation/failure-state matrix

No outward target is reachable in these transitions. All probes use disposable
local repositories. Evidence paths are under `.release-loop/runs/legacy-handoff-contract/evidence/`.

| ID | Transition and owner | Pre-state -> action -> post-state | Success | Forced failure | Rerun | Compensation | Headless | Cancellation |
|---|---|---|---|---|---|---|---|---|
| T1 | U1 marker reservation; evidence U1 | empty validated roots -> preflight and marker write -> matching incomplete marker | Marker contains the exact schema, owner fields, and digest. | Fixture adds an active or index-only child; no marker and both roots stay unchanged. | Same empty roots create one marker. | Operator preserves the source; removes only a proven fixture marker after recording its bytes. | Allowed: local CLI has no outward target. | Before marker write, no mutation. After marker write, preserve incomplete marker and source. |
| T2 | U1 active-byte copy; evidence U1 | matching incomplete marker -> copy active manifest -> exact destination with incomplete marker | All active bytes match source. | `RUN_ARTIFACT_INTEGRITY_TEST_FAIL=handoff-after-copy-one` leaves one copied child, source intact, and marker incomplete. | Exact marker and subset copy only missing bytes. | Do not auto-delete partial state. Manual recovery preserves both roots or removes only fixture destination bytes after source verification. | Allowed: fixture calls only local Python and Git. | Preserve source, copied subset, and incomplete marker. |
| T3 | U1 completion; evidence U1 | exact copied bytes -> source recheck, discovery, marker completion -> complete marker and cleanup permission | Base discovers `.release-loop/progress.md`; marker is complete. | Fixture changes source after marker; marker stays incomplete and no success payload exists. | Exact complete marker plus exact destination returns success. Any absent, subset, mismatch, or invalid marker rejects. | Preserve both roots and marker for manual recovery; no automatic cleanup exists. | Allowed: exact local verification has no outward target. | After complete marker but before cleanup, preserve both owners; Ship decides later cleanup. |
| T4 | U2 Ship cleanup gate; evidence U2 | complete marker and base discovery -> authorize local cleanup -> source remains until Ship removes it | Ship text permits cleanup only after the three checks. | Contract mutant removes one check; fixture rejects the text. | Re-run rechecks the same complete marker and base record. | Failed or cancelled cleanup keeps the source worktree and marker; retry starts from the checks. | Not allowed: Ship USER gate owns worktree removal even though the handoff is local. | Preserve both roots and report no cleanup. |

## Carry-forward trigger audit

| Tracker row | Trigger class | What fired it | Disposition |
|---|---|---|---|
| Post-Retro terminal criterion | event-based | No post-Retro criterion is declared. | Deferred: this feature has no terminal post-Retro claim. |
| Forced-failure matrix precision | edit-based | Planned files do not change the planning matrix contract. | Deferred: U1-U2 comply with the current contract. |
| Persisted reviewer output | edit-based | Planned files do not change interview or reviewing dispatch steps. | Deferred: unrelated protocol work. |
| Invariant attack in reviewing | edit-based | Planned files do not change reviewing dispatch. | Deferred: U1-U2 use fixture attacks, not reviewing contract changes. |
| Severity by threatened criterion | edit-based | Planned files do not change review triage. | Deferred: unrelated review contract work. |
| Signed dispatched commits | event-based | No dispatched committer is selected at planning time. | Deferred: record signing evidence if the user selects subagent-driven execution. |
| Retro branch merge and ledger pointer | event-based | The Retro already merged in `f7300bec`; its preserved source worktree remains outside this plan. | Deferred: remove the worktree only after this feature ships and the handoff succeeds. |
| Split merge and cleanup commands | edit-based | Planned Ship edits do not change a merge command. | Deferred: the merge-command trigger did not fire. |
| Atomic body-seal publication | edit-based | Planned files do not include `scripts/test-body-seal.sh`. | Deferred: unrelated evidence publisher. |
| Shipping fingerprint dispositions | edit-based | Planned Ship edits do not change the merge gate. | Deferred: the merge-gate trigger did not fire. |
| Legacy selected-ledger handoff | edit-based | U1-U2 modify handoff and Ship cleanup contracts. | Fold as units U1 and U2. |
| Raw merged-result traces | event-based | No new merged-result failure occurs during planning. | Deferred: capture only if a future failure creates a follow-up. |

Audited `ROADMAP.md` at `2c0660df72a77e0bb99337d0f98a484724e43608`: 12 open rows, 1 fired, 0 unobservable.

## Deferred to Follow-Up Work

- Delete the preserved original worktree and stale local or remote branches only after this contract ships, the exact legacy handoff succeeds, and evidence tags receive separate user approval.
- Add the per-fingerprint Shipping terminal-disposition gate in its own merge-gate change.

## Self-review

- Assumption recheck: both retained commands match. No contradiction or unavailable claim remains.
- Spec coverage: SC1-SC8 map to U1-U2. Archive preservation, collision rejection, retry, idempotency, path attacks, CLI compatibility, scoped control, and full validation have a unit and command.
- Scenario coverage: S1-S4 each have an ordered unit chain and a disposable integration case.
- Failure coverage: T1-T4 name owner, pre-state, action, post-state, evidence path, success, forced failure, rerun, compensation, headless, and cancellation.
- Placeholder scan: no banned planning placeholder appears. `artifact_root`, marker, manifest, and cleanup result names are consistent.
- Callers and invariants: release-loop and Ship call the CLI; only the CLI writes markers; the base archive and scoped handoff stay outside the active manifest.
- Carry-forward audit: the final file list still fires only the legacy selected-ledger row.
- Architecture consistency: U1 enforces the boundary and recovery table, and U2 exposes the same literal contract to callers.
- Command closure: commands use literal paths or test case names without undeclared variables.
- Discrimination: U1 compares matching archive bytes with one changed active child, index path, marker byte, or symlink. U2 compares unchanged contract text with one-byte mutations in the command and cleanup-condition signals.

## Confidence check

Deepening applies because the feature changes a persistent state machine and
cleanup authority. Dispatch Architecture and Feasibility reviewers. Dispatch a
Security/Risk reviewer because path and symlink rejection are product behavior.

## Open unknowns

**Planning-time:** none.

**Implementation-time:**

- Exact helper names and exact fixture-case dispatch placement. The CLI argument,
  marker fields, state table, diagnostics, and acceptance commands remain fixed.
