---
module: changelog
date: "2026-08-21"
problem_type: convention
component: release-publication
severity: medium
applies_when:
  - "editing CHANGELOG.md in this repo"
  - "a commit lands after a version tag and touches CHANGELOG.md"
  - "preparing or running a release through skills/release"
related_components:
  - release-publication
  - validate-frontmatter
tags:
  - changelog
  - released-section-immutability
  - no-unreleased
  - release-gate
---

## Context

Two project documents forbid an `[Unreleased]` section in `CHANGELOG.md` and
require entries to be created only at release time:

- `docs/specs/2026-07-16-release-skill-design.md:69` — "CHANGELOG `Unreleased`
  section — not used; entries are created only at release time (specs/retros
  already track in-flight work)."
- `release-publication.sh:213` hard-fails (`newest CHANGELOG section does not
  match the requested version`) if the newest section is not the version being
  released.

A released section (e.g. `## [0.10.0] - 2026-08-03`) is therefore immutable:
anything that belongs in a future release must not be appended under an already
tagged heading, and an `[Unreleased]` heading would break the next release gate
because nothing in the flow renames it to the new version.

## Guidance

When a commit after a tag adds a CHANGELOG line (observed with `add8bc3` #16,
which appended an entry under `[0.10.0]`), remove the stray line. It is
recreated at the correct version during the v0.11.0 (next) release cycle, where
`release-publication.sh` drafts the section from specs/retros in `last-tag..HEAD`.

Do NOT fix it by adding an `[Unreleased]` section — that satisfies the immediate
"missing entry" symptom but invalidates the newest-section gate on the next
release.

## Why This Matters

The release gate reads the *newest* CHANGELOG section to decide whether the
manifest version and the changelog agree. An `[Unreleased]` section makes the
newest section never match the requested release version, so the next
`release-publication.sh` invocation fails its preconditions and blocks shipping.
Released sections are also historical records; mutating them falsifies what
shipped in that version.

## When to Apply

- Touching `CHANGELOG.md` after a tag exists.
- Reviewing a PR that edits an already-released `## [x.y.z]` heading.
- Debugging a "newest CHANGELOG section does not match" failure in
  `release-publication.sh`.

## Examples

Wrong fix (breaks the next release gate):

```markdown
## [Unreleased]

### Fixed
- Issue #14: Shipped a self-contained planning schema and verifiable canonical seals.

## [0.10.0] - 2026-08-03
```

Right fix (drop the misplaced line; it is recreated at release time):

```markdown
## [0.10.0] - 2026-08-03

### Fixed
- Prevented feature-derived path escape, collision-suffix drift on rerun, incomplete archive matches, stranded corruption backups, and stale archive verification.
```
