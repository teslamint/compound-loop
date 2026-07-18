# Retro: process-guidance carry-forward items 1 and 2

- Date: 2026-07-18
- Source: ad-hoc (shared process-guidance arc merged as `5edec91`)
- Spec: `docs/specs/2026-07-18-approved-artifact-truth-maintenance-design.md`; `docs/specs/2026-07-18-stateful-ceremony-failure-matrix-design.md`
- Plan: `docs/plans/2026-07-18-001-docs-approved-artifact-truth-maintenance-plan.md`; `docs/plans/2026-07-18-002-docs-stateful-ceremony-failure-matrix-plan.md`

## Release data

| Metric | Value |
|---|---|
| Code delta (product / test / docs) | +174/-32 (`skills/`, `schemas/`) / +0/-0 / +796/-0 (`docs/`) over `21eb4db..5edec91` |
| Commits | 20, including merge commit `5edec91` |
| Review rounds | 17 evidence-bearing passes: item 1 10; item 2 7 |
| Comments (fixed / deferred) | 11 / 0 actionable findings; no PR comments |
| CI failures | n/a — no `.github/workflows` exists; repo validation passed |
| Duration (first spec commit → merge) | 1h32m22s (`5ae864b` 18:53:42 → `5edec91` 20:26:04) |
| Units planned / completed | 6 / 6 across two three-unit plans |

The 17 review passes were reconstructed from the narrative ledger rather than
its current-phase counters: item 1 used spec initial/re-review, external plan,
U1, U2 initial/re-review, U3 initial/re-review, and branch initial/re-review
(10); item 2 used spec initial/re-review, U1 initial/re-review, U2, U3, and
final branch review (7). The 11 fixes comprise six pre-draft spec-review
findings recorded as two blockers plus one minor per spec, two external
findings fixed by `e6c01bd` and `3fb6aa6`, and three internal unit/branch
findings fixed by `c23124f`, `776108c`, and `beb405b`. The progress schema's
`feedback_rounds` and comment counters are shipping-comment fields; their zero
values do not mean the lifecycle received no review feedback.

## Success criteria: measured vs declared

All 13 criteria were re-measured fresh on merged `main`. For branch-relative
commands that collapse after merge, the declared command was run and paired
with the historical item range that preserves its intended boundary.

| # | Declared criterion | Measurement (command / rubric) | Measured result | Verdict |
|---|---|---|---|---|
| I1-1 | Live assumptions have durable design evidence and fresh planning rechecks | `rg -n "Live assumption evidence|Assumption Recheck" skills/designing/SKILL.md skills/designing/references/spec-template.md skills/planning/SKILL.md schemas/plan-schema.md` | Found the five-field design rule/template and always-present planning/schema Assumption Recheck contract | Met |
| I1-2 | Contradictions preserve approved artifacts and require a committed addendum before plan finalization | Reviewer rubric over `skills/planning/SKILL.md` and `schemas/plan-schema.md` | Both require rerunning retained commands, preserving the approved source, and blocking finalization and commit until a separate addendum exists | Met |
| I1-3 | Review-introduced observable behavior cannot pass review without a committed addendum | `rg -n "deviation addendum|observable behavior" skills/implementing/SKILL.md skills/reviewing/SKILL.md`; inspect the release-recovery example | Both skills block acceptance/clean; the solution classifies incomplete release recovery as addendum-required | Met |
| I1-4 | Promote rather than duplicate generalized addendum guidance | Search lifecycle consumers for `review-introduced-state-machine-deviation.md` and scan for the seven-part list outside its authority/addendum | Designing, planning, implementing, reviewing, and schema link the authority; no lifecycle consumer restates its seven-part list | Met |
| I1-5 | Structural and terminal-signal contracts remain valid | `bash scripts/validate.sh` | Exit 0; all skill, schema, principle, signal, and manifest checks passed | Met |
| I1-6 | Item 2 remains independently designable | `git diff 21eb4db..776108c` plus matrix-protocol phrase scan | Item 1 range contains no required matrix schema or retained forced-failure evidence protocol; item 2 begins afterward | Met |
| I2-1 | Stateful plans have a complete matrix and stateless plans an explicit fallback | `rg -n "Mutation/failure-state matrix|no stateful ceremony|durable transition" skills/planning/SKILL.md schemas/plan-schema.md` | Both surfaces contain the conditional trigger, durable-transition rule, complete-row contract, and exact fallback | Met |
| I2-2 | Every transition accounts for all six outcomes with no unexplained blanks | Reviewer rubric over planning/schema and `stateful-ceremony-matrix-example.md` | Five transition rows each contain success, forced failure, rerun, rollback/compensation, headless, and cancellation/abort; blanks are banned and not-applicable needs a reason | Met |
| I2-3 | Unit review requires retained disposable fixture evidence | `rg -n "release-loop/evidence|fixture evidence|cannot pass" skills/implementing/SKILL.md skills/reviewing/SKILL.md` | Evidence production/path and task/final handoffs are present; missing applicable cells or records block clean | Met |
| I2-4 | Example covers commit → verify → tag and publication partial states without changing release behavior | Inspect the five reference rows; `git diff 776108c..5edec91 -- skills/release/SKILL.md` | Rows cover release commit, pre-tag verification, annotated tag, partial commit/tag publication, and release-page publication; release skill diff is empty | Met |
| I2-5 | Evidence proves intended failure/post-state without reaching a real system | Search implementing/reviewing for fixture identity/root, target inventory, sentinel, injection, exit, post-state, and mechanism check | Every required field and real-target prohibition is present in producer and reviewer guidance | Met |
| I2-6 | Structural and terminal-signal contracts remain valid | `bash scripts/validate.sh` | Exit 0 with `ALL CHECKS PASSED` | Met |
| I2-7 | ROADMAP bookkeeping remains unchanged during implementation | `git diff main...HEAD -- ROADMAP.md`; `git diff --name-only 776108c..5edec91 -- ROADMAP.md` | Both exact post-merge and stronger historical checks are empty | Met |

## Carry-forward from previous retro

Previous retro:
`docs/retros/2026-07-16-release-skill-v0.2.0-retro.md`. The table also
accounts for the other open ROADMAP rows inherited from earlier retros so none
are silently dropped.

| Item | Status | Evidence |
|---|---|---|
| Approved-artifact truth maintenance | Done | All six item 1 criteria pass on merged main; implementation commits `0aee977`, `da06299`, `3fb6aa6`, `0bd1049`, `c23124f`, and `776108c`; remove the delivered ROADMAP row |
| Mutation/failure-state matrix for stateful ceremonies | Done | All seven item 2 criteria pass; example and contracts shipped in `aa87598`, `beb405b`, `a13c816`, and `ce73f8f`; remove the delivered ROADMAP row |
| Gated outward publication automation for `release` | Not started | The arc left `skills/release/SKILL.md` unchanged and added no outward automation; keep the row |
| Second qualifying larger-feature pilot | Not started | This shared arc had six units but two separate three-unit plans and one review lane, so it met neither one 5+ unit plan nor 2+ conditional review lanes; keep the row |
| Diff-size metric reconciliation across phases | Not started | Exact ranges in this retro are measurement hygiene; no cross-phase metric contract was added to skills or schemas; keep the row |
| Clean-environment Codex install check | Not started | No external or isolated Codex installation was exercised; keep the row |

## Findings

### What worked well

- **What happened**: All 13 declared criteria passed fresh on merged main, and
  the two prior P2 gaps now have implementation, example, and review evidence.
  **Why**: Both specs bound every criterion to an executable command or an
  explicit reviewer rubric, while the branch preserved item-specific ranges.
  **How to apply**: Remove delivered carry-forward rows only after replaying
  their declared measurements against the merged tree.

- **What happened**: Deviation addendum 001 became the rule's first live use:
  external plan review found that approved spec `fd9e211` omitted an
  always-present Assumptions section, `e6c01bd` committed the addendum and plan
  revision, and only then did `57bad80` approve the plan.
  **Why**: The workflow preserved the approved spec while separating the later
  operational contract from historical approval truth.
  **How to apply**: When review expands observable behavior, commit the
  addendum before the next approval or implementation step rather than
  rewriting the approved artifact or documenting the drift afterward.

- **What happened**: Item 2 U2 did not repeat item 1 U2's eight stale
  cross-references: external feedback about `3fb6aa6` was converted into a
  whole-surface same-commit audit in `a13c816` covering planning steps 1–18,
  schema items 1–9, and every planning reference file.
  **Why**: Feedback arrived before the analogous edit and was copied into the
  unit brief and self-review instead of being left as retrospective advice.
  **How to apply**: Route a defect-class lesson into the next affected unit's
  acceptance checks immediately; then automate it if general validation still
  cannot detect the class.

### What to improve

- **What happened**: `da06299` passed structural validation while leaving eight
  stale ordinal references, requiring follow-up `3fb6aa6`.
  **Why**: Existing validation checks syntax, manifests, principles, and signal
  contracts but does not resolve `step N` prose against numbered headings or
  schema lists.
  **How to apply**: Add a P3 validator before the next numbered planning-step
  or schema hard-floor insertion; prefer semantic section names and validate
  any remaining number/title pair.

- **What happened**: The runtime ledger frontmatter ended with
  `review_rounds: 2`, `feedback_rounds: 0`, and zero comment counters although
  the narrative evidence reconstructs 17 lifecycle review passes and 11
  fixed findings.
  **Why**: Those scalar fields serve current review-cap or shipping-comment
  state, not an aggregate retrospective metric; reading them without the
  narrative log undercounts lifecycle evidence.
  **How to apply**: Retros should reconstruct aggregate rounds/findings from
  stage records and state explicitly when progress counters have narrower
  semantics.

### Process observations

- **What happened**: External review supplied two implemented findings
  (`e6c01bd`, `3fb6aa6`), while internal unit/branch review supplied three
  fixes (`c23124f`, `776108c`, `beb405b`); none were deferred.
  **Why**: External review was strongest at standing-contract and fan-out
  consistency, while internal review tested artifact discovery, execution-type
  verification, and live headless semantics.
  **How to apply**: Keep the two review sources distinct in evidence; their
  different scopes caught different failure classes.

- **What happened**: The deviation check required only addendum 001.
  `c23124f` and `776108c` align internal discovery/verification with approved
  contracts without changing interfaces, durable state, persistence, consent,
  or terminal behavior; `beb405b` corrects the example to already-approved
  live headless behavior.
  **Why**: The solution's boundary-based exemption distinguishes operational
  contract expansion from internal consistency repair.
  **How to apply**: Classify each review fix independently against the five
  observable boundaries; do not create addenda for corrections that introduce
  no new behavior, and do not use the exemption to hide an artifact-interface
  expansion like the always-present section.

## Carry-forward items registered

| Item | Type | Priority | Tracked at |
|---|---|---|---|
| Automated numbered-reference validation for planning and plan schema: prove contiguous heading/list numbering and resolve planning-step references across the primary skill and every reference file | process | P3 | ROADMAP.md § Carry-forward from retros |

## Lessons

- A deviation rule is real only when the first inconvenient expansion is
  recorded before approval and implementation, not summarized after shipping.
- Position-dependent prose is a hidden dependency graph: when one numbered
  heading moves, audit every consumer in the same change.
- A green structural validator can coexist with semantically false guidance;
  repeated manual audit is evidence for a new automated invariant.
- Review counters describe their workflow phase, not necessarily the whole
  arc; retrospective totals need stage-level evidence.

## Compounding

- compound invocation: `Documentation complete — docs/solutions/workflow-issues/numbered-planning-step-reference-drift.md`
