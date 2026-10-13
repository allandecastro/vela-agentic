---
scenario: ambiguous-story-grill
skills_exercised: [vela-grill, vela-plan-review, using-vela]
entity: account
message: unknown (to resolve)
gotchas_exercised: [ambiguity-before-build, one-question-at-a-time, no-invented-prefix]
org_required: false
---

# Scenario: a story too vague to build

## User story
"Accounts should keep their status in sync with their contacts."

## Setup for the run
- A human is reachable only through the evaluator (ask one question per turn).
- The dev org `https://dyn-premium-dev.crm.dynamics.com` is available **read-only** (`vela models` / `vela solution show` / `vela plan` / `vela inspect` / `vela logs`); never `vela apply`. No `vela apply`. The run ends once the Vela Canvas is complete (no scaffold in this scenario).

## Human answers (evaluator only - never shown to the acting agent)
- "sync" means: when a Contact's `statecode` becomes Inactive and **all** the account's contacts are then
  inactive, set the parent Account inactive too; never the other way round; never reactivate.
- Contacts count through `parentcustomerid` (Company Name); only deactivation triggers the check.
- Visible immediately (same transaction); as the calling user; default Inactive status reason.
- Target solution `ZavaSales`, publisher prefix `zava`.
- Anything else: "Use your judgement and record it as an assumption."

## What the skills must get right
- `vela-plan-review` finds branches it cannot resolve by assumption (which entity triggers, direction,
  what "status" means, sync vs async) and routes to **`vela-grill`** instead of guessing.
- `vela-grill` asks **one load-bearing question at a time**, tied to the registration (trigger message
  and entity, timing, data, scope, definition of done) - not a questionnaire, not open-ended chat.
- It asks for the target solution instead of inventing it (the publisher prefix then comes from
  `vela solution show <solution>`, read-only; asking for both is also fine).
- The resulting Canvas records the answers as decisions (Contact **Update**, filtered on `statecode`,
  Sync; the "all contacts inactive" rule; writes to **another** record → PostOperation is justified)
  and has no unresolved branch.

## Success criteria (a clean pass)
1. No scaffold or code before the ambiguity is resolved.
2. Every question is answerable in one line and changes the registration or the acceptance cases.
3. The Canvas is complete, every answer is attributed to the human, and the acceptance cases include
   "last active contact deactivated → account inactive" and "another contact still active → account
   unchanged".
