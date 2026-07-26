---
module: compound
date: "2026-07-26"
problem_type: runtime_error
component: frontmatter-validator
severity: medium
symptoms:
  - "`TypeError: 'type' object is not subscriptable` raised at import, before any argument is read"
  - "a pure-stdlib script fails on one older CPython minor and passes on every newer one"
  - "the traceback points at a `def` line rather than at the code path being exercised"
  - "the repository's own structural gate stays green while the script is broken"
root_cause: PEP 585 builtin generic annotations are evaluated at function-definition time and do not exist before CPython 3.9
resolution_type: code_fix
related_components:
  - python-support-contract
  - cross-environment-validation
tags:
  - python
  - pep-585
  - pep-563
  - annotations
  - cross-version
  - stdlib-script
---

# Builtin Generic Annotations Crash a Script on Pre-3.9 CPython

## Problem

`skills/compound/scripts/validate-frontmatter.py` is the gate every `compound`
run must pass before reporting success. It is dependency-free stdlib Python,
distributed as a skill file to machines whose interpreter this repository does
not choose.

It carried six PEP 585 builtin generic annotations — `list[str]` — across five
function signatures: `extract_frontmatter`, `parse_frontmatter`,
`check_parser_safety` (parameter and return), `check_schema`, and `main`.
Annotations in a `def` header are evaluated when the `def` statement executes,
which is at import. On CPython 3.8 `list` is not subscriptable, so the module
raised before parsing a single document:

```
TypeError: 'type' object is not subscriptable
```

Measured at `2026-07-26T06:21:32Z` on the pre-change tree: `python3.8` → `rc=1`
with that traceback; `python3.9` → `rc=0`, `OK: <path>`. 3.8 was the exact
broken boundary.

## Symptoms

- The script exits non-zero on an old interpreter and zero on every newer one,
  with no code change between the two runs.
- The traceback names a `def` line, not the function's body — the failure is at
  definition, not at call.
- Nothing in the failure mentions the argument, the document, or the validation
  logic, because none of it ran.
- The repository's structural validation suite reports `ALL CHECKS PASSED` the
  whole time.

## What Didn't Work

**Trusting the repository's own gate.** `bash scripts/validate.sh` was green on
the broken tree (`2026-07-26T06:21:32Z`). The compatibility harness resolves its
*boundary endpoints* from `schemas/python-support.json`, whose `minimum_minor`
is `"3.9"`, and compiles each registered artifact once per endpoint role — for
this validator, `role=oldest` on 3.9 and `role=newest` on 3.14. No role
resolves to 3.8, so the gate never compiled the validator there. A gate reports
on the range it was told to cover; it is silent about everything outside that
range, and that silence reads exactly like a pass.

Note the scope of that statement precisely, because the looser version is
false: the harness does not run *entirely* inside the declared range. Its own
parsing and fixture heredocs execute on `BOOTSTRAP="${PYTHON_BOOTSTRAP:-python3}"`
— the ambient interpreter, whatever the machine happens to provide. On a
3.8-ambient machine those heredocs were running on 3.8 the whole time. What was
never covered is the *registered artifact* compile, which is exactly where this
defect lived.

**Placing the future import with the other imports.** Dropping
`from __future__ import annotations` below `import sys` is not a style choice,
it is a hard failure on every interpreter:

```
SyntaxError: from __future__ imports must occur at the beginning of the file
```

A `__future__` import may be preceded only by the module docstring, comments,
and blank lines.

## Solution

One line, at the top of the module, immediately after the docstring:

```python
"""...module docstring..."""
from __future__ import annotations

import os
import re
import sys
```

Commit `69a1950` — two lines added, none removed, no signature, call site, or
control flow touched.

The declared support contract deliberately did **not** move.
`schemas/python-support.json` stays `minimum_minor: "3.9"`, and 3.8 was not
added as a boundary interpreter. What 3.8 gains is *incidental compatibility*,
not support: no boundary interpreter covers it and nothing mechanical keeps it
working. That accepted drift exposure was registered as a carry-forward row
rather than silently absorbed.

Verified on the merge commit:

- `python3.8` → `rc=0`, `OK:` on a bug-track document; `rc=1` with the
  `TypeError` before the change.
- 3.8 and 3.14 exit codes identical across the whole 10-document
  `docs/solutions/` corpus (`cmp -s` → 0); the same command returned 1 before.
- Failure path intact: an invalid-frontmatter fixture exits 1 on both 3.8 and
  3.14 with byte-identical stderr; a no-argument invocation exits 2.
- Pre/post output byte-identical across the corpus on both 3.9 and 3.14 — the
  change is observationally inert inside the supported range.

## Why This Works

`from __future__ import annotations` switches the module to PEP 563 semantics:
every annotation in the module is stored as a string and never evaluated at
runtime. `list[str]` becomes inert text on an interpreter that cannot subscript
`list`, and the type information survives for any reader or type checker.

The fix is atomic in a way a rewrite is not. Converting six annotations to
`typing.List[str]` touches six sites and can be partially applied, leaving one
missed annotation that still crashes on exactly the interpreter nobody tests.
One import either parses or does not.

PEP 563 is safe here only because the module never reads its own annotations at
runtime: no `typing.get_type_hints`, no `__annotations__` inspection, no
dataclass, no `pydantic`, no `functools.singledispatch`. That was confirmed by
direct read and then measured — byte-identical output before and after across
the corpus on two interpreters — rather than argued.

Two annotation-adjacent constructs needed no change and are worth recognizing:
a function-local variable annotation (`data: dict = {}`) is never evaluated at
runtime under PEP 526, and a return annotation already written as a string
literal (`-> "NoReturn"`) was inert to begin with.

## Prevention

1. Put `from __future__ import annotations` at the top of any stdlib-only
   script that will run on interpreters the repository does not choose. It costs
   one line and removes the entire class of "annotation syntax newer than the
   runtime" failures.
2. Read a green compatibility gate as a statement about its declared endpoints
   only. Before concluding a script runs somewhere, check whether any endpoint
   role in the gate's resolved set actually compiles that artifact there — and
   separately, which interpreter the harness itself bootstraps on, since that
   one is usually ambient and ungated.
3. When buying compatibility outside the declared range, register the exposure
   on the durable tracker in the same cycle. Incidental compatibility with no
   recorded exposure is indistinguishable from support that nobody is testing.
4. When a failure appears at import with a `TypeError` on a builtin type,
   suspect the annotations before the logic — check the `def` line the traceback
   names, not the function body.
5. Prefer the single-line mechanism over the multi-site rewrite when both fix
   the same class of defect. A fix that cannot be partially applied cannot be
   partially forgotten.

Related: `docs/solutions/test-failures/generated-python-version-warning-gate.md`
covers the mirror-image case — repo-owned Python breaking on a *newer*
interpreter — and its Prevention rule 6 (test the oldest and newest supported
versions) is the practice whose boundary this defect fell outside.
