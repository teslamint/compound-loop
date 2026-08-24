# Deviation Addendum 020: Repin golden source identity in U7

_Recorded 2026-08-24 after plan approval and before U7 lifecycle edits._

## Original contract

The sealed plan requires U7 to modify the release-loop lifecycle and transition contracts.

It does not assign U7 ownership of the eight golden packets.

## Discovered contradiction

Every golden packet stores the exact current `skills/release-loop/SKILL.md` SHA-256.

U7 must add V1 dispatch and V2 archive sequencing to that skill.

Golden validation rejects the changed source before U7 transition tests can satisfy the required static and repository gates.

## Decision

Extend U7 ownership to the eight JSON files under `tests/conformance/release-loop/golden/`.

U7 may update only these source-derived fields:

- `skill_sha256`
- `skill_materialization`

Prompts, scripted answers, harness IDs, case IDs, and payload modes remain unchanged.

## Observable behavior

Golden validation accepts the exact U7 release-loop source bytes.

A one-byte source or golden identity change still fails the semantic contract.

## Safety and consent boundaries

This deviation adds no model call, network access, credential path, publication, or outward mutation.

V1, merge, R1, R2, V2, and Ship gates remain separate.

## Verification changes

U7 records the old and new release-loop source digests.

It proves that only the approved source-derived fields changed across all eight packets.

It then runs transition, static, and repository validation.

## Traceability

- Specification: `docs/specs/2026-08-24-release-loop-conformance-fuzzing-design.md`, R30 and R36.
- Plan: `docs/plans/2026-08-24-001-feat-release-loop-conformance-fuzzing-plan.md`, U7.
- Trigger: mandatory U7 edits to the source hashed by every golden packet.
- Prior equivalent: `docs/deviations/2026-08-24-u4-golden-source-repin-019.md`.
