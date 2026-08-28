---
name: compound-refresh
description: Refresh/delete docs. /compound-refresh or $compound-refresh on request ("refresh my learnings", "audit docs/solutions/", "clean up stale docs", "consolidate overlapping docs"), or when compound flags a candidate. Skip general refactor/code-review unless pointed at docs/solutions/.
---

# Compound Refresh

Periodic maintenance for `docs/solutions/`, kept separate from `compound` on purpose: per-problem capture and periodic audit have different operating rhythms, and `compound`'s Phase 5 selective-trigger already draws that boundary correctly.

## Entry / Exit / Gate

- **Entry**: direct invocation, or a scope hint recommended by `compound`.
- **Exit**: a full Applied-vs-Recommended report; in interactive mode, applied edits are committed.
- **Gate**: interactive mode applies most classifications directly, asking only on genuine ambiguity. **Headless mode in v0.1 applies nothing** — see Mode Detection. `enforces: P7` (headless narrowing keeps unattended writes out of an audit sweep until the mechanism is proven).

## Mode Detection

Strip a leading `mode:headless` token; the remainder is a scope hint.

| Mode | Behavior |
|---|---|
| **Interactive** (default) | Classify, then apply Update/Consolidate/Delete-with-clear-evidence directly; ask via the blocking-question pattern (`references/question-tools.md`) only when the action is genuinely ambiguous, or before a Replace/Delete whose evidence isn't unambiguous |
| **Headless** | No questions. Classify every candidate per Phase 2, but **apply zero writes this version** — every action, including unambiguous ones, is reported under Recommended with full rationale. This is a deliberate narrowing from a fully-autonomous headless sweep; see Out of Scope |

## Scope Selection

Try in order, stopping at the first that produces results: directory match under `docs/solutions/` → frontmatter match (`module`/`component`/`tags`) → filename match → content search. No scope hint → process every doc. Scope hint given but no matches → report the miss; **never** silently widen to everything (headless included).

## Phase 0: Broad-Scope Triage

Route by count: **Focused** (1–2 docs) → investigate directly. **Batch** (≤8) → investigate, then present grouped. **Broad** (9+) → triage first: inventory frontmatter → cluster by module/component/category → spot-check whether referenced files still exist in each cluster → recommend the highest-impact starting cluster (in headless mode, process all clusters in impact order instead of asking).

## Phase 1: Investigate

For each candidate, read it and cross-reference its claims against the current codebase. See `references/maintenance-model.md` for the investigation dimensions and the Update-vs-Replace boundary (the rewriting-the-solution-section test).

## Phase 1.75: Document-Set Analysis

Step back from individual docs to the set as a whole: overlap detection across five dimensions, supersession signals, canonical-doc identification per topic cluster, and the Retrieval-Value Test before recommending two docs stay separate. Full detail in `references/maintenance-model.md`.

## Phase 2: Classify

Assign one of the five outcomes — Keep / Update / Consolidate / Replace / Delete — per `references/maintenance-model.md`. The hard boundary: **rewriting the solution section is Replace, never Update.** Before any Delete, apply the delete guardrails: auto-delete only when implementation is gone, the problem domain is gone, **and** inbound citations are absent or decorative (a substantive citation signals Replace instead; mixed or unclear citations get stale-marked, never guessed). Full citation-classification detail in the same reference.

## Phase 3: Decide

**Interactive**: apply clear Update/Consolidate/auto-Delete directly. Ask one question at a time, leading with the recommendation, only for genuinely ambiguous classification, a Consolidate whose canonical doc isn't clear-cut, or a Replace/Delete with insufficient evidence.

**Headless (v0.1)**: skip all questions. Every classification from Phase 2 — however unambiguous — becomes a line in the Recommended section of the report. No file is written in this mode this version.

## Phase 4: Execute (interactive mode only)

- **Keep** — no edit; report why it's still trustworthy.
- **Update** — apply the in-place fix (paths, names, links, snippets).
- **Consolidate** — merge the subsumed doc's unique content into the canonical doc, then delete the subsumed doc (delete, not archive — git history is the record).
- **Replace** — a subagent writes the successor using `compound`'s document contract (`compound`'s `references/schema.md` + frontmatter template), validated by `compound`'s `scripts/validate-frontmatter.py` before the old doc is deleted. Insufficient evidence to write a trustworthy successor → mark `status: stale` with `stale_reason` and `stale_date` instead of guessing.
- **Delete** — final inbound-link check, then remove.

## Phase 4.5: CONCEPTS.md Corpus Reconciliation

Unlike `compound`'s per-write coherence-neighborhood-only touch, this is the full audit pass: reconcile every qualifying term surfaced during Phase 1 across the whole in-scope corpus (union differing shades of the same term into one entry, never most-recent-wins), backfill core nouns for the area in scope that friction never surfaced, and run a full scrub sweep for glossary violations (implementation specifics, config values, status metadata) in existing entries. Bootstrap a repo-wide `CONCEPTS.md` from scratch only on an explicit "build the concept map" request — a plain refresh call reconciles within the scope it processed, never repo-wide by default.

## Phase 5: Report

Always split **Applied** (writes that succeeded — interactive mode only) vs. **Recommended** (everything else, with enough rationale that a human can apply it manually or via a fresh interactive run). In headless mode, Applied is always empty this version; Recommended is the entire classified set. Print the full report as markdown — this is the deliverable, never a one-line summary.

## Commit Hygiene

Applies in interactive mode only — headless mode writes nothing in this version, so there is nothing to commit (see Phase 5). Stage only the files this run modified, never a broad `git add`. On the default branch: offer branch + commit + PR. On a feature branch: commit in place. A git failure degrades to listing the recommended commands in the report, never blocking it.

## Discoverability Check

Same semantic assessment as `compound`'s Discoverability Check (does `AGENTS.md`/`CLAUDE.md` surface `docs/solutions/` and `CONCEPTS.md`?), run once at the end of a refresh pass. Interactive: consent before editing. Headless: report as a recommendation line, never an applied edit.

## Terminal Signals

End every invocation with the exact line from `schemas/headless-contract.md`: `Refresh complete — <n> applied, <n> recommended`, `Refresh skipped — <reason>` (e.g. no candidate docs found), or `Refresh failed — <reason>`.

## Handoff

Terminal in the loop — nothing is invoked automatically from here. A Replace or Consolidate that produces a new doc does not re-trigger `compound`; the doc was already written to `compound`'s contract directly.

## Out of Scope (v0.2)

- **Headless auto-apply of unambiguous actions.** v0.1 headless is deliberately recommend-only regardless of how clear-cut a classification is; applying writes unattended during an audit sweep is deferred until the classification logic has interactive-mode track record.
- A dedicated schema validator with valid/invalid/migration fixtures for `compound`'s frontmatter contract (covered today by `scripts/validate-frontmatter.py`'s mechanical checks, not a fixture suite).
