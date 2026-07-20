# Retro Interview Enforcement — Dry-Run Evidence (U6)

Committed evidence for spec Success Criteria 3–5 (plan U6, origin spec
`docs/specs/2026-07-20-retro-interview-enforcement-design.md`). Three dry runs
of the rewritten `retrospective` interview protocol were executed against this
feature's own implementation arc (branch commits `2491c62..707e86f`). Retro
documents were written to the session scratch directory, never `docs/retros/`;
they are embedded here sanitized (no secrets, no personal data). The facilitator
for run 1 was a fresh-context Claude-family subagent dispatched with artifacts
only; dispatches used: 2 of 5.

## Run 1 — dispatched facilitator (Covers S1)

Checks executed on the produced doc:

- end-of-interview findings check: PASS (3 findings, 0 uncited)
- pre-commit check (transcript section + closed-vocabulary level + rounds-used): PASS
- backward check on newest real doc under `docs/retros/`: `pre-schema, exempt`

SC3 measurement — every `**What happened**:` block carries `**Cites**:`:

```
findings: 3 uncited: 0 []
```

Produced document:

```markdown
# Retro: retro-interview-enforcement implementation arc (DRY RUN 1 — dispatched facilitator)

- Date: 2026-07-21
- Source: ad-hoc (dry run, facilitator dispatched as fresh-context subagent)
- Spec: docs/specs/2026-07-20-retro-interview-enforcement-design.md
- Plan: docs/plans/2026-07-20-002-feat-retro-interview-enforcement-plan.md

## Release data

| Metric | Value |
|---|---|
| **Changed non-test lines** | 159 (151 added + 8 removed) |
| Commits | 5 |
| Review rounds | 5 |
| Comments (fixed / deferred) | 0 / 10 |
| CI failures | 0 |
| Duration (first spec commit → merge) | n/a — dry run pre-merge |
| Units planned / completed | 6 / 5 |

## Success criteria: measured vs declared

| # | Declared criterion | Measurement (command / rubric) | Measured result | Verdict |
|---|---|---|---|---|
| 1 | SC1 template section | `grep -c "Interview Transcript" schemas/retro-template.md` | 1 | Met |
| 2 | SC2 skill defines contract+checks | reviewer rubric | facilitator-verified R1–R5 locatable; committed evidence is ledger summary only | Met per ledger-recorded independent review, evidence artifact uncommitted |
| 6 | SC6 no regression | `bash scripts/validate.sh` | exit 0, ALL CHECKS PASSED | Met |

(SC3–SC5 are measured by the enclosing U6 unit itself; not re-measured inside this dry run.)

## Carry-forward from previous retro

| Item | Status | Evidence |
|---|---|---|
| (from 2026-07-20-entirecontext-mention-removal-retro.md) diff-size-metric review + P4 planning-gate cycle closure | Done | commit 9272910 |

- Previous doc shape: pre-schema, exempt (2026-07-20-entirecontext-mention-removal-retro.md predates the Interview Transcript schema)

## Interview Transcript

- Independence level: same-model fresh-context (facilitator: Claude-family subagent on a different model tier, fresh context; cross-family heterogeneity not claimed)
- Rounds used: 2 (max 5)

| ID | Round | Phase | Probe | Answer | Evidence | Verdict (verbatim) |
|---|---|---|---|---|---|---|
| T1 | 1→2 | 5 | Which artifact records the 10-minor deferral as a decision rather than a drift, and where is each disposition accounted for? | Deferral is the implementing skill's own rule; all 10 minors itemized with stable IDs in dated ledger entries; disposition lands in final branch review | `.release-loop/progress.md` MinorFindings lists; `skills/implementing/SKILL.md` fix-loop rule + final-review mandate | accepted — Verified against artifacts: `.release-loop/progress.md` Log entries itemize all 10 minors with stable IDs (U2-m1…U5-m5, with U5-m3 routing the pre-existing check-5 traceback to Deferred), and `skills/implementing/SKILL.md` records both the deferral rule ("Minor findings → record under the ledger's MinorFindings:, do not fix now") and the final-branch-review disposition mandate ("which Minor findings need fixing"). The deferral is a recorded process decision with per-item accounting, not drift. |
| T2 | 1→2 | 5 | What concrete check caught the stale worktree base — discipline, luck, or a gate — and what proves the reset preceded any work? | Deliberate post-setup verification (`ls` of the plan file exited 1); reflog shows create→reset→first-commit order; first commit's parent is local main | reflog d79aafc→5872802→2491c62; `git log --format="%h parent=%p" -1 2491c62` → parent=5872802 | accepted — Independently reproduced from git: `git reflog show worktree-retro-interview-enforcement` shows `branch: Created from origin/main` (d79aafc) → `reset: moving to main` (5872802) → first commit 2491c62, and 2491c62's parent is 5872802, proving no work ever sat on the stale base. The preflight ledger entry corroborates the deliberate gate ("Worktree created via native tool, reset onto local main at `5872802`; baseline validate.sh ALL CHECKS PASSED") — discipline, evidenced. |
| T3 | 1→2 | 3 | What did SC2's declaration get wrong, and what concrete reviewer artifact makes its Met more than a pass-through? | Rubric choice was deliberate (prose property); weak part is the pass-through phrasing; Met rests on ledger-recorded independent review; two conceded gaps: review report uncommitted, no runnable proxy declared | `.release-loop/progress.md` U2 entry; spec SC2 declaration | accepted — in the answer's own qualified form, which becomes the SC2 record: "Met per ledger-recorded independent review, evidence artifact uncommitted." One correction for the transcript: the ledger's U2 entry records only the summary reviewer output ("Stale-phrasing sweep 0 hits; new text names no tools"), not the claimed itemized R1–R5 line-number rubric — that itemization exists only in the uncommitted session transcript, so plain "Met" is not supportable from committed artifacts, and the conceded gaps (uncommitted review report; no runnable proxy declared for SC2) are themselves finding material. |

## Findings

### What worked well
- **What happened**: The stale worktree base (branched from origin/main, 8 commits behind local main) was caught by a deliberate post-setup verification before any unit commit landed; the facilitator independently reproduced the proof from the reflog.
  **Why**: The orchestrator knew the spec/plan commits were local-only and checked for them in the fresh worktree.
  **How to apply**: After any worktree creation, verify the expected head artifacts exist before entering unit 1.
  **Cites**: T2

### What to improve
- **What happened**: SC2's "Met" could not be supported as plain Met from committed artifacts — the itemized reviewer rubric lives only in the session transcript, and the facilitator downgraded the verdict to its qualified form.
  **Why**: Task-review reports are written to `.release-loop/reports/` (untracked working state) and summarized into the ledger, but the itemized rubric output is not committed as evidence.
  **How to apply**: When a spec criterion's measurement is a reviewer rubric, commit the rubric output (or declare a runnable proxy alongside it at design time).
  **Cites**: T3

### Process observations
- **What happened**: All 10 minor findings were deferred undisposed to the final branch review, per the implementing skill's own rule, with per-item stable IDs in the ledger.
  **Why**: Fix-now churn vs. batch triage is a deliberate process trade recorded in the skill text.
  **How to apply**: Treat MinorFindings IDs as a checklist the final review must enumerate explicitly.
  **Cites**: T1

## Carry-forward items registered

| Item | Type | Priority | Tracked at |
|---|---|---|---|
| (none — dry run registers nothing durable; the SC2-evidence finding is handed to the enclosing arc's real retro) | — | — | — |

## Lessons

- A facilitator with only artifacts and a shell reproduced the respondent's strongest claim (reflog ordering) and demoted its weakest (SC2 plain Met) in one round — the round-trip changed the doc's content, which is the property the protocol exists to buy.

## Compounding

- compound invocation: not attempted — no reusable lesson this cycle (dry run)
```

## Run 2 — headless self-checklist (Covers S4)

SC4 measurement:

```
$ grep -A2 "Independence level" run2-self-checklist-retro.md | head -3
- Independence level: self-checklist
- Rounds used: 1 (max 5)
```

Produced document:

```markdown
# Retro: retro-interview-enforcement implementation arc (DRY RUN 2 — headless self-checklist)

- Date: 2026-07-21
- Source: ad-hoc (dry run, headless mode)
- Spec: docs/specs/2026-07-20-retro-interview-enforcement-design.md
- Plan: docs/plans/2026-07-20-002-feat-retro-interview-enforcement-plan.md

## Release data

| Metric | Value |
|---|---|
| **Changed non-test lines** | 159 (151 added + 8 removed) |
| Commits | 5 |
| Review rounds | 5 |
| Comments (fixed / deferred) | 0 / 10 |
| CI failures | 0 |
| Duration (first spec commit → merge) | n/a — dry run pre-merge |
| Units planned / completed | 6 / 5 |

## Success criteria: measured vs declared

| # | Declared criterion | Measurement (command / rubric) | Measured result | Verdict |
|---|---|---|---|---|
| 1 | SC1 template section | `grep -c "Interview Transcript" schemas/retro-template.md` | 1 | Met |
| 6 | SC6 no regression | `bash scripts/validate.sh` | exit 0, ALL CHECKS PASSED | Met |

(SC3–SC5 are measured by the enclosing U6 unit itself; not re-measured inside this dry run.)

## Carry-forward from previous retro

| Item | Status | Evidence |
|---|---|---|
| (from 2026-07-20-entirecontext-mention-removal-retro.md) diff-size-metric review + P4 planning-gate cycle closure | Done | commit 9272910 |

- Previous doc shape: pre-schema, exempt (2026-07-20-entirecontext-mention-removal-retro.md predates the Interview Transcript schema)

## Interview Transcript

- Independence level: self-checklist
- Rounds used: 1 (max 5)

| ID | Round | Phase | Probe | Answer | Evidence | Verdict (verbatim) |
|---|---|---|---|---|---|---|
| T1 | 1 | 4 | You marked the previous retro's item Done — which commit proves it? | Commit 9272910 closed the diff-size-metric review and P4 planning-gate cycle | `git log --oneline` shows 9272910 on main | self-attested |
| T2 | 1 | 5 | What almost went wrong but didn't? What caught it — discipline, luck, or a gate? | Worktree branched from origin/main missing 8 local commits; a deliberate post-setup ls/log verification caught it before any commit | reflog: branch@{6} create → @{5} reset → @{4} first commit | self-attested |
| T3 | 1 | 5 | Which measurement surprised you against your expectation? | None yet measurable beyond SC1/SC6; the surprise was process-level (stale worktree base), not measurement-level | Release data table above | self-attested |

## Findings

### What worked well
- **What happened**: The stale worktree base (origin/main, 8 commits behind) was caught by a deliberate post-setup verification before any unit commit landed.
  **Why**: The orchestrator knew spec/plan commits were local-only and verified their presence in the fresh worktree.
  **How to apply**: After any worktree creation, verify the expected head artifacts exist before entering unit 1.
  **Cites**: T2

### What to improve
- (none registered in this dry run — headless mode, single round)

### Process observations
- **What happened**: Self-checklist mode produced answers without independent challenge; all verdicts are self-attested.
  **Why**: No dispatch primitive is used in headless mode by design.
  **How to apply**: Read self-attested transcripts with the independence level in mind; they are not facilitator-accepted evidence.
  **Cites**: T1, T3

## Carry-forward items registered

| Item | Type | Priority | Tracked at |
|---|---|---|---|
| (none — dry run registers nothing durable) | — | — | — |

## Lessons

- A worktree created "fresh" can silently base itself on a stale remote; the artifacts you committed minutes ago are the cheapest canary — check for them before writing anything.

## Compounding

- compound invocation: not attempted — no reusable lesson this cycle (dry run)
```

## Run 3 — negative injection (Covers S5)

One deliberately uncited finding ("The review process felt generally smooth…")
was drafted into a third run. The end-of-interview findings check blocked it
before Phase 8; with no dispatches remaining it was dropped, and the re-check
passed. SC5 measurement (verbatim check output):

```
=== check on injected draft ===
FAIL: uncited finding at line 19: - **What happened**: The review process felt generally smooth and everything wen
findings check: BLOCKED — return to interview or drop
exit=1
=== resolution: drop the uncited finding (no dispatches remain in this dry run) ===
findings check: PASS
exit=0
```

Injected draft (Findings section excerpt):

```markdown
### What to improve
- **What happened**: The review process felt generally smooth and everything went well overall.
  **Why**: Good planning.
  **How to apply**: Keep planning well.
```

The committed resolution state contains no uncited finding.

## Facilitator round-trip record (run 1)

- Round 1 (dispatch 1): facilitator returned probes P1–P3 from artifacts alone.
- Round 2 (dispatch 2): facilitator verified the respondent's evidence
  independently (reran the reflog and ledger greps), accepted P1 and P2, and
  accepted P3 only in qualified form — correcting the respondent's SC2 claim
  from plain "Met" to "Met per ledger-recorded independent review, evidence
  artifact uncommitted". The verdict texts are recorded verbatim in run 1's
  transcript. The round-trip materially changed the doc's content, which is the
  property the protocol exists to provide.

## Errata and observations from task review

The embedded documents above are unedited records of the dry runs; the task
review of this evidence found two defects in their *content*, preserved here as
errata rather than rewritten, because they are themselves evidence about the
protocol's residual limits:

1. **Minor-finding count is wrong in the record: 12, not 10.** The respondent's
   artifact pack stated "10 MinorFindings" and T1's facilitator verdict repeated
   "all 10 minors" while correctly citing the ledger — which actually itemizes
   12 IDs (U2-m1/m2, U3-m1/m2, U4-m1/m2/m3, U5-m1..m5). The facilitator
   verified the structure of the deferral (stable IDs, dated entries, rule
   citation) but not the arithmetic, and an unverified count survived inside an
   `accepted` verdict. This is a live demonstration that facilitator acceptance
   narrows, but does not eliminate, respondent-sourced error — the known limit
   the skill text states. Disposition: final branch review enumerates all 12.
2. **T3 is tagged Phase 3, which the Interview Protocol excludes from
   interviewing.** The probe targeted a rubric-measured criterion (SC2), where
   the measurement *is* a narrative, so probing was the only available lever —
   but the skill's "Phase 3 is never interviewed" wording does not carve out
   rubric-measured criteria. Genuine protocol tension surfaced by the dry run;
   routed to the enclosing arc's retrospective as finding material, not patched
   here (a skill-text change is observable behavior beyond the approved spec).
