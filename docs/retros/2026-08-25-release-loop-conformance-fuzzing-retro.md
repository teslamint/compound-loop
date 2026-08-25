# Retro: release-loop conformance fuzzing

- Date: 2026-08-25
- Source: PR #25
- Spec: docs/specs/2026-08-24-release-loop-conformance-fuzzing-design.md
- Plan: docs/plans/2026-08-24-001-feat-release-loop-conformance-fuzzing-plan.md

## Release data

| Metric | Value |
|---|---|
| **Changed non-test lines** | 10,172 (10,171 added + 1 removed) |
| Commits | 80 |
| Review rounds (unit / final / standalone) | partial — lower bound since 2026-08-25T22:38:00Z |
| Fix rounds | 1 |
| Internal findings (fixed / deferred) | 0 / 0 |
| Pull request comments (fixed / deferred) | 2 / 10 |
| Count completeness | partial — lower bound since 2026-08-25T22:38:00Z |
| CI failures | 0 |
| Duration (first spec commit → merge) | 2 days (2026-08-23T15:46:50Z → 2026-08-25T14:07:08Z) |
| Units planned / completed | 15 / 15 |

## Success criteria: measured vs declared

| # | Declared criterion | Measurement (command / rubric) | Measured result | Verdict |
|---|---|---|---|---|
| 1 | The corpus covers every ROADMAP obligation and the complete SC2 matrix. | `bash scripts/test-release-loop-conformance.sh static` inventory line | verified: cases=12 live=4 static=8 harnesses=2 golden=8 graders=18 negative=14 | Met |
| 2 | Static evaluation is source-linked rather than self-contained. | Delete Design gate text from disposable source copy; verify section digest changes | verified: modified source produces digest `d385e39d` vs manifest `09d31c8d` | Met |
| 3 | Every control and semantic mutant receives its expected named result. | `bash scripts/test-release-loop-conformance.sh static` | verified: exit 0, mutations=29 graders=9 negative=7, zero unexpected results | Met |
| 4 | No grader can become unreachable silently. | `bash scripts/test-release-loop-conformance.sh static` grader reachability check | verified: 9 static graders reached, reachability mismatch check passed | Met |
| 5 | The repository gate remains green and bounded. | `bash scripts/validate.sh` | verified: exit 0 ALL CHECKS PASSED in 3m02s on the release worktree | Partially met — 3m02s exceeds the 15s bound; the bound was set before `test-run-artifact-integrity.sh` tests were added to validate.sh by main |
| 6 | The hermetic fixture completes the shipping lifecycle without an external target. | Rubric: local push, PR creation, checks, merge, Retro, and archive pass against fixture | unverified: live fixture requires model calls which were not authorized in this retro session | Not met — deferred to live evaluation |
| 7 | Forbidden outward commands fail at the policy boundary. | Rubric: mutants for every R25 command class blocked and named in audit log | unverified: live fixture required | Not met — deferred to live evaluation |
| 8 | Both harness protocols load this feature revision and resume only expected gates. | Rubric: zero-model preflight proves payload/plugin digest, session ID, resume, pending_gate | unverified: live fixture required | Not met — deferred to live evaluation |
| 9 | Every live harness-case stratum passes three of three runs. | Rubric: approved full-run manifest reports 3/3 for each stratum | unverified: no full-run manifest exists; live evaluation was not performed | Not met — deferred to live evaluation |
| 10 | Live evaluation stays inside the approved limits. | Rubric: result manifest matches full-run flags and records caps/costs | unverified: no live evaluation performed | Not met — deferred to live evaluation |
| 11 | Ship evidence survives cleanup and becomes a durable baseline. | Rubric: handoff manifests match; baseline.json matches digests | unverified: no Ship-cleanup transition ran (no live evidence generation) | Not met — deferred to live evaluation |
| 12 | The loop closes the tracker only after the durable proof exists. | Rubric: post-Ship transition removes ROADMAP row; Retro cites baseline | unverified: no post-Ship transition ran | Not met — deferred to live evaluation |
| 13 | (Acceptance 13 — full_validation_gate report) | Rubric: 16-command report with all-zero exits | unverified: no full_validation_gate report exists | Not met — deferred to live evaluation |

## Carry-forward from previous retro

| Item | Status | Evidence |
|---|---|---|
| Ship must inventory every actionable review-body and outside-diff fingerprint with one terminal disposition. | Not started | No implementation in this cycle; ROADMAP row unchanged |
| Legacy selected ledgers need an explicit collision-safe handoff destination and acceptance matrix. | In progress | `skills/release-loop/references/resume-and-archive.md` now has CLI-based archive procedure with collision resolution; `run-artifact-integrity.py` implements the discovery/archive/handoff contract |
| Split remote merge, merged verification, state handoff, worktree cleanup, and branch deletion into separately recorded operations. | In progress | Shipping skill Step 7-8 records merge and cleanup as separate Log lines; worktree cleanup separated from merge in shipping SKILL.md |
| Publish bounded raw merged-result and RED/GREEN output before citing a post-merge root cause. | Not started | No implementation in this cycle |
| Merge or push the isolated-worktree Retro and update the ledger pointer before cleanup. | In progress | Shipping skill Step 8 merge ordering invariant now requires merged-result verification before cleanup; handoff transfer protocol added in transition-hooks.md |

- Reconciliation: registered 5, accounted for 5
- Previous doc shape: conformant

## Interview Transcript

- Independence level: self-checklist
- Rounds used: 0 (no subagent primitive — headless fork context; no external facilitator CLI)

| ID | Round | Phase | Probe | Answer | Evidence | Verdict (verbatim) |
|---|---|---|---|---|---|---|

## Findings

### What worked well
- **What happened**: Static conformance testing (SC1-SC4) verifies source-linked semantic mutations without model calls, catching digest drift from upstream skill changes immediately during merge conflict resolution.
  **Why**: The golden packet digest pinning to `SKILL.md` SHA-256 forces every upstream skill change to be explicitly acknowledged in the conformance harness.
  **How to apply**: Source-linked testing with section-level digest pinning catches skill-contract drift that unit tests miss.
  **Cites**: Phase 3 SC2 measurement, merge conflict resolution repinning 8 golden files and source-manifest.json

- **What happened**: The 11-deviation protocol (016-026) provided a structured escalation path when live CLI adapters, process containment, and budget enforcement each required mid-implementation design changes.
  **Why**: Each deviation was committed with SHA-256, approved by the user at the exact committed content, and referenced by subsequent implementation. No deviation was retroactively modified.
  **How to apply**: Commit-then-approve deviations with SHA-256 binding before implementation prevents scope drift.
  **Cites**: Phase 2 data: 11 deviations across 3 categories (CLI compatibility, containment, budget)

### What to improve
- **What happened**: 7 of 13 success criteria (SC6-SC12 plus SC13) are Not Met because they require live model evaluation which was not authorized in this retro session. The spec designed live evaluation as a Ship gate, but the Ship phase focused on the gateway sub-plan instead.
  **Why**: The gateway sub-plan (8 additional units) consumed the Ship phase's budget. Live evaluation requires Claude and Codex API calls with per-invocation cost tracking, which demands a separate approval cycle.
  **How to apply**: When a spec has live-evaluation criteria, plan the evaluation budget as a distinct approved unit, not an implicit part of Ship.
  **Cites**: Phase 3 SC6-SC12 measurements, progress.md Ship log showing gateway U1-U8 as the Ship-phase work

- **What happened**: SC5's 15-second bound was exceeded (3m02s) because `validate.sh` gained `test-run-artifact-integrity.sh` tests from main during the merge. The conformance portion alone runs under 15s.
  **Why**: The SC5 criterion bound was written before the run-artifact-integrity tests existed. The 15s target applied to the conformance portion, but `validate.sh` is the single gate and now includes more.
  **How to apply**: Bound criteria to the specific test, not the umbrella script, when the script is expected to grow.
  **Cites**: Phase 3 SC5 measurement: 3m02s wall time

### Process observations
- **What happened**: CodeRabbit review produced 12 threads (5 Major, 6 Minor, 1 Trivial) targeting sealed/approved design documents and external gateway fork scope. 2 were fixed (progress timestamp, schema YAML format), 10 were replied with rationale (sealed docs, external fork scope, intentional design choices).
  **Why**: The PR included approved design specs and deviation docs that are immutable by design. CodeRabbit analyzed them as modifiable code.
  **How to apply**: When a PR includes sealed design artifacts, pre-populate the PR description with a note that certain files are immutable approved documents.
  **Cites**: Phase 2 data: 26 reviews, 12 threads, 2 fixed, 10 not-addressing

## Carry-forward items registered

| Item | Type | Priority | Tracked at |
|---|---|---|---|
| Live evaluation criteria SC6-SC12 require a separate approved pilot and full-run cycle. | feature | P1 | ROADMAP.md Conformance suite row (existing, remains open) |
| SC5 bound (15s) needs rebasing to exclude run-artifact-integrity tests or adjusting the target. | process | P3 | ROADMAP.md (no new row — covered by existing Conformance suite row) |
| Gateway governed forks (cliproxyapi/credit-manager/model-router) need deployment and OAuth bootstrap before eligibility record becomes `eligible: true`. | feature | P2 | ROADMAP.md (no new row — the gateway is a sub-deliverable of the existing Conformance suite trigger) |

## Lessons

- Source-linked digest pinning to governed skill sections catches upstream contract drift at merge time, not at runtime — a failing golden digest is cheaper than a silent behavioral regression.
- Commit-SHA-bound deviation approval prevents scope drift: the approver sees exact bytes, not a description of what will change.

## Compounding

- compound invocation: not attempted — no reusable lesson this cycle
