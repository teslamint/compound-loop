---
module: release-loop
date: 2026-08-25
problem_type: runtime_error
component: run-artifact-integrity
severity: medium
symptoms:
  - "`run-artifact-integrity.py archive` exits 1 with 'unsupported source entry' naming a .sock file"
  - "Archive refuses to proceed; all other source entries are valid"
root_cause: "Stale Unix domain socket left by a terminated Claude Code subprocess (srt-mux) inside the artifact tree"
resolution_type: manual_cleanup
tags:
  - archive
  - socket
  - release-loop
  - subprocess-cleanup
---

# Stale Socket Blocks Archive CLI

## Problem

`python3 run-artifact-integrity.py archive` exits 1 with `archive destination conflict: unsupported source entry evidence/live-runs/<uuid>/tmp/srt-mux-<pid>-0.sock`. The archive CLI validates that every source entry is a regular file or directory before moving. A Unix domain socket is neither, so the move is rejected.

## Symptoms

- Archive CLI refuses to proceed with exit code 1
- Error message names a `.sock` file path under `.release-loop/evidence/live-runs/`
- The socket belongs to `srt-mux`, Claude Code's subprocess multiplexer, which terminated without cleaning up its IPC socket

## What Didn't Work

N/A — identified on first encounter.

## Solution

1. Locate stale sockets: `find .release-loop/ -type s`
2. Remove them: `rm <each-socket-path>`
3. Re-run the archive command.

```bash
find .release-loop/ -type s -delete
python3 "$release_loop_skill_root/scripts/run-artifact-integrity.py" archive \
  --repo . --progress-path .release-loop/progress.md \
  --destination .release-loop/archive/2026-08-25-fuzz-testing/
```

## Why This Works

Unix domain sockets are transient IPC endpoints. They carry no persistent data — they are file-system-visible handles for inter-process communication that become inert when the owning process exits. The archive CLI correctly rejects them (it cannot `cp` a socket), but the fix is to remove the dead socket rather than teach the CLI to skip it.

## Prevention

- Subprocesses that create sockets inside artifact trees should use `/tmp` or a location outside the artifact root.
- The archive CLI could add a pre-flight step that auto-removes socket files (`-type s`) from the source tree before validation, since sockets are never archivable content.
- A post-pilot cleanup step in the live-run orchestrator would also prevent accumulation.
