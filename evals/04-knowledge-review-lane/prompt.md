---
max_turns: 30
timeout_seconds: 600
allowed_tools: [Skill, Write, Edit, Read, Grep, Glob]
runs: 3
---
We need to document a convention for the reviewing skill's agent mode. When `mode:agent` is used, the review output is a JSON envelope following `review-envelope.schema.json`. We discovered that if the `confidence` field is omitted from individual findings, the downstream consumer (implementing skill) silently treats the finding as low-confidence and skips it.

The convention: every finding in a `mode:agent` JSON review MUST include an explicit `confidence` value. Omission is not "unspecified" — it's "low" by default, which causes real findings to be silently dropped.

Compound this convention.
