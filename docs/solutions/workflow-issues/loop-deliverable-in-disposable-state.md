---
module: release-loop
date: "2026-08-15"
problem_type: workflow_issue
component: loop-state-lifecycle
severity: medium
symptoms:
  - "a post-merge deliverable exists only inside gitignored per-loop state"
  - "the sanctioned worktree cleanup step would destroy an obligation the cycle still owes"
  - "a retro can cite the deliverable only by an on-disk path that no commit contains"
root_cause: disposable per-loop state was used to hold an artifact whose obligation outlives the loop
resolution_type: lifecycle_classification_before_cleanup
applies_when:
  - "a plan unit prepares an outward action that a human executes after merge"
  - "loop state lives in a gitignored directory inside an isolated worktree"
  - "a later lifecycle phase must still read artifacts the earlier phase wrote"
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

## Why This Matters

A gitignored directory is invisible to every mechanical guard the repository has.
Structural validation, body-seal checks, and CI all read committed state, so an
obligation parked in loop state is enforced by nothing but memory. The failure is
silent and total: cleanup succeeds, all checks pass, and the deliverable is gone.

The audit signal is also misleading. A carry-forward row whose trigger class
(edit-based) differs from its risk class (operational) yields a truthful "not
fired" beside a live hazard. Read that combination as an open unknown, never as
an all-clear.

## When to Apply

- Before deleting or pruning any worktree that holds loop state.
- When a plan unit prepares an outward action — issue comment, release
  announcement, external ticket — that a human executes at a gate.
- When a retro cites evidence by a path that `git log` cannot resolve.
- When a carry-forward row's trigger describes a file edit but the risk it names
  is operational.

## Examples

Verifying a transfer instead of asserting it:

```
# both trees, same manifest shape
(cd <worktree>/.release-loop && find . -type f | sort | xargs md5sum) > src.md5
(cd .release-loop && find . -type f -not -path './archive/*' | sort | xargs md5sum) > dst.md5
diff src.md5 dst.md5   # must be empty; 33/33 files matched in this cycle
bash scripts/validate.sh   # [final-action] must flip from "skipped" to "shape valid"
```

Splitting a human-owned outward action so the payload stays postable:

```
.release-loop/briefs/issue-7-body.md      # payload only — posted verbatim
.release-loop/briefs/issue-7-command.md   # command + non-authorization marker
```

Then register the obligation on the durable tracker before cleanup, so the row
survives the worktree that produced it.
