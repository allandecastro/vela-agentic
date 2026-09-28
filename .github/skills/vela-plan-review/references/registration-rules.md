<!-- GENERATED copy of references/registration-rules.md by scripts/sync-copilot.mjs. Edit the source file, not this copy. -->

# Registration rules & design decisions

Two things live here: the **legal matrix** (what combinations Dataverse/Vela allow) and the
**judgment calls** the tooling does NOT decide for you (Sync vs Async, reuse vs new, service
extraction). Skills point here.

## What the typed builder already enforces (at compile time)

Vela's fluent `RegisterStep()` gates message × stage × mode × image through its interfaces, so
**illegal combinations do not compile** - e.g. `WithPostImage` does not exist on a Delete step,
`Async()` exists only on `PostOperation()`. Trust the type system; if something does not compile,
it is usually an illegal registration, not a framework bug.

## Legal matrix

| Message | Stages | Pre-image | Post-image | Mode | FilterOn |
| --- | --- | --- | --- | --- | --- |
| Create | PreValidation / PreOperation / PostOperation | no (record doesn't exist yet) | yes at PostOperation | Sync (Async at PostOp) | **required** (ignored at runtime) |
| Update | PreValidation / PreOperation / PostOperation | yes | yes at PostOperation | Sync (Async at PostOp) | **required** (gates the trigger) |
| Delete | PreValidation / PreOperation / PostOperation | yes | **no (record is gone)** | Sync (Async at PostOp) | n/a |
| Associate / Disassociate | Pre / Post | n/a | n/a | Sync / Async | n/a - message filter is primary entity **`none`** only; **not expressible in Vela 0.29.3** (see gotchas) |
| CreateMultiple / UpdateMultiple | PreValidation / PreOperation / PostOperation (Pre = Sync only) | n/a | n/a | Sync (Async at PostOp) | `FilterOn` as for Create/Update; pipelines merged with Create/Update - register one, not both |

- **Async is PostOperation-only** for every message.
- **No post-image on Delete** and **no pre-image on Create** - the record doesn't exist on the
  other side. (Trying either won't compile.)
- Create's FilterOn is a registration requirement but ignored at runtime - default it to the
  primary column, never drop it (see `dataverse-gotchas.md`).

## Target solution & publisher (prerequisite - decide in the Canvas)

Everything must land in an **unmanaged solution** tied to a **publisher** (its customization
prefix), or components fall into the org's default solution.

- `vela apply --solution <uniquename>` **tags every component** (assembly, steps, images, custom
  APIs) into that solution. **Always pass `--solution`.**
- **Vela does NOT create the solution or the publisher** - they must already exist in the org
  (created by a maker / `pac solution init` / Power Apps). A non-existent `--solution` is rejected.
- **Don't invent a prefix - take the target solution's publisher customization prefix.** The
  scaffold `--prefix` must equal it, or custom-API / component unique names (`prefix_...`) are
  rejected by `vela apply --solution`.
- So the Canvas must record the **target solution unique name** and the **publisher prefix**, and
  confirm the solution exists before apply.

## Judgment calls (NOT enforced - decide these in `vela-plan-review`, record in the Vela Canvas)

### Stage: PreOperation vs PostOperation
- **Change a column of the record being created/updated → PreOperation**, by setting it on
  `ctx.Request.Target`. The platform writes it with the rest of the record: one write, no extra
  Update event, nothing to re-trigger. This is the default for defaulting, normalising, deriving a
  column from others on the same row.
- **Validation / abort → PreValidation or PreOperation**, throwing `InvalidPluginExecutionException`.
- **PostOperation** only when you need the committed result: the new record's id on Create, writes to
  **other** records (children, parents, related tables), or work that must see what was actually saved.
- **Anti-pattern: PostOperation + `ctx.UserService.Update(...)` of the same record.** It is a second
  write, fires a second Update through every plugin on that table (including this one if its filter
  matches - recursion), and costs a round trip. Use PreOperation unless a reason above applies, and
  record that reason in the Canvas.

### Sync vs Async
- **Sync** when the caller must see the effect in the same transaction: validation/abort,
  modifying the same record before commit (pre-stage), or a result the user relies on immediately.
- **Async** when the work is non-blocking, slow, external (HTTP, queue), or eventual, and a short
  delay is acceptable. Async is PostOperation-only and must not be relied on for validation.
- Default to **Sync** for in-transaction data shaping; reach for Async only with a reason.

### Reuse vs new registration (same table)
- **New plugin, no class exists yet** → `vela add plugin <Name> --entity <E> --message <M>`, then
  code. Never hand-create the class.
- **Another behaviour on a table that already has a plugin** → prefer `vela add step` on the
  existing plugin (keeps registration coherent) unless the concern is genuinely separate.
- **Reuse** an existing plugin/step/service where the behaviour already exists - do not duplicate.

### Service needed vs inline (SOLID/DRY)
- Keep the handler thin (SRP): orchestration in `OnExecute`, real logic in a service when it is
  reusable or worth testing in isolation → `vela add service <Name> --entity <E>`, inject via DI.
- Reuse an existing service before adding one. Do not extract a service for a one-line, single-use
  operation - that is ceremony, not design.
