# Retro: schema-reference-and-seal-verification

- Date: 2026-08-16
- Source: PR #16
- Spec: `docs/specs/2026-08-14-schema-reference-and-seal-verification-design.md`
- Plan: `docs/plans/2026-08-14-001-fix-schema-reference-and-seal-verification-plan.md`

## Release data

| Metric | Value |
|---|---|
| **Changed non-test lines** | 1,068 (1,012 added + 56 removed) |
| Commits | 25 |
| Review rounds | 30 |
| Comments (fixed / deferred) | 81 / 1 |
| CI failures | 0 |
| Duration (first spec commit → merge) | 1d 6h 34m 18s |
| Units planned / completed | 4 / 4 |

## Success criteria: measured vs declared

| # | Declared criterion | Measurement (command / rubric) | Measured result | Verdict |
|---|---|---|---|---|
| 1 | A standalone planning installation contains and resolves its full schema. | `bash scripts/test-planning-schema-portability.sh` | verified: fresh run copied the planning package, resolved its local schema inventory, and reported 18 checks passed / 0 failures | Met |
| 2 | Each external consumer executes its defined plan decisions without the full schema. | `bash scripts/test-plan-consumer-portability.sh` | verified: fresh standalone implementing, release-loop, and retrospective fixtures reported 321 passed / 0 failed | Met |
| 3 | Correct and mutated seals receive identical results from the shipped validator and check 14. | `bash scripts/test-body-seal.sh` | verified: fresh parity and mutation fixtures completed within 179 passed / 0 failed, including the one-byte mutation and computed-digest checks | Met |
| 4 | Seal printing is reproducible and safe on invalid input. | `bash scripts/test-plan-frontmatter.sh` and `bash scripts/test-body-seal.sh` | verified: fresh CLI parity, missing-delimiter, argument-arity, and empty-output guards passed; the suites reported 37 passing frontmatter cases plus body-seal 179/0 | Met |
| 5 | Unsealed plans retain existing behavior. | `bash scripts/test-plan-frontmatter.sh` | verified: fresh pristine/candidate no-seal comparisons passed byte-for-byte; 37 cases passed and the only failure was unchanged case 20 | Met |
| 6 | Existing validator behavior outside issue #14 does not regress. | `bash scripts/test-plan-frontmatter.sh` | verified: fresh run reported 37 passing cases; pre-existing case 20 alone still failed because `execution: ops` is accepted while its old expectation rejects it | Met — the declared unchanged known failure remains isolated |
| 7 | The repository body-seal test file passes in full with the new shipped-validator cases. | `bash scripts/test-body-seal.sh` | verified: fresh run exited 0 with 179 passed / 0 failed | Met |
| 8 | Legacy seal-only migration is distinguishable from a body edit. | `bash scripts/test-body-seal.sh` | verified: fresh migration fixtures accepted the baseline-proven seal-only transition, rejected body mutation, and completed six durable outcomes within 179/0 | Met |

## Carry-forward from previous retro

| Item | Status | Evidence |
|---|---|---|
| Adversarially test each integrity mechanism with the cheapest intent-violating artifact | Done | Approved plan `# Carry-forward trigger audit`, U3/U4 reports, and final review rounds (T2, T5) |
| Grade findings against the threatened success criterion rather than local code blast radius | Done | Approved plan reviewer mandate and P1 classifications through `.release-loop/reviews/final-findings-round6.md` (T2, T5) |
| Gate criteria that require human action outside the pipeline | Not started | Trigger did not fire: all eight current spec criteria had executable repository measurements in Phase 3 |
| Post the issue #7 correction and close issues #6, #8, #9, and #10 | Done | `ROADMAP.md` row marked Done with issue-comment evidence (T1) |
| Move outliving loop artifacts from gitignored `.release-loop/` before cleanup | In progress | Retro and archive are still executing; transfer to the base checkout has no completed artifact yet |
| Merge or push a feature-branch retro in the same action and update its ledger pointer | In progress | This retro's Phase 8 commit and transport occur after document assembly; no completed commit exists at measurement time |
| Persist facilitator and reviewer output verbatim at dispatch time | Not started | Current facilitator output exists only as session artifact `agent://RetroFacilitator`; no committed verbatim artifact was produced |
| Pass `SSH_AUTH_SOCK` to committing agents and verify signatures | Done | `.release-loop/reports/U1-report.md` through `U4-report.md` record signed `G` commits (T2) |
| Transfer live release-loop state to the base checkout before worktree removal | In progress | `.release-loop/progress.md` remains in the isolated worktree until the archive procedure completes |
| Require forced-failure plans to name executable probe syntax, expected partial state, and compensation ownership | Done | Approved plan U4 mutation/failure-state matrix and fresh `scripts/test-body-seal.sh` 179/0 (T2; Phase 3) |

- Reconciliation: registered 10, accounted for 10
- Previous doc shape: conformant

## Interview Transcript

- Independence level: same-model fresh-context
- Rounds used: 3 (max 5)

| ID | Round | Phase | Probe | Answer | Evidence | Verdict (verbatim) |
|---|---|---|---|---|---|---|
| T1 | 1 | 4 | What artifact accounts for all 10 previous carry-forward items? | One item was already discharged; the approved plan audited the remaining nine as four fired and five non-fired. | Previous retro; approved plan carry-forward audit | accepted |
| T2 | 1 | 4 | Which prior triggers definitely fired, and what absorbed them? | Forced-failure state, adversarial invariant review, severity-by-criterion, and signed-agent commits were incorporated into U4, U3, the review mandate, and unit commit gates. | Approved plan; `.release-loop/reports/U*-report.md` | accepted |
| T3 | 1→3 | 4 | Can each of the five non-fired ROADMAP row numbers be bound to a previous-retro item without inference? | The supplied interview artifact set preserved the count and reasons but not the row-number-to-item mapping. | Approved plan; previous retro | no evidenced answer (3 rejections): rejected: the allowed artifacts name ROADMAP rows 53, 54, 57, 58, and 61 and five reasons, but do not bind each row number to one of the five prior-retro item names; per-item reconciliation would require ROADMAP.md or an equivalent mapping outside the supplied artifact set. |
| T4 | 1 | 4 | Does the previous retro satisfy the backward shape check? | It has a valid heterogeneous transcript, three rounds, and citations for every finding. | `docs/retros/2026-08-15-retro-interview-integrity-retro.md` | accepted |
| T5 | 1 | 5 | What almost went wrong, and which gate caught it before merge? | Final review round 1 found four P1 and four P2 defects; concrete P1s continued through round 6 before round 7 became clean. | `.release-loop/reviews/final-findings-round1.md`; `final-findings-round7.md` | accepted |
| T6 | 1 | 5 | Which event shows evidence quality, rather than product code, was corrected? | U3 review rejected a transient 33/5 RED claim and required a reproducible parent/blob recipe; the report now records reproducible 31/7 RED and unchanged product code. | `.release-loop/reports/U3-report.md`; `.release-loop/reviews/U3-findings-round1.md` | accepted |
| T7 | 1 | 5 | What failed after internal review had declared the branch clean? | PR review found three actionable findings and four nitpicks on the clean internal head; `095bd52` fixed them and the exact new head was revalidated before merge. | PR #16; `.release-loop/progress.md` entries 92–100 | accepted |
| T8 | 1→2 | 5 | Which phase demonstrably required repeated correction cycles? | The ledger records 29 review rounds, 25 feedback rounds, 81 fixed comments, and seven final-review artifacts with five user-authorized post-cap corrections. | `.release-loop/progress.md`; `.release-loop/reviews/final-findings-round*.md` | accepted |
| T9 | 1 | 5 | Which process-control failure occurred before approved implementation? | The ledger retracts a false approval claim and records three commits made before Design and Plan gates; work froze until both gates were explicitly satisfied. | `.release-loop/progress.md` entry at 2026-08-14T20:34:49Z | accepted |
| T10 | 1 | 5 | Which green result concealed a coverage regression? | Consumer portability stayed green at 233/0 after an evaluator dispatch disappeared and 54 assertions became unreachable; the prior 283 count exposed the loss. | `.release-loop/reviews/final-findings-round5.md`; progress entries 85–88 | accepted |
| T11 | 1 | 5 | Which passing oracle was self-consistent but not contract-consistent? | Fixture and oracle shared delimiter-line slicing instead of the approved universal-newline literal split, so 290/0 proved only their shared divergence. | `.release-loop/reviews/final-findings-round6.md`; round 7 closure | accepted |
| T12 | 1→3 | 5 | What disposes of the late outside-diff Major finding on canonical evidence publication? | CodeRabbit later approved the same head, but no artifact fixes, defers, or explicitly accepts the run-specific and non-atomic publication finding. | CodeRabbit review `4946059911`; approval `4946060047`; PR #16 | no evidenced answer (3 rejections): rejected: approval of the same head without a disposition body is not evidence that the later outside-diff atomic-publication finding was fixed or accepted; the supplied artifacts contain no cited resolution. |
| T13 | 1 | 5 | What post-merge operational work remained incomplete? | The squash merge executed, but remote branch deletion remained incomplete after the combined command hit a local-worktree conflict. | `.release-loop/progress.md` entry 101 | accepted |
| T14 | 1 | 5 | What reusable lesson follows from the assertion-count regression? | A materially lower assertion count blocks review even when the remaining deterministic suite is green; compare coverage cardinality across trusted runs. | T10 evidence | accepted |
| T15 | 1 | 5 | What reusable lesson follows from the seal-oracle regression? | A parity oracle must be implementation-independent at the semantic boundary; a shared helper proves self-consistency, not contract conformance. | T11 evidence | accepted |
| T16 | 1 | 5 | What reusable lesson follows from the PR feedback sequence? | Feedback commits invalidate prior merge preparation; the pushed head, its checks, and all feedback surfaces must be reverified before executing the merge. | PR #16; progress entries 92–100 | accepted |

## Findings

### What worked well

- **What happened**: Final branch review found eight actionable defects in round 1 and continued finding contract holes until round 7 verified a clean branch.
  **Why**: Review attacked parser, history, migration, and recovery invariants rather than trusting green unit outputs.
  **How to apply**: Preserve adversarial, independent final review for integrity mechanisms even after every implementation unit is locally clean.
  **Cites**: T5
- **What happened**: U3 review corrected the identity of RED evidence without changing already-correct product code or tests.
  **Why**: The reviewer demanded an exact parent/blob reproduction instead of accepting a transient run summary.
  **How to apply**: Treat reproducibility metadata as part of test evidence; correct the evidence rather than perturbing correct code.
  **Cites**: T6
- **What happened**: The PR feedback commit invalidated the old merge preparation, then the exact new head was tested, reviewed, and approved before merge.
  **Why**: The release ledger forced head-specific determination and retained first-hand consent separately from preparation evidence.
  **How to apply**: Recompute merge readiness after every feedback commit; never inherit approval or verification from an earlier SHA.
  **Cites**: T7, T16

### What to improve

- **What happened**: Three commits landed before genuine Design and Plan approval after a false approval claim.
  **Why**: Conversation interpretation outran the persisted gate evidence.
  **How to apply**: Freeze implementation unless the exact approval record exists in the ledger and approved artifact; retract and document any mistaken transition immediately.
  **Cites**: T9
- **What happened**: A green 233/0 result hid 54 unreachable assertions after evaluator dispatch was replaced.
  **Why**: The gate checked failures but not execution inventory continuity.
  **How to apply**: Compare deterministic assertion cardinality with the last trusted run and explain every delta; pair it with dispatch inspection rather than treating count as coverage.
  **Cites**: T10, T14
- **What happened**: A fixture generator and purported independent seal oracle shared the same wrong extraction helper while 290 assertions passed.
  **Why**: The oracle was independent in name but not at the semantic boundary.
  **How to apply**: Re-derive contract semantics independently and add discriminating inputs where plausible algorithms diverge.
  **Cites**: T11, T15
- **What happened**: CodeRabbit reported a Major run-specific/non-atomic canonical evidence publication defect, then approved the unchanged head without a durable disposition for that finding.
  **Why**: The merge gate considered approval state and unresolved threads, but the outside-diff finding existed only in a review body.
  **How to apply**: Track every actionable review-body finding independently of thread state and require an explicit fixed, deferred, declined, or accepted disposition.
  **Cites**: T12

### Process observations

- **What happened**: The cycle accumulated 30 review rounds and 81 fixed comments; the facilitator-era count was 29 before the late outside-diff CodeRabbit review added the final round and one deferred Major.
  **Why**: Test-oracle defects repeatedly made passing evidence weaker than claimed, so each correction exposed the next untested boundary.
  **How to apply**: Front-load independent oracles, mutation checks, and execution-inventory guards before entering final branch review.
  **Cites**: T8, T10, T11, T12; Phase 2 release data
- **What happened**: The combined merge/delete command merged the PR but returned nonzero during local cleanup because `main` belonged to another worktree.
  **Why**: One command crossed a successful remote transition and a local worktree-sensitive cleanup step.
  **How to apply**: After a compound outward command fails, query remote state before retrying; resume only the incomplete cleanup operation.
  **Cites**: T13

## Carry-forward items registered

| Item | Type | Priority | Tracked at |
|---|---|---|---|
| Make canonical adoption evidence publication fixture-local by default or atomic and manifest-verified when durable | architecture | P1 | `ROADMAP.md` — canonical evidence publication row |
| Make Ship inventory current-head review bodies and outside-diff findings in addition to approval state and unresolved threads | process | P1 | `ROADMAP.md` — approval/review-body gap row |

## Lessons

- A deterministic suite that drops assertions is not green until the missing execution inventory is explained.
- An oracle that shares the implementation's semantic helper proves self-consistency, not correctness.
- Approval state is not a substitute for a 1:1 disposition of every actionable feedback surface.
- A failed compound command may contain a completed irreversible prefix; verify remote state before retrying its suffix.

## Compounding

- compound invocation: `Documentation complete — docs/solutions/test-failures/green-suite-unreachable-assertions.md`
- selective refresh recommendation: `docs/solutions/test-failures/validator-harness-mutation-gap.md` has moderate overlap and may later cross-link assertion-cardinality continuity.
