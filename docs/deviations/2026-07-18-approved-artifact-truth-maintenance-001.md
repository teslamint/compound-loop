# Deviation Addendum 001: Always-Present Assumptions Section

_Recorded 2026-07-18 before item 1 plan approval._

## Original contract

The approved design at
`docs/specs/2026-07-18-approved-artifact-truth-maintenance-design.md`
requires a five-field evidence record when a spec makes live assumptions. It
defines a no-origin or zero-assumption fallback for planning, but it does not
require every design spec to contain an Assumptions and Preconditions section.

## Discovered contradiction

External plan review recovered standing user feedback already present in
commit `a8a1318`: the release-skill spec had to gain an explicit Assumptions
and Preconditions section because preconditions kept only in conversation are
not durable. The current spec template still contains no such section, as
confirmed by:

```sh
rg -n "Assumptions|Preconditions" skills/designing/references/spec-template.md
```

The command returned no matches on `feat/process-guidance` at `fd9e211`.

## Necessity

Making the whole section conditional would preserve the template gap that
caused the earlier omission. An explicit section, including a none-fallback,
lets a zero-context planner distinguish "checked and none" from "the designer
forgot to examine assumptions."

## Observable behavior

- Every spec contains an Assumptions and Preconditions section.
- A spec with no live assumptions says so explicitly and names any repository
  invariants that still apply.
- Only specs with live assumptions include the evidence table containing claim,
  exact command, observation timestamp, concise result, and evidence source.

## Safety and consent boundaries

The approved design's evidence-safety boundary is unchanged: committed evidence
must exclude secrets, credentials, personal data, and unbounded raw output.
This addendum creates no new execution or consent gate.

## Verification changes

U1 acceptance now checks three cases: a spec with live assumptions uses the
five-field table, a spec without live assumptions contains an explicit
none-fallback, and neither case commits unsafe evidence.

## Traceability

- Standing feedback: commit `a8a1318`.
- Review source: external plan review delivered first-hand on 2026-07-18.
- Planned change: U1 step 3 in
  `docs/plans/2026-07-18-001-docs-approved-artifact-truth-maintenance-plan.md`.
- Authority for this artifact shape:
  `docs/solutions/workflow-issues/review-introduced-state-machine-deviation.md`.
