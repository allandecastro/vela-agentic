#!/bin/sh
# vela-agentic apply-guard (dual-target: Claude Code + GitHub Copilot).
# Blocks `vela apply` / `--auto-approve` / `--yes` unless VELA_APPLY_APPROVED=1.
# Wired as a PreToolUse (Claude Code) / preToolUse (Copilot) hook on the shell tool.
# Deny is host-agnostic: exit 2 denies on BOTH hosts.
#
# Usage: guard.sh <host>   where host = cc (Claude Code) | cp (Copilot)
# Reads the hook payload JSON on stdin. Requires `jq`.
host="$1"
input="$(cat)"

case "$host" in
  cp) cmd="$(printf '%s' "$input" | jq -r '.toolArgs.command // .toolArgs.cmd // empty' 2>/dev/null)" ;;
  *)  cmd="$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)" ;;
esac

# Not an apply / auto-approve command -> allow.
printf '%s\n' "$cmd" | grep -Eq 'vela[[:space:]]+([^;&|]*[[:space:]])?apply([[:space:]]|$)|--auto-approve|--yes([[:space:]]|$)' || exit 0

# Explicit human approval bypasses the guard for this run.
[ "$VELA_APPLY_APPROVED" = "1" ] && exit 0

echo 'Blocked by vela-agentic: "vela apply" writes to a live org. A human must approve by setting VELA_APPLY_APPROVED=1 (stop-before-apply).' >&2
exit 2
