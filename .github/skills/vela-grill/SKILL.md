---
name: vela-grill
description: User-invoked (/vela-grill). Use when a user story is ambiguous or underspecified and only the human can resolve it before building.
compatibility: "vela CLI >= 0.19.4 (Vela.Plugins >= 0.28.2); dotnet SDK."
---

# Grill the story (interview the human)

> Paths like `references/<file>.md` in this skill are relative to **this skill's folder** (the
> directory containing this `SKILL.md`), not to the project you are working in.

User-invoked interview: when a story is too vague to build safely, grill the human until the
plan has no unresolved branch. This is the interactive sibling of `vela-plan-review` (which
grills the plan itself); use this one when only the human can resolve the ambiguity.

## When to use

- The user asks for `/vela-grill`, or Intake surfaced ambiguity that assumptions can't safely close.

## Process

Announce: `Using vela-grill to resolve the story`.

1. Restate the story in your own words and name the entity/message you think it implies.
2. Ask **one focused question at a time**, driven by what a correct registration needs:
   - Trigger: on which message, and only when which attribute changes?
   - Timing: before or after the write is committed? Sync (blocks the user) or Async?
   - Data: what exact values are read and written; where do defaults/edge cases go?
   - Scope: single record or bulk (*Multiple)? which security context?
   - Definition of done: how will we know it worked?
3. Keep going until every branch resolves. Record answers in the Vela Canvas
   (`references/build-report-template.md`).
4. Hand off to the build loop (`vela-plan-review` → `vela-scaffold`).

## Rationalizations (excuse → rebuttal)

- "I'll assume and move on." → Assumptions are for `vela-plan-review`'s advisory gate. This
  skill was invoked because the human needs to decide; ask.
- "Too many questions annoys the user." → One at a time, each clearly load-bearing. Vague builds
  annoy more.

## Red flags

- Asking broad open questions instead of load-bearing ones tied to the registration.
- Ending the interview with a branch still unresolved.

## Verification

- The Vela Canvas has no unresolved branch, and every answer came from the human, not an
  assumption.
