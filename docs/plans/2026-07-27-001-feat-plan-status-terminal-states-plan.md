---
schema: plan/v1
title: Plan status terminal states and frontmatter validation
type: feat
status: draft
date: 2026-07-27
execution: code
origin: docs/specs/2026-07-27-plan-status-terminal-states-design.md
---

# Plan: Plan Status Terminal States and Frontmatter Validation

## Goal

Settle the plan `status` enum at `draft | approved | done | superseded` with
mandatory terminal-state evidence fields, ship a `plan/v1` frontmatter validator
with a test harness and corpus check, and teach the three consumer skills
(`planning`, `retrospective`, `implementing`) their terminal-state roles.

## Architecture notes

- **Validator is a sibling of `compound`'s, not a shared module.** Replicate the
  pattern of `skills/compound/scripts/validate-frontmatter.py` (hand-rolled
  frontmatter reader, pure stdlib, exit 0/1/2, parser-safety + schema checks) as
  a standalone script. Sharing code across skill directories would couple two
  independently distributed skills; the duplication is deliberate.
- **`from __future__ import annotations` on line 2** (immediately after the
  docstring). Known Pattern:
  `docs/solutions/runtime-errors/builtin-generic-annotations-crash-python38.md` —
  PEP 585 annotations crash pre-3.9 interpreters at import; the one-line
  mechanism cannot be partially applied. The sibling validator carries it.
- **Fixtures live in the test harness, not as committed files.** Repo convention
  (`scripts/test-python-compatibility.sh`, `scripts/test-signal-drift.sh`):
  test scripts write fixtures into a temp dir via heredocs. A new
  `scripts/test-plan-frontmatter.sh` follows it.
- **Evidence fields are conditional-required, not optional.** Known Pattern:
  `docs/solutions/workflow-issues/mandated-field-absent-from-schema.md` — a
  mandate to persist X without a schema slot for X produces invented keys. The
  schema names `completed_by:` and `superseded_by:` explicitly and the validator
  enforces the pairing, so the mandate and the slot ship together.
- **Unknown fields stay valid; unknown `schema:` versions fail** — matching
  `skills/release-loop/references/progress-schema.md`'s consumer rule, so
  `origin:` / `deepened:` keep working and additive fields need no version bump.
- **Path fields resolve from the repo root** (`superseded_by:`, `origin:`),
  matching how the live `resume-builder` instance writes them and how
  `scripts/validate.sh` invokes checks from `ROOT`.
- **The retro flip rides the retro commit.** `skills/retrospective/SKILL.md`
  Phase 8 already commits the retro doc plus durable-tracker updates as one
  commit; the `status: done` + `completed_by:` edit joins that commit, keeping
  the status flip atomic with its evidence.
- **Landmine (pre-existing red harness).** `scripts/test-signal-drift.sh` Case D
  asserts a string on `skills/retrospective/SKILL.md:77`; the string actually
  lives on line 94 and line 77 is blank, so Case D errors before testing
  anything — reproduced at `4cb3fdb`, before this work. U5 adds lines to that
  file and will shift the target further; U5's acceptance records the
  post-change line number for the P2 carry-forward row. No unit cites this
  harness as evidence, and no unit edits it (ROADMAP row disposition: deferred,
  see trigger audit).

## Assumption Recheck

Origin spec retains 9 live assumptions. All rerun at `2026-07-26T15:43:41Z`
(UTC) on `7c1c83b` (branch `feat/plan-status-terminal-states`).

| # | Approved claim | Fresh evidence | Outcome |
|---|---|---|---|
| 1 | Plan-status values `in-progress`/`done`/`abandoned` occur nowhere but the enum line | `grep -rn "status: in-progress\|status: done\|status: abandoned" --include="*.md" .` → 1 hit outside this cycle's own spec, and it is `progress-schema.md:10`'s `phase_status:` | match |
| 2 | `status: superseded` + `superseded_by:` live in resume-builder under plan/v1 | `grep -h "^status: superseded" ~/workspace/resume/docs/plans/*.md \| wc -l` → 1 | match |
| 3 | `planning` ships no validator | `rg -c "validate" skills/planning/SKILL.md` → 0 | match |
| 4 | A plan path does not index its merge commit | `git log --oneline -- docs/plans/2026-07-23-001-feat-evidence-tier-vocabulary-plan.md` → 3 commits, no merge | match |
| 5 | Completion recorded retro→plan only | 14 plans / 14 retros / 12 retros referencing a plan path | match |
| 6 | Every existing plan carries every required key | key-presence loop over `docs/plans/*.md` → 0 missing | match |
| 7 | `scripts/validate.sh` green at baseline | `bash scripts/validate.sh` → `ALL CHECKS PASSED` | match |
| 8 | Case D target on line 94, line 77 blank | `sed -n '77p'` → empty; `grep -n "Documentation complete"` → 94 | match |
| 9 | Compat registry lists committed artifacts at `test-python-compatibility.sh:196` | `grep -c` → 4 refs, registry block confirmed | match |

## File structure

Grouped by responsibility:

- **Contract** — `schemas/plan-schema.md` (modify): enum, evidence fields,
  rejection records, mutable-slot boundary, unknown-field rule, plus two folded
  carry-forward fixes (provenance reword, stale item-number reference).
- **Enforcement** — `skills/planning/scripts/validate-plan-frontmatter.py`
  (create), `scripts/test-plan-frontmatter.sh` (create),
  `scripts/validate.sh` (modify: corpus check),
  `scripts/test-python-compatibility.sh` (modify: one registry line).
- **Writers/consumers** — `skills/planning/SKILL.md` (modify: validator gate,
  superseded rule, stale reference fix), `skills/retrospective/SKILL.md`
  (modify: done flip), `skills/implementing/SKILL.md` (modify: terminal-state
  refusal).
- **Tracker** — `ROADMAP.md` (modify: three new rows, future-candidate row
  annotation, fired-row dispositions).

## Scenario coverage map

Origin spec has five User Scenarios (S1–S5).

| S-ID | Unit chain | Scenario evidence |
|---|---|---|
| S1 retro records completion | U1 → U2 → U5 | `scripts/test-plan-frontmatter.sh` case: `done` + `completed_by` fixture passes, `done` without `completed_by` fails (Covers S1); U5 rubric per spec SC6 |
| S2 supersession at successor commit | U1 → U2 → U4 | test case: `superseded` + resolving `superseded_by` passes; missing pointer fails; dangling path fails (Covers S2) |
| S3 implementing refuses terminal plan | U1 → U6 | non-code-style observable verification: a reviewer walks U6's Pre-flight text and confirms both refusals name their evidence field (spec SC5 rubric) — U6 is a docs edit, no test file |
| S4 out-of-enum caught pre-commit | U2 → U3 | test case: `status: in-progress` fixture fails naming the field (Covers S4); `bash scripts/validate.sh` corpus check green on the 14-plan corpus |
| S5 zero-context corpus reader | U1 → U3 → U7 | observable verification: spec SC1 greps return expected counts; corpus check green with zero plan-file edits (spec SC3) |

## Implementation Units

## U1: schemas/plan-schema.md — settle the status contract
Execution note: skip-test-first (docs contract; U2's fixtures are its executable test)
Files:
  Create: (none)
  Modify: schemas/plan-schema.md
  Test: (none — U2 encodes this contract as fixtures)
Interfaces:
  Consumes: current frontmatter block (line 16 enum, line 32 "item 1" reference, line 33 "approved with this plan" provenance)
  Produces: the plan/v1 contract every other unit reads: STATUS = {draft, approved, done, superseded}; done ⇒ non-empty `completed_by:` (merge commit that landed the plan's work); superseded ⇒ `superseded_by:` resolving to an existing repo-root-relative path; unknown fields valid, unknown `schema:` versions rejected
Test scenarios:
  happy: `grep -c 'status: draft | approved | done | superseded' schemas/plan-schema.md` → 1 (spec SC1)
  edge: `grep -c 'in-progress' schemas/plan-schema.md` → 1 and `grep -c 'abandoned' schemas/plan-schema.md` → 1 — each surviving occurrence is its rejection record (spec SC1)
  error: n/a — doc edit; malformed contract is caught by U2's fixture suite disagreeing with the schema text at review
  integration: n/a — leaf unit
Steps:
  1. In the frontmatter block, replace the `status:` line with `status: draft | approved | done | superseded` and keep the existing draft-then-approved comment.
  2. Below the frontmatter block, add the terminal-state rules: `done` requires `completed_by: <merge commit sha>` written by `retrospective` in the same commit as the retro doc; `superseded` requires `superseded_by: <existing plan path>` written by `planning` in the same commit that commits the successor (successor status irrelevant; `draft → superseded` is valid; `draft → done` is not); direction predecessor→successor only, no backlink.
  3. Add the mutable-slot boundary (spec R5): the body is immutable after the approved commit; the `status` field and its terminal-state evidence field are the plan's only mutable slots.
  4. Add two rejection records (spec R4), one line each: `in-progress` — live execution state lives in commits and the progress ledger; a committed second copy is a dual source of truth that a dead session latches permanently. `abandoned` — zero observed instances; the observed need is `superseded`, which carries a successor pointer `abandoned` has no slot for.
  5. Add the unknown-field rule (spec R6): consumers and the validator reject unknown `schema:` versions, never unknown fields.
  6. Fold carry-forward row fixes: at line 32, change "item 1's deviation-addendum rule" to "item 3's deviation-addendum rule" (the rule lives in hard-floor item 3, Assumption Recheck); at line 33, replace "approved with this plan" with the explicit path "approved with docs/plans/2026-07-24-001-feat-planning-trigger-audit-plan.md".
  7. Commit: "feat(schema): Settle plan status enum with terminal-state evidence fields"
Acceptance: the three SC1 greps return 1/1/1; `grep -n "item 3's deviation-addendum rule" schemas/plan-schema.md` hits; `grep -n "2026-07-24-001" schemas/plan-schema.md` hits.

## U2: validate-plan-frontmatter.py + test harness
Execution note: test-first
Files:
  Create: skills/planning/scripts/validate-plan-frontmatter.py, scripts/test-plan-frontmatter.sh
  Modify: (none)
  Test: scripts/test-plan-frontmatter.sh
Interfaces:
  Consumes: U1's contract; the parser/check structure of skills/compound/scripts/validate-frontmatter.py (extract_frontmatter / parse_frontmatter / check_parser_safety / check_schema / main, exit 0 pass, 1 validation failure with offending field named on stderr, 2 usage error)
  Produces: CLI `python3 skills/planning/scripts/validate-plan-frontmatter.py <plan-path>`; test CLI `bash scripts/test-plan-frontmatter.sh` exiting 0 when all cases pass
Test scenarios:
  happy: four valid fixtures pass — `draft`; `approved`; `done` + `completed_by: abc1234`; `superseded` + `superseded_by:` naming a file the harness creates in the temp dir
  edge: legacy fixture (exactly the six pre-change keys, `status: approved`) passes; a fixture with an extra unknown field (`deepened: true`, plus a never-seen key) passes
  error: each fails naming the offending field — `status: in-progress`; `status: abandoned`; `status: done` without `completed_by`; `status: superseded` without `superseded_by`; `superseded_by` naming a missing path; `origin` naming a missing path; `schema: plan/v2`; missing required key (one case per key: schema, title, type, status, date, execution); `execution: ops`; `type: unknown`; malformed date; unquoted ` #` in a value (parser-safety port)
  integration: `bash scripts/test-plan-frontmatter.sh` runs the whole suite standalone (Covers S1, S2, S4)
Steps:
  1. Write scripts/test-plan-frontmatter.sh first: temp-dir setup, heredoc fixtures for every scenario above, assertions on exit code and stderr substring (offending field name), summary line + nonzero exit on any case failure — follow scripts/test-signal-drift.sh's case-function style.
  2. Run it; confirm every case fails because the validator does not exist yet.
  3. Write skills/planning/scripts/validate-plan-frontmatter.py: module docstring, then `from __future__ import annotations`, then the four-function structure ported from compound's validator with plan/v1 sets: REQUIRED = [schema, title, type, status, date, execution]; TYPE_VALUES = {feat, fix, refactor, chore, docs}; STATUS_VALUES = {draft, approved, done, superseded}; EXECUTION_VALUES = {code, non-code}; `schema` must equal `plan/v1`; date must match `^\d{4}-\d{2}-\d{2}$`; done ⇒ completed_by non-empty; superseded ⇒ superseded_by non-empty and `os.path.isfile` from CWD; origin present ⇒ `os.path.isfile` from CWD; keep compound's parser-safety checks; never fail on unknown keys.
  4. Run scripts/test-plan-frontmatter.sh; confirm all cases pass. Also run the validator on one real plan (`docs/plans/2026-07-23-001-feat-evidence-tier-vocabulary-plan.md`) and confirm `OK:` exit 0.
  5. Commit: "feat(planning): Add plan/v1 frontmatter validator with fixture harness"
Acceptance: `bash scripts/test-plan-frontmatter.sh` exits 0 with every case listed; `python3.9 -m py_compile` and `python3.14 -m py_compile` both succeed on the validator (pre-check of U3's registry gate).

## U3: harness integration — corpus check + compat registry
Execution note: test-first
Files:
  Create: (none)
  Modify: scripts/validate.sh, scripts/test-python-compatibility.sh
  Test: scripts/validate.sh (self-verifying: the corpus check is the test)
Interfaces:
  Consumes: U2's validator CLI; validate.sh's `fail()`/`ok()` convention and `FAIL=0` accumulator; the `artifact_registry()` heredoc at scripts/test-python-compatibility.sh:194-199 (`committed|<label>|<path>` triple format)
  Produces: a `[plan-frontmatter]` tagged check in validate.sh looping `docs/plans/*.md` through the validator; registry line `committed|plan-frontmatter-validator|skills/planning/scripts/validate-plan-frontmatter.py`
Test scenarios:
  happy: `bash scripts/validate.sh` → `ALL CHECKS PASSED` including `ok: [plan-frontmatter]` line and `label=plan-frontmatter-validator` `status=pass` for role=oldest and role=newest (spec SC3, SC4)
  edge: corpus check counts the files it validated (`ok: [plan-frontmatter] 15 plans valid`) so an empty glob is distinguishable from a green pass
  error: temporarily inject `status: in-progress` into a scratch copy of one plan under a temp dir and run only the check body against it → FAIL line naming the file and field; do not commit the scratch (manual step verification, mirrors S4)
  integration: full `bash scripts/validate.sh` on the real tree (Covers S4, S5)
Steps:
  1. Add the corpus check to scripts/validate.sh after the existing frontmatter checks: loop `"$ROOT"/docs/plans/*.md`, run the validator, on nonzero append its stderr to the FAIL output with the `[plan-frontmatter]` tag; count validated files into the ok line.
  2. Run `bash scripts/validate.sh`; confirm the new check passes on the untouched 14-plan corpus plus this plan file itself (15 total at run time).
  3. Add the registry line to `artifact_registry()` in scripts/test-python-compatibility.sh directly below the compound validator's line, same `committed|label|path` shape, no heredoc touched.
  4. Run `bash scripts/validate.sh` again; confirm the python-compat section reports the new artifact compiling on both boundary interpreters.
  5. Commit: "feat(validate): Gate the plan corpus and register the validator artifact"
Acceptance: `bash scripts/validate.sh` exits 0; output contains `[plan-frontmatter]` ok line and two `label=plan-frontmatter-validator ... status=pass` lines (spec SC4, SC7).

## U4: skills/planning/SKILL.md — superseded writer + validator gate
Execution note: skip-test-first (docs edit; U2/U3 harnesses verify the gate it prescribes)
Files:
  Create: (none)
  Modify: skills/planning/SKILL.md
  Test: (none — acceptance greps)
Interfaces:
  Consumes: U1's superseded contract; U2's validator CLI; step 17 ("Commit the plan") and line 120's stale "item 1" reference
  Produces: step 17 gains the validator gate with `compound`'s exact gate wording pattern ("Exit 0 required before claiming success"); a supersession rule; a corrected item-number reference
Test scenarios:
  happy: `rg -c "validate-plan-frontmatter" skills/planning/SKILL.md` ≥ 1 (spec-motivating asymmetry closed: was 0)
  edge: `grep -n "item 3's deviation-addendum rule" skills/planning/SKILL.md` hits at the former :120 site
  error: n/a — doc edit; a wrong gate wording is caught by review against skills/compound/SKILL.md:48
  integration: n/a — leaf unit (S2's chain evidence lives in U2's fixtures)
Steps:
  1. In step 17, after the draft-commit sentence, add: run `python3 skills/planning/scripts/validate-plan-frontmatter.py <plan-path>` on the drafted file; exit 0 required before presenting the draft and again before the approved-flip commit; a nonzero exit names the offending field — fix and re-run, never present a failing draft.
  2. Add the supersession rule to step 17: when this plan replaces an earlier plan, flip the predecessor to `status: superseded` with `superseded_by:` naming this plan's path, in the same commit that commits this plan (predecessor may be `draft` or `approved`); run the validator on the predecessor too.
  3. Fix the stale reference at line 120: "item 1's deviation-addendum rule" → "item 3's deviation-addendum rule".
  4. Commit: "feat(planning): Gate plan commits on the frontmatter validator; write supersession"
Acceptance: the three greps above hit; `bash scripts/validate.sh` still exits 0.

## U5: skills/retrospective/SKILL.md — the done flip
Execution note: skip-test-first (docs edit; the record shape it mandates is U2-fixture-verified)
Files:
  Create: (none)
  Modify: skills/retrospective/SKILL.md
  Test: (none — acceptance greps + spec SC6 rubric)
Interfaces:
  Consumes: U1's done contract; Phase 2's origin-artifact bullet (locates the plan); Phase 8 "Commit & Report" (the retro-doc commit the flip rides)
  Produces: Phase 8 rule — before committing, for every plan this retro covers, set `status: done` and `completed_by: <merge commit that landed that plan's work>` in the plan's frontmatter, in the same commit as the retro doc; a retro covering multiple plans flips every one of them, each with its own `completed_by:`; a retro with no plan (session-end mode) writes no flip; never edit anything in the plan below the frontmatter (mutable-slot boundary, U1)
Test scenarios:
  happy: `grep -n "completed_by" skills/retrospective/SKILL.md` ≥ 1 in Phase 8
  edge: the no-plan sentence and the multi-plan (flip-all) sentence both present — spec SC6 rubric requires all three cases stated
  error: n/a — doc edit; a flip rule that edits the body would violate U1's boundary and is caught by the SC6 rubric review
  integration: n/a — leaf unit (S1's chain evidence lives in U2's fixtures)
Steps:
  1. In Phase 8, after the commit sentence, add the flip rule exactly as the Produces field states, citing `schemas/plan-schema.md` for the field contract.
  2. Record the post-change line number of the `Documentation complete — <path>` string (currently line 94, will shift by the number of lines added above it) in this unit's completion note and in U7's red-suites row annotation — the P2 carry-forward repair value.
  3. Run `bash scripts/test-retro-format-drift.sh` if present and `bash scripts/validate.sh`; confirm neither regresses beyond the pre-existing Case D failure documented in Architecture notes (`scripts/test-signal-drift.sh` was red before this change and is not cited as evidence).
  4. Commit: "feat(retrospective): Flip covered plans to done atomically with the retro commit"
Acceptance: greps in scenarios hit; `bash scripts/validate.sh` exits 0; the completion note names the new line number of the Case D target string.

## U6: skills/implementing/SKILL.md — terminal-state refusal
Execution note: skip-test-first (docs edit; spec SC5 rubric is the verification)
Files:
  Create: (none)
  Modify: skills/implementing/SKILL.md
  Test: (none — SC5 rubric)
Interfaces:
  Consumes: U1's terminal-state contract; Pre-flight step 1 (the plan read)
  Produces: a Pre-flight rule — before the contradiction scan, check frontmatter `status`: `done` → stop with a detectable error naming the recorded `completed_by:` commit ("this plan already executed; its work landed in <completed_by>"); `superseded` → refuse, naming the `superseded_by:` successor path as where to go instead; `draft` → stop and route back to `planning`'s USER gate (entry requires an approved plan); neither terminal state ever degrades to executing the plan
Test scenarios:
  happy: `grep -n "completed_by" skills/implementing/SKILL.md` and `grep -n "superseded_by" skills/implementing/SKILL.md` both hit in Pre-flight
  edge: the draft-status routing sentence present (closes the gap between the entry line "an approved plan file" and observed statuses)
  error: n/a — doc edit; rubric SC5 checks both refusals name their evidence field and neither degrades to execution
  integration: n/a — leaf unit (S3 is walked by the SC5 rubric per the coverage map)
Steps:
  1. Add the status check as new Pre-flight item 1 (renumber subsequent Pre-flight items — these are list items, not U-IDs; the U-ID stability rule does not apply).
  2. Run `bash scripts/validate.sh`; confirm green.
  3. Commit: "feat(implementing): Refuse terminal-status plans at pre-flight"
Acceptance: both greps hit inside the Pre-flight section; validate.sh exits 0.

## U7: ROADMAP.md — rows, closures, dispositions
Execution note: skip-test-first (tracker edit; acceptance greps)
Files:
  Create: (none)
  Modify: ROADMAP.md
  Test: (none — acceptance greps)
Interfaces:
  Consumes: the "Future candidates" table ("Schema validators + fixtures" row), the "Carry-forward from retros" table, the fired-row list in this plan's trigger audit
  Produces: three new carry-forward/candidate rows; one candidate-row annotation; fired-row annotations for this cycle's dispositions
Test scenarios:
  happy: `grep -c "source-over-memory" ROADMAP.md` → 1; `grep -c "commit-message regeneration\|stale-message" ROADMAP.md` ≥ 1; `grep -c "post-approval body immutability\|outward publication" ROADMAP.md` ≥ 1
  edge: the "Schema validators + fixtures" row still names review-envelope/v1 as open after the plan/v1 half is annotated closed
  error: n/a — tracker edit; a dropped row is caught by the retro-side reconciliation
  integration: n/a — leaf unit (S5 evidence is the corpus check plus SC1 greps)
Steps:
  1. Annotate the "Schema validators + fixtures" future-candidate row: trigger fired (out-of-enum values tracked in a consuming repo, 2026-07-26); plan/v1 half closed by this cycle; review-envelope/v1 half remains with the original trigger.
  2. Add three rows: (a) shipping commit-message regeneration after review — a message drafted before review is stale after review changes the artifact; trigger: next `skills/shipping/SKILL.md` edit or first stale-message incident; (b) source-over-memory cross-cutting reference — claims about file content require a same-turn read; trigger: next memory-based citation error, or next cycle touching citation rules in planning/shipping/retrospective/compound; (c) reserved designing cycle — post-approval body immutability (every section, every actor) + outward publication named as a stateful ceremony; origin: resume-builder 2026-07-26 incident (findings 1–2); trigger: before the next cycle whose deliverable crosses an outward-publication boundary, or first post-approval in-place edit in any plan/v1 repo.
  3. Update the fired rows' annotations per this plan's trigger-audit dispositions (fold: provenance reword, stale item references — mark done by this cycle's commits; defer: the remaining nine, each keeping its row with the audit's reason).
  4. Record the U5 post-change line number in the red-suites (P2) row so its Case D repair has a known value.
  5. Commit: "docs(roadmap): Register resume-session rows and this cycle's trigger dispositions"
Acceptance: the greps in scenarios hit; ROADMAP renders as a table (no broken pipes) via `grep -c '^|' ROADMAP.md` increasing by the expected row count.

## Mutation/failure-state matrix

No stateful ceremony in the deliverable; no mutation/failure-state matrix required.

## Carry-forward trigger audit

Audited ROADMAP.md `Carry-forward from retros` at 7c1c83b: 21 open rows, 11 fired, 0 unobservable.

Fired rows (trigger class; what fired it; disposition):

| Row | Class | What fired it | Disposition |
|---|---|---|---|
| Plan-schema provenance reword ("approved with this plan") | edit-based | plan list edits `schemas/plan-schema.md` | **fold** → U1 step 6 |
| Stale "item 1's deviation-addendum rule" refs (`plan-schema.md:32`, `planning/SKILL.md:120`) | edit-based | plan list edits both named files | **fold** → U1 step 6, U4 step 3 |
| Two pre-existing red suites (P2: signal-drift Case D, release-publication) | edit-based | plan list edits `skills/retrospective/SKILL.md` (Case D's target file) | **defer** — spec scoped the mitigation to recording the failure and the post-change line number (U5 step 2, U7 step 4); repairing two decayed harnesses is neither in the approved spec nor safe to bolt onto a schema cycle; row keeps the repair with a now-known line value |
| Pin `PYTHON_SUPPORT_FILE` in compatibility consumers | edit-based | plan list edits `scripts/test-python-compatibility.sh` | **defer** — U3 adds one registry data row and touches no delegation boundary; folding a harness-behavior change into a schema cycle expands the approved spec; row remains with its trigger |
| Plan internal clause-consistency check | edit-based | plan edits `implementing` preflight; this plan's architecture notes summarize unit behavior (both arms) | **defer** the mechanical check (out of spec scope); the procedural clause-diff is mandated into this plan's independent review dispatch, as in the prior two cycles |
| Retro-side trigger classification rule | edit-based (tiebreak from "next retrospective-skill design cycle") | this cycle designs `retrospective` edits | **defer** — the approved spec's retrospective scope is the done flip only; folding Phase 4 reconciliation rules would expand it; row remains |
| Automated numbered-reference validation | latched | fired 2026-07-24, check still unbuilt | **defer** — no hard-floor insertion or step renumbering in this plan (frontmatter contract only); check remains unbuilt, row remains |
| Carry-forward structural T-ID assertion | latched | fired latched 2026-07-24 | **defer** — retro-template/check 9 untouched this cycle |
| Hand-up packet definition in shipping | latched | fired `2299955`, latched 2026-07-24 | **defer** — `skills/shipping/SKILL.md` untouched this cycle (U7's row-add edits ROADMAP only) |
| Mechanical `final_action` shape check | latched | fired (recurring `note:` drift), latched 2026-07-24 | **defer** — U3's validate.sh edit adds the plan-corpus check; a `final_action` check is a separate consumer with its own row |
| Spec-level carve-out rule in designing | latched | fired 2026-07-24, durable rule still unbuilt | **defer** — `skills/designing` untouched this cycle |

Not-fired notes recorded for auditability: the check-9/drift-harness row names check 9 specifically and `test-retro-format-drift.sh` (neither touched — U3 adds a new check elsewhere in validate.sh); the command-closure row names planning steps 13/14 and the unit template (this plan edits step 17 and the frontmatter contract); the heredoc-bootstrap row names inline-heredoc changes (U3's registry line adds a data row, no heredoc); the python38-drift row names `skills/compound/scripts/validate-frontmatter.py` and `schemas/python-support.json` (neither touched — U2 applies its lesson to the new sibling instead).

## Deferred to Follow-Up Work

- `review-envelope/v1` validator — remains on the "Schema validators + fixtures" row (U7 step 1).
- `execution: ops` as a possible third execution mode — future designing cycle (spec Open Decision 2; the validator flagging resume-builder's instances is intended).
- The reserved designing cycle: post-approval body immutability + outward publication as stateful ceremony (U7 step 2c) — the resume incident's root cause, deliberately not this cycle.
- Shipping commit-message regeneration (U7 step 2a) and source-over-memory reference (U7 step 2b) — registered as rows, not built here.
- The nine deferred fired rows in the trigger audit, each with its recorded reason.
- Repairing `scripts/test-signal-drift.sh` Case D and `scripts/test-release-publication.sh` — stays with the P2 row, now carrying the exact post-change line number.

## Open unknowns

**Planning-time (all resolved):** none remaining — enum, evidence fields, writers, flip-all rule, and grandfathering were settled at the spec's gates.

**Implementation-time (deferred by design):**
- Exact insertion line numbers in the three SKILL files and validate.sh (drift-prone; resolved at edit time).
- The post-change line number of the retro Case D target (knowable only after U5's exact text lands; recorded in U5's completion note and U7).
- The corpus-check tag's exact ok-line format (must follow validate.sh's existing `ok:`/`fail()` shapes at edit time).
- Whether the fixture temp dir uses `mktemp -d` under `TMPDIR` or the scratch convention of `test-signal-drift.sh` (`setup_copy`) — follow whichever the harness file structure makes cleaner at write time.
- `python3.9`/`python3.14` availability paths are resolved by the compat harness itself; U2's manual `py_compile` pre-check uses whatever the harness's endpoint resolution reports.
