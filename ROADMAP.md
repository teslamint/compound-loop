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
| Evidence-tier vocabulary | Shared CONCEPTS.md ladder of completion-evidence strength (failing-repro-now-passing > end-to-end run > integration test > unit test > typecheck/build; typecheck alone never closes a completion claim, a unit test only closes a unit-level claim) plus binary reporting language (`verified: <observation>` / `unverified: <blocker>`, no "should work" hedges) consumed by reviewing/shipping/retrospective | First completion claim that escapes review because it was verified at a lower layer than the requirement lived at |
| Skill-level trace evidence | Structured channel where a retro records which skill *section* the session confirmed, contradicted, or refined; compound-refresh consumes the rows as skill-maturity evidence (today lessons reach docs/solutions/ and ROADMAP, never a per-skill-section record) | First retro lesson that contradicts a shipped skill's guidance rather than the code under work |
| New-skill distinctness gate | Absorb-over-add rule for skill proposals: a candidate must show evidence distinct from every existing skill or be absorbed into the nearest one — complements trigger-to-build (which decides *when* to build; this decides *whether*) | Next new-skill proposal (14th skill) |

The last three rows come from the 2026-07-23 survey of
[rlaope/ultraprompt](https://github.com/rlaope/ultraprompt)
([docs/research/ultraprompt-survey.md](docs/research/ultraprompt-survey.md)) —
external idea imports, not v0.1 deferrals. The survey's fourth import
(hypothesis kill criteria / predict-before-probe / boring hypothesis) was applied
directly to `skills/debugging/SKILL.md` the same day and is not tracked here.

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
| Carry-forward check needs a structural assertion: the end-of-interview carry-forward check (probed-row→T-ID linkage) is prose-only and had zero execution evidence across all three dry runs (dry-run evidence doc erratum 4); the 2026-07-21 retro's commit records its first execution, but nothing mechanical fails a retro doc whose probed rows lack `(T<n>)` citations | 2026-07-21 retro-interview-enforcement retro (T5) | P3 | First retro where a probed carry-forward row survives to commit without its T-ID citation, or the next retro-template/check-9 design cycle |
| Plan internal clause-consistency check: planning self-review, independent plan review, and implementing preflight all validate plan-against-spec or across units — none diffs a plan's architecture-note prose against its unit step contracts, which let the F2 contradiction (deviation addendum 003) survive all three layers | 2026-07-21 retro-interview-enforcement retro (T4) | P3 | Next edit to `skills/planning/SKILL.md` self-review or `skills/implementing/SKILL.md` preflight, or the next plan whose architecture notes summarize unit behavior |
| Interview protocol vocabulary gaps (deferred by design, not oversight): `Previous doc shape` has no value for "no previous retro doc exists" (first retro); no closed verdict form for a dispatch cap exhausted mid-exchange (before 3 rejections); Round-span notation (`1→2`) and qualified/composite accepted-verdict forms are used by the dry runs but not exemplified in `schemas/retro-template.md`; `references/interview-probes.md` maps only `self-checklist` mode — the in-thread verdict form is stated only generically in SKILL.md | 2026-07-21 retro-interview-enforcement reviewing phase, pre-merge (F14, F15 + final-review minors U6-m2, U6-m4, U3-m2) | P3 | First real retro that hits one of these cases, or the next interview-protocol design cycle — vocabulary changes go through `designing`, not a patch |
| check 9 / drift-harness coverage follow-ups: check 9's malformation-guard branches (level count ≠ 4, verdict forms ≠ 3, missing `Verdict cell values:` line) and the harness's own cleanup/TMPDIR failure paths have no fixture cases; a hypothetical paren-leading verdict form would be silently skipped by the anchor extraction | 2026-07-21 retro-interview-enforcement reviewing phase, pre-merge (F11, F12 + final-review minor U5-m2) | P3 | Next edit to `scripts/validate.sh` check 9 or `scripts/test-retro-format-drift.sh` |
| Pre-existing validate.sh check 5 raises a Python traceback on an unreadable `schemas/*.md` file instead of a named `FAIL:` line (loud-failure convention that checks 6 and 9 follow) | 2026-07-21 retro-interview-enforcement reviewing phase, pre-merge (U5-m3, pre-existing/out of scope) | P4 | Next validate.sh robustness pass, or first time check 5 tracebacks in real use |
| Release headless-path `.release/draft.md` carries no in-file non-authorization marker — the spec's "every persisted packet" invariant vs R7's interactive-only scope (U4-m1); resolve via `designing` (extend the marker to the headless write, or scope the invariant with an explicit exception) | 2026-07-22 final-action-session-resilience retro (T2) | P3 | Next design cycle touching release's draft contract or the marker invariant |
| `final_action` record polish: add a marker/note slot to the schema block so the per-packet marker lives at data level and shipping's byte-for-byte single-sink claim is literally satisfiable (N-1); give `predicted → determined` the same explicit same-edit Log clause as the other transitions (N-2) | 2026-07-22 final-action-session-resilience retro (T3, T4) | P3 | Next edit to `skills/release-loop/references/progress-schema.md` or release-loop Gate handling |
| Define "hand-up packet" locally in `skills/shipping/SKILL.md` (used at Steps 7–8 without definition; pre-existing, surfaced by U3 review) | 2026-07-22 final-action-session-resilience retro (U3-m1) | P4 | Next shipping SKILL edit |
| Mechanical `scripts/validate.sh` check for `final_action` shape (plan Deferred item) | 2026-07-22 final-action-session-resilience plan, Deferred to Follow-Up Work | P3 | First observed drift in a real progress.md `final_action` record |

## Non-goals (re-affirmed)

- Porting the remaining product-specific compound-engineering skills (dhh-rails-style, gemini-imagegen, riffrec, proof, promote, product-pulse, test-xcode, slack-research, polish, dogfood-beta, strategy).
- ce-optimize's full experiment loop — its measurable-goal discipline already lives in `designing`'s required Success Criteria + `retrospective`'s measured-vs-declared pass.
