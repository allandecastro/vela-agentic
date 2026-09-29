#!/bin/sh
# After an actor finishes: deterministic checks + the grader's prompt.
#   sh evals/tools/after_actor.sh <campaign-dir> <scenario> <k> <N> <campaign-id> [--org <url>]
set -e
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
run="$1/$2/r$3"
python3 "$ROOT/evals/checks/check.py" "$2" "$run/work" $6 $7 > "$run/checks.json" || true
python3 "$ROOT/evals/tools/grader_prompt.py" "$2" "$run" "$3" "$4" "$5" > "$run/grader-prompt.md"
python3 -c "import json,sys;d=json.load(open('$run/checks.json'));print('$2 r$3 checks',d['passed'],'/',d['total']);[print('  FAIL',r['check'],'|',r['detail'][:140]) for r in d['results'] if not r['ok']]"
