---
scenario: account-default-description
date: 2026-10-17
verdict: pass
campaign: 2026-10-17e
run: 1/1
checks: pass
grader: pass
model: claude-opus-5-5
vela_cli: 0.26.2
framework: 0.37.0
runner: "campaign actor + separate grader"
---

## Check summary
`checks.json`: **19/19 passed**, `pass: true`. No failed checks. These checks cover the build, VELA diagnostics, a test
re-run (10 total, 0 failed), the registration probe (Create/account/PreOperation/Sync, filter `[name]`, one authored
step), no `Service.Update/Create` in src, `vela solution show ZavaSales`, and a read-only `vela plan` that creates
only the package and the authored step.

`vela_cli` is the installed `vela version` (0.26.2), because the work logs contain no `vela version` output. The Build
Report front-matter (`vela_cli: 0.26.2`) agrees. `framework` comes from `src/Zava.Plugins/Zava.Plugins.csproj:36`
(`Vela.Plugins` 0.37.0) and `logs/init.log`.

## Loop outcome
- CHALLENGE: two questions, asked one at a time (`logs/human-questions.md`: Q1 "empty" meaning, Q2 target solution).
  The Canvas was committed first (`fbb5b90`).
- SCAFFOLD: `vela solution show ZavaSales --json` exited 0 with `{"solution":"ZavaSales","publisherPrefix":"zava"}`.
  `vela init ZavaSales --prefix Zava --publisher-prefix zava` exited 0 and left an untouched scaffold commit (`36e6513`).
- MODEL: `vela models --entities account --project src/Zava.Shared/...` exited 0 ("Generated 4 file(s)").
- ADD: `vela add plugin ... --stage PreOperation --mode Sync --filtering-attributes name` exited 0 (`name` was
  corrected to `Name`). `vela add test` exited 0 into the scaffold's `.Tests` project.
- TEST (RED): `d32a949` commits only the tests, while the plugin was still the scaffold stub. Mono + xunit.console
  with `-parallel none` gave `Total: 10, Failed: 6` (`logs/test-red.log`).
- IMPLEMENT/VERIFY: `f1bc446`. The run gave `Total: 10, Failed: 0` (`logs/test-green.log`, `logs/test-final.log`).
  The Release build had 0 warnings and 0 errors.
- REVIEW: a fresh vela-reviewer returned PASS with 3 Nits (`review/reviewer-output.md`).
- PREVIEW: `vela plan ... --solution ZavaSales --detailed-exitcode` exited 8, which means changes are pending
  (create package + 1 step, no diagnostics). The actor stopped before `apply`.

## Criteria
| # | Criterion | Met? | Evidence |
|---|-----------|------|----------|
| 1 | `vela init` + `vela add plugin` exit 0 per vela-scaffold; tests in the scaffold's `.Tests` project | met | `logs/init.log` and `logs/add-plugin.log` succeeded, and the Build Report run trace rows 3 and 5 show exit 0. The tests are at `tests/Zava.Plugins.Tests/Account/Plugins/AccountDefaultDescriptionTests.cs`. `vela add test` added a class inside the existing test project, which is what `vela-test-harness/SKILL.md` step 1 asks for. It did not create a new project. |
| 2 | Handler on the real `EntityPluginBase` / `OnExecute` / `ctx.Request.Target` surface, no magic strings where a model exists | met | `AccountDefaultDescription.cs:13` (`EntityPluginBase<Account>`), `:27-35` (`ICreatePreContext<Account>`, `ctx.Request.Target.Description`), `:22` (`FilterOn(e => e.Name)`). The text is a named constant (`:15`) and the generated model `Account` is used. |
| 3 | Test-first: RED seen before implementation, then green; OS-correct runner; real harness API | met | The git order is `d32a949` (tests only; the plugin at that commit is the scaffold stub with a TODO) and then `f1bc446` (implementation). `logs/test-red.log` shows `Failed: 6`, each for the right reason (Expected "Created via Vela plugin", Actual null or the whitespace input). `logs/test-green.log` shows `Failed: 0`. The runner was Mono + xunit.console 2.9.2 with `-parallel none`. The tests use `PluginContext.For<Account>()...Execute` and `PluginPipeline`. |
| 4 | `dotnet build` green, no VELA00x | met | `logs/build-release.log` shows 0 Warning(s) and 0 Error(s). The checks "build succeeds" and "no VELA diagnostics" both passed. |
| 5 | null / "" / whitespace defaulted; non-empty untouched | met | Tests at `:33` (null), `:44` (""), `:58` (3 whitespace variants), `:71` (non-empty, including untrimmed text), and the pipeline cases at `:82` and `:99`. The re-run check gave total=10 with failed=0. |
| 6 | PreOperation, default set on `ctx.Request.Target`, no `Service.Update` | met | `AccountDefaultDescription.cs:20,35`. Check: "step registered ... PreOperation/Synchronous". Check: "src must not contain Service.Update/Create" passed. The tests assert `Assert.Empty(crm.GetAll(...))`, so there is no extra write. |
| 7 | Vela Canvas with acceptance cases + Build Report per the template | met | `docs/vela-builds/account-default-description.md`. It has `kind: vela-build`, the Canvas keys, `acceptance_cases` AC1-AC6 (`:17-23`), `harness: pass`, `analyzers: clean`, `review: pass`, `package_sha256`, `plan_command`, and the cases checklist (`:80-82`). It includes the REASONS sections, the evidence, the run trace and the gate. |
| - | Models note: `account` generated via `vela models`, `FilterOn(Name)` on Create | met | `logs/models.log` and `src/Zava.Shared/Models/Generated/Account.cs`. The residual risk (a create without `name` does not fire) is recorded as an assumption and tested (AC6, `:113`). |
| - | Ask-vs-assume / one question at a time | met | `logs/human-questions.md` has Q1 and Q2, each a separate single question. Both are business or target facts the skills say to ask about. Platform facts are recorded as assumptions (Build Report `:27-30`). |
| - | Known findings closed (harness API, Mono runner, authoring surface, FilterOn on Create, target.Id) | met | None of these recurred. The actor reached the correct API, runner and filter on its first attempt, with no rediscovery in the logs. |
| - | Stop before `apply` | met | `apply: pending`. The Build Report "Gate" section hands `vela apply` to a human. |

## Planted-violation results
The scenario has no "Planted-violation check" section, so this step did not apply.

## Findings against the skills
None. Nothing the pack says led the actor wrong, and every criterion was met through the documented paths.

Observations (not skill defects):
- Rubric drift in the scenario. Criterion 1 still reads "`vela add test` only when none exists", but
  `vela-test-harness/SKILL.md` step 1 now says to run `vela add test` inside the scaffold's test project. The actor
  followed the skill. The scenario wording should be updated to match the skill.
- The scaffold's generated trace logs `ctx.PrimaryEntityId`, which is often `Guid.Empty` on Create PreOperation (Nit
  from the reviewer). This comes from the Vela template, not the pack, and is reported for relay only.

## Verdict
**pass**. Checks passed 19/19 and the grader met every criterion; there are no planted violations. The next run
should re-check that RED is committed alone before the implementation and that the AC6 "does not fire" case is still
written with `PluginPipeline`.
