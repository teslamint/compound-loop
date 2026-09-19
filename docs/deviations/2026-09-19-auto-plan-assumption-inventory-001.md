# Deviation Addendum 001: Auto-plan Inventory Recheck

_Recorded 2026-09-19 during Plan preparation._

## Original contract

The approved design at
`docs/specs/2026-09-19-auto-plan-assumption-tradeoffs-design.md`
records a live assumption that the repository contains `27` tracked spec files
and `29` tracked plan files. The evidence command counts both glob sets with
`git ls-files`.

## Discovered contradiction

The planning Assumption Recheck reran that command exactly at
`2026-09-19T13:50:38Z`. It returned `spec_count=28` and `plan_count=29`.
The additional spec is the approved origin artifact itself, which this release
loop committed after the design measurement. The approved count was a
pre-feature inventory, while the identical command now includes the new spec.

A bounded follow-up command at `2026-09-19T13:51:10Z` returned
`tracked_spec_count=28; excluding_origin=27`, using the exact origin path as the
only exclusion. The pre-feature claim therefore remains reproducible, but the
unqualified recheck command is no longer a stable comparison after artifact
creation.

## Necessity

Planning cannot mark the retained claim as an unqualified match after the
identical command changes. The approved spec must remain unchanged, and the
plan must preserve the contradiction rather than silently reinterpret the
measurement. The addendum records the artifact-count lifecycle and supplies a
bounded comparison for this plan.

## Observable behavior

No product, skill, validator, terminal-output, or compatibility behavior
changes. The planning record gains one explicit contradiction classification and
one origin-aware evidence command. Historical specs and plans remain untouched.

## Safety and consent boundaries

The commands read tracked paths only. They perform no network access, file
mutation, credential access, or outward action. The design approval and the
implementation-deferred stop condition remain unchanged.

## Verification changes

- The plan's Assumption Recheck records the original command as `contradiction`
and links this addendum.
- The plan records the origin-aware count as planning evidence, not as a rewrite
of the approved design measurement.
- The focused contract harness must continue to reject missing, blank, and
unquantified auto-artifact sections; this addendum does not weaken those checks.
- Repository validation remains required before the draft plan commit.

## Traceability

- Approved spec: commit `44ae6f2c938624bd29ba1c92ef5b2322bd5b1df6`.
- Contradictory retained command: Assumptions and Preconditions row 2 in the
approved spec.
- Planning recheck: first-hand run at `2026-09-19T13:50:38Z`.
- Corrected bounded evidence: origin-aware count at `2026-09-19T13:51:10Z`.
- Authority for this artifact shape:
`docs/solutions/workflow-issues/review-introduced-state-machine-deviation.md`.
