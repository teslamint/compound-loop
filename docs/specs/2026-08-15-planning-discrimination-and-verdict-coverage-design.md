---
title: Planning Discrimination and Verdict Coverage
status: approved
date: 2026-08-15
schema: spec/v1
---

# Planning Discrimination and Verdict Coverage Design

_Created 2026-08-15._

## Overview

`skills/planning/SKILL.md` step 14 (Self-review) carries ten checks, and every one of them is an internal-consistency or dataflow check. Two failure classes escape all ten: a step that specifies a comparison or guard which cannot return both answers, and a unit that emits a verdict consumed by later units while one of that verdict's values has no next step. This spec adds one check per class (issues #11, #12), phrased so each check can itself fail.

Both defects were observed in a consuming repository on 2026-08-13 and are reported in the issues; neither is reproducible in this repository. This spec treats those observations as *reported, not verified here*, and grounds every criterion it declares in this repository instead.

## User Scenarios

### S1: A planner writes a digest comparison that cannot discriminate

An author plans a step proving a conversion option took effect by comparing a compiled artifact's digest against the source package's digest. Step 14's Discrimination check refuses the step on its face — the two comparands are different artifact kinds — and, for a repaired step comparing two builds of the same kind, makes the author run the same-kind pair and record what it observed. The same-input run turns out to compare different (fresh manifest UUIDs), so the equality half fails and the comparison is exposed at planning time instead of after the plan is sealed.

### S2: A planner branches on two of three verdicts

A spec enumerates three hypotheses. The author's plan measures which holds and supplies remedy units for two of them, declaring the measuring step's output as those two values. Step 14's Verdict coverage check takes the union of the step's declared output set and the spec's enumeration, so the author's narrower declaration cannot shadow the spec's third value. That value has no branch, so the gap is a blocking finding at planning time rather than a conditional unit firing at the wrong component during implementation.

### S3: A planner has no comparison and no verdict

An author plans a documentation change with no comparison step and no verdict-emitting unit. Both new checks are conditional on their trigger shape, so neither fires and step 14 costs the author nothing extra.

### S4: A reviewer audits whether the checks can fail

A reviewer applying this cycle's own deliverable walks the two historical cases named in the issues and confirms each check rejects them by a clause the reviewer can quote, then walks a compliant counterpart and confirms acceptance. Both answers are reachable, so the checks are not vacuous.

### S5: A planner's diagnostic resolves to nothing

An author plans a measurement that can error or come back ambiguous. Verdict coverage treats "the measurement failed to resolve" as a member of the value set, so the author must give it a next step or a Deferred entry instead of discovering at implementation time that the plan assumed the measurement always answers.

## Scope

### In

- R1: step 14 gains a **Discrimination check** covering steps that compare two things or assert a guard.
- R2: step 14 gains a **Verdict coverage** check covering units that emit a verdict, decision, or classification consumed by a later unit.
- Placement and ordering of both bullets inside step 14, with a stated rationale.
- A prepared closing comment for each of issues #11 and #12, quoting the wording that shipped. Posting and closing are human actions (see Success Criterion 6).

### Out

- Rewording or reordering the existing ten step 14 checks.
- Any change to `skills/designing/SKILL.md` step 10, whose empirical-grounding sub-step is the pattern this borrows from but does not modify.
- Regex detection of comparison or verdict shapes inside plan prose. Plan bodies are free narrative; a checker that guesses which steps are comparisons produces false positives and false negatives, and a marker the author chooses to write is self-attested. Rejected by design, not deferred.
- Mirroring the two rules into `schemas/plan-schema.md` plus a `scripts/validate.sh` agreement check. Deferred with a trigger (Open Decisions 1), because that mechanism proves only that two contract files contain agreeing text; it leaves plan bodies exactly as unaudited as prose alone.
- `CHANGELOG.md`. `skills/planning/SKILL.md` step 12 assigns changelog entries to `shipping`, never to a planning unit; this spec does not reassign that ownership.
- Retrofitting the two checks onto the 20 plans already in `docs/plans/` (`find docs/plans -maxdepth 1 -type f -name '*.md' | wc -l` → `20`, observed `2026-08-14T20:04:00Z`). The checks bind plans authored after this change.
- Any claim that the consuming-repository incidents are reproducible here.

## Assumptions and Preconditions

| Claim | Command | Observed at | Observed result | Evidence source |
|---|---|---|---|---|
| Step 14 carries exactly ten checks and none mentions discrimination or verdicts | `sed -n '/^## 14\. Self-review/,/^## 15\./p' skills/planning/SKILL.md \| grep -c '^- \*\*'` then the same range `\| grep -ci 'discriminat\|verdict'` | `2026-08-14T19:42:34Z` | `10` then `0` | Working tree at `86586a0`, branch `feat/planning-discrimination-and-verdict-coverage` |
| `schemas/plan-schema.md` hard floor has ten items | `sed -n '/## Document body — hard floor/,/^## Implementation Unit template/p' schemas/plan-schema.md \| grep -cE '^[0-9]+\. \*\*'` | `2026-08-14T19:42:34Z` | `10` | Working tree at `86586a0` |
| No check asserts that plan documents contain the hard-floor sections, so a plan may omit any body section with nothing going red | `grep -n 'plans_dir\|docs.*plans' scripts/validate.sh` | `2026-08-14T19:42:34Z` | Only the frontmatter validator loop (line 400) and the body-seal check (lines 670-676) read `docs/plans/*.md`; neither inspects body sections | Working tree at `86586a0` |
| Step 14's checks are mirrored in no other file, so a skill-to-consumer drift assertion has no existing consumer pair to anchor against | `grep -rln 'Command closure' --include='*.md' --include='*.sh' . \| grep -v '^./docs/'` | `2026-08-14T19:42:34Z` | `./skills/planning/SKILL.md` only | Working tree at `86586a0` |
| `[plan-refs]` validates step numbering contiguity and cross-references, not step 14 bullet content, so adding non-numbered bullets cannot break it | `sed -n '567,662p' scripts/validate.sh` | `2026-08-14T19:42:34Z` | The check parses `^## (\d+[a-z]?)\.` headings, deepening sections, and hard-floor item numbers; it never inspects bullets inside a step | `scripts/validate.sh` lines 567-662 |
| `CHANGELOG.md` has no unreleased heading, so a criterion measuring an entry "under the unreleased heading" would be unmeasurable | `grep -nic 'unreleased' CHANGELOG.md` | `2026-08-14T19:52:00Z` | `0`; the newest heading is `## [0.10.0] - 2026-08-03` | `CHANGELOG.md` lines 1-7 |
| The loaded plugin cache and this repository both declare version 0.10.0 while their `release-loop` skill text differs | `diff -q skills/release-loop/SKILL.md ~/.claude/plugins/cache/compound-loop/compound-loop/0.10.0/skills/release-loop/SKILL.md` | `2026-08-14T19:35:30Z` | `DIVERGENT`; cache line 38 lacks the default-isolation wording present at repo HEAD | Both files, read in this session |

Repository invariants that still apply: `bash scripts/validate.sh` and `bash scripts/test-retro-format-drift.sh` both pass at `86586a0` (verified fresh in this worktree at loop start).

## Architecture

One file carries the behavior change:

- `skills/planning/SKILL.md` step 14 — two added bullets. Step 14 is prose consumed by the planning author, so the deliverable is wording, and its quality bar is whether the wording can reject a bad plan.

Ordering rationale. Step 14's existing bullets fall into two families: coverage checks that re-walk a whole-document map (Spec coverage, Scenario coverage, Retro carryover), and step-level probes of one step's substance (Placeholder scan, Type consistency, Command closure). **Verdict coverage** is the declared dual of Spec coverage, so it sits immediately after Scenario coverage. **Discrimination check** probes a single step the way Command closure does, so it sits immediately after Command closure as the last bullet.

Both checks are conditional on a trigger shape — a comparison or guard step for R1, a verdict-emitting unit for R2 — so a plan containing neither shape adds no self-review cost (S3).

Each check leaves a durable trace inside the plan step it fires on: R1 requires the fixture pair and the two results the author **observed** when running it, and R2 requires the enumerated value set with each value's own next step. Observed results, not predicted ones, are what let a later reader tell a run check from an unrun one — issue #11's author predicted "same inputs compare equal" and was wrong, and only running it surfaces that.

### Interface — the exact wording to ship

R1, appended after the Command closure bullet:

> - **Discrimination check** — for every step that compares two things or asserts a guard, run the step's own comparison on a fixture pair of the same artifact kinds as the step's real comparands, produced by the same command or pipeline that produces them, and record in the step the pair plus the two results you observed. Two runs of the same inputs must compare equal; one changed input must compare different. A step whose comparands are different artifact kinds fails this check outright: they always differ, so the comparison cannot report anything about the change. A guard that cannot fail is not a guard.

R2, inserted after the Scenario coverage bullet:

> - **Verdict coverage** — for every unit that emits a verdict, decision, or classification, enumerate the possible values from the union of the emitting step's declared output set and the origin spec's own enumeration — never from recall, and never from the narrower of the two — and include the measurement failing to resolve as one of the values. Confirm each value has its own next step; a single catch-all consumer that acts on "whatever the verdict says" covers nothing. A value with no branch is a plan gap, not an implementation-time unknown. A value deliberately out of scope goes to Deferred to Follow-Up Work with its reason, and a verdict no unit consumes is itself either a gap or a deliberate Deferred entry.

Both wordings start from the issues' proposed text. Five repairs came from the independent review, each closing a constructed loophole that satisfied the original wording while still being the defect the check exists to catch:

1. R1 binds the fixture to the step's **own** comparands (same kinds, same producing process). The original let an author demonstrate digest comparison on toy files while the step's real comparison of different artifact kinds still could never return equal.
2. R1 records **observed** results, not expected ones. A prediction is available to an author who never ran anything.
3. R1's different-kinds clause is imperative ("fails this check outright"), not declarative rationale.
4. R2 takes the **union** of the two enumeration sources. The original disjunction let the author's own declared output set — written by the party being checked — shadow the spec's larger enumeration, which is exactly issue #12's defect.
5. R2 requires a **value-specific** next step, counts the unresolved measurement as a value, and closes the unconsumed-verdict trigger escape.

The two halves of R1 use this repository's existing vocabulary (`CONCEPTS.md`): the same-inputs half is an **invariance guard**, the changed-input half is a **discriminating criterion**. No new term is coined.

## Testing

Step 14 is prose, so it has no unit test. Three verification layers apply, and they are deliberately different in kind:

1. **Structural** — the two bullets exist, in their declared positions, with their required clauses. A structural check cannot detect whether the wording can reject anything (`docs/solutions/workflow-issues/structural-check-without-execution-evidence.md`), so it is necessary and insufficient.
2. **Behavioral, by historical case** — apply each new check to the case that motivated it and confirm rejection, then to a compliant counterpart and confirm acceptance. The inputs are not author-chosen: they come from the issues. Issue #11's `.mlmodelc`-versus-`.mlpackage` comparison must be rejected; issue #12's three-hypothesis plan with two remedy branches must be rejected **even when the plan declares a two-value output set**, which is the hostile variant the review constructed.
3. **Regression** — `bash scripts/validate.sh` and `bash scripts/test-retro-format-drift.sh` stay green, proving the edit disturbed no existing contract.

Layer 2 is the invariant attack this cycle owes (`docs/solutions/workflow-issues/verify-against-plan-vs-attack-the-invariant.md`), stated in advance so review cannot substitute conformance checking for it. It already fired once against this spec's draft wording and produced the five repairs listed above; the shipped wording must survive the same attack.

## Risks

| Risk | Mitigation |
|---|---|
| The checks ship as unenforceable prose and become two more self-attested bullets | Layer 2 of Testing requires demonstrated rejection of both historical cases, including the hostile variant, before approval; the in-step trace records observed results, which a later reader can audit |
| Step 14 grows from ten checks to twelve, raising self-review cost on every plan | Both checks are conditional on a trigger shape; S3 is the explicit no-cost case |
| A checker that guesses comparison or verdict shapes from plan prose produces false verdicts | Rejected in Scope/Out with the reason, not deferred as a future option |
| R2's wording grows long enough that authors skim it | Every clause traces to a constructed loophole listed under Interface; none is speculative. Prose economy is enforced by step 14's own no-placeholder discipline at plan time |
| This cycle's own plan is authored under the pre-change ten-check step 14, so the new checks cannot validate the plan that ships them | Recorded in the loop ledger at start; the manual invariant attack (Testing layer 2) is the declared substitute |
| The two consuming-repository incidents are unverifiable here and could be mistaken for local evidence | Every mention labels them reported; no success criterion depends on them |

## Success Criteria

1. *(discriminating)* Step 14 carries twelve checks; exactly two are named `Discrimination check` and `Verdict coverage`; and each sits in its declared position.
   - **Measured by**: with `R='/^## 14\. Self-review/,/^## 15\./'`, `sed -n "$R p" skills/planning/SKILL.md | grep -c '^- \*\*'` returns `12`; the same range piped to `grep -c 'Discrimination check\|Verdict coverage'` returns `2`; `sed -n "$R p" skills/planning/SKILL.md | grep '^- \*\*' | sed -n '4p'` names `Verdict coverage` (immediately after `Scenario coverage`, the third bullet); and the same pipeline's last line names `Discrimination check`. Established red at `2026-08-14T19:42:34Z` on the pre-change tree: `10` and `0`.
2. *(discriminating)* The shipped Discrimination check rejects the case that motivated it and accepts a compliant counterpart.
   - **Measured by**: judgment rubric. A reviewer reads the shipped bullet, then walks issue #11's step (compare a `.mlmodelc` digest against an `.mlpackage` digest to prove an option took effect) and records whether the bullet's own words refuse it, quoting the clause that decides it; then walks a step that runs the step's own comparison on two builds of the same kind and records the observed equal/different pair, and records whether the bullet accepts it. Pass requires reject on the first and accept on the second, with both deciding clauses quoted. A rejection that needs a charitable reading of which comparison is meant is a fail.
3. *(discriminating)* The shipped Verdict coverage check rejects the case that motivated it — including its hostile variant — and accepts a compliant counterpart.
   - **Measured by**: judgment rubric. A reviewer walks issue #12's plan shape (spec enumerates three hypotheses, plan supplies two remedy branches, no Deferred entry for the third) **with the plan declaring its measuring step's output set as only the two branched values**, and records whether the bullet refuses it, quoting the clause. Then walks a plan whose value-specific branches plus Deferred entries cover the union of declared set and spec enumeration, including the unresolved case, and records acceptance. Pass requires reject then accept, with both deciding clauses quoted.
4. *(invariance)* No existing repository contract regresses.
   - **Measured by**: `bash scripts/validate.sh` prints `ALL CHECKS PASSED` and exits 0.
5. *(invariance)* The retro-format contract suite stays green.
   - **Measured by**: `bash scripts/test-retro-format-drift.sh` prints `ALL CASES PASSED` and exits 0.
6. *(discriminating, human-discharged)* A closing comment for each of issues #11 and #12 exists as a committed or ledger-recorded payload quoting the shipped wording, and the loop's outward-action record names the exact command that posts it.
   - **Measured by**: the prepared payload files exist and contain the shipped bullet text (`grep -c 'Discrimination check' <payload>` returns at least `1`); the loop ledger records the posting command and its non-authorization marker. Posting and closing are human actions at the Ship gate (`enforces: P7`); this criterion measures the pipeline-side deliverable only, so the loop may not report it met on the strength of an unposted payload. ROADMAP already tracks the class of criterion that a human must discharge; this criterion states its human half rather than hiding it.

## Open Decisions

1. **Artifact-level binding for the two checks** — owner: **user, at this Design gate**. Ship the two rules as step 14 prose only, or additionally mirror them into `schemas/plan-schema.md` and add a `scripts/validate.sh` check asserting the two contract files agree?
   - **Recommendation: prose only, this cycle.** The draft of this spec recommended the mirror; the independent review falsified the justification. The proposed check can only assert that `skills/planning/SKILL.md` and `schemas/plan-schema.md` contain agreeing text. It detects contract-file drift — a real failure, and the one that produced defects #6 and #8 last cycle — but it does not detect whether an author ran either check, and no check inspects plan bodies (assumptions row 3), so plans stay exactly as unaudited as under prose alone. The false-green risk that justified the mirror is closed instead by Success Criteria 2, 3 and Testing layer 2, which require demonstrated rejection.
   - **Deferred with a trigger**: build the mirror plus a plan-body inspection when a plan authored under the new checks ships with a comparison step or a consumed verdict that omits its required trace. That is the first evidence that prose alone is insufficient, and a plan-body check has a real target only once the required sections exist in a shipped plan. Recorded in the plan's Deferred to Follow-Up Work section.
   - **If the user prefers the mirror now**: it needs its own Scope/In entries and success criteria (schema hard-floor item 11, one `validate.sh` check established red before green). The review's finding stands — the recommendation must not ship unmeasured.
2. **Whether R2's unresolved-measurement clause belongs in step 14 or in `schemas/plan-schema.md`'s Mutation/failure-state matrix** — owner: `planning`. Both cover unhappy outcomes; the matrix covers durable state transitions, while R2 covers verdict values. Resolvable from the two documents at plan time; not a product question.
