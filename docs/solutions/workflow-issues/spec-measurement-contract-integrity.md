---
module: release-loop
date: 2026-08-25
problem_type: workflow_issue
component: spec-measurement-contract
severity: medium
applies_when:
  - "A spec declares test case names as success criterion measurements"
  - "A fault injection is designed to exercise a specific recovery path"
  - "A retro measures success criteria against the actual test suite"
tags:
  - spec-plan-traceability
  - fault-injection
  - measurement-contract
  - retro
related_components:
  - designing
  - planning
  - retrospective
---

# Spec Measurement Contract Integrity

## Context

A design spec declared eight success criteria. Two of them — SC3 and SC4 — named
specific test case functions as their measurement method:
`legacy_handoff_source_changed` and `legacy_handoff_complete_rerun`. The
implementation plan's test scenario list carried only one test case per criterion
instead of both. The review round did not cross-reference every spec-declared test
name against the plan's scenario list.

Separately, the legacy handoff code used a fault injection point
(`handoff-after-copy-one`) that interrupted after copying one top-level child.
When the first child was a single file (`progress.md`), the injection never
created partial-directory state. A P0 data-loss bug in the resume logic — where
partially-copied directories were skipped because the pending list deduplicated
by top-level child name — passed the full test suite undetected.

## Guidance

**Spec-test binding**: when a spec names a test case as a measurement, that name
is a binding contract. The named case must exist in the test suite at retro time.
At the planning stage, cross-reference every spec "Measured by" test case name
against the plan's test scenario list. Flag any spec-named test missing from the
plan. At the review stage, verify each declared measurement name resolves to an
executable test.

**Injection granularity**: a fault injection point's granularity must match the
recovery unit's granularity. If the recovery logic operates at file level inside
directories, the injection must be able to interrupt mid-directory-copy, not only
between top-level children. Design injection points by asking: "what is the
smallest unit the recovery code distinguishes?" and place at least one injection
boundary at that unit.

## Why This Matters

A criterion whose measurement does not exist is unverifiable — it cannot score
Met regardless of whether the implementation handles the scenario correctly. In
this session, the implementation handled both SC3 and SC4 scenarios correctly
(manifest SHA-256 recheck; marker idempotency), but both scored Partially Met
because the named test cases were never created.

A coarse injection that passes all tests gives false confidence. The test suite
becomes a gate that certifies recovery without ever creating the
recovery-triggering state. The P0 bug was caught by code review, not by the
test suite.

## When to Apply

- Writing a spec that names test cases, fixture names, or commands as
  measurements.
- Writing a plan from a spec that declares named measurements.
- Reviewing a plan for spec coverage before approval.
- Running a retro's Phase 3 (measured vs declared) pass.
- Designing fault injection points for state-recovery code.
- Adding new recovery granularity without updating injection points.

## Examples

**Spec-test binding**: spec
`docs/specs/2026-08-25-legacy-handoff-contract-design.md` declared SC3 measured
by `legacy_handoff_incomplete_rerun && legacy_handoff_source_changed`. The plan's
U1 test scenarios listed `legacy_handoff_incomplete_rerun` but not
`legacy_handoff_source_changed`. The plan was approved without catching the
omission. At retro, `rg legacy_handoff_source_changed` returned zero matches,
forcing a Partially Met verdict.

**Injection granularity**: `handoff-after-copy-one` interrupts after
`shutil.copytree` completes for the first top-level child. When `progress.md` (a
file) copies first, no directory is ever partially copied. The test
`legacy_handoff_incomplete_rerun` verified that resume copies the remaining
children but never exercised partial-directory state. The P0 fix (commit
`100dea5`) added 3-way copy logic plus post-transfer manifest verification. The
retro registered carry-forward item: add `handoff-after-copy-one-file` injection
to exercise partial-directory recovery.

See also: `spec-review-empirical-grounding-gap.md` (spec review lacking empirical
evidence — adjacent but distinct failure mode).
