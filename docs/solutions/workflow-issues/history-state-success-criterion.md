---
module: planning
date: "2026-08-15"
problem_type: workflow_issue
component: success-criteria
severity: medium
symptoms:
  - "a success criterion defines its evidence as a red test commit, and the plan's own steps never produce one"
  - "the implementer runs red, implements, then commits once, so the red state exists only in a terminal that no longer exists"
  - "the suite is green at every commit in history, and the criterion has nothing to point at after merge"
applies_when:
  - "a spec mandates red-before-green, or a criterion cites a commit, a diff, a tag, or a bisect point as its evidence"
  - "a plan sequences run-test then implement then commit as one unit step"
  - "reviewing a plan whose criteria name a history state rather than a file state"
root_cause: a criterion whose evidence is a state of the commit history is unsatisfiable unless plan steps commit that state deliberately, because running a test leaves no artifact
resolution_type: plan_step_split
related_components:
  - designing
  - implementing
  - reviewing
  - tdd
tags:
  - success-criteria
  - red-before-green
  - commit-sequence
  - evidence-tier
  - history-as-artifact
---

## Context

Success criteria usually name a file state — a command exits 0, a path exists, a
pattern matches. Those are satisfied by the tree at HEAD, so any commit sequence
that reaches the right tree satisfies them.

A criterion that names a **history state** behaves differently. The
`retro-interview-integrity` cycle declared four criteria (SC1–SC4) whose
discrimination claim was established "when that case is committed red per the
Testing section's red-before-green step". The plan's unit steps said: add the
fixture, run the suite, confirm red, implement the change, run again, commit.
One commit per unit.

Both independent plan reviewers found the same blocking defect, and they found it
by reading the commit sequence rather than the prose: the plan claimed
red-before-green while producing a history in which no red state ever existed.
Running a test is not an artifact. The rework split four units into two commits
each — fixture red first, then the change — so the claim became checkable
(`git show <red>` for U1, U3, U4, U5 in that cycle).

## Guidance

At design time, classify each criterion's evidence by what must exist to prove it:

| Evidence class | Proven by | Plan implication |
|---|---|---|
| File state | a command against the working tree | any commit sequence works |
| History state | a commit, diff, tag, or bisect point | the plan must commit that state as its own step |

Then, for every history-state criterion:

1. Name the artifact in the criterion — "commit X shows the fixture failing", not
   "the fixture was run red". The second sentence is unfalsifiable after the fact.
2. Split the plan step that produces it. A unit that must show red then green
   commits twice, and the acceptance check names both commits.
3. Confirm the red commit is safe to land. In this cycle it was safe only because
   the drift suite runs by manual invocation, so `scripts/validate.sh` stayed
   green at every commit. When the red suite is wired into CI or a pre-merge gate,
   a landed red commit breaks the branch — use a squash-preserved sequence, a
   fixture guarded by an opt-in flag, or drop the history-state claim and measure
   discrimination another way.
4. In review, re-derive the criterion against `git log`, not against the plan's
   description of its own behavior.

## Why This Matters

A history-state criterion that no step commits is worse than a missing criterion,
because it reads as strong evidence while being unverifiable. After the squash
merge, `main` holds one commit and the red state is gone — the reviewer who asks
for it a week later gets a prose assertion, which `enforces: P3` treats as no
evidence at all.

This is the same class of defect as a structural check whose enforcement lives in
prose (`docs/solutions/workflow-issues/structural-check-without-execution-evidence.md`):
in both cases the artifact that would falsify the claim was never produced.

## When to Apply

- A spec or repo convention mandates red-before-green or committed-red fixtures.
- A criterion's `Measured by` names a commit, a diff, a bisect, or "before the
  change" state.
- A plan step chains run-test, implement, and commit into one action.
- A review must decide whether a discrimination claim is checkable at all.

## Examples

Unsatisfiable — running is not committing:

```
5. Run ./scripts/test-suite.sh. Confirm the new case fails.
6. Implement the change.
7. Run ./scripts/test-suite.sh. Confirm it passes. Commit.
```

Satisfiable — the red state is a named artifact:

```
5. Add the case. Run ./scripts/test-suite.sh. Confirm it fails, and record the line.
6. Commit the case alone: "test(x): Add <case> red before <change> lands".
7. Implement the change. Run ./scripts/test-suite.sh. Confirm it passes.
8. Commit the change: "fix(x): <change>".
Acceptance: git log --oneline -2 shows the red commit before the green commit.
```
