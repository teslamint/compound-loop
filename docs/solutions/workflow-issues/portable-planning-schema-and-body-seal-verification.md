---
module: planning
date: "2026-08-16"
problem_type: workflow_issue
component: planning-contract
severity: high
applies_when:
  - "a standalone skill depends on a schema outside the files that travel with that skill"
  - "a shipped validator accepts a digest field by format without recomputing its value"
  - "an adoption migration must distinguish a seal-only transition from a body edit"
symptoms:
  - "a planning-only installation cannot resolve the full plan schema"
  - "an arbitrary 64-character lowercase hexadecimal body_seal passes standalone validation"
  - "seal printing, normal validation, repository validation, and migration can disagree on canonical extraction"
root_cause: "load-bearing planning rules depended on plugin-root-relative schema references while the shipped validator checked body_seal format without recomputing the canonical body digest"
resolution_type: contract-and-validator-fix
related_components:
  - implementing
  - release-loop
  - retrospective
  - plan-frontmatter-validator
  - adoption-migration
tags:
  - planning
  - schema-portability
  - body-seal
  - validator
  - standalone-install
  - migration
---

# Portable Planning Schema and Verifiable Body Seal

## Context

Issue #14 reported that the installed plugin omitted `schemas/plan-schema.md`. Repository reconnaissance refined that diagnosis: the 0.10.0 full-plugin installation did contain the schema at plugin root, and that root schema already described `text.split('---', 2)[2]` as the canonical body extraction. The failures were at the consumption boundary:

1. A standalone copy of `skills/planning/` could not resolve load-bearing references that assumed plugin-root context.
2. The shipped `skills/planning/scripts/validate-plan-frontmatter.py` accepted any 64-character lowercase hexadecimal `body_seal`; value recomputation existed only in repository-local `scripts/validate.sh` check 14.
3. Implementing, release-loop, and retrospective consumers needed selected plan rules even when the sibling planning skill was unavailable.

The approved design and completed plan are `docs/specs/2026-08-14-schema-reference-and-seal-verification-design.md` and `docs/plans/2026-08-14-001-fix-schema-reference-and-seal-verification-plan.md`. PR #16 shipped the correction as squash commit `add8bc3bb2c7a0c6591014300eb05a33af42631e`.

## Guidance

### Put the complete contract under its owning skill

Keep one full schema SSOT at `skills/planning/schemas/plan-schema.md`. Resolve planning-local references from the planning skill root, not from an assumed repository or plugin root. Reject duplicate active copies: two full schemas can both exist and still drift silently.

Other standalone consumers should inline only the decision rules they execute. For this contract:

- implementing needs approved-status eligibility, execution-mode selection, full-unit consumption, and seal/history checks;
- release-loop needs the minimum `--skip-plan` field and status contract;
- retrospective needs origin resolution, coverage selection, terminal transitions, and applicability rules.

An optional pointer to the complete planning schema may aid installations that include the sibling skill, but correctness cannot depend on that pointer.

### Define one canonical seal computation

The owning schema specifies the byte-level contract:

1. Read UTF-8 text with universal-newline translation.
2. Extract everything after the first two literal `---` delimiter occurrences using `text.split('---', 2)[2]`.
3. Encode that exact string as UTF-8.
4. Compute lowercase hexadecimal SHA-256.

The shipped validator implements this once in `compute_body_seal(text)`. Normal validation and seal generation call the same function:

```sh
python3 skills/planning/scripts/validate-plan-frontmatter.py \
  --print-seal docs/plans/example-plan.md

python3 skills/planning/scripts/validate-plan-frontmatter.py \
  docs/plans/example-plan.md
```

`--print-seal` prints the candidate digest. Normal validation recomputes it and rejects a mismatch with both `stored=` and `computed=` values. A plan without `body_seal` retains its prior unsealed behavior. Validation failures exit 1; malformed invocation or a missing file exits 2.

Do not replace the literal split with delimiter-line slicing, whitespace stripping, or a custom CRLF rule. Those variants can produce internally consistent but contract-incompatible seals. The round-six review caught exactly this failure: the fixture and oracle shared the same wrong delimiter-line extraction, so a green suite proved only self-consistency.

### Keep every verifier at semantic parity

Repository check 14, the shipped validator, `--print-seal`, and the migration oracle must agree on:

- valid sealed input;
- absent seal;
- malformed stored value;
- stored/computed mismatch;
- one-byte body mutation;
- CRLF input under universal-newline reading;
- extraction failure when two literal delimiters do not exist.

Use an independent oracle and discriminating inputs. Sharing the production helper with the test oracle hides drift. A literal inline `---`, a one-byte mutation, and impossible extraction are stronger than another ordinary happy-path plan.

### Make adoption migration narrower than ordinary editing

A legacy seal migration is a one-time adoption path, not general re-seal authority. Require:

- first-hand approval;
- the exact pre-upgrade baseline commit;
- the repository-relative plan path;
- old and new seal values;
- the reproduction command;
- equality of baseline and current canonical bodies;
- a commit whose plan diff changes only `body_seal`.

Reject a changed body, missing or invalid baseline, missing evidence field, headless execution, or cancellation without clean compensation. After adoption, interactive deepening remains the sole authorized re-seal path.

The migration harness should preserve six observable outcomes: success, forced failure after write, rerun after partial state, target-only compensation, headless rejection before write, and cancellation with clean pre-write or compensated post-write state. The archived evidence for this release is under `.release-loop/archive/2026-08-16-schema-reference-and-seal-verification/evidence/U4/`.

## Why This Matters

A schema is portable only when the consumer receives both the rules and the resolution context needed to find them. Merely including a file somewhere in a full plugin artifact does not satisfy a planning-only installation.

A digest field is an integrity mechanism only when a verifier recomputes the digest from a canonical artifact. A regex proving “64 lowercase hex characters” validates representation, not integrity. If printing and checking also use different extraction algorithms, independently valid tools produce mutually unverifiable seals.

Migration adds a second risk: correcting an old seal can be used to disguise a body edit. Baseline/current canonical-body equality and a seal-only commit diff separate adoption from unauthorized re-sealing.

## When to Apply

- Packaging a skill that may be copied independently from its repository or plugin.
- Moving a schema or reference file across package boundaries.
- Adding a checksum, seal, fingerprint, or other derived integrity field.
- Exposing both “print expected value” and “validate stored value” CLI modes.
- Porting a repository-only validator into a shipped consumer tool.
- Migrating artifacts sealed before a canonical extraction rule became executable.

## Examples

### Representation-only validation is insufficient

```python
# Insufficient: any correctly shaped digest passes.
if not re.fullmatch(r"[0-9a-f]{64}", stored):
    reject("malformed body_seal")
```

```python
# Required: validate shape, then recompute from the canonical body.
computed = compute_body_seal(text)
if stored != computed:
    reject(f"body_seal mismatch: stored={stored} computed={computed}")
```

### Package-boundary rule

Fragile:

```text
See schemas/plan-schema.md.
```

The reader cannot tell whether that means repository root, plugin root, or skill root.

Portable:

```text
Read schemas/plan-schema.md relative to the planning skill directory.
```

For a consumer that must also work without planning installed, inline the exact executed subset and make the full-schema pointer optional.

## Verification Evidence

The merged release recorded:

- planning schema portability: 18 passed, 0 failed;
- standalone consumer portability: 321 passed, 0 failed;
- body-seal parity and mutation coverage: 179 passed, 0 failed;
- plugin discovery: 13 skills, 0 failures;
- full `scripts/validate.sh`: all checks passed;
- migration oracle: baseline-identical adoption accepted and body mutation rejected.

See `docs/retros/2026-08-16-schema-reference-and-seal-verification-retro.md` and `.release-loop/archive/2026-08-16-schema-reference-and-seal-verification/progress.md` for the measured evidence and correction history.

Related guidance:

- `docs/solutions/workflow-issues/numbered-planning-step-reference-drift.md`
- `docs/solutions/workflow-issues/mandated-field-absent-from-schema.md`
- `docs/solutions/test-failures/validator-harness-mutation-gap.md`
- `docs/solutions/workflow-issues/verify-against-plan-vs-attack-the-invariant.md`
- `docs/solutions/test-failures/green-suite-unreachable-assertions.md`
