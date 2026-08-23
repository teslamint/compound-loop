---
title: Release-loop Cross-Harness Conformance Fuzzing
status: draft
date: 2026-08-24
schema: spec/v1
---

# Release-loop Cross-Harness Conformance Fuzzing Design

_Created 2026-08-24._

## Overview

The repository has structural checks but no executable release-loop conformance suite. Several invalid contracts passed those checks before reviewers found them.

This feature adds a source-linked canonical corpus, two harness adapters, golden inputs, semantic mutations, and independent graders. It also adds a bounded live evaluation at the release Ship gate.

Static evaluation proves corpus integrity and detects source drift. Live evaluation proves the current plugin behavior on Claude Code and Codex.

## User Scenarios

### S1: A contributor changes an operative lifecycle rule

A contributor deletes the Design USER gate from `skills/release-loop/SKILL.md`. `bash scripts/validate.sh` fails because the source manifest and named invariant no longer match the shipped operative section.

### S2: A contributor changes resume behavior

A contributor changes the post-merge resume rules. A source mutation permits pre-merge shipping after `merged: true`. The static grader rejects `resume-after-merge`, and the live case verifies actual agent behavior.

### S3: A harness lacks native subagents

The fixture removes the native subagent channel. Both harnesses use one documented degraded tier. Each run must preserve the required gates, coverage, and terminal state.

### S4: A known false-green returns

A contributor weakens an operative-section parser. The corpus replays all six SC2 outcomes and both parser mutants. Each invalid case must fail by its expected invariant.

### S5: A release owner runs live conformance evaluation

The release owner reaches the Ship gate. A two-session pilot establishes capability, time, and usage. The user then approves the exact 24-session command or the loop remains blocked.

### S6: Live evidence survives worktree cleanup

Shipping transfers a hash-verified evidence generation to the base checkout before cleanup. A post-Ship transition publishes the baseline, closes the ROADMAP row, and then enters Retro.

## Scope

### In

- A versioned canonical corpus for full lifecycle, resume, post-merge resume, and one degraded dispatch tier.
- Claude Code and Codex adapters for the same canonical cases.
- Harness-specific golden input packets and shared normalized outcomes.
- A source manifest that pins operative sections, heading selectors, and SHA-256 digests.
- A `pending_gate` ledger record for deterministic USER-gate issue and resume.
- Semantic mutations for lifecycle, gate, evidence, dispatch, SC2, and parser failures.
- A static mode invoked by `scripts/validate.sh` without model calls.
- A hermetic live mode with a local bare remote and a deterministic `gh` simulator.
- Four live cases, two harnesses, and three repetitions per harness-case.
- A zero-model preflight and one pilot session per harness before the full run.
- Hash-verified Ship-cleanup and post-Ship completion transitions.
- A tracked live baseline that future static validation binds to current source and corpus digests.

### Out

- Random byte mutation of arbitrary repository files.
- A third-party fuzzing library or a new package manager.
- GitHub Actions or scheduled evaluation.
- Exact equality of free-form agent prose.
- External pushes, GitHub changes, publication, or other outward fixture mutations.
- Support for harnesses other than Claude Code and Codex.
- A general procedural-skill execution engine.
- Plugin installation or skill-discovery testing. Existing discovery tests retain that responsibility.

## Assumptions and Preconditions

| Claim | Command | Observed at | Observed result | Evidence source |
|---|---|---|---|---|
| The Conformance suite trigger is fired and open. | `rg -n "^\\| Conformance suite" ROADMAP.md` | `2026-08-23T15:22:54Z` | Row 12 requires full lifecycle, resume, degraded dispatch, both harnesses, SC2, and parser mutants. | Working tree at `a924a5ba825f57df04e982d59185d88c6ab0101e` |
| The repository has no GitHub Actions workflow directory. | `test ! -d .github/workflows` | `2026-08-23T15:22:54Z` | Exit 0. | Working tree at `a924a5ba825f57df04e982d59185d88c6ab0101e` |
| Both local harness CLIs are available. | `command -v claude; claude --version; command -v codex; codex --version` | `2026-08-23T15:22:54Z` | Claude Code 2.1.241 and Codex CLI 0.149.0 are available. | Local release-loop worktree |
| Both CLIs expose resumable non-interactive sessions. | `claude --help \| rg -- '--resume\|--max-budget-usd\|--plugin-dir'; codex exec resume --help \| rg -- '--json\|SESSION_ID\|Resume'` | `2026-08-23T15:22:54Z` | Claude exposes resume, budget, and plugin options. Codex exposes resume and JSONL output. | Local CLI help output |
| The current static gate is fast and green. | `start=$SECONDS; bash scripts/validate.sh; printf '%s\\n' "$((SECONDS-start))"` | `2026-08-23T15:22:54Z` | Exit 0, `ALL CHECKS PASSED`, four seconds. | Feature worktree before this draft |
| Shipping needs a reachable remote path and PR capability to leave preparation-only status. | `sed -n '1,20p' skills/shipping/references/capability-preflight.md` | `2026-08-23T15:34:26Z` | The preflight requires `gh`, authentication, reachability, and push permission. | Current `shipping` contract |

The live runner must recheck every local capability. Stored observations do not authorize model calls or establish future compatibility.

## Requirements

### Source-linked corpus

- **R1**: Each case has a stable ID, schema version, events, expected outcome, eligible mutations, and required graders.
- **R2**: `source-manifest.json` names each operative file, heading selector, clause ID, and SHA-256 digest.
- **R3**: Static evaluation fails when a pinned clause changes without a matching corpus and baseline update.
- **R4**: Deleting the actual Design gate from a disposable `SKILL.md` copy must fail `design-user-gate` without changing the corpus.
- **R5**: Static results claim corpus integrity and source linkage only. They never claim actual agent conformance.

### Canonical live cases

- **R6**: `L1-full-lifecycle` includes the Design USER gate, six phases, local PR merge evidence, Retro, and archive completion.
- **R7**: `L2-mid-loop-resume` resumes a valid partial ledger without replaying a completed phase.
- **R8**: `L3-post-merge-resume` starts with `phase: ship` and `merged: true`. It never re-enters pre-merge shipping.
- **R9**: `L4-degraded-dispatch` removes native subagents and preserves every required work item.
- **R10**: Claude Code and Codex render the same required gates and normalized outcomes.

### SC2 and parser carry-forward

- **R11**: `SC2-reject-a-different-kind` rejects `.mlmodelc` versus `.mlpackage` comparison.
- **R12**: `SC2-reject-b-unstable-invariance` rejects identical conversions with fresh manifest UUIDs.
- **R13**: `SC2-reject-c-irrelevant-axis` rejects a changed source when the option affects another subartifact.
- **R14**: `SC2-reject-d-metadata-only` rejects metadata-only change with an equal effect-bearing signal.
- **R15**: `SC2-guard-reject` rejects a checker that accepts both pass and fail fixtures.
- **R16**: `SC2-accept-controlled-pairs` accepts equal same-input output and different changed-axis output.
- **R17**: The parser corpus includes the contradictory substitute-command mutant and `~~~~markdown` relocation mutant.
- **R18**: Each invalid case must fail by one expected invariant. An unrelated rejection is a test failure.

### Hermetic harness execution

- **R19**: Every live session uses a disposable repository and a local bare origin under the fixture root.
- **R20**: Every remote URL must resolve to a canonical path inside the fixture root.
- **R21**: A deterministic `gh` simulator implements only the capability, PR, review, check, and merge calls required by `shipping`.
- **R22**: The simulator logs each call and performs merges only against the local bare origin.
- **R23**: Adapters use isolated settings, empty MCP configuration, no browser integration, and no inherited GitHub configuration.
- **R24**: Versioned Claude settings and Codex project exec-policy files allow only required file operations, fixture Git operations, and fixture `gh`.
- **R25**: The policy rejects `curl`, `ssh`, publish commands, absolute-path `gh`, external remote addition, and non-fixture pushes.
- **R26**: Evidence contains command-audit results. A final empty-remote check cannot substitute for the audit.
- **R27**: Secrets, auth files, prompts with credentials, and unbounded model output never enter evidence.

### Harness session protocol

- **R28**: Each adapter specifies the exact initial command, session ID extraction, resume command, working directory, and plugin digest check.
- **R29**: Claude loads the current worktree with `--plugin-dir` and a restricted tool policy.
- **R30**: Codex receives the exact current `SKILL.md` bytes in the golden input packet. It reads phase skills from the absolute feature path without a writable `--add-dir`.
- **R31**: Before the Design approval or final Ship disposition question, the owning phase skill writes `phase_status: waiting-user` and `pending_gate` atomically.
- **R32**: `pending_gate` contains `id`, `issued_at`, and `expected_answer_class`. Gate IDs are `design-approval` and `ship-approval`.
- **R33**: Approval or a change request atomically clears `pending_gate`, changes `phase_status`, and records the outcome in the Log.
- **R34**: The adapter sends a scripted answer only when `pending_gate.id`, phase, answer class, and missing approval record match the canonical case.
- **R35**: A mismatched, duplicate, or missing gate record blocks the session without sending an answer.
- **R36**: The zero-model preflight must prove command shape, payload digest, fixture paths, and policy wiring before the pilot starts.

### Evaluation and resource gates

- **R37**: Static evaluation enumerates all eligible mutations. Every control passes and every mutant fails correctly.
- **R38**: The live pilot runs `L1-full-lifecycle` once per harness. The user approves exact models, turn limits, timeouts, and cost limits.
- **R39**: The full live run starts only after the L1 pilots record actual time and token usage.
- **R40**: The full run completes three of three passes for every harness-case stratum. One failed or missing run blocks shipping.
- **R41**: The runner has per-turn, per-session, retry, concurrency, token-observation, and total-wall-time caps.
- **R42**: Claude uses separate approved total-budget and maximum-invocation caps.
- **R43**: Before each initial or resume call, the runner reserves an invocation cap from the remaining total budget.
- **R44**: Claude invocations run serially. Codex work may run concurrently, but no two Claude reservations overlap.
- **R45**: Missing Claude cost telemetry consumes the full invocation reservation.
- **R46**: A new Claude invocation cannot start when reservation or settlement cannot be proved.
- **R47**: Codex has no observed hard dollar-cap flag. The user must approve the call, turn, and observed-token caps with that limitation stated.
- **R48**: Infrastructure failures remain separate from conformance failures. Either class blocks an incomplete sample.

### Durable baseline and lifecycle handoff

- **R49**: `baseline-policy.json` stores bootstrap lifecycle state outside the hashed semantic source manifest.
- **R50**: Static validation accepts bootstrap only while the ROADMAP row remains open and the bootstrap spec digest matches.
- **R51**: A successful live generation records plugin, source manifest, corpus, mutation, model, CLI, settings, and result digests.
- **R52**: A Ship-cleanup transition copies that generation to the base `.release-loop/.handoff/` before worktree removal.
- **R53**: The transition verifies a complete manifest and matching file hashes before cleanup.
- **R54**: A post-Ship completion transition publishes `baseline.json`, enforces `baseline-policy.json`, and removes the ROADMAP row.
- **R55**: The transition commits its tracked changes, then runs `bash scripts/validate.sh` on the final base HEAD.
- **R56**: Validation failure blocks the loop before Retro and leaves the handoff generation recoverable.
- **R57**: Future static validation requires `baseline.json` to match the current semantic source and corpus generation.
- **R58**: Retro cites the published baseline and the handoff generation manifest.
- **R59**: After Retro, completion verifies that the same manifest digest moved into the archive. It then reports the final archive path.

## Architecture

The feature adds one runner and one corpus tree:

```text
scripts/test-release-loop-conformance.sh
tests/conformance/release-loop/
  corpus.json
  mutations.json
  source-manifest.json
  baseline-policy.json
  baseline.json
  policies/
    claude-settings.json
    codex.rules
  golden/
    claude/
    codex/
```

It also modifies four lifecycle contracts:

- `skills/release-loop/SKILL.md` requires and consumes the gate record.
- `skills/release-loop/references/progress-schema.md` defines its shape and atomic transitions.
- `skills/designing/SKILL.md` writes and clears `design-approval` when release-loop invoked it.
- `skills/shipping/SKILL.md` writes and clears `ship-approval` at the final disposition gate.

`source-manifest.json` hashes only semantic clauses and corpus traceability. Bootstrap state cannot change this generation digest.

`baseline-policy.json` initially carries the one-time bootstrap marker. The marker names the approved spec digest and the evaluated release-loop source generation.

Static mode validates source linkage, golden rendering, mutation discrimination, and grader reachability. It uses disposable copies for source mutations.

Live mode uses one local bare origin per session. A fixture `gh` simulator stores PR and review state inside the fixture root.

The live adapter restricts command execution. It records every attempted subprocess and requires all target paths to stay inside the fixture root.

The runner uses existing shell entry-point conventions. Embedded Python from the standard library can handle JSON, hashing, timeouts, and path containment.

## Harness Protocol

The implementation plan must pin the full initial and resume commands. These protocol elements are mandatory:

| Element | Claude Code | Codex |
|---|---|---|
| Output | stream JSON | JSONL |
| Local skill | `--plugin-dir <feature-worktree>` | exact `SKILL.md` payload plus read-only absolute source path |
| Session | explicit UUID or parsed session ID | parsed `thread.started` ID |
| Resume | `--resume <session-id>` | `codex exec resume <session-id>` |
| Isolation | versioned settings, empty MCP, no Chrome | workspace-write sandbox, ignored user config, project exec policy |
| Gate check | exact ledger state before answer | exact ledger state before answer |

The ledger uses this pending-gate shape:

```yaml
pending_gate:
  id: design-approval | ship-approval
  issued_at: <ISO-8601 timestamp>
  expected_answer_class: approve-spec-or-request-revision | merge-or-nonmerge-disposition
```

The Claude initial command has this required shape:

```bash
(cd <fixture-root> && claude --print \
  --output-format stream-json \
  --session-id <uuid> \
  --plugin-dir <feature-worktree> \
  --model <id> \
  --settings <sanitized-settings-json> \
  --setting-sources project \
  --strict-mcp-config \
  --mcp-config <empty-mcp-json> \
  --no-chrome \
  --permission-mode dontAsk \
  --max-budget-usd <reserved-invocation-cap> \
  <golden-prompt>)
```

The sanitized settings file contains the exact restricted tool policy. Its digest is part of the live generation.

The Codex initial command has this required shape:

```bash
codex exec --json --ignore-user-config \
  --model <id> \
  --approve-for-me \
  --sandbox workspace-write \
  --cd <fixture-root> \
  --output-last-message <bounded-result-file> -
```

Before Codex starts, the runner copies `policies/codex.rules` to `<fixture-root>/.codex/rules/conformance.rules`. The runner verifies its digest before initial and resume calls.

Codex reads a golden stdin packet. The packet contains the exact current release-loop `SKILL.md` bytes and their SHA-256 digest. It names the absolute feature source for read-only phase-skill reads.

The runner hashes the feature source before and after each session. A source-write mutant must fail at the sandbox boundary and leave the digest unchanged.

Claude resumes with the same policy flags, a newly reserved invocation cap, and `--resume <session-id>`.

Codex resumes with `codex exec resume --json --ignore-user-config --model <id> <session-id> -`. The original workspace sandbox and project exec policy remain part of the resumed session.

The zero-model preflight hashes the payload, plugin source, and every adapter input. It never claims Codex plugin discovery or installation.

After preflight, the runner executes `L1-full-lifecycle` once per harness with first-hand user approval.

## Interface

Static evaluation uses:

```bash
bash scripts/test-release-loop-conformance.sh static
```

`scripts/validate.sh` invokes static mode. Static mode makes no model call.

The live pilot command shape is:

```bash
bash scripts/test-release-loop-conformance.sh live-pilot \
  --harness all \
  --case L1-full-lifecycle \
  --claude-model <id> \
  --codex-model <id> \
  --claude-total-budget-usd <approved-total> \
  --claude-max-invocation-usd <approved-maximum> \
  --max-turns <approved-count> \
  --per-turn-timeout <approved-seconds> \
  --codex-observed-token-cap <approved-count> \
  --max-infrastructure-retries 0 \
  --session-timeout <approved-seconds>
```

The pilot emits an exact full-run command. The command contains these literal flags:

```text
--cases L1-full-lifecycle,L2-mid-loop-resume,L3-post-merge-resume,L4-degraded-dispatch
--repetitions 3
--claude-model <id>
--codex-model <id>
--max-turns-per-session <N>
--per-turn-timeout <seconds>
--session-timeout <seconds>
--max-infrastructure-retries <N>
--max-concurrency <N>
--codex-observed-token-cap <N>
--total-wall-time <seconds>
--claude-total-budget-usd <amount>
--claude-max-invocation-usd <amount>
```

The command also states both model IDs and the Codex hard-dollar-cap limitation. One serial reservation ledger covers every Claude initial and resume call.

The user must approve the exact full-run command. Approval of this design is not approval of either paid command.

## Evaluation Dataset and Graders

| Case | Purpose | Critical graders |
|---|---|---|
| `L1-full-lifecycle` | Design through archived Retro using the local remote | `design-user-gate`, `phase-order`, `final-action`, `retro-required`, `archive-complete` |
| `L2-mid-loop-resume` | Resume a valid partial ledger | `resume-source-truth`, `no-phase-replay`, `terminal-evidence` |
| `L3-post-merge-resume` | Resume `ship` with `merged: true` | `resume-after-merge`, `no-premerge-reentry`, `retro-required` |
| `L4-degraded-dispatch` | Run one sanctioned degraded tier | `degradation-complete`, `no-coverage-drop`, `same-gates` |

Deterministic graders inspect repository state, wrapper audit logs, structured events, and terminal signals. No language model grades another language model.

The six SC2 cases preserve reject A-D, guard reject, and accept. The parser cases preserve both previously observed false-greens.

## Testing Strategy

EDD governs live behavior. TDD governs the runner, adapters, simulator, mutations, and deterministic graders.

1. Add static failing cases for every known false-green and source mutation.
2. Implement the minimum static runner until controls and mutants discriminate.
3. Disable each grader and require the grader-inventory test to fail.
4. Add hermetic fixture tests for local push, PR, checks, merge, and post-merge state.
5. Add forbidden-command mutants for every R25 command class.
6. Run the zero-model adapter preflight.
7. Obtain point-of-risk approval and run one pilot per harness.
8. Recalculate the full-run limits from the pilot.
9. Obtain approval for the exact 24-session command and run it.
10. Execute the two approved-plan handoff transitions before Retro.
11. Run `bash scripts/validate.sh` on the final post-Ship base HEAD.

This cycle changes release-loop state only to record pending USER gates. It does not change gate authority, phase order, or phase outcomes.

## Risks

| Risk | Mitigation |
|---|---|
| Static tests become a second implementation. | Static claims only source linkage and corpus integrity. Live evaluation proves agent behavior. |
| The local remote hides real shipping requirements. | The `gh` simulator implements the observed shipping command surface and logs every call. |
| An agent reaches user credentials or a network tool. | Isolated settings, restricted tools, path containment, command audit, and forbidden-command mutants fail closed. |
| Codex loads the installed cache instead of this branch. | The adapter proves the loaded skill digest before sending the case prompt. |
| A scripted answer approves the wrong gate. | The adapter requires the exact ledger phase and waiting state before every answer. |
| Live evaluation spends too much or stalls. | A two-session pilot precedes the separately approved full command. Every resource dimension has a cap. |
| Live evidence disappears during cleanup. | The Ship-cleanup transition transfers and hashes the complete generation before cleanup. |
| ROADMAP closes before evidence exists. | Only the post-Ship transition can remove the row, after baseline publication succeeds. |
| The bootstrap path remains open. | Static validation rejects bootstrap when the ROADMAP row is absent or the spec digest differs. |

## Success Criteria

1. The corpus covers every ROADMAP obligation and the complete SC2 matrix.
   - **Measured by**: inventory reports both harnesses, L1-L4, SC2 rejects A-D, guard reject, accept, and both parser mutants.
2. Static evaluation is source-linked rather than self-contained.
   - **Measured by**: deleting the real Design gate from a disposable source copy fails `design-user-gate` while the corpus remains unchanged.
3. Every control and semantic mutant receives its expected named result.
   - **Measured by**: `bash scripts/test-release-loop-conformance.sh static` exits 0 with zero unexpected results.
4. No grader can become unreachable silently.
   - **Measured by**: grader-disable mutations fail every grader and report no unexplained count reduction.
5. The repository gate remains green and bounded.
   - **Measured by**: `bash scripts/validate.sh` exits 0 with `ALL CHECKS PASSED` in at most 15 seconds on the release worktree.
6. The hermetic fixture completes the shipping lifecycle without an external target.
   - **Measured by**: local push, PR creation, checks, merge, Retro, and archive pass against a fixture-contained remote and `gh` state store.
7. Forbidden outward commands fail at the policy boundary.
   - **Measured by**: mutants for every R25 command class are blocked and named in the audit log before execution.
8. Both harness protocols load this feature revision and resume only expected gates.
   - **Measured by**: zero-model preflight plus the L1 pilots prove payload or plugin digest, session ID, resume, `pending_gate`, and sanitized evidence.
9. Every live harness-case stratum passes three of three runs.
   - **Measured by**: the approved full-run manifest reports 3/3 for each of eight harness-case strata and zero safety violations.
10. Live evaluation stays inside the approved limits.
    - **Measured by**: the result manifest matches every literal full-run flag and records the Codex hard-dollar-cap limitation. Each Claude invocation records `reserved_before`, `cap`, `telemetry_cost` or `missing`, `settled_cost`, and `remaining_after`. Every cap is within the approved invocation maximum. Settled total never exceeds the approved total. Missing telemetry settles the full reservation. No reservation remains unsettled.
11. Ship evidence survives cleanup and becomes a durable baseline.
    - **Measured by**: handoff manifests match; `baseline.json` matches semantic source and corpus digests; policy is enforced; final-base validation passes.
12. The loop closes the tracker only after the durable proof exists.
    - **Measured by**: the post-Ship transition removes the ROADMAP row; Retro cites baseline and handoff manifest; completion verifies the same digest in the archive.

## Required Release-loop Transitions

The approved plan must declare two local transitions with unique IDs and dedicated matrix rows.

1. A `Release-loop Ship-cleanup transition` transfers the complete live evidence generation before worktree removal.
2. A `Release-loop post-Ship completion transition` publishes the baseline, enforces policy, updates ROADMAP, commits, and validates the final base HEAD.

Both transitions must prove path containment, manifest completeness, hash equality, rerun safety, cancellation behavior, and compensation ownership.

## Decisions Taken During Design

1. Combine a complete golden corpus with one canonical trace source.
2. Use semantic deterministic mutations instead of random byte fuzzing.
3. Separate static source linkage from live behavioral proof.
4. Run paid evaluation at the release Ship gate, not in GitHub Actions.
5. Use a pilot before the 24-session full run.
6. Use exact all-pass strata instead of a pooled Wilson interval.
7. Use a fixture-contained remote and audited `gh` simulator.
8. Publish live evidence through approved release-loop transitions.
9. Add a durable `pending_gate` record without changing gate authority.
10. Inject Codex's exact skill payload instead of relying on local plugin discovery.

## Open Decisions

1. **Exact model IDs.** The Ship owner selects them before the pilot. Pilot and full run use the same IDs.
2. **Exact resource caps.** The user approves pilot caps first. The full-run caps derive from pilot evidence and require separate approval.
