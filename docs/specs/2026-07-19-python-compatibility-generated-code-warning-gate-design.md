---
title: Declared Python Compatibility and Generated-Code Warning Gate
status: approved
date: 2026-07-19
schema: spec/v1
---

# Declared Python Compatibility and Generated-Code Warning Gate Design

_Created 2026-07-19._

## Overview

Declare Python 3.9 through 3.14, inclusive by minor version, as the repository's
supported Python range. Add one validation gate that materializes every
registered committed or generated Python artifact and compiles it with syntax
warnings promoted to errors on both boundary interpreters.

The gate records the resolved interpreter path and full version before it
compiles anything. It fails closed when either boundary cannot be proved, so a
machine with incomplete interpreter coverage cannot silently report the
repository's compatibility contract as validated.

## User Scenarios

### S1: Validate generated Python across the declared range

A maintainer runs `bash scripts/validate.sh` before completing a change. The
validator reads the one compatibility declaration, resolves Python 3.9 and
Python 3.14, reports both interpreter identities, copies the committed
frontmatter validator, extracts the publication engine from
`scripts/release-publication.sh`, and compiles both artifacts under both
endpoints with `-W error::SyntaxWarning -m py_compile`.

### S2: Diagnose an incomplete local validation environment

A contributor has only Python 3.14 installed and runs the focused compatibility
harness or `bash scripts/validate.sh`. The gate names Python 3.9 as the missing
oldest endpoint, reports the Python 3.14 identity it did resolve, and exits
nonzero. It never converts missing endpoint coverage into a passing skip.

### S3: Use explicitly selected endpoint interpreters

A maintainer whose interpreters are managed by pyenv, Homebrew, or another
layout supplies explicit oldest/newest executable paths to the focused
harness. The gate verifies that each executable's reported major/minor version
matches its declared role before compiling, then reports the resolved path and
full patch version. A Python 3.10 executable cannot stand in for the declared
3.9 endpoint.

### S4: Catch a version-dependent generated-code warning

A change reintroduces an invalid escape into the outer Python template that
renders the publication program. The oldest endpoint may accept the template,
but the newest endpoint's warning-as-error compile fails with a diagnostic that
names the producer, extracted artifact, and Python identity. Validation stops
before the warning can pollute the publication machine-output contract.

### S5: Register a future generated Python artifact

A later feature adds another repo-owned Python artifact that is rendered and
executed after generation. Its implementation adds one explicit extraction
entry to the existing compatibility harness. The same two-endpoint check
applies without introducing a second support declaration or a new framework.

## Scope

### In

- **R1 — Single compatibility declaration**: add one machine-readable
  repository contract at `schemas/python-support.json`. It declares schema
  version `1`, minimum minor `3.9`, and maximum minor `3.14`. Documentation,
  the focused harness, and `scripts/validate.sh` must refer to this contract
  rather than restating independently editable endpoint values.
- **R2 — Inclusive minor semantics**: support means repo-owned Python entry
  points and generated Python artifacts are expected to work on every CPython
  minor from 3.9 through 3.14. The automated compatibility gate compiles both
  artifact classes on the two boundary minors; changing either boundary is an
  explicit contract change.
- **R3 — Boundary identity**: before compilation, resolve each boundary
  executable, record its absolute path and full `Python X.Y.Z` identity, and
  verify that its major/minor equals the declared endpoint. Patch versions are
  reported but are not pinned by the support contract.
- **R4 — Fail-closed degradation**: the focused gate and `scripts/validate.sh`
  exit nonzero if either endpoint is missing, is not executable, cannot report
  its identity, or reports the wrong major/minor. The diagnostic names the
  endpoint role and expected minor; there is no success-with-skip mode.
- **R5 — Explicit local overrides**: the focused harness accepts separate
  oldest and newest interpreter-path overrides. Without overrides it resolves
  the conventional `python3.9` and `python3.14` commands. Overrides select
  executable locations only and cannot change the declared versions.
- **R6 — Explicit compatibility registry**: the focused harness owns one small
  registry with two artifact classes and no globbing. The initial committed
  source entry is `skills/compound/scripts/validate-frontmatter.py`; the initial
  generated entry is the publication engine embedded in
  `scripts/release-publication.sh` plus its extraction rule. Ordinary Python
  heredocs that execute directly are neither committed entry points nor
  generated-later artifacts and are not registered.
- **R7 — Warning-as-error compilation**: copy each registered committed source
  and extract each registered generated artifact once into a private temporary
  directory, then run each boundary interpreter with
  `-W error::SyntaxWarning -m py_compile` against those exact materialized
  files. A failure names the source or producer, artifact class and label,
  endpoint role, resolved path, and full interpreter version without emitting
  unbounded environment output.
- **R8 — Consumer integration**: `scripts/validate.sh` invokes the focused gate
  and preserves its nonzero result. The publication fixture harness delegates
  its embedded-engine warning check to the same extraction/compile behavior so
  it cannot drift into a single-active-interpreter substitute. Maintainer
  guidance links to the compatibility contract and focused command.
- **R9 — Cleanup and isolation**: extraction and bytecode output live only in a
  bounded temporary directory removed on success, failure, and interruption.
  The gate performs no network access, outward publication, repository write,
  or real-remote mutation.
- **R10 — Existing behavior**: the full publication suite, signal-drift suite,
  manifest checks, and structural validation remain green when both declared
  endpoints are available. No runtime package or non-stdlib Python dependency
  is added.

### Out

- Installing, downloading, or managing Python interpreters.
- Claiming support for PyPy, prerelease interpreters, Python 3.8 or earlier, or
  Python 3.15 and later.
- Running the entire repository test suite on every intermediate minor as part
  of this local gate; the declared contract covers the inclusive range, while
  this feature's automated compile proof targets the oldest and newest minors.
- Treating directly executed Python heredocs as committed entry points or
  generated artifacts solely because Bash contains their source.
- Inferring generated Python through broad repository heuristics or building a
  plugin/registration framework for hypothetical producers.
- Adding external CI, containers, version managers, package dependencies, or
  any real outward publication action.
- Changing the publication engine's runtime behavior or machine-output shape.

## Assumptions and Preconditions

Live evidence was observed on `feat/python-generated-warning-gate`. Results are
concise, contain no credentials or personal data, and retain no unbounded raw
output.

| Claim | Command | Observed at | Observed result | Evidence source |
|---|---|---|---|---|
| No supported Python range is currently declared; only the open P2 carry-forward records the need. | `grep -R -n -i -E 'supported Python|Python support|requires-python|python_requires' . --exclude-dir=.git --exclude-dir=.entirecontext` | `2026-07-19T11:55:48+09:00` | Matches occur only in the ROADMAP row, its source retro, and the generated-Python lesson; none defines a range. | Working tree at `4d3e85e` |
| Python 3.9 is the lowest observed minor that can run the repo's typed frontmatter validator, while Python 3.8 cannot. | `for p in python3.8 python3.9; do "$p" skills/compound/scripts/validate-frontmatter.py docs/solutions/test-failures/generated-python-version-warning-gate.md; done` | `2026-07-19T11:56:39+09:00` | Python 3.8.10 exits 1 at `list[str]`; Python 3.9.25 exits 0 and validates the document. | Local interpreter run against the working tree at `4d3e85e` |
| Both proposed boundary interpreters are locally available and pass current structural validation when selected as the exact unversioned `python3`. | `for p in python3.9 python3.14; do shim=$(mktemp -d); ln -s "$(command -v "$p")" "$shim/python3"; PATH="$shim:/usr/bin:/bin" bash scripts/validate.sh; rc=$?; rm -rf "$shim"; [ "$rc" -eq 0 ] || exit "$rc"; done` | `2026-07-19T12:00:30+09:00` | Isolated shims reported Python 3.9.25 and Python 3.14.6 respectively; each validation ended with `ALL CHECKS PASSED`. | Sanitized exact-interpreter validation output on `feat/python-generated-warning-gate` |
| The current publication engine compiles warning-clean on both proposed endpoints. | `tmp=$(mktemp -d); awk '/<<'"'"'RELEASE_PUBLICATION_ENGINE_PY'"'"'/ { inside=1; next } /^RELEASE_PUBLICATION_ENGINE_PY$/ { exit } inside { print }' scripts/release-publication.sh > "$tmp/engine.py"; for p in python3.9 python3.14; do "$p" -W error::SyntaxWarning -m py_compile "$tmp/engine.py"; done; rc=$?; rm -rf "$tmp"; exit "$rc"` | `2026-07-19T11:56:39+09:00` | Both endpoint compiles exit 0; resolved versions are Python 3.9.25 and Python 3.14.6. | Temporary extracted artifact deleted after the read-only compile check |
| The fixed nested HTTP regex is a unique empirical mutation target for a version-dependent warning fixture. | `python3.14 -c 'from pathlib import Path; t=Path("scripts/release-publication.sh").read_text(); print(t.count("re.fullmatch(r\\\"HTTP/(?:1\\\\\\\\.1|2(?:\\\\\\\\.0)?)"))'` | `2026-07-19T11:56:39+09:00` | The doubled-escape nested regex occurs exactly once, at the rendered-program template around line 463. | Working tree at `4d3e85e` |

## Architecture

`schemas/python-support.json` is the compatibility source of truth. A focused
shell harness reads and validates that contract with Python stdlib JSON parsing,
resolves the two endpoint executables, verifies their identities, and emits one
bounded identity/result record per endpoint.

The harness then materializes each registered artifact into one private
temporary root. The committed-source class copies the exact bytes of
`skills/compound/scripts/validate-frontmatter.py`. The generated-artifact class
uses a producer-specific rule that copies only the
`RELEASE_PUBLICATION_ENGINE_PY` block from `scripts/release-publication.sh`.
The same materialized bytes are compiled by the oldest endpoint and then the
newest endpoint. Any resolution, identity, copy, extraction, warning, or
compile failure makes the gate nonzero; cleanup still runs.

`scripts/validate.sh` is the repository-level consumer and cannot downgrade the
gate's result. `scripts/test-release-publication.sh` retains its publication
integration case but calls the shared focused behavior instead of selecting
only whichever `python3` happens to lead `PATH`. Documentation points readers
to the JSON contract and the focused command, not a copied range.

The compatibility declaration, endpoint resolver, and two-class artifact
registry have separate responsibilities. A future range change edits the
declaration; a new committed entry point or generated producer adds one typed
registry entry; neither requires changing consumer semantics.

## Interface and Diagnostics

- `bash scripts/test-python-compatibility.sh all` runs the strict two-class
  endpoint gate. Focused `committed` and `generated` groups exercise one class
  without changing the fail-closed endpoint policy.
- `PYTHON_OLDEST=/absolute/path/to/python3.9` and
  `PYTHON_NEWEST=/absolute/path/to/python3.14` select endpoint executables for
  nonstandard local layouts. Relative or non-executable values fail.
- `bash scripts/validate.sh` invokes the same strict gate without an opt-out.
- Each endpoint record identifies role, declared minor, resolved absolute path,
  full reported version, artifact label, and pass/fail state.
- Missing or mismatched endpoints use an explicit failure record rather than a
  skip record. Diagnostics never print the complete environment or arbitrary
  command output.

The focused command's exact line formatting may be settled in planning, but
the fields and fail-closed meaning above are public validation behavior.

## Testing

- A contract fixture proves valid `3.9`/`3.14` endpoints are accepted and an
  inverted, malformed, non-minor, or unknown-field declaration fails before
  artifact compilation.
- Endpoint fixtures prove missing, non-executable, wrong-minor, and
  identity-command failure states are nonzero and name the correct role.
- A happy fixture runs the real extracted publication engine through both local
  endpoints and asserts two distinct identity records plus two successful
  warning-as-error compiles.
- A committed-source fixture copies the real frontmatter validator, compiles it
  under both endpoints, and proves Python 3.9 rejects a disposable mutation
  that introduces Python 3.10-only syntax.
- A mutation fixture changes only the unique doubled escape in the nested HTTP
  regex back to a single invalid outer-template escape. It proves the Python
  3.14 compile fails for `SyntaxWarning` while the diagnostic names the
  publication producer and newest endpoint; it restores or discards the
  disposable copy afterward.
- Registry fixtures prove a missing committed source, missing extraction
  marker, empty extraction, duplicate artifact label, or unknown artifact class
  fails rather than compiling the wrong bytes.
- A cleanup fixture forces a compile failure and proves no extraction or
  `__pycache__` residue remains outside the harness temporary root.
- The existing publication, signal-drift, manifest-sync, and structural suites
  run after focused cases to prove no current ceremony or contract regresses.

## Risks and Mitigations

- **Developer machines may lack both endpoints.** Failing validation is
  intentional: the machine cannot prove the repository-wide range. The
  diagnostic reports exact missing roles and supports explicit executable-path
  overrides, but never installs software or converts absence to success.
- **A boundary-only gate can miss an intermediate-minor defect.** The support
  declaration remains inclusive, so a reported intermediate-version failure is
  still a defect. Endpoint compilation is the required local floor, not a claim
  that intermediate testing is unnecessary.
- **The registry can omit a future Python artifact.** Maintainer guidance
  defines registration as part of adding a committed Python entry point or a
  rendered-and-later-executed Python producer. The registry stays explicit so
  ordinary direct heredocs are not misclassified by unreliable heuristics.
- **Direct Python heredocs are not compiled at both endpoints.** This is an
  accepted residual boundary: they execute immediately inside their owning
  shell harness and current structural validation passed under isolated 3.9
  and 3.14 shims. A heredoc promoted into a committed executable or generated
  later-executed artifact must join the explicit registry.
- **Harnesses can drift into separate implementations.** Structural validation
  and the publication integration test call the same focused gate; they do not
  copy endpoint values or extraction rules.
- **Diagnostics can become machine-specific or leak context.** Output is
  limited to declared role/minor, resolved executable path, reported version,
  artifact label, and bounded status/reason fields.

## Success Criteria

1. One machine-readable contract declares the inclusive Python support range
   as 3.9 through 3.14, and every range consumer reads or links to it without a
   second independently editable endpoint declaration.
   - **Measured by**: `bash scripts/test-python-compatibility.sh contract` exits
     0, and a reviewer search for `3.9` and `3.14` confirms executable endpoint
     policy exists only in `schemas/python-support.json` plus fixture inputs and
     historical/design evidence.
2. Every registered committed source and generated Python artifact compiles
   with `-W error::SyntaxWarning -m py_compile` under both declared boundary
   minors.
   - **Measured by**: `bash scripts/test-python-compatibility.sh all` exits 0
     and reports one successful Python 3.9 compile and one successful Python
     3.14 compile for `skills/compound/scripts/validate-frontmatter.py` and the
     extracted publication engine; its committed-source fixture also proves a
     Python 3.10-only syntax mutation is rejected by the Python 3.9 endpoint.
3. Interpreter identity is observable before compile results are evaluated.
   - **Measured by**: the focused happy fixture asserts records containing the
     oldest/newest role, declared minor, absolute resolved path, and full patch
     version for both endpoints.
4. A missing or wrong-version endpoint cannot produce a passing gate or an
   unqualified skip.
   - **Measured by**: focused fixtures for missing oldest, missing newest,
     wrong oldest minor, and wrong newest minor each exit nonzero and name the
     expected endpoint role/minor.
5. The version-dependent invalid-escape regression is detected by the newest
   endpoint against the extracted artifact.
   - **Measured by**: the unique nested-HTTP-regex mutation fixture exits
     nonzero with `SyntaxWarning` promoted to an error and identifies the
     publication producer, artifact label, Python 3.14 role, path, and version.
6. Validation leaves no generated Python or bytecode residue after success or
   failure.
   - **Measured by**: cleanup fixtures force one passing and one failing compile,
     then assert the bounded temporary roots and their `__pycache__` contents
     are absent.
7. Existing release and structural behavior remains green with no real outward
   action.
   - **Measured by**: `bash scripts/test-release-publication.sh all`,
     `bash scripts/test-signal-drift.sh`,
     `bash scripts/test-manifest-version-sync.sh`, and `bash scripts/validate.sh`
     all exit 0 using only repository/disposable fixtures.
8. The feature uses only Bash and Python stdlib and performs no interpreter,
   package, network, remote, or publication mutation.
   - **Measured by**: reviewer inspection of the implementation diff plus a
     dependency/invocation scan; pass requires no new dependency manifest entry,
     downloader, package-manager call, network command, or real-target fixture.

## Open Decisions

None. Approval of this spec approves Python 3.9 through 3.14 as the initial
inclusive range and approves fail-closed endpoint coverage for both the focused
gate and repository validation. Planning may choose private helper names and
exact bounded diagnostic punctuation without changing those contracts.
