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

Check every verifier and assertion adapter for ignored exit status, swallowed exceptions, default-success fallbacks, unchecked `check=False` results, and missing or unknown verdict handling. A malformed, missing, or infrastructure-error result must fail closed rather than become `clean`, `pass`, or an empty finding list. Severity is P0 when the path authorizes a release or mutation and P1 otherwise.

Evidence traces the failure input to the success path. Do not flag a deliberately handled expected rejection whose result is asserted and whose unknown or infrastructure states remain distinct.

### Assertion specificity

Check that tests assert the intended observable behavior, failure class, target identity, and post-state. Flag truthiness-only assertions, unconditional success assertions, broad output substring checks, exit-code-only checks when output or state is the contract, and assertions that can pass before the target behavior executes. Severity is P1 when a false green can authorize a release; otherwise P2 or P3 based on the threatened contract.

Evidence cites the assertion and the untested distinction. Do not flag a deliberately narrow assertion when another assertion in the same case verifies the required state and failure mechanism.

### Hidden environment dependencies

Check whether tests read host `HOME`, `PATH`, `TMPDIR`, locale, timezone, credentials, Git configuration, network proxy variables, or tool-specific configuration without setting or clearing them in the fixture. Flag environment reads that change the verdict or target and are not represented in the fixture's declared inputs. Severity is P1 when host state can change authorization or target selection and P2 otherwise.

Evidence names the environment key or implicit process state and the missing fixture declaration. Do not flag an explicitly supplied value that the fixture records and verifies.

### Fixture Git signing/hooks

Check every temporary Git repository for explicit identity, signing policy, hooks path, and remote configuration. A fixture must not inherit host signing keys, global hooks, credential helpers, or remotes. Flag missing `commit.gpgsign=false` when the fixture must commit without host keys, missing empty `core.hooksPath`, and use of an inherited global configuration. Severity is P1 when host code can execute or a commit cannot be reproduced; otherwise P2.

Evidence cites the Git setup and the inherited state that remains possible. Do not flag a fixture that sets all required keys explicitly and proves its hooks directory is empty.


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

The release gate scores the real model reviewer against three corpora: `tests/conformance/review/test-integrity-corpus.json`, `tests/conformance/review/test-integrity-blind-dev.json`, and `tests/conformance/review/test-integrity-blind-confirm.json`. The two blind corpora were authored blind to the detectors. Keep `scripts/test-review-test-integrity.sh` as an offline deterministic-regex regression check; its result is not the model release verdict.

First create the exact request plan without invoking a model:

```sh
python3 scripts/eval-test-integrity-model.py plan \
  --corpus tests/conformance/review/test-integrity-corpus.json \
  --corpus tests/conformance/review/test-integrity-blind-dev.json \
  --corpus tests/conformance/review/test-integrity-blind-confirm.json \
  --out /tmp/c2ti-model-plan
shasum -a 256 /tmp/c2ti-model-plan/plan.json
```

Review the request payloads and explicitly approve the printed `plan.json` SHA-256 before any model call. Only then run the caller-selected model command, passing that exact digest as `--approval`; the command receives each request on stdin and raw responses are stored under `responses/`.

The model command MUST be tool-free: the model may see only the planned messages. Agent CLIs such as `claude -p` or `codex exec` can read files, run shell commands, or call MCP servers, so the model could read the corpus answers in this repository; their results do not count. Use `scripts/model-chat-adapter.py`, which sends the planned messages to an OpenAI-compatible endpoint and prints the reply unchanged:

```sh
C2TI_MODEL_BASE_URL=<https://host/v1> C2TI_MODEL=<model> C2TI_MODEL_TOKEN=<token> \
python3 scripts/eval-test-integrity-model.py run \
  --plan /tmp/c2ti-model-plan/plan.json \
  --command 'python3 scripts/model-chat-adapter.py' \
  --approval <approved-plan-json-sha256>
```

For one run, score with `--responses /tmp/c2ti-model-plan/responses`. For the required three-run determinism check, preserve each run in a separate response directory and use `--responses <run-1-dir> <run-2-dir> <run-3-dir> --repeat 3`. Supply all three `--corpus` arguments to `score` as in `plan`. The gate requires 100% P0/P1 recall, at least 90% precision, zero P0/P1 false positives on negative/clean cases, no malformed or missing responses, and identical predicted class-id sets in every repeat. The report also includes per-class results and severity agreement; disagreement is reported for review. Planning, scoring, and the fixture tests are offline; only the explicitly approved `run` subcommand makes model calls.
