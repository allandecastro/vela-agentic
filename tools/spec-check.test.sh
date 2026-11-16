#!/usr/bin/env bash
# Tests for tools/spec-check.cs on throwaway git repos: one fixture per check, plus the clean and plumbing cases.
#   bash tools/spec-check.test.sh
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
SPEC="$HERE/spec-check.cs"
VELA_PLUGINS="${VELA_PLUGINS_VERSION:-0.41.1}"   # any published version: only its step API is read
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0

# Restore Vela.Plugins once (spec-check reads its step API from the NuGet cache).
mkdir -p "$TMP/restore" && cat > "$TMP/restore/R.csproj" <<EOF
<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup><TargetFramework>net48</TargetFramework></PropertyGroup>
<ItemGroup><PackageReference Include="Vela.Plugins" Version="$VELA_PLUGINS" /></ItemGroup></Project>
EOF
dotnet restore "$TMP/restore/R.csproj" >/dev/null || { echo "restore of Vela.Plugins failed"; exit 1; }
dotnet build "$SPEC" >/dev/null 2>&1 || true   # warm the file-based app build

TEST='using Xunit;
namespace T
{
    public class AccountTests
    {
        [Fact]
        [Trait("Case", "ACC-001/C1")]
        public void Defaults_description()
        {
            var p = Pipeline.For<AccountPlugin>();
            p.Create(new Account());
            Assert.Equal("x", p.Description);
        }
    }
}'

# A base project: rule ACC-001 (case C1), its test, an ADR. Then branch `story` with a Canvas.
new_repo() {
    R="$TMP/r$RANDOM$RANDOM"; mkdir -p "$R"/{docs/rules,docs/adr,docs/features/s,src/P,tests/T}; cd "$R"
    git init -q -b main; git config user.email t@t; git config user.name t
    printf '<Project><ItemGroup><PackageReference Include="Vela.Plugins" Version="%s" /></ItemGroup></Project>\n' "$VELA_PLUGINS" > src/P/P.csproj
    printf '# Rules - account\n\n### ACC-001 - Default description\nGiven no description When created Then defaulted\nCases:\n  - ACC-001/C1 empty -> defaulted\nTests: AccountTests\n' > docs/rules/account.md
    printf '# 0001 - Calling user\n' > docs/adr/0001-calling-user.md
    printf '%s\n' "$TEST" > tests/T/AccountTests.cs
    echo "class P {}" > src/P/P.cs
    git add -A; git commit -qm base; git checkout -qb story
}
canvas() { printf -- "---\nkind: canvas\nrules: [%s]\namendments: [%s]\n---\n" "$1" "${2:-}" > docs/features/s/README.md; git add -A; git commit -qm canvas; }
commit() { git add -A; git commit -qm "$1"; }
expect() {  # expect <exit> <name> [grep]
    out="$(dotnet run "$SPEC" -- --base "${BASE:-main}" --canvas docs/features/s/README.md 2>&1)"; code=$?
    if [ "$code" = "$1" ] && { [ -z "${3:-}" ] || grep -qF -- "$3" <<<"$out"; }; then pass=$((pass+1)); echo "ok   $2"
    else fail=$((fail+1)); echo "FAIL $2 (exit $code, want $1)"; echo "$out" | sed 's/^/     /'; fi
    cd "$TMP"
}
add_test() {  # add_test <file> <case-or-empty>
    local trait=""; [ -n "$2" ] && trait="[Trait(\"Case\", \"$2\")]"
    printf 'using Xunit;\nnamespace T { public class %s { [Fact] %s public void It() { Assert.True(true); } } }\n' "$1" "$trait" > "tests/T/$1.cs"
}

# clean: a declared new rule with its test
new_repo; canvas "{id: ACC-002, change: add}"
printf '\n### ACC-002 - Number upper case\nCases:\n  - ACC-002/C1 lower -> upper\n' >> docs/rules/account.md; commit spec
add_test NumberTests ACC-002/C1; commit tests; expect 0 "clean story"

# 1. rule changed / added without declaration
new_repo; canvas ""; sed -i.b 's/defaulted$/set to x/' docs/rules/account.md; rm docs/rules/account.md.b; commit spec
expect 1 "1 undeclared rule change" "ACC-001 changed but is not declared"
new_repo; canvas ""; printf '\n### ACC-002 - New\n' >> docs/rules/account.md; commit spec
expect 1 "1 undeclared rule added" "ACC-002 added"

# trace lines only: not a spec change
new_repo; canvas ""; sed -i.b 's/^Tests: AccountTests$/Tests: AccountTests, Other/' docs/rules/account.md; rm docs/rules/account.md.b; commit trace
expect 0 "trace lines are not spec"

# 2. rule deleted: fails unless declared retire (with its tests gone)
new_repo; canvas ""; printf '# Rules - account\n' > docs/rules/account.md; commit spec
expect 1 "2 rule deleted without retire" "not declared \`retire\`"
new_repo; canvas "{id: ACC-001, change: retire}"; printf '# Rules - account\n' > docs/rules/account.md; git rm -q tests/T/AccountTests.cs; commit retire
expect 0 "2 rule retired with its tests"

# 3. registry edited after the build started
new_repo; canvas "{id: ACC-002, change: add}"; printf '\n### ACC-002 - New\nCases:\n  - ACC-002/C1 x\n' >> docs/rules/account.md; commit spec
echo "class Q {}" > src/P/Q.cs; commit code
sed -i.b 's/ACC-002\/C1 x/ACC-002\/C1 y/' docs/rules/account.md; rm docs/rules/account.md.b; commit late
expect 1 "3 spec edited after code" "after the build started"
new_repo; canvas "{id: ACC-002, change: add}" "ACC-002"; printf '\n### ACC-002 - New\nCases:\n  - ACC-002/C1 x\n' >> docs/rules/account.md; commit spec
echo "class Q {}" > src/P/Q.cs; commit code
sed -i.b 's/ACC-002\/C1 x/ACC-002\/C1 y/' docs/rules/account.md; rm docs/rules/account.md.b; commit late
expect 0 "3 recorded amendment"
new_repo; printf -- "---\nkind: canvas\nrules: [{id: ACC-002, change: add}]\namendments:\n  - ACC-002   # review finding\n---\n" > docs/features/s/README.md; commit canvas
printf '\n### ACC-002 - New\nCases:\n  - ACC-002/C1 x\n' >> docs/rules/account.md; commit spec
echo "class Q {}" > src/P/Q.cs; commit code
sed -i.b 's/ACC-002\/C1 x/ACC-002\/C1 y/' docs/rules/account.md; rm docs/rules/account.md.b; commit late
expect 0 "3 amendment as a block list"

# 4. regression test modified / deleted; plumbing-only and whitespace changes are not modifications
new_repo; canvas ""; sed -i.b 's/Equal("x"/Equal("y"/' tests/T/AccountTests.cs; rm tests/T/AccountTests.cs.b; commit weaken
expect 1 "4 regression test modified" "Defaults_description (ACC-001/C1) modified"
new_repo; canvas ""; git rm -q tests/T/AccountTests.cs; commit drop
expect 1 "4 regression test deleted" "deleted"
new_repo; canvas ""
sed -i.b 's/Pipeline.For<AccountPlugin>()/Pipeline.For<AccountPlugin>().OnCreate().PreOperation().Sync()/; s/p.Create(new Account());/p.Create(new Account());   \/\/ comment/' tests/T/AccountTests.cs; rm tests/T/AccountTests.cs.b; commit plumbing
expect 0 "4 plumbing + comment only"
new_repo; canvas ""; sed -i.b 's/Pipeline.For<AccountPlugin>()/Pipeline.For<AccountPlugin>().FilterOn("name")/' tests/T/AccountTests.cs; rm tests/T/AccountTests.cs.b; commit notplumbing
expect 1 "4 a non-plumbing call is a modification" "modified"
new_repo; canvas "{id: ACC-001, change: change}"; sed -i.b 's/Equal("x"/Equal("y"/' tests/T/AccountTests.cs; rm tests/T/AccountTests.cs.b; commit change
expect 0 "4 test changed with its rule declared"
new_repo; canvas "{id: ACC-001, change: tests}"; sed -i.b 's/Pipeline.For<AccountPlugin>()/PluginPipeline.Empty().Register<AccountPlugin>()/' tests/T/AccountTests.cs; rm tests/T/AccountTests.cs.b; commit rewire
expect 0 "4 tests rewired, case still cited"
new_repo; canvas "{id: ACC-001, change: tests}"; git rm -q tests/T/AccountTests.cs; add_test Other ""; commit drop
expect 1 "4 tests rewired but a case dropped" "no longer cited"
new_repo; canvas "{id: ACC-001, change: tests}"; sed -i.b 's/defaulted$/set to x/' docs/rules/account.md; rm docs/rules/account.md.b; commit spec
expect 1 "1 tests-only declaration does not allow a rule change" "rewires its tests only"

# 5. case ids
new_repo; canvas ""; add_test NoCase ""; commit t; expect 1 "5 new test without case" "has no [Trait"
new_repo; canvas ""; add_test Ghost ACC-009/C1; commit t; expect 1 "5 test cites an unknown case" "ACC-009/C1"
new_repo; canvas ""; add_test Near ACC-00/C1; commit t; expect 1 "5 a prefix of a real case is unknown" "ACC-00/C1"

# 6. uncommitted
new_repo; canvas ""; echo "// x" >> tests/T/AccountTests.cs; expect 1 "6 uncommitted test change" "uncommitted"

# 7. ids: twice at HEAD; taken on the base tip; ADR number
new_repo; canvas "{id: ACC-002, change: add}"; printf '\n### ACC-002 - A\n\n### ACC-002 - B\n' >> docs/rules/account.md; commit dup
expect 1 "7 rule id twice at HEAD" "used twice"
new_repo; canvas "{id: ACC-002, change: add}"; printf '\n### ACC-002 - City\n' >> docs/rules/account.md; commit city
git checkout -q main; printf '### ACC-002 - Email\n' > docs/rules/email.md; commit email; git checkout -q story
expect 1 "7 id already taken on the base tip" "already taken on main"
new_repo; canvas ""; printf '# 0001 - Other\n' > docs/adr/0001-other.md; commit adr
expect 1 "7 ADR number twice" "ADR 0001 is used twice"
new_repo; git checkout -q main; printf '# 0001 - Other\n' > docs/adr/0001-other.md; commit adr; git checkout -q story; git merge -q main
canvas ""; expect 0 "7 duplicate already on the base is a note" "not this story's"

# no registry, bad base
# 8. ADR scope
new_repo; canvas ""; printf '# 0002 - Provider\n\nDate: x\n' > docs/adr/0002-provider.md; commit adr; expect 1 "8 new ADR without Scope" "needs a \`Scope:\` line"
new_repo; canvas ""; printf '# 0002 - Provider\n\nDate: x\nScope: account · integrations\n' > docs/adr/0002-provider.md; commit adr; expect 0 "8 new ADR with Scope"
new_repo; canvas ""; expect 0 "8 an untouched ADR without Scope is not failed"

new_repo; git rm -q -r docs/rules; commit norules; canvas ""; expect 0 "no registry: nothing to check" "nothing to check"
new_repo; canvas ""; BASE=nope expect 2 "bad base" "not a commit"

echo "spec-check tests: $pass passed, $fail failed"
[ "$fail" = 0 ]
