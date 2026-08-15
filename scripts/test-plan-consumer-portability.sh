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
  mkdir -p "$d/skills/implementing" "$d/skills/release-loop" "$d/skills/retrospective"
  cp "$ROOT/skills/implementing/SKILL.md" "$d/skills/implementing/SKILL.md"
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
failures = 0


def emit(state: str, name: str, detail: str = "") -> None:
    global failures
    if state == "FAIL":
        failures += 1
    print("|".join((state, consumer, name, detail)))


def parse_contract(path: Path) -> tuple[list[dict], str | None]:
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
        if stripped.startswith("```"):
            in_fence = not in_fence
            continue
        if in_fence and stripped.startswith("{"):
            try:
                row = json.loads(stripped)
            except json.JSONDecodeError as exc:
                return [], f"invalid JSON contract row: {exc}"
            if not all(key in row for key in ("decision", "fixture", "expected", "diagnostic")):
                return [], "contract row missing decision/fixture/expected/diagnostic"
            rows.append(row)
    if not rows:
        return [], "operative contract block has no rows"
    return rows, None


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


def make_sealed_plan(directory: Path, name: str, fields: dict[str, str], body: str, history: dict | None = None) -> Path:
    path = write_plan(directory, name, fields, body, history)
    fields = dict(fields)
    fields["body_seal"] = body_seal(path.read_text(encoding="utf-8"))
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
        "body-mutation": {"origin": "docs/specs/design.md", "plans": [{"name": "body.md", "status": "approved", "first": "post", "landed": "base-body"}], "ledger": "body.md", "mutation": "body"},
        "dirty-worktree-body-mutation": {"origin": "docs/specs/design.md", "plans": [{"name": "dirty-body.md", "status": "approved", "first": "post", "landed": "base-dirty-body"}], "ledger": "dirty-body.md", "mutation": "body", "dirty_worktree_restore": True},
        "other-frontmatter-mutation": {"origin": "docs/specs/design.md", "plans": [{"name": "frontmatter.md", "status": "approved", "first": "post", "landed": "base-frontmatter"}], "ledger": "frontmatter.md", "mutation": "other-frontmatter"},
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
            write_plan(repo / "docs/plans", plan["name"], {"schema": "plan/v1", "title": plan["name"], "type": "fix", "status": plan["status"], "date": "2026-08-15", "execution": "code"}, "## Goal\n\nfixture")
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


def update_plan(repo: Path, name: str, landed: str) -> None:
    path = repo / "docs/plans" / name
    fields, text = parse_frontmatter(path)
    fields = dict(fields)
    fields["status"] = "done"
    fields["completed_by"] = landed
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
        plan = plans[name]
        if plan["first"] != "post": return "no-flip", "pre-contract"
        if plan["status"] != "approved": return "no-flip", "non-approved"
        if not plan["landed"]: return "reject", "completed_by"
    if not selected:
        return "no-flip", "no-plan"
    retro_rel = "docs/retros/fixture.md"
    tracker_rel = spec.get("tracker")
    required_paths = {retro_rel} | {f"docs/plans/{name}" for name in selected}
    if tracker_rel:
        required_paths.add(tracker_rel)
    mode = spec.get("git_mode", "together")
    retro_path = repo / retro_rel
    retro_path.parent.mkdir(parents=True, exist_ok=True)
    if mode == "split":
        retro_path.write_text("retro fixture\n", encoding="utf-8")
        run_git(repo, "add", retro_rel)
        run_git(repo, "commit", "-qm", "retro document")
        retro_commit = run_git(repo, "rev-parse", "HEAD")
        for name in selected:
            update_plan(repo, name, plans[name]["landed"])
        transition_paths = [f"docs/plans/{name}" for name in selected]
        run_git(repo, "add", *transition_paths)
        transition_commit = run_git(repo, "commit", "-qm", "plan transition")
        if retro_commit != transition_commit:
            return "reject", "same-commit"
        return "reject", "same-commit"
    if mode == "omission":
        ordered = sorted(selected)
        retro_path.write_text("retro fixture\n", encoding="utf-8")
        update_plan(repo, ordered[0], plans[ordered[0]]["landed"])
        first_paths = [retro_rel, f"docs/plans/{ordered[0]}"]
        run_git(repo, "add", *first_paths)
        run_git(repo, "commit", "-qm", "retro with omitted plan")
        retro_commit = run_git(repo, "rev-parse", "HEAD")
        first_commit_paths = commit_paths(repo, retro_commit)
        for name in ordered[1:]:
            update_plan(repo, name, plans[name]["landed"])
        run_git(repo, "add", *[f"docs/plans/{name}" for name in ordered[1:]])
        run_git(repo, "commit", "-qm", "omitted plan transition")
        if not required_paths.issubset(first_commit_paths):
            return "reject", "all-plans"
        return "reject", "all-plans"
    retro_path.write_text("retro fixture\n", encoding="utf-8")
    for name in selected:
        update_plan(repo, name, plans[name]["landed"])
        if spec.get("mutation"):
            mutate_transition_target(repo / "docs/plans" / name, spec["mutation"])
    if tracker_rel:
        with (repo / tracker_rel).open("a", encoding="utf-8") as tracker:
            tracker.write("retro update\n")
    run_git(repo, "add", *sorted(required_paths))
    run_git(repo, "commit", "-qm", "retro and plan transitions")
    commit = run_git(repo, "rev-parse", "HEAD")
    if spec.get("dirty_worktree_restore"):
        parent = run_git(repo, "rev-parse", f"{commit}^")
        for name in selected:
            run_git(repo, "restore", "--source", parent, "--", f"docs/plans/{name}")
    for name in selected:
        body_changed, changed_fields = inspect_plan_transition(repo, commit, name)
        unexpected_fields = changed_fields - {"status", "completed_by"}
        if body_changed:
            return "reject", "body"
        if unexpected_fields:
            return "reject", f"frontmatter {','.join(sorted(unexpected_fields))}"
    changed_paths = commit_paths(repo, commit)
    if not required_paths.issubset(changed_paths):
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
            evaluate_cases(rows, cases, implementing_decision)
            diagnostic_mutations(rows, cases, implementing_decision)
        elif consumer == "release-loop":
            cases = release_cases(root / "release-loop")
            evaluate_cases(rows, cases, release_decision)
        elif consumer == "retrospective":
            cases = retro_cases(root / "retrospective")
            evaluate_cases(rows, cases, lambda path: retro_decision(path))
        else:
            emit("FAIL", "consumer", "unknown consumer")
        if not error:
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
