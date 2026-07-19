#!/usr/bin/env bash
# Validate the declared CPython compatibility contract and its boundary endpoints.
# This file is both the focused gate and its disposable fixture harness. Stdlib only.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SELF="$ROOT/scripts/test-python-compatibility.sh"
CONTRACT="${PYTHON_SUPPORT_FILE:-$ROOT/schemas/python-support.json}"
BOOTSTRAP="${PYTHON_BOOTSTRAP:-python3}"
TAG="[python-compat]"
TMP_ROOT=""
FAIL_COUNT=0
CONTRACT_VALUES=()

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

  version_text="$($resolved --version 2>&1)"; rc=$?
  version_text="${version_text//$'\n'/ }"
  if [[ $rc -ne 0 ]]; then
    fail "endpoint role=$role expected=$expected path=$resolved reason=--version failed output=${version_text:0:120}"
    return 1
  fi
  identity="$($resolved -c 'import platform,sys; print(platform.python_implementation()+"\t"+platform.python_version())' 2>&1)"; rc=$?
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
  ok "endpoint role=$role expected=$expected path=$resolved version=Python $full_version"
}

run_contract() {
  validate_contract
}

run_endpoints() {
  local result=0
  validate_contract || return 1
  resolve_endpoint oldest "${CONTRACT_VALUES[2]}" "${PYTHON_OLDEST:-}" || result=1
  resolve_endpoint newest "${CONTRACT_VALUES[3]}" "${PYTHON_NEWEST:-}" || result=1
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

run_fixtures() {
  record_case contract_valid case_contract_valid
  record_case contract_invalids case_contract_invalids
  record_case endpoints_valid case_endpoints_valid
  record_case endpoint_future_patch case_future_patch
  record_case validate_missing_oldest_endpoint_and_failures case_endpoint_failures
  if [[ $FAIL_COUNT -eq 0 ]]; then
    printf 'All python compatibility fixture cases passed.\n'
    return 0
  fi
  printf '%s python compatibility fixture case(s) failed.\n' "$FAIL_COUNT"
  return 1
}

usage() {
  printf 'usage: bash scripts/test-python-compatibility.sh <contract|endpoints|fixtures>\n' >&2
}

make_tmp_root || exit 1
case "${1:-}" in
  contract) run_contract ;;
  endpoints) run_endpoints ;;
  fixtures) run_fixtures ;;
  *) usage; exit 2 ;;
esac
