---
schema: plan/v1
title: Gated Outward Publication for Release
type: feat
status: draft
date: 2026-07-18
execution: code
origin: docs/specs/2026-07-18-gated-outward-publication-design.md
---

# Gated Outward Publication for Release Plan

## Goal

Add a separately gated publication action to `release` that prepares and, only
after first-hand consent, publishes the exact local release commit, annotated
tag, and CHANGELOG-derived GitHub release page. Make every partial state
classifiable and resumable or fail-closed, protect the new terminal signals
against drift, and prove the ceremony only against disposable remotes and a
stub GitHub boundary.

## Architecture notes

- **Deliverable classification**: this is a code plan. The user-facing workflow
  is Markdown, but implementation adds an executable shell command generator,
  shell fixture harnesses, validator logic, git ref mutations, and stubbed
  GitHub release mutations.
- **One release owner, two files by responsibility**: keep argument dispatch,
  the publication-specific USER gate, and terminal reporting in
  `skills/release/SKILL.md`. Put the detailed Preflight -> Packet -> Gate ->
  Execute -> Verify -> Report protocol in
  `skills/release/references/publication.md`. This preserves `release` as the
  sole owner while preventing its current local seven-phase ceremony from being
  interleaved with the new outward state machine.
- **Deterministic command generator**: add
  `scripts/release-publication.sh`. Its public interface is read-only
  `prepare`; it classifies current state, persists the exact notes and approval
  packet under ignored `.release/`, and renders one fail-fast fenced Bash
  program containing only the required transitions. The skill displays and
  hashes that packet, obtains first-hand approval, rechecks the hash, extracts
  exactly one `bash` fence, and invokes that approved program once. The helper
  never asks a question and never auto-executes the rendered program.
- **Preparation interface**:
  `bash scripts/release-publication.sh prepare --version <semver> [--repair]
  [--headless]`. Ready output is exactly four machine-readable lines:
  `PUBLICATION_STATUS=ready`, `PUBLICATION_CLASS=<classification>`,
  `PUBLICATION_PACKET=.release/publication-v<version>.md`, and
  `PUBLICATION_PACKET_SHA256=<sha256>`. A fully matching state returns exit 0
  with `PUBLICATION_STATUS=noop` and no packet line. Failure returns nonzero,
  a concise sanitized diagnostic, and no newly completed packet.
- **Packet contract**: `.release/publication-v<version>.md` names the repository
  slug, both configured remote URLs after credential stripping, default ref,
  observed remote branch OID, local release commit, annotated-tag object and
  peeled OIDs, observed page fields, notes path/byte count/SHA-256, state
  classification, ordered transitions, each transition's expected pre-state,
  recovery result, and exactly one fenced Bash program beginning
  `set -euo pipefail`. Notes live at
  `.release/publication-v<version>-notes.md`; writes use temporary siblings and
  atomic rename, and the rendered program rechecks the notes hash before every
  page create or edit.
- **Immediate normal publication**: normal preparation requires the checked-out
  branch to be the symbolic default branch, clean `HEAD` to equal the local
  annotated tag's peeled commit, and the observed remote default branch to be
  an ancestor of that commit. The branch transition uses the explicit non-force
  refspec `<release-commit>:refs/heads/<default-branch>` after comparing the
  complete approved pre-state. Git documents that branch updates are accepted
  only when fast-forward and that explicit refspecs avoid configuration-selected
  destinations: [git-push documentation](https://git-scm.com/docs/git-push).
- **Exact annotated-tag identity**: matching requires both the remote tag object
  OID and its peeled commit OID to equal the local values. Creation pushes
  `refs/tags/v<version>:refs/tags/v<version>` without force. A same-commit,
  different annotated-tag object remains a conflict because replacing a tag is
  outside the approved repair authority.
- **GitHub page identity**: canonical identity is proved by release `tagName`
  plus the separately verified remote annotated-tag object and peeled commit.
  Do not treat `targetCommitish` as a mutable canonical field: GitHub's REST
  contract says it is unused when the tag already exists. Creation therefore
  pushes/verifies the tag first and uses `gh release create ... --verify-tag`;
  repair never passes `--tag` or `--target`. Sources:
  [GitHub release REST API](https://docs.github.com/en/rest/releases/releases),
  [`gh release create`](https://cli.github.com/manual/gh_release_create), and
  [`gh release view`](https://cli.github.com/manual/gh_release_view).
- **Canonical create/edit commands**: creation passes the explicit tag, repo
  slug, `--verify-tag`, title `<repository-name> v<version>`, and
  `--notes-file`; it includes `--prerelease` only for SemVer prereleases and
  omits `--draft`, whose default is published. Repair uses
  `gh release edit` with `--verify-tag`, `--title`, `--notes-file`,
  `--draft=false`, and `--prerelease=<true|false>`. It never changes tag,
  target, latest status, assets, discussions, or release identity. The local
  CLI is `gh 2.96.0`, and its help exposes these fields; the official edit
  contract is [`gh release edit`](https://cli.github.com/manual/gh_release_edit).
- **Capability boundary**: preparation proves `gh` is present, active auth for
  `github.com` is reported, and a read-only repository API query succeeds. It
  never claims those checks prove future write authorization. A rejected branch
  push, tag push, page create, or page edit is a durable failure-state outcome,
  followed by verification and a fresh-state rerun rather than guessed
  rollback.
- **Fixture-only injection seam**: production accepts no alternate remote or
  endpoint argument. Tests may set `RELEASE_PUBLICATION_FIXTURE_ROOT` to an
  absolute disposable root; only then may the script accept a `file://` bare
  remote, a `gh` executable whose resolved path is inside that root, and one of
  the enumerated `RELEASE_PUBLICATION_FAIL_AT` or
  `RELEASE_PUBLICATION_MUTATE_AT` boundaries. The script inventories every
  remote, executable, HOME/TMPDIR path, and stub state file and rejects the
  fixture mode unless all resolve inside the root. This makes wrong injection
  fail before packet creation and keeps no real target reachable.
- **Per-transition freshness**: the rendered program repeats the complete
  approved expected pre-state comparison immediately before each mutation.
  Expected state advances only through a preceding transition whose post-state
  was verified. Any external change, notes change, packet hash change, or wrong
  page identity stops the program before the next mutation and requires a newly
  prepared packet and fresh gate.
- **Terminal-signal protection**: add the `release publish` row without changing
  contract `v1` or the existing `release` row. Extend validator check 6's
  producer tuple, `Publication` keyword regex, `producer_key`, both count
  assertions, and diagnostic/ok literals from 12 to 15. Keep the three
  canonical Publication placeholders as the only inline-backticked instances
  in the release skill, and add signal-drift Case I using a one-byte mutation
  after the intact `Publication complete` keyword.
- **Known Pattern — release consent**: reuse the current release skill's one
  complete packet, one blocking USER question, same-session authorization, and
  prepare-only headless posture. Local release approval and relayed approval
  remain non-authorizing evidence.
- **Known Pattern — empirical fixture grounding**:
  `docs/solutions/workflow-issues/spec-review-empirical-grounding-gap.md`
  requires each proposed fixture to prove it failed at the intended boundary,
  not because setup or an existing validator failed first. Every forced-failure
  case records a unique fixture marker and mechanism check.
- **Known Pattern — approved state-machine truth**:
  `docs/solutions/workflow-issues/review-introduced-state-machine-deviation.md`
  governs any changed matrix row or outcome after plan approval. Preserve this
  plan and the approved spec; commit a deviation addendum before accepting new
  observable recovery, gate, side effect, or terminal behavior.
- **Risks and dependencies**:
  - Wrong-target mutation is mitigated by a complete target inventory, strict
    production/fixture boundary, explicit refspecs, verified tag existence,
    per-transition fingerprints, and zero real-target tests.
  - Credential leakage is mitigated by retaining only auth success/scope names,
    stripping URL userinfo, suppressing raw `gh auth` output, and scanning all
    retained evidence for token/account material.
  - Partial outward state is accepted as durable. The next invocation
    reinspects and resumes only matching state; no automation force-pushes,
    deletes tags/pages, or invents rollback.
  - Shell interpolation risk is mitigated by strict SemVer parsing, repo/ref/OID
    allowlists, shell-quoted rendered values, notes-file use, one fenced
    program, and fixture cases with metacharacters in paths and stub output.
  - GitHub CLI behavior is externally versioned. The implementation checks the
    required flags at runtime and fails before a packet when unavailable; it
    does not install or upgrade `gh`.
- **Retro carryover**: this plan has five substantive units, so it qualifies as
  the ROADMAP's second larger-feature pilot. `implementing` should exercise its
  normal fresh-context per-unit dispatch and review tiers, but shared writes to
  `scripts/test-release-publication.sh`, `scripts/release-publication.sh`, and
  `skills/release/SKILL.md` make the units serial unless isolated worktrees are
  deliberately used. The pilot is measured by the implementation ledger and
  review evidence, not by adding artificial parallelism.

## Global constraints

- Do not push to `origin`, create/edit/delete a real GitHub release, or run a
  forced-failure injection outside a disposable fixture.
- Do not publish or republish `v0.2.0`; normal mode must direct it to explicit
  repair, and fixture tests use synthetic versions and repositories.
- Do not change the existing local release arguments, seven phases, gate,
  recovery behavior, `.release/draft.md`, or `Release ...` terminal strings.
- Do not use force push, tag update/delete, release delete, page retargeting,
  automatic conflict repair, or rollback claims for outward transitions.
- Do not accept relayed approval, a prior local release gate, silence, or a
  packet from another session as publication authorization.
- Do not let headless mode ask a question or execute a rendered program. A
  failed headless preflight produces no newly completed executable packet.
- Do not add dependencies. Use POSIX-facing shell, repository-available
  `python3` for bounded parsing/hashing, git, and GitHub CLI.
- Keep `.release/` and `.release-loop/` ignored. Commit no packets, notes,
  credentials, fixture repositories, stub state, or retained lifecycle evidence.
- Every applicable Mutation/failure-state matrix cell must have one concise,
  sanitized record under its owning `.release-loop/evidence/U<N>/` directory
  before that unit's review. No record may name a real origin URL or credential.
- A review- or implementation-introduced observable behavior change requires a
  separate committed deviation addendum; never rewrite this approved plan or
  its origin spec after approval.

## Assumption Recheck

All nine live assumptions retained by the approved spec were rerun on
`feat/gated-outward-publication-design`. Credential output below is sanitized;
no token or unbounded response is retained.

| ID | Approved claim | Fresh command evidence | Outcome |
|---|---|---|---|
| A1 | The P2 outward-publication row remains open. | `rg -n "Gated outward publication automation" ROADMAP.md` at `2026-07-18T22:07:09+09:00` returned the open P2 row at line 38 with the same capability, consent, exact-notes, idempotency, and recovery scope. | match |
| A2 | The current `release` ceremony is local-only with a first-hand gate and prepare-only headless mode. | `sed -n '1,45p;317,405p' skills/release/SKILL.md` at `2026-07-18T22:07:09+09:00` still states it never pushes or creates a GitHub release, requires same-session consent, and writes `.release/draft.md` before the headless stop. | match |
| A3 | `origin` is the expected GitHub repository and its default branch is `main`. | `git remote -v && git symbolic-ref --short refs/remotes/origin/HEAD` at `2026-07-18T22:07:09+09:00` returned the SSH GitHub fetch/push URL and `origin/main`. | match |
| A4 | GitHub CLI auth is active and reports repository scope, without proving a future mutation. | `gh auth status` at `2026-07-18T22:07:28+09:00` reported an active keyring account, SSH git protocol, and `repo` scope. Token/account detail is omitted here and no write was attempted. | match |
| A5 | Remote `main` and annotated `v0.2.0` remain at the approved identities. | `GIT_TERMINAL_PROMPT=0 git ls-remote origin refs/heads/main refs/tags/v0.2.0 'refs/tags/v0.2.0^{}'` at `2026-07-18T22:07:28+09:00` returned main `f673b1f05938776e65d3219bcbf13b5061fff2c5`, tag object `85f851e06b8aa1077e7c58b21180e711764e776a`, and peeled commit `c3cbf01ba257d1cb70f00e9f999f65d4484babde`. | match |
| A6 | The `v0.2.0` GitHub release remains published, non-draft, and non-prerelease. | `gh release view v0.2.0 --repo teslamint/compound-loop --json tagName,name,isDraft,isPrerelease,url,publishedAt` at `2026-07-18T22:07:28+09:00` returned tag `v0.2.0`, title `compound-loop v0.2.0`, `isDraft=false`, `isPrerelease=false`, and the existing published release URL/time. | match |
| A7 | The published `v0.2.0` body exactly equals the CHANGELOG section body. | `expected=$(mktemp); actual=$(mktemp); awk 'BEGIN{in_section=0; first=1} /^## \\[0\\.2\\.0\\]/{in_section=1; next} /^## \\[/{if(in_section) exit} in_section{if(first && $0==""){first=0; next}; first=0; print}' CHANGELOG.md >"$expected"; gh release view v0.2.0 --repo teslamint/compound-loop --json body --jq .body >"$actual"; diff -u "$expected" "$actual"; rc=$?; rm -f "$expected" "$actual"; exit "$rc"` at `2026-07-18T22:07:28+09:00` exited 0 with both files at 892 bytes. | match |
| A8 | The headless contract permits an additive producer row without changing `v1`. | `rg -n 'Contract version|adding a new producer row|release' schemas/headless-contract.md` at `2026-07-18T22:07:09+09:00` returned contract `v1`, the additive-row rule, and the distinct existing `release` row. | match |
| A9 | Stateful planning and implementation require the six-outcome matrix and retained fixture evidence. | `rg -n "Mutation/failure-state matrix|release-loop/evidence" skills/planning/SKILL.md schemas/plan-schema.md skills/implementing/SKILL.md` at `2026-07-18T22:07:09+09:00` returned the plan matrix contract and the one-record-per-applicable-cell implementation gate. | match |

No contradiction or unavailable retained assumption exists; no deviation
addendum is required before plan approval.

## File structure

### Publication protocol and command generation

- Create: `scripts/release-publication.sh` — deterministic read-only
  preparation, state classification, exact notes/packet persistence, and
  generation of the approved fail-fast transition program.
- Create: `skills/release/references/publication.md` — publication action,
  packet display, first-hand gate, one-shot execution, verification, recovery,
  and headless rules consumed by the release skill.
- Modify: `skills/release/SKILL.md` — route `publish <semver>`, `repair`, and
  `mode:headless`; quote the canonical Publication signals; preserve the local
  release path byte-for-byte outside the dispatch/report integration points.

### Disposable fixtures and contract validation

- Create: `scripts/test-release-publication.sh` — grouped disposable repository,
  local bare remote, stub `gh`, forced-failure, state-mutation, scenario, and
  boundary-sentinel fixtures for preparation and rendered programs.
- Modify: `schemas/headless-contract.md` — one additive `release publish`
  producer row under contract `v1`.
- Modify: `scripts/validate.sh` — check 6 producer parsing, Publication keyword
  mapping, and 15-signal count/message invariant.
- Modify: `scripts/test-signal-drift.sh` — Case I for one-byte Publication
  success-placeholder drift.

### Runtime-only evidence

- Ignored: `.release/publication-v<version>.md` and
  `.release/publication-v<version>-notes.md` — exact approval packet and notes.
- Ignored: `.release-loop/evidence/U2/`, `.release-loop/evidence/U3/`, and
  `.release-loop/reviews/` — sanitized matrix-cell and review evidence.

## Scenario coverage map

| S-ID | Scenario | Ordered unit chain | Walking evidence |
|---|---|---|---|
| S1 | Publish a newly completed local release | U1 -> U2 -> U3 -> U4 -> U5 | U5 integration case `normal publication remains prepare-only until simulated first-hand fixture approval, then performs branch -> tag -> page` executes the rendered program against the bare remote/stub and verifies the public gate text. Covers S1. |
| S2 | Prepare a publication handoff without mutation | U1 -> U2 -> U4 -> U5 | U5 integration case `headless success writes exact packet and notes but never executes` and error case `headless unavailable capability leaves no newly completed packet` compare all outward fixture state before/after. Covers S2. |
| S3 | Resume a matching partial publication | U1 -> U2 -> U3 -> U5 | U3 integration cases `branch published before injected tag failure` and `tag published before injected page failure` rerun from fresh inspection and perform only missing transitions. Covers S3. |
| S4 | Treat an already-complete publication as idempotent | U1 -> U2 -> U3 -> U5 | U5 integration case `third fully matching invocation is no-op` compares branch/tag/page bytes and stub mutation counters before/after. Covers S4. |
| S5 | Repair an existing release explicitly | U1 -> U2 -> U3 -> U5 | U5 integration cases `repair restores missing tag/page only when remote main contains release commit` and `repair corrects only canonical editable page fields` prove no branch mutation, retarget, duplicate, or delete. Covers S5. |
| S6 | Refuse unsafe or unverifiable publication | U1 -> U2 -> U3 -> U5 | U5 integration group `fail-closed inventory` covers missing auth/API, unreachable remote, advanced HEAD, divergent branch, unordered page/tag, conflicting tag object/target, stale fingerprint before every transition, wrong injection seam, and protected normal `0.2.0`. Covers S6. |

## Requirements-to-units trace

| Spec requirement | Owning units |
|---|---|
| R1 explicit action | U5 |
| R2 capability/readiness checks | U2, U5 |
| R3 remote-state classification | U2, U3 |
| R4 separate consent | U5 |
| R5 exact notes reuse | U2, U3, U5 |
| R6 ordered durable transitions and per-transition fingerprints | U3 |
| R7 idempotent recovery | U2, U3 |
| R8 protected `v0.2.0` precedent | U2, U5 |
| R9 prepare-only headless | U2, U5 |
| R10 additive drift-protected terminal contract | U4 |
| R11 matrix and disposable evidence | U1, U2, U3, U5 |
| R12 canonical page identity and narrow repair | U2, U3 |

## Implementation Units

## U1: Disposable publication fixture foundation
Execution note: test-first
Files:
  Create: scripts/test-release-publication.sh
  Modify: none
  Test: scripts/test-release-publication.sh
Interfaces:
  Consumes: repository root; `git`; `python3`; a missing `scripts/release-publication.sh`; `mktemp -d`
  Produces: executable `bash scripts/test-release-publication.sh <prepare|mutations|integration|all>` harness; `setup_fixture` creates a disposable git repository, local `file://` bare remote, stub `gh` executable/state file, isolated HOME/TMPDIR, complete target inventory, and cleanup trap; each case reports its name, exact mechanism marker, pass/fail, and aggregate exit
Test scenarios:
  happy: fixture builder creates a release commit and annotated tag, leaves bare-remote main at its parent, configures a stub repository with no release page, and proves every configured path/remote/executable is inside the disposable root
  edge: repository paths containing spaces and shell metacharacters remain quoted, the notes fixture preserves trailing newline bytes, and cleanup removes the entire root on both pass and assertion failure
  error: `prepare` group invokes the not-yet-created generator and exits nonzero with a harness-owned `missing publication engine` assertion rather than contacting `origin` or the real `gh`
  integration: n/a — fixture infrastructure is a leaf prerequisite; no S-ID completes until the generator exists
Steps:
  1. Write `scripts/test-release-publication.sh` with strict shell mode, grouped case selection, disposable-root creation, aggregate failure counting, bounded output assertions, and traps that remove every root.
  2. Add a local git fixture whose default branch, release commit, annotated-tag object, and bare-remote refs have fixed discoverable relationships; never copy the real `.git` directory or remote configuration.
  3. Add a `gh` stub inside the fixture root that supports only the read/create/edit calls named by the approved spec, persists JSON state under that root, logs mutation counts, and rejects any unrecognized command or target.
  4. Add target-inventory and boundary-sentinel assertions covering remote URLs, resolved `gh`, HOME, TMPDIR, stub state, packet paths, and notes paths; include a scan proving the real `origin` URL and credential markers are absent.
  5. Run `bash scripts/test-release-publication.sh prepare`; confirm it is red only because `scripts/release-publication.sh` does not exist, and confirm no fixture command resolved outside the disposable root.
  6. Commit: "test(release): Add publication fixture foundation"
Acceptance: `bash scripts/test-release-publication.sh prepare` exits nonzero with the named missing-engine assertion, no setup/unrelated-validator failure, no surviving temporary root, and no real remote or GitHub invocation. `bash scripts/validate.sh` remains green because the red harness is standalone.

## U2: Read-only publication preparation and state classification
Execution note: test-first
Files:
  Create: scripts/release-publication.sh
  Modify: scripts/test-release-publication.sh
  Test: scripts/test-release-publication.sh
Interfaces:
  Consumes: `bash scripts/release-publication.sh prepare --version <semver> [--repair] [--headless]`; clean git worktree; symbolic `origin/HEAD`; local annotated `v<version>` tag; two synchronized plugin manifests; matching newest CHANGELOG section; `git remote get-url`; `git ls-remote`; `gh auth status`; read-only `gh api`/`gh release view`; optional fixture-only `RELEASE_PUBLICATION_FIXTURE_ROOT`
  Produces: the exact ready/noop/failure stdout and exit contract in Architecture notes; `.release/publication-v<version>-notes.md`; `.release/publication-v<version>.md`; classifications `fast-forwardable`, `branch-ready-tag-missing`, `refs-ready-page-missing`, `fully-matching`, `repairable-page`, `repairable-unordered-page`, `conflicting`, and `unverifiable`; no outward mutation
Test scenarios:
  happy: fast-forwardable normal state prepares exact notes and a packet whose branch -> tag -> page program names the observed OIDs and canonical page fields; headless produces the same packet shape and no outward mutation. Covers AE2, AE3
  edge: remote main equal to or later than the release commit, page present/tag missing, stable versus prerelease SemVer, fully matching no-op, matching commit under a different annotated-tag object, and normal `0.2.0` each receive the approved classification or fail/repair direction
  error: invalid arguments, dirty tree, non-default branch, advanced HEAD, manifest/CHANGELOG mismatch, non-GitHub production remote, missing `gh`, inactive auth, unreadable repo/page state, divergent branch, conflicting tag/page identity, and fixture paths escaping the root fail before a newly completed packet
  integration: `headless_prepare_only` compares local/remote refs and stub page JSON before/after, verifies exact packet fields and notes bytes, and ends without a gate or rendered-program execution. Covers S2, S4, S6
Steps:
  1. Extend the `prepare` fixture group with named cases for every happy, edge, and error scenario above; run it and confirm failures identify absent preparation behavior, not fixture setup.
  2. Implement strict argument parsing and production-versus-fixture target validation. Resolve and inventory every target, reject unknown environment overrides, and suppress raw auth/token output.
  3. Implement local release identity checks: exact default branch, clean worktree, SemVer, `HEAD == tag^{}`, annotated-tag object, synchronized manifests, newest CHANGELOG heading, and exact CHANGELOG body extraction with byte count/hash.
  4. Implement read-only remote/auth/page inspection and the named classifications. Compare remote branch ancestry, exact tag object plus peeled OIDs, `tagName`, title, body, draft, and prerelease; treat `targetCommitish` as informational only and never as a repair field.
  5. Render notes and the packet through temporary siblings and atomic rename only after complete preflight. Include one fenced `bash` program with transition-specific expected fingerprints, but do not execute it. Ensure noop and failure complete no new packet.
  6. Run the `prepare` group, `bash scripts/validate.sh`, and a credential/real-origin scan of fixture output. Produce the T0 matrix evidence records under `.release-loop/evidence/U2/` before review.
  7. Commit: "feat(release): Prepare gated publication packets"
Acceptance: `bash scripts/test-release-publication.sh prepare` exits 0 with all cases passed; `bash scripts/validate.sh` exits 0; packet/notes byte and SHA assertions pass; all T0 applicable-cell records exist and prove isolated targets, intended injection mechanisms, post-state, and next invocation.

## U3: Ordered publication transitions, recovery, and repair
Execution note: test-first
Files:
  Create: none
  Modify: scripts/release-publication.sh, scripts/test-release-publication.sh
  Test: scripts/test-release-publication.sh
Interfaces:
  Consumes: ready packet and notes produced by the preparation interface; exact packet SHA-256; one extracted fenced Bash program; fixture-only `RELEASE_PUBLICATION_FAIL_AT=<boundary>` and `RELEASE_PUBLICATION_MUTATE_AT=<boundary>` accepted only when every target is inside `RELEASE_PUBLICATION_FIXTURE_ROOT`
  Produces: one fail-fast program that rechecks the approved fingerprint before each required transition; explicit non-force branch refspec push; exact annotated-tag refspec push; `gh release create --verify-tag` with notes file; narrow `gh release edit --verify-tag` without tag/target/latest/delete flags; verified durable partial state on failure; idempotent fresh-state rerun
Test scenarios:
  happy: a normal approved fixture program advances remote main to the release commit, pushes the exact annotated tag object, creates the canonical page from the notes file, and verifies all identities. Covers AE1, AE3
  edge: matching branch skips branch push; matching tag skips tag push; prerelease values map correctly; repair creates a missing tag/page only when remote main contains the release commit; page repair changes only title/body/draft/prerelease; fully matching rerun increments no mutation counter
  error: push rejection, tag rejection, implicit-tag attempt, page create/edit rejection, immutable or conflicting page, stale branch/tag/page/notes state before every transition, post-transition verification failure, and injection without a valid fixture root stop before every later transition
  integration: `partial_failure_resume` injects failure before tag after branch success and before page after tag success, then reruns preparation and executes only the missing suffix; `repair_never_mutates_branch` proves branch counters remain zero. Covers S3, S5, S6
Steps:
  1. Add mutation-group fixtures for every transition, partial durable state, stale-fingerprint boundary, repair field, and forbidden command above; require unique mechanism markers and exact pre/post/mutation-counter assertions.
  2. Render shared bounded shell functions inside the packet program for sanitized failure, exact `ls-remote` parsing, page JSON comparison, notes hashing, and transition-specific fingerprint comparison; all resolved values remain shell-quoted literals.
  3. Implement the branch transition with the approved remote OID check and explicit non-force release-commit refspec; verify remote main before advancing expected state.
  4. Implement the tag transition with absent-or-exact classification, explicit annotated-tag refspec, no force/delete, and verification of both tag object and peeled commit OIDs.
  5. Implement page creation with `--verify-tag`, canonical title, notes file, and SemVer-derived prerelease; implement repair edit with only title, notes, `draft=false`, prerelease boolean, and `--verify-tag`. Verify canonical fields and remote tag identity after either action.
  6. Implement fixture-only failure/state-mutation boundaries around every transition and post-verification. Reject those variables in production mode and prove a stale state invalidates the packet before the next mutation.
  7. Run `prepare` and `mutations` groups plus `bash scripts/validate.sh`. Produce every T1-T4 applicable-cell record under `.release-loop/evidence/U3/` before review.
  8. Commit: "feat(release): Execute resumable publication transitions"
Acceptance: `bash scripts/test-release-publication.sh prepare` and `bash scripts/test-release-publication.sh mutations` exit 0; no forbidden force/delete/retarget command appears in any packet; every T1-T4 applicable-cell record proves isolation, intended mechanism, exact durable post-state, and fresh-invocation result.

## U4: Publication terminal-signal drift protection
Execution note: test-first
Files:
  Create: none
  Modify: schemas/headless-contract.md, scripts/validate.sh, scripts/test-signal-drift.sh, scripts/test-release-publication.sh, skills/release/SKILL.md
  Test: scripts/test-signal-drift.sh, scripts/test-release-publication.sh, scripts/validate.sh
Interfaces:
  Consumes: current headless contract `v1`; validator check 6 canonical producer map and inline-backtick consumer scan; existing release signal-drift Case H
  Produces: additive `release publish` producer row; canonical `Publication complete — v<version>`, `Publication skipped — <reason>`, and `Publication failed — <reason>` inline placeholders in `skills/release/SKILL.md`; check 6 producer `release publish`, keyword `Publication`, 15-signal invariant; Case I one-byte drift fixture
Test scenarios:
  happy: unmodified contract and skill yield exactly 15 pairwise-distinct canonical signals and all producer/state coverage
  edge: the existing `release` row and three Release placeholder bytes remain unchanged while `release publish` is parsed as a distinct producer sharing the same consumer file
  error: Case I changes only `<version>` inside the unique inline Publication success placeholder, keeps the leading keyword intact, and requires check 6 to name `skills/release/SKILL.md:<computed-line>`, producer `release publish`, state `success`, and the byte mismatch
  integration: publication fixture contract group asserts contract `v1`, exact existing release row, one additive publish row, all three unique inline placeholders, and absence of inline-backticked concrete Publication signals. Covers AE8
Steps:
  1. Add red Case I to `scripts/test-signal-drift.sh` using a computed line and a one-byte placeholder mutation; add red publication-contract assertions to `scripts/test-release-publication.sh`.
  2. Add the `release publish` row to `schemas/headless-contract.md` without changing `v1` or any existing row.
  3. Add the three canonical Publication placeholders to the release skill's terminal contract while keeping concrete examples outside inline backticks.
  4. Extend check 6's producer tuple, keyword regex, `producer_key`, both 12-to-15 count checks, failure message, and success message. Ensure `release` and `release publish` remain distinct keys.
  5. Run `bash scripts/test-signal-drift.sh`, the publication contract group, `bash scripts/validate.sh`, and a focused diff proving the old release row/placeholders are byte-identical.
  6. Commit: "feat(release): Protect publication terminal signals"
Acceptance: `bash scripts/test-signal-drift.sh` exits 0 including Case I; `bash scripts/test-release-publication.sh integration` passes its contract cases; `bash scripts/validate.sh` exits 0 and reports exactly 15 canonical pairwise-distinct signals; the existing release row and placeholders have no byte diff.

## U5: Release-skill publication integration and full scenario regression
Execution note: test-first
Files:
  Create: skills/release/references/publication.md
  Modify: skills/release/SKILL.md, scripts/test-release-publication.sh
  Test: scripts/test-release-publication.sh, scripts/test-signal-drift.sh, scripts/validate.sh
Interfaces:
  Consumes: `$release publish <semver> [repair] [mode:headless]`; preparation machine output; packet path/hash; harness blocking-question protocol; exactly one fenced Bash program beginning `set -euo pipefail`
  Produces: explicit publication dispatch separate from the unchanged local ceremony; publication-specific review packet and same-session USER gate; approve/revise/cancel outcomes; hash-checked one-shot execution; prepare-only headless handoff; canonical Publication terminal line as the last non-empty output; complete S1-S6 fixture regression
Test scenarios:
  happy: normal publish prepares and displays the complete packet, performs zero outward mutation before the fixture gate, then after explicit simulated same-session approval executes once and reports canonical completion. Covers S1
  edge: headless success writes packet/notes and reports canonical skip; fully matching state reports no-op without a gate; repair packet names only missing/narrow transitions; cancellation after preparation leaves outward state unchanged; revised packet requires a new hash and gate. Covers S2, S4, S5
  error: relayed/prior approval, missing blocking tool response, changed packet hash, multiple or non-Bash fences, program not starting with strict mode, protected normal `0.2.0`, failed preflight, wrong injection seam, and stale state all fail or skip with no unapproved later transition. Covers S6
  integration: `all_user_scenarios` runs normal, headless, two partial failures with rerun, fully matching no-op, missing-component repair, page-field repair, every fail-closed classification, local-release regression, target-inventory sentinel, and credential/real-origin evidence scan. Covers S1, S2, S3, S4, S5, S6
Steps:
  1. Extend the integration group with the named S1-S6 cases and static contract assertions for argument dispatch, separate gate, relayed-approval rejection, exact packet hash, one-fence execution, headless stop, and terminal-last-line behavior; confirm failures identify missing skill integration.
  2. Write `skills/release/references/publication.md` as the complete six-phase publication protocol. Name exact preparation command, machine-output handling, packet fields, blocking choices, hash/fence checks, one-shot execution, fresh-state invalidation, recovery classifications, and terminal outcomes.
  3. Modify `skills/release/SKILL.md` argument parsing so `publish` selects the reference protocol and returns before the existing local seven phases; reject duplicate/unknown tokens and `repair` without `publish`; preserve zero/one SemVer local-release invocation behavior.
  4. Implement the publication gate using the same-session blocking-question protocol with **Approve this exact publication/repair**, **Revise**, and **Cancel**. Headless returns immediately after successful preparation; noop returns without a mutation gate; unavailable tooling never converts silence or relay into consent.
  5. Specify packet hash verification, extraction of exactly one strict Bash fence to an ignored temporary file, one Bash invocation, cleanup, post-state verification, and canonical last-line reporting. Never expose independent mutation snippets after failure.
  6. Run the full publication harness, signal-drift harness, validator, placeholder scan, old local-release contract regression, and retained-evidence inventory. Confirm every S-ID has a passing `Covers S<n>` case and every applicable matrix cell has one sanitized record.
  7. Commit: "feat(release): Integrate gated outward publication"
Acceptance: `bash scripts/test-release-publication.sh all`, `bash scripts/test-signal-drift.sh`, and `bash scripts/validate.sh` exit 0; all S1-S6 integration cases pass; local release behavior and Release signal bytes remain unchanged; target/evidence scans prove no real remote, GitHub mutation, token, or account material was used.

## Mutation/failure-state matrix

Capability inspection, state classification, gate display, and final
verification are read-only and therefore are not durable-transition rows. Their
failures are exercised in U2/U3/U5 and stop before the next row. This matrix
follows `skills/planning/references/stateful-ceremony-matrix-example.md`; any
post-approval row/outcome change follows
`docs/solutions/workflow-issues/review-introduced-state-machine-deviation.md`.

| ID | Pre-state | Action | Expected post-state | Owner / evidence owner | Success | Forced failure | Rerun | Rollback or compensation | Headless | Cancellation or abort |
|---|---|---|---|---|---|---|---|---|---|---|
| T0 Packet + notes persistence | Complete read-only preflight; no newly completed packet for this invocation; outward state unchanged | Atomically write exact notes, then packet containing notes hash and one fail-fast program | Ignored notes and packet exist; packet hash is reported; outward state unchanged | U2 / `.release-loop/evidence/U2/t0-packet-<outcome>.md` | `t0-packet-success.md`: ready output, exact bytes/hash, zero outward counters | `RELEASE_PUBLICATION_FAIL_AT=packet-before-rename` inside fixture root; `t0-packet-forced-failure.md` proves no newly completed packet, temp cleanup, intended marker | `t0-packet-rerun.md`: fresh preparation safely replaces local artifacts, rederives hash/fingerprint, zero outward counters | `t0-packet-rollback-compensation.md`: remove temporary siblings; an orphan notes file is non-executable and any older packet fails its notes/fingerprint checks | `t0-packet-headless.md`: same persistence succeeds, then headless stops without gate/program execution | `t0-packet-cancellation-abort.md`: abort before write leaves no new artifact; cancel after write retains ignored handoff but performs zero outward mutation |
| T1 Default-branch fast-forward | Approved transition fingerprint; remote default branch equals observed ancestor OID; local HEAD/tag target equal release commit; tag/page transitions not yet run | Non-force explicit `<release-commit>:refs/heads/<default>` push, then exact remote OID verification | Remote default branch equals release commit; tag/page unchanged | U3 / `.release-loop/evidence/U3/t1-branch-<outcome>.md` | `t1-branch-success.md`: exact fast-forward and verified OID | Bare-remote hook rejects push at `branch-push`; `t1-branch-forced-failure.md` proves branch unchanged and no tag/page call | `t1-branch-rerun.md`: matching branch is recognized and not pushed again; next missing transition is prepared | `t1-branch-rollback-compensation.md`: no automated rewind/force; retain exact commit and resume tag/page or require manual recovery | `t1-branch-headless.md`: not applicable because headless exits before every outward transition | `t1-branch-cancellation-abort.md`: abort before push leaves state; interrupt after verified push preserves branch and next invocation resumes without repush |
| T2 Annotated-tag publication | Approved transition fingerprint; remote main contains release commit; remote tag absent; exact local annotated tag exists | Non-force explicit `refs/tags/v<version>:refs/tags/v<version>` push, then object and peeled-OID verification | Remote exact annotated tag exists; branch unchanged; page unchanged | U3 / `.release-loop/evidence/U3/t2-tag-<outcome>.md` | `t2-tag-success.md`: exact object/peeled OIDs verified | Bare-remote hook rejects tag or injected abort before tag after branch success; `t2-tag-forced-failure.md` proves durable branch/no tag/no page and intended marker | `t2-tag-rerun.md`: exact existing tag is not repushed; preparation advances to page; conflicting tag fails | `t2-tag-rollback-compensation.md`: no tag delete/move; retain exact tag and resume page, or manual recovery for conflict | `t2-tag-headless.md`: not applicable because headless exits before every outward transition | `t2-tag-cancellation-abort.md`: abort before push leaves tag absent; interrupt after verified push preserves tag and next invocation resumes page only |
| T3 Release-page creation | Approved transition fingerprint; remote main contains release commit; exact remote tag exists; page absent | `gh release create` with explicit tag/repo, `--verify-tag`, canonical title, notes file, and SemVer-derived prerelease | One published, non-draft page exists with canonical tag/title/body/prerelease; refs unchanged | U3 / `.release-loop/evidence/U3/t3-page-create-<outcome>.md` | `t3-page-create-success.md`: one page and exact fields/body | Stub rejects create or removes tag immediately before call; `t3-page-create-forced-failure.md` proves no implicit tag/page and intended marker | `t3-page-create-rerun.md`: matching page is no-op; mismatching page routes only to explicit repair | `t3-page-create-rollback-compensation.md`: no automated page delete; retain created page, verify/repair canonical fields on fresh invocation, or manual recovery | `t3-page-create-headless.md`: not applicable because headless exits before every outward transition | `t3-page-create-cancellation-abort.md`: abort before call leaves page absent; interrupt after create preserves page and next invocation verifies/no-ops or repairs explicitly |
| T4 Canonical page repair | Explicit repair packet approved; remote main contains release commit; exact remote tag/page identity exists; one or more editable canonical fields differ | `gh release edit` with `--verify-tag`, canonical title/notes, `--draft=false`, and derived prerelease boolean; no tag/target/latest/delete flags | Same page/tag identity with canonical title/body/draft/prerelease; refs unchanged | U3 / `.release-loop/evidence/U3/t4-page-edit-<outcome>.md` | `t4-page-edit-success.md`: only approved fields change | Stub rejects edit or mutates page after fingerprint check; `t4-page-edit-forced-failure.md` proves no later action, identity unchanged, intended marker | `t4-page-edit-rerun.md`: canonical page is no-op; remaining mismatch requires a newly prepared repair packet | `t4-page-edit-rollback-compensation.md`: no delete/recreate/retarget and no fictional rollback; re-inspect and reapply canonical repair or require manual recovery | `t4-page-edit-headless.md`: not applicable because repair headless stops with packet before page mutation | `t4-page-edit-cancellation-abort.md`: cancel before call leaves mismatch; interrupt after edit preserves observed page and next invocation verifies or offers a fresh repair |

## Deferred to Follow-Up Work

- Real GitHub mutation smoke testing remains user-owned and requires a new
  first-hand authorization naming a disposable or intentionally publishable
  repository/version. It is not implementation acceptance evidence.
- Non-GitHub hosting, GitHub Enterprise host configuration, CI/scheduled
  publication, release assets, discussions, and explicit latest-release policy
  remain outside this feature.
- Removing the delivered P2 ROADMAP row belongs to the retrospective's
  carry-forward reconciliation after implementation/review/ship evidence, not
  to an implementation unit.
- Wiring `scripts/test-release-publication.sh` or
  `scripts/test-signal-drift.sh` into external CI remains separate repository
  policy; this plan requires direct execution during implementation/review.
- Automated validation for mutable numbered planning references remains the
  existing P3 ROADMAP item; this plan adds no numbered planning headings or
  planning-schema sections.

## Open unknowns

**Planning-time**: none. The user confirmed the approved scope. All retained
assumptions match, official GitHub documentation resolves existing-tag target
semantics, and the spec fixes normal timing, repair authority, canonical page
fields, terminal signals, and the no-real-target boundary.

**Implementation-time**:

- Exact private shell function names and the stub JSON key layout may change
  while preserving the public preparation output, packet fields, command
  sequence, state classifications, fixture markers, and matrix outcomes.
- Exact concise diagnostic prose may vary, but every failure must name its
  classification/boundary without credentials and retain the canonical
  Publication terminal family at the skill boundary.
- GitHub write authorization and repository immutability are discoverable only
  when a real mutation is attempted. Implementation acceptance does not attempt
  one; the approved runtime behavior is fail-closed partial-state reporting and
  fresh-state rerun, not a claim that read-only preflight guarantees writes.
