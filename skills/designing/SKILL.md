---
name: designing
description: Turn a feature idea into an approved, committed spec with measurable success criteria via collaborative dialogue. /designing or $designing when starting new feature work, when release-loop's Design phase fires, or whenever implementation is about to begin without an approved design -- including work that looks "too simple to need one".
---

# Designing

Answers **WHAT** to build, not **HOW**. The durable output is an approved spec strong enough that `planning` never has to invent product behavior, scope boundaries, or success criteria.

## Entry / Exit / Gate

- **Entry**: a feature idea, problem, or improvement to explore (direct invocation, or release-loop's Design phase without `--skip-design`).
- **Exit**: spec file committed to git, frontmatter `status: approved`, user approved.
- **Gate**: USER — spec approval is always human. Never auto-skip this gate.

## Hard Gate

<HARD-GATE>
Do NOT invoke any implementation skill, write production code, or take any implementation action until a design has been presented and the user has approved it. This applies to EVERY project regardless of perceived simplicity.
</HARD-GATE>

**Anti-pattern: "This Is Too Simple To Need A Design."** A todo list, a single-function utility, a config change — all go through this process; the design can be a few sentences, but it must be presented and approved. `enforces: P6`

## Step 1: Explore Context

Before asking anything, run:

```
git log --oneline -20
cat AGENTS.md CLAUDE.md ROADMAP.md 2>/dev/null
ls docs/retros/*.md 2>/dev/null | tail -5   # carry-forward candidates
cat CONCEPTS.md 2>/dev/null                 # authoritative vocabulary, if present
cat STRATEGY.md 2>/dev/null                 # target problem/persona, if present
```

Look for carry-forward items from prior retros, existing patterns to follow, and recent changes that constrain the design space. **Verify before claiming absence** — a claim that something doesn't exist (a table, an endpoint, a dependency) must be checked against the codebase, not assumed; if unverified, label it as such.

## Step 2: Scope Check

Flag immediately if the request spans multiple independent subsystems, different owners, or independently-shippable parts. Decompose into sub-projects first; each gets its own `designing` cycle. Don't spend dialogue refining a project that needs splitting first.

## Step 3: Scope Tiering

Classify before choosing ceremony:

- **Lightweight** — small, well-bounded, low ambiguity.
- **Standard** — normal feature or bounded refactor with real decisions to make.
- **Deep** — cross-cutting, strategic, or highly ambiguous. Sub-classify:
  - **Deep-feature** (default): existing product shape anchors decisions.
  - **Deep-product**: primary actors, core outcome, or positioning against adjacent products are materially unresolved — the brainstorm must establish product shape, not inherit it.

Tier gates probe depth (Step 5) and which spec sections are material (Step 8). If unclear, ask one targeted question, then proceed. `enforces: P6`

## Step 4: Fast Path

*(Scope note: the fast path skips dialogue steps only — Steps 10–12, independent review through the human gate, always still apply.)*

If the request already has specific acceptance criteria, references an existing pattern to follow, and describes exact expected behavior with constrained scope, skip Steps 5-6. Confirm understanding, present a short spec only when a durable handoff to `planning` would help, and move on.

## Step 5: Rigor-Gap Probes

Before proposing approaches, scan the opening for gaps: evidence, specificity, counterfactual, attachment (+durability for Deep-product). This is internal analysis — raise only the gaps actually present, folded into normal dialogue, never as a checklist fired at the user. See `references/rigor-probes.md` for the gap definitions, concrete probe questions, and tier scaling (skip Lightweight / 4 for Standard / 5 for Deep-product). **One gap = one open-ended probe** — never bundle two gaps into one question. `enforces: P4`

## Step 6: Collaborative Dialogue

Follow `references/question-tools.md` for the blocking-tool table and the open-ended-vs-menu test. Ask what the user is already thinking before offering your own framing. Start broad (problem, users, value), then narrow (constraints, exclusions, edge cases). All rigor-gap probes from Step 5 must fire before Step 7.

**Integration check before exiting dialogue**: mentally combine what's been said so far (user-stated X + user-stated Y + your default Z) and probe any non-obvious downstream consequence the one-question-at-a-time flow hasn't surfaced yet — one probe per genuine combination effect.

Exit when the idea is clear and no integration-check questions are pending, or the user explicitly wants to proceed.

## Step 7: Propose Approaches

If multiple plausible directions remain, present 2-3 concrete approaches; otherwise state the recommendation directly.

- **Anti-anchoring**: present all approaches before recommending — a recommendation shown first anchors the conversation prematurely.
- **Granularity discipline**: name mechanism-level distinctions and product-relevant trade-offs (e.g. "pause as a rule property" vs "pause as an event filter"), never implementation specifics (column names, file paths, service classes) — those are `planning`'s job.
- Use at least one non-obvious angle (inversion, constraint removal, analogy) rather than variations on one axis.
- Optionally include one deliberately higher-upside challenger alongside the baseline — omit when the baseline is clearly right or the work is already over-scoped.

Template per approach:

```markdown
**Approach A: [Name]**
- How: [mechanism-level description]
- Pro: [main advantage]
- Con: [main disadvantage]

**Recommendation:** Approach A because [reason].
```

## Step 8: Present Design

Present in sections scaled to complexity (a few sentences when straightforward, up to 200-300 words when nuanced), asking after each section whether it looks right. Order — **User Scenarios before Architecture** (motivation before mechanism):

1. User Scenarios (3-6 concrete, with CLI/MCP examples)
2. Architecture — module structure, data flow
3. Interface — public API, CLI flags, config
4. Data model
5. Integration
6. Testing strategy
7. Risks and mitigations
8. **Success Criteria — REQUIRED.** Every criterion states what is measured and how: a proving command for hard metrics, a judgment rubric for soft ones. No source skill mandates this section; it is a deliberate elevation so `retrospective` can measure declared vs. actual. `enforces: P4`
9. Open Decisions

Design-for-isolation test per unit introduced: what does it do, how is it used, what does it depend on — can a reader understand it without internals, and change internals without breaking consumers?

## Step 9: Write Spec Document

Path: `docs/specs/YYYY-MM-DD-<topic>-design.md`. See `references/spec-template.md` for the section skeleton, Spec Quality Signals, and the required Success Criteria shape.

Frontmatter carries `status: draft` while under review; flip to **`status: approved` only after Step 12's human gate** — `release-loop`'s `--skip-design` flag depends on finding this exact record. `enforces: P8`

Requirements get stable R-IDs, grouped by concern, only when the spec's scope warrants tracking them individually (see reference).

## Step 10: Independent Review Gate

Before the user sees the spec, get a review from a fresh perspective — distinct from the user's own review in Step 12. Dispatch per `references/dispatch-degradation.md`: native reviewer subagent (most capable model) first; the `advisor` tool if the harness provides one and no subagent primitive exists; if neither is available, state that explicitly and perform a distanced self-review pass instead of skipping silently.

Treat independent review as mandatory for schema or pipeline changes, not optional ceremony.

**Empirical grounding sub-step** (pilot-proven, `enforces: P3`): any spec example that names a specific existing file, line, or behavior — especially Testing-section fixture targets — must be checked against the live repo (grep/dry-run), not just reviewed for internal logic. Two independent reviews of the same spec both missed a fixture target that a one-line grep would have falsified; internal-logic review and live-repo grounding are different checks (see docs/solutions/workflow-issues/spec-review-empirical-grounding-gap.md where present).

**Live assumption evidence**: whenever a spec makes a live assumption, retain it in `Assumptions and Preconditions` with exactly these five fields: claim, exact command, observation timestamp, concise result, and evidence source. Independent review must rerun the retained command or inspect the retained evidence source before treating the assumption as grounded. Never commit secrets, credentials, personal data, or unbounded raw command output as evidence; when output is unsafe or too large, store a committed sanitized evidence artifact and reference that artifact from the retained record instead of pasting the raw output. For post-approval observable-behavior drift and addendum content authority, link to `docs/solutions/workflow-issues/review-introduced-state-machine-deviation.md` rather than duplicating its guidance.

## Step 11: Spec Self-Review

Five fixed checks, fixed inline, no re-loop:

1. **Placeholder scan** — any TBD, TODO, incomplete section, vague requirement ("appropriate error handling")?
2. **Internal consistency** — do sections contradict each other?
3. **Scope check** — focused enough for a single implementation plan, or does it need decomposition?
4. **Ambiguity check** — any requirement interpretable two ways? Pick one, make it explicit.
5. **Principle-exception composability** — does an Architecture principle conflict with a requirement's mandated mechanism? If so, name the carve-out in the spec and cite the requirement that justifies the exception — don't leave the reconciliation to planning.

Then the **contradiction-in-one-pass test**: could a careful reader find a contradiction in any section in a single read-through?

## Step 12: Human Approval Gate

> "Spec written and committed to `<path>`. Review it and let me know if you want changes before we move to planning."

Wait for the user's response. Changes requested → revise, re-run Step 11, re-commit. Approved → set `status: approved` in the frontmatter, commit, advance. **USER — always human. Never auto-skip.** `enforces: P7`

## Step 13: Vocabulary Capture (tail, conditional)

Runs only when `CONCEPTS.md` already exists at repo root — creation and bootstrapping stay owned by `compound`/`compound-refresh`. Domain terms are born in design dialogue, and waiting for a solved problem to capture them leaves the glossary blind to them; this step is the capture point at birth. `enforces: P5` (one canonical term, defined once).

After the approval gate: scan the dialogue and the spec for **resolved** domain terms — terms whose precise local meaning the conversation actively pinned down, not terms mentioned in passing. Resolved means settled, not still under discussion; it runs last because the final canonical name often emerges only at approval. For each: add if missing, refine if new precision surfaced, no action if consistent. Glossary purity rules follow `compound`'s: domain entities, named processes, and status concepts only — no file paths, class names, or implementation decisions. Apply edits silently.

## Handoff

The only skill invoked after `designing` is `planning`. Do not invoke any implementation, frontend, or scaffolding skill from here.

Out of Scope moved to `references/out-of-scope.md`.

