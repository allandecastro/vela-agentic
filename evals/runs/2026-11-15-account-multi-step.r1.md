---
scenario: account-multi-step
date: 2026-11-15
verdict: pass
campaign: 2026-11-15
run: 1/1
checks: pass
grader: pass
model: claude-opus-5-5
vela_cli: 0.29.0
framework: 0.42.0
runner: "campaign actor + separate grader"
---

## Checks
21/21 passed (`checks.json`), no failed check. Notable: Update step `account` PreOperation/Synchronous
filter=['name']; exactly 2 authored steps; `OnDescriptionDefault` kept; new handler named after its
behaviour; no `Service.Update/Create` write-back; `PluginPipeline` in tests; tests re-run green 14/0;
no VELA diagnostics; read-only `vela plan` runs and creates only authored steps.

## Loop outcome
- plan-review: Canvas `docs/features/account-number-uppercase/README.md` + rule ACC-002 (C1-C10) in `docs/rules/account.md` (commit 8e63dc0).
- scaffold: `vela add step AccountDefaultDescription --entity Account --message Update --stage PreOperation --mode Sync --filtering-attributes Name --handler OnAccountNumberUppercase` → 0; pre-image added by hand (the CLI has no image flag); `vela add test ... --message Update` → 0.
- models: `vela models --verify --entities account,contact` → 0, in sync.
- RED: Total 14, Failed 4 (C1, C3, C6, C9 on the value) - `.vela-runs/account-number-uppercase/red.log`.
- GREEN: Total 14, Failed 0 (Mono + xunit.console `-parallel none`) - `green.log`; mutants killed by C4 / C8.
- verify: Release build 0 warnings / 0 errors / 0 VELA; spec-check 0 failures.
- review: isolated vela-reviewer PASS, 0 Critical/Required, 3 Nits (`review.md`).
- preview: `vela solution show ZavaSales` → zava (0); `vela plan ... --solution ZavaSales --detailed-exitcode` → 8 (changes: package + Create + Update steps). Stopped before apply.

## Criteria
| Criterion | Met? | Evidence |
| --- | --- | --- |
| Reuse via `vela add step AccountDefaultDescription --entity Account --message Update` | met | trace.md row 2; one class `AccountDefaultDescription.cs:10`; check "exactly 2 authored step(s)" |
| Handler named after the behaviour; `OnDescriptionDefault` kept | met | `AccountDefaultDescription.cs:20,28` (`OnDescriptionDefault`, `OnAccountNumberUppercase`); checks for both handlers |
| Filter on `e => e.Name`, no placeholder | met | `AccountDefaultDescription.cs:25` `FilterOn(e => e.Name)` (flag route `--filtering-attributes Name`); check "step registered: Update ... filter=['name']" |
| Stage PreOperation on `ctx.Request.Target` | met | `AccountDefaultDescription.cs:23,40,52`; check "no Service.Update/Create" |
| Harness: every test states its trigger; Create tests updated and green | met | tests `:17` `.OnCreate()` on the PluginContext path; ACC-002 tests go through `PluginPipeline` (needs no trigger per harness-api.md:43-46); ACC-001/C1-C3 green in green.log |
| SC1 Canvas records `reuse: add-step:AccountDefaultDescription` and the Update step | met | Canvas README.md:20-22 |
| SC2 gated on gating column; build green, no VELA00x | met | checks "build succeeds", "no VELA diagnostics"; build-verify.log |
| SC3 RED then green: name changed → uppercased; name unchanged → not run; Create cases pass | met | red.log (C1 failed on value), green.log 14/0; C5 `Assert.Empty(pipeline.ExecutionLog)` (tests:110); C4 sent-unchanged → untouched; ACC-001/C1-C3 + C10 green |
| SC4 `vela-code-review` PASS | met | `.vela-runs/account-number-uppercase/review.md:3` "Verdict: PASS" |
| Ask-vs-assume (human answers) | met | no question asked (`logs/human-questions.md` absent); the assumptions recorded (Canvas:42-47) match the evaluator answers ("sent with a different value", null number stays null - C7); solution/prefix taken from PROJECT.md and confirmed by `vela solution show` |
| Stop before apply | met | Canvas `apply: pending`, gate section; no apply in trace |

## Planted-violation results
The scenario has no "Planted-violation check" section - none run.

## Findings against the skills
No blocker. Minor:
1. minor - the actor ran `sh evals/setup/baseline.sh <work>` before noticing the baseline was already in place (exit 2, no change; actor-report "Workspace"). It's an actor/harness-prompt slip, not a skill defect: no skill sent it there. Recorded so the campaign prompt keeps saying the baseline is pre-provisioned.
2. minor - the Canvas's acceptance cases include ACC-002/C9 "Name cleared", which the actor's own assumption (Canvas:46) says Dataverse refuses because Name is required. A required-column case that can't happen still got a test and a RED. `vela-plan-review` could say to drop impossible cases rather than test them "for completeness". It's harmless here.
3. minor (pre-existing, not this run) - `OnDescriptionDefault` still carries the scaffold `// TODO: implement your logic` comment (`AccountDefaultDescription.cs:67-68`), inherited from the baseline. The reviewer didn't flag it. `vela-code-review` could treat a leftover scaffold TODO in a touched class as a Nit.

## Verdict
pass - 21/21 checks, every scenario criterion met, review PASS, stopped at the apply gate. The next run should re-check the
same flag route (`--filtering-attributes` + `--handler`) and that the ACC-001 tests keep an explicit trigger.
