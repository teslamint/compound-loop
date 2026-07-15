---
name: tdd
description: Use when implementing any feature or bugfix, before writing implementation code
---

# Test-Driven Development (TDD)

## Overview

Write the test first. Watch it fail. Write minimal code to pass.

**Core principle:** If you didn't watch the test fail, you don't know if it tests the right thing.

**Violating the letter of the rules is violating the spirit of the rules.**

## When to Use

**Always:** new features, bug fixes, refactoring, behavior changes.

**Exceptions (ask your human partner):** throwaway prototypes, generated code, configuration files.

Thinking "skip TDD just this once"? Stop. That's rationalization.

## Execution note (plan-driven mode selection)

`enforces: P1`. A plan's Implementation Unit may carry an `Execution note` selecting this unit's mode. Honor whichever the plan sets — the discipline inside the chosen mode is not negotiable:

- **test-first** (default) — the full Red-Green-Refactor cycle below, unmodified.
- **characterization-first** — legacy code with no tests: first write a test that pins down *current* behavior (it should pass immediately — it documents reality, not intent), then make the actual change test-first from that pinned baseline.
- **skip-test-first** — config or rename-only changes with no behavior change. Reserved for what the plan marks or an explicit human override; never self-selected mid-unit because a test felt inconvenient.

No `Execution note` present → default to test-first.

## The Iron Law

```
NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST
```

Write code before the test? Delete it. Start over.

**No exceptions:** don't keep it as "reference," don't "adapt" it while writing tests, don't look at it. Delete means delete. Implement fresh from tests. Period.

## Red-Green-Refactor

**RED — Write Failing Test.** One minimal test showing what should happen: one behavior, a clear name, real code (no mocks unless unavoidable).

**Verify RED — Watch It Fail.** MANDATORY, never skip. Confirm: fails (not errors); failure message is expected; fails because the feature is missing, not a typo. Passes? You're testing existing behavior — fix the test. Errors? Fix the error, re-run until it fails correctly.

**GREEN — Minimal Code.** Simplest code to pass. Don't add features, refactor other code, or "improve" beyond the test.

**Verify GREEN — Watch It Pass.** MANDATORY. Confirm: passes; other tests still pass; output pristine (no errors, warnings). Fails? Fix the code, not the test. Other tests fail? Fix now.

**REFACTOR.** After green only: remove duplication, improve names, extract helpers. Keep tests green. Don't add behavior.

**Repeat.** Next failing test for the next behavior.

## Good Tests

| Quality | Good | Bad |
|---------|------|-----|
| **Minimal** | One thing. "and" in the name? Split it. | `test('validates email and domain and whitespace')` |
| **Clear** | Name describes the behavior | `test('test1')` |
| **Shows intent** | Demonstrates the desired API | Obscures what the code should do |

## Why Order Matters

Tests written after code pass immediately, which proves nothing: the test might check the wrong thing, test the implementation instead of the behavior, or miss edge cases you already forgot. Test-first forces you to watch the test fail — the only proof it tests something real. Tests-after answer "what does this do?"; tests-first answer "what should this do?" and force edge-case discovery before implementation exists to bias the answer.

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "Too simple to test" | Simple code breaks. Test takes 30 seconds. |
| "I'll test after" | Tests passing immediately prove nothing. |
| "Tests after achieve same goals" | Tests-after = "what does this do?" Tests-first = "what should this do?" |
| "Already manually tested" | Ad-hoc ≠ systematic. No record, can't re-run. |
| "Deleting X hours is wasteful" | Sunk cost fallacy. Keeping unverified code is technical debt. |
| "Keep as reference, write tests first" | You'll adapt it. That's testing after. Delete means delete. |
| "Need to explore first" | Fine. Throw away exploration, start with TDD. |
| "Test hard = design unclear" | Listen to the test. Hard to test = hard to use. |
| "TDD will slow me down" | TDD is faster than debugging. Pragmatic = test-first. |
| "Manual test is faster" | Manual doesn't prove edge cases. You'll re-test every change. |
| "Existing code has no tests" | You're improving it now. Add tests for existing code. |

## Red Flags — STOP and Start Over

- Code before test
- Test written after implementation
- Test passes immediately
- Can't explain why the test failed
- Tests added "later"
- Rationalizing "just this once"
- "I already manually tested it"
- "Tests after achieve the same purpose"
- "It's about spirit not ritual"
- "Keep as reference" or "adapt existing code"
- "Already spent X hours, deleting is wasteful"
- "This is different because..."

**All of these mean: delete the code, start over with TDD.**

## Verification Checklist

Before marking work complete:

- [ ] Every new function/method has a test
- [ ] Watched each test fail before implementing
- [ ] Each test failed for the expected reason (feature missing, not a typo)
- [ ] Wrote minimal code to pass each test
- [ ] All tests pass
- [ ] Output pristine (no errors, warnings)
- [ ] Tests use real code (mocks only if unavoidable)
- [ ] Edge cases and errors covered

Can't check all boxes? You skipped TDD. Start over.

## When Stuck

| Problem | Solution |
|---------|----------|
| Don't know how to test | Write the wished-for API. Write the assertion first. Ask your human partner. |
| Test too complicated | Design too complicated. Simplify the interface. |
| Must mock everything | Code too coupled. Use dependency injection. |
| Test setup huge | Extract helpers. Still complex? Simplify the design. |

## Debugging Integration

Bug found? Write a failing test reproducing it. Follow the TDD cycle. The test proves the fix and prevents regression. Never fix bugs without a test.

## Final Rule

```
Production code → test exists and failed first
Otherwise → not TDD
```

No exceptions without your human partner's permission.
