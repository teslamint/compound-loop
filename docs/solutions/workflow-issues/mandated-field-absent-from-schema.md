---
module: release-loop
date: "2026-07-26"
problem_type: workflow_issue
component: shipping
severity: medium
applies_when:
  - "a skill or procedure mandates persisting a specific string or fact into a record"
  - "the record's schema documents a fixed field set with no slot for that string"
  - "a tracker row already names the gap and is being reconciled cycle over cycle"
related_components:
  - release-loop
  - retrospective
tags:
  - schema-drift
  - release-loop
  - carry-forward
  - measurement
---

## Context

`skills/shipping/SKILL.md` Step 7 requires that, before the merge gate resolves,
the exact merge command **and** the non-authorization marker
`preparation evidence -- first-hand consent still required` be written into the
durable `final_action` record. `skills/release-loop/references/progress-schema.md`
documents that record as exactly four fields — `kind`, `status`, `command`,
`updated`. There is nowhere to put the marker.

Every ship phase that follows Step 7 faithfully therefore invents a key. The
2026-07-26 cycle wrote `note:` at `determined` and `result:` at `executed`;
earlier cycles wrote their own variants. A carry-forward row (N-1) has named
this gap since 2026-07-22 and asks for a marker/note slot in the schema block.

The trap is in how the row was being read. The 2026-07-24 retro recorded that
the live record "stayed schema-clean (4-field block, no `note:`) for the first
cycle since registration" — an encouraging signal that the discipline was
improving. It was not. That cycle merged locally by repo convention and never
reached a ship phase holding a marker to persist. The mandating path simply did
not run. The next cycle that did reach Step 7 drifted immediately.

## Guidance

When a procedure mandates writing something a schema has no field for, treat the
schema as the defect and fix it there. Inventing a key is the *compliant* local
behaviour — the author is obeying the more specific instruction — so no amount of
author discipline closes the gap.

Concretely:

1. **Read the mandate and the schema together.** A rule that says "persist X into
   record R" is incomplete unless R's documented shape has somewhere for X to go.
   The pair, not either half, is the contract.
2. **Do not measure the gap by counting clean cycles.** A clean cycle is evidence
   that the record is clean; it is evidence about the gap only if the mandating
   path actually executed. Before recording "improved", verify the path ran —
   here, that a ship phase reached the merge gate at all.
3. **When a tracker row names a missing slot, the disposition is a schema edit,**
   not a reminder to be careful. A row that recurs while its own trigger keeps
   firing is not being deferred; it is being misread.

## Why This Matters

Two failure modes compound here.

The first is silent, ordinary drift: records that consumers may tolerate but that
no longer match their documented shape, so the next person to write a parser, a
validation check, or a migration works from a schema the data does not follow.

The second is worse, because it corrupts the reconciliation process itself. A
carry-forward row exists to survive the cycle that registered it. If its status
is inferred from an observation that only holds when a particular code path runs,
then a quiet cycle reads as progress and the row drifts toward "resolving" while
nothing has changed. The measurement and the thing measured come apart, and the
tracker — the mechanism specifically built to prevent forgetting — becomes the
thing that forgets.

## When To Apply

- Reconciling any carry-forward row whose evidence is "we observed the record was
  clean" rather than "we changed the artifact."
- Reviewing a skill edit that adds a "persist X to the durable record" step.
- Writing or revising a schema that a procedure elsewhere writes into.
- Any time a status improves without a corresponding commit — ask which path had
  to run for that observation to mean anything, and whether it ran.

## Examples

**The gap, as it stands:**

```
# skills/shipping/SKILL.md, Step 7
# ... write the exact merge command plus the non-authorization marker
# "preparation evidence -- first-hand consent still required" to the durable record

# skills/release-loop/references/progress-schema.md
final_action:
  kind: merge-to-base
  status: predicted
  command: null
  updated: <ISO-8601 timestamp>
```

**What a compliant ship phase then writes:**

```
final_action:
  kind: merge-to-base
  status: determined
  command: gh pr merge 1 --merge --delete-branch
  note: preparation evidence -- first-hand consent still required   # <- no schema slot
  updated: 2026-07-26T09:56:00Z
```

**The measurement error, in the reconciliation that preceded it:**

> `final_action` record polish — Not started — edit trigger did not fire
> (`progress-schema.md` untouched); notably the N-1 recurrence stopped: this
> cycle's live record stayed schema-clean (4-field block, no `note:`) for the
> first cycle since registration

The parenthetical is accurate and the inference from it is not. That cycle used
the repo's local-merge convention and never executed Step 7.

## Related

- `universal-invariant-scope-enumeration-gap.md` — the sibling failure from the
  same subsystem: a spec's universal invariant ("every persisted packet") versus
  its own narrower scope, where the uncovered instance also shipped in full
  compliance. Moderate overlap: shared subsystem and the same "compliance
  produced the defect" shape, but a different cause (spec-internal inconsistency
  rather than a missing schema slot) and a different fix (enumerate instances
  rather than add a field). The N-1 carry-forward row discussed here originated
  in that doc's cycle.
