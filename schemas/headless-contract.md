# Headless Invocation Contract

Skills that other skills call non-interactively (`mode:headless` / `mode:agent`) end their final report with an **exact, case-sensitive terminal signal line**. Callers match the full line prefix; free text after `—` is informational. Defined here once — producers and consumers never improvise variants. `enforces: P9`.

Contract version: `v1` (bump on any change to existing rows or their semantics; adding a new producer row is additive and does not require a bump).

## Terminal signal lines

| Producer | Success | Skipped / no-op | Failure |
|---|---|---|---|
| `compound` | `Documentation complete — <path>` | `Documentation skipped — <reason>` | `Documentation failed — <reason>` |
| `compound-refresh` | `Refresh complete — <n> applied, <n> recommended` | `Refresh skipped — <reason>` | `Refresh failed — <reason>` |
| `retrospective` | `Retrospective complete — <path>` | `Retrospective skipped — <reason>` | `Retrospective failed — <reason>` |
| `release` | `Release complete — v<version>` | `Release skipped — <reason>` | `Release failed — <reason>` |
| `release publish` | `Publication complete — v<version>` | `Publication skipped — <reason>` | `Publication failed — <reason>` |
| `reviewing` (`mode:agent`) | emits the JSON envelope (`schemas/review-envelope.schema.json`) as its final block instead of a signal line | — | envelope with `status: "failed"` + `reason` |

## Rules

- The signal line is the **last non-empty line** of the producer's final output.
- In headless mode a producer never asks blocking questions; ambiguity degrades to the conservative default and is reported in the body (compound-refresh: `status: stale` marking; reports split **Applied vs Recommended**).
- A caller that does not find a recognizable signal line treats the run as **failed**, not as skipped.
- Producers write their deliverable file before emitting the success signal (the path in the signal must exist — `enforces: P3`).
