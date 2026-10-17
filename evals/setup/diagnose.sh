#!/bin/sh
# Starting point of diagnose-failed-run: a real failed builder run (campaign 2026-10-17c, account-erp-outbound
# r3, trimmed: no bin/obj/artifacts/generated models) and the skill pack as it was when that run happened.
#   sh evals/setup/diagnose.sh <work-dir>  -> <work-dir>/run (the run), <work-dir>/pack (skills at 316cc0c)
set -e
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
mkdir -p "$1/run" "$1/pack"
cp -R "$ROOT/evals/fixtures/erp-run-2026-10-17c-r3/." "$1/run/"
git -C "$ROOT" archive 316cc0c skills references agents AGENTS.md | tar -x -C "$1/pack"
echo "$1"
