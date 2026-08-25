---
module: conformance-testing
date: 2026-08-26
problem_type: workflow_issue
component: release-loop-conformance
severity: high
applies_when:
  - "Any merge, rebase, or cherry-pick touches skills/release-loop/SKILL.md or its references/"
  - "Merge conflict resolution changes SKILL.md bytes"
tags:
  - conformance
  - digest-chain
  - golden-files
  - source-manifest
---

# Conformance Golden Repin Digest Chain

## Context

The release-loop conformance fuzzing harness uses a three-level digest chain to detect when skill source changes invalidate test fixtures. Any upstream change to `skills/release-loop/SKILL.md` or its `references/` files triggers a cascade requiring updates at all three levels.

## Guidance

### Level 1 — `skill_sha256` (golden files)

- **What**: `SHA-256(skills/release-loop/SKILL.md bytes)`
- **Where**: 8 golden files under `tests/conformance/release-loop/golden/{claude,codex}/L{1-4}*.json`, field `"skill_sha256"`
- **Recompute**: `shasum -a 256 skills/release-loop/SKILL.md`

### Level 2 — clause `sha256` (source-manifest.json)

- **What**: `SHA-256(section_text(source_file, heading))` — the full heading section, NOT the `text` line
- **Where**: 11 clauses in `tests/conformance/release-loop/source-manifest.json`
- **Key detail**: `section_text()` extracts from the heading line to the next same-or-higher-level heading (exclusive). The `text` literal must appear exactly once in the extracted section.
- **Recompute**: extract the heading section with the same algorithm, then SHA-256 the result

### Level 3 — `source_generation` (baseline-policy.json, corpus.json)

- **What**: `SHA-256(sorted clause_id:section_digest rows joined by "\n" with trailing "\n")`
- **Where**: `tests/conformance/release-loop/baseline-policy.json` and `corpus.json`, field `"source_generation"`
- **Recompute**: build `f"{clause_id}:{digest}"` per clause, sort, join with `\n`, append `\n`, SHA-256

### Repin procedure after a merge

1. Compute new `skill_sha256`: `shasum -a 256 skills/release-loop/SKILL.md`
2. Update all 8 golden files with the new digest
3. For each of 11 clauses: extract `section_text()`, verify `text` literal still matches (update if changed), compute section SHA-256, update `sha256` in `source-manifest.json`
4. Sort 11 `clause_id:digest` rows, join with `\n` + trailing `\n`, SHA-256 → new `source_generation`. Update both `baseline-policy.json` and `corpus.json`
5. Run `bash scripts/validate.sh` to confirm all checks pass

## Why This Matters

A single missed digest at any level breaks the conformance test suite:
- Level 1 → `golden semantic contract mismatch`
- Level 2 → `source clause digest drift`
- Level 3 → `bootstrap source generation mismatch` / `corpus source generation mismatch`

The chain is intentionally strict — it proves that test fixtures match the exact skill source they claim to test.

## When to Apply

- After any merge, rebase, or cherry-pick touching `skills/release-loop/SKILL.md` or `skills/release-loop/references/`
- After resolving merge conflicts that change SKILL.md content
- When a deviation or addendum modifies skill text that a source-manifest clause references

## Examples

PR #25 merge conflict resolution: SKILL.md changed from `4e515b0f...` to `7c43110603dcb5ae...`. Required:
- 8 golden files: `skill_sha256` updated
- 11 clause digests in `source-manifest.json` (2 `text` values also changed: `resume-after-merge`, `archive-v2-ordering`)
- `source_generation` in `baseline-policy.json` and `corpus.json` → `c2347bbff31b...`
