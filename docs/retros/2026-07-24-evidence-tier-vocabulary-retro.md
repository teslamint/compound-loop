# Retro: evidence-tier vocabulary

- Date: 2026-07-24
- Source: PR none — local no-ff merge `33e8bc6` (repo convention), release-loop cycle
- Spec: docs/specs/2026-07-23-evidence-tier-vocabulary-design.md
- Plan: docs/plans/2026-07-23-001-feat-evidence-tier-vocabulary-plan.md

## Release data

| Metric | Value |
|---|---|
| **Changed non-test lines** | 437 (440 added + 3 removed, minus none excluded; no tests, generated files, or lockfiles in scope — 45/3 of these in shipped skill/schema/glossary files, the rest spec+plan docs) |
| Commits | 11 (10 branch + 1 merge) |
| Review rounds | 7 (1 spec review + 1 plan review + 4 unit task reviews + 1 final branch review), 0 fix rounds post-implementation |
| Comments (fixed / deferred) | 15 / 2 (9 spec-review + 6 plan-review findings incorporated; 2 Minor findings carried: U2-m1, U3-m1) |
| CI failures | 0 (no CI; local-merge convention, verification via `scripts/validate.sh`) |
| Duration (first spec commit → merge) | ~0.8 days (2026-07-23 12:49 → 2026-07-24 08:28) |
| Units planned / completed | 4 / 4 |

## Success criteria: measured vs declared

One row per criterion from the spec's Success Criteria section. The measurement is run FRESH
during the retro (enforces: P3) — a prior claim in a commit message or PR body is not evidence.
The Measured result cell uses the binary completion report form — `verified: <observation>` or
`unverified: <blocker>` — and for rubric-measured criteria it reports evidence acquisition
(rubric applied, reading cited), never the Verdict itself.

| # | Declared criterion | Measurement (command / rubric) | Measured result | Verdict |
|---|---|---|---|---|
| 1 | `CONCEPTS.md` contains a `## Completion evidence` section defining the five R1 terms | `rg -n "^## Completion evidence" CONCEPTS.md && rg -o -e "Evidence tier\b" -e "Evidence-tier ladder" -e "Claim layer" -e "Layer-mismatch" -e "Binary completion report" CONCEPTS.md \| sort -u \| wc -l` | verified: heading at CONCEPTS.md:41; distinct-term count 5 (tier-free — structural grep of a docs deliverable) | Met |
| 2 | Ladder in exact declared order with the typecheck rule | judgment rubric: read the `## Completion evidence` section | verified: rubric applied — CONCEPTS.md:41–47 read; the five tiers appear on line 44 in R2's descending order; "Typecheck/build alone never closes a completion claim." present verbatim | Met |
| 3 | Each consumer carries an executable rule referencing the canonical terms | `rg -l "layer-mismatch\|Layer-mismatch" skills/reviewing/SKILL.md && rg -l "evidence-tier ladder\|Evidence-tier ladder" skills/shipping/references/verification.md && rg -l "verified:" skills/retrospective/SKILL.md` | verified: all three files matched (tier-free — structural grep) | Met |
| 4 | `reviewing`'s rule blocks `clean` on a standing layer-mismatch finding | judgment rubric: read the added rule in `skills/reviewing/SKILL.md` | verified: rubric applied — line 90 read; states "the verdict cannot be `clean` while it stands," same normative shape as the adjacent Requirements Completeness rule, with the undecidable-layer fallback and suppression pass-through | Met |
| 5 | Binary form binds only the three structured points, not prose | judgment rubric: read R4–R6's landed rules | verified: rubric applied — reviewing SKILL.md:90 ("binds findings and verdicts (structured output), not the reviewer's surrounding prose"); verification.md:46 ("Exactly two surfaces are bound to this form") + :58 (Steps 4/6/7 narration exemption); retrospective SKILL.md:42 ("binds Measured result cells only, not the doc's narrative prose") | Met |
| 6 | Traceability: every survey import-2 mechanism present with citation or on an explicit drop-list | judgment rubric: walk the survey's import-2 sentence clause by clause against the landed diff | verified: rubric applied — `.release-loop/reports/traceability.md` six rows walked against `docs/research/ultraprompt-survey.md:32–37` and the landed files; rows 1–4/6 cite branch edits, row 5 (hedges-banned) cites the pre-existing unchanged red-flag list with the reuse rationale stated; zero silent omissions | Met |
| 7 | Structural validation passes on the final tree | `bash scripts/validate.sh` | verified: ALL CHECKS PASSED (fresh this retro, post-merge on `33e8bc6`; tier-free — structural validation) | Met |

## Carry-forward from previous retro

| Item | Status | Evidence |
|---|---|---|
| Release headless-path `.release/draft.md` non-authorization marker (U4-m1) | Not started — trigger ("next design cycle touching release's draft contract or the marker invariant") did not fire: branch diff `ee70f03..33e8bc6` touches 8 files, none under `skills/release/` | `git diff --stat ee70f03..33e8bc6`; ROADMAP row retained (T1) |
| `final_action` record polish (N-1 marker/note slot, N-2 predicted→determined Log clause) | Not started — trigger ("next edit to `progress-schema.md` or release-loop Gate handling") did not fire for the edit clause; but this cycle's live record again carried the out-of-schema `note:` field, the same N-1 recurrence | branch diff (neither file edited); live `.release-loop/progress.md` `note:` field (T1) |
| Define "hand-up packet" locally in `skills/shipping/SKILL.md` | Not started — **trigger fired unnoticed**: U3 (`2299955`) edited shipping SKILL.md (Step 1 pointer), satisfying "next shipping SKILL edit"; the planning Retro-carryover check matched on feature-relevance, not on the row's edit-based trigger; caught only at this retro | `2299955`; plan Deferred section (three items, not this row) (T1) |
| Mechanical `scripts/validate.sh` check for `final_action` shape | Not started — **trigger fired under the strict reading**: the recurring out-of-schema `note:` field in a real record is observed shape drift (N-1's own observation, now in its second consecutive cycle); the check remains unbuilt | live `.release-loop/progress.md` `note:` field vs `progress-schema.md` 4-field block (T1) |
| Carry-forward check structural assertion (probed-row→T-ID linkage prose-only) — continued from the previous retro's own table | Not started — **trigger fired under the strict reading**: U4 (`503da9b`) edited `schemas/retro-template.md`, a retro-template design cycle, but only the measured-vs-declared example row; the T-ID linkage sections and check 9 vocabulary were untouched and the assertion was not folded in | `503da9b` diff (measured-table hunk only); `bash scripts/validate.sh` check 9 green (T1) |
| Plan internal clause-consistency check — continued from the previous retro's own table | In progress — trigger fired a second consecutive cycle (this plan's Architecture notes summarize unit behavior); satisfied procedurally again: the plan-review dispatch carried the mandated architecture-notes-vs-unit-steps diff and returned P1-1, fixed `3c7f308`; mechanical check still absent, row stays open | `3c7f308`; plan-review record in `.release-loop/progress.md` (T3) |

- Previous doc shape: conformant

## Interview Transcript

- Independence level: heterogeneous (facilitator: GPT-family via `codex exec -s read-only`, stateless one-shot dispatches, artifacts only — no working-conversation access; round 4 only: degraded to same-model fresh-context subagent after the GPT facilitator stalled twice with zero output — T1's final verdict carries that provenance)
- Rounds used: 4 (max 5)

| ID | Round | Phase | Probe | Answer | Evidence | Verdict (verbatim) |
|---|---|---|---|---|---|---|
| T1 | 1→4 | 4 | Classify all four rows from the 2026-07-22 retro as Done, Carry forward, or Obsolete with a commit or file:line citation and trigger event for each, explicitly explaining why the "hand-up packet" item remained unaddressed after U3 commit `2299955` edited `skills/shipping/SKILL.md` | Rejected twice before acceptance: round 2 softened ROADMAP:47 to "grazed" and ROADMAP:55 to no-drift (rejected: "ROADMAP:47 fired when U4 edited `schemas/retro-template.md`, while the recurring out-of-schema `note:` field also defeats the claimed no-drift basis for ROADMAP:55"); round 3 counted three fired triggers and claimed ROADMAP registration before it existed (rejected: "ROADMAP:48 is a fourth fired trigger, and ROADMAP.md lacks the claimed new P2 audit row"). Final: FOUR of six live rows fired — three unnoticed until retro (hand-up packet via `2299955`; structural assertion via `503da9b`; final_action shape via the recurring `note:` field) and one handled procedurally in-cycle (clause-consistency, P1-1 fixed `3c7f308`); unfired: release-draft marker, final_action polish. The three new rows were registered in ROADMAP.md before the final verdict | carry-forward table above; `2299955`; `503da9b`; live progress.md `note:` field; ROADMAP.md new rows | accepted |
| T2 | 1→2 | 5 | What exact defect made the spec's escaped-pipe `rg` assumption check vacuously pass, where was it corrected in commit `ad4b9c2`, and what concrete review rule or executable check would prevent the same false evidence pattern? | The draft recorded assumption row 3's command with markdown-escaped pipes (`\|`) inside a table cell; run literally, rg matched the literal string "evidence tier\|ladder\|layer" — nowhere present — producing a vacuous "No matches" while `skills/reviewing/SKILL.md:65` really contains "Degradation ladder"/"Model tiering". The independent spec review's mandated empirical-grounding rerun falsified it; `ad4b9c2` rewrote the command with repeated `-e` flags, recorded the line-65 hit fresh, and narrowed the claim. Prevention adopted: repeated `-e` flags in all table-cell commands so source and rendered forms agree | `287e9fe` vs `ad4b9c2` assumption row 3; spec-review report ("FALSIFIED: A3"); docs/solutions/workflow-issues/spec-review-empirical-grounding-gap.md | accepted |
| T3 | 1→2 | 5 | Using the draft-plan state at `7731b86`, the correction at `3c7f308`, and exact plan file:line citations, show how the mandated architecture-notes-versus-unit-steps diff exposed the definitions-only versus shipped-ladder contradiction and whether that evidence closes or merely validates the related ROADMAP carry-forward | Draft Architecture note asserted "No consumer restates a definition" and S4 asserted a definition-exactly-once grep, while U3 step 1 instructed reproducing R2/R3 ladder content into verification.md. The plan-review dispatch carried the previous retro's carry-forward as a mandatory clause-diff instruction and returned P1-1 naming both sides plus the spec's own R5-vs-Architecture tension as root. `3c7f308` rewrote the note with an explicit R5-cited carve-out (skills ship without CONCEPTS.md; definitional bullet form stays only there) and replaced S4 with a decidable bullet-form grep. This validates ROADMAP:48 a second time but does not close it — both firings were satisfied by a hand-written prompt instruction, and the row asks for a mechanical check | `7731b86`; `3c7f308`; plan Architecture notes + S4 row; ROADMAP:48 (T3 row above) | accepted |
| T4 | 1→3 | 5 | Cite the commit and exact `skills/retrospective/SKILL.md` and `schemas/retro-template.md` lines proving this retro is the first execution of the newly merged binary measured-result rule, then name one concrete ambiguity, friction event, or successful behavior observed while applying that rule to its own originating cycle | Round-2 answer cited measured-table cells that existed only in conversation; facilitator rejected for lack of a durable artifact. Revised with durable evidence: U4 (`503da9b`) changed SKILL.md:42 and retro-template.md:29–30,35; merge `33e8bc6` landed 08:28:38 and progress.md's retro-entry line follows the 08:28:39 ship line, so the rule predates this retro's Phase 3; the measured table in THIS committed doc is the first artifact written under it. Observation now durable in that table: all three command-measured criteria (SC1, SC3, SC7) are tier-free — first live evidence that tier-free is the common case for docs-only work, the exact case the spec-review P1-5a rule anticipated; the four rubric-measured rows exercised the evidence-acquisition clause without ambiguity | `503da9b`; `33e8bc6`; progress.md ship/retro log ordering; the measured table in this doc | accepted |
| T5 | 1→2 | 5 | For U2-m1 and U3-m1, cite each landed file:line and the review event that classified it Minor, then justify Carry rather than Fix or Drop with a specific downstream failure mode, trigger, and owner rather than "readability" or "polish" alone | U2-m1: reviewing SKILL.md:90 parenthetical omits "claim layer" though "the claim's layer" is load-bearing; Minor per U2 task review; CARRY per final branch review because the text is verbatim plan-conformant and the term resolves through the layer-mismatch definition. Failure mode: a host-repo reader looks up the two named terms, misses that claim layer is canonically defined, and mis-derives the layer by intuition — comprehension risk, no behavioral drift. Trigger/owner: next planning cycle editing reviewing Step 8. U3-m1: verification.md:37 awkward subject ("it" = the ladder); Minor per U3 task review; CARRY because the binding rule is restated unambiguously at :51. Failure mode: a shipper reading only the ladder section briefly misattributes the naming obligation, recovered two sections later. Trigger/owner: next cycle editing shipping references | U2/U3 task-review reports; final-branch-review triage; reviewing SKILL.md:90; verification.md:37, :51 | accepted |

Verdict cell values: `accepted` | `no evidenced answer (3 rejections): <verbatim>` | `self-attested`

## Findings

### What worked well

- **What happened**: The carry-forward-as-review-instruction pattern fired for the second consecutive cycle and caught a real P1: the plan-review dispatch carried the clause-consistency row as a mandatory architecture-notes-vs-unit-steps diff, which exposed the draft plan's "no consumer restates a definition" contradicting U3's spec-mandated ladder reproduction, resolved as an explicit R5 carve-out before approval.
  **Why**: An open process row converted into a verbatim dispatch instruction is executable today, unlike the mechanical check it awaits.
  **How to apply**: Keep carrying open process rows into review-dispatch prompts verbatim until their mechanical check exists.
  **Cites**: T3; `3c7f308`.
- **What happened**: The independent spec review's empirical-grounding rerun falsified a retained assumption whose recorded evidence was vacuous — the markdown-escaped `rg` pattern had matched nothing by construction, and the rerun surfaced the real line-65 hit.
  **Why**: Rerunning the retained command is a different check from reviewing its logic; the escape defect was invisible to reading and obvious to execution.
  **How to apply**: Record table-cell commands with repeated `-e` flags (source equals rendered form), and never accept a retained assumption without the reviewer's own rerun.
  **Cites**: T2; `ad4b9c2`.
- **What happened**: The cycle dogfooded its own deliverable end to end: shipping's Step 1 gate report and progress.md ship log used the binary form landed by U3, and this retro's measured table is the first written under U4's rule — with the doc itself as the durable first-execution artifact.
  **Why**: The loop's phases consume the same skills the branch edits, so a same-session application doubles as the first integration test.
  **How to apply**: When a cycle ships a process rule the current loop can already obey, apply it in the same session and let the resulting artifact be the execution evidence.
  **Cites**: T4; progress.md ship log 2026-07-24T00:53:25; the measured table above.

### What to improve

- **What happened**: Four of six live carry-forward rows had their triggers fire this cycle, three of them unnoticed at planning time — the hand-up-packet row (U3's shipping-SKILL edit), the structural-assertion row (U4's retro-template edit), and the final_action-shape row (the recurring out-of-schema `note:` field) — caught only by this retro's reconciliation, two of them only after the facilitator rejected the respondent's softer reading; the fourth (clause-consistency) fired and was handled procedurally in-cycle.
  **Why**: The planning self-review's Retro-carryover check asks "does a prior item belong in this plan?" — a feature-relevance question — while these rows' triggers are edit-based or drift-based conditions that fire on file paths and record shapes regardless of feature relevance.
  **How to apply**: When planning maps its File structure, diff the file list against every open carry-forward row's trigger condition — an edit-triggered row whose file appears in the plan fires at planning time, not at retro time.
  **Cites**: T1; `2299955`; `503da9b`.
- **What happened**: The spec carried an internal tension from its own dialogue decisions — Architecture's "no skill re-defines a term" vs R5's "verification.md gains the evidence-tier ladder" — which the spec's independent review did not flag; it surfaced only when the plan tried to satisfy both and the plan review's mandated clause-diff caught the collision (P1-1).
  **Why**: The spec review checked internal consistency of requirement statements but not the composability of an architecture principle with a requirement's mandated mechanism; the plan is where the two first had to coexist in one instruction.
  **How to apply**: When a spec pairs a universal principle with a requirement that mandates an apparent exception, resolve the pair in the spec (name the carve-out there) instead of leaving the reconciliation to planning.
  **Cites**: T3; spec Architecture section vs R5.

### Process observations

- **What happened**: The heterogeneous facilitator rejected 2 of 5 round-2 answers — P1 for misclassifying two fired triggers the respondent had softened to "grazed"/"no drift", and P4 for citing evidence that existed only in conversation — and both rejections changed the doc: stricter carry-forward statuses and a durable-artifact-first evidence rule for T4.
  **Why**: A fresh-context facilitator reads trigger conditions and artifact existence literally, without the respondent's investment in the cycle's tidiness.
  **How to apply**: Treat facilitator rejections as classification corrections to adopt, not objections to argue down — the reject-revise loop is where the retro's honesty gets bought.
  **Cites**: T1; T4.

## Carry-forward items registered

| Item | Type | Priority | Tracked at |
|---|---|---|---|
| Planning-time trigger audit: when planning writes its File structure section, diff the planned file list (and any known record-shape drift) against every open carry-forward row's trigger condition, folding fired rows into the plan or its Deferred section with a reason — three edit/drift-triggered rows fired unnoticed this cycle | process | P2 | ROADMAP.md "Carry-forward from retros" |
| Vocabulary polish batch: add "claim layer" to reviewing SKILL.md:90's parenthetical (U2-m1) and rephrase verification.md:37's "it names the tier cited" subject (U3-m1) — batch into the next cycle that edits either file | process | P4 | ROADMAP.md "Carry-forward from retros" |
| Spec-level carve-out rule: when a spec pairs a universal principle with a requirement mandating an apparent exception, the spec itself names the carve-out — surfaced by the R5-vs-Architecture tension reaching planning unresolved | process | P3 | ROADMAP.md "Carry-forward from retros" |

## Lessons

- An edit-based carry-forward trigger fires on file paths, not on feature relevance — three open rows fired unnoticed in one cycle because planning asked "does this item belong to my feature?" while the triggers asked "does my plan touch this file?"
- A retained assumption's evidence is only as good as the command that produced it: a markdown-escaped pipe made a grep vacuously pass, and only the reviewer's mandated rerun — not two careful readings — caught it.

## Compounding

- compound invocation: `Documentation complete — docs/solutions/workflow-issues/carry-forward-trigger-planning-audit-gap.md` (T1 finding; frontmatter validated exit 0 on the boundary interpreter 3.9 — ambient python3 3.8 sits below the supported range and reproduces the known `list[str]` traceback; CONCEPTS scanned, no qualifying terms at the conservative creation-time bar — the edit-based/drift-based/event-based trigger classes deferred to a later run; discoverability already met; no refresh recommended, overlap Low)
