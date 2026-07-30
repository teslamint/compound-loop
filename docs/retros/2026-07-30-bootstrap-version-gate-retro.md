# Retro: bootstrap-version-gate

- Date: 2026-07-30
- Source: direct-to-main commit `70a5504`
- Spec: none (inline design approval)
- Plan: none (skipped — 3-line version check addition)

## Release data

| Metric | Value |
|---|---|
| **Changed non-test lines** | 4 (test-python-compatibility.sh) + 1 (ROADMAP row closure) |
| Commits | 1 |
| Review rounds | 1 (self-review) |
| Comments (fixed / deferred) | 0 / 0 |
| CI failures | 0 |
| Duration (design → push) | ~3 minutes |
| Units planned / completed | n/a (no plan) |

## Success criteria: measured vs declared

| # | Declared criterion | Measurement (command / rubric) | Measured result | Verdict |
|---|---|---|---|---|
| 1 | Bootstrap gate rejects < 3.8 | Code inspection: `sys.version_info >= (3, 8)` check exits 1 with FAIL line on failure | verified: gate reads `if ! "$BOOTSTRAP" -c "import sys; sys.exit(0 if sys.version_info >= (3, 8) else 1)"` | Met |
| 2 | validate.sh passes with current python3 | `bash scripts/validate.sh` | verified: ALL CHECKS PASSED | Met |
| 3 | ROADMAP P4 row closed | `grep '~~scripts/test-python-compatibility' ROADMAP.md` | verified: strikethrough with **Done** marker | Met |

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
| T1 | — | 3 | Does the gate run before any heredoc? | Yes — the check is at lines 9-12, before TAG assignment and all parsing/fixture code | test-python-compatibility.sh:9-12 | self-attested |

## Findings

### What worked well

- **What happened**: Converting "incidental compatibility" to "declared + gated" required only 3 lines of code. The gate runs before any heredoc or parsing, ensuring a clear FAIL message instead of a cryptic syntax error.
  **Why**: The fix is a pure precondition check — it validates the environment before doing any work.
  **How to apply**: When a script has an undeclared interpreter dependency, a 3-line version check at the top converts it from incidental to gated.
  **Cites**: T1.

### What to improve

- **What happened**: No findings to improve.

### Process observations

- **What happened**: No additional observations.

## Carry-forward items registered

| Item | Type | Priority | Tracked at |
|---|---|---|---|
| (none this cycle) | — | — | — |

## Lessons

- A 3-line version gate at the top of a shell script converts an undeclared interpreter dependency into a declared, gated requirement with a clear failure message.

## Compounding

- not attempted
