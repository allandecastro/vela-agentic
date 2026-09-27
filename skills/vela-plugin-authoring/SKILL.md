---
name: vela-plugin-authoring
description: Use when implementing the logic of a Vela plugin, after scaffolding, models, and the failing (RED) harness tests exist.
compatibility: "vela CLI >= 0.19.6 (Vela.Plugins >= 0.28.2); dotnet SDK."
---

# Author a Vela plugin

> Paths like `references/<file>.md` in this skill are relative to **this skill's folder** (the
> directory containing this `SKILL.md`), not to the project you are working in.

Write the logic of a plugin after `vela-scaffold` and `vela-models`. Keep generated files
untouched; put logic in the `OnExecute` handler the scaffold created.

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
2. **Model first for any non-demo attribute.** The scaffold's generated model only covers
   demo columns (and is `sealed` - no partial extension). If the story touches any other
   attribute, run `vela-models` first - do not fall back to a magic string. MODEL precedes
   IMPLEMENT for this reason. **No-org exception (evals/rehearsals only):** when `vela-models`
   genuinely cannot run, hand-add just the needed typed property with an explicit
   `// STAND-IN for vela-models (no org)` comment. Because the generated model is `sealed` (no
   partial extension), this **does** mean editing the generated model file in place - that is the
   **one sanctioned exception** to "never hand-edit generated files", and only for a no-org
   rehearsal. On a real run there is an org: regenerate with `vela-models` instead.
3. Open the generated handler. Its name depends on how the step was created - both are correct:
   - `vela add plugin` (single-step) → `OnExecute(I<Message><Stage>Context<Entity> ctx)`.
   - `vela add step` (adds a step, the plugin becomes multi-step) → `Handle<Message>` (e.g.
     `HandleUpdate(IUpdatePostContext<Entity> ctx)`), or the name passed with `--handler`.
   Keep the generated name; do not create a parallel class or handler by hand.
4. Read through the typed context: **`ctx.Request.Target`** (the typed record over the live
   InputParameters - in a PreOperation step, set properties on it to change what is written),
   `ctx.PreImage` / `ctx.PostImage` for registered images - never magic-string attribute names where a
   model exists. `ctx.GetTarget<Entity>()` is for untyped `ILocalPluginContext` handlers only (the
   scaffold's TODO comment still mentions it).
5. Write through `ctx.UserService` (there is **no** `ctx.OrganizationService`); use
   `ctx.SystemService` / `ctx.AsSystem()` only when elevation is required.
6. Guard the trigger via the registered **filtering attributes** (`FilterOn(e => e.X)`) and
   the correct **image**, not loose re-checks in code. Add an image in `RegisterPluginSteps`
   if the handler needs prior/final values. Respect the legal matrix
   (`references/registration-rules.md`): no post-image on Delete, no pre-image on Create,
   Async only at PostOperation. A plugin that registers any `WithPreImage`/`WithPostImage` must be
   declared `partial`: the typed image projection is generated inside it, so without it the build
   fails with **`CS0260`** ("missing partial modifier"; analyzer rule VELA014). This is your authored
   plugin class, so add `partial` yourself (`public sealed partial class ...`).
7. **SOLID / DRY.** Keep `OnExecute` thin (SRP): orchestration in the handler, real logic in a
   **service** when it is reusable or worth testing in isolation → `vela add service <Name>
   --entity <E>`, injected via DI. Reuse an existing service or plugin before adding one; do not
   duplicate logic. Do not extract a service for a trivial one-liner. Follow the generated
   **naming** conventions (prefix, `OnExecute`, project layout); don't rename generated members.

## Rationalizations (excuse → rebuttal)

- "I'll use the attribute logical-name string." → Use the generated model property; a typo in
  a string is a runtime bug, a wrong property is a compile error. If the attribute isn't in the
  model, run `vela-models` - don't reach for a string.
- "`ctx.OrganizationService` to write." → It doesn't exist. Use `ctx.UserService`.
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
- `ctx.OrganizationService`, a hand-written plugin class, or a renamed generated handler
  (`OnExecute` for `add plugin`, `Handle<Message>` for `add step` - both are legitimate).
- Associate/Disassociate matched by primary entity only (won't fire - see gotchas).
- A custom API parameter name containing a dot (uncallable on a real org).
- Logic duplicated across plugins, or a fat `OnExecute` that should delegate to a service.
- An illegal registration attempted (post-image on Delete, Async off PostOperation) - see registration-rules.

## Verification

- `dotnet build` is green.
- There is a `vela-test-harness` test covering the new behaviour, and it passes. Authoring is
  not "done" until the harness proves the behaviour.
