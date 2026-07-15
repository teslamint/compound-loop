# Design-phase distillation (from distill-design agent)

## Idea inventory

### 1. superpowers/brainstorming
- HARD-GATE: no implementation until design presented AND approved — every project regardless of size
- Named anti-pattern "This Is Too Simple To Need A Design"
- 9-step checklist, each item a task, in order
- Dot-graph process flow with explicit terminal state: ONLY skill invoked after = writing-plans
- Decomposition trigger: flag immediately if request spans multiple independent subsystems
- Design-for-isolation test: what does it do / how used / depends on; understand without internals; change internals without breaking consumers
- Existing-codebase rule: fold targeted improvements the design touches; no unrelated refactoring
- Spec self-review = 4 fixed checks (placeholder, consistency, scope, ambiguity), fix inline, no re-loop
- Scripted User Review Gate message
- Visual Companion: just-in-time offer, per-question test "better seen than read"; browser for visual, terminal for conceptual
- Spec path: docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md

### 2. ce-brainstorm
- Pipeline: ce-ideate (WHAT ideas) → ce-brainstorm (WHAT exactly) → ce-plan (HOW)
- YAGNI applied to carrying cost, not coding effort
- Interaction Rule 4: cross-harness blocking question tool table — AskUserQuestion (Claude Code) / request_user_input (Codex) / ask_user (Gemini, Pi); degrade to numbered chat options ONLY when no blocking tool or call errors
- Rules 5/6: precise test for when open-ended allowed (narrative / menu-would-bias / can't write 3-4 distinct options); open-ended must be concrete enough to bite into
- Output-format precedence chain: CLI token > non-commented config > default md; pipeline-mode forces md
- Phase 0.1b task-domain classification (software / non-software / neither) gates phases
- Phase 0.2 "requirements already clear" fast path — skip rigor probes, announce-mode synthesis
- **Phase 0.3 SCOPE TIERING**: Lightweight / Standard / Deep + Deep-feature vs Deep-product; product-tier adds rigor questions + doc sections
- Phase 1.1 tier-conditional context scan; Constraint Check (AGENTS.md/STRATEGY.md/CONCEPTS.md) + Topic Scan; "verify before claiming absence"
- **Phase 1.2 RIGOR-GAP PROBES** (unique): evidence gap / specificity gap / counterfactual gap / attachment gap (+durability gap for Deep-product); one gap = one open-ended probe; concrete diagnostic questions
- Phase 1.3 exit: all present gaps probed before Phase 2; integration check (user-X + user-Y + default-Z downstream consequences)
- Phase 2: non-obvious-angle requirement (inversion/constraint-removal/analogy); present all before recommending (anti-anchoring); optional higher-upside challenger; approach granularity = mechanism/product-shape, never implementation specifics
- **Phase 2.5 Synthesis gate Path A/B**: Path A (no blocking Qs AND Lightweight) = one-line announce, proceed; Path B = full scoping synthesis + unconditional confirmation
- Phase 3: doc only when durable decisions produced (stress test given)
- Prose economy rules: one idea/sentence; requirement = intent + ≤1 qualifier; forks → Outstanding Questions; resolve in place; test = "contradiction findable in one pass?"
- Success Criteria section is include-when-material, NOT hard floor (no source mandates always-required)
- Hard floor: Summary (1-3 lines) + Requirements with stable R-IDs grouped by concern
- Vocabulary capture → CONCEPTS.md, only if exists, only resolved terms, runs last

### 3. ce-ideate (mostly out of scope — upstream idea generation)
- Same cross-harness question-tool guidance
- Subject-Identification Gate: "would a reader know what subject to ideate on" — referent test
- Generate many → critique all → explain survivors only
- Six ideation frames w/ tagged basis + meeting_test floor; Topic-Surface Decomposition into 3-5 orthogonal axes
- Recommendation: reference as optional upstream, don't merge

### 4. release-loop design-phase.md
- Entry/Exit/Gate contract framing; cross-harness invocation ($ vs /)
- **Gate: "USER — spec approval is always human. Never auto-skip."** (plainest statement)
- Step 1 context scan as literal shell commands (git log -20, AGENTS.md, ROADMAP.md, previous retros for carry-forward)
- Decomposition signals: multiple subsystems / different owners / independently shippable
- Approach template: literal fill-in markdown (Approach A/B: How/Pro/Con + Recommendation)
- **Section-ordering principle: User Scenarios before Architecture** ("motivation before mechanism")
- Spec sections: User Scenarios (3-6 concrete) → Architecture → Interface → Data model → Integration → Testing → Risks
- **Step 6 independent review gate** (unique): reviewer subagent (most capable model) or advisor tool BEFORE user sees spec; scoped to consistency/edge-cases/scope-creep/feasibility; retro-cited ("caught 2 critical design flaws self-review missed; mandatory for schema/pipeline changes")
- Spec doc literal template incl. "Open Decisions" section
- Anti-Patterns as Don't/Do table
- **Spec Quality Signals**: good-vs-bad contrastive pairs (self-contained zero conversation context; names concrete files/tables/functions; no "see conversation above"; no vague "appropriate error handling") — lift near-verbatim

## Overlap map

| Concept | Strongest |
|---|---|
| One-question-at-a-time | ce-brainstorm (only precise open-ended test) |
| Cross-harness question tool | ce-brainstorm |
| 2-3 approaches | ce-brainstorm (granularity+anti-anchoring+challenger) + release-loop template |
| Scope tiering | ce-brainstorm by wide margin |
| Rigor-gap probes | ce-brainstorm only (unique) |
| Measurable success criteria | NO source mandates always-required — merged skill elevates beyond sources |
| Human approval gate | release-loop plainest |
| Independent review before user sees spec | release-loop only (unique) |
| Spec self-review | SP/release-loop 4-point + ce-brainstorm prose-economy as second layer |
| Spec quality bar | release-loop Spec Quality Signals |
| R-IDs | ce-brainstorm only |

## Recommended merged skeleton (design-phase skill)
1. Frontmatter: release-loop Entry/Exit/Gate + SP HARD-GATE + "Too Simple" anti-pattern verbatim
2. Explore context: release-loop shell commands + CONCEPTS.md + verify-before-claiming-absence
3. Scope assessment: decomposition check + ce-brainstorm tier classification (gates everything downstream)
4. Rigor-gap probes: ce-brainstorm Phase 1.2/1.3 near-verbatim, tier-scaled (skip Lightweight / 4 Standard / 5 Deep-product)
5. Dialogue: ce-brainstorm Interaction Rules 1-6 verbatim incl. cross-harness table
6. 2-3 approaches: ce-brainstorm discipline + release-loop template
7. Present design in sections: release-loop section list + ordering rule; SP complexity scaling; per-section approval
   - **Success Criteria promoted to REQUIRED section** (deliberate elevation beyond all sources)
8. Write spec doc: release-loop skeleton + Success Criteria + R-IDs when warranted + prose-economy bar
9. Independent review gate: release-loop Step 6 (reviewer subagent/advisor BEFORE user) — distinct from user gate
10. Spec self-review: 4-point + contradiction-in-one-pass test
11. Human approval gate: "USER — always human. Never auto-skip." + scripted wait
12. Handoff: SP terminal-state constraint (only planning skill next) + next-step menu
13. Appendix: Visual Companion optional; ce-ideate pointer as upstream

Dropped: ce-ideate engine (upstream); HTML output machinery; CONCEPTS.md capture (optional tail); Path A/B nuance (simplify: one-line synthesis always, full gate Standard+)
