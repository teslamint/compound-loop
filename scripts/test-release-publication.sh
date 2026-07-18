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

def require_options(positional, value_options=(), flag_options=()):
    index = positional
    seen = set()
    while index < len(args):
        item = args[index]
        if item in flag_options:
            if item in seen:
                fail(f"duplicate option {item}")
            seen.add(item)
            index += 1
        elif item in value_options:
            if item in seen or index + 1 >= len(args) or args[index + 1].startswith("--"):
                fail(f"invalid option {item}")
            seen.add(item)
            index += 2
        elif any(item.startswith(name + "=") for name in value_options):
            name = item.split("=", 1)[0]
            if name in seen or not item.split("=", 1)[1]:
                fail(f"invalid option {name}")
            seen.add(name)
            index += 1
        else:
            fail(f"forbidden or malformed option {item}")
    return seen

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
    if not state.get("repo_read", True):
        raise SystemExit(2)
    print(expected_repo if args[2:] else json.dumps({"full_name": expected_repo}))
elif len(args) >= 3 and args[:2] == ["release", "view"]:
    require_options(3, ("--repo", "--json"))
    require_repo()
    tag = args[2]
    if state.get("page_read_error"):
        raise SystemExit(2)
    page = state["page"]
    if page is None or (page["tagName"] != tag and not state.get("page_lookup_any")):
        raise SystemExit(1)
    print(json.dumps(page, sort_keys=True))
elif len(args) >= 3 and args[:2] == ["release", "create"]:
    options = require_options(3, ("--repo", "--title", "--notes-file"), ("--verify-tag", "--prerelease"))
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
    require_options(3, ("--repo", "--title", "--notes-file", "--draft", "--prerelease"), ("--verify-tag",))
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
  printf '.release/\n' >>"$FIXTURE_REPO/.git/info/exclude"

  mkdir -p "$FIXTURE_REPO/.claude-plugin" "$FIXTURE_REPO/.codex-plugin"
  printf '{"version":"9.8.6"}\n' >"$FIXTURE_REPO/.claude-plugin/plugin.json"
  printf '{"version":"9.8.6"}\n' >"$FIXTURE_REPO/.codex-plugin/plugin.json"
  printf '# Fixture repository\n' >"$FIXTURE_REPO/README.md"
  printf '# Changelog\n\n## [9.8.6] - 2026-07-17\n\n- Previous fixture release.\n' >"$FIXTURE_REPO/CHANGELOG.md"
  git -C "$FIXTURE_REPO" add .
  git -C "$FIXTURE_REPO" commit -m "fixture: base" >/dev/null
  git -C "$FIXTURE_REPO" remote add origin "file://$FIXTURE_REMOTE"
  git -C "$FIXTURE_REPO" push origin main >/dev/null 2>&1
  git -C "$FIXTURE_REPO" remote set-head origin main

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
  printf '%s\n' intentional-cleanup-probe >"$CLEANUP_PROBE_SENTINEL"
  echo "ASSERTION=intentional cleanup probe"
  return 1
}

invoke_prepare() {
  local engine="$ROOT/scripts/release-publication.sh"
  (
    cd "$FIXTURE_REPO" &&
    env -u GH_TOKEN -u GITHUB_TOKEN \
      HOME="$FIXTURE_HOME" TMPDIR="$FIXTURE_TMPDIR" \
      PATH="$FIXTURE_BIN:$PYTHON_DIR:/usr/bin:/bin" \
      GH_STUB_STATE="$GH_STUB_STATE" GH_STUB_LOG="$GH_STUB_LOG" \
      GH_STUB_BARE_REMOTE="$FIXTURE_REMOTE" GH_STUB_REPO="fixture-owner/fixture-repo" \
      RELEASE_PUBLICATION_FIXTURE_ROOT="$CASE_ROOT" \
      bash "$engine" prepare --version "${TEST_VERSION:-9.8.7}" "$@"
  )
}

assert_no_outward_mutation() {
  local state
  state="$(cat "$GH_STUB_STATE")"
  assert_contains "$state" '"create":0' no-page-create
  assert_contains "$state" '"edit":0' no-page-edit
}

case_prepare_fast_forwardable() {
  local out expected_notes_sha packet_sha
  assert_fixture_boundary
  rm -f "$PUBLICATION_PACKET" "$PUBLICATION_NOTES"
  out="$(invoke_prepare --headless)"
  assert_eq "$out" "$(printf '%s\n' \
    'PUBLICATION_STATUS=ready' \
    'PUBLICATION_CLASS=fast-forwardable' \
    'PUBLICATION_PACKET=.release/publication-v9.8.7.md' \
    "PUBLICATION_PACKET_SHA256=$(python3 - "$PUBLICATION_PACKET" <<'PY'
import hashlib, pathlib, sys
print(hashlib.sha256(pathlib.Path(sys.argv[1]).read_bytes()).hexdigest())
PY
)")" exact-ready-output
  cmp -s "$PUBLICATION_NOTES" <(printf '%s' '- Fixture note with spaces.
- Fixture note with shell text: $(not-run); [still-data].
') || { echo "ASSERTION=exact notes bytes differ"; return 1; }
  expected_notes_sha="$(python3 - "$PUBLICATION_NOTES" <<'PY'
import hashlib, pathlib, sys
print(hashlib.sha256(pathlib.Path(sys.argv[1]).read_bytes()).hexdigest())
PY
)"
  grep -F -q "Notes SHA-256: \`$expected_notes_sha\`" "$PUBLICATION_PACKET"
  grep -F -q 'Ordered transitions: `branch -> tag -> page-create`' "$PUBLICATION_PACKET"
  grep -F -q "$(git -C "$FIXTURE_REPO" rev-parse HEAD)" "$PUBLICATION_PACKET"
  assert_eq "$(grep -c '^```bash$' "$PUBLICATION_PACKET")" 1 one-bash-fence
  assert_no_outward_mutation
}

case_headless_prepare_only() {
  local refs_before refs_after state_before state_after out
  refs_before="$(git --git-dir="$FIXTURE_REMOTE" show-ref | sort)"
  state_before="$(cat "$GH_STUB_STATE")"
  rm -f "$PUBLICATION_PACKET" "$PUBLICATION_NOTES"
  out="$(invoke_prepare --headless)"
  refs_after="$(git --git-dir="$FIXTURE_REMOTE" show-ref | sort)"
  state_after="$(cat "$GH_STUB_STATE")"
  assert_contains "$out" 'PUBLICATION_STATUS=ready' headless-ready
  assert_eq "$refs_after" "$refs_before" headless-refs-unchanged
  assert_eq "$state_after" "$state_before" headless-page-unchanged
  [[ -s "$PUBLICATION_PACKET" && -s "$PUBLICATION_NOTES" ]]
}

set_page() {
  local body_file="$1" title="$2" draft="$3" prerelease="$4"
  python3 - "$GH_STUB_STATE" "$body_file" "$title" "$draft" "$prerelease" <<'PY'
import json, pathlib, sys
state_path, body_path, title, draft, prerelease = sys.argv[1:]
path = pathlib.Path(state_path)
state = json.loads(path.read_text())
state["page"] = {"tagName":"v9.8.7", "name":title,
                 "body":pathlib.Path(body_path).read_text(),
                 "isDraft":draft == "true", "isPrerelease":prerelease == "true",
                 "targetCommitish":"informational-only"}
path.write_text(json.dumps(state, sort_keys=True) + "\n")
PY
}

case_branch_ready_tag_missing() {
  git -C "$FIXTURE_REPO" push origin HEAD:refs/heads/main >/dev/null 2>&1
  rm -f "$PUBLICATION_PACKET" "$PUBLICATION_NOTES"
  assert_contains "$(invoke_prepare --headless)" 'PUBLICATION_CLASS=branch-ready-tag-missing' branch-ready
  grep -F -q 'Ordered transitions: `tag -> page-create`' "$PUBLICATION_PACKET"
  assert_no_outward_mutation
}

case_refs_ready_page_missing() {
  git -C "$FIXTURE_REPO" push origin HEAD:refs/heads/main refs/tags/v9.8.7:refs/tags/v9.8.7 >/dev/null 2>&1
  rm -f "$PUBLICATION_PACKET" "$PUBLICATION_NOTES"
  assert_contains "$(invoke_prepare --headless)" 'PUBLICATION_CLASS=refs-ready-page-missing' refs-ready
  grep -F -q 'Ordered transitions: `page-create`' "$PUBLICATION_PACKET"
}

case_fully_matching_noop() {
  git -C "$FIXTURE_REPO" push origin HEAD:refs/heads/main refs/tags/v9.8.7:refs/tags/v9.8.7 >/dev/null 2>&1
  set_page "$PUBLICATION_NOTES" 'fixture-repo v9.8.7' false false
  rm -f "$PUBLICATION_PACKET" "$PUBLICATION_NOTES"
  assert_eq "$(invoke_prepare --headless)" "$(printf '%s\n' 'PUBLICATION_STATUS=noop' 'PUBLICATION_CLASS=fully-matching')" noop-output
  [[ ! -e "$PUBLICATION_PACKET" ]] || { echo 'ASSERTION=noop created packet'; return 1; }
}

case_repairable_page() {
  git -C "$FIXTURE_REPO" push origin HEAD:refs/heads/main refs/tags/v9.8.7:refs/tags/v9.8.7 >/dev/null 2>&1
  set_page "$PUBLICATION_NOTES" 'wrong title' true false
  rm -f "$PUBLICATION_PACKET" "$PUBLICATION_NOTES"
  assert_contains "$(invoke_prepare --repair --headless)" 'PUBLICATION_CLASS=repairable-page' repairable-page
  grep -F -q 'Ordered transitions: `page-edit`' "$PUBLICATION_PACKET"
  ! grep -Eq -- 'gh release edit.*(--tag|--target|--latest|--delete)' "$PUBLICATION_PACKET"
}

case_unordered_page() {
  git -C "$FIXTURE_REPO" push origin HEAD:refs/heads/main >/dev/null 2>&1
  set_page "$PUBLICATION_NOTES" 'fixture-repo v9.8.7' false false
  rm -f "$PUBLICATION_PACKET" "$PUBLICATION_NOTES"
  local out code
  set +e; out="$(invoke_prepare --headless 2>&1)"; code=$?; set -e
  [[ $code -ne 0 ]]; assert_contains "$out" 'exists before the matching remote tag' unordered-normal-fails
  out="$(invoke_prepare --repair --headless)"
  assert_contains "$out" 'PUBLICATION_CLASS=repairable-unordered-page' unordered-repair
  grep -F -q 'Ordered transitions: `tag`' "$PUBLICATION_PACKET"
}

case_different_tag_object_conflict() {
  git -C "$FIXTURE_REPO" tag -a v-other-object -m 'different annotation' HEAD
  git -C "$FIXTURE_REPO" push origin HEAD:refs/heads/main refs/tags/v-other-object:refs/tags/v9.8.7 >/dev/null 2>&1
  local out code
  set +e; out="$(invoke_prepare --headless 2>&1)"; code=$?; set -e
  [[ $code -ne 0 ]]; assert_contains "$out" 'annotated tag identity conflicts' different-tag-object
}

case_protected_version() {
  git -C "$FIXTURE_REPO" tag -d v9.8.7 >/dev/null
  git -C "$FIXTURE_REPO" tag -a v0.2.0 -m protected
  sed -i.bak 's/9\.8\.7/0.2.0/g' "$FIXTURE_REPO/.claude-plugin/plugin.json" "$FIXTURE_REPO/.codex-plugin/plugin.json" "$FIXTURE_REPO/CHANGELOG.md"
  find "$FIXTURE_REPO" -name '*.bak' -delete
  git -C "$FIXTURE_REPO" add . && git -C "$FIXTURE_REPO" commit --amend --no-edit >/dev/null
  git -C "$FIXTURE_REPO" tag -f -a v0.2.0 -m protected >/dev/null
  TEST_VERSION=0.2.0
  export TEST_VERSION
  local out
  out="$(invoke_prepare --headless)"
  assert_contains "$out" 'PUBLICATION_REASON=protected-version-requires-repair' protected-repair-direction
  unset TEST_VERSION
}

case_prerelease_packet() {
  git -C "$FIXTURE_REPO" tag -d v9.8.7 >/dev/null
  sed -i.bak 's/9\.8\.7/9.8.7-rc.1/g' "$FIXTURE_REPO/.claude-plugin/plugin.json" "$FIXTURE_REPO/.codex-plugin/plugin.json" "$FIXTURE_REPO/CHANGELOG.md"
  find "$FIXTURE_REPO" -name '*.bak' -delete
  git -C "$FIXTURE_REPO" add . && git -C "$FIXTURE_REPO" commit --amend --no-edit >/dev/null
  git -C "$FIXTURE_REPO" tag -a v9.8.7-rc.1 -m prerelease
  TEST_VERSION=9.8.7-rc.1; export TEST_VERSION
  PUBLICATION_PACKET="$FIXTURE_REPO/.release/publication-v9.8.7-rc.1.md"
  PUBLICATION_NOTES="$FIXTURE_REPO/.release/publication-v9.8.7-rc.1-notes.md"
  local out; out="$(invoke_prepare --headless)"
  assert_contains "$out" 'PUBLICATION_CLASS=fast-forwardable' prerelease-class
  grep -F -q 'Canonical prerelease: `true`' "$PUBLICATION_PACKET"
  grep -F -q -- '--prerelease' "$PUBLICATION_PACKET"
  unset TEST_VERSION
}

case_remote_later_repair() {
  printf '{"version":"10.0.0"}\n' >"$FIXTURE_REPO/.claude-plugin/plugin.json"
  printf '{"version":"10.0.0"}\n' >"$FIXTURE_REPO/.codex-plugin/plugin.json"
  python3 - "$FIXTURE_REPO/CHANGELOG.md" <<'PY'
import pathlib, sys
p=pathlib.Path(sys.argv[1]); p.write_text("# Changelog\n\n## [10.0.0] - 2026-07-19\n\n- Later worktree notes.\n\n" + p.read_text().split("# Changelog\n\n", 1)[1])
PY
  git -C "$FIXTURE_REPO" add .; git -C "$FIXTURE_REPO" commit -m later >/dev/null
  git -C "$FIXTURE_REPO" push origin HEAD:refs/heads/main >/dev/null 2>&1
  local out code
  set +e; out="$(invoke_prepare --headless 2>&1)"; code=$?; set -e
  [[ $code -ne 0 ]]; assert_contains "$out" 'HEAD must equal' later-normal-fails
  out="$(invoke_prepare --repair --headless)"
  assert_contains "$out" 'PUBLICATION_CLASS=branch-ready-tag-missing' later-repair
  cmp -s "$PUBLICATION_NOTES" <(printf '%s' '- Fixture note with spaces.
- Fixture note with shell text: $(not-run); [still-data].
') || { echo 'ASSERTION=repair did not read notes from tagged release commit'; return 1; }
  grep -F -q 'Later worktree notes' "$FIXTURE_REPO/CHANGELOG.md"
  ! grep -F -q 'Later worktree notes' "$PUBLICATION_NOTES"
  ! grep -F -q 'git push origin '"$(git -C "$FIXTURE_REPO" rev-parse 'v9.8.7^{}')"':refs/heads/main' "$PUBLICATION_PACKET"
}

case_prepare_argument_errors() {
  local out code engine="$ROOT/scripts/release-publication.sh"
  set +e; out="$(cd "$FIXTURE_REPO" && bash "$engine" prepare --version nope 2>&1)"; code=$?; set -e
  [[ $code -eq 2 ]]; assert_contains "$out" 'not valid SemVer' invalid-semver
  set +e; out="$(cd "$FIXTURE_REPO" && bash "$engine" prepare --version 9.8.7 --wat 2>&1)"; code=$?; set -e
  [[ $code -eq 2 ]]; assert_contains "$out" 'unknown argument' unknown-argument
}

case_dirty_tree_failure() {
  printf dirty >>"$FIXTURE_REPO/README.md"
  local out code; set +e; out="$(invoke_prepare --headless 2>&1)"; code=$?; set -e
  [[ $code -ne 0 ]]; assert_contains "$out" 'worktree must be clean' dirty-tree
  [[ ! -e "$PUBLICATION_PACKET" ]]
}

case_non_default_branch_failure() {
  git -C "$FIXTURE_REPO" checkout -b other >/dev/null 2>&1
  local out code; set +e; out="$(invoke_prepare --headless 2>&1)"; code=$?; set -e
  [[ $code -ne 0 ]]; assert_contains "$out" 'not the default branch' non-default
}

case_advanced_head_failure() {
  printf advanced >>"$FIXTURE_REPO/README.md"; git -C "$FIXTURE_REPO" add .; git -C "$FIXTURE_REPO" commit -m advanced >/dev/null
  local out code; set +e; out="$(invoke_prepare --headless 2>&1)"; code=$?; set -e
  [[ $code -ne 0 ]]; assert_contains "$out" 'HEAD must equal' advanced-head
}

case_manifest_changelog_failure() {
  printf '{"version":"1.0.0"}\n' >"$FIXTURE_REPO/.codex-plugin/plugin.json"
  git -C "$FIXTURE_REPO" add . && git -C "$FIXTURE_REPO" commit --amend --no-edit >/dev/null
  git -C "$FIXTURE_REPO" tag -f -a v9.8.7 -m fixture >/dev/null
  local out code; set +e; out="$(invoke_prepare --headless 2>&1)"; code=$?; set -e
  [[ $code -ne 0 ]]; assert_contains "$out" 'manifests do not match' manifest-mismatch
}

case_changelog_mismatch_failure() {
  python3 - "$FIXTURE_REPO/CHANGELOG.md" <<'PY'
import pathlib, sys
p=pathlib.Path(sys.argv[1]); p.write_text(p.read_text().replace("## [9.8.7]", "## [9.8.8]", 1))
PY
  git -C "$FIXTURE_REPO" add . && git -C "$FIXTURE_REPO" commit --amend --no-edit >/dev/null
  git -C "$FIXTURE_REPO" tag -f -a v9.8.7 -m fixture >/dev/null
  local out code; set +e; out="$(invoke_prepare --headless 2>&1)"; code=$?; set -e
  [[ $code -ne 0 ]]; assert_contains "$out" 'newest CHANGELOG section does not match' changelog-mismatch
}

case_inactive_auth_failure() {
  python3 - "$GH_STUB_STATE" <<'PY'
import json, pathlib, sys
p=pathlib.Path(sys.argv[1]); s=json.loads(p.read_text()); s["auth"]=False; p.write_text(json.dumps(s)+"\n")
PY
  local out code; set +e; out="$(invoke_prepare --headless 2>&1)"; code=$?; set -e
  [[ $code -ne 0 ]]; assert_contains "$out" 'authentication is inactive' inactive-auth
}

case_missing_gh_failure() {
  rm -f "$FIXTURE_BIN/gh"
  local out code; set +e; out="$(invoke_prepare --headless 2>&1)"; code=$?; set -e
  [[ $code -ne 0 ]]; assert_contains "$out" 'fixture target escapes root: gh' missing-gh
}

case_unreadable_repository_failure() {
  python3 - "$GH_STUB_STATE" <<'PY'
import json, pathlib, sys
p=pathlib.Path(sys.argv[1]); s=json.loads(p.read_text()); s["repo_read"]=False; p.write_text(json.dumps(s)+"\n")
PY
  local out code; set +e; out="$(invoke_prepare --headless 2>&1)"; code=$?; set -e
  [[ $code -ne 0 ]]; assert_contains "$out" 'repository state is unreadable' unreadable-repository
}

case_unreadable_page_failure() {
  python3 - "$GH_STUB_STATE" <<'PY'
import json, pathlib, sys
p=pathlib.Path(sys.argv[1]); s=json.loads(p.read_text()); s["page_read_error"]=True; p.write_text(json.dumps(s)+"\n")
PY
  local out code; set +e; out="$(invoke_prepare --headless 2>&1)"; code=$?; set -e
  [[ $code -ne 0 ]]; assert_contains "$out" 'release page state is unreadable' unreadable-page
}

case_conflicting_page_identity_failure() {
  set_page "$PUBLICATION_NOTES" 'fixture-repo v9.8.7' false false
  python3 - "$GH_STUB_STATE" <<'PY'
import json, pathlib, sys
p=pathlib.Path(sys.argv[1]); s=json.loads(p.read_text()); s["page"]["tagName"]="v-other"; s["page_lookup_any"]=True; p.write_text(json.dumps(s)+"\n")
PY
  local out code; set +e; out="$(invoke_prepare --headless 2>&1)"; code=$?; set -e
  [[ $code -ne 0 ]]; assert_contains "$out" 'PUBLICATION_CLASS=conflicting' page-conflict-class
  assert_contains "$out" 'page identity conflicts' page-conflict-message
}

case_unreadable_remote_failure() {
  mv "$FIXTURE_REMOTE" "$FIXTURE_REMOTE.offline"
  local out code; set +e; out="$(invoke_prepare --headless 2>&1)"; code=$?; set -e
  [[ $code -ne 0 ]]; assert_contains "$out" 'remote refs are unreadable' unreadable-remote
}

case_non_github_production_failure() {
  local out code
  set +e
  out="$(cd "$FIXTURE_REPO" && env -u RELEASE_PUBLICATION_FIXTURE_ROOT -u GH_TOKEN -u GITHUB_TOKEN \
    HOME="$FIXTURE_HOME" TMPDIR="$FIXTURE_TMPDIR" PATH="$FIXTURE_BIN:$PYTHON_DIR:/usr/bin:/bin" \
    bash "$ROOT/scripts/release-publication.sh" prepare --version 9.8.7 --headless 2>&1)"; code=$?
  set -e
  [[ $code -ne 0 ]]; assert_contains "$out" 'fetch and push URLs must both target github.com' non-github-production
}

case_mismatched_pushurl_failure() {
  git -C "$FIXTURE_REPO" remote set-url origin https://github.com/fixture-owner/fixture-repo.git
  git -C "$FIXTURE_REPO" remote set-url --push origin "file://$FIXTURE_REMOTE"
  rm -f "$PUBLICATION_PACKET" "$PUBLICATION_NOTES"
  local out code
  set +e
  out="$(cd "$FIXTURE_REPO" && env -u RELEASE_PUBLICATION_FIXTURE_ROOT -u GH_TOKEN -u GITHUB_TOKEN \
    HOME="$FIXTURE_HOME" TMPDIR="$FIXTURE_TMPDIR" PATH="$FIXTURE_BIN:$PYTHON_DIR:/usr/bin:/bin" \
    bash "$ROOT/scripts/release-publication.sh" prepare --version 9.8.7 --headless 2>&1)"; code=$?
  set -e
  [[ $code -ne 0 ]]; assert_contains "$out" 'fetch and push URLs must both target github.com' mismatched-pushurl
  [[ ! -e "$PUBLICATION_PACKET" && ! -e "$PUBLICATION_NOTES" ]]
  [[ ! -s "$GH_STUB_LOG" ]] || { echo 'ASSERTION=mismatched pushurl contacted gh'; return 1; }
}

case_divergent_branch_failure() {
  local other="$CASE_ROOT/other"; git clone "file://$FIXTURE_REMOTE" "$other" >/dev/null 2>&1
  git -C "$other" config user.name fixture; git -C "$other" config user.email fixture@example.invalid
  printf divergent >"$other/divergent"; git -C "$other" add .; git -C "$other" commit -m divergent >/dev/null; git -C "$other" push origin main >/dev/null 2>&1
  local out code; set +e; out="$(invoke_prepare --headless 2>&1)"; code=$?; set -e
  [[ $code -ne 0 ]]; assert_contains "$out" 'conflicts with the release commit' divergent
}

case_fixture_escape_failure() {
  local out code
  set +e
  out="$(cd "$FIXTURE_REPO" && env HOME=/tmp TMPDIR="$FIXTURE_TMPDIR" PATH="$FIXTURE_BIN:$PYTHON_DIR:/usr/bin:/bin" \
    GH_STUB_STATE="$GH_STUB_STATE" GH_STUB_LOG="$GH_STUB_LOG" GH_STUB_BARE_REMOTE="$FIXTURE_REMOTE" GH_STUB_REPO=fixture-owner/fixture-repo \
    RELEASE_PUBLICATION_FIXTURE_ROOT="$CASE_ROOT" bash "$ROOT/scripts/release-publication.sh" prepare --version 9.8.7 --headless 2>&1)"; code=$?
  set -e
  [[ $code -ne 0 ]]; assert_contains "$out" 'fixture target escapes root: HOME' fixture-escape
}

case_packet_forced_failure() {
  rm -f "$PUBLICATION_PACKET" "$PUBLICATION_NOTES"
  local out code
  set +e; out="$(RELEASE_PUBLICATION_FAIL_AT=packet-before-rename invoke_prepare --headless 2>&1)"; code=$?; set -e
  [[ $code -ne 0 ]]; assert_contains "$out" 'packet-before-rename' intended-injection
  [[ ! -e "$PUBLICATION_PACKET" ]]; [[ -s "$PUBLICATION_NOTES" ]]
  ! find "$FIXTURE_REPO/.release" -name '*.tmp.*' -print -quit | grep -q .
  assert_no_outward_mutation
}

case_packet_rerun() {
  rm -f "$PUBLICATION_PACKET" "$PUBLICATION_NOTES"
  local first_sha second_sha refs_before refs_after state_before state_after
  refs_before="$(git --git-dir="$FIXTURE_REMOTE" show-ref | sort)"; state_before="$(cat "$GH_STUB_STATE")"
  invoke_prepare --headless >/dev/null
  first_sha="$(python3 - "$PUBLICATION_PACKET" <<'PY'
import hashlib, pathlib, sys
print(hashlib.sha256(pathlib.Path(sys.argv[1]).read_bytes()).hexdigest())
PY
)"
  printf stale >>"$PUBLICATION_PACKET"
  invoke_prepare --headless >/dev/null
  second_sha="$(python3 - "$PUBLICATION_PACKET" <<'PY'
import hashlib, pathlib, sys
print(hashlib.sha256(pathlib.Path(sys.argv[1]).read_bytes()).hexdigest())
PY
)"
  assert_eq "$second_sha" "$first_sha" deterministic-fresh-rerun
  ! grep -F -q stale "$PUBLICATION_PACKET"
  refs_after="$(git --git-dir="$FIXTURE_REMOTE" show-ref | sort)"; state_after="$(cat "$GH_STUB_STATE")"
  assert_eq "$refs_after" "$refs_before" rerun-refs-unchanged
  assert_eq "$state_after" "$state_before" rerun-page-unchanged
}

case_packet_compensation() {
  rm -f "$PUBLICATION_PACKET" "$PUBLICATION_NOTES"
  invoke_prepare --headless >/dev/null
  [[ -s "$PUBLICATION_PACKET" ]]
  local out code
  set +e; out="$(RELEASE_PUBLICATION_FAIL_AT=packet-before-rename invoke_prepare --headless 2>&1)"; code=$?; set -e
  [[ $code -ne 0 ]]; assert_contains "$out" packet-before-rename compensation-marker
  [[ ! -e "$PUBLICATION_PACKET" ]] || { echo 'ASSERTION=older executable packet survived notes replacement'; return 1; }
  [[ -s "$PUBLICATION_NOTES" ]]
  ! grep -q '^```bash$' "$PUBLICATION_NOTES"
  ! find "$FIXTURE_REPO/.release" -name '*.tmp.*' -print -quit | grep -q .
}

case_packet_cancellation_abort() {
  rm -f "$PUBLICATION_PACKET" "$PUBLICATION_NOTES"
  local out code refs_before refs_after state_before state_after
  refs_before="$(git --git-dir="$FIXTURE_REMOTE" show-ref | sort)"; state_before="$(cat "$GH_STUB_STATE")"
  set +e; out="$(invoke_prepare --headless --headless 2>&1)"; code=$?; set -e
  [[ $code -eq 2 ]]; [[ ! -e "$PUBLICATION_PACKET" && ! -e "$PUBLICATION_NOTES" ]]
  invoke_prepare --headless >/dev/null
  [[ -s "$PUBLICATION_PACKET" && -s "$PUBLICATION_NOTES" ]]
  refs_after="$(git --git-dir="$FIXTURE_REMOTE" show-ref | sort)"; state_after="$(cat "$GH_STUB_STATE")"
  assert_eq "$refs_after" "$refs_before" cancel-after-write-refs-unchanged
  assert_eq "$state_after" "$state_before" cancel-after-write-page-unchanged
  assert_no_outward_mutation
}

run_fixture_case() {
  local name="$1" mechanism="$2" callback="$3" expected="$4"
  local marker="$HARNESS_TMP_BASE/$name.root" fixture_path code
  CLEANUP_PROBE_SENTINEL="$HARNESS_TMP_BASE/$name.intentional-sentinel"
  export CLEANUP_PROBE_SENTINEL
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
  echo "FIXTURE_ROOT=$fixture_path (removed)"

  if [[ "$expected" == pass && $code -eq 0 ]]; then
    echo "RESULT=PASS"
    PASS_COUNT=$((PASS_COUNT + 1))
  elif [[ "$expected" == probe-failure && $code -ne 0 && $code -ne 99 ]] \
    && [[ "$(cat "$CLEANUP_PROBE_SENTINEL" 2>/dev/null || true)" == intentional-cleanup-probe ]]; then
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
  run_fixture_case fast_forwardable_prepare read_only_branch_tag_page_packet case_prepare_fast_forwardable pass
  run_fixture_case headless_prepare_only before_after_refs_and_page_bytes case_headless_prepare_only pass
  run_fixture_case branch_ready_tag_missing remote_main_equals_release case_branch_ready_tag_missing pass
  run_fixture_case refs_ready_page_missing matching_remote_refs case_refs_ready_page_missing pass
  run_fixture_case fully_matching_noop exact_refs_and_page case_fully_matching_noop pass
  run_fixture_case repairable_page canonical_fields_only case_repairable_page pass
  run_fixture_case unordered_page repair_only_tag_restoration case_unordered_page pass
  run_fixture_case different_tag_object same_commit_distinct_annotation case_different_tag_object_conflict pass
  run_fixture_case protected_version normal_0_2_0_requires_repair case_protected_version pass
  run_fixture_case prerelease_packet semver_prerelease_maps_to_page_flag case_prerelease_packet pass
  run_fixture_case remote_later_repair repair_never_mutates_branch case_remote_later_repair pass
  run_fixture_case invalid_arguments strict_parser case_prepare_argument_errors pass
  run_fixture_case dirty_tree clean_worktree_precondition case_dirty_tree_failure pass
  run_fixture_case non_default_branch default_branch_precondition case_non_default_branch_failure pass
  run_fixture_case advanced_head immediate_publication_precondition case_advanced_head_failure pass
  run_fixture_case manifest_mismatch synchronized_manifest_precondition case_manifest_changelog_failure pass
  run_fixture_case changelog_mismatch newest_section_precondition case_changelog_mismatch_failure pass
  run_fixture_case inactive_auth read_only_capability_precondition case_inactive_auth_failure pass
  run_fixture_case missing_gh executable_capability_precondition case_missing_gh_failure pass
  run_fixture_case unreadable_repository repository_api_capability_precondition case_unreadable_repository_failure pass
  run_fixture_case unreadable_page release_api_capability_precondition case_unreadable_page_failure pass
  run_fixture_case conflicting_page_identity immutable_page_tag_identity case_conflicting_page_identity_failure pass
  run_fixture_case unreadable_remote remote_inspection_precondition case_unreadable_remote_failure pass
  run_fixture_case non_github_production production_target_rejection case_non_github_production_failure pass
  run_fixture_case mismatched_pushurl github_fetch_with_non_github_push_rejected case_mismatched_pushurl_failure pass
  run_fixture_case divergent_branch ancestry_conflict case_divergent_branch_failure pass
  run_fixture_case fixture_escape inventory_boundary_rejection case_fixture_escape_failure pass
  run_fixture_case packet_forced_failure packet_before_atomic_rename case_packet_forced_failure pass
  run_fixture_case packet_rerun fresh_atomic_replacement case_packet_rerun pass
  run_fixture_case packet_compensation invalidate_old_packet_and_remove_temps case_packet_compensation pass
  run_fixture_case packet_cancellation_abort before_write_abort_and_after_write_handoff case_packet_cancellation_abort pass
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
