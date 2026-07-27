---
title: Plan status terminal states and frontmatter validation
status: approved
date: 2026-07-27
schema: spec/v1
---

# Plan Status Terminal States and Frontmatter Validation Design

_Created 2026-07-27._

## Overview

`schemas/plan-schema.md`'s `status` enum declares five values, three of which
(`in-progress`, `done`, `abandoned`) have no writer, no reader, and no instance
anywhere, while a fourth value plan authors actually use (`superseded`) is absent
from it. This spec settles the enum at `draft | approved | done | superseded`,
gives each terminal state a named writer and a required evidence field, and ships
a `plan/v1` frontmatter validator so out-of-enum values stop landing silently.

The trigger is a 2026-07-26 session in `teslamint/resume-builder` that curated a
private repository into a public export. Its operator set `status: done` on a
finished plan, could not say what the value meant or which skill prescribed it,
and reverted to `approved`. Two out-of-enum values are meanwhile tracked in that
repository's plans today.

## User Scenarios

### S1: `retrospective` records a plan's completion where the plan can be read

A retro runs after a merged PR. It already reads the plan's `origin:` to find the
spec. It now also flips the plan to `status: done` and writes `completed_by:`
with the merge commit, in the same commit as the retro doc.

```bash
git log --oneline -- docs/plans/2026-07-23-001-feat-evidence-tier-vocabulary-plan.md
# bfeda57 docs(plan): Approve evidence-tier vocabulary plan
# 3c7f308 docs(plan): Incorporate independent plan review findings
# 7731b86 docs(plan): Draft evidence-tier vocabulary implementation plan
#   -- the merge commit 33e8bc6 is absent; nothing indexes it from the plan
```

Why it matters: 12 of 14 retros reference a plan path, so completion *is*
recorded — in the retro→plan direction only. `completed_by:` is the reverse
pointer, and it is the only content `status: done` adds that is not already
derivable.

### S2: `planning` supersedes a plan when its successor is committed

A plan is replaced rather than executed. In the same commit that commits the
successor, `planning` flips the predecessor to `status: superseded` and writes
`superseded_by:` naming the successor's path. The successor's own status at that
moment is irrelevant: supersession is a decision about the predecessor.

```yaml
# docs/plans/2026-07-25-003-chore-public-history-purge-plan.md
status: superseded
superseded_by: docs/plans/2026-07-25-004-chore-curated-public-repo-plan.md
```

Why it matters: this is what `resume-builder` already does under
`schema: plan/v1`. `d63e585` created both files in one commit — the predecessor
born `superseded`, having never been `approved`, and the successor born `draft`.
Both details set the rule: the flip is timed at the successor's commit, not its
approval, and a plan may reach `superseded` from `draft`. The spec legalizes
observed practice rather than inventing a shape.

### S3: `implementing` refuses re-entry on a terminal plan

A resumed or misrouted session points `implementing` at a plan that is already
finished or replaced.

```
$ implementing docs/plans/2026-07-25-003-chore-public-history-purge-plan.md
refused: plan status is `superseded`; the successor is
docs/plans/2026-07-25-004-chore-curated-public-repo-plan.md
```

`status: done` produces a detectable error naming `completed_by:`;
`status: superseded` produces a refusal naming `superseded_by:`. Neither
degrades to executing the plan again.

### S4: an out-of-enum value is caught before it is committed

A plan author or agent writes a value the schema does not define.

```bash
$ python3 skills/planning/scripts/validate-plan-frontmatter.py \
    docs/plans/2026-07-27-001-feat-example-plan.md
FAIL docs/plans/2026-07-27-001-feat-example-plan.md
  status: 'in-progress' is not one of draft|approved|done|superseded
```

Why it matters: `execution: ops` and `status: superseded` reached tracked plans in
`resume-builder` with nothing objecting. `status: done` would have joined them.

### S5: a reader with no session context reads the corpus

Someone opening `docs/plans/` sees which plans executed, which were replaced and
by what, and which are still open — from the frontmatter alone, without grepping
the retro corpus or reconstructing merges from `git log`.

## Scope

### In

- `schemas/plan-schema.md` — the enum, the two terminal-state evidence fields, the
  mutable-slot boundary, and inline rejection records for the two deleted values.
- `skills/retrospective/SKILL.md` — writes `done`.
- `skills/planning/SKILL.md` — writes `superseded`; runs the validator before
  claiming success.
- `skills/implementing/SKILL.md` — entry behavior on terminal states.
- `skills/planning/scripts/validate-plan-frontmatter.py` plus valid/invalid
  fixtures.
- `scripts/validate.sh` — a corpus check over `docs/plans/*.md`.
- `scripts/test-python-compatibility.sh:196` — registering the new committed
  Python artifact.

### Out

- **The post-approval body-amendment rule** (`planning` has no immutability rule
  outside Mutation-matrix rows) and **outward publication as a stateful
  ceremony**. These are the root cause of the `resume-builder` incident's in-place
  edits and are a separate, higher-severity `designing` cycle. This spec depends
  on them only through R5.
- **`execution: ops`** — `resume-builder` carries two instances against an enum of
  `code | non-code`. Whether `ops` is a third mode or a misuse of `non-code` is
  not decided here; the validator will flag it, and that is the intended result.
  Register a ROADMAP row.
- **`review-envelope/v1` validation** — stays on the existing ROADMAP row.
- **`shipping`'s stale pre-review commit message** — unrelated causally; ROADMAP row.
- **Backfilling terminal states onto existing plans** — see R8.

## Assumptions and Preconditions

All commands were run in `/Users/teslamint/workspace/compound-loop` at `4cb3fdb`
unless the row names another repository.

| Claim | Command | Observed at | Observed result | Evidence source |
|---|---|---|---|---|
| As *plan status* values, `in-progress`, `done`, and `abandoned` occur nowhere but the enum line | `grep -rn "status: in-progress\|status: done\|status: abandoned" --include="*.md" .` | `2026-07-26T15:17:48Z` | 1 hit, and it is `skills/release-loop/references/progress-schema.md:10`'s `phase_status:` — a different field | Working tree at `4cb3fdb` |
| `status: superseded` with `superseded_by:` is in live use under `schema: plan/v1` | `grep -h "^status: superseded" ~/workspace/resume/docs/plans/*.md \| wc -l` | `2026-07-26T15:17:48Z` | 1 (`2026-07-25-003-chore-public-history-purge-plan.md`, set at `d63e585`) | `teslamint/resume-builder` working tree |
| `planning` ships no validator while `compound` gates on one | `rg -c "validate" skills/planning/SKILL.md` | `2026-07-26T15:17:48Z` | `0`; `skills/compound/SKILL.md:48` requires exit 0 before claiming success | Working tree at `4cb3fdb` |
| A plan does not index its own merge commit | `git log --oneline -- docs/plans/2026-07-23-001-feat-evidence-tier-vocabulary-plan.md` | `2026-07-26T15:17:48Z` | 3 commits, all draft/review/approve; merge `33e8bc6` absent | Working tree at `4cb3fdb` |
| Completion is already recorded, but only retro→plan | `ls docs/plans/*.md \| wc -l`; `ls docs/retros/*.md \| wc -l`; `grep -l 'docs/plans/' docs/retros/*.md \| wc -l` | `2026-07-26T15:17:48Z` | 14 plans, 14 retros, 12 retros referencing a plan path | Working tree at `4cb3fdb` |
| Every existing plan already carries every required key | loop asserting `schema title type status date execution` present in each `docs/plans/*.md` | `2026-07-26T15:17:48Z` | 0 files missing any key (14/14 complete) | Working tree at `4cb3fdb` |
| `scripts/validate.sh` is green at HEAD and is a usable invariance guard | `bash scripts/validate.sh` | `2026-07-26T15:17:48Z` | `ALL CHECKS PASSED`, exit 0 | Working tree at `4cb3fdb` |
| `scripts/test-signal-drift.sh` Case D is already red and its fixture is off by 17 lines | `grep -n "Documentation complete" skills/retrospective/SKILL.md`; `sed -n '77p' skills/retrospective/SKILL.md` | `2026-07-26T15:17:48Z` | Target string is on line 94; line 77 is blank; Case D asserts line 77 | Working tree at `4cb3fdb`; ROADMAP carry-forward row (P2) |
| A new committed Python artifact must be registered in the compat manifest | `grep -rn "compound-frontmatter-validator" scripts/` | `2026-07-26T15:17:48Z` | Registered at `scripts/test-python-compatibility.sh:196` as `committed\|label\|path` | Working tree at `4cb3fdb` |

## Architecture

### State machine

```
draft ──┬──► approved ──┬──► done         (executed; terminal)
        │               └──► superseded   (replaced; terminal)
        └──────────────────► superseded   (replaced before approval)
```

Terminal states have no outgoing transitions. `draft → superseded` is valid and
observed: a plan can be replaced before anyone approves it, and deleting it would
lose the reasoning the successor was chosen over. `draft → done` is invalid — a
plan that never passed the USER gate cannot have been executed.

### Writers

| Value | Writer | When | Evidence written in the same commit |
|---|---|---|---|
| `draft` | `planning` | plan first committed | unchanged |
| `approved` | `planning` | after the USER gate | unchanged |
| `done` | `retrospective` | retro doc commit, after merge | `completed_by:` |
| `superseded` | `planning` | successor plan is committed, at any status | `superseded_by:` |

`retrospective` owns `done` rather than `shipping` because `shipping` exits at the
merge itself: flipping before merge writes a value that is not yet true, and
flipping after merge puts a commit on the base branch outside the PR.
`retrospective` runs after merge (`skills/retrospective/SKILL.md:12`), has an AUTO
gate (`:14`), and already commits a document the flip can ride.

A retro covering more than one plan flips **every** plan it covers, each with its
own `completed_by:` naming the merge that landed that plan's work (resolved at
the approval gate, 2026-07-27). A retro with no plan writes no flip — the skill's
existing no-plan branch (`:34`) already covers it.

### Mutable-slot boundary

A plan's **body** is immutable after the approved commit. The `status` field and
its terminal-state evidence field are the plan's only mutable slots. This
boundary is stated in the schema so the separate post-approval-amendment cycle
inherits it rather than contradicting it (R5).

## Frontmatter Contract

**R1 — Enum.** `status: draft | approved | done | superseded`.

**R2 — `done` requires `completed_by`.** `status: done` without a non-empty
`completed_by:` is invalid. `completed_by:` holds the merge commit that landed the
plan's work. A bare `done` flag is a restatement of what the retro corpus already
records; the pointer is the content that justifies the value, so the redundant
form is invalid by construction rather than by convention.

**R3 — `superseded` requires `superseded_by`.** `status: superseded` without a
`superseded_by:` naming an existing path is invalid. Direction is
predecessor→successor only; the successor grows no backlink. The predecessor need
not have been `approved` — see the state machine.

**R4 — Deleted values carry inline rejection records.** The schema records why
each removed value was removed, in the style
`docs/plans/2026-07-22-001-feat-final-action-session-resilience-plan.md:32` used
for `final_action`'s rejected `superseded`:

- `in-progress` — live execution state belongs to commits and the progress ledger
  (`schemas/plan-schema.md:3`). A committed second copy is a dual source of truth,
  and a session that dies mid-execution latches it permanently.
- `abandoned` — no instance was ever observed. The shape the need actually took is
  `superseded`, which carries a successor pointer that `abandoned` has no slot for.

**R5 — Mutable-slot boundary is stated in the schema.** The body is immutable
after approval; `status` and its evidence field are the exception. Without this,
the pending post-approval-amendment cycle would make R2 and R3 illegal.

**R6 — Unknown fields stay valid.** The validator rejects unknown `schema:`
versions, never unknown fields, matching
`skills/release-loop/references/progress-schema.md:62`. `origin:` and `deepened:`
keep working, and additive fields need no version bump.

## Validator

**R7 — `skills/planning/scripts/validate-plan-frontmatter.py`.** Checks: the
required key set (`schema`, `title`, `type`, `status`, `date`, `execution`); each
closed enum (`type`, `status`, `execution`); R2's and R3's conditional
requirements; that `superseded_by:` resolves to an existing file; and that
`origin:`, when present, resolves to an existing file. Exit 0 is
required before `planning` claims success, using `skills/compound/SKILL.md:48`'s
wording so the two skills read the same way.

This closes the ROADMAP future-candidate row *"Schema validators + fixtures"*,
whose registered trigger is **"First malformed plan or envelope produced in real
use."** That trigger fired: `status: superseded` and `execution: ops` are tracked
in `resume-builder` plans today. Scope here is `plan/v1` only —
`review-envelope/v1` stays on the row.

**R8 — Corpus check and grandfathering.** `scripts/validate.sh` gains a check
running the validator over `docs/plans/*.md`. All 14 existing plans in **this**
repository already carry every required key and a legal `status`, so this
corpus is green without edits.

Conformance is asserted for this checkout only, not for `plan/v1` as a published
contract. `resume-builder` is a live `plan/v1` consumer with two known violations
(`execution: ops`, twice), and this spec neither fixes nor grandfathers them —
adopting the validator there is that repository's decision. Read R8 as a property
of `docs/plans/` here, never as a claim that every `plan/v1` corpus passes. No
terminal state is backfilled: reconstructing a merge commit for each historical
plan would make `completed_by:` archaeology rather than a record, and writing it
would edit approved plans for no reader's benefit. The new rules apply to plans
first committed after this spec merges — keyed on the plan's own creation, not on
its approval, since `superseded` can reach a plan that is never approved.

## Testing

- Validator fixtures: valid (`draft`, `approved`, `done` + `completed_by`,
  `superseded` + `superseded_by`); invalid (each deleted value; `done` without
  `completed_by`; `superseded` without `superseded_by`; `superseded_by` pointing
  at a missing path; `origin` pointing at a missing path; unknown `schema:`
  version); legacy (a plan carrying only the pre-change key set, which must
  pass).
- Register the validator in `scripts/test-python-compatibility.sh:196` so it is
  compiled against both boundary interpreters (3.9 and 3.14).
- `implementing` entry behavior: one case per terminal state asserting the refusal
  or error names the corresponding evidence field.

## Risks

- **`scripts/test-signal-drift.sh` Case D is already red and this spec edits its
  target file.** Case D asserts `Documentation complete — <path>` on
  `skills/retrospective/SKILL.md:77`; the string is on line 94 and line 77 is
  blank, so the fixture errors before it tests anything. It reproduces at
  `4cb3fdb`, before this work. Adding lines to that file above line 94 shifts the
  target further. Mitigation: record the pre-existing failure in the plan, do not
  cite this harness in any Success Criterion, and state the post-change line
  number of the target string so the P2 carry-forward row can be repaired with a
  known value.
- **Cross-repo blast radius.** `plan/v1` is consumed by at least one other
  repository, which has already invented two out-of-enum values. Adding the
  validator will flag `execution: ops` there. That is the intended behavior, but
  it lands as a new failure in a repository this cycle does not own.
- **Cross-cycle contradiction.** If the post-approval-amendment cycle writes a
  blanket immutability rule, R2 and R3 become illegal. R5 exists to prevent this
  and must survive review of *that* spec, not only this one.
- **A reverted merge leaves `completed_by:` stale.** Less likely than
  `in-progress`'s stale latch but the same class of failure. Accepted: the field
  names a commit that a reader can verify, so the staleness is detectable rather
  than silent.

## Success Criteria

1. The `status` enum in `schemas/plan-schema.md` is exactly
   `draft | approved | done | superseded`, and `in-progress` and `abandoned` each
   appear in the schema only inside a rejection record.
   - **Measured by**: `grep -c 'status: draft | approved | done | superseded' schemas/plan-schema.md` returns `1`; `grep -c 'in-progress' schemas/plan-schema.md` returns `1`; `grep -c 'abandoned' schemas/plan-schema.md` returns `1`. The single remaining occurrence of each deleted value is its R4 rejection record.
2. The validator rejects every invalid fixture and accepts every valid one.
   - **Measured by**: the fixture suite run directly — every invalid fixture exits
     nonzero with the offending field named in the output, and every valid and
     legacy fixture exits 0.
3. The full existing plan corpus passes unmodified.
   - **Measured by**: `for f in docs/plans/*.md; do python3 skills/planning/scripts/validate-plan-frontmatter.py "$f" || exit 1; done` exits 0 with zero plan files changed in the diff.
4. The validator is compiled against both boundary interpreters.
   - **Measured by**: `bash scripts/validate.sh` output contains
     `label=plan-frontmatter-validator` with `status=pass` for `role=oldest` and
     `role=newest`.
5. `implementing` refuses a terminal plan and names the evidence field.
   - **Judgment rubric**: a reviewer reads `skills/implementing/SKILL.md`'s entry
     section and confirms it prescribes a detectable error for `done` naming
     `completed_by:` and a refusal for `superseded` naming `superseded_by:`.
     Pass requires both states handled and neither degrading to execution.
6. `retrospective` writes the flip atomically with its own commit, conditional on
   a plan existing.
   - **Judgment rubric**: a reviewer confirms the skill prescribes writing
     `status: done` and `completed_by:` in the same commit as the retro doc,
     states what happens when no plan exists, and states what happens when the
     retro spans more than one plan. Pass requires all three.
7. Nothing that passed before this change fails after it.
   - **Measured by**: `bash scripts/validate.sh` exits 0, as it does at `4cb3fdb`.

## Open Decisions

1. **Whether `superseded_by` may name a spec or a deviation addendum rather than a
   plan.** `resume-builder`'s single instance names a plan. Restricting to plans
   is the conservative reading and is what R3 assumes. **Owner: `planning`**, if a
   non-plan successor ever appears.
2. **Whether `execution: ops` is a third execution mode.** Deliberately out of
   scope; the validator will flag the existing instances. **Owner: a future
   `designing` cycle**, triggered by the ROADMAP row this spec registers.

The multi-plan retro question originally listed here was resolved at the approval
gate (flip all; see Architecture → Writers).
