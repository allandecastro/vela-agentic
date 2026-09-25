---
name: vela-scaffold
description: Use when a new Vela solution is needed, or a component (plugin, custom API, service, step, test) must be added to an existing project.
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
3. **Decide reuse vs new first** (see `references/registration-rules.md`):
   - **New plugin, no class exists yet** → `vela add plugin` via the CLI, then code. **Never
     hand-create the plugin class.**
   - **Another behaviour on a table that already has a plugin** → prefer `vela add step` on the
     existing plugin (coherent registration) unless the concern is genuinely separate.
   - **Reuse** an existing plugin/step/service when the behaviour is already there — don't duplicate (DRY).
4. **Existing project?** Find the `.csproj` first, then add the component:
   - Plugin: `vela add plugin <Name> --entity <ModelType> [--message Create|Update|...] [--filtering-attributes a,b]`
   - Extra step on a plugin: `vela add step <PluginName> --entity <ModelType> --message <Msg>`
   - Custom API: `vela add customapi <Name> [--bound|--global] [--function|--action]`
   - Test: `vela add test <Name> --kind plugin|customapi` (must be inside a `.Tests` project)
5. **Fix the `FilterOn` placeholder before building.** `vela add plugin`/`add step` may emit a
   placeholder `FilterOn(e => e.Id /* TODO: choose the attributes */)` or echo the casing you
   passed (`--filtering-attributes name` → `e => e.name`, which won't compile). Replace it with the
   real typed column (`e => e.Name`) — `e.Id` is the key, never a valid filtering attribute.
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
- You left a generated `FilterOn(e => e.Id)` placeholder or an echoed lowercase attribute
  (`e => e.name`) in place — it ships a wrong or non-compiling registration.

## Verification

- `dotnet build` succeeds — paste the output.
- The generated component is present where the CLI reported it, unedited.
