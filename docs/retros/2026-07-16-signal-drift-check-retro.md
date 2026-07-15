# Retro: signal-drift-check

- Date: 2026-07-16
- Source: local merge, commit `c6b72db` (no PR — no git remote on this repo)
- Spec: docs/specs/2026-07-16-signal-drift-check-design.md
- Plan: docs/plans/2026-07-16-001-feat-signal-drift-check-plan.md

## Release data

| Metric | Value |
|---|---|
| Code delta (product / test / docs) | +94/-0 / +218/-0 / +245/-0 |
| Commits | 6 feature commits + 1 merge commit |
| Review rounds | 1 |
| Comments (fixed / deferred) | n/a — no PR opened (no git remote on this repo; ship landed preparation-only, then the human merged locally) |
| CI failures | n/a — no CI configured or triggered (no remote) |
| Duration (first spec commit → merge) | ~55 minutes (single continuous session, well under 1 day) |
| Units planned / completed | 2 / 2 |

## Success criteria: measured vs declared

Measured fresh during this retro (not reused from Ship phase's own run), per `bash scripts/validate.sh` and `bash scripts/test-signal-drift.sh` executed on the merged `main` at commit `c6b72db`.

| # | Declared criterion | Measurement (command / rubric) | Measured result | Verdict |
|---|---|---|---|---|
| 1 | `scripts/validate.sh` run against the current, unmodified repo passes and includes the new check's `ok:` line | `bash scripts/validate.sh` → exit 0, contains `ok:   terminal signal lines match schemas/headless-contract.md`, ends `ALL CHECKS PASSED` | Exit 0; `ok:` line present, verbatim; `ALL CHECKS PASSED` present | Met |
| 2 | A one-byte mutation to a quoted signal line in `skills/compound/SKILL.md` makes `validate.sh` fail, naming the file and line | Case B fixture — nonzero exit, output contains `skills/compound/SKILL.md` and the mutated line's number | `bash scripts/test-signal-drift.sh` → Case B: pass (nonzero exit; `skills/compound/SKILL.md:77` named) | Met |
| 3 | Same mutation pattern against `skills/compound-refresh/SKILL.md` and `skills/retrospective/SKILL.md` (incl. a cross-quoted `compound` line) independently caught | Case C, Case D fixtures — nonzero exit, correct file/line in each | Case C: pass (`skills/compound-refresh/SKILL.md:77`); Case D: pass (`skills/retrospective/SKILL.md:77`, correctly attributed to producer `compound`, not `retrospective`) | Met |
| 4 | Missing/malformed `headless-contract.md` or missing consumer file produces a named `fail:` line, not a traceback | Case E, Case G fixtures — nonzero exit, no traceback, `fail:` line naming the file | Case E: pass; Case G: pass. **Gap noted**: both cases are also independently caught by pre-existing `validate.sh` checks 2/3, unrelated to this feature — a `[signal-drift]` tag was added to the new check's own `FAIL:` lines so these cases prove the *new* check's graceful handling specifically, not a coincidental catch. Not foreseen at Design time; found and fixed during Implement (see Findings) | Met (declared behavior confirmed; the fixture's original wording, "assert a named fail: line," did not by itself distinguish which check produced it — corrected) |
| 5 | Deleting a quoted signal line entirely is still caught by the coverage pass, naming the uncovered canonical line | Case F fixture — nonzero exit, names the specific uncovered producer/state line | Pass — but **not against the spec's literal target**. The spec named `skills/compound/SKILL.md`'s `Documentation skipped` clause; that exact line is cross-quoted a second time in `skills/retrospective/SKILL.md`'s Phase 7 section, so deleting only the `compound/SKILL.md` copy never triggers the coverage pass (verified: it doesn't). The fixture was retargeted to `compound-refresh`'s single-occurrence `Refresh skipped` line, which does genuinely exercise the mechanism (verified: `producer 'compound-refresh' state 'skipped'` reported) | Met (mechanism proven; the spec's own illustrative file choice was wrong — see Findings) |

(Spec exists and was used in full; no criteria skipped.)

## Carry-forward from previous retro

No previous retro exists — `docs/retros/` was empty before this doc (verified via `ls -la docs/retros/`). This is the first retro to complete for this repo/pipeline (an earlier pilot died before reaching Design). Nothing to reconcile this cycle; this retro's own carry-forward items (below) become the baseline the next retro must check.

## Findings

### What worked well

- **What happened**: Running `scripts/test-signal-drift.sh` before implementing check 6 (Implement/U1, commit `89814a8`) showed all 7 cases failing — and that red run itself revealed Cases E/G were coincidentally masked by pre-existing `validate.sh` checks 2/3, a fixture-design defect that was only visible because the red state was actually executed, not assumed.
  **Why**: Test-first discipline (P1) combined with fresh-verification discipline (P3) turned an assumed-correct fixture into an empirically-checked one.
  **How to apply**: Keep treating "watch it fail for the right reason" as a literal, evidence-producing step — every substantive catch in this pilot (this one, the Case F cross-quote, the plan's wrong keyword-mutation guidance) came from running a command, never from re-reading text more carefully.

- **What happened**: The successor agent that drove Plan through Ship had zero conversation context from the Design-phase agent and rebuilt state entirely from `.release-loop/progress.md` plus `git log`, finding the `spec`/`plan` pointers exactly consistent with git evidence — no rebuild-from-git-evidence fallback was needed (contrast an earlier pilot that died silently with no `progress.md` on disk at all).
  **Why**: The Design-phase agent left a complete, evidence-cited log (each entry names a command and its result) before handing off, satisfying the plugin's own P8 principle.
  **How to apply**: The ledger-first, evidence-per-entry discipline this pilot followed should be the template for future multi-agent handoffs — it was directly load-bearing for this specific successful cold takeover.

- **What happened**: Design-phase's independent review (`codex exec -s read-only`) caught a real architectural gap (missing coverage pass for deleted signal lines) before implementation began; separately, this retro's own facilitator pass (also `codex exec -s read-only`) caught a metric-consistency issue in the ledger — two different diff-size figures ("115-line, 2-unit diff" at Implement vs. "94 new non-test lines" at Review) cited for two different purposes without being reconciled — that the respondent hadn't noticed.
  **Why**: A heterogeneous-model, fresh-context reviewer structurally surfaces categories of gaps that same-agent self-review cannot, because self-review shares the blind spots of whoever wrote the thing being reviewed.
  **How to apply**: Keep independent review non-negotiable at both Design and Retro — this pilot has two separate, concrete instances of it finding something self-review missed.

### What to improve

- **What happened**: The approved spec named `skills/compound/SKILL.md` as Case F's coverage-pass example and implied Cases E/G would fail simply because the new check didn't exist yet. Both claims were false against the live repo: `Documentation skipped` is cross-quoted a second time in `retrospective/SKILL.md`, and Cases E/G were already independently caught by pre-existing checks 2/3. Both defects were caught only during Implement (`.release-loop/progress.md`, Implement log entries), not at Design review time, even though each is falsifiable with a single command (`grep` for the cross-quote; `bash scripts/validate.sh` with the mutation applied, against the pre-feature script).
  **Why**: Design's independent review verified the spec's *internal logic* (does the proposed regex match the spec's own worked example, is the architecture coherent) but never executed anything against the *live repository* to check whether the spec's own illustrative examples still held. Internal-consistency review and empirical-grounding review are different checks; neither substitutes for the other.
  **How to apply**: `designing`'s independent-review step should add an explicit sub-step — for any Testing/Scenario-section example naming a specific existing file/line, run the cheapest possible command to confirm it's still true against live content, before treating the illustration as settled. Documented as a reusable finding: `docs/solutions/workflow-issues/spec-review-empirical-grounding-gap.md` (see Compounding, below).

- **What happened**: The plan's own text correctly instructed mutating a placeholder (e.g. `<path>`), not the leading keyword, for Cases B/C/D — but the harness as first written mutated the keyword itself ("complete" → "complet"), silently breaking candidate detection instead of producing the intended byte-mismatch failure. Caught only after wiring the mutation into working code and running it (Implement/U2, commit `79cdd1c`'s follow-up fix), not by re-reading the plan's own already-correct guidance.
  **Why**: No step in `implementing`'s per-unit loop requires a literal re-read-back of the plan's precise wording against just-written code before running it — a correct plan doesn't guarantee implementation fidelity to it.
  **How to apply**: For units with a precise literal requirement (an exact byte-offset target, specific placeholder text), add a one-line self-check immediately after writing the code: does this match the plan's literal instruction, word for word — cheap insurance against silent drift from an already-correct plan.

- **What happened**: Ledger entries cited two different diff-size metrics for two different purposes without reconciling them — "115-line, 2-unit diff" (Implement, describing overall scope) vs. "94 new non-test lines in `scripts/validate.sh`" (Review, the adversarial lane's own trigger threshold) — both individually accurate, never cross-checked against each other. (Caught by this retro's own facilitator pass, not the respondent.)
  **Why**: No single canonical diff-size metric is defined anywhere in the release-loop protocol for cross-phase citation; each phase computed whatever number served its immediate purpose.
  **How to apply**: When citing diff size across phases for a scaling or lane-trigger decision, name the metric explicitly every time (e.g. "94 non-test lines added to `scripts/validate.sh`, per the adversarial lane's own trigger definition") rather than switching between an intuitive total and a lane-specific count without saying so.

### Process observations

- **What happened**: `main` relayed "human approved, merge locally" and the agent's own `git merge --no-ff` attempt into `main` was denied by the harness's own permission classifier, with the explicit stated reason that a teammate-relayed message doesn't establish genuine user intent for a protected-branch merge. The merge only succeeded once the actual human user performed it directly (merge commit `c6b72db`, `Author: Jaehoon You`). By contrast, this same session's Design gate — also approved via a `main`-relayed message — was *not* blocked, because its action (flipping spec frontmatter, committing to a feature branch) is local and reversible.
  **Why**: The harness's classifier appears to gate on the *action's own risk classification* (protected-branch merge/push = blocked regardless of relay; local feature-branch commit = not blocked), not uniformly on relay-vs-direct for every USER gate — but `release-loop`'s protocol text doesn't currently distinguish these two cases, so a phase-driving agent cannot predict in advance which gate's relayed approval will or won't be honored.
  **How to apply**: `release-loop`'s Ship-phase (and any USER-gated) merge/push step should not assume a relayed "approved" message is sufficient authorization to execute the action itself — either the actual end user performs the action directly, or the phase agent hands the exact command to the user to run themselves. This is a protocol-level gap, not a bug in this feature; registered as a carry-forward item below.

- **What happened**: This entire six-phase loop (Design through Retro) was driven by a single agent with no subagent dispatch at any phase — the same agent wrote the spec, planned it, implemented both units inline, ran all 5 review lanes serially in one pass, and drove Ship/Retro, citing `dispatch-degradation.md`'s Tier 3 "single-call fallback" and `implementing`'s "Inline: 1-2 units" strategy each time.
  **Why**: The feature was small enough (2 units, 1 file's worth of core logic) that inline execution was defensible per the plugin's own sizing guidance.
  **How to apply**: This pilot validates the single-agent degradation floor, not the plugin's higher dispatch tiers (parallel subagent review lanes, per-unit reviewer dispatch, parallel implementation units). A future pilot on a larger feature (5+ units, or one that legitimately triggers 2+ conditional review lanes) is needed to exercise those paths — this retro cannot speak to them.

- **What happened**: `docs/retros/` was empty before this doc (verified via `ls -la`) — this is the first retro to complete for this repo/pipeline (an earlier pilot died before reaching Design).
  **Why**: Pilot run sequencing — this is run #2 (of the pilots that reached this far), the first to complete the full loop.
  **How to apply**: This retro's carry-forward items become the baseline the *next* retro must reconcile against; the carry-forward discipline only starts paying off from the second full cycle onward.

## Carry-forward items registered

No issue tracker or ROADMAP exists in this repo yet, so these are tracked in this retro doc itself (a durable, git-committed file) rather than PR comments — a real tracker is itself a gap worth naming, not assumed.

| Item | Type | Priority | Tracked at |
|---|---|---|---|
| `release-loop`'s Ship-phase (and any USER-gated) merge/push step must not assume a relayed "approved" message is sufficient authorization — document the direct-user-action requirement explicitly in the skill text | process | P1 | this retro doc (no issue tracker exists) |
| `designing`'s independent-review step should add an explicit empirical-grounding sub-step (grep / dry-run against live repo content) for any Testing-section example naming a specific existing file or line | process | P2 | this retro doc; also `docs/solutions/workflow-issues/spec-review-empirical-grounding-gap.md` |
| Run a second pilot on a larger feature (5+ units, or one triggering 2+ conditional review lanes) to validate the multi-agent dispatch tiers this pilot never exercised (Tier 1/2 dispatch, parallel review lanes, per-unit reviewer subagents) | process | P2 | this retro doc |
| Reconcile diff-size metrics cited across phases (total diff vs. per-file non-test-line counts) to one named metric per citation | process | P3 | this retro doc |

## Lessons

- Two independent full spec reviews (an LLM-driven independent review plus the author's own self-review) both missed the same two fixture-example defects that a single `grep` or a single dry run would have caught — internal-logic review and empirical-grounding review are different checks, and neither substitutes for the other.
- A relayed "the human approved this" message authorized a local commit but not a protected-branch merge in the same session — the harness's consent boundary is scoped to the action's own risk, not to which gate emitted the message.
- The plan correctly said "mutate the placeholder, not the keyword" — the harness that got written mutated the keyword anyway. A correct plan doesn't guarantee implementation fidelity without a literal re-read-back check.

## Compounding

- compound invocation: `Documentation complete — docs/solutions/workflow-issues/spec-review-empirical-grounding-gap.md`
