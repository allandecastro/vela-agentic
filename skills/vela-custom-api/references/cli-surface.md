<!-- GENERATED copy of references/cli-surface.md by scripts/sync-copilot.mjs. Edit the source file, not this copy. -->

# Vela CLI surface (reference)

Exact commands and flags, for skills to point at. Always reconfirm against the CLI; this is a
snapshot, the CLI is the contract. Only `vela add --help` and `vela models --help` are
command-specific; `vela <other> --help` prints the global usage page, which lists every command's
flags. `-p` is accepted as the short form of `--package` (not shown in the help).

**Verified against:** `vela 0.21.4` (CLI; flags re-diffed from 0.21.0) · `Vela.Plugins` / `Vela.Testing` `0.29.11` (scaffold default), `0.29.1`, and `0.29.3` exercised by the gotcha evals (framework
resolved by `vela init`). Skills declare this floor in their `compatibility` frontmatter; when the CLI
moves, re-run the `--help` of each command below, update this file, then bump the floor.

## Scaffolding - local only, no Dataverse

### `vela init <Name>` (alias `vela new`)
Scaffold a solution on disk, into `<output>/<Name>/` (nested). The prefix's casing names the
projects and namespaces (`--prefix zava` → `zava.Plugins`). Adds demo plugins, Custom APIs and tests
- remove them for a real project.
- `--name <Name>` (or first positional, required) · `--prefix <pub>` (default derived; `Vela` rejected)
- `--output`/`-o <dir>` (default `.`) · `--core-version <v>` (default resolves latest `Vela.Plugins`)
- `--no-console` · `--no-integrations` · `--no-tests` (all three included by default)
- `--web-resources` (+ `--web-resources-namespace`, `--web-resources-folder` default `dist`) - preview
- `--managed-identity`/`--mi` · `--force` · `--json` · `--interactive` (guided wizard - needs a TTY,
  never use it from an agent)

### `vela add <kind> <Name>`
Kinds: `plugin | customapi | service | test | step | form-script | ribbon-script`. Generates a single
file into an existing project, inferring namespaces from its `RootNamespace`. (`vela add --interactive`
is a TTY wizard - not for agents.)
- `add plugin <Name> --entity <ModelType> [--message Create|Update|Delete|...] [--stage <PreValidation|PreOperation|PostOperation>] [--mode <Sync|Async>] [--filtering-attributes a,b] [--project <csproj>] [--force]`
  - `--stage` / `--mode` (0.21.4+) generate the matching chain and context type; pass them from the Canvas.
  - Generates a **single-step** plugin whose handler is `OnExecute`.
  - `--message` default `Create`; Create/Update/*Multiple require a filtering attribute (auto-picked if
    omitted, with an `/* auto-selected */` comment - check it).
- `add step <PluginName> --entity <ModelType> [--message ...] [--handler <Method>] [--stage ...] [--mode ...] [--filtering-attributes a,b] [--project <csproj>]` -
  edits an existing plugin, adding a second `RegisterStep()` + a handler method (default name
  `Handle<Message>`, e.g. `HandleUpdate`). The plugin becomes **multi-step**. Pass `--filtering-attributes`
  (0.21.4+) so the new step's `FilterOn` is the gating column.
- **`vela add` exit code (0.21.4):** outside a project folder without `--project` it prints "No .csproj found" and
  still exits `0` - pass `--project` and check the "Created"/"Added" line.
- `add customapi <Name> [--entity <ModelType>] [--bound|--global] [--function|--action] [--prefix <pub>] [--project <csproj>] [--force]` -
  default `--action`; omit `--entity` for a global (unbound) API. The unique name is `<prefix>_<Name>`,
  prefix taken from the project unless `--prefix` is passed (accepted, though not listed in `--help`).
- `add service <Name> --entity <ModelType> [--project <csproj>] [--force]` - table-scoped interface + implementation.
- `add test <Name> [--kind plugin|customapi] [--entity <ModelType>] [--project <csproj>] [--force]` - run
  inside the test project (RootNamespace ending in `.Tests`); `<Name>` is the class under test.
- `add form-script <entity>` / `add ribbon-script <entity>` [`--project <web-resources dir>`] - TS web
  resources (preview; **not covered by this pack yet**).

## `vela models` - connects to Dataverse (reads metadata)
Scope is REQUIRED (combinable): `--solution <name>` · `--entities a,b` · `--custom-apis [a,b]` (no value =
every Custom API; add `--package <nupkg>`/`--packages-dir` to exclude the ones you authored) ·
`--messages [a,b]` (no value = all consumable messages) · `--roles <a,b>` · `--solution-roles`.
- C# (default): `--lang csharp`, namespace default `<prefix>.Shared.Models.Generated`, `--namespace`,
  `--no-annotations`, `--overwrite`, `--out <dir>` (default: current dir; documented) or `--project <csproj>`
  (accepted by the parser, not listed in `--help`).
- TypeScript (preview): `--forms` and/or `--tables` (emit an `index.ts` barrel).
- `--verify` - no write; reports drift, **exit 5** on drift. Cannot combine with `--forms`/`--tables`.
- Outside a project, pass `--namespace <ns>` (or run it inside the scaffold, where it is inferred):
  without it `vela models` prints "Could not infer a namespace" and generates nothing (exit `2` since
  0.21.0; 0.19.x exited `0`). Check the "Generated N file(s)" line as well as the exit code.
- `--timeout <1-60 min, default 10>` · `--json` (report of generated files, for agents) · `-v`.

## Package - `vela sign`
`vela sign --package <path.nupkg> (--fingerprint <hex> | (--pfx <file> | --pfx-base64 <content>) (--pfx-password <pw> | --pfx-credential <target>)) [--timestamp <url>] [--json]`
- Signs the built plugin package **before** `plan`/`apply`, so the previewed package is the applied one.
- Prefer `--fingerprint` (cert store) or `--pfx-credential` (credential store) over `--pfx-password`,
  which puts the secret in shell history and logs.

## Deploy - `plan` (safe) vs `apply` (writes) vs `inspect` (read)
Shared inputs: `--package`/`-p <.nupkg>` (repeatable) or `--packages-dir <folder>` · `--package-assembly <name.dll>` ·
`--webresources <folder>` (preview) · connection options (below) · `--timeout` · `--environment <label>` ·
`--out <file>` · `--strict` (fail on any diagnostic) · `--json` · `--verbose`.
- `vela plan` - preview only, never writes. Run it on the exact package you will apply.
- `vela apply` - writes; adds `--solution <uniquename>` (apply-only) and `--auto-approve`/`--yes`. On a
  TTY prints the plan and requires a typed `yes`; non-interactive refuses unless `--auto-approve`.
  **Do not auto-approve unless explicitly told to.**
- `vela inspect` - compare local packages vs the live environment (read-only).
- **`plan.json` (from `--out`, verified 0.19.6):** `{mode, environment, hasChanges, summary: {added,
  removed, changed}, operations: [{action: create|update|delete, kind: step|image|custom-api|...,
  type, reason}], diff, diagnostics: [string], notes}`. On a first deploy the new assembly is not an
  operation - it appears as the diagnostic below - so `operations` lists the steps / Custom APIs. Read `operations` (what apply would do) and
  every `diagnostics` line. "Plugin assembly '<x>' not found in Dataverse" on a first deploy is
  expected; a rank collision with a Microsoft managed step (e.g. `ActivityFeeds.*`) is not a finding.
- **`vela apply --json` (verified on a dev org, 0.21.0):** same shape as `plan.json` with `mode:
  "apply-execute"`. **`summary` is the diff remaining *after* execution** (e.g. `added: 0` after a
  successful create) - what was done is in `notes`: "Dataverse changes were executed.", "Executed
  operations: create=N, update=N, delete=N". Report from `notes` + the exit code, never from `summary`.
- **`vela inspect --json`:** `{mode, environment, local, current: {assemblies, steps: [...]}, diagnostics}`
  - compare `current` with the package; an empty `diagnostics` after an apply means they match.
- **Output format:** a styled summary on a terminal, **JSON when piped/redirected** (an agent's shell is
  usually piped - expect JSON). Force it with `--json`, or write it with `--out <file>`.
  `NO_COLOR` / `VELA_NO_COLOR` disable colors.

## Auth / connection (on models/plan/apply/inspect)
Resolution order:
1. `--connection-string` or env `DATAVERSE_CONNECTION_STRING`.
2. Client secret: `--url` + `--tenant-id` + `--client-id` + (`--client-secret-stdin` | env
   `DATAVERSE_CLIENT_SECRET` | `--client-secret <value>` - warned, leaks into history; avoid).
3. `--interactive`/`-i` - browser login; token cached under `~/.vela` (silent on repeat). `--fresh-login`
   forces re-prompt. `vela logout` clears it. Needs a browser - not for headless runs.
4. `--url` alone → `DefaultAzureCredential` (env / managed identity / `az login`) - verified: an `az login`
   session is enough for `vela models` and `vela plan`.
- `--timeout <1-60>` connection timeout. `--authority` / `--auth-client-id` for sovereign clouds.

## Exit codes
`0` success · `2` invalid arguments · `3` file not found · `4` parse/read error · `5` drift
(`models --verify`) · `6` Dataverse connection failure.

## Other
`vela version` (or `--version`) → `vela <version>`; run it first. `vela update [--version <x.y.z>]`
updates the global tool. `vela menu` (default with no args) is an interactive TTY menu - not for agents.
