---
module: planning
date: "2026-07-24"
problem_type: workflow_issue
component: lifecycle-skill
severity: medium
applies_when:
  - "a plan, spec, or process artifact contains a self-auditing record (an audit table, attestation line, inventory, traceability walk) authored by the same agent that executed the underlying procedure"
  - "an independent review is being dispatched over that artifact and the prompt author must choose between checking the record's claims and recomputing the record"
  - "the rule governing the record has multiple arms or clauses and was recently authored or revised"
root_cause: "verify-the-claims review inherits the record author's reading of the governing rule, so any clause the author misapplied is invisible; only recomputation from source is independent of that reading"
resolution_type: process_rule
tags:
  - review-mandates
  - re-derivation
  - trigger-audit
  - self-auditing-records
---

# Re-Derive vs Verify: Review Mandates for Self-Auditing Records

## Context

In the 2026-07-24 planning-trigger-audit cycle, the spec's R6 required that
any independent plan review "re-derives this audit — open tracker rows versus
the plan's File structure and the audit section's dispositions — rather than
trusting the section's claims."

On the mandate's very first execution, the reviewer's independent
re-derivation returned a fired set of 7 rows against the draft plan's 5. The
draft's author had applied only one arm of the two-armed latching rule (R2a:
a recorded firing counts whether recorded "in the tracker itself, or a prior
retro's reconciliation") — the tracker-annotation arm caught one row, while
two rows latched only through the prior retro's reconciliation records were
missed. The author had written R2a hours earlier in the same session
(commits `f6bceaf` draft vs `1df40a9` fix; probe record in the cycle's retro
transcript, facilitator-verified).

A verify-the-claims review would have walked the five recorded rows, found
each individually well-evidenced, and passed the section: every present row
was correct; the defect was two absent rows, and absence is invisible when
the record defines the checklist.

## Guidance

When mandating independent review of a self-auditing record:

1. Phrase the mandate as **re-derive from source**: name the source of truth
   (the tracker, the file list, the inventory origin) and require the
   reviewer to recompute the record from it, then diff their result against
   the recorded one.
2. Make an omission a **blocking** finding by name — the reviewer's
   recomputed set minus the recorded set is the check that catches absent
   rows.
3. Carry the re-derive instruction **into the dispatch prompt verbatim**
   whenever the reviewer will not read the skill text that defines the
   mandate — a mandate that lives only in a skill file does not travel with
   the dispatch.
4. Do not treat recency of authorship as protection: the rule's author is
   the person most likely to under-apply it, because their working memory of
   the rule substitutes for reading its clauses.

## Why This Matters

The two review shapes fail differently. Verify-the-claims scales cheaply but
shares the author's reading — it audits presence, not completeness.
Re-derivation costs one recomputation and is the only shape whose result set
can contain rows the author never wrote. For records whose failure mode is
omission (audits, attestations, drop-lists, traceability walks), only the
second shape addresses the actual risk.

## When to Apply

- Writing a spec requirement or skill rule that mandates review of an audit,
  attestation, inventory, or coverage map.
- Composing a review dispatch prompt over any artifact containing a
  self-auditing record — include the source-of-truth pointer and the
  recompute-then-diff instruction.
- Reviewing such an artifact yourself: recompute first, read the record
  second; never walk the record's own rows as the checklist.

## Examples

The catch: draft plan (`f6bceaf`) audit table recorded fired =
{45, 48, 55, 56, 58}; the reviewer re-derived {45, 47, 48, 54, 55, 56, 58}
from ROADMAP's open rows plus the prior retro's reconciliation records; the
two-row difference was reported as a blocking P1 and fixed (`1df40a9`) with
the attestation corrected from "5 fired" to "7 fired".

The contrast case: the same repo's spec-review empirical-grounding rule
(docs/solutions/workflow-issues/spec-review-empirical-grounding-gap.md)
requires rerunning retained *commands* — the same recompute-over-read
principle applied to assumption evidence rather than record completeness.
