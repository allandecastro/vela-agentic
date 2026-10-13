# Vela.Testing harness API (verbatim)

Ground truth for writing and running harness tests. Skills point here. Every snippet below was compiled and
run under the Mono runner against vela 0.25.0 / Vela.Testing 0.34.0 (net48).

## Two ways to run a plugin - pick by what the test must prove

| Test must prove | Use | Why |
| --- | --- | --- |
| what the handler does with a given target/images | `PluginContext.For<T>()...Execute(...)` | fast, single step |
| **whether the step fires at all** (filtering attributes, message/stage matching, relationship scope) | **`PluginPipeline`** | `Execute` runs the handler **regardless of `FilterOn`, the registered stage/mode and the registered images**; only the pipeline honours the registration |
| what is actually **saved**, cascades, recursion, async steps | **`PluginPipeline`** | runs every registered step around each write, commits, then runs async steps |

A "step does not fire when an unrelated column changes" test written with `Execute` passes **and
proves nothing** (re-verified, 0.34.0). Write it with the pipeline:
```csharp
var id = Guid.NewGuid();
var p = PluginPipeline.Empty().Register<AccountNormalize>().Seed(new Account { Id = id, Name = "orig" });
p.Service.Update(new Account { Id = id, Revenue = new Money(2m) });   // filtered column (Name) not sent
Assert.Empty(p.ExecutionLog);                                          // the step did not fire
p.Service.Update(new Account { Id = id, Name = "changed" });
var run = Assert.Single(p.ExecutionLog);                               // it fired once
Assert.True(run.HandlerInvoked);                                       // entries: PluginTypeName, Message, Stage, Mode,
Assert.Equal("Update", run.Message);                                   // EntityLogicalName, Depth, HandlerInvoked,
Assert.Equal(PluginStages.PreOperation, run.Stage);                    // SkipReason (null unless skipped)
var row = Assert.Single(p.GetAll("account"));                          // what was saved
Assert.Equal("changed", row.GetAttributeValue<string>("name"));
```

## Generated test shape (`vela add test <Name> --kind plugin --entity <Entity> --message <M>`, run in the test project)

```csharp
[Fact]
public void Fires_On_Update()
{
    // Arrange: Empty().Register<T>() scopes the pipeline to this plugin (FromAssemblyOf<T>() takes them all).
    PluginPipeline pipeline = PluginPipeline.Empty().Register<<Name>>();

    // Act: send the Update the step is registered on.
    Guid id = Guid.NewGuid();
    pipeline.Seed(new Account { Id = id });
    // The step filters on Name, so the request sets it (TODO: give it a real value).
    pipeline.Service.Update(new Account { Id = id, Name = default });

    // Assert: the step fired. What the handler does is the next test's job.
    Assert.Contains(pipeline.ExecutionLog, e => e.PluginTypeName == typeof(<Name>).FullName && e.Message == "Update");
}

[Fact(Skip = "TODO: assert what <Name> does")]
public void Does_What_It_Should() { /* seed, send the request, read back what the plugin wrote */ }
```
The generated `Fires_On_*` test only proves the step fired. Give the filtered column a real value, then
un-skip `Does_What_It_Should` and fill it with assertions on what the plugin does (below) - the acceptance
cases live there, plus the negative "does not fire" cases.

Critical, easy-to-get-wrong facts:
- Run a step with an instance, `.Execute(new <Plugin>(string.Empty, string.Empty))`, or with
  **`.Execute<TPlugin>()`**, which works on the generated `(unsecureConfig, secureConfig)` ctor since
  Vela.Testing 0.33.0 and returns the instance.
- `.Execute(...)` **ignores `FilterOn`, the registered stage/mode and the registered images**: it always
  runs the handler (verified: an Async step's handler runs inline; a handler that reads a pre-image the step
  never registers still gets the one the test passes). Test "fires / does not fire", "the value is actually
  saved" and "the image is there" with `PluginPipeline`.
- **Trigger:** a single-step plugin derives it - don't chain `.OnUpdate().Stage()...`. A **multi-step**
  plugin needs the message of the step under test: `.OnCreate()` / `.OnUpdate()` resolves the single step
  registered on that message (verified, 0.34.0); several matching steps, or none, throw with the list -
  then add `.Stage(PluginStages.PreOperation)` (`using Vela.Constants;`). No trigger at all on a
  multi-step plugin throws. The pipeline needs none of this: it dispatches each write to the matching step.
- **Bulk (`*Multiple`):** seed the batch with `WithTargets(params T[])` (or an `EntityCollection`) - for a
  single-step plugin that alone is enough; otherwise
  `.OnMessage("UpdateMultiple").Stage(PluginStages.PreOperation)`. `WithTargets(params T[])` keeps your
  instances, so assert on them. To prove what is saved, use the pipeline:
  `p.Service.Execute(new UpdateMultipleRequest { Targets = ... })` (`using Microsoft.Xrm.Sdk.Messages;`) fires
  the step once for the batch; a single `p.Service.Update(...)` fires an UpdateMultiple step too.
  `vela add test <Plugin> --message UpdateMultiple` generates that pipeline `UpdateMultipleRequest` test.
- **Associate / Disassociate** (verified, 0.34.0): the step is **message-level** - the pipeline fires it
  whichever table the call is issued from (`run.EntityLogicalName` is that side; a Contact plugin's step
  also runs with an `account` Target when associated from the account side - see `dataverse-gotchas.md`).
  A step scoped with `.ForRelationship("<schema>")` is still logged on any other relationship, with
  `HandlerInvoked == false` and `SkipReason` "Vela: relationship outside the step's ForRelationship scope;
  nothing to run." - assert on that for the out-of-scope case. `vela add test --message Associate`
  generates a real pipeline Associate (`WithManyToMany(...)` + `Service.Associate(...)`): replace its
  `todo_relationship` / `todo_intersect` / `todo_*id` placeholders with the real relationship, e.g.:
  ```csharp
  Guid contactId = Guid.NewGuid(), listId = Guid.NewGuid();
  var p = PluginPipeline.Empty().Register<ListMemberAdded>()
      .WithManyToMany("listcontact_association", "listmember", "list", "listid", "contact", "entityid")
      .Seed(new Contact { Id = contactId }, new Entity("list", listId));
  p.Service.Associate("contact", contactId, new Relationship("listcontact_association"),
      new EntityReferenceCollection { new EntityReference("list", listId) });
  var run = Assert.Single(p.ExecutionLog);
  Assert.Equal("Associate", run.Message);
  Assert.True(run.HandlerInvoked);                                       // False + SkipReason on another relationship
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
  `ctx.PrimaryEntityId` follows the Target's id (verified, 0.34.0), so seed that row before `Execute`;
  `.WithPrimaryEntity(...)` only to override it. The pipeline uses the real ids.
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
Vela's `CustomApiRequest` / `CustomApiResponse` subclasses for a Custom API you author (used with
`CustomApiBase<TRequest, TResponse>`, see `plugin-authoring-api.md`), or `OrganizationRequest` /
`OrganizationResponse` subclasses generated by `vela models --custom-apis` for one that exists in the org.
When the handler uses an org service (a revenue or duplicate check), pass `.WithOrganizationService(crm)`,
or those lookups have nothing to read. A pure computation needs none.

- `vela add test <Name> --kind customapi` generates two tests: the definition builds under its unique name
  (`new <Api>(string.Empty, string.Empty).GetCustomApiDefinition().UniqueName`), and a
  `[Fact(Skip = "TODO: set the inputs ...")]` test that every declared output is set
  (`PluginContext.ForMessage("<prefix>_<Name>")` for a global API, `PluginContext.ForRequest(new
  <Name>Request { ... })` + a `Target` for a typed bound one; `builder.Context.OutputParameters`). Set the
  inputs (`.WithInputParameter("Name", value)` or the request's properties), remove `Skip`, and assert
  the values, not only their presence.
- Parameters use their **plain names**: `InputParameters["Discount"]` → `OutputParameters["Value"]`.
- A missing required input (`optional: false`) throws as on Dataverse (verified, 0.34.0), through the
  pipeline and `builder.Execute(api)`: `FaultException<OrganizationServiceFault>` "Required field 'AccountId'
  is missing for RequestName='<prefix>_<Name>'" (`using System.ServiceModel;`) - test it:
  `Assert.Throws<FaultException<OrganizationServiceFault>>(() => p.Service.Execute(new EstimateValueRequest()))`.
  Recipe 1 (`.Build()` + `api.Execute(context.ServiceProvider)`) skips that validation.

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
`pipeline.Service`, so a self-triggering plugin actually recurses (verified, 0.34.0):
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
