# Spec Template

`enforces: P4, P8`. Ported from EC release-loop's design-phase skeleton, with the Success Criteria section promoted from optional to required (see SKILL.md Step 8).

## Frontmatter

```yaml
---
title: <Feature Name>
status: draft            # flip to `approved` only after the human gate (SKILL.md Step 12)
date: YYYY-MM-DD
schema: spec/v1
---
```

`status: approved` is the persisted approval evidence `release-loop`'s `--skip-design` flag reads. A spec without that record rejects the flag and the loop enters Design normally — never hand-set `approved` before the human gate fires.

## Section Skeleton

```markdown
# <Feature Name> Design

_Created YYYY-MM-DD._

## Overview
[1-3 sentences: what this builds and why]

## User Scenarios
[3-6 concrete scenarios: who, why, and how (with CLI/MCP examples). Each gets a stable
ID — S1, S2, ... — never renumbered on reorder or deletion. Downstream, `planning`'s
scenario coverage map and integration test scenarios trace back to these S-IDs, so an
unlabeled scenario is invisible to the rest of the pipeline.]

### S1: <scenario title>
[who / why / how]

## Scope
### In
[Bulleted list of what's included]
### Out
[Bulleted list of what's explicitly excluded]

## Architecture
[Module structure, data flow]

## [Domain-Specific Sections]
[Interface, data model, config, etc. -- whatever the feature needs]

## Testing
[Strategy, key test cases]

## Risks
[What could go wrong + mitigations]

## Success Criteria
[REQUIRED -- see shape below]

## Open Decisions
[Anything deferred or needing user input later]
```

Requirements referenced across sections get stable R-IDs (e.g. `R1`, `R2`), grouped by concern, only when the spec's scope is large enough that later sections or `planning` need to cite them individually. Skip R-IDs for small, single-thread specs — they add tracking overhead with no reader benefit below that size.

## Success Criteria Section Shape (Required)

Every criterion is a pair: a statement of what's true when this succeeds, and how it's measured. `retrospective` reads this section verbatim and runs the measurement fresh — vague criteria become unmeasurable retros.

```markdown
## Success Criteria

1. <Statement of the outcome, stated so it's true or false, not a direction of travel>
   - **Measured by**: <exact command to run> -- OR -- <judgment rubric: what a reviewer checks, and what "pass" looks like>
2. ...
```

- Hard metrics get a runnable command (`pytest tests/foo.py`, `scripts/validate.sh`, a curl against an endpoint with an expected status). Soft outcomes (readability, developer experience) get a named rubric, not "looks good."
- One criterion per line item; do not fold two outcomes into one bullet with "and."
- A criterion with no measurement method is a placeholder — Step 11's placeholder scan must catch it.

## Open Decisions Section

Anything the spec author deliberately left unresolved: forks not worth blocking approval over, questions for the user to answer during implementation, assumptions flagged as uncertain by a rigor-gap probe (see `rigor-probes.md`). Each entry names what's undecided and who resolves it (user vs. `planning` vs. `implementing`) — an Open Decision with no owner is a dropped thread, not a documented one.

## Spec Quality Signals

A good spec:
- Can be handed to someone with zero conversation context
- Has concrete, S-ID-labeled user scenarios with CLI/MCP examples showing who uses it and why
- Has explicit scope boundaries (In/Out)
- Names concrete files, tables, functions -- not just concepts
- Addresses risks and mitigations
- Has a Success Criteria section with a measurement method per criterion
- Has no placeholders or TODOs

A bad spec:
- References "the discussion above"
- Jumps straight to architecture without motivating the feature through scenarios
- Uses vague language ("appropriate error handling", "proper validation")
- Omits scope boundaries
- Has sections marked TBD
- States success criteria without saying how they'd be checked
