# Retro: retro-interview-integrity

- Date: 2026-08-15
- Source: PR #13
- Spec: docs/specs/2026-08-14-retro-interview-integrity-design.md
- Plan: docs/plans/2026-08-14-001-fix-retro-interview-integrity-plan.md
- Consolidates: the 2026-08-14 retro committed on the feature branch as `bdf58dc` and never merged (its pre-squash chain is retained at tag `evidence/retro-interview-integrity`). Its four transcript rows appear below renumbered T6–T9 from their original T1–T4 — the only renumbering in this document, applied because the same T1–T5 identifiers were already published here in commit `6683d0f`. Mapping: T6←T3, T7←T4, T8←T2, T9←T1 of `bdf58dc`. One cycle now has one retro document.

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
| 6 | *(discriminating)* The dispatch ladder and both downstream files name rung 4 by capability only, and each states that `mode:headless` does not qualify | judgment rubric — read the rung-4 sentence in `skills/retrospective/SKILL.md`, the opening of `references/interview-probes.md`, and the no-subagent tier of `references/dispatch-degradation.md` | verified: rubric applied, reading cited — SKILL.md:76 names the absent capability and states `mode:headless` qualifies for no rung; SKILL.md:116 adds that a strict dispatch budget is not an absent capability either; `references/dispatch-degradation.md` retains a budget clause with no headless mention; `rg -n "headless/single-agent" skills/ references/` returns no match | Met |
| 7 | *(discriminating)* Issue #7's falsified thesis is corrected where it was asserted, and the fired Conformance-suite trigger is recorded | `grep -nE "Conformance suite.*fired" ROADMAP.md`; plus the Ship phase posts a comment on issue #7 citing the seven independent-facilitator retro docs. Owner: the human at the Ship gate (`enforces: P7`) | verified: ROADMAP.md:12 carries the Conformance-suite row marked `**fired**` (1 match). Outward half measured twice: at the 2026-08-14 interview `gh issue view 7` returned 0 comments (unposted); on 2026-08-15 the human posted the prepared payload and `gh issue view 7 --json comments` returns 1 — [issues/7#issuecomment-5297152028](https://github.com/teslamint/compound-loop/issues/7#issuecomment-5297152028) | Met — as of 2026-08-15. It shipped Partially met at merge and stayed that way for a day, which is the gap T8 probes; the criterion itself is now discharged |
| 8 | *(discriminating)* Phase 4 states both carry-forward cardinalities as a mechanical step reachable without a facilitator, with a stated fallback for a previous doc lacking the table | judgment rubric — confirm five instructions present in Phase 4 prose, not only in `interview-probes.md`, and the count field present in `schemas/retro-template.md` | verified: rubric applied, reading cited — `skills/retrospective/SKILL.md`:52–55 carries all five (read the registration table, reconcile by name, record registered N and accounted-for M, treat an unregistered row as a defect, handle the no-table case); `schemas/retro-template.md`:48–54 carries the bullet-form count field with its degraded variant | Met |

## Carry-forward from previous retro

| Item | Status | Evidence |
|---|---|---|
| Transfer live release-loop state to the base checkout before shipping removes its isolated worktree | Not started | The registered fix is a contract change and none landed: the edit-based trigger did not fire, and `git show --numstat 0086cff` lists no `skills/shipping/` or `skills/release-loop/` path among its 14 files. The hazard was handled operationally, twice. On 2026-08-14 it was avoided by position — the worktree sat under `.claude/worktrees/`, outside the path shipping removes — so cleanup was deferred past Retro. On 2026-08-15 the state was transferred to the base checkout before cleanup ran: 33 files, manifests `state-transfer-src.md5` and `state-transfer-dst.md5` byte-identical, after which `[final-action]` flipped from `no active progress.md — skipped` to `final_action shape valid` and `[body-seal]` from 4 to 5 verified. Only then were the worktrees removed. Neither mitigation has committed evidence, because `.release-loop/` is gitignored (T1) |
| Require forced-failure plans to name executable probe syntax, expected partial state, and compensation ownership | Not started | Edit-based trigger "next planning-contract change" did not fire — no unit touched `skills/planning/`, and this plan carried the stateless fallback rather than a matrix |

- Reconciliation: registered 2, accounted for 2

- Previous doc shape: conformant

## Interview Transcript

- Independence level: heterogeneous
- Rounds used: 3 (max 5) — 1 dispatch in the 2026-08-14 interview (T6–T9) and 2 in the 2026-08-15 interview (T1–T5), both facilitated by a GPT-family model through `codex exec -s read-only` receiving artifacts only, with no working-conversation access

| ID | Round | Phase | Probe | Answer | Evidence | Verdict (verbatim) |
|---|---|---|---|---|---|---|
| T1 | 1→2 | 4 | For the live-state transfer marked In progress, what trigger class applies, and which file line or concrete transfer event proves both that the trigger fired and that the 33-file md5 manifests matched? | Edit-based, and it did not fire — no committed contract change exists and I do not claim one. The transfer itself is operational, with on-disk evidence only. | `git show --numstat 0086cff` (no shipping/release-loop path); `state-transfer-src.md5` vs `state-transfer-dst.md5` identical over 33 files; the archived `progress.md` final entries; `bash scripts/validate.sh` → `[body-seal] 5 verified` | accepted |
| T2 | 1→2 | 4 | Which durable tracker row, issue event, or commit carries forward SC7's unposted issue #7 correction after this retro? | None exists as you read this — a gap, not an answer. Remedy is a new ROADMAP row naming the payload path and the human owner, registered in this retro's Phase 4 step. | `gh issue view 7` → 0 comments at the time of the probe; `ROADMAP.md` had no such row; payload only at `.release-loop/briefs/issue-7-body.md` inside a gitignored directory | accepted |
| T3 | 1→2 | 5 | Which exact API-error event and successful `codex exec` review artifact prove that the heterogeneous lane ran only after the subagent lane failed and materially revised the design? | The subagent lane died on an API error and the heterogeneous lane then ran via `codex exec`, returning needs-rework; two of its P0s were independently confirmed and both changed the shipped artifacts. No reviewer transcript was retained. | Archived `progress.md`:48 (ocx-gpt-5-5 API error, re-dispatch via `codex exec -s read-only`), :49 (needs-rework 6 P0 / 2 P1), :50; `docs/deviations/2026-07-21-check9-probes-level-scope-003.md`; `skills/retrospective/SKILL.md`:76 | accepted |
| T4 | 1→2 | 5 | Which two independent plan-review artifacts identify the missing committed-red fixtures as blocking, and which four red/green commit pairs prove U1, U3, U4, and U5 followed the reworked plan? | Two reviews dispatched heterogeneous by model family returned needs-rework (5 P0) and REVISE (1 P0 + 3 Major) with the same shared P0: committed-red never occurs. Four units then committed twice each. | Archived `progress.md`:74–77; rework `bcfff3c`, seal `b8776fa`; pairs U1 `db994ed`→`49f468c`, U3 `02e496f`→`b600096`, U4 `9fb8a68`→`62ef004`, U5 `17ccb91`→`e01db8e`, all reachable from tag `evidence/retro-interview-integrity` | accepted |
| T5 | 1→2 | 5 | Which re-review artifact and exact C1/C2 failure lines justify classifying those cases as fixture-setup regression guards rather than discrimination evidence? | The scoped re-review returned 4 CLOSED, 4 PARTIALLY CLOSED and 4 newly introduced defects; the reclassification landed with it. C1 and C2 fail at fixture setup because the value they remove does not exist pre-change, so discrimination rests on C3 and case H. | Archived `progress.md`:83–86; commit `86f066c`; plan lines 120, 127, 22; fresh `bash scripts/test-retro-format-drift.sh` → `ALL CASES PASSED` exit 0 | accepted |
| T6 | 1 | 5 | Why did three internal branch-review rounds miss two checker defects central to this cycle? | Because the sealed plan under-specified both rules and internal review checked conformance to that plan. W4 was specified only to reject `self-attested`; W2 was specified to compare the bullet's two numbers. | Plan lines 202, 208, 210; commits `4da1462`, `490ff91`; harness 38 → 44 cases | accepted — The evidence indicates that internal review verified conformance to an under-specified sealed plan instead of adversarially testing the semantic claims that "confirmation means accepted" and "counts describe actual rows." The reviews therefore reproduced the plan's blind spots rather than independently challenging them. |
| T7 | 1 | 5 | The duplicate-name concealment was known internally and deferred. Was that triage defensible? | No. It was recorded as a U5 Minor and triaged as carry-forward, while it instantiates exactly the concealment class scenario S4 promises to detect. | Archived `progress.md` U5 MinorFindings; spec S4; commit `490ff91` adding C32–C34 | accepted — The carry-forward triage was not defensible because it knowingly preserved the exact concealment class the approved design promised to detect. External review prevented shipment of the defect, but it does not validate the earlier severity judgment. |
| T8 | 1 | 5 | Is declaring the cycle complete honest while SC7's outward half is unposted, and what closes it? | It is not complete. The ledger records the obligation as pending; the prepared command is preparation evidence, never execution. | `docs/specs/…-design.md:245`; `gh issue view 7` → 0 comments; `.release-loop/briefs/issue-7-command.md` | accepted — The record is candid about the gap, but that candor precludes an honest declaration that the full cycle or all success criteria are complete. Closure requires posting the prepared correction and verifying the resulting issue comment, not merely retaining the command. |
| T9 | 1 | 5 | Four deviation addenda in one cycle — healthy recording discipline, or a plan approved with defects a better review should have caught? | Both, and the second is the load-bearing half. Two independent plan reviews and a scoped re-review ran before approval and still let three plan divergences through. | Addenda 008, 009, 010, 011; archived `progress.md` plan-review entries | accepted — Recording the addenda was healthy containment, but three plan divergences plus one spec correction after extensive approval review is evidence that the planning gate approved a materially defective contract. |

Facilitator's closing note from the 2026-08-15 interview, verbatim: `NOTE: Acceptance preserves three material gaps: T1 has only gitignored operational mitigation, T2 has no durable carry-forward registration, and T3 has no retained reviewer-output artifact beyond the progress ledger and corroborating design changes.`

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

- **What happened**: The repaired protocol was exercised on itself immediately, and the dispatch rule it fixed changed this retro's own behavior — a heterogeneous facilitator ran where the pre-change ladder would have permitted a self-checklist.
  **Why**: Rung 4 now names a capability instead of a flag, and `mode:headless` qualifies for no rung, so the availability of `codex exec` decided the level rather than the invocation mode.
  **How to apply**: When a cycle repairs a protocol the team itself runs, schedule the first real use immediately after merge; it converts the change from an assertion into an observation.
  **Cites**: T9, this document's Interview Transcript header

- **What happened**: Every divergence between the sealed plan and reality was recorded as a committed addendum rather than absorbed silently — four of them, each with byte-verified quotes of the contract it diverged from.
  **Why**: The first divergence set the precedent at the U4 gate, and each later reviewer held the branch to the standard the branch had set for itself.
  **How to apply**: Record the first divergence formally even when it feels disproportionate; the precedent is what makes the third and fourth cheap.
  **Cites**: T9; addenda 008–011

### What to improve

- **What happened**: Three internal branch-review rounds passed a checker that accepted any verdict except `self-attested`, and that trusted reconciliation counts written in a bullet rather than counted from rows. An external reviewer found both.
  **Why**: The sealed plan specified both rules narrowly, and internal review verified conformance to the plan instead of attacking the invariant the plan claimed to establish.
  **How to apply**: For each integrity mechanism, construct the cheapest artifact that satisfies the written checks while violating the intent, and require the mechanism to reject it before approval.
  **Cites**: T6; commits `4da1462`, `490ff91`

- **What happened**: The duplicate-name concealment was found internally at U5, classified Minor, and triaged as carry-forward. It is the exact concealment class scenario S4 exists to detect.
  **Why**: Severity was judged against the checker's scope — fixtures only, never real documents — rather than against the promise the spec made.
  **How to apply**: Grade a finding against the criterion it threatens, not against the blast radius of the code it sits in. A hole in the mechanism a cycle exists to build is never Minor.
  **Cites**: T7; spec S4; commit `490ff91`

- **What happened**: Success Criterion 7 shipped half-unmet and stayed that way for a day: the ROADMAP half landed at merge, the issue #7 correction was posted only on 2026-08-15, after this retro's second interview probed for its tracker row.
  **Why**: The criterion spans a boundary no skill crosses, so nothing in the pipeline could discharge it, and merge did not force the question. Its only surfacing artifact was a brief inside gitignored loop state.
  **How to apply**: A criterion whose completion depends on a human action outside the pipeline should carry an explicit gate that blocks the loop's completion report, and a durable tracker row registered when the criterion is declared rather than when a later phase notices it missing.
  **Cites**: T2, T8

- **What happened**: The live loop state, the prepared issue payload, and the prepared command all lived only in `.claude/worktrees/feat+retro-interview-integrity/.release-loop/`, a gitignored directory that the sanctioned worktree cleanup would have deleted.
  **Why**: `.release-loop/` is designed as disposable per-loop state, but this cycle put a post-merge deliverable inside it, which gives a disposable location a durable obligation.
  **How to apply**: Before any worktree cleanup, classify each file in loop state as disposable or outliving the loop; anything in the second class moves to a committed path first.
  **Cites**: T1

- **What happened**: A complete retro for this cycle was committed on the feature branch as `bdf58dc` and never merged, so a second retro was written a day later from the merged tree, and the first document's four registered ROADMAP items were untracked in the interim.
  **Why**: The Retro phase ran inside the isolated worktree and committed there, while the loop ledger still read `phase: retro / phase_status: in-progress`. Nothing on `main` referenced the branch document, and a survey of `origin/main` could not see it.
  **How to apply**: A retro commit is a merge obligation, not a local artifact — push or merge it in the same action that writes it, and update the ledger pointer at that moment. When auditing a cycle's completeness, enumerate unmerged branch commits, never only the base branch's tree.
  **Cites**: T4, this document's Consolidates line

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

- **What happened**: The running session loaded the pre-merge copy of `skills/retrospective/SKILL.md` from the main checkout while the merged contract lived in the worktree, so the skill text driving the first retro described four independence levels and the old ladder.
  **Why**: Skills load from the plugin's installed path, which is the main checkout, and it had not been pulled after the merge.
  **How to apply**: After merging a change to a skill this loop itself invokes, re-read the shipped file from the branch under test rather than trusting the loaded skill text.
  **Cites**: T9; Phase 1 verification of `skills/retrospective/SKILL.md:74` in the worktree against the loaded skill text

- **What happened**: Subagent shells did not inherit `SSH_AUTH_SOCK`, so one unit's commits landed unsigned on a branch whose every other commit was signed.
  **Why**: The signing key was already the unattended `notify-only` key; the failure was environmental inheritance, not key policy. A stale `rebase-merge` directory then blocked the first re-sign attempt.
  **How to apply**: Pass the agent socket explicitly in any dispatch that will commit, and verify `%G?` per commit rather than at the end of a branch.
  **Cites**: T4; archived `progress.md` implement entries; commits `ca01f83` through `ec0b192` re-signed as `9fb8a68` through `da02406`

## Carry-forward items registered

| Item | Type | Priority | Tracked at |
|---|---|---|---|
| Adversarially test each integrity mechanism before approval by constructing the cheapest artifact that satisfies its written checks while violating its intent | process | P1 | `ROADMAP.md` — trigger: next cycle whose deliverable is an integrity or verification mechanism |
| Grade a finding against the success criterion it threatens, not the blast radius of the code it sits in | process | P2 | `ROADMAP.md` — trigger: next review that triages a finding touching a mechanism the cycle exists to build |
| A success criterion completed by a human action outside the pipeline needs a gate that blocks the completion report | process | P2 | `ROADMAP.md` — trigger: next spec declaring a criterion no skill can discharge |
| Post the prepared issue #7 correction and close issues #6, #8, #9, #10 whose repairs merged in 0086cff | process | P2 | `ROADMAP.md` — discharged 2026-08-15, row marked Done with the comment URL |
| Loop artifacts that outlive their loop must move out of gitignored `.release-loop/` into a committed path before worktree cleanup | process | P2 | `ROADMAP.md` — trigger: next change to shipping cleanup, release-loop archival, or any unit writing a post-merge deliverable into loop state |
| A retro committed on a feature branch must be merged or pushed in the same action, with the ledger pointer updated then | process | P2 | `ROADMAP.md` — trigger: next Retro phase running inside an isolated worktree |
| Persist facilitator and reviewer output verbatim as an artifact at dispatch time | process | P3 | `ROADMAP.md` — trigger: next change to the interview protocol's round contract or to `reviewing`'s dispatch steps |
| Pass `SSH_AUTH_SOCK` explicitly to any dispatched agent that commits, and verify signature state per commit | process | P3 | `ROADMAP.md` — trigger: next cycle dispatching implementer subagents that commit |
| Transfer live release-loop state to the base checkout before shipping removes its isolated worktree | process | P2 | `ROADMAP.md` — carried from 2026-08-05; trigger unchanged: next change touching shipping cleanup or the release-loop post-merge handoff |
| Require forced-failure plans to name executable probe syntax, expected partial state, and compensation ownership | process | P3 | `ROADMAP.md` — carried from 2026-08-05; trigger unchanged: next planning-contract change |

## Lessons

- Review that verifies conformance to a sealed plan reproduces the plan's blind spots; only an attack on the claimed invariant finds what the plan failed to say.
- A hole in the mechanism a cycle exists to build is never Minor, however small its blast radius in code.
- Emptiness is not evidence: a check that reads a number an author wrote proves only that the author can write numbers.
- Four deviation addenda in one cycle is healthy containment and a defective planning gate at the same time; the recording discipline does not excuse the approval.
- A degradation ladder that names a caller flag instead of a capability will declare a channel dead while that channel is actively carrying the review — this cycle's heterogeneous facilitator only ran because the other lane failed.
- A disposable state directory holding a post-merge deliverable turns the sanctioned cleanup step into data loss; the deliverable, not the directory, decides where it belongs.
- A carry-forward row whose trigger class does not match its risk class produces a truthful "not fired" next to a live hazard, so the audit verdict is not an all-clear.
- An unmerged retro is an invisible retro: a cycle can be audited as unfinished while its finished record sits one branch away.

## Compounding

- compound invocation: `Documentation complete — docs/solutions/workflow-issues/verify-against-plan-vs-attack-the-invariant.md`
- compound invocation: `Documentation complete — docs/solutions/workflow-issues/loop-deliverable-in-disposable-state.md`
- compound invocation: `Documentation complete — docs/solutions/workflow-issues/history-state-success-criterion.md`
- compound invocation: `Documentation complete — docs/solutions/workflow-issues/degradation-ladder-flag-vs-capability.md`
