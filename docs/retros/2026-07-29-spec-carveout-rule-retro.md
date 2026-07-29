# Retro: spec-carveout-rule

- Date: 2026-07-29
- Source: direct-to-main commit `06127f6`
- Spec: none (inline design approval)
- Plan: none (skipped — atomic single-check addition)

## Release data

| Metric | Value |
|---|---|
| **Changed non-test lines** | 2 (designing SKILL.md Step 11) + 1 (ROADMAP row closure) |
| Commits | 1 |
| Review rounds | 1 (self-review) |
| Comments (fixed / deferred) | 0 / 0 |
| CI failures | 0 |
| Duration (design → push) | ~4 minutes |
| Units planned / completed | n/a (no plan) |

## Success criteria: measured vs declared

(No spec exists — inline design. Measuring against the design's implicit criteria.)

| # | Declared criterion | Measurement (command / rubric) | Measured result | Verdict |
|---|---|---|---|---|
| 1 | Step 11 has 5 checks (was 4) | `grep -c '^\d\.' skills/designing/SKILL.md` on Step 11 block | verified: "Five fixed checks" heading + 5 numbered items (lines 128–134) | Met |
| 2 | New check targets principle-requirement composability | judgment rubric: read check 5 text | verified: "does an Architecture principle conflict with a requirement's mandated mechanism? If so, name the carve-out in the spec and cite the requirement that justifies the exception" — directly addresses the T3 finding | Met |
| 3 | validate.sh passes | `bash scripts/validate.sh` | verified: ALL CHECKS PASSED | Met |
| 4 | ROADMAP P3 row closed | `grep '~~Spec-level carve-out' ROADMAP.md` | verified: row strikethrough with **Done** marker | Met |

## Carry-forward from previous retro

| Item | Status | Evidence |
|---|---|---|
| check 11 skip-path fixture test (P4) | Not started — trigger ("next edit to validate.sh check 11") did not fire this cycle | Branch diff touches designing SKILL.md and ROADMAP.md only |

- Previous doc shape: conformant

## Interview Transcript

- Independence level: self-checklist
- Rounds used: 0 (headless mode — mechanical SKILL.md rule addition)

| ID | Round | Phase | Probe | Answer | Evidence | Verdict (verbatim) |
|---|---|---|---|---|---|---|
| T1 | — | 3 | Does check 5 address the original T3 finding (principle-vs-requirement composability not caught by generic consistency check)? | Yes — check 5 specifically names Architecture principle vs requirement mechanism conflict and mandates in-spec carve-out with R-ID citation, matching the T3 "How to apply" verbatim | SKILL.md:134 text vs retro T3 finding | self-attested |
| T2 | — | 3 | Is the check distinct from existing check 2 (internal consistency)? | Yes — check 2 asks "do sections contradict each other" (surface-level), check 5 asks about composability when a principle and a requirement interact at the mechanism level; check 2 would not have caught the R5-vs-Architecture tension that triggered this item | SKILL.md:131 vs :134 | self-attested |

## Findings

### What worked well

- **What happened**: Three carry-forward items closed in one session (fix-red-suites P2, final-action-validate P3, spec-carveout-rule P3), each building on the previous loop's validated state.
  **Why**: All three were self-contained, had fired triggers, and needed no design decisions beyond the inline approval. Sequential execution reused warm context and avoided branch overhead.
  **How to apply**: When multiple fired carry-forward items are mechanical and independent, batch them in one session.
  **Cites**: T1; three commits on main in same session.

### What to improve

- **What happened**: The new check 5's enforcement is prose-only — it instructs the designer to "name the carve-out and cite the requirement" but nothing mechanical validates that a spec with both an Architecture section and R-IDs actually ran this check.
  **Why**: All five Step 11 checks are prose instructions, not mechanical validators; check 5 is consistent with that pattern. The carry-forward item asked for a "durable designing rule," not a validator.
  **How to apply**: If a future spec's principle-exception tension survives Step 11 again, consider a mechanical pre-commit check or a mandatory independent-review instruction targeting composability specifically.
  **Cites**: T2; the original ROADMAP row's "satisfied procedurally" phrasing.

### Process observations

- **What happened**: This is the third consecutive cycle where the SKILL.md change is a single paragraph (signal-drift line update, validate.sh check block, self-review check item). The release-loop overhead (progress.md, retro doc, ROADMAP closure) exceeds the implementation work.
  **Why**: These carry-forward items are mechanical by design — their ROADMAP rows contain the repair specification. The loop's value is in the retro's reconciliation and carry-forward tracking, not in gating the implementation.
  **How to apply**: Mechanical carry-forward batches could share a single retro doc covering all items, reducing per-item ceremony without losing the reconciliation pass.
  **Cites**: Three commits this session; progress.md log timestamps.

## Carry-forward items registered

| Item | Type | Priority | Tracked at |
|---|---|---|---|
| (none this cycle) | — | — | — |

## Lessons

- A SKILL.md self-review check is the lightest durable rule form — it costs one paragraph and fires on every spec, unlike a validator that needs fixtures and maintenance.

## Compounding

- not attempted — no reusable cross-skill pattern this cycle (the lesson is designing-specific)
