# Deviation Addendum 002: Auto-plan Assumption Contract Correction

_Recorded 2026-09-19 before implementation resumed._

## Original contract

The approved plan at
`docs/plans/2026-09-19-001-feat-auto-plan-assumption-tradeoffs-plan.md`
was intended to carry the approved auto artifact contract into four
implementation units. Its `Trade-offs` section has the required four-column
table, and its `Assumption Recheck` section records planning outcomes.

## Discovered contradiction

A pre-implementation contract review found that the approved plan's
`Assumptions and Preconditions` section used the three-column planning
`Assumption Recheck` shape instead of the required five-field evidence table:
claim, exact rerunnable command, observation timestamp, concise result, and
evidence source. The active auto-mode requirement applies to plans as well as
specs, so the plan did not satisfy its own front-loaded assumption contract.

## Necessity

Implementation cannot start from an approved plan that fails the active
artifact contract. The plan body must gain the missing five-field table while
retaining the separate three-column `Assumption Recheck` authority required by
`plan/v1`. The plan is corrected and re-sealed before any implementation file
changes.

## Observable behavior

No runtime or interactive behavior changes. The correction changes only the
planning artifact's evidence structure and adds no implementation unit,
validator rule, dependency, or outward action.

## Safety and consent boundaries

The correction is local and reversible. It changes no skill, script, release
ledger authority, credential, network target, or protected branch. Auto plan
approval remains bounded by the validator, body seal, and exact progress ledger.

## Verification changes

- The corrected plan contains a five-field `Assumptions and Preconditions`
table before Architecture notes.
- The corrected plan retains a separate `Assumption Recheck` section with one
outcome per retained claim.
- `validate-plan-frontmatter.py` recomputes the corrected body seal.
- The implementation harness must validate the same five-field requirement for
auto specs and plans and must fail when any field is blank or missing.

## Traceability

- Original approved plan: commit `d17ee7e59f9a7e95fc8e24de62c47b420d71195c`.
- Finding: pre-implementation contract review on 2026-09-19.
- Affected artifact: `docs/plans/2026-09-19-001-feat-auto-plan-assumption-tradeoffs-plan.md`.
- Authority for this artifact shape:
`docs/solutions/workflow-issues/review-introduced-state-machine-deviation.md`.
