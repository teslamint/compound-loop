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
---

## Log

- <timestamp> design: spec committed (<sha>), user approved
- <timestamp> implement: U1 DONE (<sha>), task review clean
- <timestamp> implement: U2 DONE_WITH_CONCERNS — <one line>, resolved by <sha>
- <timestamp> ship: verification gate — `pytest -q` → 124 passed, 0 failed (fresh)
- <timestamp> retro: archive-destination: .release-loop/archive/YYYY-MM-DD-<feature_slug>
```

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
- `final_action.status` has exactly three transitions: `predicted → determined` in the same edit as its Log line, when the exact command becomes knowable; `determined → predicted` on invalidation (PR closed, new commits on the branch) with the reason logged in the same edit; `determined → executed` in the same edit as the evidence Log line and `merged: true` — the two fields never disagree across a write.
- The `feature:` field stores one validated `feature_slug`. Consumers reject empty, uppercase, separator, dot-segment, or reserved `resume` values. They never silently normalize a stored value.
- The canonical destination evidence is one Log line with the exact marker `archive-destination: <path>`. For interrupted reruns, that logged path is authoritative and must be reused without recalculating a collision suffix.
- A completed record's terminal home is `.release-loop/archive/<YYYY-MM-DD>-<feature_slug>/`. The canonical archive Log line must name that containing directory. One qualifying record reports completion. Zero records trigger reconstruction. Multiple records block as ambiguous.
- Move all remaining children from the selected artifact root before the selected progress record. Move `progress.md` last as the commit point. An interrupted archive reuses its logged destination and moves only remaining children.
- **The `final_action` record is preparation evidence, never approval**: possession of the command is not authorization to run it. Approval evidence lives only in `ship_approved`. `enforces: P7`
