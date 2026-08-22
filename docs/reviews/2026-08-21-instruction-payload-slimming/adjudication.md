# Adjudication & Invariant-Attack Report — Instruction Payload Slimming

_Unit U8. Cycle `feat/instruction-payload-slimming`, HEAD `90e2e5e`. Adjudicated against baseline `0a64fc1` (suite-floor) and `f2efda9` (skills-text). Measurements taken in a detached worktree copy of `90e2e5e` with the stray `.release-loop/progress.md` removed (the live-loop file makes `validate.sh`'s `[final-action]` check fail in-place — expected per the brief)._

---

## 1. Adjudication of hard constraints

### C1 — No gate/integrity clause deleted or weakened → **PASS**

Every clause named in the brief is present verbatim in the current skill bodies. Evidence (grep at HEAD `90e2e5e`):

- release-loop: `grep -nE "spec approval is always human|Gate approval is not execution authorization|enforces: P7|enforces: P8|relayed" skills/release-loop/SKILL.md`
  ```
  14:| `--auto` | ... spec approval is always human (`enforces: P7`) |
  76:- **Gate approval is not execution authorization** (pilot-proven, `enforces: P7`) ...
  77:- **Prepare before the gate resolves** (`enforces: P8`) ...
  117:Preserved gates: P3, P7, P8 — spec/Design approval is always human (P7), "Gate approval is not execution authorization", ...
  ```
- planning discrimination + body_seal: `grep -nE "Discrimination check|body_seal|verdict" skills/planning/SKILL.md` → `- **Discrimination check**` (line 166) and `body_seal` clause both present; PR #15 wording intact.
- implementing both-verdicts-clean/Minor ledger: `grep -nE "Minor|ledger|both verdicts" skills/implementing/SKILL.md` → `Mark the unit complete in the ledger only once both verdicts are clean (or only Minor remains).` (line 116).
- retrospective W1–W4 + 5 independence levels: `grep -nE "W1|W2|W3|W4|independence|heterogeneous" skills/retrospective/SKILL.md` → closed vocabulary `- **W1**`…`- **W4**`, and the five level values `heterogeneous | same-model fresh-context | in-thread (approximated independence) | self-checklist | not-probed (no narrative warranted)` present (line 101). `test-retro-format-drift.sh` (45 cases) and `validate.sh` check 9 assert these.
- shipping/release publication consent ceremony + gate-packet: `grep -nE "consent|gate-packet|ceremony" skills/shipping/SKILL.md skills/release/SKILL.md` → Ship `Persist before the gate resolves` (first-hand-consent marker), release `ceremony requires first-hand consent; draft prepared at .release/draft.md` (line 360). `test-release-publication.sh` (100 cases) and `validate.sh` check 16 assert these.

### C2 — No behavioral change; suite floors at `0a64fc1` hold → **FAIL**

Twelve of thirteen suites are green at HEAD `90e2e5e` (matching the `0a64fc1` floor). One regressed:

| # | Script | Floor @ `0a64fc1` | @ HEAD `90e2e5e` | Verdict |
|---|--------|-------------------|-------------------|---------|
| 1 | `validate.sh` | ALL CHECKS PASSED | ALL CHECKS PASSED | ok |
| 2 | `test-body-seal.sh` | 185 passed, 0 failed | 185 passed, 0 failed | ok |
| 3 | `test-final-action-skip.sh` | 1 passed, 0 failed | 1 passed, 0 failed | ok |
| 4 | `test-manifest-version-sync.sh` | ALL CASES PASSED | ALL CASES PASSED | ok |
| 5 | `test-plan-consumer-portability.sh` | 321 passed, 0 failed | 321 passed, 0 failed | ok |
| 6 | `test-plan-frontmatter.sh` | ALL CASES PASSED | ALL CASES PASSED | ok |
| 7 | `test-planning-schema-portability.sh` | **18 passed, 0 failed** | **14 passed, 4 failed** | **REGRESSION** |
| 8 | `test-plugin-skill-discovery.sh` | 13 skills, 0 failures | 13 skills, 0 failures | ok |
| 9 | `test-python-compatibility.sh all` | exit 0 | exit 0 | ok |
| 10 | `test-release-loop-worktree-default.sh` | ok-line | ok-line | ok |
| 11 | `test-release-publication.sh` | passed=100 failed=0 | passed=100 failed=0 | ok |
| 12 | `test-retro-format-drift.sh` | ALL CASES PASSED (45) | ALL CASES PASSED (45) | ok |
| 13 | `test-signal-drift.sh` | ALL CASES PASSED (11) | ALL CASES PASSED (11) | ok |

**Regression detail (suite 7 at HEAD):**
```
FAIL: planning-local-inventory-completeness — discovered-vs-declared planning-local inventory mismatch
skills/planning/SKILL.md|references/deepening.md|discovered=2|declared=1
skills/planning/SKILL.md|references/stateful-ceremony-matrix-example.md|discovered=2|declared=1
skills/planning/SKILL.md|schemas/plan-schema.md|discovered=10|declared=9
```
**Root cause:** U6's body compression added a `## This skill's references` inventory block (HEAD `skills/planning/SKILL.md:194-200`) that re-lists three package paths in backticks — one extra backtick occurrence each of `references/deepening.md`, `references/stateful-ceremony-matrix-example.md`, and `schemas/plan-schema.md` beyond the counts `test-planning-schema-portability.sh` declares in its `INVENTORY` assertion. The baseline `0a64fc1` has no such block and passes 18/0; the HEAD copy fails 14/4. This is a cycle-introduced floor break (verified: the same test passes 18/0 in a `0a64fc1` detached worktree, fails 14/4 in a `90e2e5e` detached worktree — not a copy artifact).

**Verdict: C2 FAIL** — one suite floor (`test-planning-schema-portability.sh` 18→14) is not intact. The moved blocks preserved behavior, but the added inventory block desynchronized the planning-package self-description from its portability assertion. Remediation is a follow-up fix (not in scope of U8, which only adjudicates + proves necessity).

### C3 — release SKILL.md `## Arguments` body byte-identical to `0b09ae9` pin → **PASS**

Evidence:
```bash
python3 -c '
import re,subprocess
def extract(rev):
    t=subprocess.run(["git","show",f"{rev}:skills/release/SKILL.md"],capture_output=True,text=True).stdout
    out=[];f=False
    for l in t.splitlines():
        if l.startswith("## Arguments"): f=True; out.append(l); continue
        if f and l.startswith("## ") and not l.startswith("## Arguments"): break
        if f: out.append(l)
    return "\n".join(out)+"\n"
h=extract("HEAD"); b=extract("0b09ae9")
print("HEAD bytes:",len(h.encode()),"BASE bytes:",len(b.encode()),"IDENTICAL:",h==b)
'
# → HEAD bytes: 497  BASE bytes: 497  IDENTICAL: True
```
`diff` of the two extractions is empty. The earlier `c4e2209` revert restored the full release body to the U5-end state; only `## Arguments` is pinned, so release-loop body shrinkage from M5/M6 relocations (see §2) is allowed.

---

## 2. Realized compression

### Seven always-resident skill bodies (`wc -c`, `0a64fc1` → HEAD `90e2e5e`)

| Skill body | `0a64fc1` | HEAD | Δ |
|---|---:|---:|---:|
| `designing` | 12651 | 12130 | −521 |
| `planning` | 23037 | 23253 | +216 |
| `implementing` | 21311 | 18119 | −3192 |
| `reviewing` | 16357 | 15274 | −1083 |
| `shipping` | 24163 | 23712 | −451 |
| `retrospective` | 20800 | 19749 | −1051 |
| `release-loop` | 18705 | 12370 | −6335 |
| **Total** | **137024** | **124607** | **−12417 (−9.1%)** |

Note: `release-loop` shrinkage (−6335) is relocation of M5/M6 to `references/`; permitted under C3 (only `## Arguments` is pinned). `planning` grew +216 because U6 added the inventory block (the same block that broke C2).

### Thirteen skill descriptions (`description:` block bytes, exact baseline awk)

- `0a64fc1`: **4561**
- HEAD `90e2e5e`: **4173**
- Δ: **−388 (−8.5%)**

(Note: the brief's "4121" is not reproduced in this worktree; the verified HEAD figure is 4173. `release`'s description is unchanged at 314 bytes, consistent with C3 excluding release from description/body compression.)

---

## 3. Invariant attacks — each preserved clause proven necessary

All attacks run in throwaway detached-worktree copies of `90e2e5e` (`.release-loop/progress.md` removed); each copy was `rm -rf`'d afterward. Each deletes one preserved clause and shows its guarding test FAILS, with the verbatim failing assertion line.

### A1 — delete an independence-level term (`heterogeneous`) from retrospective prose

- Target: `skills/retrospective/SKILL.md` line 101 (closed level vocabulary).
- Mutation: removed all 3 `heterogeneous` occurrences (backticked + non-backticked).
- Guard: `validate.sh` check 9 (`[retro-format]`) — couples the template's five level values to skill prose.
- Result: `bash scripts/validate.sh` → nonzero. Failing line:
  ```
  FAIL: [retro-format] independence level 'heterogeneous' from schemas/retro-template.md not found in skills/retrospective/SKILL.md
  ```

### A2 — delete the planning `Discrimination check` bullet

- Target: `skills/planning/SKILL.md` line 166, `- **Discrimination check** — ...` bullet (PR #15 contract).
- Mutation: removed the exactly-one bullet line.
- Guard: `validate.sh` check 16 (`[review-remediation]`) — requires exactly one Discrimination-check bullet and its four sub-clauses.
- Result: `bash scripts/validate.sh` → nonzero. Failing line:
  ```
  FAIL: [review-remediation] skills/planning/SKILL.md expected one Discrimination check bullet
  ```

### A3 — delete the release-loop relayed-approval-refusal clause

- Target: `skills/release-loop/SKILL.md` line 54 transition-contract paragraph.
- Mutation: removed `A declined, deferred, relayed, or headless outward transition leaves Ship blocked`.
- Guard: **`validate.sh` check 16 (`[review-remediation]`)** — the brief's stated guard `test-signal-drift.sh` does **NOT** pin `release-loop` (it pins only `compound`, `compound-refresh`, `retrospective`, `release` terminal signal lines). Running `test-signal-drift.sh` after this deletion still passes its release-loop-agnostic cases (the only failure is the unrelated Case J matcher-coverage case), proving it cannot catch this clause. The genuine guard is `validate.sh` check 16.
- Result: `bash scripts/validate.sh` → nonzero. Failing line:
  ```
  FAIL: [review-remediation] skills/release-loop/SKILL.md missing contract: A declined, deferred, relayed, or headless outward transition leaves Ship blocked
  ```

All three preserved clauses are **necessary**: deleting each makes its guarding test fail on a clause-specific assertion line.

---

## 4. Summary

| Constraint | Verdict |
|---|---|
| C1 — gates/integrity clauses preserved | PASS |
| C2 — suite floors intact | **FAIL** (suite 7: 18→14 after U6 inventory block) |
| C3 — release `## Arguments` byte-identical | PASS |

| Attack | Clause deleted | Guarding test | Failing assertion |
|---|---|---|---|
| A1 | `heterogeneous` (retrospective independence level) | `validate.sh` check 9 | `FAIL: [retro-format] independence level 'heterogeneous' ... not found in skills/retrospective/SKILL.md` |
| A2 | `- **Discrimination check**` bullet | `validate.sh` check 16 | `FAIL: [review-remediation] skills/planning/SKILL.md expected one Discrimination check bullet` |
| A3 | release-loop relayed-refusal clause | `validate.sh` check 16 | `FAIL: [review-remediation] skills/release-loop/SKILL.md missing contract: A declined, deferred, relayed, or headless outward transition leaves Ship blocked` |

**Concern:** C2's single regression (suite 7) is real and cycle-introduced by U6's `## This skill's references` inventory block, which inflated the planning package's declared backtick-reference counts. It does not touch any preserved gate clause (C1 still PASS), but it does break the stated no-behavioral-change floor. Recommended follow-up (out of U8 scope): either subtract the inventory block's three re-listed references from the `INVENTORY` declared counts, or remove the redundant block — the portability test's own discovery logic already enumerates references dynamically.
