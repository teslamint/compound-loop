# Retro: Planning Discrimination and Verdict Coverage

- Date: 2026-08-16
- Source: PR #15
- Spec: `docs/specs/2026-08-15-planning-discrimination-and-verdict-coverage-design.md`
- Plan: `docs/plans/2026-08-15-001-fix-planning-discrimination-and-verdict-coverage-plan.md`

## Release data

| Metric | Value |
|---|---|
| **Changed non-test lines** | 2364 (2360 added + 4 removed) |
| Commits | 14 |
| Review rounds | 10 |
| Comments (fixed / deferred) | 4 / 1 |
| CI failures | 0 |
| Duration (first spec commit → merge) | 0.990 days (23h 45m 15s) |
| Units planned / completed | 5 / 5 |

## Success criteria: measured vs declared

| # | Declared criterion | Measurement (command / rubric) | Measured result | Verdict |
|---|---|---|---|---|
| 1 | Step 14 carries twelve checks; exactly two are named Discrimination check and Verdict coverage; and each sits in its declared position | The four declared `sed`/`grep` pipelines over `R='/^## 14\. Self-review/,/^## 15\./'` | verified: counts `12` and `2`; the fourth check is `Verdict coverage`; the last check is `Discrimination check` | Met |
| 2 | The shipped Discrimination check rejects the case that motivated it and accepts a compliant counterpart | Fresh same-model rubric review of issue #11, SC2, U5 review lines 24-29, and final Step 14 | verified: rubric applied and cited every rejection/acceptance boundary; confidence 0.95, no findings | Met |
| 3 | The shipped Verdict coverage check rejects the motivating case, including its hostile variant, and accepts a compliant counterpart | Fresh same-model rubric review of issue #12, SC3, U5 review lines 31-40, and final Step 14 | verified: rubric applied and cited union, complement, and category-specific routing clauses; confidence 0.95, no findings | Met |
| 4 | No existing repository contract regresses | `bash scripts/validate.sh` | verified: exit 0 and `ALL CHECKS PASSED`, including plan references, six body seals, release-loop isolation, and review-remediation contracts | Met |
| 5 | The retro-format contract suite stays green | `bash scripts/test-retro-format-drift.sh` | verified: exit 0, 44/44 cases passed, and `ALL CASES PASSED` | Met |
| 6 | A closing comment for each of issues #11 and #12 exists as a committed or ledger-recorded payload quoting the shipped wording, and the loop's outward-action record names the exact posting command | Declared payload `grep -c` checks plus command/marker checks on `.release-loop/progress.md:88`; supplemental packet execution and terminal issue reads | verified: payload counts `1` and `1`; ordered command-set count `1`; non-authorization-marker count `1`; supplemental packet exit `0`, one exact payload match per issue, both `CLOSED` | Met |

## Carry-forward from previous retro

| Item | Status | Evidence |
|---|---|---|
| Adversarially test each integrity mechanism before approval by constructing the cheapest artifact that satisfies its written checks while violating its intent | In progress | Procedurally exercised in the Design, plan, and U5 reviews; durable review-dispatch rule remains open in `ROADMAP.md` (current invariant-attack row) |
| Grade a finding against the success criterion it threatens, not the blast radius of the code it sits in | In progress | All PR #15 bounded reviews used the threatened-criterion rule; durable triage rule remains open in `ROADMAP.md` |
| A success criterion completed by a human action outside the pipeline needs a gate that blocks the completion report | Done | R2 blocked before point-of-risk approval, then `.release-loop/progress.md:123-125` records first-hand approval, exact packet execution, and terminal verification; the resolved tracker row was removed |
| Post the prepared issue #7 correction and close issues #6, #8, #9, #10 whose repairs merged in `0086cff` | Done | The human posted [issue #7's correction](https://github.com/teslamint/compound-loop/issues/7#issuecomment-5297152028); a fresh GitHub closed-issue listing verifies #6, #8, #9, and #10 are closed |
| Loop artifacts that outlive their loop must move out of gitignored `.release-loop/` into a committed path before worktree cleanup | Done | PR #15 committed issue payloads, command packet, deviations, and review artifacts; R1 recorded successful live-state transfer and a base-authoritative ledger before cleanup; the resolved tracker row was removed |
| A retro committed on a feature branch must be merged or pushed in the same action, with the ledger pointer updated then | Not started | The prior retro's claimed tracker row was absent; this retro repaired registration in `ROADMAP.md`, while the isolated-Retro trigger has not fired (T1) |
| Persist facilitator and reviewer output verbatim as an artifact at dispatch time | In progress | U5 is committed under `docs/reviews/`; the reusable dispatch rule is absent and this Retro's facilitator output remains in ignored loop state (T2) |
| Pass `SSH_AUTH_SOCK` explicitly to any dispatched agent that commits, and verify signature state per commit | In progress | U5 line 20 says U1-U4 were committed by dispatched implementers and all four reported `%G? = G`; the run does not retain socket-pass-through evidence, so the durable rule remains open |
| Transfer live release-loop state to the base checkout before shipping removes its isolated worktree | Done | R1 recorded T5 transition start/success, made the base ledger authoritative, and only then permitted feature-worktree removal |
| Require forced-failure plans to name executable probe syntax, expected partial state, and compensation ownership | In progress | This plan's T0-T7 satisfy the fields, but the reusable matrix contract remains deferred in plan line 979 and open in `ROADMAP.md` (T3) |

- Reconciliation: registered 10, accounted for 10
- Previous doc shape: conformant

## Interview Transcript

- Independence level: same-model fresh-context
- Rounds used: 2 (max 5)

| ID | Round | Phase | Probe | Answer | Evidence | Verdict (verbatim) |
|---|---|---|---|---|---|---|
| T1 | 1→2 | 4 | The previous retro registered the isolated-retro merge obligation, but `ROADMAP.md` has no matching row and the trigger is said not to have fired. Which exact tracker artifact or commit proves whether this registration is truly `Not started`, rather than a durable-tracker defect that already required repair? | No tracker artifact existed. Commit `f0473d9` changed both the previous retro and `ROADMAP.md`, yet omitted the row; this retro repaired registration while leaving the untriggered implementation Not started. | Previous retro line 151; pre-repair `ROADMAP.md:38-62`; commit `f0473d9` | accepted |
| T2 | 1→2 | 4 | You marked verbatim facilitator/reviewer persistence In progress. Show the exact `ROADMAP.md` row and committed file or commit that proves the dispatch-time rule is still absent, and why the existing review and facilitator artifacts do not satisfy that durable contract. | U5 was committed at `4e6d450`, but PR #15 edits neither reviewing nor retrospective; one persisted instance does not require future dispatches to persist output, and this facilitator exchange still lives only in ignored loop state. | `ROADMAP.md` facilitator/reviewer row; U5 review frontmatter; PR #15 file list | accepted |
| T3 | 1→2 | 4 | Forced-failure plans are marked In progress although U5 says T0-T7 meet the rule. Which exact plan artifact and `ROADMAP.md` entry prove that the reusable planning-matrix contract—not merely this cycle's T0-T7 rows—remains unimplemented? | Plan line 979 explicitly says T0-T7 satisfy this cycle but defers the durable `schemas/plan-schema.md` and planning-step-10 rule; U5 proves only this plan's instance. | `ROADMAP.md` forced-failure row; plan lines 964 and 979; U5 line 56 | accepted |
| T4 | 1→2 | 5 | The validator false-greens are attributed to weak operative-section parsing. What exact disposable mutation, pre-fix pass result, post-fix fail result, and commit tie each false-green to that parser defect rather than to a changed fixture? | A contradictory substitute-command sentence and a `~~~~markdown` relocation each passed the weaker whole-file check and failed the scoped operative parser; the copied fixtures were otherwise unchanged. Raw temp output was not committed. | `.release-loop/progress.md:110`; `scripts/validate.sh:742-929`; Deviation 013 lines 106-110; `2f158fe` | accepted |
| T5 | 1→2 | 5 | The `gh pr merge 15 --squash --delete-branch` event is being generalized into a recommendation to split remote merge from local cleanup. What exact command output and worktree/branch state prove the local cleanup collision caused exit 1 after the remote merge, and which subsequent event demonstrates the safe split order? | The command merged remote PR #15 as `df8f7ca`, then exited 1 because `main` was checked out in the base worktree; the feature worktree and remote branch remained. Recovery separately fast-forwarded and verified base, transferred R1 state, removed the worktree, then deleted the remote branch. | `.release-loop/progress.md:115,117-120`; current worktree and remote-branch checks | accepted |
| T6 | 1→2 | 5 | SC2 is marked Met, but the equal/different compliant pair exists only as review prose. Identify the committed raw fixture or digest output that independently reproduces the pair; if none exists, point to the exact artifact boundary where the prose-only evidence is recorded. | No raw fixture or digest is committed. U5 lines 24-29 are the durable prose boundary; the fresh rubric verifies the wording's decision boundary, not empirical replay. SC2 is Met under its judgment rubric, with replayability carried by the fired conformance-suite tracker. | U5 lines 24-29; SC2; final Step 14; fresh rubric result | accepted |

## Findings

### What worked well

- **What happened**: All six declared success criteria measured Met after merge: the exact Step 14 shape is present, both adversarial rubrics are decidable, 44/44 retro cases pass, repository validation passes, and issues #11 and #12 are closed with one exact payload each.
  **Why**: The plan separated wording, issue discharge, lifecycle transitions, and an independent invariant attack into five units with executable acceptance evidence.
  **How to apply**: Keep integrity mechanisms paired with both exact structural checks and fresh counterexample-based judgment.
  **Cites**: Phase 2–3 data

- **What happened**: The worktree was removed only after R1 recorded successful live-state transfer, made the base ledger authoritative, and replayed the persisted full-suite command on merged HEAD.
  **Why**: R1 made state handoff an explicit transition with start/success ledger records rather than an implicit cleanup side effect.
  **How to apply**: Treat cleanup as a state transition whenever later phases still consume workspace-local evidence.
  **Cites**: T5 / Phase 2–3 data

- **What happened**: The human-owned R2 packet remained blocked until exact addendum approval, then closed both issues with read-before-write preflights and terminal body/state verification.
  **Why**: The gate separated contract-substitution approval from issue-mutation approval and recorded both before execution.
  **How to apply**: Put human-only success criteria behind a durable point-of-risk gate and verify the external terminal state before completion.
  **Cites**: Phase 2–3 data

### What to improve

- **What happened**: The previous retro claimed its isolated-Retro final-action obligation was tracked in `ROADMAP.md`, but commit `f0473d9` never added the row.
  **Why**: Reconciliation counted the retro table rather than checking the durable tracker bidirectionally.
  **How to apply**: A carry-forward is registered only when both the retro row and durable tracker entry exist; check names in both directions before completion.
  **Cites**: T1

- **What happened**: Two validator versions went green while the operative shipping contract was contradictory or hidden under a tilde fence.
  **Why**: Whole-file substring checks and backtick-only stripping treated examples, comments, and fenced text as operative requirements.
  **How to apply**: Scope prose validators to uniquely identified operative sections and keep disposable negative mutations that prove false-green cases fail.
  **Cites**: T4

- **What happened**: The merge command completed its remote effect but returned exit 1 during local cleanup, leaving a safe but ambiguous partial state.
  **Why**: `gh pr merge --delete-branch` coupled remote merge and local branch deletion even though `main` was owned by another worktree.
  **How to apply**: Split remote merge, merged-result verification, state handoff, local cleanup, and remote deletion into separately observed and recorded operations.
  **Cites**: T5

- **What happened**: SC2's compliant pair is durable only as reviewer prose; no raw same-kind fixture or digest output can replay it independently.
  **Why**: The criterion required a reviewer judgment over the shipped wording, not preservation of the empirical comparison inputs.
  **How to apply**: Add the pair and parser false-green mutations to the already-fired conformance-suite fixture work rather than treating prose as replay evidence.
  **Cites**: T6

- **What happened**: U5 was durably committed, but facilitator output and the general dispatch-time persistence rule remain outside committed shared workflow contracts.
  **Why**: This cycle voluntarily persisted one review artifact without changing `reviewing` or `retrospective` dispatch semantics.
  **How to apply**: Require verbatim output persistence before a review or facilitator result can influence implementation or findings.
  **Cites**: T2

### Process observations

- **What happened**: Ten review rounds produced four fixed comments and one intentionally deferred human-only action; the deferred action completed after the merge gate.
  **Why**: Review scope expanded from plan conformance to non-artifact comparands, headless lifecycle contradictions, standalone shipping, and validator false-greens.
  **How to apply**: Budget independent review for complementary modes and consumers, not repeated readings of the same scope.
  **Cites**: Phase 2–3 data

- **What happened**: T0-T7 proved this plan's forced-failure behavior, but the shared planning matrix still does not require those fields.
  **Why**: The sealed plan excluded `schemas/plan-schema.md` and planning step 10 from its approved file set and explicitly deferred the durable contract.
  **How to apply**: Preserve the fired tracker latch until the reusable schema and planning authoring rule land.
  **Cites**: T3

## Carry-forward items registered

| Item | Type | Priority | Tracked at |
|---|---|---|---|
| Require isolated-worktree Retros to merge or push their retro in the final action and update the ledger pointer | process | P2 | `ROADMAP.md` — repaired registration; trigger: next Retro phase running inside an isolated worktree |
| Persist facilitator and reviewer output verbatim before consuming it | process | P3 | `ROADMAP.md` — existing facilitator/reviewer persistence row |
| Add executable probe syntax, expected partial state, rerun behavior, and compensation ownership to the reusable forced-failure matrix contract | process | P3 | `ROADMAP.md` — fired forced-failure row |
| Make the SC2 pairs and validator false-green mutations independently replayable | process | P2 | `ROADMAP.md` Future candidates — existing fired Conformance suite row |
| Require review dispatches to construct the cheapest conforming counterexample against an integrity mechanism | process | P1 | `ROADMAP.md` — fired invariant-attack row |
| Encode threatened-success-criterion severity in the shared review triage contract | process | P2 | `ROADMAP.md` — fired severity row |
| Split remote merge and local cleanup into separately recorded operations | process | P2 | `ROADMAP.md` — new PR #15 partial-success row |
| Pass `SSH_AUTH_SOCK` to dispatched committers and verify each commit signature | process | P3 | `ROADMAP.md` — fired: U1-U4 signatures reported `G`, socket pass-through evidence absent, durable rule remains |

## Lessons

- A tracker row that never existed is not Not started; it is a registration defect.
- A green prose validator that accepts contradictory operative text is another untested contract, not a gate.
- A command can complete its remote effect and still fail locally; persist the effect boundary before recovery or cleanup.

## Compounding

- compound invocation: `Documentation complete — docs/solutions/workflow-issues/loop-deliverable-in-disposable-state.md`
