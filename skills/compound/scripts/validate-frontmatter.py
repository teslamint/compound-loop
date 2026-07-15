#!/usr/bin/env python3
"""Validate a docs/solutions/ doc's frontmatter against references/schema.md.

Usage:
    python3 validate-frontmatter.py <doc-path>

Exit codes:
    0 — frontmatter passes all checks
    1 — validation failure (diagnostics on stderr)
    2 — usage error (bad arguments, missing file)

Scope: this script checks two things, both required before `compound` may
report success (enforces: P3):

  1. Parser-safety — frontmatter that a strict YAML parser would silently
     misread (malformed `---` delimiters, unquoted ` #` or `: ` inside a
     scalar value). Ported from compound-engineering's validator.
  2. Schema conformance — the required-fields-per-track rules in
     references/schema.md: both-track required fields present, `problem_type`
     maps to a known track, and bug-track docs additionally carry
     `symptoms` / `root_cause` / `resolution_type`.

This is a hand-rolled frontmatter reader, not a YAML parser — it only
understands the subset of YAML this schema uses (top-level scalars and
simple `- item` lists under a key). Pure stdlib, no PyYAML or other deps.
"""
import os
import re
import sys

BUG_TYPES = {
    "build_error", "test_failure", "runtime_error", "performance_issue",
    "database_issue", "security_issue", "ui_bug", "integration_issue",
    "logic_error",
}
KNOWLEDGE_TYPES = {
    "best_practice", "documentation_gap", "workflow_issue",
    "developer_experience", "architecture_pattern", "design_pattern",
    "tooling_decision", "convention",
}
REQUIRED_BOTH = ["module", "date", "problem_type", "component", "severity"]
REQUIRED_BUG_ONLY = ["symptoms", "root_cause", "resolution_type"]
DATE_RE = re.compile(r"^\d{4}-\d{2}-\d{2}$")


def usage_fail(msg: str) -> "NoReturn":
    sys.stderr.write(f"validate-frontmatter: {msg}\n")
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
            # Nested content: only meaningful as a list item under current_key
            if stripped.startswith("- ") and current_key is not None:
                item = stripped[2:].strip()
                item = _unquote(item)
                data.setdefault(current_key, [])
                data[current_key].append(item)
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


def check_schema(data: dict) -> list[str]:
    issues = []
    for field in REQUIRED_BOTH:
        if not data.get(field):
            issues.append(f"missing required field: '{field}'")

    date_val = data.get("date")
    if date_val and not DATE_RE.match(date_val):
        issues.append(f"'date' value '{date_val}' does not match YYYY-MM-DD")

    problem_type = data.get("problem_type")
    if problem_type:
        if problem_type in BUG_TYPES:
            for field in REQUIRED_BUG_ONLY:
                value = data.get(field)
                if not value:
                    issues.append(
                        f"bug-track doc (problem_type: {problem_type}) missing required field: '{field}'"
                    )
            symptoms = data.get("symptoms")
            if isinstance(symptoms, list) and not (1 <= len(symptoms) <= 5):
                issues.append(
                    f"'symptoms' must have 1-5 items, found {len(symptoms)}"
                )
        elif problem_type in KNOWLEDGE_TYPES:
            pass  # no additional required fields
        else:
            issues.append(
                f"'problem_type' value '{problem_type}' is not mapped to a track — "
                "add it to references/schema.md's Tracks table and this script's "
                "BUG_TYPES/KNOWLEDGE_TYPES sets before using it"
            )

    return issues


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        usage_fail(f"usage: {os.path.basename(argv[0])} <doc-path>")

    doc_path = argv[1]
    if not os.path.isfile(doc_path):
        usage_fail(f"file not found: {doc_path}")

    with open(doc_path) as f:
        text = f.read()

    try:
        fm_lines = extract_frontmatter(text)
    except ValueError as e:
        sys.stderr.write(f"FAIL: {doc_path}\n  {e}\n")
        return 1

    issues = check_parser_safety(fm_lines)
    data = parse_frontmatter(fm_lines)
    issues.extend(check_schema(data))

    if issues:
        sys.stderr.write(f"FAIL: {doc_path}\n")
        for issue in issues:
            sys.stderr.write(f"  {issue}\n")
        return 1

    print(f"OK: {doc_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
