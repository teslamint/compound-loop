---
module: shipping
date: 2026-08-25
problem_type: integration_issue
component: merge-gate
severity: medium
symptoms:
  - "`gh pr merge --squash --delete-branch` exits non-zero when the feature branch is checked out in a git worktree"
  - "PR is merged on GitHub but the command reports failure"
  - "Local branch remains in worktree after merge"
root_cause: "git refuses to delete a branch checked out in any worktree; gh --delete-branch invokes local branch deletion as part of its post-merge cleanup"
resolution_type: workflow_change
tags:
  - worktree
  - gh-cli
  - branch-cleanup
  - merge-gate
---

# gh merge --delete-branch Worktree Conflict

## Problem

`gh pr merge <number> --squash --delete-branch` exits non-zero when the feature branch is checked out in a git worktree, even though the squash merge succeeds on GitHub. The error comes from the local branch deletion step — git refuses to delete a branch that is checked out in any worktree.

## Symptoms

- `gh pr merge` reports failure / exits non-zero
- PR state on GitHub is `MERGED` — the squash commit exists on the base branch
- Local feature branch still exists, checked out in the worktree
- Error message references inability to delete the branch but reads as a merge failure

## What Didn't Work

Running `gh pr merge --squash --delete-branch` while a worktree references the feature branch. Git's branch deletion checks all worktrees, not just the current one.

## Solution

Separate the merge from branch cleanup:

```bash
# 1. Merge without --delete-branch
gh pr merge <number> --squash

# 2. Remove worktree (from the main checkout)
git worktree remove <worktree-path>    # --force if untracked files

# 3. Delete local branch (now safe)
git branch -d <feature-branch>
```

If `--delete-branch` was already used and the command exited non-zero, verify the merge succeeded before proceeding:

```bash
gh pr view <number> --json state --jq '.state'
# expect: MERGED
```

## Why This Works

Git's branch deletion and worktree lifecycle are independent operations. The GitHub merge (remote) is unaffected by local branch state. By sequencing worktree removal before branch deletion, each operation finds the preconditions it expects.

## Prevention

- When shipping from a worktree, omit `--delete-branch` and handle cleanup in the correct order (worktree remove → branch delete)
- Check `git worktree list` before the merge command; if the feature branch appears in any worktree, suppress `--delete-branch`
- The shipping skill's Step 8 already prescribes worktree removal as a separate cleanup step
