# Retro: frontmatter-validator-python38

- Date: 2026-07-26
- Source: PR #1 — merged as `adb310d` (merge commit, repo convention; base `60df670`)
- Spec: docs/specs/2026-07-26-frontmatter-validator-python38-compat-design.md
- Plan: docs/plans/2026-07-26-001-fix-frontmatter-validator-python38-plan.md

## Release data

| Metric | Value |
|---|---|
| **Changed non-test lines** | 6 (6 added + 0 removed; 2 in `skills/compound/scripts/validate-frontmatter.py`, 1 in `ROADMAP.md`, 3 in `CONCEPTS.md`). Total branch insertions 554 — the remaining 548 are the spec and plan documents |
| Commits | 11 (10 branch + 1 merge `adb310d`) |
| Review rounds | 6 (1 degraded spec review via `advisor`, 1 full-tier spec review of 3 lanes, 1 plan review, 1 final branch review, 1 phase-gate review, 1 post-PR automated review) |
| Comments (fixed / deferred) | 0 / 2 — one `replied`, one `declined`; neither is a deferral in the ordinary sense, and the schema has no bucket that fits |
| CI failures | 0 (GitGuardian pass, CodeRabbit pass, first attempt; repo has no `.github/workflows/`) |
| Duration (first spec commit → merge) | ~3.7 hours (2026-07-26 06:23:47Z → 10:03:16Z, same day) |
| Units planned / completed | 2 / 2 |

## Success criteria: measured vs declared

One row per criterion from the spec's Success Criteria section. The measurement is run FRESH
during the retro (enforces: P3) — a prior claim in a commit message or PR body is not evidence.
Every command below was re-executed in a detached worktree checked out at the merge commit
`adb310d`, not on the feature branch.

| # | Declared criterion | Measurement (command / rubric) | Measured result | Verdict |
|---|---|---|---|---|
| 1 | Committed validator exits 0 on CPython 3.8 for a bug-track document carrying a frontmatter list | `python3.8 skills/compound/scripts/validate-frontmatter.py docs/solutions/test-failures/generated-python-version-warning-gate.md; echo $?` | verified: `OK: docs/solutions/test-failures/generated-python-version-warning-gate.md` then `0` (failing-repro-now-passing — the same command produced a `TypeError` traceback at spec time) | Met |
| 2 | Identical verdicts on 3.8 and 3.14 across the entire `docs/solutions/` corpus | the spec's `cmp -s` sweep over `git ls-files 'docs/solutions/*.md'` | verified: `0` across 10 documents (returned `1` against the pre-change file — discriminating, not vacuous) | Met |
| 3 | Failure path still fails on 3.8 with the same diagnostics as 3.14 | the spec's `bad.md` fixture recipe, comparing stderr with `cmp -s` | verified: `3.8 rc=1`, `3.14 rc=1`, `cmp=0` (stderr `cmp=1` pre-change; exit codes alone never discriminated here) | Met |
| 4 | Structural validation including the 3.9/3.14 compatibility gate stays green | `bash scripts/validate.sh` | verified: `ALL CHECKS PASSED` (tier-free — structural validation) | Met |
| 5 | Declared support contract byte-unchanged by this cycle | `git diff 60df670 -- schemas/python-support.json scripts/test-python-compatibility.sh docs/specs/2026-07-19-python-compatibility-generated-code-warning-gate-design.md` | verified: 0 lines of output; the criterion is pinned to the branch point, so it stays falsifiable after merge | Met |
| 6 | Drift exposure registered where retro reconciliation will find it | `grep -n '3.8' ROADMAP.md` | verified: exactly 1 match, `ROADMAP.md:61`, inside the `## Carry-forward from retros` table with origin, P3, and trigger (tier-free — structural grep) | Met |
| 7 | R3 — nothing observable changes on a supported interpreter; pre/post agree across the corpus on both boundaries | the spec's pre/post `cmp -s` over `git show 60df670:…` versus the merged file, on 3.9 and 3.14 | verified: `0` (invariance guard — passing before the change is expected and is not evidence of it) | Met |

## Carry-forward from previous retro

Trigger class is stated before status, applying the P3 rule the previous retro registered —
this reconciliation is its first execution. The branch touched exactly five files:
`CONCEPTS.md`, `ROADMAP.md`, the spec, the plan, and `skills/compound/scripts/validate-frontmatter.py`.

| Item | Status | Evidence |
|---|---|---|
| Reword plan-schema audit-section provenance (name the plan path) | Not started — edit-based on `schemas/plan-schema.md`, did not fire | `git diff --stat 60df670..9440f44` lists 5 files, plan-schema absent (T1) |
| Fix stale "item 1's deviation-addendum rule" refs (plan-schema:32, planning SKILL:120) | Not started — edit-based, did not fire | same 5-file diff (T1) |
| Retro-side trigger classification rule (classify trigger class before status) | In progress — this reconciliation is its first application; no durable rule yet exists in the retro skill or template | this section's structure; ROADMAP row still open |
| Release headless-path `.release/draft.md` non-authorization marker | Not started — event-based, did not fire. Adjacent but distinct: this cycle wrote such a marker into `.release-loop/ship-packet.md`, which is `shipping`'s gitignored packet, not `release`'s `.release/draft.md` | `.release-loop/ship-packet.md` opening paragraph; no file under `skills/release/` in the branch diff |
| `final_action` record polish (N-1 marker/note slot, N-2 Log clause) | Not started as an edit — `progress-schema.md` untouched — **but the drift it predicts recurred**: the live record carried `note:` at `determined` and `result:` at `executed`, both outside the documented 4-field block. The previous retro recorded this record staying schema-clean "for the first cycle since registration"; that streak is broken | `progress-schema.md:27-32` vs live `.release-loop/progress.md:19-24` (T1) |
| Define "hand-up packet" in `skills/shipping/SKILL.md` | Not started — edit-based, did not fire | same 5-file diff |
| Mechanical `scripts/validate.sh` check for `final_action` shape | **Fired** — drift-based, and its trigger is literally "first observed drift in a real progress.md `final_action`", which the row above supplies. Not acted on: `validate.sh` is outside this cycle's approved scope. Now thrice-carried | ROADMAP `final_action` shape row; live `final_action` block (T1) |
| Carry-forward check structural assertion | Not started — edit-based, did not fire | same 5-file diff |
| Plan internal clause-consistency check | In progress — fired a fourth consecutive cycle and was satisfied procedurally again: the plan review caught a Scenario coverage map citing evidence its own integration scenario cannot produce. Mechanical check still absent | `6bac7f4`; plan review P1-1 |
| Planning-time trigger audit | Done last cycle — row already removed from ROADMAP | merge `438e56b`; ROADMAP table |
| Vocabulary polish batch (U2-m1 claim layer, U3-m1 verification.md subject) | Not started — edit-based, did not fire | same 5-file diff |
| Spec-level carve-out rule | Not started — event-based, did not fire this cycle | spec has no universal-principle-versus-exception pairing |
| Pin the Python support contract in every non-fixture compatibility consumer | Not started — edit-based, and the nearest miss of this cycle. Judged **Not fired** at planning time and independently confirmed: the contract's only readers are `scripts/test-python-compatibility.sh` (which parses it) and `scripts/validate.sh` (which supplies its path); `validate-frontmatter.py` opens only its `doc_path` argument and is a registered artifact, not a consumer | `validate-frontmatter.py:184`; `test-python-compatibility.sh:8,44-53`; `validate.sh:275-276` (T4) |

- Previous doc shape: conformant

## Interview Transcript

- Independence level: heterogeneous (facilitator: GPT-family via `codex exec -s read-only`, stateless one-shot dispatches, artifacts only — no working-conversation access; the first dispatch was killed at a 10-minute timeout with an over-broad prompt and re-issued narrowed, zero content rounds lost)
- Rounds used: 3 (max 5)

| ID | Round | Phase | Probe | Answer | Evidence | Verdict (verbatim) |
|---|---|---|---|---|---|---|
| T1 | 1 | 4 | Does the live `final_action` block carry fields outside the documented 4-field schema block? Quote both. | Yes — live block adds `result:` (and carried `note:` at `determined`); documented block is `kind`/`status`/`command`/`updated` | `.release-loop/progress.md:19-24`; `progress-schema.md:27-32` | accepted: live block is "final_action: kind: merge-to-base / status: executed / command: gh pr merge 1 --merge --delete-branch / result: merged at 2026-07-26T10:03:16Z as adb310d (parents 60df670 9440f44) / updated: 2026-07-26T10:12:00Z"; documented block is "final_action: kind: merge-to-base / status: predicted / command: null / updated: <ISO-8601 timestamp>". The live-only field is result. |
| T2 | 1 | 5 | Does `scripts/validate.sh:275` resolve interpreters such that 3.8 is never invoked? | Claimed yes | `validate.sh:274-278`; `test-python-compatibility.sh:8-9,44-53` | rejected: the artifact-compilation endpoints are contract-derived 3.9 and 3.14, so the validator is not compiled with 3.8; however "NEVER invoked" is false because the compatibility script defaults BOOTSTRAP to python3, which may itself resolve to Python 3.8 and is invoked to parse the contract. |
| T3 | 1 | 5 | Is plan U1 step 1's `BASELINE` really unassigned, and does the planning skill really ban that shape? | Yes to both | `plan:123`; `skills/planning/SKILL.md:133-135` | accepted: U1 says "git show HEAD:skills/compound/scripts/validate-frontmatter.py > "$BASELINE/pre.py" into a mktemp -d directory," but BASELINE is never assigned; Step 13 bans "steps that describe what to do without showing how." |
| T4 | 1 | 4 | Is `validate-frontmatter.py` really not a reader of the Python support contract? | Correct — it opens only `doc_path` | `validate-frontmatter.py:184`; `test-python-compatibility.sh:8,44-53`; `validate.sh:275-276` | accepted: validate-frontmatter.py opens only doc_path; the contract reader is test-python-compatibility.sh, while validate.sh supplies its contract path. |
| T5 | 1 | 5 | Does `shipping` Step 7 mandate a marker the `final_action` schema has no slot for? | Yes — that is the mechanism behind the recurring drift | `skills/shipping/SKILL.md:105-107`; `progress-schema.md:27-32` | accepted: Shipping Step 7 requires the exact merge command plus "preparation evidence -- first-hand consent still required" in the durable final_action record, but its schema exposes only kind, status, command, and updated. |
| T6 | 2→3 | 5 | Is the "nearly self-fired" framing of the new ROADMAP trigger supported, or self-congratulatory? | Revised after rejection: the registering commit touches only ROADMAP.md and could not fire the row; the defect was ambiguity, since undated wording would let a reconciler match `69a1950` — which does edit the file and rides in the same merge | `239ff24` vs `9440f44`; `ROADMAP.md:61` | accepted: The revision accurately distinguishes ambiguity from a near-miss, and the date-bound wording prevents commit 69a1950 from retroactively firing the newly registered row. |
| T7 | 2→3 | 5 | Are the two exit-code misreads independently verifiable? | Revised after rejection: labelled self-reported, and the second incident corrected — the `rc=0` beside `gh pr merge` came from a trailing `tail`, not from `gh` | `.release-loop/progress.md:78,86`; no captured shell transcript exists | accepted: The corrected exit-code attribution matches the ledger, and the self-reported label properly discloses the absence of independently captured transcripts. |
| T8 | 2→3 | 5 | Is "every variable assigned in the same step" the right lesson from the `BASELINE` defect? | Revised after rejection to command closure: define or declare inputs and create prerequisites before use, verified in a clean shell with `set -u` | `plan:123`; `skills/planning/SKILL.md:133-153` | accepted: The lesson now addresses general command dataflow closure, provides a concrete clean-shell check, and correctly explains the limitation of placeholder scans. |
| T9 | 2 | 4 | Should the ambient-`python3` bootstrap in the compatibility harness be registered, and at what priority relative to `ROADMAP.md:61`? | Facilitator-originated; respondent confirmed empirically that the harness passes today under `PYTHON_BOOTSTRAP=python3.8` | `test-python-compatibility.sh:9`; `PYTHON_BOOTSTRAP=python3.8 bash scripts/test-python-compatibility.sh all` → `rc=0` | accepted: Yes—register the bootstrap interpreter as a separate P4 operational-portability item, below ROADMAP.md:61's P3 consumer-breakage risk. BOOTSTRAP runs all parsing and fixture heredocs before boundary interpreters provide protection; Python 3.8 compatibility passes today but is unguarded. Its future failure would be loud rather than silently green, which justifies the lower priority. |

Verdict cell values: `accepted` | `no evidenced answer (3 rejections): <verbatim>` | `self-attested`

## Findings

### What worked well

- **What happened**: The re-derive review mandate shipped last cycle caught a Scenario coverage map that cited structurally impossible evidence — S1, S2, and S3 were tagged to U1's *integration* scenario, but that scenario runs `bash scripts/validate.sh`, whose registered-artifact endpoints are contract-derived 3.9 and 3.14, so it never compiles or runs the validator on 3.8. The finding was verified against source by grep before being accepted, not taken on the reviewer's word.
  **Why**: A mandate to recompute from source lets a reviewer's result set contain rows the author never wrote; a verify-the-claims review would have read three plausible sentences and passed.
  **How to apply**: When a plan claims a test walks a scenario, check the test's actual execution path rather than its label — a scenario tag is an assertion about control flow, and control flow is greppable.
  **Cites**: T2; `6bac7f4`; `validate.sh:274-278`.
- **What happened**: Every success criterion was checked for discriminating power before the work started. SC2 and SC3 were dry-run against the pre-change file and returned `1` and stderr `cmp=1`, proving they could fail; SC7 was explicitly labelled an invariance guard so its pre-change pass could never be misread as evidence of the change. Both distinctions were captured in `CONCEPTS.md` as **Discriminating criterion** and **Invariance guard**.
  **Why**: A criterion that already passes before the work measures nothing, and the two kinds are only distinguishable by running them against the opposite baseline.
  **How to apply**: Dry-run every success criterion against the unmodified tree while writing the spec; record which are expected to fail and which are expected to pass, because the second kind is not weaker — it is answering a different question.
  **Cites**: T1 data (Phase 3 rows 2, 3, 7); `aa06bad`.
- **What happened**: The new ROADMAP trigger's first wording said "next edit to `validate-frontmatter.py`" with no date bound. Commit `69a1950` edits exactly that file and rides in the same merge as the row registering it, so a later reconciler could reasonably have matched the trigger to an edit already shipped alongside the registration. Amended before review to "First edit **after 2026-07-26** … and that commit does not fire it."
  **Why**: A trigger is read months later against a merge, not against the single commit that wrote it, so an undated file-condition silently includes its own cycle's edits.
  **How to apply**: Date-bound any trigger whose named file the registering cycle also touches, and say in the row that the registering cycle does not fire it.
  **Cites**: T6; `239ff24` vs `9440f44`; `ROADMAP.md:61`.

### What to improve

- **What happened**: Plan U1 step 1 wrote `> "$BASELINE/pre.py"` while defining `BASELINE` only in surrounding prose ("into a `mktemp -d` directory"). It survived the plan author's self-review — which runs a placeholder scan explicitly banning steps that describe what to do without showing how — and an independent plan review that produced six other findings. It was caught only after merge, by the automated PR reviewer.
  **Why**: The placeholder scan matches banned tokens (TBD, TODO, "as appropriate"), and a step that is prose-complete but dataflow-incomplete contains none of them. Human and model reviewers both read for intent and silently reconstruct the missing assignment.
  **How to apply**: Command closure — every command in a plan step must define or explicitly declare its inputs and create its prerequisites before use; verify by running the step in a clean shell with `set -u`. A keyword-based placeholder scan cannot catch this class.
  **Cites**: T3; T8; PR comment `3652230761`; `plan:123`.
- **What happened**: The `final_action` schema drift recurred after exactly one clean cycle. The live record carried `note:` while `determined` and `result:` once `executed`, neither in the documented four-field block — and it drifted for precisely the reason carry-forward row N-1 names: `shipping` Step 7 mandates persisting a non-authorization marker into the durable record, and the schema has no field for one, so the author invents a key. This is also the literal trigger of the separate "mechanical `validate.sh` check for `final_action` shape" row, which is now thrice-carried.
  **Why**: When a procedure requires writing something a schema has no slot for, drift is the compliant behaviour, not a lapse. The previous retro read one clean cycle as improvement; it was the absence of a ship phase reaching Step 7 with a marker to persist.
  **How to apply**: When a carry-forward row says a schema lacks a slot that a skill mandates, treat the schema gap as the defect and fix it there — counting clean cycles measures whether the mandating path ran, not whether the gap closed.
  **Cites**: T1; T5; `progress-schema.md:27-32`; `skills/shipping/SKILL.md:105-107`; previous retro line 43.
- **What happened**: *Self-reported; no captured shell transcript exists, so this finding is not independently verifiable.* Exit status was misattributed twice in the ship phase. First, `rc=$?` after a pipeline measured the trailing `tail` and reported `rc=0` for two suites that actually exit `1`. Second, `gh pr merge` printed `fatal: 'main' is already used by worktree` — its local post-merge checkout failing — while the remote merge had in fact already succeeded; the `rc=0` printed beside it again came from a trailing `tail`, not from `gh`.
  **Why**: `$?` after a pipeline without `pipefail` reports the last command's status, and a tool's local post-step failure carries no information about its remote effect. Both readings were wrong in the direction of a cleaner result.
  **How to apply**: Use `set -o pipefail` with command substitution whenever a script's exit code is the evidence; after any outward command, confirm the outcome from the remote's own state (`git ls-remote`, `gh pr view`) rather than from the command's exit code or stderr.
  **Cites**: T7; `.release-loop/progress.md:78,86`.

### Process observations

- **What happened**: Two suites are red on `main` and were red before this cycle — `scripts/test-signal-drift.sh` Case D, whose fixture pins `skills/retrospective/SKILL.md:77` to a span that line no longer contains (the line is now blank), and `scripts/test-release-publication.sh` `local_release_regression` (99 passed / 1 failed). Both were re-run in a detached worktree at base `60df670` and reproduced identically, which is what separated "pre-existing" from "introduced" before the merge proceeded. They are documented in the PR body and remain unowned.
  **Why**: A fixture that pins a line number in a file it does not own decays whenever that file is edited; nothing links the two.
  **How to apply**: Prove pre-existing failures by re-running at the merge base rather than reasoning from the diff's file list, and register them — a failure documented only in a PR body disappears when the PR is merged.
  **Cites**: base-versus-branch reproduction; PR #1 body "Pre-existing test failures" section.
- **What happened**: The previous retro's own Compounding line records that its frontmatter validation had to be rerun on 3.9 because the ambient `python3` was 3.8 and reproduced the `list[str]` traceback. That caveat is spec scenario S3, and this cycle removed the need for it — this retro's validation ran on the ambient interpreter without qualification.
  **Why**: The retro process was itself a user of the broken tool, so the defect appeared as a recurring footnote in the artifacts rather than as a bug report.
  **How to apply**: Treat a caveat that reappears verbatim across retro documents as a defect report; the repetition is the signal.
  **Cites**: previous retro line 120; Phase 3 criterion 1.
- **What happened**: The facilitator rejected three of the respondent's six probed findings in one round — an overstated "nearly self-fired" claim, an unverifiable incident presented as established, and a lesson generalised too narrowly — and separately originated a carry-forward item the respondent had not found. All three were revised and accepted on the next round.
  **Why**: The respondent grades work it performed, and the systematic bias is toward claims slightly stronger than the evidence carries; an adversarial reader with artifact-only access has no such incentive.
  **How to apply**: Give the facilitator a standing instruction to nominate findings the draft omits, not only to judge the ones it contains — the omission here (the ambient bootstrap interpreter) was the highest-value item of the round.
  **Cites**: T6; T7; T8; T9.

## Carry-forward items registered

| Item | Type | Priority | Tracked at |
|---|---|---|---|
| `scripts/test-python-compatibility.sh` runs all its parsing and fixture heredocs on `BOOTSTRAP="${PYTHON_BOOTSTRAP:-python3}"` — the ambient interpreter, resolved before any boundary interpreter provides protection. It passes today under `PYTHON_BOOTSTRAP=python3.8`, but nothing declares or gates that; a 3.9-only construct in any heredoc would break `validate.sh` outright on a 3.8-ambient machine | process | P4 | ROADMAP.md "Carry-forward from retros" |
| Add a marker/note slot to the `final_action` schema block so `shipping` Step 7's mandated non-authorization marker has a data-level home — the drift recurred this cycle for exactly this reason, and counting clean cycles hid it | process | P3 | ROADMAP.md "Carry-forward from retros" (folds into the existing N-1 row) |
| Command-closure check for plan steps: every command defines or declares its inputs and creates its prerequisites before use, verifiable in a clean shell with `set -u`; the existing placeholder scan is keyword-based and structurally cannot catch this | process | P3 | ROADMAP.md "Carry-forward from retros" |
| Own the two pre-existing red suites: `test-signal-drift.sh` Case D's fixture pins `skills/retrospective/SKILL.md:77`, which no longer holds the expected span, and `test-release-publication.sh` `local_release_regression` fails its `48eccb0` byte comparison | edge-case | P2 | ROADMAP.md "Carry-forward from retros" |

## Lessons

- A schema gap turns compliance into drift: when a skill mandates writing something the schema has no field for, inventing a key is the *correct* local behaviour, and counting clean cycles measures whether the mandating path ran — not whether the gap closed.
- A placeholder scan cannot catch a step that is prose-complete but dataflow-incomplete; `$BASELINE` was never assigned, and both a self-review whose explicit job is banning under-specified steps and an independent review that found six other defects reconstructed the missing assignment mentally and read past it.
- An undated file-condition trigger silently includes its own registering cycle's edits, because a reconciler reads the row against a merge rather than against the commit that wrote it.

## Compounding

- compound invocation: `Documentation complete — docs/solutions/workflow-issues/mandated-field-absent-from-schema.md` (the schema-gap finding; frontmatter validated exit 0 on both the ambient interpreter and CPython 3.8 — the first time the 3.8 run was possible, which is this cycle's own deliverable closing its own loop. Overlap **Moderate** with `universal-invariant-scope-enumeration-gap.md`: shared subsystem and the same "compliance produced the defect" shape, but a different cause and fix — cross-referenced in the new doc rather than merged. Phase 1 ran at the **single-call fallback** tier, not native parallel: the harness forbids unrequested subagents, so the Context Analyzer, Solution Extractor, and Related Docs Finder roles were executed in one orchestrator pass. CONCEPTS.md scanned; one term added — **Unexercised-path observation**, in the Carry-forward triggers section, the concept the facilitator's rejection of the "clean cycle" reading sharpened. Discoverability met without an edit: this repo has no `AGENTS.md`/`CLAUDE.md`, and README.md:11 plus seven skills already point at `docs/solutions/` and `CONCEPTS.md`. Refresh not invoked — headless never invokes it; scope hint for a later `compound-refresh`: the `workflow-issues` category now holds two docs on compliance-produced defects in the release-loop subsystem, worth checking for consolidation.)
