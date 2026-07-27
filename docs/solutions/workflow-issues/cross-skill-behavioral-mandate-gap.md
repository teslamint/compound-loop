---
module: planning
date: "2026-07-27"
problem_type: workflow_issue
component: skill-definition
severity: medium
applies_when:
  - a fix adds a mandate that a different skill should perform
  - a procedure in skill A prescribes behavior executed by skill B
  - the consuming skill's entry path does not read the mandating skill
related_components:
  - implementing
  - release-loop
tags:
  - cross-skill
  - mandate
  - skill-boundary
  - dead-prose
---

## Context

A fix to planning's step 1 proposed adding: "The implementing work's first
commit message notes that planning was skipped." This mandate was written in
`skills/planning/SKILL.md` for an action `skills/implementing/SKILL.md` would
perform. A fresh implementing subagent — the recommended handoff path — reads
only its own skill definition and never sees planning's.

The advisor caught the gap before commit. The fix was revised to remove the
cross-skill mandate and keep the documentation mechanism within planning's own
control surface (attestation in the session, Log entry in progress.md).

The irony: the fix was for under-specification (Exit said "documented skip" but
step 1 didn't say how), and the initial fix reproduced the same class of bug —
specifying a mechanism in a place its executor doesn't read.

## Guidance

A behavioral mandate is effective only when the executing skill's entry path
reads it. Before shipping a procedure that says "skill B should do X":

1. **Verify B's entry reads A.** Open the consuming skill's SKILL.md and
   check whether its entry, pre-flight, or commit protocol references the
   mandating skill. If not, the mandate is dead prose.
2. **Prefer keeping the mechanism in the mandating skill's control surface.**
   If planning owns the skip decision, planning should own the record — don't
   delegate the record to a skill that doesn't know it's been delegated to.
3. **When a cross-skill mandate is genuinely needed**, add the counterpart line
   in the consuming skill in the same commit. A mandate without its receiver
   is the behavioral equivalent of a schema field without a slot.

## Why This Matters

Skill definitions are read independently — a subagent dispatched to implement
reads `implementing/SKILL.md`, not the entire skills directory. A mandate in
skill A that skill B should do X is invisible to B's executor unless B's own
text says so. The result: compliant executions that miss the mandated behavior,
identical to the `mandated-field-absent-from-schema.md` pattern but in
behavioral rather than data form.

The recursive shape — a fix for under-specification that is itself
under-specified — suggests the failure mode is particularly resistant to
self-review. The author knows what they mean; the specification gap is visible
only from the reader's (or advisor's) vantage.

## When To Apply

- Writing a procedure that says another skill, agent, or subagent "should"
  or "must" do something.
- Reviewing a fix that adds inter-skill coordination.
- Diagnosing why a mandated behavior keeps not happening despite the mandate
  existing in prose.

## Examples

**The dead mandate (caught pre-commit):**

```markdown
# skills/planning/SKILL.md, step 1
When skipping, ... The implementing work's first commit message notes that
planning was skipped — this is the durable record.
```

A fresh implementing subagent reads `skills/implementing/SKILL.md`. That file
says nothing about noting skipped planning in commit messages. The mandate is
dead prose.

**The fix — keep it on the mandating skill's surface:**

```markdown
# skills/planning/SKILL.md, step 1
When skipping, attest that all four conditions hold, citing the work's scope,
then hand off directly to `implementing`. When invoked from `release-loop`,
also write the skip to `.release-loop/progress.md`'s Log section...
```

Planning owns the attestation; planning owns the Log write. No cross-skill
mandate needed.

## Related

- `mandated-field-absent-from-schema.md` — the data-schema variant: a mandate
  to persist X into record R where R has no field for X. Same genus (mandate
  without matching slot), different species (data field vs. behavioral
  instruction). That doc's guidance ("treat the schema as the defect") maps
  here as "treat the consuming skill's definition as the defect."
