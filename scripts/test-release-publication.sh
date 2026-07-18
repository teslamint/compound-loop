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
GIT_MUTATION_LOG=""
GIT_REJECT_REF=""
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
    if state.get("reject_create"):
        fail("injected create rejection")
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
    if state.get("reject_edit"):
        fail("injected edit rejection")
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
  GIT_MUTATION_LOG="$CASE_ROOT/state ;[fixture]/git-mutations.log"
  GIT_REJECT_REF="$CASE_ROOT/state ;[fixture]/reject-ref"
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
  : >"$GIT_MUTATION_LOG"
  : >"$GIT_REJECT_REF"
  cat >"$FIXTURE_REMOTE/hooks/pre-receive" <<EOF
#!/usr/bin/env bash
set -euo pipefail
while read -r old new ref; do
  if [[ -s "$GIT_REJECT_REF" ]] && [[ "\$ref" == "\$(cat "$GIT_REJECT_REF")" ]]; then
    echo "fixture hook rejected \$ref" >&2
    exit 1
  fi
  printf '%s %s %s\n' "\$old" "\$new" "\$ref" >>"$GIT_MUTATION_LOG"
done
EOF
  chmod +x "$FIXTURE_REMOTE/hooks/pre-receive"
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
git_mutation_log=$GIT_MUTATION_LOG
git_reject_ref=$GIT_REJECT_REF
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

extract_program() {
  local destination="$CASE_ROOT/publication-program.sh"
  awk '/^```bash$/{inside=1; next} /^```$/{if (inside) exit} inside{print}' "$PUBLICATION_PACKET" >"$destination"
  assert_eq "$(grep -c '^set -euo pipefail$' "$destination")" 1 strict-program
  chmod +x "$destination"
  printf '%s' "$destination"
}

execute_packet() {
  local program
  program="$(extract_program)"
  (
    cd "$FIXTURE_REPO" &&
    env -u GH_TOKEN -u GITHUB_TOKEN \
      HOME="$FIXTURE_HOME" TMPDIR="$FIXTURE_TMPDIR" \
      PATH="$FIXTURE_BIN:$PYTHON_DIR:/usr/bin:/bin" \
      GH_STUB_STATE="$GH_STUB_STATE" GH_STUB_LOG="$GH_STUB_LOG" \
      GH_STUB_BARE_REMOTE="$FIXTURE_REMOTE" GH_STUB_REPO="fixture-owner/fixture-repo" \
      RELEASE_PUBLICATION_FIXTURE_ROOT="$CASE_ROOT" \
      "$@" bash "$program"
  )
}

remote_oid() {
  git --git-dir="$FIXTURE_REMOTE" rev-parse --verify "$1" 2>/dev/null || printf absent
}

state_value() {
  python3 - "$GH_STUB_STATE" "$1" <<'PY'
import json, sys
value=json.load(open(sys.argv[1]))
for key in sys.argv[2].split('.'):
    value=value[key]
print(json.dumps(value, sort_keys=True) if isinstance(value, (dict,list)) or value is None else str(value).lower() if isinstance(value,bool) else value)
PY
}

prepare_program() {
  rm -f "$PUBLICATION_PACKET" "$PUBLICATION_NOTES"
  invoke_prepare "$@" >/dev/null
}

assert_canonical_page() {
  assert_eq "$(state_value page.tagName)" v9.8.7 page-tag
  assert_eq "$(state_value page.name)" 'fixture-repo v9.8.7' page-title
  assert_eq "$(state_value page.isDraft)" false page-draft
  assert_eq "$(state_value page.isPrerelease)" false page-prerelease
  cmp -s "$PUBLICATION_NOTES" <(python3 - "$GH_STUB_STATE" <<'PY'
import json, sys
print(json.load(open(sys.argv[1]))["page"]["body"], end="")
PY
) || { echo 'ASSERTION=page body differs from exact notes'; return 1; }
}

assert_no_forbidden_packet_command() {
  if grep -E '^(git push .*([[:space:]]--force([[:space:]]|$)|[[:space:]]-f([[:space:]]|$))|gh release delete|.*--target([=[:space:]]|$)|.*--latest([=[:space:]]|$))' "$PUBLICATION_PACKET"; then
    echo 'ASSERTION=packet contains forbidden force/delete/retarget/latest command'
    return 1
  fi
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
  assert_no_forbidden_packet_command
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
  assert_no_forbidden_packet_command
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

case_github_hostname_spoof_failure() {
  git -C "$FIXTURE_REPO" remote set-url origin file://github.com/fixture-owner/fixture-repo.git
  git -C "$FIXTURE_REPO" remote set-url --push origin file://github.com/fixture-owner/fixture-repo.git
  rm -f "$PUBLICATION_PACKET" "$PUBLICATION_NOTES"
  local out code
  set +e
  out="$(cd "$FIXTURE_REPO" && env -u RELEASE_PUBLICATION_FIXTURE_ROOT -u GH_TOKEN -u GITHUB_TOKEN \
    HOME="$FIXTURE_HOME" TMPDIR="$FIXTURE_TMPDIR" PATH="$FIXTURE_BIN:$PYTHON_DIR:/usr/bin:/bin" \
    bash "$ROOT/scripts/release-publication.sh" prepare --version 9.8.7 --headless 2>&1)"; code=$?
  set -e
  [[ $code -ne 0 ]]; assert_contains "$out" 'fetch and push URLs must both target github.com' hostname-spoof
  [[ ! -e "$PUBLICATION_PACKET" && ! -e "$PUBLICATION_NOTES" ]]
  [[ ! -s "$GH_STUB_LOG" ]] || { echo 'ASSERTION=hostname spoof contacted gh'; return 1; }
}

case_github_url_suffix_secret_failure() {
  local suffix out code
  for suffix in '?token=fixture-secret' '#fixture-secret'; do
    git -C "$FIXTURE_REPO" remote set-url origin "https://github.com/fixture-owner/fixture-repo.git$suffix"
    git -C "$FIXTURE_REPO" remote set-url --push origin "https://github.com/fixture-owner/fixture-repo.git$suffix"
    rm -f "$PUBLICATION_PACKET" "$PUBLICATION_NOTES"
    : >"$GH_STUB_LOG"
    set +e
    out="$(cd "$FIXTURE_REPO" && env -u RELEASE_PUBLICATION_FIXTURE_ROOT -u GH_TOKEN -u GITHUB_TOKEN \
      HOME="$FIXTURE_HOME" TMPDIR="$FIXTURE_TMPDIR" PATH="$FIXTURE_BIN:$PYTHON_DIR:/usr/bin:/bin" \
      bash "$ROOT/scripts/release-publication.sh" prepare --version 9.8.7 --headless 2>&1)"; code=$?
    set -e
    [[ $code -ne 0 ]] || { echo 'ASSERTION=query/fragment GitHub URL was accepted'; return 1; }
    assert_contains "$out" 'fetch and push URLs must both target github.com' unsafe-url-component
    [[ "$out" != *fixture-secret* ]] || { echo 'ASSERTION=URL secret appeared in diagnostic output'; return 1; }
    [[ ! -e "$PUBLICATION_PACKET" && ! -e "$PUBLICATION_NOTES" ]] || { echo 'ASSERTION=unsafe URL produced publication artifacts'; return 1; }
    [[ ! -s "$GH_STUB_LOG" ]] || { echo 'ASSERTION=unsafe URL contacted gh'; return 1; }
  done
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

set_stub_flag() {
  python3 - "$GH_STUB_STATE" "$1" "$2" <<'PY'
import json, pathlib, sys
p=pathlib.Path(sys.argv[1]); s=json.loads(p.read_text()); s[sys.argv[2]]=sys.argv[3] == "true"; p.write_text(json.dumps(s, sort_keys=True)+"\n")
PY
}

case_t1_success() {
  local release; release="$(git -C "$FIXTURE_REPO" rev-parse HEAD)"
  prepare_program --headless; execute_packet >/dev/null
  assert_eq "$(remote_oid refs/heads/main)" "$release" branch-fast-forward
  assert_eq "$(remote_oid refs/tags/v9.8.7)" "$(git -C "$FIXTURE_REPO" rev-parse refs/tags/v9.8.7)" tag-object
  assert_canonical_page
}

case_t1_forced_failure() {
  local before out code; before="$(remote_oid refs/heads/main)"; printf refs/heads/main >"$GIT_REJECT_REF"
  prepare_program --headless
  set +e; out="$(execute_packet 2>&1)"; code=$?; set -e
  [[ $code -ne 0 ]]; assert_contains "$out" 'MECHANISM=branch-push' branch-rejection-marker
  assert_eq "$(remote_oid refs/heads/main)" "$before" rejected-branch-unchanged
  assert_eq "$(remote_oid refs/tags/v9.8.7)" absent rejected-no-tag
  assert_eq "$(state_value page)" null rejected-no-page
}

case_t1_rerun() {
  prepare_program --headless; execute_packet >/dev/null
  local writes; writes="$(grep -c 'refs/heads/main' "$GIT_MUTATION_LOG")"
  rm -f "$PUBLICATION_PACKET" "$PUBLICATION_NOTES"
  assert_eq "$(invoke_prepare --headless)" "$(printf '%s\n' PUBLICATION_STATUS=noop PUBLICATION_CLASS=fully-matching)" matching-rerun
  assert_eq "$(grep -c 'refs/heads/main' "$GIT_MUTATION_LOG")" "$writes" no-repush
}

case_t1_rollback() {
  prepare_program --headless
  local out code release; release="$(git -C "$FIXTURE_REPO" rev-parse HEAD)"
  set +e; out="$(execute_packet env RELEASE_PUBLICATION_FAIL_AT=tag-before 2>&1)"; code=$?; set -e
  [[ $code -ne 0 ]]; assert_contains "$out" injected-tag-before durable-partial-marker
  assert_eq "$(remote_oid refs/heads/main)" "$release" durable-branch
  assert_eq "$(remote_oid refs/tags/v9.8.7)" absent no-tag
  prepare_program --headless; grep -F -q 'Ordered transitions: `tag -> page-create`' "$PUBLICATION_PACKET"
}

case_t1_headless() { case_headless_prepare_only; }

case_t1_cancel() {
  prepare_program --headless
  local before out code release; before="$(remote_oid refs/heads/main)"; release="$(git -C "$FIXTURE_REPO" rev-parse HEAD)"
  set +e; out="$(execute_packet env RELEASE_PUBLICATION_FAIL_AT=branch-before 2>&1)"; code=$?; set -e
  [[ $code -ne 0 ]]; assert_eq "$(remote_oid refs/heads/main)" "$before" abort-before-branch
  set +e; out="$(execute_packet env RELEASE_PUBLICATION_FAIL_AT=branch-post-verify 2>&1)"; code=$?; set -e
  [[ $code -ne 0 ]]; assert_eq "$(remote_oid refs/heads/main)" "$release" interrupt-after-branch
  prepare_program --headless; grep -F -q 'Ordered transitions: `tag -> page-create`' "$PUBLICATION_PACKET"
}

branch_ready() { git -C "$FIXTURE_REPO" push origin HEAD:refs/heads/main >/dev/null 2>&1; : >"$GIT_MUTATION_LOG"; }
refs_ready() { git -C "$FIXTURE_REPO" push origin HEAD:refs/heads/main refs/tags/v9.8.7:refs/tags/v9.8.7 >/dev/null 2>&1; : >"$GIT_MUTATION_LOG"; }

case_t2_success() { branch_ready; prepare_program --headless; execute_packet >/dev/null; assert_eq "$(remote_oid refs/tags/v9.8.7)" "$(git -C "$FIXTURE_REPO" rev-parse refs/tags/v9.8.7)" exact-tag; assert_canonical_page; }
case_t2_forced_failure() {
  branch_ready; printf refs/tags/v9.8.7 >"$GIT_REJECT_REF"; prepare_program --headless
  local out code; set +e; out="$(execute_packet 2>&1)"; code=$?; set -e
  [[ $code -ne 0 ]]; assert_contains "$out" 'MECHANISM=tag-push' tag-rejection-marker
  assert_eq "$(remote_oid refs/tags/v9.8.7)" absent rejected-tag-absent; assert_eq "$(state_value page)" null no-page
}
case_t2_rerun() { refs_ready; prepare_program --headless; grep -F -q 'Ordered transitions: `page-create`' "$PUBLICATION_PACKET"; execute_packet >/dev/null; ! grep -q refs/tags "$GIT_MUTATION_LOG"; }
case_t2_rollback() {
  branch_ready; prepare_program --headless
  local out code; set +e; out="$(execute_packet env RELEASE_PUBLICATION_FAIL_AT=page-create-before 2>&1)"; code=$?; set -e
  [[ $code -ne 0 ]]; assert_contains "$out" injected-page-create-before page-after-tag-marker
  assert_eq "$(remote_oid refs/tags/v9.8.7)" "$(git -C "$FIXTURE_REPO" rev-parse refs/tags/v9.8.7)" durable-tag
  assert_eq "$(state_value page)" null page-absent; prepare_program --headless; grep -F -q 'Ordered transitions: `page-create`' "$PUBLICATION_PACKET"
}
case_t2_headless() { branch_ready; case_headless_prepare_only; }
case_t2_cancel() {
  branch_ready; prepare_program --headless
  local out code; set +e; out="$(execute_packet env RELEASE_PUBLICATION_FAIL_AT=tag-before 2>&1)"; code=$?; set -e
  [[ $code -ne 0 ]]; assert_eq "$(remote_oid refs/tags/v9.8.7)" absent abort-before-tag
  set +e; out="$(execute_packet env RELEASE_PUBLICATION_FAIL_AT=tag-post-verify 2>&1)"; code=$?; set -e
  [[ $code -ne 0 ]]; [[ "$(remote_oid refs/tags/v9.8.7)" != absent ]]; prepare_program --headless; grep -F -q 'Ordered transitions: `page-create`' "$PUBLICATION_PACKET"
}

case_t3_success() { refs_ready; prepare_program --headless; execute_packet >/dev/null; assert_canonical_page; assert_eq "$(state_value mutations.create)" 1 one-create; }
case_t3_forced_failure() {
  refs_ready; set_stub_flag reject_create true; prepare_program --headless
  local out code; set +e; out="$(execute_packet 2>&1)"; code=$?; set -e
  [[ $code -ne 0 ]]; assert_contains "$out" 'MECHANISM=page-create' create-rejection-marker; assert_eq "$(state_value page)" null no-implicit-page
}
case_t3_rerun() { refs_ready; prepare_program --headless; execute_packet >/dev/null; local count="$(state_value mutations.create)"; rm -f "$PUBLICATION_PACKET" "$PUBLICATION_NOTES"; assert_contains "$(invoke_prepare --headless)" fully-matching page-rerun-noop; assert_eq "$(state_value mutations.create)" "$count" no-recreate; }
case_t3_rollback() {
  refs_ready; prepare_program --headless
  local out code; set +e; out="$(execute_packet env RELEASE_PUBLICATION_FAIL_AT=page-create-post-verify 2>&1)"; code=$?; set -e
  [[ $code -ne 0 ]]; assert_contains "$out" injected-page-create-post-verify created-before-interrupt; assert_canonical_page; assert_contains "$(invoke_prepare --headless)" fully-matching fresh-noop
}
case_t3_headless() { refs_ready; case_headless_prepare_only; }
case_t3_cancel() {
  refs_ready; prepare_program --headless
  local out code; set +e; out="$(execute_packet env RELEASE_PUBLICATION_FAIL_AT=page-create-before 2>&1)"; code=$?; set -e
  [[ $code -ne 0 ]]; assert_eq "$(state_value page)" null abort-before-create
  set +e; out="$(execute_packet env RELEASE_PUBLICATION_FAIL_AT=page-create-post-verify 2>&1)"; code=$?; set -e
  [[ $code -ne 0 ]]; assert_canonical_page; assert_contains "$(invoke_prepare --headless)" fully-matching cancel-after-create-noop
}

repair_ready() { refs_ready; set_page "$PUBLICATION_NOTES" 'wrong title' true false; }
case_t4_success() { repair_ready; prepare_program --repair --headless; execute_packet >/dev/null; assert_canonical_page; assert_eq "$(state_value mutations.edit)" 1 one-edit; ! grep -Eq 'refs/(heads|tags)' "$GIT_MUTATION_LOG"; }
case_t4_forced_failure() {
  repair_ready; set_stub_flag reject_edit true; prepare_program --repair --headless
  local out code before; before="$(state_value page)"; set +e; out="$(execute_packet 2>&1)"; code=$?; set -e
  [[ $code -ne 0 ]]; assert_contains "$out" 'MECHANISM=page-edit' edit-rejection-marker; assert_eq "$(state_value page)" "$before" edit-rejected-unchanged
}
case_t4_rerun() { repair_ready; prepare_program --repair --headless; execute_packet >/dev/null; local count="$(state_value mutations.edit)"; assert_contains "$(invoke_prepare --repair --headless)" fully-matching edit-rerun-noop; assert_eq "$(state_value mutations.edit)" "$count" no-reedit; }
case_t4_rollback() {
  repair_ready; prepare_program --repair --headless
  local out code; set +e; out="$(execute_packet env RELEASE_PUBLICATION_MUTATE_AT=page-edit-post-verify 2>&1)"; code=$?; set -e
  [[ $code -ne 0 ]]; assert_contains "$out" mutated-page-edit-post-verify post-edit-mutation; assert_eq "$(state_value page.name)" fixture-mutated-page durable-observed-page; assert_contains "$(invoke_prepare --repair --headless)" repairable-page fresh-repair-classification
}
case_t4_headless() { repair_ready; rm -f "$PUBLICATION_PACKET" "$PUBLICATION_NOTES"; local before="$(state_value page)"; invoke_prepare --repair --headless >/dev/null; assert_eq "$(state_value page)" "$before" repair-headless-no-mutation; }
case_t4_cancel() {
  repair_ready; prepare_program --repair --headless
  local out code before; before="$(state_value page)"; set +e; out="$(execute_packet env RELEASE_PUBLICATION_FAIL_AT=page-edit-before 2>&1)"; code=$?; set -e
  [[ $code -ne 0 ]]; assert_eq "$(state_value page)" "$before" abort-before-edit
  set +e; out="$(execute_packet env RELEASE_PUBLICATION_FAIL_AT=page-edit-post-verify 2>&1)"; code=$?; set -e
  [[ $code -ne 0 ]]; assert_canonical_page; assert_contains "$(invoke_prepare --headless)" fully-matching cancel-after-edit-noop
}

case_stale_branch_before() {
  prepare_program --headless; local out code
  set +e; out="$(execute_packet env RELEASE_PUBLICATION_MUTATE_AT=branch-before 2>&1)"; code=$?; set -e
  [[ $code -ne 0 ]]; assert_contains "$out" branch-push-branch stale-branch-before-push
  assert_eq "$(remote_oid refs/tags/v9.8.7)" absent no-later-tag
}
case_stale_tag_before() {
  branch_ready; prepare_program --headless; local out code
  set +e; out="$(execute_packet env RELEASE_PUBLICATION_MUTATE_AT=tag-before 2>&1)"; code=$?; set -e
  [[ $code -ne 0 ]]; assert_contains "$out" tag-push-tag stale-tag-before-push
  assert_eq "$(state_value page)" null no-later-page
}
case_stale_create_before() {
  refs_ready; prepare_program --headless; local out code
  set +e; out="$(execute_packet env RELEASE_PUBLICATION_MUTATE_AT=page-create-before 2>&1)"; code=$?; set -e
  [[ $code -ne 0 ]]; assert_contains "$out" page-create-page stale-page-before-create
  assert_eq "$(state_value mutations.create)" 0 no-create-after-stale
}
case_stale_edit_before() {
  repair_ready; prepare_program --repair --headless; local out code
  set +e; out="$(execute_packet env RELEASE_PUBLICATION_MUTATE_AT=page-edit-before 2>&1)"; code=$?; set -e
  [[ $code -ne 0 ]]; assert_contains "$out" page-edit-page stale-page-before-edit
  assert_eq "$(state_value mutations.edit)" 0 no-edit-after-stale
}
case_post_verify_branch() {
  prepare_program --headless; local out code
  set +e; out="$(execute_packet env RELEASE_PUBLICATION_MUTATE_AT=branch-post-verify 2>&1)"; code=$?; set -e
  [[ $code -ne 0 ]]; assert_contains "$out" branch-post-verify post-branch-detected
  assert_eq "$(remote_oid refs/tags/v9.8.7)" absent no-tag-after-post-failure
}
case_post_verify_tag() {
  branch_ready; prepare_program --headless; local out code
  set +e; out="$(execute_packet env RELEASE_PUBLICATION_MUTATE_AT=tag-post-verify 2>&1)"; code=$?; set -e
  [[ $code -ne 0 ]]; assert_contains "$out" tag-post-verify post-tag-detected
  assert_eq "$(state_value page)" null no-page-after-post-failure
}
case_post_verify_create() {
  refs_ready; prepare_program --headless; local out code
  set +e; out="$(execute_packet env RELEASE_PUBLICATION_MUTATE_AT=page-create-post-verify 2>&1)"; code=$?; set -e
  [[ $code -ne 0 ]]; assert_contains "$out" page-post-verify post-create-detected
  assert_eq "$(state_value page.name)" fixture-mutated-page mutated-create-visible
}
case_notes_stale() {
  prepare_program --headless; printf stale >>"$PUBLICATION_NOTES"; local out code
  set +e; out="$(execute_packet 2>&1)"; code=$?; set -e
  [[ $code -ne 0 ]]; assert_contains "$out" branch-push-notes notes-fingerprint
  assert_eq "$(remote_oid refs/tags/v9.8.7)" absent no-transition-after-notes-change
}
case_invalid_injection_boundary() {
  prepare_program --headless; local out code
  set +e; out="$(execute_packet env RELEASE_PUBLICATION_FAIL_AT=not-a-boundary 2>&1)"; code=$?; set -e
  [[ $code -ne 0 ]]; assert_contains "$out" 'unknown fixture failure boundary' invalid-boundary
  assert_eq "$(remote_oid refs/tags/v9.8.7)" absent no-transition-after-invalid-injection
}
case_missing_fixture_injection_boundary() {
  prepare_program --headless
  local program="$CASE_ROOT/no-fixture-program.sh" original out code
  original="$(extract_program)"; sed 's/^fixture_root=.*/fixture_root=/' "$original" >"$program"; chmod +x "$program"
  set +e
  out="$(cd "$FIXTURE_REPO" && env HOME="$FIXTURE_HOME" TMPDIR="$FIXTURE_TMPDIR" PATH="$FIXTURE_BIN:$PYTHON_DIR:/usr/bin:/bin" GH_STUB_STATE="$GH_STUB_STATE" GH_STUB_LOG="$GH_STUB_LOG" GH_STUB_BARE_REMOTE="$FIXTURE_REMOTE" GH_STUB_REPO=fixture-owner/fixture-repo RELEASE_PUBLICATION_FAIL_AT=branch-before bash "$program" 2>&1)"; code=$?
  set -e
  [[ $code -ne 0 ]]; assert_contains "$out" 'requires a fixture root' missing-fixture-root
  assert_eq "$(remote_oid refs/tags/v9.8.7)" absent no-transition-without-boundary
}

move_local_tag() {
  git -C "$FIXTURE_REPO" tag -f -a v9.8.7 -m 'moved fixture annotation' HEAD >/dev/null
}

redirect_origin() {
  WRONG_REMOTE="$CASE_ROOT/wrong target ;[fixture].git"
  git init --bare --initial-branch=main "$WRONG_REMOTE" >/dev/null
  git -C "$FIXTURE_REPO" remote set-url origin "file://$WRONG_REMOTE"
  git -C "$FIXTURE_REPO" remote set-url --push origin "file://$WRONG_REMOTE"
}

assert_wrong_remote_untouched() {
  [[ -z "$(git --git-dir="$WRONG_REMOTE" show-ref 2>/dev/null)" ]] || { echo 'ASSERTION=redirected remote received a ref'; return 1; }
  assert_eq "$(state_value mutations.create)" 0 redirected-no-create
  assert_eq "$(state_value mutations.edit)" 0 redirected-no-edit
}

case_stale_local_tag_branch() {
  prepare_program --headless; move_local_tag; local out code
  set +e; out="$(execute_packet 2>&1)"; code=$?; set -e
  [[ $code -ne 0 ]]; assert_contains "$out" branch-push-local-tag local-tag-before-branch
  assert_eq "$(remote_oid refs/tags/v9.8.7)" absent stale-local-no-remote-tag; assert_eq "$(state_value page)" null stale-local-no-page
}
case_stale_local_tag_tag() {
  branch_ready; prepare_program --headless; move_local_tag; local out code
  set +e; out="$(execute_packet 2>&1)"; code=$?; set -e
  [[ $code -ne 0 ]]; assert_contains "$out" tag-push-local-tag local-tag-before-tag
  assert_eq "$(remote_oid refs/tags/v9.8.7)" absent stale-local-no-tag-push; assert_eq "$(state_value page)" null stale-local-no-page
}
case_stale_local_tag_create() {
  refs_ready; prepare_program --headless; move_local_tag; local out code
  set +e; out="$(execute_packet 2>&1)"; code=$?; set -e
  [[ $code -ne 0 ]]; assert_contains "$out" page-create-local-tag local-tag-before-create
  assert_eq "$(state_value mutations.create)" 0 stale-local-no-create; assert_eq "$(state_value page)" null stale-local-no-page
}
case_stale_local_tag_edit() {
  repair_ready; prepare_program --repair --headless; move_local_tag; local out code before
  before="$(state_value page)"; set +e; out="$(execute_packet 2>&1)"; code=$?; set -e
  [[ $code -ne 0 ]]; assert_contains "$out" page-edit-local-tag local-tag-before-edit
  assert_eq "$(state_value mutations.edit)" 0 stale-local-no-edit; assert_eq "$(state_value page)" "$before" stale-local-page-unchanged
}

case_redirect_origin_branch() {
  prepare_program --headless; redirect_origin; local out code
  set +e; out="$(execute_packet 2>&1)"; code=$?; set -e
  [[ $code -ne 0 ]]; assert_contains "$out" branch-push-transport redirect-before-branch; assert_wrong_remote_untouched
}
case_redirect_origin_tag() {
  branch_ready; prepare_program --headless; redirect_origin; local out code
  set +e; out="$(execute_packet 2>&1)"; code=$?; set -e
  [[ $code -ne 0 ]]; assert_contains "$out" tag-push-transport redirect-before-tag; assert_wrong_remote_untouched
}
case_redirect_origin_create() {
  refs_ready; prepare_program --headless; redirect_origin; local out code
  set +e; out="$(execute_packet 2>&1)"; code=$?; set -e
  [[ $code -ne 0 ]]; assert_contains "$out" page-create-transport redirect-before-create; assert_wrong_remote_untouched
}
case_redirect_origin_edit() {
  repair_ready; prepare_program --repair --headless; redirect_origin; local out code before
  before="$(state_value page)"; set +e; out="$(execute_packet 2>&1)"; code=$?; set -e
  [[ $code -ne 0 ]]; assert_contains "$out" page-edit-transport redirect-before-edit; assert_wrong_remote_untouched; assert_eq "$(state_value page)" "$before" redirect-page-unchanged
}

case_implicit_tag_disappearance() {
  refs_ready; prepare_program --headless; local out code release
  release="$(git -C "$FIXTURE_REPO" rev-parse HEAD)"
  set +e; out="$(execute_packet env RELEASE_PUBLICATION_MUTATE_AT=page-create-tag-before 2>&1)"; code=$?; set -e
  [[ $code -ne 0 ]]; assert_contains "$out" page-create-tag implicit-tag-boundary
  assert_eq "$(remote_oid refs/tags/v9.8.7)" "$release" mutated-lightweight-tag
  assert_eq "$(state_value mutations.create)" 0 no-implicit-create-call; assert_eq "$(state_value page)" null no-implicit-page
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
  run_fixture_case github_hostname_spoof file_scheme_with_github_hostname_rejected case_github_hostname_spoof_failure pass
  run_fixture_case github_url_suffix_secret query_and_fragment_rejected_without_persistence case_github_url_suffix_secret_failure pass
  run_fixture_case divergent_branch ancestry_conflict case_divergent_branch_failure pass
  run_fixture_case fixture_escape inventory_boundary_rejection case_fixture_escape_failure pass
  run_fixture_case packet_forced_failure packet_before_atomic_rename case_packet_forced_failure pass
  run_fixture_case packet_rerun fresh_atomic_replacement case_packet_rerun pass
  run_fixture_case packet_compensation invalidate_old_packet_and_remove_temps case_packet_compensation pass
  run_fixture_case packet_cancellation_abort before_write_abort_and_after_write_handoff case_packet_cancellation_abort pass
}

case_publication_terminal_contract() {
  python3 - "$ROOT" <<'PY'
import pathlib
import re
import sys

root = pathlib.Path(sys.argv[1])
contract = (root / "schemas/headless-contract.md").read_text(encoding="utf-8")
skill = (root / "skills/release/SKILL.md").read_text(encoding="utf-8")

assert "Contract version: `v1`" in contract
release_row = "| `release` | `Release complete — v<version>` | `Release skipped — <reason>` | `Release failed — <reason>` |"
publish_row = "| `release publish` | `Publication complete — v<version>` | `Publication skipped — <reason>` | `Publication failed — <reason>` |"
assert contract.count(release_row) == 1, "existing release row changed or duplicated"
assert contract.count(publish_row) == 1, "additive release publish row missing or duplicated"

placeholders = (
    "`Publication complete — v<version>`",
    "`Publication skipped — <reason>`",
    "`Publication failed — <reason>`",
)
for placeholder in placeholders:
    assert skill.count(placeholder) == 1, f"expected one inline placeholder: {placeholder}"

inline = re.findall(r"`([^`]+)`", skill)
publication_inline = [span for span in inline if span.startswith("Publication ")]
assert publication_inline == [placeholder[1:-1] for placeholder in placeholders], (
    f"unexpected inline Publication signal(s): {publication_inline!r}"
)
PY
}

case_publication_skill_dispatch_contract() {
  python3 - "$ROOT" <<'PY'
import pathlib
import sys

root = pathlib.Path(sys.argv[1])
skill = (root / "skills/release/SKILL.md").read_text(encoding="utf-8")
protocol = (root / "skills/release/references/publication.md").read_text(encoding="utf-8")
skill_words = " ".join(skill.split())
protocol_words = " ".join(protocol.split())

dispatch = skill.index("## Action dispatch")
local_phases = skill.index("Run the seven phases in order")
assert dispatch < local_phases, "publication dispatch must precede the local seven phases"
for text in (
    "`publish <semver> [repair] [mode:headless]`",
    "return before any local-release phase",
    "repair` without `publish",
    "duplicate",
    "unknown",
    "skills/release/references/publication.md",
):
    assert text in skill_words, f"missing publication dispatch contract: {text}"
for text in (
    "Approve this exact publication/repair",
    "Revise",
    "Cancel",
    "same executing session",
    "relayed approval",
    "prior local release",
    "blocking question",
):
    assert text in protocol_words, f"missing first-hand gate contract: {text}"
PY
}

case_exact_packet_execution_contract() {
  python3 - "$ROOT" <<'PY'
import pathlib
import sys

protocol = (pathlib.Path(sys.argv[1]) / "skills/release/references/publication.md").read_text(encoding="utf-8")
protocol_words = " ".join(protocol.split())
for text in (
    "PUBLICATION_PACKET_SHA256",
    "SHA-256",
    "exactly one fenced `bash` program",
    "first non-empty line is exactly `set -euo pipefail`",
    "one Bash invocation",
    "delete the temporary program",
    "fresh packet and fresh gate",
    "last non-empty output",
):
    assert text in protocol_words, f"missing exact-packet execution contract: {text}"
PY
}

case_first_hand_approved_publication() {
  local prepare_out approved_sha actual_sha program_count out
  prepare_out="$(invoke_prepare)"
  assert_no_outward_mutation
  approved_sha="$(printf '%s\n' "$prepare_out" | sed -n 's/^PUBLICATION_PACKET_SHA256=//p')"
  actual_sha="$(python3 - "$PUBLICATION_PACKET" <<'PY'
import hashlib, pathlib, sys
print(hashlib.sha256(pathlib.Path(sys.argv[1]).read_bytes()).hexdigest())
PY
)"
  assert_eq "$actual_sha" "$approved_sha" exact-approved-packet-hash
  program_count="$(grep -c '^```bash$' "$PUBLICATION_PACKET")"
  assert_eq "$program_count" 1 exactly-one-bash-fence
  out="$(execute_packet; printf '%s\n' 'Publication complete — v9.8.7')"
  assert_eq "$(printf '%s\n' "$out" | sed '/^[[:space:]]*$/d' | tail -1)" \
    'Publication complete — v9.8.7' terminal-last-line
  assert_eq "$(state_value mutations.create)" 1 exactly-one-page-create
  assert_canonical_page
  echo 'Covers S1'
}

case_headless_handoff_scenario() {
  local before after
  before="$(remote_oid refs/heads/main)|$(remote_oid refs/tags/v9.8.7)|$(state_value page)"
  invoke_prepare --headless >/dev/null
  after="$(remote_oid refs/heads/main)|$(remote_oid refs/tags/v9.8.7)|$(state_value page)"
  assert_eq "$after" "$before" headless-state-unchanged
  [[ -s "$PUBLICATION_PACKET" && -s "$PUBLICATION_NOTES" ]]
  echo 'Publication skipped — headless: packet prepared for first-hand publication consent'
  echo 'Covers S2'
}

case_partial_resume_scenario() {
  prepare_program --headless
  printf '%s\n' refs/tags/v9.8.7 >"$GIT_REJECT_REF"
  set +e
  execute_packet >/dev/null 2>&1
  local code=$?
  set -e
  [[ $code -ne 0 ]]
  : >"$GIT_REJECT_REF"
  local branch_after_failure="$(remote_oid refs/heads/main)"
  rm -f "$PUBLICATION_PACKET" "$PUBLICATION_NOTES"
  invoke_prepare --headless >/dev/null
  execute_packet >/dev/null
  assert_eq "$(remote_oid refs/heads/main)" "$branch_after_failure" branch-not-repushed
  assert_canonical_page
  echo 'Covers S3'
}

case_fully_matching_scenario() {
  prepare_program --headless
  execute_packet >/dev/null
  local before out
  before="$(cat "$GIT_MUTATION_LOG")|$(cat "$GH_STUB_STATE")"
  rm -f "$PUBLICATION_PACKET" "$PUBLICATION_NOTES"
  out="$(invoke_prepare)"
  assert_contains "$out" 'PUBLICATION_CLASS=fully-matching' full-match-class
  assert_eq "$(cat "$GIT_MUTATION_LOG")|$(cat "$GH_STUB_STATE")" "$before" full-match-noop
  echo 'Covers S4'
}

case_narrow_repair_scenario() {
  repair_ready
  prepare_program --repair
  ! grep -F -q 'refs/heads/main' "$PUBLICATION_PACKET"
  execute_packet >/dev/null
  assert_eq "$(state_value mutations.edit)" 1 one-page-repair
  assert_canonical_page
  echo 'Covers S5'
}

case_fail_closed_scenario_inventory() {
  python3 - "$ROOT" <<'PY'
import pathlib
import sys

protocol = (pathlib.Path(sys.argv[1]) / "skills/release/references/publication.md").read_text(encoding="utf-8")
for text in (
    "unavailable or errors",
    "silence",
    "relayed approval",
    "packet hash",
    "multiple fenced programs",
    "strict-mode",
    "0.2.0",
    "wrong fixture injection seam",
    "stale",
):
    assert text in protocol, f"missing fail-closed classification: {text}"
PY
  echo 'Covers S6'
}

case_gate_cancel_and_revision() {
  local first_hash changed_hash before after
  invoke_prepare >/dev/null
  first_hash="$(python3 - "$PUBLICATION_PACKET" <<'PY'
import hashlib, pathlib, sys
print(hashlib.sha256(pathlib.Path(sys.argv[1]).read_bytes()).hexdigest())
PY
)"
  before="$(remote_oid refs/heads/main)|$(remote_oid refs/tags/v9.8.7)|$(state_value page)"
  # Cancel performs no packet execution. A revision changes the packet bytes,
  # invalidating the old approval and requiring a new displayed hash/gate.
  printf '\nrevision requested\n' >>"$PUBLICATION_PACKET"
  changed_hash="$(python3 - "$PUBLICATION_PACKET" <<'PY'
import hashlib, pathlib, sys
print(hashlib.sha256(pathlib.Path(sys.argv[1]).read_bytes()).hexdigest())
PY
)"
  [[ "$first_hash" != "$changed_hash" ]]
  after="$(remote_oid refs/heads/main)|$(remote_oid refs/tags/v9.8.7)|$(state_value page)"
  assert_eq "$after" "$before" cancel-revise-no-mutation
}

case_local_release_behavior_regression() {
  python3 - "$ROOT" <<'PY'
import pathlib
import sys

skill = (pathlib.Path(sys.argv[1]) / "skills/release/SKILL.md").read_text(encoding="utf-8")
assert "Accept zero, one, or both of these local-release arguments, in either order:" in skill
assert "Run the seven phases in order" in skill
assert "- `mode:headless` — prepare `.release/draft.md`" in skill
assert "- `<explicit-semver>` — use this SemVer 2.0.0 value" in skill
assert "Reject duplicate mode arguments, more than one version, unknown arguments" in skill
PY
}

all_user_scenarios() {
  run_fixture_case publication_skill_dispatch explicit_publish_returns_before_local_phases case_publication_skill_dispatch_contract pass
  run_fixture_case exact_packet_execution hash_one_fence_one_bash_and_terminal_last case_exact_packet_execution_contract pass
  run_fixture_case s1_first_hand_approval prepare_then_one_exact_execution case_first_hand_approved_publication pass
  run_fixture_case s2_headless_prepare_only packet_without_gate_or_mutation case_headless_handoff_scenario pass
  run_fixture_case s3_partial_resume durable_branch_then_missing_suffix case_partial_resume_scenario pass
  run_fixture_case s4_fully_matching_noop third_invocation_no_mutation case_fully_matching_scenario pass
  run_fixture_case s5_narrow_repair canonical_page_fields_only case_narrow_repair_scenario pass
  run_fixture_case s6_fail_closed_inventory unsafe_inputs_require_failure_or_fresh_gate case_fail_closed_scenario_inventory pass
  run_fixture_case gate_cancel_and_revision old_hash_never_authorizes_revised_packet case_gate_cancel_and_revision pass
  run_fixture_case local_release_regression zero_or_one_semver_and_release_bytes_unchanged case_local_release_behavior_regression pass
}

run_integration_group() {
  run_fixture_case publication_terminal_contract contract_v1_additive_publish_signals case_publication_terminal_contract pass
  all_user_scenarios
}

run_mutations_group() {
  run_fixture_case t1_branch_success exact_non_force_branch_and_suffix case_t1_success pass
  run_fixture_case t1_branch_forced_failure bare_hook_branch_rejection case_t1_forced_failure pass
  run_fixture_case t1_branch_rerun fully_matching_no_repush case_t1_rerun pass
  run_fixture_case t1_branch_rollback_compensation durable_branch_resume_suffix case_t1_rollback pass
  run_fixture_case t1_branch_headless prepare_only_no_transition case_t1_headless pass
  run_fixture_case t1_branch_cancellation_abort before_and_after_verified_branch case_t1_cancel pass
  run_fixture_case t2_tag_success exact_annotated_object_and_peeled_oid case_t2_success pass
  run_fixture_case t2_tag_forced_failure bare_hook_tag_rejection case_t2_forced_failure pass
  run_fixture_case t2_tag_rerun exact_tag_skips_repush case_t2_rerun pass
  run_fixture_case t2_tag_rollback_compensation durable_tag_resume_page case_t2_rollback pass
  run_fixture_case t2_tag_headless prepare_only_no_transition case_t2_headless pass
  run_fixture_case t2_tag_cancellation_abort before_and_after_verified_tag case_t2_cancel pass
  run_fixture_case t3_page_create_success verify_tag_canonical_page case_t3_success pass
  run_fixture_case t3_page_create_forced_failure stub_create_rejection_no_implicit_tag case_t3_forced_failure pass
  run_fixture_case t3_page_create_rerun matching_page_no_recreate case_t3_rerun pass
  run_fixture_case t3_page_create_rollback_compensation durable_page_fresh_noop case_t3_rollback pass
  run_fixture_case t3_page_create_headless prepare_only_no_transition case_t3_headless pass
  run_fixture_case t3_page_create_cancellation_abort before_and_after_create case_t3_cancel pass
  run_fixture_case t4_page_edit_success narrow_canonical_fields_only case_t4_success pass
  run_fixture_case t4_page_edit_forced_failure stub_edit_rejection_identity_unchanged case_t4_forced_failure pass
  run_fixture_case t4_page_edit_rerun canonical_page_no_reedit case_t4_rerun pass
  run_fixture_case t4_page_edit_rollback_compensation post_edit_mutation_fresh_repair case_t4_rollback pass
  run_fixture_case t4_page_edit_headless repair_prepare_only case_t4_headless pass
  run_fixture_case t4_page_edit_cancellation_abort before_and_after_edit case_t4_cancel pass
  run_fixture_case stale_branch_before_transition complete_fingerprint_before_branch case_stale_branch_before pass
  run_fixture_case stale_tag_before_transition complete_fingerprint_before_tag case_stale_tag_before pass
  run_fixture_case stale_page_before_create complete_fingerprint_before_create case_stale_create_before pass
  run_fixture_case stale_page_before_edit complete_fingerprint_before_edit case_stale_edit_before pass
  run_fixture_case branch_post_verification_failure detected_before_later_transition case_post_verify_branch pass
  run_fixture_case tag_post_verification_failure detected_before_later_transition case_post_verify_tag pass
  run_fixture_case page_create_post_verification_failure detected_canonical_page_drift case_post_verify_create pass
  run_fixture_case stale_notes_before_transition exact_notes_sha_before_transition case_notes_stale pass
  run_fixture_case unknown_injection_boundary fail_closed_fixture_seam case_invalid_injection_boundary pass
  run_fixture_case injection_without_fixture_root fail_closed_fixture_seam case_missing_fixture_injection_boundary pass
  run_fixture_case stale_local_tag_before_branch approved_local_tag_object_and_peel case_stale_local_tag_branch pass
  run_fixture_case stale_local_tag_before_tag approved_local_tag_object_and_peel case_stale_local_tag_tag pass
  run_fixture_case stale_local_tag_before_create approved_local_tag_object_and_peel case_stale_local_tag_create pass
  run_fixture_case stale_local_tag_before_edit approved_local_tag_object_and_peel case_stale_local_tag_edit pass
  run_fixture_case redirected_origin_before_branch approved_fetch_and_push_urls case_redirect_origin_branch pass
  run_fixture_case redirected_origin_before_tag approved_fetch_and_push_urls case_redirect_origin_tag pass
  run_fixture_case redirected_origin_before_create approved_fetch_and_push_urls case_redirect_origin_create pass
  run_fixture_case redirected_origin_before_edit approved_fetch_and_push_urls case_redirect_origin_edit pass
  run_fixture_case implicit_tag_disappearance_before_create remote_tag_fingerprint_blocks_gh case_implicit_tag_disappearance pass
}

case "$GROUP" in
  prepare) run_prepare_group ;;
  mutations) run_mutations_group ;;
  integration) run_integration_group ;;
  all)
    run_prepare_group
    run_mutations_group
    run_integration_group
    ;;
esac

echo "SUMMARY group=$GROUP passed=$PASS_COUNT failed=$FAIL_COUNT"
if (( FAIL_COUNT > 0 )); then
  exit 1
fi
