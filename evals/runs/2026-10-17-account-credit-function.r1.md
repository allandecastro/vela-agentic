---
scenario: account-credit-function
date: 2026-10-17
verdict: pass
campaign: 2026-10-17
run: 1/3
checks: pass
grader: pass
model: claude-opus-5-5
vela_cli: 0.26.0
framework: 0.35.0
runner: "campaign actor + separate grader"
---

## Checks
22/22 passed (`checks.json`); no check failed. Key ones: "exactly one custom API: function=True bound=True"
-> `zava_GetAvailableCredit`, in `[Amount, System.Decimal, optional=true]`, out `[AvailableCredit, System.Decimal]`;
"no dotted Custom API names"; "tests re-run green (>= 5)" total=13 failed=0; "src must not contain
Service.(Update|Create|Delete)"; "src must not contain SystemService"; "read-only vela plan runs";
"plan creates only authored steps".

## Loop outcome
1. `vela version` -> 0.26.0 (Canvas run trace #1).
2. `vela solution show ZavaSales --json --url ...` -> exit 0, prefix `zava` (solution taken from the baseline Canvas).
3. Grill: Q1-Q4 to the human, one per turn (`work/logs/human-questions.md`).
4. Canvas committed first (327400c).
5. `vela add customapi GetAvailableCredit --bound --entity Account --function --project ...` -> exit 0, `zava_GetAvailableCredit`.
6. `vela add test GetAvailableCredit --kind customapi --entity Account` -> exit 0.
7. RED (6dce697): mono xunit `-parallel none`, exit 1, `Total: 13, Failed: 8` (8 behaviour tests; the 2 definition tests passed because the registration was committed with the tests).
8. GREEN (6e0ea25): `Total: 13, Failed: 0`.
9. `dotnet build -c Release`: 0 warnings, 0 errors, 0 VELA.
10. Isolated vela-reviewer: PASS, 0 Critical/Required, 2 Nits (`work/review/reviewer-output.md`).
11. `vela plan -p artifacts/zava.Plugins.1.0.0.nupkg --solution ZavaSales --detailed-exitcode` -> exit 8, no diagnostics: create custom-api (isFunction true, bound account, Amount optional System.Decimal -> AvailableCredit System.Decimal), create package, create baseline step.
12. Stopped at the apply gate (`apply: pending`), with an open question on shipping the not-yet-deployed baseline step.

## Criteria
| # | Criterion | Met? | Evidence |
|---|---|---|---|
| 1 | Routing: a called operation -> `vela-custom-api`, not a step | yes | Canvas `account-available-credit.md:72` "Custom API, not a step"; `skills:` line 53; check "exactly one custom API" passed, plan has no new authored step for this story. |
| 2 | Kind Function, with the reason (read-only, called from JS, no flow) | yes | Canvas lines 21-22 (`kind: function`, `callers: [web-api]`), 50 (assumption: no flow named, kind immutable), 74-75. Plan `isFunction: true`. |
| 3 | Bound to account; typed scaffold `vela add customapi <Name> --bound --entity Account --function` | yes | Canvas lines 20, 79, run trace #5; `GetAvailableCredit.cs:18-19` `.AsFunction().BoundTo<Account>()`. |
| 4 | Unique name `zava_<Name>`, nothing dotted | yes | `GetAvailableCredit.cs:15` `zava_GetAvailableCredit`; check "no dotted Custom API names". |
| 5 | One optional decimal input mapped with `optional: true`, default recorded | yes | `GetAvailableCredit.cs:21-22`; Canvas lines 23, 65 ("Amount absent = 0"); plan `isOptional: true`. |
| 6 | One output mapped in `.Response(...)`, placeholder `Result` replaced, every declared property mapped | yes | `GetAvailableCredit.cs:23, 96-101`; plan output `AvailableCredit System.Decimal` only. |
| 7 | Target from the request; only `creditlimit` retrieved with `ctx.Service`; no `SystemService`; writes nothing | yes | `GetAvailableCredit.cs:34-37`; checks "no SystemService", "no Service.(Update/Create/Delete)"; tests `Never_Changes_The_Account`, `Never_Writes_Through_The_Org_Service`. |
| 8 | Errors via `InvalidPluginExecutionException` with actionable messages; no error code in output | yes | `GetAvailableCredit.cs:28-31, 39-42`; messages match human answers Q1/Q2. |
| 9 | Canvas records error cases, input default, output | yes | Canvas lines 23-24, 30-38, 40-42. |
| 10 | RED then green: 1000/none -> 1000; 1000/300 -> 700; no limit -> error; negative -> error; definition bound Function, one optional input, one output | yes | Tests `GetAvailableCreditTests.cs:57-100`; `logs/test-red.log` "Total: 13, Failed: 8" (commit 6dce697 before feat 6e0ea25); `logs/test-green.log` "Failed: 0"; check re-run total=13 failed=0. Definition tests passed at RED (registration committed with tests) - acceptable, the behaviour cases were RED. |
| 11 | Build clean of VELA00x | yes | check "no VELA diagnostics"; `logs/build-release.log` 0 warnings. |
| 12 | `vela-code-review` PASS | yes | `work/review/reviewer-output.md:8` "Verdict: PASS (no Critical / Required)", 2 Nits; Canvas decisions checked listed (line 12). |
| 13 | `vela plan --solution ZavaSales` shows the Custom API with expected parameters | yes | `logs/plan.json`: create custom-api `zava_GetAvailableCredit`, isFunction/isBound true, account, Amount optional System.Decimal -> AvailableCredit System.Decimal; exit 8; check "read-only vela plan runs". |
| - | One question at a time | yes | `logs/human-questions.md` Q1-Q4, one topic each, multiple choice. |
| - | Ask vs assume | yes | Asked the load-bearing edges (no limit, negative, over-reserve); did not ask what the story/baseline already stated (optional amount, solution `ZavaSales` from the baseline Canvas); currency recorded as an assumption (Canvas 46-47). Q4 (button scope) was a fair question, answered "defaults", recorded as an assumption (Canvas 45). |
| - | Stop before apply | yes | Canvas `apply: pending`, Gate section lines 159-164; no `vela apply` in the trace; extra open question on the not-yet-deployed baseline step. |

## Planted-violation check
Each plant was applied to a copy of the actor's project (`r1/planted-<x>/`) and built in Release: all three built with 0 warnings / 0 errors (analyzers catch none). A fresh read-only subagent acting as `agents/vela-reviewer.agent.md` got only the diff (`r1/planted-<x>.diff`) and the Canvas.

| Plant | Diff | Build / suite | Reviewer verdict | Expected | Result |
|---|---|---|---|---|---|
| (a) output left out of `.Response` | `.Response(r => r.Add(x => x.AvailableCredit))` -> `.Add(x => x.CheckedOn)`, new `CheckedOn` DateTime property set in Execute | 0 errors; suite 1/13 fail (definition test) | **BLOCK, Critical** (AvailableCredit silently not registered; floor Required raised by live-org tie-break) + Required (unplanned `CheckedOn` output) + Required (stale evidence) | Required | blocked |
| (b) input made required | `optional: true` -> `optional: false` | 0 errors; suite 2/13 fail | **BLOCK, Critical** (breaks "no Amount" and definition cases; callers without Amount rejected) + Required (Canvas drift) + Required (stale evidence) | Required | blocked |
| (c) handler updates the account | `ctx.Service.Update(... ["description"] = "Credit checked on ...")` | 0 errors; suite 2/13 fail (both read-only tests) | **BLOCK, Critical** (side effect in a Function, contradicts "never changes the account", overwrites description) + Required (stale evidence) | Critical | blocked |

All three plants were blocked at or above the expected severity.

## Findings against the skills
None blocking.

1. minor - the pack has no guidance for the client-side half of a story that names a form button. `skills/` has no skill or reference mentioning a button, form script or ribbon script (grep for "button|client script|web resource|JavaScript" over `skills/*/SKILL.md` returns nothing), although the CLI has `vela add form-script|ribbon-script`. The actor had to spend Q4 on scope and then cited a "pack default" ("build only the server side ... ribbon/form scripts are a preview feature this pack does not cover") that the pack does not state. The outcome was reasonable, but the default it invoked is invented. Suggest one line in `vela-plan-review`/`vela-custom-api`: the client-side caller (button/script) is out of scope by default; record it as an assumption and name the Function's call contract for the maker.
2. minor - severity of plant (a) and (b) is Critical, above the rubric's Required floor, via the reviewer's "drift + live-org misbehaviour -> higher severity" tie-break. Harmless (still blocks), but the same non-determinism noted in `2026-10-17-lead-score-custom-api.r1.md` finding 1.

Actor-side only (not pack defects): the reviewer's 2 Nits (loose `Assert.Contains("Decimal", ...)`; untested zero-limit assumption) were left unapplied, as allowed.

## Verdict
**pass.** Checks 22/22; every criterion met; all three planted violations blocked at or above the expected severity. The next run should re-check that the button/client-script scope is handled consistently (ask vs default) and that the definition-test-passes-at-RED pattern stays accepted.
