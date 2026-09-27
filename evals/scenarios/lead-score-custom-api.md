---
scenario: lead-score-custom-api
entity: none (global)
message: zava_ScoreLead (Custom API)
gotchas_exercised: [step-vs-custom-api, custom-api-dot-free-naming, action-vs-function, ipe-errors]
org_required: false
---

# Scenario: a callable lead-scoring operation

## User story
"Expose an operation our flows can call with a lead's email that returns a score from 0 to 100:
55 for addresses at fortune500.com, 10 otherwise. An empty email is an error."

## Setup for the run
- Fresh scratch dir. `vela` and `dotnet` on PATH. No org: skip `vela plan`, recording the command.
  Never run `vela apply`.

## Success criteria (a clean pass)
1. `vela-plan-review` routes to **`vela-custom-api`** (a called operation, not a table step).
2. The Canvas records: **global**, **Function or Action with a reason** (a pure computation → Function
   is defensible; if the agent picks Action it must say why), parameters `email` (string, required) →
   `leadScore` (int), and the error case.
3. Scaffolded with `vela add customapi ScoreLead [--function|--action] --prefix <pfx>`; the unique name
   is `<pfx>_ScoreLead`; no parameter name contains a dot.
4. Test-first, RED then green, via `vela add test ScoreLead --kind customapi`: fortune500 → 55; other
   domain → 10; empty/missing email → `InvalidPluginExecutionException`.
5. Build clean of VELA00x; `vela-code-review` PASS.

## Planted-violation check (adversarial)
The review must flag: (a) a parameter named `lead.email` → **Critical**; (b) an empty email returning
`leadScore = -1` instead of throwing → **Required**; (c) the Function writing a record → **Required**.
