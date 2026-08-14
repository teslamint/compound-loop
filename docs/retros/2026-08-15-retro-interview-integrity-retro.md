# Retro: retro-interview-integrity

- Date: 2026-08-15
- Source: PR #13
- Spec: docs/specs/2026-08-14-retro-interview-integrity-design.md
- Plan: docs/plans/2026-08-14-001-fix-retro-interview-integrity-plan.md

## Release data

| Metric | Value |
|---|---|
| **Changed non-test lines** | 1129 (1110 added + 19 removed) |
| Commits | 34 |
| Review rounds | 4 (3 artifact-review rounds + 1 PR feedback round) |
| Comments (fixed / deferred) | 4 / 0 |
| CI failures | 0 |
| Duration (first spec commit → merge) | 0 days (75bbbd5 at 04:28:50Z → merge at 14:03:52Z, 9h35m) |
| Units planned / completed | 6 / 6 |

## Success criteria: measured vs declared

| # | Declared criterion | Measurement (command / rubric) | Measured result | Verdict |
|---|---|---|---|---|
| 1 | *(discriminating)* Check 9 rejects a tree where the fifth level is missing from either consumer file, and rejects a tree where a non-final level is missing from the probes contract | `bash scripts/test-retro-format-drift.sh` — C1, C2, C3 fail-as-expected, C4 passes, suite exits 0 | verified: `ALL CASES PASSED`, exit 0, C1–C34 plus cases A–J, 225s wall | Met |
| 2 | *(discriminating)* The Phase 8 absent-capability rule discriminates across the whole ladder — `mode:headless` alone rejected, a single channel rejected, both channels accepted | `bash scripts/test-retro-format-drift.sh` — C5 rejects `phase8-headless`, C7 rejects `phase8-capability`, C6 accepts | verified: C5, C6, C7 all report `pass` in the same run; suite exit 0 | Met |
| 3 | *(discriminating)* The `not-probed` warrant discriminates on all four conditions | `bash scripts/test-retro-format-drift.sh` — C8 and C13 accept, C9/C10/C12/C14/C15 each reject by condition name | verified: C8–C15 all report `pass` in the same run; suite exit 0 | Met |
| 4 | *(discriminating)* The carry-forward reconciliation catches a substitution that a matching row count conceals | `bash scripts/test-retro-format-drift.sh` — C11 rejects naming `phase4-unregistered` | verified: C11 reports `pass` in the same run; suite exit 0 | Met |
| 5 | *(invariance guard — passes before and after; not evidence the change landed)* No existing retro document is invalidated and the existing suite is not left broken | `bash scripts/validate.sh` exits 0 with `[cf-tid]` ≥ 26 docs and `retro interview format` ok; drift suite exits 0 with A–J passing | verified: `ALL CHECKS PASSED`; `[cf-tid] carry-forward T-ID integrity: 26 retro docs checked`; `retro interview format: template and skill prose agree`; A–J pass | Met |
| 6 | *(discriminating)* The dispatch ladder and both downstream files name rung 4 by capability only, and each states that `mode:headless` does not qualify | judgment rubric — read the rung-4 sentence in `skills/retrospective/SKILL.md`, the opening of `references/interview-probes.md`, and the no-subagent tier of `references/dispatch-degradation.md` | verified: rubric applied, reading cited — SKILL.md:76 names the absent capability and states `mode:headless` qualifies for no rung; SKILL.md:116 adds that a strict dispatch budget is not an absent capability either; `references/dispatch-degradation.md` retains a budget clause with no headless mention; no slash-joined capability/flag pair remains | Met |
| 7 | *(discriminating)* Issue #7's falsified thesis is corrected where it was asserted, and the fired Conformance-suite trigger is recorded | `grep -nE "Conformance suite.*fired" ROADMAP.md`; plus the Ship phase posts a comment on issue #7 citing the seven independent-facilitator retro docs. Owner: the human at the Ship gate (`enforces: P7`) | verified: ROADMAP.md:12 carries the Conformance-suite row marked `**fired**` (1 match). unverified: the issue #7 comment is not posted — `gh issue view 7` reports 0 comments; payload sits at `.release-loop/briefs/issue-7-body.md` with the command and non-authorization marker at `.release-loop/briefs/issue-7-command.md` | Partially met — the outward half is unexecuted; no skill owns the transition and the human has not run the prepared command (T2) |
| 8 | *(discriminating)* Phase 4 states both carry-forward cardinalities as a mechanical step reachable without a facilitator, with a stated fallback for a previous doc lacking the table | judgment rubric — confirm five instructions present in Phase 4 prose, not only in `interview-probes.md`, and the count field present in `schemas/retro-template.md` | verified: rubric applied, reading cited — `skills/retrospective/SKILL.md`:52–55 carries all five (read the registration table, reconcile by name, record registered N and accounted-for M, treat an unregistered row as a defect, handle the no-table case); `schemas/retro-template.md`:48–54 carries the bullet-form count field with its degraded variant | Met |

## Carry-forward from previous retro

| Item | Status | Evidence |
|---|---|---|
| Transfer live release-loop state to the base checkout before shipping removes its isolated worktree | In progress | Edit-based trigger did not fire — `git show --numstat 0086cff` lists no `skills/shipping/` or `skills/release-loop/` path among its 14 files, so no contract change landed. The exposure was mitigated operationally during this retro execution: state copied from `.claude/worktrees/feat+retro-interview-integrity/.release-loop/` to the base checkout, 33 files, manifests `.release-loop/state-transfer-src.md5` and `.release-loop/state-transfer-dst.md5` byte-identical; `bash scripts/validate.sh` then reported `[final-action] final_action shape valid` and `[body-seal] 5 verified` where it previously reported `no active progress.md — skipped` and `4 verified`. The mitigation has no committed evidence because `.release-loop/` is gitignored (T1) |
| Require forced-failure plans to name executable probe syntax, expected partial state, and compensation ownership | Not started | Edit-based trigger "next planning-contract change" did not fire — no unit of this cycle touched `skills/planning/`; `git show --numstat 0086cff` confirms no such path |

- Reconciliation: registered 2, accounted for 2

- Previous doc shape: conformant

## Interview Transcript

- Independence level: heterogeneous
- Rounds used: 2 (max 5)

| ID | Round | Phase | Probe | Answer | Evidence | Verdict (verbatim) |
|---|---|---|---|---|---|---|
| T1 | 1→2 | 4 | For the live-state transfer marked In progress, what trigger class applies, and which file line or concrete transfer event proves both that the trigger fired and that the 33-file md5 manifests matched? | Edit-based, and it did not fire — no committed contract change exists and I do not claim one. The transfer itself is operational, with on-disk evidence only. | `git show --numstat 0086cff` (no shipping/release-loop path); `.release-loop/state-transfer-src.md5` vs `.release-loop/state-transfer-dst.md5` identical over 33 files; `.release-loop/progress.md` final line; `bash scripts/validate.sh` → `[body-seal] 5 verified` | accepted |
| T2 | 1→2 | 4 | Which durable tracker row, issue event, or commit carries forward SC7's unposted issue #7 correction after this retro? | None exists as you read this — a gap, not an answer. Remedy is a new ROADMAP row naming the payload path and the human owner, registered in this retro's Phase 4 step. | `gh issue view 7` → 0 comments; `ROADMAP.md` had no such row; payload only at `.release-loop/briefs/issue-7-body.md` inside a gitignored directory | accepted |
| T3 | 1→2 | 5 | Which exact API-error event and successful `codex exec` review artifact prove that the heterogeneous lane ran only after the subagent lane failed and materially revised the design? | The subagent lane died on an API error and the heterogeneous lane then ran via `codex exec`, returning needs-rework; two of its P0s were independently confirmed and both changed the shipped artifacts. No reviewer transcript was retained. | `.release-loop/progress.md`:48 (ocx-gpt-5-5 API error, re-dispatch via `codex exec -s read-only`), :49 (needs-rework 6 P0 / 2 P1), :50; `docs/deviations/2026-07-21-check9-probes-level-scope-003.md`; `skills/retrospective/SKILL.md`:76 | accepted |
| T4 | 1→2 | 5 | Which two independent plan-review artifacts identify the missing committed-red fixtures as blocking, and which four red/green commit pairs prove U1, U3, U4, and U5 followed the reworked plan? | Two reviews dispatched heterogeneous by model family returned needs-rework (5 P0) and REVISE (1 P0 + 3 Major) with the same shared P0: committed-red never occurs. Four units then committed twice each. | `.release-loop/progress.md`:74–77; rework `bcfff3c`, seal `b8776fa`; pairs U1 `db994ed`→`49f468c`, U3 `02e496f`→`b600096`, U4 `9fb8a68`→`62ef004`, U5 `17ccb91`→`e01db8e` | accepted |
| T5 | 1→2 | 5 | Which re-review artifact and exact C1/C2 failure lines justify classifying those cases as fixture-setup regression guards rather than discrimination evidence? | The scoped re-review returned 4 CLOSED, 4 PARTIALLY CLOSED and 4 newly introduced defects; the reclassification landed with it. C1 and C2 fail at fixture setup because the value they remove does not exist pre-change, so discrimination rests on C3 and case H. | `.release-loop/progress.md`:83–86; commit `86f066c`; plan lines 120, 127, 22; fresh `bash scripts/test-retro-format-drift.sh` → `ALL CASES PASSED` exit 0 | accepted |

Facilitator's closing note, verbatim: `NOTE: Acceptance preserves three material gaps: T1 has only gitignored operational mitigation, T2 has no durable carry-forward registration, and T3 has no retained reviewer-output artifact beyond the progress ledger and corroborating design changes.`

## Findings

### What worked well

- **What happened**: The heterogeneous design review ran only because the same-family subagent lane died on an API error, and it returned needs-rework with 6 P0 findings that changed the shipped spec.
  **Why**: Two facilitator channels existed — a subagent primitive and an external CLI — and they fail independently. The surviving channel was the one the old rung-4 rule treated as unavailable whenever `mode:headless` was set.
  **How to apply**: Treat channel independence as the reason to name capabilities rather than flags in any degradation ladder; a flag describes intent, a capability describes what the environment can still do.
  **Cites**: T3

- **What happened**: Two independent plan reviews, dispatched heterogeneous by model family, converged on the same blocking defect — the fixtures were never committed red, while SC1–SC4 defined their evidence in terms of that red commit.
  **Why**: Both reviewers read the Success Criteria against the plan's commit sequence instead of against its prose claims, which is where the contradiction was visible.
  **How to apply**: When criteria define evidence as a history state, review the commit sequence as a first-class artifact; prose describing a red run is not the red commit the criterion names.
  **Cites**: T4

### What to improve

- **What happened**: SC7's outward half is unmet at retro time: the issue #7 correction is drafted and verified but unposted, and issues #6, #8, #9, #10 remain open although `0086cff` merged their repairs.
  **Why**: The spec assigned the transition to the human at the Ship gate and no skill owns it, so the loop reached Retro with an outward obligation that nothing surfaces except a brief inside gitignored state.
  **How to apply**: A cycle that declares a human-owned outward action must register it on a durable tracker at the moment it is declared, not at the moment it is discovered missing.
  **Cites**: T2

- **What happened**: The live loop state, the prepared issue payload, and the prepared command all lived only in `.claude/worktrees/feat+retro-interview-integrity/.release-loop/`, a gitignored directory that the sanctioned worktree cleanup would have deleted.
  **Why**: `.release-loop/` is designed as disposable per-loop state, but this cycle put a post-merge deliverable inside it, which gives a disposable location a durable obligation.
  **How to apply**: Before any worktree cleanup, classify each file in loop state as disposable or outliving the loop; anything in the second class moves to a committed path first.
  **Cites**: T1

- **What happened**: No reviewer output was retained for any of the three review rounds — `.release-loop/reviews/` holds only diffs, so every review claim in this retro rests on ledger lines plus the artifacts the reviews demonstrably changed.
  **Why**: The dispatch wrote findings into the working conversation and the ledger summarized them; nothing wrote the reviewer's own text to a file.
  **How to apply**: Persist facilitator and reviewer output verbatim as an artifact at dispatch time; a ledger summary cannot be re-audited against the reviewer's actual words.
  **Cites**: T3

### Process observations

- **What happened**: C1 and C2 were reclassified from discrimination evidence to regression guards after a re-review showed they fail at fixture setup, because the value they remove does not exist on the pre-change tree.
  **Why**: A case that mutates a value into absence cannot discriminate on a tree where that value is already absent — it never reaches its assertion.
  **How to apply**: For any removal-shaped fixture, check whether the pre-change tree can even reach the assertion before counting the case as discrimination evidence.
  **Cites**: T5

- **What happened**: The plan's carry-forward audit recorded the worktree-deletion row as not fired while noting its operational exposure was live, and that exposure then materialized in this cycle exactly as written.
  **Why**: The row's registered trigger was edit-based (a shipping or release-loop contract change) while the actual risk was operational, so a correct audit produced a true "not fired" beside a live hazard.
  **How to apply**: When a carry-forward row's trigger class does not match the class of risk it describes, record the mismatch as an open unknown rather than letting the trigger verdict stand as an all-clear.
  **Cites**: T1, Phase 2–3 data

## Carry-forward items registered

| Item | Type | Priority | Tracked at |
|---|---|---|---|
| Post the prepared issue #7 correction and close issues #6, #8, #9, #10 whose repairs merged in 0086cff | process | P2 | `ROADMAP.md` — trigger: immediate, human-owned at the Ship gate; payload `.release-loop/briefs/issue-7-body.md`, command `.release-loop/briefs/issue-7-command.md` |
| Move loop artifacts that outlive their loop out of gitignored `.release-loop/` into a committed path before worktree cleanup | process | P2 | `ROADMAP.md` — trigger: next change to shipping cleanup, release-loop archival, or any unit that writes a post-merge deliverable into loop state |
| Persist facilitator and reviewer output verbatim as an artifact at dispatch time | process | P3 | `ROADMAP.md` — trigger: next change to the interview protocol's round contract or to `reviewing`'s dispatch steps |

## Lessons

- A degradation ladder that names a caller flag instead of a capability will declare a channel dead while that channel is actively carrying the review — this cycle's heterogeneous facilitator only ran because the other lane failed.
- A disposable state directory holding a post-merge deliverable turns the sanctioned cleanup step into data loss; the deliverable, not the directory, decides where it belongs.
- A carry-forward row whose trigger class does not match its risk class produces a truthful "not fired" next to a live hazard, so the audit verdict is not an all-clear.

## Compounding

- compound invocation: `Documentation complete — docs/solutions/workflow-issues/loop-deliverable-in-disposable-state.md`
