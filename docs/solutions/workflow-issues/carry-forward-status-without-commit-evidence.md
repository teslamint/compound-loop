---
module: retrospective
date: 2026-08-25
problem_type: workflow_issue
component: carry-forward-accounting
severity: medium
applies_when:
  - "A retro reconciles carry-forward items from a previous retro"
  - "A carry-forward item spans two or more retro cycles without commit evidence"
tags:
  - carry-forward
  - retro-accounting
  - status-labels
related_components:
  - retrospective
  - release-loop
---

# Carry-Forward Status Without Commit Evidence

## Context

A retrospective reconciled five carry-forward items from the previous retro.
Three items (Ship disposition gate, merge command split, worktree retro merge)
were labeled "In Progress" based on narrative reasoning — "this cycle didn't
touch it" or "this is being done now." An independent facilitator verified each
item against repository evidence and rejected all three: item 1 had zero commits,
item 3 had counter-evidence (the prohibited single-command merge pattern was
reused in this PR), and item 5 cited a future promise rather than a commit SHA.

## Guidance

A carry-forward item labeled "In Progress" must cite at least one commit SHA that
advances toward closure. Without a commit:

- **Not Started**: no work done in this cycle.
- **blocked-on-X**: work attempted but stuck on a named dependency.
- **Regressed**: counter-evidence exists (the anti-pattern was repeated).

"In Progress" with zero commits is aspirational, not factual.

## Why This Matters

Inaccurate status labels erode the carry-forward system's value. When three of
five items claim progress that does not exist, the reconciliation table reads as
healthier than reality. Future retros inherit the inflated status and may
deprioritize items that need attention. The facilitator's convergent finding —
"커밋 SHA 없으면 In Progress 표기 금지" — is a mechanical rule that prevents
this class of error.

## When to Apply

- Reconciling carry-forward items in a retro's Phase 4.
- Reviewing a retro doc's carry-forward table before committing.
- Updating ROADMAP.md status for tracked items.

## Examples

**Counter-evidence regression**: the retro labeled item 3 ("split merge and
cleanup commands") as "In Progress" with "No change in this cycle. PR #26 used
`gh pr merge 26 --squash --delete-branch`." The facilitator rejected this because
`--squash --delete-branch` bundles merge and branch deletion — the exact
anti-pattern the item exists to eliminate. Correct label: "Not Started
(counter-evidence: PR #26 reused the single-command pattern)."

**Promise vs evidence**: item 5 was labeled "In Progress" with "its Retro is
being committed in this session." The facilitator required the actual retro commit
SHA (`8fa20ec`) before accepting — a promise about imminent work is not a commit
proving past work.

See also: `retro-carry-forward-reconciliation-full-commit-range.md` (carry-forward
trigger detection range — adjacent but distinct: that doc addresses *when to
check*, this doc addresses *what evidence a status label requires*).
