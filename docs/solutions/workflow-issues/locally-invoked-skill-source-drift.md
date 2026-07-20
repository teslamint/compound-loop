---
module: skill-loading
date: "2026-07-20"
problem_type: workflow_issue
component: dotagents-install
severity: medium
symptoms:
  - "a skill invocation acts on prose that was already removed or changed in the repo's tracked skills/<name>/SKILL.md"
  - "~/.agents/agents.lock's resolved_commit for a skill is behind the repo's pushed HEAD"
root_cause: dotagents pins each installed skill to a resolved GitHub commit in agents.lock at install time; nothing re-resolves it automatically after a later push, so a session that edits and pushes a skill file and then re-invokes that skill runs on the stale pinned copy
resolution_type: operational_fix
applies_when:
  - "a session edits and pushes a repo-tracked skills/<name>/SKILL.md file"
  - "that same session, or a later one, invokes the same skill again before re-installing"
  - "the skill is installed via dotagents' wildcard source resolution rather than a live symlink into the working checkout"
related_components:
  - retrospective
  - dotagents
  - skill-loading
tags:
  - dotagents
  - agents-lock
  - stale-instructions
  - self-referential-drift
---

# Locally-Invoked Skill Source Drift

## Context

`~/.claude/skills` resolves via symlink to `~/.agents/skills`, populated by
`dotagents` (`npx @sentry/dotagents`, config in `~/.agents/agents.toml`).
`compound-loop` is declared there as a wildcard skill source
(`[[skills]] name = "*" source = "teslamint/compound-loop"`). Each installed
skill is pinned to an exact upstream commit in `~/.agents/agents.lock`
(`resolved_commit = "<sha>"`) — **not** a live view into any local working
checkout, and not even a "latest on the default branch" reference. It is a
resolved GitHub download, frozen until something explicitly re-resolves it.

In this session, `compound-loop/skills/retrospective/SKILL.md` was edited and
pushed to `origin/main` twice (`b37675f`, removing an `EntireContext hooks`
bullet; a later commit changing Phase 2's metric wording). `~/.agents/agents.lock`
still pinned `retrospective` to `resolved_commit = aabfefa38f...` — the commit
that was `HEAD` when this project's skills were last installed, several
commits behind. When the `retrospective` skill was invoked again later in the
same session, the harness loaded the pinned copy from `~/.agents/skills/retrospective/SKILL.md`,
which still contained the already-removed `EntireContext hooks` bullet and
the already-fixed, stale Phase 2 wording (`code delta split
product/test/docs by path` instead of the corrected `Changed non-test
lines`) — because nothing had re-run the install step since those commits
were pushed, not because of a cache-invalidation bug.

The session's own output was not corrupted only because the acting agent
already knew, from earlier in the same conversation, what the repo's true
current skill content was — it proceeded on that knowledge rather than the
stale loaded text. A session without that prior context would have silently
produced a retro (or executed any other skill logic) against instructions
that no longer matched the repo it was operating in, with no signal that a
divergence had occurred.

## Guidance

Treat a dotagents-installed skill's loaded body as a *pinned download*, not
as equivalent to the repo's tracked source, whenever a session pushes a
commit touching `skills/<name>/SKILL.md` and later re-invokes that same
skill — in the same session or a later one — before re-installing.

The fix is a normal `dotagents` operation, not an ad hoc diff-and-repair:

```sh
npx @sentry/dotagents install --user   # or without --user, at project scope
```

This re-resolves every wildcard-sourced skill in `agents.toml` to its
source's current commit and rewrites `agents.lock` accordingly. Confirm it
took effect:

```sh
grep -A4 '^\[skills\.<name>\]' ~/.agents/agents.lock   # resolved_commit should match `git rev-parse HEAD` on origin
diff <(grep -n '<marker text>' ~/.agents/skills/<name>/SKILL.md) \
     <(grep -n '<marker text>' <repo>/skills/<name>/SKILL.md)   # empty output
```

If a skill was just edited and pushed in the *current* session and there has
been no intervening `dotagents install`, assume the installed copy is stale
and either re-install first or follow the repo's tracked file directly
rather than trusting the loaded invocation.

This is a narrower, more urgent instance of the general risk the
`ROADMAP.md` "Clean-environment Codex install check" item already names for
Codex's `.codex-plugin/plugin.json` discovery: that item is scoped to a
fresh external or clean-machine install. This finding shows the same class
of drift on the *same* dev machine, mid-session, immediately after a push —
no clean install is required to trigger it, and no `dotagents` command
detects or warns about the staleness on its own; `install` must be run
proactively.

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

Detecting and fixing the drift observed this session:

```sh
$ grep -A4 '^\[skills\.retrospective\]' ~/.agents/agents.lock
resolved_commit = "aabfefa38f7d1d10b824d85b9485b25377599f9"   # 5 commits behind pushed HEAD

$ diff <(grep -n "EntireContext\|Changed non-test lines" ~/.agents/skills/retrospective/SKILL.md) \
       <(grep -n "EntireContext\|Changed non-test lines" compound-loop/skills/retrospective/SKILL.md)
1,2c1
< 32:- **Git/PR metrics** (PR-merge mode): code delta split product/test/docs by path, ...
< 92:- **EntireContext hooks**: `ec_decision_create` to record architecture decisions ...
---
> 32:- **Git/PR metrics** (PR-merge mode): **Changed non-test lines**, commit count, ...

$ npx @sentry/dotagents install --user
Installed 17 skill(s): dotagents, find-bugs, code-review, commit, compound, ...

$ grep -A4 '^\[skills\.retrospective\]' ~/.agents/agents.lock
resolved_commit = "927291059c31ce9672f2e2febc2f8eb1dde7f48"   # now matches pushed HEAD

$ diff <(grep -n "EntireContext\|Changed non-test lines" ~/.agents/skills/retrospective/SKILL.md) \
       <(grep -n "EntireContext\|Changed non-test lines" compound-loop/skills/retrospective/SKILL.md)
$ echo $?
0   # empty diff — resolved
```

Tracked follow-up: `ROADMAP.md` "Carry-forward from retros" — a P2 row for
building a proactive reminder or check (nothing today prompts a re-install
after a skill-touching push), since `npx @sentry/dotagents install` fully
resolves the drift once run but nothing runs it automatically.
