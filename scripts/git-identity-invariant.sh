# Shared Git identity boundary for validation scripts.
# A non-Git copied fixture returns an empty baseline and is intentionally skipped.

git_identity_baseline() {
  local repo="$1" repo_root worktree_root config status

  repo_root="$(cd "$repo" && pwd -P)" || return 0
  [[ "$(git -C "$repo_root" rev-parse --is-inside-work-tree 2>/dev/null)" == "true" ]] || return 0
  worktree_root="$(git -C "$repo_root" rev-parse --show-toplevel 2>/dev/null)" || return 0
  worktree_root="$(cd "$worktree_root" && pwd -P)" || return 0
  [[ "$worktree_root" == "$repo_root" ]] || return 0

  config="$(git -C "$repo_root" config --local --get-regexp '^user\.(name|email)$' 2>/dev/null)"; status=$?
  [[ $status -eq 0 ]] && printf '%s\n' "$config"
  [[ $status -eq 0 || $status -eq 1 ]] && return 0
  return "$status"
}

git_identity_unchanged() {
  local repo="$1" baseline="$2" observed

  if ! observed="$(git_identity_baseline "$repo")"; then
    printf '%s\n' '[git-identity] could not read local user.name/user.email' >&2
    return 1
  fi

  if [[ "$observed" == "$baseline" ]]; then
    return 0
  fi

  printf '%s\n' '[git-identity] local user.name/user.email changed during validation' >&2
  return 1
}
