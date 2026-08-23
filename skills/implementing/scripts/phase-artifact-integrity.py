#!/usr/bin/env python3
"""Prepare standalone implementing state and publish owned phase artifacts."""

import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
import re
import subprocess
import sys
from pathlib import Path, PurePosixPath

FEATURE_PATTERN = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")
JOURNAL_NAME = ".phase-artifact-ownership.json"


class Blocked(RuntimeError):
    pass


class Parser(argparse.ArgumentParser):
    def error(self, message):
        raise Blocked("invalid arguments: " + message)


def reject(kind, detail):
    raise Blocked(kind + ": " + detail)


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
    rel = repo_relative(relative)
    allowed = repo_relative(allowed_root)
    if rel != allowed and not is_within(Path(*rel.parts), Path(*allowed.parts)):
        reject("path boundary", relative + " outside " + allowed_root)
    if rel == allowed and not allow_root:
        reject("path boundary", relative + " must name a child")
    cursor = repo
    for part in rel.parts:
        cursor = cursor / part
        if cursor.is_symlink():
            reject("path boundary", "symlink component " + cursor.relative_to(repo).as_posix())
        if cursor.exists() and not is_within(cursor.resolve(), repo):
            reject("path boundary", "outside repository " + relative)
    if not is_within(cursor.parent.resolve(strict=False), repo):
        reject("path boundary", "outside repository " + relative)
    return cursor


def git_tracked(repo, relative):
    result = subprocess.run(
        ("git", "ls-files", "--", relative),
        cwd=str(repo),
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    if result.returncode:
        reject("artifact scope collision", "git index unavailable")
    return [line for line in result.stdout.splitlines() if line]


def fields(path, kind):
    if path.is_symlink() or not path.is_file():
        reject("invalid " + kind, str(path))
    text = path.read_text(encoding="utf-8")
    if not text.startswith("---\n") or "\n---\n" not in text[4:]:
        reject("invalid " + kind, str(path))
    values = {}
    for line in text.split("---", 2)[1].splitlines():
        if ":" in line:
            key, value = line.split(":", 1)
            values[key.strip()] = value.strip()
    return values


def repository_file(repo, value, kind):
    repo_lexical = repo.absolute()
    candidate = Path(value)
    if candidate.is_absolute():
        try:
            relative = candidate.relative_to(repo_lexical).as_posix()
        except ValueError:
            reject("invalid " + kind + " path", value)
    else:
        relative = candidate.as_posix()
    rel = repo_relative(relative)
    cursor = repo_lexical
    for part in rel.parts:
        cursor = cursor / part
        if cursor.is_symlink():
            reject("invalid " + kind + " path", "symlink component " + cursor.relative_to(repo_lexical).as_posix())
    physical = repo_lexical.resolve(strict=True) / rel
    if not physical.is_file():
        reject("invalid " + kind + " path", value)
    return physical, rel.as_posix()


def validate_progress(repo, relative):
    rel = repo_relative(relative)
    if len(rel.parts) != 4 or rel.parts[:2] != (".release-loop", "runs") or rel.name != "progress.md":
        reject("path boundary", "invalid progress path " + relative)
    root = PurePosixPath(*rel.parts[:-1]).as_posix()
    path = guard(repo, relative, root)
    values = fields(path, "progress")
    if values.get("schema") != "release-loop/v1":
        reject("unknown schema", values.get("schema", "missing"))
    if values.get("artifact_root") != root:
        reject("path boundary", "artifact_root " + values.get("artifact_root", ""))
    if values.get("feature") != rel.parts[2]:
        reject("invalid progress", "feature does not match scope")
    return path, values


def initialize(repo, plan_value):
    plan, plan_relative = repository_file(repo, plan_value, "plan")
    repo = repo.resolve(strict=True)
    values = fields(plan, "plan")
    if values.get("schema") != "plan/v1" or values.get("status") != "approved":
        reject("invalid plan", "approved plan/v1 required")
    stem = plan.stem
    if not FEATURE_PATTERN.fullmatch(stem) or stem == "resume":
        reject("invalid plan filename stem", stem)
    root_rel = ".release-loop/runs/" + stem
    progress_rel = root_rel + "/progress.md"
    progress = guard(repo, progress_rel, root_rel)
    tracked = git_tracked(repo, root_rel)
    if progress.exists():
        validate_progress(repo, progress_rel)
        return progress, "resume"
    entries = [] if not progress.parent.exists() else [p.relative_to(repo).as_posix() for p in progress.parent.rglob("*")]
    if entries or tracked:
        reject("artifact scope collision", ", ".join(sorted(set(entries + tracked))))
    progress.parent.mkdir(parents=True, exist_ok=True)
    temporary = progress.with_name("progress.md.tmp")
    now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    branch_result = subprocess.run(("git", "symbolic-ref", "--short", "HEAD"), cwd=str(repo), text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if branch_result.returncode or not branch_result.stdout.strip():
        reject("invalid repository", "detached HEAD")
    branch = branch_result.stdout.strip()
    base_result = subprocess.run(("git", "symbolic-ref", "--short", "refs/remotes/origin/HEAD"), cwd=str(repo), text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    base_text = base_result.stdout.strip()
    base_branch = base_text[len("origin/"):] if base_result.returncode == 0 and base_text.startswith("origin/") else "main"
    body = (
        "---\n"
        "schema: release-loop/v1\n"
        "feature: " + stem + "\n"
        "artifact_root: " + root_rel + "\n"
        "phase: implement\n"
        "phase_status: in-progress\n"
        "started: " + now + "\n"
        "updated: " + now + "\n"
        "branch: " + branch + "\n"
        "base_branch: " + base_branch + "\n"
        "flags: []\n"
        "spec: null\n"
        "plan: " + plan_relative + "\n"
        "retro: null\n"
        "design_approved: null\n"
        "ship_approved: null\n"
        "final_action:\n"
        "  kind: merge-to-base\n"
        "  status: predicted\n"
        "  command: null\n"
        "  marker: null\n"
        "  updated: " + now + "\n"
        "current_unit: null\n"
        "ci_attempts: 0\n"
        "review_rounds: 0\n"
        "feedback_rounds: 0\n"
        "comments_fixed: 0\n"
        "comments_deferred: 0\n"
        "pr: null\n"
        "merged: false\n"
        "blocked_reason: null\n"
        "---\n\n## Log\n\n- standalone initialize: complete record published\n"
    )
    temporary.write_text(body, encoding="utf-8")
    os.replace(str(temporary), str(progress))
    return progress, "new"


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def journal(repo, root):
    path = guard(repo, root + "/" + JOURNAL_NAME, root)
    if git_tracked(repo, path.relative_to(repo).as_posix()):
        reject("artifact ownership", "tracked journal")
    if not path.exists():
        return path, {}
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, ValueError):
        reject("artifact ownership", "invalid journal")
    if not isinstance(value, dict):
        reject("artifact ownership", "invalid journal")
    return path, value


def publish(repo, progress_relative, source_relative, target_relative):
    repo = repo.resolve(strict=True)
    _, values = validate_progress(repo, progress_relative)
    root = values["artifact_root"]
    source = guard(repo, source_relative, root)
    target = guard(repo, target_relative, root)
    temporary_root = guard(repo, root + "/.tmp", root)
    if not is_within(source, temporary_root) or source == temporary_root:
        reject("artifact source", "outside transition temp root " + source_relative)
    if is_within(target, temporary_root):
        reject("artifact target", "inside transition temp root " + target_relative)
    if not source.is_file() or source.is_symlink():
        reject("artifact source", source_relative)
    if git_tracked(repo, source_relative):
        reject("artifact source", "tracked source " + source_relative)
    if git_tracked(repo, target_relative):
        reject("artifact target collision", target_relative)
    sha = digest(source)
    journal_path, owned = journal(repo, root)
    key = target.relative_to(repo / root).as_posix()
    if target.exists() or target.is_symlink():
        if target.is_file() and not target.is_symlink() and owned.get(key) == sha and digest(target) == sha:
            source.unlink()
            return target, sha, "reused"
        reject("artifact ownership", target_relative)
    if key in owned:
        reject("artifact ownership", "missing owned final " + target_relative)
    target.parent.mkdir(parents=True, exist_ok=True)
    os.replace(str(source), str(target))
    owned[key] = sha
    temporary = journal_path.with_name(journal_path.name + ".tmp")
    if temporary.exists() or temporary.is_symlink():
        reject("artifact ownership", "temporary journal collision")
    temporary.write_text(json.dumps(owned, sort_keys=True, separators=(",", ":")) + "\n", encoding="utf-8")
    os.replace(str(temporary), str(journal_path))
    return target, sha, "published"


def parser():
    root = Parser(description=__doc__)
    commands = root.add_subparsers(dest="command", required=True)
    init = commands.add_parser("initialize")
    init.add_argument("--repo", required=True)
    init.add_argument("--plan", required=True)
    pub = commands.add_parser("publish")
    pub.add_argument("--repo", required=True)
    pub.add_argument("--progress-path", required=True)
    pub.add_argument("--source", required=True)
    pub.add_argument("--target", required=True)
    return root


def main():
    try:
        args = parser().parse_args()
        repo = Path(args.repo).absolute()
        physical_repo = repo.resolve(strict=True)
        if args.command == "initialize":
            progress, state = initialize(repo, args.plan)
            payload = {"artifact_root": progress.parent.relative_to(physical_repo).as_posix(), "progress_path": progress.relative_to(physical_repo).as_posix(), "state": state}
        else:
            target, sha, state = publish(repo, args.progress_path, args.source, args.target)
            payload = {"progress_path": args.progress_path, "sha256": sha, "state": state, "target": target.relative_to(physical_repo).as_posix()}
    except (Blocked, OSError, UnicodeError) as exc:
        print(str(exc), file=sys.stderr)
        return 1
    print(json.dumps(payload, sort_keys=True, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
