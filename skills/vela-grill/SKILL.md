---
name: vela-grill
description: Use when a user story is ambiguous or underspecified and only the human can resolve it before building (also run by a human as /vela-grill).
compatibility: "vela CLI >= 0.25.0 (Vela.Plugins >= 0.34.0); dotnet SDK."
---

# Grill the story (interview the human)

> Paths like `references/<file>.md` in this skill are relative to **this skill's folder** (the
> directory containing this `SKILL.md`), not to the project you are working in.

Interview the human: when a story is too vague to build safely, grill the human until the
plan has no unresolved branch. This is the interactive sibling of `vela-plan-review` (which
grills the plan itself); use this one when only the human can resolve the ambiguity.

## When to use

- The user asks for `/vela-grill`, or Intake surfaced ambiguity that assumptions can't safely close.

## Process

Announce: `Using vela-grill to resolve the story`.

1. Restate the story in your own words and name the entity/message you think it implies.
2. Ask **one focused question at a time** - preferably multiple choice, answerable in one line - in
   roughly this order, skipping what the story already answers. Only **business decisions** go to the
   human; platform facts (how Dataverse behaves) are yours to know or to record as assumptions. A business
   value nobody raised (e.g. which Inactive status reason) may take the platform default - record it as an
   assumption, don't spend a question on it. Ask every edge value that changes an acceptance case (scope, empty/malformed
   input) before ending the interview - not as a gate question. A one-line edge-case follow-up may ride along with its
   question when the answer stays one line; never bundle two independent decisions.
   - Meaning: which column/table does each story term mean (a standard column or a custom one)?
   - Direction and records: which record drives the change, which is written; how are they related
     (which lookup / relationship)?
   - Trigger: on which message, and only when which attribute changes? Do **other events** reach the
     same outcome (delete, re-parent, bulk) - are they in scope?
   - Timing: inside the user's transaction or after it? Sync (blocks the user, rolls back together - even
     at PostOperation, which is still before the commit) or
     Async (never blocks, fails on its own)? Explain the consequence of each in the question.
   - Data: what exact values are read and written; where do defaults/edge cases go?
   - Security context: as the calling user, or elevated? (Default: calling user.)
   - Target solution unique name, if not known (never invented). Don't ask for the publisher prefix:
     `vela solution show <uniquename> --json` reads it (read-only); ask only if that fails.
   - Definition of done: ask only if it can't be derived from the answers; otherwise state it back.
   Stop as soon as every branch that changes the registration or the acceptance cases is resolved.
3. Record answers in the Vela Canvas (`references/build-report-template.md`), each marked as the
   human's decision; platform facts you relied on go under `assumptions:`. Registration choices use
   `references/registration-rules.md` and `references/dataverse-gotchas.md`.
4. Hand back to `vela-plan-review` to finish the Canvas (grilling the plan with the answers), then
   continue the loop (`vela-scaffold`).

## Rationalizations (excuse → rebuttal)

- "I'll assume and move on." → Assumptions are for `vela-plan-review`'s advisory gate. This
  skill was invoked because the human needs to decide; ask.
- "Too many questions annoys the user." → One at a time, each clearly load-bearing. Vague builds
  annoy more.

## Red flags

- Asking broad open questions instead of load-bearing ones tied to the registration.
- Ending the interview with a branch still unresolved.

## Verification

- The Vela Canvas has no unresolved branch; every **business decision** came from the human (marked
  as such); only platform facts are listed as assumptions.
