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
| Code delta (product / test / docs) | +A/-B / +C/-D / +E/-F |
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

(Every item from the previous retro appears here — silent drops are a defect.)

## Findings

### What worked well
- **What happened**: <specific event, cited to PR comment / CI run / review round>
  **Why**: <cause>
  **How to apply**: <forward-looking action>

### What to improve
- (same three-part structure; findings must cite specifics — vague findings are rejected;
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
