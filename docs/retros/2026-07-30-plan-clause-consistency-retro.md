# Retro: plan-clause-consistency

- Date: 2026-07-30
- Source: direct-to-main commit `ed427ee`
- Spec: none (inline design approval)
- Plan: none (skipped — two text edits across two skill files)

## Release data

| Metric | Value |
|---|---|
| **Changed non-test lines** | 2 (planning SKILL.md + implementing SKILL.md) + 1 (ROADMAP row closure) |
| Commits | 1 |
| Review rounds | 1 (self-review) |
| Comments (fixed / deferred) | 0 / 0 |
| CI failures | 0 |
| Duration (design → push) | ~3 minutes |
| Units planned / completed | n/a (no plan) |

## Success criteria: measured vs declared

(No spec exists — inline design. Measuring against the design's implicit criteria.)

| # | Declared criterion | Measurement (command / rubric) | Measured result | Verdict |
|---|---|---|---|---|
| 1 | Planning step 14 includes architecture-unit clause-consistency bullet | `grep 'Architecture-unit clause consistency' skills/planning/SKILL.md` | verified: bullet reads "diff every claim in the Architecture notes against the unit steps and interfaces that implement it" | Met |
| 2 | Implementing preflight step 3 includes Architecture notes in contradiction scan | `grep 'Architecture notes' skills/implementing/SKILL.md` | verified: step 3 now reads "contradict each other, a Global Constraint, or the plan's Architecture notes" | Met |
| 3 | validate.sh passes | `bash scripts/validate.sh` | verified: ALL CHECKS PASSED | Met |
| 4 | ROADMAP P3 row closed | `grep '~~Plan internal' ROADMAP.md` | verified: row strikethrough with **Done** marker | Met |

## Carry-forward from previous retro

| Item | Status | Evidence |
|---|---|---|
| (none — previous retro registered no carry-forward items) | — | — |

- Previous doc shape: conformant

## Interview Transcript

- Independence level: self-checklist
- Rounds used: 0 (headless mode — mechanical text edits per fired ROADMAP trigger)

| ID | Round | Phase | Probe | Answer | Evidence | Verdict (verbatim) |
|---|---|---|---|---|---|---|
| T1 | — | 3 | Does the planning step 14 bullet address the original F2 gap — architecture notes vs unit steps? | Yes — "diff every claim in the Architecture notes against the unit steps and interfaces that implement it" directly mandates the comparison that was missing when F2's contradiction survived | SKILL.md step 14 bullet text vs ROADMAP row description | self-attested |
| T2 | — | 3 | Does the implementing preflight expansion catch the same gap from the consumer side? | Yes — "or the plan's Architecture notes" adds Architecture notes to the contradiction scan that runs before Unit 1, catching plan-internal contradictions at execution time if they survived planning self-review | implementing SKILL.md:17 | self-attested |

## Findings

### What worked well

- **What happened**: This item had been "satisfied procedurally" four consecutive cycles — each plan review was manually instructed to diff architecture notes vs unit steps, and each time it found and fixed contradictions. The durable skill mandate makes the instruction permanent rather than requiring carry-forward-triggered re-injection.
  **Why**: The procedural satisfaction pattern proved the check is valuable (four real catches) while the absence of a durable mandate proved it was fragile (it required each cycle to re-discover the carry-forward row).
  **How to apply**: When a carry-forward item has been "satisfied procedurally" across 3+ cycles, that is strong evidence the mandate belongs in the skill prose, not just in ad-hoc instructions.
  **Cites**: T1; ROADMAP row history (4 consecutive firings, all procedurally satisfied).

### What to improve

- **What happened**: No findings to improve this cycle — the edits match the ROADMAP specification exactly.

### Process observations

- **What happened**: This row's trigger description ("fired third consecutive cycle... satisfied procedurally again... mechanical check still unbuilt") was semantically accurate but structurally misleading — "mechanical check" implied a validate.sh-style script check, when what was needed was a prose mandate in two skill files. The distinction matters: this is a human-executed check (the planner diffs notes vs steps while reviewing), not a machine-executed check (a script validates a file's structure).
  **Why**: The ROADMAP row inherited "mechanical check" language from the original retro's finding, which contrasted "prose-only" (the template's parenthetical) with "mechanical" (something that enforces). The terminology conflated automation with durability.
  **How to apply**: When registering a carry-forward item about missing enforcement, name what kind of enforcement: "durable skill mandate" for human-executed reviews, "validate.sh check" for machine-executed validation. Don't use "mechanical check" for both.
  **Cites**: ROADMAP row text vs actual deliverable.

## Carry-forward items registered

| Item | Type | Priority | Tracked at |
|---|---|---|---|
| (none this cycle) | — | — | — |

## Lessons

- When a carry-forward item has been "satisfied procedurally" across 3+ cycles, the evidence is sufficient to promote it to a durable skill mandate — the check has proven its value through repeated real catches, and the carry-forward mechanism is keeping it alive by friction rather than by design.

## Compounding

- not attempted — the lesson extends the carry-forward-tid-check retro's trigger-naming finding to a new dimension (enforcement-type naming)
