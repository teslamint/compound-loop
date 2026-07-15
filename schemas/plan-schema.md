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
status: draft | approved | in-progress | done | abandoned
date: YYYY-MM-DD
execution: code | non-code        # selects the unit template
origin: <path to spec>            # optional; enables retro's measured-vs-declared pass
deepened: true                    # optional; set by the deepening pass
---
```

## Document body — hard floor

1. **Goal** — 1–3 sentences, forward-looking.
2. **Architecture notes** — decisions + rationale; pseudo-code only as directional guidance, never implementation code.
3. **File structure** — files to create/modify, grouped by responsibility (single-responsibility files, colocate what changes together, follow the existing codebase's scale).
4. **Implementation Units** (see below).
5. **Deferred to Follow-Up Work** — tangential discoveries and scope creep land here, never in units (`enforces: P4`).
6. **Open unknowns** — split into *planning-time* (must resolve before approving the plan) and *implementation-time* (deferred implementation notes: exact method names, final SQL, runtime-dependent behavior — resolved during execution, listed so they are not mistaken for gaps).

## Implementation Unit template

U-IDs are **stable and unique**: never renumbered on reorder, split, or delete (`U7` stays `U7`; a split yields `U7a`/`U7b`; a deleted unit's ID is never reused). A "Covers AE<n>" link naming an acceptance criterion that does not exist in the spec is a validation error, not a soft warning.

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
Test scenarios:                     # categorized; link acceptance criteria as "Covers AE<n>"
  happy: <scenario>
  edge: <scenario>
  error: <scenario>
  integration: <scenario or "n/a — leaf unit">
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
