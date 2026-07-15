# Documentation Schema

The frontmatter contract for docs written under `docs/solutions/<category>/`. `problem_type` determines both **track** and **category** — read it first.

## Tracks

| Track | problem_type values | Description |
|---|---|---|
| **Bug** | `build_error`, `test_failure`, `runtime_error`, `performance_issue`, `database_issue`, `security_issue`, `ui_bug`, `integration_issue`, `logic_error` | Defects and failures that were diagnosed and fixed |
| **Knowledge** | `best_practice`, `documentation_gap`, `workflow_issue`, `developer_experience`, `architecture_pattern`, `design_pattern`, `tooling_decision`, `convention` | Practices, patterns, conventions, and decisions. `best_practice` is the fallback when no narrower value fits |

These lists are the v0.1 starting set. A project may extend `problem_type` with domain-specific values as long as each new value is added to both this table (for track membership) and the category mapping below — an unmapped `problem_type` is a validation error, not a silent default.

## Category Mapping

Category is the `problem_type` value with underscores replaced by hyphens, pluralized to match the existing directory naming convention: `docs/solutions/<category>/`. Starter categories (identical to `problem_type`'s kebab form):

- Bug: `build-errors`, `test-failures`, `runtime-errors`, `performance-issues`, `database-issues`, `security-issues`, `ui-bugs`, `integration-issues`, `logic-errors`
- Knowledge: `best-practices`, `documentation-gaps`, `workflow-issues`, `developer-experience`, `architecture-patterns`, `design-patterns`, `tooling-decisions`, `conventions`

## Required Fields (both tracks)

- **module** (string) — module or area affected
- **date** (string, `YYYY-MM-DD`) — date documented
- **problem_type** (enum, see Tracks table) — determines track and category
- **component** (string, **project-configurable** — no fixed enum) — the component or subsystem involved, in whatever vocabulary this project uses (e.g. a Rails project might use `service_object`; a Go project might use `grpc_handler`). Consuming repos may document a suggested value list in their own `AGENTS.md`/`CLAUDE.md`; this schema does not prescribe one.
- **severity** (enum: `critical` | `high` | `medium` | `low`) — impact severity

## Bug Track — Required

- **symptoms** (array of strings, 1–5 items) — observable symptoms: errors, broken behavior
- **root_cause** (string) — fundamental technical cause; free-form, but prefer a short stable phrase reused across docs so search stays useful
- **resolution_type** (string) — the kind of fix applied (e.g. `code_fix`, `migration`, `config_change`); free-form for the same reason as `root_cause`

## Knowledge Track — Optional

- **applies_when** (array of strings, up to 5 items) — conditions where this guidance applies
- **symptoms**, **root_cause**, **resolution_type** — same shape as bug track, optional here

## Optional (both tracks)

- **related_components** (array of strings)
- **tags** (array of strings, up to 8, lowercase and hyphen-separated)

## Backward Compatibility

Docs written before a schema revision may carry fields this version no longer requires (e.g. an old `component` enum value from a prior convention). Harmless — do not strip them on sight; `compound-refresh` decides whether a doc merits a rewrite on its own maintenance grounds, not because of a schema version bump alone.

## YAML Safety Rules

Strict YAML parsers reject an array item that starts with a reserved indicator as an unquoted scalar. When writing any array-of-strings field (`symptoms`, `applies_when`, `tags`, `related_components`), wrap the value in double quotes if it starts with any of `` ` [ * & ! | > % @ ? `` or contains the substring `": "`.

```yaml
# Breaks strict YAML:
symptoms:
  - `sudo dscacheutil -flushcache` does not restore in-container mDNS

# Parses cleanly:
symptoms:
  - "`sudo dscacheutil -flushcache` does not restore in-container mDNS"
```

This applies to array items only; scalar fields like `module:` or `date:` follow the plain quoting rule in `scripts/validate-frontmatter.py` (quote if the value contains ` #` or `: `).

## Validation Rules

1. Determine track from `problem_type`.
2. All required-both fields must be present.
3. Bug-track docs must additionally carry `symptoms`, `root_cause`, `resolution_type`.
4. Knowledge-track docs have no additional required fields.
5. `date` must match `YYYY-MM-DD`.
6. Array fields must respect stated min/max item counts.
7. `tags`, when present, should be lowercase and hyphen-separated (advisory — not a hard validation failure).

`scripts/validate-frontmatter.py` enforces rules 1–5 mechanically (stdlib only) and must exit 0 before `compound` reports success. `enforces: P3`
