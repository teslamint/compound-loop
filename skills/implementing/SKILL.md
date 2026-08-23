---
name: implementing
description: Execute an approved plan to completion with review checkpoints, surviving context loss, on any harness
---

# Implementing

**Entry:** an approved plan file with the standalone `plan/v1` contract, or a bare prompt already triaged Trivial/Small-Medium by the caller.
**Exit:** every Implementation Unit complete, tests passing, final branch review clean (or only Minor findings remain).
**Gate:** AUTO — advances to `reviewing` once every unit passes its review.

## Run artifact scope

When `release-loop` invokes implementing, it supplies one exact repo-relative `progress_path`. Validate that record before using it and require `artifact_root = dirname(progress_path)` to match the ledger's `artifact_root`. A missing, ambiguous, mismatched, symlinked, or out-of-root path blocks before any write. For standalone implementing with an approved plan, validate the approved-plan filename stem against `^[a-z0-9]+(?:-[a-z0-9]+)*$`; use the validated approved-plan filename stem as `plan_filename_stem`, and select `.release-loop/runs/<plan_filename_stem>/progress.md` without requiring a release-loop sibling. An occupied standalone scope resumes only from its matching valid record; every other filesystem or tracked entry blocks.

For standalone implementing, set `implementing_skill_root` to the directory containing this loaded `SKILL.md`. Run `python3 "$implementing_skill_root/scripts/phase-artifact-integrity.py" initialize --repo . --plan <approved-plan-path>` before the first ledger write. Use its returned exact progress path. Publish each standalone sibling with `python3 "$implementing_skill_root/scripts/phase-artifact-integrity.py" publish --repo . --progress-path <repo-relative-progress-path> --source <repo-relative-temporary-path> --target <repo-relative-final-path>`.

Before every first sibling write, invoke the packaged publisher. It rejects a symlink, an outside-root target, and any pre-existing filesystem or tracked target unless the ownership journal records the target and SHA-256 and the final bytes match. A foreign same-byte file without that journal record blocks. A valid legacy active ledger may update itself at its selected path. That exemption never applies to its sibling artifact targets.

## Standalone plan contract

This consumer executes only the plan rules listed here; it does not require the full planning skill or its schema file.

Plan-consumer contract lives in [references/plan-consumer-contract.md](references/plan-consumer-contract.md).

### Shared literals used by implementing

- Schema version literal: `plan/v1`.
- Status literals: `draft | approved | done | superseded`.
- Seal format literal: `64-char lowercase hex SHA-256`.
- Seal extraction literal: `text.split('---', 2)[2]`.

### Eligibility and unit dispatch

The only accepted plan schema is `plan/v1`; a missing or unknown `schema` rejects before execution.
A plan with `status: approved` proceeds to contradiction scanning and unit dispatch.
A plan with `status: draft` rejects with a pending-approval diagnostic.
A plan with `status: done` rejects and names its recorded `completed_by=<SHA>` commit.
A `done` plan missing `completed_by` rejects as a terminal-state validator violation; never invent a commit.
A plan with `status: superseded` rejects and names its `superseded_by=<path>` successor path.
A missing or unknown `status` rejects before any unit is executed.

Each dispatched unit consumes its full handoff: exact values and signatures, `Files`, `Interfaces`, `Test scenarios`, and `Execution note`.
`execution: code` selects the existing code-unit flow.
`execution: non-code` selects the existing non-code-unit flow.

### Approval seal and history

A correctly formatted and matching `body_seal` proceeds after stored-versus-computed comparison.
A malformed or mismatched `body_seal` rejects and reports both `stored=<value>` and `computed=<value>` values.
Compute the comparison from UTF-8 text read with universal-newline translation, then the exact `text.split('---', 2)[2]` extraction, UTF-8 encoding, and lowercase SHA-256 rendering.
An approved plan that was never sealed remains valid when its approval history contains no `body_seal`.
An approved plan whose approval history contained a seal but whose current frontmatter removed it rejects as a removed-seal violation.
- Every post-approval re-seal requires interactive deepening. The one-time adoption migration exception is allowed only for the complete, baseline-proven, first-hand-approved branch below; it is not a generic bypass.

### Adoption-only migration branch

The ordinary rule is fail-closed: an approved plan with a post-approval body change or reseal is rejected and the diagnostic names `interactive deepening`. During this release's one-time adoption, implementing may accept exactly one exception only when the evidence is complete and baseline-proven:

- first-hand explicit user approval;
- the exact pre-upgrade baseline commit;
- a repo-relative plan path;
- the old seal and the new seal;
- the canonical reproduction command; and
- canonical bodies from the baseline and current plan that are byte-identical after the shared UTF-8/universal-newline read and literal extraction.

Implementing rejects a changed body with `changed-body`, a missing baseline with `missing-baseline`, and each missing evidence field with its own diagnostic: `approval`, `baseline commit`, `plan path`, `old seal`, `new seal`, or `reproduction command`. The adoption commit may change only `body_seal` and must record `(baseline commit, plan path, old seal, new seal)`, the reproduction command, and the approval. Any later reseal is rejected unless interactive deepening authorizes it; an interrupted transition requires fresh first-hand approval after operator-owned compensation.

The six durable outcomes are mandatory: `success` advances HEAD once with one seal-line diff and a clean tree; `forced-failure` leaves HEAD unchanged with one dirty target-plan seal diff and no migration commit; `rerun` fails closed without another write or commit until compensation and fresh approval, then permits exactly one success commit; `compensation` restores only the target plan to its pre-transition bytes with unchanged HEAD; `headless` rejects before writing when approval is absent; and `cancellation` leaves pre-write state clean while post-write cancellation proves forced failure before target-only compensation returns the tree clean without a commit. No other adoption or generic bypass branch exists.

## Pre-flight

1. Read the plan once. It is a **decision artifact, not an execution script** (`enforces: P8`) — never edit its body during execution; progress lives in commits and the ledger, not plan edits.
2. **Status check** (when invoked with a plan file): apply the standalone eligibility and terminal-state rules above. For `done`, name the recorded `completed_by` commit; if it is missing, report a validator violation rather than inventing a commit. For `superseded`, name the `superseded_by` successor path. Neither terminal state ever degrades to executing the plan.
3. **Body-seal check** (runs between status check and contradiction scan): apply the approval-history rules above. A present seal must be lowercase hexadecimal and must match the stored-versus-computed values. A removed seal is a violation; a never-sealed plan remains valid. A post-approval reseal is rejected unless interactive deepening or the complete one-time adoption branch authorizes it.
4. **Contradiction scan**: before Unit 1, scan the whole plan once for units that contradict each other, a Global Constraint, or the plan's Architecture notes, or that mandate something the review rubric below would flag as a defect. Batch every finding into **one** blocking question (`references/question-tools.md` at the plugin root); a clean scan proceeds without comment.
5. **Ledger resume check**: read the selected exact `progress_path`. Units it lists complete are done — do not re-dispatch them (`enforces: P8`); trust the ledger and `git log` over recollection. Resume at the first incomplete unit.
6. **Worktree setup**: invoke `worktree-isolation` to obtain or confirm an isolated workspace before any unit touches files.

## Execution strategy

| Strategy | When |
|---|---|
| Inline | 1–2 units, or units needing mid-flight user interaction |
| Serial subagents | 3+ units with dependencies between them; fresh context per unit |
| Parallel subagents | 3+ independent units that pass the Parallel Safety Check below |

**Parallel Safety Check**: map every candidate unit's `Files:` (Create/Modify/Test) to its unit; any path claimed by 2+ units is overlap. Overlap + no worktree isolation → downgrade to serial, log the reason (e.g. "Units 2 and 4 share `config/routes.rb`"). Overlap + worktree isolation available → parallel stays safe: the overlap becomes an expected merge conflict handled by the worktree-isolated protocol in `references/merge-protocols.md`, not silent data loss.

**Capability check**: select the dispatch tier via `references/dispatch-degradation.md` at the plugin root (`enforces: P9`) — native parallel subagents → sequential passes → single-call fallback. No harness subagent primitive at all → **no-subagent fallback**: execute units inline, sequentially, with a human checkpoint between units. This floor is the correctness baseline; every tier above it buys speed and context freshness, never correctness.

## Per-unit loop

For each unit, in dependency order:

1. **Brief**: write the unit's full text (exact values, signatures, Files, Interfaces, Test scenarios, Execution note) to `<artifact_root>/briefs/U<N>-brief.md`. A dispatch prompt describes one unit, not the session's history — never paste prior-unit summaries into a later dispatch.
2. **Dispatch implementer**: one line on where the unit fits, the brief path introduced as "read this first — your requirements," interfaces/decisions from earlier units the brief cannot know, your resolution of any ambiguity you noticed, and the report path `<artifact_root>/reports/U<N>-report.md`. Code units follow `tdd`'s Execution note; non-code units write → self-review against spec → commit.
3. **Status protocol**:

| Status | Orchestrator response |
|---|---|
| DONE | Proceed to task review |
| DONE_WITH_CONCERNS | Correctness/scope concerns → address before review; pure observations → note and proceed |
| NEEDS_CONTEXT | Supply the missing context, re-dispatch |
| BLOCKED | Context gap → re-dispatch with context; reasoning gap → re-dispatch with a more capable model; too large → split; plan itself wrong → escalate to the human |

Never force the same model to retry unchanged — if the implementer said it's stuck, something has to change.

Workers never invoke blocking-question tools or address the user directly — returning `NEEDS_CONTEXT`/`BLOCKED` is their only escalation channel; the orchestrator alone decides whether to answer from its own context or ask the human (worker protocol in `references/dispatch-degradation.md` at the plugin root). `enforces: P7, P9`

4. **Fixture evidence gate**: when the approved plan contains a Mutation/failure-state matrix, every affected unit writes one concise sanitized evidence record per applicable matrix cell before task review. Write each record to `<artifact_root>/evidence/U<N>/<transition-id>-<outcome>.md` and include:
   - plan identity, matrix-row identity, source commit, fixture identity, and timestamp;
   - isolation proof containing the disposable fixture root, the complete configured target inventory, stub identity where applicable, and a boundary sentinel proving no real target is reachable;
   - pre-state, the exact injection or command, exit status, and concise sanitized output;
   - post-state and the relevant next-invocation result for rerun, rollback or compensation, headless, or cancellation or abort behavior; and
   - a mechanism check proving the intended boundary failed rather than fixture setup or unrelated validation.

   Evidence may reference larger sanitized artifacts in the same unit directory, but it never contains credentials, personal data, or unbounded output. Produce it only with disposable local fixtures, local bare remotes, and stubs; never execute a real outward or production mutation. For a stateless deliverable or unit governed by the plan fallback `No stateful ceremony in the deliverable; no mutation/failure-state matrix required.`, pass that fallback to review and create no irrelevant fixture evidence.
5. **Task review**: generate a diff (`base-before-unit..HEAD`) to `<artifact_root>/reviews/U<N>-diff.txt`. Dispatch a reviewer with one approved artifact set: the approved spec, the approved plan including its Mutation/failure-state matrix, the unit evidence directory (or the plan's exact stateless fallback), every applicable committed file discovered under `docs/deviations/` whose Original contract and/or Traceability identifies that approved spec and/or plan as its source, any explicitly handed-off deviation references, the brief path, the report path, the diff path, and Global Constraints copied verbatim from the plan. The link direction is addendum -> approved source: never edit an approved spec or plan to add a backlink just so later review can find the addendum. The reviewer returns **both** verdicts — spec compliance and quality — missing either makes the review incomplete. Reviewer-prompt rules: never pre-judge or pre-rate a finding's severity, never tell the reviewer what not to flag; the constraints block is the reviewer's attention lens, copied verbatim, not paraphrased or softened.
6. **"Cannot verify from diff"** items are the orchestrator's to resolve, not the reviewer's — they require cross-unit context only you hold. A confirmed gap is a failed spec review: send it back to the implementer.
7. **Plan-mandated conflicts** — a finding that conflicts with what the plan's own text requires is the human's decision, like any plan contradiction: present the finding and the plan text, ask which governs. Never silently dismiss a finding because "the plan says so," and never dispatch a fix that contradicts the plan without asking.
8. **Observable deviation gate** — if review or implementation confirms observable behavior absent from, contradictory to, or materially narrower/broader than the approved artifact set, acceptance is blocked until a separate committed deviation addendum records that behavior. A post-approval change to a Mutation/failure-state matrix row or outcome is such observable behavior and follows this committed addendum rule before acceptance. Do not treat this addendum rule as permission to bypass step 7: when the plan itself mandates the conflicting behavior, the human still decides whether the plan governs or a change is required. Use `docs/solutions/workflow-issues/review-introduced-state-machine-deviation.md` for the observable-behavior definition, required addendum contents, the incomplete-release recovery example that requires an addendum, and the internal-refactor exemption when interfaces, state transitions, persistence, consent boundaries, and terminal behavior stay unchanged.
9. **Fix loop**: Critical/Important findings → one fix subagent with the complete findings list, then re-review. **Cap: 3 rounds per unit**; on cap exhaustion, escalate to the human with the surviving findings. Minor findings → record under the ledger's `MinorFindings:`, do not fix now — the final branch review triages which of these must land before merge.
10. Mark the unit complete in the ledger only once both verdicts are clean (or only Minor remains).

## Test gates

Before writing a unit's tests, check scenario completeness against the Test Scenario Completeness table in `references/test-checks.md` (happy/edge/error/integration) and supplement any gap from the unit's own Goal/Approach — vague scenarios ("validates correctly") are a gap too. Before marking a unit done, run the System-Wide Test Check in the same reference file; **skip it** for leaf-node changes with no callbacks, no persisted state, and no parallel interfaces.

## Incremental commits

Heuristic: can you write a commit message that isn't "WIP" or "partial X"? If yes, commit now. Stage only the files for this logical change — never `git add -A`.

## Simplify-as-you-go

`enforces: P4, P5`. At phase boundaries — every 2–3 units, not after every single unit — review recently changed files for duplication and consolidation opportunities. Do not simplify after every unit: early duplication between units may be intentional divergence that hasn't finished revealing itself, and premature merging couples code that changes for different reasons.

## Progress ledger

`enforces: P8`. The selected exact `progress_path` survives context compaction; conversation memory does not. After each unit's review passes, append one line: `Unit <N>: complete (commits <base7>..<head7>, review clean)`. On any resume, trust the ledger plus `git log` over recollection — the commits it names exist in git even when context no longer remembers creating them.

## Final branch review

After all units complete: generate the full branch diff (`merge-base(base, HEAD)..HEAD`) to `<artifact_root>/reviews/branch-diff.txt`. Dispatch one final reviewer on the most capable available model with one approved artifact set: the branch diff, the approved spec, the approved plan including its Mutation/failure-state matrix, every accumulated unit evidence directory (or the plan's exact stateless fallback), every applicable committed file discovered under `docs/deviations/` whose Original contract and/or Traceability identifies that approved spec and/or plan as its source, any explicitly handed-off deviation references, the plan's Scenario coverage map, the accumulated Minor findings, and Global Constraints. The link direction remains addendum -> approved source: never edit an approved spec or plan to add a backlink for review discovery. It checks cross-unit integration (task reviewers only ever saw their own diff), spec coverage across all units, **scenario delivery** — for `code` execution plans, every S-ID row in the coverage map completes end to end on the actual branch and its `Covers S<n>` integration tests exist and pass; for `non-code` execution plans, every S-ID row's named observable verification in the Scenario coverage map is walked and satisfied on the actual branch (`enforces: P3`) — which Minor findings need fixing, and anything visible only from the full diff. Confirmed observable behavior absent from or contradictory to that approved artifact set blocks a clean branch review until a separate committed deviation addendum exists; a post-approval Mutation/failure-state matrix row or outcome change explicitly triggers that committed addendum rule. Use `docs/solutions/workflow-issues/review-introduced-state-machine-deviation.md` for the observable-behavior definition, addendum contents, the incomplete-release recovery example, and the internal-refactor exemption. Findings get **ONE** fix subagent with the complete list — never one fixer per finding. Re-review under the same 3-round cap; escalate on cap exhaustion with any surviving Critical/Important findings named explicitly.

Merge mechanics for worktree-isolated or shared-directory parallel dispatch: `references/merge-protocols.md`.
