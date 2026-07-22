# Retro: final-action session resilience

- Date: 2026-07-22
- Source: PR none — local no-ff merge `7e68962` (repo convention), release-loop cycle
- Spec: docs/specs/2026-07-22-final-action-session-resilience-design.md
- Plan: docs/plans/2026-07-22-001-feat-final-action-session-resilience-plan.md

## Release data

| Metric | Value |
|---|---|
| **Changed non-test lines** | 478 (467 added + 11 removed; no tests, generated files, or lockfiles in scope) |
| Commits | 12 (11 branch + 1 merge) |
| Review rounds | 6 (4 unit task reviews + 1 final branch review + 1 phase-gate verification), 0 fix rounds |
| Comments (fixed / deferred) | 14 / 7 (10 spec-review + 4 plan-review findings incorporated; 7 Minor findings carried) |
| CI failures | 0 (no CI; local-merge convention, verification via `scripts/validate.sh`) |
| Duration (first spec commit → merge) | 0 days (same day, 08:31 → 11:26, ≈3h) |
| Units planned / completed | 4 / 4 |

## Success criteria: measured vs declared

| # | Declared criterion | Measurement (command / rubric) | Measured result | Verdict |
|---|---|---|---|---|
| 1 | Progress schema documents `final_action` with all three status values and the non-authorization rule | `grep -n "final_action"`; `grep -oE "predicted\|determined\|executed" \| sort -u \| wc -l`; `grep -in "not.*authorization\|never.*approval"` on progress-schema.md | Field at lines 28/62/63/64; unique-status count `3`; non-authorization matches at lines 27 and 64 | Met |
| 2 | release-loop declares the final action at startup and enforces prepare-before-gate in Gate handling | `grep -n "final_action" skills/release-loop/SKILL.md` + placement check | Matches at line 39 (Starting a new loop item 5) and line 52 (Gate handling), plus 45 (Resuming) and 60 (State updates) | Met |
| 3 | shipping persists the exact merge command before the merge-gate question on the normal interactive path | Rubric: persistence instruction precedes the blocking question, no capability-missing/worker trigger | `skills/shipping/SKILL.md:107` "Persist before the gate resolves" opens Step 7, "before asking the blocking question or evaluating `--auto` conditions", "on every path that reaches this step" | Met |
| 4 | release's interactive path persists `.release/draft.md` before the Phase 5 gate | Rubric: unconditional, ordered before presentation and every re-presentation | `skills/release/SKILL.md:362` persist-before-presenting opens Phase 5 ("not only in `mode:headless`"); `:387` rewrite before every re-presentation; Phase 6 item 1 persists newly derived packets | Met |
| 5 | The gate-death drill passes | Drill transcript: zero-context reader with only the state file reproduces the exact command and names first-hand consent as missing | Fresh drill this retro: a zero-context agent given only the determined-state progress.md fixture quoted the merge command byte-for-byte, refused execution citing `ship_approved: null` and the gate log line, and cited the non-authorization note verbatim | Met |
| 6 | Structural validation still passes | `bash scripts/validate.sh` | `ALL CHECKS PASSED` (fresh this retro, post-merge on `7e68962`) | Met |

## Carry-forward from previous retro

| Item | Status | Evidence |
|---|---|---|
| Carry-forward check structural assertion (probed-row→T-ID linkage is prose-only) | Not started — trigger ("next retro-template/check-9 design cycle") did not fire | Branch diff `800c623..7e68962` touches 7 files, none of them `scripts/validate.sh` or `schemas/retro-template.md`; ROADMAP row retained (T1) |
| Plan internal clause-consistency check (architecture-note prose vs unit step contracts) | In progress — trigger fired this cycle (plan's Architecture notes summarize unit behavior); satisfied procedurally, not mechanically: the independent plan review was explicitly instructed to diff Architecture notes vs unit steps and returned P1-1 (preparation-only contradiction), fixed in `0be6580`; mechanical check still absent, row stays open | `0be6580`; plan review record in `.release-loop/progress.md` (T1) |

- Previous doc shape: conformant

## Interview Transcript

- Independence level: heterogeneous (facilitator: GPT-family via `codex exec -s read-only`, stateless one-shot dispatches, artifacts only — no working-conversation access)
- Rounds used: 2 (max 5)

| ID | Round | Phase | Probe | Answer | Evidence | Verdict (verbatim) |
|---|---|---|---|---|---|---|
| T1 | 1→2 | 4 | The previous retro registered two P3 carry-forward items; where does this cycle account for each item, and what concrete artifact shows that neither was silently dropped? | (a) Structural assertion: Not started, trigger unfired — branch diff touches neither validate.sh nor retro-template; ROADMAP row retained. (b) Clause-consistency: trigger fired (Architecture notes summarize unit behavior); handled procedurally — plan review check 5 explicitly diffed notes vs steps and caught P1-1, fixed in `0be6580`; mechanical check still absent, row stays. Both get reconciliation rows | branch diff stat; `0be6580`; ROADMAP rows | accepted |
| T2 | 1→2 | 5 | The release headless-path draft has no in-file non-authorization marker despite the design requiring one on every persisted packet; what allowed this tension to survive through plan step 4 and all five reviews? | The spec is internally inconsistent — Architecture's "every persisted command packet" vs R7/Scope-In confining release to the interactive path — and plan U4 step 4 froze the Headless boundary; every review validated artifact compliance, so a compliant implementation reproduced the spec's own gap. First seen by the U4 task reviewer (U4-m1), triaged carry-with-registration by the final branch review | plan U4 step 4; U4 review verdict; ledger MinorFindings U4-m1 | accepted |
| T3 | 1→2 | 5 | The schema defines a four-field `final_action` record with no marker slot, while the live file added an ad-hoc `note:` field; what concrete event exposed this mismatch, and what assumption produced it? | Dogfooding exposed it: the loop's own progress.md needed a marker home at declaration (08:39:51 `note:` field) and shipping's "byte-for-byte" promise at determined-persist (10:19:48) cannot hold literally against a 4-field schema. Assumption: the marker was placed at documentation level (Rules bullets, header comment) not data level (record slot). Caught as N-1 by the final branch reviewer | schema lines 27–32; live progress.md `note:` field; final-review N-1 | accepted |
| T4 | 1→2 | 5 | The design requires a Log line for every status transition, but no explicit clause governs `predicted → determined`; how did the live transition get recorded, and what evidence shows whether that outcome came from an enforceable instruction or interpretation? | The live transition was logged (10:19:48 line) but from interpretation: State updates (SKILL.md:60) inherits the section's general at-the-moment discipline, while the schema's transitions bullet (:63) attaches same-edit logging only to invalidation and executed. No shipped file names per-transition logging for predicted→determined — recorded as N-2 | progress.md 10:19:48 log line; skills/release-loop/SKILL.md:60; progress-schema.md:63; final-review N-2 | accepted |
| T5 | 1→2 | 5 | At the final gate, the checkout had unexpectedly switched to `main`; what almost went wrong, and what specific persisted evidence or gate discipline prevented an incorrect merge action? | Almost-wrong: "re-fixing" CONCEPTS.md against main's version (divergent duplicate edits) or merging from a mis-assumed position. Prevented by file-over-memory discipline: `git status` (clean), branch pointer re-verified intact at `1a02283`, main confirmed at recorded base `800c623` — main was the correct merge position; the executed merge was the persisted final_action command byte-for-byte after first-hand approval in `ship_approved` | progress.md ship log 10:20:00 and 11:26:04; merge commit `7e68962` | accepted |

Verdict cell values: `accepted` | `no evidenced answer (3 rejections): <verbatim>` | `self-attested`

## Findings

### What worked well

- **What happened**: Prepare-before-gate was dogfooded live in the same cycle that shipped it — the loop's own `final_action` ran predicted → determined (10:19:48, before the gate) → executed (11:26:04), and the SC5 zero-context drill reproduced the merge command byte-for-byte while refusing execution for missing first-hand consent.
  **Why**: The orchestrating session applied U2/U3's freshly merged rules to its own ship gate instead of waiting for the next cycle.
  **How to apply**: When a cycle ships a process rule the current loop can already obey, apply it in the same session — it doubles as the first integration test.
  **Cites**: Phase 3 SC5 drill result; T5.
- **What happened**: A mid-gate environment shift (checkout found switched to `main`, CONCEPTS.md apparently "reverted") was absorbed without a wrong action: state was re-derived from git evidence, main turned out to be the correct merge position, and the persisted command executed unchanged.
  **Why**: The loop's file-over-memory rule (progress.md + `git log` outrank recollection) covers exactly this class of surprise; the determined record made the pending action checkout-independent.
  **How to apply**: On any unexplained workspace change mid-gate, stop and re-derive from `git status`/`rev-parse`/`log` before touching anything — never "repair" content against memory.
  **Cites**: T5.
- **What happened**: The independent plan review caught P1-1 — U3's "preparation-only alike" contradicting shipping Step 0's terminal-state semantics — the exact defect class the previous retro's clause-consistency carry-forward describes, because the review prompt explicitly instructed the Architecture-notes-vs-unit-steps diff.
  **Why**: The prior retro's finding was converted into a standing review instruction rather than left as a row.
  **How to apply**: Until a mechanical check exists, carry open process rows into review-dispatch prompts verbatim.
  **Cites**: T1; `0be6580`.

### What to improve

- **What happened**: The spec's universal invariant ("non-authorization marker on every persisted command packet") silently excepted the release headless draft, and the inconsistency survived spec self-review, independent spec review, and plan review — only the U4 task reviewer saw it (U4-m1).
  **Why**: Every review layer validated artifacts against the spec; none checked the spec's universal claims against its own scope sections.
  **How to apply**: When a spec states an "every X" invariant, enumerate the X instances in the spec and mark each as covered or explicitly excepted; review the enumeration, not the adjective.
  **Cites**: T2.
- **What happened**: The `final_action` schema block carries no slot for the marker its own rules demand per packet; the live record improvised a `note:` field, making shipping's "byte-for-byte" single-sink claim literally unsatisfiable (N-1).
  **Why**: The invariant was specified at documentation level (Rules prose) while the record instance defines the data level; nothing forced the two to meet.
  **How to apply**: Specify where an invariant lives in the data shape, not only in the rules that describe it.
  **Cites**: T3.
- **What happened**: The predicted→determined transition is logged by interpretation of the general at-the-moment rule, not by an explicit clause — the only transition without one (N-2).
  **Why**: U1's transitions bullet attached same-edit logging to the two riskier transitions and left the first to the section's ambient discipline.
  **How to apply**: When enumerating transitions, give each the same clause shape — asymmetry reads as intent.
  **Cites**: T4.

### Process observations

- **What happened**: The originating directive's literal arm ("execute the irreversible action first") was rejected as P7-incompatible and its parenthetical arm ("script it standalone") adopted; the rejection is recorded in the spec's Directive-interpretation section and as an EntireContext decision (`ec5eea9a`), so the design survives without the conversation.
  **Why**: Treating a directive's intent and letter as separable let the feature ship without weakening a principle.
  **How to apply**: When an instruction conflicts with a standing principle, implement the compatible reading and commit the rejection rationale as a first-class design record.
  **Cites**: spec "Directive interpretation" section; design log 08:39:51 (progress.md).
- **What happened**: The Review phase advanced without a full re-dispatch: the phase-gate caller shape verified the just-completed final branch review's state (HEAD unchanged, clean tree, fresh validate.sh) in one command batch.
  **Why**: The reviewing skill explicitly authorizes verify-and-advance when implementing's last review is current.
  **Cites**: progress.md review-phase log entry; Phase 2 data.

## Carry-forward items registered

| Item | Type | Priority | Tracked at |
|---|---|---|---|
| Release headless-path `.release/draft.md` carries no in-file non-authorization marker — the spec's "every persisted packet" invariant vs R7's interactive-only scope (U4-m1); resolve by extending the marker to the headless write or by scoping the invariant, via `designing` | edge-case | P3 | ROADMAP.md "Carry-forward from retros" |
| `final_action` record polish: add a marker/note slot to the schema block so the per-packet marker lives at data level and shipping's byte-for-byte single-sink claim is literally satisfiable (N-1); give predicted→determined the same explicit same-edit Log clause as the other transitions (N-2) | architecture | P3 | ROADMAP.md "Carry-forward from retros" |
| Define "hand-up packet" locally in shipping (term used at Steps 7–8 without definition; pre-existing, surfaced by U3 review) | process | P4 | ROADMAP.md "Carry-forward from retros" |
| Mechanical `scripts/validate.sh` check for `final_action` shape (plan Deferred item) | process | P3 | ROADMAP.md "Carry-forward from retros" |

## Lessons

- A universal invariant in a spec ("every persisted packet") is only as strong as its enumerated instances — three review layers validated artifacts against the spec while the spec silently excepted one instance in its own scope section.
- Persist the exact final command before the gate opens: when the checkout switched under the session mid-gate, the on-disk record — not session memory — was the thing that stayed true, and the drill proved a stranger could finish the release from it.

## Compounding

- compound invocation: `Documentation complete — docs/solutions/workflow-issues/universal-invariant-scope-enumeration-gap.md` (T2 finding; frontmatter validated exit 0 on the boundary interpreter 3.9; CONCEPTS scanned, no qualifying terms; discoverability already met by README.md; no refresh recommended)
