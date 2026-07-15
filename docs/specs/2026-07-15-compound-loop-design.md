# compound-loop Design Spec

- Date: 2026-07-15
- Status: draft
- Sources distilled: superpowers 6.1.1 (SP), compound-engineering 3.11.2 (CE), entirecontext release-loop (EC)

## Summary

compound-loop is a single plugin of 12 skills covering the engineering lifecycle (Design → Plan → Implement → Review → Ship → Retro) plus knowledge compounding, working identically in Claude Code and Codex. Each skill is a distillation of the strongest mechanisms from SP, CE, and EC for that phase — selected idea by idea, with dropped material recorded. A root-level PRINCIPLES.md charter (9 principles) is the normative layer; every check in every skill carries an `enforces:` tag tracing back to it.

## Goals and non-goals

**Goals**
- One curated skill set replacing day-to-day use of superpowers + compound-engineering + the project-local release-loop.
- Identical outcomes on Claude Code and Codex; quality (not correctness) may scale with harness capability.
- Retrospective as a standalone skill usable outside the loop, feeding knowledge compounding.
- Measurable success criteria declared at design time and measured at retro time — closing the loop no source system closes.

**Non-goals**
- Porting all 38 CE skills / 43 CE agents (product-specific ones stay behind).
- ce-optimize's full experiment loop (distilled to "declared measurable criteria + retro measurement"; may become a skill later).
- Gemini/Cursor support (nothing precludes it; not verified in v0.1).

## Success criteria (measured at retro)

1. `.claude-plugin/plugin.json` and `.codex-plugin/plugin.json` exist and parse as valid JSON.
2. 12 skills, each `skills/<name>/SKILL.md` with valid frontmatter (`name`, `description`) passing a stdlib validation script.
3. `PRINCIPLES.md` has 9 principles, each with statement/rationale/boundary/enforcement.
4. `schemas/` contains: findings JSON schema, plan frontmatter + unit contract, retro document template.
5. Spec and implementation plan committed to git.
6. Claude Code loads the plugin from a local marketplace; Codex discovers the skills via symlink — both verified by command output, not assumption.

## Architecture

### Layering

```
PRINCIPLES.md              ← normative charter (9 principles)
release-loop               ← orchestrator: 6 phases, file-based state
  ├── designing            ← phase skills, each independently invocable
  ├── planning
  ├── implementing ──┬── tdd
  │                  ├── debugging
  │                  └── worktree-isolation     ← always-on utilities
  ├── reviewing
  ├── shipping
  └── retrospective ───── compound ── compound-refresh
schemas/                   ← inter-skill contracts (findings JSON, plan schema, retro template)
```

The orchestrator holds no phase logic — it sequences, gates, and persists state. Every phase skill works standalone; the loop is a caller, not a container.

### Cross-harness foundation (consulted with Codex gpt-5.6-sol, 2026-07-15)

- **SKILL.md is the unit of portability.** Frontmatter limited to the open Agent Skills standard (`name`, `description`). Codex-only metadata, if ever needed, goes in `agents/openai.yaml`, never in shared frontmatter.
- **Dispatch degradation, stated in every skill that parallelizes:** native parallel subagents (bounded; capacity errors are backpressure, not failure) → sequential passes → single-call fallback (all lanes run serially inside one prompt, still emitting per-lane structured output). Correctness never depends on tier 1.
- **State lives in files** (enforces P8): `.release-loop/progress.md` for the loop, plan frontmatter for plans, findings artifacts on disk for reviews. Hooks and MCP are enhancements only.
- **Blocking questions:** use the harness's blocking question tool (`AskUserQuestion` in Claude Code, `request_user_input` in Codex); numbered chat options only when no blocking tool exists or the call errors.
- **Invocation spelling** documented everywhere as `/name` (Claude Code) and `$name` (Codex).

### Inter-skill contracts

| Contract | Producer → Consumer | Shape |
|---|---|---|
| Plan schema | planning → implementing, reviewing | Frontmatter (`title/type/status/date/execution` required) + Implementation Units with stable U-IDs, Files/Interfaces, categorized test scenarios (happy/edge/error/integration) linked to acceptance criteria ("Covers AE3") |
| Findings JSON | reviewing `mode:agent` → implementing, shipping, release-loop | Single JSON object: `status/verdict/scope/reviewers/findings[]` with per-finding `title/severity(P0-P3)/file/line/confidence(0|25|50|75|100)/autofix_class/owner/suggested_fix` + 3-tier rollup field (Critical/Important/Minor) |
| Headless capture | retrospective → compound | `mode:headless` invocation; terminal signal strings `Documentation complete` / `Documentation skipped`; Applied vs Recommended report split |
| Loop state | release-loop ↔ all phases | `.release-loop/progress.md`: phase, task, branch, base branch, PR number, CI attempts, review rounds, comments fixed/deferred |
| Success criteria | designing → retrospective | Spec's required Success Criteria section: each criterion = statement + measurement method (command or judgment rubric) |

The plan-schema agreement resolves the tension flagged during distillation: CE ce-work's rich per-unit metadata assumed a CE-shaped plan; here `planning` emits and `implementing` consumes one documented schema.

## Skill specifications

Each entry lists: purpose, distilled mechanisms (source → what), and dropped material. "Verbatim" means the mechanism is ported with only naming/path normalization.

### 1. release-loop (orchestrator)

EC release-loop retained as the spine: six phases, phase-transition table, flags (`--auto`, `--skip-design`, `--skip-plan`), resume protocol ("trust progress file and git log over conversation memory", enforces P8). Rewritten so each phase's protocol section becomes a one-paragraph invocation of the corresponding standalone skill plus gate handling. Gates: Design = USER always (enforces P7); Ship = USER unless `--auto` with CI green + no open Critical; others AUTO.

Dropped: EC's inline phase protocols (now live in the phase skills); project-specific pitfalls hardcoded in phase docs (moved to a per-repo pluggable pitfalls file, see shipping).

### 2. designing

Purpose: turn an idea into an approved spec with measurable success criteria. WHAT, not HOW.

| Source | Distilled |
|---|---|
| EC design-phase | Entry/Exit/Gate contract; context scan as literal commands (git log, AGENTS.md, ROADMAP, previous retros for carry-forward); approach template; User Scenarios before Architecture ("motivation before mechanism"); spec doc skeleton incl. Open Decisions; **independent review gate before the user sees the spec** (reviewer subagent or advisor tool; retro-cited: caught 2 critical flaws self-review missed); Spec Quality Signals (good-vs-bad contrastive pairs) near-verbatim; "Gate: USER — always human, never auto-skip" |
| SP brainstorming | HARD-GATE (no implementation before approval) + "This Is Too Simple To Need A Design" anti-pattern verbatim; 4-point spec self-review (placeholder/consistency/scope/ambiguity), fix inline; decomposition trigger for multi-subsystem requests; design-for-isolation test; terminal-state constraint (only `planning` is invoked next) |
| CE ce-brainstorm | **Scope tiering** (Lightweight/Standard/Deep + Deep-feature vs Deep-product) gating all downstream ceremony; **rigor-gap probes** (evidence/specificity/counterfactual/attachment + durability for Deep-product; one gap = one open-ended probe); Interaction Rules 1–6 verbatim (one question per turn, single-select preferred, cross-harness blocking-tool table, precise open-ended test); "requirements already clear" fast path; integration check before exiting dialogue; approach granularity (mechanism, never implementation specifics); anti-anchoring order; optional higher-upside challenger; "verify before claiming absence"; YAGNI-on-carrying-cost principle; prose economy + contradiction-in-one-pass test; R-ID convention when warranted |
| Elevation beyond all sources | **Success Criteria is a required spec section**: every criterion states what is measured and how (command for hard metrics, judgment rubric for soft ones). No source mandates this; ce-optimize's measurable-goal discipline is its ancestor. Consumed by `retrospective`. |

Dropped: ce-ideate engine (upstream concern; one-line pointer only); HTML output machinery; CONCEPTS.md capture (optional tail step); Path A/B synthesis nuance (simplified: one-line synthesis always, full confirmation gate for Standard+); SP visual companion (Claude-Code-specific; optional appendix note).

### 3. planning

Purpose: turn an approved spec into a plan executable by an engineer (or agent) with zero codebase context.

| Source | Distilled |
|---|---|
| CE ce-plan | Entry check — **is a plan doc warranted at all** (skip-criteria + false-atomic stress tests, near-verbatim); compressed scope confirmation before research spend; **U-ID stability rule** (never renumber); **planning-time vs implementation-time unknowns** (3.6, verbatim); **anti-expansion** (3.7: tangential discoveries → Deferred to Follow-Up Work); test-scenario taxonomy (happy/edge/error/integration + AE-links); metadata/frontmatter contract; prose economy; file naming `docs/plans/YYYY-MM-DD-NNN-<type>-<name>-plan.md`; **risk-scored deepening pass** compressed to 5 trigger categories (vague rationale, missing risk treatment, weak sequencing, thin external grounding, unclear verification) — skip when nothing scores; deepening change discipline (tighten prose OK, implementation code NOT, never renumber U-IDs); outstanding-question triage (planning-owned vs product blocker) |
| CE ce-doc-review | Persona activation-signal pattern for the deepening reviewers (Architecture/Feasibility always; Security/Risk and Scope/Coherence conditional, each with explicit activation and non-activation signals); backpressure framing; cross-round evidence-overlap suppression as optional refinement |
| SP writing-plans | Zero-context assumption; file-structure phase before tasks; task right-sizing ("smallest unit worth a fresh reviewer's gate"); literal task template (Files Create/Modify/Test + Interfaces Consumes/Produces + 2–5 min numbered TDD steps); no-placeholder banned-phrase list verbatim; type-consistency self-check; 2-option execution handoff (subagent-driven vs inline) |
| EC plan-phase | Code vs **non-code dual task templates** (non-code: Write → self-review-against-spec → Commit), deliverable type recorded in plan frontmatter (not a side-channel file); task-count smell test (3–7 typical); self-review additions: **callers+invariants check** and prior-retro carryover; progress-file pointer write for headless/pipeline invocations |

Dispatch degradation stated verbatim in the deepening section: parallel reviewers → sequential when no parallel primitive exists.

Dropped: OUTPUT_FORMAT html machinery; Proof/issue-tracker handoff options; approach-altitude state machine (one-line pointer); ce-plan's paragraph-budget scoping templates.

### 4. implementing

Purpose: execute a plan to completion with review checkpoints, surviving context loss, on any harness.

| Source | Distilled |
|---|---|
| SP subagent-driven-development | File-handoff discipline (task-brief file, report file, review package — never paste into context; rationale kept); implementer status protocol (DONE / DONE_WITH_CONCERNS / NEEDS_CONTEXT / BLOCKED with defined orchestrator responses); reviewer-prompt rules verbatim (never pre-judge severity, never say what not to flag); "⚠️ cannot verify from diff" resolved by orchestrator; pre-flight plan contradiction scan batched into one question; durable progress ledger (compaction survival framing); final branch review + ONE fix subagent for the complete findings list; plan-mandated finding conflicts escalate to human |
| CE ce-work | Plan is a decision artifact — never edit plan body during execution; execution strategy table (Inline/Serial/Parallel) gated by **parallel safety check** (file-overlap detection); **dual degradation protocols**: worktree-isolated (commit-in-branch → sequential merge in dependency order → on conflict abort and re-dispatch serially, never hand-resolve) vs shared-directory (subagents never stage/commit/run suite; orchestrator batches; discovered-collision check beyond declared file lists); test scenario completeness table; **System-Wide Test Check** (5 questions, leaf-node skip condition); incremental commit heuristic ("can I write a non-WIP message?"); **simplify-as-you-go at phase boundaries** (every 2–3 units, not every unit — early duplication may be intentional divergence; enforces P4/P5); anti-pattern: never re-scope into human-time sessions |
| EC implement-phase | Directory convention generalized to `.release-loop/{briefs,reports,reviews}/` + `progress.md`; max-3-rounds cap on review-fix loops before escalation; retro-cited justification for two-level review (task + branch); cross-harness model-selection phrasing (Codex agent_type inherits role model) |
| SP executing-plans | Survives as one line: harness with no subagent primitive → sequential inline execution with human checkpoints between tasks |
| SP dispatching-parallel-agents | Prompt-writing heuristics (focused/self-contained/specific-output + common-mistakes table) folded into the dispatch sections here and in debugging — not a separate skill |

Dropped: CE Phase-0 complexity router (upstream planning concern); Figma sync; branch-name quality check; SP model-pricing tables (kept as one "turn count beats token price" note).

### 5. tdd

SP test-driven-development near-verbatim: Iron Law (P1), red-green-refactor with mandatory verify-red (right reason) and verify-green (no regressions), delete-don't-adapt rule, rationalization table, red flags, completion checklist, "when stuck" table. One addition: per-unit `execution:` note hook (test-first / characterization-first / skip-test-first) chosen by the plan, so orchestration decides applicability without weakening the discipline inside the chosen mode.

Dropped: nothing substantive (skill has no harness dependencies).

### 6. debugging

CE ce-debug as the spine: 5-phase flow (Triage → Investigate → Root Cause → Fix → Handoff); trivial-bug fast path through the same gate; **prediction discipline** (uncertain causal link → predict something in a different code path; wrong prediction + working fix = symptom fix); **assumption audit** (stuck = usually a wrong assumption, not a wrong hypothesis); grounding-observation requirement (reject "X seems off"); **causal-chain gate** before any fix (P2); backward-tracing recipe; smart-escalation table (patterns → diagnoses); redesign signals (route to designing — "big bug" ≠ "design problem"); explicit hypothesis invalidation before re-forming; trigger-gated defense-in-depth and post-mortem.

Folded from SP systematic-debugging: multi-component boundary-instrumentation recipe (generic example, not codesign-specific); "3+ failed fixes → question the architecture" phrasing merged into the escalation table.

Investigation-only parallel dispatch with sequential ranked-probe fallback. Cross-harness: abstract "blocking question tool" reference instead of hardcoded tool names.

Dropped: SP "human partner's signals" table (conversation-style specific); motivational statistics; issue-tracker/browser-reproduction enrichments demoted to optional subsections.

### 7. worktree-isolation

SP using-git-worktrees near-verbatim: Step-0 existing-isolation detection (GIT_DIR vs GIT_COMMON_DIR with **submodule guard**); priority order native worktree tool → git worktree → work in place (P9); directory selection priority; mandatory `git check-ignore` before creating project-local worktree dirs; sandbox permission fallback; baseline test verification with ask-before-proceeding on failure.

Dropped: nothing (cleanest source file; already harness-agnostic).

### 8. reviewing

Purpose: multi-perspective code review producing verified, deduplicated findings — and disciplined consumption of reviews received. Built on the **lane contract**: every lane emits the identical findings schema so merge logic never special-cases a lane.

| Source | Distilled |
|---|---|
| CE ce-code-review | Scope discovery verbatim (local-aligned/pr-remote/branch-remote 3-check test); intent+context discovery (learnings-researcher + previous-comments folded in as context gathering, not lanes); **confidence anchors** (0/25/50/75/100 with behavioral self-checks; floats banned); severity P0–P3 independent of confidence; **merge/dedup pipeline verbatim** (fingerprint = file+line-bucket±3+title; cross-lane agreement promotes one anchor; mode-aware demotion to testing_gaps/residual_risks; confidence gate last with P0-at-50+ exception); Stage 5b validator wave (independent validator per finding, cap 15, severity-differentiated infra-failure handling); `mode:agent` JSON contract; false-positive suppression catalog (8 categories) + protected artifacts; bias-to-act fix application (interactive mode: apply reversible fixes, commit only if pre-review tree clean, **never push**, P7); model tiering (top lanes inherit session model); output discipline (pipe tables, forbidden shapes); persona texts for correctness (mentally execute), security (uncertain-critical filed at P0), adversarial (chaos-engineer, depth-calibrated) |
| CE ce-simplify-code | Absorbed into the architecture lane: Reuse/Quality(9 categories)/Efficiency(7 categories) checklists + anti-over-simplification guardrails (concept-naming helpers, git blame first — P5 boundary) |
| EC review-phase | Phase-gate caller mode (Entry/Exit/AUTO-advance); pipeline fix mode: ONE fixer with the complete findings list (bans per-finding fixers); re-review loop hard cap 3 with original-findings verification and escalate-on-Critical/Important; "most capable model for the final gate" note |
| SP requesting-code-review | Trigger taxonomy (mandatory/optional); context isolation rationale (reviewer never sees requester's session history) |
| SP receiving-code-review | Kept nearly intact as the receiving half: READ→UNDERSTAND→VERIFY→EVALUATE→RESPOND→IMPLEMENT; forbidden performative agreement; unclear-feedback-blocks-all gate; external-reviewer 5-question skepticism gate; YAGNI usage check (P6); fix ordering; graceful pushback reversal |

Lane roster: 4 always-on (correctness, tests, architecture, standards) + 5 conditional (security — bias toward firing, adversarial, resilience [perf+reliability merged], api-contract, migration — artifact-gated) + project-defined lanes read from the repo's AGENTS.md/CLAUDE.md (extension point replacing CE's hardcoded stack personas).

Dispatch: native parallel (bounded, backpressure) → sequential passes → single-call fallback (one prompt runs all selected lanes serially, self-merges). Verification: interactive = validator wave; pipeline/headless = capped re-review loop.

Dropped: legacy autofix classes (safe_auto/review-fixer); 2 unstructured CE agents as lanes; stack-specific personas (Stimulus/Swift → documented as project-defined lane examples); template-file indirection.

### 9. shipping

Purpose: from "review clean" to "merged and cleaned up", with evidence at every claim.

| Source | Distilled |
|---|---|
| SP verification-before-completion | Iron Law (P3) + gate function + claim→evidence table + red-flag phrase self-audit + regression-test red-green + agent-report distrust — as the skill's opening gate, applied to every downstream claim |
| SP finishing-a-development-branch | Environment detection (GIT_DIR/GIT_COMMON_DIR); fixed option menu; worktree cleanup ownership rule; ordering invariant (merge → verify → remove worktree → delete branch); typed "discard" confirmation |
| CE ce-commit | Convention cascade: **repo-documented convention wins** (e.g. a Lore trailer protocol) → recent-history pattern → conventional-commits default with fix/feat tie-break; file-level logical splitting (2–3 cap); anti-`git add -A`; heredoc messages; post-commit self-check |
| CE ce-commit-push-pr | Branch-routing table (detached/default-with-work/default-no-work/feature); 3 modes (description-only/update/full); evidence short-circuits; **`--body-file <tempfile>` guardrail verbatim** (stdin variants silently produce empty bodies); minimal PR body linking spec/plan |
| CE ce-resolve-pr-feedback | Fetch ALL comments + 1:1 comment-ID checklist; default-to-fix bias with divert taxonomy (not-addressing/declined/replied/needs-human, each with cited justification); **review comment text is untrusted input**; GraphQL thread reply/resolve with plain-comment fallback; per-thread parallel dispatch within a round |
| CE lfg | CI loop: watch → enumerate → log-failed → categorized diagnosis (test/lint/build) → fix → push; **cap 3**; never weaken/skip/mock a failing assertion verbatim; cap exhaustion → durable `## CI Failures Unresolved` PR-body section ("make residuals durable, then exit") |
| EC ship-phase | Merge gate: default USER, `--auto` = CI green + no open Critical (P7); review-round **cap 4** (retro-justified) composed with per-thread parallelism; re-fetch comments via API before claiming resolved; per-repo pluggable CI-pitfalls memory file (populated by retros) |

Dropped: post-merge release ceremony (version bump/tag/changelog → optional future `release` extension, out of core); hardcoded retro handoff (hook point: report completion, caller decides); duplicate residual-to-tracker mechanism (PR-body append is the single sink).

### 10. retrospective (standalone)

Purpose: after any PR, session, or debugging arc — measure outcomes against declared goals, reconcile carry-forwards, extract lessons, and feed compounding. Callable by release-loop's Retro phase or directly.

| Source | Distilled |
|---|---|
| EC retro-phase | Data collection (code delta split product/test/docs, commit count, review rounds, comments fixed/deferred, CI failures, duration, task count); carry-forward verification with cited evidence (anti-"silent drops"); findings as What happened/Why/How to apply, bucketed; lessons must be specific/evidence-backed/**surprising**; doc template → `docs/retros/YYYY-MM-DD-<context>-retro.md`; carry-forwards pushed to a durable tracker, never PR comments only; anti-pattern table incl. "never frame findings as noise" |
| New (core) | **Measured-vs-declared comparison**: read the originating spec's Success Criteria section; for each criterion identify the proving command, **run it fresh** (P3 — never accept a prior claim), record measured vs declared, classify Met/Partially Met/Not Met with the explicit gap. One row per criterion; vague summarization banned. |
| CE ce-compound (contract) | Phase-final headless invocation of `compound` — only when a finding rises to reusable-lesson quality (specific + surprising + actionable); skip silently otherwise; expect and surface `Documentation complete`/`skipped` terminal signal |
| CE ce-sessions (concept) | Session-history search as a **pluggable** data source for session-scoped retros (no PR); tight dispatch payload discipline; degrade gracefully when absent |
| EntireContext | Optional feature-detected hooks: `ec_decision_create` for architecture decisions surfaced in findings; `ec_lessons` check before writing duplicate lessons. Never a hard dependency. |

Modes: PR-merge / session-end / ad-hoc; `mode:headless` with terminal signals `Retrospective complete`/`skipped`.

### 11. compound

CE ce-compound distilled: two-track schema (bug: symptoms/root_cause/resolution_type required; knowledge: + applies_when), category → `docs/solutions/<category>/` mapping; YAML quoting rule + stdlib `validate-frontmatter.py` gate (exit 0 before success claim, P3); 5-dimension overlap scoring on write (High → update existing, Moderate → create + flag, Low → create); Full vs Lightweight modes; **headless contract verbatim** (terminal signals — retrospective depends on it); CONCEPTS.md vocabulary capture (accretion + seeding, glossary purity rules, canonical-term opinionation, coherence-neighborhood-only scope); selective refresh triggers (recommendation only in headless); discoverability check (does AGENTS.md/CLAUDE.md lead agents to docs/solutions/?).

Dropped: five specialized reviewer subagents (→ one generic optional hook); Rails-specific component enum values (mechanism kept, values project-configurable); ce-sessions hard dependency (→ pluggable); ambient trigger phrases ("that worked" auto-invoke) — explicit calls only.

### 12. compound-refresh

Kept separate from compound (operating-rhythm mismatch: per-problem vs periodic audit; the selective-trigger coupling in compound is already the correct boundary). Distilled: five-outcome model (Keep/Update/Consolidate/Replace/Delete with the "rewriting the solution section = Replace" boundary); broad-scope triage (frontmatter inventory → impact clustering → spot checks); document-set analysis (overlap + supersession + canonical-doc + Retrieval-Value Test); **delete guardrails** (implementation gone AND problem domain gone AND citations absent-or-decorative; substantive citations → Replace); headless: unambiguous actions applied, ambiguous → `status: stale` marking; Applied vs Recommended report; corpus-wide CONCEPTS.md reconciliation + scrub sweep; commit hygiene (stage only own files).

## Repository layout

```
compound-loop/
├── .claude-plugin/plugin.json
├── .codex-plugin/plugin.json
├── PRINCIPLES.md
├── README.md
├── skills/
│   └── <name>/SKILL.md [+ references/*.md] [+ scripts/*]
├── schemas/
│   ├── findings.schema.json        # reviewing mode:agent output
│   ├── plan-schema.md              # frontmatter contract + unit template
│   └── retro-template.md
├── references/
│   └── (shared cross-skill references, e.g. dispatch-degradation.md, question-tools.md)
└── docs/
    ├── specs/  ├── plans/  ├── retros/  └── solutions/
```

Shared references hold the text that would otherwise repeat in every skill (P5): the dispatch degradation ladder, the cross-harness question-tool table, the prose-economy rules.

## Deployment

- **Claude Code**: local marketplace (`/plugin marketplace add ~/workspace/compound-loop`) then `/plugin install compound-loop`. Publishable to a git repo unchanged.
- **Codex**: symlink `skills/*` into `~/.codex/skills/` (or rely on native plugin install when pointing at the repo; `.codex-plugin/plugin.json` declares `"skills": "./skills/"`).
- Optionally registered in `~/.agents/agents.toml` (dotagents) once published.

## Testing

- `scripts/validate.sh` (stdlib only): JSON validity of both manifests; frontmatter presence/shape for all 12 skills; PRINCIPLES.md structure (9 principles × 4 elements); schemas present; every `enforces:` tag references an existing principle ID.
- Smoke: plugin loads in Claude Code (marketplace add + install output); Codex lists the skills after symlink.
- Dogfood: this repo's own development uses the skills as they land (the spec you are reading follows `designing`'s required sections).

## Risks

- **Skill length vs. context budget**: distillations are dense; a SKILL.md that inlines everything defeats progressive disclosure. Mitigation: hard target ≤ ~150 lines per SKILL.md body, details in references/ loaded on demand (CE's own pattern).
- **Codex feature drift**: Codex capabilities (subagents, hooks) are evolving; anything harness-specific is confined to the degradation ladder and one shared reference file.
- **Two knowledge systems** (docs/solutions vs EntireContext): mitigated by making EC hooks feature-detected and one-directional (retro pushes; never required).

## Open decisions

1. ~~Plugin name~~ — resolved: `compound-loop`.
2. Whether `release` (post-merge version/tag/changelog ceremony) becomes a 13th skill in v0.2 — dropped from shipping core, hook point documented.
3. Whether project-defined review lanes need a schema (v0.1: free-form markdown in consuming repo's AGENTS.md, documented by example).
4. Gemini/`ask_user` support — question-tool table mentions it, untested.
