---
schema: plan/v1
title: Planning Discrimination and Verdict Coverage
type: fix
status: draft
date: 2026-08-15
execution: non-code
origin: docs/specs/2026-08-15-planning-discrimination-and-verdict-coverage-design.md
---

# Planning Discrimination and Verdict Coverage — Implementation Plan

## Goal

Land the two step 14 self-review checks the approved spec specifies — Verdict coverage as the fourth check of `skills/planning/SKILL.md` step 14 and Discrimination check as the last — and prepare the human-posted closing payloads for issues #11 and #12.

## Architecture notes

- **One behavior file, two units, fixed order.** Both bullets edit the same section of `skills/planning/SKILL.md`. They are separate units because a reviewer can reject one wording and accept the other. U2 depends on U1: each unit's acceptance asserts an absolute bullet count, so the counts encode the order 11 then 12.
- **Insertion, never renumbering.** Step 14's checks are an unnumbered bullet list, so neither insertion renumbers anything. `scripts/validate.sh` check 13 (`[plan-refs]`) parses `^## <n>.` step headings, `skills/planning/references/deepening.md` sections, and `schemas/plan-schema.md` hard-floor numbers; it never reads bullets inside a step (rechecked below).
- **Positions carry meaning, and nothing outside this cycle depends on them.** Verdict coverage lands immediately after Scenario coverage because the spec declares it the dual of Spec coverage, so the three coverage checks read as one family. Discrimination check lands last, after Command closure, because both probe one step's substance rather than a document-wide map. Every ordinal reference to a step 14 bullet in this repository sits inside this cycle's own three documents — this plan, its origin spec, and the spec review — verified by grep at `2026-08-14T20:22:00Z`; references anywhere else name bullets by title, so insertion breaks no cross-reference.
- **The shipped wording is the deliverable.** Seven clauses in these bullets exist only because two independent invariant attacks constructed plan steps that satisfied the wording of the moment while still carrying the defect. Five came from the Design-gate attack; the sixth and seventh come from the plan-gate attack and are carried by `docs/deviations/2026-08-15-discrimination-axis-and-out-of-set-verdict-012.md`, because the approved spec's Interface section fixes the pre-amendment text and stays unchanged as the record of the original decision. A unit that "simplifies" any of those clauses reopens a closed loophole.
- **Issue payloads go to a committed path, not loop state.** U3 writes `docs/issue-closures/`, a new directory. These payloads are consumed by a human at the Ship gate — after merge — so they outlive the loop, and `docs/solutions/workflow-issues/loop-deliverable-in-disposable-state.md` records the cost of leaving that class in gitignored `.release-loop/`. `docs/reviews/` is reserved for review records, so a sibling directory is the smaller change.
- **Acceptance commands assert rather than report.** Every acceptance check exits nonzero when the implementation is wrong: counts are compared with `test`, and name checks pipe into `grep -q`. A command whose exit status is 0 on both a right and a wrong implementation measures nothing, which is the same defect class this cycle's deliverable exists to catch.
- **No mechanical check ships.** The user chose prose only at the Design gate. The plan-schema mirror plus a `validate.sh` agreement check stay deferred behind the trigger the spec records.
- **Author-executed implementation.** No unit is dispatched to a subagent, so ROADMAP's unsigned-commit row has no occasion to fire this cycle.

## Assumption Recheck

All seven retained commands from the origin spec rerun fresh at `2026-08-14T20:06:11Z` against working tree `68ffafe`:

| Approved claim | Fresh evidence | Outcome |
|---|---|---|
| Step 14 carries exactly ten checks; none mentions discrimination or verdicts | Bullet count `10`; name search `0` | match |
| `schemas/plan-schema.md` hard floor has ten items | `10` | match |
| No check asserts plan-document body sections | `grep -c 'plans_dir\|docs.*plans' scripts/validate.sh` → `7` mentions, still only the frontmatter loop and the body-seal reader | match |
| Step 14's checks are mirrored in no other file | `grep -rln 'Command closure' --include='*.md' --include='*.sh' . \| grep -v '^./docs/'` now returns `./.release-loop/progress.md` **and** `./skills/planning/SKILL.md` | match, with a recorded qualification: the new hit is this loop's own gitignored ledger, which quoted the bullet name in a Log line. No consumer contract file mirrors step 14, which is the substance of the approved claim. Future runs should exclude `.release-loop/` |
| `[plan-refs]` never inspects bullets inside a step | `sed -n '567,662p' scripts/validate.sh` → parses step headings, deepening sections, hard-floor numbers only | match |
| `CHANGELOG.md` has no unreleased heading | `grep -nic 'unreleased' CHANGELOG.md` → `0` | match |
| Plugin cache and repo both declare 0.10.0 with differing `release-loop` text | `diff -q` → `DIVERGENT` | match |

No contradiction, so no deviation addendum is required for the assumptions. Addendum 012 exists for a different reason: a review-introduced wording amendment to an approved artifact. No unavailable evidence.

## File structure

| File | Change | Owner unit |
|---|---|---|
| `skills/planning/SKILL.md` | Insert the Verdict coverage bullet after the Scenario coverage bullet | U1 |
| `skills/planning/SKILL.md` | Append the Discrimination check bullet after the Command closure bullet | U2 |
| `docs/issue-closures/2026-08-15-issue-11.md` | Create: prepared closing comment for issue #11 | U3 |
| `docs/issue-closures/2026-08-15-issue-12.md` | Create: prepared closing comment for issue #12 | U3 |
| `docs/plans/2026-08-15-001-fix-planning-discrimination-and-verdict-coverage-plan.md` | This plan | — |

## Scenario coverage map

| S-ID | Unit chain | Observable verification |
|---|---|---|
| S1 (digest comparison that cannot discriminate) | U2 | A reader applies U2's shipped bullet to issue #11's step: the comparands are a `.mlmodelc` and an `.mlpackage`, so the different-kinds clause refuses it outright. The same reader applies it to the sixth-loophole construction (same-kind digests varied along an axis the option does not touch) and the axis-binding clause refuses that too. Recorded as the SC2 reject cases |
| S2 (branching on two of three verdicts) | U1 | A reader applies U1's shipped bullet to issue #12's plan shape with the measuring step declaring only two output values: the union clause pulls the spec's third hypothesis in, and "a value with no branch is a plan gap" refuses it. Recorded as the SC3 reject case |
| S3 (no comparison, no verdict) | U1 → U2 | Both bullets open with their trigger shape, so a plan with neither shape satisfies both vacuously. A reader confirms neither bullet imposes an unconditional obligation |
| S4 (reviewer audits whether the checks can fail) | U1 → U2 | Phase 4's review lane walks the five cases in Verification summary and records reject/accept with the deciding clause quoted; the review record is the durable artifact |
| S5 (diagnostic resolves to nothing, or to something unenumerated) | U1 | After U1, `sed -n '/^## 14\. Self-review/,/^## 15\./p' skills/planning/SKILL.md \| grep -c 'outside that set'` returns `1`, and a reader confirms the clause makes both the unresolved outcome and an out-of-set value require their own next step |

## Implementation Units

## U1: Insert the Verdict coverage check as step 14's fourth bullet

Files:
  Create/Modify: skills/planning/SKILL.md
Steps:
  1. In `## 14. Self-review`, immediately after the bullet that begins `- **Scenario coverage**` (it ends with the sentence about every map row naming real scenario evidence and its `enforces: P8` tag), insert exactly this bullet, wrapped to match the surrounding lines:
     - **Verdict coverage** — for every unit that emits a verdict, decision, or classification, enumerate the possible values from the union of the emitting step's declared output set and the origin spec's own enumeration — never from recall, and never from the narrower of the two — and include the measurement failing to resolve, or resolving to a value outside that set, among the values. Confirm each value has its own next step; a single catch-all consumer that acts on "whatever the verdict says" covers nothing. A value with no branch is a plan gap, not an implementation-time unknown. A value deliberately out of scope goes to Deferred to Follow-Up Work with its reason, and a verdict no unit consumes is itself either a gap or a deliberate Deferred entry.
  2. Confirm no other line changed: `git diff skills/planning/SKILL.md` shows only the inserted region.
  3. Self-review against the origin spec's Interface section plus addendum 012: the bullet carries the union clause, the out-of-set clause, the unresolved-value clause, the value-specific-next-step clause, the catch-all rejection, the Deferred clause, and the unconsumed-verdict clause. A missing clause reopens a loophole recorded in `docs/reviews/`.
  4. Commit: "fix(planning): Add the verdict coverage self-review check"
Acceptance: run these five commands in order; every one must exit 0.
  `R='/^## 14\. Self-review/,/^## 15\./'`
  `test "$(sed -n "$R p" skills/planning/SKILL.md | grep -c '^- \*\*')" = 11`
  `sed -n "$R p" skills/planning/SKILL.md | grep '^- \*\*' | sed -n '4p' | grep -q 'Verdict coverage'`
  `test "$(sed -n "$R p" skills/planning/SKILL.md | grep -c 'outside that set')" = 1`
  `bash scripts/validate.sh | tail -1 | grep -q 'ALL CHECKS PASSED'`

## U2: Append the Discrimination check as step 14's last bullet

Files:
  Create/Modify: skills/planning/SKILL.md
Depends on: U1, landed. This unit's acceptance asserts a bullet count of 12, which holds only after U1's insertion.
Steps:
  1. In `## 14. Self-review`, immediately after the bullet that begins `- **Command closure**` (currently the last bullet, ending with the sentence about a step referencing `$VAR` without a prior assignment), insert exactly this bullet, wrapped to match the surrounding lines:
     - **Discrimination check** — for every step that compares two things or asserts a guard, run the step's own comparison on a fixture pair of the same artifact kinds as the step's real comparands, produced by the same command or pipeline that produces them, and record in the step the pair plus the two results you observed. Two runs of the same inputs must compare equal; one changed input must compare different, and the changed input is the very input or option whose effect the step exists to detect, never an arbitrary one. A step whose comparands are different artifact kinds fails this check outright: they always differ, so the comparison cannot report anything about the change. A guard that cannot fail is not a guard.
  2. Confirm the bullet is last in the section and that the paragraph following the list (`Fix issues inline; no separate review pass is needed.`) is untouched.
  3. Self-review against the origin spec's Interface section plus addendum 012: the bullet binds the fixture to the step's own comparand kinds and producing pipeline, binds the changed input to the axis under test, requires observed results, and makes the different-kinds case an outright failure. Softening any of those four reopens a loophole.
  4. Commit: "fix(planning): Add the discrimination self-review check"
Acceptance: run these six commands in order; every one must exit 0.
  `R='/^## 14\. Self-review/,/^## 15\./'`
  `test "$(sed -n "$R p" skills/planning/SKILL.md | grep -c '^- \*\*')" = 12`
  `test "$(sed -n "$R p" skills/planning/SKILL.md | grep -c 'Discrimination check\|Verdict coverage')" = 2`
  `sed -n "$R p" skills/planning/SKILL.md | grep '^- \*\*' | tail -1 | grep -q 'Discrimination check'`
  `test "$(sed -n "$R p" skills/planning/SKILL.md | grep -c 'never an arbitrary one')" = 1 && test "$(sed -n "$R p" skills/planning/SKILL.md | grep -c 'fails this check outright')" = 1`
  `bash scripts/validate.sh | tail -1 | grep -q 'ALL CHECKS PASSED'`

## U3: Prepare the human-posted closing payloads for issues #11 and #12

Files:
  Create/Modify: docs/issue-closures/2026-08-15-issue-11.md, docs/issue-closures/2026-08-15-issue-12.md
Depends on: U1 and U2, both landed. This unit quotes the wording that shipped, read out of `skills/planning/SKILL.md`, so running it earlier makes its byte-identity check unsatisfiable.
Steps:
  1. Create `docs/issue-closures/2026-08-15-issue-11.md` containing, in this order: the shipped Discrimination check bullet, copied out of `skills/planning/SKILL.md` and written as one unwrapped line prefixed `> ` so the byte-identity check in step 3 can normalize it; one paragraph stating that the shipped wording differs from the issue's proposal because two independent invariant attacks constructed plan steps that satisfied the proposal while still carrying the defect — the first compared two different artifact kinds, the second varied an input the option under test does not touch — so the fixture is now bound to the step's own comparand kinds and producing pipeline, the changed input is bound to the axis under test, and the recorded results are observed rather than expected; and pointers to `docs/reviews/2026-08-15-planning-discrimination-and-verdict-coverage-spec-review.md`, `docs/reviews/2026-08-15-planning-discrimination-and-verdict-coverage-plan-review.md`, and `docs/deviations/2026-08-15-discrimination-axis-and-out-of-set-verdict-012.md`. No metadata, no command, no marker — the file is the comment body and nothing else.
  2. Create `docs/issue-closures/2026-08-15-issue-12.md` with the shipped Verdict coverage bullet in the same one-line quoted form; one paragraph stating that the issue's proposed enumeration source was a disjunction that let an author-declared output set shadow the origin spec's enumeration — the exact defect the issue reported — so the shipped clause takes the union of both sources, and that a later attack added the out-of-set value alongside the unresolved case, the value-specific next step, and the unconsumed-verdict case; and the same three pointers.
  3. Verify each payload quotes the wording that actually shipped, normalizing whitespace on both sides. For issue #11:
     `R='/^## 14\. Self-review/,/^## 15\./'`
     `SKILL_BULLET=$(sed -n "$R p" skills/planning/SKILL.md | awk '/^- \*\*Discrimination check\*\*/{f=1;print;next} f&&/^- \*\*/{exit} f&&/^[^-]/{print}' | tr -s '[:space:]' ' ')`
     `PAYLOAD_BULLET=$(grep '^> - \*\*Discrimination check\*\*' docs/issue-closures/2026-08-15-issue-11.md | sed 's/^> //' | tr -s '[:space:]' ' ')`
     `test "$SKILL_BULLET" = "$PAYLOAD_BULLET"`
     Repeat with `Verdict coverage` and `docs/issue-closures/2026-08-15-issue-12.md`.
  4. Self-review: neither file contains any `gh` invocation, authorization statement, or sentence that reads as approval to post. The posting command and its non-authorization marker belong to the loop ledger at the Ship gate, never to the payload (`enforces: P7`).
  5. Commit: "docs(issues): Prepare closing payloads for #11 and #12"
Acceptance: run these five commands in order; every one must exit 0.
  `test -f docs/issue-closures/2026-08-15-issue-11.md && test -f docs/issue-closures/2026-08-15-issue-12.md`
  `grep -q 'Discrimination check' docs/issue-closures/2026-08-15-issue-11.md && grep -q 'Verdict coverage' docs/issue-closures/2026-08-15-issue-12.md`
  `test "$(grep -lE 'gh (issue|pr|api|repo|release) ' docs/issue-closures/*.md | wc -l | tr -d ' ')" = 0`
  step 3's two `test` comparisons, both exiting 0
  `bash scripts/validate.sh | tail -1 | grep -q 'ALL CHECKS PASSED'`

## Mutation/failure-state matrix

No stateful ceremony in the deliverable; no mutation/failure-state matrix required.

The units modify one skill file and create two documentation files, and every transition is a local commit. No unit pushes, publishes, posts a comment, changes repository visibility, or creates a release. Posting the U3 payloads is an outward-publication boundary, and it is deliberately not a unit: a human performs it at the Ship gate with first-hand consent (`enforces: P7`).

## Carry-forward trigger audit

Classification per step 5a against the File structure table above, with recorded fired-state annotations read first (latching) and the tiebreak applied (a trigger naming both a file condition and an event resolves to edit-based). Tracker: `ROADMAP.md` — nine open carry-forward rows plus twelve open Future-candidate rows. Both independent review lanes re-derived this table; their re-derivations agreed with its verdicts and counts.

| Tracker row (ROADMAP.md line) | Class | Fired by | Disposition |
|---|---|---|---|
| Conformance suite (12) | event-based | Latched: the row carries `**fired**` (structural validation passed 18 retro documents whose independence level the ladder did not warrant, 2026-08-14) and stays open | Deferred with reason (see Deferred to Follow-Up Work) |
| Schema validators + fixtures (13) | event-based | Latched: the row carries `**fired**` with the review-envelope/v1 half still open | Deferred with reason (see Deferred to Follow-Up Work) |
| Post-Retro terminal criterion cannot be measured in Retro (53) | event-based | Not fired: no criterion in the origin spec resolves after Retro; SC6 resolves at the Ship gate | — |
| Shipping can delete the worktree owning live loop state (54) | edit-based by tiebreak | Not fired: the file list touches neither `skills/shipping/SKILL.md` nor the release-loop post-merge handoff. Operationally live for this loop and already mitigated by the ledger's carried-hazard line | — |
| Forced-failure matrices omit partial durable state (55) | edit-based by tiebreak | **Fired**: the trigger names a planning-contract change, whose mechanically checkable reading is an edit to `skills/planning/SKILL.md` or `schemas/plan-schema.md`, and U1/U2 edit the former | Deferred with reason (see Deferred to Follow-Up Work) |
| Loop artifacts outliving their loop sit only in gitignored state (57) | edit-based by tiebreak | **Fired** on its third arm, read conservatively: U3 writes a post-merge deliverable | Folded: U3 writes `docs/issue-closures/`, a committed path, and the Design phase's review artifacts were moved to `docs/reviews/` for the same reason |
| Reviewer output is never persisted (58) | edit-based by tiebreak | Not fired: the file list touches neither the interview protocol's round contract nor `reviewing`'s dispatch steps. Discharged voluntarily anyway — all four review lanes of this cycle are committed under `docs/reviews/` | — |
| Review verifies conformance instead of attacking the invariant (59) | event-based | **Fired**: this cycle's deliverable is an integrity mechanism | Deferred with reason (see Deferred to Follow-Up Work); satisfied procedurally twice this cycle — the Design-gate attack closed five loopholes and the plan-gate attack closed two more, carried by addendum 012 |
| Finding severity graded by blast radius instead of threatened criterion (60) | event-based | **Fired**: both review gates triaged findings against a mechanism this cycle exists to build | Deferred with reason (see Deferred to Follow-Up Work); satisfied procedurally this cycle — every dispatch prompt carried the row's severity rule verbatim and both lanes graded by threatened criterion |
| Human-discharged criterion has no gate blocking the completion report (61) | event-based | **Fired**: the origin spec declares SC6, which no skill can discharge | Folded: SC6 is stated as human-discharged, U3 produces the pipeline-side payload, and the criterion forbids reporting itself met on an unposted payload |
| Dispatched agents' commits land unsigned (62) | event-based | Not fired: no unit is dispatched to a committing subagent | — |
| Session-history search (14), compound-refresh auto-apply (15), cross-round deepening suppression (16), demo/evidence capture (17), project-defined lane schema (18), ambient compound triggers (19), Gemini support verification (20), evidence-tier vocabulary (21), skill-level trace evidence (22), new-skill distinctness gate (23) | event-based | Not fired: each names an external occurrence — a session retro, a third refresh cycle, a user complaint, a UI-heavy project, a second project, a Gemini user — none of which is this cycle | — |

Audited ROADMAP.md at 68ffafe: 21 open rows, 7 fired, 0 unobservable.

## Deferred to Follow-Up Work

- **ROADMAP row 12 (conformance suite)** — fired via latching. Deferred: the row itself records that the suite build stays deferred to its own cycle, and this spec ships no test harness. The firing is recorded here so the row keeps its latch.
- **ROADMAP row 13 (schema validators + fixtures)** — fired via latching, review-envelope/v1 half still open. Deferred: no validator work is in this spec's file set; the row's original trigger continues to govern.
- **ROADMAP row 55 (forced-failure matrices omit exact partial durable state)** — fired, because U1/U2 change the planning contract. Deferred: the remedy edits the mutation/failure-state matrix contract in `schemas/plan-schema.md` and step 10, both outside the approved spec's file set, and this plan carries the stateless fallback so it has no matrix to improve. It remains the natural fold for the next planning-contract change that touches the matrix.
- **ROADMAP row 59 (attack the invariant instead of verifying conformance)** — fired, and satisfied procedurally twice this cycle: the Design-gate attack produced five wording repairs and the plan-gate attack produced two more plus addendum 012. Deferred as a durable-rule change: writing the construction requirement into `skills/reviewing/SKILL.md`'s dispatch steps is outside this spec's file set, so the row stays open for the cycle that edits that file.
- **ROADMAP row 60 (severity graded by threatened criterion)** — fired, and satisfied procedurally this cycle: every review dispatch prompt carried the row's rule verbatim, and both lanes graded the loopholes P0 because they threatened SC2 and SC3 rather than by code reachability. Deferred as a durable-rule change for the same reason as row 59.
- **The plan-schema mirror plus a `validate.sh` agreement check** — the origin spec's Open Decision 1, resolved at the Design gate as prose only. Trigger to build: the first plan authored under these checks that ships with a comparison step or a consumed verdict and omits its required trace.
- **`CHANGELOG.md` entry for the two checks** — step 12 assigns changelog entries to `shipping`, never to a planning unit. The repository has no unreleased heading, so `shipping` creates one when it next cuts a release.
- **A `grep` recipe that excludes `.release-loop/`** — the Assumption Recheck row for step 14 mirroring now matches this loop's own ledger. Measurement hygiene only; no behavior depends on it.

## Open unknowns

**Planning-time**: none. The origin spec's Open Decision 2 (whether the unresolved-measurement clause belongs in step 14 or in the mutation/failure-state matrix) is resolved here in favor of step 14: the matrix enumerates outcome classes of durable state transitions, while this clause enumerates values of a verdict, and no unit in this plan performs a durable transition.

**Implementation-time** (deferred by design):
- Exact line wrapping of the two inserted bullets in the skill file, which follows whatever column the surrounding bullets use. The payload copies in U3 are deliberately unwrapped so the byte-identity comparison has a single line to normalize.
- Exact prose of the one explanatory paragraph in each U3 payload beyond the content specified in the unit steps.

## Verification summary

Per-unit acceptance commands above; each exits nonzero on a wrong implementation. Spec criteria:

- **SC1** — after U2: bullet count `12`, name count `2`, bullet 4 named `Verdict coverage`, last bullet named `Discrimination check`. Established red on the pre-change tree at `2026-08-14T19:42:34Z` (`10` and `0`), reconfirmed at `2026-08-14T20:06:11Z`.
- **SC2** — reject case A: issue #11's step comparing a `.mlmodelc` digest against an `.mlpackage` digest to prove `--optimize` took effect. Reject case B (the sixth loophole, per addendum 012): a step comparing two same-kind `coremldata.bin` digests from the same pipeline, where the changed input is the source package rather than the `--optimize` option whose effect the step verifies. Accept case: a step that hashes two builds of the same kind produced by the same conversion command, where the changed input is the very option under test, and that records the same-input pair as equal and the changed-option pair as different. Pass requires reject, reject, then accept, each with the deciding clause quoted; a rejection that needs a charitable reading of "the comparison" is a fail.
- **SC3** — reject case: a plan whose origin spec enumerates three hypotheses, whose measuring unit declares an output set of only the two branched values, and which carries no Deferred entry for the third. Accept case: a plan whose value-specific branches plus Deferred entries cover the union of declared set and spec enumeration, including both the unresolved measurement and a value outside that set. Pass requires reject then accept with the deciding clause quoted.
- **SC4** — `bash scripts/validate.sh` → `ALL CHECKS PASSED`, exit 0.
- **SC5** — `bash scripts/test-retro-format-drift.sh` → `ALL CASES PASSED`, exit 0.
- **SC6** — human-discharged. U3's payloads plus the ledger's recorded posting command and non-authorization marker are the pipeline-side deliverable; the criterion is not met until a human posts them.

Risk mitigation traceability — each Risks row in the origin spec whose mitigation requires a deliverable, and the carrier that discharges it:

| Spec risk | Mitigation carrier |
|---|---|
| Checks ship as unenforceable prose | SC2 and SC3 in this section, plus U2 step 1's observed-results and axis-binding clauses and U1 step 1's union clause |
| Step 14 grows to twelve checks | U1 and U2 step 1 both open with a trigger shape; scenario S3 verifies the vacuous-satisfaction path |
| A checker guessing shapes from plan prose produces false verdicts | Architecture notes ("No mechanical check ships") and the Deferred entry that gives the mirror a trigger |
| R2's wording grows long enough to be skimmed | U1 step 3's clause-by-clause self-review against the spec's Interface section and addendum 012 |
| The new checks cannot validate their own plan | Carry-forward audit row 59, its Deferred entry, and the Phase 4 dispatch instruction below |
| Consuming-repository incidents mistaken for local evidence | No unit or criterion depends on them; the SC2 and SC3 rubric cases are applied to plan text, not to that repository |

Phase 4's review dispatch carries three instructions verbatim: re-derive the carry-forward audit above against the final file list; repeat the invariant attack against the shipped wording rather than checking conformance to this plan; and grade any finding by the success criterion it threatens, not by code blast radius.
