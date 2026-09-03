## Resuming (`resume` argument)

1. Run `python3 "$release_loop_skill_root/scripts/run-artifact-integrity.py" discover --repo .`. For an exact selector, add `--progress-path <repo-relative-progress-path>`. Discover records at `.release-loop/progress.md` and `.release-loop/runs/*/progress.md`. Reject each unknown schema or symlink record. Do not discard an invalid record because another record is valid.
2. Exactly one valid live record resumes without another selector. Multiple valid records require one exact repo-relative progress path. A feature name never resolves an ambiguous legacy and scoped pair. An unattended ambiguity returns blocked context before mutation.
3. If no live record exists, require a validated feature selector before an archive lookup. Bare interactive `resume` asks for the feature and waits. An unattended call returns blocked context. Do not infer the selector from an archive or branch.
4. Search completed archives only for that exact `feature:`. A candidate requires `phase: done`, `phase_status: complete`, and valid destination evidence. One candidate reports completion. Zero candidates enter reconstruction. Multiple candidates stop as ambiguous. A legacy candidate without destination evidence enters reconstruction.
5. Validate the selected progress path and its stored `artifact_root`. Verify the recorded branch and artifact pointers before any move. Treat an invalid slug, root, or path as corrupt state.
6. After reconstruction, archive proven completion or resume the reconstructed phase. **The selected progress file and `git log` always outrank conversation memory.** `enforces: P8`
7. Verify any `determined` `final_action` against live PR and head state before trusting it. A failed check flips it to `predicted` and logs the reason.
8. Resume at the recorded or reconstructed phase and unit.

## Completing and archiving

A **Loop archive** moves a loop's local working state to its terminal home. Run this procedure after Retro's exit condition holds (`retro` committed). `enforces: P8`

### Archive procedure

1. Determine completion from the `retro:` pointer or a Retro commit found through `git log`. Validate `feature:`, the exact progress path, and `artifact_root` before any lookup or move.
2. Resolve and validate one destination inside the fixed `.release-loop/archive` family. Never derive the allowed root from the candidate destination. Reject absolute paths and parent escapes. Reject every symlink in each existing source or destination component.
3. On the first attempt, choose `.release-loop/archive/<YYYY-MM-DD>-<feature_slug>/`. Add `-2`, `-3`, and so on for collisions. Use the current completion date, the Retro commit date during reconstruction, or the archive date for incomplete work.
4. Persist the exact collision-resolved destination in the selected ledger before any child move. For completed work, set `phase: done` and `phase_status: complete` atomically. Refresh `updated`. Write one `<timestamp> retro: archive-destination: <path>` Log line. For user-directed incomplete work, require both phase fields and keep them unchanged. Each must belong to the progress schema's closed vocabulary. Require `phase != done` and `phase_status != complete`. Write one distinct `<timestamp> archived-incomplete: archive-destination: <path>` Log line.
5. Run `python3 "$release_loop_skill_root/scripts/run-artifact-integrity.py" archive --repo . --progress-path <repo-relative-progress-path> --destination <repo-relative-archive-path>` only after step 4 persists the canonical evidence. The CLI validates one exact marker and its matching phase state before a move. It never writes ledger evidence or changes phase. It returns `state: archived` for completed evidence and `state: archived-incomplete` for incomplete evidence. On a pre-commit rerun, omit `--destination`; the command reads the persisted path. If the progress commit point already moved, repeat the exact canonical `--destination` so the CLI can validate the terminal archive and finish scoped cleanup.
6. A valid done record with one completed destination marks an interrupted completed archive. A nonterminal record with one incomplete destination marks an interrupted user-directed incomplete archive. For either mode, reuse the exact recorded archive destination. Do not calculate another suffix. Duplicate, mixed-mode, phase-mismatched, or argument-mismatched evidence blocks before movement.
7. For a scoped run, move only the remaining children of its exact `artifact_root`. Move scoped `progress.md` last as the archive commit point.
8. For a legacy run, validate the accepted V1 ownership block and its exact `.release-loop/v1` tree. Move V1 with `briefs`, `reports`, `reviews`, `evidence`, publisher state, and corrupt backups. Never move `archive`, `.handoff`, or `runs` as active state.
9. Move the selected root `progress.md` last. This move is the archive commit point.
10. Verify the terminal record and V1 tree against the exact returned `archive_path`. A rerun uses the persisted destination. It accepts V1 in either source or destination, but never both. It moves only remaining children.

### Recovering an archived-incomplete scoped run

Use recovery only for one exact scoped `archived-incomplete` packet. The
orchestrator supplies the current-session USER gate answer; the CLI never
accepts an answer, receipt, digest, or replacement target from its caller.

1. Request the packet and pin the live gate ledger:
   `request-legacy-archive --repo . --recovery-id <id> --progress-path <archive-progress> --gate-progress-path <gate-progress> --session <session>`.
2. Publish the gate-owned approval with only `--repo` and `--recovery-id`.
3. Copy the terminal archive to the reserved backup root, then run the audit.
4. Restore only the derived scoped target. Never restore a legacy root or
   reverse a completed archive. An interrupted copy, executor claim, or
   occupied target is ambiguous and requires operator resolution before a new
   recovery ID.

Resume the same recovery ID and the same reserved destination. Never allocate
a new identity or collision suffix for a started attempt. Resume in this order: G0 result, receipt R, G1, G2, G3, then the completed archive move.

- A G0 result without R republishes only R after it validates G0.
- R without G1 reuses R and reserves the recorded destination.
- G1 without G2 reruns only legacy-equivalent pre-archive validation.
- G2 without G3 reruns only the atomic done transition.
- G3 before or during movement resumes the same completed archive operation.

Each G1, G2, and G3 write fetches a fresh UTC timestamp. It updates the
top-level `updated` field in the same replacement. The generation evidence
records the predecessor's `updated` value. A retry adopts an exact durable
progress temporary and its timestamp only when G1 does not precede G0 or the
request.

Only G3 may enter the recovery archive move. G1 and G2 remain nonterminal.
Any changed digest, duplicate record, stale receipt, or changed destination
blocks. Keep the source archive, backup, and authority roots for inspection.

Read recovery gates, receipts, final-action evidence, and scalar authority only
from frontmatter. Body examples never supply authority. The audit also requires
one top-level approved plan status and one top-level stored body seal at the
approval commit. That seal must match both the plan body and the request pin.
Only an exact delimiter line closes frontmatter. A scalar containing `---`
cannot hide later authority or change the sealed plan body boundary.
Before acceptance, audit pins one audit timestamp. It validates the atomic Ship
and Retro timestamps, their nondecreasing order, and the request-time upper
bound. A future or inconsistent terminal timestamp blocks before restore.

Recovery payloads reserve all transaction basenames. This includes the
reservation files, progress temporary, and archive-control temporaries. It also
includes `.legacy-archive-recovery-owner-*.json` and
`.legacy-archive-recovery-pending-*.tmp` at any depth. A collision blocks the
request before authority creation. A completed-archive resume also requires
the exact journal derived from the pinned source. Deleting a valid owned row
blocks the resume.

The archive transition is local-only and can run headlessly after it proves that no outward target exists. Pre-move cancellation preserves the source and recorded destination. Mid-move cancellation leaves the selected progress record in the source scope. This rule applies to scoped and legacy archives. The next invocation reads that record and finishes the same destination. Ambiguous bytes require manual recovery without source deletion.

After Retro's exit condition holds, run the Archive procedure before reporting done. Retain the exact returned `archive_path`. Verify that the selected live progress path is absent. For a scoped record (`artifact_root: .release-loop/runs/<feature_slug>`), verify the terminal record, Retro evidence, destination marker, and exact `archive_path`; do not apply V1 tree checks. For a legacy record (`artifact_root: .release-loop`), also verify the live V1 tree is absent and the archived V1 tree is present at the exact returned path. The completion report names that path.
