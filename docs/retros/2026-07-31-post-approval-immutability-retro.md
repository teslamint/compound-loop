# Retro: post-approval-immutability-and-publication-ceremony

- Date: 2026-07-31
- Source: squash merge `049b612` on main
- Spec: docs/specs/2026-07-31-post-approval-immutability-design.md
- Plan: docs/plans/2026-07-31-001-feat-post-approval-immutability-plan.md

## Release data

| Metric | Value |
|---|---|
| **Changed non-test lines** | 82 (87 added + 5 removed; across schemas/plan-schema.md, scripts/validate.sh, skills/planning/SKILL.md, skills/planning/references/deepening.md, skills/implementing/SKILL.md, skills/reviewing/SKILL.md, CONCEPTS.md, ROADMAP.md) |
| Commits | 12 branch (squashed to 1 merge `049b612`) |
| Review rounds | 3 (1 branch review with 2 P1 + 3 P2 + 3 P3, 1 fix round, 1 plan seal) |
| Comments (fixed / deferred) | 8 / 0 |
| CI failures | 0 (no CI workflows configured) |
| Duration (first spec commit → merge) | ~2 hours |
| Units planned / completed | 6 / 6 + 1 fix round |

## Success criteria: measured vs declared

| # | Declared criterion | Measurement (command / rubric) | Measured result | Verdict |
|---|---|---|---|---|
| 1 | Seal-verification check detects modified plan body (seal mismatch) and exits nonzero | `bash scripts/test-body-seal.sh` Fixture B | verified: Fixture B PASS — wrong body_seal → FAIL line, nonzero exit | Met |
| 2 | Seal-verification check passes a plan with correct body_seal | `bash scripts/test-body-seal.sh` Fixture A | verified: Fixture A PASS — 1 verified, 0 skipped | Met |
| 3 | Seal-verification check skips plans without body_seal | `bash scripts/test-body-seal.sh` Fixture C | verified: Fixture C PASS — 0 verified, 1 skipped | Met |
| 4 | Existing plan corpus passes structural validation | `bash scripts/validate.sh` | verified: ALL CHECKS PASSED, `[body-seal] body-seal integrity: 1 verified, 15 skipped (no seal)` — 16 plans total (spec declared 15; this cycle's plan is the 16th) | Met |
| 5 | Planning step 10 recognizes outward-publication boundaries as stateful ceremonies | Rubric: a reviewer handed a plan with stateless fallback + unit containing `git push` identifies a matrix-requirement gap | unverified: declared rubric input was never constructed — measurement used `grep -A3 "outward-publication boundary" skills/planning/SKILL.md`, a structural criterion below the declared claim layer | Not met — the clause exists (grep confirms), but the declared end-to-end rubric was not exercised |
| 6 | Implementing preflight stops execution on seal mismatch | Rubric: reviewer reads preflight, confirms (a) seal computation, (b) stop condition, (c) remediation paths | verified: branch reviewer applied this rubric (P3-c finding caught absence-when-expected gap, fixed in `3217977`); preflight names canonical extraction reference, mismatch/absent stop conditions, deviation addendum or byte-exact revert | Met |
| 7 | Body-seal check 14 heredoc uses only 3.9-safe constructs | Code inspection: no walrus operators, no `match`/`case`, no 3.10+ syntax | verified: code inspection — `hashlib`, `re`, `pathlib`, f-strings only; boundary compilation covered by `invoke_validation_fixture_repo` running validate.sh end-to-end | Met |

## Carry-forward from previous retro

Previous retro: `docs/retros/2026-07-30-vocab-polish-batch-retro.md`.

| Item | Status | Evidence |
|---|---|---|
| check 11 skip-path fixture test (P4) | Done — validate-robustness-batch cycle | ROADMAP row marked Done; `scripts/validate.sh` checks 12, 13 added that cycle |

- Previous doc shape: conformant (Interview Transcript section with `self-checklist` independence level, T1/T2 cited)

## Interview Transcript

- Independence level: in-thread (approximated independence)
- Rounds used: 1

| ID | Round | Phase | Probe | Answer | Evidence | Verdict (verbatim) |
|---|---|---|---|---|---|---|
| T1 | 1 | 5 | What took meaningfully longer than planned, and what did the plan fail to see? | The test harness (U2) took 3 iterations: first the fixture mechanism was wrong (negative fixtures in real docs/plans/ would break validate.sh), then the assert functions couldn't distinguish verified from skipped, then the golden-hash shell interpolation failed. The plan underspecified the fixture mechanism ("inline heredocs or test-plan-frontmatter.sh pattern") and the independent plan review caught this as a blocking finding. | Plan review finding #1 (P1-a, P1-b); test-body-seal.sh iterations visible in branch history | self-attested |
| T2 | 1 | 5 | The harness validated the implementation against itself (compute_seal used the same split expression as check 14). What broke the self-referential loop? | The branch reviewer independently computed both hash readings (with and without the delimiter newline) and showed they differ. The harness alone would have passed 3/3 green with either interpretation. The spec Risks table prescribed "one canonical extraction rule + a round-trip fixture" but neither shipped in the first pass — the reviewer was the actual safety net. | Branch review P1-a finding, spec Risks table row 1 | self-attested |
| T3 | 1 | 5 | The progress.md final_action was left at determined/merged:false after the squash merge. How did that escape? | The merge was done inline (not via shipping skill), and the progress.md update was forgotten in the transition from ship to retro. The mechanical check (validate.sh check 11) validates final_action shape but not the determined→executed consistency or merged field agreement. This is the exact failure class the feature aims to prevent — a durable record contradicting reality. | progress.md stale state observed at retro start; fixed to executed/merged:true before writing retro doc | self-attested |
| T4 | 1 | 3 | SC5 was graded Met on a grep. The declared rubric requires constructing a plan input and handing it to a reviewer. Why the downgrade? | The grep proves the clause exists structurally; it does not prove a reviewer can apply it. The declared rubric was an end-to-end test ("hand a plan to a reviewer, they file a finding"), but no such input was constructed. Grading it Met on grep would be the layer-mismatch this cycle's own CONCEPTS.md defines. Recorded as Not Met — the clause ships, the rubric remains unexercised. | SC5 grep output vs spec rubric text; CONCEPTS.md layer-mismatch definition | self-attested |

## Findings

### What worked well

- **What happened**: The branch review caught the body-extraction ambiguity (P1-a) that would have made every newly sealed plan fail validation — the prose said "after the line" while the code included the delimiter's newline. The spec's Risks table predicted this exact risk.
  **Why**: An independent reviewer computed both hash interpretations, which the self-validating harness structurally could not do.
  **How to apply**: Whenever a spec Risk names a prescribed mitigation (like "round-trip fixture"), the plan should trace it to a unit step — an un-traced mitigation is an undelivered promise.
  **Cites**: T2, branch review P1-a

- **What happened**: Sealing this cycle's own plan (reviewer recommendation) provided the first production exercise of the write path, and the terminal-state flip (`status: done` + `completed_by:`) confirmed the seal survives frontmatter-only mutation end-to-end — `1 verified, 15 skipped`.
  **Why**: Without the reviewer's suggestion, the feature would have shipped with zero sealed plans and zero production-path evidence.
  **How to apply**: When a feature introduces a new artifact field, exercise the write-then-verify path on the cycle's own artifacts before merge.
  **Cites**: T1, validate.sh output `[body-seal] body-seal integrity: 1 verified, 15 skipped`

### What to improve

- **What happened**: SC5's declared rubric ("hand a plan with stateless fallback + `git push` to a reviewer") was never constructed. The measurement used grep — a structural criterion below the declared claim layer. Recorded as Not Met.
  **Why**: The retro's Phase 3 substituted a cheaper measurement without checking whether the declared rubric was exercisable. The layer-mismatch concept exists in CONCEPTS.md but was not applied reflexively to the retro's own measurement pass.
  **How to apply**: Before grading a rubric-measured criterion as Met, verify that the rubric's stated input was actually constructed and the stated evaluator was actually invoked — grep on the clause text does not exercise the rubric.
  **Cites**: T4, SC5 row

- **What happened**: The progress.md final_action was left at `determined` with `merged: false` after the squash merge completed. The mechanical check (validate.sh check 11) validates shape but not the determined→executed transition consistency.
  **Why**: The merge was done inline without the shipping skill's structured flow, so the post-merge ledger update was forgotten. A cycle whose subject is durable-record integrity left its own final-action record contradicting reality.
  **How to apply**: After any inline merge (not routed through shipping), the orchestrator should immediately update the progress.md final_action and merged fields.
  **Cites**: T3

### Process observations

- **What happened**: The test harness's `compute_seal()` used the same `split('---', 2)[2]` expression as check 14, so both sides agreed on a potentially wrong rule. The harness validated the implementation against itself — a wrong-but-consistent rule would pass all fixtures green.
  **Why**: Round-trip fixtures prove consistency, not correctness. Correctness requires an independent reference — the branch reviewer served that role by computing both hash readings manually.
  **How to apply**: Spec Risk mitigations that prescribe "round-trip fixture" should also prescribe an independent reference value (a golden hash from a known-good extraction) so the fixture can detect a consistently wrong rule.
  **Cites**: T2, branch review P1-a, spec Risks table

## Carry-forward items registered

| Item | Type | Priority | Tracked at |
|---|---|---|---|
| SC5 outward-publication rubric unexercised: the planning clause exists but no plan has been reviewed against it with the declared rubric input (stateless fallback + outward-publication unit) | process | P3 | ROADMAP.md — trigger: first planning cycle whose deliverable includes an outward-publication transition |
| Spec Risk mitigation traceability: Risks table mitigations are not traced to plan units via a `Covers` link the way scenarios are; an un-traced mitigation can ship undelivered | process | P3 | ROADMAP.md — trigger: next designing or planning cycle that names a Risk mitigation requiring a specific deliverable |

## Lessons

- A test harness that computes its expected value with the same code it validates proves consistency, not correctness — an independent reader computing both readings is the only thing that breaks a wrong-but-consistent loop.

## Compounding

- compound invocation: not attempted — no reusable lesson this cycle (the lesson above is a restatement of the existing source-over-memory principle applied to test harnesses, not a new pattern)
