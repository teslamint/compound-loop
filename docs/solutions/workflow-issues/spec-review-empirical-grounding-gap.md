---
module: release-loop
date: "2026-07-16"
problem_type: workflow_issue
component: designing
severity: medium
applies_when:
  - "a spec's Testing/Scenario section names a specific existing file, line, or example as an illustration of expected behavior"
  - "an independent spec review checks internal logic consistency but doesn't execute anything against the live repository"
related_components:
  - planning
  - reviewing
tags:
  - spec-review
  - tdd
  - fixture-design
  - release-loop
---

## Context

During the `signal-drift-check` feature pilot (a `scripts/validate.sh` check that
detects drift between terminal-signal lines quoted in three consumer
`SKILL.md` files and their canonical definitions in
`schemas/headless-contract.md`), the Design phase's independent review
(`codex exec -s read-only`) caught a real gap — the original spec only
validated *found* candidate spans, missing a coverage pass for deleted
signal lines — and the review was correctly credited for that catch.

But the same review, and the author's own self-review, both missed two
separate defects in the spec's own illustrative Testing-section examples:

1. The spec named `skills/compound/SKILL.md`'s `Documentation skipped`
   clause as the example for "deleted signal line triggers the coverage
   pass" — but that exact canonical line is cross-quoted a second time
   inside `skills/retrospective/SKILL.md`'s Phase 7 section. Deleting only
   the `compound/SKILL.md` copy, as the spec's own fixture Case
   instructed, would never actually trigger the coverage pass, because the
   line stays "seen" via the cross-quote.
2. The spec's Testing-section fixture cases for "malformed contract" and
   "missing consumer file" assumed these would fail because the *new*
   check doesn't exist yet — but `scripts/validate.sh`'s pre-existing
   checks (file-presence and skill-roster checks) already independently
   produce a failure for those same mutations, for unrelated reasons.

Both defects were caught only during Implement, by actually running the
fixture harness and reading the output (P3 in the plugin's own principles) —
never by re-reading the spec text more carefully. The independent review
had verified the spec's *internal logic* (does the proposed regex match
the spec's own worked example, is the architecture internally coherent)
but never executed anything against the *live repository* to check
whether the spec's chosen illustrative examples were still grounded in
the actual current file contents.

## Guidance

When a spec's Testing or Scenario section names a specific existing
file/line as the illustration for a behavior — especially a "this input
should trigger this failure mode" claim — verify it against live repo
content with the cheapest possible command *before* treating the
illustration as settled:

- **"Deleting/mutating X should be the only thing that changes" claims**:
  grep for every other place the same string, value, or line appears in
  the repo. A canonical string quoted in two files, when the fixture only
  mutates one of them, silently fails to exercise the mechanism it's
  supposed to prove.
- **"This currently fails because the feature doesn't exist yet" claims**:
  actually run the existing tooling (the check, script, or test suite as
  it stands *before* the new feature) against the proposed fixture
  mutation. A different, unrelated, already-existing mechanism may
  already produce the same-looking failure, which means the fixture
  doesn't prove what it claims to prove once the new feature exists.

Both checks are single commands (a `grep`, or one run of the pre-feature
tooling) — cheaper than writing the fixture code, and they belong at
Design-review time or Plan-authoring time, not discovered mid-Implement
after the fixture is already wired into working code.

## Why This Matters

Internal-consistency review (does the regex match the example, is the
architecture coherent) and empirical-grounding review (is the example
still true against the live repo) are different checks that catch
different failure classes. A review that only does the first kind will
structurally miss the second kind every time, no matter how many passes
it runs or how careful the reviewer is — the gap isn't reviewer
diligence, it's scope. Two independent full reviews (an LLM-driven
independent review plus the author's own self-review) both missed the
same two empirical-grounding gaps in this pilot, which is exactly the
signature of a scope gap rather than an attention lapse.

## When to Apply

Any spec, plan, or test-design document that cites a *specific existing
file, line, string, or piece of live system state* as a worked example —
not just for drift/coverage checkers, but any feature whose fixture
design assumes something about the current shape of a codebase or
config. Low-cost to apply (one grep or one dry run), high payoff (avoids
building a fixture that either passes for the wrong reason or fails to
prove anything).

## Examples

- `grep -rn "<the-exact-string-being-deleted>" <the-files-in-scope>` before
  writing a "deleting this proves the coverage pass" test case — if it
  appears more than once, the fixture must mutate *all* occurrences or
  target a different, single-occurrence instance.
- Run the *current, pre-feature* version of the tool being extended
  against the exact fixture mutation planned for a "this currently fails"
  claim — if it already fails (for any reason), the claim is false and
  the fixture needs a distinguishing marker or a different target.
