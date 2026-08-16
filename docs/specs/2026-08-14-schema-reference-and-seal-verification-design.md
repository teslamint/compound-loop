---
schema: spec/v1
title: Make the planning schema portable and verify body_seal values
type: fix
status: approved
date: 2026-08-14
issue: 14
---

# Portable Planning Schema and Verifiable Body Seal Design

_Created 2026-08-14._

## Overview

Issue #14 reports that a standalone installation of the planning skill cannot resolve `schemas/plan-schema.md`, although the skill depends on that contract for naming, lifecycle, unit shape, coverage, and `body_seal` creation. The 0.10.0 full-plugin artifact contains the file only at repository/plugin root. An agent receiving `skills/planning/` alone therefore cannot read it.

The shipped planning validator also checks only that `body_seal` is 64 lowercase hexadecimal characters. Repository-local `scripts/validate.sh` check 14 recomputes the value, but standalone consumers do not run that repository check. A syntactically valid arbitrary digest therefore passes the shipped validator.

## User Scenarios

### S1: Standalone planning skill

An agent receives only `skills/planning/`. It can read the complete plan contract, create a draft plan, compute the canonical seal after approval, and validate the stored value without locating a plugin root.

### S2: Standalone consumer skill

An agent receives only implementing, release-loop, or retrospective. The skill contains the exact subset of plan rules required for its own decisions. Absence of the full planning schema does not block those defined operations.

### S3: Existing sealed plan migration

A consuming repository upgrades the planning skill and an existing non-canonical seal fails value verification. The operator can compare the plan against an explicit pre-upgrade baseline commit and follow a documented, reviewable migration procedure.

## Scope

### In

- Move the full plan schema SSOT into the planning skill.
- Inline only load-bearing plan rules in implementing, release-loop, and retrospective.
- Verify `body_seal` values in the shipped planning validator.
- Add a reliable seal-print command and creation/verification guide.
- Define an auditable migration process for seals that existed before a consuming repository adopted this release.
- Update direct non-historical path consumers of the moved schema.

### Out

- Fixing the pre-existing `execution: ops` test/schema disagreement.
- Changing the canonical extraction or adding delimiter/line-ending restrictions.
- Sweeping unrelated `references/` or `schemas/` citations.
- Backfilling seals into unsealed historical plans.
- Rewriting historical plans, retrospectives, or changelog entries that cite the old location as historical evidence.
- Cryptographically preventing a repository writer from recomputing a seal.

## Assumptions and Preconditions

_No live assumptions were retained for this spec. Repository or environment invariants: the full compound-loop checkout retains sibling skill directories under `skills/`; standalone installers may copy one skill directory without repository-root files; existing seal implementations read UTF-8 text with universal-newline translation._

## Verified Current State

- Full-plugin 0.10.0 contains `schemas/plan-schema.md` at plugin root.
- The canonical extraction is currently `text.split('---', 2)[2]`, UTF-8 encoded, SHA-256, lowercase hexadecimal.
- `skills/planning/scripts/validate-plan-frontmatter.py` checks seal format only in the pristine pre-change implementation.
- `scripts/validate.sh` check 14 independently recomputes the seal.
- Planning needs the full schema. Three other skills use subsets:
  - implementing: plan eligibility/status and body-seal preflight.
  - release-loop: minimum eligibility for `--skip-plan`.
  - retrospective: `origin`, applicability, and `done/completed_by` transition.
- `scripts/test-plan-frontmatter.sh` case 20 already fails on the pristine validator because `ops` was added to `EXECUTIONS` without updating the test. This is not caused by issue #14.

## Architecture

`skills/planning/schemas/plan-schema.md` becomes the single source of truth. Planning-local documents resolve `schemas/plan-schema.md` from the planning skill root. External consumer skills no longer need the full schema for decisions they execute; they inline a constrained subset. In a full checkout they may additionally point readers to the sibling planning schema, but that optional pointer is not load-bearing.

The planning validator owns one seal-computation function. Normal validation and `--print-seal` both call it. Repository check 14 retains the same algorithm and is parity-tested against the shipped validator.

## Requirements

### R1: Make the planning schema self-contained

Move the canonical full schema from `schemas/plan-schema.md` to `skills/planning/schemas/plan-schema.md`. Do not retain a second full copy.

All paths written inside the planning skill are resolved from the planning skill root:

- `skills/planning/SKILL.md` → `schemas/plan-schema.md`
- `skills/planning/references/deepening.md` → `schemas/plan-schema.md`
- validator documentation → `schemas/plan-schema.md`

Direct non-historical repository consumers such as validation scripts must use the new repository-relative path. Historical evidence documents remain unchanged.

### R2: Inline only rules each external consumer executes

Replace load-bearing full-schema references with these local rules.

**implementing**

- accept `schema: plan/v1` only;
- execute only `status: approved` plans;
- reject `draft`, `done`, `superseded`, missing, and unknown status values with the existing status-specific diagnostics where defined;
- consume each Implementation Unit's full text, including exact values/signatures, `Files`, `Interfaces`, `Test scenarios`, and `Execution note`;
- use the plan's `execution` value to select the existing code versus non-code unit flow;
- when `body_seal` is present, require 64 lowercase hexadecimal characters and compare it with the R3 digest;
- when an approved plan has no current `body_seal`, inspect approval history: a plan that was never sealed remains valid, while removal of a previously stored seal is a violation;
- authorize re-sealing only through interactive deepening, except for the explicit user-approved, baseline-proven adoption migration in R5.

**release-loop**

- `--skip-plan` requires an existing plan with non-empty `schema`, `title`, `type`, `status`, `date`, and `execution` fields;
- require `schema: plan/v1` and `status: approved`;
- use the sibling planning validator when available;
- without that validator, enforce the stated minimum fields and reject unknown schema versions. This local fallback is sufficient for release-loop's gate; implementing performs its own preflight before execution.

**retrospective**

- `origin` is the repo-relative spec path;
- only post-contract `status: approved` plans transition to `done`;
- the transition mutates only frontmatter `status` and `completed_by`, with `completed_by` naming the landed base-branch commit;
- retrospective never changes the plan body or other frontmatter fields;
- pre-contract plans are not retroactively flipped.

Each external skill may include the optional sentence: “The full contract is in `../planning/schemas/plan-schema.md` when the sibling planning skill is installed.” Missing that optional file cannot block the locally defined behavior.

### R3: Verify body_seal in the shipped validator

Canonical input semantics are fixed to existing behavior:

1. read the file as UTF-8 text with universal-newline translation (`open(path, encoding='utf-8', newline=None).read()` semantics);
2. extract `text.split('---', 2)[2]` exactly;
3. encode that extracted text as UTF-8;
4. compute SHA-256 and render lowercase hexadecimal.

Do not add delimiter, whitespace, BOM, or line-ending restrictions beyond existing parser behavior.

When a non-empty, correctly formatted `body_seal` exists, recompute and compare it. A mismatch exits 1 and reports stored and computed values. Plans without `body_seal` retain their pre-change result.

Add `--print-seal <plan-path>` using the same computation. It must:

- exit 1 with a diagnostic when canonical extraction is impossible;
- reject missing or extra arguments with usage exit 2;
- never emit an empty successful result.

Repository check 14 and the shipped validator must agree for every fixture and plan in the current corpus. No validity rule may exist in only one implementation.

### R4: Document seal creation and verification

The schema's Body seal section must contain:

1. the R3 input semantics and exact extraction expression;
2. a worked example with a real complete digest;
3. a copy-pasteable independent Python command;
4. validator commands to print and verify a seal;
5. a statement that the seal is tamper evidence, not prevention. Authorization is audited through commit history and review.

Planning remains a two-commit process: commit `status: draft` first. Only after explicit user approval, make a second commit that flips `status: approved` and adds `body_seal`.

### R5: Define an auditable legacy migration

Migration applies only during a consuming repository's adoption of the release containing this contract.

The migration commit must record:

- the exact pre-upgrade baseline commit;
- the plan path;
- old and new seal values;
- the canonical reproduction command;
- explicit user approval.

Before replacing only `body_seal`, compare the canonical body text at the recorded baseline commit with the current body. They must be byte-for-byte equal after the R3 UTF-8/universal-newline read semantics. If they differ, seal-only migration is forbidden: revert the body or use interactive deepening.

Update the schema's existing “deepening only” rule with this narrow exception: user-approved seal-only migration during adoption, proven against the recorded pre-upgrade baseline. After adoption, deepening remains the sole authorized re-seal path for body changes.

### R6: Keep the diff issue-scoped

Change only:

- the plan schema location and its direct current consumers;
- the minimum inlined rules defined in R2;
- the planning validator and targeted tests;
- check 14 only as required for path/parity;
- schema usage/migration documentation and the current CHANGELOG entry.

Do not change frontmatter parsing, accepted execution values, terminal-state semantics, or unrelated skill behavior.

## Testing

- Targeted validator fixtures: correct seal, mismatch, one-byte mutation, malformed seal, absent seal, failed extraction, invalid CLI arguments, and print/verify round trip.
- Parity fixture: run shipped validator and check 14 computation on identical files and compare computed digests/results.
- Standalone planning fixture: copy only `skills/planning/`, assert every planning-local referenced file exists, create and validate a sealed fixture plan.
- Standalone consumer fixtures: copy each of implementing, release-loop, and retrospective without planning; review/execute their defined decision paths using only inlined rules.
- Regression: run the entire `scripts/test-plan-frontmatter.sh` and `scripts/test-body-seal.sh` files. Report the pre-existing case 20 separately; no previously passing case may regress.

## Risks

- **Schema move leaves stale current-code paths** — mitigate with a repository search limited to non-historical consumers and targeted validation-script tests.
- **Inline subsets drift from the full schema** — mitigate with a validation check that compares named invariant literals/fields used by the three consumers against the SSOT. Do not duplicate the full schema.
- **Seal implementations diverge** — mitigate with shared fixtures proving validator/check-14 parity.
- **Migration becomes a generic re-seal bypass** — constrain it to a recorded adoption baseline, unchanged canonical body, explicit user approval, and reviewable old/new values.

## Success Criteria

1. A standalone planning installation contains and resolves its full schema.
   - **Measured by**: copy only `skills/planning/` to a temporary directory; verify `schemas/plan-schema.md` exists and every planning-local schema reference resolves within that copy.
2. Each external consumer executes its defined plan decisions without the full schema.
   - **Measured by**: standalone fixtures for implementing, release-loop, and retrospective exercise every R2 branch with no sibling planning directory; pass means no required lookup outside the copied skill.
3. Correct and mutated seals receive identical results from the shipped validator and check 14.
   - **Measured by**: parity fixtures show correct seal exits 0 in both and a one-byte body mutation exits 1 in both with the same computed digest.
4. Seal printing is reproducible and safe on invalid input.
   - **Measured by**: `--print-seal` equals the independent R4 Python command; missing delimiter exits 1; missing/extra arguments exit 2; no failing case emits successful empty output.
5. Unsealed plans retain existing behavior.
   - **Measured by**: run the pristine and changed validators over every no-seal fixture and compare exit codes and diagnostics byte-for-byte.
6. Existing validator behavior outside issue #14 does not regress.
   - **Measured by**: all 26 previously passing cases in `scripts/test-plan-frontmatter.sh` remain passing; pre-existing case 20 is reported unchanged and is not counted as a new failure.
7. The repository body-seal test file passes in full with the new shipped-validator cases.
   - **Measured by**: `bash scripts/test-body-seal.sh` exits 0 and reports zero failed fixtures.
8. Legacy seal-only migration is distinguishable from a body edit.
   - **Measured by**: one fixture with identical R3 body at the recorded baseline permits the documented migration; a second fixture with a one-byte body change rejects seal-only migration.

## Open Decisions

None. The user selected a planning-owned full-schema SSOT with minimum rule subsets in the three external consumers.
