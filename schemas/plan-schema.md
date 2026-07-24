# Plan Schema

The contract between `planning` (producer) and `implementing` / `reviewing` (consumers). A plan is a **decision artifact, not an execution script**: consumers never edit the plan body; execution progress lives in commits and the progress ledger.

## File naming

`docs/plans/YYYY-MM-DD-NNN-<type>-<name>-plan.md` — `NNN` is a per-day sequence number (collision-safe), `<type>` matches the frontmatter `type`.

## Frontmatter (required unless marked optional)

```yaml
---
schema: plan/v1                   # contract version; consumers reject unknown versions
title: Human-readable plan title
type: feat | fix | refactor | chore | docs
status: draft | approved | in-progress | done | abandoned  # draft commits first; approved is a separate commit after the USER gate (skills/planning/SKILL.md)
date: YYYY-MM-DD
execution: code | non-code        # selects the unit template
origin: <path to spec>            # optional; enables retro's measured-vs-declared pass
deepened: true                    # optional; set by the deepening pass
---
```

## Document body — hard floor

1. **Goal** — 1–3 sentences, forward-looking.
2. **Architecture notes** — decisions + rationale; pseudo-code only as directional guidance, never implementation code.
3. **Assumption Recheck** — required whenever the plan is written. If the origin spec retains live assumptions, rerun every retained command and record the approved claim, fresh command evidence, and one outcome: `match`, `contradiction`, or `unavailable`. If the plan has no origin spec, write exactly: `No origin spec; no approved live assumptions to recheck.` If the origin spec exists but retains zero live assumptions, write exactly: `Origin spec retains no live assumptions; no assumption recheck required.` A contradiction blocks plan finalization and commit until a separate committed addendum exists under `docs/deviations/`; preserve the approved spec and plan unchanged and follow `docs/solutions/workflow-issues/review-introduced-state-machine-deviation.md` for the addendum's content contract. An unavailable result remains a planning-time unknown unless the user narrows the claim enough to remove the missing evidence.
4. **File structure** — files to create/modify, grouped by responsibility (single-responsibility files, colocate what changes together, follow the existing codebase's scale).
5. **Scenario coverage map** — one row per User Scenario (S-ID) in the origin spec: the ordered chain of units that realizes it end to end, and the scenario evidence that walks it — for code plans, integration test scenario(s) tagged `Covers S<n>`; for non-code plans, a named observable verification per scenario (e.g. "a reader following README.md alone completes S1"), since non-code units carry no test field. A scenario with neither a completing unit chain nor walking evidence is a plan gap that blocks approval — either add the missing unit or send the scenario back to `designing` for explicit descoping. When the origin spec has no User Scenarios section (or no spec exists), state that in this section explicitly — never leave it absent. The map is the durable traceability record downstream verification runs against (`enforces: P8`); the fresh verification itself happens in `implementing`'s final branch review and `reviewing`'s tests lane (`enforces: P3` there, not here).
6. **Implementation Units** (see below).
7. **Mutation/failure-state matrix** — conditional on the deliverable containing a stateful ceremony: a workflow whose deliverable can cross an observable side-effect boundary. A durable transition is a step that changes persisted or externally observable state across invocations. Include one row per durable transition with transition identity, pre-state, action, expected post-state, owning implementation unit, and the evidence owner that will produce disposable fixture evidence under `.release-loop/evidence/U<N>/`. Fill all six outcome classes: success; forced failure; rerun; rollback or compensation; headless; and cancellation or abort. Blank cells are invalid; every not-applicable cell must contain a concrete reason tied to the interface or irreversibility boundary. Forced-failure outcomes name a safe injection boundary and isolation approach; irreversible transitions name compensation or explicit manual recovery. Link `skills/planning/references/stateful-ceremony-matrix-example.md` and `docs/solutions/workflow-issues/review-introduced-state-machine-deviation.md` rather than duplicating their contracts. Changing an approved row or outcome is observable behavior and triggers item 1's deviation-addendum rule before release. When the deliverable has no stateful ceremony, write exactly: `No stateful ceremony in the deliverable; no mutation/failure-state matrix required.`
8. **Carry-forward trigger audit** — records the planning-time trigger audit: the classification of every open carry-forward tracker row's trigger — edit-based (fires on a named file or section being touched), drift-based (fires on a named record shape deviating), or event-based (fires on a future occurrence) — diffed against the plan's file list and observable record state. Three record shapes, lean by design: one row per fired trigger (tracker row, trigger class, what fired it, disposition with reason — "what fired it" is a deliberate one-field addition to spec R5's enumeration, approved with this plan); one row per unobservable drift-based trigger (tracker row, the named record, why it is not observable at planning time); and one always-present attestation line in the fixed template `Audited <tracker location> at <tracker state>: <N> open rows, <M> fired, <K> unobservable.` where tracker state is a commit or equivalent identifier. Fired includes latched rows: a firing already recorded in the tracker or a prior retro counts regardless of current observability. When no trigger fired and nothing is unobservable, the section is the attestation line alone. A fired trigger's disposition is fold-as-unit or a Deferred to Follow-Up Work entry naming the row and the reason; a fired row with neither blocks approval. When the repo has no durable tracker, write exactly: `No durable carry-forward tracker in this repo; no trigger audit possible.`
9. **Deferred to Follow-Up Work** — tangential discoveries and scope creep land here, never in units (`enforces: P4`).
10. **Open unknowns** — split into *planning-time* (must resolve before approving the plan) and *implementation-time* (deferred implementation notes: exact method names, final SQL, runtime-dependent behavior — resolved during execution, listed so they are not mistaken for gaps).

## Implementation Unit template

U-IDs are **stable and unique**: never renumbered on reorder, split, or delete (`U7` stays `U7`; a split yields `U7a`/`U7b`; a deleted unit's ID is never reused). A "Covers AE<n>" or "Covers S<n>" link naming an acceptance criterion or user scenario that does not exist in the spec is a validation error, not a soft warning.

### Code unit (`execution: code`)

```markdown
## U<N>: <unit title>
Execution note: test-first | characterization-first | skip-test-first
Files:
  Create: <paths>
  Modify: <paths>
  Test: <paths>
Interfaces:
  Consumes: <exact signatures / types this unit uses>
  Produces: <exact signatures / types this unit exposes>
Test scenarios:                     # categorized; link acceptance criteria as "Covers AE<n>",
                                    # user scenarios as "Covers S<n>" (integration scenarios
                                    # are derived from the spec's User Scenarios first)
  happy: <scenario>
  edge: <scenario>
  error: <scenario>
  integration: <scenario, "Covers S<n>" where it walks a user scenario, or "n/a — leaf unit">
Steps:                              # 2–5 minute literal steps; TDD baked in
  1. Write failing test <path>::<name> asserting <behavior>
  2. Run it; confirm it fails because <expected reason>
  3. Implement minimal code in <path>
  4. Run tests; confirm pass, no regressions
  5. Commit: "<message>"
Acceptance: <verifiable check(s) — command or observable behavior>
```

### Non-code unit (`execution: non-code`)

```markdown
## U<N>: <unit title>
Files:
  Create/Modify: <paths>
Steps:
  1. Write <artifact> covering <required content>
  2. Self-review against <spec section / checklist>
  3. Commit: "<message>"
Acceptance: <verifiable check(s)>
```

## Rules

- **No placeholders**: banned phrases include "TBD", "similar to Task N", "as appropriate", "etc." — every unit is self-contained because implementers may read units out of order and see only their own unit.
- **Right-sizing**: a unit is the smallest change worth a fresh reviewer's gate; 3–7 units is typical — >10 suggests under-decomposition, <3 suggests the plan may not be warranted at all.
- **Zero-context test**: an engineer with no codebase knowledge and only this unit's text can implement it.
- **Prose economy**: one idea per sentence; a requirement is intent plus at most one qualifier; forks go to Open unknowns, not both arms written out; resolve superseded text in place.
