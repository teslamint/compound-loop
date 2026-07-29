# Verification Before Completion

Ported from SP `verification-before-completion`, faithfully. Applies to every claim made anywhere in `shipping` -- tests pass, CI is green, a comment is resolved, the branch is clean -- not only the Step 1 gate.

**Core principle:** evidence before claims, always. Violating the letter of this rule is violating the spirit of it.

## The Iron Law

```
NO COMPLETION CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE
```

If the verification command has not been run in this message, the claim cannot be made yet.

## The gate function

```
BEFORE claiming any status or expressing satisfaction:

1. IDENTIFY: what command proves this claim?
2. RUN: execute the FULL command (fresh, complete)
3. READ: full output, exit code, failure count
4. VERIFY: does the output confirm the claim?
   - NO  -> state the actual status, with evidence
   - YES -> state the claim, WITH the evidence
5. ONLY THEN: make the claim

Skip any step = lying, not verifying.
```

## Evidence-tier ladder

Completion evidence is ranked on a fixed descending ladder of strength:

```
failing-repro-now-passing > end-to-end run > integration test > unit test > typecheck/build
```

Canonical definitions of the five tiers live in the repo-root `CONCEPTS.md` (`## Completion evidence`) when that file is present; this section restates only the order and its operating rules so the skill executes standalone. The ladder applies to every completion claim this file governs -- name the tier cited whenever reporting evidence for a claim:

- Typecheck/build alone never closes a completion claim.
- Evidence that fits no tier (for example, a structural validation run proving a docs-only change) is cited tier-free -- never forced into a tier label.

## Binary completion report

Exactly two surfaces are bound to this form: the Step 1 verification-gate report, and the evidence cited for a claim -> evidence table row when that claim is formally reported. On those two surfaces, use exactly one of:

```
verified: <observation>
unverified: <blocker>
```

naming the evidence tier where one applies (tier-free evidence is cited without a tier label). No hedged middle state. One example of each form:

- `verified: pytest -q -> 124 passed, 0 failed (integration tier)`
- `unverified: no test suite exists; highest evidence is typecheck (build tier)`

Conversational narration elsewhere in shipping (Steps 4/6/7) stays governed by the existing red-flag list only -- it is not bound to the binary form.

## Claim -> evidence table

| Claim | Requires | Not sufficient |
|---|---|---|
| Tests pass | test command output, 0 failures | a previous run, "should pass" |
| Linter clean | linter output, 0 errors | a partial check, extrapolation |
| Build succeeds | build command, exit 0 | linter passing, "logs look good" |
| Bug fixed | test of the original symptom, passes | code changed, assumed fixed |
| Regression test works | red-green cycle verified (below) | test passes once |
| Agent (subagent) completed | VCS diff shows the changes | agent reports "success" |
| Requirements met | line-by-line checklist against the plan | tests passing |
| CI is green | fresh `gh pr checks`, all green | "it was green last time" |
| Review comment resolved | re-fetched thread state after reply | commit-message summary, memory |

## Red flags -- stop

- Using "should", "probably", "seems to"
- Expressing satisfaction before verification ("Great!", "Perfect!", "Done!")
- About to commit, push, open a PR, or merge without verification
- Trusting an agent's or subagent's success report
- Relying on partial verification
- Thinking "just this once"
- Any wording that implies success without having run verification

## Rationalization-prevention table

| Excuse | Reality |
|---|---|
| "Should work now" | Run the verification. |
| "I'm confident" | Confidence is not evidence. |
| "Just this once" | No exceptions. |
| "Linter passed" | Linter is not the compiler, and neither is CI green from an earlier push. |
| "Agent said success" | Verify independently -- check the diff. |
| "I'm tired" | Exhaustion is not an excuse. |
| "Partial check is enough" | Partial proves nothing. |
| "Different words so the rule doesn't apply" | Spirit over letter. |

## Regression tests: red-green protocol

Writing a regression test is not verification until it has been shown to fail for the right reason:

```
Write the test
  -> Run it: MUST PASS (with the fix in place)
  -> Revert the fix
  -> Run it again: MUST FAIL (proves the test catches the bug)
  -> Restore the fix
  -> Run it once more: MUST PASS
```

A regression test that has never been observed to fail proves nothing about what it catches.

## Agent-delegation distrust

A subagent's report of "done" or "success" is a claim, not evidence. Before relying on it:

```
Agent reports success -> check the VCS diff -> verify the changes are what was claimed -> report the actual state
```

Never propagate a subagent's self-report upward as your own verified claim.

## Why this matters here specifically

Shipping is the phase where false completions are most expensive: a merge cannot be un-sent the way a claim in conversation can be retracted. "CI passed" stated without a fresh `gh pr checks` run, or "all comments resolved" stated without a re-fetch, both convert directly into an irreversible outward action (Steps 4, 6, 7) taken on stale information.
