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

- **Git/PR metrics** (PR-merge mode): **Changed non-test lines**, commit count, review rounds, comments fixed/deferred, CI failures, duration from first spec commit to merge, units planned vs. completed. Shape per `schemas/retro-template.md`'s Release data table.
- **Session-history search** (session-end mode, no PR): a pluggable capability, not a hard dependency — if a session-search tool is available, use it with a tight payload (topic, time window, one filter rule); if unavailable, skip and note the gap in the doc rather than blocking.
- **Origin artifact**: read the plan's `origin:` frontmatter field (`schemas/plan-schema.md`) to locate the spec. If no plan exists, check for a spec path directly. Read that spec's `## Success Criteria` section verbatim (`skills/designing/references/spec-template.md` shape: statement + `Measured by`).

## Phase 3: Measured vs. Declared (core)

For each criterion in the spec's Success Criteria section:

1. Identify the proving command or judgment rubric exactly as declared — do not paraphrase it into something easier to run.
2. **Run the command fresh, in this execution.** A prior claim in a commit message, PR body, or earlier retro is not evidence. `enforces: P3`
3. Record the measured result next to the declared target and classify **Met / Partially Met / Not Met**, with the gap stated explicitly for anything short of Met. The Measured result cell uses the binary completion report form — `verified: <observation>` (naming the evidence tier where one applies; tier-free otherwise) or `unverified: <why the measurement could not run>`. For rubric-measured criteria the form reports evidence acquisition (`verified: <rubric applied, reading cited>`), never the judgment: the Verdict cell keeps Met / Partially Met / Not Met, and a `verified:` result can still carry Partially Met or Not Met; `unverified:` is never recorded as Met. The form binds Measured result cells only, not the doc's narrative prose.

One row per criterion — vague summarization across criteria is banned. **If no spec exists, state that explicitly in the doc and skip this section.** Never reconstruct success criteria after the fact from what was actually built; a criterion invented post-hoc is not a measurement, it's a rationalization.

## Phase 4: Carry-Forward Reconciliation

Read the previous retro doc (most recent under `docs/retros/`), if any. For every item it registered, classify its trigger class — edit-based (fires on a named file or section edit), drift-based (fires on a named record deviating), or event-based (fires on a future occurrence) — before classifying its status as Done / In progress / Not started, citing the commit, PR, or file that proves it. An item from the previous retro that goes unmentioned here is a silent drop, which is itself a defect to report.

**Backward check** (`enforces: P3`): while reading the previous retro doc, verify its shape — an Interview Transcript section with a valid independence level, and no uncited findings. Record the result as this doc's `Previous doc shape` bullet: `conformant`, `violations recorded as findings`, or `pre-schema, exempt`. A violation becomes a finding in the current retro, never a silent repair; a previous doc predating the transcript schema is marked `pre-schema, exempt` and skipped. Running in a different execution than the one that wrote the doc, this check catches violations one cycle late but reliably.

Register this cycle's new carry-forward items: type (architecture / performance / feature / edge-case / process) × priority (P1–P4). Push every item to a durable tracker (ROADMAP, issue tracker, or equivalent) — **never PR comments alone**, which are lost after merge.

## Interview Protocol (governs Phases 4–5)

The narrative half of a retro is where self-assessment bias lives: the agent that did the work grades its own work. Split the roles (`enforces: P3` — self-reports are not evidence):

- **Facilitator** — an independent agent with fresh context. Receives only artifacts (spec, plan, progress ledger, PR data, Phase 2–3 outputs), never the working conversation. Asks evidence-demanding probes from `references/interview-probes.md` and **rejects vague answers** ("mostly fine", "went well") by re-asking for the commit, measurement, or concrete event — an unevidenced answer cannot become a finding.
- **Respondent** — the agent that did the work (the main session, or in standalone runs whoever holds the context), answering from its record. The respondent assembles the doc mechanically from transcript rows — it holds the pen but not the judgment.

**Verdict authority**: only the facilitator authors the Verdict cell of a transcript row (the Interview Transcript section of `schemas/retro-template.md`). Every probed exchange lands in the transcript — accepted triples and terminal rejections alike. A non-terminal `rejected: <reason>` is a round output that continues the loop, never a transcript verdict; after 3 consecutive rejections the exchange terminates and the row records `no evidenced answer (3 rejections)` with the facilitator's final rejection text verbatim. A finding may cite such a T-ID — an honest gap is itself finding material. T-IDs are stable and never renumbered (same discipline as the spec's S-IDs).

**Round contract**: one round is one stateless dispatch. Input: the artifacts above + the accumulated transcript + the respondent's new answers. Output: per-probe results — `accepted` / `rejected: <reason>` / re-probe text — expressible as structured text from a one-shot invocation. At most 5 dispatches globally across the whole interview; Phases 4 and 5 may share a round, and the cap is never per-phase.

**Verbatim rule**: facilitator verdict text — acceptances and rejections both — is recorded verbatim, never summarized by the respondent. In degraded modes where one agent authors probe, answer, and verdict, the Verdict cell records `self-attested`, never `accepted` — a reader must never mistake self-attestation for facilitator acceptance.

**Independence-level recording**: the transcript header carries exactly one of the four closed level values — `heterogeneous`, `same-model fresh-context`, `in-thread (approximated independence)`, `self-checklist`. Tool names are optional free text; the level vocabulary is closed.

**Facilitator model selection**: fresh context is the minimum; a *heterogeneous* model is better when the environment offers one (from Claude Code, `codex exec` for a GPT-family facilitator; from Codex, a Claude subagent) — shared model biases produce shared blind spots, so heterogeneity adds a defense self-review cannot. Degrade per `references/dispatch-degradation.md` (plugin root): heterogeneous facilitator → same-model fresh-context subagent → sequential passes (facilitator pass generates probes from artifacts, respondent pass answers, facilitator pass critiques the evidence) → headless/single-agent: skip the interview and run the probe list as a fixed self-checklist. `enforces: P9`

The dispatch cap is the only exchange limit — when the fifth dispatch returns, the interview is over. Phase 5's raw material is transcript rows, cited by T-ID, never the working conversation's memory of what was said. Data collection (Phase 2) and measurement (Phase 3) are never interviewed — they are commands, not narratives (`enforces: P4`).

**End-of-interview checks** (`enforces: P3`) — run after the last dispatch, before Phase 6's doc write is finalized:

- **Carry-forward check**: every row of the `Carry-forward from previous retro` table cites artifact evidence (commit, PR, or file); any row the facilitator probed also cites its T-ID in the Evidence cell.
- **Findings check**: every finding — the `**What happened**:` list item, not the bucket heading — cites at least one transcript T-ID or Phase 2–3 data. An uncited finding goes back to the interview if dispatches remain under the cap; otherwise it is dropped.

**Known limit**: this protocol is a procedural gate, not a hard barrier — a respondent could fabricate transcript rows, and full mechanical enforcement would require the facilitator to own the file write, which no current harness contract guarantees. The citation checks and Phase 4's backward check are the backstop.

## Phase 5: Findings & Lessons

Findings use the three-part shape — **What happened / Why / How to apply** — bucketed into What Worked Well, What to Improve, Process Observations. Every finding cites something specific (a PR comment, a CI run, a review round); "tests caught bugs" is too vague, "the branch-level review caught the commit-threading bug that per-task review missed" is the bar. Never frame an acted-on review finding as "noise" or "trivial" — if it was worth fixing, it was legitimate.

Distill the most important findings into **lessons**: quotable one-liners that are specific, evidence-backed, actionable, and **surprising** — "testing is good" does not qualify.

## Phase 6: Write the Retro Doc

Write `docs/retros/YYYY-MM-DD-<context>-retro.md` following `schemas/retro-template.md` exactly — section order, table shapes, and the measured-vs-declared table are the contract other tooling may parse later. Do not invent additional top-level sections.

## Phase 7: Headless Compound Invocation

After writing the doc, invoke `compound` in `mode:headless` **only when at least one finding reaches reusable-lesson quality** — specific, surprising, and actionable enough to help a future occurrence, not every retro produces one. Skip the invocation silently (note "not attempted — no reusable lesson this cycle" in the doc's Compounding section) when nothing qualifies; do not force a thin doc into existence to satisfy this phase.

When invoked, pass the qualifying finding as context and expect `compound`'s exact terminal signal (`Documentation complete — <path>` / `Documentation skipped — <reason>` / `Documentation failed — <reason>`, per `schemas/headless-contract.md`). Surface whichever line `compound` returned in this retro's Compounding section — do not paraphrase it.

## Phase 8: Commit & Report

**Pre-commit check** (`enforces: P8`): the doc contains an Interview Transcript section with a valid independence level and a rounds-used count; in `self-checklist` mode the rows are the checklist answers. A zero-row table under a valid header is valid — nothing warranted probing. A missing section blocks the commit.

Commit the retro doc (and any durable-tracker updates from Phase 4) as its own commit, separate from other work in flight.

The plans a retro covers are: the plan path in `.release-loop/progress.md`'s `plan:` field when that ledger exists for the cycle, plus any plan path this retro's Phase 2 data or doc body cites; when neither names a plan (session-end mode), no flip. For every covered plan **first committed after the terminal-state contract landed** (`schemas/plan-schema.md` applicability boundary — pre-contract plans are never flipped), set `status: done` and `completed_by:` naming the commit on the base branch that landed that plan's work, in the plan's frontmatter, in the same commit as the retro doc; a retro covering multiple plans flips every qualifying one, each with its own `completed_by:`; never edit anything in the plan below the frontmatter (mutable-slot boundary, `schemas/plan-schema.md`).

Report what was measured, what carried forward, and what — if anything — was compounded.

End every invocation with the exact terminal signal line from `schemas/headless-contract.md`:
`Retrospective complete — <path>` on success, `Retrospective skipped — <reason>` when no retro was warranted (e.g. nothing to measure and no session content), or `Retrospective failed — <reason>` on failure. This line is the last non-empty line of the report in every mode, not only headless.

## Handoff

`compound` is the only skill invoked from inside `retrospective`, and only per Phase 7's gate. Nothing invokes `retrospective` automatically — `release-loop`'s Retro phase and direct user invocation are the only callers.

## Out of Scope (v0.2 hook points — documented, not implemented)

- **Session-history search integration**: Phase 2 names it as pluggable; the concrete search tool and dispatch payload discipline are deferred to v0.2.
