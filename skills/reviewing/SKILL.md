---
name: reviewing
description: "Multi-lane code review producing verified, deduplicated findings (mode:agent JSON per review-envelope.schema.json, or markdown pipe tables), and disciplined consumption of reviews received from anyone else. Use via /reviewing (Claude Code) or $reviewing (Codex): mandatorily after each subagent task, after completing a major feature, or before merge; optionally when stuck, before refactoring, or after a complex bugfix; whenever release-loop's Review phase fires; or whenever external feedback (a human reviewer, a bot, another agent) needs disciplined evaluation before you implement it."
---

# Reviewing

Purpose: produce multi-perspective findings that are verified and deduplicated -- or process someone else's findings without performative agreement. Every lane emits the identical `schemas/lane-findings.schema.json` shape so merge logic never special-cases a lane.

## Entry / Exit / Gate

- **Entry**: a diff to review (standalone), or all implementation tasks complete (phase-gate, called from `implementing`).
- **Exit**: verdict `clean` | `actionable` | `blocked` (see Output).
- **Gate**: AUTO -- advances on `clean`; `blocked` (open P0/P1) escalates to the caller/user, never silently advances.

Trigger taxonomy (SP): **Mandatory** -- after each subagent task, after a major feature, before merge. **Optional** -- when stuck, before refactoring, after a complex bugfix.

## Argument Parsing

Parse tokens, stripping each before treating the remainder as a PR number/URL/branch:

| Token | Effect |
|---|---|
| `mode:agent` | Report-only: JSON envelope, no local apply, no lane-selection change |
| `mode:headless` | Deprecated alias for `mode:agent` |
| `mode:report-only`, `mode:autofix` | Deprecated -- silently ignored, normal flow proceeds |
| `base:<ref>` | Explicit diff base on the current checkout; conflicts with a PR/branch target -- stop with a one-line reason if both are given |
| `plan:<path>` | Plan file for Requirements Completeness (Step 2) |

## Two Things This Skill Does

**Producing** -- the flow below: discover scope, dispatch lanes, merge, verify, output. **Receiving** -- when invoked with feedback already in hand (pasted review comments, a GitHub review, another agent's findings) rather than a scope to review: skip straight to `references/receiving.md`, no lane dispatch.

## Two Caller Shapes

- **Standalone**: direct invocation per the trigger taxonomy above.
- **Phase-gate** (`release-loop`'s Review phase): deliberately redundant with `implementing`'s final task-level review -- it catches issues surviving all fix rounds and gives the user a clean checkpoint between "code complete" and "ready to ship." If `implementing`'s last review already came back clean, verify that state and advance without a full re-dispatch.

## Step 1: Scope Discovery

Resolve `base`/`head`/`mode` with the 3-check test -- all three must hold for `local-aligned`; any failure means `pr-remote`/`branch-remote`, and workspace file contents for changed paths are not trusted:

1. The current checkout's branch equals the target's head branch (or `base:` was given explicitly).
2. The target is not cross-repository (not a fork PR).
3. The target's head commit is an ancestor of HEAD (the tree actually carries it, including unpushed local fixes).

Untracked files: review tracked changes only, list exclusions. No base resolvable: stop -- never fall back to a bare working-tree diff, that silently drops committed work. The resolved mode maps to `schemas/review-envelope.schema.json`'s `scope.mode` enum -- do not invent new mode names.

## Step 2: Intent + Context Discovery

Write a 2-3 line intent summary (PR title/body, commits, `plan:`, conversation) and pass it to every lane -- it shapes depth, not lane selection. Fold the following in as context, never as lanes:

- **Requirements Completeness artifact set**: when review is checking requirements completeness, treat the approved spec, the approved plan, every applicable committed file discovered under `docs/deviations/` whose Original contract and/or Traceability identifies that approved spec and/or plan as its source, and any explicitly handed-off deviation references as one contract set. The link direction is addendum -> approved source: never require or expect approved artifacts to grow backlinks to later addenda. Use `docs/solutions/workflow-issues/review-introduced-state-machine-deviation.md` for the observable-behavior definition, addendum contents, the incomplete-release recovery example that requires an addendum, and the internal-refactor exemption when interfaces, state transitions, persistence, consent boundaries, and terminal behavior are unchanged.
- **Stateful ceremony evidence**: for task review, inspect the approved plan's Mutation/failure-state matrix together with `.release-loop/evidence/U<N>/`; for final branch review, inspect that matrix together with every accumulated unit evidence directory. Match one concise sanitized record at `.release-loop/evidence/U<N>/<transition-id>-<outcome>.md` to every applicable cell. Each record must identify the plan and matrix row, source commit, fixture identity, and timestamp; prove isolation with the disposable fixture root, complete configured target inventory, applicable stub identity, and a boundary sentinel; and retain pre-state, exact injection or command, exit status, concise output, post-state, relevant next-invocation result, and a mechanism check proving the intended boundary failed rather than setup or unrelated validation. Inspect isolation proof before executing or accepting fixture evidence; evidence must use only disposable local fixtures, local bare remotes, and stubs, remain sanitized, and never reach a real outward or production target. When the approved plan says `No stateful ceremony in the deliverable; no mutation/failure-state matrix required.`, honor that stateless fallback and require no irrelevant evidence records.
- **Plan discovery**: `plan:` arg > a single unambiguous PR-body match > branch-keyword auto-discovery; tag `plan_source: explicit | inferred`. Feeds Requirements Completeness in Step 8.
- **Learnings**: check `docs/solutions/` for prior issues touching this diff's modules; surface hits as "Known Pattern."
- **Previous comments**: PR-only, and only when prior review threads exist -- fold into context so lanes verify comments were actually addressed, rather than spawning a redundant lane for it.

## Step 3: Lane Selection

4 always-on (correctness, tests, architecture, standards) + 5 conditional (security, adversarial, resilience, api-contract, migration) + N project-defined lanes read from the repo's `AGENTS.md`/`CLAUDE.md` (extension point; free-form, no schema beyond the standard lane-findings output). Full trigger/focus/non-flags per lane: `references/lanes.md`. Announce the team with a one-line justification per conditional/project-defined lane selected -- progress reporting, not a blocking confirmation.

## Step 4: Dispatch

Degradation ladder per `references/dispatch-degradation.md` (native parallel -> sequential passes -> single-call fallback; capacity errors are backpressure, never lane failure). **Model tiering**: `correctness`, `security`, and `adversarial` inherit the session model (highest-stakes analysis); every other lane runs on the harness's mid-tier model. The orchestrating pass (this skill) also inherits the session model.

## Step 5: Merge, Dedup, Confidence Gate

Full pipeline in `references/merge-pipeline.md` (fingerprint dedup, cross-lane promotion, mode-aware demotion, confidence gate last with the P0-at-50 exception, atomic artifact writes). Severity is **P0-P3 everywhere** -- the envelope's critical/important/minor `rollup` is a presentation-only projection, never a second severity scale.

## Step 6: Verification (dual path)

- **Interactive** (default mode, standalone or phase-gate in a chat session): a validator wave -- one independent validator per surviving finding, budget cap 15 (never drop a P0/P1 to fit the cap; raise it instead). Protocol and infra-failure handling: `references/merge-pipeline.md`.
- **Pipeline / headless / `mode:agent`**: a capped re-review loop instead -- cheaper, same intent (`enforces: P9`). Cap **3 rounds** (review -> fix -> re-review); re-review always receives the **original** findings list to verify each was addressed. After 3 rounds: only minor survivors -> advance; any P0/P1 survivor -> escalate to the caller/user, never silently absorb.

## Step 7: Fix Dispatch (mode-dependent)

- **Interactive**: bias-to-act -- apply clear, reversible improvements without a severity gate; push back and keep the finding when the lane is wrong; commit only when the pre-review tree was clean (`fix(review): <summary>`, or the repo's nearest convention). **Never push, open a PR, or file a ticket** -- outward steps belong to the human (`enforces: P7`).
- **Pipeline**: **ONE** fixer subagent gets the complete findings list -- never one fixer per finding, that rebuilds context and reruns suites redundantly. The fixer reports what changed, tests run, and results.

## Step 8: Output

- **Default**: markdown, pipe-delimited finding tables grouped by severity (no `Field:` blocks, no box-drawing separators, ASCII `->` not middot) plus an Actionable Findings summary.
- **`mode:agent`**: one raw JSON object -- no code fence -- matching `schemas/review-envelope.schema.json` exactly. `clean` = no P0-P2 actionable findings; `actionable` = fixable findings present; `blocked` = open P0/P1 the caller must resolve before advancing.

Requirements Completeness rule: if the diff confirms observable behavior absent from or contradictory to the approved artifact set, and no separate committed deviation addendum records that behavior, the finding stays actionable and the verdict cannot be `clean`. Preserve the existing plan-conflict handling outside this skill's suppression logic: a plan-mandated conflict still goes back to the caller/human rather than being silently authorized by the addendum rule.

Stateful ceremony evidence gate: a finding remains actionable and the verdict cannot be `clean` when any applicable matrix cell or corresponding evidence record is missing; isolation is unproved or a real target remains reachable; the observed failure came from the wrong mechanism; or the observed post-state, rerun, rollback or compensation, headless, or cancellation or abort behavior differs from the approved matrix. A post-approval change to a matrix row or outcome is observable behavior and requires item 1's separate committed deviation addendum before review can return `clean`; do not rewrite the approved matrix or treat evidence of the new behavior as authorization.

Layer-mismatch rule: when a completion claim in the reviewed material rests on best evidence sitting below the claim's layer (evidence-tier ladder and layer-mismatch, defined in the repo's `CONCEPTS.md` where present), that is an actionable layer-mismatch finding, and the verdict cannot be `clean` while it stands. When no spec criterion or requirement implies a claim layer, the mismatch test is undecidable -- file an unverifiable-claim finding naming the missing layer instead. Layer-mismatch findings pass through the normal Suppression Policy like any lane finding, with no special exemption. This rule binds findings and verdicts (structured output), not the reviewer's surrounding prose.

## Suppression Policy

Before any finding survives to a report, check it against `references/suppression.md` -- the merged false-positive catalog and protected-artifact list. A finding matching a suppression category is dropped outright, never routed to a soft bucket.

## Receiving a Review

When someone else's feedback is the input, not a diff you're dispatching lanes over: follow `references/receiving.md` in full -- read, verify against codebase reality, evaluate, then respond and implement. Forbidden performative agreement applies regardless of who wrote the feedback.

## Handoff

Standalone: report and stop. Phase-gate: return the verdict to `release-loop`, which advances on `clean` or escalates on `blocked`.
