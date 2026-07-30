# Retro: pin-python-support

- Date: 2026-07-30
- Source: direct-to-main commit `3aac366`
- Spec: none (inline design approval)
- Plan: none (skipped — one delegation-boundary pin)

## Release data

| Metric | Value |
|---|---|
| **Changed non-test lines** | 1 (test-release-publication.sh) + 1 (ROADMAP row closure) |
| Commits | 1 |
| Review rounds | 1 (self-review) |
| Comments (fixed / deferred) | 0 / 0 |
| CI failures | 0 |
| Duration (design → push) | ~2 minutes |
| Units planned / completed | n/a (no plan) |

## Success criteria: measured vs declared

| # | Declared criterion | Measurement (command / rubric) | Measured result | Verdict |
|---|---|---|---|---|
| 1 | test-release-publication.sh pins PYTHON_SUPPORT_FILE | `grep 'PYTHON_SUPPORT_FILE' scripts/test-release-publication.sh` | verified: delegation now reads `PYTHON_SUPPORT_FILE="$ROOT/schemas/python-support.json"` | Met |
| 2 | validate.sh passes | `bash scripts/validate.sh` | verified: ALL CHECKS PASSED | Met |
| 3 | ROADMAP row closed | `grep '~~Pin the tracked' ROADMAP.md` | verified: strikethrough with **Done** marker | Met |

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
| T1 | — | 3 | Are all non-fixture consumers of test-python-compatibility.sh now pinned? | Yes — validate.sh (check 8) was already pinned; test-release-publication.sh is now pinned; no other non-fixture callers exist | `grep -rn 'test-python-compatibility' scripts/ | grep -v 'test-python-compatibility.sh:'` returns exactly 2 hits, both pinned | self-attested |

## Findings

### What worked well

- **What happened**: grep found exactly 2 callers outside the script itself, one already pinned (validate.sh) and one not (test-release-publication.sh). The fix was a single-line edit.
  **Why**: The delegation boundary was well-defined — the ROADMAP row named the exact variable and the exact action.
  **How to apply**: ROADMAP rows that name the exact variable and action to take are the fastest to close.
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

- Delegation-boundary pins are mechanical: grep callers, check each for the pinned variable, add where missing.

## Compounding

- not attempted
