# Review: Planning discrimination and verdict coverage spec

- Reviewed artifact: `docs/specs/2026-08-15-planning-discrimination-and-verdict-coverage-design.md`
- Origin issues: #11 (discrimination check), #12 (verdict coverage)
- Gate: `designing` Step 10 independent review, run before the human approval gate
- Lanes: two, both read-only, dispatched in parallel
  - **Lane 1 — native reviewer subagent** (Claude, `reviewer` agent). Scope: invariant attack, reflexive-rejection soundness, internal consistency, Open Decision framing, missing edge cases. Full structured output committed verbatim beside this file as `2026-08-15-planning-discrimination-and-verdict-coverage-spec-review-r1-native.json`.
  - **Lane 2 — heterogeneous** (`codex exec -s read-only`, GPT-family). Scope: the empirical-grounding sub-step only — falsify every claim the spec makes about this repository by re-running its commands.
- **Status: closed.** Lane 1's two P0 findings and Lane 2's P1 were repaired in the spec before the human gate. Remaining items are recorded below with their disposition.
- Audience: a reader with no memory of the authoring conversation.

## Why this file exists

The ROADMAP carries an open row: *"Facilitator and reviewer output is never persisted, so review claims rest on ledger summaries rather than the reviewer's own words"* (2026-08-15 retro-interview-integrity retro, P3). Its trigger is a change to the interview protocol's round contract or to `reviewing`'s dispatch steps, so this cycle is not obliged to discharge it — this file discharges it voluntarily for this cycle, because the loop's own working copies live in gitignored `.release-loop/` and would be destroyed with the worktree (`docs/solutions/workflow-issues/loop-deliverable-in-disposable-state.md`).

Lane 1's output is committed in full. Lane 2's transcript is not: it is 1675 lines / 138 KB of session noise, MCP auth errors, and whole-file dumps, and `designing` Step 10 forbids committing unbounded raw command output as evidence. Its Findings section and verdict line are reproduced verbatim below instead.

## Lane 1 — native reviewer, verdict `incorrect` (2 P0, 5 P1, 4 P2)

| # | Severity | Finding | Disposition |
|---|---|---|---|
| 1 | P0 | R1's fixture was not bound to the step's actual comparands, so an author could demonstrate digest comparison on toy files while the step's real comparison of two different artifact kinds still could never return equal — the exact issue #11 defect passing every written clause | **Fixed.** R1 now requires a fixture pair *of the same artifact kinds as the step's real comparands, produced by the same command or pipeline*, and makes the different-kinds case an outright failure rather than declarative rationale |
| 2 | P0 | R2's enumeration source was a disjunction ("the emitting step's declared output set **or** the origin spec's own enumeration"), letting the author's own two-value declaration shadow the spec's three-value enumeration — the exact issue #12 defect passing every written clause | **Fixed.** R2 now requires the **union** of both sources, "never from the narrower of the two" |
| 3 | P1 | The trace recorded "expected results", which an author who never ran the fixture can write just as easily, contradicting Architecture's claim that the trace distinguishes a run check from an unrun one | **Fixed.** R1 records *observed* results; Architecture states why, citing issue #11's author whose expectation was wrong |
| 4 | P1 | SC2's rejection of the `.mlmodelc`/`.mlpackage` case followed only under a charitable referent for "the comparison" | **Fixed** by finding 1's wording repair; SC2 additionally states that a rejection needing a charitable reading is a fail |
| 5 | P1 | SC3's rejection was not forced by the words when the plan declares a narrow output set | **Fixed** by finding 2's repair; SC3's rubric now walks the hostile variant explicitly |
| 6 | P1 | The recommended schema-mirror option "only proves two files contain agreeing text", leaving plan bodies as unaudited as prose alone, so it does not close the false-green gap that justified it | **Recommendation reversed.** The spec now recommends prose only and defers the mirror behind a named trigger |
| 7 | P1 | The recommended option was covered by no Scope item and no success criterion | **Fixed** by the reversal; the spec states that adopting the mirror now would require its own Scope/In entries and red-before-green criteria |
| 8 | P2 | Scope/In declared bullet placement, but SC1 measured only counts and names, so any placement passed | **Fixed.** SC1 gained position assertions: bullet 4 must name `Verdict coverage`, the last bullet must name `Discrimination check` |
| 9 | P2 | The issue-closure criterion gated success on a human-owned outward action, re-creating the class ROADMAP row 61 already tracks | **Fixed.** Restated as human-discharged: the pipeline-side deliverable is a prepared payload plus the recorded posting command |
| 10 | P2 | Verdict coverage had no answer for a measurement that errors or comes back ambiguous | **Fixed.** R2 counts "the measurement failing to resolve" as a value; added as scenario S5 |
| 11 | P2 | Two consumption-shape escapes: a catch-all consumer satisfies "each value has a next step", and a verdict no unit consumes never triggers the check | **Fixed.** R2 requires a value-specific next step and closes the unconsumed-verdict escape |

Lane 1's summary, verbatim: *"the spec is close but not approvable as written."* Every finding above was applied before the human gate.

## Lane 2 — heterogeneous empirical grounding, verdict `0 P0, 1 P1, 1 P2`

The first run of this lane was piped through `tail -60`, which discarded its three P0 findings before they were read — a self-inflicted evidence loss recorded in the loop ledger. The lane was re-run against the revised spec with `tee`, and two of the three lost findings were independently re-derived by direct measurement (`CHANGELOG.md` has no unreleased heading; one assumption row cited a tool selector instead of a runnable command). Both were fixed.

Findings from the re-run, verbatim:

> 1. P1 — stale repository count
>    - Claim: "Retrofitting the two checks onto the 19 plans already in `docs/plans/`."
>    - Command: `find docs/plans -maxdepth 1 -type f -name '*.md' | wc -l`
>    - Actual output: `20`
>    - Verdict: FALSE. The repository contains 20 plan documents, not 19. This does not undermine the proposed behavior, but the grounding claim must be corrected.
>
> 2. P2 — current regression status is unverifiable under the review constraint
>    - Claim: "`bash scripts/validate.sh` and `bash scripts/test-retro-format-drift.sh` both pass at `86586a0` (verified fresh in this worktree at loop start)."
>    - Actual output: `NOT RUN — explicitly prohibited by the review instructions.`
>    - Verdict: UNVERIFIABLE. No inference was made from historical results.
>
> EMPIRICAL VERDICT: 0 P0, 1 P1, 1 P2.

Disposition:

- **P1 — fixed.** The count is now 20, with the command and observation time inline.
- **P2 — accepted as designed.** The lane was told not to run the two suites because the orchestrator runs them; the loop-start result (`ALL CHECKS PASSED`, exit 0, fresh in this worktree) is recorded in the loop ledger, and the post-change runs are Success Criteria 4 and 5. The lane correctly refused to infer from a historical result.

All other assumption rows replayed as MATCH, and every named artifact was confirmed to exist and to say what the spec claims — including `skills/planning/SKILL.md:131` assigning changelog entries to `shipping`, the two `CONCEPTS.md` terms, both cited solution documents, the ROADMAP row on human-discharged criteria, the ten-item hard floor, and that `scripts/validate.sh:567-662` never inspects bullets inside a step.

## What this review changed about the deliverable

The two shipped wordings are materially different from the wordings the issues proposed. Both issues' texts were dodgeable by a plan that satisfied every word while containing the defect the check exists to catch — which is the failure mode this cycle's own deliverable is about. The invariant attack, run before the approval gate rather than after the plan was sealed, is what surfaced that.
