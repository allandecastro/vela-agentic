---
scenario: account-default-description
skills_exercised: [vela-plan-review, vela-scaffold, vela-test-harness, vela-plugin-authoring, vela-code-review, vela-apply]
entity: account
message: Create
gotchas_exercised: [filtering-attributes, model-before-implement]
org_required: false        # local loop only; model/plan steps are noted, not run
---

# Scenario: default an Account's Description on create

## User story
"When an Account is created, if its Description is empty, set it to 'Created via Vela plugin'."

## Setup for the run
- The evaluator gives you a work dir; nothing outside it.
- `vela` and `dotnet` on PATH. The dev org `https://dyn-premium-dev.crm.dynamics.com` is available **read-only**
  (`vela models` / `vela solution show` / `vela plan` / `vela inspect` / `vela logs`); never `vela apply`.

## Success criteria (a clean pass)
1. `vela init` + `vela add plugin` exit 0, following `vela-scaffold`; tests live in the scaffold's `.Tests`
   project (`vela add test` only when none exists - `vela-test-harness` step 1). (Rubric note, campaign
   2026-10-02: `vela add test` was required here but the pack never asks for it when the scaffold has a test project.)
2. The handler is implemented per `vela-plugin-authoring` (real `EntityPluginBase` /
   `OnExecute` / `ctx.Request.Target` surface), no magic strings where a model exists.
3. **Test-first:** the acceptance-case tests are written and seen to **fail (RED)** before
   the handler is implemented, then pass after - run with the OS-correct runner (Mono +
   `-parallel none` on macOS), using the real harness API.
4. `dotnet build` is green **and** has no analyzer (VELA00x) violations.
5. Behaviours proven: empty (null / whitespace) Description → defaulted; non-empty → untouched.
6. **Stage:** the step is **PreOperation** and sets the default on `ctx.Request.Target`; no
   `ctx.Service.Update` of the account (a PostOperation write-back is a finding).
7. A Vela Canvas (with the acceptance cases listed) and Build Report (harness pass + analyzers
   clean + cases checklist) are produced per `references/build-report-template.md`.

## Models note
The minimal scaffold has no models: `account` is generated from the read-only dev org with `vela models`
before the plugin builds (no hand-written stand-in). A Create step still needs a `FilterOn`, and it gates
the trigger on Create too (verified live): `Name` (sent on every create of an account) is the natural pick; adding `Description` is fine (it only widens the trigger). (Campaign 2026-10 note: vela 0.24.1 / Vela.Plugins 0.33.0 - minimal scaffold, org read-only for every run.)

## Known findings closed
- Iteration 1 blockers (harness API, macOS Mono runner, `EntityPluginBase`/`OnExecute` authoring
  surface) must NOT recur - the skills give the correct path without rediscovery.
- Iteration 2 (F1) mandatory Create/Update `FilterOn`, (F2) no-org non-demo-attribute path, (F3)
  `target.Id` vs `ctx.PrimaryEntityId` in the harness - all now documented in the skills/references.

## Human answers (evaluator only - never shown to the acting agent)
- "Empty" = null, "" or whitespace-only.
- Target solution / publisher prefix: `ZavaSales` / `zava`.
- Anything not listed: "Use the skills' defaults and record it as an assumption."
