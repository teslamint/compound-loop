---
schema: plan/v1
title: Evidence-Tier Vocabulary
type: feat
status: approved
date: 2026-07-23
execution: non-code
origin: docs/specs/2026-07-23-evidence-tier-vocabulary-design.md
---

# Evidence-Tier Vocabulary Plan

## Goal

Define the completion-evidence vocabulary (evidence-tier ladder, layer-mismatch
rule, binary completion report) once in `CONCEPTS.md`, and land one executable
rule in each consumer — `reviewing`, `shipping`'s verification reference, and
`retrospective` with its template — so a completion claim verified below its
requirement's layer can no longer pass review, ship, or retro unlabeled.

## Architecture notes

- **Definitions in one place, rules in consumers** (approved dialogue
  decision). `CONCEPTS.md` carries the five term *definitions*; each consumer
  carries only normative sentences that use the terms by canonical name.
  One R5-mandated carve-out: `skills/shipping/references/verification.md`
  reproduces the ladder's *order* as operational rule content — the skills
  ship as a plugin without this repo's `CONCEPTS.md`, so the shipped rule must
  execute standalone; the definitional bullet form of the five terms still
  lives only in `CONCEPTS.md` (P5).
- **Rule placement mirrors existing structures.** The reviewing rule lands in
  Step 8 (Output) beside the Requirements Completeness rule, in its normative
  shape ("the finding stays actionable and the verdict cannot be `clean`").
  The shipping additions land inside `references/verification.md` as new
  subsections; `skills/shipping/SKILL.md` Step 1's existing pointer sentence
  gains two list items ("the evidence-tier ladder, the binary completion
  report form") — no structural change. The retrospective rule lands in
  Phase 3's numbered list; the template change edits only the example row's
  Measured result cell plus its lead-in prose.
- **Binary form scope is enumerated, not implied** (approved dialogue
  decision + Known Pattern below): every rule sentence names its exact
  surface — review verdict evidence, shipping Step 1 gate report and formally
  reported claim→evidence rows, retro Measured result cells — and U2–U4 each
  state the form does not bind surrounding prose.
- **No skill-file renumbering.** All edits land inside existing sections;
  existing step/phase numbers in all edited files stay untouched.
- **Known Pattern**: `docs/solutions/workflow-issues/universal-invariant-scope-enumeration-gap.md`
  — R7's "structured outputs only" is a scoped invariant; each unit enumerates
  the surfaces it binds rather than stating a universal.
- **Known Pattern**: `docs/solutions/workflow-issues/structural-check-without-execution-evidence.md`
  — every acceptance check below is a command to execute or a rubric with a
  named reader, never an unexecuted claim.
- **Known Pattern**: `docs/solutions/workflow-issues/numbered-planning-step-reference-drift.md`
  — no renumbering of existing numbered steps/phases in consumer files.
- **Known Pattern**: `docs/solutions/workflow-issues/inventory-traceability-success-criterion.md`
  — spec SC6 is the traceability criterion; the final branch review walks the
  survey import-2 clauses against the landed diff.

## Assumption Recheck

Origin spec retains five live assumptions; all rerun fresh at
2026-07-23T13:28:34+0900 against the working tree at `36a32b2`:

| Approved claim | Fresh evidence | Outcome |
|---|---|---|
| `CONCEPTS.md` has a `## Release verification` section; new section slots alongside | `rg -n "^## " CONCEPTS.md` → 6 sections (Release verification … Metrics) | match |
| `verification.md` has no tier ladder or binary form | `rg -n -e "tier" -e "ladder" -e "verified:" skills/shipping/references/verification.md` → no matches (exit 1) | match |
| `reviewing` has no completion-evidence vocabulary; sole ladder/tier hits are dispatch/model concerns | `rg -n -i -e "evidence tier" -e "ladder" -e "layer" skills/reviewing/SKILL.md` → one match, line 65 (Degradation ladder / Model tiering) | match |
| `retrospective` Phase 3 has no binary form | `rg -n "verified" skills/retrospective/SKILL.md` → no matches (exit 1) | match |
| validate.sh check 9 parses only interview-transcript vocabulary of `schemas/retro-template.md` | full check 9 body (lines 280–398, end of file) reread at 2026-07-23T13:33:33+0900: `awk '/^# 9\./,0' scripts/validate.sh \| rg -n "measured"` → no matches (exit 1); 7 interview-vocabulary references (`Interview Transcript`, `Independence level`, `Verdict cell`) | match |

## File structure

| File | Responsibility |
|---|---|
| `CONCEPTS.md` | five canonical definitions (U1) |
| `skills/reviewing/SKILL.md` | layer-mismatch verdict rule in Step 8 (U2) |
| `skills/shipping/references/verification.md` + `skills/shipping/SKILL.md` | ladder + binary form subsections; Step 1 pointer extension (U3) |
| `skills/retrospective/SKILL.md` + `schemas/retro-template.md` | Phase 3 binary-form rule; template example row (U4) |

## Scenario coverage map

| S-ID | Unit chain | Observable verification |
|---|---|---|
| S1 reviewer catches layer-mismatch | U1 → U2 | rubric: a reader of Step 8 alone determines that a typecheck-backed end-to-end claim yields an actionable finding and blocks `clean`; `rg -n "layer-mismatch" skills/reviewing/SKILL.md` non-empty |
| S2 shipping gate reports in binary form | U1 → U3 | rubric: a reader of verification.md alone produces `verified:`/`unverified:` report lines with a tier name for the Step 1 gate; `rg -n "verified:" skills/shipping/references/verification.md` non-empty |
| S3 retro measures and names the tier | U1 → U4 | rubric: a reader of Phase 3 + the template example row alone fills a Measured result cell in binary form, tier-free where no tier applies; `rg -n "verified:" schemas/retro-template.md` non-empty |
| S4 canonical meaning resolves from CONCEPTS.md | U1 → U2 → U3 → U4 | `rg -l -e '\*\*Evidence tier\*\* —' -e '\*\*Evidence-tier ladder\*\* —' -e '\*\*Claim layer\*\* —' -e '\*\*Layer-mismatch\*\* —' -e '\*\*Binary completion report\*\* —' CONCEPTS.md skills/ schemas/` → exactly `CONCEPTS.md` (the definitional bullet form appears nowhere else; U3's ladder-order reproduction is rule content per the Architecture-notes carve-out, not the bullet form) |
| S5 unit evidence closes only unit claim | U1 → U2 | rubric: CONCEPTS.md layer-mismatch definition states unit-level evidence closes only a unit-level claim; Step 8 rule covers the S5 gap as S1's finding class |

## Implementation Units

## U1: CONCEPTS.md `## Completion evidence` section

Files:
  Create/Modify: CONCEPTS.md
Steps:
  1. Add a `## Completion evidence` section after `## Session resilience` (before `## Metrics`), defining exactly five terms as definition-list bullets in the file's existing style (`- **Term** — definition.`):
     - **Evidence tier** — a named strength level of completion evidence; the position a proving observation occupies on the evidence-tier ladder.
     - **Evidence-tier ladder** — the fixed descending order of completion-evidence strength: failing-repro-now-passing > end-to-end run > integration test > unit test > typecheck/build. Typecheck/build alone never closes a completion claim. The ladder ranks strength where tiers apply; evidence that fits no tier (for example, a structural validation run proving a docs-only change) is cited tier-free, never forced into a tier label.
     - **Claim layer** — the layer a completion claim lives at, implied by the requirement or success criterion it answers (unit, integration, end-to-end).
     - **Layer-mismatch** — a completion claim whose best evidence sits below the claim's layer. A claim is closed only by evidence at or above its layer; unit-level evidence closes only a unit-level claim.
     - **Binary completion report** — the two-valued reporting form for completion claims at structured outputs: `verified: <observation>` or `unverified: <blocker>`, with no hedged middle state. For rubric-measured checks it reports evidence acquisition (the rubric was applied, reading cited), not the judgment itself.
  2. Keep definitions conceptual per the file's header rule — no implementation specifics, status, or links; no file paths.
  3. Self-review against spec R1–R3: five terms present, ladder order exact, typecheck rule stated, tier-free rule stated, unit-closes-unit stated.
  4. Commit: "docs(concepts): Define completion-evidence vocabulary"
Acceptance: `rg -n "^## Completion evidence" CONCEPTS.md` non-empty; `rg -o -e "Evidence tier\b" -e "Evidence-tier ladder" -e "Claim layer" -e "Layer-mismatch" -e "Binary completion report" CONCEPTS.md | sort -u | wc -l` ≥ 5; reviewer reads the section and confirms R2's exact ladder order and the typecheck-never-closes sentence; `bash scripts/validate.sh` → ALL CHECKS PASSED.

## U2: Reviewing layer-mismatch verdict rule

Files:
  Create/Modify: skills/reviewing/SKILL.md
Steps:
  1. In Step 8 (Output), directly after the "Stateful ceremony evidence gate" paragraph, add a "Layer-mismatch rule" paragraph: a completion claim in the reviewed material whose best evidence sits below the claim's layer (see `CONCEPTS.md`: evidence-tier ladder, layer-mismatch) is an actionable layer-mismatch finding, and the verdict cannot be `clean` while it stands. When no spec criterion or requirement implies a claim layer, the mismatch test is undecidable — file an unverifiable-claim finding naming the missing layer instead. Layer-mismatch findings pass through the normal Suppression Policy like any lane finding, with no special exemption.
  2. State in the same paragraph that the rule binds findings and verdicts (structured output), not the reviewer's surrounding prose.
  3. Self-review against spec R4 and S1/S5: rule shape matches the Requirements Completeness rule's normative form; no existing step numbers changed.
  4. Commit: "feat(reviewing): Block clean verdicts on layer-mismatch completion claims"
Acceptance: `rg -n -i "layer-mismatch" skills/reviewing/SKILL.md` matches in Step 8; reviewer confirms the paragraph states the verdict cannot be `clean` while the finding stands, the undecidable-layer fallback, and the suppression pass-through; `bash scripts/validate.sh` → ALL CHECKS PASSED.

## U3: Shipping evidence-tier ladder and binary report form

Files:
  Create/Modify: skills/shipping/references/verification.md, skills/shipping/SKILL.md
Steps:
  1. In `references/verification.md`, after "The gate function" section, add an "Evidence-tier ladder" section: reproduce the ladder's fixed descending order (failing-repro-now-passing > end-to-end run > integration test > unit test > typecheck/build) with a pointer that canonical definitions live in the repo-root `CONCEPTS.md` when present; state that typecheck/build alone never closes a completion claim and that evidence fitting no tier is cited tier-free.
  2. In the same file, add a "Binary completion report" section: the Step 1 verification-gate report and the evidence cited for a claim→evidence table row, when that claim is formally reported, use exactly `verified: <observation>` or `unverified: <blocker>`, naming the evidence tier where one applies. Conversational narration elsewhere in shipping (Steps 4/6/7) stays governed by the existing red-flag list only. Include one example of each form (e.g. `verified: pytest -q → 124 passed, 0 failed (integration tier)` / `unverified: no test suite exists; highest evidence is typecheck (build tier)`).
  3. Leave the Iron Law, gate function, claim→evidence table, red-flag list, rationalization table, and red-green protocol byte-identical.
  4. In `skills/shipping/SKILL.md` Step 1, extend the existing "See `references/verification.md` for …" sentence with "the evidence-tier ladder, the binary completion report form" — no other change.
  5. Self-review against spec R5/R7 and S2: both new sections enumerate their binding surfaces; no prose-wide extension.
  6. Commit: "feat(shipping): Add evidence-tier ladder and binary completion report to verification reference"
Acceptance: `rg -n "failing-repro-now-passing" skills/shipping/references/verification.md` non-empty; `rg -n "verified:" skills/shipping/references/verification.md` non-empty; `rg -n "evidence-tier" skills/shipping/SKILL.md` matches in Step 1; reviewer confirms pre-existing sections are unchanged (`git diff` shows only additions outside them); `bash scripts/validate.sh` → ALL CHECKS PASSED.

## U4: Retrospective binary measured-result form

Files:
  Create/Modify: skills/retrospective/SKILL.md, schemas/retro-template.md
Steps:
  1. In `skills/retrospective/SKILL.md` Phase 3, extend numbered item 3 (record the measured result): the Measured result cell uses the binary completion report form — `verified: <observation>` (naming the evidence tier where one applies; tier-free otherwise) or `unverified: <why the measurement could not run>`. For rubric-measured criteria the form reports evidence acquisition (`verified: <rubric applied, reading cited>`), never the judgment: the Verdict cell keeps Met / Partially met / Not met, and a `verified:` result can still carry Partially met or Not met; `unverified:` is never recorded as Met. The form binds Measured result cells only, not the doc's narrative prose.
  2. In `schemas/retro-template.md`, change the measured-vs-declared example row's Measured result cell from `<output summary>` to `verified: <observation> / unverified: <blocker>` and add one lead-in sentence naming the binary form and the rubric-measured meaning. Column count and headers stay unchanged; the `## Interview Transcript` section is untouched.
  3. Preserve each file's existing tri-state casing exactly as found (the skill file capitalizes "Partially Met / Not Met", the template uses "Partially met / Not met") — casing normalization is an out-of-scope edit.
  4. Write the SC6 traceability walk to `.release-loop/reports/traceability.md`: one row per `docs/research/ultraprompt-survey.md` import-2 clause — ladder order, typecheck-never-closes, layer-mismatch/unit-closes-unit, binary reporting language, hedges-banned, three named consumers — citing the landed `file:line` (hedges-banned cites `skills/shipping/references/verification.md`'s unchanged red-flag list) or an explicit drop reason. Zero silent omissions.
  5. Self-review against spec R6/R7 and S3: tri-state Verdict preserved; table shape unchanged; transcript vocabulary untouched.
  6. Commit: "feat(retrospective): Record measured results in binary completion form"
Acceptance: `rg -n "verified:" skills/retrospective/SKILL.md` matches in Phase 3; `rg -n "verified:" schemas/retro-template.md` matches in the measured-vs-declared section; `rg -c "Met / Partially met / Not met" schemas/retro-template.md` ≥ 1 (tri-state preserved, template casing); `.release-loop/reports/traceability.md` exists with all six clause rows, each citing a landed location or drop reason (reviewer walks it against the diff); `bash scripts/validate.sh` → ALL CHECKS PASSED (check 9 guards the transcript section).

## Mutation/failure-state matrix

No stateful ceremony in the deliverable; no mutation/failure-state matrix required.

## Deferred to Follow-Up Work

- `debugging` as a ladder consumer (spec Open Decision; trigger: first
  debugging completion claim the ladder would have caught).
- Mechanical enforcement of the binary form (validator/hook parsing reports)
  — spec Scope Out; documented convention for now.
- `designing`/`planning`/`implementing` consumption — spec Scope Out.

## Open unknowns

**Planning-time**: none — all five spec assumptions rerun `match`; rule
placements verified against current file structure.

**Implementation-time**:
- Exact sentence wording of each rule paragraph (units fix content and
  placement; final phrasing is the implementer's, held to the spec's R-IDs).
- Whether U3's Step 1 pointer extension reads better as one list item or two
  — resolved at edit time; either satisfies the acceptance check.
