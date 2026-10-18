# Plugin authoring API (verbatim)

The shape `vela add plugin` generates and the non-obvious members you use in a handler. Every snippet
compiles; skills point here instead of paraphrasing. For anything not listed, read the generated file and
IntelliSense - a failing build tells you the rest.

## Generated plugin shape

`vela add plugin <Name> --entity Account --message Update --stage PreOperation --filtering-attributes Name`
(`--filtering-attributes` is **required** for Create/Update(+Multiple), else exit 2) generates:

```csharp
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

    private void OnExecute(OnExecuteContext ctx) { /* TODO: ctx.Request.Target */ }
}
```

- The class is already `sealed partial` (generated step contexts nest in it; non-partial = `CS0260`, VELA014).
- The handler is **`OnExecute`**; `.Handle(...)` is required and last (VELA002).
- A **single-step** plugin auto-derives its trigger; the harness need not restate it.
- `Account` resolves only once the model exists: run `vela models --entities account ... --project
  src/<P>.Shared/<P>.Shared.csproj` first (a minimal `vela init` has no models).

## Multi-step plugin (`vela add step`)

`vela add step <Plugin> --entity Account --message Update --stage PostOperation --filtering-attributes Telephone1`
appends a step whose handler is **`Handle<Message>`** (e.g. `HandleUpdate(HandleUpdateContext ctx)`,
or the `--handler <Method>` name). `OnExecute` stays the first step's handler; don't rename generated
handlers. The plugin is now multi-step: harness tests must state the trigger (`.OnUpdate()` ...).

## RegisterStep() fluent surface

Callable only inside `RegisterPluginSteps()`. Options are discoverable via IntelliSense; the traps:

- **Trigger:** use the typed `On<Message>()` (`OnCreate()`, `OnUpdate()`, `OnDelete()`, `OnAssociate()`...).
  `On<TRequest>()` / `OnAsyncOnly<TRequest>()` / `OnMessage<TMessage>()` are only for Custom APIs and
  messages without a typed trigger - `On<UpdateRequest>()` is VELA023.
- **Mode:** `Sync()`, `Async()` / `Async(deleteJobOnSuccess: true)`. **Async is PostOperation-only.**
- **`FilterOn(e => e.Attr, ...)`** - required on every Create/Update(+Multiple) step (VELA020), and it
  **gates the trigger on Create too** (the Microsoft docs are wrong; see `dataverse-gotchas.md`). For
  "every create", filter on a column every create sends (e.g. a business-required `Name`).
- `WithStepKey(...)` when two steps on one trigger differ in no filter/image/relationship (VELA008);
  each single-value modifier at most once per step (VELA003). Secrets: `WithSecureConfigFrom("Name")`.

### Images and the generated per-handler context

A step with `WithPreImage`/`WithPostImage` gets a generated context named after its handler
(`<Handler>Context`) whose images expose **only the captured columns** - reading another is `CS1061`,
not a silent null:

```csharp
RegisterStep().OnUpdate().PreOperation().Sync()
    .FilterOn(a => a.CreditLimit)
    .WithPreImage(a => a.CreditLimit)            // only the columns you read
    .Handle(OnCreditLimitChanging);

private void OnCreditLimitChanging(OnCreditLimitChangingContext ctx)   // generated
{
    decimal before = ctx.PreImage.CreditLimit?.Value ?? 0m;
    decimal after = ctx.Request.Target.CreditLimit?.Value ?? 0m;
}
```

- Prefer the generated context (the message context also compiles, with a full-entity `PreImage`).
- Image read on a step that captures none: VELA017. One handler per image-capturing step: VELA016.
- `WithPostImage` exists only from PostOperation.

### Associate / Disassociate

Registered **message-level** (empty entity, as Dataverse requires). Scope it:

```csharp
RegisterStep().OnAssociate().PostOperation().Sync()
    .ForRelationship("contact_customer_accounts")     // (schemaName, params additionalSchemaNames)
    .Handle(OnExecute);
// OnExecute(OnExecuteContext ctx): ctx.Request.Target (EntityReference),
// ctx.Request.Relationship.SchemaName, ctx.Request.RelatedEntities
```

- `ForRelationship` is enforced at dispatch (out-of-scope requests are traced and skipped); without it
  the handler runs for **every** association in the org.
- The plugin's `<T>` does **not** filter the Target - it may be **either side** (an
  `EntityPluginBase<Contact>` handler received an `account` Target). Check
  `ctx.Request.Target.LogicalName` and the related entities' types before acting.

## Handler context

Use the generated **`{Handler}Context`** (e.g. `private void OnExecute(OnExecuteContext ctx)`) - Vela's recommended
signature: it derives from the message context, stays stable when images change, and types `ctx.PreImage` /
`ctx.PostImage` to the captured columns. `vela add plugin` / `add step` generate it; keep it (it also applies to
`On<TRequest>()`, the `On{X}()` extensions from `vela models --messages/--custom-apis` and `OnAsyncOnly<T>()`, not to
`OnMessage<T>()` - use `On<TRequest>()` there). Hand-written plugins must be `partial` (VELA014). A context that doesn't match the step is VELA015. Add `using Microsoft.Xrm.Sdk;` for `Money`,
`EntityReference`, `InvalidPluginExecutionException` (generated files don't import it).

- **Target: `ctx.Request.Target`** - a typed `Account` over the live InputParameters: setting a property
  in PreOperation changes the record being written. In an **Async** step a Target write has no effect
  (VELA018). `ctx.GetTarget<Account>()` / `TryGetTarget` / `GetTargetRef` are for `ILocalPluginContext`
  handlers (Custom APIs, `On<TRequest>()`).
- **Bulk (`*Multiple`):** `ctx.Request.Targets.Entities` (untyped). `e.ToEntity<Account>()` shares the
  attribute collection, so editing the typed copy in PreOperation edits the target. Never call `Update`
  per record inside the loop.
- **Sent? Changed?** (`using Vela.Querying;`): `target.Contains(e => e.AccountNumber)` (also `Contains(a, b)`
  = all, `ContainsAny`) tests presence in the payload; `ctx.HasChanged<Account>(e => e.Name)` = in the
  Target **and** differs from the pre-image (needs a pre-image with that column - VELA009; absent from
  the Target counts as unchanged; Delete/Assign/SetState throw). Never logical-name strings.
- **Read the org - typed** (`using Vela.Querying;`), never logical-name strings:
  ```csharp
  List<Contact> contacts = Query.For<Contact>()
      .Select(c => c.LastName, c => c.EmailAddress1)
      .Where(c => c.ParentCustomerId, ConditionOperator.Equal, accountId)
      .ToList(ctx.Service);   // or .FirstOrDefault(svc), .CountScalar(svc, c => c.ContactId), .Top(n)
  ```
  By id: `ctx.Service.Retrieve(Account.EntityLogicalNameValue, id, new ColumnSet(...)).ToEntity<Account>()`.
- **Delete:** `ctx.Request.Target` is an **`EntityReference`** (no columns) - read what you need with a
  typed query or `WithPreImage`; no `FilterOn`, no post-image. To **block** a delete, throw
  `InvalidPluginExecutionException` from a **Sync PreValidation** step (before the operation and its
  cascades); an Async step blocks nothing.
- **Depth:** `ctx.Depth` (recursion: `dataverse-gotchas.md`).
- **Write to the org** (no `ctx.OrganizationService`, no `ctx.UserService`):
  - `ctx.Service` - the step's user (the impersonated user, else the caller); record-level security
    applies. **The default**, and what DI resolves for `IOrganizationService`.
  - `ctx.SystemService` - SYSTEM, bypasses security; only where elevation is intended.
  - `ctx.AsUser(userId)` - a specific user, e.g. `ctx.AsUser(ctx.InitiatingUserId)`.
- **Secure configuration:** `.WithSecureConfigFrom("Name")`; the value is supplied at deploy time
  (`vela plan|apply --secure-config Name=VALUE|Name=@file`, or `VELA_SECURE_CONFIG_Name`) and read through
  the base `SecureConfig` property. Only the name is in the assembly.
- **Trace:** `ctx.Trace(format, args)`.

## Dependency injection (service into a handler)

```csharp
using Vela.DI;

protected override void ConfigureServices(SimpleServiceResolver services, ILocalPluginContext context)
    => services.AddScoped<IAccountDescriptionDefault>(r => new AccountDescriptionDefault(r.GetRequiredService<IOrganizationService>()));

private void HandleUpdate(HandleUpdateContext ctx)
    => ctx.GetRequiredService<IAccountDescriptionDefault>().Execute(ctx.Request.Target);
```

- `vela add service <Name> --entity Account` generates the interface + class (in `Account/Services/`)
  and prints the registration line. Reshape `Execute` to what the Canvas needs; a pure rule may drop the
  `IOrganizationService` parameter.
- Keep the handler thin; real logic in the service. In a test, `WithService<T>(fake)` **replaces the
  registration** (`harness-api.md`) - no test-only constructor in the plugin.

## Custom API authoring (`vela add customapi`)

Unique name `<publisher prefix>_<Name>`: the prefix comes from `--prefix`, else the project's
`<VelaPublisherPrefix>` (from `vela init --publisher-prefix`), else the project prefix.
`vela add customapi <Name>` (no `--entity`) generates the untyped global form (`GlobalCustomApis/`):

```csharp
public sealed class ScoreLead(string unsecureConfig, string secureConfig)
    : CustomApiBase(unsecureConfig, secureConfig)
{
    protected override void RegisterCustomApi()
    {
        RegisterCustomApi("zava_ScoreLead", Handle)     // handler bound here - no .Handle(...) terminal
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

- **Asymmetry:** `RequestParameter<T>(name, bool optional = false, description)` has `optional`;
  `ResponseParameter<T>(name, description)` does **not**.
- `.AsAction()` - side effects, **and anything Power Automate calls** (the connector only calls
  Actions); "POST" in a story = Action. `.AsFunction()` - read-only, **must declare a response
  property**. The kind can't change after creation. No HTTP status codes: signal errors with
  `InvalidPluginExecutionException` (VELA012).

### Bound / typed form (`vela add customapi <Name> --entity <E>`)

Generates a typed API in `<Entity>/CustomApis/` with request/response classes in the same file
(`CustomApiRequest` / `CustomApiResponse`, `using Vela.Messages;`):

```csharp
public sealed class RecalcAccount(string unsecureConfig, string secureConfig)
    : CustomApiBase<RecalcAccountRequest, RecalcAccountResponse>(unsecureConfig, secureConfig)
{
    protected override void RegisterCustomApi()
    {
        RegisterCustomApi("zava_RecalcAccount")
            .AsFunction()
            .BoundTo<Account>()
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
// The scaffold seeds a placeholder response `Result` property - rename or replace it.
```

- Without `.Request(...)`/`.Response(...)` every property is registered; once called, only mapped ones.
- Parameter names = property names: **plain identifiers**, no dot, no prefix. Check what will register
  with `new <Api>(string.Empty, string.Empty).GetCustomApiDefinition()`.
- Rejected when the definition is built (harness `Register`, `vela plan` - not `dotnet build`): a
  non-identifier name, a Function with no response property, a duplicate name. A unique name **without
  the publisher prefix is not rejected locally** - review is the guard (`vela apply --solution` rejects it).
- Callers: `service.Execute(new RecalcAccountRequest { ... }).ToResponse<RecalcAccountResponse>()`
  (`using Vela.Context;`); a bound API needs `Target` set on the request.

## Platform services - decide in the Canvas, read the Vela guide for the API

| Need | Use | Guide |
| --- | --- | --- |
| A message the user sees (business error) | a localized key: `throw ctx.BusinessError("KEY", args)` / `ctx.GetMessage`; the source (in-code dictionary, a Dataverse labels table, String (RESX) web resources) is the project's convention - ask the human | [localization](https://allandecastro.github.io/vela/guides/localization) |
| A value that differs per environment (URL, threshold, id, feature flag) | an environment variable: `ctx.GetEnvironmentVariable("pfx_Name")` / `GetEnvironmentVariableAs<T>` (secrets stay in secure config) | [environment variables](https://allandecastro.github.io/vela/guides/environment-variables) |
| Reference data read on every execution | `IPluginCacheService` (per-organization, with a TTL the human accepted - a change shows only after it - recorded in the Canvas); never cache data read as the calling user across users | [caching](https://allandecastro.github.io/vela/guides/caching) |
| Operational logs (Application Insights + trace log) | `ctx.LogInformation` / `LogWarning` / `LogError`; `ctx.Trace` stays for debug detail | [telemetry](https://allandecastro.github.io/vela/guides/telemetry) |
| Behaviour that depends on the user's rights | a test with `WithSecurity(...)` (roles, business units, teams) | [security model](https://allandecastro.github.io/vela/guides/security-model) |
| Harness and org disagree | check what the harness does not model before suspecting the code | [limitations](https://allandecastro.github.io/vela/reference/limitations) |

