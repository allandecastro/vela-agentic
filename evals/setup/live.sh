#!/bin/sh
# The plugin project that is DEPLOYED in the dev org (solution VelaEvals, publisher veval) - the starting
# point of the scenarios that work on a live registration (debug-live-trace, deployed-plugin-change).
#   sh evals/setup/live.sh <work-dir>      -> <work-dir>/VelaEvalsLive (git repo, builds)
# ContactPhoneNormalize carries a planted bug (a null phone throws); AccountRegionStamp has a Create and an
# Update step. The evaluator deploys exactly this project with `vela apply --solution VelaEvals` (an approved
# evaluator action, never an actor's).
set -e
. "$(dirname "$0")/lib.sh"
LIVE="$(cd "$(dirname "$0")" && pwd)/live"
mkdir -p "$1"
vela init --name VelaEvalsLive --prefix Veval --publisher-prefix veval --output "$1" >/dev/null
sol="$1/VelaEvalsLive"
cd "$sol"
vela models --entities account,contact --project src/Veval.Shared/Veval.Shared.csproj --url "$DEV_ORG" --overwrite >/dev/null
vela add plugin ContactPhoneNormalize --entity Contact --message Create --stage PreOperation --mode Sync \
  --filtering-attributes telephone1 --project src/Veval.Plugins/Veval.Plugins.csproj >/dev/null
vela add plugin AccountRegionStamp --entity Account --message Create --stage PreOperation --mode Sync \
  --filtering-attributes address1_country --project src/Veval.Plugins/Veval.Plugins.csproj >/dev/null
cp "$LIVE/src/Contact/Plugins/ContactPhoneNormalize.cs" src/Veval.Plugins/Contact/Plugins/
cp "$LIVE/src/Account/Plugins/AccountRegionStamp.cs" src/Veval.Plugins/Account/Plugins/
cp "$LIVE/tests/LivePluginsTests.cs" tests/Veval.Plugins.Tests/
dotnet build VelaEvalsLive.sln -c Release >/dev/null
commit "$sol" "live: the plugins deployed in VelaEvals (dev org)"
echo "$sol"
