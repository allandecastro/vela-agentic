# Vela CLI surface (reference)

Exact commands and flags, for skills to point at. Always reconfirm with
`vela <command> --help`; this is a snapshot, the CLI is the contract.

## Scaffolding — local only, no Dataverse

### `vela init <Name>` (alias `vela new`)
Scaffold a solution on disk.
- `--name <Name>` (or first positional, required) · `--prefix <pub>` (default derived; `Vela` rejected)
- `--output`/`-o <dir>` (default `.`) · `--core-version <v>` (default resolves latest `Vela.Plugins`)
- `--no-console` · `--no-integrations` · `--no-tests` (all three included by default)
- `--web-resources` (+ `--web-resources-namespace`, `--web-resources-folder` default `dist`)
- `--managed-identity`/`--mi` · `--force` · `--json`

### `vela add <kind> <Name>`
Kinds: `plugin | customapi | service | test | step | form-script | ribbon-script`.
- `add plugin <Name> --entity <ModelType> [--message Create|Update|Delete|...] [--filtering-attributes a,b] [--project <csproj>] [--force]`
  - `--message` default `Create`; Create/Update/*Multiple require a filtering attribute (auto-picked if omitted).
- `add step <PluginName> --entity <ModelType> [--message ...] [--handler <Method>]` — edits an existing plugin; `--handler` default `Handle<Message>`.
- `add customapi <Name> [--entity] [--bound|--global] [--function|--action] [--prefix <pub>]` — default `--action`.
- `add service <Name> --entity <ModelType>`
- `add test <Name> [--kind plugin|customapi] [--entity]` — must run inside a `.Tests` project.
- `add form-script <entity>` / `add ribbon-script <entity>` [`--project <web-resources dir>`] — TS web resources (preview).

## `vela models` — connects to Dataverse (reads metadata)
Scope is REQUIRED (one of): `--solution <name>` · `--entities a,b` · `--custom-apis[=all]` · `--messages[=all]` · `--roles` · `--solution-roles`.
- C# (default): `--lang csharp`, writes to `<project>/Models/Generated`, `--namespace` inferred, `--no-annotations`, `--overwrite`.
- TypeScript: `--forms` and/or `--tables` (default `--lang ts`), emit an `index.ts` barrel.
- `--verify` — no write; reports drift, **exit 5** on drift. Cannot combine with `--forms`/`--tables`.
- `--out <dir>` · `--project <csproj>` · `--timeout <1-60 min, default 10>` · `--json` · `-v`.

## Deploy — `plan` (safe) vs `apply` (writes)
Shared inputs: `--package`/`-p <.nupkg>` (repeatable, required unless `--webresources`), `--packages-dir`, `--solution <uniquename>`, `--environment <label>`, connection options (below), `--strict` (fail on any diagnostic), `--json`, `-v`.
- `vela plan` — preview only, never writes. Run this before every apply.
- `vela apply` — writes. On a TTY prints the plan and requires a typed `yes`; non-interactive refuses unless `--auto-approve`/`--yes`. **Do not auto-approve unless explicitly told to.**
- `vela inspect` — compare local packages vs live environment.

## Auth / connection (on models/plan/apply/inspect)
Resolution order:
1. `--connection-string` or env `DATAVERSE_CONNECTION_STRING`.
2. Client secret: `--url` + `--tenant-id` + `--client-id` + (`--client-secret` | `--client-secret-stdin` | env `DATAVERSE_CLIENT_SECRET`).
3. `--interactive`/`-i` — browser login; token cached under `~/.vela` (silent on repeat). `--fresh-login` forces re-prompt. `vela logout` clears it.
4. `--url` alone → `DefaultAzureCredential` (env / managed identity / `az login`).
- `--timeout <1-60>` connection timeout. `--authority` / `--auth-client-id` for sovereign clouds.

## Version
`vela version` or `vela --version` → `vela <version>`. Run it first; skills assume the
current release line (CLI 0.15.2 / framework `Vela.Plugins` 0.26.2 or newer).
