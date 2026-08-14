---
module: references/dispatch-degradation
date: "2026-08-15"
problem_type: workflow_issue
component: degradation-ladder
severity: high
symptoms:
  - "a ladder rung joins a caller flag and an environment capability with a slash, so setting the flag reads as satisfying the rung"
  - "the cheapest rung is claimed in nearly every run while the top rung is never exercised"
  - "a justification names a mode or a budget rather than a primitive the environment lacks"
applies_when:
  - "a skill degrades from an independent worker to a self-performed fallback"
  - "a rung's entry condition mentions a caller-supplied flag, mode, or budget"
  - "auditing why a quality-preserving path is never taken in practice"
root_cause: a rung stated as a flag lets the caller authorize its own degradation, because the flag is always true when the caller says so while a capability is a fact about the environment
resolution_type: capability_only_rung_definition
related_components:
  - retrospective
  - reviewing
  - release-loop
tags:
  - degradation-ladder
  - independence
  - self-assessment-bias
  - capability-vs-flag
  - audit-signal
---

## Context

This repo's `retrospective` skill degraded its facilitator selection down a
ladder ending in a self-checklist. The floor rung's condition joined a caller flag
to an environment capability with a slash — roughly "no subagent primitive /
`mode:headless`". Any headless run therefore read as legally entitled to the
floor.

The measured consequence: of 18 retro documents with zero interview rounds, 17
cited headless as the reason. The thesis that the independent path was untested
turned out to be false — 7 retros did reach an independent facilitator — but the
incentive was real, and it was filed as issue #6.

The repair (`0086cff`) makes rung 4 capability-only, states that `mode:headless`
qualifies for no rung, and adds the same rule for a budget: a budget is a choice
about spend, not a missing primitive. A degraded claim must now name the absent
capability across the whole ladder, and the retro that measured this fix was
itself the counter-example — its same-family subagent lane died on an API error
while the external CLI carried the review, proving the two channels fail
independently.

## Guidance

- **State every rung as a capability**, phrased as a fact an outside party could
  check: "no subagent primitive is available", "no external facilitator CLI is on
  PATH". If the condition can be made true by passing an argument, it is not a
  rung condition.
- **Enumerate the channels the ladder actually has.** A single "no worker
  available" clause hides the case where one of two independent channels survives.
  Name each channel, and require a degraded claim to name all of them.
- **Never let a spend limit enter the ladder.** A budget cap changes what you
  choose to do, not what the environment can do; treating it as a rung condition
  turns every constrained run into a licensed degradation.
- **Audit by distribution, not by rule.** Count how often each rung is claimed. A
  floor rung claimed in nearly every run is evidence of a definition defect, even
  when each individual claim looks conformant.
- **Gate the cheapest rung hardest.** Where a rung is reachable with no dispatch
  at all, require a confirming dispatch when any channel is reachable, and treat
  self-confirmation as invalid — the party that benefits from the claim cannot be
  its own witness.

## Why This Matters

A flag-shaped rung inverts the purpose of a degradation ladder. The ladder exists
to preserve quality when the environment cannot support the best path; a flag lets
the caller declare the environment insufficient. Because each claim is locally
conformant, review cannot catch it one document at a time — only the distribution
across many runs reveals it.

The failure is self-reinforcing in exactly the place it does most damage:
self-assessment. When the degraded path is the one where an agent grades its own
work, a cheap route to that path removes the independent check the process was
built around.

## When to Apply

- Writing or reviewing any fallback ladder — facilitators, reviewers, verifiers,
  model tiers, dispatch tiers.
- A rung mentions a mode, flag, budget, or "if time permits".
- One rung dominates the observed distribution.
- Adding a new rung reachable with less work than an existing abused rung; check
  whether it has become the cheaper floor rather than a genuine new state.

## Examples

Flag-shaped rung — the caller authorizes its own degradation:

```
Tier 4: no subagent primitive / mode:headless -> run the checklist yourself
```

Capability-only rung, with both channels named and the flag explicitly excluded:

```
Tier 4: no subagent primitive AND no external facilitator CLI
        -> run the checklist yourself, naming both absent capabilities
        mode:headless does not qualify for this tier; it governs whether the
        user is asked blocking questions, not what the harness can dispatch.
        A strict dispatch budget does not qualify either.
```

Audit query that exposes the defect:

```
# how often is the floor rung claimed, and with what justification?
rg -c "self-checklist" docs/retros/ | sort -t: -k2 -rn
rg -n "headless" docs/retros/*.md | wc -l
```
