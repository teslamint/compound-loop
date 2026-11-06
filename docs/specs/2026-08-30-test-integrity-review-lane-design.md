---
title: Test-integrity review sub-check
status: approved
date: 2026-08-30
schema: spec/v1
---

# Test-integrity Review Sub-check Design

## Overview

The standing `tests` review lane checks coverage and assertion quality, but it does not name the integrity controls that make a fixture trustworthy. A green fixture can therefore hide network access, shared temporary state, fail-open verifiers, broad assertions, undeclared environment dependencies, or host Git signing and hook state.

This cycle adds a deterministic `test-integrity` sub-check to the existing `tests` lane. The sub-check keeps the existing `lane-findings` schema and merge pipeline, emits code-grounded findings, and ships a versioned local corpus that measures detection quality without network or model calls.

## User Scenarios

### S1: A reviewer audits a test-bearing diff

A reviewer selects the standing `tests` lane. The lane explicitly runs `test-integrity` and checks each named integrity class with the same P0-P3 finding contract used by other lanes.

### S2: A seeded fixture defect is detected

The dogfood corpus contains at least two seeded defects and one holdout per integrity class. The evaluator reports the expected seed IDs, validates every finding against `schemas/lane-findings.schema.json`, and applies the existing merge-pipeline confidence and severity rules.

### S3: A clean fixture remains clean

A clean fixture is reviewed three times. It emits no P0 or P1 finding, and the three normalized finding-ID sets are identical.

### S4: Fixture evidence is hermetic

The dogfood run creates a disposable repository with a local Git identity, disabled signing, an empty hooks path, isolated `HOME`, isolated `TMPDIR`, and no network-capable command. The run fails closed if the fixture reaches an external target or relies on host Git configuration.

## Scope

### In

- A named `test-integrity` sub-check under the standing `tests` review lane.
- Six auditable classes: network isolation, shared temporary directories, verifier fail-open behavior, assertion specificity, hidden environment dependencies, and fixture Git signing/hooks.
- A standard-schema finding emitter with evidence, impact, severity, owner, and verification fields.
- A versioned C2-TI corpus with two seeded defects and one holdout per class, plus a clean fixture.
- A deterministic evaluator with three repeated runs, precision/recall measurements, clean-fixture P0/P1 false-positive checks, schema checks, and compound-loop validation.

### Out

- A new finding schema or alternate merge pipeline.
- Network calls, model calls, GitHub mutations, or host credential access.
- Runtime changes to `ai-orchestration`.
- A general-purpose static-analysis framework or third-party dependency.
- Automatic fixes for test code.

## Requirements

- **R1**: The `tests` lane names `test-integrity` as a required sub-check and links its six classes and non-flags.
- **R2**: Every emitted finding uses the existing `schemas/lane-findings.schema.json` detail contract, including at least one code-grounded evidence item and a failure-mode `why_it_matters`.
- **R3**: The evaluator detects network access, shared temporary state, fail-open verification, weak assertions, undeclared environment reads, and host Git signing or hook inheritance.
- **R4**: The versioned C2-TI corpus contains two seeded defects and one holdout per class, a clean fixture, stable seed IDs, and expected P0-P3 severity.
- **R5**: The evaluator achieves 100% recall for seeded P0/P1 defects, at least 90% precision across expected findings, and zero clean-fixture P0/P1 findings.
- **R6**: Three identical runs produce the same normalized seed-ID set and the same finding fingerprints.
- **R7**: The evaluator validates findings against the existing schema and reuses the merge-pipeline rules for severity, confidence, deduplication, and suppression boundaries.
- **R8**: The fixture Git repository cannot inherit host signing keys or hooks; its isolated configuration is verified before review.
- **R9**: The dogfood run performs no network or model call and passes `bash scripts/validate.sh` with recursive self-invocation disabled only for the nested validation call.
- **R10**: A changed defect fixture fails by its named class and seed ID; setup failures do not count as detection evidence.

## Design Decisions

1. Keep `test-integrity` inside `tests` because its findings concern test trustworthiness, not a new review perspective. This preserves the always-on lane roster and existing merge semantics.
2. Use a standard-library shell entry point with embedded Python because this repository's executable conformance checks follow that pattern and have no Python package runtime.
3. Store source snippets and expectations in one versioned JSON corpus. The evaluator reads only corpus content and disposable paths, which makes the measurement reproducible and prevents hidden fixture files from becoming an untracked input.
4. Use deterministic lexical probes for the narrow named classes. A probe emits a finding only for a documented unsafe pattern and records the exact source line. The holdout cases prevent probes from firing on safe neighboring patterns.
5. Treat a missing or malformed finding as an evaluator failure, not as an empty review. A clean result is valid only after the corpus inventory, schema validation, and repeated-run checks pass.

## Verification Contract

The evaluator reports case-level pass/fail lines and a final summary containing the six class counts, recall, precision, clean-fixture P0/P1 count, repeated-run equality, schema status, network-call count, and nested validation status. It exits nonzero for any unmet requirement. Its findings are serialized using the same field names as the existing lane schema; no second severity vocabulary is permitted.

## Risks and Mitigations

| Risk | Mitigation |
|---|---|
| Lexical probes miss semantic test behavior. | Scope the claim to the named patterns, require code-grounded evidence, and keep the sub-check an explicit review prompt rather than a complete static analyzer. |
| The corpus becomes self-affirming. | Include holdouts, mutation-shaped defect removal checks, three repeated runs, and schema validation independent of expected IDs. |
| Fixture setup inherits host state. | Use isolated `HOME` and `TMPDIR`, an empty hooks directory, explicit Git config, and a command audit that rejects network tools. |
| A malformed finding appears clean. | Fail closed on missing fields, invalid enums, missing evidence, and unknown case outcomes. |

## Acceptance Evidence

- `bash scripts/test-review-test-integrity.sh dogfood` exits 0 and prints the C2-TI metrics.
- Removing one seeded defect changes the expected-rejection assertion and causes the corresponding case to fail at the detector assertion, not fixture setup.
- Three repeated reviews produce byte-equivalent normalized finding fingerprints.
- `bash scripts/validate.sh` exits 0 and includes the test-integrity dogfood check.
