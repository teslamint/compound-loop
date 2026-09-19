---
max_turns: 30
timeout_seconds: 600
allowed_tools: [Skill, Write, Edit, Read, Grep, Glob]
runs: 3
---
We learned an important pattern about subagent dispatch. When dispatching 3 parallel research subagents, the native parallel tier works on Claude Code but fails silently on Codex because Codex doesn't support native parallel subagents. The system falls back to sequential passes, which is correct behavior but takes 3x longer.

The key insight: always design dispatch so that correctness never depends on tier 1 (native parallel). The sequential fallback must produce identical results, just slower. And the single-call fallback (tier 3) must also work as a last resort.

Document this pattern.
