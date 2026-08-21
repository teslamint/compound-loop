# Review: Instruction payload slimming spec

- Reviewed artifact: `docs/specs/2026-08-21-instruction-payload-slimming-design.md`
- Gate: `designing` Step 10 independent review, run before the human approval gate
- Lane: heterogeneous (`codex exec -s read-only`, GPT-family, model `gpt-5.6-sol`), three sequential rounds against the then-current spec wording. The native reviewer subagent lane was attempted first and failed at dispatch (harness error "No model selected"), so the ladder degraded to the heterogeneous lane per `references/dispatch-degradation.md` — stated here rather than skipped silently.
- Round 1 session id: `01a0248f-f71d-7800-af44-7ec73cf39e8e`. Rounds 2–3 ran in the same environment; their session ids were not captured in the retained output.
- **Status: closed.** Round 1 (`blocked`, 11 findings) and round 2 (`blocked`, 9 findings) were each fully repaired in the spec before the next round; round 3 returned `approve-with-P2s` with 2 P2s, both repaired before the human gate.
- Audience: a reader with no memory of the authoring conversation.

## Why this file exists

The ROADMAP carries an open row: *"Facilitator and reviewer output is never persisted, so review claims rest on ledger summaries rather than the reviewer's own words"* (2026-08-15 retro-interview-integrity retro, P3). This file discharges it voluntarily for this cycle, because the loop's working copies would otherwise live only in conversation (`docs/solutions/workflow-issues/loop-deliverable-in-disposable-state.md`).

Raw transcripts are not committed: each round is 2,000+ lines of session/hook noise, and `designing` Step 10 forbids committing unbounded raw command output. Each round's findings and verdict line are reproduced below in the reviewer's own wording, condensed only by dropping repeated evidence command output.

## Round 1 — verdict `blocked` (1 P0, 7 P1, 2 P2, 1 environment note)

| # | Sev | Finding (reviewer's wording, condensed) | Disposition |
|---|---|---|---|
| 1 | P0 | "이동 무결성과 압축 규칙이 서로 양립하지 않습니다" — R7 required every removed block verbatim in a reference while R5/Architecture licensed compression; block boundaries and compression tracking undefined | **Fixed.** R10 disposition inventory added: every scoped removal classified `moved` or `compressed` (original + replacement + rationale) |
| 2 | P1 | 95,000-byte ceiling unevidenced: firm moves 17,181B; generous R3 +8,186B → 106,379B remaining; "방어 가능한 상한은 105,000B" | **Fixed.** Ceiling set to 105,000; 95,000 demoted to explicitly conditional stretch |
| 3 | P1 | Move selection deferred to planning violates the spec boundary; one candidate (`planning` Out-of-Scope) does not exist | **Fixed.** M1–M9 table fixes source, boundaries, bytes, destination, trigger, retained core; reselection is a spec deviation |
| 4 | P1 | Evidence table recorded ×10 where the actual count is ×11, and one measurement was "analogous range", not an exact command | **Fixed.** ×11 (3+3+3+2) with the exact counting command; full M6 `awk` command recorded |
| 5 | P1 | `test-plan-consumer-portability.sh` copies no `references/` and is vulnerable to a duplicate-marker/stale-copy attack | **Fixed.** R6: fixture copies `references/`, parser resolves the pointer's exact destination, marker pair must exist exactly once per consumer tree |
| 6 | P1 | Validator inventory incomplete — heading-range extractions, mutation paths, diagnostic filenames pinned by `test-retro-format-drift.sh`, `test-signal-drift.sh`, `validate.sh`, `test-plugin-skill-discovery.sh` | **Fixed.** R6 names all five validators with per-validator migration obligations |
| 7 | P1 | Loading-surface (plugin cache) parity absent from success criteria; cache already diverges from HEAD at equal version | **Fixed.** SC7 added (reformulated again in round 2, see finding 17) |
| 8 | P1 | Each SC1–SC7 admitted a cheapest conforming-but-defective deliverable (byte ceilings via deletion; trigger-only descriptions; inverted triggers; narrowed suites; self-manifested R7; three easy attacks; SC7 pre-satisfied by the ROADMAP row) | **Fixed.** SC set rewritten: inventory-bound SC1, hardened SC3 rubric, baseline case floors, diff-derived R7, six enumerated attack classes, ROADMAP row dropped as SC |
| 9 | P1 | "Zero behavior change"를 직접 측정하지 않음 — one dry resume cannot protect the other trigger paths | **Fixed.** SC8 behavior parity: fired/not-fired walkthrough pair per move unit |
| 10 | P2 | SC7 (ROADMAP registration) is out-of-goal and already satisfied | **Fixed.** Moved to Scope Out; replaced by behavior parity |
| 11 | P2 | Mutation-heavy suites could not run in the reviewer's read-only sandbox; must be rerun writable before approval, not recorded as regressions | **Done.** `bash scripts/validate.sh` → `ALL CHECKS PASSED` in the writable tree (2026-08-21T13:45:12Z); recorded in the spec's evidence table as sanity check only |

Verbatim verdict line: `VERDICT: blocked`

## Round 2 — verdict `blocked` (findings 1–11 all ADDRESSED; 1 new P0, 6 new P1, 2 new P2)

Common theme in the reviewer's words: every new seam was self-attestation — "the cheapest conforming implementation can … self-classify each weakening as equivalent; omit hard clauses from the implementer-authored description map; establish reduced test counts after narrowing tests; add six fixture-specific rejection cases; write self-reviewed parity narratives."

| # | Sev | Finding (condensed) | Disposition |
|---|---|---|---|
| 12 | P0 | "Semantic equivalence remains self-attested" — R10 `compressed` rationale had no independent oracle | **Fixed.** Verification Independence section added; independent reviewer adjudicates every `compressed` entry; rejected entries revert or become `moved` |
| 13 | P1 | M-table boundary prose ("rows between", "body") and byte figures described different objects; M6 silently spanned two sections | **Fixed.** Normative block definition: the block is exactly the extraction command's output, headings/markers inclusive; command governs on disagreement; M6 labeled a deliberate two-section unit |
| 14 | P1 | SC3's mapping table was authored inside the deliverable | **Fixed.** Baseline side generated mechanically from `git show da1ffbf:...`; independent reviewer re-derives it |
| 15 | P1 | Coverage floor self-established ("first cycle commit") and no-op case substitution undetected | **Fixed.** Baseline totals from a clean `da1ffbf` worktree run recorded before any test edit; reviewer compares assertion inventories |
| 16 | P1 | SC8 walkthroughs lacked independence, fixtures, and reproducible commands | **Fixed.** Reviewer executes/verifies M5–M9 walkthroughs; records carry reproducible fixture commands and verbatim confirmation |
| 17 | P1 | SC7 "explicitly permits non-completion" — a required criterion satisfiable by deferral | **Fixed.** Reformulated as a registered obligation (ROADMAP row with owner = release-loop completion gate and exact evidence path), the repo's established post-Retro-criterion pattern; measured in-cycle if the release lands in-cycle |
| 18 | P1 | R10's universe ("every baseline line") contradicted its categories once validator changes are counted | **Fixed.** R10 scoped to the seven bodies + thirteen descriptions; validators governed by R6 |
| 19 | P2 | Commit ordering internally inconsistent (test-with-move vs moves-separate-from-compression) | **Fixed.** Commit discipline: move commits (with their test migrations) precede compression commits; dual-purpose validator changes land with the necessitating move commit |
| 20 | P2 | Seeded attacks provable by fixture recognition | **Fixed.** Attacks authored by the independent reviewer after implementation freeze, run against unmodified HEAD validators; validator changes restart the round |

Verbatim verdict line: `VERDICT: blocked`

## Round 3 — verdict `approve-with-P2s` (findings 12–20 all ADDRESSED; 2 new P2)

| # | Sev | Finding (condensed) | Disposition |
|---|---|---|---|
| 21 | P2 | SC6 did not require the failing check to be the targeted invariant — an unrelated failure could count as "caught" | **Fixed.** Each attack is a single-defect mutant with a passing control fixture; caught only when the failing check is the class's targeted invariant |
| 22 | P2 | Baseline provenance contradiction: the Verification Independence section requires clean-`da1ffbf` derivation while the evidence table's `validate.sh` row ran in the drafting working tree | **Fixed.** Evidence row relabeled sanity-check-only; SC4 baseline totals must come from a clean `da1ffbf` worktree |

Verbatim verdict line: `VERDICT: approve-with-P2s`

## Residual notes for planning

- Round 2's feasibility arithmetic (move-only savings 18,745B; ~7–8KB of inventoried compression needed to reach 105,000) is the quantitative basis for SC1; planning should budget compression per skill against it.
- Round 3 was explicitly instructed to stay proportionate to a WHAT-spec; downstream plan-gate and implementation-review invariant attacks remain mandatory per repo convention and are not discharged by this review.
