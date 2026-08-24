# progress.md Schema

The selected progress path is the loop's single durable state record (`enforces: P8`). New loops use `.release-loop/runs/<feature_slug>/progress.md`. A valid legacy run can retain `.release-loop/progress.md`. The file contains YAML frontmatter and a human-readable Log section. Consumers reject unknown `schema:` versions.

```markdown
---
schema: release-loop/v1
feature: <feature_slug matching ^[a-z0-9]+(?:-[a-z0-9]+)*$ and not equal to resume>
artifact_root: .release-loop/runs/<feature_slug>
phase: design | plan | implement | review | ship | retro | done | blocked
phase_status: in-progress | waiting-user | blocked | complete
started: <ISO-8601 timestamp>
updated: <ISO-8601 timestamp>          # touched on every write
branch: <current checkout branch; feature branch before handoff, value of base_branch after verified base handoff>
base_branch: <detected base>
flags: [--auto, --skip-design]          # as given, empty list if none

# Artifact pointers (set as each phase produces them)
spec: docs/specs/YYYY-MM-DD-<topic>-design.md
plan: docs/plans/YYYY-MM-DD-NNN-<type>-<name>-plan.md
retro: docs/retros/YYYY-MM-DD-<context>-retro.md

# Approval evidence (USER gates; --skip-design relies on the spec's own
# status: approved plus this record)
design_approved: {by: user, at: <timestamp>}
ship_approved: {by: user | auto, at: <timestamp>, conditions: "CI green, no open P0"}

# Final-action record (preparation evidence, never approval — see Rules)
final_action:
  kind: merge-to-base                   # closed vocabulary; sole value
  status: predicted                     # predicted | determined | executed
  command: null                         # exact command string once determined; no secrets — ambient auth only
  marker: null                          # optional; preparation-not-approval text when present
  updated: <ISO-8601 timestamp>

# Phase counters
current_unit: U3                        # implement phase
ci_attempts: 0                          # cap 3
review_rounds: 0                        # reviewing re-review cap 3
feedback_rounds: 0                      # shipping comment-round cap 4
comments_fixed: 0
comments_deferred: 0
pr: <number | null>
merged: false
blocked_reason: null                    # set when phase_status: blocked

# Durable review registries. New ledgers include them. Legacy ledgers may omit them.
review_counts:
  completeness: exact                   # exact | partial
  counting_started_at: <ISO-8601 timestamp>
  unit_passes: 0
  fix_rounds: 0
  final_passes: 0
  standalone_passes: 0
  findings_fixed: 0
  findings_deferred: 0
review_events:
  - id: <kind>:<subject>:<ordinal>
    kind: unit | fix | final | standalone
    subject: <stable unit or branch subject>
    ordinal: <positive integer allocated once per kind and subject>
    state: started | complete
    reviewed_head: <full Git object ID>
    result_path: <artifact_root>/reviews/events/<round-specific-name>
    result_sha256: <64-char lowercase SHA-256 or null while started>
    outcome: clean | actionable | blocked | null  # null only while started
    finding_inventory: []               # [{fingerprint: <stable ID>, severity: P0 | P1 | P2 | P3, source: structured | review-body | outside-diff}]
    source_review_event: <event ID for fix, otherwise null>
    re_review_of: <prior unit, final, or standalone event ID; otherwise null>
    source_adoption_path: <immutable legacy-source adoption path or null>
    source_adoption_sha256: <64-char lowercase SHA-256 or null>
finding_dispositions:
  - fingerprint: <stable reviewing fingerprint>
    severity: P0 | P1 | P2 | P3
    status: fixed | deferred
    introduced_by: <review event ID>
    resolved_by: <verifying re-review event ID or terminal-triage authority>
    rationale: <required for deferred, optional for fixed>

# Current Git authority and exact-head review gate. New ledgers include both.
current_commit_range:
  base: <full Git object ID or null>
  head: <full Git object ID or null>
review_gate:
  event_id: <final or standalone event ID or null>
  head: <full reviewed Git object ID or null>

# History rewrite evidence. Entries are append-only.
rewrite_approvals:
  - id: <stable rewrite attempt ID>
    state: active | consumed | cancelled | failed
    approver: USER
    session: <current orchestrating session identity>
    timestamp: <ISO-8601 timestamp>
    old_range: {base: <full Git object ID>, head: <full Git object ID>}
    command: <exact rewrite command, no secrets>
    target_base: <exact target base ref>
rewrite_results:
  - approval_id: <rewrite approval ID>
    state: success | failed | cancelled
    exit_status: <integer or null before command>
    verification_command: <exact command or null before command>
    old_range: {base: <full Git object ID>, head: <full Git object ID>}
    new_range: {base: <full Git object ID>, head: <full Git object ID>}
---

## Log

- <timestamp> design: spec committed (<sha>), user approved
- <timestamp> implement: U1 DONE (<sha>), task review clean
- <timestamp> implement: U2 DONE_WITH_CONCERNS — <one line>, resolved by <sha>
- <timestamp> ship: verification gate — `pytest -q` → 124 passed, 0 failed (fresh)
- <timestamp> retro: archive-destination: .release-loop/archive/YYYY-MM-DD-<feature_slug>
```

## Executable integrity guard

The packaged standard-library CLI owns discovery, validation, scope preparation, handoff, and archive movement.
Scope preparation creates no ledger. The orchestrator publishes one complete new ledger.
Archive movement requires canonical destination and phase evidence already present in that ledger.
The CLI never authors archive evidence.
It returns one canonical JSON object after success.
It returns one named diagnostic on stderr after a blocked or invalid transition.
The CLI path is `skills/release-loop/scripts/run-artifact-integrity.py`.

## Rules

- `artifact_root` equals the exact repo-relative directory that contains the selected progress record. New scoped records require this field. A resumed legacy record can add `artifact_root: .release-loop`.
- The four closed physical-root families are scoped active state, legacy active state, terminal archives, and transition handoff.
- Scoped active state permits only the selected `.release-loop/runs/<run_id>` root. Legacy active state permits the root progress file and its four known sibling directories.
- Terminal archive state permits only the collision-resolved `.release-loop/archive/<destination>` root. Handoff state permits only `.release-loop/.handoff`.
- Reject every symlink in each existing source or destination component. Also reject absolute paths, parent escapes, and physical parents outside the applicable closed root.
- Before the first scope write, inspect filesystem entries and `git ls-files -- <artifact_root>`. A nonempty scope requires one matching valid progress record. Any other ignored or tracked entry is an artifact-scope collision.
- Discovery considers the valid legacy record and all valid scoped records. One record selects `resume`. Zero records select `new`. Multiple records select `blocked` until the caller supplies one exact repo-relative progress path.
- Write at the moment of the event, not batched (`enforces: P3` — the record is the evidence).
- **Gate transitions record their evidence inline**: the proving command, its observed result, and the timestamp (see the `ship: verification gate` log line above). A transition line without command + result is a claim, not a record — resumed and headless runs inherit evidence only through these lines. `enforces: P3, P8`
- Timestamps are ISO-8601 with timezone, **fetched fresh via command (`date -u +%Y-%m-%dT%H:%M:%SZ`) at each write — never estimated or interpolated** (pilot-proven: estimated timestamps produced a non-monotonic log).
- **Status flips are atomic with their evidence**: changing `phase`/`phase_status` and writing the explaining Log line (plus `blocked_reason` when the status is blocked) happen in the same edit — a bare `blocked` with `blocked_reason: null` is a schema violation, not a placeholder.
- Corrupt/unparsable file on resume → rebuild frontmatter from git evidence (branch, committed artifacts, PR state via `gh pr view`), keep the old file as `progress.md.corrupt-<timestamp>`, and note the rebuild in the Log. A stored `feature:` that fails the `feature_slug` invariant is the same class of corruption.
- `.release-loop/` contains local working state. Gitignore it by default. Durable spec, plan, and Retro documents remain committed. Corrupt backups stay with their selected artifact root and move into its terminal archive.
- `final_action` is additive and optional on `release-loop/v1`: absence stays valid — consumers reject unknown `schema:` versions, never unknown fields.
- `review_events`, `finding_dispositions`, and `review_counts` are additive. New ledgers include all three. A legacy ledger may add them only with `completeness: partial` and a fresh `counting_started_at`.
- `review_events` is append-only. Derive the next ordinal from the ledger: the first is 1, then each kind and subject advances without gaps. Only a matching started row replays. Duplicate, conflicting, or gapped rows block.
- Reserve one round-specific `result_path` in the started row. Persist `outcome: null` before dispatch. A `fix` row names `source_review_event`; a source re-review names `re_review_of`. A completed row never dispatches again.
- Persist a started `fix` row before each fixer dispatch. A fixer invocation without that durable row blocks before dispatch.
- A historical fix-event migration uses one publisher-owned `review-fix-event-migration/v1` adoption. Validate it with `validate-fix-event-migration.py` before editing the ledger.
- Each migrated row binds one source review, one signed full fix commit, and one publisher-owned fixer report. The adoption binds all rows by path and SHA-256.
- Reject a missing adoption, a wrong source, an unsigned commit, a report mismatch, a duplicate row, an ordinal gap, and a conflicting replay.
- An exact migration replay changes no row or count. New migrated rows increase the `partial` lower-bound `fix_rounds`; they never make legacy totals exact.
- The reviewer body starts with one canonical `review-body/v1` JSON manifest line. It declares outcome and the full P0-P3 inventory. Arbitrary verbatim reviewer bytes follow that first line.
- The manifest outcome is closed: `clean`, `actionable`, or `blocked`. Reject every other value before publication or recovery.
- Derive wrapper outcome and inventory only from that body manifest. Callers cannot supply metadata separately.
- Frame each `review-result/v1` wrapper as one JSON header line followed by the exact body bytes. The header records body byte length and SHA-256 plus event ID, head, `re_review_of`, outcome, and inventory. Validate length, digest, and equality with the body manifest. Delimiter-like bytes inside the body remain valid.
- Publish the validated wrapper through the packaged phase publisher. Use one same-directory temporary path and the reserved create-once final path. Persist the publisher's final SHA-256 in the event.
- A started event without a final result re-dispatches under the same ID. A journal-owned final result completes that event only after wrapper validation. Persist its outcome and full inventory in the completion edit.
- A foreign or different final result blocks with `review-event-conflict`. Never allocate another event to bypass the conflict.
- A complete event must have its immutable result. A missing file blocks with `review-event-integrity: completed review result missing`. A digest mismatch blocks with `review-event-integrity: completed review digest mismatch`.
- A pre-wrapper source may be adopted once through `review-legacy-source-adoption/v1`. The immutable adoption binds source event, exact result path and SHA-256, reviewed head, outcome, and full severity inventory. Preserve the legacy result bytes. Persist the adoption path and SHA-256 on the source event.
- Re-review resolves an adopted source only after validating both immutable digests and every adoption field. A mismatched path, result digest, head, outcome, inventory, or source event blocks.
- Phase-gate reuse requires sealed outcome `clean` and a successful exact inventory/disposition clean gate. `actionable` and `blocked` events never reuse.
- `current_commit_range.base` is `git merge-base <base_branch> HEAD`. Its `head` is the full `git rev-parse HEAD` object ID. Validate both on resume, Retro entry, and each shipping rebase.
- A descendant head refreshes `current_commit_range`. Any head change clears `review_gate`, even when the new head descends from the old head.
- `review_gate` names only a clean complete `final` or `standalone` event. Its event `reviewed_head`, gate `head`, and the current full `HEAD` must be identical before phase-gate reuse.
- A non-descendant head without one matching active pre-mutation approval blocks with `stale-commit-range`. Never infer authorization from a post-mutation result.
- Persist a current-session USER rewrite approval before mutation. Bind it to one old range, exact rewrite command, and exact target base. An approval from another session or with any mismatched field blocks before command execution.
- After mutation, append one post-mutation result with the approval ID, exit status, exact verification command, old range, and observed new range. A successful result consumes its approval, refreshes `current_commit_range`, and clears `review_gate` without changing historical events or counts.
- A failed rewrite runs its documented abort command, verifies the old range, retains that authoritative range, records the nonzero result, clears any gate invalidated while HEAD changed, and marks the approval failed.
- Pre-command cancellation appends a cancelled result and marks that approval cancelled. Failed and cancelled approvals never authorize retry; a later attempt requires fresh current-session USER approval.
- Persist reviewer output verbatim. Parsing may validate its shape, but no caller may rewrite the authoritative result bytes.
- Each finding uses the reviewing contract's stable fingerprint. `finding_dispositions` contains at most one current row per fingerprint.
- The generic disposition operation records only reasoned `deferred`. It rejects `fixed` from every caller, including the source review itself and fix events.
- Only the verifying re-review operation writes `fixed`. It first validates explicit `re_review_of`, matching kind and subject, sequential source, sealed source and current inventories, and finding absence. Recovery and adopted sources use the same path.
- Terminal triage may set `deferred` only with a rationale. Record its original severity. Deferred findings remain in accounting, but only deferred P3 may satisfy a clean gate. P0-P2 require `fixed`.
- Derive `review_counts` after every registry transition. Count complete events by kind. Derive finding totals from current disposition rows. Never increment these counters directly.
- Write the event or disposition transition, derived counters, result pointer, and evidence Log line in one ledger edit. Replaying one event ID changes none of them.
- `final_action.status` has exactly three transitions: `predicted → determined` in the same edit as its Log line, when the exact command becomes knowable; `determined → predicted` on invalidation (PR closed, new commits on the branch) with the reason logged in the same edit; `determined → executed` in the same edit as the evidence Log line and `merged: true` — the two fields never disagree across a write.
- The `feature:` field stores one validated `feature_slug`. Consumers reject empty, uppercase, separator, dot-segment, or reserved `resume` values. They never silently normalize a stored value.
- The canonical destination evidence is one Log line with the exact marker `archive-destination: <path>`. For interrupted reruns, that logged path is authoritative and must be reused without recalculating a collision suffix.
- Completed archive evidence is `<timestamp> retro: archive-destination: <path>` with `phase: done` and `phase_status: complete`.
- Incomplete archive evidence is `<timestamp> archived-incomplete: archive-destination: <path>`. Both phase fields are mandatory and must use the schema's closed vocabularies. Require `phase != done` and `phase_status != complete`. The transition never flips either field.
- Exactly one archive-evidence mode may exist. Duplicate, mixed-mode, phase-mismatched, or destination-mismatched evidence blocks.
- A completed record's terminal home is `.release-loop/archive/<YYYY-MM-DD>-<feature_slug>/`. The canonical archive Log line must name that containing directory. One qualifying record reports completion. Zero records trigger reconstruction. Multiple records block as ambiguous.
- Move all remaining children from the selected artifact root before the selected progress record. Move `progress.md` last as the commit point. An interrupted archive reuses its logged destination and moves only remaining children.
- Before an archive move, validate the phase-artifact journal and every owned final. A pending publication blocks until recovery or compensation.
- Archive the ownership journal and applicable `.tmp` state with the selected run. Leave no live publisher authority outside the terminal archive.
- **The `final_action` record is preparation evidence, never approval**: possession of the command is not authorization to run it. Approval evidence lives only in `ship_approved`. `enforces: P7`
