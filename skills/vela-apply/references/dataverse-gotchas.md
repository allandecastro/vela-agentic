<!-- GENERATED copy of references/dataverse-gotchas.md by scripts/sync-copilot.mjs. Edit the source file, not this copy. -->

# Dataverse & Vela gotchas (battle-tested)

Real failure modes seen in Vela plugins. Skills cite these as Red Flags. Each entry is
symptom → cause → fix.

## Registration & steps

- **Associate / Disassociate fires for every relationship - or never.** These messages have a single
  filter, primary entity `none`: a step matched by a primary entity never runs. Vela registers
  `OnAssociate()` / `OnDisassociate()` message-level, so it fires for **every** relationship in the org.
  Scope it with `.ForRelationship("<schema name>", ...)` (enforced at dispatch). The plugin's `<T>` does
  not filter the Target: either side can be the Target (an association made from the account side runs an
  `EntityPluginBase<Contact>` handler with an `account` Target) - check `ctx.Request.Target.LogicalName` and
  the related entities' types. Marketing-list members added from the UI may raise `AddMember` /
  `AddListMembers` instead (`OnAddMemberList()` / `OnAddListMembersList()`) - confirm the message the story needs.
- **Bulk + single-record steps run twice.** An UpdateMultiple request also runs the Update steps per row
  (and in the harness a single Update fired an UpdateMultiple step). Register on **one**: UpdateMultiple for
  one execution per batch, Update for per-row context. A bulk handler iterates `ctx.Request.Targets` and
  never writes per record.
- **Create/Update step never triggers on the expected change.** The filtering attributes exclude the
  column actually written - check them against it.
- **Every Create/Update(+Multiple) step needs `FilterOn(...)`** (VELA020; `vela add` requires
  `--filtering-attributes`). **On Create the filter gates the trigger exactly as on Update** (verified
  live; the Microsoft docs are wrong; `PluginPipeline` matches): a create sending none of the filtered
  columns does not fire. To fire on every create, filter on a column every create sends (business-required)
  - and the Canvas says what happens to a create without it.
- **Image is empty at runtime.** Not registered for that message/stage, or the column not captured. The
  generated `<Handler>Context` catches this at build (VELA017); the untyped `GetPreImage<T>()` / aliases
  return a silent null - verify the registration, not just the code.
- **State changes are Updates.** `SetStateRequest` is deprecated: change state with an Update of `statecode`
  / `statuscode`, and react to it on Update filtered on `statecode`, checking the new state in the Target
  (`StateCode == Inactive`); reactivation fires the same step. A SetState step never fires (VELA022). Only when
  known legacy callers still send `SetStateRequest` (it also fires the Update step) add one pipeline test with it.

## Runtime: recursion, state, sandbox, transactions, secrets

- **Save fails with a depth/recursion error.** Vela's depth guard (`MaxDepth`, default 8 = the Dataverse
  limit) throws when `ctx.Depth` exceeds it and the user's whole operation fails (harness: "stopped at depth
  9 (cap 8)"). Cause: the plugin re-triggers its own step (its `FilterOn` includes the column it writes, or
  it `Update`s its own record in PostOperation), or two plugins trigger each other. Fix the cause: edit
  `ctx.Request.Target` in PreOperation (part of the same write, re-triggers nothing - filtering on that
  column is fine); for a write-back keep written columns out of the filter; write only on real change
  (`ctx.PreImage` / `HasChanged`). **Do not** paper over it with `if (ctx.Depth > 1) return;` or
  `.SkipWhenDepthAbove(1)` (runtime-only skip): the self-triggering step still writes and fires twice, and
  legitimate nested calls from other plugins/flows are skipped too. Either needs a reason in the Canvas.
- **Data leaks between executions / random failures under load.** Plugin instances are cached and called
  concurrently: no writable fields (VELA011), no org data in statics, no parallel work (VELA024).
- **Works locally, fails on the org.** The sandbox has no file system (VELA019), registry or machine APIs;
  outbound HTTP/HTTPS to DNS names only (VELA025); a **2-minute** execution cutoff. Keep Sync steps short;
  put slow/external work in an Async step, outbound code in the Integrations project
  (`vela init --integrations`), with an explicit timeout (VELA026) proven by a test whose fake transport
  never answers (it must fail within the timeout, not the 100 s default).
- **Serialization works in tests, fails on the org.** Partial trust: reflection serializers
  (`DataContractJsonSerializer`, `XmlSerializer`) handle only **public** types/members; tests run in full
  trust and pass. Make payload types public (review: **Critical**, every call fails).
- **An error undoes more (or less) than expected.** Sync Pre/PostOperation run inside the transaction:
  throwing rolls back everything, including earlier plugin writes. PreValidation runs before it. Async runs
  after commit (failure = a failed system job, the save stays). External side effects never roll back -
  don't make them from a Sync step that may still fail after them.
- **A failed write inside the transaction ends it, even when caught:** rethrow as
  `InvalidPluginExecutionException`. A caught failed read (missing row, missing privilege, row out of depth)
  does not end it; still handle it explicitly rather than swallowing it.
- **User sees "An unexpected error occurred".** Only `InvalidPluginExecutionException` surfaces its
  message (VELA012). Throw it with an actionable message, never swallow, `ctx.Trace(...)` what you need.
- **A secret in a solution export or the repo.** Unsecure config is exported; code is in git. Use secure
  configuration: `.WithSecureConfigFrom("Name")`, value at deploy time
  (`vela plan|apply --secure-config Name=@file`, or `VELA_SECURE_CONFIG_Name`), read via
  `SecureConfig` - or a secret store via managed identity (`ctx.AcquireManagedIdentityToken`).
- **A role check passes in the root business unit only.** A role is copied into every business unit: the
  user's `systemuserroles.roleid` is the copy of their BU. Compare the role's `parentrootroleid` to the root id
  (`Roles.<X>Id`) - for a system role, `roletemplateid` to `Roles.<X>TemplateId` - and count roles held through teams (`teamroles`) when the story says so.
- **"Last one" rollups race.** "Deactivate the parent when the last active child is deactivated" misses
  when two children are deactivated in parallel. Record it in the Canvas as accepted, or use an Async recheck.
- **A "begins with" / "like" query matches far too many rows.** `BeginsWith`, `Like`, `startswith`,
  `contains` become SQL `LIKE`, where `[`, `]`, `%`, `_` are wildcards (`startswith(name,'[vela-eval]')`
  matched 517 unrelated accounts). Escape them (`[[]`, `[%]`, `[_]`) for data or user input.

## Custom APIs

- **Parameter rejected: "only letters, digits and underscores".** Dotted names fail when the definition is
  built (harness `Register`, `vela plan`), not at `dotnet build`. Use plain identifiers (`AccountId`).
- **Rejected at apply: unique name without the publisher prefix.** Nothing local checks it. Name it
  `<publisher prefix>_<Name>` (`vela add customapi` does it); review guards hand-written names.
- **Function rejected: "declares no response property".** Add an output, or make it an Action.

## Deep insert / relationships

- **Grandchild records dropped or mis-parented.** Each level of a multi-level deep insert must be wired;
  verify the whole tree.

## Codegen & project layout

- **Compiles locally, missing on CI.** A committed `*.generated.cs` matched a `.gitignore` pattern. Never
  name a committed file that way; let the CLI name output.
- **A hand-wired typed message misbehaves.** It spans several files (incl. the CLI's known-messages list).
  Use `vela add`; regenerate, never edit generated output.

## Execution order / rank

- **Rank shared with Microsoft/managed steps** (reported by `vela plan`) is normal and harmless - don't
  bump your rank to dodge it. Only ordering among **your own** steps on one table + message + stage
  matters: use `WithExecutionOrder(n)` for that, never reactively.

## Analyzers (`Vela.Analyzers`)

Every VELA diagnostic in authored code is a gate failure (several are build errors); read its text, don't
suppress it. The runtime and safety ids: VELA011 mutable plugin field · VELA012 non-`InvalidPluginExecutionException`
throw · VELA013 `ColumnSet(true)` · VELA017 uncaptured image read · VELA018 Async handler writes the Target
(lost) · VELA019 file system · VELA020 Create/Update without `FilterOn` · VELA022 step on SetState ·
VELA023 `On<TRequest>()` for a typed trigger · VELA024 parallel work / blocking on a task in a plugin type
(the sync wrapper over `HttpClient` lives in the service) · VELA025 HTTP to an IP address · VELA026
`HttpClient` without `Timeout` · VELA027 empty `catch` in a plugin. Non-obvious: a missing `partial` (VELA014) surfaces as **CS0260**; an
ungenerated typed image projection (VELA021) as **CS0246**.

## Verification discipline

- Report the **observed** org/build/test state, never the intended one.
- Non-zero exits are failures to surface (`models --verify` 5 = drift; `plan`/`apply` 2 = `--solution` missing,
  4 = solution or publisher not found, 6 = connection; `apply` 7 = partial).
