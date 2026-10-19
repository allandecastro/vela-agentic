---
name: vela-grill
description: Use when a user story is ambiguous or underspecified and only the human can resolve it before building (also run by a human as /vela-grill).
compatibility: "vela CLI + dotnet SDK."
---

# Grill the story (interview the human)

> Paths like `references/<file>.md` in this skill are relative to **this skill's folder** (the
> directory containing this `SKILL.md`), not to the project you are working in.

Interview the human until no branch of a vague story is unresolved. Interactive sibling of
`vela-plan-review`.

## When to use

- The user asks for `/vela-grill`, or Intake surfaced ambiguity that assumptions can't safely close.

## Process

Announce: `Using vela-grill to resolve the story`.

1. Restate the story and name the entity/message you think it implies.
2. Ask **one focused question at a time** (multiple choice, one-line answer), roughly in this order,
   skipping what the story answers. Only **business decisions** go to the human; platform facts are
   yours (or assumptions). A business value nobody raised (e.g. which Inactive status reason) may take the
   platform default as an assumption. Ask every edge value that changes an acceptance case (scope,
   empty/malformed input) before ending; a one-line edge follow-up may ride along, never two independent
   decisions.
   - Meaning: which column/table (standard or custom) does each story term mean?
   - Direction: which record drives the change, which is written, via which lookup/relationship?
   - Trigger: which message, which attribute? Do **other events** (delete, re-parent, bulk) reach the
     same outcome - in scope?
   - Timing: Sync (blocks the user, rolls back together - even at PostOperation) or Async (never blocks,
     fails on its own)? State each consequence in the question.
   - Data: exact values read and written; defaults and edge cases.
   - Security context: calling user (default) or elevated?
   - A message the user sees: which languages, and where the texts live (project convention) - never
     assumed; no default covers it.
   - Target solution unique name, if unknown (never invented). Not the publisher prefix:
     `vela solution show <uniquename> --json` reads it; ask only if that fails.
   - Definition of done: only if not derivable; otherwise state it back.
   Stop once every branch that changes the registration or the acceptance cases is resolved.
3. Record answers in the Vela Canvas (`references/build-report-template.md`) as the human's decisions;
   platform facts (`references/registration-rules.md`, `references/dataverse-gotchas.md`) go under
   `assumptions:`.
4. Hand back to `vela-plan-review` to finish the Canvas, then continue (`vela-scaffold`).

## Rationalizations (excuse → rebuttal)

- "I'll assume and move on." → Assumptions belong to `vela-plan-review`; this skill runs because the
  human must decide. Ask.
- "Too many questions annoys the user." → One at a time, each load-bearing. Vague builds annoy more.

## Red flags

- Broad open questions instead of load-bearing ones tied to the registration.
- Ending the interview with a branch still unresolved.

## Verification

- The Canvas has no unresolved branch; every **business decision** came from the human (marked as
  such); only platform facts are assumptions.
