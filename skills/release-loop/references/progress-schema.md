# progress.md Schema

The selected progress path is the loop's single durable state record (`enforces: P8`). New loops use `.release-loop/runs/<feature_slug>/progress.md`. A valid legacy run can retain `.release-loop/progress.md`. The file contains YAML frontmatter and a human-readable Log section. Consumers reject unknown `schema:` versions.

```markdown
---
schema: release-loop/v1
feature: <feature_slug matching ^[a-z0-9]+(?:-[a-z0-9]+)*$ and not equal to resume>
artifact_root: .release-loop/runs/<feature_slug>
phase: design | plan | implement | review | ship | retro | done | blocked
phase_status: in-progress | waiting-user | blocked | complete
started: <ISO-8601 timestamp>
updated: <ISO-8601 timestamp>          # touched on every write
branch: <current checkout branch; feature branch before handoff, value of base_branch after verified base handoff>
base_branch: <detected base>
flags: [--auto, --skip-design]          # as given, empty list if none

# Artifact pointers (set as each phase produces them)
spec: docs/specs/YYYY-MM-DD-<topic>-design.md
plan: docs/plans/YYYY-MM-DD-NNN-<type>-<name>-plan.md
retro: docs/retros/YYYY-MM-DD-<context>-retro.md

# Approval evidence (USER gates; --skip-design relies on the spec's own
# status: approved plus this record)
design_approved: {by: user, at: <timestamp>}
ship_approved: {by: user | auto, at: <timestamp>, conditions: "CI green, no open P0"}

# Final-action record (preparation evidence, never approval — see Rules)
final_action:
  kind: merge-to-base                   # closed vocabulary; sole value
  status: predicted                     # predicted | determined | executed
  command: null                         # exact command string once determined; no secrets — ambient auth only
  marker: null                          # optional; preparation-not-approval text when present
  updated: <ISO-8601 timestamp>

# Phase counters
current_unit: U3                        # implement phase
ci_attempts: 0                          # cap 3
review_rounds: 0                        # reviewing re-review cap 3
feedback_rounds: 0                      # shipping comment-round cap 4
comments_fixed: 0
comments_deferred: 0
pr: <number | null>
merged: false
blocked_reason: null                    # set when phase_status: blocked
---

## Log

- <timestamp> design: spec committed (<sha>), user approved
- <timestamp> implement: U1 DONE (<sha>), task review clean
- <timestamp> implement: U2 DONE_WITH_CONCERNS — <one line>, resolved by <sha>
- <timestamp> ship: verification gate — `pytest -q` → 124 passed, 0 failed (fresh)
- <timestamp> retro: archive-destination: .release-loop/archive/YYYY-MM-DD-<feature_slug>
```

## Executable integrity check

The check below is the executable oracle for run discovery and local artifact transitions.
The fixture suite extracts this exact block.

<!-- run-artifact-integrity-check:begin -->
```python
import json
import re
import shutil
import subprocess
from pathlib import Path, PurePosixPath

SCHEMA_VERSION = "release-loop/v1"
FEATURE_PATTERN = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")


class Blocked(RuntimeError):
    pass


def reject(kind, detail):
    raise Blocked(f"{kind}: {detail}")


def repo_relative(value):
    path = PurePosixPath(value)
    if path.is_absolute() or not path.parts or ".." in path.parts:
        reject("path boundary", value)
    return path


def is_within(path, root):
    try:
        path.relative_to(root)
    except ValueError:
        return False
    return True


def guard(repo, relative, allowed_root, allow_root=False):
    repo = Path(repo).resolve(strict=True)
    rel = repo_relative(relative)
    allowed_rel = repo_relative(allowed_root)
    if rel != allowed_rel and not is_within(Path(*rel.parts), Path(*allowed_rel.parts)):
        reject("path boundary", f"{relative} outside {allowed_root}")
    if rel == allowed_rel and not allow_root:
        reject("path boundary", f"{relative} must name a child of {allowed_root}")
    cursor = repo
    for part in rel.parts:
        cursor = cursor / part
        if cursor.is_symlink():
            reject("path boundary", f"symlink component {cursor.relative_to(repo).as_posix()}")
        if cursor.exists() and not is_within(cursor.resolve(), repo):
            reject("path boundary", f"outside repository {relative}")
    parent = cursor if cursor.exists() and cursor.is_dir() else cursor.parent
    if not is_within(parent.resolve(strict=False), repo):
        reject("path boundary", f"outside repository {relative}")
    return cursor


def frontmatter(path):
    if path.is_symlink():
        reject("path boundary", f"symlink progress {path}")
    if not path.is_file():
        reject("invalid progress", str(path))
    text = path.read_text(encoding="utf-8")
    if not text.startswith("---\n") or "\n---\n" not in text[4:]:
        reject("invalid progress", str(path))
    block = text.split("---", 2)[1]
    values = {}
    for line in block.splitlines():
        if ":" not in line:
            continue
        key, value = line.split(":", 1)
        values[key.strip()] = value.strip()
    schema = values.get("schema", "")
    if schema != SCHEMA_VERSION:
        reject("unknown schema", schema or "missing")
    feature = values.get("feature", "")
    if not FEATURE_PATTERN.fullmatch(feature) or feature == "resume":
        reject("invalid progress", f"feature {feature!r}")
    return values, text


def validate_progress(repo, relative, expected_feature=None):
    rel = repo_relative(relative)
    if rel == PurePosixPath(".release-loop/progress.md"):
        path = guard(repo, relative, ".release-loop", allow_root=False)
        expected_root = ".release-loop"
    elif len(rel.parts) == 4 and rel.parts[:2] == (".release-loop", "runs") and rel.name == "progress.md":
        scope = PurePosixPath(*rel.parts[:-1]).as_posix()
        path = guard(repo, relative, scope, allow_root=False)
        expected_root = scope
    else:
        reject("path boundary", f"invalid progress path {relative}")
    values, text = frontmatter(path)
    if values.get("artifact_root") != expected_root:
        reject("path boundary", f"artifact_root {values.get('artifact_root', '')}")
    if expected_feature is not None and values.get("feature") != expected_feature:
        reject("invalid progress", f"feature does not match {expected_feature}")
    return path, values, text


def git_tracked(repo, relative):
    result = subprocess.run(
        ["git", "ls-files", "--", relative],
        cwd=repo,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if result.returncode != 0:
        reject("artifact scope collision", "git index unavailable")
    return [line for line in result.stdout.splitlines() if line]


def filesystem_entries(repo, scope):
    if not scope.exists():
        return []
    entries = []
    for child in scope.rglob("*"):
        entries.append(child.relative_to(repo).as_posix())
    return entries


def progress_text(feature, artifact_root):
    return (
        "---\n"
        f"schema: {SCHEMA_VERSION}\n"
        f"feature: {feature}\n"
        f"artifact_root: {artifact_root}\n"
        "phase: design\n"
        "phase_status: in-progress\n"
        "---\n\n"
        "## Log\n"
    )


def initialize(repo, feature, selected=None):
    repo = Path(repo).resolve(strict=True)
    if not FEATURE_PATTERN.fullmatch(feature) or feature == "resume":
        reject("invalid feature", feature)
    expected = f".release-loop/runs/{feature}/progress.md"
    relative = selected or expected
    repo_relative(relative)
    if relative != expected:
        reject("path boundary", f"progress path does not match run identity: {relative}")
    scope_rel = f".release-loop/runs/{feature}"
    target = guard(repo, relative, scope_rel, allow_root=False)
    scope = target.parent
    fs_entries = filesystem_entries(repo, scope)
    tracked_entries = git_tracked(repo, scope_rel)
    collisions = sorted(set(fs_entries + tracked_entries))
    if target.is_file() and not target.is_symlink() and collisions == [relative] and not tracked_entries:
        validate_progress(repo, relative, feature)
        return target
    if collisions:
        reject("artifact scope collision", ", ".join(collisions))
    scope.mkdir(parents=True, exist_ok=True)
    target.write_text(progress_text(feature, scope_rel), encoding="utf-8")
    validate_progress(repo, relative, feature)
    return target


def discover(repo, exact=None):
    repo = Path(repo).resolve(strict=True)
    records = []
    legacy = repo / ".release-loop/progress.md"
    if legacy.is_symlink():
        reject("path boundary", ".release-loop/progress.md")
    if legacy.exists():
        records.append(validate_progress(repo, ".release-loop/progress.md")[0])
    runs = repo / ".release-loop/runs"
    if runs.is_symlink():
        reject("path boundary", ".release-loop/runs")
    if runs.is_dir():
        for scope in sorted(runs.iterdir()):
            if scope.is_symlink():
                reject("path boundary", scope.relative_to(repo).as_posix())
            candidate = scope / "progress.md"
            if candidate.is_symlink():
                reject("path boundary", candidate.relative_to(repo).as_posix())
            if candidate.exists():
                relative = candidate.relative_to(repo).as_posix()
                records.append(validate_progress(repo, relative)[0])
    if exact is not None:
        selected = validate_progress(repo, exact)[0]
        if selected not in records:
            reject("invalid progress", exact)
        return "resume", selected
    if len(records) == 1:
        return "resume", records[0]
    if len(records) > 1:
        reject("multiple valid live records require exact progress path", ", ".join(path.relative_to(repo).as_posix() for path in records))
    return "new", None


def archive_marker(text):
    matches = re.findall(r"^- .*archive-destination: (\S+)\s*$", text, re.MULTILINE)
    if len(matches) > 1:
        reject("archive destination conflict", "multiple markers")
    return matches[0] if matches else None


def persist_archive_marker(path, text, destination):
    marker = archive_marker(text)
    if marker is not None and marker != destination:
        reject("archive destination conflict", f"stored={marker} requested={destination}")
    if marker is None:
        separator = "" if text.endswith("\n") else "\n"
        text = f"{text}{separator}- archive-destination: {destination}\n"
        path.write_text(text, encoding="utf-8")
    return text


def move_one(source, destination):
    target = destination / source.name
    if target.exists() or target.is_symlink():
        reject("archive destination conflict", target.as_posix())
    shutil.move(str(source), str(target))


def archive(repo, progress_path, destination=None, fail_after_first=False):
    repo = Path(repo).resolve(strict=True)
    progress_file, values, text = validate_progress(repo, progress_path)
    stored = archive_marker(text)
    selected = stored if destination is None else destination
    if selected is None:
        reject("archive destination conflict", "missing persisted destination")
    if stored is not None and destination is not None and stored != destination:
        reject("archive destination conflict", f"stored={stored} requested={destination}")
    destination_path = guard(repo, selected, ".release-loop/archive", allow_root=False)
    source_rel = values["artifact_root"]
    if source_rel == ".release-loop":
        guard(repo, progress_path, ".release-loop", allow_root=False)
        source = repo / ".release-loop"
        children = []
        for name in ("briefs", "reports", "reviews", "evidence"):
            child = source / name
            if child.exists() or child.is_symlink():
                guard(repo, child.relative_to(repo).as_posix(), ".release-loop", allow_root=False)
                children.append(child)
        for child in sorted(source.glob("progress.md.corrupt-*")):
            guard(repo, child.relative_to(repo).as_posix(), ".release-loop", allow_root=False)
            children.append(child)
    else:
        source = guard(repo, source_rel, source_rel, allow_root=True)
        children = [child for child in sorted(source.iterdir()) if child.name != "progress.md"]
        for child in children:
            guard(repo, child.relative_to(repo).as_posix(), source_rel, allow_root=False)
    persist_archive_marker(progress_file, text, selected)
    destination_path.mkdir(parents=True, exist_ok=True)
    order = []
    for child in children:
        move_one(child, destination_path)
        order.append(child.name)
        if fail_after_first:
            reject("injected archive interruption", child.name)
    move_one(progress_file, destination_path)
    order.append("progress.md")
    if source_rel != ".release-loop":
        source.rmdir()
    return order


def tree_manifest(root):
    manifest = {}
    for path in sorted(root.rglob("*")):
        if path.is_symlink():
            reject("path boundary", f"symlink component {path}")
        relative = path.relative_to(root).as_posix()
        manifest[relative] = None if path.is_dir() else path.read_bytes()
    return manifest


def copy_missing(source, target):
    source_manifest = tree_manifest(source)
    target_manifest = tree_manifest(target) if target.exists() else {}
    extras = sorted(set(target_manifest) - set(source_manifest))
    mismatches = sorted(key for key in set(target_manifest) & set(source_manifest) if target_manifest[key] != source_manifest[key])
    if extras or mismatches:
        reject("handoff target mismatch", ", ".join(extras + mismatches))
    target.mkdir(parents=True, exist_ok=True)
    for relative, data in source_manifest.items():
        destination = target / relative
        if data is None:
            destination.mkdir(parents=True, exist_ok=True)
        elif relative not in target_manifest:
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_bytes(data)


def handoff(repo, base_repo, progress_path, marker_path=None, fail_after_marker=False):
    repo = Path(repo).resolve(strict=True)
    base_repo = Path(base_repo).resolve(strict=True)
    progress_file, values, _ = validate_progress(repo, progress_path)
    artifact_root = values["artifact_root"]
    if artifact_root == ".release-loop":
        reject("path boundary", "legacy handoff requires an explicit legacy destination contract")
    source = guard(repo, artifact_root, artifact_root, allow_root=True)
    run_id = values["feature"]
    marker_relative = marker_path or f".release-loop/.handoff/{run_id}.json"
    marker = guard(base_repo, marker_relative, ".release-loop/.handoff", allow_root=False)
    destination = guard(base_repo, artifact_root, f".release-loop/runs/{run_id}", allow_root=True)
    expected = {
        "schema": "release-loop-handoff/v1",
        "feature": run_id,
        "progress_path": progress_file.relative_to(repo).as_posix(),
        "artifact_root": artifact_root,
        "source_worktree": str(repo),
        "base_owner": str(base_repo),
        "destination": artifact_root,
    }
    if marker.exists():
        observed = json.loads(marker.read_text(encoding="utf-8"))
        if any(observed.get(key) != value for key, value in expected.items()):
            reject("handoff owner mismatch", marker_relative)
    else:
        marker.parent.mkdir(parents=True, exist_ok=True)
        marker.write_text(json.dumps({**expected, "status": "incomplete"}, sort_keys=True) + "\n", encoding="utf-8")
    if fail_after_marker:
        reject("injected handoff interruption", marker_relative)
    copy_missing(source, destination)
    if tree_manifest(source) != tree_manifest(destination):
        reject("handoff target mismatch", artifact_root)
    state, selected = discover(base_repo, f"{artifact_root}/progress.md")
    if state != "resume" or selected != destination / "progress.md":
        reject("handoff resume verification", artifact_root)
    marker.write_text(json.dumps({**expected, "status": "complete"}, sort_keys=True) + "\n", encoding="utf-8")
    return {"cleanup_permitted": True, "marker": marker, "progress": selected}
```
<!-- run-artifact-integrity-check:end -->

## Rules

- `artifact_root` equals the exact repo-relative directory that contains the selected progress record. New scoped records require this field. A resumed legacy record can add `artifact_root: .release-loop`.
- The four closed physical-root families are scoped active state, legacy active state, terminal archives, and transition handoff.
- Scoped active state permits only the selected `.release-loop/runs/<run_id>` root. Legacy active state permits the root progress file and its four known sibling directories.
- Terminal archive state permits only the collision-resolved `.release-loop/archive/<destination>` root. Handoff state permits only `.release-loop/.handoff`.
- Reject every symlink in each existing source or destination component. Also reject absolute paths, parent escapes, and physical parents outside the applicable closed root.
- Before the first scope write, inspect filesystem entries and `git ls-files -- <artifact_root>`. A nonempty scope requires one matching valid progress record. Any other ignored or tracked entry is an artifact-scope collision.
- Discovery considers the valid legacy record and all valid scoped records. One record selects `resume`. Zero records select `new`. Multiple records select `blocked` until the caller supplies one exact repo-relative progress path.
- Write at the moment of the event, not batched (`enforces: P3` — the record is the evidence).
- **Gate transitions record their evidence inline**: the proving command, its observed result, and the timestamp (see the `ship: verification gate` log line above). A transition line without command + result is a claim, not a record — resumed and headless runs inherit evidence only through these lines. `enforces: P3, P8`
- Timestamps are ISO-8601 with timezone, **fetched fresh via command (`date -u +%Y-%m-%dT%H:%M:%SZ`) at each write — never estimated or interpolated** (pilot-proven: estimated timestamps produced a non-monotonic log).
- **Status flips are atomic with their evidence**: changing `phase`/`phase_status` and writing the explaining Log line (plus `blocked_reason` when the status is blocked) happen in the same edit — a bare `blocked` with `blocked_reason: null` is a schema violation, not a placeholder.
- Corrupt/unparsable file on resume → rebuild frontmatter from git evidence (branch, committed artifacts, PR state via `gh pr view`), keep the old file as `progress.md.corrupt-<timestamp>`, and note the rebuild in the Log. A stored `feature:` that fails the `feature_slug` invariant is the same class of corruption.
- `.release-loop/` contains local working state. Gitignore it by default. Durable spec, plan, and Retro documents remain committed. Corrupt backups stay with their selected artifact root and move into its terminal archive.
- `final_action` is additive and optional on `release-loop/v1`: absence stays valid — consumers reject unknown `schema:` versions, never unknown fields.
- `final_action.status` has exactly three transitions: `predicted → determined` in the same edit as its Log line, when the exact command becomes knowable; `determined → predicted` on invalidation (PR closed, new commits on the branch) with the reason logged in the same edit; `determined → executed` in the same edit as the evidence Log line and `merged: true` — the two fields never disagree across a write.
- The `feature:` field stores one validated `feature_slug`. Consumers reject empty, uppercase, separator, dot-segment, or reserved `resume` values. They never silently normalize a stored value.
- The canonical destination evidence is one Log line with the exact marker `archive-destination: <path>`. For interrupted reruns, that logged path is authoritative and must be reused without recalculating a collision suffix.
- A completed record's terminal home is `.release-loop/archive/<YYYY-MM-DD>-<feature_slug>/`. The canonical archive Log line must name that containing directory. One qualifying record reports completion. Zero records trigger reconstruction. Multiple records block as ambiguous.
- Move all remaining children from the selected artifact root before the selected progress record. Move `progress.md` last as the commit point. An interrupted archive reuses its logged destination and moves only remaining children.
- **The `final_action` record is preparation evidence, never approval**: possession of the command is not authorization to run it. Approval evidence lives only in `ship_approved`. `enforces: P7`
