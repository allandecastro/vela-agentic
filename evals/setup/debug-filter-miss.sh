#!/bin/sh
# Deterministic starting point for debug-filter-miss: an Update plugin that normalises Description but
# is filtered on the wrong column (the planted bug), with one test that sends Name too, so it can't reveal it.
#   sh evals/setup/debug-filter-miss.sh <work-dir>   -> <work-dir>/DescNorm (git repo)
set -e
. "$(dirname "$0")/lib.sh"
sol=$(new_solution "$1" DescNorm zava)
# The customer's solution, as in the dev org (the scenario tests debugging, not the solution question).
sed -i.bak "s/: DescNorm$/: ZavaSales/" "$sol/PROJECT.md" && rm "$sol/PROJECT.md.bak"
cd "$sol"
vela add plugin AccountNormalizeDescription --entity Account --message Update --stage PreOperation --mode Sync --filtering-attributes Name --handler OnDescriptionNormalize \
  --project src/zava.Plugins/zava.Plugins.csproj >/dev/null
python3 - <<'PY'
import re
p = "src/zava.Plugins/Account/Plugins/AccountNormalizeDescription.cs"
s = open(p, encoding="utf-8").read()
s = s.replace(".PostOperation()", ".PreOperation()").replace("IUpdatePostContext<Account>", "IUpdatePreContext<Account>")
s = re.sub(r"\.FilterOn\([^;\n]*\)[^\n]*", ".FilterOn(e => e.Name)", s, count=1)
s = s.replace("            // TODO: implement your logic.", """            var target = ctx.Request.Target;
            if (target.Description != null)
            {
                target.Description = System.Text.RegularExpressions.Regex.Replace(target.Description.Trim(), " {2,}", " ");
            }
            // TODO: implement your logic.""", 1)
assert "var target = ctx.Request.Target;" in s and ".FilterOn(e => e.Name)" in s, "scaffold template changed - update this setup"
open(p, "w", encoding="utf-8").write(s)
PY
mkdir -p tests/zava.Plugins.Tests/Account/Plugins
cat > tests/zava.Plugins.Tests/Account/Plugins/AccountNormalizeDescriptionTests.cs <<'CS'
namespace zava.Plugins.Tests.Account.Plugins
{
    using System;
    using Vela.Testing;
    using Xunit;
    using zava.Plugins.Account.Plugins;
    using zava.Shared.Models.Generated;

    public sealed class AccountNormalizeDescriptionTests
    {
        [Fact]
        public void Normalises_description()
        {
            var id = Guid.NewGuid();
            var p = PluginPipeline.Empty().Register<AccountNormalizeDescription>().Seed(new Account { Id = id, Name = "Zava" });
            p.Service.Update(new Account { Id = id, Name = "Zava Ltd", Description = "  Hello   world  " });
            Assert.Equal("Hello world", Assert.Single(p.GetAll(Account.EntityLogicalNameValue)).ToEntity<Account>().Description);
        }
    }
}
CS
dotnet build DescNorm.sln -c Release >/dev/null
commit "$sol" "account description normalisation (shipped)"
echo "$sol"
