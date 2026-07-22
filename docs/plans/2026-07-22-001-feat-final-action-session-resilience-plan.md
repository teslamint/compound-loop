---
schema: plan/v1
title: Final-Action Session Resilience
type: feat
status: approved
date: 2026-07-22
execution: non-code
origin: docs/specs/2026-07-22-final-action-session-resilience-design.md
---

# Final-Action Session Resilience Plan

## Goal

Make the loop's single irreversible action (merge-to-base) survivable across
session death: declare it at loop start, refine it to an exact command at
determination points, and persist it durably before any gate resolves — in
`release-loop`, `shipping`, and `release`, with the field contract in the
progress schema.

## Architecture notes

- **Additive schema field, v1 unchanged.** `final_action` joins
  `release-loop/v1` frontmatter. Consumers reject unknown `schema:` versions,
  not unknown fields; files without the field stay valid. Rationale: a
  version bump would force every consumer to change for an optional record.
- **Closed status vocabulary** `predicted | determined | executed`.
  Transitions: `predicted → determined` (exact command knowable),
  `determined → predicted` (invalidation, reason logged in the same edit),
  `determined → executed` (same edit as the evidence Log line and
  `merged: true` — the two fields never disagree across a write).
  `superseded` was rejected at design review (no pointer slot in a
  single-record schema).
- **Prepare-before-gate invariant.** The exact command packet is persisted
  before the merge gate resolves — whether it blocks on a USER question or
  evaluates `--auto` conditions. On every re-presentation of a gate packet,
  the persisted copy is rewritten first: disk never trails the conversation.
- **Non-authorization marker on every packet.** Each persisted packet
  (progress.md record, shipping handoff file, `.release/draft.md`) states it
  is preparation evidence, never approval; approval evidence stays in
  `ship_approved` / first-hand gate records (P7). No secrets in commands —
  ambient `gh` auth only.
- **Single sink under orchestration.** The shipping worker's hand-up packet
  is byte-for-byte the content the orchestrator writes to `progress.md` — no
  second wording to drift.
- **Standalone shipping handoff location** (spec Open Decision, resolved
  here): `"$(git rev-parse --git-dir)/shipping-final-action.md"` — inside
  the git dir, inherently untracked in any host repo; a gitignore assumption
  is unavailable because host repos don't know the path. In a worktree this
  resolves under `.git/worktrees/<name>` and shares the worktree's lifetime —
  intended: the protection window is gate death before cleanup, and cleanup
  removing the record with the worktree is correct disposal.
- **Resume surfacing** (spec Open Decision, resolved here): the resume
  report includes one line stating the final-action record's status and, when
  `determined`, its command.
- **Known Pattern**: `docs/solutions/workflow-issues/structural-check-without-execution-evidence.md`
  — every acceptance check below is a command to execute or a rubric with a
  named reader, never an unexecuted claim.
- **Known Pattern**: `docs/solutions/workflow-issues/numbered-planning-step-reference-drift.md`
  — edits keep existing step/phase numbering in all three skill files
  untouched; new content lands inside existing sections, no renumbering.

## Assumption Recheck

Origin spec retains three live assumptions; all rerun fresh at
2026-07-22T08:41:31+0900 against the working tree at `5db77ad`:

| Approved claim | Fresh evidence | Outcome |
|---|---|---|
| `release-loop/v1` progress schema has no final-action field | `grep -n "final" skills/release-loop/references/progress-schema.md` → no matches (exit 1) | match |
| `release` persists the exact-command packet to disk only on the headless path | `grep -n "draft.md" skills/release/SKILL.md` → lines 44, 59, 103, 149, 302, 343 — all headless/recovery/retention contexts; Phase 5 has no persistence step | match |
| `shipping`'s durable command handoff activates only in preparation-only or worker modes | `grep -n "preparation-only\|prepared" skills/shipping/SKILL.md` → Step 0 (line 27) capability-missing trigger; line 115 worker hand-up; no interactive-path persistence | match |

## File structure

| File | Responsibility |
|---|---|
| `skills/release-loop/references/progress-schema.md` | field contract: shape, vocabulary, rules (U1) |
| `skills/release-loop/SKILL.md` | orchestrator behavior: declare, refine, gate-check, resume-verify (U2) |
| `skills/shipping/SKILL.md` | merge-gate persistence on all paths (U3) |
| `skills/release/SKILL.md` | interactive `.release/draft.md` persistence (U4) |

## Scenario coverage map

| S-ID | Unit chain | Observable verification |
|---|---|---|
| S1 loop start declares | U1 → U2 | `grep -n "final_action"` matches in release-loop SKILL "Starting a new loop"; a reader of a fresh progress.md names the terminal action |
| S2 determination refines | U1 → U2 → U3 | rubric: shipping's PR-creation/hand-up content equals the `determined` record the orchestrator writes; grep shows `determined` refinement in State updates |
| S3 session dies at merge gate | U2 → U3 | gate-death drill: reader with only the state file reproduces the exact command byte-for-byte and names first-hand consent as missing (transcript in retro) |
| S4 interactive release survives gate death | U4 | rubric: Phase 5 draft write is unconditional and precedes packet presentation; rewrite precedes every re-presentation |
| S5 successor doesn't over-read | U1 → U2 | rubric: Resuming step verifies live state and treats the record as preparation only; schema states the non-authorization rule (grep `not.*authorization\|never.*approval`) |
| S6 determined invalidated | U1 → U2 | grep: literal `determined → predicted` transition in progress-schema.md; rubric: release-loop SKILL "State updates" documents the invalidation flip back to `predicted` with a same-edit logged reason |

## Implementation Units

## U1: Progress-schema `final_action` field contract

Files:
  Create/Modify: skills/release-loop/references/progress-schema.md
Steps:
  1. Add a `final_action` block to the frontmatter example: `kind: merge-to-base` (closed vocabulary, sole value), `status: predicted` with comment `predicted | determined | executed`, `command: null` with comment "exact command string once determined; no secrets — ambient auth only", `updated: <ISO-8601>`.
  2. Add a Rules bullet: the field is additive and optional on `release-loop/v1` — absence stays valid; consumers reject unknown schema versions, never unknown fields.
  3. Add a Rules bullet naming the three transitions: `predicted → determined` when the exact command becomes knowable; `determined → predicted` on invalidation (PR closed, new commits on the branch) with the reason logged in the same edit; `determined → executed` in the same edit as the evidence Log line and `merged: true` — the two fields never disagree across a write.
  4. Add a Rules bullet: the record is preparation evidence, never approval — possession of the command is not authorization to run it; approval evidence lives only in `ship_approved` (P7). Include this non-authorization statement in the field's inline comment or rules so any reader of the file sees it.
  5. Self-review against spec sections Architecture and R5.
  6. Commit: "docs(schema): Add final_action record to release-loop progress schema"
Acceptance: `grep -n "final_action" skills/release-loop/references/progress-schema.md` non-empty; `grep -oE "predicted|determined|executed" skills/release-loop/references/progress-schema.md | sort -u | wc -l` = 3; `grep -in "not.*authorization\|never.*approval" skills/release-loop/references/progress-schema.md` non-empty; `bash scripts/validate.sh` → ALL CHECKS PASSED.

## U2: Release-loop declares, refines, gates, and resumes the record

Files:
  Create/Modify: skills/release-loop/SKILL.md
Steps:
  1. In "Starting a new loop" item 5 (initial state write), state that the initial `references/progress-schema.md`-conformant state includes `final_action` with `kind: merge-to-base`, `status: predicted`, and a Log line declaring it (Covers S1).
  2. In "State updates", add: the `final_action` record is refined at each determination or invalidation point — PR created → `determined` plus the exact merge command; PR closed or new commits after determination → back to `predicted` with the reason logged in the same edit (Covers S2, S6). Updates happen at the moment of the event, matching the section's existing at-the-moment rule.
  3. In "Gate handling", add the prepare-before-gate rule: before the Ship gate resolves — USER question or `--auto` condition evaluation — the orchestrator verifies the record is `determined` and persisted; a gate must not resolve while the packet exists only in conversation. After execution, flip to `executed` in the same edit as the evidence Log line. State that the record is preparation evidence, never approval (Covers S3).
  4. In "Resuming" item 2, extend artifact verification: a `determined` record is verified against live state (PR open, head unchanged) before being trusted; a failed check flips it to `predicted` with the reason logged. The resume report includes one line stating the record's status and, when `determined`, its command (Covers S5).
  5. Self-review against spec R1–R4, R8; confirm no existing numbered items were renumbered.
  6. Commit: "feat(release-loop): Declare and maintain the final-action record"
Acceptance: `grep -n "final_action" skills/release-loop/SKILL.md` matches in both "Starting a new loop" and "Gate handling" sections (reviewer confirms placement); reviewer confirms the Resuming text requires the resume report's one-line record status (plus command when `determined`); `bash scripts/validate.sh` → ALL CHECKS PASSED.

## U3: Shipping persists the merge command before the gate resolves

Files:
  Create/Modify: skills/shipping/SKILL.md
Steps:
  1. In "Step 7: Merge Gate", before the existing blocking-question instruction, add: persist the exact merge command (the `gh pr merge <number> --squash --delete-branch` line with literal values) plus a non-authorization marker ("preparation evidence — first-hand consent still required") to the durable record before the gate resolves, on every path that reaches Step 7 — interactive, `--auto`, and worker. Preparation-only terminates at Step 0 with its existing manual-command file handoff and never reaches this step. Re-persist whenever the command changes (e.g. merge strategy overridden by repo convention).
  2. In the same step, name the sinks: dispatched worker → the hand-up packet, whose content is byte-for-byte what the orchestrator writes to `.release-loop/progress.md`'s `final_action` record; standalone invocation → `"$(git rev-parse --git-dir)/shipping-final-action.md"`, inherently untracked in any host repo (never a gitignore assumption).
  3. Confirm the existing Step 7/Step 8 numbering and the "Who executes the merge" paragraph are untouched.
  4. Self-review against spec R6 and scenarios S2, S3.
  5. Commit: "feat(shipping): Persist the exact merge command before the merge gate resolves"
Acceptance: reviewer reads Step 7 and confirms the persistence instruction precedes the blocking question, applies without a capability-missing or worker-mode trigger, and names both sinks; `bash scripts/validate.sh` → ALL CHECKS PASSED.

## U4: Release persists the interactive draft before Phase 5 presents

Files:
  Create/Modify: skills/release/SKILL.md
Steps:
  1. In "Phase 5: Gate", before "Present one review packet before asking anything", add: write `.release/draft.md` (creating `.release/` on demand) with the identical content contract the Headless boundary defines — every Phase 3 draft component and a final `## Exact commands` section holding the single fenced `bash` program — plus a non-authorization marker; this now runs on the interactive path, not only `mode:headless`.
  2. In the same phase's revision text ("A revision returns to Draft or Version and presents a new complete packet"), add: the rewritten `.release/draft.md` precedes every re-presentation, so the persisted copy always matches the packet shown.
  3. In "Phase 6: Execute" item 1 (state changed → newly derived packet), add: persist the newly derived packet to `.release/draft.md` before presenting it.
  4. Confirm the Headless boundary section itself is unchanged (its stop-and-signal behavior is headless-only; only the draft-writing duty is now shared).
  5. Self-review against spec R7 and scenario S4.
  6. Commit: "feat(release): Persist the gate packet to .release/draft.md on the interactive path"
Acceptance: reviewer reads Phase 4–6 and confirms draft persistence is unconditional (not gated on `mode:headless`) and ordered before gate presentation and before every re-presentation; `bash scripts/validate.sh` → ALL CHECKS PASSED.

## Mutation/failure-state matrix

No stateful ceremony in the deliverable; no mutation/failure-state matrix required.

## Deferred to Follow-Up Work

- Mechanical `scripts/validate.sh` check for `final_action` shape — owner:
  `retrospective`, registered as carry-forward on first observed drift (spec
  Open Decisions; ROADMAP trigger convention).

## Open unknowns

**Planning-time**: none — both planning-owned spec Open Decisions (standalone
handoff path; resume report line) are resolved in Architecture notes.

**Implementation-time**: exact sentence placement and wording inside each
SKILL section, kept consistent with each file's voice and prose economy;
whether U3's marker phrasing reuses the schema's wording verbatim or adapts
to shipping's tone.
