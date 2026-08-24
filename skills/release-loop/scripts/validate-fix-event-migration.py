#!/usr/bin/env python3
"""Validate one fail-closed adoption of missing historical fix events."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
import sys
from pathlib import Path, PurePosixPath

from phase_artifact_core import ArtifactBlocked
from phase_artifact_core import guard as guard_phase_artifact_path


SCHEMA = "review-fix-event-migration/v1"
SHA256 = re.compile(r"^[0-9a-f]{64}$")
COMMIT = re.compile(r"^[0-9a-f]{40}$")
EVENT_ID = re.compile(r"^fix:([A-Za-z0-9._-]+):([1-9][0-9]*)$")
TIMESTAMP = re.compile(r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$")


class Blocked(RuntimeError):
    pass


def canonical(value):
    path = PurePosixPath(value)
    if path.is_absolute() or not path.parts or ".." in path.parts or path.as_posix() != value:
        raise Blocked("fix migration path invalid: " + value)
    return path


def physical_guard(repo, relative, allowed_root=None):
    allowed = allowed_root or ".release-loop"
    try:
        return guard_phase_artifact_path(
            repo,
            canonical(relative).as_posix(),
            canonical(allowed).as_posix(),
            allow_root=relative == allowed,
        )
    except ArtifactBlocked as exc:
        raise Blocked(str(exc)) from exc


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def progress_values(path):
    text = path.read_text(encoding="utf-8")
    if not text.startswith("---\n") or "\n---\n" not in text[4:]:
        raise Blocked("fix migration progress invalid")
    values = {}
    for line in text.split("---", 2)[1].splitlines():
        if ":" in line:
            key, value = line.split(":", 1)
            values[key.strip()] = value.strip()
    return values, text


def scalar(value):
    if value == "null":
        return None
    if value == "[]":
        return []
    return value


def parse_review_events(text):
    events = []
    current = None
    in_registry = False
    for line in text.splitlines():
        if line == "review_events:":
            in_registry = True
            continue
        if in_registry and line and not line.startswith(" "):
            in_registry = False
            current = None
        if not in_registry:
            continue
        match = re.match(r"^  - id: (\S+)\s*$", line)
        if match:
            current = {"id": match.group(1)}
            events.append(current)
            continue
        match = re.match(r"^    ([a-z0-9_]+):\s*(.*?)\s*$", line)
        if current is not None and match:
            current[match.group(1)] = scalar(match.group(2))
    return events


def journal(repo, root):
    path = physical_guard(repo, (root / ".phase-artifact-ownership.json").relative_to(repo).as_posix(), root.relative_to(repo).as_posix())
    if path.is_symlink() or not path.is_file():
        raise Blocked("fix migration ownership journal missing")
    try:
        state = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        raise Blocked("fix migration ownership journal invalid") from exc
    if state.get("schema") != "phase-artifact-ownership/v1" or not isinstance(state.get("owned"), dict) or state.get("pending") is not None:
        raise Blocked("fix migration ownership journal invalid")
    return state


def validate_owned(repo, root, relative, expected, label):
    path = physical_guard(repo, relative, root.relative_to(repo).as_posix())
    try:
        key = path.relative_to(root).as_posix()
    except ValueError as exc:
        raise Blocked(label + " outside artifact root") from exc
    if path.is_symlink() or not path.is_file() or digest(path) != expected:
        raise Blocked(label + " digest mismatch")
    if journal(repo, root)["owned"].get(key) != expected:
        raise Blocked(label + " is not publisher-owned")
    return path


def git(repo, *args):
    result = subprocess.run(("git", *args), cwd=str(repo), text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)
    if result.returncode:
        raise Blocked("fix migration Git validation failed: " + result.stderr.strip())
    return result.stdout.strip()


def default_signature_checker(repo):
    return lambda commit: git(repo, "log", "-1", "--format=%G?", commit)


def ordinal_value(event):
    raw = event.get("ordinal")
    if type(raw) is int:
        value = raw
    elif isinstance(raw, str) and re.fullmatch(r"[1-9][0-9]*", raw):
        value = int(raw)
    else:
        raise Blocked("fix migration ledger ordinal invalid")
    if value < 1:
        raise Blocked("fix migration ledger ordinal invalid")
    return value


def normalized_existing(event):
    return {
        "id": event.get("id"),
        "kind": event.get("kind"),
        "subject": event.get("subject"),
        "ordinal": ordinal_value(event),
        "state": event.get("state"),
        "reviewed_head": event.get("reviewed_head"),
        "result_path": event.get("result_path"),
        "result_sha256": event.get("result_sha256"),
        "outcome": event.get("outcome"),
        "finding_inventory": event.get("finding_inventory"),
        "source_review_event": event.get("source_review_event"),
        "re_review_of": event.get("re_review_of"),
        "source_adoption_path": event.get("source_adoption_path"),
        "source_adoption_sha256": event.get("source_adoption_sha256"),
    }


def validate_migration(repo, progress_relative, adoption_relative, signature_checker=None):
    repo = Path(repo).resolve(strict=True)
    progress_relative = canonical(progress_relative).as_posix()
    adoption_relative = canonical(adoption_relative).as_posix()
    progress = physical_guard(repo, progress_relative)
    values, text = progress_values(progress)
    root_relative = values.get("artifact_root")
    if not root_relative or progress.parent != repo / canonical(root_relative):
        raise Blocked("fix migration progress/root mismatch")
    root = physical_guard(repo, values["artifact_root"], values["artifact_root"])
    adoption_path = physical_guard(repo, adoption_relative, values["artifact_root"])
    if adoption_path.is_symlink() or not adoption_path.is_file():
        raise Blocked("fix migration adoption missing")
    adoption_sha = digest(adoption_path)
    validate_owned(repo, root, adoption_relative, adoption_sha, "fix migration adoption")
    try:
        adoption = json.loads(adoption_path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        raise Blocked("fix migration adoption invalid") from exc
    if set(adoption) != {"schema", "progress_path", "counting_started_at", "rows"} or adoption.get("schema") != SCHEMA:
        raise Blocked("fix migration adoption invalid")
    if adoption["progress_path"] != progress_relative:
        raise Blocked("fix migration adoption progress mismatch")
    counting_match = re.search(r"^  counting_started_at: (\S+)\s*$", text, re.MULTILINE)
    if not counting_match or adoption["counting_started_at"] != counting_match.group(1) or not TIMESTAMP.fullmatch(adoption["counting_started_at"]):
        raise Blocked("fix migration counting start mismatch")
    rows = adoption["rows"]
    if not isinstance(rows, list) or not rows:
        raise Blocked("fix migration rows missing")
    required = {
        "id", "subject", "ordinal", "source_review_event", "reviewed_head",
        "fix_commit", "fixer_report_path", "fixer_report_sha256",
    }
    identities = [(row.get("id"), row.get("subject"), row.get("ordinal")) for row in rows if isinstance(row, dict)]
    if len(identities) != len(rows) or len(set(identities)) != len(rows):
        raise Blocked("fix migration duplicate row")
    events = parse_review_events(text)
    by_id = {event.get("id"): event for event in events}
    if len(by_id) != len(events):
        raise Blocked("fix migration duplicate ledger event")
    checker = signature_checker or default_signature_checker(repo)
    accepted = []
    result_path_owners = {}
    for existing_event in events:
        existing_path = existing_event.get("result_path")
        existing_id = existing_event.get("id")
        if isinstance(existing_path, str):
            owner = result_path_owners.get(existing_path)
            if owner is not None and owner != existing_id:
                raise Blocked("fix migration duplicate result path")
            result_path_owners[existing_path] = existing_id
    for row in rows:
        if set(row) != required:
            raise Blocked("fix migration row invalid")
        row_ordinal = row["ordinal"]
        if type(row_ordinal) is not int or row_ordinal < 1:
            raise Blocked("fix migration row ordinal invalid")
        match = EVENT_ID.fullmatch(str(row["id"]))
        if not match or row["subject"] != match.group(1) or row_ordinal != int(match.group(2)):
            raise Blocked("fix migration row identity mismatch")
        source = by_id.get(row["source_review_event"])
        if source is None or source.get("state") != "complete":
            raise Blocked("fix migration source review missing")
        if source.get("kind") not in {"unit", "final", "standalone"}:
            raise Blocked("fix migration source review is chained")
        if source.get("subject") != row["subject"] or source.get("reviewed_head") != row["reviewed_head"]:
            raise Blocked("fix migration source review mismatch")
        reviewed_head = row["reviewed_head"]
        if not isinstance(reviewed_head, str) or not COMMIT.fullmatch(reviewed_head):
            raise Blocked("fix migration full reviewed head required")
        source_sha = source.get("result_sha256")
        source_path = source.get("result_path")
        if not isinstance(source_sha, str) or not SHA256.fullmatch(source_sha) or not isinstance(source_path, str):
            raise Blocked("fix migration source review result invalid")
        validate_owned(repo, root, source_path, source_sha, "fix migration source review result")
        commit = row["fix_commit"]
        if not isinstance(commit, str) or not COMMIT.fullmatch(commit):
            raise Blocked("fix migration full fix commit required")
        if git(repo, "rev-parse", commit + "^{commit}") != commit:
            raise Blocked("fix migration full fix commit mismatch")
        if checker(commit) != "G":
            raise Blocked("fix migration signed fix commit required")
        ancestor = subprocess.run(("git", "merge-base", "--is-ancestor", reviewed_head, commit), cwd=str(repo), check=False)
        if ancestor.returncode != 0:
            raise Blocked("fix migration commit/source mismatch")
        report_path = row["fixer_report_path"]
        if not isinstance(report_path, str):
            raise Blocked("fix migration fixer report path invalid")
        if report_path in {adoption_relative, source_path}:
            raise Blocked("fix migration fixer report path not round-specific")
        owner = result_path_owners.get(report_path)
        if owner is not None and owner != row["id"]:
            raise Blocked("fix migration duplicate fixer report path")
        report_sha = row["fixer_report_sha256"]
        if not isinstance(report_sha, str) or not SHA256.fullmatch(report_sha):
            raise Blocked("fix migration fixer report digest invalid")
        validate_owned(repo, root, report_path, report_sha, "fix migration fixer report")
        result_path_owners[report_path] = row["id"]
        event = {
            "id": row["id"],
            "kind": "fix",
            "subject": row["subject"],
            "ordinal": row["ordinal"],
            "state": "complete",
            "reviewed_head": row["reviewed_head"],
            "result_path": report_path,
            "result_sha256": report_sha,
            "outcome": "clean",
            "finding_inventory": [],
            "source_review_event": row["source_review_event"],
            "re_review_of": None,
            "source_adoption_path": adoption_relative,
            "source_adoption_sha256": adoption_sha,
        }
        existing = by_id.get(row["id"])
        if existing is not None and normalized_existing(existing) != event:
            raise Blocked("fix migration replay conflict: " + row["id"])
        accepted.append(event)
    by_subject = {}
    for event in events:
        if event.get("kind") == "fix":
            by_subject.setdefault(event.get("subject"), []).append(ordinal_value(event))
    for event in accepted:
        if event["id"] not in by_id:
            by_subject.setdefault(event["subject"], []).append(event["ordinal"])
    for subject, ordinals in by_subject.items():
        if sorted(ordinals) != list(range(1, len(ordinals) + 1)):
            raise Blocked("fix migration ordinal gap: " + str(subject))
    existing_complete = sum(event.get("kind") == "fix" and event.get("state") == "complete" for event in events)
    new_count = sum(event["id"] not in by_id for event in accepted)
    return {
        "adoption_path": adoption_relative,
        "adoption_sha256": adoption_sha,
        "events": accepted,
        "review_counts": {"completeness": "partial", "counting_started_at": adoption["counting_started_at"], "fix_rounds": existing_complete + new_count},
        "state": "reused" if new_count == 0 else "new",
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", required=True)
    parser.add_argument("--progress-path", required=True)
    parser.add_argument("--adoption-path", required=True)
    args = parser.parse_args()
    try:
        payload = validate_migration(args.repo, args.progress_path, args.adoption_path)
    except (Blocked, OSError, UnicodeError, ValueError) as exc:
        print(str(exc), file=sys.stderr)
        return 1
    print(json.dumps(payload, sort_keys=True, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
