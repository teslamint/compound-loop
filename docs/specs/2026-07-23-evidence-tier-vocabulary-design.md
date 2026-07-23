---
title: Evidence-Tier Vocabulary
status: draft
date: 2026-07-23
schema: spec/v1
---

# Evidence-Tier Vocabulary Design

_Created 2026-07-23._

## Overview

Adds a shared vocabulary for completion-evidence strength — a fixed ladder of
evidence tiers, a layer-mismatch rule, and a binary reporting form — defined
once in `CONCEPTS.md` and consumed as executable rules by `reviewing`,
`shipping`, and `retrospective`. Trigger evidence: the v0.1 release retro
(`docs/retros/2026-07-16-v0.1-release-retro.md`) recorded seven structural
success criteria passing while three distilled mechanisms were silently
missing — a completion claim verified at a lower layer than the requirement
lived at. Source inventory: `docs/research/ultraprompt-survey.md` import 2
(verification-discipline + honest-reporting).

## User Scenarios

### S1: Reviewer catches a layer-mismatch completion claim

A review lane inspects a diff whose PR body claims "feature complete" with
evidence `typecheck passed`. The requirement lives at the end-to-end layer.
Under R4 the lane files an actionable layer-mismatch finding; the envelope
verdict cannot be `clean` while it stands. Invocation: `/reviewing` (any
caller shape).

### S2: Shipping verification gate reports in binary form

`/shipping` Step 1 runs the full test suite and reports
`verified: pytest -q → 124 passed, 0 failed (integration tier)` — or, on a
missing suite, `unverified: no test suite exists; highest evidence is
typecheck (build tier)` and stops per the existing Iron Law. No "should
work", no "probably fine".

### S3: Retro measures a criterion and names the tier

`/retrospective` Phase 3 runs a declared proving command fresh and records
the Measured result cell as `verified: scripts/validate.sh → ALL CHECKS
PASSED` (or `unverified: <blocker>`), so a reader can judge evidence
strength from the doc alone.

### S4: Agent resolves the canonical meaning from CONCEPTS.md

Any agent or reader encountering "evidence tier" or "layer mismatch" in a
skill finds the single canonical definition in `CONCEPTS.md` — the skills
carry rules that use the terms, never a second definition (`enforces: P5`).

### S5: Unit-level evidence closes only the unit-level claim

An implementer finishes a unit with passing unit tests and claims the
feature done. Under R3 the unit tests close the unit's own claim; the
feature-level claim stays open until feature-layer evidence (end-to-end run
or the declared proving command) exists. `reviewing` treats the gap as S1's
finding class.

## Scope

### In

- New `## Completion evidence` section in `CONCEPTS.md` (definitions only).
- Executable-rule insertions in `skills/reviewing/SKILL.md`,
  `skills/shipping/references/verification.md` (+ a pointer in
  `skills/shipping/SKILL.md` Step 1 if wording requires),
  `skills/retrospective/SKILL.md` Phase 3.
- Guidance-prose update in `schemas/retro-template.md`'s measured-vs-declared
  section (example cell shows the binary form; table column shape unchanged).

### Out

- `debugging` as a consumer (already imported its own verification mechanisms
  2026-07-23; adding the ladder there is a future cycle).
- `designing` / `planning` / `implementing` consumption.
- Mechanical enforcement (a validator or hook that parses reports for the
  binary form) — documented convention, consistent with repo practice.
- Prose-wide language policing: the binary form binds only the structured
  points named in R7.
- Renaming or restructuring the existing claim→evidence table in
  `skills/shipping/references/verification.md` — it stays canonical for
  claim-to-command mapping; this spec only adds the tier/ladder layer.

## Assumptions and Preconditions

| Claim | Command | Observed at | Observed result | Evidence source |
|---|---|---|---|---|
| `CONCEPTS.md` exists with a `## Release verification` section (new section slots alongside) | `rg -n "^## " CONCEPTS.md` | 2026-07-23T12:41:00+0900 | 6 sections: Release verification, Release ceremony, Python compatibility, Retrospective interview, Session resilience, Metrics | Working tree @ `ee70f03` |
| `shipping`'s verification reference has a claim→evidence table and red-flag phrase list but no tier ladder or binary reporting form | `rg -n "tier\|ladder\|verified:" skills/shipping/references/verification.md` | 2026-07-23T12:45:00+0900 | No matches for tier/ladder/`verified:` | Working tree @ `ee70f03` |
| `reviewing` has no completion-evidence-strength vocabulary | `rg -n -i "evidence tier\|ladder\|layer" skills/reviewing/SKILL.md` | 2026-07-23T12:45:00+0900 | No matches | Working tree @ `ee70f03` |
| `retrospective` Phase 3 records measured results with no binary form | `rg -n "verified" skills/retrospective/SKILL.md` | 2026-07-23T12:45:00+0900 | No `verified:`/`unverified:` form; Phase 3 says "Record the measured result next to the declared target" | Working tree @ `ee70f03` |
| `scripts/validate.sh` check 9 inspects only interview-transcript vocabulary in `schemas/retro-template.md`, not the measured-vs-declared table | `sed -n 280,340p scripts/validate.sh` | 2026-07-23T12:47:52+0900 | Check 9 parses `## Interview Transcript`, `- Independence level:`, `Verdict cell values:` lines only | Working tree @ `ee70f03` |

## Architecture

`CONCEPTS.md` is the single definition sink; the three consumer skills carry
only rules that reference the terms by canonical name (approved dialogue
decision: "definitions in CONCEPTS.md, rules in skill bodies"). Data flow
across the lifecycle: `designing` declares success criteria (each implies a
claim layer) → `reviewing` gates verdicts on layer match → `shipping` gates
the verification report form → `retrospective` records measured results in
the same form. No skill re-defines a term.

## Requirements

Grouped by concern; stable R-IDs.

### Vocabulary (CONCEPTS.md)

- **R1**: `CONCEPTS.md` gains a `## Completion evidence` section defining
  exactly these terms: **Evidence tier**, **Evidence-tier ladder**, **Claim
  layer**, **Layer-mismatch**, **Binary completion report**. Definitions stay
  conceptual per the file's own header rule — no file paths or skill names.
- **R2**: The ladder's fixed descending order is:
  failing-repro-now-passing > end-to-end run > integration test > unit test >
  typecheck/build. The definition states that typecheck/build alone never
  closes a completion claim.
- **R3**: Layer-mismatch is defined as: a completion claim is closed only by
  evidence at or above the layer the claim lives at; unit-level evidence
  closes only a unit-level claim.

### Consumption (rules in skill bodies)

- **R4**: `reviewing` gains a rule (alongside the existing Requirements
  Completeness rule in Step 8): a completion claim whose best evidence sits
  below the claim's layer is an actionable layer-mismatch finding, and the
  verdict cannot be `clean` while it stands (approved dialogue decision).
- **R5**: `shipping`'s `references/verification.md` gains the evidence-tier
  ladder and the binary completion report form; the Step 1 verification-gate
  report and every claim in the claim→evidence table's scope use
  `verified: <observation>` / `unverified: <blocker>`, naming the evidence
  tier where a tier applies. The existing Iron Law, gate function, and
  red-flag list are unchanged — the ladder layers on top.
- **R6**: `retrospective` Phase 3 records each Measured result cell in the
  binary form; `schemas/retro-template.md`'s measured-vs-declared example row
  shows it. Table column shape is unchanged.
- **R7**: The binary form is mandatory only at structured outputs — the three
  points named in R4–R6 (review verdict evidence, shipping verification-gate
  report, retro measured-result cells) — never a prose-wide language rule
  (approved dialogue decision).

## Testing

Structural + judgment, matching the repo's docs-only change conventions
(no test suite; `scripts/validate.sh` is the mechanical layer):

- `bash scripts/validate.sh` → ALL CHECKS PASSED (guards check 9 against the
  retro-template edit).
- Grep checks per success criterion below (section presence, ladder order,
  consumer references).
- Judgment rubric: a reader following any consumer rule can resolve every
  term to exactly one CONCEPTS.md definition; no consumer re-defines a term.

## Risks

- **Vocabulary drift between CONCEPTS.md and skill rules** — mitigated by the
  definitions-in-one-place split (R1 vs R4–R6) and the traceability criterion
  (SC6).
- **Over-constraining review**: the layer-mismatch gate could be read as
  demanding top-tier evidence everywhere — mitigated by R3's wording
  ("at or above the layer the claim lives at"): layer-appropriate evidence is
  sufficient; the ladder ranks strength, it does not set a floor.
- **retro-template edit breaking validate.sh check 9** — pre-verified: check 9
  parses only interview-transcript vocabulary (see Assumptions); still gated
  by running validate.sh fresh.
- **Terms colliding with existing "Structural criterion" family** — the new
  section describes evidence for completion claims, the existing one
  describes criterion kinds for inventory-derived deliverables; definitions
  are written to cross-reference nothing and overlap nowhere.

## Success Criteria

1. `CONCEPTS.md` contains a `## Completion evidence` section defining the
   five R1 terms.
   - **Measured by**: `rg -n "^## Completion evidence" CONCEPTS.md && rg -c "Evidence tier|Evidence-tier ladder|Claim layer|Layer-mismatch|Binary completion report" CONCEPTS.md` — section heading present, all five terms matched.
2. The ladder appears in the exact declared order with the typecheck rule.
   - **Measured by**: `rg -n "failing-repro-now-passing" CONCEPTS.md` — the match line lists the five tiers in R2's order and the section states typecheck/build alone never closes a completion claim (read the section).
3. Each consumer carries an executable rule referencing the canonical terms.
   - **Measured by**: `rg -l "layer-mismatch|Layer-mismatch" skills/reviewing/SKILL.md && rg -l "evidence-tier ladder|Evidence-tier ladder" skills/shipping/references/verification.md && rg -l "verified:" skills/retrospective/SKILL.md` — all three files match.
4. `reviewing`'s rule blocks `clean` on a standing layer-mismatch finding.
   - **Measured by**: judgment rubric — read the added rule in `skills/reviewing/SKILL.md`; pass = it states the verdict cannot be `clean` while the finding stands, in the same normative shape as the Requirements Completeness rule.
5. The binary form binds only the three structured points, not prose.
   - **Measured by**: judgment rubric — read R4–R6's landed rules; pass = each names its structured output point and no rule extends the form to general prose.
6. Traceability: every source-inventory mechanism from
   `docs/research/ultraprompt-survey.md` import 2 (ladder order,
   typecheck-never-closes, layer-mismatch/unit-closes-unit, binary reporting
   language, three named consumers) is present in the deliverable with a
   citation, or on an explicit drop-list with a reason.
   - **Measured by**: judgment rubric — walk the survey's import-2 sentence clause by clause against the landed diff; pass = zero silent omissions.
7. Structural validation passes on the final tree.
   - **Measured by**: `bash scripts/validate.sh` → `ALL CHECKS PASSED`.

## Open Decisions

- Whether `debugging` later consumes the ladder (its 2026-07-23 import
  covered hypothesis discipline, not completion evidence). Owner: a future
  design cycle, triggered by the first debugging completion claim that would
  have been caught by the ladder. Deliberately out of scope here.
