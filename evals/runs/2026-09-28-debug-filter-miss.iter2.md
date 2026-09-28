---
scenario: debug-filter-miss
date: 2026-09-28
verdict: pass
vela_cli: 0.19.6
framework: 0.28.2
runner: "fresh subagent, local, no org, iteration 2"
---

## Loop outcome
- Setup (harness role): `vela version` -> `vela 0.19.6`. `vela init DescNorm --prefix zava -o <scratch> --no-console --no-integrations` exit 0 (Vela.Plugins 0.28.2). Demos deleted (vela-scaffold step 6). `// STAND-IN for vela-models (no org)` `Description` property added to `Models/Generated/Account.cs` (vela-plugin-authoring step 2). `vela add plugin AccountNormalizeDescription --entity Account --message Update --filtering-attributes Name` exit 0 -> `.FilterOn(e => e.Name)` (the planted bug). Stage changed to `.PreOperation()` + `IUpdatePreContext<Account>`; handler normalises `ctx.Request.Target.Description`. One handler test with `PluginContext...Execute` (ignores `FilterOn`, so it does not reveal the bug). `dotnet build -c Release --no-incremental`: 0 Warning(s), 0 Error(s). Mono xunit: `Total: 1, Errors: 0, Failed: 0`. Committed `c712df3`.
- Step 1 symptom (debugging role): Update / account / PreOperation / Sync (read from `RegisterPluginSteps()`); user edits only Description; expected trimmed + collapsed value; observed unchanged value.
- Step 2 trace log (no org, no human): request recorded, not sent - "Power Apps -> Advanced settings -> Settings -> Plug-in Trace Log (or Plugin Registration Tool). First check System Settings -> Customization -> Enable logging to plug-in trace log = Exception or All; if off, enable and edit a description once. Paste, for the account Update where you edited the description: type name, message, primary entity, stage/mode, depth, correlation id, exception details, message block. If there is no row for `zava.Plugins.Account.Plugins.AccountNormalizeDescription` at all, say so." No org read around the CLI.
- Step 3 RED repro with `PluginPipeline` (description-only Update, expect one run + normalised value): `Assert.Single() Failure: The collection was empty`; `Total: 2, Errors: 0, Failed: 1, Skipped: 0`. Committed `971ace7`, before any code change.
- Step 4 minimize: already minimal (one Update, one column).
- Step 5 hypothesis: gotchas "Create/Update step never triggers on the change you expect. A filtering attribute excludes the attribute that actually changed" vs `.FilterOn(e => e.Name)`.
- Step 6 instrument: temporary probe read `pipeline.ExecutionLog`: `description-only update -> runs: 0`, `name-only update -> runs: 1`, `zava.Plugins.Account.Plugins.AccountNormalizeDescription Update PreOperation Synchronous account depth=1`. Probe deleted.
- Step 7 fix, one line: `.FilterOn(e => e.Name)` -> `.FilterOn(e => e.Description)` (`git diff --stat`: 1 file changed, 1 insertion(+), 1 deletion(-)). Committed `db0e3a3`.
- Step 8 regression: `dotnet build DescNorm.sln -c Release --no-incremental` 0 Warning(s) / 0 Error(s) (no VELA diagnostics); Mono xunit `Total: 2, Errors: 0, Failed: 0, Skipped: 0`; package `artifacts/zava.Plugins.1.0.0.nupkg`. Recorded, not run (no org):
  `vela inspect -p artifacts/zava.Plugins.1.0.0.nupkg --connection-string "$DATAVERSE_CONNECTION_STRING"` (expect the live Update step's filtering attributes = `name`, which confirms the cause), then
  `vela plan -p artifacts/zava.Plugins.1.0.0.nupkg --connection-string "$DATAVERSE_CONNECTION_STRING"` (expect the step's filtering attributes to change `name` -> `description`). `vela apply` never run.

## Success criteria
1. RED before a code change: yes, commit `971ace7` (test only) before `db0e3a3` (fix); failure is `Assert.Single() ... empty` = step never fired (the right reason, not the assertion on the value).
2. One-line fix, repro + existing suite green: yes, diff is 1 line; `Total: 2, Failed: 0`.
3. Explanation names the gotcha + evidence: filtering-attribute gotcha; evidence = empty ExecutionLog for a description-only Update, one run for a name-only Update.
4. Trace log request: says where, how to enable it, which fields; no Web API / org read.

## Findings
Skill defects (none blocking):
1. minor - `skills/vela-debug-plugin/SKILL.md` step 6: "add `ctx.Trace(...)` lines ..., reproduce, read the message block". In the harness there is no documented way to read `ctx.Trace` output: `references/harness-api.md` does not mention it. Vela.Testing.xml has `PluginPipeline.Trace`, `RecordingTracingService.Traces` and `PluginContextBuilder<T>.TraceCapture`. Not needed this run (the step never fired, so ExecutionLog was the evidence), but a handler-level bug would need rediscovery. Fix: document the trace-capture API in harness-api.md.
2. minor - `references/harness-api.md` / step 6 say to "read `pipeline.ExecutionLog`" but not how to see it from the Mono xunit console. `ITestOutputHelper.WriteLine` printed nothing on a passing test (even with `-verbose`); I had to switch to `Console.WriteLine`. Fix: say to assert on it (`Assert.Single`/`Assert.Empty`) or print with `Console.WriteLine`.
3. minor - `skills/vela-debug-plugin/SKILL.md` step 3 sends you to `vela-test-harness`, whose Coverage says "mandatory - no happy-path-only ... a column not sent vs a column cleared". The skill does not say whether a bug repro must add the full coverage set, or only the repro plus regression. The scenario says "nothing else changes". I added only the repro. Fix: say a debug run adds the repro (plus any directly related regression case), not the full story coverage set.
4. minor - `skills/vela-debug-plugin/SKILL.md` step 1: "stage, mode ... Missing a piece? Ask for it in one question". It does not say that stage and mode come from `RegisterPluginSteps()` (the Evidence table's "Intended registration") and not from the user. I read them from the code, the only reasonable path. Fix: "fill registration facts from the code; ask the human only for what they did and saw".
5. minor (setup phase) - `skills/vela-scaffold/SKILL.md` Verification says "The generated component is present where the CLI reported it, unedited." Step 5 and the "Scaffolded ... are yours" paragraph require editing it (stage, context type). Fix: "compiles as generated; registration then aligned to the Canvas".

Environment notes (not skill defects): none. The Mono runner at `~/.nuget/packages/xunit.runner.console/2.9.2/tools/net462/xunit.console.exe` was already present; `-parallel none` gave no segv.

## Fixes
- none yet (this run feeds the next iteration)

## Verdict
pass - no blocking finding. The skill's process (pipeline repro, gotcha lookup, ExecutionLog) led to the cause with no hidden knowledge: the harness-api recipe (`Register<T>().Seed(...)`, `p.Service.Update`, `Assert.Single(p.ExecutionLog)`, entry fields `PluginTypeName/Message/Stage/Mode/EntityLogicalName/Depth`) compiled and ran verbatim. Next run must re-check findings 1-3 once fixed (trace capture documented, ExecutionLog printing, repro-vs-coverage scope).
