---
title: Final-Action Session Resilience
status: draft
date: 2026-07-22
schema: spec/v1
---

# Final-Action Session Resilience Design

_Created 2026-07-22._

## Overview

A session limit must never strand a release at its finish line. This design
makes the loop's single irreversible/final action — the merge into the base
branch — survivable: identified at loop start, refined into an exact command
packet as it becomes determined, and persisted durably **before** any USER
gate blocks. A successor (human or fresh session) can then complete the
release from the on-disk record plus first-hand consent, with nothing to
re-derive.

### Directive interpretation

The originating directive reads: *"Before we start, identify the single
irreversible/final action in this workflow and execute it first (or script it
standalone) so a session limit can't block it."* Its literal arm — execute the
irreversible action first — is rejected: it contradicts P7 (outward steps
belong to the human) and the entire gate ordering (a merge cannot precede
design, review, or approval). The parenthetical arm — make it standalone —
is adopted as the intent: the final action is *prepared* early and durably,
never *executed* early. This is the prepare-first interpretation, confirmed
by the user at design time.

## User Scenarios

### S1: Loop start declares the final action

An orchestrator starting `/release-loop <feature>` writes a `final_action`
record into `.release-loop/progress.md` at loop creation: kind
`merge-to-base`, status `predicted`, no command yet. Anyone reading the state
file from the first minute knows what the loop's terminal irreversible step
will be.

### S2: Determination refines the record

When `shipping` creates the PR, the exact merge command becomes knowable
(`gh pr merge <number> ...`). The record is updated to status `determined`
with the exact command at that moment — not batched to phase end.

### S3: Session dies at the merge gate

The ship USER gate is reached; the exact command packet is already persisted;
the session hits its limit before (or while) asking. The user opens
`progress.md`, finds the determined command plus the explicit
not-an-authorization marker, and runs the merge themselves. No context
reconstruction, no successor agent required.

### S4: Interactive release ceremony survives gate death

A user runs `/release` interactively. Before Phase 5 presents its gate, the
skill writes `.release/draft.md` (same content contract as the headless
path, including the single fenced exact-command program). If the session dies
at the gate, the complete packet is on disk instead of lost with the
conversation.

### S5: Successor session resumes without over-reading the record

A fresh session runs `/release-loop resume`, reads `final_action` with status
`determined`, and treats it as preparation evidence only: it re-obtains
first-hand consent before executing, because the record explicitly states it
is not approval. `ship_approved` remains the only approval evidence field.

### S6: Determined command is invalidated

After determination, new review commits land (or the PR is closed). The
refinement point that observes this flips the record back to `predicted` and
logs why in the same edit — a stale exact command is worse than none.

## Scope

### In

- `skills/release-loop/SKILL.md`: final-action declaration at loop start,
  refinement on state updates, prepare-before-gate rule in Gate handling.
- `skills/release-loop/references/progress-schema.md`: additive
  `final_action` field on `release-loop/v1` (no schema version bump).
- `skills/shipping/SKILL.md`: merge-gate step persists the exact merge
  command durably before the blocking question, in both orchestrated and
  standalone invocations.
- `skills/release/SKILL.md`: interactive path writes `.release/draft.md`
  before Phase 5 presents the gate (today only `mode:headless` writes it).

### Out

- Executing any irreversible action early or automatically — gate ordering,
  approval semantics, and P7 are unchanged.
- A separate executable script file (e.g. `final-action.sh`) — rejected at
  design time in favor of the existing single durable state file.
- Outward publication resumability in `release` — already shipped (v0.3.0,
  durable-prefix classification).
- Persisting non-final outward commands (feature-branch push, PR creation)
  — only the single final action gets this treatment.
- New `scripts/validate.sh` checks — trigger-based per ROADMAP convention
  (see Open Decisions).

## Assumptions and Preconditions

| Claim | Command | Observed at | Observed result | Evidence source |
|---|---|---|---|---|
| `release-loop/v1` progress schema has no final-action field | `grep -n "final" skills/release-loop/references/progress-schema.md` | 2026-07-22T08:27:26+0900 | no matches | working tree at `800c623` |
| `release` persists the exact-command packet to disk only on the headless path; the interactive path presents it in conversation at Phase 5 | `grep -n "draft.md" skills/release/SKILL.md` | 2026-07-22T08:26:41+0900 | `draft.md` writes appear only under `mode:headless` (line 44) and the "Headless boundary" section (line 343); Phase 5 (line 359) presents a review packet with no persistence step | working tree at `800c623` |
| `shipping`'s durable command handoff activates only when an outward capability is missing (preparation-only) or when running as a dispatched phase worker | `grep -n "preparation-only\|prepared" skills/shipping/SKILL.md` | 2026-07-22T08:26:41+0900 | preparation-only defined in Step 0 (capability-missing trigger); worker hand-up packet at line 115; no persistence on the normal interactive path before the merge gate | working tree at `800c623` |

## Architecture

One new concept, one invariant, no new tracked files.

**Final-action record** — a field in the loop's existing single state file
(`.release-loop/progress.md`, P8) naming the loop's single irreversible/final
action:

```yaml
final_action:
  kind: merge-to-base            # closed vocabulary; only value in this cycle
  status: predicted              # predicted | determined | executed
  command: null                  # exact command string once determined
  updated: <ISO-8601>
```

Status transitions: `predicted → determined` (exact command knowable),
`determined → predicted` (invalidation, S6, with the reason logged in the
same edit), `determined → executed` (post-execution, with an evidence Log
line, P3). Every transition writes a Log line at the moment it happens.

**Prepare-before-gate invariant** — before the merge gate resolves — whether
by blocking on a USER question or by evaluating `--auto` conditions — the
exact command packet must already be persisted durably: `progress.md` for
the loop, the skill-local handoff file for standalone `shipping`,
`.release/draft.md` for `release`. Gate order becomes: persist, then
resolve. On every re-presentation of a gate packet (e.g. after a revision
loop), the persisted copy is rewritten first so disk never trails the
conversation.

**Non-authorization marker** — every persisted command packet (the
`progress.md` record, the standalone `shipping` handoff file, and
`.release/draft.md`) states explicitly that it is preparation evidence,
never approval. Approval evidence lives only in the existing
`ship_approved` / first-hand gate fields.
This extends the pilot-proven "gate approval is not execution authorization"
rule to its file-shaped counterpart: possession of the command is not
permission to run it. `enforces: P7`

Commands must not embed secrets or tokens (ambient `gh` auth only), matching
the existing evidence-sanitization rule.

## Requirements

Grouped by owner. R-IDs are stable.

**release-loop**
- R1: Loop startup writes `final_action` (`kind: merge-to-base`,
  `status: predicted`) with a Log line.
- R2: State updates refine the record at each determination or invalidation
  point (PR created → `determined` + exact command; PR closed or new commits
  after determination → `predicted` with the reason logged), at the moment
  of the event.
- R3: Gate handling states the prepare-before-gate invariant: the orchestrator
  verifies the record is `determined` and persisted before the ship gate
  resolves (USER question or `--auto` condition evaluation).
- R4: After execution, the record flips to `executed` in the same edit as the
  evidence Log line.
- R8: Resume verifies a `determined` record against live state (PR open,
  head unchanged) before trusting it — alongside the existing artifact-pointer
  verification in the Resuming step; a failed check flips the record to
  `predicted` with the reason logged.

**progress-schema**
- R5: `final_action` documented as an additive `release-loop/v1` field with
  the closed status vocabulary, the non-authorization rule, and the
  no-secrets rule. Consumers reject unknown `schema:` versions, not unknown
  fields; absence of the field (older files) stays valid. Consistency rule:
  the `executed` transition and `merged: true` happen in the same edit —
  the two fields never disagree across a write.

**shipping**
- R6: The merge-gate step persists the exact merge command (with the
  non-authorization marker) to its durable record before the gate resolves,
  on the normal interactive path — not only in preparation-only or worker
  modes. Orchestrated: the worker's hand-up packet is the same content the
  orchestrator writes to `progress.md`. Standalone: a handoff file in an
  inherently untracked location (e.g. inside the git dir) — never a
  gitignore assumption, since host repos don't know the path; exact path
  chosen by `planning`.

**release**
- R7: The interactive path writes `.release/draft.md` (identical content
  contract to the headless path, including the single fenced exact-command
  program, plus the non-authorization marker) before Phase 5 presents the
  gate packet — and rewrites it before every re-presentation after a
  revision loop or a Phase 6 newly-derived packet, so the persisted copy
  always matches the packet being shown.

## Testing

No new automated harness this cycle. Verification is grep checks or judgment
rubrics per success criterion, plus one drill:

- Grep checks and rubrics (below) prove each skill document contains the
  required ordering and vocabulary.
- **Gate-death drill**: construct a `progress.md` with a `determined`
  `final_action`, hand it to a reader with zero conversation context, and
  have them state (dry-run, not execute) the exact command and the consent
  they still need. Pass: command matches the record byte-for-byte and the
  reader names first-hand consent as missing.
- `scripts/validate.sh` passes unchanged (no structural regressions).

## Risks

- **Stale determined command** (S6): mitigated by R2 invalidation transitions,
  the `updated` timestamp, and R8's resume-time live-state check.
- **Record misread as authorization**: mitigated by R5's non-authorization
  rule in the schema, the marker in the record's documentation, and S5's
  resume behavior.
- **Drift between shipping's packet and the loop record**: single-sink rule
  in R6 — the worker packet *is* the content written to `progress.md`; no
  second wording.
- **Secrets in persisted commands**: prohibited by the no-secrets rule (R5);
  `gh` relies on ambient auth, so compliant commands need no tokens.

## Success Criteria

1. The progress schema documents `final_action` with all three status values
   and the non-authorization rule.
   - **Measured by**: `grep -n "final_action" skills/release-loop/references/progress-schema.md` shows the field; `grep -oE "predicted|determined|executed" skills/release-loop/references/progress-schema.md | sort -u | wc -l` = 3; `grep -in "not.*authorization\|never.*approval" skills/release-loop/references/progress-schema.md` non-empty.
2. release-loop declares the final action at startup and enforces
   prepare-before-gate in Gate handling.
   - **Measured by**: `grep -n "final_action" skills/release-loop/SKILL.md` matches in both the "Starting a new loop" and "Gate handling" sections (reviewer confirms section placement).
3. shipping persists the exact merge command before the merge-gate question
   on the normal interactive path.
   - **Measured by**: judgment rubric — a reviewer reads the merge-gate step and confirms the persistence instruction precedes the blocking question and applies without a capability-missing or worker-mode trigger.
4. release's interactive path persists `.release/draft.md` before the Phase 5
   gate.
   - **Measured by**: judgment rubric — a reviewer reads Phase 4/5 and confirms draft persistence is unconditional (not gated on `mode:headless`) and ordered before gate presentation.
5. The gate-death drill passes.
   - **Measured by**: drill transcript recorded in the retro — reader with only the state file reproduces the exact command and names first-hand consent as the missing ingredient.
6. Structural validation still passes.
   - **Measured by**: `scripts/validate.sh` → `ALL CHECKS PASSED`.

## Open Decisions

- Standalone-`shipping` handoff file path/name for the persisted merge
  command — owner: `planning`.
- Whether a future `scripts/validate.sh` check should mechanically enforce
  `final_action` shape — owner: `retrospective` (register as carry-forward on
  first observed drift, per ROADMAP trigger convention).
- Whether `release-loop` should surface the final-action record in its resume
  report output — owner: `planning` (default: yes, one line).
