# Deviation Addendum 022: Add a Codex permission profile

_Recorded 2026-08-24 after security review of the deviation 021 repair._

## Original contract

The approved specification and sealed plan use workspace-write sandboxing plus a project execution policy.

Approved deviation 021 replaced the conflicting Codex flags with `--approve-for-me`.

No approved artifact assigns a versioned Codex permission profile or a profile-copy contract to the authentication broker.

## Discovered security gap

The workspace-write sandbox permits broad host reads. The automatic reviewer is not a deterministic credential boundary.

The current project rules do not match these commands:

```text
cat /Users/teslamint/.ssh/id_ed25519
grep token /Users/teslamint/.codex/auth.json
```

Both commands produced `matchedRules: []` during the security review. An automatic approval could therefore expose a host credential.

## Decision

Add `tests/conformance/release-loop/policies/codex-profile.toml` as a versioned template.

The runner materializes these runtime paths into the profile:

- the exact feature source as read-only;
- the Codex binary directory as read-only;
- the resolved Codex runtime root as read-only;
- the current fixture workspace as writable through `:workspace_roots`.

The profile grants `:minimal` read access. It grants no other host or network access.

The profile sets `approval_policy = "on-request"` and `approvals_reviewer = "auto_review"`.

Replace `--approve-for-me` with `--profile conformance` in Codex initial and resume argv.

The runner exports the materialized profile path and SHA-256 to the verified Codex broker.

The broker verifies the source file identity. It copies the profile to the private `CODEX_HOME` as `conformance.config.toml` with mode `0400`.

The broker still removes the private authentication file before it forwards `thread.started`. It keeps the non-secret profile until the process exits.

## Observable behavior

Codex local commands can read the feature source and edit only the fixture workspace.

Codex local commands cannot read arbitrary host-home paths. This restriction uses the operating-system sandbox, not automatic review.

Initial and resumed sessions use the same named profile. Policy drift blocks before each invocation.

## Safety and consent boundaries

This addendum does not authorize a model call, retry, merge, push, or publication.

The profile does not grant command network access. Codex client authentication and model transport remain outside the local-command sandbox.

The broker receives no credential value through the profile environment variables. It receives only a path and a digest.

A replacement pilot still requires a fresh approval packet and first-hand USER approval.

## Verification changes

Add exact initial and resume argv tests for `--profile conformance`.

Add profile template, materialization, digest, symlink, mode, and mutation tests.

Use `codex sandbox --profile conformance` without a model call to prove these cases:

- fixture reads and writes succeed;
- feature reads succeed and writes fail;
- host credential reads fail;
- Codex binary and runtime paths remain executable.

Run `preflight`, `resource`, `fixture`, and `bash scripts/validate.sh` before a new packet is prepared.

## Traceability

- Specification: `docs/specs/2026-08-24-release-loop-conformance-fuzzing-design.md`, R29 and R42.
- Plan: `docs/plans/2026-08-24-001-feat-release-loop-conformance-fuzzing-plan.md`, U5 and V1.
- Approved predecessor: `docs/deviations/2026-08-24-live-cli-compatibility-021.md`.
- Security review trigger: commit range `b0edb28..28d21bb`.
- Official profile contract: `default_permissions` with `[permissions.<name>.filesystem]`.
- Zero-model proof: Codex 0.149.1 accepted the proposed profile and emitted its restricted filesystem context.
