---
schema: plan/v1
title: Remove EntireContext mentions from shipped skill surface and roadmap
type: docs
status: draft
date: 2026-07-20
execution: non-code
---

# Remove EntireContext mentions from shipped skill surface and roadmap

## Goal

Remove the EntireContext-specific references from the distributed plugin
surface (`skills/retrospective/SKILL.md`) and from `ROADMAP.md`'s Future
candidates table, so the shipped plugin names no third-party product or
foreign MCP tool a user may not have. Retrospective-time decision capture
remains available to EntireContext users through their own user-level
instructions, outside this plugin's contract.

## Architecture notes

- **Why removal, not generalization**: the mention names one specific
  external product and two of its MCP tools (`ec_decision_create`,
  `ec_lessons`). For users without that product it is a dangling reference;
  for users with it, user-level configuration (e.g. a global CLAUDE.md
  decision-capture section) already covers when to record decisions. The
  plugin gains nothing by carrying the pointer.
- **Drop, not defer**: the user decided EntireContext integration is out of
  plugin scope, not postponed. Therefore the `ROADMAP.md` Future candidates
  row "EntireContext hooks" is deleted rather than kept as a triggered
  candidate. No replacement carry-forward row is added.
- **What stays**: the product-neutral "Session-history search integration"
  bullet (`skills/retrospective/SKILL.md`) and its Future candidates row
  ("Session-history search") remain — they describe a pluggable capability,
  not a vendor. The "Out of Scope (v0.2 hook points — documented, not
  implemented)" heading stays accurate with one bullet and is not edited.
- **Approved artifacts untouched**: `docs/specs/2026-07-15-compound-loop-design.md`,
  `docs/plans/2026-07-15-001-feat-compound-loop-skills-plan.md`, and
  `docs/research/index.md` keep their EntireContext mentions — they are the
  provenance record of the original deferral decision and of the "EC" source
  distillation, and approved lifecycle artifacts are never rewritten.
- **Known Pattern**: `docs/solutions/` has no prior learning about removing
  shipped-doc content; the nearest analogue is the docs-type plan
  `docs/plans/2026-07-18-001-docs-approved-artifact-truth-maintenance-plan.md`
  (non-code execution, grep-verifiable acceptance), whose acceptance style
  this plan follows.
- **Single unit, below the smell-test floor**: on its own this change would
  qualify for planning's skip path (atomic, one commit). The plan exists
  because the user explicitly requested the plan → implement → release →
  retro cycle for it; the explicit ask overrides the skip heuristic.

## Assumption Recheck

No origin spec; no approved live assumptions to recheck.

## File structure

- `skills/retrospective/SKILL.md` — shipped skill surface; delete the
  EntireContext bullet from "Out of Scope (v0.2 hook points — documented,
  not implemented)".
- `ROADMAP.md` — durable tracker; delete the "EntireContext hooks" row from
  the Future candidates table.

Both edits express one decision (EntireContext is out of plugin scope) and
land in one commit.

## Scenario coverage map

No origin spec exists, so there is no User Scenarios section to map. The
observable verification standing in for scenario evidence: after U1, a
search for `entirecontext|ec_decision|ec_lessons` (case-insensitive) across
`skills/`, `schemas/`, `scripts/`, `README.md`, `CONCEPTS.md`, and
`ROADMAP.md` returns zero matches, while the provenance documents under
`docs/specs/`, `docs/plans/`, and `docs/research/` retain theirs.

## Implementation Units

## U1: Delete EntireContext references from SKILL.md and ROADMAP.md

Files:
  Create/Modify: `skills/retrospective/SKILL.md`, `ROADMAP.md`
Steps:
  1. In `skills/retrospective/SKILL.md`, delete the single bullet beginning
     `- **EntireContext hooks**:` from the section "Out of Scope (v0.2 hook
     points — documented, not implemented)". Leave the section heading and
     the "Session-history search integration" bullet byte-identical.
  2. In `ROADMAP.md`, delete the Future candidates table row whose Item
     cell is `EntireContext hooks`. Leave every other row — including
     "Session-history search" — byte-identical.
  3. Self-review: run
     `rg -in 'entirecontext|ec_decision|ec_lessons' skills schemas scripts README.md CONCEPTS.md ROADMAP.md`
     from the repo root and confirm zero matches; run the same pattern over
     `docs/` and confirm the remaining hits are only in `docs/specs/`,
     `docs/plans/`, and `docs/research/`.
  4. Run `bash scripts/validate.sh` and confirm it passes.
  5. Commit: "docs(skills): Remove EntireContext plugin references"
Acceptance: the two grep checks in step 3 hold exactly as stated, and
`bash scripts/validate.sh` exits 0 on the commit.

## Mutation/failure-state matrix

No stateful ceremony in the deliverable; no mutation/failure-state matrix
required.

## Deferred to Follow-Up Work

- User-level EntireContext decision-capture guidance already exists in the
  user's global instructions; no repo-side replacement document is created,
  and none is planned.

## Open unknowns

Planning-time: none — the one material fork (also removing the ROADMAP
Future candidates row) was resolved by the user before this plan was
finalized: remove it.

Implementation-time: none — both edits are literal single-line deletions
with no runtime-dependent behavior.
