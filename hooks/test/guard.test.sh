#!/bin/sh
# Table tests for hooks/bin/guard.sh. Run: sh hooks/test/guard.test.sh  (needs jq)
# Each case: expected exit (0 allow / 2 deny) + the shell command the agent would run.
cd "$(dirname "$0")/../.." || exit 1
G=hooks/bin/guard.sh
fail=0; total=0

run() { # host expected command
  host="$1"; want="$2"; c="$3"
  if [ "$host" = cp ]; then payload="$(jq -n --arg c "$c" '{toolName:"bash", toolArgs:{command:$c}}')"
  else payload="$(jq -n --arg c "$c" '{tool_name:"Bash", tool_input:{command:$c}}')"; fi
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
allow 'cat > docs/vela-builds/x.md <<EOF
vela apply -p x --yes
EOF'
allow ''

# --- documented limit: indirection is not caught (the CLI prompt + credentials stay the real barrier)
allow 'v=vela; $v apply -p x'

# --- approval: the HOST env var (not an inline prefix) opens the gate
printf '%s' '{"tool_input":{"command":"vela apply -p x"}}' | VELA_APPLY_APPROVED=1 sh "$G" cc 2>/dev/null
rc=$?; total=$((total + 1)); [ $rc = 0 ] || { fail=$((fail + 1)); echo "FAIL approved host env should allow"; }

# --- no jq: fail closed on vela+apply, open otherwise
nojq="$(mktemp -d)"; ln -s /bin/sh "$nojq/sh"; ln -s /bin/cat "$nojq/cat"
printf '%s' '{"tool_input":{"command":"vela apply -p x"}}' | PATH="$nojq" sh "$G" cc 2>/dev/null
rc=$?; total=$((total + 1)); [ $rc = 2 ] || { fail=$((fail + 1)); echo "FAIL no-jq should deny vela apply"; }
printf '%s' '{"tool_input":{"command":"ls -la"}}' | PATH="$nojq" sh "$G" cc 2>/dev/null
rc=$?; total=$((total + 1)); [ $rc = 0 ] || { fail=$((fail + 1)); echo "FAIL no-jq should allow ls"; }
rm -rf "$nojq"

# --- Copilot may pass toolArgs as a JSON string
printf '%s' '{"toolName":"bash","toolArgs":"{\"command\":\"vela apply -p x\"}"}' | env -u VELA_APPLY_APPROVED sh "$G" cp 2>/dev/null
rc=$?; total=$((total + 1)); [ $rc = 2 ] || { fail=$((fail + 1)); echo "FAIL cp string toolArgs should deny"; }

# --- the generated Copilot configs embed the same guard: smoke-test them end to end
for cfg in hooks.json .github/hooks/vela.json .github/copilot/settings.json; do
  gen="$(jq -r '.hooks.preToolUse[0].bash' "$cfg")"
  jq -n '{toolName:"bash",toolArgs:{command:"vela apply -p x"}}' | env -u VELA_APPLY_APPROVED bash -c "$gen" 2>/dev/null
  rc=$?; total=$((total + 1)); [ $rc = 2 ] || { fail=$((fail + 1)); echo "FAIL $cfg should deny vela apply"; }
  jq -n '{toolName:"bash",toolArgs:{command:"vela plan -p x"}}' | env -u VELA_APPLY_APPROVED bash -c "$gen" 2>/dev/null
  rc=$?; total=$((total + 1)); [ $rc = 0 ] || { fail=$((fail + 1)); echo "FAIL $cfg should allow vela plan"; }
done

echo "guard tests: $((total - fail))/$total passed"
[ "$fail" = 0 ]
