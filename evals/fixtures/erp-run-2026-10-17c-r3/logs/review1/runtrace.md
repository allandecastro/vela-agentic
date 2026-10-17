| # | step | skill | command | exit | verdict |
|---|------|-------|---------|------|---------|
| 1 | version | using-vela | `vela version` | 0 | vela 0.26.1 |
| 2 | grill | vela-grill | Q1-Q3 to the human (solution, ERP-down behaviour, JSON body) | - | answered |
| 3 | solution | vela-scaffold | `vela solution show ZavaSales --json --url https://dyn-premium-dev.crm.dynamics.com` | 0 | {"solution":"ZavaSales","publisherPrefix":"zava"} |
| 4 | scaffold | vela-scaffold | `vela init ZavaSales --prefix Zava --publisher-prefix zava --integrations -o .` | 0 | 11 files, Vela.Plugins 0.36.0 |
| 5 | model | vela-models | `vela models --entities account --project src/Zava.Shared/Zava.Shared.csproj --url https://dyn-premium-dev.crm.dynamics.com` | 0 | Generated 4 file(s) |
| 6 | add | vela-scaffold | `vela add plugin AccountErpNotify --entity Account --message Create --stage PostOperation --mode Async --filtering-attributes name --project src/Zava.Integrations/Zava.Integrations.csproj` | 0 | Created plugin |
| 7 | add | vela-scaffold | `vela add service ErpAccountSender --entity Account --project src/Zava.Integrations/Zava.Integrations.csproj` | 0 | Created service |
| 8 | add | vela-scaffold | `vela add test AccountErpNotify --kind plugin --entity Account --message Create --project Zava.Integrations.Tests.csproj` (in tests/Zava.Integrations.Tests) | 0 | Created test |
| 9 | build | vela-test-harness | `dotnet build ZavaSales.sln -c Release` | 0 | 0 Warning(s) 0 Error(s) |
| 10 | test-red | vela-test-harness | `mono ~/.nuget/packages/xunit.runner.console/2.9.2/tools/net472/xunit.console.exe tests/Zava.Integrations.Tests/bin/Release/net48/Zava.Integrations.Tests.dll -parallel none` | 1 | RED 14/18 fail (expected) |
| 11 | build | vela-plugin-authoring | `dotnet build ZavaSales.sln -c Release` | 0 | 0 Warning(s) 0 Error(s) |
| 12 | verify | vela-test-harness | same mono runner, Zava.Integrations.Tests.dll | 0 | GREEN 18/18 |
| 13 | verify | vela-test-harness | same mono runner, Zava.Plugins.Tests.dll | 0 | Total: 0 (empty project, nothing of this story) |
