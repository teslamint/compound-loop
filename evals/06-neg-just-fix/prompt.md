---
max_turns: 10
timeout_seconds: 120
allowed_tools: [Read, Grep, Glob, Edit]
runs: 3
---
The `validate-frontmatter.py` script doesn't check that the `date` field matches the `YYYY-MM-DD` format. It accepts any string. Fix the validation to reject dates that don't match this pattern.
