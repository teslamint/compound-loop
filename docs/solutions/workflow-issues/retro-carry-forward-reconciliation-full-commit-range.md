---
module: retrospective
date: "2026-08-23"
problem_type: workflow_issue
component: carry-forward-reconciliation
severity: medium
symptoms:
  - "Retro reconciliation marks an event-triggered carry-forward item \"Not started\" even though the trigger fired"
  - "Respondent checks only whether the current session touched the trigger path"
  - "Shipping-gate or other trigger-path commits from prior unretro'd PRs get silently skipped"
root_cause: >-
  Two PRs (#17, #18) merged after the previous retro (2026-08-16) without a
  retrospective run, so the carry-forward event trigger fired twice with no
  reconciliation. The next retro scoped its check to the current session's diff
  instead of the full inter-retro window, missing commits 9e4ebd3 (F17) and
  f2efda9 (F18).
applies_when:
  - "Reconciling any carry-forward item whose trigger is phrased as \"next change to <path/area>\""
  - "More than one PR has merged since the prior retro"
  - "Verifying whether a stated trigger fired before accepting a respondent's self-assessment"
tags:
  - retrospective
  - carry-forward
  - reconciliation
  - commit-range
  - shipping-gates
---

# Reconcile carry-forward items against the full inter-retro commit range

## Context

During the v0.11.0 retrospective (2026-08-22), a carry-forward item from the prior retro (2026-08-16) was reconciled against the wrong commit range. The prior retro registered two carry-forward items; item 2's trigger was "next change to shipping or release-loop merge gates." Between the two retros, two PRs merged against the trigger path with no retro run in between:

- `9e4ebd3` — F17, pre-push base-topology gate
- `f2efda9` — F18, external review verification gate

Both touch `skills/shipping/SKILL.md`. The retro draft classified item 2 as "Not started — trigger has not fired" — false, because the respondent checked only the current session's commits. A fresh-context facilitator caught this while probing warrant W2 by running the inter-retro `git log` directly against the trigger path.

## Guidance

1. **Query the full inter-retro range, not the current session.** For any event-based carry-forward item with a trigger defined as "next change to `<path>`":

   ```bash
   git log --since=<prev-retro-date> -- <trigger-path>
   # or, if the prior retro's HEAD commit is known:
   git log <prev-retro-commit>..HEAD -- <trigger-path>
   ```

   Session-scoped recollection ("did I touch this file today?") is not a substitute for this query. Carry-forward items exist precisely because they span sessions.

2. **Invoke or explicitly defer retro after every PR merge.** If a merge lands and retro is not run immediately, the trigger fires silently and accumulates. When deferring, state the reason so the deferral is an auditable decision, not a gap.

3. **Score partial discharge as partial, not complete.** When a fired trigger only partially addresses the item's scope — here, F18 added artifact-level review inventory but not outside-diff finding inventory or a durable disposition requirement — record "In progress," not "Done" or "Not started." Re-arm the ROADMAP trigger for the undischarged remainder so the next retro checks the residual scope specifically.

## Why This Matters

A retrospective's carry-forward mechanism only works if triggers are evaluated against the interval they were designed to cover. Scoping the check to "this session" silently degrades an inter-retro trigger into a same-session trigger:

- False "Not started" classifications hide real progress and real gaps alike.
- Partially-addressed scope disappears entirely when misclassified — both "Done" and "Not started" drop the remaining work from tracking.
- The problem compounds silently across cycles: each un-invoked retro widens the range that must be reconciled later, and a same-session-only check keeps missing it.

The failure was caught only because a fresh-context facilitator re-probed a warrant instead of accepting the respondent's self-report. The correct check (full-range `git log`) should be applied by default, not held in reserve for probing.

## When to Apply

- Reconciling any carry-forward item whose trigger is phrased as "next change to `<path/area>`" against actual repository history.
- Writing or reviewing a retrospective when more than one PR has merged since the prior retro.
- Verifying whether a stated trigger fired, before accepting a respondent's or draft author's self-assessment.
- Deciding an item's disposition when a fix landed but only partially covered the stated scope — use "In progress" plus a re-armed, remainder-scoped trigger.

## Related

- [`carry-forward-trigger-planning-audit-gap.md`](carry-forward-trigger-planning-audit-gap.md) — establishes the trigger taxonomy (edit-based, drift-based, event-based); this doc extends the event-based class into inter-retro range detection.
- Retro evidence: `docs/retros/2026-08-22-v0.11.0-release-and-templates-retro.md` (T1–T4).
