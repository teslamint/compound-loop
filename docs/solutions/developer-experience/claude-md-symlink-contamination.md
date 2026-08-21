---
module: agent-context-files
date: "2026-08-21"
problem_type: developer_experience
component: agent-context-loader
severity: high
applies_when:
  - "asked to update or append to CLAUDE.md / AGENTS.md in this repo"
  - "any repo where /CLAUDE.md or /AGENTS.md is gitignored as a dot-agents link"
  - "writing project-specific guidance that should not leak to other projects"
related_components:
  - dot-agents
  - gitignore
tags:
  - claude-md-symlink
  - global-rules-contamination
  - machine-local-config
  - gitignored-agent-files
---

## Context

In this repo `/CLAUDE.md` and `/AGENTS.md` are both gitignored under the comment
"dot-agents personal config links (machine-local, never commit)". Critically,
`/CLAUDE.md` is not a normal file — it is a **symlink** to the user's global
rules file at `~/.agents/rules/global/rules.mdc`:

```text
lrwxr-xr-x  CLUDE.md -> /Users/teslamint/.agents/rules/global/rules.mdc
```

`~/.agents` is itself a git repository. Writing repository-specific content
through `CLAUDE.md` therefore edits the *global* rules document, which loads into
every project the user opens — a cross-project contamination, not a local edit.
Observed this session: a repo-specific "compound-loop Specifics" section written
to `CLAUDE.md` propagated to `~/.agents/rules/global/rules.mdc`; it was caught and
reverted with `git -C ~/.agents checkout -- rules/global/rules.mdc`.

A second trap: `git ls-files <file> && cat <file>` does not prove the file is
tracked — `git ls-files` exits 0 even for untracked/ignored paths. The reliable
checks are `git check-ignore -v <file>` and `ls -la <file>`.

## Guidance

Before editing any agent context file, confirm what it is:

```bash
ls -la CLAUDE.md AGENTS.md          # is it a symlink? to where?
git check-ignore -v CLAUDE.md AGENTS.md   # is it gitignored (machine-local)?
```

- If `CLAUDE.md` is a symlink to a global/dot-agents path, never write
  repo-specific content through it.
- Repo-specific, machine-local guidance that should survive only in this checkout
  goes in the repo-root `AGENTS.md` (a normal, gitignored file here) — not in the
  `CLAUDE.md` symlink target.
- Team-shared, committable guidance goes in `docs/solutions/` (its own frontmatter
  gate), never in `CLAUDE.md`/`AGENTS.md`, which this repo never commits.

## Why This Matters

Global-rule contamination silently degrades every future session across every
project by injecting one repo's quirks into the shared system prompt. It is
invisible from inside the repo (the symlink masks the real target) and only shows
up as unexplained behavior in unrelated projects.

## When to Apply

- Any request to "update CLAUDE.md" / "add to AGENTS.md" in this or any repo.
- Before a commit that would touch an agent context file.
- When `git status` looks unexpectedly clean after an edit you thought was staged.

## Examples

Detect before editing:

```bash
ls -la CLAUDE.md
# lrwxr-xr-x CLAUDE.md -> /Users/teslamint/.agents/rules/global/rules.mdc  <- STOP
git check-ignore -v AGENTS.md
# .gitignore:8:/AGENTS.md  AGENTS.md   <- machine-local, but a normal file: safe to edit locally
```

Revert a contaminated global file:

```bash
git -C ~/.agents checkout -- rules/global/rules.mdc
git -C ~/.agents diff --stat rules/global/rules.mdc   # expect: no diff
```
