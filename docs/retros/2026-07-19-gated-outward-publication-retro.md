# Retro: gated outward publication

- Date: 2026-07-19
- Source: merged range `f673b1f..596c8ea`
- Spec: `docs/specs/2026-07-18-gated-outward-publication-design.md`
- Plan: `docs/plans/2026-07-18-003-feat-gated-outward-publication-plan.md`

## Release data

| Metric | Value |
|---|---|
| Code delta (product / test / docs) | +932/-3 / +1895/-6 / +875/-0 |
| Commits | 18 |
| Review rounds | 15 lifecycle rounds: 13 internal + 2 external |
| Comments (fixed / deferred) | ledger 17/0 internal; 2/0 external; internal finding granularity is not independently auditable from the narrative |
| CI failures | 0; no PR CI run, one external Python 3.14.6 verification failure fixed before merge |
| Duration (first spec commit -> merge) | <1 day; 4h42m from first spec commit to final fix commit |
| Units planned / completed | 5 / 5 |

Product is `scripts/release-publication.sh`, the release skill/reference, and
the headless contract. Test includes the publication harness, signal-drift
harness, and validator. Docs are the approved spec and plan.

## Success criteria: measured vs declared

All commands below were rerun on merged `main` during this retrospective with
Python 3.14.6 selected for the publication harness.

| # | Declared criterion | Measurement (command / rubric) | Measured result | Verdict |
|---|---|---|---|---|
| 1 | Publication has an explicit action and separate same-session USER gate; local-release approval cannot authorize it | Reviewer walk of S1 plus `publication_skill_dispatch`, `s1_first_hand_approval`, `gate_revision`, `gate_cancel`, and `gate_rejects_non_direct` in `bash scripts/test-release-publication.sh all` | Explicit publish dispatch returns before local phases; preparation precedes one exact execution; revise/cancel/relay/silence/prior approval cannot execute | Met |
| 2 | Headless publication is prepare-only and leaves outward state unchanged | Fixture cases `headless_prepare_only` and `s2_headless_prepare_only`; compare local/remote refs and page state before/after | Packet and notes were retained, outward state and counters were unchanged, and the canonical Publication skipped line was terminal | Met |
| 3 | Publication reuses the target CHANGELOG body exactly | Fixture byte/hash assertions in `fast_forwardable_prepare`, `exact_packet_execution`, and S1 | Extracted notes, packet-declared notes hash, and stub endpoint body matched including section and trailing-newline bytes; zero-byte difference | Met |
| 4 | Matching partial branch/tag/page states resume safely and complete state is idempotent | T1/T2 forced-failure, rerun, and compensation cases plus `s3_partial_resume` and `s4_fully_matching_noop` | Durable matching prefixes were not repeated; only missing suffix transitions ran; the third complete invocation made zero mutations | Met |
| 5 | Conflicting refs and protected `v0.2.0` cannot enter normal publication | `divergent_branch`, `different_tag_object`, `conflicting_page_identity`, `protected_version`, and repair preparation cases | Every conflict stopped before gate/mutation; normal `0.2.0` returned protected-version conflict and only explicit repair could prepare a repair packet | Met |
| 6 | Repair is narrow and never rewrites published history | T4 six-outcome cases, `remote_later_repair`, `unordered_page`, and `s5_narrow_repair`; reviewer scan of rendered commands | Repair required remote main containment, emitted no branch mutation, changed only canonical page fields or restored missing tag/page, and exposed no force/move/delete/retarget/duplicate command | Met |
| 7 | Capability failure and stale post-gate state fail closed | Capability cases `inactive_auth` through `unreadable_remote`, stale/fingerprint cases 65-83, `s6_unreadable_page_ceremony`, and both after-gate tamper cases | Incomplete capabilities produced no executable packet; every stale transition stopped further mutation; packet/notes tamper executed zero programs and required fresh derivation/gate | Met |
| 8 | Publication signals are additive and local release signals remain unchanged | `bash scripts/test-release-publication.sh all`; `bash scripts/test-signal-drift.sh`; `bash scripts/validate.sh` | Publication suite 100/100; drift Cases A-I passed including Case I producer/state mismatch proof; validator reported exactly 15 canonical pairwise-distinct signals and passed | Met |
| 9 | The approved plan contains the first real stateful-ceremony matrix and retained evidence ownership | Reviewer maps T0-T4 x six outcomes to U2/U3, named fixture cases, and `.release-loop/evidence/U2|U3` | Five durable transitions have 30 explained cells, 30 retained sanitized records, and 30 named fixture cases; T1-T4 expose 24 distinct outcome mechanisms and T0 owns six packet outcomes | Met |
| 10 | Existing local release behavior remains intact and validation uses no real outward target | All three commands above; `local_release_regression`; target inventory/boundary sentinel and retained-evidence scan | All commands exited 0; local release section hash matched its base bytes; targets were only disposable roots, local bare remote, and loopback stub; no real origin, credential, or token was retained | Met |

## Carry-forward from previous retro

Previous retro:
`docs/retros/2026-07-18-process-guidance-carry-forward-retro.md`.

| Item | Status | Evidence |
|---|---|---|
| Gated outward publication automation for `release` | Done | All 10 criteria pass on merged `main`; `b4afed5` through `596c8ea` implement packet preparation, transitions, consent, capability/tamper checks, and the protected-version normal/repair state machine; remove the delivered row |
| Second qualifying larger-feature pilot | Done | One five-unit plan completed 5/5 under subagent-driven dispatch with per-unit review: U1 one round, U2 three, U3 three, U4 one, U5 three, and final branch review two; serial execution was intentional because units shared files, so do not claim parallel writes; remove the row |
| Diff-size metric reconciliation across phases | Not started | This retro classifies the merged diff once, but no cross-phase metric contract was added to lifecycle skills or schemas; keep the row |
| Clean-environment Codex install check | Not started | No isolated installation was exercised; keep the row |
| Automated numbered-reference validation | Not started | This arc added no planning/schema numbered section and did not implement the validator; keep the row |

## Findings

### What worked well

- **What happened**: The first live T0-T4 matrix produced 30 retained records
  and named fixture coverage for all five transitions and six outcome classes.
  U2 review required all six T0 records to be recaptured with the full schema;
  U3 review rejected inaccurate T2-T4 post-states and missing immediate
  tag-disappearance evidence before accepting the unit.
  **Why**: Evidence ownership was assigned in the approved plan and enforced
  before each unit review, so the matrix affected implementation rather than
  being reconstructed afterward.
  **How to apply**: Keep the matrix limited to durable transitions, require the
  records before review, and retain scenario-level review for read-only
  classification, gates, and final verification that are intentionally outside
  matrix rows.

- **What happened**: The five-unit arc satisfied the larger-feature second
  pilot with 13 internal rounds, seven feedback rounds, per-unit reviewers, and
  5/5 completion.
  **Why**: The qualification threshold was 5+ substantive units, not forced
  parallel editing; the dispatcher correctly serialized overlapping U1-U3-U5
  and U4-U5 surfaces while preserving fresh-context review.
  **How to apply**: Judge dispatch pilots by substantive unit boundaries and
  independent review evidence, not by whether unsafe parallel writes occurred.

### What to improve

- **What happened**: An external Python 3.14.6 run reported 93/6 while the same
  commit passed 99/99 under Python 3.11 or earlier; the first response called
  the report non-reproducible and suspected stale checkout. Python 3.14.6 then
  reproduced the six failures, and `596c8ea` fixed the outer-template escape
  and added `-W error::SyntaxWarning -m py_compile` for the extracted engine.
  **Why**: Exact commit identity was treated as complete environment identity;
  the interpreter path/version was not compared before rejecting the report.
  The warning went to stderr, which the harness combined with exact-shape
  stdout.
  **How to apply**: Capture interpreter identity before diagnosing result drift,
  reproduce on a second supported version, and compile generated code with
  syntax warnings promoted to errors.

- **What happened**: `.release-loop/progress.md` reports 17 fixed internal
  comments, but the narrative cannot reproduce 17 without choosing a different
  granularity for compound findings; an independent facilitator counts at
  least 18 actionable categories. The 13 rounds and seven feedback rounds do
  reconstruct exactly.
  **Why**: The scalar counter and prose grouped multi-part findings differently.
  **How to apply**: Give each review finding a stable ID or append-only record
  before using comment totals as an audited retrospective metric; until then,
  label the scalar as ledger-declared rather than independently measured.

### Process observations

- **What happened**: External review contributed one pre-approval spec finding
  (`745b433` added Publication drift protection) and one cross-environment RED
  report resolved by `596c8ea`. Internal review drove release-blob reads,
  remote-parser and transport strictness (`2737019`, `ea4703e`, `ad63e83`),
  fingerprint binding (`6b2f1bb`), exact consent output (`8c15b20`),
  post-consent hash rechecks (`8956fc3`), and fail-closed capability checks
  (`c83cf1f`). None were deferred.
  **Why**: Spec review covered validator fan-out, unit review exercised matrix
  cells and transition boundaries, final review challenged cross-unit
  capability behavior, and the external environment exposed interpreter drift.
  **How to apply**: Preserve source and round identity for review evidence;
  different review surfaces found different defect classes.

- **What happened**: No real GitHub mutation occurred anywhere in the arc.
  Every acceptance path used a disposable repository, local bare remote, and
  stub; a real mutation smoke remains user-owned and requires new first-hand
  authority naming an intentionally publishable target/version.
  **Why**: Real outward mutation was deliberately excluded from implementation
  acceptance and from this retrospective.
  **How to apply**: Keep the automation row closed while tracking the first
  intentional live smoke separately; never use normal publication to republish
  protected `v0.2.0`.

## Carry-forward items registered

| Item | Type | Priority | Tracked at |
|---|---|---|---|
| Declare the supported Python range and validate extracted generated Python with `-W error::SyntaxWarning -m py_compile` on the oldest and newest supported interpreters | process | P2 | `ROADMAP.md` Carry-forward from retros |
| Run the first real gated-publication smoke only on a disposable or intentionally publishable future repository/version after a new first-hand approval; never normal-republish protected `v0.2.0` | edge-case | P2 | `ROADMAP.md` Carry-forward from retros |

## Lessons

- Exact commit identity is necessary but not sufficient reproduction identity;
  record interpreter identity before rejecting a cross-environment failure.
- A stateful-ceremony matrix earns its keep when every cell owns a named test
  and retained record before review, not when it merely summarizes code later.
- Safe serialization can satisfy a multi-agent pilot; artificial parallelism is
  not evidence of better orchestration.
- Review-count scalars without stable finding IDs are operational hints, not
  auditable retrospective totals.

## Compounding

- compound invocation: `Documentation complete — docs/solutions/test-failures/generated-python-version-warning-gate.md`
