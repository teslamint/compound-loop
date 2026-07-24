# Retro: planning-trigger-audit

- Date: 2026-07-24
- Source: PR none — local no-ff merge `438e56b` (repo convention), release-loop cycle
- Spec: docs/specs/2026-07-24-planning-trigger-audit-design.md
- Plan: docs/plans/2026-07-24-001-feat-planning-trigger-audit-plan.md

## Release data

| Metric | Value |
|---|---|
| **Changed non-test lines** | 516 (513 added + 3 removed; no tests, generated files, or lockfiles in scope — 28 of these in shipped skill/schema/glossary files: CONCEPTS.md +7, plan-schema +5/−2, planning SKILL +16/−1; the rest spec+plan docs) |
| Commits | 10 (9 branch + 1 merge) |
| Review rounds | 6 (1 spec review + 1 plan review + 3 unit task reviews + 1 final branch review), 0 fix rounds post-implementation |
| Comments (fixed / deferred) | 14 / 2 (8 spec-review + 6 plan-review findings incorporated; 2 Minor carried: U2-m1, U3-m1) |
| CI failures | 0 (no CI; local-merge convention, verification via `scripts/validate.sh`) |
| Duration (first spec commit → merge) | ~1.6 hours (2026-07-24 18:21 → 19:58, same day) |
| Units planned / completed | 3 / 3 |

## Success criteria: measured vs declared

One row per criterion from the spec's Success Criteria section. The measurement is run FRESH
during the retro (enforces: P3) — a prior claim in a commit message or PR body is not evidence.
The Measured result cell uses the binary completion report form — `verified: <observation>` or
`unverified: <blocker>` — and for rubric-measured criteria it reports evidence acquisition
(rubric applied, reading cited), never the Verdict itself.

| # | Declared criterion | Measurement (command / rubric) | Measured result | Verdict |
|---|---|---|---|---|
| 1 | CONCEPTS.md defines the four trigger terms, each exactly once | four `rg -ci -F "**<Term>**" CONCEPTS.md` commands (per the plan-recorded case adaptation: `-i` added, U1 acceptance) | verified: counts 1/1/1/1 for Edit-based trigger, Drift-based trigger, Event-based trigger, Trigger audit (fresh post-merge; tier-free — structural grep of a docs deliverable) | Met |
| 2 | Planning skill contains the audit step covering all three classes, drift observability, latching, unclassifiable fallback, tiebreak | `rg -n -e "edit-based" -e "drift-based" -e "event-based" skills/planning/SKILL.md` + rubric (step executable literally against ROADMAP) | verified: hits only at lines 77/81 (step 5a) and 151 (step-14 bullet); rubric applied — final branch reviewer executed the 5a text literally against ROADMAP's table and reproduced the fired set (progress.md SC2 record); latching at :79, tiebreak at :77, unobservable/unclassifiable at :81 read fresh | Met |
| 3 | Fired-trigger disposition rule with both arms and blocking consequence stated | `rg -n "fired" skills/planning/SKILL.md` | verified: line 83 names fold-as-unit, Deferred-entry-with-reason, and "Silence on a fired trigger is a plan gap that blocks approval" (fresh read) | Met |
| 4 | Plan-schema hard floor carries the audit section with three record shapes, fixed template, exact fallback | `rg -n "Carry-forward trigger audit" schemas/plan-schema.md`; `rg -c -F` on the fallback and template strings | verified: item 8 at line 33; fallback line count 1; `Audited <tracker location>` template count 1 (fresh; tier-free — structural grep) | Met |
| 5 | Self-review re-runs the audit against the final file list; reviewer mandate requires re-derivation with blocking omitted-fired-row | `rg -n -e "final file list" -e "re-derive" skills/planning/SKILL.md` + rubric | verified: line 151 (final file list, attestation re-check) and line 87 (re-derives; "an omitted fired row is a blocking finding"; dispatch-prompt-verbatim clause) read fresh | Met |
| 6 | This cycle's own plan carries a conformant audit whose dispositions cover every fired row (file-list, observed state, or latched) | judgment rubric: walk ROADMAP open rows vs plan File structure, live progress.md, and fired-state annotations | verified: rubric applied — final branch reviewer independently re-derived the audit row-by-row and matched the plan's fired set {45,47,48,54,55,56,58} with attestation counts 15/7/0 (progress.md SC6 record); plan audit section at lines 133–153 re-read fresh this retro; ROADMAP untouched on the branch so the audited state `29602c5` remained current through merge | Met |
| 7 | Structural validation passes on the final tree | `bash scripts/validate.sh` | verified: ALL CHECKS PASSED (fresh this retro, post-merge on `438e56b`; tier-free — structural validation) | Met |

## Carry-forward from previous retro

| Item | Status | Evidence |
|---|---|---|
| Release headless-path `.release/draft.md` non-authorization marker | Not started — event trigger (design cycle touching release's draft contract) did not fire; branch `eb93cd8..438e56b` touches no release files | `git diff --stat eb93cd8..438e56b` (5 files, none under skills/release/) (T1) |
| `final_action` record polish (N-1 marker/note slot, N-2 Log clause) | Not started — edit trigger did not fire (`progress-schema.md` untouched); notably the N-1 recurrence stopped: this cycle's live record stayed schema-clean (4-field block, no `note:`) for the first cycle since registration | live `.release-loop/progress.md` final_action block; branch diff (T1) |
| Define "hand-up packet" in `skills/shipping/SKILL.md` | Not started — but the latched firing (`2299955`, prior cycle) was caught at planning time for the first time: plan audit row 54 (prior-retro arm) + explicit Deferred entry; previous two cycles caught it only at retro | plan audit section row 54; plan Deferred entry; ROADMAP:54 annotation (T1) |
| Mechanical `scripts/validate.sh` check for `final_action` shape | Not started — latched-fired (tracker arm) in the plan audit, deferred with reason (validate.sh outside approved scope; now twice-carried) | plan audit row 55; plan Deferred entry; ROADMAP:55 annotation (T1) |
| Carry-forward check structural assertion | Not started — latched-fired (prior-retro arm) in the plan audit, deferred with reason (retro-template/check 9 outside scope) | plan audit row 47; plan Deferred entry; ROADMAP:47 annotation (T1) |
| Plan internal clause-consistency check | In progress — trigger fired third consecutive cycle (U3 edits planning self-review); satisfied procedurally again: plan-review dispatch carried the mandated clause-diff, returned F3/F4 (incomplete cross-ref inventory; overbroad never-by-number claim), fixed `1df40a9`; mechanical check still absent | `1df40a9`; progress.md plan-review log (T1) |
| Planning-time trigger audit (previous retro's registered P2) | Done — the entire merged feature: CONCEPTS vocabulary, plan-schema hard-floor section, planning SKILL step 5a + extended self-review + reviewer mandate; ROADMAP row removed per Done rule | merge `438e56b`; ROADMAP carry-forward table (row removed) (T1) |
| Vocabulary polish batch (U2-m1 claim layer, U3-m1 verification.md subject) | Not started — edit trigger did not fire: neither `skills/reviewing/SKILL.md` nor `skills/shipping/references/verification.md` touched (plan audit non-fired set) | plan audit attestation; branch diff (T1) |
| Spec-level carve-out rule | Not started (durable `designing` rule unbuilt) — event trigger fired (this spec paired the gloss-boundary principle with R2's mandate) and was satisfied procedurally in-spec via the explicit carve-out sentence; plan audit recorded the firing with a Deferred disposition | spec Architecture gloss boundary; plan audit row 58; ROADMAP:58 annotation (T1) |

- Previous doc shape: conformant

## Interview Transcript

- Independence level: heterogeneous (facilitator: GPT-family via `codex exec -s read-only`, stateless one-shot dispatches, artifacts only — no working-conversation access; first dispatch attempt stalled on stdin and was re-issued with stdin closed, zero content rounds lost)
- Rounds used: 2 (max 5)

| ID | Round | Phase | Probe | Answer | Evidence | Verdict (verbatim) |
|---|---|---|---|---|---|---|
| T1 | 1 | 4 | Verify the respondent's nine draft carry-forward classifications against artifact evidence, reading trigger conditions literally without softening | The nine-row draft (6 previous-retro table rows + 3 registered items) as recorded in `.release-loop/retro-draft-materials.md`, each with commit/file citations | draft-materials Phase 4 section; ROADMAP.md; plan audit section; branch diff | accepted (row verdicts: "row 1: accepted" … "row 9: accepted", all nine) |
| T2 | 1→2 | 5 | For E1, provide the draft-plan commit and exact plan file:line citations showing the original five-row fired set, then commit `1df40a9` and exact file:line citations showing rows 47 and 54 added under the prior-retro latching arm | Draft `f6bceaf` audit table lines 74–78 list five fired rows, attestation "5 fired" at line 80; `1df40a9` adds row 47 at line 146 and row 54 at line 148 (both "Latching rule, prior-retro arm" citing the prior retro's reconciliation records), attestation corrected to "7 fired" at line 153; forcing event logged at progress.md:48 (reviewer re-derivation returned 7 vs 5) | `f6bceaf`; `1df40a9`; progress.md:48; docs/retros/2026-07-24-evidence-tier-vocabulary-retro.md:44,46 | accepted |
| T3 | 1→2 | 5 | For E2, provide the pre-correction spec criterion file:line, the exact CONCEPTS.md capitalization evidence, and the commit plus plan file:line where `-i` was adopted before approval; also cite the progress-log line recording the self-review event | Approved spec `29602c5` SC1 at git-show line 239 (case-sensitive lowercase `rg -c -F` commands); CONCEPTS.md:17 `**Backfill**` and :45 `**Claim layer**` prove the capitalized-bullet convention; adaptation recorded in draft plan `f6bceaf` U1 Acceptance (current line 93) with the prior cycle's `→`→`->` precedent named; self-review event logged at progress.md:47 (18:38:38, pre-commit) | `29602c5`; CONCEPTS.md:17,45; plan line 93; progress.md:47 | accepted |
| T4 | 1→2 | 5 | For E3, provide commit `2f10dd7` and exact before/after file:line evidence for each P1 correction: fixed attestation template, R2a latching rule, and the unobservable-drift record slot | `2f10dd7` diff: fixed template added at diff line 90 (replacing the draft's variable-content attestation, F1); R2a added at diff line 67 (F2, with live counterexample ROADMAP:55); unobservable row shape added at diff line 87 (F3 — R2's never-invent-verdict rule previously had no durable landing place) | `2f10dd7` vs `7d62a2a`; spec R5/R2a | accepted |
| T5 | 1→2 | 5 | For E4, provide three distinct artifact citations proving each dogfood execution: the plan's first audit table, the independent reviewer's seven-row re-derivation, and this retro reconciliation's consumption of the latched fired-state records | (1) plan lines 133–153 — first executed audit, run from the spec alone before U1–U3 existed; (2) progress.md:48 plan-review re-derivation + the final branch review's second independent re-derivation (SC6 record); (3) this retro's carry-forward rows for ROADMAP:47/54/55 reconcile via the plan's latched-fired audit rows and Deferred entries rather than fresh retro-time discovery — the first reconciliation to consume planning-time records | plan audit section; progress.md:48 and SC6 log; carry-forward table above | accepted |
| T6 | 1→2 | 5 | For E5, provide the exact progress-log file:line recording the `git ls-remote` timeout, the local ancestry and clean-tree evidence used for degradation, and the merge commit proving the local-only ship path completed without converting unavailable remote evidence into a verified claim | progress.md:57 records the 2m timeout with cause (Secretive require-auth key) and the degradation to local-only preflight; the same line carries the local evidence (main `eb93cd8` ancestor of HEAD `6d5df07`; validate.sh ALL CHECKS PASSED; `git status --short` empty); the remote state was logged as a timeout, never as verified; merge completed at progress.md:60 → `438e56b` | progress.md:57,60; `git log --oneline -1 438e56b` | accepted |

Verdict cell values: `accepted` | `no evidenced answer (3 rejections): <verbatim>` | `self-attested`

## Findings

### What worked well

- **What happened**: The spec's R6 re-derive mandate caught, on its very first execution, the record author's own omission: the draft plan's audit applied only the tracker-annotation arm of the latching rule (row 55) and missed the prior-retro arm (rows 47, 54) — the plan reviewer's independent re-derivation returned fired=7 against the draft's 5, a blocking P1 fixed before approval.
  **Why**: A re-derive mandate makes the reviewer recompute the record from source, so their result set can contain rows the author never wrote; a verify-the-claims review would have walked five correct rows and passed the section.
  **How to apply**: For any self-auditing record (audit, attestation, inventory, traceability walk), phrase the review mandate as recompute-then-diff, name the source of truth, and make an omission a blocking finding.
  **Cites**: T2; `f6bceaf` vs `1df40a9`.
- **What happened**: Planning's self-review caught the spec's SC1 measurement-convention conflict before the draft commit — CONCEPTS.md's capitalized-bullet convention would have made the spec's case-sensitive lowercase `rg` commands return 0 at retro time — and resolved it as a recorded file-convention adaptation with prior-cycle precedent. The analogous defect last cycle (a vacuous escaped-pipe command) survived until an independent reviewer's rerun.
  **Why**: The planner dry-ran the SC commands against the target file's actual conventions while authoring the acceptance criteria, one stage earlier than any reviewer.
  **How to apply**: When a spec declares exact measurement commands against a file, planning re-runs them against that file's live conventions before committing the plan, and records any adaptation next to the acceptance criteria it modifies.
  **Cites**: T3; progress.md:47.
- **What happened**: The cycle triple-dogfooded its own deliverable: the plan executed the first trigger audit from the spec alone (before the skill text existed), the plan review executed the first R6 re-derivation (catching the P1), and this retro's reconciliation is the first to consume planning-time latched-fired records instead of discovering firings fresh — three of nine carry-forward rows reconciled via the plan's audit.
  **Why**: The loop's phases consume the same skills the branch edits, so each phase after the spec became that mechanism's first integration test.
  **How to apply**: When a cycle ships a process mechanism the current loop can already exercise, run it in-cycle and let each phase's artifact stand as the mechanism's execution evidence.
  **Cites**: T5; plan lines 133–153; progress.md:48.

### What to improve

- **What happened**: The author of the two-armed latching rule (R2a, written hours earlier in the same session) applied only one arm when executing it — the tracker-annotation arm — and missed the prior-retro arm entirely, despite the previous retro's reconciliation records being the direct evidence base for two of the rows.
  **Why**: Working memory of a freshly written rule substitutes for reading its clauses; the author executed "check for fired annotations" as remembered, not as written.
  **How to apply**: When executing a multi-clause rule you just authored, walk it clause-by-clause from the text as a checklist — recency of authorship is a risk factor, not a protection.
  **Cites**: T2; spec R2a; `f6bceaf`.
- **What happened**: The ship-phase remote preflight (`git ls-remote`) hung for its full 2-minute timeout because the SSH agent's require-auth key demands user presence, and the pending request later left the signing agent unresponsive, stalling the retro's first commit attempt.
  **Why**: Network git operations route through the same Secretive agent as commit signing; an unanswered auth request blocks the agent's queue for subsequent operations.
  **How to apply**: In local-merge-convention repos, gate the remote reachability check behind a short explicit timeout (or skip it when the gate does not need remote state), and treat an agent-auth hang as a queue-blocking event — probe agent responsiveness before the next signing operation.
  **Cites**: T6; progress.md:57.

### Process observations

- **What happened**: The spec's independent review produced 3 P1s pre-approval, one of which (F2) cited a live counterexample from the repo's own tracker — ROADMAP:55's drifted record had been archived, so the spec's observability-based audit would have missed a row the tracker itself marks fired — and that finding became R2a, a shipped spec requirement.
  **Why**: A reviewer grounded in live repo state tests a spec's rules against real data, which turns review findings into requirements rather than wording fixes.
  **How to apply**: Give spec reviewers the live artifacts the spec's rules will operate on, and treat a rule that fails on a live example as a missing requirement, not a nitpick.
  **Cites**: T4; `2f10dd7`; ROADMAP:55.

## Carry-forward items registered

| Item | Type | Priority | Tracked at |
|---|---|---|---|
| Reword plan-schema audit-section provenance ("approved with this plan" → name the plan path) | process | P4 | ROADMAP.md "Carry-forward from retros" |
| Fix stale "item 1's deviation-addendum rule" numeric references (plan-schema:32, planning SKILL:120) | process | P4 | ROADMAP.md "Carry-forward from retros" |
| Retro-side trigger classification rule (classify trigger class before status at reconciliation) — registers the spec's Open Decision, owner satisfied | process | P3 | ROADMAP.md "Carry-forward from retros" |

## Lessons

- A re-derive mandate caught its own author on first execution: the writer of a two-armed rule applied one arm, and only the reviewer's recomputation from source — not a check of the recorded rows — could surface rows the author never wrote.
- A spec's exact measurement command can false-fail on the target file's conventions; the cheap catch is planning's dry-run of every SC command while authoring acceptance criteria, one stage before any reviewer reruns them.

## Compounding

- compound invocation: `Documentation complete — docs/solutions/workflow-issues/rederive-vs-verify-review-mandate.md` (T2 finding; frontmatter validated exit 0 on boundary interpreter 3.9 — ambient python3 3.8 sits below the supported range and reproduces the known `list[str]` traceback; overlap Moderate with spec-review-empirical-grounding-gap.md (same recompute-over-read principle, distinct scope: commands vs record completeness) — cross-referenced in the new doc, narrow consolidation of the recompute-family docs left as a later `compound-refresh` scope hint; CONCEPTS scanned, no qualifying terms at the conservative creation-time bar ("re-derive mandate" borderline, deferred); discoverability met via the lifecycle skills' own docs/solutions//CONCEPTS.md pointers, no edit)
