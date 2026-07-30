# Retro: source-over-memory

- Date: 2026-07-30
- Source: direct-to-main commit `1540323`
- Spec: none (inline design approval)
- Plan: none (skipped — one text edit to verification.md)

## Release data

| Metric | Value |
|---|---|
| **Changed non-test lines** | 2 (verification.md) + 1 (ROADMAP row closure) |
| Commits | 1 |
| Review rounds | 1 (self-review) |
| Comments (fixed / deferred) | 0 / 0 |
| CI failures | 0 |
| Duration (design → push) | ~4 minutes |
| Units planned / completed | n/a (no plan) |

## Success criteria: measured vs declared

(No spec exists — inline design. Measuring against the design's implicit criteria.)

| # | Declared criterion | Measurement (command / rubric) | Measured result | Verdict |
|---|---|---|---|---|
| 1 | Source-over-memory rule added to tracked verification reference | `grep 'Source over memory' skills/shipping/references/verification.md` | verified: "when citing file content in a claim or report, read the file in the current turn — prior reads and conversation memory are not evidence of current disk state" | Met |
| 2 | validate.sh passes | `bash scripts/validate.sh` | verified: ALL CHECKS PASSED | Met |
| 3 | ROADMAP P3 row closed | `grep '~~source-over-memory' ROADMAP.md` | verified: row strikethrough with **Done** marker | Met |

## Carry-forward from previous retro

| Item | Status | Evidence |
|---|---|---|
| (none — previous retro registered no carry-forward items) | — | — |

- Previous doc shape: conformant

## Interview Transcript

- Independence level: self-checklist
- Rounds used: 0 (headless mode — one-line text edit)

| ID | Round | Phase | Probe | Answer | Evidence | Verdict (verbatim) |
|---|---|---|---|---|---|---|
| T1 | — | 3 | Does the placement in verification.md cover the four skills named by the ROADMAP row? | Partially — verification.md is consumed by shipping and reviewing directly; planning and retrospective enforce P3 (fresh evidence) independently but don't consume this file. The cross-cutting coverage is via the local AGENTS.md rule (untracked) and the user's mandatory-reread global rule | verification.md consumers; AGENTS.md (gitignored) | self-attested |

## Findings

### What worked well

- **What happened**: Initial attempt targeted AGENTS.md (gitignored) and CLAUDE.md (symlink to global rules). Both failed, redirecting to verification.md — the tracked, version-controlled evidence reference.
  **Why**: The project's CLAUDE.md is a symlink to a personal global file, and AGENTS.md is gitignored. Neither is appropriate for project-level carry-forward fixes.
  **How to apply**: For project-level rule additions, target tracked skill files or references, not CLAUDE.md (may be a symlink) or AGENTS.md (may be gitignored).
  **Cites**: T1; git error on AGENTS.md staging.

### What to improve

- **What happened**: The ROADMAP row names four skills (planning/shipping/retrospective/compound) but the fix landed in one reference file (verification.md) consumed by two (shipping/reviewing). The other two skills (planning, retrospective) rely on P3 enforcement and the untracked AGENTS.md rule.
  **Why**: Adding the same line to four separate skill files would be redundant. Verification.md is the evidence-rules reference, and the principle is general enough that all skills should follow it. But the coverage is incomplete for clean-install scenarios where AGENTS.md doesn't exist.
  **How to apply**: Accept the partial coverage — the principle is enforced by the user's personal global rule (`mandatory-reread.md`) and the tracked verification reference. A full four-skill fix would be over-engineering for a one-line rule.
  **Cites**: T1.

### Process observations

- **What happened**: No additional observations.

## Carry-forward items registered

| Item | Type | Priority | Tracked at |
|---|---|---|---|
| (none this cycle) | — | — | — |

## Lessons

- Project-level rule additions must target tracked files — CLAUDE.md may be a symlink and AGENTS.md may be gitignored, so neither is reliable for committed carry-forward fixes.

## Compounding

- not attempted — the lesson is a file-targeting observation specific to this repo's setup
