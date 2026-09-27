---
scenario: account-multi-step
skills_exercised: [vela-plan-review, vela-scaffold, vela-plugin-authoring, vela-test-harness, vela-code-review]
entity: account
message: Create + Update
gotchas_exercised: [add-step-handler-naming, vela001-placeholder, multi-step-harness-trigger, stage-choice]
org_required: false
depends_on: account-default-description
---

# Scenario: add a second step to an existing plugin

## Context
`AccountDefaultDescription` exists (single-step Create, PreOperation, handler `OnExecute`).

## User story
"Also on update: when an Account's Name changes, uppercase its account number."

## What the skills must get right
- **Reuse:** `vela add step AccountDefaultDescription --entity Account --message Update` - not a new
  plugin, not a hand-written step.
- **Generated handler:** the new handler is `HandleUpdate` (`Handle<Message>`); the agent keeps it and
  keeps `OnExecute` for the Create step - neither is renamed.
- **Placeholder:** the generated `FilterOn(e => e.Id /* TODO */)` fails the build with **VELA001**; the
  agent replaces it with `e => e.Name` (the column whose change gates the step).
- **Stage:** PreOperation on `ctx.Request.Target` (same-record column).
- **Harness:** the plugin is now multi-step, so every test states its trigger (`.OnCreate()` /
  `.OnUpdate()` + stage); the existing Create tests are updated accordingly and stay green.

## Success criteria (a clean pass)
1. The Canvas records `reuse: add-step:AccountDefaultDescription` and the Update step.
2. Build fails first on VELA001 (seen and fixed), then green with no VELA00x in authored code.
3. RED then green: name changed → account number uppercased; name unchanged (filter) → step not run;
   the Create cases still pass.
4. `vela-code-review` PASS.
