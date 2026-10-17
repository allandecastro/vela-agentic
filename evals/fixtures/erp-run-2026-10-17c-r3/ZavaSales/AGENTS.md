# AGENTS.md

Instructions for AI coding agents in this Dataverse solution, scaffolded by `vela init`. It uses Vela
(`Vela.Plugins`, `Vela.Testing` and the `vela` CLI). Docs: https://allandecastro.github.io/vela/

## Layout

- `src/Zava.Shared`: early-bound models (`Models/Generated`, regenerate with `vela models`) and shared services.
- `src/Zava.Plugins`: plugins and Custom APIs. Targets .NET Framework 4.8, the version Microsoft supports
  (never net481). Plugin packages above net471 register only on Dataverse 9.2.26092 or later; on an older
  environment, drop to net471. The Release build packs a plugin package into `artifacts/`.
- `tests/Zava.Plugins.Tests`: xUnit tests on the in-memory harness (`Vela.Testing`), no Dataverse connection.

## Commands

```bash
dotnet build ZavaSales.sln -c Release   # build, analyzers, and the plugin package in artifacts/
dotnet test tests/Zava.Plugins.Tests -c Release   # net48: on macOS/Linux run the test dll with Mono + xunit.console instead
vela models --entities account,contact --project src/Zava.Shared/Zava.Shared.csproj --interactive
vela add plugin AccountGuard --entity Account --message Update --stage PreOperation --filtering-attributes Name --project src/Zava.Plugins/Zava.Plugins.csproj
vela add customapi EstimateValue --global --function --project src/Zava.Plugins/Zava.Plugins.csproj
vela plan  --packages-dir artifacts --solution <uniquename> --json   # read-only; JSON with "schemaVersion": 1
vela apply --packages-dir artifacts --solution <uniquename>          # writes; asks for confirmation - run only when the user asks
vela help --json                                                     # every command, option and exit code
```

Always pass `--solution`: it gives the package its publisher prefix, without which plan and apply fail. Run
`vela plan` and read its result before any `vela apply`, and never apply without being asked to.

## Write a step

```csharp
using Microsoft.Xrm.Sdk;
using Vela.Context;
using Vela.Plugin;
using Zava.Shared.Models.Generated;

public sealed partial class AccountCreditPlugin(string unsecureConfig, string secureConfig)
    : EntityPluginBase<Account>(unsecureConfig, secureConfig)
{
    protected override void RegisterPluginSteps()
    {
        RegisterStep().OnUpdate().PreOperation().Sync()
            .FilterOn(a => a.CreditLimit)          // required on Create/Update (VELA020)
            .WithPreImage(a => a.CreditLimit)      // only the columns you read
            .Handle(OnCreditLimitChanging);

        RegisterStep().OnUpdate().PostOperation().Async()
            .FilterOn(a => a.CreditLimit)
            .WithStepKey("credit-review")          // needed only when two steps on one trigger look identical
            .Handle(OnCreditLimitChanged);
    }

    // OnCreditLimitChangingContext is generated (the class must be partial): PreImage holds the captured columns.
    private void OnCreditLimitChanging(OnCreditLimitChangingContext ctx)
    {
        decimal before = ctx.PreImage.CreditLimit?.Value ?? 0m;
        decimal after = ctx.Request.Target.CreditLimit?.Value ?? 0m;
        if (before > 0 && after > before * 2)
        {
            throw new InvalidPluginExecutionException("The credit limit cannot more than double at once.");
        }
    }

    // An async step runs after the commit: write through a service, never to the Target (VELA018).
    private void OnCreditLimitChanged(IUpdatePostContext<Account> ctx) =>
        ctx.Service.Update(new Account { Id = ctx.PrimaryEntityId, Description = "Credit limit reviewed." });
}
```

- Use the typed trigger (`OnCreate()`, `OnUpdate()`, `OnDelete()`, `OnAssociate()`...), then the stage, then
  `Sync()` / `Async()` (async is PostOperation only), then modifiers, and end with `Handle(...)`. A message has one
  way in: `On<TRequest>()` is only for Custom APIs and messages without a typed trigger (VELA023 rejects
  `On<UpdateRequest>()`).
- One class can register several steps, even on the same trigger; give them different filters or images, or a
  `WithStepKey(...)`.
- Images: a post-image only at PostOperation, never a pre-image on Create. The analyzers reject the rest at build time.
- Services: `ctx.Service` (the step's user), `ctx.SystemService` (SYSTEM), `ctx.AsUser(userId)`.
- Keep plugins stateless (no mutable fields). Throw `InvalidPluginExecutionException` for a message the user sees.
- Secrets: `WithSecureConfigFrom("Name")`, with the value given at deploy time
  (`vela apply --secure-config Name=...` or `VELA_SECURE_CONFIG_Name`). Never put a secret in code.

## Write a Custom API

```csharp
using System;
using Vela.Context;
using Vela.CustomApi;
using Vela.Messages;

public sealed class EstimateValueApi(string unsecureConfig, string secureConfig)
    : CustomApiBase<EstimateValueRequest, EstimateValueResponse>(unsecureConfig, secureConfig)
{
    protected override void RegisterCustomApi()
    {
        RegisterCustomApi("zava_EstimateValue")
            .DisplayName("Estimate value")
            .Description("Estimates the value of an account.")
            .AsFunction()
            .Request(r => r
                .Add(x => x.AccountId)                                       // required by default
                .Add(x => x.Discount, optional: true, "Discount to apply."))
            .Response(r => r.Add(x => x.Value));                             // a function needs a response
    }

    protected override EstimateValueResponse Execute(ILocalPluginContext ctx, EstimateValueRequest request) =>
        new EstimateValueResponse { Value = 1000m - request.Discount };
}

public sealed class EstimateValueRequest : CustomApiRequest
{
    public EstimateValueRequest() : base("zava_EstimateValue") { }

    public Guid AccountId { get => Get<Guid>(); set => Set(value); }

    public decimal Discount { get => Get<decimal>(); set => Set(value); }
}

public sealed class EstimateValueResponse : CustomApiResponse
{
    public EstimateValueResponse() : base("zava_EstimateValue") { }

    public decimal Value { get => Get<decimal>(); set => Set(value); }
}
```

The unique name carries the publisher prefix. Parameter names are plain identifiers (letters, digits,
underscores). `Build()` rejects what Dataverse refuses, such as a function without a response property.

## Write a test

```csharp
using System;
using Microsoft.Xrm.Sdk;
using Vela.Context;
using Vela.Testing;
using Xunit;
using Zava.Shared.Models.Generated;

[Fact]
public void Rejects_A_Credit_Limit_That_More_Than_Doubles()
{
    PluginPipeline pipeline = PluginPipeline.Empty().Register<AccountCreditPlugin>();
    Guid id = pipeline.Service.Create(new Account { Name = "Zava", CreditLimit = new Money(100m) });

    Assert.Throws<InvalidPluginExecutionException>(() =>
        pipeline.Service.Update(new Account { Id = id, CreditLimit = new Money(500m) }));
}

[Fact]
public void Estimates_A_Value()
{
    PluginPipeline pipeline = PluginPipeline.Empty().Register<EstimateValueApi>();

    EstimateValueResponse response = pipeline.Service
        .Execute(new EstimateValueRequest { AccountId = Guid.NewGuid(), Discount = 100m })
        .ToResponse<EstimateValueResponse>();

    Assert.Equal(900m, response.Value);
}
```

Also add a `using` for the namespace of the plugin and Custom API classes under test.
`PluginPipeline` runs every registered step around each request, as Dataverse does (stages, filters, images,
transactions, async steps after the commit). Read stored rows with `pipeline.GetAll("account")`. For a single
handler, `PluginContext.For<Account>().WithTarget(...).Execute<AccountCreditPlugin>()` runs one step directly.