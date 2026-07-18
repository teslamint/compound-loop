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

## Assumptions and Preconditions
[Always present. If there are no live assumptions, say so explicitly and note any repository or environment invariants that still apply.]

_No live assumptions were retained for this spec. Repository or environment invariants: [none / list]._

[When live assumptions exist, replace the fallback above with the five-field evidence table below and retain only concise sanitized results. If raw output is unsafe or too large, reference a committed sanitized evidence artifact instead of pasting the raw output.]

| Claim | Command | Observed at | Observed result | Evidence source |
|---|---|---|---|---|
| [Live assumption being retained] | `[Exact command used to check it]` | `YYYY-MM-DDTHH:MM:SS±HH:MM` | [Concise sanitized result, or a reference to a committed sanitized evidence artifact when raw output is unsafe or too large] | [Working tree / commit / artifact / document inspected] |

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
- Always includes Assumptions and Preconditions, with an explicit none-fallback when no live assumptions exist
- Retains each live assumption with claim, exact command, observation timestamp, concise result, and evidence source
- Keeps retained evidence sanitized: no secrets, credentials, personal data, or unbounded raw output; large or unsafe output is referenced through a committed sanitized evidence artifact
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
