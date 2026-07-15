# Implement-phase distillation (from distill-implement agent)

## Idea inventory

**1. SP test-driven-development**
- Iron Law: "NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST" — code-before-test must be deleted, not adapted/kept as reference
- Red-Green-Refactor with mandatory verify-red (confirm failure is for the right reason, not a typo) and mandatory verify-green (confirm pass + no other regressions + pristine output)
- "Tests-after prove nothing" argument: passing immediately ≠ tested; tests-after answer "what does this do" not "what should this do"
- Extensive Rationalization table + Red Flags list (anti-bypass framing) — treats skipping TDD as a discipline-failure to catch, not a style choice
- Verification checklist gate before "done" (every function has a test, watched each fail, minimal code, edge cases covered)
- "When Stuck" table (don't know how to test → write wished API; must-mock-everything → DI problem)
- Debugging integration: bug fix must start with a failing test reproducing it

**2. SP systematic-debugging**
- Iron Law: "NO FIXES WITHOUT ROOT CAUSE INVESTIGATION FIRST"
- Four Phases: Root Cause Investigation → Pattern Analysis → Hypothesis+Testing → Implementation
- Multi-component evidence gathering recipe: instrument every component boundary, run once, THEN analyze where it breaks (concrete bash example for CI→build→signing)
- Pattern Analysis phase is distinctive: find working examples in codebase, diff against broken, list every difference without dismissing small ones
- Scientific method framing: single hypothesis stated explicitly ("I think X because Y"), smallest test, one variable at a time
- **3+ failed fixes → STOP, question the architecture** (not just "try again") — explicit trigger for design-level escalation, separate from a failed hypothesis
- Red Flags phrased as self-caught internal monologue ("quick fix for now", "just try changing X")
- "your human partner's signals you're doing it wrong" — a table mapping human phrases to debugging failure modes
- Supporting technique files referenced: root-cause-tracing.md, defense-in-depth.md, condition-based-waiting.md
- Real-world impact stats (95% first-fix rate vs 40%) used as motivation

**3. SP executing-plans**
- Minimal 3-step process: Load/Review plan → Execute tasks sequentially with todos → finishing-a-development-branch handoff
- Explicitly self-deprecating: tells the user subagent-driven-development is better when subagents are available; this skill is the no-subagent fallback
- "When to Revisit Earlier Steps" — plan changes or fundamental rethink sends you back to Step 1
- Never start implementation on main/master without explicit consent

**4. SP subagent-driven-development**
- Core loop: fresh implementer subagent per task → task review (spec compliance + code quality, BOTH required verdicts) → fix subagent for Critical/Important → final whole-branch reviewer at the end
- **Pre-Flight Plan Review**: scan whole plan once for internal contradictions before Task 1, batch all conflicts into one question
- **Model Selection by task-complexity signals** (cheap/standard/most-capable) + warning: omitted model silently inherits expensive session default; "turn count beats token price"
- **Implementer status protocol**: DONE / DONE_WITH_CONCERNS / NEEDS_CONTEXT / BLOCKED, each with defined orchestrator response
- **Reviewer "⚠️ Cannot verify from diff" items** — orchestrator (not reviewer) resolves these using cross-task context
- **Constructing Reviewer Prompts**: never pre-judge/pre-rate a finding's severity for the reviewer, never tell it what not to flag; global-constraints block = verbatim binding requirements
- **File Handoffs discipline**: task-brief script extracts task text to a file (not pasted), report file named to match brief, reviewer gets 3 file paths — rationale: pasted content stays in context and is re-read every turn
- **Durable Progress ledger** (`.superpowers/sdd/progress.md`) surviving compaction — most expensive failure = re-dispatching completed tasks after context loss; trust ledger + git log over recollection
- Plan-mandated finding conflicts escalate to the human, never silently dismissed or fixed
- Final-review fixes: ONE fix subagent for the complete findings list, not one per finding
- Red Flags: never dispatch multiple implementers in parallel — conflicts; never skip ledger check on resume

**5. SP dispatching-parallel-agents**
- Decision tree: independent? → parallelizable (no shared state)? → dispatch multiple in ONE response
- Agent prompt structure: focused / self-contained / specific-about-output, with good-vs-bad example
- Common Mistakes table (too broad / no context / no constraints / vague output)
- "Don't use when" list: related failures, need full system context, agents would interfere
- Post-dispatch verification: read each summary, check conflicts, run full suite, spot-check for systematic agent errors

**6. SP using-git-worktrees**
- Step 0 "Detect Existing Isolation" — GIT_DIR vs GIT_COMMON check with explicit **submodule guard**
- Priority: native worktree tool > git worktree fallback > work in place; "never fight the harness"
- Directory selection: explicit user pref > existing `.worktrees`/`worktrees` > default `.worktrees/`
- Mandatory `git check-ignore` before creating project-local worktree dir
- Sandbox fallback: permission error → report and work in place
- Baseline verification: run tests immediately after setup, ask before proceeding on failure

**7. CE ce-work**
- Phase 0 Input Triage: plan-file vs bare-prompt, Trivial/Small-Medium/Large complexity router (Large → suggest brainstorm/plan)
- Plan is a **decision artifact, not an execution script** — never edit plan body during execution
- Branch-name quality check: detect auto-generated names, suggest rename
- **Execution Strategy table**: Inline / Serial subagents / Parallel subagents, gated by **Parallel Safety Check** (file-to-unit overlap detection, two degrade paths by worktree availability)
- **Post-batch merge protocol** (worktree-isolated): review diff → merge sequentially in dependency order → on conflict, abort merge and re-dispatch that unit serially (never hand-resolve) → tests after each merge → cleanup
- **Shared-directory fallback**: subagents forbidden from staging/committing/running suite; orchestrator does after batch; discovered file-collision check (actual files vs declared) with recovery path
- Test Discovery + **Test Scenario Completeness table** (happy/edge/error/integration + "how to derive if missing")
- **System-Wide Test Check** — 5-question gate before task done (what fires / real chain / orphaned state / other interfaces / error strategy alignment) with leaf-node skip condition
- Incremental commit heuristic: "can I write a commit message that isn't WIP? If yes, commit."
- "Simplify as you go" at phase boundaries (every 2-3 units)
- Two-tier code review: Tier 1 (harness-native, fix inline) vs Tier 2 (separate review-then-fix, batched-by-file parallel fix)
- Anti-pattern: don't re-scope plan into "human-time phases" or session subsets — use subagent dispatch for context pressure

**8. CE ce-debug**
- 5-phase flow (Triage → Investigate → Root Cause → Fix → Handoff) with trivial-bug fast-path through same user-choice gate (fix-now vs diagnosis-only)
- **Prediction discipline**: for uncertain causal-chain links, form a prediction in a DIFFERENT code path that must also be true; wrong prediction + working fix = symptom fix
- **Assumption audit** before hypothesis: list "must be true" beliefs, verified vs assumed — stuck = usually wrong assumption
- Hypotheses require **grounding observation** (concrete runtime value/log line), reject "X seems off"
- **Causal chain gate**: no fix until trigger→symptom chain has no gaps (user can authorize best-available)
- Backward-tracing recipe: stack trace bottom-to-top, first frame with invalid input, instrument boundaries, valid→invalid transition
- Smart Escalation table: hypotheses in different subsystems → architecture problem; contradictory evidence → wrong mental model; works-locally-fails-CI → environment; fix works but prediction wrong → symptom fix
- **Redesign signals** (brainstorm handoff): wrong responsibility/interface, requirements wrong, every fix is a workaround — "big bug" ≠ "design problem"
- Failed fix → explicitly invalidate hypothesis with stated evidence before new one — blocks incremental patching
- Conditional defense-in-depth and post-mortem, trigger-gated (pattern in 3+ files / catastrophic; production bug / 3+ locations)
- Structured handoff, branch-ownership-aware next steps; calibrated learning-capture offer
- Cross-tool abstraction: names blocking-question tool per harness

**9. EC release-loop implement-phase.md**
- Condensed re-implementation of SP SDD + CE model-selection, adapted for cross-harness (Entry/Exit/Gate header, `.release-loop/` layout)
- `.release-loop/progress.md`, `briefs/`, `reports/`, `reviews/` directory convention
- Retro-backed evidence for two-level review (v0.13.0: branch review caught 1 Critical + 2 Important all 5 task reviewers missed)
- Cross-harness model note: Codex/OMX `agent_type` inherits role model; override only with concrete reason
- Max-3-rounds cap on review-fix loops before escalating (unique numeric bound)

## Overlap map

| Concept | Sources | Strongest |
|---|---|---|
| TDD enforcement | SP TDD, CE ce-work (Execution note), CE ce-debug | **SP TDD** standalone; orchestration references it. Add CE's per-unit Execution note as mode hook |
| Debugging | SP systematic-debugging, CE ce-debug | **CE ce-debug spine** (prediction discipline, assumption audit, causal-chain gate, escalation table, redesign signals) + SP's boundary-instrumentation recipe folded in |
| Plan execution loop | SP SDD, SP executing-plans, CE ce-work, EC implement | **SP SDD + EC together**; CE ce-work's test-completeness + System-Wide Test Check extracted; executing-plans = no-subagent fallback footnote |
| Parallel dispatch + degradation | SP dispatching, SP SDD (bans it), CE ce-work | **CE ce-work** only one engineering degradation (Parallel Safety Check + worktree/shared-dir dual protocol) |
| Worktree isolation | SP using-git-worktrees, CE ce-work (consumer), EC (branch only) | **SP using-git-worktrees** (submodule guard, native-first ordering) |

## Recommended merged skeleton

**3+1 skills**: test-driven-development (SP verbatim + CE Execution-note hook), systematic-debugging (CE spine + SP techniques, drop harness-specific tool names), implementing-plans (big merge: EC entry/gate header + CE execution strategy/degradation + SP file handoffs/status protocol/reviewer rules + EC 3-round cap + CE test checks + SP one-fixer rule), git-worktree-isolation (SP near-verbatim).
Parallel dispatch: NOT a separate skill — fold prompt heuristics into debugging (investigation) and implementing-plans (implementation).

## Unresolved tension
CE ce-work's plan-format assumptions (U-IDs, Execution note, Patterns to follow, Scope Boundaries, Deferred) are richer than SP/EC plan formats. Merged implementing-plans needs plan-format agreement with the planning-phase skill (plan schema decision required).
