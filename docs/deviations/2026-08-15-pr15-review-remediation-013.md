# Deviation Addendum 013: PR #15 review remediation and pinned R2 packet override

_Recorded 2026-08-15 after approval of `docs/plans/2026-08-15-001-fix-planning-discrimination-and-verdict-coverage-plan.md` and CodeRabbit review of PR #15. The approved specification, body-sealed plan, and Deviation Addendum 012 remain unchanged. This draft records no USER approval, merge authorization, or issue-mutation authorization._

## Original contract

The approved plan and Addendum 012 fix four relevant behaviors:

1. The Discrimination check applies to every step that compares two things, but its fixture requirements are written only in artifact terms.
2. R2 verifies the issue-closure packet at SHA-256 `8168d671af3c457c36afa79e8b8c0217fbce96af0f07e7e8dc563687b8b1aaa7`; that packet pins issue #11 payload SHA-256 `6a823211c87178f4d61c2f2a054a483fe5d471c80c5f8000252993e97d9092b3` and reads both payloads from local `HEAD`.
3. The release-loop hook permits a matrix-authorized local transition in headless mode, then ends the same paragraph by saying headless mode leaves Ship blocked without limiting that statement to outward transitions.
4. Shipping orders merged-result verification before R1, but does not require the merged commit identity, exact verification command, result, and timestamp to be written before a transition start.

The plan's body seal remains valid. These are post-approval review findings, so the correction belongs here rather than in the approved plan or Addendum 012.

## Discovered contradictions

### Comparison-domain contradiction

A numeric, string, HTTP-response, or structured-value comparison has no artifact kind. The universal trigger therefore rejects valid non-artifact comparisons even when they use the real calculation and controlled invariance/changed-axis fixtures. Artifact-kind equality is necessary only when the real comparands are artifacts.

### R2 packet identity consequence

Generalizing the shipped Discrimination check changes the exact issue #11 payload to SHA-256 `18946ff5f0d3ef25a0495bdcfdd82f49999c69ca84603a9f5583540ccee1919f`. Updating that literal pin and correcting the preflight ordering below changes the packet to SHA-256 `910fc52254d59e6d181283afd98cbd360a03d33f3551fd7fde2752092e155728`. R2 would reject the corrected packet unless the runtime consumes an explicitly approved, durable override.

Automatic discovery of files under `docs/deviations/` is not an acceptable override: an arbitrary committed file could otherwise replace a body-sealed transition contract. The override must be pinned by exact path and SHA-256 in the authoritative ledger after a current-session USER reviews this addendum. That approval authorizes only the contract substitution; it never authorizes issue comments or closures.

### Packet preflight contradiction

The sealed R2 acceptance requires a fixture read failure to produce zero mutations. The original packet reads and may mutate issue #11 before its first read of issue #12, so a later issue #12 read failure can leave issue #11 changed. All four read-only comment/state preflights must succeed before the first possible comment or close operation.

### Headless-mode contradiction

The local-transition permission and unconditional headless block cannot both govern the same matrix-permitted local transition. The blocking clause applies to outward transitions; missing, failed, cancelled, or unverifiable transitions still fail closed.

### Merged-result evidence gap

A generic instruction to verify the merged result does not prove which commit was tested or that verification finished before the durable transition start. R1 can therefore begin without replayable evidence of its prerequisite.

## Necessity

The comparison wording cannot remain artifact-universal: doing so would make the new mandatory self-review reject valid numeric, string, HTTP-response, and structured-value checks. The synchronized issue payload must change with that shipped contract, and the immutable sealed R2 packet digest then requires an explicit override rather than silent resealing or plan mutation. The packet also must preflight both issues before mutation to satisfy the sealed zero-mutation read-failure acceptance rather than weakening that acceptance after approval.

The headless clause must distinguish local from outward transitions because the approved matrix deliberately permits local headless completion while first-hand consent remains mandatory for outward effects. Leaving both statements in force would make the local terminal state unreachable.

Merged-result verification must persist both its exact command before the merge gate and its result after merge. Conversation memory or a reconstructed command cannot recover the prerequisite after an orchestrator interruption, while allowing R1 to start without that record would permit cleanup on unverified merged bytes. No existing check records this pre-gate command/commit/result chain or safely authorizes the changed R2 digest.

## Decision

### Discrimination wording

`skills/planning/SKILL.md` and the issue #11 payload use the same comparison domain as the real comparands and the same actual command, pipeline, or computation that produces or derives them. Artifact-kind requirements apply only when the real comparands are artifacts. The effect-bearing target may be a signal, field, or subartifact. The existing two-pair, changed-axis, unrelated-metadata, mixed-artifact, and guard pass/fail protections remain.

### Packet preflight

The packet computes both issues' comment-presence and open/closed state first, validates all four values, and only then enters the mutation cases. A read failure for either issue therefore exits before every comment or close, while post-write failures retain the sealed partial-state reporting and idempotent recovery semantics.

### Transition override R2

- Plan: `docs/plans/2026-08-15-001-fix-planning-discrimination-and-verdict-coverage-plan.md`
- Transition: `R2`
- Target: `docs/issue-closures/2026-08-15-issues-11-and-12-command.md`
- Replaces-SHA-256: `8168d671af3c457c36afa79e8b8c0217fbce96af0f07e7e8dc563687b8b1aaa7`
- Replacement-SHA-256: `910fc52254d59e6d181283afd98cbd360a03d33f3551fd7fde2752092e155728`
- Issue-11-payload-SHA-256: `18946ff5f0d3ef25a0495bdcfdd82f49999c69ca84603a9f5583540ccee1919f`

The release-loop runtime does not scan for or auto-accept this block. Before applying it, the current-session USER must approve this exact addendum path and its whole-file SHA-256. The orchestrator writes one durable ledger line containing `transition=R2`, the addendum path and digest, target path, replaced digest, replacement digest, `approver=USER`, session identity, and an observation-time ISO-8601 timestamp. R2 accepts exactly one matching current-session line, re-hashes the committed byte-clean addendum and target, checks the sealed plan contains the replaced digest, and then substitutes only the replacement digest. Prior-session approval lines remain immutable history but do not confer current-session authority. Missing, duplicate-current-session, untracked, dirty, ambiguous, or hash-mismatched state blocks R2.

This override approval is not reusable consent for the outward transition. After the override is validated, R2 still presents the repository, issues, payloads, packet, and all four possible mutations and obtains fresh point-of-risk USER confirmation exactly as the sealed plan requires.

### Review-thread dispositions

- CodeRabbit thread `3789345661`: addressed by the generalized comparison-domain contract and synchronized issue #11 payload.
- CodeRabbit thread `3789345662`: not addressed. R2 already runs only after shipping returns merged-and-cleaned, from the authoritative base checkout, with the T1 pre-state `Exact U3 commit merged`, a verified packet digest, and fresh USER consent. Replacing the packet's local-`HEAD` reads with an unmodeled remote fetch would break the sealed R2 packet contract without adding a reachable workflow guard. The packet remains preparation evidence and authorizes no standalone execution.
- CodeRabbit thread `3789345664`: addressed by limiting the headless block to outward transitions and preserving matrix-permitted local completion.
- CodeRabbit thread `3789345667`: addressed by commit-pinned, durably recorded merged-result verification before any transition start.

## Observable behavior

- Non-artifact comparison steps can satisfy the Discrimination check through their real computation path; artifact comparisons retain same-kind protection.
- The corrected issue #11 comment body and packet pin become the R2 terminal artifact only after exact USER-approved addendum pinning.
- Both issues' read-only comment/state preflights finish before the first possible comment or close operation, so any preflight read failure has zero mutation calls.
- Matrix-permitted local transitions may complete headlessly; outward transitions remain blocked without first-hand USER consent.
- On a release-loop merge path with an eligible pre-removal transition, cleanup blocks until the base checkout is fast-forwarded to the merged commit, the exact Step 1 full-suite command passes there, and command/SHA/result/time evidence is appended before any approved-plan transition start. Standalone shipping retains its existing merged-result verification and cleanup flow without requiring a release-loop ledger.

## Safety and consent boundaries

No automatic deviation discovery is allowed. The addendum override requires a current-session USER approval event for one exact path and whole-file digest. That event authorizes only the R2 contract substitution. Merge authorization and issue-mutation authorization remain separate first-hand gates. Missing merged-verification evidence blocks R1 and its subsequent cleanup; override ambiguity blocks R2 and Retro after cleanup, without inventing rollback or silently advancing.

The issue packet continues to use local `HEAD` intentionally: the R2 runtime gate reaches it only from the authoritative merged base checkout after the sealed plan's merged-state checks. The packet's first line remains `Preparation evidence — first-hand consent still required. This file authorizes no command.`

## Verification changes

- `scripts/validate.sh` check 16 rejects artifact-only universal comparison wording, the headless contradiction, missing pre-gate command persistence or merged-commit evidence, and an invalid R2 override identity/digest chain.
- The check scopes the six override fields to one `Transition override R2` block, requires the active plan path and exact transition ID, hashes raw payload/packet bytes, requires the sealed R2 section to contain the replaced digest, and rejects automatic discovery or ambiguous current-session authority.
- A disposable merged-base-shaped Git fixture executes the packet behind a local `gh` stub. Clean committed payloads must finish with read-only issue views; a committed payload whose bytes miss the pin, a post-commit working-tree/`HEAD` byte mismatch, or a late issue preflight read failure must exit before any issue comment or close call.
- Shipping verification must prove the exact full-suite command was durably recorded before the merge gate, then prove merged SHA, base-HEAD equality, the same command, exit/result, and timestamp appear before the first R1 start record.

| Gate | Success | Forced failure | Rerun / recovery | Compensation and headless |
|---|---|---|---|---|
| Merged-result prerequisite | Recorded pre-gate command replays at the exact merged SHA; success record precedes R1 start | Missing/ambiguous command, SHA mismatch, nonzero verification, late record, or append failure leaves R1 and cleanup untouched | Resume from the authoritative base ledger, replay the recorded command, and append a new success record; never infer it from chat | The merge is not rolled back; preserve the worktree until success. The local verification may run headlessly, but it authorizes no outward action |
| R2 override selection | Exactly one matching current-session USER approval line binds the committed addendum and target raw-byte digests | No approval, duplicate current-session lines, dirty/untracked bytes, wrong path/digest/transition, or a second override block blocks R2 | Retain prior-session lines as history; a resumed session obtains fresh USER approval and appends one new session-scoped line | Do not roll back merge, R1, or completed cleanup. Headless mode cannot create the USER approval |
| R2 issue packet | Hash-verified payloads and read-only state snapshots precede the separately approved mutations | Hash mismatch or read failure exits before comment/close; partial remote state is never reported as terminal success | Re-read issue state and resume idempotently from the first missing comment/close operation under fresh point-of-risk consent | Existing comment/close operations are not reversed; record partial durable state and retry only the missing operations. Headless, relayed, declined, or deferred consent leaves R2 blocked |

- CodeRabbit re-review must report no unresolved actionable thread before the merge gate is presented again.

## Traceability

- Approved specification: `docs/specs/2026-08-15-planning-discrimination-and-verdict-coverage-design.md` (unchanged).
- Approved plan: `docs/plans/2026-08-15-001-fix-planning-discrimination-and-verdict-coverage-plan.md` (unchanged; body seal retained).
- Prior addendum: `docs/deviations/2026-08-15-discrimination-axis-and-out-of-set-verdict-012.md` (unchanged).
- Review: PR #15, CodeRabbit run `9da8b3f8-bc91-4927-a5c0-be8c10f4416a`, threads `3789345661`, `3789345662`, `3789345664`, and `3789345667`.
- Changed contracts: `skills/planning/SKILL.md`, `skills/release-loop/SKILL.md`, `skills/shipping/SKILL.md`, `docs/issue-closures/2026-08-15-issue-11.md`, and `docs/issue-closures/2026-08-15-issues-11-and-12-command.md`.
- Addendum authority: `docs/solutions/workflow-issues/review-introduced-state-machine-deviation.md`.
