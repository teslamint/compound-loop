# Deviation Addendum 024: Define the adapter descendant boundary

_Recorded 2026-08-25 after the output-cap security review found an unbounded descendant claim._

## Original contract

The approved plan starts each live invocation in a new process group.

The plan requires bounded TERM and KILL handling. It also requires proof that the runner reaped every child.

Deviation 023 requires overflow to kill and reap the process group.

## Discovered contradiction

A trusted adapter can create a new session before it kills its supervisor.

That escaped process leaves the invocation process group. The portable process APIs cannot atomically retain ownership after this escape.

PID sampling can miss a process that reparents before the next sample. Signalling a sampled PID later can target an unrelated reused PID.

The runner must not claim complete cleanup for an intentionally escaped and unobserved process.

## Decision

Define the enforceable boundary as the adapter invocation process group.

Start the real CLI only after a launcher commits a nonce-bound PID, PGID, and SID record.

The launcher writes the record with an atomic replacement. It also syncs the file and its directory.

Keep an in-group watchdog for the supervisor lifetime. The watchdog kills its own group when the supervisor pipe closes.

The outer controller verifies group absence. It never signals a recorded numeric PGID after the supervisor exits.

Treat sampled escaped descendants as diagnostic evidence only. Do not claim that sampling provides complete containment.

The trusted Claude Code and Codex executables must not intentionally escape the invocation group or kill their supervisor.

## Observable behavior

Normal completion preserves stdout, stderr, stdin, and the CLI exit status.

Timeout sends TERM to the invocation group. It waits 200 milliseconds before it sends KILL.

Overflow sends KILL to the invocation group. The supervisor retains at most one mebibyte across both output streams.

A supervisor crash closes the watchdog pipe. The watchdog kills the CLI and every in-group descendant.

An intentionally escaped process is outside the guaranteed cleanup boundary.

## Safety and consent boundaries

This addendum does not authorize a model call, retry, merge, push, or publication.

It does not weaken the Claude or Codex command sandbox. It does not grant process escape to model-issued commands.

The runner fails if the handshake record is missing, malformed, unsafe, or inconsistent.

A replacement pilot requires a new source packet and first-hand USER approval.

## Verification changes

Test output below, at, and above the one-mebibyte combined cap.

Test mixed stdout and stderr. Test byte-identical stdin after the launcher handshake.

Test TERM-resistant timeout handling. Verify TERM, KILL, and process absence.

Test a supervisor crash with an in-group child. Verify both process IDs are absent.

Run `preflight`, `resource`, `fixture`, and `bash scripts/validate.sh` before a new packet.

## Traceability

- Specification: `docs/specs/2026-08-24-release-loop-conformance-fuzzing-design.md`, R27.
- Plan: `docs/plans/2026-08-24-001-feat-release-loop-conformance-fuzzing-plan.md`, lines 41 and 308.
- Predecessor: `docs/deviations/2026-08-24-live-adapter-output-cap-023.md`.
- Invalidated packet: SHA-256 `4f467c2477a86dc2747b75caacabf2105d7dff4b41d33be36090217065496669`.
- Source commit: `f8c9d7f073d7bd1bf3c0984441cae6c5771167f6`.
