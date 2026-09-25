#!/bin/sh
# vela-agentic run-trace logger (dual-target: Claude Code + GitHub Copilot).
# Appends every vela/dotnet/mono shell command to a run-trace log, so the run is
# auditable even if the agent does not write the Build Report's Run trace table.
# Wired as a PostToolUse (Claude Code) / postToolUse (Copilot) hook on the shell tool.
# Post-hooks cannot block; this is observability only.
#
# Usage: trace.sh <host>   where host = cc | cp
# Reads the hook payload JSON on stdin. Requires `jq`.
# Log location: $VELA_TRACE_DIR/run-trace.log (default ./.vela, falls back to ~/.vela).
host="$1"
input="$(cat)"

case "$host" in
  cp) cmd="$(printf '%s' "$input" | jq -r '.toolArgs.command // .toolArgs.cmd // empty' 2>/dev/null)" ;;
  *)  cmd="$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)" ;;
esac

[ -n "$cmd" ] || exit 0
printf '%s\n' "$cmd" | grep -Eq '(^|[[:space:]/])(vela|dotnet|mono)([[:space:]]|$)' || exit 0

dir="${VELA_TRACE_DIR:-.vela}"
mkdir -p "$dir" 2>/dev/null || { dir="$HOME/.vela"; mkdir -p "$dir" 2>/dev/null; }
printf '%s\t%s\t%s\n' "$(date -u +%FT%TZ)" "$host" "$cmd" >> "$dir/run-trace.log"
exit 0
