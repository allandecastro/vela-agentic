#!/bin/sh
# Deterministic starting point for debug-filter-miss: an Update plugin that normalises Description but
# is filtered on the wrong column (the planted bug), with one handler-level test that can't reveal it.
#   sh evals/setup/debug-filter-miss.sh <work-dir>   -> <work-dir>/DescNorm (git repo)
set -e
. "$(dirname "$0")/lib.sh"
sol=$(new_solution "$1" DescNorm zava)
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
        public void Handler_normalises_description()
        {
            var target = new Account { Id = Guid.NewGuid(), Description = "  Hello   world  " };
            PluginContext.For<Account>().WithTarget(target).WithOrganizationService(new InMemoryOrganizationService())
                .Execute(new AccountNormalizeDescription(string.Empty, string.Empty));
            Assert.Equal("Hello world", target.Description);
        }
    }
}
CS
dotnet build DescNorm.sln -c Release >/dev/null
commit "$sol" "account description normalisation (shipped)"
echo "$sol"
