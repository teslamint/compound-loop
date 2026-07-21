# CONCEPTS

Shared vocabulary for this repo. One canonical term per concept; definitions stay conceptual — no implementation specifics, status, or links.

## Release verification

- **Source inventory** — the enumerable list of items a derived deliverable is authored from (mechanisms distilled into skills, records in a migration, sections in a consolidation).
- **Drop-list** — the explicit, reasoned record of source-inventory items deliberately left out of a deliverable. The only artifact where a silent omission is visible; each entry carries a reason judged by a reviewable rubric.
- **Structural criterion** — a success criterion that measures an artifact's presence or well-formedness (exists, parses, loads, emits an expected line) rather than its content. *Avoid: presence check* as a criterion name — reserve it for describing what the criterion measures.
- **Traceability criterion** — a success criterion requiring every source-inventory item to be either present in the deliverable (with a citation) or on a drop-list with a reason. The fidelity-class complement to structural criteria for inventory-derived work.
- **Content-fidelity drift** — divergence between a source inventory and the content authored from it; invisible to structural criteria by construction.

## Release ceremony

- **Release ceremony** — the post-merge process that turns merged work into a versioned release: CHANGELOG authoring, version bump, and tag. Owned by `release`, deliberately separate from feature shipping so features stay independently revertable.
- **Four-way version agreement** — the release-time invariant that both plugin manifests, the newest CHANGELOG section, and the newest tag name the same version.
- **Backfill** — creating CHANGELOG sections for releases that predate the file itself, derived from their committed specs and retros; keyed on the file's absence, one-time per repo.
- **Prepare-only** — the headless posture of a ceremony that requires first-hand consent: run every step up to the gate, persist the draft and exact commands, and stop with a skip signal instead of executing.
- **Deviation addendum** — a committed companion to an approved spec or plan that preserves the original approval record while documenting post-approval observable behavior before release. *Avoid: implementation drift record* — the addendum records an authorized contract change, not merely that code differs.

## Python compatibility

- **Supported Python range** — the inclusive interval of CPython minor versions that repo-owned Python entry points and generated Python artifacts are expected to support.
- **Boundary interpreter** — the oldest or newest minor in the supported Python range, used as an explicit endpoint for compatibility evidence.
- **Generated Python artifact** — Python source rendered by another program and executed later; distinct from Python source executed directly by its containing shell command.

## Retrospective interview

- **Interview transcript** — the retro doc's record of every probed exchange between facilitator and respondent, accepted and rejected alike; the only content findings may cite beyond measured data.
- **Transcript triple** — one probed exchange: probe, answer, evidence, carrying a facilitator-authored verdict recorded verbatim.
- **Independence level** — the closed vocabulary describing how independent a retro's facilitator was from the respondent (heterogeneous, same-model fresh-context, in-thread approximated, self-checklist); recorded so a reader can judge the bias-guard's strength from the doc alone. *Avoid: tool names* — the level describes independence, not mechanism.
- **Self-attested** — a verdict authored by the same agent that produced the answer, in degraded modes with no independent facilitator; never to be read as acceptance.
- **Backward check** — the audit a retro performs on the previous cycle's retro doc while reading it, from an execution independent of the one that wrote it; catches violations one cycle late but outside the writer's own discipline.

## Session resilience

- **Final-action record** — the durable record naming a workflow's single irreversible/final action: its kind, a closed status (predicted, determined, executed), and the exact command once determined. Preparation evidence only — possession of the command is never permission to run it.
- **Prepare-before-gate** — the invariant that the exact command packet of a gated irreversible action is persisted durably before the gate resolves, whether the gate blocks on a human question or evaluates automatic conditions; disk never trails the conversation.
- **Non-authorization marker** — the explicit statement carried by every persisted command packet that it is preparation evidence, never approval; the file-shaped counterpart of "gate approval is not execution authorization".

## Metrics

- **Changed non-test lines** — the count of modified lines (added + removed) excluding tests, generated files, and lockfiles, used as the canonical diff-size metric across all phases (e.g. lane triggers).
