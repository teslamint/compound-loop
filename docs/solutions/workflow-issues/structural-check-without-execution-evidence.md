---
module: "retrospective interview protocol / structural validation"
date: "2026-07-21"
problem_type: workflow_issue
component: structural-check
severity: medium
applies_when:
  - "shipping two or more structural checks in the same change"
  - "a check's enforcement lives in skill prose rather than a script or validator"
  - "dry runs or fixtures are cited as proof that a gate works"
  - "reviewing a claim that a procedural check 'fired' or 'passed'"
tags:
  - execution-evidence
  - structural-checks
  - dry-run
  - retrospective
  - verification
---

# A Structural Check Without an Execution Record Is Indistinguishable From an Unbuilt One

## Context

The retro-interview-enforcement cycle (merged `9d2d9c4`) shipped two
end-of-interview checks side by side in `skills/retrospective/SKILL.md`: a
findings-citation check and a carry-forward/T-ID-linkage check. Three dry runs
were recorded as evidence (`docs/reviews/2026-07-20-retro-interview-enforcement-dryrun-evidence.md`).
The findings check left execution records in two of them — run 1 recorded it
passing ("PASS (3 findings, 0 uncited)") and run 3 recorded it firing on an
injected violation ("FAIL: uncited finding at line 19"). The carry-forward
check left none: erratum 4 states that *no run's executed-checks record names
the carry-forward check*, and run 2's probed row shipped with its required
`(T1)` citation missing — the exact violation the check exists to stop. The
gap was found by a task reviewer (U6-m1) and, during the retro interview, the
facilitator rejected the respondent's claim that the check had partially run
(retro doc T5).

## Guidance

When a change ships more than one check, require a per-check execution record
before treating any of them as delivered:

- For each check, the evidence set must contain at least one run where that
  check *by name* passed on clean input and — where a negative fixture is
  feasible — one where it fired on a violation. Runs 1 and 3 did this for the
  findings check; nothing did it for the carry-forward check.
- A dry run "covering the feature" is not a dry run covering every check in
  the feature. Enumerate the checks and map each to the run that exercised
  it; an unmapped check is untested, whatever the overall run count is.
- Prose-only checks (enforced by skill text, no script behind them) need this
  discipline most: their only existence proof *is* an execution record.

## Why This Matters

The unexercised check was precisely the one that failed silently: run 2's
missing `(T1)` passed every recorded gate and was caught two layers later by
a human-directed review, not by the check itself. Had both checks been held
to the runs-1-and-3 standard (named pass + named fire), the omission would
have surfaced before commit instead of as an erratum.

## When to Apply

- Reviewing or accepting a change that adds checks, gates, or validators —
  ask "which run shows *this* check firing?" per check, not per feature.
- Writing dry-run or fixture evidence: record executed checks by name, so a
  later reader can distinguish "ran and passed" from "never ran".
- Retro reconciliation of "Done" claims about enforcement mechanisms.

## Examples

- Findings check (proven): run 1 `ok` record + run 3 injected-violation
  `FAIL` record, both naming the check.
- Carry-forward check (unproven at ship time): zero named records across
  three runs; first durable execution evidence is the
  `2026-07-21-retro-interview-enforcement-retro.md` commit, one full cycle
  after shipping.
- Contrast with `scripts/validate.sh` check 9: its fixture harness
  (`scripts/test-retro-format-drift.sh`) gives every failure mode a named
  red-then-green case — the standard prose-only checks should approximate
  with execution records.
