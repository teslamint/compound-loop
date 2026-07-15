---
schema: plan/v1
title: Author the 12 compound-loop skills and verify both harnesses load them
type: feat
status: approved
date: 2026-07-15
execution: non-code
origin: docs/specs/2026-07-15-compound-loop-design.md
---

# Implementation Plan: compound-loop v0.1 skills

## Goal

Author 12 SKILL.md files (plus per-skill references) that realize the approved spec, then verify the structural success criteria and load the plugin in Claude Code and Codex.

## Architecture notes

- Already in place (committed): manifests, PRINCIPLES.md, schemas/ (lane-findings, review-envelope, plan-schema, retro-template, headless-contract), shared references (dispatch-degradation, question-tools), scripts/validate.sh.
- Authoring source of truth per unit: the distillation inventories produced during design (session scratchpad `distill-{design,plan,implement,review,ship,retro}.md`) + the spec's per-skill tables. Where an inventory says "verbatim", port from the original source file, normalizing only names/paths.
- Style constraints for every SKILL.md: frontmatter `name` (= directory) + `description` only; body ≤ ~150 lines with detail pushed to `references/`; checks carry `enforces: P<n>` tags; parallel sections reference `references/dispatch-degradation.md`; blocking questions reference `references/question-tools.md`; document both invocation spellings (`/name`, `$name`).
- Units are authored by parallel subagents writing disjoint directories; subagents never run git commands — the orchestrator reviews and commits per unit group.

## Implementation Units

## U1: designing skill
Files:
  Create: skills/designing/SKILL.md, skills/designing/references/*.md (rigor-gap probes, spec template + quality signals)
Steps:
  1. Write per spec §designing table + distill-design inventory (tiering, probes, dialogue rules, required Success Criteria section, independent review gate, human gate)
  2. Self-review against spec §designing: every table row present or explicitly dropped
  3. Commit
Acceptance: scripts/validate.sh frontmatter pass; grep confirms Success Criteria required section, both gates, tier names, `enforces:` tags

## U2: planning skill
Files:
  Create: skills/planning/SKILL.md, skills/planning/references/*.md (deepening workflow, unit templates pointer to schemas/plan-schema.md)
Steps:
  1. Write per spec §planning table + distill-plan inventory (skip-criteria, U-ID rules via schema link, 3.6/3.7, deepening pass with 5 triggers + degradation, dual templates)
  2. Self-review against spec §planning
  3. Commit
Acceptance: validate.sh pass; SKILL.md references schemas/plan-schema.md rather than restating it (enforces: P5)

## U3: implementing + tdd + worktree-isolation skills
Files:
  Create: skills/implementing/SKILL.md (+references: execution-strategy.md, merge-protocols.md), skills/tdd/SKILL.md, skills/worktree-isolation/SKILL.md
Steps:
  1. Write per spec tables + distill-implement inventory (file handoffs, status protocol, parallel safety check, dual degradation protocols, test checks, 3-round cap, ledger; tdd near-verbatim + execution-note hook; worktree near-verbatim)
  2. Self-review against spec §implementing/§tdd/§worktree-isolation
  3. Commit
Acceptance: validate.sh pass for all three; implementing references dispatch-degradation.md and plan-schema.md

## U4: debugging skill
Files:
  Create: skills/debugging/SKILL.md, skills/debugging/references/techniques.md (boundary instrumentation, backward tracing)
Steps:
  1. Write per spec §debugging + distill-implement inventory ce-debug section (5 phases, prediction discipline, assumption audit, causal-chain gate, escalation table, redesign signals)
  2. Self-review; 3. Commit
Acceptance: validate.sh pass; causal-chain gate present before fix phase; escalation table present

## U5: reviewing skill
Files:
  Create: skills/reviewing/SKILL.md, skills/reviewing/references/{lanes.md, merge-pipeline.md, receiving.md, suppression.md}
  Modify: none (schemas already committed)
Steps:
  1. Write per spec §reviewing + distill-review inventory: 4 always-on + 5 conditional lanes (persona texts distilled from CE agents), confidence anchors, merge/dedup verbatim, validator wave vs capped-loop dual verification, mode:agent envelope per schemas, receiving half from SP
  2. Self-review; 3. Commit
Acceptance: validate.sh pass; lane roster count 4+5; envelope schema referenced not restated; receiving pipeline README→...→IMPLEMENT present

## U6: shipping skill
Files:
  Create: skills/shipping/SKILL.md, skills/shipping/references/{ci-loop.md, pr-feedback.md}
Steps:
  1. Write per spec §shipping + distill-ship inventory (verification gate, branch detection, commit cascade with repo-convention-wins, PR modes + --body-file guardrail, CI cap 3 + never-weaken, feedback round cap 4 + divert taxonomy, merge gate, cleanup invariants, capability preflight → preparation-only terminal state)
  2. Self-review; 3. Commit
Acceptance: validate.sh pass; merge gate expressed in P-levels; preflight section present

## U7: retrospective + compound + compound-refresh skills
Files:
  Create: skills/retrospective/SKILL.md, skills/compound/SKILL.md (+references/schema.md distilled two-track), skills/compound-refresh/SKILL.md, skills/compound/scripts/validate-frontmatter.py (stdlib port)
Steps:
  1. Write per spec tables + distill-retro inventory (measured-vs-declared as core phase; headless contract lines exactly per schemas/headless-contract.md; v0.2 deferrals as documented hook points; refresh headless = recommend-only)
  2. Self-review; 3. Commit
Acceptance: validate.sh pass; terminal signal lines byte-identical to headless-contract.md; retro template referenced not restated

## U8: release-loop skill + verification + install
Files:
  Create: skills/release-loop/SKILL.md, skills/release-loop/references/progress-schema.md
  Modify: README.md (only if drift found)
Steps:
  1. Write orchestrator per spec §release-loop: phase table calling the 11 skills, gates (Design USER always; --skip-design requires approved spec), progress.md schema (version, timestamps, artifact pointers, approval evidence), resume protocol
  2. Run scripts/validate.sh — all checks green (success criteria 1–4)
  3. Headless smoke: compound mode:headless on a fixture lesson → exact terminal signal (criterion 7)
  4. Install: Claude Code local marketplace add + install; Codex skills root symlink; verify discovery by command output (criterion 6)
  5. Commit; final report with measured criteria table
Acceptance: validate.sh exit 0; both harnesses list the skills; smoke signal line matches contract

## Deferred to Follow-Up Work

- v0.2 items listed in the spec (conformance suite, EntireContext hooks, refresh auto-apply, lane schema, schema validators with fixtures)
- Publishing to a remote git host / dotagents registration (outward step — user's call, enforces: P7)

## Open unknowns

- Planning-time: none blocking.
- Implementation-time: exact Codex skills root on this machine (verified at U8 install, not assumed); whether Claude Code marketplace add requires a git commit per change (observed during U8).
