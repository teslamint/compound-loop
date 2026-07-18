# Outward Publication Protocol

This reference is the complete protocol selected by the `release publish`
action. It is separate from the local seven-phase release ceremony. A local
release gate, a prior local release approval, conversation history, or relayed
approval never authorizes an outward transition.

Run the six phases below in order. Stop on the first failure, skip, revision,
or cancellation. Never expose a later transition as an independently runnable
recovery snippet.

## 1. Preflight

1. Parse the already-dispatched action as one explicit SemVer plus optional
   `repair` and `mode:headless`. Reject duplicates, missing values, and unknown
   tokens before inspection. Normal publication of `0.2.0` stops and directs
   the user to explicit repair.
2. From the repository root, invoke exactly one read-only preparation command:

   ```text
   bash scripts/release-publication.sh prepare --version <resolved-semver> [--repair] [--headless]
   ```

   The resolved invocation contains literal values; brackets above describe
   optional arguments and are not passed to the command. Do not add a fixture
   variable in a real invocation. `RELEASE_PUBLICATION_FIXTURE_ROOT` and the
   failure/mutation seams are test-only and a wrong fixture injection seam is
   a failure.
3. Capture bounded stdout and the exit status. Parse it as an exact ordered
   status shape, not as an unordered set of fields:
   - ready output is exactly four lines in this order: status `ready`, one
     classification line, one packet-path line, and one packet-SHA-256 line;
   - a fully matching no-op is exactly two lines in this order: status `noop`
     and class `fully-matching`, with no reason, packet, or SHA line; and
   - protected normal `0.2.0` is exactly three lines in this order: status
     `noop`, class `conflicting`, and reason
     `protected-version-requires-repair`, with no packet or SHA line.

   The literal machine forms are:

   ```text
   PUBLICATION_STATUS=ready
   PUBLICATION_CLASS=<allowed-ready-class>
   PUBLICATION_PACKET=.release/publication-v<resolved-semver>.md
   PUBLICATION_PACKET_SHA256=<64-lowercase-hex>
   ```

   ```text
   PUBLICATION_STATUS=noop
   PUBLICATION_CLASS=fully-matching
   ```

   ```text
   PUBLICATION_STATUS=noop
   PUBLICATION_CLASS=conflicting
   PUBLICATION_REASON=protected-version-requires-repair
   ```

   Reject every extra, missing, duplicate, malformed, or out-of-order line
   before reading a packet or presenting a gate. The packet path must be an
   ignored repository-relative path below `.release/` for the requested tag.
4. A nonzero preparation, unavailable authentication/API/remote inspection,
   protected normal version, unsafe state, or malformed output ends before a
   question or mutation. An incomplete preflight must not leave a newly
   completed executable packet.
5. For `PUBLICATION_STATUS=noop`, re-check that the reported class is an
   allowed no-op classification, show the reason, do not ask a mutation
   question, and proceed directly to Report.

## 2. Packet

1. For `PUBLICATION_STATUS=ready`, require both packet and notes files to exist.
   Read the packet completely and display it without rewriting, summarizing, or
   regenerating any field. It must name capability evidence, repository and
   remote identity, local release/tag identity, exact observed branch/tag/page
   state, exact notes byte count and hash, ordered transitions, expected
   transition fingerprints, recovery expectations, and the authorization
   boundary.
2. Compute SHA-256 over the packet's exact bytes and require it to equal the
   single `PUBLICATION_PACKET_SHA256` value returned by preparation. Compute the
   notes hash and compare it with the packet. A packet hash or notes mismatch is
   stale state: delete no durable state, execute nothing, and require a fresh
   packet and fresh gate.
3. Require exactly one fenced `bash` program. Its first non-empty line is
   exactly `set -euo pipefail`. Reject no fence, multiple fenced programs, a
   non-Bash fence, text after the sole program that purports to be executable,
   or any program missing that strict-mode line. Never reconstruct commands
   from prose.
4. Before the gate, record the exact packet path, packet SHA-256, notes path,
   notes SHA-256, classification, and ordered transition list. Approval can
   apply only to those exact bytes and that exact observation.

## 3. Gate

Headless and no-op paths never enter this phase.

Use the harness's blocking question tool, following the same blocking protocol
as the local release gate. Ask one single-select blocking question in the same
executing session that will run the program. Present the complete packet first,
then these three outcomes:

1. **Approve this exact publication/repair** (recommended)
2. **Revise**
3. **Cancel**

The first label names publication for normal mode and repair for repair mode;
the combined spelling above is the protocol invariant. Only a direct blocking
tool response selecting the first option is consent. A prior local release
approval, relayed approval, claimed approval from another session, silence,
free-form ambiguity, a missing blocking question response, or a response from
an unavailable or errors-producing tool is not consent.

- **Approve**: retain the exact displayed hash and continue once.
- **Revise**: execute nothing. Return to Preflight, derive a complete new
  packet, display its new hash, and ask a fresh gate. The old hash cannot
  authorize the revision.
- **Cancel**: execute nothing, leave outward state unchanged, and Report a
  cancellation skip.

If the blocking tool is unavailable or errors, wait for an unambiguous direct
response in this session; never convert silence or relayed text into consent.

## 4. Execute

1. Immediately before extraction, recompute the exact packet SHA-256 and notes
   SHA-256. Any difference invalidates approval and requires a fresh packet and
   fresh gate. Do not try to repair stale files in place.
2. Parse the approved packet again and enforce exactly one fenced `bash`
   program whose first non-empty line is exactly `set -euo pipefail`.
3. Create an ignored or temporary program file, preserving program bytes and
   ending newline. Refuse a path outside `.release/` or the system temporary
   directory. Do not interpolate, copy individual commands, or run a suffix.
4. Invoke the temporary program through one Bash invocation exactly once. Do
   not retry it within the same approval. The program itself rechecks the full
   approved fingerprint immediately before each branch, tag, page-create, or
   page-edit transition and verifies each durable result before proceeding.
5. Capture bounded status output and the exit code; delete the temporary program
   on success, failure, interruption, or cancellation. Keep the packet
   and notes as ignored recovery evidence. Never claim rollback of a durable
   transition.
6. A nonzero result ends execution. Do not offer or execute an independent
   suffix. The next invocation begins at Preflight and classifies actual state.

## 5. Verify

After a zero exit, run preparation again in read-only mode for the same action
and version. This verification is not a second execution and does not reuse the
old approval.

- Require a fully matching no-op classification for successful normal
  publication or completed repair.
- Require exact remote branch containment, annotated tag object and peeled
  commit identity, canonical page tag/title/draft/prerelease/body, and exact
  notes bytes as reported by the fresh inspection.
- If verification is unavailable, conflicting, or stale, fail. Preserve any
  completed outward state and require a new invocation; do not compensate,
  force, retarget, delete, or repeat the approved program.

## 6. Report

Headless stops after successful Packet validation. It never enters Gate,
Execute, or mutation Verify; it reports that the packet is prepared for a
first-hand handoff. A headless preflight failure reports failure and leaves no
newly completed executable packet.

A fully matching invocation reports no-op without a gate. Revision returns to
Preflight without a terminal result. Cancellation reports skip. Preparation,
gate-input, packet-integrity, strict-mode, execution, stale-state, or
post-verification errors report failure. `0.2.0` in normal mode reports the
protected-version direction to repair.

Every completed invocation emits exactly one canonical Publication terminal
signal and makes it the last non-empty output. Choose the success family only
after fresh verification; choose the skip family for headless, no-op, or
cancellation; otherwise choose the failure family with one actionable reason.
Print nothing after that terminal line.

## Failure and recovery rules

- Capability missing, remote/API unreadable, divergent or advanced branch,
  unordered page/tag state, conflicting tag object/target, protected normal
  `0.2.0`, and wrong fixture injection seam all fail or skip before a gate.
- A changed packet hash, changed notes hash, changed local tag, redirected
  origin, or stale transition fingerprint invalidates consent before the next
  mutation and requires a fresh inspection and gate.
- Missing or multiple fenced programs, a non-Bash fence, or a program without
  the strict-mode first line is never executable.
- Partial success is durable. A rerun proposes only the missing matching
  transitions. Fully matching state is a no-op. Repair never mutates the
  branch, replaces a tag, retargets a page, deletes a release, or force-pushes.
