---
scenario: account-multi-step
date: 2026-09-28
verdict: fail
vela_cli: 0.19.6
framework: 0.28.2
runner: fresh subagent, local, no org
---

## Loop outcome
Setup (depends_on `account-default-description`), then the scenario, acting as `vela-builder`.
Scratch: `evals/account-multi-step/` (solution in `src-sol/ZavaEval`, Canvases in `artifacts/`,
Build Report in `src-sol/ZavaEval/docs/vela-builds/account-multi-step.md`).

Baseline:
- Version: `vela version` -> `vela 0.19.6`, exit 0.
- Challenge: baseline Canvas written (`artifacts/account-default-description.md`, now superseded).
- Scaffold: `vela init ZavaEval --prefix Zava -o src-sol` exit 0; `dotnet build` 0 errors, 4 demo VELA013;
  `vela add plugin AccountDefaultDescription --entity Account --message Create --filtering-attributes Name --project src/Zava.Plugins/Zava.Plugins.csproj` exit 0 (`FilterOn(e => e.Name)`);
  `vela add test AccountDefaultDescription --kind plugin --entity Account` (in the Tests project) exit 0.
- Model: skipped (no org), `Description` stand-in. Would run: `vela models --entities account --project src/Zava.Shared/Zava.Shared.csproj --overwrite -i`.
- RED: `Total: 3, Errors: 0, Failed: 2` (exit 1). Implement (PreOperation, `ctx.Request.Target`). GREEN: `Total: 12, Errors: 0, Failed: 0` (exit 0).

Scenario:
- Challenge: Canvas `artifacts/account-multi-step.md`: `reuse: add-step:AccountDefaultDescription`, `steps:` list with the Update step (PreOperation/Sync/filter name/pre-image accountnumber). Assumptions flagged, continued.
- Scaffold: `vela add step AccountDefaultDescription --entity Account --message Update --project src/Zava.Plugins/Zava.Plugins.csproj` exit 0. Generated `HandleUpdate(IUpdatePostContext<Account>)`, `.PostOperation()`, `FilterOn(e => e.Id /* TODO */)`.
- Build 1: exit 1, `AccountDefaultDescription.cs(25,34): error VELA001: 'Id' is not a Dataverse column; ...`. Replaced it with `e => e.Name`, set `.PreOperation()` + `IUpdatePreContext<Account>`, added `.WithPreImage(e => e.AccountNumber)` and `partial`. Build 2: 0 errors.
- Model: skipped (no org), `AccountNumber` stand-in.
- Unchanged Create tests on the now multi-step plugin: 3 fail, `Plugin '...AccountDefaultDescription' has no registered step matching message 'Update'`. The skill predicted this, so the tests were updated with `.OnCreate().Stage(PluginStages.PreOperation)`.
- RED: `Total: 8, Errors: 0, Failed: 2` (U1, U2; exit 1).
- Implement: 1 fail, U4 "name not in Target -> step not run" (`Assert.False() Failure`). `PluginContext.Execute` ignores `FilterOn` (finding 1). U4 was rewritten on `PluginPipeline` (which honours filtering attributes).
- GREEN: `Total: 18, Errors: 0, Failed: 0`. A mutation check (add `Telephone1` to the filter) makes U4 fail, so the test is not vacuous.
- Review (self, diff against the post-baseline snapshot because this eval allows no git): BLOCK, 1 Required. An explicitly cleared AccountNumber was resurrected from the pre-image. Canvas updated first (U6), then RED `Total: 19, Failed: 1` (`Actual: "AB-123"`), then fix, then GREEN `Total: 19, Errors: 0, Failed: 0`. Re-review: PASS, 3 Nits.
- Verify: `dotnet build ZavaEval.sln -c Release --no-incremental` gives `0 Error(s)`, `4 Warning(s)`. All 4 are VELA013 in scaffold demo tests; 0 VELA00x in authored code.
- Package: a cold `dotnet pack ... -c Release -o pack-cold` exits 0 but produces a 4-file package with **no assemblies** (finding 2). The deployable package is `artifacts/Zava.Plugins.1.0.0.nupkg` from `dotnet build -c Release` (contains Zava.Plugins.dll and Zava.Shared.dll), sha256 `47590f58aaa846741f8ca74f8f6d8aa7452258ec2d03826e2552eff604d6afce`, unsigned (no cert).
- Plan: skipped (no org). Would run: `vela plan -p artifacts/Zava.Plugins.1.0.0.nupkg --connection-string "$DATAVERSE_CONNECTION_STRING" --out plan.json`.
- Apply gate: Build Report emitted; stopped. `vela apply` not run. Draft PR skipped (eval).

### Scenario checks
| Item | Result | Evidence |
| --- | --- | --- |
| Reuse via `vela add step`, not a new plugin | pass | exit 0, `Added step Update (HandleUpdate) to AccountDefaultDescription` |
| `HandleUpdate` + `OnExecute` both kept | pass | both handler names unchanged in the final file |
| VELA001 placeholder fails the build, then replaced with `e => e.Name` | pass | `error VELA001: 'Id' is not a Dataverse column`, then `0 Error(s)` |
| Stage PreOperation on `ctx.Request.Target` | pass (manual edit, finding 3) | `.PreOperation()`, `IUpdatePreContext<Account>`, `target.AccountNumber = upper` |
| Every test states its trigger; Create tests updated and green | pass | `.OnCreate()/.OnUpdate().Stage(PluginStages.PreOperation)`; C1-C3 green |
| SC1 Canvas has `reuse: add-step:AccountDefaultDescription` and the Update step | pass | `artifacts/account-multi-step.md` |
| SC2 VELA001 first, then green with no VELA00x in authored code | pass | see above |
| SC3 RED, then green: name changed -> uppercased; name unchanged -> not run; Create cases pass | pass, after a deviation (finding 1) | RED 2/8, then GREEN 19/19 |
| SC4 `vela-code-review` PASS | pass | BLOCK (1 Required), then PASS (3 Nits) |
| Baseline SC1-SC7 (init/add exit 0, real surface, RED then green, analyzer-clean, 2 behaviours, PreOperation, Canvas + Report) | pass | baseline RED 2/3, then GREEN 12/12 |

## Findings

### Skill defects
1. **blocker** - `skills/vela-test-harness/references/harness-api.md` gives only the `PluginContext.For<T>()...Execute(plugin)` shape for step tests, and mentions `PluginPipeline` only "for cascades". `vela-plugin-authoring` step 6 says "Guard the trigger via the registered filtering attributes (`FilterOn`) ... not loose re-checks in code". The scenario requires proving "name unchanged (filter) -> step not run".
   - What happened: `PluginContext.Execute` does **not** apply `FilterOn`. The handler ran with a Target containing only `telephone1`, and the test failed after implementation (`Assert.False() Failure / Expected: False / Actual: True`). Before implementation it passed vacuously in RED.
   - Why it blocks: the literal path leaves two wrong options. Either add an in-code `Contains("name")` guard (forbidden), or delete the case.
   - How I got past it: I had to find the fix in `~/.nuget/packages/vela.testing/0.28.2/lib/*/Vela.Testing.xml`, where PluginPipeline is documented as "honouring filtering attributes, execution order, pre/post images and cascade".
   - Correct path: prove filtering with `PluginPipeline.Empty().Register<AccountDefaultDescription>().Seed(new Account{Id=id, Name="Zava", AccountNumber="ab-123"})`, then `pipeline.Service.Update(new Account{Id=id, Telephone1="555"})`, then assert the stored value is unchanged and `Assert.DoesNotContain(pipeline.ExecutionLog, e => e.Message == "Update")`. `PipelineExecutionEntry` has `PluginTypeName`, `Message`, `Stage`, `Mode`, `EntityLogicalName`, `Depth`.
   - Fix for the skill: harness-api should state "PluginContext.Execute bypasses FilterOn; test filtering with PluginPipeline".
2. minor - `skills/vela-apply/SKILL.md` step 2 says "**Package** the final code: `dotnet pack` as the project defines (e.g. `-c Release`)", and `build-report-template.md` shows `dotnet pack -c Release -o artifacts`.
   - What happened: on a clean tree `dotnet pack src/Zava.Plugins/Zava.Plugins.csproj -c Release -o pack-cold` exits 0 and writes a package with only `Zava.Plugins.nuspec` (4 files, no DLL). The scaffold's own csproj says so: "`dotnet build -c Release` produces the deployable package, NOT `dotnet pack` (run cold it skips the publish and emits an assembly-less package that vela plan rejects with 'No assemblies found')". A warm pack after the Verify build did contain the DLLs, so the loop order hides the problem. With no org, `plan` is skipped and nothing would catch an empty package.
   - Correct path: `dotnet build <sln> -c Release`, then use `artifacts/<PackageId>.<Version>.nupkg` (GeneratePackageOnBuild). Check that it contains `lib/net462/<Prefix>.Plugins.dll` (`unzip -l`) before hashing.
3. minor - `vela-plan-review`, `registration-rules.md` and the scenario require PreOperation, but neither `add plugin` nor `add step` has a stage flag, and both generate `.PostOperation()` with `I<Msg>PostContext<Account>`. No skill says to edit both the chain (`.PreOperation()`) and the handler type (`ICreatePreContext` / `IUpdatePreContext`). `vela-scaffold` says generated code must work "without hand edits" and lists "about to hand-edit a generated file" as a red flag, which makes this edit ambiguous. Correct path: after `vela add`, change `.PostOperation()` to `.PreOperation()` and the handler parameter to `I<Msg>PreContext<T>` in the authored plugin. That is what was done, and it compiles.
4. minor - `harness-api.md` / `vela-test-harness` say "There is **no** `.Execute<TPlugin>()` generic". It exists: `PluginContextBuilder<T>.Execute<TPlugin>()` ("Instantiates and executes a plugin"). A probe fails with `error CS0310: 'AccountDefaultDescription' must be a non-abstract type with a public parameterless constructor`. The advice (pass an instance) is right; the reason given is wrong. Should say "`Execute<T>()` requires a parameterless ctor; scaffolded plugins don't have one."
5. minor - `vela-plugin-authoring` bans magic strings where a model exists, but gives no typed way to ask "is this column present in the Update Target (possibly as null)?". That is needed to tell "not sent" from "cleared". I had to use `target.Contains("accountnumber")`. The review then caught the Required data-loss bug the typed-only approach produces (`Target.AccountNumber ?? PreImage` resurrects a cleared value). The skill should name the sanctioned pattern (e.g. `Contains(<logical name>)`, or a Vela helper if one exists) and add the "explicit null vs absent" edge to the Update coverage list.
6. minor - `vela-scaffold` / `references/cli-surface.md` document `vela models ... --project <csproj>` ("that is the `--project` target for `vela models`"), but `vela models --help` does not list `--project` (only `--out <dir>`). The parser accepts it: with no auth it reports `Missing Dataverse auth` rather than `Unknown option`. Behaviour after the connection is unverified without an org.
7. minor - the skills say "confirm flags with `vela init --help` / `vela plan --help` / `vela sign --help`", but those print the global usage banner, not per-command help. The flags are present in that global usage, so this is not blocking. `vela add --help` and `vela models --help` are command-specific.
8. minor - `vela-plugin-authoring` opens with "put logic in the `OnExecute` handler the scaffold created". Step 3 then correctly adds `Handle<Message>` for `add step`. The intro should say "the generated handler".
9. minor - `build-report-template.md` / `vela-plan-review` do not say whether a second story on an existing plugin gets a new Canvas slug or updates the existing Canvas ("living spec"). I created `account-multi-step` covering both steps and marked the baseline Canvas `superseded`.
10. minor - `vela init` scaffolds demo Account plugins (`AccountPostCreatePlugin`, `AccountRelatedContactsPlugin`). Read literally, the reuse rule ("table already has a plugin -> prefer `vela add step`") applies to them in the baseline. No skill says to exclude or remove demo plugins from the reuse-vs-new decision.
11. minor (doc precision) - `harness-api.md` could quote the multi-step failure text an unstated trigger produces: `has no registered step matching message 'Update'`. The builder defaults to Update, so Create tests fail with this message. The skill's instruction (state the trigger) is correct.

### Environment / eval-protocol issues (not skill defects)
- E1: no org, so `vela models`, `vela plan` and `vela inspect` were skipped (commands recorded). Stand-ins were used for `description` and `accountnumber`.
- E2: no git allowed, so `vela-code-review` step 1 (`git diff <base>...HEAD`) was replaced by `diff -ru` against a post-baseline snapshot (`artifacts/multi-step.diff`). The draft PR (`gh pr create --draft`) was skipped (eval).
- E3: CLI cosmetic: after `vela add step`, the class summary still reads "Single-step plugin generated by `vela add plugin`" (I edited it).
- E4: macOS has no `timeout` binary (only affected a probe command).
- E5: incremental build pitfall during my mutation check: `mv` restored an older-mtime source and the build did not recompile. `--no-incremental` fixed it. This is a tooling nuance, not a skill defect.

## Fixes
- None yet: the pack is read-only in this run. Proposed:
  - finding 1: add a "filtering attributes are only honoured by PluginPipeline" section and recipe to `harness-api.md`, plus a red flag in `vela-test-harness`.
  - finding 2: change `vela-apply` step 2 and the template's run-trace row to `dotnet build -c Release` and the `artifacts/` package, with an `unzip -l` DLL check.
  - findings 3-11: small doc edits as described above.

## Verdict
**fail**: one blocker (finding 1). Following the harness reference literally, the scenario's own "name unchanged -> step not run" case cannot be proven without breaking the plugin-authoring rule. It needed the `PluginPipeline` filtering behaviour, which I had to rediscover from the package XML docs. Everything else in the scenario was reached without rediscovery: add-step reuse, `HandleUpdate`/`OnExecute` kept, VELA001 seen and fixed, PreOperation on Target, explicit triggers, RED then green, review PASS.

Next run must re-check:
- (a) the filter case is written with `PluginPipeline` straight from the skill;
- (b) the package step produces a DLL-bearing package from a cold tree;
- (c) the stage edit (`PreOperation` + `I<Msg>PreContext`) is guided by the skill.

## Fixes (iteration 1)

f6b5aa3 (PluginPipeline for the filter case; Update not-sent vs cleared; Execute<T> note), 21eb4e0 (dotnet build packaging), add212a (stage edit; authoring opener; demos; --help / --project notes), 7ec62f8 (one Canvas file per story)

Next: re-run this scenario against the fixed skills and record iteration 2.
