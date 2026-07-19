---
module: release
date: "2026-07-19"
problem_type: test_failure
component: generated-python
severity: medium
symptoms:
  - "an exact-shape shell harness passes on Python 3.11 and earlier but gains an unexpected stderr line on Python 3.12 and later"
  - "a generated Python program emits SyntaxWarning before its documented machine output"
  - "an exact-commit reproduction appears green locally while a second environment reports deterministic failures"
root_cause: outer string-template escaping becomes invalid generated Python syntax on newer interpreters
resolution_type: code_fix_and_warning_gate
applies_when:
  - "shell or Python code renders another Python program from a string template"
  - "stdout and stderr are combined under an exact-line machine-output contract"
  - "a defect reproduces only on a different Python minor version"
related_components:
  - release-publication
  - cross-environment-validation
  - exact-output-contracts
tags:
  - generated-python
  - syntaxwarning
  - cross-environment
  - exact-output
  - regression-test
---

# Gate Generated Python Against Version-Dependent Warnings

## Problem

`scripts/release-publication.sh` renders an executable Python program from an
outer Python f-string. The generated program contained an inner regular
expression with `\.` escapes. On Python 3.11 and earlier, the repository's full
publication suite reported 99 passing cases. On Python 3.14.6, the outer
non-raw f-string emitted `SyntaxWarning: invalid escape sequence '\.'` before
the generated program ran.

The harness intentionally combines stderr with stdout around the publication
ceremony. That warning therefore became a fifth line in a four-line ready
machine-output contract and caused six gate and tamper integration cases to
fail. An exact-SHA rerun on the older interpreter stayed green, so the first
diagnosis incorrectly attributed the external result to a stale checkout.

## Symptoms

- The same commit is green on one machine and red on another.
- Exact-line output validation reports one unexpected line.
- The extra line is a warning emitted before application output.
- The failure begins at a Python minor-version boundary rather than a code
  change.

## What Didn't Work

Rechecking only the Git commit and worktree was insufficient. Exact source
identity does not establish exact execution-environment identity. A clean run
under Python 3.11 or earlier could not disprove a report produced under Python
3.14.6.

Treating the warning as harmless was also invalid. When a protocol combines
stderr and stdout or requires an exact number of lines, warnings are observable
output and can corrupt the protocol even when the program exits zero.

## Solution

Escape for both parsing layers. The outer f-string now uses doubled
backslashes so the rendered program receives the intended raw-regex `\.`
sequence without warning:

```python
match = re.fullmatch(r"HTTP/(?:1\\.1|2(?:\\.0)?) ...", line)
```

Extract the generated program in the fixture harness and compile it with
syntax warnings promoted to errors:

```sh
python3 -W error::SyntaxWarning -m py_compile release-publication-engine.py
```

Commit `596c8ea` applied both changes. The rendered engine compiled under
Python 3.12.13 and 3.14.6, and the Python 3.14.6 publication suite then passed
100 of 100 cases.

## Why This Works

The doubled escape is consumed once by the outer template, leaving the exact
escape required by the inner generated program. Compiling the extracted
artifact tests what will actually execute rather than merely compiling the
generator.

Promoting `SyntaxWarning` to an error turns interpreter-version drift into a
deterministic regression failure before the warning can pollute a machine
protocol. It also makes the check useful on versions that already recognize
the warning class without requiring a real outward publication.

## Prevention

When a failure differs across environments:

1. Record `python3 --version` and the resolved interpreter path before
   attributing the difference to checkout or report drift.
2. Reproduce on the reporter's minor version or the newest supported version.
3. Extract and compile generated code, not only its generator.
4. Run generated Python with `-W error::SyntaxWarning` in the harness.
5. Treat stderr as part of the protocol whenever the caller captures `2>&1`.
6. Define and test the repository's oldest and newest supported Python
   versions when more than one interpreter version is expected.
