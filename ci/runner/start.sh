#!/bin/sh
# Runs the self-hosted runner in a container on this machine, one job per container, until stopped (Ctrl-C).
#   sh ci/runner/start.sh                 # Apple `container` (macOS 26); RUNTIME=docker for Docker
# Needs `gh` signed in with admin rights on the repo (it fetches a short-lived registration token per job).
# The workflows run here when the repo variable RUNS_ON is '["self-hosted","linux"]' (unset: GitHub-hosted).
set -e
REPO="${REPO:-allandecastro/vela-agentic}"
RUNTIME="${RUNTIME:-container}"
IMAGE="vela-agentic-runner"
cd "$(dirname "$0")"
"$RUNTIME" build -t "$IMAGE" . >/dev/null
echo "runner image built - waiting for jobs on $REPO (Ctrl-C to stop)"
trap 'exit 0' INT TERM
while :; do
  token="$(gh api -X POST "repos/$REPO/actions/runners/registration-token" --jq .token)"
  "$RUNTIME" run --rm -e REPO="$REPO" -e RUNNER_TOKEN="$token" "$IMAGE" || sleep 10
done
