---
scenario: account-default-description
date: 2026-10-13
verdict: pass
campaign: 2026-10-13
run: 2/3
checks: pass
grader: pass
model: claude-opus-5-5
vela_cli: 0.25.0
framework: 0.34.0
runner: "campaign actor + separate grader"
---

## Check summary
`checks.json`: **19/19 passed** (`pass: true`). No failed check. Key ones: build succeeds, no VELA diagnostics,
tests re-run green (total=11 failed=0), step registered `Create 'account' PreOperation/Synchronous filter=['name']`,
exactly 1 authored step, no `Service.Update/Create` in src, read-only `vela plan` runs and creates only authored steps.

## Loop outcome
- Canvas first (commit `cab18ac`), then `vela solution show ZavaSales` (exit 0, prefix `zava`), `vela init` (exit 0, minimal scaffold, 0.25.0 / Vela.Plugins 0.34.0) `a73f122`.
- `vela models --entities account` from the read-only dev org (exit 0, 4 files) + `vela add plugin ... --stage PreOperation --mode Sync --filtering-attributes name` (exit 0) `c6e345f`.
- `vela add test` (a test class in the scaffold's existing `Zava.Plugins.Tests` project) and RED tests `07cb679`; Mono xunit.console 2.9.2 `-parallel none`: 8/12 failed.
- Implement `133d77b` -> 11/12; the 12th exposed a Vela.Testing gap (below), test removed (not a declared case), gap recorded. GREEN 11/11.
- Isolated vela-reviewer subagent: PASS, 0 Critical / 0 Required / 4 Nits (`docs/vela-builds/account-default-description.review.md`).
- `dotnet build -c Release` -> `artifacts/Zava.Plugins.1.0.0.nupkg`; `vela plan` exit 8 (create package + 1 step). Stopped before apply.

## Criteria
| # | Criterion | Met? | Evidence |
|---|---|---|---|
| 1 | `vela init` + `vela add plugin` exit 0 per vela-scaffold; tests in the scaffold's `.Tests` project | met | Build Report run trace rows 3, 5 (exit 0); `.vela/scaffold-manifest.json` lists `tests/Zava.Plugins.Tests/Zava.Plugins.Tests.csproj`; test file at `tests/Zava.Plugins.Tests/Account/Plugins/AccountDefaultDescriptionTests.cs` (no new test project; `vela add test` only added a class) |
| 2 | Real `EntityPluginBase` / `OnExecute` / `ctx.Request.Target` surface, no magic strings where a model exists | met | `src/Zava.Plugins/Account/Plugins/AccountDefaultDescription.cs:13` `EntityPluginBase<Account>`, `:28-30` `OnExecute(ICreatePreContext<Account> ctx)`, `ctx.Request.Target`, typed `target.Description`, `FilterOn(e => e.Name)`; generated model from `vela models` (`src/Zava.Shared/Models/Generated/Account.cs`) |
| 3 | Test-first: RED seen before the handler, then green, OS-correct runner, real harness API | met | Commit order `07cb679` (tests, stub plugin) before `133d77b` (logic). **Grader reproduced** RED at `07cb679` with Mono xunit.console 2.9.2 `-parallel none`: `Total: 12, Errors: 0, Failed: 8` - matches Build Report line 86. GREEN: checks `tests re-run green (>= 3)` total=11 failed=0. `PluginPipeline` / `PluginContext.For<Account>()` / `InMemoryOrganizationService` used |
| 4 | `dotnet build` green, no VELA00x | met | checks `build succeeds`, `no VELA diagnostics`; Build Report line 85 |
| 5 | null / whitespace -> defaulted; non-empty -> untouched | met | Tests `Description_Not_Sent_Is_Defaulted`, `Description_Sent_As_Null_Is_Defaulted`, `Empty_Description_Is_Defaulted`, `Whitespace_Only_Description_Is_Defaulted` (3 inputs), `Non_Empty_Description_Is_Left_Untouched` (2 inputs) - all green |
| 6 | PreOperation, sets default on `ctx.Request.Target`, no `ctx.Service.Update` | met | Handler `:30-37`; checks `step registered ... PreOperation/Synchronous`, `src must not contain Service.(Update|Create)`; plan.json stage 20 |
| 7 | Vela Canvas with acceptance cases + Build Report (harness pass, analyzers clean, cases checklist) | met | `docs/vela-builds/account-default-description.md`: front-matter `acceptance_cases` (l.28-33), `harness: pass`, `analyzers: clean`, `review: pass`, REASONS sections l.49-75, cases checklist l.88, run trace, gate l.117-120 |
| - | Models note: `account` generated from the org, no hand-written stand-in | met | commit `c6e345f` adds `Models/Generated/Account.cs` (1701 lines) from `vela models` |
| - | Known findings (iteration 1/2) must not recur | met | Correct harness API, Mono runner, `EntityPluginBase`/`OnExecute`, mandatory Create `FilterOn` defaulted to primary column - no rediscovery visible |
| - | Stop before apply | met | `apply: pending`, `status: awaiting-apply`; no apply in run trace |

## Planted-violation results
The scenario has no "Planted-violation check" section - none run.

## Findings against the skills
1. minor - `references/harness-api.md` (and its bundled copy under `skills/vela-test-harness/references/`) l.11: "`Execute` runs the handler **regardless of `FilterOn`** ...; only the pipeline honours the registration", while `references/dataverse-gotchas.md` l.31 says "On Create the filter is ignored at runtime but still mandatory". Neither says that `PluginPipeline` (Vela.Testing 0.34.0) **applies** the Create `FilterOn`, unlike Dataverse. The actor wrote `Fires_On_Create_Even_Without_Name` (pipeline Create without `Name`) and it failed `Assert.Single() Failure: The collection was empty`. The grader reproduced it (`133d77b` src + `07cb679` tests: 12 total, 1 failed, that test). The actor handled it correctly: it reported the gap and did not work around it. Per the pack's rule, the gap is Vela's to fix. The pack should state it in one line (and give it to the user for Vela.Testing) so the next actor doesn't find it by accident.

No blocker. (The unused `using Vela.Constants;` Nit comes from the `vela add plugin` template, not the pack.)

## Verdict
pass - 19/19 checks, every criterion met with artifact evidence, RED independently reproduced. Next run should re-check:
the Create-without-FilterOn-column harness behaviour, either noted in the pack or fixed in Vela.Testing.
