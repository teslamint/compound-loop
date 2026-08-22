---
name: release-loop
description: "Drive a feature from idea to merged PR to retrospective through six phases: Design, Plan, Implement, Review, Ship, Retro. Each phase invokes a standalone compound-loop skill; this skill only sequences, gates, and persists state. /release-loop <feature> or $release-loop <feature>. Bare resume continues a live record or prompts for the feature when none exists."
---

# Release Loop

Orchestrates the full lifecycle. Holds **no phase logic** — every phase is an invocation of its standalone skill; this skill owns sequencing, gates, and `.release-loop/progress.md`. `enforces: P8` (state lives in files).

## Flags

| Flag | Effect |
|------|--------|
| `--auto` | Minimize human gates. The Design gate remains — spec approval is always human (`enforces: P7`) |
| `--skip-design` | Start from Plan. Requires `--spec <path>` whose frontmatter records `status: approved` — the persisted approval evidence. A spec without that record rejects the flag and the loop enters Design normally |
| `--skip-plan --plan <path>` | Start from Implement. Requires the standalone minimum plan contract below; the full planning skill is optional |

## Standalone `--skip-plan` contract


Plan-consumer contract lives in [references/plan-consumer-contract.md](references/plan-consumer-contract.md).

### Minimum `--skip-plan` contract

This gate executes only the minimum plan rules listed here; it does not require a planning-skill sibling to exist.
Each required field (`schema`, `title`, `type`, `status`, `date`, and `execution`) must be present and non-empty; a missing or empty YAML value rejects with that field name.
`--skip-plan` proceeds only for `schema: plan/v1` with `status: approved`.
`--skip-plan` rejects an unknown schema version and every non-approved status.
When the sibling planning validator is available, `--skip-plan` resolves `--plan <path>` to exactly that existing repo plan file, runs the validator against it, and requires exit 0.
When the sibling planning validator is absent, `--skip-plan` resolves `--plan <path>` to exactly that existing repo plan file, applies the local minimum-field fallback to it, and still rejects unknown schema versions.
The fallback does not guess unknown fields or defer eligibility to an unavailable sibling; implementing performs its own full pre-flight after this gate.

The standalone literal set is closed: `required-fields`, `schema`, `approved-status`, and `plan-argument` are the only executable literal rows. An absent or unexpected literal key is contract drift and fails closed; this gate never ignores extra status-set declarations.

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

Before either family runs, revalidate the approved plan's `body_seal`, require the section to name an owner and a matching mutation/failure-state matrix row, and persist the transition start in `progress.md`. A missing, failed, cancelled, or unverifiable transition blocks the loop in Ship; it never advances by silence. Any outward action requires an interactive point-of-risk USER gate with exact target and values; only the human or orchestrating session receiving first-hand approval executes it. A declined, deferred, relayed, or headless outward transition leaves Ship blocked; a matrix-permitted local transition may complete headlessly only when its matrix permits it and proves every outward target unreachable.
A post-approval deviation never overrides a transition by discovery alone. When a sealed transition's literal artifact changed, accept one override only after the current-session USER approves the exact committed addendum path and whole-file SHA-256 and the orchestrator persists one timestamped `transition-override-approved` Log line with transition ID, addendum path/digest, target path, replaced/replacement digests, `approver=USER`, and session identity. Before use, require exactly one matching approval line for the current session, re-hash the tracked byte-clean addendum and target, and prove a single exact override block names the same transition and digests and that the sealed plan contains the replaced digest. Retain prior-session approval lines as history but ignore them for current-session authority. Missing, duplicate-current-session, untracked, dirty, ambiguous, or mismatched override state blocks the transition. Override approval changes only the pinned contract; it is never merge or outward-action consent.
On every Ship entry or resume, before trusting a base `progress.md` or removing a worktree, inspect the base checkout's `.release-loop/.handoff/`. If an owned approved-plan transition operation is present, rerun that named transition from the still-preserved feature worktree before continuing. A missing or mismatched owner marker blocks Ship without deleting the operation.
If the authoritative base ledger records `phase: ship` and `merged: true`, resume never re-enters pre-merge `shipping` or treats “nothing to ship” as completion. Use transition start/acceptance logs plus `.handoff/` state to rerun an interrupted pre-removal transition, finish only pending cleanup after its acceptance, and then run every incomplete post-Ship transition before Retro.

When an approved plan declares a Release-loop transition heading or .release-loop/.handoff/ is non-empty at Ship entry or resume, read references/transition-hooks.md and follow it before proceeding.

## Starting a new loop

1. Parse flags; validate `--skip-*` prerequisites (above). Before any feature-derived lookup or mutation, define one `feature_slug` from explicit feature input. Accept only `^[a-z0-9]+(?:-[a-z0-9]+)*$`, reject the reserved standalone token `resume`, never silently normalize invalid input, ask an interactive caller for a replacement, and return blocked context for an unattended caller. Reuse the exact `feature_slug` for `feature:`, the branch suffix, the archive suffix, and any archived-resume lookup.
2. Detect base branch: `git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|origin/||' || echo main`
3. If `.release-loop/progress.md` exists, stop and ask: resume it or archive it. An `archive it` answer runs the references/resume-and-archive.md's Archive procedure. That procedure selects its evidence-based done-flip or archived-incomplete path. Never silently overwrite a live loop.
4. Create a feature branch from HEAD via `worktree-isolation` by default. Honor an explicit user request to work in the current checkout instead. Treat an explicit request not to create a new worktree as the same exception. Do not create a new branch or worktree when `--skip-*` resumes an existing branch.
5. Write initial `references/progress-schema.md`-conformant state, including `final_action` (`kind: merge-to-base`, `status: predicted`) with a Log line declaring it.
6. Enter the first applicable phase.

On `resume` entry or when an archive is needed, the schema-version rejection rule applies: 1. If `.release-loop/progress.md` exists, read it and reject unknown `schema:` versions rather than guessing. Never silently overwrite a live loop. After Retro's exit condition holds, run the Archive procedure before reporting the loop done; the completion report names that verified archive path.
When the resume argument is given or the Retro exit condition holds, read references/resume-and-archive.md and follow it before proceeding.

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


