"""Validate a docs/plans/ plan's frontmatter against schemas/plan-schema.md.

Usage:
    python3 validate-plan-frontmatter.py <plan-path>

Exit codes:
    0 — frontmatter passes all checks
    1 — validation failure (diagnostics on stderr)
    2 — usage error (bad arguments, missing file)

Scope: this script checks two things, both required by schemas/plan-schema.md
(the `## Status lifecycle` section) and skills/planning/SKILL.md:

  1. Parser-safety — frontmatter that a strict YAML parser would silently
     misread (malformed `---` delimiters, unquoted ` #` or `: ` inside a
     scalar value). Ported from compound-engineering's validator via
     skills/compound/scripts/validate-frontmatter.py.
  2. Schema conformance — the required-keys / enum / terminal-state-evidence
     rules in schemas/plan-schema.md: `schema` pins `plan/v1`; `type`,
     `status`, `execution` map to known enums; `date` matches YYYY-MM-DD;
     `status: done` requires non-empty `completed_by`; `status: superseded`
     requires `superseded_by` resolving to an existing file; `origin`, when
     present, resolves to an existing file. Unknown fields are always valid.

Path resolution for `superseded_by:` / `origin:` is repo-root-relative, where
the root is derived by ascending from the plan file's directory to the
nearest ancestor containing a `docs/` directory, falling back to the current
working directory when no ancestor qualifies — independent of the caller's
CWD (schemas/plan-schema.md).

This is a hand-rolled frontmatter reader, not a YAML parser — it only
understands the subset of YAML this schema uses (top-level scalars and
simple `- item` lists under a key). Pure stdlib, no PyYAML or other deps.
"""
from __future__ import annotations

import os
import re
import sys

TYPES = {"feat", "fix", "refactor", "chore", "docs"}
STATUSES = {"draft", "approved", "done", "superseded"}
EXECUTIONS = {"code", "non-code", "ops"}
REQUIRED = ["schema", "title", "type", "status", "date", "execution"]
DATE_RE = re.compile(r"^\d{4}-\d{2}-\d{2}$")


def usage_fail(msg: str) -> "NoReturn":
    sys.stderr.write(f"validate-plan-frontmatter: {msg}\n")
    sys.exit(2)


def extract_frontmatter(text: str) -> list[str]:
    """Return the frontmatter lines (between the two '---' delimiters), or
    raise ValueError with a diagnostic message if the delimiters are malformed."""
    lines = text.split("\n")
    if not lines or lines[0].rstrip() != "---":
        raise ValueError("file does not start with '---' frontmatter delimiter line")

    end_idx = None
    for i in range(1, len(lines)):
        if lines[i].rstrip() == "---":
            end_idx = i
            break
    if end_idx is None:
        raise ValueError("frontmatter not closed (no '---' line after the opening delimiter)")

    return lines[1:end_idx]


def parse_frontmatter(fm_lines: list[str]) -> dict:
    """Minimal top-level-key / list-value parser. Scalars are unquoted in
    the returned dict; list values become a list of unquoted strings."""
    data: dict = {}
    current_key = None
    for line in fm_lines:
        stripped = line.lstrip()
        if not stripped or stripped.startswith("#"):
            continue
        if line.startswith((" ", "\t")):
            if stripped.startswith("- ") and current_key is not None:
                item = stripped[2:].strip()
                item = _unquote(item)
                existing = data.get(current_key)
                if isinstance(existing, list):
                    existing.append(item)
                else:
                    data[current_key] = [item]
            continue
        if ":" not in line:
            continue
        key, _, val = line.partition(":")
        key = key.strip()
        val = val.strip()
        current_key = key
        if val:
            data[key] = _unquote(val)
        else:
            data[key] = []  # placeholder; filled by subsequent "- item" lines if any
    return data


def _unquote(val: str) -> str:
    if len(val) >= 2 and val[0] == val[-1] and val[0] in "\"'":
        return val[1:-1]
    return val


def check_parser_safety(fm_lines: list[str]) -> list[str]:
    """Port of compound-engineering's silent-corruption checks: unquoted
    ' #' (comment truncation) and ': ' (mapping confusion) in a top-level
    scalar value."""
    issues = []
    for lineno, line in enumerate(fm_lines, start=2):
        stripped = line.lstrip()
        if not stripped or stripped.startswith("#"):
            continue
        if ":" not in line or line.startswith((" ", "\t")):
            continue
        if stripped.startswith("- "):
            continue
        key, _, val = line.partition(":")
        val_stripped = val.strip()
        if not val_stripped:
            continue
        if val_stripped[0] in "\"'[{|>":
            continue
        if re.search(r"\s#", val_stripped):
            issues.append(
                f"line {lineno}: '{key.strip()}' value contains ' #' — quote it. "
                "YAML treats space-then-# as a comment delimiter and silently "
                "drops the rest of the value."
            )
        if re.search(r":\s", val_stripped):
            issues.append(
                f"line {lineno}: '{key.strip()}' value contains ': ' — quote it. "
                "Strict YAML parsers may treat this as a nested mapping."
            )
    return issues


def find_repo_root(start_dir: str) -> "str | None":
    """Ascend from start_dir to the nearest ancestor containing a docs/
    directory. Returns None if no ancestor qualifies."""
    current = os.path.abspath(start_dir)
    while True:
        if os.path.isdir(os.path.join(current, "docs")):
            return current
        parent = os.path.dirname(current)
        if parent == current:
            return None
        current = parent


def check_schema(data: dict, repo_root: str) -> list[str]:
    issues = []
    for field in REQUIRED:
        if not data.get(field):
            issues.append(f"missing required field: '{field}'")

    def scalar(key: str) -> "str | None":
        """Return data[key] if it's a plain string; otherwise record a
        'must be scalar' issue (e.g. a YAML list value) and return None so
        callers skip enum/regex/path checks on it."""
        val = data.get(key)
        if val is not None and not isinstance(val, str):
            issues.append(f"'{key}' must be a scalar value, not a list")
            return None
        return val

    schema_val = scalar("schema")
    if schema_val and schema_val != "plan/v1":
        issues.append(f"'schema' value '{schema_val}' is not 'plan/v1'")

    type_val = scalar("type")
    if type_val and type_val not in TYPES:
        issues.append(f"'type' value '{type_val}' is not one of: {sorted(TYPES)}")

    status_val = scalar("status")
    if status_val and status_val not in STATUSES:
        issues.append(f"'status' value '{status_val}' is not one of: {sorted(STATUSES)}")

    execution_val = scalar("execution")
    if execution_val and execution_val not in EXECUTIONS:
        issues.append(f"'execution' value '{execution_val}' is not one of: {sorted(EXECUTIONS)}")

    date_val = scalar("date")
    if date_val and not DATE_RE.match(date_val):
        issues.append(f"'date' value '{date_val}' does not match YYYY-MM-DD")

    if status_val == "done":
        completed_by = scalar("completed_by")
        if not completed_by:
            issues.append("status 'done' requires a non-empty 'completed_by'")

    if status_val == "superseded":
        superseded_by = scalar("superseded_by")
        if not superseded_by:
            issues.append("status 'superseded' requires a non-empty 'superseded_by'")
        elif not os.path.isfile(os.path.join(repo_root, superseded_by)):
            issues.append(
                f"'superseded_by' value '{superseded_by}' does not resolve to an existing file"
            )

    origin_val = scalar("origin")
    if origin_val and not os.path.isfile(os.path.join(repo_root, origin_val)):
        issues.append(f"'origin' value '{origin_val}' does not resolve to an existing file")

    body_seal_val = scalar("body_seal")
    if body_seal_val and not re.fullmatch(r"[0-9a-f]{64}", body_seal_val):
        issues.append(
            f"'body_seal' value '{body_seal_val}' is not a valid 64-char lowercase hex SHA-256"
        )

    return issues


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        usage_fail(f"usage: {os.path.basename(argv[0])} <plan-path>")

    plan_path = argv[1]
    if not os.path.isfile(plan_path):
        usage_fail(f"file not found: {plan_path}")

    with open(plan_path) as f:
        text = f.read()

    try:
        fm_lines = extract_frontmatter(text)
    except ValueError as e:
        sys.stderr.write(f"FAIL: {plan_path}\n  {e}\n")
        return 1

    repo_root = find_repo_root(os.path.dirname(os.path.abspath(plan_path))) or os.getcwd()

    issues = check_parser_safety(fm_lines)
    data = parse_frontmatter(fm_lines)
    issues.extend(check_schema(data, repo_root))

    if issues:
        sys.stderr.write(f"FAIL: {plan_path}\n")
        for issue in issues:
            sys.stderr.write(f"  {issue}\n")
        return 1

    print(f"OK: {plan_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
