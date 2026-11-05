---
schema: deviation/v1
title: Auto coverage authority successor correction
date: 2026-09-20
status: accepted
---

# Auto coverage authority successor correction

## Original contract

The approved coverage design and sealed successor plan must remain immutable
once the plan approval seal exists. The release ledger must point to the
approved pair used by Ship.

## Discovered contradiction

A review found that the approved coverage design received a post-plan-seal
change to assert the ledger's `--auto` flag. That change made the old plan and
its design origin non-authoritative for exact-head review.

## Necessity

The change must not mutate an approved design after its plan is sealed. The
immutable authority successor preserves the final command, fixed mutation
inventory, and ledger population assertion while replacing both predecessor
artifacts through explicit successor pointers.

## Measurement

The successor design's exact Population and Coverage command ran at
`2026-09-20T02:51:37Z`. It read the two paths from the ledger, asserted
`flags == ['[--auto]']`, validated both artifacts, and compared the fixed 17
mutation labels. It returned 17/17 validator detection, 17/17 harness
observation, validator recall `1.000`, harness incremental recall `0.000`, and
stacked recall `1.000`.

## Safety and consent

This correction changes no runtime behavior. It adds no migration requirement.
The successor remains at the Design gate until fresh user approval, followed by
a new sealed plan approval and exact-head review.

## Traceability

- Superseded design: `docs/specs/2026-09-20-auto-plan-assumption-tradeoffs-coverage-design.md`
- Successor design: `docs/specs/2026-09-20-auto-plan-assumption-tradeoffs-coverage-authority-design.md`
- Superseded plan: `docs/plans/2026-09-20-005-feat-auto-plan-assumption-tradeoffs-coverage-plan.md`
- Successor plan: `docs/plans/2026-09-20-006-feat-auto-plan-assumption-tradeoffs-coverage-authority-plan.md`
