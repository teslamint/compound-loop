---
name: release
description: Cut a local versioned release from committed lifecycle evidence with an artifact-derived CHANGELOG, synchronized plugin manifests, a first-hand USER gate, and an annotated tag. Use via /release (Claude Code) or $release (Codex); pass mode:headless for a prepare-only handoff or a SemVer argument to propose that exact version.
---

# Release

Owns the local post-merge versioned-release ceremony. It turns committed specs,
retros, and notable commits into one release draft, synchronizes both plugin
manifests, and tags the resulting release commit. It never pushes a commit or
tag and never creates a GitHub release.

Every invocation ends with exactly one canonical terminal line as its last
non-empty output: `Release complete — v<version>`,
`Release skipped — <reason>`, or `Release failed — <reason>`. Concrete
instantiations below are deliberately shown as prose or fenced output; these
three placeholders are the signal contract quoted for drift validation.

## Arguments

Accept zero, one, or both of these arguments, in either order:

- `mode:headless` — prepare `.release/draft.md`, then stop before the USER gate.
- `<explicit-semver>` — use this SemVer 2.0.0 value as the proposed version;
  explicit input bypasses proposal generation, not validation or consent.

Reject duplicate mode arguments, more than one version, unknown arguments, and
versions that are not SemVer 2.0.0. A rejected invocation performs no phase
work and reports failure.

## Entry / Exit / Gate

- **Entry**: direct user invocation in a git repository, or an orchestrator
  invocation with `mode:headless`.
- **Exit**: an annotated `v<version>` tag on a release commit that changes
  exactly `CHANGELOG.md`, `.claude-plugin/plugin.json`, and
  `.codex-plugin/plugin.json`; a prepare-only `.release/draft.md`; or an
  explicit skip/failure with no later phase run.
- **Gate**: USER, always. Commit and tag creation require first-hand approval
  received by the same session that executes them. Relayed approval from an
  orchestrator or another worker is handoff evidence only, never execution
  authorization. `enforces: P7`

Run the seven phases in order. A failure or skip ends the invocation
immediately; do not collect, draft, write, commit, or tag after a terminal
Preflight result.

## Phase 1: Preflight

Perform these checks in the listed order so the first terminal condition is
stable and no release-note work occurs for an invalid repository.

1. **Git repository** — require `git rev-parse --is-inside-work-tree` to return
   `true` and require a committed `HEAD`.
2. **Clean worktree** — require `git status --porcelain` to be empty. Ignored
   `.release/` state does not make the tree dirty. Never stash or discard work.
3. **Default branch** — obtain the current branch with
   `git branch --show-current`; reject detached HEAD. Detect the default branch
   with:

   ```bash
   git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|origin/||' || echo main
   ```

   Require the current branch to equal the detected default branch. A release
   commit is never created on a feature branch.
4. **Manifest validity** — require both `.claude-plugin/plugin.json` and
   `.codex-plugin/plugin.json` to exist, parse as JSON, contain a string
   `version`, and have that value match SemVer 2.0.0, including valid optional
   prerelease/build components. Name the offending file in any absence, JSON,
   field, type, or SemVer failure.
5. **Manifest agreement** — require the two parsed values to be byte-identical.
   A mismatch ends before `.release/draft.md` is created or release sources are
   collected. For values `0.2.0` and `0.1.0`, the final report is:

   ```text
   Release failed — manifest version mismatch (.claude-plugin 0.2.0 ≠ .codex-plugin 0.1.0)
   ```
6. **Already released** — list SemVer-shaped `v*` tags pointing at HEAD, sorted
   by version descending. If one exists, stop without changing files, commits,
   or tags. For `v0.2.0`, the final report is:

   ```text
   Release skipped — HEAD already released as v0.2.0
   ```
7. **Previous tag and range** — discover the latest reachable annotated or
   lightweight tag with `git describe --tags --abbrev=0`. With a tag, the
   release range is `<last-tag>..HEAD`. Without one, the range is all commits
   reachable from `HEAD`, and this is a first-release path.
8. **Non-empty range** — require at least one commit in the range. If a previous
   tag exists and the range is empty, report the already-released/no-change
   state rather than manufacturing release notes. On the first-release path,
   require at least one reachable commit.
9. **CHANGELOG/backfill state** — record whether `CHANGELOG.md` exists. If it is
   absent and earlier release evidence exists (a prior tag or release-era
   lifecycle artifacts), schedule concise older sections below the new section.
   If no prior release evidence exists, start the file with the current release
   only.

Preflight reads state only. Apart from the ignored draft written later in
headless mode, no phase before Execute mutates the repository.

## Phase 2: Collect

Collection is based on committed evidence, never the working conversation.

1. Enumerate committed lifecycle paths in the release range:

   ```bash
   git log --name-only --format= <range> -- docs/specs docs/retros
   ```

   Remove blank lines, deduplicate paths, retain existing `docs/specs/*.md` and
   `docs/retros/*.md` paths, and read their committed versions at `HEAD`.
   For a first release, use the same command over `HEAD` instead of a tag range.
2. Record every collected spec path in a **Source inventory**. Specs are the
   traceability unit; retros are supporting evidence and remain separately
   listed as **Retros consulted**.
3. For every spec, read its Overview and user-facing intent. Draft feature
   language from that evidence rather than copying commit subjects. Use retros
   to qualify verified outcomes and to ground any older backfill section.
4. Collect non-merge commit hashes and subjects in the range. Filter mechanical
   noise: merge commits, `chore:`-only maintenance, review-only commits,
   formatting-only commits, and commits whose user-visible topic is already
   covered by an inventory spec. Keep meaningful feature, fix, documentation,
   workflow, or infrastructure subjects not otherwise represented as the
   **Git-log supplement**.
5. If no committed specs exist in the range, make git log the primary source
   and attach this exact provenance label to the draft:

   ```text
   derived from git log — no spec inventory
   ```

6. When backfill is scheduled, derive each older tagged section from lifecycle
   files reachable at that tag, bounded by the preceding tag when one exists.
   The earliest tag uses repository root through that tag. Do not attribute
   post-tag evidence to an older release.

## Phase 3: Draft

Draft a Keep a Changelog-shaped current section:

```markdown
## [<version>] - <YYYY-MM-DD>

### Added
- <feature-level outcome>

### Changed
- <notable changed behavior or workflow>

### Fixed
- <user-relevant correction>
```

Use only the subsections that have entries. The proposed version may still
change at the gate, so render the heading again after the version decision.
When `CHANGELOG.md` already exists, preserve its existing content below the new
current section. When backfilling, place every older section below the current
section, newest first.

Trace the source inventory explicitly:

- Map every inventory spec to one or more current-section entries.
- If a spec should not appear (for example, its feature was reverted), put its
  path and a concrete reason in a **Drop-list** shown at the USER gate.
- Never silently omit an inventory spec. An empty drop-list is written as
  `None`.
- Retain the mapping and drop-list in `.release/draft.md` for headless runs and
  in the interactive gate presentation for interactive runs.

The full draft consists of provenance, source inventory, retros consulted,
git-log supplement, traceability mapping, drop-list, proposed version and
justification, complete CHANGELOG text, tag highlights, and exact commands.

## Phase 4: Version

First validate that the current manifest version is the release base.

- If an explicit version argument was supplied, use it as the proposal after
  requiring it to be greater than the current manifest version under SemVer
  precedence.
- Otherwise, for a pre-1.0 base, propose the next minor version when the range
  contains a feature and the next patch version when it contains fixes only.
- On other bases, apply standard SemVer intent: breaking behavior proposes
  major, backward-compatible features propose minor, and fixes-only proposes
  patch.
- State a one-line justification tied to collected evidence. The USER may
  revise the proposal; validate a revised value with the same rules before
  presenting the gate again.

Render the final proposed version into the CHANGELOG heading, release commit
subject, tag name, tag annotation, manifest-edit commands, and verification
commands. Commands presented at the gate or persisted to the draft must contain
the literal resolved version and full resolved CHANGELOG content, not symbolic
placeholders.

### Headless boundary

In `mode:headless`, stop after Version. Create `.release/` on demand and write
`.release/draft.md` with every draft component named in Phase 3. Its final
section is `## Exact commands` and contains the fully rendered write, manifest
bump, validation, staging, commit, tag, and verification commands an authorized
interactive session would run.

Headless mode never asks a question, writes a tracked file, updates a manifest,
commits, or tags. After confirming the draft exists, end with this byte-exact
last non-empty line:

```text
Release skipped — headless: ceremony requires first-hand consent; draft prepared at .release/draft.md
```

## Phase 5: Gate

Present one review packet before asking anything:

1. release range and provenance;
2. source inventory, retros consulted, and git-log supplement;
3. traceability mapping and the complete drop-list;
4. proposed version with its one-line justification;
5. complete CHANGELOG content and tag highlights; and
6. exact commands, with literal paths, versions, messages, and file content.

Use the harness's blocking question tool per
`references/question-tools.md`. Ask one single-select question with these
distinct outcomes: **Approve this exact release** (recommended), **Revise the
draft or version**, and **Cancel the release**. A revision returns to Draft or
Version and presents a new complete packet. Cancellation exits without tracked
changes. If the blocking tool is unavailable or errors, show the same numbered
options in chat and wait; never treat silence or relayed approval as consent.

The exact command packet must, in execution order:

- write the complete `CHANGELOG.md` content;
- replace only the existing version string in each manifest, preserving all
  unrelated bytes and formatting;
- run `bash scripts/validate.sh`;
- stage the three named release files explicitly;
- prove the staged path set is exactly those three files;
- create one release commit with the resolved version in its subject;
- create one annotated tag on that commit, with the version and draft
  highlights in its annotation; and
- run the four-way agreement and source-inventory traceability checks.

Approval applies only to the packet displayed. Any changed version, CHANGELOG
entry, drop reason, command, or tag message requires a fresh gate.

## Phase 6: Execute

Execute only after first-hand approval in this session.

1. Recheck the clean worktree, current/default branch equality, manifest
   agreement, range, and absence of the proposed tag. If state changed since
   the gate, stop and present a newly derived packet; do not execute stale
   commands.
2. Write the approved `CHANGELOG.md` exactly.
3. Surgically replace the version value in both manifest files. Parse both
   files again and confirm the only intended manifest change is the version
   string; never reserialize or reformat unrelated JSON.
4. Run `bash scripts/validate.sh`. If it fails, do not stage, commit, or tag;
   report the command and relevant failure output.
5. Stage exactly `CHANGELOG.md`, `.claude-plugin/plugin.json`, and
   `.codex-plugin/plugin.json` by name. Compare
   `git diff --cached --name-only` with that exact three-path set. Any missing
   or additional path is a failure; never use `git add .` or `git add -A`.
6. Create one release commit using the approved subject. Verify its changed
   path set is exactly the three release paths.
7. Create the approved annotated `v<version>` tag on that new commit. The tag
   annotation names the version and the approved highlights. Never create a
   lightweight tag and never push it.

If validation, staging, commit, or tag creation fails, do not attempt the later
steps. In particular, no validation or verification failure may be followed by
tag creation.

## Phase 7: Report

Before reporting success, prove all of the following from repository state:

- the two parsed manifest versions equal the approved version;
- the first `## [<version>] - <date>` heading in `CHANGELOG.md` names that
  version;
- `git describe --tags --abbrev=0 HEAD` names the approved tag;
- the approved annotated tag dereferences to the release commit;
- the release commit changes exactly the three release files; and
- every source-inventory spec is represented by the approved current-section
  mapping or the approved drop-list reason.

Report the release commit, annotated tag, validation result, four-way agreement,
and traceability result. Terminal state is always the last non-empty output
line, in interactive and headless invocations alike, using exactly one of the
three canonical forms defined at the top of this skill. `enforces: P3, P9`

On success, instantiate the completion form with the approved tag. On a no-op
or cancellation, instantiate the skip form with one specific reason. On any
invalid input, preflight failure, command failure, or postcondition failure,
instantiate the failure form with one actionable reason. Do not print anything
after the terminal line.

## Handoff

The release ceremony is local-only. Report the terminal state and stop. Do not
invoke `shipping`, push the commit or tag, create a GitHub release, update
`ROADMAP.md`, or invoke `retrospective`; those are separate user- or
orchestrator-owned workflows.
