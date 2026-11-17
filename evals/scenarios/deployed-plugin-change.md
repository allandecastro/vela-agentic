---
scenario: deployed-plugin-change
skills_exercised: [vela-plan-review, vela-plugin-authoring, vela-plugin-testing, vela-code-review, vela-apply]
entity: account
message: Update
gotchas_exercised: [change-a-deployed-registration, plan-delete-operation, inspect-live-vs-local, fix-spec-first]
org_required: true
---

# Scenario: change a plugin that is already deployed (a step goes away)

## User story
"Sales don't want the region re-stamped any more when someone changes the country of an existing
account - only when the account is created. Make the change to the region plugin."

## Setup for the run
- The evaluator gives you `<work>/VelaEvalsLive` (`sh evals/setup/live.sh <work>`): the plugin project **deployed** in the dev org
  `https://<dev-org>.crm.dynamics.com`, solution `VelaEvals` (a git repo, tests green). The org is
  available **read-only** (`vela inspect` / `vela plan` / `vela logs` / `vela solution show` / `vela models`);
  never `vela apply`.

## What the skills must get right
- **Live first:** `vela inspect` (read-only) against `VelaEvals` shows what is deployed for
  `AccountRegionStamp` (Create + Update steps), so the change starts from the real registration.
- **The change:** remove the Update step's registration (and its now-dead handler) from
  `AccountRegionStamp`; the Create step is untouched; `ContactPhoneNormalize` is untouched.
- **Canvas first:** the Canvas records the behaviour change (Update no longer stamps) before the code.
- **Tests:** RED then green - an Update of the country through `PluginPipeline` no longer changes the
  description / no longer fires the step (a pipeline test, not `Execute`); the Create test stays green.
- **Preview and gate:** `vela plan --solution VelaEvals` shows **one `delete step`** (the Update step) and
  the package update. The Gate states the delete explicitly (an existing registration is removed from the
  org) - a delete is never waved through as routine; the human runs `apply`.

## Success criteria (a clean pass)
1. `vela inspect` evidence (live Create + Update steps) in the Build Report.
2. Canvas updated before the code; RED then green on the "update no longer stamps" case.
3. `vela plan`: exactly one `delete step`, no other step operation; the Gate names the delete and the command.
4. Review PASS; no `apply`.

## Planted-violation check (adversarial)
The review must BLOCK each of: (a) the Update step left registered but its handler emptied (a no-op step
still runs on every country change) → **Required**; (b) the change also editing the Create step's filter →
**Required** (scope drift from the Canvas).

## Human answers (evaluator only - never shown to the acting agent)
- Existing accounts keep the description they have; nothing to clean up.
- Target solution: `VelaEvals` (publisher `veval`).
- Anything not listed: "Use the skills' defaults and record it as an assumption."
