---
name: retrospective
description: Measure outcomes against declared success criteria, reconcile carry-forward items, extract lessons, and feed the knowledge-compounding loop. Use via /retrospective (Claude Code) or $retrospective (Codex) after a PR merges, at the end of a session or debugging arc, on direct request ("run a retro", "retrospective on this"), or when release-loop's Retro phase fires.
---

# Retrospective

Standalone and callable from anywhere in the loop. Measures declared success criteria against reality, closes the carry-forward loop, and hands reusable lessons to `compound` — a step no source system closed end-to-end.

## Entry / Exit / Gate

- **Entry**: a merged PR, a finished session or debugging arc, or direct invocation.
- **Exit**: retro doc committed to git at `docs/retros/YYYY-MM-DD-<context>-retro.md`.
- **Gate**: AUTO — no human approval required to write or commit a retro.

## Phase 1: Scope & Mode Detection

Classify the source before collecting anything:

| Mode | Trigger |
|---|---|
| PR-merge | invoked after `shipping` merges, or a PR number is given |
| session-end | invoked at the close of a session with no PR (design/planning/debugging-only arc) |
| ad-hoc | direct invocation with a named topic, no PR or session boundary |

Check for `mode:headless` in arguments. In headless mode: no blocking questions, ambiguity resolves to the conservative default (see Phase 3/4), and the run ends with the exact terminal signal line from `schemas/headless-contract.md` — never an improvised variant.

## Phase 2: Collect Data

Gather what's available; degrade gracefully rather than blocking on a missing source.

- **Git/PR metrics** (PR-merge mode): code delta split product/test/docs by path, commit count, review rounds, comments fixed/deferred, CI failures, duration from first spec commit to merge, units planned vs. completed. Shape per `schemas/retro-template.md`'s Release data table.
- **Session-history search** (session-end mode, no PR): a pluggable capability, not a hard dependency — if a session-search tool is available, use it with a tight payload (topic, time window, one filter rule); if unavailable, skip and note the gap in the doc rather than blocking.
- **Origin artifact**: read the plan's `origin:` frontmatter field (`schemas/plan-schema.md`) to locate the spec. If no plan exists, check for a spec path directly. Read that spec's `## Success Criteria` section verbatim (`skills/designing/references/spec-template.md` shape: statement + `Measured by`).

## Phase 3: Measured vs. Declared (core)

For each criterion in the spec's Success Criteria section:

1. Identify the proving command or judgment rubric exactly as declared — do not paraphrase it into something easier to run.
2. **Run the command fresh, in this execution.** A prior claim in a commit message, PR body, or earlier retro is not evidence. `enforces: P3`
3. Record the measured result next to the declared target and classify **Met / Partially Met / Not Met**, with the gap stated explicitly for anything short of Met.

One row per criterion — vague summarization across criteria is banned. **If no spec exists, state that explicitly in the doc and skip this section.** Never reconstruct success criteria after the fact from what was actually built; a criterion invented post-hoc is not a measurement, it's a rationalization.

## Phase 4: Carry-Forward Reconciliation

Read the previous retro doc (most recent under `docs/retros/`), if any. For every item it registered, verify status now — Done / In progress / Not started — citing the commit, PR, or file that proves it. An item from the previous retro that goes unmentioned here is a silent drop, which is itself a defect to report.

Register this cycle's new carry-forward items: type (architecture / performance / feature / edge-case / process) × priority (P1–P4). Push every item to a durable tracker (ROADMAP, issue tracker, or equivalent) — **never PR comments alone**, which are lost after merge.

## Interview Protocol (governs Phases 4–5)

The narrative half of a retro is where self-assessment bias lives: the agent that did the work grades its own work. Split the roles (`enforces: P3` — self-reports are not evidence):

- **Facilitator** — an independent agent with fresh context. Receives only artifacts (spec, plan, progress ledger, PR data, Phase 2–3 outputs), never the working conversation. Asks evidence-demanding probes from `references/interview-probes.md` and **rejects vague answers** ("mostly fine", "went well") by re-asking for the commit, measurement, or concrete event — an unevidenced answer cannot become a finding.
- **Respondent** — the agent that did the work (the main session, or in standalone runs whoever holds the context), answering from its record.

**Facilitator model selection**: fresh context is the minimum; a *heterogeneous* model is better when the environment offers one (from Claude Code, `codex exec` for a GPT-family facilitator; from Codex, a Claude subagent) — shared model biases produce shared blind spots, so heterogeneity adds a defense self-review cannot. Degrade per `references/dispatch-degradation.md` (plugin root): heterogeneous facilitator → same-model independent-context subagent → sequential passes (facilitator pass generates probes from artifacts, respondent pass answers, facilitator pass critiques the evidence) → headless/single-agent: skip the interview and run the probe list as a fixed self-checklist. `enforces: P9`

Cap the exchange at 5 rounds; the facilitator's accepted answers become the raw material for Phase 5's findings. Data collection (Phase 2) and measurement (Phase 3) are never interviewed — they are commands, not narratives (`enforces: P4`).

## Phase 5: Findings & Lessons

Findings use the three-part shape — **What happened / Why / How to apply** — bucketed into What Worked Well, What to Improve, Process Observations. Every finding cites something specific (a PR comment, a CI run, a review round); "tests caught bugs" is too vague, "the branch-level review caught the commit-threading bug that per-task review missed" is the bar. Never frame an acted-on review finding as "noise" or "trivial" — if it was worth fixing, it was legitimate.

Distill the most important findings into **lessons**: quotable one-liners that are specific, evidence-backed, actionable, and **surprising** — "testing is good" does not qualify.

## Phase 6: Write the Retro Doc

Write `docs/retros/YYYY-MM-DD-<context>-retro.md` following `schemas/retro-template.md` exactly — section order, table shapes, and the measured-vs-declared table are the contract other tooling may parse later. Do not invent additional top-level sections.

## Phase 7: Headless Compound Invocation

After writing the doc, invoke `compound` in `mode:headless` **only when at least one finding reaches reusable-lesson quality** — specific, surprising, and actionable enough to help a future occurrence, not every retro produces one. Skip the invocation silently (note "not attempted — no reusable lesson this cycle" in the doc's Compounding section) when nothing qualifies; do not force a thin doc into existence to satisfy this phase.

When invoked, pass the qualifying finding as context and expect `compound`'s exact terminal signal (`Documentation complete — <path>` / `Documentation skipped — <reason>` / `Documentation failed — <reason>`, per `schemas/headless-contract.md`). Surface whichever line `compound` returned in this retro's Compounding section — do not paraphrase it.

## Phase 8: Commit & Report

Commit the retro doc (and any durable-tracker updates from Phase 4) as its own commit, separate from other work in flight. Report what was measured, what carried forward, and what — if anything — was compounded.

End every invocation with the exact terminal signal line from `schemas/headless-contract.md`:
`Retrospective complete — <path>` on success, `Retrospective skipped — <reason>` when no retro was warranted (e.g. nothing to measure and no session content), or `Retrospective failed — <reason>` on failure. This line is the last non-empty line of the report in every mode, not only headless.

## Handoff

`compound` is the only skill invoked from inside `retrospective`, and only per Phase 7's gate. Nothing invokes `retrospective` automatically — `release-loop`'s Retro phase and direct user invocation are the only callers.

## Out of Scope (v0.2 hook points — documented, not implemented)

- **Session-history search integration**: Phase 2 names it as pluggable; the concrete search tool and dispatch payload discipline are deferred to v0.2.
