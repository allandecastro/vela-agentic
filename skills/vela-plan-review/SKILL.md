---
name: vela-plan-review
description: Use right after interpreting a user story and before scaffolding, when the plan needs pressure-testing before any code is written.
compatibility: "vela CLI >= 0.21.4 (Vela.Plugins >= 0.29.1); dotnet SDK."
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
   - **Step or Custom API?** A reaction to a table event (create/update/delete...) is a plugin step. An
     operation someone *calls* with inputs and outputs is a Custom API → `vela-custom-api`.
   - **Message/stage/mode:** Is the message right (Create vs Update vs *Multiple)? Wording like "set or
     changed" can cover **Create** too (a value set on a new record) - decide both, or ask (`vela-grill`). Is the stage
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
     Shared by the steps of one plugin → private helper; across plugins → service.
   - **Structure - outbound integration?** Does the behaviour call another system (HTTP API, queue,
     Azure service, e-mail gateway...)? Yes → that code goes in the scaffold's **Integrations** project
     (its own package; usually an Async step - see Sync vs Async). No outbound flow → the solution is
     scaffolded with `--no-integrations`. Record the answer in the Canvas (Structure).
   - **Structure - target solution & publisher:** which **unmanaged solution** (unique name) do
     components go into, and its **publisher prefix**? It must already exist (Vela doesn't create
     it), and the scaffold `--prefix` must match that publisher prefix. Record both in the Canvas
     (see `references/registration-rules.md`). **Not in the story and no org to read it from?** It
     names the projects, so ask the human once before scaffolding if one is available (`vela-grill`);
     otherwise scaffold with a flagged assumption - a placeholder that can't pass for real, e.g.
     `--prefix tbd` - list it as an open question, and state in the Gate
     that apply is blocked until the prefix and solution are confirmed.
   - **"When X changes" on Update:** a filtering attribute fires whenever the column is *sent*, even
     with the same value. Record whether the behaviour needs the value to actually differ (compare with
     `ctx.PreImage`) and write only when it changes. A PreOperation edit of `ctx.Request.Target` is not a
     write: re-assigning the same value there costs nothing, so no compare is needed.
   - **Trigger:** On Update, which filtering attribute gates this? On Create/Update a `FilterOn`
     is **mandatory** (registration throws without one); on Create it's ignored at runtime, so it
     can never be dropped; default it to the primary column (another column is harmless there - Nit).
   - **Images / legality:** Pre-image or post-image needed, and registered? Check the legal matrix
     (`registration-rules.md`): no post-image on Delete, no pre-image on Create, Async = PostOp only.
   - **Association:** Associate/Disassociate need a message-level registration (primary entity `none`),
     which Vela 0.29.3 cannot express - record the story as **blocked (framework limit)** and stop; see
     `references/dataverse-gotchas.md`. Which message the story really means (Associate, or
     marketing-list `AddMember` / `AddListMembers`, or dynamic lists that raise no event) is a question
     for the human - ask it (`vela-grill`) or list it as an open question; the pack has no recipe for the
     marketing-list messages yet, so that path is blocked too.
   - **Bulk:** `*Multiple` vs single-record message - one of them, never both for the same logic
     (merged pipelines); record why. A story scoped to "bulk updates" can't stay bulk-only: the step
     also runs for single Updates - that is a scope point for the human to confirm, listed at the Gate.
   - **Models:** Does every attribute exist in the generated model, or must you run `vela-models`?
   - **Norms:** Naming per generated conventions + prefix; SOLID/DRY intent.
   - **Acceptance cases:** Turn the DoD into concrete test cases - primary behaviour, each edge,
     each applicable gotcha. These become the RED tests. Include what `vela-test-harness` will
     require anyway: on Update, "column not sent" vs "column cleared"; a `PluginPipeline` case when
     the step must (not) fire or could re-trigger itself. **Every assumption that changes behaviour**
     (e.g. "whitespace-only means empty") is also an acceptance case.
3. **Fill the Vela Canvas** (`references/build-report-template.md`): the seven REASONS-adapted
   sections (R Requirements/DoD · E Entities · A Approach · S Structure · O Operations · N Norms ·
   S Safeguards), with the acceptance cases, assumptions and open questions. Keep it proportional -
   one line per section for a simple story.
4. Flag the assumptions in one line to the user and **continue** to `vela-scaffold` - unless a branch
   is a **business decision only the human can make** (what a story term means, which record drives
   which, the rule itself): then use `vela-grill` first, and resume here with the answers. No human
   reachable (e.g. an unattended run)? Continue on a flagged assumption, listed as an open question
   that blocks the apply gate. A **blocked** outcome (framework limit, story not deliverable) always
   wins over "continue": set the Canvas `status: blocked` and stop (see the builder's "Blocked stories").

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
