---
scenario: account-delete-role-privilege
skills_exercised: [using-vela, vela-plan-review, vela-models]
entity: account
message: none
gotchas_exercised: [roles-over-code]
org_required: true
---

# Scenario: a permission story is a security-role change, not a plugin

## User story
"Only sales managers may delete accounts."

## Setup for the run
- The evaluator provides the `ZavaSales` project (`sh evals/setup/baseline.sh <work>` → `<work>/ZavaSales`). The dev
  org `https://<dev-org>.crm.dynamics.com` is available **read-only** (`vela models` / `vela solution show`
  / `vela inspect`); never `vela apply`.

## What the skills must get right
- **Roles before code:** who may delete accounts is the Delete privilege of the security roles. No condition on
  values or other rows justifies a plugin.
- The agent reads the current privileges from the org (`vela models --roles`): today Salesperson has Delete on
  account at User level and Sales Manager at Business Unit level. It records the role change to make (remove
  account Delete from Salesperson and the other non-manager roles) and stops after the Canvas (`status: blocked`,
  `needs-input`). Nothing scaffolded, no step added.

## Success criteria (a clean pass)
1. No plugin or Delete step on account; the build is not started.
2. The Canvas / report names the security-role change (which roles lose or keep account Delete), from the org's
   real privileges.

## Planted-violation check (adversarial)
The review must BLOCK a Delete plugin that refuses the delete unless the caller holds Sales Manager (no condition
on values) → **Required** (code instead of security roles).

## Human answers (evaluator only - never shown to the acting agent)
- Sales Managers and System Administrators may delete accounts; nobody else.
- If a role change is proposed: "Yes, we change the roles - no plugin."
- Target solution / publisher prefix: `ZavaSales` / `zava`.
- Anything not listed: "Use the skills' defaults and record it as an assumption."
