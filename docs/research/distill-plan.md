# Plan-phase distillation (from distill-plan agent)

## Idea inventory

**1. SP writing-plans**
- Zero-context assumption: write for engineer with no codebase knowledge
- Scope Check: multi-subsystem specs split into separate plans; each plan independently testable
- File Structure phase before tasks (single-responsibility, colocate, follow existing scale)
- Task right-sizing: smallest unit with own test cycle, "worth a fresh reviewer's gate"
- Bite-sized literal steps (2-5min): failing test / run fail / implement minimal / run pass / commit
- Task template: Files (Create/Modify/Test) + Interfaces (Consumes/Produces exact signatures) — implementer sees only own task
- No-placeholders banned-phrase list; "similar to Task N" forbidden (out-of-order reads)
- Self-review checklist (author-run): spec coverage, placeholder scan, type consistency
- Handoff: 2-option menu (Subagent-Driven vs Inline) each with REQUIRED SUB-SKILL

**2. CE ce-plan (+references)**
- WHAT/HOW/execute split; "decisions, not code"
- Plan Quality Bar checklist (traceability, repo-relative paths, test paths, decisions+rationale, patterns, scenarios, dependencies)
- Resume/deepen fast-path via frontmatter status/deepened
- Approach-altitude: recognize "plan the approach, not the deliverable" requests, hold at checkpoint
- Domain classification gate (software/answer-seeking/universal)
- Requirements carry-forward with A-ID/F-ID/AE-ID preservation
- Outstanding-question triage: planning-owned vs product blocker — never plan over a live blocker
- Depth tiers (Lightweight/Standard/Deep) + unit-count guidance
- Scoping synthesis before research (Stated/Inferred/Out-of-scope buckets, confirm before spending budget)
- External-research decision tree (explicit > intent classification > implicit signals)
- Depth reclassification: Lightweight→Standard when touching external contract surfaces
- **U-ID stability rule**: never renumber on reorder/split/delete
- Unit fields incl. categorized test scenarios (happy/edge/error/integration) with AE-linking ("Covers AE3")
- **3.7 Anti-expansion**: tangential discoveries → "Deferred to Follow-Up Work"
- **3.6 Planning-time vs implementation-time unknowns**: deferred implementation notes (exact method names, final SQL, runtime behavior)
- plan-sections.md: skip-the-plan-doc-entirely criteria + false-atomic stress tests ("add caching" hides KTDs)
- plan-sections.md: hard-floor vs include-when-material catalog; prose economy + contradiction test; metadata contract (title/type/status/date required); resolve-in-place
- **5.3 Confidence Check/Deepening**: risk-weighted section scoring → top 2-5 candidates → section-to-specialist mapping; auto vs interactive modes
- Deepening allowed/forbidden list (tighten prose OK; impl code NOT; never renumber U-IDs)
- **Parallel→sequential degradation explicit**: "if platform doesn't support parallel dispatch, run sequentially"
- Handoff 5-option menu with must-fire completion check

**3. CE ce-doc-review**
- Parallel persona review engine over whole doc (different from ce-plan's section-scored deepening — complementary)
- 2 always-on (coherence, feasibility) + 5 conditional personas w/ content-signal activation checklists + "do NOT activate" counter-examples
- Doc-type classification by content shape, path as tie-breaker
- Bounded-parallelism: queue beyond cap; capacity errors = backpressure
- **Decision primer**: cross-round memory of applied/rejected findings; evidence-snippet >50% overlap test suppresses re-surfacing rejected findings
- 3-tier finding routing: safe_auto / gated_auto / manual + FYI
- Headless mode: structured text instead of blocking walkthrough
- Tool-preload discipline (load question-tool schema once up front)

**4. EC plan-phase.md**
- Deliverable Type Detection (code vs non-code) in progress.md → task-template choice
- Gate: AUTO (plan auto-commits after self-review — different governance than ce-plan)
- Dual task templates: Code (TDD, = superpowers) vs **Non-Code** (Write → Self-review-against-spec → Commit) — only source
- Task-count smell test: 3-7 typical, >10 under-decomposed, <3 too coarse
- Anti-scope-creep instance: version bump/CHANGELOG = Ship-phase, never plan task
- Self-review adds **callers+invariants check** + prior-retro carryover (retro-cited)
- Step 8 Independent Review: reviewer subagent or advisor (cited catch: parsing bug + schema gap pre-implementation)
- Progress-file handoff (.release-loop/progress.md plan path)

## Overlap map (strongest)
- File structure / task template / no-placeholder: SP origin (EC copies)
- Task right-sizing: SP "worth a fresh reviewer's gate"
- Self-review: EC (callers/invariants + retro carryover) + SP type-consistency
- Independent plan review: ce-plan only real dispatch mechanism
- ce-doc-review vs ce-plan deepening: NOT same idea — complementary
- Sequential degradation: ce-plan explicit one-liner (portable baseline); ce-doc-review backpressure as refinement
- 3.6 unknowns separation / 3.7 anti-expansion / U-IDs / skip-criteria / metadata contract: ce-plan only — keep
- File naming: ce-plan collision-safe NNN + type
- Handoff: SP menu shape + EC progress-file pointer for headless
- Deliverable type: EC dual templates + ce-plan frontmatter recording

## Recommended merged skeleton
1. Entry check — plan warranted? (ce-plan skip-criteria + false-atomic stress tests, near-verbatim)
2. Cheap scope confirmation (compressed 0.7/5.1.5: stated scope + material forks, one confirmation; auto-proceed trivial; drop paragraph-budget machinery)
3. File Structure (SP rules)
4. Deliverable-type gate: detect once, record in frontmatter (not side-channel), selects template
5. Decomposition: SP "fresh reviewer's gate" + ce-plan U-ID stability + EC 3-7 count heuristic
6. Task templates: SP literal template (code) / EC Write→Self-review→Commit (non-code); inject ce-plan test-scenario taxonomy + AE-links into test step
7. 3.6 planning vs implementation unknowns, verbatim
8. 3.7 anti-expansion + EC version-bump worked example
9. No-placeholder list, verbatim
10. Plan header: SP human-readable header + ce-plan machine frontmatter in same file
11. Self-review: EC base (callers/invariants + retro carryover) + SP type-consistency
12. **Confidence check + deepening**: ce-plan risk-scoring compressed to ~5 trigger categories (vague rationale, missing risk treatment, weak sequencing, thin external grounding, unclear verification); skip if nothing scores; personas = Architecture/Feasibility + conditional Security/Risk + Scope/Coherence using ce-doc-review activation-signal pattern; dispatch parallel → **sequential fallback if no parallel primitive**; backpressure note; auto vs interactive modes; ce-doc-review evidence-overlap suppression as optional refinement; change discipline verbatim
13. Prose economy cross-cutting
14. Naming: ce-plan docs/plans/YYYY-MM-DD-NNN-<type>-<name>-plan.md primary
15. Commit plan
16. Handoff: SP 2-option menu + EC progress-file write for headless/pipeline

Dropped: OUTPUT_FORMAT html machinery, Proof HITL, issue creation, CONCEPTS.md gap-fill, full approach-altitude state machine (one-line pointer only)
