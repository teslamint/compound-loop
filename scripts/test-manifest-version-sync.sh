#!/usr/bin/env bash
# Red fixture harness for plugin-manifest version synchronization. Each case
# copies the current worktree into a disposable directory, removes its Git
# metadata, mutates only the copy, and runs scripts/validate.sh there.
#
# This harness is intentionally red until validate.sh gains check 7. It is
# manual-only and must not be wired into validate.sh or CI before that check
# exists.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL_COUNT=0

setup_copy() {
  local dir
  dir="$(mktemp -d "${TMPDIR:-/tmp}/compound-loop-manifest-version.XXXXXX" 2>&1)" || {
    echo "  harness error: mktemp -d failed: $dir" >&2
    return 1
  }
  cp -R "$ROOT/." "$dir/" || {
    echo "  harness error: copying fixture failed" >&2
    rm -rf "$dir"
    return 1
  }
  rm -rf "$dir/.git"
  printf '%s\n' "$dir"
}

assert_contains() {
  local haystack="$1" needle="$2" label="$3"
  if [[ "$haystack" == *"$needle"* ]]; then
    return 0
  fi
  echo "  assertion failed ($label): expected output to contain: $needle"
  return 1
}

assert_not_contains() {
  local haystack="$1" needle="$2" label="$3"
  if [[ "$haystack" != *"$needle"* ]]; then
    return 0
  fi
  echo "  assertion failed ($label): expected output NOT to contain: $needle"
  return 1
}

run_case() {
  local name="$1"
  shift
  echo "Case $name:"
  if "$@"; then
    echo "  pass"
  else
    echo "  FAIL"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
}

# Case A: clean manifests agree. Derive the expected version from the copy so
# the fixture does not pin a particular release version.
case_a() {
  local dir versions claude_version codex_version out code result=0
  dir="$(setup_copy)" || return 1
  versions="$(python3 - "$dir/.claude-plugin/plugin.json" "$dir/.codex-plugin/plugin.json" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as stream:
    claude = json.load(stream)["version"]
with open(sys.argv[2], encoding="utf-8") as stream:
    codex = json.load(stream)["version"]
print(claude)
print(codex)
PY
)" || {
    echo "  harness error: could not read copied manifest versions"
    rm -rf "$dir"
    return 1
  }
  claude_version="${versions%%$'\n'*}"
  codex_version="${versions#*$'\n'}"
  if [[ "$claude_version" != "$codex_version" ]]; then
    echo "  harness error: clean copied manifests do not agree ($claude_version != $codex_version)"
    rm -rf "$dir"
    return 1
  fi

  out="$(cd "$dir" && bash scripts/validate.sh 2>&1)"; code=$?
  [[ $code -eq 0 ]] || { echo "  expected exit 0, got $code"; result=1; }
  assert_contains "$out" "ok:   plugin manifest versions agree: $claude_version" "derived agreement ok-line" || result=1
  rm -rf "$dir"
  return $result
}

# Case B: both manifests remain valid SemVer, but their values disagree.
case_b() {
  local dir original_version out code result=0
  dir="$(setup_copy)" || return 1
  original_version="$(python3 -c 'import json, sys; print(json.load(open(sys.argv[1], encoding="utf-8"))["version"])' "$dir/.claude-plugin/plugin.json")" || {
    echo "  harness error: could not read copied Claude manifest version"
    rm -rf "$dir"
    return 1
  }
  if ! python3 - "$dir/.codex-plugin/plugin.json" <<'PY'
import json
import sys

path = sys.argv[1]
with open(path, encoding="utf-8") as stream:
    manifest = json.load(stream)
manifest["version"] = "9.9.9"
with open(path, "w", encoding="utf-8") as stream:
    json.dump(manifest, stream, indent=2, ensure_ascii=False)
    stream.write("\n")
PY
  then
    echo "  harness error: fixture mutation failed"
    rm -rf "$dir"
    return 1
  fi
  out="$(cd "$dir" && bash scripts/validate.sh 2>&1)"; code=$?
  [[ $code -ne 0 ]] || { echo "  expected nonzero exit, got 0"; result=1; }
  assert_contains "$out" "[manifest-version]" "reported by check 7 specifically" || result=1
  assert_contains "$out" ".claude-plugin/plugin.json" "names Claude manifest" || result=1
  assert_contains "$out" ".codex-plugin/plugin.json" "names Codex manifest" || result=1
  assert_contains "$out" "$original_version" "names original value" || result=1
  assert_contains "$out" "9.9.9" "names mismatched value" || result=1
  rm -rf "$dir"
  return $result
}

# Case C: the Codex manifest is valid JSON but has no version field.
case_c() {
  local dir out code result=0
  dir="$(setup_copy)" || return 1
  if ! python3 - "$dir/.codex-plugin/plugin.json" <<'PY'
import json
import sys

path = sys.argv[1]
with open(path, encoding="utf-8") as stream:
    manifest = json.load(stream)
manifest.pop("version", None)
with open(path, "w", encoding="utf-8") as stream:
    json.dump(manifest, stream, indent=2, ensure_ascii=False)
    stream.write("\n")
PY
  then
    echo "  harness error: fixture mutation failed"
    rm -rf "$dir"
    return 1
  fi
  out="$(cd "$dir" && bash scripts/validate.sh 2>&1)"; code=$?
  [[ $code -ne 0 ]] || { echo "  expected nonzero exit, got 0"; result=1; }
  assert_contains "$out" "[manifest-version]" "reported by check 7 specifically" || result=1
  assert_contains "$out" ".codex-plugin/plugin.json" "names missing-version manifest" || result=1
  rm -rf "$dir"
  return $result
}

# Case D: the Codex manifest version is present but not SemVer 2.0.0.
case_d() {
  local dir out code result=0
  dir="$(setup_copy)" || return 1
  if ! python3 - "$dir/.codex-plugin/plugin.json" <<'PY'
import json
import sys

path = sys.argv[1]
with open(path, encoding="utf-8") as stream:
    manifest = json.load(stream)
manifest["version"] = "v0.1"
with open(path, "w", encoding="utf-8") as stream:
    json.dump(manifest, stream, indent=2, ensure_ascii=False)
    stream.write("\n")
PY
  then
    echo "  harness error: fixture mutation failed"
    rm -rf "$dir"
    return 1
  fi
  out="$(cd "$dir" && bash scripts/validate.sh 2>&1)"; code=$?
  [[ $code -ne 0 ]] || { echo "  expected nonzero exit, got 0"; result=1; }
  assert_contains "$out" "[manifest-version]" "reported by check 7 specifically" || result=1
  assert_contains "$out" ".codex-plugin/plugin.json" "names invalid-version manifest" || result=1
  rm -rf "$dir"
  return $result
}

# Case E: check 1 already detects the missing manifest. The marker assertion
# proves check 7 also handles it, while the traceback assertion protects the
# validator's user-facing failure path.
case_e() {
  local dir out code result=0
  dir="$(setup_copy)" || return 1
  rm -f "$dir/.codex-plugin/plugin.json"
  out="$(cd "$dir" && bash scripts/validate.sh 2>&1)"; code=$?
  [[ $code -ne 0 ]] || { echo "  expected nonzero exit, got 0"; result=1; }
  assert_contains "$out" "[manifest-version]" "check 7 specifically handles a missing manifest" || result=1
  assert_contains "$out" ".codex-plugin/plugin.json" "names missing manifest" || result=1
  assert_not_contains "$out" "Traceback" "no Python traceback" || result=1
  rm -rf "$dir"
  return $result
}

run_case A case_a
run_case B case_b
run_case C case_c
run_case D case_d
run_case E case_e

echo
if [[ $FAIL_COUNT -eq 0 ]]; then
  echo "ALL CASES PASSED"
  exit 0
else
  echo "$FAIL_COUNT case(s) FAILED"
  exit 1
fi
