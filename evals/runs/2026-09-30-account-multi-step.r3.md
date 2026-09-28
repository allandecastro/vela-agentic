---
scenario: account-multi-step
date: 2026-09-30
verdict: pass
campaign: 2026-09-30
run: 3/3
checks: pass
grader: pass
model: claude-opus-5-5
vela_cli: 0.21.0
framework: 0.29.3
runner: "campaign actor + separate grader"
---

## Loop outcome
- Checks (`checks.json`): **17/17 passed**, no failed check. They include the build, no VELA diagnostics, 14/14 tests green, both steps registered as PreOperation/Sync with filter `name`, exactly 2 authored steps, `HandleUpdate` and `OnExecute` both kept, no write-back, and `PluginPipeline` used in the tests.
- Plan review: Canvas `docs/vela-builds/account-number-uppercase.md` (commit cb4a63e).
- Scaffold: `vela add step AccountDefaultDescription --entity Account --message Update --project src/zava.Plugins/zava.Plugins.csproj`, exit 0. The step was then aligned to the Canvas: Post changed to PreOperation, and the `e.Id /* TODO */` placeholder changed to `e.Name`.
- Model: `vela models` was skipped because there is no org. The `AccountNumber` property was added as a labelled stand-in.
- Tests: RED showed 4 of 14 failing, then GREEN showed 14 of 14 passing (Mono xunit.console 2.9.2 `-parallel none`).
- Review: `vela-reviewer` returned PASS with 0 Critical, 0 Required and 5 Nits.
- Package: nupkg built.
- `vela plan`: skipped because there is no org. The exact command is recorded.
- Stopped at the apply gate. `vela apply` was never run.

## Criteria

| Criterion | Met? | Evidence |
|---|---|---|
| Reuse: `vela add step AccountDefaultDescription --entity Account --message Update` | met | Canvas l.101 and run trace l.146 (exit 0). The check "exactly 2 authored step(s)" passes. There is one plugin class, `AccountDefaultDescription.cs` l.15-28. |
| Generated handler `HandleUpdate` kept; `OnExecute` kept | met | `AccountDefaultDescription.cs` l.28/31 and l.20/57. Checks `src contains /HandleUpdate/` and `/OnExecute/` pass. |
| Placeholder replaced with the gating column | met | `AccountDefaultDescription.cs` l.25 `FilterOn(e => e.Name)`. Canvas l.103 records the replaced `e => e.Id /* TODO */`. The check "step registered: Update ... filter=['name']" passes. |
| Stage PreOperation on `ctx.Request.Target` | met | l.23 `.PreOperation()` and l.33 `ctx.Request.Target`. The check "no UserService.Update/Create" passes. |
| Harness: every test states its trigger; Create tests updated and green | met | `AccountDefaultDescriptionTests.cs` diff: `.OnCreate().Stage(PluginStages.PreOperation)`. `AccountNumberUppercaseOnNameChangeTests.cs` l.18: `.OnUpdate().Stage(PreOperation)`. The pipeline tests trigger through `Service.Create/Update`. |
| SC1: Canvas records `reuse: add-step:AccountDefaultDescription` and the Update step | met | Canvas front-matter l.11 and l.9-10. |
| SC2: build green, no VELA00x in authored code | met | Checks "build succeeds" and "no VELA diagnostics". The grader's rebuild also succeeded with 0 warnings. |
| SC3: RED then green. Name changed → uppercased; name unchanged (filter) → not run; Create cases still pass | met | Canvas l.114-119 records the RED run (4 failed) and the GREEN run (14/14). **The grader reproduced RED independently**: in `grader-red/` the `HandleUpdate` body was emptied, and the exact 4 behaviour tests failed (`Total: 14, Failed: 4`). Test l.112 `Pipeline_name_not_sent_does_not_fire` covers the filter. Test l.122 covers Name sent unchanged. Test l.66 covers null staying null. The check "tests re-run green" shows total=14, failed=0. |
| SC4: `vela-code-review` PASS | met | Canvas l.124-130: an isolated vela-reviewer returned PASS, 0 Critical/Required, 5 Nits. Only the Canvas records this; no reviewer transcript was kept. The grader's own read of the diff found no Critical/Required defect either. |
| Human answers: null account number stays null; ZavaSales / zava | met | Test l.59 and l.66. Canvas l.13-14. |

## Planted-violation results
The scenario has no "Planted-violation check" section, so there was nothing to plant.

## Findings
Findings against the skill pack:

1. minor - Evidence persistence. AGENTS.md says "Evidence over claims ... paste the evidence". The RED/GREEN runner output and the review findings survive only as excerpts written by the actor into the Canvas. The work tree has no raw log, and tests and implementation went into a single commit (91d89a4), so git history cannot show RED. The grader had to re-derive RED by stubbing the handler. The pack could require the RED run to be committed separately (tests before implementation) or its raw output to be saved.
2. minor - The Create step keeps `FilterOn(e => e.Name)` (l.18), inherited from the baseline. Filtering attributes have no effect on Create. Neither the reviewer nor the Canvas flagged it. This is outside this scenario's diff, so it is recorded only as a review-baseline gap and not held against this run.

No blocker.

## Fixes
- none yet

## Verdict
**pass**: checks 17/17, and every criterion is met with artifact evidence. RED was independently reproduced. The next run should re-check that RED evidence is present in the artifacts and not only in the actor's own summary.
