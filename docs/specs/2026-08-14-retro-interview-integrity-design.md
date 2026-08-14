---
title: Retro Interview Integrity
status: draft
date: 2026-08-14
schema: spec/v1
---

# Retro Interview Integrity Design

_Created 2026-08-14. Revised 2026-08-14 after two independent reviews (one heterogeneous via `codex exec`, one same-family)._

## Overview

The `retrospective` skill's interview protocol splits facilitator from respondent to keep an agent from grading its own work. Five defects let that split be skipped, claimed falsely, or bypassed entirely. This spec repairs the dispatch ladder's wording, makes the degraded-mode claim falsifiable against the whole ladder, adds a mechanical carry-forward count reconciliation with parseable fields, and separates "no facilitator was reachable" from "nothing warranted probing" behind a falsifiable warrant.

Source issues: #6, #7, #8, #9, #10.

## User Scenarios

### S1: Headless run on a harness that has subagents

A retro runs with `mode:headless` on Claude Code, where a subagent tool and a Codex CLI are both available. Today the dispatch ladder's fourth rung reads `headless/single-agent`, and the slash reads as "or", so the run legally takes the self-checklist floor. After this change the ladder names rung 4 by capability only, and `mode:headless` is stated as a non-qualifying condition. The run dispatches a same-model fresh-context facilitator instead.

### S2: Run whose subagent primitive dies mid-session

A retro's subagent dispatch fails. The ladder's rung 1 already names an external CLI facilitator (`codex exec`), so the run is not at the floor: it dispatches the external facilitator. `self-checklist` requires **both** channels to be unreachable, and Phase 8 requires the doc to say so — "no subagent primitive and no external facilitator CLI reachable in this harness" — rather than the unfalsifiable "no independent facilitator was available".

### S3: Mechanical change where nothing warranted probing

A retro covers a docs-only text edit. Every success criterion is Met, the carry-forward counts reconcile exactly, and the Findings section has no What to Improve entries. The author records `not-probed (no narrative warranted)` with a zero-row table. The three warrant conditions are visible in the doc itself, so the claim is falsifiable by reading the doc.

### S4: Carry-forward substitution that a matching count conceals

The previous retro registered four carry-forward items. This retro's reconciliation table has four rows, but one registered item is missing and one unregistered item took its place. Phase 4's current prose ("an item that goes unmentioned is a silent drop") does not require reading the previous doc's registration table row by row, so the matching count passes. After this change Phase 4 requires a row-by-row reconciliation by name, both counts recorded in a parseable template field, and an unregistered row flagged as its own defect.

### S5: A run that names `mode:headless` as its justification

An author writes `Independence level: self-checklist` with `Rounds used: 0 (headless mode)`. Phase 8's current check validates only that the level string is drawn from the closed vocabulary, so it passes. After this change the check requires a named absent capability covering the whole ladder and states that `mode:headless` is explicitly not one, so the claim is rejected at the pre-commit gate.

### S6: A run claiming `not-probed` while carrying an unmet criterion

An author records `not-probed (no narrative warranted)` on a retro whose Phase 3 table has a Not Met row. Warrant condition W1 fails on the doc's own content, so the level is rejected and the run must probe or degrade to a facilitator level with a named absent capability.

## Scope

### In

- `skills/retrospective/SKILL.md` — dispatch ladder rung 4 (#6), Phase 8 pre-commit clause and the migrated zero-row sentence (#8, #10), Phase 4 count reconciliation (#9), independence-level vocabulary and the `not-probed` warrant (#10).
- `skills/retrospective/references/interview-probes.md` — the headless/single-agent assertion at the file's opening paragraph (#6) and the verdict-forms table (#10).
- `references/dispatch-degradation.md` — the headless conflation in the no-subagent tier (#6). **Shared file with 12 skill and reference consumers** (see Risks).
- `schemas/retro-template.md` — the independence-level line (#10) and a parseable carry-forward count field (#9).
- `scripts/validate.sh` check 9 — level count and the probes-consistency rule (#10).
- `scripts/test-retro-format-drift.sh` — discrimination cases (#8, #9, #10) **and an audit of existing cases A–J against the 5-level template** (see Testing).
- `ROADMAP.md` — record that the Conformance-suite trigger fired (#7).
- `CONCEPTS.md` — the `Independence level` definition, which enumerates the closed vocabulary (#10).

### Out

- Annotating or amending the 18 existing zero-round retro docs. They stay as historical record, matching issue #7's own recommendation.
- Building the Conformance suite. Its ROADMAP trigger fired; the build is its own cycle.
- Posting the #7 thesis correction to GitHub. That is an outward action (`enforces: P7`) and belongs to this loop's Ship phase, tracked as a named deliverable in Success Criteria 7.
- `skills/planning/SKILL.md` step 14 (issues #11, #12). Separate loop by user scoping decision.
- Any repository-wide validation over `docs/retros/*.md`. Deliberately excluded: 17 of 18 existing zero-round docs would fail such a check immediately.
- Splitting the independence field into two orthogonal fields (independence level + interview disposition). Considered and declined at the Design gate in favor of W4 — see Decisions Taken at the Design Gate, item 2.

## Assumptions and Preconditions

Live assumptions retained. Every command below is pipe-free so it is copy-pasteable out of this table; all were rerun at the recorded timestamp. Repository invariants that still apply: `scripts/validate.sh` is the single structural gate and must pass on the post-change tree; `docs/retros/` holds 36 committed retro docs whose shapes this change must not invalidate.

| Claim | Command | Observed at | Observed result | Evidence source |
|---|---|---|---|---|
| All four current independence levels already appear in `interview-probes.md`, so requiring every level there is satisfiable without inventing artificial mentions | `rg -c -e heterogeneous -e "same-model fresh-context" -e in-thread -e self-checklist skills/retrospective/references/interview-probes.md` | `2026-08-14T04:25:09+00:00` | `4` | Working tree at `d3c6f0b` |
| check 9 hardcodes a level count of 4 and selects the probes-checked rung positionally | `rg -n -e "len\(set\(levels\)\) != 4" -e "degraded = levels\[-1\]" scripts/validate.sh` | `2026-08-14T04:25:09+00:00` | `333: if len(set(levels)) != 4:` and `373: degraded = levels[-1]` | Working tree at `d3c6f0b` |
| `references/dispatch-degradation.md` carries the same headless conflation named in issue #6, which cites only SKILL.md and interview-probes.md | `rg -n -e "no subagent capability at all" references/dispatch-degradation.md` | `2026-08-14T04:25:09+00:00` | Line 22: "Harness offers no subagent capability at all (or the run is headless with a strict budget)" | Working tree at `d3c6f0b` |
| 18 retro docs record `Rounds used: 0` | `rg -c "Rounds used: 0" docs/retros/` | `2026-08-14T04:25:09+00:00` | 18 files, one match each | Working tree at `d3c6f0b` |
| The independent-facilitator path was exercised 7 times, falsifying issue #7's "never exercised" thesis | `rg -n -e "Independence level: heterogeneous" -e "Independence level: same-model" -e "Independence level: in-thread" docs/retros/` | `2026-08-14T04:25:09+00:00` | 7 matching lines across 7 docs (5 heterogeneous, 1 same-model fresh-context, 1 in-thread) | Working tree at `d3c6f0b` |
| The repository's fixture convention is disposable `mktemp -d` trees, so discrimination fixtures need no committed directory and cannot pollute `docs/retros/` | `rg -c "mktemp -d" scripts/test-retro-format-drift.sh` | `2026-08-14T04:25:09+00:00` | `2` (pattern documentation and the per-case setup) | Working tree at `d3c6f0b` |
| Existing test case H asserts the 4-level guard string and therefore breaks when the count becomes 5 | `rg -n "expected 4 distinct" scripts/test-retro-format-drift.sh` | `2026-08-14T04:25:09+00:00` | Line 253 (level-count guard, breaks) and line 272 (verdict-count guard, unaffected) | Working tree at `d3c6f0b` |
| `references/dispatch-degradation.md` is consumed by 12 skill and reference files, not 1 | `rg -ln "dispatch-degradation" skills/ references/ schemas/` | `2026-08-14T04:25:09+00:00` | 12 files: compound, debugging, designing, implementing, planning, planning/references/deepening, release-loop, retrospective, reviewing, reviewing/references/merge-pipeline, shipping, shipping/references/pr-feedback | Working tree at `d3c6f0b` |
| Exactly one existing retro doc lacks a `Carry-forward items registered` table, so Phase 4 step 1 needs a stated fallback | `rg -L --files-without-match "Carry-forward items registered" docs/retros/` | `2026-08-14T04:25:09+00:00` | 1 file: `docs/retros/2026-08-05-add-license-retro.md` (35 of 36 have the table) | Working tree at `d3c6f0b` |

## Architecture

Eight files change. No runtime module structure exists — the deliverable is procedural contract text plus the structural validation that keeps its vocabulary consistent across four files.

The vocabulary flows one way. `schemas/retro-template.md` is the source of the closed level list. `scripts/validate.sh` check 9 parses that list and asserts each value appears in both `skills/retrospective/SKILL.md` and `skills/retrospective/references/interview-probes.md`. A value added to the template without a consumer edit fails the gate; a consumer renamed without the template fails it too.

Data flow for the new Phase 4 step: the previous retro doc's `Carry-forward items registered` table is the input, the current doc's `Carry-forward from previous retro` table is the output, and the reconciliation is a two-way name match whose two cardinalities land in a parseable template field.

## Interface

### Independence-level vocabulary (#10)

The closed list gains a fifth value, appended last:

```
heterogeneous | same-model fresh-context | in-thread (approximated independence) | self-checklist | not-probed (no narrative warranted)
```

`not-probed` sits off the independence axis: the first four rank how independent a facilitator was, the fifth records that no probing was warranted. `self-checklist` narrows to exactly one meaning — one agent authored probe, answer, and verdict because no other agent was reachable.

`not-probed` gets its own row in `interview-probes.md`'s verdict-forms table. Its verdict forms follow the two paths W4 defines: on the reachable-channel path the single confirmation row carries `accepted`, authored by the facilitator that confirmed nothing warranted probing; on the no-channel path the table is empty and there are no verdict cells at all. `self-attested` is never a `not-probed` verdict — a self-attested confirmation of one's own decision not to probe would restore exactly the bias the level is being kept honest against.

**Precedence when both conditions hold.** A run can have both a degraded environment and nothing warranting probing. `not-probed` wins and occupies the single field. What keeps that from discarding the bias question is W4 below: the not-to-probe judgment itself carries an independence requirement, so the field's one value still tells a reader whether an independent agent stood behind the decision to produce no rows. Phase 8's current sentence — "A zero-row table under a valid header is valid — nothing warranted probing" — migrates to `not-probed` and is removed from the other four levels.

### The `not-probed` warrant (#10)

Emptiness is not evidence. A zero-row table is what an author writes after deciding not to probe, so authorizing `not-probed` from table emptiness alone would install a rung cheaper than the floor rung the issues show being abused. `not-probed` is valid only when all four conditions hold:

- **W1** — no Phase 3 criterion is Partially Met or Not Met, or the doc states that no spec exists.
- **W2** — Phase 4's reconciliation records registered N equal to accounted-for M, with no unregistered rows. The degraded fallback of Phase 4 step 1 never satisfies W2: when the previous doc has no registration table, the reconciliation is degraded, so `registered 0, accounted for 0` is not a passing reconciliation and `not-probed` is unavailable.
- **W3** — the Findings section contains no entries outside What Worked Well. Naming What to Improve alone would leave the trivial evasion of filing the same concern under Process Observations.
- **W4** — when any facilitator channel is reachable, the not-to-probe judgment is confirmed by one facilitator dispatch, and its confirmation is recorded as a transcript row. `not-probed` without a dispatch is available only when the same absent-capability claim Phase 8 requires of `self-checklist` holds — no subagent primitive and no external facilitator CLI reachable — and that claim is recorded on the rounds-used line.

W4 is what stops the fifth value from becoming a cheaper floor than the floor rung the issues show being abused. Without it, `not-probed` would be the only level reachable with no dispatch and no capability claim, which is precisely the incentive shape that produced the 17 false headless justifications. With it, the cheapest path is no longer the one that avoids all independent contact: the decision that nothing warranted probing is itself subject to the independence the protocol exists to enforce, and the run costs exactly one dispatch.

W4 changes the transcript's row count from zero to one when a channel is reachable. The zero-row table remains valid only on the no-channel path.

The four conditions are **falsifiable from committed artifacts** — this doc, the previous retro doc, and the spec named by the plan's `origin:` field — not from this doc alone. W1's no-spec branch and W2's registered count both require reading a second committed file, which is exactly what Phase 2 and Phase 4 already do; W3 and W4 are visible in this doc. The property that matters is preserved: a false `not-probed` claim can be caught by any reader with repository access, where "no facilitator was available" could not.

**Residual limit, stated rather than papered over.** W1–W4 raise the cost of a false `not-probed` claim; they do not eliminate it. An author who simply writes no finding about a surprise that occurred outside the declared criteria satisfies W1–W3, and W4's facilitator sees only the artifacts the respondent assembled. This is the same residual the protocol already declares for the transcript itself — `skills/retrospective/SKILL.md`'s Known limit: "this protocol is a procedural gate, not a hard barrier — a respondent could fabricate transcript rows". The warrant is held to that standard, not to a higher one it could not meet.

A run failing any condition must probe, or degrade to a facilitator level and name its absent capability.

### check 9 probes rule (#10)

The positional selection `degraded = levels[-1]` is replaced by a position-independent rule: **every** level parsed from the template must appear in `interview-probes.md`, as it already must in `SKILL.md`. The level count assertion moves from 4 to 5.

**This supersedes a recorded user decision.** `docs/deviations/2026-07-21-check9-probes-level-scope-003.md` resolved the same question in favor of list-final-only, reasoning that "requiring all four levels there would force artificial mentions of rungs the probes contract never uses". That premise is now empirically moot: all four levels already appear in the probes contract via its verdict-forms table (see Assumptions), so the generalization forces no artificial mention today. The supersession is deliberate and has a cost — it imposes the mention requirement on every future level, including `not-probed`, which this spec accepts by giving `not-probed` a verdict-forms row. Approving this spec carries the supersession; the earlier decision is not silently preserved.

### Dispatch ladder rung 4 (#6)

Rung 4 is named by capability only — no facilitator channel is reachable at all. The ladder states explicitly that `mode:headless` is not a qualifying condition for any rung, because it governs user interaction, not worker dispatch. The same correction applies to `interview-probes.md`'s opening paragraph, which currently asserts the wrong mapping as a plain statement of fact.

In `references/dispatch-degradation.md`, the tier-3 parenthetical is **reworded, not deleted**: `(or the run is headless with a strict budget)` becomes `(or a strict dispatch budget applies)`. This removes the headless conflation while preserving the budget-based tier-3 sanction that other consumers depend on — notably `compound`, which retrospective's own Phase 7 invokes in `mode:headless` and which selects its tier through this ladder.

### Phase 8 pre-commit clause (#8)

A degraded independence level must name the specific capability that was absent, covering **the whole ladder, not one rung of it**. Scope: `in-thread (approximated independence)` and `self-checklist` only.

- The two independent levels are excluded — nothing was absent.
- `not-probed` is excluded on its reachable-channel path, where W4's confirmation row is the evidence; on its no-channel path it carries the same claim `self-checklist` does, in the same shape.
- `mode:headless` is explicitly not an absent capability.

Both degraded levels are in scope, resolved at the Design gate: `in-thread` names why fresh context was unavailable, and `self-checklist` names both facilitator channels. Holding the two to one standard keeps the rule short enough to apply without interpretation.

For `self-checklist` the claim must cover both facilitator channels the ladder names, in the shape "no subagent primitive and no external facilitator CLI reachable in this harness". A bare "no subagent primitive" is insufficient, because the ladder's own rung 1 names `codex exec` as a facilitator channel independent of the subagent primitive — a subagent that dies does not establish that no facilitator was reachable. For `in-thread` the claim names why fresh context was unavailable.

The rule turns an unfalsifiable claim into a checkable one: an author writing a specific unreachability claim can be wrong about it, where "no facilitator was available" cannot be.

**Considered and rejected: recorded attempt evidence.** The heterogeneous review argued that a named absent capability is still an unsupported assertion, and asked for a facilitator-channel inventory plus a recorded dispatch attempt and its failure result. Rejected: no fixture can verify that a recorded attempt actually happened, so the requirement adds ceremony an agent can pencil-whip while changing nothing about the failure mode. The full-ladder phrasing is kept instead, and the residual gaming is covered by the Known limit cited under the warrant. Recorded here so the argument is visibly answered rather than dropped.

### Phase 4 count reconciliation (#9)

Four mechanical steps, promoted out of the facilitator's probe bank so they run in every mode:

1. Read the previous retro's `Carry-forward items registered` table — the table, not the narrative. **Fallback**: when the previous doc has no such table, record registered N = 0 and note the absence; this is a degraded reconciliation, not a passing one.
2. Reconcile row by row, by name.
3. Record both counts in the template's parseable field: registered N, accounted for M.
4. A row in this table that the previous retro did not register is itself a defect — it inflates M and can conceal a drop.

`schemas/retro-template.md` gains the count field under the `Carry-forward from previous retro` heading so the two cardinalities are parseable rather than prose.

**The count field is a bullet line, never a table row.** `scripts/validate.sh`'s carry-forward check (line 543) collects every three-column pipe row inside that section and treats a row whose first cell is not a separator, header, or `(none…)` as a carry-forward data row. A count expressed as `| registered | 4 | 4 |` would therefore be counted as an item across all 36 existing retro docs and corrupt the `has_data_rows` determination that gates the Phase-4-probe citation check. The field takes the bullet form used by the Interview Transcript header lines.

The corresponding probe stays in `interview-probes.md`. A mechanical step and a facilitator probe are different defenses against the same failure.

## Testing

Extends `scripts/test-retro-format-drift.sh`, which already mutates disposable `mktemp -d` trees and asserts check 9's response.

**Existing-case audit (mandatory).** Case H (line 248) removes `| self-checklist` from the template and asserts the failure string `expected 4 distinct independence levels` (line 253). Under a 5-level template that mutation leaves 4 levels, so the new check fails with `expected 5 ...` and case H's assertion misses — turning the whole suite, which is Success Criterion 1's own measured-by command, red. Every case A–J is audited against the 5-level template before new cases are added. Traced already: case I's verdict-form count of 4 is unaffected; cases B and G survive as written.

New vocabulary-propagation cases:

| Case | Mutation | Expected |
|---|---|---|
| C1 | Remove `not-probed (no narrative warranted)` from `SKILL.md` | check 9 fails |
| C2 | Remove `not-probed (no narrative warranted)` from `interview-probes.md` | check 9 fails |
| C3 | Remove `in-thread (approximated independence)` from `interview-probes.md` | check 9 fails (proves the rule is position-independent, not list-final) |
| C4 | Unmutated tree | check 9 passes |

New discrimination cases. The Phase 8 and warrant rules are enforced at runtime by an agent reading skill prose, which no shell test can execute. What the test proves is that the rules **discriminate**, and that the shipped prose still carries them:

| Case | Fixture | Expected |
|---|---|---|
| C5 | `self-checklist` / `Rounds used: 0 (headless mode)` | checker rejects |
| C6 | `self-checklist` / `Rounds used: 0 (no subagent primitive and no external facilitator CLI reachable in this harness)` | checker accepts |
| C7 | `self-checklist` / `Rounds used: 0 (no subagent primitive in this harness)` | checker rejects — covers one ladder channel only |
| C8 | `not-probed` / one confirmation row verdict `accepted` / all criteria Met / counts reconcile / no findings outside What Worked Well | checker accepts |
| C9 | `not-probed` / one Not Met criterion | checker rejects (W1) |
| C10 | `not-probed` / registered 4, accounted 3 | checker rejects (W2) |
| C11 | Previous doc registers 4 items; current table has 4 rows, one substituted | checker rejects the unregistered row (#9) |
| C12 | `not-probed` / zero-row table / no absent-capability claim on the rounds-used line | checker rejects (W4) — the incentive case: no dispatch and no claim |
| C13 | `not-probed` / zero-row table / both-channels absent-capability claim | checker accepts — the no-channel path |
| C14 | `not-probed` / one confirmation row verdict `self-attested` | checker rejects (W4) — self-confirmation is not confirmation |
| C15 | `not-probed` / a finding under Process Observations | checker rejects (W3) — the relocation evasion |

**Checker contract.** The checker is a shell function in `scripts/test-retro-format-drift.sh`. Input: the path of one fixture retro document inside a disposable `mktemp -d` tree, plus the path of a fixture previous-retro document when the case exercises Phase 4. Output: exit 0 for accept, nonzero for reject, and on reject a single line naming the violated condition by its identifier (`phase8-capability`, `phase8-headless`, `W1`, `W2`, `W3`, `W4`, or `phase4-unregistered`). Each case asserts both the exit status and, for rejections, the condition name — so a case cannot pass by rejecting for the wrong reason. The checker never reads `docs/retros/`.

**Anti-circularity coupling, per case.** A checker implemented in the test script and never run against the shipped artifact proves only itself: if the prose drifts or is deleted, the cases stay green. Each case therefore also asserts that the specific shipped clause it mirrors is still present — a blanket Phase 8 assertion would leave C8–C11 coupled to prose whose semantics they do not test.

| Cases | Asserted shipped clause |
|---|---|
| C5, C6, C7 | `skills/retrospective/SKILL.md` Phase 8 requires a named absent capability for a degraded level, names `mode:headless` as non-qualifying, and carries the both-channels shape |
| C8, C9, C10, C12, C13, C14, C15 | `skills/retrospective/SKILL.md` carries W1–W4 as the `not-probed` warrant, including W2's exclusion of the degraded fallback and W4's two paths |
| C11 | `skills/retrospective/SKILL.md` Phase 4 carries the row-by-row name reconciliation, the recorded counts, and the unregistered-row defect rule |

This ties C5–C15 to the deliverable the way C1–C4 are tied to the real `validate.sh`.

**Red before green.** Each new case is committed red against the pre-change tree before the change it guards lands, following the precedent recorded in `docs/deviations/2026-07-21-check9-probes-level-scope-003.md` ("Committed red before the check extension lands"). The coupling assertions are what make this possible for C5–C11: on the pre-change tree the asserted clauses do not exist in `SKILL.md`, so each case fails for a named reason before the prose lands. Note precisely what is and is not claimed: the suite command `./scripts/test-retro-format-drift.sh` exits 0 on today's tree because these cases do not exist yet. The discrimination claim is about each case against the pre-change tree, established at the moment the case is committed red — not about the suite command's exit status today.

## Risks

| Risk | Mitigation |
|---|---|
| A repository-wide check over `docs/retros/*.md` would fail 17–18 existing docs on the first run | Explicitly out of scope. The checker runs against fixtures only |
| `references/dispatch-degradation.md` is consumed by 12 skill and reference files; deleting the tier-3 budget parenthetical would remove the only budget-based tier-3 sanction repo-wide, concretely changing `compound`'s sanctioned headless single-call collapse — which retrospective's own Phase 7 depends on | The parenthetical is reworded to a budget-only clause, not deleted. Before commit, verify each of the 12 consumers' readings is unchanged; the enumeration is retained in Assumptions |
| Appending a fifth level changes check 9's `levels[-1]` target from `self-checklist` to `not-probed`, silently relaxing the rung the probes contract is checked against | The positional rule is replaced, not adjusted. C3 is the discriminating case that proves the replacement |
| Adding `not-probed` installs a rung cheaper than the floor rung the issues show being abused — no facilitator, no capability claim, no transcript row | W4 removes exactly that shape: with a channel reachable, `not-probed` costs one confirming dispatch; without one, it costs the same absent-capability claim `self-checklist` pays. W1–W3 add three doc-visible conditions on top. C12 is the adversarial fixture that fails if this ever regresses |
| A zero-row table can coexist with a full Findings section, because the Findings check accepts a finding citing Phase 2–3 data with no T-ID | W3 closes this hole for every bucket, not only What to Improve: `not-probed` is invalid when any finding sits outside What Worked Well, whatever it cites. C15 covers the relocation evasion |
| W4's confirming facilitator sees only artifacts the respondent assembled, so a surprise the respondent never wrote down stays invisible | Not closed, and not claimed to be. This is the protocol's declared Known limit (`skills/retrospective/SKILL.md`); W4 raises the cost of a false `not-probed` without converting a procedural gate into a hard barrier |
| The check 9 generalization reverses a recorded user decision | Named as a supersession in the Interface section with its rationale and its cost, and raised explicitly at the Design gate rather than carried silently |
| Issue #7's falsified thesis gets repaired locally while the issue keeps asserting it | Success Criterion 7 makes the issue correction a named Ship-phase deliverable with an owner |

## Success Criteria

Each criterion is labeled with its kind, using the vocabulary in `CONCEPTS.md`: a **discriminating criterion** measures a state change and must fail on the pre-change tree; an **invariance guard** must hold both before and after, and passing beforehand is the expected result rather than a defect. The two are read against opposite baselines, so a guard is never counted as proof that the change landed.

For the criteria measured by `./scripts/test-retro-format-drift.sh`, the discrimination claim is about each named case against the pre-change tree, established when that case is committed red per the Testing section's red-before-green step. The suite command itself exits 0 on today's tree because the cases do not exist yet; that is not evidence either way.

1. *(discriminating)* Check 9 rejects a tree where the fifth level is missing from either consumer file, and rejects a tree where a non-final level is missing from the probes contract.
   - **Measured by**: `./scripts/test-retro-format-drift.sh` — cases C1, C2, C3 fail-as-expected and C4 passes, with the whole suite exiting 0. C3 is the discriminating case: committed against the pre-change validator, whose probes rule checks only the list-final level, it fails.
2. *(discriminating)* The Phase 8 absent-capability rule discriminates across the whole ladder: a justification naming only `mode:headless` is rejected, one naming a single ladder channel is rejected, and one naming both channels is accepted.
   - **Measured by**: `./scripts/test-retro-format-drift.sh` — C5 rejects naming `phase8-headless`, C7 rejects naming `phase8-capability`, C6 accepts. Each also asserts the Phase 8 clause it mirrors, which is absent pre-change.
3. *(discriminating)* The `not-probed` warrant discriminates on all four conditions: a conforming doc is accepted on either W4 path, and docs violating W1, W2, W3, or W4 are each rejected by name.
   - **Measured by**: `./scripts/test-retro-format-drift.sh` — C8 accepts (dispatch path), C13 accepts (no-channel path), C9 rejects naming `W1`, C10 rejects naming `W2`, C15 rejects naming `W3`, C12 and C14 reject naming `W4`. Each also asserts the W1–W4 warrant text, which is absent pre-change.
   - **Why C12 is the load-bearing case**: it is the incentive shape the whole fifth value risks creating — no dispatch, no capability claim, nothing to probe asserted by the party who benefits from asserting it. If C12 ever passes, the fifth value has become a cheaper floor than the rung issues #6–#8 document being abused.
4. *(discriminating)* The carry-forward reconciliation catches a substitution that a matching row count conceals.
   - **Measured by**: `./scripts/test-retro-format-drift.sh` — C11 rejects naming `phase4-unregistered`, and asserts the Phase 4 reconciliation text, which is absent pre-change.
5. *(invariance guard — passes before and after; not evidence the change landed)* No existing retro document is invalidated by this change, and the existing test suite is not left broken by the level-count change.
   - **Measured by**: `./scripts/validate.sh` exits 0 with `[cf-tid] carry-forward T-ID integrity` reporting at least 26 retro docs checked and `retro interview format: template and skill prose agree` reported ok; `./scripts/test-retro-format-drift.sh` exits 0 with every case A–J passing. The A–J half is the part this change can break, via the case-H level-count audit.
6. *(discriminating)* The dispatch ladder and both downstream files name rung 4 by capability only, and each states that `mode:headless` does not qualify.
   - **Measured by**: judgment rubric. A reviewer reads the rung-4 sentence in `skills/retrospective/SKILL.md`, the opening paragraph of `skills/retrospective/references/interview-probes.md`, and the no-subagent tier in `references/dispatch-degradation.md`, and confirms each names an absent capability and none names headless mode as a qualifying condition. Pass means all three read that way with no slash-joined capability/flag pair remaining, and the dispatch-degradation tier retains a budget clause that does not mention headless.
7. *(discriminating)* Issue #7's falsified thesis is corrected where it was asserted, and the fired Conformance-suite trigger is recorded.
   - **Measured by**: `rg -n "Conformance suite.*fired" ROADMAP.md` returns the Conformance-suite row marked fired with this cycle as the evidence — the row-scoped pattern is required because a bare `fired` search already matches the Schema-validators row on the pre-change tree and would not discriminate; and the Ship phase posts a comment on issue #7 citing the seven independent-facilitator retro docs by filename. Owner: the human at the Ship gate (`enforces: P7`).
8. *(discriminating)* Phase 4 states both carry-forward cardinalities as a mechanical step reachable without a facilitator, with a stated fallback for a previous doc lacking the table.
   - **Measured by**: judgment rubric. A reviewer confirms Phase 4 instructs reading the previous doc's registration table, reconciling by name, recording registered N and accounted-for M in the template field, treating an unregistered row as a defect, and handling the no-table case. Pass means all five instructions are present in Phase 4 prose, not only in `interview-probes.md`, and `schemas/retro-template.md` carries the count field.

## Decisions Taken at the Design Gate

Recorded here rather than deleted, so the reasoning survives for `planning` and for the retro that measures this cycle.

1. **check 9 supersedes deviation 003.** The list-final scoping decision of 2026-07-21 is reversed in favor of the all-levels rule, on the grounds that its stated rationale — artificial mentions of unused rungs — is empirically moot. Accepted cost: every future level must appear in the probes contract.
2. **Mixed state resolved by option (iii), not precedence alone.** The heterogeneous review's argument was accepted: a zero-row table removes verdict cells but not the decision to produce none, and that decision's provenance is exactly the bias question the protocol exists to expose. The single-field model is kept, and W4 supplies the missing independence — `not-probed` requires one confirming facilitator dispatch whenever a channel is reachable. Option (ii), splitting the field, was declined for blast radius; option (i), bare precedence, was declined because it leaves the provenance unrecorded.
3. **Both degraded levels carry the absent-capability rule.** `in-thread` names why fresh context was unavailable; `self-checklist` names both facilitator channels.

## Open Decisions

1. **The display string for the fifth level.** The spec uses `not-probed (no narrative warranted)`. A shorter form is acceptable provided `schemas/retro-template.md`, both consumer files, `CONCEPTS.md`, and the fixtures agree. Resolved by: `planning`.
2. **Which facilitator level a W4 confirmation dispatch is recorded under.** The transcript header carries `not-probed`, but the confirming dispatch has its own independence (heterogeneous, same-model fresh-context, or in-thread). The spec requires the verdict `accepted`, which already excludes an in-thread self-attestation; whether the header should additionally note the confirming channel is unresolved. Resolved by: `planning`, which may add a free-text suffix to the rounds-used line without touching the closed level vocabulary.
