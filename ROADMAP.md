# Roadmap

## Future candidates

Originally deferred from v0.1 by explicit decision (spec "Deferred to v0.2"
section + post-release distillation audit). They are not promises for a
specific version. Each entry names its trigger — build it when the trigger
fires, not before (`enforces: P6`).

| Item | What | Trigger to build |
|---|---|---|
| Conformance suite | Golden-fixture end-to-end tests: full lifecycle, resume, one degraded dispatch tier, on both harnesses | First contract regression that structural validation (`scripts/validate.sh`) fails to catch |
| Schema validators + fixtures | plan/v1 and review-envelope/v1 validators with valid/invalid/legacy/migration fixtures | First malformed plan or envelope produced in real use |
| EntireContext hooks | `retrospective` feature-detects `ec_decision_create` (decisions from findings) and `ec_lessons` (dedup before writing) | When retro docs and EC lessons start visibly diverging |
| Session-history search | Pluggable prior-context source for session-scoped retros (ce-sessions distillation) | First session retro that needed "what was tried before" and couldn't answer it |
| compound-refresh headless auto-apply | Apply unambiguous Keep/Update actions headlessly (v0.1 is recommend-only) | After ~3 manual refresh cycles show the classifications are trustworthy |
| Cross-round deepening suppression | Skip re-surfacing findings the user rejected in a prior deepening round (evidence-overlap keyed) | First complaint about repeat findings in interactive deepening |
| Demo/evidence capture | ce-demo-reel distillation: GIF/screenshot evidence for PR bodies of UI-observable changes | First UI-heavy project adopting `shipping` |
| Project-defined lane schema | Formal schema for custom review lanes (v0.1: free-form markdown in the consuming repo's AGENTS.md) | Second project defining custom lanes |
| Ambient compound triggers | "that worked / it's fixed" phrase detection auto-offering `compound` (v0.1: explicit calls + skill descriptions) | Evidence that solved problems routinely go uncaptured outside release-loop |
| Gemini support verification | `ask_user` question-tool path is documented but untested | First Gemini-harness user |

## Shipped

| Item | Release | Evidence | Follow-up boundary |
|---|---|---|---|
| `release` skill (13th): local post-merge CHANGELOG, synchronized manifests, first-hand gate, annotated tag, and prepare-only headless handoff | `v0.2.0` | Release commit `c3cbf01`; tag `v0.2.0`; [GitHub release](https://github.com/teslamint/compound-loop/releases/tag/v0.2.0) reported published from the CHANGELOG section | Manual `v0.2.0` publication is complete; outward-publication automation for future releases is tracked below |

## Carry-forward from retros

Open items registered by retro docs (`docs/retros/`), pushed here per `retrospective` Phase 4 (durable tracker, never retro-doc-only). Remove a row when its retro reconciliation marks it Done.

| Item | Origin | Priority | Trigger / next step |
|---|---|---|---|
| Second pilot on a larger feature (5+ units, or 2+ conditional review lanes) to exercise the multi-agent dispatch tiers (Tier 1/2, parallel review lanes, per-unit reviewers) that the first pilot's single-agent floor never touched | 2026-07-16 signal-drift-check retro | P2 | Next feature big enough to qualify |
| Diff-size metric reconciliation: one named metric per cross-phase citation (total diff vs. per-file non-test lines), so lane-trigger decisions never mix figures silently | 2026-07-16 signal-drift-check retro | P3 | Next release-loop run that cites diff size across phases |
| Clean-environment Codex install check: plugin-native skill discovery (`.codex-plugin/plugin.json`) has never been isolated from the dev machine's `~/.agents/skills/` symlinks | 2026-07-16 v0.1 release retro | P3 | First external or clean-machine Codex install |
| Gated outward publication automation for `release`: remote/auth capability checks, a separate first-hand publication gate, exact CHANGELOG-section body reuse, idempotency, and partial-failure recovery; never republish `v0.2.0` except through an explicit repair path | 2026-07-16 release-skill v0.2.0 retro | P2 | Start a new designing cycle for future releases; the remote trigger fired and manual `v0.2.0` publication is already complete |
| Automated numbered-reference validation for planning and plan schema: prove contiguous heading/list numbering and resolve planning-step references across `skills/planning/SKILL.md`, `skills/planning/references/*.md`, and `schemas/plan-schema.md` | 2026-07-18 process-guidance carry-forward retro | P3 | Before the next numbered planning-step or plan-schema hard-floor insertion, add the check to structural validation |

## Non-goals (re-affirmed)

- Porting the remaining product-specific compound-engineering skills (dhh-rails-style, gemini-imagegen, riffrec, proof, promote, product-pulse, test-xcode, slack-research, polish, dogfood-beta, strategy).
- ce-optimize's full experiment loop — its measurable-goal discipline already lives in `designing`'s required Success Criteria + `retrospective`'s measured-vs-declared pass.
