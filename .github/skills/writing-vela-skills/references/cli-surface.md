<!-- GENERATED copy of references/cli-surface.md by scripts/sync-copilot.mjs. Edit the source file, not this copy. -->

# Vela CLI surface (reference)

Exact commands and flags, for skills to point at. Always reconfirm against the CLI; this is a
snapshot, the CLI is the contract. Every command has its own `vela <command> --help` (or
`vela help <command>`); `vela help --json` prints every command, option, alias and exit code as one
JSON document (`schemaVersion: 1`) - the machine-readable source to check a flag against.

**Verified against:** `vela 0.26.2` (CLI; flags re-diffed from `vela help --json`) · `Vela.Plugins` /
`Vela.Testing` `0.37.0` (scaffold default, resolved by `vela init`). Skills declare this floor in their
`compatibility` frontmatter; when the CLI moves, re-run `vela help --json`, update this file, then bump
the floor.

## Scaffolding - local only, no Dataverse

### `vela init <Name>` (alias `vela new`)
Scaffold a solution on disk, into `<output>/<Name>/` (nested). **Minimal by default**: three empty
projects - `<Prefix>.Shared` (models + shared services, `net48;net10.0`), `<Prefix>.Plugins` (`net48`,
builds the plugin package into `artifacts/`) and `tests/<Prefix>.Plugins.Tests` - plus an `AGENTS.md`,
a `README.md` and `.vela/scaffold-manifest.json`. No demo code, no models, no Integrations/Console project
(unless `--integrations`).
- `--name <Name>` (or first positional, required) · `--output`/`-o <dir>` (parent folder: the solution lands in `<dir>/<SolutionName>`; default `.`)
- `--prefix <Prefix>` - **namespace / assembly prefix**, used verbatim (`--prefix Zava` →
  `Zava.Plugins`; `--prefix zava` → `zava.Plugins`). Pass it PascalCase. Omitted → the solution name.
- `--publisher-prefix <prefix>` - the **Dataverse publisher prefix** (2-8 chars, e.g. `zava`), recorded as
  `<VelaPublisherPrefix>` in the Plugins project and used by `vela add customapi` for `<prefix>_<Name>`.
  Omitted → not recorded (Custom APIs then fall back to the lower-cased `--prefix`).
- `--no-tests` · `--core-version <v>` (default: latest `Vela.Plugins` on nuget.org)
- `--integrations` - add an **empty** Integrations plugin project (`src/<Prefix>.Integrations`, `net48`,
  references `System.Net.Http`) and its tests (`tests/<Prefix>.Integrations.Tests`), no demos. It builds
  its own package (`artifacts/<Prefix>.Integrations.<ver>.nupkg`). The home for outbound calls.
  `--managed-identity`/`--mi` adds the signing step to that package and implies `--integrations`.
- `--samples` - add the demos (sample models, plugins, Custom APIs, services, tests) **and** the
  Integrations + ConsoleApp projects - never for real work. `--no-integrations`, `--no-console` apply
  only with `--samples`. `--minimal`/`--no-demos` is the default (kept as an alias).
- `--web-resources`/`--webresources` (+ `--web-resources-namespace`, `--web-resources-folder`) - preview
- `--force` - regenerate into a non-empty folder; only files Vela wrote and you did not edit are
  overwritten or removed (tracked in `.vela/scaffold-manifest.json` - commit it).
- `--json` → `{solution, root, files, projects, kept, removed}` · `--verbose`/`-v` ·
  `--interactive`/`-i` (guided wizard - needs a TTY, never use it from an agent)

### `vela add <kind> <Name>`
Kinds: `plugin | customapi | service | test | step | form-script | ribbon-script`. Generates a single
file into an existing project, inferring namespaces from its `RootNamespace` (a plugin on `Account`
lands in `Account/Plugins/<Name>.cs`). Each kind accepts only its own options. `--json` →
`{description, created: [paths]}`. (`vela add --interactive` is a TTY wizard - not for agents.)
- `add plugin <Name> --entity <ModelType> [--message Create|Update|Delete|...] [--stage <PreValidation|PreOperation|PostOperation>] [--mode <Sync|Async>] [--filtering-attributes|--filter a,b] [--project <csproj>] [--force]`
  - Generates a **single-step** plugin whose handler is `OnExecute`, with the chain and context type for
    `--stage`/`--mode`. Defaults: `--message Create`, PostOperation, Sync - pass them from the Canvas.
  - Create/Update(+Multiple) **require** `--filtering-attributes`: without it the command exits `2`
    ("A Update step needs a filtering attribute"). Logical names are mapped to the model property
    (`--filter name` generates `FilterOn(e => e.Name)`); model property names work too.
- `add step <PluginName> --entity <ModelType> [--message ...] [--handler <Method>] [--stage ...] [--mode ...] [--filtering-attributes a,b] [--project <csproj>]` -
  edits an existing plugin, adding a second `RegisterStep()` + a handler method (default name
  `Handle<Message>`, e.g. `HandleUpdate`). The plugin becomes **multi-step**. Same filter rule (exit `2`).
- `add customapi <Name> [--entity <ModelType>] [--bound|--global] [--function|--action] [--prefix <publisherprefix>] [--project <csproj>] [--force]` -
  default `--action`; omit `--entity` for a global (unbound) API. Unique name `<prefix>_<Name>`: `--prefix`,
  else the project's `VelaPublisherPrefix`, else the project prefix.
- `add service <Name> --entity <ModelType> [--project <csproj>] [--force]` - table-scoped interface + implementation.
- `add test <PluginName> [--kind plugin|customapi] [--entity <ModelType>] [--message <Message>] [--prefix <publisherprefix>] [--project <csproj>] [--force]` -
  run inside the test project (RootNamespace ending in `.Tests`); `<PluginName>` is the class under test,
  the file is `<PluginName>Tests.cs`. On an existing class it **adds the tests of the steps it lacks**
  (0.26.0; e.g. `Fires_On_Create_PreOperation`); `--force` overwrites instead.
- `add form-script <entity>` / `add ribbon-script <entity>` [`--project <web-resources dir>`] - TS web
  resources (preview; **not covered by this pack yet**).
- **Exit code:** outside a project folder without `--project` it prints "No .csproj found" and exits `2`.
  Always pass `--project <csproj>` and check the "Created"/"Added" line (or `created` in `--json`).

## `vela models` - connects to Dataverse (reads metadata)
Scope is REQUIRED (combinable): `--solution <name>` · `--entities a,b` · `--custom-apis [a,b]` (bare =
every Custom API, with a warning; add `--package`/`-p <nupkg>` (repeatable) or `--packages-dir <folder>`
to exclude the typed Custom APIs you authored, `--package-assembly <name.dll>` when it cannot be inferred) ·
`--messages [a,b]` (bare = all consumable messages) · `--roles <a,b>` · `--solution-roles` ·
`--intersect` (also the N:N intersect tables of the scoped tables).
- C# (default, `--lang csharp`): **`--project <csproj>`** uses that project's namespace and its
  `Models/Generated` folder - pass the Shared project (`--project src/<Prefix>.Shared/<Prefix>.Shared.csproj`).
  Or `--out <dir>` (default: current dir) + `--namespace <ns>`. `--overwrite` · `--no-annotations` (omit
  `[StringLength]`/`[Range]`).
- **Offline:** `--from-solution <solution.zip> --namespace <ns>` - entity models and option sets from an
  exported solution zip; only what the solution contains (no table metadata → exit `2`).
- TypeScript (preview): `--lang ts`, `--forms` and/or `--tables`.
- `--verify` - no write; reports drift, **exit 5** on drift. Cannot combine with `--forms`/`--tables`.
- Outside a project with neither `--project` nor `--namespace`, nothing is generated ("Could not infer a
  namespace", exit `2`). Check the "Generated N file(s)" line as well as the exit code.
- `--timeout <1-60 min, default 10>` · `--json` (report of generated files) · `--verbose`/`-v`.

## Read-only org commands - `vela solution`, `vela logs`
- **`vela solution show <uniquename> [--json] <connection>`** - prints the solution's publisher prefix.
  JSON: `{"solution":"<uniquename>","publisherPrefix":"<pfx>"}`, exit `0`; a solution that does not exist →
  exit `4`. The read-only way to confirm the target solution exists and that `--publisher-prefix` matches.
- **`vela logs` (alias `vela trace`) `<connection>`** - plug-in trace log rows (newest first), or failed system
  jobs with `--jobs` (`--all-statuses` for every status). Filters: `--errors` (rows with an exception) ·
  `--since <30m|2h|3d|date>` · `--type <plugin type substring>` · `--message <m>` · `--entity <logical>` ·
  `--correlation <guid>` · `--top <1-200, default 20>` · `--full` (no truncation) · `--json`
  (`{mode, count, logs}`). Trace rows exist only when the org's plug-in trace log setting is on.

## Package - `vela sign`
`vela sign --package <path.nupkg> (--fingerprint <hex> | (--pfx <file> | --pfx-base64-env <VAR>) (--pfx-password-env <VAR> | --pfx-credential <target>)) [--timestamp <url>] [--json]`
- Signs the built plugin package **before** `plan`/`apply`, so the previewed package is the applied one.
- Prefer `--fingerprint` (cert store), `--pfx-credential` (credential store) or the `*-env` forms over
  `--pfx-password <pw>` / `--pfx-base64 <content>`, which put the secret on the command line (warned).

## Deploy - `plan` (safe) vs `apply` (writes) vs `inspect` (read)
Shared inputs: `--package`/`-p <.nupkg>` (repeatable) or `--packages-dir <folder>` (newest version of each
package id) · `--package-assembly <name.dll>` · **`--solution <uniquename>`** (alias `--solution-unique-name`) ·
`--secure-config <NAME=VALUE|NAME=@file>` (repeatable; or env `VELA_SECURE_CONFIG_<NAME>`; `@file` drops one trailing line ending since 0.26.2 (release note, not re-verified) - prefer it or the env var, never `NAME=VALUE` on a command line) ·
`--webresources <folder>` (preview; requires `--solution`) · connection options (below) · `--environment <label>` ·
`--out <file>` · `--json` · `--verbose`.
- **`--solution` is required on `plan` and `apply`**: it resolves the publisher prefix Dataverse needs to
  import a plugin package, and on `apply` adds every written component to that solution. Without it both
  fail before any write: exit `4`, "Plugin package '<x>' has no solution publisher prefix ... Re-run with
  --solution". The solution + publisher must already exist (Vela does not create them).
- `vela plan` - preview only, never writes. Run it on the exact package you will apply. `--strict` (exit `4`
  on any warning in `diagnostics`; `info` never fails) · `--detailed-exitcode` (exit `8` when there are
  changes to apply, `0` when there is nothing to do).
- `vela apply` - writes; adds `--auto-approve`/`--yes`, `--batch-size <1-1000, default 100>` (ExecuteMultiple
  chunk size) and `--strict`. On a TTY prints the plan and requires a typed `yes`; non-interactive refuses
  unless `--auto-approve`. **Do not auto-approve unless explicitly told to.** Every operation is an
  idempotent upsert, so a partial apply (exit `7`) is fixed then re-run.
- `vela inspect` - local packages vs the live environment (read-only).
- **`plan` JSON (`--out`/`--json`/piped, verified 0.24.1, 0.25.0, 0.26.0):** `{schemaVersion: 1, mode: "plan", environment,
  hasChanges, summary: {added, removed, changed}, operations: [{action: create|update|delete, kind:
  package|step|image|custom-api|..., type, reason}], diff: {localAssemblies, currentAssemblies, added,
  removed, changed, ...}, diagnostics: [string], notes, unmanaged, info: [string]}`. Read `operations` (what
  apply would do) and every `diagnostics` line. A **`package` operation** creates or republishes the plugin
  package - on a first deploy `create package <pfx>_<Package>`; after a recompile that changes no
  definition, the registration diff is empty yet `hasChanges` is true and apply republishes the package.
  `summary` counts the registrations (not the package). Each step's `definition` in the diff carries its
  `relationships` (the `ForRelationship` scope of an Associate/Disassociate step, 0.26.0 - verified): check it
  matches the Canvas. On a first deploy `currentAssemblies` is `[]` and
  `info` says "Plugin assembly '<x>' not found in Dataverse (first deployment)" - expected, not a finding.
  A package with no plugin and no Custom API (e.g. the empty `<P>.Plugins` beside an Integrations-only story)
  is not created: `info` says "Plugin package '<x>' contains no plugin or Custom API; it is not created in
  Dataverse until it does" (0.26.1 - verified).
  A rank collision with a Microsoft managed step (e.g. `ActivityFeeds.*`) in `diagnostics` is not a finding
  about your code. Don't parse the free-text `notes`.
- **`apply` JSON:** the plan shape plus an **`executed`** block - what was done: `created`, `updated`,
  `deleted`, `packageRepublished`, `addedToSolution`, and a `byKind` breakdown. **`summary` is the diff
  remaining *after* the apply** (`added: 0` after a successful create). Report from `executed` + the exit
  code, never from `summary`.
- **`vela inspect --json`:** `{mode, environment, local, current: {assemblies, steps: [...]}, diagnostics}`
  - compare `current` with the package; an empty `diagnostics` after an apply means they match.
- **Output format:** a styled summary on a terminal, **JSON when piped/redirected** (an agent's shell is
  usually piped - expect JSON). Force it with `--json`, or write it with `--out <file>`. Notices and
  `--verbose` detail go to stderr. `NO_COLOR` / `VELA_NO_COLOR` disable colors.

## Auth / connection (on models/plan/apply/inspect/solution/logs)
Resolution order:
1. `--connection-string` or env `DATAVERSE_CONNECTION_STRING`.
2. Client secret: `--url` + `--tenant-id` + `--client-id` + (`--client-secret-stdin` | env
   `DATAVERSE_CLIENT_SECRET` | `--client-secret <value>` - warned, leaks into history; avoid).
3. `--interactive`/`-i` - browser login; token cached under `~/.vela` (silent on repeat). `--fresh-login`
   forces re-prompt. `vela logout` clears the token and the remembered URL. Needs a browser - not for
   headless runs.
4. `--url` alone → ambient Azure credential (`az login` / managed identity) - headless.
- `--timeout <1-60>` connection timeout. `--authority` / `--auth-client-id` for sovereign clouds.

## Exit codes
`0` success · `2` invalid arguments · `3` file not found · `4` error (incl. a `--strict` failure, a missing
`--solution` on plan/apply, a missing solution on `solution show`) · `5` drift (`models --verify`) or apply
not converged (the org still differs after the write) · `6` Dataverse connection failure (since 0.25.1 any network error - DNS, socket, HTTP, timeout - on any
Dataverse call of plan/apply/inspect/models/solution/logs; `models` stops with `6` instead of skipping the entity; verified) · `7` partial apply
(fix the cause, re-run `apply`) · `8` changes pending (`plan --detailed-exitcode` only).

## Other
`vela version` → `vela <version>`; run it first. `vela update [--version <x.y.z>]` updates the global
tool. `vela help [<command>] [--json]`. `vela menu` (the default with no arguments) is an interactive TTY
menu - not for agents.
