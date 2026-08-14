# Review: Planning discrimination and verdict coverage plan

- Reviewed artifact: `docs/plans/2026-08-15-001-fix-planning-discrimination-and-verdict-coverage-plan.md` at draft commit `682e059`
- Origin spec: `docs/specs/2026-08-15-planning-discrimination-and-verdict-coverage-design.md` (approved)
- Gate: the plan approval gate. The user declined to approve on the draft alone and asked for an independent review first
- Lanes: two, both read-only, dispatched in parallel, both carrying three instructions verbatim — step 5a's re-derive mandate, ROADMAP row 59's invariant-attack construction, and ROADMAP row 60's severity rule
  - **Lane 1 — native reviewer subagent** (Claude). Design judgment: invariant attack, architecture-unit clause consistency, acceptance soundness, schema conformance, scope discipline. Full structured output committed beside this file as `2026-08-15-planning-discrimination-and-verdict-coverage-plan-review-r1-native.json`
  - **Lane 2 — heterogeneous** (`codex exec -s read-only`, GPT-family). Mechanical verification: re-derive the audit independently, run every acceptance command against the pre-change tree, check schema conformance, verify every named path, line, and SHA
- Verdicts: Lane 1 `incorrect` — 1 P0, 2 P1, 3 P2 plus one informational mandate-discharge row. Lane 2 `3 P0, 4 P1, 0 P2`
- **Status: closed.** Every finding was applied to the plan before approval. Two required a deviation addendum because they amend wording the approved spec fixes: `docs/deviations/2026-08-15-discrimination-axis-and-out-of-set-verdict-012.md`
- Audience: a reader with no memory of the authoring conversation

## The two invariant-attack findings

Both lanes were told to construct the cheapest plan step that satisfies every written clause while still being the defect the check exists to catch. Lane 1 succeeded twice.

**Sixth loophole (P0) — the changed input was never bound to the axis under test.** A step verifies that `--optimize` took effect by comparing digests of `coremldata.bin` with and without the flag, where the flag in fact only rewrites `weights.bin`. The fixture is two `coremldata.bin` digests: same artifact kinds, same producing pipeline. Same inputs compare equal, observed; the changed input — a swapped source package — compares different, observed. Every clause of the pre-amendment wording passes, and the approved spec's own SC2 accept rubric blessed the same construction, so the criterion would have certified a comparison that is constant along the axis it exists to measure. Fix applied: `and the changed input is the very input or option whose effect the step exists to detect, never an arbitrary one`, plus an amended SC2 accept case and a third reject case.

**Seventh clause (P1) — verdict values outside both enumeration sources.** The measuring step is `grep -c pattern file` with a declared output set of `{0, 1}`; the spec asks only whether the pattern appears, so it enumerates nothing larger. The union is `{0, 1}` plus unresolved, each value branched, nothing unconsumed — and the measurement returns `2`, a value that resolved cleanly, sits in neither source, and has no branch. Fix applied: `include the measurement failing to resolve, or resolving to a value outside that set, among the values`.

Neither loophole was reachable from the Design-gate attack's five repairs. The invariant attack found new holes on a second pass against tighter wording, which is the argument for running it at every gate rather than once.

## Findings and dispositions

| Lane | Severity | Finding | Disposition |
|---|---|---|---|
| 1 | P0 | Discrimination check's changed input unbound to the axis under test; SC2's accept rubric blessed the loophole | **Fixed** via addendum 012: axis-binding clause added, SC2 gains reject case B and an amended accept case |
| 2 | P0 | Fired rows 12, 13, 59, 60 carried dispositions that are neither step 5a arm — audit-cell text only, or "folded" into a phase procedure rather than a named unit | **Fixed**: each now has a Deferred to Follow-Up Work entry naming the row and the reason; 59 and 60 record that they were satisfied procedurally this cycle while their durable-rule change stays open |
| 2 | P0 | The claim "No cross-reference in any file cites a step 14 bullet by ordinal" is false — this cycle's own spec, plan, and spec review all do | **Fixed**: the claim is narrowed to what a grep confirms — every ordinal reference sits inside this cycle's three documents, and references elsewhere name bullets by title |
| 2 | P0 | Architecture notes named `references/deepening.md`, which does not exist; the real path is `skills/planning/references/deepening.md` | **Fixed** |
| 1 | P1 | Verdict values outside both enumeration sources escape the union clause | **Fixed** via addendum 012 |
| 1 | P1 | U1 and U2 acceptance assert absolute counts (11, then 12) while U3's note said the two "may land in either order", so the authorized order U2→U1 would red-flag a correct implementation | **Fixed**: U2 declares `Depends on: U1`, and the either-order sentence is gone |
| 2 | P1 | The position probes `sed -n '4p'` and `tail -1` exit 0 whether or not the position is right — they report, they do not assert | **Fixed**: both pipe into `grep -q`, and every count comparison is a `test`, so each command exits nonzero on a wrong implementation |
| 2 | P1 | U3's byte-identity check named no executable command, and a single-line `grep -F` cannot establish identity for a wrapped bullet | **Fixed**: U3 step 3 carries an executable extraction-and-compare sequence; the payload quotes the bullet unwrapped so normalization has one line to work on. The sequence was exercised both ways before commit — identical input compares equal, a one-character mutation compares different |
| 2 | P1 | `grep -c 'gh issue' docs/issue-closures/*.md` never emits a bare `0` for two files, and the pattern was narrower than the step it enforces | **Fixed**: `test "$(grep -lE 'gh (issue\|pr\|api\|repo\|release) ' docs/issue-closures/*.md \| wc -l \| tr -d ' ')" = 0` |
| 2 | P1 | Clause probes were scoped to the whole skill file, so either phrase could be added outside step 14 and still pass | **Fixed**: every clause probe is scoped to the step 14 range |
| 1 | P2 | Row 55's trigger classifies as edit-based under step 5a's tiebreak, not event-based | **Fixed**: reclassified as edit-based by tiebreak, verdict and disposition unchanged |
| 1 | P2 | Latched rows 12 and 13 had no Deferred-section entries | **Fixed** — same repair as Lane 2's first P0 |
| 1 | P2 | U3's multi-file `grep -c` output shape and single-line identity phrasing | **Fixed** — same repairs as Lane 2's P1s |

## Mandate 1 discharged: the audit re-derived independently, twice

Both lanes enumerated `ROADMAP.md`'s open rows from the tracker rather than from the plan's table, applying latching and the tiebreak, and both arrived at the plan's counts:

> Open rows: Future candidates lines 12–23 = 12 rows, none struck; Carry-forward lines 44–62 = 19 data rows of which 10 are struck, leaving 9 open. Total 21. Fired set: {12, 13, 55, 57, 59, 60, 61} = 7. No drift-based triggers exist, so 0 unobservable.

Lane 2 reproduced the same set and added that `68ffafe` exists and its ROADMAP is byte-unchanged through HEAD. Zero omitted fired rows, so the mandate's blocking class is empty; the divergences both lanes found were about disposition form and one classification label, all repaired above.

Lane 1 also noted that row 57's firing is over-inclusive — the row's third arm literally reads "into loop state", which U3 avoids by writing a committed path. Over-inclusive firing is the safe direction and the plan keeps it.

## What both lanes confirmed

- Hard-floor sections present in schema order; non-code unit template used; the stateless-fallback sentence byte-exact (`grep -Fxc` → 1).
- Filename, `type`, `execution`, `status`, `date`, `origin`, and `schema` valid; `validate-plan-frontmatter.py` exit 0.
- `bash scripts/validate.sh` exit 0 (`ALL CHECKS PASSED`) and `bash scripts/test-retro-format-drift.sh` exit 0 (44 cases) on the pre-change tree.
- With current ordering, Scenario coverage is bullet 3, so Verdict coverage becomes bullet 4; Command closure is last, so Discrimination check becomes bullet 12 and last.
- The recorded pre-change red values reproduce: `10` bullets and `0` name matches.
- Scope is clean against the spec's Scope/In and Scope/Out; nothing exceeds issues #11 and #12.

## Note on Lane 2's transcript

Lane 2's raw transcript is 3571 lines and includes session noise, MCP auth errors, and whole-file dumps, so it is not committed — `designing` Step 10 forbids committing unbounded raw output. Its findings and its re-derived audit table are reproduced above and in the dispositions; the working copy lived at `.release-loop/reviews/plan-review-r1-mechanical.txt` for the duration of the loop.
