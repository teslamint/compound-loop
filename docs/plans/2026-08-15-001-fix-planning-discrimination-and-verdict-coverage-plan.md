---
schema: plan/v1
title: Planning Discrimination and Verdict Coverage
type: fix
status: done
completed_by: df8f7cac095254959a7a8433c05540f06be41c6d
date: 2026-08-15
execution: non-code
origin: docs/specs/2026-08-15-planning-discrimination-and-verdict-coverage-design.md
body_seal: 5091cc907df5a2b80afd8fec35797c32c9235fc8270da2c738e82010ef6153d7
---

# Planning Discrimination and Verdict Coverage — Implementation Plan

## Goal

Land the two step 14 self-review checks the approved spec specifies — Verdict coverage as the fourth check of `skills/planning/SKILL.md` step 14 and Discrimination check as the last — prepare the human-posted closing payloads for issues #11 and #12, and close the addendum-authorized Ship lifecycle so local evidence survives cleanup and SC6 blocks Retro until first-hand-gated issue verification completes.

## Architecture notes

- **Five ordered implementation units plus two Ship transitions.** U1 and U2 edit the same section of `skills/planning/SKILL.md` but remain separate because a reviewer can reject one wording and accept the other. U2 follows U1 so its absolute bullet-count acceptance encodes the final order. U3 follows both because it copies the wording that actually shipped and fixture-tests the outward packet. U4 adds the two approved-plan transition hooks, owns their integration fixtures, and follows U3 because R2 consumes its packet. U5 independently attacks and durably records the result after all four implementation commits. The release-loop orchestrating session enters `shipping`; that same session executes R1 inside shipping Step 8 after merged-result verification, then executes R2 after cleanup and before Retro. Neither transition is an `implementing` unit and neither is delegated.
- **Insertion, never renumbering.** Step 14's checks are an unnumbered bullet list, so neither insertion renumbers anything. `scripts/validate.sh` check 13 (`[plan-refs]`) parses `^## <n>.` step headings, `skills/planning/references/deepening.md` sections, and `schemas/plan-schema.md` hard-floor numbers; it never reads bullets inside a step (rechecked below).
- **Positions carry meaning, and nothing outside this cycle depends on them.** Verdict coverage lands immediately after Scenario coverage because the spec declares it the dual of Spec coverage, so the three coverage checks read as one family. Discrimination check lands last, after Command closure, because both probe one step's substance rather than a document-wide map. Every ordinal reference to a step 14 bullet in this repository sits inside this cycle's own documents; references elsewhere name bullets by title, so insertion breaks no external cross-reference.
- **The shipped wording is the deliverable.** Successive invariant attacks constructed plan steps that satisfied the wording of the moment while retaining the defect. The approved spec remains unchanged as the historical contract; `docs/deviations/2026-08-15-discrimination-axis-and-out-of-set-verdict-012.md` carries every post-approval wording repair. U1 and U2 use the addendum's complete replacement bullets, not isolated patch clauses.
- **Two controlled comparisons, not one overloaded pair.** Discrimination requires an invariance pair and a changed-axis pair. Both use the real artifact kinds and producing pipeline; the changed-axis result must occur in a named effect-bearing signal or subartifact. Metadata-only or receipt-only change does not prove the specified effect.
- **Verdict complement coverage is categorical.** Verdict coverage derives the known set from both declared sources, then requires explicit handling for the full complement: unresolved measurement and any value outside the known set. Enumerating one representative out-of-set value cannot cover another.
- **Issue payloads, review evidence, and loop state survive cleanup.** U3 commits two post bodies plus a separate command packet under `docs/issue-closures/`. Payload files contain only the public comment bodies. The command packet contains exact targets, idempotent fail-closed read-before-write commands, a non-authorization marker, and post-action verification. U4 adds exact approved-plan hooks to `shipping` and `release-loop`; its integration fixtures prove R1's identity-bound transfer, crash recovery, archive preservation, foreign/collision/symlink rejection, and R2's consent/block/recovery/Phase-6 ordering. U5 commits bounded invariant-attack findings and the final verdict to `docs/reviews/2026-08-15-planning-discrimination-and-verdict-coverage-implementation-review.md`; `.release-loop/reviews/` remains scratch only.
- **Acceptance checks compare the normalized complete bullet.** U1 and U2 each carry a literal SHA-256 of the normalized replacement bullet and mutation probes that delete the clauses previously shown to be dodgeable. Counts and token greps remain only positional checks; they are not accepted as wording proof.
- **No mechanical plan-body checker ships.** The user chose prose only at the Design gate. The plan-schema mirror plus a `validate.sh` agreement check stay deferred behind the trigger the spec records.
- **Execution follows the phase contracts.** After approval, `implementing` selects Serial subagents by default for U1–U5 or Inline if the user explicitly chooses it; U5 is a real unit, so the normal clean Phase-4 fast path can verify its committed review record instead of silently skipping the invariant attack. If a committing subagent is selected, the orchestrator passes the session's actual `SSH_AUTH_SOCK` and verifies `%G?` after each commit; an Inline run has no dispatched-commit event. U4 makes the lifecycle explicit: `shipping` owns R1 inside Step 8's fixed cleanup order, and `release-loop` owns R2 after `shipping` returns and before Retro.
- **Issue closure is a separate first-hand gate.** Neither `shipping` nor a dispatched worker owns issue comments or issue closure. R1 makes the base checkout's non-archive `.release-loop/` state authoritative immediately before cleanup removes the feature worktree. R2 then reads the committed packet and authoritative ledger from that base checkout, presents the exact repository, issue numbers, payload paths, possible comment commands, and possible close commands, and asks for point-of-risk confirmation. The human may run the packet or authorize the orchestrating session that received the answer directly. The packet reads before each write, so a freshly approved recovery invocation skips transitions already present. Until post-action issue-state and body verification pass, SC6 remains unmet, Ship stays blocked, and Retro cannot begin.

## Assumption Recheck

All seven retained commands from the origin spec rerun fresh at `2026-08-14T20:06:11Z` against working tree `68ffafe`:

| Approved claim | Fresh evidence | Outcome |
|---|---|---|
| Step 14 carries exactly ten checks; none mentions discrimination or verdicts | Bullet count `10`; name search `0` | match |
| `schemas/plan-schema.md` hard floor has ten items | `10` | match |
| No check asserts plan-document body sections | `grep -c 'plans_dir\|docs.*plans' scripts/validate.sh` → `7` mentions, still only the frontmatter loop and the body-seal reader | match |
| Step 14's checks are mirrored in no other file | `grep -rln 'Command closure' --include='*.md' --include='*.sh' . \| grep -v '^./docs/'` now returns `./.release-loop/progress.md` **and** `./skills/planning/SKILL.md` | match, with a recorded qualification: the new hit is this loop's own gitignored ledger, which quoted the bullet name in a Log line. No consumer contract file mirrors step 14, which is the substance of the approved claim. Future runs should exclude `.release-loop/` |
| `[plan-refs]` never inspects bullets inside a step | `sed -n '567,662p' scripts/validate.sh` → parses step headings, deepening sections, hard-floor numbers only | match |
| `CHANGELOG.md` has no unreleased heading | `grep -nic 'unreleased' CHANGELOG.md` → `0` | match |
| Plugin cache and repo both declare 0.10.0 with differing `release-loop` text | `diff -q` → `DIVERGENT` | match |

No contradiction, so no deviation addendum is required for the assumptions. Addendum 012 exists for a different reason: a review-introduced wording amendment to an approved artifact. No unavailable evidence.

## File structure

| File | Change | Owner |
|---|---|---|
| `skills/planning/SKILL.md` | Insert the Verdict coverage bullet after the Scenario coverage bullet | U1 |
| `skills/planning/SKILL.md` | Append the Discrimination check bullet after the Command closure bullet | U2 |
| `docs/issue-closures/2026-08-15-issue-11.md` | Create: prepared closing comment for issue #11 | U3 |
| `docs/issue-closures/2026-08-15-issue-12.md` | Create: prepared closing comment for issue #12 | U3 |
| `docs/issue-closures/2026-08-15-issues-11-and-12-command.md` | Create: exact human-gated posting, closing, and verification packet | U3 |
| `skills/shipping/SKILL.md` | Modify: add the approved-plan pre-removal transition hook to Step 8 | U4 |
| `skills/release-loop/SKILL.md` | Modify: define both transition families and the post-Ship completion gate | U4 |
| `skills/release-loop/references/progress-schema.md` | Modify: allow `branch` to become the base checkout branch after a verified authoritative handoff | U4 |
| `docs/reviews/2026-08-15-planning-discrimination-and-verdict-coverage-implementation-review.md` | Create: bounded independent invariant-attack findings and final verdict | U5 |
| Base-checkout `.release-loop/` non-archive live state | Install the post-merge verified live state immediately before worktree removal; preserve base `.release-loop/archive/`; rewrite the transferred ledger to base-main Ship state | R1 (hook and evidence owned by U4) |
| `.release-loop/evidence/U3/` | Create: sanitized disposable-fixture records for T0–T4 | U3 |
| `.release-loop/evidence/U4/` | Create: six sanitized T5 transfer records, six T6 R2-gate records, and six T7 SC6-completion records | U4 |
| `.release-loop/evidence/U5/final-branch-review.json` | Create: exact-HEAD provenance and clean verdict for the post-U5 final branch review | U5 |
| `docs/plans/2026-08-15-001-fix-planning-discrimination-and-verdict-coverage-plan.md` | This plan | — |

## Scenario coverage map

| S-ID | Unit chain | Observable verification |
|---|---|---|
| S1 (digest comparison that cannot discriminate) | U2 | SC2 rejects four loopholes: different artifact kinds, identical conversions whose package digest changes only because of fresh manifest UUIDs, same-kind comparison varied along an irrelevant input, and metadata-only change while the named effect-bearing output stays constant. It then accepts a comparison with separate same-input and changed-axis pairs whose named effect-bearing signal returns equal then different. |
| S2 (branching on two of three verdicts) | U1 | SC3 rejects the issue #12 shape through the union clause, then rejects a known set `{0,1}` whose plan handles only representative out-of-set value `2` while leaving `3` branchless. It accepts only value-specific known branches plus category-specific unresolved and any-outside-set handling. |
| S3 (no comparison, no verdict) | U1 → U2 | Both bullets open with trigger shapes, so a plan with neither shape satisfies both vacuously. A reader confirms neither bullet imposes an unconditional obligation. |
| S4 (reviewer audits whether the checks can fail) | U1 → U2 → U3 → U4 → U5 | U5 runs the SC2/SC3 invariant attacks after the shipped wording, payload artifacts, transition hooks, and T5 evidence exist; records each reject/accept result with the deciding clause; writes the bounded record to `docs/reviews/2026-08-15-planning-discrimination-and-verdict-coverage-implementation-review.md`; and commits it before the normal final branch review. |
| S5 (diagnostic resolves to nothing, or to something unenumerated) | U1 | The complete-bullet check proves the unresolved and full-complement categories shipped; SC3 proves a single representative out-of-set branch cannot stand in for all other values. |

## Implementation Units

## U1: Insert the Verdict coverage check as step 14's fourth bullet

Files:
  Create/Modify: skills/planning/SKILL.md
Steps:
  1. In `## 14. Self-review`, immediately after the bullet that begins `- **Scenario coverage**`, insert exactly this bullet, wrapped to match the surrounding lines:
     - **Verdict coverage** — for every unit that emits a verdict, decision, or classification, derive the known value set from the union of the emitting step's declared output set and the origin spec's own enumeration — never from recall, and never from the narrower of the two. Cover that set's full complement as two explicit outcome categories: the measurement fails to resolve, or it resolves to any value outside the known set; one representative out-of-set value does not cover the rest. Confirm every known value and both complement categories have their own value- or category-specific next step; a single catch-all consumer that acts on "whatever the verdict says" covers nothing. A value or category with no next step is a plan gap, not an implementation-time unknown. A known value deliberately out of scope goes to Deferred to Follow-Up Work with its reason, and a verdict no unit consumes is itself either a gap or a deliberate Deferred entry.
  2. Confirm no other line changed: `git diff skills/planning/SKILL.md` shows only the inserted region.
  3. Run the complete-bullet and mutation program below. It extracts the bullet through the next bullet or blank line, normalizes whitespace, requires the literal digest, and proves that deleting the full-complement, catch-all, or unconsumed-verdict clause makes validation fail.
  4. Commit: "fix(planning): Add the verdict coverage self-review check"
Acceptance: the positional commands, the Python program, and repository validation below must all exit 0.

```bash
R='/^## 14\. Self-review/,/^## 15\./'
test "$(sed -n "$R p" skills/planning/SKILL.md | grep -c '^- \*\*')" = 11
sed -n "$R p" skills/planning/SKILL.md | grep '^- \*\*' | sed -n '4p' | grep -q 'Verdict coverage'
python3 -I - <<'PY'
from hashlib import sha256
from pathlib import Path

path = Path("skills/planning/SKILL.md")
expected = """- **Verdict coverage** — for every unit that emits a verdict, decision, or classification, derive the known value set from the union of the emitting step's declared output set and the origin spec's own enumeration — never from recall, and never from the narrower of the two. Cover that set's full complement as two explicit outcome categories: the measurement fails to resolve, or it resolves to any value outside the known set; one representative out-of-set value does not cover the rest. Confirm every known value and both complement categories have their own value- or category-specific next step; a single catch-all consumer that acts on "whatever the verdict says" covers nothing. A value or category with no next step is a plan gap, not an implementation-time unknown. A known value deliberately out of scope goes to Deferred to Follow-Up Work with its reason, and a verdict no unit consumes is itself either a gap or a deliberate Deferred entry."""
expected_digest = "1b0b0fa7d06777b677df0ac676fff619a7326839824679822fc535f6e2b51a22"

def normalize(value):
    return " ".join(value.split())

def extract(text):
    section = text.split("## 14. Self-review", 1)[1].split("## 15.", 1)[0]
    lines = section.splitlines()
    start = next(i for i, line in enumerate(lines) if line.startswith("- **Verdict coverage**"))
    result = [lines[start]]
    for line in lines[start + 1:]:
        if line.startswith("- **") or not line.strip():
            break
        result.append(line)
    return "\n".join(result)

def validate_bullet(actual):
    assert normalize(actual) == normalize(expected)
    assert sha256(normalize(actual).encode()).hexdigest() == expected_digest

source = path.read_text()
actual = extract(source)
validate_bullet(actual)
normalized_actual = normalize(actual)
for clause in (
    "Cover that set's full complement as two explicit outcome categories",
    'a single catch-all consumer that acts on "whatever the verdict says" covers nothing',
    "a verdict no unit consumes is itself either a gap or a deliberate Deferred entry",
):
    assert normalized_actual.count(clause) == 1
    mutant = normalized_actual.replace(clause, "", 1)
    try:
        validate_bullet(mutant)
    except AssertionError:
        pass
    else:
        raise AssertionError(f"deleting clause remained accepted: {clause}")
PY
bash scripts/validate.sh | tail -1 | grep -q 'ALL CHECKS PASSED'
```

## U2: Append the Discrimination check as step 14's last bullet

Files:
  Create/Modify: skills/planning/SKILL.md
Depends on: U1, landed. This unit's acceptance asserts a bullet count of 12, which holds only after U1's insertion.
Steps:
  1. In `## 14. Self-review`, immediately after the bullet that begins `- **Command closure**`, insert exactly this bullet, wrapped to match the surrounding lines:
     - **Discrimination check** — for every step that compares two things, run the step's own comparison on two controlled fixture pairs. Both pairs use the same artifact kinds as the step's real comparands and the same command or pipeline that produces them. The invariance pair runs identical inputs and configuration twice; the changed-axis pair differs only in the input or option whose effect the step exists to detect. Name the effect-bearing signal or subartifact the comparison measures, and record both fixture pairs and both observed results in the step. The invariance pair must compare equal; the changed-axis pair must compare different in that named signal or subartifact. A difference confined to metadata, a receipt, or another output unrelated to the specified effect does not satisfy the changed-axis result. Different artifact kinds in the real comparands or either fixture pair fail this check outright: they always differ, so the comparison cannot report anything about the change. For every guard, run and record one fixture that must pass and one minimally changed fixture that must fail; a guard that accepts both is not a guard.
  2. Confirm the bullet is last in the section and that the paragraph following the list (`Fix issues inline; no separate review pass is needed.`) is untouched.
  3. Run the complete-bullet and mutation program below. It extracts through the following blank line, normalizes whitespace, requires the literal digest, and proves deletion of the two-pair, changed-axis, effect-bearing-output, or guard-failure clause makes validation fail.
  4. Commit: "fix(planning): Add the discrimination self-review check"
Acceptance: the positional commands, the Python program, and repository validation below must all exit 0.

```bash
R='/^## 14\. Self-review/,/^## 15\./'
test "$(sed -n "$R p" skills/planning/SKILL.md | grep -c '^- \*\*')" = 12
test "$(sed -n "$R p" skills/planning/SKILL.md | grep -c 'Discrimination check\|Verdict coverage')" = 2
sed -n "$R p" skills/planning/SKILL.md | grep '^- \*\*' | tail -1 | grep -q 'Discrimination check'
python3 -I - <<'PY'
from hashlib import sha256
from pathlib import Path

path = Path("skills/planning/SKILL.md")
expected = """- **Discrimination check** — for every step that compares two things, run the step's own comparison on two controlled fixture pairs. Both pairs use the same artifact kinds as the step's real comparands and the same command or pipeline that produces them. The invariance pair runs identical inputs and configuration twice; the changed-axis pair differs only in the input or option whose effect the step exists to detect. Name the effect-bearing signal or subartifact the comparison measures, and record both fixture pairs and both observed results in the step. The invariance pair must compare equal; the changed-axis pair must compare different in that named signal or subartifact. A difference confined to metadata, a receipt, or another output unrelated to the specified effect does not satisfy the changed-axis result. Different artifact kinds in the real comparands or either fixture pair fail this check outright: they always differ, so the comparison cannot report anything about the change. For every guard, run and record one fixture that must pass and one minimally changed fixture that must fail; a guard that accepts both is not a guard."""
expected_digest = "6910b8bf6c9195d414bd1812f76e8ae8e5b98b688c69923b8e5c84f1b9930d49"

def normalize(value):
    return " ".join(value.split())

def extract(text):
    section = text.split("## 14. Self-review", 1)[1].split("## 15.", 1)[0]
    lines = section.splitlines()
    start = next(i for i, line in enumerate(lines) if line.startswith("- **Discrimination check**"))
    result = [lines[start]]
    for line in lines[start + 1:]:
        if line.startswith("- **") or not line.strip():
            break
        result.append(line)
    return "\n".join(result)

def validate_bullet(actual):
    assert normalize(actual) == normalize(expected)
    assert sha256(normalize(actual).encode()).hexdigest() == expected_digest

source = path.read_text()
actual = extract(source)
validate_bullet(actual)
normalized_actual = normalize(actual)
for clause in (
    "two controlled fixture pairs",
    "the changed-axis pair differs only in the input or option whose effect the step exists to detect",
    "A difference confined to metadata, a receipt, or another output unrelated to the specified effect does not satisfy the changed-axis result",
    "a guard that accepts both is not a guard",
):
    assert normalized_actual.count(clause) == 1
    mutant = normalized_actual.replace(clause, "", 1)
    try:
        validate_bullet(mutant)
    except AssertionError:
        pass
    else:
        raise AssertionError(f"deleting clause remained accepted: {clause}")
PY
bash scripts/validate.sh | tail -1 | grep -q 'ALL CHECKS PASSED'
```

## U3: Prepare the human-gated closing payloads and command packet

Files:
  Create/Modify: docs/issue-closures/2026-08-15-issue-11.md, docs/issue-closures/2026-08-15-issue-12.md, docs/issue-closures/2026-08-15-issues-11-and-12-command.md, .release-loop/progress.md
Depends on: U1 and U2, both landed. This unit quotes the wording that shipped, read out of `skills/planning/SKILL.md`, so running it earlier makes its complete-bullet equality check fail.
Steps:
  1. Create `docs/issue-closures/2026-08-15-issue-11.md` as the public comment body and nothing else. Its first paragraph is the complete shipped Discrimination check bullet on one quoted line prefixed `> `. Its second paragraph is exactly: `The historical H3 evidence observed a comparison between different artifact kinds, .mlmodelc and .mlpackage. It also observed identical .mlpackage conversions whose model and weight data matched while fresh Manifest.json UUIDs made the whole-package digests differ. The later coremldata.bin/weights.bin same-kind axis example is reviewer-constructed. The shipped check therefore requires two controlled pairs from the real producing pipeline, identical-input equality, changed-axis difference in a named effect-bearing signal or subartifact, and one passing plus one failing guard fixture.` Its final paragraph is the three provenance paths below, each as a backtick-quoted Markdown list item and in the tuple's order.
  2. Create `docs/issue-closures/2026-08-15-issue-12.md` in the same payload-only form. Its first paragraph is the complete shipped Verdict coverage bullet on one quoted line. Its second paragraph is exactly: `Issue #12 reported a branchless third verdict; it did not prescribe a disjunctive enumeration source. The Design-gate review constructed the narrower author-declared-set loophole, which the union clause closes. The later plan review constructed a resolved value outside both known sources, which requires full-complement handling rather than one representative value. The shipped check therefore requires value-specific branches for known values, category-specific next steps for unresolved and any-outside-set outcomes, rejection of a catch-all consumer, and a Deferred entry or other next step for every unconsumed verdict.` Use the same exact final provenance paragraph.
  3. Create `docs/issue-closures/2026-08-15-issues-11-and-12-command.md`, separate from both payloads, with exactly this content:

~~~~markdown
Preparation evidence — first-hand consent still required. This file authorizes no command.

Target: `teslamint/compound-loop`, issues `#11` and `#12`.

```bash
set -euo pipefail
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
PAYLOAD_11="$TMP/issue-11.md"
PAYLOAD_12="$TMP/issue-12.md"
git show HEAD:docs/issue-closures/2026-08-15-issue-11.md > "$PAYLOAD_11"
git show HEAD:docs/issue-closures/2026-08-15-issue-12.md > "$PAYLOAD_12"
cmp -s docs/issue-closures/2026-08-15-issue-11.md "$PAYLOAD_11"
cmp -s docs/issue-closures/2026-08-15-issue-12.md "$PAYLOAD_12"
python3 -I - "$PAYLOAD_11" "$PAYLOAD_12" <<'PY'
from hashlib import sha256
from pathlib import Path
import sys
if sys.flags.optimize:
    raise SystemExit("optimized Python is forbidden for packet verification")
pins = (
    (Path(sys.argv[1]), "6a823211c87178f4d61c2f2a054a483fe5d471c80c5f8000252993e97d9092b3"),
    (Path(sys.argv[2]), "6bbf1e73b146a0e2bbb4a20ff7349b6000ccf31e713d5060cb5a41e7c5a4ee2c"),
)
for path, expected in pins:
    actual = sha256(path.read_bytes()).hexdigest()
    if actual != expected:
        raise SystemExit(f"payload hash mismatch: {path}")
PY
comment_status() {
  issue=$1
  payload=$2
  snapshot="$TMP/$issue-before-comment.json"
  if ! gh issue view "$issue" --repo teslamint/compound-loop --json state,comments > "$snapshot"; then
    echo "issue comment-state read failed" >&2
    return 2
  fi
  python3 -I - "$snapshot" "$payload" <<'PY'
import json
from pathlib import Path
import sys
if sys.flags.optimize:
    raise SystemExit("optimized Python is forbidden for packet verification")
result = json.loads(Path(sys.argv[1]).read_text())
payload = Path(sys.argv[2]).read_text().rstrip("\n")
print("present" if any(comment["body"].rstrip("\n") == payload for comment in result["comments"]) else "absent")
PY
}
issue_state() {
  issue=$1
  snapshot="$TMP/$issue-before-close.json"
  if ! gh issue view "$issue" --repo teslamint/compound-loop --json state > "$snapshot"; then
    echo "issue state read failed" >&2
    return 2
  fi
  python3 -I - "$snapshot" <<'PY'
import json
from pathlib import Path
import sys
if sys.flags.optimize:
    raise SystemExit("optimized Python is forbidden for packet verification")
print(json.loads(Path(sys.argv[1]).read_text())["state"])
PY
}
status=$(comment_status 11 "$PAYLOAD_11")
case "$status" in
  present) ;;
  absent) gh issue comment 11 --repo teslamint/compound-loop --body-file "$PAYLOAD_11" ;;
  *) exit 1 ;;
esac
state=$(issue_state 11)
case "$state" in
  CLOSED) ;;
  OPEN) gh issue close 11 --repo teslamint/compound-loop ;;
  *) exit 1 ;;
esac
status=$(comment_status 12 "$PAYLOAD_12")
case "$status" in
  present) ;;
  absent) gh issue comment 12 --repo teslamint/compound-loop --body-file "$PAYLOAD_12" ;;
  *) exit 1 ;;
esac
state=$(issue_state 12)
case "$state" in
  CLOSED) ;;
  OPEN) gh issue close 12 --repo teslamint/compound-loop ;;
  *) exit 1 ;;
esac
gh issue view 11 --repo teslamint/compound-loop --json state,comments > "$TMP/11.json"
gh issue view 12 --repo teslamint/compound-loop --json state,comments > "$TMP/12.json"
python3 -I - "$TMP/11.json" "$PAYLOAD_11" "$TMP/12.json" "$PAYLOAD_12" <<'PY'
import json
from pathlib import Path
import sys
if sys.flags.optimize:
    raise SystemExit("optimized Python is forbidden for packet verification")
for result_path, payload_path in zip(sys.argv[1::2], sys.argv[2::2]):
    result = json.loads(Path(result_path).read_text())
    payload = Path(payload_path).read_text().rstrip("\n")
    if result["state"] != "CLOSED":
        raise SystemExit(f"issue not closed: {result_path}")
    if not any(comment["body"].rstrip("\n") == payload for comment in result["comments"]):
        raise SystemExit(f"exact payload absent: {result_path}")
PY
```
~~~~
  4. Before the Ship gate, append a `.release-loop/progress.md` Log line whose text after the leading `- <UTC timestamp> ` is exactly the `ledger_suffix` in the acceptance program below. It names the committed packet path, repeats the four literal `gh` mutation commands, carries the packet's exact non-authorization marker, and names the release-loop orchestrator or human who receives first-hand approval as execution owner. Do not write these commands or the marker into either payload.
  5. Run the complete-payload program below. It uses a line-boundary extractor that stops on the next bullet or blank line, so the last Discrimination bullet cannot consume the following prose. It requires normalized equality for both full bullets, the provenance distinctions, all three pointers, payload-only safety, and the separate packet contract.
  6. Exercise matrix rows T0–T4 only through a disposable `gh` stub prepended to `PATH`, with state and call logs under a temporary root and the exact `FAIL_AT` seams named in the matrix. Each run records `command -v gh`, the stub hash, an unset real-host/token inventory, and `BOUNDARY_SENTINEL=gh-stub-only`; every read-failure case proves zero mutation calls, and every post-write failure rerun proves already-landed transitions are skipped. A real `gh` or network endpoint must be unreachable. Write one sanitized record per row/outcome to `.release-loop/evidence/U3/`.
  7. Commit: "docs(issues): Prepare closing payloads and command packet". Commit the three files under `docs/issue-closures/`; `.release-loop/progress.md` and evidence remain loop state.
Acceptance: the Python program and repository validation below must exit 0, and `.release-loop/evidence/U3/` must contain all 30 T0–T4 outcome records with the fixture identity, pre-state, injection or command, exit status, post-state, next-invocation result, and mechanism check required by `implementing` step 4.

```bash
python3 -I - <<'PY'
from datetime import datetime
from hashlib import sha256
from pathlib import Path
import re
import subprocess

skill = Path("skills/planning/SKILL.md").read_text()
payloads = {
    "Discrimination check": Path("docs/issue-closures/2026-08-15-issue-11.md"),
    "Verdict coverage": Path("docs/issue-closures/2026-08-15-issue-12.md"),
}
pointers = (
    "docs/reviews/2026-08-15-planning-discrimination-and-verdict-coverage-spec-review.md",
    "docs/reviews/2026-08-15-planning-discrimination-and-verdict-coverage-plan-review.md",
    "docs/deviations/2026-08-15-discrimination-axis-and-out-of-set-verdict-012.md",
)
paragraphs = {
    "Discrimination check": "The historical H3 evidence observed a comparison between different artifact kinds, .mlmodelc and .mlpackage. It also observed identical .mlpackage conversions whose model and weight data matched while fresh Manifest.json UUIDs made the whole-package digests differ. The later coremldata.bin/weights.bin same-kind axis example is reviewer-constructed. The shipped check therefore requires two controlled pairs from the real producing pipeline, identical-input equality, changed-axis difference in a named effect-bearing signal or subartifact, and one passing plus one failing guard fixture.",
    "Verdict coverage": "Issue #12 reported a branchless third verdict; it did not prescribe a disjunctive enumeration source. The Design-gate review constructed the narrower author-declared-set loophole, which the union clause closes. The later plan review constructed a resolved value outside both known sources, which requires full-complement handling rather than one representative value. The shipped check therefore requires value-specific branches for known values, category-specific next steps for unresolved and any-outside-set outcomes, rejection of a catch-all consumer, and a Deferred entry or other next step for every unconsumed verdict.",
}

def normalize(value):
    return " ".join(value.split())

def extract(text, name):
    section = text.split("## 14. Self-review", 1)[1].split("## 15.", 1)[0]
    lines = section.splitlines()
    start = next(i for i, line in enumerate(lines) if line.startswith(f"- **{name}**"))
    result = [lines[start]]
    for line in lines[start + 1:]:
        if line.startswith("- **") or not line.strip():
            break
        result.append(line)
    return "\n".join(result)

pointer_block = "\n".join(f"- `{pointer}`" for pointer in pointers)
payload_pins = {
    "Discrimination check": "6a823211c87178f4d61c2f2a054a483fe5d471c80c5f8000252993e97d9092b3",
    "Verdict coverage": "6bbf1e73b146a0e2bbb4a20ff7349b6000ccf31e713d5060cb5a41e7c5a4ee2c",
}
for name, path in payloads.items():
    assert path.is_file()
    body = path.read_text()
    expected_body = f"> {normalize(extract(skill, name))}\n\n{paragraphs[name]}\n\n{pointer_block}\n"
    assert body == expected_body
    assert sha256(body.encode()).hexdigest() == payload_pins[name]
    lowered = body.lower()
    for forbidden in ("gh issue", "gh --repo", "preparation evidence", "first-hand consent", "authorizes no command"):
        assert forbidden not in lowered

packet = Path("docs/issue-closures/2026-08-15-issues-11-and-12-command.md").read_text()
assert sha256(packet.encode()).hexdigest() == "8168d671af3c457c36afa79e8b8c0217fbce96af0f07e7e8dc563687b8b1aaa7"
for required in (
    "git show HEAD:docs/issue-closures/2026-08-15-issue-11.md",
    "git show HEAD:docs/issue-closures/2026-08-15-issue-12.md",
    "cmp -s docs/issue-closures/2026-08-15-issue-11.md",
    "cmp -s docs/issue-closures/2026-08-15-issue-12.md",
    "6a823211c87178f4d61c2f2a054a483fe5d471c80c5f8000252993e97d9092b3",
    "6bbf1e73b146a0e2bbb4a20ff7349b6000ccf31e713d5060cb5a41e7c5a4ee2c",
    'gh issue comment 11 --repo teslamint/compound-loop --body-file "$PAYLOAD_11"',
    'gh issue comment 12 --repo teslamint/compound-loop --body-file "$PAYLOAD_12"',
    'if result["state"] != "CLOSED"',
    "raise SystemExit(f\"exact payload absent: {result_path}\")",
    "python3 -I -",
    "if sys.flags.optimize:",
):
    assert required in packet
command = packet.split("```bash\n", 1)[1].split("\n```", 1)[0]
subprocess.run(["bash", "-n"], input=command, text=True, check=True)

ledger = Path(".release-loop/progress.md").read_text()
ledger_suffix = (
    "ship: issue-closure preparation | "
    "packet=docs/issue-closures/2026-08-15-issues-11-and-12-command.md | "
    "payload_sha256=issue11:6a823211c87178f4d61c2f2a054a483fe5d471c80c5f8000252993e97d9092b3,issue12:6bbf1e73b146a0e2bbb4a20ff7349b6000ccf31e713d5060cb5a41e7c5a4ee2c | "
    'commands=`gh issue comment 11 --repo teslamint/compound-loop --body-file "$PAYLOAD_11"`; '
    "`gh issue close 11 --repo teslamint/compound-loop`; "
    '`gh issue comment 12 --repo teslamint/compound-loop --body-file "$PAYLOAD_12"`; '
    "`gh issue close 12 --repo teslamint/compound-loop` | "
    "marker=Preparation evidence — first-hand consent still required. This file authorizes no command. | "
    "execution owner=the release-loop orchestrator or human who receives first-hand approval at the point-of-risk gate"
)
ledger_matches = [line for line in ledger.splitlines() if line.endswith(ledger_suffix)]
assert len(ledger_matches) == 1
timestamp_match = re.fullmatch(r"- (\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z) " + re.escape(ledger_suffix), ledger_matches[0])
assert timestamp_match
datetime.strptime(timestamp_match.group(1), "%Y-%m-%dT%H:%M:%SZ")
PY
bash scripts/validate.sh | tail -1 | grep -q 'ALL CHECKS PASSED'
```

## U4: Add approved-plan Ship transition hooks and prove the local handoff

Files:
  Create/Modify: skills/shipping/SKILL.md, skills/release-loop/SKILL.md, skills/release-loop/references/progress-schema.md, .release-loop/evidence/U4/
Depends on: U1, U2, and U3, all committed and individually reviewed.
Steps:
  1. In `skills/shipping/SKILL.md` Step 8, replace its ordering paragraph with exactly:

~~~~markdown
Merge ordering invariant, never reordered: **merge -> verify tests on the merged result -> run every eligible approved-plan pre-removal transition -> remove worktree -> delete branch.** This transition path applies only to a chosen merge outcome. A transition is eligible only when `shipping` is invoked by `release-loop` and the approved, body-sealed plan contains a `## Release-loop Ship-cleanup transition R<N>:` section with an explicit owner, executable acceptance, and matching mutation/failure-state matrix row. Revalidate the plan `body_seal` immediately before running it. Execute eligible transitions in heading order after merged-result verification and before worktree removal; any failure blocks cleanup. A local transition may run headlessly only when its matrix explicitly permits that outcome and its boundary proof makes every outward target unreachable; an outward transition still requires first-hand confirmation at the point of risk. Only remove a worktree this tooling created (path under `.worktrees/` or `worktrees/`); anything else is harness- or user-owned -- leave it. The typed `discard` path executes no approved-plan transition: after `references/question-tools.md` confirmation its separate order is **typed discard confirmation -> remove worktree -> delete branch**, with force-delete (`git branch -D`) only after worktree removal succeeds.
~~~~

  2. In `skills/release-loop/SKILL.md`, immediately before `## Starting a new loop`, insert exactly:

~~~~markdown
## Approved-plan transition hooks

An approved plan may declare only two release-loop-owned transition families, recognized by exact heading shape and never by free-text inference:

- `## Release-loop Ship-cleanup transition R<N>:` — pass the body-sealed plan to `shipping`; its Step 8 hook runs these local transitions after merged-result verification and before worktree removal.
- `## Release-loop post-Ship completion transition R<N>:` — after `shipping` returns a merged-and-cleaned exit and before Phase 6, the release-loop orchestrator runs these transitions in heading order and requires each section's acceptance evidence before advancing to Retro.

Each transition section's first nonblank body line must be `Matrix rows: T<N>[, T<N> ...]`. Transition IDs are globally unique across both families; a matrix row may be claimed by at most one transition; and every declared row must exist with exactly one evidence owner. Duplicate IDs, duplicate row claims, missing rows, or extra mappings block Ship before any transition runs.

Before either family runs, revalidate the approved plan's `body_seal`, require the section to name an owner and a matching mutation/failure-state matrix row, and persist the transition start in `progress.md`. A missing, failed, cancelled, or unverifiable transition blocks the loop in Ship; it never advances by silence. Local transitions may run headlessly only when their matrix permits it and proves every outward target unreachable. Any outward action requires an interactive point-of-risk USER gate with exact target and values; only the human or orchestrating session receiving first-hand approval executes it, and decline, deferral, relayed approval, or headless mode leaves Ship blocked.

On every Ship entry or resume, before trusting a base `progress.md` or removing a worktree, inspect the base checkout's `.release-loop/.handoff/`. If an owned approved-plan transition operation is present, rerun that named transition from the still-preserved feature worktree before continuing. A missing or mismatched owner marker blocks Ship without deleting the operation.

If the authoritative base ledger records `phase: ship` and `merged: true`, resume never re-enters pre-merge `shipping` or treats “nothing to ship” as completion. Use transition start/acceptance logs plus `.handoff/` state to rerun an interrupted pre-removal transition, finish only pending cleanup after its acceptance, and then run every incomplete post-Ship transition before Retro.
~~~~
  3. In `skills/release-loop/references/progress-schema.md`, replace `branch: <feature branch>` with exactly `branch: <current checkout branch; feature branch before handoff, value of base_branch after verified base handoff>`. No other field changes: transferred state remains `phase: ship`, `phase_status: in-progress`, and `merged: true`.
  4. Run the exact-contract program below. Exercise T5 in a disposable Git repository with linked `main` and feature worktrees. The fixture dispatch log must order `merged-result-verified → R1-start → R1-accepted → worktree-remove`, preserve a byte-identical base `archive/`, transform only the staged ledger, and converge after the exact production-code seams `t5-mid-backup-copy`, `t5-after-backup`, `t5-mid-rollback-copy`, and `t5-mid-install-before-progress`. The second-crash fixture fails after the complete backup, fails again during restore-by-copy, then proves a third run converges without losing the prior base manifest. Source and prior-base fixtures each contain nested empty directories; canonical manifests record directory entries explicitly, and every crash/rerun proves those empty directories transfer or restore exactly. Add boundary cases for a foreign `main` repository; destination/`.handoff/`/`archive/`/live-child and owned operation `stage`/`backup` symlinks pointing at an external sentinel; a base `progress.md` naming a different feature plus an evidence sentinel; a correct-base `.handoff/` operation with a mismatched identity-named owner directory; cancellation at both marker seams, including owner-only state before operation creation and after authoritative completion; and cancellation mid-install before the progress commit point. Boundary cases fail before unowned mutation and preserve sentinels; the authoritative destination ledger disambiguates the owner-only completion seam; every cancellation rerun converges without executing R1 twice. Run the exact packet and R1 bytes under `PYTHONOPTIMIZE=1`, corrupt a pinned payload and a destination identity in separate fixtures, and prove `python3 -I` plus the explicit guards still fail closed. Restart before R1, during R1, and after R1/worktree cleanup; merged state never re-enters pre-merge shipping or executes R1 twice. Then run a fixture release-loop through `shipping merged-clean exit → T6 R2 consent gate → T7 SC6 completion → Phase 6 only after T7 success`. Write the six exact outcome records named in each of T5, T6, and T7. T6 covers direct approval, decline, headless, cancellation, and crash after approval append before extraction; every retry asks again. T7 covers fail-closed read, post-write failure, fresh-approval recovery without duplicate calls, cancellation after R2 start, exact terminal verification, blocked-state clearing, and Phase-6 reachability. Every record contains pre/post ledger fields, dispatch trace, packet/body/payload digests where applicable, boundary inventory/stub calls, approval event if any, injection seam, observed post-state, and mechanism check. Use only `BOUNDARY_SENTINEL=local-copy-only` or `gh-stub-only`; no real worktree or outward endpoint may be reachable.
  5. Commit: "feat(workflow): Add approved Ship transition hooks".
Acceptance: both normalized hook contract digests match; the progress-schema branch line matches exactly; every named hook mutation changes its digest; repository validation exits 0; `.release-loop/evidence/U4/` contains exactly the six records named by each of T5, T6, and T7; T5 proves hook order, operation identity, foreign/collision/symlink rejection, file-and-directory manifest completeness, manifest-before-backup ordering, all four named crash seams, one-crash and second-crash convergence with exact prior-base manifest including nested empty-directory preservation, schema-valid transformed manifests, and archive identity; T6 proves durable fresh approval or blocked state before extraction; T7 proves fail-closed execution/recovery, exact packet/body/remote verification, blocked-state clearing, and Phase-6 exclusion unless SC6 passes.

```bash
python3 -I - <<'PY'
from hashlib import sha256
from pathlib import Path

def normalize(value):
    return " ".join(value.split())
packet_digest = "8168d671af3c457c36afa79e8b8c0217fbce96af0f07e7e8dc563687b8b1aaa7"
plan_source = Path("docs/plans/2026-08-15-001-fix-planning-discrimination-and-verdict-coverage-plan.md").read_text()
u3_source = plan_source.split("## U3:", 1)[1].split("## U4:", 1)[0]
u4_source = plan_source.split("## U4:", 1)[1].split("## U5:", 1)[0]
r2_source = plan_source.rsplit("\n## Release-loop post-Ship completion transition R2:", 1)[1].split("## Mutation/failure-state matrix", 1)[0]
r1_source = plan_source.rsplit("\n## Release-loop Ship-cleanup transition R1:", 1)[1].split("\n## Release-loop post-Ship completion transition R2:", 1)[0]
for clause in (
    'if requested_fail_at and boundary_sentinel != "local-copy-only":',
    'if fail_at == "t5-after-backup":',
    'if fail_at == "t5-mid-backup-copy"',
    'if fail_at == "t5-mid-rollback-copy"',
    "backup_manifest_temp.rename(backup_manifest_record)",
    "assert manifest(backup) == destination_before",
    "if path.is_dir():",
    "TRANSFER_TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    'if fail_at == "t5-mid-install-before-progress":',
    "assert backup.is_dir() and not backup.is_symlink()",
    "assert stage.is_dir() and not stage.is_symlink()",
    "if destination_without_progress == source_without_progress and progress_is_authoritative(destination):",
):
    assert clause in r1_source
    assert normalize(r1_source.replace(clause, "", 1)) != normalize(r1_source)
assert u3_source.count(packet_digest) == 1
assert u4_source.count(packet_digest) == 1
assert r2_source.count(packet_digest) == 2
for clause in (
    "then continue directly to step 3",
    "FAIL_AT=t6-after-approval-before-extraction",
):
    assert clause in r2_source
    assert normalize(r2_source.replace(clause, "", 1)) != normalize(r2_source)
progress_schema = Path("skills/release-loop/references/progress-schema.md").read_text()
assert progress_schema.count("branch: <current checkout branch; feature branch before handoff, value of base_branch after verified base handoff>") == 1
assert "branch: <feature branch>" not in progress_schema



shipping = Path("skills/shipping/SKILL.md").read_text()
shipping_start = shipping.index("Merge ordering invariant, never reordered:")
shipping_end = shipping.index("\n\n## Handoff", shipping_start)
shipping_contract = shipping[shipping_start:shipping_end]
assert sha256(normalize(shipping_contract).encode()).hexdigest() == "9691a8121bd40e08198bca0142ba1447ffebfa2e021cc3155ca1ff1674b1620e"

release = Path("skills/release-loop/SKILL.md").read_text()
release_start = release.index("## Approved-plan transition hooks")
release_end = release.index("\n## Starting a new loop", release_start)
release_contract = release[release_start:release_end]
assert sha256(normalize(release_contract).encode()).hexdigest() == "58c7c26b556adeb8a68c29beac7cd24d2df89883c54c5b768c8834bc50125adb"

for contract, clause in (
    (shipping_contract, "Revalidate the plan `body_seal` immediately before running it."),
    (shipping_contract, "any failure blocks cleanup"),
    (shipping_contract, "an outward transition still requires first-hand confirmation at the point of risk"),
    (release_contract, "before Phase 6"),
    (release_contract, "A missing, failed, cancelled, or unverifiable transition blocks the loop in Ship"),
    (release_contract, "only the human or orchestrating session receiving first-hand approval executes it"),
    (release_contract, "Transition IDs are globally unique across both families"),
    (release_contract, "Duplicate IDs, duplicate row claims, missing rows, or extra mappings block Ship before any transition runs."),
    (release_contract, "resume never re-enters pre-merge `shipping`"),
):
    assert clause in contract
    assert normalize(contract.replace(clause, "", 1)) != normalize(contract)
PY
test "$(find .release-loop/evidence/U4 -maxdepth 1 -type f -name 't6-r2-gate-*.md' | wc -l | tr -d ' ')" = 6
test "$(find .release-loop/evidence/U4 -maxdepth 1 -type f | wc -l | tr -d ' ')" = 18
test "$(find .release-loop/evidence/U4 -maxdepth 1 -type f -name 't7-sc6-completion-*.md' | wc -l | tr -d ' ')" = 6
bash scripts/validate.sh | tail -1 | grep -q 'ALL CHECKS PASSED'
test "$(find .release-loop/evidence/U4 -maxdepth 1 -type f -name 't5-state-transfer-*.md' | wc -l | tr -d ' ')" = 6
```

## U5: Persist the independent invariant-attack review

Files:
  Create: docs/reviews/2026-08-15-planning-discrimination-and-verdict-coverage-implementation-review.md, .release-loop/evidence/U5/final-branch-review.json
Depends on: U1, U2, U3, and U4, all committed and individually reviewed.
Steps:
  1. Generate the full branch diff and a canonical path/size/SHA-256 manifest of the exact matrix records under `.release-loop/evidence/U3/` and `.release-loop/evidence/U4/`, then dispatch an independent reviewer with the approved spec, body-sealed plan plus addendum 012, that evidence manifest, SC2, and SC3. Give five instructions verbatim: re-derive the carry-forward audit against the final file list; repeat the SC2/SC3 invariant attacks against the shipped wording rather than checking conformance to this plan; attack U4/R1/R2 lifecycle ordering, identity, recovery, consent boundaries, and the same-session release-loop→shipping→R1 handoff; grade findings by the success criterion threatened rather than code blast radius; and return bounded findings plus a final verdict. Require the response to identify reviewer, reviewer session, model, and the reviewed artifact hashes.
  2. Persist the bounded reviewer output to `docs/reviews/2026-08-15-planning-discrimination-and-verdict-coverage-implementation-review.md`. The file contains `## Scope`, `## Carry-forward re-derivation`, `## SC2 invariant attack`, `## SC3 invariant attack`, `## Lifecycle attack`, `## Findings`, and `## Final verdict`. `## Scope` carries backticked `reviewer_identity`, `reviewer_session`, `reviewer_model`, `orchestrator_session`, `reviewed_head`, `full_diff_sha256`, `approved_spec_sha256`, `approved_plan_sha256`, `addendum_sha256`, and `u3_u4_evidence_manifest_sha256` fields; reviewer and orchestrator sessions differ. The attack sections record every reject and compliant case, observed result, and deciding clause. Scratch transcripts remain under `.release-loop/reviews/` and are not cited as durable evidence.
  3. If any actionable P0–P2 survives, return it to the owning unit, rerun that unit's review and this invariant attack against a fresh full diff/evidence manifest, and replace the bounded record. Proceed only when `## Final verdict` contains exactly `clean`; only P3 or explicitly non-actionable observations may remain. Any later change to U1–U4, the approved artifacts, or their evidence invalidates the record and restarts U5 from step 1.
  4. Commit: "docs(review): Persist planning invariant attack".
  5. Run the normal `implementing` final branch review against the exact U5 commit and write `.release-loop/evidence/U5/final-branch-review.json` with reviewer identity/session/model, `reviewed_head`, full branch-diff SHA-256, and verdict. If the review causes any file change or commit, delete the stale final-review evidence, rerun U5 steps 1–4 against the new parent, and rerun this final review. Phase 4 requires the final-review `reviewed_head` to equal current `HEAD`, its verdict to be `clean`, and the committed U5 record's `reviewed_head` to equal current `HEAD^`.
Acceptance: the committed file contains all seven headings; the provenance program below proves reviewer independence/freshness and byte-matches the reviewed U1–U4 HEAD, full branch diff, approved spec/plan/addendum, and evidence manifest; it also proves the post-U5 final review covers exact current `HEAD` with a clean verdict; SC2 names rejects A–D, the guard reject, and the compliant case; SC3 names rejects A–C and the compliant case; Lifecycle attack names the R1 same-session owner, identity, collision, symlink, marker-seam, mid-install, archive, handoff/resume-order, and R2 first-hand-gate/blocked-recovery cases; each case records an observed result and deciding clause; the final verdict is exactly `clean`. Phase 4 may take its documented clean fast path only after all of these checks pass.

```bash
python3 -I - <<'PY'
from hashlib import sha256
from pathlib import Path
import json
import re
import subprocess

record = Path("docs/reviews/2026-08-15-planning-discrimination-and-verdict-coverage-implementation-review.md").read_text()

def field(name):
    matches = re.findall(rf"^- {name}: `([^`]+)`$", record, re.M)
    assert len(matches) == 1
    return matches[0]

for name in ("reviewer_identity", "reviewer_session", "reviewer_model", "orchestrator_session"):
    assert field(name).lower() not in {"", "unknown", "n/a", "todo", "placeholder"}
assert field("reviewer_session") != field("orchestrator_session")

reviewed_head = subprocess.check_output(["git", "rev-parse", "HEAD^"], text=True).strip()
assert field("reviewed_head") == reviewed_head
base = subprocess.check_output(["git", "merge-base", "main", reviewed_head], text=True).strip()
full_diff = subprocess.check_output(["git", "diff", "--binary", base, reviewed_head])
assert field("full_diff_sha256") == sha256(full_diff).hexdigest()

for name, path in (
    ("approved_spec_sha256", "docs/specs/2026-08-15-planning-discrimination-and-verdict-coverage-design.md"),
    ("approved_plan_sha256", "docs/plans/2026-08-15-001-fix-planning-discrimination-and-verdict-coverage-plan.md"),
    ("addendum_sha256", "docs/deviations/2026-08-15-discrimination-axis-and-out-of-set-verdict-012.md"),
):
    assert field(name) == sha256(Path(path).read_bytes()).hexdigest()

outcomes = ("success", "forced-failure", "rerun", "rollback-compensation", "headless", "cancellation-abort")
stems = {
    "U3": ("t0-preparation", "t1-comment-11", "t2-close-11", "t3-comment-12", "t4-close-12"),
    "U4": ("t5-state-transfer", "t6-r2-gate", "t7-sc6-completion"),
}
expected = {
    str(Path(".release-loop/evidence") / unit / f"{stem}-{outcome}.md")
    for unit, unit_stems in stems.items()
    for stem in unit_stems
    for outcome in outcomes
}
actual = {
    str(path)
    for unit in stems
    for path in (Path(".release-loop/evidence") / unit).glob("*")
    if path.is_file()
}
assert actual == expected
evidence = [
    (path, Path(path).stat().st_size, sha256(Path(path).read_bytes()).hexdigest())
    for path in sorted(actual)
]
manifest_digest = sha256(json.dumps(evidence, separators=(",", ":")).encode()).hexdigest()
assert field("u3_u4_evidence_manifest_sha256") == manifest_digest

verdict = record.split("## Final verdict\n", 1)[1].split("\n## ", 1)[0].strip()

final_review = json.loads(Path(".release-loop/evidence/U5/final-branch-review.json").read_text())
current_head = subprocess.check_output(["git", "rev-parse", "HEAD"], text=True).strip()
assert final_review["reviewed_head"] == current_head
assert final_review["verdict"] == "clean"
for key in ("reviewer_identity", "reviewer_session", "reviewer_model"):
    assert str(final_review[key]).lower() not in {"", "unknown", "n/a", "todo", "placeholder"}
assert final_review["reviewer_session"] not in {field("reviewer_session"), field("orchestrator_session")}
assert subprocess.check_output(["git", "status", "--porcelain"]).strip() == b""
current_base = subprocess.check_output(["git", "merge-base", "main", current_head], text=True).strip()
current_diff = subprocess.check_output(["git", "diff", "--binary", current_base, current_head])
assert final_review["full_diff_sha256"] == sha256(current_diff).hexdigest()
assert verdict == "clean"
PY
```

## Release-loop Ship-cleanup transition R1: Preserve live state across removal
Matrix rows: T5

R1 is not an implementation unit. It runs inside Ship step 8 only after the merge and merged-result verification succeed, immediately before worktree removal. Owner and executor: the release-loop orchestrating session while it is executing `shipping` Step 8; the transition is never delegated to a worker.

1. Set `BASE_CHECKOUT` to the absolute checkout carrying `base_branch: main`. The program canonicalizes both paths, verifies the base path is exactly that repository's top level, verifies feature and base resolve to the same canonical Git common directory, verifies the base is on `main`, and refuses the feature checkout, a nested path, another repository, or another branch.
2. Run the Python transfer program below. It stages the latest feature-worktree `.release-loop/` children except `archive/` inside a uniquely owned base `.release-loop/.handoff/` operation and first proves an exact path/size/SHA-256 live-state copy. Before creating any marker, it requires the base's non-archive live state to be absent or to carry the same `feature`, `spec`, and `plan` identity as the source; unknown or different-feature base state fails untouched. Its identity-named owner directory is created atomically before the operation directory and removed only after the operation directory; foreign owner identities fail closed, and a rerun can recover either marker-seam cancellation without temporary marker residue. Inside staging, the program rewrites `branch`, `phase`, `phase_status`, `merged`, and `updated`, then appends the T5/base-authoritative Log line. It records the base archive manifest, moves only the base's non-archive entries to a backup, installs all non-progress staged entries, rechecks the transformed manifest, installs `progress.md` last as the commit point, and removes staging/backup only after success. A crash before that point leaves no authoritative destination ledger; a rerun restores from backup before attempting a fresh stage.

3. Treat the base copy as authoritative through the remaining cleanup, SC6, and Retro. Remove the feature worktree only after the transformed manifest matches, the base archive manifest is unchanged, the transferred frontmatter reads `branch: main`, `phase: ship`, `phase_status: in-progress`, and `merged: true`, and all six T5 fixture records exist under the transferred `.release-loop/evidence/U4/`.
4. No git commit: this is a verified transfer of gitignored runtime state inside the fixed Ship cleanup order.

```bash
set -euo pipefail
test -n "${BASE_CHECKOUT:?set by release-loop orchestrator}"
FEATURE_CHECKOUT=$(pwd -P)
BASE_CHECKOUT=$(cd "$BASE_CHECKOUT" && pwd -P)
test "$BASE_CHECKOUT" != "$FEATURE_CHECKOUT"
test "$(cd "$(git -C "$BASE_CHECKOUT" rev-parse --show-toplevel)" && pwd -P)" = "$BASE_CHECKOUT"
test "$(git -C "$BASE_CHECKOUT" branch --show-current)" = main
FEATURE_GIT_COMMON=$(cd "$FEATURE_CHECKOUT" && cd "$(git rev-parse --git-common-dir)" && pwd -P)
BASE_GIT_COMMON=$(cd "$BASE_CHECKOUT" && cd "$(git rev-parse --git-common-dir)" && pwd -P)
test "$FEATURE_GIT_COMMON" = "$BASE_GIT_COMMON"
TRANSFER_TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
python3 -I - "$FEATURE_CHECKOUT/.release-loop" "$BASE_CHECKOUT/.release-loop" "$TRANSFER_TIMESTAMP" <<'PY'
from hashlib import sha256
from pathlib import Path
import json
import os
import re
import shutil
import sys
if sys.flags.optimize:
    raise SystemExit("optimized Python is forbidden for R1")
boundary_sentinel = os.environ.get("BOUNDARY_SENTINEL")
requested_fail_at = os.environ.get("FAIL_AT")
if requested_fail_at and boundary_sentinel != "local-copy-only":
    raise SystemExit("FAIL_AT requires BOUNDARY_SENTINEL=local-copy-only")
fail_at = requested_fail_at if boundary_sentinel == "local-copy-only" else None
if fail_at not in {None, "t5-mid-backup-copy", "t5-after-backup", "t5-mid-rollback-copy", "t5-mid-install-before-progress"}:
    raise SystemExit(f"unknown FAIL_AT seam: {fail_at}")

source, destination = map(Path, sys.argv[1:3])
timestamp = sys.argv[3]
if not re.fullmatch(r"\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z", timestamp):
    raise SystemExit("invalid date -u transfer timestamp")
handoff_root = destination / ".handoff"
operation = handoff_root / "planning-discrimination-and-verdict-coverage-R1"
stage = operation / "stage"
backup = operation / "backup"
backup_manifest_record = operation / "backup-manifest.json"
backup_manifest_temp = operation / ".backup-manifest.tmp"
assert source.is_dir() and not source.is_symlink()
if destination.exists():
    assert destination.is_dir() and not destination.is_symlink()
archive = destination / "archive"
if archive.exists():
    assert archive.is_dir() and not archive.is_symlink()
if handoff_root.exists():
    assert handoff_root.is_dir() and not handoff_root.is_symlink()
identity = {
    "destination": str(destination.resolve()),
    "operation": "planning-discrimination-and-verdict-coverage-R1",
    "source": str(source.resolve()),
}
identity_bytes = json.dumps(identity, sort_keys=True).encode()
owner = handoff_root / (
    "planning-discrimination-and-verdict-coverage-R1.owner-"
    + sha256(identity_bytes).hexdigest()
)

def manifest(root, include_archive=False):
    if not root.exists():
        return []
    result = []
    for path in sorted(root.rglob("*")):
        assert not path.is_symlink()
        relative = path.relative_to(root)
        if not include_archive and relative.parts[0] in {"archive", ".handoff"}:
            continue
        if path.is_dir():
            result.append((str(relative) + "/", 0, "directory"))
        else:
            assert path.is_file()
            result.append((str(relative), path.stat().st_size, sha256(path.read_bytes()).hexdigest()))
    return result

def live_children(root):
    if not root.exists():
        return []
    children = [child for child in root.iterdir() if child.name not in {"archive", ".handoff"}]
    assert all(not child.is_symlink() for child in children)
    return children

def remove(path):
    path.unlink() if path.is_symlink() or path.is_file() else shutil.rmtree(path)

def set_frontmatter(text, updates):
    lines = text.splitlines()
    assert lines[0] == "---"
    end = lines.index("---", 1)
    for key, value in updates.items():
        matches = [index for index in range(1, end) if lines[index].startswith(f"{key}:")]
        assert len(matches) == 1
        lines[matches[0]] = f"{key}: {value}"
    return "\n".join(lines) + "\n"

def progress_identity(root):
    path = root / "progress.md"
    if not path.is_file():
        return None
    lines = path.read_text().splitlines()
    assert lines[0] == "---"
    end = lines.index("---", 1)
    result = {}
    for key in ("feature", "spec", "plan"):
        matches = [line.split(":", 1)[1].strip() for line in lines[1:end] if line.startswith(f"{key}:")]
        assert len(matches) == 1
        result[key] = matches[0]
    return result

def progress_is_authoritative(root):
    path = root / "progress.md"
    if not path.is_file() or path.is_symlink():
        return False
    text = path.read_text()
    marker_suffix = " ship: T5 live state transferred after merged-result verification; evidence `.release-loop/evidence/U4/t5-state-transfer-success.md`; base-state-authoritative; worktree removal may proceed"
    markers = [line for line in text.splitlines() if line.endswith(marker_suffix)]
    if len(markers) != 1:
        return False
    timestamp_match = re.fullmatch(r"- (\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z)" + re.escape(marker_suffix), markers[0])
    if not timestamp_match:
        return False
    authoritative_timestamp = timestamp_match.group(1)
    expected = set_frontmatter((source / "progress.md").read_text(), {
        "branch": "main",
        "phase": "ship",
        "phase_status": "in-progress",
        "merged": "true",
        "updated": authoritative_timestamp,
    }).rstrip() + f"\n{markers[0]}\n"
    return text == expected

def read_backup_manifest():
    assert backup_manifest_record.is_file() and not backup_manifest_record.is_symlink()
    rows = json.loads(backup_manifest_record.read_text())
    assert all(isinstance(row, list) and len(row) == 3 for row in rows)
    return [tuple(row) for row in rows]

assert source.is_dir() and not source.is_symlink()
source_live = manifest(source)
source_without_progress = [row for row in source_live if row[0] != "progress.md"]
source_identity = progress_identity(source)
assert source_identity is not None
destination_live = manifest(destination)
if destination_live and not backup.exists():
    assert progress_identity(destination) == source_identity
destination.mkdir(exist_ok=True)
assert destination.is_dir() and not destination.is_symlink()
handoff_root.mkdir(exist_ok=True)
assert handoff_root.is_dir() and not handoff_root.is_symlink()
owner_candidates = list(handoff_root.glob("planning-discrimination-and-verdict-coverage-R1.owner-*"))
assert all(candidate == owner for candidate in owner_candidates)
if owner.exists():
    assert owner.is_dir() and not owner.is_symlink()
else:
    assert not operation.exists()
    owner.mkdir()
if operation.exists():
    assert operation.is_dir() and not operation.is_symlink()
else:
    destination_without_progress = [row for row in manifest(destination) if row[0] != "progress.md"]
    if destination_without_progress == source_without_progress and progress_is_authoritative(destination):
        owner.rmdir()
        if not any(handoff_root.iterdir()):
            handoff_root.rmdir()
        raise SystemExit(0)
    operation.mkdir()
destination_without_progress = [row for row in manifest(destination) if row[0] != "progress.md"]
if destination_without_progress == source_without_progress and progress_is_authoritative(destination):
    allowed_children = {stage, backup, backup_manifest_record, backup_manifest_temp}
    assert all(child in allowed_children for child in operation.iterdir())
    for directory in (stage, backup):
        if directory.exists():
            assert directory.is_dir() and not directory.is_symlink()
            shutil.rmtree(directory)
    for marker in (backup_manifest_record, backup_manifest_temp):
        if marker.exists():
            assert marker.is_file() and not marker.is_symlink()
            marker.unlink()
    shutil.rmtree(operation)
    owner.rmdir()
    if not any(handoff_root.iterdir()):
        handoff_root.rmdir()
    raise SystemExit(0)
for marker in (backup_manifest_record, backup_manifest_temp):
    if marker.exists():
        assert marker.is_file() and not marker.is_symlink()
if backup_manifest_temp.exists():
    if backup_manifest_record.exists():
        backup_manifest_temp.unlink()
    else:
        assert not backup.exists()
        backup_manifest_temp.unlink()
if backup.exists():
    assert backup.is_dir() and not backup.is_symlink()
    backup_expected = read_backup_manifest()
    backup_actual = manifest(backup)
    if backup_actual != backup_expected:
        assert manifest(destination) == backup_expected
        shutil.rmtree(backup)
        backup_manifest_record.unlink()
    else:
        destination_without_progress = [row for row in manifest(destination) if row[0] != "progress.md"]
        if destination_without_progress == source_without_progress and progress_is_authoritative(destination):
            if stage.exists():
                assert stage.is_dir() and not stage.is_symlink()
                shutil.rmtree(stage)
            shutil.rmtree(backup)
            backup_manifest_record.unlink()
            shutil.rmtree(operation)
            owner.rmdir()
            if not any(handoff_root.iterdir()):
                handoff_root.rmdir()
            raise SystemExit(0)
        for child in live_children(destination):
            remove(child)
        for index, child in enumerate(sorted(backup.iterdir())):
            target = destination / child.name
            shutil.copytree(child, target) if child.is_dir() else shutil.copy2(child, target)
            if fail_at == "t5-mid-rollback-copy" and index == 0:
                raise SystemExit("injected t5-mid-rollback-copy")
        assert manifest(destination) == backup_expected
        shutil.rmtree(backup)
        backup_manifest_record.unlink()
elif backup_manifest_record.exists():
    backup_expected = read_backup_manifest()
    assert manifest(destination) == backup_expected
    backup_manifest_record.unlink()
destination_live = manifest(destination)
if destination_live:
    assert progress_identity(destination) == source_identity
if stage.exists():
    assert stage.is_dir() and not stage.is_symlink()
    shutil.rmtree(stage)
stage.mkdir()
for child in source.iterdir():
    if child.name in {"archive", ".handoff"}:
        continue
    target = stage / child.name
    shutil.copytree(child, target) if child.is_dir() else shutil.copy2(child, target)
assert manifest(stage) == source_live
progress = stage / "progress.md"
progress.write_text(set_frontmatter(progress.read_text(), {
    "branch": "main",
    "phase": "ship",
    "phase_status": "in-progress",
    "merged": "true",
    "updated": timestamp,
}).rstrip() + f"\n- {timestamp} ship: T5 live state transferred after merged-result verification; evidence `.release-loop/evidence/U4/t5-state-transfer-success.md`; base-state-authoritative; worktree removal may proceed\n")
expected_live = manifest(stage)
assert [row for row in expected_live if row[0] != "progress.md"] == source_without_progress
assert progress_is_authoritative(stage)
archive_before = manifest(destination / "archive", include_archive=True)
destination_before = manifest(destination)
backup_manifest_temp.write_text(json.dumps(destination_before, separators=(",", ":")))
backup_manifest_temp.rename(backup_manifest_record)
backup.mkdir()
for index, child in enumerate(live_children(destination)):
    target = backup / child.name
    shutil.copytree(child, target) if child.is_dir() else shutil.copy2(child, target)
    if fail_at == "t5-mid-backup-copy" and index == 0:
        raise SystemExit("injected t5-mid-backup-copy")
assert manifest(backup) == destination_before
for child in live_children(destination):
    remove(child)
if fail_at == "t5-after-backup":
    raise SystemExit("injected t5-after-backup")
for child in [entry for entry in list(stage.iterdir()) if entry.name != "progress.md"]:
    child.rename(destination / child.name)
installed_without_progress = [row for row in manifest(destination) if row[0] != "progress.md"]
assert installed_without_progress == [row for row in expected_live if row[0] != "progress.md"]
assert manifest(destination / "archive", include_archive=True) == archive_before
if fail_at == "t5-mid-install-before-progress":
    raise SystemExit("injected t5-mid-install-before-progress")
(stage / "progress.md").rename(destination / "progress.md")
assert manifest(destination) == expected_live
assert manifest(destination / "archive", include_archive=True) == archive_before
shutil.rmtree(stage)
shutil.rmtree(backup)
backup_manifest_record.unlink()
shutil.rmtree(operation)
owner.rmdir()
if not any(handoff_root.iterdir()):
    handoff_root.rmdir()
PY
test "$(find "$BASE_CHECKOUT/.release-loop/evidence/U4" -maxdepth 1 -type f -name 't5-state-transfer-*.md' | wc -l | tr -d ' ')" = 6
```

## Release-loop post-Ship completion transition R2: Discharge SC6
Matrix rows: T1, T2, T3, T4, T6, T7

R2 is not an implementation unit. U4 owns its hook; the release-loop orchestrator executes it only after `shipping` returns a merged-and-cleaned exit and R1's authoritative base ledger is available, and before Phase 6. A dispatched worker never executes it.


1. From the base checkout, read the committed command packet and the authoritative ledger. Present the exact repository, issues, payload paths, and all four possible mutation commands to the user. State that the packet reads before every write and skips exact comments or closed states already present.
2. Obtain point-of-risk USER confirmation in the orchestrating session. Decline, deferral, relayed approval, or headless mode atomically records `phase: ship`, `phase_status: blocked`, a non-null SC6 `blocked_reason`, and a Log line; stop before extraction or execution. On direct approval, atomically append a timestamped Log line naming `approver=USER`, the receiving release-loop orchestrator, target `teslamint/compound-loop#11,#12`, packet SHA-256 `8168d671af3c457c36afa79e8b8c0217fbce96af0f07e7e8dc563687b8b1aaa7`, the four covered mutations, and the consent scope before extraction, then continue directly to step 3. Only the explicit fixture seam `FAIL_AT=t6-after-approval-before-extraction` stops after the durable append and before extraction. This record proves that event but never carries reusable authorization: a new session or rerun requires fresh first-hand approval.
3. After direct approval is durably recorded, first verify the whole Markdown packet SHA-256 equals U3's literal `8168d671af3c457c36afa79e8b8c0217fbce96af0f07e7e8dc563687b8b1aaa7`. Verify both current and `HEAD` payload bytes equal U3's literal SHA-256 pins before any mutation. Extract the packet's single fenced `bash` body in memory, derive a separate command-body SHA-256, write the body to a temporary file, require the file's SHA-256 to equal that derived body digest, run `bash -n`, then execute that exact temporary file. Do not extract from a mutable path again after verification.
4. On nonzero exit, perform fresh read-only issue views, report which exact comment/close transitions landed and which remain, then atomically write `phase: ship`, `phase_status: blocked`, a non-null failure-specific `blocked_reason`, refreshed `updated`, and a Log line carrying the landed/missing transition evidence. Require fresh point-of-risk confirmation before rerunning the same packet. Never replay individual raw commands from memory.
5. On exit 0, independently rerun the packet's final read-only issue views/body comparison, then atomically set `phase_status: complete`, clear `blocked_reason: null`, refresh `updated`, and append the timestamped SC6 evidence line with both issue states, exact payload hashes, the verified packet hash, the separately derived command-body hash, and whether this recovered from a blocked state. Only then may release-loop advance to Retro.

Acceptance: T1–T4's matrix evidence matches the current packet bytes; packet SHA-256 equals U3's literal while the temporary executable equals the separately derived command-body SHA-256; a fixture read failure produces zero mutations; post-write failures converge without duplicate comments or close calls; decline/headless paths write a schema-valid blocked state; every outward attempt has a fresh pre-execution approval event; and success writes one ISO-8601 SC6 ledger line before the Phase-6 transition.

## Mutation/failure-state matrix

The deliverable contains a stateful ceremony: U3 persists its packet, R2 later owns four possible `gh issue` mutations, and shipping executes R1 to transfer authoritative live loop state before worktree removal. The matrix follows `skills/planning/references/stateful-ceremony-matrix-example.md`; any post-approval row/outcome change follows `docs/solutions/workflow-issues/review-introduced-state-machine-deviation.md`.

T0–T4 evidence uses only a disposable temporary state store and a fixture `gh` executable prepended to `PATH`. Every record proves `command -v gh` resolves inside that fixture, records the stub hash and complete target inventory, shows all real host/token variables unset, and carries `BOUNDARY_SENTINEL=gh-stub-only`. The stub accepts the packet's literal repository and issue arguments but performs no network call. It models both read failures and post-write failures: read failure must terminate with zero mutation calls, while a repeated approved invocation after a partial write skips every already-landed transition. T5 evidence uses a disposable Git repository with linked `main` and feature worktrees plus a separate foreign `main` repository and `BOUNDARY_SENTINEL=local-copy-only`; its base `archive/` contains a sentinel that must remain byte-identical, and the foreign repository must remain untouched. U3 is the sole T0–T4 fixture evidence owner; U4 owns the transition hooks and all T5 fixture evidence. Shipping executes R1; release-loop executes R2. Each row produces the six exact records below with the fields required by `implementing` step 4.

| ID | Pre-state | Action | Expected post-state | Owner / evidence owner | Success | Forced failure | Rerun | Rollback or compensation | Headless | Cancellation or abort |
|---|---|---|---|---|---|---|---|---|---|---|
| T0 Packet, payload, and ledger persistence | U1/U2 committed; no U3 commit; fixture issues open with no comments | Write the two exact payloads, raw-byte-sealed packet, exact ledger suffix, validate, then commit the three tracked files | One U3 commit contains all three exact files; ledger suffix exists; fixture remote unchanged | U3 / `.release-loop/evidence/U3/t0-preparation-<outcome>.md` | `t0-preparation-success.md`: commit OID, three file hashes, ledger match, zero stub calls | Fixture pre-commit hook exits nonzero when `FAIL_AT=t0-before-commit`; expected partial state is validated local files plus ledger line but unchanged `HEAD` and zero stub calls; record hook marker and before/after OID | `t0-preparation-rerun.md`: same validated bytes produce one commit; an existing matching commit is not duplicated | `t0-preparation-rollback-compensation.md`: remove only U3's uncommitted fixture files/ledger line after hash match; a committed bad packet is corrected by a new reviewed commit, never history rewrite | `t0-preparation-headless.md`: local preparation succeeds with the non-authorization marker and zero stub calls; no outward action follows | `t0-preparation-cancellation-abort.md`: abort before commit leaves U1/U2 `HEAD` and fixture issues unchanged; uncommitted U3 files are reported, not silently discarded |
| T1 Comment issue #11 | Exact U3 commit merged; issue #11 open; exact comment absent; issue #12 untouched; fresh point-of-risk approval recorded | `gh issue comment 11 --repo teslamint/compound-loop --body-file docs/issue-closures/2026-08-15-issue-11.md` | Issue #11 remains open with exactly one exact payload comment; issue #12 unchanged | U4 live transition owner; U3 evidence owner / `.release-loop/evidence/U3/t1-comment-11-<outcome>.md` | `t1-comment-11-success.md`: stub call, body hash, one stored exact comment | Stub writes the comment, then exits nonzero when `FAIL_AT=t1-after-comment-write`; expected partial state is one exact #11 comment, both issues open, #12 comment absent; record injected marker and stored body hash | `t1-comment-11-rerun.md`: read detects the exact comment and skips reposting; recovery advances to T2 only after fresh approval for missing actions | `t1-comment-11-rollback-compensation.md`: no automatic rollback; deletion of a mistaken/duplicate live comment requires separate first-hand approval and its comment ID, then SC6 restarts from fresh reads | `t1-comment-11-headless.md`: preparation-only terminal state, zero stub mutation calls, SC6 blocked | `t1-comment-11-cancellation-abort.md`: before call leaves no comment; after durable write leaves the exact comment and SC6 blocked at T2, with no automatic deletion |
| T2 Close issue #11 | T1 exact comment present; issue #11 open; issue #12 untouched; fresh approval covers T2 | `gh issue close 11 --repo teslamint/compound-loop` | Issue #11 `CLOSED` with exact comment; issue #12 open and uncommented | U4 live transition owner; U3 evidence owner / `.release-loop/evidence/U3/t2-close-11-<outcome>.md` | `t2-close-11-success.md`: state transition OPEN→CLOSED and retained body hash | Stub sets #11 `CLOSED`, then exits nonzero when `FAIL_AT=t2-after-close-write`; expected partial state is #11 closed with exact comment and #12 untouched; record marker and both issue states | `t2-close-11-rerun.md`: read detects `CLOSED` and does not close again; recovery advances to T3 after fresh approval | `t2-close-11-rollback-compensation.md`: no automatic reopen; an erroneous live closure is reopened only under separate first-hand approval, then verified | `t2-close-11-headless.md`: zero close calls; #11 stays open; SC6 blocked | `t2-close-11-cancellation-abort.md`: before call preserves T1; after durable write preserves the closed state and resumes at T3 |
| T3 Comment issue #12 | T2 complete; issue #12 open; exact #12 comment absent; fresh approval covers T3 | `gh issue comment 12 --repo teslamint/compound-loop --body-file docs/issue-closures/2026-08-15-issue-12.md` | #11 remains closed; #12 remains open with exactly one exact payload comment | U4 live transition owner; U3 evidence owner / `.release-loop/evidence/U3/t3-comment-12-<outcome>.md` | `t3-comment-12-success.md`: one #12 comment with exact body hash and unchanged #11 | Stub writes #12 comment, then exits nonzero when `FAIL_AT=t3-after-comment-write`; expected partial state is #11 closed, #12 open with one exact comment; record marker and call log | `t3-comment-12-rerun.md`: exact existing comment is detected and not duplicated; recovery advances to T4 after fresh approval | `t3-comment-12-rollback-compensation.md`: no automatic deletion; mistaken/duplicate live comment deletion requires separate first-hand approval and comment ID | `t3-comment-12-headless.md`: zero #12 mutation calls; T2 state retained; SC6 blocked | `t3-comment-12-cancellation-abort.md`: before call retains T2; after durable write retains one #12 comment and resumes at T4 |
| T4 Close issue #12 and verify terminal state | T3 complete; #12 open with exact comment; #11 closed with exact comment; fresh approval covers T4 | `gh issue close 12 --repo teslamint/compound-loop`, then the packet's two read-only exact-body/state queries | Both issues `CLOSED`; each has its exact payload; SC6 may pass | U4 live transition owner; U3 evidence owner / `.release-loop/evidence/U3/t4-close-12-<outcome>.md` | `t4-close-12-success.md`: both CLOSED states, both exact body hashes, verification exit 0 | Stub sets #12 `CLOSED`, then makes the first verification read exit nonzero when `FAIL_AT=t4-after-close-before-verify`; expected partial state is both issues closed with exact comments but SC6 unverified; record marker and stored states | `t4-close-12-rerun.md`: fresh reads detect all transitions complete; no comment/close command repeats, only verification reruns | `t4-close-12-rollback-compensation.md`: no rollback for a correct terminal state; a wrong live closure/comment requires separately approved reopen/delete compensation and a full fresh verification | `t4-close-12-headless.md`: zero mutation calls and no completion claim; prior partial state is reported | `t4-close-12-cancellation-abort.md`: before close retains T3; after close but before verification retains terminal remote state while SC6 remains blocked until reads pass |
| T5 Live loop-state transfer | Merge and merged-result verification passed; Ship cleanup reached R1; feature and base are linked worktrees sharing one canonical Git common directory; feature non-archive `.release-loop/` live state authoritative; base live copy absent/stale; base `archive/` retained; source and prior base contain nested empty-directory sentinels | R1 rejects foreign repositories and identity collisions, stages only non-archive live state, builds canonical manifests containing both file hashes and explicit directory entries, proves an exact source copy, transforms staged `progress.md`, records the complete prior-base manifest before copying any backup entry, copies and verifies the backup, installs and verifies every non-progress entry, installs authoritative `progress.md` last as the commit point, rechecks the full manifest/archive identity, then deletes backup before its manifest marker and permits worktree removal | Base non-progress files and directories equal feature source exactly; transformed base ledger is authoritative for Ship; prior-base empty directories survive every rollback; base archive unchanged; feature source remains until cleanup; foreign/collision sentinels untouched | U4 / `.release-loop/evidence/U4/t5-state-transfer-<outcome>.md` | `t5-state-transfer-success.md`: canonical paths/common-dir equality, hook dispatch order, source/staged/base file-and-directory manifests, transformed-ledger fields, before/after archive manifest, identity-named owner, and authoritative marker | Fixture exits at `FAIL_AT=t5-mid-backup-copy`, `FAIL_AT=t5-after-backup`, `FAIL_AT=t5-mid-rollback-copy`, and `FAIL_AT=t5-mid-install-before-progress`; each first run exits nonzero; expected partial states preserve the exact recorded prior-base manifest including nested empty-directory entries, complete source/stage, verified complete-or-detectably-partial backup as applicable, omit any authoritative destination ledger before commit point, keep archive unchanged, and block worktree removal | `t5-state-transfer-rerun.md`: each one-crash fixture's second run exits zero and exactly preserves the prior-base file-and-directory manifest through recovery before installing the source manifest; the after-backup then mid-rollback-copy two-crash fixture exits nonzero twice and its third run exits zero with the same exact preservation; owner-before-operation, operation-before-owner-removal, and resume-before/during/after-R1 cases all converge; merged state never re-enters pre-merge shipping; R1 never executes twice | `t5-state-transfer-rollback-compensation.md`: before commit point restore the exact recorded backup file-and-directory manifest or fail closed without deleting the record; after verified commit point keep base authoritative and retain source until normal cleanup; mismatched owner/foreign repository remain untouched | `t5-state-transfer-headless.md`: deterministic local R1 is allowed with unreachable outward boundary; R2 remains blocked without first-hand approval | `t5-state-transfer-cancellation-abort.md`: marker seams, mid-backup, mid-rollback, and mid-install preserve a recoverable owned operation; before commit point feature stays authoritative and removal is blocked; after commit point base stays authoritative and resume continues pending cleanup/R2 |
| T6 R2 durable consent gate | Shipping returned merged-and-cleaned; R1 accepted; authoritative base ledger is `phase: ship`, `phase_status: in-progress`, `merged: true`; no reusable approval | Present exact target, packet hash, payloads, and four possible mutations; direct USER approval durably appends the timestamped approval event before extraction and normally continues directly to T7, while decline/deferral/relayed/headless atomically writes blocked Ship state | Exactly one current-session approval event permits T7, or a schema-valid blocked state prevents extraction, mutation, and Phase 6; old events never authorize retry | U4 / `.release-loop/evidence/U4/t6-r2-gate-<outcome>.md` | `t6-r2-gate-success.md`: current USER/orchestrator, exact target/hash/four mutations, timestamp, zero mutation calls at the durable-append point, then direct continuation into T7 | `t6-r2-gate-forced-failure.md`: `FAIL_AT=t6-after-approval-before-extraction` exits nonzero after the durable approval append; event retained, zero mutation calls, T7 not entered | `t6-r2-gate-rerun.md`: prior event is reported but fresh first-hand approval is required; the new timestamped event then gates T7 without another unconditional stop | `t6-r2-gate-rollback-compensation.md`: never erase the audit event; atomically block Ship and require a new gate | `t6-r2-gate-headless.md`: no approval event, zero mutation calls, blocked reason, Phase 6 unreachable | `t6-r2-gate-cancellation-abort.md`: cancellation before answer or after append records blocked Ship state; resume asks again and never infers consent |
| T7 SC6 completion and Retro release | T6 current-session approval recorded; packet whole-file digest verified; command-body digest derived; SC6 incomplete; T1–T4 may be wholly or partly landed | Verify extracted bytes, execute the idempotent packet, perform independent exact-body/state reads, then atomically complete Ship, clear `blocked_reason`, append SC6 evidence, and permit Phase 6 | Both issues CLOSED with exact bodies; one SC6 completion line records payload/packet/body hashes and recovery status; `phase_status: complete`, `blocked_reason: null`; Phase 6 reachable only now | U4 / `.release-loop/evidence/U4/t7-sc6-completion-<outcome>.md` | `t7-sc6-completion-success.md`: verified digests/states, completion fields/log, dispatch `T7-verified → Phase6` | `t7-sc6-completion-forced-failure.md`: read failure causes zero writes, or post-write failure records landed/missing transitions and atomically blocks Ship before Phase 6 | `t7-sc6-completion-rerun.md`: routes through fresh T6 approval, skips landed transitions, never duplicates comment/close calls, re-verifies, clears block, and reaches Phase 6 once | `t7-sc6-completion-rollback-compensation.md`: no automatic remote rollback; wrong live state requires separately approved compensation, then fresh T6/T7 | `t7-sc6-completion-headless.md`: zero new mutations, SC6 unmet, blocked Ship, Phase 6 unreachable | `t7-sc6-completion-cancellation-abort.md`: cancellation before/during execution records exact landed/missing state and blocks; cancellation after remote terminal state but before verification still blocks until fresh reads and fresh approval succeed |

Runtime gate: U3 prepares and commits the payloads and packet; possession is not authorization. Shipping executes R1 only on the merge path after merged-result verification and before worktree removal; discard executes no R transition. U4's release-loop hook routes merged-state resumes through owned handoff recovery, pending cleanup, and R2 without re-entering pre-merge shipping. R2 presents the exact target, packet hash, payloads, and four possible mutations and obtains point-of-risk USER confirmation. Decline, deferral, relayed approval, or headless mode atomically records blocked Ship state with SC6 unmet. Direct approval is durably recorded before extraction but never reused across sessions or reruns. Only the human or orchestrating session receiving first-hand approval executes the verified packet body. Reads fail closed before each possible write; partial writes are reported with landed/missing evidence and require fresh confirmation; successful recovery clears `blocked_reason`, independently verifies exact bodies/states, writes the SC6 completion record, and only then advances to Retro. A dispatched worker never mutates GitHub.

## Carry-forward trigger audit

Classification per step 5a against the final File structure table, with recorded fired-state annotations read first (latching) and the tiebreak applied. Tracker: `ROADMAP.md` — nine open carry-forward rows plus twelve open Future-candidate rows.

| Tracker row (ROADMAP.md line) | Class | Fired by | Disposition |
|---|---|---|---|
| Conformance suite (12) | event-based | Latched: the row carries `**fired**` and stays open | Deferred with reason |
| Schema validators + fixtures (13) | event-based | Latched: the row carries `**fired**`; review-envelope/v1 half remains open | Deferred with reason |
| Post-Retro terminal criterion cannot be measured in Retro (53) | event-based | Not fired: SC6 resolves after merged-result verification but before Ship completion and Retro | — |
| Shipping can delete the worktree owning live loop state (54) | edit-based by tiebreak | **Fired**: U4 changes `skills/shipping/SKILL.md` and `skills/release-loop/SKILL.md` | Folded: R1 transfers and transforms the latest non-archive loop state into base after merged-result verification, verifies archive identity, then permits worktree removal; resume routing reaches pending transitions from the authoritative base |
| Forced-failure matrices omit partial durable state (55) | edit-based by tiebreak | **Fired**: U1/U2 change `skills/planning/SKILL.md` | Deferred with reason |
| Loop artifacts outliving their loop sit only in gitignored state (57) | edit-based by tiebreak | **Fired**: U3/U4 and Phase 4 create post-merge obligations/evidence | Folded: payloads, command packet, and bounded implementation review land in committed paths; R1 transfers authoritative runtime evidence before cleanup; the ledger carries pointers and literal commands |
| Reviewer output is never persisted (58) | edit-based by tiebreak | Not fired by its named file trigger; voluntarily discharged for this cycle | Folded voluntarily: Phase 4 writes and commits the bounded reviewer findings and verdict under `docs/reviews/` |
| Review verifies conformance instead of attacking the invariant (59) | event-based | **Fired**: this cycle's deliverable is an integrity mechanism | Deferred as a durable-rule change; satisfied procedurally by the Design review, plan reviews, and mandated Phase-4 invariant attack |
| Finding severity graded by blast radius instead of threatened criterion (60) | event-based | **Fired**: reviews triage findings against the mechanism this cycle exists to build | Deferred as a durable-rule change; every review grades against threatened criteria |
| Human-discharged criterion has no gate blocking completion (61) | event-based | **Fired**: SC6 requires comments and closures outside dispatched-worker authority | Folded: U4's post-Ship hook consumes the committed packet only after a durable point-of-risk gate, names the first-hand execution owner, blocks on decline/failure, and requires post-action body/state verification |
| Dispatched agents' commits land unsigned (62) | event-based | Not fired at plan time: implementation handoff has not selected Serial subagents or Inline | Conditional control: if Serial subagents is selected, pass the actual `SSH_AUTH_SOCK`, verify `%G?` after every commit, and latch the row; Inline creates no dispatched-commit event |
| Session-history search (14), compound-refresh auto-apply (15), cross-round deepening suppression (16), demo/evidence capture (17), project-defined lane schema (18), ambient compound triggers (19), Gemini support verification (20), evidence-tier vocabulary (21), skill-level trace evidence (22), new-skill distinctness gate (23) | event-based | Not fired: each names an external occurrence absent from this cycle | — |

Audited ROADMAP.md at 68ffafe: 21 open rows, 8 fired, 0 unobservable. The Phase-4 reviewer must re-derive these counts and verdicts against the then-current final file list; this table is not self-authenticating.

## Deferred to Follow-Up Work

- **ROADMAP row 12 (conformance suite)** — fired via latching. Deferred: the row itself records that the suite build stays deferred to its own cycle, and this spec ships no test harness. The firing is recorded here so the row keeps its latch.
- **ROADMAP row 13 (schema validators + fixtures)** — fired via latching, review-envelope/v1 half still open. Deferred: no validator work is in this spec's file set; the row's original trigger continues to govern.
- **ROADMAP row 55 (forced-failure matrices omit exact partial durable state)** — fired, because U1/U2 change the planning contract. This cycle now satisfies the requirement procedurally with T0–T7, including exact injection seams, expected partial states, rerun behavior, and compensation owners. The durable remedy still edits the matrix contract in `schemas/plan-schema.md` and planning step 10, both outside the approved spec's file set, so that reusable rule remains deferred to the next planning-contract change that touches the matrix.
- **ROADMAP row 59 (attack the invariant instead of verifying conformance)** — fired, and satisfied procedurally twice this cycle: the Design-gate attack produced five wording repairs and the plan-gate attack produced two more plus addendum 012. Deferred as a durable-rule change: writing the construction requirement into `skills/reviewing/SKILL.md`'s dispatch steps is outside this spec's file set, so the row stays open for the cycle that edits that file.
- **ROADMAP row 60 (severity graded by threatened criterion)** — fired, and satisfied procedurally this cycle: every review dispatch prompt carried the row's rule verbatim, and both lanes graded the loopholes P0 because they threatened SC2 and SC3 rather than by code reachability. Deferred as a durable-rule change for the same reason as row 59.
- **The plan-schema mirror plus a `validate.sh` agreement check** — the origin spec's Open Decision 1, resolved at the Design gate as prose only. Trigger to build: the first plan authored under these checks that ships with a comparison step or a consumed verdict and omits its required trace.
- **`CHANGELOG.md` entry for the two checks** — step 12 assigns changelog entries to `shipping`, never to a planning unit. The repository has no unreleased heading, so `shipping` creates one when it next cuts a release.
- **A `grep` recipe that excludes `.release-loop/`** — the Assumption Recheck row for step 14 mirroring now matches this loop's own ledger. Measurement hygiene only; no behavior depends on it.

## Open unknowns

**Planning-time**: none. The origin spec's Open Decision 2 remains resolved in favor of step 14: the mutation/failure-state matrix enumerates durable transition outcomes, while Verdict coverage enumerates diagnostic value categories.

**Implementation-time** (deferred by design):
- Exact line wrapping of the two inserted bullets in the skill file. The normalized complete-bullet checks deliberately ignore wrapping while rejecting any textual clause change.
- Exact timestamps and reviewer verdict content in the Phase-4 committed review record; its path and required bounded shape are fixed here, but the observations must come from the future run.

## Verification summary

Per-unit acceptance programs above compare complete normalized bullets, then prove named clause deletions fail. Spec criteria:

- **SC1** — after U2: bullet count `12`, name count `2`, bullet 4 named `Verdict coverage`, last bullet named `Discrimination check`; both complete normalized bullet digests equal the literals in U1/U2.
- **SC2** — reject A: issue #11's different-kind `.mlmodelc`/`.mlpackage` digest comparison. Reject B: two identical `.mlpackage` conversions whose model and weight data match but whose whole-package digests differ because `Manifest.json` carries fresh UUIDs; the invariance pair fails. Reject C: same-kind `coremldata.bin` digests differ only because the source package changed while `--optimize` affects `weights.bin`; the changed axis is irrelevant. Reject D: the changed option alters only metadata or a receipt while the named effect-bearing signal stays equal. Guard reject: both pass and fail fixtures are accepted. Accept: two same-kind pairs from the real pipeline, with identical inputs/configuration comparing equal and only the option under test changed in the second pair, whose named effect-bearing signal compares different; a guard counterpart records one pass and one fail. Pass requires all rejects, then accepts, with the deciding clause quoted.
- **SC3** — reject A: issue #12's three-hypothesis spec, two-value declared set, two branches, no Deferred entry. Reject B: known set `{0,1}` plus a special branch for out-of-set `2`, while produced value `3` remains branchless; one representative does not cover the complement. Reject C: deleting either the catch-all rejection or unconsumed-verdict clause from an otherwise complete bullet. Accept: every known value has a value-specific branch or Deferred entry, unresolved measurement has a category-specific next step, and any value outside the known set has a category-specific next step. Pass requires each reject then accept with the deciding clause quoted.
- **SC4** — `bash scripts/validate.sh` → `ALL CHECKS PASSED`, exit 0.
- **SC5** — `bash scripts/test-retro-format-drift.sh` → `ALL CASES PASSED`, exit 0.
- **SC6** — pipeline side: U3's two payloads, separate committed packet, and ledger record pass their complete-content checks. Human side: after merge verification, the point-of-risk gate resolves, a first-hand owner executes the exact commands, and bounded issue reads prove both exact comments exist and both states are `CLOSED`. The criterion remains unmet on prepared files, relayed approval, comment-only state, close-only state, or unverified execution.

Risk mitigation traceability:

| Spec risk | Mitigation carrier |
|---|---|
| Checks ship as unenforceable prose | U1/U2 exact normalized checks, mutation probes, SC2/SC3 invariant attacks, and committed U5 review |
| Step 14 grows to twelve checks | Trigger-shaped bullet openings and scenario S3 |
| A checker guessing shapes from plan prose produces false verdicts | No plan-body checker ships; mirror remains deferred behind the approved trigger |
| Verdict wording is skimmed | Complete-bullet equality plus mutation probes for complement, catch-all, and unconsumed clauses |
| The new checks cannot validate their own plan | Carry-forward row 59 and the U5 independent invariant attack |
| Consuming-repository incidents mistaken for local evidence | U3 explicitly distinguishes H3 observations from reviewer constructions; SC2/SC3 are applied as plan-text rubrics |

U5 dispatch carries five instructions verbatim: re-derive the carry-forward audit against the final file list; repeat the SC2/SC3 invariant attacks against the shipped wording rather than checking conformance to this plan; attack U4/R1/R2 lifecycle ordering, identity, recovery, consent boundaries, and the same-session release-loop→shipping→R1 handoff; grade findings by the success criterion threatened rather than code blast radius; and return bounded findings plus a final verdict. U5 writes and commits that record before the normal final branch review. Phase 4 only verifies the committed U5 record plus the final branch review and may take its documented clean fast path only when both are clean; scratch output in `.release-loop/reviews/` is not durable evidence.
