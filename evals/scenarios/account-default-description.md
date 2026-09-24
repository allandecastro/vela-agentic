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
   `OnExecute` / `ctx.GetTarget` / `ctx.UserService` surface), no magic strings where a model exists.
3. `dotnet build` is green.
4. A harness test written per `vela-test-harness` (real `PluginContext.For<T>()...
   .WithOrganizationService(crm).Execute(new Plugin(string.Empty, string.Empty))`) passes —
   run with the OS-correct runner (Mono + `-parallel none` on macOS).
5. Two behaviours proven: empty Description → defaulted; non-empty → untouched.
6. A Plan artifact and Build Report are produced per `references/build-report-template.md`.

## Known findings closed
Iteration 1 blockers (harness API, macOS test runner, authoring surface) must NOT recur: an
agent following the skills should reach a green harness run without having to discover the real
API or the Mono runner on its own.
