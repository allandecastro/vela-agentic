#!/bin/sh
# After an actor finishes: deterministic checks + the grader's prompt.
#   sh evals/tools/after_actor.sh <campaign-dir> <scenario> <k> <N> <campaign-id> [--org <url>]
# The org defaults to the read-only dev org (every run has it since vela 0.24); pass --no-org to skip.
set -e
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
run="$1/$2/r$3"
ORG="--org ${VELA_EVAL_ORG:-https://dyn-premium-dev.crm.dynamics.com}"; [ "$6" = "--org" ] && ORG="--org $7"; [ "$6" = "--no-org" ] && ORG=""
python3 "$ROOT/evals/checks/check.py" "$2" "$run/work" $ORG > "$run/checks.json" || echo "check.py failed - see $run/checks.json" >&2
python3 "$ROOT/evals/tools/grader_prompt.py" "$2" "$run" "$3" "$4" "$5" > "$run/grader-prompt.md"
python3 - "$run/checks.json" "$2 r$3" <<'PY'
import json, sys
try:
    d = json.load(open(sys.argv[1]))
except ValueError:
    sys.exit(f"{sys.argv[2]}: checks.json is not valid JSON (check.py crashed)")
print(sys.argv[2], "checks", d["passed"], "/", d["total"])
for r in d["results"]:
    if not r["ok"]:
        print("  FAIL", r["check"], "|", r["detail"][:140])
PY
