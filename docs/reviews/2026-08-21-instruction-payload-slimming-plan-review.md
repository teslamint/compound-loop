# Review: Instruction payload slimming plan

- Reviewed artifact: `docs/plans/2026-08-21-001-refactor-instruction-payload-slimming-plan.md` (draft)
- Origin spec: `docs/specs/2026-08-21-instruction-payload-slimming-design.md` (approved `8c00d55`) with Deviation Addendum 014 (`c123b70`)
- Gate: `planning` step 15 deepening / independent plan review, run before the draft commit and human approval gate
- Lane: heterogeneous (`codex exec -s read-only`, GPT-family), three sequential rounds. Each round's dispatch prompt carried the step 5a reviewer mandate verbatim (re-derive the carry-forward audit; attack invariants with cheapest conforming deliverables; grade by threatened success criterion; discrimination/verdict coverage).
- **Status: closed.** Round 1 (`blocked`, 5 P0 + 3 P1 + 1 P2) and round 2 (`blocked`, 1 P0 + 2 P1, findings 1–8 all ADDRESSED) were each fully repaired in the plan before the next round; round 3 verified findings 9–11 ADDRESSED, found zero new P0s, and returned `clean`.
- Audience: a reader with no memory of the authoring conversation.

## Round 1 — verdict `blocked`

| # | Sev | Finding (condensed, reviewer's wording) | Disposition |
|---|---|---|---|
| 1 | P0 | Carry-forward audit omitted two latched-fired rows: Schema validators + fixtures (plan/v1 half recorded fired 2026-07-26) and `gh pr merge --delete-branch` (recorded **Fired in PR #15**) — "omitted fired row is blocking" | **Fixed.** Both rows added to the Fired table with latching class and Deferred dispositions; matching Deferred entries added |
| 2 | P0 | No unit produced the spec's independent baseline-vs-HEAD assertion-inventory comparison; cheapest deliverable keeps case counts while no-op-ing assertions (SC4) | **Fixed.** U1 section (d) now captures per-validator assertion inventories (`grep -n` output verbatim at baseline); U8 requires the reviewer's per-validator comparison with a no-loss verdict |
| 3 | P0 | R10 accounting: duplicate/conflicting classifications for one removal were not rejected — cheapest counterexample records both `moved` and `compressed` (SC1/SC5) | **Fixed.** Exactly-one-row rule in U6 Produces; U7 check (b) rejects no-row, out-of-set, duplicate, and conflicting rows; self-test injection (b3) added |
| 4 | P0 | Comparison steps lacked invariance/changed-axis pairs; R7 check (a) was never attacked (SC3–SC6/SC8) | **Fixed.** U2/U3/U4/U5/U6 each carry an invariance run plus a scratch-copy changed-axis probe; U7 self-test gains injection (a1) proving the removal set is diff-derived |
| 5 | P0 | U8 attack/verdict state machine incomplete: no next step for unresolved or out-of-set outcomes; repairs after the attack round left stale attack evidence satisfying SC6 | **Fixed.** Outcome set {caught-by-target, caught-by-unrelated, not-caught, unresolved} each with a blocking next step; out-of-set outcome itself blocking; attack records bound to a tree sha with restart-on-repair |
| 6 | P1 | U1–U4 acceptance loopholes: empty-section U1 pass; U2 grep self-contradiction (pointer contains the grepped token); U3 retained rules satisfiable from comments/fences; U4 missing pointer-form and fail-closed checks | **Fixed.** Structural non-emptiness in U1; JSONL/marker/pointer-regex triple in U2; operative-body-prose requirement and pointer regexes in U3/U4 |
| 7 | P1 | U5–U8 acceptance loopholes: filler survival cells; title-only parity rows; unverifiable reviewer identity | **Fixed.** U5 mechanical substring completeness check with deleted-row probe; U7 per-record required fields; U8 identity record (lane, command, identifiers, non-authorship statement) |
| 8 | P1 | Command closure: `<branch-base>`, `<tmp>`, `<name>`, `<extraction awk>`, `<reference file>`, `<cache>` unassigned | **Fixed.** All replaced by in-step assignments (`BASE_REF=$(git merge-base main HEAD)`, explicit `for name in ...` loops, literal awk pipelines, `CACHE=` definition inside the ROADMAP row) |
| — | P2 | Feasibility re-measurement matched all eight recheck rows and Addendum 014 (137,024; 4,561; M-block bytes; portability counts); no Scope Out violation found; mutation-heavy suites unrunnable in the reviewer's read-only sandbox — environment limit, not a contradiction | No action; writable-tree suite runs are every unit's acceptance |

## Round 2 — findings 1–8 all ADDRESSED; verdict `blocked` on three new findings

| # | Sev | Finding | Disposition |
|---|---|---|---|
| 9 | P1 | Re-derived ROADMAP audit found `Project-defined lane schema` (ROADMAP line 18) absent from both Fired and Not-fired lists while the plan attested all 13 Future-candidate rows examined | **Fixed.** Row classified event-based, not fired, with reason (`reviewing`'s lane text moves nothing; no second project defines lanes) |
| 10 | P0 | SHA circularity: attack records were required to carry a sha equal to the final pre-Ship HEAD, but committing the records changes HEAD — the stated identity proof is unsatisfiable | **Fixed.** Records bind to the implementation-tree sha `git log -1 --format=%H -- skills/ scripts/`, re-compared at Ship entry; evidence-only commits never invalidate attacks |
| 11 | P1 | U6 acceptance said "every line" of the diff (including added lines) while R10's scope is removed/changed lines — internally inconsistent inventory contract | **Fixed.** Acceptance scoped to removed-or-changed baseline lines; added-only lines are in-row replacement text, never their own rows |

## Round 3 — verdict `clean`

Findings 9–11 verified ADDRESSED (evidence lines 294, 258/266, 211–222). New P0 findings: none. Verbatim verdict line: `VERDICT: clean`.

## Residual notes

- Semantic adjudication of `compressed` entries, description non-inversion, and the six SC6 attack classes are deliberately owned by U8's independent reviewer at implementation time — the plan gate verified the machinery exists and can fail, not the future verdicts.
- The implementation-review dispatch must carry the plan's Architecture-notes mandate block verbatim (step 5a travel rule); this file records that obligation for the reviewing phase.
