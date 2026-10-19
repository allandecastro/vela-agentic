# Vela.Testing harness API (verbatim)

Ground truth for writing and running harness tests. Skills point here. Snippets were compiled and run under
the Mono runner (net48). For other members, read the IntelliSense on `PluginContext` / `PluginPipeline` - a
failing build or probe test tells you.

## Two ways to run a plugin - pick by what the test must prove

| Test must prove | Use | Why |
| --- | --- | --- |
| what the handler does with a given target/images | `PluginContext.For<T>()...Execute(...)` | fast, single step |
| **whether the step fires at all** (filtering attributes, message/stage matching, relationship scope) | **`PluginPipeline`** | `Execute` runs the handler **regardless of `FilterOn`, the registered stage/mode and the registered images** (an Async handler runs inline; an unregistered pre-image you pass is still there); only the pipeline honours the registration |
| what is actually **saved**, cascades, recursion, async steps | **`PluginPipeline`** | runs every registered step around each write, commits, then runs async steps |

A "does not fire when an unrelated column changes" test written with `Execute` passes **and proves
nothing**. Write it with the pipeline:
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
var row = Assert.Single(p.GetAll(Account.EntityLogicalNameValue)).ToEntity<Account>();   // what was saved, typed
Assert.Equal("changed", row.Name);
```

## The generated test (`vela add test`)

It generates a pipeline `Fires_On_*` test (proves only that the step fired) and a skipped
`Does_What_It_Should`. Give the filtered column a real value (it is `default` + a TODO), then un-skip
`Does_What_It_Should` and put the acceptance cases there, plus the negative "does not fire" cases.  Every
test needs its functional justification: tag the generated `Fires_On_*` test with the case whose trigger it
proves (e.g. the Create case) - never leave it untagged, never delete it to dodge the rule.

## Easy-to-get-wrong facts

- Run a step with `.Execute(new <Plugin>(string.Empty, string.Empty))` or `.Execute<TPlugin>()` (returns the instance).
- **Trigger:** a single-step plugin derives it - don't chain `.OnUpdate().Stage()...`. A **multi-step** plugin
  needs the message: `.OnCreate()` / `.OnUpdate()` resolves the single step on it; several or none throw with
  the list - then add `.Stage(PluginStages.PreOperation)` (`using Vela.Constants;`). No trigger at all on a
  multi-step plugin throws. The pipeline needs none of this.
- `.Build()` does **not** derive the trigger (defaults to Update / PostOperation / Sync); `.Build<TPlugin>()`
  and `.Build(plugin)` do. Use them to inspect a context.
- **Bulk (`*Multiple`):** `WithTargets(params T[])` keeps your instances (assert on them); enough for a
  single-step plugin, else `.OnMessage("UpdateMultiple").Stage(...)`. To prove what is saved:
  `p.Service.Execute(new UpdateMultipleRequest { Targets = ... })` (`using Microsoft.Xrm.Sdk.Messages;`)
  fires the step once for the batch; a single `p.Service.Update(...)` fires an UpdateMultiple step too.
- **Associate / Disassociate:** the step is **message-level** - it fires whichever table the call is issued
  from (`run.EntityLogicalName` is that side; see `dataverse-gotchas.md`). Out of a `.ForRelationship(...)`
  scope it is still logged with `HandlerInvoked == false` and a `SkipReason` - assert on that. The generated
  Associate test has `todo_*` placeholders; replace them with the real relationship:
  ```csharp
  var p = PluginPipeline.Empty().Register<ListMemberAdded>()
      .WithManyToMany("listcontact_association", "listmember", "list", "listid", "contact", "entityid")
      .Seed(new Contact { Id = contactId }, new Entity("list", listId));
  p.Service.Associate("contact", contactId, new Relationship("listcontact_association"),
      new EntityReferenceCollection { new EntityReference("list", listId) });
  ```
- **Images:** `.WithPreImage(preImage)` (alias optional). The pipeline builds the pre-image from the seeded
  row **only if the step registers it** - so an image-dependent case also needs a pipeline test:
  ```csharp
  var p = PluginPipeline.Empty().Register<AccountRevenueGuard>().Seed(new Account { Id = id, Revenue = new Money(10m) });
  Assert.Throws<InvalidPluginExecutionException>(() => p.Service.Update(new Account { Id = id, Revenue = new Money(5m) }));
  Assert.Equal(10m, p.GetAll(Account.EntityLogicalNameValue).Single().ToEntity<Account>().Revenue.Value);   // rolled back
  ```
- **Async steps:** the pipeline runs them **after the outermost operation commits**, never on rollback. An
  async failure is **not thrown** (a failed system job, as on Dataverse): it is in `p.AsyncStepFailures`
  and the triggering write stays saved. Assert `run.Mode == ExecutionMode.Asynchronous` (`using Vela.Steps;`)
  and `Assert.Empty(p.AsyncStepFailures)` (or `Single` for a failure case).
- Assert by reading records back (`GetAll`, `Retrieve`), not by counting calls.
- **PreOperation (a column of the same record):** assert on the `target` you passed - the edit of
  `ctx.Request.Target` lands on it - and that `crm` received no extra write (`Assert.Empty(crm.GetAll("account"))`).
- "Already correct → nothing re-set" in PreOperation is not observable: don't assert on trace text; cover it
  by design review and record it as a Canvas note.
- **A handler that writes by `ctx.PrimaryEntityId`:** in a `PluginContext` test it follows the Target's id,
  so seed that row before `Execute` (`.WithPrimaryEntity(...)` only to override).
- Depth: `.Depth(n)`; above 8 the guard throws "Plugin execution stopped to prevent recursion."
  (pipeline cap: `WithMaxDepth(n)`, default 8).
- Traces: `builder.TraceCapture` (`.Output`, `.Traces`) and `pipeline.Trace` (whole cascade). Print with
  `Console.WriteLine` - the Mono console runner hides `ITestOutputHelper` output for passing tests.

## Custom APIs

Entry points: `PluginContext.ForMessage("<uniquename>")` (global/message-only), `PluginContext.ForRequest(request)` (typed).
```csharp
// Typed request through the builder.
var builder = PluginContext.ForRequest(new EstimateValueRequest { AccountId = accountId, Discount = 100m });
builder.Execute(api);
Assert.Equal(900m, builder.Context.OutputParameters["Value"]);

// Through the pipeline, typed response (using Vela.Context; for ToResponse).
var p = PluginPipeline.Empty().Register<EstimateValueApi>();
EstimateValueResponse response = p.Service
    .Execute(new EstimateValueRequest { AccountId = accountId, Discount = 100m })
    .ToResponse<EstimateValueResponse>();
```
- `pipeline.Service.Execute(...)` returns a base `OrganizationResponse` that cannot be cast; `.ToResponse<T>()` views it as `T`.
- Parameters use their **plain names**: `InputParameters["Discount"]` → `OutputParameters["Value"]`.
- A handler that uses an org service needs `.WithOrganizationService(crm)`, or its lookups have nothing to read.
- The generated `--kind customapi` test has a skipped "every output is set" test: set the inputs
  (`.WithInputParameter(...)` or the request's properties), remove `Skip`, assert the values, not only presence.
- A missing required input throws as on Dataverse, through the pipeline and `builder.Execute(api)` - test it:
  `Assert.Throws<FaultException<OrganizationServiceFault>>(() => p.Service.Execute(new EstimateValueRequest()))`
  (`using System.ServiceModel;`). `.Build()` + `api.Execute(context.ServiceProvider)` skips that validation.

## Replace a service - `WithService<TService>(instance)`

Platform services are not replaced this way (`WithService` rejects them): fake a managed identity with
`PluginPipeline.WithManagedIdentityService(fake)` (or the context builder's `WithManagedIdentityService`). Each
harness has its own `IPluginCacheService`: test a TTL with `WithClock(() => now)` and move `now` past it.

On `PluginPipeline` and the context builder, it replaces what `ConfigureServices` registers for `TService`,
so the plugin runs end to end against a fake - no test-only constructor or seam in the plugin:
```csharp
var p = PluginPipeline.Empty()
    .WithService<IErpSender>(fake)
    .WithSecureConfig("ErpApiKey", "test-key")                    // the step's WithSecureConfigFrom("ErpApiKey")
    .Register<ErpNotify>();
p.Service.Create(new Account { Id = Guid.NewGuid(), Name = "Contoso" });
Assert.Equal("test-key", fake.LastApiKey);                        // the key really comes from secure config
```
Assert what the plugin hands the fake, the secure-config value included (a "missing key" test alone would
also pass if the plugin read the unsecure configuration). So the value must reach the fake: pass it through
the interface (`Send(id, name, apiKey)`), or make the **transport** the replaced service (an `IHttpSender`
wrapping `HttpClient`) and assert the header it receives. A key captured in the real service's constructor
inside `ConfigureServices` never reaches the fake - that test proves nothing about the key. Test the real
HTTP implementation against a fake `HttpMessageHandler`. No test may reach the network.

## Recursion / cascade

`PluginPipeline` runs every registered plugin on each write through `pipeline.Service`, so a self-triggering
plugin really recurses: a write-back loop throws "Vela pipeline stopped at depth 9 (cap 8)". Use the pipeline
whenever a step writes a column that could re-trigger it.

## InMemoryOrganizationService

A stateful in-memory `IOrganizationService` (Create/Retrieve/Update/Delete/RetrieveMultiple/Execute/
Associate/Disassociate; QueryExpression, QueryByAttribute, FetchExpression). Configuration (`WithSecurity`,
`WithClock`, `WithAlternateKey`...) is in IntelliSense; the pipeline exposes the same.
- An `Update` needs the record to exist: `Seed` it (with its id) first, or it throws "... Does Not Exist".
  (Seeding the record a Create plugin just created so it can update it → the step should probably be
  PreOperation - see `registration-rules.md`.)
- For anything it can't model, inject your own `IOrganizationService` via `WithOrganizationService`.

## Running the tests

Plugin and test projects target **net48**.
- **Windows:** `dotnet test <path>.Tests.csproj -c Release`.
- **macOS / Linux:** `dotnet test` **fails** (no .NET Framework test host). Run under **Mono + xunit console**.
  If `~/.nuget/packages/xunit.runner.console/2.9.2/` is missing, add
  `<PackageReference Include="xunit.runner.console" Version="2.9.2" PrivateAssets="all" />` to the test project once.
  ```bash
  dotnet build <Solution>.sln -c Release
  mono ~/.nuget/packages/xunit.runner.console/2.9.2/tools/net472/xunit.console.exe \
    tests/<P>.Plugins.Tests/bin/Release/net48/<P>.Plugins.Tests.dll -parallel none
  ```
  Success is `Total: N, Errors: 0, Failed: 0, Skipped: 0`. **Always pass `-parallel none` on Mono** - a
  `mono-sgen` "Got a segv" without it is an environment crash, **not** a test failure.
- Built against a stale package? Purge `vela.testing` under `~/.nuget` and rebuild.
