---
name: vela-plugin-authoring
description: Use when writing the actual logic of a Vela plugin or custom API handler — after scaffolding and model generation. Covers the plugin handler shape, using generated models, images, and the Dataverse pitfalls to avoid.
---

# Author a Vela plugin

Write the logic of a plugin or custom API handler, after `vela-scaffold` and `vela-models`.
Keep generated files untouched; put logic in the handler the scaffold created.

## When to use

- The scaffold and models exist and you now need to implement the behaviour from the spec.

## Process

Announce: `Using vela-plugin-authoring to <purpose>`.

1. Re-read the spec: which message, stage, and mode? Which attributes are read/written?
2. Open the handler method the scaffold generated (e.g. `Handle<Message>`). Do not create a
   parallel class by hand.
3. Use the **generated early-bound models** for the target and images — never magic strings
   for attribute names.
4. Read from the correct **image** (pre-image for prior values, post-image for final), and
   make sure the image is actually registered for that attribute (see gotchas).
5. Guard the trigger: if the logic should only run when an attribute changed, rely on the
   registered **filtering attributes** rather than re-checking loosely in code.
6. Keep it deterministic and side-effect-light; do not call out to a live org from logic
   that the harness will exercise.

## Rationalizations (excuse → rebuttal)

- "I'll use the attribute logical name as a string." → Use the generated model property; a
  typo in a string is a runtime bug, a wrong property is a compile error.
- "I'll add a second plugin class for the extra message." → Use `vela add step` on the
  existing plugin so registration stays in sync.
- "I'll just read Target, images are overkill." → For Update/Delete you often need prior
  values; read the correct image.

## Red flags

- Magic-string attribute names where a generated model exists.
- Logic that assumes an image that was never registered.
- Associate/Disassociate handling matched by primary entity only (see gotchas — it won't fire).
- A custom API parameter name containing a dot (uncallable on a real org).

## Verification

- `dotnet build` is green.
- There is a `vela-test-harness` test covering the new behaviour, and it passes. Authoring
  is not "done" until the harness proves the behaviour.
