---
schema: plan/v1
title: Archive on loop completion for release-loop
type: feat
status: done
date: 2026-08-03
execution: non-code
origin: docs/specs/2026-08-03-archive-on-loop-completion-design.md
body_seal: b34b082c65be97d9f065387cfd83858b8a56e48db49060d3befa64643d9f95f0
completed_by: f3f5cbb4f25c6f400805ad7102447c7b5dac4e65
---

# Archive on Loop Completion Plan

## Goal

Add a completion-archive rule to `release-loop`: a named, idempotent archive procedure defined once in `skills/release-loop/SKILL.md`, invoked from two call sites (Retro phase exit and loop-start rule 3), plus a resume-after-archive check and a progress-schema lifecycle rule. The loop then never reports done while a live `progress.md` remains.

## Architecture notes

- **One procedure, two call sites.** The archive procedure lives in a new SKILL.md section; both the Retro-exit rule and the loop-start "archive" answer reference it by section name. Duplicating the steps at each call site is the failure mode this structure avoids.
- **Move order is the crash-safety mechanism.** Log lines are written before any move (the record cannot be edited at its old path afterward); working-dir contents move first; `progress.md` moves last as the commit point. Any interruption leaves a self-describing done-state record in the working dir, which keys loop-start rule 3 on the next session. Idempotency: a record already at `phase: done` carrying an archive-destination Log line skips the edit step; only the remaining moves run.
- **Archive-dir date is per-scenario** (spec Architecture step 3): S1 normal completion — completion date UTC fetched fresh; S3 evidence-based reconstruction — the retro commit's date; S4 archived-incomplete — the date of the archiving act.
- **`validate.sh` needs no change**: check 11 already prints `ok: [final-action] no active progress.md — skipped` and exits 0 when the file is absent (verified in Assumption Recheck).
- **`retrospective` stays archive-unaware**: the orchestrator owns state; phase skills hold no orchestration state (spec Scope Out).
- **Vocabulary**: CONCEPTS.md "Loop archive" (committed 1c23dd0) is the canonical term; SKILL.md text uses it.

## Assumption Recheck

Origin spec retains three live assumptions; all rerun at planning time (2026-08-03T02:47:00Z).

| Approved claim | Fresh evidence | Outcome |
|---|---|---|
| validate.sh tolerates an absent progress.md | `sed -n '415,425p' scripts/validate.sh` — check 11 prints `ok: [final-action] no active progress.md — skipped`, `sys.exit(0)` | match |
| Archive convention already exists | `ls .release-loop/archive/` — 24 entries (23 at spec time + the immutability-loop archive performed 2026-08-03), dominant form `<YYYY-MM-DD>-<feature-slug>/` | match |
| Completion-archive gap is live, not hypothetical | `head -6 .release-loop/archive/2026-07-31-post-approval-immutability/progress.md` shows `phase: done`/`complete` with reconstruction Log lines; `git log --oneline -3 main` shows `f2ea290`, `0b09ae9`, retro `90a2d8f` behind them | match |

## File structure

- `skills/release-loop/SKILL.md` — archive procedure section, Retro-exit call site, loop-start call site, resume-after-archive check, anti-pattern row (U1, U2).
- `skills/release-loop/references/progress-schema.md` — lifecycle rule and working-state list extension (U3).

## Scenario coverage map

| S-ID | Unit chain | Observable verification |
|---|---|---|
| S1 normal completion | U1 → U3 | This loop's own Retro exit runs the new rule: `test ! -f .release-loop/progress.md && grep -H "phase: done" .release-loop/archive/*archive-on-loop-completion*/progress.md` (spec Success Criterion 4) |
| S2 stale-record archive | U2 | Reviewer walkthrough: the loop-start archive answer resolves to the named procedure with no ad-hoc steps left |
| S3 completed-by-evidence reconstruction | U2 (procedure's evidence step authored in U1) | Reviewer walkthrough; live precedent `.release-loop/archive/2026-07-31-post-approval-immutability/progress.md` matches the reconstruction path |
| S4 archived-incomplete | U2 (procedure's else-branch authored in U1) | Reviewer walkthrough: phase fields untouched, archived-incomplete Log line named |
| S5 interrupted archive | U1 | Reviewer walkthrough: skip-clause plus move-order guarantee text present |

## Implementation Units

Order: U1 → U2 → U3 (U2's call sites reference the section U1 creates).

## U1: SKILL.md — archive procedure, Retro-exit call site, anti-pattern row

Files:
  Create/Modify: skills/release-loop/SKILL.md
Steps:
  1. Add a new section `## Completing and archiving` after `## Resuming (\`resume\` argument)`, containing the **Archive procedure** as three numbered steps mirroring spec Architecture steps 1–3: (a) determine completion from evidence — retro pointer set or retro commit found via `git log`, never conversation memory; a record already at `phase: done` carrying an archive-destination Log line is an interrupted archive: skip step (b); (b) if completed, in one edit set `phase: done`, `phase_status: complete`, refresh `updated`, append Log lines recording the completion evidence (retro commit SHA; reconstruction note when a successor established it) and the archive destination; if not completed and the user directed archiving anyway, append only an archived-incomplete Log line and leave phase fields unchanged; (c) move into `.release-loop/archive/<YYYY-MM-DD>-<feature>/` (collision → append `-2`, `-3`, ...): working-dir contents (`briefs/`, `reports/`, `reviews/`, `evidence/`) first, `progress.md` **last** as the commit point; date per scenario — completion date UTC (normal), the retro commit's date (reconstruction), the archiving act's date (incomplete). State the procedure is idempotent and that working directories start the next loop empty.
  2. In the same section, add the Retro-exit call site: after Retro's exit condition holds (retro committed), run the Archive procedure before reporting the loop done; the completion report names the archive path.
  3. Add an Anti-patterns row: `| Report the loop done with a live progress.md | Run the archive procedure; the completion report names the archive path |`.
  4. Self-review the section against spec S1 and S5 and the prose economy of the surrounding sections (table-and-rule style, `enforces:` tags where a principle applies — this section enforces P8); where the concept is named, use CONCEPTS.md's canonical term "Loop archive".
  5. Commit: "feat(release-loop): Define idempotent archive procedure and Retro-exit call site"
Acceptance: `grep -n "archive" skills/release-loop/SKILL.md` shows the procedure section and the Retro-exit call site; a reader maps S1 and S5 each to a sentence in the section.

## U2: SKILL.md — loop-start archive answer and resume-after-archive check

Files:
  Create/Modify: skills/release-loop/SKILL.md
Steps:
  1. Rewrite `## Starting a new loop` rule 3 so the "archive it" answer executes the Archive procedure from the `## Completing and archiving` section (which decides evidence-based done-flip vs archived-incomplete), instead of leaving the method undefined. Keep the existing "stop and ask" and "never silently overwrite" wording.
  2. In `## Resuming` rule 2, extend the absent-`progress.md` branch: before rebuilding state from git evidence, check `.release-loop/archive/` for a completed record whose `feature:` matches the requested loop; when found, report the loop already completed — naming the archive path — instead of resuming. Keep the existing predecessor-died rebuild path for records not found in the archive.
  3. Self-review both edits against spec S2, S3, S4: the stale-record path, the reconstruction path, and the archived-incomplete path each resolve through the named procedure.
  4. Commit: "feat(release-loop): Route loop-start archive answer and resume through the archive procedure"
Acceptance: a reader maps S2, S3, and S4 each to a sentence in `## Starting a new loop` or `## Resuming`; both call sites name the `## Completing and archiving` section rather than restating its steps.

## U3: progress-schema.md — lifecycle rule and working-state list

Files:
  Create/Modify: skills/release-loop/references/progress-schema.md
Steps:
  1. In the Rules list, extend the working-state rule "`.release-loop/` (briefs/, reports/, reviews/, progress.md) is local working state" to include `evidence/`.
  2. Add one lifecycle rule bullet: a completed record's terminal home is `.release-loop/archive/<YYYY-MM-DD>-<feature>/`; a record at `phase: done` carrying an archive-destination Log line is an interrupted archive — successors skip the edit and perform only the remaining moves (idempotent; `progress.md` moves last as the commit point).
  3. Self-review against spec Success Criterion 3 and the surrounding bullet style.
  4. Commit: "feat(release-loop): Document archive lifecycle in progress schema"
Acceptance: `grep -n "archive" skills/release-loop/references/progress-schema.md` shows at least one lifecycle rule bullet; `bash scripts/validate.sh` passes.

## Mutation/failure-state matrix

No stateful ceremony in the deliverable; no mutation/failure-state matrix required.

(The deliverable is skill text committed to the feature branch; no unit crosses an outward-publication boundary. The archive procedure the text *describes* moves gitignored local working state and is executed by future loops — including this loop's own Retro exit, which serves as S1's observable verification, not as an implementation unit.)

## Carry-forward trigger audit

Audited ROADMAP.md at `f2ea290`: 0 open rows, 0 fired, 0 unobservable.

All eight "Carry-forward from retros" rows are struck through Done/Closed (cleared by `0b09ae9`); no open row exists to classify.

## Deferred to Follow-Up Work

- Pre-rule stray files in `.release-loop/` (2026-07-27 briefs U1–U7, review diffs U1–U6): spec Scope Out — no retroactive cleanup; the new rule's empty-working-dirs property sweeps them into the next completing loop's archive.

## Open unknowns

**Planning-time**: none.

**Implementation-time**:
- Exact placement and prose of the `## Completing and archiving` section (must read like the neighboring sections; substance is fixed by U1 step 1).
- Final wording of the anti-pattern row cell text.
