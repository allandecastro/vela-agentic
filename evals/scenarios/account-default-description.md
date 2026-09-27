---
scenario: account-default-description
entity: account
message: Create
gotchas_exercised: [filtering-attributes, model-before-implement]
org_required: false        # local loop only; model/plan steps are noted, not run
---

# Scenario: default an Account's Description on create

## User story
"When an Account is created, if its Description is empty, set it to 'Created via Vela plugin'."

## Setup for the run
- Fresh scratch dir (e.g. `/tmp/vela-rehearsal`). Nothing outside it.
- `vela` and `dotnet` on PATH. No Dataverse org: SKIP `vela models` and `vela plan`/`apply`,
  recording the exact command that would have run. Never run `vela apply`.

## Success criteria (a clean pass)
1. `vela init` + `vela add plugin` + `vela add test` all exit 0, following `vela-scaffold`.
2. The handler is implemented per `vela-plugin-authoring` (real `EntityPluginBase` /
   `OnExecute` / `ctx.Request.Target` surface), no magic strings where a model exists.
3. **Test-first:** the two acceptance-case tests are written and seen to **fail (RED)** before
   the handler is implemented, then pass after - run with the OS-correct runner (Mono +
   `-parallel none` on macOS), using the real harness API.
4. `dotnet build` is green **and** has no analyzer (VELA00x) violations.
5. Two behaviours proven: empty Description → defaulted; non-empty → untouched.
7. **Stage:** the step is **PreOperation** and sets the default on `ctx.Request.Target`; no
   `ctx.UserService.Update` of the account (a PostOperation write-back is a finding).
6. A Vela Canvas (with the acceptance cases listed) and Build Report (harness pass + analyzers
   clean + cases checklist) are produced per `references/build-report-template.md`.

## No-org note
`account.description` is not in the scaffold's sealed demo model. With no org, follow
`vela-plugin-authoring`'s documented no-org exception (a labelled stand-in property); a real run
regenerates via `vela-models`. Keep the scaffold's `FilterOn(e => e.Name)` - a Create step
requires a filter at build even though Create ignores it at runtime.

## Known findings closed
- Iteration 1 blockers (harness API, macOS Mono runner, `EntityPluginBase`/`OnExecute` authoring
  surface) must NOT recur - the skills give the correct path without rediscovery.
- Iteration 2 (F1) mandatory Create/Update `FilterOn`, (F2) no-org non-demo-attribute path, (F3)
  `target.Id` vs `ctx.PrimaryEntityId` in the harness - all now documented in the skills/references.
