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
- The evaluator plays the human and answers only what is asked, one answer per question:
  - "sync" means: when a Contact's `statecode` becomes Inactive, and **all** the account's contacts are
    then inactive, set the parent Account inactive too;
  - only then, never the other way round; it must be visible immediately (same transaction);
  - target solution `ZavaSales`, publisher prefix `zava`;
  - done = the account becomes inactive when its last active contact is deactivated, and stays active
    otherwise.
- No org, no `vela apply`. Stop after the Vela Canvas (this scenario tests the front of the loop).

## What the skills must get right
- `vela-plan-review` finds branches it cannot resolve by assumption (which entity triggers, direction,
  what "status" means, sync vs async) and routes to **`vela-grill`** instead of guessing.
- `vela-grill` asks **one load-bearing question at a time**, tied to the registration (trigger message
  and entity, timing, data, scope, definition of done) - not a questionnaire, not open-ended chat.
- It asks for the target solution and publisher prefix instead of inventing them.
- The resulting Canvas records the answers as decisions (Contact **Update**, filtered on `statecode`,
  Sync; the "all contacts inactive" rule; writes to **another** record → PostOperation is justified)
  and has no unresolved branch.

## Success criteria (a clean pass)
1. No scaffold or code before the ambiguity is resolved.
2. Every question is answerable in one line and changes the registration or the acceptance cases.
3. The Canvas is complete, every answer is attributed to the human, and the acceptance cases include
   "last active contact deactivated → account inactive" and "another contact still active → account
   unchanged".
