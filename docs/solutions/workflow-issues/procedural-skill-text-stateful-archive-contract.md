---
module: release-loop
date: "2026-08-03"
last_updated: "2026-08-03"
problem_type: workflow_issue
component: loop-archive
severity: medium
applies_when:
  - "procedural skill text authorizes durable local mutation even though the implementation diff is documentation-only"
  - "a resume or retry path must preserve one durable destination across interrupted moves"
  - "planning is deciding whether a mutation or failure-state matrix is required"
  - "completion must be verified against the exact current artifact path, not a glob or recency rule"
related_components:
  - planning
  - reviewing
  - retrospective
tags:
  - release-loop
  - workflow-contract
  - state-machine
  - documentation-only-diff
  - idempotency
  - persisted-identity
  - archive-integrity
---

## Context

PR #3 changed only Markdown contracts.
Its plan therefore declared no stateful ceremony or mutation matrix.

The changed skill text still authorized durable runtime behavior.
It moved local state, recovered partial work, recognized completion, and resumed after interruption.

PR review found six valid findings across five threads.
Addendum 005 recorded the missing runtime contract before corrective implementation.

This guidance complements
`docs/solutions/workflow-issues/review-introduced-state-machine-deviation.md`.
That document governs post-approval deviations.
This document governs the earlier classification mistake that makes such deviations likely.

## Guidance

Classify procedural workflow text by the runtime transitions it authorizes.
Do not classify it only by the edited file type.

1. List every durable state that the procedure creates or recognizes.
2. Add a mutation/failure-state matrix when those transitions cross invocations.
3. Persist the identity required to resume before the first mutation.
4. Make interrupted reruns consume that identity instead of recomputing it.
5. Define explicit predicates for completed, incomplete, corrupt, and ambiguous records.
6. Verify the exact artifact produced by the current run.
7. Record review-introduced observable branches in a committed deviation addendum.

For archive workflows, persist the collision-resolved destination before any move.
Treat that destination as authoritative on every rerun.

Do not use traversal order, a directory glob, or the newest record as identity.
Those approaches can select an older or incomplete durable record.

## Why This Matters

Documentation can act as executable policy for later agents.
A prose defect can therefore become a data-integrity or security defect.

PR #3 exposed five runtime failure classes:

- raw feature input could escape the declared archive root;
- a rerun could split one loop across two suffixed destinations;
- resume could report an incomplete archive as complete;
- corruption backups could remain in live working state; and
- final verification could pass against an older archive.

All five defects came from missing durable identity or incomplete state predicates.
The Markdown-only diff did not reduce their runtime impact.

## When to Apply

Apply this guidance when procedural text does any of the following:

- moves, renames, archives, or deletes durable local state;
- defines retry, resume, recovery, or reconstruction behavior;
- recognizes prior work from files, logs, or frontmatter;
- reuses a selector, slug, path, or key across invocations;
- allows interruption between a record write and terminal action; or
- treats a Log entry as operational evidence.

Use it before approving changes to lifecycle skills, progress schemas, and recovery contracts.

## Examples

### Classify by runtime effect

The archive plan used `execution: non-code` because its tracked files were Markdown.
The skill still defined a state machine with live, incomplete, completed, corrupt, and interrupted states.

The correct planning question is not "Does this diff contain code?"
Ask "What durable transitions will future agents execute because this text changed?"

### Persist identity before mutation

The archive procedure now writes one canonical
`archive-destination: <path>` marker before it moves any file.

An interrupted rerun reads that path and moves only remaining state.
It never recalculates a collision suffix.

### Verify the current result

The original completion check used a directory glob.
An older archive could satisfy it.

The corrected workflow retains the exact path returned by the current procedure.
It verifies feature identity, terminal state, destination evidence, and retro evidence there.

### Assign post-Retro proof to the completion gate

The retrospective could not verify its own terminal archive because archiving runs after Retro exits.
The release-loop completion gate retained the exact returned path instead:
`.release-loop/archive/2026-08-03-archive-on-loop-completion`.

That record contains the expected feature, completed phase, executed final action,
retro path, retro commit evidence, and canonical destination Log entry.
The live `.release-loop/progress.md` is absent.

Assign criteria that fire after Retro to this completion gate.
Do not mark them complete from an earlier retrospective measurement pass.
