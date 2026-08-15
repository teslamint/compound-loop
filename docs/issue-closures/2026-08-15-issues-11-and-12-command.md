Preparation evidence — first-hand consent still required. This file authorizes no command.

Target: `teslamint/compound-loop`, issues `#11` and `#12`.

```bash
set -euo pipefail
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
PAYLOAD_11="$TMP/issue-11.md"
PAYLOAD_12="$TMP/issue-12.md"
git show HEAD:docs/issue-closures/2026-08-15-issue-11.md > "$PAYLOAD_11"
git show HEAD:docs/issue-closures/2026-08-15-issue-12.md > "$PAYLOAD_12"
cmp -s docs/issue-closures/2026-08-15-issue-11.md "$PAYLOAD_11"
cmp -s docs/issue-closures/2026-08-15-issue-12.md "$PAYLOAD_12"
python3 -I - "$PAYLOAD_11" "$PAYLOAD_12" <<'PY'
from hashlib import sha256
from pathlib import Path
import sys
if sys.flags.optimize:
    raise SystemExit("optimized Python is forbidden for packet verification")
pins = (
    (Path(sys.argv[1]), "18946ff5f0d3ef25a0495bdcfdd82f49999c69ca84603a9f5583540ccee1919f"),
    (Path(sys.argv[2]), "6bbf1e73b146a0e2bbb4a20ff7349b6000ccf31e713d5060cb5a41e7c5a4ee2c"),
)
for path, expected in pins:
    actual = sha256(path.read_bytes()).hexdigest()
    if actual != expected:
        raise SystemExit(f"payload hash mismatch: {path}")
PY
comment_status() {
  issue=$1
  payload=$2
  snapshot="$TMP/$issue-before-comment.json"
  if ! gh issue view "$issue" --repo teslamint/compound-loop --json state,comments > "$snapshot"; then
    echo "issue comment-state read failed" >&2
    return 2
  fi
  python3 -I - "$snapshot" "$payload" <<'PY'
import json
from pathlib import Path
import sys
if sys.flags.optimize:
    raise SystemExit("optimized Python is forbidden for packet verification")
result = json.loads(Path(sys.argv[1]).read_text())
payload = Path(sys.argv[2]).read_text().rstrip("\n")
print("present" if any(comment["body"].rstrip("\n") == payload for comment in result["comments"]) else "absent")
PY
}
issue_state() {
  issue=$1
  snapshot="$TMP/$issue-before-close.json"
  if ! gh issue view "$issue" --repo teslamint/compound-loop --json state > "$snapshot"; then
    echo "issue state read failed" >&2
    return 2
  fi
  python3 -I - "$snapshot" <<'PY'
import json
from pathlib import Path
import sys
if sys.flags.optimize:
    raise SystemExit("optimized Python is forbidden for packet verification")
print(json.loads(Path(sys.argv[1]).read_text())["state"])
PY
}
status_11=$(comment_status 11 "$PAYLOAD_11")
state_11=$(issue_state 11)
status_12=$(comment_status 12 "$PAYLOAD_12")
state_12=$(issue_state 12)
case "$status_11" in
  present|absent) ;;
  *) exit 1 ;;
esac
case "$state_11" in
  CLOSED|OPEN) ;;
  *) exit 1 ;;
esac
case "$status_12" in
  present|absent) ;;
  *) exit 1 ;;
esac
case "$state_12" in
  CLOSED|OPEN) ;;
  *) exit 1 ;;
esac
case "$status_11" in
  present) ;;
  absent) gh issue comment 11 --repo teslamint/compound-loop --body-file "$PAYLOAD_11" ;;
esac
case "$state_11" in
  CLOSED) ;;
  OPEN) gh issue close 11 --repo teslamint/compound-loop ;;
esac
case "$status_12" in
  present) ;;
  absent) gh issue comment 12 --repo teslamint/compound-loop --body-file "$PAYLOAD_12" ;;
esac
case "$state_12" in
  CLOSED) ;;
  OPEN) gh issue close 12 --repo teslamint/compound-loop ;;
esac
gh issue view 11 --repo teslamint/compound-loop --json state,comments > "$TMP/11.json"
gh issue view 12 --repo teslamint/compound-loop --json state,comments > "$TMP/12.json"
python3 -I - "$TMP/11.json" "$PAYLOAD_11" "$TMP/12.json" "$PAYLOAD_12" <<'PY'
import json
from pathlib import Path
import sys
if sys.flags.optimize:
    raise SystemExit("optimized Python is forbidden for packet verification")
for result_path, payload_path in zip(sys.argv[1::2], sys.argv[2::2]):
    result = json.loads(Path(result_path).read_text())
    payload = Path(payload_path).read_text().rstrip("\n")
    if result["state"] != "CLOSED":
        raise SystemExit(f"issue not closed: {result_path}")
    if not any(comment["body"].rstrip("\n") == payload for comment in result["comments"]):
        raise SystemExit(f"exact payload absent: {result_path}")
PY
```
