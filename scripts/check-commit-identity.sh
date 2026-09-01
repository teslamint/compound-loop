#!/usr/bin/env bash
# Reject fixture identities from a verified commit range.
set -uo pipefail

BASE="${1:?usage: check-commit-identity.sh <base> <head>}"
HEAD="${2:?usage: check-commit-identity.sh <base> <head>}"

if ! git rev-parse --verify --quiet "$BASE^{commit}" >/dev/null || \
   ! git rev-parse --verify --quiet "$HEAD^{commit}" >/dev/null; then
  echo "FAIL: commit identity policy requires two commits" >&2
  exit 2
fi

RANGE_BASE="$(git merge-base "$BASE" "$HEAD")" || {
  echo "FAIL: commit identity policy cannot derive a merge base" >&2
  exit 2
}

is_fixture_name() {
  case "$1" in
    [Ff][Ii][Xx][Tt][Uu][Rr][Ee]) return 0 ;;
    *) return 1 ;;
  esac
}

is_fixture_email() {
  case "$1" in
    [Ff][Ii][Xx][Tt][Uu][Rr][Ee]@[Ee][Xx][Aa][Mm][Pp][Ll][Ee].[Ii][Nn][Vv][Aa][Ll][Ii][Dd]) return 0 ;;
    *) return 1 ;;
  esac
}

FAILED=0
while IFS= read -r -d '' sha &&
      IFS= read -r -d '' author_name &&
      IFS= read -r -d '' author_email &&
      IFS= read -r -d '' committer_name &&
      IFS= read -r -d '' committer_email; do
  if is_fixture_name "$author_name" || is_fixture_email "$author_email"; then
    echo "FAIL: fixture identity in author for commit $sha" >&2
    FAILED=1
  fi
  if is_fixture_name "$committer_name" || is_fixture_email "$committer_email"; then
    echo "FAIL: fixture identity in committer for commit $sha" >&2
    FAILED=1
  fi
done < <(git log --format='%H%x00%an%x00%ae%x00%cn%x00%ce%x00' "$RANGE_BASE..$HEAD")

if [[ $FAILED -ne 0 ]]; then
  exit 1
fi

echo "ok:   commit identities accepted"
