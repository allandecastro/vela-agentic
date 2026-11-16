#!/bin/sh
# Table tests for hooks/bin/guard.sh. Run: sh hooks/test/guard.test.sh  (POSIX sh + awk; node for the generated configs)
# Each case: expected exit (0 allow / 2 deny) + the shell command the agent would run, or the file it would write.
cd "$(dirname "$0")/../.." || exit 1
G=hooks/bin/guard.sh
fail=0; total=0
TMPD="$(mktemp -d)"; trap 'rm -rf "$TMPD"' EXIT
(cd "$TMPD" && git init -q -b feature && git commit -q --allow-empty -m x)   # cwd on a feature branch

# A JSON string literal (quotes, backslashes, newlines, tabs escaped).
jstr() { printf '%s' "$1" | awk 'BEGIN { ORS = "" } { gsub(/\\/, "\\\\"); gsub(/"/, "\\\""); gsub(/\t/, "\\t"); if (NR > 1) print "\\n"; print } END { }' | sed 's/^/"/; s/$/"/'; }
check() { # host expected payload label
  printf '%s' "$3" | env -u VELA_APPLY_APPROVED sh "$G" "$1" 2>/dev/null; got=$?
  total=$((total + 1))
  [ "$got" = "$2" ] || { fail=$((fail + 1)); printf 'FAIL [%s] want %s got %s :: %s\n' "$1" "$2" "$got" "$4"; }
}
run() { # host expected command
  host="$1"; want="$2"; c="$3"
  if [ "$host" = cp ]; then payload="{\"toolName\":\"bash\",\"toolArgs\":{\"command\":$(jstr "$c")},\"cwd\":\"$TMPD\"}"
  else payload="{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":$(jstr "$c")},\"cwd\":\"$TMPD\"}"; fi
  printf '%s' "$payload" | env -u VELA_APPLY_APPROVED sh "$G" "$host" 2>/dev/null; got=$?
  total=$((total + 1))
  if [ "$got" != "$want" ]; then fail=$((fail + 1)); printf 'FAIL [%s] want %s got %s :: %s\n' "$host" "$want" "$got" "$c"; fi
}
deny()  { run cc 2 "$1"; run cp 2 "$1"; }
allow() { run cc 0 "$1"; run cp 0 "$1"; }

# --- must deny
deny 'vela apply -p x.nupkg --solution s'
deny 'vela --verbose apply'
deny 'vela --environment dev apply -p x'
deny 'echo ok && vela apply'
deny 'cd src; vela apply -p x'
deny 'dotnet build && dotnet pack | tee log; vela apply -p x'
deny 'dotnet vela apply -p x'
deny 'dotnet tool run vela apply -p x'
deny 'FOO=1 vela apply -p x'
deny 'VELA_APPLY_APPROVED=1 vela apply -p x'
deny 'env VELA_APPLY_APPROVED=1 vela apply -p x'
deny '/Users/me/.dotnet/tools/vela apply -p x'
deny '(vela apply -p x)'
deny 'echo $(vela apply -p x)'
deny 'vela plan -p x --auto-approve'
deny 'vela apply -p x --yes'
deny 'bash -c "vela apply -p x"'
deny "sh -c 'cd s && vela apply -p x'"
deny 'eval "vela apply -p x"'
deny 'vela plan -p x
vela apply -p x'

# --- must allow
allow 'vela plan -p x.nupkg -i'
allow 'vela apply --help'
allow 'vela inspect -p x'
allow 'vela version'
allow 'git commit -m "wire the vela apply gate"'
allow "git commit -m 'vela apply is gated'"
allow 'npm i --yes'
allow 'apt-get install --yes jq'
allow 'grep -rn "vela apply" skills'
allow 'cat skills/vela-apply/SKILL.md'
allow 'ls skills/vela-apply && echo vela-apply'
allow 'gh pr create --title "Build report" --body "$(cat <<'"'"'EOF'"'"'
## Gate
Run to deploy: `vela apply -p Zava.nupkg --solution zava -i`
vela apply -p Zava.nupkg --solution zava -i
It will not write until a human approves.
EOF
)"'
allow 'cat > docs/features/x/README.md <<EOF
vela apply -p x --yes
EOF'
allow ''

# --- documented limit: indirection is not caught (the CLI prompt + credentials stay the real barrier)
allow 'v=vela; $v apply -p x'

# --- approval: the HOST env var (not an inline prefix) opens the gate
printf '%s' '{"tool_input":{"command":"vela apply -p x"}}' | VELA_APPLY_APPROVED=1 sh "$G" cc 2>/dev/null
rc=$?; total=$((total + 1)); [ $rc = 0 ] || { fail=$((fail + 1)); echo "FAIL approved host env should allow"; }

# --- Copilot may pass toolArgs as a JSON string
printf '%s' '{"toolName":"bash","toolArgs":"{\"command\":\"vela apply -p x\"}"}' | env -u VELA_APPLY_APPROVED sh "$G" cp 2>/dev/null
rc=$?; total=$((total + 1)); [ $rc = 2 ] || { fail=$((fail + 1)); echo "FAIL cp string toolArgs should deny"; }

# --- git
deny 'git push origin main'
deny 'git push -u origin HEAD:main'
deny 'git push origin +feat/x'
deny 'git push --force origin feat/x'
deny 'git push -uf origin feat/x'
deny 'git push --mirror origin'
deny 'git commit --no-verify -m x'
deny 'git commit -anm x'
deny 'git -C repo push --no-verify origin feat/x'
allow 'git push -u origin feat/x'
allow 'git push --force-with-lease origin feat/x'
allow 'git push'                                      # cwd is on a feature branch
allow 'git commit -am "push to main later"'
allow 'git commit -m "fix --no-verify docs"'
(cd "$TMPD" && git checkout -q -b main)
deny 'git push'                                       # cwd is now on main
deny 'git push --force-with-lease'
(cd "$TMPD" && git checkout -q feature)

# --- secrets (built at run time: no literal secret in this file)
tok="abcdefgh$(printf '1%.0s' $(seq 1 8))"; az="abc8Q~$(printf 'a%.0s' $(seq 1 34))"; aws="AKIA$(printf 'Q%.0s' $(seq 1 16))"
deny "vela plan -p x --client-secret Sup3rS3cretValue"
deny "vela plan -p x --client-secret=Sup3rS3cretValue"
deny "curl -H 'Authorization: Bearer $tok' https://x"
deny "vela add step S --secure-config ApiKey=abcdef123"
deny 'echo $AZURE_CLIENT_SECRET'
deny 'printenv'
deny 'env | grep VELA'
deny "echo $az"
deny "export K=$aws"
deny "sqlcmd -C 'Server=x;User Id=u;Password=Hunter2pass'"
allow 'vela plan -p x --client-secret "$VELA_SECRET"'
allow 'vela plan -p x --client-secret-file secret.txt'
allow 'vela add step S --secure-config ApiKey=@secret.txt'
allow 'echo "--client-secret <secret>"'
allow 'printenv HOME'
allow 'env FOO=1 vela plan -p x'
allow '[ -n "$AZURE_CLIENT_SECRET" ] && echo set'

# --- file writes: generated files and secrets in content
write() { # expected path content
  check cc "$1" "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":$(jstr "$2"),\"content\":$(jstr "$3")},\"cwd\":\"$TMPD\"}" "write $2"
  check cp "$1" "{\"toolName\":\"create\",\"toolArgs\":{\"path\":$(jstr "$2"),\"file_text\":$(jstr "$3")},\"cwd\":\"$TMPD\"}" "create $2"
}
printf '// <auto-generated/>\nnamespace Z { static class Roles {} }\n' > "$TMPD/Roles.cs"
printf 'namespace Z { class Plugin {} }\n' > "$TMPD/Plugin.cs"
write 2 src/P/Models/Generated/Account.cs 'class Account {}'
write 2 src/P/Messages.g.cs 'x'
write 2 Roles.cs 'class Roles {}'                    # generated: its head carries <auto-generated
write 0 Plugin.cs 'class Plugin { string Name = "x"; }'
write 0 src/P/AccountPlugin.cs 'class AccountPlugin {}'
write 2 appsettings.json "{ \"ClientSecret\": \"$az\" }"
write 2 conn.txt "AuthType=ClientSecret;ClientId=x;ClientSecret=$tok"
write 0 README.md 'Pass --client-secret from an environment variable.'
check cc 2 "{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"Roles.cs\",\"old_string\":\"a\",\"new_string\":\"b\"},\"cwd\":\"$TMPD\"}" "edit Roles.cs"

# --- approval opens the apply gate only
printf '%s' '{"tool_input":{"command":"git push origin main"}}' | VELA_APPLY_APPROVED=1 sh "$G" cc 2>/dev/null
rc=$?; total=$((total + 1)); [ $rc = 2 ] || { fail=$((fail + 1)); echo "FAIL approval must not open the git rules"; }

# --- the generated Copilot configs embed the same scripts: smoke-test them end to end
A="$(printf 'ap%s' ply)"   # keeps this file from tripping the guard it tests when it is edited
for cfg in hooks.json .github/hooks/vela.json .github/copilot/settings.json; do
  gen="$(node -p "require('./$cfg').hooks.preToolUse[0].bash")"
  printf '{"toolName":"bash","toolArgs":{"command":"vela %s -p x"}}' "$A" | env -u VELA_APPLY_APPROVED bash -c "$gen" 2>/dev/null
  rc=$?; total=$((total + 1)); [ $rc = 2 ] || { fail=$((fail + 1)); echo "FAIL $cfg should deny the apply"; }
  printf '%s' '{"toolName":"bash","toolArgs":{"command":"vela plan -p x"}}' | env -u VELA_APPLY_APPROVED bash -c "$gen" 2>/dev/null
  rc=$?; total=$((total + 1)); [ $rc = 0 ] || { fail=$((fail + 1)); echo "FAIL $cfg should allow vela plan"; }
  out="$(bash -c "$(node -p "require('./$cfg').hooks.sessionStart[0].bash")" </dev/null)"
  total=$((total + 1)); case "$out" in "vela-agentic: vela CLI"*|"vela-agentic: the vela CLI"*) ;; *) fail=$((fail + 1)); echo "FAIL $cfg sessionStart: $out";; esac
done

# --- session hook
out="$(sh hooks/bin/session.sh 999.0.0)"; total=$((total + 1))
case "$out" in *"older than 999.0.0"*|*"not installed"*) ;; *) fail=$((fail + 1)); echo "FAIL session: older CLI not reported: $out";; esac
out="$(PATH=/usr/bin:/bin HOME="$TMPD" sh hooks/bin/session.sh 1.0.0)"; total=$((total + 1))
case "$out" in *"not installed"*) ;; *) fail=$((fail + 1)); echo "FAIL session: missing CLI not reported: $out";; esac

echo "guard tests: $((total - fail))/$total passed"
[ "$fail" = 0 ]
