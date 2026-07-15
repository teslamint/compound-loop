# Review Lanes

Every lane -- always-on, conditional, or project-defined -- emits `schemas/lane-findings.schema.json` findings. Only a lane's trigger and internal checklist differ; never its output shape. Confidence anchors (0/25/50/75/100) and their behavioral criteria are the schema's `_meta.confidence_anchors` -- reference, don't restate them per lane.

**Evidence is not optional** (`enforces: P3`): every finding carries at least one piece of code-grounded evidence (snippet, line reference, or traced pattern) and a `why_it_matters` that names what breaks -- not what is wrong. If you cannot cite code you read, the finding does not exist yet; go read it or drop it. This applies with full force in the single-call degradation tier, where no schema validator will catch an empty evidence field.

**Pre-delivery quality gate** (every lane, every tier): before returning, re-read each of your findings for vagueness (no nameable failure mode), false positives from skimming (did you actually trace it?), severity calibration against the schema's P0-P3 definitions, and line-number accuracy. A finding that fails this re-read gets fixed or dropped, never delivered as-is.

**Scope tiers** (every lane): primary = changed lines, full confidence. Secondary = unchanged code in the same block/function whose bug becomes reachable through the diff -- report it, `pre_existing: false`. Pre-existing = unrelated unchanged code the diff doesn't interact with -- `pre_existing: true`, reported separately, never counted toward the verdict. Test: if you'd flag the same issue on an identical diff without the surrounding file, it's pre-existing.

## Roster

| Lane | Kind | Model |
|---|---|---|
| correctness | always-on | session |
| tests | always-on | mid-tier |
| architecture | always-on | mid-tier |
| standards | always-on | mid-tier |
| security | conditional | session |
| adversarial | conditional | session |
| resilience | conditional | mid-tier |
| api-contract | conditional | mid-tier |
| migration | conditional, artifact-gated | mid-tier |
| project-defined | extension point | mid-tier |

## correctness (always-on)

Mentally execute the diff -- trace inputs through branches, track state across calls, ask "what happens when this value is X?" (`enforces: P2`)

**Hunts for** (5 categories): off-by-one/boundary mistakes; null/undefined propagation; race conditions and ordering assumptions (including TOCTOU); incorrect state transitions (invalid states reachable, error-path flags not cleared); broken error propagation (swallowed errors, fallback values masking failure).

**Non-flags**: style preferences; missing optimization (resilience's territory); naming opinions; defensive-coding suggestions for values that can't actually be null on this code path.

## tests (always-on)

**Focus**: coverage gaps, weak assertions, brittle tests, missing edge-case tests for the scenarios the diff introduces. When a plan was provided (`plan:` token or discovered), also verify its Scenario coverage map: every `Covers S<n>` integration test the map names exists in the diff or the tree, and no user scenario (S-ID) is left without a walking test — file a finding per missing walk, citing the S-ID. `enforces: P3`

**Non-flags**: test code style; adding tests for trivial getters or pure boilerplate with no branching.

## architecture (always-on)

Merges CE's maintainability lane with `ce-simplify-code`'s three reviewers into one lane -- a project's structural-quality pass is one perspective, not three.

**Reuse**: existing utilities/helpers that duplicate new code; inline logic that should use an existing utility instead.

**Quality** (9 categories): redundant state; parameter sprawl instead of restructuring; copy-paste-with-variation needing a shared abstraction; leaky abstractions; stringly-typed code where enums/branded types already exist; unnecessary wrapper elements (component-tree UI frameworks only); nested conditionals 3+ levels deep; unnecessary WHAT-comments (keep only non-obvious WHY); dead code/unused imports/exports (prefer the project's own dead-code linter over grep).

**Efficiency** (7 categories): unnecessary repeated work (N+1, duplicate reads/calls); missed concurrency for independent operations; hot-path bloat; recurring no-op updates lacking a change-detection guard; TOCTOU existence-checks before operating; unbounded memory/missing cleanup/listener leaks; overly broad reads (whole file for a portion, load-all for filter-one).

**Anti-over-simplification guardrails** (`enforces: P4`/`P5`): never inline a helper whose name carries a concept; check `git blame` before declaring an abstraction obsolete; a "simpler" version that ends up longer or harder to follow is not a finding. 1k-line regressions, coupling, and type-boundary leaks are this lane's structural-quality core, not a separate check.

**Non-flags**: anything the project's linter/formatter already catches; removing an abstraction whose testability/extensibility purpose you haven't confirmed is obsolete.

## standards (always-on)

Discover paths only (not contents) for every `AGENTS.md`/`CLAUDE.md` whose directory is an ancestor of a changed file, then read just those. **Focus**: frontmatter/reference conventions, naming, cross-platform portability, tool selection against the repo's own documented rules.

**Non-flags**: general code-quality opinions not codified in the repo's own standards files -- codified concerns route here; uncodified ones are suppressed (see `references/suppression.md`).

## security (conditional)

**Trigger**: auth middleware, public endpoints, user-input handling, permission checks, secrets management.

Think like an attacker: "how would I break this?", then trace whether the code stops you. **Hunts for**: injection vectors (SQL/XSS/shell/template, traced entry-to-sink); auth/authz bypasses (missing auth, broken ownership checks, privilege escalation, CSRF on state changes); secrets in code or logs; insecure deserialization; SSRF/path traversal.

**Bias toward firing**: security has a *lower* effective threshold than other lanes -- the cost of a missed vulnerability exceeds the cost of a false positive. A real-but-uncertain finding (anchor 50) should be filed at **P0** so it survives the confidence gate via the P0-at-50 exception, rather than suppressed for lack of full exploit confirmation.

**Non-flags**: defense-in-depth suggestions on already-protected code; theoretical physical-access/side-channel attacks; HTTP-vs-HTTPS in dev/test configs; generic hardening advice with no exploitable finding in the diff.

## adversarial (conditional)

**Trigger**: >=50 changed non-test/non-generated/non-lockfile lines, OR touches auth, payments, data mutations, external APIs.

Chaos-engineer framing -- construct failure scenarios rather than pattern-match. **Depth calibrated** to size + risk: quick (<50 lines, no risk signals) -- assumption violation only, at most 3 findings; standard (50-199 lines or minor risk) -- + composition failures + abuse cases; deep (200+ lines or strong risk signals) -- all four techniques including multi-step cascade chains.

**4 techniques**: assumption violation (data-shape/timing/ordering/value-range assumptions and what violates them); composition failures (contract mismatches, shared-state mutation, cross-boundary ordering, error-contract divergence); cascade construction (resource exhaustion, state-corruption propagation, recovery-induced failures); abuse cases (repetition, timing, concurrent mutation, boundary-walking with legitimate-looking input).

**Non-flags** (territory boundaries): single-component logic bugs (correctness's territory); known vulnerability patterns (security's); single I/O error handling and perf anti-patterns in isolation (resilience's); style/dead-code (architecture's); coverage gaps (tests'); contract breakage (api-contract's); migration safety (migration's). Adversarial's territory is the space *between* these -- combinations, sequences, emergent behavior no single-pattern lane catches. Titles describe the constructed failure ("Cascade: payment timeout triggers unbounded retry"), not the pattern name.

## resilience (conditional)

Perf + reliability merged into one operational-risk lane, not two overlapping passes.

**Trigger**: DB queries/ORM calls/caching/async code (perf side), or error handling/retries/circuit breakers/timeouts/background jobs/health checks (reliability side).

**Focus**: N+1 queries, missing indexes, unbounded allocations, missing timeout/retry/backoff, unhandled async rejections, background-job failure isolation.

**Non-flags**: premature optimization with no measured or evident hot path; retry/timeout behavior already provided by a framework default.

## api-contract (conditional)

**Trigger**: route definitions, serializer/interface changes, event schemas, exported type signatures, API versioning.

**Focus**: breaking changes to a published contract, silent shape drift, a missing version bump for a breaking change.

**Non-flags**: internal-only refactors with no externally observable shape change.

## migration (conditional, artifact-gated)

**Trigger** (hard gate, not judgment): the diff includes a migration/schema artifact -- `db/migrate/*`, `db/schema.rb`, `db/structure.sql`, Alembic/Flyway/Liquibase paths, or an explicit backfill/data-transform script. **Do not spawn** for model-only or query-only changes that reference columns without one of these artifacts in the diff.

**Focus**: schema drift against the resolved review base, missing rollback for destructive DDL, `NOT NULL` without a default, unguarded column rename/drop, backfill safety under concurrent writes.

## Project-defined lanes (extension point)

Read the repo's `AGENTS.md`/`CLAUDE.md` for project-declared review lanes -- a free-form section naming a focus area and its non-flags, with no schema requirement beyond emitting standard lane-findings output. This replaces hardcoded stack personas: a Stimulus/Turbo project might declare a frontend-async-races lane; a Swift project, an iOS-lifecycle lane. Select and announce these exactly like conditional lanes -- diff-driven judgment, not keyword matching. Absent such a section, no project-defined lanes run; that is not a coverage gap to report.
