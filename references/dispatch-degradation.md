# Dispatch Degradation Ladder

`enforces: P9`. Every skill that fans work out to multiple perspectives (review lanes, plan deepening reviewers, parallel investigations, parallel implementation units) selects its dispatch tier by capability detection, in this order. Correctness must be identical at every tier; only wall-clock time and context freshness may differ.

## Tier 1 — native parallel subagents

Use the harness's subagent primitive (Claude Code `Agent` tool; Codex native subagents) and dispatch independent work items concurrently.

- **Bounded**: respect the harness concurrency cap. A capacity/limit error is **backpressure, not failure** — queue the item and retry when a slot frees; never drop it and never count it against the work item.
- **Isolation rule for writes**: parallel dispatch of *writing* work additionally requires either per-agent worktree isolation or the shared-directory protocol (see `implementing`). Read-only fan-out (reviews, investigations) needs no isolation.
- Each dispatch prompt is focused, self-contained, and specific about its output shape — the receiving agent has no conversation context.

## Tier 2 — sequential passes

No parallel primitive (or the caller degraded deliberately): run the same work items one at a time, each in a fresh pass with the same prompt and the same output contract.

- Passes are **explicitly separated**: finish and record one item's structured output before starting the next; never blend two perspectives in one pass.
- Order by expected severity/importance (e.g. correctness lane before style-adjacent lanes) so an interrupted run has spent its budget on what matters.

## Tier 3 — single-call fallback

Harness offers no subagent capability at all (or a strict dispatch budget applies): one prompt executes all selected work items **serially inside itself**, emitting each item's structured output before self-merging.

- The per-item output contract is unchanged — downstream consumers cannot tell which tier produced the artifact.
- Verification adjusts: where Tier 1 uses a per-finding validator wave, Tier 3 uses a capped re-review loop instead (cheaper, same intent).

## Worker protocol (all tiers)

- **Only the parent orchestrator asks blocking questions.** Dispatched workers have no reliable question channel (Claude Code subagents cannot call `AskUserQuestion`; non-interactive Codex runs cannot surface approvals). A worker that needs input returns a structured `NEEDS_CONTEXT: <question>` result; the orchestrator answers from its own context or asks the user, then re-dispatches.
- **Malformed output**: a worker whose structured output does not parse gets one re-dispatch with the parse error included; a second failure is a lane/worker failure handled per severity rules (critical lanes kept-but-marked-degraded, advisory lanes dropped with a coverage note).
- **Timeout / permission failure**: treated the same as worker failure — never as an empty (clean) result.
- **Partial completion**: report what ran and what did not; silence about missing coverage is a defect.

## Anti-patterns

| Don't | Because |
|---|---|
| Treat a concurrency-limit error as a failed reviewer | It is backpressure; the item still runs |
| Let Tier 3 skip items to save budget silently | Coverage loss must be reported, never implied |
| Depend on Tier 1 for correctness (e.g. "the validator wave will catch it") | Tier availability varies by harness; the pipeline must gate correctness at every tier |
| Dispatch parallel writers without isolation | File conflicts corrupt both units' work |
