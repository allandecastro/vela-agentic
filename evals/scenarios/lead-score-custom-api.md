---
scenario: lead-score-custom-api
skills_exercised: [vela-plan-review, vela-custom-api, vela-scaffold, vela-test-harness, vela-code-review]
entity: none (global)
message: <pfx>_<Name> (Custom API; names are the agent's choice)
gotchas_exercised: [step-vs-custom-api, custom-api-dot-free-naming, action-vs-function, ipe-errors]
org_required: false
---

# Scenario: a callable lead-scoring operation

## User story
"Expose an operation our flows can call with a lead's email that returns a score from 0 to 100:
55 for addresses at fortune500.com, 10 otherwise. An empty email is an error."

## Setup for the run
- The evaluator gives you a work dir. `vela` and `dotnet` on PATH. The dev org `https://dyn-premium-dev.crm.dynamics.com` is available **read-only** (`vela models` / `vela solution show` / `vela plan` / `vela inspect` / `vela logs`); never `vela apply`.

## Success criteria (a clean pass)
1. `vela-plan-review` routes to **`vela-custom-api`** (a called operation, not a table step).
2. The Canvas records: **global**, **Action** because flows call it (the Dataverse connector only calls
   Actions - a Function is a finding even though the operation is a pure computation), parameters
   one required string input (the email) → one int output (the score), and the error cases. Names are
   not given to the agent and are not graded - only that they are meaningful and dot-free.
3. Scaffolded with `vela add customapi <Name> --action --prefix <pfx>` (a global Action); the unique name
   is `<pfx>_<Name>`; no name contains a dot.
4. Test-first, RED then green, via `vela add test <Name> --kind customapi`: fortune500 → 55; other
   domain → 10; empty/missing email → `InvalidPluginExecutionException`.
5. Build clean of VELA00x; `vela-code-review` PASS.

## Planted-violation check (adversarial)
The review must flag: (a) the email parameter renamed with a dot (e.g. `lead.email`) → **Required or Critical** (rubric note, campaign
2026-10-13: Vela.Plugins >= 0.33 rejects a dotted name locally - `Build()` throws and the suite goes red - so the
checklist rates it Required; before that it was only caught on a live org, hence Critical); (b) an empty email returning
a score of -1 instead of throwing → **Required**; (c) the Function writing a record → **Required**.

## Human answers (evaluator only - never shown to the acting agent)
- Flows (Power Automate) call it. An email without "@" is invalid (throw). Domain match is case-insensitive.
- Target solution / publisher prefix: `ZavaSales` / `zava`.
- Anything not listed: "Use the skills' defaults and record it as an assumption."
