---
scenario: contact-association
skills_exercised: [vela-plan-review, vela-grill, vela-scaffold, vela-plugin-authoring, vela-test-harness, vela-code-review, vela-apply]
entity: contact
message: Associate
gotchas_exercised: [associate-matched-by-message, relationship-scope, either-side-target, pipeline-for-firing]
org_required: true
---

# Scenario: react to an association

## User story
"When a Contact is linked to a Lead, stamp the contact's Description with 'Linked to a lead'."

## Setup for the run
- The evaluator gives you a work dir. `vela` and `dotnet` on PATH. The dev org
  `https://dyn-premium-dev.crm.dynamics.com` is available **read-only** (`vela models` / `vela solution show` /
  `vela plan` / `vela inspect` / `vela logs`); never `vela apply`.

## What the skills must get right
- **Associate is a message-level registration** (Vela >= 0.33: `OnAssociate()` registers with no primary
  table) **scoped to the relationship** with `ForRelationship(...)` - the contact-lead N:N
  (`contactleads_association`, read from the org metadata or asked, not guessed). An unscoped Associate step
  fires on every N:N association in the org (Required finding).
- **Either side can be the Target:** linking from the lead side makes the lead the Target and the contact a
  related entity. The handler finds the contact on whichever side it is.
- **Writes another record:** Associate has no Target entity to edit, so the stamp is a `ctx.Service.Update`
  of the contact (PostOperation, Sync) - no recursion (an Update of the contact does not raise Associate).
- **Tests:** `PluginPipeline` with the N:N declared (`WithManyToMany`), one test per direction (contact side,
  lead side), plus an association through **another** relationship that must not stamp
  (`HandlerInvoked == false` or no write).
- Minimal scaffold + `vela models` for contact (and lead); `vela solution show ZavaSales`; `vela plan --solution`.

## Success criteria (a clean pass)
1. Step registered on Associate, message-level, scoped to `contactleads_association`, PostOperation Sync.
2. RED then GREEN: contact side stamps; lead side stamps; other relationship does not stamp.
3. Writes through `ctx.Service`; no elevation without a recorded reason.
4. `vela-code-review` PASS; Build Report with `vela plan --solution ZavaSales` evidence; stops before apply.

## Human answers (evaluator only - never shown to the acting agent)
- The relationship is the standard contact-lead N:N (`contactleads_association`).
- Stamp on every link (also when the description already has text: overwrite it).
- Target solution: `ZavaSales` (publisher prefix `zava`).
- Anything not listed: "Use the skills' defaults and record it as an assumption."

(Rubric note, campaign 2026-10-13: until Vela 0.33 this scenario expected a "blocked - framework limit"
outcome; Vela now supports message-level Associate with `ForRelationship`, so it is a build.)
