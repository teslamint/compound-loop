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

## Approved-plan transition hooks

An approved plan may declare only two release-loop-owned transition families, recognized by exact heading shape and never by free-text inference:

- `## Release-loop Ship-cleanup transition R<N>:` — pass the body-sealed plan to `shipping`; its Step 8 hook runs these local transitions after merged-result verification and before worktree removal.
- `## Release-loop post-Ship completion transition R<N>:` — after `shipping` returns a merged-and-cleaned exit and before Phase 6, the release-loop orchestrator runs these transitions in heading order and requires each section's acceptance evidence before advancing to Retro.

Each transition section's first nonblank body line must be `Matrix rows: T<N>[, T<N> ...]`. Transition IDs are globally unique across both families; a matrix row may be claimed by at most one transition; and every declared row must exist with exactly one evidence owner. Duplicate IDs, duplicate row claims, missing rows, or extra mappings block Ship before any transition runs.

Before either family runs, revalidate the approved plan's `body_seal`, require the section to name an owner and a matching mutation/failure-state matrix row, and persist the transition start in `progress.md`. A missing, failed, cancelled, or unverifiable transition blocks the loop in Ship; it never advances by silence. Local transitions may run headlessly only when their matrix permits it and proves every outward target unreachable. Any outward action requires an interactive point-of-risk USER gate with exact target and values; only the human or orchestrating session receiving first-hand approval executes it, and decline, deferral, relayed approval, or headless mode leaves Ship blocked.

On every Ship entry or resume, before trusting a base `progress.md` or removing a worktree, inspect the base checkout's `.release-loop/.handoff/`. If an owned approved-plan transition operation is present, rerun that named transition from the still-preserved feature worktree before continuing. A missing or mismatched owner marker blocks Ship without deleting the operation.

If the authoritative base ledger records `phase: ship` and `merged: true`, resume never re-enters pre-merge `shipping` or treats “nothing to ship” as completion. Use transition start/acceptance logs plus `.handoff/` state to rerun an interrupted pre-removal transition, finish only pending cleanup after its acceptance, and then run every incomplete post-Ship transition before Retro.

## Starting a new loop

1. Parse flags; validate `--skip-*` prerequisites (above). Before any feature-derived lookup or mutation, define one `feature_slug` from explicit feature input. Accept only `^[a-z0-9]+(?:-[a-z0-9]+)*$`, reject the reserved standalone token `resume`, never silently normalize invalid input, ask an interactive caller for a replacement, and return blocked context for an unattended caller. Reuse the exact `feature_slug` for `feature:`, the branch suffix, the archive suffix, and any archived-resume lookup.
2. Detect base branch: `git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|origin/||' || echo main`
3. If `.release-loop/progress.md` exists, stop and ask: resume it or archive it. An `archive it` answer runs the `## Completing and archiving` section's Archive procedure. That procedure selects its evidence-based done-flip or archived-incomplete path. Never silently overwrite a live loop.
4. Create a feature branch from HEAD via `worktree-isolation` by default. Honor an explicit user request to work in the current checkout instead. Treat an explicit request not to create a new worktree as the same exception. Do not create a new branch or worktree when `--skip-*` resumes an existing branch.
5. Write initial `references/progress-schema.md`-conformant state, including `final_action` (`kind: merge-to-base`, `status: predicted`) with a Log line declaring it.
6. Enter the first applicable phase.

## Resuming (`resume` argument)

1. If `.release-loop/progress.md` exists, read it and reject unknown `schema:` versions rather than guessing.
2. If `.release-loop/progress.md` is absent, require an explicit feature selector before any archive lookup. Accept `$release-loop <feature> resume` as that selector only after it validates to `feature_slug`. Bare `resume` asks one blocking question for the feature when no live record exists, then waits; in unattended mode, return blocked context instead. Do not search `.release-loop/archive/`, inspect branch names, or infer another selector before the user supplies that value. Search completed archives for candidates that satisfy all of these conditions: exact `feature:` match to the validated selector, `phase: done`, `phase_status: complete`, and a valid `archive-destination: <path>` Log entry that names the candidate's containing archive directory. One candidate reports completion and its archive path. Zero candidates enter git-evidence reconstruction. Several candidates stop as ambiguous. Legacy records without valid destination evidence do not qualify and therefore enter reconstruction.
3. If `.release-loop/progress.md` exists, verify the recorded branch is checked out, its stored `feature:` still validates as `feature_slug`, and its artifact pointers still exist before any archive lookup or move. Treat an invalid stored slug as corrupt state. On mismatch or corruption, rebuild state from git evidence.
4. After any reconstruction, finish through the `## Completing and archiving` section's Archive procedure when evidence proves completion. Otherwise, resume the reconstructed phase and unit. **The progress file and `git log` always outrank conversation memory.** `enforces: P8`
5. Verify any `determined` `final_action` against live PR and head state before trusting it. A failed check flips it to `predicted` and logs the reason. The resume report states the record status and includes the command when `determined`.
6. Resume at the recorded or reconstructed phase and unit.

## Completing and archiving

A **Loop archive** moves a loop's local working state to its terminal home. Run this procedure after Retro's exit condition holds (`retro` committed). `enforces: P8`

### Archive procedure

1. Determine completion from the `retro:` pointer or a retro commit found through `git log`, never conversation memory. Validate the stored `feature:` as `feature_slug` before any archive lookup or move; invalid stored state is corruption. A live record already at `phase: done` with `phase_status: complete` and one valid `archive-destination: <path>` Log line marks an interrupted archive when that path stays inside `.release-loop/archive/`. Read that logged destination as authoritative, skip step 2, and do not calculate another collision suffix. Legacy done records without valid destination evidence do not qualify for this fast path and must reconstruct instead.
2. On the first archive attempt, choose `.release-loop/archive/<YYYY-MM-DD>-<feature_slug>/`, appending `-2`, `-3`, and so on when needed. Use the fresh UTC completion date for normal completion, the retro commit date for reconstruction, or the archiving date for incomplete work. Persist the collision-resolved destination before any move with the canonical Log marker `archive-destination: <path>`. For completed work, atomically set `phase: done`, set `phase_status: complete`, refresh `updated`, and log the retro commit SHA plus that exact destination. Add a reconstruction Log line when a successor established completion. For incomplete work archived at the user's direction, log `archived-incomplete` and the destination without changing phase fields.
3. Move remaining contents from `briefs/`, `reports/`, `reviews/`, and `evidence/` into the destination first. Move every root-level `progress.md.corrupt-*` backup into the same destination before the live `progress.md`. On an interrupted rerun, reuse the logged destination and move only the paths that remain in working state. Move `progress.md` last as the commit point.

After Retro's exit condition holds (`retro` committed), run the Archive procedure before reporting the loop done. Retain the exact returned `archive_path` through completion verification. Before reporting done, verify that the live `.release-loop/progress.md` is absent and that this exact path proves the current `feature_slug`, `phase: done`, `phase_status: complete`, `retro:` pointer, retro commit SHA, and `archive-destination` evidence. The completion report names that verified archive path.

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
