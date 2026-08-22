---
name: compound
description: Document a solved problem or captured guidance into docs/solutions/ and the shared CONCEPTS.md vocabulary. /compound or $compound right after verifying a fix, when retrospective invokes it in mode:headless with a qualifying finding, or on direct request ("document this", "compound this fix").
---

# Compound

Captures a solution while context is fresh. The first time a problem is solved it costs research; documented, the next occurrence costs minutes. `references/schema.md` is the frontmatter contract this skill writes to — read on demand, never restated here.

## Entry / Exit / Gate

- **Entry**: a verified fix or a captured piece of durable guidance, in conversation context or passed as a headless argument.
- **Exit**: one doc written or updated under `docs/solutions/<category>/`, plus optional `CONCEPTS.md` / instruction-file maintenance edits.
- **Gate**: AUTO — no human approval required to write documentation.

## Mode Detection

Strip a leading `mode:headless` token from arguments before treating the remainder as a context hint.

| Mode | Behavior |
|---|---|
| **Interactive** (default) | Ask Full vs. Lightweight via the blocking-question pattern in `references/question-tools.md`; Full mode may also offer session-history search |
| **Headless** | No questions. Run **Full mode** without session history. Apply Discoverability edits silently if a gap exists. Skip the optional-review phase. End with the exact terminal signal from `schemas/headless-contract.md` |

## Full Mode

**The deliverable is ONE file.** Research subagents return text only — never Write/Edit — so only the orchestrator writes files. `CONCEPTS.md` and an instruction-file edit are maintenance side effects of the one deliverable, not additional ones.

### Phase 1: Parallel Research

Dispatch per `references/dispatch-degradation.md` (native parallel → sequential passes → single-call fallback; correctness never depends on tier 1):

- **Context Analyzer** — determines track and category from `references/schema.md`, drafts the frontmatter skeleton, suggests a filename (`[problem-slug].md`, no date suffix — `date:` frontmatter is the canonical date).
- **Solution Extractor** — writes the track-appropriate body sections (bug: Problem/Symptoms/What Didn't Work/Solution/Why This Works/Prevention; knowledge: Context/Guidance/Why This Matters/When to Apply/Examples).
- **Related Docs Finder** — grep-first search of `docs/solutions/<category>/` for overlap, scored across five dimensions (problem statement, root cause, solution approach, referenced files, prevention rules): **High** (4–5 match) / **Moderate** (2–3) / **Low** (0–1).
- **Session-history search** (interactive Full only, if the user opts in) — pluggable; skip cleanly when unavailable rather than hard-depending on it.

### Phase 2: Assembly & Write

Wait for all Phase 1 inputs. Act on the overlap score:

| Overlap | Action |
|---|---|
| High | Update the existing doc (fresher examples, `last_updated:` field) rather than create a duplicate — two docs on the same problem drift apart |
| Moderate | Create the new doc; flag the overlap for Phase 5's refresh check |
| Low | Create the new doc normally |

Assemble the file, validate frontmatter against `references/schema.md`'s YAML quoting rule, write to `docs/solutions/<category>/`, then **run `python3 skills/compound/scripts/validate-frontmatter.py <path>`**. Exit 0 required before claiming success; a nonzero exit names the offending field(s) — fix and re-run, never declare success on a failing run. `enforces: P3`

### Phase 3: CONCEPTS.md Vocabulary Capture

Scan the new doc and surrounding conversation for qualifying domain terms — a bar of "a new engineer would need this term defined." Glossary purity: no implementation specifics, status fields, config numbers, or links in an entry. Be opinionated: one canonical term per concept, `*Avoid: X*` for rejected aliases.

- If `CONCEPTS.md` doesn't exist and a term qualifies, **seed the learning's area**, not the whole repo — the surfaced term plus the core nouns of the domain it touched. A repo-wide concept map is `compound-refresh`'s bootstrap job, not this one.
- If it exists, add/refine entries, then refresh the touched entry's **coherence neighborhood only** (its cluster siblings) — never a full-file audit; that's `compound-refresh`'s job.
- Hold the qualifying bar conservatively at creation time — borderline terms defer to a later run.
- No qualifying term found is a valid outcome — record it explicitly ("scanned, no qualifying terms"), never silently skip.

### Phase 4: Discoverability Check

Assess whether `AGENTS.md`/`CLAUDE.md` would lead an agent to discover `docs/solutions/` (and `CONCEPTS.md`, if it exists) before working in a documented area — a semantic check, not a string match. If the spirit is already met, no edit. If not, draft the smallest addition (a line in an existing section beats a new headed section) in an informational, non-imperative tone. Interactive mode: consent via the blocking-question pattern before editing. Headless mode: apply silently, report the edit.

### Phase 5: Selective Refresh Recommendation

`compound-refresh` is not a default follow-up — invoke or recommend it only when this new doc suggests an older one is now stale (contradicts it, clearly supersedes it, or Phase 1 reported moderate/high overlap worth consolidating). Prefer the narrowest scope hint (a specific file, module, or category). **In headless mode, never invoke it — surface the scope hint as a recommendation line in the terminal report instead** and let the caller decide.

## Lightweight Mode

Single pass, no subagents, no overlap detection: extract the problem/solution from conversation, classify track/category/filename from `references/schema.md`, write the minimal doc, run the same `validate-frontmatter.py` gate, and do an **update-only** vocabulary pass (refine an existing `CONCEPTS.md`; never bootstrap or seed one in this mode). Skip the specialized-review and discoverability-edit phases; note a Discoverability *tip* instead of an edit. Headless mode always forces Full — it never enters Lightweight.

## Optional Enhancement Hook

Interactive Full mode only, never headless: after Phase 4, a project may wire in its own specialized review agent(s) (security, performance, code-simplicity) keyed off `problem_type`. This plugin ships no fixed roster — projects document their own hook in local config.

## Terminal Signals

End every invocation with the exact line from `schemas/headless-contract.md` — the last non-empty line of the report, in every mode: `Documentation complete — <path>` (doc written or updated), `Documentation skipped — <reason>` (e.g. no solved problem found), or `Documentation failed — <reason>` (e.g. validation never reached exit 0).

## Handoff

`compound-refresh` is the only skill this may invoke, and only per Phase 5's gate. Nothing invokes `compound` automatically on trigger phrases — every run is an explicit call, from a user, from `retrospective`, or from any other caller.

## Out of Scope

Dropped by design: five specialized reviewer subagents (→ one generic project-wired hook, see above); a fixed Rails-shaped `component` enum (→ project-configurable string, `references/schema.md`); a hard dependency on session-history search (→ pluggable, interactive-only); ambient auto-invoke on trigger phrases like "that worked" (→ explicit calls only).
