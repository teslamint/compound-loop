#!/usr/bin/env bash
# Standalone contract harness for implementing, release-loop, and retrospective.
# The fixture copies the real skill files, deliberately omits skills/planning/, and
# evaluates the machine-readable contract blocks against real frontmatter/history
# and coverage fixtures.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS_COUNT=0
FAIL_COUNT=0

pass() {
  echo "  PASS: $1"
  PASS_COUNT=$((PASS_COUNT + 1))
}

fail() {
  echo "  FAIL: $1"
  FAIL_COUNT=$((FAIL_COUNT + 1))
}

copy_consumers() {
  local d
  d="$(mktemp -d)" || return 1
  mkdir -p "$d/skills/implementing" "$d/skills/reviewing" "$d/skills/release-loop" "$d/skills/retrospective"
  cp "$ROOT/skills/implementing/SKILL.md" "$d/skills/implementing/SKILL.md"
  cp "$ROOT/skills/reviewing/SKILL.md" "$d/skills/reviewing/SKILL.md"
  cp "$ROOT/skills/release-loop/SKILL.md" "$d/skills/release-loop/SKILL.md"
  cp "$ROOT/skills/retrospective/SKILL.md" "$d/skills/retrospective/SKILL.md"
  printf '%s\n' "$d"
}

record_results() {
  local result_file="$1" state consumer name detail
  while IFS='|' read -r state consumer name detail; do
    [ -z "$state" ] && continue
    case "$state" in
      PASS) pass "$consumer/$name${detail:+ — $detail}" ;;
      FAIL) fail "$consumer/$name${detail:+ — $detail}" ;;
      *) fail "harness/unknown-result — $state" ;;
    esac
  done < "$result_file"
}

run_engine() {
  local mode="$1" consumer="$2" skill_file="$3" fixture_root="$4"
  local result_file rc
  result_file="$(mktemp)"
  python3 - "$mode" "$consumer" "$skill_file" "$fixture_root" > "$result_file" <<'PY'
from __future__ import annotations

import hashlib
import json
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

mode, consumer, skill_file, fixture_root = sys.argv[1:]
skill_path = Path(skill_file)
root = Path(fixture_root)
adoption_policy: dict | None = None
INTERACTIVE_DEEPENING_MARKER = "interactive-deepening=first-hand-explicit"
failures = 0


def emit(state: str, name: str, detail: str = "") -> None:
    global failures
    if state == "FAIL":
        failures += 1
    print("|".join((state, consumer, name, detail)))


def parse_contract(path: Path) -> tuple[list[dict], str | None]:
    global adoption_policy
    text = path.read_text(encoding="utf-8")
    marker = f"<!-- plan-consumer-contract: {consumer}/v1 -->"
    end_marker = "<!-- end-plan-consumer-contract -->"
    if marker not in text or end_marker not in text:
        return [], "missing operative contract block"
    block = text.split(marker, 1)[1].split(end_marker, 1)[0]
    rows: list[dict] = []
    in_fence = False
    for line in block.splitlines():
        stripped = line.strip()
        if stripped.startswith(("```", "~~~")):
            in_fence = not in_fence
            continue
        if in_fence and stripped.startswith("{"):
            try:
                row = json.loads(stripped)
            except json.JSONDecodeError as exc:
                return [], f"invalid JSON contract row: {exc}"
            if row.get("decision") == "adoption-policy":
                adoption_policy = row.get("policy")
                continue
            if not all(key in row for key in ("decision", "fixture", "expected", "diagnostic")):
                return [], "contract row missing decision/fixture/expected/diagnostic"
            rows.append(row)
    if mode == "adoption" and not isinstance(adoption_policy, dict):
        return [], "missing authoritative adoption policy"
    if not rows:
        return [], "operative contract block has no rows"
    return rows, None
def policy_violation(policy: dict | None) -> str | None:
    if not isinstance(policy, dict):
        return "missing"
    required = (
        "approval", "baseline", "plan_path", "old_seal", "new_seal", "reproduction_command"
    )
    if policy.get("required_evidence") != list(required):
        return "required-evidence"
    if policy.get("baseline_current_body") != "equal":
        return "baseline-current-equality"
    commit = policy.get("migration_commit")
    if not isinstance(commit, dict):
        return "migration-commit"
    if commit.get("path") != "repo-relative-evidence":
        return "migration-commit-path"
    if commit.get("diff") != "seal-only":
        return "migration-commit-diff"
    if commit.get("message_fields") != [
        "baseline", "plan", "old-seal", "new-seal", "reproduction-command", "approval"
    ]:
        return "migration-commit-message-tuple"
    if commit.get("command") != "exact":
        return "migration-commit-command"
    if commit.get("approval") != "first-hand-explicit":
        return "migration-commit-approval"
    if policy.get("later_reseal") != "reject-unless-interactive-deepening":
        return "later-reseal"
    retry = policy.get("interrupted_retry")
    if not isinstance(retry, dict) or retry.get("compensation") != "target-only":
        return "interrupted-retry-compensation"
    if retry.get("fresh_approval") is not True:
        return "interrupted-retry-fresh-approval"
    return None



def find_row(rows: list[dict], fixture: str) -> dict | None:
    matches = [row for row in rows if row["fixture"] == fixture]
    if len(matches) != 1:
        return None
    return matches[0]


def parse_frontmatter_text(text: str) -> dict[str, str]:
    parts = text.split("---", 2)
    if len(parts) < 3:
        return {}
    values: dict[str, str] = {}
    for line in parts[1].splitlines():
        match = re.match(r"^([a-z_]+):(?:[ \t]*(.*))?$", line)
        if match:
            values[match.group(1)] = (match.group(2) or "").strip()
    return values


def parse_frontmatter(path: Path) -> tuple[dict[str, str], str]:
    text = path.read_text(encoding="utf-8")
    return parse_frontmatter_text(text), text


def write_plan(directory: Path, name: str, fields: dict[str, str], body: str, history: dict | None = None) -> Path:
    directory.mkdir(parents=True, exist_ok=True)
    path = directory / name
    frontmatter = "\n".join(f"{key}: {value}" if value else f"{key}:" for key, value in fields.items())
    path.write_text(f"---\n{frontmatter}\n---\n{body}\n", encoding="utf-8")
    if history is not None:
        path.with_suffix(path.suffix + ".history.json").write_text(json.dumps(history), encoding="utf-8")
    return path


def body_seal(text: str) -> str:
    return hashlib.sha256(text.split("---", 2)[2].encode("utf-8")).hexdigest()
def canonical_body(text: str) -> str:
    parts = text.split("---", 2)
    if len(parts) != 3:
        raise ValueError("malformed canonical body")
    return parts[2]


def independent_body_seal(text: str) -> str:
    canonical = text.split("---", 2)[2]
    return hashlib.sha256(canonical.encode("utf-8")).hexdigest()

def make_sealed_plan(directory: Path, name: str, fields: dict[str, str], body: str, history: dict | None = None) -> Path:
    path = write_plan(directory, name, fields, body, history)
    fields = dict(fields)
    fields["body_seal"] = independent_body_seal(path.read_text(encoding="utf-8"))
    return write_plan(directory, name, fields, body, history)


def implementing_cases(directory: Path) -> list[tuple[str, Path]]:
    base = {"schema": "plan/v1", "title": "Fixture", "type": "fix", "status": "approved", "date": "2026-08-15", "execution": "code"}
    cases: list[tuple[str, Path]] = []
    cases.append(("schema-plan-v1", write_plan(directory, "schema-plan-v1.md", base, "## Goal\n\nfixture")))
    missing = dict(base); missing.pop("schema"); cases.append(("schema-missing", write_plan(directory, "schema-missing.md", missing, "## Goal\n\nfixture")))
    unknown = dict(base); unknown["schema"] = "plan/v9"; cases.append(("schema-unknown", write_plan(directory, "schema-unknown.md", unknown, "## Goal\n\nfixture")))
    for name, status in (("status-approved", "approved"), ("status-draft", "draft"), ("status-done", "done"), ("status-superseded", "superseded"), ("status-unknown", "paused")):
        fields = dict(base); fields["status"] = status
        if status == "done": fields["completed_by"] = "0123456789abcdef0123456789abcdef01234567"
        if status == "superseded": fields["superseded_by"] = "docs/plans/successor.md"
        cases.append((name, write_plan(directory, f"{name}.md", fields, "## Goal\n\nfixture")))
    missing_done = dict(base); missing_done["status"] = "done"; cases.append(("status-done-missing-evidence", write_plan(directory, "status-done-missing-evidence.md", missing_done, "## Goal\n\nfixture")))
    missing_status = dict(base); missing_status.pop("status"); cases.append(("status-missing", write_plan(directory, "status-missing.md", missing_status, "## Goal\n\nfixture")))
    sealed_fields = dict(base)
    cases.append(("seal-correct", make_sealed_plan(directory, "seal-correct.md", sealed_fields, "## Goal\n\nsealed")))
    malformed = dict(base); malformed["body_seal"] = "not-a-seal"; cases.append(("seal-malformed", write_plan(directory, "seal-malformed.md", malformed, "## Goal\n\nsealed")))
    mismatch = dict(base); mismatch["body_seal"] = "0" * 64; cases.append(("seal-mismatch", write_plan(directory, "seal-mismatch.md", mismatch, "## Goal\n\nsealed")))
    cases.append(("seal-never-sealed", write_plan(directory, "seal-never-sealed.md", base, "## Goal\n\nhistorical")))
    cases.append(("seal-removed", write_plan(directory, "seal-removed.md", base, "## Goal\n\nhistorical", {"had_seal": True})))
    cases.append(("reseal-post-approval", make_sealed_plan(directory, "reseal-post-approval.md", sealed_fields, "## Goal\n\nresealed", {"resealed_after_approval": True})))
    for name, execution in (("unit-code", "code"), ("unit-non-code", "non-code")):
        fields = dict(base); fields["execution"] = execution
        body = "## Goal\n\nfixture\n\n## Files\n\n- src/example\n\n## Interfaces\n\n- contract\n\n## Test scenarios\n\n- happy\n\n## Execution note\n\ntest-first"
        cases.append((name, write_plan(directory, f"{name}.md", fields, body)))
    return cases


def implementing_decision(path: Path, fixture: str) -> tuple[str, str]:
    fields, text = parse_frontmatter(path)
    schema = fields.get("schema")
    if schema != "plan/v1":
        return "reject", "schema"
    status = fields.get("status")
    if status == "draft": return "reject", "pending approval"
    if status == "done":
        return "reject", f"completed_by={fields['completed_by']}" if fields.get("completed_by") else "completed_by missing"
    if status == "superseded":
        return "reject", f"superseded_by={fields['superseded_by']}" if fields.get("superseded_by") else "superseded_by missing"
    if status != "approved": return "reject", "status"
    history_path = path.with_suffix(path.suffix + ".history.json")
    history = json.loads(history_path.read_text(encoding="utf-8")) if history_path.exists() else {}
    current = fields.get("body_seal")
    if history.get("resealed_after_approval"):
        return "reject", "interactive deepening"
    if current is None:
        if history.get("had_seal"):
            return "reject", "removed seal"
    else:
        computed = body_seal(text)
        if not re.fullmatch(r"[0-9a-f]{64}", current):
            return "reject", f"stored={current} computed={computed}"
        if current != computed:
            return "reject", f"stored={current} computed={computed}"
    if fixture == "unit-code" and fields.get("execution") != "code": return "reject", "code flow"
    if fixture == "unit-non-code" and fields.get("execution") != "non-code": return "reject", "non-code flow"
    if fixture == "unit-code" or fixture == "unit-non-code":
        required = ("Files", "Interfaces", "Test scenarios", "Execution note")
        if not all(f"## {heading}" in text for heading in required): return "reject", "full handoff"
    return "accept", ""
def adoption_cases(directory: Path, consumer: str) -> list[tuple[str, Path]]:
    cases: list[tuple[str, Path]] = []
    body = "## Goal\n\nimmutable baseline body\n"
    old_seal = "0" * 64
    required = {
        "approval": "first-hand explicit approval",
        "baseline": "",
        "plan_path": "docs/plans/adoption.md",
        "old_seal": old_seal,
        "new_seal": "",
        "reproduction_command": "",
    }
    names = (
        "adoption-complete",
        "adoption-changed-body",
        "adoption-missing-baseline",
        "adoption-missing-approval",
        "adoption-missing-plan-path",
        "adoption-missing-old-seal",
        "adoption-missing-new-seal",
        "adoption-missing-reproduction-command",
        "reseal-after-adoption",
    )
    for name in names:
        case_dir = directory / name
        repo = case_dir / "repo"
        (repo / "docs/plans").mkdir(parents=True, exist_ok=True)
        run_git(repo, "init", "-q")
        run_git(repo, "config", "user.email", "fixture@example.invalid")
        run_git(repo, "config", "user.name", "Adoption Fixture")
        path = write_plan(
            repo / "docs/plans",
            "adoption.md",
            {
                "schema": "plan/v1",
                "title": "Adoption",
                "type": "fix",
                "status": "approved",
                "date": "2026-08-15",
                "execution": "code",
                "body_seal": old_seal,
            },
            body,
        )
        (repo / "sentinel.txt").write_text("ADOPTION_BOUNDARY_SENTINEL\n", encoding="utf-8")
        run_git(repo, "add", ".")
        run_git(repo, "commit", "-qm", "adoption baseline")
        baseline = run_git(repo, "rev-parse", "HEAD")
        with open(path, encoding="utf-8", newline=None) as handle:
            current_text = handle.read()
        evidence = dict(required)
        evidence["baseline"] = baseline
        evidence["new_seal"] = body_seal(current_text)
        evidence["reproduction_command"] = f"python3 migration-check.py {baseline} docs/plans/adoption.md"
        if name == "adoption-changed-body":
            path.write_text(current_text + "\nchanged body byte\n", encoding="utf-8")
        if name == "adoption-missing-baseline":
            evidence["baseline"] = "deadbeefdeadbeefdeadbeefdeadbeefdeadbeef"
            evidence["reproduction_command"] = f"python3 migration-check.py {evidence['baseline']} docs/plans/adoption.md"
        for field, suffix in (
            ("approval", "approval"),
            ("plan_path", "plan-path"),
            ("old_seal", "old-seal"),
            ("new_seal", "new-seal"),
            ("reproduction_command", "reproduction-command"),
        ):
            if name == f"adoption-missing-{suffix}":
                evidence.pop(field)
        path.with_suffix(path.suffix + ".adoption.json").write_text(json.dumps(evidence), encoding="utf-8")
        if name == "reseal-after-adoption" or (consumer == "reviewing" and name == "adoption-complete"):
            adopted = current_text.replace("body_seal: " + old_seal, "body_seal: " + evidence["new_seal"])
            path.write_text(adopted, encoding="utf-8")
            run_git(repo, "add", "docs/plans/adoption.md")
            message = (
                f"adoption reseal\n\nbaseline={baseline}\nplan=docs/plans/adoption.md\n"
                f"old-seal={old_seal}\nnew-seal={evidence['new_seal']}\n"
                f"reproduction-command={evidence['reproduction_command']}\n"
                "approval=first-hand-explicit\n"
            )
            run_git(repo, "commit", "-qm", message)
            if name == "reseal-after-adoption":
                resealed = adopted.replace(evidence["new_seal"], "f" * 64, 1)
                path.write_text(resealed, encoding="utf-8")
                run_git(repo, "add", "docs/plans/adoption.md")
                run_git(repo, "commit", "-qm", "unauthorized adoption reseal-away")
                path.write_text(adopted, encoding="utf-8")
                run_git(repo, "add", "docs/plans/adoption.md")
                run_git(repo, "commit", "-qm", "restored adoption seal")
        cases.append((name, path))
    return cases
def verify_transition(repo: Path, baseline: str, plan_path: str, evidence: dict, policy: dict, commit: str) -> tuple[bool, str]:
    try:
        parent = run_git(repo, "rev-parse", f"{commit}^")
    except subprocess.CalledProcessError:
        return False, "parent-missing"
    if baseline == commit:
        return False, "parent-mismatch"
    try:
        run_git(repo, "merge-base", "--is-ancestor", baseline, commit)
    except subprocess.CalledProcessError:
        return False, "parent-mismatch"
    if commit_paths(repo, commit) != {plan_path}:
        return False, "changed-paths"
    try:
        parent_text = run_git_text(repo, "show", f"{parent}:{plan_path}")
        current_text = run_git_text(repo, "show", f"{commit}:{plan_path}")
        baseline_text = run_git_text(repo, "show", f"{baseline}:{plan_path}")
    except subprocess.CalledProcessError:
        return False, "missing-baseline"
    try:
        if canonical_body(baseline_text) != canonical_body(current_text):
            return False, "baseline-body-mismatch"
    except ValueError:
        return False, "malformed-body"
    old_line = f"body_seal: {evidence.get('old_seal', '')}\n"
    new_line = f"body_seal: {evidence.get('new_seal', '')}\n"
    if parent_text.count(old_line) != 1 or current_text.count(new_line) != 1:
        return False, "seal-line"
    if re.sub(r"(?m)^body_seal: [0-9a-f]{64}\n", "", parent_text, count=1) != re.sub(r"(?m)^body_seal: [0-9a-f]{64}\n", "", current_text, count=1):
        return False, "non-seal-bytes"
    commit_policy = policy["migration_commit"]
    expected = {
        "baseline": baseline,
        "plan": plan_path,
        "old-seal": evidence.get("old_seal", ""),
        "new-seal": evidence.get("new_seal", ""),
        "reproduction-command": evidence.get("reproduction_command", ""),
        "approval": commit_policy["approval"],
    }
    parsed: dict[str, str] = {}
    for line in run_git_text(repo, "show", "-s", "--format=%B", commit).splitlines():
        if "=" not in line:
            continue
        key, value = line.split("=", 1)
        if key not in expected or key in parsed:
            return False, "message-evidence"
        parsed[key] = value
    if parsed != expected:
        return False, "message-evidence"
    return True, "transition-valid"


def verify_later_transition(repo: Path, plan_path: str, commit: str) -> tuple[bool, str]:
    try:
        parent = run_git(repo, "rev-parse", f"{commit}^")
        parent_text = run_git_text(repo, "show", f"{parent}:{plan_path}")
        current_text = run_git_text(repo, "show", f"{commit}:{plan_path}")
    except subprocess.CalledProcessError:
        return False, ""
    paths = commit_paths(repo, commit)
    seal_pattern = re.compile(r"(?m)^body_seal: ([0-9a-f]{64})$")
    parent_seals = seal_pattern.findall(parent_text)
    current_seals = seal_pattern.findall(current_text)
    if len(parent_seals) != 1 or len(current_seals) != 1:
        return False, ""
    parent_seal, current_seal = parent_seals[0], current_seals[0]
    try:
        if parent_seal != body_seal(parent_text) or parent_seal != independent_body_seal(parent_text):
            return False, ""
    except (IndexError, ValueError):
        return False, ""

    parent_fields = parse_frontmatter_text(parent_text)
    current_fields = parse_frontmatter_text(current_text)
    if parent_fields.get("schema") != "plan/v1" or current_fields.get("schema") != "plan/v1":
        return False, ""

    if parent_seal == current_seal:
        # An unchanged seal has exactly two legal terminal shapes.  Both
        # mutate only the status and its evidence slot, preserve the
        # canonical body, and carry exactly one same-commit companion.
        if plan_path not in paths:
            return False, ""
        companion = paths - {plan_path}
        if len(companion) != 1:
            return False, ""
        companion_path = next(iter(companion))
        if parent_fields.get("status") != "approved":
            return False, ""
        changed_fields = {
            key
            for key in set(parent_fields) | set(current_fields)
            if parent_fields.get(key) != current_fields.get(key)
        }
        try:
            if canonical_body(parent_text) != canonical_body(current_text):
                return False, ""
        except ValueError:
            return False, ""

        if current_fields.get("status") == "done":
            # Done requires a non-empty docs/retros/*.md companion and a
            # completed_by commit.
            retro_parts = Path(companion_path).parts
            if (
                len(retro_parts) != 3
                or retro_parts[:2] != ("docs", "retros")
                or not retro_parts[2].endswith(".md")
            ):
                return False, ""
            try:
                retro_text = run_git_text(repo, "show", f"{commit}:{companion_path}")
            except subprocess.CalledProcessError:
                return False, ""
            if not retro_text.strip():
                return False, ""
            if changed_fields != {"status", "completed_by"}:
                return False, ""
            completed_by = current_fields.get("completed_by")
            if not completed_by:
                return False, ""
            try:
                run_git(repo, "cat-file", "-e", f"{completed_by}^{{commit}}")
            except subprocess.CalledProcessError:
                return False, ""
            return True, current_seal

        if current_fields.get("status") == "superseded":
            # Superseded requires a repo-relative docs/plans/*.md successor
            # companion whose path is recorded in superseded_by and exists
            # as a committed file in this exact transition.
            superseded_by = current_fields.get("superseded_by")
            successor_parts = Path(companion_path).parts
            if (
                not superseded_by
                or superseded_by != companion_path
                or len(successor_parts) != 3
                or successor_parts[:2] != ("docs", "plans")
                or not successor_parts[2].endswith(".md")
            ):
                return False, ""
            try:
                if run_git(repo, "cat-file", "-t", f"{commit}:{companion_path}") != "blob":
                    return False, ""
            except subprocess.CalledProcessError:
                return False, ""
            if changed_fields != {"status", "superseded_by"}:
                return False, ""
            return True, current_seal

        return False, ""
    # Interactive deepening must be a real body edit paired with a digest
    # update.  Its same-commit message must carry the exact shared
    # first-hand authorization marker.
    if paths != {plan_path}:
        return False, ""
    if {
        key
        for key in set(parent_fields) | set(current_fields)
        if key != "body_seal" and parent_fields.get(key) != current_fields.get(key)
    }:
        return False, ""
    try:
        if canonical_body(parent_text) == canonical_body(current_text):
            return False, ""
        if current_seal != body_seal(current_text) or current_seal != independent_body_seal(current_text):
            return False, ""
    except (IndexError, ValueError):
        return False, ""
    marker_key = INTERACTIVE_DEEPENING_MARKER.partition("=")[0] + "="
    marker_count = 0
    for line in run_git_text(repo, "show", "-s", "--format=%B", commit).splitlines():
        stripped = line.strip()
        if stripped.startswith(marker_key):
            if line != INTERACTIVE_DEEPENING_MARKER:
                return False, ""
            marker_count += 1
    if marker_count != 1:
        return False, ""
    return True, current_seal


def prior_transition(repo: Path, baseline: str, plan_path: str, evidence: dict, policy: dict) -> tuple[bool, str, str | None, str | None]:
    valid_commits: list[str] = []
    for commit in run_git(repo, "log", "--format=%H", "--", plan_path).splitlines():
        valid, _ = verify_transition(repo, baseline, plan_path, evidence, policy, commit)
        if valid:
            valid_commits.append(commit)
    if not valid_commits:
        return False, "no-transition", None, None
    if len(valid_commits) != 1:
        return False, "multiple-transitions", None, None
    migration = valid_commits[0]
    try:
        migration_text = run_git_text(repo, "show", f"{migration}:{plan_path}")
    except subprocess.CalledProcessError:
        return False, "no-transition", None, None
    # The one-time adoption is the first and only plan-touching commit after
    # the baseline.  A reseal, body edit, or even a repaired intermediate
    # state is still unauthorized history; restoring bytes before the valid
    # migration does not erase that touch from the audit trail.
    history_commits = run_git(
        repo, "log", "--reverse", "--format=%H", f"{baseline}..{migration}", "--", plan_path
    ).splitlines()
    if migration not in history_commits or any(commit != migration for commit in history_commits):
        return False, "pre-migration-history", None, None
    latest_seal = evidence["new_seal"]
    later_commits = run_git(repo, "log", "--reverse", "--format=%H", f"{migration}..HEAD", "--", plan_path).splitlines()
    for commit in later_commits:
        authorized, later_seal = verify_later_transition(repo, plan_path, commit)
        if not authorized:
            return False, "interactive deepening", None, None
        latest_seal = later_seal
    return True, "transition-valid", latest_seal, migration_text

def adoption_decision(path: Path, fixture: str, consumer: str, policy: dict | None = None) -> tuple[str, str]:
    del fixture
    policy = adoption_policy if policy is None else policy
    policy_error = policy_violation(policy)
    if policy_error:
        return "reject", f"adoption-policy:{policy_error}"
    meta_path = path.with_suffix(path.suffix + ".adoption.json")
    if not meta_path.exists():
        return "reject", "adoption evidence missing"
    evidence = json.loads(meta_path.read_text(encoding="utf-8"))
    diagnostic_names = {
        "approval": "approval",
        "baseline": "baseline commit",
        "plan_path": "plan path",
        "old_seal": "old seal",
        "new_seal": "new seal",
        "reproduction_command": "reproduction command",
    }
    for field in policy["required_evidence"]:
        if not evidence.get(field):
            return "reject", diagnostic_names[field]
    plan_path = evidence["plan_path"]
    if plan_path.startswith("/") or ".." in Path(plan_path).parts or plan_path != "docs/plans/adoption.md":
        return "reject", "plan path"
    if evidence.get("approval") != "first-hand explicit approval":
        return "reject", "approval"
    expected_command = f"python3 migration-check.py {evidence['baseline']} {plan_path}"
    if evidence.get("reproduction_command") != expected_command:
        return "reject", "reproduction command"
    repo = path.parents[2]
    transition_found, transition_detail, transition_seal, migration_text = prior_transition(
        repo, evidence["baseline"], plan_path, evidence, policy
    )
    try:
        baseline_text = run_git_text(repo, "show", f"{evidence['baseline']}:{plan_path}")
    except subprocess.CalledProcessError:
        return "reject", "missing-baseline"
    with open(path, encoding="utf-8", newline=None) as handle:
        current_text = handle.read()
    if policy["baseline_current_body"] != "equal":
        return "reject", "adoption-policy:baseline-current-equality"
    if transition_detail == "interactive deepening":
        return "reject", "interactive deepening"
    comparison_text = migration_text if transition_found and migration_text is not None else current_text
    try:
        # Adoption proves the baseline against the migration snapshot.  Later
        # legal terminal/deepening commits are evaluated independently.
        if canonical_body(baseline_text) != canonical_body(comparison_text):
            return "reject", "changed-body"
    except ValueError:
        return "reject", "malformed-body"
    if body_seal(baseline_text) != body_seal(comparison_text):
        return "reject", "changed-body"
    if consumer == "reviewing" and not transition_found:
        return "reject", f"migration commit:{transition_detail}"
    if not re.fullmatch(r"[0-9a-f]{64}", evidence["old_seal"]):
        return "reject", "old seal"
    if not re.fullmatch(r"[0-9a-f]{64}", evidence["new_seal"]):
        return "reject", "new seal"
    current_fields, _ = parse_frontmatter(path)
    expected_current_seal = (
        transition_seal
        if consumer == "reviewing" and transition_found
        else evidence["new_seal"]
        if consumer == "reviewing"
        else evidence["old_seal"]
    )
    if transition_found and current_fields.get("body_seal") != expected_current_seal:
        return "reject", "interactive deepening"
    if current_fields.get("body_seal") != expected_current_seal:
        return "reject", "new seal" if consumer == "reviewing" else "old seal"
    expected_body_seal = expected_current_seal if consumer == "reviewing" else evidence["new_seal"]
    if expected_body_seal != body_seal(current_text) or expected_body_seal != independent_body_seal(current_text):
        return "reject", "new seal"
    if policy["later_reseal"] != "reject-unless-interactive-deepening":
        return "reject", "adoption-policy:later-reseal"
    return "accept", "adoption-approved"


def evaluate_adoption_cases(rows: list[dict], cases: list[tuple[str, Path]], consumer: str) -> None:
    for fixture, path in cases:
        row = find_row(rows, fixture)
        if row is None:
            emit("FAIL", fixture, "contract row missing")
            continue
        repo = path.parents[2]
        before_head = run_git(repo, "rev-parse", "HEAD")
        before_bytes = path.read_bytes()
        actual, detail = adoption_decision(path, fixture, consumer)
        after_head = run_git(repo, "rev-parse", "HEAD")
        after_bytes = path.read_bytes()
        if actual != row["expected"] or row["diagnostic"] not in detail:
            emit("FAIL", fixture, f"expected={row['expected']} diagnostic={row['diagnostic']} got={actual}:{detail}")
        elif before_head != after_head or before_bytes != after_bytes:
            emit("FAIL", fixture, "adoption decision mutated Git state")
        else:
            emit("PASS", fixture, f"{actual}:{detail}")
    if consumer == "reviewing":
        complete = dict(cases)["adoption-complete"]
        complete_meta = complete.with_suffix(complete.suffix + ".adoption.json")
        transition_mutations(complete, json.loads(complete_meta.read_text(encoding="utf-8")))
def transition_mutations(complete: Path, evidence: dict) -> None:
    source_repo = complete.parents[2]
    source_baseline = evidence["baseline"]
    source_plan = evidence["plan_path"]
    mutation_root = Path(tempfile.mkdtemp(prefix="u4-transition-mutations-"))
    policy = adoption_policy
    assert policy is not None
    try:
        def fresh(name: str) -> Path:
            destination = mutation_root / name
            shutil.copytree(source_repo, destination)
            return destination

        expected_commit = run_git(source_repo, "rev-parse", "HEAD")
        cases: list[tuple[str, str, str]] = [
            ("wrong-parent", "wrong-parent", ""),
            ("extra-path", "extra-path", ""),
            ("extra-frontmatter", "extra-frontmatter", ""),
            ("missing-message-field", "missing-message-field", ""),
            ("prefixed-message-field", "prefixed-message-field", ""),
            ("duplicate-message-field", "duplicate-message-field", ""),
            ("conflicting-message-field", "conflicting-message-field", ""),
            ("wrong-reproduction-command", "wrong-reproduction-command", ""),
            ("wrong-approval", "wrong-approval", ""),
            ("wrong-plan", "wrong-plan", ""),
            ("wrong-old-seal", "wrong-old-seal", ""),
            ("wrong-new-seal", "wrong-new-seal", ""),
        ]
        for name, mutation, _ in cases:
            repo = fresh(name)
            candidate = expected_commit
            baseline = source_baseline
            if mutation == "wrong-parent":
                baseline = run_git(repo, "rev-parse", "HEAD")
            else:
                run_git(repo, "reset", "--hard", source_baseline)
                plan = repo / source_plan
                text = plan.read_text(encoding="utf-8")
                adopted = text.replace(
                    f"body_seal: {evidence['old_seal']}",
                    f"body_seal: {evidence['new_seal']}",
                    1,
                )
                if mutation == "extra-frontmatter":
                    adopted = adopted.replace("title: Adoption", "title: Mutated Adoption", 1)
                plan.write_text(adopted, encoding="utf-8")
                if mutation == "extra-path":
                    (repo / "extra.txt").write_text("EXTRA\n", encoding="utf-8")
                message = (
                    "adoption reseal\n\n"
                    f"baseline={source_baseline}\nplan={source_plan}\n"
                    f"old-seal={evidence['old_seal']}\nnew-seal={evidence['new_seal']}\n"
                    f"reproduction-command={evidence['reproduction_command']}\n"
                    "approval=first-hand-explicit\n"
                )
                if mutation == "missing-message-field":
                    message = message.replace(f"baseline={source_baseline}\n", "")
                elif mutation == "prefixed-message-field":
                    message = message.replace("baseline=", "x-baseline=", 1)
                elif mutation == "duplicate-message-field":
                    message += f"baseline={source_baseline}\n"
                elif mutation == "conflicting-message-field":
                    message = message.replace(f"baseline={source_baseline}\n", f"baseline={'0' * 40}\n", 1)
                    message += f"baseline={source_baseline}\n"
                elif mutation == "wrong-reproduction-command":
                    message = message.replace(
                        f"reproduction-command={evidence['reproduction_command']}\n",
                        f"reproduction-command=python3 migration-check.py {source_baseline} {source_plan} --mutated\n",
                        1,
                    )
                elif mutation == "wrong-approval":
                    message = message.replace("approval=first-hand-explicit\n", "approval=fresh-approval-after-interruption\n", 1)
                elif mutation == "wrong-plan":
                    message = message.replace(f"plan={source_plan}\n", "plan=docs/plans/other.md\n", 1)
                elif mutation == "wrong-old-seal":
                    message = message.replace(f"old-seal={evidence['old_seal']}\n", f"old-seal={'1' * 64}\n", 1)
                elif mutation == "wrong-new-seal":
                    message = message.replace(f"new-seal={evidence['new_seal']}\n", f"new-seal={'2' * 64}\n", 1)
                run_git(repo, "add", source_plan)
                if mutation == "extra-path":
                    run_git(repo, "add", "extra.txt")
                run_git(repo, "commit", "-qm", message)
                candidate = run_git(repo, "rev-parse", "HEAD")
            valid, detail = verify_transition(repo, baseline, source_plan, evidence, policy, candidate)
            expected_detail = {
                "wrong-parent": "parent-mismatch",
                "extra-path": "changed-paths",
                "extra-frontmatter": "non-seal-bytes",
                "missing-message-field": "message-evidence",
                "prefixed-message-field": "message-evidence",
                "duplicate-message-field": "message-evidence",
                "conflicting-message-field": "message-evidence",
                "wrong-reproduction-command": "message-evidence",
                "wrong-approval": "message-evidence",
                "wrong-plan": "message-evidence",
                "wrong-old-seal": "message-evidence",
                "wrong-new-seal": "message-evidence",
            }[mutation]
            if valid:
                emit("FAIL", f"transition-mutation-{name}", "invalid transition accepted")
            elif detail != expected_detail:
                emit("FAIL", f"transition-mutation-{name}", f"diagnostic drift: expected={expected_detail} got={detail}")
            else:
                emit("PASS", f"transition-mutation-{name}", f"rejected:{detail}")
        def evaluate_pre_migration_history(name: str, build_history) -> None:
            repo = fresh(name)
            run_git(repo, "reset", "--hard", source_baseline)
            baseline_text = (repo / source_plan).read_text(encoding="utf-8")

            def commit_plan(text: str, message: str) -> None:
                (repo / source_plan).write_text(text, encoding="utf-8")
                run_git(repo, "add", source_plan)
                run_git(repo, "commit", "-qm", message)

            def migration_message() -> str:
                return (
                    "adoption reseal\n\n"
                    f"baseline={source_baseline}\nplan={source_plan}\n"
                    f"old-seal={evidence['old_seal']}\nnew-seal={evidence['new_seal']}\n"
                    f"reproduction-command={evidence['reproduction_command']}\n"
                    "approval=first-hand-explicit\n"
                )

            build_history(repo, baseline_text, commit_plan, migration_message)
            candidate_plan = repo / source_plan
            candidate_plan.with_suffix(candidate_plan.suffix + ".adoption.json").write_text(
                json.dumps(evidence), encoding="utf-8"
            )
            actual, detail = adoption_decision(candidate_plan, name, "reviewing")
            if actual == "reject" and "pre-migration-history" in detail:
                emit("PASS", f"pre-migration-history-{name}", f"{actual}:{detail}")
            else:
                emit(
                    "FAIL",
                    f"pre-migration-history-{name}",
                    f"expected=reject:pre-migration-history got={actual}:{detail}",
                )

        def reseal_away_restore_migration(repo: Path, baseline_text: str, commit_plan, migration_message) -> None:
            resealed = baseline_text.replace(
                f"body_seal: {evidence['old_seal']}\n",
                f"body_seal: {'f' * 64}\n",
                1,
            )
            commit_plan(resealed, "unauthorized pre-migration reseal-away")
            restored = resealed.replace(
                f"body_seal: {'f' * 64}\n",
                f"body_seal: {evidence['old_seal']}\n",
                1,
            )
            commit_plan(restored, "restored pre-migration seal")
            migrated = restored.replace(
                f"body_seal: {evidence['old_seal']}\n",
                f"body_seal: {evidence['new_seal']}\n",
                1,
            )
            commit_plan(migrated, migration_message())

        def body_change_restore_migration(repo: Path, baseline_text: str, commit_plan, migration_message) -> None:
            changed = baseline_text.rstrip("\n") + "\n\npre-migration body byte\n"
            changed = changed.replace(
                f"body_seal: {evidence['old_seal']}\n",
                f"body_seal: {independent_body_seal(changed)}\n",
                1,
            )
            commit_plan(changed, "unauthorized pre-migration body change")
            commit_plan(baseline_text, "restored pre-migration body")
            migrated = baseline_text.replace(
                f"body_seal: {evidence['old_seal']}\n",
                f"body_seal: {evidence['new_seal']}\n",
                1,
            )
            commit_plan(migrated, migration_message())

        evaluate_pre_migration_history(
            "reseal-away-restoration-migration",
            reseal_away_restore_migration,
        )
        evaluate_pre_migration_history(
            "body-change-restoration-migration",
            body_change_restore_migration,
        )

        def evaluate_later_history(name: str, repo: Path, expected: str) -> None:
            candidate_plan = repo / source_plan
            candidate_plan.with_suffix(candidate_plan.suffix + ".adoption.json").write_text(
                json.dumps(evidence), encoding="utf-8"
            )
            actual, detail = adoption_decision(candidate_plan, name, "reviewing")
            if actual == expected and (
                (expected == "accept" and detail == "adoption-approved")
                or (expected == "reject" and detail == "interactive deepening")
            ):
                emit("PASS", f"later-history-{name}", f"{actual}:{detail}")
            else:
                emit("FAIL", f"later-history-{name}", f"expected={expected} got={actual}:{detail}")

        # Legal retrospective completion: the plan changes only its terminal
        # mutable slots, and the same commit carries its companion retro.
        retro_repo = fresh("retrospective-terminal")
        retro_plan = retro_repo / source_plan
        retro_text = retro_plan.read_text(encoding="utf-8")
        retro_text = retro_text.replace("status: approved\n", "status: done\n", 1)
        retro_text = retro_text.replace(
            f"body_seal: {evidence['new_seal']}\n",
            f"body_seal: {evidence['new_seal']}\ncompleted_by: {expected_commit}\n",
            1,
        )
        retro_plan.write_text(retro_text, encoding="utf-8")
        retro_path = retro_repo / "docs/retros/adoption.md"
        retro_path.parent.mkdir(parents=True, exist_ok=True)
        retro_path.write_text("# Adoption retrospective\n\nCompleted.\n", encoding="utf-8")
        run_git(retro_repo, "add", source_plan, "docs/retros/adoption.md")
        run_git(retro_repo, "commit", "-qm", "retrospective terminal transition")
        evaluate_later_history("retrospective-terminal", retro_repo, "accept")

        # The same frontmatter transition without its retro companion is not
        # an authorized mutable-slot shape.
        missing_retro_repo = fresh("retrospective-missing-companion")
        missing_retro_plan = missing_retro_repo / source_plan
        missing_retro_text = missing_retro_plan.read_text(encoding="utf-8")
        missing_retro_text = missing_retro_text.replace("status: approved\n", "status: done\n", 1)
        missing_retro_text = missing_retro_text.replace(
            f"body_seal: {evidence['new_seal']}\n",
            f"body_seal: {evidence['new_seal']}\ncompleted_by: {expected_commit}\n",
            1,
        )
        missing_retro_plan.write_text(missing_retro_text, encoding="utf-8")
        run_git(missing_retro_repo, "add", source_plan)
        run_git(missing_retro_repo, "commit", "-qm", "terminal transition without retro")
        evaluate_later_history("retrospective-missing-companion", missing_retro_repo, "reject")

        # A retro transition with an unrelated frontmatter edit is also
        # unauthorized, despite preserving the unchanged seal.
        extra_retro_repo = fresh("retrospective-extra-frontmatter")
        extra_retro_plan = extra_retro_repo / source_plan
        extra_retro_text = extra_retro_plan.read_text(encoding="utf-8")
        extra_retro_text = extra_retro_text.replace("status: approved\n", "status: done\n", 1)
        extra_retro_text = extra_retro_text.replace(
            f"body_seal: {evidence['new_seal']}\n",
            f"body_seal: {evidence['new_seal']}\ncompleted_by: {expected_commit}\n",
            1,
        ).replace("title: Adoption\n", "title: Mutated Adoption\n", 1)
        extra_retro_plan.write_text(extra_retro_text, encoding="utf-8")
        extra_retro_path = extra_retro_repo / "docs/retros/adoption.md"
        extra_retro_path.parent.mkdir(parents=True, exist_ok=True)
        extra_retro_path.write_text("# Adoption retrospective\n\nCompleted.\n", encoding="utf-8")
        run_git(extra_retro_repo, "add", source_plan, "docs/retros/adoption.md")
        run_git(extra_retro_repo, "commit", "-qm", "terminal transition with extra mutation")
        evaluate_later_history("retrospective-extra-frontmatter", extra_retro_repo, "reject")

        def make_superseded_repo(
            name: str,
            successor_field: str = "docs/plans/successor.md",
            companion_path: str | None = "docs/plans/successor.md",
            extra_path: str | None = None,
            mutation: str | None = None,
        ) -> Path:
            repo = fresh(name)
            plan = repo / source_plan
            text = plan.read_text(encoding="utf-8")
            text = text.replace("status: approved\n", "status: superseded\n", 1)
            text = text.replace(
                f"body_seal: {evidence['new_seal']}\n",
                f"body_seal: {evidence['new_seal']}\nsuperseded_by: {successor_field}\n",
                1,
            )
            if mutation == "extra-frontmatter":
                text = text.replace("title: ", "title: Mutated ", 1)
            elif mutation == "body":
                text = text.rstrip("\n") + "\n\n## Unauthorized mutation\n\nRejected.\n"
            plan.write_text(text, encoding="utf-8")
            if companion_path is not None:
                successor = repo / companion_path
                successor.parent.mkdir(parents=True, exist_ok=True)
                write_plan(
                    successor.parent,
                    successor.name,
                    {
                        "schema": "plan/v1",
                        "title": "Successor",
                        "type": "fix",
                        "status": "approved",
                        "date": "2026-08-16",
                        "execution": "code",
                    },
                    "## Goal\n\nSuccessor fixture.\n",
                )
            if extra_path is not None:
                extra = repo / extra_path
                extra.parent.mkdir(parents=True, exist_ok=True)
                extra.write_text("EXTRA\n", encoding="utf-8")
            run_git(repo, "add", source_plan)
            if companion_path is not None:
                run_git(repo, "add", companion_path)
            if extra_path is not None:
                run_git(repo, "add", extra_path)
            run_git(repo, "commit", "-qm", "superseded terminal transition")
            return repo

        # A post-adoption supersession must carry its repo-relative successor
        # plan in the same commit as the unchanged-seal predecessor transition.
        superseded_repo = make_superseded_repo("superseded-terminal")
        evaluate_later_history("superseded-terminal", superseded_repo, "accept")

        # Missing, misplaced, extra-path, and plan-byte mutations all reject.
        missing_successor_repo = make_superseded_repo(
            "superseded-missing-successor", companion_path=None
        )
        evaluate_later_history("superseded-missing-successor", missing_successor_repo, "reject")
        wrong_successor_path_repo = make_superseded_repo(
            "superseded-wrong-successor-path",
            successor_field="docs/retros/successor.md",
            companion_path="docs/retros/successor.md",
        )
        evaluate_later_history("superseded-wrong-successor-path", wrong_successor_path_repo, "reject")
        extra_successor_path_repo = make_superseded_repo(
            "superseded-extra-path", extra_path="extra.txt"
        )
        evaluate_later_history("superseded-extra-path", extra_successor_path_repo, "reject")
        extra_successor_frontmatter_repo = make_superseded_repo(
            "superseded-extra-frontmatter", mutation="extra-frontmatter"
        )
        evaluate_later_history(
            "superseded-extra-frontmatter", extra_successor_frontmatter_repo, "reject"
        )
        extra_successor_body_repo = make_superseded_repo(
            "superseded-extra-body", mutation="body"
        )
        evaluate_later_history("superseded-extra-body", extra_successor_body_repo, "reject")

        def make_deepening_repo(name: str, authorization: str | None, seal_override: str | None = None) -> Path:
            repo = fresh(name)
            plan = repo / source_plan
            text = plan.read_text(encoding="utf-8")
            deepened = text.rstrip("\n") + "\n\n## Interactive deepening\n\nAccepted finding.\n"
            deepened_seal = independent_body_seal(deepened)
            if seal_override is not None:
                deepened_seal = seal_override
            deepened = deepened.replace(
                f"body_seal: {evidence['new_seal']}\n",
                f"body_seal: {deepened_seal}\n",
                1,
            )
            plan.write_text(deepened, encoding="utf-8")
            message = "interactive plan deepening\n\n"
            if authorization is not None:
                message += f"{authorization}\n"
            run_git(repo, "add", source_plan)
            run_git(repo, "commit", "-qm", message)
            return repo

        # Authorized deepening must change both the body and its digest.
        deepening_repo = make_deepening_repo("interactive-deepening", INTERACTIVE_DEEPENING_MARKER)
        evaluate_later_history("interactive-deepening", deepening_repo, "accept")

        # A body change carrying a stale/wrong digest is not deepening.
        wrong_digest_repo = make_deepening_repo(
            "deepening-wrong-digest", INTERACTIVE_DEEPENING_MARKER, "e" * 64
        )
        evaluate_later_history("deepening-wrong-digest", wrong_digest_repo, "reject")

        # Missing and incorrect authorization are real commit mutations, not
        # policy-object substitutions, and must fail through the same history
        # verifier.
        missing_auth_repo = make_deepening_repo("deepening-missing-authorization", None)
        evaluate_later_history("deepening-missing-authorization", missing_auth_repo, "reject")
        wrong_auth_repo = make_deepening_repo(
            "deepening-wrong-authorization",
            f"{INTERACTIVE_DEEPENING_MARKER.split('=', 1)[0]}=fresh-approval-after-interruption",
        )
        evaluate_later_history("deepening-wrong-authorization", wrong_auth_repo, "reject")



    finally:
        shutil.rmtree(mutation_root, ignore_errors=True)


def adoption_evidence_deletions(rows: list[dict], cases: list[tuple[str, Path]], consumer: str) -> None:
    complete = dict(cases)["adoption-complete"]
    meta_path = complete.with_suffix(complete.suffix + ".adoption.json")
    original = json.loads(meta_path.read_text(encoding="utf-8"))
    diagnostic_names = {
        "approval": "approval",
        "baseline": "baseline commit",
        "plan_path": "plan path",
        "old_seal": "old seal",
        "new_seal": "new seal",
        "reproduction_command": "reproduction command",
    }
    required = tuple((field, diagnostic_names[field]) for field in adoption_policy["required_evidence"])
    for field, diagnostic in required:
        mutated = dict(original)
        mutated.pop(field, None)
        meta_path.write_text(json.dumps(mutated), encoding="utf-8")
        actual, detail = adoption_decision(complete, "adoption-complete", consumer)
        row = find_row(rows, f"adoption-missing-{field.replace('_', '-')}")
        if actual == "reject" and diagnostic in detail and row is not None:
            emit("PASS", f"deletion-evidence-{field}", f"independent missing-{field} mutation rejected:{detail}")
        else:
            emit("FAIL", f"deletion-evidence-{field}", f"missing field accepted or diagnostic drift: {actual}:{detail}")
        meta_path.write_text(json.dumps(original), encoding="utf-8")


def adoption_policy_mutations(cases: list[tuple[str, Path]], consumer: str) -> None:
    complete = dict(cases)["adoption-complete"]
    policy = adoption_policy
    mutations = {
        "required-evidence": lambda p: p["required_evidence"].pop(),
        "baseline-current-equality": lambda p: p.update(baseline_current_body="ignore"),
        "migration-commit-path": lambda p: p["migration_commit"].update(path="docs/plans/other.md"),
        "migration-commit-diff": lambda p: p["migration_commit"].update(diff="all-files"),
        "migration-commit-message-tuple": lambda p: p["migration_commit"].update(message_fields=["baseline"]),
        "migration-commit-command": lambda p: p["migration_commit"].update(command="approximate"),
        "migration-commit-approval": lambda p: p["migration_commit"].update(approval="implicit"),
        "later-reseal": lambda p: p.update(later_reseal="accept"),
        "interrupted-retry-compensation": lambda p: p["interrupted_retry"].update(compensation="all-files"),
        "interrupted-retry-fresh-approval": lambda p: p["interrupted_retry"].update(fresh_approval=False),
    }
    for name, mutate in mutations.items():
        mutated = json.loads(json.dumps(policy))
        mutate(mutated)
        actual, detail = adoption_decision(complete, "adoption-complete", consumer, mutated)
        if actual == "accept":
            emit("FAIL", f"operative-policy-mutation-{name}", "weakened adoption policy was accepted")
        else:
            emit("PASS", f"operative-policy-mutation-{name}", f"policy mutation rejected:{detail}")

def release_cases(directory: Path) -> list[tuple[str, Path]]:
    required = ("schema", "title", "type", "status", "date", "execution")
    base = {key: "plan/v1" if key == "schema" else "approved" if key == "status" else "code" if key == "execution" else "fixture" for key in required}
    cases: list[tuple[str, Path]] = []
    for field in required:
        missing = dict(base); missing.pop(field); cases.append((f"required-missing-{field}", write_plan(directory, f"required-missing-{field}.md", missing, "## Goal\n\nfixture")))
        empty = dict(base); empty[field] = ""; cases.append((f"required-empty-{field}", write_plan(directory, f"required-empty-{field}.md", empty, "## Goal\n\nfixture")))
    validators = directory / "validators"
    validators.mkdir(parents=True, exist_ok=True)
    for name, exit_code in (("exit0", 0), ("nonzero", 7)):
        validator = validators / f"validator-{name}.py"
        validator.write_text(f"#!/usr/bin/env python3\nimport sys\nsys.exit({exit_code})\n", encoding="utf-8")
        validator.chmod(0o755)
        plan = write_plan(directory, f"valid-validator-{name}.md", base, "## Goal\n\nfixture")
        plan.with_suffix(plan.suffix + ".meta.json").write_text(json.dumps({"validator_path": str(validator)}), encoding="utf-8")
        cases.append((f"valid-validator-{name}", plan))
    fallback = write_plan(directory, "valid-validator-fallback.md", base, "## Goal\n\nfixture")
    cases.append(("valid-validator-fallback", fallback))
    unknown = dict(base); unknown["schema"] = "plan/v9"; cases.append(("unknown-schema", write_plan(directory, "unknown-schema.md", unknown, "## Goal\n\nfixture")))
    draft = dict(base); draft["status"] = "draft"; cases.append(("non-approved-status", write_plan(directory, "non-approved-status.md", draft, "## Goal\n\nfixture")))
    return cases


def release_decision(path: Path) -> tuple[str, str]:
    fields, _ = parse_frontmatter(path)
    for field in ("schema", "title", "type", "status", "date", "execution"):
        if not fields.get(field, "").strip(): return "reject", field
    if fields["schema"] != "plan/v1": return "reject", "schema"
    if fields["status"] != "approved": return "reject", "status"
    meta_path = path.with_suffix(path.suffix + ".meta.json")
    if meta_path.exists():
        validator_path = json.loads(meta_path.read_text(encoding="utf-8"))["validator_path"]
        result = subprocess.run([validator_path, str(path)], capture_output=True, text=True)
        if result.returncode == 0:
            return "accept", "validator=available exit=0"
        return "reject", f"validator=available nonzero exit={result.returncode}"
    return "accept", "validator=fallback"


def run_git(repo: Path, *args: str) -> str:
    result = subprocess.run(["git", "-C", str(repo), *args], check=True, capture_output=True, text=True)
    return result.stdout.strip()


def commit_paths(repo: Path, commit: str) -> set[str]:
    return set(run_git(repo, "diff-tree", "--no-commit-id", "--name-only", "-r", commit).splitlines())


def retro_cases(directory: Path) -> list[tuple[str, Path]]:
    cases: list[tuple[str, Path]] = []
    specs = {
        "origin-repo-relative": {"origin": "docs/specs/design.md", "plans": [], "selection": "none"},
        "no-plan-no-flip": {"origin": "", "plans": [], "selection": "none"},
        "ledger-plan": {"origin": "docs/specs/design.md", "plans": [{"name": "ledger.md", "status": "approved", "first": "post", "landed": ""}], "ledger": "ledger.md", "git_mode": "together"},
        "body-cited-plan": {"origin": "docs/specs/design.md", "plans": [{"name": "cited.md", "status": "approved", "first": "post", "landed": ""}], "body_cites": ["cited.md"], "git_mode": "together"},
        "multi-plan": {"origin": "docs/specs/design.md", "plans": [{"name": "one.md", "status": "approved", "first": "post", "landed": ""}, {"name": "two.md", "status": "approved", "first": "post", "landed": ""}], "ledger": "one.md", "body_cites": ["two.md"], "tracker": "ROADMAP.md", "git_mode": "together"},
        "pre-contract": {"origin": "docs/specs/design.md", "plans": [{"name": "old.md", "status": "approved", "first": "pre", "landed": "base-old"}], "ledger": "old.md"},
        "non-approved": {"origin": "docs/specs/design.md", "plans": [{"name": "draft.md", "status": "draft", "first": "post", "landed": "base-draft"}], "ledger": "draft.md"},
        "missing-landed-commit": {"origin": "docs/specs/design.md", "plans": [{"name": "missing.md", "status": "approved", "first": "post", "landed": ""}], "ledger": "missing.md", "missing_landed": True},
        "split-commit": {"origin": "docs/specs/design.md", "plans": [{"name": "split.md", "status": "approved", "first": "post", "landed": ""}], "ledger": "split.md", "git_mode": "split"},
        "omission-commit": {"origin": "docs/specs/design.md", "plans": [{"name": "kept.md", "status": "approved", "first": "post", "landed": ""}, {"name": "omitted.md", "status": "approved", "first": "post", "landed": ""}], "ledger": "kept.md", "body_cites": ["omitted.md"], "git_mode": "omission"},
        "body-mutation": {"origin": "docs/specs/design.md", "plans": [{"name": "body.md", "status": "approved", "first": "post", "landed": ""}], "ledger": "body.md", "mutation": "body"},
        "dirty-worktree-body-mutation": {"origin": "docs/specs/design.md", "plans": [{"name": "dirty-body.md", "status": "approved", "first": "post", "landed": ""}], "ledger": "dirty-body.md", "mutation": "body", "dirty_worktree_restore": True},
        "other-frontmatter-mutation": {"origin": "docs/specs/design.md", "plans": [{"name": "frontmatter.md", "status": "approved", "first": "post", "landed": ""}], "ledger": "frontmatter.md", "mutation": "other-frontmatter"},
    }
    for name, spec in specs.items():
        case_dir = directory / name
        repo = case_dir / "repo"
        (repo / "docs/plans").mkdir(parents=True, exist_ok=True)
        (repo / "fixture.txt").write_text("base fixture\n", encoding="utf-8")
        run_git(repo, "init", "-q")
        run_git(repo, "config", "user.email", "fixture@example.invalid")
        run_git(repo, "config", "user.name", "Fixture")
        for plan in spec.get("plans", []):
            body = "## Goal\n\nfixture"
            fields = {
                "schema": "plan/v1",
                "title": plan["name"],
                "type": "fix",
                "status": plan["status"],
                "date": "2026-08-15",
                "execution": "code",
            }
            path = write_plan(repo / "docs/plans", plan["name"], fields, body)
            fields["body_seal"] = independent_body_seal(path.read_text(encoding="utf-8"))
            write_plan(repo / "docs/plans", plan["name"], fields, body)
        if spec.get("ledger"):
            (repo / ".release-loop").mkdir(parents=True, exist_ok=True)
            (repo / ".release-loop/progress.md").write_text(f"plan: {spec['ledger']}\n", encoding="utf-8")
        if spec.get("body_cites"):
            (repo / "retro-body.md").write_text("\n".join(f"Covers plan: {plan}" for plan in spec["body_cites"]) + "\n", encoding="utf-8")
        if spec.get("tracker"):
            (repo / spec["tracker"]).write_text("base tracker\n", encoding="utf-8")
        run_git(repo, "add", ".")
        run_git(repo, "commit", "-qm", "base fixture")
        base_commit = run_git(repo, "rev-parse", "HEAD")
        for plan in spec.get("plans", []):
            if plan["first"] == "post" and not plan["landed"] and not spec.get("missing_landed"):
                plan["landed"] = base_commit
        spec["base_commit"] = base_commit
        (case_dir / "case.json").write_text(json.dumps(spec), encoding="utf-8")
        cases.append((name, case_dir))
    return cases


def update_plan(repo: Path, name: str, landed: str, completed_by: str | None = None) -> None:
    path = repo / "docs/plans" / name
    fields, text = parse_frontmatter(path)
    fields = dict(fields)
    fields["status"] = "done"
    fields["completed_by"] = landed if completed_by is None else completed_by
    frontmatter = "\n".join(f"{key}: {value}" for key, value in fields.items())
    path.write_text(f"---\n{frontmatter}\n---{text.split('---', 2)[2]}", encoding="utf-8")


def mutate_transition_target(path: Path, mutation: str) -> None:
    before = path.read_text(encoding="utf-8")
    before_fields = parse_frontmatter_text(before)
    before_body = before.split("---", 2)[2]
    if mutation == "body":
        after = before.rstrip("\n") + "\n\nfixture body mutation\n"
    elif mutation == "other-frontmatter":
        fields = dict(before_fields)
        fields["date"] = "2099-12-31"
        frontmatter = "\n".join(f"{key}: {value}" for key, value in fields.items())
        after = f"---\n{frontmatter}\n---{before.split('---', 2)[2]}"
    else:
        raise ValueError(f"unknown transition mutation: {mutation}")
    after_fields = parse_frontmatter_text(after)
    after_body = after.split("---", 2)[2]
    if mutation == "body":
        if before_fields != after_fields or before_body == after_body:
            raise AssertionError("body mutation setup changed more than the plan body")
    elif set(before_fields) ^ set(after_fields) or {
        key for key in set(before_fields) | set(after_fields)
        if before_fields.get(key) != after_fields.get(key)
    } != {"date"} or before_body != after_body:
        raise AssertionError("frontmatter mutation setup changed more than date")
    path.write_text(after, encoding="utf-8")


def run_git_text(repo: Path, *args: str) -> str:
    result = subprocess.run(["git", "-C", str(repo), *args], check=True, capture_output=True, text=True)
    return result.stdout


def inspect_plan_transition(repo: Path, commit: str, name: str) -> tuple[bool, set[str]]:
    relative = f"docs/plans/{name}"
    parent = run_git(repo, "rev-parse", f"{commit}^")
    diff = run_git_text(repo, "diff", "--no-ext-diff", parent, commit, "--", relative)
    if not diff:
        return False, set()
    before = run_git_text(repo, "show", f"{parent}:{relative}")
    after = run_git_text(repo, "show", f"{commit}:{relative}")
    before_fields = parse_frontmatter_text(before)
    after_fields = parse_frontmatter_text(after)
    changed_fields = {
        key for key in set(before_fields) | set(after_fields)
        if before_fields.get(key) != after_fields.get(key)
    }
    return before.split("---", 2)[2] != after.split("---", 2)[2], changed_fields


def retro_history_mutations(cases: list[tuple[str, Path]]) -> None:
    source_case = dict(cases)["multi-plan"]
    mutation_root = Path(tempfile.mkdtemp(prefix="retro-history-mutations-"))

    try:
        def fresh(name: str) -> Path:
            destination = mutation_root / name
            shutil.copytree(source_case, destination)
            return destination

        def evaluate(name: str, expected: str, diagnostic: str, **overrides: object) -> None:
            case_dir = fresh(name)
            spec = json.loads((case_dir / "case.json").read_text(encoding="utf-8"))
            if overrides.pop("unrelated_completed_by", False):
                repo = case_dir / "repo"
                (repo / "unrelated-existing.txt").write_text("unrelated\n", encoding="utf-8")
                run_git(repo, "add", "unrelated-existing.txt")
                run_git(repo, "commit", "-qm", "unrelated existing commit")
                unrelated = run_git(repo, "rev-parse", "HEAD")
                spec["completed_by_override"] = {"one.md": unrelated}
            spec.update(overrides)
            (case_dir / "case.json").write_text(json.dumps(spec), encoding="utf-8")
            actual, detail = retro_decision(case_dir)
            if actual == expected and diagnostic in detail:
                emit("PASS", f"retro-history-{name}", f"{actual}:{detail}")
            else:
                emit(
                    "FAIL",
                    f"retro-history-{name}",
                    f"expected={expected}:{diagnostic} got={actual}:{detail}",
                )

        # A legal multi-plan terminal commit carries exactly one retro, both
        # sibling plan transitions, and only the modeled tracker update.
        evaluate("multi-plan-legal", "transition", "all-plans")
        evaluate("missing-retro", "reject", "retro", retro_count=0)
        evaluate("extra-retro", "reject", "retro", retro_count=2)
        evaluate(
            "sibling-body-mutation",
            "reject",
            "body",
            mutation="body",
            mutation_plan="two.md",
        )
        evaluate(
            "sibling-frontmatter-mutation",
            "reject",
            "frontmatter",
            mutation="other-frontmatter",
            mutation_plan="two.md",
        )
        evaluate("extra-tracker-artifact", "reject", "tracker", extra_tracker="UNMODELED.md")
        evaluate("unrelated-completed-by", "reject", "completed_by", unrelated_completed_by=True)
    finally:
        shutil.rmtree(mutation_root, ignore_errors=True)


def retro_decision(case_dir: Path) -> tuple[str, str]:
    spec = json.loads((case_dir / "case.json").read_text(encoding="utf-8"))
    repo = case_dir / "repo"
    if spec.get("origin") and not spec["origin"].startswith("docs/"):
        return "reject", "repo-relative origin"
    if spec.get("selection") == "none":
        return "accept" if spec.get("origin") else "no-flip", "repo-relative origin" if spec.get("origin") else "no-plan"
    selected: set[str] = set()
    progress = repo / ".release-loop/progress.md"
    if progress.exists():
        match = re.search(r"^plan:\s*(\S+)", progress.read_text(encoding="utf-8"), re.MULTILINE)
        if match:
            selected.add(Path(match.group(1)).name)
    body = repo / "retro-body.md"
    if body.exists():
        selected.update(re.findall(r"^Covers plan:\s*(\S+)", body.read_text(encoding="utf-8"), re.MULTILINE))
    plans = {plan["name"]: plan for plan in spec.get("plans", [])}
    for name in selected:
        plan = plans.get(name)
        if plan is None:
            return "reject", "all-plans"
        if plan["first"] != "post":
            return "no-flip", "pre-contract"
        if plan["status"] != "approved":
            return "no-flip", "non-approved"
        if not plan["landed"]:
            return "reject", "completed_by"
        try:
            run_git(repo, "cat-file", "-e", f"{plan['landed']}^{{commit}}")
        except subprocess.CalledProcessError:
            return "reject", "completed_by"
    if not selected:
        return "no-flip", "no-plan"
    retro_rel = "docs/retros/fixture.md"
    tracker_rel = spec.get("tracker")
    required_paths = {retro_rel} | {f"docs/plans/{name}" for name in selected}
    if tracker_rel:
        required_paths.add(tracker_rel)

    def completed_by_for(name: str) -> str:
        overrides = spec.get("completed_by_override", {})
        if isinstance(overrides, dict) and name in overrides:
            return str(overrides[name])
        return str(plans[name]["landed"])

    mode = spec.get("git_mode", "together")
    retro_path = repo / retro_rel
    retro_path.parent.mkdir(parents=True, exist_ok=True)
    if mode == "split":
        retro_path.write_text("retro fixture\n", encoding="utf-8")
        run_git(repo, "add", retro_rel)
        run_git(repo, "commit", "-qm", "retro document")
        retro_commit = run_git(repo, "rev-parse", "HEAD")
        for name in selected:
            update_plan(repo, name, plans[name]["landed"], completed_by_for(name))
        transition_paths = [f"docs/plans/{name}" for name in selected]
        run_git(repo, "add", *transition_paths)
        transition_commit = run_git(repo, "commit", "-qm", "plan transition")
        if retro_commit != transition_commit:
            return "reject", "same-commit"
        return "reject", "same-commit"
    if mode == "omission":
        retro_path.write_text("retro fixture\n", encoding="utf-8")
        ordered = sorted(selected)
        update_plan(repo, ordered[0], plans[ordered[0]]["landed"], completed_by_for(ordered[0]))
        first_paths = [retro_rel, f"docs/plans/{ordered[0]}"]
        run_git(repo, "add", *first_paths)
        run_git(repo, "commit", "-qm", "retro with omitted plan")
        retro_commit = run_git(repo, "rev-parse", "HEAD")
        first_commit_paths = commit_paths(repo, retro_commit)
        for name in ordered[1:]:
            update_plan(repo, name, plans[name]["landed"], completed_by_for(name))
        run_git(repo, "add", *[f"docs/plans/{name}" for name in ordered[1:]])
        run_git(repo, "commit", "-qm", "omitted plan transition")
        if not required_paths.issubset(first_commit_paths):
            return "reject", "all-plans"
        return "reject", "all-plans"
    retro_count = int(spec.get("retro_count", 1))
    if retro_count > 0:
        retro_path.write_text("retro fixture\n", encoding="utf-8")
    if retro_count > 1:
        (repo / "docs/retros/extra.md").write_text("extra retro fixture\n", encoding="utf-8")
    for name in selected:
        update_plan(repo, name, plans[name]["landed"], completed_by_for(name))
        mutation = spec.get("mutation")
        mutation_plan = spec.get("mutation_plan")
        if mutation and (not mutation_plan or mutation_plan == name):
            mutate_transition_target(repo / "docs/plans" / name, mutation)
    if tracker_rel:
        with (repo / tracker_rel).open("a", encoding="utf-8") as tracker:
            tracker.write("retro update\n")
    extra_tracker = spec.get("extra_tracker")
    if extra_tracker:
        extra_tracker_path = repo / str(extra_tracker)
        extra_tracker_path.parent.mkdir(parents=True, exist_ok=True)
        extra_tracker_path.write_text("unmodeled tracker\n", encoding="utf-8")
    add_paths = [path for path in sorted(required_paths) if (repo / path).exists()]
    if retro_count > 1:
        add_paths.append("docs/retros/extra.md")
    if extra_tracker:
        add_paths.append(str(extra_tracker))
    run_git(repo, "add", *add_paths)
    run_git(repo, "commit", "-qm", "retro and plan transitions")
    commit = run_git(repo, "rev-parse", "HEAD")
    if spec.get("dirty_worktree_restore"):
        parent = run_git(repo, "rev-parse", f"{commit}^")
        for name in selected:
            run_git(repo, "restore", "--source", parent, "--", f"docs/plans/{name}")
    parent_commit = run_git(repo, "rev-parse", f"{commit}^")
    for name in selected:
        body_changed, changed_fields = inspect_plan_transition(repo, commit, name)
        unexpected_fields = changed_fields - {"status", "completed_by"}
        parent_text = run_git_text(repo, "show", f"{parent_commit}:docs/plans/{name}")
        parent_fields = parse_frontmatter_text(parent_text)
        committed_text = run_git_text(repo, "show", f"{commit}:docs/plans/{name}")
        committed_fields = parse_frontmatter_text(committed_text)
        if parent_fields.get("status") != "approved" or committed_fields.get("status") != "done":
            return "reject", "status"
        if committed_fields.get("completed_by") != str(plans[name]["landed"]):
            return "reject", "completed_by"
        if body_changed:
            return "reject", "body"
        if unexpected_fields:
            return "reject", f"frontmatter {','.join(sorted(unexpected_fields))}"
    changed_paths = commit_paths(repo, commit)
    retro_paths = {
        path
        for path in changed_paths
        if Path(path).parts[:2] == ("docs", "retros") and path.endswith(".md")
    }
    if retro_paths != {retro_rel}:
        return "reject", "retro"
    try:
        if not run_git_text(repo, "show", f"{commit}:{retro_rel}").strip():
            return "reject", "retro"
    except subprocess.CalledProcessError:
        return "reject", "retro"
    if changed_paths - required_paths:
        return "reject", "tracker"
    if changed_paths != required_paths:
        return "reject", "all-plans"
    return "transition", "all-plans same-commit"


def diagnostic_matches(row: dict, path: Path, fixture: str, detail: str) -> bool:
    expected = row["diagnostic"]
    if consumer == "implementing":
        fields, text = parse_frontmatter(path)
        if fixture == "status-done":
            token = f"completed_by={fields.get('completed_by', '')}"
            return bool(fields.get("completed_by")) and expected == token and detail == token
        if fixture == "status-superseded":
            token = f"superseded_by={fields.get('superseded_by', '')}"
            return bool(fields.get("superseded_by")) and expected == token and detail == token
        if fixture in {"seal-malformed", "seal-mismatch"}:
            current = fields.get("body_seal", "")
            computed = body_seal(text)
            return expected == "stored= computed=" and detail == f"stored={current} computed={computed}"
    return not expected or expected in detail


def evaluate_cases(rows: list[dict], cases: list[tuple[str, Path]], decision_fn) -> None:
    for fixture, path in cases:
        row = find_row(rows, fixture)
        if row is None:
            emit("FAIL", fixture, "contract row missing")
            continue
        actual, detail = decision_fn(path, fixture) if consumer == "implementing" else decision_fn(path)
        if actual != row["expected"] or not diagnostic_matches(row, path, fixture, detail):
            emit("FAIL", fixture, f"expected={row['expected']} diagnostic={row['diagnostic']} got={actual}:{detail}")
        else:
            emit("PASS", fixture, f"{actual}:{detail}")


def diagnostic_mutations(rows: list[dict], cases: list[tuple[str, Path]], decision_fn) -> None:
    if consumer != "implementing":
        return
    requirements = {
        "status-done": ("completed_by=",),
        "status-superseded": ("superseded_by=",),
        "seal-malformed": ("stored=", "computed="),
        "seal-mismatch": ("stored=", "computed="),
    }
    case_map = dict(cases)
    for fixture, tokens in requirements.items():
        row = find_row(rows, fixture)
        path = case_map.get(fixture)
        if row is None or path is None:
            emit("FAIL", f"diagnostic-{fixture}", "required fixture or contract row missing")
            continue
        actual, detail = decision_fn(path, fixture)
        if actual != "reject":
            emit("FAIL", f"diagnostic-{fixture}", f"fixture unexpectedly returned {actual}")
            continue
        for token in tokens:
            if row["diagnostic"].count(token) != 1:
                emit("FAIL", f"diagnostic-{fixture}-missing-{token.rstrip('=')}", "mutation setup expected exactly one token")
                continue
            mutated = dict(row)
            mutated["diagnostic"] = row["diagnostic"].replace(token, "", 1)
            if mutated["diagnostic"] == row["diagnostic"]:
                emit("FAIL", f"diagnostic-{fixture}-missing-{token.rstrip('=')}", "mutation setup made no change")
            elif diagnostic_matches(mutated, path, fixture, detail):
                emit("FAIL", f"diagnostic-{fixture}-missing-{token.rstrip('=')}", "missing-token mutation was accepted")
            else:
                emit("PASS", f"diagnostic-{fixture}-missing-{token.rstrip('=')}", "missing-token mutation rejected")


def deletion_mutations(rows: list[dict], cases: list[tuple[str, Path]]) -> None:
    source = skill_path.read_text(encoding="utf-8")
    for row in rows:
        if row["decision"] == "literal":
            continue
        fixture = row["fixture"]
        needle = json.dumps(row, sort_keys=True)
        # JSON formatting in the source is not canonical; target the fixture key
        # and require exactly one operative row before deleting it.
        target = re.compile(r'"fixture"\s*:\s*"' + re.escape(fixture) + r'"')
        matching = [line for line in source.splitlines(keepends=True) if target.search(line)]
        if len(matching) != 1:
            emit("FAIL", f"deletion-{fixture}", f"mutation setup changed {len(matching)} rows, expected exactly 1")
            continue
        mutated = source.replace(matching[0], "", 1)
        if mutated == source:
            emit("FAIL", f"deletion-{fixture}", "mutation setup made no change")
            continue
        with tempfile.NamedTemporaryFile("w", encoding="utf-8", suffix=".md") as handle:
            handle.write(mutated)
            handle.flush()
            mutated_rows, error = parse_contract(Path(handle.name))
        if error or find_row(mutated_rows, fixture) is not None:
            emit("FAIL", f"deletion-{fixture}", "deleted rule remained parseable")
        else:
            emit("PASS", f"deletion-{fixture}", "missing contract row rejected")


def compare_shared_rows(rows: list[dict], consumer_name: str, expected: dict[str, str]) -> list[tuple[str, str, str]]:
    del consumer_name
    mismatches: list[tuple[str, str, str]] = []
    literal_rows = [row for row in rows if row["decision"] == "literal"]
    actual_fields = {row["fixture"] for row in literal_rows}
    for field in sorted(actual_fields | set(expected)):
        matches = [row for row in literal_rows if row["fixture"] == field]
        if field not in expected:
            actual = matches[0]["expected"] if len(matches) == 1 else "<duplicate>"
            mismatches.append((field, actual, "<unexpected>"))
        elif not matches:
            mismatches.append((field, "<missing>", expected[field]))
        elif len(matches) != 1:
            mismatches.append((field, "<duplicate>", expected[field]))
        elif matches[0]["expected"] != expected[field]:
            mismatches.append((field, matches[0]["expected"], expected[field]))
    return mismatches


def shared_literals(path: Path, fixture: Path) -> None:
    schema_path = fixture / "skills/planning/schemas/plan-schema.md"
    if not schema_path.exists():
        schema_path = fixture / "schemas/plan-schema.md"
    if not schema_path.exists():
        emit("FAIL", "shared-ssot", "missing planning schema in both moved and pre-move locations")
        return
    schema_text = schema_path.read_text(encoding="utf-8")
    required = [match.group(1) for match in re.finditer(r"^([a-z_]+): .+$", schema_text, re.MULTILINE) if match.group(1) in {"schema", "title", "type", "status", "date", "execution"}]
    schema_version = re.search(r"^schema:\s+(plan/v1)\s+#", schema_text, re.MULTILINE).group(1)
    statuses = re.search(r"^status:\s+([^#]+?)\s+#", schema_text, re.MULTILINE).group(1).strip()
    seal_format = re.search(r"^body_seal:\s+<([^>]+)>\s+#", schema_text, re.MULTILINE).group(1).strip()
    extraction = re.search(r"text\.split\('---', 2\)\[2\]", schema_text).group(0)
    expected = {
        "implementing": {"schema": schema_version, "statuses": statuses, "seal-format": seal_format, "seal-extraction": extraction},
        "release-loop": {"required-fields": ",".join(required), "schema": schema_version, "approved-status": "approved"},
        "retrospective": {},
    }[consumer]
    rows, error = parse_contract(path)
    if error:
        emit("FAIL", "shared-contract", error)
        return
    live_mismatches = compare_shared_rows(rows, consumer, expected)
    if live_mismatches:
        for field, actual, value in live_mismatches:
            emit("FAIL", f"shared-{field}", f"DRIFT consumer={consumer} field={field} actual={actual} expected={value}")
    else:
        for field in sorted(expected):
            emit("PASS", f"shared-{field}", "matches sibling SSOT")
    for field, value in expected.items():
        matches = [row for row in rows if row["decision"] == "literal" and row["fixture"] == field]
        if len(matches) != 1:
            emit("FAIL", f"drift-{field}", f"mutation setup changed {len(matches)} rows, expected exactly 1")
            continue
        removed_rows = [
            row for row in rows
            if not (row["decision"] == "literal" and row["fixture"] == field)
        ]
        if len(rows) - len(removed_rows) != 1:
            emit("FAIL", f"drift-missing-{field}", "mutation setup changed more than the target literal")
        else:
            missing_mismatches = compare_shared_rows(removed_rows, consumer, expected)
            expected_missing = [(field, "<missing>", value)]
            if missing_mismatches != expected_missing:
                detail = missing_mismatches[0] if missing_mismatches else ("<none>", "<none>", value)
                emit("FAIL", f"drift-missing-{field}", f"DRIFT consumer={consumer} field={detail[0]} actual={detail[1]} expected={detail[2]}")
            else:
                emit("PASS", f"drift-missing-{field}", f"DRIFT consumer={consumer} field={field} actual=<missing> expected={value}")
        mutated_rows = [dict(row) for row in rows]
        changed = 0
        for mutated in mutated_rows:
            if mutated["decision"] == "literal" and mutated["fixture"] == field:
                mutated["expected"] = "drift"
                changed += 1
        if changed != 1:
            emit("FAIL", f"drift-{field}", f"mutation setup changed {changed} rows, expected exactly 1")
            continue
        mismatches = compare_shared_rows(mutated_rows, consumer, expected)
        expected_mismatch = [(field, "drift", value)]
        if mismatches != expected_mismatch:
            detail = mismatches[0] if mismatches else ("<none>", "<none>", value)
            emit("FAIL", f"drift-{field}", f"DRIFT consumer={consumer} field={detail[0]} actual={detail[1]} expected={detail[2]}")
        else:
            emit("PASS", f"drift-{field}", f"DRIFT consumer={consumer} field={field} actual=drift expected={value}")
    if consumer in {"release-loop", "retrospective"}:
        forbidden = {
            "decision": "literal",
            "fixture": "statuses",
            "expected": "draft | approved | done | superseded",
            "diagnostic": "",
        }
        injected_rows = [dict(row) for row in rows] + [forbidden]
        original_keys = {row["fixture"] for row in rows if row["decision"] == "literal"}
        injected_keys = {row["fixture"] for row in injected_rows if row["decision"] == "literal"}
        if injected_keys - original_keys != {"statuses"}:
            emit("FAIL", "drift-unexpected-statuses", "mutation setup changed more than the forbidden literal key")
        else:
            unexpected_mismatches = compare_shared_rows(injected_rows, consumer, expected)
            expected_unexpected = [("statuses", forbidden["expected"], "<unexpected>")]
            if unexpected_mismatches != expected_unexpected:
                detail = unexpected_mismatches[0] if unexpected_mismatches else ("<none>", "<none>", "<unexpected>")
                emit("FAIL", "drift-unexpected-statuses", f"DRIFT consumer={consumer} field={detail[0]} actual={detail[1]} expected={detail[2]}")
            else:
                emit("PASS", "drift-unexpected-statuses", f"DRIFT consumer={consumer} field=statuses actual={forbidden['expected']} expected=<unexpected>")
    if not expected:
        emit("PASS", "shared-subset", "retrospective carries no full-schema literal copy")


if mode == "fixtures":
    rows, error = parse_contract(skill_path)
    if error:
        emit("FAIL", "contract", error)
    else:
        if consumer == "implementing":
            cases = implementing_cases(root / "implementing")
            diagnostic_mutations(rows, cases, implementing_decision)
        elif consumer == "release-loop":
            cases = release_cases(root / "release-loop")
            evaluate_cases(rows, cases, release_decision)
        elif consumer == "retrospective":
            cases = retro_cases(root / "retrospective")
            retro_history_mutations(cases)
            evaluate_cases(rows, cases, lambda path: retro_decision(path))
        else:
            emit("FAIL", "consumer", "unknown consumer")
        if not error:
            deletion_mutations(rows, cases)
elif mode == "adoption":
    rows, error = parse_contract(skill_path)
    if error:
        emit("FAIL", "adoption-policy/missing", error)
    else:
        cases = adoption_cases(root / "adoption", consumer)
        adoption_policy_mutations(cases, consumer)
        evaluate_adoption_cases(rows, cases, consumer)
        adoption_evidence_deletions(rows, cases, consumer)
        deletion_mutations(rows, cases)
elif mode == "shared":
    shared_literals(skill_path, root)
else:
    emit("FAIL", "harness-mode", mode)

raise SystemExit(1 if failures else 0)
PY
  rc=$?
  record_results "$result_file"
  rm -f "$result_file"
  return "$rc"
}

# --- Fixture A: standalone consumers without skills/planning/ ---
echo "Fixture A: executable standalone consumer contracts"
fixture="$(copy_consumers)"
if [ -d "$fixture/skills/planning" ]; then
  fail "standalone fixture omits skills/planning/"
else
  pass "standalone fixture omits skills/planning/"
fi
for consumer in implementing release-loop retrospective; do
  file="$fixture/skills/$consumer/SKILL.md"
  if grep -Fq -- 'schemas/plan-schema.md' "$file"; then
    fail "$consumer has no load-bearing root schema reference"
  else
    pass "$consumer has no load-bearing root schema reference"
  fi
  if run_engine fixtures "$consumer" "$file" "$fixture/fixtures"; then
    pass "$consumer executable decision fixtures"
  else
    fail "$consumer executable decision fixtures"
  fi
done
rm -rf "$fixture"

# --- Fixture C: complete one-time adoption branch ----------------------------
echo "Fixture C: baseline-proven adoption acceptance and rejection branches"
fixture="$(copy_consumers)"
for consumer in implementing reviewing; do
  file="$fixture/skills/$consumer/SKILL.md"
  if run_engine adoption "$consumer" "$file" "$fixture/fixtures"; then
    pass "$consumer complete adoption branch and invalid evidence branches"
  else
    fail "$consumer complete adoption branch and invalid evidence branches"
  fi
done
rm -rf "$fixture"

# --- Fixture B: sibling SSOT parity and pre-move fallback ---
echo "Fixture B: consumer-subset parity with pre-/post-move fallback"
fixture="$(copy_consumers)"
ssot=""
if [ -f "$ROOT/skills/planning/schemas/plan-schema.md" ]; then
  ssot="$ROOT/skills/planning/schemas/plan-schema.md"
elif [ -f "$ROOT/schemas/plan-schema.md" ]; then
  ssot="$ROOT/schemas/plan-schema.md"
fi
if [ -z "$ssot" ]; then
  fail "shared SSOT fallback finds skills/planning/schemas/plan-schema.md or schemas/plan-schema.md"
else
  mkdir -p "$fixture/skills/planning/schemas"
  cp "$ssot" "$fixture/skills/planning/schemas/plan-schema.md"
  for consumer in implementing release-loop retrospective; do
    if run_engine shared "$consumer" "$fixture/skills/$consumer/SKILL.md" "$fixture"; then
      pass "$consumer shared subset matches moved sibling SSOT"
    else
      fail "$consumer shared subset matches moved sibling SSOT"
    fi
  done
  rm -rf "$fixture/skills/planning"
  mkdir -p "$fixture/schemas"
  cp "$ssot" "$fixture/schemas/plan-schema.md"
  if run_engine shared implementing "$fixture/skills/implementing/SKILL.md" "$fixture" && \
     run_engine shared release-loop "$fixture/skills/release-loop/SKILL.md" "$fixture" && \
     run_engine shared retrospective "$fixture/skills/retrospective/SKILL.md" "$fixture"; then
    pass "all consumer subsets match pre-move root SSOT fallback"
  else
    fail "all consumer subsets match pre-move root SSOT fallback"
  fi
fi
rm -rf "$fixture"

echo "Summary: $PASS_COUNT passed, $FAIL_COUNT failed"
if [ "$FAIL_COUNT" -ne 0 ]; then
  exit 1
fi
exit 0
