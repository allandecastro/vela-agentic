#!/bin/sh
# Ablation only: strip the skill pack's own conventions from a set-up project so neither arm starts from them
# (no docs/rules, no docs/features, no [Trait("Case", ...)] on tests). Committed as a plain project commit.
#   sh evals/setup/neutralize.sh <work-dir>
set -eu
for repo in "$1"/*/; do
  [ -d "$repo/.git" ] || continue
  cd "$repo"
  rm -rf docs/rules docs/features
  [ -d docs ] && [ -z "$(ls -A docs)" ] && rmdir docs
  find tests -name '*.cs' -exec perl -0pi -e 's/,\s*Trait\("Case",\s*"[^"]*"\)//g; s/\[Trait\("Case",\s*"[^"]*"\)\]\s*//g' {} +
  git add -A && git commit -qm "chore: project files" || true
  cd - >/dev/null
done
