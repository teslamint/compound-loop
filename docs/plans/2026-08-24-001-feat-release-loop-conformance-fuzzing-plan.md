---
schema: plan/v1
title: Release-loop Cross-Harness Conformance Fuzzing
type: feat
status: draft
date: 2026-08-24
execution: code
origin: docs/specs/2026-08-24-release-loop-conformance-fuzzing-design.md
deepened: true
---

# Release-loop Cross-Harness Conformance Fuzzing Plan

## Goal

Build a source-linked conformance corpus for the release-loop lifecycle. Add deterministic static evaluation and bounded live evaluation for Claude Code and Codex. Preserve the live generation through Ship cleanup and publish it before Retro.

## Architecture notes

- Use one Bash entry point with embedded Python standard-library programs. This matches `scripts/test-release-publication.sh` and avoids a new dependency.
- Keep semantic data in versioned JSON files. Keep harness rendering in versioned golden packets.
- Treat static and live claims as different result classes. Static success proves corpus integrity and source linkage only.
- Use semantic mutations. Do not use random byte mutations or a third-party fuzzing framework.
- Canonicalize directory manifests as sorted relative paths plus file SHA-256 values.
- Reject tar-stream comparison. Directory metadata broke its planning-time invariance probe.
- Reuse the disposable fixture pattern from `scripts/test-release-publication.sh`.
- Generate the `gh` simulator inside each fixture root. Put it first in an isolated `PATH` and clear credential variables.
- Keep the simulator command set closed. Unknown commands, flags, repositories, paths, and remote targets fail before mutation.
- Allow only exact executable and argv shapes. Reject compound shells, `env`, interpreter networking, Git config overrides, remote helpers, absolute executable paths, symlinks, and validate-then-swap targets.
- Reconcile structured tool events one-to-one with command-audit rows. A missing, extra, or nested execution blocks the run.
- Add `pending_gate` only to release-loop-owned Design and Ship questions. The record changes observability, not authority or phase order.
- A static item returns `pass`, `expected-reject`, `unexpected-pass`, `unexpected-reject`, or `infrastructure-error`.
- A live stratum returns `conformant`, `nonconformant`, `infrastructure-failure`, or `incomplete`.
- Missing and out-of-set verdicts block with their own diagnostics.
- Run no model calls during implementation. End implementation after static tests, fake-command resource tests, and zero-model preflight pass.
- Run the two L1 pilots at Ship after first-hand approval.
- Run the 24-session command only after another approval of its exact values.
- Bind each paid approval to a current-session receipt, exact command digest, model IDs, caps, retry scope, and one-shot nonce.
- Treat an interrupted or changed command as unapproved. Require a new first-hand gate.
- Start each live invocation in its own process group. On timeout, send TERM, wait within a cap, send KILL, reap every child, and prove exit before retry.
- Use one serial Claude reservation ledger. Missing cost telemetry settles the full reservation.
- Treat Codex token observation as a stop condition, not a hard dollar cap.
- Keep live generations under `.release-loop/evidence/`. Track only bounded, sanitized manifests and normalized results.
- R1 transfers the complete generation before worktree removal.
- R2 publishes the baseline, closes the tracker row, commits the result, and validates the final base HEAD.
- V1 is a pre-merge verification hook. It makes live evaluation durable and blocks the merge gate until acceptance.
- V2 is a pre-archive verification hook. It checks staged archive evidence before the terminal progress move.
- Preserve the approved plan body. Any observable transition change requires a committed deviation addendum.
- If implementation uses committing subagents, pass the actual `SSH_AUTH_SOCK`. Verify `%G?` for each dispatched commit.
- Use brokered CLI authentication only when preflight proves that agent tools cannot read the credential store. Clear all token, Git, SSH, and config-override variables from tool subprocesses.
- Block live mode when authentication is absent or isolation cannot be proved. Do not copy a user credential into the fixture.

### Controlled comparison and guard probes

Planning ran the effect-bearing comparisons with the same artifact kinds and computations that the units require:

- Two Markdown copies of `skills/release-loop/SKILL.md` returned `cmp` exit 0.
- Changing only the Design gate cell from `USER` to `AUTO` returned `cmp` exit 1.
- Two equal directory generations produced equal sorted path-and-file-hash manifests.
- Changing only `manifest.txt` produced different generation digests.
- A canonical `remote.git` path inside the fixture root passed the path guard.
- The minimally changed `../remote.git` path failed the path guard.

The initial tar-stream comparison failed the invariance pair. Directory metadata differed despite equal file bytes. The plan rejects that comparison domain.

## Assumption Recheck

All six retained commands ran at `2026-08-24T02:15:14Z` on `d06d993e0de43886ddc68a17b027f9cf7ceaff10`.

| Approved claim | Fresh evidence | Outcome |
|---|---|---|
| The Conformance suite trigger is fired and open. | `rg -n '^\\| Conformance suite' ROADMAP.md` returned the fired row at line 12. | match |
| The repository has no GitHub Actions workflow directory. | `test ! -d .github/workflows` returned exit 0. | match |
| Both local harness CLIs are available. | Claude Code is 2.1.241. Codex CLI is 0.149.0. | match |
| Both CLIs expose resumable non-interactive sessions. | The Claude help filter returned six matches. The Codex filter returned five. | match |
| The current static gate is fast and green. | `bash scripts/validate.sh` returned `ALL CHECKS PASSED` in three seconds. | match |
| Shipping needs a remote path and PR capability. | The preflight still names `gh`, authentication, reachability, and push permission. | match |

No result is a contradiction or unavailable. No assumption addendum is required.

The approved Claude command has one protocol contradiction outside the retained assumption table. Claude Code 2.1.241 requires `--verbose` with print-mode stream JSON. `docs/deviations/2026-08-24-claude-stream-json-verbose-016.md` records the repair before this plan is committed.

## File structure

| File | Responsibility | Owner |
|---|---|---|
| `scripts/test-release-loop-conformance.sh` | Static evaluator, fixture, adapters, resource ledger, manifests, and transition commands | U1-U7 |
| `scripts/validate.sh` | Invoke static conformance without model calls | U2 |
| `tests/conformance/release-loop/corpus.json` | Cases, events, expected outcomes, eligible mutations, and graders | U1, U4, U7 |
| `tests/conformance/release-loop/mutations.json` | Semantic source, SC2, parser, gate, dispatch, evidence, and policy mutations | U2, U4, U7 |
| `tests/conformance/release-loop/source-manifest.json` | Operative files, heading selectors, clause IDs, and clause digests | U2, U4, U7 |
| `tests/conformance/release-loop/baseline-policy.json` | Bootstrap state and approved spec digest | U2, U4, U7, R2 |
| `tests/conformance/release-loop/baseline.json` | Sanitized live generation published after Ship | R2 |
| `tests/conformance/release-loop/policies/claude-settings.json` | Restricted Claude tool policy | U3, U5 |
| `tests/conformance/release-loop/policies/codex.rules` | Fixture-only Codex execution policy | U3, U5 |
| `tests/conformance/release-loop/golden/claude/L1-full-lifecycle.json` | Claude L1 input | U1, U5 |
| `tests/conformance/release-loop/golden/claude/L2-mid-loop-resume.json` | Claude L2 input | U1, U5 |
| `tests/conformance/release-loop/golden/claude/L3-post-merge-resume.json` | Claude L3 input | U1, U5 |
| `tests/conformance/release-loop/golden/claude/L4-degraded-dispatch.json` | Claude L4 input | U1, U5 |
| `tests/conformance/release-loop/golden/codex/L1-full-lifecycle.json` | Codex L1 input | U1, U5 |
| `tests/conformance/release-loop/golden/codex/L2-mid-loop-resume.json` | Codex L2 input | U1, U5 |
| `tests/conformance/release-loop/golden/codex/L3-post-merge-resume.json` | Codex L3 input | U1, U5 |
| `tests/conformance/release-loop/golden/codex/L4-degraded-dispatch.json` | Codex L4 input | U1, U5 |
| `skills/release-loop/SKILL.md` | Consume `pending_gate`; dispatch V1 and V2; preserve fail-closed resume | U4, U7 |
| `skills/release-loop/references/progress-schema.md` | Define gate and verification-hook state transitions | U4, U7 |
| `skills/release-loop/references/transition-hooks.md` | Keep R1/R2 and define sealed V1/V2 verification dispatch | U7 |
| `skills/release-loop/references/resume-and-archive.md` | Stage archive evidence, run V2, then commit terminal progress | U7 |
| `skills/designing/SKILL.md` | Write and clear `design-approval` for release-loop calls | U4 |
| `skills/shipping/SKILL.md` | Write and clear `ship-approval` at final disposition | U4 |
| `ROADMAP.md` | Retain the row until R2 publishes proof | R2 |
| `.release-loop/evidence/` | Disposable unit and mutation evidence in U1 through U7 subdirectories | U1-U7 |
| `.release-loop/evidence/live-evaluation-state.json` | Paid-command receipts, process state, pilot results, and full-run progress | V1 |
| `.release-loop/.handoff/fuzz-testing/` | Base-owned generation across cleanup | R1, R2 |

## Requirement trace

| Requirements | Carrier |
|---|---|
| R1-R5 | U1-U2 |
| R6-R10 | U1, U3, U5, U6 |
| R11-R18 | U1-U2 |
| R19-R27 | U3 |
| R28-R36 | U4-U5 |
| R37 | U2 |
| R38-R48 | U6 and V1 |
| R49-R51 | U2, U6 |
| R52-R53 | U7, R1 |
| R54-R58 | U7, R2 |
| R59 | U7 and V2 before the Archive progress commit point |

## Scenario coverage map

| S-ID | Ordered unit chain | Integration evidence |
|---|---|---|
| S1 | U1 -> U2 | `case_s1_design_gate_source_mutation` deletes the real Design gate and expects `design-user-gate`. Covers S1. |
| S2 | U1 -> U2 -> U3 -> U4 -> U5 -> U6 | `case_s2_post_merge_resume` starts with `merged: true` and proves no pre-merge shipping call. Covers S2. |
| S3 | U1 -> U3 -> U5 -> U6 | `case_s3_degraded_dispatch` removes subagents and compares normalized gates and work. Covers S3. |
| S4 | U1 -> U2 | `case_s4_sc2_and_parser_inventory` runs six SC2 cases and two parser mutants. Covers S4. |
| S5 | U5 -> U6 -> V1 | `case_s5_zero_model_preflight` proves both packets. V1 runs separately approved pilots and the full command. Covers S5. |
| S6 | U6 -> U7 -> V1 -> R1 -> R2 -> Retro -> archive staging -> V2 -> terminal archive | `case_s6_generation_handoff` proves one digest across cleanup, baseline, and archive. Covers S6. |

## Implementation Units

## U1: Create the canonical corpus and golden packets

Execution note: test-first
Files:
  Create: scripts/test-release-loop-conformance.sh; tests/conformance/release-loop/corpus.json; eight files under tests/conformance/release-loop/golden/
  Modify: none
  Test: scripts/test-release-loop-conformance.sh
Interfaces:
  Consumes: repository root; canonical JSON files; current release-loop source path
  Produces: `static-inventory` mode; stable case IDs; stable grader IDs; normalized events
Test scenarios:
  happy: inventory lists L1-L4, both harnesses, all six SC2 cases, and both parser mutants
  edge: packets preserve spaces, newlines, and exact `SKILL.md` bytes without shell evaluation
  error: duplicate IDs, unknown schema versions, missing fields, and unreachable graders fail by name
  integration: `case_s4_sc2_and_parser_inventory` walks the false-green inventory. Covers S4
Steps:
  1. Write a failing `static-inventory` self-test in `scripts/test-release-loop-conformance.sh`.
  2. Run it. Confirm failure names the missing corpus.
  3. Add `corpus.json` and all eight golden files with events, outcomes, mutations, graders, and gate answer classes.
  4. Reject unknown schemas, duplicate IDs, missing fields, unknown verdicts, missing verdicts, and unreachable graders.
  5. Run the inventory and confirm every expected item passes once.
  6. Commit: "test(conformance): define the canonical release-loop corpus"
Acceptance: `bash scripts/test-release-loop-conformance.sh static-inventory` exits 0 with zero inventory defects.

## U2: Add source linkage, mutations, and the static gate

Execution note: test-first
Files:
  Create: tests/conformance/release-loop/mutations.json; tests/conformance/release-loop/source-manifest.json; tests/conformance/release-loop/baseline-policy.json
  Modify: scripts/test-release-loop-conformance.sh; scripts/validate.sh
  Test: scripts/test-release-loop-conformance.sh
Interfaces:
  Consumes: U1 corpus; operative Markdown sections; bootstrap spec digest; ROADMAP row
  Produces: `static` mode; semantic source digest; named control and mutation results
Test scenarios:
  happy: every control passes and every eligible mutation fails by its expected invariant
  edge: SC2 accepts controlled same-kind pairs and rejects A-D plus the guard reject
  error: unrelated rejection returns `unexpected-reject`; a disabled grader fails inventory
  integration: source gate deletion covers S1; complete SC2 and parser replay covers S4
Steps:
  1. Add failing cases for gate deletion, resume weakening, six SC2 outcomes, both parser mutants, grader disablement, and source drift.
  2. Run static mode. Confirm each red case names its intended false-green.
  3. Implement heading-bounded clause extraction and SHA-256 linkage.
  4. Implement every declared mutation on disposable source copies.
  5. Handle every known static verdict separately. Block missing, unknown, and infrastructure results separately.
  6. Record the source comparison probes: equal copies compare equal; the USER-to-AUTO change compares different.
  7. Accept bootstrap only while the ROADMAP row exists and the approved spec digest matches.
  8. Add static mode to `scripts/validate.sh`.
  9. Run static mode and repository validation. Confirm the full gate stays within 15 seconds.
  10. Commit: "test(conformance): make lifecycle clauses mutation-sensitive"
Acceptance: static mode reports zero unexpected results. `bash scripts/validate.sh` passes within 15 seconds.

## U3: Build the hermetic shipping fixture and policies

Execution note: test-first
Files:
  Create: tests/conformance/release-loop/policies/claude-settings.json; tests/conformance/release-loop/policies/codex.rules
  Modify: scripts/test-release-loop-conformance.sh
  Test: scripts/test-release-loop-conformance.sh
Interfaces:
  Consumes: U1 cases; local Git; generated fixture `gh`
  Produces: disposable repository; local bare origin; closed `gh` log; command audit
Test scenarios:
  happy: local push, PR, checks, review reads, squash merge, and merged-state reads complete
  edge: roots contain spaces and metacharacters; Git uses pinned identity and safe host settings
  error: every R25 command class and every unknown `gh` call fails before execution
  integration: `case_fixture_shipping_lifecycle` completes without an external target. Covers S2
Steps:
  1. Write failing fixture tests for Git setup, required `gh` calls, containment, credential removal, and audit coverage.
  2. Run the fixture group. Confirm failure names the absent simulator.
  3. Reuse the per-case temporary root, isolated `HOME`, isolated `TMPDIR`, bounded output, and cleanup trap pattern.
  4. Generate a Python `gh` simulator with only the shipping command surface.
  5. Pin `user.name`, `user.email`, `core.autocrlf=false`, `core.safecrlf=false`, and `commit.gpgsign=false`.
  6. Add both policies. Reject `curl`, `ssh`, package publication, absolute-path `gh`, external remote addition, and non-fixture push commands.
  7. Reject `/bin/sh -c`, `env`, interpreter socket access, `git -c`, credential helpers, `ext::` remotes, symlink targets, and target replacement after validation.
  8. Record one inside path that passes and the minimally changed outside path that fails.
  9. Prove the real origin and credential markers never enter the fixture. Reconcile every structured tool event with exactly one audit row.
  10. Run fixture, indirect-bypass, forbidden-command, race, and cleanup groups.
  11. Commit: "test(conformance): isolate live cases behind local fixtures"
Acceptance: all fixture groups pass. Only fixture-local refs and simulator state change.

## U4: Add deterministic pending USER-gate state

Execution note: test-first
Files:
  Create: none
  Modify: skills/release-loop/SKILL.md; skills/release-loop/references/progress-schema.md; skills/designing/SKILL.md; skills/shipping/SKILL.md; scripts/test-release-loop-conformance.sh; tests/conformance/release-loop/source-manifest.json; tests/conformance/release-loop/baseline-policy.json; tests/conformance/release-loop/corpus.json; tests/conformance/release-loop/mutations.json
  Test: scripts/test-release-loop-conformance.sh
Interfaces:
  Consumes: release-loop context; phase; approval fields; adapter answer class
  Produces: optional `pending_gate`; atomic issue and clear transitions
Test scenarios:
  happy: Design and Ship write `waiting-user` plus the correct gate, then clear it with the outcome
  edge: resume observes one valid gate without replay or duplicate answer
  error: missing, duplicate, mismatched, stale, unknown, or already-approved gate state blocks
  integration: `case_s2_post_merge_resume` bypasses pre-merge shipping. Covers S2
Steps:
  1. Add failing fixtures for both gate issues, all outcomes, mismatches, duplicates, and resume.
  2. Run the gate group. Confirm source fails because `pending_gate` is undefined.
  3. Define `pending_gate.id`, `issued_at`, and `expected_answer_class` in `progress-schema.md`.
  4. Close the ID set to `design-approval` and `ship-approval`. Close answer classes to `approve-spec-or-request-revision` and `merge-or-nonmerge-disposition`.
  5. Make `designing` write and clear `design-approval` only for release-loop.
  6. Make `shipping` write and clear `ship-approval` only at final disposition.
  7. Make release-loop consume only matching ID, phase, answer class, and missing approval state.
  8. Preserve final-action, consent, post-merge resume, review-artifact, cleanup-order, and Retro invariants.
  9. Route issue, approve, revise, mismatch, missing, and unknown outcomes separately.
  10. Update source clause digests and bootstrap generation after the four lifecycle files change. Update corpus events or mutations when selectors or clauses change.
  11. Run the gate group, static mode, and repository validation.
  12. Commit: "feat(release-loop): persist pending user gates for resume"
Acceptance: all gate fixtures pass. A minimally changed gate fixture fails by its expected invariant.

## U5: Implement harness adapters and zero-model preflight

Execution note: test-first
Files:
  Create: none
  Modify: scripts/test-release-loop-conformance.sh; eight golden files; both policy files
  Test: scripts/test-release-loop-conformance.sh
Interfaces:
  Consumes: fixture root; feature worktree; model argument; golden packet; policy digests
  Produces: exact initial and resume arrays; parsed session ID; bounded events; `preflight` report
Test scenarios:
  happy: fake Claude and Codex receive exact arrays and emit parseable session IDs
  edge: Codex stdin has exact current skill bytes; Claude plugin and both policies match digests
  error: digest drift, malformed ID, wrong resume flags, writable source, inherited config, unreadable auth isolation, or unbounded output blocks
  integration: `case_s5_zero_model_preflight` proves command shape, payload, paths, and policy wiring. Covers S5
Steps:
  1. Add fake CLI tests that capture argv, stdin, cwd, environment, and output bounds.
  2. Run preflight. Confirm failure names the absent adapters.
  3. Build the Claude initial array in this order: `claude --print --output-format stream-json --verbose --session-id`, UUID, `--plugin-dir`, feature root, `--model`, model ID, `--settings`, policy path, `--setting-sources project --strict-mcp-config --mcp-config`, empty MCP path, `--no-chrome --permission-mode dontAsk --max-budget-usd`, reserved cap, and golden prompt.
  4. Build Claude resume with the same policy, model, plugin, MCP, output, verbose, and budget flags. Add `--resume` plus the parsed session ID.
  5. Build the Codex initial array in this order: `codex exec --json --ignore-user-config --model`, model ID, `--approve-for-me --sandbox workspace-write --cd`, fixture root, `--output-last-message`, bounded result path, and `-`.
  6. Build Codex resume as `codex exec resume --json --ignore-user-config --model`, model ID, session ID, and `-`. Retain the fixture project policy and workspace sandbox from the original session.
  7. Parse Claude stream JSON and Codex `thread.started` JSONL identities.
  8. Hash feature source before and after each fake session. Reject source or policy drift.
  9. Clear GitHub, model-token, `GIT_CONFIG_*`, credential-helper, and SSH variables from every tool subprocess. Pass only the closed locale, path, fixture, and audit variables.
  10. Probe CLI authentication without printing secrets. Require brokered auth plus a denial proof for every known credential path. Return `auth-isolation-unavailable` otherwise.
  11. Prove arrays, bytes, containment, digests, session extraction, authentication isolation, and resume shape.
  12. Run preflight with both fake harnesses, missing-auth fixtures, unreadable-auth fixtures, and the source-write mutant.
  13. Commit: "feat(conformance): pin cross-harness session protocols"
Acceptance: `bash scripts/test-release-loop-conformance.sh preflight` passes without a model call.

## U6: Add bounded pilots, live strata, and generation manifests

Execution note: test-first
Files:
  Create: none
  Modify: scripts/test-release-loop-conformance.sh
  Test: scripts/test-release-loop-conformance.sh
Interfaces:
  Consumes: approved pilot flags; pilot usage; approved full-run flags; adapter events
  Produces: `live-pilot` command; exact `live` command; approval receipt validator; reservation ledger; process ledger; stratum results; generation manifest
Test scenarios:
  happy: fake pilots emit usage and eight fake strata each reach 3/3
  edge: missing Claude telemetry settles the full reservation; Claude stays serial
  error: missing or stale receipt, cap exhaustion, unsettled reservation, orphan process, timeout, unknown verdict, incomplete sample, infrastructure failure, or conformance failure blocks
  integration: fake pilots emit one exact 24-session command with every required flag. Covers S5
Steps:
  1. Add fake-clock and fake-harness tests for every cap, reservation state, retry, concurrency limit, timeout, and verdict.
  2. Run the resource group. Confirm failure names the missing ledger.
  3. Validate one current-session paid receipt before `live-pilot` or `live`. Require gate kind, exact command SHA-256, model IDs, every cap, retry scope, approval time, session marker, and one-shot nonce.
  4. Atomically consume the receipt before the first call. A command change, interruption, exhausted retry scope, or second use requires fresh approval.
  5. Reserve and settle every Claude call before the next Claude call.
  6. Start every CLI in a new process group. On timeout or cancellation, send TERM, wait within the configured cap, send KILL, reap descendants, and record proof of exit.
  7. Forbid a new invocation until process exit and resource settlement both pass.
  8. Implement Codex call, turn, timeout, concurrency, and observed-token stops.
  9. Emit the full-run command only from complete pilot evidence. Require literal flags for `--cases`, `--repetitions`, both model IDs, both turn limits, both timeouts, retries, concurrency, Codex observed tokens, total wall time, and both Claude budget limits.
  10. Implement `live` with exact 3/3 per stratum. Separate infrastructure and conformance failures.
  11. Finalize one sanitized generation with all R51 digests and the command audit.
  12. Test known live verdicts, both complements, orphan children, TERM-resistant children, double-run attempts, and stale receipts.
  13. Run resource, fake-pilot, fake-full-run, process-reap, and manifest groups.
  14. Commit: "feat(conformance): bound live evaluation by approved resources"
Acceptance: fake live tests pass without model calls. Every failed, missing, unknown, or unsettled state blocks.

## U7: Add handoff, baseline, and archive checks

Execution note: test-first
Files:
  Create: tests/conformance/release-loop/baseline.json during R2 only
  Modify: scripts/test-release-loop-conformance.sh; skills/release-loop/SKILL.md; skills/release-loop/references/progress-schema.md; skills/release-loop/references/transition-hooks.md; skills/release-loop/references/resume-and-archive.md; tests/conformance/release-loop/source-manifest.json; tests/conformance/release-loop/baseline-policy.json; tests/conformance/release-loop/corpus.json; tests/conformance/release-loop/mutations.json; ROADMAP.md during R2
  Test: scripts/test-release-loop-conformance.sh
Interfaces:
  Consumes: complete generation; feature and base identities; handoff manifest; final archive path
  Produces: `handoff`, `publish-baseline`, and `verify-archive` modes; sealed V1/V2 dispatch and resume contracts
Test scenarios:
  happy: R1 copies one generation, R2 publishes its digest, and archive verification finds it
  edge: interrupted copy, repeated transitions, unrelated archive data, and cancellation converge
  error: skipped hook, early terminal state, incomplete manifest, escape, foreign repository, hash mismatch, stale generation, dirty target, or validation failure blocks
  integration: `case_s6_generation_handoff` walks generation, handoff, baseline, tracker removal, validation, and archive. Covers S6
Steps:
  1. Add disposable feature/base fixtures for all T5, T6, and T7 outcomes.
  2. Run the transition group. Confirm failure names the absent commands.
  3. Implement sorted relative path-and-file-hash manifests. Reject symlinks, controls, traversal, missing files, extra files, and mismatch.
  4. Record equal-generation equality and changed-`manifest.txt` inequality.
  5. Define exact sealed V1 and V2 headings in `transition-hooks.md`. Require one-to-one matrix ownership, start and acceptance logs, and fail-closed resume.
  6. Make release-loop run V1 after clean Review and before shipping reaches the merge gate. Resume cannot pass an incomplete V1.
  7. Change Archive ordering: persist destination while nonterminal, stage evidence, run V2, record acceptance, mark handoff consumed, then set done and move progress last.
  8. Keep a failed V2 live and resumable. A completed archive with a V2 marker may finish removal of only the matching consumed handoff.
  9. Implement `handoff` with owner-first staging, verification, and completion-marker-last installation.
  10. Implement `publish-baseline` with handoff verification, bounded baseline, closed bootstrap, exact row removal, and dirty-tree rejection.
  11. Implement `verify-archive` against the exact persisted archive destination.
  12. Update source digests, corpus events, mutations, and bootstrap generation after lifecycle contract changes.
  13. Run hook, resume, archive, transition, static, and repository validation groups.
  14. Commit: "feat(conformance): preserve live proof through loop completion"
Acceptance: V1 cannot be skipped before merge. V2 cannot be skipped before terminal archive. One digest matches feature evidence, handoff, baseline, and staged archive.

## Release-loop pre-merge verification V1: Produce the approved generation

Matrix rows: T3, T4

Owner: the first-hand release-loop orchestrating session. The release-loop V1 dispatcher runs after Review is clean and before shipping can reach the merge gate.

State: `.release-loop/evidence/live-evaluation-state.json` stores completed preflight, receipt digests, call status, process-group termination proof, pilot measurements, the emitted full command, stratum progress, and the final generation digest. The state file contains no credential, prompt secret, or unbounded output.

Precondition: U1 through U7 are committed. Static validation and zero-model preflight pass. Authentication isolation returns `brokered-and-agent-denied`. Any other authentication result blocks V1.

Action:

1. Build the exact two-session pilot command. Present every model, cap, timeout, retry, and the Codex dollar-cap limitation.
2. After first-hand approval, write a current-session one-shot pilot receipt. Run the two L1 pilots.
3. Record actual time, tokens, Claude settlement, Codex observed tokens, and infrastructure results.
4. Derive one exact 24-session command with all required flags. Present its SHA-256 and full text.
5. After a separate first-hand approval, write a current-session one-shot full-run receipt. Run all eight strata three times.
6. Finalize T4 only when every stratum is 3/3 and every process and reservation is settled.

Resume: the V1 start and every call state live in the ledger and state file. Retain completed calls and pilot evidence. Never reuse a prior-session receipt. A process interruption, command change, or retry outside the approved scope requires a fresh first-hand gate.

Acceptance: `.release-loop/evidence/live-generation/complete.json` exists. Its manifest proves all eight 3/3 strata, zero safety violations, settled resources, reaped processes, exact command digests, and both approved receipt digests.

Failure behavior: infrastructure failure and conformance failure remain distinct. Either leaves V1 incomplete and Ship blocked before the merge gate. No incomplete generation can satisfy R1.

## Release-loop Ship-cleanup transition R1: Preserve the live generation

Matrix rows: T5

Owner: `shipping` Step 8 in the first-hand release-loop orchestrating session.

Precondition: the approved full run produced one complete generation. Merged-result verification passed on the exact merged SHA.

Action:

`bash scripts/test-release-loop-conformance.sh handoff --feature-root "$(git rev-parse --show-toplevel)" --base-root /Users/teslamint/workspace/compound-loop --generation .release-loop/evidence/live-generation --handoff-name fuzz-testing`

The literal base root is the checkout already verified against the merged SHA. The runner rejects a foreign, symlinked, or mismatched base root.

Acceptance: base `.release-loop/.handoff/fuzz-testing/` contains `manifest.json` and `complete.json`. Their generation digest equals the feature digest. Shipping records the literal base path, command, result, digest, and timestamp before cleanup.

Failure behavior: failure or cancellation keeps the worktree. Resume consumes the owned operation before cleanup.

## Release-loop post-Ship completion transition R2: Publish baseline and close bootstrap

Matrix rows: T6

Owner: the first-hand release-loop orchestrating session after shipping and before Retro.

Precondition: R1 is accepted. The authoritative base ledger has `phase: ship`, `merged: true`, and the accepted handoff digest.

Action:

1. Run `bash scripts/test-release-loop-conformance.sh publish-baseline --handoff .release-loop/.handoff/fuzz-testing --archive-source .release-loop/evidence/live-generation --baseline tests/conformance/release-loop/baseline.json --policy tests/conformance/release-loop/baseline-policy.json --roadmap ROADMAP.md`.
2. Stage only `baseline.json`, `baseline-policy.json`, and `ROADMAP.md`.
3. Commit with `test(conformance): publish the approved live baseline` and lore trailers.
4. Run `bash scripts/validate.sh` on the committed base HEAD.

Acceptance: one commit changes only the three tracked targets. The baseline names the handoff digest. Base `.release-loop/evidence/live-generation/` contains the same complete generation for the generic Archive procedure. Bootstrap is closed. The Conformance suite row is absent. Validation prints `ALL CHECKS PASSED`.

Failure behavior: failure blocks before Retro and retains the handoff. Compensation restores only the three targets from pre-transition HEAD.

## Release-loop pre-archive verification V2: Verify the archived generation

Matrix rows: T7

Owner: the release-loop Archive procedure after Retro exits, after it stages evidence at the persisted destination, and before it marks the live progress record done.

Action: assign `ARCHIVE_ROOT` to the exact destination already persisted in the live progress Log. Run `bash scripts/test-release-loop-conformance.sh verify-archive --archive-root "$ARCHIVE_ROOT" --baseline tests/conformance/release-loop/baseline.json --handoff .release-loop/.handoff/fuzz-testing` from the base checkout.

The Archive procedure assigns the exact collision-resolved path to `ARCHIVE_ROOT`. It never uses a glob, newest-directory lookup, or reconstructed date.

Acceptance: staged `evidence/live-generation/manifest.json`, tracked baseline, and retained handoff share one digest. The live progress record contains a V2 acceptance marker and the exact destination. The procedure then marks the handoff consumed, sets done, and moves progress last.

Failure behavior: keep the live progress record nonterminal. Keep the staged evidence, persisted destination, and handoff. Resume reruns V2 without recalculating the destination.

## Mutation/failure-state matrix

This matrix follows `skills/planning/references/stateful-ceremony-matrix-example.md`. Post-approval changes use the repository deviation process.

| ID | Transition | Pre-state | Action | Expected post-state | Owner | Evidence owner |
|---|---|---|---|---|---|---|
| T1 | Design pending gate | no approval or pending gate | atomically write waiting state, gate, and Log | one resumable Design question | U4 | `.release-loop/evidence/U4/` with six T1 outcome records |
| T2 | Ship pending gate | no disposition or pending gate | atomically write waiting state, gate, and Log | one resumable Ship question | U4 | `.release-loop/evidence/U4/` with six T2 outcome records |
| T3 | Live harness invocation | current-session receipt, contained fixture, settled prior call, no live process | consume receipt, reserve, spawn process group, parse, terminate, reap, settle | one bounded session result with exit proof | U6, V1 | `.release-loop/evidence/U6/` with six T3 outcome records |
| T4 | Generation finalization | eight strata each have three samples | hash files and install completion last | one immutable complete generation | U6, V1 | `.release-loop/evidence/U6/` with six T4 outcome records |
| T5 | Ship-cleanup handoff | merged verification passed and feature generation complete | run R1 | base owns exact generation | R1; U7 | `.release-loop/evidence/U7/` with six T5 outcome records |
| T6 | Baseline publication | R1 accepted and tracked tree clean | run R2 and validate | baseline tracked and tracker closed | R2; U7 | `.release-loop/evidence/U7/` with six T6 outcome records |
| T7 | Pre-archive digest verification | Retro committed; destination persisted; evidence staged; live progress nonterminal; handoff complete | run V2, record acceptance, mark handoff consumed, then commit terminal progress | staged archive digest verified before done; matching handoff removable | U7, V2 | `.release-loop/evidence/U7/` with six T7 outcome records |

| ID | Success | Forced failure and partial state | Rerun | Rollback or compensation | Headless | Cancellation or abort |
|---|---|---|---|---|---|---|
| T1 | gate exists before question; approval clears it | `FAIL_AT=t1-after-gate-write` leaves one valid Design gate and no approval | resume asks once from retained gate | revision clears gate and returns to Design | cannot answer; waiting state remains | before write leaves none; after write retains gate |
| T2 | gate exists before disposition; outcome clears it | `FAIL_AT=t2-after-gate-write` leaves one valid Ship gate and no disposition | resume revalidates PR and asks once | nonmerge clears gate and preserves selected state | no first-hand consent; Ship blocks | before write leaves none; after write retains gate |
| T3 | exact receipt is consumed; call stays in caps; process exits; reservation settles | fake timeout leaves infrastructure failure; TERM-resistant child receives KILL and is reaped; missing telemetry charges full cap | retry requires receipt scope or fresh approval, no live process, and one new reservation | no call rollback; stop and retain receipt, process, and settlement evidence | real live mode is unavailable without a current-session paid receipt | before call creates no process; after call blocks until every child exits and settlement completes |
| T4 | completion marker follows all verified files | `FAIL_AT=t4-before-complete` leaves files without a marker | verify or replace the same owned partial generation | remove only the owned incomplete generation | fake evidence may finalize; real evidence needs approved samples | before marker remains incomplete; after marker is immutable |
| T5 | base digest equals feature digest; cleanup may continue | `FAIL_AT=t5-mid-copy` leaves owner and partial stage, no completion; feature remains | remove owned stage, recopy, verify, install once | before completion remove stage; after completion keep base authoritative | allowed because all targets are local and contained | before operation keeps feature authoritative; mid-copy keeps recoverable owner |
| T6 | one commit publishes digest, closes bootstrap, removes row, and passes | `FAIL_AT=t6-after-write-before-commit` leaves exactly three dirty targets and no commit | require exact owned diff or clean compensation; create at most one commit | restore only three targets; retain handoff | allowed because all changes are local Git state | before write stays clean; after write blocks Retro |
| T7 | staged archive, baseline, and handoff digests match; V2 marker precedes done | `FAIL_AT=t7-after-stage-before-accept` leaves nonterminal live progress, persisted destination, staged evidence, and handoff | reuse the destination, verify staged bytes, write one V2 marker, then finish terminal commit | remove only staged files owned by this destination or retain them for rerun; never remove handoff before acceptance | allowed because verification and archive staging are local and contained | before staging keeps evidence live; after staging keeps progress nonterminal; after acceptance finishes only the terminal commit and matching handoff cleanup |

## Carry-forward trigger audit

Recorded fired annotations were read first. Every open `ROADMAP.md` row is classified below.

| Open row | Class | State | Disposition |
|---|---|---|---|
| Conformance suite | event-based | fired and latched | Fold U1-U7, R1, R2 |
| Schema validators + fixtures | event-based | fired and latched | Defer review-envelope half |
| Session-history search | event-based | not fired | No unit |
| compound-refresh headless auto-apply | event-based | not fired | No unit |
| Cross-round deepening suppression | event-based | not fired | No unit |
| Demo/evidence capture | event-based | not fired | No unit |
| Project-defined lane schema | event-based | not fired | No unit |
| Ambient compound triggers | event-based | not fired | No unit |
| Gemini support verification | event-based | not fired | No unit |
| Release-loop phase-worker dispatch | event-based | fired: squash commit `792f0ec` is on `main` | Defer because this feature tests the current single-orchestrator path and does not add phase-worker routing |
| Pre-release / dev version convention | event-based | fired by local dev and formal version tags | Defer because this cycle does not audit release publication |
| Evidence-tier vocabulary | event-based | not fired | No unit |
| Skill-level trace evidence | event-based | not fired | No unit |
| New-skill distinctness gate | event-based | not fired | No unit |
| Post-Retro criterion measurement | event-based | fired by criterion 12 | Fold U7 and completion gate |
| Forced-failure partial states | edit-based | fired and latched | Fold T1-T7; defer reusable contract wording |
| Reviewer output persistence | edit-based | not fired; reviewing contract untouched | No unit |
| Attack invariant in review | event-based | fired and latched | Apply in this cycle; defer reviewing contract |
| Grade severity by threatened criterion | event-based | fired and latched | Apply in this cycle; defer reviewing contract |
| Dispatched commit signing | event-based | fired and latched | Conditional execution control in Architecture notes |
| Feature-branch Retro must land | event-based | not fired; R1 transfers authority before Retro | No unit |
| `gh pr merge --delete-branch` cleanup collision | event-based | fired and latched | Defer the merge-command split; preserve current cleanup order and test that R1 runs before local cleanup |
| Mixed-generation adoption evidence | edit-based | not fired; body-seal test untouched | No unit |
| Final approval with outside-diff findings | edit-based | fired by merge-gate changes | Defer per-finding review-body inventory because the approved scope adds gate resume state, not review ingestion |
| PR merge without Retro | event-based | not fired yet; Ship will fire it | Fold mandatory R2-before-Retro order |

Audited `ROADMAP.md` at `d06d993e0de43886ddc68a17b027f9cf7ceaff10`: 25 open rows, 11 fired, 0 unobservable.

The independent reviewer must re-derive this audit from the tracker and final file list. An omitted fired row blocks approval.

## Deferred to Follow-Up Work

- Review-envelope validator fixtures remain under their existing tracker row.
- The pre-release tag audit remains under its tracker row.
- Phase-worker dispatch remains a separate lifecycle-routing cycle. This plan tests the current sanctioned degraded tier without adding phase-level routing.
- Reusable forced-failure wording remains a planning-contract change.
- Reviewer-output, invariant-attack, and severity rules remain reviewing-contract work.
- Remote merge, verification, handoff, local cleanup, and remote deletion still need separate shipping records. U4 does not change the merge command.
- Review-body findings still need a durable per-finding inventory and disposition contract. U4 preserves the existing gate but does not add review ingestion.
- Release notes and plugin versions belong to a later release ceremony.

## Open unknowns

**Planning-time**: none.

**Implementation-time**:

- Exact private helper names inside the embedded Python programs.
- Claude authentication is currently unavailable: `claude auth status --json` returned `loggedIn: false`. V1 blocks until Ship preflight proves safe brokered authentication.
- Codex currently reports ChatGPT login. V1 still blocks unless preflight proves that agent tools cannot read its credential store.
- Exact Claude and Codex model IDs. The Ship owner supplies them in the approved pilot command.
- Exact resource caps. Pilot evidence determines the separately approved full-run values.
- Actual time, tokens, Claude telemetry, and Codex observed tokens.
- Exact timestamps, session IDs, fixture roots, commit SHAs, and archive path.

## Self-review record

- Assumptions: six match, zero contradiction, zero unavailable.
- Spec coverage: R1-R59 map to units or transitions.
- Scenario coverage: S1-S6 each has a complete chain and integration case.
- Verdict coverage: known static and live values have specific actions. Missing and out-of-set values block separately.
- Mutation matrix: T1-T7 include six outcomes, failure seams, partial states, and compensation owners.
- Placeholder scan: no banned placeholder remains in a unit.
- Type consistency: case IDs, gate IDs, verdicts, and digest names stay consistent.
- Callers and invariants: validation calls static only. Lifecycle callers own transition modes.
- Carry-forward: 25 rows were rechecked; eleven fired rows have dispositions.
- Architecture: file ownership and unit interfaces implement every architecture choice.
- Command closure: transition commands use literal arguments or same-command assignments.
- Discrimination: source and handoff comparisons passed both pairs. The path guard passed one inside and one outside fixture.
