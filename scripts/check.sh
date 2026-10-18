#!/bin/sh
# Local replay of the CI (.github/workflows/ci.yml) - run before every push.
#   sh scripts/check.sh
# Fails on: lint errors, invalid JSON configs, shell syntax, guard test failures, or generated
# surfaces (.github/, skills/*/references/, hooks.json, evals coverage) out of sync with the source.
set -e
cd "$(dirname "$0")/.."

node scripts/lint-pack.mjs

for f in .claude-plugin/marketplace.json .claude-plugin/plugin.json hooks/hooks.json hooks.json .github/hooks/vela.json .github/copilot/settings.json; do
  node -e "JSON.parse(require('fs').readFileSync('$f','utf8'))" || { echo "invalid JSON: $f"; exit 1; }
done

for s in hooks/bin/*.sh hooks/test/*.sh scripts/*.sh evals/setup/*.sh; do sh -n "$s"; done
for p in evals/checks/check.py evals/tools/brief.py; do python3 -m py_compile "$p"; done
for j in evals/checks/*.json; do node -e "JSON.parse(require('fs').readFileSync('$j','utf8'))" || { echo "invalid JSON: $j"; exit 1; }; done

sh hooks/test/guard.test.sh
sh hooks/test/spec-guard.test.sh

node scripts/sync-copilot.mjs >/dev/null
if [ -n "$(git status --porcelain -- .github/skills .github/agents .github/hooks .github/copilot .github/copilot-instructions.md skills hooks.json evals/README.md)" ]; then
  git status --porcelain -- .github/skills .github/agents .github/hooks .github/copilot .github/copilot-instructions.md skills hooks.json evals/README.md
  echo "generated files are out of sync - run 'node scripts/sync-copilot.mjs' and commit"
  exit 1
fi
echo "check: all green"
