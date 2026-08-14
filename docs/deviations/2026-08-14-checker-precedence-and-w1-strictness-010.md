# Deviation Addendum 010: Checker Precedence and W1 Strictness

_Recorded 2026-08-14 during the final branch review, before merge._

Two observable divergences between the shipped checker and the literal text of the sealed plan.
Neither changes the outcome of an honest document. Both are recorded here rather than carried
silently, which is the standard addenda 008 and 009 already set on this branch.

## Original contract

### (i) The seven-condition precedence

The sealed plan fixes the condition order in its Architecture notes, line 42:

```text
**Condition precedence.** The checker prints one condition name. It evaluates in this fixed order and reports the first failure: `phase8-headless`, `phase8-capability`, `W1`, `W2`, `W3`, `W4`, `phase4-unregistered`.
```

Seven names, in that order. The plan repeats the same seven in unit step 5, line 211.

### (ii) W1 as a disjunction

The sealed plan states W1 twice, both times as a disjunction. Unit step 1, line 207:

```text
  1. Add condition `W1` to the checker. It fails when the Verdict column of the Phase 3 table carries `Partially met` or `Not met`. Use the casing of `schemas/retro-template.md` line 35 and match case-insensitively. It passes that check when the document states that no spec exists.
```

Unit step 10, line 216, which is the instruction that wrote the shipped prose:

```text
  10. Add the warrant to `skills/retrospective/SKILL.md` beside the independence-level paragraph. Label the four conditions `W1` through `W4`. Write W1: no Phase 3 criterion reads `Partially met` or `Not met`, or the document states that no spec exists.
```

The shipped prose carries that disjunction verbatim, `skills/retrospective/SKILL.md` line 91:

```text
- **W1 — nothing measured short.** No Phase 3 criterion reads `Partially met` or `Not met`, or the document states that no spec exists. A criterion the cycle missed is narrative material by definition.
```

Read literally, either disjunct suffices: a no-spec statement licenses the level whatever the
verdict cells say.

## Discovered contradiction

### (i) The checker evaluates eight conditions

`RETRO_CONDITIONS` in `scripts/test-retro-format-drift.sh` line 80 lists eight names, with
`level-unrecognized` first, ahead of `phase8-headless`. The checker prints a condition name the
plan's line 42 never defines.

The condition is not an invention of the checker. The Phase 8 pre-commit sentence requires a
valid independence level, `skills/retrospective/SKILL.md` line 116, opening sentence:

```text
**Pre-commit check** (`enforces: P8`): the doc contains an Interview Transcript section with a valid independence level and a rounds-used count; in `self-checklist` mode the rows are the checklist answers.
```

The plan's own step text consumes that requirement, line 169:

```text
  Consumes: the Phase 8 pre-commit sentence of `skills/retrospective/SKILL.md`, which requires a valid independence level and a rounds-used count
```

An unrecognized level is also load-bearing for every other condition. `phase8-headless`,
`phase8-capability` and `W1` through `W4` all gate on a level match, so a level outside the
template's five satisfies all seven of line 42's conditions vacuously. Without a guard ahead of
them, one unpublished level string buys an acceptance.

So the shipped prose and the plan's step text agree that the level must be valid; only line 42's
enumeration is stale. This is the same two-against-one shape addendum 009 resolved.

### (ii) The checker rejects an unmet criterion unconditionally

`cond_W1` reads the verdict rows first and returns failure on `Partially met` or `Not met`
before it ever looks for the no-spec statement. A document carrying both a `Not met` row and a
genuine "no spec exists" sentence is rejected. The prose, read literally, would accept it.

Note what such a document is. A measured criterion cannot exist if no spec exists — a criterion
is a spec's own content. A document that asserts both is self-contradictory, and its two halves
point at opposite verdicts. The checker resolves the contradiction by rejecting; the literal
prose resolves it by accepting.

No honest document is affected. A cycle with a spec states no unmet criterion and no no-spec
sentence. A cycle without a spec states the sentence and has no rows to fail on. Only the
self-contradictory document sees the two readings differ.

## Decision

### (i)

Keep `level-unrecognized`, and record the plan's line 42 enumeration as stale. Removing the
condition would restore the vacuous-pass hole that the level guard exists to close, and would
contradict the Phase 8 pre-commit sentence the checker exists to prove. The plan's line 42 is
corrected by this addendum, not by an edit.

### (ii)

Keep the checker's strict read. The reasoning lives beside the code, in `cond_W1`'s comment
block in `scripts/test-retro-format-drift.sh`: the verdict rows are read first and an unmet
criterion rejects unconditionally, because a document that measured a criterion and found it
unmet has narrative material whatever else the section says; the no-spec escape hatch speaks
only for a section that measured nothing.

Nothing else changes. The shipped prose stays as written, because it is correct for every
document that is not self-contradictory, and a clause qualifying the disjunction would add
words to the warrant to describe a document no honest author writes. The checker is not
loosened, because loosening it would make a contradiction the cheapest path to the cheapest
level.

The approved specification and the sealed plan stay unchanged as historical records.

## Necessity

Editing the approved plan body would break its body seal.
Re-sealing outside interactive deepening would erase the approval boundary.

Carrying either divergence unrecorded is the alternative this branch has twice rejected:
addenda 008 and 009 each recorded a divergence of this class rather than let the shipped
artifact drift from its sealed contract in silence. A reader comparing the checker to the plan
would otherwise find two unexplained differences and no way to tell a deliberate resolution
from an implementation slip.

## Observable behavior

No `retrospective` runtime behavior changes. No skill prose, specification, template, or
checker code changes with this addendum; it records what already shipped.

For the record, the two behaviors it describes are: a fixture whose `- Independence level:` line
names a value outside the template's five is rejected with `level-unrecognized`, ahead of every
other condition; and a `not-probed (no narrative warranted)` fixture carrying a `Not met`
verdict cell is rejected with `W1` even when the measured section also states that no spec
exists.

## Safety and consent boundaries

The checker reads disposable fixture documents only.
It never reads `docs/retros/` and it is not a repository linter.

This addendum grants no execution authority.
Existing review and merge gates remain unchanged.

## Verification changes

- Run `./scripts/test-retro-format-drift.sh` and require all cases to pass.
- Require case C27 to reject with `level-unrecognized`, which is divergence (i)'s condition
  proving that it discriminates rather than sitting unreachable ahead of the other seven.
- Require case C28 to reject with `phase8-capability`, which proves the level guard admits a
  published level after the trim and does not swallow the conditions behind it.
- Require case C25 to reject with `W1`: a `not-probed` document carrying a `Not met` verdict
  cell beside a genuine no-spec statement, which is exactly the self-contradictory document
  divergence (ii) describes.
- No new case is added for either divergence. Both behaviors already have cases; what was
  missing was the record of why they differ from the sealed text.

## Traceability

- Approved plan: `docs/plans/2026-08-14-001-fix-retro-interview-integrity-plan.md`.
- Divergent plan text (i): Architecture notes line 42, the seven-condition enumeration.
- Divergent plan text (ii): unit step 1 line 207 and unit step 10 line 216.
- Shipped prose: `skills/retrospective/SKILL.md` line 116 for (i), line 91 for (ii).
- Supporting plan step text (i): line 169, which consumes the valid-independence-level
  requirement.
- Shipped checker: `scripts/test-retro-format-drift.sh`, `RETRO_CONDITIONS` at line 80 and
  `cond_W1`.
- Decision basis (i): the artifact set — the shipped prose and the plan's step text against one
  stale enumeration.
- Decision basis (ii): only self-contradictory documents distinguish the two readings, so the
  checker's resolution costs no honest document.
- Correction precedents: `docs/deviations/2026-08-14-w1-measured-section-heading-008.md` and
  `docs/deviations/2026-08-14-in-thread-capability-scope-009.md`, the same class resolved the
  same way earlier on this branch.
- Addendum authority: `docs/solutions/workflow-issues/review-introduced-state-machine-deviation.md`.
