# Plugin authoring API (verbatim)

The real shape `vela add plugin` generates and the members you use inside a handler.
This is ground truth from the framework (verified against vela 0.25.0 / Vela.Plugins 0.34.0: every
snippet below was compiled); skills point here instead of paraphrasing.

## Generated plugin shape

`vela add plugin <Name> --entity Account --message Update --stage PreOperation --filtering-attributes Name`
generates (`--filtering-attributes` is **required** for Create/Update(+Multiple): without it the CLI exits 2):

```csharp
namespace <Prefix>.Plugins.Account.Plugins
{
    using Vela.Constants;
    using Vela.Context;
    using Vela.Plugin;
    using <Prefix>.Shared.Models.Generated;

    public sealed partial class <Name>(string unsecureConfig, string secureConfig)
        : EntityPluginBase<Account>(unsecureConfig, secureConfig)   // unsecure FIRST, secure SECOND
    {
        protected override void RegisterPluginSteps()
        {
            RegisterStep().OnUpdate()
                .PreOperation()
                .Sync()
                .FilterOn(e => e.Name)
                .WithDescription("Update Account handler.")
                .Handle(OnExecute);
        }

        private void OnExecute(IUpdatePreContext<Account> ctx)
        {
            ctx.Trace("<Name> executed for {0} '{1}'.", ctx.PrimaryEntityName, ctx.PrimaryEntityId);
            // TODO: read the typed record with ctx.Request.Target (ctx.Request.Targets for *Multiple).
        }
    }
}
```

- Base class: `EntityPluginBase<TEntity>` with a primary constructor `(string unsecureConfig, string secureConfig)`.
  The generated class is already `sealed partial` (the framework nests generated step contexts in it).
- The handler method is **`OnExecute`**, not `Handle<Message>`. `.Handle(OnExecute)` is required and last.
- A **single-step** plugin auto-derives its trigger from this registration; the harness does
  not need it restated.
- `Account` resolves only once the model exists: run `vela models --entities account ... --project
  src/<P>.Shared/<P>.Shared.csproj` first (a minimal `vela init` has no models).

## Multi-step plugin (`vela add step`)

`vela add step <Plugin> --entity Account --message Update --stage PostOperation --filtering-attributes Telephone1`
appends a second step and a handler to the existing class:

```csharp
RegisterStep().OnUpdate()
    .PostOperation()
    .Sync()
    .FilterOn(e => e.Telephone1)
    .Handle(HandleUpdate);

private void HandleUpdate(IUpdatePostContext<Account> ctx) { /* TODO (read ctx.Request.Target) */ }
```

- The handler is **`Handle<Message>`** (or the `--handler <Method>` name). `OnExecute` stays the
  handler of the first step. Both names are legitimate; don't rename generated handlers.
- The plugin is now multi-step: harness tests must state the trigger (`.OnUpdate()` ...).

## RegisterStep() fluent surface

`RegisterStep()` is callable only inside `RegisterPluginSteps()`.

- **Trigger (typed):** `OnCreate() OnUpdate() OnDelete() OnCreateMultiple() OnUpdateMultiple()
  OnRetrieve() OnRetrieveMultiple() OnAssociate() OnDisassociate() OnAssign() OnGrantAccess()
  OnRevokeAccess() OnModifyAccess() OnMerge() OnQualifyLead() OnWinOpportunity() OnSendEmail()
  OnAddMemberList() OnAddListMembersList() OnRemoveMemberList() ...` (one per modelled message).
  **`On<TRequest>()` / `OnAsyncOnly<TRequest>()` / `OnMessage<TMessage>()` are only for Custom APIs and
  messages without a typed trigger** - `On<UpdateRequest>()` is a build error (**VELA023**). There is no
  string `OnMessage("name")` any more.
- **Stage:** `PreValidation()`, `PreOperation()`, `PostOperation()`.
- **Mode:** `Sync()`, `Async()` / `Async(deleteJobOnSuccess: true)` (Dataverse `asyncautodelete`).
  **Async is PostOperation-only.**
- **Config:** `FilterOn(e => e.Attr, ...)` - **REQUIRED on every Create/Update(+Multiple) step**; a
  missing one is a **build error (VELA020)**. On **Create** and **Update** alike the filter gates the
  trigger (verified live on a dev org; the Microsoft docs say Create ignores filtering attributes - they do not): the step fires only when the payload carries a
  filtered column. For "every create", filter on a column every create sends (e.g. a business-required
  `FilterOn(e => e.Name)`). Not offered on Delete/Retrieve.
  `WithPreImage(e => e.Attr, ...)` (Update/Delete), `WithPostImage(e => e.Attr, ...)`
  (Create/Update PostOperation), `ForRelationship("schema_name", ...)` (Associate/Disassociate only, see
  below), `WithDescription(...)`, `WithExecutionOrder(int)`, `WithStepKey(...)` (two steps on one
  trigger that differ in no filter/image/relationship need one - VELA008), `WithImpersonation(Guid)`,
  `WithSupportedDeployment(...)`, `WithUnsecureConfig(...)`, `WithSecureConfigFrom("Name")`,
  `SkipWhenDepthAbove(n)`, `Disabled()`, then `Handle(OnExecute)`. Each single-value modifier at most
  once per step (VELA003).
- Image availability is stage-gated: `WithPostImage` first exists on PostOperation.
- Analyzer **VELA002** enforces that every chain ends with `.Handle(...)`.

### Images and the generated per-handler context

A step with `WithPreImage`/`WithPostImage` gets a **generated typed context named after its handler**
(`<Handler>Context`), whose images expose **only the captured columns** - reading one the step did not
capture is a compile error (`CS1061`), not a silent null. The plugin must be `partial` (the scaffold
already is; a non-partial one fails with **`CS0260`**, rule VELA014).

```csharp
RegisterStep().OnUpdate().PreOperation().Sync()
    .FilterOn(a => a.CreditLimit)
    .WithPreImage(a => a.CreditLimit)            // only the columns you read
    .Handle(OnCreditLimitChanging);

private void OnCreditLimitChanging(OnCreditLimitChangingContext ctx)   // generated
{
    decimal before = ctx.PreImage.CreditLimit?.Value ?? 0m;
    decimal after = ctx.Request.Target.CreditLimit?.Value ?? 0m;
    if (before > 0 && after > before * 2)
        throw new InvalidPluginExecutionException("The credit limit cannot more than double at once.");
}
```

- The message context (`IUpdatePreContext<Account>`) also compiles as the handler type; its
  `ctx.PreImage` is then the full early-bound entity. Prefer the generated context.
- Reading `ctx.PreImage`/`ctx.PostImage` on a step that captures none is a build error (**VELA017**).
- One handler per image-capturing step (**VELA016**) - the context is named after it.

### Associate / Disassociate (`OnAssociate()` / `OnDisassociate()`)

`vela add plugin <Name> --entity Contact --message Associate` generates
`RegisterStep().OnAssociate().PostOperation().Sync()...Handle(OnExecute)` with
`OnExecute(IAssociatePostContext<Contact> ctx)`. The step is registered **message-level** (step
definition `EntityLogicalName` is empty, as Dataverse requires). Scope it to the relationship(s) the story
is about:

```csharp
RegisterStep().OnAssociate().PostOperation().Sync()
    .ForRelationship("contact_customer_accounts")     // (schemaName, params additionalSchemaNames)
    .Handle(OnExecute);

private void OnExecute(IAssociatePostContext<Contact> ctx)
{
    EntityReference target = ctx.Request.Target;                  // may be EITHER side of the relationship
    string relationship = ctx.Request.Relationship.SchemaName;
    EntityReferenceCollection related = ctx.Request.RelatedEntities;
}
```

- `ForRelationship` is enforced **at dispatch**: the handler runs only when the request's relationship is
  one of these (otherwise Vela traces "relationship outside the step's ForRelationship scope" and skips).
  Without it the handler runs for **every** association in the org.
- The `<T>` of the plugin does **not** filter the Target: in the harness, associating from the account
  side ran a `EntityPluginBase<Contact>` handler with an `account` Target. Check
  `ctx.Request.Target.LogicalName` and the related entities' types before acting.

## Handler context

Context type per message and stage: `ICreatePostContext<T>` / `ICreatePreContext<T>`, the same for
Update/Delete/Associate..., or the generated `<Handler>Context` (images). A handler bound to the wrong
message/stage context is VELA015. Generated plugin files don't import `Microsoft.Xrm.Sdk` - add
`using Microsoft.Xrm.Sdk;` when you use `Money`, `EntityReference`, `InvalidPluginExecutionException`...

- **Read (and change) the target: `ctx.Request.Target`** - the typed context's `Request` is the current
  message as a typed request (`CreateRequest<Account>`, `UpdateRequest<Account>`) **over the live
  InputParameters**, so `ctx.Request.Target` is an `Account` and setting a property on it in a
  PreOperation step changes the record being written. In an **Async** step a Target write has no
  effect (**VELA018**). The untyped extensions `ctx.GetTarget<Account>()` / `TryGetTarget` /
  `GetTargetRef` remain for `ILocalPluginContext` handlers (Custom APIs, `On<TRequest>()`).
- **Bulk (`IUpdateMultiplePreContext<T>` / `ICreateMultiple...`):** `ctx.Request.Targets.Entities` is the batch
  (untyped `Entity`, also `ctx.BulkTargets`). `e.ToEntity<Account>()` shares the attribute collection,
  so editing the typed copy in PreOperation edits the target:
  `foreach (Entity e in ctx.Request.Targets.Entities) { var a = e.ToEntity<Account>(); a.Telephone1 = a.Telephone1?.Trim(); }`
  Never call `Update` per record inside the loop.
- **Images:** see above; extensions `ctx.GetPreImage<Account>()` / `ctx.GetPostImage<Account>()` /
  `GetPreImageMerged` work by alias. Response: `ctx.Response` on post contexts.
- **Was a column sent? Did it change?** - typed helpers, not logical-name strings:
  `target.Contains(e => e.AccountNumber)` (also `Contains(a, b)` = all, `ContainsAny(a, b)` = any; needs
  `using Vela.Querying;`) tests presence in the payload; `ctx.HasChanged<Account>(e => e.Name)` is true
  when the column is in the Target **and** differs from the registered pre-image (needs a pre-image with
  that column - VELA009 without one; a column absent from the Target counts as unchanged;
  Delete/Assign/SetState throw).
- **Read the org - typed** (`using Vela.Querying;`, verified 0.36.0): build queries on the generated
  models, never with logical-name strings:
  ```csharp
  List<Contact> contacts = Query.For<Contact>()
      .Select(c => c.LastName, c => c.EmailAddress1)
      .Where(c => c.ParentCustomerId, ConditionOperator.Equal, accountId)
      .ToList(ctx.Service);                              // also FirstOrDefault(svc), CountScalar(svc, c => c.ContactId)
  ```
  The builder also has `WhereIn`, `WhereAll`/`WhereAny`, `OrderBy`, `Top`, `Link<T>(...)`, `Distinct`, `Page`;
  `service.RetrieveByKey<T>(key, columns...)` reads by alternate key. A single row by id:
  `ctx.Service.Retrieve(Account.EntityLogicalNameValue, id, new ColumnSet(...)).ToEntity<Account>()`.
- **Depth:** `ctx.Depth` (see the recursion gotcha in `dataverse-gotchas.md`).
- **Write to the org** (there is no `ctx.OrganizationService`, and **no `ctx.UserService`** any more):
  - `ctx.Service` - the step's user (the "Run in User's Context" user when the step impersonates,
    otherwise the caller); record-level security applies. **The default**, and what DI resolves for
    `IOrganizationService`.
  - `ctx.SystemService` - SYSTEM, bypasses record-level security; only where elevation is intended.
  - `ctx.AsUser(userId)` - a specific user, e.g. `ctx.AsUser(ctx.InitiatingUserId)` for the user who
    started the operation.
- **Secure configuration:** `.WithSecureConfigFrom("Name")` on the step; the value is supplied at deploy
  time (`vela plan|apply --secure-config Name=VALUE|Name=@file`, or `VELA_SECURE_CONFIG_Name`), passed to the
  constructor and read through the base `SecureConfig` property. Only the name is in the assembly.
- **Trace / log:** `ctx.Trace(format, args)`, `ctx.Log(...)`, `ctx.TracingService`, `ctx.Logger`.

## Dependency injection (service into a handler)

Register services on the plugin, resolve them in the handler.

```csharp
using Vela.DI;                       // for the resolver type

protected override void ConfigureServices(SimpleServiceResolver services, ILocalPluginContext context)
    => services.AddScoped<IAccountDescriptionDefault>(r => new AccountDescriptionDefault(r.GetRequiredService<IOrganizationService>()));

private void HandleUpdate(IUpdatePostContext<Account> ctx)
    => ctx.GetRequiredService<IAccountDescriptionDefault>().Execute(ctx.Request.Target);
```

`vela add service AccountDescriptionDefault --entity Account` generates (in `Account/Services/`) an
interface + class, and prints the registration line to add:

```csharp
public interface IAccountDescriptionDefault { void Execute(Account target); }

public sealed class AccountDescriptionDefault(IOrganizationService service) : IAccountDescriptionDefault
{
    private readonly IOrganizationService _service = service;
    public void Execute(Account target) { /* TODO: domain logic using _service */ }
}
// Register (printed by the CLI):
// services.AddScoped<IAccountDescriptionDefault>(r => new AccountDescriptionDefault(r.GetRequiredService<IOrganizationService>()));
```
Rename/reshape `Execute` to what the Canvas needs; a pure rule that never calls the org may drop the
`IOrganizationService` parameter (then register it with `new AccountDescriptionDefault()`).
The `IOrganizationService` DI resolves is `ctx.Service` (the step's user).

- `ConfigureServices(SimpleServiceResolver services, ILocalPluginContext context)` is a `protected
  virtual` override on the base; `services.AddScoped<TService>(Func<IPluginServiceResolver, TService> factory)`.
- Resolve inside the handler with `ctx.GetRequiredService<T>()`. Keep the handler thin (SRP); put
  real logic in the service (DRY, testable). In a test, `WithService<T>(fake)` on the pipeline or the context
  builder replaces the registration (`harness-api.md`) - no test-only constructor in the plugin.

## Custom API authoring (`vela add customapi`)

The unique name is `<publisher prefix>_<Name>`: `vela add customapi` takes the prefix from `--prefix`,
else the project's `<VelaPublisherPrefix>` (written by `vela init --publisher-prefix`), else the project
prefix. `vela add customapi ScoreLead --global --action` generates a lightweight, untyped Custom API (in
`GlobalCustomApis/`). The handler is passed to `RegisterCustomApi(uniqueName, handler)`; parameters chain
on the returned builder:

```csharp
public sealed class ScoreLead(string unsecureConfig, string secureConfig)
    : CustomApiBase(unsecureConfig, secureConfig)
{
    protected override void RegisterCustomApi()
    {
        RegisterCustomApi("zava_ScoreLead", Handle)     // <publisher prefix>_<Name>
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

- The handler is bound by `RegisterCustomApi(name, handler)` - there is **no** `.Handle(...)` terminal
  on a Custom API builder (that is the plugin-step surface).
- **Signature asymmetry (easy to get wrong):**
  `RequestParameter<T>(string name, bool optional = false, string? description = null)` has the
  `optional` bool; `ResponseParameter<T>(string name, string? description = null)` does **not**.
- `.AsAction()` (POST-style, side effects, **and anything Power Automate / flows call** - the Dataverse
  connector only calls Actions) vs `.AsFunction()` (GET-style, read-only, code/Web API callers; **must
  declare at least one response property**). The kind can't be changed after creation. "POST" in a story
  maps to an Action; a Custom API has **no HTTP status codes** - signal errors with
  `throw new InvalidPluginExecutionException("...")` (VELA012: other exceptions reach the caller as a
  generic error).
- The global form above is what `vela add customapi <Name>` (no `--entity`) generates.

### Bound / typed form (`vela add customapi <Name> --entity <E>`)

With `--entity`, the CLI generates a **typed** Custom API bound to the table (in `<Entity>/CustomApis/`),
with its request and response classes in the same file - subclasses of Vela's `CustomApiRequest` /
`CustomApiResponse` (`using Vela.Messages;`), the same pattern the scaffold's `AGENTS.md` shows:

```csharp
public sealed class RecalcAccount(string unsecureConfig, string secureConfig)
    : CustomApiBase<RecalcAccountRequest, RecalcAccountResponse>(unsecureConfig, secureConfig)
{
    protected override void RegisterCustomApi()
    {
        RegisterCustomApi("zava_RecalcAccount")
            .DisplayName("RecalcAccount")
            .Description("Recalculates the account total.")
            .AsFunction()                                  // or .AsAction()
            .BoundTo<Account>()
            .AllowedCustomProcessingSteps(CustomApiAllowedCustomProcessingStepType.SyncAndAsync)
            .Request(r => r
                .Add(x => x.Factor)                        // required by default
                .Add(x => x.Note, optional: true, "Free text."))
            .Response(r => r.Add(x => x.Total));
    }

    protected override RecalcAccountResponse Execute(ILocalPluginContext ctx, RecalcAccountRequest request)
        => new RecalcAccountResponse { Total = 21m * request.Factor };
}

public sealed class RecalcAccountRequest : CustomApiRequest
{
    public RecalcAccountRequest() : base("zava_RecalcAccount") { }
    public decimal Factor { get => Get<decimal>(); set => Set(value); }
    public string Note { get => Get<string>(); set => Set(value); }
}
// RecalcAccountResponse : CustomApiResponse, same pattern (Total). The scaffold seeds a placeholder
// `Result` property ("a function must return at least one response property") - rename or replace it.
```

- Add a typed property (`Get<T>()` / `Set(value)`) and map it in `.Request(...)` / `.Response(...)`.
  Without a `.Request(...)` call every settable request property becomes a parameter (optional unless
  `[Required]`); without `.Response(...)` every response property is an output. Once you call them,
  only the mapped properties are registered.
- Registered parameter names are the property names: **plain identifiers** (letters, digits,
  underscores), no dot, no prefix (`Factor`, `Total`). Check what will be registered with
  `new <Api>(string.Empty, string.Empty).GetCustomApiDefinition()` → `UniqueName`, `IsFunction`,
  `IsBound`, `BindingType`, `InputParameters`, `OutputParameters`; each parameter has `Name`,
  `ParameterTypeName`, `IsOptional`.
- **What the builder rejects** when the definition is built (harness `Register`, `vela plan`; not
  `dotnet build`): a parameter name with a dot or other non-identifier character (`ArgumentException`),
  a Function with no response property (`InvalidOperationException`), a duplicate parameter name.
  It does **not** reject a unique name without the publisher prefix (`ScoreIt` registers locally) - the
  review is the guard for that.
- Other builder options: `.Public()`/`.Private()`, `.ExecutePrivilege(...)`, `.BoundToCollection<T>()`,
  `.WorkflowSdkStep(...)`, `.AllowedCustomProcessingSteps(None | AsyncOnly | SyncAndAsync)`.
- Callers use the request class itself:
  `service.Execute(new RecalcAccountRequest { ... }).ToResponse<RecalcAccountResponse>()` (`ToResponse`
  is in `Vela.Context`). A bound API needs its `Target` set on the request.
