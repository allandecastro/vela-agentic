---
name: vela-plan-review
description: Use right after interpreting a user story and before scaffolding, when the plan needs pressure-testing before any code is written.
compatibility: "vela CLI >= 0.19.6 (Vela.Plugins >= 0.28.2); dotnet SDK."
---

# Review the plan (self-grilling)

> Paths like `references/<file>.md` in this skill are relative to **this skill's folder** (the
> directory containing this `SKILL.md`), not to the project you are working in.

Before building anything, interrogate your own plan until every branch resolves. This is the
front gate: it catches a mis-interpreted story before a wasted build. It is **advisory** - you
flag unresolved assumptions and continue; you do not block.

## When to use

- Right after Intake (story → interpreted spec), before `vela-scaffold`.

## Process

Announce: `Using vela-plan-review to grill the plan`.

1. State the interpreted spec: entity, message, stage, mode, attributes read/written.
2. **Grill it** - answer each question; an unanswered one becomes an assumption or open question:
   - **Message/stage/mode:** Is the message right (Create vs Update vs *Multiple)? Is the stage
     right? Changing a column of the same record → **PreOperation**, set on `ctx.Request.Target` (no
     extra write, nothing re-triggered). PostOperation only for the committed id, other records, or
     the saved result. PostOperation + an `Update` of the same record needs a written reason.
   - **Recursion:** does anything this plugin writes re-trigger it (its own filtering attributes, or
     another plugin on the same table)? See the recursion gotcha in `references/dataverse-gotchas.md`.
   - **Approach - Sync vs Async:** Sync when the effect must be seen/validated in the same
     transaction; Async only for non-blocking, slow, external, eventual work (PostOperation-only).
     Default Sync; justify Async. (See `references/registration-rules.md`.)
   - **Approach - reuse vs new:** New plugin (no class) → `vela add plugin` then code. Behaviour on
     a table that already has a plugin → prefer `vela add step`. Reuse an existing plugin/service;
     never duplicate; never hand-create a class.
   - **Structure - service?** Keep the handler thin (SRP). Real/reusable logic → a service
     (`vela add service`) injected via DI; reuse an existing one; don't extract for a one-liner.
   - **Structure - target solution & publisher:** which **unmanaged solution** (unique name) do
     components go into, and its **publisher prefix**? It must already exist (Vela doesn't create
     it), and the scaffold `--prefix` must match that publisher prefix. Record both in the Canvas
     (see `references/registration-rules.md`).
   - **Trigger:** On Update, which filtering attribute gates this? On Create/Update a `FilterOn`
     is **mandatory** (registration throws without one); on Create it's ignored at runtime, so keep
     the primary column and never drop it.
   - **Images / legality:** Pre-image or post-image needed, and registered? Check the legal matrix
     (`registration-rules.md`): no post-image on Delete, no pre-image on Create, Async = PostOp only.
   - **Association:** Associate/Disassociate matched by **message**, not primary entity (else never fires).
   - **Models:** Does every attribute exist in the generated model, or must you run `vela-models`?
   - **Norms:** Naming per generated conventions + prefix; SOLID/DRY intent.
   - **Acceptance cases:** Turn the DoD into concrete test cases - primary behaviour, each edge,
     each applicable gotcha. These become the RED tests.
3. **Fill the Vela Canvas** (`references/build-report-template.md`): the seven REASONS-adapted
   sections (R Requirements/DoD · E Entities · A Approach · S Structure · O Operations · N Norms ·
   S Safeguards), with the acceptance cases, assumptions and open questions. Keep it proportional -
   one line per section for a simple story.
4. Flag the assumptions in one line to the user and **continue** to `vela-scaffold`.

## Rationalizations (excuse → rebuttal)

- "The story is clear enough." → Grill it anyway; the cost is a paragraph, the payoff is not
  building the wrong thing.
- "I'll figure out images/filtering while coding." → Decide them now; they change the
  registration, which changes the scaffold.

## Red flags

- Any grilling branch left unanswered and not recorded as an assumption or open question.
- Proceeding without a Vela Canvas, or a Canvas whose Approach/Structure leave Sync-vs-Async or
  reuse-vs-new undecided.

## Verification

- A Vela Canvas exists with all seven sections filled (proportional), every grilling branch
  resolved or logged, and the assumptions surfaced to the user.
