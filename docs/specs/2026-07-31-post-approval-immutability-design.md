---
title: Post-Approval Immutability and Outward-Publication Ceremony
status: draft
date: 2026-07-31
schema: spec/v1
---

# Post-Approval Immutability and Outward-Publication Ceremony Design

_Created 2026-07-31._

## Overview

Enforce the existing plan-body immutability rule (plan-schema.md "Mutable slots") with a cross-cutting skill-level check and a mechanical body-seal validation, and expand the planning skill's stateful-ceremony definition to name outward-publication boundaries as a concrete trigger for the mutation/failure-state matrix.

## User Scenarios

### S1: Implementing preflight detects prior-session plan-body damage

An agent resumes an implementing session. The plan's body was modified in a prior session (e.g. a dead worker edited the plan before dying). Implementing's preflight computes the body hash, compares it to `body_seal`, finds a mismatch, and stops with a named violation directing to deviation addendum or byte-exact revert.

### S2: validate.sh catches a committed unsealed plan-body mutation

An agent edits an approved plan's body and commits the change without updating `body_seal`. `validate.sh` check 14 recomputes the body SHA-256, finds it does not match `body_seal`, and reports FAIL with the plan path and expected vs actual hash. The seal proves body-matches-last-seal, not unchanged-since-approval — an agent that re-seals after editing defeats check 14. The cross-cutting skill rules (R1) are the defense against unauthorized re-sealing; the mechanical check catches accidental or unaware body edits.

### S3: Planning seals the body at approval

The user approves a plan. Planning computes the SHA-256 of the markdown body (everything after the closing frontmatter `---`), writes `body_seal: <hash>` into the frontmatter, and commits both the `status: approved` flip and the seal in the same commit.

### S4: Interactive deepening re-seals after controlled modification

The user explicitly asks to deepen an already-approved plan. The deepening pass modifies the body under its own controlled protocol. After the deepening changes land, planning recomputes the body hash and writes a new `body_seal` in the same commit as the body changes. A log note in the plan's git history records the re-seal event. No other editing path may re-seal.

### S5: Outward-publication deliverable triggers matrix requirement

A planning cycle produces a deliverable that will push commits to a remote, create a GitHub release, or change repository visibility. Planning step 10 recognizes these as outward-publication boundaries — a named category of stateful ceremony — and requires a mutation/failure-state matrix covering those transitions.

### S6: Outward publication without matrix is caught by review

A plan carries the stateless fallback ("No stateful ceremony") but its units include `git push`, `gh release create`, or `gh repo edit --visibility`. Reviewing identifies the mismatch: outward-publication transitions exist without a matrix. The finding blocks `clean`.

### S7: Existing plan corpus passes validation

15 existing plans in `docs/plans/` have no `body_seal` field. validate.sh check 14 skips seal verification when the field is absent. All existing plans continue to pass.

### S8: Terminal-state flip does not trigger seal mismatch

Retrospective writes `status: done` and `completed_by: <commit>` to a plan's frontmatter. These are mutable slots in the frontmatter, not in the body. The body remains unchanged, so the seal still matches.

## Scope

### In

- R1: Cross-cutting immutability check in implementing preflight and reviewing scope — each independently verifies the plan body is unchanged from its sealed state.
- R2: `body_seal` frontmatter field in plan-schema.md — SHA-256 of the markdown body, set at approval, used by validate.sh.
- R3: validate.sh check 14 — mechanical seal verification for plans with `body_seal` present. Catches every unsealed body mutation regardless of which skill or session produced it. Does not catch a mutator that re-seals — that path is defended by R1's skill-level rules.
- R4: Planning step 10 expansion — outward-publication boundary named as a concrete stateful-ceremony category with examples (push to remote, create remote repository, publish to registry, create GitHub/platform release, change repository visibility).
- R5: CONCEPTS.md entries for "body seal" and "outward-publication boundary".
- R6: Interactive-deepening carve-out — the only post-approval body modification path, with re-seal in the same commit as the body changes.

### Out

- Backfilling `body_seal` onto existing 15 plans — they predate this contract (per plan-schema.md Applicability rule).
- Git-hook enforcement — validate.sh is the mechanical check; hooks are a separate concern.
- Automated body-seal repair tooling — a mismatched seal is a failure, not an auto-fix target.
- Extending immutability to spec documents — specs already have the deviation-addendum pattern; mechanical sealing is a separate future decision.
- Frontmatter immutability enforcement — non-mutable frontmatter fields (`title`, `type`, `date`, `execution`, `origin`) remain procedurally protected by the existing Mutable-slots rule. The seal covers the body only; extending it to frontmatter fields is a separate decision.
- Shipping-specific immutability check — shipping's verification gate (Step 1) runs the project's test suite, not `validate.sh`. Adding validate.sh to shipping's verification is a separate scope decision. For this cycle, the mechanical defense is validate.sh run independently (CI, manual, pre-merge convention), and the primary procedural defense is reviewing's Requirements Completeness rule. Shipping inherits protection from these two layers without its own dedicated check.

### Carve-out: interactive deepening (R6 justification)

The plan-schema.md immutability rule says the body is immutable after the approved commit. Interactive deepening (`skills/planning/references/deepening.md` section 5, interactive mode) modifies the body of an already-approved plan under user control. This is a controlled re-entry, not an immutability violation, because:
- It runs only on explicit user request ("deepen this plan").
- The user gates each change individually (section 5, interactive mode protocol).
- The body hash is recomputed and re-sealed in the same commit as the body changes.
- Auto-mode deepening runs before approval (planning step 15, before the human gate) and is not affected.

## Assumptions and Preconditions

| Claim | Command | Observed at | Observed result | Evidence source |
|---|---|---|---|---|
| plan-schema.md already declares body immutability via "Mutable slots" | `grep -c "Mutable slots" schemas/plan-schema.md` | 2026-07-31T05:36:30Z | 1 | Working tree |
| validate.sh check 10 already validates plan frontmatter | `grep -c "Plan corpus" scripts/validate.sh` | 2026-07-31T05:36:31Z | 1 | Working tree |
| 15 existing plans, none have body_seal | `ls docs/plans/*.md \| wc -l` and `grep -rl body_seal docs/plans/*.md \| wc -l` | 2026-07-31T05:36:37Z | 15 plans, 0 with body_seal | Working tree |
| validate.sh currently has 13 checks | `grep -c "^# [0-9]" scripts/validate.sh` | 2026-07-31T05:36:37Z | 13 | Working tree |
| Auto-mode deepening runs before approval (planning step 15, before step 17 commit) | `grep -n "^## 15\|^## 16\|^## 17" skills/planning/SKILL.md` | 2026-07-31T05:42:00Z | Step 15: Deepening pass (line 157). Step 16: Outstanding-question triage (line 161). Step 17: Commit the plan as draft, then approved after user confirms (line 165). Auto deepening synthesizes inline at step 15; approval commit at step 17. | `skills/planning/SKILL.md:157-167`, `skills/planning/references/deepening.md:52-56` |
| Reviewing has Requirements Completeness rule at line 86 and Stateful ceremony evidence gate at line 88 | `grep -n "Requirements Completeness\|Stateful ceremony evidence" skills/reviewing/SKILL.md` | 2026-07-31T05:36:37Z | Line 86: Requirements Completeness rule; Line 88: Stateful ceremony evidence gate | Working tree |
| Implementing preflight has 5 items, item 1 = read plan, item 2 = status check | `grep -n "^[0-9]\." skills/implementing/SKILL.md \| head -8` | 2026-07-31T05:36:37Z | 1. Read the plan, 2. Status check, 3. Contradiction scan, 4. Ledger resume, 5. Worktree setup | Working tree, `skills/implementing/SKILL.md:16-21` |

## Architecture

### Body-seal data flow

```
Planning (approval commit)
  → extract body text (after second `---` line)
  → compute SHA-256 (lowercase hex)
  → write body_seal: <hex> to frontmatter
  → commit status: approved + body_seal in one commit

validate.sh check 14 (primary mechanical defense)
  → for each docs/plans/*.md with body_seal in frontmatter:
    → extract body (after second `---` line)
    → compute SHA-256
    → compare with body_seal value
    → mismatch → FAIL

Interactive deepening (carve-out)
  → user requests deepening of approved plan
  → deepening modifies body under interactive protocol
  → recompute SHA-256 of modified body
  → write new body_seal in same commit as body changes
```

### Cross-cutting immutability check

Each consuming skill adds one check:

- **implementing** preflight item 2.5 (between status check and contradiction scan): if the plan has `body_seal`, verify the current body matches it. Delegate to `bash scripts/validate.sh` (which includes check 14) or compute inline with the same extraction rule (Python `hashlib.sha256` on body text after second `---`). Mismatch → stop, report the violation, direct to deviation addendum or byte-exact revert.
- **reviewing** Requirements Completeness rule extension: a plan whose body has been modified post-approval (seal mismatch or detectable body diff) is a finding that blocks `clean`. Only interactive deepening (R6) is an authorized re-seal.

### Detection layers and their roles

| Layer | When it runs | What it catches | Primary for |
|---|---|---|---|
| validate.sh check 14 | Any validation run (CI, pre-merge, manual) | Any committed unsealed body mutation | Mechanical defense — catches accidental/unaware edits regardless of which skill or session produced them |
| Reviewing Requirements Completeness rule | During review, after implementation | Plan-body diff vs approved state, including unauthorized re-seals | Procedural defense — catches within-cycle violations; the only layer that can distinguish authorized (deepening) from unauthorized re-seals |
| Implementing preflight | Before unit 1 | Pre-existing body damage from a prior session | Cross-session defense — catches damage from dead or misbehaving prior workers |

### Outward-publication recognition

Planning step 10 adds a concrete recognition clause after the existing stateful-ceremony definition: any deliverable that creates, modifies, or exposes artifacts outside the local repository's default branch is an outward-publication boundary and constitutes a stateful ceremony. Concrete examples: pushing commits to a remote, creating a remote repository, publishing to a package registry, creating a GitHub/platform release, changing repository visibility. A plan carrying the stateless fallback whose units include any of these transitions has a recognition error — reviewing catches this as a matrix-requirement gap.

## Data Model

### `body_seal` field (plan-schema.md)

```yaml
body_seal: <64-char lowercase hex SHA-256>  # optional; set at approval
```

- **Computation input**: everything after the line matching the second `---` in the file, through end of file, including any trailing newline. The second `---` line itself is excluded.
- **Hash algorithm**: SHA-256, lowercase hex digest.
- **Set at**: approval commit (planning), or re-seal commit (interactive deepening only).
- **Absence**: valid. Plans without `body_seal` are not sealed; validate.sh skips them.
- **body_seal is itself a mutable slot**: it is written at approval and may be updated only by the interactive-deepening carve-out. It is NOT part of the sealed content (it lives in frontmatter).

## Integration

- Existing deviation-addendum flow unchanged — the immutability check adds a pre-check that fires before implementation or during review, not a replacement for the existing observable-deviation gate (implementing item 8).
- The body_seal check is additive to validate.sh check 10 (plan corpus). Check 10 validates frontmatter structure; check 14 validates body integrity. They are independent.
- `body_seal` is an unknown field to existing consumers — plan-schema.md's "Unknown fields" rule (spec R6) says consumers reject unknown schema versions, never unknown fields. So `body_seal` is safe to add.
- Shipping's verification gate (Step 1) runs the project's test suite, not validate.sh. The mechanical defense runs independently of shipping (CI, manual validation, pre-merge convention). Shipping inherits protection from reviewing (procedural) and validate.sh (mechanical) without its own dedicated check.

## Testing

- validate.sh check 14 fixture: plan with correct `body_seal` → PASS.
- validate.sh check 14 fixture: plan with incorrect `body_seal` (body modified after seal) → FAIL with plan path and mismatch detail.
- validate.sh check 14 fixture: plan without `body_seal` → PASS (skip message).
- Existing plan corpus (15 plans): all pass check 14 (no body_seal = skip).
- Boundary interpreter compilation: the Python heredoc in check 14 compiles on both 3.9 and 3.14.
- Body extraction determinism: the same plan file produces the same hash on repeated runs.
- Round-trip fixture: planning-side seal computation and validate.sh-side verification produce the same hash for the same body content.

## Risks

| Risk | Mitigation |
|---|---|
| Body extraction logic differs between planning (seal writer) and validate.sh (seal checker) | Define one canonical extraction rule (after second `---` line, through EOF). Both sides implement the same rule. Test with a round-trip fixture. |
| Frontmatter reordering by a YAML formatter changes body position | Body is defined positionally (after second `---`), not by YAML semantics. Formatters that touch only frontmatter do not affect body content. |
| An agent re-seals after editing, defeating check 14 | The seal catches accidental/unaware body edits (the common failure mode — the ROADMAP incident's three in-place edits were not re-sealed). Unauthorized re-sealing is a skill-rule violation caught by R1's cross-cutting checks: implementing preflight and reviewing both verify immutability independently of the seal. The only authorized re-seal path is interactive deepening (R6), which requires explicit user request. |
| Interactive deepening re-seal weakens immutability tracking | The carve-out is narrow: only deepening, only on explicit user request, user gates each change. The cross-cutting skill rules name deepening as the sole authorized re-seal path; any other re-seal is a violation. |

## Success Criteria

1. The seal-verification check detects a modified plan body (seal mismatch) and exits nonzero.
   - **Measured by**: fixture plan with wrong body_seal → `FAIL` in output, exit 1.
2. The seal-verification check passes a plan with correct body_seal.
   - **Measured by**: fixture plan with correct body_seal → `ok:` in output, exit 0.
3. The seal-verification check skips plans without body_seal.
   - **Measured by**: fixture plan without body_seal field → `ok:` skip message, exit 0.
4. Existing plan corpus (15 plans) passes structural validation after this change.
   - **Measured by**: `bash scripts/validate.sh` → ALL CHECKS PASSED.
5. Planning step 10 recognizes outward-publication boundaries as stateful ceremonies: a reviewer handed a plan carrying the stateless fallback ("No stateful ceremony") whose units include `git push` identifies it as a matrix-requirement gap.
   - **Measured by**: judgment rubric — input: a plan with the stateless fallback + a unit containing `git push`; pass: the reviewer cites the outward-publication clause and files a matrix-requirement finding; fail: the reviewer accepts the stateless fallback.
6. Implementing preflight stops execution when it detects a plan whose body has been modified post-approval (seal mismatch), directing to deviation addendum or byte-exact revert.
   - **Measured by**: judgment rubric — a reviewer reads the preflight immutability check, confirms it names: (a) the seal computation delegated to `scripts/validate.sh` or an inline equivalent, (b) the stop condition (mismatch or absence-when-expected), and (c) the two remediation paths (deviation addendum or byte-exact revert).
7. Body-seal computation passes on both boundary interpreters.
   - **Measured by**: structural validation output shows seal-check pass lines for both 3.9 and 3.14.

## Open Decisions

1. **`body_seal` on specs**: this cycle seals plans only. Sealing specs is a natural extension but adds scope (designing SKILL.md, spec-template.md, a separate validate.sh check). **Owner**: future designing cycle, triggered by first post-approval spec body edit.
2. **Seal check in shipped validator**: this cycle implements the seal check in `scripts/validate.sh` (repo-local). The shipped validator (`skills/planning/scripts/validate-plan-frontmatter.py`) does not gain seal verification. Consuming repos that adopt plan/v1 get frontmatter validation but not body-seal enforcement. **Owner**: future cycle, triggered by first consuming-repo adoption of plan/v1 with body_seal fields.
