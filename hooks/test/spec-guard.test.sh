#!/bin/sh
# Tests for hooks/bin/spec-guard.sh. Exit 0 if all pass.
G="$(cd "$(dirname "$0")/.." && pwd)/bin/spec-guard.sh"
pass=0; fail=0
t() { # name, host, payload, expect (ask|deny|allow)
  out="$(printf '%s' "$3" | VELA_SPEC_EDIT= sh "$G" "$2" 2>/dev/null)"; code=$?
  case "$code:$out" in
    0:*'"ask"'*) got=ask ;;
    2:*) got=deny ;;
    0:*) got=allow ;;
    *) got="exit$code" ;;
  esac
  if [ "$got" = "$4" ]; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL $1: got $got, want $4"; fi
}
t "cc edit rules"      cc '{"tool_name":"Edit","tool_input":{"file_path":"/p/docs/rules/account.md"}}' ask
t "cc write rules"     cc '{"tool_name":"Write","tool_input":{"file_path":"docs/rules/contact.md","content":"x"}}' ask
t "cc edit code"       cc '{"tool_name":"Edit","tool_input":{"file_path":"/p/src/A.cs"}}' allow
t "cc read rules"      cc '{"tool_name":"Read","tool_input":{"file_path":"/p/docs/rules/account.md"}}' allow
t "cc bash cat"        cc '{"tool_name":"Bash","tool_input":{"command":"cat docs/rules/account.md"}}' allow
t "cc bash grep"       cc '{"tool_name":"Bash","tool_input":{"command":"grep -n ACC-001 docs/rules/account.md"}}' allow
t "cc bash redirect"   cc '{"tool_name":"Bash","tool_input":{"command":"echo x >> docs/rules/account.md"}}' ask
t "cc bash sed -i"     cc '{"tool_name":"Bash","tool_input":{"command":"sed -i \"\" s/a/b/ docs/rules/account.md"}}' ask
t "cc bash git rm"     cc '{"tool_name":"Bash","tool_input":{"command":"git rm docs/rules/account.md"}}' ask
t "cc bash git log"    cc '{"tool_name":"Bash","tool_input":{"command":"git log -- docs/rules/account.md"}}' allow
t "cp edit rules"      cp '{"toolName":"edit","toolArgs":{"path":"docs/rules/account.md"}}' deny
t "cp shell redirect"  cp '{"toolName":"bash","toolArgs":{"command":"tee docs/rules/account.md"}}' deny
t "cp read rules"      cp '{"toolName":"view","toolArgs":{"path":"docs/rules/account.md"}}' allow
out="$(printf '%s' '{"tool_name":"Edit","tool_input":{"file_path":"docs/rules/a.md"}}' | VELA_SPEC_EDIT=1 sh "$G" cc)"; [ -z "$out" ] && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAIL approved session"; }
echo "spec-guard tests: $pass/$((pass+fail)) passed"
[ "$fail" -eq 0 ]
