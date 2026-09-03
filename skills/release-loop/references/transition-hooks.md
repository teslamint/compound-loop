## Approved-plan transition hooks

An approved plan may declare only two release-loop-owned transition families, recognized by exact heading shape and never by free-text inference:

- `## Release-loop Ship-cleanup transition R<N>:` — pass the body-sealed plan to `shipping`; its Step 8 hook runs these local transitions after merged-result verification and before worktree removal.
- `## Release-loop post-Ship completion transition R<N>:` — after `shipping` returns a merged-and-cleaned exit and before Phase 6, the release-loop orchestrator runs these transitions in heading order and requires each section's acceptance evidence before advancing to Retro.

Each transition section's first nonblank body line must be `Matrix rows: T<N>[, T<N> ...]`. Transition IDs are globally unique across both families; a matrix row may be claimed by at most one transition; and every declared row must exist with exactly one evidence owner. Duplicate IDs, duplicate row claims, missing rows, or extra mappings block Ship before any transition runs.

Before either family runs, revalidate the approved plan's `body_seal`, require the section to name an owner and a matching mutation/failure-state matrix row, and persist the transition start in `progress.md`. A missing, failed, cancelled, or unverifiable transition blocks the loop in Ship; it never advances by silence. Any outward action requires an interactive point-of-risk USER gate with exact target and values; only the human or orchestrating session receiving first-hand approval executes it. A declined, deferred, relayed, or headless outward transition leaves Ship blocked; a matrix-permitted local transition may complete headlessly only when its matrix permits it and proves every outward target unreachable.

A post-approval deviation never overrides a transition by discovery alone. When a sealed transition's literal artifact changed, accept one override only after the current-session USER approves the exact committed addendum path and whole-file SHA-256 and the orchestrator persists one timestamped `transition-override-approved` Log line with transition ID, addendum path/digest, target path, replaced/replacement digests, `approver=USER`, and session identity. Before use, require exactly one matching approval line for the current session, re-hash the tracked byte-clean addendum and target, and prove a single exact override block names the same transition and digests and that the sealed plan contains the replaced digest. Retain prior-session approval lines as history but ignore them for current-session authority. Missing, duplicate-current-session, untracked, dirty, ambiguous, or mismatched override state blocks the transition. Override approval changes only the pinned contract; it is never merge or outward-action consent.

On every Ship entry or resume, inspect the base checkout's handoff state before trusting a progress record. Run `python3 "$release_loop_skill_root/scripts/run-artifact-integrity.py" handoff --repo <source-worktree> --base-repo <base-checkout> --progress-path <repo-relative-progress-path>`. Resolve both checkout paths physically. If they are identical, block before marker creation. `.release-loop/.handoff` is the fixed handoff root. Never derive the allowed root from the marker or destination. Reject absolute paths, parent escapes, symlinks, and physical parents outside each fixed root family.

A legacy record (`artifact_root: .release-loop`) adds `--legacy-destination .release-loop` to that same invocation: `python3 "$release_loop_skill_root/scripts/run-artifact-integrity.py" handoff --repo <source-worktree> --base-repo <base-checkout> --progress-path <repo-relative-progress-path> --legacy-destination .release-loop`. A scoped record never passes `--legacy-destination`; the CLI rejects either flag on the wrong record shape. Accepted legacy V1 state is active state. Handoff validates its ledger ownership and exact `.release-loop/v1` tree before copying it. Under `.release-loop`, `archive/`, `.handoff/`, and `runs/` are persistent siblings. The `recovery-authority/` and `recovery-backups/` are persistent siblings too. They are never active transfer bytes. At the base destination, legacy handoff skips every persistent sibling during the collision scan. At the source, legacy handoff rejects every persistent sibling; a source worktree must contain only active state under `.release-loop`.

Each handoff operation records the exact repo-relative source progress path, `artifact_root`, feature, source worktree, base owner, and destination. Create the marker before transfer. Copy the exact active scope to that base destination. A matching incomplete marker resumes the same transfer. A missing or mismatched marker blocks Ship and preserves both scopes.

Transfer only the exact active scope to the base owner. Compare the complete source and destination manifests. Make the base owner discover and resume that exact progress path. Permit worktree removal only after both checks pass. A partial destination remains incomplete. Remove it only when its bytes and owner marker match the source. Otherwise preserve both copies for manual recovery.

A matching owner marker resumes only incomplete transfer steps. The local transfer can run headlessly only after it proves that no outward target is reachable. Cancellation preserves the source worktree. A partial target retains its incomplete marker. The next invocation resumes from that marker before cleanup.

If the authoritative base ledger records `phase: ship` and `merged: true`, resume never re-enters pre-merge `shipping`. Use transition logs and the exact handoff marker to resume an interrupted transfer. Finish pending cleanup only after acceptance. Then run each incomplete post-Ship transition before Retro.

## Release-loop pre-merge verification V1: Produce the approved generation

After Review returns `clean`, the first-hand release-loop orchestrator runs the approved plan's V1 section before invoking `shipping`. It requires a current-session pilot approval packet and receipt, a complete pilot, a separately approved full packet and receipt, and one verified complete generation. Persist V1 start and acceptance with the exact generation manifest SHA-256. The `pre_merge_verification` block is the sole acceptance authority. The `v1` block records ownership paths and digests. Handoff and archive preserve the exact V1 bytes. Missing, failed, interrupted, stale, or unverifiable V1 state blocks Ship before the merge gate. Resume retains completed calls but never reuses a receipt from another session.

## Release-loop pre-archive verification V2: Verify the archived generation

After Retro commits and archive evidence is staged, keep the live progress record nonterminal. Run the approved plan's V2 section against the exact persisted archive destination, tracked baseline, and matching handoff. Persist V2 acceptance and mark only that handoff consumed before setting `phase: done`. Move `progress.md` last. A missing marker, digest mismatch, incomplete generation, failed validation, or foreign destination leaves the loop live and resumable.

## Pre-archive contract registry

Parse declarations only from Markdown headings with this exact shape:

```text
## Release-loop pre-archive verification V<N>: <version-specific title>
```

`N` is a positive canonical decimal string without leading zeroes. Do not
convert it to a machine integer. The registry maps each supported version to one exact heading title and one body validator.
The initial registry contains only version `2`. Its title is
`Verify the archived generation`. Its validator is the existing V2 validator.
A later version requires an approved registry entry, validator, and fixtures.

Treat a close heading match as a declaration candidate. Body text is never a
candidate. Classify duplicate or malformed candidates before version dispatch.
Apply this closed order: `duplicate`, `absent-legacy-shape`, `malformed`,
`unsupported-version`, `unverifiable`, then `supported`. Only an eligible `absent-legacy-shape` packet may enter recovery.
The provenance audit must also prove that the sealed plan predates the V2
contract. A lexical absence result alone grants no authority.

## Legacy archived-incomplete recovery transition

Recovery consumes one exact scoped terminal archive only after the release-loop
orchestrator receives first-hand current-session USER approval. The orchestrator
writes the answer receipt to the pinned gate ledger, then invokes
`request-legacy-archive --publish-approval` without answer or replacement-path
arguments. The immutable gate snapshot pins the request digest, session, gate
ID, timestamps, nonce, source ledger path, and pre-clear ledger digest.
`approval.json` pins the snapshot path and SHA-256. Only an accepted audit may
start restore.

Ordinary V2, V3, malformed, duplicate, stale, missing, or override evidence never activates recovery.
G1 and G2 remain nonterminal and cannot enter the archive move. Only G3 may use
the recovery terminal exception. Every other run follows its registered
ordinary pre-archive contract. A missing, changed, ambiguous, or occupied root
blocks and preserves the archive and recovery roots.
