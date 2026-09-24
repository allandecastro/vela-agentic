---
name: vela-plan-review
description: Model-invoked. Use right after interpreting a user story, before scaffolding. Self-grill the plan against the Dataverse gotchas until every branch resolves, then emit the Plan artifact. Advisory gate — flag unresolved assumptions and continue.
---

# Review the plan (self-grilling)

Before building anything, interrogate your own plan until every branch resolves. This is the
front gate: it catches a mis-interpreted story before a wasted build. It is **advisory** — you
flag unresolved assumptions and continue; you do not block.

## When to use

- Right after Intake (story → interpreted spec), before `vela-scaffold`.

## Process

Announce: `Using vela-plan-review to grill the plan`.

1. State the interpreted spec: entity, message, stage, mode, attributes read/written.
2. **Grill it** — answer each question; an unanswered one becomes an assumption or open question:
   - **Message/stage/mode:** Is the message right (Create vs Update vs *Multiple)? Is the stage
     right (PostOperation to see committed values; Pre to change the write)? Sync or Async?
   - **Trigger:** Which filtering attribute actually gates this? Will it fire only when intended?
   - **Images:** Do you need prior values (pre-image) or final values (post-image)? Registered?
   - **Association:** If it's Associate/Disassociate, are you matching the message regardless of
     primary entity? (Matching by entity alone never fires — see `references/dataverse-gotchas.md`.)
   - **Models:** Does every attribute exist in the generated model, or must you run `vela-models`?
   - **Custom API:** Any parameter name with a dot? (Uncallable on a real org.)
   - **Ambiguity:** Is "empty", "changed", "valid" defined? What are the edge cases?
3. **Emit the Plan artifact** (`references/build-report-template.md`): spec, the grilling Q&A,
   assumptions, open questions, proposed approach, risks.
4. Flag the assumptions in one line to the user and **continue** to `vela-scaffold`.

## Rationalizations (excuse → rebuttal)

- "The story is clear enough." → Grill it anyway; the cost is a paragraph, the payoff is not
  building the wrong thing.
- "I'll figure out images/filtering while coding." → Decide them now; they change the
  registration, which changes the scaffold.

## Red flags

- Any grilling branch left unanswered and not recorded as an assumption or open question.
- Proceeding without a Plan artifact.

## Verification

- A Plan artifact exists with every grilling branch either resolved or logged as an
  assumption/open question, and the assumptions were surfaced to the user.
