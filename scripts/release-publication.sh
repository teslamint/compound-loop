#!/usr/bin/env bash
set -euo pipefail

python3 - "$@" <<'RELEASE_PUBLICATION_ENGINE_PY'
import hashlib
import json
import os
import pathlib
import re
import shlex
import shutil
import subprocess
import sys
import tempfile
from urllib.parse import urlsplit, urlunsplit


def fail(message, code=1, classification="unverifiable"):
    print(f"PUBLICATION_CLASS={classification}", file=sys.stderr)
    print(f"Publication preparation failed: {message}", file=sys.stderr)
    raise SystemExit(code)


def run(args, *, check=True, text=True, env=None):
    result = subprocess.run(args, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                            text=text, env=env)
    if check and result.returncode:
        fail(f"required inspection failed ({args[0]})")
    return result


def git(*args, check=True):
    return run(["git", *args], check=check).stdout.strip()


def inside(root, value):
    try:
        pathlib.Path(value).resolve().relative_to(root)
        return True
    except ValueError:
        return False


def strip_credentials(url):
    if "://" in url:
        parsed = urlsplit(url)
        host = parsed.hostname or ""
        if parsed.port:
            host += f":{parsed.port}"
        return urlunsplit((parsed.scheme, host, parsed.path, "", ""))
    return re.sub(r"^[^@]+@", "", url)


def github_repository(url):
    if "://" in url:
        parsed = urlsplit(url)
        if parsed.scheme not in ("https", "ssh"):
            return None
        if parsed.query or parsed.fragment:
            return None
        if parsed.hostname != "github.com" or parsed.port is not None or parsed.password is not None:
            return None
        if parsed.scheme == "https" and parsed.username is not None:
            return None
        if parsed.scheme == "ssh" and parsed.username != "git":
            return None
        path = parsed.path.strip("/")
    else:
        match = re.fullmatch(r"git@github\.com:([^?#]+)", url)
        if not match:
            return None
        path = match.group(1).strip("/")
    if path.endswith(".git"):
        path = path[:-4]
    if not re.fullmatch(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+", path):
        return None
    return path


def parse_args(argv):
    if not argv or argv[0] != "prepare":
        fail("usage: prepare --version <semver> [--repair] [--headless]", 2)
    version = None
    repair = False
    headless = False
    index = 1
    while index < len(argv):
        token = argv[index]
        if token == "--version":
            if version is not None or index + 1 >= len(argv):
                fail("--version must occur exactly once with a value", 2)
            version = argv[index + 1]
            index += 2
        elif token == "--repair":
            if repair:
                fail("duplicate --repair", 2)
            repair = True
            index += 1
        elif token == "--headless":
            if headless:
                fail("duplicate --headless", 2)
            headless = True
            index += 1
        else:
            fail(f"unknown argument: {token}", 2)
    if version is None:
        fail("missing --version", 2)
    semver = re.fullmatch(
        r"(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)"
        r"(?:-([0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?"
        r"(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?", version)
    if not semver:
        fail("version is not valid SemVer", 2)
    if semver.group(4):
        for identifier in semver.group(4).split("."):
            if identifier.isdigit() and len(identifier) > 1 and identifier.startswith("0"):
                fail("version is not valid SemVer", 2)
    return version, repair, headless, bool(semver.group(4))


version, repair, headless, prerelease = parse_args(sys.argv[1:])
tag = f"v{version}"
cwd = pathlib.Path.cwd().resolve()
fixture_value = os.environ.get("RELEASE_PUBLICATION_FIXTURE_ROOT")
fixture_root = pathlib.Path(fixture_value).resolve() if fixture_value else None

allowed_overrides = {
    "RELEASE_PUBLICATION_FIXTURE_ROOT",
    "RELEASE_PUBLICATION_FAIL_AT",
    "RELEASE_PUBLICATION_MUTATE_AT",
}
unknown = sorted(k for k in os.environ if k.startswith("RELEASE_PUBLICATION_") and k not in allowed_overrides)
if unknown:
    fail(f"unknown publication environment override: {unknown[0]}")

fail_at = os.environ.get("RELEASE_PUBLICATION_FAIL_AT", "")
mutate_at = os.environ.get("RELEASE_PUBLICATION_MUTATE_AT", "")
if (fail_at or mutate_at) and not fixture_root:
    fail("failure or mutation injection requires a fixture root")
if fail_at not in ("", "packet-before-rename"):
    fail("unknown fixture failure boundary")
if mutate_at:
    fail("no mutation boundary is available during preparation")

if fixture_root:
    if not pathlib.Path(fixture_value).is_absolute() or not inside(fixture_root, cwd):
        fail("fixture repository escapes fixture root")
    inventory = {
        "HOME": os.environ.get("HOME", ""),
        "TMPDIR": os.environ.get("TMPDIR", ""),
        "gh": shutil.which("gh") or "",
        "GH_STUB_STATE": os.environ.get("GH_STUB_STATE", ""),
        "GH_STUB_LOG": os.environ.get("GH_STUB_LOG", ""),
        "GH_STUB_BARE_REMOTE": os.environ.get("GH_STUB_BARE_REMOTE", ""),
    }
    for label, value in inventory.items():
        if not value or not inside(fixture_root, value):
            fail(f"fixture target escapes root: {label}")

if git("rev-parse", "--show-toplevel") != str(cwd):
    fail("run from the repository root")
if git("status", "--porcelain"):
    fail("worktree must be clean")

default_ref = git("symbolic-ref", "--quiet", "refs/remotes/origin/HEAD", check=False)
if not default_ref:
    fail("symbolic origin/HEAD is required")
default_branch = default_ref.rsplit("/", 1)[-1]
current_branch = git("symbolic-ref", "--short", "HEAD", check=False)
if current_branch != default_branch:
    fail("checked-out branch is not the default branch")

head_commit = git("rev-parse", "HEAD")
tag_object = git("rev-parse", f"refs/tags/{tag}", check=False)
tag_target = git("rev-parse", f"refs/tags/{tag}^{{}}", check=False)
tag_type = git("cat-file", "-t", f"refs/tags/{tag}", check=False)
if not tag_object or not tag_target or tag_type != "tag":
    fail("local release tag must be annotated")
if not repair and tag_target != head_commit:
    fail("HEAD must equal the annotated tag target")
if repair and run(["git", "merge-base", "--is-ancestor", tag_target, head_commit], check=False).returncode != 0:
    fail("repair HEAD must contain the annotated tag target")
release_commit = tag_target


def release_blob(relative, maximum=2 * 1024 * 1024):
    object_name = f"{release_commit}:{relative}"
    if git("cat-file", "-t", object_name, check=False) != "blob":
        fail(f"release commit is missing required blob: {relative}")
    size_text = git("cat-file", "-s", object_name, check=False)
    if not size_text.isdigit() or int(size_text) > maximum:
        fail(f"release commit blob exceeds inspection bound: {relative}")
    result = run(["git", "show", object_name], check=False, text=False)
    if result.returncode or len(result.stdout) != int(size_text):
        fail(f"cannot read release commit blob: {relative}")
    return result.stdout

manifest_versions = []
for relative in (".claude-plugin/plugin.json", ".codex-plugin/plugin.json"):
    try:
        manifest_versions.append(json.loads(release_blob(relative).decode("utf-8"))["version"])
    except (UnicodeDecodeError, KeyError, json.JSONDecodeError):
        fail(f"cannot read manifest version: {relative}")
if manifest_versions != [version, version]:
    fail("plugin manifests do not match the requested version")

try:
    changelog = release_blob("CHANGELOG.md").decode("utf-8")
except UnicodeDecodeError:
    fail("cannot read CHANGELOG.md")
heading = re.compile(r"^## \[([^]]+)\](?:\s+-\s+.*)?$", re.MULTILINE)
matches = list(heading.finditer(changelog))
if not matches or matches[0].group(1) != version:
    fail("newest CHANGELOG section does not match the requested version")
start = matches[0].end()
if changelog[start:start + 2] == "\n\n":
    start += 2
elif changelog[start:start + 1] == "\n":
    start += 1
end = matches[1].start() if len(matches) > 1 else len(changelog)
notes_text = changelog[start:end]
while notes_text.endswith("\n\n"):
    notes_text = notes_text[:-1]
if not notes_text.endswith("\n"):
    notes_text += "\n"
notes_bytes = notes_text.encode("utf-8")
notes_sha = hashlib.sha256(notes_bytes).hexdigest()

fetch_url = git("remote", "get-url", "origin")
push_url = git("remote", "get-url", "--push", "origin")
if fixture_root:
    for label, url in (("fetch", fetch_url), ("push", push_url)):
        if not url.startswith("file://") or not inside(fixture_root, url[7:]):
            fail(f"fixture {label} remote escapes root")
    repo_slug = os.environ.get("GH_STUB_REPO", "")
    if not re.fullmatch(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+", repo_slug):
        fail("invalid fixture repository slug")
else:
    fetch_repo = github_repository(fetch_url)
    push_repo = github_repository(push_url)
    if not fetch_repo or not push_repo:
        fail("origin fetch and push URLs must both target github.com")
    if fetch_repo != push_repo:
        fail("origin fetch and push URLs must target the same GitHub repository")
    repo_slug = fetch_repo

gh = shutil.which("gh")
if not gh:
    fail("GitHub CLI is unavailable")
gh_version_result = run([gh, "--version"], check=False)
if gh_version_result.returncode or len(gh_version_result.stdout) > 4096:
    fail("GitHub CLI version is unreadable")
gh_version_match = re.fullmatch(r"gh version ([0-9]+(?:\.[0-9]+){1,3})(?: .*)?",
                                gh_version_result.stdout.splitlines()[0] if gh_version_result.stdout.splitlines() else "")
if not gh_version_match:
    fail("GitHub CLI version is unreadable")
gh_version = gh_version_match.group(1)
auth = run([gh, "auth", "status", "--hostname", "github.com"], check=False)
if auth.returncode:
    fail("GitHub CLI authentication is inactive")
auth_text = auth.stdout + "\n" + auth.stderr
if len(auth_text) > 65536:
    fail("GitHub CLI authentication evidence exceeds inspection bound")
scope_names = []
for line in auth_text.splitlines():
    if "token scopes:" in line.lower():
        scope_names.extend(re.findall(r"['\"]([A-Za-z0-9:_-]+)['\"]", line))
scope_names = sorted(set(scope_names))
if not scope_names:
    fail("GitHub CLI reported auth scopes are unavailable")

required_help = {
    "create": ("--repo", "--verify-tag", "--title", "--notes-file", "--prerelease"),
    "edit": ("--repo", "--verify-tag", "--title", "--notes-file", "--draft", "--prerelease"),
}
capability_flags = {}
for action, required_flags in required_help.items():
    help_result = run([gh, "release", action, "--help"], check=False)
    help_text = help_result.stdout + "\n" + help_result.stderr
    if help_result.returncode or len(help_text) > 65536:
        fail(f"GitHub release {action} capability is unavailable")
    missing_flags = [flag for flag in required_flags
                     if not re.search(rf"(?<![A-Za-z0-9-]){re.escape(flag)}(?![A-Za-z0-9-])", help_text)]
    if missing_flags:
        fail(f"GitHub release {action} capability is missing required flag: {missing_flags[0]}")
    capability_flags[action] = required_flags
repo_read = run([gh, "api", f"repos/{repo_slug}", "--jq", ".full_name"], check=False)
if repo_read.returncode or repo_read.stdout.strip() != repo_slug:
    fail("GitHub repository state is unreadable")

remote = run(["git", "ls-remote", "origin", f"refs/heads/{default_branch}",
              f"refs/tags/{tag}", f"refs/tags/{tag}^{{}}"], check=False)
if remote.returncode:
    fail("remote refs are unreadable")
refs = {}
for line in remote.stdout.splitlines():
    fields = line.split("\t", 1)
    if len(fields) == 2 and re.fullmatch(r"[0-9a-f]{40,64}", fields[0]):
        refs[fields[1]] = fields[0]
remote_branch = refs.get(f"refs/heads/{default_branch}")
if not remote_branch:
    fail("remote default branch is missing")
remote_tag_object = refs.get(f"refs/tags/{tag}")
remote_tag_target = refs.get(f"refs/tags/{tag}^{{}}")

branch_equal = remote_branch == release_commit
remote_ancestor = run(["git", "merge-base", "--is-ancestor", remote_branch, release_commit], check=False).returncode == 0
release_ancestor = run(["git", "merge-base", "--is-ancestor", release_commit, remote_branch], check=False).returncode == 0
if not (branch_equal or remote_ancestor or release_ancestor):
    fail("remote default branch conflicts with the release commit", classification="conflicting")
if not repair and release_ancestor and not branch_equal:
    fail("remote default branch is later than the release commit; use repair")
if repair and not (branch_equal or release_ancestor):
    fail("repair requires remote default branch to contain the release commit")

if remote_tag_object or remote_tag_target:
    if remote_tag_object != tag_object or remote_tag_target != tag_target:
        fail("remote annotated tag identity conflicts with the local tag", classification="conflicting")
    tag_matches = True
else:
    tag_matches = False

page_probe = run([gh, "api", "--include", f"repos/{repo_slug}/releases/tags/{tag}"], check=False)
if len(page_probe.stdout) > 65536 or len(page_probe.stderr) > 65536:
    fail("release page status response exceeds inspection bound")
probe_lines = page_probe.stdout.splitlines()
status_match = re.fullmatch(r"HTTP/(?:1\.1|2(?:\.0)?) ([0-9]{3})(?: .*)?", probe_lines[0] if probe_lines else "")
if not status_match:
    fail("release page status is unreadable")
page_status = int(status_match.group(1))
page = None
if page_status == 404:
    if page_probe.returncode not in (0, 1):
        fail("release page state is unreadable")
elif page_status == 200 and page_probe.returncode == 0:
    page_result = run([gh, "release", "view", tag, "--repo", repo_slug,
                       "--json", "tagName,name,isDraft,isPrerelease,body,targetCommitish"], check=False)
    if page_result.returncode:
        fail("release page state is unreadable")
    try:
        page = json.loads(page_result.stdout)
    except json.JSONDecodeError:
        fail("release page state is unreadable")
else:
    fail("release page state is unreadable")

repo_name = repo_slug.split("/", 1)[1]
canonical_title = f"{repo_name} {tag}"
page_matches = bool(page) and (
    page.get("tagName") == tag
    and page.get("name") == canonical_title
    and page.get("body") == notes_text
    and page.get("isDraft") is False
    and page.get("isPrerelease") is prerelease
)
if page and page.get("tagName") != tag:
    fail("release page identity conflicts with the requested tag", classification="conflicting")
page_body_sha = hashlib.sha256((page.get("body", "") if page else "").encode("utf-8")).hexdigest() if page else "absent"
page_fingerprint = hashlib.sha256(json.dumps(page, sort_keys=True, separators=(",", ":")).encode("utf-8")).hexdigest() if page else "absent"

transitions = []
if version == "0.2.0" and not repair:
    print("PUBLICATION_STATUS=noop")
    print("PUBLICATION_CLASS=conflicting")
    print("PUBLICATION_REASON=protected-version-requires-repair")
    raise SystemExit(0)
if page_matches and tag_matches and (branch_equal or (repair and release_ancestor)):
    print("PUBLICATION_STATUS=noop")
    print("PUBLICATION_CLASS=fully-matching")
    raise SystemExit(0)
if page and not tag_matches:
    if not repair:
        fail("release page exists before the matching remote tag; use repair")
    classification = "repairable-unordered-page"
    transitions.append("tag")
    if not page_matches:
        transitions.append("page-edit")
elif page and not page_matches:
    if not repair:
        fail("release page fields differ; use repair")
    if not tag_matches:
        fail("page repair requires a matching remote tag")
    classification = "repairable-page"
    transitions.append("page-edit")
else:
    if not repair and not branch_equal:
        classification = "fast-forwardable"
        transitions.append("branch")
    elif not tag_matches:
        classification = "branch-ready-tag-missing"
    else:
        classification = "refs-ready-page-missing"
    if not tag_matches:
        transitions.append("tag")
    transitions.append("page-create")

release_dir = cwd / ".release"
release_dir.mkdir(mode=0o700, exist_ok=True)
notes_path = release_dir / f"publication-{tag}-notes.md"
packet_path = release_dir / f"publication-{tag}.md"
notes_rel = f".release/{notes_path.name}"
packet_rel = f".release/{packet_path.name}"

q = shlex.quote
program_text = f'''set -euo pipefail
cd {q(str(cwd))}
notes={q(notes_rel)}
expected_notes_sha={q(notes_sha)}
repo={q(repo_slug)}
tag={q(tag)}
default_ref={q(f"refs/heads/{default_branch}")}
release_commit={q(release_commit)}
tag_object={q(tag_object)}
tag_target={q(tag_target)}
canonical_title={q(canonical_title)}
canonical_prerelease={q("true" if prerelease else "false")}
expected_branch={q(remote_branch)}
expected_tag_object={q(remote_tag_object or "absent")}
expected_tag_target={q(remote_tag_target or "absent")}
expected_page_fingerprint={q(page_fingerprint)}
expected_fetch_url={q(fetch_url)}
expected_push_url={q(push_url)}
fixture_root={q(str(fixture_root) if fixture_root else "")}
fixture_remote={q(push_url[7:] if fixture_root else "")}
fixture_state={q(os.environ.get("GH_STUB_STATE", "") if fixture_root else "")}
gh_bin={q(gh)}

publication_fail() {{
  printf 'MECHANISM=%s\n' "$1" >&2
  printf 'Publication failed — %s\n' "$2" >&2
  exit 1
}}

notes_sha() {{
  python3 - "$notes" <<'PY'
import hashlib, pathlib, sys
print(hashlib.sha256(pathlib.Path(sys.argv[1]).read_bytes()).hexdigest())
PY
}}

assert_transport() {{
  local boundary="$1" current_fetch_url current_push_url
  current_fetch_url="$(git remote get-url origin 2>/dev/null || true)"
  current_push_url="$(git remote get-url --push origin 2>/dev/null || true)"
  [[ "$current_fetch_url" == "$expected_fetch_url" && "$current_push_url" == "$expected_push_url" ]] || publication_fail "$boundary-transport" "origin fetch or push target changed before $boundary"
}}

remote_ref() {{
  assert_transport remote-read
  git ls-remote origin "$1" 2>/dev/null | awk -v wanted="$1" '$2 == wanted {{ print $1 }}'
}}

page_json() {{
  local probe output code status
  set +e
  probe="$("$gh_bin" api --include "repos/$repo/releases/tags/$tag" 2>&1)"
  code=$?
  set -e
  [[ ${{#probe}} -le 65536 ]] || publication_fail page-read "release page status response exceeded inspection bound"
  status="$(python3 - "$probe" <<'PY'
import re, sys
lines=sys.argv[1].splitlines()
match=re.fullmatch(r"HTTP/(?:1\.1|2(?:\.0)?) ([0-9]{{3}})(?: .*)?", lines[0] if lines else "")
print(match.group(1) if match else "")
PY
)"
  [[ -n "$status" ]] || publication_fail page-read "release page status became unreadable"
  if [[ "$status" == 404 && ( $code -eq 0 || $code -eq 1 ) ]]; then printf 'absent'; return 0; fi
  [[ "$status" == 200 && $code -eq 0 ]] || publication_fail page-read "release page state became unreadable"
  set +e
  output="$("$gh_bin" release view "$tag" --repo "$repo" --json tagName,name,isDraft,isPrerelease,body,targetCommitish 2>/dev/null)"
  code=$?
  set -e
  [[ $code -eq 0 ]] || publication_fail page-read "release page state became unreadable"
  python3 - "$output" <<'PY'
import json, sys
print(json.dumps(json.loads(sys.argv[1]), sort_keys=True, separators=(",", ":")))
PY
}}

page_fingerprint() {{
  local value="$1"
  if [[ "$value" == absent ]]; then printf absent; return; fi
  python3 - "$value" <<'PY'
import hashlib, sys
print(hashlib.sha256(sys.argv[1].encode()).hexdigest())
PY
}}

assert_fingerprint() {{
  local boundary="$1" branch tag_obj tag_peeled current_page current_page_fp local_tag_object local_tag_target
  [[ "$(notes_sha)" == "$expected_notes_sha" ]] || publication_fail "$boundary-notes" "notes fingerprint changed before $boundary"
  local_tag_object="$(git rev-parse "refs/tags/$tag" 2>/dev/null || true)"
  local_tag_target="$(git rev-parse "refs/tags/$tag^{{}}" 2>/dev/null || true)"
  [[ "$local_tag_object" == "$tag_object" && "$local_tag_target" == "$tag_target" ]] || publication_fail "$boundary-local-tag" "local annotated tag identity changed before $boundary"
  assert_transport "$boundary"
  branch="$(remote_ref "$default_ref")"
  tag_obj="$(remote_ref "refs/tags/$tag")"
  tag_peeled="$(remote_ref "refs/tags/$tag^{{}}")"
  [[ -n "$tag_obj" ]] || tag_obj=absent
  [[ -n "$tag_peeled" ]] || tag_peeled=absent
  current_page="$(page_json)"
  current_page_fp="$(page_fingerprint "$current_page")"
  [[ "$branch" == "$expected_branch" ]] || publication_fail "$boundary-branch" "remote branch fingerprint changed before $boundary"
  [[ "$tag_obj" == "$expected_tag_object" && "$tag_peeled" == "$expected_tag_target" ]] || publication_fail "$boundary-tag" "remote tag fingerprint changed before $boundary"
  [[ "$current_page_fp" == "$expected_page_fingerprint" ]] || publication_fail "$boundary-page" "release page fingerprint changed before $boundary"
}}

verify_page() {{
  local value="$1"
  [[ "$value" != absent ]] || publication_fail page-post-verify "release page is absent after transition"
  python3 - "$value" "$tag" "$canonical_title" "$notes" "$canonical_prerelease" <<'PY' || publication_fail page-post-verify "canonical release page verification failed"
import json, pathlib, sys
page=json.loads(sys.argv[1])
expected=(page.get("tagName") == sys.argv[2] and page.get("name") == sys.argv[3]
          and page.get("body") == pathlib.Path(sys.argv[4]).read_text()
          and page.get("isDraft") is False
          and page.get("isPrerelease") is (sys.argv[5] == "true"))
raise SystemExit(0 if expected else 1)
PY
}}

verify_remote_tag() {{
  [[ "$(remote_ref "refs/tags/$tag")" == "$tag_object" && "$(remote_ref "refs/tags/$tag^{{}}")" == "$tag_target" ]] || publication_fail page-post-verify "remote annotated tag identity changed during page transition"
}}

validate_injection() {{
  local fail_at="${{RELEASE_PUBLICATION_FAIL_AT:-}}" mutate_at="${{RELEASE_PUBLICATION_MUTATE_AT:-}}" path
  [[ -z "$fail_at$mutate_at" ]] && return
  [[ -n "$fixture_root" ]] || publication_fail fixture-boundary "failure or mutation injection requires a fixture root"
  case "$fail_at" in
    ''|branch-before|branch-push|branch-post-verify|tag-before|tag-push|tag-post-verify|page-create-before|page-create|page-create-post-verify|page-edit-before|page-edit|page-edit-post-verify) ;;
    *) publication_fail fixture-boundary "unknown fixture failure boundary" ;;
  esac
  case "$mutate_at" in
    ''|branch-before|branch-post-verify|tag-before|tag-post-verify|page-create-before|page-create-tag-before|page-create-post-verify|page-edit-before|page-edit-post-verify) ;;
    *) publication_fail fixture-boundary "unknown fixture mutation boundary" ;;
  esac
  for path in "$PWD" "$notes" "$gh_bin" "$fixture_remote" "$fixture_state"; do
    python3 - "$fixture_root" "$path" <<'PY' || publication_fail fixture-boundary "injection target escapes fixture root"
import pathlib, sys
try: pathlib.Path(sys.argv[2]).resolve().relative_to(pathlib.Path(sys.argv[1]).resolve())
except ValueError: raise SystemExit(1)
PY
  done
}}

inject_at() {{
  local boundary="$1" fail_at="${{RELEASE_PUBLICATION_FAIL_AT:-}}" mutate_at="${{RELEASE_PUBLICATION_MUTATE_AT:-}}"
  [[ "$fail_at" != "$boundary" ]] || publication_fail "injected-$boundary" "injected fixture failure at $boundary"
  [[ "$mutate_at" != "$boundary" ]] || {{
    case "$boundary" in
      branch-before ) git --git-dir="$fixture_remote" fetch "$PWD" "$release_commit" >/dev/null 2>&1; git --git-dir="$fixture_remote" update-ref "$default_ref" "$release_commit" ;;
      branch-* ) git --git-dir="$fixture_remote" update-ref "$default_ref" "$(git rev-parse HEAD^)" ;;
      page-create-tag-before ) git --git-dir="$fixture_remote" update-ref "refs/tags/$tag" "$release_commit" ;;
      tag-* ) git --git-dir="$fixture_remote" update-ref "refs/tags/$tag" "$release_commit" ;;
      page-* ) python3 - "$fixture_state" <<'PY'
import json, pathlib, sys
p=pathlib.Path(sys.argv[1]); s=json.loads(p.read_text())
if s.get("page") is None:
    s["page"]={{"tagName":"v-stale","name":"stale","body":"stale\\n","isDraft":True,"isPrerelease":False}}
    s["page_lookup_any"]=True
else: s["page"]["name"]="fixture-mutated-page"
p.write_text(json.dumps(s, sort_keys=True)+"\\n")
PY
        ;;
      * ) publication_fail fixture-boundary "unknown mutation boundary" ;;
    esac
    printf 'MECHANISM=mutated-%s\n' "$boundary" >&2
  }}
}}

validate_injection
'''
program = program_text.splitlines()

if "branch" in transitions:
    program += [
        'inject_at branch-before',
        'assert_fingerprint branch-push',
        'inject_at branch-push',
        f'git push origin {release_commit}:refs/heads/{default_branch} || publication_fail branch-push "non-force branch push rejected"',
        'expected_branch="$release_commit"',
        'inject_at branch-post-verify',
        '[[ "$(remote_ref "$default_ref")" == "$release_commit" ]] || publication_fail branch-post-verify "remote branch verification failed"',
    ]
if "tag" in transitions:
    program += [
        'inject_at tag-before',
        'assert_fingerprint tag-push',
        'inject_at tag-push',
        f'git push origin refs/tags/{tag}:refs/tags/{tag} || publication_fail tag-push "non-force annotated tag push rejected"',
        'expected_tag_object="$tag_object"',
        'expected_tag_target="$tag_target"',
        'inject_at tag-post-verify',
        '[[ "$(remote_ref "refs/tags/$tag")" == "$tag_object" && "$(remote_ref "refs/tags/$tag^{}")" == "$tag_target" ]] || publication_fail tag-post-verify "annotated tag verification failed"',
    ]
if "page-create" in transitions:
    command = [gh, "release", "create", tag, "--repo", repo_slug, "--verify-tag",
               "--title", canonical_title, "--notes-file", notes_rel]
    if prerelease:
        command.append("--prerelease")
    program += [
        'inject_at page-create-tag-before',
        'inject_at page-create-before',
        'assert_fingerprint page-create',
        'inject_at page-create',
        shlex.join(command) + ' || publication_fail page-create "release page creation rejected"',
        'inject_at page-create-post-verify',
        'created_page="$(page_json)"',
        'verify_page "$created_page"',
        'verify_remote_tag',
        'expected_page_fingerprint="$(page_fingerprint "$created_page")"',
    ]
if "page-edit" in transitions:
    command = [gh, "release", "edit", tag, "--repo", repo_slug,
               "--verify-tag", "--title", canonical_title,
               "--notes-file", notes_rel, "--draft=false",
               f"--prerelease={'true' if prerelease else 'false'}"]
    program += [
        'inject_at page-edit-before',
        'assert_fingerprint page-edit',
        'inject_at page-edit',
        shlex.join(command) + ' || publication_fail page-edit "release page repair rejected"',
        'inject_at page-edit-post-verify',
        'edited_page="$(page_json)"',
        'verify_page "$edited_page"',
        'verify_remote_tag',
        'expected_page_fingerprint="$(page_fingerprint "$edited_page")"',
    ]
program += ['printf \'PUBLICATION_EXECUTION=complete\\n\'']

packet = "\n".join([
    f"# Publication packet for {tag}", "",
    f"- Repository: `{repo_slug}`",
    f"- Capability gh version: `{gh_version}`",
    f"- Capability auth: `active`; reported scopes: `{', '.join(scope_names)}` (reported names only; not proof of write authorization)",
    f"- Capability repository read: `confirmed`",
    f"- Capability release create flags: `{' '.join(capability_flags['create'])}`",
    f"- Capability release edit flags: `{' '.join(capability_flags['edit'])}`",
    f"- Fetch remote: `{strip_credentials(fetch_url)}`",
    f"- Push remote: `{strip_credentials(push_url)}`",
    f"- Default ref: `refs/heads/{default_branch}`",
    f"- Observed remote branch OID: `{remote_branch}`",
    f"- Local release commit: `{release_commit}`",
    f"- Annotated tag object OID: `{tag_object}`",
    f"- Annotated tag peeled OID: `{tag_target}`",
    f"- Observed remote tag object OID: `{remote_tag_object or 'absent'}`",
    f"- Observed remote tag peeled OID: `{remote_tag_target or 'absent'}`",
    f"- Observed page: `{'present' if page else 'absent'}`",
    f"- Observed page tag: `{page.get('tagName', 'absent') if page else 'absent'}`",
    f"- Observed page title: `{page.get('name', 'absent') if page else 'absent'}`",
    f"- Observed page draft: `{str(page.get('isDraft')).lower() if page else 'absent'}`",
    f"- Observed page prerelease: `{str(page.get('isPrerelease')).lower() if page else 'absent'}`",
    f"- Observed page body SHA-256: `{page_body_sha}`",
    f"- Observed page fingerprint SHA-256: `{page_fingerprint}`",
    f"- Observed targetCommitish: `{page.get('targetCommitish', 'unreported') if page else 'absent'}` (informational only; never a repair field)",
    f"- Canonical title: `{canonical_title}`",
    f"- Canonical draft: `false`",
    f"- Canonical prerelease: `{'true' if prerelease else 'false'}`",
    f"- Notes path: `{notes_rel}`",
    f"- Notes bytes: `{len(notes_bytes)}`",
    f"- Notes SHA-256: `{notes_sha}`",
    f"- Classification: `{classification}`",
    f"- Ordered transitions: `{' -> '.join(transitions)}`",
    *[f"- Expected pre-state ({transition}): `branch={release_commit if transition != 'branch' and 'branch' in transitions else remote_branch}; tag={'exact' if transition.startswith('page') else ('absent' if not tag_matches else 'exact')}; page={page_fingerprint}`" for transition in transitions],
    "- Recovery: re-run preparation from freshly observed durable state; never force, delete, or retarget.",
    "- Authorization: this packet is not approval; only a first-hand gate in the executing session authorizes one exact run.",
    "", "```bash", *program, "```", ""
])

notes_tmp = None
packet_tmp = None
try:
    # A version-specific packet from an earlier observation must never survive
    # as the executable companion of freshly written notes.
    packet_path.unlink(missing_ok=True)
    fd, notes_tmp = tempfile.mkstemp(prefix=notes_path.name + ".tmp.", dir=release_dir)
    with os.fdopen(fd, "wb") as handle:
        handle.write(notes_bytes)
        handle.flush()
        os.fsync(handle.fileno())
    os.replace(notes_tmp, notes_path)
    notes_tmp = None

    fd, packet_tmp = tempfile.mkstemp(prefix=packet_path.name + ".tmp.", dir=release_dir)
    with os.fdopen(fd, "w", encoding="utf-8", newline="\n") as handle:
        handle.write(packet)
        handle.flush()
        os.fsync(handle.fileno())
    if fail_at == "packet-before-rename":
        fail("injected fixture failure at packet-before-rename")
    os.replace(packet_tmp, packet_path)
    packet_tmp = None
finally:
    for temporary in (notes_tmp, packet_tmp):
        if temporary:
            pathlib.Path(temporary).unlink(missing_ok=True)

packet_sha = hashlib.sha256(packet_path.read_bytes()).hexdigest()
print("PUBLICATION_STATUS=ready")
print(f"PUBLICATION_CLASS={classification}")
print(f"PUBLICATION_PACKET={packet_rel}")
print(f"PUBLICATION_PACKET_SHA256={packet_sha}")
RELEASE_PUBLICATION_ENGINE_PY
