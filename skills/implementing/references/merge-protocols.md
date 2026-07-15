# Merge Protocols

Ported from CE ce-work's Phase 1 dual degradation protocols. Applies once a batch of parallel-dispatched units completes. Which protocol governs is decided by whether worktree isolation was available for the batch (see `implementing`'s Parallel Safety Check).

## Subagent isolation, by harness

Give each parallel subagent its own working tree when the harness supports it:

- **Claude Code (`Agent` tool):** pass `isolation: "worktree"` and `run_in_background: true`. The harness creates a per-subagent worktree on its own branch. Verify the worktree root is gitignored before relying on this.
- **Harnesses without built-in worktree isolation** (e.g. Codex `spawn_agent` without a worktree flag): subagents share the orchestrator's directory — use the shared-directory fallback below.

**Permission mode:** omit the `mode` parameter when dispatching subagents so the user's configured permission settings apply; do not force an auto-approve mode — it silently overrides user-level settings.

## Protocol A: Worktree-isolated

Use when every subagent in the batch has its own worktree.

1. Wait for every subagent in the current parallel batch to finish.
2. For each completed subagent, in dependency order: review the worktree's diff against the orchestrator's branch. If the subagent did not commit its own work, stage and commit it inside that worktree.
3. **Merge each subagent's branch into the orchestrator's branch sequentially, in dependency order.** If a merge conflict surfaces, **abort the merge** (`git merge --abort`) and **re-dispatch the conflicting unit serially** against the now-merged tree — never hand-resolve a conflict; hand-resolving silently picks a side and discards one unit's intent. (Predicted overlap from the Parallel Safety Check surfaces here as an expected conflict, not as silent data loss.)
4. After each merge, run the relevant test suite. If tests fail, diagnose and fix before merging the next branch.
5. Update the task tracker and progress ledger — progress is carried by the merge commits, not by editing the plan.
6. After merging, clean up each subagent's worktree and branch, using the absolute path and branch name the subagent returned:
   - Unlock the worktree first if the harness locks per-subagent worktrees: `git worktree unlock <absolute-path>`
   - Remove the worktree: `git worktree remove <absolute-path>`
   - Delete the branch: `git branch -d <branch-name>` (lowercase `-d` refuses to delete an unmerged branch — that refusal is the safety check; if it fails, investigate before forcing)
7. Dispatch the next batch of independent units, or the next dependent unit.

## Protocol B: Shared-directory fallback

Use only when worktree isolation is unavailable for the batch. Constraints exist to prevent git index contention (concurrent staging/committing corrupts the index) and test interference (concurrent test runs pick up each other's in-progress changes).

**Subagent constraints during dispatch:** instruct each subagent explicitly — "Do not stage files (`git add`), create commits, or run the project test suite. The orchestrator handles testing, staging, and committing after all parallel units complete." Subagents in this mode never stage, commit, or run the suite.

**After the batch completes:**

1. Wait for every subagent in the batch to finish before acting on any of their results.
2. **Discovered-collision check**: compare the *actual* files modified by all subagents in the batch — not just their declared `Files:` lists. Plans describe what, not how, so unanticipated file touches are expected; a collision only matters when 2+ subagents in the same batch modified the *same* file. In a shared working directory, only the last writer's version survives — the other unit's changes to that file are silently lost if this check is skipped.
3. If a collision is detected: commit all non-colliding files from all units first, then re-run the affected units serially for the shared file so each builds on the other's committed work.
4. For each completed unit, in dependency order: review the diff, run the relevant test suite, stage only that unit's files, and commit with a conventional message derived from the unit's Goal.
5. If tests fail after committing a unit's changes, diagnose and fix before committing the next unit.
6. Update the task tracker and progress ledger — progress is carried by the commits just made, not by editing the plan.
7. Dispatch the next batch of independent units, or the next dependent unit.

## Anti-patterns

| Don't | Because |
|---|---|
| Hand-resolve a worktree merge conflict | Silently picks a side, discards the other unit's intent — abort and re-dispatch serially instead |
| Let shared-directory subagents stage or commit | Concurrent staging corrupts the git index |
| Skip the discovered-collision check because declared `Files:` lists didn't overlap | Plans describe intent, not every file actually touched; real collisions hide in the gap |
| Merge batches out of dependency order | A later unit may assume an earlier unit's interface already landed |
