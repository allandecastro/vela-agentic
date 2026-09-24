# Vela.Testing harness API (verbatim)

Ground truth for writing and running harness tests. Skills point here.

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
        // For a MULTI-step plugin only, state it: .OnUpdate().Stage(...).Mode(...).
        PluginContext.For<Account>()
            .WithTarget(target)
            .WithOrganizationService(crm)
            .Execute(new <Name>(string.Empty, string.Empty));   // instance, (unsecure, secure) ctor

        // Assert: read the record(s) back from crm and check fields.
        // var rows = crm.RetrieveMultiple(new QueryExpression("account") { ColumnSet = new ColumnSet(true) });
        // var row = Assert.Single(rows.Entities);
        // Assert.Equal("expected", row.GetAttributeValue<string>("description"));
    }
}
```

Critical, easy-to-get-wrong facts:
- `.Execute(...)` takes a **plugin instance**: `new <Plugin>(string.Empty, string.Empty)`.
  There is **no** `.Execute<TPlugin>()` generic.
- The ctor is `(unsecureConfig, secureConfig)` — pass `string.Empty, string.Empty` when unused.
- Do **not** chain `.OnUpdate().Stage().Mode()` for a single-step plugin; it auto-derives.
  Only restate the trigger for multi-step plugins.
- Assert by reading records back from `crm`, not by counting calls.

Builder entry points (`Vela.Testing.PluginContext`): `PluginContext.For<TEntity>()` for entity
plugins; `PluginContext.ForMessage("<uniquename>").Build()` for custom APIs / message-only,
then `api.Execute(context.ServiceProvider)` and assert
`context.PluginExecutionContext.OutputParameters[...]`.

Builder methods you'll use: `WithTarget`, `WithPreImage`, `WithPostImage`, `WithPrimaryEntity`,
`WithOrganizationService(crm)` (also `WithUserService`, `WithSystemService`),
`WithInputParameter`/`WithOutputParameter`, then `Execute(...)`. For cascades use
`PluginPipeline.FromAssemblyOf<T>()`, `Register<TPlugin>()`, `Seed(...)`, write through
`pipeline.Service`, inspect `pipeline.ExecutionLog`.

## InMemoryOrganizationService

`Vela.Testing.InMemoryOrganizationService` — a stateful in-memory `IOrganizationService`.
- Seed: `.Seed(params Entity[])`; read all: `.GetAll(logicalName)`.
- Full `IOrganizationService`: Create/Retrieve/Update/Delete/RetrieveMultiple/Execute/
  Associate/Disassociate. RetrieveMultiple supports QueryExpression, QueryByAttribute, FetchExpression.
- Configure: `.WithCurrentUser(Guid)`, `.WithSecurity(...)`, `.WithClock(...)`,
  `.WithAlternateKey(...)`, `.WithManyToMany(...)`, `.WithRelationship(...)`, `.WithAutoNumber(...)`,
  `.AsElastic()`/`.AsVirtual()`, `.WithEntityMetadata(...)`.
- For anything it can't model, inject your own `IOrganizationService` via `WithOrganizationService`.

## Running the tests

Test projects target **net462**. The runner depends on the OS:

- **Windows:** `dotnet test <path>.Tests.csproj -c Release`.
- **macOS / Linux (arm64 or x64):** `dotnet test` **fails** — .NET has no net-framework test
  host (`testhost.arm64.exe` missing). Run under **Mono + xunit console** instead:
  ```bash
  dotnet build <path>.Tests.csproj -c Release
  mono ~/.nuget/packages/xunit.runner.console/2.9.2/tools/net462/xunit.console.exe \
    <path>/bin/Release/net462/<Name>.Tests.dll -parallel none
  ```
  **Always pass `-parallel none` on Mono.** A native `mono-sgen` segv ("Got a segv") without it
  is an environment crash from parallel assembly loading, **not** a test failure — the suite
  passes serially.
- If you built against a stale package, purge `vela.testing` under `~/.nuget` and rebuild.
