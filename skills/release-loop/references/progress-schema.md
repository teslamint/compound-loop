# progress.md Schema

`.release-loop/progress.md` is the loop's single durable state record (`enforces: P8`). Markdown with a YAML frontmatter block for machine-read fields and a free-form log section for humans. Consumers reject unknown `schema:` versions.

```markdown
---
schema: release-loop/v1
feature: <short feature name>
phase: design | plan | implement | review | ship | retro | done | blocked
phase_status: in-progress | waiting-user | blocked | complete
started: <ISO-8601 timestamp>
updated: <ISO-8601 timestamp>          # touched on every write
branch: <feature branch>
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
```

## Rules

- Write at the moment of the event, not batched (`enforces: P3` — the record is the evidence).
- **Gate transitions record their evidence inline**: the proving command, its observed result, and the timestamp (see the `ship: verification gate` log line above). A transition line without command + result is a claim, not a record — resumed and headless runs inherit evidence only through these lines. `enforces: P3, P8`
- Timestamps are ISO-8601 with timezone, **fetched fresh via command (`date -u +%Y-%m-%dT%H:%M:%SZ`) at each write — never estimated or interpolated** (pilot-proven: estimated timestamps produced a non-monotonic log).
- **Status flips are atomic with their evidence**: changing `phase`/`phase_status` and writing the explaining Log line (plus `blocked_reason` when the status is blocked) happen in the same edit — a bare `blocked` with `blocked_reason: null` is a schema violation, not a placeholder.
- Corrupt/unparsable file on resume → rebuild frontmatter from git evidence (branch, committed artifacts, PR state via `gh pr view`), keep the old file as `progress.md.corrupt-<timestamp>`, and note the rebuild in the Log.
- `.release-loop/` (briefs/, reports/, reviews/, progress.md) is local working state: gitignore it by default; the durable artifacts are the committed spec/plan/retro docs.
- `final_action` is additive and optional on `release-loop/v1`: absence stays valid — consumers reject unknown `schema:` versions, never unknown fields.
- `final_action.status` has exactly three transitions: `predicted → determined` in the same edit as its Log line, when the exact command becomes knowable; `determined → predicted` on invalidation (PR closed, new commits on the branch) with the reason logged in the same edit; `determined → executed` in the same edit as the evidence Log line and `merged: true` — the two fields never disagree across a write.
- **The `final_action` record is preparation evidence, never approval**: possession of the command is not authorization to run it. Approval evidence lives only in `ship_approved`. `enforces: P7`
