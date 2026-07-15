---
title: Terminal-Signal Drift Check
status: approved
date: 2026-07-16
schema: spec/v1
---

# Terminal-Signal Drift Check Design

_Created 2026-07-16._

## Overview

`scripts/validate.sh` currently checks manifests, schemas, skill frontmatter, and `PRINCIPLES.md` structure, but nothing checks that the headless terminal signal lines quoted inside `skills/retrospective/SKILL.md`, `skills/compound/SKILL.md`, and `skills/compound-refresh/SKILL.md` still byte-match the canonical lines defined once in `schemas/headless-contract.md`. A wording edit in either place (a dropped placeholder, a hyphen swapped for an em dash, a case change) silently breaks the cross-skill contract `headless-contract.md` exists to prevent, and nothing catches it today. This adds a sixth check to `scripts/validate.sh` that catches that drift.

## User Scenarios

### S1: A contributor edits `headless-contract.md`'s wording but forgets the consumer files
A contributor tightens the wording of `compound`'s failure line in `schemas/headless-contract.md` and runs `bash scripts/validate.sh` before committing. The new check reads the updated table, finds `skills/compound/SKILL.md`'s quoted copy of the old wording no longer matches, and fails, naming the file and line so the contributor knows exactly what to fix.

### S2: A contributor edits a SKILL.md's quoted signal line directly
While editing `skills/retrospective/SKILL.md`'s prose, a contributor rewords the sentence around `` `Retrospective failed — <reason>` `` and accidentally drops a character from the placeholder ("`<reasn>`"). `scripts/validate.sh` fails, pointing at `skills/retrospective/SKILL.md` and the line number, rather than the drift surfacing later as a caller that fails to recognize its own producer's terminal signal.

### S3: A contributor deletes a quoted signal line entirely
A contributor rewrites the Terminal Signals paragraph in `skills/compound/SKILL.md` and drops the `` `Documentation skipped — <reason>` `` clause altogether while keeping the other two. Because there is no longer any candidate span to byte-compare, a check that only validates *found* candidates would report clean. The coverage rule in Architecture step 4 catches this: `schemas/headless-contract.md`'s 9 canonical lines must each appear, byte-identical, at least once somewhere across the three consumer files — the missing line is reported by name.

### S4: CI / pre-merge gate runs validate.sh on an unmodified repo
`shipping`'s preflight (or a contributor's habitual `bash scripts/validate.sh` before a commit) runs the full suite including the new check. On the current, uncorrupted repo it reports `ok:` and contributes to the overall `ALL CHECKS PASSED` line, adding no noise to a clean run.

## Scope

### In
- One new numbered check ("6.") appended to `scripts/validate.sh`, following the existing `fail()`/`ok()` + `python3 - <<'PY'` convention already used by checks 1-5.
- Parses `schemas/headless-contract.md`'s terminal-signal-lines table to build the canonical set: 3 producers (`compound`, `compound-refresh`, `retrospective`) × 3 states (Success, Skipped/no-op, Failure) = 9 exact strings.
- Scans exactly `skills/compound/SKILL.md`, `skills/compound-refresh/SKILL.md`, and `skills/retrospective/SKILL.md` for backtick-quoted spans matching the shape `<Producer-word> <state-word>...` (see Architecture) — cross-file quotes count (e.g. `retrospective/SKILL.md` quoting `compound`'s lines in its Phase 7 section is checked against `compound`'s canonical lines, not rejected as out-of-place).
- On any quoted candidate span that doesn't byte-match one of the 9 canonical strings: fail, naming the offending file, its line number, the actual text found, and the canonical Success/Skipped/Failure triplet for that producer.
- **Coverage, not just candidate correctness**: each of the 9 canonical lines must appear, byte-identical, at least once somewhere across the three consumer files combined. A line quoted nowhere (deleted, or silently replaced by a duplicate of another canonical line) fails by name even though no *malformed* candidate was found — this is what makes the check a drift check rather than a "spans I happened to find look fine" check.
- Graceful failure (a named `fail:` line, not a Python traceback) if `schemas/headless-contract.md` is missing, unreadable, or its table doesn't yield exactly 9 canonical, pairwise-distinct strings; same graceful-failure treatment if any of the three consumer files is missing or unreadable.

### Out
- `skills/release-loop/SKILL.md` and any other file that discusses terminal signals narratively without quoting the exact line — not scanned; only the three named consumer files are in scope, per the feature request.
- Auto-fixing drift. Detection only, consistent with every other check in `scripts/validate.sh`.
- Bumping or validating the `schemas/headless-contract.md` contract version number itself (out of scope; a separate concern from line-level drift).
- Fuzzy/typo detection of the leading producer or state keyword itself as a *candidate-matching* mechanism (e.g. "Documentaiton" instead of "Documentation" is never flagged as a malformed candidate span — the coverage pass may still catch its side effect; see Risks for exactly when it does and doesn't).

## Architecture

Appended as check "6." in `scripts/validate.sh`, one more `python3 - <<'PY' ... PY` block in the existing style:

1. **Parse canonical lines**: read `schemas/headless-contract.md`, locate the markdown table rows for `compound`, `compound-refresh`, `retrospective`; for each row, strip the enclosing single backticks from the Success / Skipped-no-op / Failure cells to get 3 exact strings per producer (9 total). Fail loudly if the table doesn't parse to exactly 9 non-empty strings, or if any two of the 9 are identical (a headless-contract.md authoring bug, not a consumer-side drift).
2. **Find candidate spans**: for each of the 3 consumer files, regex-scan for inline code spans `` `([^`]+)` `` whose content matches, case-insensitively (to still flag a case-drift as a candidate rather than silently skip it), `^(Documentation|Refresh|Retrospective)\s+(complete|skipped|failed)\b`. A missing or unreadable consumer file is a named `fail:` line here, not a crash.
3. **Byte-compare**: for each candidate span, compare its exact text (case-sensitive, full string) against the 9 canonical strings. Match found → mark that canonical string "seen". No match → record a failure: file path, 1-based line number (computed from the span's character offset), the actual quoted text, and the canonical Success/Skipped/Failure triplet for that producer (all three, not just the guessed state — the guess itself may be what's wrong).
4. **Coverage pass**: after scanning all three files, any of the 9 canonical strings never marked "seen" in step 3 is a failure in its own right — report the canonical producer/state and the fact that no consumer file quotes it. This catches deletion and duplicate-substitution, which step 3 alone cannot (see S3).
5. **Report**: `ok:   terminal signal lines match schemas/headless-contract.md` when every candidate span matched (step 3) and every canonical line was seen at least once (step 4); otherwise one `fail:` line per drifted span and one per uncovered canonical line, contributing to the script's existing `FAIL=1` / exit-1 behavior.

## Testing

`scripts/validate.sh` has no dedicated test harness in this repo (verification today is "run it, read the output"); this check follows the same convention, using disposable fixture copies rather than corrupting real skill files.

- **Fixture harness**: a new standalone script, `scripts/test-signal-drift.sh`, invoked manually (not part of `validate.sh` itself, and not wired into any CI in this repo). It copies the current worktree to a `mktemp -d` directory per case, applies one mutation, runs `bash scripts/validate.sh` from the temp copy, asserts on exit code + grepped output, and removes the temp directory afterward. Never mutates the real `skills/` files in place.
- **Case A — clean repo**: run against an unmodified temp copy; assert exit 0 and the new `ok:` line is present.
- **Case B — drift in `skills/compound/SKILL.md`**: mutate one byte inside one of its quoted signal lines (e.g. drop a character from `<path>`); assert nonzero exit and output containing `skills/compound/SKILL.md` plus the correct line number.
- **Case C — drift in `skills/compound-refresh/SKILL.md`**: same mutation pattern; assert nonzero exit and correct file/line named.
- **Case D — drift in `skills/retrospective/SKILL.md`**: same mutation pattern, including one against a cross-quoted `compound` line inside `retrospective/SKILL.md` (Phase 7), confirming cross-file quotes are checked against the right producer's canonical set.
- **Case E — malformed contract**: temp copy with `schemas/headless-contract.md` emptied/deleted; assert a named `fail:` line (not a traceback) and nonzero exit.
- **Case F — deleted signal line (coverage)**: temp copy with the `` `Documentation skipped — <reason>` `` clause removed entirely from `skills/compound/SKILL.md` (S3); assert nonzero exit and output naming that canonical line as uncovered, even though no malformed candidate span exists to point at.
- **Case G — missing consumer file**: temp copy with `skills/retrospective/SKILL.md` deleted; assert a named `fail:` line (not a traceback) and nonzero exit.

TDD order: write Cases B-G as failing tests first (they fail today because the check doesn't exist — `validate.sh` would incorrectly report `ALL CHECKS PASSED` on every corrupted fixture, including Case F where nothing is even malformed, only missing), confirm the failure mode is "check missing" not "check present but wrong", then implement the check until B-G fail for the *right* reason (drift or gap correctly detected) and A passes clean.

## Risks

- **Contract file format changes** (table restructured) could break the parser silently-passing 0 rows instead of failing — mitigated by the "exactly 9 canonical, pairwise-distinct strings or fail loudly" rule in Architecture step 1.
- **Keyword-level typos** ("Documentaiton complete") aren't caught as a malformed-candidate failure, because the candidate-detection regex itself requires the correct keyword. If that canonical line is quoted only once across the three files, the coverage pass (Architecture step 4) still catches it indirectly, as a "line X not found anywhere" report. If the same canonical line is quoted correctly elsewhere too (e.g. `compound`'s lines, quoted both in `compound/SKILL.md` and cross-quoted in `retrospective/SKILL.md`), a keyword-level typo in one copy stays invisible to both mechanisms — an accepted residual gap (see Scope/Out): the feature asks for byte-match drift detection on correctly-shaped candidates plus coverage of the canonical set, not spellcheck of arbitrary prose.
- **New producers added later** (a 4th skill joining the headless contract) require this check's regex keyword list to be extended by hand — acceptable now (KISS/YAGNI; only 3 producers exist), flagged in Open Decisions for whoever adds a 4th.

## Success Criteria

1. `scripts/validate.sh` run against the current, unmodified repo passes and includes the new check's `ok:` line.
   - **Measured by**: `bash scripts/validate.sh` → exit 0, output contains `ok:   terminal signal lines match schemas/headless-contract.md` (or the implemented equivalent wording) and the final `ALL CHECKS PASSED`.
2. A deliberate one-byte mutation to a quoted signal line in a temp copy of `skills/compound/SKILL.md` makes `scripts/validate.sh` fail, naming that file and the correct line number.
   - **Measured by**: the Case B fixture test — nonzero exit, output contains `skills/compound/SKILL.md` and the mutated line's number.
3. The same mutation pattern against `skills/compound-refresh/SKILL.md` and `skills/retrospective/SKILL.md` (including a cross-quoted `compound` line inside `retrospective/SKILL.md`) is independently caught, each naming its own file and line.
   - **Measured by**: the Case C and Case D fixture tests — nonzero exit, correct file/line named in each.
4. A missing or malformed `schemas/headless-contract.md`, or a missing consumer `SKILL.md`, produces a named `fail:` line instead of a Python traceback.
   - **Measured by**: the Case E and Case G fixture tests — nonzero exit, no traceback in output, a `fail:` line naming the missing/malformed file.
5. Deleting a quoted signal line entirely (no malformed candidate remains, just an absence) is still caught by the coverage pass, naming the uncovered canonical line.
   - **Measured by**: the Case F fixture test — nonzero exit, output names the specific canonical producer/state line that no consumer file quotes.

## Open Decisions

- Exact wording of the new check's `ok:`/`fail:` message strings — owner: `implementing` (cosmetic, doesn't affect the byte-match semantics above).
- Whether to extend the producer-keyword list when a 4th headless-contract producer is added later — owner: whoever adds that producer (see Risks).
