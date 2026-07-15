---
name: release-loop
description: "Drive a feature from idea to merged PR to retrospective through six phases: Design, Plan, Implement, Review, Ship, Retro. Each phase invokes a standalone compound-loop skill; this skill only sequences, gates, and persists state. Use via /release-loop <feature> (Claude Code) or $release-loop <feature> (Codex); append resume to continue an interrupted loop."
---

# Release Loop

Orchestrates the full lifecycle. Holds **no phase logic** — every phase is an invocation of its standalone skill; this skill owns sequencing, gates, and `.release-loop/progress.md`. `enforces: P8` (state lives in files).

## Flags

| Flag | Effect |
|------|--------|
| `--auto` | Minimize human gates. The Design gate remains — spec approval is always human (`enforces: P7`) |
| `--skip-design` | Start from Plan. Requires `--spec <path>` whose frontmatter records `status: approved` — the persisted approval evidence. A spec without that record rejects the flag and the loop enters Design normally |
| `--skip-plan` | Start from Implement. Requires `--plan <path>` conforming to `schemas/plan-schema.md` |

## Phases

| # | Phase | Invokes | Gate |
|---|-------|---------|------|
| 1 | Design | `designing` | **USER** — always human, never auto-skip |
| 2 | Plan | `planning` | AUTO (plan committed) |
| 3 | Implement | `implementing` | AUTO (all units complete, tests pass) |
| 4 | Review | `reviewing` (phase-gate caller shape, pipeline verification path) | AUTO when verdict `clean`; escalate to user when P0/P1 survive the capped re-review loop |
| 5 | Ship | `shipping` | **USER**; with `--auto`: CI green + no open P0 |
| 6 | Retro | `retrospective` (`mode:headless` unless the user asks to run it interactively) | AUTO (retro committed) |

Phase transitions fire only when the invoked skill's exit condition holds — read its terminal state (commit, `mode:agent` envelope, or terminal signal line per `schemas/headless-contract.md`), never assume success from silence. `enforces: P3`

Ship without Retro is an incomplete release: after merge, the loop always enters Retro before reporting done.

## Starting a new loop

1. Parse flags; validate `--skip-*` prerequisites (above).
2. Detect base branch: `git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|origin/||' || echo main`
3. If `.release-loop/progress.md` exists, stop and ask: resume it or archive it. Never silently overwrite a live loop.
4. Create a feature branch from HEAD (via `worktree-isolation` when isolation is wanted), unless `--skip-*` resumes an existing branch.
5. Write initial `references/progress-schema.md`-conformant state.
6. Enter the first applicable phase.

## Resuming (`resume` argument)

1. Read `.release-loop/progress.md`; reject unknown `schema:` versions rather than guessing.
2. Verify the recorded branch exists and is checked out; verify recorded artifact pointers (spec/plan paths) still exist. On mismatch, corruption, **or a progress.md that is absent entirely** (a predecessor died before writing one — treat identically), rebuild state from git evidence — **the progress file and `git log` always outrank conversation memory**. `enforces: P8`
3. Resume at the recorded phase and unit.

## Gate handling

- USER gates use the harness's blocking question tool per `references/question-tools.md` (plugin root). Record the approval in progress.md (`approved_by: user`, timestamp) — this is the evidence `--skip-design` later relies on.
- **Gate approval is not execution authorization** (pilot-proven, `enforces: P7`): a relayed "the human approved" message lets the loop *advance*, but protected or outward executions (merging to the default branch, pushing) are performed by whoever holds first-hand consent — the human, or the session that received the approval directly. A phase worker acting on relay will be (correctly) refused by harness permission systems; it prepares the exact command and hands it up instead of executing.
- Workers/phase skills never ask the user directly in `--auto` mode; they return structured results and this orchestrator decides (see `references/dispatch-degradation.md`, worker protocol).
- On any gate failure or cap exhaustion escalated by a phase skill: pause the loop, record the blocked state + reason in progress.md, and surface it to the user. Never loop past an escalation.

## State updates

Update `.release-loop/progress.md` after every phase transition, unit completion, CI attempt, and review round — at the moment it happens, not batched at phase end. Schema: `references/progress-schema.md`.

## Worker liveness

Silence is the default failure mode of a long-running dispatched worker — a dead worker looks identical to a busy one. Defenses (pilot-proven):
- Workers write the ledger **before** starting substantive work and at every transition (P8) — death before the first ledger write cost a full phase once.
- Workers send their first gate/status message early, not after long silent stretches.
- The orchestrator watches ledger mtime/phase (not the worker's chat) and treats prolonged no-write as presumed-dead: verify via file evidence, then stop and resume with a successor — the ledger makes replacement cheap.

## Anti-patterns

| Don't | Do |
|-------|-----|
| Auto-skip the Design gate under `--auto` | Design approval is always human |
| Advance a phase because the skill "seemed done" | Check its exit condition evidence |
| Trust conversation memory on resume | Trust progress.md + git log |
| Silently overwrite an existing progress.md | Ask: resume or archive |
| Stop after merge | Retro completes the release |
