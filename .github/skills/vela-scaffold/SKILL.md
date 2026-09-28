---
name: vela-scaffold
description: Use when a new Vela solution is needed, or a component (plugin, custom API, service, step, test) must be added to an existing project.
compatibility: "vela CLI >= 0.19.6 (Vela.Plugins >= 0.28.2); dotnet SDK."
---

# Scaffold Vela projects and components

> Paths like `references/<file>.md` in this skill are relative to **this skill's folder** (the
> directory containing this `SKILL.md`), not to the project you are working in.

Drive `vela init` and `vela add` to create a solution or add components. These commands are
**local only** and never connect to Dataverse.

Two kinds of files - don't confuse them:
- **Generated** - `Models/Generated/*` (from `vela models`) and compiler-generated code. Never
  hand-edit; regenerate. (One sanctioned no-org exception: `vela-plugin-authoring` step 2.)
- **Scaffolded** - the plugin / step / Custom API / service / test files `vela add` writes once for
  you. They are **yours**: you implement them, and you adjust their registration to the Canvas
  (stage, `FilterOn`, images). The contract is that they compile as generated, not that they stay
  untouched.

## When to use

- Start a new Vela solution.
- Add a plugin, step, custom API, service, or test to an existing Vela project.

## Process

Announce: `Using vela-scaffold to <purpose>`.

1. `vela version`; confirm the exact flags with `vela add --help` (command-specific) and `vela --help`
   (the other commands' flags are listed there - `vela init --help` prints the same global page).
2. **New solution?** `vela init <Name> [--prefix <pub>] [-o <dir>]` - it creates `<dir>/<Name>/` (the
   solution folder is nested under `-o`), and the prefix's casing names the projects and namespaces
   (`--prefix zava` → `zava.Plugins`). The prefix cannot be
   `Vela`. **Don't invent a prefix - use the target Dataverse solution's own publisher
   customization prefix** (see `references/registration-rules.md`); it must match, otherwise
   `vela apply --solution` rejects
   the unique names later. The target solution + publisher must already exist in the org (Vela
   does not create them). Prefix unknown and no org to read it from? Follow `vela-plan-review`
   (ask once, or a flagged assumption that blocks the apply gate). This emits **6 projects** under `src/` + `tests/`: `<Prefix>.Shared`,
   `<Prefix>.Plugins`, `<Prefix>.Integrations`, `<Prefix>.Plugins.Tests`,
   `<Prefix>.Integrations.Tests`, `<Prefix>.ConsoleApp` (trim with `--no-console` /
   `--no-integrations` / `--no-tests`). **Generated models live in
   `<Prefix>.Shared/Models/Generated`** - that is the `--out` (or `--project`) target for `vela models`,
   not the Plugins project.
3. **Decide reuse vs new first** (see `references/registration-rules.md`):
   - **New plugin, no class exists yet** → `vela add plugin` via the CLI, then code. **Never
     hand-create the plugin class.**
   - **Another behaviour on a table that already has a plugin** → prefer `vela add step` on the
     existing plugin (coherent registration) unless the concern is genuinely separate.
   - **Reuse** an existing plugin/step/service when the behaviour is already there - don't duplicate (DRY).
4. **Existing project?** Find the `.csproj` first, then add the component:
   - Plugin: `vela add plugin <Name> --entity <ModelType> [--message Create|Update|...] [--filtering-attributes A,B]`
     (pass the **model property** names - `Name`, not the logical name `name`, which generates `e => e.name`)
   - Extra step on a plugin: `vela add step <PluginName> --entity <ModelType> --message <Msg>`
   - Custom API: `vela add customapi <Name> [--entity <E>] [--function|--action] [--prefix <pub>]`
     (`--prefix` is accepted though `vela add --help` does not list it)
     (omit `--entity` for a global API; the unique name is `<prefix>_<Name>`) - design it with
     `vela-custom-api` first
   - Test: `vela add test <Name> --kind plugin|customapi` (must be inside a `.Tests` project)
5. **Align the scaffolded registration with the Canvas.** `vela add plugin` / `add step` always
   generate **`PostOperation` + `Sync`** (there is no stage flag). When the Canvas says PreOperation
   (the default for a column of the same record - `references/registration-rules.md`), change both
   the chain and the handler's context type - this is the expected edit of your scaffolded file:
   `.PostOperation()` → `.PreOperation()` and `I<Message>PostContext<E>` → `I<Message>PreContext<E>`.
   Then **verify the generated `FilterOn`** (it may be wrong yet compile):
   - `vela add step` emits a `FilterOn(e => e.Id /* TODO */)` placeholder that **fails the build with
     VELA001** ("'Id' is not a Dataverse column") - replace it with the column that gates the step.
   - `vela add plugin` may echo the casing you passed (`--filtering-attributes name` -> `e => e.name`,
     won't compile), OR **auto-pick a column** (marked `/* auto-selected */`, e.g. `--entity Incident`
     -> `e => e.caseage`) that compiles fine and, on Create, is runtime-ignored so nothing errors.
   Replace it with the intended column (`e => e.Name`): confirm it is the right filtering attribute,
   not merely that it builds.
   - After `vela add step` the plugin is **multi-step**: its new handler is `Handle<Message>`, and its
     harness tests must now state the trigger (`.OnCreate()` / `.OnUpdate()`, see `references/harness-api.md`).
6. **Real project: no demos in what you ship.**
   - **Integrations project - keep it only for outbound flows.** It is where plugins that call
     another system (HTTP API, queue, Azure...) live, and it builds its own package. The Canvas
     decides (`vela-plan-review`, "Structure - outbound integration?"): **no outbound flow detected →
     `--no-integrations`**; an outbound flow → keep it, remove its demos, and preview both packages.
     `--no-console` unless the Canvas needs the console app.
   - Then delete the demos `vela init` adds (verified list, 0.19.6) and their tests:
     `<Prefix>.Plugins/Account/{CustomApis/AccountEstimateValueCustomApi, Plugins/AccountMessageReference,
     Plugins/AccountPostCreatePlugin, Plugins/AccountRelatedContactsPlugin, Services/AccountFollowUpService}`,
     `<Prefix>.Plugins/Contact/{CustomApis/ContactValidateCustomApi, Plugins/ContactRouterPlugin,
     Services/ContactDuplicateService}`, `<Prefix>.Plugins/GlobalCustomApis/PingCustomApi`,
     `<Prefix>.Shared/Services/{GreetingService, IGreetingService}`, the matching files under
     `tests/<Prefix>.Plugins.Tests/` (including `Security/SecurityExampleTests`), and - if kept - the
     Integrations demos (`AccountReconcileCustomApi`, `AccountSyncRouterPlugin`, `ContactExportCustomApi`,
     `ContactSyncPlugin`, `IntegrationHeartbeatCustomApi`) and their tests. Delete demo models your code does not use (e.g. `Contact.cs`) once `vela models` has generated the
     ones it does; with no org, keep the demo *models* until
     `vela models` regenerates them if your code uses them.
   - Demos never count as "a table that already has a plugin" for the reuse rule.
7. **Build** to prove it compiles: `dotnet build`. Report the exact output.
   Line endings: scaffolded files are mostly **CRLF** (some `vela add` output mixes in LF lines;
   `vela models` writes LF). Keep each file's existing endings when you edit it (or configure your
   editor/git), or every edited file shows up as a whole-file diff in review.
8. Summarise what was generated and the next skill in the loop.

## Rationalizations (excuse → rebuttal)

- "I'll just edit the generated file to make it compile." → If *generated* code (models,
  compiler output) doesn't compile, that's a bug to report, not to patch. Re-run the command with
  correct inputs. (Adjusting the *scaffolded* plugin's stage or `FilterOn` is not that - it is expected.)
- "The scaffold said PostOperation, so PostOperation it is." → The scaffold has no stage flag; the
  Canvas decides the stage. Change the chain and the context type.
- "I'll create the plugin file by hand, it's just a class." → A typed message touches
  several files that must stay in sync (see gotchas). Use `vela add`.
- "`--message` doesn't matter, I'll set it in code." → It drives the registration and the
  filtering-attribute requirement. Pass it.

## Red flags

- You are about to hand-edit a generated file (`Models/Generated`, compiler output).
- The Canvas says PreOperation but the scaffolded step still says `.PostOperation()`.
- The scaffold's demo plugins / Custom APIs are still in a project headed for `vela apply`.
- Prefix is `Vela` (rejected) or a committed file is named `*.generated.cs` (often gitignored).
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
- The component is present where the CLI reported it; its only edits are the ones step 5 calls for
  (stage/context type, `FilterOn`) - the logic comes later, in `vela-plugin-authoring`.
