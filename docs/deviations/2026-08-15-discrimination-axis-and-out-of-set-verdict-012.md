# Deviation Addendum 012: Discrimination axis binding and out-of-set verdict values

_Recorded 2026-08-15 at the plan approval gate, before the plan was approved or sealed._

## Original contract

The approved spec fixes both shipped wordings verbatim in `docs/specs/2026-08-15-planning-discrimination-and-verdict-coverage-design.md`, section `### Interface — the exact wording to ship`:

```text
- **Discrimination check** — ... Two runs of the same inputs must compare equal; one changed
  input must compare different. A step whose comparands are different artifact kinds fails this
  check outright ...
```

```text
- **Verdict coverage** — ... and include the measurement failing to resolve as one of the
  values. ...
```

Those wordings were themselves the product of an invariant attack at the Design gate, which closed five loopholes (`docs/reviews/2026-08-15-planning-discrimination-and-verdict-coverage-spec-review.md`).

## Discovered contradiction

The independent plan review ran the same invariant attack against the shipped wordings and constructed two artifacts that satisfy every written clause while carrying the defect each check exists to catch.

**Sixth loophole, Discrimination check.** A step verifies that `--optimize` took effect by comparing digests of `coremldata.bin` from a build with the flag against one without, where the flag in fact only rewrites `weights.bin`. The fixture pair is two `coremldata.bin` digests — same artifact kinds, same producing pipeline. Two same-input runs compare equal, observed. For the changed-input half the author swaps the source package, and the digests compare different, observed. Every clause passes: the different-kinds clause does not fire, and the comparison demonstrably returns both answers. Yet the deployed comparison is constant along the `--optimize` axis, so it still cannot report anything about the change under test. The loophole clause is `one changed input must compare different`, which never binds the change to the input or option whose effect the step exists to verify. The approved spec's own SC2 accept rubric blessed the same construction, so the criterion would have accepted it.

**Residual, Verdict coverage.** The measuring step is `grep -c pattern file` with a declared output set of `{0, 1}`, and the origin spec asks only whether the pattern appears, so it enumerates nothing larger. The union is `{0, 1}` plus the unresolved case; each value gets its own next step; nothing is unconsumed. The measurement returns `2` — a value that resolved cleanly, sits in neither source, and has no branch. `failing to resolve` does not cover a value that resolved to something outside the enumerated set.

## Decision

Both wordings gain one clause each. The approved spec stays unchanged as the record of the original decision; this addendum carries the delta, and the plan's U1 and U2 ship the amended text.

- Discrimination check gains: `and the changed input is the very input or option whose effect the step exists to detect, never an arbitrary one`.
- Verdict coverage's unresolved clause becomes: `include the measurement failing to resolve, or resolving to a value outside that set, among the values`.
- The spec's SC2 accept case is amended in the plan's Verification summary so the accept fixture varies the option under test rather than an arbitrary input.

Decision authority: the user, at the plan approval gate, 2026-08-15. This addendum is preparation evidence and grants no execution authority.

## Necessity

The clauses cannot be dropped and cannot be handled by moving an existing check.

Without the axis binding, the Discrimination check accepts the exact defect class issue #11 reported, in same-kind clothing, and SC2's accept half certifies it. Both halves of the criterion would then pass on a mechanism that does not discriminate — the false-green shape this cycle exists to remove.

Without the out-of-set clause, a producible verdict value can have no branch while every written clause is satisfied, which is the defect class issue #12 reported.

Editing the approved spec instead would erase the record that the original wording was approved and would let the sixth loophole disappear from the history that explains why the clause exists.

## Observable behavior

No runtime behavior changes: the deliverable is prose in `skills/planning/SKILL.md` step 14.

For a future plan author, two obligations tighten. A comparison step must vary the option or input whose effect it verifies, not any input that produces a difference. A verdict-emitting unit must give a branch or a Deferred entry to values outside its enumerated set, alongside the unresolved case.

Both additions are conditional on the same trigger shapes the approved spec already established, so a plan with no comparison step and no verdict-emitting unit is unaffected.

## Safety and consent boundaries

No new outward action, no new authorization. Posting the issue closing payloads stays a human action at the Ship gate.

## Verification changes

- Success: `sed -n '/^## 14\. Self-review/,/^## 15\./p' skills/planning/SKILL.md | grep -c 'never an arbitrary one'` returns `1`, and the same range piped to `grep -c 'outside that set'` returns `1`.
- Discrimination: both commands return `0` on the pre-change tree, established at `2026-08-14T20:06:11Z`.
- Rerun: the two commands are idempotent reads with no side effects.
- Rollback: reverting U1 and U2 removes both clauses; no other file depends on them.
- Headless: no interactive step; both probes are non-interactive greps.
- Forced failure: deleting either clause from the shipped bullet makes its probe return `0`, which fails the amended SC2 and SC3 rubrics.
- The amended SC2 accept case must be walked with the option under test varied; an accept recorded on an arbitrary changed input is a rubric failure.

## Traceability

- Approved specification: `docs/specs/2026-08-15-planning-discrimination-and-verdict-coverage-design.md` (unchanged).
- Draft plan carrying the amended wording: `docs/plans/2026-08-15-001-fix-planning-discrimination-and-verdict-coverage-plan.md`.
- Review findings: `docs/reviews/2026-08-15-planning-discrimination-and-verdict-coverage-plan-review.md`, findings 1 and 2.
- Prior invariant attack that closed the first five loopholes: `docs/reviews/2026-08-15-planning-discrimination-and-verdict-coverage-spec-review.md`.
- Tracker row that mandated the attack: `ROADMAP.md` line 59.
- Addendum authority: `docs/solutions/workflow-issues/review-introduced-state-machine-deviation.md`.
