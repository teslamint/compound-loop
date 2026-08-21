---
schema: plan/v1
title: Instruction Payload Slimming
type: refactor
status: draft
date: 2026-08-21
execution: code
origin: docs/specs/2026-08-21-instruction-payload-slimming-design.md
---

# Instruction Payload Slimming — Implementation Plan

## Goal

Slim the seven always-resident skill bodies from 137,024 bytes to at most 110,000 and the thirteen skill descriptions from 4,561 bytes to at most 3,200 by executing the spec's nine fixed move units into trigger-gated reference files and inventoried meaning-preserving compression — proving with baseline-anchored evidence that no gate, contract, or behavior was lost. Baseline revision is `f2efda9` per Deviation Addendum 014 (`docs/deviations/2026-08-21-baseline-revision-drift-014.md`), which supersedes the spec's `da1ffbf` and 105,000/95,000 figures.

## Architecture notes

- **Eight ordered units.** U1 captures baseline evidence and must land before any edit to `skills/` or `scripts/` — SC4's case floors and SC3's baseline mapping are meaningless if any edit precedes them. U2–U4 are the move commits, each carrying exactly the validator migration it necessitates (spec commit discipline: moves before compressions; a validator change serving both classes lands with the move that necessitates it). U5–U6 are the compression commits; U6 is the implementation freeze. U7 assembles the R7 integrity script, parity walkthrough fixtures, and the evidence artifact. U8 dispatches the independent reviewer for adjudication and the SC6 attack round and commits the verbatim output. Every intermediate commit keeps `bash scripts/validate.sh` plus every `scripts/test-*.sh` green.
- **Baseline is `f2efda9`, everywhere.** R7 diffs `git diff f2efda9..HEAD -- skills/`; R5 clause comparisons read `git show f2efda9:skills/<name>/SKILL.md`; SC4 case floors and SC3's baseline mapping come from a worktree checked out at `f2efda9`. No unit re-measures a baseline mid-cycle (Addendum 014's necessity section explains why `da1ffbf` is wrong: it would misattribute the user-authored F18 gate to this cycle).
- **Trigger pointers use one form** (spec R8), so U7's check (e) and the reviewing phase can audit them mechanically: `When <condition>, read <references/file.md> and follow it before proceeding.` One pointer per reference file, in the skill that owns it.
- **Moves are verbatim** per the spec's Normative block definition: a block is exactly the byte output of its extraction command, headings and marker lines inclusive. Anything not verbatim is an R10 `compressed` entry with original text, replacement text, and rationale, adjudicated by the independent reviewer at the review phase. Connective-framing drops (a sentence deleted to stitch the seam left by a moved block) are `compressed` entries too.
- **R7 script is archived cycle evidence, not a permanent suite member** (spec Open Decision 1, resolved at the 2026-08-21 scope gate). It lives at `docs/reviews/2026-08-21-instruction-payload-slimming/verify-move-integrity.sh`, runnable but not wired into `scripts/validate.sh`, because it is keyed to a git baseline that recedes: as a permanent test it would rot or demand baseline maintenance, and the repo's permanent suites are all HEAD-relative. Its committed output is the durable evidence.
- **Known Pattern** (`docs/solutions/test-failures/green-suite-unreachable-assertions.md`): a migrated test can go green by never reaching its assertions. U1's per-validator case-total floors plus the reviewing phase's assertion-inventory comparison exist to catch exactly this; U2's portability migration additionally adds a positive marker-pair-uniqueness assertion rather than only relocating paths.
- **Known Pattern** (`docs/solutions/test-failures/validator-harness-mutation-gap.md`): attacks must run against unmodified HEAD validators; the spec's SC6 freeze rule encodes this. No unit modifies a validator after U6 lands — U7 and U8 touch only `docs/reviews/` and `ROADMAP.md`, and a validator edit after a caught attack restarts the attack round.
- **Known Pattern** (`docs/solutions/conventions/plugin-cache-version-drift.md`): the loading surface can lag the repo at equal version numbers. SC7 registers the installed-cache parity obligation as a ROADMAP row owned by the release-loop completion gate (U7 step 5); this cycle does not measure the cache itself unless its release ships in-cycle.
- **Dispatched committers** (`ROADMAP.md` carry-forward, 2026-08-14 retro): if implementation is subagent-driven, the orchestrator passes the session's live `SSH_AUTH_SOCK` value through to each committing dispatch and verifies `git log -1 --format='%G?'` = `G` after every commit, recording both in the ledger. An Inline run has no dispatched-commit event. Never copy a redaction token as the socket value; pass the current variable through.
- **Descriptions stay single-line.** `scripts/test-plugin-skill-discovery.sh` asserts single-line `name:`/`description:` frontmatter; R4 compression must produce one physical line per description.
- **`test-planning-schema-portability.sh` needs no migration.** Its consumer-skill references are a stale-path allowlist scan for `schemas/plan-schema.md` mentions in active files, not contract extraction; the moved JSONL contains no schema path. It still runs in every unit's acceptance via the full-suite rule, so a surprise breakage is caught, not assumed away.
- **Reviewing-phase mandates are executed by U8's dispatch** (step 5a reviewer mandate, spec SC3/SC6/R10): the U8 dispatch prompt — and any plan-review dispatch prompt for this plan — copies in verbatim: re-derive the carry-forward trigger audit against the final file list; adjudicate every R10 `compressed` entry; re-derive the SC3 baseline mapping from `git show f2efda9:...`; author the six SC6 attack classes as single-defect mutants with passing controls after implementation freeze; grade findings by the success criterion threatened.

## Assumption Recheck

All eight retained commands from the origin spec rerun first-hand at `2026-08-21T14:35:47Z` against working tree `8c00d55`:

| Approved claim | Fresh evidence | Outcome |
|---|---|---|
| Seven bodies total 131,746 bytes | `wc -c ...` → `137024 total` | **contradiction — resolved by committed Addendum 014** (`docs/deviations/2026-08-21-baseline-revision-drift-014.md`, commit `c123b70`): user commit `f2efda9` (+5,278B F18 gate in shipping Step 7) landed after the spec's measurement and before its draft commit. Baseline revision becomes `f2efda9`; SC1 ceiling becomes 110,000, stretch 100,000 |
| Thirteen descriptions total 4,561 bytes | `4561` | match |
| M1–M4 total 9,040 bytes | `9040` | match |
| M5 measures 3,566 bytes | `3566` | match |
| M6 measures 4,575 bytes | `4575` | match |
| M7, M8, M9 measure 942, 402, 220 bytes | `942`, `402`, `220` | match |
| Portability suite references the four consumer paths 11 times (3+3+3+2) | implementing 3, release-loop 3, retrospective 3, reviewing 2 | match |
| `validate.sh` passes (sanity check only) | `ALL CHECKS PASSED` | match |

No unavailable evidence. The addendum commit `c123b70` precedes this plan's draft commit, satisfying the contradiction-blocks-finalization rule.

## File structure

| File | Change | Owner |
|---|---|---|
| `docs/reviews/2026-08-21-instruction-payload-slimming/baseline.md` | Create: baseline suite totals, byte figures, description mapping baseline, validator manifest — all at `f2efda9` | U1 |
| `skills/release-loop/references/plan-consumer-contract.md` | Create: M1 block verbatim | U2 |
| `skills/implementing/references/plan-consumer-contract.md` | Create: M2 block verbatim | U2 |
| `skills/reviewing/references/plan-consumer-contract.md` | Create: M3 block verbatim | U2 |
| `skills/retrospective/references/plan-consumer-contract.md` | Create: M4 block verbatim | U2 |
| `skills/{release-loop,implementing,reviewing,retrospective}/SKILL.md` | Modify: replace each contract block with an R8 pointer | U2 |
| `scripts/test-plan-consumer-portability.sh` | Modify: fixture copies `references/`; parser resolves the pointer's destination; add marker-pair-uniqueness check | U2 |
| `skills/release-loop/references/transition-hooks.md` | Create: M5 block verbatim | U3 |
| `skills/release-loop/references/resume-and-archive.md` | Create: M6 block verbatim | U3 |
| `skills/release-loop/SKILL.md` | Modify: M5/M6 replaced by core-retains text plus two R8 pointers | U3 |
| `skills/shipping/references/capability-preflight.md` | Create: M7 block verbatim | U4 |
| `skills/designing/references/out-of-scope.md` | Create: M8 block verbatim | U4 |
| `skills/retrospective/references/out-of-scope.md` | Create: M9 block verbatim | U4 |
| `skills/{shipping,designing,retrospective}/SKILL.md` | Modify: M7/M8/M9 replaced by R8 pointers (M7 also keeps the fail-closed rule) | U4 |
| `skills/*/SKILL.md` (all thirteen) | Modify: compressed single-line `description:` fields, total ≤ 3,200 bytes | U5 |
| `docs/reviews/2026-08-21-instruction-payload-slimming/description-routing-map.md` | Create: SC3 mapping table — baseline side mechanical from `git show f2efda9:...`, current side per skill | U5 |
| `skills/{designing,planning,implementing,reviewing,shipping,retrospective,release-loop}/SKILL.md` | Modify: R5-bounded prose compression to ≤ 110,000 total | U6 |
| `docs/reviews/2026-08-21-instruction-payload-slimming/disposition-inventory.md` | Create: R10 inventory — every scoped removed/changed baseline line classified `moved` or `compressed`, reviewer-verdict column pending | U6 |
| `docs/reviews/2026-08-21-instruction-payload-slimming/verify-move-integrity.sh` | Create: R7 script, checks (a)–(e) | U7 |
| `docs/reviews/2026-08-21-instruction-payload-slimming/r7-output.md` | Create: committed R7 run output | U7 |
| `docs/reviews/2026-08-21-instruction-payload-slimming/parity-walkthroughs.md` | Create: fired/not-fired records M1–M9 | U7 |
| `ROADMAP.md` | Modify: add SC7 installed-cache parity carry-forward row | U7 |
| `docs/reviews/2026-08-21-instruction-payload-slimming/adjudication-and-attacks.md` | Create: reviewer identity, verbatim transcript, six attack records; verdict columns filled in the U6 inventory and U5 map | U8 |
| `scripts/test-signal-drift.sh`, `scripts/test-retro-format-drift.sh`, `scripts/validate.sh` | Modify only if a move shifts a pinned extraction or diagnostic (R6); expected no-op for M4/M9 since pinned sections do not move — verified in unit acceptance, changed in the same commit as the necessitating move if wrong | U2–U4 |
| `docs/plans/2026-08-21-001-refactor-instruction-payload-slimming-plan.md` | This plan | — |

## Scenario coverage map

| S-ID | Unit chain | Scenario evidence |
|---|---|---|
| S1 (new loop loads slim orchestrator) | U1 → U2 → U3 → U6 | Integration: U7 parity walkthrough "release-loop core, no trigger fired" — core `wc -c` strictly below baseline 18,705, no pointer condition satisfied, every gate/sequencing rule present (Covers S1); SC1 measurement over the seven bodies |
| S2 (ordinary loop ships without ceremony text) | U3 | Integration: U7 not-fired walkthrough for M5 — fixture plan with no transition heading and empty `.handoff/` reaches Ship with heading shapes + inspection rule + blocked-by-silence invariant all in core (Covers S2) |
| S3 (resume fires its pointer) | U3 | Integration: U7 fired walkthrough for M6 — fixture `.release-loop/progress.md` plus `resume` path shows schema-version rejection in core and reconstruction procedure reachable via the pointer (Covers S3) |
| S4 (non-loop session pays less fixed cost) | U5 → U8 | SC2 measurement ≤ 3,200; `scripts/test-plugin-skill-discovery.sh` green; description-routing map shows zero dropped/moved/inverted triggers, reviewer verdict column filled by U8 (Covers S4) |
| S5 (suite still guards moved contracts) | U1 → U2 → U3 → U4 | SC4: every suite green with self-reported totals ≥ U1's baseline floors; U2's marker-pair-uniqueness check rejects a stale-copy fixture (Covers S5) |
| S6 (reviewer proves the change lost nothing) | U1 → U6 → U7 → U8 | R7 output + disposition inventory committed by U7; U8 commits the independent reviewer's verbatim adjudication of every `compressed` entry, the SC3 map verdicts, the M5–M9 walkthrough confirmations, and the six-class attack round against frozen validators (Covers S6) |

## Implementation Units

## U1: Baseline evidence capture at f2efda9

Execution note: skip-test-first — this unit generates evidence, no production logic.
Files:
  Create: docs/reviews/2026-08-21-instruction-payload-slimming/baseline.md
Interfaces:
  Consumes: `git worktree add "$WT" f2efda9`; `bash scripts/validate.sh`; every `scripts/test-*.sh`
  Produces: baseline.md with four sections — Suite totals, Byte figures, Description baseline, Validator manifest (including per-validator assertion inventories) — consumed by U5, U6, U7, U8
Test scenarios:
  happy: every suite runs at the baseline worktree and reports a numeric case/pass total
  edge: a suite reports no machine-readable total → record its exact final summary line verbatim as the floor
  error: a suite fails at baseline → stop; the baseline is not green and the cycle cannot establish floors (escalate to user — this contradicts Addendum 014's expectations)
  integration: n/a — leaf evidence unit
Steps:
  1. `BASE=f2efda9; WT=$(mktemp -d)/base; git worktree add "$WT" "$BASE"` and inside `$WT` run `bash scripts/validate.sh` and each of the twelve `scripts/test-*.sh`, capturing each suite's self-reported summary line (e.g. `44 passed`, `13 skills checked, 0 failures`, `ALL CHECKS PASSED`).
  2. Write `docs/reviews/2026-08-21-instruction-payload-slimming/baseline.md` with: (a) one row per suite — script name, exact summary line, numeric total; (b) byte figures from `$WT`: seven-body `wc -c` table (must total 137,024), thirteen-description total (must be 4,561), M1–M9 block bytes re-derived by the spec's extraction commands (must be 2245, 3755, 1609, 1431, 3566, 4575, 942, 402, 220); (c) the SC3 baseline side: per skill, the trigger phrases and negative/routing clauses extracted from `git show f2efda9:skills/<name>/SKILL.md` `description:` fields, quoted verbatim — one or more rows for each of the thirteen skills; (d) validator manifest: `sha256sum` of the five R6 validators at `$BASE`; per validator the exact case-count command used and its output — `grep -c '^run_case' scripts/test-retro-format-drift.sh` and `grep -c '^run_case' scripts/test-signal-drift.sh` for the two mutation suites, the suite's own self-reported total for the other three; and per validator an **assertion inventory**: the numbered output of `grep -n 'assert_\|fail \|fail(\|require(' scripts/<validator>` at `$BASE`, pasted verbatim, as the baseline side of U8's assertion-inventory comparison.
  3. `git worktree remove "$WT"` and commit only the new evidence file.
  4. Confirm ordering: `BASE_REF=$(git merge-base main HEAD); git log --oneline "$BASE_REF"..HEAD -- skills/ scripts/` prints nothing at this commit — no skill or script edit precedes the baseline.
  5. Commit: "chore(evidence): capture f2efda9 baseline for payload slimming"
Acceptance: baseline.md exists with all four sections non-empty by their own definitions — 13 suite rows each with a summary line, the seven-body table totaling 137024, ≥1 phrase row for each of the 13 skills in (c), and 5 validator entries in (d) each with hash, case-count output, and a non-empty assertion inventory; the commit touches only `docs/reviews/`.

## U2: Move the four plan-consumer contracts (M1–M4) and migrate the portability suite

Execution note: test-first — the portability suite migration is written and failing-red against the unmoved tree before the blocks move.
Files:
  Create: skills/release-loop/references/plan-consumer-contract.md, skills/implementing/references/plan-consumer-contract.md, skills/reviewing/references/plan-consumer-contract.md, skills/retrospective/references/plan-consumer-contract.md
  Modify: skills/release-loop/SKILL.md, skills/implementing/SKILL.md, skills/reviewing/SKILL.md, skills/retrospective/SKILL.md
  Test: scripts/test-plan-consumer-portability.sh
Interfaces:
  Consumes: marker pair `<!-- plan-consumer-contract: <skill>/v1 -->` … `<!-- end-plan-consumer-contract -->` (marker text unchanged by the move)
  Produces: one reference file per consumer holding its marker pair plus enclosed JSONL verbatim; one R8 pointer line per consumer core; a portability suite that resolves the pointer's exact destination and asserts marker-pair uniqueness per consumer tree
Test scenarios:
  happy: suite parses each consumer's contract from its reference file and all existing engine cases pass unchanged
  edge: marker pair present in both core and reference (stale copy) → uniqueness check fails naming both paths
  error: core pointer names a nonexistent reference file → suite fails naming the dangling path
  integration: `run_engine shared` cases still exercise implementing/release-loop/retrospective contract rows end to end (Covers S5)
Steps:
  1. Extend `scripts/test-plan-consumer-portability.sh`: fixture setup copies `skills/<name>/references/` (create dir if absent) alongside each consumer `SKILL.md`; contract lookup reads the consumer core, resolves the single R8 pointer line's `references/...` path, and loads the marker pair from that file; add a check asserting each consumer's marker pair appears exactly once across that consumer's core+references tree. Run the suite — it must fail against the unmoved tree (pointer absent), proving the new resolution path executes.
  2. For each consumer, move the exact block (markers inclusive, byte-verbatim per the spec extraction command) into `skills/<name>/references/plan-consumer-contract.md`, and replace it in core with one pointer: release-loop `When executing the --skip-plan gate, read references/plan-consumer-contract.md and follow it before proceeding.`; implementing `When running the plan eligibility pre-flight, read references/plan-consumer-contract.md and follow it before proceeding.`; reviewing `When entering a plan-scoped review, read references/plan-consumer-contract.md and follow it before proceeding.`; retrospective `When entering a plan-covering retro, read references/plan-consumer-contract.md and follow it before proceeding.` Adjacent minimum-contract prose stays in core untouched (spec Scope Out).
  3. Verify verbatim moves and their discrimination: `for name in release-loop implementing reviewing retrospective; do diff <(git show f2efda9:skills/$name/SKILL.md | awk '/plan-consumer-contract/,/end-plan-consumer-contract/') <(awk '/plan-consumer-contract/,/end-plan-consumer-contract/' skills/$name/references/plan-consumer-contract.md); done` prints nothing (invariance side); then flip one byte in a scratch copy of one reference file, rerun that consumer's diff against the scratch copy, observe non-empty output (changed-axis side), and delete the scratch copy.
  4. Run `bash scripts/test-plan-consumer-portability.sh`, then `bash scripts/validate.sh` and the remaining `scripts/test-*.sh`; all green, portability total ≥ U1's floor.
  5. Commit: "refactor(skills): move plan-consumer contracts to trigger-gated references (M1-M4)"
Acceptance: step 3 invariance diffs empty ×4 and the changed-axis probe non-empty; suite totals ≥ baseline floors; per consumer core: `grep -c '^{"decision"' skills/<name>/SKILL.md` = 0, `grep -c '<!-- plan-consumer-contract' skills/<name>/SKILL.md` = 0, and exactly one line matches `^When .*references/plan-consumer-contract\.md and follow it before proceeding\.$`; four reference files each contain exactly one marker pair.

## U3: Move release-loop's rare paths (M5, M6)

Execution note: characterization-first — the M-table "Core retains" column is the characterization; write it into core before deleting the sections.
Files:
  Create: skills/release-loop/references/transition-hooks.md, skills/release-loop/references/resume-and-archive.md
  Modify: skills/release-loop/SKILL.md
  Test: scripts/test-release-loop-worktree-default.sh (verify only), scripts/validate.sh (verify only)
Interfaces:
  Consumes: `## Approved-plan transition hooks` section; `## Resuming (\`resume\` argument)` + `## Completing and archiving` sections (extraction commands in the spec Assumptions table)
  Produces: two reference files verbatim; core retains — M5: the transition heading shapes (`## Release-loop Ship-cleanup transition`, `## Release-loop post-Ship completion transition`) for detection, the `.release-loop/.handoff/` inspection rule, and the blocked-by-silence invariant; M6: the schema-version rejection rule, the never-overwrite-live-progress rule, and the completion-report-names-verified-archive-path rule; plus two R8 pointers
Test scenarios:
  happy: full suite green; core retains all named rules verbatim
  edge: a plan declaring a transition heading with the reference file deleted → the pointer dangles; U7's R7 check (e) and the U2-style uniqueness principle catch it (recorded here as the designed failure mode, exercised by SC6 attack class (c))
  error: `bash scripts/validate.sh` [worktree-default] or [final-action] check fails → the moved text carried a pinned clause; move it back to core and reclassify the block boundary as a spec deviation (stop, addendum per step 4 rule) — never patch the validator to pass
  integration: U7's S2/S3 walkthroughs consume this unit's core/reference split (Covers S2, S3)
Steps:
  1. Record the two extraction outputs at HEAD and verify byte counts still equal 3,566 and 4,575 (they are untouched by U2; command: the spec Assumptions rows 4–5 commands).
  2. Write the core-retains lines into the sections' former positions as operative body prose (never inside HTML comments or code fences): M5 → heading-shape detection sentence naming both exact headings, the `.handoff/` inspection rule sentence, the blocked-by-silence invariant sentence, then the pointer `When an approved plan declares a Release-loop transition heading or .release-loop/.handoff/ is non-empty at Ship entry or resume, read references/transition-hooks.md and follow it before proceeding.` M6 → schema-version rejection sentence, never-overwrite-live-progress sentence, completion-report sentence, then the pointer `When the resume argument is given or the Retro exit condition holds, read references/resume-and-archive.md and follow it before proceeding.` Each retained sentence is copied verbatim from the moved section where it exists there; a retained sentence that must be newly condensed is an R10 `compressed` entry recorded in U6's inventory.
  3. Move both blocks verbatim into their reference files; verify (invariance side): `diff <(git show f2efda9:skills/release-loop/SKILL.md | awk '/^## Approved-plan transition hooks/,/^## Starting a new loop/' | sed \$d) skills/release-loop/references/transition-hooks.md` and `diff <(git show f2efda9:skills/release-loop/SKILL.md | awk '/^## Resuming/,/^## Gate handling/' | sed \$d) skills/release-loop/references/resume-and-archive.md` both print nothing; then flip one byte in a scratch copy of one reference and observe the same diff non-empty (changed-axis side); delete the scratch copy.
  4. Run `bash scripts/validate.sh`, `bash scripts/test-release-loop-worktree-default.sh`, `bash scripts/test-plan-consumer-portability.sh`, then the rest; all green, totals ≥ floors.
  5. Commit: "refactor(release-loop): move transition hooks and resume/archive to references (M5-M6)"
Acceptance: both invariance diffs empty and the changed-axis probe non-empty; `wc -c skills/release-loop/SKILL.md` < 12,000 (18,705 − 8,141 + retained/pointer lines); each of the three M5 retained rules and three M6 retained rules appears as body prose in the section that replaced its source (verified by extracting those sections and grepping outside comment/fence lines); exactly one pointer line each matching `^When .*references/transition-hooks\.md and follow it before proceeding\.$` and `^When .*references/resume-and-archive\.md and follow it before proceeding\.$`; full suite green.

## U4: Move the three small sections (M7–M9)

Execution note: skip-test-first — pure verbatim moves guarded by the existing suite and U7's R7 checks.
Files:
  Create: skills/shipping/references/capability-preflight.md, skills/designing/references/out-of-scope.md, skills/retrospective/references/out-of-scope.md
  Modify: skills/shipping/SKILL.md, skills/designing/SKILL.md, skills/retrospective/SKILL.md
  Test: scripts/test-retro-format-drift.sh (verify only), scripts/validate.sh (verify only)
Interfaces:
  Consumes: the three sections per the spec Assumptions row 6 extraction commands
  Produces: three verbatim reference files; M7 core retains the fail-closed rule sentence plus pointer `When entering shipping on a harness whose capabilities are unknown or degraded, read references/capability-preflight.md and follow it before proceeding.`; M8 core pointer `When asked why a dropped capability is absent, read references/out-of-scope.md and follow it before proceeding.`; M9 core pointer identical in form to M8's
Test scenarios:
  happy: full suite green; validate.sh check 16 (shipping Step 7/Step 8 pins) unaffected because Step 0 is disjoint from Steps 7–8
  edge: retro-format-drift extracts a retrospective section shifted by M9's removal → its `extract_section` calls are heading-anchored, not line-anchored, so removal of a trailing section must not affect them; a failure here means a pinned extraction crossed the moved boundary → fix per R6 in this same commit and record which case moved
  error: shipping's F18/merge-gate clauses (R5, f2efda9 wording) accidentally touched → `git diff f2efda9..HEAD -- skills/shipping/SKILL.md` may show only the Step 0 removal and pointer insertion; anything else reverts before commit
  integration: n/a — leaf moves; S1's byte criterion consumes the reductions
Steps:
  1. Verify section boundaries at HEAD equal the baseline bytes (942, 402, 220) via the spec extraction commands.
  2. Move each section verbatim to its reference file; insert the pointer (M7: fail-closed rule sentence copied verbatim from the moved section, then pointer) at the former position.
  3. Verify: three `diff` checks against the `git show f2efda9:...` extractions are empty (invariance side), plus one one-byte scratch-copy mutation showing a non-empty diff (changed-axis side, scratch deleted after); `git diff f2efda9..HEAD -- skills/shipping/SKILL.md` contains no hunk overlapping `## Step 7` or `## Step 8`.
  4. Run the full suite; all green, totals ≥ floors.
  5. Commit: "refactor(skills): move capability preflight and out-of-scope sections to references (M7-M9)"
Acceptance: three empty invariance diffs and one non-empty changed-axis probe; step 3 hunk check clean; the M7 fail-closed sentence present as body prose at shipping's former Step 0 position; per moved file exactly one line matching `^When .*references/capability-preflight\.md and follow it before proceeding\.$` (shipping) or `^When .*references/out-of-scope\.md and follow it before proceeding\.$` (designing, retrospective); full suite green with totals ≥ floors.

## U5: Compress the thirteen descriptions (R4) and build the routing map

Execution note: test-first — `scripts/test-plugin-skill-discovery.sh` and the SC2 byte command are the failing/passing oracles run before and after.
Files:
  Create: docs/reviews/2026-08-21-instruction-payload-slimming/description-routing-map.md
  Modify: all thirteen `skills/*/SKILL.md` frontmatter `description:` fields
Interfaces:
  Consumes: U1 baseline.md section (c) — the per-skill trigger-phrase and routing-clause inventory
  Produces: single-line descriptions totaling ≤ 3,200 bytes; a two-column-per-skill map — baseline entry (verbatim, from U1) → where it survives in the new description — with an empty reviewer-verdict column for the reviewing phase
Test scenarios:
  happy: SC2 command ≤ 3200; discovery suite green; every baseline trigger phrase present in the same skill's new description with non-inverted meaning
  edge: a description compresses below usefulness — the map's per-entry rows make the drop visible as an empty survival cell, which is a failure before commit
  error: a trigger phrase moved to a different skill's description → map row names a different file than its baseline row → failure (spec attack class (e) tests this at review)
  integration: n/a — S4's evidence is the measurement plus map
Steps:
  1. From U1 baseline.md section (c), build the map skeleton: one row per trigger phrase and per negative/routing clause, per skill.
  2. Rewrite each `description:` as one physical line, preserving every mapped entry on its own skill with non-inverted semantics; fill each row's survival cell with the new phrasing, quoted so that the survival text appears verbatim (substring) in that skill's new description.
  3. Run the mechanical completeness check: a `python3 -I` script that reads U1 baseline.md section (c) and the map, and fails naming the row if any baseline entry lacks a map row or any survival cell's quoted text is not a substring of the same skill's current description (invariance side: the real map passes; changed-axis side: delete one map row in a scratch copy, rerun, observe the named failure, delete the scratch). Then run `for f in skills/*/SKILL.md; do awk '/^description:/{f=1} f{print} /^---$/&&NR>1{exit}' "$f"; done | wc -c` → ≤ 3200; run `bash scripts/test-plugin-skill-discovery.sh` and `bash scripts/test-signal-drift.sh`; then the full suite.
  4. Commit map + descriptions: "refactor(skills): compress descriptions within routing-preservation map (R4)"
Acceptance: byte command ≤ 3200; full suite green with totals ≥ floors; the completeness check passes on the real map and fails on the deleted-row scratch; semantic non-inversion and same-skill meaning are U8's verdict column — mechanical presence is proven here, semantics are adjudicated there.

## U6: Compress core prose within R5 bounds and build the disposition inventory

Execution note: characterization-first — the R5 inviolable list at `f2efda9` wording is extracted and pinned before any edit.
Files:
  Create: docs/reviews/2026-08-21-instruction-payload-slimming/disposition-inventory.md
  Modify: skills/{designing,planning,implementing,reviewing,shipping,retrospective,release-loop}/SKILL.md
Interfaces:
  Consumes: R5 inviolable list (spec) at `git show f2efda9:...` wording — designing `<HARD-GATE>`; release-loop Design-gate row, `--auto` row, gate-approval-not-execution bullet, prepare-before-gate bullet, three worker-liveness defenses; planning step 14's twelve checks; retrospective Interview Protocol + Warrant sections; implementing per-unit steps 4 and 8 gates; shipping Step 7 (F18 inclusive) + base-topology gate
  Produces: seven compressed cores totaling ≤ 110,000 with U2–U4 reductions; an inventory with **exactly one row per scoped removed/changed baseline line** (a line with zero rows or two-plus rows is a violation) — classification (`moved`/`compressed`), original text verbatim, replacement text verbatim, one-line meaning-equivalence rationale naming what is preserved, empty reviewer-verdict column
Test scenarios:
  happy: SC1 command ≤ 110000; every R5 clause normalized-identical to its `f2efda9` extraction; full suite green
  edge: a compression touches a line inside an R5 clause → the pre-pinned extraction comparison fails before commit; revert that edit
  error: ceiling unreachable within R5/R10 bounds → stop and escalate to the user (spec Risks: never cut protected text to make a number)
  integration: R7 (U7) re-verifies every entry mechanically; reviewing phase adjudicates (Covers S6 jointly with U7)
Steps:
  1. Extract every R5 clause from `git show f2efda9:skills/<name>/SKILL.md` into a working pin list (whitespace-normalized SHA-256 per clause) committed as the inventory's appendix.
  2. Compress non-protected prose per skill — duplicated framing, restated schema content, multi-sentence connectives — recording every changed/removed scoped line as an inventory row in the same edit session. U2–U4 moved blocks are recorded as `moved` rows referencing their reference files; U3's newly condensed retained sentences (if any) enter as `compressed` rows here.
  3. After each skill, re-verify its R5 pins (normalize, hash, compare — invariance side) and once, on a scratch copy of one skill, mutate one word inside a pinned clause and observe the hash mismatch (changed-axis side; delete the scratch); run `bash scripts/validate.sh`; after all seven, run `wc -c skills/{designing,planning,implementing,reviewing,shipping,retrospective,release-loop}/SKILL.md | tail -1` → total ≤ 110000, then the full suite.
  4. Commit: "refactor(skills): compress non-protected core prose within inventory (R5/R10)"
Acceptance: SC1 ≤ 110000; every R5 pin matches; the inventory has exactly one row for every removed or changed baseline line of `git diff f2efda9..HEAD` over the seven bodies plus thirteen descriptions — added-only lines are replacement text and appear inside rows, never as their own rows (spot-verified here, mechanically proven by U7 check (b)); full suite green with totals ≥ floors.

## U7: R7 integrity script, parity walkthroughs, evidence assembly, SC7 registration

Execution note: test-first — the script's own checks are the tests; author them against known-bad fixtures first.
Files:
  Create: docs/reviews/2026-08-21-instruction-payload-slimming/verify-move-integrity.sh, docs/reviews/2026-08-21-instruction-payload-slimming/r7-output.md, docs/reviews/2026-08-21-instruction-payload-slimming/parity-walkthroughs.md
  Modify: ROADMAP.md
Interfaces:
  Consumes: `git diff f2efda9..HEAD -- skills/`; disposition-inventory.md; the nine reference files; the R5 pin appendix
  Produces: `verify-move-integrity.sh` (bash + `python3 -I` heredocs, runnable on CPython 3.9–3.14 per the repo gate) proving (a) removed-line set derived by the script itself from `git diff f2efda9..HEAD -- skills/`, never from a hand-maintained manifest, (b) every removal classified in the inventory by **exactly one** row — no row, an out-of-set classification, and duplicate or conflicting rows for one line are each named violations, (c) every `moved` block normalized-identical at its destination, (d) every R5 clause normalized-identical in core, (e) every reference file reachable from exactly one R8-form pointer — zero pointers and two-plus pointers are both named violations; committed run output; M1–M9 fired/not-fired walkthrough records; one new ROADMAP carry-forward row
Test scenarios:
  happy: script exits 0 on HEAD; clean run output committed beside the self-test failures
  edge: `--self-test` mode injects one defect per failure mode into a temporary fixture tree and requires a nonzero exit naming it — (a1) an extra deleted line injected into the fixture tree that must appear in the script-derived removal set and be flagged (proves check (a) reads the diff, not a manifest), (b1) an unclassified deleted line, (b2) an inventory row classified `reworded` (out-of-set), (b3) a second, conflicting row for an already-classified line, (c) a token-stubbed reference file, (d) a one-word-mutated R5 clause in core, (e1) a dangling pointer, (e2) a duplicate pointer to one reference. The clean HEAD run is each check's invariance side; each injected fixture is its changed-axis side — both observed results are recorded per check in r7-output.md
  error: a `--self-test` injection that the script accepts → the check cannot fail; fix the script before any HEAD run counts as evidence
  integration: parity walkthroughs — M1–M4 cite the migrated portability suite cases by name; M5–M9 each get a fired and a not-fired record with reproducible fixture setup commands (fixture `.release-loop/` state for M6; fixture plan with/without a transition heading for M5; degraded-harness note for M7; reader-question form for M8/M9) and both texts' decision outcomes, left open for the independent reviewer's verbatim confirmation in U8 (Covers S1, S2, S3)
Steps:
  1. Write `verify-move-integrity.sh` implementing checks (a)–(e) with the eight-injection `--self-test` mode above.
  2. Run `--self-test` (all eight injected defects caught, each diagnostic recorded), then run against HEAD; write both outputs verbatim to r7-output.md.
  3. Write parity-walkthroughs.md per the integration scenario above.
  4. Run `wc -c skills/{designing,planning,implementing,reviewing,shipping,retrospective,release-loop}/SKILL.md | tail -1` and `for f in skills/*/SKILL.md; do awk '/^description:/{f=1} f{print} /^---$/&&NR>1{exit}' "$f"; done | wc -c` over HEAD and record both results in r7-output.md (≤ 110000 and ≤ 3200).
  5. Add the ROADMAP carry-forward row, defining its own paths: installed-plugin-cache parity — with `CACHE=~/.claude/plugins/cache/compound-loop/compound-loop/<released version>`, re-run the two step 4 commands against `$CACHE/skills` and run `diff -rq "$CACHE/skills" skills` at the released tag → no differences; owner: release-loop completion gate of the release shipping this change; evidence path `docs/reviews/2026-08-21-instruction-payload-slimming/cache-parity.md`.
  6. Run the full suite; commit everything: "chore(evidence): commit R7 integrity run, parity walkthroughs, SC7 registration"
Acceptance: r7-output.md shows all eight self-test injections caught with named diagnostics and a clean HEAD run of all five checks; parity-walkthroughs.md covers 9/9 move units, each record carrying fenced runnable fixture commands, both stated decision outcomes, and a baseline-equivalence statement — a row reduced to a title fails this acceptance; ROADMAP row present naming owner, `$CACHE` definition, and evidence path; full suite green with totals ≥ floors.

## U8: Independent adjudication and attack round

Execution note: skip-test-first — this unit dispatches the independent reviewer and commits their verbatim output; the implementer authors nothing under test.
Files:
  Create: docs/reviews/2026-08-21-instruction-payload-slimming/adjudication-and-attacks.md
  Modify: docs/reviews/2026-08-21-instruction-payload-slimming/disposition-inventory.md, docs/reviews/2026-08-21-instruction-payload-slimming/description-routing-map.md
Interfaces:
  Consumes: the U6 inventory and U5 map (verdict columns pending); U7's r7-output.md and parity-walkthroughs.md; frozen validators (no validator commit after U6)
  Produces: reviewer identity record — the dispatch lane per `references/dispatch-degradation.md`, the exact command or agent invoked, model/session identifiers where available, and an explicit statement that this identity authored none of the implementation commits — plus the transcript persisted verbatim (never summarized); filled verdict columns; six attack records; the assertion-inventory comparison verdict
Test scenarios:
  happy: every `compressed` entry and every map row carries `accepted`; all six attack classes caught by the invariant each targets; M5–M9 walkthroughs carry the reviewer's verbatim confirmation; the reviewer's baseline-vs-HEAD assertion-inventory comparison (U1 section (d) vs the same extraction at HEAD, per validator) reports no deleted or no-op-substituted assertion, recorded verbatim
  edge: a `compressed` entry or map row verdict resolves to `rejected` → the entry's edit is reverted or converted to `moved` in a follow-up commit before Ship; because that commit changes the implementation tree, the R7 script reruns and **the attack round restarts against the new tree** — each attack record carries the implementation-tree sha `git log -1 --format=%H -- skills/ scripts/` observed at attack time, and SC6 is satisfied only when that recorded sha equals the same command's output at Ship entry (evidence-only commits under `docs/reviews/` and `ROADMAP.md` never invalidate attacks); a verdict left pending or resolving outside {accepted, rejected} blocks Ship as an unfilled gate, never a soft note
  error: an attack is caught only by an unrelated check, or not caught → blocking finding against SC6; an attack that cannot be executed or whose evidence is incomplete is recorded `unresolved` and blocks Ship exactly like `not caught` — never silently skipped; an attack outcome outside {caught-by-target, caught-by-unrelated, not-caught, unresolved} is itself a blocking finding; a validator edit in response restarts the attack round per the freeze rule
  integration: attack classes (a)–(f) per the spec Testing section, each a single-defect mutant paired with a passing control fixture, authored by the reviewer after U6 (implementation freeze), run against unmodified HEAD validators and U7's script; results recorded with the failing check named per attack (Covers S6)
Steps:
  1. Dispatch the independent reviewer with the verbatim mandate block from Architecture notes plus paths to the inventory, map, r7-output.md, parity-walkthroughs.md, and baseline.md; require per-item verdicts, the six attacks with controls, and the per-validator assertion-inventory comparison against U1 section (d).
  2. Persist the reviewer transcript verbatim to adjudication-and-attacks.md with the reviewer identity record and dispatch timestamp; fill both verdict columns from it.
  3. Execute any `rejected`-entry repairs (revert or convert to `moved`), rerun `bash scripts/validate.sh` plus the R7 script, and restart the attack round and re-dispatch verdicts against the new implementation tree for all affected items.
  4. Run the full suite; commit: "docs(review): commit independent adjudication and attack round"
Acceptance: zero pending or out-of-set verdicts across both artifacts; six attack records each naming its targeted invariant as the failing check, its passing control fixture, and an implementation-tree sha (`git log -1 --format=%H -- skills/ scripts/`) equal to that command's output at Ship entry; the assertion-inventory comparison recorded with a no-loss verdict per validator; M5–M9 confirmations present; full suite green with totals ≥ floors.

## Mutation/failure-state matrix

No stateful ceremony in the deliverable; no mutation/failure-state matrix required.

(The units publish nothing outside the local repository: no push, remote creation, registry publication, release, or visibility change occurs in any unit — outward actions belong to the `shipping` phase under its own gates. U1's baseline worktree is read-only and removed within the unit.)

## Carry-forward trigger audit

Tracker examined: `ROADMAP.md` at commit `c123b70` (Future candidates, 13 open rows; Carry-forward from retros, 10 open rows — struck-through Done rows excluded).

Fired rows:

| Tracker row | Class | What fired it | Disposition |
|---|---|---|---|
| "A success criterion that fires after Retro cannot be measured inside that Retro's Phase 3 pass" (2026-08-03 retro) | event-based | Spec SC7 declares a post-Retro criterion (installed-cache parity at the released tag) | Folded: U7 step 5 registers the ROADMAP row assigning proof to the release-loop completion gate with the exact evidence path — precisely the row's prescribed next step |
| "Dispatched agents that commit do not inherit `SSH_AUTH_SOCK`" (2026-08-14 retro) | event-based | This cycle dispatches committing subagents if the Subagent-driven handoff is chosen | Folded: Architecture notes bind the orchestrator to pass the live socket and verify `%G?` = `G` per commit, recorded in the ledger |
| Conformance suite (Future candidates; firing recorded 2026-08-14, latched) | event-based (latched fired) | Prior recorded firing counts regardless of current observability | Deferred to Follow-Up Work: building the suite is its own cycle; this cycle adds no new fired case (its attack fixtures are cycle evidence, not suite members) |
| "Forced-failure matrices can omit exact partial durable state" (2026-08-05 retro; firing recorded in PR #15, durable rule remains) | edit-based (latched fired) | Recorded firing latches; its durable-rule trigger ("next planning-contract change") is NOT met — this plan compresses `planning` prose without changing the matrix contract, and step 10/schema text is R5-adjacent behavior this spec's Scope Out forbids changing | Deferred to Follow-Up Work with reason |
| "Review verifies conformance instead of attacking the invariant" (retro T6, P1; firing recorded in PR #15, durable rule remains) | edit-based (latched fired) | Same latching; durable-rule trigger ("next change to `reviewing`'s dispatch contract") not met — compression is meaning-preserving, not a contract change | Deferred to Follow-Up Work; this cycle's own reviews already apply the rule via the spec's SC6 attack contract |
| "Finding severity graded against blast radius" (retro T7, P2; firing recorded in PR #15, durable rule remains) | edit-based (latched fired) | Same latching; triage-contract trigger not met | Deferred to Follow-Up Work; the review-dispatch mandate in Architecture notes carries the grade-by-threatened-criterion instruction for this cycle |
| "Facilitator and reviewer output never persisted" (2026-08-15 retro) | edit-based | File list touches `skills/reviewing/SKILL.md` and `skills/retrospective/SKILL.md`; the interview protocol and dispatch-step semantics are R5-protected/meaning-preserved, but the row's edit condition (touch) is met on the mechanically checkable reading | Folded in practice: the spec's Verification Independence clause mandates verbatim reviewer persistence for every artifact this cycle produces; the durable skill-text encoding is Deferred (behavior change out of spec scope) |
| Schema validators + fixtures (Future candidates; plan/v1 half's firing recorded 2026-07-26, latched; review-envelope half still open) | event-based (latched fired) | Prior recorded firing counts regardless of the half already closed | Deferred to Follow-Up Work: this cycle changes neither plan/v1 nor review-envelope schemas (spec Scope Out forbids `schemas/` changes); the review-envelope half stays under its original trigger |
| "gh pr merge --delete-branch can merge remotely then exit 1" (2026-08-16 retro T5; firing recorded in PR #15, latched; durable rule remains) | edit-based (latched fired) | Recorded firing latches; the durable-rule trigger ("next shipping merge-command change") is NOT met — shipping Steps 7–8 stay byte-identical per U4 acceptance | Deferred to Follow-Up Work with reason; the split-operations rule already lives in shipping's shipped text from PR #17, so no in-cycle action is lost |

Unobservable rows: none — every open drift-based record named by a row is observable at planning time, and no open row is drift-based (all classify as edit- or event-based; the tiebreak rule was needed only for the PR #15-latched rows above, each resolved edit-based).

Not fired (verified): "test-body-seal evidence publication" (edit-based — file untouched); "final approval coexisting with outside-diff finding" (edit-based on merge gates — R5-protected, unchanged); Session-history search, compound-refresh headless auto-apply, Cross-round deepening suppression, Demo/evidence capture, Project-defined lane schema (event — no second project defines custom lanes here, and `reviewing`'s lane text moves nothing), Ambient compound triggers, Gemini support verification, Evidence-tier vocabulary, Skill-level trace evidence (events, none occur here); New-skill distinctness gate (event — reference files are not new skills; no 14th skill is proposed); Release-loop phase-worker dispatch (event — fires only after this cycle merges; its disposition belongs to the retro).

Attestation: classification performed against `ROADMAP.md` as of `c123b70` diffed against this plan's File structure table; re-run at step 14 self-review against the final unit set with no divergence.

## Deferred to Follow-Up Work

- Conformance suite build (Future candidates row) — own cycle; this plan adds attack fixtures as archived evidence only.
- Durable-rule encodings for the three PR #15-latched rows (matrix-contract requirement, cheapest-conforming-counterexample requirement in `reviewing`, grade-by-threatened-criterion in the triage contract) — each is an observable behavior addition this spec's Scope Out rejects; they remain tracked in ROADMAP with their original triggers.
- Schema validators + fixtures (latched row) — no schema change in this cycle by spec Scope Out; the review-envelope half remains under its original trigger.
- Split-merge-operations durable rule (latched `gh pr merge` row) — its trigger (a shipping merge-command change) does not occur here; shipping Steps 7–8 are R5-preserved.
- Durable verbatim-reviewer-persistence encoding in `reviewing`/`retrospective` skill text — same Scope Out reason; the practice is honored in-cycle by spec mandate.
- Release-loop phase-worker dispatch — ROADMAP Future-candidates row; fires after this cycle merges.
- Runtime/wall-clock optimization of the test suites — spec Scope Out.
- Revisiting the R7-archive decision — deferred behind its natural trigger: the first regression that a permanent baseline-keyed integrity check would have caught.

## Open unknowns

Planning-time: none. (The baseline contradiction was the single blocker; resolved by committed Addendum 014 before this draft.)

Implementation-time (deferred by design):
- Exact compressed wording per description and per core-prose region, and the per-skill allocation of the ~13.5KB compression needed beyond moves to reach 110,000 — bounded by R5 pins and the R10 inventory, adjudicated at review.
- Whether any `test-signal-drift.sh` / `test-retro-format-drift.sh` case needs a path or line update after M4/M9 (expected no-op; discovered by running them in U2/U4 and fixed in the same commit under R6 if not).
- Final byte totals (SC1 measured value below the 110,000 ceiling; whether the 100,000 stretch is reachable without protected-text pressure).
- Exact fixture-repo shapes for the M5/M6 parity walkthroughs (reproducible commands recorded in the artifact when written).
- Whether `verify-move-integrity.sh`'s Python heredocs need registration in the python-compat gate's artifact list (only if `validate.sh` flags them; the script targets 3.9-compatible syntax regardless).
