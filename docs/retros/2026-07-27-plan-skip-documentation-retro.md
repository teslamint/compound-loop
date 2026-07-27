# Retro: plan-skip-documentation

- Date: 2026-07-27
- Source: direct push to main — `da1fdf9`, `20d59c1` (no PR)
- Spec: none (lightweight fast path — inline design approved, no spec doc)
- Plan: none (skipped — all four conditions held per step 1)

## Release data

| Metric | Value |
|---|---|
| **Changed non-test lines** | 4 (4 changed across 3 files: planning SKILL, release-loop SKILL, ROADMAP) |
| Commits | 2 |
| Review rounds | 1 (self-review + 2 advisor rounds) |
| Comments (fixed / deferred) | 0 / 0 |
| CI failures | 0 |
| Duration (design → push) | ~30 min |
| Units planned / completed | 0 / 0 (no plan; atomic change) |

## Success criteria: measured vs declared

No spec exists for this cycle (lightweight fast path with inline design). Success criteria were stated in the design conversation, not in a committed spec. Measured against the inline design's four criteria:

| # | Declared criterion | Measurement | Measured result | Verdict |
|---|---|---|---|---|
| 1 | step 1 has attestation + release-loop record procedure | `grep -c "attest" skills/planning/SKILL.md` | verified: 1 hit at line 26 — attestation and progress.md Log procedure both present | Met |
| 2 | Exit "documented" resolved to step 1 procedures | Read step 1 line 26 and Exit line 13 | verified: Exit says "documented skip per step 1"; step 1 now specifies attestation (session), Log entry (pipeline) | Met |
| 3 | `Plan:` → `plan:` casing fixed | `grep "plan:" skills/planning/SKILL.md \| grep -c "progress.md"` | verified: line 176 reads `plan:` (lowercase) matching progress-schema.md:19 | Met |
| 4 | release-loop Plan gate aligned | `grep "skip recorded" skills/release-loop/SKILL.md` | verified: 1 hit — "AUTO (plan committed, or skip recorded in progress.md)" | Met |

## Carry-forward from previous retro

Previous retro: `docs/retros/2026-07-27-plan-status-terminal-states-retro.md`.

| Item | Status | Evidence |
|---|---|---|
| Fix `Plan:` → `plan:` casing at `skills/planning/SKILL.md:176` | Done | `da1fdf9` — casing corrected; ROADMAP row closed at `20d59c1` |

- Previous doc shape: conformant

## Interview Transcript

- Independence level: self-checklist
- Rounds used: 0 (headless mode — self-checklist; advisor served as pre-commit reviewer during implementation, not as retro facilitator)

| ID | Round | Phase | Probe | Answer | Evidence | Verdict (verbatim) |
|---|---|---|---|---|---|---|
| T1 | — | 4 | Is the P3 carry-forward row (Plan:/plan: casing) resolved by the commit claimed? | Yes — `da1fdf9` changed `Plan:` to `plan:` at step 18; ROADMAP annotated done at `20d59c1` | `git show da1fdf9 -- skills/planning/SKILL.md`; `git show 20d59c1 -- ROADMAP.md` | self-attested |
| T2 | — | 3 | Were SC measurements run fresh? | Yes — grep commands run during this retro session | Phase 3 outputs above | self-attested |

## Findings

### What worked well

- **What happened**: The advisor caught three blocking issues (recursive under-specification, cross-skill mandate, resume regression) that would have shipped a fix containing the same class of bug it was fixing. Two rounds of advisor feedback before commit prevented all three.
  **Why**: The fix was deceptively simple — a one-sentence edit — but its consequences crossed three skill boundaries (planning, implementing, release-loop) and one schema (progress-schema). The advisor's cross-file analysis found interactions the author missed.
  **How to apply**: For fixes that touch workflow routing (skip, handoff, gate conditions), call advisor before commit even when the diff looks trivial. The routing graph is wider than any single file.
  **Cites**: T2; advisor findings 1-3.

### What to improve

- **What happened**: The initial design proposed a commit-message mandate in planning/SKILL.md for an action implementing/SKILL.md would perform — a cross-skill mandate with no counterpart in the consuming skill. The repo already has a named solution for this pattern (`mandated-field-absent-from-schema.md`), but it wasn't checked before proposing.
  **Why**: The author treated "documented" as a property of planning's output rather than checking which skill's entry point would actually execute the documentation.
  **How to apply**: Before mandating behavior across a skill boundary, verify the consuming skill's entry path reads the mandate. If it doesn't, the mandate is dead prose.
  **Cites**: T1; advisor finding 2.

### Process observations

- **What happened**: This was the first cycle to exercise the planning step 1 skip in practice under release-loop. The skip itself triggered P3 carry-forward row `Plan:` → `plan:` casing, which was folded. The cycle demonstrated the skip documentation mechanism it was adding — a self-referential test.
  **Why**: The work was genuinely atomic and the four conditions held, validating the skip criteria.
  **How to apply**: When a fix changes a procedure, exercise the procedure in the same cycle if feasible — it catches integration issues the text alone won't reveal.
  **Cites**: T1; progress.md Log line `plan: skipped`.

## Carry-forward items registered

| Item | Type | Priority | Tracked at |
|---|---|---|---|
| (none this cycle) | — | — | — |

## Lessons

- When fixing under-specification in a workflow skip path, check whether the fix itself crosses a skill boundary — a mandate written in skill A for an action skill B performs is the same class of bug as the gap being fixed.

## Compounding

- compound invocation: not attempted — no reusable lesson this cycle. The advisor-as-pre-commit-reviewer pattern is already established practice, and the cross-skill mandate observation, while valid, is a restatement of the existing `mandated-field-absent-from-schema.md` lesson rather than a new discovery.
