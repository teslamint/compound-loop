#!/usr/bin/env bash
# Validate the declared CPython compatibility contract and its boundary endpoints.
# This file is both the focused gate and its disposable fixture harness. Stdlib only.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SELF="$ROOT/scripts/test-python-compatibility.sh"
CONTRACT="${PYTHON_SUPPORT_FILE:-$ROOT/schemas/python-support.json}"
BOOTSTRAP="${PYTHON_BOOTSTRAP:-python3}"
if ! "$BOOTSTRAP" -c "import sys; sys.exit(0 if sys.version_info >= (3, 8) else 1)" 2>/dev/null; then
  echo "FAIL: [python-compat] bootstrap interpreter ($BOOTSTRAP) is below CPython 3.8 or missing"
  exit 1
fi
TAG="[python-compat]"
TMP_ROOT=""
FAIL_COUNT=0
CONTRACT_VALUES=()
ENDPOINT_PATHS=()
ENDPOINT_VERSIONS=()

ok() { printf 'ok:   %s %s\n' "$TAG" "$*"; }
fail() { printf 'FAIL: %s %s\n' "$TAG" "$*"; }

cleanup() {
  local rc=$?
  trap - EXIT
  if [[ -n "$TMP_ROOT" && -d "$TMP_ROOT" ]]; then
    rm -rf -- "$TMP_ROOT"
  fi
  exit "$rc"
}

make_tmp_root() {
  local made
  made="$(mktemp -d "${TMPDIR:-/tmp}/compound-loop-python-compat.XXXXXX" 2>&1)" || {
    fail "temporary root creation failed: ${made:0:160}"
    return 1
  }
  TMP_ROOT="$made"
  trap cleanup EXIT
  trap 'exit 129' HUP
  trap 'exit 130' INT
  trap 'exit 143' TERM
}

validate_contract() {
  local output rc
  output="$("$BOOTSTRAP" - "$CONTRACT" 2>&1 <<'PY'
import json
import re
import sys

path = sys.argv[1]
try:
    with open(path, encoding="utf-8") as stream:
        value = json.load(stream)
except (OSError, UnicodeError, json.JSONDecodeError) as exc:
    print("contract unreadable or malformed JSON: " + str(exc).splitlines()[0][:120])
    raise SystemExit(1)

expected = {"schema_version", "implementation", "minimum_minor", "maximum_minor"}
if not isinstance(value, dict):
    print("contract root must be an object")
    raise SystemExit(1)
actual = set(value)
if actual != expected:
    missing = sorted(expected - actual)
    extra = sorted(actual - expected)
    print("contract fields mismatch: missing=%s extra=%s" % (missing, extra))
    raise SystemExit(1)
if type(value["schema_version"]) is not int or value["schema_version"] != 1:
    print("schema_version must be integer 1")
    raise SystemExit(1)
if type(value["implementation"]) is not str or value["implementation"] != "CPython":
    print("implementation must be CPython")
    raise SystemExit(1)
minor_re = re.compile(r"^[0-9]+\.[0-9]+$")
for key in ("minimum_minor", "maximum_minor"):
    item = value[key]
    if type(item) is not str or not minor_re.fullmatch(item):
        print(key + " must be a major.minor string")
        raise SystemExit(1)
minimum = tuple(map(int, value["minimum_minor"].split(".")))
maximum = tuple(map(int, value["maximum_minor"].split(".")))
if minimum >= maximum:
    print("minimum_minor must be lower than maximum_minor")
    raise SystemExit(1)
print(value["schema_version"])
print(value["implementation"])
print(value["minimum_minor"])
print(value["maximum_minor"])
PY
)"; rc=$?
  if [[ $rc -ne 0 ]]; then
    output="${output//$'\n'/ }"
    fail "contract path=$CONTRACT reason=${output:0:220}"
    return 1
  fi
  CONTRACT_VALUES=()
  while IFS= read -r line; do
    CONTRACT_VALUES[${#CONTRACT_VALUES[@]}]="$line"
  done <<< "$output"
  if [[ ${#CONTRACT_VALUES[@]} -ne 4 ]]; then
    fail "contract validator returned an invalid bounded result"
    return 1
  fi
  ok "contract schema=${CONTRACT_VALUES[0]} implementation=${CONTRACT_VALUES[1]} range=${CONTRACT_VALUES[2]}..${CONTRACT_VALUES[3]}"
}

resolve_absolute() {
  "$BOOTSTRAP" - "$1" <<'PY'
import os
import sys
print(os.path.realpath(sys.argv[1]))
PY
}

resolve_endpoint() {
  local role="$1" expected="$2" override="$3"
  local candidate resolved version_text identity rc implementation full_version actual_minor
  if [[ -n "$override" ]]; then
    if [[ "$override" != /* ]]; then
      fail "endpoint role=$role expected=$expected reason=override must be an absolute path"
      return 1
    fi
    candidate="$override"
  else
    candidate="$(command -v "python$expected" 2>/dev/null || true)"
    if [[ -z "$candidate" ]]; then
      fail "endpoint role=$role expected=$expected reason=command python$expected not found"
      return 1
    fi
  fi
  if [[ ! -f "$candidate" || ! -x "$candidate" ]]; then
    fail "endpoint role=$role expected=$expected reason=path is missing or not executable path=${candidate:0:160}"
    return 1
  fi
  resolved="$(resolve_absolute "$candidate" 2>/dev/null)" || {
    fail "endpoint role=$role expected=$expected reason=could not resolve absolute path"
    return 1
  }
  if [[ ! -f "$resolved" || ! -x "$resolved" ]]; then
    fail "endpoint role=$role expected=$expected reason=resolved path is missing or not executable path=${resolved:0:160}"
    return 1
  fi

  version_text="$("$resolved" --version 2>&1)"; rc=$?
  version_text="${version_text//$'\n'/ }"
  if [[ $rc -ne 0 ]]; then
    fail "endpoint role=$role expected=$expected path=$resolved reason=--version failed output=${version_text:0:120}"
    return 1
  fi
  identity="$("$resolved" -c 'import platform,sys; print(platform.python_implementation()+"\t"+platform.python_version())' 2>&1)"; rc=$?
  identity="${identity//$'\n'/ }"
  if [[ $rc -ne 0 || "$identity" != *$'\t'* ]]; then
    fail "endpoint role=$role expected=$expected path=$resolved reason=identity probe failed output=${identity:0:120}"
    return 1
  fi
  implementation="${identity%%$'\t'*}"
  full_version="${identity#*$'\t'}"
  if [[ "$implementation" != "CPython" ]]; then
    fail "endpoint role=$role expected=$expected path=$resolved version=${version_text:0:80} reason=implementation is ${implementation:0:40}, expected CPython"
    return 1
  fi
  if [[ ! "$full_version" =~ ^([0-9]+)\.([0-9]+)\.([^[:space:]]+)$ ]]; then
    fail "endpoint role=$role expected=$expected path=$resolved reason=invalid full version ${full_version:0:80}"
    return 1
  fi
  actual_minor="${BASH_REMATCH[1]}.${BASH_REMATCH[2]}"
  if [[ "$actual_minor" != "$expected" ]]; then
    fail "endpoint role=$role expected=$expected path=$resolved version=Python $full_version reason=wrong major.minor actual=$actual_minor"
    return 1
  fi
  if [[ "$role" == "oldest" ]]; then
    ENDPOINT_PATHS[0]="$resolved"
    ENDPOINT_VERSIONS[0]="$full_version"
  else
    ENDPOINT_PATHS[1]="$resolved"
    ENDPOINT_VERSIONS[1]="$full_version"
  fi
  ok "endpoint role=$role expected=$expected path=$resolved version=Python $full_version"
}

run_contract() {
  validate_contract
}

run_endpoints() {
  local result=0
  ENDPOINT_PATHS=()
  ENDPOINT_VERSIONS=()
  validate_contract || return 1
  resolve_endpoint oldest "${CONTRACT_VALUES[2]}" "${PYTHON_OLDEST:-}" || result=1
  resolve_endpoint newest "${CONTRACT_VALUES[3]}" "${PYTHON_NEWEST:-}" || result=1
  return "$result"
}

artifact_registry() {
  cat <<'REGISTRY'
committed|compound-frontmatter-validator|skills/compound/scripts/validate-frontmatter.py
committed|plan-frontmatter-validator|skills/planning/scripts/validate-plan-frontmatter.py
committed|run-artifact-integrity-cli|skills/release-loop/scripts/run-artifact-integrity.py
committed|phase-artifact-integrity-cli|skills/implementing/scripts/phase-artifact-integrity.py
generated|release-publication-engine|scripts/release-publication.sh|RELEASE_PUBLICATION_ENGINE_PY|RELEASE_PUBLICATION_ENGINE_PY
REGISTRY
}

registry_entries() {
  local line class label rest result=0
  local labels="|"
  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    IFS='|' read -r class label rest _extra <<< "$line"
    if [[ "$class" != "committed" && "$class" != "generated" ]]; then
      fail "artifact class=${class:-missing} label=${label:-missing} source=${rest:-missing} reason=unknown-class"
      result=1
      continue
    fi
    if [[ -z "$label" || "$labels" == *"|$label|"* ]]; then
      fail "artifact class=$class label=${label:-missing} source=${rest:-missing} reason=duplicate-label"
      result=1
      continue
    fi
    labels+="$label|"
    if [[ "$class" == "committed" ]]; then
      local source extra
      IFS='|' read -r _ _ source extra <<< "$line"
      if [[ -z "$source" || -n "$extra" ]]; then
        fail "artifact class=$class label=$label source=${source:-missing} reason=registry-shape"
        result=1
      else
        printf '%s\n' "$line"
      fi
    else
      local producer start end extra
      IFS='|' read -r _ _ producer start end extra <<< "$line"
      if [[ -z "$producer" || -z "$start" || -z "$end" || -n "$extra" ]]; then
        fail "artifact class=$class label=$label producer=${producer:-missing} reason=registry-shape"
        result=1
      else
        printf '%s\n' "$line"
      fi
    fi
  done < <(artifact_registry)
  return "$result"
}

extract_generated() {
  local producer="$1" start="$2" end="$3" destination="$4" output rc
  output="$($BOOTSTRAP - "$producer" "$start" "$end" "$destination" 2>&1 <<'PY'
import pathlib
import sys

source = pathlib.Path(sys.argv[1])
start, end = sys.argv[2], sys.argv[3]
destination = pathlib.Path(sys.argv[4])
try:
    lines = source.read_text(encoding="utf-8").splitlines(keepends=True)
except (OSError, UnicodeError) as exc:
    print("missing: " + str(exc).splitlines()[0][:120])
    raise SystemExit(3)
starts = [index for index, line in enumerate(lines)
          if start in line and line.rstrip("\r\n") != end]
ends = [index for index, line in enumerate(lines) if line.rstrip("\r\n") == end]
if len(starts) != 1 or len(ends) != 1 or ends[0] <= starts[0]:
    print("marker-count: start=%d end=%d ordered=%s" %
          (len(starts), len(ends), bool(starts and ends and ends[0] > starts[0])))
    raise SystemExit(4)
body = b"".join(line.encode("utf-8") for line in lines[starts[0] + 1:ends[0]])
if not body:
    print("empty-artifact")
    raise SystemExit(5)
try:
    destination.write_bytes(body)
except OSError as exc:
    print("copy-failed: " + str(exc).splitlines()[0][:120])
    raise SystemExit(6)
PY
)"; rc=$?
  if [[ $rc -ne 0 ]]; then
    printf '%s' "${output:0:220}"
    return "$rc"
  fi
}

materialize_entry() {
  local line="$1" class label source start end destination output rc
  IFS='|' read -r class label source start end <<< "$line"
  destination="$TMP_ROOT/materialized/$label.py"
  mkdir -p -- "$(dirname "$destination")" || {
    fail "artifact class=$class label=$label source=$source reason=copy-failed"
    return 1
  }
  if [[ "$class" == "committed" ]]; then
    if [[ ! -e "$ROOT/$source" ]]; then
      fail "artifact class=$class label=$label source=$source reason=missing"
      return 1
    fi
    output="$(cp -- "$ROOT/$source" "$destination" 2>&1)"; rc=$?
    if [[ $rc -ne 0 ]]; then
      fail "artifact class=$class label=$label source=$source reason=copy-failed output=${output:0:120}"
      return 1
    fi
  else
    output="$(extract_generated "$ROOT/$source" "$start" "$end" "$destination" 2>&1)"; rc=$?
    if [[ $rc -ne 0 ]]; then
      local reason="marker-count"
      [[ "$output" == missing:* ]] && reason="missing"
      [[ "$output" == empty-artifact* ]] && reason="empty-artifact"
      [[ "$output" == copy-failed:* ]] && reason="copy-failed"
      fail "artifact class=$class label=$label producer=$source reason=$reason output=${output:0:160}"
      return 1
    fi
  fi
  printf '%s\n' "$destination"
}

compile_artifact() {
  local line="$1" path="$2" class label source _start _end
  local role index endpoint version output rc result=0 owner
  IFS='|' read -r class label source _start _end <<< "$line"
  [[ "$class" == "generated" ]] && owner="producer" || owner="source"
  for index in 0 1; do
    [[ $index -eq 0 ]] && role=oldest || role=newest
    endpoint="${ENDPOINT_PATHS[$index]}"
    version="${ENDPOINT_VERSIONS[$index]}"
    output="$("$endpoint" -W error::SyntaxWarning -m py_compile "$path" 2>&1)"; rc=$?
    if [[ $rc -eq 0 ]]; then
      ok "artifact class=$class label=$label $owner=$source role=$role path=$endpoint version=Python $version status=pass"
    else
      output="${output//$'\n'/ }"
      fail "artifact class=$class label=$label $owner=$source role=$role path=$endpoint version=Python $version reason=compile-failed output=${output:0:240}"
      result=1
    fi
  done
  return "$result"
}

run_artifacts() {
  local selection="$1" entries line class path result=0
  run_endpoints || return 1
  entries="$(registry_entries)" || { printf '%s\n' "$entries"; return 1; }
  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    class="${line%%|*}"
    if [[ "$selection" != "all" && "$selection" != "$class" ]]; then
      continue
    fi
    path="$(materialize_entry "$line")" || { printf '%s\n' "$path"; result=1; continue; }
    compile_artifact "$line" "$path" || result=1
  done <<< "$entries"
  return "$result"
}

assert_contains() {
  local text="$1" expected="$2" label="$3"
  [[ "$text" == *"$expected"* ]] && return 0
  printf '  assertion failed (%s): expected %s\n' "$label" "$expected"
  return 1
}

assert_not_contains() {
  local text="$1" unexpected="$2" label="$3"
  [[ "$text" != *"$unexpected"* ]] && return 0
  printf '  assertion failed (%s): unexpected %s\n' "$label" "$unexpected"
  return 1
}

record_case() {
  local name="$1"
  shift
  printf 'Case %s:\n' "$name"
  if "$@"; then printf '  pass\n'; else printf '  FAIL\n'; FAIL_COUNT=$((FAIL_COUNT + 1)); fi
}

write_contract() {
  local path="$1" schema="$2" implementation="$3" minimum="$4" maximum="$5"
  "$BOOTSTRAP" - "$path" "$schema" "$implementation" "$minimum" "$maximum" <<'PY'
import json
import sys
path, schema, implementation, minimum, maximum = sys.argv[1:]
with open(path, "w", encoding="utf-8") as stream:
    json.dump({"schema_version": int(schema), "implementation": implementation,
               "minimum_minor": minimum, "maximum_minor": maximum}, stream)
    stream.write("\n")
PY
}

write_fake() {
  local path="$1" implementation="$2" version="$3" version_rc="${4:-0}" identity_rc="${5:-0}"
  cat > "$path" <<EOF
#!/usr/bin/env bash
if [[ "\${1:-}" == "--version" ]]; then
  echo "Python $version"
  exit $version_rc
fi
if [[ "\${1:-}" == "-c" ]]; then
  printf '%s\\t%s\\n' '$implementation' '$version'
  exit $identity_rc
fi
exit 1
EOF
  chmod +x "$path"
}

invoke_inner() {
  local group="$1" contract="$2" oldest="$3" newest="$4" tmp_parent="$5"
  PYTHON_SUPPORT_FILE="$contract" PYTHON_OLDEST="$oldest" PYTHON_NEWEST="$newest" TMPDIR="$tmp_parent" bash "$SELF" "$group" 2>&1
}

case_contract_valid() {
  local d="$TMP_ROOT/contract-valid" out rc
  mkdir -p "$d/tmp"
  write_contract "$d/support.json" 1 CPython 3.9 3.14
  out="$(PYTHON_SUPPORT_FILE="$d/support.json" TMPDIR="$d/tmp" bash "$SELF" contract 2>&1)"; rc=$?
  [[ $rc -eq 0 ]] || return 1
  assert_contains "$out" "range=3.9..3.14" "declared range" && [[ -z "$(find "$d/tmp" -mindepth 1 -print -quit)" ]]
}

case_contract_invalids() {
  local d="$TMP_ROOT/contract-invalid" out rc result=0 name
  mkdir -p "$d/tmp"
  for name in missing malformed extra missing_field wrong_schema_type wrong_implementation_type wrong_minimum_type wrong_maximum_type non_minor equal inverted wrong_schema wrong_impl; do
    case "$name" in
      missing) rm -f "$d/value.json" ;;
      malformed) printf '{broken\n' > "$d/value.json" ;;
      extra) printf '{"schema_version":1,"implementation":"CPython","minimum_minor":"3.9","maximum_minor":"3.14","extra":true}\n' > "$d/value.json" ;;
      missing_field) printf '{"schema_version":1,"implementation":"CPython","minimum_minor":"3.9"}\n' > "$d/value.json" ;;
      wrong_schema_type) printf '{"schema_version":"1","implementation":"CPython","minimum_minor":"3.9","maximum_minor":"3.14"}\n' > "$d/value.json" ;;
      wrong_implementation_type) printf '{"schema_version":1,"implementation":9,"minimum_minor":"3.9","maximum_minor":"3.14"}\n' > "$d/value.json" ;;
      wrong_minimum_type) printf '{"schema_version":1,"implementation":"CPython","minimum_minor":3.9,"maximum_minor":"3.14"}\n' > "$d/value.json" ;;
      wrong_maximum_type) printf '{"schema_version":1,"implementation":"CPython","minimum_minor":"3.9","maximum_minor":3.14}\n' > "$d/value.json" ;;
      non_minor) write_contract "$d/value.json" 1 CPython 3.x 3.14 ;;
      equal) write_contract "$d/value.json" 1 CPython 3.14 3.14 ;;
      inverted) write_contract "$d/value.json" 1 CPython 3.14 3.9 ;;
      wrong_schema) write_contract "$d/value.json" 2 CPython 3.9 3.14 ;;
      wrong_impl) write_contract "$d/value.json" 1 PyPy 3.9 3.14 ;;
    esac
    out="$(PYTHON_SUPPORT_FILE="$d/value.json" TMPDIR="$d/tmp" bash "$SELF" contract 2>&1)"; rc=$?
    [[ $rc -ne 0 ]] || { echo "  $name unexpectedly passed"; result=1; }
    assert_contains "$out" "FAIL: $TAG contract" "$name bounded failure" || result=1
    assert_not_contains "$out" "Traceback" "$name no traceback" || result=1
  done
  [[ -z "$(find "$d/tmp" -mindepth 1 -print -quit)" ]] || result=1
  return "$result"
}

case_endpoints_valid() {
  local d="$TMP_ROOT/endpoints-valid" old new out rc result=0
  mkdir -p "$d/tmp" "$d/bin"
  write_contract "$d/support.json" 1 CPython 3.9 3.14
  old="$(command -v python3.9)" || return 1
  new="$(command -v python3.14)" || return 1
  ln -s "$old" "$d/bin/oldest"
  ln -s "$new" "$d/bin/newest"
  out="$(invoke_inner endpoints "$d/support.json" "$d/bin/oldest" "$d/bin/newest" "$d/tmp")"; rc=$?
  [[ $rc -eq 0 ]] || { printf '%s\n' "$out"; return 1; }
  assert_contains "$out" "role=oldest expected=3.9" "oldest identity" || result=1
  assert_contains "$out" "version=Python 3.9." "oldest full patch" || result=1
  assert_contains "$out" "role=newest expected=3.14" "newest identity" || result=1
  assert_contains "$out" "version=Python 3.14." "newest full patch" || result=1
  assert_contains "$out" "path=$(resolve_absolute "$old")" "oldest resolved symlink" || result=1
  assert_contains "$out" "path=$(resolve_absolute "$new")" "newest resolved symlink" || result=1
  [[ -z "$(find "$d/tmp" -mindepth 1 -print -quit)" ]] || result=1
  return "$result"
}

case_future_patch() {
  local d="$TMP_ROOT/future-patch" out rc
  mkdir -p "$d/tmp"
  write_contract "$d/support.json" 1 CPython 3.9 3.14
  write_fake "$d/old" CPython 3.9.99
  write_fake "$d/new" CPython 3.14.99
  out="$(invoke_inner endpoints "$d/support.json" "$d/old" "$d/new" "$d/tmp")"; rc=$?
  [[ $rc -eq 0 ]] && assert_contains "$out" "Python 3.9.99" "future oldest patch" && assert_contains "$out" "Python 3.14.99" "future newest patch"
}

case_endpoint_paths_with_spaces() {
  local d="$TMP_ROOT/endpoint paths with spaces" old new out rc result=0
  mkdir -p "$d/tmp" "$d/bin with spaces"
  write_contract "$d/support.json" 1 CPython 3.9 3.14
  old="$d/bin with spaces/python oldest"
  new="$d/bin with spaces/python newest"
  write_fake "$old" CPython 3.9.25
  write_fake "$new" CPython 3.14.6
  out="$(invoke_inner endpoints "$d/support.json" "$old" "$new" "$d/tmp")"; rc=$?
  [[ $rc -eq 0 ]] || return 1
  assert_contains "$out" "path=$(resolve_absolute "$old") version=Python 3.9.25" "oldest resolved path with spaces" || result=1
  assert_contains "$out" "path=$(resolve_absolute "$new") version=Python 3.14.6" "newest resolved path with spaces" || result=1
  return "$result"
}

case_endpoint_failures() {
  local d="$TMP_ROOT/endpoint-failures" out rc result=0 long_output long_run
  mkdir -p "$d/tmp"
  write_contract "$d/support.json" 1 CPython 3.9 3.14
  write_fake "$d/good-old" CPython 3.9.25
  write_fake "$d/good-new" CPython 3.14.6
  write_fake "$d/wrong-old" CPython 3.10.1
  write_fake "$d/wrong-new" CPython 3.13.1
  write_fake "$d/pypy-old" PyPy 3.9.25
  write_fake "$d/failing-old" CPython 3.9.25 7
  write_fake "$d/identity-failing-old" CPython 3.9.25 0 9
  long_output="$("$BOOTSTRAP" -c 'print("x" * 600)')"
  long_run="$("$BOOTSTRAP" -c 'print("x" * 130)')"
  write_fake "$d/unbounded-old" CPython "$long_output" 7
  printf '#!/usr/bin/env bash\nexit 0\n' > "$d/not-executable"

  out="$(PYTHON_SUPPORT_FILE="$d/support.json" PYTHON_OLDEST=relative/python PYTHON_NEWEST="$d/good-new" TMPDIR="$d/tmp" bash "$SELF" endpoints 2>&1)"; rc=$?
  [[ $rc -ne 0 ]] && assert_contains "$out" "override must be an absolute path" "relative override" || result=1
  out="$(invoke_inner endpoints "$d/support.json" "$d/missing" "$d/good-new" "$d/tmp")"; rc=$?
  [[ $rc -ne 0 ]] && assert_contains "$out" "role=oldest expected=3.9" "validate_missing_oldest_endpoint" && assert_contains "$out" "role=newest expected=3.14" "newest still reported" || result=1
  out="$(invoke_inner endpoints "$d/support.json" "$d/good-old" "$d/missing-new" "$d/tmp")"; rc=$?
  [[ $rc -ne 0 ]] && assert_contains "$out" "role=oldest expected=3.9" "oldest still reported" && assert_contains "$out" "role=newest expected=3.14" "validate_missing_newest_endpoint" || result=1
  out="$(invoke_inner endpoints "$d/support.json" "$d/not-executable" "$d/good-new" "$d/tmp")"; rc=$?
  [[ $rc -ne 0 ]] && assert_contains "$out" "not executable" "non-executable" || result=1
  out="$(invoke_inner endpoints "$d/support.json" "$d/failing-old" "$d/good-new" "$d/tmp")"; rc=$?
  [[ $rc -ne 0 ]] && assert_contains "$out" "--version failed" "failing version command" || result=1
  out="$(invoke_inner endpoints "$d/support.json" "$d/identity-failing-old" "$d/good-new" "$d/tmp")"; rc=$?
  [[ $rc -ne 0 ]] && assert_contains "$out" "identity probe failed" "failing identity command" || result=1
  out="$(invoke_inner endpoints "$d/support.json" "$d/unbounded-old" "$d/good-new" "$d/tmp")"; rc=$?
  [[ $rc -ne 0 ]] && assert_contains "$out" "--version failed" "bounded subprocess failure" && assert_not_contains "$out" "$long_run" "bounded subprocess output" || result=1
  out="$(invoke_inner endpoints "$d/support.json" "$d/pypy-old" "$d/good-new" "$d/tmp")"; rc=$?
  [[ $rc -ne 0 ]] && assert_contains "$out" "expected CPython" "wrong implementation" || result=1
  out="$(invoke_inner endpoints "$d/support.json" "$d/wrong-old" "$d/wrong-new" "$d/tmp")"; rc=$?
  [[ $rc -ne 0 ]] && assert_contains "$out" "actual=3.10" "wrong oldest minor" && assert_contains "$out" "actual=3.13" "wrong newest minor" || result=1
  assert_not_contains "$out" "Traceback" "no endpoint traceback" || result=1
  [[ -z "$(find "$d/tmp" -mindepth 1 -print -quit)" ]] || result=1
  return "$result"
}

make_fixture_repo() {
  local destination="$1"
  mkdir -p "$destination/scripts" "$destination/schemas" "$destination/skills/compound/scripts" "$destination/skills/planning/scripts" "$destination/skills/release-loop/scripts" "$destination/skills/implementing/scripts" "$destination/tmp"
  cp "$SELF" "$destination/scripts/test-python-compatibility.sh"
  cp "$ROOT/schemas/python-support.json" "$destination/schemas/python-support.json"
  cp "$ROOT/skills/compound/scripts/validate-frontmatter.py" "$destination/skills/compound/scripts/validate-frontmatter.py"
  cp "$ROOT/skills/planning/scripts/validate-plan-frontmatter.py" "$destination/skills/planning/scripts/validate-plan-frontmatter.py"
  cp "$ROOT/skills/release-loop/scripts/run-artifact-integrity.py" "$destination/skills/release-loop/scripts/run-artifact-integrity.py"
  cp "$ROOT/skills/implementing/scripts/phase-artifact-integrity.py" "$destination/skills/implementing/scripts/phase-artifact-integrity.py"
  cp "$ROOT/scripts/release-publication.sh" "$destination/scripts/release-publication.sh"
}

make_validation_fixture_repo() {
  local destination="$1" rel
  mkdir -p "$destination"
  while IFS= read -r -d '' rel; do
    mkdir -p "$destination/$(dirname "$rel")"
    cp "$ROOT/$rel" "$destination/$rel"
  done < <(git -C "$ROOT" ls-files -z)
  mkdir -p "$destination/skills/release-loop/scripts"
  cp "$ROOT/skills/release-loop/scripts/run-artifact-integrity.py" "$destination/skills/release-loop/scripts/run-artifact-integrity.py"
  mkdir -p "$destination/skills/implementing/scripts"
  cp "$ROOT/skills/implementing/scripts/phase-artifact-integrity.py" "$destination/skills/implementing/scripts/phase-artifact-integrity.py"
}

invoke_validation_fixture_repo() {
  local destination="$1"
  PYTHON_OLDEST="${PYTHON_OLDEST_OVERRIDE:-$(command -v python3.9)}" \
    PYTHON_NEWEST="${PYTHON_NEWEST_OVERRIDE:-$(command -v python3.14)}" \
    PYTHON_SUPPORT_FILE="${PYTHON_SUPPORT_OVERRIDE:-$destination/schemas/python-support.json}" \
    TMPDIR="$destination/tmp" bash "$destination/scripts/validate.sh" 2>&1
}

invoke_fixture_repo() {
  local destination="$1" group="${2:-all}"
  PYTHON_OLDEST="$(command -v python3.9)" PYTHON_NEWEST="$(command -v python3.14)" \
    TMPDIR="$destination/tmp" bash "$destination/scripts/test-python-compatibility.sh" "$group" 2>&1
}

replace_once() {
  "$BOOTSTRAP" - "$1" "$2" "$3" <<'PY'
import pathlib, sys
p=pathlib.Path(sys.argv[1]); old,new=sys.argv[2:]; text=p.read_text()
if text.count(old) < 1: raise SystemExit("replace_once count=0")
p.write_text(text.replace(old,new,1))
PY
}

case_real_artifacts_and_bytes() {
  local entries line path class source expected="$TMP_ROOT/expected-engine.py" count=0 result=0 out rc
  run_endpoints || return 1
  entries="$(registry_entries)" || return 1
  [[ "$entries" == *'committed|run-artifact-integrity-cli|skills/release-loop/scripts/run-artifact-integrity.py'* ]] || result=1
  [[ "$entries" == *'committed|phase-artifact-integrity-cli|skills/implementing/scripts/phase-artifact-integrity.py'* ]] || result=1
  while IFS= read -r line; do
    [[ -n "$line" ]] || continue; class="${line%%|*}"; path="$(materialize_entry "$line")" || return 1
    if [[ "$class" == committed ]]; then
      IFS='|' read -r _ _ source <<< "$line"
      cmp -s "$path" "$ROOT/$source" || result=1
    else
      awk '/<<'"'"'RELEASE_PUBLICATION_ENGINE_PY'"'"'/ { inside=1; next } /^RELEASE_PUBLICATION_ENGINE_PY$/ { exit } inside { print }' "$ROOT/scripts/release-publication.sh" > "$expected"
      cmp -s "$path" "$expected" || result=1
    fi
    out="$(compile_artifact "$line" "$path" 2>&1)"; rc=$?; [[ $rc -eq 0 ]] || { printf '%s\n' "$out"; result=1; }
    count=$((count + $(printf '%s\n' "$out" | grep -c 'status=pass')))
  done <<< "$entries"
  [[ $count -eq 10 ]] || { echo "  expected ten artifact pass records, got $count"; result=1; }
  return "$result"
}

case_registry_and_materialization_failures() {
  local base="$TMP_ROOT/registry failures" d out rc result=0 name
  mkdir -p "$base"
  for name in missing_source unknown_class duplicate_label missing_start duplicate_start missing_end duplicate_end reversed empty copy_failure; do
    d="$base/$name"; make_fixture_repo "$d"
    case "$name" in
      missing_source) rm "$d/skills/compound/scripts/validate-frontmatter.py" ;;
      unknown_class) replace_once "$d/scripts/test-python-compatibility.sh" 'committed|compound-frontmatter-validator|skills/compound/scripts/validate-frontmatter.py' 'mystery|compound-frontmatter-validator|skills/compound/scripts/validate-frontmatter.py' ;;
      duplicate_label) replace_once "$d/scripts/test-python-compatibility.sh" 'generated|release-publication-engine|scripts/release-publication.sh|RELEASE_PUBLICATION_ENGINE_PY|RELEASE_PUBLICATION_ENGINE_PY' $'generated|release-publication-engine|scripts/release-publication.sh|RELEASE_PUBLICATION_ENGINE_PY|RELEASE_PUBLICATION_ENGINE_PY\ncommitted|release-publication-engine|skills/compound/scripts/validate-frontmatter.py' ;;
      missing_start) replace_once "$d/scripts/release-publication.sh" "<<'RELEASE_PUBLICATION_ENGINE_PY'" "<<'MISSING_ENGINE_MARKER'" ;;
      duplicate_start) sed -i.bak "5i\\
python3 - <<'RELEASE_PUBLICATION_ENGINE_PY'" "$d/scripts/release-publication.sh"; rm "$d/scripts/release-publication.sh.bak" ;;
      missing_end) replace_once "$d/scripts/release-publication.sh" $'\nRELEASE_PUBLICATION_ENGINE_PY\n' $'\nMISSING_ENGINE_END\n' ;;
      duplicate_end) printf '\nRELEASE_PUBLICATION_ENGINE_PY\n' >> "$d/scripts/release-publication.sh" ;;
      reversed) replace_once "$d/scripts/release-publication.sh" $'\nRELEASE_PUBLICATION_ENGINE_PY\n' $'\nMISSING_ENGINE_END\n'; sed -i.bak '1i\
RELEASE_PUBLICATION_ENGINE_PY' "$d/scripts/release-publication.sh"; rm "$d/scripts/release-publication.sh.bak" ;;
      empty) "$BOOTSTRAP" - "$d/scripts/release-publication.sh" <<'PY'
import pathlib, sys
p=pathlib.Path(sys.argv[1]); lines=p.read_text().splitlines(True)
s=next(i for i,x in enumerate(lines) if "<<'RELEASE_PUBLICATION_ENGINE_PY'" in x)
e=next(i for i,x in enumerate(lines) if x.rstrip("\r\n") == "RELEASE_PUBLICATION_ENGINE_PY")
p.write_text("".join(lines[:s+1] + lines[e:]))
PY
        ;;
      copy_failure) rm "$d/skills/compound/scripts/validate-frontmatter.py"; mkdir "$d/skills/compound/scripts/validate-frontmatter.py" ;;
    esac
    out="$(invoke_fixture_repo "$d")"; rc=$?; [[ $rc -ne 0 ]] || { echo "  $name unexpectedly passed"; result=1; }
    assert_contains "$out" 'artifact class=' "$name owner" || result=1
    case "$name" in
      missing_source) assert_contains "$out" 'reason=missing' "$name reason" || result=1 ;;
      unknown_class) assert_contains "$out" 'reason=unknown-class' "$name reason" || result=1 ;;
      duplicate_label) assert_contains "$out" 'reason=duplicate-label' "$name reason" || result=1 ;;
      empty) assert_contains "$out" 'reason=empty-artifact' "$name reason" || result=1 ;;
      copy_failure) assert_contains "$out" 'reason=copy-failed' "$name reason" || result=1 ;;
      reversed) assert_contains "$out" 'marker-count: start=1 end=1 ordered=False' "$name exact reversed markers" || result=1 ;;
      *) assert_contains "$out" 'reason=marker-count' "$name reason" || result=1 ;;
    esac
    [[ -z "$(find "$d/tmp" -mindepth 1 -print -quit)" ]] || result=1
  done
  return "$result"
}

case_boundary_compile_failures() {
  local d="$TMP_ROOT/boundary compile" out rc result=0 count
  make_fixture_repo "$d/old syntax"
  printf '\nmatch 1:\n    case 1:\n        pass\n' >> "$d/old syntax/skills/compound/scripts/validate-frontmatter.py"
  out="$(invoke_fixture_repo "$d/old syntax" committed)"; rc=$?; [[ $rc -ne 0 ]] || result=1
  assert_contains "$out" 'label=compound-frontmatter-validator' 'old syntax label' || result=1
  assert_contains "$out" 'role=oldest' 'old syntax oldest' || result=1
  assert_contains "$out" 'reason=compile-failed' 'old syntax failure' || result=1
  assert_contains "$out" 'role=newest' 'old syntax newest still checked' || result=1
  assert_contains "$out" 'status=pass' 'old syntax newest pass' || result=1
  [[ $(printf '%s\n' "$out" | grep -c 'artifact class=committed.*reason=compile-failed') -eq 1 ]] || result=1
  [[ $(printf '%s\n' "$out" | grep -c 'label=compound-frontmatter-validator.*role=newest.*status=pass') -eq 1 ]] || result=1
  [[ -z "$(find "$d/old syntax/tmp" -mindepth 1 -print -quit)" ]] || result=1

  make_fixture_repo "$d/invalid escape"
  count="$(grep -F -c 'match=re.fullmatch(r"HTTP/(?:1\\.1|2(?:\\.0)?)' "$d/invalid escape/scripts/release-publication.sh")"
  [[ "$count" -eq 1 ]] || { echo "  invalid-escape precondition expected one match, got $count"; return 1; }
  replace_once "$d/invalid escape/scripts/release-publication.sh" \
    $'match=re.fullmatch(r"HTTP/(?:1\\\\.1|2(?:\\\\.0)?)' \
    $'match=re.fullmatch(r"HTTP/(?:1\\.1|2(?:\\.0)?)'
  out="$(invoke_fixture_repo "$d/invalid escape" generated)"; rc=$?; [[ $rc -ne 0 ]] || result=1
  assert_contains "$out" 'label=release-publication-engine' 'invalid escape label' || result=1
  assert_contains "$out" 'role=newest' 'invalid escape newest' || result=1
  assert_contains "$out" 'reason=compile-failed' 'invalid escape failure' || result=1
  [[ $(printf '%s\n' "$out" | grep -c 'artifact class=generated.*reason=compile-failed') -eq 1 ]] || result=1
  [[ $(printf '%s\n' "$out" | grep -c 'artifact class=generated.*role=oldest.*status=pass') -eq 1 ]] || result=1
  [[ -z "$(find "$d/invalid escape/tmp" -mindepth 1 -print -quit)" ]] || result=1
  return "$result"
}

case_additional_generated_registry_entry() {
  local d="$TMP_ROOT/additional generated registry" out rc
  make_fixture_repo "$d"
  printf '%s\n' '#!/usr/bin/env bash' "python3 - <<'FUTURE_GENERATED_PY'" 'print("future")' 'FUTURE_GENERATED_PY' > "$d/scripts/future producer.sh"
  replace_once "$d/scripts/test-python-compatibility.sh" 'generated|release-publication-engine|scripts/release-publication.sh|RELEASE_PUBLICATION_ENGINE_PY|RELEASE_PUBLICATION_ENGINE_PY' $'generated|release-publication-engine|scripts/release-publication.sh|RELEASE_PUBLICATION_ENGINE_PY|RELEASE_PUBLICATION_ENGINE_PY\ngenerated|future-generated|scripts/future producer.sh|FUTURE_GENERATED_PY|FUTURE_GENERATED_PY'
  out="$(invoke_fixture_repo "$d" generated)"; rc=$?; [[ $rc -eq 0 ]] || { printf '%s\n' "$out"; return 1; }
  assert_contains "$out" 'label=future-generated' 'future generated label' && [[ $(printf '%s\n' "$out" | grep -c 'label=future-generated.*status=pass') -eq 2 ]] && [[ -z "$(find "$d/tmp" -mindepth 1 -print -quit)" ]]
}

case_absolute_endpoint_overrides() {
  local d="$TMP_ROOT/absolute overrides" out rc
  make_fixture_repo "$d"; out="$(invoke_fixture_repo "$d" all)"; rc=$?
  [[ $rc -eq 0 ]] || { printf '%s\n' "$out"; return 1; }
  assert_contains "$out" "path=$(resolve_absolute "$(command -v python3.9)")" 'oldest absolute override' && assert_contains "$out" "path=$(resolve_absolute "$(command -v python3.14)")" 'newest absolute override'
}

case_validate_all_registered_artifacts() {
  local d="$TMP_ROOT/validate all registered" out rc result=0
  make_validation_fixture_repo "$d"
  mkdir -p "$d/tmp"
  out="$(invoke_validation_fixture_repo "$d")"; rc=$?
  [[ $rc -eq 0 ]] || { printf '%s\n' "$out"; return 1; }
  [[ $(printf '%s\n' "$out" | grep -c 'endpoint role=oldest') -eq 1 ]] || result=1
  [[ $(printf '%s\n' "$out" | grep -c 'endpoint role=newest') -eq 1 ]] || result=1
  [[ $(printf '%s\n' "$out" | grep -c 'artifact class=.*status=pass') -eq 10 ]] || result=1
  [[ $(printf '%s\n' "$out" | grep -c '^ALL CHECKS PASSED$') -eq 1 ]] || result=1
  assert_contains "$out" 'label=compound-frontmatter-validator' 'registered committed artifact' || result=1
  assert_contains "$out" 'label=plan-frontmatter-validator' 'registered committed artifact' || result=1
  assert_contains "$out" 'label=run-artifact-integrity-cli' 'registered committed artifact' || result=1
  assert_contains "$out" 'label=phase-artifact-integrity-cli' 'registered standalone implementing artifact' || result=1
  assert_contains "$out" 'label=release-publication-engine' 'registered generated artifact' || result=1
  [[ -z "$(find "$d/tmp" -mindepth 1 -print -quit)" ]] || result=1
  return "$result"
}

case_validate_missing_oldest_endpoint() {
  local d="$TMP_ROOT/validate missing oldest" out rc result=0
  make_validation_fixture_repo "$d"
  mkdir -p "$d/tmp"
  out="$(PYTHON_OLDEST_OVERRIDE="$d/missing-python" invoke_validation_fixture_repo "$d")"; rc=$?
  [[ $rc -ne 0 ]] || result=1
  assert_contains "$out" 'endpoint role=oldest expected=3.9' 'validation missing oldest' || result=1
  assert_contains "$out" 'endpoint role=newest expected=3.14' 'validation still checks newest' || result=1
  assert_contains "$out" 'CHECKS FAILED' 'validation aggregate failure' || result=1
  assert_not_contains "$out" 'ALL CHECKS PASSED' 'validation no false success' || result=1
  [[ -z "$(find "$d/tmp" -mindepth 1 -print -quit)" ]] || result=1
  return "$result"
}

case_invalid_outer_escape_fails_validation() {
  local d="$TMP_ROOT/validate invalid outer escape" out rc count result=0 before after
  make_validation_fixture_repo "$d"
  mkdir -p "$d/tmp"
  before="$(shasum -a 256 "$ROOT/scripts/release-publication.sh" | awk '{print $1}')"
  count="$(grep -F -c 'match=re.fullmatch(r"HTTP/(?:1\\.1|2(?:\\.0)?)' "$d/scripts/release-publication.sh")"
  [[ "$count" -eq 1 ]] || { echo "  invalid-escape precondition expected one match, got $count"; return 1; }
  replace_once "$d/scripts/release-publication.sh" \
    $'match=re.fullmatch(r"HTTP/(?:1\\\\.1|2(?:\\\\.0)?)' \
    $'match=re.fullmatch(r"HTTP/(?:1\\.1|2(?:\\.0)?)'
  out="$(invoke_validation_fixture_repo "$d")"; rc=$?
  [[ $rc -ne 0 ]] || result=1
  assert_contains "$out" 'label=release-publication-engine' 'validation invalid escape artifact' || result=1
  assert_contains "$out" 'role=newest' 'validation invalid escape newest' || result=1
  assert_contains "$out" 'reason=compile-failed' 'validation invalid escape failure' || result=1
  [[ $(printf '%s\n' "$out" | grep -c 'artifact class=generated.*role=newest.*reason=compile-failed') -eq 1 ]] || result=1
  [[ $(printf '%s\n' "$out" | grep -c 'artifact class=generated.*role=oldest.*status=pass') -eq 1 ]] || result=1
  assert_contains "$out" 'CHECKS FAILED' 'invalid escape aggregate failure' || result=1
  after="$(shasum -a 256 "$ROOT/scripts/release-publication.sh" | awk '{print $1}')"
  [[ "$before" == "$after" ]] || result=1
  [[ -z "$(find "$d/tmp" -mindepth 1 -print -quit)" ]] || result=1
  return "$result"
}

case_publication_delegates_generated_group() {
  local body
  body="$(sed -n '/^case_embedded_engine_syntax_warnings()/,/^}/p' "$ROOT/scripts/test-release-publication.sh")"
  [[ $(printf '%s\n' "$body" | grep -F -c 'bash "$ROOT/scripts/test-python-compatibility.sh" generated') -eq 1 ]] || return 1
  assert_not_contains "$body" 'py_compile' 'publication no local compile' && \
    assert_not_contains "$body" 'RELEASE_PUBLICATION_ENGINE_PY' 'publication no local extraction'
}

run_fixtures() {
  record_case contract_valid case_contract_valid
  record_case contract_invalids case_contract_invalids
  record_case endpoints_valid case_endpoints_valid
  record_case endpoint_future_patch case_future_patch
  record_case endpoint_paths_with_spaces case_endpoint_paths_with_spaces
  record_case validate_missing_oldest_endpoint_and_failures case_endpoint_failures
  record_case real_artifacts_and_exact_bytes case_real_artifacts_and_bytes
  record_case registry_and_materialization_failures case_registry_and_materialization_failures
  record_case boundary_compile_failures case_boundary_compile_failures
  record_case absolute_endpoint_overrides case_absolute_endpoint_overrides
  record_case additional_generated_registry_entry case_additional_generated_registry_entry
  record_case validate_all_registered_artifacts case_validate_all_registered_artifacts
  record_case validate_missing_oldest_endpoint case_validate_missing_oldest_endpoint
  record_case invalid_outer_escape_fails_validation case_invalid_outer_escape_fails_validation
  record_case publication_delegates_generated_group case_publication_delegates_generated_group
  if [[ $FAIL_COUNT -eq 0 ]]; then
    printf 'All python compatibility fixture cases passed.\n'
    return 0
  fi
  printf '%s python compatibility fixture case(s) failed.\n' "$FAIL_COUNT"
  return 1
}

usage() {
  printf 'usage: bash scripts/test-python-compatibility.sh <contract|endpoints|committed|generated|all|fixtures>\n' >&2
}

make_tmp_root || exit 1
case "${1:-}" in
  contract) run_contract ;;
  endpoints) run_endpoints ;;
  committed) run_artifacts committed ;;
  generated) run_artifacts generated ;;
  all) run_artifacts all ;;
  fixtures) run_fixtures ;;
  *) usage; exit 2 ;;
esac
