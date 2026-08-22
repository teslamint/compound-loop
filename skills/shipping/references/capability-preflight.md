## Step 0: Capability Preflight

Outward steps (push, PR creation, GraphQL thread ops, CI watch, merge) depend on capabilities that may not hold. Check before committing to a workflow, not mid-flow:

| Capability | Check | Missing |
|---|---|---|
| `gh` present | `gh --version` | no PR/CI/thread ops possible |
| `gh` authed | `gh auth status` | no PR/CI/thread ops possible |
| network reachable | one cheap `git ls-remote` / `gh api` call | no push, no PR ops |
| repo push permission | push dry-run or `gh repo view --json viewerPermission` | no push, no merge |

If any outward capability is missing, do not fail the skill -- terminate in a **preparation-only state**: commits are made locally (Steps 1-3 still run), the PR title/body are composed and written to a file instead of posted, and the remaining manual steps (`git push`, `gh pr create --body-file <path>`, etc.) are listed for the user to run themselves. `enforces: P7, P9`

