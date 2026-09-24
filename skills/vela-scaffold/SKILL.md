---
name: vela-scaffold
description: Use when you need to create a new Vela solution (vela init) or add a component to an existing project (vela add plugin/customapi/service/test/step). Local only, never touches Dataverse. Generated code must compile and apply unedited.
---

# Scaffold Vela projects and components

Drive `vela init` and `vela add` to create a solution or add components. These commands are
**local only** and never connect to Dataverse. Generated code must compile and apply
**without hand edits** — that is the contract.

## When to use

- Start a new Vela solution.
- Add a plugin, step, custom API, service, or test to an existing Vela project.

## Process

Announce: `Using vela-scaffold to <purpose>`.

1. `vela version`; confirm the exact flags with `vela init --help` / `vela add --help`.
2. **New solution?** `vela init <Name> [--prefix <pub>] [-o <dir>]`. The prefix cannot be
   `Vela`. This emits **6 projects** under `src/` + `tests/`: `<Prefix>.Shared`,
   `<Prefix>.Plugins`, `<Prefix>.Integrations`, `<Prefix>.Plugins.Tests`,
   `<Prefix>.Integrations.Tests`, `<Prefix>.ConsoleApp` (trim with `--no-console` /
   `--no-integrations` / `--no-tests`). **Generated models live in
   `<Prefix>.Shared/Models/Generated`** — that is the `--project` target for `vela models`,
   not the Plugins project.
3. **Existing project?** Find the `.csproj` first, then add the component:
   - Plugin: `vela add plugin <Name> --entity <ModelType> [--message Create|Update|...] [--filtering-attributes a,b]`
   - Extra step on a plugin: `vela add step <PluginName> --entity <ModelType> --message <Msg>`
   - Custom API: `vela add customapi <Name> [--bound|--global] [--function|--action]`
   - Test: `vela add test <Name> --kind plugin|customapi` (must be inside a `.Tests` project)
4. **Build** to prove it compiles: `dotnet build`. Report the exact output.
5. Summarise what was generated and the next skill in the loop.

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

## Verification

- `dotnet build` succeeds — paste the output.
- The generated component is present where the CLI reported it, unedited.
