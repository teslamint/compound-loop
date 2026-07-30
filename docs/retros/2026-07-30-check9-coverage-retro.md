# Retro: check9-coverage

- Date: 2026-07-30
- Source: direct-to-main commit `85cdaf0`
- Spec: none (inline design approval)
- Plan: none (skipped — 3 fixture cases added to existing harness)

## Release data

| Metric | Value |
|---|---|
| **Changed non-test lines** | 1 (ROADMAP row closure) |
| Test lines | 60 (3 fixture cases in test-retro-format-drift.sh) |
| Commits | 1 |
| Review rounds | 1 (self-review) |
| Comments (fixed / deferred) | 0 / 0 |
| CI failures | 0 |
| Duration (design → push) | ~4 minutes |
| Units planned / completed | n/a (no plan) |

## Success criteria: measured vs declared

| # | Declared criterion | Measurement (command / rubric) | Measured result | Verdict |
|---|---|---|---|---|
| 1 | Case H tests level-count guard | `bash scripts/test-retro-format-drift.sh` Case H | verified: PASS — removing one level triggers "expected 4 distinct independence levels" | Met |
| 2 | Case I tests verdict-count guard | Case I output | verified: PASS — removing one verdict form triggers "expected 3 distinct backticked verdict forms" | Met |
| 3 | Case J tests verdict-line guard | Case J output | verified: PASS — removing Verdict cell values line triggers "expected exactly one" | Met |
| 4 | All 10 cases pass | `bash scripts/test-retro-format-drift.sh` | verified: ALL CASES PASSED (10/10) | Met |
| 5 | ROADMAP row closed | `grep '~~check 9' ROADMAP.md` | verified: strikethrough with **Done** marker | Met |

## Carry-forward from previous retro

| Item | Status | Evidence |
|---|---|---|
| (none — previous retro registered no carry-forward items) | — | — |

- Previous doc shape: conformant

## Interview Transcript

- Independence level: self-checklist
- Rounds used: 0 (headless mode)

| ID | Round | Phase | Probe | Answer | Evidence | Verdict (verbatim) |
|---|---|---|---|---|---|---|
| T1 | — | 3 | Do the 3 new cases cover all 3 malformation guards named in the ROADMAP row? | Yes — level count ≠ 4 (Case H), verdict forms ≠ 3 (Case I), missing Verdict cell values line (Case J) | ROADMAP row text vs case mutations | self-attested |

## Findings

### What worked well

- **What happened**: The existing harness pattern (setup_copy → mutate → validate → assert) made adding 3 cases mechanical — each case is ~20 lines following the same template.
  **Why**: Cases B-G established the pattern; Cases H-J are the same structure with different mutations.
  **How to apply**: Fixture harnesses with a stable setup/mutate/assert pattern make coverage expansion cheap.
  **Cites**: T1; 10/10 cases pass.

### What to improve

- **What happened**: The ROADMAP row also mentioned "a hypothetical paren-leading verdict form would be silently skipped by the anchor extraction." This was not addressed — the anchor extraction logic in check 9 was not modified.
  **Why**: Fixing the anchor extraction is a code change to validate.sh check 9, not a fixture case addition. The ROADMAP row bundled a bug fix with a coverage gap.
  **How to apply**: When closing a bundled ROADMAP row, note any sub-items left unaddressed. The paren-leading anchor issue is minor (hypothetical, no real verdict form starts with a paren) and can be tracked separately if needed.
  **Cites**: ROADMAP row text ("a hypothetical paren-leading verdict form").

### Process observations

- **What happened**: No additional observations.

## Carry-forward items registered

| Item | Type | Priority | Tracked at |
|---|---|---|---|
| (none this cycle) | — | — | — |

## Lessons

- Bundled ROADMAP rows (coverage gap + code fix) should be split at registration time — the coverage gap is a fixture task, the code fix is a validate.sh edit, and they have different scopes.

## Compounding

- not attempted
