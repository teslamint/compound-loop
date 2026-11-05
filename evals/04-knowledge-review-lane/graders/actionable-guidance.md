---
type: llm
focus: trace
weight: 1
---
The agent was asked to document a review convention using the compound skill. Look at the full trace for evidence of document creation. Grade on these criteria:
1. A markdown file was created under docs/solutions/ with YAML frontmatter
2. The document clearly states the convention: every mode:agent review finding MUST include an explicit confidence value
3. The document explains the failure mode: a finding without `confidence` fails `review-envelope.schema.json` validation and is dropped by the merge pipeline validate step, which records a drop count

Score 1 if criteria 1-3 are met (look for Write/Edit tool calls that show the document content). Score 0 if no document was created or criteria 1-2 are missing.
