# Deviation Addendum 014: Baseline Revision Drift for Instruction Payload Slimming

_Recorded 2026-08-21 before instruction payload slimming plan approval._

## Original contract

The approved design at
`docs/specs/2026-08-21-instruction-payload-slimming-design.md` (approved at
commit `8c00d55`) pins:

- **Baseline revision** `da1ffbf` — every baseline-derived artifact is
  generated from `git show da1ffbf:...` or a worktree checked out at it.
- **Assumption row 1** — the seven always-resident skill bodies total
  131,746 bytes.
- **Success Criterion 1** — the seven bodies total at most 105,000 bytes
  ("baseline 131,746, a ≥20% reduction"), with 95,000 as a conditional
  stretch.
- **R5 inviolable list** — includes `shipping`'s merge gate (Step 7), whose
  wording must survive byte-identical after whitespace normalization.
- **R7** — the removed-line set is derived from `git diff <baseline>..HEAD`.

## Discovered contradiction

The planning Assumption Recheck reran the retained commands first-hand at
`2026-08-21T14:35:47Z` on working tree `8c00d55`. Assumption row 1 returned
`137024 total`, contradicting the approved `131746`.

Root cause: commit `f2efda9` ("docs(shipping): add F18 external review
verification gate to Step 7", authored by the user at
`2026-08-21T13:46:50Z` — one minute after the spec's final baseline
observation) added 63 lines (5,278 bytes) to `skills/shipping/SKILL.md`
Step 7, and landed before the spec's draft commit `3cfc809`. The spec's
measurements were taken on a working tree at `da1ffbf` and were correct
when observed; the repository's pre-cycle skill state is now `f2efda9`,
not `da1ffbf`.

Every other retained assumption row rerun at `2026-08-21T14:35:47Z`
matched exactly: descriptions `4561`; M1–M4 `9040`; M5 `3566`; M6 `4575`;
M7/M8/M9 `942`/`402`/`220`; portability references `3+3+3+2`. Verified:
the seven bodies at `f2efda9` total `137024`, and `f2efda9` touched only
`skills/shipping/SKILL.md`.

## Necessity

The contradiction cannot be handled by preserving `da1ffbf` as baseline:

- R7's `git diff da1ffbf..HEAD` would attribute F18's 63 user-authored
  lines to this cycle and demand they be classified `moved` or
  `compressed` — false accounting of work this cycle did not do.
- R5's byte-identical check for shipping Step 7 would compare HEAD against
  the pre-F18 wording and fail on legitimately shipped behavior, or force
  this cycle to revert a user-approved gate.
- SC1's arithmetic (105,000 from 131,746) silently tightens: the F18 gate
  text is itself R5-protected merge-gate wording that cannot be
  compressed, so the approved compression obligation would grow by
  5,278 bytes without review.

F18 cannot be rolled back (user-authored shipped behavior), and the spec
must stay unchanged (approved artifact).

## Observable behavior

No runtime skill behavior changes. This addendum changes only the cycle's
verification baseline and one success-criterion threshold:

- **Baseline revision**: `f2efda9` replaces `da1ffbf` everywhere the spec
  says "baseline revision", including R7's diff base, R5's
  normalized-comparison source (`git show f2efda9:skills/...`), SC3's
  description-mapping baseline side, and SC4's baseline suite-total
  worktree.
- **Assumption row 1**: baseline body total is 137,024 bytes.
- **SC1 ceiling**: 110,000 bytes (was 105,000), stretch 100,000 (was
  95,000). Rationale: 105,000 + 5,278 = 110,278; setting 110,000 preserves
  the approved reduction obligation exactly and rounds 278 bytes stricter.
  Relative to the corrected baseline this is a 19.7% reduction; the
  approved "≥20%" parenthetical was descriptive of the superseded
  arithmetic, and the binding value is the ceiling.
- The shipping Step 7 inviolable wording is `f2efda9`'s version, F18
  included.

All other spec text, scope boundaries, M-table rows, success criteria, and
gates are unchanged.

## Safety and consent boundaries

This addendum authorizes no outward action and changes no gate ownership.
The user approved this addendum first-hand at the planning scope gate on
2026-08-21 before the plan draft was finalized (decision authority per the
artifact-shape authority below).

## Verification changes

- Planning records Assumption row 1 as **contradiction — resolved by this
  addendum**; all other rows as match.
- The plan's baseline-evidence unit checks out `f2efda9` (not `da1ffbf`)
  for suite totals, assertion inventories, and the SC3 baseline mapping.
- R7 derives removals from `git diff f2efda9..HEAD -- skills/`.
- SC1's measurement command threshold reads `≤ 110000`; the stretch reads
  `≤ 100000`.
- The R5 attack-evidence and clause-verification comparisons for
  `shipping` use the F18-inclusive Step 7 section.

## Traceability

- Approved spec: `docs/specs/2026-08-21-instruction-payload-slimming-design.md`
  (draft `3cfc809`, approved `8c00d55`).
- Intervening commit: `f2efda9` (63 insertions,
  `skills/shipping/SKILL.md` only).
- Planning recheck: first-hand run at `2026-08-21T14:35:47Z` on `8c00d55`;
  isolation evidence `git diff --stat da1ffbf HEAD -- skills/` →
  `skills/shipping/SKILL.md | 63 ++`.
- Authority for this artifact shape:
  `docs/solutions/workflow-issues/review-introduced-state-machine-deviation.md`.
