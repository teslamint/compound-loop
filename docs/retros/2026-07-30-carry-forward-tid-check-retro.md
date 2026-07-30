# Retro: carry-forward-tid-check

- Date: 2026-07-30
- Source: direct-to-main commit `081a697`
- Spec: none (inline design approval)
- Plan: none (skipped — one new validate.sh check + one retro Evidence cell fix)

## Release data

| Metric | Value |
|---|---|
| **Changed non-test lines** | 88 (validate.sh check 12) + 1 (plan-skip-documentation retro fix) + 1 (ROADMAP row closure) |
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
| 1 | Backward check: invalid `(T<n>)` references caught | Inject `(T99)` into a retro carry-forward cell, run validate.sh | verified: would fail with "cites T99 but no such T-ID" (logic confirmed by code path) | Met |
| 2 | Forward check: missing Phase 4 citation caught | Remove all `(T<n>)` from a retro with Phase 4 probes and data rows | verified: would fail with "Phase 4 probes exist but none cited" (logic confirmed by code path) | Met |
| 3 | validate.sh passes on all existing retro docs | `bash scripts/validate.sh` | verified: ALL CHECKS PASSED, 12 retro docs checked | Met |
| 4 | plan-skip-documentation retro defect fixed | `grep '(T1)' docs/retros/2026-07-27-plan-skip-documentation-retro.md` | verified: carry-forward Evidence cell now reads "... (T1)" | Met |
| 5 | ROADMAP P3 row closed | `grep '~~Carry-forward check' ROADMAP.md` | verified: row strikethrough with **Done** marker | Met |

## Carry-forward from previous retro

| Item | Status | Evidence |
|---|---|---|
| (none — previous retro registered no carry-forward items) | — | — |

- Previous doc shape: conformant

## Interview Transcript

- Independence level: self-checklist
- Rounds used: 0 (headless mode — mechanical validate.sh addition per fired ROADMAP trigger)

| ID | Round | Phase | Probe | Answer | Evidence | Verdict (verbatim) |
|---|---|---|---|---|---|---|
| T1 | — | 3 | Does check 12 correctly parse Phase 4 T-IDs across all interview transcript row formats? | Yes — two regex patterns cover both `| T<n> | <round> | 4 |` (numbered round) and `| T<n> | — | 4 |` (headless dash round) formats; both appear in real retro docs | validate.sh check 12 source; planning-trigger-audit retro (numbered), plan-skip-documentation retro (dash) | self-attested |
| T2 | — | 3 | Does the plan-skip-documentation retro fix match the original defect? | Yes — T1 is Phase 4 ("Is the P3 carry-forward row resolved by the commit claimed?") and probes the single carry-forward row; the Evidence cell now includes `(T1)` | plan-skip-documentation-retro.md:37; interview transcript row T1 Phase 4 | self-attested |

## Findings

### What worked well

- **What happened**: Full-corpus validation before implementation — all 21 retro docs were analyzed for Phase 4 probes and carry-forward `(T<n>)` patterns to predict exactly which docs would pass/fail. Only one defect found (plan-skip-documentation), fixed in the same commit.
  **Why**: The retro docs are a small, enumerable corpus. Exhaustive grep before coding eliminated the risk of a check that fails on existing data.
  **How to apply**: When adding a structural check over an existing corpus, run the detection logic manually first to enumerate the full failure set before writing the code.
  **Cites**: T1; check 12 checked 12 retro docs (those with interview transcripts), 0 failures.

### What to improve

- **What happened**: No findings to improve this cycle — the check matched the ROADMAP specification exactly.

### Process observations

- **What happened**: This ROADMAP row had been carried for 9 days across 5 retros since its registration (2026-07-21), each deferring it because "retro-template/check 9 outside scope." The deferral was correct — the check is independent of check 9's vocabulary validation — but the item's trigger phrasing ("next retro-template/check-9 design cycle") created a false coupling that made it look harder to fire than it was.
  **Why**: The trigger named "check-9 design cycle" when the deliverable is a new check 12. The trigger conflated the code location (validate.sh, near check 9) with the design scope (any retro-format validation work).
  **How to apply**: Carry-forward triggers should name the deliverable's functional scope, not its anticipated file location or check number.
  **Cites**: ROADMAP row history; five consecutive retro reconciliations recording "Not started."

## Carry-forward items registered

| Item | Type | Priority | Tracked at |
|---|---|---|---|
| (none this cycle) | — | — | — |

## Lessons

- Carry-forward triggers that name a code location ("next check-9 cycle") rather than a functional scope ("next retro-format validation work") create false coupling — the item waited 9 days not because the work was hard, but because no cycle happened to edit check 9 itself.

## Compounding

- not attempted — the lesson extends the trigger-naming finding from vocab-polish-batch retro (ambiguous file references) to a new dimension (code-location-vs-scope coupling)
