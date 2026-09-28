---
scenario: contact-association
skills_exercised: [vela-plan-review, vela-scaffold, vela-plugin-authoring, vela-test-harness, vela-code-review]
entity: contact
message: Associate
gotchas_exercised: [associate-matched-by-message, relationship-name, pipeline-for-firing]
org_required: false
---

# Scenario: react to an association

## User story
"When a Contact is linked to a Marketing List, stamp the contact's Description with 'In a marketing
list'."

## What the skills must get right
- **Associate is a message, not an entity event:** the step is registered on the **Associate** message
  and must not be matched by primary entity alone (the classic "never fires" gotcha); the handler checks
  the **relationship name** and the entity types of the target / related entities before acting.
- The write goes to the contact (another record than the one the step is registered on, or not):
  stage and Sync/Async are decided with a reason; no recursion.
- Tests: the step fires on an association of the right relationship and does nothing for another
  relationship - proven with `PluginPipeline` (or the harness's association support) rather than a bare
  `Execute`, which does not prove firing.

## Success criteria (a clean pass)
1. Canvas records message = Associate, the relationship name, and why the handler filters on it.
2. RED then GREEN: right relationship → description stamped; other relationship → untouched.
3. Build clean of VELA00x; `vela-code-review` PASS.
