---
name: vela-plugin-authoring
description: Use when implementing the logic of a Vela plugin, after scaffolding, models, and the failing (RED) harness tests exist.
---

# Author a Vela plugin

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

1. Re-read the spec: message, stage, mode; which attributes are read/written.
2. **Model first for any non-demo attribute.** The scaffold's generated model only covers
   demo columns (and is `sealed` — no partial extension). If the story touches any other
   attribute, run `vela-models` first — do not fall back to a magic string. MODEL precedes
   IMPLEMENT for this reason. **No-org exception (evals/rehearsals only):** when `vela-models`
   genuinely cannot run, hand-add just the needed typed property with an explicit
   `// STAND-IN for vela-models (no org)` comment; this is a documented rehearsal shim, never a
   pattern for a real run (which has an org and regenerates the model properly).
3. Open the generated `OnExecute(I<Message>PostContext<Entity> ctx)` method (the handler is
   `OnExecute`, not `Handle<Message>`). Do not create a parallel class by hand.
4. Read with the typed helpers: `ctx.GetTarget<Entity>()`, `ctx.GetPreImage<Entity>()`,
   `ctx.GetPostImage<Entity>()` — never magic-string attribute names where a model exists.
5. Write through `ctx.UserService` (there is **no** `ctx.OrganizationService`); use
   `ctx.SystemService` / `ctx.AsSystem()` only when elevation is required.
6. Guard the trigger via the registered **filtering attributes** (`FilterOn(e => e.X)`) and
   the correct **image**, not loose re-checks in code. Add an image in `RegisterPluginSteps`
   if the handler needs prior/final values.

## Rationalizations (excuse → rebuttal)

- "I'll use the attribute logical-name string." → Use the generated model property; a typo in
  a string is a runtime bug, a wrong property is a compile error. If the attribute isn't in the
  model, run `vela-models` — don't reach for a string.
- "`ctx.OrganizationService` to write." → It doesn't exist. Use `ctx.UserService`.
- "I'll add a second plugin class for another message." → Use `vela add step` on the existing
  plugin so registration stays in sync.
- "Target is enough, images are overkill." → For Update/Delete you often need prior values;
  read the correct image (and register it).

## Red flags

- Magic-string attribute names where a generated model exists (or should, via `vela-models`).
- `ctx.OrganizationService`, `.Handle<Message>`, or a hand-written plugin class.
- Associate/Disassociate matched by primary entity only (won't fire — see gotchas).
- A custom API parameter name containing a dot (uncallable on a real org).

## Verification

- `dotnet build` is green.
- There is a `vela-test-harness` test covering the new behaviour, and it passes. Authoring is
  not "done" until the harness proves the behaviour.
