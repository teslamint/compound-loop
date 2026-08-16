---
module: plan-consumer portability
component: test-dispatch
date: 2026-08-16
problem_type: test_failure
severity: high
symptoms:
  - "Consumer portability reported 233 passed and 0 failed while 54 operative assertions were unreachable"
  - "The assertion count fell from 283 to 233 after an evaluator-dispatch refactor"
root_cause: operative evaluator dispatch replaced by supplemental-only dispatch
resolution_type: code_fix
tags:
  - test-coverage
  - assertion-count
  - operative-evaluator
  - regression
  - review-evidence
---

# Green suites can hide unreachable assertions

## Problem

A deterministic contract suite can stay green after an entire evaluator path becomes unreachable. In PR #16, `scripts/test-plan-consumer-portability.sh` reported 233 passed and 0 failed after a refactor removed the operative adoption evaluator from dispatch. The previous trusted run had reported 283 passed and 0 failed; the 50-count drop was the only immediate signal that the green result no longer represented the same coverage.

Evidence: `.release-loop/reviews/final-findings-round5.md` and `.release-loop/progress.md` entries for commits `63bb016`, `bd5393f`, and `a64f04e`.

## Symptoms

- A refactor changes the number of executed assertions without an intentional fixture or contract change.
- The suite still exits successfully because the removed path is never invoked, so none of its assertions can fail.
- Helper and fixture code remains present, making source-level inspection of definitions insufficient; the missing behavior is at the dispatch site.

## What Didn't Work

Treating `0 failed` as complete evidence did not detect the regression. The harness had replaced the existing `evaluate_adoption_cases(...)` call with the supplemental `adoption_history_boundaries(...)` call instead of invoking both. The remaining assertions were valid and green, but they did not execute the displaced evaluator.

Assertion count alone is not a coverage metric. A high or stable count does not prove semantic correctness, fixture discrimination, or contract conformance. It is useful here because the harness is deterministic and the expected inventory was unchanged.

## Solution

Restore both operative evaluator calls in the dispatch branch. Compare the new run with the immediately preceding trusted result and explain every count delta:

1. Identify the exact dispatch sites, not only the evaluator definitions.
2. Confirm every evaluator family is invoked in the intended mode.
3. Run the deterministic harness and compare its assertion count with the trusted baseline.
4. Require a named fixture, evaluator, or contract change for every intentional delta.

For PR #16, restoring both calls raised the result from 233/0 to 290/0. Later contract additions raised it to 315/0; the final independent review verified the operative call paths and the full 315/0 result in `.release-loop/reviews/final-findings-round7.md`.

## Why This Works

A missing dispatch call removes assertions from execution rather than making them fail. Count continuity detects that class of reachability regression because the expected assertion inventory is part of the harness contract. Reviewing the dispatch code then distinguishes a real coverage loss from an intentional test-count change.

This combines two independent signals:

- behavioral evidence: the current harness remains green;
- inventory evidence: the expected evaluator and assertion cardinality remain reachable.

Neither signal is sufficient alone.

## Prevention

- Preserve baseline evaluator calls when adding boundary or adversarial evaluators; supplemental coverage is additive unless the contract explicitly replaces the old path.
- Record the trusted assertion count beside release evidence for deterministic contract suites.
- Treat an unexplained count reduction as review-blocking even when failures remain zero.
- Add a sentinel assertion or explicit dispatch check for each evaluator family when count totals may legitimately vary.
- Use mutation tests to prove checks discriminate bad states; see `docs/solutions/test-failures/validator-harness-mutation-gap.md` for the complementary mechanism-level pattern.
