---
title: Default Worktree Isolation
status: approved
date: 2026-08-05
schema: spec/v1
---

# Default Worktree Isolation Design

_Created 2026-08-05._

## Overview

The release loop creates an isolated worktree by default for new feature work.
An explicit user request can keep work in the current checkout.

## User Scenarios

### S1: Start a normal release loop

A user starts `$release-loop default-worktree-isolation` without a workspace preference.
The loop creates a feature branch inside an isolated worktree before it writes feature files.

### S2: Request in-place work

A user explicitly requests work in the current checkout.
The loop honors that instruction and creates the feature branch without a new worktree.

### S3: Resume existing work

A user resumes a loop through `--skip-design` or `--skip-plan` on an existing branch.
The loop resumes that branch and does not create a replacement worktree.

## Scope

### In

- Change the new-loop contract from opt-in isolation to default isolation.
- Preserve an explicit user request for in-place work as the opt-out.
- Add a regression check for the default and exception wording.

### Out

- Add a new command-line flag.
- Change the `worktree-isolation` creation algorithm.
- Change resume behavior for existing branches.
- Change cleanup behavior after shipping.

## Assumptions and Preconditions

| Claim | Command | Observed at | Observed result | Evidence source |
|---|---|---|---|---|
| The current release loop makes isolation conditional. | `rg -n "worktree-isolation|isolation is wanted" skills/release-loop/SKILL.md` | `2026-08-05T01:52:28Z` | Starting step 4 says to isolate only when isolation is wanted. | Working tree at `cc9e20a` |
| The isolation skill already honors a declared user preference. | `sed -n '1,120p' skills/worktree-isolation/SKILL.md` | `2026-08-05T01:52:28Z` | Step 0 uses an existing preference and asks only when no preference exists. | Working tree at `cc9e20a` |

## Architecture

The release-loop orchestrator owns the default workspace policy.
It invokes `worktree-isolation` with a declared preference for an isolated worktree.
The isolation skill remains the only owner of workspace detection and creation.

An explicit request to use the current checkout overrides the default.
Equivalent requests to avoid a new worktree have the same effect.
Skip-based resume paths continue to use their existing branch.

## Interface

No new flag is added.
The default applies when the user gives no workspace instruction.
An explicit current-checkout or no-new-worktree instruction is the opt-out interface.

## Integration

The implementation changes three files:

- `skills/release-loop/SKILL.md` defines the default and the explicit exception.
- `scripts/test-release-loop-worktree-default.sh` checks the procedural contract.
- `scripts/validate.sh` invokes the focused regression script.

## Testing

The regression test reads the release-loop skill text.
It fails if the old conditional wording remains.
It also fails if the default or explicit exception is absent.
It asserts that both skip-based resume exceptions remain in the starting contract.

Run the focused regression test before and after the skill edit.
Run `scripts/validate.sh` after the focused test passes.

## Risks

- **Unexpected workspace creation:** The explicit in-place exception preserves user control.
- **Duplicated isolation logic:** The release loop delegates creation to `worktree-isolation`.
- **Resume regression:** The existing skip-resume exception remains unchanged.

## Success Criteria

1. New release loops default to isolated worktrees.
   - **Measured by**: `bash scripts/test-release-loop-worktree-default.sh`
2. An explicit in-place request remains a documented exception.
   - **Measured by**: `bash scripts/test-release-loop-worktree-default.sh`
3. The starting contract preserves both skip-based resume exceptions.
   - **Measured by**: `bash scripts/test-release-loop-worktree-default.sh`
4. Repository structural validation remains green.
   - **Measured by**: `./scripts/validate.sh`

## Open Decisions

None.
