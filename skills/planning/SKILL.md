---
name: planning
description: Turn an approved spec into an implementation plan an engineer or agent can execute with zero codebase context. Invoke as /planning (Claude Code) or $planning (Codex), or when the user says "plan this", "write an implementation plan", "break this into tasks", or a designing-phase spec is ready to plan.
---

# Planning

Turns an approved spec into the plan that `implementing` and `reviewing` consume — a decision artifact, never an execution script. `schemas/plan-schema.md` is the frontmatter and unit contract; this skill produces documents that satisfy it and never restates its content.

## Entry / Exit / Gate

- **Entry**: an approved spec (`designing`'s output), or a direct user request to plan a change with no spec.
- **Exit**: an approved plan doc committed to `docs/plans/YYYY-MM-DD-NNN-<type>-<name>-plan.md`, or a documented skip to `implementing` per step 1.
- **Gate**: USER. Commit the plan as `status: draft` first. Flip to `status: approved` only after the user confirms the drafted plan, in a separate commit — never combine both in one commit. Downstream consumers (`implementing`, `reviewing`, `release-loop`'s pipeline gating) depend on finding this exact draft-then-approved record.

## 1. Entry check — is a plan doc warranted?

Bias toward writing one: a thin plan for small work is mild ceremony, but skipping a warranted plan costs the implementer real time. Skip the plan doc only when **all** hold:
- The work is atomic — one commit, no unit boundaries worth breaking out.
- No Key Technical Decisions — no choice the implementer needs to be told how to resolve.
- No scope boundaries worth pinning in writing.
- No upstream spec or prior-plan artifact needs traceability through this plan.

Stress-test anything that "looks atomic": "Add caching" hides TTL/invalidation/key-shape decisions; "migrate A to B" hides semantic-difference decisions; "add rate limiting" hides algorithm/scope decisions — all three warrant a plan. Genuine skips: a typo fix, a mechanical rename, a dependency bump with no breaking change.

When skipping, attest that all four conditions hold, citing the work's scope, then hand off directly to `implementing`. When invoked from `release-loop`, also write the skip to `.release-loop/progress.md`'s Log section with the conditions cited — `plan:` stays `null` (the Log line is the record; a non-path value would break resume's artifact-pointer verification).

## 2. Scope confirmation

One compressed confirmation before spending research or authoring budget: state the scope read from the spec (stated intent plus any material forks) and ask the user to confirm or redirect, using the blocking-question pattern in `references/question-tools.md`. Skip the confirmation only for a trivial, single-unit plan with zero forks — proceed and say so in one line. When invoked as a dispatched phase worker under an AUTO gate (release-loop pipeline), this question is the orchestrator's to ask or waive — state the read scope in the ledger/log and proceed rather than blocking (worker protocol in `references/dispatch-degradation.md`).

## 3. Context research

Plans are written for a zero-context implementer, which makes the planner the one who must carry the context (`enforces: P5` — reuse before new).

**Local research — always runs.** Search for a similar feature and read its implementation end to end before structuring anything; when the work is genuinely greenfield, record the verified absence and read the nearest analogue instead (the search is unconditional, the find is not). Identify the existing patterns, utilities, and conventions units must follow (name them in the units — implementers see only their own unit). Check `docs/solutions/` for prior learnings touching the planned modules and surface hits as "Known Pattern"; read `CONCEPTS.md` if present and use its canonical vocabulary. Any claim that something does not exist in the codebase must be verified against source or labeled an unverified assumption.

**External research — conditional.** Escalate to documentation or web sources only when one holds: the user explicitly asked; the plan makes claims about an unfamiliar library, framework, or API version; or the work touches a high-risk surface with sparse local precedent (fewer than 3 direct examples). Record findings in Architecture notes with sources — unbacked external claims are exactly what the deepening trigger "thin external grounding" catches later.

## 4. Assumption recheck

When the plan has an `origin` spec, inspect that approved artifact for retained
live assumptions before mapping files or units. Rerun every retained command
and record the fresh result in the plan's **Assumption Recheck** section using
one outcome per claim:

- **match** — the fresh evidence still supports the approved claim.
- **contradiction** — the fresh evidence disagrees with the approved claim or
  reveals a newly observable contradiction.
- **unavailable** — the command or evidence source cannot be rerun or inspected
  safely at planning time.

For a **contradiction**, preserve the approved spec unchanged and stop plan
finalization and commit until a separate committed addendum exists under
`docs/deviations/`. The addendum's required contents are owned by
`docs/solutions/workflow-issues/review-introduced-state-machine-deviation.md`;
link that authority rather than restating its seven-part contract here.

For **unavailable** evidence, do not invent a contradiction or a clean match.
Record the unavailable result in Assumption Recheck and carry it into Open
unknowns as a planning-time unknown unless the user narrows the claim enough to
remove the missing evidence.

When the plan has **no origin spec**, the Assumption Recheck section must say:
`No origin spec; no approved live assumptions to recheck.`

When the origin spec exists but retains **zero live assumptions**, the section
must say:
`Origin spec retains no live assumptions; no assumption recheck required.`

## 5. File structure

Map files to create or modify before defining units: one responsibility per file, colocate what changes together, split by responsibility rather than technical layer, and follow the existing codebase's scale — don't unilaterally restructure an established large-file convention.

## 5a. Carry-forward trigger audit

When the File structure section is written, list every open row in the durable tracker (ROADMAP, issue tracker, or equivalent — the same tracker `retrospective` pushes carry-forward items to) and classify each row's trigger into exactly one class: edit-based (names a file or section whose touch fires it), drift-based (names a record shape or observable state whose deviation fires it), or event-based (names a future occurrence). Tiebreak: a trigger naming both a file condition and an event resolves to edit-based — the mechanically checkable reading wins.

Read recorded fired-state annotations first (latching): a row whose firing is already recorded in the tracker or a prior retro counts as fired regardless of current observability — an archived or reset record does not un-fire it.

Diff edit-based triggers against the planned file list; check each drift-based trigger's named record where observable at planning time. An unobservable record is recorded as unobservable in the audit section — never given an invented verdict. A row with no classifiable trigger condition is recorded as unclassifiable and handled under the event-based feature-relevance question, never silently skipped.

Every fired trigger gets a disposition in the same planning pass: fold the row in as a unit, or add a Deferred to Follow-Up Work entry naming the row and the reason. Silence on a fired trigger is a plan gap that blocks approval.

Record the result in the plan's Carry-forward trigger audit section per `schemas/plan-schema.md` — fired rows, unobservable rows, and the attestation line.

Reviewer mandate: any independent plan review re-derives this audit — open tracker rows versus the plan's File structure and the audit section's dispositions — rather than trusting the section's claims; an omitted fired row is a blocking finding. Whoever composes a plan-review dispatch prompt carries this re-derive instruction into the prompt verbatim, so the mandate travels with the dispatch.

## 6. Deliverable-type gate

Classify the spec's deliverable once: `code` (source, schema, CLI, API changes) or `non-code` (docs, skill files, config-only). Record it in the plan frontmatter's `execution` field per `schemas/plan-schema.md` — never in a side-channel file. This selects the unit template in step 9.

## 7. Scenario flow analysis

Before cutting units, walk every User Scenario (S-ID) in the spec end to end: what has to exist, in what order, for this scenario to complete? The walkthrough produces two artifacts — the durable record downstream fresh-verification runs against (`enforces: P8`):

- The plan's **Scenario coverage map** (hard-floor section per `schemas/plan-schema.md`): S-ID → ordered unit chain → the integration test scenario(s) that walk it.
- The **integration test scenarios** themselves — derive them from user scenarios first, before inventing technical integration cases. A user scenario no test walks is untested motivation; a scenario no unit chain completes is a plan gap that blocks approval (add the missing unit, or send the scenario back to `designing` for explicit descoping — never silently drop it).

Specs without a User Scenarios section (or plans with no spec) record that fact in the coverage map section explicitly. Decomposition in step 8 takes this walkthrough as input: unit boundaries that would strand a scenario mid-flow are wrong boundaries.

## 8. Decomposition

A unit is the smallest change worth a fresh reviewer's gate — small enough that a reviewer could reject one unit while approving its neighbor, but not a 2–5 minute micro-step. Fold setup and scaffolding into the unit that needs them.

U-IDs follow the stability rule in `schemas/plan-schema.md` (never renumbered on reorder, split, or delete) — this matters most during the deepening pass in step 15, the likeliest accidental-renumber vector.

Smell test: 3–7 units is typical. More than 10 suggests under-decomposition — split the plan or revisit the spec. Fewer than 3 suggests step 1 may have been wrong to write a plan doc at all.

## 9. Unit authoring

Use the code or non-code unit template from `schemas/plan-schema.md` as-is — do not redefine it here. For code units, fill test scenarios by category (happy / edge / error / integration); every category that applies to the unit gets a scenario, right-sized to its risk. Integration scenarios come from step 7's walkthrough first — tag the ones that walk a user scenario with `Covers S<n>`. Link a scenario to a spec acceptance criterion with `Covers AE<n>` only when it directly enforces that criterion — sparse by design, since most scenarios are finer-grained than an AE. A `Covers AE<n>` or `Covers S<n>` naming a nonexistent target is a validation error, not a soft note.

## 10. Mutation/failure-state matrix

A **stateful ceremony** is a workflow whose deliverable can cross an observable side-effect boundary. A **durable transition** is a step that changes persisted or externally observable state across invocations.

If the deliverable contains a stateful ceremony, add a **Mutation/failure-state matrix** plan section. Include one row for every durable transition. Each row must name the transition identity, pre-state, action, expected post-state, owning implementation unit, and evidence owner that will produce disposable fixture evidence under `.release-loop/evidence/U<N>/`. Fill all six outcome classes: success; forced failure; rerun; rollback or compensation; headless; and cancellation or abort. Every forced-failure outcome names a safe injection boundary and isolation approach. Irreversible transitions describe compensation or explicit manual recovery rather than fictional rollback. Blank cells are invalid; every not-applicable cell gives a concrete reason tied to the interface or irreversibility boundary.

Use `references/stateful-ceremony-matrix-example.md` as the worked example and `docs/solutions/workflow-issues/review-introduced-state-machine-deviation.md` as the deviation authority; link them rather than duplicating their contracts. Changing an approved matrix row or outcome is observable behavior and triggers item 3's deviation-addendum rule before release.

If the deliverable contains no stateful ceremony, write exactly:
`No stateful ceremony in the deliverable; no mutation/failure-state matrix required.`

## 11. Planning-time vs. implementation-time unknowns

Split every open unknown by when it can resolve. Planning-time unknowns block approval — resolve them, or ask, before finalizing the plan. Implementation-time unknowns (exact method or helper names, final SQL, runtime-dependent behavior only discoverable once code is touched) are not gaps — record them under the implementation-time half of Open unknowns so they read as deferred-by-design, never as something missed.

## 12. Anti-expansion

Distinct from step 11: this is *known but tangential* work noticed while planning — an adjacent refactor, a "while we're here" cleanup, a scope-adjacent nice-to-have. Route it to Deferred to Follow-Up Work, never into an active unit (`enforces: P4, P6`). The user's explicit ask overrides this default — if they asked for the refactor, it's in scope, not deferred. Worked example: a version bump or CHANGELOG entry belongs to `shipping`, never to a planning unit.

## 13. No-placeholder rule

Banned in any unit: "TBD", "TODO", "similar to Task N" / "see U3", "as appropriate", "etc.", "add appropriate error handling", steps that describe what to do without showing how, and references to types or functions not defined in any unit. Units may be read out of order by their implementer — repeat content rather than pointing sideways.

## 14. Self-review

Before finalizing, the author (not a subagent) checks:
- **Assumption recheck flows** — walk one match, one contradiction, one
  unavailable result, the no-origin case, and the zero-retained-assumption
  case against the final wording. Confirm contradictions block finalization and
  commit until a separate committed addendum exists, and unavailable evidence
  stays a planning-time unknown unless the user narrows the claim.
- **Spec coverage** — every spec requirement traces to a unit; list gaps.
- **Scenario coverage** — re-walk the Scenario coverage map against the final unit set: every S-ID still completes end to end (deepening and unit edits are the likeliest breakage vector), and every map row names real scenario evidence (integration test, or observable verification for non-code plans). `enforces: P8`
- **Mutation/failure-state completeness** — when the deliverable contains a stateful ceremony, confirm every durable transition has a row with transition identity, pre-state, action, expected post-state, all six outcome classes, and an implementation-unit/evidence-owner mapping. Confirm irreversible transitions name compensation or manual recovery, every forced failure uses safe isolated injection, and no cell is blank or uses not-applicable without a concrete reason. Otherwise confirm the exact stateless fallback is present.
- **Placeholder scan** — search for step 13's red flags; fix inline.
- **Type consistency** — do signatures, names, and types agree across units (a function `clearLayers()` in U2 and `clearFullLayers()` in U5 is a bug)?
- **Callers + invariants** — for code units, who calls the functions being changed, and what invariants must still hold afterward?
- **Retro carryover** — re-run the step 5a trigger audit against the final file list (deepening and unit edits are the likeliest divergence vector), confirm the attestation line still names the tracker state actually examined, and keep the feature-relevance question ("does this item belong in this plan?") for event-based triggers only.
- **Architecture-unit clause consistency** — diff every claim in the Architecture notes against the unit steps and interfaces that implement it. A note asserting "X is always Y" while a unit step implements otherwise (or omits the constraint entirely) is a blocking finding.
- **Command closure** — for every shell command in a unit step, verify that every variable it references is assigned or declared within that step or an earlier step in the same unit. A step referencing `$VAR` without a prior assignment is a dataflow gap that step 13's keyword scan cannot catch.

Fix issues inline; no separate review pass is needed.

## 15. Deepening pass

After self-review, run the confidence check in `references/deepening.md`: six trigger categories score the plan (vague rationale, missing risk treatment, weak sequencing, thin external grounding, unclear verification, thin scenario coverage) — skip deepening entirely when nothing scores. When triggered, dispatch reviewer personas — Architecture and Feasibility always-on, Security/Risk and Scope/Coherence conditional on activation signals — per the dispatch ladder in `references/dispatch-degradation.md` (native parallel → sequential passes; correctness never depends on parallelism being available). Change discipline: tightening prose is in scope; writing implementation code is not; U-IDs are never renumbered; superseded text is resolved in place, never stacked as a separate layer.

## 16. Outstanding-question triage

Classify every open question as planning-owned (resolvable from repo context, docs, or a user choice made now) or a product blocker (would change scope, behavior, or success criteria). Never plan over a live product blocker — surface it and either send the user back to `designing` to resolve it, or convert it to an explicit assumption before continuing.

## 17. Commit the plan

Write to `docs/plans/YYYY-MM-DD-NNN-<type>-<name>-plan.md` per the naming rule in `schemas/plan-schema.md`, then `git add` and commit with `status: draft`, following the repo's commit protocol. Run `python3 skills/planning/scripts/validate-plan-frontmatter.py <plan-path>` on the drafted file; exit 0 required before presenting the draft and again before the approved-flip commit; a nonzero exit names the offending field — fix and re-run, never present a failing draft. Present the drafted plan to the user; only after they approve it, commit again — same file, `status: approved` only — per this skill's Gate. Never commit a plan directly as `approved`; the draft commit is what a reviewer or a later session diffs against. From this point the plan is a decision artifact — `implementing` never edits its body.

When this plan replaces an earlier plan first committed after the terminal-state contract landed (`schemas/plan-schema.md`'s applicability boundary — plans predating it are never retroactively flipped), flip the predecessor to `status: superseded` with `superseded_by:` naming this plan's path, in the same commit that commits this plan (the predecessor may be `draft` or `approved`); run the validator on the predecessor too.

Do not finalize or commit a plan whose Assumption Recheck contains a
contradiction unless the separate addendum commit already exists.

## 18. Handoff

Offer a 2-option menu: **Subagent-driven** (fresh subagent per unit, review between units — recommended) or **Inline** (execute in this session with checkpoints between units). Fire the chosen path; don't just announce it.

When invoked headless from `release-loop` or any pipeline caller, skip the menu: write the plan's path to `.release-loop/progress.md`'s `plan:` field and return control to the caller.
