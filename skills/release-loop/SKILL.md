---
name: release-loop
description: "Drive a feature from idea to merged PR to retrospective through six phases: Design, Plan, Implement, Review, Ship, Retro. Each phase invokes a standalone compound-loop skill; this skill only sequences, gates, and persists state. /release-loop <feature> or $release-loop <feature>. Bare resume continues a live record; use <feature> resume when no live record exists."
---

# Release Loop

Orchestrates the full lifecycle. Holds **no phase logic**. Each phase invokes its standalone skill. This skill owns sequencing, gates, and the selected progress record. `enforces: P8` (state lives in files).

At entry, set `release_loop_skill_root` to the absolute directory containing the loaded `SKILL.md`. Obtain it from the skill loader's resolved file location, never from the target repository cwd. Reuse that value for every packaged CLI invocation.

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

Before every phase dispatch, persist and send one invocation packet containing the literal field `progress_path: <repo-relative-progress-path>`. Never let a phase infer this value from cwd, a feature name, or a glob. The same packet carries the packaged publisher command for every phase artifact write: `python3 "$release_loop_skill_root/scripts/run-artifact-integrity.py" publish --repo . --progress-path <repo-relative-progress-path> --source <repo-relative-temporary-path> --target <repo-relative-final-path>`. The source is a transition-owned temporary regular file under `<artifact_root>/.tmp/`; the target is its final sibling path under that same root.

| # | Phase | Invokes | Gate |
|---|-------|---------|------|
| 1 | Design | `designing` | **USER** — always human, never auto-skip |
| 2 | Plan | `planning` | AUTO (plan committed, or skip recorded in progress.md) |
| 3 | Implement | `implementing` | AUTO (all units complete, tests pass) |
| 4 | Review | `reviewing` (phase-gate caller shape, pipeline verification path) | AUTO when verdict `clean`; escalate to user when P0/P1 survive the capped re-review loop |
| 5 | Ship | `shipping` | **USER**; with `--auto`: CI green + no open P0 |
| 6 | Retro | `retrospective` (`mode:headless` unless the user asks to run it interactively) | AUTO (retro committed) |

Phase transitions fire only when the invoked skill's exit condition holds — read its terminal state (commit, `mode:agent` envelope, or terminal signal line per `schemas/headless-contract.md`), never assume success from silence. `enforces: P3`

After Review is clean and before `shipping` starts, run the approved plan's `## Release-loop pre-merge verification V1:` contract from `references/transition-hooks.md`. Ship remains blocked until one complete generation digest is accepted and persisted. Resume never infers V1 completion from partial calls or an approval packet.

Before every V1 preparation or resume, require the runner's closed `adapter_eligibility` result before reading or mutating an approval packet, receipt, nonce, or generation. An ineligible adapter blocks with its exact failure and preserves every authority artifact byte-for-byte.

Ship without Retro is an incomplete release: after merge, the loop always enters Retro before reporting done.

## Approved-plan transition hooks

An approved plan may declare only two release-loop-owned transition families, recognized by exact heading shape and never by free-text inference:

Before either family runs, revalidate the approved plan's `body_seal`, require the section to name an owner and a matching mutation/failure-state matrix row, and persist the transition start in `progress.md`. A missing, failed, cancelled, or unverifiable transition blocks the loop in Ship; it never advances by silence. Any outward action requires an interactive point-of-risk USER gate with exact target and values; only the human or orchestrating session receiving first-hand approval executes it. A declined, deferred, relayed, or headless outward transition leaves Ship blocked; a matrix-permitted local transition may complete headlessly only when its matrix permits it and proves every outward target unreachable.
A post-approval deviation never overrides a transition by discovery alone. When a sealed transition's literal artifact changed, accept one override only after the current-session USER approves the exact committed addendum path and whole-file SHA-256 and the orchestrator persists one timestamped `transition-override-approved` Log line with transition ID, addendum path/digest, target path, replaced/replacement digests, `approver=USER`, and session identity. Before use, require exactly one matching approval line for the current session, re-hash the tracked byte-clean addendum and target, and prove a single exact override block names the same transition and digests and that the sealed plan contains the replaced digest. Retain prior-session approval lines as history but ignore them for current-session authority. Missing, duplicate-current-session, untracked, dirty, ambiguous, or mismatched override state blocks the transition. Override approval changes only the pinned contract; it is never merge or outward-action consent.
On every Ship entry or resume, inspect the base checkout's exact `.release-loop/.handoff` root. Do this before trusting the selected progress record or removing a worktree. Rerun an owned operation from the preserved feature worktree. A missing or mismatched owner marker blocks Ship and preserves the operation.
If the authoritative base ledger records `phase: ship` and `merged: true`, resume never re-enters pre-merge `shipping`. Use transition logs and exact handoff state to resume an interrupted transfer. Finish cleanup only after acceptance. Then run each incomplete post-Ship transition before Retro.

When an approved plan declares a Release-loop transition heading, read references/transition-hooks.md. Also read it when `.release-loop/.handoff` is nonempty at Ship entry or resume.

## Starting a new loop

1. Parse flags; validate `--skip-*` prerequisites (above). Before any feature-derived lookup or mutation, define one `feature_slug` from explicit feature input. Accept only `^[a-z0-9]+(?:-[a-z0-9]+)*$`, reject the reserved standalone token `resume`, never silently normalize invalid input, ask an interactive caller for a replacement, and return blocked context for an unattended caller. Reuse the exact `feature_slug` for `feature:`, the branch suffix, the archive suffix, and any archived-resume lookup.
2. Set the new record path to `.release-loop/runs/<feature_slug>/progress.md`. Set `artifact_root` to its containing scope.
3. Run `python3 "$release_loop_skill_root/scripts/run-artifact-integrity.py" discover --repo .` without a selector. With a selector, run `python3 "$release_loop_skill_root/scripts/run-artifact-integrity.py" discover --repo . --progress-path <repo-relative-progress-path>`. Exactly one valid live record resumes without another selector. Multiple valid live records require one exact repo-relative progress path. An unattended ambiguous discovery returns blocked context before any write.
4. If discovery selects a live record, stop and ask: resume it or archive it. An `archive it` answer runs the Archive procedure. Never silently overwrite a live loop. A resume path stays in its existing checkout. Do not create a new branch or worktree when `--skip-*` resumes an existing branch.
5. Detect base branch: `git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|origin/||' || echo main`
6. Create a feature branch from HEAD via `worktree-isolation` by default. Enter the resulting feature checkout before any run-scope preparation. Honor an explicit user request to work in the current checkout instead. Treat an explicit request not to create a new worktree as the same exception.
7. In the feature checkout, run `python3 "$release_loop_skill_root/scripts/run-artifact-integrity.py" initialize --repo . --feature <feature_slug>` before the first state write. Add `--progress-path <repo-relative-progress-path>` only for an exact selected path. For a new run, the command creates only an empty scope and returns its exact progress path with `state: new`. It never writes a partial ledger. An interrupted preparation therefore reruns as `new`. An existing valid progress record returns `state: resume`. Reject absolute paths, parent escapes, symlinks, and physical parents outside the fixed root family. An occupied scope without one matching valid progress record is an artifact-scope collision. List every filesystem or index collision by its exact path. Stop before mutation.
8. Require the initialize result to remain `state: new` with an empty scope in the feature checkout. Write one complete schema-conformant record at the returned progress path. Include its validated `artifact_root`, a predicted `final_action`, `current_commit_range` from full Git object IDs, and an empty `review_gate`. Add the declaration Log line in that same and only ledger write.
9. Enter the first applicable phase.

A blocked initialization reuses the same path and reports the same state. Remove only an empty directory that this attempt created before publication. Remove an injected disposable orphan only after ownership proof. After publication, use resume or archive-incomplete compensation. A published progress record remains resumable. An unattended ambiguity returns blocked context without a prompt. Cancellation before creation changes nothing. Cancellation before publication removes only a proven empty directory.

On `resume` entry or when an archive is needed, read the selected exact progress path. Reject unknown `schema:` versions rather than guessing. Never silently overwrite a live loop. After Retro's exit condition holds, run the Archive procedure before reporting the loop done. The completion report names that verified archive path.
When the resume argument is given or the Retro exit condition holds, read references/resume-and-archive.md and follow it before proceeding.

## Gate handling

- Before answering a pending USER gate, require exactly one valid `pending_gate` from `references/progress-schema.md`. Match its ID, phase, answer class, issue timestamp, absent approval, and absent `gate_answer_receipt`. Atomically reserve the answer receipt and Log line before sending one answer. Then require the owning phase to validate the outcome timestamp and atomically clear the gate and receipt with its outcome Log. Missing, duplicate, stale, mismatched, unknown, already-approved, or previously reserved state blocks without sending an answer.
- USER gates use the harness's blocking question tool per `references/question-tools.md` (plugin root). Record the approval in progress.md (`approved_by: user`, timestamp) — this is the evidence `--skip-design` later relies on.
- **Gate approval is not execution authorization** (pilot-proven, `enforces: P7`): a relayed "the human approved" message lets the loop *advance*, but protected or outward executions (merging to the default branch, pushing) are performed by whoever holds first-hand consent — the human, or the session that received the approval directly. A phase worker acting on relay will be (correctly) refused by harness permission systems; it prepares the exact command and hands it up instead of executing.
- **Prepare before the gate resolves** (`enforces: P8`): before the Ship gate resolves — USER question or `--auto` condition evaluation — the orchestrator verifies `final_action` is `determined` and persisted; a gate must not resolve while the command packet exists only in conversation. After execution, flip the record to `executed` in the same edit as the evidence Log line. The record is preparation evidence, never approval (`enforces: P7`).
- Workers/phase skills never ask the user directly in `--auto` mode; they return structured results and this orchestrator decides (see `references/dispatch-degradation.md`, worker protocol).
- On any gate failure or cap exhaustion escalated by a phase skill: pause the loop, record the blocked state + reason in progress.md, and surface it to the user. Never loop past an escalation.

## State updates

Update the selected exact progress path after every phase transition, unit completion, CI attempt, and review round. Write at the moment of the event. Schema: `references/progress-schema.md`.

Validate `current_commit_range` on resume, Retro entry, and every shipping rebase. Refresh a descendant head and clear `review_gate`. A non-descendant head without matching current-session pre-mutation approval blocks with `stale-commit-range`. Any head change clears `review_gate`; historical review events and derived counts remain unchanged.

Set `review_gate` only from a clean complete final or standalone event whose full `reviewed_head` equals the current full `HEAD`. Phase reuse requires the same event ID and exact head equality.

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
