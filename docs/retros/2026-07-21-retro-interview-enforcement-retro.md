# Retro: retro-interview-enforcement

- Date: 2026-07-21
- Source: PR-merge mode — local no-ff merge `9d2d9c4` to `main`, pushed (`d79aafc..9d2d9c4`); no GitHub PR exists for this cycle
- Spec: docs/specs/2026-07-20-retro-interview-enforcement-design.md
- Plan: docs/plans/2026-07-20-002-feat-retro-interview-enforcement-plan.md

## Release data

| Metric | Value |
|---|---|
| **Changed non-test lines** | 546 (538 added + 8 removed), measured over `5872802..28c087e`; the fixture harness `scripts/test-retro-format-drift.sh` (+254) is excluded as test |
| Commits | 13 (12 on branch `5872802..28c087e` + merge commit `9d2d9c4`) |
| Review rounds | 9 — six unit task reviews (U1–U5 one round each, U6 two rounds with errata), one final branch review (READY), one standalone pre-merge reviewing phase (5 lanes + Tier-3 validation + one fix round) |
| Comments (fixed / deferred) | 7 / 9 — reviewing phase validated 11 findings: 7 fixed (`cf1221e`; F2 via addendum 003 + `0116c46` + `a6e6e69`), 4 deferred to ROADMAP (`28c087e`); final-review minor triage: 12 accepted as-is, 5 deferred to ROADMAP |
| CI failures | 0 — no CI configured; `bash scripts/validate.sh` passed after every commit in the arc |
| Duration (first spec commit → merge) | ≈13h40m — `4ad305d` (spec draft) 2026-07-20T22:47+09:00 → `9d2d9c4` 2026-07-21T12:27+09:00 |
| Units planned / completed | 6 / 6 |

## Success criteria: measured vs declared

| # | Declared criterion | Measurement (command / rubric) | Measured result | Verdict |
|---|---|---|---|---|
| 1 | Template defines Interview Transcript section with independence level, rounds-used, T-ID table | `grep -c "Interview Transcript" schemas/retro-template.md`; `grep -c "Independence level"`; `grep -c "\| ID \|"` | 1 / 1 / 1 | Met |
| 2 | SKILL.md defines round contract and all four structural checks; R1–R5 locatable by section; no degradation rung named by tool | reviewer rubric, performed fresh this execution | R1 (Verdict authority ¶), R2 (Round contract ¶), R3 (Verbatim rule ¶), R4 (Independence-level recording ¶), R5 (Backward check, End-of-interview checks, Pre-commit check) all located; the newly added text names no tools | Met — with the documented scope caveat: the pre-existing Facilitator-model-selection sentence still names `codex exec`/Claude subagent per the spec's Scope Out (harness-tool naming removal was out of scope; preflight resolution recorded in the implementation ledger) |
| 3 | Tier 1 dry-run doc: every finding cites a T-ID or Phase 2–3 data | per-section count of `**What happened**:` vs `**Cites**:` in the run-1 embedded doc | run 1: 3 findings / 3 Cites; run 2: 2 / 2 | Met |
| 4 | Self-checklist dry-run doc shows `self-checklist` independence level | `grep -A2 "Independence level"` on the run-2 embedded doc | `- Independence level: self-checklist` present | Met |
| 5 | Negative injection caught before Phase 8 commit | dry-run 3 transcript inspection | `FAIL: uncited finding at line 19` recorded, finding dropped; no uncited finding in any final embedded doc | Met |
| 6 | No structural regression | `bash scripts/validate.sh` | exit 0, `ALL CHECKS PASSED` (fresh run this execution) | Met |

## Carry-forward from previous retro

Previous retro: `docs/retros/2026-07-20-diff-size-metric-review-and-planning-gate-retro.md`.

| Item | Status | Evidence |
|---|---|---|
| Locally-invoked skill divergence (dot-agents sync snapshot vs tracked skill file) — P2, registered by the previous retro | Done — resolved out of repo scope, not completed in-repo: removed from ROADMAP by explicit decision, underlying mechanism corrected and confirmed | `c63fbaf` (removal + rationale: only `./skills/` ships; the sync path is maintainer-personal environment), `16e712e` (fix confirmed working) (T3) |
| Retrospective interview protocol enforcement — P2 (ROADMAP row) | Done — scoped procedural mitigation per the row's own fix direction (a): skill text mandates the round-trip, structural checks distinguish `accepted` from `self-attested`; facilitator-authorship authentication remains the stated known limit (SKILL.md Known-limit ¶), and the Phase 8 check verifies transcript presence/shape, not authenticity | `0bf1f41`, `2491c62`, `707e86f`, merge `9d2d9c4`; dry runs 1–3 in `docs/reviews/2026-07-20-retro-interview-enforcement-dryrun-evidence.md`; this retro's own interview ran the shipped protocol (3 heterogeneous dispatches) (T1) |
| Structural check for schema/skill format drift — P3 (ROADMAP row) | Done | `8d1ad21` (harness red), `707e86f` (check 9), `cf1221e` (Case F), `0116c46`+`a6e6e69` (Case G per addendum 003); fresh runs this execution: `validate.sh` exit 0, harness ALL CASES PASSED (7 cases) (T2) |
| Clean-environment Codex install check — P3 | Not started | no clean-machine install occurred this cycle; `git log 5872802..28c087e -- .codex-plugin .claude-plugin` is empty (no plugin-manifest edits to re-test) |
| Automated numbered-reference validation for planning/plan schema — P3 | Not started | `git log 5872802..28c087e -- skills/planning schemas/plan-schema.md` is empty — trigger did not fire |
| Pin Python support contract in non-fixture consumers — P3 | Not started | `rg -c 'PYTHON_SUPPORT_FILE' scripts/release-publication.sh` → no match; no publication-harness edit this cycle |

The three rows registered mid-cycle by the pre-merge reviewing phase (protocol
vocabulary gaps, check 9/harness coverage, check-5 traceback) are not
re-registered here — they were already pushed to `ROADMAP.md` in `28c087e`
before this retro was invoked.

- Previous doc shape: pre-schema, exempt

(the previous retro was committed 2026-07-20T13:58+09:00, before the
transcript schema landed in `2491c62` the same evening)

## Interview Transcript

- Independence level: heterogeneous (facilitator: GPT-family via `codex exec -s read-only`, stateless one-shot dispatches, artifacts only — no working-conversation access)
- Rounds used: 3 (max 5)

| ID | Round | Phase | Probe | Answer | Evidence | Verdict (verbatim) |
|---|---|---|---|---|---|---|
| T1 | 1→3 | 4 | Which commits and dry-run artifacts prove the original facilitator-round-trip failure is closed despite the documented fabrication limit — satisfied, not merely documented? | Round 2: four shipped boundaries (verdict authority, findings check proven by dry run 3, pre-commit check, backward check); rejected — no artifact authenticates facilitator-authored acceptance, and Phase 8 permits a zero-row transcript. Round 3: conceded; adopted the facilitator's classification — the row closes as a scoped procedural mitigation per its own fix direction (a), with the fabrication limit and presence-not-authenticity boundary stated in the reconciliation row | `0bf1f41`, `2491c62`, `707e86f`, dry-run evidence doc Run 3, SKILL.md Known-limit ¶ | accepted |
| T2 | 1→2 | 4 | Which commits and fixtures prove check 9 covers the promised template-to-consumer drift, and why do the remaining follow-ups not keep the row open? | Cases A–G each mutate one drift class in a disposable mktemp copy with named FAIL assertions; the row's trigger ("next schemas/*.md shape change adds a check") fired and was satisfied in the same cycle (`2491c62` shape change + `707e86f` check); follow-ups F11/F12/U5-m2 harden the checker's own guard branches, not the promised drift detection | `8d1ad21`, `707e86f`, `cf1221e`, `0116c46`, `a6e6e69`; fresh harness run ALL CASES PASSED | accepted |
| T3 | 1→2 | 4 | What concrete evidence justified removing the dot-agents P2 item rather than completing it, and how does this retro account for that without claiming Done or silently dropping? | `16e712e` confirmed the underlying fix works; `c63fbaf` removed the row with the recorded rationale that only `./skills/` ships and the sync path is maintainer-personal environment; this doc's reconciliation row carries "resolved out of repo scope" with both commits | `c63fbaf`, `16e712e` | accepted |
| T4 | 1→2 | 5 | What did the plan or its review process fail to see in the architecture-note/U5 contradiction, and which concrete event exposed it? | Both the plan's independent review (`d6811b5`, 9 findings) and the implementing preflight scan validated units against the spec but never diffed the plan's own summary prose against its step contracts clause-against-clause; the adversarial lane's mktemp co-rename fixture returned exit 0 and proved the blind spot (F2), escalated per implementing rule 7, resolved by user decision into addendum 003 + `0116c46` red → `a6e6e69` green | `06a9ddc`, `0116c46`, `a6e6e69`, addendum 003 | accepted |
| T5 | 1→3 | 5 | How did run 2's missing `(T1)` citation pass the recorded checks, what caught it, and where did the enforcement boundary actually fail? | Round 2: claimed the recorded pass exercised the artifact-evidence clause; rejected — erratum 4 states no executed-check record names the carry-forward check. Round 3: correction adopted — the entire carry-forward check was omitted from every dry run's executed-checks record; only the findings check has execution records (runs 1 and 3); the omission was caught by U6 task review (U6-m1) and committed as erratum 4 in `cf1221e` | dry-run evidence doc erratum 4, run-2 embedded doc (unedited, `(T1)` still absent), `cf1221e` | accepted |

Verdict cell values: `accepted` | `no evidenced answer (3 rejections): <verbatim>` | `self-attested`

Round-2 non-terminal rejections (P1, P5) are round outputs, not transcript
verdicts, per the Round contract; their substance is preserved in the Answer
cells above and the final facilitator verdicts are recorded verbatim.

## Findings

### What worked well

- **What happened**: On its first live run, the shipped protocol did the job it was built for: the heterogeneous facilitator rejected 2 of 5 respondent answers with evidence-demanding re-probes, and the P5 rejection exposed a factual error in the respondent's own account — the claim that the dry runs' recorded checks had exercised the carry-forward check's first clause contradicted erratum 4, which the facilitator had read and the respondent had written.
  **Why**: A fresh-context, different-family model verified the cited artifacts in-repo (round 2 ran git and file reads) instead of inheriting the respondent's narrative — exactly the shared-blind-spot defense the spec argued heterogeneity buys.
  **How to apply**: Keep heterogeneous as the default facilitator tier when the environment offers one, and budget at least 3 dispatches — both rejected exchanges needed the third round to converge.
  **Cites**: T1, T5
- **What happened**: The F2 arc turned a latent plan self-contradiction into a governed fix: the adversarial lane proved the check-9 blind spot by fixture (co-rename returned exit 0), the finding was escalated as a plan-mandated conflict rather than silently patched, the user chose the architecture-note arm, and the fix landed as addendum 003 plus a red-then-green fixture case.
  **Why**: Fixture proof made the blind spot undeniable and cheap to adjudicate, and the implementing skill's rule 7 routed the plan conflict to the human instead of letting either arm win by default.
  **How to apply**: When a review finding implies a check is incomplete, reproduce the miss by fixture before proposing the extension — the fixture then becomes the regression case (Case G) for free.
  **Cites**: T4

### What to improve

- **What happened**: Of the two end-of-interview checks shipped together, only the findings check has any execution evidence — dry runs 1 and 3 record it firing (PASS and FAIL respectively), while no run's executed-checks record names the carry-forward check at all, and its probed-row→T-ID clause exists only as skill prose with no structural assertion behind it.
  **Why**: The dry runs were designed around the findings check's scenarios (S1, S4, S5); nothing forced the carry-forward check to leave an execution trace, and an unexercised check is invisible until its violation ships.
  **How to apply**: This retro executed both checks and records that execution in its commit message (first durable execution evidence for the carry-forward check); the remaining structural-assertion gap is registered as a carry-forward item below.
  **Cites**: T5
- **What happened**: The plan's architecture note and its U5 step contradicted each other from the draft onward ("asserts the two skill files agree" vs level assertions scoped to SKILL.md only), and three layers — planning self-review, the independent plan review (`d6811b5`), and the implementing preflight contradiction scan — all missed it because none diffs a plan's summary prose against its unit step contracts.
  **Why**: Each layer checked plan-against-spec or unit-against-unit; clause-against-clause consistency inside the same document belonged to nobody.
  **How to apply**: Registered as a carry-forward item below: the planning self-review and the implementing preflight scan should each name architecture-note-vs-unit-step agreement as an explicit check.
  **Cites**: T4
- **What happened**: The respondent's first Done claims overreached and needed facilitator pushback to scope honestly — T1's round-2 answer presented the interview-enforcement row as closed on the strength of four boundaries, and the accepted resolution required reclassifying it as a scoped procedural mitigation with the fabrication limit and the presence-not-authenticity boundary stated in the reconciliation row.
  **Why**: A Done cell invites unqualified claims; the delivered boundary was real but narrower than the unqualified word.
  **How to apply**: When reconciliation marks a row Done for work whose enforcement is procedural, the Evidence cell must name the residual limit, not only the delivering commits.
  **Cites**: T1

### Process observations

- **What happened**: Respondent-sourced numbers failed three separate times across this cycle — "10 MinorFindings" survived a facilitator-accepted verdict when the ledger itemized 12 (erratum 1), and "8 commits behind" appeared three times when the doc's own endpoints give 7 (erratum 3) — and each instance was caught by a different independent layer (U6 task review; the reviewing phase's correctness lane), never by the author who wrote the number.
  **Why**: Facilitator acceptance verifies structure and citations, not arithmetic — the known limit the skill text states, demonstrated live twice in one cycle.
  **How to apply**: Any count in a retro or evidence doc gets its producing command inline (as this doc's Release data table does), so a reviewer can re-run rather than re-trust.
  **Cites**: Phase 2 data (dry-run evidence doc errata 1 and 3)
- **What happened**: The interview consumed 3 of 5 dispatches; the third dispatch's verdicts were recovered from the codex session rollout file after the live output was mis-captured, avoiding a wasted fourth dispatch.
  **Why**: Stateless dispatches leave complete rollout records, which makes the dispatch cap resilient to orchestrator-side capture mistakes.
  **How to apply**: On a mis-captured facilitator response, check the dispatch tool's session log before re-dispatching — a re-run costs a cap slot, a log read costs nothing.
  **Cites**: T1–T5 (rounds-used count)

## Carry-forward items registered

| Item | Type | Priority | Tracked at |
|---|---|---|---|
| Carry-forward check has no structural assertion and had zero execution evidence across all three dry runs (erratum 4): the probed-row→T-ID clause is prose-only; this retro's commit records the first execution, but nothing mechanical fails a doc whose probed rows lack `(T<n>)` citations | process | P3 | `ROADMAP.md` "Carry-forward from retros" |
| Plan internal clause-consistency check: planning self-review, independent plan review, and implementing preflight all validate against the spec or across units, but none diffs a plan's architecture-note prose against its unit step contracts — the F2 contradiction survived all three | process | P3 | `ROADMAP.md` "Carry-forward from retros" |

## Lessons

- On its first live run the heterogeneous facilitator rejected 2 of 5 self-assessments — including one already disproven by the respondent's own committed errata — and both corrections made the retro more accurate than the respondent's first draft.
- A structural check with no execution record is indistinguishable from an unbuilt one: across three dry runs, only the findings check ever demonstrably fired, and the carry-forward check shipped with zero execution evidence.
- Unverified counts are the recurring failure mode facilitator acceptance cannot stop: three independent layers each caught a fresh instance (12-not-10, 7-not-8) that had already survived an accepted verdict or an errata pass.

## Compounding

- compound invocation: attempted, `mode:headless`, qualifying finding: the execution-evidence asymmetry between the two end-of-interview checks (T5). Returned signal: `Documentation complete — docs/solutions/workflow-issues/structural-check-without-execution-evidence.md`. Compound's headless report also noted: no CONCEPTS.md term qualified (conservative bar), no discoverability edit (no repo-tracked instruction file; the lifecycle skills themselves point at docs/solutions/), and a scoped `compound-refresh` recommendation for `docs/solutions/workflow-issues/` (moderate-family overlap with `spec-review-empirical-grounding-gap.md`).
