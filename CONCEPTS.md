# CONCEPTS

Shared vocabulary for this repo. One canonical term per concept; definitions stay conceptual — no implementation specifics, status, or links.

## Release verification

- **Source inventory** — the enumerable list of items a derived deliverable is authored from (mechanisms distilled into skills, records in a migration, sections in a consolidation).
- **Drop-list** — the explicit, reasoned record of source-inventory items deliberately left out of a deliverable. The only artifact where a silent omission is visible; each entry carries a reason judged by a reviewable rubric.
- **Structural criterion** — a success criterion that measures an artifact's presence or well-formedness (exists, parses, loads, emits an expected line) rather than its content. *Avoid: presence check* as a criterion name — reserve it for describing what the criterion measures.
- **Traceability criterion** — a success criterion requiring every source-inventory item to be either present in the deliverable (with a citation) or on a drop-list with a reason. The fidelity-class complement to structural criteria for inventory-derived work.
- **Content-fidelity drift** — divergence between a source inventory and the content authored from it; invisible to structural criteria by construction.
- **Discriminating criterion** — a success criterion that measures a state change and therefore must fail on the pre-change tree. One that already passes before the work is done carries no information about the work, whatever it reports afterward.
- **Invariance guard** — a success criterion that must hold both before and after, proving the change disturbed nothing. Passing on the pre-change tree is the expected result, not the non-discriminating defect; the two criterion kinds are read against opposite baselines.

## Release ceremony

- **Release ceremony** — the post-merge process that turns merged work into a versioned release: CHANGELOG authoring, version bump, and tag. Owned by `release`, deliberately separate from feature shipping so features stay independently revertable.
- **Four-way version agreement** — the release-time invariant that both plugin manifests, the newest CHANGELOG section, and the newest tag name the same version.
- **Backfill** — creating CHANGELOG sections for releases that predate the file itself, derived from their committed specs and retros; keyed on the file's absence, one-time per repo.
- **Prepare-only** — the headless posture of a ceremony that requires first-hand consent: run every step up to the gate, persist the draft and exact commands, and stop with a skip signal instead of executing.
- **Deviation addendum** — a committed companion to an approved spec or plan that preserves the original approval record while documenting post-approval observable behavior before release. *Avoid: implementation drift record* — the addendum records an authorized contract change, not merely that code differs.
- **Outward-publication boundary** — any action that makes an artifact accessible outside the local repository's default branch: pushing to a remote, creating a remote repository, publishing to a registry, creating a platform release, changing repository visibility. A deliverable crossing this boundary constitutes a stateful ceremony and requires a mutation/failure-state matrix.

## Python compatibility

- **Supported Python range** — the inclusive interval of CPython minor versions that repo-owned Python entry points and generated Python artifacts are expected to support.
- **Boundary interpreter** — the oldest or newest minor in the supported Python range, used as an explicit endpoint for compatibility evidence.
- **Generated Python artifact** — Python source rendered by another program and executed later; distinct from Python source executed directly by its containing shell command.
- **Incidental compatibility** — an artifact running correctly on an interpreter outside the supported Python range, without that being declared, gated, or promised. Distinct from support: the range still excludes the interpreter, no boundary interpreter covers it, and nothing mechanical keeps it working. Worth buying for artifacts distributed to machines whose interpreter the repo does not choose; the cost is an accepted drift exposure, which belongs on a carry-forward row rather than being silently absorbed.

## Retrospective interview

- **Interview transcript** — the retro doc's record of every probed exchange between facilitator and respondent, accepted and rejected alike; the only content findings may cite beyond measured data.
- **Transcript triple** — one probed exchange: probe, answer, evidence, carrying a facilitator-authored verdict recorded verbatim.
- **Independence level** — the closed vocabulary describing how independent a retro's facilitator was from the respondent (heterogeneous, same-model fresh-context, in-thread approximated, self-checklist); recorded so a reader can judge the bias-guard's strength from the doc alone. *Avoid: tool names* — the level describes independence, not mechanism.
- **Self-attested** — a verdict authored by the same agent that produced the answer, in degraded modes with no independent facilitator; never to be read as acceptance.
- **Backward check** — the audit a retro performs on the previous cycle's retro doc while reading it, from an execution independent of the one that wrote it; catches violations one cycle late but outside the writer's own discipline.

## Session resilience

- **Final-action record** — the durable record naming a workflow's single irreversible/final action: its kind, a closed status (predicted, determined, executed), and the exact command once determined. Preparation evidence only — possession of the command is never permission to run it.
- **Prepare-before-gate** — the invariant that the exact command packet of a gated irreversible action is persisted durably before the gate resolves, whether the gate blocks on a human question or evaluates automatic conditions; disk never trails the conversation.
- **Non-authorization marker** — the explicit statement carried by every persisted command packet that it is preparation evidence, never approval; the file-shaped counterpart of "gate approval is not execution authorization".
- **Loop archive** — the terminal archive of a finished release loop's local working state. It preserves the loop's final durable record in its archive home so completion is read from files rather than conversation memory.
- **State handoff** — transferring a durable lifecycle record from a workspace scheduled for cleanup to the next owning workspace. Verify the new owner can resume from the record before deleting the old workspace.

## Completion evidence

- **Evidence tier** — a named strength level of completion evidence; the position a proving observation occupies on the evidence-tier ladder.
- **Evidence-tier ladder** — the fixed descending order of completion-evidence strength: failing-repro-now-passing > end-to-end run > integration test > unit test > typecheck/build. Typecheck/build alone never closes a completion claim. The ladder ranks strength where tiers apply; evidence that fits no tier (for example, a structural validation run proving a docs-only change) is cited tier-free, never forced into a tier label.
- **Claim layer** — the layer a completion claim lives at, implied by the requirement or success criterion it answers (unit, integration, end-to-end).
- **Layer-mismatch** — a completion claim whose best evidence sits below the claim's layer. A claim is closed only by evidence at or above its layer; unit-level evidence closes only a unit-level claim.
- **Binary completion report** — the two-valued reporting form for completion claims at structured outputs: `verified: <observation>` or `unverified: <blocker>`, with no hedged middle state. For rubric-measured checks it reports evidence acquisition (the rubric was applied, reading cited), not the judgment itself.

## Carry-forward triggers

- **Edit-based trigger** — a carry-forward trigger that fires when a named file or section is touched by planned or actual work; detected by diffing a plan's file list against the trigger's named targets.
- **Drift-based trigger** — a carry-forward trigger that fires when a named record shape or observable state deviates from its contract; detected by inspecting the named record where observable.
- **Event-based trigger** — a carry-forward trigger that fires on a future occurrence rather than a file edit or record shape (a new install, an external report, the next cycle of a named kind); detected by judgment, not diffing.
- **Trigger audit** — the planning-time act of classifying every open carry-forward row's trigger into exactly one class and diffing the fireable classes against the plan's file list and observable record state. A fired trigger demands a recorded disposition, and a recorded firing latches: archiving or resetting the drifted record never un-fires a row.
- **Unexercised-path observation** — a clean reading of a record taken in a cycle where the path that would have dirtied it never ran. It says the record is clean; it says nothing about the gap the row tracks, so reconciling a row as improving on this evidence is a measurement error. The carry-forward counterpart of a criterion that cannot fail.

## Plan lifecycle

- **Terminal state** — a plan status with no outgoing transitions, recording that the plan was executed or replaced. Reaching one requires the evidence field that justifies it, so a bare terminal flag that merely restates derivable history cannot exist.
- **Mutable slot** — the only part of a plan that may legally change after its approval: the status field, the terminal-state evidence accompanying it, and the body seal. Everything else is the immutable decision artifact; the boundary is what lets terminal states coexist with post-approval immutability.
- **Body seal** — the SHA-256 hex digest of a plan's markdown body (after the closing frontmatter delimiter), stored in the frontmatter at approval. Proves body-matches-last-seal; does not prove unchanged-since-approval. A mutator that re-seals defeats the mechanical check — the cross-cutting skill rules are the defense against unauthorized re-sealing; interactive deepening is the sole authorized re-seal path.
- **Supersession** — retiring a plan because a successor replaces it, recorded on the predecessor with a pointer to the successor. Timed at the successor's creation, not its approval, and reachable from draft: a plan can be replaced before anyone approves it. Direction is predecessor→successor only. *Avoid: abandoned* — retirement without a successor pointer has no observed instance and no slot to explain itself.
- **Rejection record** — an inline schema note preserving why a value was removed from (or refused entry to) a closed vocabulary, so the absence reads as a decision rather than an oversight and the value is not re-proposed uninformed.

## Metrics

- **Changed non-test lines** — the count of modified lines (added + removed) excluding tests, generated files, and lockfiles, used as the canonical diff-size metric across all phases (e.g. lane triggers).
