---
schema: plan/v1
title: Diff-size Metric Reconciliation
type: chore
status: approved
date: 2026-07-20
execution: non-code
---

1. **Goal** — Reconcile the diff-size metric across reviewing and retrospective phases to use a single canonical metric ("Changed non-test lines") to prevent silent mixing of figures in lane-trigger decisions.
2. **Architecture notes** — Define the canonical metric in CONCEPTS.md. Update `retrospective` and `reviewing` references to strictly cite this metric name. Remove the tech debt item from ROADMAP.md.
3. **Assumption Recheck** — No origin spec; no approved live assumptions to recheck.
4. **File structure** — 
   Modify:
   - CONCEPTS.md
   - skills/reviewing/references/lanes.md
   - skills/retrospective/SKILL.md
   - ROADMAP.md
5. **Scenario coverage map** — No origin spec; no User Scenarios section.
6. **Implementation Units** (see below).
7. **Mutation/failure-state matrix** — No stateful ceremony in the deliverable; no mutation/failure-state matrix required.
8. **Deferred to Follow-Up Work** — None.
9. **Open unknowns** — None.

## U1: Define Metric in CONCEPTS.md
Files:
  Create/Modify: CONCEPTS.md
Steps:
  1. Write a new entry in `CONCEPTS.md` under a new `## Metrics` section for `Changed non-test lines`. Define it as "The count of modified lines excluding tests, generated files, and lockfiles, used as the canonical diff-size metric across all phases (e.g. lane triggers)."
  2. Self-review against the defined concept.
  3. Commit: "docs: define Changed non-test lines metric in CONCEPTS"
Acceptance: CONCEPTS.md contains the explicit definition for `Changed non-test lines`.

## U2: Align Reviewing and Retrospective Skills
Files:
  Create/Modify: 
    - skills/reviewing/references/lanes.md
    - skills/retrospective/SKILL.md
Steps:
  1. Modify `skills/reviewing/references/lanes.md` to explicitly capitalize and cite the `Changed non-test lines` concept for its trigger threshold.
  2. Modify `skills/retrospective/SKILL.md` to replace ambiguous "code delta split product/test/docs" references with the explicit `Changed non-test lines` metric in the Git/PR metrics section.
  3. Self-review against the file modifications.
  4. Commit: "chore(skills): align diff-size metric references to Changed non-test lines"
Acceptance: Both skill files use the exact term `Changed non-test lines`.

## U3: Resolve Roadmap Carry-forward
Files:
  Create/Modify: ROADMAP.md
Steps:
  1. Remove the row for "Diff-size metric reconciliation" from the "Carry-forward from retros" table in `ROADMAP.md`.
  2. Self-review against the change.
  3. Commit: "chore: resolve Diff-size metric reconciliation tech debt"
Acceptance: ROADMAP.md no longer contains the Diff-size metric reconciliation item.
