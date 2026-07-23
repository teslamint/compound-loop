# ultraprompt survey (2026-07-23)

Source: <https://github.com/rlaope/ultraprompt> (surveyed at 14 stars, last updated 2026-07-23).

## What it is

Twelve "strategy axis" skills distilled from Claude Fable 5 reasoning traces, published as a
Claude Code plugin. Axes are orthogonal to lifecycle phases: exploration-strategy,
hypothesis-management, verification-discipline, tradeoff-articulation, failure-mode-enumeration,
self-correction-loop, spec-to-code-fidelity, incremental-safety, plus four candidates
(state-probing, honest-reporting, context-memory-hygiene, delegation-parallelism). Every skill
follows a fixed template: When to apply / Core loop / Heuristics / Anti-patterns / Worked
example / Trace evidence. A meta-protocol (`_SIMULATION.md`) governs authoring: skills are born
as `v0.1 baseline draft` and are promoted only when a real session trace lands an evidence row
in the skill's `CASES.md` naming which section the trace confirmed, contradicted, or refined.

## Credibility caveat

At survey time every skill was `v0.1 baseline draft` with zero real trace-evidence rows — the
repo's own promotion gate has never fired. Its content is well-constructed prompt engineering,
not validated data; numeric heuristics ("run the race N ≥ 5 times", "~15-minute environment
time-box") are author intuition.

## Ideas imported into compound-loop

1. **Hypothesis kill criteria + predict-before-probe + boring hypothesis** (from
   hypothesis-management) — applied directly to `skills/debugging/SKILL.md` Phase 2 on
   2026-07-23. Three mechanisms compound-loop's debugging lacked: a kill criterion stated per
   hypothesis before probing, per-probe predicted outcomes committed before execution (anchoring
   guard), and a standing "boring" hypothesis (stale build / wrong env / bad data / misread
   symptom) kept live beyond Phase 1's one-time environment sanity check.
2. **Evidence-tier ladder** (from verification-discipline + honest-reporting) — descending
   completion-evidence strength: failing-repro-now-passing > end-to-end run > integration test >
   unit test > typecheck/build; typecheck alone never supports a completion claim; a unit test
   only closes a unit-level claim (layer-mismatch rule); reporting language is binary
   (`verified: <observation>` / `unverified: <blocker>`), hedges like "should work" banned.
   Registered in ROADMAP Future candidates.
3. **Skill-level trace evidence** (from `_SIMULATION.md` + `CASES.md` shape) — a structured
   channel recording which *skill section* a real session confirmed, contradicted, or refined,
   feeding compound-refresh. compound-loop retros currently route lessons to docs/solutions/ and
   ROADMAP but have no per-skill-section evidence channel. Registered in ROADMAP Future
   candidates.
4. **Distinctness rule / absorb-over-add** — a proposed new skill must show evidence distinct
   from every existing skill or be absorbed into the nearest one; complements trigger-to-build
   (which decides *when*; this decides *whether*). Registered in ROADMAP Future candidates.

## Explicitly not imported

- Wholesale strategy-axis skills: they overlap harness system prompts and global rules, and sit
  outside compound-loop's lifecycle scope (non-goals spirit).
- The template's fixed anti-pattern/worked-example sections as a compound-loop authoring
  requirement — line-budget cost not justified without evidence of need.
