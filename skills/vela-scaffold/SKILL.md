---
name: vela-scaffold
description: Use when a new Vela solution is needed, or a component (plugin, custom API, service, step, test) must be added to an existing project.
compatibility: "vela CLI >= 0.26.0 (Vela.Plugins >= 0.35.0); dotnet SDK."
---

# Scaffold Vela projects and components

> Paths like `references/<file>.md` in this skill are relative to **this skill's folder** (the
> directory containing this `SKILL.md`), not to the project you are working in.

Drive `vela init` and `vela add` to create a solution or add components. These commands are
**local only** and never connect to Dataverse.

Two kinds of files - don't confuse them:
- **Generated** - `Models/Generated/*` (from `vela models`) and compiler-generated code. Never
  hand-edit; regenerate.
- **Scaffolded** - the plugin / step / Custom API / service / test files `vela add` writes once for
  you. They are **yours**: you implement them, and you adjust their registration to the Canvas
  (stage, `FilterOn`, images). The contract is that they compile as generated, not that they stay
  untouched.

## When to use

- Start a new Vela solution.
- Add a plugin, step, custom API, service, or test to an existing Vela project.

## Process

Announce: `Using vela-scaffold to <purpose>`.

1. `vela version`; confirm the exact flags with `vela init --help` / `vela add --help` (or `vela help --json`
   for all of them; `references/cli-surface.md`).
2. **Confirm the target solution and its publisher prefix (read-only):**
   `vela solution show <uniquename> --json <connection>` → `{"solution":"...","publisherPrefix":"..."}`.
   The solution unique name comes from the story or the human (`vela-grill`) - never invented; the
   prefix comes from this command, not from a guess. Exit `4` = the solution does not exist (Vela does
   not create it): an open question that blocks the apply gate. Exit `6` (no connection): record the
   exact command and its exit code, and carry the prefix as a flagged assumption.
3. **New solution?** `vela init <Name> --prefix <Prefix> --publisher-prefix <publisherPrefix> -o <dir>`.
   It creates `<dir>/<Name>/` (nested under `-o`) and is **minimal**: `src/<Prefix>.Shared` (models),
   `src/<Prefix>.Plugins` (the plugin package), `tests/<Prefix>.Plugins.Tests` - no demo code, no
   models. Add `--integrations` when the Canvas records an outbound call (HTTP API, queue, ...): an
   **empty** `src/<Prefix>.Integrations` plugin project (references `System.Net.Http`) + its tests, which
   builds its own package - the outbound code goes there. Two different prefixes:
   - `--prefix` - the **namespace / assembly prefix**, used verbatim, so pass it PascalCase
     (`--prefix Zava` → `Zava.Plugins`; `--prefix zava` → `zava.Plugins`). Omitted → the solution name.
   - `--publisher-prefix` - the **Dataverse publisher prefix** from step 2 (2-8 chars, e.g. `zava`),
     recorded as `<VelaPublisherPrefix>`; `vela add customapi` names APIs `<publisherPrefix>_<Name>`
     with it (see `references/registration-rules.md`). `plan`/`apply` take the prefix from `--solution`.
   - Never `--samples` for a real project: it adds the demos and a ConsoleApp (`--no-integrations`/
     `--no-console` only apply with it); `--integrations` gives the Integrations project without them
     (`--managed-identity` implies it). `--no-tests` never - tests are the acceptance criteria.
   - `vela init` also writes an `AGENTS.md` in the project (Vela's own agent guide: layout, commands,
     code samples). It is useful context, but **this pack's skills govern**. Where it differs, follow the
     pack: it shows `vela models ... --interactive` (use the resolved headless connection) and
     `vela plan --packages-dir artifacts` (preview the exact package(s) with `-p`, see `vela-apply`); its
     Custom API example (`CustomApiBase<TRequest, TResponse>` + `CustomApiRequest`/`CustomApiResponse`)
     is valid. Our rule on `apply` is stricter: stop before it, never `--auto-approve` unless authorized.
4. **Generate the models before the first plugin** (`vela-models`): the scaffold has none, and a plugin on
   `Account` does not compile until the model exists (`CS0234` "The type or namespace name 'Shared' does
   not exist" / `CS0118`). `vela models --entities <tables> --project src/<Prefix>.Shared/<Prefix>.Shared.csproj <connection>` -
   `--project` puts them in `<Prefix>.Shared/Models/Generated` with that project's namespace.
5. **Decide reuse vs new first** (see `references/registration-rules.md`):
   - **New plugin, no class exists yet** → `vela add plugin` via the CLI, then code. **Never
     hand-create the plugin class.**
   - **Another behaviour on a table that already has a plugin** → prefer `vela add step` on the
     existing plugin (coherent registration) unless the concern is genuinely separate.
   - **Reuse** an existing plugin/step/service when the behaviour is already there - don't duplicate (DRY).
6. **Add the component** - always with `--project <path>.csproj` (without it, outside a project folder,
   `vela add` prints "No .csproj found" and exits `2`); read the "Created"/"Added" line (or `--json`'s `created`):
   - Plugin: `vela add plugin <Name> --entity <ModelType> --message <Msg> --stage <PreValidation|PreOperation|PostOperation> --mode <Sync|Async> --filtering-attributes <A,B> --project src/<Prefix>.Plugins/<Prefix>.Plugins.csproj`
     (an outbound plugin: `--project src/<Prefix>.Integrations/<Prefix>.Integrations.csproj`). `--filter` is
     the short alias; logical names are mapped to the model property (`name` → `FilterOn(e => e.Name)`, with
     a "corrected to" note). Create/Update(+Multiple) without a filter exits `2`.
   - Extra step on a plugin: `vela add step <PluginName> --entity <ModelType> --message <Msg> --stage <Stage> --mode <Mode> --filtering-attributes <A,B> --project ...`
   - Custom API: `vela add customapi <Name> [--entity <E>] [--function|--action] [--project ...]` - the unique
     name is `<VelaPublisherPrefix>_<Name>` (`--prefix <pub>` overrides it); omit `--entity` for a global
     API. Design it with `vela-custom-api` first.
   - Test: `vela add test <PluginName> --kind plugin|customapi [--entity <E>] [--message <Msg>] --project tests/<Prefix>.Plugins.Tests/<Prefix>.Plugins.Tests.csproj`
     (`--prefix` for a Custom API test when the project records none; an Integrations plugin's tests go in
     `tests/<Prefix>.Integrations.Tests`). A plugin gets a pipeline "fires" test + a skipped "does what it
     should" stub; a Custom API a unique-name test + a skipped execution test - `vela-test-harness` fills them.
7. **Scaffold the registration the Canvas decided** - pass `--stage`, `--mode` and `--filtering-attributes`
   to `add plugin` / `add step`; the chain, the handler's context type and the `FilterOn` are generated to
   match. Then **read the generated chain** against the Canvas: stage, mode and filter must be what you
   asked for. (Defaults when omitted: `--message Create`, PostOperation, Sync.)
   - After `vela add step` the plugin is **multi-step**: its new handler is `Handle<Message>`, and its
     harness tests must now state the trigger (`.OnCreate()` / `.OnUpdate()`, see `references/harness-api.md`).
8. **Build** to prove it compiles: `dotnet build <Name>.sln -c Release`. Report the exact output. A
   `FilterOn` on a column the model lacks fails with `CS1061` - regenerate the model (`vela-models`), never
   hand-edit it.
9. Summarise what was generated and the next skill in the loop.

## Rationalizations (excuse → rebuttal)

- "I'll just edit the generated file to make it compile." → If *generated* code (models,
  compiler output) doesn't compile, that's a bug to report, not to patch. Re-run the command with
  correct inputs. (Adjusting the *scaffolded* plugin's stage or `FilterOn` is not that - it is expected.)
- "I'll let `vela add` pick the stage." → Its default is PostOperation + Sync; the Canvas decides the stage -
  pass `--stage` / `--mode`.
- "The prefix is probably the solution name lower-cased." → `vela solution show <uniquename> --json`
  reads it; a guessed publisher prefix breaks the Custom API unique names at apply.
- "I'll add the plugin first and generate models later." → It does not compile without the model; run
  `vela models --project` first.
- "I'll create the plugin file by hand, it's just a class." → A typed message touches
  several files that must stay in sync (see gotchas). Use `vela add`.
- "`--message` doesn't matter, I'll set it in code." → It drives the registration and the
  filtering-attribute requirement. Pass it.

## Red flags

- You are about to hand-edit a generated file (`Models/Generated`, compiler output).
- The Canvas says PreOperation but the scaffolded step still says `.PostOperation()`.
- `vela init --samples` (demos, Integrations, ConsoleApp) for a project headed for `vela apply`; or
  outbound code in the Plugins project instead of a `--integrations` project.
- A lower-case `--prefix` (namespaces like `zava.Plugins`), or a `--publisher-prefix` nobody confirmed
  with `vela solution show`.
- A committed file is named `*.generated.cs` (often gitignored).
- You guessed a flag instead of reading `--help`.
- You accepted the generated `FilterOn` without checking it: a column the Canvas did not choose ships
  a wrong registration.
- You used `--interactive` on `vela init`/`vela add` (a TTY wizard - an agent must pass flags).
- You followed the scaffold's `AGENTS.md` where it contradicts the pack (e.g. `vela models --interactive`).
- The **build fails right after `vela models`** with an error in generated code (an incompatible
  auto-resolved framework version): pin a known-good core with `vela init --core-version <v>` (see
  `references/cli-surface.md`) and report the regression.

## Verification

- `dotnet build` succeeds - paste the output.
- `vela solution show` output (or the exact command + exit code when unavailable) recorded in the Canvas.
- The component is present where the CLI reported it; its only edits are the ones step 7 calls for
  (stage/context type, `FilterOn`) - the logic comes later, in `vela-plugin-authoring`.
