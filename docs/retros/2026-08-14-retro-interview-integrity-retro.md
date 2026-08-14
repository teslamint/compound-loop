# Retro: retro-interview-integrity

- Date: 2026-08-14
- Source: PR #13
- Spec: docs/specs/2026-08-14-retro-interview-integrity-design.md
- Plan: docs/plans/2026-08-14-001-fix-retro-interview-integrity-plan.md

## Release data

| Metric | Value |
|---|---|
| **Changed non-test lines** | 1129 (1110 added + 19 removed) |
| Commits | 34 |
| Review rounds | 4 (3 branch-review rounds, 1 PR feedback round) |
| Comments (fixed / deferred) | 4 / 0 |
| CI failures | 0 |
| Duration (first spec commit → merge) | under 1 day (2026-08-14T04:28Z → 2026-08-14T14:03Z) |
| Units planned / completed | 6 / 6 |

## Success criteria: measured vs declared

| # | Declared criterion | Measurement (command / rubric) | Measured result | Verdict |
|---|---|---|---|---|
| 1 | Check 9 rejects a missing fifth level and a missing non-final level | `./scripts/test-retro-format-drift.sh` | verified: exit 0, 44 cases, C1–C4 pass | Met |
| 2 | The Phase 8 capability rule discriminates across the whole ladder | `./scripts/test-retro-format-drift.sh` | verified: C5 rejects `phase8-headless`, C7 rejects `phase8-capability`, C6 accepts | Met |
| 3 | The `not-probed` warrant discriminates on all four conditions | `./scripts/test-retro-format-drift.sh` | verified: C8 and C13 accept; C9, C10, C12, C14, C15 each reject under their own name | Met |
| 4 | The reconciliation catches a substitution a matching count conceals | `./scripts/test-retro-format-drift.sh` | verified: C11 rejects `phase4-unregistered` | Met |
| 5 | No existing retro document invalidated; the suite is not left broken | `./scripts/validate.sh` and the drift suite | verified: validate exit 0, `[cf-tid] 26 retro docs checked`, cases A–J pass | Met |
| 6 | Rung 4 named by capability only in all three files | judgment rubric | verified: rubric applied — `rg -n "headless/single-agent" skills/ references/` returns no match; `dispatch-degradation.md:22` retains a budget clause naming no flag | Met |
| 7 | Issue #7's thesis corrected where asserted, and the fired trigger recorded | `rg -n "Conformance suite.*fired" ROADMAP.md`; Ship posts the comment | verified: ROADMAP half returns 1 row naming this cycle; `gh issue view 7` returns 0 comments, so the outward half is unposted | Partially Met — the repository half landed, the issue comment has not been posted |
| 8 | Phase 4 states both cardinalities with a stated no-table fallback | judgment rubric | verified: rubric applied — Phase 4 carries all five instructions and `schemas/retro-template.md:48` carries the reconciliation bullet | Met |

## Carry-forward from previous retro

| Item | Status | Evidence |
|---|---|---|
| Transfer live release-loop state to the base checkout before shipping removes its isolated worktree | Not started | Edit-based trigger did not fire: no unit modified `skills/shipping/SKILL.md` or `skills/release-loop/SKILL.md`. The hazard was avoided operationally rather than fixed — the worktree sits under `.claude/worktrees/`, outside the path shipping removes, so cleanup was deferred past Retro (`.release-loop/progress.md`, ship entries) |
| Require forced-failure plans to name executable probe syntax, expected partial state, and compensation ownership | Not started | Edit-based trigger did not fire: no unit modified the planning contract, and this plan carried the stateless fallback rather than a matrix |

- Reconciliation: registered 2, accounted for 2
- Previous doc shape: conformant

## Interview Transcript

- Independence level: heterogeneous (facilitator: GPT-family via `codex exec -s read-only`, artifacts only — no working-conversation access)
- Rounds used: 1 (max 5)

| ID | Round | Phase | Probe | Answer | Evidence | Verdict (verbatim) |
|---|---|---|---|---|---|---|
| T1 | 1 | 5 | Four deviation addenda in one cycle — healthy recording discipline, or a plan approved with defects a better review should have caught? | Both, and the second is the load-bearing half. Two independent plan reviews and a scoped re-review ran before approval and still let three plan divergences through. | Addenda 008, 009, 010, 011; `.release-loop/progress.md` plan-review entries | accepted — Recording the addenda was healthy containment, but three plan divergences plus one spec correction after extensive approval review is evidence that the planning gate approved a materially defective contract. |
| T2 | 1 | 5 | Is declaring the cycle complete honest while SC7's outward half is unposted, and what closes it? | It is not complete. The ledger records the obligation as pending; the prepared command is preparation evidence, never execution. | `docs/specs/…-design.md:245`; `gh issue view 7` → 0 comments; `.release-loop/briefs/issue-7-command.md` | accepted — The record is candid about the gap, but that candor precludes an honest declaration that the full cycle or all success criteria are complete. Closure requires posting the prepared correction and verifying the resulting issue comment, not merely retaining the command. |
| T3 | 1 | 5 | Why did three internal branch-review rounds miss two checker defects central to this cycle? | Because the sealed plan under-specified both rules and internal review checked conformance to that plan. W4 was specified only to reject `self-attested`; W2 was specified to compare the bullet's two numbers. | Plan lines 202, 208, 210; commits `4da1462`, `490ff91`; harness 38 → 44 cases | accepted — The evidence indicates that internal review verified conformance to an under-specified sealed plan instead of adversarially testing the semantic claims that "confirmation means accepted" and "counts describe actual rows." The reviews therefore reproduced the plan's blind spots rather than independently challenging them. |
| T4 | 1 | 5 | The duplicate-name concealment was known internally and deferred. Was that triage defensible? | No. It was recorded as a U5 Minor and triaged as carry-forward, while it instantiates exactly the concealment class scenario S4 promises to detect. | `.release-loop/progress.md` U5 MinorFindings; spec S4; commit `490ff91` adding C32–C34 | accepted — The carry-forward triage was not defensible because it knowingly preserved the exact concealment class the approved design promised to detect. External review prevented shipment of the defect, but it does not validate the earlier severity judgment. |

Verdict cell values: `accepted` | `no evidenced answer (3 rejections): <verbatim>` | `self-attested` | `no evidenced answer (dispatch cap): <verbatim>`

## Findings

### What worked well

- **What happened**: The repaired protocol was exercised on itself immediately, and the dispatch rule it fixed changed this retro's own behavior — a heterogeneous facilitator ran where the pre-change ladder would have permitted a self-checklist.
  **Why**: Rung 4 now names a capability instead of a flag, and `mode:headless` qualifies for no rung, so the availability of `codex exec` decided the level rather than the invocation mode.
  **How to apply**: When a cycle repairs a protocol the team itself runs, schedule the first real use immediately after merge; it converts the change from an assertion into an observation.
  **Cites**: T1, this doc's Interview Transcript header

- **What happened**: Every divergence between the sealed plan and reality was recorded as a committed addendum rather than absorbed silently — four of them, each with byte-verified quotes of the contract it diverged from.
  **Why**: The first divergence set the precedent at the U4 gate, and each later reviewer held the branch to the standard the branch had set for itself.
  **How to apply**: Record the first divergence formally even when it feels disproportionate; the precedent is what makes the third and fourth cheap.
  **Cites**: T1; addenda 008–011

### What to improve

- **What happened**: Three internal branch-review rounds passed a checker that accepted any verdict except `self-attested`, and that trusted reconciliation counts written in a bullet rather than counted from rows. An external reviewer found both.
  **Why**: The sealed plan specified both rules narrowly, and internal review verified conformance to the plan instead of attacking the invariant the plan claimed to establish.
  **How to apply**: For each integrity mechanism, construct the cheapest artifact that satisfies the written checks while violating the intent, and require the mechanism to reject it before approval.
  **Cites**: T3; commits `4da1462`, `490ff91`

- **What happened**: The duplicate-name concealment was found internally at U5, classified Minor, and triaged as carry-forward. It is the exact concealment class scenario S4 exists to detect.
  **Why**: Severity was judged against the checker's scope — fixtures only, never real documents — rather than against the promise the spec made.
  **How to apply**: Grade a finding against the criterion it threatens, not against the blast radius of the code it sits in. A hole in the mechanism a cycle exists to build is never Minor.
  **Cites**: T4; spec S4; commit `490ff91`

- **What happened**: Success Criterion 7 shipped half-unmet. The ROADMAP half landed; the issue #7 correction comment has not been posted.
  **Why**: The criterion spans a boundary no skill crosses, so nothing in the pipeline could discharge it, and merge did not force the question.
  **How to apply**: A criterion whose completion depends on a human action outside the pipeline should carry an explicit gate that blocks the loop's completion report, not only a ledger line.
  **Cites**: T2; `gh issue view 7` → 0 comments

### Process observations

- **What happened**: The running session loaded the pre-merge copy of `skills/retrospective/SKILL.md` from the main checkout while the merged contract lived in the worktree, so the skill text driving this retro described four independence levels and the old ladder.
  **Why**: Skills load from the plugin's installed path, which is the main checkout, and it had not been pulled after the merge.
  **How to apply**: After merging a change to a skill this loop itself invokes, re-read the shipped file from the branch under test rather than trusting the loaded skill text.
  **Cites**: Phase 1 verification of `skills/retrospective/SKILL.md:74` in the worktree against the loaded skill text

- **What happened**: Subagent shells did not inherit `SSH_AUTH_SOCK`, so one unit's commits landed unsigned on a branch whose every other commit was signed.
  **Why**: The signing key was already the unattended `notify-only` key; the failure was environmental inheritance, not key policy. A stale `rebase-merge` directory then blocked the first re-sign attempt.
  **How to apply**: Pass the agent socket explicitly in any dispatch that will commit, and verify `%G?` per commit rather than at the end of a branch.
  **Cites**: `.release-loop/progress.md` implement entries; commits `ca01f83` through `ec0b192` re-signed as `9fb8a68` through `da02406`

## Carry-forward items registered

| Item | Type | Priority | Tracked at |
|---|---|---|---|
| Adversarially test each integrity mechanism before approval by constructing the cheapest artifact that satisfies its written checks while violating its intent | process | P1 | `ROADMAP.md` — trigger: next cycle whose deliverable is an integrity or verification mechanism |
| Grade a finding against the success criterion it threatens, not the blast radius of the code it sits in | process | P2 | `ROADMAP.md` — trigger: next review that triages a finding touching a mechanism the cycle exists to build |
| A success criterion completed by a human action outside the pipeline needs a gate that blocks the completion report | process | P2 | `ROADMAP.md` — trigger: next spec declaring a criterion no skill can discharge |
| Pass `SSH_AUTH_SOCK` explicitly to any dispatched agent that commits, and verify signature state per commit | process | P3 | `ROADMAP.md` — trigger: next cycle dispatching implementer subagents that commit |
| Transfer live release-loop state to the base checkout before shipping removes its isolated worktree | process | P2 | `ROADMAP.md` — carried from 2026-08-05; trigger unchanged: next change touching shipping cleanup or the release-loop post-merge handoff |
| Require forced-failure plans to name executable probe syntax, expected partial state, and compensation ownership | process | P3 | `ROADMAP.md` — carried from 2026-08-05; trigger unchanged: next planning-contract change |

## Lessons

- Review that verifies conformance to a sealed plan reproduces the plan's blind spots; only an attack on the claimed invariant finds what the plan failed to say.
- A hole in the mechanism a cycle exists to build is never Minor, however small its blast radius in code.
- Emptiness is not evidence: a check that reads a number an author wrote proves only that the author can write numbers.
- Four deviation addenda in one cycle is healthy containment and a defective planning gate at the same time; the recording discipline does not excuse the approval.

## Compounding

- compound invocation: `Documentation complete — docs/solutions/workflow-issues/verify-against-plan-vs-attack-the-invariant.md`
