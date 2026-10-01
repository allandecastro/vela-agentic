---
name: vela-custom-api
description: Use when a story asks for a callable operation (an endpoint, action, function or message other code or a flow invokes) rather than a reaction to a table event, or when a Vela Custom API must be added, changed or tested.
compatibility: "vela CLI >= 0.21.4 (Vela.Plugins >= 0.29.1); dotnet SDK."
---

# Build a Vela Custom API

> Paths like `references/<file>.md` in this skill are relative to **this skill's folder** (the
> directory containing this `SKILL.md`), not to the project you are working in.

A Custom API is a message you define: other code, Power Automate or a client calls it by its unique
name, and your handler returns outputs. It is the right tool when the story says "expose", "call",
"endpoint", "action", "compute on demand" - not "when a record is created/updated" (that is a plugin
step). It follows the same loop: Canvas → scaffold → RED tests → implement → verify → review → preview.

## When to use

- The story describes an operation that someone **calls**, with inputs and outputs.
- An existing Custom API needs a new parameter, a behaviour change, or tests.

## Process

Announce: `Using vela-custom-api to <purpose>`.

1. `vela version`; `vela add --help` to confirm flags (`references/cli-surface.md`).
2. **Decide in the Vela Canvas** (Approach/Structure), each with a reason:
   - **Global or bound?** Operates on one record of a table → bound (`--entity <E>`, the record comes
     as the target); otherwise global.
   - **Action or Function?** Decide by **who calls it**, then by side effects:
     - called from **Power Automate / flows / workflows** (the Dataverse connector) → **Action**, even
       for a pure computation - the connector can only call Actions;
     - side effects (writes, sends) → **Action**; "POST" in a story means Action;
     - a pure read/computation called only from code or the Web API with GET → **Function**.
     The kind **cannot be changed after the Custom API is created** in the org - get it right here.
   - **Parameters:** names, types, required/optional, and the outputs. Names are **dot-free** and
     short (`email`, `leadScore`); the unique name is `<publisher prefix>_<Name>`.
   - **Errors:** which invalid inputs throw `InvalidPluginExecutionException`, with which message. A
     Custom API has no HTTP status codes.
   - **Exposure:** `.Private()` if only your own code calls it; `.ExecutePrivilege(...)` if callers need
     a specific privilege; `.AllowedCustomProcessingSteps(CustomApiAllowedCustomProcessingStepType.None)`
     unless others must hook plugins on it (`AsyncOnly` / `SyncAndAsync`).
3. **Scaffold** with `vela-scaffold`: `vela add customapi <Name> [--entity <E> | --global] [--action|--function]
   [--prefix <publisher prefix>]` (`--global` is the explicit form of "no `--entity`"). Global → a lightweight untyped class (handler passed to
   `RegisterCustomApi(name, handler)`); `--entity` → a **typed** class
   (`CustomApiBase<TRequest, TResponse>`, `Execute(ctx, request)`) with request/response classes. Both
   shapes are in `references/plugin-authoring-api.md` - don't convert one into the other by hand.
4. **Tests first (RED)** with `vela-test-harness`: `vela add test <Name> --kind customapi`, then one
   test per acceptance case - outputs for valid inputs, each edge, and each invalid input throwing
   `InvalidPluginExecutionException` (recipe in `references/harness-api.md`). Watch them fail.
5. **Implement** to green:
   - Global: declare parameters with `.RequestParameter<T>(name, optional, description)` /
     `.ResponseParameter<T>(name, description)`; read with `ctx.GetInputParameter<T>(name)`, write with
     `ctx.SetOutputParameter(name, value)`.
   - Typed: add a property per parameter on the request/response classes (`Get<T>()` / `Set(value)`)
     **and** map it with `.Request(r => r.Add(x => x.Prop))` / `.Response(r => r.Add(x => x.Prop))`.
   - Real logic in a service when it earns it (same SOLID/DRY rules as plugins).
6. **Callers in C#** (another plugin, the Integrations project) use typed classes: for an API that
   exists in the org, `vela models --custom-apis <uniquename>` generates them (`vela-models`); for your
   own typed API, the request class itself is callable
   (`service.Execute(new <Name>Request { ... }).ToResponse<<Name>Response>()`).
7. Continue the loop: verify (suite green, analyzers clean) → `vela-code-review` → `vela-apply`
   (the preview lists the Custom API and its parameters).

## Rationalizations (excuse → rebuttal)

- "It's triggered by the UI, so it's a plugin step." → If someone *calls* it with inputs and expects
  outputs, it is a Custom API; a step reacts to a table event.
- "I'll name the parameter `Account.Id`." → A dot makes it uncallable on a real org. `AccountId`.
- "I'll return an error code in an output." → Callers expect a fault. Throw
  `InvalidPluginExecutionException` with a clear message.
- "It only computes, so it's a Function." → Not if a flow calls it: the Dataverse connector only
  calls Actions, and the kind can't be changed after creation. Callers first.
- "I added the property, it's enough." → On the typed form an unmapped property is not a registered
  parameter. Map it in `.Request(...)` / `.Response(...)`.

## Red flags

- A parameter or unique name containing a dot, or a unique name without the target solution's
  publisher prefix.
- A Function that writes data, or a Function the story says a flow / Power Automate calls.
- A typed request/response property not mapped in `.Request(...)` / `.Response(...)`.
- Using the internal `<uniquename>.<prop>` keys from the generated comments as parameter names.
- No test for an invalid input.

## Verification

- The Canvas records global/bound, Action/Function (with the callers), parameters and error cases,
  each with a reason.
- Optional self-check of what will be registered: a test reading
  `CustomApiDefinitionReader.GetCustomApiDefinitions(typeof(<Api>).Assembly)` (`references/plugin-authoring-api.md`).
- Harness tests cover every acceptance case including the failing inputs, seen RED then green (runner
  summary pasted).
- Build clean of VELA00x in authored code; review PASS; `vela plan` shows the Custom API with the
  expected parameters (or `skipped - no org` with the exact command).
