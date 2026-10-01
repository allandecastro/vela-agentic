---
superseded_by: 2026-10-02-account-default-description.r2.md   # rubric corrected mid-campaign; kept for transparency
scenario: account-default-description
date: 2026-10-02
verdict: fail
run: 2/3
checks: pass
grader: fail
model: claude-opus-5-5
vela_cli: 0.21.4
framework: 0.29.11
runner: "campaign actor + separate grader"
---

## Check summary
`checks.json`: **15/15 passed**, with no failed checks. The checks covered: the Canvas exists and mentions PreOperation; the solution was found; the build succeeds; there are no VELA diagnostics; the tests re-run green (total=10, failed=0); the plugin dll is built; the registration probe runs; no demo is registered; the step is Create/account/PreOperation/Synchronous with filter=[name]; there is exactly 1 authored step; there are no dotted Custom API names; the package holds the plugin dll; there is no `UserService.Update/Create`; and there is no `ColumnSet(true)`.

## Loop outcome
- `vela version` gave 0.21.4 (Build Report run trace #1, `docs/vela-builds/account-default-description.md:109`).
- `vela init --name ZavaSales --prefix zava --output . --no-integrations --no-console` exited 0 with Vela.Plugins 0.29.11. The untouched scaffold is commit 0fc504a, and the demos were removed in 9ac7577.
- The Canvas was committed (0b1f0ef) before any code.
- `vela add plugin AccountDefaultDescriptionPlugin --entity Account --message Create --stage PreOperation --mode Sync --filtering-attributes Name --project ...` exited 0 (1bfb946). The generated chain matches the Canvas with no hand-fix.
- `vela models` was skipped because there is no org. The exact command is recorded, and `Description` is a labelled STAND-IN (9bdb148, `Account.cs:32-39`).
- **`vela add test` was never run.** The test file was hand-written into the scaffold's existing `zava.Plugins.Tests` project (b6c7c13).
- RED came from b6c7c13 and GREEN from aded8b1. The runner was mono xunit.console 2.9.2 with `-parallel none`.
- The isolated reviewer returned PASS: 0 Critical, 0 Required, 4 Nits (`account-default-description.review.md`).
- `rm -rf artifacts && dotnet build -c Release` produced `artifacts/zava.Plugins.1.0.0.nupkg`. Its sha256 is recorded and it is unsigned (signing requirement unknown).
- `vela plan` was skipped because there is no org; the exact command is recorded. `vela apply` was not run.

## Criteria
| # | Criterion | Met? | Evidence |
|---|-----------|------|----------|
| 1 | `vela init` + `vela add plugin` + `vela add test` all exit 0, per `vela-scaffold` | **not met** | `init` and `add plugin` exited 0 (run trace rows 3 and 5, `account-default-description.md:111,113`; commits 0fc504a and 1bfb946). **No `vela add test` invocation appears anywhere:** not in the run trace, `review/run-trace.md`, `review/bundle.txt`, or the actor report. Commit b6c7c13 adds a hand-written test file to the scaffold's `.Tests` project. The actor followed `vela-test-harness` step 1, which makes `vela add test` conditional (see Finding 1). |
| 2 | Handler per `vela-plugin-authoring` (`EntityPluginBase` / `OnExecute` / `ctx.Request.Target`), no magic strings where a model exists | met | `src/zava.Plugins/Account/Plugins/AccountDefaultDescriptionPlugin.cs`: `EntityPluginBase<Account>`, `RegisterStep().OnCreate().PreOperation().Sync().FilterOn(e => e.Name)...Handle(OnExecute)`, `ICreatePreContext<Account>`, `ctx.Request.Target.Description` through the typed property, default as a named const. The stand-in is labelled per the no-org exception. |
| 3 | Test-first: RED before implementation, then green, OS-correct runner, real harness API | met | Commit order b6c7c13 (tests) then aded8b1 (impl). **The grader re-ran RED independently:** clone at b6c7c13, `dotnet build -c Release` gave 0 warn / 0 err, then `mono xunit.console.exe ... -parallel none` gave `Total: 10, Errors: 0, Failed: 7`. The 7 failing cases are the ones that expect the default value, which matches Build Report line 90. GREEN comes from the check "tests re-run green" (total=10, failed=0). The harness is real: `PluginContext.For<Account>().WithTarget().WithOrganizationService().Execute(instance)`, `PluginPipeline.Empty().Register<>()`, `InMemoryOrganizationService`. |
| 4 | `dotnet build` green, no VELA00x | met | Checks "build succeeds" and "no VELA diagnostics"; the grader's RED-commit build gave 0 Warning(s) / 0 Error(s). |
| 5 | Empty (null/whitespace) defaulted; non-empty untouched | met | Tests file lines 24-77: not sent, null, "", whitespace ×3 → default; non-empty ×2 (including padded text) → untouched. Pipeline tests lines 79-105. All green (checks). |
| 6 | PreOperation, sets default on `ctx.Request.Target`, no `UserService.Update` | met | Check "step registered ... PreOperation/Synchronous filter=['name']"; check "no UserService.Update/Create"; plugin sets `target.Description` on `ctx.Request.Target`. |
| 7 | Vela Canvas (acceptance cases) + Build Report (harness pass + analyzers clean + cases checklist) per template | met | `docs/vela-builds/account-default-description.md`: front-matter `acceptance_cases` (lines 16-21), `harness: pass`, `analyzers: clean`, `review: pass`, R-E-A-S-O-N-S Canvas (45-73), Evidence with a cases checklist (85-100), run trace, Gate, and open questions. |
| — | Known findings closed: iter-1 (harness API, Mono runner, authoring surface) and iter-2 F1-F3 do not recur | met | Real harness API, macOS Mono `-parallel none` used first time, `EntityPluginBase`/`OnExecute`, `FilterOn(e => e.Name)` kept on Create, labelled no-org stand-in, tests use `Guid.NewGuid()` target Id. |

## Planted-violation results
The scenario has no "Planted-violation check" section, so nothing was planted.

## Findings against the skills
1. **minor (scenario/skill mismatch, decides this run's verdict):** `skills/vela-test-harness/SKILL.md:47-48` says "Ensure a `.Tests` project references `Vela.Testing` (the scaffold includes one; else `vela add test <Name> --kind plugin --entity <Entity>`)". `skills/vela-scaffold/SKILL.md:64` lists `vela add test` only as an option. Following these skills, the actor hand-wrote the test class in the scaffold's existing test project and never ran `vela add test`. Scenario success criterion 1 requires `vela add test` to exit 0. Runs r2 and r3 on 2026-09-30 did run it, so the pack does not reliably produce the step either way. **Fix one side:** either have the skills require `vela add test <Name> --kind plugin --entity <Entity> --project <tests csproj>` to create each plugin's test class, or drop `vela add test` from criterion 1.
2. minor (observation, not blocking): the tests read the result back with magic strings (`new ColumnSet("description")`, `GetAttributeValue<string>("description")`, tests lines 86-87 and 101-102) even though a typed model property exists. The handler itself is clean, and criterion 2 concerns the handler. `vela-test-harness` / `references/harness-api.md` could show a typed read-back (for example `row.ToEntity<Account>().Description`) so tests follow the same no-magic-strings norm.

## Verdict
**fail.** The checks pass (15/15). The grader fails the run only on criterion 1, because `vela add test` was never run. The run is otherwise clean: the grader reproduced RED, PreOperation edits the target in place, review PASS, there is a correct no-org stand-in, and the run stopped at the gate. The next run must re-check criterion 1 after Finding 1 is resolved, either by a skill change or by a scenario change.
