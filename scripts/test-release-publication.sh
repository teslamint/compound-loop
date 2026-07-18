#!/usr/bin/env bash
# Disposable fixture harness for gated outward publication.
#
# Manual invocation only. The harness never uses the repository's real git
# configuration or gh executable: every publication target lives below a
# per-case mktemp root and every case removes that root through an EXIT trap.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GROUP="${1:-all}"
PASS_COUNT=0
FAIL_COUNT=0
CASE_ROOT=""
FIXTURE_REPO=""
FIXTURE_REMOTE=""
FIXTURE_HOME=""
FIXTURE_TMPDIR=""
FIXTURE_BIN=""
GH_STUB_STATE=""
GH_STUB_LOG=""
PUBLICATION_PACKET=""
PUBLICATION_NOTES=""
PYTHON_DIR="$(dirname "$(command -v python3)")"

HARNESS_TMP_BASE="$(mktemp -d "${TMPDIR:-/tmp}/release-publication-harness.XXXXXX")"
cleanup_harness() {
  rm -rf "$HARNESS_TMP_BASE"
}
trap cleanup_harness EXIT HUP INT TERM

case "$GROUP" in
  prepare|mutations|integration|all) ;;
  *)
    echo "usage: bash scripts/test-release-publication.sh <prepare|mutations|integration|all>" >&2
    exit 2
    ;;
esac

assert_contains() {
  local haystack="$1" needle="$2" label="$3"
  if [[ "$haystack" != *"$needle"* ]]; then
    echo "ASSERTION=$label: expected output to contain: $needle"
    return 1
  fi
}

assert_eq() {
  local actual="$1" expected="$2" label="$3"
  if [[ "$actual" != "$expected" ]]; then
    echo "ASSERTION=$label: expected '$expected', got '$actual'"
    return 1
  fi
}

assert_inside() {
  python3 - "$CASE_ROOT" "$1" "$2" <<'PY'
import os
import sys

root, candidate, label = sys.argv[1:]
root = os.path.realpath(root)
candidate = os.path.realpath(candidate)
try:
    inside = os.path.commonpath((root, candidate)) == root
except ValueError:
    inside = False
if not inside:
    print(f"ASSERTION=target boundary ({label}): {candidate} escapes {root}")
    raise SystemExit(1)
PY
}

write_gh_stub() {
  cat >"$FIXTURE_BIN/gh" <<'PY'
#!/usr/bin/env python3
import json
import os
import pathlib
import subprocess
import sys

state_path = pathlib.Path(os.environ["GH_STUB_STATE"])
log_path = pathlib.Path(os.environ["GH_STUB_LOG"])
remote = os.environ["GH_STUB_BARE_REMOTE"]
expected_repo = os.environ["GH_STUB_REPO"]
args = sys.argv[1:]

def fail(message):
    print(f"gh fixture rejected: {message}", file=sys.stderr)
    raise SystemExit(2)

def load():
    return json.loads(state_path.read_text(encoding="utf-8"))

def save(state):
    state_path.write_text(json.dumps(state, sort_keys=True) + "\n", encoding="utf-8")

def option(name, required=True):
    prefix = name + "="
    for arg in args:
        if arg.startswith(prefix):
            return arg[len(prefix):]
    if name not in args:
        if required:
            fail(f"missing {name}")
        return None
    index = args.index(name)
    if index + 1 >= len(args):
        fail(f"missing value for {name}")
    return args[index + 1]

def require_repo():
    repo = option("--repo")
    if repo != expected_repo:
        fail("unexpected repository target")

def notes_text():
    notes = pathlib.Path(option("--notes-file"))
    root = pathlib.Path(os.environ["RELEASE_PUBLICATION_FIXTURE_ROOT"]).resolve()
    try:
        notes.resolve().relative_to(root)
    except ValueError:
        fail("notes file escapes fixture root")
    return notes.read_text(encoding="utf-8")

log_path.parent.mkdir(parents=True, exist_ok=True)
with log_path.open("a", encoding="utf-8") as log:
    log.write(json.dumps(args) + "\n")

state = load()

if args == ["--version"]:
    print("gh version 2.96.0 (fixture)")
elif args == ["release", "create", "--help"]:
    print("--repo --verify-tag --title --notes-file --prerelease")
elif args == ["release", "edit", "--help"]:
    print("--repo --verify-tag --title --notes-file --draft --prerelease")
elif args == ["auth", "status", "--hostname", "github.com"]:
    if not state["auth"]:
        raise SystemExit(1)
    print("github.com: fixture authentication active")
elif len(args) >= 2 and args[:2] == ["api", f"repos/{expected_repo}"]:
    if args[2:] not in ([], ["--jq", ".full_name"], ["--jq", ".nameWithOwner"]):
        fail("unrecognized api arguments")
    print(expected_repo if args[2:] else json.dumps({"full_name": expected_repo}))
elif len(args) >= 3 and args[:2] == ["release", "view"]:
    require_repo()
    tag = args[2]
    page = state["page"]
    if page is None or page["tagName"] != tag:
        raise SystemExit(1)
    print(json.dumps(page, sort_keys=True))
elif len(args) >= 3 and args[:2] == ["release", "create"]:
    require_repo()
    tag = args[2]
    if "--verify-tag" not in args or state["page"] is not None:
        fail("create requires an existing tag and absent page")
    subprocess.run(
        ["git", f"--git-dir={remote}", "rev-parse", "--verify", f"refs/tags/{tag}"],
        check=True,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    state["page"] = {
        "body": notes_text(),
        "isDraft": False,
        "isPrerelease": "--prerelease" in args,
        "name": option("--title"),
        "tagName": tag,
    }
    state["mutations"]["create"] += 1
    save(state)
    print("https://example.invalid/fixture/release")
elif len(args) >= 3 and args[:2] == ["release", "edit"]:
    require_repo()
    tag = args[2]
    page = state["page"]
    if page is None or page["tagName"] != tag or "--verify-tag" not in args:
        fail("edit requires the existing canonical page")
    if "--tag" in args or "--target" in args:
        fail("release identity may not be edited")
    page.update({
        "body": notes_text(),
        "isDraft": option("--draft") == "true",
        "isPrerelease": option("--prerelease") == "true",
        "name": option("--title"),
    })
    state["mutations"]["edit"] += 1
    save(state)
    print("https://example.invalid/fixture/release")
else:
    fail("unrecognized command")
PY
  chmod +x "$FIXTURE_BIN/gh"
}

setup_fixture() {
  CASE_ROOT="$(mktemp -d "$HARNESS_TMP_BASE/publication fixture ;[] XXXXXX")"
  FIXTURE_REPO="$CASE_ROOT/work repo ;[fixture]"
  FIXTURE_REMOTE="$CASE_ROOT/remote repo ;[fixture].git"
  FIXTURE_HOME="$CASE_ROOT/home ;[fixture]"
  FIXTURE_TMPDIR="$CASE_ROOT/tmp ;[fixture]"
  FIXTURE_BIN="$CASE_ROOT/bin ;[fixture]"
  GH_STUB_STATE="$CASE_ROOT/state ;[fixture]/gh-state.json"
  GH_STUB_LOG="$CASE_ROOT/state ;[fixture]/gh-calls.jsonl"
  PUBLICATION_PACKET="$FIXTURE_REPO/.release/publication-v9.8.7.md"
  PUBLICATION_NOTES="$FIXTURE_REPO/.release/publication-v9.8.7-notes.md"

  mkdir -p "$FIXTURE_REPO" "$FIXTURE_HOME" "$FIXTURE_TMPDIR" \
    "$FIXTURE_BIN" "$(dirname "$GH_STUB_STATE")" "$FIXTURE_REPO/.release"

  git init --bare --initial-branch=main "$FIXTURE_REMOTE" >/dev/null
  git -C "$FIXTURE_REPO" init --initial-branch=main >/dev/null
  git -C "$FIXTURE_REPO" config user.name "Publication Fixture"
  git -C "$FIXTURE_REPO" config user.email "fixture@example.invalid"

  mkdir -p "$FIXTURE_REPO/.claude-plugin" "$FIXTURE_REPO/.codex-plugin"
  printf '{"version":"9.8.6"}\n' >"$FIXTURE_REPO/.claude-plugin/plugin.json"
  printf '{"version":"9.8.6"}\n' >"$FIXTURE_REPO/.codex-plugin/plugin.json"
  printf '# Fixture repository\n' >"$FIXTURE_REPO/README.md"
  printf '# Changelog\n\n## [9.8.6] - 2026-07-17\n\n- Previous fixture release.\n' >"$FIXTURE_REPO/CHANGELOG.md"
  git -C "$FIXTURE_REPO" add .
  git -C "$FIXTURE_REPO" commit -m "fixture: base" >/dev/null
  git -C "$FIXTURE_REPO" remote add origin "file://$FIXTURE_REMOTE"
  git -C "$FIXTURE_REPO" push origin main >/dev/null 2>&1

  printf '{"version":"9.8.7"}\n' >"$FIXTURE_REPO/.claude-plugin/plugin.json"
  printf '{"version":"9.8.7"}\n' >"$FIXTURE_REPO/.codex-plugin/plugin.json"
  python3 - "$FIXTURE_REPO/CHANGELOG.md" <<'PY'
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
old = path.read_text(encoding="utf-8")
path.write_text(
    "# Changelog\n\n## [9.8.7] - 2026-07-18\n\n"
    "- Fixture note with spaces.\n"
    "- Fixture note with shell text: $(not-run); [still-data].\n\n"
    + old.split("# Changelog\n\n", 1)[1],
    encoding="utf-8",
)
PY
  git -C "$FIXTURE_REPO" add .
  git -C "$FIXTURE_REPO" commit -m "fixture: release 9.8.7" >/dev/null
  git -C "$FIXTURE_REPO" tag -a v9.8.7 -m "fixture release 9.8.7"
  printf '%s' '- Fixture note with spaces.
- Fixture note with shell text: $(not-run); [still-data].
' >"$PUBLICATION_NOTES"

  cat >"$GH_STUB_STATE" <<'JSON'
{"auth":true,"mutations":{"create":0,"edit":0},"page":null,"repository":"fixture-owner/fixture-repo"}
JSON
  : >"$GH_STUB_LOG"
  write_gh_stub

  cat >"$CASE_ROOT/target-inventory.txt" <<EOF
fixture_root=$CASE_ROOT
repository=$FIXTURE_REPO
fetch_remote=file://$FIXTURE_REMOTE
push_remote=file://$FIXTURE_REMOTE
gh=$FIXTURE_BIN/gh
home=$FIXTURE_HOME
tmpdir=$FIXTURE_TMPDIR
stub_state=$GH_STUB_STATE
stub_log=$GH_STUB_LOG
packet=$PUBLICATION_PACKET
notes=$PUBLICATION_NOTES
EOF
}

assert_fixture_boundary() {
  local resolved_gh remote_url real_origin=""
  resolved_gh="$(PATH="$FIXTURE_BIN:$PYTHON_DIR:/usr/bin:/bin" command -v gh)"
  remote_url="$(git -C "$FIXTURE_REPO" remote get-url origin)"

  assert_inside "$FIXTURE_REPO" repository
  assert_inside "$FIXTURE_REMOTE" remote
  assert_inside "$resolved_gh" gh
  assert_inside "$FIXTURE_HOME" HOME
  assert_inside "$FIXTURE_TMPDIR" TMPDIR
  assert_inside "$GH_STUB_STATE" stub-state
  assert_inside "$GH_STUB_LOG" stub-log
  assert_inside "$PUBLICATION_PACKET" packet
  assert_inside "$PUBLICATION_NOTES" notes
  assert_contains "$remote_url" "file://$CASE_ROOT/" fixture-remote

  real_origin="$(git -C "$ROOT" remote get-url origin 2>/dev/null || true)"
  if [[ -n "$real_origin" ]] && grep -R -F -- "$real_origin" "$CASE_ROOT" >/dev/null; then
    echo "ASSERTION=real origin URL found inside disposable fixture"
    return 1
  fi
  if grep -R -E 'ghp_[[:alnum:]]+|github_pat_[[:alnum:]_]+|GITHUB_TOKEN=|GH_TOKEN=' "$CASE_ROOT" >/dev/null; then
    echo "ASSERTION=credential marker found inside disposable fixture"
    return 1
  fi
}

case_fixture_foundation() {
  local base_commit release_commit tag_object tag_target remote_main state
  assert_fixture_boundary
  base_commit="$(git -C "$FIXTURE_REPO" rev-parse HEAD^)"
  release_commit="$(git -C "$FIXTURE_REPO" rev-parse HEAD)"
  tag_object="$(git -C "$FIXTURE_REPO" rev-parse refs/tags/v9.8.7)"
  tag_target="$(git -C "$FIXTURE_REPO" rev-parse 'refs/tags/v9.8.7^{}')"
  remote_main="$(git --git-dir="$FIXTURE_REMOTE" rev-parse refs/heads/main)"
  state="$(cat "$GH_STUB_STATE")"

  assert_eq "$remote_main" "$base_commit" remote-main-at-parent
  assert_eq "$tag_target" "$release_commit" annotated-tag-target
  [[ "$tag_object" != "$tag_target" ]] || { echo "ASSERTION=tag must be annotated"; return 1; }
  if git --git-dir="$FIXTURE_REMOTE" show-ref --verify --quiet refs/tags/v9.8.7; then
    echo "ASSERTION=bare remote unexpectedly contains release tag"
    return 1
  fi
  assert_contains "$state" '"page":null' no-release-page
}

case_gh_stub_contract() {
  local stub_env state rejected code
  stub_env=(
    env -u GH_TOKEN -u GITHUB_TOKEN
    HOME="$FIXTURE_HOME"
    TMPDIR="$FIXTURE_TMPDIR"
    PATH="$FIXTURE_BIN:$PYTHON_DIR:/usr/bin:/bin"
    GH_STUB_STATE="$GH_STUB_STATE"
    GH_STUB_LOG="$GH_STUB_LOG"
    GH_STUB_BARE_REMOTE="$FIXTURE_REMOTE"
    GH_STUB_REPO="fixture-owner/fixture-repo"
    RELEASE_PUBLICATION_FIXTURE_ROOT="$CASE_ROOT"
  )
  assert_fixture_boundary
  "${stub_env[@]}" "$FIXTURE_BIN/gh" --version >/dev/null
  "${stub_env[@]}" "$FIXTURE_BIN/gh" auth status --hostname github.com >/dev/null
  assert_eq "$("${stub_env[@]}" "$FIXTURE_BIN/gh" api repos/fixture-owner/fixture-repo --jq .full_name)" \
    fixture-owner/fixture-repo repository-read
  if "${stub_env[@]}" "$FIXTURE_BIN/gh" release view v9.8.7 \
    --repo fixture-owner/fixture-repo --json tagName,name,isDraft,isPrerelease,body >/dev/null 2>&1; then
    echo "ASSERTION=stub unexpectedly reported an existing release page"
    return 1
  fi

  git -C "$FIXTURE_REPO" push origin refs/tags/v9.8.7:refs/tags/v9.8.7 >/dev/null 2>&1
  "${stub_env[@]}" "$FIXTURE_BIN/gh" release create v9.8.7 \
    --repo fixture-owner/fixture-repo --verify-tag \
    --title "fixture-repo v9.8.7" --notes-file "$PUBLICATION_NOTES" >/dev/null
  "${stub_env[@]}" "$FIXTURE_BIN/gh" release edit v9.8.7 \
    --repo fixture-owner/fixture-repo --verify-tag \
    --title "fixture-repo v9.8.7" --notes-file "$PUBLICATION_NOTES" \
    --draft=false --prerelease=false >/dev/null

  state="$(cat "$GH_STUB_STATE")"
  assert_contains "$state" '"create": 1' create-count
  assert_contains "$state" '"edit": 1' edit-count
  assert_contains "$state" '"tagName": "v9.8.7"' canonical-page-tag

  set +e
  rejected="$("${stub_env[@]}" "$FIXTURE_BIN/gh" release view v9.8.7 \
    --repo real-owner/real-repo --json tagName 2>&1)"
  code=$?
  set -e
  [[ $code -ne 0 ]] || { echo "ASSERTION=stub accepted an unexpected repository target"; return 1; }
  ((${#rejected} <= 4096)) || { echo "ASSERTION=stub rejection output exceeded 4096 bytes"; return 1; }
  assert_contains "$rejected" "unexpected repository target" rejected-target
}

case_quoted_paths_and_notes() {
  local last_byte
  assert_fixture_boundary
  assert_contains "$CASE_ROOT" "publication fixture ;[]" metacharacter-path
  last_byte="$(tail -c 1 "$PUBLICATION_NOTES" | od -An -t u1 | tr -d ' ')"
  assert_eq "$last_byte" 10 notes-trailing-newline
  grep -F -q '$(not-run); [still-data].' "$PUBLICATION_NOTES" || {
    echo "ASSERTION=notes shell text was not preserved literally"
    return 1
  }
}

case_cleanup_pass() {
  assert_fixture_boundary
}

case_cleanup_failure() {
  assert_fixture_boundary
  echo "ASSERTION=intentional cleanup probe"
  return 1
}

case_missing_engine() {
  local engine="$ROOT/scripts/release-publication.sh" out code remote_before remote_after
  assert_fixture_boundary
  if [[ -e "$engine" ]]; then
    echo "ASSERTION=U1 expected publication engine to be absent"
    return 1
  fi
  remote_before="$(git --git-dir="$FIXTURE_REMOTE" show-ref | sort)"
  set +e
  out="$(
    cd "$FIXTURE_REPO" &&
    env -u GH_TOKEN -u GITHUB_TOKEN \
      HOME="$FIXTURE_HOME" TMPDIR="$FIXTURE_TMPDIR" \
      PATH="$FIXTURE_BIN:$PYTHON_DIR:/usr/bin:/bin" \
      GH_STUB_STATE="$GH_STUB_STATE" GH_STUB_LOG="$GH_STUB_LOG" \
      GH_STUB_BARE_REMOTE="$FIXTURE_REMOTE" GH_STUB_REPO="fixture-owner/fixture-repo" \
      RELEASE_PUBLICATION_FIXTURE_ROOT="$CASE_ROOT" \
      bash "$engine" prepare --version 9.8.7 --headless 2>&1
  )"
  code=$?
  set -e
  remote_after="$(git --git-dir="$FIXTURE_REMOTE" show-ref | sort)"

  [[ $code -ne 0 ]] || { echo "ASSERTION=missing publication engine unexpectedly exited zero"; return 1; }
  ((${#out} <= 4096)) || { echo "ASSERTION=missing engine output exceeded 4096 bytes"; return 1; }
  assert_contains "$out" "$engine" missing-engine-path
  assert_eq "$remote_after" "$remote_before" remote-unchanged
  [[ ! -s "$GH_STUB_LOG" ]] || { echo "ASSERTION=missing engine contacted gh stub"; return 1; }
  echo "ASSERTION=missing publication engine"
  return 1
}

run_fixture_case() {
  local name="$1" mechanism="$2" callback="$3" expected="$4"
  local marker="$HARNESS_TMP_BASE/$name.root" fixture_path code
  echo "CASE=$name"
  echo "MECHANISM=$mechanism"
  set +e
  (
    set -e
    setup_fixture
    printf '%s\n' "$CASE_ROOT" >"$marker"
    local fixture_to_remove="$CASE_ROOT"
    trap 'rm -rf "$fixture_to_remove"' EXIT HUP INT TERM
    "$callback"
  )
  code=$?
  set -e
  fixture_path="$(cat "$marker")"
  if [[ -e "$fixture_path" ]]; then
    echo "ASSERTION=cleanup left fixture root: $fixture_path"
    code=99
  fi

  if [[ "$expected" == pass && $code -eq 0 ]]; then
    echo "RESULT=PASS"
    PASS_COUNT=$((PASS_COUNT + 1))
  elif [[ "$expected" == probe-failure && $code -ne 0 && $code -ne 99 ]]; then
    echo "RESULT=PASS (expected assertion failure; cleanup verified)"
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    echo "RESULT=FAIL"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
}

run_prepare_group() {
  run_fixture_case fixture_foundation local_git_annotated_tag_and_stub case_fixture_foundation pass
  run_fixture_case gh_stub_contract bounded_read_create_edit_and_target_rejection case_gh_stub_contract pass
  run_fixture_case quoted_paths_and_notes literal_metacharacter_paths_and_trailing_newline case_quoted_paths_and_notes pass
  run_fixture_case cleanup_on_pass exit_trap_success_path case_cleanup_pass pass
  run_fixture_case cleanup_on_assertion_failure exit_trap_failure_path case_cleanup_failure probe-failure
  run_fixture_case missing_publication_engine publication_engine_absent case_missing_engine pass
}

run_empty_group() {
  local name="$1"
  echo "GROUP=$name"
  echo "MECHANISM=U1_leaf_prerequisite_no_cases"
  echo "RESULT=PASS"
}

case "$GROUP" in
  prepare) run_prepare_group ;;
  mutations) run_empty_group mutations ;;
  integration) run_empty_group integration ;;
  all)
    run_prepare_group
    run_empty_group mutations
    run_empty_group integration
    ;;
esac

echo "SUMMARY group=$GROUP passed=$PASS_COUNT failed=$FAIL_COUNT"
if (( FAIL_COUNT > 0 )); then
  exit 1
fi
