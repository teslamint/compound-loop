---
module: plugin-runtime
date: "2026-08-21"
problem_type: convention
component: plugin-cache
severity: medium
applies_when:
  - "editing or relying on a skill whose text an agent loads from the plugin cache"
  - "a behavior changes in repo HEAD skills/ but the running agent still cites old wording"
  - "debugging why loaded skill text disagrees with the checked-out SKILL.md"
related_components:
  - skills
  - plugin-loader
tags:
  - plugin-cache
  - skill-drift
  - version-string-same-but-content-different
  - repo-head-is-authoritative
---

## Context

The installed plugin cache at
`~/.claude/plugins/cache/compound-loop/compound-loop/<version>/skills/...` can
diverge from the repository's checked-out `skills/**` while declaring the *same*
plugin version. In this repo the `0.10.0` cache copy differed from HEAD across
10 skill files (implementing, planning + deepening + validator, release-loop +
progress-schema, retrospective + interview-probes, reviewing, shipping) and was
missing `skills/planning/schemas/` entirely — even though both the cache and the
repo reported version `0.10.0`.

The version number is not a drift detector: a stale cache and a newer HEAD ship
the same `plugin.json` version string, so `cache == repo version` proves nothing
about content parity.

## Guidance

Treat the repository HEAD `skills/**` as the governing contract. When a loaded
skill's wording matters (e.g. it gates a review or defines a behavior you are
about to change), diff the cache copy against HEAD before relying on it:

```bash
cache=~/.claude/plugins/cache/compound-loop/compound-loop/0.10.0
diff -rq "$cache/skills" skills
```

If they differ, base your work on the repo HEAD file, not the cached text. The
cache only refreshes on a plugin reinstall/upgrade, which lags committed changes.

## Why This Matters

An agent that trusts cached skill text while the repo HEAD has moved will edit
against a stale contract, reintroduce fixed defects, or miss a new gate. The
drift recurred within a single session in this repo's own history, so checking
at the start of any cycle that edits a skill it also invokes is the safe default.

## When to Apply

- At the start of a release-loop or any cycle that edits a skill this session
  also loads.
- When loaded skill instructions contradict the repo's `skills/**` text.
- When `plugin.json` versions match but behavior visibly differs.

## Examples

Detect drift before trusting cache text:

```bash
for v in ~/.claude/plugins/cache/compound-loop/compound-loop/*/; do
  diff -rq "$v/skills" skills 2>/dev/null | head
done
# Files .../0.10.0//skills/planning/SKILL.md and skills/planning/SKILL.md differ
#   -> use repo HEAD skills/planning/SKILL.md as the contract
```
