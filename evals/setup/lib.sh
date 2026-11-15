#!/bin/sh
# Shared helpers for deterministic eval setups (the evaluator prepares the starting point; the acting
# agent only gets the project + the story). Requires vela, dotnet, python3, git.
set -e
export PATH="$HOME/.dotnet/tools:$PATH"

# The dev org the evaluator reads models from (read-only); every campaign run gets it read-only too.
DEV_ORG="${VELA_EVAL_ORG:-https://dyn-premium-dev.crm.dynamics.com}"

# new_solution <dir> <Name> <prefix>  -> minimal scaffold (vela >= 0.24: no demos) + account/contact models
# generated from the dev org (read-only). <prefix> is used for both the namespace and the publisher prefix.
new_solution() {
  mkdir -p "$1"
  vela init --name "$2" --prefix "$3" --publisher-prefix "$3" --solution "$2" --output "$1" >/dev/null
  sol="$1/$2"
  ( cd "$sol" && vela models --entities account,contact --project "src/$3.Shared/$3.Shared.csproj" \
      --url "$DEV_ORG" --overwrite >/dev/null )
  echo "$sol"
}

commit() { ( cd "$1" && git init -q 2>/dev/null; git add -A && git -c user.name=eval -c user.email=eval@local commit -q -m "$2" ); }
