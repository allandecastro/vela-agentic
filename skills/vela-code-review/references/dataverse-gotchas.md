<!-- GENERATED copy of references/dataverse-gotchas.md by scripts/sync-copilot.mjs. Edit the source file, not this copy. -->

# Dataverse & Vela gotchas (battle-tested)

Real failure modes seen in Vela plugins. Skills cite these as Red Flags. Each entry is a
symptom → cause → fix.

## Registration & steps

- **Associate / Disassociate steps not firing - or firing for everything.** In Dataverse these
  messages have a **single message filter: primary entity `none`** (verified on a dev org:
  `sdkmessagefilters` for Associate = 1, primary `none`); a step matched by a primary entity never runs.
  Vela (0.33.0) registers `RegisterStep().OnAssociate()` / `OnDisassociate()` **message-level** (step
  definition `EntityLogicalName` empty), so the step fires - for **every** relationship in the org.
  Scope it with `.ForRelationship("<schema name>", ...)`: Vela enforces the scope at dispatch (the
  handler runs only for those relationships). The plugin's `<T>` does not filter the Target: in the
  harness an association made from the other side ran an `EntityPluginBase<Contact>` handler with an
  `account` Target - check `ctx.Request.Target.LogicalName` and the related entities' types. (Marketing
  lists: adding members from the UI may raise `AddMember` / `AddListMembers` rather than Associate -
  typed `OnAddMemberList()` / `OnAddListMembersList()` triggers exist; confirm which message the story
  really needs.)
- **Bulk messages (`CreateMultiple` / `UpdateMultiple`) and single-record steps.** The pipelines are
  merged: for an UpdateMultiple request Dataverse also runs the Update steps per row (framework doc),
  and in the harness a single Update fired an UpdateMultiple step. Register the logic on **one** of
  them (UpdateMultiple for one execution per batch; Update when per-row context is needed) - not both,
  or it runs twice. A bulk handler iterates `ctx.Request.Targets` and never writes per record.
- **Create/Update step never triggers on the change you expect.** A filtering attribute
  excludes the attribute that actually changed. Check the filtering attributes against the
  attribute being written.
- **Create/Update step without a filter: build error VELA020.** Every Create/Update(+Multiple) step
  requires a `FilterOn(...)` (`vela add plugin|step` refuses Create/Update without
  `--filtering-attributes`). On Create the filter is ignored at runtime but still mandatory - default it
  to the primary column and never drop it, even when the step should fire on every create. On Update the
  filter actually gates the trigger.
- **Image is empty at runtime.** The image was not registered for that message/stage, or the
  requested attributes were not included. With the generated `<Handler>Context`, an uncaptured column
  does not compile and reading an uncaptured image is VELA017; through the untyped extensions
  (`GetPreImage<T>()`, an alias) it is still a silent null - verify the registration, not just the code.
- **A SetState step never fires** (VELA022): `SetStateRequest` and an Update of `statecode` fire the
  SetStateDynamicEntity and Update steps. Register on Update (filter on `statecode`).

## Runtime: recursion, state, sandbox, transactions, secrets

- **Save fails with a depth/recursion error.** Vela's plugin-level depth guard (`MaxDepth`, default
  `PluginBase.DefaultMaxDepth` = **8**, the Dataverse limit) throws `InvalidPluginExecutionException` when
  `ctx.Depth` exceeds it - the user's whole operation fails (the harness `PluginPipeline` reports "stopped
  at depth 9 (cap 8)"). Cause: the plugin writes something that re-triggers the same step (its `FilterOn`
  includes the column it writes, or it `Update`s its own record in PostOperation), or two plugins trigger
  each other. Fix the cause: edit `ctx.Request.Target` in PreOperation instead of a write-back (that edit
  is part of the same write and re-triggers nothing, so filtering on the column you normalise there is
  fine); when you must write back, keep the written columns out of the step's filtering attributes; write
  only when the value actually changes (compare with `ctx.PreImage` / `HasChanged`). **Do not** paper over
  it with `if (ctx.Depth > 1) return;` **or its declarative form `.SkipWhenDepthAbove(1)`**:
  `SkipWhenDepthAbove(n)` skips this step's handler (with a trace line) instead of throwing when the depth
  exceeds `n` - it is runtime-only, not deployed. Verified in the harness: a PostOperation step that
  updates its own filtered column with `SkipWhenDepthAbove(1)` still writes twice and fires twice (the
  second run is skipped), and it also skips legitimate calls made by other plugins, flows or child
  operations (Microsoft advises against logic tied to a `Depth` value). Use either only with a reason
  recorded in the Canvas. The guard is a backstop, not a design.
- **Data leaks between executions / random failures under load.** Plugin instances are cached and
  called concurrently by the sandbox; a writable field is shared across users and requests
  (**VELA011**). Keep per-execution state in locals or the context; never cache org data in a static.
  Don't start parallel work either (`Task.Run`, `Parallel.For` - **VELA024**): plugin code runs on the
  calling thread.
- **Works locally, fails on the org: "sandbox" / security / timeout errors.** Plugins run in an
  isolated sandbox: no file system (**VELA019**), registry or local machine APIs; outbound calls over
  HTTP/HTTPS to DNS names only (no raw IP addresses); and a plugin execution is cut off after
  **2 minutes**. Keep Sync steps short; move slow or external work to an Async step (outbound HTTP code
  lives in the Plugins project, which references `System.Net.Http`; set an explicit timeout).
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
  (not exported with the solution, set per environment, readable by admins only): declare the step with
  `.WithSecureConfigFrom("Name")` and supply the value at deploy time (`vela plan|apply --secure-config
  Name=VALUE|Name=@file`, or `VELA_SECURE_CONFIG_Name`); the plugin reads it through `SecureConfig`. Or an
  external secret store reached with a managed identity (`ctx.AcquireManagedIdentityToken`).

- **"Last one" rollups race.** A rule like "when the last active child is deactivated, deactivate
  the parent" can miss when two children are deactivated in parallel: each sees the other still
  active. Record it in the Canvas as an accepted limitation, or use an Async recheck.

- **A "begins with" / "like" query matches far too many rows.** Dataverse translates `BeginsWith`,
  `Like` (and the Web API's `startswith`/`contains`) to SQL `LIKE`, where `[`, `]`, `%` and `_` are
  wildcards: `startswith(name,'[vela-eval]')` matched 517 unrelated accounts on a dev org (`[...]` is a
  character class). Escape them (`[[]`, `[%]`, `[_]`) when the value comes from data or user input.

## Custom APIs

- **Custom API parameter rejected: "can contain only letters, digits and underscores".** Vela 0.33.0's
  builder rejects a dotted (or otherwise non-identifier) parameter name when the definition is built
  (harness `Register`, `vela plan`) - not at `dotnet build`. Use plain identifiers (`AccountId`).
- **Custom API rejected at apply: unique name without the publisher prefix.** Nothing local checks the
  prefix (`ScoreIt` registers in the harness). Name it `<publisher prefix>_<Name>` - `vela add customapi`
  does it from `<VelaPublisherPrefix>`; the review is the guard for hand-written names.
- **Function rejected: "declares no response property".** A Function must return at least one output;
  add one, or make it an Action.

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

## Analyzers (`Vela.Analyzers`, shipped in `Vela.Plugins` 0.33.0)

Treat every VELA diagnostic in authored code as a gate failure. Several are **build errors** (marked
*error*); the rest are warnings. Each one below was verified by compiling a violation on 0.33.0 unless
its text is quoted from the analyzer's own description:

- **VELA001** *error* - a column selector (`FilterOn`, images, typed `Select`) targets a member that is
  not a Dataverse column (e.g. `e => e.Id`).
- **VELA002** - every `RegisterStep()` chain must end with `.Handle(...)`.
- **VELA003** *error* - a single-value step modifier (`WithDescription`, `FilterOn`...) set twice on one step.
- **VELA005** *error* - the same column listed twice in one `FilterOn`/image/`Select`.
- **VELA008** - two steps on one trigger that differ in no filter, image, relationship scope or step key
  (they resolve to the same step key): give one a `WithStepKey("...")` or merge them.
- **VELA009** - `HasChanged` without a registered pre-image (or a column missing from it).
- **VELA010** - a relationship navigation property used where a column is expected.
- **VELA011** (warning) - mutable plugin state: plugin instances are reused and called concurrently by
  the sandbox, so a writable field leaks data between executions. Keep state in locals / the context.
- **VELA012** (warning) - throw `InvalidPluginExecutionException`; any other exception reaches the
  caller as a generic error.
- **VELA013** (warning) - `new ColumnSet(true)` retrieves every column. Prefer an explicit
  `new ColumnSet("attr1", "attr2")` or the typed `Select(...)`.
- **VELA014** - a plugin with typed images must be `partial`; in practice the build reports
  **`CS0260`** (missing partial modifier). The scaffold's classes are already `partial`.
- **VELA004 / VELA015 / VELA016** - static handler / handler context that does not match the step /
  one typed-context handler bound to two image-capturing steps.
- **VELA017** *error* - `ctx.PreImage` / `ctx.PostImage` read on a step that captures no such image.
- **VELA018** (warning) - an **Async** step's handler writes to the Target, which has no effect (the
  operation is already committed). Write through `ctx.Service.Update(...)` or make the step Sync.
- **VELA019** - file-system access (`File`, `Directory`, `FileStream`...): the sandbox denies it.
- **VELA020** *error* - a Create/Update(+Multiple) step without `FilterOn(...)`.
- **VELA021** - a typed image projection could not be generated (non-constant capture); code naming it
  then fails with CS0246.
- **VELA022** - a step on SetState never fires.
- **VELA023** *error* - a message with a typed trigger registered through `On<TRequest>()`
  (e.g. `On<UpdateRequest>()`): use `OnUpdate()`.
- **VELA024** (warning) - `Task.Run` / `Parallel.*`: parallel work in a plugin.
- Read the diagnostic text; don't suppress it.

## Verification discipline

- Report the **observed** org/build/test state, never the intended one.
- `models --verify` exits `5` on drift, `plan`/`apply` exit `6` on connection failure and `4` without a
  resolvable `--solution`, `apply` exits `7` on a partial apply - treat non-zero exit codes as failures to
  surface, not to swallow.
