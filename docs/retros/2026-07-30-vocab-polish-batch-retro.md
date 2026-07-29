# Retro: vocab-polish-batch

- Date: 2026-07-30
- Source: direct-to-main commit `531497a`
- Spec: none (inline design approval)
- Plan: none (skipped — two atomic text edits across two files)

## Release data

| Metric | Value |
|---|---|
| **Changed non-test lines** | 2 (reviewing SKILL.md + verification.md) + 1 (ROADMAP row closure) |
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
| 1 | reviewing SKILL.md parenthetical includes "claim layer" | `grep 'claim layer' skills/reviewing/SKILL.md` | verified: line 90 reads "(evidence-tier ladder, claim layer, and layer-mismatch, defined in the repo's `CONCEPTS.md` where present)" | Met |
| 2 | verification.md ambiguous "it" removed | `grep 'name the tier cited' skills/shipping/references/verification.md` | verified: line 39 reads "-- name the tier cited whenever reporting evidence for a claim:" — imperative, no pronoun | Met |
| 3 | validate.sh passes | `bash scripts/validate.sh` | verified: ALL CHECKS PASSED | Met |
| 4 | ROADMAP P4 row closed | `grep '~~Vocabulary polish' ROADMAP.md` | verified: row strikethrough with **Done** marker | Met |

## Carry-forward from previous retro

| Item | Status | Evidence |
|---|---|---|
| check 11 skip-path fixture test (P4) | Not started — trigger did not fire | No validate.sh edits this cycle |

- Previous doc shape: conformant

## Interview Transcript

- Independence level: self-checklist
- Rounds used: 0 (headless mode — mechanical text edits per retro T5 specifications)

| ID | Round | Phase | Probe | Answer | Evidence | Verdict (verbatim) |
|---|---|---|---|---|---|---|
| T1 | — | 3 | Does the claim-layer addition match the original U2-m1 finding? | Yes — the retro T5 stated "reviewing SKILL.md:90 parenthetical omits 'claim layer' though 'the claim's layer' is load-bearing"; the parenthetical now lists it as a canonical term | reviewing SKILL.md:90 vs retro T5 U2-m1 | self-attested |
| T2 | — | 3 | Does the verification.md rephrase resolve the U3-m1 ambiguity? | Yes — imperative "name the tier cited" removes the ambiguous "it" subject entirely; the retro identified "it" = "the ladder" as the confusion point | verification.md:39 vs retro T5 U3-m1 | self-attested |

## Findings

### What worked well

- **What happened**: Five carry-forward items closed in one session across five cycles, all mechanical, all direct-to-main, accumulating zero test failures.
  **Why**: All items had precise repair specifications in their ROADMAP rows (line numbers, exact text to change, canonical term to add). The session built warm context across the skill files.
  **How to apply**: ROADMAP rows with exact repair values enable zero-investigation cycles.
  **Cites**: T1, T2; five commits this session.

### What to improve

- **What happened**: No findings to improve this cycle — the edits matched the retro T5 specification exactly.

### Process observations

- **What happened**: This P4 item waited since 2026-07-24 (6 days, 5 cycles) for an explicit batch selection despite its trigger ("next cycle that edits either file") having plausibly fired during the shipping-skill-polish cycle (which edited the shipping SKILL, not verification.md — the trigger was ambiguous about which "file" qualified).
  **Why**: The trigger named "either file" meaning the two specific targets (reviewing SKILL.md and verification.md), not the shipping SKILL.md parent directory.
  **How to apply**: Edit-triggered carry-forward rows should name exact file paths in the trigger, not relative references that require context to resolve.
  **Cites**: ROADMAP row trigger text vs shipping-skill-polish diff.

## Carry-forward items registered

| Item | Type | Priority | Tracked at |
|---|---|---|---|
| (none this cycle) | — | — | — |

## Lessons

- Carry-forward rows that name exact file:line targets and the precise text change are the fastest to close — they need no investigation, no design decisions, and no independent review beyond self-review.

## Compounding

- not attempted — the lesson restates the fix-red-suites finding about repair-value quality
