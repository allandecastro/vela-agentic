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

## RegisterStep() fluent surface

`RegisterStep()` is callable only inside `RegisterPluginSteps()`.

- **Message:** `OnCreate() OnUpdate() OnDelete() OnCreateMultiple() OnUpdateMultiple()
  OnRetrieve() OnRetrieveMultiple() OnAssociate() OnDisassociate() OnGrantAccess()
  OnRevokeAccess() OnQualifyLead() OnWinOpportunity() OnMerge() ...`; escape hatches
  `OnMessage("name")`, `OnMessage<TMessage>()`, `On<TRequest>()`.
- **Stage:** `PreValidation()`, `PreOperation()`, `PostOperation()`.
- **Mode:** `Sync()`, `Async()`. **Async is PostOperation-only.**
- **Config (terminal):** `FilterOn(e => e.Attr, ...)` — **REQUIRED on every Create/Update
  step**; if absent the step registration *throws when it is materialized* (harness `Execute`,
  `vela plan` / `vela apply`) — **not** at `dotnet build` ("must declare at least one filtering
  attribute via FilterOn(...)"). On **Create**, Dataverse ignores filtering attributes at
  runtime, so the filter is a registration requirement only — default it to the primary column
  (e.g. `FilterOn(e => e.Name)`) and never drop it, even for a step that must fire on every
  create. On **Update**, the filter genuinely gates the trigger. Not valid on Delete/Retrieve.
  `WithPreImage(e => e.Attr, ...)` (Update/Delete), `WithPostImage(e => e.Attr, ...)`
  (Create/Update PostOperation), `WithDescription(...)`, `WithExecutionOrder(int)`,
  `WithStepKey(...)`, `WithImpersonation(...)`, `WithSupportedDeployment(...)`,
  `WithUnsecureConfig(...)`, `WithSecureConfig(...)`, `Disabled()`, then `Handle(OnExecute)`.
- Image availability is stage-gated: `WithPostImage` first exists on PostOperation.
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
