# compound-loop

Engineering lifecycle skills that work identically in Claude Code and Codex.

compound-loop merges three lineages into one curated skill set:

- **superpowers** — process discipline (brainstorming, plans, TDD, systematic debugging, verification)
- **compound-engineering** — review pipeline rigor and knowledge compounding (persona lanes, confidence gating, docs/solutions)
- **release-loop** — a six-phase orchestrated lifecycle (Design → Plan → Implement → Review → Ship → Retro) with file-based state

Read [PRINCIPLES.md](PRINCIPLES.md) first — it is the charter every skill enforces.

## Skills

| Skill | Role |
|---|---|
| `release-loop` | Orchestrates the six phases end to end; each phase invokes the standalone skill below |
| `designing` | Requirements exploration with scope tiering, rigor-gap probes, and mandatory measurable success criteria |
| `planning` | Implementation plans with stable unit IDs, per-unit test scenarios, and a risk-scored deepening pass |
| `implementing` | Plan execution with file-based handoffs, parallel-safety checks, and graceful degradation |
| `tdd` | Red-green-refactor discipline (Iron Law: no production code without a failing test) |
| `debugging` | Root-cause investigation with causal-chain gate and prediction discipline |
| `worktree-isolation` | Isolated workspaces: native tool → git worktree → work in place |
| `reviewing` | Lane-contract multi-perspective review with confidence gating and a machine-readable JSON mode |
| `shipping` | Verification gate, commit/PR protocol, CI watch loop, review-feedback resolution, merge gate |
| `retrospective` | Measured-vs-declared success comparison, carry-forward tracking, lessons |
| `compound` | Capture solved problems into `docs/solutions/` and maintain CONCEPTS.md vocabulary |
| `compound-refresh` | Periodic audit of accumulated knowledge docs (keep/update/consolidate/replace/delete) |

## Install

### Claude Code

```bash
/plugin marketplace add <path-or-repo>
/plugin install compound-loop
```

### Codex

```bash
ln -s "$(pwd)/skills" ~/.codex/skills/compound-loop   # or per-skill symlinks
```

Skills are invoked as `/name` in Claude Code and `$name` in Codex.

## Cross-harness contracts

- Skills communicate through files, never through harness-specific channels: review findings as JSON artifacts (`mode:agent`), knowledge capture with terminal signal strings (`mode:headless`), loop state in `.release-loop/progress.md`.
- Every parallel dispatch degrades: native parallel subagents → sequential passes → single-call fallback.
- Plan documents follow a single schema (frontmatter + stable U-IDs + categorized test scenarios) shared by `planning`, `implementing`, and `reviewing`. See `schemas/`.
