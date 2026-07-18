---
title: Gated Outward Publication for Release
status: draft
date: 2026-07-18
schema: spec/v1
---

# Gated Outward Publication for Release Design

_Created 2026-07-18._

## Overview

Extend `release` with an explicit publication ceremony for a completed local
release. The ceremony publishes the default-branch release commit, annotated
tag, and exact CHANGELOG-derived GitHub release body only after read-only
capability/state checks and a publication-specific first-hand USER gate.

Publication is never an automatic suffix of the existing local release
ceremony. Normal publication is intentionally immediate: the checked-out
default-branch HEAD and the annotated tag target must be the same release
commit. Headless operation remains prepare-only, and already-published
`v0.2.0` is inaccessible to normal publication: only an explicit repair
invocation may inspect or propose a correction for it.

## User Scenarios

### S1: Publish a newly completed local release

Immediately after `$release` has created a future local release commit and
annotated tag, while default-branch HEAD still equals that tag target,
the user invokes `$release publish 0.3.0`. The skill proves remote and GitHub
capability, confirms the local release identity, inspects current remote/page
state, and presents a complete publication packet at a second USER gate. Only
approval received first-hand by that executing session permits the branch push,
tag push, and GitHub release creation.

### S2: Prepare a publication handoff without mutation

An orchestrator invokes `$release publish 0.3.0 mode:headless`. When every
read-only capability and state check succeeds, the skill writes a
version-specific ignored publication packet and stops. If capability or state
cannot be inspected, it fails without an executable packet. It never asks a
question, pushes a ref, creates or edits a release page, or treats relayed
approval as authorization.

### S3: Resume a matching partial publication

A prior `0.3.0` publication pushed the default branch but failed before the tag
push, or pushed both refs but failed before page creation. The user invokes the
same publication operation again. The skill detects matching durable state,
proposes only the missing transitions, and requires a fresh publication gate;
it never assumes the failed invocation left no outward state.

### S4: Treat an already-complete publication as idempotent

The remote branch, annotated tag, and GitHub release page already match the
local release and exact CHANGELOG body. A repeated publication invocation
reports a no-op without presenting a mutation gate or changing outward state.

### S5: Repair an existing release explicitly

The user invokes `$release publish 0.2.0 repair` or applies `repair` to a later
version whose matching tag exists but whose release page is missing or has the
wrong body. The skill presents the observed mismatch and a narrowly scoped
repair packet at the separate publication gate. Repair may add a missing
matching tag/page or correct canonical page fields for the same tag, but only
when remote `main` already contains the release commit. It never mutates the
branch, force-updates a tag, deletes a release, retargets a page, or rewrites
published history.

### S6: Refuse unsafe or unverifiable publication

The remote is unreachable, GitHub authentication/capability is unavailable,
the local tag is not the verified annotated release tag, a remote ref conflicts
with the local release, or state changes after the gate. The skill performs no
outward mutation. Conflicting refs require manual recovery; stale gate state
requires a newly derived packet and fresh approval.

## Scope

### In

- **R1 — Explicit action**: add publication as an explicit `publish <semver>`
  action of `release`, with optional `mode:headless` and an optional `repair`
  modifier. A version is always explicit; publication never guesses the target.
- **R2 — Capability/readiness checks**: before offering a publication gate,
  prove the configured target is the expected GitHub remote, remote inspection
  and read-only release API inspection succeed, the current/default branch and
  clean-worktree requirements hold, current default-branch HEAD equals the
  local annotated tag target, and that verified release commit's manifests and
  newest CHANGELOG heading agree with the requested version. Authentication
  evidence proves only active auth and reported scopes; it does not by itself
  prove create/edit capability.
- **R3 — Remote-state classification**: inspect the default branch, annotated
  tag, release-page identity, draft/prerelease flags, and exact page body, then
  classify the invocation as fast-forwardable unpublished, matching partial,
  fully matching, safely repairable, conflicting, or unverifiable. Exact tag
  identity requires the same annotated tag object OID and dereferenced release
  commit; a different tag object at the same commit is a conflict.
- **R4 — Separate consent**: local release approval never authorizes
  publication. Every outward mutation requires a publication-specific USER
  gate in the same executing session; relayed approval is handoff evidence
  only.
- **R5 — Exact notes reuse**: derive the page body byte-for-byte from the target
  CHANGELOG version section after its version/date heading and separator blank,
  ending immediately before the next version heading. Pass that persisted body
  as a notes file; do not summarize or regenerate it.
- **R6 — Ordered durable transitions**: publish the default-branch release
  commit with a non-force fast-forward update, then the annotated tag, then
  create or repair the release page. Page creation must require the remote tag
  to exist (`gh release create --verify-tag` or an equivalent hard assertion),
  so the hosting service cannot implicitly create a tag. Recompare the exact
  approved transition-specific expected pre-state fingerprint immediately
  before each mutation, and verify each completed transition before proceeding.
- **R7 — Idempotent recovery**: a rerun resumes only missing transitions when
  every existing ref/page identity matches. Fully matching state is a no-op.
  Normal publication requires remote `main` to be an ancestor of the exact
  release commit. Repair requires remote `main` already to contain that commit
  and never mutates the branch. Conflicting branch or tag identity is never
  overwritten automatically.
- **R8 — Protected precedent**: normal publication of `v0.2.0` always stops and
  directs the user to the explicit repair action. Repair is still no-op when
  the existing publication matches; it does not recreate or duplicate it.
- **R9 — Prepare-only headless**: headless publication writes an ignored
  `.release/publication-v<version>.md` packet only after complete preflight,
  containing capability evidence, observed state, exact notes bytes/hash,
  intended transitions, recovery expectations, and one fail-fast exact-command
  program, then stops before the publication gate and every outward mutation.
  An unavailable capability or unverifiable state emits failure and produces
  no executable publication packet.
- **R10 — Additive terminal contract**: add a `release publish` producer row to
  `schemas/headless-contract.md` using the canonical placeholder families
  `Publication complete — v<version>`, `Publication skipped — <reason>`, and
  `Publication failed — <reason>`. Keep contract version `v1` and the existing
  `release` row/semantics byte-for-byte unchanged. In the same change, extend
  `scripts/validate.sh` check 6 so `release publish` joins the producer tuple,
  `Publication` joins the consumer keyword regex, `producer_key` maps it to
  `release publish`, both canonical/distinct count assertions and their
  diagnostic/ok message literals change from 12 to 15, and all three new
  placeholders participate in byte-drift and coverage checks. Put the three
  canonical Publication placeholder forms in inline backticks in
  `skills/release/SKILL.md`; keep concrete runtime instantiations out of inline
  backticks under the existing authoring rule.
- **R11 — Stateful planning evidence**: the implementation plan must contain a
  real Mutation/failure-state matrix for every publication transition and map
  every applicable cell to disposable fixture evidence before unit review.
- **R12 — Canonical page identity**: the one acceptable release page has tag
  `v<version>`, target equal to the verified remote annotated tag/release
  commit, title `<repository-name> v<version>`, `draft=false`, prerelease equal
  to whether the SemVer has a prerelease identifier, and body equal to the
  exact persisted CHANGELOG section. Repair may create a missing page or edit
  only title, body, draft, and prerelease to those values; it cannot retarget a
  page or tag.

### Out

- Automatically publishing after the local release gate or treating local
  release approval as publication approval.
- Changing the existing local release arguments, seven-phase behavior,
  recovery rules, gate, draft, or `Release ...` terminal signals.
- Publishing, repairing, or otherwise mutating any real remote during design,
  planning, implementation tests, or review fixtures.
- Force-pushing, deleting or moving remote tags, deleting releases, rewriting
  published history, or automatically resolving conflicting remote identities.
- Supporting non-GitHub release-page providers, CI/scheduled publication, or
  repository-hosting account setup.
- Republishing `v0.2.0` through the normal path; only explicit repair may
  inspect it or propose a narrowly scoped matching-state correction.
- Delayed normal publication after default-branch HEAD has advanced beyond the
  release tag. Such a state requires manual handling, or explicit repair when
  the remote branch already contains the release commit.

## Assumptions and Preconditions

Live evidence was observed on `feat/gated-outward-publication-design`. Results
below are deliberately concise and exclude credential material, token values,
and unbounded output.

| Claim | Command | Observed at | Observed result | Evidence source |
|---|---|---|---|---|
| The P2 outward-publication row is open and its trigger requests a new design cycle. | `rg -n "Gated outward publication automation" ROADMAP.md` | `2026-07-18T20:41:38+09:00` | One open P2 row requires capability checks, separate consent, exact CHANGELOG reuse, idempotency, and partial-failure recovery. | `ROADMAP.md` at `f673b1f` |
| The current `release` ceremony is local-only and already owns a first-hand local release gate plus prepare-only headless mode. | `sed -n '1,45p;317,405p' skills/release/SKILL.md` | `2026-07-18T20:41:38+09:00` | The skill explicitly never pushes or creates a GitHub release; local commit/tag require same-session consent; headless writes `.release/draft.md` and stops. | Working tree at `f673b1f` |
| A GitHub `origin` exists and its default branch is `main`. | `git remote -v && git symbolic-ref --short refs/remotes/origin/HEAD` | `2026-07-18T20:41:38+09:00` | Fetch/push remote is the expected GitHub repository; remote HEAD resolves to `origin/main`. | Local git configuration at `f673b1f` |
| GitHub CLI authentication is active and reports repository scope. | `gh auth status` | `2026-07-18T20:41:38+09:00` | Active keyring-backed GitHub authentication reports repository scope; this proves neither a future mutation nor create/edit authorization, and the token value was neither retained nor copied. | Sanitized command result in this designing session |
| Remote `main` and the annotated `v0.2.0` tag exist at the expected commits. | `GIT_TERMINAL_PROMPT=0 git ls-remote origin refs/heads/main refs/tags/v0.2.0 'refs/tags/v0.2.0^{}'` | `2026-07-18T20:41:38+09:00` | Remote main equals `f673b1f`; annotated tag object exists and dereferences to release commit `c3cbf01`. | Read-only `origin` ref query |
| The `v0.2.0` GitHub release is already fully published. | `gh release view v0.2.0 --repo teslamint/compound-loop --json tagName,name,isDraft,isPrerelease,url,publishedAt` | `2026-07-18T20:41:38+09:00` | Tag is `v0.2.0`; release is neither draft nor prerelease and has a published URL/time. | Sanitized read-only GitHub release metadata |
| The published `v0.2.0` body is exact CHANGELOG-section content when the version heading and its first separator blank are excluded. | `expected=$(mktemp); actual=$(mktemp); awk 'BEGIN{in_section=0; first=1} /^## \\[0\\.2\\.0\\]/{in_section=1; next} /^## \\[/{if(in_section) exit} in_section{if(first && $0==""){first=0; next}; first=0; print}' CHANGELOG.md >"$expected"; gh release view v0.2.0 --repo teslamint/compound-loop --json body --jq .body >"$actual"; diff -u "$expected" "$actual"; rc=$?; rm -f "$expected" "$actual"; exit "$rc"` | `2026-07-18T20:43:27+09:00` | Byte comparison exited 0; expected and published bodies were both 892 bytes. | Temporary sanitized files deleted after read-only comparison |
| The headless contract permits an additive producer row without changing `v1`. | `rg -n 'Contract version|adding a new producer row|release' schemas/headless-contract.md` | `2026-07-18T20:41:38+09:00` | Contract is `v1`; its rule says an additive producer row does not require a bump; the existing release row is distinct. | `schemas/headless-contract.md` at `f673b1f` |
| Stateful planning now requires a six-outcome matrix and retained fixture evidence. | `rg -n "Mutation/failure-state matrix|release-loop/evidence" skills/planning/SKILL.md schemas/plan-schema.md skills/implementing/SKILL.md` | `2026-07-18T20:41:38+09:00` | Planning requires one row per durable transition and implementing requires one sanitized evidence record per applicable cell. | Merged process-guidance contracts at `f673b1f` |

## Architecture

`release` gains a publication action with its own read-only Preflight, Packet,
Gate, Execute, Verify, and Report flow. The existing local seven-phase release
path remains a separate action and returns before publication begins.

Publication consumes a completed local release identity: requested version,
default-branch release commit, annotated tag object/target, manifest values, and
the matching CHANGELOG section. Preflight derives the complete remote/page
state and a canonical notes file before any question is asked. Packet presents
that immutable input, including the remote-branch OID, tag object/target OIDs,
page fields, and notes hash, plus only the transitions still required and the
expected pre-state fingerprint for each transition after prior approved
transitions. Gate authorizes that exact sequence; any unpredicted change
invalidates approval. Execute rechecks the transition-specific fingerprint
immediately before every mutation and runs the transition only while it matches.
Verify compares remote refs and release metadata/body with the approved identity
before Report emits one publication terminal signal.

The publication operation is a stateful ceremony. Planning must use
`skills/planning/references/stateful-ceremony-matrix-example.md` as its model,
then replace illustrative T4/T5 outcomes with the final transition rows and
retained evidence owners for this feature.

## Interface

- `$release publish <semver>` — immediately after local release, inspect and,
  after a separate first-hand gate, perform or resume normal publication for
  that explicit future version. Checked-out default-branch HEAD must equal the
  annotated tag target.
- `$release publish <semver> mode:headless` — persist the exact publication
  packet and stop prepare-only.
- `$release publish <semver> repair` — inspect an already-published/protected
  version and, when safe, propose only a matching-state correction at the
  publication gate.
- `$release publish <semver> repair mode:headless` — persist the repair packet
  without mutation.

Argument order may remain flexible like the existing release arguments, but
duplicates, unknown tokens, a missing version, or `repair` without `publish`
are invocation failures with no phase work.

Normal publication of `0.2.0` is a protected no-op directing the user to
`repair`. For any version, fully matching state is a no-op. A missing component
with matching existing identity is resumable. Normal branch publication is
allowed only when the observed remote default branch is an ancestor of the
release commit and uses a non-force fast-forward update tied to that observed
OID. If local HEAD has advanced past the release tag, normal publication fails
rather than choosing a later branch commit. Repair never mutates the branch and
is available only when the remote default branch already contains the release
commit. A conflicting branch or tag is a hard failure in both modes.

## Publication State Model

The model distinguishes the remote branch relation from tag/page presence.
“Matching tag” means the remote annotated tag object OID and its dereferenced
commit both equal the local verified identity; the same commit under a different
tag object is conflicting, not matching.

| Observed state | Normal publication | Explicit repair |
|---|---|---|
| Local default-branch HEAD has advanced beyond the release tag target | Fail: delayed normal publication is unsupported | Continue classification only if remote `main` contains the release commit; never mutate the branch |
| Remote `main` is an ancestor of the release commit; HEAD/tag target equal the release commit; tag and page absent | Gate non-force branch fast-forward → exact annotated tag push → verified-tag page creation | Fail: repair cannot publish the branch |
| Remote `main` equals the release commit; tag/page missing | Gate only exact annotated tag push → verified-tag page creation | Gate the same tag/page restoration |
| Remote `main` contains the release commit as an ancestor but is later than it | Fail: normal publication cannot select a later branch commit | Gate only missing matching tag/page repair; never mutate the branch |
| Remote `main` does not contain the release commit and cannot fast-forward to the exact release commit, or is unrelated | Fail with manual-recovery evidence | Fail: repair cannot mutate the branch |
| Matching branch state and matching tag exist; page missing | Gate only verified-tag page creation | Gate page creation |
| Matching branch state, matching tag, and exact canonical page exist | Skip without a mutation gate | Skip without a mutation gate |
| Matching tag/page identity exists but title, body, draft, or prerelease differs | Fail and require explicit repair | Gate only edits of those canonical fields; never recreate or retarget the release |
| Page exists while the remote tag is absent | Fail as unordered partial state | If remote `main` contains the release commit, gate tag restoration, verify it, then verify/edit the existing page; otherwise fail |
| Remote tag exists and matches locally, but remote `main` does not contain its release commit | Fail as conflicting publication order | Fail: repair cannot mutate the branch |
| Remote tag dereferences to the release commit but its annotated tag object OID differs | Fail as conflicting tag identity | Fail: repair cannot replace, move, or delete the tag |
| Remote tag points to another commit, or the page names another tag/target | Fail with manual-recovery evidence | Fail: repair cannot retarget published identity |
| State cannot be inspected or capability is unavailable | Fail before packet/gate | Fail before packet/gate |
| Requested version is `0.2.0` | Skip and require explicit repair | Apply the repair rows above without branch mutation or duplicate creation |

Cancellation at the publication gate leaves observed state unchanged. Failure
or cancellation after one outward transition preserves that durable result;
the next invocation must reinspect and resume from observed state rather than
run an assumed suffix or rollback published history.

## Integration

- Keep publication inside `skills/release/SKILL.md` so one owner verifies the
  local release identity and outward publication, while retaining two actions
  and two consent gates.
- Extend `schemas/headless-contract.md` additively with the `release publish`
  producer row; do not alter the current `release` row.
- Reuse the blocking-question protocol for publication consent, but present a
  publication-specific packet and choices: approve exact publication, revise
  or cancel, and—when a repair was requested—approve exact repair.
- Persist publication packets and notes under ignored `.release/` state. Never
  rely on conversation history, relayed approval, or an earlier local release
  gate as executable authorization.

## Testing

The implementation plan must contain a Mutation/failure-state matrix covering
capability inspection, branch publication, tag publication, page
creation/edit, and post-publication verification. Every row must cover success,
forced failure, rerun, rollback or compensation, headless, and cancellation or
abort, with concrete not-applicable reasons where needed.

All mutation tests run only in disposable isolation:

- a disposable repository and local bare remote for branch/tag states;
- a stub `gh`/release endpoint for authentication, page creation/edit,
  page-exists, and verification states;
- a boundary sentinel proving no configured target resolves outside the
  fixture root or loopback stub;
- one retained evidence record per applicable matrix cell under the standard
  `.release-loop/evidence/U<N>/` path.

Required scenarios include: capability missing; remote inspection unavailable;
unpublished success; branch-pushed/tag-missing failure; tag-pushed/page-missing
failure; fully matching rerun; page-exists exact no-op; page-body mismatch
requiring repair; remote-main ancestor fast-forward; advanced local HEAD;
remote main containing the release commit without equaling it; divergent remote
main; page-present/tag-missing unordered state; matching tag with branch missing
the release commit; same tag target with a different annotated tag object;
implicit-tag-creation refusal; canonical title/target/draft/prerelease repair;
conflicting remote tag; explicit `v0.2.0` protection and repair; successful
headless packet creation; headless preflight failure with no executable packet;
gate cancellation; a state change before each individual transition; wrong
injected mechanism; post-state/next-invocation verification; and
`scripts/test-signal-drift.sh` Case I, which makes a one-byte change inside the
unique inline Publication success placeholder while preserving its leading
keyword and proves check 6 reports the correct file, line, producer, state, and
byte mismatch.

No test or review step may contact or mutate the real `origin`, GitHub release
API, credential store, payment/deployment system, or any non-fixture target.

## Risks

- **Wrong-target mutation** — mitigate by explicit version, target inventory,
  remote URL/capability proof, boundary checks in tests, and a packet that names
  every outward target before consent.
- **Approval confusion** — mitigate with a separate publication action/gate;
  local release approval and relayed approval are never publication consent.
- **Partial outward state** — mitigate with ordered transitions, verification
  after each transition, durable post-state reporting, and rerun from observed
  state rather than blind retry or fictional rollback.
- **Duplicate or overwritten publication** — mitigate by exact identity/body
  comparison, fully matching no-op, explicit repair, and a ban on forced ref
  updates, release deletion, or duplicate page creation.
- **Notes drift** — mitigate by persisting and hashing the exact extracted
  CHANGELOG body and passing it through a notes file rather than regenerated
  prose or shell interpolation.
- **Credential leakage** — retain only capability outcome and target identity;
  never persist tokens, credential output, personal data, or unbounded CLI
  responses in packets or fixture evidence.
- **Signal ambiguity** — mitigate with an additive `release publish` producer
  row and Publication signal family while leaving existing Release semantics
  untouched.

## Success Criteria

1. Publication is an explicit release action with a separate same-session USER
   gate; the existing local release gate cannot authorize it.
   - **Measured by**: a reviewer walks S1 and confirms the publication packet
     and blocking question occur only in the explicit publish action, after
     capability/state checks, and that relayed or prior release approval is
     rejected as execution authorization.
2. Headless publication is prepare-only and leaves every outward state
   unchanged.
   - **Measured by**: the publication fixture suite compares local/remote refs
     and stub release records before/after a headless run, finds no changes,
     finds `.release/publication-v<version>.md`, and observes the canonical
     Publication skipped placeholder family as the last-line contract.
3. Publication reuses the target CHANGELOG body exactly.
   - **Measured by**: the fixture suite byte-compares the extracted notes file
     with the body received by the stub release endpoint, including section
     boundaries and trailing newline, and reports zero-byte difference.
4. Matching partial branch/tag/page states resume safely and fully matching
   state is idempotent.
   - **Measured by**: the fixture suite forces failure after branch publication
     and after tag publication, reruns each case, proves existing matching refs
     are unchanged, creates only missing state, and proves a third fully
     matching invocation performs no mutation.
5. Conflicting refs and protected `v0.2.0` cannot enter normal publication.
   - **Measured by**: fixture cases for a mismatched remote branch, mismatched
     remote tag, and normal `publish 0.2.0` all exit before the gate with zero
     remote/page mutations; only an explicit repair invocation can reach a
     repair packet for `v0.2.0`.
6. Repair is narrow and never rewrites published history.
   - **Measured by**: fixtures prove repair is unavailable unless remote `main`
     contains the release commit, never emits a branch mutation, offers only
     missing tag/page restoration or title/body/draft/prerelease correction,
     and exposes no force-push, tag move/delete, page retarget, duplicate page,
     or release-delete command.
7. Capability failure and stale post-gate state fail closed.
   - **Measured by**: missing-auth, unreachable-remote, unavailable-page-state,
     headless preflight-failure, and state-changed-before-each-transition
     fixtures all perform zero further mutations; no executable packet is
     written for incomplete preflight, and stale state requires a newly derived
     packet and fresh gate.
8. Publication terminal signals are additive and local release signals remain
   unchanged.
   - **Measured by**: `bash scripts/test-release-publication.sh` asserts contract
     `v1`, the exact preexisting `release` producer row, and one additive
     `release publish` row; `bash scripts/test-signal-drift.sh` Case I mutates
     one byte inside the inline Publication success placeholder and proves
     check 6 identifies producer `release publish`, state `success`, and the
     mismatch; the full signal-drift suite exits 0; and
     `bash scripts/validate.sh` reports exactly 15 canonical pairwise-distinct
     signals before exiting 0.
9. The approved implementation plan contains the first real stateful-ceremony
   matrix and retained evidence ownership for publication.
   - **Measured by**: a reviewer maps every durable publication transition to
     all six outcome classes, one implementation unit, and one disposable
     evidence owner, with no blank or unexplained not-applicable cell.
10. Existing local release behavior remains intact and no real outward target
    is used by validation.
    - **Measured by**: `bash scripts/validate.sh`,
      `bash scripts/test-signal-drift.sh`, and
      `bash scripts/test-release-publication.sh` exit 0; the last command's
      target inventory and boundary sentinel contain only the disposable
      root/local bare remote/loopback stub, its local-release regression case
      passes, and retained fixture evidence contains no real origin URL,
      credential, or token material.

## Decisions

The following design decisions were resolved first-hand in this designing
session:

- **Normal publication timing** — require default-branch HEAD to equal the
  release tag target; do not choose a later branch commit for delayed
  publication.
- **Repair authority** — repair never mutates the branch and requires remote
  `main` already to contain the release commit.
- **Canonical page fields** — derive title as `<repository-name> v<version>`,
  target the verified tag/release commit, set `draft=false`, derive prerelease
  from SemVer, and reuse the exact CHANGELOG body.

Remaining implementation-owned decisions:

- **Real GitHub smoke test after implementation** — owner: user. It is not
  required for implementation acceptance and must not run without a new
  first-hand authorization naming a disposable or intentionally publishable
  version. The default is no real outward smoke test.
- **Internal helper/file layout** — owner: planning. It may choose focused
  references or test helpers, but cannot change the public arguments, two-gate
  boundary, state classifications, exact-body contract, or terminal signals.
