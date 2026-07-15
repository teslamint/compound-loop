---
schema: plan/v1
title: Terminal-Signal Drift Check
type: feat
status: draft
date: 2026-07-16
execution: code
origin: docs/specs/2026-07-16-signal-drift-check-design.md
---

# Terminal-Signal Drift Check Plan

## Goal

Add a sixth check to `scripts/validate.sh` that fails when a backtick-quoted
terminal-signal line inside `skills/compound/SKILL.md`,
`skills/compound-refresh/SKILL.md`, or `skills/retrospective/SKILL.md` no
longer byte-matches the canonical lines in `schemas/headless-contract.md`, and
that also fails when any canonical line is quoted nowhere at all. Prove the
check red-then-green with a disposable fixture harness that never mutates the
real skill files.

## Architecture notes

- **Canonical-line source of truth**: `schemas/headless-contract.md`'s table
  has four rows (`compound`, `compound-refresh`, `retrospective`, `reviewing`).
  Only the first three carry pure backtick-wrapped Success/Skipped/Failure
  cells; `reviewing`'s row is prose (JSON envelope description) and must be
  skipped by name, not swept in by "parse every row". Parsing targets exactly
  those three row names and nothing else.
- **Canonical string extraction**: for each of the three rows, strip the
  single enclosing backticks from the Success, Skipped/no-op, and Failure
  cells to get 3 exact strings (9 total). Fail loudly — a named `FAIL:` line,
  not a traceback — if this doesn't yield exactly 9 non-empty, pairwise-distinct
  strings, or if `schemas/headless-contract.md` is missing/unreadable.
- **Candidate detection**: scan each of the three consumer files for inline
  code spans `` `([^`]+)` `` whose content matches, case-insensitively (so a
  case-drift is still flagged as a candidate rather than silently skipped),
  `^(Documentation|Refresh|Retrospective)\s+(complete|skipped|failed)\b`. A
  missing/unreadable consumer file is a named `FAIL:` line, not a crash.
- **Byte-compare**: compare each candidate span's exact text (case-sensitive)
  against the 9 canonical strings. A match marks that canonical string "seen".
  No match records a `FAIL:` naming the file, the 1-based line number
  (`text.count('\n', 0, offset) + 1` from the span's character offset), the
  actual text found, and the full Success/Skipped/Failure triplet of the
  producer guessed from the candidate's own first word (case-insensitive) —
  this is direction-agnostic: whether the drift originated from an edit to
  `headless-contract.md` (spec S1) or a direct edit to the consumer file
  (spec S2), the observable symptom is identical, so one mechanism covers both.
- **Coverage pass**: after all three files are scanned, any of the 9 canonical
  strings never marked "seen" is its own `FAIL:` naming the producer/state and
  stating no consumer file quotes it. This is the only mechanism that catches
  a deleted signal line (spec S3), since step above only evaluates spans that
  exist.
- **Report line**: emit exactly `ok:   terminal signal lines match
  schemas/headless-contract.md` (the literal string from the spec's Success
  Criterion 1) when zero mismatch failures and zero uncovered-canonical
  failures occurred. Otherwise emit every failure found (no early exit) and
  let it flow into the script's existing `FAIL=1` / exit-1 handling, matching
  the `python3 - <<'PY' ... PY || FAIL=1` convention already used by checks 3-5.
- **Known existing candidates** (verified in the current repo, useful for
  fixture design): `skills/compound/SKILL.md:77` holds all three of
  `compound`'s canonical spans on one line; `skills/compound-refresh/SKILL.md:77`
  holds `compound-refresh`'s three; `skills/retrospective/SKILL.md:77` holds a
  **cross-quote** of `compound`'s three spans (Phase 7 section), and line 84
  holds `retrospective`'s own three. A mutation to `retrospective/SKILL.md:77`
  must be checked against `compound`'s canonical triplet, not `retrospective`'s
  — the producer guess comes from the candidate's own first word, never from
  which file it lives in.

## File structure

- Modify: `scripts/validate.sh` — append check "6." following the existing
  `python3 - "$ROOT" <<'PY' ... PY || FAIL=1` style used by checks 3-5.
- Create: `scripts/test-signal-drift.sh` — standalone fixture harness, not
  wired into `validate.sh` or any CI (per spec, invoked manually).

## Scenario coverage map

| S-ID | Scenario | Unit chain | Test evidence |
|---|---|---|---|
| S1 | Contributor edits `headless-contract.md` wording, forgets a consumer file | U1 → U2 | Case B/C/D in `scripts/test-signal-drift.sh` (mismatch detection is direction-agnostic: the same byte-compare mechanism catches drift regardless of which side changed) |
| S2 | Contributor edits a SKILL.md's quoted line directly, drops a character | U1 → U2 | Case B (compound), Case D (retrospective, cross-quoted `compound` line) |
| S3 | Contributor deletes a quoted signal line entirely | U1 → U2 | Case F (coverage pass fires with no malformed candidate present) |
| S4 | CI/pre-merge runs `validate.sh` on an unmodified repo | U1 → U2 | Case A (fixture) + a direct `bash scripts/validate.sh` run against the real repo in U2 step 8 |

## Implementation Units

## U1: Fixture test harness (Cases A-G)
Execution note: skip-test-first
Files:
  Create: scripts/test-signal-drift.sh
Interfaces:
  Consumes: `scripts/validate.sh` (invoked, unmodified — check 6 does not exist yet at this unit's end)
  Produces: an executable script that, for each of 7 named cases, copies the current worktree into a fresh `mktemp -d` directory (excluding `.git`), applies exactly one mutation (or none, for Case A), runs `bash scripts/validate.sh` from the copy, asserts on exit code and grepped output, prints a pass/fail line per case, and removes the temp directory afterward — never touches the real `skills/` or `schemas/` files.
Test scenarios:
  happy: Case A — no mutation; assert the harness's own copy/cleanup mechanics work (temp dir created, populated, removed) regardless of what `validate.sh` currently reports.
  edge: cleanup (`rm -rf` the temp dir) still runs even when a case's assertion fails, so a failing run doesn't leak temp directories — verify by checking the temp dir is gone after an intentionally-failing case.
  error: `mktemp -d` failure (simulate by pointing `TMPDIR` at a non-writable path) is reported as a harness error, not a silent pass.
  integration: running all 7 cases end to end via `bash scripts/test-signal-drift.sh` in one invocation — Covers S1, S2, S3, S4 by construction (each case fixture instantiates one of those scenarios; U2 is what makes the assertions pass).
Steps:
  1. Write `scripts/test-signal-drift.sh` with a `run_case(name)`-style helper that: creates a `mktemp -d`, copies the worktree into it (e.g. `git ls-files` piped to `cpio`/`tar`, or `rsync --exclude=.git`, or plain `cp -r` skipping `.git` — any mechanism that excludes `.git` and is idempotent), `cd`s into the copy, and always removes the copy on exit via `trap ... EXIT`.
  2. Implement Case A: no mutation applied; assert `bash scripts/validate.sh` output contains the literal line `ok:   terminal signal lines match schemas/headless-contract.md`. Run it now — confirm it fails (the line is absent because check 6 doesn't exist yet). This is the expected red state.
  3. Implement Case B: in the copy, mutate one byte inside one of the three backtick-quoted spans on `skills/compound/SKILL.md:77` (e.g. drop one character from the `<path>` placeholder in the Success span), leaving line count unchanged. Assert nonzero exit and output containing both `skills/compound/SKILL.md` and `77`. Run it now — confirm it fails because `validate.sh` still reports `ALL CHECKS PASSED` (check 6 absent), not because of a harness bug.
  4. Implement Case C: same mutation pattern against `skills/compound-refresh/SKILL.md:77`. Assert nonzero exit and output containing `skills/compound-refresh/SKILL.md` and `77`. Run it now — confirm same red state as Case B.
  5. Implement Case D: same mutation pattern against `skills/retrospective/SKILL.md:77` — this is the cross-quoted `compound` triplet inside retrospective's Phase 7 section, not retrospective's own lines (those are at line 84). Assert nonzero exit, output containing `skills/retrospective/SKILL.md` and `77`, AND that the reported canonical triplet mentions `compound`'s wording (not `retrospective`'s) — confirms the guess comes from the candidate's own first word, not the file it's found in. Run it now — confirm red state.
  6. Implement Case E: in the copy, truncate `schemas/headless-contract.md` to empty. Assert nonzero exit, output containing `FAIL:` and `schemas/headless-contract.md`, and output NOT containing `Traceback` (no Python traceback). Run it now — confirm it currently fails (the file is genuinely used by nothing yet — validate.sh reports `ALL CHECKS PASSED` unchanged, since check 6 doesn't exist, so today's actual failure is "no FAIL: line was produced at all" — the right kind of red).
  7. Implement Case F: in the copy, remove the entire `` `Documentation skipped — <reason>` `` backtick span (the whole clause containing it) from `skills/compound/SKILL.md:77`, keeping the Success and Failure spans intact on that line. Assert nonzero exit and output containing both `Documentation` and `skipped` (naming the uncovered canonical line). Run it now — confirm it fails because nothing today detects a deleted-with-no-malformed-remnant line (`validate.sh` still reports `ALL CHECKS PASSED`).
  8. Implement Case G: in the copy, delete `skills/retrospective/SKILL.md` entirely. Assert nonzero exit, output containing `FAIL:` and `skills/retrospective/SKILL.md`, and no `Traceback`. Run it now — confirm current red state.
  9. Make the script executable (`chmod +x scripts/test-signal-drift.sh`) and confirm running it prints a clear pass/fail summary line per case (A through G) plus an overall exit code (0 only if all 7 assertions hold).
  10. Commit: "Add fixture harness for terminal-signal drift check (red — check 6 not yet implemented)"
Acceptance: `bash scripts/test-signal-drift.sh` runs to completion without hanging or crashing; its output shows Case A failing only on the missing `ok:` line, and Cases B/C/D/E/F/G each failing specifically because `validate.sh` reports `ALL CHECKS PASSED` (or, for E/G, produces no relevant `FAIL:` line) rather than any harness-internal error — i.e., every case's failure is traceable to "check 6 doesn't exist," never to a bug in the harness itself.

## U2: Terminal-signal drift check (validate.sh check 6)
Execution note: test-first
Files:
  Modify: scripts/validate.sh
  Test: scripts/test-signal-drift.sh (from U1, unmodified in this unit)
Interfaces:
  Consumes: `schemas/headless-contract.md` (table format documented in Architecture notes above), `skills/compound/SKILL.md`, `skills/compound-refresh/SKILL.md`, `skills/retrospective/SKILL.md` (read-only)
  Produces: a 6th check block in `scripts/validate.sh` that prints exactly one `ok:   terminal signal lines match schemas/headless-contract.md` line on a clean repo, or one or more `FAIL:` lines (mismatch and/or uncovered-canonical and/or malformed-input) on a corrupted one, contributing to the script's existing `FAIL` flag and final exit code.
Test scenarios:
  happy: Case A (clean repo) → `ok:` line present, exit 0. Covers S4.
  edge: Case F (signal line deleted entirely, no malformed candidate remains) → coverage pass fires, names the uncovered canonical line. Covers S3.
  error: Case E (malformed/empty `headless-contract.md`) and Case G (missing consumer file) → named `FAIL:` line, no Python traceback, nonzero exit.
  integration: Case B, C, D (byte-level drift in each of the three consumer files, including the cross-quoted `compound` line inside `retrospective/SKILL.md`) → each independently names its own file, line, and correct producer triplet. Covers S1, S2.
Steps:
  1. Run `bash scripts/test-signal-drift.sh` now (before touching `validate.sh`) and confirm every case fails for the reason recorded in U1 (check 6 absent) — this is the explicit "watch it fail for the right reason" checkpoint before writing the fix.
  2. In `scripts/validate.sh`, append check "6." as a new `python3 - "$ROOT" <<'PY' ... PY || FAIL=1` block (matching checks 3-5's style). Parse `schemas/headless-contract.md`: locate the table rows named exactly `compound`, `compound-refresh`, `retrospective` (skip the `reviewing` row); for each, strip the enclosing single backticks from its Success, Skipped/no-op, and Failure cells. If this does not yield exactly 9 non-empty, pairwise-distinct strings, or the file is missing/unreadable, print a `FAIL:` line naming `schemas/headless-contract.md` and the specific problem (missing / unreadable / wrong count / duplicate strings), and skip the remaining steps below for this check (no traceback).
  3. For each of the three consumer files (`skills/compound/SKILL.md`, `skills/compound-refresh/SKILL.md`, `skills/retrospective/SKILL.md`): if the file is missing or unreadable, print a `FAIL:` line naming it and continue to the next file (no crash). Otherwise regex-scan for inline code spans `` `([^`]+)` `` whose content matches, case-insensitively, `^(Documentation|Refresh|Retrospective)\s+(complete|skipped|failed)\b`.
  4. For each candidate span found in step 3: compute its 1-based line number via `text.count('\n', 0, offset) + 1`. Compare the span's exact text (case-sensitive) against the 9 canonical strings from step 2. On exact match, mark that canonical string "seen". On no match, print a `FAIL:` line naming the file, the line number, the actual text found, and the full Success/Skipped/Failure triplet of the producer whose name matches the candidate's own leading word (case-insensitively) — not the file's "home" producer.
  5. After all three files are scanned: for each of the 9 canonical strings never marked "seen" in step 4, print a `FAIL:` line naming its producer, its state (Success/Skipped/Failure), and the canonical text, stating no consumer file quotes it.
  6. If steps 2-5 produced zero `FAIL:` lines for this check, print `ok:   terminal signal lines match schemas/headless-contract.md`. Confirm the block's exit code contributes to the script's existing `FAIL=1` handling exactly like checks 3-5 (via `|| FAIL=1` on the heredoc invocation).
  7. Run `bash scripts/test-signal-drift.sh` again. Confirm Case A now passes (the `ok:` line is present) and confirm Cases B, C, D, E, F, G now fail *for the case-specific reason* their assertions check (correct file+line+triplet named, or correct uncovered-canonical name, or correct graceful `FAIL:` with no traceback) — not for any other reason.
  8. Run `bash scripts/validate.sh` directly against the real, unmodified worktree (no fixture copy). Confirm exit 0, the new `ok:` line present, and the trailing `ALL CHECKS PASSED` — this is Success Criterion 1 verified against the actual repo.
  9. Commit: "Add terminal-signal drift check (6.) to scripts/validate.sh"
Acceptance: `bash scripts/test-signal-drift.sh` exits 0 (all 7 cases pass); `bash scripts/validate.sh` run directly against the real repo exits 0, prints `ok:   terminal signal lines match schemas/headless-contract.md`, and ends with `ALL CHECKS PASSED` — together these satisfy spec Success Criteria 1-5.

## Deferred to Follow-Up Work

- Extending the producer-keyword regex list (`Documentation|Refresh|Retrospective`) when a 4th headless-contract producer is added later — owner is whoever adds that producer (spec Risks).
- Auto-fixing detected drift — spec scope is detection-only, consistent with checks 1-5.
- Validating or bumping `schemas/headless-contract.md`'s own contract version number — separate concern from line-level drift (spec Scope/Out).
- Wiring `scripts/test-signal-drift.sh` into any CI pipeline — spec explicitly keeps it a manually-invoked, standalone script, not part of `validate.sh` or CI, in this repo.

## Open unknowns

**Planning-time** (none blocking): the spec fully specifies parsing, matching, and coverage semantics; nothing here required a decision before this plan could be finalized.

**Implementation-time**:
- Exact `FAIL:` message phrasing beyond the fixed `ok:` line text is cosmetic (spec Open Decisions, owner: this unit's implementer) — the wording only needs to name the file/line/text/triplet or producer/state as specified in Steps above, not match an exact string.
- Exact mechanism for copying the worktree into the `mktemp -d` directory in U1 (`cp -r` with `.git` excluded, `rsync`, or `git ls-files | cpio`) is an implementation choice; any of them satisfies "excludes `.git`, doesn't mutate the real tree."
