---
module: reviewing
date: "2026-08-14"
problem_type: workflow_issue
component: lifecycle-skill
severity: high
applies_when:
  - "the deliverable is an integrity or verification mechanism — a checker, a gate, a guard, a validator whose whole purpose is to reject dishonest or malformed input"
  - "an approved plan or spec specifies that mechanism's rules in prose, and review is dispatched against the plan"
  - "review rounds are passing while the mechanism has never been attacked with an artifact built to satisfy its written checks"
root_cause: "review that verifies conformance to an approved plan can only find defects the plan was specific enough to describe; where the plan under-specifies a rule, conformance review reproduces the gap instead of exposing it"
resolution_type: process_rule
tags:
  - review-mandates
  - integrity-mechanisms
  - adversarial-testing
  - under-specification
related_components:
  - "docs/solutions/workflow-issues/rederive-vs-verify-review-mandate.md"
---

# Verify Against the Plan, or Attack the Invariant

## Context

The 2026-08-14 retro-interview-integrity cycle built a checker whose entire
purpose was to reject retro documents that claim more independence than they
earned. The approved plan specified its conditions in prose, and three internal
branch-review rounds ran against that plan. All three passed.

An external reviewer on the pull request then found two defects in the checker,
both central to what it exists to do:

- `cond_W4` rejected only the verdict `self-attested`. The shipped contract
  says the confirming dispatch records `accepted`, so a document whose
  transcript row carried a rejection verdict still authorized the cheapest
  independence level.
- `cond_W2` compared the two numbers written in a reconciliation bullet and
  never counted the actual table rows, so a forged `registered 2, accounted
  for 2` passed while the tables said otherwise.

Neither was a coding error. The plan had specified W4 as "rejects
`self-attested`" and W2 as "compares the two numbers on the bullet." The
implementation was faithful. The reviews confirmed the implementation was
faithful. Everyone was checking the same under-specified sentence.

The fixes landed as `4da1462` and `490ff91`, and the fixture harness grew from
38 cases to 44.

## Guidance

When the deliverable is a mechanism that exists to reject something, one review
question outranks conformance:

> Construct the cheapest artifact that satisfies every written check while
> violating the mechanism's intent. Does the mechanism reject it?

Run that construction before approval, not after. It is a different act from
reading the diff against the plan, and it finds a different class of defect —
the class the plan failed to describe.

Three practical forms:

1. **Name the invariant in one sentence, separately from the plan's wording.**
   For W4 that sentence was "an empty transcript never authorizes `not-probed`
   when a facilitator was reachable." Once written down, it is obvious that
   rejecting one bad verdict is not the same as requiring the good one.
2. **Attack each check's input, not its logic.** A check that reads a number an
   author wrote proves only that the author can write numbers. Ask where every
   value the check consumes comes from, and whether the party being checked
   controls it.
3. **Prefer a positive requirement to a negative one.** "Rejects
   `self-attested`" enumerates one bad case; "requires `accepted`" closes the
   set. Enumerated rejection lists are where the next case hides.

## Why This Matters

Conformance review is not weak review. It catches drift, dataflow gaps, and
contradictions between units, and it caught many of them in this cycle. Its
blind spot is specific and structural: it inherits the plan's model of what
could go wrong. A plan that fails to imagine a failure mode cannot direct a
reviewer to look for it, and a reviewer checking against that plan will report
clean in good faith.

That blind spot is most expensive exactly when the deliverable is an integrity
mechanism, because there the plan's model of failure *is* the product. A gate
that passes review while accepting the artifact it was built to reject has not
been partially delivered — it has been delivered inverted, and it will report
success while doing nothing.

The same cycle produced a second, related error: the duplicate-name
concealment hole was found internally, classified Minor because the checker
only ever reads disposable fixtures, and triaged as carry-forward. It was the
exact concealment class the spec's own scenario S4 promised to detect. Severity
had been graded against the blast radius of the code rather than against the
criterion the finding threatened.

## When to Apply

Apply when the artifact under review is a checker, validator, gate, guard,
schema constraint, permission boundary, or audit rule — anything whose success
is defined by what it refuses.

Apply also when triaging severity on such an artifact: grade the finding
against the success criterion it threatens, not the reachability of the code
path. A hole in the mechanism a cycle exists to build is never Minor, however
narrow its current blast radius.

Do not apply as a blanket replacement for conformance review. Conformance
review and invariant attack answer different questions, and the first is
cheaper. Run both; run the attack last, when the mechanism is complete enough
to be attacked.

## Examples

**Under-specified negative check, and the artifact that beat it**

The plan said W4 rejects a transcript row whose verdict is `self-attested`.
The cheapest artifact satisfying that check while violating intent is a
document whose row reads `no evidenced answer (3 rejections)` — not
`self-attested`, therefore accepted, while carrying no confirmation at all.
The repaired check requires at least one row whose verdict reads exactly
`accepted`, and case C29 pins it.

**Author-controlled input, and the artifact that beat it**

The plan said W2 compares registered N against accounted-for M on the
reconciliation bullet. Both numbers are written by the party being checked, so
the cheapest artifact is a document with one table row and a bullet reading
`registered 2, accounted for 2`. The repaired check derives both counts from
the actual tables and rejects when the bullet disagrees; cases C30 and C31 pin
each direction.

**The severity error, stated as a rule**

The internal review recorded: duplicate current-row names can conceal a drop
while both counts agree. It graded that Minor because the checker reads only
fixtures. The spec's scenario S4 says the reconciliation exists to catch a
substitution that a matching count conceals. Graded against S4 rather than
against code reachability, the same finding is a direct failure of the
deliverable's stated purpose.

## Related

- `docs/solutions/workflow-issues/rederive-vs-verify-review-mandate.md` — the
  adjacent failure: review inheriting the record author's *reading of a rule*,
  fixed by recomputing from source. This doc covers review inheriting the
  plan's *model of failure*, fixed by attacking the invariant. Both are forms
  of a review that is not independent of the artifact it reviews.
