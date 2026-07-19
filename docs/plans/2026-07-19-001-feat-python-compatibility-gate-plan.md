---
schema: plan/v1
title: Declared Python Compatibility and Generated-Code Warning Gate
type: feat
status: approved
date: 2026-07-19
execution: code
origin: docs/specs/2026-07-19-python-compatibility-generated-code-warning-gate-design.md
---

# Declared Python Compatibility and Generated-Code Warning Gate Plan

## Goal

Add one machine-readable CPython support contract and a strict local gate that
compiles the repository's registered committed and generated Python artifacts
under the oldest and newest supported minors. Integrate that gate into normal
structural and publication validation without adding dependencies, installing
interpreters, or performing any network or outward action.

## Architecture notes

- **Deliverable classification**: this is a code plan. The feature adds a JSON
  contract and executable shell validation, then changes existing validation
  callers and maintainer documentation.
- **Compatibility source of truth**: create `schemas/python-support.json` with
  exactly `schema_version: 1`, `implementation: "CPython"`,
  `minimum_minor: "3.9"`, and `maximum_minor: "3.14"`. Reject missing,
  additional, wrongly typed, malformed, equal, or inverted endpoint fields.
  Consumers derive command names from these values; no executable policy file
  copies the endpoint minors.
- **One focused gate and fixture harness**:
  `scripts/test-python-compatibility.sh` owns both the real-repository gate and
  its disposable negative fixtures. Operational groups are `contract`,
  `endpoints`, `committed`, `generated`, and `all`; `all` runs the real contract,
  endpoint, and both artifact-class checks. A separate `fixtures` group mutates
  only temporary copies and proves failure classification without making every
  normal validation run execute the negative suite.
- **Endpoint resolution**: parse the support contract with the active
  repository `python3`, derive default executable names `python<minor>`, and
  allow absolute `PYTHON_OLDEST` and `PYTHON_NEWEST` path overrides. Resolve
  symlinks with Python stdlib, require executable files, run `--version`, and
  require each reported major/minor to equal its declared role. The full patch
  version and resolved absolute path are emitted before any artifact result.
- **Bounded diagnostics**: success lines begin `ok:   [python-compat]` and
  failures begin `FAIL: [python-compat]`. Endpoint records include role,
  declared minor, resolved path, and full reported version. Artifact records
  additionally include class, label, source/producer, and compile status.
  Failure reasons come from a fixed vocabulary such as `missing`,
  `not-executable`, `identity-failed`, `wrong-minor`, `copy-failed`,
  `marker-count`, `empty-artifact`, and `compile-failed`; do not echo the full
  environment or unbounded subprocess output.
- **Two-class explicit registry**: keep a literal typed registry in the focused
  harness rather than a repository glob. The committed entry is label
  `compound-frontmatter-validator` with source
  `skills/compound/scripts/validate-frontmatter.py`. The generated entry is
  label `release-publication-engine`, producer
  `scripts/release-publication.sh`, start marker containing
  `RELEASE_PUBLICATION_ENGINE_PY`, and the exact closing marker line. A
  committed entry is copied byte-for-byte; a generated entry requires exactly
  one start and one later closing marker and extracts only the bounded body.
- **Single materialization boundary**: each gate invocation creates one private
  `mktemp -d` root, copies or extracts every selected artifact there, and
  compiles those same bytes with both boundary interpreters using
  `-W error::SyntaxWarning -m py_compile`. An EXIT/HUP/INT/TERM trap removes the
  root and every `__pycache__` on success or failure.
- **Caller ownership**: `scripts/validate.sh` invokes the focused `all` group
  and contributes nonzero status to its existing aggregate `FAIL` result.
  `scripts/test-release-publication.sh` keeps its named
  `embedded_engine_syntax_warnings` integration case but delegates to the
  focused `generated` group. Neither caller implements endpoint discovery,
  registry entries, extraction, or compilation itself.
- **Maintainer guidance**: add a concise Python compatibility subsection to
  `README.md` that links `schemas/python-support.json`, explains strict
  boundary coverage and path overrides, and names the `all` and `fixtures`
  commands. It refers readers to the contract instead of restating endpoint
  values.
- **Known Pattern — disposable validation copies**:
  `scripts/test-manifest-version-sync.sh` establishes isolated copy/mutate/run,
  check-specific diagnostics, aggregate case reporting, and cleanup. Reuse
  those behaviors while avoiding recursive `scripts/validate.sh` calls inside
  the compatibility harness itself.
- **Known Pattern — generated warning regression**:
  `docs/solutions/test-failures/generated-python-version-warning-gate.md`
  requires compiling the extracted artifact, recording interpreter identity,
  and treating stderr warnings as protocol-visible failures.
- **Known Pattern — empirical fixture grounding**:
  `docs/solutions/workflow-issues/spec-review-empirical-grounding-gap.md`
  requires every disposable mutation to fail at its intended compatibility
  mechanism rather than an unrelated existing check. Each negative case must
  assert the `[python-compat]` marker and the named reason.
- **Known Pattern — approved-artifact truth**:
  `docs/deviations/2026-07-19-python-gate-assumption-evidence-002.md` preserves
  the A5 evidence-command contradiction and supplies the corrected unique
  fixed-string precondition. Any later observable departure from the approved
  spec or this plan follows
  `docs/solutions/workflow-issues/review-introduced-state-machine-deviation.md`.
- **External research**: none required. The plan uses existing repository
  Bash/Python-stdlib conventions and three direct local precedents:
  `scripts/validate.sh`, `scripts/test-manifest-version-sync.sh`, and
  `scripts/test-release-publication.sh`.
- **Risks and dependencies**:
  - A developer missing one boundary interpreter will make normal validation
    fail. This is the approved honest-degradation behavior; diagnostics name
    the missing role and the README documents path overrides without installing
    software.
  - A future unregistered Python artifact can escape endpoint compilation.
    The explicit registry is intentional; README guidance makes registration
    part of adding a committed entry point or later-executed generated source.
  - Boundary compilation does not prove every intermediate minor. The support
    promise remains inclusive, while endpoint compilation is the approved local
    floor and any intermediate-version failure remains a defect.
  - `py_compile` creates bytecode beside its input by default. Materializing
    both artifact classes only inside the trapped temporary root prevents
    tracked-tree residue.
  - Existing fixture harnesses call `scripts/validate.sh` from disposable
    copies. They inherit the strict endpoint gate and must pass through the
    system boundary interpreters or explicit test overrides; no fixture may
    silently bypass the new check.

## Global constraints

- Do not install, download, or select a different supported Python range during
  implementation. The approved contract is inclusive CPython 3.9 through 3.14.
- Do not add package, container, version-manager, CI, or network dependencies.
- Do not run a real publication, contact a remote, or mutate a real repository
  outside the tracked feature worktree; negative fixtures use bounded temporary
  copies only.
- Do not change `scripts/release-publication.sh` runtime behavior or its exact
  machine-output contract.
- Do not infer artifacts with globs. Only explicit typed registry entries are
  compiled by this feature.
- Do not classify directly executed Python heredocs as committed entry points
  or generated-later artifacts.
- Do not turn a missing or mismatched boundary into a skip or exit-zero result.
- Do not copy endpoint values into README or caller scripts; derive executable
  defaults from `schemas/python-support.json`.
- Run `bash scripts/validate.sh` after every implementation commit. Both
  boundary interpreters are available in the current environment.

## Assumption Recheck

All five live assumptions retained by the approved spec were rerun exactly on
`feat/python-generated-warning-gate` at `2026-07-19T12:38:21+09:00`. One
evidence-command contradiction is resolved by committed Deviation Addendum
002; no assumption is unavailable.

| ID | Approved claim | Fresh command evidence | Outcome |
|---|---|---|---|
| A1 | No implemented supported-Python range or machine-readable compatibility contract exists before this feature. | `grep -R -n -i -E 'supported Python|Python support|requires-python|python_requires' . --exclude-dir=.git --exclude-dir=.entirecontext` now finds the approved origin spec and `CONCEPTS.md` vocabulary in addition to the ROADMAP, retro, and solution. It still finds no `schemas/python-support.json`, packaging metadata, or executable policy declaration. | match |
| A2 | Python 3.9 is the lowest observed minor that runs the typed frontmatter validator, while Python 3.8 cannot. | `for p in python3.8 python3.9; do "$p" skills/compound/scripts/validate-frontmatter.py docs/solutions/test-failures/generated-python-version-warning-gate.md; done` reproduced Python 3.8.10's `TypeError: 'type' object is not subscriptable`; Python 3.9.25 returned `OK` for the same document. | match |
| A3 | Exact Python 3.9 and 3.14 boundary interpreters are available and pass current structural validation. | The retained isolated-shim loop selected Python 3.9.25 and Python 3.14.6 as the unversioned `python3` in separate runs; both `bash scripts/validate.sh` invocations ended with `ALL CHECKS PASSED`. | match |
| A4 | The extracted publication engine is warning-clean on both boundary interpreters. | The retained `mktemp` plus `awk` extraction command compiled the same extracted `engine.py` with Python 3.9 and Python 3.14 using `-W error::SyntaxWarning -m py_compile`; the loop exited 0 and removed the temporary root. | match |
| A5 | The doubled-escape nested HTTP regex is a unique mutation target. | The retained inline Python count command returned `0`, contradicting its approved observed result. Addendum 002 records the quoting defect. Its corrected `grep -F -c 'match=re.fullmatch(r"HTTP/(?:1\\.1|2(?:\\.0)?)' scripts/release-publication.sh` returned `1` and identified line 463. | contradiction |

The A5 contradiction is nonblocking because commit `1b297f2` records the
required separate addendum before this plan. The approved spec remains
unchanged; implementation consumes the corrected evidence command from that
addendum.

## File structure

### Compatibility contract and focused gate

- Create: `schemas/python-support.json` — single machine-readable CPython
  implementation and inclusive minor endpoints.
- Create: `scripts/test-python-compatibility.sh` — contract parser, endpoint
  resolver, typed artifact registry, materialization/compile gate, grouped
  disposable fixtures, bounded diagnostics, and cleanup.

### Existing validation consumers

- Modify: `scripts/validate.sh` — invoke the focused `all` group as a numbered
  compatibility check and preserve its nonzero status in aggregate validation.
- Modify: `scripts/test-release-publication.sh` — delegate the existing
  generated-engine warning case to the focused `generated` group and assert the
  shared diagnostic identity.

### Maintainer guidance

- Modify: `README.md` — link the support contract, focused gate/fixture commands,
  strict missing-endpoint behavior, override names, and explicit registration
  responsibility without duplicating the supported minors.

## Scenario coverage map

| S-ID | Scenario | Ordered unit chain | Walking evidence |
|---|---|---|---|
| S1 | Validate registered artifacts across the declared range | U1 -> U2 -> U3 | U3 integration case `validate_all_registered_artifacts` runs `bash scripts/validate.sh`, observes both endpoint identities and four artifact/endpoint pass records, and ends `ALL CHECKS PASSED`. Covers S1. |
| S2 | Diagnose an incomplete local environment | U1 -> U3 | U3 integration case `validate_missing_oldest_endpoint` runs validation in a disposable copy with an absolute nonexistent `PYTHON_OLDEST`, asserts nonzero plus the oldest/missing diagnostic, and asserts the newest identity is still reported. Covers S2. |
| S3 | Use explicitly selected endpoint interpreters | U1 -> U2 | U2 integration case `absolute_endpoint_overrides` supplies exact Python 3.9 and 3.14 paths, verifies their resolved identities and all selected artifact compiles, then proves a Python 3.10 path in the oldest role fails `wrong-minor`. Covers S3. |
| S4 | Catch a version-dependent generated-code warning | U2 -> U3 | U3 integration case `invalid_outer_escape_fails_validation` mutates the one addendum-proved regex in a disposable copy, runs `bash scripts/validate.sh`, and requires a newest-endpoint `compile-failed` diagnostic naming the publication producer before aggregate failure. Covers S4. |
| S5 | Register a future generated Python artifact | U2 | U2 integration case `additional_generated_registry_entry` adds a fixture-only second generated producer/typed registry entry inside a temporary copy and proves both boundary compiles succeed without changing endpoint logic or the support contract. Covers S5. |

## Requirements-to-units trace

| Spec requirement | Owning units |
|---|---|
| R1 single compatibility declaration | U1, U3 |
| R2 inclusive minor semantics | U1, U2 |
| R3 boundary identity | U1 |
| R4 fail-closed degradation | U1, U3 |
| R5 explicit local overrides | U1, U2 |
| R6 explicit two-class compatibility registry | U2 |
| R7 warning-as-error compilation | U2 |
| R8 consumer integration | U3 |
| R9 cleanup and isolation | U1, U2 |
| R10 existing behavior and no new dependency | U3 |

## Implementation Units

## U1: Compatibility contract and strict endpoint resolution
Execution note: test-first
Files:
  Create: schemas/python-support.json, scripts/test-python-compatibility.sh
  Modify: none
  Test: scripts/test-python-compatibility.sh
Interfaces:
  Consumes: repository root; `schemas/python-support.json` with exact keys `schema_version`, `implementation`, `minimum_minor`, and `maximum_minor`; optional absolute executable paths `PYTHON_OLDEST` and `PYTHON_NEWEST`; command group `<contract|endpoints|fixtures>` at this unit boundary
  Produces: validated CPython endpoint roles `oldest` and `newest`; default commands derived as `python<minimum_minor>` and `python<maximum_minor>`; resolved absolute executable path plus full version per role; bounded `ok:   [python-compat]` or `FAIL: [python-compat]` records; nonzero exit on any contract or endpoint failure; one trapped private temporary root
Test scenarios:
  happy: `contract` accepts only schema version 1, CPython, minimum 3.9, and maximum 3.14; `endpoints` resolves the local Python 3.9.25 and Python 3.14.6 binaries and reports both identities before returning zero. Covers AE1, Covers AE3
  edge: absolute symlink/path overrides resolve to the same binaries; patch versions are reported but not pinned; a valid future patch within the declared minor remains acceptable
  error: missing file, malformed JSON, extra/missing/wrongly typed field, non-minor string, equal/inverted range, relative override, missing/non-executable override, failing `--version`, wrong implementation, and wrong role minor each produce a check-specific nonzero result with no traceback or environment dump. Covers AE4
  integration: `validate_missing_oldest_endpoint` fixture retains a valid newest endpoint while the oldest is absent and proves fail-closed diagnostics needed by S2; endpoint overrides expose the identities consumed by S3. Covers S2, Covers S3
Steps:
  1. Create the grouped shell harness with aggregate case reporting and cleanup, then add red `contract` and `endpoints` fixture cases for every happy, edge, and error scenario above; run `bash scripts/test-python-compatibility.sh fixtures` and confirm failures are missing-contract/resolver assertions rather than harness setup errors.
  2. Add `schemas/python-support.json` with the exact four-field contract and implement bounded JSON/schema validation using Python stdlib; derive endpoint command names only from the parsed minor values.
  3. Implement override validation, stdlib absolute-path resolution, executability checks, bounded `--version` capture, exact role-major/minor comparison, and identity-first diagnostics. Continue resolving/reporting the other endpoint after one endpoint fails, but keep the aggregate result nonzero and do not begin artifact work.
  4. Add signal-safe temporary-root cleanup and fixtures proving missing endpoints, wrong-role versions, and failing identity commands leave no directory or unbounded subprocess output.
  5. Run `bash scripts/test-python-compatibility.sh contract`, `endpoints`, and `fixtures`; run `bash scripts/validate.sh`; confirm the new standalone harness is green while existing structural validation remains unchanged.
  6. Commit: "feat(validation): Declare Python compatibility endpoints"
Acceptance: `bash scripts/test-python-compatibility.sh contract`, `bash scripts/test-python-compatibility.sh endpoints`, and `bash scripts/test-python-compatibility.sh fixtures` exit 0; the endpoint output names resolved Python 3.9 and 3.14 paths/full versions; every invalid/missing fixture asserts a `[python-compat]` reason and nonzero inner gate; no temporary root remains; `bash scripts/validate.sh` exits 0 before consumer integration.

## U2: Two-class artifact materialization and boundary compilation
Execution note: test-first
Files:
  Create: none
  Modify: scripts/test-python-compatibility.sh
  Test: scripts/test-python-compatibility.sh
Interfaces:
  Consumes: reviewed U1 contract parser, endpoint identities, private temporary root, and command groups; literal typed registry entries `committed|compound-frontmatter-validator|skills/compound/scripts/validate-frontmatter.py` and `generated|release-publication-engine|scripts/release-publication.sh|<start-marker>|<end-marker>`; corrected unique-regex evidence command from Deviation Addendum 002
  Produces: byte-for-byte temporary copy of the committed validator; bounded extraction of the publication engine; one `-W error::SyntaxWarning -m py_compile` invocation per selected artifact and endpoint; artifact records containing class, label, source/producer, endpoint role/path/version, and status; `committed`, `generated`, and `all` operational groups; nonzero aggregate result on any copy, extraction, registry, warning, or compile failure
Test scenarios:
  happy: real committed validator and extracted publication engine each compile under both exact endpoint interpreters, producing four pass records; the materialized files match their tracked/extracted source bytes. Covers AE2
  edge: Python 3.9 rejects a disposable committed-validator copy containing a Python 3.10 `match` statement; a fixture-only second generated producer registers through the same typed entry shape and compiles under both endpoints; paths containing spaces remain inside the temporary root. Covers S5
  error: missing committed source, unknown/duplicate class or label, missing/duplicate/reversed generated markers, empty extraction, copy failure, and newest-endpoint invalid outer escape each fail with the owning class/label/source/role; the addendum fixed-string precheck must equal one before the invalid-escape mutation runs; pass and forced-failure cases both prove the temporary root and `__pycache__` are absent afterward. Covers AE5, Covers AE6
  integration: `absolute_endpoint_overrides` compiles both artifact classes with explicit correct endpoints and rejects Python 3.10 in the oldest role; `additional_generated_registry_entry` compiles a future-style generated entry without another range declaration. Covers S3, Covers S5
Steps:
  1. Add red registry/materialization cases to the `fixtures` group, including exact byte checks, every error classification above, the Python 3.10-only committed-source mutation, the additional generated entry, and the addendum-corrected one-match invalid-escape precondition.
  2. Implement the literal typed registry, rejecting unknown classes and duplicate labels. Copy committed entries and extract generated entries only into the U1 temporary root; require exactly one ordered marker pair and nonempty bytes.
  3. Compile each selected materialized file with oldest then newest using each resolved executable's absolute path and `-W error::SyntaxWarning -m py_compile`. Emit identity-bearing artifact records and preserve nonzero aggregate status without hiding the bounded compiler diagnostic.
  4. Implement `committed`, `generated`, and `all` selection. Ensure `all` performs only operational checks, while `fixtures` owns disposable negative mutations and aggregate case reporting.
  5. Run the corrected fixed-string count against the real publication script, then run `committed`, `generated`, `all`, and `fixtures`. Scan the tracked tree and temporary parent for `__pycache__`/materialized residue after both pass and forced compile failure.
  6. Run `bash scripts/validate.sh` and commit: "test(validation): Gate Python artifacts across endpoints"
Acceptance: all four focused operational groups and `fixtures` exit 0; output contains four real artifact/endpoint pass records; the Python 3.10-only and invalid-escape mutations fail only through their intended inner endpoint compiles; added generated-entry coverage passes without a second range declaration; no tracked or temporary residue survives; `bash scripts/validate.sh` remains green.

## U3: Structural, publication, and maintainer integration
Execution note: characterization-first
Files:
  Create: none
  Modify: scripts/validate.sh, scripts/test-release-publication.sh, README.md
  Test: scripts/test-python-compatibility.sh, scripts/test-release-publication.sh, scripts/test-signal-drift.sh, scripts/test-manifest-version-sync.sh, scripts/validate.sh
Interfaces:
  Consumes: reviewed `bash scripts/test-python-compatibility.sh <generated|all|fixtures>` interface and its `[python-compat]` diagnostics; existing `FAIL` aggregation in `scripts/validate.sh`; publication case `embedded_engine_syntax_warnings`; existing disposable-copy harness conventions
  Produces: numbered structural-validation invocation of the strict `all` gate; publication integration delegation to `generated`; README compatibility/override/registration guidance linked to `schemas/python-support.json`; full S1/S2/S4 end-to-end disposable validation evidence; unchanged publication engine and machine-output bytes
Test scenarios:
  happy: real `bash scripts/validate.sh` reports both endpoint identities, four artifact pass records, one compatibility success, and final `ALL CHECKS PASSED`; publication, signal-drift, and manifest suites remain green. Covers S1, Covers AE7
  edge: publication integration calls the shared generated group exactly once; README names contract and commands without a copied endpoint pair; existing disposable validation copies inherit the system endpoints and clean up normally
  error: disposable `PYTHON_OLDEST` absence makes validation fail while retaining the newest identity; disposable invalid-escape mutation at the addendum-proved unique target fails validation through `compile-failed` on the newest role; wrong registry/extraction cannot be downgraded by caller status handling. Covers S2, Covers S4
  integration: `validate_all_registered_artifacts`, `validate_missing_oldest_endpoint`, and `invalid_outer_escape_fails_validation` walk S1, S2, and S4 through the public `scripts/validate.sh` entry point; the existing publication case proves its consumer no longer selects only active `python3`; the final dependency/invocation scan proves no package, downloader, network, real-remote, or publication-mutation path was added. Covers S1, Covers S2, Covers S4, Covers AE8
Steps:
  1. Extend compatibility `fixtures` with disposable-copy S1/S2/S4 integration cases that expect `scripts/validate.sh` to own the focused gate; add a static publication assertion that the existing embedded-engine case delegates to `generated`. Run them and confirm they are red because consumer integration is absent, not because endpoint setup or an older validator check fails.
  2. Add compatibility check 8 to `scripts/validate.sh`. Invoke `bash "$ROOT/scripts/test-python-compatibility.sh" all`, preserve bounded output, set aggregate `FAIL=1` on nonzero, and emit no second success claim that could disagree with the focused gate.
  3. Replace the publication harness's local extraction/current-`python3` compile body with one call to the focused `generated` group. Keep the case name/group membership unchanged and assert the shared publication artifact plus both endpoint records.
  4. Add README maintainer guidance linked to the JSON contract. Document `all`, `fixtures`, strict missing-endpoint failure, absolute override variables, two registry classes, and the direct-heredoc boundary without restating supported minors.
  5. Run compatibility operational/fixture groups and all three end-to-end disposable cases. Confirm the invalid-escape fixture mutates exactly one copied source line, names the newest endpoint, and never changes the real publication script.
  6. Run `bash scripts/test-release-publication.sh all`, `bash scripts/test-signal-drift.sh`, `bash scripts/test-manifest-version-sync.sh`, and `bash scripts/validate.sh`. Scan the implementation diff for package-manager/download/network commands, real remote names, publication mutations, duplicate endpoint literals outside allowed fixture/history evidence, and temporary/bytecode residue.
  7. Commit: "feat(validation): Enforce Python compatibility gate"
Acceptance: all focused and existing suites exit 0; direct validation shows two endpoint identities, four artifact passes, and `ALL CHECKS PASSED`; S1/S2/S4 disposable integration cases prove success, missing-oldest fail-closed behavior, and newest invalid-escape detection; publication's warning case delegates to shared behavior; README links the single contract without a second policy declaration; `git diff` shows no change to `scripts/release-publication.sh`.

## Mutation/failure-state matrix

The compatibility gate reads tracked inputs, materializes copies only under a
trapped temporary directory, invokes `py_compile` on those copies, emits
diagnostics, and exits. Its temporary files and bytecode are cleanup-scoped
test artifacts, not deliverable state that persists across invocations. It has
no USER gate, headless mutation mode, remote call, repository write, or durable
partial result to resume, roll back, or compensate. When a release ceremony
calls `scripts/validate.sh`, that caller owns any later commit/tag transition;
this deliverable itself runs before and does not cross that side-effect
boundary.

No stateful ceremony in the deliverable; no mutation/failure-state matrix required.

## Deferred to Follow-Up Work

- Running the full suite on every intermediate supported minor remains outside
  this endpoint gate; an observed intermediate-minor failure is still a defect.
- Compiling directly executed Python heredocs at both endpoints remains the
  approved residual boundary unless one becomes a committed entry point or
  later-executed generated artifact.
- External CI, containers, interpreter installation/version management, PyPy,
  prerelease Python, and support beyond the approved range remain separate
  policy decisions.
- Removing the delivered P2 ROADMAP row belongs to the retrospective after
  implementation, review, and merge evidence.
- The planned `$release 0.3.0` begins only after this feature completes its
  lifecycle; it is not an implementation unit here.

## Open unknowns

**Planning-time**: none. The approved spec and Deviation Addendum 002 fix the
range, fail-closed behavior, artifact classes, consumer ownership, safety
boundary, and corrected mutation precondition.

**Implementation-time**:

- Private shell function and local variable names may change while preserving
  the command groups, environment override names, registry semantics, bounded
  diagnostic fields, cleanup, and exit behavior defined here.
- The exact temporary filenames may vary while remaining inside one trapped
  root and retaining artifact labels in diagnostics.
- Full interpreter version suffixes may differ by local patch build; validation
  must preserve and report the complete bounded `--version` line while matching
  only the declared major/minor role.
