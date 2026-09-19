# Deviation Addendum 003: Auto-design Trade-off Cost Correction

_Recorded 2026-09-19 before implementation resumed._

## Original contract

The approved design at
`docs/specs/2026-09-19-auto-plan-assumption-tradeoffs-design.md` defined the
selected auto-only structured contract and its four-column trade-off table.

## Discovered contradiction

The first standalone validator run against the approved design found that the
selected row's `Measured cost` cell had no numeric quantity. The artifact
therefore failed the active auto-mode contract even though its rejected rows had
numeric values.

## Necessity

The selected option must name a quantified, attributed cost. The approved
artifact remains unchanged as historical evidence. A successor draft records
the measured count of two standalone validator copies and the command that
observed it at `2026-09-19T14:05:58Z`.

## Observable behavior

No runtime behavior changes. The successor design only repairs the evidence
shape required before Architecture and Success Criteria. It does not widen the
selected scope, interactive gates, migration boundary, or publication boundary.

## Safety and consent boundaries

The correction is local and reversible. It changes no protected branch, ledger
authority, credential, network target, or external service. The successor must
receive a fresh human Design approval before planning continues.

## Verification changes

- The successor design passes `validate-auto-artifact.py --mode auto`.
- Its selected and rejected trade-off rows contain numeric measured costs.
- The focused harness continues to require numeric costs in every trade-off row.
- The original approved design remains a historical artifact and is not used as
the implementation origin after the successor approval.

## Traceability

- Original approved design: commit `44ae6f2c938624bd29ba1c92ef5b2322bd5b1df6`.
- Finding: first standalone validator run on 2026-09-19.
- Successor draft: `docs/specs/2026-09-19-auto-plan-assumption-tradeoffs-correction-design.md`.
- Evidence command: validator-copy count at `2026-09-19T14:05:58Z`.
- Authority for this artifact shape:
`docs/solutions/workflow-issues/review-introduced-state-machine-deviation.md`.
