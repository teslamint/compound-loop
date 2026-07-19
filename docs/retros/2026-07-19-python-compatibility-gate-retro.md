# Retro: Python compatibility and generated-code warning gate

- Date: 2026-07-19
- Source: merged range `4d3e85e..1856a4f`
- Spec: `docs/specs/2026-07-19-python-compatibility-generated-code-warning-gate-design.md`
- Plan: `docs/plans/2026-07-19-001-feat-python-compatibility-gate-plan.md`

## Release data

| Metric | Value |
|---|---|
| Code delta (product / test / docs) | +12/-0 / +777/-7 / +716/-0 |
| Commits | 11 |
| Review rounds | 9 named rounds: 5 internal implementation/final + 4 external spec/plan/unit notes |
| Comments (fixed / deferred) | 5 / 1 deduplicated actionable findings; the deferred external U3 LOW and final-review Minor are the same contract-pinning item |
| CI failures | 0; no PR CI run, fresh merged-main repository suites all passed |
| Duration (first spec commit → merge) | <1 day; 1h30m from `988a497` to `1856a4f` |
| Units planned / completed | 3 / 3 |

Product is the machine-readable support contract and structural-validation
integration. Test is the compatibility harness and publication-harness
integration. Docs are the spec, plan, deviation addendum, README, and concepts
changes.

## Success criteria: measured vs declared

All measurements below were rerun fresh on merged `main` during this
retrospective. The full publication suite used only disposable repositories,
local bare remotes, and stubs.

| # | Declared criterion | Measurement (command / rubric) | Measured result | Verdict |
|---|---|---|---|---|
| AE1 | One machine-readable contract declares 3.9 through 3.14, and consumers do not own a second endpoint declaration | `bash scripts/test-python-compatibility.sh contract`; reviewer `rg` search for `3.9` and `3.14` across executable consumers | Contract exited 0 with `schema=1 implementation=CPython range=3.9..3.14`; executable policy is in `schemas/python-support.json`, while other endpoint literals are fixture inputs or historical/design evidence; README links the contract and `scripts/validate.sh` pins it | Met |
| AE2 | Every registered committed and generated Python artifact compiles warning-strict under both boundary minors | `bash scripts/test-python-compatibility.sh all`; `boundary_compile_failures` fixture in `bash scripts/test-python-compatibility.sh fixtures` | `all` exited 0 with four artifact records: committed validator and generated publication engine each passed Python 3.9.25 and 3.14.6; the match-statement mutation produced exactly one oldest failure and one newest pass | Met |
| AE3 | Interpreter identity is observable before compile results | Focused happy fixture assertions for role, declared minor, resolved path, and full patch version | Fresh output named oldest/newest, expected 3.9/3.14, absolute Cellar paths, and full versions 3.9.25/3.14.6 before the four artifact results; fixtures passed | Met |
| AE4 | Missing or wrong-version endpoints fail rather than pass or skip | `validate_missing_oldest_endpoint_and_failures` plus public `validate_missing_oldest_endpoint` fixture | Missing oldest/newest and wrong oldest/newest cases returned nonzero with the expected role/minor; peer endpoint evaluation continued; public validation emitted `CHECKS FAILED` and no false success | Met |
| AE5 | The version-dependent invalid escape is rejected by the newest endpoint against the extracted artifact | `boundary_compile_failures` and `invalid_outer_escape_fails_validation` fixtures after the corrected `grep -F` count | Corrected unique-match precondition equaled one; mutated publication artifact produced exactly one Python 3.14 `compile-failed` record with producer/label/path/version while Python 3.9 passed | Met |
| AE6 | Success and failure leave no generated Python or bytecode residue | Cleanup assertions in the boundary and public-validation fixtures; post-suite `find` for `__pycache__`, `*.pyc`, and `compound-loop-python-compat.*` | Passing and forced-failure fixture temp parents were empty; post-suite tracked-tree and temporary-parent scans returned no residue | Met |
| AE7 | Existing release and structural behavior remains green without real outward action | `bash scripts/test-release-publication.sh all`; `bash scripts/test-signal-drift.sh`; `bash scripts/test-manifest-version-sync.sh`; `bash scripts/validate.sh` | Publication `100/100`; signal drift A-I and manifest sync A-E passed; validator reported both identities, four artifact passes, and `ALL CHECKS PASSED`; no real outward target was used | Met |
| AE8 | Only Bash/Python stdlib are used and no interpreter, dependency, network, remote, or publication mutation is introduced | Reviewer inspection of `git diff 4d3e85e..1856a4f`, dependency-manifest scan, added-invocation scan, and release-engine diff | No dependency manifest, installer, downloader, network command, real-target fixture, or publication mutation was added; `scripts/release-publication.sh` has a zero-line diff | Met |

## Carry-forward from previous retro

Previous retro:
`docs/retros/2026-07-19-gated-outward-publication-retro.md`.

| Item | Status | Evidence |
|---|---|---|
| Declared Python compatibility and generated-code warning gate | Done | `4f06454`, `5d7def4`, `b8ceac1`, and `1856a4f` deliver the contract, strict endpoints, two artifact classes, consumer integration, and review fixes; AE1-AE8 pass fresh on merged `main`; remove the delivered ROADMAP row |
| First real gated-publication smoke | Not started | This arc intentionally performed no real outward action; the P2 remains user-owned and requires new first-hand approval naming an intentionally publishable target/version |
| Diff-size metric reconciliation across phases | Not started | This retro classifies the merged range once but adds no cross-phase metric contract; keep the P3 row untouched |
| Clean-environment Codex install check | Not started | No isolated plugin installation was exercised; keep the P3 row untouched |
| Automated numbered-reference validation | Not started | No numbered planning/schema hard-floor insertion or validator implementation occurred; keep the P3 row untouched |

## Findings

### What worked well

- **What happened**: The first live planning Assumption Recheck reran the
  approved A5 evidence command exactly and observed `0`, contradicting its
  recorded result of `1`. Deviation Addendum 002 (`1b297f2`) preserved approved
  spec commit `4566b7c`, recorded the quoting defect and corrected `grep -F`
  result, and preceded plan approval `b751e1f`. The plan kept A5 classified as
  `contradiction`, and U2/U3 required the corrected count before mutation.
  **Why**: The truth-maintenance contract treats evidence commands as
  executable claims rather than prose that planning may silently reinterpret.
  **How to apply**: Rerun retained commands byte for byte, preserve mismatches
  as contradictions, commit a separate addendum before downstream approval,
  and bind implementation to the corrected fail-closed evidence.

- **What happened**: The two boundary mutations proved opposite failure
  directions: Python-3.10 `match` syntax failed only on the 3.9 endpoint, while
  the invalid escape failed only on 3.14 because pre-3.12 treats it as a
  `DeprecationWarning`; each case asserted that the opposite endpoint still
  ran and passed.
  **Why**: The compiler loop aggregates failures after visiting both exact
  endpoints instead of short-circuiting on the first failure.
  **How to apply**: Boundary compatibility tests should prove both the expected
  failure and the opposite-endpoint pass; a single aggregate nonzero result is
  too weak to establish which boundary detects the regression.

### What to improve

- **What happened**: Internal U1 review found unquoted resolved interpreter
  execution, so a valid absolute path containing spaces failed. Commit
  `5d7def4` quoted both invocations and added a mutation-proven regression.
  **Why**: The resolver validated an absolute path but the later command
  position lost that path's byte boundary through shell word splitting.
  **How to apply**: When an interface promises absolute path overrides, include
  a path-with-spaces case before approval and review every later execution site,
  not only resolution and validation.

- **What happened**: External U1 review correctly required structural check 8
  to pin `PYTHON_SUPPORT_FILE`, and `1856a4f` applied it. External U3 review and
  final branch review then observed that the standalone publication harness
  delegates to `generated` without the same pin. It still fails closed and did
  not affect AE7, but the preventive inconsistency remains accepted.
  **Why**: Consumer integration hardened the production structural entry point
  but treated the test-harness caller as a clean-environment consumer even
  though the contract path is an inheritable fixture seam.
  **How to apply**: Pin tracked policy inputs at every non-fixture consumer
  boundary; register the publication-harness pin as a durable P3 test-integrity
  follow-up rather than leaving it only in review prose.

### Process observations

- **What happened**: Review layers found different gaps: external spec review
  added committed Python entry points as a second registry class in `18bbd14`;
  external plan review added AE6/AE8 trace tags in `683db33`; external U1 review
  drove tracked-contract pinning in U3; internal U1 review fixed paths with
  spaces in `5d7def4`; internal U2 review sharpened the reversed-marker fixture
  in `1856a4f`; external U3/final review accepted one shared nonblocking pinning
  follow-up.
  **Why**: Pre-approval review challenged inventory completeness, planning
  review challenged traceability, unit review exercised shell and fixture
  semantics, and final review compared consumer boundaries across units.
  **How to apply**: Keep review source and round identity. Deduplicate the U3
  external LOW and final-review Minor as one deferred finding rather than
  inflating totals or silently dropping it.

- **What happened**: The approved plan used the exact read-only matrix sentinel
  rather than inventing state-machine rows for temporary compile artifacts.
  All three units completed without a durable partial state, rollback, resume,
  USER gate, remote action, or outward mutation.
  **Why**: Temporary copies and bytecode are cleanup-scoped test artifacts, not
  deliverable state that persists across invocations.
  **How to apply**: Keep the mutation/failure-state matrix mandatory for
  stateful ceremonies, but record a concrete read-only judgment when the
  deliverable has no durable transition instead of creating ceremonial rows.

## Carry-forward items registered

| Item | Type | Priority | Tracked at |
|---|---|---|---|
| Pin the tracked Python support contract in every non-fixture compatibility consumer, including the publication harness delegation | process | P3 | `ROADMAP.md` Carry-forward from retros |

## Lessons

- An approved claim can remain true while its approved evidence command is
  false; preserve that distinction with an addendum instead of silently fixing
  the command.
- A boundary mutation proves compatibility only when the expected endpoint
  fails and the opposite endpoint is shown to continue and pass.
- A validated path is not a safely executed path until command-position quoting
  is tested with spaces.
- Read-only matrix judgments should name the absent durable boundary; they
  should not manufacture rollback rows for cleanup-scoped temporary files.

## Compounding

- compound invocation: `Documentation complete — docs/solutions/workflow-issues/approved-assumption-evidence-command-contradiction.md`
