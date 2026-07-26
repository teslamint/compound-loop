---
title: Frontmatter Validator Runs on Python 3.8
status: draft
date: 2026-07-26
schema: spec/v1
---

# Frontmatter Validator Runs on Python 3.8 Design

_Created 2026-07-26._

## Overview

`skills/compound/scripts/validate-frontmatter.py` ships inside the distributed
`compound` skill and aborts with `TypeError: 'type' object is not subscriptable`
on CPython 3.8, because six PEP 585 builtin-generic annotations (`list[str]`)
across five sites are evaluated at function-definition time. This design makes
that one file run on 3.8 while leaving the repository's declared support
contract at `minimum_minor: "3.9"`. Making a shipped file *run* on an
interpreter is not the same as *claiming support* for it, so the 2026-07-19
compatibility spec's Out clause is untouched.

## User Scenarios

### S1: Skill user on a distribution whose `python3` is 3.8

A `compound` user installs the plugin on a machine (older Ubuntu LTS, a locked
corporate image, a CI base container) where the unversioned `python3` resolves
to 3.8. `skills/compound/SKILL.md:48` instructs them to run
`python3 skills/compound/scripts/validate-frontmatter.py <path>` and states no
interpreter floor. Today they get a traceback that names a type annotation, not
their document. After this change the command prints `OK: <path>` and exits 0.

### S2: Agent finishing a `compound` run on a 3.8-ambient session

An agent must reach exit 0 on the validator before claiming documentation
success (`enforces: P3`). On a 3.8-ambient session the gate is unreachable, so
the agent either fabricates success or stalls. After this change the gate
resolves normally on the ambient interpreter.

### S3: Retro author no longer writes the 3.8 caveat

`docs/retros/2026-07-24-evidence-tier-vocabulary-retro.md:116` and
`docs/retros/2026-07-24-planning-trigger-audit-retro.md:120` each carry a
sentence explaining that the ambient `python3` was 3.8, reproduced the known
`list[str]` traceback, and that validation was therefore rerun on 3.9. Those two
lines are historical records and stay as written. What changes is the next
retro run on a 3.8-ambient machine: it records a single unqualified exit-0
observation instead of the caveat.

### S4: Maintainer still gets a 3.9-floored repository

A maintainer runs `bash scripts/validate.sh`. The compatibility gate resolves
boundary interpreters from `schemas/python-support.json`, which still reads
`3.9` / `3.14`, and compiles the validator on exactly those two. Nothing about
the declared contract, the gate's endpoints, or the approved 2026-07-19 spec
changes.

### S5: Author of a document with a malformed frontmatter list

A user runs the validator on a bug-track doc missing `symptoms` / `root_cause` /
`resolution_type` and carrying an unquoted ` #` in a scalar. On 3.8 they get the
same `FAIL:` block, the same four diagnostic lines, and the same exit 1 they
would get on 3.14 — the fix must not degrade diagnostics on the newly-reachable
interpreter.

## Scope

### In

- **R1** — `skills/compound/scripts/validate-frontmatter.py` executes to
  completion on CPython 3.8 for valid documents (exit 0), invalid documents
  (exit 1), and usage errors (exit 2).
- **R2** — the mechanism is `from __future__ import annotations` (PEP 563,
  available 3.7+), placed as the first statement after the module docstring.
  The five annotation sites (L51, L69, L105, L138, L174 — L105 carries two
  `list[str]`, one parameter and one return) keep their current text; no
  annotation is rewritten to `typing.List` and no annotation is deleted.
- **R3** — behavior on 3.9 through 3.14 is unchanged: identical stdout, identical
  stderr diagnostics, identical exit codes.
- **R4** — the file remains pure stdlib with no new imports beyond the
  `__future__` statement, preserving the "no PyYAML or other deps" property its
  own docstring declares.
- **R5** — a ROADMAP carry-forward row registers the drift exposure this change
  creates: nothing mechanical prevents a future edit from reintroducing a
  3.9-only construct, because 3.8 is deliberately not a gate boundary. The row
  goes in the `## Carry-forward from retros` table at Priority **P3**, matching
  every existing row in that table; its origin is this spec and its trigger is
  the next edit to the validator or to `schemas/python-support.json`.

### Out

- Changing `schemas/python-support.json`. `minimum_minor` stays `"3.9"`.
- Adding 3.8 as a boundary interpreter in `scripts/test-python-compatibility.sh`,
  or touching that harness's fixture pins at lines 445-446, 545-546, 553, 669.
- Amending or superseding
  `docs/specs/2026-07-19-python-compatibility-generated-code-warning-gate-design.md`.
  Its Out clause forbids *claiming support* for 3.8, which this change does not do.
- Declaring, documenting, or testing 3.8 as a supported interpreter anywhere,
  including `skills/compound/SKILL.md`.
- Any change to `scripts/release-publication.sh`'s embedded engine — it already
  compiles clean on 3.8.
- Python 3.7 or earlier, PyPy, and prerelease interpreters.
- Building the mechanical guard that would prevent 3.9-only syntax from
  reappearing. R5 registers it as a tracked carry-forward, deliberately not as
  work in this cycle.

## Assumptions and Preconditions

All live assumptions were observed on branch `fix/frontmatter-validator-python38`
at `60df670` (identical tree to `main`; the branch adds only this spec file).
Rows A2-A5, A10, and A11 were observed against a throwaway copy of the validator
carrying the proposed one-line change, not against the repository tree. Results
are exit codes and one-word comparisons; no credentials, personal data, or
unbounded output are retained.

Rows A2-A5, A10, and A11 depend on two throwaway artifacts. Recreate both first,
in the same shell, then run those rows' commands:

```bash
d=$(mktemp -d)
python3 -c 'import pathlib,sys; p=pathlib.Path("skills/compound/scripts/validate-frontmatter.py"); pathlib.Path(sys.argv[1]).write_text(p.read_text().replace("\"\"\"\nimport os", "\"\"\"\nfrom __future__ import annotations\n\nimport os", 1))' "$d/v.py"
printf -- '---\nmodule: x\ndate: 2026-07-26\nproblem_type: build_error\ncomponent: y # bad\nseverity: low\n---\nbody\n' > "$d/bad.md"
# ... run the dependent rows ...
rm -rf "$d"
```

**Before copy-pasting a command out of the table**: cells that contain a shell
pipe carry it as `\|`, because an unescaped `|` would end the markdown table
cell. Rows A3, A5, and A9 are affected. Replace every `\|` with `|` before
running, or the command fails — noisily, not silently.

| Claim | Command | Observed at | Observed result | Evidence source |
|---|---|---|---|---|
| A1 — The committed validator fails on 3.8 and passes on 3.9, so 3.8 is the exact broken boundary. | `for i in 3.8 3.9; do python$i skills/compound/scripts/validate-frontmatter.py docs/solutions/workflow-issues/carry-forward-trigger-planning-audit-gap.md; echo "rc=$?"; done` | `2026-07-26T06:21:32Z` | 3.8.10 → `rc=1` with `TypeError: 'type' object is not subscriptable` at line 51; 3.9.25 → `rc=0`, `OK: <path>`. | Working tree at `60df670` |
| A2 — `from __future__ import annotations` makes the validator succeed on every locally available interpreter for a valid document. | `for i in 3.8 3.9 3.13 3.14; do python$i "$d/v.py" docs/solutions/workflow-issues/carry-forward-trigger-planning-audit-gap.md >/dev/null 2>&1; printf '%s rc=%s  ' "$i" "$?"; done` | `2026-07-26T06:25:57Z` | `3.8 rc=0  3.9 rc=0  3.13 rc=0  3.14 rc=0`. Local interpreters are 3.8.10, 3.9.25, 3.13.14, 3.14.6. | Throwaway copy `$d/v.py` built by the recipe above |
| A3 — The failure path still fails, on every interpreter, with byte-identical diagnostics, and the usage path still exits 2. | `for i in 3.8 3.9 3.13 3.14; do python$i "$d/v.py" "$d/bad.md" >/dev/null 2>&1; printf '%s rc=%s  ' "$i" "$?"; done; python3.8 "$d/v.py" "$d/bad.md" 2>"$d/e38"; python3.14 "$d/v.py" "$d/bad.md" 2>"$d/e314"; cmp -s "$d/e38" "$d/e314" && echo identical; python3.8 "$d/v.py" >/dev/null 2>&1; echo "usage rc=$?"` | `2026-07-26T06:25:57Z` | `3.8 rc=1  3.9 rc=1  3.13 rc=1  3.14 rc=1`; stderr comparison → `identical`; `usage rc=2`. | Throwaway copy plus throwaway invalid-frontmatter fixture from the recipe above |
| A4 — The patched file passes the compatibility gate's exact compile check on both declared boundaries. | `for i in 3.9 3.14; do python$i -W error::SyntaxWarning -m py_compile "$d/v.py" && echo "$i compile ok"; done` | `2026-07-26T06:25:57Z` | Both compiles exit 0, no warning raised as error. | Throwaway copy; bytecode discarded with `$d` |
| A5 — A `__future__` import placed after the existing imports is a hard error, so placement is a requirement rather than style. | `python3 -c 'import pathlib,sys; p=pathlib.Path("skills/compound/scripts/validate-frontmatter.py"); pathlib.Path(sys.argv[1]).write_text(p.read_text().replace("import sys\n", "import sys\nfrom __future__ import annotations\n", 1))' "$d/wrong.py"; python3.14 "$d/wrong.py" README.md 2>&1 \| tail -1` | `2026-07-26T06:25:57Z` | `SyntaxError: from __future__ imports must occur at the beginning of the file`. | Second throwaway copy, deliberately misplaced |
| A6 — Structural validation is green before the change, establishing the regression baseline. | `bash scripts/validate.sh` | `2026-07-26T06:21:32Z` | Final line `ALL CHECKS PASSED`. | Working tree at `60df670` |
| A7 — The publication engine, the repository's only other Python, already compiles clean on 3.8. | `t=$(mktemp -d); awk '/<<'"'"'RELEASE_PUBLICATION_ENGINE_PY'"'"'/ { inside=1; next } /^RELEASE_PUBLICATION_ENGINE_PY$/ { exit } inside { print }' scripts/release-publication.sh > "$t/engine.py"; python3.8 -W error::SyntaxWarning -m py_compile "$t/engine.py"; echo "rc=$?"; rm -rf "$t"` | `2026-07-26T06:21:32Z` | `rc=0`. | Working tree at `60df670`; extracted artifact deleted after the read-only compile |
| A8 — The validator is the only committed `.py` file, so it is the sole blocker. | `git ls-files '*.py'` | `2026-07-26T06:21:32Z` | Exactly one line: `skills/compound/scripts/validate-frontmatter.py`. | Working tree at `60df670` |
| A9 — Every document Criterion 2 sweeps has frontmatter, so the sweep cannot pass by both interpreters uniformly erroring out. | `for f in $(git ls-files 'docs/solutions/*.md'); do head -1 "$f" \| grep -q '^---$' \|\| echo "NO-FM: $f"; done` | `2026-07-26T06:25:57Z` | No output; the pathspec matches 10 files, all with a `---` first line. | Working tree at `60df670` |
| A10 — The patched validator also passes on a **bug-track** document, exercising `check_schema`'s bug branch (L150-161) and not only the knowledge branch. | `for i in 3.8 3.9 3.13 3.14; do python$i "$d/v.py" docs/solutions/test-failures/generated-python-version-warning-gate.md >/dev/null 2>&1; printf '%s rc=%s  ' "$i" "$?"; done` | `2026-07-26T06:57:00Z` | `3.8 rc=0  3.9 rc=0  3.13 rc=0  3.14 rc=0`. That document is `problem_type: test_failure` (a `BUG_TYPES` member) with a 3-item `symptoms` list plus `root_cause` and `resolution_type`. | Throwaway copy from the recipe above |
| A11 — R3's before/after invariance holds directly: the change alters nothing observable on 3.9 or 3.14. | For each of the committed validator and `$d/v.py`, capture `<path>\|<combined stdout+stderr>\|<exit code>` for every file in `git ls-files 'docs/solutions/*.md'`, then `cmp -s` the two captures — once under `python3.9`, once under `python3.14` | `2026-07-26T06:57:00Z` | `3.14 pre/post: IDENTICAL`; `3.9 pre/post: IDENTICAL`. | Committed validator vs throwaway patched copy, 10-document corpus |

Repository invariants that still apply: the validator is registered in
`scripts/test-python-compatibility.sh:196` as the `committed` artifact class and
is copied byte-for-byte into the gate's temporary root (line 530) and compared
with `cmp -s` (line 572), so any edit to it must keep the gate's copy/compare
path green.

## Architecture

One file changes. `from __future__ import annotations` switches the module to
PEP 563 semantics: every annotation in the module is stored as a string and
never evaluated at runtime, so `list[str]` at L51, L69, L105, L138, and L174
becomes inert text on interpreters that lack PEP 585 subscripting. No call site,
control flow, or data structure moves.

Two annotation-adjacent details are deliberately left alone:

- `data: dict = {}` at L72 is a function-local variable annotation. Per PEP 526
  those are never evaluated at runtime, so it was never part of the failure and
  needs no change.
- `-> "NoReturn"` at L46 is already a string literal referencing a name the
  module never imports. It is inert today and stays inert under PEP 563.
  Cleaning it up is a separate concern, not this change.

## Interface

No interface change. The command remains
`python3 skills/compound/scripts/validate-frontmatter.py <doc-path>`, with the
documented exit codes 0 / 1 / 2. `skills/compound/SKILL.md:48` needs no edit —
it already states no interpreter floor, and adding one would contradict the
purpose of this change.

## Testing

No new test file. Verification is the existing gate plus a bounded manual matrix.
The repository's testing convention is bash fixture harnesses under `scripts/`
(`test-python-compatibility.sh`, `test-manifest-version-sync.sh`,
`test-release-publication.sh`, `test-retro-format-drift.sh`,
`test-signal-drift.sh`), not a Python unit-test framework. A one-line annotation
change that the existing compatibility harness already compiles on both declared
boundaries does not warrant a sixth harness.

Three of the five checks below can fail independently: test 1 (the gate, which
no other check exercises), test 4 (the usage path — the sweep never invokes the
validator without an argument, so nothing else covers it), and test 5 (the
corpus sweep). Tests 2 and 3 are single-fixture instances the sweep subsumes,
kept because they localize a failure the sweep only reports in aggregate.

1. **Regression on the declared boundaries (S4)** — `bash scripts/validate.sh`
   must end `ALL CHECKS PASSED`. This exercises the compatibility gate, which
   compiles the changed file on 3.9 and 3.14 under `-W error::SyntaxWarning` and
   byte-compares the copy the gate extracts against the repository file.
2. **Interpreter matrix, valid document (S1, S2)** — run the committed file on
   3.8, 3.9, 3.13, 3.14 against
   `docs/solutions/test-failures/generated-python-version-warning-gate.md`.
   That document is `problem_type: test_failure`, a `BUG_TYPES` member, so it
   drives `check_schema`'s bug-track success branch (L150-161, including the
   1-5 `symptoms` length check at L158); its 3-item `symptoms` list also drives
   the `- item` list-parsing branch at L80-84. One fixture, both branches.
   Expect `rc=0` and `OK: <path>` on all four.
3. **Interpreter matrix, invalid document (S5)** — run the same four interpreters
   against the `$d/bad.md` fixture whose exact `printf` recipe is in Assumptions
   and Preconditions: an unquoted ` #` in a scalar plus missing bug-track fields.
   Expect `rc=1` on all four and `cmp -s` equality between the 3.8 and 3.14
   stderr.
4. **Usage error (R1)** — invoke with no argument on 3.8. Expect `rc=2`.
5. **Whole-corpus sweep, two axes** — across every doc under `docs/solutions/`:
   (a) *cross-interpreter*, the committed file on 3.8 vs on 3.14, catching a
   behavioral divergence the single-fixture cases miss; and (b) *before/after
   on a supported interpreter* (**R3**), the pre-change file vs the post-change
   file under 3.14 and again under 3.9, comparing combined stdout+stderr and
   exit code. Axis (b) is what actually measures R3 — axis (a) alone would not,
   since it never looks at pre-change output on a supported interpreter.

## Risks

| Risk | Mitigation |
|---|---|
| The `__future__` import is placed after the existing imports and the file stops parsing everywhere. | Placement is specified in R2 and proven to matter by the retained `SyntaxError` evidence. Test 1 catches it immediately — the gate compiles the file on both boundaries. |
| PEP 563 changes runtime behavior somewhere the module actually reads annotations. | The module never calls `typing.get_type_hints`, never inspects `__annotations__`, and has no dataclass, `pydantic`, or `functools.singledispatch` usage. Two independent reviewers confirmed this by direct read. A11 measures it rather than arguing it: pre-change and post-change output is byte-identical across the whole corpus on both 3.9 and 3.14. Test 5 axis (b) re-runs that check on the committed change. |
| Someone reintroduces a 3.9-only construct later, because 3.8 is not a gate boundary and nothing fails. | Accepted, not solved. R5 registers a ROADMAP carry-forward row naming the exposure and its trigger. Building the guard would require moving the contract floor, which the user explicitly declined. |
| A reader infers from the change that the repository now supports 3.8. | The Out section states the opposite and `schemas/python-support.json` is untouched — both are durable artifacts a reader can check. Success Criterion 5 proves the contract did not move. |
| `from __future__ import annotations` is itself on a deprecation path. PEP 649/749 replaced PEP 563 as the annotation mechanism from 3.14 onward, and the future-import is expected to be removed eventually (timeline uncertain — general knowledge, not verified against a released changelog here). | Empirically inert through the declared ceiling: `python3.14 -W error -c 'from __future__ import annotations'` succeeds, and compiling an annotated module under `-W error::DeprecationWarning` on 3.14 raises no warning (checked `2026-07-26T06:57:00Z`). This only bites when `maximum_minor` moves past the removal version, and the gate's `-W error::SyntaxWarning` would not catch a `DeprecationWarning` — so the trigger is a contract ceiling raise, not a silent drift. Folded into Open Decision 1. |
| 3.8 is EOL (2024-10) and its ecosystem keeps diverging. | This change buys compatibility for one dependency-free stdlib script, not a support commitment. If the divergence ever costs more than one line, the correct response is to stop, not to expand the compatibility surface. |

## Success Criteria

1. The committed validator exits 0 on CPython 3.8 for a bug-track document that
   carries a frontmatter list, exercising both `check_schema`'s bug branch and
   the list-parsing branch.
   - **Measured by**: `python3.8 skills/compound/scripts/validate-frontmatter.py docs/solutions/test-failures/generated-python-version-warning-gate.md; echo $?` → prints `OK: <path>` and `0`.
2. The committed validator produces identical verdicts on 3.8 and 3.14 across the
   entire `docs/solutions/` corpus.
   - **Measured by**: `d=$(mktemp -d); for i in 3.8 3.14; do for f in $(git ls-files 'docs/solutions/*.md'); do printf '%s %s\n' "$f" "$(python$i skills/compound/scripts/validate-frontmatter.py "$f" >/dev/null 2>&1; echo $?)"; done > "$d/r$i.txt"; done; cmp -s "$d/r3.8.txt" "$d/r3.14.txt"; echo $?; rm -rf "$d"` → `0`. Dry-run on the unfixed tree returns `1`, confirming the check discriminates.
3. The failure path still fails on 3.8 with the same diagnostics as on 3.14.
   Exit codes alone do not discriminate here — the unfixed validator already
   exits 1 on 3.8, via a traceback rather than diagnostics — so the `cmp` of
   stderr is the load-bearing clause.
   - **Measured by**: `d=$(mktemp -d); printf -- '---\nmodule: x\ndate: 2026-07-26\nproblem_type: build_error\ncomponent: y # bad\nseverity: low\n---\nbody\n' > "$d/bad.md"; for i in 3.8 3.14; do python$i skills/compound/scripts/validate-frontmatter.py "$d/bad.md" 2>"$d/e$i"; printf '%s rc=%s\n' "$i" "$?"; done; cmp -s "$d/e3.8" "$d/e3.14"; echo "cmp=$?"; rm -rf "$d"` → both `rc=1` and `cmp=0`.
4. Structural validation, including the 3.9/3.14 compatibility gate, stays green.
   - **Measured by**: `bash scripts/validate.sh` → final line `ALL CHECKS PASSED`.
5. The declared support contract is byte-unchanged by this cycle.
   - **Measured by**: `git diff 60df670 -- schemas/python-support.json scripts/test-python-compatibility.sh docs/specs/2026-07-19-python-compatibility-generated-code-warning-gate-design.md` → empty output. The comparison is pinned to the branch point (`git merge-base main HEAD` at spec time), not to `main`: after merge, `main` contains this work, so a `main`-relative diff would be empty no matter what changed and the criterion could never fail.
6. The drift exposure is registered where retro reconciliation will find it.
   - **Measured by**: `grep -n '3.8' ROADMAP.md` → matches a row in the "Carry-forward from retros" table naming the exposure, its origin, priority P3, and a trigger.
7. **R3** — the change alters nothing observable on a supported interpreter:
   pre-change and post-change output agree across the whole corpus on both
   declared boundaries. Criteria 1-3 all measure post-change state only; this is
   the only criterion that looks at the pre-change baseline, which is what R3
   actually claims.
   - **Measured by**: `d=$(mktemp -d); git show 60df670:skills/compound/scripts/validate-frontmatter.py > "$d/pre.py"; for v in "$d/pre.py" skills/compound/scripts/validate-frontmatter.py; do for i in 3.9 3.14; do for f in $(git ls-files 'docs/solutions/*.md'); do printf '%s|%s|' "$f" "$(python$i "$v" "$f" 2>&1)"; python$i "$v" "$f" >/dev/null 2>&1; printf '%s\n' "$?"; done; done > "$d/$(basename "$v").txt"; done; cmp -s "$d/pre.py.txt" "$d/validate-frontmatter.py.txt"; echo $?; rm -rf "$d"` → `0`.

## Review Record

Recorded here rather than in `.release-loop/progress.md`, which is gitignored;
this spec is the durable artifact.

Step 10 ran twice. The **first pass was degraded** — the harness forbids spawning
subagents unless the user asks, so the reviewer-subagent tier was unavailable and
the `advisor` tool (the next tier in `references/dispatch-degradation.md`) stood
in. It found five defects, the substantive one being a Success Criterion 5 pinned
to `main`, which would have been unfalsifiable by the time `retrospective` ran it
post-merge; it is now pinned to the branch point `60df670`.

The user then explicitly requested the independent review, which lifted the
constraint, so the **second pass ran at full tier**: three lanes, none carrying
the authoring session's context, all reading from disk.

| Lane | Reviewer | Scope | Verdict |
|---|---|---|---|
| 1 | `critic` (Fable 5) | Internal consistency, edge cases, scope, feasibility | APPROVE-WITH-FIXES — 3 P1, 7 P2, no P0 |
| 2 | `verifier` (Fable 5) | Empirical grounding — every assumption and criterion command re-executed, every cited `file:line` re-checked | GROUNDED-WITH-CORRECTIONS — 2 P2, no blockers |
| 3 | `codex exec` (GPT-5.5) | Cross-model: mechanism choice, PEP 563 runtime effects, other 3.8 blockers, underweighted risk | No dissent; confirmed the mechanism and found no further 3.8 blocker |

Lane 2 reproduced all of A1-A9 and confirmed every cited line number across five
files. It also established that Criteria 1-3 genuinely fail on the unmodified
tree — a criterion that already passes before the work is done measures nothing.

The findings that changed the design's substance rather than its wording:

- **Fixture was mislabeled** (lane 1, P1-1). Criterion 1 and test 2 targeted
  `carry-forward-trigger-planning-audit-gap.md` and called it a bug-track
  document; its `problem_type` is `workflow_issue`, a `KNOWLEDGE_TYPES` member,
  so the bug-track success branch was covered by no test at all. Replaced with
  `generated-python-version-warning-gate.md` (`problem_type: test_failure`),
  which drives both branches from one fixture. A10 retains the evidence.
- **R3 was labeled but not measured** (lane 1, P2-2). Every check compared
  interpreters *after* the change; none compared before against after on a
  supported interpreter, which is what R3 claims. Added A11 and Success
  Criterion 7 — pre/post output is byte-identical across the corpus on both 3.9
  and 3.14.
- **Criterion 3 was not runnable verbatim** (lane 1, P1-2), describing a fixture
  in prose that exists nowhere. Its exact `printf` recipe is now inline. Lane 2
  separately noted that Criterion 3's exit codes do not discriminate — the
  unfixed validator already exits 1 on 3.8, by traceback — so the stderr `cmp`
  carries the whole check. The criterion now says so.
- **Deprecation horizon was unconsidered** (lane 1, P2-7). PEP 649/749 supersede
  PEP 563 from 3.14 on. Added a Risks row, grounded in a live check rather than
  recollection, and folded the long-term question into Open Decision 1.

Remaining lane-1 P2s were applied as written: S-ID trace corrections (S4→test 1,
S2→test 2), the six-occurrences-at-five-sites count, R5's explicit P3 priority,
Risk 4's removal of a mitigation that leaned on an uncommitted commit-message
convention, and the table-cell `\|` unescaping note. No finding was rejected.

## Open Decisions

- **Whether the 3.8 floor should ever become mechanical.** Undecided by design.
  Resolving it means moving `minimum_minor` and superseding the 2026-07-19 spec.
  Owner: **user**, via a future `designing` cycle triggered by the R5 ROADMAP row.
  The same cycle should settle the mechanism's own horizon: `from __future__
  import annotations` implements PEP 563, which PEP 649/749 supersede from 3.14
  onward. It is inert today at the declared ceiling (see the Risks row), but a
  future raise of `maximum_minor` past the future-import's removal is the point
  where the mechanism, not just the floor, has to be revisited.
- **Whether `-> "NoReturn"` at L46 should import `typing.NoReturn` or be dropped.**
  Out of scope here; it is inert either way. Owner: **`reviewing`** — if a review
  lane raises it, it is a separate finding, not a change to this spec.
