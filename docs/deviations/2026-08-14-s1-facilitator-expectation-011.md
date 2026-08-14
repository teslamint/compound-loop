# Deviation Addendum 011: The S1 Facilitator Expectation

_Recorded 2026-08-14 at the PR review gate, before merge._

One approved artifact contradicted another. Scenario S1 of the approved specification stated a
dispatched facilitator level that the shipped dispatch ladder does not select under S1's own
stated conditions. The specification text was corrected; the ladder was already right. This
addendum records the correction, in the same form addenda 008 through 010 set on this branch.

## Original contract

Scenario S1 of the approved specification sets up a run where two facilitator channels are both
reachable, then names the level the run takes. `docs/specs/2026-08-14-retro-interview-integrity-design.md`
line 22, pre-correction, opening and closing sentences of the paragraph:

```text
A retro runs with `mode:headless` on Claude Code, where a subagent tool and a Codex CLI are both available.
```

```text
The run dispatches a same-model fresh-context facilitator instead.
```

`same-model fresh-context` is rung 2 of the ladder.

## Discovered contradiction

The shipped dispatch ladder selects rung 1 under those conditions. `skills/retrospective/SKILL.md`
line 76 names the heterogeneous path and the CLI that provides it from Claude Code:

```text
a *heterogeneous* model is better when the environment offers one (from Claude Code, `codex exec` for a GPT-family facilitator; from Codex, a Claude subagent)
```

and orders the degradation, same line:

```text
heterogeneous facilitator → same-model fresh-context subagent → sequential passes
```

S1 stipulates a Codex CLI on Claude Code. That is exactly the environment the selection clause
calls heterogeneous, and the degradation order reaches rung 2 only after rung 1 is unavailable.
So the two approved documents demanded different dispatch results from identical conditions.

The contradiction is confined to S1's closing sentence. S1's point — that a headless run no
longer reads as entitled to the self-checklist floor — is delivered by either level, because
either is above the floor. The sentence named the wrong one of the two.

## Decision

Correct S1's closing sentence to name the level the ladder selects:

```text
The run dispatches a heterogeneous facilitator instead.
```

The ladder is not touched. It is the artifact agents execute, its selection rule is correct, and
S1 is an illustration of that rule rather than a second source of it. Only the illustration was
wrong, so only the illustration changes. The correction reuses the ladder's own term for rung 1
rather than introducing a third phrasing, and it does not restate the ladder inside the scenario.

Decision owner: the user, at the PR review gate, 2026-08-14, after an external reviewer raised
the inconsistency on PR #13.

The specification's `status: approved` field is unchanged. This is an erratum to an approved
artifact, not a re-approval: the scenario's stated conditions, its purpose, and every other
scenario and section stay as approved.

## Necessity

The sealed plan cannot carry the correction. Editing an approved plan body breaks its body seal,
and re-sealing outside interactive deepening would erase the approval boundary — the same
constraint addenda 008 through 010 record.

Leaving the contradiction unrecorded is the alternative this branch has three times rejected. A
reader comparing the specification's git history to the ladder would otherwise find an
unexplained edit to an approved document and no way to tell a review-gate decision from an
unauthorized rewrite.

## Observable behavior

No `retrospective` runtime behavior changes. The dispatch ladder is what executes, and it was
already correct; a run in S1's environment dispatched a heterogeneous facilitator before this
correction and dispatches one after it. This addendum and its commit correct a description of
the rule, never the rule.

No skill prose, template, checker code, or scenario other than S1's closing sentence changes.

## Safety and consent boundaries

This addendum grants no execution authority and changes no gate.
Existing review and merge gates remain unchanged.

The correction was made under an explicit user decision at the review gate; no artifact was
re-approved and no approval status was altered.

## Verification changes

- Run `./scripts/validate.sh` and require exit 0, including the `[body-seal]` check reporting
  its verified count, which proves the sealed plan was not disturbed by the specification edit.
- Run `./scripts/test-retro-format-drift.sh` and require all cases to pass.
- No new case is added. The checker reads retrospective documents, not specification scenarios,
  and the corrected sentence changes no document the checker can observe.

## Traceability

- Source artifact: `docs/specs/2026-08-14-retro-interview-integrity-design.md`, scenario S1,
  line 22.
- Corrected text: S1's closing sentence, `same-model fresh-context facilitator` →
  `heterogeneous facilitator`.
- Evidence for the correction: `skills/retrospective/SKILL.md` line 76, the facilitator model
  selection clause and the degradation order.
- Approved plan: `docs/plans/2026-08-14-001-fix-retro-interview-integrity-plan.md`, unchanged.
- Decision basis: S1's stipulated environment satisfies rung 1's condition, so the ladder cannot
  reach rung 2 there.
- Correction precedents: `docs/deviations/2026-08-14-w1-measured-section-heading-008.md`,
  `docs/deviations/2026-08-14-in-thread-capability-scope-009.md`, and
  `docs/deviations/2026-08-14-checker-precedence-and-w1-strictness-010.md`.
- Addendum authority: `docs/solutions/workflow-issues/review-introduced-state-machine-deviation.md`.
