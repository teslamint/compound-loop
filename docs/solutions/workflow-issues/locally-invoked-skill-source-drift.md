---
module: skill-loading
date: "2026-07-20"
problem_type: workflow_issue
component: dot-agents-sync
severity: medium
applies_when:
  - "a session edits and commits a repo-tracked skills/<name>/SKILL.md file"
  - "that same session later invokes the same skill again, in the same or a different tool"
  - "the skill is installed through a symlinked, synced, or otherwise indirect path rather than a live view of the repo checkout"
related_components:
  - retrospective
  - dot-agents
  - skill-loading
tags:
  - dot-agents
  - skill-sync
  - stale-instructions
  - self-referential-drift
---

# Locally-Invoked Skill Source Drift

## Context

`~/.claude/skills` resolves via symlink to `~/.agents/skills`, a dot-agents
cross-tool skill-sync directory. That directory holds a point-in-time
snapshot copy of each skill's `SKILL.md`, not a live view into any repo
checkout.

In this session, `compound-loop/skills/retrospective/SKILL.md` was edited and
committed twice (`b37675f` at 11:43, removing an `EntireContext hooks`
bullet; further edits at 13:29, changing Phase 2's metric wording). When the
`retrospective` skill was invoked again later in the same session, the
harness loaded its body from `~/.agents/skills/retrospective/SKILL.md` — a
copy last synced at `2026-07-20T11:06:47+09:00`, before either edit. The
loaded text still contained the already-removed `EntireContext hooks` bullet
and the already-fixed, stale Phase 2 wording (`code delta split
product/test/docs by path` instead of the corrected `Changed non-test
lines`).

The session's own output was not corrupted only because the acting agent
already knew, from earlier in the same conversation, what the repo's true
current skill content was — it proceeded on that knowledge rather than the
stale loaded text. A session without that prior context would have silently
produced a retro (or executed any other skill logic) against instructions
that no longer matched the repo it was operating in, with no signal that a
divergence had occurred.

## Guidance

Treat a locally-invoked skill's loaded body as a *cached copy*, not as
equivalent to the repo's tracked source, whenever both of these hold: the
skill was edited in the current session, and the install path is anything
other than a live symlink directly into the working checkout (a synced
snapshot, a plugin cache, a packaged install).

Before trusting a skill invocation's loaded instructions in that situation:

```sh
diff <(sed -n '1,40p' ~/.agents/skills/<name>/SKILL.md) \
     <(sed -n '1,40p' <repo>/skills/<name>/SKILL.md)
```

If they differ, follow the repo's tracked file — it is the authoritative,
committed source — and note the divergence rather than silently reconciling
it in the invocation's output.

This is a narrower, more urgent instance of the general risk the
`ROADMAP.md` "Clean-environment Codex install check" item already names for
Codex's `.codex-plugin/plugin.json` discovery: that item is scoped to a
fresh external or clean-machine install. This finding shows the same class
of drift on the *same* dev machine, mid-session, immediately after an edit —
no clean install is required to trigger it.

## Why This Matters

The failure mode is self-referential and easy to miss: the very tool meant
to measure and record what happened in a session (`retrospective`) can
itself be running on stale instructions about how to do that, without
raising any error. Nothing in the invocation path diffs the loaded skill
body against the repo's tracked file, so a diverged skill looks identical to
a correct one until someone happens to recognize specific stale content by
memory.

## When to Apply

- Editing any `skills/<name>/SKILL.md` in a repo whose skills are also
  installed through dot-agents (or any other sync/cache/package mechanism)
  and re-invoking that same skill later in the same session.
- Debugging a skill invocation that appears to ignore a change just
  committed to its `SKILL.md`.
- Auditing whether a repo's dot-agents-synced skill copies are safe to trust
  without a fresh sync.

## Examples

Detecting the drift observed this session:

```sh
$ stat -f '%Sm %N' ~/.agents/skills/retrospective/SKILL.md
Jul 20 11:06:47 2026 /Users/teslamint/.agents/skills/retrospective/SKILL.md
$ stat -f '%Sm %N' compound-loop/skills/retrospective/SKILL.md
Jul 20 13:29:45 2026 compound-loop/skills/retrospective/SKILL.md
$ diff <(grep -n "EntireContext\|Changed non-test lines" ~/.agents/skills/retrospective/SKILL.md) \
       <(grep -n "EntireContext\|Changed non-test lines" compound-loop/skills/retrospective/SKILL.md)
1,2c1
< 32:- **Git/PR metrics** (PR-merge mode): code delta split product/test/docs by path, ...
< 92:- **EntireContext hooks**: `ec_decision_create` to record architecture decisions ...
---
> 32:- **Git/PR metrics** (PR-merge mode): **Changed non-test lines**, commit count, ...
```

Tracked follow-up: `ROADMAP.md` "Carry-forward from retros" — a P2 row to
either diff the loaded skill against the tracked source before trusting it,
or fix dot-agents sync to resolve live against a working checkout.
