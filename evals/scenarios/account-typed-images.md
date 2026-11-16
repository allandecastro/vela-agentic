---
scenario: account-typed-images
skills_exercised: [vela-plan-review, vela-scaffold, vela-plugin-authoring, vela-plugin-testing, vela-code-review]
entity: account
message: Update
gotchas_exercised: [typed-image-partial-cs0260, pre-image-compare, value-actually-differs]
org_required: false
---

# Scenario: compare old and new values with a typed pre-image

## User story
"When an Account's credit limit is lowered, set its Description to 'Credit limit reduced'. Raising it or
leaving it unchanged does nothing."

## What the skills must get right
- **Pre-image:** the old value comes from a registered `WithPreImage(e => e.CreditLimit)`, read through
  the typed `ctx.PreImage`; the plugin class is declared **`partial`** (otherwise `CS0260`).
- **"Lowered" means the value actually differs:** compare the sent value with the pre-image; the step
  fires whenever `creditlimit` is sent, even with the same value.
- Stage: the Description is a column of the same record → PreOperation on `ctx.Request.Target`.
- Tests supply the pre-image (`WithPreImage(entity, alias)` / the pipeline) and cover lowered, raised,
  same value, and cleared (null) credit limit.

## Success criteria (a clean pass)
1. The build error `CS0260` is avoided (or seen and fixed) by making the plugin `partial`.
2. RED then GREEN over the four cases; no write when the value did not go down.
3. Build clean of VELA00x; `vela-code-review` PASS.

## Human answers (evaluator only - never shown to the acting agent)
- A cleared (null) credit limit, or a limit set where there was none, is not "lowered".
- Target solution / publisher prefix: `ZavaSales` / `zava`.
- Anything not listed: "Use the skills' defaults and record it as an assumption."
