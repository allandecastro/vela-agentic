<!-- GENERATED copy of references/harness-api.md by scripts/sync-copilot.mjs. Edit the source file, not this copy. -->

# Vela.Testing harness API (verbatim)

Ground truth for writing and running harness tests. Skills point here. Every snippet below was compiled and
run under the Mono runner against vela 0.24.1 / Vela.Testing 0.33.0 (net48).

## Two ways to run a plugin - pick by what the test must prove

| Test must prove | Use | Why |
| --- | --- | --- |
| what the handler does with a given target/images | `PluginContext.For<T>()...Execute(...)` | fast, single step |
| **whether the step fires at all** (filtering attributes, message/stage matching, relationship scope) | **`PluginPipeline`** | `Execute` runs the handler **regardless of `FilterOn`, the registered stage/mode and the registered images**; only the pipeline honours the registration |
| what is actually **saved**, cascades, recursion, async steps | **`PluginPipeline`** | runs every registered step around each write, commits, then runs async steps |

A "step does not fire when an unrelated column changes" test written with `Execute` passes **and
proves nothing** (re-verified, 0.33.0). Write it with the pipeline:
```csharp
var id = Guid.NewGuid();
var p = PluginPipeline.Empty().Register<AccountNormalize>().Seed(new Account { Id = id, Name = "orig" });
p.Service.Update(new Account { Id = id, Revenue = new Money(2m) });   // filtered column (Name) not sent
Assert.Empty(p.ExecutionLog);                                          // the step did not fire
p.Service.Update(new Account { Id = id, Name = "changed" });
var run = Assert.Single(p.ExecutionLog);                               // it fired once
Assert.Equal("Update", run.Message);                                   // entries: PluginTypeName, Message, Stage,
Assert.Equal(PluginStages.PreOperation, run.Stage);                    // Mode, EntityLogicalName, Depth
var row = Assert.Single(p.GetAll("account"));                          // what was saved
Assert.Equal("changed", row.GetAttributeValue<string>("name"));
```

## Generated test shape (`vela add test <Name> --kind plugin --entity <Entity>`, run in the test project)

```csharp
[Fact]
public void Runs_Its_Handler()
{
    // Arrange: an in-memory Dataverse the plugin's injected IOrganizationService reads and writes.
    InMemoryOrganizationService crm = new InMemoryOrganizationService();
    Account target = new Account { Id = Guid.NewGuid() };

    // Act: a single-step plugin derives its trigger (message/stage/mode) from its own registration. For a
    // multi-step plugin, select the step under test: .OnUpdate().Stage(PluginStages.PostOperation).Sync().
    PluginContextBuilder<Account> builder = PluginContext.For<Account>()
        .WithTarget(target)
        .WithOrganizationService(crm);
    builder.Execute(new <Name>(string.Empty, string.Empty));

    // Assert: the handler ran (the scaffolded one traces this line). Replace it ...
    Assert.Contains("<Name> executed", builder.TraceCapture.Output);
}
```
The generated assertion only proves the scaffold's trace line ran - it fails as soon as you replace the
handler body. Replace it with assertions on what the plugin does (below).

Critical, easy-to-get-wrong facts:
- Run a step with an instance, `.Execute(new <Plugin>(string.Empty, string.Empty))`, or with
  **`.Execute<TPlugin>()`**, which works on the generated `(unsecureConfig, secureConfig)` ctor since
  Vela.Testing 0.33.0 and returns the instance.
- `.Execute(...)` **ignores `FilterOn`, the registered stage/mode and the registered images**: it always
  runs the handler (verified: an Async step's handler runs inline; a handler that reads a pre-image the step
  never registers still gets the one the test passes). Test "fires / does not fire", "the value is actually
  saved" and "the image is there" with `PluginPipeline`.
- **Trigger:** a single-step plugin derives it - don't chain `.OnUpdate().Stage()...`. A **multi-step**
  plugin needs the message **and** the stage of the step under test:
  `.OnUpdate().Stage(PluginStages.PreOperation)` (`using Vela.Constants;`). The message alone is not enough
  (the stage defaults to PostOperation): `.OnCreate()` on a PreOperation Create step throws "has no
  registered step matching message 'Create'"; no trigger at all throws "... matching message 'Update'".
  The pipeline needs none of this: it dispatches each write to the matching step.
- **Bulk (`*Multiple`):** seed the batch with `WithTargets(params T[])` (or an `EntityCollection`) - for a
  single-step plugin that alone is enough; otherwise
  `.OnMessage("UpdateMultiple").Stage(PluginStages.PreOperation)`. `WithTargets(params T[])` keeps your
  instances, so assert on them. To prove what is saved, use the pipeline:
  `p.Service.Execute(new UpdateMultipleRequest { Targets = ... })` (`using Microsoft.Xrm.Sdk.Messages;`) fires
  the step once for the batch; a single `p.Service.Update(...)` fires an UpdateMultiple step too.
  `vela add test <Plugin> --message UpdateMultiple` generates `WithTargets(...)`.
- **Associate / Disassociate** (verified, 0.33.0): the step is **message-level** - the pipeline fires it
  whichever table the call is issued from (`run.EntityLogicalName` is that side). A step scoped with
  `.ForRelationship("<schema>")` skips its handler on any other relationship, **but `ExecutionLog` still
  records the dispatch** (the trace says "relationship outside the step's ForRelationship scope") - assert
  on the handler's effect or trace, not on `ExecutionLog`, for the out-of-scope case. The test `vela add
  test --message Associate` generates (`WithTarget(new Contact ...)`) proves nothing - replace it:
  ```csharp
  Guid contactId = Guid.NewGuid(), listId = Guid.NewGuid();
  var p = PluginPipeline.Empty().Register<ListMemberAdded>()
      .WithManyToMany("listcontact_association", "listmember", "list", "listid", "contact", "entityid")
      .Seed(new Contact { Id = contactId }, new Entity("list", listId));
  p.Service.Associate("contact", contactId, new Relationship("listcontact_association"),
      new EntityReferenceCollection { new EntityReference("list", listId) });
  Assert.Equal("Associate", Assert.Single(p.ExecutionLog).Message);
  Assert.Contains("ListMemberAdded executed", p.Trace.Output);
  ```
- **Images:** `.WithPreImage(preImage)` - the alias is optional and defaults to the one `ctx.PreImage`
  reads. The pipeline builds the pre-image from the seeded row, **only if the step registers it** - so an
  image-dependent case also needs a pipeline test:
  ```csharp
  var p = PluginPipeline.Empty().Register<AccountRevenueGuard>().Seed(new Account { Id = id, Revenue = new Money(10m) });
  Assert.Throws<InvalidPluginExecutionException>(() => p.Service.Update(new Account { Id = id, Revenue = new Money(5m) }));
  Assert.Equal(10m, p.GetAll("account").Single().GetAttributeValue<Money>("revenue").Value);   // rolled back
  ```
- **Async steps:** the pipeline runs them **after the outermost operation commits**, and never when it rolls
  back. An async failure is **not thrown** to the caller (as on Dataverse, it is a failed system job): it is
  recorded in `p.AsyncStepFailures`, and the triggering write stays saved.
  ```csharp
  p.Service.Update(new Account { Id = id, Name = "b" });                 // no throw even if the async step fails
  var run = Assert.Single(p.ExecutionLog);
  Assert.Equal(ExecutionMode.Asynchronous, run.Mode);                    // using Vela.Steps;
  Assert.Empty(p.AsyncStepFailures);                                     // or Assert.Single(...) for a failure case
  Assert.Equal("renamed", p.GetAll("account").Single().GetAttributeValue<string>("description"));
  ```
- Assert by reading records back (`crm.GetAll("account")`, `p.GetAll("account")`, `Retrieve`), not by
  counting calls.
- **PreOperation (the usual case - a column of the same record):** assert on the `target` you passed -
  the plugin's edit of `ctx.Request.Target` lands on it - and that `crm` received no extra write
  (`Assert.Empty(crm.GetAll("account"))`): the platform, not the plugin, does the create.
- "Already correct → nothing re-set" in PreOperation is not observable from outside (the column was
  sent, so it is on the target either way): don't assert on trace text; cover it by design review and
  record it as a Canvas note.
- **A handler that writes by `ctx.PrimaryEntityId`** (PostOperation, async): in a `PluginContext` test
  `ctx.PrimaryEntityId` is a random id, **not** `target.Id`, so the write throws "account With Id = ... Does
  Not Exist". Pass `.WithPrimaryEntity("account", target.Id)` (and seed that row), or use the pipeline,
  where the ids are real.
- `.Build()` does **not** derive the trigger (it defaults to Update / PostOperation / Sync);
  `.Build<TPlugin>()` and `.Build(plugin)` derive it from a single-step plugin, like `Execute`. Use them
  when you build a context to inspect it (`context.PluginExecutionContext.InputParameters["Target"]`).
- Execution depth: `.Depth(n)` on the builder; above 8 the framework's guard throws "Plugin execution
  stopped to prevent recursion." (the pipeline's cap: `WithMaxDepth(n)`, default 8).

Builder entry points (`Vela.Testing.PluginContext`): `PluginContext.For<TEntity>()` for entity
plugins; `PluginContext.ForMessage("<uniquename>")` for custom APIs / message-only;
`PluginContext.ForRequest(request)` for a typed request (message and inputs come from the request).

Custom API test recipes:
```csharp
// 1. Raw context - set inputs, run the instance, read outputs.
var context = PluginContext.ForMessage("adc_EstimateValue")
    .WithOrganizationService(crm)                 // only when the handler reads/writes through an org service
    .Build();
context.PluginExecutionContext.InputParameters["AccountId"] = accountId;
context.PluginExecutionContext.InputParameters["Discount"] = 1m;
api.Execute(context.ServiceProvider);
Assert.Equal(999m, context.PluginExecutionContext.OutputParameters["Value"]);

// 2. Typed request through the builder.
var builder = PluginContext.ForRequest(new EstimateValueRequest { AccountId = accountId, Discount = 100m });
builder.Execute(api);
Assert.Equal(900m, builder.Context.OutputParameters["Value"]);

// 3. Through the pipeline, typed response (using Vela.Context; for ToResponse).
var p = PluginPipeline.Empty().Register<EstimateValueApi>();
EstimateValueResponse response = p.Service
    .Execute(new EstimateValueRequest { AccountId = accountId, Discount = 100m })
    .ToResponse<EstimateValueResponse>();
Assert.Equal(900m, response.Value);
```
`pipeline.Service.Execute(...)` returns a base `OrganizationResponse` that cannot be cast to the typed one;
`.ToResponse<T>()` views it as `T` over the same results. The typed request/response classes are
`OrganizationRequest` / `OrganizationResponse` subclasses (e.g. generated by `vela models --custom-apis`).
When the handler uses an org service (a revenue or duplicate check), pass `.WithOrganizationService(crm)`,
or those lookups have nothing to read. A pure computation needs none.

- `vela add test <Name> --kind customapi` generates two tests: the definition builds under its unique name
  (`new <Api>(string.Empty, string.Empty).GetCustomApiDefinition().UniqueName`), and every declared output is
  set (`PluginContext.ForMessage("<prefix>_<Name>")`, `builder.Context.OutputParameters`). Add inputs with
  `.WithInputParameter("Name", value)` and assert the values, not only their presence.
- Parameters use their **plain names**: `InputParameters["Discount"]` → `OutputParameters["Value"]`.
- The harness does **not** enforce `optional: false` (re-verified, 0.33.0: a missing required input does not
  throw): the handler must check the input and throw itself. A missing required input should throw
  `InvalidPluginExecutionException` - test it:
  `Assert.Throws<InvalidPluginExecutionException>(() => api.Execute(context.ServiceProvider))`.

Trigger and image signatures (`PluginContextBuilder<T>`): `.OnCreate()` / `.OnUpdate()` / `.OnDelete()` /
`.OnMessage("<name>")`, `.Stage(PluginStages x)` (`Vela.Constants`), `.Mode(ExecutionMode x)`
(`Vela.Steps`) or `.Sync()` / `.Async()`, and `.WithPreImage(entity, alias)` / `.WithPostImage(entity,
alias)`; bulk: `.WithBulkPreImages(...)` / `.WithBulkPostImages(...)` (aligned by target index).

Reading traces and the execution log: `ctx.Trace(...)` lines land in `builder.TraceCapture` (a
`RecordingTracingService`: `.Output` joined text, `.Traces` lines) and, for a pipeline, `pipeline.Trace`
(whole cascade). Assert on them or on `pipeline.ExecutionLog` (`Assert.Single` / `Assert.Empty`), or print
with `Console.WriteLine` - `ITestOutputHelper` output is not shown by the Mono console runner for passing tests.

Builder methods you'll use: `WithTarget`, `WithTargets`, `WithPreImage`, `WithPostImage`,
`WithPrimaryEntity`, `WithOrganizationService(crm)` (also `WithUserService`, `WithSystemService`),
`WithInputParameter`/`WithOutputParameter`, `Depth`, then `Execute(...)` / `Execute<TPlugin>()`.
Pipeline: `PluginPipeline.Empty()` + `Register<TPlugin>()` (or `FromAssemblyOf<T>()` for every plugin in
an assembly), `Seed(...)`, write through `pipeline.Service`, inspect `ExecutionLog`, `GetAll(table)`,
`Trace`, `AsyncStepFailures`; configure with `WithManyToMany(...)`, `WithSecureConfig(name, value)` (a step's
`WithSecureConfigFrom(name)`), `WithMaxDepth(n)`.

Recursion / cascade recipe - `PluginPipeline` runs every registered plugin on each write made through
`pipeline.Service`, so a self-triggering plugin actually recurses (verified, 0.33.0):
```csharp
var id = Guid.NewGuid();
var pipeline = PluginPipeline.Empty().Register<AccountNormalize>().Seed(new Account { Id = id, Name = "x" });
pipeline.Service.Update(new Account { Id = id, Name = "  Hello   world  " });
var row = pipeline.Service.Retrieve("account", id, new ColumnSet("name"));
Assert.Equal("Hello world", row.GetAttributeValue<string>("name"));
```
A write-back loop throws `InvalidPluginExecutionException` "Vela pipeline stopped at depth 9 (cap 8).
Likely infinite recursion between plugins." Use the pipeline whenever a step writes a column that could
re-trigger it: the test fails on recursion.

## InMemoryOrganizationService

`Vela.Testing.InMemoryOrganizationService` - a stateful in-memory `IOrganizationService`.
- Seed: `.Seed(params Entity[])`; read all: `.GetAll(logicalName)`. An `Update` needs the record to
  exist first: `Seed` it (with its id) before `Execute`, or the `Update` throws "account With Id = ... Does
  Not Exist". (If you find yourself seeding the record a Create plugin just created so it can update it,
  the step should probably be PreOperation - see `registration-rules.md`.)
- Full `IOrganizationService`: Create/Retrieve/Update/Delete/RetrieveMultiple/Execute/
  Associate/Disassociate. RetrieveMultiple supports QueryExpression, QueryByAttribute, FetchExpression.
- Configure: `.WithCurrentUser(Guid)`, `.WithSecurity(...)`, `.WithClock(...)`,
  `.WithAlternateKey(...)`, `.WithManyToMany(...)`, `.WithRelationship(...)`, `.WithAutoNumber(...)`,
  `.AsElastic()`/`.AsVirtual()`, `.WithEntityMetadata(...)`. The pipeline exposes the same configuration.
- For anything it can't model, inject your own `IOrganizationService` via `WithOrganizationService`.

## Running the tests

Plugin and test projects target **net48** (`Vela.Testing` is a net462 package, consumed from net48). The
runner depends on the OS:

- **Windows:** `dotnet test <path>.Tests.csproj -c Release`.
- **macOS / Linux (arm64 or x64):** `dotnet test` **fails** - .NET has no .NET Framework test host. Run
  under **Mono + xunit console** instead. The runner is not part of the scaffold: if
  `~/.nuget/packages/xunit.runner.console/2.9.2/` is missing, restore it once by adding
  `<PackageReference Include="xunit.runner.console" Version="2.9.2" PrivateAssets="all" />` to the test
  project.
  ```bash
  dotnet build <Solution>.sln -c Release
  mono ~/.nuget/packages/xunit.runner.console/2.9.2/tools/net472/xunit.console.exe \
    tests/<P>.Plugins.Tests/bin/Release/net48/<P>.Plugins.Tests.dll -parallel none
  ```
  Success is the summary line `Total: N, Errors: 0, Failed: 0, Skipped: 0`. **Always pass `-parallel none`
  on Mono.** A native `mono-sgen` segv ("Got a segv") without it is an environment crash from parallel
  assembly loading, **not** a test failure - the suite passes serially.
- If you built against a stale package, purge `vela.testing` under `~/.nuget` and rebuild.
