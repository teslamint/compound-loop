---
schema: plan/v1
title: Dedicated CLIProxyAPI Pre-Spend Quota Gateway
type: feat
status: done
completed_by: 08e12a82752847b3bead5a96fd251b4ad58eae1b
date: 2026-08-25
execution: code
origin: docs/specs/2026-08-25-dedicated-cliproxy-hard-cap-gateway-design.md
deepened: true
body_seal: 33264c35240d3bda38bae4eee679789625a9ee5fbc139a5a91b43d752116ef3f
---

# Dedicated CLIProxyAPI Pre-Spend Quota Gateway Plan

## Goal

Build, test, and deploy a dedicated CLIProxyAPI gateway that enforces a conservative pre-spend quota before each Claude model request. This is Gateway deliverable #1 of the approved spec. The Integration deliverable (#2) depends on the accepted Gateway proof.

## Architecture notes

- Three governed local-only forks: CLIProxyAPI v7.2.128, credit-manager v1.4.2, Model Router v0.4.2. No remote push. Pinned to exact upstream commits.
- Gateway runs on a dedicated tailnet host, separate from the existing `:8317` service. Broker runs co-located on the gateway host. The release-loop runner invokes broker commands over operator-controlled tailnet SSH. Management API never leaves loopback. This interpretation resolves spec Open Decision 7.
- R11 hidden-content ceiling is 2,048 tokens per deviation 026, not the spec's original 65,536. Settlement invariant checks `usage.input_tokens <= body_ceiling_tokens + 2048` at R29.
- Maximum per-request reservation is 959,694 micro-USD (down from spec's 1,378,716) due to the reduced hidden allowance. Computed using spec's category-split formula: worst-case three-category ceil = 824,526 input-like + 135,168 output = 959,694.
- No live API calls in this plan's deterministic suite. No `count_tokens` calls. The settlement invariant makes live verification unnecessary for deterministic testing.
- Deployment and OAuth login (spec Decision 5) are out of scope. Gateway bootstrap is a separate gate.
- Fork workspaces are sibling repositories outside compound-loop (only `./skills/` ships from this repo).

## Open Decision resolution

| Decision | Resolution |
|---|---|
| 1. Gateway origin | Dedicated tailnet host, port TBD at deploy gate |
| 2-4. Fork ownership | Local-only repos at `~/workspace/gateway-forks/{cliproxyapi,credit-manager,model-router}` |
| 6. R11 ceiling | Claude API pricing docs; 2,048 tokens; deviation 026 |
| 7. Broker transport | Co-located on gateway host; runner uses tailnet SSH |
| 5. OAuth identity | Deferred to deployment gate |

## Units

### U1: Fork workspaces and reproducible-build skeleton

Create three local fork repositories pinned to exact upstream commits. Set up a reproducible Go build system that produces deterministic binaries and an SBOM.

**Deliverables:**
- `~/workspace/gateway-forks/cliproxyapi/` pinned to `bd34ceca04209ef0460f4b05e3a1a047fb7fad2a`
- `~/workspace/gateway-forks/credit-manager/` pinned to `b1cb5f60a00b0aa9ca833b1bc3a043cebf26e28d`
- `~/workspace/gateway-forks/model-router/` pinned to `594497e5a6a05ad19228063b6fe78ac23949f1f8`
- `Makefile` or build script producing `gateway-core`, `credit-manager-strict.so`, `model-router-audit.so`
- Two clean builds produce identical SHA-256 for all three artifacts
- SBOM generation (Go `cyclonedx-gomod` or `syft`)
- License and vulnerability audit pass

**Tests:** Reproducible build proof (two builds, diff hashes). SBOM schema validation.

### U2: CLIProxyAPI core — last-mile hook ABI and transport admission

Add `hardcap.pre_round_trip/v1` hook to the governed CLIProxyAPI fork. Add the concurrency-safe admission slot to the executor. Disable redirects, auth fallback, credential rotation, replay, and automatic retries.

**Deliverables:**
- `hardcap.pre_round_trip/v1` plugin capability registration
- Startup validation: exactly one healthy matching capability required
- Admission slot: single-assignment, settlement handoff, compensation, cancellation
- Per-attempt-ID reservation binding: every attempt ID requires a distinct committed reservation before network bytes (R19)
- Transport `RoundTrip` boundary invokes hook before network bytes; repeated attempt ID with identical governed fields returns original reservation; changed fields return `reservation-conflict`
- Config: `hard_cap.required: true`, `hard_cap.plugin_id: credit-manager-strict`
- Zero retries, zero redirects, no `GetBody` replay

**Tests:**
- Startup: missing, duplicate, disabled, unhealthy, wrong-ID, wrong-schema capability → no listener
- Admission slot: single assignment, double-assignment rejection, failed-assignment compensation
- Transport: hook error/timeout/malformed → local 503, zero network writes
- Attempt-ID binding: same ID + same fields → same reservation; same ID + changed fields → `reservation-conflict`, zero network writes
- Redirect/auth-fallback/retry attempts → blocked

### U3: credit-manager strict mode — reservation, settlement, freeze

Add `strict_pre_spend` mode to the governed credit-manager fork. Implement last-mile hook handler, reservation arithmetic with deviation-026 ceiling, settlement, and freeze.

**Deliverables:**
- `strict_pre_spend` mode with closed model allowlist (`claude-sonnet-4-6`)
- Reservation arithmetic: `body_ceiling = len(final_utf8_json)`, `hidden_allowance = 2048`, `output_ceiling = max_tokens ≤ 8192`
- Input-like price ceiling: 6.60 USD/MTok. Output-like: 16.50 USD/MTok
- Category-split reservation with `ceil()` per category
- Settlement: valid usage reduces hold; missing/malformed → full reservation charged, key frozen
- R29 invariant: `usage.input_tokens > body_ceiling + 2048` → key disabled, eligibility revoked
- Stale-reservation cleanup converts to fully-charged frozen records
- SQLite single-transaction reserve+quota-check
- Strict schema: no OAuth account name, label, email, auth path columns

**Tests:**
- Byte ceiling: exact boundary at 122,880 bytes, one-over reject
- Output limit: 8,192 accept, 8,193 reject
- Price arithmetic: overflow, negative, zero, boundary values
- Unknown model/provider/pricing/binary/config → closed rejection; every non-`claude-sonnet-4-6` model string rejected
- Forbidden betas: each removed independently, zero network writes
- Error precedence: schema → route → body → output → context → price → quota → concurrency → conflict → unavailable
- Idempotency: same attempt ID + same fields → same reservation; changed fields → conflict
- Concurrency: 100-contender test, concurrency-one → one admitted
- Missing usage: `charged_missing_usage` with full reservation
- R29: input_tokens above ceiling → `invariant_breach`
- SQLite concurrency with competing reservations

### U4: Model Router audit-only fork

Create the governed Model Router fork in audit-only mode. Register only `usage_plugin` and bounded read-only usage management. Reject every other capability.

**Deliverables:**
- `audit_only` mode registered at startup
- Read-only price book loaded from governed artifact
- Startup rejects: `model_router`, `executor`, `model_registrar`, interceptors, config writes, price writes, sync, reset, outbound network
- Usage tracking: request ID, tokens, cost, model, provider, timing
- Bounded read-only usage management resource

**Tests:**
- Each forbidden capability mutation → startup failure before listener
- Usage record contains required reconciliation fields
- Price book loaded from artifact, not from network

### U5: Gateway configuration, startup validation, and deploy scripts

Create the gateway service configuration, startup capability validation, and deployment scripts for the dedicated tailnet host.

**Deliverables:**
- Gateway config template: dedicated port, auth dir, plugin dir, database, logs
- Startup sequence: validate hard-cap capability → validate audit-only Model Router → open listener
- Egress policy: outbound only to Claude OAuth and model origins, management loopback-only
- Process identity: distinct from `:8317`
- Deploy scripts: install binaries, create directories (mode 0700/0600), generate config, start/stop/status
- Existing `:8317` remains byte-identical

**Tests:**
- Pre/post deploy: `:8317` config hash, auth inventory hash, public root response unchanged
- Gateway startup without hard-cap plugin → no listener
- Outbound connection to denied destination → blocked
- Auth directory mode 0700, credential files mode 0600 verified after deploy script

### U6: Broker CLI and FD-3 key handoff

Create the management broker CLI for key lifecycle operations with secure credential handoff.

**Deliverables:**
- `gateway-broker` CLI: `status`, `create`, `inspect`, `usage`, `revoke`
- `create` idempotency key: `(approval_sha256, receipt_nonce, session_marker)`
- FD-3 private pipe: plaintext key delivered once, HMAC fingerprint retained
- Failed pipe delivery → revoke key, return `key-handoff-failed`
- Closed error vocabulary: 10 named errors, none retryable under same nonce
- Management API accessed only via loopback

**Tests:**
- Create + inspect + revoke lifecycle
- Idempotent create with same triple → same key ID
- FD-3 pipe failure → key revoked
- Each error code reachable
- Management secrets never in stdout, stderr, or env

### U7: Black-box integration suite

Integration tests proving the gateway enforces pre-spend quotas without live model calls.

**Deliverables:**
- Fake upstream: counts requests, proves rejected reservations → zero upstream requests
- Streaming fake: every terminal path charges or settles exactly once
- Two-service fixture: existing `:8317` config/auth/response unchanged after gateway operations
- Broker fixture: management secrets never reach mock Claude child env/argv
- Zero-model preflight: exact gateway environment and sandbox policy verification
- Reconciliation: request/attempt/reservation/key/auth/route/pricing/model/token/amount/terminal-status across plugin, Model Router, and compound-loop records

**Tests:**
- All fake-upstream rejected-reservation paths → zero `RoundTrip` calls
- All streaming terminal paths → exactly one settlement
- `:8317` byte-identical before and after
- Secret scan: zero credential values in child env, argv, packets, receipts, logs, states
- Reconciliation schema: validate `release-loop-gateway-reconciliation/v1` fields across plugin, Model Router, and compound-loop records per spec R47-R51

### U8: Eligibility record and proof generation

Generate the gateway eligibility record binding all governed artifacts.

**Deliverables:**
- `release-loop-hard-cap-gateway-eligibility/v1` JSON record
- All SHA-256 fields populated: core, plugin, model-router, go toolchain, dependency lock, SBOM, reproducible build proof, egress policy, strict config, pricing, transform proof, proof generation
- No URL, key, token, account name, email, or management response body in record
- Eligibility false when any bound artifact changes

**Tests:**
- Each artifact mutation → `eligible: false`
- Record validates against schema
- Record contains no secrets or PII

## Scope boundaries

**Deferred to Integration deliverable (#2):** R40-R46 (prepare-pilot, approval packet, receipt binding, adapter eligibility, re-hash at paid entry). The eligibility record (U8) is generated but authority flows exercise it only in the Integration plan.

**Deferred to deployment gate:** Gateway deployment, OAuth login (spec Decision 5, SC12 bootstrap/rollback matrix).

**Deferred success criteria:** SC10 (live pilot), SC12 (OAuth bootstrap/rollback), SC13 (integration artifact drift), SC14 (reproducible build is partially covered by U1; egress probing requires deployment).

This plan produces a built, tested, eligible-false gateway ready for deployment approval.

## Verification

- `go test ./...` passes in all three governed forks
- `bash scripts/validate.sh` passes in compound-loop
- Two clean builds produce identical binary hashes
- Black-box suite proves zero network writes for all rejection paths
- Eligibility record validates and is `eligible: false` (no OAuth yet)
