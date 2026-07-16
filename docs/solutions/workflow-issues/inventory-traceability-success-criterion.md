---
module: release-loop
date: "2026-07-16"
problem_type: workflow_issue
component: designing
severity: medium
symptoms:
  - "every declared success criterion passes at baseline while items from the source inventory are missing from the deliverable"
  - "content-fidelity drift surfaces only in a post-release audit, not in any pre-release check"
applies_when:
  - "a release's core deliverable is content derived from a source inventory (distillation, migration, port, consolidation)"
  - "the declared success criteria are exclusively structural (file exists / parses / loads in harness / emits contract line)"
  - "success criteria are being declared at design time for inventory-derived work"
root_cause: structural-only success criteria cannot detect content-fidelity drift
related_components:
  - retrospective
  - planning
tags:
  - success-criteria
  - traceability
  - distillation
  - drop-list
  - release-loop
---

## Context

v0.1 of this plugin authored 12 skills by distilling six source inventories.
All seven declared success criteria passed at baseline — and every one was
structural: files exist, JSON parses, frontmatter validates, the plugin loads
in the harness, the headless smoke emits its contract line. Meanwhile three
distilled mechanisms were silently missing from the authored skills:
planning's context-research step, scenario flow analysis, and debugging's
known-solution check against `docs/solutions/`.

The criteria could not have caught this by construction: structural checks
measure the presence and well-formedness of the artifact, not its fidelity to
the source it was derived from. The drift was caught only by a separate
post-release audit of the distillation drop-lists (commit `5d9da52`), which
judged every dropped item by "does any downstream mechanism check the gap
this leaves" and restored the three mechanisms. The audit worked — but it
existed as a rescue, not as a declared, pre-release criterion.

Sibling gap: `docs/solutions/workflow-issues/spec-review-empirical-grounding-gap.md`
covers a review that checks internal logic but never grounds a spec's
examples against the live repo. This doc covers the analogous gap between a
source inventory and the content authored from it. Both are scope gaps in a
verification pass, not rigor gaps.

## Guidance

When a release's core deliverable is content derived from a source inventory
(distillation, migration, port, consolidation), declare a **traceability
criterion** alongside the structural ones, at the time the success criteria
are declared:

> Every inventory item is present in the deliverable (cite the section that
> carries it) **or** on an explicit drop-list with a reason.

Make it a pre-release check, not a post-release rescue:

- The check is mechanical: walk the inventory item by item; each row either
  cites where the deliverable carries it or points at a drop-list entry with
  a reason. An item with neither is a failure.
- Judge drop-list entries by a reviewable rubric, not a feeling — v0.1's
  audit used "does any downstream mechanism check the gap this leaves."
- Commit the inventory and the drop-list before verification runs. In v0.1
  the inventories lived only in a session scratchpad for the whole release
  window, so the one artifact the audit depended on wasn't in git.

## Why This Matters

Presence checks and fidelity checks are different measurement classes. A
criteria set made entirely of structural checks can be green while the core
content silently loses items — adding more structural criteria never closes
this, because the gap is in the criteria set's scope, not its rigor or count.
The drop-list audit is the only place a silent omission is visible: an
omission, by definition, leaves no trace in the deliverable itself.

## When to Apply

At design time, whenever the deliverable is derived from an enumerable
source: skill or doc distillation from inventories, data and schema
migrations, code ports between languages or frameworks, doc consolidation,
config translations. If you can list the source items, you can declare
traceability over them — and if you can't list them, that absence is itself
worth surfacing before implementation starts.

## Examples

- v0.1 of this repo: seven structural criteria all passed while three
  mechanisms (planning context research, scenario flow analysis, debugging
  known-solution check) were missing; commit `5d9da52` restored them after a
  drop-list audit that a traceability criterion would have forced pre-release.
- Criterion shape to declare: "For each of the N inventory items: the
  deliverable section that carries it is cited, or a drop-list entry with a
  reason exists — verified as a table (or script) before release, zero
  unaccounted items."
