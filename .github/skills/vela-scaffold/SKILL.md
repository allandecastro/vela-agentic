---
name: vela-scaffold
description: Use when a new Vela solution is needed, or a component (plugin, custom API, service, step, test) must be added to an existing project.
compatibility: "vela CLI + dotnet SDK."
---

# Scaffold Vela projects and components

> Paths like `references/<file>.md` in this skill are relative to **this skill's folder** (the
> directory containing this `SKILL.md`), not to the project you are working in.

Drive `vela init` and `vela add` (**local only**, never connect to Dataverse).

Two kinds of files:
- **Generated** - `Models/Generated/*` and compiler output. Never hand-edit; regenerate.
- **Scaffolded** - what `vela add` writes once. **Yours**: you implement it and adjust its registration
  (stage, `FilterOn`, images) to the Canvas. It must compile as generated, not stay untouched.

## When to use

- Start a new Vela solution.
- Add a plugin, step, custom API, service, or test to an existing Vela project.

## Process

Announce: `Using vela-scaffold to <purpose>`. Exact flags: `vela init --help` / `vela add --help`
(`references/cli-surface.md`).

1. `vela version`.
2. **The solution and its publisher prefix:** an existing project → `PROJECT.md` (front matter
   `publisherPrefix`, `packages:` → solution). A new one → the unique name from the story or the human
   (`vela-grill`), the prefix from `vela solution show <uniquename> --json <connection>` (read-only) - never guessed. Exit `4` = no such solution (Vela does not create it): an open
   question that blocks the apply gate. Unknown and no org (exit `6`, or none reachable): record the command +
   exit code, scaffold with the obvious placeholder `--publisher-prefix tbd`, list it as an open question;
   apply stays blocked until it is confirmed.
3. **New solution?** `vela init <Name> --prefix <Prefix> --publisher-prefix <publisherPrefix> --solution <uniquename> -o <dir>` -
   lands in `<dir>/<Name>/`, minimal (Shared, Plugins, Plugins.Tests; no demos, no models), with `PROJECT.md` (the
   prefix and the package → solution map; Vela never rewrites it), `ProjectServices.cs`, `Messages.cs`, `.editorconfig`.
   - `--prefix` = namespace/assembly prefix, used verbatim: pass it **PascalCase** (`zava` →
     `zava.Plugins`). `--publisher-prefix` = the Dataverse prefix from step 2 (read it from `PROJECT.md` and
     pass it to `vela add customapi --prefix`; `references/registration-rules.md`).
   - `--integrations` when the Canvas records an outbound call: an empty Integrations project with its
     own package - outbound code goes there. **Never `--samples`** (demos + ConsoleApp) and **never
     `--no-tests`** (tests are the acceptance criteria).
   - The scaffold's `AGENTS.md` is context; **this pack governs** (no `vela models --interactive`, no
     `plan --packages-dir artifacts`, stop before `apply`).
4. **Generate the models before the first plugin** (`vela-models`): without them a plugin on `Account`
   fails with `CS0234` ("... 'Shared' does not exist") / `CS0118`.
   `vela models --entities <tables> --project src/<Prefix>.Shared/<Prefix>.Shared.csproj <connection>`.
5. **Reuse vs new first** (`references/registration-rules.md`):
   - New plugin → `vela add plugin`, then code. **Never hand-create the plugin class.**
   - Another behaviour on a table that already has a plugin → prefer `vela add step` on it, unless the
     concern is genuinely separate.
   - Behaviour already there → reuse, don't duplicate.
6. **Add the component** - always `--project <path>.csproj` (else "No .csproj found", exit `2`); read
   the "Created"/"Added" line (or `--json`'s `created`):
   - `vela add plugin <Entity>Plugin --entity <ModelType> --message <Msg> --stage <Stage> --mode <Sync|Async> --filtering-attributes <A,B> --handler <OnBehaviour> --project src/<Prefix>.Plugins/<Prefix>.Plugins.csproj`
     (outbound: the Integrations csproj). Create/Update(+Multiple) without a filter exits `2`.
   - `vela add step <PluginName> ...` (same options, `--handler` named after the behaviour); `vela add customapi <Name> --prefix <publisherPrefix> ...` (design it with
     `vela-custom-api` first); `vela add test <PluginName> --kind plugin|customapi --project tests/<Prefix>.Plugins.Tests/<Prefix>.Plugins.Tests.csproj`
     (stubs `vela-test-harness` fills).
7. **Pass the registration the Canvas decided** (`--stage`, `--mode`, `--filtering-attributes`; the
   defaults are Create / PostOperation / Sync), then **read the generated chain** against the Canvas:
   stage, mode and `FilterOn` must be what you asked for.
   - After `vela add step` the plugin is **multi-step**: its tests run through `PluginPipeline`; an existing
     `PluginContext` test on the same trigger moves there (`vela-test-harness`, `change: tests`).
8. **Build:** `dotnet build <Name>.sln -c Release`; report the output. `CS1061` on a `FilterOn` column →
   regenerate the model (`vela-models`), never hand-edit it.
9. Summarise what was generated and the next skill in the loop.

## Rationalizations (excuse → rebuttal)

- "I'll just edit the generated file to make it compile." → Generated code that doesn't compile is a bug
  to report; re-run with correct inputs. (Adjusting the *scaffolded* plugin's stage or `FilterOn` is
  expected.)
- "I'll let `vela add` pick the stage." → Its default is PostOperation + Sync; the Canvas decides.
- "The prefix is probably the solution name lower-cased." → `vela solution show` reads it; a guess
  breaks the Custom API unique names at apply.
- "I'll create the plugin file by hand, it's just a class." → A typed message touches several files that
  must stay in sync. Use `vela add`.
- "`--message` doesn't matter, I'll set it in code." → It drives the registration. Pass it.

## Red flags

- Hand-editing a generated file (`Models/Generated`, compiler output).
- The Canvas says PreOperation but the scaffolded step still says `.PostOperation()`.
- `vela init --samples` for a project headed for `vela apply`, or outbound code outside the
  `--integrations` project.
- A lower-case `--prefix`, or a `--publisher-prefix` not confirmed with `vela solution show` (other than a recorded `tbd`).
- A guessed flag instead of `--help`; `--interactive` on `vela init`/`vela add` (a TTY wizard).
- A generated `FilterOn` accepted unchecked: a column the Canvas did not choose ships a wrong registration.
- Following the scaffold's `AGENTS.md` where it contradicts the pack.
- **Build fails right after `vela models`** in generated code (an incompatible auto-resolved framework):
  stop and report the regression with the version - a gap for the Vela owner, not worked around.

## Verification

- `dotnet build` succeeds - paste the output.
- `vela solution show` output (or command + exit code when unavailable) recorded in the Canvas.
- The component is where the CLI reported it, edited only per step 7 (logic: `vela-plugin-authoring`).
