---
name: release
description: Cut a local versioned release from committed lifecycle evidence with an artifact-derived CHANGELOG, synchronized plugin manifests, a first-hand USER gate, and an annotated tag. Use via /release (Claude Code) or $release (Codex); pass mode:headless for a prepare-only handoff or a SemVer argument to propose that exact version.
---

# Release

Owns the local post-merge versioned-release ceremony and an explicitly selected,
separate outward-publication ceremony. The local action turns committed specs,
retros, and notable commits into one release draft, synchronizes both plugin
manifests, and tags the resulting release commit. That local action never pushes
a commit or tag and never creates a GitHub release.

Every invocation ends with exactly one canonical terminal line as its last
non-empty output: `Release complete — v<version>`,
`Release skipped — <reason>`, or `Release failed — <reason>`. Concrete
instantiations below are deliberately shown as prose or fenced output; these
three placeholders are the signal contract quoted for drift validation.

The separate outward-publication action uses its own additive terminal family:
`Publication complete — v<version>`, `Publication skipped — <reason>`, or
`Publication failed — <reason>`. These are the only inline Publication signal
placeholders; concrete publication outcomes must remain prose or fenced output.

## Action dispatch

Parse the complete invocation before doing any phase work.

- When the token `publish` is present, require exactly the form
  `publish <semver> [repair] [mode:headless]`, with the optional tokens allowed
  in either order. Reject a duplicate `publish`, version, `repair`, or mode
  token; reject a missing version and every unknown token. Dispatch to
  `skills/release/references/publication.md`; return before any local-release
  phase. The publication action owns its own Preflight, Packet, Gate, Execute,
  Verify, and Report phases and never inherits consent from this local action.
- When `publish` is absent, reject `repair` without `publish`. Otherwise use the
  unchanged local-release argument contract below. Publication-only tokens must
  never fall through to the local ceremony.

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
  `.codex-plugin/plugin.json`; an explicitly approved revert of a recognized
  incomplete release commit; a prepare-only `.release/draft.md`; or an
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
   default_branch="$(
     git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null |
       sed 's|^origin/||'
   )"
   if [ -z "$default_branch" ]; then
     default_branch=main
   fi
   ```

   The explicit empty-result check is required because `sed` exits successfully
   on empty input when `origin/HEAD` is absent. Require the current branch to
   equal `default_branch`. A release commit is never created on a feature
   branch.
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
7. **Incomplete release recovery** — before discovering a normal release
   range, inspect an untagged `HEAD` for a release commit left behind by a
   failed pre-tag check or tag command. A commit is a recognized incomplete
   release only when all of these independently derived facts agree:
   - its exact subject is `Release v<version>`, where `<version>` is SemVer;
   - its changed path set is exactly `CHANGELOG.md`,
     `.claude-plugin/plugin.json`, and `.codex-plugin/plugin.json`;
   - both parsed manifest versions are byte-identical to `<version>`; and
   - the first version section in `CHANGELOG.md` is exactly `<version>`.

   If any release-shaped evidence exists at `HEAD` (for example, a
   `Release v...` subject or the exact release path set) but those facts do not
   all agree, fail as an ambiguous partial release. Never collect sources,
   propose a later version, or silently treat either a recognized or ambiguous
   partial release as normal input.

   For a recognized incomplete release, stop the normal seven-phase path and
   branch on invocation mode. An interactive invocation presents a fresh
   first-hand USER recovery gate. The packet identifies the existing commit
   and offers three distinct outcomes: **Revalidate and tag this exact commit**
   (recommended), **Revert this incomplete release**, and **Cancel recovery**.
   Prior release approval does not authorize recovery.
   The tag-recovery packet must re-run `bash scripts/validate.sh`, reverify the
   subject, exact three-path set, both manifests, newest CHANGELOG version,
   source-inventory disposition, absence of the proposed tag, and current
   `HEAD`, then create one annotated tag on that same commit and run tag-only
   verification. Reconstruct the inventory over the preceding release range
   ending at `HEAD^`; do not trust an ignored draft as the only traceability
   record. Derive the resolved annotation highlights from the existing newest
   CHANGELOG section and show the reconstructed mapping, Drop-list, highlights,
   and exact recovery packet at this gate.

   In `mode:headless`, never present that gate or ask any question. Create
   `.release/` on demand and write `.release/draft.md` as a recovery handoff
   containing the recognized subject/version, commit ID, exact path set,
   manifest values, newest CHANGELOG version, reconstructed inventory mapping
   and Drop-list, resolved highlights, and both available recovery choices.
   Render the tag choice and revert choice as two separate, complete fenced
   `bash` programs, each beginning with `set -euo pipefail` and containing all
   resolved checks and commands for only that choice. Neither packet may be an
   incomplete suffix or refer to commands outside its own block. Headless
   recovery does not modify tracked files, commit, revert, or tag. After
   confirming the draft exists, end with the same byte-exact headless skip
   signal defined under the Headless boundary. Do not collect or propose a
   normal next version.

   In interactive recovery, the rollback packet must be separately displayed
   and approved. It creates one `git revert --no-edit HEAD` commit, verifies
   that the revert changed exactly the same three release paths, verifies that
   the incomplete version is no longer the manifest/CHANGELOG release state,
   and confirms that its tag is absent. It then stops; a future release requires
   a new invocation and a new normal gate. Never reset, rewrite, or discard the
   incomplete commit.

   Each recovery choice is rendered as one Bash program whose first command is
   `set -euo pipefail`. Execute only the approved program, as one fail-fast
   shell invocation. If any command fails, Bash must not reach a later command:
   in particular, a failed revalidation or pre-tag check cannot create a tag,
   and a failed rollback cannot be reported as resolved. End a successful tag
   recovery, rollback, cancellation, and command-failure signals respectively
   by instantiating these exact forms:

   ```text
   Release complete — v<version>
   Release skipped — incomplete release v<version> reverted; invoke release again
   Release skipped — incomplete release recovery cancelled
   Release failed — incomplete release recovery failed at <command>; HEAD remains untagged
   ```

   The terminal signal remains the last non-empty output. Do not resume normal
   version proposal in the same invocation after any recovery outcome.
8. **Previous tag and range** — discover the latest reachable annotated or
   lightweight tag with `git describe --tags --abbrev=0`. With a tag, the
   release range is `<last-tag>..HEAD`. Without one, the range is all commits
   reachable from `HEAD`, and this is a first-release path.
9. **Non-empty range** — require at least one commit in the range. If a previous
   tag exists and the range is empty, report the already-released/no-change
   state rather than manufacturing release notes. On the first-release path,
   require at least one reachable commit.
10. **CHANGELOG/backfill state** — record whether `CHANGELOG.md` exists. If it is
   absent and earlier release evidence exists (a prior tag or release-era
   lifecycle artifacts), schedule concise older sections below the new section.
   If no prior release evidence exists, start the file with the current release
   only.

Preflight reads state only. Apart from an ignored draft written for a headless
normal-release or recovery handoff, no phase before Execute mutates the
repository.

## Phase 2: Collect

Collection is based on committed evidence, never the working conversation.

1. Enumerate committed lifecycle paths in the release range:

   ```bash
   git log --name-only --format= <range> -- docs/specs docs/retros
   ```

   Remove blank lines and deduplicate paths, but do not filter the result by
   current filesystem existence. For a first release, use the same command over
   `HEAD` instead of a tag range.
2. Record **every** collected `docs/specs/*.md` path in the **Source inventory**,
   including a path deleted or renamed before `HEAD`. A committed in-range path
   is inventory evidence even when the current worktree no longer contains it.
   Retros are supporting evidence and remain separately listed as **Retros
   consulted**; they are not source-inventory units.
3. Recover spec content before drafting:
   - When the path exists at `HEAD`, read the committed `HEAD` version.
   - When it is absent at `HEAD`, find the last in-range add/modify commit with
     `git log --diff-filter=AM -1 --format=%H <range> -- <path>` and read that
     commit's blob with `git show <commit>:<path>`.
   - If the range contains only the deletion, inspect the blob from the
     deletion commit's first parent (or the range base) as clearly labeled
     pre-range context. If no blob can be recovered, retain the path and record
     that recovery failed; never drop the inventory row.

   For every spec with recoverable content, read its Overview and user-facing
   intent. Draft feature language from that evidence rather than copying commit
   subjects. Any inventory path absent at `HEAD` must also have a structured,
   gate-visible Drop-list record whose `disposition` is exactly one normalized
   lowercase value: `deleted`, `renamed`, or `reverted`. Its separate `reason`
   remains concrete human-readable prose explaining what happened; recovered
   text does not waive that adjudication. Use retros to qualify verified
   outcomes and to ground any older backfill section.
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
When `CHANGELOG.md` already exists, split it immediately before its first
`## [<version>]` section. Preserve the stable title and preamble prefix
byte-for-byte at the beginning of the file, insert the new current section
after that prefix, and preserve all prior version sections below the new one.
For example, `# Changelog`, its explanatory preamble, then `## [0.1.0]` becomes
that same title and preamble, then `## [0.2.0]`, then `## [0.1.0]`; never put a
new version above the title or append it below an older version. If no version
section exists yet, keep the whole existing title/preamble as the prefix and
append the new current section after it. When backfilling, place every older
section below the current section, newest first.

Trace the source inventory explicitly:

- Map every inventory spec to one or more current-section entries.
- If a spec should not appear (for example, its feature was reverted), put its
  path and a concrete reason in a **Drop-list** shown at the USER gate.
- Render each Drop-list item as structured fields: `path`, `disposition`,
  `reason`, and `recovered_from`. Put every inventory spec absent at `HEAD` in
  that list with `disposition` set to exactly lowercase `deleted`, `renamed`,
  or `reverted`; preserve a gate-visible concrete `reason`; and name the
  recovered-content source (or state that no content was recoverable). Never
  treat absence at `HEAD` as a reason to erase the inventory row.
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
commands. The release commit subject is always exactly
`Release v<resolved-version>`; do not accept, render, approve, or execute an
alternative subject. Commands presented at the gate or persisted to the draft
must contain the literal resolved version and full resolved CHANGELOG content,
not symbolic placeholders. Every rendered exact-command packet is one complete
Bash program:
its first command is `set -euo pipefail`, all writes and checks follow in one
fenced `bash` block, and no command from the packet is presented as a separately
executable fragment. A copied packet must therefore stop at its first failing
write, validation, staging, commit, or verification command.

### Headless boundary

On the normal release path, `mode:headless` stops after Version; a recognized
incomplete release instead uses the recovery handoff defined in Preflight step
7. For a normal release, create `.release/` on demand and write
`.release/draft.md` with every draft component named in Phase 3. Its final
section is `## Exact commands` and contains exactly one fenced `bash` program
beginning with `set -euo pipefail`. That single program contains the fully
rendered write, manifest bump, validation, staging, commit, pre-tag
verification, tag, and tag-only verification commands an authorized
interactive session would run. Do not render independent shell fragments
before or after that program.

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
6. one fail-fast exact-command Bash program, with literal paths, versions,
   messages, and file content, including the exact commit subject
   `Release v<resolved-version>`.

Use the harness's blocking question tool per
`references/question-tools.md`. Ask one single-select question with these
distinct outcomes: **Approve this exact release** (recommended), **Revise the
draft or version**, and **Cancel the release**. A revision returns to Draft or
Version and presents a new complete packet. Cancellation exits without tracked
changes. If the blocking tool is unavailable or errors, show the same numbered
options in chat and wait; never treat silence or relayed approval as consent.

The exact command packet must be a single fenced `bash` program whose first
command is `set -euo pipefail`. All commands below occur in that one program, in
execution order. Do not split the packet into individually runnable snippets,
and do not offer later commands as recovery instructions after an earlier
command fails:

- write the complete `CHANGELOG.md` content;
- replace only the existing version string in each manifest, preserving all
  unrelated bytes and formatting;
- run `bash scripts/validate.sh`;
- stage the three named release files explicitly;
- prove the staged path set is exactly those three files;
- create one release commit whose entire subject is exactly
  `Release v<resolved-version>`; no prefix, suffix, scope, alternate wording,
  or additional subject text is allowed;
- before creating any tag, verify both manifest values, the newest CHANGELOG
  heading, the release commit's exact subject, the release commit's exact
  three-path set, and complete disposition of every source-inventory spec
  through an approved mapping or structured Drop-list record. For an
  absent-at-HEAD item, normalize the structured `disposition` with `.lower()`
  before comparing it with the allowed set `{deleted, renamed, reverted}`. If
  the command additionally validates the human-readable reason, compare
  `reason.lower()`; never use a case-sensitive substring test against the prose
  reason;
- create one annotated tag on that commit, with the version and draft
  highlights in its annotation; and
- after tag creation, run only the tag-name and tag-dereference checks needed
  to complete four-way agreement.

Use explicit nonzero assertions for every invariant so `set -e` can stop the
program. Where a command's natural exit status would hide a mismatch (for
example, a comparison inside output-producing code), make the mismatch exit
nonzero. The complete resolved CHANGELOG heredoc and resolved tag annotation
remain inside this same program; fail-fast structure must not replace or
abbreviate approved content.

Approval applies only to the packet displayed. Any changed version, CHANGELOG
entry, drop reason, command, or tag message requires a fresh gate.

## Phase 6: Execute

Execute only after first-hand approval in this session. Persist the displayed
packet to a temporary or ignored file and invoke it once with Bash, or pass the
whole displayed program to one Bash process. Do not execute its commands one at
a time. Because the program begins with `set -euo pipefail`, a nonzero command
terminates the packet before every later commit or tag command.

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
6. Create one release commit with subject exactly
   `Release v<approved-version>`. The approved packet may not substitute a
   conventional-commit prefix, description suffix, or any other subject.
7. **Pre-tag verification** — while no proposed tag exists, verify all non-tag
   postconditions: parse both manifests and require each to equal the approved
   version; require the newest CHANGELOG heading to name the approved version;
   require `git log -1 --format=%s` to equal exactly
   `Release v<approved-version>`; require the release commit's changed path set
   to equal exactly the three release paths; and require every source-inventory
   path to have an approved current-section mapping or an approved, structured
   Drop-list record. For every path absent at `HEAD`, normalize `disposition`
   with `.lower()` and require membership in
   `{deleted, renamed, reverted}`; require the separate concrete reason to be
   non-empty. If reason text is inspected beyond non-emptiness, inspect
   `reason.lower()`, never a case-sensitive prose substring. If any check
   fails, do not create a tag.
8. Create the approved annotated `v<version>` tag on that verified release
   commit. The tag annotation names the version and the approved highlights.
   Never create a lightweight tag and never push it.
9. **Tag-only verification** — after creation, check only that
   `git describe --tags --abbrev=0 HEAD` names the approved tag and that the
   annotated tag dereferences to the verified release commit. These checks add
   the tag value to the already-recorded manifest/CHANGELOG evidence and
   complete four-way agreement.

If validation, staging, commit, or tag creation fails, the single Bash process
must exit immediately and the runner must not invoke any suffix of the packet.
In particular, no validation or pre-tag verification failure may be followed
by tag creation. A failure after the release commit but before a verified tag
leaves a recognizable incomplete release for Preflight step 7; report that
state and stop instead of proposing another version or automatically retrying.
A tag-only verification failure reports failure without rerunning or
substituting the earlier non-tag checks.

## Phase 7: Report

Before reporting success, require the recorded pre-tag evidence from Execute
step 7: both manifest values and the newest CHANGELOG heading equal the approved
version, the release commit subject equals exactly
`Release v<approved-version>`, the commit changes exactly the three release
files, and every source-inventory spec has an approved mapping or structured
Drop-list record whose disposition/reason checks used the normalized rules
above. Then require the tag-only evidence from Execute step 9: the newest
reachable tag has the approved name and dereferences to that verified release
commit. Do not move non-tag verification after tag creation or replace recorded
pre-tag evidence with a post-tag rerun.

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
