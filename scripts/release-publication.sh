#!/usr/bin/env bash
set -euo pipefail

python3 - "$@" <<'PY'
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
    if url.startswith("file://"):
        return url
    if "://" in url:
        parsed = urlsplit(url)
        host = parsed.hostname or ""
        if parsed.port:
            host += f":{parsed.port}"
        return urlunsplit((parsed.scheme, host, parsed.path, parsed.query, parsed.fragment))
    return re.sub(r"^[^@]+@", "", url)


def github_repository(url):
    if "://" in url:
        parsed = urlsplit(url)
        if parsed.hostname != "github.com" or parsed.port is not None:
            return None
        path = parsed.path.strip("/")
    else:
        match = re.fullmatch(r"(?:[^@/:]+@)?github\.com:([^?#]+)", url)
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
auth = run([gh, "auth", "status", "--hostname", "github.com"], check=False)
if auth.returncode:
    fail("GitHub CLI authentication is inactive")
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

page_result = run([gh, "release", "view", tag, "--repo", repo_slug,
                   "--json", "tagName,name,isDraft,isPrerelease,body,targetCommitish"], check=False)
page = None
if page_result.returncode == 0:
    try:
        page = json.loads(page_result.stdout)
    except json.JSONDecodeError:
        fail("release page state is unreadable")
elif page_result.returncode not in (1,):
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

program = [
    "set -euo pipefail",
    f"cd {shlex.quote(str(cwd))}",
    f"notes={shlex.quote(notes_rel)}",
    f"expected_notes_sha={shlex.quote(notes_sha)}",
    'actual_notes_sha="$(python3 - "$notes" <<\'PY\'\nimport hashlib, pathlib, sys\nprint(hashlib.sha256(pathlib.Path(sys.argv[1]).read_bytes()).hexdigest())\nPY\n)"',
    '[[ "$actual_notes_sha" == "$expected_notes_sha" ]] || { echo "Publication failed — notes fingerprint changed" >&2; exit 1; }',
    f"# expected remote {default_branch}: {remote_branch}",
    f"# expected local release commit: {release_commit}",
    f"# expected annotated tag object/target: {tag_object} {tag_target}",
]
if "branch" in transitions:
    program += [f"git push origin {release_commit}:refs/heads/{default_branch}"]
if "tag" in transitions:
    program += [f"git push origin refs/tags/{tag}:refs/tags/{tag}"]
if "page-create" in transitions:
    command = ["gh", "release", "create", tag, "--repo", repo_slug, "--verify-tag",
               "--title", canonical_title, "--notes-file", notes_rel]
    if prerelease:
        command.append("--prerelease")
    program += [shlex.join(command)]
if "page-edit" in transitions:
    program += [shlex.join(["gh", "release", "edit", tag, "--repo", repo_slug,
                            "--verify-tag", "--title", canonical_title,
                            "--notes-file", notes_rel, "--draft=false",
                            f"--prerelease={'true' if prerelease else 'false'}"])]

packet = "\n".join([
    f"# Publication packet for {tag}", "",
    f"- Repository: `{repo_slug}`",
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
PY
