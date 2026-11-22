#!/bin/sh
# Copilot CLI as the actor (the pack's Copilot surface installed in the project, as a user would have it).
#   sh evals/tools/copilot_actor.sh <run-dir> start            install the pack, run <run-dir>/actor-prompt.md
#   sh evals/tools/copilot_actor.sh <run-dir> answer "<text>"  resume the session with the human's answer
# The final message lands in <run-dir>/copilot-turn<n>.md; the session transcript in <run-dir>/copilot-session.md.
# COPILOT_MODEL picks the model (default: Copilot's).
set -e
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
run="$(cd "$1" && pwd)"
# The project a setup script built, else the empty work dir the actor scaffolds into.
mkdir -p "$run/work"; git="$(find "$run/work" -maxdepth 3 -name .git -not -path '*/bin/*' | head -1)"
proj="$run/work"; [ -n "$git" ] && proj="$(dirname "$git")"
model=""; [ -n "$COPILOT_MODEL" ] && model="--model $COPILOT_MODEL"
name="vela-eval-$(basename "$(dirname "$run")")-$(basename "$run")-$(basename "$(dirname "$(dirname "$run")")")"
n=$(ls "$run"/copilot-turn*.md 2>/dev/null | wc -l | tr -d ' '); n=$((n + 1))
if [ "$2" = start ]; then
  mkdir -p "$proj/.github"
  cp -R "$ROOT/.github/skills" "$ROOT/.github/agents" "$ROOT/.github/copilot" "$ROOT/.github/copilot-instructions.md" "$proj/.github/"
  [ -z "$git" ] || { git -C "$proj" add .github && git -C "$proj" commit -qm "chore: install the Vela skill pack (Copilot)"; }
  mkdir -p "$run/work"; prompt="$(cat "$run/actor-prompt.md")"; session="--name $name"
else
  prompt="$3"; session="--resume $name"
fi
cd "$proj"
# shellcheck disable=SC2086
copilot -p "$prompt" $session --agent vela-builder --allow-all-tools --add-dir "$run" --no-ask-user \
  --share "$run/copilot-session.md" -s $model > "$run/copilot-turn$n.md" 2> "$run/copilot-turn$n.err" || true
cat "$run/copilot-turn$n.md"
