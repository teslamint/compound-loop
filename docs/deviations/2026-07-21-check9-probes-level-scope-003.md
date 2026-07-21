# Deviation Addendum 003: Check 9 Independence-Level Scope Extension to the Probes Contract

_Recorded 2026-07-21 after the pre-merge reviewing phase, before merge._

## Original contract

The approved plan at
`docs/plans/2026-07-20-002-feat-retro-interview-enforcement-plan.md` contains
two clauses about check 9's independence-level validation that conflict:

- Architecture note (plan line "Source-of-truth direction"): "The drift check
  reads the template as canonical and asserts the two skill files agree" —
  naming both `skills/retrospective/SKILL.md` and
  `skills/retrospective/references/interview-probes.md` as checked consumers.
- U5 step 2: "assert each level value appears in
  `skills/retrospective/SKILL.md`" — scoping the level assertions to SKILL.md
  only; the probes file is asserted only for the verdict-vocabulary anchors.

The implementation (`scripts/validate.sh` check 9, commit `707e86f`) followed
U5 step 2 literally.

## Discovered contradiction

The pre-merge reviewing phase's adversarial lane proved the gap by fixture:
renaming the degraded rung (`self-checklist`) in both
`schemas/retro-template.md` and `skills/retrospective/SKILL.md` passes check 9
while `skills/retrospective/references/interview-probes.md` keeps the stale
name — the probes contract's headless mapping ("runs as a fixed
self-checklist … under the `self-checklist` independence level") then cites a
level the closed vocabulary no longer defines. The plan-internal conflict
(architecture note vs. U5 step 2) makes this a plan-mandated conflict per the
implementing skill's rule 7, so it was escalated to the user rather than fixed
unilaterally.

## Decision

The user resolved the conflict on 2026-07-21 in favor of the architecture
note ("A안"): check 9 also validates independence-level vocabulary against the
probes contract. Scope of the extension: the probes contract cites exactly one
rung — the degraded self-checklist mode, the list-final value of the
template's `Independence level:` line. Check 9 therefore asserts that the
list-final canonical level appears (boundary-aware) in
`skills/retrospective/references/interview-probes.md`. Requiring all four
levels there would force artificial mentions of rungs the probes contract
never uses, which the architecture note does not demand.

## Necessity

Without the extension, a template+SKILL co-rename silently strands the probes
contract on a stale level name, and the transcript header vocabulary the
template mandates diverges from the mode mapping facilitators are instructed
to follow. Review cannot return `clean` over a proven-by-fixture drift class
that the plan's own architecture note says the check covers.

## Observable behavior

`scripts/validate.sh` check 9 gains one failure mode: a named `FAIL:` line
when the template's list-final independence level is absent from
`skills/retrospective/references/interview-probes.md`. The `ok:` line, exit
codes, all existing failure modes, and every other check are unchanged. No
skill prose, template, or schema content changes.

## Safety and consent boundaries

The extension reads two tracked files and performs no mutation, network
access, or outward action. The fixture harness case that proves it mutates
only disposable `mktemp -d` copies, never the real worktree files. No push or
merge occurs; merge remains a USER gate.

## Verification changes

- `scripts/test-retro-format-drift.sh` gains Case G: co-rename
  `self-checklist` → `solo-checklist` in the template and SKILL.md copies,
  leave the probes copy untouched, assert nonzero exit and a `FAIL:` line
  naming both the probes file and the missing level value. Committed red
  before the check extension lands (same red-then-green ordering as the
  U4/U5 precedent).
- Case A (clean repo) must stay green: the current list-final value
  `self-checklist` already appears in the probes contract.

## Traceability

- Approved spec: commit `6a71cb4`
  (`docs/specs/2026-07-20-retro-interview-enforcement-design.md`).
- Approved plan: commit `5872802`; the conflicting clauses are the
  "Source-of-truth direction" architecture note and U5 step 2.
- Implementation that followed U5 step 2: commit `707e86f`.
- Reviewing-phase finding: F2 (P2), recorded in `.release-loop/progress.md`
  (reviewing-phase entry, 2026-07-21); the co-drift fixture reproduction is
  the adversarial lane's evidence.
- User decision: 2026-07-21, "F2는 A안으로 하죠" (extend per the architecture
  note).
- Authority for this artifact shape:
  `docs/solutions/workflow-issues/review-introduced-state-machine-deviation.md`.
