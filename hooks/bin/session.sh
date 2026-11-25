#!/bin/sh
# version: 0.1.1
# vela-agentic session hook: at session start, tells the agent which vela CLI is installed against the version the
# skills were verified with (AGENTS.md golden rule 2: an older minor stops the run, an older patch warns). Prints
# context on stdout; never blocks itself (always exit 0). POSIX sh + grep + sort only.
#
# Usage: session.sh <references/cli-surface.md | x.y.z>
want="$1"
[ -f "$want" ] && want="$(grep -m1 -oE 'Verified against:\*\* `vela [0-9]+\.[0-9]+\.[0-9]+' "$want" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+$')"
vela=vela; command -v vela >/dev/null 2>&1 || vela="$HOME/.dotnet/tools/vela"
have="$("$vela" --version 2>/dev/null | grep -m1 -oE '[0-9]+\.[0-9]+\.[0-9]+')"
older() { [ "$1" != "$2" ] && [ "$(printf '%s\n%s\n' "$1" "$2" | sort -t. -k1,1n -k2,2n -k3,3n | head -1)" = "$1" ]; }
if [ -z "$have" ]; then
  echo "vela-agentic: the vela CLI is not installed (dotnet tool install --global Vela.Cli) - Vela work needs it; say so and stop."
elif [ -n "$want" ] && older "${have%.*}.0" "${want%.*}.0"; then
  echo "vela-agentic: vela CLI $have is older than $want, the version the skills were verified against (an older minor or major) - stop and tell the user to run \`vela update\`."
elif [ -n "$want" ] && older "$have" "$want"; then
  echo "vela-agentic: vela CLI $have is older than $want, the version the skills were verified against (an older patch) - warn the user (\`vela update\`) and continue."
else
  echo "vela-agentic: vela CLI $have (skills verified against ${want:-an unknown version})."
fi
exit 0
