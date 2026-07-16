---
schema: plan/v1
title: Release Skill and v0.2.0 Dogfood Ceremony
type: feat
status: approved
date: 2026-07-16
execution: code
origin: docs/specs/2026-07-16-release-skill-design.md
---

# Release Skill and v0.2.0 Dogfood Ceremony Plan

## Goal

Add the `release` skill as the sole owner of the local versioned-release
ceremony, protect its manifest and terminal-signal contracts with executable
fixtures, and then use the reviewed skill to cut local tag `v0.2.0`. The
ceremony must preserve source-inventory traceability, require first-hand user
approval before commit or tag creation, and leave headless invocations in a
prepare-only state.

## Architecture notes

- **Deliverable classification**: this is a code plan. The primary user-facing
  artifact is Markdown, but the deliverable also changes executable shell and
  Python-in-shell validation logic and performs git state transitions.
- **Single skill file**: create `skills/release/SKILL.md` without a new
  `references/` subtree. `skills/shipping/SKILL.md` and
  `skills/release-loop/SKILL.md` show that a phase-oriented ceremony of this
  size fits the repository's established single-file skill scale; a reference
  split would add navigation without a second consumer or reusable concept.
- **Existing patterns to reuse**:
  - Detect the default branch with the repository's established
    `git symbolic-ref --short refs/remotes/origin/HEAD ... || echo main`
    fallback from `skills/release-loop/SKILL.md`.
  - Use the blocking-question protocol in `references/question-tools.md` for
    the release USER gate, and preserve `skills/release-loop/SKILL.md`'s rule
    that relayed approval is not authorization to execute a protected action.
  - Follow `schemas/headless-contract.md`: exact, case-sensitive terminal
    signals are the last non-empty output line; headless mode never asks a
    blocking question.
  - Follow the disposable-copy harness shape in
    `scripts/test-signal-drift.sh`; fixtures mutate copies, distinguish the
    new check with a check-specific marker, and remove temporary directories.
- **Known Pattern — empirical fixture grounding**:
  `docs/solutions/workflow-issues/spec-review-empirical-grounding-gap.md`
  requires running the pre-feature tool against the exact fixture mutation.
  This was done during planning: current `scripts/validate.sh` exits 0 for
  both a `9.9.9` manifest mismatch and a missing `.codex-plugin` `version`, so
  both fixtures are genuinely red because check 7 is absent rather than
  because an unrelated check already catches them.
- **Known Pattern — inventory traceability**:
  `docs/solutions/workflow-issues/inventory-traceability-success-criterion.md`
  and `CONCEPTS.md` require a source inventory plus an explicit drop-list.
  The release draft must enumerate every in-range spec and either carry its
  topic into the CHANGELOG or record a gate-reviewed drop reason. Git-log
  entries supplement the inventory but do not replace it when specs exist.
- **Release range and inventory rules**:
  - With a previous tag, use `<last-tag>..HEAD`; identify committed lifecycle
    artifacts with `git log --name-only --format= <range> -- docs/specs
    docs/retros`, deduplicate paths, and read the committed versions at HEAD.
  - With no previous tag, collect committed lifecycle artifacts reachable from
    HEAD. If none exist, derive the current release draft from non-noise commit
    subjects and label it `derived from git log — no spec inventory`.
  - When `CHANGELOG.md` is absent but prior release evidence exists, draft
    older sections below the current section. For this repository, backfill a
    concise `v0.1.0` section from the v0.1 spec and release retro.
- **Version decision**: validate manifest values as SemVer 2.0.0 strings.
  Propose minor for pre-1.0 releases containing features and patch for
  fixes-only releases. An explicit version argument bypasses proposal
  generation but never bypasses the USER gate. This plan's confirmed dogfood
  target is `0.2.0`.
- **Commit and tag invariant**: the release commit changes exactly
  `CHANGELOG.md`, `.claude-plugin/plugin.json`, and
  `.codex-plugin/plugin.json`; annotated tag `v0.2.0` targets that commit.
  Before reporting completion, compare both manifest versions, the newest
  CHANGELOG heading, and the newest tag and require all four to equal `0.2.0`.
- **Two-stage execution boundary**: U1-U3 run on an isolated feature branch.
  After their per-unit reviews and an extra full-branch pre-release review are
  clean, the orchestrator obtains first-hand user authorization to integrate
  them onto local `main`, verifies the merged result, and cleans the feature
  worktree. U4 then runs from the clean default-branch checkout, presents the
  release skill's separate USER gate, and creates the release commit and tag.
  A final review after U4 covers the integrated feature plus release artifact.
  This ordering is required because the skill must reject release execution
  from a feature branch.
- **Remote-state correction**: live research found an `origin` remote even
  though the approved spec records none. The approved scope still excludes
  pushing tags and creating a GitHub release; U4 is local-only. The now-fired
  remote trigger is recorded under Deferred to Follow-Up Work for a new design
  cycle rather than expanded into this implementation.
- **Retro carryover**: the four-unit plan does not meet the ROADMAP threshold
  of five units for the larger-feature dispatch pilot. Normal implementing
  rules still favor serial fresh-context subagents because the units are
  dependent; no artificial unit split is introduced merely to satisfy the
  metric.

## Global constraints

- Do not modify `skills/release-loop/SKILL.md`, `skills/shipping/SKILL.md`,
  `skills/retrospective/SKILL.md`, or `ROADMAP.md`.
- Do not push commits or tags and do not create a GitHub release.
- Do not create a release commit or tag without first-hand approval received
  by the session executing those commands.
- In `mode:headless`, do not commit, tag, or ask a question; write
  `.release/draft.md`, report exact commands, and end with the canonical skip
  signal.
- Keep existing headless-contract producer rows and signal strings byte-for-
  byte unchanged; only clarify the version rule and add the `release` row.
- Keep release fixture mutations inside disposable copies and remove every
  temporary directory, including on assertion failure.
- The `v0.2.0` release commit contains only `CHANGELOG.md` and the two plugin
  manifests; implementation and validation changes land before it.

## File structure

### Skill and discoverability

- Create: `skills/release/SKILL.md` — complete Preflight → Collect → Draft →
  Version → Gate → Execute → Report protocol for interactive and headless
  invocations.
- Modify: `README.md` — add `release` to the user-facing skill roster without
  changing the `release-loop` phase model.
- Modify: `.gitignore` — add `.release/` as machine-local draft state.

### Validation and contract protection

- Create: `scripts/test-manifest-version-sync.sh` — disposable-copy fixtures
  for clean, mismatch, missing, invalid, and absent manifest-version states.
- Modify: `scripts/validate.sh` — add the 13th roster entry, extend check 6 to
  `release`, and add check 7 for manifest version validity and agreement.
- Modify: `scripts/test-signal-drift.sh` — add a release-signal mutation case.
- Modify: `schemas/headless-contract.md` — clarify the additive-row version
  rule and add the three release terminal signals.

### Dogfood release artifact

- Create: `CHANGELOG.md` — current `0.2.0` section plus the one-time `0.1.0`
  backfill, both derived from committed lifecycle evidence.
- Modify: `.claude-plugin/plugin.json` — bump `version` from `0.1.0` to
  `0.2.0` in the release commit.
- Modify: `.codex-plugin/plugin.json` — bump `version` from `0.1.0` to
  `0.2.0` in the same release commit.
- Runtime only, ignored: `.release/draft.md` — headless or pre-gate draft and
  exact command handoff; never staged.

## Scenario coverage map

| S-ID | Scenario | Ordered unit chain | Walking evidence |
|---|---|---|---|
| S1 | Cut v0.2 from lifecycle artifacts | U2 → U3 → U4 | U4 integration scenario `dogfood v0.2.0 from v0.1.0..HEAD lifecycle inventory` runs the real USER gate, release commit, annotated tag, traceability audit, and four-way comparison. Covers S1. |
| S2 | Spec-less repo fallback | U2 → U3 → U4 | U2 integration scenario `spec-less headless fixture reaches the gate boundary with git-log provenance` proves fallback collection and drafting; U4's real gate-to-commit/tag path proves the shared execution half. Together they cover S2 without publishing a fixture tag externally. |
| S3 | Manifest drift blocks the ceremony | U1 → U2 → U3 | U1 cases B-E prove the persistent validator is red before check 7; U2's drifted-manifest invocation proves Preflight fails before draft creation; U3 makes both mechanisms green. Covers S3. |
| S4 | Nothing to release | U2 → U4 | U2 disposable tagged-HEAD scenario proves the no-write skip path; U4 repeats the real skill after tagging `v0.2.0` and requires `Release skipped — HEAD already released as v0.2.0`. Covers S4. |
| S5 | Headless invocation prepares but never executes | U2 → U3 | U2 real-repo headless smoke snapshots HEAD and tags, writes the ignored draft, and emits the exact skip signal; U3 drift-protects that signal. Covers S5. |

## Implementation Units

## U1: Manifest-version fixture harness
Execution note: test-first
Files:
  Create: scripts/test-manifest-version-sync.sh
  Modify: none
  Test: scripts/test-manifest-version-sync.sh
Interfaces:
  Consumes: repository root containing `.claude-plugin/plugin.json`, `.codex-plugin/plugin.json`, and `scripts/validate.sh`; each fixture operates on a new `mktemp -d` copy with `.git` removed
  Produces: executable fixture harness with Cases A-E, per-case pass/fail output, aggregate `ALL CASES PASSED` output on success, nonzero aggregate exit on any assertion failure, and unconditional cleanup of every disposable copy
Test scenarios:
  happy: Case A leaves both manifests at `0.1.0`, expects `scripts/validate.sh` exit 0 and `ok:   plugin manifest versions agree: 0.1.0`; before check 7 exists it is red because the exact line is absent
  edge: Case C removes `.codex-plugin/plugin.json`'s `version`, and Case D replaces it with `v0.1`; each expects nonzero exit plus a `[manifest-version]` failure naming `.codex-plugin/plugin.json`
  error: Case B changes `.codex-plugin/plugin.json` to `9.9.9` and expects a mismatch failure naming both files and both values; Case E removes `.codex-plugin/plugin.json` and requires a `[manifest-version]` failure with no Python traceback, distinguishing check 7 from existing JSON check 1
  integration: one `bash scripts/test-manifest-version-sync.sh` run executes Cases A-E against disposable copies and is the validator half of Covers S3
Steps:
  1. Write a shell harness following `scripts/test-signal-drift.sh`: `setup_copy`, string assertions, `run_case`, aggregate failure count, and cleanup that runs before every case returns.
  2. Implement Case A and assert the exact future check-7 success line; run it and confirm red because current validation has no manifest-agreement success line.
  3. Implement Cases B-D with Python JSON mutations; require nonzero exits and `[manifest-version]` diagnostics with the exact offending file or mismatch values. Run them and confirm red because current validation exits 0 for all three mutations.
  4. Implement Case E by removing the Codex manifest in the disposable copy; require a `[manifest-version]` diagnostic and no `Traceback`. Run it and confirm red even though existing check 1 also fails, because check 1 does not emit the marker.
  5. Make the harness executable and run all cases once. Confirm each failure is an unmet check-7 assertion, not a harness error, and confirm no temporary directories remain.
  6. Commit only `scripts/test-manifest-version-sync.sh` with message `Add red fixtures for manifest version synchronization`.
Acceptance: `bash scripts/test-manifest-version-sync.sh` completes without a harness crash and exits nonzero before check 7 exists; Case A fails only on the absent exact success line, Cases B-D fail because validation still exits 0 or lacks the marker, Case E fails only because the marker is absent, and the run leaves no disposable-copy directory behind.

## U2: Release skill protocol and prepare-only mode
Execution note: skip-test-first
Files:
  Create: skills/release/SKILL.md
  Modify: README.md, .gitignore
  Test: disposable git repositories plus ignored `.release/draft.md` in the real repository
Interfaces:
  Consumes: invocation arguments `[mode:headless] [<explicit-semver>]`; git worktree status; current branch and default branch; previous annotated or lightweight tag; `.claude-plugin/plugin.json`; `.codex-plugin/plugin.json`; optional `CHANGELOG.md`; committed `docs/specs/*.md` and `docs/retros/*.md`; `schemas/headless-contract.md`; `references/question-tools.md`
  Produces: interactive draft plus semver proposal and exact-command USER gate; or `.release/draft.md` plus prepare-only skip report in headless mode; after first-hand approval, one release commit changing `CHANGELOG.md` and both manifests, annotated tag `v<version>` on that commit, and exactly one final terminal signal line: `Release complete — v<version>`, `Release skipped — <reason>`, or `Release failed — <reason>`
Test scenarios:
  happy: a disposable repo with matching `0.1.0` manifests, tag `v0.1.0`, one in-range feature spec, one retro, and one uncovered notable commit produces a draft containing the spec topic, relevant supplement, `0.1.0` backfill, proposed `0.2.0`, and exact gated commands
  edge: a disposable repo with no `docs/specs/` produces `derived from git log — no spec inventory`; a separate disposable repo whose HEAD is tagged `v0.2.0` emits `Release skipped — HEAD already released as v0.2.0` and changes no files, commits, or tags
  error: a disposable repo with manifest values `0.2.0` and `0.1.0` emits `Release failed — manifest version mismatch (.claude-plugin 0.2.0 ≠ .codex-plugin 0.1.0)` before creating `.release/draft.md` or collecting release notes
  integration: run `mode:headless` against the real repo, snapshot `git rev-parse HEAD` and `git tag --list` before and after, require an existing `.release/draft.md` whose final section contains exact commands, and require the last non-empty report line `Release skipped — headless: ceremony requires first-hand consent; draft prepared at .release/draft.md`; Covers S2, S3, S4, S5
Steps:
  1. Write `skills/release/SKILL.md` with frontmatter for `/release` and `$release`, argument parsing, Entry/Exit/Gate contract, and the seven phases Preflight, Collect, Draft, Version, Gate, Execute, Report.
  2. Make Preflight check in this order: git repository, clean worktree, default branch, both manifest files present and parseable with SemVer versions, versions equal, HEAD already tagged, previous-tag discovery, non-empty range, and CHANGELOG/backfill state. Every failure or skip ends with one exact canonical terminal signal and performs no later phase.
  3. Define Collect and Draft literally: enumerate committed in-range specs and retros, create the source inventory, derive feature-language entries from spec Overviews, supplement uncovered notable commits after filtering chore/review noise, include each inventory spec or a gate-visible drop reason, add the spec-less provenance label when applicable, and place any backfilled release below the current release.
  4. Define Version and Gate: propose minor for a pre-1.0 range containing a feature and patch for fixes-only, accept an explicit SemVer argument as the proposal, show one-line justification, full CHANGELOG draft, drop-list, and exact write/bump/validate/commit/tag commands through the blocking-question protocol. State that approval received by another worker is handoff evidence only, never execution authorization.
  5. Define Execute and Report: write the CHANGELOG, update both JSON versions without unrelated reformatting, run `bash scripts/validate.sh`, stage exactly the three release files, create one release commit, create an annotated `v<version>` tag naming draft highlights, verify four-way agreement and source-inventory traceability, and emit the exact last-line terminal signal. On validation or verification failure, do not tag and emit `Release failed — <reason>`.
  6. Define `mode:headless` as Preflight through Version followed by persistence of `.release/draft.md` containing provenance, inventory, drop-list, proposed version, CHANGELOG text, and exact commands; never ask, commit, or tag, and emit the byte-exact prepare-only skip line.
  7. Add `.release/` to `.gitignore` and add a concise `release` row to README.md's skill table. Do not change the documented six-phase `release-loop` lifecycle.
  8. Create the three disposable git scenarios described above and dispatch fresh-context agents that receive only the repo path, `skills/release/SKILL.md`, invocation mode, and expected observable state. For the interactive happy scenario, stop at the displayed USER gate; do not fabricate approval.
  9. Run the real-repo headless smoke. Verify HEAD and the complete tag list are byte-identical before and after, `.release/draft.md` exists but `git status --short` does not list it, and the report's final non-empty line is exact.
  10. Run `bash scripts/validate.sh`; confirm existing checks still pass before roster and signal protection are expanded. Commit `skills/release/SKILL.md`, `README.md`, and `.gitignore` with message `Add prepare-only release ceremony skill`.
Acceptance: all disposable scenarios produce the specified gate, provenance, failure, or skip behavior; the real headless smoke creates only ignored `.release/draft.md`, leaves HEAD and tags unchanged, and ends with the exact headless skip signal; `bash scripts/validate.sh` exits 0; the commit contains only the three named tracked files.

## U3: Release contract, signal drift, and manifest-sync validation
Execution note: test-first
Files:
  Create: none
  Modify: schemas/headless-contract.md, scripts/test-signal-drift.sh, scripts/validate.sh
  Test: scripts/test-signal-drift.sh, scripts/test-manifest-version-sync.sh
Interfaces:
  Consumes: canonical release signals quoted in `skills/release/SKILL.md`; headless-contract v1 table; both plugin manifest JSON files; existing check-6 producer tuple, consumer list, candidate regex, producer-key mapping, and canonical-count invariant
  Produces: additive `release` row in headless-contract v1; signal-drift Case H; 13-skill roster validation; check 6 coverage for 12 canonical signals across four producer skills; check 7 with exact clean output `ok:   plugin manifest versions agree: <version>` and `[manifest-version]` failures for absent files, unreadable or invalid JSON, missing or non-SemVer versions, and unequal versions
Test scenarios:
  happy: unchanged repo with both versions `0.1.0` passes check 7, validates `skills/release/SKILL.md` frontmatter, parses 12 pairwise-distinct canonical signals, and ends `ALL CHECKS PASSED`
  edge: manifest fixture Case C (missing field) and Case D (non-SemVer value) fail independently and name `.codex-plugin/plugin.json`; the contract parser accepts the additive release row without changing contract version v1
  error: manifest fixture Case B reports both mismatched values; Case E names the absent manifest without a traceback; signal fixture Case H mutates one byte after the intact `Release complete` keyword and reports `skills/release/SKILL.md:<computed-line>` under `[signal-drift]`
  integration: `bash scripts/test-manifest-version-sync.sh`, `bash scripts/test-signal-drift.sh`, and direct `bash scripts/validate.sh` all exit 0 after implementation; Covers S3 and contract protection used by S1, S4, S5
Steps:
  1. Add Case H to `scripts/test-signal-drift.sh`. Locate the unique quoted `Release complete — v<version>` span in the copied skill, compute its line from the copied content, mutate one byte in `<version>` while leaving `Release complete` intact, and assert nonzero validation plus `[signal-drift]` and `skills/release/SKILL.md:<computed-line>`. Run the case and confirm red because current check 6 ignores `release`.
  2. Re-run `scripts/test-manifest-version-sync.sh` before editing validation. Confirm Case A lacks the exact success line, Cases B-D either exit 0 or lack `[manifest-version]`, and Case E lacks `[manifest-version]` even though JSON check 1 also fails.
  3. In `schemas/headless-contract.md`, change the version-rule sentence so changes to existing rows or semantics require a bump while an added producer row is additive, retain `v1`, and add exactly `Release complete — v<version>`, `Release skipped — <reason>`, and `Release failed — <reason>` without modifying existing rows.
  4. Extend check 6 in `scripts/validate.sh` through all five coordinated sites: add `release` to the producer tuple, add `skills/release/SKILL.md` to consumer files, add `Release` to the candidate state regex, map `release` to producer key `release`, and change both canonical-count expectations from 9 to 12 while retaining the pairwise-distinct requirement.
  5. Add `release` to `EXPECTED_SKILLS`. Append check 7 using a Python block that reads each manifest once, reports `[manifest-version]` failures without traceback, validates that `version` is a SemVer 2.0.0 string, compares the two valid values, prints both paths and values on mismatch, and prints exactly `ok:   plugin manifest versions agree: <version>` only when both are valid and equal.
  6. Run the manifest fixture harness and require Cases A-E plus the aggregate summary to pass. Run the signal fixture harness and require Cases A-H plus its aggregate summary to pass.
  7. Run `bash scripts/validate.sh` directly and require `skills/release/SKILL.md frontmatter valid`, the 12-signal check-6 success line, the exact check-7 success line, and trailing `ALL CHECKS PASSED`.
  8. Compare `schemas/headless-contract.md` against its pre-unit version and confirm the diff contains only the version-rule clarification and release row. Commit the three modified files with message `Protect release signals and manifest version agreement`.
Acceptance: both fixture harnesses exit 0 with all named cases passing; direct validation exits 0 with the 13-skill roster and check 7 success; a saved diff proves existing contract rows and signals did not change; the commit contains only the three named files.

## U4: Integrate the skill and cut local v0.2.0
Execution note: skip-test-first
Files:
  Create: CHANGELOG.md
  Modify: .claude-plugin/plugin.json, .codex-plugin/plugin.json
  Test: scripts/validate.sh, scripts/test-signal-drift.sh, scripts/test-manifest-version-sync.sh
Interfaces:
  Consumes: reviewed feature commits that create `skills/release/SKILL.md` and `scripts/test-manifest-version-sync.sh` and modify `.gitignore`, `README.md`, `schemas/headless-contract.md`, `scripts/test-signal-drift.sh`, and `scripts/validate.sh`, integrated onto clean local `main`; previous tag `v0.1.0`; committed specs and retros in `v0.1.0..HEAD`; first-hand user decisions for local feature integration and the release gate
  Produces: one local release commit changing exactly `CHANGELOG.md` and both manifests; annotated tag `v0.2.0` targeting that commit; four-way version value `0.2.0`; zero unaccounted in-range specs; terminal signal `Release complete — v0.2.0`; an immediate re-run signal `Release skipped — HEAD already released as v0.2.0`
Test scenarios:
  happy: interactive invocation on clean main inventories `v0.1.0..HEAD`, proposes `0.2.0`, receives first-hand approval, commits the three release files, creates annotated tag `v0.2.0`, and reports four-way agreement
  edge: absent CHANGELOG triggers a concise `0.1.0` backfill below the new `0.2.0` section; every in-range spec appears in the new section or in an explicit drop note; immediate re-run skips with no new commit or tag
  error: if feature integration is not approved, main is dirty, validation fails, a manifest is invalid or mismatched, or the release gate is not approved, stop before creating the release commit or tag and report the blocking state without bypassing it
  integration: `dogfood v0.2.0 from v0.1.0..HEAD lifecycle inventory` executes the real gate-to-commit-to-tag path and its idempotent re-run; Covers S1, S2, S4
Steps:
  1. After the release skill, manifest fixture, contract, drift fixture, and validation changes pass their individual reviews, run an extra full feature-branch review against the approved spec and this plan's Scenario coverage map. Run all three validation commands on the branch and require clean results.
  2. Return control to the user-facing orchestrator, present the exact local merge command, and obtain first-hand authorization to integrate the feature branch onto `main`. After authorized integration, run the three validation commands again on merged `main`, then remove only the feature worktree and branch created for this implementation.
  3. Record the pre-release HEAD, complete tag list, both manifest versions, and `git status --short`; require clean local `main`. Invoke the new `release` skill interactively without an explicit version.
  4. Build the current source inventory from unique committed spec paths in `v0.1.0..HEAD`, draft `0.2.0` feature-level entries plus explicit drop reasons, draft the `0.1.0` backfill from its committed design and release retro, and present the proposal, full CHANGELOG, drop-list, and exact commands at the release USER gate.
  5. On first-hand approval, write `CHANGELOG.md`, change only each manifest's `version` value to `0.2.0`, run all three validation commands, stage exactly those three files, and verify the staged diff contains no other path before committing with message `Release v0.2.0`.
  6. Create annotated tag `v0.2.0` on the release commit with a message containing the version and approved highlights. Do not push the commit or tag.
  7. Compare the two manifest values, the newest `CHANGELOG.md` version heading, and the dereferenced newest tag; require all values to equal `0.2.0` and require `git rev-parse v0.2.0^{}` to equal HEAD.
  8. Walk every unique spec path committed in `v0.1.0..HEAD`; require its topic in the `0.2.0` CHANGELOG section or an explicit drop note. Require zero unaccounted paths, verify the annotated tag message, and emit `Release complete — v0.2.0` as the last non-empty line.
  9. Invoke `release` once more without changing the tree. Require unchanged HEAD and tag list plus final line `Release skipped — HEAD already released as v0.2.0`.
  10. Run the final integrated review over the feature integration and release commit, re-walk S1-S5 against the actual evidence, and fix no finding by rewriting the immutable release tag; any release-artifact defect requires an explicit user-approved corrective release procedure.
Acceptance: local `main` is clean at a release commit whose only file changes are `CHANGELOG.md` and the two manifests; annotated tag `v0.2.0` dereferences to that commit; all three validation commands exit 0; the four compared version sources equal `0.2.0`; every in-range spec is present or explicitly dropped; the first invocation ends `Release complete — v0.2.0`; the immediate re-run leaves HEAD and tags unchanged and ends with the exact already-released skip signal; no push or GitHub release occurs.

## Deferred to Follow-Up Work

- Git push and GitHub release creation. Live planning found `origin` now exists,
  so the approved trigger has fired; start a new designing cycle to specify
  capability checks, release-body reuse, publication gates, and failure
  recovery before adding outward actions.
- ROADMAP shipped-candidate cleanup, trigger marking, carry-forward removal,
  and next-version section management. The approved spec assigns these to the
  next release-skill iteration after the mechanical ceremony proves out.
- A generalized tag-target rule for retroactive releases. This skill always
  tags its own release commit.
- A persistent CHANGELOG `Unreleased` section. This repository continues to
  treat specs and retros as the in-flight record.

## Open unknowns

**Planning-time**: none. The user confirmed that the plan includes the real,
first-hand-gated `v0.2.0` dogfood unit. The discovered remote does not reopen
scope because the approved spec explicitly defers outward publication; this
plan records the fired trigger instead of implementing it.

**Implementation-time**:

- Exact CHANGELOG prose, section assignment (`Added`, `Changed`, `Fixed`), and
  inventory drop reasons depend on the committed artifacts present when U4
  runs. They are produced before the USER gate and become fixed only when the
  user approves the draft.
- The annotated tag's highlight bullets are derived from the approved
  CHANGELOG draft. The tag must name `v0.2.0` and include the approved major
  highlights, but their final wording is intentionally release-content
  dependent.
- The feature-branch name and isolated-worktree path are selected by
  `worktree-isolation` at implementation start; neither changes file ownership,
  unit order, or the two first-hand approval boundaries defined above.
