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
- **Associate is a message-level registration:** Dataverse's only message filter for Associate is
  primary entity `none` (verified on the dev org). Vela 0.29.3 binds every `OnAssociate()` step to the
  plugin's table and `vela plan` does not flag it (verified, 2026-09-29).
- So the correct outcome **today** is to recognise the framework limit at plan-review, record the story
  as **blocked (framework limit)** in the Canvas with the evidence, and **not** scaffold or ship a
  per-table workaround. The agent also asks whether the story really means Associate (marketing-list
  members may come through `AddMember` / `AddListMembers`).
- When Vela supports message-level Associate registration, this scenario flips back to a build:
  relationship-name check, a `PluginPipeline` test per direction, review PASS.

## Success criteria (a clean pass, current Vela)
1. The Canvas names the limit (message filter `none` vs Vela's table binding) and marks the story
   blocked, with the AddMember question as an open question.
2. No plugin is scaffolded or packaged; nothing is proposed for apply.
3. The hand-off to the human says what Vela needs (message-level Associate registration) - reported,
   not worked around.

## Human answers (evaluator only - never shown to the acting agent)
- Contacts are added to static marketing lists from the list's "Add members" and from code; nobody knows which message the UI raises.
- Target solution / publisher prefix: `ZavaSales` / `zava`.
- Anything not listed: "Use the skills' defaults and record it as an assumption."
