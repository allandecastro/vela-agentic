<!-- GENERATED copy of references/harness-api.md by scripts/sync-copilot.mjs. Edit the source file, not this copy. -->

# Vela.Testing harness API (verbatim)

Ground truth for writing and running harness tests. Skills point here.

## Two ways to run a plugin - pick by what the test must prove

| Test must prove | Use | Why |
| --- | --- | --- |
| what the handler does with a given target/images | `PluginContext.For<T>()...Execute(plugin)` | fast, single step |
| **whether the step fires at all** (filtering attributes, message/stage matching) | **`PluginPipeline`** | `Execute` runs the handler **regardless of `FilterOn`**; only the pipeline honours the registration |
| cascades, recursion, one plugin's write triggering another | **`PluginPipeline`** | runs every registered plugin on each write |

A "step does not fire when an unrelated column changes" test written with `Execute` passes **and
proves nothing** (verified, Vela.Testing 0.28.2). Write it with the pipeline:
```csharp
var id = Guid.NewGuid();
var p = PluginPipeline.Empty().Register<AccountNormalize>().Seed(new Account { Id = id, Name = "orig" });
p.Service.Update(new Account { Id = id, Revenue = new Money(2m) });   // filtered column (Name) not sent
Assert.Empty(p.ExecutionLog);                                          // the step did not fire
p.Service.Update(new Account { Id = id, Name = "changed" });
var run = Assert.Single(p.ExecutionLog);                               // it fired once
Assert.Equal("Update", run.Message);                                   // entries: PluginTypeName, Message, Stage,
                                                                       // Mode, EntityLogicalName, Depth
```

## Generated test shape (`vela add test <Name> --kind plugin --entity <Entity>`)

```csharp
using System;
using Microsoft.Xrm.Sdk;
using Microsoft.Xrm.Sdk.Query;
using Vela.Testing;
using Xunit;

public sealed class <Name>Tests
{
    [Fact]
    public void Executes()
    {
        // Arrange: in-memory Dataverse the plugin's injected IOrganizationService writes to.
        InMemoryOrganizationService crm = new InMemoryOrganizationService();
        Account target = new Account { Id = Guid.NewGuid() };

        // Act: a single-step plugin auto-derives message/stage/mode from its registration.
        // For a MULTI-step plugin only, state it: .OnUpdate().Stage(...).Mode(...)
        // (otherwise: "has no registered step matching message 'Update'").
        PluginContext.For<Account>()
            .WithTarget(target)
            .WithOrganizationService(crm)
            .Execute(new <Name>(string.Empty, string.Empty));   // instance, (unsecure, secure) ctor

        // Assert (the generated comment shows a "task"/"subject" example; what to assert is below):
        // PreOperation -> check `target` (the plugin edited ctx.Request.Target) and that crm got no extra
        // write. Writes to OTHER records -> read them back from crm and check fields.
        // var rows = crm.RetrieveMultiple(new QueryExpression("account") { ColumnSet = new ColumnSet(true) });
        // var row = Assert.Single(rows.Entities);
        // Assert.Equal("expected", row.GetAttributeValue<string>("description"));
    }
}
```

Critical, easy-to-get-wrong facts:
- `.Execute(...)` takes a **plugin instance**: `new <Plugin>(string.Empty, string.Empty)`. (A generic
  `.Execute<TPlugin>()` exists but needs a public parameterless ctor, which generated plugins don't
  have - `CS0310`. Pass an instance.)
- `.Execute(...)` **ignores `FilterOn` - and the registered stage/mode**: it always runs the handler.
  A step wrongly registered Async/PostOperation still "passes" an `Execute` test; only the pipeline
  (which persists what the step really does) shows the edit is lost. Test "fires / does not fire" and
  "the value is actually saved" with `PluginPipeline` (above).
- The ctor is `(unsecureConfig, secureConfig)` - pass `string.Empty, string.Empty` when unused.
- Do **not** chain `.OnUpdate().Stage().Mode()` for a single-step plugin; it auto-derives.
  Only restate the trigger for multi-step plugins.
- **Bulk (`*Multiple`) tests** (verified, 0.29.3): seed the batch with `WithTargets(...)` - for a
  single-step plugin that alone is enough (the trigger is derived); otherwise state it with the stage
  **the step is registered at**, e.g. `.OnMessage("UpdateMultiple").Stage(PluginStages.PreOperation)`
  (a stage that doesn't match gives "has no registered step matching message 'UpdateMultiple'").
  `WithTargets(params T[])` keeps your instances, so assert on them. To prove what is saved, use the
  pipeline: `p.Service.Execute(new UpdateMultipleRequest { Targets = ... })` fires the step once for
  the batch; a single `p.Service.Update(...)` fires an UpdateMultiple step too (merged pipeline).
- **Associate tests** (verified, 0.29.3): declare the relationship, then associate through the pipeline:
  `PluginPipeline.Empty().Register<P>().WithManyToMany("listcontact_association", "listmember", "list",
  "listid", "contact", "entityid")...; p.Service.Associate("contact", contactId, new
  Relationship("listcontact_association"), refs)`. The pipeline fires an Associate step **only when the
  association's target table is the plugin's table** - test both directions. (A bare `Execute` proves
  nothing about firing.) The test `vela add test` generates for an Associate plugin (`WithTarget(new
  Contact ...)`) is meaningless for Associate - replace it with a pipeline test.
- **Images:** `.WithPreImage(preImage)` - the alias is optional and defaults to the one `ctx.PreImage`
  reads. `Execute` ignores the image *registration* too (a test passes even if `WithPreImage` was
  removed from the step); the pipeline builds the pre-image from the seeded row, so an image-dependent
  case also needs a `PluginPipeline` test.
- Assert by reading records back from `crm`, not by counting calls.
- **PreOperation (the usual case - a column of the same record):** assert on the `target` you passed -
  the plugin's edit of `ctx.Request.Target` lands on it - and that `crm` received no extra write
  (`Assert.Empty(crm.GetAll("account"))`): the platform, not the plugin, does the create.
- "Already correct → nothing re-set" in PreOperation is not observable from outside (the column was
  sent, so it is on the target either way): don't assert on trace text; cover it by design review and
  record it as a Canvas note.
- **PostOperation writing to another record** - `ctx.PrimaryEntityId` in the harness is a random id,
  **not** `target.Id`. The new record's id is `target.Id` (set it, e.g. `new Account { Id =
  Guid.NewGuid() }`); use `target.Id`, not `ctx.PrimaryEntityId`, or a retrieve will "not exist".

- `.Execute(plugin)` auto-derives the trigger of a single-step plugin; **`.Build()` does not** (it
  defaults to Update). When you `Build()` a context to inspect it (e.g. read
  `context.PluginExecutionContext.InputParameters["Target"]`), state the trigger:
  `.OnCreate().Stage(PluginStages.PreOperation)` (`using Vela.Constants;`).
- Execution depth: `.Depth(n)` on the builder (the framework's recursion guard throws above 8).

Builder entry points (`Vela.Testing.PluginContext`): `PluginContext.For<TEntity>()` for entity
plugins; `PluginContext.ForMessage("<uniquename>")` for custom APIs / message-only.

Custom API test recipe (complete - the parts that are easy to miss):
```csharp
var crm = new InMemoryOrganizationService();
crm.Seed(new Account { Id = accId, Name = "Zava", Revenue = new Money(2_000_000m) });
var context = PluginContext.ForMessage("adc_ScoreLead")
    .WithOrganizationService(crm)                 // only when the handler reads/writes through an org service
    .Build();
context.PluginExecutionContext.InputParameters["email"] = "exec@fortune500.com";   // set inputs here
api.Execute(context.ServiceProvider);             // run the Custom API instance
Assert.Equal(55, context.PluginExecutionContext.OutputParameters["leadScore"]);    // assert outputs
```
When the handler uses an org service (e.g. `ctx.GetRequiredService<IOrganizationService>()` for a revenue or duplicate check), pass `.WithOrganizationService(crm)` before `Build()`, or those lookups have nothing to read. A pure computation needs none.

- `vela add test <Name> --kind customapi` generates the minimal shape (`PluginContext.ForMessage("<prefix>_<Name>").Build()`, no org service); add `.WithOrganizationService(crm)` only if the handler needs it.
- **Typed / bound** Custom APIs are tested the same way, with the **plain parameter names**:
  `InputParameters["Factor"] = 2m` → `OutputParameters["Total"]` (verified, 0.28.2).
- The harness does **not** enforce `optional: false`: the handler must check the input and throw
  itself. A missing required input should throw `InvalidPluginExecutionException` - test it:
  `Assert.Throws<InvalidPluginExecutionException>(() => api.Execute(context.ServiceProvider))`.

Trigger and image signatures (`PluginContextBuilder<T>`): `.OnCreate()` / `.OnUpdate()` / ...,
`.Stage(PluginStages x)` (`Vela.Constants`), `.Mode(ExecutionMode x)` (`Vela.Steps`) or `.Sync()` /
`.Async()` - the stage alone is usually enough to match the step - and `.WithPreImage(entity, alias)` /
`.WithPostImage(entity, alias)`.

Reading traces and the execution log: `ctx.Trace(...)` lines land in `builder.TraceCapture.Traces` (a
`RecordingTracingService`) and, for a pipeline, `pipeline.Trace` (whole cascade). Assert on them or on
`pipeline.ExecutionLog` (`Assert.Single` / `Assert.Empty`), or print with `Console.WriteLine` -
`ITestOutputHelper` output is not shown by the Mono console runner for passing tests.

Builder methods you'll use: `WithTarget`, `WithPreImage`, `WithPostImage`, `WithPrimaryEntity`,
`WithOrganizationService(crm)` (also `WithUserService`, `WithSystemService`),
`WithInputParameter`/`WithOutputParameter`, then `Execute(...)`. For cascades use
`PluginPipeline.FromAssemblyOf<T>()`, `Register<TPlugin>()`, `Seed(...)`, write through
`pipeline.Service`, inspect `pipeline.ExecutionLog`.

Recursion / cascade recipe - `PluginPipeline` runs every registered plugin on each write made through
`pipeline.Service`, so a self-triggering plugin actually recurses (verified, 0.28.2):
```csharp
var id = Guid.NewGuid();
var pipeline = PluginPipeline.Empty().Register<AccountNormalize>().Seed(new Account { Id = id, Name = "x" });
pipeline.Service.Update(new Account { Id = id, Name = "  Hello   world  " });   // a write-back loop throws "...prevent recursion"
var row = pipeline.Service.Retrieve("account", id, new ColumnSet("name"));
Assert.Equal("Hello world", row.GetAttributeValue<string>("name"));
```
Use it whenever a step writes a column that could re-trigger it: the test fails on recursion.

## InMemoryOrganizationService

`Vela.Testing.InMemoryOrganizationService` - a stateful in-memory `IOrganizationService`.
- Seed: `.Seed(params Entity[])`; read all: `.GetAll(logicalName)`. An `Update` needs the record to
  exist first: `Seed` it (with its id) before `Execute`, or the `Update` throws "does not exist". (If
  you find yourself seeding the record a Create plugin just created so it can update it, the step
  should probably be PreOperation - see `registration-rules.md`.)
- Full `IOrganizationService`: Create/Retrieve/Update/Delete/RetrieveMultiple/Execute/
  Associate/Disassociate. RetrieveMultiple supports QueryExpression, QueryByAttribute, FetchExpression.
- Configure: `.WithCurrentUser(Guid)`, `.WithSecurity(...)`, `.WithClock(...)`,
  `.WithAlternateKey(...)`, `.WithManyToMany(...)`, `.WithRelationship(...)`, `.WithAutoNumber(...)`,
  `.AsElastic()`/`.AsVirtual()`, `.WithEntityMetadata(...)`.
- For anything it can't model, inject your own `IOrganizationService` via `WithOrganizationService`.

## Running the tests

Test projects target **net462**. The runner depends on the OS:

- **Windows:** `dotnet test <path>.Tests.csproj -c Release`.
- **macOS / Linux (arm64 or x64):** `dotnet test` **fails** - .NET has no net-framework test
  host (`testhost.arm64.exe` missing). Run under **Mono + xunit console** instead:
  The runner is not part of the scaffold. If `~/.nuget/packages/xunit.runner.console/2.9.2/` is
  missing, restore it once by adding `<PackageReference Include="xunit.runner.console" Version="2.9.2"
  PrivateAssets="all" />` to the test project (verified: a restore drops `tools/net462/xunit.console.exe`
  there).
  ```bash
  dotnet build <path>.Tests.csproj -c Release
  mono ~/.nuget/packages/xunit.runner.console/2.9.2/tools/net462/xunit.console.exe \
    <path>/bin/Release/net462/<Name>.Tests.dll -parallel none
  ```
  **Always pass `-parallel none` on Mono.** A native `mono-sgen` segv ("Got a segv") without it
  is an environment crash from parallel assembly loading, **not** a test failure - the suite
  passes serially.
- If you built against a stale package, purge `vela.testing` under `~/.nuget` and rebuild.
