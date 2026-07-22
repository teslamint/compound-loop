---
module: release-loop
date: "2026-07-22"
problem_type: workflow_issue
component: designing
severity: medium
applies_when:
  - "a spec states a universal invariant over a class of artifacts (\"every persisted packet\", \"all consumers\", \"each transition\")"
  - "the same spec's Scope or Requirements sections carve the work to a subset of that class"
  - "reviews validate implementation-against-spec without checking the spec's universal claims against its own scope sections"
related_components:
  - reviewing
  - planning
tags:
  - spec-review
  - invariants
  - scope
  - release-loop
---

## Context

The final-action-session-resilience spec (2026-07-22) declared a universal
invariant in its Architecture section: a non-authorization marker rides
"every persisted command packet." The same spec's R7 and Scope-In rows
confined the `release` skill's change to the interactive path, and the plan's
U4 step 4 explicitly froze the Headless boundary section. Result: the
headless-path `.release/draft.md` — one instance of "every persisted packet"
— shipped without an in-file marker, in full compliance with the plan.

The inconsistency survived three review layers — spec self-review,
independent spec review, and independent plan review — because each validated
artifacts *against* the spec. None checked the spec's universal claims
against the spec's own scope sections. The first reader to hold the
Architecture invariant against the frozen headless section was the U4 task
reviewer (finding U4-m1, triaged carry-with-registration by the final branch
review; retro T2).

## Guidance

When a spec states an "every X" / "all X" / "each X" invariant:

1. Enumerate the X instances explicitly in the spec — list the concrete
   packets, consumers, transitions, or files the class contains.
2. Mark each instance **covered** (a requirement realizes the invariant
   there) or **excepted** (deliberately out of scope, with the reason).
3. Point reviews at the enumeration: the reviewer verifies every instance is
   marked and every "covered" mark has a realizing requirement — the
   adjective ("every") is never itself the thing reviewed.

An unenumerated universal invariant plus a scope section is a silent
exception generator: Scope-In/Out and per-requirement wording will carve
instances out of the class without anyone deciding that exception on
purpose.

## Why This Matters

Compliance-shaped review layers all inherit the spec's blind spot: an
implementation can be simultaneously fully plan-compliant and
invariant-violating when the spec disagrees with itself. The defect class is
invisible exactly to the reviews most likely to run (artifact-vs-spec), and
surfaces only when someone reads the invariant against a section the plan
froze — which this cycle happened one layer before merge, by luck of a
thorough task reviewer.

## When to Apply

- Writing or reviewing any spec whose Architecture/Design section uses
  universal quantifiers over artifact classes.
- Spec self-review (the contradiction-in-one-pass test): grep the draft for
  "every ", "all ", "each " and check each hit against Scope-In/Out.
- Independent spec review: add "universal claims vs own scope sections" as an
  internal-consistency check distinct from artifact-vs-spec compliance.

## Examples

From the originating cycle: Architecture said the marker rides every
persisted packet; the enumerable instances were (1) `progress.md`
`final_action` record, (2) standalone shipping handoff file, (3) interactive
`.release/draft.md`, (4) headless `.release/draft.md`. R7 covered 1–3;
instance 4 was silently excepted by Scope-In's "interactive path" wording.
An enumeration with covered/excepted marks would have forced the exception
to be decided (extend the marker to the headless write, or scope the
invariant) at design time instead of discovered at U4 task review.
