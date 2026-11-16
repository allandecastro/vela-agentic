---
scenario: account-credit-function
skills_exercised: [vela-plan-review, vela-custom-api, vela-scaffold, vela-models, vela-plugin-testing, vela-code-review]
entity: account
message: <pfx>_<Name> (bound Custom API; names are the agent's choice)
gotchas_exercised: [step-vs-custom-api, action-vs-function, bound-vs-global, typed-request-response-mapping, function-no-side-effects, ipe-errors]
org_required: true
---

# Scenario: a read-only operation bound to an account (typed Custom API)

## User story
"On the account form, a button should ask Dataverse how much credit the account still has: its credit
limit minus an amount the user types to reserve. The amount is optional - no amount means nothing is
reserved. The button only reads; it must never change the account."

## Setup for the run
- The evaluator gives you the `ZavaSales` project (`<work>/ZavaSales`, a git repo, scaffolded with
  `vela init`, `account` / `contact` models generated, one existing Create plugin). `vela` and `dotnet`
  on PATH. The dev org `https://dyn-premium-dev.crm.dynamics.com` is available **read-only**
  (`vela models` / `vela solution show` / `vela plan` / `vela inspect` / `vela logs`); never `vela apply`.

## What the skills must get right
- **Routing:** a called operation → `vela-custom-api`, not a table step.
- **Kind:** **Function** - it only reads and is called from the form's JavaScript (a GET through the Web
  API), not from flows; an Action is a Required finding unless the Canvas gives a reason the human
  confirmed. **Bound to `account`** (it runs on one record), so the typed form:
  `vela add customapi <Name> --bound --entity Account --function`.
- **Typed request/response:** one **optional** input (the reserved amount, a number) mapped in
  `.Request(...)` with `optional: true`; one output (the available credit) mapped in `.Response(...)`;
  the scaffold's placeholder `Result` replaced. Every property the Canvas declares is mapped (an unmapped
  one is silently not registered once `.Request`/`.Response` is called).
- **Reading the record:** the bound account comes from the request's `Target`; the handler retrieves only
  the credit limit column with `ctx.Service` (no `SystemService`) and **writes nothing**.
- **Errors:** `InvalidPluginExecutionException` with an actionable message for the cases the human
  defines (below); never an error code in the output.
- **Tests:** RED then green through the harness (custom API execution with a seeded account), plus the
  registered definition checked (`GetCustomApiDefinition()`: `IsFunction`, `IsBound`, the optional input).

## Success criteria (a clean pass)
1. The Canvas records: bound to account, **Function** and why (read-only, called from JS), the optional
   input and its default, the output, the error cases.
2. Scaffolded with `vela add customapi ... --bound --entity Account --function`; the unique name is
   `zava_<Name>`; nothing dotted.
3. RED then green: limit 1000, no amount → 1000; limit 1000, amount 300 → 700; no credit limit → error;
   negative amount → error; the definition is a bound Function with one optional input, one output.
4. Build clean of VELA00x; `vela-code-review` PASS; `vela plan --solution ZavaSales` shows the Custom API
   with the expected parameters.

## Planted-violation check (adversarial)
The review must BLOCK each of: (a) the output property declared on the response class but left out of
`.Response(...)` (only a second, unrelated output mapped) → **Required** (silently not registered);
(b) the input made required → **Required** (spec drift: the story says optional); (c) the handler also
updating the account (e.g. stamping the last check date) → **Critical** (a Function must not have side
effects; the story says it never changes the account).

## Human answers (evaluator only - never shown to the acting agent)
- Target solution / publisher prefix: `ZavaSales` / `zava`.
- Called from JavaScript on the account form only; not from flows.
- No credit limit set on the account → an error ("This account has no credit limit."). A negative amount
  → an error. The result may be negative (over-reserved) - return it as is.
- Currency: ignore it; plain numbers in the account's currency.
- Anything not listed: "Use the skills' defaults and record it as an assumption."
