---
module: git-workflow
date: "2026-08-22"
problem_type: workflow_issue
component: git-workflow
severity: medium
tags:
  - squash-merge
  - commit-message
  - github-cli
  - pr-merge
---

# Squash-merge commit message not rewritten before merge

## Context

When squash-merging a multi-commit PR via `gh pr merge --squash` or the GitHub
UI, the default commit message is the concatenation of every branch commit's
subject + body. For a 10-commit feature branch this produces a wall of text
with per-unit `Constraint:`, `Confidence:`, `Scope-risk:` trailers,
`Co-Authored-By` lines, and intermediate fix descriptions — none of which
belong in the final squash summary.

## Guidance

The squash-merge commit message should be a single authored summary of what
the PR delivers, not a dump of intermediate development notes. GitHub's
`--squash` flag auto-fills the message from branch commits and applies it
immediately unless overridden.

**Prevention — `gh` CLI path:**

```bash
# Write the summary to a file first (same --body-file guardrail as shipping Step 4).
BODY_FILE=$(mktemp) && cat > "$BODY_FILE" <<'EOF'
refactor(skills): slim instruction payload — relocate rare paths,
compress descriptions, trim bodies

Move 9 rare-path blocks to skill-local references/ files (M1-M9),
compress 13 description fields, and trim 7 phase-skill bodies.
Net reduction: 165,383 → 149,832 B (−9.4%). All gate/integrity
clauses preserved; validate.sh + portability suite green.
EOF

gh pr merge <number> --squash --delete-branch --body-file "$BODY_FILE"
```

Key points:

1. **Always pass `--body-file`** (or `--body`) to `gh pr merge --squash`.
   Without it, the concatenated dump becomes the permanent commit message.
2. **Never use `--body-file -`** or stdin pipes — they can silently produce
   an empty message while `gh` exits 0 (same guardrail as `shipping` Step 4).
3. **For remote-only merges** (when `gh pr merge` runs remotely because the
   base branch is checked out in another worktree), `--body` / `--body-file`
   still applies — `gh pr merge` always operates through the GitHub API, so
   the body is an API parameter regardless of local checkout state. Not
   empirically verified for every `gh` version; if in doubt, confirm with
   `gh pr merge --help` that `--body-file` is listed.
4. **GitHub UI path**: the "Squash and merge" button opens a message editor
   pre-filled with the concatenated commits. Edit it before clicking Confirm.

**Recovery — after the fact:**

A squash-merge commit on a shared/protected branch cannot be amended without
a force-push. If the repo enforces branch protection (no force-push to main),
the message is permanent. Downstream, the unedited message is noise but does
not affect code correctness — it is a cosmetic defect in `git log`.

If force-push is available and no downstream work has been based on the commit:

```bash
# PRECONDITION: HEAD must be the squash-merge commit you want to amend.
# If any commit was made on top (e.g. a version bump, a follow-up fix),
# `git commit --amend` will amend HEAD — the wrong commit.
# In that case use interactive rebase to target the specific commit:
#   git rebase -i <squash-commit>~1
# and change "pick" to "reword" on the squash-merge line.

git rev-parse HEAD  # verify this equals the squash-merge SHA
git commit --amend  # edit the message
git push --force-with-lease origin main
```

This rewrites history and should only be done immediately after the merge,
before any tag, release, or dependent branch references the old SHA.

## Why This Matters

The squash-merge message is the only surviving record of the PR in `git log`
(the branch commits are unreachable after squash). A clean message enables
`git log --oneline` scanning, bisect triage, and CHANGELOG generation. A
concatenated dump forces readers to parse 10 sub-commit blocks to understand
what the PR did — the opposite of the squash's purpose.

## When to Apply

- Every `gh pr merge --squash` invocation by an agent or human.
- The `shipping` skill's Step 7 merge gate already persists the merge command
  before execution — extend this to also persist the squash body (or confirm
  `--body-file` is set) as a pre-merge checklist item.
- Particularly important for multi-commit feature branches (>3 commits) where
  the concatenated default is large enough to be unreadable.
