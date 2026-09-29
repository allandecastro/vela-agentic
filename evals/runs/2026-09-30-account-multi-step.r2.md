---
scenario: account-multi-step
date: 2026-09-30
verdict: pass
campaign: 2026-09-30
run: 2/3
checks: pass
grader: pass
model: claude-opus-5-5
vela_cli: 0.21.0
framework: 0.29.3
runner: "campaign actor + separate grader"
---

## Check summary
`checks.json`: **17/17 passed**, `"pass": true`. No failed checks. Key ones: build succeeds, no VELA
diagnostics, tests re-run green (total=13 failed=0), step registered Create and Update account
PreOperation/Synchronous filter=['name'], exactly 2 authored steps, `HandleUpdate` kept, `OnExecute` kept,
no `UserService.Update/Create` write-back, `PluginPipeline` used for the "does not fire" case.

## Loop outcome
The Canvas was committed first (2c88e75). Then:
1. `vela add step AccountDefaultDescription --entity Account --message Update`, then aligned to the Canvas
   (c16a1e3): PreOperation, `FilterOn(e => e.Name)`, a pre-image on Name and AccountNumber, and the class
   made partial.
2. The model got a labelled no-org stand-in for `AccountNumber`.
3. RED tests (58395b0): 7 failures, then 4 once the Create tests stated their trigger.
4. Implementation (0e25d15), then GREEN 13/13.
5. Release build: 0 warnings and 0 errors.
6. An isolated vela-reviewer returned PASS: 0 Critical, 0 Required, 4 Nits.
7. The package was built, `vela plan` was skipped (no org, command recorded), and the run stopped at the
   gate. `vela apply` was never run.

## Criteria

| Criterion | Met? | Evidence |
| --- | --- | --- |
| Reuse: `vela add step AccountDefaultDescription --entity Account --message Update`, not a new plugin or hand-written step | met | Canvas `docs/vela-builds/account-number-uppercase.md:20` `reuse: add-step:AccountDefaultDescription`, run trace row 4 (exit 0). Check "exactly 2 authored step(s)" = 2. There is still one plugin class, `src/zava.Plugins/Account/Plugins/AccountDefaultDescription.cs:10`. |
| Generated handler `HandleUpdate` kept, `OnExecute` kept for Create | met | `AccountDefaultDescription.cs:19` `.Handle(OnExecute)`, `:27` `.Handle(HandleUpdate)`, `:30` and `:57`. Checks "src contains /HandleUpdate/" and "/OnExecute/" ok. |
| Placeholder `e => e.Id /* TODO */` replaced with the gating column `e => e.Name` | met | `AccountDefaultDescription.cs:24` `.FilterOn(e => e.Name)`. Check "step registered: Update ... filter=['name']" ok. Canvas `:102` "placeholder `e => e.Id` replaced". Under the corrected rubric, seeing VELA001 is not required. |
| Stage PreOperation on `ctx.Request.Target` | met | `AccountDefaultDescription.cs:22` `.PreOperation()`, `:30` `IUpdatePreContext<Account>`, `:38`/`:52` write to `ctx.Request.Target`. Check "no UserService.Update/Create" ok. |
| Harness: every test states its trigger; Create tests updated and green | met | `AccountDefaultDescriptionUpdateTests.cs:20` `.OnUpdate().Stage(PluginStages.PreOperation)`. The Create tests diff adds `.OnCreate().Stage(PluginStages.PreOperation)`. The pipeline tests register through `PluginPipeline`, which dispatches by message. 13/13 green (check). |
| SC1: Canvas records `reuse: add-step:AccountDefaultDescription` and the Update step | met | Canvas `:17-20`: steps list with Update/PreOperation/Synchronous/filter [Name]/HandleUpdate/pre-image, plus the `reuse:` line. |
| SC2: build green, no VELA00x in authored code | met | Checks "build succeeds" and "no VELA diagnostics" ok. Canvas `:113` `0 Warning(s) 0 Error(s)`. |
| SC3: RED then green; name changed gives an uppercased account number; name unchanged means the step does not run; Create cases still pass | met | Tests commit 58395b0 comes before the implementation commit 0e25d15, and the implementation stub in c16a1e3 has an empty `HandleUpdate`, so RED was structurally real. Canvas `:114` "Failed: 4" (AC1, AC2, AC8, AC10). AC1 is at tests `:33`, AC8 (pipeline, saved uppercase) at `:121`. The name-not-sent pipeline case is at `:106` (`Assert.Empty(p.ExecutionLog)`) and the same-value case at `:79`/`:138`. The null account number staying null is covered at `:51`/`:61`. The Create tests are green (13/13 check). |
| SC4: `vela-code-review` PASS | met | Canvas `:119-123` gives the findings list: PASS, 0 Critical, 0 Required, 4 Nits, 2 of them resolved. The frontmatter has `review: pass`. The reviewed diff is kept at `r2/review-diff.txt`. The grader's own read of the final code found no Critical or Required issue. |
| Human answers honoured (`ZavaSales`/`zava`; a null account number stays null) | met | Canvas `:22-23`; AC3 and AC4 are tested. |

## Planted-violation results
Not applicable. The scenario has no "Planted-violation check" section.

## Findings against the skills
No blocker.

1. minor: `skills/vela-scaffold/SKILL.md:76-77` says "After `vela add step` the plugin is **multi-step**
   ... its harness tests must now state the trigger". The actor still wrote only the new tests at first,
   and its first RED run failed the 3 existing Create tests with "has no registered step matching message
   'Update'" (Canvas `:115-116`). It fixed this before GREEN, so there was no outcome impact. The rule
   lives in vela-scaffold, but it is not repeated in `skills/vela-test-harness/SKILL.md`, which is the
   skill in force when tests are written. Consider adding one line there: "multi-step plugin: update the
   EXISTING tests' trigger too".

## Verdict
**pass.** Checks are 17/17, and every "must get right" item and success criterion is met from the
artifacts. The next run should re-check that the Create-test trigger update happens before the first RED
run, not only in response to it.
