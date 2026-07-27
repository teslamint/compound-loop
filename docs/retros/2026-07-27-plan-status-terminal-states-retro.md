# Retro: plan-status-terminal-states

- Date: 2026-07-27
- Source: PR #2 — squash merged as `146e128` (base `4cb3fdb`)
- Spec: docs/specs/2026-07-27-plan-status-terminal-states-design.md
- Plan: docs/plans/2026-07-27-001-feat-plan-status-terminal-states-plan.md

## Release data

| Metric | Value |
|---|---|
| **Changed non-test lines** | 308 (308 added + 13 removed; across schemas/plan-schema.md, skills/planning/scripts/validate-plan-frontmatter.py, scripts/validate.sh, scripts/test-python-compatibility.sh, 3 SKILL files, ROADMAP.md, CONCEPTS.md). Total branch insertions 1656 — the remainder are the spec and plan documents + test harness |
| Commits | 17 branch (squashed to 1 merge `146e128`) |
| Review rounds | 9 (1 spec review, 1 plan review with 2 P1 + 11 P2 + 8 minor findings, 7 unit reviews, 1 branch review, 1 CodeRabbit review) |
| Comments (fixed / deferred) | 6 / 0 — 3 MEDIUM from U2 review fixed at `3c003fd`, 3 from CodeRabbit fixed at `c19251b` |
| CI failures | 0 (no CI workflows configured; CodeRabbit and GitGuardian pass) |
| Duration (first spec commit → merge) | ~2 hours (2026-07-26T22:55Z spec draft → 2026-07-27T01:03Z merge) |
| Units planned / completed | 7 / 7 + 1 fix round (U2 review) + 1 branch-review fix + 1 CodeRabbit fix |

## Success criteria: measured vs declared

One row per criterion from the spec's Success Criteria section. The measurement is run FRESH
during the retro (enforces: P3) — a prior claim in a commit message or PR body is not evidence.

| # | Declared criterion | Measurement (command / rubric) | Measured result | Verdict |
|---|---|---|---|---|
| 1 | The `status` enum is exactly `draft \| approved \| done \| superseded`; `in-progress` and `abandoned` appear only in rejection records | `grep -c 'status: draft \| approved \| done \| superseded' schemas/plan-schema.md` → 1; `grep -c 'in-progress'` → 1; `grep -c 'abandoned'` → 1 | verified: 1/1/1 — each rejected value appears exactly once in its rejection record | Met |
| 2 | Validator rejects every invalid fixture, accepts every valid one | `bash scripts/test-plan-frontmatter.sh` — every invalid exits nonzero naming the field, every valid exits 0 | verified: 27/27 ALL CASES PASSED | Met |
| 3 | Full existing plan corpus passes unmodified | `for f in docs/plans/*.md; do python3 .../validate-plan-frontmatter.py "$f" \|\| exit 1; done` | verified: 15/15 OK, exit 0; zero plan files in the diff | Met |
| 4 | Validator compiled against both boundary interpreters | `bash scripts/validate.sh` output contains `label=plan-frontmatter-validator status=pass` for oldest (3.9.25) and newest (3.14.6) | verified: both lines present | Met |
| 5 | `implementing` refuses terminal plan naming evidence field | Judgment rubric: reviewer reads Pre-flight item 2 | verified: `done` → detectable error naming `completed_by:`; `superseded` → refusal naming `superseded_by:`; malformed-done branch handles missing `completed_by:`; neither degrades to execution | Met |
| 6 | `retrospective` writes flip atomically, conditional on plan existing | Judgment rubric: reviewer confirms same-commit write, no-plan case, multi-plan case | verified: Phase 8 prescribes `status: done` + `completed_by:` in same commit as retro doc; no-plan = no flip; multi-plan = flip all qualifying with individual `completed_by:` | Met |
| 7 | Nothing that passed before fails after | `bash scripts/validate.sh` exits 0 | verified: ALL CHECKS PASSED | Met |

## Carry-forward from previous retro

Previous retro: `docs/retros/2026-07-26-frontmatter-validator-python38-retro.md`. This branch touched schemas/plan-schema.md, skills/planning/SKILL.md, skills/retrospective/SKILL.md, skills/implementing/SKILL.md, scripts/validate.sh, scripts/test-python-compatibility.sh, ROADMAP.md, CONCEPTS.md (8 files + spec/plan/harness).

| Item | Status | Evidence |
|---|---|---|
| Reword plan-schema audit-section provenance | Done — edit-based, fired this cycle | `f33ba6b` U1 step 7 changed "approved with this plan" → explicit plan path; ROADMAP row annotated done at `6807b7a` (T1) |
| Fix stale "item 1's deviation-addendum rule" refs | Done — edit-based, fired this cycle | `f33ba6b` U1 step 7 (plan-schema); `acd0fe3` U4 step 3 (planning SKILL); ROADMAP row annotated done at `6807b7a` (T1) |
| Retro-side trigger classification rule | Not started — this cycle's retrospective scope was the done flip only; designing rule still unbuilt | ROADMAP row unchanged |
| Release headless-path non-authorization marker | Not started — event-based, did not fire | No release-skill edit this cycle |
| `final_action` record polish (N-1 marker/note, N-2 Log clause) | Not started — `progress-schema.md` untouched | Schema file unchanged |
| Define "hand-up packet" in shipping SKILL | Not started — edit-based, did not fire | `skills/shipping/SKILL.md` untouched |
| Mechanical validate.sh check for `final_action` shape | Not started — drift-based; this cycle added a corpus check to validate.sh but scoped to plan-frontmatter only | ROADMAP row unchanged |
| Carry-forward structural T-ID assertion | Not started — edit-based, did not fire | `schemas/retro-template.md` untouched |
| Plan internal clause-consistency check | In progress — fired again (plan review returned 6 contradictions at `bc35e9e`); satisfied procedurally; mechanical check still absent | ROADMAP row unchanged |
| Vocabulary polish batch | Not started — edit-based, did not fire | Neither `skills/reviewing/SKILL.md` nor `skills/shipping/references/verification.md` touched |
| Spec-level carve-out rule | Not started — edit-based, did not fire | `skills/designing/SKILL.md` untouched |
| Pin Python support contract in compatibility consumers | Not started — edit-based; U3 added a registry data line but touched no delegation boundary | ROADMAP row unchanged |
| Two pre-existing red suites (P2) | In progress — U5 confirmed Case D target still at line 94 after edit; U7 recorded repair value 94 in ROADMAP; suites still red, still unowned | `c992881` U5 step 2 assertion; `6807b7a` U7 step 4 |
| Ambient bootstrap interpreter (P4) | Not started — this cycle's U3 added a registry line, not a heredoc; trigger did not fire | ROADMAP row unchanged |
| `final_action` marker/note slot (fold into N-1) | Not started — `progress-schema.md` untouched | ROADMAP row unchanged |
| Command-closure check for plan steps | Not started — event-based; this cycle's plan did not exhibit the defect | ROADMAP row unchanged |

- Previous doc shape: conformant

## Interview Transcript

- Independence level: self-checklist
- Rounds used: 0 (self-checklist mode — single-agent session, no facilitator dispatch available at this context depth)

| ID | Round | Phase | Probe | Answer | Evidence | Verdict (verbatim) |
|---|---|---|---|---|---|---|
| T1 | — | 4 | Are the two fired carry-forward rows (provenance reword, stale item refs) actually resolved by the commits claimed? | Yes — U1 step 7 changed both sites in plan-schema; U4 step 3 changed the planning SKILL site; ROADMAP annotated both done | `git show f33ba6b -- schemas/plan-schema.md`; `git show acd0fe3 -- skills/planning/SKILL.md`; `git show 6807b7a -- ROADMAP.md` | self-attested |
| T2 | — | 3 | Were all 7 SC measurements run fresh during this retro, not copied from prior claims? | Yes — grep outputs 1/1/1, harness 27/27, corpus 15/15, compat oldest+newest pass, validate.sh ALL CHECKS PASSED | Phase 3 command outputs above | self-attested |
| T3 | — | 5 | Did the U2 review's 3 MEDIUM findings get addressed before U3 landed? | Yes — fix round at `3c003fd` added list-crash type guard, origin fixture (case 27), and colon-safety fixture (case 26); 27/27 pass post-fix | `3c003fd`; `.release-loop/reports/U2-fix-report.md` | self-attested |
| T4 | — | 5 | The branch review found `Plan:` vs `plan:` casing mismatch — is this a regression? | No — pre-existing at `d75210e` (2026-07-16). U5's new reader uses the canonical lowercase `plan:` matching `progress-schema.md:19`. The defect is in the pre-existing writer (`skills/planning/SKILL.md:176`) | `git log --oneline d75210e`; `progress-schema.md:19` | self-attested |

Verdict cell values: `accepted` | `no evidenced answer (3 rejections): <verbatim>` | `self-attested`

## Findings

### What worked well

- **What happened**: Serial subagent execution with fresh context per unit produced 7 clean implementations in ~45 minutes wall-clock. Every subagent returned DONE or DONE_WITH_CONCERNS (Secretive signing), zero BLOCKED/NEEDS_CONTEXT. The brief-per-unit pattern — complete requirements doc written before dispatch, report path specified — kept each agent focused and eliminated cross-unit contamination.
  **Why**: Fresh context means no accumulated assumptions from prior units; the brief is the single source of truth for the agent, not a conversation that grew for hours.
  **How to apply**: For 3+ unit plans, write a self-contained brief per unit before dispatching. Include the exact commit protocol, acceptance checks, and report path. A subagent that reads only its brief cannot contradict a prior unit's assumptions.
  **Cites**: T3; all 7 unit reports under `.release-loop/reports/`.

- **What happened**: The U2 review (mutation-testing approach) caught three gaps — untested `: ` parser-safety, missing resolving-origin fixture, list-valued scalar crash — that would have surfaced as U3 corpus-check failures or worse. Fixing before U3 prevented a cascade.
  **Why**: The reviewer mutated the validator (replaced checks with no-ops) and confirmed the harness stayed green — proving the check was unenforced, not just untested. This is stronger than coverage counting.
  **How to apply**: For validators, mutation-test the harness: delete each check and confirm the suite catches it. A fixture that coincidentally passes is worse than no fixture.
  **Cites**: T3; U2 review findings 1-3.

### What to improve

- **What happened**: Secretive SSH signing blocked the U1 subagent's commit — "agent refused operation" — requiring a manual handoff to the user. The same failure did NOT recur for U2-U7, suggesting the auth window had lapsed between the planning phase and the first implementation commit.
  **Why**: The Secretive require-auth key needs user presence per signature. A long gap between interactive use and the first subagent commit lets the auth window close.
  **How to apply**: Before dispatching the first implementation subagent, trigger a trivial signing operation (e.g., `git commit --allow-empty -m test && git reset HEAD~1`) to warm the Secretive auth window. This is a session-setup step, not a per-unit step.
  **Cites**: U1 report DONE_WITH_CONCERNS; U2-U7 reports all DONE without signing issues.

- **What happened**: The plan downgraded U4-U6 from parallel to serial because of Secretive signing serialization. In practice, U4-U7 all committed on first try without signing refusal — the auth window stayed open after U2's successful commit. The serial constraint added ~15 minutes of unnecessary wall-clock wait.
  **Why**: The planning-time risk assessment was correct (signing CAN race), but the mitigation (full serialization) was overweight. A try-parallel-fallback-serial strategy would have been faster with the same safety.
  **How to apply**: For file-disjoint units with signing, try parallel dispatch with a signing-retry protocol instead of preemptive serialization. If the first parallel batch's commits all succeed, the auth window is warm and the risk is retired.

### Process observations

- **What happened**: The `Plan:` vs `plan:` casing bug in `skills/planning/SKILL.md:176` is pre-existing (`d75210e`, 2026-07-16) but was surfaced only by U5's review because the new done-flip rule at `skills/retrospective/SKILL.md:102` is the first code that reads the `plan:` field case-sensitively. This is a latent defect activated by this cycle's work.
  **Why**: The field was written but never read by case-sensitive code until now.
  **How to apply**: When a cycle adds a new reader for an existing field, verify the writer's casing against the canonical schema, not against what "looks right."
  **Cites**: T4; U5 review finding 3; `progress-schema.md:19`.

## Carry-forward items registered

| Item | Type | Priority | Tracked at |
|---|---|---|---|
| Fix `Plan:` → `plan:` casing at `skills/planning/SKILL.md:176` to match `progress-schema.md:19` — latent defect activated by the done-flip reader | edge-case | P3 | ROADMAP.md "Carry-forward from retros" |

## Compounding

Not attempted — no reusable lesson this cycle. The brief-per-unit pattern and mutation-testing approach are worth documenting, but both are already captured in the findings above and neither is surprising enough to warrant a standalone `docs/solutions/` entry; the mutation-testing technique is standard QA practice, not a project-specific discovery.

## Done flip

This cycle's plan (`docs/plans/2026-07-27-001-feat-plan-status-terminal-states-plan.md`) was first committed at `43f5d81`, which predates the terminal-state contract commit `f33ba6b` (`146e128` on main). Per the applicability boundary in `schemas/plan-schema.md` — "terminal-state rules apply to plans first committed after this contract lands" — this plan is not eligible for a done flip. No flip performed.
