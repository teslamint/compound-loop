# Deviation Addendum 018: Bind source generation in the corpus

_Recorded 2026-08-24 after plan approval and before U2 acceptance. The user approved this exact ownership expansion in the current session._

## Original contract

The approved specification requires source changes to carry matching corpus and baseline updates.

The sealed plan assigns U2 ownership to the runner, validator, mutations, source manifest, and baseline policy. It assigns `corpus.json` to U1, U4, and U7.

## Discovered contradiction

U2 task review showed that the source manifest and bootstrap policy can authorize each other.

An operative section can change. A modifier can update its manifest digest and policy generation without changing the corpus.

The validator then cannot prove the corpus represents the new source generation.

## Decision

Extend U2 ownership to `tests/conformance/release-loop/corpus.json`.

Add one `source_generation` field to the canonical corpus. Compute it from actual heading-bounded source section bytes.

Require the same digest in the corpus and bootstrap policy. A source change therefore requires source manifest, corpus, and policy updates.

No other U2 file ownership changes.

## Necessity

A manifest-only digest proves source identity. It does not prove corpus synchronization.

The corpus must retain the generation it claims to evaluate. This closes the circular authorization path.

## Observable behavior

Static validation rejects when source section bytes, source manifest, corpus generation, or bootstrap policy disagree.

U4 and U7 must repin all three records after approved operative source changes.

## Safety and consent boundaries

This deviation adds no model call, network access, credential path, or outward mutation.

The approved paid-call and merge gates remain unchanged.

## Verification changes

U2 adds a source-section mutation that changes operative text without changing the manifest.

U2 adds independent corpus-generation and policy-generation mutations.

Each mutation must fail with its own diagnostic. Updating only two of the three records must still fail.

## Traceability

- Specification: `docs/specs/2026-08-24-release-loop-conformance-fuzzing-design.md`, R3 and R50.
- Plan: `docs/plans/2026-08-24-001-feat-release-loop-conformance-fuzzing-plan.md`, U2.
- Review finding: U2 task review after commit `f6b6fa7`.
- Authority: `docs/solutions/workflow-issues/review-introduced-state-machine-deviation.md`.

