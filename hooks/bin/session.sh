#!/bin/sh
# version: 0.1.0
# vela-agentic session hook: at session start, tells the agent which vela CLI is installed against the version the
# skills were verified with (AGENTS.md golden rule 2). Prints context on stdout; never blocks (always exit 0).
# POSIX sh + grep + sort only.
#
# Usage: session.sh <references/cli-surface.md | x.y.z>
want="$1"
[ -f "$want" ] && want="$(grep -m1 -oE 'Verified against:\*\* `vela [0-9]+\.[0-9]+\.[0-9]+' "$want" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+$')"
vela=vela; command -v vela >/dev/null 2>&1 || vela="$HOME/.dotnet/tools/vela"
have="$("$vela" version 2>/dev/null | grep -m1 -oE '[0-9]+\.[0-9]+\.[0-9]+')"
if [ -z "$have" ]; then
  echo "vela-agentic: the vela CLI is not installed (dotnet tool install --global Vela.Cli) - Vela work needs it; say so and stop."
elif [ -n "$want" ] && [ "$have" != "$want" ] \
     && [ "$(printf '%s\n%s\n' "$have" "$want" | sort -t. -k1,1n -k2,2n -k3,3n | head -1)" = "$have" ]; then
  echo "vela-agentic: vela CLI $have is older than $want, the version the skills were verified against - tell the user to run \`vela update\`; stop only if a feature the task needs is missing."
else
  echo "vela-agentic: vela CLI $have (skills verified against ${want:-an unknown version})."
fi
exit 0
