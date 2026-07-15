# Review-phase distillation (from distill-review agent)

## Idea inventory

### 1. SP requesting-code-review
- Context isolation: reviewer gets crafted prompt, never requester's session history
- Trigger taxonomy: Mandatory (after each subagent task, major feature, before merge) vs Optional (stuck, before refactor, after complex bugfix)
- Minimal dispatch: BASE_SHA/HEAD_SHA + 4-placeholder template, one general-purpose subagent
- 3-tier action: Critical→now, Important→before proceeding, Minor→later; "push back if reviewer wrong" first-class
- Red-flags checklist

### 2. SP receiving-code-review
- Pipeline: READ → UNDERSTAND → VERIFY → EVALUATE → RESPOND → IMPLEMENT (verify before implement)
- Forbidden performative agreement ("You're absolutely right!") — catch and delete
- Unclear-feedback gate: ANY unclear item → clarify ALL before implementing ANY
- Source-specific skepticism: external reviewer → 5-question gate (correct for codebase? breaks something? reason current impl exists? cross-platform? full context?)
- YAGNI check: grep actual usage before "implement properly" — remove-if-unused beats gold-plating
- Fix ordering: clarify → blocking → simple → complex, test each individually
- Graceful pushback-reversal; GitHub thread-reply mechanic

### 3. CE ce-code-review (richest)
- Tiered persona selection: 4 always-on + 2 unstructured CE agents + 7 cross-cutting conditional + 2 stack-specific + 1 migration-gated = 14; agent judgment not keyword matching; announced with justifications
- mode:agent JSON contract: single JSON object, deterministic schema (status/verdict/scope/intent/reviewers/findings/actionable_findings); markdown default; deprecated aliases collapsed
- **Confidence gating**: 5 discrete anchors (0/25/50/75/100) with behavioral self-checks; floats banned
- Confidence vs severity independent axes; autofix_class/owner = signal not gate
- **Merge/dedup Stage 5**: fingerprint = normalize(file)+line_bucket(±3)+normalize(title); cross-reviewer agreement promotes confidence one anchor; disagreements annotated; mode-aware demotion (weak P2/P3 testing/maintainability → testing_gaps/residual_risks); confidence gate LAST with P0 exception (P0@50+ survives)
- **Stage 5b validation pass**: independent validator per surviving finding, cap 15 (never drop P0/P1); infra-failure: P0/P1 kept-marked-degraded, P2/P3 dropped
- Findings schema two-tier: compact to orchestrator / full artifact (why_it_matters/evidence) to disk
- Severity P0-P3 + autofix_class (gated_auto/manual/advisory) × owner
- Diff-scope discovery: local-aligned/pr-remote/branch-remote 3-check test (branch match, not cross-repo, PR head ancestor of HEAD)
- Protected artifacts (docs/brainstorms, plans, solutions never flagged for deletion)
- Bounded parallel dispatch: capacity errors = backpressure, retry
- Model tiering: correctness/security/adversarial inherit session model; rest mid-tier
- Stage 5c bias-to-act: apply clear reversible improvements without severity gate; commit only if pre-review tree clean; never push
- Quality gates: re-read findings for vagueness/false-positive/calibration/line accuracy
- Output discipline: pipe tables only, forbidden shapes enumerated
- Adversarial persona: chaos-engineer framing (assumption violation/composition failure/cascade/abuse), depth calibrated to size+risk
- Security persona: files uncertain-critical at P0 to survive gate; explicit non-flags
- Correctness persona: "mentally execute", 5 bug categories, non-flags
- subagent-template: 8-category false-positive suppression catalog; suggested_fix "most defensible default + name assumption", no soft-punt
- validator-template: 3 questions (real? introduced by diff? not handled elsewhere?), conservative-reject

### 4. CE ce-simplify-code
- Quality-only mandate (not bug hunt)
- Scope priority: user-named (never widen) → branch-diff → recent files → ask
- 3 parallel reviewers: Reuse / Quality (9 categories) / Efficiency (7 categories incl TOCTOU)
- Anti-over-simplification guardrails (don't inline concept-naming helper; git blame first)
- Fix applied directly w/ same-input/output/side-effects check; typecheck+lint full + scoped tests; revert-don't-weaken

### 5. EC review-phase.md
- Phase-gate framing (Entry/Exit/Gate), AUTO-advance when clean
- Deliberately redundant with implement's final review (rationale stated)
- Model discipline hard rule: most capable model, always, for final gate
- 6-area single-reviewer brief (correctness, integration, edge cases, contract consistency, security, test coverage)
- 3-tier severity (Critical/Important/Minor)
- Fix dispatch anti-pattern: ONE fixer with complete list (bans per-finding fixer)
- Re-review loop hard cap 3; re-review gets ORIGINAL findings list; after cap: Minor-only advance / Critical-Important escalate
- Progress-state schema for resumability

## Overlap map (strongest)
- Persona selection / confidence / dedup / JSON contract / scope discovery / suppression catalog: CE only — keep verbatim
- Severity: CE P0-P3 for machine + 3-tier rollup for humans
- Fix dispatch: split by mode — CE bias-to-act (interactive) vs EC one-fixer + capped loop (pipeline)
- Receiving feedback: SP receiving-code-review only source — keep as other half
- Trigger taxonomy: SP requesting; phase-gate: EC (complementary)
- Model tiering: CE per-persona > EC blanket
- Quality-only pass: ce-simplify-code unique

## Recommended merged skeleton (lane contract)
0. Args: mode:agent | default; base:/plan:; deprecated tokens ignored
1. Entry/Exit framing: standalone AND phase-gate callers; SP trigger taxonomy
2. Scope discovery: CE Stage 1 verbatim (3-check test)
3. Intent+context: CE Stage 2 thinned; learnings-researcher + previous-comments folded here (context, not lanes)
4. Lanes: 4 always-on (correctness, tests, architecture [merges maintainability + simplify-code's 3 reviewers], standards) + 5 conditional (security [bias toward firing], adversarial, resilience [perf+reliability merged], api-contract, migration) + N project-defined via AGENTS.md extension point (from 14 → 4+5+N)
5. Dispatch: (1) native parallel bounded w/ backpressure → (2) sequential passes → (3) codex exec single-call all-lanes-serial; model tiering: 3 top lanes inherit session model
6. Merge/dedup/confidence gate: CE Stage 5 verbatim (strongest mechanism in corpus)
7. Verification gate dual path: interactive = CE 5b validator wave (cap 15); pipeline/headless = EC round-capped re-review loop (cap 3, original list, escalate)
8. Fix dispatch mode-dependent: interactive = CE 5c bias-to-act; pipeline = EC one-fixer-complete-list
9. Output: CE pipe-table markdown / mode:agent JSON + 3-tier rollup field
10. Suppression: CE 8-category catalog + protected artifacts + EC no-flag list merged
11. Receiving-review mode: SP receiving-code-review nearly intact (other half of skill)

Dropped: safe_auto/review-fixer legacy; 2 unstructured CE agents as lanes; stack-specific personas (→ project-defined extension); previous-comments lane; template file indirection; separate implement-review framing (collapsed: same skill, two callers)
