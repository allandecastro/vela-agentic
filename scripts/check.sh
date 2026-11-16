#!/bin/sh
# Local replay of the CI (.github/workflows/ci.yml) - run before every push.
#   sh scripts/check.sh
# Fails on: lint errors, invalid JSON configs, shell syntax, guard test failures, a secret (gitleaks), or generated
# surfaces (.github/, skills/*/references/, hooks.json, evals coverage) out of sync with the source.
set -e
cd "$(dirname "$0")/.."

node scripts/lint-pack.mjs

for f in .claude-plugin/marketplace.json .claude-plugin/plugin.json hooks/hooks.json hooks.json .github/hooks/vela.json .github/copilot/settings.json; do
  node -e "JSON.parse(require('fs').readFileSync('$f','utf8'))" || { echo "invalid JSON: $f"; exit 1; }
done

for s in hooks/bin/*.sh hooks/test/*.sh scripts/*.sh evals/setup/*.sh evals/tools/*.sh evals/tools/shim/vela .githooks/pre-push; do sh -n "$s"; done
for p in evals/checks/check.py evals/tools/*.py; do python3 -c "import ast,sys; ast.parse(open(sys.argv[1]).read())" "$p"; done
for j in evals/checks/*.json; do node -e "JSON.parse(require('fs').readFileSync('$j','utf8'))" || { echo "invalid JSON: $j"; exit 1; }; done

sh hooks/test/guard.test.sh

# spec-check fixture tests (CI always; locally when the .NET SDK is present - the first run compiles).
if command -v dotnet >/dev/null 2>&1; then
  out="$(bash tools/spec-check.test.sh 2>&1)" || { echo "$out"; exit 1; }
  echo "$out" | tail -1
else echo "dotnet not installed - spec-check tests skipped (CI runs them)"; fi

# Secret scan of the whole history (.gitleaks.toml); CI always runs it, locally only when gitleaks is installed.
if command -v gitleaks >/dev/null 2>&1; then
  gitleaks git --no-banner --redact --log-level warn . || { echo "gitleaks: secret found - see above"; exit 1; }
else
  echo "gitleaks not installed - secret scan skipped (CI runs it)"
fi

node scripts/sync-copilot.mjs >/dev/null
if [ -n "$(git status --porcelain -- .github/skills .github/agents .github/hooks .github/copilot .github/copilot-instructions.md skills hooks.json evals/README.md)" ]; then
  git status --porcelain -- .github/skills .github/agents .github/hooks .github/copilot .github/copilot-instructions.md skills hooks.json evals/README.md
  echo "generated files are out of sync - run 'node scripts/sync-copilot.mjs' and commit"
  exit 1
fi
echo "check: all green"
