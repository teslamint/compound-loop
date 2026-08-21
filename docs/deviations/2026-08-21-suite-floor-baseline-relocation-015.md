# Deviation Addendum 015: Suite-Floor Baseline Relocation for Instruction Payload Slimming

_Recorded 2026-08-21 during implementing pre-flight (U1), before any cycle edit to `skills/` or `scripts/`._

## Original contract

The approved plan (`docs/plans/2026-08-21-001-refactor-instruction-payload-slimming-plan.md`, sealed) U1 runs `bash scripts/validate.sh` and each of the twelve `scripts/test-*.sh` in a worktree at baseline `f2efda9` and records their totals as SC4 floors; its error scenario stops the cycle when a suite fails at baseline. The approved spec's Testing section requires the full suite green at every commit, and Addendum 014 fixed the baseline revision at `f2efda9`.

## Discovered state

U1's dispatched implementer ran all thirteen suites in a worktree at `f2efda9` and reported BLOCKED: three suites fail there. All three reproduce identically at the pre-cycle HEAD (`4851d20`), and all three are regressions from earlier cycles, unrelated to this one:

1. `scripts/test-plan-frontmatter.sh` Case 20 — asserted rejection of `execution: ops` after `0b09ae9` legitimately added `ops` to the validator enum.
2. `scripts/test-planning-schema-portability.sh` schema-byte-parity — the byte-exact schema move commit (`ac8ef7e`) became unreachable from HEAD's first-parent walk when PR #16 squash-merged it into `add8bc3` together with seal edits.
3. `scripts/test-release-publication.sh` local-section regression — pinned to the `1a02283` hash of `skills/release/SKILL.md` after `0b09ae9` legitimately changed that section.

## Necessity

The three failures predate the cycle; no revision this cycle could choose as its skills-text baseline is suite-green, and waiving them would leave the repository red and the SC4 floors meaningless for three suites.

## Repair (user-approved at the 2026-08-21 implementing gate)

The three suites were repaired on `main` before any cycle edit, each aligning the test with its shipped contract: `457043d` (Case 20 rejects an out-of-enum value), `b57cbc4` (schema-byte-parity accepts exactly the recorded PR #16 squash blob pair, general parity retained for future moves), `0a64fc1` (release local-section hash re-pinned to the `0b09ae9` base).

## Observable behavior

No skill text or runtime behavior changes. This addendum splits the plan's single baseline into two anchored roles:

- **Skills-text baseline: `f2efda9`, unchanged.** R7's diff base, R5 clause comparisons, SC3's description baseline, and all M-block byte figures stay exactly as Addendum 014 fixed them.
- **Suite-floor baseline: `0a64fc1`** (= `f2efda9` plus docs/plan commits and the three test repairs; zero `skills/` changes — proof: `git diff f2efda9..0a64fc1 --stat -- skills/` is empty). U1 runs the thirteen suites in a worktree at `0a64fc1` and records those totals as the SC4 floors; byte figures measured there equal `f2efda9`'s because `skills/` is identical.

U1's step 1 command therefore reads `BASE=f2efda9` for byte extraction and `SUITE_BASE=0a64fc1` for suite runs (one worktree at `0a64fc1` serves both, given the equality proof). `scripts/test-python-compatibility.sh` is invoked as `bash scripts/test-python-compatibility.sh all` (bare invocation exits 2 with usage).

## Safety and consent boundaries

Test repairs and this addendum authorize no outward action. User approval was given first-hand at the implementing gate on 2026-08-21 (option: "main에서 3건 수리 + Addendum 015").

## Verification changes

- U1 acceptance additionally records the equality proof output (`git diff f2efda9..0a64fc1 --stat -- skills/` → empty).
- SC4's floors are the `0a64fc1` totals; the three repaired suites' floors are their green totals (Case count unchanged for test-plan-frontmatter; 18 checks for schema portability, one more than the red run reported passing; 100/100 for release publication).
- All other plan text and Addendum 014 remain in force.

## Traceability

- U1 BLOCKED report: `.release-loop/reports/U1-report.md` in the cycle worktree (three named failures, ten green suites).
- Reproduction at pre-cycle HEAD: first-hand runs on 2026-08-21 (`1 case(s) FAILED`; `17 checks passed, 1 failures`; `passed=99 failed=1`), repaired runs green (`ALL CASES PASSED`; `18 checks passed, 0 failures`; `passed=100 failed=0`), `bash scripts/validate.sh` → `ALL CHECKS PASSED` at `0a64fc1`.
- Repair commits: `457043d`, `b57cbc4`, `0a64fc1`.
- Authority for this artifact shape: `docs/solutions/workflow-issues/review-introduced-state-machine-deviation.md`.
