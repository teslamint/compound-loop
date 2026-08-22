# Baseline Evidence — Instruction Payload Slimming

_Captured 2026-08-22 by U1 (re-execution R2) in the cycle worktree `feat/instruction-payload-slimming` (HEAD `96cb557`)._

## Baseline revisions and equality proof

- **Skills-text baseline:** `f2efda9` (fixed by Addendum 014; unchanged by Addendum 015).
- **Suite-floor baseline:** `0a64fc1` (per Deviation Addendum 015 — `f2efda9` plus docs/plan commits and the three test repairs `457043d`, `b57cbc4`, `0a64fc1`; zero `skills/` changes).
- **Worktree used for every measurement:** `$(mktemp -d)/base` checked out at `0a64fc1`. One worktree serves both byte extraction (identical `skills/` to `f2efda9`) and suite runs.
- **Equality proof (Addendum 015):** `git diff f2efda9..0a64fc1 --stat -- skills/` → _empty_ (no `skills/` change between the two revisions, therefore all byte figures measured at `0a64fc1` equal `f2efda9`'s).

---

## (a) Suite totals — 13 suites at `0a64fc1` (SC4 floors)

All thirteen suites are **green** at the suite-floor baseline. Any suite that reports no single machine-readable numeric total records its exact final summary line verbatim as the floor (per the brief's edge case).

| # | Script | Exact self-reported summary line | Numeric total |
|---|--------|----------------------------------|---------------|
| 1 | `scripts/validate.sh` | `ALL CHECKS PASSED` | N/A (verbatim line is the floor) |
| 2 | `scripts/test-body-seal.sh` | `Results: 185 passed, 0 failed` | 185 |
| 3 | `scripts/test-final-action-skip.sh` | `1 passed, 0 failed` | 1 |
| 4 | `scripts/test-manifest-version-sync.sh` | `ALL CASES PASSED` | N/A (verbatim line is the floor) |
| 5 | `scripts/test-plan-consumer-portability.sh` | `Summary: 321 passed, 0 failed` | 321 |
| 6 | `scripts/test-plan-frontmatter.sh` | `ALL CASES PASSED` | N/A (verbatim line is the floor) |
| 7 | `scripts/test-planning-schema-portability.sh` | `Planning schema portability: 18 checks passed, 0 failures` (followed by `ALL CHECKS PASSED`) | 18 |
| 8 | `scripts/test-plugin-skill-discovery.sh` | `Plugin skill discovery: 13 skills checked, 0 failures` (followed by `ALL CHECKS PASSED`) | 13 |
| 9 | `scripts/test-python-compatibility.sh all` | no single numeric line; per-endpoint `ok:` lines, exit 0 | N/A (exit 0 is the floor) |
| 10 | `scripts/test-release-loop-worktree-default.sh` | `ok:   release-loop defaults new work to isolated worktrees` | N/A (verbatim line is the floor) |
| 11 | `scripts/test-release-publication.sh` | `SUMMARY group=all passed=100 failed=0` | 100 |
| 12 | `scripts/test-retro-format-drift.sh` | `ALL CASES PASSED` (`grep -c '^run_case'` = 45) | 45 |
| 13 | `scripts/test-signal-drift.sh` | `ALL CASES PASSED` (`grep -c '^run_case'` = 11) | 11 |

Invocation note: `scripts/test-python-compatibility.sh` was run as `bash scripts/test-python-compatibility.sh all` (bare invocation exits 2 with usage). The three previously-red suites (`test-plan-frontmatter.sh` Case 20, `test-planning-schema-portability.sh` schema-byte-parity, `test-release-publication.sh` local-section) are green at `0a64fc1` after the Addendum 015 repairs.

---

## (b) Byte figures — measured in the `0a64fc1` worktree

### Seven always-resident bodies (`wc -c`)

| Skill body | Bytes |
|---|---|
| `skills/designing/SKILL.md` | 12651 |
| `skills/planning/SKILL.md` | 23037 |
| `skills/implementing/SKILL.md` | 21311 |
| `skills/reviewing/SKILL.md` | 16357 |
| `skills/shipping/SKILL.md` | 24163 |
| `skills/retrospective/SKILL.md` | 20800 |
| `skills/release-loop/SKILL.md` | 18705 |
| **Total** | **137024** |

Total must be **137024** — confirmed.

### Thirteen skill descriptions (`description:` block bytes)

Command: `for f in skills/*/SKILL.md; do awk '/^description:/{f=1} f{print} /^---$/&&NR>1{exit}' "$f"; done | wc -c`

Result: **4561** (must be 4,561 — confirmed).

### M1–M9 move-unit block bytes

| Block | Command (verbatim from spec Assumptions table, lines 99–108) | Bytes |
|---|---|---|
| M1–M4 (markers inclusive, sum) | `for f in release-loop implementing reviewing retrospective; do awk '/plan-consumer-contract/,/end-plan-consumer-contract/' $f/SKILL.md | wc -c; done | paste -sd+ - | bc` | 9040 (2245+3755+1609+1431) |
| M5 (heading inclusive) | `awk '/^## Approved-plan transition hooks/,/^## Starting a new loop/' skills/release-loop/SKILL.md | sed \$d | wc -c` | 3566 |
| M6 (two sections, headings inclusive) | `awk '/^## Resuming/,/^## Gate handling/' skills/release-loop/SKILL.md | sed \$d | wc -c` | 4575 |
| M7 (heading inclusive) | `awk '/^## Step 0: Capability Preflight/,/^## Step 1:/' skills/shipping/SKILL.md | sed \$d | wc -c` | 942 |
| M8 (heading inclusive) | `awk '/^## Out of Scope/,0' skills/designing/SKILL.md | wc -c` | 402 |
| M9 (heading inclusive) | `awk '/^## Out of Scope/,0' skills/retrospective/SKILL.md | wc -c` | 220 |

All M-block figures match the spec's required values (2245, 3755, 1609, 1431, 3566, 4575, 942, 402, 220).

---

## (c) SC3 baseline side — description fields at `f2efda9` (verbatim)

Extracted from `git show f2efda9:skills/<name>/SKILL.md` `description:` fields. Each entry quotes the full `description:` verbatim; the **trigger phrases** (invocation paths / "use when" conditions) and **negative/routing clauses** ("Do not trigger for…", routing to other skills, scoping limits) are marked inline.

### 1. `compound-refresh`
> description: Audit docs/solutions/ against the current codebase and refresh, consolidate, or delete drifted learnings and pattern docs. Use via /compound-refresh (Claude Code) or $compound-refresh (Codex) on direct request ("refresh my learnings", "audit docs/solutions/", "clean up stale docs", "consolidate overlapping docs"), or when compound flags an older doc as a refresh candidate. Do not trigger for general refactor or code-review work unless the user explicitly points at docs/solutions/.

- **Trigger:** `/compound-refresh` (Claude Code), `$compound-refresh` (Codex); direct request phrases; "when compound flags an older doc as a refresh candidate".
- **Negative/routing:** "Do not trigger for general refactor or code-review work unless the user explicitly points at docs/solutions/".

### 2. `compound`
> description: Document a recently solved problem or captured piece of guidance so it compounds the team's knowledge in docs/solutions/ and the shared CONCEPTS.md vocabulary. Use via /compound (Claude Code) or $compound (Codex) right after verifying a fix, when retrospective invokes it in mode:headless with a qualifying finding, or on direct request ("document this", "compound this fix").

- **Trigger:** `/compound` (Claude Code), `$compound` (Codex); "right after verifying a fix"; "when retrospective invokes it in mode:headless with a qualifying finding"; direct request phrases.

### 3. `debugging`
> description: Find root causes and fix bugs systematically. Use when debugging errors, investigating test failures, reproducing bugs from issue trackers, or when stuck after failed fix attempts. Also use when the user says "debug this", "why is this failing", "trace this error", or pastes a stack trace or error message.

- **Trigger:** "when debugging errors, investigating test failures, reproducing bugs from issue trackers, or when stuck after failed fix attempts"; user phrases "debug this", "why is this failing", "trace this error", or pastes stack trace/error message.

### 4. `designing`
> description: Turn a feature idea into an approved, committed spec with measurable success criteria through collaborative dialogue. Use via /designing (Claude Code) or $designing (Codex) when starting new feature work, when release-loop's Design phase fires, or whenever implementation is about to begin without an approved design -- including work that looks "too simple to need one".

- **Trigger:** `/designing` (Claude Code), `$designing` (Codex); "when starting new feature work"; "when release-loop's Design phase fires"; "whenever implementation is about to begin without an approved design".
- **Routing/negative:** "-- including work that looks 'too simple to need one'" (explicitly includes work that would otherwise be skipped).

### 5. `implementing`
> description: Execute an approved plan to completion with review checkpoints, surviving context loss, on any harness

- **Trigger:** (implied by name and cross-references) executes an approved plan; no explicit negative clause.

### 6. `planning`
> description: Turn an approved spec into an implementation plan an engineer or agent can execute with zero codebase context. Invoke as /planning (Claude Code) or $planning (Codex), or when the user says "plan this", "write an implementation plan", "break this into tasks", or a designing-phase spec is ready to plan.

- **Trigger:** `/planning` (Claude Code), `$planning` (Codex); user phrases "plan this", "write an implementation plan", "break this into tasks"; "a designing-phase spec is ready to plan".

### 7. `release-loop`
> description: "Drive a feature from idea to merged PR to retrospective through six phases: Design, Plan, Implement, Review, Ship, Retro. Each phase invokes a standalone compound-loop skill; this skill only sequences, gates, and persists state. Use via /release-loop <feature> (Claude Code) or $release-loop <feature> (Codex). Bare resume continues a live record; use <feature> resume when no live record exists."

- **Trigger:** `/release-loop <feature>` (Claude Code), `$release-loop <feature>` (Codex).
- **Routing:** "Each phase invokes a standalone compound-loop skill; this skill only sequences, gates, and persists state" (explicitly a router/orchestrator, not an executor).
- **Negative/scope:** "Bare resume continues a live record; use <feature> resume when no live record exists" (resume routing clause).

### 8. `release`
> description: Cut a local versioned release from committed lifecycle evidence with an artifact-derived CHANGELOG, synchronized plugin manifests, a first-hand USER gate, and an annotated tag. Use via /release (Claude Code) or $release (Codex); pass mode:headless for a prepare-only handoff or a SemVer argument to propose that exact version.

- **Trigger:** `/release` (Claude Code), `$release` (Codex); "mode:headless for a prepare-only handoff"; "a SemVer argument to propose that exact version".

### 9. `retrospective`
> description: Measure outcomes against declared success criteria, reconcile carry-forward items, extract lessons, and feed the knowledge-compounding loop. Use via /retrospective (Claude Code) or $retrospective (Codex) after a PR merges, at the end of a session or debugging arc, on direct request ("run a retro", "retrospective on this"), or when release-loop's Retro phase fires.

- **Trigger:** `/retrospective` (Claude Code), `$retrospective` (Codex); "after a PR merges"; "at the end of a session or debugging arc"; direct request phrases; "when release-loop's Retro phase fires".

### 10. `reviewing`
> description: "Multi-lane code review producing verified, deduplicated findings (mode:agent JSON per review-envelope.schema.json, or markdown pipe tables), and disciplined consumption of reviews received from anyone else. Use via /reviewing (Claude Code) or $reviewing (Codex): mandatorily after each subagent task, after completing a major feature, or before merge; optionally when stuck, before refactoring, or after a complex bugfix; whenever release-loop's Review phase fires; or whenever external feedback (a human reviewer, a bot, another agent) needs disciplined evaluation before you implement it."

- **Trigger:** `/reviewing` (Claude Code), `$reviewing` (Codex).
- **Mandatory routing:** "mandatorily after each subagent task, after completing a major feature, or before merge".
- **Optional routing:** "optionally when stuck, before refactoring, or after a complex bugfix; whenever release-loop's Review phase fires; or whenever external feedback (a human reviewer, a bot, another agent) needs disciplined evaluation before you implement it".

### 11. `shipping`
> description: Take reviewed, verified work from a clean local state to merged and cleaned up -- commit, push, open a PR, watch CI, resolve review feedback, gate the merge, and clean up the branch or worktree. Use via /shipping (Claude Code) or $shipping (Codex) when review is clean and work is ready to ship, when release-loop's Ship phase fires, or on direct requests like "commit and open a PR", "ship this", "finish this branch".

- **Trigger:** `/shipping` (Claude Code), `$shipping` (Codex); "when review is clean and work is ready to ship"; "when release-loop's Ship phase fires"; direct request phrases.

### 12. `tdd`
> description: Use when implementing any feature or bugfix, before writing implementation code

- **Trigger:** "when implementing any feature or bugfix, before writing implementation code".

### 13. `worktree-isolation`
> description: Use when starting feature work that needs isolation from the current workspace or before executing an implementation plan - ensures an isolated workspace exists via native tools or a git worktree fallback

- **Trigger:** "when starting feature work that needs isolation from the current workspace or before executing an implementation plan".

---

## (d) Validator manifest — five R6 validators at `0a64fc1`

`sha256sum` of each validator in the worktree (suite-floor baseline `0a64fc1`). Per validator: the exact case-count command and its output, plus the **assertion inventory** (numbered `grep -nE 'assert_|fail |fail\(|require\('` output, pasted verbatim — this is the baseline side of U8's assertion-inventory comparison).

> Note: the brief's literal `grep -n 'assert_\|fail \|fail(\|require('` (BRE) returns nothing because the validators use `fail()` (no space) and uppercase `FAIL`. The ERE form below surfaces 11 / 33 / 98 / 7 / 48 assertion lines respectively, satisfying the non-empty assertion-inventory acceptance. The verbatim grep output is recorded as-is.

### 1. `scripts/test-plan-consumer-portability.sh`
- **sha256:** `8caac4138bc581d90b756dca4f6f613e525ed94bb70cb261b09dd703aff9daa3`
- **Case-count command:** `bash scripts/test-plan-consumer-portability.sh` → self-reported: `Summary: 321 passed, 0 failed` (total **321**).
- **Assertion inventory (`grep -nE 'assert_|fail |fail\(|require\('`):**
```
17:fail() {
39:      FAIL) fail "$consumer/$name${detail:+ — $detail}" ;;
40:      *) fail "harness/unknown-result — $state" ;;
1365:        # policy-object substitutions, and must fail through the same history
2529:  fail "standalone fixture omits skills/planning/"
2536:    fail "$consumer has no load-bearing root schema reference"
2543:    fail "$consumer executable decision fixtures"
2556:    fail "$consumer complete adoption branch and invalid evidence branches"
2571:  fail "shared SSOT fallback finds skills/planning/schemas/plan-schema.md or schemas/plan-schema.md"
2579:      fail "$consumer shared subset matches moved sibling SSOT"
2590:    fail "all consumer subsets match pre-move root SSOT fallback"
```

### 2. `scripts/test-signal-drift.sh`
- **sha256:** `91c36abd0cf2ebd3f335b69628defd41b7813ef39e192fb67c3a76f507906bdf`
- **Case-count command:** `grep -c '^run_case' scripts/test-signal-drift.sh` → **11**.
- **Assertion inventory (`grep -nE 'assert_|fail |fail\(|require\('`):**
```
22:assert_contains() {
31:assert_not_contains() {
58:  assert_contains "$out" "ok:   terminal signal lines match schemas/headless-contract.md" "ok-line" || result=1
84:  assert_contains "$out" "[signal-drift]" "reported by the new check specifically" || result=1
85:  assert_contains "$out" "skills/compound/SKILL.md:77" "file:line" || result=1
105:  assert_contains "$out" "[signal-drift]" "reported by the new check specifically" || result=1
106:  assert_contains "$out" "skills/compound-refresh/SKILL.md:77" "file:line" || result=1
134:  assert_contains "$out" "[signal-drift]" "reported by the new check specifically" || result=1
135:  assert_contains "$out" "skills/retrospective/SKILL.md:$mutation_line" "file:line" || result=1
136:  assert_contains "$out" "producer 'compound'" "correct producer guessed from candidate's own word, not the file it lives in" || result=1
154:  assert_contains "$out" "FAIL:" "named fail" || result=1
155:  assert_contains "$out" "[signal-drift]" "check 6 itself (not just pre-existing check 2) reports this" || result=1
156:  assert_contains "$out" "schemas/headless-contract.md" "names the malformed file" || result=1
157:  assert_not_contains "$out" "Traceback" "no python traceback" || result=1
185:  assert_contains "$out" "[signal-drift]" "reported by the new check specifically" || result=1
186:  assert_contains "$out" "producer 'compound-refresh'" "names the uncovered producer" || result=1
187:  assert_contains "$out" "state 'skipped'" "names the uncovered state" || result=1
203:  assert_contains "$out" "FAIL:" "named fail" || result=1
204:  assert_contains "$out" "[signal-drift]" "check 6 itself (not just pre-existing check 3) reports this" || result=1
205:  assert_contains "$out" "skills/retrospective/SKILL.md" "names the missing file" || result=1
206:  assert_not_contains "$out" "Traceback" "no python traceback" || result=1
243:  assert_contains "$out" "[signal-drift]" "reported by the new check specifically" || result=1
244:  assert_contains "$out" "skills/release/SKILL.md:$target_line" "computed file:line" || result=1
280:  assert_contains "$out" "[signal-drift]" "reported by check 6 specifically" || result=1
281:  assert_contains "$out" "skills/release/SKILL.md:$target_line" "computed file:line" || result=1
282:  assert_contains "$out" "producer 'release publish'" "distinct publication producer" || result=1
283:  assert_contains "$out" "state 'success'" "publication success state" || result=1
284:  assert_contains "$out" "Publication complete — v<versio>" "found byte mismatch" || result=1
285:  assert_contains "$out" "Publication complete — v<version>" "expected byte sequence" || result=1
321:  assert_contains "$out" "[signal-drift]" "reported by check 6 specifically" || result=1
322:  assert_contains "$out" "skills/release/SKILL.md:$target_line" "computed file:line" || result=1
323:  assert_contains "$out" "Release complete — v<version>\nmutated" "multiline candidate was inspected" || result=1
324:  assert_not_contains "$out" "canonical line not found" "canonical coverage remains present" || result=1
```

### 3. `scripts/test-retro-format-drift.sh`
- **sha256:** `f495c326f5af89c1326c36828973cdde1b9ab6f0ec0b4999175ab36a78bb55bc`
- **Case-count command:** `grep -c '^run_case' scripts/test-retro-format-drift.sh` → **45**.
- **Assertion inventory (`grep -nE 'assert_|fail |fail\(|require\('`):**
```
32:assert_contains() {
41:assert_not_contains() {
52:assert_fail_naming() {
413:assert_phase8_anchors() {
446:assert_warrant_anchors() {
466:assert_measured_heading_anchor() {
481:assert_no_spec_boilerplate_anchor() {
498:assert_levels_anchor() {
526:assert_reconciliation_bullet_anchor() {
659:assert_phase4_anchors() {
724:assert_condition_name() {
754:  assert_contains "$out" "ok:   retro interview format: template and skill prose agree" "ok-line" || result=1
782:  assert_fail_naming "$out" "schemas/retro-template.md" "FAIL line names the template" || result=1
783:  assert_fail_naming "$out" "self-check" "FAIL line names the mismatched level value" || result=1
810:  assert_fail_naming "$out" "skills/retrospective/SKILL.md" "FAIL line names the skill file" || result=1
837:  assert_fail_naming "$out" "schemas/retro-template.md" "FAIL line names the template" || result=1
838:  assert_not_contains "$out" "Traceback" "no python traceback" || result=1
862:  assert_fail_naming "$out" "skills/retrospective/references/interview-probes.md" "FAIL line names the probes file" || result=1
876:  assert_fail_naming "$out" "skills/retrospective/references/interview-probes.md" "FAIL line names the missing probes file" || result=1
877:  assert_not_contains "$out" "Traceback" "no Python traceback" || result=1
905:  assert_fail_naming "$out" "skills/retrospective/references/interview-probes.md" "FAIL line names the probes file" || result=1
906:  assert_fail_naming "$out" "solo-checklist" "FAIL line names the missing level value" || result=1
925:  assert_fail_naming "$out" "expected 5 distinct independence levels" "FAIL names the level-count guard" || result=1
944:  assert_fail_naming "$out" "expected 4 distinct backticked verdict forms" "FAIL names the verdict-count guard" || result=1
963:  assert_fail_naming "$out" "expected exactly one 'Verdict cell values:' line" "FAIL names the verdict-line guard" || result=1
989:  assert_fail_naming "$out" "skills/retrospective/SKILL.md" "FAIL line names the skill file" || result=1
990:  assert_fail_naming "$out" "not-probed (no narrative warranted)" "FAIL line names the missing level value" || result=1
1012: assert_fail_naming "$out" "skills/retrospective/references/interview-probes.md" "FAIL line names the probes file" || result=1
1013: assert_fail_naming "$out" "not-probed (no narrative warranted)" "FAIL line names the missing level value" || result=1
1038: assert_fail_naming "$out" "skills/retrospective/references/interview-probes.md" "FAIL line names the probes file" || result=1
1039: assert_fail_naming "$out" "in-thread (approximated independence)" "FAIL line names the missing level value" || result=1
1053: assert_contains "$out" "ok:   retro interview format: template and skill prose agree" "ok-line" || result=1
1069: assert_condition_name "$out" "phase8-headless" || result=1
1070: assert_phase8_anchors "$dir" || result=1
1085: assert_phase8_anchors "$dir" || result=1
1103: assert_condition_name "$out" "phase8-capability" || result=1
1104: assert_phase8_anchors "$dir" || result=1
1120: assert_warrant_anchors "$dir" || result=1
1136: assert_condition_name "$out" "W1" || result=1
1137: assert_warrant_anchors "$dir" || result=1
1138: assert_measured_heading_anchor "$dir" || result=1
1154: assert_condition_name "$out" "W2" || result=1
1155: assert_warrant_anchors "$dir" || result=1
1156: assert_reconciliation_bullet_anchor "$dir" || result=1
1174: assert_condition_name "$out" "W4" || result=1
1175: assert_warrant_anchors "$dir" || result=1
1193: assert_warrant_anchors "$dir" || result=1
1209: assert_condition_name "$out" "W4" || result=1
1210: assert_warrant_anchors "$dir" || result=1
1226: assert_condition_name "$out" "W3" || result=1
1227: assert_warrant_anchors "$dir" ||
1227: assert_warrant_anchors "$dir" || result=1
1244: assert_condition_name "$out" "W1" || result=1
1245: assert_warrant_anchors "$dir" || result=1
1246: assert_measured_heading_anchor "$dir" || result=1
1262: assert_condition_name "$out" "W3" || result=1
1263: assert_warrant_anchors "$dir" || result=1
1281: assert_condition_name "$out" "W1" || result=1
1282: assert_warrant_anchors "$dir" || result=1
1283: assert_measured_heading_anchor "$dir" || result=1
1301: assert_warrant_anchors "$dir" || result=1
1302: assert_measured_heading_anchor "$dir" || result=1
1322: assert_condition_name "$out" "phase4-unregistered" || result=1
1323: assert_phase4_anchors "$dir" || result=1
1359: assert_condition_name "$out" "W2" || result=1
1360: assert_warrant_anchors "$dir" || result=1
1361: assert_reconciliation_bullet_anchor "$dir" || result=1
1379: assert_phase8_anchors "$dir" || result=1
1395: assert_condition_name "$out" "phase8-capability" || result=1
1396: assert_phase8_anchors "$dir" || result=1
1415: assert_condition_name "$out" "W1" || result=1
1416: assert_warrant_anchors "$dir" || result=1
1417: assert_measured_heading_anchor "$dir" || result=1
1418: assert_no_spec_boilerplate_anchor "$dir" || result=1
1437: assert_condition_name "$out" "W1" || result=1
1438: assert_warrant_anchors "$dir" || result=1
1439: assert_measured_heading_anchor "$dir" || result=1
1458: assert_condition_name "$out" "W1" || result=1
1459: assert_warrant_anchors "$dir" || result=1
1460: assert_no_spec_boilerplate_anchor "$dir" || result=1
1477: assert_condition_name "$out" "level-unrecognized" || result=1
1478: assert_levels_anchor "$dir" || result=1
1496: assert_condition_name "$out" "phase8-capability" || result=1
1497: assert_phase8_anchors "$dir" || result=1
1516: assert_condition_name "$out" "W4" || result=1
1517: assert_warrant_anchors "$dir" || result=1
1535: assert_condition_name "$out" "W2" || result=1
1536: assert_warrant_anchors "$dir" || result=1
1537: assert_reconciliation_bullet_anchor "$dir" || result=1
1548:# would also fail the later condition.
1557: assert_condition_name "$out" "W2" || result=1
1558: assert_warrant_anchors "$dir" || result=1
1559: assert_reconciliation_bullet_anchor "$dir" || result=1
1580: assert_condition_name "$out" "phase4-unregistered" || result=1
1581: assert_phase4_anchors "$dir" || result=1
1599: assert_condition_name "$out" "phase4-unregistered" || result=1
1600: assert_phase4_anchors "$dir" || result=1
1619: assert_condition_name "$out" "phase4-unregistered" || result=1
1620: assert_phase4_anchors "$dir" || result=1
```

### 4. `scripts/test-plugin-skill-discovery.sh`
- **sha256:** `66be6964e38240876dc57c4c2086cb3f88a8880510254248dd2e4d44ac034bff`
- **Case-count command:** `bash scripts/test-plugin-skill-discovery.sh` → self-reported: `Plugin skill discovery: 13 skills checked, 0 failures` (total **13**).
- **Assertion inventory (`grep -nE 'assert_|fail |fail\(|require\('`):**
```
48:  fail=$((fail + 1))
60:    fail=$((fail + 1))
70:    fail=$((fail + 1))
73:    fail=$((fail + 1))
82:  fail=$((fail + 1))
90:    fail=$((fail + 1))
95:echo "Plugin skill discovery: $checked skills checked, $fail failures"
```

### 5. `scripts/validate.sh`
- **sha256:** `a7916d8496584d7223aaf8d90a778080612c0892bb9635e6ad35f8aea0472ab6`
- **Case-count command:** `bash scripts/validate.sh` → self-reported: `ALL CHECKS PASSED` (structural checks; the suite's own gates per sub-check).
- **Assertion inventory (`grep -nE 'assert_|fail |fail\(|require\('`):**
```
9:fail() { echo "FAIL: $1"; FAIL=1; }
17:    fail "$m missing or invalid JSON"
26:    fail "$s missing or invalid JSON"
30:  [ -s "$ROOT/$s" ] && ok "$s present" || fail "$s missing or empty"
38:    fail "skills/$skill/SKILL.md missing"
108:def fail(msg):
115:    fail("schemas/headless-contract.md missing or unreadable")
134:        fail(
159:            fail(f"{rel} missing or unreadable")
175:                fail(
184:                fail(
296:def fail(msg):
316:    fail(f"{TEMPLATE} missing or unreadable")
320:    fail(f"{TEMPLATE}: '## Interview Transcript' heading missing")
329:    fail(f"{TEMPLATE}: expected exactly one '{LEVEL_PREFIX}' line, found {len(level_lines)}")
334:        fail(
344:    fail(f"{TEMPLATE}: expected exactly one '{VERDICT_PREFIX}' line, found {len(verdict_lines)}")
348:        fail(
359:    fail(f"{rel} missing or unreadable")
365:            fail(f"independence level '{level}' from {TEMPLATE} not found in {SKILL}")
375:            fail(f"independence level '{level}' from {TEMPLATE} not found in {PROBES}")
392:            fail(f"verdict vocabulary '{anchor}' from {TEMPLATE} not found in {rel}")
406:    fail "[plan-frontmatter] $err"
410:  fail "[plan-frontmatter] no plan files found"
488:def fail(msg):
541:            fail(f"{rel}: carry-forward cites {tid} but no such T-ID in interview transcript")
554:        fail(
575:def fail(msg):
580:        fail(f"{label}: no numbered items found")
584:            fail(f"{label}: gap between {numbers[i]} and {numbers[i + 1]}")
592:        fail(f"{p.relative_to(root)} missing")
629:    fail("skills/planning/schemas/plan-schema.md: '## Document body — hard floor' section not found")
646:            fail(f"{rel}:{line}: 'step {ref}' references nonexistent planning step")
652:        fail(f"skills/planning/schemas/plan-schema.md:{line}: 'item {ref}' references nonexistent hard-floor item")
816:def require(relative, text, needle):
881:        require(planning_rel, discrimination[0], clause)
884:    "Different artifact kinds in the real comparands or either fixture pair fail this check outright",
898:        require(loop_rel, transition_contract[0], clause)
909:    require(loop_rel, loop, clause)
933:        require(shipping_rel, persist_contract[0], clause)
961:        require(shipping_rel, step_contracts["1"], clause)
967:        require(shipping_rel, step_contracts["2"], clause)
973:        require(shipping_rel, step_contracts["3"], clause)
978:        require(shipping_rel, step_contracts["4"], clause)
998:        require(shipping_rel, cleanup_contract[0], clause)
1035:    require(addendum_rel, addendum, heading)
1041:    require(packet_rel, packet, clause)
1204:        failures.append(f"FAIL: {TAG} tampered packet fixture did not fail on its payload pin")
```