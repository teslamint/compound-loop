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
```

## Rules

- Write at the moment of the event, not batched (`enforces: P3` — the record is the evidence).
- Timestamps are ISO-8601 with timezone.
- Corrupt/unparsable file on resume → rebuild frontmatter from git evidence (branch, committed artifacts, PR state via `gh pr view`), keep the old file as `progress.md.corrupt-<timestamp>`, and note the rebuild in the Log.
- `.release-loop/` (briefs/, reports/, reviews/, progress.md) is local working state: gitignore it by default; the durable artifacts are the committed spec/plan/retro docs.
