# Retro: run-artifact-integrity

- Date: 2026-08-25
- Source: PR #22 and PR #23
- Spec: `docs/specs/2026-08-23-run-artifact-integrity-design.md`
- Plan: `docs/plans/2026-08-23-001-fix-run-artifact-integrity-plan.md`

## Release data

| Metric | Value |
|---|---|
| **Changed non-test lines** | 4,288 (4,229 added + 59 removed) |
| Commits | 43 working commits; 2 landed squash commits; 1 local recovery commit |
| Review rounds (unit / final / standalone) | at least 19 (9 / 3 / 7) |
| Fix rounds | at least 11 |
| Internal findings (fixed / deferred) | at least 21 / 0 |
| Pull request comments (fixed / deferred) | 15 / 1 |
| Count completeness | partial — lower bound since 2026-08-24T00:09:21Z |
| CI failures | 0 |
| Duration (first spec commit → merge) | 35h58m |
| Units planned / completed | 5 / 5 |

## Success criteria: measured vs declared

| # | Declared criterion | Measurement (command / rubric) | Measured result | Verdict |
|---|---|---|---|---|
| 1 | A new run scopes every applicable artifact class and writes no new legacy-root artifact. | `stateful_scoped_lifecycle`, `stateless_no_evidence`, `all_consumers_one_root` | verified: all three fixtures passed (integration tier) | Met |
| 2 | A new run preserves a tracked legacy report. | `tracked_legacy_preserved` | verified: index, worktree bytes, and clean status passed (integration tier) | Met |
| 3 | Tracked or ignored orphan content blocks before the first write and lists collisions. | `ignored_orphan`, `tracked_scope_target` | verified: both collision fixtures passed (integration tier) | Met |
| 4 | Actionable review, fix, re-review, and final review produce exact structured counts. | `review_event_lifecycle`, `event_replay` | verified: exact counts and replay idempotency passed (integration tier) | Met |
| 5 | Review event recovery preserves one immutable result per event. | `matching_started_result`, `event_conflict`, `completed_result_missing`, `completed_digest_mismatch` | verified: recovery control and three integrity failures passed (integration tier) | Met |
| 6 | Only a verifying re-review can mark a finding fixed. | `fix_cannot_mark_fixed`, `deferred_then_fixed` | verified: ownership and terminal transition fixtures passed (integration tier) | Met |
| 7 | Standalone dispatch and phase-gate reuse count differently. | `standalone_and_reuse` | verified: one standalone pass remained after reuse (integration tier) | Met |
| 8 | An approved rewrite refreshes commit references without changing prior counts. | `authorized_rewrite_refresh` | verified: range refresh and preserved counts passed (integration tier) | Met |
| 9 | An unapproved non-descendant head fails closed. | `unapproved_rewrite` | verified: `stale-commit-range` fixture passed (integration tier) | Met |
| 10 | Every head change invalidates the exact-head review gate. | `descendant_head_invalidates`, `fresh_review_after_rewrite` | verified: both invalidation paths required fresh review (integration tier) | Met |
| 11 | Retro renders exact new totals and labels legacy totals partial. | `retro_structured_metrics`, `legacy_partial_metrics` | verified: exact and partial render fixtures passed (integration tier) | Met |
| 12 | Active, archive, and handoff transitions cannot escape the repository. | `scoped_symlink`, `legacy_symlink`, `archive_symlink`, `handoff_symlink` | verified: all four boundary fixtures passed (integration tier) | Met |
| 13 | Existing repository behavior remains green. | `full_validation_gate` plus publisher receipt verification | verified: publisher SHA matched; 16/16 commands exited zero; `full_lifecycle` passed (end-to-end tier) | Met |

## Carry-forward from previous retro

| Item | Status | Evidence |
|---|---|---|
| Carry-forward item 2 remains open: inventory every actionable review-body and outside-diff finding at Ship. | In progress | PR #22 completed reviewing inventory at `merge-pipeline.md:31-33`; Shipping still gates on counts and open P0/P1 state (`shipping/SKILL.md:160-211`) (T1) |
| PRs #17 and #18 merged without retrospective runs; invoke Retro after each future merge or explicitly defer. | Done | PR #22 recorded a reasoned verification blocker; PR #23 entered this Retro after recovery (`progress.md:700-744`) (T2) |

- Reconciliation: registered 2, accounted for 2
- Previous doc shape: conformant

## Interview Transcript

- Independence level: same-model fresh-context
- Rounds used: 3 (max 5)

| ID | Round | Phase | Probe | Answer | Evidence | Verdict (verbatim) |
|---|---|---|---|---|---|---|
| T1 | 1→2 | 4 | Does Done prove the Ship gate consumes complete review-body and outside-diff inventories? | No. Reviewing enforces inventory equality, but Shipping still lacks the same disposition gate. | `skills/reviewing/references/merge-pipeline.md:31-33`; `skills/shipping/SKILL.md:160-211` | accepted — Classify the previous item In progress, not Done. PR #22 completed the reviewing half; the Ship-specific durable-disposition half remains open. |
| T2 | 1→2 | 4 | Did PR #22 and PR #23 each invoke Retro or record an explicit deferral? | PR #22 recorded a verification blocker. PR #23 recorded recovery and entered Retro. | `.release-loop/progress.md:700-744` | accepted — Classify this previous carry-forward item Done for the observed triggers. |
| T3 | 1→3 | 5 | Do durable artifacts prove the signature status was the sole PR #22 failure cause? | No. The ledger preserves summaries, but the raw historical failure and RED output were transient. The sole-cause claim was dropped. | `.release-loop/progress.md:702`; publisher-owned evidence inventory | accepted — merged-result verification found and closed a regression, but the retrospective cannot independently validate the sole-cause narrative because Shipping retained only summarized output. |
| T4 | 1→2 | 5 | Is legacy handoff a contract gap or expected fail-closed behavior? | The rejection is correct, but no approved legacy destination contract satisfies mandatory state transfer before cleanup. | `run-artifact-integrity.py:633-636`; `transition-hooks.md:14-22`; plan T4 | accepted — Classify this as a lifecycle contract gap, not a failure of the 13 run-integrity criteria. Register a P1 architecture carry-forward item for an explicit collision-safe legacy destination and acceptance matrix. |

## Findings

### What worked well

- **What happened**: Fresh measurements passed all 13 criteria, including the publisher-owned 16-command full-validation report.
  **Why**: Each criterion mapped to executable controls, attacks, or the full lifecycle fixture.
  **How to apply**: Keep criterion-specific fixture names in specs and retain exact publisher receipts for terminal evidence.
  **Cites**: Phase 2–3 data

### What to improve

- **What happened**: Reviewing now inventories review-body and outside-diff findings, but Shipping still lacks a matching durable-disposition gate.
  **Why**: Shipping counts reviews, comments, and threads without joining every actionable fingerprint to one terminal disposition.
  **How to apply**: Add a Ship-level inventory and failing missing-disposition fixture before the next merge-gate change.
  **Cites**: T1
- **What happened**: Merged-result verification closed a regression, but raw failure and RED/GREEN output remained transient.
  **Why**: The ledger stores exact commands and summaries, not publisher-owned bounded output streams.
  **How to apply**: Publish bounded failure, signature, and RED/GREEN traces before making an independent root-cause claim.
  **Cites**: T3

### Process observations

- **What happened**: Both merge commands completed remotely and then exited 1 during local worktree cleanup.
  **Why**: One compound command joined remote merge with branch cleanup while `main` belonged to another worktree.
  **How to apply**: Record remote merge, merged-byte verification, state handoff, worktree cleanup, and branch deletion as separate operations.
  **Cites**: Phase 2 data; `.release-loop/progress.md:700,734`
- **What happened**: The selected legacy ledger could not use the only handoff CLI, so USER-approved recovery ran Retro before cleanup.
  **Why**: The CLI rejects legacy roots without an explicit destination contract, while lifecycle cleanup still requires state transfer.
  **How to apply**: Define a collision-safe legacy destination, ownership marker, acceptance matrix, and rerun contract.
  **Cites**: T4
- **What happened**: PR #22 deferred Retro with a recorded verification failure, and PR #23 resumed the obligation instead of silently ending at Ship.
  **Why**: The ledger preserved each blocker and required first-hand recovery approval.
  **How to apply**: Treat a reasoned deferral as state, then close it in the next successful lifecycle transition.
  **Cites**: T2

## Carry-forward items registered

| Item | Type | Priority | Tracked at |
|---|---|---|---|
| Ship must inventory every actionable review-body and outside-diff fingerprint with one terminal disposition. | process | P1 | `ROADMAP.md` existing review-inventory row |
| Legacy selected ledgers need an explicit collision-safe handoff destination and acceptance matrix. | architecture | P1 | `ROADMAP.md` new row |
| Split remote merge, merged verification, state handoff, worktree cleanup, and branch deletion into separately recorded operations. | process | P2 | `ROADMAP.md` existing merge-command row |
| Publish bounded raw merged-result and RED/GREEN output before citing a post-merge root cause. | process | P2 | `ROADMAP.md` new row |
| Merge or push the isolated-worktree Retro and update the ledger pointer before cleanup. | process | P2 | `ROADMAP.md` existing isolated-retro row |

## Lessons

- A fail-closed handoff is safe only when every accepted ledger shape has a collision-safe destination contract.
- A summarized failure can justify recovery, but it cannot support an independently verified sole-cause claim.
- Remote merge and local cleanup are separate transactions even when one command performs both.

## Compounding

- compound invocation: `Documentation complete — docs/solutions/workflow-issues/loop-deliverable-in-disposable-state.md`
