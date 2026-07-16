# Retro: release skill v0.2.0

- Date: 2026-07-16
- Source: ad-hoc (release-skill arc; no PR, released as `v0.2.0`)
- Spec: docs/specs/2026-07-16-release-skill-design.md
- Plan: docs/plans/2026-07-16-002-feat-release-skill-plan.md

## Release data

| Metric | Value |
|---|---|
| Code delta (product / test / docs) | +580/-10 / +277/-0 / +467/-0 over `48b8151..c3cbf01` |
| Commits | 17, including the integration merge and release commit |
| Review rounds | 12 (plan 1; U1 2; U2 3; U3 2; full-branch 3; U4 1) |
| Comments (fixed / deferred) | 20 / 0 actionable findings or scenario defects; no PR comments |
| CI failures | n/a — no `.github/workflows` exists |
| Duration (first spec commit → merge) | 2h39m54s (`76cd2af` 11:14:23 → `757249e` 13:54:17); 4h23m25s through release commit `c3cbf01` |
| Units planned / completed | 4 / 4 |

The local release state was measured fresh: `c3cbf01` is `Release v0.2.0`,
the annotated tag dereferences to that commit, and both manifests plus the
newest CHANGELOG section are `0.2.0`. Outward publication is recorded complete
from the user's first-hand status report: `main` and `v0.2.0` were pushed, and
the [GitHub release](https://github.com/teslamint/compound-loop/releases/tag/v0.2.0)
was created from the `0.2.0` CHANGELOG section. GitHub state was not
independently refreshed in this run: `git ls-remote`, `gh release view`, and
the web fetch could not reach GitHub.

## Success criteria: measured vs declared

All seven criteria were re-measured fresh. The headless criterion was run in a
scratch clone at the integrated pre-release commit `757249e`, because current
`HEAD` is already tagged and correctly takes the already-released skip path.

| # | Declared criterion | Measurement (command / rubric) | Measured result | Verdict |
|---|---|---|---|---|
| 1 | `scripts/validate.sh` passes with the 13-skill roster, including `release` frontmatter | `bash scripts/validate.sh` | Exit 0; included `ok:   skills/release/SKILL.md frontmatter valid`, 12 pairwise-distinct signals, manifest agreement `0.2.0`, and `ALL CHECKS PASSED` | Met |
| 2 | Manifest drift is caught for a mismatch and a missing `version`, naming the offending file | `bash scripts/test-manifest-version-sync.sh` | Cases A-E and aggregate passed; Case B proved mismatch diagnostics and Case C proved missing-field diagnostics correlated with `.codex-plugin/plugin.json` | Met |
| 3 | A one-byte release-signal mutation fails validation naming file and line | `bash scripts/test-signal-drift.sh` | Cases A-H and aggregate passed; Case H exercised the computed `skills/release/SKILL.md:<line>` release mutation | Met |
| 4 | Contract change is additive: prior rows/signals unchanged; only rule clarification and `release` row added | `git diff 918ff57..v0.2.0 -- schemas/headless-contract.md`; `bash scripts/validate.sh` | Diff contains exactly the rule-line clarification and one `release` row; check 6 passes with 12 signals | Met |
| 5 | `v0.2.0` is cut with four-way version agreement | Fresh Python comparison of both manifest values, first CHANGELOG version heading, `git describe --tags --abbrev=0 HEAD`, and `git rev-parse 'v0.2.0^{}'` | All four values are `0.2.0`; annotated tag target equals `HEAD` | Met |
| 6 | Every spec committed in `v0.1.0..HEAD` appears in the `0.2.0` CHANGELOG section or an explicit drop note | Fresh inventory from `git log --name-only --format= v0.1.0..HEAD^ -- docs/specs`, then topic checks against the current CHANGELOG section | Inventory is exactly the release-skill and signal-drift specs; both topics are represented; unaccounted list is empty | Met |
| 7 | Headless invocation prepares but does not execute | Fresh `$release mode:headless` in a scratch clone at `757249e`; compare HEAD, full tag refs, status; verify ignored draft and terminal bytes | HEAD/tag refs/status unchanged; `.release/draft.md` exists and is ignored; last Markdown H2 is `## Exact commands`; exact last line was `Release skipped — headless: ceremony requires first-hand consent; draft prepared at .release/draft.md` | Met |

## Carry-forward from previous retro

Previous retro:
`docs/retros/2026-07-16-v0.1-release-retro.md`. All four registered
items are accounted for.

| Item | Status | Evidence |
|---|---|---|
| Second pilot on a larger feature (5+ units, or 2+ conditional review lanes) to exercise multi-agent dispatch tiers | Not started | The plan explicitly states this four-unit feature did not meet the qualifying threshold (`docs/plans/2026-07-16-002-feat-release-skill-plan.md:92-95`). Subagents and per-unit reviewers were used, but that does not satisfy the declared larger-feature pilot |
| Diff-size metric reconciliation across phases | Not started | Fresh search found no implementing guidance in `skills/` or `schemas/`; using one named range in this retro is measurement hygiene, not the requested cross-phase contract |
| Clean-environment Codex install check for plugin-native discovery | Not started | No external or isolated Codex installation was exercised during this arc |
| Traceability criterion for inventory-derived releases | Done | Spec criterion 6, the release draft mapping/drop-list, `CHANGELOG.md`, and the fresh inventory measurement account for both in-range specs with zero drops; the ROADMAP row can be removed |

## Findings

### What worked well

- **What happened**: All seven declared criteria passed fresh, including a new
  historical headless run at `757249e`, the real `v0.2.0` release commit/tag,
  and a zero-unaccounted inventory walk.
  **Why**: The spec paired every criterion with an executable measurement, and
  the release plan preserved a pre-release commit where the prepare-only path
  could still be reproduced after the final tag existed.
  **How to apply**: Keep historical state identifiers in release plans so a
  retro can re-run state-sensitive criteria rather than citing old output.

- **What happened**: Twelve independent review rounds fixed 20 actionable
  findings without deferring any, including remote-less default-branch
  detection (`e983949`), inventory preservation (`96d2e7c`), ASCII-only SemVer
  (`3642ae2`), fail-fast packets (`640bb59`), and recovery/subject consistency
  (`420483a`).
  **Why**: Unit reviewers, parallel disposable scenarios, and full-branch
  review examined different boundaries; the later findings were cross-step
  hazards, not duplicate reviewer opinion.
  **How to apply**: Preserve layered review, but move transition-state analysis
  and forced-failure packet execution into planning and unit acceptance so the
  full-branch gate verifies coverage instead of discovering the state model.

- **What happened**: The v0.1 carry-forward for inventory traceability was
  exercised by the release itself: the two-spec source inventory was mapped
  into the `0.2.0` CHANGELOG with an explicit empty drop-list.
  **Why**: The prior retro pushed a content-fidelity gap into a durable tracker,
  and the release-skill spec promoted it to criterion 6 rather than leaving it
  as narrative guidance.
  **How to apply**: Close carry-forward only with the released artifact and a
  fresh measurement; remove the ROADMAP row once both exist.

### What to improve

- **What happened**: `skills/release/SKILL.md` Preflight step 7, **Incomplete
  release recovery**, was in neither the approved spec's seven-phase
  architecture nor the plan's U2 Preflight list. Full-branch review exposed
  that a failed post-commit check or tag command can leave an untagged release
  commit; `640bb59` and `420483a` added gated tag/revert recovery.
  **Why**: The design modeled the happy transition from commit to tag but not
  the durable intermediate state. Some invariants require an actual commit,
  and tag creation itself can fail, so moving every check earlier cannot remove
  the state.
  **How to apply**: Preserve the approved spec/plan as historical artifacts,
  record this as a necessary and beneficial implementation deviation, and
  require a committed deviation addendum before release whenever review adds
  an observable state-machine branch.

- **What happened**: Spec Assumption 7 said **No git remote** and claimed the
  assumptions were live-verified, but the plan found `origin` before
  implementation (`docs/plans/2026-07-16-002-feat-release-skill-plan.md:87-91`).
  No durable design-time command output exists, so the exact design-time state
  cannot be reconstructed; the approved assumption was demonstrably stale by
  planning.
  **Why**: The verification result was asserted rather than retained, and the
  planning correction protected scope without correcting or addending the
  approved source artifact.
  **How to apply**: Live assumptions should name command, timestamp, and source;
  planning should rerun them and commit an addendum when reality contradicts
  the approved spec.

- **What happened**: A four-unit arc needed three U2 reviews and three
  full-branch reviews. The costly findings clustered around executable packet
  control flow and the write → validate → commit → verify → tag state machine.
  **Why**: The plan described ordered prose but did not require a
  mutation/failure-state matrix or forced failures at every durable boundary.
  **How to apply**: Require a matrix with success, forced-failure, rerun, and
  headless outcomes for every state transition; unit review passes only after
  retained disposable evidence executes each applicable failure.

### Process observations

- **What happened**: The remote trigger for push/GitHub-release work had fired
  by planning, but the approved local-only scope was preserved. After the local
  release, the user separately authorized and completed publication of
  `v0.2.0`.
  **Why**: Local release correctness and outward publication have different
  capability, consent, idempotency, and recovery boundaries.
  **How to apply**: Record manual `v0.2.0` publication as complete. The deferred
  designing cycle is for automating future outward publication or explicit
  repair, not for publishing `v0.2.0` again.

- **What happened**: The approved spec and plan now intentionally differ from
  the released recovery behavior.
  **Why**: Rewriting approved artifacts after release would erase what was
  actually approved, while leaving the difference undocumented would hide
  implementation drift.
  **How to apply**: Use this retro as the post-approval deviation record for
  this release; add a prospective addendum rule to the lifecycle skills.

- **What happened**: External GitHub state could not be refreshed during this
  retro even though local release measurements were complete.
  **Why**: DNS/network access to GitHub was unavailable.
  **How to apply**: Separate first-hand supplied publication status from fresh
  command evidence in retro wording; never use a local remote-tracking ref as
  independent proof of a push.

## Carry-forward items registered

| Item | Type | Priority | Tracked at |
|---|---|---|---|
| Gated outward publication automation for `release`: v0.2.0 publication is complete; automate future releases or explicit repair with capability checks, a separate first-hand gate, CHANGELOG body reuse, idempotency, and partial-failure recovery | feature | P2 | ROADMAP.md § Carry-forward from retros |
| Approved-artifact truth maintenance: retain command evidence for live assumptions, recheck them in planning, and require a committed addendum when a contradiction or review introduces observable behavior | process | P2 | ROADMAP.md § Carry-forward from retros |
| Mutation/failure-state matrix for stateful ceremonies, with forced-failure fixtures required before unit review passes | process | P2 | ROADMAP.md § Carry-forward from retros |

## Lessons

- A review-discovered safety branch is still scope: if it changes the state
  machine, record a spec/plan deviation before shipping it.
- A trigger can fire and be manually satisfied without its automation existing;
  trackers must distinguish operational completion from product capability.
- “Verified live” is an evidence claim, not prose — if planning cannot inspect
  the command result, the assumption is not durably verified.
- Fewer review rounds are not success by themselves; move defects earlier while
  continuing to report how many the gates discover.

## Compounding

- compound invocation: `Documentation complete — docs/solutions/workflow-issues/review-introduced-state-machine-deviation.md`
