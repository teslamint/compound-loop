# Deepening Pass

The confidence check `planning` step 15 invokes after self-review. Distinct from a general document review (clarity, simplification, scope control): this pass strengthens rationale, sequencing, risk treatment, and system-wide thinking when a plan is structurally sound but still thin somewhere. `enforces: P4` (complexity must earn its keep — the pass itself must not manufacture ceremony where nothing scored).

## 1. Score the plan against six trigger categories

Walk the plan once; a category "scores" when its checklist below finds a real instance, not a hypothetical one.

| Category | Look for |
|---|---|
| Vague rationale | A Key Technical Decision or unit whose "why" restates the "what" ("use a queue because queuing is needed"); a decision with no rejected alternative or no stated trade-off where one plausibly exists |
| Missing risk treatment | The plan touches a high-risk surface (auth, payments, migrations, external APIs, privacy/compliance) with no Risks & Dependencies content, or a risk is named without a mitigation or explicit acceptance |
| Weak sequencing | Units reference dependencies out of order, a later unit assumes an interface an earlier unit doesn't produce, or parallelizable units are needlessly serialized (or vice versa — a hidden dependency forced into parallel unit lists) |
| Thin external grounding | The plan makes a claim about a library, framework, or external system's behavior with no cited source, version, or local pattern backing it — especially when local precedent was sparse (fewer than 3 direct examples) |
| Unclear verification | A unit's Acceptance criterion is not independently checkable (no command, no observable behavior) or is missing entirely for a feature-bearing unit |
| Thin scenario coverage | A Scenario coverage map row whose unit chain has a gap or hand-waved hop; a user scenario (S-ID) with no `Covers S<n>` integration test scenario; integration scenarios that are purely technical while spec scenarios go unwalked |

## 2. Gate: skip when nothing scores

If no category scores, stop here — report "confidence check passed, no sections need strengthening" and proceed to step 16. Running personas over a plan with nothing to find is ceremony without a requirement behind it (`enforces: P4`). Do not force a score to justify running the pass.

## 3. Persona roster

Four personas, distilled from `ce-doc-review`'s activation-signal pattern down to the two axes this plugin cares about for plans.

**Architecture** (always-on). Checks unit boundaries, dependency ordering, whether the File Structure phase's split still holds after units were drawn, and whether a KTD is load-bearing enough to deserve its own unit rather than being folded in.

**Feasibility** (always-on). Checks whether the plan is actually buildable as specified: do Interfaces (Consumes/Produces) agree across units, does the file structure match what the codebase can support, is the unit count realistic for the stated scope.

**Security/Risk** (conditional). Activate when the plan contains any of:
- Auth, authorization, session, or credential handling
- Payments, PII, or other regulated/sensitive data
- A data migration, backfill, or destructive schema change
- A new external integration or trust-boundary crossing
- A greenfield architectural pattern with no prior local precedent to validate it

Do **not** activate on a routine plan confined to internal, already-precedented code with no sensitive-data or destructive-operation surface — the plan's normal thoroughness is not itself a signal.

**Scope/Coherence** (conditional). Activate when the plan contains any of:
- More than 8 implementation units, or units spanning more than one clearly distinct subsystem
- Stated priority tiers, stretch goals, or a "future work" list living inside active units rather than Deferred to Follow-Up Work
- A Requirements-to-Units trace that looks incomplete on a skim (a requirement with no obvious owning unit)
- Scope Boundaries language that reads inconsistent with the units actually defined

Do **not** activate on a small, single-subsystem plan with a clean requirements trace — routing every plan through this persona regardless of size defeats the trigger scoring in step 1.

## 4. Dispatch

Follow `references/dispatch-degradation.md` (repo-root shared reference) unmodified: native parallel subagents first, one per activated persona, each self-contained and given only the plan text plus its persona brief; sequential passes when no parallel primitive exists; single-call fallback (one prompt runs all activated personas serially and self-merges) when neither is available. Correctness never depends on which tier ran — only wall-clock time does. A concurrency-limit error is backpressure, not a persona failure.

## 5. Auto vs. interactive mode

- **Auto mode** (default, runs inline right after self-review during normal plan generation): findings are synthesized directly into the plan. The user sees what changed but does not gate each change.
- **Interactive mode** (the user explicitly asked to "deepen" an already-existing, already-approved plan): present each persona's findings individually; the user accepts, rejects, or discusses before it lands. Only accepted findings get synthesized. This mode exists because a user revisiting a plan they're already invested in wants to be surgical, not re-run the whole pass silently.

Headless/pipeline invocations always run in auto mode — there is no synchronous user to gate findings interactively.

## 6. Change discipline

Applies to every finding integrated, in either mode:
- Tightening prose, adding a missing rationale sentence, or filling a thin Risks entry: in scope.
- Writing or editing implementation code, imports, or exact method signatures: never — findings land as plan-level decisions, not code.
- Renumbering U-IDs to "clean up" a gap or reorder: never, regardless of how the deepening pass reshuffles unit presentation order.
- Resolve superseded text in place — rewrite or delete the original sentence a finding corrects. Do not leave it standing with strikethrough or stack a separate "deepening notes" section on top of the plan; version control already holds the history, and stacked strata double the reading surface for the next reader.
- When deepening an already-approved plan (interactive mode), recompute the body SHA-256 and write a new `body_seal` in the same commit as the body changes — this is the sole authorized re-seal path. No other editing path may update `body_seal` after the initial approval.

## v0.2 note

Cross-round evidence-overlap suppression (skip re-surfacing a finding the user already rejected in a prior deepening round on the same plan, keyed on evidence-snippet overlap) is a documented hook point only, deferred to v0.2 per the design spec. v0.1's interactive mode does not suppress repeat findings across separate deepening invocations on the same plan — each round evaluates fresh.
