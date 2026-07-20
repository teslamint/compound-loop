# Retro: Diff-size metric review, P4 fix, and ROADMAP registration

- Date: 2026-07-20
- Source: ad-hoc — session-end invocation, no PR (this repo commits directly to `main`)
- Spec: none
- Plan: none — both the review and the P4 fix were atomic, self-contained changes with no key technical decision the entry-check heuristic in `skills/planning/SKILL.md` step 1 would have flagged; see Findings

## Release data

| Metric | Value |
|---|---|
| **Changed non-test lines** | 135 (128 added + 7 removed), measured over `8a107c0..HEAD` — no test, generated, or lockfile paths touched |
| Commits | 3 authored this session (`d01fd12` review file, `d93698a` P4 fix, `57e1f1a` ROADMAP registration); 4 reviewed but externally authored (`314fe25`, `313e0d1`, `7f4fd37`, `aa4a94c`) |
| Review rounds | 1 — one review file (`docs/reviews/2026-07-20-diff-size-metric-reconciliation-review.md`) covering all 4 findings, one external fix commit (`aa4a94c`) addressing 3 of them, one Claude-authored fix (`d93698a`) addressing the 4th |
| Comments (fixed / deferred) | 4 / 0 — P1, P2, P3×2 fixed in `aa4a94c`; P4 fixed in `d93698a`; nothing deferred without an explicit reason |
| CI failures | 0 — no CI configured; `bash scripts/validate.sh` passed after every commit in this arc |
| Duration (first spec commit → merge) | no spec exists; session span for this cycle was `8a107c0` at `2026-07-20T12:28:42+09:00` to `57e1f1a` at `2026-07-20T13:49:19+09:00` ≈ 1h20m, including the review-authoring, external-fix wait, verification, and P4 investigation |
| Units planned / completed | no plan exists; 2 self-contained changes completed (review file; P4 gate documentation) |

## Success criteria: measured vs declared

No spec exists for this cycle. The review file's own findings table is the nearest declared, verifiable target; each row is re-measured fresh here rather than trusted from the review file's own "Outcome" column (`enforces: P3`):

| # | Declared finding (review file) | Fresh measurement | Result | Verdict |
|---|---|---|---|---|
| 1 | P1: `schemas/retro-template.md`'s Release data row must agree with `skills/retrospective/SKILL.md` Phase 2's `Changed non-test lines` wording | `sed -n '15,17p' schemas/retro-template.md`; `grep -n "Changed non-test lines" skills/retrospective/SKILL.md` | Template row reads `\| **Changed non-test lines** \| N (added + removed) \|`; SKILL.md Phase 2 cites the same bold term | Met |
| 2 | P2: ROADMAP's removed carry-forward row must be actually true, not just claimed | Consequence of #1 being Met; `grep -n "Diff-size metric reconciliation" ROADMAP.md` | No match — the original row stays correctly absent now that P1 is fixed | Met |
| 3 | P3: bold-citation convention applied in `lanes.md`/`SKILL.md`; `CONCEPTS.md` definition lowercase-started with explicit added+removed rule | `grep -n "Changed non-test lines" skills/reviewing/references/lanes.md skills/retrospective/SKILL.md`; `sed -n '29p' CONCEPTS.md` | Both citations bold; `CONCEPTS.md:29` reads `— the count of modified lines (added + removed) excluding tests, generated files, and lockfiles...` | Met |
| 4 | P4: `skills/planning/SKILL.md` needed an explicit USER approval gate for the draft→approved transition | `grep -n "## Entry / Exit / Gate" skills/planning/SKILL.md`; read the section and step 17 | Section present, states the USER gate and the two-separate-commits rule; step 17 reinforced with the same rule; `schemas/plan-schema.md:16` carries a one-line pointer comment | Met, with a caveat: this is **documented, not mechanically enforced** — no validator or hook rejects a plan committed directly as `status: approved`. A future author (human or agent) can still skip the gate exactly as this arc's own plan did. Not registered as a separate carry-forward item: this repo relies on documented convention over mechanical enforcement for process rules generally (e.g. the Assumption Recheck contradiction rule is also enforced by skill text, not tooling), so this is consistent with existing practice rather than a new gap — but it is worth stating plainly rather than claiming full closure. |
| 5 | New ROADMAP row registered for schema/skill-phase format drift is a genuine, trackable item, not a symbolic gesture | Compare its shape against the 3 pre-existing carry-forward rows and the Future Candidates table | All rows in both ROADMAP tables state only a directional trigger ("build it when the trigger fires"), never acceptance criteria or a regression fixture — `grep -c "fixture\|acceptance criteria\|regression test" ROADMAP.md` → 3 hits, all inside the *Future candidates* table's `Schema validators + fixtures` and `Conformance suite` rows describing *what would be built*, not a requirement on how carry-forward rows must themselves be written | Met, by this repo's own established convention — a facilitator probe suggested this made the row "unexecutable," but the repo's own non-goals framing ("not promises for a specific version... build it when the trigger fires") shows every row in both tables is written this way by design, not as a shortcut unique to this row |

## Carry-forward from previous retro

Previous retro: `docs/retros/2026-07-20-entirecontext-mention-removal-retro.md`.

| Item | Status | Evidence |
|---|---|---|
| Pin the tracked Python support contract in every non-fixture compatibility consumer | Not started | No commit in this cycle touched `scripts/release-publication.sh`; `rg -n 'PYTHON_SUPPORT_FILE' scripts/release-publication.sh` still finds no match |
| Diff-size metric reconciliation (previously reported "In progress, not attributable to this arc") | **Done** | `aa4a94c` (external) + `d01fd12`/`d93698a` (this session's review and P4 fix) closed it; fresh verification above, rows 1–3 |
| Clean-environment Codex install check | Not started, but see new finding below — a related-but-distinct live drift was observed this cycle on the *same* dev machine, not only in a hypothetical clean install | See Findings: "Process observations" |
| Automated numbered-reference validation for planning and plan schema | Not started | This cycle inserted an unnumbered `## Entry / Exit / Gate` section into `skills/planning/SKILL.md` *before* `## 1. Entry check`, not between numbered steps — `grep -n '^## ' skills/planning/SKILL.md` confirms `1.` through `18.` are unchanged and contiguous, so this cycle's own edit did not trigger the item, but the item itself remains unbuilt |

New item from the cycle before this one (schema/skill format drift) is not re-registered here — it was already pushed to `ROADMAP.md` in `57e1f1a`, part of this same session, before this retro was invoked.

## Findings

### What worked well

- **What happened**: Both changes in this cycle (the review file and the P4 fix) skipped `planning` entirely, and re-checking `skills/planning/SKILL.md` step 1's skip criteria against them after the fact confirms the skip was correct: neither had a scope boundary worth pinning in writing, neither had a Key Technical Decision the P4 fix's author needed to be told how to resolve (it copied an existing pattern from `designing`/`release`/`retrospective` verbatim), and neither needed upstream traceability.
  **Why**: The entry-check heuristic is meant to bias toward writing a plan but permit skipping genuinely atomic work; this cycle is a clean example of it correctly predicting a skip rather than being bypassed out of convenience.
  **How to apply**: Continue trusting the step-1 heuristic for small, precedent-following documentation fixes; don't manufacture a plan doc just because a prior cycle (the EntireContext arc) used one.
- **What happened**: When the external workflow's fix commit `aa4a94c` landed, every claim in it was re-measured fresh in this session rather than trusted from its own commit message ("Resolves P1 and P3 review findings") — the exact commands from the original review file's "Resolution" section were rerun against `HEAD`, not copied from the fix's own report.
  **Why**: `enforces: P3` — a claim of a fix is not evidence a fix landed correctly.
  **How to apply**: Keep re-running the original review's exact evidence commands after any externally-reported fix, in this repo and any other multi-agent workflow sharing a branch.

### What to improve

- **What happened**: The retro request in this session invoked the `retrospective` *skill* through the harness's skill-loading mechanism, and the loaded skill body was pulled from `~/.claude/skills/retrospective/SKILL.md` — which resolves via `~/.claude/skills` being a symlink to `~/.agents/skills` (a dot-agents cross-tool sync directory) — not from this repo's tracked `skills/retrospective/SKILL.md`. `stat` shows the synced copy was last written at `2026-07-20T11:06:47+09:00`, while the tracked repo file was last written at `2026-07-20T13:29:45+09:00` (the `aa4a94c`/`d93698a` edits). The loaded copy still contained the `EntireContext hooks` bullet this same session had already removed from the tracked file in an earlier, unrelated arc (`b37675f`, committed `11:43`), and still had the old `code delta split product/test/docs by path` Phase 2 wording this cycle just fixed.
  **Why**: dot-agents syncs a point-in-time snapshot into `~/.agents/skills/` rather than resolving live against a working repo checkout, so any repo-local skill edit is invisible to skill invocations until the next sync — and nothing surfaces that staleness to the invoking session.
  **How to apply**: This is a live, evidenced instance of the same risk class the existing "Clean-environment Codex install check" carry-forward item names for Codex, but broader: it affects the *same* dev machine mid-session, not only a fresh external install, and it affects Claude Code's `~/.claude/skills` path specifically. This retro's own accuracy did not suffer only because the acting session happened to already know the repo's true current skill content from earlier in the same conversation — a session without that prior context would have silently written a retro (or executed any skill) against stale instructions. Registering a new, narrower carry-forward item below.

### Process observations

- **What happened**: A facilitator probe (independent, fresh-context, heterogeneous model) suggested the P4 fix and the new ROADMAP row were both underspecified — P4 for lacking mechanical enforcement, the ROADMAP row for lacking acceptance criteria or a regression fixture.
  **Why**: Both critiques are individually reasonable asks, but checking them against this repo's actual established conventions (Success criteria table rows 4 and 5 above) shows P4's documentation-over-enforcement approach and the new row's trigger-only format both match how this repo already treats every comparable case — accepting the critique without checking would have added scope-creep enforcement machinery this repo doesn't use anywhere else.
  **How to apply**: A facilitator probe is a starting question, not an automatic finding — verify it against the repo's own existing conventions before accepting or rejecting it, the same discipline `superpowers:receiving-code-review` applies to human/bot review feedback.

## Carry-forward items registered

| Item | Type | Priority | Tracked at |
|---|---|---|---|
| Locally-invoked skills can silently diverge from the repo's tracked `skills/<name>/SKILL.md`: `~/.claude/skills` → `~/.agents/skills` (dot-agents sync) holds a point-in-time snapshot, not a live view, so an in-session edit to a repo skill is invisible to skill invocations until the next sync — observed directly this session against `skills/retrospective/SKILL.md` | process | P2 | `ROADMAP.md` "Carry-forward from retros" |

## Lessons

- A skill invocation can silently execute stale instructions on the very machine that just edited the skill's own source file, with no signal to the invoking session that the two have diverged — trusting "the skill loaded" is not the same as trusting "the skill matches the repo."
- A facilitator's critique is a probe to verify, not a finding to inherit — checking two independent critiques (enforcement mechanism, acceptance criteria) against this repo's own established conventions correctly declined both without dismissing the probes as noise.

## Compounding

- compound invocation: attempted, `mode:headless`, qualifying finding: the stale locally-invoked skill divergence (dot-agents sync snapshot vs. live repo tracked file), passed as context to `compound`.
