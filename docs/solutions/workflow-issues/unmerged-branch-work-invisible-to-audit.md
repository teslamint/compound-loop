---
module: release-loop
date: "2026-08-15"
problem_type: workflow_issue
component: completeness-audit
severity: high
symptoms:
  - "an audit of the base branch concludes a phase never ran, while a complete commit for it sits on an unmerged feature branch"
  - "one cycle acquires two deliverables for the same phase because the first was invisible to the audit that preceded the second"
  - "a reconciliation step that reads only the most recent document silently drops the older document's registered items"
  - "a document cites commit hashes that stop resolving after a squash-merged branch is deleted"
root_cause: a completeness audit reads the base branch tree, the base branch log, and gitignored loop state, and all three are blind to work committed on an unmerged branch inside an isolated worktree
resolution_type: audit_surface_and_evidence_retention
applies_when:
  - "a lifecycle phase runs inside an isolated git worktree and commits its deliverable there"
  - "a pull request is squash-merged, so branch commits are not ancestors of the base branch"
  - "a document cites commit hashes as evidence and its branch is a deletion candidate"
  - "auditing what work remains in a repository that uses worktree isolation by default"
related_components:
  - retrospective
  - shipping
  - worktree-isolation
tags:
  - completeness-audit
  - unmerged-work
  - squash-merge
  - evidence-reachability
  - worktree-isolation
---

## Context

The `retro-interview-integrity` cycle was squash-merged as `0086cff`. Its Retro
phase then ran inside the isolated worktree at
`.claude/worktrees/feat+retro-interview-integrity`, on the local branch
`worktree-feat+retro-interview-integrity`, and committed a complete retro there as
`bdf58dc`: a 120-line retro document, four new `ROADMAP.md` carry-forward rows, a
`CONCEPTS.md` section, a plan frontmatter flip, and a compound doc. That commit was
never merged and never pushed.

A day later an audit of remaining work read `git ls-tree origin/main docs/retros/`,
found no document for the cycle, and concluded the Retro phase was unfinished. A
second retro was written from the merged tree and pushed as `6683d0f`. For one
cycle two retro documents existed, and the second was authored with no knowledge of
the first — so the first document's four registered ROADMAP rows were untracked on
`main` until a later consolidation commit merged both.

Three signals an auditor would normally trust were all blind:

1. `git ls-tree origin/main <path>` shows the base branch tree only.
2. `git log` on the base branch excludes the branch's commits, and after a squash
   merge none of them is an ancestor of the base branch anyway.
3. The loop ledger `.release-loop/progress.md` still read
   `phase: retro / phase_status: in-progress`, and it is gitignored and
   worktree-local — it did not exist in the checkout where the audit ran.

The second half of the hazard surfaced during cleanup. The consolidated retro cites
eleven pre-squash commits as evidence: the red/green fixture pairs
`db994ed`→`49f468c`, `02e496f`→`b600096`, `9fb8a68`→`62ef004`,
`17ccb91`→`e01db8e`, and the plan-review chain `bcfff3c`, `86f066c`, `b8776fa`.
A squash merge leaves none of them reachable from the base branch, so
`git branch -D` would have made every cited hash unreachable from any ref while
every mechanical check stayed green. The remedy was an annotated tag
`evidence/retro-interview-integrity` created at the branch tip **before** deletion,
then pushed.

This is the committed-work counterpart to
`docs/solutions/workflow-issues/loop-deliverable-in-disposable-state.md`, which
covers artifacts that were never committed at all.

## Guidance

### Auditing completeness

Enumerate refs, not trees. A tree tells you what the base branch contains; it
cannot tell you what exists elsewhere.

```bash
BASE=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|origin/||' || echo main)
git worktree list                     # every checkout, including locked ones
git branch --format='%(refname:short)' # every local branch
for b in $(git branch --format='%(refname:short)'); do
  [ "$b" = "$BASE" ] && continue
  echo "== $b"; git log --oneline "$BASE..$b"
done
```

Then, for each branch with unmerged commits:

- Read what those commits actually contain (`git show --numstat <sha>`), rather
  than inferring from the subject line. A phase deliverable is often a docs-only
  commit that looks incidental.
- Do not trust `git branch --merged`. After a squash merge the branch is fully
  merged in content and completely unmerged in ancestry, so it never appears.
  Compare content, or read the PR's merge commit.
- Treat a worktree-local ledger as a claim about that worktree only. A ledger
  reading `in-progress` beside a commit that finished the phase means the phase
  updated the tree and not the ledger — the commit is the stronger evidence.

### Retaining cited evidence across a squash merge

Before deleting a squash-merged branch, decide whether anything cites its commits.

```bash
git show <branch>:docs/retros/<file>.md | grep -oE '\b[0-9a-f]{7,40}\b' | sort -u
git tag -a evidence/<slug> <branch> -m "Pre-squash chain cited by <doc path>"
git push origin evidence/<slug>
git branch -D <branch>
```

Verify reachability from refs afterwards, not from the reflog — the reflog is
local, expires, and is absent in every fresh clone:

```bash
for h in <cited hashes>; do
  git rev-list --all --tags | grep -q "$(git rev-parse "$h")" \
    && echo "$h reachable" || echo "$h LOST"
done
```

Write the tag message so it explains itself to someone who finds it later: which
PR it precedes, which document cites it, and why it exists. An unexplained tag is
the next candidate for cleanup.

## Why This Matters

Finished-but-unmerged is indistinguishable from unstarted when you look only at the
base branch, and the cost is paid twice. The first payment is duplicated work: an
entire deliverable reproduced because the original was invisible. The second is
silent data loss — where a later phase reconciles against "the most recent
document", a duplicate makes the older document's registered obligations
unreachable without any error being raised.

Evidence loss has the same shape. Deleting a squash-merged branch succeeds, the
tree is clean, structural validation passes, and CI is green, because all of them
read the base branch. The citations rot in place, and the defect surfaces only when
someone asks for the evidence a document already claimed to have.

Both halves share a root: a repository's durable surface is its refs, and an audit
that samples one ref reports on one ref.

## When to Apply

- Asking "what work remains" in any repository that isolates work in worktrees.
- Before `git branch -D`, `git worktree remove`, or `git worktree prune` on
  anything related to a merged cycle.
- Whenever a phase's deliverable is a commit produced inside an isolated worktree —
  push or merge it in the same action that writes it, and update the phase ledger
  at that moment.
- When a document cites commit hashes and its branch has been squash-merged.
- When a ledger and a commit disagree about whether a phase finished.

## Examples

The audit that missed it, and the audit that would not have:

```bash
# Blind: base-branch tree only
git ls-tree origin/main docs/retros/ | grep 2026-08   # no row for the cycle

# Sighted: ask the refs
git log --oneline main..worktree-feat+retro-interview-integrity
# bdf58dc docs(retro): Retro-interview-integrity cycle retrospective   <- the finished phase
git show --numstat bdf58dc                            # 5 files: retro, ROADMAP, CONCEPTS, plan, solution doc
```

Why `--merged` is the wrong question after a squash merge:

```bash
git branch --merged main | grep retro-interview   # no output: not an ancestor
git log --oneline main | grep 0086cff             # yet the content shipped here
```

Tag, delete, then prove the citations survived:

```bash
git tag -a evidence/retro-interview-integrity bdf58dc \
  -m "Pre-squash chain for PR #13 (squashed as 0086cff); cited as T4 evidence by docs/retros/2026-08-15-retro-interview-integrity-retro.md"
git push origin evidence/retro-interview-integrity
git branch -D worktree-feat+retro-interview-integrity
git rev-list --all --tags | grep -c "$(git rev-parse db994ed)"   # 1 = still reachable from a ref
```
