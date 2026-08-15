# Deviation Addendum 012: Discrimination effect binding and verdict complement coverage

_Recorded 2026-08-15 after spec approval and revised while the implementation plan remained draft. Approval authority remains the user at the plan gate; this document grants no plan approval or execution authorization._

## Original contract

The approved spec fixes both shipped wordings verbatim in `docs/specs/2026-08-15-planning-discrimination-and-verdict-coverage-design.md`, section `### Interface — the exact wording to ship`.

The original Discrimination check requires one fixture pair, says identical inputs compare equal and one changed input compares different, rejects different artifact kinds, and says a guard that cannot fail is not a guard.

The original Verdict coverage check derives values from the union of the emitting step's declared output set and the origin spec's enumeration, adds failure to resolve, requires each value's own next step, rejects a catch-all, and handles unconsumed verdicts.

Those wordings were themselves the product of the Design-gate invariant attack recorded in `docs/reviews/2026-08-15-planning-discrimination-and-verdict-coverage-spec-review.md`.

## Discovered contradictions

Independent plan reviews constructed artifacts that satisfy the approved wording while retaining the defects.

1. **The changed input can miss the axis under test.** A step claims to verify `--optimize` by comparing `coremldata.bin` digests, although the option affects `weights.bin`. Its fixtures use the same kinds and pipeline; identical inputs compare equal; swapping an unrelated source package makes the changed-input pair compare different. The comparison still says nothing about `--optimize`.
2. **One fixture pair cannot prove two controlled relations.** Same-input equality and changed-axis difference require separate pairs. The singular `a fixture pair` and `the pair plus the two results` do not identify both baselines, both changed-axis fixtures, or which result belongs to which relation.
3. **Any changed output can shadow an unchanged effect.** The changed option may alter metadata or a receipt while the effect-bearing output stays identical. A package digest can therefore differ even though the option did not produce the effect the step claims to verify.
4. **An always-successful guard can evade structural wording checks.** The original conclusion says such a guard is invalid, but it does not require the author to run and record one accepted and one rejected fixture. A positive pass/fail execution obligation makes the conclusion auditable.
5. **One out-of-set value does not cover the set's complement.** With known values `{0,1}`, a plan can add a branch for representative value `2` while emitted value `3` remains branchless. Enumerating examples cannot close an unbounded complement; the check must require a category-specific next step for any value outside the known set.

The historical issue #11 evidence and the reviewer constructions are distinct. H3 actually observed a comparison between different artifact kinds and also observed identical `.mlpackage` conversions whose model and weight data matched while fresh `Manifest.json` UUIDs made whole-package digests differ. The later `coremldata.bin`/`weights.bin` example is a reviewer-constructed same-kind extension. Issue #12 reported a branchless third verdict; it did not prescribe the disjunctive enumeration source that the Design review later attacked.

6. **The approved architecture cannot discharge its own retained lifecycle obligations.** The specification limits the shipped behavior file to `skills/planning/SKILL.md`, but the carry-forward audit requires live loop state to survive Ship cleanup and SC6 requires human-gated issue closure after merge. Existing `shipping` removes the feature worktree before either obligation is transferred to the base checkout, and existing `release-loop` advances directly from Ship to Retro without consuming approved-plan transitions. Plan review therefore proved that prose inside the plan would be unreachable after cleanup.

## Decision

The approved spec stays unchanged as the historical decision record. This addendum replaces both exact bullets for the draft plan.

This addendum also supersedes the approved spec's one-behavior-file architecture only for lifecycle closure. The draft plan adds one generic, body-sealed approved-plan transition hook to each of `skills/shipping/SKILL.md` and `skills/release-loop/SKILL.md`. The hooks recognize exact transition headings, require globally unique IDs and explicit matrix-row ownership, fail closed on missing or ambiguous mappings, preserve local state before worktree removal, and retain the first-hand confirmation gate for outward actions. The plan's R1 and R2 sections are the first consumers; neither transition is an `implementing` unit.

```text
- **Discrimination check** — for every step that compares two things, run the step's own comparison on two controlled fixture pairs. Both pairs use the same artifact kinds as the step's real comparands and the same command or pipeline that produces them. The invariance pair runs identical inputs and configuration twice; the changed-axis pair differs only in the input or option whose effect the step exists to detect. Name the effect-bearing signal or subartifact the comparison measures, and record both fixture pairs and both observed results in the step. The invariance pair must compare equal; the changed-axis pair must compare different in that named signal or subartifact. A difference confined to metadata, a receipt, or another output unrelated to the specified effect does not satisfy the changed-axis result. Different artifact kinds in the real comparands or either fixture pair fail this check outright: they always differ, so the comparison cannot report anything about the change. For every guard, run and record one fixture that must pass and one minimally changed fixture that must fail; a guard that accepts both is not a guard.
```

```text
- **Verdict coverage** — for every unit that emits a verdict, decision, or classification, derive the known value set from the union of the emitting step's declared output set and the origin spec's own enumeration — never from recall, and never from the narrower of the two. Cover that set's full complement as two explicit outcome categories: the measurement fails to resolve, or it resolves to any value outside the known set; one representative out-of-set value does not cover the rest. Confirm every known value and both complement categories have their own value- or category-specific next step; a single catch-all consumer that acts on "whatever the verdict says" covers nothing. A value or category with no next step is a plan gap, not an implementation-time unknown. A known value deliberately out of scope goes to Deferred to Follow-Up Work with its reason, and a verdict no unit consumes is itself either a gap or a deliberate Deferred entry.
```

The plan's SC2 and SC3 rubrics use the complete replacement text. They do not treat the added clauses as optional patches.

## Necessity

Each new obligation closes a demonstrated false-green path:

- two controlled pairs distinguish invariance from discrimination;
- axis binding prevents an arbitrary input from manufacturing difference;
- effect-bearing-signal binding prevents metadata or receipt drift from standing in for the specified effect;
- explicit pass/fail guard fixtures turn the guard conclusion into observed evidence;
- categorical complement coverage prevents representative out-of-set values from hiding another branchless result.

The H3 fresh-UUID case remains a separate SC2 reject case because it proves that even same-input conversions can violate the invariance half when the chosen digest includes nondeterministic metadata.

Editing the approved spec would erase the original approved wording and the review sequence that explains these clauses. The draft plan can change freely until approval; after approval, `body_seal` protects it.

## Observable behavior

The shipped behavior changes in exactly four files:

- `skills/planning/SKILL.md` step 14 receives the two approved self-review bullets;
- `skills/shipping/SKILL.md` Step 8 receives the generic pre-removal transition hook needed to preserve approved-plan local state before worktree deletion;
- `skills/release-loop/SKILL.md` receives the generic post-Ship completion hook and resume-time handoff recovery rule needed to discharge a body-sealed plan before Retro;
- `skills/release-loop/references/progress-schema.md` defines `branch` as the current checkout branch, including the `base_branch` value after verified authoritative handoff.

For future plan authors, the planning checks require:

- a comparison records two controlled pairs, the real producing pipeline, the varied axis, the named effect-bearing signal or subartifact, and both observed results;
- a guard records one passing and one failing fixture;
- a verdict-emitting unit covers every known value plus the unresolved and any-outside-known-set categories with value- or category-specific next steps.

A plan with no comparison, guard, verdict, decision, or classification remains unaffected by the two planning checks. Approved-plan transition hooks are likewise inert unless a body-sealed plan contains an exact recognized transition heading and a one-to-one matrix mapping.

## Safety and consent boundaries

The planning wording adds no outward action. The lifecycle hooks grant no authorization: local transitions require a fixture-proven unreachable outward boundary, and outward transitions remain blocked until first-hand point-of-risk USER confirmation. Issue comments and closure remain a separate human-discharged boundary. The draft plan requires committed payloads, a separate non-authorizing command packet, point-of-risk confirmation, a first-hand execution owner, durable approval and recovery records, and post-action body/state verification.

## Verification changes

- U1 and U2 acceptance extract each complete bullet, normalize whitespace, and require literal SHA-256 digests. Token-only substitutes cannot pass.
- Mutation probes delete the full-complement, catch-all, unconsumed-verdict, two-pair, changed-axis, effect-bearing-output, and guard-failure clauses one at a time; every mutant must fail the complete-bullet check.
- SC2 rejects: different artifact kinds; fresh UUIDs making identical whole-package digests differ; a same-kind comparison varied along an irrelevant input; metadata-only difference with an unchanged effect-bearing signal; and a guard accepting both fixtures. It accepts only separate invariance and changed-axis pairs with observed equal/different results in the named effect-bearing signal, plus a guard with observed pass/fail results.
- SC3 rejects both the original missing-third-verdict shape and `{0,1}` with a special branch for `2` but no category handling for `3`. It accepts only full known-set coverage plus unresolved and any-outside-set category handling.
- U3 distinguishes H3 observations from reviewer constructions and does not attribute the Design review's enumeration-source loophole to issue #12.
- U4 extracts both exact hook contracts, requires normalized literal SHA-256 digests, and deletes each eligibility, ordering, identity, resume, and consent clause in turn; every mutation must change the accepted contract.
- T5 uses only disposable linked worktrees and external sentinels. It covers success; foreign repository, identity collision, and destination/`.handoff/`/`archive/`/live-child symlink rejection; failure after backup and mid-install before the progress commit point; rerun from both owner-marker seams; rollback before cutover; headless local transfer; and cancellation/resume before, during, and after R1.
- U4's R2 integration fixture covers the full `shipping` merged-clean → R2 → Phase-6 boundary: direct success; decline; headless mode; fail-closed read; post-write failure with fresh-approval recovery and no duplicate mutation; cancellation after R2 start; durable blocked/approval/recovery fields; independent terminal verification; and Phase-6 exclusion until SC6 passes.
- The progress-schema acceptance requires exactly one base-handoff-aware `branch` line and rejects the obsolete feature-only form while retaining `phase: ship`, `phase_status: in-progress`, and `merged: true`.
- U5 independently attacks the final lifecycle for one-to-one transition/matrix mapping, merge-versus-discard ordering, same-session R1 ownership, path identity and symlink escape, crash recovery, resume routing, durable point-of-risk consent, and terminal-state gating. Its bounded committed verdict must be `clean`.

## Traceability

- Approved specification: `docs/specs/2026-08-15-planning-discrimination-and-verdict-coverage-design.md` (unchanged).
- Draft plan carrying the replacement wording and expanded rubrics: `docs/plans/2026-08-15-001-fix-planning-discrimination-and-verdict-coverage-plan.md`.
- Design-gate findings: `docs/reviews/2026-08-15-planning-discrimination-and-verdict-coverage-spec-review.md`.
- Plan-gate findings: `docs/reviews/2026-08-15-planning-discrimination-and-verdict-coverage-plan-review.md`.
- Lifecycle hook implementations and ledger schema: `skills/shipping/SKILL.md`, `skills/release-loop/SKILL.md`, and `skills/release-loop/references/progress-schema.md`.
- U3 disposable packet evidence: `.release-loop/evidence/U3/`.
- U4 disposable transition evidence: `.release-loop/evidence/U4/` (six T5 transfer records, six T6 consent-gate records, and six T7 SC6-completion records).
- U5 bounded implementation review: `docs/reviews/2026-08-15-planning-discrimination-and-verdict-coverage-implementation-review.md`.
- Historical issue #11 source: `https://github.com/teslamint/compound-loop/issues/11`.
- Historical issue #12 source: `https://github.com/teslamint/compound-loop/issues/12`.
- Tracker mandate: `ROADMAP.md` line 59.
- Addendum authority: `docs/solutions/workflow-issues/review-introduced-state-machine-deviation.md`.
