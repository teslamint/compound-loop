# Deviation Addendum 019: Repin golden source identity in U4

_Recorded 2026-08-24 after plan approval and before U4 acceptance._

## Original contract

The sealed plan assigns U4 ownership to four lifecycle files, the runner, and four static data files.

It assigns the eight golden packets to U1 and U5.

## Discovered contradiction

U4 must change `skills/release-loop/SKILL.md` to consume `pending_gate`.

Every golden packet stores the exact current skill SHA-256 and materialization lines.

The U1 validator rejects stale source identity before the U4 gate tests run.

U4 therefore cannot pass its required static and repository gates without updating derived golden fields.

## Decision

Extend U4 ownership to the eight JSON files under `tests/conformance/release-loop/golden/`.

U4 may update only these source-derived fields:

- `skill_sha256`
- `skill_materialization`

Prompts, scripted answers, harness IDs, case IDs, and payload modes remain unchanged.

U5 retains ownership of adapter-related golden changes.

## Observable behavior

Golden validation accepts the current exact `SKILL.md` bytes after U4 changes.

A one-byte source or golden identity change still fails the semantic contract.

## Safety and consent boundaries

This deviation adds no model call, network access, credential path, or outward mutation.

The approved paid-call and merge gates remain unchanged.

## Verification changes

U4 records the old and new source digest.

It verifies that only the two allowed fields change across all eight packets.

It then runs the gate group, static mode, and `bash scripts/validate.sh`.

## Traceability

- Specification: `docs/specs/2026-08-24-release-loop-conformance-fuzzing-design.md`, R30 and R36.
- Plan: `docs/plans/2026-08-24-001-feat-release-loop-conformance-fuzzing-plan.md`, U4 and U5.
- Trigger: U4 RED after adding the required release-loop pending-gate consumer.
- Authority: `docs/solutions/workflow-issues/review-introduced-state-machine-deviation.md`.
