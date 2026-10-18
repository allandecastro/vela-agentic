#!/bin/sh
# Deterministic starting point: the reviewed account-default-description baseline, committed.
#   sh evals/setup/baseline.sh <work-dir>      -> <work-dir>/ZavaSales (git repo, green)
set -e
. "$(dirname "$0")/lib.sh"
sol=$(new_solution "$1" ZavaSales zava)
cd "$sol"
vela add plugin AccountDefaultDescription --entity Account --message Create --stage PreOperation --mode Sync --filtering-attributes Name \
  --project src/zava.Plugins/zava.Plugins.csproj >/dev/null
python3 - <<'PY'
import re
p = "src/zava.Plugins/Account/Plugins/AccountDefaultDescription.cs"
s = open(p, encoding="utf-8").read()
s = s.replace(".PostOperation()", ".PreOperation()").replace("ICreatePostContext<Account>", "ICreatePreContext<Account>")
s = re.sub(r"\.FilterOn\([^;\n]*\)[^\n]*", ".FilterOn(e => e.Name)", s, count=1)
s = s.replace("            // TODO: implement your logic.", """            var target = ctx.Request.Target;
            if (string.IsNullOrWhiteSpace(target.Description))
            {
                target.Description = "Created via Vela plugin";
            }
            // TODO: implement your logic.""", 1)
open(p, "w", encoding="utf-8").write(s)
PY
mkdir -p tests/zava.Plugins.Tests/Account/Plugins
cat > tests/zava.Plugins.Tests/Account/Plugins/AccountDefaultDescriptionTests.cs <<'CS'
namespace zava.Plugins.Tests.Account.Plugins
{
    using System;
    using Vela.Testing;
    using Xunit;
    using zava.Plugins.Account.Plugins;
    using zava.Shared.Models.Generated;

    public sealed class AccountDefaultDescriptionTests
    {
        private static Account Run(string description)
        {
            var target = new Account { Id = Guid.NewGuid(), Name = "Zava", Description = description };
            PluginContext.For<Account>().WithTarget(target).WithOrganizationService(new InMemoryOrganizationService())
                .Execute(new AccountDefaultDescription(string.Empty, string.Empty));
            return target;
        }

        [Fact] public void Null_description_is_defaulted() => Assert.Equal("Created via Vela plugin", Run(null).Description);
        [Fact] public void Whitespace_description_is_defaulted() => Assert.Equal("Created via Vela plugin", Run("   ").Description);
        [Fact] public void Given_description_is_untouched() => Assert.Equal("Keep me", Run("Keep me").Description);
    }
}
CS
mkdir -p docs/vela-builds
cat > docs/vela-builds/account-default-description.md <<'MD'
---
kind: vela-build
slug: account-default-description
status: approved
entity: account
message: Create
stage: PreOperation
mode: Synchronous
filtering_attributes: [Name]
solution: ZavaSales
publisher_prefix: zava
rules:
  - {id: ACC-001, change: add}
acceptance_cases:
  - "null Description -> 'Created via Vela plugin'"
  - "whitespace Description -> defaulted"
  - "non-empty Description -> untouched"
---

## R - Requirements & DoD
"When an Account is created, if its Description is empty, set it to 'Created via Vela plugin'."

## A - Approach
Sync PreOperation on ctx.Request.Target: the default is part of the same write. New plugin.
MD
mkdir -p docs/rules
cat > docs/rules/account.md <<'MD'
# Rules - account

### ACC-001 - A new account without a description gets a default one
Status: active · Since: account-default-description (2026-09-25)

Given an account whose Description is empty (null, "" or whitespace only)
When the account is created
Then its Description is set to "Created via Vela plugin"
Otherwise (a non-empty Description) the Description is left as entered

Exceptions / assumptions:
  - A create that does not send Name does not fire the step (the step filters on Name)

Implementation: AccountDefaultDescription · Create · PreOperation · Sync
Tests: AccountDefaultDescriptionTests
MD
dotnet build ZavaSales.sln -c Release >/dev/null
commit "$sol" "baseline: account-default-description (reviewed, green)"
echo "$sol"
