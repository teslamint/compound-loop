# Deviation Addendum 025: Require a hard Claude invocation budget

_Recorded 2026-08-25 after pilot 4 exceeded its approved invocation budget._

## Original contract

The approved plan sets a Claude total budget and a per-invocation budget.

The paid receipt reserves the per-invocation amount before each Claude call.

The scheduler rejects a settlement above that reservation.

Deviation 021 keeps Claude in `dontAsk` mode with explicit project allow rules.

## Observed contradiction

Pilot 4 passed `--max-budget-usd 1.50` to Claude Code 2.1.241.

Claude reported `error_max_budget_usd` after 22 internal turns. It reported a total cost of USD 1.51532725.

The reported cost exceeded the approved invocation budget by USD 0.01532725.

The scheduler rejected the settlement as `claude-settlement-invalid`. This fail-closed result was correct.

The disposable fixture was not a trusted Claude workspace. Claude ignored five project `permissions.allow` entries.

The ignored rules caused repeated Bash denials. Those denials consumed budget without completing the lifecycle.

Codex did not start. The one-shot receipt remains consumed.

## Decision

Keep the USD 1.50 per-invocation amount as a strict consent boundary.

Do not reinterpret this amount as a soft target or an after-the-fact settlement threshold.

Classify the current Claude CLI live adapter as ineligible for paid conformance calls.

Require a future adapter to stop spend before the approved amount. Post-call rejection alone does not satisfy this requirement.

Do not mutate the user's global `.claude.json` trust records for disposable fixtures.

Do not use `auto` mode as the repair. It adds a probabilistic classifier and can abort headless sessions after repeated blocks.

Do not use `bypassPermissions` as the repair. It bypasses permission checks and does not provide a hard dollar cap.

Keep `dontAsk` for the current adapter until a replacement design satisfies both trust-independent permissions and hard budget enforcement.

## Observable behavior

One closed `adapter_eligibility` predicate governs every paid or approval entry point.

The predicate runs at `prepare-pilot`, `install-full-approval`, `live-pilot`, `live`, and V1 resume.

The rejection is `claude-hard-budget-unavailable` for the current Claude adapter.

The rejection occurs before packet mutation, approval validation, receipt consumption, nonce mutation, or model launch.

An existing packet, receipt, or generation does not override this predicate. A direct paid-mode command cannot bypass it.

A future eligible adapter provides a versioned proof record. A deterministic repository verifier creates the record.

The record includes these bindings:

- adapter identity and version;
- executed adapter SHA-256;
- hard-cap enforcer identity, version, and SHA-256;
- hard-cap mechanism and deterministic proof SHA-256;
- verifier identity, version, and SHA-256.

The closed verifier identity is `release-loop-hard-budget-verifier/v1`.

Every launch re-hashes the adapter, enforcer, and verifier bytes before it consumes authority. Any mismatch makes the adapter ineligible.

The approval packet and receipt bind that exact eligibility proof digest.

The scheduler closes an over-budget result with a terminal `overrun` record. It never records a successful settlement or retries that invocation.

The atomic `overrun` record contains these typed fields:

- `call_id`: the reserved invocation identifier;
- `reserved`: the approved decimal string;
- `reported_actual`: the Claude decimal string;
- `difference`: `reported_actual - reserved` as a decimal string;
- `total_before`, `raw_remaining`, and `remaining_after`: decimal strings;
- `result_subtype`: the closed value `error_max_budget_usd`;
- `trust_warning`: `workspace-untrusted-project-allows-ignored` or `null`;
- `retryable`: the literal `false`;
- `budget_frozen`: the literal `true`.

The same atomic write clears `active_process` and `claude_active`. It adds `reported_actual` to `claude_spent`.

Immediately before that write, `total_before` equals `claude_remaining + claude_active.reserved`.

It sets `raw_remaining` to `total_before - reported_actual`.

It sets `claude_remaining` and `remaining_after` to `max(0, raw_remaining)`. This formula avoids resetting or charging the reservation twice.

A negative mathematical remainder persists in `raw_remaining`.

The paid state becomes `failed` with failure `claude-hard-budget-overrun`.

The over-budget subtype is the primary failure. The trust warning is a secondary root-cause classification.

Restart preserves the `overrun` record. It cannot convert the record into success, missing telemetry, or a retryable infrastructure failure.

## Safety and consent boundaries

This addendum does not authorize a model call, retry, merge, push, or publication.

It does not increase any dollar, token, turn, timeout, concurrency, or retry limit.

It does not authorize changes to the user's Claude configuration or workspace trust state.

The release-loop remains blocked at Ship V1 until a separately approved adapter provides hard budget enforcement.

## Eval and verification changes

Add a deterministic stream fixture for `error_max_budget_usd` with a reported cost above the reservation.

The result fixture contains `type: result`, `subtype: error_max_budget_usd`, and a decimal `total_cost_usd` above the reservation.

Add a deterministic stderr fixture for the workspace trust warning.

The fixture uses this normalized single-line form:

```text
Ignoring <COUNT> permissions.allow entries from .claude/settings.json: this workspace has not been trusted. Run Claude Code interactively here once and accept the trust dialog, or set projects["<FIXTURE_ROOT>"].hasTrustDialogAccepted: true in <HOST_HOME>/.claude.json.
```

The matcher accepts only a positive decimal `<COUNT>`. `<FIXTURE_ROOT>` must equal the canonical disposable fixture root.

`<HOST_HOME>` must equal the broker's canonical host home. The matcher rejects extra text, missing text, and embedded newlines.

The persisted record stores only the normalized form. Map only this form to `workspace-untrusted-project-allows-ignored`.

Replace generic Claude usage extraction with typed accounting evidence for result subtype, reported cost, and trust warning.

Require the scheduler to persist the exact `overrun` fields and decimal arithmetic above.

Require the fallback exception path to preserve `claude-hard-budget-overrun`. It must not call missing-telemetry settlement.

Prove that every named entry point rejects before it reads or mutates approval authority.

Prove that stale packets, stale receipts, direct paid commands, and V1 resume cannot bypass eligibility.

Require packet, receipt, and nonce files to remain byte-identical after every rejection.

Add eligibility-proof mutation tests for every adapter, enforcer, verifier, mechanism, and digest field.

Add a launch-time byte mutation test for the adapter, enforcer, and verifier.

Add an accounting test with prior settled spend. Require the exact reservation-reversal formula for `total_before`.

Add a restart test that cannot reclassify `overrun` as success, missing telemetry, or infrastructure failure.

Run `preflight`, `resource`, `fixture`, and `bash scripts/validate.sh` after implementation.

No stochastic permission-mode eval is required because this decision rejects `auto` mode.

## Rejected alternatives

- **Soft budget semantics:** This changes a strict consent boundary after observed overspend.
- **Budget headroom:** A lower CLI target does not prove a maximum final API turn cost.
- **Auto mode:** The classifier is probabilistic and can fail closed in non-interactive sessions.
- **Bypass mode:** The mode removes permission checks without solving hard budget enforcement.
- **Global trust mutation:** The change affects user state and can race with concurrent Claude sessions.

## Traceability

- Specification: `docs/specs/2026-08-24-release-loop-conformance-fuzzing-design.md`, R27, R29, and R42 through R46.
- Success criterion: `docs/specs/2026-08-24-release-loop-conformance-fuzzing-design.md`, criterion 10.
- Plan: `docs/plans/2026-08-24-001-feat-release-loop-conformance-fuzzing-plan.md`, U5, U6, and V1.
- Predecessors: deviations 021 through 024.
- Pilot packet SHA-256: `f69031ae53f077dca745be86e09956e527f792a79b893a9086c0599a473bc7e1`.
- Receipt nonce: `2f58d74d9ae9368c11f60fa1bcbc4f17`.
- Failure state: `.release-loop/evidence/live-pilot-state-2f58d74d9ae9368c11f60fa1bcbc4f17.json`.
- Claude result: `error_max_budget_usd`, reported USD 1.51532725.
- Claude permission modes: <https://code.claude.com/docs/en/permission-modes>.
- Claude permission evaluation: <https://code.claude.com/docs/en/agent-sdk/permissions>.
