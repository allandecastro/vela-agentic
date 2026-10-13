---
name: vela-plugin-authoring
description: Use when implementing the logic of a Vela plugin, after scaffolding, models, and the failing (RED) harness tests exist.
compatibility: "vela CLI >= 0.25.0 (Vela.Plugins >= 0.34.0); dotnet SDK."
---

# Author a Vela plugin

> Paths like `references/<file>.md` in this skill are relative to **this skill's folder** (the
> directory containing this `SKILL.md`), not to the project you are working in.

Write the logic of a plugin after `vela-scaffold` and `vela-models`. Keep *generated* files
(`Models/Generated`) untouched; put logic in the handler the scaffold created (`OnExecute`, or
`Handle<Message>` for a step added with `vela add step`), in the scaffolded plugin file, which is yours.

**Read `references/plugin-authoring-api.md` before writing code.** It has the verbatim shape;
the notes below are the workflow.

## When to use

- The scaffold, models, and the **failing (RED) harness tests** exist, and you now implement the
  behaviour to make those tests **green**. Do not start here before the tests are written and
  seen to fail (`vela-test-harness`).

## Process

Announce: `Using vela-plugin-authoring to <purpose>`.

1. Re-read the **Vela Canvas** (Operations, Approach, Structure, Norms): implement exactly those
   Operations - no scope creep. Honour the Approach decisions (Sync/Async, reuse vs new) already made.
2. **Model first.** A minimal scaffold has no models: every table and column the story touches must
   be in the generated model (`vela-models`) before the RED tests are written - do not fall back to a
   magic string, and never hand-add or hand-edit a property in `Models/Generated`. MODEL precedes
   IMPLEMENT for this reason. No org? Generate offline from an exported solution
   (`vela models --from-solution`, see `vela-models`) or surface the blocker - never hand-write the model.
3. Open the generated handler. Its name depends on how the step was created - both are correct:
   - `vela add plugin` (single-step) → `OnExecute(I<Message><Stage>Context<Entity> ctx)`.
   - `vela add step` (adds a step, the plugin becomes multi-step) → `Handle<Message>` (e.g.
     `HandleUpdate(IUpdatePostContext<Entity> ctx)`), or the name passed with `--handler`.
   Keep the generated name; do not create a parallel class or handler by hand.
4. Read through the typed context: **`ctx.Request.Target`** (the typed record over the live
   InputParameters - in a PreOperation step, set properties on it to change what is written; in an
   Async step a Target write is lost, VELA018), `ctx.PreImage` / `ctx.PostImage` for registered images
   (a step with an image hands its handler a generated `<Handler>Context` exposing only the captured
   columns) - never magic-string attribute names where a model exists. `ctx.GetTarget<Entity>()` is for
   untyped `ILocalPluginContext` handlers only.
5. Write through **`ctx.Service`** (the step's user; there is **no** `ctx.OrganizationService` and no
   `ctx.UserService`); `ctx.SystemService` (SYSTEM) only when elevation is required and recorded in the
   Canvas; `ctx.AsUser(userId)` for a specific user. A secret comes from `.WithSecureConfigFrom("Name")`
   (read `SecureConfig`), never from code or unsecure config.
6. Guard the trigger via the registered **filtering attributes** (`FilterOn(e => e.X)`) and
   the correct **image**, not loose re-checks in code. Add an image in `RegisterPluginSteps`
   if the handler needs prior/final values. Respect the legal matrix
   (`references/registration-rules.md`): no post-image on Delete, no pre-image on Create,
   Async only at PostOperation. The scaffolded class is already `sealed partial` - keep `partial`: the
   generated step contexts nest inside it (without it the build fails with **`CS0260`**, VELA014).
   Associate/Disassociate: scope the step with `.ForRelationship("<schema name>")` and check
   `ctx.Request.Target.LogicalName` (either side of the relationship can be the Target).
7. **SOLID / DRY.** Keep `OnExecute` thin (SRP): orchestration in the handler, real logic in a
   **service** when it is reusable or worth testing in isolation → `vela add service <Name>
   --entity <E>`, injected via DI. Reuse an existing service or plugin before adding one; do not
   duplicate logic. Do not extract a service for a trivial one-liner (steps of one plugin share a private helper;
   plugins share a service). Follow the generated
   **naming** conventions (prefix, `OnExecute`, project layout); don't rename generated members.

## Rationalizations (excuse → rebuttal)

- "I'll use the attribute logical-name string." → Use the generated model property; a typo in
  a string is a runtime bug, a wrong property is a compile error. If the attribute isn't in the
  model, run `vela-models` - don't reach for a string.
- "`ctx.OrganizationService` / `ctx.UserService` to write." → Neither exists. Use `ctx.Service`.
- "`SkipWhenDepthAbove(1)` stops the recursion." → It skips the second run; the write-back still
  happens twice. Fix the cause (PreOperation edit of the Target, or keep the written column out of
  `FilterOn`).
- "I'll add a second plugin class for another message." → Use `vela add step` on the existing
  plugin so registration stays in sync.
- "Target is enough, images are overkill." → For Update/Delete you often need prior values;
  read the correct image (and register it).
- "I'll copy the logic from the other plugin." → Duplication is a DRY violation; extract/reuse a
  service instead.
- "Everything in OnExecute is simpler." → A fat handler violates SRP and can't be unit-tested in
  isolation; move real logic to a service.

## Red flags

- Magic-string attribute names where a generated model exists (or should, via `vela-models`).
- `ctx.OrganizationService` / `ctx.UserService`, a hand-written plugin class, or a renamed generated handler
  (`OnExecute` for `add plugin`, `Handle<Message>` for `add step` - both are legitimate).
- An Associate/Disassociate step without `ForRelationship(...)` (runs for every association in the org).
- A custom API parameter name that is not a plain identifier (rejected when the definition is built).
- Logic duplicated across plugins, or a fat `OnExecute` that should delegate to a service.
- A PostOperation `ctx.Service.Update` of the record the step fired on (use PreOperation +
  `ctx.Request.Target`), or a **write-back** (`ctx.Service.Update`/`Create` of a record that
  re-triggers this step) whose column is in the step's `FilterOn` (recursion). Editing
  `ctx.Request.Target` in PreOperation is not a write-back: filtering on the column you normalise
  there is correct.
- A mutable field on the plugin class (VELA011), a secret in code or unsecure config, or
  `if (ctx.Depth > 1) return;` / `.SkipWhenDepthAbove(n)` without a recorded reason - see
  `references/dataverse-gotchas.md`.
- An illegal registration attempted (post-image on Delete, Async off PostOperation) - see registration-rules.

## Verification

- `dotnet build` is green with no VELA diagnostic in authored code (VELA020/VELA023/VELA017... are
  errors; VELA018/VELA011/VELA012... warnings still fail the gate).
- There is a `vela-test-harness` test covering the new behaviour, and it passes. Authoring is
  not "done" until the harness proves the behaviour.
