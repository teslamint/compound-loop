---
module: planning
date: "2026-07-24"
problem_type: workflow_issue
component: lifecycle-skill
severity: medium
applies_when:
  - "a repo tracks carry-forward rows whose trigger-to-build conditions are edit-based (fire when a named file is touched) or drift-based (fire when a record shape deviates)"
  - "a plan's File structure section names files that appear in any open carry-forward row's trigger"
  - "a planning self-review includes a retro-carryover check"
symptoms:
  - "carry-forward rows with fired triggers survive an entire release cycle unaddressed and are caught only by the next retro's reconciliation"
  - "a plan's Deferred section omits a tracker row whose trigger the plan's own file list satisfies"
root_cause: "planning's retro-carryover check asks a feature-relevance question while the tracker rows' triggers are file-path and record-shape conditions"
resolution_type: process_rule
tags:
  - carry-forward
  - trigger-to-build
  - planning
  - retro-reconciliation
---

# Carry-Forward Trigger Planning Audit Gap

## Context

In the 2026-07-24 evidence-tier-vocabulary cycle, four of six live ROADMAP
carry-forward rows had their trigger-to-build conditions fire within one
cycle, and three went unnoticed until the retro:

- "Define hand-up packet in `skills/shipping/SKILL.md`" — trigger "next
  shipping SKILL edit" — fired by commit `2299955`, which edited that file
  for an unrelated one-sentence pointer extension.
- "Carry-forward check structural assertion" — trigger "next
  retro-template/check-9 design cycle" — fired by commit `503da9b`, which
  edited `schemas/retro-template.md` for an unrelated example-row change.
- "Mechanical validate.sh check for `final_action` shape" — trigger "first
  observed drift in a real record" — fired by the recurring out-of-schema
  `note:` field in the live progress ledger, present for the second
  consecutive cycle.

The fourth (plan clause-consistency) fired and was handled in-cycle only
because a previous retro had converted it into a mandatory review-prompt
instruction. The planning phase's retro-carryover self-review had answered
"does a prior carry-forward item belong in this plan?" — a feature-relevance
question — with a defensible no for all three missed rows, because none of
them relate to evidence tiers. Their triggers never asked about the feature:
they asked whether the plan touches a file or whether a record shape drifted.

## Guidance

When planning writes its File structure section, run a trigger audit before
finalizing the plan:

1. List every open carry-forward row in the durable tracker and extract its
   trigger condition.
2. Classify each trigger: edit-based (names files/sections), drift-based
   (names a record shape or observable state), or event-based (names a
   future occurrence).
3. Diff the plan's file list against every edit-based trigger, and known
   live-record state against every drift-based trigger.
4. A fired trigger folds its row into the plan (as a unit or explicit
   Deferred entry with a reason) — silence is not an option once the
   condition holds.

The feature-relevance question stays useful for event-based triggers; it is
the wrong instrument for the other two classes.

## Why This Matters

Trigger-to-build discipline (build when the trigger fires, not before) only
works if trigger firing is actually detected. An edit-based trigger that
fires unnoticed converts the discipline into indefinite deferral: the cheap
moment to fold the item in — while the file is already open and under review
— is spent, and the item waits another full cycle. Detection at retro time
is a backstop, not a substitute: it lands after merge, when the edit window
has closed.

## When to Apply

- Writing any plan whose File structure names files appearing in open
  tracker rows' triggers.
- Reviewing a plan: check the Deferred section against the tracker's
  edit-based triggers.
- Retro reconciliation: classify each row's trigger before classifying its
  status — a softened reading ("grazed", "no real drift") is the same miss
  in a second form; this cycle's facilitator rejected exactly that reading
  twice.

## Examples

The miss: plan `docs/plans/2026-07-23-001-feat-evidence-tier-vocabulary-plan.md`
lists `skills/shipping/SKILL.md` and `schemas/retro-template.md` in File
structure; ROADMAP rows 54 and 47 carried edit-based triggers naming those
same files; the plan's Deferred section lists three items, none of them
these rows.

The audit that would have caught it: `rg -n "Trigger" ROADMAP.md` against
the plan's file table — two overlapping paths, both rows folded or
explicitly deferred at planning time.
