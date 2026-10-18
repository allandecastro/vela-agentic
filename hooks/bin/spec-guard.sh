#!/bin/sh
# vela-agentic spec-guard (dual-target: Claude Code + GitHub Copilot).
# The rules registry (docs/rules/**) is the functional spec of the tests: it may change only in the design
# phase, with the human. Any write to it - an Edit/Write/MultiEdit on a docs/rules/ path, or a shell command
# that writes there - is:
#   - Claude Code: sent to the human for confirmation (permissionDecision "ask");
#   - Copilot (no ask): denied (exit 2).
# A host started with VELA_SPEC_EDIT=1 (a design session the human runs) is allowed. Reads are always allowed.
#
# Usage: spec-guard.sh <host>   where host = cc (Claude Code) | cp (Copilot). Reads the hook JSON on stdin.
host="$1"
input="$(cat)"
[ "$VELA_SPEC_EDIT" = "1" ] && exit 0
case "$input" in *docs/rules/*) ;; *) exit 0 ;; esac

reason="docs/rules/ is the functional spec of the tests: it changes only in the design phase, with the human (spec-guard)."

block() {
  if [ "$host" = "cc" ]; then
    printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"%s"}}\n' "$reason"
    exit 0
  fi
  echo "Blocked by vela-agentic: $reason Start the session with VELA_SPEC_EDIT=1 to edit the spec." >&2
  exit 2
}

if command -v jq >/dev/null 2>&1; then
  case "$host" in
    cp) tool="$(printf '%s' "$input" | jq -r '.toolName // empty' 2>/dev/null)"
        args="$(printf '%s' "$input" | jq -r '.toolArgs | if type == "string" then . else tostring end' 2>/dev/null)" ;;
    *)  tool="$(printf '%s' "$input" | jq -r '.tool_name // empty' 2>/dev/null)"
        args="$(printf '%s' "$input" | jq -c '.tool_input // {}' 2>/dev/null)" ;;
  esac
else
  tool=""; args="$input"
fi

# File-editing tools aimed at docs/rules/.
case "$tool" in
  Write|Edit|MultiEdit|NotebookEdit|edit|create|write|str_replace_editor|apply_patch)
    case "$args" in *docs/rules/*) block ;; esac
    exit 0 ;;
esac

# Shell commands: a write operator together with a docs/rules/ path.
if printf '%s' "$args" | grep -Eq 'docs/rules/' && \
   printf '%s' "$args" | grep -Eq '(>>?[[:space:]]*[^[:space:]]*docs/rules/|tee([[:space:]]+-a)?[[:space:]]+[^[:space:]]*docs/rules/|sed[[:space:]]+-i|perl[[:space:]]+-[a-z]*i|(^|[[:space:];&|])(mv|cp|rm|truncate|install)[[:space:]]|git[[:space:]]+(rm|mv|checkout|restore)[[:space:]]|open\(|write_text|writeFile)'; then
  block
fi
exit 0
