# Deviation Addendum 016: Claude stream JSON verbose mode

_Recorded 2026-08-24 after spec approval and before the draft plan commit. The user still owns plan approval and every paid-command gate._

## Original contract

The approved specification fixes the Claude initial command in `docs/specs/2026-08-24-release-loop-conformance-fuzzing-design.md`.

The command combines `--print` with `--output-format stream-json`. It does not include `--verbose`.

The Harness Protocol also requires Claude resume to retain the same policy flags.

## Discovered contradiction

Claude Code 2.1.241 rejects that command shape before model execution.

The installed executable contains this exact diagnostic:

`Error: When using --print, --output-format=stream-json requires --verbose`

The command below found the diagnostic twice in the installed binary:

`strings /opt/homebrew/Caskroom/claude-code@latest/2.1.241/claude | rg -n -F 'requires --verbose'`

The approved command therefore cannot start an L1 pilot on the observed CLI.

## Decision

Keep the approved specification unchanged as the historical record.

The draft plan adds `--verbose` to both Claude command arrays.

The initial array places `--verbose` after `--output-format stream-json`. The resume array uses the same placement and adds `--resume` with the parsed session ID.

No other approved flag changes.

## Necessity

The live suite requires structured events and a resumable session ID.

Changing the output to plain text would remove the structured event contract. Removing `--print` would remove the required non-interactive protocol.

Adding `--verbose` is the smallest compatible repair.

## Observable behavior

Claude invocations emit verbose stream JSON instead of failing argument validation.

The adapter still bounds output. It still uses the approved settings, plugin, model, MCP, permission, session, and budget flags.

The user still approves the exact paid command before execution.

## Safety and consent boundaries

This addendum grants no model-call authority.

A first-hand point-of-risk gate remains mandatory for the pilot and the full run. The runner must bind each approval to the exact command digest and current session.

The added flag does not relax the command policy or expose credentials.

## Verification changes

U5 captures both fake Claude argv arrays. Each array must include exactly one `--verbose` after the stream JSON output flag.

A negative command-shape mutation removes `--verbose`. The adapter validator must reject that mutation before a model call.

The Ship preflight reruns `claude --version`. It rejects a CLI version whose observed command contract differs from the pinned adapter.

## Traceability

- Approved specification: `docs/specs/2026-08-24-release-loop-conformance-fuzzing-design.md`.
- Draft plan: `docs/plans/2026-08-24-001-feat-release-loop-conformance-fuzzing-plan.md`.
- Installed CLI evidence: Claude Code 2.1.241 at `/opt/homebrew/Caskroom/claude-code@latest/2.1.241/claude`.
- Addendum authority: `docs/solutions/workflow-issues/review-introduced-state-machine-deviation.md`.

