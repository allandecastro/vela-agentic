<!-- GENERATED copy of references/dataverse-gotchas.md by scripts/sync-copilot.mjs. Edit the source file, not this copy. -->

# Dataverse & Vela gotchas (battle-tested)

Real failure modes seen in Vela plugins. Skills cite these as Red Flags. Each entry is a
symptom → cause → fix.

## Registration & steps

- **Associate / Disassociate steps not firing.** These messages are not tied to a single
  primary entity; a step matched by primary entity alone silently never runs. Match the
  message regardless of primary entity.
- **Create/Update step never triggers on the change you expect.** A filtering attribute
  excludes the attribute that actually changed. Check the filtering attributes against the
  attribute being written.
- **Create/Update step throws at registration: "must declare at least one filtering attribute".**
  Every Create/Update step requires a `FilterOn(...)`. This throws when the registration is
  materialized (harness `Execute`, `vela plan`/`apply`), NOT at `dotnet build` - so a green build
  is not proof. On Create the filter is ignored at runtime but still mandatory - default it to the
  primary column and never drop it, even when the step should fire on every create. On Update the
  filter actually gates the trigger.
- **Image is empty at runtime.** The image was not registered for that message/stage, or the
  requested attributes were not included. Verify the image registration, not just the code.

## Runtime: recursion, state, sandbox, transactions, secrets

- **Save fails with "Plugin execution stopped to prevent recursion."** Vela's depth guard
  (`PluginBase.MaxDepth`, default **8**) throws `InvalidPluginExecutionException` when `ctx.Depth`
  exceeds it (verified in the harness, 0.28.2) - the user's whole operation fails. Cause: the plugin
  writes something that re-triggers the same step (its `FilterOn` includes the column it writes, or it
  `Update`s its own record in PostOperation), or two plugins trigger each other. Fix the cause: edit
  `ctx.Request.Target` in PreOperation instead of a write-back (that edit is part of the same write
  and re-triggers nothing, so filtering on the column you normalise there is fine); when you must
  write back, keep the written columns out of the step's filtering attributes; write only when the value actually changes (compare with
  `ctx.PreImage`). **Do not** paper over it with `if (ctx.Depth > 1) return;` - that also skips
  legitimate calls made by other plugins, flows or child operations; only use a depth check with a
  reason recorded in the Canvas. The guard is a backstop, not a design.
- **Data leaks between executions / random failures under load.** Plugin instances are cached and
  called concurrently by the sandbox; a writable field is shared across users and requests
  (**VELA011**). Keep per-execution state in locals or the context; never cache org data in a static.
- **Works locally, fails on the org: "sandbox" / security / timeout errors.** Plugins run in an
  isolated sandbox: no file system, registry or local machine APIs; outbound calls over HTTP/HTTPS to
  DNS names only (no raw IP addresses); and a plugin execution is cut off after **2 minutes**. Keep
  Sync steps short; move slow or external work to an Async step or out of the plugin (the scaffold's
  Integrations project).
- **An error in a plugin undoes more (or less) than expected.** Sync PreOperation/PostOperation steps
  run inside the database transaction: throwing rolls back the whole operation, including earlier
  plugin writes. PreValidation runs before the main transaction. Async steps run after the commit:
  their failure does not undo the save (it shows as a failed system job). Side effects on external
  systems are never rolled back - don't make them from a Sync step that may still fail after them.
- **The user sees "An unexpected error occurred" instead of your message.** Only
  `InvalidPluginExecutionException` surfaces its message (**VELA012**). Throw it with a message the
  user can act on; never swallow exceptions; `ctx.Trace(...)` the context you'll need to debug
  (it lands in the Plugin Trace Log).
- **A secret shows up in a solution export or the repo.** Unsecure configuration is exported with the
  solution and readable; code is in git. Never put secrets in either. Use **secure configuration**
  (not exported with the solution, set per environment, readable by admins only) or an external
  secret store reached with a managed identity (see the scaffold's `--managed-identity` option).

- **"Last one" rollups race.** A rule like "when the last active child is deactivated, deactivate
  the parent" can miss when two children are deactivated in parallel: each sees the other still
  active. Record it in the Canvas as an accepted limitation, or use an Async recheck.

## Custom APIs

- **Custom API is uncallable on a real org** despite working locally. Parameter/unique names
  contained a dot. Nothing local rejects it (build, harness and the definition reader all accept
  `lead.email`), so the review is the guard: dot-free names only.

## Deep insert / relationships

- **Grandchild records in a deep insert are dropped or mis-parented.** Multi-level deep
  inserts need each level wired correctly; verify the whole tree, not just the first child.

## Codegen & project layout

- **Compiles locally, missing on CI.** A committed source file was named `*.generated.cs`, and the
  repository's `.gitignore` ignores that pattern (common in .NET templates and in the Vela repo; the
  0.19.6 scaffold's own `.gitignore` does not - check yours). Never name a committed file
  `*.generated.cs`; let the CLI name output.
- **Adding a typed message silently misbehaves.** A modelled plugin message touches several
  files that must stay in sync (including the CLI's known-messages list). Use `vela add`
  rather than hand-wiring; regenerate rather than editing generated output.

## Build / smoke

- **You compiled against a stale framework.** Purge the `vela.plugins` / `vela.testing`
  caches under `~/.nuget` before a smoke build, or you build against an old package.

## Execution order / rank

- **Rank "collisions" with Microsoft / managed steps are normal and harmless.** `vela plan` may
  report that your step shares a rank with other steps on the same message/stage (e.g. MS managed
  plugins like PredictiveScoring, OpportunityScoring). You do **not** control or truly conflict with
  managed steps - **do not bump your rank just to dodge them.**
- What actually matters is deterministic ordering among **your OWN** steps on the same
  table + message + stage. Use `WithExecutionOrder(n)` only to sequence *your* steps relative to
  each other when you register more than one; don't set it reactively to avoid managed steps.

## Analyzers (`Vela.Analyzers`, shipped in `Vela.Plugins` 0.28.2)

Treat every VELA diagnostic in authored code as a gate failure. The ones you will meet most:

- **VELA001** - a column selector (`FilterOn`, images, typed `Select`) targets a member that is not a
  Dataverse column (e.g. `e => e.Id`, the `add step` placeholder).
- **VELA002** - every `RegisterStep()` chain must end with `.Handle(...)`.
- **VELA003** - a step modifier set twice, or two steps for the same message/stage on one plugin
  (merge them - combine the filtering attributes).
- **VELA005** - the same column listed twice in one `FilterOn`/image/`Select`.
- **VELA006** (warning) - `OnMessage("...")` used where a typed trigger (`OnCreate`, `OnUpdate`...) exists.
- **VELA010** - a relationship used where a column is expected.
- **VELA011** - mutable plugin state: plugin instances are reused and called concurrently by the
  sandbox, so a writable field leaks data between executions. Keep state in locals / the context.
- **VELA012** - throw `InvalidPluginExecutionException`; any other exception reaches the caller as a
  generic error.
- **VELA013** - `new ColumnSet(true)` retrieves every column. Prefer an explicit
  `new ColumnSet("attr1", "attr2")`. (The scaffold's own demo tests use `ColumnSet(true)` and trip
  this - cosmetic in generated demo code, but do not copy the pattern into real queries.)
- **VELA014** - a plugin with typed images (`WithPreImage`/`WithPostImage`) must be `partial`; in
  practice the build reports it as **`CS0260`** (missing partial modifier) on the plugin class.
- Others (handler/context mismatch, a handler bound on two image steps, static handlers...) explain
  themselves in the diagnostic text - read it, don't suppress it.

## Verification discipline

- Report the **observed** org/build/test state, never the intended one.
- `models --verify` exits `5` on drift and `plan`/`apply` exit `6` on connection failure -
  treat non-zero exit codes as failures to surface, not to swallow.
