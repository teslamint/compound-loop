---
schema: plan/v1
title: Run Artifact Integrity
type: fix
status: approved
date: 2026-08-23
execution: code
origin: docs/specs/2026-08-23-run-artifact-integrity-design.md
body_seal: 813e7492e1b8ae4a39027c0eed4aba8b2f422b2f606a9f18caf6a5d53c08936a
---

# Run Artifact Integrity Implementation Plan

## Goal

Prevent one release-loop run from overwriting another run's artifacts. Record exact lifecycle review totals and current Git evidence across resume, review, rewrite, handoff, archive, and Retro.

## Architecture notes

- **One artifact scope per run.** New release loops use the validated feature slug. Standalone implementing uses the validated approved-plan filename stem. The chosen progress path is the only phase handoff value.
- **Closed physical roots.** Active scoped state, legacy active state, the exact archive destination, and handoff state are the only allowed roots. Every existing source and destination component rejects symlinks before a write or move.
- **Occupied means blocked or resumed.** A nonempty selected scope resumes only from one valid matching progress record. Any other tracked or ignored content blocks before writing.
- **Additive schema.** `release-loop/v1` stays unchanged. New fields are optional for legacy readers. A resumed legacy ledger records `completeness: partial` and never invents historic events.
- **Registries before counters.** Review counts derive from append-only sealed review events and current finding dispositions. Callers never increment lifecycle totals directly.
- **Create-once results.** Each review event reserves one round-specific result path. Publication uses a same-directory temporary file, validation, SHA-256, and a create-once final path.
- **Exact-head gate.** A clean final or standalone review names one full head object ID. Any head change invalidates that gate.
- **Two-part rewrite evidence.** A current-session USER record precedes a history rewrite. A result record follows it. A result record alone grants no authority.
- **No new runtime dependency.** The implementation changes procedural contracts and deterministic fixture tests. It does not add a YAML library or a general run database.
- **Serial units.** U1 through U5 share lifecycle contracts and tests. Execute them in order to avoid divergent path and counter semantics.
- **Known Pattern:** `docs/solutions/workflow-issues/procedural-skill-text-stateful-archive-contract.md` requires a matrix for procedural text that authorizes durable transitions.
- **Known Pattern:** `docs/solutions/workflow-issues/universal-invariant-scope-enumeration-gap.md` requires an explicit inventory for every universal root and artifact claim.
- **Known Pattern:** `docs/solutions/workflow-issues/review-introduced-state-machine-deviation.md` keeps approved artifacts immutable when implementation discovers a new observable branch.

## Global Constraints

- Preserve unrelated local changes. Stage only unit-owned files.
- Write the failing fixture case before each contract change. Record the expected RED diagnostic before implementation.
- Use only disposable fixture repositories. Configure `user.name`, `user.email`, `core.autocrlf=false`, `core.safecrlf=false`, and `commit.gpgsign=false` in every fixture.
- Never configure a hosted remote, credential, token, or non-loopback endpoint in a fixture.
- Keep `review_rounds` as the standalone retry cap. Keep pull request feedback counters separate from internal finding counters.
- Do not change review severity rules, round caps, merge commands, or cleanup command semantics.
- Persist reviewer and facilitator output verbatim in immutable scoped artifacts. A ledger summary never replaces the original result.
- Every integrity review constructs the cheapest conforming counterexample and grades findings against the threatened success criterion.
- Every review-body and outside-diff finding receives a stable fingerprint and terminal disposition before a clean gate.
- When a dispatched worker commits, pass the live `SSH_AUTH_SOCK`. Record `%G? = G` for each unit commit. Inline execution records that no dispatched committer ran.
- Every guard fixture has one same-kind control that passes and one minimally changed attack that fails for the intended mechanism.
- After each U1-U5 commit, the orchestrator runs `git log -1 --format=%G?` and requires `G`. The same ledger edit records the unit, commit, signature result, and whether a dispatched committer ran.

## Assumption Recheck

Origin spec retains four live assumptions. All four commands ran at `2026-08-23T13:08:13Z` against `5f3036b767a5e951aa0ab711832daa24c64915d1`.

| Approved claim | Fresh command evidence | Outcome |
|---|---|---|
| Implementing uses fixed root paths for unit artifacts. | `rg -n -e '\.release-loop/briefs/U<N>' -e '\.release-loop/reports/U<N>' -e '\.release-loop/reviews/U<N>' skills/implementing/SKILL.md` returned lines 88, 89, and 111. | match |
| The progress schema has only retry and pull request feedback counters. | `sed -n '33,43p' skills/release-loop/references/progress-schema.md` showed `review_rounds`, `feedback_rounds`, and comment counters only. | match |
| Ignoring `.release-loop/` does not protect an already tracked report. | `git -C /tmp/run-artifact-integrity.19f9e8 ls-files --error-unmatch .release-loop/reports/U1-report.md && git -C /tmp/run-artifact-integrity.19f9e8 status --short` returned the tracked path and ` M .release-loop/reports/U1-report.md`. | match |
| The pre-change repository validation gate passes. | `bash scripts/validate.sh` returned `ALL CHECKS PASSED`. | match |

## File structure

| File | Responsibility |
|---|---|
| `scripts/test-run-artifact-integrity.sh` | Disposable Git fixtures for scope, event, rewrite, handoff, archive, and Retro contracts. |
| `skills/release-loop/SKILL.md` | Run selection, exact progress handoff, review state updates, and exact-head phase gates. |
| `skills/release-loop/references/progress-schema.md` | Additive scope, event, disposition, count, commit-range, and review-gate fields. |
| `skills/release-loop/references/resume-and-archive.md` | Scoped and legacy discovery, exact selector rules, safe archive roots, and progress-last completion. |
| `skills/release-loop/references/transition-hooks.md` | Handoff ownership and closed-root validation before worktree removal. |
| `skills/planning/SKILL.md` | Exact progress-path handoff and executable partial-state matrix requirements. |
| `skills/planning/schemas/plan-schema.md` | Scoped evidence-root wording and forced-failure probe contract. |
| `skills/implementing/SKILL.md` | Scoped unit artifacts, event allocation, fix ownership, final review events, and resume behavior. |
| `skills/reviewing/SKILL.md` | Standalone events, exact-head reuse, verbatim outputs, and complete finding disposition. |
| `skills/reviewing/references/merge-pipeline.md` | Stable fingerprints and complete review-body or outside-diff inventory. |
| `skills/shipping/SKILL.md` | Pre-mutation rewrite approval, post-mutation result, and exact-head invalidation. |
| `skills/retrospective/SKILL.md` | Structured exact or partial totals, commit-range validation, and facilitator result artifacts. |
| `schemas/retro-template.md` | Separate lifecycle review, fix, finding, and pull request comment metrics. |
| `scripts/test-plan-consumer-portability.sh` | Standalone consumer fixtures for exact progress paths and scoped evidence roots. |
| `scripts/test-retro-format-drift.sh` | Retro metric shape and exact or partial rendering mutations. |
| `scripts/validate.sh` | Registration of the focused run-integrity contract suite and updated path checks. |

Files run without planned edits: `scripts/test-planning-schema-portability.sh`, `scripts/test-final-action-skip.sh`, and `scripts/test-release-loop-worktree-default.sh`. Modify one only if its RED output proves an in-scope contract dependency.

## Requirements-to-Units trace

| Requirement | Units |
|---|---|
| R1, R3, R4, R5, R10 | U1, U2, U5 |
| R2 | U2 |
| R6, R7 | U3, U5 |
| R8 | U4 |
| R9 | U5 |

## Scenario coverage map

| S-ID | Unit chain | Integration test scenario |
|---|---|---|
| S1 scoped artifacts | U1 -> U2 -> U5 | `stateful_scoped_lifecycle` creates all applicable scoped artifacts, hands state off, and archives the exact scope. Covers S1. |
| S2 tracked collision | U1 -> U2 | `tracked_legacy_preserved` and `occupied_scope_blocked` preserve the old blob and fail before selected-scope writes. Covers S2. |
| S3 exact review metrics | U3 -> U5 | `review_event_lifecycle` exercises actionable review, fix, clean re-review, final review, replay, and derived totals. Covers S3. |
| S4 history rewrite | U4 -> U5 | `authorized_rewrite_refresh` records approval before rebase, refreshes full object IDs, preserves counts, and requires a new exact-head review. Covers S4. |
| S5 Retro aggregates | U3 -> U4 -> U5 | `retro_structured_metrics` deletes narrative review lines and renders the same exact totals from structured fields. Covers S5. |

## Implementation Units

Order: U1 -> U2 -> U3 -> U4 -> U5. Shared files and contracts require serial execution.

## U1: Scoped run discovery, closed roots, handoff, and archive

Execution note: test-first
Files:
  Create: scripts/test-run-artifact-integrity.sh
  Modify: skills/release-loop/SKILL.md, skills/release-loop/references/progress-schema.md, skills/release-loop/references/resume-and-archive.md, skills/release-loop/references/transition-hooks.md, scripts/validate.sh
  Test: scripts/test-run-artifact-integrity.sh, scripts/test-release-loop-worktree-default.sh, scripts/test-final-action-skip.sh
Interfaces:
  Consumes: validated `feature_slug`, current repository root, optional exact repo-relative progress path
  Produces: `.release-loop/runs/<feature_slug>/progress.md`, validated `artifact_root`, one of `new | resume | blocked`, exact archive destination
Test scenarios:
  happy: `new_scoped_run` creates one scoped progress record and `archive_scoped_run` moves that scope with progress last. Covers AE1.
  edge: `one_live_record`, `multiple_live_records`, `valid_legacy_record`, and `interrupted_archive` select only exact durable identities. Covers AE3.
  error: `ignored_orphan`, `tracked_scope_target`, `absolute_outside_root`, `relative_parent_escape`, `scoped_symlink`, `legacy_symlink`, `archive_symlink`, and `handoff_symlink` fail before mutation and preserve external sentinels. Covers AE2, AE3, AE12.
  integration: `stateful_scoped_lifecycle` starts, hands off, and archives one exact scope without a new root-level artifact. Covers S1, S2.
Steps:
  1. Create `scripts/test-run-artifact-integrity.sh` with named case dispatch and pinned fixture Git configuration. Run `bash scripts/test-run-artifact-integrity.sh scope`; record RED because current text selects fixed root paths and has no closed-root guard.
  2. Add scoped creation and discovery to `skills/release-loop/SKILL.md` and `progress-schema.md`. Reject occupied orphan scopes. Require an exact repo-relative progress path when discovery is ambiguous.
  3. Update `resume-and-archive.md` and `transition-hooks.md` with the four closed root families. Validate every existing source and destination component. Preserve the exact archive destination and move scoped progress last.
  4. Register the focused suite in `scripts/validate.sh`. Run the U1 Test files and confirm all U1 cases pass without touching a real target.
  5. Commit: `fix(release-loop): isolate run state before artifact writes`
Acceptance: `bash scripts/test-run-artifact-integrity.sh scope`, `bash scripts/test-release-loop-worktree-default.sh`, `bash scripts/test-final-action-skip.sh`, and `bash scripts/validate.sh` exit zero. The focused suite reports each named collision, direct escape, and sentinel case as passed. The U1 commit reports `%G? = G` in the ledger.

## U2: Thread the exact ledger path through every consumer

Execution note: test-first
Files:
  Create: none
  Modify: skills/planning/SKILL.md, skills/planning/schemas/plan-schema.md, skills/implementing/SKILL.md, skills/reviewing/SKILL.md, skills/shipping/SKILL.md, skills/retrospective/SKILL.md, scripts/test-run-artifact-integrity.sh, scripts/test-plan-consumer-portability.sh
  Test: scripts/test-run-artifact-integrity.sh, scripts/test-plan-consumer-portability.sh, scripts/test-planning-schema-portability.sh
Interfaces:
  Consumes: exact `progress_path` from the release-loop orchestrator, or a validated approved-plan filename stem for standalone implementing
  Produces: `artifact_root = dirname(progress_path)`, scoped `briefs`, `reports`, `reviews`, and conditional `evidence` paths
Test scenarios:
  happy: `all_consumers_one_root` gives every phase the same progress path and resolves one artifact root. Covers AE1.
  edge: `stateless_no_evidence` creates no evidence path; `legacy_resume_guarded` lets the active ledger update while checking each sibling target. Covers AE1, AE11.
  error: `tracked_legacy_preserved` and `tracked_selected_target` preserve blobs and stop before sibling writes. Covers AE2, AE3.
  integration: `stateful_scoped_lifecycle` creates scoped progress, brief, report, review, and evidence without new legacy-root artifacts. Covers S1, S2.
Steps:
  1. Extend the focused and portability suites with exact-progress-path fixtures. Run both suites; record RED from current `.release-loop/progress.md` and sibling path literals.
  2. Update all six phase consumers to accept or use the exact progress path. Derive every sibling artifact path from its containing root. Keep the valid legacy active ledger exempt from its own sibling collision check.
  3. Update planning's matrix contract and `plan-schema.md`. Evidence owners use `<artifact_root>/evidence/U<N>/`. Every forced failure names an executable probe, exact partial durable state, and compensation owner.
  4. Run the U2 Test files. Confirm standalone planning and implementing fixtures work without a release-loop sibling and no fixed-root artifact write remains.
  5. Commit: `fix(skills): thread scoped ledger paths through phase consumers`
Acceptance: `bash scripts/test-run-artifact-integrity.sh consumers`, `bash scripts/test-plan-consumer-portability.sh`, `bash scripts/test-planning-schema-portability.sh`, and `bash scripts/validate.sh` exit zero. A source scan finds no operative new-run write to `.release-loop/progress.md`, `briefs`, `reports`, `reviews`, or `evidence` outside the legacy branch. The U2 commit reports `%G? = G` in the ledger.

## U3: Seal review events and derive finding totals

Execution note: test-first
Files:
  Create: none
  Modify: skills/release-loop/references/progress-schema.md, skills/implementing/SKILL.md, skills/reviewing/SKILL.md, skills/reviewing/references/merge-pipeline.md, scripts/test-run-artifact-integrity.sh
  Test: scripts/test-run-artifact-integrity.sh
Interfaces:
  Consumes: event kind `unit | fix | final | standalone`, subject, next persisted ordinal, full reviewed head, existing stable finding fingerprints
  Produces: event ID `<kind>:<subject>:<ordinal>`, create-once result path and SHA-256, append-only `review_events`, current `finding_dispositions`, derived `review_counts`
Test scenarios:
  happy: `review_event_lifecycle` produces unit passes 2, fix rounds 1, final passes 1, and fixed findings only after clean re-review. Covers AE4, AE6.
  edge: `event_replay`, `matching_started_result`, `deferred_then_fixed`, `phase_gate_reuse`, and `outside_diff_inventory_complete` preserve idempotency and accept one complete inventory. Covers AE4, AE5, AE7.
  error: `event_conflict`, `completed_result_missing`, `completed_digest_mismatch`, `fix_cannot_mark_fixed`, and `outside_diff_missing_disposition` fail with exact diagnostics. Covers AE5, AE6.
  integration: `standalone_and_reuse` dispatches one standalone review, reuses its exact-head gate, and reports standalone passes 1. Covers S3, S5.
Steps:
  1. Add event, recovery, conflict, digest, disposition, and outside-diff cases to the focused suite. Run `bash scripts/test-run-artifact-integrity.sh reviews`; record RED because the schema has no registries or create-once results.
  2. Add the additive schema fields and derivation rules. Allocate an event before dispatch. Publish validated results through a same-directory temporary path and persist the final digest.
  3. Update implementing and reviewing. Use round-specific immutable artifacts. Let only a verifying re-review set `fixed`. Persist reviewer output verbatim. Require the cheapest conforming counterexample for every integrity mechanism.
  4. Update merge-pipeline. Include review-body and outside-diff findings in the stable-fingerprint inventory. Reject a clean gate while any actionable fingerprint lacks a terminal disposition.
  5. Commit: `fix(reviewing): derive durable metrics from sealed events`
Acceptance: `bash scripts/test-run-artifact-integrity.sh reviews` and `bash scripts/validate.sh` exit zero. The suite proves replay idempotency, result integrity, disposition ownership, exact counts, verbatim artifacts, and outside-diff inventory. The complete inventory control returns clean. The missing-disposition mutant blocks. The U3 commit reports `%G? = G` in the ledger.

## U4: Bind review gates to exact heads and authorize rewrites before mutation

Execution note: test-first
Files:
  Create: none
  Modify: skills/release-loop/SKILL.md, skills/release-loop/references/progress-schema.md, skills/implementing/SKILL.md, skills/reviewing/SKILL.md, skills/shipping/SKILL.md, scripts/test-run-artifact-integrity.sh
  Test: scripts/test-run-artifact-integrity.sh
Interfaces:
  Consumes: base branch, full current head, current-session USER rewrite approval, exact rewrite command and target base
  Produces: `current_commit_range`, `review_gate = {event_id, head}`, pre-mutation approval record, post-mutation result record, `stale-commit-range` on unauthorized divergence
Test scenarios:
  happy: `authorized_rewrite_refresh` records approval first, updates full object IDs, preserves event counts, and clears the old gate. Covers AE8.
  edge: `descendant_head_invalidates` refreshes the head and clears the gate without rewrite approval; `shipping_command_invariance` compares the pinned baseline command blocks with an unchanged same-kind copy. Covers AE10.
  error: `unapproved_rewrite`, `mismatched_approval`, `rewrite_conflict`, and `cancelled_approval_rejected` block or abort while preserving the old authoritative range. Covers AE9.
  integration: `fresh_review_after_rewrite` permits the phase gate only after a final or standalone event reviews the new exact head; `shipping_command_changed_axis` changes one fixture command byte and proves the comparison detects that command signal. Covers S4.
Steps:
  1. Add descendant, approved rewrite, unapproved rewrite, approval mismatch, conflict, cancelled-approval, and fresh-review cases. Run `bash scripts/test-run-artifact-integrity.sh history`; record RED from absent structured range and exact-head fields.
  2. Add `current_commit_range` and `review_gate` rules to the schema and orchestrator. Clear the gate on every head change.
  3. Update implementing and reviewing so each complete review event records the full head. Phase-gate reuse requires exact equality with current HEAD.
  4. Update shipping. Persist current-session USER approval with the old range, command, and target before rebase. Persist result, exit status, verification command, and new range afterward. Keep merge and cleanup commands unchanged.
  5. Commit: `fix(shipping): bind rewrite evidence to exact reviewed heads`
Acceptance: `bash scripts/test-run-artifact-integrity.sh history` and `bash scripts/validate.sh` exit zero. The history group compares shipping's merge and cleanup command blocks with `git show 5f3036b767a5e951aa0ab711832daa24c64915d1:skills/shipping/SKILL.md`; the unchanged pair is equal and the one-byte command mutant differs in the command signal. The U4 commit reports `%G? = G` in the ledger.

## U5: Render structured Retro metrics and prove the lifecycle

Execution note: test-first
Files:
  Create: none
  Modify: skills/retrospective/SKILL.md, schemas/retro-template.md, scripts/test-retro-format-drift.sh, scripts/test-run-artifact-integrity.sh, scripts/validate.sh
  Test: scripts/test-retro-format-drift.sh, scripts/test-run-artifact-integrity.sh, all scripts/test-*.sh
Interfaces:
  Consumes: exact or partial `review_counts`, `counting_started_at`, current commit range, pull request feedback counters, scoped facilitator artifacts
  Produces: Review rounds breakdown, fix rounds, internal finding dispositions, separate pull request comments, lower-bound legacy label, exact archive completion evidence; missing legacy completeness becomes `partial`, and an unknown value blocks
Test scenarios:
  happy: `retro_structured_metrics` removes narrative review lines and renders unchanged exact totals; `full_validation_gate` runs the exact repository command list. Covers AE11, AE13.
  edge: `legacy_partial_metrics` renders a lower bound since the recorded start; `stateless_no_evidence` retains no irrelevant matrix evidence. Covers AE1, AE11.
  error: `retro_stale_range` blocks measurement; `facilitator_artifact_missing` prevents an evidence-backed review count claim; `unknown_count_completeness` blocks instead of guessing. Covers AE9, AE11.
  integration: `full_lifecycle` walks scoped start, all artifact classes, review events, rewrite, fresh review, Retro, handoff, archive, and exact completion verification. Covers S1, S2, S3, S4, S5.
Steps:
  1. Add retro format mutations and full-lifecycle cases. Run the two focused suites; record RED from narrative-only totals, fixed metric shape, and missing scoped facilitator results.
  2. Update retrospective and the template. Compute review rounds from unit, final, and standalone passes. Show fix rounds and internal findings separately from pull request comments. Label legacy totals as partial.
  3. Persist each facilitator round verbatim under the selected scoped reviews directory. Revalidate the current commit range before Retro measurement.
  4. Complete `scripts/validate.sh` registration. Run these exact commands: `bash scripts/test-body-seal.sh`; `bash scripts/test-final-action-skip.sh`; `bash scripts/test-manifest-version-sync.sh`; `bash scripts/test-plan-consumer-portability.sh`; `bash scripts/test-plan-frontmatter.sh`; `bash scripts/test-planning-schema-portability.sh`; `bash scripts/test-plugin-skill-discovery.sh`; `bash scripts/test-python-compatibility.sh all`; `bash scripts/test-python-compatibility.sh fixtures`; `bash scripts/test-release-loop-worktree-default.sh`; `bash scripts/test-release-publication.sh all`; `bash scripts/test-retro-format-drift.sh`; `bash scripts/test-signal-drift.sh`; `bash scripts/test-run-artifact-integrity.sh all`; `bash scripts/validate.sh`; `git diff --check`.
  5. Commit: `fix(retrospective): render exact scoped review evidence`
Acceptance: every exact U5 step 4 command exits zero; `bash scripts/validate.sh` reports `ALL CHECKS PASSED`; `git diff --check` is empty; the full-lifecycle fixture proves all thirteen spec criteria. The U5 commit reports `%G? = G` in the ledger.

## Mutation/failure-state matrix

All matrix evidence uses disposable fixtures. Evidence owners write one record per cell under `<artifact_root>/evidence/U<N>/`. The fixture inventory contains no hosted remote, credential, token, or non-loopback endpoint.

### Transition inventory

| Transition | Pre-state | Action | Expected post-state | Owning unit | Evidence owner |
|---|---|---|---|---|---|
| T1 `initialize-run-scope` | Valid repository root; selected scope absent or empty; no matching live record | Validate the selector and closed root, then create the scoped progress record | One valid scoped progress record; legacy paths and external sentinels unchanged | U1 | U1 `<artifact_root>/evidence/U1/` |
| T6 `publish-scoped-phase-artifact` | Valid exact progress path; derived sibling target absent or verified as this run's matching artifact | Write an applicable brief, report, review, or evidence artifact under the derived root | One owned scoped artifact; tracked legacy and outside-root paths unchanged | U2 | U2 `<artifact_root>/evidence/U2/` |
| T2 `publish-review-result-and-ledger-event` | One persisted started event with reserved result path and unchanged derived counters | Validate a temporary result, publish it once, store its digest, and complete the event | One immutable result, one complete event, and registry-derived counters | U3 | U3 `<artifact_root>/evidence/U3/` |
| T3 `authorized-history-rewrite` | Current range and review gate known; current-session USER approval absent | Persist approval, run the exact rewrite, verify the result, and refresh the range | New verified range, old gate cleared, prior events preserved, result recorded | U4 | U4 `<artifact_root>/evidence/U4/` |
| T4 `handoff-active-scope` | Active scope owned by a feature worktree; base owner lacks accepted state | Persist owner marker, transfer exact state, and verify resume at the base owner | Base owner resumes exact scope; feature worktree becomes removable | U1; U5 verifies | U1 `<artifact_root>/evidence/U1/`; U5 verifies the retained record |
| T5 `archive-run-scope` | Retro committed; exact active progress and archive destination known | Persist destination, move remaining children, move progress last, and verify | No live progress; one exact complete archive with Retro evidence | U1; U5 verifies | U1 `<artifact_root>/evidence/U1/`; U5 verifies the retained record |

### Outcome matrix

| Transition | Success | Forced failure with exact partial state | Rerun | Rollback or compensation | Headless | Cancellation or abort |
|---|---|---|---|---|---|---|
| T1 `initialize-run-scope` (U1) | `bash scripts/test-run-artifact-integrity.sh new_scoped_run` creates one validated scope and progress record. No legacy artifact changes. | `bash scripts/test-run-artifact-integrity.sh occupied_scope_blocked`, `bash scripts/test-run-artifact-integrity.sh absolute_outside_root`, and `bash scripts/test-run-artifact-integrity.sh relative_parent_escape` inject ignored or tracked content and direct path escapes. Each exits nonzero. The selected scope bytes, old blob, HEAD, index, and external sentinel stay unchanged. U1 owns fixture cleanup. | Repeating a blocked case returns the same paths and state. After U1 removes only the disposable injected orphan, one retry creates exactly one progress record. | Before progress publication, U1 removes only an empty created fixture scope. After valid progress exists, compensation is archive-incomplete or resume; it never deletes the live record. | An unattended ambiguous selector returns blocked context before scope creation. No prompt is inferred and no file changes. | Pre-create cancellation leaves no scope. Post-directory/pre-progress cancellation removes only the proven empty fixture directory. A published progress record remains resumable. |
| T6 `publish-scoped-phase-artifact` (U2) | `bash scripts/test-run-artifact-integrity.sh all_consumers_one_root` writes each applicable phase artifact under the one derived root. No new legacy artifact appears. | `bash scripts/test-run-artifact-integrity.sh tracked_selected_target` injects a tracked sibling target. It exits nonzero; active progress, target blob, index, HEAD, and external sentinel remain unchanged. U2 owns fixture cleanup. | A matching owned artifact is reused under the same run identity. A different existing artifact blocks with its exact path. No retry allocates another root. | U2 removes only a transition-owned temporary file after ownership proof. It never deletes a tracked target or another run's final artifact. | Headless consumers use the supplied exact progress path. Missing or ambiguous paths return blocked context before a sibling write. | Pre-write cancellation changes nothing. Post-temporary/pre-final cancellation removes only the owned temporary file. A final matching artifact remains resume evidence. |
| T2 `publish-review-result-and-ledger-event` (U3) | `bash scripts/test-run-artifact-integrity.sh review_event_lifecycle` reserves one event, publishes one validated result, stores its digest, completes the event, and derives counters. | `bash scripts/test-run-artifact-integrity.sh event_conflict` pre-creates a different final result. The event remains `started`; the final artifact and counters remain unchanged; the conflict diagnostic names the event. U3 owns temporary-file cleanup. | A matching sealed result completes the same started event without dispatch. A missing result re-dispatches the same ID. A conflict repeats without allocating another ID. | U3 may remove only an event-owned temporary file after proving ownership. A missing or mismatched completed result requires manual repair; no replacement event bypasses integrity failure. | Pipeline review follows the same event publication path. Missing worker output leaves the event started and returns blocked context; no USER gate is invented. | Cancellation before dispatch leaves a started event for resume. Cancellation after final publication but before ledger completion verifies the digest and completes the same event. |
| T3 `authorized-history-rewrite` (U4) | `bash scripts/test-run-artifact-integrity.sh authorized_rewrite_refresh` records USER approval before a disposable rebase, records the result afterward, refreshes full IDs, preserves counts, and clears the gate. | `bash scripts/test-run-artifact-integrity.sh rewrite_conflict` injects a disposable rebase conflict. After abort, HEAD and the authoritative old range match the pre-state; the failed result and approval remain historical; the gate is not reusable. U4 owns abort verification. | Every failed or cancelled attempt needs fresh current-session approval. A successful retry writes one new result and range. It never reuses old approval as authority. | U4 runs the fixture's exact `git rebase --abort`, verifies the old range, and records failure. Published history is never rewritten in these fixtures. | Missing first-hand approval returns `stale-commit-range` before the rebase command. HEAD, range, counts, and gate stay unchanged. | Pre-command cancellation writes a terminal cancelled result that invalidates the approval. Mid-conflict cancellation aborts, verifies the old range, records cancellation, and invalidates approval. `cancelled_approval_rejected` proves neither record can authorize a later mutation. |
| T4 `handoff-active-scope` (U1, verified U5) | `bash scripts/test-run-artifact-integrity.sh handoff_success` writes an owned handoff marker, transfers the exact active scope to the base owner, verifies resume there, then permits worktree removal. | `bash scripts/test-run-artifact-integrity.sh handoff_symlink` injects a symlinked destination component. It exits nonzero; the external sentinel and destination stay unchanged; the source scope and owner marker remain. U1 owns fixture cleanup. | A matching owner marker resumes only incomplete transfer steps. It never copies a second progress record or chooses another destination. | Before source removal, U1 removes only a hash-matching incomplete fixture destination. If source identity cannot be proven, manual recovery preserves both copies and blocks cleanup. | This local transition may complete headlessly only after proving every outward target unreachable and the owner marker exact. Otherwise it returns blocked context. | Cancellation preserves the source worktree. A partial target remains marked incomplete, and the next invocation resumes from the owner marker before cleanup. |
| T5 `archive-run-scope` (U1, verified U5) | `bash scripts/test-run-artifact-integrity.sh archive_scoped_run` persists one destination, moves remaining scoped children, moves progress last, and verifies the exact archive. | `bash scripts/test-run-artifact-integrity.sh archive_symlink` injects a symlinked destination component. It exits nonzero before a move; the source scope, destination, HEAD, and external sentinel stay unchanged. U1 owns fixture cleanup. | An interrupted rerun reuses the recorded destination and moves only remaining children. It never recalculates a suffix. | Reverse movement is not a valid rollback because the archive is terminal local state. Compensation is to finish the same recorded destination. Ambiguous bytes require manual recovery without source deletion. | After Retro exit, archive may complete headlessly because it is local-only. It still validates the exact root, destination, retro commit, and absence of outward targets. | Pre-move cancellation leaves the recorded destination and source. Mid-move cancellation leaves progress in the source as the commit point; the successor resumes the same destination. |

## Carry-forward trigger audit

| Tracker row | Trigger class | What fired it | Disposition |
|---|---|---|---|
| ROADMAP line 55: post-Retro criteria | event-based | Spec S1 and AE13 require archive proof after Retro exits. | Fold into U5 and the release-loop completion gate. Retain the exact archive path. |
| ROADMAP line 56: forced-failure matrix partial states | edit-based, latched | U2 changes the planning matrix and evidence-root contract. | Fold into U2 and this matrix. Each forced failure names a probe, exact partial state, and owner. |
| ROADMAP line 57: reviewer output not persisted | edit-based | U3 changes reviewing dispatch; U5 changes facilitator handling. | Fold into U3 reviewer results and U5 facilitator artifacts. Persist both verbatim. |
| ROADMAP line 58: conformance-only review | edit-based, latched | U3 changes integrity review dispatch. | Fold into Global Constraints and U3. Require the cheapest conforming counterexample. |
| ROADMAP line 59: severity by blast radius | edit-based, latched | Finding disposition work is adjacent to triage. | Defer because approved Scope Out forbids severity changes. Preserve the row and current severity contract. |
| ROADMAP line 60: unsigned dispatched commits | event-based, latched | The execution strategy can use committing workers. | Fold into U1-U5 acceptance and Global Constraints. Pass `SSH_AUTH_SOCK`; record each `%G? = G` result and execution owner. |
| ROADMAP line 62: combined merge and cleanup command | edit-based, latched | U4 changes shipping rebase evidence, not merge-command semantics. | Defer. U4 proves merge and cleanup command blocks remain byte-equal. |
| ROADMAP line 64: unresolved outside-diff findings | edit-based, latched | U3 and U4 change finding disposition and exact-head review gates. | Fold into U3 and U4. Inventory every review-body and outside-diff fingerprint before clean. |

Audited ROADMAP.md Carry-forward from retros at 5f3036b767a5e951aa0ab711832daa24c64915d1: 11 open rows, 8 fired, 0 unobservable.

Not fired at planning time: ROADMAP line 61 fires during isolated-worktree Retro; line 63 requires a `scripts/test-body-seal.sh` publication change; line 65 fires at PR merge. The release-loop must perform the line 61 handoff and line 65 Retro obligations when those events occur.

## Deferred to Follow-Up Work

- ROADMAP line 59 severity-contract change. Reason: the approved spec excludes review severity changes. U3 adds dispositions without changing grading.
- ROADMAP line 62 merge-command decomposition. Reason: U4 changes rebase evidence only. The merge and cleanup command contract stays byte-equal.
- The broader cross-harness conformance suite. Reason: issues #20 and #21 require this scoped lifecycle fixture, not every degraded dispatch tier.

## Risks and Dependencies

- **Procedural text and fixture model could drift.** Each case names the exact operative clause it proves. `scripts/validate.sh` runs the focused suite.
- **Shared-file unit overlap could cause lost edits.** Units run serially. Each unit reviews the current full file before editing.
- **Legacy counts could be presented as exact.** U5 requires `partial` plus a counting start timestamp and lower-bound wording.
- **Symlink validation could block valid archive or handoff paths.** U1 tests all four closed root families with control and attack fixtures.
- **History rewrite approval could be recorded after mutation.** U4 tests record order and rejects result-only evidence.
- **External dependencies:** none. All implementation and verification use repository tools, Git, shell, and Python standard library already used by existing suites.

## Plan self-review record

- **Assumption flows:** all four retained claims are `match`. The planning contract still keeps contradiction as a commit blocker and unavailable evidence as an open unknown. No-origin and zero-assumption wording remains unchanged.
- **Spec coverage:** R1 through R10 and all thirteen acceptance criteria map to U1 through U5. No mitigation lacks a unit or Deferred entry.
- **Scenario coverage:** S1 through S5 each have a complete ordered unit chain and one named integration scenario.
- **Verdict coverage:** scope discovery handles `new`, `resume`, and `blocked`. Measurement failure and any out-of-set result fail closed as `blocked`. Count completeness handles `exact` and `partial`; missing legacy values become `partial`, while unknown values block.
- **Mutation completeness:** T1 through T6 each contain success, forced failure, rerun, compensation, headless, and cancellation outcomes. Every forced failure names a command, exact partial state, and owner.
- **Placeholder and type checks:** no banned placeholder remains. `progress_path`, `artifact_root`, event IDs, fingerprints, counts, range, and gate types stay consistent across units.
- **Callers and invariants:** release-loop owns the exact progress path. Phase consumers derive siblings. Review counts derive from registries. Shipping alone records rewrite execution results.
- **Carry-forward:** the final file list still yields 11 open rows, 8 fired, and 0 unobservable. Each fired row is folded or explicitly deferred.
- **Architecture consistency:** every unit preserves additive schema compatibility, closed roots, create-once results, exact-head gates, and two-part rewrite evidence.
- **Command closure:** every unit command uses literal arguments. No command references an undeclared shell variable.
- **Discrimination:** collision, symlink, digest, exact-head, metric, and command-preservation guards each use a same-kind passing control and one minimally changed failing attack.

## Confidence check

The six deepening categories do not score. Rationale, risk treatment, serial sequencing, local precedents, acceptance commands, and S1-S5 coverage are explicit. No persona dispatch is required by `skills/planning/references/deepening.md`.

## Open unknowns

**Planning-time:** none.

**Implementation-time:**

- Exact helper function names inside the new fixture script. The public case names and diagnostics in this plan remain fixed.
- Exact prose placement within each existing section. The consuming interfaces and transition order remain fixed.
