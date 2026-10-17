# Registration rules & design decisions

Two things live here: the **legal matrix** (what combinations Dataverse/Vela allow) and the
**judgment calls** the tooling does NOT decide for you (Sync vs Async, reuse vs new, service
extraction). Skills point here.

## What the typed builder already enforces (at compile time)

Vela's fluent `RegisterStep()` gates message × stage × mode × image through its interfaces, so
**illegal combinations do not compile** - e.g. `WithPostImage` does not exist on a Delete step,
`Async()` exists only on `PostOperation()`, `ForRelationship` only on Associate/Disassociate. The
analyzers (vela 0.25.0 / Vela.Plugins 0.34.0) turn the rest into build errors: a Create/Update step
without `FilterOn` (VELA020), `On<UpdateRequest>()` instead of the typed trigger (VELA023), an image
read but not captured (VELA017). Trust the type system; if something does not compile, it is usually an
illegal registration, not a framework bug.

## Legal matrix

| Message | Stages | Pre-image | Post-image | Mode | FilterOn |
| --- | --- | --- | --- | --- | --- |
| Create | PreValidation / PreOperation / PostOperation | no (record doesn't exist yet) | yes at PostOperation | Sync (Async at PostOp) | **required** - VELA020; gates the trigger (as on Update) |
| Update | PreValidation / PreOperation / PostOperation | yes | yes at PostOperation | Sync (Async at PostOp) | **required** - VELA020 (gates the trigger) |
| Delete | PreValidation / PreOperation / PostOperation | yes | **no (record is gone)** | Sync (Async at PostOp) | n/a |
| Associate / Disassociate | PreValidation / PreOperation / PostOperation | n/a | n/a | Sync (Async at PostOp) | n/a - registered message-level (primary entity `none`); scope with `ForRelationship("<schema>")` (see gotchas) |
| CreateMultiple / UpdateMultiple | PreValidation / PreOperation / PostOperation (Pre = Sync only) | n/a | n/a | Sync (Async at PostOp) | `FilterOn` as for Create/Update; pipelines merged with Create/Update - register one, not both |

- **Async is PostOperation-only** for every message.
- **No post-image on Delete** and **no pre-image on Create** - the record doesn't exist on the
  other side. (Trying either won't compile.)
- Create's FilterOn gates the trigger like Update's (verified live; the Microsoft docs are wrong here) -
  for "every create", filter on a column every create sends (see `dataverse-gotchas.md`).
- SetState steps never fire (VELA022): react to the Update (or SetStateDynamicEntity) instead.

## Target solution & publisher (prerequisite - decide in the Canvas)

Everything must land in an **unmanaged solution** tied to a **publisher** (its customization
prefix), or components fall into the org's default solution.

- `vela plan|apply --solution <uniquename>` resolves the publisher prefix and **tags every component**
  (assembly, steps, images, custom APIs) into that solution. **Always pass `--solution`** - `plan`
  without it fails (exit 4, "no solution publisher prefix").
- **Vela does NOT create the solution or the publisher** - they must already exist in the org
  (created by a maker / `pac solution init` / Power Apps). A non-existent `--solution` is rejected.
- **Confirm it read-only:** `vela solution show <uniquename> --json <connection>` prints
  `{"solution":"...","publisherPrefix":"..."}` (exit 0), or exits 4 when the solution does not exist.
- **Don't invent a prefix - take the target solution's publisher customization prefix.** Scaffold with
  `vela init --publisher-prefix <it>` (recorded as `<VelaPublisherPrefix>` in the plugin project, and used
  by `vela add customapi` for `<prefix>_<Name>` unique names). `--prefix` is only the namespace/assembly
  prefix (`Zava` → `Zava.Plugins`). A Custom API unique name without the publisher prefix is rejected by
  `vela apply --solution`.
- So the Canvas must record the **target solution unique name** and the **publisher prefix**, and
  confirm the solution exists (`vela solution show`) before apply.

## Judgment calls (NOT enforced - decide these in `vela-plan-review`, record in the Vela Canvas)

### Stage: PreOperation vs PostOperation
- **Change a column of the record being created/updated → PreOperation**, by setting it on
  `ctx.Request.Target`. The platform writes it with the rest of the record: one write, no extra
  Update event, nothing to re-trigger. This is the default for defaulting, normalising, deriving a
  column from others on the same row.
- **Validation / abort → PreValidation or PreOperation**, throwing `InvalidPluginExecutionException`.
- **PostOperation** only when you need the saved result (a **Sync** PostOperation still runs inside the
  transaction, before the commit - a failure rolls the write back; only Async runs after the commit): the new record's id on Create, writes to
  **other** records (children, parents, related tables), or work that must see what was actually saved.
- **Anti-pattern: PostOperation + `ctx.Service.Update(...)` of the same record.** It is a second
  write, fires a second Update through every plugin on that table (including this one if its filter
  matches - recursion), and costs a round trip. Use PreOperation unless a reason above applies, and
  record that reason in the Canvas.

### Sync vs Async
- **Sync** when the caller must see the effect in the same transaction: validation/abort,
  modifying the same record before commit (pre-stage), or a result the user relies on immediately.
- **Async** when the work is non-blocking, slow, external (HTTP, queue), or eventual, and a short
  delay is acceptable. Async is PostOperation-only and must not be relied on for validation, and an
  Async step cannot change the record through `ctx.Request.Target` (VELA018 - write through `ctx.Service`).
  `Async(deleteJobOnSuccess: true)` deletes the succeeded system job (keeps the async queue clean).
- Default to **Sync** for in-transaction data shaping; reach for Async only with a reason.

### Reuse vs new registration (same table)
- **New plugin, no class exists yet** → `vela add plugin <Name> --entity <E> --message <M>`, then
  code. Never hand-create the class.
- **Another behaviour on a table that already has a plugin** → prefer `vela add step` on the
  existing plugin (keeps registration coherent) unless the concern is genuinely separate.
- **Reuse** an existing plugin/step/service where the behaviour already exists - do not duplicate.

### Outbound integration (calls to another system)
- Outbound code lives in the **Integrations project**: scaffold with `vela init --integrations` (an
  empty `src/<Prefix>.Integrations` plugin project + `tests/<Prefix>.Integrations.Tests`, no demos; its
  csproj references `System.Net.Http`; `--managed-identity` implies it). **Don't scaffold with
  `--samples` for real work** - it adds demo code and a ConsoleApp.
- It builds its **own package** (`artifacts/<Prefix>.Integrations.<ver>.nupkg`): preview (`vela plan`)
  **both** packages. Put the call in a service, usually behind an **Async** PostOperation step. Sandbox rules apply: HTTPS to DNS names
  only (no raw IP), explicit timeouts well under the 2-minute limit, secrets via
  `WithSecureConfigFrom("Name")` (never code or unsecure config). See `dataverse-gotchas.md`.

### Service needed vs inline (SOLID/DRY)
- Keep the handler thin (SRP): orchestration in `OnExecute`, real logic in a service when it is
  reusable or worth testing in isolation → `vela add service <Name> --entity <E>`, inject via DI.
- Reuse an existing service before adding one. Do not extract a service for a one-line, single-use
  operation - that is ceremony, not design. Logic shared by the steps of **one** plugin → a private
  helper (+ constant); logic shared **across plugins** → a service. A shared constant alone is not
  sharing the logic: the rule itself (e.g. "empty → default") lives once in the helper, and each step's own
  guard (e.g. "only when the column was sent") wraps the call.
