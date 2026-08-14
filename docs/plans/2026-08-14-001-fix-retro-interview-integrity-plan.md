---
schema: plan/v1
title: Retro Interview Integrity
type: fix
status: draft
date: 2026-08-14
execution: code
origin: docs/specs/2026-08-14-retro-interview-integrity-design.md
---

## Goal

Repair five defects in the interview protocol of the `retrospective` skill. The defects let an agent skip the facilitator, claim a degraded level falsely, or take a cheaper rung. This plan ships the vocabulary change, two prose gates, the carry-forward reconciliation, and the fixtures that hold them.

## Architecture notes

**Vocabulary flows one way.** `schemas/retro-template.md` holds the closed level list. Check 9 in `scripts/validate.sh` parses that list. Check 9 then asserts that every parsed level appears in `skills/retrospective/SKILL.md`. For `skills/retrospective/references/interview-probes.md` the current rule is narrower. It checks the list-final level only, at lines 371-375. A comment at lines 366-370 records that scope and cites deviation 003. U1 generalizes the probes rule to every level. The direction of the flow does not change.

**U1 moves six files in one commit pair.** Check 9 asserts an exact level count. A count bump before the template change fails the check. A template change before the count bump also fails it. The template, both consumer files, and check 9 therefore move together. The `Independence level` definition in `CONCEPTS.md` lists the same vocabulary and joins them. `scripts/test-retro-format-drift.sh` is the sixth file. It carries the cases.

**U1 lands before U3, U4, and U5, for two reasons.** The first reason is fixture coherence. Cases C1 and C2 remove `not-probed` from a consumer file. That mutation needs the value to exist first. The second reason is the checker chain. U3 creates the checker function. U4 and U5 extend it. U3 therefore precedes both. U2 and U6 touch neither the vocabulary nor the checker. They may land in any position.

**Check 9 does not enforce the reverse direction.** The loop at lines 363-365 reads each template level and searches the skill file. Prose in a consumer file that names a level absent from the template triggers no failure. A skill edit before a template edit therefore leaves the tree green, not red. The ordering constraint above rests on fixture coherence and the checker chain alone.

**Each test-first unit commits twice.** The first commit carries the new cases in a red state. The second commit carries the change that turns them green. The approved spec requires this. `docs/deviations/2026-07-21-check9-probes-level-scope-003.md` sets the precedent: "Committed red before the check extension lands." The red commit is safe. The header of `scripts/test-retro-format-drift.sh` states that the suite runs by manual invocation only. `scripts/validate.sh` does not call it. `./scripts/validate.sh` therefore stays green at every commit in this plan.

**The checker is not a linter.** An agent executes the Phase 8 rule and the warrant at runtime. The shell checker is a second implementation. It runs against disposable fixtures only. It never reads `docs/retros/`. It proves two things: the rules discriminate, and the shipped prose still carries them. Each discrimination case therefore asserts its own clause in `skills/retrospective/SKILL.md`.

**Checker grammar.** The plan fixes the detection grammar so two implementers cannot diverge. Section scope always means the text from a named `## ` heading up to the next `## ` heading. A data row always means a pipe row whose first cell is neither a header label nor a `---` separator.

- `phase8-headless` matches the token `headless` on the `- Rounds used:` line, when the `- Independence level:` line names a degraded level.
- `phase8-capability` requires both anchors `no subagent primitive` and `no external facilitator CLI` on that same line.
- `W1` reads the last cell of every data row in the `## Measured vs. Declared` section. It fails on `Partially met` or `Not met`, using the casing of `schemas/retro-template.md` line 35.
- `W2` matches the regular expression `registered ([0-9]+), accounted for ([0-9]+)` on the reconciliation bullet. It fails when the two captures differ. It also fails when that line carries the degraded suffix.
- `W3` reads the `## Findings` section. It treats a `### ` sub-heading as a bucket. It fails when any list item appears under a bucket other than What Worked Well.
- `W4` counts data rows in the `## Interview Transcript` section. It reads the Verdict cell as the last cell of each data row.
- `phase4-unregistered` reads the first cell of every data row in two sections: `## Carry-forward items registered` in the previous document, and `## Carry-forward from previous retro` in the current document.

All matches are case-insensitive. The level values are the exception and match exactly.

**Condition precedence.** The checker prints one condition name. It evaluates in this fixed order and reports the first failure: `phase8-headless`, `phase8-capability`, `W1`, `W2`, `W3`, `W4`, `phase4-unregistered`.

**Known Pattern — disposable fixture trees.** `scripts/test-retro-format-drift.sh` builds a `mktemp -d` copy for each case. The case mutates the copy. The case runs `scripts/validate.sh` inside the copy. The case then asserts a named `FAIL:` string. Every new case follows this shape. No case mutates the real worktree.

**Backtick constraint on verdict vocabulary.** Case C at lines 127-135 strips backticked `self-attested` from a copy of `skills/retrospective/SKILL.md`. It then asserts that no bare occurrence remains. Any new sentence in that file that names `self-attested` must therefore keep it backticked. U4 step 13 writes such a sentence.

**Anchor assertions are section-scoped.** A discrimination case asserts its anchor inside the section that owns the rule, never anywhere in the file. C5, C6, and C7 scope to the Phase 8 section. C8 through C15 scope to the warrant section. C11 scopes to the Phase 4 section. A file-wide substring check would stay green after the operative clause moved or weakened, which is the failure the coupling exists to prevent.

**The dispatch ladder is a shared file.** Twelve skill and reference files read `references/dispatch-degradation.md`. U2 rewords the tier-3 parenthetical. U2 does not delete it. A deletion would remove the only budget-based tier-3 sanction in the repository. It would also change the headless single-call collapse of `compound`. Phase 7 of `retrospective` depends on that collapse.

## Assumption Recheck

The origin spec retains nine live assumptions. The planner reran every retained command on the working tree at `1e929bf`.

| # | Approved claim | Fresh evidence | Outcome |
|---|---|---|---|
| 1 | All four current levels appear in `interview-probes.md` | `rg -c -e heterogeneous -e "same-model fresh-context" -e in-thread -e self-checklist skills/retrospective/references/interview-probes.md` → `4` | match |
| 2 | Check 9 hardcodes count 4 and selects the probes rung as `levels[-1]` | `rg -n -e "len\(set\(levels\)\) != 4" -e "degraded = levels\[-1\]" scripts/validate.sh` → lines 333, 373 | match |
| 3 | `dispatch-degradation.md` carries the headless conflation | `rg -n -e "no subagent capability at all" references/dispatch-degradation.md` → line 22 | match |
| 4 | 18 retro documents record `Rounds used: 0` | `rg -c "Rounds used: 0" docs/retros/` → 18 files | match |
| 5 | The independent-facilitator path ran 7 times | `rg -n -e "Independence level: heterogeneous" -e "Independence level: same-model" -e "Independence level: in-thread" docs/retros/` → 7 lines | match |
| 6 | The fixture convention uses disposable `mktemp -d` trees | `rg -c "mktemp -d" scripts/test-retro-format-drift.sh` → `2` | match |
| 7 | Case H asserts the 4-level guard string | `rg -n "expected 4 distinct" scripts/test-retro-format-drift.sh` → lines 253, 272 | match |
| 8 | `dispatch-degradation.md` has 12 consumers | `rg -ln "dispatch-degradation" skills/ references/ schemas/` → 12 files | match |
| 9 | One retro document lacks a registration table | `rg -L --files-without-match "Carry-forward items registered" docs/retros/` → `docs/retros/2026-08-05-add-license-retro.md` | match |

The recheck found no contradiction. The recheck found no unavailable evidence. No deviation addendum is necessary. Plan finalization is not blocked.

## File structure

**Vocabulary sources and consumers.** These files move together in U1.

- Modify `schemas/retro-template.md`. The independence-level line gains a fifth value. The carry-forward section gains a reconciliation bullet in U5.
- Modify `skills/retrospective/SKILL.md`. It gains the fifth level, the rung-4 rewrite, the Phase 8 clause, the warrant, and the Phase 4 steps.
- Modify `skills/retrospective/references/interview-probes.md`. It gains a rewritten opening paragraph and a verdict-forms row.
- Modify `CONCEPTS.md`. The `Independence level` definition gains the fifth value.
- Modify `scripts/validate.sh`. Check 9 gains a new level count and a new probes rule.

**Shared dispatch ladder.**

- Modify `references/dispatch-degradation.md`. U2 rewords the tier-3 parenthetical.

**Verification.**

- Modify `scripts/test-retro-format-drift.sh`. It gains the case A–J audit, cases C1–C15, and the fixture checker.

**Tracker and Ship preparation.**

- Modify `ROADMAP.md`. U6 records the fired Conformance-suite trigger.
- Create `.release-loop/briefs/issue-7-body.md`. U6 drafts the issue #7 correction body. `gh` posts this file verbatim, so it carries no metadata.
- Create `.release-loop/briefs/issue-7-command.md`. U6 records the exact command and the non-authorization marker. Both files are local working state and stay uncommitted.

## Scenario coverage map

| S-ID | Unit chain | Scenario evidence |
|---|---|---|
| S1 | U2 | `happy` in U2. `rg -n "headless/single-agent" skills/ references/` returns the rung-4 sentence before the change. It returns no match after the change. Covers S1 |
| S2 | U2 → U3 | `integration` in U3. C6 accepts a both-channels claim. C7 rejects a single-channel claim. Covers S2 |
| S3 | U1 → U4 | `integration` in U4. C8 accepts the dispatch path. C13 accepts the no-channel path. Covers S3 |
| S4 | U5 | `integration` in U5. C11 rejects a substituted row that a matching count conceals. Covers S4 |
| S5 | U3 | `integration` in U3. C5 rejects a `mode:headless` justification. Covers S5 |
| S6 | U1 → U4 | `integration` in U4. C9 rejects an unmet criterion under `not-probed`. Covers S6 |

Every S-ID completes through a unit chain. Named evidence walks every S-ID. Every row names a runnable command. S1 uses an `rg` assertion instead of a fixture case, because U2 changes prose. The spec declares SC6 a judgment rubric for the same reason. The `rg` command is the mechanical half of that rubric. It does not replace the rubric.

## Implementation Units

## U1: Add the fifth independence level
Execution note: test-first
Files:
  Modify: schemas/retro-template.md, skills/retrospective/SKILL.md, skills/retrospective/references/interview-probes.md, CONCEPTS.md, scripts/validate.sh
  Test: scripts/test-retro-format-drift.sh
Interfaces:
  Consumes: the `- Independence level:` line of `schemas/retro-template.md`, pipe-separated
  Produces: a five-value closed level list whose fifth value is `not-probed (no narrative warranted)`; check 9 asserting `len(set(levels)) == 5`; check 9 asserting that every parsed level appears in `skills/retrospective/SKILL.md` and in `skills/retrospective/references/interview-probes.md`
Test scenarios:
  happy: C4 — check 9 passes on an unmutated tree that carries five levels
  edge: C3 — check 9 fails when the case removes `in-thread (approximated independence)` from `interview-probes.md`. This proves the rule reads every level, not the last one
  error: C1 — check 9 fails when the case removes `not-probed (no narrative warranted)` from `skills/retrospective/SKILL.md`. C2 — check 9 fails on the same removal from `interview-probes.md`. Each `FAIL:` line names the file and the missing level. C1 and C2 are regression guards for the new value, not discriminating cases: the value does not exist before this unit, so their pre-change red is a fixture-setup artifact rather than evidence about the old validator. C3 and case H carry the discrimination for this unit
  integration: n/a — leaf unit. The scenario-walking cases belong to U3, U4, and U5
Steps:
  1. Read case H at lines 239-256 of `scripts/test-retro-format-drift.sh`. Its mutation removes `| self-checklist` from the template copy. It asserts the string `expected 4 distinct independence levels`.
  2. Audit cases A through J for other assertions on the level count. Case I at line 272 asserts `expected 4 distinct backticked verdict forms`. This unit does not change the verdict count. Cases B and G assert no count.
  3. Change case H's assertion string to `expected 5 distinct independence levels`. Keep case H's mutation unchanged.
  4. Add cases C1, C2, C3, and C4 to `scripts/test-retro-format-drift.sh`. Follow the shape of `case_g()`, which opens at line 216 and ends at line 237.
  5. Run `./scripts/test-retro-format-drift.sh`. Confirm four distinct red mechanisms, and record each observed line. C1 and C2 fail at fixture setup, because `not-probed (no narrative warranted)` does not yet exist in either consumer file, so the assert-before-mutate guard trips. That is a setup artifact, so C1 and C2 prove nothing about the old validator; they guard the new value against later removal. C3 fails its expected-FAIL assertion, because the positional rule ignores a removed non-final level and check 9 passes the mutated tree. Case H fails its assertion string, because the current validator still reports four. C3 and case H are this unit's discrimination evidence.
  6. Commit: "test(retro): Add level-vocabulary cases red before check 9 changes"
  7. Append `not-probed (no narrative warranted)` to the `- Independence level:` line of `schemas/retro-template.md`. Place it last.
  8. Add the same value to the independence-level paragraph of `skills/retrospective/SKILL.md`.
  9. Add the same value to the `Independence level` definition in `CONCEPTS.md`.
  10. Add a `not-probed (no narrative warranted)` row to the verdict-forms table in `skills/retrospective/references/interview-probes.md`. The row states two paths. On the reachable-channel path the confirmation row carries `accepted`. On the no-channel path the table holds no verdict cells. The row also states that `self-attested` is never a `not-probed` verdict. Keep every occurrence of `self-attested` inside backticks.
  11. Change the level-count assertion at line 333 of `scripts/validate.sh` from `!= 4` to `!= 5`. Change its message to `expected 5 distinct independence levels`.
  12. Replace lines 366-375 of `scripts/validate.sh`. The range covers the comment block and the code block together. The comment records the list-final scope and cites deviation 003, so it must not survive the change. Write a loop over every value in `levels`. Call the existing `boundary_search` helper at line 306 for each value against `probes_text`. Fail with a message that names the probes file and the missing level. Write a new comment that records the all-levels scope and names this plan as the supersession.
  13. Run `./scripts/test-retro-format-drift.sh`. Confirm that cases A through J pass. Confirm that C1 through C4 pass.
  14. Run `./scripts/validate.sh`. Confirm exit 0. Confirm the `retro interview format: template and skill prose agree` line.
  15. Commit: "fix(retro): Add the not-probed independence level and generalize check 9"
Acceptance: `./scripts/validate.sh` exits 0. `./scripts/test-retro-format-drift.sh` exits 0 with cases A–J and C1–C4 passing. `rg -c -e heterogeneous -e "same-model fresh-context" -e in-thread -e self-checklist -e "not-probed" skills/retrospective/references/interview-probes.md` returns 5. `git log --oneline -2` shows the red commit before the green commit.

## U2: Name the floor rung by capability
Execution note: skip-test-first
Files:
  Modify: skills/retrospective/SKILL.md, skills/retrospective/references/interview-probes.md, references/dispatch-degradation.md
Interfaces:
  Consumes: the ladder sentence in the Facilitator model selection paragraph of `skills/retrospective/SKILL.md`; the opening paragraph of `skills/retrospective/references/interview-probes.md`; the tier-3 sentence at line 22 of `references/dispatch-degradation.md`
  Produces: a rung-4 description that names only an absent facilitator channel; an explicit statement that `mode:headless` qualifies for no rung
Test scenarios:
  happy: `rg -n "headless/single-agent" skills/ references/` returns the rung-4 sentence before the change. It returns no match after the change. Covers S1
  edge: `rg -n "strict dispatch budget" references/dispatch-degradation.md` returns line 22. This proves the tier-3 budget sanction survived the reword
  error: n/a — this unit rewrites three prose sentences. It has no failure path. A mistyped edit shows up as a failed happy or edge command
  integration: n/a — leaf unit. The Phase 8 cases that depend on this wording belong to U3
Steps:
  1. Find the ladder sentence in `skills/retrospective/SKILL.md`. It ends with `→ headless/single-agent: skip the interview and run the probe list as a fixed self-checklist`.
  2. Replace the fourth rung with a capability-only description. The new text names two absent channels: no subagent primitive, and no external facilitator CLI.
  3. Add one sentence to the same paragraph. It states that `mode:headless` qualifies for no rung of the ladder. It gives the reason: the flag governs user interaction, not worker dispatch.
  4. Find the sentence in `skills/retrospective/references/interview-probes.md` that begins `In headless/single-agent mode this file runs as a fixed self-checklist`. Rewrite it to name the absent capability instead of the flag.
  5. Replace the parenthetical `(or the run is headless with a strict budget)` at line 22 of `references/dispatch-degradation.md` with `(or a strict dispatch budget applies)`. Keep the parenthetical. It is the only budget-based tier-3 sanction in the file.
  6. Run `rg -ln "dispatch-degradation" skills/ references/ schemas/`. Read the citing sentence in each of the 12 files. Confirm that no file depends on the word "headless" in the tier-3 description. Record the result.
  7. Run `./scripts/validate.sh`. Confirm exit 0.
  8. Commit: "fix(retro): Name the dispatch ladder's floor rung by capability, not by flag"
Acceptance: `./scripts/validate.sh` exits 0. `rg -n "headless/single-agent" skills/ references/` returns no match. `rg -n "strict dispatch budget" references/dispatch-degradation.md` returns line 22.

## U3: Require a named absent capability in Phase 8
Execution note: test-first
Files:
  Modify: skills/retrospective/SKILL.md
  Test: scripts/test-retro-format-drift.sh
Interfaces:
  Consumes: the Phase 8 pre-commit sentence of `skills/retrospective/SKILL.md`, which requires a valid independence level and a rounds-used count
  Produces: a checker function that takes a retro-document path; the function exits 0 on accept; the function exits nonzero on reject and prints one condition name, either `phase8-capability` or `phase8-headless`
Test scenarios:
  happy: C6 — the checker accepts `self-checklist` when the rounds-used line carries both anchors. The canonical accepted string is `no subagent primitive and no external facilitator CLI reachable in this harness`
  edge: C7 — the checker rejects `self-checklist` with `phase8-capability` when the line carries only `no subagent primitive in this harness`. The second anchor is absent
  error: C5 — the checker rejects `self-checklist` with `phase8-headless` when the line carries the token `headless`
  integration: C5, C6, and C7 each assert that Phase 8 of `skills/retrospective/SKILL.md` carries three anchors: `not an absent capability`, `no subagent primitive`, and `no external facilitator CLI`. Covers S2, Covers S5
Steps:
  1. Add a checker function to `scripts/test-retro-format-drift.sh`. It reads a fixture retro document. It extracts the `- Independence level:` line. It extracts the `- Rounds used:` line. It treats `in-thread (approximated independence)` and `self-checklist` as degraded levels.
  2. Make the checker exit nonzero with `phase8-headless` when a degraded level carries the token `headless` on the rounds-used line.
  3. Make the checker exit nonzero with `phase8-capability` when a degraded level lacks either anchor `no subagent primitive` or `no external facilitator CLI` on that line. Match both anchors case-insensitively as substrings.
  4. Add cases C5, C6, and C7. Each case builds its fixture document in its own `mktemp -d` tree. Each case calls the checker. Each case asserts the exit status. Each rejecting case also asserts the printed condition name.
  5. Add one more assertion to C5, C6, and C7. Each extracts the Phase 8 section from the case's copy of `skills/retrospective/SKILL.md`. Each then asserts that the section carries the three anchors that steps 8 through 11 write. Scope the assertion to that section, never to the whole file.
  6. Run `./scripts/test-retro-format-drift.sh`. Confirm that C5, C6, and C7 fail on the anchor assertion, because Phase 8 carries none of the three anchors yet. Record the failure lines.
  7. Commit: "test(retro): Add Phase 8 capability cases red before the clause lands"
  8. Extend the Phase 8 pre-commit check in `skills/retrospective/SKILL.md`. A degraded independence level must name the capability that was absent. Scope the requirement to `in-thread (approximated independence)` and `self-checklist`.
  9. Add to the same paragraph that `mode:headless` is not an absent capability.
  10. Add that a `self-checklist` claim must cover both facilitator channels of the ladder: no subagent primitive, and no external facilitator CLI. Give the reason: rung 1 names an external CLI facilitator that does not depend on the subagent primitive.
  11. Add that an `in-thread` claim names why fresh context was unavailable.
  12. Run `./scripts/test-retro-format-drift.sh`. Confirm that C5, C6, and C7 pass. Confirm that no earlier case regressed.
  13. Run `./scripts/validate.sh`. Confirm exit 0.
  14. Commit: "fix(retro): Require a named absent capability for degraded independence levels"
Acceptance: `./scripts/test-retro-format-drift.sh` exits 0. C5 rejects with `phase8-headless`. C7 rejects with `phase8-capability`. C6 accepts. `./scripts/validate.sh` exits 0. `git log --oneline -2` shows the red commit before the green commit.

## U4: Gate not-probed behind the warrant
Execution note: test-first
Files:
  Modify: skills/retrospective/SKILL.md
  Test: scripts/test-retro-format-drift.sh
Interfaces:
  Consumes: the checker function that U3 produces; the reconciliation bullet `- Reconciliation: registered <N>, accounted for <M>` that U5 step 8 adds to `schemas/retro-template.md`
  Produces: the same checker with four added conditions, `W1`, `W2`, `W3`, and `W4`; a warrant section in `skills/retrospective/SKILL.md`
Test scenarios:
  happy: C8 — the checker accepts `not-probed` on the dispatch path. The fixture carries one confirmation row with verdict `accepted`, no `Partially met` or `Not met` cell, a reconciliation bullet whose two numbers agree, and no finding outside What Worked Well
  edge: C13 — the checker accepts `not-probed` on the no-channel path. The fixture carries a zero-row table and both capability anchors on the rounds-used line
  error: C9 rejects with `W1` on a `Not met` cell. C10 rejects with `W2` on `registered 4, accounted for 3`. C15 rejects with `W3` on a finding under Process Observations. C12 rejects with `W4` on a zero-row table whose rounds-used line carries neither capability anchor. C14 rejects with `W4` on a confirmation row whose verdict is `self-attested`
  integration: C8, C9, C10, C12, C13, C14, and C15 each assert that `skills/retrospective/SKILL.md` carries the anchors `W1`, `W2`, `W3`, and `W4`. Covers S3, Covers S6
Steps:
  1. Add condition `W1` to the checker. It fails when the Verdict column of the Phase 3 table carries `Partially met` or `Not met`. Use the casing of `schemas/retro-template.md` line 35 and match case-insensitively. It passes that check when the document states that no spec exists.
  2. Add condition `W2`. It parses the bullet `- Reconciliation: registered <N>, accounted for <M>` in the carry-forward section. It fails when N and M differ. It also fails when the bullet carries the suffix `— degraded: previous retro has no registration table`.
  3. Add condition `W3`. It fails when the Findings section carries any entry outside the What Worked Well bucket.
  4. Add condition `W4`. It fails when the transcript holds zero data rows and the rounds-used line lacks either capability anchor. It also fails when a transcript row carries verdict `self-attested` under level `not-probed`.
  5. Order the seven conditions in the checker as the Architecture notes fix: `phase8-headless`, `phase8-capability`, `W1`, `W2`, `W3`, `W4`, `phase4-unregistered`. Report the first failure only.
  6. Add cases C8, C9, C10, C12, C13, C14, and C15. Each case builds its fixture document in its own `mktemp -d` tree. Each case asserts the exit status. Each rejecting case asserts the condition name.
  7. Add to each of the seven cases an assertion that extracts the warrant section from the case's copy of `skills/retrospective/SKILL.md`. Each asserts that the section carries the four anchors `W1`, `W2`, `W3`, and `W4` that steps 10 through 13 write. Scope the assertion to that section, never to the whole file.
  8. Run `./scripts/test-retro-format-drift.sh`. Confirm that all seven cases fail on the anchor assertion. Record the failure lines.
  9. Commit: "test(retro): Add not-probed warrant cases red before the warrant lands"
  10. Add the warrant to `skills/retrospective/SKILL.md` beside the independence-level paragraph. Label the four conditions `W1` through `W4`. Write W1: no Phase 3 criterion reads `Partially met` or `Not met`, or the document states that no spec exists.
  11. Write W2: the Phase 4 reconciliation records registered N equal to accounted-for M, with no unregistered row. Add that the degraded no-table fallback never satisfies W2. A `registered 0, accounted for 0` result from a missing table therefore does not authorize `not-probed`.
  12. Write W3: the Findings section carries no entry outside What Worked Well.
  13. Write W4 as two paths. On the first path a facilitator channel is reachable. One facilitator dispatch then confirms the judgment. The transcript records that confirmation as a row with verdict `accepted`. State that `self-attested` is never a valid `not-probed` verdict. Keep every occurrence of `self-attested` inside backticks, because case C at lines 127-135 fails on a bare occurrence. On the second path no channel is reachable. `not-probed` then carries the same absent-capability claim that `self-checklist` carries.
  14. Add one sentence on the residual limit. W1 through W4 raise the cost of a false claim. They do not remove it. This matches the Known limit that the protocol already declares.
  15. Move the Phase 8 sentence `A zero-row table under a valid header is valid — nothing warranted probing`. It now applies to `not-probed` alone.
  16. Run `./scripts/test-retro-format-drift.sh`. Confirm that all seven cases pass. Confirm that no earlier case regressed. Confirm that case C still passes, which proves the backtick constraint held.
  17. Run `./scripts/validate.sh`. Confirm exit 0.
  18. Commit: "fix(retro): Gate not-probed behind a four-condition warrant"
Acceptance: `./scripts/test-retro-format-drift.sh` exits 0. C8 and C13 accept. C9, C10, C12, C14, and C15 each reject under their own condition name. `./scripts/validate.sh` exits 0. `git log --oneline -2` shows the red commit before the green commit.

## U5: Reconcile carry-forward items by name
Execution note: test-first
Files:
  Modify: skills/retrospective/SKILL.md, schemas/retro-template.md
  Test: scripts/test-retro-format-drift.sh
Interfaces:
  Consumes: the `## Carry-forward from previous retro` section of `schemas/retro-template.md`; the checker function that U3 produces
  Produces: the exact bullet `- Reconciliation: registered <N>, accounted for <M>` under that heading; the degraded form of that bullet, which appends `— degraded: previous retro has no registration table`; the checker with an added condition `phase4-unregistered`
Test scenarios:
  happy: the checker accepts a fixture whose current table reproduces all four registered names
  edge: the checker rejects a fixture whose reconciliation bullet carries the degraded suffix. It rejects under `W2`, because U4 step 2 defines that suffix as a failure
  error: C11 — the previous document registers four items. The current table holds four rows. One registered name is replaced by an unregistered one. The checker rejects with `phase4-unregistered`
  integration: C11 asserts that Phase 4 of `skills/retrospective/SKILL.md` carries the anchors `row by row, by name`, `registered`, and `accounted for`. Covers S4
Steps:
  1. Add condition `phase4-unregistered` to the checker in `scripts/test-retro-format-drift.sh`. The checker takes a second path for the previous retro document.
  2. Make the condition compare item names between two tables. The first is the `Carry-forward items registered` table of the previous document. The second is the `Carry-forward from previous retro` table of the current document. Compare the first cell of each data row. Strip whitespace. Match case-insensitively.
  3. Make the condition fail when a current row names an item that the previous document did not register.
  4. Add case C11. It builds both fixture documents in one `mktemp -d` tree. It asserts the exit status. It asserts the condition name.
  5. Add to C11 an assertion that extracts the Phase 4 section from the case's copy of `skills/retrospective/SKILL.md`. It asserts that the section carries the three anchors that steps 9 through 12 write. Scope the assertion to that section, never to the whole file.
  6. Run `./scripts/test-retro-format-drift.sh`. Confirm that C11 fails on the anchor assertion. Record the failure line.
  7. Commit: "test(retro): Add the carry-forward substitution case red before Phase 4 changes"
  8. Add the bullet `- Reconciliation: registered <N>, accounted for <M>` under the `## Carry-forward from previous retro` heading of `schemas/retro-template.md`. Add the degraded form beside it, which appends `— degraded: previous retro has no registration table`. Use a bullet. Never use a table row: line 543 of `scripts/validate.sh` collects every three-column pipe row in that section, so a table-row form would read as a carry-forward item in every future document that follows the template.
  9. Add Phase 4 step one to `skills/retrospective/SKILL.md`. It reads the `Carry-forward items registered` table of the previous retro, not its narrative. Add the fallback: a previous document without that table yields registered N = 0 and the degraded suffix.
  10. Add Phase 4 step two: reconcile row by row, by name.
  11. Add Phase 4 step three: record both counts in the reconciliation bullet of the template.
  12. Add Phase 4 step four: a current row that the previous document did not register is itself a defect. Give the reason: it inflates M, and it can conceal a drop.
  13. Run `./scripts/test-retro-format-drift.sh`. Confirm that C11 passes. Confirm that no earlier case regressed.
  14. Run `./scripts/validate.sh`. Confirm exit 0. Confirm that `[cf-tid] carry-forward T-ID integrity` still reports at least 26 retro documents.
  15. Commit: "fix(retro): Reconcile carry-forward items by name with recorded counts"
Acceptance: `./scripts/test-retro-format-drift.sh` exits 0. C11 rejects with `phase4-unregistered`. `./scripts/validate.sh` exits 0 with the `[cf-tid]` line reporting at least 26 documents. `git log --oneline -2` shows the red commit before the green commit.

## U6: Record the fired trigger and prepare the issue correction
Execution note: skip-test-first
Files:
  Modify: ROADMAP.md
  Create: .release-loop/briefs/issue-7-body.md, .release-loop/briefs/issue-7-command.md
Interfaces:
  Consumes: the `Conformance suite` row of the Future candidates table in `ROADMAP.md`. Its trigger reads `First contract regression that structural validation (scripts/validate.sh) fails to catch`
  Produces: the same row marked as fired, with this cycle named as the evidence; a drafted comment body and its exact command, held as local working state for the Ship gate
Test scenarios:
  happy: `rg -n "Conformance suite.*fired" ROADMAP.md` returns the row after the edit
  edge: the drafted brief names all seven independent-facilitator retro documents by filename, which is what SC7 requires the comment to cite
  error: n/a — this unit edits one table row and writes one local file. It has no failure path
  integration: n/a — leaf unit. The tracker row has no runtime consumer
Steps:
  1. Run `rg -n "Conformance suite.*fired" ROADMAP.md`. Confirm exit 1. This pre-change result makes the criterion discriminating. A bare `fired` search would match the Schema-validators row at line 13 and prove nothing.
  2. Edit the trigger cell of the `Conformance suite` row. Mark the trigger fired. Name the evidence: structural validation passed 18 retro documents whose independence level the dispatch ladder did not warrant. That result is the contract regression the trigger names.
  3. Add to the same cell that the suite build stays deferred to its own cycle. The row therefore stays open. It must not read as delivered.
  4. Run `rg -n "Conformance suite.*fired" ROADMAP.md`. Confirm that it returns the row.
  5. Run `rg -n -e "Independence level: heterogeneous" -e "Independence level: same-model" -e "Independence level: in-thread" docs/retros/`. Record the seven filenames.
  6. Write `.release-loop/briefs/issue-7-body.md`. It holds the comment body and nothing else. The body states that the counts in the issue hold: 18 zero-round documents, 17 citing headless. The body states that the "never exercised" thesis is false. The body cites the seven filenames from step 5. Write no command and no marker into this file. `gh` posts the whole file, so any metadata here would reach the public issue.
  7. Write `.release-loop/briefs/issue-7-command.md`. It holds the exact command `gh issue comment 7 --body-file .release-loop/briefs/issue-7-body.md`.
  8. Add a non-authorization marker to `.release-loop/briefs/issue-7-command.md`. It states that the file is preparation evidence, never approval.
  9. Add a Log line to `.release-loop/progress.md`. It names both brief paths. It records the comment as a Ship-phase deliverable that no skill executes. The human runs the command at the Ship gate, and the orchestrator surfaces this line there.
  10. Run `./scripts/validate.sh`. Confirm exit 0.
  11. Commit: "docs(roadmap): Record the fired Conformance-suite trigger". Commit `ROADMAP.md` only. Both briefs and the ledger are local working state and stay uncommitted.
Acceptance: `rg -n "Conformance suite.*fired" ROADMAP.md` returns one line that names this cycle. `.release-loop/briefs/issue-7-body.md` exists and names seven retro filenames. `rg -c -e "gh issue comment" -e "preparation evidence" .release-loop/briefs/issue-7-body.md` returns 0, which proves the payload carries no metadata. `.release-loop/briefs/issue-7-command.md` carries the `gh issue comment 7` command and the non-authorization marker. `./scripts/validate.sh` exits 0.

## Mutation/failure-state matrix

No stateful ceremony in the deliverable; no mutation/failure-state matrix required.

The planner recorded this recognition check deliberately. A prior cycle learned that procedural skill text can authorize a durable transition even when the tracked diff is documentation-only. The units modify skill prose, a schema template, a shared reference, two shell scripts, and a tracker row. U6 also writes one local file. No unit pushes to a remote. No unit creates a remote repository. No unit publishes to a registry. No unit creates a platform release. No unit changes repository visibility. No unit posts to an issue tracker. W4 adds one runtime behavior, a facilitator dispatch. That dispatch consumes budget. It persists no state between invocations. Every fixture mutation happens inside a disposable `mktemp -d` tree, and the owning case removes that tree.

The heterogeneous review asked for a matrix, on the grounds that U6 serves an outward action. The planner declined. U6 produces two local files and a local ledger line. Under the reviewer's reading every plan in this repository would need a matrix, because every loop ends in a push. The matrix rule targets a unit that crosses the boundary itself. This plan has none.

No skill owns the issue-comment transition. `skills/shipping/SKILL.md` lists its outward steps as push, PR creation, thread operations, CI watch, and merge. An issue comment is not among them. The human therefore runs the prepared command at the Ship gate, and the ledger line from U6 step 9 is what surfaces it there. The plan states this rather than assigning the step to a skill that would not execute it (`enforces: P7`).

## Carry-forward trigger audit

Audited ROADMAP.md at 1e929bf: 3 open rows, 0 fired, 0 unobservable.

## Deferred to Follow-Up Work

- **The Conformance suite build.** U6 records the trigger as fired. The golden-fixture suite belongs to its own cycle. This deferral keeps the plan scoped to the five defects.
- **Issues #11 and #12.** They cover step 14 of `skills/planning/SKILL.md`. The user scoped them to a separate loop.
- **Annotation of the 18 historical retro documents.** They stay as a historical record. This matches the recommendation in issue #7 and the Out of Scope list of the spec.

## Open unknowns

**Planning-time** — none. Implementation resolves both spec Open Decisions without a scope change. U1 step 7 fixes the display string of the fifth level. U1 steps 8 through 10 propagate it. The confirming-channel note on the rounds-used line is free text. It touches no closed vocabulary.

**Implementation-time**

- The name and argument order of the checker function. U3 creates it. U4 and U5 extend it. The contract is fixed: a retro-document path enters, and an exit status plus one condition name leaves. The name follows the convention of the surrounding `assert_fail_naming` helpers.
- The body of each fixture retro document for C5 through C15. The Architecture notes fix the anchors that each condition detects, and each case's Test scenarios entry names the fields its fixture must carry. The remaining prose is free. The heterogeneous review asked for complete fixture bodies in the plan. The planner declined: the anchors plus the named fields meet the zero-context standard, and full bodies would seal reviewable test data inside an immutable document.
- The source of the anchor assertions in C5 through C15. The case may read `skills/retrospective/SKILL.md` from its `mktemp -d` copy or from the repository root. The copy gives better isolation. The implementer confirms during U3 step 5 whether `setup_copy` already places that file.
- **An operational risk, not a plan gap.** The `.release-loop/progress.md` file of this loop lives inside the feature worktree. `shipping` may remove that worktree before `retrospective` reads the file. The second open carry-forward row names this exposure. U6 writes its brief to the same worktree, so the brief carries the same risk. The loop must move live state to the base checkout before worktree removal. This entry records the risk so the Ship phase does not rediscover it.
