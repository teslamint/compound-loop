# Deviation Addendum 023: Raise the bounded adapter output cap

_Recorded 2026-08-24 after the approved replacement pilot reached the existing cap._

## Original contract

The approved specification and plan require bounded model output. They do not fix a byte value.

The implementation limits combined adapter stdout and stderr to 65,536 bytes.

## Discovered contradiction

Claude Code stream JSON reached the limit during the first pilot turn.

The supervisor recorded `overflow: true` and killed the process with return code `-9`.

The captured Base64 stdout length was 87,384 characters. No terminal model result was available.

The fresh receipt remains consumed. Codex did not start.

## Decision

Raise the combined adapter stdout and stderr cap to 1,048,576 bytes.

Keep the cap fixed and non-configurable. Kill the process when it exceeds the cap.

Raise only the bounded supervisor-summary read limit needed for Base64 encoding overhead.

Do not persist raw adapter output in the final generation.

## Observable behavior

Normal verbose stream JSON can complete below one mebibyte.

Output above one mebibyte still fails as `adapter output exceeded cap` and terminates the process group.

The old failed run remains terminal. A replacement run requires a new packet, receipt, and USER approval.

## Safety and consent boundaries

This addendum does not authorize a model call, retry, merge, push, or publication.

It does not change models, monetary caps, token caps, timeouts, retry count, or concurrency.

## Verification changes

Add boundary tests for output below, at, and above 1,048,576 bytes.

Verify that overflow still kills and reaps the process group.

Run `preflight`, `resource`, `fixture`, and `bash scripts/validate.sh` before preparing another packet.

## Traceability

- Specification: `docs/specs/2026-08-24-release-loop-conformance-fuzzing-design.md`, R27.
- Plan: `docs/plans/2026-08-24-001-feat-release-loop-conformance-fuzzing-plan.md`, U5 and V1.
- Failed receipt nonce: `5729b948f49e92f025d68c51b3367eb7`.
- Failure evidence: `.release-loop/evidence/live-runs/a26000f64c364fed90cd455919cc757e/`.
- Source commit: `63558ecf7ff96c5fc922bc1ec3d0378a54938630`.
