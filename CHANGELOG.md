# Changelog

All notable changes to this project are documented in this file.

## [0.10.0] - 2026-08-03

### Added
- Release-loop completion now archives the progress record and working artifacts after Retro, then reports the exact archive path.

### Changed
- Loop start and resume now reuse one persisted archive destination and distinguish completed, incomplete, corrupt, and ambiguous records.

### Fixed
- Prevented feature-derived path escape, collision-suffix drift on rerun, incomplete archive matches, stranded corruption backups, and stale archive verification.

## [0.9.0] - 2026-08-01

### Added
- Mechanical body-seal enforcement for approved plans: `body_seal` (SHA-256 hex digest) set at approval, verified by `validate.sh` check 14, with cross-cutting immutability checks in implementing preflight and reviewing.
- Outward-publication boundary recognition: actions making artifacts accessible outside the local repo's default branch (push, publish, release, visibility change) now constitute a stateful ceremony requiring a mutation/failure-state matrix.
- `scripts/test-body-seal.sh` fixture harness with 5 test cases covering correct seal, wrong seal, absent seal, golden-hash round-trip, and terminal-state-flip scenarios.
- `scripts/test-plugin-skill-discovery.sh` validating plugin skill paths, frontmatter, and manifest agreement across all 13 skills.
- `execution: ops` added to the plan schema enum and frontmatter validator.
- Interview protocol vocabulary expanded: `no previous retro doc` shape, `no evidenced answer (dispatch cap)` verdict form, round-span notation, and verdict-by-independence-level table.
- Risk mitigation traceability in planning step 14: Spec coverage now traces Risks table mitigations to units or Deferred entries.

### Changed
- `validate.sh` check 9 verdict form count updated from 3 to 4 to accommodate the dispatch-cap verdict form.
- Release headless-path `.release/draft.md` now carries the same non-authorization marker as the interactive path.

### Fixed
- `validate-plan-frontmatter.py` now validates `body_seal` format (64-char lowercase hex SHA-256).
- Cleared all 30 carry-forward items from ROADMAP.md (22 previously completed, 8 resolved this cycle).

## [0.8.0] - 2026-07-30

### Added
- Three new `scripts/validate.sh` structural checks: check 11 (final_action shape validation), check 12 (carry-forward T-ID referential integrity across retro docs), and check 13 (planning step/item numbering contiguity and cross-file reference resolution).
- Designing step 11 gains a principle-exception composability check: when a spec pairs a universal principle with a requirement mandating an apparent exception, the spec names the carve-out.
- `scripts/test-final-action-skip.sh` fixture test verifying check 11's skip path when no progress.md exists.
- Three malformation-guard fixture cases (H/I/J) added to `scripts/test-retro-format-drift.sh` covering check 9's level-count, verdict-count, and verdict-line guards.

### Changed
- Planning step 14 (Self-review) gains two checks: architecture-unit clause consistency (diff Architecture notes claims against unit steps) and command closure (verify every shell variable referenced in a unit step is assigned within that step or earlier).
- Retrospective Phase 4 now mandates classifying each carry-forward row's trigger class (edit-based, drift-based, event-based) before classifying its status.
- `progress-schema.md` final_action block gains an optional `marker` field; the `predicted -> determined` transition now has the same explicit same-edit Log clause as the other transitions.
- Shipping verification reference adds the source-over-memory citation rule: claims about file content require a same-turn read.
- Shipping SKILL.md Step 7 adds the hand-up packet definition and a message-freshness rule for post-review commit messages.
- Reviewing SKILL.md adds "claim layer" to the canonical evidence-tier term list.

### Fixed
- Repaired two pre-existing red test suites: signal-drift Case D line reference (77 -> 94) and release-publication hash fixture.
- `validate.sh` check 5 now emits a named `FAIL:` line instead of a Python traceback on unreadable files.
- `scripts/test-release-publication.sh` now pins `PYTHON_SUPPORT_FILE` at the delegation boundary.
- `scripts/test-python-compatibility.sh` bootstrap interpreter gated at CPython >= 3.8.
- Closed the plan-skip-documentation retro's missing `(T1)` carry-forward T-ID citation.

## [0.7.1] - 2026-07-27

### Added
- Documented the cross-skill behavioral mandate gap (a mandate in skill A for behavior skill B performs is dead prose when B's entry path doesn't read A) and the validator harness mutation-gap technique as reusable solutions.

### Fixed
- Planning step 1 now specifies how to document a plan skip: attest all four conditions, then hand off; in release-loop context, write to progress.md Log. Aligns the release-loop Plan phase gate with planning's actual Exit condition.
- Fixed `Plan:` → `plan:` casing at planning step 18 to match progress-schema.md (P3 carry-forward closed).

## [0.7.0] - 2026-07-27

### Added
- Settled the plan `status` enum at `draft | approved | done | superseded` with terminal-state evidence fields (`completed_by:` for done, `superseded_by:` for superseded), rejection records for `in-progress` and `abandoned`, a mutable-slot boundary, and an applicability boundary for grandfathering.
- Shipped `skills/planning/scripts/validate-plan-frontmatter.py` — a pure-stdlib plan/v1 frontmatter validator with 27-case fixture harness, CWD-independent root derivation, and CPython 3.9–3.14 compilation.
- Gated the plan corpus in `scripts/validate.sh` (15 plans validated) and registered the validator in the Python compatibility harness.
- Added a carry-forward trigger audit step to `skills/planning/SKILL.md` with edit/drift/event-based classification and a reviewer re-derive mandate.
- Added carry-forward trigger audit and plan-schema hard-floor sections to `schemas/plan-schema.md`.
- `skills/planning/SKILL.md` now gates plan commits on the frontmatter validator and writes `superseded` status on predecessor plans.
- `skills/retrospective/SKILL.md` Phase 8 now flips covered plans to `done` atomically with the retro commit, with flip-all for multi-plan retros.
- `skills/implementing/SKILL.md` Pre-flight now refuses terminal-status plans naming the evidence field.
- Documented PEP 585 annotations crash and mandated-field-absent-from-schema as reusable solutions.

### Fixed
- Compound frontmatter validator now runs cleanly on CPython 3.8 — replaced `list[str]` annotation with `from __future__ import annotations` placement.
- Plan frontmatter validator guards against list-valued scalar fields (TypeError crash) and validates `completed_by` through the scalar helper.

## [0.6.0] - 2026-07-24

### Added
- Added the completion-evidence vocabulary to CONCEPTS.md — Evidence tier, Evidence-tier ladder (failing-repro-now-passing > end-to-end run > integration test > unit test > typecheck/build), Claim layer, Layer-mismatch, and Binary completion report — with the rules that typecheck/build alone never closes a completion claim and that evidence fitting no tier is cited tier-free.
- Added the layer-mismatch rule to reviewing's output step: a completion claim whose best evidence sits below its claim layer is an actionable finding and the verdict cannot be `clean` while it stands; a claim with no determinable layer files an unverifiable-claim finding instead, and layer-mismatch findings pass through normal suppression with no special exemption.
- Added the evidence-tier ladder and binary completion report form to shipping's verification reference — `verified: <observation>` / `unverified: <blocker>` bound to exactly the Step 1 verification-gate report and formally reported claim→evidence rows, with conversational narration exempt — plus the Step 1 pointer naming both.
- Added hypothesis kill criteria, a standing boring hypothesis, and predict-before-probe discipline to debugging Phase 2, and captured the carry-forward trigger planning-audit lesson under docs/solutions/workflow-issues/.

### Changed
- retrospective Phase 3 and the retro template now record measured results in the binary completion report form: tier named where one applies, tier-free otherwise, rubric-measured rows reporting evidence acquisition rather than judgment, and the tri-state Verdict column preserved.
- ROADMAP registers the ultraprompt survey (docs/research/ultraprompt-survey.md) with three future-candidate imports and the evidence-tier cycle's new carry-forward rows (planning-time trigger audit, vocabulary polish batch, spec-level carve-out rule).

## [0.5.0] - 2026-07-22

### Added
- Added the final-action record to the release-loop progress schema: `final_action` with kind `merge-to-base`, closed status vocabulary `predicted | determined | executed`, the exact command once determined, and an update timestamp — declared at loop start, refined at determination and invalidation points, and flipped to executed in the same edit as its evidence Log line and `merged: true`; always preparation evidence, never approval.
- Added the prepare-before-gate rule across the lifecycle: release-loop verifies the record is determined and persisted before the Ship gate resolves; shipping persists the exact merge command plus a non-authorization marker before the merge gate on every path that reaches it, with a byte-identical hand-up packet for dispatched workers and an inherently untracked git-dir handoff file for standalone runs; release persists the interactive gate packet to `.release/draft.md` before Phase 5 presents it and rewrites it before every re-presentation.
- Added session-resilience vocabulary to CONCEPTS.md (Final-action record, Prepare-before-gate, Non-authorization marker) and captured the universal-invariant scope-enumeration lesson under docs/solutions/workflow-issues/.

### Changed
- release-loop resume now verifies a determined final-action record against live state before trusting it, flips it back to predicted with a logged reason on failure, and surfaces the record's status in the resume report.

## [0.4.0] - 2026-07-21

### Added
- Added an enforced retrospective interview protocol: facilitator-only verdict authority, a stateless round contract capped at 5 dispatches, verbatim verdict recording under four closed independence levels, and an Interview Transcript section in the retro template that findings must cite by T-ID or measured data.
- Added the interview's structural checks: end-of-interview carry-forward and findings-citation checks, a pre-commit transcript check, and a backward check that audits the previous retro doc from an independent later execution.
- Added validate.sh check 9, a retro format-drift gate asserting the template's closed vocabularies agree with the retrospective skill prose and probes contract — including the co-rename blind spot closed by deviation addendum 003 — backed by a seven-case red-then-green fixture harness.

### Changed
- Standardized the diff-size metric as "Changed non-test lines" across the reviewing lanes, retro template, and concept glossary, and added the planning skill's missing Entry/Exit/Gate section with the draft-then-approve USER gate.

## [0.3.1] - 2026-07-20

### Changed
- Removed the EntireContext-specific future-hook references from the `retrospective` skill and the roadmap candidate table; third-party decision capture is left to user-level configuration, while the product-neutral session-history hook point remains.

## [0.3.0] - 2026-07-19

### Added
- Added explicit gated outward publication for completed local releases, with separate first-hand consent, prepare-only headless packets, resumable branch/tag/page transitions, narrow repair, and protected-version handling.
- Added mutation and failure-state matrices that require stateful ceremonies to map durable transitions across success, forced failure, rerun, compensation, headless, and cancellation outcomes with disposable evidence before review.
- Added one CPython support contract and strict Python 3.9/3.14 compilation for registered committed and generated Python artifacts.

### Changed
- Made approved lifecycle artifacts auditable by retaining live-assumption evidence, rerunning it during planning, and requiring committed deviation addenda before accepting contradictions or post-approval observable drift.

### Fixed
- Hardened publication against missing capabilities, unsafe remote identities, stale transition fingerprints, tampered consent packets, machine-output drift, and cross-Python embedded-template warnings.
- Made compatibility validation fail closed with exact endpoint identities, safe paths containing spaces, boundary-specific syntax and warning detection, and cleanup of all materialized Python residue.

## [0.2.0] - 2026-07-16

### Added
- Added a local release ceremony derived from committed lifecycle evidence, with synchronized plugin manifests, CHANGELOG authoring, annotated tags, and a prepare-only headless handoff.
- Added validation that detects byte drift and coverage gaps across the canonical headless terminal signals.
- Preserved the six distillation inventories as durable research so future audits can trace authored skills back to their source decisions.

### Changed
- Strengthened lifecycle review and delivery guidance with explicit empirical grounding, pre-delivery quality gates, direct-consent boundaries, and inventory traceability learned from the first pilots.

### Fixed
- Hardened release preparation and recovery around missing remote default branches, complete source inventories, normalized drop dispositions, fail-fast command packets, exact release subjects, and manifest diagnostics.

## [0.1.0] - 2026-07-16

### Added
- Introduced the cross-harness `compound-loop` plugin with 12 skills spanning Design, Plan, Implement, Review, Ship, Retro, and knowledge compounding for Claude Code and Codex.
- Added the normative principles, shared schemas, validation script, lifecycle state contracts, and dual plugin manifests that keep those skills portable across harnesses.
