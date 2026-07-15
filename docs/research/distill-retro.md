# Retro/Compound distillation (from distill-retro agent)

## Idea inventory

### 1. retro-phase.md (release-loop)
- Step 1 Collect Release Data: code delta split (product/test/docs by path), commit count, review rounds, comments fixed/deferred, CI failures, duration (spec commit → merge), task count
- Step 2 Carry-Forward check: read previous retro, verify each item ✅/⏳/❌ with cited evidence; anti-pattern "silent drops"
- Step 3 Findings: What happened / Why / How to apply, bucketed Worked Well / To Improve / Process Observations; must cite specifics; never frame findings as "noise"
- Step 4 Register carry-forward: type (arch/perf/feature/edge-case/process) × priority (P1-P4); deferred items → ROADMAP/tracker, not PR comments
- Step 5 Lessons: quotable one-liners — specific/evidence-backed/actionable/**surprising**
- Step 6 doc template → docs/retros/YYYY-MM-DD-<feature>-retro.md
- Step 7 commit + progress.md → done
- Anti-pattern table baked in

### 2. ce-compound
- Modes: Interactive (Full vs Lightweight) vs **Headless** (`mode:headless` — no blocking questions, Full-without-session-history, terminal signal strings `Documentation complete`/`Documentation skipped`) — model for skill-to-skill invocation
- Phase 0.5 Auto Memory Scan with origin tagging `(auto memory [claude])`
- Phase 1 parallel subagents return TEXT ONLY (never write files; orchestrator writes the one deliverable): Context Analyzer (track+category via schema), Solution Extractor, Related Docs Finder (grep-first + **5-dimension overlap scoring** → High/Moderate/Low)
- Two-track schema: bug track (symptoms, root_cause enum, resolution_type enum required) vs knowledge track (optional + applies_when); shared: module, date, problem_type enum, component enum, severity enum; categories map to docs/solutions/<category>/ (9 bug + 8 knowledge)
- YAML safety: quote reserved-indicator strings; validate-frontmatter.py (stdlib) must exit 0
- Overlap→action: High → update existing (+last_updated); Moderate → create + flag for consolidation; Low → create ("two docs describing same problem will drift apart")
- **Phase 2.4 CONCEPTS.md vocabulary capture**: accretion (friction-surfaced terms) vs seeding (stable-central core nouns); bar = "new engineer would need it defined"; glossary purity (no impl specifics/status/config numbers/links); be opinionated (canonical term + *Avoid: X* aliases + flagged-ambiguities audit trail); scoped runs seed own area only; **coherence neighborhood refresh** (bounded, not full audit)
- Phase 2.5 Selective Refresh Check: refresh NOT default follow-up; trigger conditions (contradicts/supersedes/refactor invalidated refs/moderate-overlap); headless → recommendation line only
- Discoverability Check: semantic assessment whether AGENTS.md/CLAUDE.md leads agents to docs/solutions/ + CONCEPTS.md; minimal informational edit
- Lightweight mode: single-pass, no subagents, no overlap detection, update-only vocab
- Auto-invoke trigger phrases ("that worked", "it's fixed")

### 3. ce-compound-refresh
- Five-outcome model: Keep / Update / Consolidate / Replace / Delete; boundary: "rewriting solution section = Replace, not Update"
- Broad-scope triage (9+ docs): frontmatter inventory → impact clustering → spot-check file existence → recommend starting cluster
- Phase 1.75 document-set analysis: 5-dim overlap + supersession signals + canonical-doc per cluster + **Retrieval-Value Test** ("separate docs improve discoverability or just drift risk?")
- **Delete guardrails**: ALL THREE — implementation gone, problem domain gone, inbound citations absent-or-decorative; citations classified decorative/substantive/mixed (substantive → Replace; unclear → stale-mark)
- Headless: apply unambiguous; ambiguous → status: stale + stale_reason + stale_date; report **Applied vs Recommended** split
- Phase 4.5 vocab refresh: full-corpus reconciliation (union shades, not most-recent-wins), backfill core nouns, full scrub sweep (contrast: compound = neighborhood only; refresh = audit)
- Phase 5 commit: branch/PR-vs-direct logic; stage only own files

### 4. ce-sessions
- Cross-platform (Claude Code/Codex/Cursor) session search; skill-to-skill sync call pattern (backgrounded parallel then sync — wall-clock = max not sum)
- Tight dispatch payload discipline (one-sentence topic + time window + filter + schema; verbose payloads compound wall time)
- Script-mediated pipeline (never read 1-7MB session files into context); deep-dive cap 5 sessions; scratch-dir skeleton extraction; synthesis-only subagent
- Guardrails: no tool I/O verbatim, no thinking blocks, never current session, technical not personal
- Fail-fast on access errors; "fast confident negative is a valid complete answer"

### 5. verification-before-completion (narrow transfer)
- Gate Function for retro claims: retro's success-criteria comparison must RUN the actual measurement fresh, not accept self-report

## Overlap map
| Concept | Strongest |
|---|---|
| Overlap scoring | ce-compound-refresh (adds Retrieval-Value Test + canonical-doc) ; ce-compound = entry point |
| Carry-forward | retro-phase.md (typed, prioritized, evidence-verified); refresh's Applied/Recommended = report shape to borrow |
| Evidence-before-claim | verification-before-completion general; others are domain instances |
| Headless contract | ce-compound (terminal signals) + ce-compound-refresh (Applied/Recommended) |
| CONCEPTS.md capture | both, deliberately split scopes (creation-neighborhood vs corpus-audit) — keep split |
| Session mining | ce-sessions (gap-fill for retro) |
| Metrics collection | retro-phase.md only |

## Recommended skeletons

### (a) `retrospective` — standalone
- Phase 1 Scope & Mode: detect PR-merge / session-end / ad-hoc; mode:headless w/ terminal signals (`Retrospective complete`/`skipped`)
- Phase 2 Collect Data: git/PR metrics when available; session-history search as pluggable capability (skip gracefully); **read declared measurable success criteria from originating design/plan artifact** (new — retro-phase only checks previous carry-forward, never current work vs declared goals)
- Phase 3 **Measured vs Declared comparison** (new core): per criterion — identify proving command, RUN FRESH, record measured vs target, Met/Partially/Not Met with explicit gap; structural not stylistic
- Phase 4 Carry-forward reconciliation (retro-phase Steps 2&4 unchanged; durable tracker push)
- Phase 5 Findings & Lessons (retro-phase Steps 3&5 unchanged)
- Phase 6 Write doc: docs/retros/YYYY-MM-DD-<context-name>-retro.md
- Phase 7 **Headless invocation of compound**: only if a finding rises to reusable-lesson quality (specific+surprising+actionable); skip silently otherwise; expect/surface compound's terminal signal
- Phase 8 Commit & report (separate commits per deliverable)
- Optional pluggable: ec_decision_create (decision records), ec_lessons (check prior lessons) — feature-detected, degrade silently

### (b) `compound` — distilled ce-compound
Keep: two-track schema, category→dir mapping, YAML validation gate, overlap scoring on write, Full/Lightweight split, headless contract verbatim, CONCEPTS.md accretion+seeding neighborhood-scoped, Discoverability Check
Keep **compound-refresh as SEPARATE skill** (operating-rhythm mismatch; Phase 2.5 selective-trigger coupling already correct)
Drop: 5 specialized reviewer subagents (→ generic optional hook); Rails-specific component enum values (→ project-configurable); ce-sessions hard dependency (→ pluggable prior-context search); ambient trigger phrases (→ explicit calls)
