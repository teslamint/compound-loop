# Merge Pipeline

Converts N lane returns (merge-tier fields: `title, severity, file, line, confidence, autofix_class, owner, requires_verification, pre_existing`, plus optional `suggested_fix`) into one deduplicated, confidence-gated `schemas/review-envelope.schema.json` payload. Confidence is one of 5 discrete anchors -- treat as integers, never coerce to floats.

## 1. Validate

Drop malformed returns/findings (missing required fields, wrong enum values) and record the drop count. Do not validate detail-tier fields (`why_it_matters`, `evidence`) here -- those apply to the on-disk artifact, not the compact return.

## 2. Deduplicate

Fingerprint = `normalize(file) + line_bucket(line, +/-3) + normalize(title)`. Matching fingerprints merge into one finding: keep the highest severity, keep the highest confidence anchor, and record every contributing lane in `lanes`.

## 3. Cross-lane promotion

When 2+ independent lanes report the same fingerprint, promote the merged finding **one anchor step**: `50 -> 75`, `75 -> 100`, `100 -> 100`. This runs before the confidence gate so agreement can rescue a borderline finding.

## 4. Mode-aware demotion

A finding demotes out of primary findings into `testing_gaps` (contributing lane `tests`) or `residual_risks` (contributing lane `architecture`) only when **all** of these hold: severity is P2 or P3, `autofix_class` is `advisory`, and **every** contributing lane is `tests` or `architecture` -- corroboration from any other lane keeps the finding in primary findings regardless of severity. Demoted lines are title-only (`<file:line> -- <title>`); record the demotion count for coverage reporting.

## 5. Confidence gate (last, deliberately)

Runs **after** promotion and demotion so a borderline anchor-50 finding gets a chance to be rescued first. Suppress everything below anchor 75. **Exception**: P0 findings at anchor 50+ survive -- a critical-but-uncertain issue must never be silently dropped. Record the suppressed count by anchor.

## 6. Sort and number

Order: severity (P0 first) -> confidence (descending) -> file -> line. Assign a monotonically increasing `#` once, in that order -- never renumber per severity table or per report section; a finding keeps its `#` everywhere it's referenced.

## Validator protocol (interactive verification path)

One independent validator sub-agent per surviving finding -- a fresh second opinion, not a critique of the original lane's reasoning.

**Budget cap**: 15 findings. Never drop a P0/P1 to fit the cap -- if P0/P1 findings alone exceed 15, raise the cap to include all of them; only the P2/P3 tail is subject to it.

**3 questions per validator**: (1) is the issue real in the code as written -- not already guarded, misread, or intentional; (2) is it introduced by *this* diff, or pre-existing and merely visible through it; (3) is it already handled elsewhere (caller, middleware, framework default, parallel handler)?

**Conservative-reject bias**: when in doubt, reject. A validator wrongly rejecting a real finding costs one re-flag on the next pass; a validator confirming a false positive costs a wasted fix downstream.

**Infra-failure handling** (timeout, dispatch error, malformed output -- not a genuine `validated:false` verdict): severity-differentiated. **P0/P1**: keep the finding, mark validation **degraded**, note it in coverage -- a transient failure must never silently remove a critical finding. **P2/P3**: drop with reason "validator failed" -- the conservative bias extends to infra failures at low severity, where the cost asymmetry flips.

## Atomic artifact writes (`enforces: P8`)

Every artifact this pipeline writes (per-lane JSON, the merged envelope, the rendered report) is written to a temp file then renamed into place -- never streamed directly to the final path. A corrupt or partial artifact discovered on read is treated as a **lane failure**, handled per `references/dispatch-degradation.md`'s worker-failure rules (critical lanes kept-but-marked-degraded, advisory lanes dropped with a coverage note) -- never as an empty/clean result.
