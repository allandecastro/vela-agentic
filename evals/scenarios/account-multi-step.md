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

## Setup for the run
- The evaluator provides the reviewed `account-default-description` baseline, which already has the
  `AccountDefaultDescription` Create plugin (`sh evals/setup/baseline.sh <work>` → `<work>/ZavaSales`,
  a git repo). The dev org `https://dyn-premium-dev.crm.dynamics.com` is available **read-only** (`vela models` / `vela solution show` / `vela plan` / `vela inspect` / `vela logs`); never `vela apply`.

## User story
"Also on update: when an Account's Name changes, uppercase its account number."

## What the skills must get right
- **Reuse:** `vela add step AccountDefaultDescription --entity Account --message Update` - not a new
  plugin, not a hand-written step.
- **Handler named after the behaviour:** `vela add step ... --handler <OnBehaviour>` (e.g.
  `OnAccountNumberUpper`), not the default `Handle<Message>`; `OnDescriptionDefault` keeps its name.
- **Filter:** the Update step is gated on `e => e.Name` (the column whose change gates the step) - either
  passed up front (`vela add step ... --filtering-attributes Name`, so no placeholder is generated) or by
  replacing the generated `FilterOn(e => e.Id /* TODO */)` placeholder (VELA001) before or after a build
  that shows it; seeing the error is not required. (Rubric note 2026-10-17: the flag route is equally valid.) (Rubric corrected 2026-09-30: it used to require the
  error to be seen, which contradicts vela-scaffold's "align the step before building".)
- **Stage:** PreOperation on `ctx.Request.Target` (same-record column).
- **Harness:** the plugin is now multi-step, so every test states its trigger (`.OnCreate()` /
  `.OnUpdate()`, plus `.Stage(...)` only when several steps share the message - `harness-api.md`); the
  existing Create tests are updated accordingly and stay green. (Rubric note 2026-10-17: "+ stage" on every
  test was stricter than the pack.)

## Success criteria (a clean pass)
1. The Canvas records `reuse: add-step:AccountDefaultDescription` and the Update step.
2. The Update step is gated on the gating column (no placeholder left); the build is green with no VELA00x in authored code.
3. RED then green: name changed → account number uppercased; name unchanged (filter) → step not run;
   the Create cases still pass.
4. `vela-code-review` PASS.

## Human answers (evaluator only - never shown to the acting agent)
- "Name changes" = the Name column is sent with a different value; a null account number stays null.
- Target solution / publisher prefix: `ZavaSales` / `zava`.
- Anything not listed: "Use the skills' defaults and record it as an assumption."
