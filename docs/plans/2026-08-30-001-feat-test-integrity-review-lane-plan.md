---
schema: plan/v1
title: Test-integrity review sub-check
type: feat
status: approved
date: 2026-08-30
execution: code
origin: docs/specs/2026-08-30-test-integrity-review-lane-design.md
body_seal: 54627347f8ddb139e946478f331cc8af2ee9e7129e5301e1f024b15f217581d8
---

# Test-integrity Review Sub-check Plan

## Goal

Add a named `test-integrity` sub-check to the standing `tests` review lane and prove its bounded detector contract with a versioned C2-TI corpus. The evaluator must fail closed, use the existing lane-finding and merge contracts, and report reproducible recall, precision, isolation, and repeatability evidence.

## Architecture notes

- Keep the reviewer-facing contract in `skills/reviewing/references/lanes.md` and place the detailed checklist in `skills/reviewing/references/test-integrity.md`.
- Use one standard-library shell entry point with embedded Python. This matches the repository's executable validation pattern and avoids a runtime dependency.
- Represent each corpus case as JSON with stable case ID, class, source text, expected finding IDs, severity, and holdout status. The evaluator creates disposable files from these values.
- Implement six narrow lexical probes. Each probe returns the existing detail-tier fields and a source-line evidence item. The evaluator rejects malformed compact or detail findings before calculating metrics.
- Run the fixture under isolated `HOME`, `TMPDIR`, Git config, and hooks. Count network-capable command attempts and reject any non-local target before measuring detector results.
- Use the merge-pipeline contract as the source of severity, confidence, deduplication, suppression, and testing-gap rules. The evaluator checks those fields; it does not introduce a second envelope or a second severity scale.
- Keep the corpus and evaluator independent enough that removing one detector or one expected finding makes a named case fail. Record the failed detector assertion as discrimination evidence.

## Assumption Recheck

Origin spec retains no live assumptions; no assumption recheck required.

## File structure

| File | Responsibility | Owner |
|---|---|---|
| `skills/reviewing/references/lanes.md` | Name `test-integrity` under the always-on `tests` lane and retain the lane's non-flags | U1 |
| `skills/reviewing/references/test-integrity.md` | Define the six checks, evidence requirements, severity guidance, and non-flags | U1 |
| `scripts/test-review-test-integrity.sh` | Run fixture creation, probes, schema checks, metrics, repeatability, and isolation audit | U2-U4 |
| `tests/conformance/review/test-integrity-corpus.json` | Versioned C2-TI seeded defects, holdouts, clean fixture, and expected findings | U2-U3 |
| `scripts/validate.sh` | Run the no-network, no-model dogfood check as a validation gate | U4 |
| `docs/specs/2026-08-30-test-integrity-review-lane-design.md` | Approved source specification | U1 |
| `docs/plans/2026-08-30-001-feat-test-integrity-review-lane-plan.md` | This plan and traceability record | U1 |

## Scenario coverage map

| S-ID | Ordered unit chain | Integration evidence |
|---|---|---|
| S1 | U1 -> U2 -> U4 | `case_lane_contract` checks the named sub-check and its six classes in the standing lane. Covers S1. |
| S2 | U2 -> U3 | `case_seeded_defects` runs every seeded case, validates detail findings, and measures recall and precision. Covers S2. |
| S3 | U2 -> U3 | `case_clean_fixture` runs the clean fixture three times and checks no P0/P1 finding plus identical fingerprints. Covers S3. |
| S4 | U2 -> U3 -> U4 | `case_fixture_isolation` proves isolated Git state, temporary paths, network command count, and nested compound-loop validation. Covers S4. |

## Implementation Units

## U1: Document the tests-lane sub-check contract
Execution note: test-first
Files:
  Create: `skills/reviewing/references/test-integrity.md`
  Modify: `skills/reviewing/references/lanes.md`
  Test: `scripts/test-review-test-integrity.sh`
Interfaces:
  Consumes: existing `tests` lane contract, `schemas/lane-findings.schema.json`, and `skills/reviewing/references/merge-pipeline.md`
  Produces: named `test-integrity` entry with six checks, evidence rules, severity guidance, and non-flags
Test scenarios:
  happy: the lane text names all six integrity classes and the standard lane-findings contract
  edge: the lane text keeps coverage gaps and weak assertions in the tests lane while routing unrelated security or performance concerns to their existing lanes
  error: deleting one required class or the standard schema reference makes `case_lane_contract` fail by the missing class name
  integration: `case_lane_contract` walks S1
Steps:
  1. Add a failing `case_lane_contract` assertion for the absent `test-integrity` name and six class names.
  2. Run `bash scripts/test-review-test-integrity.sh contract`; confirm the assertion fails because the lane has no named sub-check.
  3. Add the concise lane entry and the detailed reference contract.
  4. Run the contract case; confirm all required names and existing merge-pipeline references are present.
  5. Commit: `docs(review): define the test-integrity sub-check`
Acceptance: the contract case passes and the lane references exactly the six named classes without adding a new lane or schema.

## U2: Build the deterministic finding probes and corpus
Execution note: test-first
Files:
  Create: `scripts/test-review-test-integrity.sh`; `tests/conformance/review/test-integrity-corpus.json`
  Modify: none
  Test: `scripts/test-review-test-integrity.sh`
Interfaces:
  Consumes: corpus cases containing source text, class, expected finding IDs, severity, and holdout marker
  Produces: detail-tier lane findings with `title`, `severity`, `file`, `line`, `why_it_matters`, `evidence`, `confidence`, `owner`, `autofix_class`, `requires_verification`, and `pre_existing`
Test scenarios:
  happy: two seeded defects per class produce their expected IDs and each finding validates against the existing schema
  edge: safe holdouts use neighboring syntax without triggering the class probe
  error: malformed fields, unknown classes, invalid severity, missing evidence, and duplicate IDs fail closed
  integration: `case_seeded_defects` walks S2
Steps:
  1. Write a failing corpus inventory and finding-schema assertion for one case in each class.
  2. Run the corpus case; confirm it fails because the corpus and probes do not exist.
  3. Add six class definitions, two seeded defects per class, one holdout per class, and one clean fixture.
  4. Implement one bounded probe per class and emit the source path, line, impact, and evidence for every match.
  5. Validate every finding against the required schema fields and reject malformed outputs before metric calculation.
  6. Run the seeded, holdout, and clean cases; confirm the expected IDs and failure reasons.
  7. Commit: `feat(review): add deterministic test-integrity findings`
Acceptance: seeded and holdout cases have zero unexpected IDs, all findings pass schema validation, and malformed output never becomes a clean result.

## U3: Add hermetic fixture auditing and quality metrics
Execution note: test-first
Files:
  Modify: `scripts/test-review-test-integrity.sh`
  Test: `scripts/test-review-test-integrity.sh`
Interfaces:
  Consumes: U2 findings, disposable fixture root, local Git repository, isolated environment, and expected corpus labels
  Produces: recall, precision, clean-fixture P0/P1 count, three-run fingerprint equality, Git isolation evidence, and network-call count
Test scenarios:
  happy: recall is 100% for seeded P0/P1 defects, precision is at least 90%, and the clean fixture has zero P0/P1 findings
  edge: roots containing spaces are contained, shared temporary directory patterns are rejected, and safe Git hooks/signing configuration is accepted
  error: a network command, inherited hook, signing key, shared temporary path, or host environment read fails before a clean verdict
  integration: `case_clean_fixture` and `case_fixture_isolation` walk S3 and S4
Steps:
  1. Add failing assertions for isolated `HOME`, isolated `TMPDIR`, empty hooks, disabled signing, zero network attempts, and the metric thresholds.
  2. Run the fixture group; confirm failure names the missing isolation or metric evidence.
  3. Create a temporary Git repository with explicit identity, `commit.gpgsign=false`, and an empty hooks path; clear credential and network environment variables.
  4. Execute the corpus three times, normalize fingerprints, compare runs, and count true positives, false positives, and false negatives by class and severity.
  5. Add a mutation-shaped case that removes one seeded defect and asserts the detector assertion fails rather than setup.
  6. Run the fixture group and retain concise stdout evidence for each required threshold.
  7. Commit: `test(review): measure test-integrity fixture quality`
Acceptance: the fixture group proves all R3-R8 thresholds and reports a nonzero failure for each removed detector or seeded defect.

## U4: Connect dogfood to compound-loop validation
Execution note: test-first
Files:
  Modify: `scripts/validate.sh`; `scripts/test-review-test-integrity.sh`
  Test: `scripts/test-review-test-integrity.sh`; `scripts/validate.sh`
Interfaces:
  Consumes: U1-U3 contract, corpus, evaluator, and validation root
  Produces: one validation gate that runs the local dogfood without network or model calls
Test scenarios:
  happy: direct dogfood and nested `bash scripts/validate.sh` both pass with the recursion guard
  edge: the nested validation sees the same repository root and does not scan the disposable fixture as a source tree
  error: a failed dogfood case or compound-loop validation exits nonzero and names the failed gate
  integration: `case_validation_gate` completes the S4 path
Steps:
  1. Add a failing assertion that `scripts/validate.sh` invokes the dogfood command and that the nested invocation uses only the documented recursion guard.
  2. Run the validation gate; confirm it fails because no test-integrity invocation exists.
  3. Add the guarded invocation at the end of `scripts/validate.sh` and keep the dogfood script's network/model counters explicit.
  4. Run the direct dogfood, full validation, ruff-equivalent shell checks, and existing conformance checks.
  5. Commit: `test(review): gate validation on test-integrity dogfood`
Acceptance: `bash scripts/test-review-test-integrity.sh dogfood` and `bash scripts/validate.sh` exit 0; a mutated corpus or lane contract exits nonzero.

## Mutation/failure-state matrix

No stateful ceremony in the deliverable; no mutation/failure-state matrix required.

## Carry-forward trigger audit

| Tracker row | Trigger class | What fired it | Disposition |
|---|---|---|---|
| Conformance suite | event-based | The roadmap records a structural-validation regression and keeps the suite row open; this cycle does not alter the release-loop conformance implementation. | Deferred to Follow-Up Work: finish the separately scoped release-loop conformance cycle before closing its row. |

The following open rows were audited as event-based and did not fire in this plan because their named future occurrence is outside this change: Schema validators + fixtures; Session-history search; compound-refresh headless auto-apply; Cross-round deepening suppression; Demo/evidence capture; Project-defined lane schema; Ambient compound triggers; Gemini support verification; Release-loop phase-worker dispatch; Pre-release / dev version convention; Evidence-tier vocabulary; Skill-level trace evidence; New-skill distinctness gate; the post-Retro terminal criterion; the reusable forced-failure matrix contract; persisted reviewer output; invariant-attack wording in review dispatch; success-criterion severity grading; dispatched-committer SSH evidence; retro branch merge/push coupling; `gh pr merge --delete-branch` handling; canonical adoption evidence publication; Shipping's outside-diff disposition gate; bounded raw post-merge failure output; legacy handoff case coverage; mid-directory handoff fault injection; and exact structured review events.

Audited `ROADMAP.md` at `59dcff696ba2aa3bfa24a46ed77baee5c41c2ac6`: 29 open rows, 1 fired, 0 unobservable.

## Deferred to Follow-Up Work

- Complete the release-loop conformance suite and its live harness cycle named by the Conformance suite roadmap row.
- Add formal custom-lane schema support only when a second consuming project defines a project lane.
- Add reviewer-output persistence only when the reviewing dispatch contract changes.

## Open unknowns

### Planning-time

None. The source schema, merge-pipeline contract, repository validation entry point, and fixture pattern are present and readable.

### Implementation-time

- The exact lexical expressions for each probe remain implementation details and must stay limited to the seeded and holdout patterns.
- The exact temporary-directory prefix is implementation detail; the evaluator must record the resolved disposable root and reject shared paths.
