# Principles

This is the normative charter of compound-loop. Every skill in this plugin exists to uphold these principles; every check inside a skill is an enforcement tool for one of them. Each principle is stated in four parts: **statement**, **rationale**, **boundary** (where it does NOT apply), and **enforcement** (which skill mechanisms implement it).

**Precedence**: a consuming repository's own documented conventions (AGENTS.md, CLAUDE.md, working agreements) override the defaults here. These principles fill gaps; they do not overrule the house rules of the codebase you are working in.

Checks inside skills carry an `enforces:` tag naming the principle they implement. A check without a principle is a rule nobody can justify; a principle without a check is a slogan. Both are defects.

---

## P1. No production code without a failing test first

- **Statement**: Write a failing test, watch it fail for the right reason, then write the minimal code to pass. Code written before its test is deleted, not adapted.
- **Rationale**: Tests written after the fact answer "what does this do," not "what should this do." A test you never saw fail proves nothing.
- **Boundary**: The plan may mark a unit `execution: characterization-first` (legacy code) or `execution: skip-test-first` (config/rename-only changes). The orchestrating skill decides the mode; the discipline inside the chosen mode is not negotiable.
- **Enforcement**: `tdd` (entire skill), `planning` (test scenarios per unit), `implementing` (per-unit execution notes).

## P2. No fixes without root-cause investigation first

- **Statement**: Reproduce, trace the causal chain from trigger to symptom with no gaps, and state a grounded hypothesis before changing code.
- **Rationale**: Symptom fixes multiply bugs. A fix that "works" without a verified causal chain has moved the defect, not removed it.
- **Boundary**: Trivial bugs may take the fast path, but through the same gate (the user chooses fix-now vs diagnosis-only); the gate is never skipped silently.
- **Enforcement**: `debugging` (causal-chain gate, prediction discipline, assumption audit), `reviewing` (correctness lane's "mentally execute" rule).

## P3. No completion claims without fresh verification evidence

- **Statement**: Before claiming "done", "fixed", or "passing", run the proving command in full, in this message, and read its output. Extrapolation, memory, and subagent self-reports are not evidence.
- **Rationale**: The most expensive failures are false completions — they end investigation while the defect survives.
- **Boundary**: None. Violating the letter of this rule is violating its spirit.
- **Enforcement**: `shipping` (verification gate, re-fetch-before-claiming-resolved), `retrospective` (measured-vs-declared comparison runs measurements fresh), `implementing` (verify-red/verify-green), `reviewing` (validator pass).

## P4. KISS — complexity must be justified by a requirement

- **Statement**: Choose the simplest implementation that satisfies the stated requirement. Add abstraction, configurability, or extension points only when a present requirement demands them.
- **Rationale**: Unjustified complexity is a permanent tax on every future reader and modifier, paid whether or not the flexibility is ever used.
- **Boundary**: Low-cost polish with low carrying cost is allowed (see P6); simplicity is not an excuse to drop error handling a requirement implies.
- **Enforcement**: `designing` (attachment-gap probe: "smallest version that proves the bet"), `planning` (anti-expansion rule), `implementing` (simplify-as-you-go passes), `reviewing` (architecture lane: deep nesting, unnecessary wrappers, leaky abstractions).

## P5. DRY — but accidental duplication is not real duplication

- **Statement**: Extract shared logic when two sites repeat for the same reason. Do not merge code that merely looks similar if it changes for different reasons.
- **Rationale**: Real duplication drifts apart and breeds inconsistent fixes. False deduplication couples unrelated concerns and makes both harder to change.
- **Boundary**: Never inline a helper whose name carries a concept; check `git blame`/history before declaring an abstraction obsolete; early duplication during implementation may be intentional divergence — simplification passes run at phase boundaries, not after every unit.
- **Enforcement**: `reviewing` (architecture lane: copy-paste variants + reuse detection, with anti-over-simplification guardrails), `implementing` (simplify-as-you-go), `compound`/`compound-refresh` (one canonical doc per problem; overlap scoring; "two docs describing the same problem will drift apart").

## P6. YAGNI applies to carrying cost, not coding effort

- **Statement**: Reject speculative features and hypothetical future-proofing. Accept low-cost, high-value polish when its ongoing maintenance cost is small.
- **Rationale**: The cost that matters is not writing the code but carrying it — reading, testing, migrating, and reasoning about it forever after.
- **Boundary**: When a reviewer says "implement properly," first check whether the thing is used at all — removal beats gold-plating.
- **Enforcement**: `designing` (core principle + scope tiering), `planning` (deferred-to-follow-up section), `reviewing` (receiving-mode YAGNI usage check).

## P7. Outward steps belong to the human

- **Statement**: Skills may commit locally and prepare artifacts, but pushing, merging, publishing, and anything that leaves the machine requires explicit human approval or an explicit `--auto` grant with stated conditions.
- **Rationale**: Outward actions are hard to reverse and carry the user's name. Autonomy ends where the blast radius leaves the working tree.
- **Boundary**: `--auto` mode may auto-merge only when its declared conditions hold (CI green, no open Critical findings); the design-approval gate is never automated.
- **Enforcement**: `shipping` (merge gate default USER), `release-loop` (Design gate always USER), `reviewing` (never pushes), `designing` (human approval gate).

## P8. State lives in files, not in the conversation

- **Statement**: Every piece of state that must survive — progress, findings, decisions, metrics — is written to a file or committed to git at the moment it is produced. The conversation is presentation, not storage.
- **Rationale**: Context windows compact, sessions crash, agents restart. The most expensive observed failure is re-doing completed work because the record of it lived only in memory.
- **Boundary**: Ephemeral reasoning that no later step depends on does not need a file.
- **Enforcement**: `release-loop` (progress.md as source of truth; trust file + git log over recollection), `implementing` (progress ledger, file-based handoffs), `reviewing` (findings artifacts on disk), `retrospective` (retro doc + durable tracker for carry-forwards).

## P9. Never fight the harness

- **Statement**: Prefer native capabilities in this order: harness-native tool → portable fallback → graceful sequential degradation. Detect capabilities; never assume them, and never hard-depend on one harness's feature for correctness.
- **Rationale**: The same skill must produce the same outcome in Claude Code and Codex. Correctness that depends on hooks, parallel subagents, or a specific tool name is not portable — it is a silent fork.
- **Boundary**: Quality enhancements (parallel review lanes, worktree isolation) may exploit native features when present; only correctness must not.
- **Enforcement**: every skill's dispatch section (native parallel → sequential passes → single-call fallback), `worktree-isolation` (native tool → git worktree → work in place), cross-harness question-tool table (blocking tool per harness → numbered options fallback), file-based inter-skill contracts (`mode:agent` JSON, `mode:headless` terminal signals).
