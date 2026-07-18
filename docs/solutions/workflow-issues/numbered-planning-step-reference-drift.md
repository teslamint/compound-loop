---
module: planning
date: "2026-07-18"
problem_type: workflow_issue
component: structural-validation
severity: medium
symptoms:
  - "inserting or reordering a numbered planning step leaves prose references pointing at the wrong headings"
  - "cross-file references in planning reference documents drift when the main workflow numbering changes"
  - "structural validation passes while review later finds multiple stale step references"
root_cause: position-dependent numbered references are not resolved against heading semantics during validation
resolution_type: validation_rule
applies_when:
  - "a workflow document uses numbered headings and prose references such as step N"
  - "step references cross from a primary skill document into supporting reference files"
  - "a numbered step or schema list item is inserted, removed, or reordered"
related_components:
  - planning
  - plan-schema
  - validation
tags:
  - planning
  - cross-reference-drift
  - structural-validation
  - numbered-steps
---

# Numbered Planning Step Reference Drift

## Context

`skills/planning/SKILL.md` is an ordered procedure whose prose and companion
references point to sections as `step N`. Inserting a heading therefore creates
a fan-out edit across the skill, its reference files, and the numbered
hard-floor list in `schemas/plan-schema.md`.

Commit `da06299` inserted **Assumption recheck** as step 4 but left eight
downstream references stale: six in `skills/planning/SKILL.md` and two in
`skills/planning/references/deepening.md`. Commit `3fb6aa6` repaired them after
external review. `bash scripts/validate.sh` passed before the repair because it
does not resolve ordinal references against heading meaning.

Later, `a13c816` inserted **Mutation/failure-state matrix** as step 10. A
preventive whole-surface audit updated the shifted headings, internal
references, `deepening.md`, and the schema's complete numbered list in the same
commit. The defect did not recur, but the protection remained manual.

## Guidance

Prefer semantic section names over position-dependent ordinals:

- Write **Unit authoring**, not only `step 9`.
- Write **Scenario flow analysis**, not only `step 7`.
- Write **Deepening pass**, not only `planning step 15`.

When a number materially helps navigation, pair it with the exact heading, for
example `planning step 15 (Deepening pass)`. A validator can then prove that
the number exists and the title matches.

Until that validator exists, any insertion, deletion, split, merge, or reorder
of planning headings or schema hard-floor items requires one same-change audit:

```sh
rg -n '^## [0-9]+\.' skills/planning/SKILL.md
rg -n -i '\b(?:planning )?step [0-9]+\b' \
  skills/planning/SKILL.md skills/planning/references/*.md
sed -n '/^## Document body — hard floor$/,/^## Implementation Unit template$/p' \
  schemas/plan-schema.md
```

Check that headings and schema list items are contiguous, then resolve every
search result semantically. Stable identifiers such as `U7`, `S3`, and `AE2`,
and locally scoped numbered steps inside one implementation unit, are separate
identifier domains and should not be rewritten by this audit.

## Why This Matters

Ordinal drift is structurally invisible but semantically dangerous. Markdown
still renders, frontmatter still parses, and the referenced number usually
still exists; it now points to the wrong instruction. Fluent stale prose can
therefore survive general validation and look authoritative until a reviewer
reconstructs the old and new heading maps.

The two commits demonstrate the difference between recovery and prevention:
`3fb6aa6` was an eight-reference follow-up repair, while `a13c816` carried its
numbering repair with the originating insertion. Automation should make the
second behavior the default rather than depend on reviewer memory.

## When to Apply

- Adding or reordering a lifecycle phase or gate.
- Editing a companion reference that points into a numbered workflow.
- Inserting a numbered plan-schema hard-floor section.
- Reviewing a diff that changes `## N.` headings.
- Maintaining any ordered procedure whose prose uses ordinal cross-references.

## Examples

Fragile:

```text
Decomposition in step 8 takes this walkthrough as input.
```

Stable:

```text
Decomposition takes the Scenario flow analysis walkthrough as input.
```

Mechanically checkable when numbering must remain:

```text
The confidence check runs in planning step 15 (Deepening pass).
```

Historical evidence:

```sh
git diff 3fb6aa6^ 3fb6aa6 --unified=0 -- \
  skills/planning/SKILL.md skills/planning/references/deepening.md
git diff a13c816^ a13c816 --unified=0 -- \
  skills/planning/SKILL.md skills/planning/references/deepening.md
```
