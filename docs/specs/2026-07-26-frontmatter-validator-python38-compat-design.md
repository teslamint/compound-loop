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
on CPython 3.8, because five annotations use PEP 585 builtin generics
(`list[str]`) that 3.8 evaluates at function-definition time. This design makes
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
`list[str]` traceback, and that validation was therefore rerun on 3.9. That
recurring caveat disappears — the retro records a single unqualified exit-0
observation.

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
  The five annotation sites (L51, L69, L105, L138, L174) keep their current
  text; no annotation is rewritten to `typing.List` and no annotation is
  deleted.
- **R3** — behavior on 3.9 through 3.14 is unchanged: identical stdout, identical
  stderr diagnostics, identical exit codes.
- **R4** — the file remains pure stdlib with no new imports beyond the
  `__future__` statement, preserving the "no PyYAML or other deps" property its
  own docstring declares.
- **R5** — a ROADMAP carry-forward row registers the drift exposure this change
  creates: nothing mechanical prevents a future edit from reintroducing a
  3.9-only construct, because 3.8 is deliberately not a gate boundary.

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
at `60df670` (identical tree to `main`). E3-E5 were observed against a scratchpad
copy of the validator carrying the proposed one-line change, not against the
repository tree. Results are exit codes and one-word comparisons; no credentials,
personal data, or unbounded output are retained.

| Claim | Command | Observed at | Observed result | Evidence source |
|---|---|---|---|---|
| The committed validator fails on 3.8 and passes on 3.9, so 3.8 is the exact broken boundary. | `python3.8 skills/compound/scripts/validate-frontmatter.py docs/solutions/workflow-issues/carry-forward-trigger-planning-audit-gap.md; python3.9 <same>` | `2026-07-26T06:21:32Z` | 3.8.10 → `rc=1` with `TypeError: 'type' object is not subscriptable` at line 51; 3.9.25 → `rc=0`, `OK: <path>`. | Working tree at `60df670` |
| `from __future__ import annotations` makes the validator succeed on every locally available interpreter for a valid document. | `for i in 3.8 3.9 3.13 3.14; do python$i <patched-copy> docs/solutions/workflow-issues/carry-forward-trigger-planning-audit-gap.md; done` | `2026-07-26T06:21:32Z` | `3.8 rc=0  3.9 rc=0  3.13 rc=0  3.14 rc=0`. Local interpreters are 3.8.10, 3.9.25, 3.13.14, 3.14.6. | Scratchpad copy of the validator with the proposed change |
| The failure path still fails, on every interpreter, with byte-identical diagnostics. | `for i in 3.8 3.9 3.13 3.14; do python$i <patched-copy> <invalid-fixture>; done` then `cmp -s <3.8 stderr> <3.14 stderr>` | `2026-07-26T06:21:32Z` | `3.8 rc=1  3.9 rc=1  3.13 rc=1  3.14 rc=1`; stderr comparison → `identical`. Usage error with no argument → `rc=2` on 3.8. | Scratchpad copy plus a scratchpad invalid-frontmatter fixture |
| The patched file passes the compatibility gate's exact compile check on both declared boundaries. | `for i in 3.9 3.14; do python$i -W error::SyntaxWarning -m py_compile <patched-copy>; done` | `2026-07-26T06:21:32Z` | Both compiles exit 0, no warning raised as error. | Scratchpad copy; bytecode discarded |
| A `__future__` import placed after the existing imports is a hard error, so placement is a real requirement rather than style. | `python3.14 <copy with the import after `import sys`> README.md` | `2026-07-26T06:21:32Z` | `SyntaxError: from __future__ imports must occur at the beginning of the file`. | Second scratchpad copy, deliberately misplaced |
| Structural validation is green before the change, establishing the regression baseline. | `bash scripts/validate.sh` | `2026-07-26T06:21:32Z` | `ALL CHECKS PASSED`. | Working tree at `60df670` |
| The other Python in the repository is already 3.8-clean, so this file is the sole blocker. | extract the `RELEASE_PUBLICATION_ENGINE_PY` heredoc from `scripts/release-publication.sh`, then `python3.8 -W error::SyntaxWarning -m py_compile` it; separately `git ls-files '*.py'` | `2026-07-26T06:21:32Z` | Engine compile → `rc=0`; `git ls-files '*.py'` lists exactly one file, the validator. | Working tree at `60df670`; extracted artifact deleted after the read-only compile |

Repository invariants that still apply: the validator is registered in
`scripts/test-python-compatibility.sh:196` as the `committed` artifact class and
is copied byte-for-byte into the gate's temporary root (line 530) and compared
with `cmp -s` (line 572), so any edit to it must keep the gate's copy/compare
path green.

## Architecture

One file changes. `from __future__ import annotations` switches the module to
PEP 563 semantics: every annotation in the module is stored as a string and
never evaluated at runtime, so `list[str]` at L51, L69, L105, L138, and L174
becomes inert text on interpreters that lack PEP 585 subscripting. No call site, control flow,
or data structure moves.

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

No new test file. Verification is the existing gate plus a bounded manual matrix,
because the repository has no Python unit-test harness and adding one for a
one-line change is disproportionate.

1. **Regression on the declared boundaries** — `bash scripts/validate.sh` must
   end `ALL CHECKS PASSED`. This exercises the compatibility gate, which compiles
   the changed file on 3.9 and 3.14 under `-W error::SyntaxWarning` and byte-
   compares the copy the gate extracts against the repository file.
2. **Interpreter matrix, valid document (S1, S4)** — run the committed file on
   3.8, 3.9, 3.13, 3.14 against
   `docs/solutions/workflow-issues/carry-forward-trigger-planning-audit-gap.md`,
   a real bug-track doc whose frontmatter has a `symptoms:` block with `- item`
   lines. This exercises the list-parsing branch at L80-84, not only the scalar
   path. Expect `rc=0` and `OK: <path>` on all four.
3. **Interpreter matrix, invalid document (S5)** — run the same four interpreters
   against a fixture with an unquoted ` #` in a scalar and missing bug-track
   fields. Expect `rc=1` on all four and `cmp -s` equality between the 3.8 and
   3.14 stderr.
4. **Usage error (R1)** — invoke with no argument on 3.8. Expect `rc=2`.
5. **Whole-corpus sweep (R3)** — run the committed file on 3.8 and on 3.14 across
   every doc under `docs/solutions/` and compare the two result sets. Any
   document whose verdict differs between interpreters is a failure. This is the
   check that would catch a behavioral divergence the single-fixture cases miss.

## Risks

| Risk | Mitigation |
|---|---|
| The `__future__` import is placed after the existing imports and the file stops parsing everywhere. | Placement is specified in R2 and proven to matter by the retained `SyntaxError` evidence. Test 1 catches it immediately — the gate compiles the file on both boundaries. |
| PEP 563 changes runtime behavior somewhere the module actually reads annotations. | The module never calls `typing.get_type_hints`, never inspects `__annotations__`, and has no dataclass, `pydantic`, or `functools.singledispatch` usage. Test 5's whole-corpus sweep is the empirical backstop. |
| Someone reintroduces a 3.9-only construct later, because 3.8 is not a gate boundary and nothing fails. | Accepted, not solved. R5 registers a ROADMAP carry-forward row naming the exposure and its trigger. Building the guard would require moving the contract floor, which the user explicitly declined. |
| A reader infers from the change that the repository now supports 3.8. | The Out section states the opposite, `schemas/python-support.json` is untouched, and the commit message says "run on" rather than "support". |
| 3.8 is EOL (2024-10) and its ecosystem keeps diverging. | This change buys compatibility for one dependency-free stdlib script, not a support commitment. If the divergence ever costs more than one line, the correct response is to stop, not to expand the compatibility surface. |

## Success Criteria

1. The committed validator exits 0 on CPython 3.8 for a valid bug-track document
   that contains a frontmatter list.
   - **Measured by**: `python3.8 skills/compound/scripts/validate-frontmatter.py docs/solutions/workflow-issues/carry-forward-trigger-planning-audit-gap.md; echo $?` → prints `OK: <path>` and `0`.
2. The committed validator produces identical verdicts on 3.8 and 3.14 across the
   entire `docs/solutions/` corpus.
   - **Measured by**: `d=$(mktemp -d); for i in 3.8 3.14; do for f in $(git ls-files 'docs/solutions/*.md'); do printf '%s %s\n' "$f" "$(python$i skills/compound/scripts/validate-frontmatter.py "$f" >/dev/null 2>&1; echo $?)"; done > "$d/r$i.txt"; done; cmp -s "$d/r3.8.txt" "$d/r3.14.txt"; echo $?; rm -rf "$d"` → `0`. Dry-run on the unfixed tree returns `1`, confirming the check discriminates.
3. The failure path still fails on 3.8 with the same diagnostics as on 3.14.
   - **Measured by**: run the committed validator on a frontmatter fixture with an unquoted ` #` scalar and missing bug-track fields under both interpreters; both exit 1 and `cmp -s` of their stderr exits 0.
4. Structural validation, including the 3.9/3.14 compatibility gate, stays green.
   - **Measured by**: `bash scripts/validate.sh` → final line `ALL CHECKS PASSED`.
5. The declared support contract is byte-unchanged by this cycle.
   - **Measured by**: `git diff main -- schemas/python-support.json scripts/test-python-compatibility.sh docs/specs/2026-07-19-python-compatibility-generated-code-warning-gate-design.md` → empty output.
6. The drift exposure is registered where retro reconciliation will find it.
   - **Measured by**: `grep -n '3.8' ROADMAP.md` → matches a row in the "Carry-forward from retros" table naming the exposure, its origin, a priority, and a trigger.

## Open Decisions

- **Whether the 3.8 floor should ever become mechanical.** Undecided by design.
  Resolving it means moving `minimum_minor` and superseding the 2026-07-19 spec.
  Owner: **user**, via a future `designing` cycle triggered by the R5 ROADMAP row.
- **Whether `-> "NoReturn"` at L46 should import `typing.NoReturn` or be dropped.**
  Out of scope here; it is inert either way. Owner: **`reviewing`** — if a review
  lane raises it, it is a separate finding, not a change to this spec.
