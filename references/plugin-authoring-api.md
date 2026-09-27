# Plugin authoring API (verbatim)

The real shape `vela add plugin` generates and the members you use inside a handler.
This is ground truth from the framework source; skills point here instead of paraphrasing.

## Generated plugin shape

`vela add plugin <Name> --entity <Entity> --message Create` generates:

```csharp
namespace <Prefix>.Plugins.<Entity>.Plugins
{
    using Vela.Constants;
    using Vela.Context;
    using Vela.Plugin;
    using <Prefix>.Shared.Models.Generated;

    public sealed class <Name>(string unsecureConfig, string secureConfig)
        : EntityPluginBase<Account>(unsecureConfig, secureConfig)   // unsecure FIRST, secure SECOND
    {
        protected override void RegisterPluginSteps()
        {
            RegisterStep().OnCreate()
                .PostOperation()
                .Sync()
                .FilterOn(e => e.Name)
                .WithDescription("Create Account handler.")
                .Handle(OnExecute);
        }

        private void OnExecute(ICreatePostContext<Account> ctx)
        {
            ctx.Trace("<Name> executed for {0} '{1}'.", ctx.PrimaryEntityName, ctx.PrimaryEntityId);
            // TODO: your logic
        }
    }
}
```

- Base class: `EntityPluginBase<TEntity>`; ctor `(string unsecureConfig, string secureConfig)`.
- The handler method is **`OnExecute`**, not `Handle<Message>`. `.Handle(OnExecute)` is required and last.
- A **single-step** plugin auto-derives its trigger from this registration; the harness does
  not need it restated.

## Multi-step plugin (`vela add step`)

`vela add step <Plugin> --entity <Entity> --message Update` appends a second step and a handler to
the existing class (verified on CLI 0.19.4):

```csharp
RegisterStep().OnUpdate()
    .PostOperation()
    .Sync()
    .FilterOn(e => e.Id /* TODO: choose the attributes that should trigger this step */)  // VELA001 until replaced
    .Handle(HandleUpdate);

private void HandleUpdate(IUpdatePostContext<Account> ctx) { /* TODO */ }
```

- The handler is **`Handle<Message>`** (or the `--handler <Method>` name). `OnExecute` stays the
  handler of the first step. Both names are legitimate; don't rename generated handlers.
- The placeholder `FilterOn(e => e.Id ...)` does not compile (VELA001) - pick the gating column.
- The plugin is now multi-step: harness tests must state the trigger (`.OnUpdate()` ...).

## RegisterStep() fluent surface

`RegisterStep()` is callable only inside `RegisterPluginSteps()`.

- **Message:** `OnCreate() OnUpdate() OnDelete() OnCreateMultiple() OnUpdateMultiple()
  OnRetrieve() OnRetrieveMultiple() OnAssociate() OnDisassociate() OnGrantAccess()
  OnRevokeAccess() OnQualifyLead() OnWinOpportunity() OnMerge() ...`; escape hatches
  `OnMessage("name")`, `OnMessage<TMessage>()`, `On<TRequest>()`.
- **Stage:** `PreValidation()`, `PreOperation()`, `PostOperation()`.
- **Mode:** `Sync()`, `Async()`. **Async is PostOperation-only.**
- **Config (terminal):** `FilterOn(e => e.Attr, ...)` - **REQUIRED on every Create/Update
  step**; if absent the step registration *throws when it is materialized* (harness `Execute`,
  `vela plan` / `vela apply`) - **not** at `dotnet build` ("must declare at least one filtering
  attribute via FilterOn(...)"). On **Create**, Dataverse ignores filtering attributes at
  runtime, so the filter is a registration requirement only - default it to the primary column
  (e.g. `FilterOn(e => e.Name)`) and never drop it, even for a step that must fire on every
  create. On **Update**, the filter genuinely gates the trigger. Not valid on Delete/Retrieve.
  `WithPreImage(e => e.Attr, ...)` (Update/Delete), `WithPostImage(e => e.Attr, ...)`
  (Create/Update PostOperation), `WithDescription(...)`, `WithExecutionOrder(int)`,
  `WithStepKey(...)`, `WithImpersonation(...)`, `WithSupportedDeployment(...)`,
  `WithUnsecureConfig(...)`, `WithSecureConfig(...)`, `Disabled()`, then `Handle(OnExecute)`.
- Image availability is stage-gated: `WithPostImage` first exists on PostOperation.
- A plugin with any `WithPreImage`/`WithPostImage` must be declared **`partial`**: the framework generates a typed image projection nested in the
  plugin class, so a non-partial plugin fails the build with **`CS0260`** (verified on 0.28.2; the
  analyzer rule is VELA014). Reading
  a column the step did not capture is then a compile error, not a silent null.
- Analyzer **VELA002** enforces that every chain ends with `.Handle(...)`.

## Handler context

Context type per message: `ICreatePostContext<T>` / `ICreatePreContext<T>`, and the same for
Update/Delete. Custom `OnMessage` handlers get `ILocalPluginContext`.

- **Read the target:** `ctx.GetTarget<Account>()` (extension). Also `TryGetTarget`,
  `GetTargetRef`, `GetTargets` (bulk).
- **Images:** `ctx.GetPreImage<Account>()` / `ctx.GetPostImage<Account>()`; typed post/pre
  contexts also expose `ctx.PostImage` / `ctx.PreImage` properties. Request/response:
  `ctx.Request` / `ctx.Response`.
- **Write to the org:** there is **no `ctx.OrganizationService`**. Use
  `ctx.UserService` (initiating user), `ctx.CallingUserService`, or `ctx.SystemService`
  / `ctx.AsSystem()`. `CreateOrganizationService(userId)` for a specific user.
- **Trace / log:** `ctx.Trace(format, args)`, `ctx.Log(...)`, `ctx.TracingService`, `ctx.Logger`.

## Dependency injection (service into a handler)

Register services on the plugin, resolve them in the handler.

```csharp
using Vela.DI;                       // for the resolver type

protected override void ConfigureServices(SimpleServiceResolver services, ILocalPluginContext context)
    => services.AddScoped<IRevenueRollupService>(_ => new RevenueRollupService());

private void OnExecute(ICreatePostContext<Account> ctx)
    => ctx.GetRequiredService<IRevenueRollupService>().Do(ctx);   // ctx.GetRequiredService<T>() resolves it
```

- `ConfigureServices(SimpleServiceResolver services, ILocalPluginContext context)` is a `protected
  virtual` override on the base; `services.AddScoped<TService>(Func<IPluginServiceResolver, TService> factory)`.
- Resolve inside the handler with `ctx.GetRequiredService<T>()`. Keep the handler thin (SRP); put
  real logic in the service (DRY, testable).

## Custom API authoring (`vela add customapi`)

`vela add customapi ScoreLead --global --action` generates a lightweight, untyped Custom API (verified,
CLI 0.19.4 / `Vela.Plugins` 0.28.2). The handler is passed to `RegisterCustomApi(uniqueName, handler)`;
parameters chain on the returned builder:

```csharp
public sealed class ScoreLead(string unsecureConfig, string secureConfig)
    : CustomApiBase(unsecureConfig, secureConfig)
{
    protected override void RegisterCustomApi()
    {
        RegisterCustomApi("zava_ScoreLead", Handle)     // dot-free unique name = <publisher prefix>_<Name>
            .DisplayName("ScoreLead")
            .Description("Scores a lead.")
            .AsAction()                                  // or .AsFunction()
            .RequestParameter<string>("email", optional: false, "Lead email")
            .ResponseParameter<int>("leadScore", "0-100");
    }

    private void Handle(ILocalPluginContext ctx)
    {
        var email = ctx.GetInputParameter<string>("email");
        if (string.IsNullOrWhiteSpace(email))
            throw new InvalidPluginExecutionException("email is required");   // VELA012
        ctx.SetOutputParameter("leadScore", 55);
    }
}
```

- The handler is bound by `RegisterCustomApi(name, handler)` (or `.Handler(...)` on the builder) -
  there is **no** `.Handle(...)` terminal on a Custom API builder (that is the plugin-step surface).
- **Signature asymmetry (easy to get wrong):**
  `RequestParameter<T>(string name, bool optional = false, string? description = null)` has the
  `optional` bool; `ResponseParameter<T>(string name, string? description = null)` does **not**.
- `.AsAction()` (POST-style, side effects) vs `.AsFunction()` (GET-style, read-only). "POST" in a
  story maps to an Action; a Custom API has **no HTTP status codes** - signal errors with
  `throw new InvalidPluginExecutionException("...")` (VELA012: other exceptions reach the caller as a
  generic error).
- A strongly-typed variant exists (`CustomApiBase<TRequest, TResponse>`, request/response classes
  generated by `vela models --custom-apis`); prefer the scaffolded untyped form unless the project
  already uses typed requests.
- Unique name and every parameter name must be **dot-free** and use the target solution's publisher
  prefix, or `vela apply --solution` rejects them.
