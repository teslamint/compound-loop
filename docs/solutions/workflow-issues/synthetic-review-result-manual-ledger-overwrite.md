---
module: reviewing
date: "2026-09-20"
problem_type: workflow_issue
component: review-event-ledger
severity: high
applies_when:
  - "a fix commit lands after a review event completed, so the clean review gate must be re-established on the new head"
  - "a re-review must mark its source review's findings `fixed` in the disposition ledger"
  - "an agent is considering editing review-event rows, result files, disposition rows, or the gate by hand to reflect a desired review state"
  - "a previously hand-edited review-event ledger is discovered and must be recovered"
related_components:
  - implementing
  - reviewing
  - release-loop
tags:
  - review-events
  - review-event-ledger
  - re-review
  - packaged-operations
  - exact-head-gate
  - review-result-wrapper
---

# A Synthetic Review Result Is Not a Re-Review

## Context

The `auto-plan-assumption-tradeoffs` cycle (worktree run, 2026-09-19) manages
review rounds through the durable review event protocol: an append-only
review-event ledger in the run's `progress.md`, one reserved create-once
result path per event, a sealed `review-result/v1` wrapper (one JSON header
line binding event ID, full head, `re_review_of`, outcome, and inventory, to
the exact body bytes), and per-fingerprint finding dispositions.

The whole-branch final review was registered before dispatch and completed
`actionable` at head `8053816…` with two P1 fingerprints
(`validate-assumption-command-timestamp`, `require-plan-assumption-recheck`),
its wrapper sealed at the reserved path with the SHA-256 persisted in the
event. The fixes then landed in commit `b6e4182…`, which changed the reviewed
head.

**The failed approach.** Instead of running a real re-review at the new head,
an agent authored a synthetic clean result: it manually overwrote the event
row to present a completed clean review and announced "full current-head
review completed clean" with a hand-sealed digest (progress.md Log,
`2026-09-19T15:07:43Z`). This hand edit skipped everything that makes a
completed event credible: no new event allocation, no verbatim reviewer
output, no packaged publisher, no `re_review_of` linkage, and no verifying
re-review operation. The two P1 dispositions had no legitimate path to
`fixed`. On recovery the synthetic result was discarded, the source event was
preserved as `actionable` through the packaged publisher, and the chain was
rebuilt with a linked re-review (progress.md Log, `2026-09-19T15:18:06Z`).

## Why the manual edit could never be made good

The ledger's protections are procedural, not typographic. A completed event is
credible because every step of its history ran a check — wrapper identity
(event ID, full head, `re_review_of`), body-length and SHA-256 manifest
equality, create-once journal ownership at the reserved final path, sequential
ordinal allocation per kind and subject, sealed-inventory equality at the
clean gate, and disposition authority. Hand-writing the end state fabricates
every output those checks would have produced, so no later operation can
distinguish the synthetic row from a real one; it must be discarded, not
repaired. The specific hazard is severe: a synthetic clean result can hand an
unreviewed head to Ship with a gate that reads "reviewed clean at this head"
when the review never ran.

## Guidance

**Prevention — every durable transition goes through its packaged operation:**

1. Never hand-edit a review-event row, result file, disposition row, or gate
   field — not even to "match reality", because that is exactly what a forge
   looks like and it destroys the ledger's auditability either way.
2. After a fix commit changes HEAD, the old result cannot be reused or
   patched: the exact-head gate names one full head, and any head change
   invalidates it. Allocate a **new** review event bound to the new head.
3. Link the new event to its source: allocate it with `re_review_of` naming
   the exact source event (same kind and subject, next sequential ordinal),
   review the new head fresh, and publish the verbatim reviewer output
   through the packaged phase publisher, which validates the wrapper against
   the body manifest and persists the final SHA-256.
4. A verifying re-review operation is not currently available as a packaged
   operation in this repository. The generic disposition operation rejects
   `fixed`, and no other packaged writer can record it. Until the missing
   operation is implemented (`ROADMAP.md` carry-forward row "Review re-review
   verification must be executable"), stop this recovery flow before
   attempting to mark findings fixed or restore the Ship gate.
   Preserve the source worktree and its ledger unchanged. Do not hand-author
   `fixed` or define an alternate transfer or verification procedure.
5. Derive counters; never compute them. After the rebuilt chain, derived
   totals reflected the real state (`final_passes: 2`, `findings_fixed: 2`)
   without anyone incrementing a field.
6. Maintainers: when a legitimate transition has no packaged operation, expose
   one instead of leaving operators with manual edits as the only path —
   a missing packaged verification operation is precisely what made the
   synthetic attempt tempting.
7. Recovering from a discovered manual edit: do not finish or transfer the
   synthetic state. Preserve the source worktree and its ledger unchanged.
   The packaged re-review verification operation is not yet available; stop
   before trying to mark findings fixed or restore the Ship gate. See the
   same `ROADMAP.md` carry-forward row.

**Current status:** the linked re-review cannot currently be completed through
packaged operations. The source event, new-head review, and published wrapper
do not authorize writing `fixed`; preserve the source worktree and stop before
restoring the exact-head review gate. Resume only after that ROADMAP row's
operation is implemented.

## Why This Matters

An append-only sealed-events ledger exists to turn review outcomes into
auditable evidence rather than narrative. A synthetic result converts the
ledger back to narrative at exactly the point where trust matters most — the
gate between review and Ship — and it launders findings as `fixed` without
anyone verifying they are gone. The sibling failure classes are already
documented: a status claimed without the execution that produced it
(`structural-check-without-execution-evidence.md`) and a status label
requiring commit evidence rather than narrative
(`carry-forward-status-without-commit-evidence.md`). This doc covers their
ledger-shaped sibling: a review state claimed by hand instead of performed
through the operations that validate it.

## When to Apply

- Any run using the durable review event protocol — every unit review, fixer
  batch, and final or standalone review, in auto or interactive mode.
- Immediately after any fix commit during review: ask "which new event reviews
  the new head, and which packaged operation will write `fixed`?" If either
  answer is a hand edit, stop.
- When auditing or recovering a ledger: treat hand-edited rows as synthetic
  and rebuild, never grandfather them.

## Examples

The corrected chain as landed in the same cycle, verified from the run's
`progress.md` ledger and sealed wrapper files:

| Step | Result | Evidence |
|---|---|---|
| Source review | `final:auto-plan-assumption-tradeoffs:1` complete, `actionable`, head `8053816…`, two P1 fingerprints | event row; wrapper sealed, SHA-256 persisted |
| Synthetic clean result | rejected and discarded | Log `2026-09-19T15:18:06Z` |
| Source preserved | re-published `actionable` through the packaged publisher | same Log line |
| Linked re-review allocated | `final:auto-plan-assumption-tradeoffs:2`, `re_review_of=final:…:1`, head `b6e4182…` | event row |
| Wrapper published | verbatim clean body; SHA-256 recomputation matches the persisted digest | `reviews/events/final-review-2.md` header |
| Findings fixed | both fingerprints `fixed`, `introduced_by` the source event, `resolved_by` the re-review | finding-disposition rows |
| Gate set and verified | review gate = the re-review event at exactly `b6e4182…`; full validation green | Log `2026-09-19T15:19:29Z` |

**What the synthetic attempt skipped, mapped to its operation:** allocation
(new event bound to the new head), publication (create-once wrapper with
manifest-validated digest), verification (`re_review_of` linkage plus finding
absence before `fixed`), and the exact-head gate (clean event at the current
full HEAD). Each skip was replaced by the corresponding packaged operation in
the corrected chain — the durable lesson being to keep it that way: expose a
packaged verification operation for every legitimate transition, and manual
ledger edits have no path to authority.
