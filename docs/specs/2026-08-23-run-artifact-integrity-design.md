---
title: Run Artifact Integrity
status: draft
date: 2026-08-23
schema: spec/v1
---

# Run Artifact Integrity Design

_Created 2026-08-23._

## Overview

Release-loop artifacts currently share one mutable directory across runs. Old tracked files can therefore receive new run output despite `.gitignore`. The progress ledger also lacks audited lifecycle review totals and current commit references. This design gives each run one artifact scope and adds durable review aggregates.

## User Scenarios

### S1: A new loop isolates its artifacts

A user runs `$release-loop run-artifact-integrity`. The loop stores its progress, briefs, reports, reviews, and evidence under one run scope. A later run uses a different scope and cannot overwrite these files.

### S2: A tracked target blocks before a write

A repository ignores `.release-loop/` but tracks an old report. A new scoped run preserves the old blob. If its selected scope already contains a tracked path, pre-flight lists each collision and stops before writing.

### S3: Review metrics survive resume

An implementation has one initial unit review, one fix batch, one clean unit re-review, and one final review. The ledger reports two unit passes, one fix round, and one final pass. Replaying a recorded transition does not increment a counter twice.

### S4: A history rewrite refreshes commit evidence

Shipping performs an approved rebase that replaces commit identifiers. The ledger preserves historical review counts and updates its current base and head. An unapproved non-descendant head blocks with `stale-commit-range`.

### S5: Retro reads exact aggregates

Retrospective reads structured review and finding counts. It does not reconstruct totals from narrative log lines. It reports pull request comments separately from internal review findings.

## Scope

### In

- R1: New runs use `.release-loop/runs/<run_id>/` for progress, briefs, reports, reviews, and evidence.
- R2: `run_id` is the validated `feature_slug` for release-loop. Standalone implementing uses the validated approved-plan filename stem.
- R3: New-run pre-flight fails closed when `git ls-files -- <run_root>` returns any path.
- R4: Resume discovers scoped progress records. It selects one live record or requires an exact selector when several exist.
- R5: Legacy root progress remains resumable. It never gains automatic migration or overwrite authority.
- R6: The ledger gains additive lifecycle review counts and current commit-range fields.
- R7: Each completed review or fix transition updates counters once with its stable artifact identity.
- R8: An authorized history rewrite refreshes the structured commit range. An unapproved rewrite blocks.
- R9: Retrospective uses structured lifecycle totals and keeps pull request comment totals separate.

### Out

- Concurrent live loops in one checkout.
- Automatic deletion or untracking of legacy `.release-loop/` files.
- A repository-wide run database or lock service.
- Changes to review lane selection, severity, or round caps.
- Reconstructing old ledgers that predate the additive fields.

## Assumptions and Preconditions

| Claim | Command | Observed at | Observed result | Evidence source |
|---|---|---|---|---|
| Implementing uses fixed root paths for unit artifacts. | `rg -n -e '\.release-loop/briefs/U<N>' -e '\.release-loop/reports/U<N>' -e '\.release-loop/reviews/U<N>' skills/implementing/SKILL.md` | `2026-08-23T12:48:42Z` | Fixed brief, report, and review paths occur in the per-unit loop. | Working tree at `a924a5ba825f` |
| The progress schema has only phase retry and pull request feedback counters. | `sed -n '33,43p' skills/release-loop/references/progress-schema.md` | `2026-08-23T12:48:42Z` | The schema has `review_rounds`, `feedback_rounds`, and comment counters only. | Working tree at `a924a5ba825f` |
| Ignoring `.release-loop/` does not protect an already tracked report. | `git -C /tmp/run-artifact-integrity.19f9e8 ls-files --error-unmatch .release-loop/reports/U1-report.md && git -C /tmp/run-artifact-integrity.19f9e8 status --short` | `2026-08-23T12:45:57Z` | Git reported the tracked path and then ` M .release-loop/reports/U1-report.md`. | Disposable local fixture with signing and CRLF settings disabled |
| The pre-change repository validation gate passes. | `bash scripts/validate.sh` | `2026-08-23T12:43:05Z` | `ALL CHECKS PASSED` | Isolated feature worktree at `a924a5ba825f` |

## Architecture

### Run scope

The orchestrator resolves `run_root` once before the first write. A release-loop scope is `.release-loop/runs/<feature_slug>`. A standalone plan scope uses its validated filename stem as `run_id`. Every consumer receives the exact progress path and derives sibling artifact paths from its containing scope.

New-loop discovery checks both legacy `.release-loop/progress.md` and scoped `runs/*/progress.md` records. Exactly one live record can resume without another selector. Multiple records block until the user selects an exact `run_id`.

Before a new run creates `run_root`, it runs `git ls-files -- <run_root>`. Any output is a collision. The loop reports all returned paths and performs no write. A tracked legacy root report does not collide with a new scoped root, so the new run preserves the legacy blob by construction.

The scoped ledger records `artifact_root: <run_root>` and validates that value on resume. The archive procedure moves only this scope's working directories. It moves scoped `progress.md` last as the archive commit point. Legacy progress follows the old root layout and gains the same tracked-target guard before any new artifact write.

### Review aggregates

New ledgers add this compatible structure:

```yaml
review_counts:
  unit_passes: 0
  fix_rounds: 0
  final_passes: 0
  standalone_passes: 0
  findings_fixed: 0
  findings_deferred: 0
current_commit_range:
  base: <full Git object ID or null>
  head: <full Git object ID or null>
```

The existing `review_rounds` field remains the standalone reviewing retry counter. The existing `feedback_rounds` and comment counters remain pull request feedback fields.

A unit pass is one valid task-review result, including a re-review. A final pass is one valid final-branch result. A standalone pass is one dispatched multi-lane result. Reusing an existing clean final result at the phase gate adds no standalone pass. A fix round is one completed batch from one fixer. It is not a review pass.

Each finding uses the reviewing contract's stable fingerprint. The ledger increments `findings_fixed` or `findings_deferred` once when that fingerprint reaches its terminal disposition. Each counter transition records the result artifact path and an event key in the same ledger edit. Resume ignores an event key already recorded.

Retrospective computes `Review rounds` as `unit_passes + final_passes + standalone_passes`. It shows the component counts and `fix_rounds`. It reports internal finding dispositions separately from pull request comment dispositions.

### Commit-range integrity

`current_commit_range.base` stores `git merge-base <base> HEAD`. `head` stores the full current `HEAD`. Resume, Retro entry, and each shipping rebase validate both fields.

A descendant head is normal progress and refreshes `head`. A non-descendant head requires an authorization record that names old and new base and head values. The rewrite transition updates the structured range and appends one evidence log line. Missing authorization blocks with `stale-commit-range`.

Historical unit log lines remain unchanged. The structured range is the authority for the current branch. A rewrite after a clean final or standalone review invalidates that gate and requires another full-branch review.

## Integration

- `release-loop` owns scope creation, discovery, and archive handoff.
- `planning`, `implementing`, `reviewing`, `shipping`, and `retrospective` use the supplied scoped ledger path.
- `implementing` owns unit, fix, and final counters.
- `reviewing` owns standalone counters and stable finding dispositions.
- `shipping` refreshes commit evidence after an approved rebase.
- `retrospective` validates the current range and renders structured totals.

## Testing

- Add a disposable Git fixture that ignores `.release-loop/` and force-tracks a legacy `U1-report.md`.
- Prove a new scoped run preserves the old index blob, worktree blob, and clean status.
- Prove a tracked path inside the selected scope causes a pre-write collision diagnostic.
- Exercise one actionable unit review, one fix round, one clean re-review, and one final review.
- Replay one event key and prove all counters remain unchanged.
- Perform an authorized non-descendant rewrite before final review. Prove the final range matches Git and earlier counters stay stable.
- Repeat the rewrite without authorization and require `stale-commit-range`.
- Compare one standalone dispatch with one phase-gate reuse. Only the dispatch increments `standalone_passes`.
- Run the full repository gate and every test target affected by changed consumer text.

## Risks

- **Scope discovery could select the wrong run.** Require an exact selector when discovery finds several live records.
- **Legacy resume could overwrite a tracked file.** Apply the tracked-target guard before every legacy artifact write.
- **Counter replay could inflate metrics.** Bind every increment to one stable event key and persisted artifact.
- **A rewrite could preserve counters but invalidate review evidence.** Require another full-branch review after a post-review rewrite.
- **Consumers could disagree on the ledger path.** Store `artifact_root` in the ledger and pass the exact progress path at every phase transition.

## Success Criteria

1. A new run preserves a tracked legacy report while writing all new artifacts under its scoped root.
   - **Measured by**: the run-artifact fixture compares the legacy index blob and worktree blob before and after the new write. It also requires clean legacy-path status.
2. A selected scope with any tracked path stops before its first write and lists the collision.
   - **Measured by**: the collision fixture requires a nonzero result, `artifact scope collision`, the exact path, and unchanged Git state.
3. One actionable unit review, one fix, one clean re-review, and one final review produce exact structured counts.
   - **Measured by**: the review-state fixture requires unit passes `2`, fix rounds `1`, final passes `1`, and no duplicate increment after replay.
4. Standalone review dispatch and phase-gate reuse have distinct count behavior.
   - **Measured by**: the review-state fixture requires standalone passes `1` after both events.
5. An approved history rewrite refreshes current commit references without changing prior event counts.
   - **Measured by**: the rewrite fixture compares stored full object IDs with `git merge-base main HEAD` and `git rev-parse HEAD`.
6. An unapproved non-descendant head fails closed.
   - **Measured by**: the rewrite fixture requires a nonzero result and `stale-commit-range`.
7. Retro can render exact review and finding totals without parsing narrative log prose.
   - **Measured by**: a fixture removes narrative review lines and requires the same totals from structured fields.
8. Existing repository behavior remains green.
   - **Measured by**: `bash scripts/validate.sh` plus every directly affected `scripts/test-*.sh` target exits zero.

## Open Decisions

None. Planning selects file boundaries and test harness placement without changing these contracts.
