# Changelog

All notable changes to this project are documented in this file.

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
