---
module: skills/planning/scripts
date: 2026-07-27
problem_type: test_failure
component: plan-frontmatter-validator
severity: medium
symptoms:
  - "Test harness passes 25/25 but two enforced validator checks have zero fixture coverage"
  - "Deleting a validator check (replacing with no-op) leaves the harness green"
  - "Downstream corpus integration inherits an unenforced check as a silent gap"
root_cause: "Fixture suite covers the check's positive and negative outcomes but not every enforced rule — a check can exist in the validator with no fixture that would fail if it were removed"
resolution_type: mutation_testing
tags:
  - validator
  - fixtures
  - mutation-testing
  - false-green
---

## Problem

A validator ships with a fixture harness that exercises many rules, but individual enforced checks may lack a discriminating fixture — one that would fail if the check were deleted. Standard coverage metrics count lines executed, not checks enforced.

## Symptoms

- Harness exits 0 with all cases passing.
- Replacing a check body with `if False:` (or equivalent no-op) still passes every case.
- A downstream consumer (e.g., a corpus gate in `scripts/validate.sh`) inherits the unenforced rule, creating a silent gap where invalid input passes both the harness and the gate.

## What Didn't Work

- **Line coverage**: the check's code runs during valid-input cases, so coverage tools mark it covered — but no invalid-input case exercises the rejection path.
- **Reading the fixture list for completeness**: the brief listed the check as required, and a matching case name existed, but the fixture's assertion targeted a different field than the one the check validates.

## Solution

After writing the harness, **mutate each enforced check to a no-op and confirm the suite catches it**:

1. For each check in the validator, temporarily replace its body with a pass-through (e.g., `if False:` in Python, `true` in shell).
2. Run the harness. If all cases still pass, the check has no discriminating fixture.
3. Add a fixture whose input triggers exactly that check and whose assertion names the check's field/rule.
4. Restore the check body and confirm the new fixture passes.

In this cycle, three gaps were found this way:
- The `: ` parser-safety check had no fixture (only ` #` was tested).
- The resolving-`origin:` happy path had no fixture (only the missing-path negative case existed).
- `completed_by` bypassed the scalar type guard that `superseded_by` and `origin` used.

## Why This Works

A mutation test asks "would removing this check break something?" — a question coverage cannot answer. A check that can be deleted with a green suite is functionally dead code from the harness's perspective, regardless of its presence in the validator.

## Prevention

- After writing a validator + harness pair, run a mutation pass before declaring the harness complete.
- When a downstream consumer (corpus check, CI gate) depends on the validator, the mutation pass prevents inheriting unenforced rules as silent gaps.
- The mutation pass is a one-time cost per check, not per run — once a discriminating fixture exists, regression is caught by the normal suite.
