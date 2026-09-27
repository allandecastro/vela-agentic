---
name: vela-scaffold
description: Use when a new Vela solution is needed, or a component (plugin, custom API, service, step, test) must be added to an existing project.
compatibility: "vela CLI >= 0.19.4 (Vela.Plugins >= 0.28.2); dotnet SDK."
---

# Scaffold Vela projects and components

Drive `vela init` and `vela add` to create a solution or add components. These commands are
**local only** and never connect to Dataverse. Generated code must compile and apply
**without hand edits** - that is the contract.

## When to use

- Start a new Vela solution.
- Add a plugin, step, custom API, service, or test to an existing Vela project.

## Process

Announce: `Using vela-scaffold to <purpose>`.

1. `vela version`; confirm the exact flags with `vela init --help` / `vela add --help`.
2. **New solution?** `vela init <Name> [--prefix <pub>] [-o <dir>]`. The prefix cannot be
   `Vela`. **Don't invent a prefix - use the target Dataverse solution's own publisher
   customization prefix** (see `references/registration-rules.md`); it must match, otherwise
   `vela apply --solution` rejects
   the unique names later. The target solution + publisher must already exist in the org (Vela
   does not create them). This emits **6 projects** under `src/` + `tests/`: `<Prefix>.Shared`,
   `<Prefix>.Plugins`, `<Prefix>.Integrations`, `<Prefix>.Plugins.Tests`,
   `<Prefix>.Integrations.Tests`, `<Prefix>.ConsoleApp` (trim with `--no-console` /
   `--no-integrations` / `--no-tests`). **Generated models live in
   `<Prefix>.Shared/Models/Generated`** - that is the `--project` target for `vela models`,
   not the Plugins project.
3. **Decide reuse vs new first** (see `references/registration-rules.md`):
   - **New plugin, no class exists yet** → `vela add plugin` via the CLI, then code. **Never
     hand-create the plugin class.**
   - **Another behaviour on a table that already has a plugin** → prefer `vela add step` on the
     existing plugin (coherent registration) unless the concern is genuinely separate.
   - **Reuse** an existing plugin/step/service when the behaviour is already there - don't duplicate (DRY).
4. **Existing project?** Find the `.csproj` first, then add the component:
   - Plugin: `vela add plugin <Name> --entity <ModelType> [--message Create|Update|...] [--filtering-attributes a,b]`
   - Extra step on a plugin: `vela add step <PluginName> --entity <ModelType> --message <Msg>`
   - Custom API: `vela add customapi <Name> [--entity <E>] [--function|--action] [--prefix <pub>]`
     (omit `--entity` for a global API; the unique name is `<prefix>_<Name>`)
   - Test: `vela add test <Name> --kind plugin|customapi` (must be inside a `.Tests` project)
5. **Verify the generated `FilterOn` before building** (it may be wrong yet compile):
   - `vela add step` emits a `FilterOn(e => e.Id /* TODO */)` placeholder that **fails the build with
     VELA001** ("'Id' is not a Dataverse column") - replace it with the column that gates the step.
   - `vela add plugin` may echo the casing you passed (`--filtering-attributes name` -> `e => e.name`,
     won't compile), OR **auto-pick a column** (marked `/* auto-selected */`, e.g. `--entity Incident`
     -> `e => e.caseage`) that compiles fine and, on Create, is runtime-ignored so nothing errors.
   Replace it with the intended column (`e => e.Name`): confirm it is the right filtering attribute,
   not merely that it builds.
   - After `vela add step` the plugin is **multi-step**: its new handler is `Handle<Message>`, and its
     harness tests must now state the trigger (`.OnCreate()` / `.OnUpdate()`, see `references/harness-api.md`).
6. **Build** to prove it compiles: `dotnet build`. Report the exact output.
7. Summarise what was generated and the next skill in the loop.

## Rationalizations (excuse → rebuttal)

- "I'll just edit the generated file to make it compile." → If generated code doesn't
  compile, that's a bug to report, not to patch. Re-run the command with correct inputs.
- "I'll create the plugin file by hand, it's just a class." → A typed message touches
  several files that must stay in sync (see gotchas). Use `vela add`.
- "`--message` doesn't matter, I'll set it in code." → It drives the registration and the
  filtering-attribute requirement. Pass it.

## Red flags

- You are about to hand-edit a generated file.
- Prefix is `Vela` (rejected) or a committed file is named `*.generated.cs` (gitignored).
- You guessed a flag instead of reading `--help`.
- You accepted the generated `FilterOn` without checking it: a placeholder (`e => e.Id`, VELA001), an
  echoed lowercase attribute (`e => e.name`), or an auto-picked non-primary column (`e => e.caseage`)
  ships a wrong registration even when it compiles.
- You used `--interactive` on `vela init`/`vela add` (a TTY wizard - an agent must pass flags).
- The **baseline scaffold build fails right after `vela init`** (an incompatible auto-resolved
  framework version): pin a known-good core with `vela init --core-version <v>` (see
  `references/cli-surface.md`) and report the regression.

## Verification

- `dotnet build` succeeds - paste the output.
- The generated component is present where the CLI reported it, unedited.
