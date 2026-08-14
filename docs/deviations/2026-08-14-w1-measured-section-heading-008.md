# Deviation Addendum 008: W1 Measured Section Heading

_Recorded 2026-08-14 during the U4 review gate, before merge._

## Original contract

The sealed plan states the W1 grammar in its Architecture notes:

```text
- `W1` reads the last cell of every data row in the `## Measured vs. Declared` section. It fails on `Partially met` or `Not met`, using the casing of `schemas/retro-template.md` line 35.
```

Plan step 1 repeats the same rule for the checker implementation.
Both places name the section by the literal `## Measured vs. Declared`.

## Discovered contradiction

`schemas/retro-template.md` line 25 carries the heading `## Success criteria: measured vs declared`.
No line of that template carries `## Measured vs. Declared`.

The three sibling conditions name headings the template does carry:

| Condition | Plan literal | Template line |
|---|---|---|
| W2 | `## Carry-forward from previous retro` | 39 |
| W3 | `## Findings` | 73 |
| W4 | `## Interview Transcript` | 53 |

Only W1 diverges.
The divergence is therefore a transcription error in the sealed plan, not a deliberate dialect.

The literal `Measured vs. Declared` does occur in `skills/retrospective/SKILL.md` line 36,
as the Phase 3 heading `## Phase 3: Measured vs. Declared (core)`.
That is the probable source of the error.

## Decision

The user decided at the U4 review gate on 2026-08-14.
Align the checker to the real template heading and record this addendum.

`cond_W1` in `scripts/test-retro-format-drift.sh` now extracts the section
`## Success criteria: measured vs declared`.
Every fixture that writes that section writes the same heading.

The approved specification and the sealed plan stay unchanged as historical records.

## Necessity

Editing the approved plan body would break its body seal.
Re-sealing outside interactive deepening would erase the approval boundary.

Keeping the plan literal instead would leave W1 unable to find its section in any real retro
document. W1 would then pass vacuously on every document, which contradicts the checker's own
stated principle that an absent field fails the condition it belongs to.

## Observable behavior

No `retrospective` runtime behavior changes.
The retro template and the skill prose are untouched.

The fixture checker in `scripts/test-retro-format-drift.sh` changes behavior.
It reads the measured-criteria section under the heading the template publishes.
Fixture documents that carry the old literal no longer satisfy W1.

## Safety and consent boundaries

The checker reads disposable fixture documents only.
It never reads `docs/retros/` and it is not a repository linter.

This addendum grants no execution authority.
Existing review and merge gates remain unchanged.

## Verification changes

- Run `./scripts/test-retro-format-drift.sh` and require all cases to pass.
- Require case C9 to reject with `W1`, which proves W1 still reads a real table cell.
- Require case C16 to reject with `W1` when the measured section is absent.
- Compare the heading in `cond_W1` against `schemas/retro-template.md` line 25 byte for byte.

## Traceability

- Approved specification: `docs/specs/2026-08-14-retro-interview-integrity-design.md`.
- Approved plan: `docs/plans/2026-08-14-001-fix-retro-interview-integrity-plan.md`.
- Divergent plan text: Architecture notes line 34, repeated at step 1 and step 10.
- Decision authority: the user, at the U4 review gate, 2026-08-14.
- Correction precedent: `docs/deviations/2026-08-05-worktree-assumption-table-pipe-007.md`.
- Addendum authority: `docs/solutions/workflow-issues/review-introduced-state-machine-deviation.md`.
