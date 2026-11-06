# Test-integrity Sub-check

This checklist is a named sub-check of the always-on `tests` lane. It audits whether a test or fixture can produce a misleading green result. It does not replace the `tests` lane, create a new lane, or define a new finding schema.

## Contract

Read the changed test code and every helper that controls its environment, fixture, verifier, or assertion. For each applicable class, either cite the safe control or emit one standard detail-tier finding. Do not report a class from a filename alone. Trace the behavior to a source line, command, or configuration value.

Every finding must satisfy `schemas/lane-findings.schema.json`: use P0-P3 severity, one of the existing confidence anchors, one owner, one autofix class, an explicit verification flag, a failure-mode `why_it_matters`, and at least one code-grounded `evidence` item. Deduplicate and confidence-gate findings with `references/merge-pipeline.md`. A malformed or incomplete finding is a lane failure, not a clean result.

## Checks

### Network isolation

Check that fixture tests cannot reach external hosts through sockets, HTTP clients, package managers, SSH, remote Git helpers, or unrestricted subprocesses. Verify deny-by-default command policy, local-only remotes, cleared credential variables, and a command audit when the fixture launches processes. A reachable external target is P0 or P1 according to whether it can disclose credentials or mutate state.

Evidence names the executable or call site and the missing boundary. Do not flag a local bare remote or an explicitly injected in-process stub.

### Shared temporary directories

Check that each test run owns a unique disposable root and that all temporary files, sockets, logs, and generated repositories remain below it. Flag hard-coded shared paths, the process-wide temporary directory without a unique child, reusable fixture names, and cleanup that can remove another run's files. Severity is P1 when cross-run mutation or data disclosure is possible, otherwise P2.

Evidence includes the path expression and the isolation boundary it bypasses. Do not flag a unique `mktemp -d` or an equivalent standard-library temporary directory created per run.

### Verifier fail-open behavior

Check every verifier and assertion adapter for ignored exit status, swallowed exceptions, default-success fallbacks, unchecked `check=False` results, and missing or unknown verdict handling. A command substitution whose failure becomes empty output is one of these: `test -z "$(find ...)"`, `[ -z "$(tool ...)" ]`, or a pipeline whose exit status is not checked reports success when the command itself is missing, fails, or errors. A malformed, missing, or infrastructure-error result must fail closed rather than become `clean`, `pass`, or an empty finding list. Severity is P0 when the path authorizes a release or mutation and P1 otherwise.

Evidence traces the failure input to the success path. Do not flag a deliberately handled expected rejection whose result is asserted and whose unknown or infrastructure states remain distinct.

### Assertion specificity

Check that tests assert the intended observable behavior, failure class, target identity, and post-state. Flag truthiness-only assertions, unconditional success assertions, broad output substring checks, exit-code-only checks when output or state is the contract, and assertions that can pass before the target behavior executes. Severity is P1 when a false green can authorize a release; otherwise P2 or P3 based on the threatened contract.

Evidence cites the assertion and the untested distinction. Do not flag a deliberately narrow assertion when another assertion in the same case verifies the required state and failure mechanism.

### Hidden environment dependencies

Check whether tests read host `HOME`, `PATH`, `TMPDIR`, locale, timezone, credentials, Git configuration outside fixture repositories, network proxy variables, or tool-specific configuration without setting or clearing them in the fixture. Flag environment reads that change the verdict or target and are not represented in the fixture's declared inputs. Severity is P1 when host state can change authorization or target selection and P2 otherwise.

Evidence names the environment key or implicit process state and the missing fixture declaration. A read of host `HOME` or `PATH` that the snippet does not first set or clear is a finding even when the snippet shown only stores or prints the value, because the fixture has not declared the input. The temporary root is an exception: `mktemp`, `tempfile.gettempdir()`, `tempfile.TemporaryDirectory()`, and the process temporary directory are judged only under Shared temporary directories, and the host `TMPDIR`, `TEMP`, or `TMP` they consult is not a separate Hidden environment dependency unless the snippet uses the value for something else. Do not flag an explicitly supplied value that the fixture records and verifies.

### Fixture Git signing/hooks

Check every temporary Git repository for explicit identity, signing policy, hooks path, and remote configuration. A fixture must not inherit host signing keys, global hooks, credential helpers, or remotes. Flag missing `commit.gpgsign=false` when the fixture must commit without host keys, missing empty `core.hooksPath`, and use of an inherited global configuration. Severity is P1 when host code can execute or a commit cannot be reproduced; otherwise P2.

Evidence cites the Git setup and the inherited state that remains possible. Do not flag a fixture that sets identity and `commit.gpgsign=false` locally and takes one of these hook-isolation forms: an empty `core.hooksPath`, a `core.hooksPath` directory the fixture created and does not populate, or `core.hooksPath=/dev/null`. Those keys isolate signing and hooks only. Other inherited Git configuration can still execute host code, so do not describe local keys as complete isolation: a global `core.fsmonitor`, `core.attributesFile` with a `filter.<name>.clean` command, or a global `init.templateDir` remains reachable. Flag that residual only when host code can execute through it, and treat a fixture that must exclude host Git configuration entirely as requiring `GIT_CONFIG_GLOBAL` and `GIT_CONFIG_NOSYSTEM`.

### Class boundaries

Report each defect once, under the single class that owns it:

- Git identity, signing, hooks, credential helpers, remote settings, and inherited global or system Git configuration of a fixture repository belong to Fixture Git signing/hooks. Do not also report that configuration as a hidden environment dependency. A Git command that actually contacts an external remote, such as `clone`, `fetch`, or `push`, is a separate Network isolation defect.
- A configured remote, URL, or host name that the code never contacts is not a network defect. Network isolation needs a call or command that can reach an external host.
- An ignored exit status, swallowed exception, or default-success value belongs to Verifier fail-open behavior. Report Assertion specificity only for a test assertion that can pass without the required behavior.
- Hidden environment dependencies covers host state other than Git configuration that the snippet reads or that selects its target or verdict. Running a tool or `git` binary from `PATH` is not by itself an environment defect. Package-source settings such as `PIP_INDEX_URL` or `PIP_CONFIG_FILE` inherited by an install command belong to Network isolation when that command can reach an external index, not to this class.
- Judge only the text shown. Do not report a class because unseen helper code might be unsafe.
- A snippet is often a fragment written to show one defect. When another class owns that defect, do not also report Assertion specificity because the fragment lacks an assertion; report that class only for an assertion that is present and too weak.


## Per-run evidence record

Every full phase-gate review MUST atomically persist one event-bound record at `<artifact_root>/reviews/events/<event-id>-test-integrity.json` before deciding its verdict. The `test-integrity-run/v1` object contains `run_id`, `event_id`, `reviewed_head`, `status` (`complete` only after the sub-check finishes; `cancelled` otherwise), `raw_evidence`, and `normalized_findings` validated against `schemas/lane-findings.schema.json`, including an empty array when none were found. Bind `event_id` and `reviewed_head` to the current review event; a prior event's complete record is stale and cannot satisfy this event. Derive the path from the validated review artifact root; do not write outside it. Missing, cancelled, stale-event, stale-head, or malformed records MUST block a clean verdict per [references/merge-pipeline.md](merge-pipeline.md). `records` mode verifies these cases; `record` mode requires the record path, current event ID, and reviewed head via environment.
## Finding boundary

Keep test-trust findings in this sub-check. Route shell injection, credential exposure, SSRF, or authorization bypasses to `security`; unbounded test resource use to `resilience`; published shape changes to `api-contract`; and ordinary missing scenario coverage to the parent `tests` focus. A review body that states a test-integrity finding must use the same file, line, title, severity, and evidence identity as its structured finding.

## Required dogfood evidence

The C2-TI evaluator must include at least two seeded defects per class and a clean fixture, three repeated runs, schema validation, seed recall and precision, zero clean-fixture P0/P1 findings, isolated `HOME` and `TMPDIR`, an empty hooks directory, disabled signing, and zero network or model calls. When an independent holdout corpus is supplied, require at least one positive and one negative holdout per class and report separate holdout recall and precision. Until then, report positive/negative holdout counts without claiming held-out performance. A defect-removal mutation removes the seeded defect line from its source and must fail on that seed ID; a setup failure is not discrimination evidence.
 
## Adding a fixture

Add a unique case with `id`, `class`, `kind` (`seed`, `holdout`, or `clean`), `file`, `source`, and `expected_findings`. Seed and holdout cases use one of the six declared class IDs; clean cases are scanned by every class probe. A positive seed or holdout lists `{ "seed_id": "<case id>", "severity": "<class severity>" }`. Analyzer-owned `CLASS_SEVERITY` values come from the severity rules in each class section below; the corpus class declaration and every expected severity must match those constants. Negative-control holdouts use an empty `expected_findings` list and must remain clean under every probe. Cases used while developing probes are seeds, not holdouts. A separate optional JSON corpus of `holdout` cases can be supplied with `C2_TI_HOLDOUTS=<path>`; when present it must include at least one positive and one negative case for every class and is scored separately for positive recall and precision. Until the independent holdout corpus is available, report its counts rather than claim held-out performance. Do not broaden a probe merely to make a positive holdout pass. The shared-temp negative control asserts `root.is_dir()` rather than bare `assert root`: bare truthiness is a genuine assertion-specificity defect and would be a cross-class finding, not a false positive.

Run `bash scripts/test-review-test-integrity.sh seeded` to exercise seed and holdout cases, or `bash scripts/test-review-test-integrity.sh` for the complete evaluator. The complete evaluator also runs the record fail-closed cases (`records` mode); `record` mode validates a persisted record named by `COMPOUND_LOOP_TEST_INTEGRITY_RECORD`.

## Model release gate

The release gate scores the real model reviewer against six corpora: `tests/conformance/review/test-integrity-corpus.json`, `tests/conformance/review/test-integrity-blind-dev.json`, `tests/conformance/review/test-integrity-blind-confirm.json`, `tests/conformance/review/test-integrity-blind-final.json`, `tests/conformance/review/test-integrity-blind-gate2.json`, and `tests/conformance/review/test-integrity-blind-gate3.json`. The blind corpora were authored without access to the detectors. The first five were used to tune or correct the checklist, so they are regression data, not out-of-sample evidence. `test-integrity-blind-gate3.json` is the out-of-sample corpus: it was written after the checklist was fixed, by an author who had only the class descriptions. Two independent judges labeled its sources without seeing the labels and agreed with 35 of its 36; the one dispute is recorded under `label_audit`. Report its figures separately, which needs a separate plan and score run containing only that corpus, because `score` has no per-corpus breakdown and class severities are declared only in `test-integrity-corpus.json`. Keep `scripts/test-review-test-integrity.sh` as an offline deterministic-regex regression check; its result is not the model release verdict.

First create the exact request plan without invoking a model:

```sh
python3 scripts/eval-test-integrity-model.py plan \
  --corpus tests/conformance/review/test-integrity-corpus.json \
  --corpus tests/conformance/review/test-integrity-blind-dev.json \
  --corpus tests/conformance/review/test-integrity-blind-confirm.json \
  --corpus tests/conformance/review/test-integrity-blind-final.json \
  --corpus tests/conformance/review/test-integrity-blind-gate2.json \
  --corpus tests/conformance/review/test-integrity-blind-gate3.json \
  --out /tmp/c2ti-model-plan
shasum -a 256 /tmp/c2ti-model-plan/plan.json
```

Review the request payloads and explicitly approve the printed `plan.json` SHA-256 before any model call. Only then run the caller-selected model command, passing that exact digest as `--approval`. The command receives each request on stdin. `run` checks every request digest before the first call, writes raw responses to a fresh `--responses` directory, and publishes that directory only after every case succeeds, so responses from different runs never mix.

The model command MUST be tool-free: the model may see only the planned messages. Agent CLIs such as `claude -p` or `codex exec` can read files, run shell commands, or call MCP servers, so the model could read the corpus answers in this repository; their results do not count. Use `scripts/model-chat-adapter.py`, which sends the planned messages to an OpenAI-compatible endpoint and prints the reply unchanged:

```sh
C2TI_MODEL_BASE_URL=<https://host/v1> C2TI_MODEL=<model> C2TI_MODEL_TOKEN=<token> \
python3 scripts/eval-test-integrity-model.py run \
  --plan /tmp/c2ti-model-plan/plan.json \
  --command 'python3 scripts/model-chat-adapter.py' \
  --responses /tmp/c2ti-run-1 \
  --approval <approved-plan-json-sha256>
```

For one run, score with `--responses /tmp/c2ti-run-1`. For the required three-run determinism check, run three times into three different directories and use `--responses <run-1-dir> <run-2-dir> <run-3-dir> --repeat 3`. Supply all six `--corpus` arguments to `score` as in `plan`. The gate requires, in every repeat, 100% P0/P1 recall, at least 90% precision, zero P0/P1 false positives on negative/clean cases, and no malformed or missing responses. Determinism requires the same set of detected seed ids in every repeat; free-text wording and extra findings do not count toward it, but extra findings still lower each repeat's precision. The report shows the worst repeat as its headline figures, lists each repeat under `repeats`, and also includes per-class results and severity agreement; disagreement is reported for review. Planning, scoring, and the fixture tests are offline; only the explicitly approved `run` subcommand makes model calls.
