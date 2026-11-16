#!/bin/sh
# Registers an ephemeral runner (one job, then it exits and the start script registers a fresh one).
set -e
cd /home/runner/actions-runner
./config.sh --unattended --ephemeral --replace \
  --url "https://github.com/$REPO" --token "$RUNNER_TOKEN" \
  --name "${RUNNER_NAME:-vela-agentic-container}" --labels "${RUNNER_LABELS:-self-hosted,linux,container}" >/dev/null
exec ./run.sh
