---
schema: deviation/v1
title: Auto artifact goal coverage correction
date: 2026-09-20
status: accepted
---

# Auto artifact goal coverage correction

## Original contract

The approved successor design requires executable assumptions, trade-offs,
closure sections, and negative controls for artifacts written by `--auto`.

## Discovered contradiction

The success criteria proved individual fields and mutations, but they did not
state the population covered by the goal or require a recall floor. A green
field-level harness could therefore leave broad artifact coverage unmeasured.

## Necessity

The goal covers every spec and plan produced by the two auto-authoring skills.
A design that lacks a population and measured coverage cannot prove that its
implementation attains that goal. The approved design remains immutable, so a
successor design records the coverage contract and the measured sample.

## Measurement

The rerunnable Population and Coverage command in the successor design ran at
`2026-09-20T02:19:58Z`. It validated the two artifacts named by the
authoritative ledger. It tested 17 fixed malformed mutations: the standalone
validators detected 17/17, the downstream harness observed 17/17, validator
recall was `1.000`, harness incremental recall was `0.000`, and stacked recall
was `1.000`. The harness is downstream, so zero incremental recall is expected
and is not presented as complementary coverage.

## Safety and consent

This correction changes no runtime behavior. It adds no migration requirement
and does not weaken the auto-only scope. The successor design was approved at
the Design gate after the measured coverage was reviewed.

## Traceability

- Superseded design: `docs/specs/2026-09-19-auto-plan-assumption-tradeoffs-correction-design.md`
- Successor design: `docs/specs/2026-09-20-auto-plan-assumption-tradeoffs-coverage-design.md`
- Measurement command: `bash scripts/test-auto-artifact-contract.sh`
- Implementation contract: `skills/designing/scripts/validate-auto-artifact.py`
- Regression harness: `scripts/test-auto-artifact-contract.sh`
