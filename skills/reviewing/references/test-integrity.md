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

## Finding boundary

Keep test-trust findings in this sub-check. Route shell injection, credential exposure, SSRF, or authorization bypasses to `security`; unbounded test resource use to `resilience`; published shape changes to `api-contract`; and ordinary missing scenario coverage to the parent `tests` focus. A review body that states a test-integrity finding must use the same file, line, title, severity, and evidence identity as its structured finding.

## Required dogfood evidence

The C2-TI evaluator must include two seeded defects and one holdout for each check, a clean fixture, three repeated runs, schema validation, recall and precision, zero clean-fixture P0/P1 findings, isolated `HOME` and `TMPDIR`, an empty hooks directory, disabled signing, and zero network or model calls. A defect-removal mutation that fails during fixture setup is not discrimination evidence and must be recorded as a harness failure.
