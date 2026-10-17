---
name: vela-plugin-authoring
description: Use when implementing the logic of a Vela plugin, after scaffolding, models, and the failing (RED) harness tests exist.
compatibility: "vela CLI >= 0.26.2 (Vela.Plugins >= 0.37.0); dotnet SDK."
---

# Author a Vela plugin

> Paths like `references/<file>.md` in this skill are relative to **this skill's folder** (the
> directory containing this `SKILL.md`), not to the project you are working in.

Write the plugin logic in the handler the scaffold created, in the scaffolded plugin file (yours). Never
touch generated files (`Models/Generated`). **Read `references/plugin-authoring-api.md` before writing
code** - it has the shape; this is the workflow.

## When to use

- Scaffold, models and the **failing (RED) harness tests** exist; you now implement to **green**. Not
  before the tests are written and seen to fail (`vela-test-harness`).

## Process

Announce: `Using vela-plugin-authoring to <purpose>`.

1. Re-read the **Vela Canvas** (Operations, Approach, Structure, Norms): implement exactly those
   Operations, honour the Approach decisions - no scope creep.
2. **Model first.** Every table/column the story touches is in the generated model (`vela-models`)
   before the RED tests - no magic strings, never hand-edit `Models/Generated`. No org →
   `vela models --from-solution`, or surface the blocker.
3. Keep the generated handler name: `OnExecute` (`vela add plugin`) or `Handle<Message>` / the
   `--handler` name (`vela add step`). No parallel class or handler by hand.
4. Read through the typed context: `ctx.Request.Target` (PreOperation: set properties on it to change what
   is written; Async: a Target write is lost, VELA018), `ctx.PreImage` / `ctx.PostImage` for registered
   images.
5. Write through **`ctx.Service`** (the step's user; `ctx.OrganizationService` / `ctx.UserService` do not
   exist). `ctx.SystemService` only when elevation is recorded in the Canvas. Secrets via
   `.WithSecureConfigFrom("Name")`, never code or unsecure config.
6. Guard the trigger with **`FilterOn`** and the right **image** (register it in `RegisterPluginSteps`),
   not loose re-checks in code; respect the legal matrix (`references/registration-rules.md`). Keep the
   class `partial` (VELA014). Associate/Disassociate: `.ForRelationship("<schema name>")` and check
   `ctx.Request.Target.LogicalName` (either side can be the Target).
7. **SOLID / DRY.** Thin handler; real/reusable logic in a service (`vela add service <Name> --entity <E>`,
   DI). Reuse before adding; no service for a one-liner (steps of one plugin share a private helper holding
   the rule, each step's guard wraps the call; plugins share a service). Keep generated naming.

## Rationalizations (excuse → rebuttal)

- "I'll use the attribute logical-name string." → A string typo is a runtime bug, a wrong property a
  compile error. Missing from the model → `vela-models`.
- "`ctx.OrganizationService` / `ctx.UserService` to write." → Neither exists. `ctx.Service`.
- "`SkipWhenDepthAbove(1)` stops the recursion." → It skips the second run; the write still happens
  twice. Fix the cause (PreOperation Target edit, or written column out of `FilterOn`).
- "A second plugin class for another message." → `vela add step` on the existing plugin.
- "Target is enough, images are overkill." → Update/Delete often need prior values; register and read
  the image.
- "I'll copy the logic from the other plugin." / "Everything in OnExecute is simpler." → DRY/SRP:
  extract or reuse a service.

## Red flags

- Magic-string attribute names where a generated model exists (or should).
- `ctx.OrganizationService` / `ctx.UserService`, a hand-written plugin class, or a renamed generated
  handler (`OnExecute` and `Handle<Message>` are both legitimate).
- An Associate/Disassociate step without `ForRelationship(...)` (runs for every association).
- A custom API parameter name that is not a plain identifier.
- Duplicated logic across plugins, or a fat `OnExecute` that should delegate to a service.
- A PostOperation `ctx.Service.Update` of the triggering record (use PreOperation + Target), or a
  write-back whose column is in the step's `FilterOn` (recursion). A PreOperation Target edit is not a
  write-back: filtering on the column you normalise there is correct.
- A mutable plugin field (VELA011), a secret in code or unsecure config, or `ctx.Depth` /
  `.SkipWhenDepthAbove(n)` without a recorded reason (`references/dataverse-gotchas.md`).
- An illegal registration attempted (post-image on Delete, Async off PostOperation).

## Verification

- `dotnet build` green with no VELA diagnostic in authored code (warnings fail the gate too).
- A `vela-test-harness` test covers the new behaviour and passes; not "done" until the harness proves it.
