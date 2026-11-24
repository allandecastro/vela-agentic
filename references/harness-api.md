# Vela.Testing harness API (verbatim)

Ground truth for writing and running harness tests. Skills point here. Snippets were compiled and run under
the Mono runner (net48). For other members, read the IntelliSense on `PluginPipeline` - a failing build or
probe test tells you.

## `PluginPipeline` - the only harness

Register the plugins (`PluginPipeline.Empty().Register<TPlugin>()`, or `FromAssemblyOf<T>()` for all of them -
a type registered twice throws),
`Seed(...)` the starting rows (no plugin fires), send the triggering write through `p.Service`, then assert on
`GetAll`, `ExecutionLog`, `Trace` and `LogCapture`. It runs the registration as Dataverse does: filters,
message/stage, relationship scope, images, ranks, several plugins, cascades, rollback, async. A class with several
steps on one trigger is tested on their combined effect (there is no per-step selector).

A test cannot hand a plugin a crafted context - produce the case as Dataverse does:
- `Depth` ≥ 2, `SharedVariables`, `ParentContext`: register the plugins whose writes produce them; a `tag`:
  set `request["tag"]` on a request object sent with `p.Service.Execute(...)` (`ctx.Tag`);
- one error branch: seed the rows that lead to it;
- an invalid Custom API input: send it - the request is checked against the definition first.

A "does not fire when an unrelated column changes" test:
```csharp
var id = Guid.NewGuid();
var p = PluginPipeline.Empty().Register<AccountPlugin>().Seed(new Account { Id = id, Name = "orig" });
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
`Does_What_It_Should` and put the acceptance cases there, plus the negative "does not fire" cases. Every
test needs its functional justification: tag the generated `Fires_On_*` test with the case whose trigger it
proves (e.g. the Create case) - never leave it untagged, never delete it to dodge the rule.

## Easy-to-get-wrong facts

- **The step that fires is the one the write triggers** - a test never states the message or stage.
- **Bulk (`*Multiple`):** `p.Service.Execute(new UpdateMultipleRequest { Targets = ... })`
  (`using Microsoft.Xrm.Sdk.Messages;`) fires the step once for the batch; a single `p.Service.Update(...)` fires
  an UpdateMultiple step too.
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
- **Images:** the pipeline builds the pre-image from the seeded row **only if the step registers it**:
  ```csharp
  var p = PluginPipeline.Empty().Register<AccountPlugin>().Seed(new Account { Id = id, Revenue = new Money(10m) });
  Assert.Throws<InvalidPluginExecutionException>(() => p.Service.Update(new Account { Id = id, Revenue = new Money(5m) }));
  Assert.Equal(10m, p.GetAll(Account.EntityLogicalNameValue).Single().ToEntity<Account>().Revenue.Value);   // rolled back
  ```
- **Async steps:** the pipeline runs them **after the outermost operation commits**, never on rollback. An
  async failure is **not thrown** (a failed system job, as on Dataverse): it is in `p.AsyncStepFailures`
  and the triggering write stays saved - so do the writes the step made before failing. Assert `run.Mode == ExecutionMode.Asynchronous` (`using Vela.Steps;`)
  and `Assert.Empty(p.AsyncStepFailures)` (or `Single` for a failure case).
- Assert by reading records back (`GetAll`, `Retrieve`), not by counting calls.
- **Stamped as on Dataverse:** `createdon`, `createdby`, `modifiedon`, `modifiedby`, `owningbusinessunit` sent on a
  write are ignored - arrange them with `Seed(...)`. A Create with `statecode` but no `statuscode` is active:
  send both.
- **PreOperation (a column of the same record):** through the pipeline, read the row back (the edit of
  `ctx.Request.Target` is what was saved); `Assert.Single(p.ExecutionLog)` proves no second write re-fired the step.
- "Already correct → nothing re-set" in PreOperation is not observable: don't assert on trace text; cover it
  by design review and record it as a Canvas note.
- Depth: the cascade cap is `WithMaxDepth(n)` (default 8).
- Traces: `pipeline.Trace` (`.Output`, `.Traces`, whole cascade). Print with `Console.WriteLine` - the Mono
  console runner hides `ITestOutputHelper` output for passing tests.

## Custom APIs

Send the request through the pipeline: the typed request, or `new OrganizationRequest("<uniquename>") { ["Input"] = value }`
(global/message-only); a bound API's request carries `request["Target"]`. Read the outputs from
`response.Results["<Name>"]`, or typed:
```csharp
// using Vela.Context; for ToResponse
var p = PluginPipeline.Empty().Register<EstimateValueApi>();
EstimateValueResponse response = p.Service
    .Execute(new EstimateValueRequest { AccountId = accountId, Discount = 100m })
    .ToResponse<EstimateValueResponse>();
```
- `pipeline.Service.Execute(...)` returns a base `OrganizationResponse` that cannot be cast; `.ToResponse<T>()` views it as `T`.
- Parameters use their **plain names**: `request["Discount"]` → `response.Results["Value"]`.
- A handler that reads other rows needs them `Seed`ed, or its lookups have nothing to read.
- The generated `--kind customapi` test has a skipped "every output is set" test: set the inputs (the request's
  properties or `request["<Name>"]`), remove `Skip`, assert the values, not only presence.
- A missing required input throws as on Dataverse - test it:
  `Assert.Throws<FaultException<OrganizationServiceFault>>(() => p.Service.Execute(new EstimateValueRequest()))`
  (`using System.ServiceModel;`).

## Platform services and security

Platform services are not replaced this way (`WithService` rejects them): fake a managed identity with
`PluginPipeline.WithManagedIdentityService(fake)`. Each pipeline has its own `IPluginCacheService`: test a TTL
with `WithClock(() => now)` and move `now` past it.
`WithSecurity` uses the **generated roles** (`vela models --roles`): `.Role(Roles.SalespersonName,
Roles.SalespersonId, Roles.Salesperson)` (a system role: `.Role(Roles.XName, Roles.XId, Roles.XTemplateId, Roles.X)`)
then `.User(alice, bu, Roles.SalespersonName)` - the org's real privileges and ids, never a hand-written grant list.
Like Dataverse, the harness copies each role per business unit (`systemuserroles` / `teamroles` hold the BU copy),
faults a read without Read privilege on any table it touches - link-entities and `role` included (`0x80040220`) -
and a Retrieve out of scope (`0x80048306`): grant the Read, or read as SYSTEM when production must. A hand-built role only for a deliberately missing privilege (a
read-denied case), named for what it lacks.
A `WithSecurity` test that depends on who can read a child row (e.g. an account's contacts) declares the
parental relationship (`WithParentalRelationship("account", "contact", "parentcustomerid")`): inherited access
(the parent's owner reads its children) applies only then - see Vela's security-model guide.
Like Dataverse, it also checks: a new owner (Create with `ownerid`, Assign, a PreOperation setting it) holds Read
on the table (`0x80040299`); an N:N Associate/Disassociate has Append on both tables; a Create setting a secured
column has `FieldPermission(..., create: true)`. A `User`/`Team`/`FieldPermission` naming an undeclared principal
or business unit throws at `WithSecurity`. Such a fault is a real denial or a missing declaration, not a harness
bug.

## Replace a service - `WithService<TService>(instance)`

On `PluginPipeline`, `WithService<T>` replaces what `ConfigureServices` registers for `TService`,
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
- The pipeline always drives its own store - no custom `IOrganizationService` can replace it. What it does not
  model is on Vela's [limitations](https://allandecastro.github.io/vela/reference/limitations) page.

## Running the tests

Plugin and test projects target **net48**.
- **Windows:** `dotnet test <path>.Tests.csproj -c Release`.
- **macOS / Linux:** `dotnet test` **fails** (no .NET Framework test host). Run under **Mono + xunit console**.
  If `~/.nuget/packages/xunit.runner.console/<ver>/` is missing, add
  `<PackageReference Include="xunit.runner.console" Version="<ver>" PrivateAssets="all" />` to the test project once.
  One command builds and runs every test assembly:
  ```bash
  dotnet build <Solution>.sln -c Release && for t in tests/*/bin/Release/net48/*.Tests.dll; do
    mono ~/.nuget/packages/xunit.runner.console/<ver>/tools/net472/xunit.console.exe "$t" -parallel none || break; done
  ```
  Success is `Total: N, Errors: 0, Failed: 0, Skipped: 0` with **N > 0 in every test assembly and at least the
  declared cases** - a run over zero tests checked nothing (wrong path, filter, discovery) and is not green. **Always pass `-parallel none` on Mono** - a
  `mono-sgen` "Got a segv" without it is an environment crash, **not** a test failure.
- `Vela.Testing` pins its own `Vela.Plugins` version (NU1608 otherwise): upgrade both together.
- Built against a stale package? Purge `vela.testing` under `~/.nuget` and rebuild.
