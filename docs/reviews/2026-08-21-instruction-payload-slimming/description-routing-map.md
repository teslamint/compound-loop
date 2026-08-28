## Description Routing Map — Instruction Payload Slimming (U5)

- **Baseline:** `f2efda9` (skills-text baseline), section (c) of `docs/reviews/2026-08-21-instruction-payload-slimming/baseline.md`, used as the authoritative per-skill trigger/negative/routing-clause inventory.
- **Scope:** every baseline-marked trigger phrase and negative/routing clause across all 13 `skills/*/SKILL.md` `description:` fields, mapped to its current-working-tree survival text.
- **Method:** each row's `Survival text` is a literal substring of the current file's `description:` field (verified mechanically below); rows marked `reworded` compress the baseline wording while preserving the same routing condition — non-inversion asserted by direct reading, not just substring presence.
- **SC2 measurement** (`for f in skills/*/SKILL.md; do awk '/^description:/{f=1} f{print} /^---$/&&NR>1{exit}' "$f"; done | wc -c`): **3189 bytes** (ceiling 3200). Per-file breakdown in the appendix.
- **`release`** description is pinned byte-identical to `f2efda9` (adjudication.md C3 exclusion) — its four rows below are `verbatim`, not `reworded`.

| # | Skill | Kind | Baseline text (f2efda9) | Survival text (current) | Class | reviewer-verdict |
|---:|---|---|---|---|---|---|
| 1 | `compound-refresh` | trigger | /compound-refresh | /compound-refresh | verbatim | pending |
| 2 | `compound-refresh` | trigger | $compound-refresh | $compound-refresh | verbatim | pending |
| 3 | `compound-refresh` | trigger | "refresh my learnings" | "refresh my learnings" | verbatim | pending |
| 4 | `compound-refresh` | trigger | "audit docs/solutions/" | "audit docs/solutions/" | verbatim | pending |
| 5 | `compound-refresh` | trigger | "clean up stale docs" | "clean up stale docs" | verbatim | pending |
| 6 | `compound-refresh` | trigger | "consolidate overlapping docs" | "consolidate overlapping docs" | verbatim | pending |
| 7 | `compound-refresh` | trigger | when compound flags an older doc as a refresh candidate | when compound flags a candidate | reworded | pending |
| 8 | `compound-refresh` | negative | Do not trigger for general refactor or code-review work unless the user explicitly points at docs/solutions/ | Skip general refactor/code-review unless pointed at docs/solutions/ | reworded | pending |
| 9 | `compound` | trigger | /compound | /compound | verbatim | pending |
| 10 | `compound` | trigger | $compound | $compound | verbatim | pending |
| 11 | `compound` | trigger | right after verifying a fix | right after verifying a fix | verbatim | pending |
| 12 | `compound` | trigger | when retrospective invokes it in mode:headless with a qualifying finding | when retrospective invokes it in mode:headless with a qualifying finding | verbatim | pending |
| 13 | `compound` | trigger | "document this" | "document this" | verbatim | pending |
| 14 | `compound` | trigger | "compound this fix" | "compound this fix" | verbatim | pending |
| 15 | `debugging` | trigger | debugging errors, investigating test failures, reproducing bugs from issue trackers | debugging errors, investigating failures, reproducing bugs | reworded | pending |
| 16 | `debugging` | trigger | stuck after failed fix attempts | stuck after failed fixes | reworded | pending |
| 17 | `debugging` | trigger | "debug this" | "debug this" | verbatim | pending |
| 18 | `debugging` | trigger | "why is this failing" | "why is this failing" | verbatim | pending |
| 19 | `debugging` | trigger | "trace this error" | "trace this error" | verbatim | pending |
| 20 | `debugging` | trigger | pastes a stack trace or error message | a stack trace/error | reworded | pending |
| 21 | `designing` | trigger | /designing | /designing | verbatim | pending |
| 22 | `designing` | trigger | $designing | $designing | verbatim | pending |
| 23 | `designing` | trigger | starting new feature work | starting new feature work | verbatim | pending |
| 24 | `designing` | trigger | release-loop's Design phase fires | release-loop's Design phase | reworded | pending |
| 25 | `designing` | trigger | implementation is about to begin without an approved design | implementation begins without an approved design | reworded | pending |
| 26 | `designing` | routing | too simple to need one | too simple to need one | verbatim | pending |
| 27 | `implementing` | trigger | Execute an approved plan to completion with review checkpoints, surviving context loss, on any harness | Execute an approved plan to completion with review checkpoints, surviving context loss, on any harness | verbatim | pending |
| 28 | `planning` | trigger | /planning | /planning | verbatim | pending |
| 29 | `planning` | trigger | $planning | $planning | verbatim | pending |
| 30 | `planning` | trigger | "plan this" | "plan this" | verbatim | pending |
| 31 | `planning` | trigger | "write an implementation plan" | "write an implementation plan" | verbatim | pending |
| 32 | `planning` | trigger | "break this into tasks" | "break this into tasks" | verbatim | pending |
| 33 | `planning` | trigger | a designing-phase spec is ready to plan | a designing-phase spec is ready to plan | verbatim | pending |
| 34 | `release` | trigger | /release | /release | verbatim | pending |
| 35 | `release` | trigger | $release | $release | verbatim | pending |
| 36 | `release` | trigger | mode:headless for a prepare-only handoff | mode:headless for a prepare-only handoff | verbatim | pending |
| 37 | `release` | trigger | a SemVer argument to propose that exact version | a SemVer argument to propose that exact version | verbatim | pending |
| 38 | `release-loop` | trigger | /release-loop <feature> | /release-loop <feature> | verbatim | pending |
| 39 | `release-loop` | trigger | $release-loop <feature> | $release-loop <feature> | verbatim | pending |
| 40 | `release-loop` | routing | Each phase invokes a standalone compound-loop skill; this skill only sequences, gates, and persists state | each phase invokes its own skill; this only sequences/gates/persists state | reworded | pending |
| 41 | `release-loop` | negative | Bare resume continues a live record; use <feature> resume when no live record exists | bare resume continues a live record, <feature> resume when none exists | reworded | pending |
| 42 | `retrospective` | trigger | /retrospective | /retrospective | verbatim | pending |
| 43 | `retrospective` | trigger | $retrospective | $retrospective | verbatim | pending |
| 44 | `retrospective` | trigger | after a PR merges | after a PR merges | verbatim | pending |
| 45 | `retrospective` | trigger | at the end of a session or debugging arc | at session/debugging-arc end | reworded | pending |
| 46 | `retrospective` | trigger | "run a retro" | "run a retro" | verbatim | pending |
| 47 | `retrospective` | trigger | "retrospective on this" | "retrospective on this" | verbatim | pending |
| 48 | `retrospective` | trigger | release-loop's Retro phase fires | release-loop's Retro phase | reworded | pending |
| 49 | `reviewing` | trigger | /reviewing | /reviewing | verbatim | pending |
| 50 | `reviewing` | trigger | $reviewing | $reviewing | verbatim | pending |
| 51 | `reviewing` | routing | mandatorily after each subagent task, after completing a major feature, or before merge | mandatory after subagent tasks, major features, or before merge | reworded | pending |
| 52 | `reviewing` | routing | optionally when stuck, before refactoring, or after a complex bugfix | optional when stuck, refactoring, after bugfixes | reworded | pending |
| 53 | `reviewing` | routing | whenever release-loop's Review phase fires | on release-loop's Review phase | reworded | pending |
| 54 | `reviewing` | routing | whenever external feedback (a human reviewer, a bot, another agent) needs disciplined evaluation before you implement it | on external feedback needing disciplined evaluation | reworded | pending |
| 55 | `shipping` | trigger | /shipping | /shipping | verbatim | pending |
| 56 | `shipping` | trigger | $shipping | $shipping | verbatim | pending |
| 57 | `shipping` | trigger | when review is clean and work is ready to ship | when review is clean and ready to ship | reworded | pending |
| 58 | `shipping` | trigger | release-loop's Ship phase fires | release-loop's Ship phase | reworded | pending |
| 59 | `shipping` | trigger | "commit and open a PR" | "commit and open a PR" | verbatim | pending |
| 60 | `shipping` | trigger | "ship this" | "ship this" | verbatim | pending |
| 61 | `shipping` | trigger | "finish this branch" | "finish this branch" | verbatim | pending |
| 62 | `tdd` | trigger | when implementing any feature or bugfix, before writing implementation code | when implementing any feature or bugfix, before writing implementation code | verbatim | pending |
| 63 | `worktree-isolation` | trigger | when starting feature work that needs isolation from the current workspace or before executing an implementation plan | when starting feature work that needs isolation from the current workspace or before executing an implementation plan | verbatim | pending |

## Mechanical completeness verification

No dedicated description-routing-map validator exists in `scripts/` (confirmed by search of `scripts/*.sh` for `description-routing-map|routing.map|INVENTORY|survival`; only an unrelated planning-reference `INVENTORY` array matched). This pass performs the plan's U5-step-3 completeness check directly: for every one of the 63 rows above, `survival text in current-skill-description` was asserted programmatically against the live working-tree files (`awk '/^description:/{f=1} f{print} /^---$/&&NR>1{exit}' skills/<name>/SKILL.md`), with YAML single-quote-escape (`''` -> `'`) accounted for on `shipping`'s scalar (its row's raw-byte substring check false-positived on the escaped apostrophe; the YAML-unescaped value was confirmed to contain the clause). Result: **63/63 rows pass** — every baseline-marked trigger and negative/routing clause is present, in original or compressed form, in its own skill's current description, with no clause moved to a different skill and no clause inverted.

## Appendix — SC2 byte breakdown (current working tree)

| Skill | Bytes | Compressed this pass |
|---|---:|---|
| `compound-refresh` | 299 | yes |
| `compound` | 255 | yes |
| `debugging` | 250 | yes |
| `designing` | 289 | yes |
| `implementing` | 120 | no (already minimal / untouched) |
| `planning` | 207 | no (already minimal / untouched) |
| `release` | 344 | no (already minimal / untouched) |
| `release-loop` | 272 | yes |
| `retrospective` | 283 | yes |
| `reviewing` | 367 | yes |
| `shipping` | 227 | yes |
| `tdd` | 97 | no (already minimal / untouched) |
| `worktree-isolation` | 179 | yes |

**Total: 3189 bytes** (ceiling 3200; margin 11 bytes).
