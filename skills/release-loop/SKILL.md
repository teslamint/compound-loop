---
name: release-loop
description: "Drive a feature from idea to merged PR to retrospective through six phases: Design, Plan, Implement, Review, Ship, Retro. Each phase invokes a standalone compound-loop skill; this skill only sequences, gates, and persists state. Use via /release-loop <feature> (Claude Code) or $release-loop <feature> (Codex). Bare resume continues a live record; use <feature> resume when no live record exists."
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
| 2 | Plan | `planning` | AUTO (plan committed, or skip recorded in progress.md) |
| 3 | Implement | `implementing` | AUTO (all units complete, tests pass) |
| 4 | Review | `reviewing` (phase-gate caller shape, pipeline verification path) | AUTO when verdict `clean`; escalate to user when P0/P1 survive the capped re-review loop |
| 5 | Ship | `shipping` | **USER**; with `--auto`: CI green + no open P0 |
| 6 | Retro | `retrospective` (`mode:headless` unless the user asks to run it interactively) | AUTO (retro committed) |

Phase transitions fire only when the invoked skill's exit condition holds — read its terminal state (commit, `mode:agent` envelope, or terminal signal line per `schemas/headless-contract.md`), never assume success from silence. `enforces: P3`

Ship without Retro is an incomplete release: after merge, the loop always enters Retro before reporting done.

## Starting a new loop

1. Parse flags; validate `--skip-*` prerequisites (above).
2. Detect base branch: `git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|origin/||' || echo main`
3. If `.release-loop/progress.md` exists, stop and ask: resume it or archive it. An `archive it` answer runs the `## Completing and archiving` section's Archive procedure. That procedure selects its evidence-based done-flip or archived-incomplete path. Never silently overwrite a live loop.
4. Create a feature branch from HEAD (via `worktree-isolation` when isolation is wanted), unless `--skip-*` resumes an existing branch.
5. Write initial `references/progress-schema.md`-conformant state, including `final_action` (`kind: merge-to-base`, `status: predicted`) with a Log line declaring it.
6. Enter the first applicable phase.

## Resuming (`resume` argument)

1. If `.release-loop/progress.md` exists, read it and reject unknown `schema:` versions rather than guessing.
2. If `.release-loop/progress.md` is absent, require an explicit feature selector before any archive lookup. Accept `$release-loop <feature> resume` as that selector. Bare `resume` asks one blocking question for the feature when no live record exists, then waits; do not search `.release-loop/archive/`, inspect branch names, or infer another selector before the user supplies that value. Search completed archives for an exact `feature:` match. When found, report the completed loop and its archive path instead of resuming. When no match exists, reconstruct the predecessor's state from git evidence. If reconstruction proves completion, finish through the `## Completing and archiving` section's Archive procedure; otherwise resume the reconstructed phase and unit.
3. If `.release-loop/progress.md` exists, verify the recorded branch is checked out and its artifact pointers still exist. On mismatch or corruption, rebuild state from git evidence. If reconstruction proves completion, finish through the `## Completing and archiving` section's Archive procedure; otherwise resume the reconstructed phase and unit. **The progress file and `git log` always outrank conversation memory.** `enforces: P8` Verify any `determined` `final_action` against live PR and head state before trusting it. A failed check flips it to `predicted` and logs the reason. The resume report states the record status and includes the command when `determined`.
4. Resume at the recorded or reconstructed phase and unit.

## Completing and archiving

A **Loop archive** moves a loop's local working state to its terminal home. Run this procedure after Retro's exit condition holds (`retro` committed). `enforces: P8`

### Archive procedure

1. Determine completion from the `retro:` pointer or a retro commit found through `git log`, never conversation memory. A record already at `phase: done` with an archive-destination Log line marks an interrupted archive; skip step 2.
2. Choose `.release-loop/archive/<YYYY-MM-DD>-<feature>/`, appending `-2`, `-3`, and so on when needed. Use the fresh UTC completion date for normal completion, the retro commit date for reconstruction, or the archiving date for incomplete work. For completed work, atomically set `phase: done`, set `phase_status: complete`, refresh `updated`, and log the retro commit SHA and destination. Add a reconstruction Log line when a successor established completion. For incomplete work archived at the user's direction, log `archived-incomplete` and the destination without changing phase fields.
3. Move remaining contents from `briefs/`, `reports/`, `reviews/`, and `evidence/` into the destination first. Move `progress.md` last as the commit point. This order makes the procedure idempotent after interruption and leaves the next loop's working directories empty.

After Retro's exit condition holds (`retro` committed), run the Archive procedure before reporting the loop done. The completion report names the archive path.

## Gate handling

- USER gates use the harness's blocking question tool per `references/question-tools.md` (plugin root). Record the approval in progress.md (`approved_by: user`, timestamp) — this is the evidence `--skip-design` later relies on.
- **Gate approval is not execution authorization** (pilot-proven, `enforces: P7`): a relayed "the human approved" message lets the loop *advance*, but protected or outward executions (merging to the default branch, pushing) are performed by whoever holds first-hand consent — the human, or the session that received the approval directly. A phase worker acting on relay will be (correctly) refused by harness permission systems; it prepares the exact command and hands it up instead of executing.
- **Prepare before the gate resolves** (`enforces: P8`): before the Ship gate resolves — USER question or `--auto` condition evaluation — the orchestrator verifies `final_action` is `determined` and persisted; a gate must not resolve while the command packet exists only in conversation. After execution, flip the record to `executed` in the same edit as the evidence Log line. The record is preparation evidence, never approval (`enforces: P7`).
- Workers/phase skills never ask the user directly in `--auto` mode; they return structured results and this orchestrator decides (see `references/dispatch-degradation.md`, worker protocol).
- On any gate failure or cap exhaustion escalated by a phase skill: pause the loop, record the blocked state + reason in progress.md, and surface it to the user. Never loop past an escalation.

## State updates

Update `.release-loop/progress.md` after every phase transition, unit completion, CI attempt, and review round — at the moment it happens, not batched at phase end. Schema: `references/progress-schema.md`.

The `final_action` record is refined at each determination or invalidation point, at the moment of the event like every update above: PR created → `determined` plus the exact merge command; PR closed or new commits after determination → back to `predicted` with the reason logged in the same edit.

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
| Report the loop done with a live progress.md | Run the Archive procedure; the completion report names the archive path |
