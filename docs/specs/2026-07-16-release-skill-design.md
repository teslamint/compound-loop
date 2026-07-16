---
title: release skill (13th) — versioned release ceremony
status: approved
date: 2026-07-16
schema: spec/v1
---

# release Skill Design

_Created 2026-07-16._

## Overview

A 13th skill, `release`, owning the post-merge versioned-release ceremony: CHANGELOG authoring, version bump across both plugin manifests, and an annotated git tag — kept out of `shipping` (per ROADMAP) so feature work stays independently revertable. Trigger fired 2026-07-16: this repo cut v0.1.0 manually, exposing the friction this skill removes (no CHANGELOG, human-adjudicated tag target, unverified manifest sync).

## User Scenarios

### S1: Cut v0.2 from lifecycle artifacts (main path)

After several features merge, the user invokes `/release` (Codex: `$release`). The skill finds the last tag (`git describe --tags --abbrev=0`), collects specs and retros landed since it, drafts a CHANGELOG section in their feature-level language, proposes a semver bump (0.1.0 → 0.2.0), and presents both at a USER gate. On approval it writes CHANGELOG.md, bumps both manifests, commits the three files as one release commit, and creates annotated tag `v0.2.0` on that commit. Ends `Release complete — v0.2.0`.

### S2: Spec-less repo fallback

A consuming repo without `docs/specs/` invokes `/release`. Collection finds no lifecycle artifacts, falls back to `git log <last-tag>..HEAD`, drafts from commit subjects (filtering chore/review noise), and labels the draft's provenance ("derived from git log — no spec inventory"). Same gate and ceremony.

### S3: Manifest drift blocks the ceremony

`.claude-plugin/plugin.json` says 0.2.0 but `.codex-plugin/plugin.json` says 0.1.0. Preflight fails before any drafting: `Release failed — manifest version mismatch (.claude-plugin 0.2.0 ≠ .codex-plugin 0.1.0)`. Independently, `scripts/validate.sh` check 7 catches the same drift on every validation run, release or not.

### S4: Nothing to release (idempotent re-run)

`/release` is invoked when HEAD is already tagged and no commits landed since. Preflight detects it and ends `Release skipped — HEAD already released as v0.2.0` without touching anything.

### S5: Headless invocation prepares but never executes

An orchestrator dispatches `release` with `mode:headless`. The skill runs Preflight → Collect → Draft → Version fully, writes the draft to `.release/draft.md` (gitignored; created on demand), and stops before Execute — tagging the default branch requires first-hand consent (pilot-proven: relayed gate approval is not execution authorization, `skills/release-loop/SKILL.md:51`). Ends `Release skipped — headless: ceremony requires first-hand consent; draft prepared at .release/draft.md`, handing the exact commands up.

## Assumptions and Preconditions

Verified against the live repo at design time (grep/command, not recall); consuming repos that break one land on the named fallback or failure path.

1. **A previous tag exists** for the normal path — this repo: `v0.1.0` (`git describe --tags --abbrev=0`). No tag and no specs → first-release path (no backfill, version proposed at the gate).
2. **Both manifests exist with parseable `version` fields** (`.claude-plugin/plugin.json:3`, `.codex-plugin/plugin.json:3`). Absence or non-semver is an explicit check 7 failure, never a silent pass.
3. **Lifecycle-artifact convention** — dated specs/retros under `docs/specs/`, `docs/retros/` with committed history (Approach B's inventory). Repos without it: S2 git-log fallback.
4. **validate.sh structure as of `76cd2af`** — six checks; roster hardcoded at `scripts/validate.sh:34`; check 6's producers/consumers/regex/9-count invariant hardcoded at `:115,:128,:137,:139,:141-145` (five coordinated edits required, per Testing).
5. **headless-contract v1 table shape** and its bump rule at `schemas/headless-contract.md:5` — the additive-row argument and the rule clarification both assume this exact wording.
6. **A user present at the gate** — the ceremony cannot complete unattended: USER gate + first-hand-consent rule (`skills/release-loop/SKILL.md:51`). Headless is prepare-only by design (S5).
7. **No git remote** — push/GitHub release are out of scope; the first remote is the trigger for that deferred iteration.
8. **Runtime state at ceremony**: clean working tree, on the default branch (Preflight-enforced).

## Scope

### In

- CHANGELOG.md authoring (Keep a Changelog shape), artifact-derived (Approach B): specs/retros since last tag are the source inventory; git log is the supplement for spec-less changes and the fallback for spec-less repos.
- Backfill, keyed on **CHANGELOG.md absence** (not tag absence): when the file doesn't exist and prior releases do (tags and/or release-era artifacts present), create it with sections for those prior releases derived from their specs/retros — in this repo, a one-time `v0.1.0` section from the v0.1 spec + retro. When no prior release artifacts exist, no backfill: the file starts at the current release.
- Headless draft handoff: `.release/draft.md`, gitignored (`.release/` added to .gitignore with the feature).
- Version bump: both manifests, same commit as the CHANGELOG update; tag targets that commit.
- Semver proposal by the agent (pre-1.0 convention: features → minor, fixes-only → patch), decided by the user at the gate.
- Manifest version-sync validation as `scripts/validate.sh` check 7 (permanent drift protection, independent of ceremonies).
- Terminal signal row for `release` added to `schemas/headless-contract.md` (additive, contract stays v1; bump rule clarified — see Contract change).
- Headless mode: prepare-only (S5).

### Out (deferred, with triggers)

- ROADMAP updates (shipped-candidate cleanup, trigger-fired marks, carry-forward removal, next-version section) — next `release` iteration, after the mechanics prove out on v0.2.
- Generalized tag-target decision rule — in-skill the target is always the release commit; the retroactive-tagging case is documented in the v0.1 EC decision, not in this skill.
- GitHub release / push — feature-detected and documented only; first repo with a remote is the trigger to implement and verify.
- CHANGELOG `Unreleased` section — not used; entries are created only at release time (specs/retros already track in-flight work).

## Architecture

Single skill `skills/release/SKILL.md` (+ references if needed). Phases:

1. **Preflight** — clean working tree; on default branch; both manifest versions parse and agree; locate last tag (none, and no specs either → first-release path: no backfill, initial version proposed at the gate); diff last tag..HEAD non-empty (else S4 skip); CHANGELOG.md existence noted (absent → backfill per Scope).
2. **Collect** — specs (`docs/specs/`) and retros (`docs/retros/`) with commits in `<last-tag>..HEAD`; supplement with `git log` for changes no spec covers; the collected spec list is the release's **source inventory** (CONCEPTS.md sense).
3. **Draft** — CHANGELOG section: feature entries from spec Overviews, notable process/infra entries from git log supplement; every inventory spec appears or gets an explicit drop reason (traceability criterion). A spec whose feature was reverted in-range is not auto-detected — it stays in the inventory and is adjudicated at the gate (drop reason: "reverted"); accepted as a judgment step, not automated.
4. **Version** — semver proposal with one-line justification.
5. **Gate (USER)** — present draft + version + exact commands. Never auto-skip. Headless: stop here, emit skip signal (S5).
6. **Execute** — write CHANGELOG.md, bump both manifests, single commit, annotated tag `v<version>` with a message naming the highlights.
7. **Report** — terminal signal per contract.

Entry is user invocation only. `release-loop`, `shipping`, and `retrospective` are not modified and do not invoke it.

## Interface

- Invocation: `/release` (Claude Code), `$release` (Codex). Optional argument: explicit version (skips the proposal, still gated).
- Terminal signals (new contract row): `Release complete — v<version>` / `Release skipped — <reason>` / `Release failed — <reason>`.

## Contract change

`schemas/headless-contract.md` gains one producer row for `release`. The contract stays `v1`: a new producer row is additive — no consumer that predates `release` can encounter its signals (the only callers ship with or after the skill), while bumping would force every existing consumer to accept an unknown version for zero protection. The bump rule at `schemas/headless-contract.md:5` is clarified to: bump on any change to *existing* lines or their semantics; adding a new producer row is additive and does not bump.

## Data model

- `CHANGELOG.md` (repo root): Keep a Changelog headings — `## [<version>] - YYYY-MM-DD` with `### Added / Changed / Fixed` subsections as applicable.
- Tag: annotated, `v<semver>`, message = version + highlight list.
- Version agreement invariant (four-way, at release time): `.claude-plugin/plugin.json` == `.codex-plugin/plugin.json` == newest CHANGELOG section == newest tag. validate.sh check 7 enforces the manifest pair permanently; the ceremony verifies all four before declaring `Release complete`. On a ceremony that creates CHANGELOG.md (backfill run), "newest section" is the release being cut — backfilled sections sit below it.

## Testing

- `scripts/validate.sh` check 7 (manifest version sync): reads the `version` fields of both manifests, fails naming both files and values on mismatch; an **absent or non-semver** `version` in either manifest is its own explicit failure naming that file (a missing field must never compare equal to another missing field). Roster line `EXPECTED_SKILLS` (`scripts/validate.sh:34`) gains `release` so check 3 covers the new SKILL.md.
- Fixture: mutate `.codex-plugin/plugin.json` version to `9.9.9` → validate.sh nonzero exit, output names the file; restore. Second fixture: delete the field → same, naming the file.
- Signal drift: check 6 does **not** discover producers dynamically — its producer tuple, consumer file list, state regex, producer-key mapping, and the 9-signal count invariant are all hardcoded (`scripts/validate.sh:115,137,139,141-145` and the `len(flat) != 9` assertion at `:128`, verified against live source in review). Adding `release` therefore requires five coordinated edits: producer tuple + `release` consumer entry + `Release` in the state regex + producer-key mapping + invariant `9 → 12`. Only after those edits does the drift protection extend to release's signals.
- Drift fixture: with the check-6 edits in place, a one-byte mutation to a quoted release signal in `skills/release/SKILL.md` must fail validate.sh naming file and line (new case in the `scripts/test-signal-drift.sh` Case A–G pattern).
- Headless smoke: subagent runs `release` with `mode:headless` on this repo → no commit, no tag, draft written, last line `Release skipped — headless: ...` byte-exact.
- Dogfood: v0.2.0 is cut with this skill (S1), which is itself the primary end-to-end test.

## Risks

- **Semver misjudgment** — mitigated by the USER gate; the agent's proposal carries a justification the user can override.
- **CHANGELOG misses spec-less changes** — mitigated by the git log supplement pass; residual risk accepted (noise-filtering is judgment).
- **Contract-table edit breaks the drift check** — the quoted signals in the new SKILL.md must be byte-identical to the new row; check 6 fails loudly if not (this is protection, not risk, but the first edit must run validate.sh before commit).
- **First-run backfill misrepresents v0.1** — backfill derives from the committed v0.1 spec + retro, both of which carry verified claims; kept to a short section.

## Success Criteria

1. `scripts/validate.sh` passes with the 13-skill roster, including `release` frontmatter.
   - **Measured by**: `bash scripts/validate.sh` → exit 0, contains `ok:   skills/release/SKILL.md frontmatter valid` and `ALL CHECKS PASSED`.
2. Manifest version drift is caught by check 7, naming the offending files — for both a mismatched and a missing `version` field.
   - **Measured by**: two fixture runs — (a) set `.codex-plugin/plugin.json` version to `9.9.9`, (b) delete the field; each → nonzero exit naming `.codex-plugin/plugin.json`; restore after each.
3. The release terminal signals are drift-protected: a one-byte mutation to a quoted signal line in `skills/release/SKILL.md` fails validate.sh naming file and line.
   - **Measured by**: fixture run per the `scripts/test-signal-drift.sh` pattern (Case for release added).
4. The contract-table change is additive: existing producer rows and signals are byte-identical to before; only the release row and the bump-rule clarification are new. ("Additive" applies to the contract table — check 6's code changes per Testing are expected, not a violation.)
   - **Measured by**: `git diff <before>..<after> -- schemas/headless-contract.md` shows only added lines plus the rule-line edit; validate.sh check 6 passes with the 12-signal invariant.
5. v0.2.0 is cut with the skill and the four-way version agreement holds.
   - **Measured by**: `git tag -l v0.2.0` non-empty; both manifests report the same version as the newest CHANGELOG section heading and the newest tag (single command comparing all four).
6. Traceability: every spec committed in `v0.1.0..HEAD` appears in the v0.2.0 CHANGELOG section or in an explicit drop note.
   - **Measured by**: list `docs/specs/*.md` with commits in that range; for each, grep the CHANGELOG section for its topic; zero unaccounted specs.
7. Headless invocation prepares but does not execute.
   - **Measured by**: smoke run with `mode:headless` → no new commits or tags, `.release/draft.md` exists, last non-empty line starts `Release skipped — `.

## Open Decisions

- **GitHub release body shape** (what the release notes reuse from CHANGELOG) — owner: the future iteration triggered by the first remote; not blocking.
- **ROADMAP-update phase design** (which of the four update tasks run automatically vs. gated) — owner: user, at the next `designing` cycle for the deferred scope.
