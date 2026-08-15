# Plan Schema

The contract between `planning` (producer) and `implementing` / `reviewing` (consumers). A plan is a **decision artifact, not an execution script**: consumers never edit the plan body; execution progress lives in commits and the progress ledger.

## File naming

`docs/plans/YYYY-MM-DD-NNN-<type>-<name>-plan.md` — `NNN` is a per-day sequence number (collision-safe), `<type>` matches the frontmatter `type`.

## Frontmatter (required unless marked optional)

```yaml
---
schema: plan/v1                   # contract version; consumers reject unknown versions
title: Human-readable plan title
type: feat | fix | refactor | chore | docs
status: draft | approved | done | superseded  # draft commits first; approved is a separate commit after the USER gate (skills/planning/SKILL.md)
date: YYYY-MM-DD
execution: code | non-code | ops  # selects the unit template
origin: <path to spec>            # optional; enables retro's measured-vs-declared pass
deepened: true                    # optional; set by the deepening pass
body_seal: <64-char lowercase hex SHA-256>  # optional; set at approval, verified by validate.sh check 14
completed_by: <commit>            # required when status: done
superseded_by: <path to successor plan>  # required when status: superseded
---
```

## Status lifecycle

`status` moves `draft → approved → done | superseded`, or directly `draft → superseded`; `done` and `superseded` are the terminal states.

- **`done`** requires a non-empty `completed_by:` naming the commit on the base branch that landed the plan's work — normally the merge commit; the squashed or fast-forwarded tip when no merge commit exists. `retrospective` writes it in the same commit as the retro doc. `draft → done` is invalid.
- **`superseded`** requires `superseded_by:` resolving to an existing repo-root-relative plan path, written by `planning` in the same commit that commits the successor. The successor's status is irrelevant; `draft → superseded` is valid. Direction is predecessor→successor only — no backlink.
- **Mutable slots** (spec R5): the body is immutable after the approved commit; the `status` field, its terminal-state evidence field, and `body_seal` are the plan's only mutable slots.
- **Rejection records** (spec R4): `in-progress` — live execution state lives in commits and the progress ledger; a committed second copy is a dual source of truth that a dead session latches permanently. `abandoned` — zero observed instances; the observed need is `superseded`, which carries a successor pointer the rejected value has no slot for.
- **Unknown fields** (spec R6): consumers and the validator reject unknown `schema:` versions, never unknown fields.
- **Applicability** (spec R8): terminal-state rules apply to plans first committed after this contract lands — keyed on the plan's creation, not its approval; no terminal state is backfilled onto earlier plans. Corpus conformance is asserted for this checkout only, never for `plan/v1` as a published contract.

## Body seal

`body_seal` stores the lowercase SHA-256 hex digest of the plan's markdown body. Every implementation reads the file as UTF-8 text with universal-newline translation, exactly `open(path, encoding="utf-8", newline=None).read()`. It then extracts the body with the literal expression `text.split('---', 2)[2]`: the first two delimiter occurrences are consumed, no delimiter-line reinterpretation or stripping occurs, and the newline after the second delimiter remains part of the body. The extracted text is encoded as UTF-8 and hashed with SHA-256.

For a worked example, the sealed plan `docs/plans/2026-08-14-001-fix-schema-reference-and-seal-verification-plan.md` has this complete stored digest:

```text
3264db823d75aba9a12ecf84c197059a2460b9c69d154c44ec4a6280f2779681
```

The following independent reproduction prints the digest for any plan without importing the shipped validator:

```bash
python3 - docs/plans/2026-08-14-001-fix-schema-reference-and-seal-verification-plan.md <<'PY'
import hashlib
import sys

with open(sys.argv[1], encoding="utf-8", newline=None) as handle:
    text = handle.read()
body = text.split('---', 2)[2]
print(hashlib.sha256(body.encode("utf-8")).hexdigest())
PY
```

Use the shipped validator to print a seal, then verify one plan normally:

```bash
python3 skills/planning/scripts/validate-plan-frontmatter.py --print-seal <plan-path>
python3 skills/planning/scripts/validate-plan-frontmatter.py <plan-path>
bash scripts/validate.sh
```

- **Creation**: first commit the complete plan as `status: draft` without `body_seal`. After the user gives explicit approval, compute the seal from the unchanged body and make a second commit that changes only `status: approved` and adds `body_seal`. The approval commit must not alter any body line or other frontmatter field.

The two commits are explicit:

```bash
git add <plan-path>
git commit -m "docs(plan): create draft"
# After first-hand user approval, update only status and body_seal.
git add <plan-path>
git commit -m "docs(plan): approve plan"
```
- **Re-sealing**: interactive deepening is the ordinary and only post-approval reseal path. Adoption migration is the one-time release exception described below, not a generic bypass.
- **Absence**: valid. Plans without `body_seal` are not sealed; check 14 skips them. Plans predating this contract are never backfilled.
- **Limits**: a seal is tamper evidence, not tamper prevention. Authorization is audited through commit history and review; a user who can edit and re-seal can make the digest match a changed body, so the seal cannot establish who authorized that edit.

### Adoption-only migration

During adoption of this release, one reseal may replace an existing seal only when the first-hand user approval, exact pre-upgrade baseline commit, repo-relative plan path, old seal, new seal, canonical reproduction command, and baseline/current canonical-body equality are all present. The migration commit changes only `body_seal`; its message records `(baseline commit, plan path, old seal, new seal)`, the reproduction command, and the approval. A changed body or missing baseline rejects with the named `changed-body` or `missing-baseline` diagnostic. Missing evidence rejects while naming the missing field: approval, baseline commit, plan path, old seal, new seal, or reproduction command. Any later ordinary reseal is rejected unless interactive deepening authorizes it. After an interruption, fresh first-hand approval is mandatory.

The migration check below is the executable oracle used by the adoption branch. It accepts `<baseline-commit> <plan-path>`, reads `git show <baseline>:<path>` and the current plan with UTF-8 and universal-newline semantics, extracts both canonical bodies literally, exits 0 only when they are equal, and exits 1 with a named diagnostic otherwise.

<!-- body-seal-migration-check:begin -->
```python
import io
import subprocess
import sys


def universal_text(data: bytes) -> str:
    return io.TextIOWrapper(io.BytesIO(data), encoding="utf-8", newline=None).read()


def canonical_body(text: str) -> str:
    return text.split('---', 2)[2]


if len(sys.argv) != 3:
    print("usage: migration-check.py <baseline-commit> <plan-path>", file=sys.stderr)
    raise SystemExit(2)

baseline, plan_path = sys.argv[1:]
baseline_result = subprocess.run(
    ["git", "show", f"{baseline}:{plan_path}"],
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE,
    check=False,
)
if baseline_result.returncode != 0:
    print(f"missing-baseline: {baseline}:{plan_path}", file=sys.stderr)
    raise SystemExit(1)

with open(plan_path, encoding="utf-8", newline=None) as handle:
    current_text = handle.read()
baseline_text = universal_text(baseline_result.stdout)
if canonical_body(current_text) != canonical_body(baseline_text):
    print(f"changed-body: {plan_path}", file=sys.stderr)
    raise SystemExit(1)

print("unchanged-body")
```
<!-- body-seal-migration-check:end -->

### Fail-closed adoption outcomes

The adoption transition is fail-closed at every interruption boundary:

- `success`: with a clean baseline/current-equivalent state and approval, replace only the seal and commit once. HEAD advances once, the committed diff is one seal line, the message contains the exact evidence, and the tree is clean.
- `forced-failure`: if the operation fails after writing the seal but before commit, HEAD stays unchanged and exactly one target plan is dirty with a one-line seal diff; no migration commit exists.
- `rerun`: invoking again in that forced-failure state fails closed without another write or commit. Compensate first, obtain fresh approval, then make exactly one success commit with no duplicate transition.
- `compensation`: restore only the target plan from HEAD; its bytes and the worktree return to the pre-transition state, HEAD stays unchanged, and no migration commit exists.
- `headless`: without first-hand approval, exit nonzero before writing; HEAD and the worktree remain unchanged, with a diagnostic naming missing approval.
- `cancellation`: a pre-write cancellation leaves a clean state. A post-write cancellation first proves the forced-failure state, then operator-owned target-only compensation returns the tree clean; no commit is created.

- **Verification**: check 14 recomputes the same canonical body and compares it with the stored value. A mismatch is a failure; an extraction failure is also a failure with the shipped `body_seal` extraction diagnostic.

## Document body — hard floor

1. **Goal** — 1–3 sentences, forward-looking.
2. **Architecture notes** — decisions + rationale; pseudo-code only as directional guidance, never implementation code.
3. **Assumption Recheck** — required whenever the plan is written. If the origin spec retains live assumptions, rerun every retained command and record the approved claim, fresh command evidence, and one outcome: `match`, `contradiction`, or `unavailable`. If the plan has no origin spec, write exactly: `No origin spec; no approved live assumptions to recheck.` If the origin spec exists but retains zero live assumptions, write exactly: `Origin spec retains no live assumptions; no assumption recheck required.` A contradiction blocks plan finalization and commit until a separate committed addendum exists under `docs/deviations/`; preserve the approved spec and plan unchanged and follow `docs/solutions/workflow-issues/review-introduced-state-machine-deviation.md` for the addendum's content contract. An unavailable result remains a planning-time unknown unless the user narrows the claim enough to remove the missing evidence.
4. **File structure** — files to create/modify, grouped by responsibility (single-responsibility files, colocate what changes together, follow the existing codebase's scale).
5. **Scenario coverage map** — one row per User Scenario (S-ID) in the origin spec: the ordered chain of units that realizes it end to end, and the scenario evidence that walks it — for code plans, integration test scenario(s) tagged `Covers S<n>`; for non-code plans, a named observable verification per scenario (e.g. "a reader following README.md alone completes S1"), since non-code units carry no test field. A scenario with neither a completing unit chain nor walking evidence is a plan gap that blocks approval — either add the missing unit or send the scenario back to `designing` for explicit descoping. When the origin spec has no User Scenarios section (or no spec exists), state that in this section explicitly — never leave it absent. The map is the durable traceability record downstream verification runs against (`enforces: P8`); the fresh verification itself happens in `implementing`'s final branch review and `reviewing`'s tests lane (`enforces: P3` there, not here).
6. **Implementation Units** (see below).
7. **Mutation/failure-state matrix** — conditional on the deliverable containing a stateful ceremony: a workflow whose deliverable can cross an observable side-effect boundary. A durable transition is a step that changes persisted or externally observable state across invocations. Include one row per durable transition with transition identity, pre-state, action, expected post-state, owning implementation unit, and the evidence owner that will produce disposable fixture evidence under `.release-loop/evidence/U<N>/`. Fill all six outcome classes: success; forced failure; rerun; rollback or compensation; headless; and cancellation or abort. Blank cells are invalid; every not-applicable cell must contain a concrete reason tied to the interface or irreversibility boundary. Forced-failure outcomes name a safe injection boundary and isolation approach; irreversible transitions name compensation or explicit manual recovery. Link `skills/planning/references/stateful-ceremony-matrix-example.md` and `docs/solutions/workflow-issues/review-introduced-state-machine-deviation.md` rather than duplicating their contracts. Changing an approved row or outcome is observable behavior and triggers item 3's deviation-addendum rule before release. When the deliverable has no stateful ceremony, write exactly: `No stateful ceremony in the deliverable; no mutation/failure-state matrix required.`
8. **Carry-forward trigger audit** — records the planning-time trigger audit: the classification of every open carry-forward tracker row's trigger — edit-based (fires on a named file or section being touched), drift-based (fires on a named record shape deviating), or event-based (fires on a future occurrence) — diffed against the plan's file list and observable record state. Three record shapes, lean by design: one row per fired trigger (tracker row, trigger class, what fired it, disposition with reason — "what fired it" is a deliberate one-field addition to spec R5's enumeration, approved with docs/plans/2026-07-24-001-feat-planning-trigger-audit-plan.md); one row per unobservable drift-based trigger (tracker row, the named record, why it is not observable at planning time); and one always-present attestation line in the fixed template `Audited <tracker location> at <tracker state>: <N> open rows, <M> fired, <K> unobservable.` where tracker state is a commit or equivalent identifier. Fired includes latched rows: a firing already recorded in the tracker or a prior retro counts regardless of current observability. When no trigger fired and nothing is unobservable, the section is the attestation line alone. A fired trigger's disposition is fold-as-unit or a Deferred to Follow-Up Work entry naming the row and the reason; a fired row with neither blocks approval. When the repo has no durable tracker, write exactly: `No durable carry-forward tracker in this repo; no trigger audit possible.`
9. **Deferred to Follow-Up Work** — tangential discoveries and scope creep land here, never in units (`enforces: P4`).
10. **Open unknowns** — split into *planning-time* (must resolve before approving the plan) and *implementation-time* (deferred implementation notes: exact method names, final SQL, runtime-dependent behavior — resolved during execution, listed so they are not mistaken for gaps).

## Implementation Unit template

U-IDs are **stable and unique**: never renumbered on reorder, split, or delete (`U7` stays `U7`; a split yields `U7a`/`U7b`; a deleted unit's ID is never reused). A "Covers AE<n>" or "Covers S<n>" link naming an acceptance criterion or user scenario that does not exist in the spec is a validation error, not a soft warning.

### Code unit (`execution: code`)

```markdown
## U<N>: <unit title>
Execution note: test-first | characterization-first | skip-test-first
Files:
  Create: <paths>
  Modify: <paths>
  Test: <paths>
Interfaces:
  Consumes: <exact signatures / types this unit uses>
  Produces: <exact signatures / types this unit exposes>
Test scenarios:                     # categorized; link acceptance criteria as "Covers AE<n>",
                                    # user scenarios as "Covers S<n>" (integration scenarios
                                    # are derived from the spec's User Scenarios first)
  happy: <scenario>
  edge: <scenario>
  error: <scenario>
  integration: <scenario, "Covers S<n>" where it walks a user scenario, or "n/a — leaf unit">
Steps:                              # 2–5 minute literal steps; TDD baked in
  1. Write failing test <path>::<name> asserting <behavior>
  2. Run it; confirm it fails because <expected reason>
  3. Implement minimal code in <path>
  4. Run tests; confirm pass, no regressions
  5. Commit: "<message>"
Acceptance: <verifiable check(s) — command or observable behavior>
```

### Non-code unit (`execution: non-code`)

```markdown
## U<N>: <unit title>
Files:
  Create/Modify: <paths>
Steps:
  1. Write <artifact> covering <required content>
  2. Self-review against <spec section / checklist>
  3. Commit: "<message>"
Acceptance: <verifiable check(s)>
```

## Rules

- **No placeholders**: banned phrases include "TBD", "similar to Task N", "as appropriate", "etc." — every unit is self-contained because implementers may read units out of order and see only their own unit.
- **Right-sizing**: a unit is the smallest change worth a fresh reviewer's gate; 3–7 units is typical — >10 suggests under-decomposition, <3 suggests the plan may not be warranted at all.
- **Zero-context test**: an engineer with no codebase knowledge and only this unit's text can implement it.
- **Prose economy**: one idea per sentence; a requirement is intent plus at most one qualifier; forks go to Open unknowns, not both arms written out; resolve superseded text in place.
