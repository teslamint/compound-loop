---
title: Planning-Time Carry-Forward Trigger Audit
status: draft
date: 2026-07-24
schema: spec/v1
---

# Planning-Time Carry-Forward Trigger Audit Design

_Created 2026-07-24._

## Overview

Planning's retro-carryover self-review asks a feature-relevance question
("does this item belong in this plan?") while most tracker rows' triggers are
file-path or record-shape conditions that never mention the feature. In the
2026-07-24 cycle four of six live carry-forward rows' triggers fired and three
went unnoticed until retro. This feature adds a mechanical trigger audit at
planning time — classify every open row's trigger, diff the fireable classes
against the plan's file list and known record state, and record the result as
a durable plan section that reviewers verify.

## User Scenarios

### S1: Edit-based trigger fires on a planned file

A planner (agent or human) drafts a plan whose File structure lists
`skills/shipping/SKILL.md`. An open tracker row carries the trigger "next
shipping SKILL edit". The audit step diffs the planned file list against every
edit-based trigger, detects the overlap, and the planner folds the row into
the plan — as a unit, or as a Deferred entry naming the row and the reason it
is not being done now. The plan's Carry-forward trigger audit section records
the fired row, its class, and the disposition.

### S2: No trigger fires

A planner drafts a plan touching only files no tracker row names, with no
observed record-shape drift and no fired-state annotations in the tracker. The
audit section carries the single fixed-template attestation line naming the
tracker state examined and the row counts. No row is reproduced into the plan.

### S3: Drift-based trigger fires on observed record state

An open row's trigger is "first observed drift in a real progress.md
`final_action` record". The live `.release-loop/progress.md` in the working
tree carries an out-of-schema field. The audit checks each drift-based
trigger's named record where it is observable at planning time, detects the
drift, and the row is folded or deferred with a reason — the same disposition
rule as S1. Had the drifted record already been archived, the row's recorded
fired-state annotation in the tracker would still count it as fired (latching
rule): a reset record does not un-fire a row.

### S4: Independent plan review catches an omitted fired row

A plan review (deepening persona or caller-dispatched subagent) re-runs the
audit diff itself: open tracker rows versus the plan's File structure and the
audit section's dispositions. It finds a planned file that appears in an
edit-based trigger with no corresponding disposition, and reports it as a
finding that blocks approval until resolved — the check is re-derived from the
tracker, never trusted from the section.

### S5: Repo without a durable tracker

A host repo adopting the skills has no carry-forward tracker. The audit
section states that explicitly in a fixed fallback line instead of being
silently absent, keeping the hard floor decidable for every repo.

## Scope

### In

- `CONCEPTS.md`: trigger-class vocabulary (edit-based, drift-based,
  event-based) and the trigger-audit concept.
- `skills/planning/SKILL.md`: a trigger-audit step tied to the File structure
  step; an extended self-review item re-running the audit against the final
  file list; a reviewer mandate that independent plan reviews re-derive the
  diff.
- `schemas/plan-schema.md`: a new hard-floor section, **Carry-forward trigger
  audit**, in the lean form (fired rows recorded fully; otherwise a one-line
  attestation; fixed no-tracker fallback).

### Out

- Retrospective-side rule ("classify each row's trigger before classifying
  its status" at reconciliation) — deferred; candidate carry-forward for this
  cycle's retro.
- Mechanical `scripts/validate.sh` check for the audit section — deferred by
  explicit user decision; build on the trigger-to-build pattern (first
  observed omission of the section in a real plan).
- Tracker format standardization — the audit reads "the durable tracker" as
  `retrospective` already defines it (ROADMAP, issue tracker, or equivalent);
  no new format is imposed on host repos.
- `skills/reviewing/SKILL.md` and `skills/retrospective/SKILL.md` — unchanged
  this cycle.

## Assumptions and Preconditions

| Claim | Command | Observed at | Observed result | Evidence source |
|---|---|---|---|---|
| Planning's existing carryover check is feature-relevance-only, one line | `rg -n "Retro carryover" skills/planning/SKILL.md` | 2026-07-24T18:20:10+0900 | Single hit, line 137: "does a prior retrospective's carry-forward item belong in this plan?" | Working tree at `eb93cd8` |
| Deferred to Follow-Up Work is item 8 of the plan-schema hard floor | `rg -n "Deferred to Follow-Up Work" schemas/plan-schema.md` | 2026-07-24T18:20:10+0900 | Single hit, line 33, numbered `8.` | Working tree at `eb93cd8` |
| This repo's tracker rows carry trigger conditions in a named column | `rg -n "Trigger / next step" ROADMAP.md` | 2026-07-24T18:20:10+0900 | Single hit, line 42 (carry-forward table header) | Working tree at `eb93cd8` |
| No skill or schema file mentions a trigger audit yet | `rg -ln -e "trigger audit" -e "trigger-audit" skills/ schemas/` | 2026-07-24T18:20:10+0900 | No matches | Working tree at `eb93cd8` |
| CONCEPTS.md exists and defines no trigger-class terms | `rg -n -e "edit-based" -e "drift-based" -e "event-based" CONCEPTS.md` | 2026-07-24T18:20:10+0900 | No matches (the only "trigger" usage is "lane triggers" under Metrics) | Working tree at `eb93cd8` |

## Architecture

Definitions and rules split per P5, following the evidence-tier-vocabulary
precedent: `CONCEPTS.md` owns the trigger-class definitions once;
`skills/planning/SKILL.md` owns the procedural rules and cites the terms;
`schemas/plan-schema.md` owns the durable record's section contract. No
consumer restates a definition — skills reference the vocabulary by name and
remain readable without `CONCEPTS.md` present (host repos install skills
without it), so each rule sentence carries enough inline gloss to be applied
literally, without reproducing the definitional bullets. The gloss boundary is
testable: a gloss is a parenthetical attached to the term's first use in a
rule sentence; the bolded-term definitional bullet form (`- **term** — ...`)
appears only in `CONCEPTS.md`.

Data flow at planning time: enumerate open tracker rows → classify each row's
trigger into exactly one class → diff edit-based triggers against the plan's
File structure list, and drift-based triggers against their named records
where observable in the working tree → every fired trigger produces a
disposition (fold as unit, or Deferred entry with reason) → the audit section
records fired rows and the attestation. Event-based triggers (a future
occurrence neither file-diffable nor record-observable) stay under the
existing feature-relevance question.

## Requirements

Grouped by concern; stable R-IDs.

**Vocabulary**

- R1: `CONCEPTS.md` gains a "Carry-forward triggers" section defining:
  **edit-based trigger** (fires when a named file or section is touched),
  **drift-based trigger** (fires when a named record shape or observable
  state deviates), **event-based trigger** (fires on a future occurrence
  outside the repo's current tree), and **trigger audit** (the planning-time
  act of classifying open rows and diffing the fireable classes against the
  plan). Each term defined exactly once, conceptually, with no file paths.

**Planning procedure**

- R2: `skills/planning/SKILL.md` gains a trigger-audit step that runs when
  the File structure section is written: list every open row in the durable
  tracker, classify its trigger into exactly one of the three classes, diff
  edit-based triggers against the planned file list, and check each
  drift-based trigger's named record where observable at planning time. A
  drift-based trigger whose record is not observable at planning time is
  recorded as unobservable — never given an invented verdict. A row whose
  trigger text yields no classifiable condition is recorded as unclassifiable
  and handled under the event-based feature-relevance path, never silently
  skipped.
- R2a: **Latching rule** — a row whose firing is already recorded (a
  fired-state annotation in the tracker itself, or a prior retro's
  reconciliation) counts as fired regardless of current observability; the
  audit reads recorded fired-state annotations before re-observing. A drifted
  record that has since been archived or reset does not un-fire a row.
- R3: A fired trigger folds its row into the plan — as an implementation
  unit, or as a Deferred to Follow-Up Work entry naming the row and the
  reason — in the same planning pass. Silence on a fired trigger is a plan
  gap that blocks approval.
- R4: The self-review's Retro carryover item is extended: re-run the trigger
  audit against the **final** file list (deepening and unit edits are the
  likeliest divergence vector), and confirm the audit section's attestation
  still names the tracker state actually examined. The feature-relevance
  question is retained for event-based triggers only.

**Durable record**

- R5: `schemas/plan-schema.md`'s hard floor gains a **Carry-forward trigger
  audit** section (inserted adjacent to Deferred to Follow-Up Work; existing
  section numbering may shift — hard-floor items carry no stable IDs). Lean
  form, three record shapes:
  - One row per **fired** trigger: tracker row, trigger class, disposition,
    reason.
  - One row per **unobservable** drift-based trigger: tracker row, the named
    record, and why it is not observable at planning time.
  - One **attestation line** always present, in the fixed template
    `Audited <tracker location> at <tracker state>: <N> open rows, <M> fired, <K> unobservable.`
    — where tracker state is a commit or equivalent identifier. When no
    trigger fired and nothing is unobservable, the section is the attestation
    line alone.
  When the repo has no durable tracker, write exactly:
  `No durable carry-forward tracker in this repo; no trigger audit possible.`

**Review**

- R6: `skills/planning/SKILL.md` states the reviewer mandate: any independent
  plan review (deepening persona or caller-dispatched) re-derives the audit —
  open tracker rows versus the plan's File structure and the audit section's
  dispositions — rather than trusting the section's own claims. An omitted
  fired row is a blocking finding. The same skill text instructs that whoever
  composes a plan-review dispatch prompt (deepening dispatch or a pipeline
  caller reading this skill) carries the re-derive instruction into that
  prompt verbatim, so the mandate travels with the dispatch rather than
  depending on the reviewer having read planning's skill text.

## Testing

Docs-only deliverable; verification is structural and rubric-based, tier-free.

- `rg`-decidable checks: each R1 term defined exactly once in `CONCEPTS.md`;
  the audit step, extended self-review item, and reviewer mandate present in
  `skills/planning/SKILL.md`; the hard-floor section with the exact no-tracker
  line and the fixed-prefix attestation template present in
  `schemas/plan-schema.md`.
- `bash scripts/validate.sh` passes after every unit (existing checks only;
  no new check added this cycle).
- Dogfood: this cycle's own plan is the first executed audit — its audit
  section must carry dispositions for every row the plan's file list fires
  (see SC6).

## Risks

- **Ceremony creep on small plans** — every plan gains a section. Mitigated
  by the lean form: the no-fire case is one attestation line.
- **Classification ambiguity** — a trigger could read as two classes.
  Mitigated by the exactly-one-class rule with a stated tiebreak in the skill
  text: a trigger naming both a file condition and an event resolves to
  edit-based (the mechanically checkable reading wins; the audit errs toward
  checking).
- **Stale attestation** — the tracker changes between draft and approval.
  Mitigated by R4: self-review re-runs the audit and re-verifies the
  attestation against the tracker state actually examined.
- **Procedural-only reviewer mandate** — R6 is skill text, not a mechanical
  check; the clause-diff precedent shows such mandates work but depend on
  prompt discipline. R6's carry-into-the-dispatch-prompt rule narrows the gap,
  but reviews dispatched by callers that never read planning's skill text
  remain out of reach — accepted deliberately: the mechanical check is
  deferred on the trigger-to-build pattern (Out of scope), and the durable
  audit section is itself the new mechanically checkable surface.

## Success Criteria

1. `CONCEPTS.md` defines edit-based trigger, drift-based trigger, event-based
   trigger, and trigger audit, each exactly once.
   - **Measured by**: four separate commands, each returning exactly 1: `rg -c -F "**edit-based trigger**" CONCEPTS.md`, `rg -c -F "**drift-based trigger**" CONCEPTS.md`, `rg -c -F "**event-based trigger**" CONCEPTS.md`, `rg -c -F "**trigger audit**" CONCEPTS.md` (the definitional bullet form appears only in CONCEPTS.md per the Architecture gloss boundary).
2. `skills/planning/SKILL.md` contains a trigger-audit step covering all
   three classes, the observability rule for drift-based triggers, the
   latching rule, the unclassifiable fallback, and the exactly-one-class
   tiebreak.
   - **Measured by**: `rg -n -e "edit-based" -e "drift-based" -e "event-based" skills/planning/SKILL.md` hits inside one audit step; reviewer rubric: the step's instructions can be executed literally against ROADMAP.md's current table without consulting this spec.
3. A fired trigger's disposition rule (fold as unit or Deferred entry with
   reason; silence blocks approval) is stated in the planning skill.
   - **Measured by**: `rg -n "fired" skills/planning/SKILL.md` shows the disposition sentence; reviewer confirms it names both disposition arms and the blocking consequence.
4. `schemas/plan-schema.md`'s hard floor contains the Carry-forward trigger
   audit section with the three record shapes, the fixed-template attestation
   line, and the exact no-tracker fallback line.
   - **Measured by**: `rg -n "Carry-forward trigger audit" schemas/plan-schema.md` hits the hard-floor list; `rg -n "No durable carry-forward tracker" schemas/plan-schema.md` hits the exact fallback line; `rg -n -F "Audited <tracker location>" schemas/plan-schema.md` hits the attestation template.
5. The self-review item re-runs the audit against the final file list and the
   reviewer mandate requires re-deriving the diff.
   - **Measured by**: `rg -n -e "final file list" -e "re-derive" skills/planning/SKILL.md` shows both; reviewer confirms the mandate names the omitted-fired-row consequence as blocking.
6. This cycle's own plan contains a conformant audit section whose
   dispositions cover every open tracker row fired by the plan's file list,
   observed record state, or a recorded fired-state annotation (latching
   rule).
   - **Measured by**: reviewer rubric — walk ROADMAP.md's open carry-forward rows against the plan's File structure, the live `.release-loop/progress.md`, and each row's own fired-state annotations; every fired row (including tracker-annotated fired rows such as ROADMAP's final_action-check row) has a disposition row, every non-fired row is covered by the attestation counts.
7. `bash scripts/validate.sh` passes on the final branch.
   - **Measured by**: `bash scripts/validate.sh` → `ALL CHECKS PASSED`.

## Open Decisions

- Whether the retrospective-side rule (classify trigger class before status
  at reconciliation) becomes a tracker row. Owner: this cycle's
  `retrospective` phase — register it as carry-forward or record why not.
- Exact placement and wording of the audit step inside
  `skills/planning/SKILL.md`'s numbered flow (between File structure and
  Deliverable-type gate, or folded into File structure). Owner: `planning`
  (implementation-time layout decision; the spec fixes behavior, not step
  numbering).
