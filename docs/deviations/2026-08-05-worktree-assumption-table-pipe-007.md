# Deviation Addendum 007: Worktree Assumption Table Pipe

_Recorded 2026-08-05 during PR #4 review, before merge._

## Original contract

The approved specification and sealed plan retain one assumption command.
The command searches for the current worktree policy and its old conditional wording.

Both approved artifacts store this command inside a Markdown table:

```text
rg -n "worktree-isolation|isolation is wanted" skills/release-loop/SKILL.md
```

## Discovered contradiction

PR #4 review found that the raw pipe character splits the Markdown table row.
`markdownlint-cli2` reports MD056 because the row has one extra column.

The shell command remains valid outside Markdown.
Its persisted evidence shape is not valid table content.

## Decision

Preserve the approved specification and sealed plan as historical records.
Use this corrected command for future assumption rechecks:

```text
rg -n -e "worktree-isolation" -e "isolation is wanted" skills/release-loop/SKILL.md
```

The corrected form has no raw table pipe.
It preserves the original two search alternatives.

## Necessity

Editing the approved plan body would break its body seal.
Re-sealing outside interactive deepening would erase the approval boundary.

The addendum preserves approval history and supplies a valid operational command.
This follows the existing assumption-evidence correction pattern in Addendum 002.

## Observable behavior

No release-loop runtime behavior changes.
Future planning and review runs use the corrected two-pattern command.

## Safety and consent boundaries

The corrected command reads one tracked file.
It performs no file mutation, network request, branch change, push, or merge.

This addendum grants no execution authority.
Existing worktree and merge gates remain unchanged.

## Verification changes

- Run the corrected command and require both intended search patterns.
- Treat the approved table row as historical evidence, not a reusable command shape.
- Verify this addendum renders without a raw pipe inside its table content.

## Traceability

- Approved specification: `docs/specs/2026-08-05-default-worktree-isolation-design.md`.
- Approved plan: `docs/plans/2026-08-05-001-feat-default-worktree-isolation-plan.md`.
- Review comment: PR #4 comment `3717915000`.
- Correction precedent: `docs/deviations/2026-07-19-python-gate-assumption-evidence-002.md`.
- Addendum authority: `docs/solutions/workflow-issues/review-introduced-state-machine-deviation.md`.
