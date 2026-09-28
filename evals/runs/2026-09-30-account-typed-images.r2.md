---
scenario: account-typed-images
date: 2026-09-30
verdict: pass
campaign: 2026-09-30
run: 2/3
checks: pass
grader: pass
model: claude-opus-5-5
vela_cli: 0.21.0
framework: 0.29.6
runner: "campaign actor + separate grader"
---

## Check summary
`checks.json`: **14/14 passed**, `pass: true`. No failed checks. Key ones: build succeeds; no VELA diagnostics;
tests re-run green (total=9, failed=0); step registered `Update account PreOperation/Synchronous filter=['creditlimit']`;
exactly 1 authored step; no scaffold demo registered; no `UserService.Update/Create` in src; `partial class` present.

## Loop outcome
- `vela version` -> `vela 0.21.0` (exit 0).
- Grill: one question to the human (cleared limit?) -> A (not a lowering); solution ZavaSales / prefix zava.
- `vela init --name ZavaSales --prefix zava --output . --no-integrations --no-console` (exit not captured - piped); scaffold committed untouched (`33f9815`), demos removed (`3391815`), Canvas committed (`cbd6b23`) before code.
- `vela add plugin AccountCreditLimitReduced --entity Account --message Update --filtering-attributes CreditLimit` (exit 0); stage moved to PreOperation, pre-image added, class `partial` (`4519501`). No org -> labelled model stand-in.
- Restore resolved Vela.* 1.0.0 (NU1603, `build1.log`); fixed with `dotnet restore --force-evaluate --no-http-cache` -> 0.29.6.
- RED tests committed (`6033870`), implementation (`6c7bbc4`), Build Report (`6b877cc`).
- Review: isolated vela-reviewer, PASS 0 Critical / 0 Required / 6 Nits. `vela plan` skipped (no org) with exact command. Stopped before apply.

## Criteria
| Criterion | Met? | Evidence |
| --- | --- | --- |
| Pre-image via `WithPreImage(e => e.CreditLimit)`, read through typed `ctx.PreImage` | met | `src/zava.Plugins/Account/Plugins/AccountCreditLimitReduced.cs:20` `.WithPreImage(e => e.CreditLimit)`; `:29` `ctx.PreImage?.CreditLimit` |
| Plugin class declared `partial` | met | same file `:10` `public sealed partial class AccountCreditLimitReduced`; check "src contains partial class" ok |
| "Lowered" = value actually differs (compare sent vs pre-image; step fires on same value) | met | `:32` `newLimit == null \|\| oldLimit == null \|\| newLimit.Value >= oldLimit.Value` -> return; test `SentWithSameValue_DoesNothing` (tests `:64-70`); Canvas A section states filter fires even when unchanged |
| Stage PreOperation, write on `ctx.Request.Target` | met | plugin `:17` `.PreOperation()`, `:38` `target.Description = ...`; check "step registered ... PreOperation/Synchronous" ok; check "no UserService.Update/Create" ok; tests assert `crm.GetAll("account")` empty (tests `:36`) |
| Tests supply the pre-image and cover lowered, raised, same, cleared | met | `Run()` uses `.WithPreImage(preImage)` (tests `:31`) and `PluginPipeline` (registered image) for 3 tests; cases `Lowered_SetsDescription`, `Raised_DoesNothing`, `SentWithSameValue_DoesNothing`, `Cleared_DoesNothing` (+ set-from-empty, not-sent, pipeline) |
| Human answer honoured: cleared / set-from-empty is not lowered | met | plugin `:32` null guards; tests `Cleared_DoesNothing`, `SetFromEmpty_DoesNothing`; Canvas decisions line 36, assumption line 42 |
| Solution / prefix ZavaSales / zava | met | Canvas `solution: ZavaSales`, `publisher_prefix: zava`; project `zava.Plugins` |
| SC1: CS0260 avoided or seen and fixed via `partial` | met | avoided: class `partial` from commit `4519501`; no CS0260 in any build log |
| SC2: RED then GREEN over the four cases; no write when value did not go down | met | Grader re-ran the RED commit `6033870` in a clone (`redcheck/`): `Total: 9, Errors: 0, Failed: 3` (the 3 lowering cases FAIL); GREEN: checks.json "tests re-run green" total=9 failed=0; no-op tests assert `!target.Contains("description")` and pipeline `Pipeline_Raised_LeavesDescription` keeps "orig" |
| SC3: build clean of VELA00x; `vela-code-review` PASS | met | checks "build succeeds", "no VELA diagnostics"; `build-release.log` 0 Warning(s) 0 Error(s); Canvas Evidence lines 118-124: PASS, 0 Critical / 0 Required / 6 Nits (diff reviewed saved in `work/review-diff.txt`) |
| Stop before apply | met | Canvas `status: awaiting-apply`, `apply: pending`; `vela plan` skipped with exact command |

Note on evidence strength: the review verdict is attested only by the Canvas/actor report (the reviewer's raw output
was not saved, only the diff it reviewed). The findings list is itemised, which satisfies the pack's
"Reviewed" proof rule, but a saved reviewer transcript would be stronger.

## Planted-violation results
The scenario has no "Planted-violation check" section - none applied.

## Findings against the skills
1. minor - The pack gives no guidance for a stale NuGet cache that resolves the wrong framework version. `build1.log`
   shows `warning NU1603: zava.Plugins depends on Vela.Plugins (>= 0.29.6) but Vela.Plugins 0.29.6 was not found.
   Vela.Plugins 1.0.0 was resolved instead.` No file under `skills/`, `references/` or `agents/` mentions NU1603 or
   `--no-http-cache`. The actor diagnosed it and fixed it with `dotnet restore --force-evaluate --no-http-cache`.
   A less careful run could have tested against the wrong framework, and the result would still build.
   Suggested fix: in the scaffold or harness skill, treat NU1603 on `Vela.*` as a stop-and-fix, and give that restore command.
2. minor - The Build Report does not keep the reviewer's raw output. `AGENTS.md` asks for "the `vela-code-review`
   findings list", and the actor reproduced that list in the Canvas, so the claim cannot be checked on its own.
   Suggested fix: `vela-code-review` could require saving the reviewer's verbatim reply next to the Build Report.

No blocker findings.

## Fixes
- none yet

## Verdict
**pass**. Checks 14/14, and every scenario criterion is met by the artifacts. The grader re-ran the RED commit and it failed as the actor reported.
The next run must re-check two things: RED evidence is recoverable (a RED commit or saved log), and the NU1603 cache trap does not silently pass.
