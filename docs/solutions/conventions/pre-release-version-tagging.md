---
module: release
date: "2026-08-22"
problem_type: convention
component: versioning
severity: low
applies_when:
  - "creating a snapshot build between formal releases"
  - "bumping plugin manifests for local autoUpdate testing"
  - "another agent or session asks which pre-release format to use"
related_components:
  - plugin-cache
  - release-skill
tags:
  - pre-release
  - dev-build
  - semver
  - tagging
---

## Context

Between formal releases (`v0.10.0`, `v0.11.0`, ...) the plugin cache needs
version bumps so that autoUpdate detects a change. A lightweight ceremony
produces these snapshots without invoking the release skill or touching
CHANGELOG.

## Convention

### Format

```
v<target>-dev.<N>
```

- `<target>`: the next expected release version (e.g. `0.11.0`).
- `<N>`: monotonically increasing integer, starting at 1.
- SemVer 2.0.0 precedence: `0.11.0-dev.1 < 0.11.0-dev.2 < 0.11.0`.

When the target version changes (e.g. scope grows from patch to minor),
reset `<N>` to 1 under the new target.

### Commit

One commit that changes exactly the two plugin manifests:

```
.claude-plugin/plugin.json
.codex-plugin/plugin.json
```

Both `version` fields must be byte-identical to `<target>-dev.<N>`.

Commit message pattern (matches the v0.11.0-dev.1 precedent):

```
chore: dev build <target>-dev.<N> — <one-line summary>
```

### Tag

Annotated tag on the dev-build commit. The annotation marks it as
non-release:

```
git tag -a "v<target>-dev.<N>" -m "dev build <target>-dev.<N> — local-install tag (not a published release)

<body: what changed since last tag>"
```

### Scope

- **Local only.** Dev-build commits and tags are not pushed to origin.
  They exist for local plugin-cache autoUpdate.
- **No CHANGELOG entry.** The release skill owns CHANGELOG; dev builds
  do not write to it.
- **No GitHub release.** Publication is reserved for the release skill's
  outward-publication ceremony.
- **No release skill involvement.** Dev builds bypass the seven-phase
  release ceremony entirely.

### Interaction with the release skill

The release skill's Phase 4 (Version) reads the current manifest version as
the release base. A manifest at `0.11.0-dev.1` yields a valid proposal of
`0.11.0` because `0.11.0-dev.1 < 0.11.0` under SemVer precedence. No
conflict.

Preflight step 6 checks for `v*` tags pointing at HEAD. Because dev-build
commits are separate from the release commit, no collision occurs.

Preflight step 8 discovers the latest reachable tag via `git describe`. If
a dev tag is reachable, the release range narrows to changes since that dev
build. This is acceptable — the release draft still covers the full scope
via its source inventory.

### What not to do

- Do not reuse or move a dev tag. Create a new `dev.<N+1>` instead.
- Do not delete a dev tag to "clean up." Tags are historical markers.
- Do not create dev builds on feature branches. They belong on the local
  default branch only.

## Precedent

```
v0.11.0-dev.1  (4946334)
  commit: chore: dev build 0.11.0-dev.1 — re-apply two PR#19 fixes, bump manifests
  tag:    annotated, "local-install tag (not a published release)"
  scope:  local only, not on origin/main
```
