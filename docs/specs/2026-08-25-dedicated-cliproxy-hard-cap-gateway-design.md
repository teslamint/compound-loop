---
title: Dedicated CLIProxyAPI Pre-Spend Quota Gateway
status: approved
date: 2026-08-25
schema: spec/v1
---

# Dedicated CLIProxyAPI Pre-Spend Quota Gateway Design

_Created 2026-08-25._

## Overview

Build a dedicated CLIProxyAPI gateway in front of the existing Claude OAuth proxy.

The gateway uses governed CLIProxyAPI and `credit-manager` forks to enforce a conservative USD-equivalent quota before each provider request.

The dedicated gateway has its own Claude OAuth credential and does not use the existing service as an upstream.

The design does not modify the existing CLIProxyAPI service at `https://cliproxyapi.tailnet-0a4d.ts.net:8317`.

## User Scenarios

### S1: Prepare a paid pilot without spending

The release-loop operator runs `prepare-pilot`. The runner verifies the dedicated gateway, strict plugin, price ceiling, and quota template.

The command writes no remote key and starts no model request.

### S2: Execute one approved Claude invocation

After first-hand approval, the gateway broker creates one short-lived `tk-...` key.

The key allows only `claude-sonnet-4-6`. Its total quota is 1,500,000 micro-USD and its concurrency is one.

The runner launches Claude Code through the dedicated gateway. That gateway uses its own Claude OAuth credential.

### S3: Reject an unaffordable request before spend

The strict plugin computes a worst-case request ceiling before forwarding.

If the reservation exceeds the remaining key quota, the gateway returns a deterministic rejection. It sends no upstream request.

### S4: Settle and reconcile usage

The strict plugin settles the reservation from final usage data.

The Model Router usage view and the compound-loop ledger independently reconcile model, tokens, price, reservation, and actual cost.

### S5: Fail safely without usage

If a stream ends without valid usage, the plugin charges the complete reservation. It does not release the hold.

The key remains frozen until an operator reconciles the request.

### S6: Recover without affecting existing clients

If the dedicated gateway fails, the operator stops only that service. Existing clients continue using `:8317` unchanged.

The operator revokes or expires the pilot key. The release-loop remains blocked.

## Scope

### In

- A maintained CLIProxyAPI fork based on v7.2.128 commit `bd34ceca04209ef0460f4b05e3a1a047fb7fad2a`.
- A maintained strict fork based on `credit-manager` v1.4.2 commit `b1cb5f60a00b0aa9ca833b1bc3a043cebf26e28d`.
- A maintained Model Router fork based on v0.4.2 commit `594497e5a6a05ad19228063b6fe78ac23949f1f8`.
- A separate CLIProxyAPI instance with its own Claude OAuth credential.
- Pre-forward reservation, strict settlement, usage reconciliation, and gateway lifecycle evidence.
- A compound-loop broker for management credentials and short-lived plugin keys.
- A compound-loop adapter that launches Claude Code through the dedicated gateway.
- A governed eligibility proof that binds all executable, configuration, and pricing bytes.

### Out

- Installing `credit-manager` into the existing `:8317` service.
- Migrating existing CLIProxyAPI client keys.
- Sharing OAuth files between two CLIProxyAPI processes.
- Anthropic API-key billing or reuse of the existing service as an upstream.
- Multiple models, automatic fallback, preview models, Fast mode, or server tools.
- General-purpose multi-tenant credit management.
- Treating a dashboard estimate as pre-spend enforcement.

## Delivery Decomposition

This design has two ordered deliverables with separate plans.

1. **Gateway deliverable:** governed CLIProxyAPI fork, strict `credit-manager` fork, dedicated service, and black-box hard-cap proof.
2. **Integration deliverable:** compound-loop broker, adapter, eligibility verifier, and V1 lifecycle integration.

Planning must complete the Gateway plan first. The Integration plan cannot mark the adapter eligible without the accepted Gateway proof.

## Assumptions and Preconditions

| Claim | Command | Observed at | Observed result | Evidence source |
|---|---|---|---|---|
| The existing independent service is a CLIProxyAPI core service. | `/usr/bin/curl -sS --max-time 10 https://cliproxyapi.tailnet-0a4d.ts.net:8317/` | `2026-08-25T02:18:10Z` | Returned `CLI Proxy API Server` and its public endpoint list. | Live tailnet endpoint, sanitized public response. |
| The existing independent service still requires model-list authentication. | `/usr/bin/curl -sS --max-time 10 -o /dev/null -w 'models_status=%{http_code}\n' https://cliproxyapi.tailnet-0a4d.ts.net:8317/v1/models` | `2026-08-25T02:18:10Z` | Returned HTTP 401. This suggests that exclusive `credit-manager` frontend authentication is not active, but does not prove plugin inventory. | Live tailnet endpoint, status only. |
| The reviewed `credit-manager` source is v1.4.2. | `git ls-remote --tags https://github.com/yuluo688/credit-manager.git 'refs/tags/v1.4.2' 'refs/tags/v1.4.2^{}'` | `2026-08-25T02:18:10Z` | Tag resolves to commit `b1cb5f60a00b0aa9ca833b1bc3a043cebf26e28d`. | Upstream Git repository. |
| The governed CLIProxyAPI base version is v7.2.128. | `git ls-remote --tags https://github.com/router-for-me/CLIProxyAPI.git 'refs/tags/v7.2.128'` | `2026-08-25T02:32:46Z` | Tag resolves to commit `bd34ceca04209ef0460f4b05e3a1a047fb7fad2a`. | Upstream Git repository. |
| The current plugin reserves before forwarding but permits settlement above the hold. | `/usr/bin/curl -sS https://raw.githubusercontent.com/yuluo688/credit-manager/v1.4.2/internal/store/settle.go` | `2026-08-25T02:18:10Z` | The bounded source file explicitly permits actual cost above the hold. | Audited v1.4.2 source. |
| The current input estimate is not a tokenizer ceiling. | `/usr/bin/curl -sS https://raw.githubusercontent.com/yuluo688/credit-manager/v1.4.2/internal/service/request.go` | `2026-08-25T02:18:10Z` | Input estimate is `len(body)/2 + 1` and is clamped to the configured maximum. | Audited v1.4.2 source. |
| The running instance has no active credit manager. | `GET /v0/management/plugins` with `CLIPROXYAPI_MANAGEMENT_KEY` | `2026-08-25T03:58:31Z` | `credit-manager` is configured but unregistered and disabled. `model-router` v0.3.2 is registered and enabled. | Live management API, sanitized inventory fields only. |
| The running Model Router usage schema lacks hard-cap correlation fields. | `GET /v0/management/plugins/model-router/usage/requests?limit=1` with `CLIPROXYAPI_MANAGEMENT_KEY` | `2026-08-25T03:58:31Z` | The row has token, cost, model, provider, and timing fields. It has no request, attempt, reservation, auth-fingerprint, route-digest, or pricing-digest field. | Live management API, field names only. |

No management key, plugin key, OAuth token, account name, or usage body is retained in this spec.

## Architecture

```text
release-loop runner
  -> dedicated hard-cap CLIProxyAPI gateway
       -> strict credit-manager fork
       -> final-payload admission hook in governed CLIProxyAPI fork
       -> dedicated Claude OAuth credential
            -> Claude billing boundary
```

The dedicated gateway owns one isolated Claude OAuth credential. It never reads the existing service's auth directory.

The strict plugin owns frontend authentication, reservations, settlement, and audit for the dedicated gateway.

The compound-loop broker owns the gateway management credential. The Claude child receives only one short-lived plugin key.

The governed core selects the exact Claude provider and model. Model Router usage tracking supplies independent post-request reconciliation.

The governed Model Router fork runs only in `audit_only` mode. It never selects, executes, intercepts, retries, or rewrites a model request.

The governed core invokes the hard-cap hook after final translation, injection, auth selection, and route selection. It invokes the hook before every network attempt.

### Trusted computing base

The gateway trust boundary includes all three governed forks, their Go dependencies, the Go runtime, SQLite, the operating system, and the dedicated OAuth files.

The native plugin runs in the gateway process and can access process memory. Artifact pinning alone is not sufficient.

The build is reproducible and emits an SBOM. Review covers every dependency and the complete fork diff.

The gateway process has outbound access only to the governed Claude OAuth and model origins. Management remains loopback-only.

No dynamic plugin download, auto-update, shell command, or ungoverned network destination is permitted.

## Accounting Semantics

The enforced unit is **gateway micro-USD**. It is a conservative USD-equivalent derived from approved price ceilings.

This unit does not claim to reproduce a Claude subscription invoice or its included-usage quota.

The design satisfies the consent boundary by refusing to forward requests whose gateway micro-USD reservation exceeds the approved quota.

The dedicated OAuth account must have Fast mode and extra provider fallbacks disabled. Any unknown premium or billing mode makes eligibility false.

Approval of this spec approves gateway micro-USD as the V1 hard-cap unit. It does not authorize a gateway deployment or model call.

This decision replaces deviation 025's provider-reported USD requirement with a conservative token-price quota.

The design does not prove or cap the Claude subscription invoice. Provider-reported external charges remain unverified.

## Requirements

### Gateway isolation

**R1.** The dedicated gateway uses a different origin from `https://cliproxyapi.tailnet-0a4d.ts.net:8317`.

**R2.** The gateway is reachable only through the operator's tailnet or loopback network.

**R3.** The existing `:8317` configuration, auth directory, client keys, and service lifecycle remain byte-identical.

**R4.** The dedicated gateway uses its own config, auth directory, OAuth login, plugin directory, database, pepper, logs, and process identity.

**R5.** The gateway pins the governed CLIProxyAPI, strict credit plugin, and Model Router audit plugin source commits, build inputs, and artifact SHA-256 values.

The Model Router audit fork registers only `usage_plugin` and a bounded read-only usage management resource.

It does not register `model_router`, `executor`, `model_registrar`, request or response interceptors, streaming interceptors, configuration writes, price writes, models.dev sync, history reset, or outbound network access.

Its price book is a governed read-only artifact loaded at startup. Startup rejects every extra or missing capability.

### Strict reservation

**R6.** The governed CLIProxyAPI fork adds a last-mile admission hook after final request construction and before each network write.

**R7.** The strict plugin adds a closed `strict_pre_spend` mode and implements that hook. Default plugin behavior never enables this mode implicitly.

**R8.** Strict mode accepts only `claude-sonnet-4-6` and exact Claude-compatible message routes.

**R9.** Strict mode requires an explicit positive `max_tokens` value no greater than 8,192.

**R10.** Strict mode rejects a final decoded request body larger than 122,880 bytes.

The final body is the UTF-8 JSON payload after every client and gateway transform. The ceiling uses one token per decoded byte.

The algorithm is `body_ceiling_tokens = len(final_utf8_json_bytes)`. It never uses `len(body)/2` or tokenizer estimates.

**R11.** Strict mode reserves 65,536 input tokens for provider-side billed content not represented in the final body.

Eligibility requires a governed billing contract that bounds that hidden content. Corpus tests alone cannot establish the bound.

**R12.** Strict mode rejects any request whose body ceiling, hidden-content ceiling, and output ceiling exceed 200,000 tokens.

**R13.** The input-like price ceiling is 6.60 USD per million tokens. It covers base input, cache read, and cache creation.

**R14.** The output-like price ceiling is 16.50 USD per million tokens. It covers output, reasoning, and the 1.1x geography multiplier.

**R15.** The maximum reservation is 1,378,716 micro-USD. One shared integer function rounds each billable category before summation.

```text
max over input + cache_read + cache_creation = 188416:
  ceil(input * 6.60) + ceil(cache_read * 6.60) + ceil(cache_creation * 6.60) = 1243548
ceil(output 8192 * 16.50) = 135168
maximum category-split reserve = 1243548 + 135168 = 1378716 micro-USD
```

**R16.** The plugin never clamps an over-limit estimate. It rejects the request before forwarding.

**R17.** Unknown pricing, unknown models, malformed bodies, compressed bodies, binary content, image blocks, document blocks, missing limits, negative values, and arithmetic overflow fail closed.

**R18.** Fast mode, batch mode, server tools, web search, web fetch, code execution, image generation, automatic retry, and provider fallback are forbidden.

The only allowed `anthropic-beta` values are:

```text
claude-code-20250219
oauth-2025-04-20
interleaved-thinking-2025-05-14
thinking-token-count-2026-05-13
context-management-2025-06-27
prompt-caching-scope-2026-01-05
mid-conversation-system-2026-04-07
advanced-tool-use-2025-11-20
effort-2025-11-24
extended-cache-ttl-2025-04-11
```

The governed core removes and rejects `server-side-fallback-2026-06-01`, `fallback-credit-2026-06-01`, every later equivalent, and every unlisted beta before admission.

Eligibility mutates each forbidden beta independently and proves zero network writes.

**R19.** Every network retry would require a new reservation. Strict mode configures zero automatic retries, so one client request causes at most one network attempt.

Redirects are disabled. Auth fallback, credential rotation, preview fallback, and replay with `GetBody` are disabled.

The governed transport invokes admission at the lowest `RoundTrip` boundary. Every attempt ID requires a distinct committed reservation before any request bytes leave.

### Last-mile hook ABI

The governed core adds `hardcap.pre_round_trip/v1`.

The strict plugin registers capability `hardcap_pre_round_trip`, method `hardcap.pre_round_trip`, schema version `1`, and plugin ID `credit-manager-strict`.

The core configuration sets `hard_cap.required: true` and `hard_cap.plugin_id: credit-manager-strict`.

Startup requires exactly one healthy matching capability. Missing, duplicate, disabled, wrong-version, or unhealthy registration stops the gateway before it listens.

The request schema is:

```json
{
  "schema": "hardcap-pre-round-trip/v1",
  "request_id": "<uuid>",
  "attempt_id": "<uuid>",
  "plugin_key_fingerprint": "<sha256>",
  "provider": "claude",
  "auth_fingerprint": "<sha256>",
  "model": "claude-sonnet-4-6",
  "method": "POST",
  "canonical_path": "/v1/messages",
  "canonical_query_sha256": "<sha256>",
  "governed_headers": {
    "anthropic-beta": "claude-code-20250219,oauth-2025-04-20,interleaved-thinking-2025-05-14,thinking-token-count-2026-05-13,context-management-2025-06-27,prompt-caching-scope-2026-01-05,mid-conversation-system-2026-04-07,advanced-tool-use-2025-11-20,effort-2025-11-24,extended-cache-ttl-2025-04-11",
    "content-encoding": "identity",
    "content-type": "application/json"
  },
  "inference_geo": "us",
  "service_tier": "standard",
  "target_origin_sha256": "<sha256>",
  "route_sha256": "<sha256>",
  "stream": true,
  "body_byte_count": 122880,
  "body_sha256": "<sha256>",
  "body_base64": "<bounded final body>"
}
```

The response schema is:

```json
{
  "schema": "hardcap-pre-round-trip-result/v1",
  "admitted": true,
  "request_id": "<uuid>",
  "attempt_id": "<uuid>",
  "plugin_key_fingerprint": "<sha256>",
  "auth_fingerprint": "<sha256>",
  "route_sha256": "<sha256>",
  "body_sha256": "<sha256>",
  "reservation_id": "<uuid>",
  "held_micro_usd": 1378716,
  "error": null
}
```

A rejection sets `admitted: false`, leaves `reservation_id` empty, and returns a closed sanitized error.

The core validates every field and the reservation transaction before it calls `RoundTrip`.

The committed reservation row and response must echo every request, attempt, route, body, key, and auth binding before `RoundTrip`.

The last-mile hook is the only reservation owner in strict mode. Strict mode bypasses the legacy pre-execution `BuildReservePlan` and `Reserve` path.

The executor creates a concurrency-safe single-assignment admission slot before `client.Do`. The request context carries the slot pointer before transport starts.

The last-mile transport fills the slot with the committed reservation and complete attempt bindings before it writes network bytes.

The executor reads the same slot after `client.Do` returns and uses it through streaming or non-streaming terminal settlement.

The slot rejects a second assignment. A failed assignment causes zero network writes and compensates the committed hold before returning.

The synchronous executor settles that same reservation. One client request produces exactly one hold and one terminal settlement.

A repeated attempt ID with byte-identical governed fields returns the original committed reservation.

The same attempt ID with any changed governed field returns `reservation-conflict` and causes zero network writes.

A hook error, timeout, malformed response, or SQLite failure returns a local 503 and causes zero network writes.

The closed admission errors are `schema-invalid`, `route-forbidden`, `body-limit`, `output-limit`, `context-limit`, `price-unavailable`, `quota-exceeded`, `concurrency-exceeded`, `reservation-conflict`, and `admission-unavailable`.

Error precedence is schema, route, body, output, context, price, quota, concurrency, conflict, then unavailable. Multi-defect tests assert this exact order.

### Quota and concurrency

**R20.** Each approved invocation receives a new plugin key with a 1,500,000 micro-USD total quota.

**R21.** The key has `max_concurrent_requests: 1` and one exact allowed model.

**R22.** The key expires within one hour. The runner revokes it after terminal evidence.

**R23.** Reservation and quota mutation occur in one SQLite transaction.

**R24.** Repeated idempotency keys return the same reservation. Conflicting repeats reject.

**R25.** A reservation cannot exceed total, daily, weekly, or monthly remaining quota.

### Settlement

**R26.** Valid final usage settles actual input, cache, output, and reasoning costs against the same price ceiling.

**R27.** Missing or malformed usage charges the complete reservation and freezes the key.

**R28.** Stale-reservation cleanup never releases strict reservations. It converts them to fully charged frozen records.

**R29.** Actual cost above the reservation is an invariant breach. The plugin disables the key and its eligibility health.

**R30.** Late usage can reduce a fully charged reservation. It cannot increase spend beyond the original reservation.

**R31.** The synchronous executor and SQLite transaction own terminal settlement exactly once by request ID.

**R32.** Async lifecycle and usage callbacks are idempotent, best-effort audit inputs. A callback error never restores spendable quota.

### Claude adapter

**R33.** Claude Code receives the dedicated gateway URL through `ANTHROPIC_BASE_URL`.

**R34.** Claude Code receives only the short-lived `tk-...` key through `ANTHROPIC_AUTH_TOKEN`.

**R35.** The adapter sets `CLAUDE_CODE_DISABLE_1M_CONTEXT=1`, `CLAUDE_CODE_MAX_OUTPUT_TOKENS=8192`, `CLAUDE_CODE_MAX_RETRIES=0`, and the documented Fast and fallback disable flags.

**R36.** The adapter uses `bypassPermissions` only inside the existing fail-closed OS sandbox and disposable fixture.

**R37.** The Claude tool list excludes Bash, Agent, WebFetch, WebSearch, and every server tool. A scrubbed local MCP fixture executor provides the closed command surface.

**R38.** Credential deny rules, source read-only rules, network denial, process-group supervision, and plugin-key scrubbing from every tool subprocess remain mandatory.

**R39.** The management credential and Claude OAuth credential never enter the child environment, command line, packet, receipt, logs, or generation.

### Authority and eligibility

Gateway bootstrap has the durable states `absent`, `login-approved`, `authenticated`, `eligible`, `revocation-pending`, and `removed`.

The Gateway deployment approval exclusively owns OAuth login and credential persistence.

The dedicated OAuth principal must differ from the principal used by the existing `:8317` service. Gateway eligibility binds both sanitized identity fingerprints and requires inequality.

The auth directory has mode `0700`. Credential files have mode `0600`. Backups and credential copies are forbidden.

Eligibility requires the selected OAuth identity fingerprint and a healthy exact Claude route.

Gateway rollback runs the governed logout or token-revocation operation, deletes the dedicated auth directory, and verifies state `removed`.

If upstream revocation is unavailable, rollback remains `revocation-pending`. It does not report credential removal from local deletion alone.

**R40.** `prepare-pilot` verifies a read-only gateway template. It does not create a plugin key.

**R41.** The approval packet names the dedicated gateway origin, quota, expiry, model, pricing digest, and all governed artifact digests.

**R42.** First-hand V1 pilot approval authorizes creation of one exact short-lived key and one pilot execution against an already eligible gateway.

**R43.** The receipt binds the returned key fingerprint, not its plaintext.

**R44.** Gateway eligibility binds the core fork, strict plugin, config, price rules, model metadata, OAuth identity and route, hidden billing contract, transform proof, and black-box proof generation.

**R45.** Final adapter eligibility binds gateway eligibility plus the broker, adapter, verifier, sandbox profile, packet schema, and receipt schema.

**R46.** Every paid entry re-hashes and revalidates both proofs before nonce consumption. Any unavailable component, unknown version, changed byte, changed price, changed route, changed auth mode, or stale proof blocks before authority mutation.

### Reconciliation and recovery

**R47.** The governed core creates one request ID before reservation and propagates it through reservation, executor, response, usage, audit, and runner records.

**R48.** The plugin ledger, Model Router usage data, and compound-loop ledger emit the normalized reconciliation record defined below.

**R49.** The runner polls reconciliation for at most ten seconds after process exit. It requires one plugin record and one compound-loop record per request.

**R50.** Missing Model Router usage is allowed only with plugin status `charged_missing_usage`. Every other missing, duplicate, or contradictory record blocks the generation.

**R51.** Late usage after a terminal reconciliation failure can reduce the remote charge. It cannot reopen, retry, or rewrite the frozen generation.

**R52.** The model child cannot reach the existing `:8317` origin or the gateway management plane.

**R53.** Gateway cleanup failure leaves the key quota-limited and expiring. It never authorizes a retry.

**R54.** Rollback stops the dedicated gateway and revokes its plugin key. It does not restart or modify `:8317`.

## Interfaces

### Runner environment

```text
CONFORMANCE_HARD_CAP_GATEWAY_URL
CONFORMANCE_HARD_CAP_GATEWAY_BROKER
CONFORMANCE_HARD_CAP_ELIGIBILITY_SHA256
```

The broker supports read-only `status --json` and approved mutation commands for create, inspect, and revoke.

The management API binds to loopback only. A co-located broker is its only client.

### Broker commands

```text
gateway-broker status --json --harness hard-cap-gateway
gateway-broker create --approval-sha256 <hex> --receipt-nonce <hex> --session-marker <uuid> --key-fd 3
gateway-broker inspect --key-id <id> --fingerprint <hex> --session-marker <uuid>
gateway-broker usage --invocation-id <id> --fingerprint <hex> --session-marker <uuid>
gateway-broker revoke --key-id <id> --fingerprint <hex> --session-marker <uuid>
```

`create` uses `(approval_sha256, receipt_nonce, session_marker)` as its idempotency key.

The bounded JSON response contains key ID, fingerprint, quota, model, expiry, and governed digests. It never contains plaintext.

File descriptor 3 is a private bounded pipe. It carries the plaintext key once to the runner's credential handoff.

The broker stores only the HMAC fingerprint after handoff. The strict fork removes key reveal, recoverable plaintext, and management UI routes.

If key creation succeeds but pipe delivery fails, the broker revokes that key and returns `key-handoff-failed`.

The broker uses this closed error vocabulary:

```text
gateway-unavailable
gateway-identity-mismatch
approval-mismatch
receipt-reused
key-create-failed
key-handoff-failed
key-inspect-mismatch
usage-unavailable
key-revoke-failed
```

No broker error is retryable under the same receipt nonce.

### Gateway eligibility record

```json
{
  "schema": "release-loop-hard-cap-gateway-eligibility/v1",
  "eligible": true,
  "gateway_origin_sha256": "<sha256>",
  "cliproxyapi_sha256": "<sha256>",
  "credit_manager_sha256": "<sha256>",
  "model_router_sha256": "<sha256>",
  "go_toolchain_sha256": "<sha256>",
  "dependency_lock_sha256": "<sha256>",
  "sbom_sha256": "<sha256>",
  "reproducible_build_proof_sha256": "<sha256>",
  "egress_policy_sha256": "<sha256>",
  "strict_config_sha256": "<sha256>",
  "pricing_sha256": "<sha256>",
  "oauth_identity_sha256": "<sha256>",
  "oauth_route_sha256": "<sha256>",
  "hidden_billing_contract_sha256": "<sha256>",
  "transform_proof_sha256": "<sha256>",
  "proof_generation_sha256": "<sha256>"
}
```

The record contains no URL, key, token, account name, email, or management response body.

### Adapter eligibility record

```json
{
  "schema": "release-loop-hard-cap-adapter-eligibility/v1",
  "eligible": true,
  "gateway_eligibility_sha256": "<sha256>",
  "management_broker_sha256": "<sha256>",
  "claude_adapter_sha256": "<sha256>",
  "eligibility_verifier_sha256": "<sha256>",
  "sandbox_profile_sha256": "<sha256>",
  "packet_schema_sha256": "<sha256>",
  "receipt_schema_sha256": "<sha256>"
}
```

Every paid entry revalidates the gateway proof first and the adapter proof second. A mutation to any bound artifact makes final eligibility false.

## Data Model

The gateway database retains plugin keys, held reservations, settled usage, strict failures, and audit events.

Every strict reservation records request ID, key fingerprint, model, `body_byte_count`, `body_sha256`, input ceiling, output ceiling, price rule, held micro-USD, status, and timestamps.

The database, audit records, logs, backups, and reconciliation artifacts never retain raw bodies, prompts, tool arguments, authorization headers, or ungoverned headers.

Strict mode also removes OAuth account name, label, email, auth path, and token-file metadata from collection, storage, management responses, and usage exports.

The dedicated database is created with a strict schema that omits those columns. Migration from a non-strict database is forbidden.

Terminal statuses are `settled`, `charged_missing_usage`, `rejected`, and `invariant_breach`.

Every ledger exports this normalized record:

```json
{
  "schema": "release-loop-gateway-reconciliation/v1",
  "invocation_id": "<id>",
  "request_id": "<id>",
  "attempt_id": "<id>",
  "reservation_id": "<id>",
  "key_fingerprint": "<sha256>",
  "auth_fingerprint": "<sha256>",
  "model": "claude-sonnet-4-6",
  "provider": "claude",
  "route_sha256": "<sha256>",
  "pricing_rule_id": "sonnet-4-6-hard-ceiling",
  "pricing_sha256": "<sha256>",
  "input_rate_micro_usd_per_mtok": 6600000,
  "cache_read_rate_micro_usd_per_mtok": 6600000,
  "cache_creation_rate_micro_usd_per_mtok": 6600000,
  "output_rate_micro_usd_per_mtok": 16500000,
  "reservation_micro_usd": 0,
  "settled_micro_usd": 0,
  "input_tokens": 0,
  "cache_read_tokens": 0,
  "cache_creation_tokens": 0,
  "output_tokens": 0,
  "reasoning_tokens": 0,
  "status": "settled",
  "requested_at": "<rfc3339>",
  "completed_at": "<rfc3339>"
}
```

The plugin record is the spend authority. Model Router usage is audit evidence. The compound-loop record is the consumer projection.

The compound-loop generation retains only sanitized summaries and artifact digests.

## Testing Strategy

### Deterministic tests

- Unit tests for byte ceilings, output limits, price arithmetic, overflow, and unknown-field rejection.
- Final-body tests for escaped JSON, ASCII, Unicode, tool schemas, and every allowed content block. Image, document, binary, and compressed forms must reject.
- Core transport tests for redirect, auth fallback, credential rotation, connection reuse, retry, stream failure, and cancellation attempts.
- Core startup tests for missing, duplicate, disabled, unhealthy, wrong-ID, and wrong-schema hard-cap capabilities.
- Audit-plugin startup tests reject routing, executor, registrar, interceptor, mutable management, sync, reset, and network capabilities.
- Each forbidden audit-plugin capability mutation stops gateway startup before the listener opens.
- ABI mutation tests for every request, response, echo, route, body, auth, and reservation binding.
- Admission-slot tests for single assignment, settlement handoff, compensation, cancellation, and streaming completion.
- Property tests around every byte, token, price, and quota boundary.
- SQLite concurrency tests with competing reservations and repeated idempotency keys.
- Failure injection before reserve, after reserve, during forwarding, during streaming, during settlement, and during revoke.
- Missing, duplicate, delayed, malformed, and contradictory usage callbacks.
- Model, provider, pricing, binary, config, OAuth route, and auth-type mutation tests.
- Secret scanning for the SQLite database, backups, packets, receipts, logs, states, and generation artifacts.

### Integration tests

- A fake upstream counts requests and proves rejected reservations send zero requests.
- A streaming fake proves every terminal path charges or settles exactly once.
- A two-service fixture proves the existing `:8317` service remains unchanged.
- A broker fixture proves management secrets never reach the Claude child.
- A Claude zero-model preflight proves exact gateway environment and sandbox policy.

### Eval-driven tests

- Run the existing L1 lifecycle pilot only after every deterministic gate passes.
- Treat cost, latency, denied tools, lifecycle completion, and ledger reconciliation as eval dimensions.
- A live pilot requires a separate packet and first-hand approval. No design or implementation approval authorizes it.

## Risks and Mitigations

| Risk | Mitigation |
|---|---|
| `credit-manager` is a small third-party project in the OAuth trust boundary. | Maintain pinned forks, audit complete diffs and dependencies, build reproducibly, emit an SBOM, and restrict process egress. |
| OAuth or CLIProxyAPI behavior changes. | Pin versions and fail eligibility on any binary, model, route, or usage-shape drift. |
| Configured micro-USD differs from provider billing. | Use approved price ceilings, disable premium features, and block on pricing or auth-mode uncertainty. |
| Provider-side billed content exceeds 65,536 tokens. | Require a governed billing contract plus transform proof. Corpus evidence alone is insufficient; absent proof keeps eligibility false. |
| Missing usage releases quota. | Strict mode charges the complete reservation and freezes the key. |
| Existing clients break under exclusive plugin auth. | Use a separate gateway origin. Never install the plugin into `:8317`. |
| Management credentials leak. | Isolate them in a broker and persist only key fingerprints and digests. |
| A cleanup call fails. | Use one-hour expiry, fixed quota, concurrency one, and non-retryable terminal state. |

## Success Criteria

1. The strict fork never forwards a request without a committed reservation.
   - **Measured by**: `go test ./...` passes in all three governed forks, and the black-box transport fixture records zero network attempts for every admission failure.
2. No accepted request can reserve more than 1,500,000 micro-USD.
   - **Measured by**: the boundary suite proves 1,500,000 accepts and 1,500,001 rejects before upstream execution.
3. The maximum allowed request reserves exactly 1,378,716 micro-USD.
   - **Measured by**: a deterministic category-residue test covers R9 through R15 and asserts the exact integer result.
4. Missing usage cannot restore spendable quota.
   - **Measured by**: crash and missing-usage tests end in `charged_missing_usage` with the full reservation charged.
5. Concurrent requests cannot oversubscribe one key.
   - **Measured by**: a 100-contender test with concurrency one admits one reservation and rejects or queues all others without negative balances.
6. Existing `:8317` service state remains unchanged.
   - **Measured by**: pre/post hashes of its governed config and auth inventory match, and its public root response remains byte-identical.
7. Paid authority cannot be consumed while gateway eligibility is false.
   - **Measured by**: `prepare-pilot`, `install-full-approval`, `live-pilot`, `live`, and V1 resume preserve packet, receipt, nonce, and generation bytes under every eligibility mutant.
8. Management and OAuth secrets never reach model-visible artifacts.
   - **Measured by**: the broker integration test and repository secret scan find zero credential values in child env, argv, packets, receipts, logs, states, and generations.
9. Every accepted request reconciles across three ledgers.
   - **Measured by**: the integration suite compares request, attempt, reservation, key, auth, route, pricing, model, token, amount, and terminal-status fields across plugin, Model Router, and compound-loop records.
10. The first live pilot completes without exceeding the approved gateway quota.
    - **Measured by**: one separately approved L1 pilot produces a complete generation, reports no reservation or usage mismatch, and records at most 1,500,000 gateway micro-USD for Claude. The result makes no provider-invoice claim.
11. Repository validation remains green.
    - **Measured by**: `bash scripts/validate.sh` reports `ALL CHECKS PASSED` after both delivery plans complete.
12. OAuth bootstrap and rollback never share or orphan credentials.
    - **Measured by**: the deployment matrix proves distinct principal fingerprints, isolated login, eligible health, logout or revocation, auth-directory deletion, and the explicit `revocation-pending` failure path.
13. Integration artifact drift always revokes final eligibility.
    - **Measured by**: separate broker, adapter, verifier, sandbox, packet-schema, and receipt-schema mutations each produce `eligible: false` before authority access.
14. The governed gateway build and egress policy are reproducible and closed.
    - **Measured by**: two clean builds produce identical core and plugin hashes; SBOM license and vulnerability policy passes; denied-destination probes produce zero outbound connections.

## Open Decisions

1. **Dedicated gateway origin and host** — The USER selects the exact tailnet origin at the Gateway planning gate. It must differ from `:8317`.
2. **CLIProxyAPI fork ownership** — The USER selects the maintained core-fork repository before Gateway planning completes.
3. **Credit-manager fork ownership** — The USER selects the maintained plugin-fork repository before Gateway planning completes.
4. **Model Router fork ownership** — The USER selects the maintained audit-plugin fork before Gateway planning completes.
5. **Dedicated OAuth identity** — The USER selects the account and approves its isolated login at the deployment gate.
6. **Hidden billed-content contract** — Gateway planning must identify a governed source for the R11 ceiling. If none exists, planning returns blocked.
7. **Co-located broker transport** — Gateway planning selects the operator-controlled remote execution channel. It cannot expose the management API beyond loopback.

Neither open decision authorizes deployment. Deployment requires a separate first-hand outward-action gate.

## References

- [credit-manager repository](https://github.com/yuluo688/credit-manager)
- [CLIProxyAPI request lifecycle example](https://github.com/router-for-me/CLIProxyAPI/blob/main/examples/plugin/request-lifecycle/README.md)
- [CLIProxyAPI Usage Observer](https://help.router-for.me/plugin/usage-plugin)
- [CLIProxyAPI Model Router](https://help.router-for.me/plugin/model-router)
- [CPA Model Router usage tracking](https://github.com/markhuangai/cpa-plugin-model-router/blob/v0.4.2/docs/usage-tracking.md)
- [Claude Code CLIProxyAPI client configuration](https://help.router-for.me/agent-client/claude-code)
- [Claude Code environment variables](https://code.claude.com/docs/en/env-vars)
- [Claude Sonnet 4.6 pricing](https://platform.claude.com/docs/en/about-claude/pricing)
- [Claude model limits](https://platform.claude.com/docs/en/about-claude/models/overview)
