# progress.md Schema

`.release-loop/progress.md` is the loop's single durable state record (`enforces: P8`). Markdown with a YAML frontmatter block for machine-read fields and a free-form log section for humans. Consumers reject unknown `schema:` versions.

```markdown
---
schema: release-loop/v1
feature: <feature_slug matching ^[a-z0-9]+(?:-[a-z0-9]+)*$ and not equal to resume>
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

# Optional pending USER gate. It exists only while one release-loop question waits.
pending_gate:
  id: design-approval | ship-approval
  issued_at: <ISO-8601 timestamp>
  expected_answer_class: approve-spec-or-request-revision | merge-or-nonmerge-disposition

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
---

## Log

- <timestamp> design: spec committed (<sha>), user approved
- <timestamp> implement: U1 DONE (<sha>), task review clean
- <timestamp> implement: U2 DONE_WITH_CONCERNS — <one line>, resolved by <sha>
- <timestamp> ship: verification gate — `pytest -q` → 124 passed, 0 failed (fresh)
- <timestamp> retro: archive-destination: .release-loop/archive/YYYY-MM-DD-<feature_slug>
```

## Rules

- Write at the moment of the event, not batched (`enforces: P3` — the record is the evidence).
- **Gate transitions record their evidence inline**: the proving command, its observed result, and the timestamp (see the `ship: verification gate` log line above). A transition line without command + result is a claim, not a record — resumed and headless runs inherit evidence only through these lines. `enforces: P3, P8`
- `pending_gate` is optional and has exactly three fields. `design-approval` belongs only to `phase: design` and `approve-spec-or-request-revision`. `ship-approval` belongs only to `phase: ship` and `merge-or-nonmerge-disposition`.
- A pending gate requires `phase_status: waiting-user` and no matching approval record. Issuing it atomically writes the gate, status, and Log evidence. Approving, revising, or choosing a non-merge disposition atomically removes the gate, changes the status, and logs the outcome.
- Resume sends one answer only when the gate ID, phase, answer class, issue timestamp, and absent approval record match. Missing, duplicate, stale, mismatched, unknown, or already-approved gate state blocks without sending an answer.
- Timestamps are ISO-8601 with timezone, **fetched fresh via command (`date -u +%Y-%m-%dT%H:%M:%SZ`) at each write — never estimated or interpolated** (pilot-proven: estimated timestamps produced a non-monotonic log).
- **Status flips are atomic with their evidence**: changing `phase`/`phase_status` and writing the explaining Log line (plus `blocked_reason` when the status is blocked) happen in the same edit — a bare `blocked` with `blocked_reason: null` is a schema violation, not a placeholder.
- Corrupt/unparsable file on resume → rebuild frontmatter from git evidence (branch, committed artifacts, PR state via `gh pr view`), keep the old file as `progress.md.corrupt-<timestamp>`, and note the rebuild in the Log. A stored `feature:` that fails the `feature_slug` invariant is the same class of corruption.
- `.release-loop/` (briefs/, reports/, reviews/, evidence/, progress.md, progress.md.corrupt-*) is local working state: gitignore it by default; the durable artifacts are the committed spec/plan/retro docs. Root-level `progress.md.corrupt-*` backups move into the same terminal archive as the rebuilt record.
- `final_action` is additive and optional on `release-loop/v1`: absence stays valid — consumers reject unknown `schema:` versions, never unknown fields.
- `final_action.status` has exactly three transitions: `predicted → determined` in the same edit as its Log line, when the exact command becomes knowable; `determined → predicted` on invalidation (PR closed, new commits on the branch) with the reason logged in the same edit; `determined → executed` in the same edit as the evidence Log line and `merged: true` — the two fields never disagree across a write.
- The `feature:` field stores one validated `feature_slug`. Consumers reject empty, uppercase, separator, dot-segment, or reserved `resume` values. They never silently normalize a stored value.
- The canonical destination evidence is one Log line with the exact marker `archive-destination: <path>`. For interrupted reruns, that logged path is authoritative and must be reused without recalculating a collision suffix.
- A completed record's terminal home is `.release-loop/archive/<YYYY-MM-DD>-<feature_slug>/`. A record qualifies as a completed archive candidate only when `feature:` exactly matches the validated selector, `phase: done`, `phase_status: complete`, and the canonical `archive-destination: <path>` Log line names that record's containing archive directory. One qualifying record reports completion. Zero qualifying records trigger reconstruction. Several qualifying records are ambiguous and stop the loop. Legacy records without valid destination evidence do not qualify and therefore reconstruct.
- Move remaining working directories first, then any root-level `progress.md.corrupt-*` backups, then `progress.md` last as the commit point. A live record already at `phase: done` with `phase_status: complete` and one canonical destination path inside `.release-loop/archive/` marks an interrupted archive. Successors reuse that logged destination and perform only the remaining moves.
- **The `final_action` record is preparation evidence, never approval**: possession of the command is not authorization to run it. Approval evidence lives only in `ship_approved`. `enforces: P7`
