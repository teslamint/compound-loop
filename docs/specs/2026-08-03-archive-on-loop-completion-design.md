---
title: Archive on Loop Completion
status: draft
date: 2026-08-03
schema: spec/v1
---

# Archive on Loop Completion Design

_Created 2026-08-03._

## Overview

`release-loop` mentions archiving only at loop start ("resume it or archive it") and never defines when or how a completed loop's `.release-loop/progress.md` gets archived. This spec adds a completion-archive rule: when Retro completes, the orchestrator flips the record to done, archives it, and only then reports the loop finished.

## User Scenarios

### S1: Normal loop completion

The orchestrator finishes Retro (retro doc committed). Before reporting done, it flips `progress.md` to `phase: done` / `phase_status: complete`, logs the retro evidence, and moves the loop's working state to `.release-loop/archive/<completion-date>-<feature>/`. The completion report names the archive path. The next `/release-loop <feature>` starts against an empty working set with no "resume or archive?" prompt.

### S2: Loop-start against a stale record

A user runs `/release-loop <new feature>` and `progress.md` from a prior loop still exists. The user answers "archive". The orchestrator runs the same archive procedure defined here — including the completed-by-evidence check in S3 — instead of an ad-hoc move.

### S3: Predecessor died after finishing the work

A session finds `progress.md` at `phase: retro / in-progress`, but `git log` shows the retro commit and release exist (observed live on 2026-08-03 with the post-approval-immutability loop). The successor reconstructs completion from git evidence, records a reconstruction Log line citing the commit SHAs, flips the record to done, and archives — the file-over-memory rule applied to loop completion.

### S4: Archiving a genuinely incomplete loop

At loop start the user chooses "archive" for a loop that never completed (no retro commit exists). The record is archived as-is with a Log line stating it was archived incomplete at the user's direction — phases are never flipped to done without evidence.

### S5: Crash between edit and move

A session flipped the record to `phase: done` and wrote the archive-destination Log line, then died before (or during) the move. A successor finds either a done-but-unmoved `progress.md`, or working-dir files moved but `progress.md` still in place. The archive procedure is idempotent: a record already at `phase: done` with an archive-destination Log line skips the edit step and performs only the remaining moves.

## Scope

### In

- `skills/release-loop/SKILL.md`: a completion-archive rule (fires after Retro's exit condition) and a named archive procedure that the loop-start "archive" answer reuses.
- `skills/release-loop/SKILL.md` Resuming: `resume` with no `progress.md` checks `.release-loop/archive/` for a matching completed record before rebuilding from git — absent now usually means "completed and archived", no longer only "predecessor died before writing".
- `skills/release-loop/references/progress-schema.md`: one lifecycle rule documenting that a completed record's terminal home is `.release-loop/archive/`, and the working-state list at its gitignore rule extended to include `evidence/`.
- The rule text covers S1-S5 (normal completion, stale-record archive, completed-by-evidence reconstruction, archive-incomplete, interrupted archive).

### Out

- No scripts or automation — this is skill-text (procedure) only, consistent with the rest of `release-loop`.
- No changes to `scripts/validate.sh` (check 11 already skips when `progress.md` is absent).
- No retroactive cleanup of stray files from pre-rule loops (the 2026-07-27 briefs/diffs currently in `.release-loop/` are noted but out of scope).
- No committed durable trace for reconstruction archives (S3): the archived record is gitignored working state by design — git history (the retro commit itself) remains the durable trace, per progress-schema's "durable artifacts are the committed spec/plan/retro docs" rule.
- No changes to other lifecycle skills (`retrospective` stays archive-unaware; the orchestrator owns state, per its "holds no phase logic" contract's inverse: phases hold no orchestration state).

## Assumptions and Preconditions

| Claim | Command | Observed at | Observed result | Evidence source |
|---|---|---|---|---|
| validate.sh tolerates an absent progress.md | `bash -c 'sed -n "415,425p" scripts/validate.sh'` | 2026-08-03T02:33:00Z | check 11 prints `ok: [final-action] no active progress.md — skipped` and exits 0 when the file is absent | Working tree, `scripts/validate.sh:421-425` |
| Archive convention already exists | `ls .release-loop/archive/` | 2026-08-03T02:31:00Z | 23 entries, dominant form `<YYYY-MM-DD>-<feature-slug>/` containing a `progress.md` with `phase: done` / `phase_status: complete` | Local `.release-loop/archive/` (gitignored working state) |
| Completion-archive gap is live, not hypothetical | `git log --oneline -5 main` vs `.release-loop/progress.md` (pre-archive) | 2026-08-03T02:29:00Z | retro commit `90a2d8f` and `f2ea290 Release v0.9.0` existed while progress.md still read `phase: retro / in-progress` | `git log` + archived record `.release-loop/archive/2026-07-31-post-approval-immutability/progress.md` |

## Architecture

One named procedure, two call sites.

**Archive procedure** (defined once in `release-loop`'s SKILL.md, idempotent — safe to re-run after a partial execution):

1. Determine completion from evidence: retro pointer set or retro commit found via `git log` — never from conversation memory. A record already at `phase: done` carrying an archive-destination Log line is an interrupted archive (S5): skip step 2.
2. If completed: in one edit, set `phase: done`, `phase_status: complete`, refresh `updated`, and append Log lines recording (a) the completion evidence (retro commit SHA; reconstruction note when a successor established it) and (b) the archive destination. If not completed and the user directed archiving anyway: append only an archived-incomplete Log line; leave phase fields as they were.
3. Move into `.release-loop/archive/<YYYY-MM-DD>-<feature>/` (on name collision append `-2`, `-3`, ...): first the current contents of `briefs/`, `reports/`, `reviews/`, `evidence/`, then `progress.md` **last** — the `progress.md` move is the commit point, so an interruption always leaves a record in the working dir that keys loop-start rule 3. Working directories start the next loop empty. Archive-dir date per scenario: S1 — completion date UTC, fetched fresh; S3 — the retro commit's date (the loop's own completion era, matching live precedent `2026-07-31-post-approval-immutability`); S4 — the date of the archiving act.

**Call site 1 — Retro phase exit**: after Retro's AUTO gate condition holds (retro committed), the orchestrator runs the archive procedure before reporting the loop done. The completion report includes the archive path. "Stop after merge" already has an anti-pattern row; this adds its sibling: reporting done with a live `progress.md` is an incomplete completion.

**Call site 2 — loop-start rule 3**: the existing "resume it or archive it" question's archive answer executes this same procedure instead of leaving the method undefined.

Ordering constraint: Log lines (including the archive-destination line) are written **before** the move, because the record cannot be edited at its old path after it has moved. The moves come last, `progress.md` after the working dirs; a crash anywhere in between leaves a self-describing done-state record in place, which a successor finishes per S5.

## Testing

Docs-only change; the test is the live loop itself. This cycle's own loop completes under the new rule, providing one end-to-end execution (see Success Criteria 4). `scripts/validate.sh` guards structural regressions.

## Risks

- **Rule fires but move fails mid-way** (e.g. collision, permission): `progress.md` moves last, so an interruption always leaves the done-state record — carrying the archive-destination Log line — in the working dir; a successor finishes the move per S5 (idempotent procedure). Mitigation: move order fixed (working dirs first, `progress.md` last as commit point); collision rule defined.
- **Stray files from older loops get archived into the wrong loop's directory**: accepted — the rule also makes working dirs start empty, so strays self-eliminate after one cycle; pre-existing strays are out of scope.
- **Retro runs interactively and the session ends at the gate**: unchanged from today — the record stays at `retro / in-progress` and S3 covers the successor.

## Success Criteria

1. `skills/release-loop/SKILL.md` defines the archive procedure once, and both call sites (Retro exit, loop-start rule 3) reference it.
   - **Measured by**: `grep -n "archive" skills/release-loop/SKILL.md` — shows the procedure definition and both call sites.
2. The procedure text covers all five scenarios S1-S5.
   - **Measured by**: judgment rubric — a reviewer maps each of S1-S5 to the sentence in SKILL.md that handles it; pass = no scenario unmapped.
3. `skills/release-loop/references/progress-schema.md` documents that a completed record's terminal home is `.release-loop/archive/`.
   - **Measured by**: `grep -n "archive" skills/release-loop/references/progress-schema.md` — at least one lifecycle rule bullet.
4. This loop itself ends archived: after its Retro completes, `.release-loop/progress.md` is absent and the archived record shows `phase: done`.
   - **Measured by**: `test ! -f .release-loop/progress.md && grep -H "phase: done" .release-loop/archive/*archive-on-loop-completion*/progress.md`
5. Structural validation passes.
   - **Measured by**: `bash scripts/validate.sh`

## Open Decisions

- **Archive date semantics** — resolved in Architecture step 3 per scenario (S1: completion date; S3: retro commit's date; S4: date of the archiving act) after independent review flagged the original single-date rule as ambiguous. User may override at the approval gate. Owner: user.
- **Whether `done` becomes a distinct logged phase transition** (a `retro → done` line formally required) or stays implicit in the completion Log line. This spec keeps it implicit; planning may formalize if the schema edit turns out to need it. Owner: `planning`.
