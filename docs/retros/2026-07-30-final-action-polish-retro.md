# Retro: final-action-polish

- Date: 2026-07-30
- Source: direct-to-main commit `31f0998`
- Spec: none (inline design approval)
- Plan: none (skipped — schema field addition + clause edit + check 11 update)

## Release data

| Metric | Value |
|---|---|
| **Changed non-test lines** | 3 (progress-schema.md) + 4 (validate.sh check 11) + 1 (ROADMAP) |
| Commits | 1 |
| Review rounds | 1 (self-review) |
| Comments (fixed / deferred) | 0 / 0 |
| CI failures | 0 |
| Duration (design → push) | ~4 minutes |
| Units planned / completed | n/a (no plan) |

## Success criteria: measured vs declared

| # | Declared criterion | Measurement (command / rubric) | Measured result | Verdict |
|---|---|---|---|---|
| 1 | N-1: marker field in schema | `grep 'marker' skills/release-loop/references/progress-schema.md` | verified: `marker: null` in schema block with comment "optional; preparation-not-approval text when present" | Met |
| 2 | N-1: check 11 accepts marker as optional | `bash scripts/validate.sh` with current progress.md (no marker) | verified: ALL CHECKS PASSED — marker absent, no failure | Met |
| 3 | N-2: same-edit clause on predicted→determined | `grep 'predicted → determined' skills/release-loop/references/progress-schema.md` | verified: "in the same edit as its Log line" prepended to the transition description | Met |
| 4 | ROADMAP row closed | `grep '~~final_action.*record polish' ROADMAP.md` | verified: strikethrough with **Done** marker | Met |

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
| T1 | — | 3 | Does separating REQUIRED from OPTIONAL in check 11 prevent future regressions? | Yes — the REQUIRED set enforces the 4 mandatory keys; ALLOWED = REQUIRED | OPTIONAL allows marker without requiring it; adding another optional field in the future only needs an OPTIONAL addition | validate.sh check 11 source | self-attested |

## Findings

### What worked well

- **What happened**: The recurring out-of-schema `note:` field that motivated check 11's creation (final-action-validate cycle) now has a proper schema slot (`marker`). The drift that triggered check 11 is now a feature.
  **Why**: The original drift was the system trying to do something the schema didn't allow. Adding the slot makes the behavior legal rather than repeatedly rejecting it.
  **How to apply**: When a validation check keeps rejecting the same out-of-schema field across multiple cycles, the field may belong in the schema rather than being suppressed.
  **Cites**: T1; check 11 history across 3 retros.

### What to improve

- **What happened**: No findings to improve.

### Process observations

- **What happened**: No additional observations.

## Carry-forward items registered

| Item | Type | Priority | Tracked at |
|---|---|---|---|
| (none this cycle) | — | — | — |

## Lessons

- A validation check that repeatedly rejects the same out-of-schema value is evidence that the schema should expand, not that the value should be suppressed.

## Compounding

- not attempted
