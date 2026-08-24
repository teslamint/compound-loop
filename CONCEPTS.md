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

## Changelog convention

- **Released-section immutability** — a tagged `## [x.y.z]` CHANGELOG heading is a historical record of what shipped in that version and must not be edited after the tag. *Avoid: changelog entry reuse* — new entries belong in the next release's freshly drafted section, never under an old heading.
- **No-unreleased convention** — this repo creates CHANGELOG sections only at release time; an `[Unreleased]` heading is absent by policy and would break the release gate that matches the newest section to the requested version.

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
- **Independence level** — the closed vocabulary describing how independent a retro's facilitator was from the respondent (heterogeneous, same-model fresh-context, in-thread (approximated independence), self-checklist, not-probed (no narrative warranted)); recorded so a reader can judge the bias-guard's strength from the doc alone. *Avoid: tool names* — the level describes independence, not mechanism.
- **Self-attested** — a verdict authored by the same agent that produced the answer, in degraded modes with no independent facilitator; never to be read as acceptance.
- **Backward check** — the audit a retro performs on the previous cycle's retro doc while reading it, from an execution independent of the one that wrote it; catches violations one cycle late but outside the writer's own discipline.

## Session resilience

- **Final-action record** — the durable record naming a workflow's single irreversible/final action: its kind, a closed status (predicted, determined, executed), and the exact command once determined. Preparation evidence only — possession of the command is never permission to run it.
- **Prepare-before-gate** — the invariant that the exact command packet of a gated irreversible action is persisted durably before the gate resolves, whether the gate blocks on a human question or evaluates automatic conditions; disk never trails the conversation.
- **Non-authorization marker** — the explicit statement carried by every persisted command packet that it is preparation evidence, never approval; the file-shaped counterpart of "gate approval is not execution authorization".
- **Loop archive** — the terminal archive of a finished release loop's local working state. It preserves the loop's final durable record in its archive home so completion is read from files rather than conversation memory.
- **State handoff** — transferring a durable lifecycle record from a workspace scheduled for cleanup to the next owning workspace. Verify the new owner can resume from the record before deleting the old workspace.
- **Partial success** — a compound action state in which an earlier durable effect completed but a later step failed. Recovery resumes from the first uncompleted effect boundary; a single exit status never authorizes retrying or cleaning up every step as a unit.

## Completion evidence

- **Evidence tier** — a named strength level of completion evidence; the position a proving observation occupies on the evidence-tier ladder.
- **Evidence-tier ladder** — the fixed descending order of completion-evidence strength: failing-repro-now-passing > end-to-end run > integration test > unit test > typecheck/build. Typecheck/build alone never closes a completion claim. The ladder ranks strength where tiers apply; evidence that fits no tier (for example, a structural validation run proving a docs-only change) is cited tier-free, never forced into a tier label.
- **Claim layer** — the layer a completion claim lives at, implied by the requirement or success criterion it answers (unit, integration, end-to-end).
- **Layer-mismatch** — a completion claim whose best evidence sits below the claim's layer. A claim is closed only by evidence at or above its layer; unit-level evidence closes only a unit-level claim.
- **Binary completion report** — the two-valued reporting form for completion claims at structured outputs: `verified: <observation>` or `unverified: <blocker>`, with no hedged middle state. For rubric-measured checks it reports evidence acquisition (the rubric was applied, reading cited), not the judgment itself.

## Run integrity

- **Artifact scope** — the closed repository-owned boundary for one workflow run's mutable state. A run never adopts content outside this boundary and never overwrites an occupied scope by inference.
- **Review event** — one reserved review or fix attempt with a stable identity and one immutable result. Replay resumes the same event; it never creates a second count for the same attempt.
- **Exact-head review gate** — a clean whole-branch review bound to one full commit identity. Any head change invalidates the gate, regardless of ancestry.
- **Count completeness** — whether structured lifecycle totals cover the whole run (`exact`) or only events after structured counting began (`partial`). A partial count is a lower bound, never an exact total.

## Carry-forward triggers

- **Edit-based trigger** — a carry-forward trigger that fires when a named file or section is touched by planned or actual work; detected by diffing a plan's file list against the trigger's named targets.
- **Drift-based trigger** — a carry-forward trigger that fires when a named record shape or observable state deviates from its contract; detected by inspecting the named record where observable.
- **Event-based trigger** — a carry-forward trigger that fires on a future occurrence rather than a file edit or record shape (a new install, an external report, the next cycle of a named kind); detected by querying the inter-retro range against the trigger path, not by session recollection. *Avoid: session-scoped trigger check* (wrong scope).
- **Inter-retro range** — the commit range between two consecutive retrospective documents. Event-based triggers fire on any qualifying commit in this range, not only commits from the current session. Queried as `git log <prev-retro-date>..HEAD -- <trigger-path>`. Skipped retros widen the range and compound reconciliation drift.
- **Partial discharge** — a fired carry-forward trigger whose responding change addresses only part of the item's stated scope. Recorded as "In progress" with the ROADMAP trigger re-armed for the undischarged remainder. *Avoid: classifying as "Done" or "Not started"* — both drop the remaining work from tracking.
- **Trigger audit** — the planning-time act of classifying every open carry-forward row's trigger into exactly one class and diffing the fireable classes against the plan's file list and observable record state. A fired trigger demands a recorded disposition, and a recorded firing latches: archiving or resetting the drifted record never un-fires a row.
- **Unexercised-path observation** — a clean reading of a record taken in a cycle where the path that would have dirtied it never ran. It says the record is clean; it says nothing about the gap the row tracks, so reconciling a row as improving on this evidence is a measurement error. The carry-forward counterpart of a criterion that cannot fail.

## Plan lifecycle

- **Terminal state** — a plan status with no outgoing transitions, recording that the plan was executed or replaced. Reaching one requires the evidence field that justifies it, so a bare terminal flag that merely restates derivable history cannot exist.
- **Mutable slot** — the only part of a plan that may legally change after its approval: the status field, the terminal-state evidence accompanying it, and the body seal. Everything else is the immutable decision artifact; the boundary is what lets terminal states coexist with post-approval immutability.
- **Body seal** — the SHA-256 hex digest of a plan's markdown body (after the closing frontmatter delimiter), stored in the frontmatter at approval. Proves body-matches-last-seal; does not prove unchanged-since-approval. A mutator that re-seals defeats the mechanical check — the cross-cutting skill rules are the defense against unauthorized re-sealing; interactive deepening is the sole authorized re-seal path.
- **Supersession** — retiring a plan because a successor replaces it, recorded on the predecessor with a pointer to the successor. Timed at the successor's creation, not its approval, and reachable from draft: a plan can be replaced before anyone approves it. Direction is predecessor→successor only. *Avoid: abandoned* — retirement without a successor pointer has no observed instance and no slot to explain itself.
- **Rejection record** — an inline schema note preserving why a value was removed from (or refused entry to) a closed vocabulary, so the absence reads as a decision rather than an oversight and the value is not re-proposed uninformed.

## Review independence

- **Conformance review** — review that checks an artifact against the approved plan or spec that specified it. Finds drift, dataflow gaps, and contradictions between units; inherits the approved artifact's model of what could go wrong, so it cannot surface a failure mode the plan never imagined.
- **Invariant attack** — review that states the mechanism's guarantee in its own sentence, then constructs the cheapest artifact satisfying every written check while violating that guarantee, and requires the mechanism to reject it. The complement to conformance review, not a replacement; it finds the class the plan failed to describe.
- **Integrity mechanism** — a deliverable whose success is defined by what it refuses: a checker, gate, guard, validator, schema constraint, or audit rule. For this class the plan's model of failure is the product, which is why a conformance-only review is most expensive here.
- **Threatened-criterion severity** — grading a finding by the success criterion it puts at risk rather than by the reachability of the code path it sits in. A hole in the mechanism a cycle exists to build is never minor, however narrow its blast radius.

## Metrics

- **Changed non-test lines** — the count of modified lines (added + removed) excluding tests, generated files, and lockfiles, used as the canonical diff-size metric across all phases (e.g. lane triggers).

## Agent context files

- **Global-rule contamination** — editing a repo's `CLAUDE.md` that is a symlink to a dot-agents global rules file, which loads into every project and leaks repo-specific content across all of them. *Avoid: writing project guidance through the CLAUDE.md symlink* — it silently degrades unrelated sessions.
- **Plugin-cache drift** — divergence between a plugin cache's skill text and the repository HEAD `skills/**` while both declare the same plugin version string; the version number is not a parity signal. *Avoid: trusting cached skill text* when HEAD has moved.
- **Machine-local config** — agent context files (`/CLAUDE.md`, `/AGENTS.md`) that are gitignored per-project and never committed; `git ls-files` exiting 0 does not prove tracking. Team-shared guidance belongs in `docs/solutions/`.
