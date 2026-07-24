---
schema: plan/v1
title: Planning-time carry-forward trigger audit
type: feat
status: approved
date: 2026-07-24
execution: non-code
origin: docs/specs/2026-07-24-planning-trigger-audit-design.md
---

# Planning-Time Carry-Forward Trigger Audit — Implementation Plan

## Goal

Land the trigger-audit vocabulary in `CONCEPTS.md`, the durable audit-section
contract in `schemas/plan-schema.md`, and the audit procedure (with latching,
tiebreak, unclassifiable fallback, extended self-review, and reviewer mandate)
in `skills/planning/SKILL.md`, per spec R1–R6 and R2a.

## Architecture notes

- **P5 split with the spec's gloss carve-out**: `CONCEPTS.md` (U1) is the only
  file carrying the bolded-term definitional bullet form (`- **term** — ...`).
  U2 and U3 cite the terms with a parenthetical gloss attached to each term's
  first use in a rule sentence — reproducing enough meaning to be applied
  literally without `CONCEPTS.md` present. This inline-gloss reproduction is
  spec-mandated (Architecture gloss boundary), not a restatement of the
  definitional form; the exactly-once criterion (SC1) binds the bullet form,
  not the glosses.
- **No step renumbering in the planning skill**: U3 inserts the audit as step
  `5a` between File structure (5) and Deliverable-type gate (6). The skill body
  cross-references step numbers at lines 13, 77, 86, 92, 94, 98, 117, 134
  (verified via `rg -n "step [0-9]+" skills/planning/SKILL.md`, independent
  review re-run at `f6bceaf`); renumbering 6–18 would touch all of them for
  zero behavior gain.
- **Contained renumbering in plan-schema**: U2 inserts the audit section as
  hard-floor item 8, shifting Deferred to Follow-Up Work to 9 and Open unknowns
  to 10. Hard-floor items carry no stable IDs (spec R5); the two shifted
  sections are referenced elsewhere by name, never by number (an existing
  numeric reference, "item 1's deviation-addendum rule", points at an unshifted
  item and appears stale independently of this change — see Deferred).
- **Lean audit record**: three record shapes only — fired row, unobservable
  row, and the always-present fixed-template attestation line. Fired includes
  latched rows (a recorded firing never un-fires when the drifted record is
  archived or reset).

## Assumption Recheck

All five retained commands rerun fresh at 2026-07-24T18:35:37+0900 against
working tree `29602c5`:

| Approved claim | Fresh evidence | Outcome |
|---|---|---|
| Planning's existing carryover check is feature-relevance-only, one line | `rg -n "Retro carryover" skills/planning/SKILL.md` → single hit, line 137, same sentence | match |
| Deferred to Follow-Up Work is item 8 of the plan-schema hard floor | `rg -n "Deferred to Follow-Up Work" schemas/plan-schema.md` → single hit, line 33, numbered `8.` | match |
| This repo's tracker rows carry trigger conditions in a named column | `rg -n "Trigger / next step" ROADMAP.md` → single hit, line 42 | match |
| No skill or schema file mentions a trigger audit yet | `rg -ln -e "trigger audit" -e "trigger-audit" skills/ schemas/` → no matches | match |
| CONCEPTS.md exists and defines no trigger-class terms | `rg -n -e "edit-based" -e "drift-based" -e "event-based" CONCEPTS.md` → no matches | match |

## File structure

| File | Change | Owner unit |
|---|---|---|
| `CONCEPTS.md` | Add "Carry-forward triggers" section: four definitional bullets | U1 |
| `schemas/plan-schema.md` | Insert hard-floor item 8 "Carry-forward trigger audit"; renumber 8→9, 9→10 | U2 |
| `skills/planning/SKILL.md` | Insert step 5a (audit procedure + reviewer mandate); extend step 14 Retro carryover bullet | U3 |
| `docs/plans/2026-07-24-001-feat-planning-trigger-audit-plan.md` | This plan (carries the first executed audit section below) | — |

## Scenario coverage map

| S-ID | Unit chain | Observable verification |
|---|---|---|
| S1 (edit-based fire → disposition) | U1 → U2 → U3 | This plan's audit section rows 45/48 (real edit-based firings with dispositions); a reader executing U3's step 5a text against ROADMAP.md's current table reproduces the same fired set |
| S2 (no-fire attestation) | U2 → U3 | U2's schema text fixes the attestation template; reviewer applies the template to a hypothetical plan touching only `README.md` and confirms the section reduces to one decidable line |
| S3 (drift fire + latching) | U1 → U2 → U3 | This plan's audit section rows 55 (tracker-annotation arm) and 47/54 (prior-retro-reconciliation arm): fired via recorded firing while the live tree shows no fresh fire — the latching clause in U3's text and U1's trigger-audit definition both name this outcome |
| S4 (reviewer re-derives) | U3 | The independent review of this plan is dispatched with the re-derive instruction (R6) and reports its own tracker-vs-file-list diff, not a trust-the-section check |
| S5 (no durable tracker) | U2 | `rg -n -F "No durable carry-forward tracker" schemas/plan-schema.md` hits the exact fallback line after U2 |

## Implementation Units

## U1: Define carry-forward trigger vocabulary in CONCEPTS.md

Files:
  Create/Modify: CONCEPTS.md
Steps:
  1. Insert a new `## Carry-forward triggers` section between `## Completion evidence` and `## Metrics` (chronological-adjacency precedent: Completion evidence was itself inserted before Metrics in the previous cycle). Write exactly four definitional bullets in the file's established form (`- **term** — definition`), conceptual only, no file paths:
     - **Edit-based trigger** — a carry-forward trigger that fires when a named file or section is touched by planned or actual work; detected by diffing a plan's file list against the trigger's named targets.
     - **Drift-based trigger** — a carry-forward trigger that fires when a named record shape or observable state deviates from its contract; detected by inspecting the named record where observable.
     - **Event-based trigger** — a carry-forward trigger that fires on a future occurrence rather than a file edit or record shape (a new install, an external report, the next cycle of a named kind); detected by judgment, not diffing.
     - **Trigger audit** — the planning-time act of classifying every open carry-forward row's trigger into exactly one class and diffing the fireable classes against the plan's file list and observable record state. A fired trigger demands a recorded disposition, and a recorded firing latches: archiving or resetting the drifted record never un-fires a row.
  2. Self-review against spec R1 and the file's header rule ("definitions stay conceptual — no implementation specifics, status, or links"); confirm no other section renumbering or reflow occurred.
  3. Commit: "docs(concepts): Define carry-forward trigger vocabulary"
Acceptance: each of `rg -ci -F "**edit-based trigger**" CONCEPTS.md`, `rg -ci -F "**drift-based trigger**" CONCEPTS.md`, `rg -ci -F "**event-based trigger**" CONCEPTS.md`, `rg -ci -F "**trigger audit**" CONCEPTS.md` returns exactly 1. **File-convention adaptation of spec SC1**: CONCEPTS.md's definitional bullets capitalize the term's first letter (`- **Backfill**`, `- **Claim layer**`), so all four bullets land with a capitalized first letter (`**Edit-based trigger**`, `**Drift-based trigger**`, `**Event-based trigger**`, `**Trigger audit**`) and SC1's case-sensitive commands are measured with `-i` added — same adaptation class as the previous cycle's `→`→`->` (recorded here so the retro measures the adapted command, not a false fail). `bash scripts/validate.sh` → ALL CHECKS PASSED.

## U2: Add the Carry-forward trigger audit hard-floor section to plan-schema

Files:
  Create/Modify: schemas/plan-schema.md
Steps:
  1. In "Document body — hard floor", insert a new item 8 titled **Carry-forward trigger audit** immediately before Deferred to Follow-Up Work, and renumber the two following items (Deferred to Follow-Up Work 8→9, Open unknowns 9→10). The new item's text states, in this order:
     - The section records the planning-time trigger audit (the classification of every open carry-forward tracker row's trigger — edit-based (fires on a named file or section being touched), drift-based (fires on a named record shape deviating), or event-based (fires on a future occurrence) — diffed against the plan's file list and observable record state).
     - Three record shapes, lean by design: one row per fired trigger (tracker row, trigger class, what fired it, disposition with reason — "what fired it" is a deliberate one-field addition to spec R5's enumeration, approved with this plan); one row per unobservable drift-based trigger (tracker row, the named record, why it is not observable at planning time); and one always-present attestation line in the fixed template `Audited <tracker location> at <tracker state>: <N> open rows, <M> fired, <K> unobservable.` where tracker state is a commit or equivalent identifier.
     - Fired includes latched rows: a firing already recorded in the tracker or a prior retro counts regardless of current observability.
     - When no trigger fired and nothing is unobservable, the section is the attestation line alone.
     - A fired trigger's disposition is fold-as-unit or a Deferred to Follow-Up Work entry naming the row and the reason; a fired row with neither blocks approval.
     - When the repo has no durable tracker, write exactly: `No durable carry-forward tracker in this repo; no trigger audit possible.`
  2. Self-review against spec R5: three record shapes present, template byte-exact, fallback line byte-exact, hard-floor numbering contiguous 1–10.
  3. Commit: "feat(planning): Add carry-forward trigger audit section to plan schema"
Acceptance: `rg -n "Carry-forward trigger audit" schemas/plan-schema.md` hits the hard-floor list; `rg -n -F "No durable carry-forward tracker" schemas/plan-schema.md` and `rg -n -F "Audited <tracker location>" schemas/plan-schema.md` each hit exactly once; `awk '/^## Document body/,/^## Implementation Unit/' schemas/plan-schema.md | grep -c '^[0-9]*\.'` returns 10; `bash scripts/validate.sh` → ALL CHECKS PASSED.

## U3: Add the audit procedure, reviewer mandate, and extended self-review to the planning skill

Files:
  Create/Modify: skills/planning/SKILL.md
Steps:
  1. Insert a new section `## 5a. Carry-forward trigger audit` between `## 5. File structure` and `## 6. Deliverable-type gate` (no renumbering of any existing step). Its text instructs, in this order:
     - When the File structure section is written, list every open row in the durable tracker (ROADMAP, issue tracker, or equivalent — the same tracker `retrospective` pushes carry-forward items to) and classify each row's trigger into exactly one class: edit-based (names a file or section whose touch fires it), drift-based (names a record shape or observable state whose deviation fires it), or event-based (names a future occurrence).
     - Tiebreak: a trigger naming both a file condition and an event resolves to edit-based — the mechanically checkable reading wins.
     - Read recorded fired-state annotations first (latching): a row whose firing is already recorded in the tracker or a prior retro counts as fired regardless of current observability — an archived or reset record does not un-fire it.
     - Diff edit-based triggers against the planned file list; check each drift-based trigger's named record where observable at planning time. An unobservable record is recorded as unobservable in the audit section — never given an invented verdict. A row with no classifiable trigger condition is recorded as unclassifiable and handled under the event-based feature-relevance question, never silently skipped.
     - Every fired trigger gets a disposition in the same planning pass: fold the row in as a unit, or add a Deferred to Follow-Up Work entry naming the row and the reason. Silence on a fired trigger is a plan gap that blocks approval.
     - Record the result in the plan's Carry-forward trigger audit section per `schemas/plan-schema.md` — fired rows, unobservable rows, and the attestation line.
     - Reviewer mandate: any independent plan review re-derives this audit — open tracker rows versus the plan's File structure and the audit section's dispositions — rather than trusting the section's claims; an omitted fired row is a blocking finding. Whoever composes a plan-review dispatch prompt carries this re-derive instruction into the prompt verbatim, so the mandate travels with the dispatch.
  2. In step 14 self-review, replace the "Retro carryover" bullet with an extended version: re-run the step 5a trigger audit against the **final** file list (deepening and unit edits are the likeliest divergence vector), confirm the attestation line still names the tracker state actually examined, and keep the feature-relevance question ("does this item belong in this plan?") for event-based triggers only.
  3. Self-review against spec R2, R2a, R3, R4, R6: all three classes glossed at first use, tiebreak present, latching present, unobservable and unclassifiable fallbacks present, disposition rule names both arms and the blocking consequence, dispatch-prompt clause present; confirm no existing step number or cross-reference changed (`git diff` shows only the 5a insertion and the step 14 bullet).
  4. Commit: "feat(planning): Add carry-forward trigger audit step and reviewer mandate"
Acceptance: `rg -n -e "edit-based" -e "drift-based" -e "event-based" skills/planning/SKILL.md` hits only inside step 5a and the step 14 bullet; `rg -n "fired" skills/planning/SKILL.md` shows the disposition sentence naming both arms and blocking; `rg -n -e "final file list" -e "re-derive" skills/planning/SKILL.md` shows both; `rg -n "Retro carryover" skills/planning/SKILL.md` still returns exactly one hit (the extended bullet); `bash scripts/validate.sh` → ALL CHECKS PASSED.

## Mutation/failure-state matrix

No stateful ceremony in the deliverable; no mutation/failure-state matrix required.

## Carry-forward trigger audit

First executed audit (dogfood, spec SC6), placed per the U2 contract
(immediately before Deferred to Follow-Up Work). Classification per spec
R2/R2a against the File structure table above, the live
`.release-loop/progress.md`, and each row's recorded fired-state annotations.
The table's "Fired by" column is an intentional superset of spec R5's
fired-row fields (tracker row, trigger class, disposition, reason) — recorded
here and in U2 as a deliberate contract addition, not drift.

| Tracker row (ROADMAP.md line) | Class | Fired by | Disposition |
|---|---|---|---|
| Automated numbered-reference validation for planning and plan schema (45) | edit-based | U3 inserts a numbered planning step (5a); U2 inserts a plan-schema hard-floor item — both named insertion conditions hold | Deferred with reason (see Deferred to Follow-Up Work) |
| Carry-forward check structural assertion (47) | event-based | Latching rule, prior-retro arm: the 2026-07-24 retro's reconciliation records "trigger fired under the strict reading" (`503da9b` edited `schemas/retro-template.md`), unconsumed by any disposition | Deferred with reason (see Deferred to Follow-Up Work) |
| Plan internal clause-consistency check (48) | edit-based | U3 edits `skills/planning/SKILL.md` self-review — the row's named edit condition | Deferred with reason; satisfied procedurally this cycle: the plan-review dispatch prompt carries the mandated architecture-notes-vs-unit-steps diff |
| Define hand-up packet in shipping SKILL (54) | edit-based | Latching rule, prior-retro arm: the 2026-07-24 retro's reconciliation records "trigger fired unnoticed" (`2299955` edited `skills/shipping/SKILL.md`), unconsumed; no fresh fire this cycle | Deferred with reason (see Deferred to Follow-Up Work) |
| Mechanical validate.sh check for `final_action` shape (55) | drift-based | Latching rule, tracker arm: tracker-annotated **fired** (second consecutive cycle); the drifted record now lives only in `.release-loop/archive/2026-07-23-evidence-tier-vocabulary/progress.md` — archival does not un-fire the row | Deferred with reason (see Deferred to Follow-Up Work) |
| Planning-time trigger audit (56) | event-based | The named occurrence — "next planning cycle (any plan with a File structure section)" — is this plan | Folded: this entire plan (U1–U3) |
| Spec-level carve-out rule (58) | event-based | The named occurrence — a designing cycle whose spec pairs a universal principle with a mandating requirement — is this cycle's spec (gloss boundary vs R2 literal executability) | Deferred with reason; handled procedurally in the origin spec (explicit gloss-boundary carve-out sentence) |

Audited ROADMAP.md carry-forward table at 29602c5: 15 open rows, 7 fired, 0 unobservable.

## Deferred to Follow-Up Work

- **ROADMAP row 45 (automated numbered-reference validation)** — trigger fired
  (U2/U3 perform exactly the named insertions). Deferred: the approved spec's
  scope is three files with no `scripts/validate.sh` changes, and the user
  explicitly deferred mechanical checks this cycle on the trigger-to-build
  pattern. The firing itself is recorded here so the row latches; U2 and U3
  carry manual numbering acceptance checks in its place this cycle.
- **ROADMAP row 47 (carry-forward check structural assertion)** — fired via
  latching, prior-retro arm (the 2026-07-24 retro's reconciliation records the
  strict-reading firing by `503da9b`, unconsumed). Deferred:
  `schemas/retro-template.md` and validate.sh check 9 are outside the approved
  spec's file set; the row's own trigger text routes it to a retro-template or
  check-9 design cycle, which this is not.
- **ROADMAP row 48 (plan internal clause-consistency check)** — trigger fired
  (U3 edits the planning self-review). Deferred: the row's resolution needs its
  own design fork (procedural self-review bullet vs mechanical check) that this
  cycle's spec did not adjudicate; the defect class is covered procedurally
  this cycle by the mandated clause-diff in the plan-review dispatch prompt.
- **ROADMAP row 54 (define hand-up packet in shipping SKILL)** — fired via
  latching, prior-retro arm (the 2026-07-24 retro's reconciliation records the
  unnoticed firing by `2299955`, unconsumed). Deferred:
  `skills/shipping/SKILL.md` is outside the approved spec's file set; the P4
  one-sentence definition remains the natural fold for the next cycle that
  edits that file.
- **ROADMAP row 55 (mechanical validate.sh check for final_action shape)** —
  fired via latching (tracker-annotated, second consecutive cycle). Deferred:
  `scripts/validate.sh` is outside the approved spec scope; the row is now
  twice-carried and is the natural first candidate for the next
  validate.sh-touching cycle.
- **ROADMAP row 58 (spec-level carve-out rule)** — trigger fired (this cycle's
  spec paired a universal principle with a mandating requirement). Deferred:
  the durable rule belongs in `designing`'s skill text, outside this spec's
  approved file set; this cycle satisfied it procedurally with an explicit
  in-spec carve-out sentence.
- **Retrospective-side trigger classification rule** — spec Out; owner: this
  cycle's `retrospective` phase (register as carry-forward or record why not).
- **Mechanical validate.sh check for the audit section itself** — spec Out;
  build on first observed omission of the section in a real plan
  (trigger-to-build).
- **Stale numeric cross-reference discovered by review**:
  `schemas/plan-schema.md:32` and `skills/planning/SKILL.md:106` cite "item
  1's deviation-addendum rule", but the deviation-addendum rule lives in
  hard-floor item 3 (Assumption Recheck) — pre-existing defect, outside this
  plan's scope; candidate carry-forward row for this cycle's retro.

## Open unknowns

**Planning-time**: none.

**Implementation-time** (deferred by design):
- Exact gloss phrasings in U2/U3 prose beyond the terms' first-use
  parentheticals specified above.
- Exact insertion line numbers (the anchors are section headings, stable
  against upstream drift).

## Verification summary

Per-unit acceptance commands above; branch-level: SC1 per U1's recorded
case-adaptation (`-i` added), SC2–SC5 commands as written in the spec, SC6 by
reviewer rubric against this plan's audit section, SC7
`bash scripts/validate.sh` → ALL CHECKS PASSED.
