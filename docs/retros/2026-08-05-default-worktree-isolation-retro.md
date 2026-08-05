# Retro: default-worktree-isolation

- Date: 2026-08-05
- Source: PR #4, squash merge `9017b17`
- Spec: docs/specs/2026-08-05-default-worktree-isolation-design.md
- Plan: docs/plans/2026-08-05-001-feat-default-worktree-isolation-plan.md

## Release data

| Metric | Value |
|---|---|
| **Changed non-test lines** | 383 (382 added + 1 removed; excludes the 38-line focused test) |
| Commits | 9 branch commits, squashed to merge `9017b17` |
| Review rounds | 1 final branch review and 2 PR feedback rounds |
| Comments (fixed / deferred) | 2 / 5 |
| CI failures | 0 across 2 head attempts |
| Duration (first spec commit → merge) | 2 hours 53 minutes 17 seconds |
| Units planned / completed | 1 / 1, plus 2 deviation addenda |

## Success criteria: measured vs declared

| # | Declared criterion | Measurement (command / rubric) | Measured result | Verdict |
|---|---|---|---|---|
| 1 | New release loops default to isolated worktrees | `bash scripts/test-release-loop-worktree-default.sh` | verified: exit 0; the section-scoped assertion found the default `worktree-isolation` contract | Met |
| 2 | An explicit in-place request remains a documented exception | `bash scripts/test-release-loop-worktree-default.sh` | verified: exit 0; the assertions found both explicit current-checkout and no-new-worktree exceptions | Met |
| 3 | The starting contract preserves both skip-based resume exceptions | `bash scripts/test-release-loop-worktree-default.sh` | verified: exit 0; the assertion found the branch-or-worktree skip contract for `--skip-*` resumes | Met |
| 4 | Repository structural validation remains green | `./scripts/validate.sh` | verified: `ALL CHECKS PASSED`, including the focused default-worktree check | Met |

## Carry-forward from previous retro

Previous retro: `docs/retros/2026-08-03-archive-on-loop-completion-retro.md`.

| Item | Status | Evidence |
|---|---|---|
| Classify procedural skill text by its durable runtime transitions | Done | Plan mutation/failure-state matrix and trigger audit; Deviation 006; merge `9017b17` (T1) |
| Assign post-Retro criteria to the release-loop completion gate | Not started — trigger did not fire | Plan trigger audit states that this spec has no post-Retro criterion; spec criteria 1-4 all run before Retro exit (T1) |

- Previous doc shape: conformant

## Interview Transcript

- Independence level: same-model fresh-context
- Rounds used: 2 (max 5)

| ID | Round | Phase | Probe | Answer | Evidence | Verdict (verbatim) |
|---|---|---|---|---|---|---|
| T1 | 1→2 | 4 | Show how each previous carry-forward item was reconciled in this cycle. | The runtime-effects item fired and produced the plan matrix. The post-Retro item did not fire because the spec defines no post-Retro criterion. | Plan lines 84-112; spec lines 96-105; Deviation 006 | accepted |
| T2 | 1→2 | 5 | Which single control most clearly made this procedural contract shift safe? | The mutation/failure-state matrix exposed a durable orphan-branch result that string assertions could not detect. The focused and aggregate tests then proved the final contract. | Deviation 006; focused-test output; validator output; progress entries at 04:07:56 and 04:12:31 | accepted |
| T3 | 1→2 | 5 | What surprised the team most during Ship for PR #4? | Cleanup failed because `main` belonged to the primary worktree. Live loop state had to move before the feature worktree could be removed. | Progress entries at 04:54:01, 04:55:40, and 04:57:48; merge `9017b17` | accepted |
| T4 | 1→2 | 5 | What scope expansion happened after planning? | The stale PR comparison listed 14 files, but the squash merge changed seven. Only the two deviation addenda were unplanned feature-cycle additions. | `pr-files.json`; `pr.json`; merge diff `9017b17` | accepted |
| T5 | 1→2 | 5 | What upstream process artifact should change next? | Planning should require exact failure-probe syntax, expected partial durable state, and compensation ownership before approval. | Deviations 006 and 007 | accepted |

## Findings

### What worked well

- **What happened**: The planning matrix forced a disposable failure probe that exposed an orphan branch after `git worktree add -b` failed.
  **Why**: The plan classified procedural text by runtime effects instead of treating the Markdown diff as stateless.
  **How to apply**: Require a mutation/failure-state matrix whenever workflow prose authorizes durable local mutation.
  **Cites**: T2, Deviation 006, Phase 3 focused-test data

- **What happened**: The focused regression and aggregate validator both passed on merged `main`.
  **Why**: One section-scoped test protects the default and every documented exception through the repository validator.
  **How to apply**: Keep one focused contract test in the aggregate validation path for procedural behavior changes.
  **Cites**: T2, Phase 3 criteria 1-4

### What to improve

- **What happened**: Shipping could not remove the feature worktree until live release-loop state moved to the primary checkout.
  **Why**: The shipping cleanup order removes the isolated workspace before release-loop starts Retro, but the loop ledger lived in that workspace.
  **How to apply**: Transfer and verify live lifecycle state before deleting the workspace that owns it.
  **Cites**: T3, progress entries at 04:54:01-04:57:48

- **What happened**: Two post-approval deviations were needed to preserve forced-failure truth and valid shell syntax.
  **Why**: The approved plan did not name the expected partial branch state. Its Markdown table also stored an unescaped shell pipe.
  **How to apply**: Planning should require executable probe syntax, expected partial state, and compensation ownership before approval.
  **Cites**: T5, Deviations 006 and 007

### Process observations

- **What happened**: GitHub retained a 14-file old-base comparison, while the final squash merge changed seven files.
  **Why**: PR #4 was opened before the approved v0.10.0 publication advanced remote `main`.
  **How to apply**: Use the final merge diff for shipped scope. Keep the PR comparison as historical review context.
  **Cites**: T4, Phase 2 PR data, merge diff `9017b17`

## Carry-forward items registered

| Item | Type | Priority | Tracked at |
|---|---|---|---|
| Transfer live release-loop state to the base checkout before shipping removes its isolated worktree | process | P2 | `ROADMAP.md` — trigger: next change touching shipping cleanup or the release-loop post-merge handoff |
| Require forced-failure plans to name executable probe syntax, expected partial state, and compensation ownership | process | P3 | `ROADMAP.md` — trigger: next planning-contract change |

## Lessons

- Workspace cleanup is a state handoff when a later lifecycle phase still needs records from that workspace.
- A forced-failure matrix is incomplete until it predicts partial durable state and names its compensation owner.

## Compounding

- compound invocation: Documentation complete — docs/solutions/workflow-issues/procedural-skill-text-stateful-archive-contract.md
