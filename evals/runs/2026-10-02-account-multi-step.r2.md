---
scenario: account-multi-step
date: 2026-10-02
verdict: pass
campaign: 2026-10-02
run: 2/3
checks: pass
grader: pass
model: claude-opus-5-5
vela_cli: 0.21.4
framework: 0.29.11
runner: "campaign actor + separate grader"
---

## Check summary
`checks.json`: **17/17 passed**, `"pass": true`. No checks failed. The key ones:
- the build succeeds with no VELA diagnostics;
- tests re-run green (total=14, failed=0);
- the Create and Update account steps are both registered PreOperation/Synchronous with filter=['name'];
- there are exactly 2 authored steps;
- `HandleUpdate` and `OnExecute` are both kept;
- there is no `UserService.Update/Create` write-back;
- `PluginPipeline` is used for the "does not fire" case;
- the package holds the plugin dll.

## Loop outcome
1. `vela version` returned `vela 0.21.4` (Canvas run trace row 1).
2. The Canvas was committed first (e02adb4).
3. `vela add step AccountDefaultDescription --entity Account --message Update --stage PreOperation --mode Sync --filtering-attributes Name --project ...` exited 0 (c1a1c7d). The actor then aligned it to the Canvas by hand: it added `WithPreImage(Name, AccountNumber)` and a description, and made the class `partial`.
4. `Account.AccountNumber` was added to the model as a labelled no-org stand-in.
5. RED tests (13a37b2) gave `Total: 14, Failed: 4` (AC1, AC2, AC7, AC9). **The grader reproduced this independently**: a clean clone of the work at 13a37b2, a Release build, and mono xunit.console gave `Total: 14, Errors: 0, Failed: 4`, with the same 4 tests failing.
6. Implementation (ddbb93c), then GREEN at 14/14 (`green-run.txt`; the checks re-run also gave total=14 failed=0).
7. An isolated vela-reviewer returned PASS: 0 Critical, 0 Required, 4 Nits (`docs/vela-builds/account-number-uppercase.review.md`).
8. The Release build produced `artifacts/zava.Plugins.1.0.0.nupkg`, and `vela plan` was skipped (no org) with the exact command recorded. The run stopped at the gate, and `vela apply` was never run.

## Criteria

| Criterion | Met? | Evidence |
| --- | --- | --- |
| Reuse: `vela add step AccountDefaultDescription --entity Account --message Update`, not a new plugin or a hand-written step | met | Canvas `docs/vela-builds/account-number-uppercase.md:20` `reuse: add-step:AccountDefaultDescription`; run trace row 3 (`:118`, exit 0). Check "exactly 2 authored step(s)" = 2. There is still one plugin class: `src/zava.Plugins/Account/Plugins/AccountDefaultDescription.cs:10`. |
| Generated handler `HandleUpdate` kept, `OnExecute` kept for Create, neither renamed | met | `AccountDefaultDescription.cs:19` `.Handle(OnExecute)`, `:27` `.Handle(HandleUpdate)`, `:33`, `:62`. Checks "src contains /HandleUpdate/" and "/OnExecute/" are ok. |
| Placeholder replaced with the gating column `e => e.Name` | met | `AccountDefaultDescription.cs:24` `.FilterOn(e => e.Name)`. The actor passed `--filtering-attributes Name`, as vela-scaffold step 5 says, so no `e.Id /* TODO */` placeholder was emitted. Check "step registered: Update ... filter=['name']" is ok. |
| Stage: PreOperation on `ctx.Request.Target` | met | `AccountDefaultDescription.cs:22` `.PreOperation()`, `:35` `var target = ctx.Request.Target`, `:57` `target.AccountNumber = upper`. Check "no UserService.Update/Create" is ok. |
| Harness: every test states its trigger, and the Create tests are updated and stay green | met | `AccountDefaultDescriptionTests.cs` diff: `.OnCreate().Stage(PluginStages.PreOperation)`. `AccountNumberUppercaseTests.cs:18` `.OnUpdate().Stage(PluginStages.PreOperation)`. The pipeline tests (`:99`, `:114`, `:131`) drive real Update messages. GREEN 14/14. |
| SC1: the Canvas records `reuse: add-step:AccountDefaultDescription` and the Update step | met | Canvas `:19` (Update / PreOperation / Synchronous / filter [Name] / HandleUpdate / pre-image), `:20`. |
| SC2: placeholder replaced; build green with no VELA00x in authored code | met | Checks "build succeeds" and "no VELA diagnostics". The grader's rebuild at 13a37b2 also gave 0 Warning(s). |
| SC3: RED then green: name changed → uppercased; name unchanged (filter) → step not run; Create cases still pass | met | RED: `red-run.txt` (4 failures, "Strings differ"), reproduced by the grader. Name changed: AC1 `:31`, AC9 `:111` (pipeline, persisted, single run). Name not sent → step not run: AC8 `:96` `Assert.Empty(p.ExecutionLog)`. Same name re-sent → number untouched: AC6 `:78`, `:128`. A null number stays null: AC3 `:49`, which matches the human answer. Create cases are green in the 14/14. |
| SC4: `vela-code-review` PASS | met | `docs/vela-builds/account-number-uppercase.review.md`: "Verdict: **PASS** (0 Critical, 0 Required, 4 Nits)", from an isolated subagent over the diff e2e5842...ddbb93c. |

## Planted-violation results
Not applicable. The scenario has no "Planted-violation check" section.

## Findings against the skills
None, blocking or minor. The skills led the actor down the intended path:
- vela-scaffold `SKILL.md:57,65` ("pass `--stage`, `--mode` and `--filtering-attributes`") gave the right `vela add step` command without the placeholder.
- The multi-step harness rule produced `.OnCreate()` / `.OnUpdate()` on every test.
- The review ran isolated.

Two notes that are not skill defects:
- `red.txt` and `review-diff.txt` in the r2 folder are stale files from a 2026-09-29 run (different test class `AccountUppercaseNumberOnNameChangeTests`). They are evaluator leftovers and were not used as evidence. The evaluator should clear the run folder between campaigns.
- AC7 ("Name cleared is a change") tests a case Dataverse would reject in practice, because `account.name` is required. It is harmless over-coverage.

## Verdict
**pass**. Checks are 17/17, every criterion is met with evidence, and the RED run was reproduced independently. The next run must re-check that the actor still passes `--filtering-attributes` (or replaces the `e.Id` placeholder), and that the existing Create tests state `.OnCreate()`.
