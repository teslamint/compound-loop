# Suppression Policy

A finding matching any category below is a **non-finding** -- suppress it entirely; do not route it to a soft bucket (`testing_gaps`/`residual_risks`) even at a low confidence anchor. This applies to every lane.

## False-positive catalog (8 categories)

1. **Pedantic style a linter/formatter would catch** -- semicolons, indentation, import ordering, unused-variable warnings the project's tooling already enforces.
2. **Code that looks wrong but is intentional** -- check comments, commit messages, PR description, and surrounding code for evidence of intent before flagging.
3. **Issues already handled elsewhere** -- callers, guards, middleware, framework defaults, parallel handlers. If a parent middleware already validates input, a controller-level check the lane wants to add is redundant.
4. **Suggestions restating what the code already does** -- "consider extracting a helper" when it's already a small helper; "consider adding a guard" when a guard one line up already covers it.
5. **Generic "consider adding" advice with no concrete failure mode** -- if you cannot name what breaks, find the failure mode or suppress; don't emit the vague version.
6. **Issues with a relevant lint-ignore comment** -- an explicit suppression (`eslint-disable-next-line`, `# rubocop:disable`, `# noqa`) for the exact rule you're about to flag. The author already chose to suppress; re-flagging via a different lane creates noise, unless the suppression itself violates a project-standards rule that explicitly forbids it for this code shape.
7. **General code-quality opinions not codified in the repo's own standards** -- "this file is getting long," "too many parameters" with no rule in `AGENTS.md`/`CLAUDE.md` anchoring the concern. Codified -> a `standards` finding; uncodified -> suppress.
8. **Speculative future-work concerns with no current signal** -- "this might break under load," "what if requirements change" -- not a finding unless the diff introduces concrete evidence the concern is reachable now.

**Intentional behavior changes that align with the diff's stated intent** are not findings either -- check intent (SKILL.md Step 2) before flagging a deliberate change as a defect.

Pre-existing issues are handled separately, not suppressed: mark `pre_existing: true` for unrelated unchanged code and report it in the dedicated section (`references/lanes.md`'s scope tiers); it never counts toward the verdict.

## Protected artifacts

Never flag any file under these paths for deletion, removal, or gitignoring, by any lane:

- `docs/brainstorms/*`
- `docs/plans/*.md`
- `docs/solutions/*.md`
- `docs/specs/*.md`
- `docs/retros/*.md`

These are compound-loop's own pipeline artifacts -- spec, plan, solution, and retro documents produced by other skills in this plugin. Discard any finding recommending their removal during merge, regardless of which lane raised it.
