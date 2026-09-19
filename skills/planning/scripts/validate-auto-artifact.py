#!/usr/bin/env python3
"""Validate the shared contract for auto-generated Markdown artifacts."""
from __future__ import annotations

import re
import sys
from pathlib import Path

ASSUMPTION_HEADER = [
    "Claim",
    "Command",
    "Observed at",
    "Observed result",
    "Evidence source",
]
TRADEOFF_HEADER = [
    "Option",
    "Metric it improves",
    "Metric it degrades",
    "Measured cost",
]
SEPARATOR = re.compile(r"^:?-{1,}:?$")


def fail(message: str) -> "NoReturn":
    print(f"validate-auto-artifact: {message}", file=sys.stderr)
    raise SystemExit(1)


def usage(message: str) -> "NoReturn":
    print(f"validate-auto-artifact: {message}", file=sys.stderr)
    raise SystemExit(2)


def split_cells(line: str) -> list[str]:
    """Split a Markdown table row while preserving escaped pipe characters."""
    text = line.strip()
    if text.startswith("|"):
        text = text[1:]
    if text.endswith("|") and not text.endswith("\\|"):
        text = text[:-1]
    cells: list[str] = []
    current: list[str] = []
    escaped = False
    for char in text:
        if char == "|" and not escaped:
            cells.append("".join(current).strip())
            current = []
            continue
        current.append(char)
        escaped = char == "\\" and not escaped
        if char != "\\":
            escaped = False
    cells.append("".join(current).strip())
    return cells


def heading_index(lines: list[str], pattern: re.Pattern[str]) -> int:
    for index, line in enumerate(lines):
        if pattern.fullmatch(line.strip()):
            return index
    return -1

def required_content(
    lines: list[str], patterns: list[re.Pattern[str]], label: str
) -> str:
    for pattern in patterns:
        index = heading_index(lines, pattern)
        if index >= 0:
            content = "\n".join(section_lines(lines, index)).strip()
            if not content:
                fail(f"{label} section is empty")
            return content
    fail(f"missing {label} section")


def section_lines(lines: list[str], start: int) -> list[str]:
    for index in range(start + 1, len(lines)):
        if re.fullmatch(r"##\s+.+", lines[index].strip()):
            return lines[start + 1 : index]
    return lines[start + 1 :]


def data_rows(section: list[str], expected_header: list[str], label: str) -> list[list[str]]:
    header_index = -1
    for index, line in enumerate(section):
        if line.lstrip().startswith("|") and split_cells(line) == expected_header:
            header_index = index
            break
    if header_index < 0:
        fail(f"{label} table header is missing")

    rows: list[list[str]] = []
    for line in section[header_index + 1 :]:
        if not line.lstrip().startswith("|"):
            continue
        cells = split_cells(line)
        if cells and all(SEPARATOR.fullmatch(cell.replace(" ", "")) for cell in cells):
            continue
        rows.append(cells)
    if not rows:
        fail(f"{label} table has no data rows")
    return rows


def validate_assumptions(section: list[str]) -> None:
    text = "\n".join(section).strip()
    if not text:
        fail("assumptions section is empty")
    lowered = text.casefold()
    if "no-live-assumptions" in lowered or "no live assumptions" in lowered:
        return
    rows = data_rows(section, ASSUMPTION_HEADER, "assumptions")
    for row_number, row in enumerate(rows, start=1):
        if len(row) != len(ASSUMPTION_HEADER) or any(not cell for cell in row):
            fail(f"assumptions row {row_number} has a blank or malformed field")


def validate_tradeoffs(section: list[str]) -> None:
    rows = data_rows(section, TRADEOFF_HEADER, "trade-offs")
    selected = False
    rejected = False
    no_alternative = False
    for row_number, row in enumerate(rows, start=1):
        if len(row) != len(TRADEOFF_HEADER) or any(not cell for cell in row):
            fail(f"trade-offs row {row_number} has a blank or malformed field")
        option = row[0]
        if option.startswith("Selected:"):
            if not option[len("Selected:") :].strip():
                fail(f"trade-offs row {row_number} has no selected option name")
            selected = True
        elif option.startswith("Rejected:"):
            if not option[len("Rejected:") :].strip():
                fail(f"trade-offs row {row_number} has no rejected option name")
            rejected = True
        elif option.startswith("No rejected alternative:"):
            if not option[len("No rejected alternative:") :].strip():
                fail(f"trade-offs row {row_number} has no alternative rationale")
            no_alternative = True
        if not re.search(r"[0-9]", row[3]):
            fail(f"trade-offs row {row_number} measured cost has no ASCII digit")
    if not selected:
        fail("trade-offs table has no Selected: row")
    if not rejected and not no_alternative:
        fail("trade-offs table has neither Rejected: nor No rejected alternative: row")

def validate_auto(path: Path) -> None:
    try:
        text = path.read_text(encoding="utf-8")
    except OSError as error:
        usage(f"cannot read {path}: {error}")
    lines = text.splitlines()
    if not lines or lines[0].strip() != "---":
        fail("artifact has no frontmatter")
    try:
        end = lines.index("---", 1)
    except ValueError:
        fail("frontmatter is not closed")
    frontmatter = lines[1:end]
    mode_entries = [
        line.split(":", 1)[1].strip()
        for line in frontmatter
        if line.strip().startswith("mode:")
    ]
    if mode_entries != ["auto"]:
        fail("frontmatter must contain exactly one mode: auto entry")

    assumptions = heading_index(lines, re.compile(r"## Assumptions and Preconditions"))
    tradeoffs = heading_index(lines, re.compile(r"## Trade-offs"))
    architecture = heading_index(lines, re.compile(r"## (?:Architecture|Architecture notes)"))
    if assumptions < 0:
        fail("missing ## Assumptions and Preconditions")
    if tradeoffs < 0:
        fail("missing ## Trade-offs")
    if architecture < 0:
        fail("missing Architecture heading")
    if assumptions >= architecture or tradeoffs >= architecture:
        fail("assumptions and trade-offs must precede Architecture")
    validate_assumptions(section_lines(lines, assumptions))
    validate_tradeoffs(section_lines(lines, tradeoffs))

    required_content(
        lines,
        [re.compile(r"## Non-goals"), re.compile(r"### Out")],
        "non-goals",
    )
    required_content(
        lines,
        [re.compile(r"## Residual Risks"), re.compile(r"## Risks(?: and Mitigations)?")],
        "residual risks",
    )
    success = required_content(lines, [re.compile(r"## Success Criteria")], "success criteria")
    if not re.search(r"`(?:bash|python3|sh) [^`]+`", success):
        fail("success criteria has no concrete proving command")
    if not re.search(r"negative[- ]controls?", success.casefold()):
        fail("success criteria has no negative-control requirement")


def main(argv: list[str]) -> int:
    if len(argv) != 4 or argv[1] != "--mode":
        usage("usage: validate-auto-artifact.py --mode auto|interactive <artifact>")
    mode = argv[2]
    if mode not in {"auto", "interactive"}:
        usage("mode must be auto or interactive")
    path = Path(argv[3])
    if not path.is_file():
        usage(f"file not found: {path}")
    if mode != "auto":
        return 0
    validate_auto(path)
    print(f"OK: {path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
