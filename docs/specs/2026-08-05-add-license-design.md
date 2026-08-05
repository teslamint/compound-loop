---
status: approved
feature: add-license
created: 2026-08-05T13:11:06Z
---

# Add MIT LICENSE file

## Problem

Both plugin manifests (`plugin.json`) declare `"license": "MIT"` but no LICENSE file exists in the repository root. Downstream consumers and registries expect the full license text.

## Solution

Add a standard MIT LICENSE file at the repository root with copyright holder "Jaehoon You" and year 2026 (project inception year based on commit history).

## Scope

- Add `LICENSE` (MIT full text)
- No manifest changes needed (already MIT)

## Success criteria

1. `LICENSE` exists at repo root with valid MIT text
2. Copyright line names "Jaehoon You"
3. Plugin manifest `license` fields remain "MIT" (no regression)

## Assumptions

- Year uses project inception year (2026), not current year
- Author name matches `plugin.json` author field
