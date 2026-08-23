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
4. Persist the exact collision-resolved destination in the selected ledger before any child move. For completed work, set `phase: done` and `phase_status: complete` atomically. Refresh `updated`. Write one `<timestamp> retro: archive-destination: <path>` Log line. For user-directed incomplete work, keep the nonterminal phase unchanged. Write one distinct `<timestamp> archived-incomplete: archive-destination: <path>` Log line.
5. Run `python3 "$release_loop_skill_root/scripts/run-artifact-integrity.py" archive --repo . --progress-path <repo-relative-progress-path> --destination <repo-relative-archive-path>` only after step 4 persists the canonical evidence. The CLI validates one exact marker and its matching phase state before a move. It never writes ledger evidence or changes phase. It returns `state: archived` for completed evidence and `state: archived-incomplete` for incomplete evidence. On rerun, omit `--destination`; the command reads the persisted path.
6. A valid done record with one completed destination marks an interrupted completed archive. A nonterminal record with one incomplete destination marks an interrupted user-directed incomplete archive. For either mode, reuse the exact recorded archive destination. Do not calculate another suffix. Duplicate, mixed-mode, phase-mismatched, or argument-mismatched evidence blocks before movement.
7. For a scoped run, move only the remaining children of its exact `artifact_root`. Move scoped `progress.md` last as the archive commit point.
8. For a legacy run, move only `briefs`, `reports`, `reviews`, `evidence`, and its corrupt backups. Move the selected root `progress.md` last.
9. Verify the terminal record against the retained destination. A rerun reads the destination from the source ledger. It moves only remaining children. It never reverses a terminal archive.

The archive transition is local-only and can run headlessly after it proves that no outward target exists. Pre-move cancellation preserves the source and recorded destination. Mid-move cancellation leaves the selected progress record in the source scope. This rule applies to scoped and legacy archives. The next invocation reads that record and finishes the same destination. Ambiguous bytes require manual recovery without source deletion.

After Retro's exit condition holds, run the Archive procedure before reporting done. Retain the exact returned `archive_path`. Verify that the selected live progress path is absent. Verify the terminal record, Retro evidence, and destination marker. The completion report names that path.
