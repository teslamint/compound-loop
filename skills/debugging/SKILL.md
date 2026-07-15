---
name: debugging
description: Find root causes and fix bugs systematically. Use when debugging errors, investigating test failures, reproducing bugs from issue trackers, or when stuck after failed fix attempts. Also use when the user says "debug this", "why is this failing", "trace this error", or pastes a stack trace or error message.
---

# Debugging

Find root causes, then fix them. Trace the full causal chain before proposing a fix; optionally implement the fix with test-first discipline.

Input is whatever the caller provides: an issue-tracker reference, a stack trace, a failing test path, or a plain description of broken behavior.

## Iron Law

```
NO FIXES WITHOUT ROOT CAUSE INVESTIGATION FIRST
```

`enforces: P2`. A fix that "works" without a verified causal chain has moved the defect, not removed it. Symptom fixes are failure, not progress.

## Flow

| Phase | Purpose |
|---|---|
| 0 Triage | Parse input, fetch issue if referenced, reach a clear problem statement |
| 1 Investigate | Reproduce, verify environment sanity, trace the code path |
| 2 Root Cause | Assumption audit, grounded hypotheses, causal-chain gate, smart escalation |
| 3 Fix | Only if the user chose to fix — test-first, one change at a time |
| 4 Handoff | Structured summary, branch-aware next step, calibrated learning-capture offer |

Beyond the trivial-bug fast path in Phase 0, no other phase is skippable — complex bugs simply spend more time in each phase.

### Phase 0: Triage

If the input references an issue tracker, fetch the full thread (description + every comment) — comments often carry updated repro steps, narrowed scope, or prior failed attempts that the opening post doesn't show. Otherwise the problem statement is the input itself.

**Trivial-bug fast path**: if the cause is immediately readable (single-file typo, missing import, obvious null deref or off-by-one) and verification doesn't need deep tracing, present the cause and a one-line fix, then run the same Phase 2 **Fix now / Diagnosis only** gate below before editing anything — the fast path skips ceremony, never the user's choice. When in doubt, run the full flow; a wrong root cause costs more than the few minutes saved.

Investigate before asking questions. Only ask when a genuine ambiguity blocks investigation and code/tests can't resolve it. Exception: if the user signals prior failed attempts ("I've been trying", "keeps failing", "stuck"), ask what was already tried before investigating further — this avoids repeating dead ends.

### Phase 1: Investigate

Reproduce the bug, then verify environment sanity (branch, dependencies, runtime version, env vars, stale build artifacts, dependent services) before trusting any code-level theory — a stale environment is a frequent false lead.

Trace data flow backward from the symptom toward where valid state first became invalid; read code-shape to form a hypothesis, then confirm with observed values, not assumptions. See `references/techniques.md` for the backward-tracing recipe and the multi-component boundary-instrumentation recipe. Check recent changes (`git log`, `git bisect` for suspected regressions) and any observability tools the project has (error trackers, logs, console output, database state).

### Phase 2: Root Cause

*Do not propose a fix until the causal chain from trigger to symptom has no gaps.*

**Assumption audit** (before forming hypotheses): list the concrete "this must be true" beliefs the current understanding depends on — the framework behaves as documented, this function returns what its name implies, config loads before this runs, the caller never passes null. Mark each *verified* (read/ran/checked) or *assumed*. Getting stuck is usually a wrong assumption, not a wrong hypothesis.

**Form hypotheses**, ranked by likelihood. Each needs:
- What is wrong and where (file:line)
- A **grounding observation** — a runtime value, log line, instrumented capture, or behavior delta against a working comparison case. "X seems off" is not evidence; reject any hypothesis that can't cite one. Go back to Phase 1 and instrument instead.
- The causal chain, step by step, from trigger to symptom
- For **uncertain links** in the chain: a prediction — something true in a *different* code path or scenario if this link is correct. If the chain is obvious (missing import, explicit null deref), the chain explanation alone is sufficient; predictions are a tool for uncertain links, not a ritual for every hypothesis.

**Causal-chain gate**: no fix until the chain has no gaps. The user may explicitly authorize proceeding with the best-available hypothesis when investigation is genuinely stuck — this is an explicit override, never a silent default.

*If a prediction was wrong but a fix "works," that's a symptom fix — the real cause is still active. Say so and keep investigating.*

Before forming a new hypothesis, state what evidence ruled out the prior one.

**Smart escalation** — when 2-3 hypotheses are exhausted without confirmation, diagnose why instead of forming a fourth blindly:

| Pattern | Diagnosis | Next move |
|---|---|---|
| Hypotheses point to different subsystems | Architecture problem, not a localized bug | Present findings, route to `designing` |
| Evidence contradicts itself | Wrong mental model of the code | Re-read the code path without assumptions |
| Works locally, fails in CI/prod | Environment problem | Focus on env differences, config, timing |
| Fix works but prediction was wrong | Symptom fix, not root cause | Keep investigating — the cause is still active |
| 3+ fix attempts have failed | Root-cause identification was likely wrong | Return to this table before attempting a 4th fix |

**Redesign signals** — route to `designing` only when investigation shows the bug can't be properly fixed inside the current design: the root cause is a wrong responsibility/interface (fix requires moving logic between modules, not correcting it in one); the requirements are wrong (code does exactly what it was written to do, the spec is the gap); or every fix is a workaround (patches keep needing special cases, never a direct correction). Size alone never qualifies — a large bug with a clear fix stays here.

**Parallel investigation**: when hypotheses are evidence-bottlenecked across clearly independent subsystems and don't depend on each other's outcome, dispatch read-only investigations per the dispatch-degradation ladder (`references/dispatch-degradation.md` at the plugin root) — native parallel subagents first, each with one explicit hypothesis and a structured evidence-return format, no code edits. When no parallel primitive is available, run the same probes sequentially in ranked-likelihood order instead; parallelism here is a latency optimization, not a correctness requirement.

Present the root cause, proposed fix, files affected, and recommended tests before asking anything. Then ask via the harness's blocking question tool (see `references/question-tools.md` at the plugin root for the per-harness table and fallback rule) with options: **Fix it now** (→ Phase 3), **Diagnosis only** (→ Phase 4's summary, skill ends), or **Rethink the design** (→ `designing`, only when a redesign signal fired).

### Phase 3: Fix

*One change at a time. Changing multiple things "to see if it helps" is shotgun debugging — stop.*

Skip this phase if the user chose diagnosis-only or design-rethink in Phase 2.

Before editing: check for uncommitted changes in files that need modification (confirm before overwriting in-progress work); if on the default branch, ask via the blocking question tool whether to create a feature branch first (default: yes).

Invoke the `tdd` skill for the fix itself: write a failing test that captures the bug, verify it fails for the root-cause reason (not an unrelated setup issue), implement the minimal fix, verify the test passes, run the broader suite for regressions. Do not bundle drive-by refactors or formatting into the fix. Self-review the diff before declaring done: every changed line, checked for style violations, missed edges, and adjacent regressions.

**On a failed fix**: return to Phase 2 and explicitly invalidate the current hypothesis — state what evidence ruled it out — before forming a new one with its own grounding observation. Do not retry variants of the same theory.

**3 failed fixes** run the smart-escalation table again before a 4th attempt.

**Conditional defense-in-depth** (trigger: the root-cause pattern greps in 3+ other files, or the bug would have been catastrophic in production): add validation at the layers that matter — entry validation, invariant check, environment guard, diagnostic breadcrumb — choosing only the layers the pattern warrants. Skip for one-off errors with no realistic recurrence path.

**Conditional post-mortem** (trigger: the bug reached production, or the pattern appears in 3+ locations): note how it was introduced and what let it survive; this informs Phase 4's learning-capture decision.

### Phase 4: Handoff

Always write the structured summary first: problem, root cause (causal chain with file:line), recommended tests, fix (or "diagnosis only"), prevention added, confidence (High/Medium/Low).

If Phase 3 was skipped, stop after the summary — the user already said they'd take it from here.

If Phase 3 ran and this skill created the branch, default to proceeding toward `shipping` without re-asking (preview what will be committed and on what branch first, so the user can interrupt). If the branch pre-existed, ask via the blocking question tool: commit-and-hand-to-`shipping`, commit only, or stop here.

**Learning capture**: most bugs are mechanical (typo, missed null check) and compounding them adds no value — skip silently by default. Offer the `compound` skill neutrally when the lesson fits one sentence ("X returns T | undefined when Y, not just T"); lean into the offer when the pattern recurred in 3+ locations or the root cause reveals a wrong assumption about a shared dependency others are likely to repeat. If the lesson can't be stated in one sentence, skip rather than offer.
