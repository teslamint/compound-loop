# Deviation Addendum 017: Release-loop verification hook reachability

_Recorded 2026-08-24 after spec approval and before the draft plan commit. The user still owns plan approval, model-call approval, and merge approval._

## Original contract

The approved specification requires live conformance at the Ship gate. It also requires the same generation digest in the terminal archive.

The specification declares two local transition families:

- the Ship-cleanup transition transfers evidence after merged-result verification;
- the post-Ship completion transition publishes the baseline before Retro.

The current release-loop recognizes only those two transition families. Its Archive procedure marks the loop done before any plan-specific archive check.

## Discovered contradictions

A plan can describe the live evaluation without making it reachable. The current release-loop moves from clean Review directly into shipping.

A resumed Ship can therefore enter the merge gate without running the pilots or full evaluation.

The post-Ship transition runs before Retro. It cannot inspect the archive that the release-loop creates after Retro.

The current Archive procedure can mark the loop done and move `progress.md` before a plan-specific digest check runs. A failed late check would leave no live record for resume.

## Decision

Keep the two approved transition families unchanged.

Add two distinct verification hook families:

- `Release-loop pre-merge verification` runs after clean Review and before shipping reaches its merge gate;
- `Release-loop pre-archive verification` runs after archive evidence staging and before the terminal progress commit point.

Verification hooks do not replace R1 or R2. R1 still owns pre-removal evidence transfer. R2 still owns baseline publication.

The draft plan declares V1 for live evaluation and V2 for archive digest verification.

## Necessity

The live run must block merge. A conversation-only action cannot survive resume.

The archive digest check must run before the loop becomes terminal. A check after the progress move cannot block a later completed-archive lookup.

Exact hook headings give the release-loop a durable and testable dispatch point.

## Observable behavior

On Ship entry or resume, release-loop revalidates the sealed plan. It completes V1 before the merge gate.

The ledger records V1 start, paid approval receipts, process state, generation digest, and acceptance.

During Archive, release-loop persists the exact destination while the live progress record remains nonterminal. It stages evidence, runs V2, and records acceptance.

Only then does it mark the record done and move `progress.md` last.

A V2 failure retains the live progress record, archive destination, staged evidence, and handoff. Resume reuses those exact artifacts.

After terminal commit, release-loop removes the handoff. An interrupted cleanup uses the archived V2 marker to remove only the matching consumed handoff.

## Safety and consent boundaries

V1 never infers paid authorization from plan approval or a prior session. Each paid command requires a current-session first-hand receipt.

V2 is read-only until it marks the handoff consumed. It verifies only contained local paths and exact digests.

Neither hook authorizes merge, remote publication, or a non-fixture target.

## Verification changes

U7 adds source mutations that delete each hook dispatch, resume, ordering, and fail-closed clause.

Fixture tests cover V1 success, failure, prior-session receipt, interruption, and resume before the merge gate.

Archive fixtures cover destination persistence, evidence staging, V2 failure, V2 resume, terminal progress move, consumed handoff cleanup, and interrupted cleanup.

A mutation that marks `phase: done` before V2 acceptance must fail.

A mutation that reports a completed archive while the matching handoff remains unconsumed must fail.

## Traceability

- Approved specification: `docs/specs/2026-08-24-release-loop-conformance-fuzzing-design.md`.
- Draft plan: `docs/plans/2026-08-24-001-feat-release-loop-conformance-fuzzing-plan.md`.
- Current transition contract: `skills/release-loop/references/transition-hooks.md`.
- Current archive contract: `skills/release-loop/references/resume-and-archive.md`.
- Addendum authority: `docs/solutions/workflow-issues/review-introduced-state-machine-deviation.md`.

