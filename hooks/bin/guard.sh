#!/bin/sh
# vela-agentic apply-guard (dual-target: Claude Code + GitHub Copilot).
# Denies `vela apply` (and `--auto-approve` / `--yes` on a vela command) unless the HOST process was
# started with VELA_APPLY_APPROVED=1. Wired as a PreToolUse (Claude Code) / preToolUse (Copilot)
# hook on the shell tool. Exit 2 denies on BOTH hosts; exit 0 allows.
#
# Usage: guard.sh <host>   where host = cc (Claude Code) | cp (Copilot)
# Reads the hook payload JSON on stdin. Uses `jq`; without it the guard fails CLOSED on any
# payload that mentions vela and apply.
#
# What counts as an apply: a shell segment (split on ; && || | & newline, subshells, backticks)
# whose command word is `vela` (any path, optionally after env assignments / env / command / exec /
# sudo / time / nohup / dotnet [tool run]) and which has an `apply` word, or `--auto-approve`/`--yes`.
# Quoted strings and heredoc bodies are data, not commands (commit messages, PR bodies, grep
# patterns). `sh -c` / `eval` payloads are checked conservatively. `vela apply --help` is allowed.
# Known limit (by design, see hooks/README.md): indirection such as `v=vela; $v apply` is not caught.
host="$1"
input="$(cat)"

deny() {
  echo "Blocked by vela-agentic: $1 A human must approve by starting the session with VELA_APPLY_APPROVED=1 (stop-before-apply)." >&2
  exit 2
}

[ "$VELA_APPLY_APPROVED" = "1" ] && exit 0

if ! command -v jq >/dev/null 2>&1; then
  # Fail closed only when it could matter.
  case "$input" in
    *vela*apply*|*apply*vela*) deny '"jq" is missing, so the guard cannot parse this command that mentions vela apply.' ;;
  esac
  exit 0
fi

case "$host" in
  cp) cmd="$(printf '%s' "$input" | jq -r '(.toolArgs | if type == "string" then (fromjson? // {command: .}) else . end) | (.command // .cmd // empty)' 2>/dev/null)" ;;
  *)  cmd="$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)" ;;
esac
[ -n "$cmd" ] || exit 0

# Fast path: nothing to inspect.
case "$cmd" in *vela*) ;; *) exit 0 ;; esac

# `sh -c "..."` / `eval "..."`: the payload is quoted, so check the raw text conservatively.
if printf '%s\n' "$cmd" | grep -Eq '(^|[[:space:];&|(])(eval|(ba|z|da|k)?sh[[:space:]]+(-[a-z]*[[:space:]]+)*-[a-z]*c)[[:space:]]' \
   && printf '%s\n' "$cmd" | grep -Eq 'vela[^;&|]*[[:space:]](apply|--auto-approve|--yes)([[:space:]"'"'"']|$)'; then
  deny '"vela apply" inside sh -c / eval writes to a live org.'
fi

verdict="$(printf '%s\n' "$cmd" | awk '
  # 1. Drop heredoc bodies (PR bodies, file contents).
  {
    if (delim != "") { t = $0; gsub(/^[ \t]+|[ \t]+$/, "", t); if (t == delim) delim = ""; next }
    line = $0
    if (match(line, /<<-?[ \t]*["\047]?[A-Za-z_][A-Za-z0-9_]*["\047]?/)) {
      d = substr(line, RSTART, RLENGTH); sub(/^<<-?[ \t]*/, "", d); gsub(/["\047]/, "", d); delim = d
    }
    text = text line "\n"
  }
  END {
    # 2. Replace quoted strings with a space (quotes are data, not commands).
    out = ""; n = length(text); q = ""
    for (i = 1; i <= n; i++) {
      c = substr(text, i, 1)
      if (q == "\047") { if (c == "\047") { q = ""; out = out " " } continue }
      if (q == "\"")   { if (c == "\\") { i++; continue } if (c == "\"") { q = ""; out = out " " } continue }
      if (c == "\\") { out = out substr(text, i, 2); i++; continue }
      if (c == "\047" || c == "\"") { q = c; continue }
      out = out c
    }
    # 3. Split into command segments.
    gsub(/\$\(|[;&|()`\n]/, "\n", out)
    m = split(out, seg, "\n")
    for (s = 1; s <= m; s++) {
      k = split(seg[s], w, /[ \t]+/); j = 1
      while (j <= k && (w[j] == "" || w[j] ~ /^[A-Za-z_][A-Za-z0-9_]*=/ || w[j] ~ /^(env|command|exec|sudo|time|nohup|dotnet|tool|run)$/)) j++
      if (j > k) continue
      base = w[j]; sub(/.*\//, "", base)
      if (base != "vela" && base != "vela.exe") continue
      help = 0; hit = ""
      for (x = j + 1; x <= k; x++) {
        if (w[x] == "--help" || w[x] == "-h") help = 1
        if (w[x] == "apply") hit = "apply"
        if (w[x] == "--auto-approve" || w[x] == "--yes") hit = "auto-approve"
      }
      if (hit != "" && !help) { print hit; exit }
    }
  }')"

case "$verdict" in
  apply)        deny '"vela apply" writes to a live org.' ;;
  auto-approve) deny '"--auto-approve"/"--yes" bypasses the confirmation of a write to a live org.' ;;
esac
exit 0
