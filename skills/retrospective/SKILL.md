---
name: retrospective
description: Measure outcomes vs criteria, reconcile carry-forward, extract lessons, feed the knowledge loop. /retrospective or $retrospective after a PR merges, at session/debugging-arc end, on request ("run a retro", "retrospective on this"), or on release-loop's Retro phase.
---

# Retrospective

Standalone and callable from anywhere in the loop. Measures declared success criteria against reality, closes the carry-forward loop, and hands reusable lessons to `compound` — a step no source system closed end-to-end.

## Entry / Exit / Gate

- **Entry**: a merged PR, a finished session or debugging arc, or direct invocation.
- **Exit**: retro doc committed to git at `docs/retros/YYYY-MM-DD-<context>-retro.md`.
- **Gate**: AUTO — no human approval required to write or commit a retro.

## Run artifact scope

When `release-loop` invokes retrospective, it supplies one exact repo-relative `progress_path`. Validate that record before using it and require `artifact_root = dirname(progress_path)` to match the ledger's `artifact_root`. A missing, ambiguous, mismatched, symlinked, or out-of-root path blocks before any read-dependent write. Derive every persisted sibling target from `artifact_root`; before its first write, reject any unowned filesystem or tracked target. A valid legacy ledger may update itself at the selected path, but no sibling target inherits that exemption. Standalone retrospective may proceed without a run ledger and creates no release-loop artifact.

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
- **Origin artifact**: Follow `Origin and coverage selection` below; with no plan, preserve the existing no-plan fallback. Otherwise, read the selected spec's `## Success Criteria` section verbatim (`skills/designing/references/spec-template.md` shape: statement + `Measured by`).

For a selected release-loop ledger, derive release-review metrics only from `review_counts`; never parse narrative Log lines. Compute `Review rounds` as `unit_passes + final_passes + standalone_passes`, then show those three components and `fix_rounds`. Show internal `findings_fixed` / `findings_deferred` separately from pull request `comments_fixed` / `comments_deferred`.

Before rendering those values, run `git merge-base <base_branch> HEAD` and `git rev-parse HEAD`. Both full object IDs must equal `current_commit_range.base` and `.head`. A mismatch blocks measurement with `stale-commit-range`; Retro never refreshes stale authority while measuring. A current legacy ledger with neither `review_counts.completeness` nor `counting_started_at` adopts `partial` and the current valid ISO-8601 UTC timestamp in the same persisted edit before structured counting starts. A legacy row with only one field, an empty or invalid timestamp, or an unknown `completeness` value blocks; never guess or render it. Render partial values as a lower bound since `counting_started_at`, using the exact persisted value.

Acceptance criterion 13 uses the immutable `full_validation_gate` report, not validator-registration text. The dedicated group runs the sixteen exact commands from approved plan U5 step 4, in order, and records each exact command, numeric exit, bounded result, and UTC start/end timestamps. It publishes the report once through the packaged publisher. Before Retro or full-lifecycle evidence cites the report, verify its publisher receipt path and SHA-256, ownership journal entry, current bytes, sixteen-command inventory, and all-zero exits. Keep this group outside the ordinary `all` group so its nested `test-run-artifact-integrity.sh all` command cannot recurse.

## Standalone plan contract

Retrospective consumes only repo-relative origin, applicability, terminal-transition, coverage-selection, and frontmatter-immutability rules; it does not require the full planning skill or its schema file.

Plan-consumer contract lives in [references/plan-consumer-contract.md](references/plan-consumer-contract.md).

### Origin and coverage selection

`origin` is resolved as a repo-relative spec path, while the existing no-plan fallback applies when no plan exists.
The covered-plan set is the selected exact `progress_path` ledger's `plan:` value plus every plan cited by Phase 2 data or the retrospective body.
When neither the ledger nor Phase 2/body cites a plan, no plan is selected and no terminal flip occurs.
When multiple qualifying plans are selected, apply the same applicability and transition rules to every plan.

### Plan terminal transition contract

Only a post-contract plan with `status: approved` may transition to `status: done`.
The terminal transition mutates only frontmatter `status` and `completed_by`.
`completed_by` must name the landed base-branch commit; a missing landed commit rejects.
A pre-contract plan is never retroactively flipped, even when a retro covers it.
A non-approved plan does not flip to `done`.
Each qualifying plan's `status` and `completed_by` change in the same commit as the retro document.
Retrospective never changes the plan body.
Retrospective rejects any frontmatter mutation other than `status` and `completed_by`.
Applicability is keyed to the plan's first commit after the terminal-state contract landed, not to its approval date; no terminal state is backfilled onto earlier plans.

Transition validation inspects the actual parent-to-retro commit diff for every selected plan. It compares the committed plan bytes before and after that commit, allowing only `status` and `completed_by` frontmatter changes and rejecting any body or other-frontmatter mutation; mutation metadata never supplies the immutability verdict.

## Phase 3: Measured vs. Declared (core)

For each criterion in the spec's Success Criteria section:

1. Identify the proving command or judgment rubric exactly as declared — do not paraphrase it into something easier to run.
2. **Run the command fresh, in this execution.** A prior claim in a commit message, PR body, or earlier retro is not evidence. `enforces: P3`
3. Record the measured result next to the declared target and classify **Met / Partially Met / Not Met**, with the gap stated explicitly for anything short of Met. The Measured result cell uses the binary completion report form — `verified: <observation>` (naming the evidence tier where one applies; tier-free otherwise) or `unverified: <why the measurement could not run>`. For rubric-measured criteria the form reports evidence acquisition (`verified: <rubric applied, reading cited>`), never the judgment: the Verdict cell keeps Met / Partially Met / Not Met, and a `verified:` result can still carry Partially Met or Not Met; `unverified:` is never recorded as Met. The form binds Measured result cells only, not the doc's narrative prose.

One row per criterion — vague summarization across criteria is banned. **If no spec exists, state that explicitly in the doc and skip this section.** Never reconstruct success criteria after the fact from what was actually built; a criterion invented post-hoc is not a measurement, it's a rationalization.

## Phase 4: Carry-Forward Reconciliation

Read the previous retro doc (most recent under `docs/retros/`), if any. For every item it registered, classify its trigger class — edit-based (fires on a named file or section edit), drift-based (fires on a named record deviating), or event-based (fires on a future occurrence) — before classifying its status as Done / In progress / Not started, citing the commit, PR, or file that proves it. An item from the previous retro that goes unmentioned here is a silent drop, which is itself a defect to report.

Reconcile mechanically, in four steps:

1. Read the previous retro's `Carry-forward items registered` table, never its narrative. Its data-row count is registered N. A previous doc that carries no such table yields registered N = 0 and the degraded suffix on the reconciliation bullet: `— degraded: previous retro has no registration table`.
2. Reconcile row by row, by name. Match each registered item name against the `Carry-forward from previous retro` table of this doc, ignoring case and surrounding whitespace. Counts that agree while the names do not are not a reconciliation.
3. Record both counts in the template's reconciliation bullet — `- Reconciliation: registered <N>, accounted for <M>` — where M is this doc's row count. Both numbers are recorded, never only their agreement.
4. A row naming an item the previous retro never registered is itself a defect, reported like a silent drop. It inflates M, and an inflated M can conceal an item that was dropped.

**Backward check** (`enforces: P3`): while reading the previous retro doc, verify its shape — an Interview Transcript section with a valid independence level, and no uncited findings. Record the result as this doc's `Previous doc shape` bullet: `conformant`, `violations recorded as findings`, or `pre-schema, exempt`. A violation becomes a finding in the current retro, never a silent repair; a previous doc predating the transcript schema is marked `pre-schema, exempt` and skipped. Running in a different execution than the one that wrote the doc, this check catches violations one cycle late but reliably.

Register this cycle's new carry-forward items: type (architecture / performance / feature / edge-case / process) × priority (P1–P4). Push every item to a durable tracker (ROADMAP, issue tracker, or equivalent) — **never PR comments alone**, which are lost after merge.

## Interview Protocol (governs Phases 4–5)

The narrative half of a retro is where self-assessment bias lives: the agent that did the work grades its own work. Split the roles (`enforces: P3` — self-reports are not evidence):

- **Facilitator** — an independent agent with fresh context. Receives only artifacts (spec, plan, progress ledger, PR data, Phase 2–3 outputs), never the working conversation. Asks evidence-demanding probes from `references/interview-probes.md` and **rejects vague answers** ("mostly fine", "went well") by re-asking for the commit, measurement, or concrete event — an unevidenced answer cannot become a finding.
- **Respondent** — the agent that did the work (the main session, or in standalone runs whoever holds the context), answering from its record. The respondent assembles the doc mechanically from transcript rows — it holds the pen but not the judgment.

**Verdict authority**: only the facilitator authors the Verdict cell of a transcript row (the Interview Transcript section of `schemas/retro-template.md`). Every probed exchange lands in the transcript — accepted triples and terminal rejections alike. A non-terminal `rejected: <reason>` is a round output that continues the loop, never a transcript verdict; after 3 consecutive rejections the exchange terminates and the row records `no evidenced answer (3 rejections)` with the facilitator's final rejection text verbatim. A finding may cite such a T-ID — an honest gap is itself finding material. T-IDs are stable and never renumbered (same discipline as the spec's S-IDs).

**Round contract**: one round is one stateless dispatch. Input: the artifacts above + the accumulated transcript + the respondent's new answers. Output: per-probe results — `accepted` / `rejected: <reason>` / re-probe text — expressible as structured text from a one-shot invocation. At most 5 dispatches globally across the whole interview; Phases 4 and 5 may share a round, and the cap is never per-phase.

Persist every facilitator round verbatim before the transcript or metrics cite it. In release-loop mode, write the exact returned bytes to a transition-owned temporary file, then use the packaged publisher from the invocation packet to publish `<artifact_root>/reviews/facilitator/round-<N>.md`. The target is `reviews/facilitator/round-<N>.md` relative to `artifact_root`; N is the dispatch ordinal. Persist the publisher receipt path and SHA-256 with that round. Before use, require one receipt for each ordinal, the matching ownership journal entry, and current bytes with the same SHA-256. A missing, changed, conflicting, journal-mismatched, or unpublished round blocks an evidence-backed count or verdict claim. Standalone retrospective without a ledger records the same bytes in the retro document only and creates no release-loop artifact.

**Verbatim rule**: facilitator verdict text — acceptances and rejections both — is recorded verbatim, never summarized by the respondent. In degraded modes where one agent authors probe, answer, and verdict, the Verdict cell records `self-attested`, never `accepted` — a reader must never mistake self-attestation for facilitator acceptance.

**Independence-level recording**: the transcript header carries exactly one of the five closed level values — `heterogeneous`, `same-model fresh-context`, `in-thread (approximated independence)`, `self-checklist`, `not-probed (no narrative warranted)`. Tool names are optional free text; the level vocabulary is closed.

**Facilitator model selection**: fresh context is the minimum; a *heterogeneous* model is better when the environment offers one (from Claude Code, `codex exec` for a GPT-family facilitator; from Codex, a Claude subagent) — shared model biases produce shared blind spots, so heterogeneity adds a defense self-review cannot. Degrade per `references/dispatch-degradation.md` (plugin root): heterogeneous facilitator → same-model fresh-context subagent → sequential passes (facilitator pass generates probes from artifacts, respondent pass answers, facilitator pass critiques the evidence) → no subagent primitive and no external facilitator CLI: skip the interview and run the probe list as a fixed self-checklist. `mode:headless` qualifies for no rung of this ladder — the flag governs whether the user is asked blocking questions, not which worker dispatch the harness can perform. `enforces: P9`

The dispatch cap is the only exchange limit — when the fifth dispatch returns, the interview is over. Phase 5's raw material is transcript rows, cited by T-ID, never the working conversation's memory of what was said. Data collection (Phase 2) and measurement (Phase 3) are never interviewed — they are commands, not narratives (`enforces: P4`).

**End-of-interview checks** (`enforces: P3`) — run after the last dispatch, before Phase 6's doc write is finalized:

- **Carry-forward check**: every row of the `Carry-forward from previous retro` table cites artifact evidence (commit, PR, or file); any row the facilitator probed also cites its T-ID in the Evidence cell.
- **Findings check**: every finding — the `**What happened**:` list item, not the bucket heading — cites at least one transcript T-ID or Phase 2–3 data. An uncited finding goes back to the interview if dispatches remain under the cap; otherwise it is dropped.

**Known limit**: this protocol is a procedural gate, not a hard barrier — a respondent could fabricate transcript rows, and full mechanical enforcement would require the facilitator to own the file write, which no current harness contract guarantees. The citation checks and Phase 4's backward check are the backstop.

## Warrant for not-probed

`not-probed (no narrative warranted)` is the only level reachable with no facilitator dispatch, so it carries a warrant rather than a justification. All four conditions below must hold. Any one of them failing blocks the level, and the retro records a probed level instead.

- **W1 — nothing measured short.** No Phase 3 criterion reads `Partially met` or `Not met`, or the document states that no spec exists. A criterion the cycle missed is narrative material by definition.
- **W2 — carry-forward reconciles exactly.** The Phase 4 reconciliation records registered N equal to accounted-for M, with no unregistered row. The degraded no-table fallback never satisfies W2: a `registered 0, accounted for 0` result produced by a previous retro that has no registration table is an absent measurement, not a clean one, so it does not authorize `not-probed`.
- **W3 — findings sit in one bucket.** The Findings section carries no entry outside What Worked Well. An entry under What to Improve or Process Observations is a narrative the retro has already written.
- **W4 — the judgment is confirmed, not asserted.** Two paths, and exactly one applies. On the first path a facilitator channel is reachable: one facilitator dispatch confirms the judgment, and the transcript records that confirmation as a row whose Verdict cell reads `accepted`. `self-attested` is never a valid `not-probed` verdict — the claimant confirming its own claim is the shape this warrant exists to block. On the second path no channel is reachable, and `not-probed` then carries the same absent-capability claim that `self-checklist` carries, naming both `no subagent primitive` and `no external facilitator CLI` on the `- Rounds used:` line. A zero-row table under a valid header is valid — nothing warranted probing — on this second path.

W1 through W4 raise the cost of a false `not-probed` claim; they do not remove it. That residual is the Known limit the protocol already declares — a procedural gate, not a hard barrier.

## Phase 5: Findings & Lessons

Findings use the three-part shape — **What happened / Why / How to apply** — bucketed into What Worked Well, What to Improve, Process Observations. Every finding cites something specific (a PR comment, a CI run, a review round); "tests caught bugs" is too vague, "the branch-level review caught the commit-threading bug that per-task review missed" is the bar. Never frame an acted-on review finding as "noise" or "trivial" — if it was worth fixing, it was legitimate.

Distill the most important findings into **lessons**: quotable one-liners that are specific, evidence-backed, actionable, and **surprising** — "testing is good" does not qualify.

## Phase 6: Write the Retro Doc

Write `docs/retros/YYYY-MM-DD-<context>-retro.md` following `schemas/retro-template.md` exactly — section order, table shapes, and the measured-vs-declared table are the contract other tooling may parse later. Do not invent additional top-level sections.

## Phase 7: Headless Compound Invocation

After writing the doc, invoke `compound` in `mode:headless` **only when at least one finding reaches reusable-lesson quality** — specific, surprising, and actionable enough to help a future occurrence, not every retro produces one. Skip the invocation silently (note "not attempted — no reusable lesson this cycle" in the doc's Compounding section) when nothing qualifies; do not force a thin doc into existence to satisfy this phase.

When invoked, pass the qualifying finding as context and expect `compound`'s exact terminal signal (`Documentation complete — <path>` / `Documentation skipped — <reason>` / `Documentation failed — <reason>`, per `schemas/headless-contract.md`). Surface whichever line `compound` returned in this retro's Compounding section — do not paraphrase it.

## Phase 8: Commit & Report

**Pre-commit check** (`enforces: P8`): the doc contains an Interview Transcript section with a valid independence level and a rounds-used count; in `self-checklist` mode the rows are the checklist answers. A missing section blocks the commit. A degraded level — `in-thread (approximated independence)` or `self-checklist` — must also name the capability that was absent, on the same `- Rounds used:` line; an unnamed capability blocks the commit. `mode:headless` is not an absent capability: the flag governs whether the user is asked blocking questions, not which worker dispatch the harness can perform. A strict dispatch budget is not an absent capability either: a budget is a choice about spend, not a missing primitive. A `self-checklist` claim names both facilitator channels of the ladder as absent — `no subagent primitive` and `no external facilitator CLI` — because rung 1 of `references/dispatch-degradation.md` (plugin root) names an external CLI facilitator that does not depend on the subagent primitive, so an absent subagent primitive alone still leaves a reachable facilitator. An `in-thread (approximated independence)` claim names why fresh context was unavailable.

Commit the retro document, every qualifying plan's `status`/`completed_by` frontmatter transition, and every applicable tracker update together in one commit. A retro commit that omits a qualifying plan or splits any transition into another commit is invalid.


Report what was measured, what carried forward, and what — if anything — was compounded.

End every invocation with the exact terminal signal line from `schemas/headless-contract.md`:
`Retrospective complete — <path>` on success, `Retrospective skipped — <reason>` when no retro was warranted (e.g. nothing to measure and no session content), or `Retrospective failed — <reason>` on failure. This line is the last non-empty line of the report in every mode, not only headless.

## Handoff

`compound` is the only skill invoked from inside `retrospective`, and only per Phase 7's gate. Nothing invokes `retrospective` automatically — `release-loop`'s Retro phase and direct user invocation are the only callers.

Out of Scope moved to `references/out-of-scope.md`.
