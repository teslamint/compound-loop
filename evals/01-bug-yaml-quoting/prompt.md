---
max_turns: 30
timeout_seconds: 600
allowed_tools: [Skill, Write, Edit, Read, Grep, Glob, Bash]
runs: 3
---
I just fixed a bug in our YAML frontmatter handling. When a `symptoms` array item starts with a backtick (`` ` ``), strict YAML parsers reject it as an unquoted scalar. The fix was to wrap such values in double quotes.

Before (broken):
```yaml
symptoms:
  - `sudo dscacheutil -flushcache` does not restore in-container mDNS
```

After (fixed):
```yaml
symptoms:
  - "`sudo dscacheutil -flushcache` does not restore in-container mDNS"
```

The root cause is that YAML reserves certain characters (`` ` ``, `[`, `*`, `&`, `!`, `|`, `>`, `%`, `@`, `?`) as flow indicators. Array items starting with these must be quoted.

Compound this fix.
