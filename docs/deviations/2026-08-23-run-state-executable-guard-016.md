# Deviation Addendum 016: Executable Run-State Guard

_Recorded 2026-08-23 during U1 review, before release._

## Original contract

The approved specification defines scoped artifacts, closed path roots, review state, and exact-head evidence. It assigns run-scope resolution to the release-loop orchestrator.

The approved plan implements U1 through procedural skill text and deterministic fixtures. Its File structure does not name a packaged run-state command. The plan rejects a new runtime dependency but does not forbid a standard-library helper.

## Discovered contradiction

U1 round 1 found that the focused fixture used a self-contained Python model. It did not execute the operative release-loop path.

The first correction moved that model into `progress-schema.md`. The test extracted and executed the Markdown block, but release-loop had no command that invoked it. Round 2 therefore found the same missing execution boundary. It also measured a 13,675-byte schema-reference increase and duplicate code/prose ownership.

Procedural text alone cannot prove that an agent performs path checks before durable mutation. A test-only oracle cannot supply that proof.

## Necessity

Issue #20 is a data-integrity defect. A missed path check can overwrite tracked artifacts or move state outside the repository. This boundary must be deterministic and directly executable.

Keeping the Markdown oracle would retain the false-green gap and increase instruction payload. Removing all executable logic would return to unverified agent interpretation.

## Decision

Move run discovery and local artifact transitions to one packaged Python standard-library CLI:

`skills/release-loop/scripts/run-artifact-integrity.py`

The release-loop skill names the exact command for initialization, discovery, handoff, and archive. The CLI owns validation and mutation. The skill owns phase sequencing and USER gates.

Delete the embedded Python oracle from `progress-schema.md`. Keep concise input, output, failure, and state rules there.

The CLI prints one JSON object on stdout after success. It prints one named diagnostic on stderr and exits nonzero on blocked or invalid state. It never prints credentials or unbounded file content.

## Observable behavior

- New-loop initialization calls the packaged guard before its first state write.
- Resume calls the guard to discover or validate an exact progress path.
- Handoff and archive call the guard before source or destination mutation.
- Missing commands, invalid paths, unknown schemas, ambiguous records, collisions, and integrity mismatches fail before the protected transition.
- Existing phase order, USER gates, progress fields, terminal signals, and archive outcomes do not change.
- Legacy progress remains supported under the approved partial-compatibility rules.

## Safety and consent boundaries

The CLI performs only repository-local state transitions already authorized by the approved spec. It grants no push, merge, branch deletion, network access, publication, or consent exception.

Every test uses a disposable repository with no hosted remote or credential. Failure injection is fixture-only and requires an explicit test environment value. Production calls do not set it.

The CLI validates repo-relative input, rejects absolute and parent paths, rejects symlink components, and verifies every physical source and destination parent against its closed root.

## Verification changes

- The focused fixture invokes the packaged CLI as a subprocess. It does not import or dynamically execute a Markdown implementation.
- A mutation removes or changes each exact skill invocation. The structural grader must reject the mutated contract.
- U1 retains the handoff, interrupted archive, legacy, unknown-schema, index-only collision, and four-root attack cases.
- Eval dataset: the named run-integrity fixture cases in `scripts/test-run-artifact-integrity.sh`.
- Deterministic grader: exit status, named diagnostic, exact JSON fields, Git identity, file bytes, and external sentinels.
- Shipping threshold: 100% of registered cases pass; every attack blocks for its intended mechanism; zero external sentinel changes.
- `scripts/validate.sh` runs the fast dataset on every change.

## Traceability

- Approved specification: `docs/specs/2026-08-23-run-artifact-integrity-design.md`.
- Approved plan: `docs/plans/2026-08-23-001-fix-run-artifact-integrity-plan.md`.
- Initial U1 implementation: `1a4bb72d7b14c83cbbe1935bdd4470e65ea314ec`.
- Test-only Markdown oracle correction: `c4d119efa943db5b28884d176a37a957cd318430`.
- Review findings: `U1-TEST-003`, `U1-OPERATIVE-001`, and `U1-COMPLEXITY-002`.
- Affected runtime contracts: `skills/release-loop/SKILL.md`, `skills/release-loop/references/progress-schema.md`, `skills/release-loop/references/resume-and-archive.md`, and `skills/release-loop/references/transition-hooks.md`.
- Addendum authority: `docs/solutions/workflow-issues/review-introduced-state-machine-deviation.md`.
