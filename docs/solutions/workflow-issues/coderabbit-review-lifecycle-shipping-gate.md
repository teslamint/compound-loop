---
module: shipping
date: 2026-08-26
problem_type: workflow_issue
component: external-review-gate
severity: medium
applies_when:
  - "PR created in a repo with CodeRabbit installed"
  - "Shipping Step 7 external review verification gate fires"
  - "CodeRabbit check run detected with artifact-free-success status"
tags:
  - coderabbit
  - external-review
  - shipping-gate
  - pr-merge
---

# CodeRabbit Review Lifecycle in Shipping Gate

## Context

The shipping skill's Step 7 external review verification gate detects review bots (CodeRabbit, SonarCloud, Codacy, etc.) by check-run name and requires review artifacts — submitted reviews or review threads — before merge. A green check-run status alone does not prove a review happened; the gate distinguishes "the bot ran" from "the bot produced review artifacts."

## Guidance

CodeRabbit transitions through these states, each requiring a specific gate response:

1. **Initial skip** (status: `skipped`, reviews: 0, threads: 0) — CodeRabbit did not run a review. Gate fires as `artifact-free-success`. Use `@coderabbitai review` as a PR comment to trigger a manual review.

2. **Pending** (status: `pending`/`in_progress`) — CodeRabbit is running. Gate blocks. Re-fetch all four evidence classes after 60 seconds. Cap at 2 re-fetch attempts. On cap exhaustion, escalate to user with waive/stop options.

3. **CHANGES_REQUESTED** (reviews: >0, threads: >0) — CodeRabbit completed its review with feedback. Gate evaluates as `satisfied` (review artifacts exist). Process all review threads via shipping Step 6's 1:1 checklist discipline. After addressing all threads, post `@coderabbitai resolve` to request re-review.

4. **APPROVED** (reviews: >0, latest review state: APPROVED) — CodeRabbit re-reviewed and approved. Gate satisfied. Proceed to merge-approval question.

5. **Re-evaluation** — After each state change, re-fetch all four evidence classes independently (never from cached Step 5/6 results). The gate re-evaluates the full decision tree.

## Why This Matters

A green CodeRabbit check-run status proves only that the integration handled an event — not that a review ran to completion. Without the artifact-free-success gate, PRs merge with zero review artifacts despite a "passing" CodeRabbit status. This was observed in PR #25: CodeRabbit's check run passed but submitted zero reviews and zero threads.

## When to Apply

- Any PR in a repo with CodeRabbit installed where shipping's external review gate fires
- When CodeRabbit status is green but no review artifacts exist
- When CodeRabbit has CHANGES_REQUESTED and all threads need resolution before merge
- When automating the full shipping pipeline with `--auto` mode (the gate escalates to blocked rather than auto-waiving)

## Examples

**PR #25 in compound-loop** (fuzz-testing feature, 39 files, 11,521 additions):

| Step | State | Action |
|------|-------|--------|
| 1 | CodeRabbit check passed, reviews=0, threads=0 | Gate fired `artifact-free-success` |
| 2 | User chose "Required — request review" | Posted `@coderabbitai review` |
| 3 | 2 re-fetches at 60s: still pending | User chose "Stop" |
| 4 | Later check: CHANGES_REQUESTED, 12 threads | Gate satisfied, entered Step 6 |
| 5 | 2 fixed, 1 declined, 9 not-addressing | All 12/12 resolved |
| 6 | Posted `@coderabbitai resolve` | CodeRabbit submitted APPROVED |
| 7 | Gate satisfied | Merged |
