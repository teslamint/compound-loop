# Retro: archive-on-loop-completion

- Date: 2026-08-03
- Source: PR #3, squash merge `f3f5cbb`
- Spec: docs/specs/2026-08-03-archive-on-loop-completion-design.md
- Plan: docs/plans/2026-08-03-001-feat-archive-on-loop-completion-plan.md

## Release data

| Metric | Value |
|---|---|
| **Changed non-test lines** | 502 (493 added + 9 removed) |
| Commits | 13 branch commits, squashed to merge `f3f5cbb` |
| Review rounds | 4 final rounds, plus U1-U3 task reviews |
| Comments (fixed / deferred) | 5 / 0 (six findings across five threads) |
| CI failures | 0 across two head attempts |
| Duration (first spec commit → merge) | 2 hours 22 minutes |
| Units planned / completed | 3 / 3, plus one shipping fix round |

## Success criteria: measured vs declared

| # | Declared criterion | Measurement (command / rubric) | Measured result | Verdict |
|---|---|---|---|---|
| 1 | `SKILL.md` defines the archive procedure once, and both call sites reference it | `grep -n "archive" skills/release-loop/SKILL.md` | verified: one procedure appears at lines 53-61; loop-start and Retro-exit call sites appear at lines 37 and 61 | Met |
| 2 | The procedure text covers S1-S5 | Rubric: map each scenario to current procedure text | verified: rubric applied; S1 maps to lines 57-61, S2 to line 37, S3 to lines 45-48 and 57-59, S4 to lines 37 and 58, and S5 to lines 57-59 | Met |
| 3 | `progress-schema.md` documents the completed record's terminal archive home | `grep -n "archive" skills/release-loop/references/progress-schema.md` | verified: lines 67-69 define terminal home, destination evidence, rerun identity, and final move order | Met |
| 4 | This loop ends archived after Retro | Exact current `archive_path` verification from Addendum 005 | unverified: Retro has not exited, so the live `.release-loop/progress.md` still exists and no current archive path exists yet | Partially met — the post-Retro release-loop gate must close this criterion |
| 5 | Structural validation passes | `bash scripts/validate.sh` | verified: `ALL CHECKS PASSED` on merged `main` | Met |

## Carry-forward from previous retro

Previous retro: `docs/retros/2026-07-31-post-approval-immutability-retro.md`.

| Item | Status | Evidence |
|---|---|---|
| SC5 outward-publication rubric unexercised | Done | Commit `0b09ae9` exercised the fixture plan and marked the ROADMAP row Done (T1) |
| Spec Risk mitigation traceability | Done | Commit `0b09ae9` added planning-step traceability and marked the ROADMAP row Done (T1) |

- Previous doc shape: conformant

## Interview Transcript

- Independence level: self-checklist
- Rounds used: 1 (max 5)

| ID | Round | Phase | Probe | Answer | Evidence | Verdict (verbatim) |
|---|---|---|---|---|---|---|
| T1 | 1 | 4 | The previous retro registered two items. Where are they now? | Both items are Done. The carry-forward clearing batch implemented and marked both rows. | Commit `0b09ae9`; current `ROADMAP.md` Done rows | self-attested |
| T2 | 1 | 3 | Criterion 4 is only Partially Met. What did the declaration get wrong? | Its measurement fires after Retro exit, but the retro measures criteria before its own exit. The release-loop final gate must own the exact-path proof. | SC4 measurement row; `skills/release-loop/SKILL.md:61` | self-attested |
| T3 | 1 | 5 | What took meaningfully longer than planned, and what did the plan fail to see? | PR review found six state-integrity findings after the local branch review was clean. The plan treated procedural text as stateless because the Git diff was documentation-only. | PR #3 threads; plan Mutation/failure-state matrix fallback; Addendum 005 | self-attested |
| T4 | 1 | 5 | What almost went wrong, and what caught it? | Raw feature input could escape the archive root. Interrupted reruns could also split one loop across suffixed destinations. CodeRabbit and five independent thread checks caught both before merge. | Threads `3701298279` and `3701298297`; commits `a66fceb`, `3f091f3` | self-attested |
| T5 | 1 | 5 | If you re-ran this work from the spec, what would you do differently? | Classify the runtime behavior authorized by skill prose. A workflow contract that moves durable state needs state-machine analysis even when implementation edits only Markdown. | Plan stateless fallback; five PR resolver reports; Addendum 005 | self-attested |

## Findings

### What worked well

- **What happened**: PR review found five threads containing six valid findings after the local final review was clean.
  **Why**: The external review analyzed archive identity, recovery, and path confinement across the whole workflow contract.
  **How to apply**: Give procedural workflow text the same adversarial state review as executable mutation code.
  **Cites**: T3, T4, PR #3 review data

- **What happened**: The final-action record moved from determined to predicted after new commits, then returned to determined after the pushed head was verified.
  **Why**: The loop updated the command packet at each invalidation point instead of trusting the earlier PR head.
  **How to apply**: Treat every post-determination commit as an immediate command-packet invalidation.
  **Cites**: Phase 2 progress ledger data at `a66fceb`, `3f091f3`, and merge `f3f5cbb`

### What to improve

- **What happened**: The approved plan declared no stateful ceremony because the deliverable changed skill text, not an executable script.
  **Why**: Planning classified the tracked-file type instead of the durable runtime transitions that the prose authorizes.
  **How to apply**: Classify procedural skill text by its runtime effects. Add a mutation/failure-state matrix when it authorizes durable moves.
  **Cites**: T3, T5, plan fallback, Addendum 005

- **What happened**: SC4 cannot be measured inside the retro that must complete before SC4 fires.
  **Why**: The design assigned a terminal post-Retro observation to the retrospective's earlier measurement pass.
  **How to apply**: Assign post-Retro criteria to the release-loop completion gate and retain the exact returned evidence path.
  **Cites**: T2, SC4 measurement row

### Process observations

- **What happened**: Five review thread comments contained six findings because one thread consolidated two related archive issues.
  **Why**: GitHub thread IDs and reviewer finding counts are different record shapes.
  **How to apply**: Report resolved thread comments and resolved findings separately when their counts differ.
  **Cites**: Phase 2 PR data, PR #3 review snapshot

## Carry-forward items registered

| Item | Type | Priority | Tracked at |
|---|---|---|---|
| Classify procedural skill text by the durable runtime transitions it authorizes, not only by tracked-file type | process | P2 | `ROADMAP.md` — trigger: next planning cycle whose procedural workflow text authorizes durable local mutation |
| Assign success criteria that fire after Retro to the release-loop completion gate with exact retained evidence | process | P3 | `ROADMAP.md` — trigger: next design or retrospective cycle that declares a post-Retro terminal criterion |

## Lessons

- A documentation-only diff can still define a stateful ceremony. Classify the runtime contract, not the file extension.
- An idempotent retry needs a persisted identity. Skipping an edit does not prevent collision handling from splitting state.

## Compounding

- compound invocation: Documentation complete — docs/solutions/workflow-issues/procedural-skill-text-stateful-archive-contract.md
