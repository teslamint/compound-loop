---
max_turns: 30
timeout_seconds: 600
allowed_tools: [Skill, Write, Edit, Read, Grep, Glob]
runs: 3
---
mode:headless I fixed a bug where the compound skill's terminal signal was written to the output file instead of stdout. When retrospective calls compound in headless mode, it parses stdout for the exact line "Documentation complete — <path>". But compound was appending this line to the markdown document body instead of printing it. The retrospective caller then failed to detect completion.

The fix: moved the terminal signal emission from the file-write phase to the final print statement, after the file is closed. The signal line must be the last non-empty line of stdout output, never part of the document content.
