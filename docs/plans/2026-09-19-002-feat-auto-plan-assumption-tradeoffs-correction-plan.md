---
schema: plan/v1
title: Auto Planning Assumption and Trade-off Contract Correction
type: feat
status: superseded
date: 2026-09-19
execution: code
origin: docs/specs/2026-09-19-auto-plan-assumption-tradeoffs-design.md
body_seal: 11a45e8c863f7f22db7d73f45c91920c74d27747d7426253930e3ad92ce3d9d1
superseded_by: docs/plans/2026-09-19-003-feat-auto-plan-assumption-tradeoffs-final-plan.md
---

# Auto Planning Assumption and Trade-off Contract Correction Plan

## Goal

Add one explicit, validated assumption-and-trade-off contract to auto-generated
specs and plans. Preserve interactive authoring, historical artifact validity,
release-loop ledger authority, and standalone skill packaging.

## Assumptions and Preconditions

The approved design retains three live assumptions. Planning reran every
retained command before mapping units.

| Claim | Command | Observed at | Observed result | Evidence source |
|---|---|---|---|---|
| The target skills have no auto-mode contract yet. | `printf 'observed_at='; date -u +%Y-%m-%dT%H:%M:%SZ; python3 -c 'from pathlib import Path; names=("designing","planning"); print("; ".join(n+":auto="+str((Path("skills")/n/"SKILL.md").read_text().count("--auto"))+";tradeoff="+str((Path("skills")/n/"SKILL.md").read_text().lower().count("trade-off"))+";assumption-heading="+str((Path("skills")/n/"SKILL.md").read_text().count("Assumptions and Preconditions")) for n in names))'` | 2026-09-19T13:50:38Z | `designing:auto=0;tradeoff=1;assumption-heading=1; planning:auto=0;tradeoff=0;assumption-heading=0` | Feature worktree at `d17ee7e` |
| Existing artifact migration would cover 27 specs and 29 plans. | `printf 'observed_at='; date -u +%Y-%m-%dT%H:%M:%SZ; wc -l skills/designing/SKILL.md skills/planning/SKILL.md; printf 'spec_count='; git ls-files 'docs/specs/*.md' \| wc -l; printf 'plan_count='; git ls-files 'docs/plans/*.md' \| wc -l` | 2026-09-19T13:50:38Z | `spec_count=28; plan_count=29`; the origin-aware follow-up returned `tracked_spec_count=28; excluding_origin=27` at `2026-09-19T13:51:10Z` | Feature worktree; addendum `docs/deviations/2026-09-19-auto-plan-assumption-inventory-001.md` |
| The existing plugin skill discovery gate passes before this change. | `bash scripts/test-plugin-skill-discovery.sh` | 2026-09-19T13:50:38Z | `13 skills checked, 0 failures; ALL CHECKS PASSED` | Feature worktree command output |

The inventory contradiction is resolved by the committed addendum. The
approved scope remains unchanged, and the approved spec remains immutable.

## Trade-offs

| Option | Metric it improves | Metric it degrades | Measured cost |
|---|---|---|---|
| Rejected: prose-only auto guidance | Smallest patch and no new validation surface | Contract detectability; later edits can remove the rule without a focused failure | Origin evidence measured `0` auto clauses in the target skills; no artifact negative control can run |
| Selected: auto-only structured contract | Artifact completeness and reviewer visibility while preserving interactive behavior | Skill payload size and duplicated contract text across standalone packages | Bounded target-file diff; no existing specs or plans require migration |
| Rejected: contract required in every mode | Uniform artifact shape across all callers | Backward compatibility and authoring cost for non-auto callers | Origin evidence measured `56` existing spec/plan files as the strict-backfill review surface; current scope leaves them unchanged |

The selected option owns the decision. The focused harness owns contract
presence and negative-control measurements. The rejected alternatives remain
for later reconsideration only if new evidence changes the scope boundary.

## Architecture notes

- `skills/designing/SKILL.md` defines the auto contract for specs. It reads the exact `progress_path`, checks ledger `flags`, writes `mode: auto`, and requires assumptions and trade-offs before Architecture and Success Criteria.
- `skills/planning/SKILL.md` defines the same contract for plans. It preserves `Assumption Recheck`, writes `mode: auto`, and requires assumptions and trade-offs before Architecture notes and Implementation Units.
- Each standalone skill package receives a byte-identical `validate-auto-artifact.py`. The validators parse stable section markers and Markdown table fields without new dependencies.
- `scripts/test-auto-artifact-contract.sh` owns disposable fixtures, structural checks, validator invocation, negative mutations, and historical no-mode compatibility checks.
- The selected release-loop ledger remains the only invocation authority. A phase activates the contract only when its exact `progress_path` exists and its frontmatter flags contain `--auto`.
- Implementing, reviewing, shipping, and retrospective consume validated artifacts. They do not gain mode-specific branches.

## Assumption Recheck

The original inventory command produced a contradiction because the approved
origin spec became a new tracked file. The contradiction is resolved by the
committed addendum before this plan is finalized. The other two claims remain
matches. The approved spec remains unchanged.

## File structure

| File | Responsibility | Owner |
|---|---|---|
| `skills/designing/SKILL.md` | Auto-mode selection, required sections, field rules, validator invocation, and stop condition for specs | U1 |
| `skills/planning/SKILL.md` | Auto-mode selection, required sections, field rules, validator invocation, and stop condition for plans | U2 |
| `skills/designing/scripts/validate-auto-artifact.py` | Standalone validator for auto specs | U3 |
| `skills/planning/scripts/validate-auto-artifact.py` | Byte-identical standalone validator for auto plans | U3 |
| `scripts/test-auto-artifact-contract.sh` | Focused structural and artifact regression harness with disposable controls | U4 |

No historical spec or plan is modified. No release-loop source file is
modified; its existing packet already carries the exact ledger path and flags.

## Requirement trace

| Requirement | Carrier |
|---|---|
| R1, R3-R8 | U1 |
| R2-R8 | U2 |
| R9 | U3 and U4 |
| S1 | U1, U3, U4 |
| S2 | U2, U3, U4 |
| S3 | U1, U2, U4 |
| S4 | U3 and U4 |

## Scenario coverage map

| S-ID | Ordered unit chain | Observable verification |
|---|---|---|
| S1 | U1 -> U3 -> U4 | `bash scripts/test-auto-artifact-contract.sh` accepts the compliant auto-spec fixture and rejects missing, blank, and unquantified fields. Covers S1. |
| S2 | U2 -> U3 -> U4 | The same harness accepts the compliant auto-plan fixture and rejects the same mutations before implementation units would run. Covers S2. |
| S3 | U1 -> U2 -> U4 | Historical no-mode fixtures pass, and a non-auto skill path remains unchanged in the focused harness. Covers S3. |
| S4 | U3 -> U4 | Disposable negative controls fail for removed markers, blank cells, missing status rows, and numeric-cost removal. Covers S4. |

## Implementation Units

## U1: Define the designing auto contract

Execution note: test-first

Files:
  Modify: `skills/designing/SKILL.md`
  Test: `scripts/test-auto-artifact-contract.sh`

Interfaces:
  Consumes: exact `progress_path` from the release-loop packet; ledger `flags`; existing five-field live-assumption table; existing spec section markers.
  Produces: explicit auto-mode instructions for `mode: auto`, assumptions, trade-offs, non-goals, residual risks, success controls, and validator invocation.

Test scenarios:
  happy: the contract names the exact ledger path, `mode: auto`, five-field assumptions, four-column trade-offs, selected and rejected rows, and the implementation-deferred stop condition. Covers S1.
  edge: a no-live-assumptions artifact uses one explicit non-empty statement and a no-alternative decision uses `Selected:` plus `No rejected alternative:`.
  error: removing the auto marker, a required field, or the ledger-mode check makes the focused harness fail.
  integration: a compliant auto-spec fixture passes the package-local validator. Covers S1.

Steps:
  1. Add failing structural assertions for the designing contract and its auto-spec fixture to `scripts/test-auto-artifact-contract.sh`.
  2. Run the focused harness; confirm it names the missing auto contract.
  3. Update `skills/designing/SKILL.md` with the exact ledger selection rule, required section order, non-empty field rules, numeric measured-cost rule, validator command, and stop condition.
  4. Run the focused harness; confirm the compliant fixture passes and every design mutation fails.
  5. Commit: `feat(designing): require decisions in auto specs`

Acceptance: the designing contract is structurally detectable, references no unmeasured quantity, and its compliant fixture passes while each declared mutation fails.

## U2: Define the planning auto contract

Execution note: test-first

Files:
  Modify: `skills/planning/SKILL.md`
  Test: `scripts/test-auto-artifact-contract.sh`

Interfaces:
  Consumes: exact `progress_path` from the release-loop packet; ledger `flags`; approved origin spec; existing `Assumption Recheck` section.
  Produces: explicit auto-mode instructions for `mode: auto`, assumption recheck, assumptions, trade-offs, non-goals, residual risks, success controls, and validator invocation.

Test scenarios:
  happy: the contract requires assumptions and trade-offs before Architecture notes and Implementation Units while retaining Assumption Recheck. Covers S2.
  edge: a historical plan without `mode: auto` remains accepted outside the auto path.
  error: a mismatched ledger path, missing mode marker, blank cell, or missing status row makes the focused harness fail.
  integration: a compliant auto-plan fixture passes the package-local validator. Covers S2.

Steps:
  1. Add failing structural assertions for the planning contract and its auto-plan fixture to `scripts/test-auto-artifact-contract.sh`.
  2. Run the focused harness; confirm it names the missing planning contract.
  3. Update `skills/planning/SKILL.md` with the exact ledger selection rule, required section order, Assumption Recheck precedence, non-empty field rules, numeric measured-cost rule, validator command, and stop condition.
  4. Run the focused harness; confirm the compliant fixture passes and every planning mutation fails.
  5. Commit: `feat(planning): require decisions in auto plans`

Acceptance: the planning contract is structurally detectable, preserves fresh-evidence authority, and its compliant fixture passes while each declared mutation fails.

## U3: Add standalone auto-artifact validators

Execution note: test-first

Files:
  Create: `skills/designing/scripts/validate-auto-artifact.py`; `skills/planning/scripts/validate-auto-artifact.py`
  Test: `scripts/test-auto-artifact-contract.sh`

Interfaces:
  Consumes: one Markdown artifact path and `--mode auto`; section markers; Markdown tables.
  Produces: exit `0` for a compliant auto artifact; exit `1` with a named diagnostic for missing sections, blank cells, missing status rows, missing numeric measured cost, or invalid mode placement; exit `2` for usage or file errors.

Test scenarios:
  happy: compliant spec and plan fixtures pass through their respective package-local copies.
  edge: explicit no-live-assumptions and no-rejected-alternative statements pass when non-empty.
  error: removing one field, blanking one assumption cell, blanking one trade-off cell, removing a status row, or removing the only numeric cost fails.
  integration: both validators reject a fixture missing `mode: auto`; the harness separately rejects a missing or mismatched ledger flag before validator invocation. Covers S4.

Steps:
  1. Add failing validator cases and disposable fixtures to `scripts/test-auto-artifact-contract.sh`.
  2. Run the cases; confirm each malformed fixture fails with a distinct contract diagnostic.
  3. Implement the pure-standard-library parser and field checks in the designing validator.
  4. Copy the validated implementation byte-for-byte to the planning validator and invoke both copies independently.
  5. Run the validator cases; confirm compliant fixtures pass and all negative controls fail.
  6. Commit: `feat(auto): add standalone artifact validators`

Acceptance: both validator files are byte-identical, standalone, dependency-free, fail closed for every declared mutation, and accept historical no-mode fixtures when auto mode is not selected.

## U4: Add focused contract regression harness

Execution note: test-first

Files:
  Create: `scripts/test-auto-artifact-contract.sh`
  Test: `scripts/test-auto-artifact-contract.sh`

Interfaces:
  Consumes: both skill files, both validators, disposable Markdown fixtures, and the repository's existing shell test conventions.
  Produces: named pass or expected-reject results and `ALL CHECKS PASSED` only when every positive and negative case meets its expected outcome.

Test scenarios:
  happy: both compliant auto fixtures and both historical no-mode fixtures pass.
  edge: the harness handles spaces in temporary paths and removes every temporary fixture on exit.
  error: each structural marker removal and each blank or unquantified value produces the expected rejection.
  integration: one command exercises S1 through S4 without mutating tracked files. Covers S4.

Steps:
  1. Write fixture constructors and the positive cases using temporary directories.
  2. Add negative mutations for marker removal, missing five-field evidence, blank assumption cells, blank trade-off cells, missing status rows, and numeric-cost removal.
  3. Add historical no-mode fixtures and assert they remain accepted outside auto selection.
  4. Run the harness and verify each negative control fails for the intended reason.
  5. Add plugin discovery invocation and clean temporary directories in every exit path.
  6. Commit: `test(auto): guard assumption trade-off contract`

Acceptance: `bash scripts/test-auto-artifact-contract.sh` returns zero, reports zero unexpected outcomes, and emits `ALL CHECKS PASSED`; the same harness returns nonzero for each individually mutated control.

## Mutation/failure-state matrix

No stateful ceremony in the deliverable; no mutation/failure-state matrix required.

## Carry-forward trigger audit

The audit covers every open row in `ROADMAP.md` at planning time. Trigger classes
are edit-based, drift-based, or event-based. No unobservable drift-based trigger
was found.

| Tracker row | Trigger class | What fired it | Disposition |
|---|---|---|---|
| Conformance suite | edit-based | Structural validation failure trigger is marked fired in the tracker | Deferred: this focused contract harness is narrower than the repository-wide conformance suite. |
| Schema validators + fixtures | edit-based | Malformed plan or envelope trigger is marked fired in the tracker | Deferred: this plan validates auto artifacts only and does not alter plan/v1 or review-envelope/v1. |
| Session-history search | event-based | No future session-retro need is recorded | Deferred: unrelated to artifact authoring. |
| compound-refresh headless auto-apply | event-based | No three-cycle classification evidence is recorded | Deferred: unrelated to artifact authoring. |
| Cross-round deepening suppression | edit-based | No deepening contract section is in the file list | Deferred: current scope does not change deepening. |
| Demo/evidence capture | event-based | No UI-heavy adoption event is recorded | Deferred: no UI surface exists here. |
| Project-defined lane schema | event-based | No second custom-lane project is recorded | Deferred: no review-lane schema change is in scope. |
| Ambient compound triggers | event-based | No outside-loop capture evidence is recorded | Deferred: no trigger detector is in scope. |
| Gemini support verification | event-based | No Gemini-harness user event is recorded | Deferred: no question-tool adapter change is in scope. |
| Release-loop phase-worker dispatch | event-based | No new phase-worker dispatch event is recorded in the tracker | Deferred: this plan consumes the existing ledger packet only. |
| Pre-release / dev version convention | event-based | No new local versioning event is recorded | Deferred: versioning is outside the approved scope. |
| Evidence-tier vocabulary | event-based | No completion claim escaped at a lower evidence tier in this feature | Deferred: no shared vocabulary change is in scope. |
| Skill-level trace evidence | event-based | No retro lesson contradicting a skill section is recorded | Deferred: no retro trace channel change is in scope. |
| New-skill distinctness gate | event-based | No next new-skill proposal is recorded | Deferred: this modifies existing skills. |
| Post-Retro terminal criterion timing | event-based | No new post-Retro criterion is declared | Deferred: this plan has no terminal criterion. |
| Forced-failure matrix reuse | edit-based | The next planning-contract-change trigger is marked fired | Deferred: the approved deliverable has no stateful ceremony. |
| Facilitator output persistence | edit-based | No interview protocol or reviewing-dispatch file is in the file list | Deferred: no reviewer-output persistence change is in scope. |
| Invariant-attack review | edit-based | No reviewing dispatch contract file is in the file list | Deferred: review-phase work follows after implementation. |
| Success-criterion severity grading | edit-based | No review-triage contract file is in the file list | Deferred: no review triage change is in scope. |
| Dispatched-committer SSH identity | event-based | No dispatched committing worker is planned | Deferred: units commit in the owning session. |
| Retro commit handoff | event-based | No retro commit or handoff event is active | Deferred: Retro owns that transition. |
| Shipping merge command split | edit-based | No shipping or release-loop merge file is in the file list | Deferred: no outward action is part of implementation. |
| Body-seal evidence publication | edit-based | No body-seal publication file is in the file list | Deferred: plans are drafted and sealed by existing tooling. |
| Shipping outside-diff terminal gate | edit-based | No shipping merge-gate file is in the file list | Deferred: no Ship contract change is approved. |
| Post-merge raw failure traces | event-based | No merged-result failure exists for this feature | Deferred: no post-merge follow-up exists. |
| Legacy handoff missing cases | edit-based | No handoff test file is in the file list | Deferred: no handoff behavior is changed. |
| Legacy handoff copy fault injection | edit-based | No handoff fault-injection file is in the file list | Deferred: no handoff behavior is changed. |
| Exact review events | edit-based | No review ledger is in the file list during planning | Deferred: review phase records its own events. |

Attestation: every open tracker row was classified; fired rows have an explicit
unit or Deferred disposition; no drift-based record was unobservable.

## Deferred to Follow-Up Work

- General plan/v1 and review-envelope/v1 schema fixtures remain under the existing tracker row and are not widened into this auto-only contract.
- Repository-wide conformance integration remains under the Conformance suite row; this plan supplies only the focused negative controls required by R9.
- Shipping, review-dispatch, and Retro evidence changes remain under their existing carry-forward rows.

## Open unknowns

### Planning-time unknowns

None. The inventory contradiction has a committed addendum, and the remaining
scope, file ownership, contract fields, and verification commands are explicit.

### Implementation-time unknowns

- The validator's exact diagnostic wording will be chosen while matching existing shell and Python diagnostics; each failure class remains separately observable.
- The temporary fixture directory implementation will follow the existing test-script cleanup convention while preserving the acceptance commands above.

## Self-review record

- Assumption recheck: one contradiction is preserved and linked to a committed addendum; two claims match fresh evidence.
- Spec coverage: R1-R9 each map to a unit; S1-S4 each map to an end-to-end observable verification.
- Architecture-unit consistency: every architecture bullet appears in U1-U4 and no unit adds a runtime dependency or interactive gate.
- Negative controls: each required marker, field, blank-cell, status-row, and numeric-cost mutation has a named expected rejection.
- Placeholder scan: no unit depends on an undefined task, file, command variable, or future artifact.
- Interactive compatibility: historical no-mode fixtures remain accepted and no interactive gate file is modified.
- Implementation stop condition: if exact ledger selection, auto-only scope, explicit assumptions and trade-offs, or negative controls cannot be implemented without changing the approved contract, stop and return to the Design gate.
