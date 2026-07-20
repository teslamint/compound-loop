# Retro Document Template

Written by `retrospective` to `docs/retros/YYYY-MM-DD-<context>-retro.md`, where `<context>` is the feature, PR, or session topic.

```markdown
# Retro: <context>

- Date: YYYY-MM-DD
- Source: PR #<n> | session <topic> | ad-hoc
- Spec: <path or "none">
- Plan: <path or "none">

## Release data

| Metric | Value |
|---|---|
| **Changed non-test lines** | N (added + removed) |
| Commits | N |
| Review rounds | N |
| Comments (fixed / deferred) | N / N |
| CI failures | N |
| Duration (first spec commit → merge) | N days |
| Units planned / completed | N / N |

## Success criteria: measured vs declared

One row per criterion from the spec's Success Criteria section. The measurement is run FRESH
during the retro (enforces: P3) — a prior claim in a commit message or PR body is not evidence.

| # | Declared criterion | Measurement (command / rubric) | Measured result | Verdict |
|---|---|---|---|---|
| 1 | <criterion> | `<command>` | <output summary> | Met / Partially met / Not met — <gap> |

(If no spec exists, state that explicitly and skip this section — do not reconstruct criteria after the fact.)

## Carry-forward from previous retro

| Item | Status | Evidence |
|---|---|---|
| <previous item> | Done / In progress / Not started | <commit / PR / file> |

(Every item from the previous retro appears here — silent drops are a defect.
Rows probed during the interview append `(T<n>)` to their Evidence cell.)

- Previous doc shape: conformant | violations recorded as findings | pre-schema, exempt

(the backward check's result on the previous retro doc)

## Interview Transcript

- Independence level: heterogeneous | same-model fresh-context | in-thread (approximated independence) | self-checklist
- Rounds used: N (max 5)

| ID | Round | Phase | Probe | Answer | Evidence | Verdict (verbatim) |
|---|---|---|---|---|---|---|
| T1 | 1 | 5 | <probe> | <answer> | <commit/file/measurement> | accepted |
| T2 | 3 | 4 | <probe> | <final answer> | — | no evidenced answer (3 rejections): <facilitator's final rejection, verbatim> |

Verdict cell values: `accepted` | `no evidenced answer (3 rejections): <verbatim>` | `self-attested`

(`self-attested` is for degraded modes only; in `self-checklist` mode the rows are the
checklist answers; a zero-row table under a valid header is valid.)

## Findings

### What worked well
- **What happened**: <specific event, cited to PR comment / CI run / review round>
  **Why**: <cause>
  **How to apply**: <forward-looking action>
  **Cites**: T<n> / Phase 2–3 data

### What to improve
- (same structure including the **Cites** line; findings must cite specifics — vague findings
  are rejected, and a finding with no **Cites** line is rejected as uncited;
  never frame resolved review findings as "noise")

### Process observations
- (same structure)

## Carry-forward items registered

| Item | Type | Priority | Tracked at |
|---|---|---|---|
| <item> | architecture / performance / feature / edge-case / process | P1–P4 | <issue / ROADMAP link — never a PR comment> |

## Lessons

- <one quotable line: specific, evidence-backed, actionable, and surprising —
  "testing is good" does not qualify>

## Compounding

- compound invocation: `Documentation complete — <path>` | `Documentation skipped — <reason>` | `not attempted — no reusable lesson this cycle`
```
