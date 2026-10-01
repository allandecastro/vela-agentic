---
scenario: account-default-description
date: 2026-10-02
verdict: pass
campaign: 2026-10-02
run: 1/3
checks: pass
grader: pass
model: claude-opus-5-5
vela_cli: 0.21.4
framework: 0.29.11
runner: "campaign actor + separate grader"
---

## Check summary
`checks.json`: **15/15 passed**. There are no failed checks.
- The build succeeds with no VELA diagnostics.
- The tests re-run green: total=15, failed=0.
- Exactly one authored step is registered, `Create account PreOperation/Synchronous filter=['name']`, and no scaffold demo is registered.
- The package `artifacts/zava.Plugins.1.0.0.nupkg` holds the plugin dll.
- `src` contains no `UserService.Update/Create` and no `ColumnSet(true)`.

## Loop outcome
- `vela version` returned `vela 0.21.4` (Build Report Run trace row 1; the installed CLI is the same version).
- Canvas and grill: the Canvas was committed before the plugin (commit 5e18a91). Both human answers are recorded as `decisions` (Canvas L37-39).
- Scaffold, all exit 0 (Run trace rows 3, 4 and 7):
  - `vela init --name ZavaSales --prefix zava --output . --no-integrations --no-console`
  - `vela add plugin AccountDefaultDescription --entity Account --message Create --stage PreOperation --mode Sync --filtering-attributes Name ...`
  - `vela add test ... --kind plugin --entity Account ...`
  - The untouched scaffold base is commit afde163. The 18 demo files were removed in 91030b9.
- Model: `vela models` was skipped because there is no org. The exact command is recorded (Run trace row 6). `Account.Description` was added as a labelled STAND-IN (`Account.cs:32-39`, commit 7ee7257).
- RED: commit d8b7b6b holds the tests only, with the handler still the generated TODO.
  - Actor's run: `Total: 15, Errors: 0, Failed: 11` (`review/test-evidence.txt`).
  - **The grader re-ran it independently** on a clone at d8b7b6b with Mono xunit.console `-parallel none` and got the same result, 15 total and 11 failing. The 11 failures are exactly the defaulting cases.
- GREEN: commit 492a871 is the handler only, and the run gave `Total: 15, Errors: 0, Failed: 0`.
- Release build: `dotnet build -c Release --no-incremental` gave `0 Warning(s) 0 Error(s)`.
- Review: an isolated vela-reviewer returned PASS with 0 Critical, 0 Required and 4 Nits. It is saved verbatim in `docs/vela-builds/account-default-description.review.md`.
- Package: built with `rm -rf artifacts && dotnet build -c Release`. The dll was checked and the sha256 recorded.
- `vela plan` was skipped because there is no org. The exact command is at Build Report L108-109.
- The actor stopped at the apply gate and never ran `vela apply`.

## Criteria
| # | Criterion | Met? | Evidence |
|---|-----------|------|----------|
| SC1 | `vela init` + `vela add plugin` + `vela add test` exit 0, per vela-scaffold | met | Build Report Run trace rows 3, 4 and 7 (exit 0). `review/run-trace.txt`. Commits afde163 (untouched init) and 4aaef71 (`add plugin` output). The check "solution found" passed. |
| SC2 | Handler per vela-plugin-authoring (`EntityPluginBase` / `OnExecute` / `ctx.Request.Target`), no magic strings where a model exists | met | `AccountDefaultDescription.cs:12` `EntityPluginBase<Account>`, `:26` `OnExecute(ICreatePreContext<Account> ctx)`, `:30` `ctx.Request.Target`, `:31,37` typed `target.Description`. The default text is a private const (`:14`). |
| SC3 | Test-first: tests seen RED before the handler, then GREEN, OS-correct runner, real harness API | met | Commit order d8b7b6b (tests) -> 492a871 (logic). The grader re-ran RED at d8b7b6b: `Total: 15, Errors: 0, Failed: 11`. GREEN: `Failed: 0`. Runner: mono xunit.console 2.9.2 net462 `-parallel none`. The tests use `PluginContext.For<Account>().WithTarget().WithOrganizationService().Execute()` and `PluginPipeline.Empty().Register<>()` (`AccountDefaultDescriptionTests.cs:92,154-160`). |
| SC4 | `dotnet build` green, no VELA00x | met | Checks "build succeeds" and "no VELA diagnostics". Build Report L93. The grader's own Release build at d8b7b6b also gave 0 warnings and 0 errors. |
| SC5 | Empty (null / whitespace) -> defaulted; non-empty -> untouched | met | Tests at L21-71 and L88-111 cover null not sent, null sent, `""` and 5 whitespace variants, both direct and through the pipeline. L73-85 and L114-124 cover non-empty values. All 15 are green (checks.json). |
| SC6 | Step is PreOperation, default set on `ctx.Request.Target`, no `UserService.Update` | met | Check "step registered: Create account PreOperation/Synchronous" and the check that `src` has no `UserService.Update/Create`. `AccountDefaultDescription.cs:19,37`. The tests assert `crm` is empty, so there is no extra write (L29 and others). |
| SC7 | Vela Canvas with acceptance cases + Build Report (harness pass, analyzers clean, cases checklist) per the template | met | `docs/vela-builds/account-default-description.md`: `kind: vela-build`, acceptance_cases AC1-AC10 (L26-36), `harness: pass`, `analyzers: clean`, `review: pass` (L21-23), cases checklist L94, RED/GREEN lines L95-98, Run trace and Gate L118-146. It is one file at the template path. |
| No-org | STAND-IN property labelled; `FilterOn(e => e.Name)` kept | met | `Account.cs:32-33` comment carries the regenerate command. `AccountDefaultDescription.cs:21`. Regenerating is the first item in the gate (L138-139). |
| Closed findings | Iteration 1 and 2 blockers (harness API, Mono runner, authoring surface, F1 FilterOn, F2 no-org path, F3 `target.Id`) do not recur | met | The correct API and runner were used the first time, as the trace shows. The Execute tests set `Id` on the target and the pipeline tests use the Id returned by `Create`. Neither depends on `PrimaryEntityId`. |

## Planted-violation results
Not applicable. The scenario has no "Planted-violation check" section.

## Findings
No blocker or minor defect in the skill pack was observed in this run. One observation, which is not a skill defect:
1. observation - the reviewer's Nit 3 says the generated handler line `ctx.Trace("... {0} '{1}'.", ctx.PrimaryEntityName, ctx.PrimaryEntityId)` traces a usually-empty `PrimaryEntityId` in Create PreOperation. That line comes from the `vela add plugin` template (commit 4aaef71), so it is a CLI template matter to relay to the Vela repo, not a skill fix.

## Fixes
- None needed.

## Verdict
**pass**. The checks pass 15/15 and every scenario criterion is met with artifact evidence.
- The RED step was reproduced independently by the grader.
- The next runs (2/3 and 3/3) must re-check that RED is observed before the logic commit and that the no-org STAND-IN stays labelled and listed at the gate.
