---
title: Auto Planning Assumption and Trade-off Coverage Authority Design
status: approved
date: 2026-09-20
schema: spec/v1
mode: auto
---

# Auto Planning Assumption and Trade-off Coverage Authority Design

_Created 2026-09-20 as the immutable authority successor._

## Overview

When `release-loop --auto` writes a spec or plan, it must expose the assumptions
and trade-offs that would otherwise stay inside the agent's reasoning. The
change adds an explicit artifact contract and an executable validator to the
`designing` and `planning` skills. Normal interactive work keeps its current
dialogue flow.

## User Scenarios

### S1: Auto design records assumptions before architecture

A release loop runs with `--auto` and drafts a spec. The phase receives the
exact `progress_path`, reads the ledger's `flags`, and selects auto mode only
when `--auto` is present. The spec records each live assumption in the existing
five-field evidence table before its Architecture or Success Criteria sections.
It also records selected and rejected alternatives with measured costs in the
required trade-off table.

### S2: Auto planning records decisions before implementation

The same loop writes a plan from the approved spec. The phase reads the same
exact progress ledger and marks the plan as `mode: auto`. The plan preserves the
existing Assumption Recheck contract and adds the same explicit assumption and
trade-off requirements before implementation units. The implementer can see the
selected option, the rejected option, the improved metric, the degraded metric,
and the measured cost.

### S3: Interactive planning keeps its existing contract

A user runs `designing` or `planning` without `--auto`. The skills continue to
use their existing dialogue and approval gates. The new auto-only artifact
contract does not force migration of existing interactive specs or plans.

### S4: A structural and artifact regression test rejects incomplete output

The validation suite checks both skill contracts and both artifact validators.
Disposable auto spec and plan fixtures pass only with the required sections,
non-empty fields, selected status, and rejected alternative. Disposable
mutations remove one required field or blank one value and must fail. A
historical fixture without `mode: auto` is accepted unchanged.

## Scope

### In

- R1: Define one auto-mode artifact contract for specs produced by `designing`.
- R2: Define the same contract for plans produced by `planning`.
- R3: Read `--auto` from the selected exact progress ledger before phase output.
- R4: Require `mode: auto` in auto-generated spec and plan frontmatter.
- R5: Require an explicit assumption record, including a no-assumption statement
  when no live assumption exists.
- R6: Require a trade-off table with the columns `Option`, `Metric it improves`,
  `Metric it degrades`, and `Measured cost`.
- R7: Require `Selected:` and `Rejected:` option statuses, or an explicit
  `No rejected alternative` row when no alternative exists.
- R8: Require every live-assumption and trade-off cell to be non-empty. Require
  `Measured cost` to contain a numeric quantity, including `0` when appropriate.
- R9: Add one executable validator per standalone skill package and one focused
  regression harness with disposable negative controls.

### Out

- Migrating the 27 existing specs or 29 existing plans authored before this
  change. The measured inventory is retained in the assumptions table.
- Changing the interactive Design or Plan approval gates.
- Inferring assumptions or trade-offs from arbitrary prose without a stable
  section marker and field layout.
- Replacing the existing five-field live-assumption evidence table or the plan's
  Assumption Recheck section.
- Adding a new runtime dependency, plugin extension, or external service.
- Publishing, pushing, or merging as part of implementation.

## Assumptions and Preconditions

The following live assumptions were checked in the feature worktree before this
design was written. Results are concise and contain no credentials or personal
data.

| Claim | Command | Observed at | Observed result | Evidence source |
|---|---|---|---|---|
| The target skills have no auto-mode contract yet. | `printf 'observed_at='; date -u +%Y-%m-%dT%H:%M:%SZ; python3 -c 'from pathlib import Path; names=("designing","planning"); print("; ".join(n+":auto="+str((Path("skills")/n/"SKILL.md").read_text().count("--auto"))+";tradeoff="+str((Path("skills")/n/"SKILL.md").read_text().lower().count("trade-off"))+";assumption-heading="+str((Path("skills")/n/"SKILL.md").read_text().count("Assumptions and Preconditions")) for n in names))'` | 2026-09-19T13:24:08Z | `designing:auto=0;tradeoff=1;assumption-heading=1; planning:auto=0;tradeoff=0;assumption-heading=0` | Feature worktree at `e19851f` |
| Existing artifact migration would cover 27 specs and 29 plans. | `printf 'observed_at='; date -u +%Y-%m-%dT%H:%M:%SZ; wc -l skills/designing/SKILL.md skills/planning/SKILL.md; printf 'spec_count='; git ls-files 'docs/specs/*.md' \| wc -l; printf 'plan_count='; git ls-files 'docs/plans/*.md' \| wc -l` | 2026-09-19T13:23:49Z | `spec_count=27; plan_count=29` | Feature worktree at `e19851f` |
| The existing plugin skill discovery gate passes before this change. | `bash scripts/test-plugin-skill-discovery.sh` | 2026-09-19T13:23:49Z | `13 skills checked, 0 failures; ALL CHECKS PASSED` | Feature worktree command output |

Repository invariants: the existing live-assumption table remains authoritative
for executable evidence; the selected release-loop ledger already persists
`flags: [--auto]`; and the full repository gate remains
`bash scripts/validate.sh`.

## Trade-offs

| Option | Metric it improves | Metric it degrades | Measured cost |
|---|---|---|---|
| Rejected: prose-only auto guidance | Smallest patch and no new validation surface | Contract detectability; a later edit can remove the rule without a focused failure | `0` auto clauses exist in the target skills at baseline; no artifact negative control can run |
| Selected: auto-only structured contract | Artifact completeness and reviewer visibility while preserving interactive behavior | Skill payload size and duplicated contract text across standalone skill packages | `2` standalone validator copies, measured by the 2026-09-19T14:05:58Z validator-copy command; no existing specs or plans require migration |
| Rejected: contract required in every mode | Uniform artifact shape across all callers | Backward compatibility and authoring cost for non-auto callers | `56` existing spec/plan files are the measured review surface if strict backfill is required; current scope leaves them unchanged |

Measured-cost provenance: `python3 -c 'from pathlib import Path; print("validator_copies="+str(len(list(Path("skills").glob("*/scripts/validate-auto-artifact.py")))))'` returned `validator_copies=2` at `2026-09-19T14:05:58Z`.

Decision owner: the release-loop maintainer owns the scope choice. Measurement
owner: the focused validator harness owns contract-presence and negative-control
results. The recommended option rejects the prose-only and all-mode alternatives
because their degraded metric is either unmeasurable or unnecessarily broad.

## Recommendation

Use the auto-only structured contract with phase-ledger selection and artifact
validation. It makes auto-generated artifacts self-describing with `mode: auto`,
preserves the existing live-evidence and Assumption Recheck sections, and adds
one compact trade-off table. It does not force migration of existing interactive
artifacts.

## Architecture

The behavior remains in instruction files, standalone validators, and one
focused test harness:

- `skills/designing/SKILL.md` defines the auto-mode contract for specs. It reads
  the supplied exact progress ledger, requires `mode: auto`, the existing
  five-field assumption evidence table, and a selected/rejected trade-off table
  before Architecture and Success Criteria.
- `skills/planning/SKILL.md` defines the same contract for plans. It reads the
  same ledger path, preserves `Assumption Recheck` as the fresh-evidence
  authority, and adds the same assumption and trade-off requirements before
  implementation units.
- `skills/designing/scripts/validate-auto-artifact.py` validates auto specs.
- `skills/planning/scripts/validate-auto-artifact.py` validates auto plans.
  The two scripts use the same field rules and remain byte-identical so each
  standalone skill package carries its own validator.
- `scripts/test-auto-artifact-contract.sh` checks both skill contracts, both
  validators, compliant fixtures, historical no-mode fixtures, and disposable
  negative controls.

The validators reject missing sections, blank table cells, missing status rows,
and a non-numeric measured cost. They accept a no-live-assumptions statement
only when it is explicit and non-empty. The phase skills select auto mode from
the exact `progress_path` already carried by the release-loop invocation packet.
They reject a missing or mismatched ledger before writing an auto artifact. Each
skill carries its own validator because standalone skill packages may be copied
without sibling files.

## Interface

Auto-generated specs and plans use this frontmatter field:

```yaml
mode: auto
```

Each auto artifact contains these sections before its architecture or unit
content:

```markdown
## Assumptions and Preconditions

[Five-field evidence table, or an explicit no-live-assumptions statement]

## Trade-offs

| Option | Metric it improves | Metric it degrades | Measured cost |
|---|---|---|---|
| Selected: ... | ... | ... | 0 or another numeric quantity |
| Rejected: ... | ... | ... | 0 or another numeric quantity |
```

Every live-assumption row has non-empty values in all five fields. An artifact
with no live assumptions uses one explicit non-empty no-assumption statement.
Every trade-off data row has non-empty values in all four columns. `Measured
cost` contains at least one ASCII digit. A decision with no viable alternative
uses one row beginning `Selected:` and one explicit row beginning `No rejected
alternative:`. A decision with alternatives has at least one `Rejected:` row
with a measured reason.

The spec keeps its existing `Assumptions and Preconditions` table as the
five-field evidence source. The plan keeps its existing `Assumption Recheck`
section for fresh evidence. The auto validators require both authority sections
and do not replace either one.

## Data Model

No runtime data model changes. The only persisted artifact signal is the
frontmatter scalar `mode: auto`. The release-loop ledger remains the authority
for invocation flags and phase state.

## Integration

`release-loop --auto` supplies `progress_path` in every phase packet. The Design
and Plan phase skills read that exact repo-relative ledger and activate auto mode
only when its frontmatter contains `--auto` in `flags`. They write `mode: auto`
before their architecture or unit sections and run their package-local validator
before committing the artifact.

`implementing`, `reviewing`, `shipping`, and `retrospective` consume the
validated artifacts without adding new mode-specific branches. A missing or
incomplete auto artifact fails before the phase can advance.

## Testing

The focused harness reads both skill files and verifies their marked auto
contract regions. It runs both validators against disposable auto spec and plan
fixtures, plus historical fixtures without `mode: auto`. It removes one required
field from each disposable auto fixture, blanks one assumption cell, blanks one
trade-off cell, and removes the numeric quantity from `Measured cost`; each
mutation must fail. It then deletes the disposable copies. This tests the
rejection behavior without mutating repository files.

The existing plugin discovery test and the full repository validation gate run
after implementation. A reviewer also walks one compliant auto artifact, one
artifact with no live assumptions, one artifact with a rejected alternative, and
one blank-value mutation.

## Risks

| Risk | Mitigation |
|---|---|
| The two standalone skill contracts or validators drift apart. | Keep identical field labels and require both marker regions and validator digests in one structural test. |
| Authors satisfy headings with empty or vague content. | Require non-empty five-field rows, an explicit no-assumption statement when empty, selected/rejected status, and a numeric measured cost in every trade-off row. |
| `mode: auto` is added but the invocation was interactive. | Treat the mode field as a claim for review, while the exact release-loop ledger remains the invocation authority. |
| A phase writes an incomplete auto artifact and advances. | Run the package-local validator before the artifact commit and fail closed on missing sections or fields. |
| The test only proves text presence. | Include artifact fixtures, historical no-mode acceptance, missing-field mutations, and blank-value mutations. |

## Population and Coverage

Population: the current `--auto` run outputs named by the authoritative
release-loop ledger, not artifacts that happen to claim `mode: auto`. The ledger
names one spec and one plan, so the production population is two artifacts.
Superseded historical artifacts remain outside this current-run population.

The coverage sample adds 17 disposable mutations representing every named
contract boundary in the focused harness: missing mode or sections, malformed
evidence, blank fields, status and cost errors, weak closure sections, duplicate
mode, unsupported validator mode, and weak proving evidence.

Measurement command:

```text
python3 - <<'PY'
import re
import subprocess
from pathlib import Path

root = Path('.')
ledger = root / '.release-loop/runs/auto-plan-assumption-tradeoffs/progress.md'
observed = subprocess.check_output(['date', '-u', '+%Y-%m-%dT%H:%M:%SZ'], text=True).strip()
fields = {}
ledger_lines = ledger.read_text(encoding='utf-8').splitlines()
flag_values = [
    line.split(':', 1)[1].strip()
    for line in ledger_lines
    if line.startswith('flags:')
]
assert flag_values == ['[--auto]']
for line in ledger.read_text(encoding='utf-8').splitlines():
    match = re.match(r'^(spec|plan):\s+(.+)$', line)
    if match:
        fields[match.group(1)] = match.group(2).strip()
assert set(fields) == {'spec', 'plan'}
for kind, name in fields.items():
    validator = root / ('skills/designing/scripts/validate-auto-artifact.py'
                        if kind == 'spec'
                        else 'skills/planning/scripts/validate-auto-artifact.py')
    subprocess.run(['python3', str(validator), '--mode', 'auto', name], check=True)

expected = [
    'missing mode', 'missing assumptions section', 'prose assumption command',
    'non-timestamp assumption evidence', 'missing plan assumption recheck',
    'blank assumption cell', 'blank trade-off cell', 'missing rejected status',
    'unquantified measured cost', 'missing non-goals', 'missing residual risks',
    'missing success criteria', 'status-only selected row',
    'missing proving command', 'unrelated control phrase', 'duplicate mode',
    'unsupported mode',
]
run = subprocess.run(['bash', 'scripts/test-auto-artifact-contract.sh'],
                     text=True, capture_output=True, check=True)
lines = run.stdout.splitlines()
observed_labels = [
    line[4:-len(' is rejected')]
    for line in lines
    if line.startswith('ok: ') and line.endswith(' is rejected')
]
assert observed_labels == expected
print(f'observed_at={observed}; production_population={len(fields)}')
print(f'validator_detected_mutants={len(observed_labels)}/{len(expected)}; '
      f'harness_observed_mutants={len(observed_labels)}/{len(expected)}; '
      f'validator_recall={len(observed_labels)/len(expected):.3f}; '
      f'harness_incremental_recall=0.000; '
      f'stacked_recall={len(observed_labels)/len(expected):.3f}')
PY
```

Observed at `2026-09-20T02:51:37Z`: production population 2, validator
detection 17/17, downstream harness observation 17/17, validator recall
`1.000`, harness incremental recall `0.000`, and stacked recall `1.000`.
The harness is downstream of the validator, so its incremental recall is
correctly zero rather than complementary. The coverage floor is `1.000` recall
for the two ledger-named artifacts and all 17 fixed mutation cases. Any lower
result fails this design's success criteria.

## Success Criteria

1. Both target skills and their standalone validators define the same auto-mode
   artifact contract, including mode selection, non-empty assumption fields,
   trade-off columns, selected/rejected status, numeric measured cost, and
   negative controls.
   - **Measured by**: `bash scripts/test-auto-artifact-contract.sh` exits 0,
     prints a pass for each skill, each validator, each compliant fixture, each
     historical no-mode fixture, and each disposable negative control, then
     prints `ALL CHECKS PASSED`. The controls fail when a required marker, field,
     value, or measured-cost quantity is removed.
2. Auto-generated specs and plans are self-describing and expose assumptions and
   trade-offs before architecture or implementation units.
   - **Measured by**: judgment rubric. A reviewer checks one spec and one plan
     fixture with `mode: auto`; each has an assumptions record, a trade-off
     table with all four required columns, at least one `Selected:` row, and a
     `Rejected:` row when alternatives exist. Every checked value is non-empty,
     and `Measured cost` contains a numeric quantity. A missing or blank field
     fails its package-local validator.
3. Interactive artifacts keep their existing contract and historical artifacts
   do not require migration.
   - **Measured by**: the focused test accepts fixtures without `mode: auto` and
     no historical spec or plan is rewritten by the implementation.
4. Existing repository behavior remains valid after the skill changes.
   - **Measured by**: `bash scripts/validate.sh` exits 0 and prints
     `ALL CHECKS PASSED`; `bash scripts/test-plugin-skill-discovery.sh` exits 0.
5. The contract detects every named malformed auto artifact in the sampled
   population instead of merely proving that the validators contain the right
   headings.
   - **Measured by**: the Population and Coverage command reports
     `validator_recall=1.000` and `stacked_recall=1.000` over the 17 mutation
     cases. A result below `1.000` fails this criterion.

## Open Decisions

1. **Whether to make the contract universal** — owner: release-loop maintainer;
   resolved for this cycle by the recommended auto-only scope. Reconsider only
   after evidence shows interactive artifacts also lose decisions without the
   contract.
2. **Whether to add a parser for arbitrary artifact bodies** — owner: planning;
   deferred. The validators inspect only the stable auto sections and frontmatter;
   free-form prose parsing would add false positives and false negatives.
3. **Implementation-time stop condition** — implementation may choose the exact
   marker syntax and helper structure, but it must preserve the required fields,
   exact-ledger mode selection, auto-only scope, disposable negative control, and
   existing authority sections. If those constraints cannot be met without
   changing user-visible artifact semantics, stop and return to this Design gate.
