# Review: Diff-size metric reconciliation arc

- Reviewed commits: `314fe25`, `313e0d1`, `7f4fd37` on `main`
- Reviewed plan: `docs/plans/2026-07-20-001-chore-diff-size-metric-plan.md`
- Reviewer: Claude Code (ad hoc content review, not a `/reviewing` skill run)
- Audience: the workflow that authored this arc (commits attributed to
  Gemini 3.1 Pro and Antigravity) — this file is self-contained; it assumes
  no memory of any prior conversation.
- **Status: closed.** P1/P2/P3 were fixed in `aa4a94c` ("fix: align retro
  template and citation style for diff-size metric"), re-verified fresh
  against `HEAD`. P4 was left open by design (process note, no code impact).
  Findings below are kept verbatim as the original record; see the Outcome
  column and Resolution section for current status.

## Context

Three commits closed the ROADMAP carry-forward item "Diff-size metric
reconciliation: one named metric per cross-phase citation ... so lane-trigger
decisions never mix figures silently" (origin: 2026-07-16 signal-drift-check
retro):

1. `314fe25` — added the plan doc only (commit subject overstates scope; see
   P3 below).
2. `313e0d1` — added the `Changed non-test lines` definition to `CONCEPTS.md`.
3. `7f4fd37` — updated `skills/retrospective/SKILL.md` and
   `skills/reviewing/references/lanes.md` to cite the new term, and removed
   the ROADMAP carry-forward row.

`bash scripts/validate.sh` passes at `HEAD`. That is expected and does not
bear on the finding below — structural validation does not check cross-file
prose consistency.

## Findings

| Severity | File:Line | Finding | Evidence | Outcome |
|---|---|---|---|---|
| P1 | `schemas/retro-template.md:17` | The plan's stated goal was "one named metric per cross-phase citation," but this file — the actual contract `retrospective` must follow — was never updated. It still requires `Code delta (product / test / docs) \| +A/-B / +C/-D / +E/-F`, a three-way split with insertion/deletion counts. `skills/retrospective/SKILL.md:32` now instructs collecting `Changed non-test lines` (a single scalar), and `skills/retrospective/SKILL.md:71` (Phase 6) still says to follow `schemas/retro-template.md` "exactly ... table shapes ... are the contract other tooling may parse later." Following Phase 2's new instruction makes it impossible to fill the Release data table Phase 6 requires — the exact "figures mix silently across phases" failure mode this arc set out to fix, now moved from reviewing↔retro into retro's own internal Phase 2↔Phase 6. | `grep -n "Code delta" schemas/retro-template.md` → line 17 unchanged since before this arc. `git show 7f4fd37 --stat` touches only `ROADMAP.md`, `skills/retrospective/SKILL.md`, `skills/reviewing/references/lanes.md` — `schemas/retro-template.md` is absent from every commit in this arc. | **Fixed** in `aa4a94c` — row now reads `\| **Changed non-test lines** \| N (added + removed) \|`, agreeing with Phase 2. |
| P2 | `ROADMAP.md` (row removed by `7f4fd37`) | The carry-forward row was deleted as resolved while the P1 above is open. The durable tracker now claims a state that isn't true. This repo has its own recorded lesson for exactly this failure class: a structural/mechanical check (`validate.sh`, "the referenced files were edited") passing while the actual content-fidelity goal (a real cross-phase-consistent metric) remains unmet. Recommend either restoring the row or re-scoping it to name the specific remaining gap (`schemas/retro-template.md`'s Release data row), not deleting it. | `git show 7f4fd37 -- ROADMAP.md`; compare against `docs/solutions/` guidance on structural vs. traceability/content criteria (see e.g. the "Traceability criterion" / "Content-fidelity drift" concepts in `CONCEPTS.md`'s Release verification section, which this arc's own domain — metric definitions — should have applied to itself). | **Fixed** as a consequence of the P1 fix — the ROADMAP claim is now true, no separate ROADMAP edit was needed. |
| P3 | commit `314fe25` subject | Subject reads "Standardize diff-size metric tracking across review and retro phases," but the commit's entire diff is one new plan file (`docs/plans/2026-07-20-001-chore-diff-size-metric-plan.md`, 53 lines) — no standardization actually happened in this commit. The standardization work landed two commits later in `7f4fd37`. This is a minor but real mismatch between commit subject and diff scope; a git-log-driven release draft (see `skills/release/SKILL.md` Phase 2, which collects meaningful subjects) would misdescribe this commit's actual content if read from the subject alone. | `git show 314fe25 --stat` → only the plan file. | **Won't fix** — the commit is already in history; not amendable without rewriting shared history. Noted for future commit-message discipline only. |
| P3 | `skills/reviewing/references/lanes.md:72`, `skills/retrospective/SKILL.md:32` | The new term `Changed non-test lines` is cited in plain capitalized prose (`>=50 Changed non-test lines`, `Changed non-test lines, commit count, ...`) rather than the bold-citation convention this repo already uses for `CONCEPTS.md` terms elsewhere (`**Source inventory**`, `**Drop-list**`, `**Four-way version agreement**` — see `skills/release/SKILL.md` for examples). Minor style inconsistency, not a correctness issue. | `rg -n "Source inventory\|Drop-list" skills/release/SKILL.md` shows the bold convention; `grep -n "Changed non-test lines" skills/reviewing/references/lanes.md skills/retrospective/SKILL.md` shows the new citations are unbolded. | **Fixed** in `aa4a94c` — both citations now read `**Changed non-test lines**`. |
| P3 | `CONCEPTS.md:29` | `CONCEPTS.md`'s own preamble (line 3) says "definitions stay conceptual." Every other entry in the file begins its definition in lowercase immediately after the em-dash (`— the enumerable list...`, `— the post-merge process...`). The new entry breaks that pattern: `— The count of modified lines...` (capital T). Also underspecified relative to the file's own conceptual-but-precise style: it doesn't say whether "modified lines" means net or gross (added+removed), which is exactly the kind of ambiguity a "canonical diff-size metric" definition exists to remove. | `sed -n '1,29p' CONCEPTS.md` — direct comparison of casing across all seven entries. | **Fixed** in `aa4a94c` — lowercase `— the count of modified lines (added + removed) ...` now states the net-vs-gross rule explicitly. |
| P4 | plan process | `docs/plans/2026-07-20-001-chore-diff-size-metric-plan.md` was committed directly with `status: approved` in its only commit — no separate draft commit reviewed before approval. Other plans in this repo's history (e.g. `docs/plans/2026-07-20-001-docs-remove-entirecontext-mentions-plan.md`, committed the same day) used a two-commit draft→approved gate. Not a schema violation (`schemas/plan-schema.md` only requires a `status` field), but a process inconsistency worth normalizing if this workflow continues authoring plans in this repo. | `git log --oneline -- docs/plans/2026-07-20-001-chore-diff-size-metric-plan.md` shows one commit only, already `approved`. | **Open** — left as a process note for future plans by this workflow; no code or doc change applies retroactively. |

## Actionable Findings (original, kept for record)

The only P1/P2 items both trace to the same root cause and can close in one
change:

1. Update `schemas/retro-template.md:17`'s Release data row to name
   `Changed non-test lines` (or whatever single value Phase 2 is meant to
   collect) instead of the three-way `product / test / docs` split, so
   `retrospective` Phase 2 and Phase 6 agree on what shape the data takes.
   Decide explicitly whether the table still needs a `+insertions/-deletions`
   value or a plain count, and update the `Value` column's placeholder
   (`+A/-B / +C/-D / +E/-F`) to match.
2. Once that lands, the ROADMAP carry-forward row removal in `7f4fd37`
   becomes actually true; no further ROADMAP change is needed at that point.

P3/P4 items are optional polish — safe to batch into the same follow-up
commit or defer, reviewer's judgment.

## Resolution

`aa4a94c` ("fix: align retro template and citation style for diff-size
metric") applied exactly action 1 above and both P3 style fixes in one
4-file, 4-line commit:

- `schemas/retro-template.md:17` → `| **Changed non-test lines** | N (added + removed) |`
- `skills/retrospective/SKILL.md:32` and `skills/reviewing/references/lanes.md:72` → bold-cited
- `CONCEPTS.md:29` → lowercase em-dash start, explicit added+removed rule

Re-verified fresh against `HEAD` (not reused from the fix commit's own
claim, per this repo's own P3 evidence discipline):

```
$ sed -n '13,18p' schemas/retro-template.md
## Release data

| Metric | Value |
|---|---|
| **Changed non-test lines** | N (added + removed) |
| Commits | N |

$ grep -n "Changed non-test lines" skills/reviewing/references/lanes.md skills/retrospective/SKILL.md
skills/reviewing/references/lanes.md:72:**Trigger**: >=50 **Changed non-test lines**, OR touches auth, ...
skills/retrospective/SKILL.md:32:- **Git/PR metrics** (PR-merge mode): **Changed non-test lines**, commit count, ...

$ grep -n "Diff-size metric" ROADMAP.md
(no output — row correctly absent, and now accurately so)

$ bash scripts/validate.sh
ALL CHECKS PASSED
```

P2 required no separate fix — it was a consequence finding, and closing P1
made the already-removed ROADMAP row's claim true. P4 (plan draft/approve
gate) was left open by design; it is a process note about how future plans
get authored, not a defect in anything currently committed.

## Non-findings (verified correct, not raised as noise)

- `313e0d1` (the `CONCEPTS.md` addition itself, casing aside) is scoped
  correctly, matches the plan's U1 acceptance text exactly, and its commit
  message matches the plan's specified message verbatim.
- `7f4fd37`'s edits to `lanes.md` and `SKILL.md` correctly replace the prior
  ambiguous phrasing with the new canonical term — the *content* of the
  change is right; only the still-inconsistent `retro-template.md` and the
  citation style are at issue.
