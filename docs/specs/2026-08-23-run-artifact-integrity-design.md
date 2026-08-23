---
title: Run Artifact Integrity
status: approved
date: 2026-08-23
schema: spec/v1
---

# Run Artifact Integrity Design

_Created 2026-08-23._

## Overview

Release-loop artifacts currently share one mutable directory across runs. Old tracked files can therefore receive new run output despite `.gitignore`. The progress ledger also lacks audited lifecycle review totals and current commit references. This design gives each run one artifact scope and adds durable review aggregates.

Independent adversarial review ran three correction rounds. This revision incorporates every finding from those rounds. It blocks orphan scopes, seals event results, separates rewrite approval from results, and binds clean review gates to one exact head.

## User Scenarios

### S1: A new loop isolates its artifacts

A user runs `$release-loop run-artifact-integrity`. The loop stores its progress, briefs, reports, reviews, and evidence under one run scope. Completion archives that scope. A later run recreates an empty scope or stops on any orphaned content.

### S2: A tracked target blocks before a write

A repository ignores `.release-loop/` but tracks an old report. A new scoped run preserves the old blob. If its selected scope already contains a tracked path, pre-flight lists each collision and stops before writing.

### S3: Review metrics survive resume

An implementation has one initial unit review, one fix batch, one clean unit re-review, and one final review. The event registry holds four distinct events. Derived counters report two unit passes, one fix round, and one final pass.

### S4: A history rewrite refreshes commit evidence

Shipping performs an approved rebase that replaces commit identifiers. The ledger preserves historical review counts and updates its current base and head. An unapproved non-descendant head blocks with `stale-commit-range`.

### S5: Retro reads exact aggregates

Retrospective reads structured review and finding counts. It does not reconstruct totals from narrative log lines. It reports pull request comments separately from internal review findings.

## Scope

### In

- R1: New runs use `.release-loop/runs/<run_id>/` for progress, briefs, reports, reviews, and evidence.
- R2: `run_id` is the validated `feature_slug` for release-loop. Standalone implementing uses the validated approved-plan filename stem.
- R3: New-run pre-flight fails closed when the selected scope contains any filesystem entry or tracked path.
- R4: Resume discovers scoped progress records. It selects one live record or requires an exact progress path when several exist.
- R5: Legacy root progress remains resumable. It never gains automatic migration or overwrite authority.
- R6: The ledger gains additive lifecycle review counts and current commit-range fields.
- R7: Append-only sealed review events and current finding dispositions derive counters without replay inflation.
- R8: A pre-mutation approval and a post-mutation result refresh an authorized rewrite. An unapproved rewrite blocks.
- R9: Retrospective uses structured lifecycle totals and keeps pull request comment totals separate.
- R10: Each artifact transition rejects symlink components and physical paths outside its closed repository-owned root.

### Out

- Concurrent live loops in one checkout.
- Automatic deletion or untracking of legacy `.release-loop/` files.
- A repository-wide run database or lock service.
- Changes to review lane selection, severity, or round caps.
- Reconstructing exact historic counts for ledgers that predate the additive fields.

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

New-loop discovery checks both legacy `.release-loop/progress.md` and scoped `runs/*/progress.md` records. Exactly one valid live record can resume without another selector. Multiple records block until the user selects an exact repo-relative progress path. A feature name alone never resolves a legacy and scoped ambiguity.

Before a new run creates `run_root`, it checks filesystem entries and `git ls-files -- <run_root>`. An absent or empty scope can start. A nonempty scope resumes only when its exact progress record validates and matches the requested identity. Every other entry is an artifact-scope collision. The loop lists filesystem and tracked paths, then performs no write.

The repository owns four closed physical-root families:

- scoped active state: the selected `.release-loop/runs/<run_id>`;
- legacy active state: the exact root progress file and the `briefs`, `reports`, `reviews`, and `evidence` directories;
- terminal archives: the exact collision-resolved `.release-loop/archive/<destination>`; and
- transition handoff: the exact `.release-loop/.handoff` root.

The loop rejects a symlink in every existing source or destination component. It verifies each physical parent remains below its transition's allowed root before every write or move. No other `.release-loop` child is an implied exception. Failure blocks before any external sentinel can change.

A tracked legacy root report does not collide with a new scoped root. The new run preserves that blob by construction. An ignored orphan inside the selected scope blocks instead of receiving new output.

The scoped ledger records `artifact_root: <run_root>` and validates that value on resume. The archive procedure moves only this scope's working directories. It moves scoped `progress.md` last as the archive commit point.

A selected valid legacy progress record can update itself. Each sibling artifact target receives the tracked-target guard before its first write. The loop never treats the active ledger itself as a sibling collision.

### Review aggregates

New ledgers add this compatible structure:

```yaml
review_counts:
  completeness: exact
  counting_started_at: <ISO-8601 timestamp>
  unit_passes: 0
  fix_rounds: 0
  final_passes: 0
  standalone_passes: 0
  findings_fixed: 0
  findings_deferred: 0
review_events: []
finding_dispositions: []
current_commit_range:
  base: <full Git object ID or null>
  head: <full Git object ID or null>
review_gate:
  event_id: <final or standalone event ID or null>
  head: <full reviewed Git object ID or null>
```

The existing `review_rounds` field remains the standalone reviewing retry counter. The existing `feedback_rounds` and comment counters remain pull request feedback fields.

A unit pass is one valid task-review result, including a re-review. A final pass is one valid final-branch result. A standalone pass is one dispatched multi-lane result. Reusing an existing clean final result at the phase gate adds no standalone pass. A fix round is one completed batch from one fixer. It is not a review pass.

`review_events` is append-only. The orchestrator persists an event with `state: started` before dispatch. Its canonical ID is `<kind>:<subject>:<ordinal>`, where the ledger allocates the ordinal once. Resume reuses a started event and its round-specific artifact path. A completed event never dispatches again.

Kinds are `unit`, `fix`, `final`, and `standalone`. Each complete event records its immutable result path, SHA-256 digest, exact reviewed head, outcome, and finding IDs. A fix event also records its source review event. Review artifacts include the event ordinal, so a re-review cannot overwrite its initial review.

A worker writes a result to a same-directory temporary file. The orchestrator validates it, computes its digest, and publishes it once at the reserved result path. An existing matching result completes the same started event without another dispatch. An existing different result blocks with `review-event-conflict`.

A started event with no published result re-dispatches under the same ID. A temporary partial file has no authority and can be replaced only after its event ownership is proven. A completed event with a missing or mismatched result blocks with `review-event-integrity`. The ledger never allocates a replacement ID to bypass either failure.

Each finding uses the reviewing contract's stable fingerprint. `finding_dispositions` stores one current row per fingerprint. A fix event cannot change a disposition. Only the re-review of its source event can set `fixed` after it verifies that fingerprint is resolved.

The orchestrator or user can set `deferred` at terminal triage with a rationale. Allowed transitions are absent to `fixed` or `deferred`, and `deferred` to `fixed`. `fixed` is terminal. Derived counts reflect current rows, so a deferred finding fixed later decrements deferred and increments fixed.

After each event or disposition transition, the orchestrator derives `review_counts` from both registries. It writes the registry, counters, result artifact path, and evidence log line in one ledger edit. Replaying the same event ID changes nothing.

Retrospective computes `Review rounds` as `unit_passes + final_passes + standalone_passes`. It shows the component counts and `fix_rounds`. It reports internal finding dispositions separately from pull request comment dispositions.

New ledgers set `completeness: exact`. A resumed legacy ledger sets `completeness: partial` and records when structured counting began. It never invents old registry rows. Retro labels those values as a lower bound since that timestamp, not an exact lifecycle total.

### Commit-range integrity

`current_commit_range.base` stores `git merge-base <base> HEAD`. `head` stores the full current `HEAD`. Resume, Retro entry, and each shipping rebase validate both fields.

A descendant head is normal branch progress and refreshes `head`. Any head change clears `review_gate`, regardless of ancestry. A phase gate can reuse a clean result only when `review_gate.head` equals the current full head.

A non-descendant head requires two records. Before mutation, a current-session USER approval records approver, session, timestamp, old range, exact command, and target base. After mutation, a result records the new range, exit status, and verification command. The existing shipping rebase choice supplies the first-hand approval. A post-mutation record alone grants no authority.

The successful result updates the structured range and appends one evidence log line. A missing or mismatched pre-mutation approval blocks with `stale-commit-range`. A failed rewrite retains the old authoritative range and records the failure.

Historical unit log lines remain unchanged. The structured range is the authority for the current branch. Any commit after a clean final or standalone review invalidates that gate and requires another full-branch review.

## Integration

- `release-loop` owns scope creation, discovery, and archive handoff.
- `planning`, `implementing`, `reviewing`, `shipping`, and `retrospective` use the supplied scoped ledger path.
- `implementing` owns unit, fix, and final counters.
- `reviewing` owns standalone counters and stable finding dispositions.
- `shipping` refreshes commit evidence after an approved rebase.
- `retrospective` validates the current range and renders structured totals.

## Testing

- Add a disposable Git fixture that ignores `.release-loop/` and force-tracks a legacy `U1-report.md`.
- Prove one stateful run creates scoped progress, brief, report, review, and evidence artifacts.
- Prove one stateless run creates no evidence artifact in either scoped or legacy roots.
- Prove no new progress, brief, report, or review artifact appears at the legacy root.
- Prove a new scoped run preserves the old index blob, worktree blob, and clean status.
- Leave ignored orphan content without progress. Require the same scope to stop before writing.
- Prove a tracked path inside the selected scope causes a pre-write collision diagnostic.
- Exercise one actionable unit review, one fix round, one clean re-review, and one final review.
- Replay one event ID and prove all registries and counters remain unchanged.
- Recover one started event with a matching sealed result without a new dispatch.
- Reject a conflicting result and a completed event with a missing or changed result.
- Prove a fix event cannot mark a finding fixed before its re-review verifies closure.
- Perform an authorized non-descendant rewrite before final review. Prove the final range matches Git and earlier counters stay stable.
- Repeat the rewrite without authorization and require `stale-commit-range`.
- Compare one standalone dispatch with one phase-gate reuse. Only the dispatch increments `standalone_passes`.
- Resume a legacy ledger and require partial count completeness with a counting start timestamp.
- Point active, archive, and handoff components outside the repository. Each case requires a pre-transition failure and an unchanged external sentinel.
- Run the full repository gate and every test target affected by changed consumer text.

## Risks

- **Scope discovery could select the wrong run.** Require an exact selector when discovery finds several live records.
- **Legacy resume could overwrite a tracked file.** Apply the tracked-target guard before every legacy artifact write.
- **Counter replay could inflate metrics.** Allocate one event ID before dispatch and derive counters from registries.
- **A partial result could become authoritative after a crash.** Publish validated results once and bind each event to its digest.
- **A rewrite could preserve counters but invalidate review evidence.** Require another full-branch review after a post-review rewrite.
- **Consumers could disagree on the ledger path.** Store `artifact_root` in the ledger and pass the exact progress path at every phase transition.

## Success Criteria

1. A new run scopes every applicable artifact class and writes no new legacy-root artifact.
   - **Measured by**: a stateful fixture requires scoped progress, brief, report, review, and evidence paths. A stateless fixture requires no evidence path in either layout. Both reject new root progress, brief, report, and review paths.
2. A new run preserves a tracked legacy report.
   - **Measured by**: the fixture compares the legacy index blob and worktree blob before and after the new write. It also requires clean legacy-path status.
3. A selected scope with tracked or ignored orphan content stops before its first write and lists each collision.
   - **Measured by**: two collision cases require a nonzero result, `artifact scope collision`, exact paths, and unchanged state.
4. One actionable unit review, one fix, one clean re-review, and one final review produce exact structured counts.
   - **Measured by**: the review-state fixture requires unit passes `2`, fix rounds `1`, final passes `1`, and no duplicate increment after replay.
5. Review event recovery preserves one immutable result per event.
   - **Measured by**: matching sealed-result recovery completes once. Conflicting, missing, and digest-mismatched results fail with their defined diagnostics.
6. Only a verifying re-review can mark a finding fixed.
   - **Measured by**: a failed fix leaves the disposition unchanged. A later clean re-review moves the same fingerprint to `fixed` once.
7. Standalone review dispatch and phase-gate reuse have distinct count behavior.
   - **Measured by**: the review-state fixture requires standalone passes `1` after both events.
8. An approved history rewrite refreshes current commit references without changing prior event counts.
   - **Measured by**: the rewrite fixture compares stored full object IDs with `git merge-base main HEAD` and `git rev-parse HEAD`.
9. An unapproved non-descendant head fails closed.
   - **Measured by**: the rewrite fixture requires a nonzero result and `stale-commit-range`.
10. Any head change invalidates an exact-head clean review gate.
   - **Measured by**: descendant and rewritten-head cases both clear `review_gate` and require a new full-branch review.
11. Retro renders exact new-ledger totals and labels legacy structured totals as partial.
   - **Measured by**: a fixture removes narrative review lines and requires the same exact totals from a new ledger. A legacy fixture requires a lower-bound label and counting start timestamp.
12. No active, archive, or handoff transition can redirect artifacts outside the repository.
   - **Measured by**: scoped-active, legacy-active, archive, and handoff symlink cases each require a nonzero result, a path-boundary diagnostic, and an unchanged external sentinel.
13. Existing repository behavior remains green.
   - **Measured by**: `bash scripts/validate.sh` plus every directly affected `scripts/test-*.sh` target exits zero.

## Open Decisions

None. Planning selects file boundaries and test harness placement without changing these contracts.
