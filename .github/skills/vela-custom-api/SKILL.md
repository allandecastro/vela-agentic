---
name: vela-custom-api
description: Use when a story asks for a callable operation (an endpoint, action, function or message other code or a flow invokes) rather than a reaction to a table event, or when a Vela Custom API must be added, changed or tested.
compatibility: "vela CLI + dotnet SDK."
license: MIT
metadata:
  version: "0.1.0"
---

# Build a Vela Custom API

> Paths like `references/<file>.md` in this skill are relative to **this skill's folder** (the
> directory containing this `SKILL.md`), not to the project you are working in.

A message you define that code, flows or a client call by unique name ("expose", "call", "endpoint",
"compute on demand" - not "when a record is created/updated", a plugin step). Same build loop. Shapes:
`references/plugin-authoring-api.md` ("Custom API authoring").

## When to use

- The story describes an operation that someone **calls**, with inputs and outputs.
- An existing Custom API needs a new parameter, a behaviour change, or tests.

## Process

Announce: `Using vela-custom-api to <purpose>`.

1. `vela version`; confirm flags with `vela add --help`.
2. **Decide in the Vela Canvas** (Approach/Structure), each with a reason:
   - **Global or bound?** Operates on one record of a table → bound (`--entity <E>`); otherwise global.
   - **Action or Function?** By **caller** first, then side effects: called from **Power Automate /
     flows** → **Action**, even if pure (the connector only calls Actions); writes/sends or "POST" →
     Action; pure read called only from code / Web API GET → **Function** (needs at least one output).
     The kind **cannot change after creation** in the org.
   - **Parameters:** names, types, required/optional, outputs. **Plain identifiers**, short (`email`,
     `leadScore`). Unique name `<publisher prefix>_<Name>`, the target solution's publisher prefix.
   - **Errors:** which invalid inputs throw `InvalidPluginExecutionException`, with which message (no HTTP
     codes). Invalid beyond the story is the human's call (`vela-grill`).
   - **Exposure:** `.Private()` if only your code calls it; `.ExecutePrivilege(...)` if callers need a
     privilege; `.AllowedCustomProcessingSteps(CustomApiAllowedCustomProcessingStepType.None)` unless
     others must hook plugins on it (`AsyncOnly` / `SyncAndAsync`).
3. **Scaffold** (`vela-scaffold`): `vela add customapi <Name> --prefix <publisherPrefix> [--entity <E> | --global] [--action|--function]`
   (prefix from `PROJECT.md`); check the generated unique name against
   the Canvas. Rename or replace the typed form's placeholder `Result` property. Never convert global ↔
   typed by hand.
4. **Tests first (RED)** (`vela-plugin-testing`): `vela add test <Name> --kind customapi` (set the inputs,
   remove `Skip`), one test that pins the definition (kind, binding, parameters - a flow breaks when they change),
   then one test per acceptance case - outputs for valid inputs, each edge, each invalid
   input throwing `InvalidPluginExecutionException` (`references/harness-api.md`). A missing **required**
   input is rejected by the harness itself - validate values, not presence. Watch them fail.
5. **Implement** to green (`references/plugin-authoring-api.md`). Typed form: a property per parameter
   **and** its mapping in `.Request(...)` / `.Response(...)` - an unmapped property is not registered.
   Real logic in a service when it earns it.
6. **Callers.** C#: `vela models --custom-apis <uniquename>` for an API in the org; your own typed request
   class is callable directly. **Client** (form button, ribbon): `form-script|ribbon-script` is not covered
   by the pack - build the server side and record in the Canvas and Build Report, as an open item for the human (not as their decision or
   a pack rule), what the client must call (unique name, binding, parameters, Function → GET / Action → POST).
7. Continue: verify (suite green, analyzers clean) → `vela-code-review` → `vela-apply` (the preview lists
   the Custom API and its parameters).

## Rationalizations (excuse → rebuttal)

- "It's triggered by the UI, so it's a plugin step." → Called with inputs/outputs = Custom API.
- "I'll name the parameter `Account.Id`." → Rejected; `AccountId`.
- "I'll return an error code in an output." → Callers expect a fault: throw
  `InvalidPluginExecutionException`.
- "It only computes, so it's a Function." → Not if a flow calls it; the kind can't change later.
- "I added the property, it's enough." → Typed form: map it in `.Request(...)` / `.Response(...)`.

## Red flags

- A non-identifier parameter name, or a unique name without the publisher prefix (nothing local checks it).
- A Function that writes, or one the story says a flow calls.
- A typed property not mapped in `.Request(...)` / `.Response(...)`.
- The internal `<uniquename>.<prop>` keys from generated comments used as parameter names.
- No test for an invalid input.

## Verification

- The Canvas records global/bound, Action/Function (with callers), parameters and error cases, each with
  a reason.
- The definition test reads `new <Api>(string.Empty, string.Empty).GetCustomApiDefinition()`.
- Harness tests cover every acceptance case incl. failing inputs, seen RED then green (summary pasted).
- Build clean of VELA diagnostics in authored code; review PASS; `vela plan` shows the Custom API with the
  expected parameters (or `plan_preview: unavailable` with the exact command + exit code).
