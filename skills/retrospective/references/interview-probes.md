# Retro Interview Probes

The facilitator's question bank. Same grammar as `designing`'s rigor-gap probes: one gap = one open-ended probe, concrete enough to bite into, never a menu. Probes are starting points — follow the evidence, not the list. In headless/single-agent mode this file runs as a fixed self-checklist instead of a dialogue.

## Carry-forward probes (Phase 4)

- "You marked `<item>` Done — which commit or PR proves it? Show the reference, not the recollection."
- "This item has been In Progress across two retros. What is actually blocking it, and should its priority change?"
- "The previous retro registered `<n>` items; this doc accounts for `<m>`. Where are the rest?" (silent drops are themselves a finding)

## Gap probes (Phase 3 output → Phase 5 input)

- "Criterion `<n>` is Partially Met. What did the declaration get wrong at design time — the target, the measurement method, or the estimate?"
- "Which measurement surprised you against your expectation before running it? What produced the wrong expectation?"

## Surprise elicitation

- "What took meaningfully longer than planned, and what did the plan fail to see?"
- "If you re-ran this work from the spec, what is the one thing you would do differently — and what evidence from this run supports that?"
- "What almost went wrong but didn't? What caught it — discipline, luck, or a gate?"

## Evidence enforcement (rejection rules)

The facilitator rejects and re-asks when an answer:

- names no commit, file, measurement, or concrete event ("it went smoothly");
- generalizes across items instead of answering for the one asked;
- frames an acted-on review finding as "noise" or "trivial" — if it was worth fixing, it was legitimate;
- restates the plan's intent as if it were the outcome (intent is not evidence — `enforces: P3`).

Three consecutive rejections on the same probe → record "no evidenced answer" for that probe in the doc rather than accepting the vague version; an honest gap beats a polished rationalization.

## Output contract

The facilitator returns accepted answers as (probe, answer, evidence) triples. Phase 5 findings may only cite evidence that appears in a triple or in Phase 2–3 data — nothing enters a finding on narrative authority alone.
