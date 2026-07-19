# Deviation Addendum 002: Python Gate Assumption Evidence Command

_Recorded 2026-07-19 before Python compatibility plan approval._

## Original contract

The approved design at
`docs/specs/2026-07-19-python-compatibility-generated-code-warning-gate-design.md`
retains a live assumption that the doubled-escape nested HTTP regex in
`scripts/release-publication.sh` is a unique empirical mutation target. Its
five-field evidence row records an inline Python count command and an observed
result of one match.

## Discovered contradiction

The planning Assumption Recheck reran the retained command exactly on
`feat/python-generated-warning-gate` at `2026-07-19T12:38:21+09:00`. It returned
`0`, contradicting the approved evidence row's result of `1`. The command's
quoted needle includes an unintended escaped quote, so it does not represent
the source text it claims to count.

The underlying source target remains unique. This corrected bounded command
returns `1` and identifies line 463:

```sh
grep -F -c 'match=re.fullmatch(r"HTTP/(?:1\\.1|2(?:\\.0)?)' scripts/release-publication.sh
```

## Necessity

Planning cannot classify the approved live assumption as a match using a
command that reproduces the opposite count. Preserving the approved spec while
recording the corrected command keeps the original approval history intact and
gives implementation a reproducible fixture precondition.

## Observable behavior

No product, validation, terminal-output, or compatibility behavior changes.
The approved requirement remains that the disposable invalid-escape fixture
must mutate exactly one nested generated-program regex. This addendum changes
only the evidence command used to prove that precondition.

## Safety and consent boundaries

The corrected command reads one tracked source file and performs no mutation,
network access, interpreter installation, or outward action. The approved
fail-closed compatibility policy and user-approval boundaries are unchanged.

## Verification changes

- Planning records the original retained command as a contradiction resolved
  by this addendum rather than mislabeling it as a clean match.
- Implementation reruns the corrected fixed-string count before constructing
  the disposable invalid-escape fixture and requires exactly one match.
- The fixture still mutates only a disposable copy and must not edit the real
  publication script during negative-path validation.

## Traceability

- Approved spec: commit `4566b7c`.
- Contradictory retained command: Assumptions and Preconditions row 5 in the
  approved spec.
- Planning recheck: first-hand run on 2026-07-19 at
  `2026-07-19T12:38:21+09:00`.
- Corrected evidence: fixed-string count and line lookup returned one match at
  `scripts/release-publication.sh:463`.
- Authority for this artifact shape:
  `docs/solutions/workflow-issues/review-introduced-state-machine-deviation.md`.
