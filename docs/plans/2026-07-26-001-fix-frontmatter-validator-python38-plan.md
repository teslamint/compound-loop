---
schema: plan/v1
title: Frontmatter Validator Runs on Python 3.8
type: fix
status: approved
date: 2026-07-26
execution: code
origin: docs/specs/2026-07-26-frontmatter-validator-python38-compat-design.md
---

# Frontmatter Validator Runs on Python 3.8 Plan

## Goal

Make `skills/compound/scripts/validate-frontmatter.py` execute on CPython 3.8
by deferring annotation evaluation, and register the drift exposure that choice
creates. The declared support contract does not move.

## Architecture notes

- **Deliverable classification**: code plan. One Python source file changes;
  one tracker document gains a row. Both units are gated on the existing bash
  harnesses, not on a new test file.
- **Mechanism**: `from __future__ import annotations` (PEP 563). It converts
  every annotation in the module to a stored string, so the six `list[str]`
  occurrences across five sites stop being evaluated at function-definition
  time. The spec's cross-model review lane compared this against `typing.List`
  imports, individually quoting each annotation, and deleting the annotations,
  and confirmed the future-import over all three; no lane dissented. It is one
  localized line, it cannot be partially applied, and it preserves the type
  information.
- **Placement is a constraint, not a style choice**: a `__future__` import must
  precede every other statement except the module docstring. Placed after the
  existing imports it is a `SyntaxError` on every interpreter, which is why the
  spec pins the position in R2 and why assumption A5 retains the proof.
- **Why no new test harness**: the repo's convention is bash fixture harnesses
  under `scripts/`, and the compatibility gate already extracts this exact file,
  compiles it on both declared boundary interpreters under
  `-W error::SyntaxWarning`, and byte-compares its copy against the repository
  file. A sixth harness for a one-line annotation change would duplicate that.
- **Contract untouched**: `schemas/python-support.json` keeps
  `minimum_minor: "3.9"`, so 3.8 gains *incidental compatibility* — it runs, but
  no boundary interpreter covers it and nothing mechanical keeps it working.
  That exposure is the reason U2 exists; the alternative (moving the floor)
  would supersede an approved spec and was declined by the user at the Design
  gate.
- **Unit independence**: U1 and U2 are separable — a reviewer can accept the
  source change and reject the tracker wording, or the reverse. These notes
  state decisions and rationale only; unit behavior is specified in the units
  themselves, never summarized here.

## Assumption Recheck

Origin spec `docs/specs/2026-07-26-frontmatter-validator-python38-compat-design.md`
retains eleven live assumptions (A1-A11). Every retained command was rerun
verbatim at `2026-07-26T07:44:43Z` against working tree `aa06bad`, comparing
exit status and the distinctive recorded output rather than exit status alone.
Rows A2-A5, A10, and A11 were rerun after recreating the spec's two throwaway
artifacts via its committed recipe.

| Claim | Approved result | Fresh result | Outcome |
|---|---|---|---|
| A1 — 3.8 fails, 3.9 passes | 3.8 `rc=1` w/ `TypeError` at L51; 3.9 `rc=0` | `3.8 rc=1  3.9 rc=0`, same `TypeError` text | match |
| A2 — patched copy passes on all four | `3.8 rc=0  3.9 rc=0  3.13 rc=0  3.14 rc=0` | identical | match |
| A3 — failure path, identical diagnostics, usage rc=2 | all four `rc=1`; stderr `identical`; `usage rc=2` | identical | match |
| A4 — compiles on both boundaries under `-W error::SyntaxWarning` | both exit 0 | `3.9 ok  3.14 ok` | match |
| A5 — misplaced future-import is a hard error | `SyntaxError: from __future__ imports must occur at the beginning of the file` | identical | match |
| A6 — structural validation green pre-change | `ALL CHECKS PASSED` | `ALL CHECKS PASSED` | match |
| A7 — publication engine already 3.8-clean | `rc=0` | `rc=0` | match |
| A8 — validator is the only committed `.py` | exactly one line | exactly one line | match |
| A9 — every swept document has frontmatter | no output; 10 files | no output; `files=10` | match |
| A10 — bug-track fixture passes on all four | `3.8 rc=0  3.9 rc=0  3.13 rc=0  3.14 rc=0` | identical | match |
| A11 — pre/post output identical on 3.9 and 3.14 | `IDENTICAL` on both | `pre/post IDENTICAL on 3.9+3.14` | match |

Eleven claims, eleven `match`, zero `contradiction`, zero `unavailable`. No
deviation addendum is required and plan finalization is not blocked. The
recheck followed
[`approved-assumption-evidence-command-contradiction.md`](../solutions/workflow-issues/approved-assumption-evidence-command-contradiction.md),
which requires comparing the *command's* reproducibility and not only the
underlying claim's truth.

## File structure

| File | Action | Responsibility | Unit |
|---|---|---|---|
| `skills/compound/scripts/validate-frontmatter.py` | Modify | Add the `__future__` import; nothing else in the file changes | U1 |
| `ROADMAP.md` | Modify | One new row in the `## Carry-forward from retros` table registering the drift exposure | U2 |

No file is created. No file is deleted.

## Scenario coverage map

The origin spec defines five user scenarios.

| S-ID | Scenario | Unit chain | Scenario evidence |
|---|---|---|---|
| S1 | Skill user whose `python3` is 3.8 runs the validator | U1 | U1 **happy** scenario `Covers S1` — the bug-track fixture on CPython 3.8 prints `OK: <path>` and exits 0 (step 4), widened to the whole corpus by the step-6 3.8-vs-3.14 sweep. The integration scenario cannot carry S1: `bash scripts/validate.sh` resolves its interpreters from the contract (`validate.sh:275`), so it never invokes 3.8 |
| S2 | Agent on a 3.8-ambient session reaches the exit-0 gate | U1 | U1 **happy** scenario, `Covers S2` — S2 and S1 are satisfied by the same 3.8 exit-0 observable; they differ in who is running it, not in what is measured |
| S3 | Retro author stops writing the 3.8 caveat | U1 | U1 **happy** scenario, `Covers S3` — the caveat exists only because the validator could not run on the ambient interpreter, so the 3.8 exit-0 observation on a real `docs/solutions/` document *is* the removal condition. No test asserts a future retro's prose; this is the honest proxy, recorded rather than overclaimed |
| S4 | Maintainer still gets a 3.9-floored repository | U1 | U1 **integration** scenario `Covers S4` — `bash scripts/validate.sh` ends `ALL CHECKS PASSED`, the gate resolving 3.9/3.14 from the untouched contract; plus U1 step 9's Criterion 5 diff proving `schemas/python-support.json` and the compatibility harness are byte-unchanged |
| S5 | Author of an invalid document still gets full diagnostics | U1 | U1 error scenario `Covers S5` — the `$d/bad.md` fixture on 3.8 and 3.14, both `rc=1`, stderr `cmp -s` equal |

U2 maps to no S-ID by design: it serves R5 and Success Criterion 6, which are
maintainer-tracker obligations rather than user scenarios. Every S-ID completes
end to end; no scenario is stranded.

## Implementation Units

## U1: Defer annotation evaluation in the frontmatter validator
Execution note: characterization-first
Files:
  Modify: `skills/compound/scripts/validate-frontmatter.py`
  Test: none — see the interpreter matrix in Steps; the repo has no Python test framework and the compatibility gate at `scripts/test-python-compatibility.sh` already compiles this exact file on both declared boundaries
Interfaces:
  Consumes: nothing new. The module keeps its current imports (`os`, `re`, `sys`) and adds no dependency
  Produces: unchanged CLI contract — `validate-frontmatter.py <doc-path>`, exit 0 pass / 1 validation failure / 2 usage error; unchanged stdout `OK: <path>` and stderr `FAIL: <path>` plus one indented line per issue
Test scenarios:
  happy: `docs/solutions/test-failures/generated-python-version-warning-gate.md` (`problem_type: test_failure`, a `BUG_TYPES` member with a 3-item `symptoms` list) exits 0 on CPython 3.8, driving both `check_schema`'s bug-track branch at L150-161 and the `- item` list-parsing branch at L80-84. This is the exact measurement the origin spec's Success Criterion 1 names. Covers S1, S2, S3 — all three are 3.8 observations, and this is the only scenario that runs 3.8 on a real document. No `Covers AE<n>` tag appears anywhere in this plan: the origin spec labels its acceptance criteria as numbered Success Criteria, never as `AE<n>`, so an `AE` tag here would name a target that does not exist
  edge: the same document on 3.9, 3.13, and 3.14 also exits 0, confirming the change is not 3.8-specific; and every document under `docs/solutions/` yields the same exit code on 3.8 as on 3.14, catching a corpus-wide divergence the single fixture cannot
  error: a fixture carrying an unquoted ` #` in a scalar and missing `symptoms`/`root_cause`/`resolution_type` exits 1 on both 3.8 and 3.14, with `cmp -s` reporting their stderr byte-identical. Covers S5
  integration: `bash scripts/validate.sh` ends `ALL CHECKS PASSED`, proving the compatibility gate still compiles the modified file on 3.9 and 3.14 under `-W error::SyntaxWarning` and that its byte-comparison against the repository file still holds. Covers S4 only — the gate resolves its interpreters from `schemas/python-support.json` (`validate.sh:275`) and never invokes 3.8, so it cannot walk S1, S2, or S3
Steps:
  1. Capture the pre-change baseline before editing: `git show HEAD:skills/compound/scripts/validate-frontmatter.py > "$BASELINE/pre.py"` into a `mktemp -d` directory. This is characterization-first — the baseline is what step 7 compares against, and it is unrecoverable once the file is edited.
  2. Record the current failure so the fix is provably the cause of the change: run `python3.8 skills/compound/scripts/validate-frontmatter.py docs/solutions/test-failures/generated-python-version-warning-gate.md`; confirm it exits 1 with `TypeError: 'type' object is not subscriptable`.
  3. Insert the line `from __future__ import annotations` followed by one blank line immediately after the module docstring's closing `"""` and immediately before `import os`. Change nothing else — no annotation text, no import reordering, no docstring edit.
  4. Run `python3.8 skills/compound/scripts/validate-frontmatter.py docs/solutions/test-failures/generated-python-version-warning-gate.md`; confirm it now prints `OK: <path>` and exits 0. If it raises `SyntaxError: from __future__ imports must occur at the beginning of the file`, the line landed below another statement — move it up rather than adding a second one.
  5. Run the same document on 3.9, 3.13, and 3.14; confirm exit 0 on each.
  6. Sweep the whole corpus across interpreters (origin spec Testing test 5 axis (a) / Success Criterion 2 — the two single-fixture cases sample only two documents, and this is the check that would catch a divergence they miss): `d=$(mktemp -d); for i in 3.8 3.14; do for f in $(git ls-files 'docs/solutions/*.md'); do printf '%s %s\n' "$f" "$(python$i skills/compound/scripts/validate-frontmatter.py "$f" >/dev/null 2>&1; echo $?)"; done > "$d/r$i.txt"; done; cmp -s "$d/r3.8.txt" "$d/r3.14.txt"; echo $?; rm -rf "$d"`. It must print `0`. On the unmodified tree the same command prints `1`, so this check discriminates.
  7. Prove nothing observable changed on the supported interpreters (test 5 axis (b) / Success Criterion 7): for the baseline copy from step 1 and the edited file, capture `<path>|<combined stdout+stderr>|<exit code>` for every file in `git ls-files 'docs/solutions/*.md'` under 3.9 and again under 3.14, then `cmp -s` the baseline capture against the edited-file capture. It must report equality. Note this compares pre-change against post-change, not 3.9 against 3.14.
  8. Prove the failure path is intact: write the invalid fixture with `printf -- '---\nmodule: x\ndate: 2026-07-26\nproblem_type: build_error\ncomponent: y # bad\nseverity: low\n---\nbody\n'`, run it under 3.8 and 3.14, confirm both exit 1, and confirm `cmp -s` of their stderr exits 0. Run the validator with no argument under 3.8 and confirm exit 2.
  9. Prove the contract did not move (Success Criterion 5): `git diff 60df670 -- schemas/python-support.json scripts/test-python-compatibility.sh docs/specs/2026-07-19-python-compatibility-generated-code-warning-gate-design.md` must print nothing. `60df670` is this branch's branch point; a `main`-relative diff would be empty after merge no matter what changed.
  10. Run `bash scripts/validate.sh`; confirm the final line is `ALL CHECKS PASSED`.
  11. Remove the temporary directories from steps 1 and 8.
  12. Commit: `fix(compound): Run frontmatter validator on CPython 3.8`
Acceptance: `python3.8 skills/compound/scripts/validate-frontmatter.py docs/solutions/test-failures/generated-python-version-warning-gate.md` exits 0; the step-6 corpus sweep prints `0`; the step-7 pre/post capture comparison exits 0; the step-9 contract diff is empty; `bash scripts/validate.sh` ends `ALL CHECKS PASSED`; `git diff HEAD~1 --stat -- skills/compound/scripts/validate-frontmatter.py` shows exactly 2 lines added and 0 removed.

## U2: Register the incidental-compatibility drift exposure
Execution note: skip-test-first
Files:
  Modify: `ROADMAP.md`
  Test: none — the deliverable is a tracker row; its verifiable property is presence and shape, checked in Acceptance rather than by a test
Interfaces:
  Consumes: the existing `## Carry-forward from retros` table and its four-column shape — `| Item | Origin | Priority | Trigger / next step |` (five pipes per row) as rendered by the rows already present
  Produces: one additional row in that table; no heading, column, or existing row changes
Test scenarios:
  happy: `grep -n '3.8' ROADMAP.md` matches the new row
  edge: the row sits inside the `## Carry-forward from retros` table and not in `## Future candidates` or `## Shipped`, so `retrospective`'s reconciliation pass finds it where it looks for open items
  error: n/a — a markdown table row has no failure mode beyond malformation, which the edge scenario's placement check and the Acceptance render check already cover
  integration: `bash scripts/validate.sh` still ends `ALL CHECKS PASSED`, confirming the edit did not break any structural check that reads ROADMAP.md
Steps:
  1. Append one row to the `## Carry-forward from retros` table, after its current last row. Item: the frontmatter validator is expected to run on CPython 3.8 but 3.8 is not a boundary interpreter, so no gate prevents a later edit from reintroducing a 3.9-only construct and silently breaking it again. Origin: `2026-07-26 frontmatter-validator-python38 spec (R5)`. Priority: `P3`. Trigger: next edit to `skills/compound/scripts/validate-frontmatter.py` or to `schemas/python-support.json`.
  2. Confirm the row renders as a table row and not as body prose: it must begin and end with `|` and carry exactly the same column count as the row above it.
  3. Run `bash scripts/validate.sh`; confirm `ALL CHECKS PASSED`.
  4. Commit: `docs(roadmap): Register 3.8 incidental-compatibility drift exposure`
Acceptance: `grep -n '3.8' ROADMAP.md` returns a line inside the `## Carry-forward from retros` table naming the exposure, origin, priority `P3`, and a trigger; the row's pipe count equals the preceding row's; `bash scripts/validate.sh` ends `ALL CHECKS PASSED`.

## Mutation/failure-state matrix

No stateful ceremony in the deliverable; no mutation/failure-state matrix required.

## Carry-forward trigger audit

Audited ROADMAP.md `## Carry-forward from retros` at `aa06bad`: 17 open rows, 6 fired, 0 unobservable.

All six firings are latched — recorded in the tracker by earlier cycles — rather
than newly triggered by this plan's two-file scope. A latched firing is not
un-fired by the current cycle leaving the named file untouched, so each still
takes a disposition.

| Tracker row | Trigger class | What fired it | Disposition |
|---|---|---|---|
| Automated numbered-reference validation for planning and plan schema | edit-based | Latched: recorded **fired** 2026-07-24 when that cycle performed both numbered insertions; the check remains unbuilt | Deferred to Follow-Up Work — this plan inserts no numbered planning step and does not touch `skills/planning/SKILL.md`, its references, or `schemas/plan-schema.md` |
| Carry-forward check needs a structural assertion (probed-row → T-ID linkage) | event-based | Latched at the 2026-07-24 plan audit and deferred there | Deferred to Follow-Up Work — retro-template and check 9 are outside this plan's file list; the obligation belongs to a `retrospective`-template cycle |
| Plan internal clause-consistency check (architecture notes vs unit contracts) | edit-based | Latched: **fired** for a third consecutive cycle at 2026-07-24; the mechanical check is still unbuilt | Deferred to Follow-Up Work as a mechanical check, and satisfied procedurally in this plan: the Architecture notes deliberately state decisions and rationale only, and the `planning` skill's step-14 self-review pass diffs them against both unit step contracts |
| Define "hand-up packet" locally in `skills/shipping/SKILL.md` | edit-based | Latched: fired at `2299955`, re-latched and deferred 2026-07-24 | Deferred to Follow-Up Work — this plan does not edit `skills/shipping/SKILL.md` |
| Mechanical `scripts/validate.sh` check for `final_action` shape | drift-based | Latched: **fired** on a recurring out-of-schema `note:` field across two consecutive cycles | Deferred to Follow-Up Work — `scripts/validate.sh` is outside this plan's file list. Observability note: this cycle's `.release-loop/progress.md` `final_action` block carries exactly the four schema fields with no `note:`, so the drift is *not* present in the current record; the row stays fired on the latching rule, not on fresh evidence |
| Spec-level carve-out rule for universal principles | event-based | Latched: **fired** 2026-07-24 during that cycle's spec review | Deferred to Follow-Up Work — the rule change belongs to a `designing`-skill cycle, not to a source fix |

No drift-based trigger was unobservable at planning time.

The near-miss worth recording: **"Pin the tracked Python support contract in
every non-fixture compatibility consumer"** is edit-based and sits in this
plan's subject area, so it was checked against source rather than by topic.
The non-documentation files that read the contract are `scripts/validate.sh`
and `scripts/test-python-compatibility.sh`. The delegation boundary the row
names is `validate.sh:275`, where the gate is invoked with
`PYTHON_SUPPORT_FILE` already set explicitly; `scripts/release-publication.sh`
is the publication harness the gate extracts an artifact from and contains no
contract reference at all (`grep -n 'PYTHON_SUPPORT\|python-support'` → no
match). Neither file is in this plan's file list. `ROADMAP.md` appears in the same grep only because the row's own prose
names the contract, and a tracker document cannot set `PYTHON_SUPPORT_FILE`.
`validate-frontmatter.py` is a *registered artifact* the gate compiles, not a
consumer that reads the contract. **Not fired.**

## Deferred to Follow-Up Work

- The mechanical guard that would keep 3.8 working — building it requires moving
  `minimum_minor` and superseding the approved 2026-07-19 spec, which the user
  declined at the Design gate. U2's tracker row is the registered substitute.
- `-> "NoReturn"` at `validate-frontmatter.py:46` references a name the module
  never imports. Inert before and after this change; the origin spec's Open
  Decision 2 assigns it to `reviewing`.
- The six latched carry-forward rows. Each one's Deferred entry — the tracker
  row named, plus its reason — is the corresponding Disposition cell in the
  Carry-forward trigger audit table above, written per row rather than restated
  here; this bullet is the pointer, not the entry.
- Revisiting the mechanism when `maximum_minor` rises past the version that
  removes the PEP 563 future-import (PEP 649/749 supersede it from 3.14 on).
  Origin spec Open Decision 1 owns this.

## Open unknowns

**Planning-time** — none. Every fork the spec left open is owned by a later
cycle, not by this plan; no unresolved question blocks approval.

**Implementation-time**

- U1 step 1 uses `git show HEAD:` for the baseline. If the branch is rebased
  between approval and execution, `HEAD` still resolves to the correct
  pre-change content because U1 is the first commit to touch the file — but an
  implementer resuming mid-unit after a partial edit must take the baseline from
  the last commit that predates their edit, not from a dirty tree.
- The exact prose of U2's tracker row is left to the implementer within the
  four required elements (exposure, origin, priority `P3`, trigger); matching
  the surrounding rows' voice matters more than reproducing a dictated string.
