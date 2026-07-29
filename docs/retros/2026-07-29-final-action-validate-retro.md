# Retro: final-action-validate

- Date: 2026-07-29
- Source: direct-to-main commit `149ff52`
- Spec: none (inline design approval)
- Plan: none (skipped — atomic single-check addition)

## Release data

| Metric | Value |
|---|---|
| **Changed non-test lines** | 62 (validate.sh check 11) + 1 (ROADMAP row closure) |
| Commits | 1 |
| Review rounds | 1 (self-review) |
| Comments (fixed / deferred) | 0 / 0 |
| CI failures | 0 |
| Duration (design → push) | ~8 minutes |
| Units planned / completed | n/a (no plan) |

## Success criteria: measured vs declared

(No spec exists — inline design. Measuring against the design's implicit criteria.)

| # | Declared criterion | Measurement (command / rubric) | Measured result | Verdict |
|---|---|---|---|---|
| 1 | validate.sh passes with valid final_action | `bash scripts/validate.sh` | verified: ALL CHECKS PASSED, check 11 reports "final_action shape valid (command, kind, status, updated)" | Met |
| 2 | Unknown key detected | Injected `note:` field, ran validate.sh | verified: FAIL: [final-action] unknown final_action key 'note' | Met |
| 3 | Invalid status value detected | Injected `status: in-progress`, ran validate.sh | verified: FAIL: [final-action] final_action.status 'in-progress' not in {'executed', 'predicted', 'determined'} | Met |
| 4 | ROADMAP P3 row closed | `grep '~~Mechanical' ROADMAP.md` | verified: row strikethrough with **Done** marker | Met |

## Carry-forward from previous retro

| Item | Status | Evidence |
|---|---|---|
| (none — previous retro registered no carry-forward items) | — | — |

- Previous doc shape: conformant

## Interview Transcript

- Independence level: self-checklist
- Rounds used: 0 (headless mode — mechanical validate.sh addition)

| ID | Round | Phase | Probe | Answer | Evidence | Verdict (verbatim) |
|---|---|---|---|---|---|---|
| T1 | — | 3 | Does check 11 catch the recurring out-of-schema note: field? | Yes — injected note: field, validate.sh reported FAIL with the exact key name | Test output during implementation | self-attested |
| T2 | — | 3 | Does check 11 skip cleanly when no progress.md exists? | Not directly tested this cycle — will fire on any clean clone or CI run | Code inspection: `if not progress.exists(): print(...skipped); sys.exit(0)` | self-attested |

## Findings

### What worked well

- **What happened**: Two carry-forward items closed in one session (fix-red-suites P2, then final-action-validate P3) — the second built on the first's validated validate.sh state.
  **Why**: Both were self-contained, had fired triggers, and required no design decisions. The sequential approach reused warm context.
  **How to apply**: When multiple fired carry-forward items touch the same file area (validate.sh / test harnesses), batch them in one session.
  **Cites**: T1; both commits on same branch in same session.

### What to improve

- **What happened**: T2 (no-progress.md skip path) was verified by code inspection, not by actually running the check without a progress.md file present. The conditional skip is trivial but untested.
  **Why**: The active loop creates a progress.md, so the skip path can't fire during the loop's own validate.sh run.
  **How to apply**: A fixture test (like test-signal-drift.sh cases) would cover this — run validate.sh in a copy with no .release-loop/ directory.
  **Cites**: T2.

### Process observations

- **What happened**: The check validates the live gitignored working file, not committed artifacts. This is unusual for validate.sh (all other checks validate committed files). It's defensible — the drift happens in the working file — but consumers should know the check is conditional and environment-dependent.
  **Why**: progress.md is never committed; the schema violation (note: field) happened in the working file and propagated to archives.
  **How to apply**: Document check 11's conditional nature in the check's comment block.
  **Cites**: progress-schema.md rule: ".release-loop/ is local working state: gitignore it by default."

## Carry-forward items registered

| Item | Type | Priority | Tracked at |
|---|---|---|---|
| check 11 skip-path fixture test: validate.sh check 11's no-progress.md conditional skip has no fixture case (verified by inspection only, T2) | edge-case | P4 | ROADMAP.md carry-forward |

## Lessons

- Carry-forward items whose triggers have fired in 2+ consecutive cycles without being built are ripe for batch closure — the accumulated context in the ROADMAP row makes implementation near-mechanical.

## Compounding

- not attempted — no reusable lesson this cycle (the lesson restates the fix-red-suites finding about repair-value quality in carry-forward rows)
