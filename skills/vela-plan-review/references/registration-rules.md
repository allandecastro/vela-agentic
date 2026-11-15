<!-- GENERATED copy of references/registration-rules.md by scripts/sync-copilot.mjs. Edit the source file, not this copy. -->

# Registration rules & design decisions

The **legal matrix** (what Dataverse/Vela allow) and the **judgment calls** the tooling does NOT make
(stage, Sync vs Async, reuse vs new, service). Skills point here.

## What the typed builder already enforces

`RegisterStep()` gates message × stage × mode × image through its types, so **illegal combinations do
not compile** (no `WithPostImage` on Delete, `Async()` only after `PostOperation()`, `ForRelationship`
only on Associate/Disassociate); analyzers catch the rest (VELA020, VELA023, VELA017 - see
`dataverse-gotchas.md`). If it does not compile, suspect an illegal registration, not a framework bug.

## Legal matrix

| Message | Stages | Pre-image | Post-image | FilterOn |
| --- | --- | --- | --- | --- |
| Create | PreVal / PreOp / PostOp | no (record doesn't exist yet) | PostOp | **required** (VELA020); gates the trigger as on Update |
| Update | PreVal / PreOp / PostOp | yes | PostOp | **required** (VELA020); gates the trigger |
| Delete | PreVal / PreOp / PostOp | yes | **no (record is gone)** | n/a |
| Associate / Disassociate | PreVal / PreOp / PostOp | n/a | n/a | n/a - message-level; scope with `ForRelationship("<schema>")` |
| CreateMultiple / UpdateMultiple | PreVal / PreOp / PostOp (Pre = Sync only) | n/a | n/a | as Create/Update; pipeline merged with Create/Update - register one, not both |

- Mode: Sync everywhere; **Async is PostOperation-only** for every message.
- State changes: react to the Update filtered on `statecode` (`SetStateRequest` is deprecated; a SetState step
  never fires, VELA022).

## Target solution & publisher (prerequisite - decide in the Canvas)

- `vela plan|apply --solution <uniquename>` resolves the publisher prefix and tags every component into
  that unmanaged solution. **Required** (exit 2 without it); one solution per run - read it from `PROJECT.md`
  (`packages:` maps each package id to its solution).
- **Vela does NOT create the solution or publisher** - they must exist in the org. Confirm read-only:
  `vela solution show <uniquename> --json <connection>` (exit 4 when it does not exist).
- **Don't invent a prefix:** take the solution's publisher customization prefix and scaffold with
  `vela init --publisher-prefix <it> --solution <uniquename>`; `vela add customapi --prefix` takes it from
  `PROJECT.md` (`<prefix>_<Name>`; a name without it is rejected by `vela apply --solution`). `--prefix` on
  `init` is only the namespace/assembly prefix.
- `PROJECT.md` is the only record of the prefix and the solutions - never copied into a Canvas.

## Judgment calls (NOT enforced - decide in `vela-plan-review`, record in the Vela Canvas)

### Stage: PreOperation vs PostOperation
- **Change a column of the record being written → PreOperation**, set on `ctx.Request.Target`: one
  write, no extra Update event. The default for defaulting, normalising, deriving same-row columns.
- **Validation / abort → PreValidation or PreOperation**, throwing `InvalidPluginExecutionException`.
- **PostOperation** only when you need the saved result: the new id on Create, writes to **other**
  records, or work that must see what was saved. A **Sync** PostOperation is still in the transaction (a
  failure rolls back); only Async runs after commit.
- **Anti-pattern: PostOperation + `ctx.Service.Update(...)` of the same record** - a second write that
  re-fires every Update plugin on the table (recursion if its filter matches). Use PreOperation unless a
  reason above applies, and record it in the Canvas.

### Sync vs Async
- **Sync** when the caller must see the effect in the transaction: validation, same-record changes,
  results the user relies on immediately. The default for in-transaction data shaping.
- **Async** (with a reason) for non-blocking, slow, external or eventual work. Never for validation; it
  cannot change the record through `ctx.Request.Target` (VELA018 - write through `ctx.Service`).
  `Async(deleteJobOnSuccess: true)` keeps the async queue clean.

### Reuse vs new registration (same table)
- **One plugin class per table**, named `<Entity>Plugin` (`AccountPlugin`) - a deterministic name, so isolated or
  parallel builds converge. No class on the table → `vela add plugin <Entity>Plugin --entity <E> --message <M>`
  (never hand-create it). The table has one (whatever its name) → each story is a step on it (`vela add step`);
  the class is never renamed. A separate class only when the Canvas justifies it: its own secure/unsecure config, another
  package (Integrations), or a Custom API.
- **Handlers are named after the behaviour** (`OnDeleteGuard`, `OnPhoneNormalize`): pass `--handler` on
  `vela add plugin` and `vela add step`.
- **Shared files have fixed names** (parallel builds append to the same file): message keys and texts in
  `Messages.cs` (`ProjectMessages`), the assembly registrar in `ProjectServices.cs` (both generated by `vela init`), rules in `docs/rules/<table>.md`.
- **Parallel builds** (one session dispatches several builders):
  - **before dispatch**, the dispatcher grills every story, commits the ADRs it needs to the base branch, and
    gives each builder its rule ids and ADR numbers - two builders never pick the same id;
  - each builder works **only in its own worktree** - never a checkout or commit in the shared repository;
  - **after merging**, re-check one class per table, these shared files and duplication (the same query or rule
    definition in two places). Never copy another feature's uncommitted content.
- **Reuse** existing behaviour (plugin/step/service) - do not duplicate.

### Outbound integration (calls to another system)
- Lives in the **Integrations project**: `vela init --integrations` (`--managed-identity` implies it).
  **Never `--samples` for real work.**
- It builds its **own package**: preview (`vela plan`) **both** packages. Put the call in a service,
  usually behind an **Async** PostOperation step. Sandbox: HTTPS to DNS names only, explicit timeouts
  well under 2 minutes, secrets via `WithSecureConfigFrom("Name")` (see `dataverse-gotchas.md`).

### Service needed vs inline (SOLID/DRY)
- Thin handler (SRP); real logic in a service when reusable or worth isolated tests →
  `vela add service <Name> --entity <E>` (no `--entity` for one shared by several tables), injected via DI. Reuse an existing service first.
- **Triggers - extract a service when any holds** (record which in the Canvas `service:` reasoning):
  1. **A second consumer** - another plugin, Custom API or step on another table needs the same logic
     (in this story or already in the code). Move the logic out of the first plugin into the service;
     its existing tests stay unchanged and green (a move, not a behaviour change).
  2. **Data access plus decisions** - the logic queries/writes other tables *and* decides on the result:
     the service is tested alone, the handler test only checks the wiring.
  3. **The handler outgrows itself** - more than one business decision, or roughly 30+ lines of logic.
  4. **An outbound call** - always a service (Integrations, below).
  5. **A shared business definition** - a rule other rules reference ("an active contact of an account"):
     one service from the first story, whatever the consumer count today.
- **Placement:** a service lives under the table whose data it owns (`Account/Services/`); a cross-table one in
  `Services/`. Every service is registered once, in the assembly's `ProjectServices` (`IServiceRegistrar`),
  not in each plugin's `ConfigureServices`. Its constructor takes the service it reads with and its
  `<summary>` says which (caller or SYSTEM), so the security context is visible where the data is read.
- **Same rule on N columns or N tables:** one column list per table and one loop or helper, never a block per
  column or a copied plugin.
- No service for a one-line, single-use operation (ceremony). Shared by the steps of **one** plugin → a
  private helper (+ constant); shared **across plugins** → a service. A shared constant alone is not
  shared logic: the rule lives once in the helper; each step's own guard wraps the call.
