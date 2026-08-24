# Deviation Addendum 021: Update live adapter CLI contracts

_Recorded 2026-08-24 after the first approved pilot failed before any model response._

## Original contract

The approved specification and sealed plan require this Codex initial command fragment:

```text
--approve-for-me --sandbox workspace-write
```

They also require an empty Claude MCP configuration and an isolated child environment.

## Discovered contradiction

The installed Codex CLI is version 0.149.1. It rejects `--approve-for-me` with an explicit `--sandbox` value.

The installed Claude Code CLI is version 2.1.241. It rejects `{}` as a strict MCP configuration.

Claude Code also forces `default` permission mode when `CLAUDE_CODE_SUBPROCESS_ENV_SCRUB=1` is present. This blocks the approved `dontAsk` adapter contract.

Both pilot sessions stopped before a model response. The one-shot receipt remains consumed.

The paid state file retained `status: running` after the terminal infrastructure failure. This status does not describe the observed state.

## Decision

Replace the Codex fragment with this current CLI contract:

```text
--approve-for-me
```

The current flag provides automatic approval review inside the workspace-write sandbox. Do not add a second sandbox flag.

Represent the empty Claude MCP configuration as this valid object:

```json
{"mcpServers": {}}
```

Remove `CLAUDE_CODE_SUBPROCESS_ENV_SCRUB` from the constructed adapter environment. The runner already creates a closed environment without credential variables.

Keep the Claude sandbox credential deny list and the canonical PreToolUse path guard. Keep `autoAllowBashIfSandboxed: false`.

Persist a terminal failed state when the paid scheduler raises an infrastructure or conformance failure. Do not reuse the consumed receipt.

## Observable behavior

The zero-model preflight expects the revised Codex argv and the valid empty MCP object.

The live adapter starts each CLI without the three observed argument and configuration errors.

A failed paid run records `status: failed`. A fresh run requires a new approval packet and a new one-shot receipt.

## Safety and consent boundaries

This addendum does not authorize a model call, retry, merge, push, or publication.

The runner still passes only its closed environment to each broker. The Claude broker adds public user identity fields for Keychain access.

The Claude filesystem sandbox and path guard still deny host credential access. Codex still uses its workspace-write sandbox and project execution policy.

The current failed pilot remains terminal. A replacement pilot needs a fresh first-hand USER approval.

## Verification changes

Add failing tests for all three captured CLI diagnostics.

Require the preflight to verify the exact revised arrays and MCP bytes.

Require resource tests to prove terminal failed-state persistence and receipt non-reuse.

Run `preflight`, `resource`, `fixture`, and `bash scripts/validate.sh` before a new packet is prepared.

## Traceability

- Specification: `docs/specs/2026-08-24-release-loop-conformance-fuzzing-design.md`, adapter command shapes.
- Plan: `docs/plans/2026-08-24-001-feat-release-loop-conformance-fuzzing-plan.md`, U5 and V1.
- Failed receipt nonce: `885a978ff3fa247da81396614dc7189c`.
- Claude adapter evidence: `.release-loop/evidence/live-runs/db85bd4cb7134d1481774d3e369b623b/`.
- Codex adapter evidence: `.release-loop/evidence/live-runs/10303d159322492895685a37b4db30a8/`.
- Trigger: first approved V1 pilot on source commit `08512855ac9e9ee43fc4d3be232fadcf507ffcee`.
