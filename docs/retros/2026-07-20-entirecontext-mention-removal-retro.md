# Retro: EntireContext mention removal (v0.3.1)

- Date: 2026-07-20
- Source: ad-hoc — direct user invocation, no PR (this repo commits directly to `main`)
- Spec: none — user explicitly decided to skip `designing` for this change
- Plan: `docs/plans/2026-07-20-001-docs-remove-entirecontext-mentions-plan.md`

## Release data

| Metric | Value |
|---|---|
| Code delta (product / test / docs) | product: `-1` line (`skills/retrospective/SKILL.md`); test: none; docs: `+172/-1` (`ROADMAP.md` `-1`; `docs/plans/2026-07-20-001-docs-remove-entirecontext-mentions-plan.md` `+119`; release-touched `CHANGELOG.md` `+5`, `.claude-plugin/plugin.json` `+1/-1`, `.codex-plugin/plugin.json` `+1/-1`), measured over `e78a691^..f4c68f6` |
| Commits | 4 (`e78a691` plan draft, `283890c` plan approval, `b37675f` implementation, `f4c68f6` release) |
| Review rounds | 0 formal review lane — self-review was the plan's step-3 grep check, run and passing before commit |
| Comments (fixed / deferred) | 0 / 0 — no external review comments; no items deferred |
| CI failures | 0 — no CI configured for this repo; `bash scripts/validate.sh` passed at every commit boundary |
| Duration (first spec commit → merge) | no spec exists; plan-to-release span was `e78a691` at `2026-07-20T11:42:13+09:00` to `f4c68f6` at `2026-07-20T11:50:52+09:00` = 8m39s |
| Units planned / completed | 1 / 1 (`U1: Delete EntireContext references from SKILL.md and ROADMAP.md`) |

## Success criteria: measured vs declared

No spec exists for this change (user explicitly skipped `designing`); this section is skipped per the retrospective contract. The plan's own acceptance check is measured fresh instead, since it is the nearest declared, verifiable target:

| # | Declared plan acceptance (U1) | Measurement (command) | Measured result | Verdict |
|---|---|---|---|---|
| 1 | A case-insensitive search for `entirecontext\|ec_decision\|ec_lessons` across `skills/`, `schemas/`, `scripts/`, `README.md`, `CONCEPTS.md`, `ROADMAP.md` returns zero matches | `rg -in 'entirecontext\|ec_decision\|ec_lessons' skills schemas scripts README.md CONCEPTS.md ROADMAP.md` | Exit code `1` (no matches) | Met |
| 2 | Remaining hits confined to `docs/specs/`, `docs/plans/`, `docs/research/` (provenance) | `rg -il 'entirecontext\|ec_decision\|ec_lessons' docs` | Hits only under `docs/plans/` (including this arc's own plan file, expected), `docs/research/`, `docs/specs/` | Met |
| 3 | `bash scripts/validate.sh` passes | `bash scripts/validate.sh` | `ALL CHECKS PASSED`, exit 0 | Met |
| 4 | Release commit contains exactly the three release paths, both manifests read `0.3.1`, newest CHANGELOG heading is `[0.3.1] - 2026-07-20`, tag `v0.3.1` dereferences to the release commit, and `origin` matches locally | `git diff-tree --no-commit-id --name-only -r f4c68f6`; manifest/CHANGELOG parse; `git rev-parse 'v0.3.1^{}'` vs `HEAD`; `git ls-remote origin` | Path set exactly `.claude-plugin/plugin.json .codex-plugin/plugin.json CHANGELOG.md`; both manifests `0.3.1`; heading matches; tag target `f4c68f6` = `HEAD`; remote `main` and `v0.3.1`/`v0.3.1^{}` match local | Met |
| 5 | The release was tagged and pushed only — no outward GitHub publication was performed | `git push` output; `gh release view v0.3.1` | Commit and tag pushed to `origin`; `gh release view v0.3.1` returns `release not found` | Met |

## Carry-forward from previous retro

Previous retro: `docs/retros/2026-07-19-v0.3.0-release-publication-retro.md`.

| Item | Status | Evidence |
|---|---|---|
| Pin the tracked Python support contract in every non-fixture compatibility consumer, including the publication harness delegation | Not started | `rg -n 'PYTHON_SUPPORT_FILE' scripts/release-publication.sh` finds no match; this arc's release (`f4c68f6`) touched only `CHANGELOG.md` and both manifests, not `scripts/release-publication.sh` |
| Diff-size metric reconciliation: one named metric per cross-phase citation | **In progress** (not attributable to this arc) | While this retro was in flight, two unrelated commits landed on `main` addressing this exact item: `314fe25` ("Standardize diff-size metric tracking across review and retro phases", assisted by Gemini 3.1 Pro) added `docs/plans/2026-07-20-001-chore-diff-size-metric-plan.md`, and `313e0d1` ("docs: define Changed non-test lines metric in CONCEPTS", assisted by Antigravity) added the `Changed non-test lines` definition to `CONCEPTS.md`. As of this retro, `skills/retrospective/SKILL.md` still has an **uncommitted** working-tree edit (`git status --porcelain` shows ` M skills/retrospective/SKILL.md`, changing Phase 2's `Git/PR metrics` line to use the new term) — the item is mid-flight, not Done, and this retro's own commit must not touch that dirty file |
| Clean-environment Codex install check | Not started | No new clean-install artifact or script exists; `find . -iname '*clean-env*' -o -iname '*clean-install*'` (excluding `.git`) returns nothing |
| Automated numbered-reference validation for planning and plan schema | Not started | `rg -n 'numbered.reference\|contiguous heading' scripts/validate.sh` finds no match |

## Findings

### What worked well

- **What happened**: The approved plan (`docs/plans/2026-07-20-001-docs-remove-entirecontext-mentions-plan.md`) explicitly recorded `No origin spec; no approved live assumptions to recheck` and a named rationale for skipping `designing` (single-unit, below the smell-test floor, done only because the user explicitly asked for the full plan→release→retro cycle), rather than silently proceeding without a spec.
  **Why**: The plan schema requires an explicit Assumption Recheck line for every plan; writing the skip reason inline made the shortcut auditable instead of implicit.
  **How to apply**: Continue writing an explicit "why no spec" justification in Architecture notes whenever a plan skips `designing`, even for changes this small.
- **What happened**: All four self-review acceptance checks (shipped-surface grep, docs-residual grep, `validate.sh`, four-way release agreement) were re-run fresh during this retro rather than trusted from the implementation session's own report, and all five reproduced exactly (Success criteria table rows 1–5).
  **Why**: `enforces: P3` requires fresh measurement, not reuse of a prior claim.
  **How to apply**: Keep treating the plan's own acceptance section as the fallback measured-vs-declared table whenever no spec exists, rather than skipping measurement entirely.

### What to improve

- **What happened**: The facilitator's probe on distributed-consumer coverage found that the shipped-surface grep only covers the tracked repository tree, not an actually-installed plugin copy under `~/.claude/plugins/cache/` or a clean Codex install; the existing P3 carry-forward item "Clean-environment Codex install check" already names exactly this gap, and this arc did not close it.
  **Why**: `scripts/validate.sh` and the plan's acceptance checks only inspect the git-tracked source tree, never an installed copy.
  **How to apply**: When that carry-forward item is eventually picked up, include a check that a doc-removal change (not only a code change) is reflected in an installed plugin copy — this arc is one more data point that doc-only removals share the same unproven boundary as code changes.

### Process observations

- **What happened**: Two commits from a separate, unrelated workstream (`314fe25`, `313e0d1`, both explicitly assisted by non-Claude tools — Gemini 3.1 Pro and Antigravity) landed on `main` while this retro was being written, addressing the "diff-size metric reconciliation" carry-forward item from the previous retro. A further edit to `skills/retrospective/SKILL.md` from that same workstream was still uncommitted in the working tree at retro time.
  **Why**: This repo has no branch protection or PR gate; multiple agents/sessions commit directly to `main` concurrently, so the repository state a retro's Phase 4 reconciliation sees can change between the retro's invocation and the moment Phase 4 actually runs.
  **How to apply**: Phase 4 carry-forward reconciliation must re-read `git log`/`git status` at the moment of writing, not rely on the state assumed when the retro was invoked, and must never attribute or claim credit for a concurrently-landed commit that belongs to a different arc — report status honestly (e.g. "In progress, not attributable to this arc") rather than either silently ignoring it or folding it into this retro's own narrative.
- **What happened**: This retro's own commit must stage only `docs/retros/2026-07-20-entirecontext-mention-removal-retro.md`; it must not stage `skills/retrospective/SKILL.md`, which carries the concurrent workstream's uncommitted, unrelated edit.
  **Why**: Committing that file here would either silently finish someone else's in-flight edit under this retro's authorship or overwrite it if the concurrent session commits first.
  **How to apply**: Always run `git status --porcelain` immediately before a retro's own Phase 8 commit and stage files by explicit name, never `git add -A`, exactly as the release skill already requires for its own commit.

## Carry-forward items registered

No new carry-forward item is registered. The one new observation from this cycle (clean-install boundary applying to doc-only changes too) reinforces the existing P3 "Clean-environment Codex install check" row in `ROADMAP.md` rather than duplicating it; that row is left unchanged.

## Lessons

- On a shared `main` with no PR gate, a retro's carry-forward reconciliation must re-check git state at the moment Phase 4 actually runs, not at invocation time — two unrelated commits from a different agent landed on the exact item being reconciled while this retro was in progress, and misattributing them (or ignoring them) would have produced a wrong status.
- Removing a documented-but-never-implemented third-party hook point is a pure content-deletion change with zero executable-path impact: the entire proof of correctness reduces to "the shipped surface no longer names it," verifiable by two greps and `validate.sh` — no test suite, mutation matrix, or spec was needed because nothing executable ever depended on the removed text.

## Compounding

- compound invocation: `not attempted — no reusable lesson this cycle`; both lessons above are specific to this dual-session/no-PR-gate workflow already documented in the user's standing operating context, and the concurrent-commit observation is process-level guidance for retro authorship rather than a repo-durable technical pattern — no `docs/solutions/` gap or repeated occurrence justifies a standalone solution doc yet
