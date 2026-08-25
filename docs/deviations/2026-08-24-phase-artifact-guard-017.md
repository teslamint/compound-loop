# Deviation Addendum 017: Executable Phase Artifact Guard

_Recorded 2026-08-24 during U2 review, before release._

## Original contract

The approved specification requires every phase artifact to derive from one exact progress path. The approved plan U2 changes each phase consumer's procedural text and uses deterministic fixtures.

The plan expects standalone implementing to work without a release-loop sibling. It does not name an executable standalone bootstrap or phase-artifact publisher.

## Discovered contradiction

U2 round 1 found that standalone implementing selects a scoped path but cannot create its first complete ledger. Its portability fixture creates a pseudo-ledger for the consumer.

The focused U2 fixture also publishes artifacts through a test-only helper. That helper does not validate the operative ledger, symlink components, tracked index-only paths, or durable ownership. It can reuse a foreign same-byte artifact.

The T6 evidence therefore describes fixture-model behavior rather than the approved transition.

## Necessity

Issue #20 applies to every phase artifact, not only the initial progress record. A procedural instruction followed by a test-only publisher leaves the overwrite boundary probabilistic and unverified.

Standalone implementing cannot depend on the release-loop package. It needs a local packaged entrypoint for its first ledger and artifacts.

## Decision

Extend `skills/release-loop/scripts/run-artifact-integrity.py` with one atomic phase-artifact publication command. The command validates the exact progress record and target root. It rejects tracked, index-only, symlinked, outside-root, and unowned existing targets.

Publication records target identity and SHA-256 in an artifact-root ownership journal. A matching final can be reused only when the journal and bytes agree. A foreign same-byte file without a journal record blocks.

Add a standalone implementing entrypoint under `skills/implementing/scripts/`. It validates the approved plan filename stem, prepares or resumes one scoped ledger, and uses the same publication contract without a release-loop sibling. Its standalone contract remains smaller than the release-loop transition CLI.

Release-loop supplies the exact repo-relative `progress_path` in every phase invocation packet. A phase cannot infer the path from cwd or a glob.

## Observable behavior

- A first standalone implementing invocation creates one complete scoped ledger or resumes one matching record.
- Every phase artifact write executes a packaged publisher.
- Matching owned bytes reuse one final path. Missing ownership, different bytes, tracked state, index-only state, symlink state, and root mismatch block before final publication.
- Stateless plans create no evidence directory or ownership entry for evidence.
- Existing phase order, review semantics, counters, rewrite behavior, and Retro rendering do not change.

## Safety and consent boundaries

Both entrypoints perform repository-local writes only. They authorize no network, push, merge, branch deletion, or publication.

The publisher accepts a transition-owned temporary source under the selected artifact root. It atomically publishes to an absent final path. A failed or cancelled call preserves unrelated finals and journals.

Every fixture uses a disposable repository with pinned Git identity and no hosted remote or credential.

## Verification changes

- Focused tests invoke the packaged publisher instead of `publish_phase_artifact`.
- Standalone portability starts with no ledger and invokes the implementing entrypoint.
- Controls and attacks cover mismatched `artifact_root`, missing or ambiguous progress, absolute and parent paths, symlink progress, symlink sibling parents, dangling targets, tracked and index-only targets, foreign same-byte finals, matching owned reuse, and stateless evidence absence.
- Release-loop mutation coverage removes the exact progress-path phase packet and requires failure.
- T6 evidence records the inner transition exit status and uses real temporary publication, cancellation, compensation, rerun, and headless probes.
- Eval dataset is the U2 consumer group plus standalone portability fixture. Shipping threshold is 100%, with zero external sentinel changes.

## Traceability

- Approved specification: `docs/specs/2026-08-23-run-artifact-integrity-design.md`.
- Approved plan: `docs/plans/2026-08-23-001-fix-run-artifact-integrity-plan.md`.
- U2 initial implementation: `b0ae1fc73c2cb43ab9ef364261381ca1a5abd34b`.
- Review findings: `U2-STANDALONE-001`, `U2-OPERATIVE-002`, `U2-T6-003`, and `U2-COVERAGE-004`.
- Existing deterministic boundary: Addendum 016 and `skills/release-loop/scripts/run-artifact-integrity.py`.
- Addendum authority: `docs/solutions/workflow-issues/review-introduced-state-machine-deviation.md`.
