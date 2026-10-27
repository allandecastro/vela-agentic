# Vela CLI surface (reference)

The commands the loop needs and the traps `--help` does not show. A snapshot - the CLI is the contract:
confirm every flag with `vela <command> --help`, or `vela help --json` (every command, option, alias and
exit code as one JSON document).

**Verified against:** `vela 0.28.0` (CLI; flags re-diffed from `vela help --json`) · `Vela.Plugins` /
`Vela.Testing` `0.41.1` (scaffold default, resolved by `vela init`) · the CLI targets .NET 10: the .NET 10 SDK
(also what `dotnet run tools/spec-check.cs` needs). This is the pack's only version
record: when the CLI moves, re-run `vela help --json` and update this file.

## Scaffolding - local only, no Dataverse

### `vela init <Name>` (alias `vela new`)
`vela init <Name> --output <dir> --prefix <Prefix> --publisher-prefix <pfx> [--integrations]`
- Lands in `<dir>/<Name>/` (nested). **Minimal by default**: empty `<Prefix>.Shared` (models + shared
  services, `net48;net10.0`), `<Prefix>.Plugins` (`net48`, builds the plugin package into `artifacts/`),
  `tests/<Prefix>.Plugins.Tests`, plus `AGENTS.md`, `README.md`, `.vela/scaffold-manifest.json`. No models.
- `--prefix` is the **namespace / assembly prefix**, used verbatim (`zava` → `zava.Plugins`): pass it
  PascalCase. Omitted → the solution name.
- `--publisher-prefix` is the **Dataverse publisher prefix** (2-8 chars), recorded as `<VelaPublisherPrefix>`
  and used by `vela add customapi` for `<prefix>_<Name>`. Omitted → Custom APIs fall back to the
  lower-cased `--prefix`.
- `--integrations` adds an **empty** Integrations plugin project (`src/<Prefix>.Integrations`, references
  `System.Net.Http`) + its tests, building its own package - the home for outbound calls.
  `--managed-identity`/`--mi` adds package signing and implies it.
- `--samples` adds demos - never for real work. `--force` regenerates only files Vela wrote and you did not
  edit (tracked in `.vela/scaffold-manifest.json` - commit it). `--interactive` needs a TTY - never from an agent.

### `vela add <kind> <Name>`
Kinds: `plugin | customapi | service | test | step | form-script | ribbon-script`; one file into an existing
project, namespaces from its `RootNamespace`. **Always pass `--project <csproj>`** (else "No .csproj found",
exit `2`) and check the "Created"/"Added" line (or `created` in `--json`).
- `add plugin <Name> --entity <ModelType> --message <M> --stage <S> --mode <Sync|Async> --filtering-attributes a,b`
  - a **single-step** plugin, handler `OnExecute`. Defaults are Create / PostOperation / Sync - pass the
  Canvas values. Create/Update(+Multiple) **require** `--filtering-attributes` (else exit `2`); logical names
  map to model properties.
- `add step <PluginName> --entity ... [--handler <Method>] ...` - adds a second `RegisterStep()` + handler
  (default `Handle<Message>`); the plugin becomes **multi-step**. Same filter rule.
- `add customapi <Name> [--entity <ModelType>] [--function|--action]` - default action; no `--entity` = global.
- `add service <Name> --entity <ModelType>` - table-scoped interface + implementation (`<Table>/Services/`);
  without `--entity`, a shared one in `Services/` (logic used by several tables).
- `add test <PluginName> [--kind plugin|customapi] [--entity ...] [--message ...]` - run in the test project;
  on an existing test class it **adds the tests of the steps it lacks** (`--force` overwrites).
- `form-script` / `ribbon-script` - TS web resources (preview; **not covered by this pack yet**).

## `vela models` - connects to Dataverse (reads metadata)
- Scope is REQUIRED: `--solution <name>` and/or `--entities a,b` (also `--custom-apis`, `--messages`, `--roles`,
  `--intersect` - see `--help`). Bare `--custom-apis` takes every Custom API: add `--package <nupkg>` to
  exclude the ones you authored.
- C#: **`--project src/<Prefix>.Shared/<Prefix>.Shared.csproj`** (its namespace, `Models/Generated`). Without
  `--project` or `--namespace` nothing is generated ("Could not infer a namespace", exit `2`) - check the
  "Generated N file(s)" line as well as the exit code.
- Offline: `--from-solution <solution.zip> --namespace <ns>` (only what the zip contains).
- `--verify` - no write; **exit 5** on drift.

## Read-only org commands - `vela solution`, `vela logs`
- **`vela solution show <uniquename> --json <connection>`** → `{"solution","publisherPrefix"}`, exit `0`;
  missing solution → exit `4`. Confirms the target solution exists and `--publisher-prefix` matches.
- **`vela logs` (alias `vela trace`) `<connection>`** - plug-in trace rows (newest first), or failed system
  jobs with `--jobs`. Filters (`--errors`, `--since`, `--type`, `--correlation`, `--full`, `--json`...) in
  `--help`. Trace rows exist only when the org's plug-in trace log setting is on.

## Package - `vela sign`
Sign the built package **before** `plan`/`apply`, so the previewed package is the applied one. Pass secrets
via `--fingerprint`, `--pfx-credential` or the `*-env` forms - never `--pfx-password`/`--pfx-base64` on the
command line.

## Deploy - `plan` (safe) vs `apply` (writes) vs `inspect` (read)
`vela plan --package artifacts/<P>.Plugins.<ver>.nupkg --solution <uniquename> <connection>` (or
`--packages-dir`; `--strict`, `--detailed-exitcode` in `--help`).
- **`--solution` is required on `plan` and `apply`** (resolves the publisher prefix; `apply` adds every
  component to it). Without it: exit `4`, "... has no solution publisher prefix ... Re-run with --solution".
  The solution + publisher must already exist.
- `--secure-config <NAME=@file>` (one trailing line ending is dropped) or env `VELA_SECURE_CONFIG_<NAME>` - never
  `NAME=VALUE` on a command line.
- `vela plan` never writes; run it on the exact package you will apply.
- `vela apply` writes. On a TTY it requires a typed `yes`; non-interactive refuses unless `--auto-approve`.
  **Do not auto-approve unless explicitly told to.** Operations are idempotent upserts: a partial apply
  (exit `7`) is fixed then re-run.
- `vela inspect` - local packages vs the live environment (read-only).
- **Output:** JSON when piped (an agent's shell usually is), or force `--json` / `--out <file>`; notices on stderr.
- **`plan` JSON:** `{schemaVersion, mode, environment, hasChanges, summary: {added, removed, changed},
  operations: [{action, kind, type, reason}], diff: {localAssemblies, currentAssemblies, ...}, diagnostics,
  notes, unmanaged, info}`. Read `operations` and every `diagnostics` line; don't parse `notes`.
  - A **`package` operation** creates/republishes the package; after a recompile with no definition change,
    the registration diff is empty yet `hasChanges` is true. `summary` counts registrations, not the package.
  - Each step's `definition` carries its `relationships` (`ForRelationship` scope): check it matches the Canvas.
  - First deploy: `currentAssemblies` is `[]` and `info` says "... not found in Dataverse (first deployment)" -
    expected. A package with no plugin and no Custom API is not created (`info` says so) - expected.
  - A rank collision with a Microsoft managed step (e.g. `ActivityFeeds.*`) is not a finding about your code.
- **`apply` JSON:** the plan shape plus **`executed`** (`created`, `updated`, `deleted`, `packageRepublished`,
  `addedToSolution`, `byKind`). `summary` is the diff remaining *after* the apply: report from `executed` +
  the exit code, never from `summary`.
- **`inspect --json`:** `{mode, environment, local, current: {assemblies, steps}, diagnostics}` - empty
  `diagnostics` after an apply means they match.

## Auth / connection (on models/plan/apply/inspect/solution/logs)
Resolution order:
1. `--connection-string` or env `DATAVERSE_CONNECTION_STRING`.
2. `--url` + `--tenant-id` + `--client-id` + (`--client-secret-stdin` | env `DATAVERSE_CLIENT_SECRET`);
   avoid `--client-secret <value>` (leaks into history).
3. `--interactive`/`-i` - browser login, token cached under `~/.vela`; needs a browser, not headless.
   `vela logout` clears it.
4. `--url` alone → ambient Azure credential (`az login` / managed identity) - headless.

## Exit codes
`0` success · `2` invalid arguments · `3` file not found · `4` error (incl. `--strict`, a missing
`--solution`, a missing solution on `solution show`) · `5` drift (`models --verify`) or apply not converged ·
`6` Dataverse connection failure (any network error on any Dataverse call; `models` stops rather than
skipping) · `7` partial apply (fix, re-run `apply`) · `8` changes pending (`plan --detailed-exitcode` only).

## Other
Run `vela version` first; `vela update` updates the tool. `vela menu` (default with no arguments) is an
interactive TTY menu - not for agents.
