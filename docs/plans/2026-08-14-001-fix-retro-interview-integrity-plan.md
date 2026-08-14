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

Repair five defects in the `retrospective` skill's interview protocol so the facilitator/respondent split cannot be skipped by wording, claimed falsely without a checkable warrant, or bypassed by a cheaper new rung. Ship the vocabulary change, the two prose gates, the mechanical carry-forward reconciliation, and the fixtures that keep all four honest.

## Architecture notes

**One-way vocabulary flow.** `schemas/retro-template.md` is the source of the closed independence-level list. `scripts/validate.sh` check 9 parses that list and asserts each value appears in both `skills/retrospective/SKILL.md` and `skills/retrospective/references/interview-probes.md`. This direction already exists; the change extends the count from 4 to 5 and replaces the positional probes rule with an all-levels rule.

**Why the vocabulary lands as one unit.** check 9 asserts an exact level count against the template. Bumping the count before the template gains its fifth value fails the check; adding the value before bumping the count fails it too. Template, both consumer files, and check 9 must move in a single commit or the tree is red in between. `CONCEPTS.md`'s `Independence level` definition enumerates the same vocabulary and joins that unit for the same reason.

**Ordering constraint.** U1 lands before U3, U4, and U5. Those three write prose naming `not-probed`, and check 9 asserts that every level in the template appears in both consumer files; writing the value into `skills/retrospective/SKILL.md` before the template declares it leaves the tree red. U2 and U6 touch neither the vocabulary nor the checker and may land in any position. U3 introduces the checker function that U4 and U5 extend, so it precedes both.

**Red before green.** Each unit writes its fixtures first and confirms them red against the pre-change tree, per the precedent in `docs/deviations/2026-07-21-check9-probes-level-scope-003.md` ("Committed red before the check extension lands"). For the prose-backed cases this works because each case also asserts the shipped clause it mirrors, and that clause does not exist yet.

**Checker, not linter.** The Phase 8 and warrant rules are executed at runtime by an agent reading skill prose. The shell checker added here is a second implementation used only against disposable fixtures; it never reads `docs/retros/`. Its value is proving the rules discriminate and that the shipped prose still carries them. This is why every discrimination case carries a coupling assertion against `skills/retrospective/SKILL.md` — without it the checker would prove only itself.

**Known Pattern — disposable fixture trees.** `scripts/test-retro-format-drift.sh` already builds a `mktemp -d` copy per case, mutates it, runs `scripts/validate.sh` inside it, and asserts a named `FAIL:` string. Every new case follows that shape; no case mutates the real worktree.

**Shared-file caution.** `references/dispatch-degradation.md` is read by 12 skill and reference files. The tier-3 parenthetical is reworded rather than deleted, because deleting it would remove the only budget-based tier-3 sanction repo-wide and change `compound`'s headless single-call collapse, which `retrospective` Phase 7 depends on.

## Assumption Recheck

Origin spec `docs/specs/2026-08-14-retro-interview-integrity-design.md` retains nine live assumptions. Every retained command was rerun at planning time on the working tree at `1e929bf`.

| # | Approved claim | Fresh evidence | Outcome |
|---|---|---|---|
| 1 | All four current levels appear in `interview-probes.md` | `rg -c -e heterogeneous -e "same-model fresh-context" -e in-thread -e self-checklist skills/retrospective/references/interview-probes.md` → `4` | match |
| 2 | check 9 hardcodes count 4 and selects the probes rung as `levels[-1]` | `rg -n -e "len\(set\(levels\)\) != 4" -e "degraded = levels\[-1\]" scripts/validate.sh` → lines 333, 373 | match |
| 3 | `dispatch-degradation.md` carries the headless conflation | `rg -n -e "no subagent capability at all" references/dispatch-degradation.md` → line 22, text unchanged | match |
| 4 | 18 retro docs record `Rounds used: 0` | `rg -c "Rounds used: 0" docs/retros/` → 18 files | match |
| 5 | The independent-facilitator path was exercised 7 times | `rg -n -e "Independence level: heterogeneous" -e "Independence level: same-model" -e "Independence level: in-thread" docs/retros/` → 7 lines | match |
| 6 | Fixture convention is disposable `mktemp -d` trees | `rg -c "mktemp -d" scripts/test-retro-format-drift.sh` → `2` | match |
| 7 | Case H asserts the 4-level guard string and breaks at 5 | `rg -n "expected 4 distinct" scripts/test-retro-format-drift.sh` → lines 253, 272 | match |
| 8 | `dispatch-degradation.md` has 12 skill and reference consumers | `rg -ln "dispatch-degradation" skills/ references/ schemas/` → 12 files | match |
| 9 | Exactly one retro doc lacks a registration table | `rg -L --files-without-match "Carry-forward items registered" docs/retros/` → `docs/retros/2026-08-05-add-license-retro.md` | match |

No contradictions and no unavailable evidence. Plan finalization is not blocked; no deviation addendum is required.

## File structure

**Vocabulary sources and consumers** (must move together)
- Modify `schemas/retro-template.md` — independence-level line gains the fifth value; carry-forward section gains a count bullet.
- Modify `skills/retrospective/SKILL.md` — level vocabulary, ladder rung 4, Phase 8 clause, W1–W4 warrant, Phase 4 reconciliation steps.
- Modify `skills/retrospective/references/interview-probes.md` — opening paragraph, verdict-forms table.
- Modify `CONCEPTS.md` — the `Independence level` definition's enumerated vocabulary.
- Modify `scripts/validate.sh` — check 9 level count and probes rule.

**Shared dispatch ladder**
- Modify `references/dispatch-degradation.md` — tier-3 parenthetical reword.

**Verification**
- Modify `scripts/test-retro-format-drift.sh` — case A–J audit, cases C1–C15, and the fixture checker.

**Tracker**
- Modify `ROADMAP.md` — record the Conformance-suite trigger as fired.

## Scenario coverage map

| S-ID | Unit chain | Scenario evidence |
|---|---|---|
| S1 | U2 | `happy` in U2: `rg -n "headless/single-agent" skills/ references/` returns no matches after the change and returns the rung-4 sentence before it (`Covers S1`). The SC6 rubric remains the spec's declared evidence; this command is the machine-checkable half of it |
| S2 | U2 → U3 | `integration` in U3: C6 accepts a both-channels claim, C7 rejects a single-channel claim (`Covers S2`) |
| S3 | U1 → U4 | `integration` in U4: C8 accepts the dispatch path, C13 accepts the no-channel path (`Covers S3`) |
| S4 | U5 | `integration` in U5: C11 rejects a substituted row that a matching count conceals (`Covers S4`) |
| S5 | U3 | `integration` in U3: C5 rejects a `mode:headless` justification (`Covers S5`) |
| S6 | U1 → U4 | `integration` in U4: C9 rejects an unmet criterion under `not-probed` (`Covers S6`) |

Every S-ID completes through a unit chain and is walked by named evidence. S1 is the one row whose evidence is a rubric rather than a test; the spec declares SC6 as a judgment rubric for the same reason.

## Implementation Units

## U1: Fifth independence level across the vocabulary chain
Execution note: test-first
Files:
  Modify: schemas/retro-template.md, skills/retrospective/SKILL.md, skills/retrospective/references/interview-probes.md, CONCEPTS.md, scripts/validate.sh
  Test: scripts/test-retro-format-drift.sh
Interfaces:
  Consumes: the `- Independence level:` line of `schemas/retro-template.md`, pipe-separated; the `Verdict cell values:` line of the same file
  Produces: a five-value closed level list whose fifth value is `not-probed (no narrative warranted)`; check 9 asserting `len(set(levels)) == 5` and asserting every parsed level appears in both `skills/retrospective/SKILL.md` and `skills/retrospective/references/interview-probes.md`
Test scenarios:
  happy: C4 — an unmutated tree passes check 9 with five levels
  edge: C3 — removing `in-thread (approximated independence)` from `interview-probes.md` fails check 9, proving the rule is position-independent rather than list-final
  error: C1 removes `not-probed (no narrative warranted)` from `skills/retrospective/SKILL.md` and C2 removes it from `interview-probes.md`; each fails check 9 with a `FAIL:` line naming the missing level and the file
  integration: n/a — leaf unit; the scenario-walking cases live in U3, U4, and U5
Steps:
  1. Read `scripts/test-retro-format-drift.sh` case H at lines 239-256. Its mutation removes `| self-checklist` from the template copy and it asserts the string `expected 4 distinct independence levels`. Audit cases A through J for any other assertion coupled to the level count; case I at line 272 asserts `expected 4 distinct backticked verdict forms`, which this unit does not change, and cases B and G do not assert a count.
  2. Rewrite case H's assertion string to `expected 5 distinct independence levels` and leave its mutation unchanged, so removing one value from a five-value line still trips the count guard.
  3. Add cases C1, C2, C3, C4 to `scripts/test-retro-format-drift.sh` following the existing `setup_copy` / mutate / `bash scripts/validate.sh` / `assert_fail_naming` shape used by case G at lines 220-237.
  4. Run `./scripts/test-retro-format-drift.sh`; confirm C1, C2, C3 fail and case H fails, because the template still carries four levels and check 9 still asserts four. Record the observed failure lines.
  5. Add `not-probed (no narrative warranted)` as the fifth entry on the `- Independence level:` line of `schemas/retro-template.md`, appended last.
  6. Add the same value to `skills/retrospective/SKILL.md`'s independence-level recording paragraph, and to the `Independence level` definition in `CONCEPTS.md`.
  7. Add a `not-probed (no narrative warranted)` row to the verdict-forms table in `skills/retrospective/references/interview-probes.md`. Its verdict forms are `accepted` on the reachable-channel path and no verdict cells at all on the no-channel path. State that `self-attested` is never a `not-probed` verdict.
  8. In `scripts/validate.sh`, change the level-count assertion at line 333 from `!= 4` to `!= 5` and update its message string to `expected 5 distinct independence levels`.
  9. In `scripts/validate.sh`, replace the block at lines 371-375 that selects `degraded = levels[-1]` with a loop asserting every value in `levels` appears in `probes_text` via the existing `boundary_search` helper, failing with a message naming both the probes file and the missing level.
  10. Run `./scripts/test-retro-format-drift.sh`; confirm every case A through J and C1 through C4 passes.
  11. Run `./scripts/validate.sh`; confirm exit 0 and the `retro interview format: template and skill prose agree` ok line.
  12. Commit: "fix(retro): Add the not-probed independence level and generalize check 9"
Acceptance: `./scripts/validate.sh` exits 0; `./scripts/test-retro-format-drift.sh` exits 0 with cases A–J and C1–C4 all passing; `rg -c -e heterogeneous -e "same-model fresh-context" -e in-thread -e self-checklist -e "not-probed" skills/retrospective/references/interview-probes.md` returns 5.

## U2: Name dispatch rung 4 by capability only
Execution note: skip-test-first
Files:
  Modify: skills/retrospective/SKILL.md, skills/retrospective/references/interview-probes.md, references/dispatch-degradation.md
Interfaces:
  Consumes: the degradation ladder sentence in `skills/retrospective/SKILL.md`'s Facilitator model selection paragraph; the opening paragraph of `skills/retrospective/references/interview-probes.md`; the tier-3 heading sentence at `references/dispatch-degradation.md` line 22
  Produces: a rung-4 description naming only the absence of a facilitator channel, plus an explicit statement that `mode:headless` does not qualify for any rung
Test scenarios:
  happy: `rg -n "headless/single-agent" skills/ references/` returns no matches after the change, and returned the rung-4 sentence before it. Covers S1
  edge: `rg -n "strict dispatch budget" references/dispatch-degradation.md` returns line 22, proving the tier-3 budget sanction survived the reword rather than being deleted with the headless conflation
  error: n/a — the unit rewrites three prose sentences and has no failure path of its own; a mistyped edit surfaces as the happy or edge command not matching
  integration: n/a — leaf unit; the Phase 8 cases that depend on this wording live in U3
Steps:
  1. In `skills/retrospective/SKILL.md`, locate the ladder sentence ending `→ headless/single-agent: skip the interview and run the probe list as a fixed self-checklist`. Replace the fourth rung with a capability-only description: no subagent primitive and no external facilitator CLI reachable.
  2. In the same paragraph, add one sentence stating that `mode:headless` is not a qualifying condition for any rung of the ladder, because it governs user interaction rather than worker dispatch.
  3. In `skills/retrospective/references/interview-probes.md`, rewrite the opening paragraph's sentence beginning `In headless/single-agent mode this file runs as a fixed self-checklist` so it names the absent capability instead of the headless flag.
  4. In `references/dispatch-degradation.md` line 22, replace the parenthetical `(or the run is headless with a strict budget)` with `(or a strict dispatch budget applies)`. Do not delete the parenthetical — it is the only budget-based tier-3 sanction in the file.
  5. Verify the reword against every consumer: run `rg -ln "dispatch-degradation" skills/ references/ schemas/` and read each of the 12 files' citing sentence, confirming none depends on the word "headless" appearing in the tier-3 description. Record the result.
  6. Run `./scripts/validate.sh`; confirm exit 0.
  7. Commit: "fix(retro): Name the dispatch ladder's floor rung by capability, not by flag"
Acceptance: `./scripts/validate.sh` exits 0; `rg -n "headless/single-agent" skills/ references/` returns no matches; `rg -n "strict dispatch budget" references/dispatch-degradation.md` returns line 22.

## U3: Phase 8 requires a named absent capability
Execution note: test-first
Files:
  Modify: skills/retrospective/SKILL.md
  Test: scripts/test-retro-format-drift.sh
Interfaces:
  Consumes: the Phase 8 pre-commit sentence in `skills/retrospective/SKILL.md` requiring a valid independence level and a rounds-used count
  Produces: a fixture checker function taking a retro-document path, exiting 0 on accept and nonzero on reject, printing one line naming the violated condition as `phase8-capability` or `phase8-headless`
Test scenarios:
  happy: C6 — `self-checklist` with a rounds-used line naming both facilitator channels is accepted
  edge: C7 — `self-checklist` naming only `no subagent primitive in this harness` is rejected with `phase8-capability`, because it covers one ladder channel and the ladder names two
  error: C5 — `self-checklist` justified by `headless mode` is rejected with `phase8-headless`
  integration: C5, C6, C7 also assert that `skills/retrospective/SKILL.md` Phase 8 carries the named-absent-capability requirement, the `mode:headless` non-qualifying statement, and the both-channels shape. Covers S2, Covers S5
Steps:
  1. Add a checker function to `scripts/test-retro-format-drift.sh` that reads a fixture retro document path, extracts the `- Independence level:` and `- Rounds used:` lines, and returns nonzero with `phase8-headless` when a degraded level's rounds-used line cites headless mode, or nonzero with `phase8-capability` when a degraded level's line names fewer than both facilitator channels.
  2. Add cases C5, C6, C7. Each builds its fixture retro document inside the case's own `mktemp -d` tree, calls the checker, and asserts both the exit status and the printed condition name.
  3. In each of C5, C6, C7, add an assertion that the case's `mktemp -d` copy of `skills/retrospective/SKILL.md` contains the Phase 8 clause text this unit is about to write.
  4. Run `./scripts/test-retro-format-drift.sh`; confirm C5, C6, C7 fail on the coupling assertion, because Phase 8 does not yet carry the clause. Record the observed failure lines.
  5. In `skills/retrospective/SKILL.md` Phase 8, extend the pre-commit check: a degraded independence level must name the specific capability that was absent. Scope the requirement to `in-thread (approximated independence)` and `self-checklist`.
  6. In the same paragraph, state that `mode:headless` is not an absent capability, and that a `self-checklist` claim must cover both facilitator channels the ladder names — no subagent primitive and no external facilitator CLI reachable — because rung 1 names an external CLI facilitator independent of the subagent primitive.
  7. State that `in-thread` names why fresh context was unavailable.
  8. Run `./scripts/test-retro-format-drift.sh`; confirm C5, C6, C7 pass and no earlier case regressed.
  9. Run `./scripts/validate.sh`; confirm exit 0.
  10. Commit: "fix(retro): Require a named absent capability for degraded independence levels"
Acceptance: `./scripts/test-retro-format-drift.sh` exits 0 with C5 rejecting `phase8-headless`, C7 rejecting `phase8-capability`, and C6 accepting; `./scripts/validate.sh` exits 0.

## U4: The not-probed warrant W1 through W4
Execution note: test-first
Files:
  Modify: skills/retrospective/SKILL.md
  Test: scripts/test-retro-format-drift.sh
Interfaces:
  Consumes: the checker function produced by U3
  Produces: the same checker extended with conditions `W1`, `W2`, `W3`, `W4`; a `not-probed` warrant section in `skills/retrospective/SKILL.md`
Test scenarios:
  happy: C8 — `not-probed` with one confirmation row whose verdict is `accepted`, all criteria Met, reconciling counts, and no finding outside What Worked Well is accepted
  edge: C13 — `not-probed` with a zero-row table and a both-channels absent-capability claim is accepted on the no-channel path
  error: C9 rejects with `W1` on a Not Met criterion; C10 rejects with `W2` on registered 4 against accounted 3; C15 rejects with `W3` on a finding filed under Process Observations; C12 rejects with `W4` on a zero-row table carrying no absent-capability claim; C14 rejects with `W4` on a confirmation row whose verdict is `self-attested`
  integration: C8, C9, C10, C12, C13, C14, C15 also assert that `skills/retrospective/SKILL.md` carries W1 through W4 including W2's exclusion of the degraded fallback and W4's two paths. Covers S3, Covers S6
Steps:
  1. Extend the checker in `scripts/test-retro-format-drift.sh` with four conditions. `W1` fails when a Phase 3 verdict cell reads Partially Met or Not Met and the document does not state that no spec exists. `W2` fails when the carry-forward count bullet's two numbers differ, or when the reconciliation is the degraded no-table fallback. `W3` fails when the Findings section carries any entry outside What Worked Well. `W4` fails when the transcript has zero rows and the rounds-used line carries no both-channels absent-capability claim, or when a confirmation row's verdict is `self-attested`.
  2. Add cases C8, C9, C10, C12, C13, C14, C15, each building its fixture retro document in its own `mktemp -d` tree and asserting exit status plus condition name.
  3. In each case, add an assertion that the case's copy of `skills/retrospective/SKILL.md` contains the W1–W4 warrant text this unit is about to write.
  4. Run `./scripts/test-retro-format-drift.sh`; confirm all seven new cases fail on the coupling assertion. Record the observed failure lines.
  5. In `skills/retrospective/SKILL.md`, add the `not-probed` warrant next to the independence-level paragraph. Write W1: no Phase 3 criterion is Partially Met or Not Met, or the doc states no spec exists.
  6. Write W2: Phase 4's reconciliation records registered N equal to accounted-for M with no unregistered rows, and state that the degraded no-table fallback never satisfies W2, so `registered 0, accounted for 0` from a missing table does not authorize `not-probed`.
  7. Write W3: the Findings section contains no entries outside What Worked Well.
  8. Write W4: when any facilitator channel is reachable, the not-to-probe judgment is confirmed by one facilitator dispatch recorded as a transcript row with verdict `accepted`; `self-attested` is never a valid `not-probed` verdict. Without a reachable channel, `not-probed` carries the same absent-capability claim `self-checklist` carries.
  9. Add one sentence stating the residual limit: W1–W4 raise the cost of a false claim without eliminating it, consistent with the protocol's existing Known limit.
  10. Migrate Phase 8's sentence `A zero-row table under a valid header is valid — nothing warranted probing` so it applies to `not-probed` rather than to any level.
  11. Run `./scripts/test-retro-format-drift.sh`; confirm all seven cases pass and no earlier case regressed.
  12. Run `./scripts/validate.sh`; confirm exit 0.
  13. Commit: "fix(retro): Gate not-probed behind a four-condition warrant"
Acceptance: `./scripts/test-retro-format-drift.sh` exits 0 with C8 and C13 accepting and C9, C10, C12, C14, C15 each rejecting under its own condition name; `./scripts/validate.sh` exits 0.

## U5: Mechanical carry-forward reconciliation
Execution note: test-first
Files:
  Modify: skills/retrospective/SKILL.md, schemas/retro-template.md
  Test: scripts/test-retro-format-drift.sh
Interfaces:
  Consumes: the `## Carry-forward from previous retro` section of `schemas/retro-template.md`; the checker function produced by U3
  Produces: a bullet line under that heading recording registered N and accounted-for M; the checker extended with condition `phase4-unregistered`
Test scenarios:
  happy: a fixture whose current table reproduces all four registered names is accepted
  edge: a fixture whose previous document has no registration table is rejected under `W2` as the degraded fallback, matching U4's rule
  error: C11 — the previous document registers four items, the current table has four rows, and one registered name was replaced by an unregistered one; the checker rejects with `phase4-unregistered`
  integration: C11 also asserts that `skills/retrospective/SKILL.md` Phase 4 carries the row-by-row name reconciliation, the recorded counts, and the unregistered-row rule. Covers S4
Steps:
  1. Extend the checker in `scripts/test-retro-format-drift.sh` with condition `phase4-unregistered`, taking a second fixture path for the previous retro document, comparing item names between the previous document's `Carry-forward items registered` table and the current document's `Carry-forward from previous retro` table, and failing when a current row names an item the previous document did not register.
  2. Add case C11 building both fixture documents in one `mktemp -d` tree, and assert exit status plus the condition name.
  3. Add to C11 an assertion that the case's copy of `skills/retrospective/SKILL.md` contains the Phase 4 reconciliation text this unit is about to write.
  4. Run `./scripts/test-retro-format-drift.sh`; confirm C11 fails on the coupling assertion. Record the observed failure line.
  5. In `schemas/retro-template.md`, add a bullet line under the `## Carry-forward from previous retro` heading recording registered N and accounted-for M. Use a bullet, never a table row: `scripts/validate.sh` line 543 collects every three-column pipe row inside that section and would count a table-row form as a carry-forward item across all 36 existing retro documents.
  6. In `skills/retrospective/SKILL.md` Phase 4, add four mechanical steps. Step one reads the previous retro's `Carry-forward items registered` table rather than its narrative, with the fallback that a previous document lacking the table yields registered N = 0 recorded as a degraded reconciliation.
  7. Write step two: reconcile row by row, by name. Write step three: record both counts in the template's bullet field. Write step four: a current row the previous document did not register is itself a defect, because it inflates M and can conceal a drop.
  8. Run `./scripts/test-retro-format-drift.sh`; confirm C11 passes and no earlier case regressed.
  9. Run `./scripts/validate.sh`; confirm exit 0 and that `[cf-tid] carry-forward T-ID integrity` still reports at least 26 retro docs checked.
  10. Commit: "fix(retro): Reconcile carry-forward items by name with recorded counts"
Acceptance: `./scripts/test-retro-format-drift.sh` exits 0 with C11 rejecting `phase4-unregistered`; `./scripts/validate.sh` exits 0 with the `[cf-tid]` line reporting at least 26 docs.

## U6: Record the fired Conformance-suite trigger
Execution note: skip-test-first
Files:
  Modify: ROADMAP.md
Interfaces:
  Consumes: the `Conformance suite` row of `ROADMAP.md`'s Future candidates table, whose trigger reads `First contract regression that structural validation (scripts/validate.sh) fails to catch`
  Produces: the same row annotated as fired, naming this cycle as the evidence
Test scenarios:
  happy: `rg -n "Conformance suite.*fired" ROADMAP.md` returns the row after the edit
  edge: n/a — a single table-row edit with no branching behavior
  error: n/a — a single table-row edit with no failure path
  integration: n/a — leaf unit; the tracker row has no runtime consumer
Steps:
  1. Confirm the pre-change state: run `rg -n "Conformance suite.*fired" ROADMAP.md` and observe exit 1, which is what makes this criterion discriminating. A bare `fired` search would match the Schema-validators row at line 13 and prove nothing.
  2. Edit the `Conformance suite` row's trigger cell to mark it fired, naming the evidence: structural validation passed 18 retro documents whose independence level was not warranted by the dispatch ladder, which is the contract regression the trigger names.
  3. State in the same cell that building the suite remains deferred to its own cycle, so the row stays open rather than reading as delivered.
  4. Run `rg -n "Conformance suite.*fired" ROADMAP.md`; confirm it now returns the row.
  5. Run `./scripts/validate.sh`; confirm exit 0.
  6. Commit: "docs(roadmap): Record the fired Conformance-suite trigger"
Acceptance: `rg -n "Conformance suite.*fired" ROADMAP.md` returns exactly one line naming this cycle; `./scripts/validate.sh` exits 0.

## Mutation/failure-state matrix

No stateful ceremony in the deliverable; no mutation/failure-state matrix required.

Recognition check, recorded because a prior cycle learned that procedural skill text can authorize durable transitions even when the tracked diff is documentation-only: the units modify skill prose, a schema template, a shared reference, two shell scripts, and a tracker row. No unit pushes to a remote, creates a remote repository, publishes to a registry, creates a platform release, or changes repository visibility. The runtime behavior W4 adds is a facilitator dispatch, which consumes budget but persists no state across invocations. Every fixture mutation happens inside a disposable `mktemp -d` tree that its case removes.

## Carry-forward trigger audit

Audited ROADMAP.md at 1e929bf: 3 open rows, 0 fired, 0 unobservable.

| Tracker row | Trigger class | Examined against | Result |
|---|---|---|---|
| A success criterion that fires after Retro cannot be measured inside that Retro's Phase 3 pass | event-based | This plan's success criteria, via the origin spec's Success Criteria section | Not fired — SC7's Ship-phase issue comment resolves before Retro, so no criterion is post-Retro terminal |
| Shipping can delete the isolated worktree that owns live release-loop state before Retro consumes that state | edit-based | This plan's File structure | Not fired — no unit modifies `skills/shipping/SKILL.md` or `skills/release-loop/SKILL.md`. The operational exposure is live for this loop and is recorded under Open unknowns rather than given an invented plan disposition |
| Forced-failure matrices can omit the exact partial durable state and persist invalid shell syntax in Markdown tables | edit-based | This plan's File structure | Not fired — no unit modifies the planning contract, and this plan carries the stateless fallback rather than a matrix |

## Deferred to Follow-Up Work

- **Building the Conformance suite.** U6 records the trigger as fired; the golden-fixture end-to-end suite is its own cycle. Deferring keeps this plan's scope at the five defects.
- **Posting the issue #7 correction.** The comment crossing to GitHub is an outward action owned by the human at the Ship gate (`enforces: P7`), not by any unit here.
- **Issues #11 and #12** — `skills/planning/SKILL.md` step 14's discrimination and verdict-coverage checks. Separate loop by the user's scoping decision.
- **Annotating the 18 historical zero-round retro documents.** Left as historical record, matching issue #7's own recommendation and the spec's Out of Scope list.

## Open unknowns

**Planning-time** — none. Both spec Open Decisions are resolvable inside implementation without changing scope: the display string for the fifth level is fixed by U1 step 5 and propagated by U1 steps 6 and 7, and whether the rounds-used line notes the confirming channel is a free-text suffix that touches no closed vocabulary.

**Implementation-time**
- The exact shell function name and argument order of the fixture checker introduced in U3 and extended in U4 and U5. The contract is fixed — a retro-document path in, exit 0 or nonzero plus one condition name out — but the name follows whatever convention the surrounding `assert_fail_naming` helpers use.
- Whether the C5–C15 coupling assertions read `skills/retrospective/SKILL.md` from the case's `mktemp -d` copy or from the repository root. The copy is preferred for isolation; the deciding factor is whether `setup_copy` already places the file, which the implementer confirms while writing U3 step 3.
- The precise wording of the fifth level's row in the `interview-probes.md` verdict-forms table, beyond the two verdict-form paths U1 step 7 fixes.
- **Operational, not a plan gap**: this loop's `.release-loop/progress.md` lives inside the feature worktree, which `shipping` may remove before `retrospective` reads it — the exposure named by the second carry-forward row above. The loop must transfer live state to the base checkout before worktree removal. Recorded here so the Ship phase does not rediscover it.
