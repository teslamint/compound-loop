#!/usr/bin/env bash
# C2-TI fixture evaluator. The contract mode is the first RED test for U1.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODE="${1:-dogfood}"

if [[ "$MODE" != "contract" ]]; then
  echo "C2-TI RED: dogfood evaluator is not implemented yet" >&2
  exit 1
fi

python3 - "$ROOT/skills/reviewing/references/lanes.md" <<'PY'
import sys
from pathlib import Path

lane_path = Path(sys.argv[1])
text = lane_path.read_text(encoding="utf-8")
required = (
    "test-integrity",
    "network isolation",
    "shared temporary directories",
    "verifier fail-open behavior",
    "assertion specificity",
    "hidden environment dependencies",
    "fixture Git signing/hooks",
    "schemas/lane-findings.schema.json",
    "references/merge-pipeline.md",
)
missing = [item for item in required if item not in text]
if missing:
    raise SystemExit("C2-TI contract missing: " + ", ".join(missing))
print("C2-TI contract present")
PY
