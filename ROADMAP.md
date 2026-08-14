# Roadmap

## Future candidates

Originally deferred from v0.1 by explicit decision (spec "Deferred to v0.2"
section + post-release distillation audit). They are not promises for a
specific version. Each entry names its trigger — build it when the trigger
fires, not before (`enforces: P6`).

| Item | What | Trigger to build |
|---|---|---|
| Conformance suite | Golden-fixture end-to-end tests: full lifecycle, resume, one degraded dispatch tier, on both harnesses | First contract regression that structural validation (`scripts/validate.sh`) fails to catch — **fired** (structural validation passed 18 retro documents whose independence level the dispatch ladder did not warrant, found and repaired by the `feat/retro-interview-integrity` cycle, 2026-08-14); the suite build stays deferred to its own cycle, so this row remains open |
| Schema validators + fixtures | plan/v1 and review-envelope/v1 validators with valid/invalid/legacy/migration fixtures | First malformed plan or envelope produced in real use — **fired** (out-of-enum values tracked in a consuming repo, 2026-07-26); plan/v1 half closed by this cycle (`feat/plan-status-terminal-states`); review-envelope/v1 half remains open under the original trigger |
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
| ~~Clean-environment Codex install check: plugin-native skill discovery (`.codex-plugin/plugin.json`) has never been isolated from the dev machine's `~/.agents/skills/` symlinks~~ **Done** carry-forward-clear batch | 2026-07-16 v0.1 release retro | P3 | ~~First external or clean-machine Codex install~~ resolved: `scripts/test-plugin-skill-discovery.sh` validates plugin.json skill paths, frontmatter, and manifest agreement (13 skills, 0 failures) |
| ~~Interview protocol vocabulary gaps~~ **Done** carry-forward-clear batch | 2026-07-21 retro-interview-enforcement reviewing phase, pre-merge (F14, F15 + final-review minors U6-m2, U6-m4, U3-m2) | P3 | ~~First real retro that hits one of these cases~~ resolved: added `no previous retro doc` to Previous doc shape, `no evidenced answer (dispatch cap)` verdict form to retro-template.md, round-span notation, and verdict-by-independence-level table to interview-probes.md |
| ~~Release headless-path `.release/draft.md` carries no in-file non-authorization marker~~ **Done** carry-forward-clear batch | 2026-07-22 final-action-session-resilience retro (T2) | P3 | ~~Next design cycle touching release's draft contract or the marker invariant~~ resolved: extended non-authorization marker to both headless paths (normal + recovery) in `skills/release/SKILL.md` |
| ~~`skills/compound/scripts/validate-frontmatter.py` CPython 3.8 guard~~ **Closed** accepted risk | 2026-07-26 frontmatter-validator-python38 spec (R5) | P3 | Closed: user declined guard at 2026-07-26 Design gate (would require moving `minimum_minor`); incidental compatibility remains — risk accepted |
| ~~Seal check in shipped validator: `validate-plan-frontmatter.py` does not verify body_seal~~ **Done** carry-forward-clear batch | post-approval-immutability-and-publication-ceremony cycle (spec Open Decision 2) | P3 | ~~First consuming-repo adoption of plan/v1 with body_seal fields~~ resolved: added `body_seal` format validation (64-char hex SHA-256) to `validate-plan-frontmatter.py` |
| ~~SC5 outward-publication rubric unexercised~~ **Done** carry-forward-clear batch | post-approval-immutability-and-publication-ceremony retro | P3 | ~~First planning cycle whose deliverable includes an outward-publication transition~~ resolved: fixture plan (stateless fallback + `npm publish` unit) exercised the rubric — reviewing's outward-publication recognition check correctly identifies the matrix-requirement gap |
| ~~Spec Risk mitigation traceability: Risks table mitigations are not traced to plan units~~ **Done** carry-forward-clear batch | post-approval-immutability-and-publication-ceremony retro | P3 | ~~Next designing or planning cycle that names a Risk mitigation requiring a specific deliverable~~ resolved: planning step 14 Spec coverage check now traces Risk mitigations to units or Deferred entries |
| ~~`execution: ops` as a possible third execution mode~~ **Done** carry-forward-clear batch | 2026-07-27 plan-status-terminal-states cycle | P3 | ~~First `execution: ops` instance in this repo~~ resolved: added `ops` to `plan-schema.md` enum and `validate-plan-frontmatter.py` EXECUTIONS set |
| ~~Procedural skill text can authorize durable state transitions even when the tracked diff is documentation-only~~ **Done** default-worktree-isolation cycle | 2026-08-03 archive-on-loop-completion retro | P2 | ~~Next planning cycle whose procedural workflow text authorizes durable local mutation~~ resolved: the plan classified runtime effects and included a mutation/failure-state matrix, with Deviation 006 retaining the observed partial branch state |
| A success criterion that fires after Retro cannot be measured inside that Retro's Phase 3 pass | 2026-08-03 archive-on-loop-completion retro | P3 | Next design or retrospective cycle declaring a post-Retro terminal criterion — assign proof to the release-loop completion gate and retain the exact evidence path |
| Shipping can delete the isolated worktree that owns live release-loop state before Retro consumes that state | 2026-08-05 default-worktree-isolation retro | P2 | Next change touching shipping cleanup or the release-loop post-merge handoff — transfer live loop state to the base checkout before removing the feature worktree |
| Forced-failure matrices can omit the exact partial durable state and persist invalid shell syntax in Markdown tables | 2026-08-05 default-worktree-isolation retro | P3 | Next planning-contract change — require executable probe syntax, expected partial state, and compensation ownership before plan approval |
| ~~Issue #7's prepared correction is unposted and issues #6, #8, #9, #10 stay open although `0086cff` merged their repairs~~ **Done** 2026-08-15 | 2026-08-15 retro-interview-integrity retro | P2 | ~~Immediate, human-owned at the Ship gate~~ resolved: the human posted the prepared payload at [issues/7#issuecomment-5297152028](https://github.com/teslamint/compound-loop/issues/7#issuecomment-5297152028) and closed #6, #8, #9, #10 with their measurement citations |
| Loop artifacts that outlive their loop can sit only in gitignored `.release-loop/`, where the sanctioned worktree cleanup destroys them | 2026-08-15 retro-interview-integrity retro | P2 | Next change to shipping cleanup, release-loop archival, or any unit writing a post-merge deliverable into loop state — classify each file as disposable or outliving, and move the second class to a committed path first (`docs/solutions/workflow-issues/loop-deliverable-in-disposable-state.md`) |
| Facilitator and reviewer output is never persisted, so review claims rest on ledger summaries rather than the reviewer's own words | 2026-08-15 retro-interview-integrity retro | P3 | Next change to the interview protocol's round contract or to `reviewing`'s dispatch steps — write reviewer output verbatim to an artifact at dispatch time |
| Review verifies conformance to the sealed plan instead of attacking the invariant the plan claims to establish | 2026-08-14 retro-interview-integrity retro (T6) | P1 | Next cycle whose deliverable is an integrity or verification mechanism — before approval, construct the cheapest artifact that satisfies every written check while violating the intent, and require the mechanism to reject it |
| Finding severity graded against the blast radius of the code rather than the success criterion the finding threatens | 2026-08-14 retro-interview-integrity retro (T7) | P2 | Next review that triages a finding touching a mechanism the cycle exists to build — a hole in that mechanism is never Minor |
| A success criterion completed by a human action outside the pipeline has no gate that blocks the completion report | 2026-08-14 retro-interview-integrity retro (T8) | P2 | Next spec declaring a criterion no skill can discharge — SC7 shipped half-unmet because merge did not force the question |
| Dispatched agents that commit do not inherit `SSH_AUTH_SOCK`, so their commits land unsigned on an otherwise signed branch | 2026-08-14 retro-interview-integrity retro | P3 | Next cycle dispatching implementer subagents that commit — pass the socket explicitly and verify `%G?` per commit |

## Non-goals (re-affirmed)

- Porting the remaining product-specific compound-engineering skills (dhh-rails-style, gemini-imagegen, riffrec, proof, promote, product-pulse, test-xcode, slack-research, polish, dogfood-beta, strategy).
- ce-optimize's full experiment loop — its measurable-goal discipline already lives in `designing`'s required Success Criteria + `retrospective`'s measured-vs-declared pass.
