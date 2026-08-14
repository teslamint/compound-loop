# Deviation Addendum 009: In-thread Capability Scope

_Recorded 2026-08-14 during the final branch review, before merge._

## Original contract

The sealed plan states the capability grammar in its Architecture notes, line 33:

```text
- `phase8-capability` requires both anchors `no subagent primitive` and `no external facilitator CLI` on that same line.
```

The bullet names no independence level. Line 32 above it scopes `phase8-headless` with the
clause "when the `- Independence level:` line names a degraded level", and line 33 inherits
that scope, so the two-anchor rule reads as one rule for both degraded levels.

## Discovered contradiction

The approved specification and the shipped prose both split the two degraded levels.

`docs/specs/2026-08-14-retro-interview-integrity-design.md` line 147:

```text
For `self-checklist` the claim must cover both facilitator channels the ladder names, in the shape "no subagent primitive and no external facilitator CLI reachable in this harness". A bare "no subagent primitive" is insufficient, because the ladder's own rung 1 names `codex exec` as a facilitator channel independent of the subagent primitive — a subagent that dies does not establish that no facilitator was reachable. For `in-thread` the claim names why fresh context was unavailable.
```

`skills/retrospective/SKILL.md` line 116 ships the same split:

```text
A `self-checklist` claim names both facilitator channels of the ladder as absent — `no subagent primitive` and `no external facilitator CLI` — [...] An `in-thread (approximated independence)` claim names why fresh context was unavailable.
```

Two artifacts state the split, one states the merged rule. The merged rule is therefore a
transcription error in the sealed plan, not a deliberate dialect.

The consequence was live: a retro document following the shipped prose exactly — level
`in-thread (approximated independence)` with a rounds-used line naming why fresh context was
unavailable — was rejected with `phase8-capability`. The checker contradicted the prose it
exists to prove. No `in-thread` fixture existed in the suite (C5, C6 and C7 are all
`self-checklist`), so no case could catch it.

## Decision

The artifact set resolves this without a new judgment call: the specification and the shipped
prose agree against the grammar bullet, two to one, and the bullet's own neighbours show the
level scope it omits. Align the checker to the specification and the shipped prose, and record
this addendum.

`cond_phase8_capability` in `scripts/test-retro-format-drift.sh` now branches on the level:

- `self-checklist` requires both facilitator-channel anchors, unchanged.
- `in-thread (approximated independence)` requires a reason clause after the round count.

The in-thread test is presence, not wording. The prose asks the author to name why fresh
context was unavailable, in whatever words that cycle's cause takes; a fixed phrase would
reject honest reasons the author did not phrase the way the checker expected, which is the
failure this addendum corrects rather than repeats.

The approved specification and the sealed plan stay unchanged as historical records.

## Necessity

Editing the approved plan body would break its body seal.
Re-sealing outside interactive deepening would erase the approval boundary.

Keeping the plan literal instead would make the checker reject every honest `in-thread`
document, which contradicts the checker's stated purpose: it is a second implementation of the
shipped prose, so a document the prose accepts and the checker rejects means the checker is
wrong, not the document.

## Observable behavior

No `retrospective` runtime behavior changes. The skill prose and the specification are
untouched; the checker moves toward them.

The fixture checker in `scripts/test-retro-format-drift.sh` changes behavior. An `in-thread`
fixture naming a reason is accepted where it was rejected. An `in-thread` fixture carrying a
bare round count and no reason is rejected with `phase8-capability`. `self-checklist` behavior
is unchanged, and `cond_W4`'s zero-row path still requires both anchors, because the
specification puts `not-probed`'s no-channel path on the same claim `self-checklist` carries.

## Safety and consent boundaries

The checker reads disposable fixture documents only.
It never reads `docs/retros/` and it is not a repository linter.

This addendum grants no execution authority.
Existing review and merge gates remain unchanged.

## Verification changes

- Run `./scripts/test-retro-format-drift.sh` and require all cases to pass.
- Require case C22 to accept: `in-thread` naming why fresh context was unavailable, which is
  the document the shipped prose describes.
- Require case C23 to reject with `phase8-capability`: `in-thread` with a bare round count and
  no reason, which proves the scoping did not remove the condition for that level.
- Require cases C5, C6 and C7 to keep their `self-checklist` verdicts, which proves the
  scoping left the other degraded level alone.

## Traceability

- Approved specification: `docs/specs/2026-08-14-retro-interview-integrity-design.md` line 147.
- Shipped prose: `skills/retrospective/SKILL.md` line 116.
- Approved plan: `docs/plans/2026-08-14-001-fix-retro-interview-integrity-plan.md`.
- Divergent plan text: Architecture notes line 33 only.
- Decision basis: the artifact set — two source artifacts against one grammar bullet.
- Correction precedent: `docs/deviations/2026-08-14-w1-measured-section-heading-008.md`,
  the same class resolved the same way at the U4 gate on 2026-08-14.
- Addendum authority: `docs/solutions/workflow-issues/review-introduced-state-machine-deviation.md`.
