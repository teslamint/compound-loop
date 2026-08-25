---
module: release-loop
date: "2026-08-15"
last_updated: "2026-08-25"
problem_type: workflow_issue
component: loop-state-lifecycle
severity: medium
symptoms:
  - "a post-merge deliverable exists only inside gitignored per-loop state"
  - "the sanctioned worktree cleanup step would destroy an obligation the cycle still owes"
  - "a retro can cite the deliverable only by an on-disk path that no commit contains"
  - "a compound merge command exits nonzero after the remote merge already succeeded"
  - "the surviving worktree and branches make retry versus cleanup ambiguous"
root_cause: remote effects and outliving loop state were coupled to destructive local cleanup without independently persisted outcomes
resolution_type: boundary_verification_and_state_handoff_before_cleanup
applies_when:
  - "a plan unit prepares an outward action that a human executes after merge"
  - "loop state lives in a gitignored directory inside an isolated worktree"
  - "a later lifecycle phase must still read artifacts the earlier phase wrote"
  - "a merge command can perform remote merge and local branch cleanup in one invocation"
  - "the base branch is checked out in a different worktree"
related_components:
  - shipping
  - retrospective
  - worktree-isolation
tags:
  - loop-state
  - worktree-cleanup
  - gitignored-artifacts
  - human-owned-transition
  - durable-tracker
  - partial-success
  - merge-recovery
---

## Context

`.release-loop/` is designed as disposable per-loop state: gitignored, and in the
default-isolation model, local to the feature worktree. The
`retro-interview-integrity` cycle (PR #13, squash-merged as `0086cff`) put three
things there that outlived the loop:

- The live ledger `progress.md`, which the Retro phase still had to read after merge.
- `briefs/issue-7-body.md`, the payload of a correction comment that Success
  Criterion 7 declared and that no skill executes.
- `briefs/issue-7-command.md`, the command and its non-authorization marker.

The sanctioned cleanup step deletes the feature worktree. Running it would have
destroyed an unmet obligation and the only copy of its payload, while every
mechanical check stayed green — `scripts/validate.sh` cannot see a file that no
commit contains.

The previous cycle had already registered the general shape as a carry-forward
item ("transfer live release-loop state to the base checkout before shipping
removes its isolated worktree"). Its trigger was edit-based — a change to
`skills/shipping/` or `skills/release-loop/` — and that trigger correctly did not
fire, because the hazard was operational rather than textual.

PR #15 exposed the same lifecycle hazard through a compound command rather than
an uncommitted payload. `gh pr merge 15 --squash --delete-branch` merged the PR
remotely as `df8f7cac095254959a7a8433c05540f06be41c6d`, then exited 1 when its local
cleanup collided with `main` checked out in the base worktree. The feature
worktree and branch survived. The nonzero exit described the local post-step,
not the already-completed remote merge (`docs/retros/2026-08-16-planning-discrimination-and-verdict-coverage-retro.md`, T5).

## Guidance

Classify every file in loop state before any cleanup, using the obligation it
carries rather than the directory it sits in:

1. **Disposable** — consumed entirely within the phase that wrote it (unit diffs,
   per-unit reports, review scratch). Cleanup may delete these.
2. **Outliving the loop** — read by a later phase, or naming an action still
   owed after merge. These move before cleanup, not during it.

For class 2, apply in order:

- Transfer live ledger state to the base checkout first, and verify the transfer
  mechanically rather than by inspection: compare `md5sum` manifests of both
  trees and require them to be identical, then re-run the repository's structural
  validation and confirm the ledger-dependent checks changed state (here
  `[final-action] no active progress.md — skipped` became
  `[final-action] final_action shape valid`).
- Register any human-owned outward action on a durable tracker (`ROADMAP.md`, an
  issue) **at the moment the plan declares it**, not when a later phase notices
  it missing. The tracker row, not the gitignored brief, is what surfaces the
  obligation.
- Keep the payload and the command in separate files when the command posts a
  file verbatim to a public surface, and keep the non-authorization marker out of
  the payload.

Treat a compound command's effect boundaries independently. After any ambiguous
merge result:

1. Query the remote PR state and require a non-empty merged commit SHA.
2. Inspect worktrees and local/remote feature refs to identify skipped cleanup.
3. Fast-forward the base checkout without rewriting local work and require
   base `HEAD` to equal the merged SHA.
4. Replay the exact full-suite command persisted before the merge gate from
   that merged checkout.
5. Record merged-result verification before starting an eligible release-loop
   transition.
6. Transfer and verify authoritative loop state, then remove the worktree,
   local branch, and remote branch as separate observable operations.

Never infer that all effects failed or all effects succeeded from one compound
exit status. Remote merge, merged-byte verification, state handoff, worktree
removal, and branch deletion are separate recoverable transitions.

Legacy ledgers need a separate recovery path. If `artifact_root: .release-loop`
makes handoff fail before marker creation because no explicit legacy destination
contract exists, preserve the worktree. Do not invent a destination. This is a
lifecycle contract gap, not a failure of run-integrity success criteria. After
first-hand USER approval, create a recovery branch at the verified merged SHA.
Run Retro and archive before cleanup. The durable follow-up is an explicit,
collision-safe legacy destination with an acceptance matrix.

A ledger summary is not a verification transcript. Preserve bounded raw failure
output, exact environment observations, and both RED and GREEN results before
using them for an independent root-cause claim. When those artifacts do not
exist, Retro may record the recovery outcome but must narrow the causal claim.

## Why This Matters

A gitignored directory is invisible to every mechanical guard the repository has.
Structural validation, body-seal checks, and CI all read committed state, so an
obligation parked in loop state is enforced by nothing but memory. The failure is
silent and total: cleanup succeeds, all checks pass, and the deliverable is gone.

The audit signal is also misleading. A carry-forward row whose trigger class
(edit-based) differs from its risk class (operational) yields a truthful "not
fired" beside a live hazard. Read that combination as an open unknown, never as
an all-clear.

Misreading partial success in either direction is destructive. Retrying an
already-completed remote merge can duplicate or conflict with the landed
change; treating exit 1 as harmless can skip merged-result verification or
delete the only authoritative loop state. Persisting each boundary turns an
ambiguous command result into a deterministic recovery path.

## When to Apply

- Before deleting or pruning any worktree that holds loop state.
- When a plan unit prepares an outward action — issue comment, release
  announcement, external ticket — that a human executes at a gate.
- When a retro cites evidence by a path that `git log` cannot resolve.
- When a carry-forward row's trigger describes a file edit but the risk it names
  is operational.
- When `gh pr merge ... --delete-branch` returns nonzero after GitHub may have
  accepted the merge.
- Before retrying a merge whose command also performs local cleanup.
- A phase deliverable was committed inside the worktree rather than left in loop
  state — that is the committed-work counterpart, covered by
  `docs/solutions/workflow-issues/unmerged-branch-work-invisible-to-audit.md`.

## Examples

Verifying a transfer instead of asserting it:

```
# both trees, same manifest shape
(cd <worktree>/.release-loop && find . -type f | sort | xargs md5sum) > src.md5
(cd .release-loop && find . -type f -not -path './archive/*' | sort | xargs md5sum) > dst.md5
diff src.md5 dst.md5   # must be empty; 33/33 files matched in PR #13's transfer
bash scripts/validate.sh   # [final-action] must flip from "skipped" to "shape valid"
```

Splitting a human-owned outward action so the payload stays postable:

```
.release-loop/briefs/issue-7-body.md      # payload only — posted verbatim
.release-loop/briefs/issue-7-command.md   # command + non-authorization marker
```

Then register the obligation on the durable tracker before cleanup, so the row
survives the worktree that produced it.

Recovering a remote-merge/local-cleanup partial success:

```
merged_sha=<remote PR merged commit SHA>
git fetch origin main
git -C <base-checkout> merge --ff-only origin/main
test "$(git -C <base-checkout> rev-parse HEAD)" = "$merged_sha"
(cd <base-checkout> && <exact command persisted before the merge gate>)
# transfer and mechanically verify authoritative live loop state
git worktree remove <feature-worktree>
# preserve any cited pre-squash commits under an evidence ref first
git branch -D <feature-branch>
git push origin --delete <feature-branch>
```

For PR #15, the persisted verification replay passed at the merged SHA, R1 then
recorded successful live-state transfer and base authority, and only afterward
did worktree, local-branch, and remote-branch cleanup run as separate observed steps. For committed work hidden
behind a squash boundary, also apply
`docs/solutions/workflow-issues/unmerged-branch-work-invisible-to-audit.md`.
