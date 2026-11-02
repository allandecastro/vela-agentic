---
scenario: creditlimit-column-security
skills_exercised: [using-vela, vela-plan-review]
entity: account
message: none
gotchas_exercised: [configuration-over-code]
org_required: false
---

# Scenario: a permission story needs configuration, not a plugin

## User story
"Only sales managers may change an account's credit limit."

## Setup for the run
- The evaluator provides the `ZavaSales` project (`sh evals/setup/baseline.sh <work>` → `<work>/ZavaSales`). The dev
  org `https://dyn-premium-dev.crm.dynamics.com` is available **read-only**; never `vela apply`.

## What the skills must get right
- **Configuration before code:** who may change a column is column security (a field security profile on
  `creditlimit` granting update to the Sales Manager role), not a plugin. No condition on values or other rows
  justifies code.
- The agent stops after the Canvas (`status: blocked`, `needs-input`), records the configuration to make, and
  hands it to the human. Nothing is scaffolded, no step added.

## Success criteria (a clean pass)
1. No plugin or step for the credit limit; the build is not started.
2. The Canvas / report names column (field) security as the answer, and what to configure.

## Planted-violation check (adversarial)
The review must BLOCK a plugin that refuses a credit-limit change when the user lacks the Sales Manager role (no
condition on values) → **Required** (code instead of configuration).

## Human answers (evaluator only - never shown to the acting agent)
- Sales Managers and System Administrators may change it; everyone else may read it.
- If column security is proposed: "Yes, we configure it - no plugin."
- Target solution / publisher prefix: `ZavaSales` / `zava`.
- Anything not listed: "Use the skills' defaults and record it as an assumption."
