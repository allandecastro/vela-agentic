#!/bin/sh
# Shared helpers for deterministic eval setups (the evaluator prepares the starting point; the acting
# agent only gets the project + the story). Requires vela, dotnet, python3, git.
set -e
export PATH="$HOME/.dotnet/tools:$PATH"

# new_solution <dir> <Name> <prefix>  -> scaffold without integrations/console, demos removed.
new_solution() {
  mkdir -p "$1"
  vela init "$2" --prefix "$3" --no-integrations --no-console -o "$1" >/dev/null
  sol="$1/$2"
  ( cd "$sol"
    rm -f src/"$3".Plugins/Account/CustomApis/AccountEstimateValueCustomApi.cs \
          src/"$3".Plugins/Account/Plugins/AccountMessageReference.cs \
          src/"$3".Plugins/Account/Plugins/AccountPostCreatePlugin.cs \
          src/"$3".Plugins/Account/Plugins/AccountRelatedContactsPlugin.cs \
          src/"$3".Plugins/Account/Services/AccountFollowUpService.cs \
          src/"$3".Plugins/Contact/CustomApis/ContactValidateCustomApi.cs \
          src/"$3".Plugins/Contact/Plugins/ContactRouterPlugin.cs \
          src/"$3".Plugins/Contact/Services/ContactDuplicateService.cs \
          src/"$3".Plugins/GlobalCustomApis/PingCustomApi.cs \
          src/"$3".Shared/Services/GreetingService.cs src/"$3".Shared/Services/IGreetingService.cs
    rm -rf tests/"$3".Plugins.Tests/Account tests/"$3".Plugins.Tests/Contact \
           tests/"$3".Plugins.Tests/GlobalCustomApis tests/"$3".Plugins.Tests/Security )
  echo "$sol"
}

# stand_in <sol> <prefix> <Entity> <logical> <Property> <ClrType>  -> labelled no-org model property.
stand_in() {
  python3 - "$1/src/$2.Shared/Models/Generated/$3.cs" "$4" "$5" "$6" <<'EOF'
import sys
p, logical, prop, clr = sys.argv[1:5]
s = open(p, encoding="utf-8").read()
if f'"{logical}"' not in s:
    block = (f'\n        // STAND-IN for vela-models (no org)\n        [AttributeLogicalName("{logical}")]\n'
             f'        public {clr} {prop}\n        {{\n            get => GetAttributeValue<{clr}>("{logical}");\n'
             f'            set => SetAttributeValue("{logical}", value);\n        }}\n')
    i = s.rindex("    }\n}")
    s = s[:i] + block + s[i:]
    open(p, "w", encoding="utf-8").write(s)
EOF
}

commit() { ( cd "$1" && git init -q 2>/dev/null; git add -A && git -c user.name=eval -c user.email=eval@local commit -q -m "$2" ); }
