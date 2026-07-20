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
| `release` skill (13th): local post-merge CHANGELOG, synchronized manifests, first-hand release/publication gates, annotated tags, prepare-only headless handoff, and resumable outward publication | `v0.3.0` | Release commit `22b4d85`; tag `v0.3.0`; [GitHub release](https://github.com/teslamint/compound-loop/releases/tag/v0.3.0); first live smoke classified matching branch/tag, executed only `page-create`, then independently verified `noop/fully-matching` with a byte-exact CHANGELOG body | Local ceremony originally shipped at `v0.2.0` (`c3cbf01`); protected `v0.2.0` remains non-republishable through normal publication; future versions reuse the same separate-consent, missing-suffix, fail-closed boundary |

## Carry-forward from retros

Open items registered by retro docs (`docs/retros/`), pushed here per `retrospective` Phase 4 (durable tracker, never retro-doc-only). Remove a row when its retro reconciliation marks it Done.

| Item | Origin | Priority | Trigger / next step |
|---|---|---|---|
| Clean-environment Codex install check: plugin-native skill discovery (`.codex-plugin/plugin.json`) has never been isolated from the dev machine's `~/.agents/skills/` symlinks | 2026-07-16 v0.1 release retro | P3 | First external or clean-machine Codex install |
| Automated numbered-reference validation for planning and plan schema: prove contiguous heading/list numbering and resolve planning-step references across `skills/planning/SKILL.md`, `skills/planning/references/*.md`, and `schemas/plan-schema.md` | 2026-07-18 process-guidance carry-forward retro | P3 | Before the next numbered planning-step or plan-schema hard-floor insertion, add the check to structural validation |
| Pin the tracked Python support contract in every non-fixture compatibility consumer, including the publication harness delegation | 2026-07-19 Python compatibility gate retro | P3 | Before the next publication-harness or compatibility-consumer edit, set `PYTHON_SUPPORT_FILE` explicitly at the delegation boundary |
| Structural check for schema/skill format drift: nothing in `scripts/validate.sh` catches a `schemas/*.md` document (e.g. `retro-template.md`'s Release data table shape) diverging from the skill phase prose that must produce or consume it — found only by manual review, not tooling, when `retrospective`'s Phase 2 metric wording and `retro-template.md`'s table row disagreed | 2026-07-20 diff-size-metric-reconciliation review (`docs/reviews/2026-07-20-diff-size-metric-reconciliation-review.md`) | P3 | Next time a `schemas/*.md` table/field shape changes, add a check (even a targeted grep) that every skill phase citing that shape still names the same fields |
| Locally-invoked skills can silently diverge from the repo's tracked `skills/<name>/SKILL.md`: `dotagents` pins each installed skill to a resolved GitHub commit in `~/.agents/agents.lock`, so a same-session edit + push is invisible to skill invocations until `npx @sentry/dotagents install` is re-run — observed directly against `skills/retrospective/SKILL.md`; confirmed fixable (`install --user` re-resolved `agents.lock` to the pushed `HEAD` and the drift disappeared), but nothing prompts the re-install automatically | 2026-07-20 diff-size-metric review and planning-gate retro | P2 | Add a proactive reminder or check (e.g. a note in `shipping`'s post-push report, or a `dotagents doctor`-style staleness check) that a skill-touching push should be followed by `npx @sentry/dotagents install` before the next same-session skill invocation |

## Non-goals (re-affirmed)

- Porting the remaining product-specific compound-engineering skills (dhh-rails-style, gemini-imagegen, riffrec, proof, promote, product-pulse, test-xcode, slack-research, polish, dogfood-beta, strategy).
- ce-optimize's full experiment loop — its measurable-goal discipline already lives in `designing`'s required Success Criteria + `retrospective`'s measured-vs-declared pass.
