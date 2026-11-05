---
schema: deviation/v1
title: Auto plan closure sections correction
date: 2026-09-19
status: accepted
---

# Auto plan closure sections correction

## Original contract

The active auto-authoring rule requires every spec and plan to state assumptions,
trade-offs, non-goals, residual risks, and measurable success criteria. Each
numeric claim must carry rerunnable command evidence.

## Discovered contradiction

Approved plan `2026-09-19-003-feat-auto-plan-assumption-tradeoffs-final-plan.md`
contained the required assumptions and trade-offs tables, but it did not contain
explicit `Non-goals`, `Residual Risks`, or `Success Criteria` sections. Its
`Deferred to Follow-Up Work`, `Open unknowns`, and scenario tables did not satisfy
the active section contract.

## Necessity

The plan is an implementation authority. Leaving the omission would allow the
implementation to pass a weaker contract than the one the user requested.
The approved body remains immutable, so a successor plan is required.

## Observable behavior

Plan `2026-09-19-003-feat-auto-plan-assumption-tradeoffs-final-plan.md` is marked
`superseded`. Successor plan
`2026-09-19-004-feat-auto-plan-assumption-tradeoffs-contract-plan.md` carries
`mode: auto`, the same approved origin, explicit closure sections, and the same
implementation units.

## Safety and consent

This correction changes no runtime behavior and modifies no historical artifact.
It only makes the implementation authority satisfy the active authoring contract.
The successor plan receives the automatic plan gate because the ledger invocation
is `--auto`; no outward publish, push, or merge is authorized by this addendum.

## Verification changes

The validator now rejects an auto artifact missing any closure section. The
focused harness adds negative controls for missing closure sections and empty
selected or rejected status names. It also rejects duplicate mode entries and
unsupported validator modes.

## Traceability

- Superseded plan: `docs/plans/2026-09-19-003-feat-auto-plan-assumption-tradeoffs-final-plan.md`
- Successor plan: `docs/plans/2026-09-19-004-feat-auto-plan-assumption-tradeoffs-contract-plan.md`
- Implementation contract: `skills/designing/scripts/validate-auto-artifact.py`
- Regression harness: `scripts/test-auto-artifact-contract.sh`
