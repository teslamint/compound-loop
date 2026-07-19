---
module: planning
date: "2026-07-19"
problem_type: workflow_issue
component: assumption-recheck
severity: medium
symptoms:
  - "an approved live-assumption evidence command returns a different result when planning reruns it exactly"
  - "the underlying empirical claim remains true only after correcting the evidence command"
root_cause: retained evidence command encoded a different quoted needle than the source text it claimed to count
resolution_type: evidence_correction_addendum
applies_when:
  - "an approved spec retains executable evidence for a live assumption"
  - "planning obtains a contradiction while the underlying claim may still hold"
related_components:
  - designing
  - planning
  - implementing
tags:
  - assumption-recheck
  - live-evidence
  - command-quoting
  - deviation-addendum
  - approved-artifacts
---

## Context

An approved claim and the command recorded as its evidence can have different
truth values. The Python compatibility gate exposed this distinction during the
first live planning Assumption Recheck under the approved-artifact
truth-maintenance rules:

- Approved spec commit `4566b7c` retained an inline Python count command and an
  observed result of one unique nested-regex match.
- Planning reran that command byte for byte and observed `0`. An unintended
  escaped quote meant the command did not count the source text it claimed to
  measure.
- The underlying uniqueness claim still held: a corrected fixed-string command
  returned `1` and identified the intended source line.
- Commit `1b297f2` preserved the approved spec and recorded Deviation Addendum
  002 before plan approval commit `b751e1f`.
- Implementation commit `b8ceac1` required the corrected count to equal one
  immediately before the disposable mutation; `1856a4f` carried the same
  precondition into public structural validation.

This is related to
[`review-introduced-state-machine-deviation.md`](review-introduced-state-machine-deviation.md),
which defines the addendum authority, and
[`spec-review-empirical-grounding-gap.md`](spec-review-empirical-grounding-gap.md),
which prevents untested evidence before approval. This case covers the bridge:
planning discovers after approval that the retained evidence command itself is
not reproducible.

## Guidance

Rerun every retained live-evidence command exactly during planning. Compare its
exit status and bounded output with the approved evidence row before using the
assumption to structure implementation.

When the fresh result contradicts the recorded result:

1. Classify it as a contradiction even if a simpler command still proves the
   underlying claim.
2. Do not silently repair quoting, reinterpret intended meaning, or rewrite the
   approved spec.
3. Commit a deviation addendum that preserves the original command/result,
   records the fresh contradiction, and supplies corrected bounded evidence.
4. Commit the addendum before plan approval so the plan can cite it as the
   active evidence source.
5. Make implementation fail closed on the corrected precondition wherever the
   assumption controls selection, replacement, or mutation.

Prefer fixed-string cardinality checks over nested interpreter/string/shell
quoting when the question is whether source text occurs exactly once. The
smallest command that directly measures the claim is usually the easiest to
reproduce and audit.

## Why This Matters

Semantic truth and evidentiary reproducibility are separate. A mutation target
may genuinely be unique while the approved command offered as proof matches
nothing. Accepting intended meaning instead of observed output preserves the
claim but destroys the audit trail.

The addendum path preserves both forms of truth:

- the approved spec remains the historical record of what was reviewed;
- the addendum records the evidence defect and the corrected operational proof;
- the plan explicitly names the contradiction rather than laundering it into a
  match; and
- implementation consumes the same corrected proof immediately before the
  risky operation.

## When to Apply

Use this pattern when an approved spec contains a live assumption whose evidence
is a command, query, count, path lookup, or other executable observation, and a
later exact rerun disagrees with the recorded result.

It is especially important when the evidence controls:

- a unique replacement or mutation target;
- file, symbol, or registry cardinality;
- endpoint or interpreter selection;
- a safety boundary or fail-closed classification; or
- whether implementation may omit a fallback or migration path.

A result mismatch caused by environment drift is still a contradiction until
identified and recorded. The addendum should distinguish command defects,
environment changes, and a genuinely false underlying claim.

## Examples

### Unique mutation target

**Approved claim:** a generated-program regex occurs exactly once and is safe to
mutate in a disposable fixture.

**Fresh result:** the approved inline Python command returns zero because its
quoted needle contains an unintended escaped quote. A corrected `grep -F -c`
returns one.

The deviation addendum should retain both results, state that product behavior
is unchanged, record the corrected command and source location, and require the
fixture to stop before mutation unless the corrected count is exactly one.

### Prevention checklist

- Capture stdout and exit status from the exact approved command.
- Keep the original contradiction visible in the plan's Assumption Recheck.
- Use the fewest quoting layers needed to prove cardinality.
- Reuse the corrected literal precondition immediately before replacement.
- Verify the mutation touches only a disposable copy.
- Never let a helper substitute inferred intent for a failed empirical
  precondition.
