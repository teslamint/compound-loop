---
schema: plan/v1
title: Retro Interview Protocol Enforcement
type: feat
status: draft
date: 2026-07-20
execution: code
origin: docs/specs/2026-07-20-retro-interview-enforcement-design.md
---

# Retro Interview Protocol Enforcement Plan

## Goal

Make the retrospective facilitator round-trip structurally enforceable: rewrite the Interview Protocol around facilitator verdict authority and a stateless re-dispatch contract, add the Interview Transcript section to the retro template, add a targeted format-drift check to `scripts/validate.sh` (the ROADMAP P3 drift-check trigger fires with this template change), and prove the whole arrangement with dry runs.

## Architecture notes

- **Source-of-truth direction**: `schemas/retro-template.md` owns the closed vocabularies (four independence levels, three verdict forms, seven transcript columns); `skills/retrospective/SKILL.md` and `skills/retrospective/references/interview-probes.md` cite them. The drift check reads the template as canonical and asserts the two skill files agree — same direction as validate.sh check 6, where `schemas/headless-contract.md` is canonical and consumer SKILL.md files are checked against it. **Known Pattern** (P5 reuse): check 6 and its fixture harness (`docs/plans/2026-07-16-001-feat-signal-drift-check-plan.md`) are the direct precedent — worktree-copy-to-mktemp fixtures, one mutation per case, red-then-green ordering (harness commits red before the check exists).
- **Verbatim length bound (spec Open Decision, owner: planning — resolved here)**: no truncation. Truncation is itself a softening vector — the respondent picking where to cut is the exact editorial power R3 removes. Instead the bound moves to the source: `interview-probes.md` instructs facilitators to keep verdict text to at most two sentences; whatever comes back is recorded in full.
- **Backward-check result placement** (spec left placement open): one bullet under the current doc's `Carry-forward from previous retro` section — `Previous doc shape: conformant | violations recorded as findings | pre-schema, exempt` — so the audit result is visible where the previous doc is already being discussed.
- **Check ordering**: the new check runs as check 9 in `scripts/validate.sh`, after check 8 (Python compatibility). Its `ok:` line is the literal `ok:   retro interview format: template and skill prose agree`. Extraction failure (template section missing, level count ≠ 4, verdict forms ≠ 3) is a named `FAIL:` line, never a traceback — same loud-failure convention as check 6.
- **Python-pin carry-forward (ROADMAP P3) not triggered**: this plan edits `scripts/validate.sh` but not its compatibility delegation; that boundary already sets `PYTHON_SUPPORT_FILE` explicitly (`scripts/validate.sh:275`). Verified, no action.

## Assumption Recheck

Origin spec retains four live assumptions; all commands rerun at 2026-07-20T22:59:13+09:00 on working tree at `34f7c24`:

| Approved claim | Fresh evidence | Outcome |
|---|---|---|
| 5-round cap exists in prose; accepted answers are Phase 5's raw material | `grep -n "Cap the exchange at 5 rounds" skills/retrospective/SKILL.md` → line 61 | match |
| Dispatched workers have no blocking-question channel | `grep -n "Only the parent orchestrator asks blocking questions" references/dispatch-degradation.md` → line 29 | match |
| No Interview Transcript section exists yet | `grep -rn "Interview Transcript" schemas/retro-template.md docs/retros/ scripts/` → no matches | match |
| Triple output contract already exists | `grep -n "triples" skills/retrospective/references/interview-probes.md` → line 35 | match |

## File structure

- Modify `schemas/retro-template.md` — transcript section, citation shapes (U1).
- Modify `skills/retrospective/SKILL.md` — Interview Protocol, Phases 4/8 (U2).
- Modify `skills/retrospective/references/interview-probes.md` — output contract (U3).
- Create `scripts/test-retro-format-drift.sh` — fixture harness (U4).
- Modify `scripts/validate.sh` — check 9 (U5).
- Create `docs/reviews/2026-07-20-retro-interview-enforcement-dryrun-evidence.md` — dry-run evidence (U6).

## Scenario coverage map

| S-ID | Unit chain | Scenario evidence |
|---|---|---|
| S1 (Tier 1 full-fidelity retro) | U1 → U2 → U3 | U6 positive dry run (Covers S1) |
| S2 (heterogeneous facilitator via external CLI) | U2 | U2 acceptance rubric: round contract is one-shot-expressible and no degradation-ladder rung is named by tool (spec SC2); loop shape itself walked by U6's S1 dry run |
| S3 (degraded in-thread pass) | U1 → U2 | Text verification in U2/U1 acceptance: `in-thread (approximated independence)` level and `self-attested` verdict present and defined; no live dry run — the restricted environment cannot be simulated from this session, and spec Testing deliberately scopes dry runs to S1/S4/S5 |
| S4 (self-checklist headless) | U1 → U2 | U6 degraded dry run (Covers S4) |
| S5 (violation caught before commit) | U2 | U6 negative injection (Covers S5) |

## Implementation Units

## U1: Interview Transcript section in retro template
Execution note: skip-test-first
Files:
  Modify: schemas/retro-template.md
Interfaces:
  Consumes: current template section order (`## Carry-forward from previous retro` directly precedes `## Findings`)
  Produces: the canonical vocabularies check 9 (U5) extracts: an `Independence level:` line carrying exactly `heterogeneous | same-model fresh-context | in-thread (approximated independence) | self-checklist`, and a single line beginning `Verdict cell values:` carrying the three backticked forms `` `accepted` ``, `` `no evidenced answer (3 rejections): <verbatim>` ``, `` `self-attested` `` separated by `|`. Also produces the seven-column table header `| ID | Round | Phase | Probe | Answer | Evidence | Verdict (verbatim) |` — guarded by this unit's acceptance grep only, not extracted by U5 (the header is template-internal; check 9's job is cross-file agreement)
Test scenarios:
  happy: n/a — prose artifact; verified by Acceptance greps
  edge: n/a — prose artifact
  error: n/a — prose artifact
  integration: n/a — canonical-source unit; walked end to end by U6's dry runs (Covers S1, S4 via the chain in the coverage map)
Steps:
  1. Insert a `## Interview Transcript` section between `## Carry-forward from previous retro` and `## Findings` inside the template's fenced markdown block, exactly per the spec's Data Model: the `Independence level:` line with the four values, `Rounds used: N (max 5)`, the seven-column table with two example rows (one `accepted`, one `no evidenced answer (3 rejections): <facilitator's final rejection, verbatim>`), then a single line beginning `Verdict cell values:` carrying the three backticked verdict forms separated by `|` (this exact anchor and shape is what check 9 parses — do not spread it over multiple lines), followed by a parenthetical noting that `self-attested` is degraded-modes-only, that in `self-checklist` mode the rows are the checklist answers, and that a zero-row table under a valid header is valid.
  2. In the `## Carry-forward from previous retro` section, add below the table: `- Previous doc shape: conformant | violations recorded as findings | pre-schema, exempt` with a parenthetical that this is the backward check's result on the previous retro doc.
  3. In the `## Findings` section, extend the `What worked well` example item with a `**Cites**: T<n> / Phase 2–3 data` line and extend the parenthetical under `What to improve` so uncited findings are named as rejected; note in the carry-forward table's parenthetical that probed rows append `(T<n>)` to their Evidence cell.
  4. Self-review against spec Data Model and R5; run `bash scripts/validate.sh` (template presence check must still pass).
  5. Commit: "docs(schema): Add Interview Transcript section to retro template"
Acceptance: `grep -c "Interview Transcript" schemas/retro-template.md` ≥ 1; the file contains `Independence level`, all four level values verbatim, a single `Verdict cell values:` line with the three backticked forms, `self-attested`, `no evidenced answer (3 rejections)`, `Previous doc shape`, `**Cites**`, and the `| ID | Round | Phase |` header (spec SC1).

## U2: Interview Protocol rewrite in retrospective SKILL.md
Execution note: skip-test-first
Files:
  Modify: skills/retrospective/SKILL.md
Interfaces:
  Consumes: U1's exact vocabulary spellings (levels, verdict forms, `Previous doc shape` values); existing section structure (Phase 4, Interview Protocol at current line 52, Phase 8)
  Produces: the protocol text U6's dry runs execute and check 9 (U5) validates against the template
Test scenarios:
  happy: n/a — prose artifact; verified by Acceptance greps and U6 dry runs
  edge: n/a — prose artifact
  error: n/a — prose artifact
  integration: n/a — behavior walked by U6 (Covers S1, S4, S5 via the coverage-map chains)
Steps:
  1. Rewrite the `## Interview Protocol (governs Phases 4–5)` section, preserving the existing facilitator/respondent definitions, model-selection ladder paragraph, and `enforces:` tags, and adding: (a) verdict authority — only the facilitator authors Verdict cells; every probed exchange lands in the transcript, accepted triples and terminal rejections alike (a non-terminal `rejected: <reason>` is a round output that continues the loop, never a transcript verdict); the 3-consecutive-rejection terminal state records as `no evidenced answer (3 rejections)` with the facilitator's final rejection verbatim, and findings may cite such a T-ID; (b) the round contract — one round is one stateless dispatch whose input is artifacts + accumulated transcript + new answers and whose output is per-probe results (`accepted` / `rejected: <reason>` / re-probe text), expressible as structured text from a one-shot invocation, capped at 5 dispatches globally across the whole interview (Phases 4 and 5 may share a round); (c) the verbatim rule — facilitator verdict text is recorded verbatim, never summarized; in degraded modes where one agent authors probe, answer, and verdict, the cell records `self-attested`, never `accepted`; (d) independence-level recording — the transcript header carries exactly one of the four levels; tool names are optional free text, the level vocabulary is closed; (e) the known limit — this is a procedural gate, not a hard barrier: a respondent could fabricate transcript rows, and full mechanical enforcement would require the facilitator to own the file write, which no current harness contract guarantees; the citation checks and the backward check are the backstop.
  2. Replace the sentence at current line 61 ("Cap the exchange at 5 rounds; the facilitator's accepted answers become the raw material...") with wording that counts dispatches and routes Phase 5's raw material through transcript rows, so no stale round-cap phrasing survives.
  3. Add the two end-of-interview checks to the protocol section: carry-forward check (every `Carry-forward from previous retro` row cites artifact evidence; probed rows also cite their T-ID) and findings check (every `**What happened**:` item cites a T-ID or Phase 2–3 data; an uncited finding goes back to the interview if dispatches remain, else is dropped) — run after the last dispatch, before Phase 6's doc write is finalized.
  4. In Phase 4, add the backward check: when reading the previous retro doc, verify it has an Interview Transcript section with a valid independence level and no uncited findings; record the result as the `Previous doc shape` bullet; a violation becomes a finding in the current retro, never a silent repair; a pre-schema doc is marked `pre-schema, exempt` and skipped.
  5. In Phase 8, add the pre-commit check: the doc contains an Interview Transcript section with a valid independence level and rounds-used count; in `self-checklist` mode the rows are the checklist answers; a zero-row table under a valid header is valid; a missing section blocks the commit.
  6. Self-review the whole file for stale references to the old accepted-only transcript model, and reconcile the model-selection ladder's "same-model independent-context subagent" phrasing with the closed level value `same-model fresh-context` so one spelling names the rung; run `bash scripts/validate.sh`.
  7. Commit: "feat(retrospective): Enforce facilitator round-trip via transcript and structural checks"
Acceptance: `skills/retrospective/SKILL.md` contains all four independence level values verbatim, `self-attested`, `no evidenced answer (3 rejections)`, `Previous doc shape`, `pre-schema, exempt`, the known-limit statement (fabrication possible, citation checks and backward check as backstop), and text for all four structural checks; no degradation-ladder rung is named by a concrete tool or product (reviewer rubric, spec SC2); `bash scripts/validate.sh` exits 0.

## U3: Output contract update in interview-probes.md
Execution note: skip-test-first
Files:
  Modify: skills/retrospective/references/interview-probes.md
Interfaces:
  Consumes: U1's verdict vocabulary
  Produces: the facilitator-facing contract dispatched prompts embed
Test scenarios:
  happy: n/a — prose artifact; verified by Acceptance greps
  edge: n/a — prose artifact
  error: n/a — prose artifact
  integration: n/a — leaf unit
Steps:
  1. Update the `## Output contract` section: triples carry stable T-IDs and a facilitator-authored verdict recorded verbatim; the existing 3-consecutive-rejection rule's recorded form becomes the `no evidenced answer (3 rejections)` verdict value (align wording, keep the rule's substance); add the conciseness instruction — verdict text at most two sentences, recorded in full with no truncation.
  2. Update the headless note so the self-checklist mode maps to `self-attested` verdicts and the `self-checklist` independence level.
  3. Self-review against U1's spellings; run `bash scripts/validate.sh`.
  4. Commit: "docs(retrospective): Align interview output contract with transcript schema"
Acceptance: the file contains `no evidenced answer (3 rejections)`, `self-attested`, a T-ID reference, and the two-sentence verdict bound; wording matches U1's vocabulary byte-for-byte where quoted.

## U4: Fixture harness for the format-drift check (red)
Execution note: skip-test-first
Files:
  Create: scripts/test-retro-format-drift.sh
Interfaces:
  Consumes: `scripts/validate.sh` (invoked unmodified — check 9 does not exist yet at this unit's end); the U1–U3 file states
  Produces: an executable script that per case copies the worktree (excluding `.git`) into a fresh `mktemp -d`, applies exactly one mutation (none for Case A), runs `bash scripts/validate.sh` from the copy, asserts on exit code and grepped output, prints a per-case pass/fail line, and removes the temp directory via `trap ... EXIT`
Test scenarios:
  happy: Case A — no mutation; asserts output contains the literal `ok:   retro interview format: template and skill prose agree` (red until U5)
  edge: cleanup still runs when an assertion fails — temp dir gone after a failing case
  error: non-writable `TMPDIR` reported as a harness error, not a silent pass
  integration: all five cases in one invocation — each fixture instantiates a drift the check must catch; U5 makes the assertions pass
Steps:
  1. Write the harness skeleton (copy, run, assert, cleanup helpers), following `scripts/test-signal-drift.sh`'s structure.
  2. Case A: no mutation; assert the check-9 `ok:` line is present. Run — confirm red (line absent, check 9 doesn't exist).
  3. Case B: in the copy, mutate one independence level value in `schemas/retro-template.md` (`self-checklist` → `self-check`); assert nonzero exit and a `FAIL:` naming the mismatch. Run — confirm red (validate.sh still reports `ALL CHECKS PASSED`).
  4. Case C: in the copy, delete the `self-attested` occurrences from `skills/retrospective/SKILL.md`; assert nonzero exit and a `FAIL:` naming `skills/retrospective/SKILL.md`. Run — confirm red.
  5. Case D: in the copy, delete the entire `## Interview Transcript` section from `schemas/retro-template.md`; assert nonzero exit, a `FAIL:` naming the template, and no `Traceback` in output. Run — confirm red.
  6. Case E: in the copy, delete `no evidenced answer` from `skills/retrospective/references/interview-probes.md`; assert nonzero exit and a `FAIL:` naming that file. Run — confirm red.
  7. `chmod +x`; confirm per-case summary lines and overall exit code. Commit: "test: Add fixture harness for retro format-drift check (red — check 9 pending)"
Acceptance: `bash scripts/test-retro-format-drift.sh` runs to completion; every case fails specifically because check 9 does not exist (validate.sh reports `ALL CHECKS PASSED` or lacks the `ok:` line), never from a harness-internal error.

## U5: Format-drift check (validate.sh check 9)
Execution note: test-first
Files:
  Modify: scripts/validate.sh
  Test: scripts/test-retro-format-drift.sh
Interfaces:
  Consumes: `schemas/retro-template.md`'s Interview Transcript section (canonical); `skills/retrospective/SKILL.md`; `skills/retrospective/references/interview-probes.md`
  Produces: check 9 — a `python3 - "$ROOT" <<'PY' ... PY || FAIL=1` block after check 8, emitting `ok:   retro interview format: template and skill prose agree` on success and named `FAIL:` lines otherwise
Test scenarios:
  happy: real repo — extraction yields 4 distinct levels + 3 verdict forms; all present in consumers; `ok:` line emitted (Case A green)
  edge: level value mutated in the template produces a `FAIL:` naming the missing level value and the consumer file it is absent from (Case B — the check knows only the template's spelling, not the consumer's intent)
  error: template section missing → named `FAIL:`, no traceback (Case D); missing/unreadable consumer file → named `FAIL:`
  integration: `bash scripts/test-retro-format-drift.sh` all-green (Cases A–E), proving red-then-green against U4's committed red state
Steps:
  1. Run `bash scripts/test-retro-format-drift.sh`; confirm the committed red state.
  2. Implement check 9: locate the `## Interview Transcript` heading in the template; extract the four level values by splitting the `Independence level:` line on `|` and trimming; extract the three verdict forms from the backtick spans of the single line anchored `Verdict cell values:` (the anchor U1 pins); fail loudly (named `FAIL:` lines) unless exactly 4 distinct levels and 3 distinct verdict forms result; assert each level value appears in `skills/retrospective/SKILL.md` with boundary-aware matching, not naive substring — Case B's mutation `self-check` is a substring of the consumer's intact `self-checklist`, so a substring check would pass the mutated fixture silently; assert `self-attested` and `no evidenced answer` appear in both `skills/retrospective/SKILL.md` and `skills/retrospective/references/interview-probes.md`; emit the `ok:` line only when zero failures.
  3. Run the harness; confirm all five cases pass. Run `bash scripts/validate.sh` on the real repo; confirm exit 0 with both check-9 `ok:` and `ALL CHECKS PASSED`.
  4. Commit: "feat(validate): Add retro interview format-drift check (check 9)"
Acceptance: `bash scripts/test-retro-format-drift.sh` exits 0; `bash scripts/validate.sh` exits 0 and prints the check-9 `ok:` line (spec SC6 plus the ROADMAP drift-check trigger satisfied).

## U6: Dry-run verification and evidence
Execution note: skip-test-first
Files:
  Create: docs/reviews/2026-07-20-retro-interview-enforcement-dryrun-evidence.md
Interfaces:
  Consumes: U1–U5 in their committed states; the retrospective skill as rewritten
  Produces: a committed, sanitized evidence document embedding three dry-run results the retro's measured-vs-declared pass can inspect (spec SC3–SC5)
Test scenarios:
  happy: positive dry run passes all three in-run checks with every finding cited
  edge: degraded dry run produces a valid `self-checklist` transcript
  error: negative injection is blocked before Phase 8
  integration: Covers S1, S4, S5 (one dry run each, per the coverage map)
Steps:
  1. Positive dry run (Covers S1): execute the rewritten retrospective skill in ad-hoc mode against this feature's own implementation arc, with a facilitator dispatched as a fresh-context subagent, writing the retro doc to the session scratch directory — never `docs/retros/`. Verify: all three in-run checks pass; every `**What happened**:` item carries a `**Cites**:` line; the backward check against the newest real doc under `docs/retros/` yields `pre-schema, exempt`.
  2. Degraded dry run (Covers S4): repeat in headless self-checklist mode; verify the transcript header shows `self-checklist` and all verdicts are `self-attested`.
  3. Negative injection (Covers S5): in a third scratch run, deliberately draft one uncited finding; verify the findings check blocks it before Phase 8 and it is removed or routed through the interview.
  4. Write the evidence doc: for each dry run, the produced retro doc in a fenced block (sanitized: no secrets, no personal data) plus the observed check outcomes; include the grep commands spec SC3–SC5 declare and their outputs.
  5. Commit: "docs(review): Record retro interview enforcement dry-run evidence"
Acceptance: the evidence doc exists and shows, verbatim: zero uncited findings in run 1, `self-checklist` level in run 2, and the blocked injection in run 3; `grep -A2 "Independence level" <run-2 block>` within the doc shows `self-checklist` (spec SC3–SC5).

## Mutation/failure-state matrix

No stateful ceremony in the deliverable; no mutation/failure-state matrix required.

## Deferred to Follow-Up Work

- Repo-wide `scripts/validate.sh` scanning of `docs/retros/*.md` for transcript conformance — deferred per the spec's Open Decision; trigger is the first violation past both the in-run checks and the backward check.
- ROADMAP carry-forward row removals (the P2 interview-enforcement row and the P3 drift-check row) — owned by the next retro's Phase 4 reconciliation, never by this plan's units.

## Open unknowns

**Planning-time (resolved):**
- Verbatim-verdict length bound — resolved in Architecture notes: no truncation; two-sentence bound instructed at source (U3).

**Implementation-time (deferred by design):**
- Exact Python regex/split patterns for check 9's extraction (U5 step 2 fixes behavior, not syntax).
- Exact placement of new sentences within existing SKILL.md paragraphs, and which existing sentences U2 step 6's stale-reference sweep rewrites.
- Scratch-directory paths and facilitator dispatch mechanics for U6's dry runs (harness-dependent at execution time).
