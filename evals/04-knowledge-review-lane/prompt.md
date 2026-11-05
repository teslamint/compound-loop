---
max_turns: 30
timeout_seconds: 600
allowed_tools: [Skill, Write, Edit, Read, Grep, Glob, Bash]
runs: 3
---
We need to document a convention for the reviewing skill's agent mode. When `mode:agent` is used, the review output is a JSON envelope following `review-envelope.schema.json`. The schema requires a `confidence` field for every finding.

The convention: every finding in a `mode:agent` JSON review MUST include an explicit `confidence` value. A finding without `confidence` fails schema validation and is dropped by the merge pipeline's Validate step, which records a drop count.

Compound this convention.
