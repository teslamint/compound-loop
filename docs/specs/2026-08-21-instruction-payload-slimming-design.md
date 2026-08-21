---
title: Instruction Payload Slimming
status: approved
date: 2026-08-21
schema: spec/v1
---

# Instruction Payload Slimming Design

_Created 2026-08-21._

## Overview

A full release-loop cycle loads 131,746 bytes of always-resident skill text (six phase skills plus the orchestrator), and every session — looping or not — carries 4,561 bytes of skill descriptions. Much of that resident text is rare-path procedure (resume reconstruction, transition-override ceremony, archive interruption recovery) or machine-consumed JSONL contract fixtures that no ordinary turn needs. This spec slims each skill to a core of always-needed gates, sequencing, and behavior rules by (a) moving nine enumerated blocks into trigger-gated reference files and (b) inventoried, meaning-preserving compression of non-protected prose — never deleting or weakening gate or integrity text. A second cycle (phase-worker dispatch tiers) is out of scope and already registered as a ROADMAP row.

Independent design review (heterogeneous reviewer, `codex exec -s read-only`, 2026-08-21) ran two rounds against this spec's wording; round 1's eleven findings and round 2's nine findings (all self-attestation seams in the verification design) are incorporated. The reviewer's feasibility computation bounds move-only savings at 18,745 bytes, so the byte ceiling is 105,000 (defensible), with 95,000 as an explicitly conditional stretch.

## Verification Independence (definitions used throughout)

- **Implementer**: whoever edits skill text, tests, or scripts in this cycle.
- **Independent reviewer**: a fresh-context or heterogeneous lane per `references/dispatch-degradation.md` (plugin root), with a recorded identity distinct from the implementer. Reviewer output is persisted **verbatim** in the committed evidence artifact at dispatch time, never summarized into it.
- **Baseline revision**: `da1ffbf`. Every baseline-derived artifact (byte figures, case totals, description mapping) is generated mechanically from `git show da1ffbf:...` or a worktree checked out at it — never transcribed by hand and never re-established mid-cycle.
- **Normative block definition**: each move unit's block is exactly the byte output of its extraction command in the Assumptions table, headings and marker lines inclusive. The M-table byte column restates those commands' outputs; where prose and command disagree, the command governs.

## User Scenarios

### S1: A new loop starts with a slim orchestrator

A user runs `/release-loop my-feature`. The harness loads `skills/release-loop/SKILL.md` at its core size; the transition-override ceremony, resume reconstruction, and archive interruption recovery text is not in context because no trigger condition has fired.

### S2: An ordinary loop ships without reading ceremony text

A loop whose approved plan declares no `## Release-loop Ship-cleanup transition` or `## Release-loop post-Ship completion transition` heading passes Ship without ever reading the transition-hooks reference. The core retains the heading shapes to detect declarations, the `.handoff/` inspection rule, and the one-line pointer that mandates reading the reference before any transition runs.

### S3: A resume fires its trigger pointer

A user runs `$release-loop resume`. The core's resume section is a compact trigger: validate the live record's schema, then read `references/resume-and-archive.md` and follow it. The full reconstruction and archive-interruption procedure enters context only now, when it is actually needed.

### S4: A non-loop session pays less fixed cost

A session that never touches the release pipeline still receives every skill description in its skill list. After this change the thirteen descriptions total at most 3,200 bytes (currently 4,561) while retaining every invocation trigger phrase, on the same skill it triggers today, with non-inverted semantics.

### S5: The test suite still guards the moved contracts

`bash scripts/validate.sh` and every `scripts/test-*.sh` pass, with per-suite reported case totals at or above the totals a baseline-revision run reports. The five affected validators (`test-plan-consumer-portability.sh`, `test-signal-drift.sh`, `test-retro-format-drift.sh`, `test-plugin-skill-discovery.sh`, `validate.sh`) follow moved text to its new reference path per the R6 inventory, asserting the same protected properties — never merely a token at the old path.

### S6: A reviewer proves the change lost nothing

During the cycle, a move-integrity script derives the set of removed baseline lines independently from `git diff` against the baseline revision, requires every removal to be classified in the disposition inventory, verifies moved blocks normalized-identical at their destinations, verifies every R5 inviolable clause unchanged in core, and verifies every new reference reachable from exactly one trigger pointer. The independent reviewer adjudicates every `compressed` entry. All output is committed under `docs/reviews/`.

## Scope

### In

**Move units (fixed here, not deferred to planning).** Blocks follow the Normative block definition above. `planning` sequences these into units but does not reselect them; adding or dropping a move unit is a spec deviation.

| ID | Source | Block (per extraction command) | Bytes | Destination | Trigger pointer condition | Core retains |
|---|---|---|---|---|---|---|
| M1 | `release-loop/SKILL.md` | Contract markers plus enclosed JSONL | 2,245 | `skills/release-loop/references/plan-consumer-contract.md` | Executing the `--skip-plan` gate | Minimum-contract prose |
| M2 | `implementing/SKILL.md` | Contract markers plus enclosed JSONL | 3,755 | `skills/implementing/references/plan-consumer-contract.md` | Plan eligibility pre-flight | Same as M1 |
| M3 | `reviewing/SKILL.md` | Contract markers plus enclosed JSONL | 1,609 | `skills/reviewing/references/plan-consumer-contract.md` | Plan-scoped review entry | Same as M1 |
| M4 | `retrospective/SKILL.md` | Contract markers plus enclosed JSONL | 1,431 | `skills/retrospective/references/plan-consumer-contract.md` | Plan-covering retro entry | Same as M1 |
| M5 | `release-loop/SKILL.md` | `## Approved-plan transition hooks` section, heading inclusive | 3,566 | `skills/release-loop/references/transition-hooks.md` | Approved plan declares a transition heading, or `.release-loop/.handoff/` is non-empty at Ship entry/resume | Heading shapes for detection; `.handoff/` inspection rule; blocked-by-silence invariant |
| M6 | `release-loop/SKILL.md` | The two consecutive sections `## Resuming (`resume` argument)` and `## Completing and archiving`, headings inclusive (deliberate two-section unit) | 4,575 | `skills/release-loop/references/resume-and-archive.md` | The `resume` argument; Retro exit condition holding | Schema-version rejection rule; never-overwrite-live-progress rule; completion report names the verified archive path |
| M7 | `shipping/SKILL.md` | `## Step 0: Capability Preflight` section, heading inclusive | 942 | `skills/shipping/references/capability-preflight.md` | Shipping entry on a harness whose capabilities are unknown/degraded | One-line pointer plus the fail-closed rule |
| M8 | `designing/SKILL.md` | `## Out of Scope` section, heading inclusive | 402 | `skills/designing/references/out-of-scope.md` | Reader asks why a dropped capability is absent | One-line pointer |
| M9 | `retrospective/SKILL.md` | `## Out of Scope (v0.2 hook points ...)` section, heading inclusive | 220 | `skills/retrospective/references/out-of-scope.md` | Same as M8 | One-line pointer |

Move total: 18,745 bytes.

**Compression (inventoried)**
- R4: Frontmatter `description:` fields across all thirteen skills compress to a 3,200-byte total ceiling while preserving every invocation trigger phrase on its current skill with non-inverted semantics, and preserving every negative/routing clause ("do not trigger for...", when-not-to-use distinctions).
- R5: Core prose outside the move units may be compressed only where meaning is preserved, and never on the **inviolable list**, whose wording must survive byte-identical after whitespace normalization: the `designing` `<HARD-GATE>` block; `release-loop`'s Design-gate row and `--auto` flag row, "Gate approval is not execution authorization" bullet, "Prepare before the gate resolves" bullet, and the three Worker-liveness defenses; `planning` step 14's twelve self-review checks; `retrospective`'s Interview Protocol and Warrant-for-not-probed sections; `implementing`'s fixture evidence gate (per-unit step 4) and observable deviation gate (per-unit step 8); `shipping`'s merge gate (Step 7) and pre-push base-topology gate. Inviolable clauses stay in core; moving one is prohibited.
- R10 (disposition inventory): scope is exactly the seven skill bodies plus the thirteen `description:` fields — validator and script changes are governed by R6, not R10. Every scoped baseline line removed or changed between the baseline revision and HEAD is classified exactly one of `moved` (appears normalized-identical in a destination reference) or `compressed` (entry records original text, replacement text, and a one-line meaning-equivalence rationale); anything unclassified is a violation. Connective-framing drops are `compressed` entries. **Adjudication**: the independent reviewer marks every `compressed` entry accepted or rejected; a rejected entry is reverted or converted to `moved` before Ship. The inventory with reviewer verdict column is a committed artifact under `docs/reviews/`.

**Test migration and verification**
- R6: The five affected validators migrate per this inventory, each preserving what it guards today:
  - `scripts/test-plan-consumer-portability.sh` — its fixture copy includes `skills/*/references/` (today it copies only the four `SKILL.md` files); its parser resolves the exact destination the core pointer names; a new check asserts each consumer's contract marker pair exists exactly once across that consumer's core+references tree (kills the duplicate-marker/stale-copy attack).
  - `scripts/test-signal-drift.sh` — mutation targets and expected diagnostics (file name, line) follow the text they mutate; diagnostics keep naming the file that actually carries the clause.
  - `scripts/test-retro-format-drift.sh` — heading-range extractions and direct SKILL.md mutations follow moved sections; case count does not decrease.
  - `scripts/test-plugin-skill-discovery.sh` — single-line `name:`/`description:` frontmatter assertions unchanged; compressed descriptions must still pass.
  - `scripts/validate.sh` — structural checks keyed to planning/retrospective/release-loop/shipping skill files updated to the new locations.
  No assertion is deleted, and no case is replaced by a no-op: the independent reviewer compares the baseline-revision assertion inventory against HEAD's per validator and records the comparison verbatim in the evidence artifact. Token/count greps upgrade to structural invariants (marker-pair uniqueness, JSONL row-for-row parse, clause-complete normalized comparison).
- R7: A move-integrity script (cycle-scoped, committed) proves: (a) the removed-line set is derived from `git diff <baseline>..HEAD` over the R10 scope by the script itself, never from a hand-maintained manifest; (b) every removal is classified per R10; (c) every `moved` block is normalized-identical at its destination; (d) every R5 clause is normalized-identical in its core; (e) every new reference file is reachable from exactly one R8 trigger pointer. Output committed under `docs/reviews/`.
- R8: Trigger pointers use one standard form so review can audit them mechanically: a single imperative line `When <condition>, read <references/file.md> and follow it before proceeding.`

### Out

- Phase-worker dispatch tiers, model routing, and any change to `references/dispatch-degradation.md` semantics — registered this session as the ROADMAP Future-candidates row "Release-loop phase-worker dispatch" (not a success criterion of this spec; already satisfied and owned by a future `designing` cycle).
- Deleting, weakening, or rewording any gate or integrity clause (R5 list). Rejected by design.
- Changing any skill's observable behavior: same gates, same exit conditions, same escalation paths.
- Changing `schemas/`, `scripts/release-publication.sh`, or the plan/spec/retro document schemas.
- Compressing `docs/` (solutions, retros, specs, plans) — instruction payload only.
- Runtime/wall-clock optimization of test scripts — separate concern.
- Moving the minimum-contract prose adjacent to M1–M4 (it is behavioral and stays in core), and any move unit not listed in the M-table.

## Assumptions and Preconditions

| Claim | Command | Observed at | Observed result | Evidence source |
|---|---|---|---|---|
| The seven always-resident bodies total 131,746 bytes (baseline revision for R7) | `wc -c skills/{designing,planning,implementing,reviewing,shipping,retrospective,release-loop}/SKILL.md` | `2026-08-21T13:40:21Z` | `131746 total` | Working tree at `da1ffbf`, branch `main` |
| Thirteen skill descriptions total 4,561 bytes | `for f in skills/*/SKILL.md; do awk '/^description:/{f=1} f{print} /^---$/&&NR>1{exit}' "$f"; done \| wc -c` | `2026-08-21T13:40:21Z` | `4561` | Working tree at `da1ffbf` |
| M1–M4 (markers inclusive) total 9,040 bytes | `for f in skills/{release-loop,implementing,reviewing,retrospective}; do awk '/plan-consumer-contract/,/end-plan-consumer-contract/' $f/SKILL.md \| wc -c; done \| paste -sd+ - \| bc` | `2026-08-21T13:40:21Z` | `9040` (2245+3755+1609+1431) | Working tree at `da1ffbf` |
| M5 (heading inclusive) measures 3,566 bytes | `awk '/^## Approved-plan transition hooks/,/^## Starting a new loop/' skills/release-loop/SKILL.md \| sed \$d \| wc -c` | `2026-08-21T13:40:21Z` | `3566` | Working tree at `da1ffbf` |
| M6 (two sections, headings inclusive) measures 4,575 bytes | `awk '/^## Resuming/,/^## Gate handling/' skills/release-loop/SKILL.md \| sed \$d \| wc -c` | `2026-08-21T13:40:21Z` | `4575` | Working tree at `da1ffbf` |
| M7, M8, M9 (headings inclusive) measure 942, 402, 220 bytes | `awk '/^## Step 0: Capability Preflight/,/^## Step 1:/' skills/shipping/SKILL.md \| sed \$d \| wc -c`; `awk '/^## Out of Scope/,0' skills/designing/SKILL.md \| wc -c`; `awk '/^## Out of Scope/,0' skills/retrospective/SKILL.md \| wc -c` | `2026-08-21T13:44:56Z` | `942`, `402`, `220` | Working tree at `da1ffbf` |
| `test-plan-consumer-portability.sh` references the four consumer SKILL.md paths 11 times (3+3+3+2) | `grep -o 'skills/[a-z-]*/SKILL.md' scripts/test-plan-consumer-portability.sh \| sort \| uniq -c` | `2026-08-21T13:44:56Z` | implementing 3, release-loop 3, retrospective 3, reviewing 2 | Working tree at `da1ffbf` |
| `validate.sh` passes in the working tree where this spec was drafted (sanity check only — **not** the baseline suite evidence; SC4's baseline case totals must come from a clean worktree checked out at `da1ffbf`) | `bash scripts/validate.sh` | `2026-08-21T13:45:12Z` | `ALL CHECKS PASSED` | Working tree at `da1ffbf` plus this spec draft and one ROADMAP row |

## Architecture

Each skill becomes **slim core + trigger-gated references**:

- **Core** (`SKILL.md`): entry/exit/gates, sequencing, behavior rules a majority of loops execute, the R5 inviolable clauses, and R8 trigger pointers.
- **References** (`skills/<name>/references/*.md`): the M-table blocks, loaded only when a pointer's condition fires. This extends the repo's existing pattern (`planning/references/stateful-ceremony-matrix-example.md`, `reviewing/references/lanes.md`); no new mechanism.
- **Commit discipline**: every commit is classified move or compression. Move commits (each carrying the test migration it necessitates) precede compression commits; a validator change serving both classes lands with the move commit that necessitates it. Every intermediate commit keeps the full suite green.
- **Move discipline**: moves are verbatim per the Normative block definition; anything not verbatim is a `compressed` R10 entry.

Data flow is unchanged: skills still read `.release-loop/progress.md`, plan frontmatter, and each other's terminal states exactly as today.

## Testing

- Full suite green at every commit: `bash scripts/validate.sh` plus every `scripts/test-*.sh`. Baseline case totals come from running the suites in a worktree checked out at the baseline revision, recorded in the evidence artifact **before** any test edit lands; HEAD totals must be ≥ those.
- Move integrity: R7 script output plus the R10 disposition inventory (with reviewer verdicts) committed under `docs/reviews/`.
- Invariant attack (repo convention): after implementation freeze, the **independent reviewer** — never the implementer — authors at minimum one attack per class: (a) token-only stub of a moved block, (b) truncated JSONL row set at the new path, (c) dangling trigger pointer, (d) duplicate marker pair (stale copy left in core plus reference copy), (e) trigger phrase preserved but semantically inverted or reassigned to the wrong skill's description, (f) a `compressed` entry that drops an operative clause. Each attack is a **single-defect mutant** paired with a control fixture (the same fixture with the mutation removed) that must pass, and it counts as caught only when the failing check is the invariant that class targets — an unrelated failure does not count. Attacks run against the **unmodified HEAD validators** (no post-hoc special-casing; validators do not change between freeze and attack evaluation, and any validator change after a caught attack restarts the attack round). Evidence committed with the R7 output.
- Behavior parity: for each move unit M1–M9, a fired/not-fired walkthrough pair — the trigger condition satisfied on a fixture (e.g. a fixture `.release-loop/` state for M6, a fixture plan declaring a transition heading for M5) and the same fixture without the trigger. Each record contains the reproducible fixture setup commands and both texts' decision outcomes. M1–M4 take this from the migrated portability suite; for M5–M9 the **independent reviewer executes or verifies** each walkthrough and the record carries the reviewer's verbatim confirmation.

## Risks

- **A trigger never fires and its reference goes unread** → behavior silently lost. Mitigated by R8's single audited pointer form, R7 check (e), attack class (c), and the per-unit fired/not-fired parity walkthroughs.
- **Compression weakens a gate in spirit while passing normalization** → R5 forbids touching listed clauses; every other rewording is an R10 `compressed` entry adjudicated by the independent reviewer; attack class (f) tests the inventory check.
- **Plugin cache drift masks the change at the loading surface** (recurred twice; `docs/solutions/conventions/plugin-cache-version-drift.md`) → Success Criterion 7 registers the installed-cache parity obligation with an exact evidence path and the release gate as owner, per the repo's post-Retro-criterion rule.
- **Test migration accidentally narrows what a test guards** → R6 per-validator inventory plus reviewer assertion-inventory comparison; baseline-revision case floors; attack classes (a)–(d).
- **Byte targets tempt deletion of load-bearing prose** → ceilings are success criteria, not licenses; R7 derives removals from `git diff` and every removal must be classified and adjudicated. If a ceiling is unreachable within R5/R10 bounds, the cycle escalates to the user rather than cutting protected text.

## Success Criteria

1. The seven always-resident skill bodies total at most 105,000 bytes (baseline 131,746, a ≥20% reduction), with every byte of reduction accounted for by the R10 disposition inventory. 95,000 is a stretch target permitted only through additional inventoried compression, never through deletion.
   - **Measured by**: `wc -c skills/{designing,planning,implementing,reviewing,shipping,retrospective,release-loop}/SKILL.md | tail -1` → total ≤ 105000, AND criterion 5 passing over the same HEAD.
2. The thirteen skill descriptions total at most 3,200 bytes.
   - **Measured by**: `for f in skills/*/SKILL.md; do awk '/^description:/{f=1} f{print} /^---$/&&NR>1{exit}' "$f"; done | wc -c` → ≤ 3200.
3. Description routing survives compression.
   - **Measured by**: rubric — the baseline side of the per-skill mapping table is generated mechanically from `git show da1ffbf:skills/<name>/SKILL.md` (trigger phrases and negative/routing clauses); the independent reviewer re-derives it, then confirms each entry appears in the **same skill's** new description with non-inverted meaning. Pass = zero dropped, moved, or inverted entries; the table with reviewer verdicts is committed with the R7 evidence.
4. The full validation suite passes with no lost coverage.
   - **Measured by**: `bash scripts/validate.sh` exit 0; each `scripts/test-*.sh` exit 0; each suite's self-reported case/pass total ≥ the total from the baseline-revision run recorded before any test edit; the reviewer's assertion-inventory comparison (R6) reports no deleted or no-op-substituted assertion.
5. Move integrity holds.
   - **Measured by**: R7 script exit 0, deriving removals from `git diff <baseline>..HEAD` itself; committed output names each moved block with destination, each `compressed` entry with original/replacement/rationale **and an accepted verdict from the independent reviewer**, and each verified R5 clause.
6. The verification mechanisms discriminate: every reviewer-authored attack from the six enumerated classes is rejected by unmodified HEAD validators.
   - **Measured by**: attack evidence committed under `docs/reviews/` naming the attack author (independent reviewer identity), per attack the failing check (or rubric row) and its diagnostic; pass = every attack caught, all six classes represented, zero validator edits between freeze and evaluation.
7. The loading-surface parity obligation is registered, owned, and carries an exact evidence path.
   - **Measured by**: a ROADMAP carry-forward row exists assigning installed-plugin-cache parity measurement (criteria 1–2 commands re-run against the cache; `diff -rq <cache>/skills skills` at the released tag → no differences) to the release that ships this change, with the release-loop completion gate as proof owner and the exact evidence path named — the repo's established pattern for criteria that fire after Retro. If that release happens within this cycle, the measurement itself is run and the row marked Done.
8. Behavior parity evidence exists for every move unit.
   - **Measured by**: the committed evidence artifact contains one fired and one not-fired walkthrough (or suite reference for M1–M4) per M-table row, each with reproducible fixture commands and, for M5–M9, the independent reviewer's verbatim confirmation; pass = 9/9 rows covered with baseline-equivalent outcomes.

## Open Decisions

1. **Whether the R7 move-integrity script is retained as a permanent regression test or archived as cycle evidence** — owner: `planning`. Retention adds a maintenance surface keyed to a git baseline; archiving keeps the suite lean. Decide against the repo's existing test-suite conventions.
