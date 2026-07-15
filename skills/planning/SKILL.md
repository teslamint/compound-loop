---
name: planning
description: Turn an approved spec into an implementation plan an engineer or agent can execute with zero codebase context. Invoke as /planning (Claude Code) or $planning (Codex), or when the user says "plan this", "write an implementation plan", "break this into tasks", or a designing-phase spec is ready to plan.
---

# Planning

Turns an approved spec into the plan that `implementing` and `reviewing` consume — a decision artifact, never an execution script. `schemas/plan-schema.md` is the frontmatter and unit contract; this skill produces documents that satisfy it and never restates its content.

## 1. Entry check — is a plan doc warranted?

Bias toward writing one: a thin plan for small work is mild ceremony, but skipping a warranted plan costs the implementer real time. Skip the plan doc only when **all** hold:
- The work is atomic — one commit, no unit boundaries worth breaking out.
- No Key Technical Decisions — no choice the implementer needs to be told how to resolve.
- No scope boundaries worth pinning in writing.
- No upstream spec or prior-plan artifact needs traceability through this plan.

Stress-test anything that "looks atomic": "Add caching" hides TTL/invalidation/key-shape decisions; "migrate A to B" hides semantic-difference decisions; "add rate limiting" hides algorithm/scope decisions — all three warrant a plan. Genuine skips: a typo fix, a mechanical rename, a dependency bump with no breaking change.

When skipping, hand off directly to `implementing` and stop here.

## 2. Scope confirmation

One compressed confirmation before spending research or authoring budget: state the scope read from the spec (stated intent plus any material forks) and ask the user to confirm or redirect, using the blocking-question pattern in `references/question-tools.md`. Skip the confirmation only for a trivial, single-unit plan with zero forks — proceed and say so in one line.

## 3. Context research

Plans are written for a zero-context implementer, which makes the planner the one who must carry the context (`enforces: P5` — reuse before new).

**Local research — always runs.** Read at least one similar feature's implementation end to end before structuring anything; identify the existing patterns, utilities, and conventions units must follow (name them in the units — implementers see only their own unit). Check `docs/solutions/` for prior learnings touching the planned modules and surface hits as "Known Pattern"; read `CONCEPTS.md` if present and use its canonical vocabulary. Any claim that something does not exist in the codebase must be verified against source or labeled an unverified assumption.

**External research — conditional.** Escalate to documentation or web sources only when one holds: the user explicitly asked; the plan makes claims about an unfamiliar library, framework, or API version; or the work touches a high-risk surface with sparse local precedent (fewer than 3 direct examples). Record findings in Architecture notes with sources — unbacked external claims are exactly what the deepening trigger "thin external grounding" catches later.

## 4. File structure

Map files to create or modify before defining units: one responsibility per file, colocate what changes together, split by responsibility rather than technical layer, and follow the existing codebase's scale — don't unilaterally restructure an established large-file convention.

## 5. Deliverable-type gate

Classify the spec's deliverable once: `code` (source, schema, CLI, API changes) or `non-code` (docs, skill files, config-only). Record it in the plan frontmatter's `execution` field per `schemas/plan-schema.md` — never in a side-channel file. This selects the unit template in step 8.

## 6. Scenario flow analysis

Before cutting units, walk every User Scenario (S-ID) in the spec end to end: what has to exist, in what order, for this scenario to complete? The walkthrough produces two artifacts consumed downstream (`enforces: P3`):

- The plan's **Scenario coverage map** (hard-floor section per `schemas/plan-schema.md`): S-ID → ordered unit chain → the integration test scenario(s) that walk it.
- The **integration test scenarios** themselves — derive them from user scenarios first, before inventing technical integration cases. A user scenario no test walks is untested motivation; a scenario no unit chain completes is a plan gap that blocks approval (add the missing unit, or send the scenario back to `designing` for explicit descoping — never silently drop it).

Specs without a User Scenarios section (or plans with no spec) record that fact in the coverage map section explicitly. Decomposition in step 7 takes this walkthrough as input: unit boundaries that would strand a scenario mid-flow are wrong boundaries.

## 7. Decomposition

A unit is the smallest change worth a fresh reviewer's gate — small enough that a reviewer could reject one unit while approving its neighbor, but not a 2–5 minute micro-step. Fold setup and scaffolding into the unit that needs them.

U-IDs follow the stability rule in `schemas/plan-schema.md` (never renumbered on reorder, split, or delete) — this matters most during the deepening pass in step 13, the likeliest accidental-renumber vector.

Smell test: 3–7 units is typical. More than 10 suggests under-decomposition — split the plan or revisit the spec. Fewer than 3 suggests step 1 may have been wrong to write a plan doc at all.

## 8. Unit authoring

Use the code or non-code unit template from `schemas/plan-schema.md` as-is — do not redefine it here. For code units, fill test scenarios by category (happy / edge / error / integration); every category that applies to the unit gets a scenario, right-sized to its risk. Integration scenarios come from step 6's walkthrough first — tag the ones that walk a user scenario with `Covers S<n>`. Link a scenario to a spec acceptance criterion with `Covers AE<n>` only when it directly enforces that criterion — sparse by design, since most scenarios are finer-grained than an AE. A `Covers AE<n>` or `Covers S<n>` naming a nonexistent target is a validation error, not a soft note.

## 9. Planning-time vs. implementation-time unknowns

Split every open unknown by when it can resolve. Planning-time unknowns block approval — resolve them, or ask, before finalizing the plan. Implementation-time unknowns (exact method or helper names, final SQL, runtime-dependent behavior only discoverable once code is touched) are not gaps — record them under the implementation-time half of Open unknowns so they read as deferred-by-design, never as something missed.

## 10. Anti-expansion

Distinct from step 9: this is *known but tangential* work noticed while planning — an adjacent refactor, a "while we're here" cleanup, a scope-adjacent nice-to-have. Route it to Deferred to Follow-Up Work, never into an active unit (`enforces: P4, P6`). The user's explicit ask overrides this default — if they asked for the refactor, it's in scope, not deferred. Worked example: a version bump or CHANGELOG entry belongs to `shipping`, never to a planning unit.

## 11. No-placeholder rule

Banned in any unit: "TBD", "TODO", "similar to Task N" / "see U3", "as appropriate", "etc.", "add appropriate error handling", steps that describe what to do without showing how, and references to types or functions not defined in any unit. Units may be read out of order by their implementer — repeat content rather than pointing sideways.

## 12. Self-review

Before finalizing, the author (not a subagent) checks:
- **Spec coverage** — every spec requirement traces to a unit; list gaps.
- **Scenario coverage** — re-walk the Scenario coverage map against the final unit set: every S-ID still completes end to end (deepening and unit edits are the likeliest breakage vector), and every map row names a real integration test scenario. `enforces: P3`
- **Placeholder scan** — search for step 11's red flags; fix inline.
- **Type consistency** — do signatures, names, and types agree across units (a function `clearLayers()` in U2 and `clearFullLayers()` in U5 is a bug)?
- **Callers + invariants** — for code units, who calls the functions being changed, and what invariants must still hold afterward?
- **Retro carryover** — does a prior retrospective's carry-forward item belong in this plan? Check the durable tracker before finalizing.

Fix issues inline; no separate review pass is needed.

## 13. Deepening pass

After self-review, run the confidence check in `references/deepening.md`: six trigger categories score the plan (vague rationale, missing risk treatment, weak sequencing, thin external grounding, unclear verification, thin scenario coverage) — skip deepening entirely when nothing scores. When triggered, dispatch reviewer personas — Architecture and Feasibility always-on, Security/Risk and Scope/Coherence conditional on activation signals — per the dispatch ladder in `references/dispatch-degradation.md` (native parallel → sequential passes; correctness never depends on parallelism being available). Change discipline: tightening prose is in scope; writing implementation code is not; U-IDs are never renumbered; superseded text is resolved in place, never stacked as a separate layer.

## 14. Outstanding-question triage

Classify every open question as planning-owned (resolvable from repo context, docs, or a user choice made now) or a product blocker (would change scope, behavior, or success criteria). Never plan over a live product blocker — surface it and either send the user back to `designing` to resolve it, or convert it to an explicit assumption before continuing.

## 15. Commit the plan

Write to `docs/plans/YYYY-MM-DD-NNN-<type>-<name>-plan.md` per the naming rule in `schemas/plan-schema.md`, then `git add` and commit following the repo's commit protocol. From this point the plan is a decision artifact — `implementing` never edits its body.

## 16. Handoff

Offer a 2-option menu: **Subagent-driven** (fresh subagent per unit, review between units — recommended) or **Inline** (execute in this session with checkpoints between units). Fire the chosen path; don't just announce it.

When invoked headless from `release-loop` or any pipeline caller, skip the menu: write the plan's path to `.release-loop/progress.md`'s `Plan:` field and return control to the caller.
