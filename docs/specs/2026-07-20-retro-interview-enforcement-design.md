---
title: Retro Interview Protocol Enforcement
status: draft
date: 2026-07-20
schema: spec/v1
---

# Retro Interview Protocol Enforcement Design

_Created 2026-07-20._

## Overview

The retrospective Interview Protocol's facilitator round-trip is described in prose but not enforced: the respondent can answer its own probes internally and skip the facilitator loop entirely, defeating the self-assessment bias guard (`enforces: P3`). Observed in the dhlottery-autobuy session 001 retro, where the facilitator sent 5 probes and the respondent wrote answers directly into the retro doc without routing them through the facilitator. This design combines a workflow redefinition (the facilitator owns verdicts on interview content) with document evidence (an Interview Transcript section holding the probed exchanges) and structural checks (uncited findings block the commit).

## User Scenarios

### S1: Full-fidelity retro under a harness with native subagents

A PR-merge retro runs on Claude Code or Codex. The orchestrator (respondent) dispatches a facilitator per the existing degradation ladder — heterogeneous model first, same-model fresh-context subagent otherwise. Each round is one dispatch: facilitator receives artifacts plus the accumulated transcript, returns verdicts and any re-probes. Accepted (probe, answer, evidence) triples land verbatim in the retro doc's Interview Transcript section; Phase 5 findings cite triple IDs.

### S2: Heterogeneous facilitator via external CLI

The orchestrator reaches a cross-model facilitator through a one-shot CLI (e.g. from Claude Code, a GPT-family CLI; from Codex, a Claude CLI). Because the round contract is stateless — full context travels in the prompt each round — the same loop runs unchanged. The transcript records independence level `heterogeneous`, not the tool name.

### S3: Degraded in-thread sequential pass

No dispatch primitive is available (sandboxed run, restricted environment). The facilitator role runs as an in-thread pass generating probes from artifacts only. The transcript records `in-thread (approximated independence)` — readers can see this retro's bias guard was weaker. The citation checks still apply in full.

### S4: Headless / single-agent self-checklist

Headless mode skips the dialogue and runs the probe list as a fixed self-checklist (existing behavior). The transcript section is still written, with independence level `self-checklist` and the checklist answers as its rows, so the doc shape is uniform and the degradation is visible rather than silent.

### S5: Violation attempt caught before commit

A respondent drafts a Phase 5 finding that cites no transcript triple and no Phase 2–3 data. The end-of-interview findings check scans the draft doc, finds the uncited finding, and blocks progression to Phase 8 — the finding either goes through the interview loop or is dropped. The dhlottery-autobuy failure mode (answers written directly into the doc) becomes structurally detectable instead of review-dependent.

## Scope

### In

- `skills/retrospective/SKILL.md`: Interview Protocol rewrite (facilitator verdict authority, re-dispatch round contract, 5-dispatch global cap), end-of-interview structural checks (carry-forward, findings), the Phase 8 pre-commit check, and the Phase 4 next-retro backward check.
- `schemas/retro-template.md`: new `## Interview Transcript` section (independence level + triples table with stable T-IDs); citation column/line added to Carry-forward and Findings shapes.
- `skills/retrospective/references/interview-probes.md`: output contract updated to include T-IDs and the verbatim-verdict rule.

### Out

- `scripts/validate.sh` changes (repo-wide retro-doc scanning; see Open Decisions).
- `references/dispatch-degradation.md` changes — the ladder is reused, not modified.
- Retroactive editing of existing `docs/retros/*.md` (they predate the schema and stay valid as historical artifacts).
- `release-loop` sequencing changes.
- Any harness-specific tool naming inside the skill (per the EntireContext-removal precedent).

## Assumptions and Preconditions

| Claim | Command | Observed at | Observed result | Evidence source |
|---|---|---|---|---|
| The 5-round cap exists in prose and accepted answers are Phase 5's raw material | `grep -n "Cap the exchange at 5 rounds" skills/retrospective/SKILL.md` | 2026-07-20T22:40:50+09:00 | Line 61 matches | Working tree at `d79aafc` |
| Dispatched workers have no blocking-question channel; orchestrator drives all loops | `grep -n "Only the parent orchestrator asks blocking questions" references/dispatch-degradation.md` | 2026-07-20T22:40:50+09:00 | Line 29 matches | Working tree at `d79aafc` |
| No Interview Transcript section exists anywhere yet (template, retros, scripts) | `grep -rn "Interview Transcript" schemas/retro-template.md docs/retros/ scripts/` | 2026-07-20T22:40:50+09:00 | No matches | Working tree at `d79aafc` |
| The (probe, answer, evidence) triple output contract already exists | `grep -n "triples" skills/retrospective/references/interview-probes.md` | 2026-07-20T22:40:50+09:00 | Line 35: facilitator returns accepted answers as triples | Working tree at `d79aafc` |

## Architecture

### Role redefinition (R1)

The facilitator owns **verdicts**: only the facilitator authors the Verdict cell of any transcript row, and only transcript triples (or Phase 2–3 data) may be cited by Findings. Every probed exchange lands in the transcript — accepted triples and terminal rejections alike; the 3-consecutive-rejection state records as `no evidenced answer (3 rejections)` with the facilitator's final rejection text verbatim. A finding may cite a no-evidenced-answer T-ID: an honest gap is itself finding material. The respondent assembles the doc mechanically from transcript rows — it holds the pen but not the judgment. This is a procedural gate, not a hard barrier: the real backstop is the citation check (R5), which makes uncited content fail structurally regardless of who wrote it.

### Round contract (R2)

One interview round is one dispatch, stateless by construction:

- **Input**: artifacts (per existing protocol) + accumulated transcript so far + the respondent's new answers.
- **Output**: per-probe verdict (`accepted` / `rejected: <reason>` / re-probe text), expressible as structured text from a one-shot invocation.
- **Cap**: at most 5 dispatches **globally across the whole interview** (the existing 5-round cap, now countable) — Phase 4 and Phase 5 probes may share a round; the cap is not per-phase.
- **Constraint**: the facilitator never sees the working conversation — artifacts and transcript only (existing rule, unchanged).

Because the contract is one-shot-expressible, every rung of the existing degradation ladder satisfies it — native subagents, external CLIs, in-thread passes — without the skill naming any mechanism.

### Verbatim rule (R3)

Facilitator verdict text — acceptances and rejections both — is recorded in the transcript verbatim, not summarized by the respondent (same principle as the terminal-signal verbatim rule). This narrows the respondent's room to soften rejections while holding the pen. In degraded modes where the same agent authors probe, answer, and verdict (`in-thread`, `self-checklist`), the Verdict cell records `self-attested` instead of `accepted` — a reader must never mistake self-attestation for facilitator acceptance.

### Independence-level recording (R4)

The transcript header records one of: `heterogeneous` | `same-model fresh-context` | `in-thread (approximated independence)` | `self-checklist`. Tool names are free-form and optional; the level vocabulary is closed. Readers and future tooling judge a retro's bias-guard strength from the doc alone.

### Structural checks (R5)

Because rounds may span Phases 4 and 5, the two content checks run **at end-of-interview** (after the last dispatch, before Phase 6's doc write is finalized), in this order:

- **Carry-forward check**: every row of the `Carry-forward from previous retro` table cites artifact evidence (commit/PR/file — existing rule); any row the facilitator probed also cites its T-ID in the Evidence cell.
- **Findings check**: every finding — the unit is the `**What happened**:` list item, not the three fixed `###` buckets — cites at least one transcript T-ID or Phase 2–3 data. An uncited finding blocks progression — back to the interview (if dispatches remain under the cap) or dropped.
- **Phase 8 pre-commit**: the doc contains an Interview Transcript section with a valid independence level and a rounds-used count; in `self-checklist` mode the rows are the checklist answers. A zero-row table under a valid header is valid (nothing warranted probing). A missing section blocks the commit.
- **Next-retro backward check (Phase 4)**: when Phase 4 reads the previous retro doc, it also verifies that doc's shape — an Interview Transcript section with a valid independence level, and no uncited findings. A violation is recorded as a finding in the current retro, not silently repaired. A previous doc predating this schema is marked `pre-schema, exempt` and skipped. This check runs in a different execution than the one that wrote the doc, so it does not share the in-run checks' weakness (the same agent skipping its own instructions); it catches violations one cycle late but reliably, since Phase 4 reads the previous doc every cycle by existing rule.

The first three checks are executed by the skill within the writing run, scoped to the doc being written; the backward check audits the previous cycle's doc. Existing retro docs are unaffected except as `pre-schema, exempt` backward-check subjects.

## Data Model

`schemas/retro-template.md` gains, between "Carry-forward from previous retro" and "Findings":

```markdown
## Interview Transcript

- Independence level: heterogeneous | same-model fresh-context | in-thread (approximated independence) | self-checklist
- Rounds used: N (max 5)

| ID | Round | Phase | Probe | Answer | Evidence | Verdict (verbatim) |
|---|---|---|---|---|---|---|
| T1 | 1 | 5 | <probe> | <answer> | <commit/file/measurement> | accepted |
| T2 | 3 | 4 | <probe> | <final answer> | — | no evidenced answer (3 rejections): <facilitator's final rejection, verbatim> |
```

Verdict cell values: `accepted` | `no evidenced answer (3 rejections): <verbatim>` | `self-attested` (degraded modes only, per R3). A zero-row table under the header fields is valid. T-IDs are stable and never renumbered (same discipline as S-IDs). Each finding — the `**What happened**:` list item under the three fixed buckets — gains a `**Cites**: T<n> / Phase 2–3 data` line; probed rows of the `Carry-forward from previous retro` table append `(T<n>)` to their Evidence cell (`Carry-forward items registered` is untouched — it has no Evidence column and registers forward-looking items, not probed claims).

## Testing

Skill-doc change — verification is by dry run, not unit tests:

1. **Positive dry run (Tier 1)**: run a retro on a real merged change with a dispatched facilitator; verify the produced doc passes the three in-run structural checks and every finding cites a T-ID. The backward check fires on the previous retro doc and marks it `pre-schema, exempt`.
2. **Degraded dry run (self-checklist)**: run a headless retro; verify the transcript section exists with `self-checklist` level and the doc still passes checks.
3. **Negative injection**: during a dry run, deliberately draft one finding with no citation; verify the end-of-interview findings check blocks it before Phase 8.
4. **Regression**: `bash scripts/validate.sh` still passes (frontmatter, signal lines, template presence).

## Risks

- **Procedural, not mechanical**: a respondent could fabricate transcript rows. Mitigation: verbatim rule (R3) plus independence-level recording (R4) leave forgery detectable in review; full mechanical enforcement would require the facilitator to own the file write, which no current harness contract guarantees — accepted as a known limit, stated in the skill text.
- **Overhead on small ad-hoc retros**: the transcript section adds ceremony. Mitigation: `self-checklist` mode keeps the lightweight path — the section is a table of checklist answers, minutes not hours.
- **Schema/skill format drift**: the new template section and the skill prose citing it are exactly the drift class the P3 carry-forward item warns about. Mitigation: this change triggers that item's "next step" — a targeted grep check is registered as an Open Decision rather than silently skipped.

## Success Criteria

1. `schemas/retro-template.md` defines the Interview Transcript section with independence level, rounds-used, and a T-ID triples table.
   - **Measured by**: `grep -c "Interview Transcript" schemas/retro-template.md` returns ≥1 and the section contains `Independence level` and a `| ID |` table header.
2. `skills/retrospective/SKILL.md` defines the round contract (stateless dispatch, ≤5 dispatches, verbatim verdicts) and all four structural checks (carry-forward, findings, pre-commit, next-retro backward).
   - **Measured by**: reviewer rubric — each of R1–R5 is locatable in the skill text by section; no rung of the degradation ladder is named by tool.
3. A Tier 1 dry-run retro produces a doc where every finding cites a T-ID or Phase 2–3 data.
   - **Measured by**: on the produced doc, every `**What happened**:` finding block under the Findings buckets contains a `**Cites**:` line; zero uncited findings.
4. A self-checklist dry-run retro produces a doc containing an Interview Transcript section with `self-checklist` independence level.
   - **Measured by**: `grep -A2 "Independence level" <produced-doc>` shows `self-checklist`.
5. The negative injection (one uncited finding) is caught before Phase 8 commit.
   - **Measured by**: dry-run transcript shows the end-of-interview findings check firing and the finding being removed or routed through the interview — the committed doc contains no uncited finding.
6. No structural regression.
   - **Measured by**: `bash scripts/validate.sh` exits 0.

## Open Decisions

- **Repo-wide `scripts/validate.sh` check for new retro docs**: a date- or list-gated check (docs after this spec's adoption must contain the transcript section) would close the gap mechanically but adds grandfathering logic. Deferred: the next-retro backward check (R5) already audits every doc one cycle later from an independent execution. Owner: user — trigger is the first violation that slips past both the in-run checks and the backward check.
- **Verbatim-verdict length bound**: whether very long facilitator outputs may be truncated with a marker, or must be carried in full. Owner: `planning`.
- **Schema-drift grep check**: whether the P3 format-drift carry-forward item's targeted check (skill prose ↔ template field names) is implemented in this cycle or its own. Owner: user.
