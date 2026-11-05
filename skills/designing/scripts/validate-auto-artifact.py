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
OBSERVED_AT = re.compile(r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$")
BACKTICKED_COMMAND = re.compile(r"^`[^`\n]+`$")
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


def fence_run(marker: str) -> tuple[str, int]:
    if not marker or marker[0] not in "`~":
        return "", 0
    char = marker[0]
    length = len(marker) - len(marker.lstrip(char))
    if length < 3:
        return "", 0
    return char, length


def strip_fenced_blocks(lines: list[str]) -> list[str]:
    kept: list[str] = []
    fence_char = ""
    fence_length = 0
    for line in lines:
        marker = line.strip()
        char, length = fence_run(marker)
        if fence_char:
            if char == fence_char and length >= fence_length and marker == char * length:
                fence_char, fence_length = "", 0
            continue
        if char:
            fence_char, fence_length = char, length
            continue
        kept.append(line)
    return kept


def frontmatter_scalar(line: str) -> str:
    value = line.split(":", 1)[1].strip()
    if len(value) >= 2 and value[0] == value[-1] and value[0] in "\"'":
        return value[1:-1]
    return value


def has_negative_control_requirement(text: str) -> bool:
    for sentence in re.split(r"[\n.!?]+", text.casefold()):
        if re.search(r"\bnegative[- ]controls?\b", sentence) and not re.search(
            r"\b(?:no|not|never|without|unnecessary|unneeded|aren't|isn't|doesn't|don't)\b",
            sentence,
        ):
            return True
    return False


COMMAND_SPAN = re.compile(r"`((?:\.{0,2}/)?[A-Za-z0-9_.][A-Za-z0-9_./-]*)(\s+[^`\n]+)?`")


def has_proving_command(text: str) -> bool:
    # Any executable is allowed, but a bare identifier (`progress_path`) or a
    # key-value span (`mode: auto`) is not a command: it needs arguments or a path.
    return any(
        match.group(2) or "/" in match.group(1)
        for match in COMMAND_SPAN.finditer(text)
    )


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
    heading = re.fullmatch(r"(#{1,6})\s+.+", lines[start].strip())
    level = len(heading.group(1)) if heading else 2
    for index in range(start + 1, len(lines)):
        match = re.fullmatch(r"(#{1,6})\s+.+", lines[index].strip())
        if match and len(match.group(1)) <= level:
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
    has_marker = "no-live-assumptions" in lowered or "no live assumptions" in lowered
    has_table_header = any(
        line.lstrip().startswith("|") and split_cells(line) == ASSUMPTION_HEADER
        for line in section
    )
    if has_marker and not has_table_header:
        return
    rows = data_rows(section, ASSUMPTION_HEADER, "assumptions")
    for row_number, row in enumerate(rows, start=1):
        if len(row) != len(ASSUMPTION_HEADER) or any(not cell for cell in row):
            fail(f"assumptions row {row_number} has a blank or malformed field")
        if not BACKTICKED_COMMAND.fullmatch(row[1]):
            fail(f"assumptions row {row_number} command is not a delimited rerunnable command")
        if not OBSERVED_AT.fullmatch(row[2]):
            fail(f"assumptions row {row_number} observed-at value is not an ISO-8601 UTC timestamp")


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
        frontmatter_scalar(line)
        for line in frontmatter
        if line.strip().startswith("mode:")
    ]
    if mode_entries != ["auto"]:
        fail("frontmatter must contain exactly one mode: auto entry")
    schema_entries = [
        frontmatter_scalar(line)
        for line in frontmatter
        if line.strip().startswith("schema:")
    ]
    content_lines = lines[: end + 1] + strip_fenced_blocks(lines[end + 1 :])
    if schema_entries == ["plan/v1"]:
        required_content(
            content_lines,
            [re.compile(r"## Assumption Recheck")],
            "assumption recheck",
        )

    assumptions = heading_index(content_lines, re.compile(r"## Assumptions and Preconditions"))
    tradeoffs = heading_index(content_lines, re.compile(r"## Trade-offs"))
    architecture = heading_index(content_lines, re.compile(r"## (?:Architecture|Architecture notes)"))
    success_criteria = heading_index(content_lines, re.compile(r"## Success Criteria"))
    implementation_units = heading_index(content_lines, re.compile(r"## Implementation Units"))
    if assumptions < 0:
        fail("missing ## Assumptions and Preconditions")
    if tradeoffs < 0:
        fail("missing ## Trade-offs")
    if architecture < 0:
        fail("missing Architecture heading")
    ordering_gates = [
        index for index in (architecture, success_criteria, implementation_units) if index >= 0
    ]
    if any(assumptions >= gate or tradeoffs >= gate for gate in ordering_gates):
        fail("assumptions and trade-offs must precede Architecture, Success Criteria, and Implementation Units")
    validate_assumptions(section_lines(content_lines, assumptions))
    validate_tradeoffs(section_lines(content_lines, tradeoffs))

    required_content(
        content_lines,
        [re.compile(r"## Non-goals"), re.compile(r"### Out")],
        "non-goals",
    )
    required_content(
        content_lines,
        [re.compile(r"## Residual Risks"), re.compile(r"## Risks(?: and Mitigations)?")],
        "residual risks",
    )
    success = required_content(content_lines, [re.compile(r"## Success Criteria")], "success criteria")
    if not has_proving_command(success):
        fail("success criteria has no concrete proving command")
    if not has_negative_control_requirement(success):
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
