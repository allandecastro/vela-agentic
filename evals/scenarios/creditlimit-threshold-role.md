---
scenario: creditlimit-threshold-role
skills_exercised: [vela-plan-review, vela-models, vela-test-harness, vela-plugin-authoring, vela-code-review, vela-apply]
entity: account
message: Create, Update
gotchas_exercised: [generated-roles, role-root-id, team-roles, configuration-over-code]
org_required: true
---

# Scenario: a value condition on a role - a plugin, with the generated roles

## User story
"A credit limit above 50,000 can only be granted by a sales manager."

## Setup for the run
- The evaluator provides the `ZavaSales` project (`sh evals/setup/baseline.sh <work>` → `<work>/ZavaSales`). The dev
  org `https://dyn-premium-dev.crm.dynamics.com` is available **read-only** (`vela models` / `vela solution show`
  / `vela plan` / `vela inspect` / `vela logs`); never `vela apply`.

## What the skills must get right
- **Code is justified:** the permission depends on the value (above 50,000), which column security cannot express.
- **Generated roles:** `vela models --roles "Sales Manager,Salesperson,System Administrator"` into the Shared
  project; tests use `.Role(Roles.XName, Roles.XId, Roles.X)` - no hand-written role, GUID or privilege list.
- **Root id:** the check compares the caller's roles' `parentrootroleid` to `Roles.SalesManagerId` (a role is
  copied per business unit); roles held through a team count.
- A Sync PreValidation/PreOperation step on Create and Update of `account`, `FilterOn(creditlimit)`; the message in
  French in `Localization/Messages.cs`; tests RED first, each with its case id.

## Success criteria (a clean pass)
1. Roles generated from the org; tests use them; no hand-built role except one named for a missing privilege.
2. `parentrootroleid` in the check; a team-role case and a child-business-unit case tested (or the harness gap
   recorded as a divergence, not encoded).
3. Steps on Create + Update filtered on `creditlimit`; spec-check passes; review PASS; `vela plan` run; no apply.

## Planted-violation check (adversarial)
The review must BLOCK: (a) a role check on `roleid` instead of `parentrootroleid` → **Required**; (b) the Sales
Manager GUID or name written by hand in the plugin → **Required**.

## Human answers (evaluator only - never shown to the acting agent)
- Allowed above 50,000: Sales Managers and System Administrators. Exactly 50,000 is allowed for everyone.
- Applies on create too. Lowering a limit is always allowed. Roles held through a team count.
- Message (French only): "Seul un responsable commercial peut accorder une limite de crédit supérieure à 50 000."
- The role lookup may run as SYSTEM (it reads only the caller's own role assignments; nothing is shown).
- Target solution / publisher prefix: `ZavaSales` / `zava`.
- Anything not listed: "Use the skills' defaults and record it as an assumption."
