# Retro: numbered-reference-validation

- Date: 2026-07-30
- Source: direct-to-main commit `c20bf56`
- Spec: none (inline design approval)
- Plan: none (skipped — one new validate.sh check + one ROADMAP row closure)

## Release data

| Metric | Value |
|---|---|
| **Changed non-test lines** | 97 (validate.sh check 13) + 1 (ROADMAP row closure) |
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
| 1 | SKILL.md step contiguity verified | `bash scripts/validate.sh` check 13 output | verified: "19 steps" — integers 1..18 contiguous, sub-step 5a recognized | Met |
| 2 | deepening.md section contiguity verified | check 13 output | verified: "6 deepening sections" — integers 1..6 contiguous | Met |
| 3 | plan-schema.md hard-floor contiguity verified | check 13 output | verified: "10 hard-floor items" — integers 1..10 contiguous | Met |
| 4 | Step references resolve | check 13 scans all planning files for `step N` references | verified: all references (step 1, 5a, 7, 8, 9, 11, 13, 15, 16) resolve to valid SKILL.md headings | Met |
| 5 | Item references resolve | check 13 scans plan-schema.md for `item N` references | verified: "item 3" resolves to hard-floor item 3 (Assumption Recheck) | Met |
| 6 | ROADMAP P3 row closed | `grep '~~Automated numbered' ROADMAP.md` | verified: row strikethrough with **Done** marker | Met |

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
| T1 | — | 3 | Does check 13 cover all three numbered-item sets described in the ROADMAP row? | Yes — SKILL.md steps (19), deepening.md sections (6), plan-schema.md hard-floor items (10), all verified for contiguity and reference resolution | validate.sh output: `[plan-refs] planning references valid: 19 steps, 6 deepening sections, 10 hard-floor items` | self-attested |
| T2 | — | 4 | Is the ROADMAP P3 row properly closed? | Yes — strikethrough with **Done** marker and trigger annotation | `git show c20bf56 -- ROADMAP.md` | self-attested |

## Findings

### What worked well

- **What happened**: The check validates both directions — structural contiguity (no gaps in numbered sequences) and semantic resolution (every "step N" or "item N" reference points to a valid heading). This catches both accidental step-number gaps from insertions/deletions and stale cross-references from renamed steps.
  **Why**: The ROADMAP row named both concerns ("contiguous heading/list numbering" and "resolve planning-step references") and the implementation addressed both in one pass.
  **How to apply**: When a validation check targets a numbered document, always validate both the numbering structure and its cross-references — one without the other leaves half the failure modes uncovered.
  **Cites**: T1; check 13 source.

### What to improve

- **What happened**: No findings to improve this cycle — the check matched the ROADMAP specification exactly.

### Process observations

- **What happened**: This is the third validate.sh check added in one session (checks 11, 12, 13 across three cycles). Each followed the same pattern: Python heredoc, TAG constant, failures list, ok/fail output. The pattern is stable enough that adding a check is now mechanical.
  **Why**: The first check (11, final-action-validate cycle) established the template; subsequent checks copied the structure.
  **How to apply**: When adding future validate.sh checks, copy the TAG + failures-list + fail()/finish pattern from an existing check — the convention is settled.
  **Cites**: checks 11, 12, 13 in validate.sh.

## Carry-forward items registered

| Item | Type | Priority | Tracked at |
|---|---|---|---|
| (none this cycle) | — | — | — |

## Lessons

- Three validate.sh checks in one session confirms the TAG + failures-list + Python-heredoc pattern is a stable, repeatable template for structural validation — new checks are now copy-and-specialize, not design-from-scratch.

## Compounding

- not attempted — the lesson is a pattern-stability observation, not a reusable finding for docs/solutions/
