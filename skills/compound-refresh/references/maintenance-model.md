# Maintenance Model

Detail behind `SKILL.md`'s Phase 1–2 summary: the investigation dimensions, the five-outcome classification, and the delete guardrails. Ported from ce-compound-refresh, condensed.

## Investigation Dimensions (Phase 1)

For each candidate doc, check:

- **References** — do the file paths, class/function names, and modules it cites still exist, or have they moved?
- **Recommended solution** — does the fix still match how the code actually works, or did the implementation pattern change underneath a surface-level path rename?
- **Code examples** — do embedded snippets still reflect the current implementation?
- **Related docs** — are cross-referenced learnings/patterns still present and consistent?
- **Overlap** — does another in-scope doc cover the same problem domain, files, or solution? Record which dimensions overlap for Phase 1.75.
- **Vocabulary** — does the doc cite a domain term that should be in `CONCEPTS.md`? Flag for Phase 4.5; do not edit the glossary during investigation.

Match investigation depth to specificity — a doc citing exact paths and snippets needs more verification than one stating a general principle.

## Update vs. Replace — the Boundary

- **Update territory**: paths moved, classes renamed, links broke, metadata drifted, but the core recommended approach still matches how the code works. Fix directly.
- **Replace territory**: the recommended solution conflicts with current code, the architecture shifted, or the pattern is no longer preferred.

**The test**: if you find yourself rewriting the solution section or changing what the doc recommends, that is Replace, not Update — no exceptions for how small the rewrite feels.

Age alone is not a stale signal — a doc that still matches current code stays Keep regardless of age; use age only as a prompt to look more carefully.

## The Five Outcomes

| Outcome | Meaning | Default action |
|---|---|---|
| **Keep** | Still accurate and useful | No edit; report reviewed-and-trustworthy |
| **Update** | Core solution correct, references drifted | In-place fix (paths, names, links, snippets) |
| **Consolidate** | Two+ docs overlap heavily, both materially correct | Merge unique content into the canonical doc, delete the subsumed one |
| **Replace** | Old artifact now misleading; a better replacement is knowable | Write a trustworthy successor, then delete the old artifact |
| **Delete** | No longer useful, applicable, or distinct | Remove the file — git history is the archive, there is no `_archived/` directory |

## Document-Set Analysis (Phase 1.75)

Beyond per-doc accuracy, evaluate whether the doc set is still the right shape:

- **Overlap detection** — for docs sharing module/component/tags, compare problem statement, solution shape, referenced files, prevention rules, root cause. High overlap (3+ dimensions) is a strong Consolidate signal.
- **Supersession signals** — a newer, broader doc covering the same files/workflow as an older, narrower one; an older incident doc generalized by a newer pattern doc.
- **Canonical-doc identification** — per topic cluster, name the doc a maintainer should find first; others are **distinct** (keep separate — independent retrieval value), **subsumed** (Consolidate), or **redundant** (Delete).
- **Retrieval-Value Test** — before keeping two docs separate: "would having these as separate docs improve discoverability six months from now, or just create drift risk?" Separate docs earn their keep only when they cover genuinely different sub-problems, target different audiences, or merging would produce an unwieldy doc.
- **Cross-doc conflict check** — outright contradictions between in-scope docs are more urgent than individual staleness; resolve via Consolidate (one is a stale version of the same truth) or targeted Update/Replace.

## Delete Guardrails

Auto-delete only when **all three** hold:

1. **Implementation gone** — the referenced code/workflow no longer exists (or is fully superseded by a clearly better successor, or the doc is plainly redundant with another kept doc).
2. **Problem domain gone** — the concern the doc addresses is no longer live in the codebase, not merely the specific file. A doc about session-token storage where the file moved but the app still handles session tokens is Replace, not Delete — the domain persists under a new implementation.
3. **Citations absent or decorative** — no other doc, plan, or instruction file cites this one substantively.

If any of the three fails, classify as Replace, Update, Consolidate, or stale-mark instead — never delete a doc whose problem domain is still active or whose content is cited substantively.

### Citation Classification

Search markdown content (other docs, plans, instruction files, READMEs — not source code, where citations are rare) for the filename slug before any Delete:

- **Decorative** — a "see also" pointer or bare attribution; the citing content stands on its own. Delete is fine; clean up the citation in the same commit.
- **Substantive** — the citing doc relies on this one for content not restated inline. Signals Replace (write a successor at the same path) or Keep-with-narrowed-scope if the doc's actual content is broader than its title implies.
- **Mixed or unclear** — stale-mark rather than guess.

Removing a citation is always mechanical once the classification is settled; the judgment is upstream, in whether Delete is still the right call given what depends on the doc.
