---
schema: plan/v1
title: Add MIT LICENSE file
type: docs
status: approved
date: 2026-08-05
execution: non-code
origin: docs/specs/2026-08-05-add-license-design.md
body_seal: 17ea723f8133e21e0918e48fecf184dfcf0f9fe9b1f479ec73dd5fcbe89ae302
---

## Goal

Add the MIT LICENSE full text to the repository root, matching the license already declared in both plugin manifests.

## Architecture notes

No architecture impact. Single file addition, no imports or dependencies.

## Assumption Recheck

Origin spec retains one live assumption: inception year is 2026. Verified via `git log --reverse --format="%ai" | head -1` → `2026-07-15`. Match.

## File structure

- `LICENSE` (create) — MIT full text, copyright 2026 Jaehoon You

## Scenario coverage map

Origin spec has no User Scenarios section; success criteria are structural (file exists, correct text, no manifest regression).

## U1: Add MIT LICENSE file

Files:
  Create: LICENSE
Steps:
  1. Write LICENSE with standard MIT text, copyright line "Copyright (c) 2026 Jaehoon You"
  2. Verify plugin.json files still declare "license": "MIT" (no regression)
  3. Commit: "docs: add MIT LICENSE file"
Acceptance: `test -f LICENSE && head -1 LICENSE | grep -q "MIT"` passes; `grep '"license": "MIT"' .claude-plugin/plugin.json .codex-plugin/plugin.json` returns two matches

## No stateful ceremony in the deliverable; no mutation/failure-state matrix required.

## Carry-forward trigger audit

No durable carry-forward tracker in this repo; no trigger audit possible.

## Deferred to Follow-Up Work

None.

## Open unknowns

None.
