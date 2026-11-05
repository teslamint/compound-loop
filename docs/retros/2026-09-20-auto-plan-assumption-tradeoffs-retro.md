# Retro: Auto Plan Assumption and Trade-off Contract

- Date: 2026-09-20
- Source: local fast-forward merge to `main`; no pull request
- Spec: `docs/specs/2026-09-20-auto-plan-assumption-tradeoffs-coverage-authority-design.md`
- Plan: `docs/plans/2026-09-20-007-feat-auto-plan-assumption-tradeoffs-coverage-authority-final-plan.md`

## Release data

| Metric | Value |
|---|---|
| **Changed non-test lines** | 4243 (4243 added + 0 removed) |
| Commits | 26 |
| Review rounds (unit / final / standalone) | 3 (0 / 3 / 0) |
| Fix rounds | 0 |
| Internal findings (fixed / deferred) | 2 / 0 |
| Pull request comments (fixed / deferred) | 0 / 0 |
| Count completeness | partial — lower bound since 2026-09-19T13:18:23Z |
| CI failures | 0 |
| Duration (first spec commit → merge) | 13h 57m 51s |
| Units planned / completed | 4 / 4 |

The review count remains partial because the durable structured event chain began
after earlier review activity. The final ledger records three final events, two
fixed findings, and the exact-head clean event at `8c298df`.

## Success criteria: measured vs declared

| # | Declared criterion | Measurement (command / rubric) | Measured result | Verdict |
|---|---|---|---|---|
| 1 | Both target skills and standalone validators define one auto-mode contract with required fields and negative controls. | `bash scripts/test-auto-artifact-contract.sh` | verified: exit 0, both byte-identical validators passed, authority checks passed, all 17 named negative controls rejected, and `ALL CHECKS PASSED` | Met |
| 2 | Auto specs and plans expose non-empty assumptions and trade-offs before architecture or implementation units. | Fresh rubric applied to the approved authority spec and final plan; package validators ran in the coverage command. | verified: both ledger-named artifacts passed; the rubric found the required five-field evidence table, four-column trade-off table, selected/rejected rows, and numeric costs. | Met |
| 3 | Interactive artifacts retain their contract and historical artifacts need no migration. | Focused harness historical no-mode controls; `git diff --name-only 3ff60c5 8c298df` reviewed against the approved scope. | verified: historical no-mode spec and plan fixtures passed; no pre-existing historical artifact was rewritten. | Met |
| 4 | Existing repository behavior remains valid. | `bash scripts/validate.sh`; `bash scripts/test-plugin-skill-discovery.sh` | verified: both exited 0 and printed `ALL CHECKS PASSED`; the full gate reported 36 valid plans and 19 verified body seals. | Met |
| 5 | The contract covers the ledger population and every named malformed mutation. | Fresh Population and Coverage command from the approved authority spec at 2026-09-20T04:02:36Z. | verified: production population 2; validator detection 17/17; harness observation 17/17; validator recall 1.000; downstream incremental recall 0.000; stacked recall 1.000. | Met |

## Carry-forward from previous retro

| Item | Status | Evidence |
|---|---|---|
| Two spec-declared test case names (`legacy_handoff_source_changed`, `legacy_handoff_complete_rerun`) were never implemented; add them to close the SC3/SC4 gap. | Done | PR #32 merge commit `22fcd463`, as recorded by the latest prior retro (T1). |
| Add a mid-directory-copy fault injection (`handoff-after-copy-one-file`) to exercise partial-directory recovery directly. | Done | PR #32 merge commit `22fcd463`, as recorded by the latest prior retro (T1). |
| Structured review events must be populated when `completeness: exact` — either use the event system or downgrade to `partial`. | Done | The run uses publisher-owned final events 1–3 and explicitly keeps `review_counts.completeness: partial`; ROADMAP row 69 is resolved by this retro (T1). |

- Reconciliation: registered 3, accounted for 3
- Previous doc shape: conformant

## Interview Transcript

- Independence level: same-model fresh-context
- Rounds used: 1 (max 5)

| ID | Round | Phase | Probe | Answer | Evidence | Verdict (verbatim) |
|---|---|---|---|---|---|---|
| T1 | 1 | 5 | Which exact contradictions forced the approved artifact corrections, and what control now prevents the same omissions? | The three triggers were missing five-field assumption evidence in plan 001, an unquantified selected trade-off cost in the approved spec, and missing explicit closure sections in plan 003. The closure plan preserves the inventory contradiction in Assumption Recheck, while validators and the harness reject missing sections, blank fields, missing status rows, and numeric-cost removal. | `.release-loop/runs/auto-plan-assumption-tradeoffs/reviews/facilitator/round-1.md` SHA-256 `7305fb5ac781a5c22d0173b3730e66cdbaf0de82e860398b4f4cd71548847c4f`; deviations 001, 002, and 004; final plan 007 | accepted |
| T2 | 1 | 5 | After the focused harness first passed, which false-green boundaries were exposed, and what evidence binds the final clean gate to a fresh review rather than the earlier result? | The first harness missed reproducible command syntax, timestamp semantics, plan Assumption Recheck, ledger-authoritative population, fixed mutation inventory, and exact-head successor review. The final chain uses event 3 at `8c298df`, its own publisher-owned wrapper and SHA-256, `re_review_of` event 2, and an empty inventory. | `.release-loop/runs/auto-plan-assumption-tradeoffs/reviews/events/final-review-1.md`, `final-review-2.md`, `final-review-3.md`; ledger `review_gate`; compound lesson `docs/solutions/workflow-issues/synthetic-review-result-manual-ledger-overwrite.md` | accepted |
| T3 | 1 | 5 | Which prior-retro carry-forward item remains active, and what durable tracker evidence prevents it from disappearing because this feature did not edit the dispatch contract? | The structured-review row is now satisfied by explicit partial completeness and publisher-owned events. The separate facilitator/reviewer verbatim-persistence row remains In progress, and the new re-review verification row remains open because no reusable dispatch operation was added in this feature. | Latest prior retro T1 and T2; `ROADMAP.md` rows 57 and 70; final plan 007 carry-forward trigger audit | accepted |

## Findings

### What worked well

- **What happened**: The final authority correction used successor spec and plan artifacts instead of mutating an approved body.
  **Why**: Review caught both post-seal mutation and missing draft-history evidence before Ship.
  **How to apply**: Treat every post-approval contract correction as an immutable successor pair with a separate draft and approval transition.
  **Cites**: T1 / Phase 2–3 data

- **What happened**: The coverage command measured the ledger-named population, each validator layer, downstream incremental recall, and a fixed mutation inventory.
  **Why**: Earlier field-level checks allowed self-derived denominators and omitted population authority.
  **How to apply**: Define the population from the authority record, enumerate expected cases, and report stacked layers without claiming downstream checks are complementary.
  **Cites**: T2 / Phase 2–3 data

### What to improve

- **What happened**: The cycle required several successor artifacts because design, plan, measurement, and review-gate contracts were corrected sequentially.
  **Why**: The initial success criteria did not include population coverage, then the first correction did not bind every authority field or preserve plan history.
  **How to apply**: Run the goal-attainment population and successor immutability checks before the first approval gate.
  **Cites**: T1 / T2

- **What happened**: Final review event allocation and exact-head gate advancement still required manual orchestration around the packaged publisher.
  **Why**: The repository lacks one packaged operation that allocates, publishes, verifies, and advances a linked re-review atomically.
  **How to apply**: Add the reusable `verify_re_review` operation before the next review-event lifecycle change.
  **Cites**: T2 / T3

### Process observations

- **What happened**: The final review chain preserved event 1 as actionable, event 2 as its clean fix, and event 3 as the exact-head successor.
  **Why**: Publisher-owned wrappers and explicit `re_review_of` links prevented a synthetic clean result from replacing the audit trail.
  **How to apply**: Reject hand-authored review rows and derive the exact-head gate from the latest sealed clean event.
  **Cites**: T2 / Phase 2–3 data

- **What happened**: The ledger remained `partial` rather than claiming exact review completeness.
  **Why**: Earlier review work preceded durable event recording, so counters could not be reconstructed safely.
  **How to apply**: Start structured counting before the first review dispatch, or preserve the partial lower-bound state.
  **Cites**: T3 / Phase 2–3 data

## Carry-forward items registered

| Item | Type | Priority | Tracked at |
|---|---|---|---|
| Persist facilitator and reviewer output verbatim at dispatch time. | process | P3 | `ROADMAP.md` row 57 |
| Expose a packaged `verify_re_review` operation for linked clean re-reviews. | process | P2 | `ROADMAP.md` row 70 |

## Lessons

- A coverage claim is only enforceable when its population comes from the authority record, its mutation denominator is fixed, and downstream layers report their incremental contribution separately.
- A post-approval contract correction requires a new immutable spec-plan pair; otherwise the plan seal and exact-head review gate certify different artifacts.

## Compounding

- compound invocation: `Documentation complete — docs/solutions/workflow-issues/synthetic-review-result-manual-ledger-overwrite.md`

Retrospective complete — docs/retros/2026-09-20-auto-plan-assumption-tradeoffs-retro.md
