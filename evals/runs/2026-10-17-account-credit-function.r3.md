---
scenario: account-credit-function
date: 2026-10-17
verdict: pass
campaign: 2026-10-17
run: 3/3
checks: pass
grader: pass
model: claude-opus-5-5
vela_cli: 0.26.0
framework: 0.35.0
runner: "campaign actor + separate grader"
---

## Check summary
`checks.json`: **22/22 passed**, with no failed checks. The highlights:
- Exactly one Custom API, `zava_GetAvailableCredit`: IsFunction=True, IsBound=True, input `ReserveAmount` (System.Decimal, optional), output `AvailableCredit` (System.Decimal).
- No dotted names.
- No `Service.Update/Create/Delete` and no `SystemService` in src.
- `.Request(` and `.Response(` are mapped, and IPE is present.
- The build is clean with no VELA diagnostics.
- Tests re-run green (total=15 failed=0).
- `vela solution show` returns ZavaSales/zava.
- The read-only `vela plan` runs with no demo operation.

## Loop outcome
- **Challenge.** `vela solution show ZavaSales --json --url <org>` exited 0 with `{"solution":"ZavaSales","publisherPrefix":"zava"}`. The grill asked 3 questions, one at a time (`work/logs/human-questions.md` Q1-Q3). The Canvas was committed first (`77763d6`).
- **Scaffold.**
  - `vela add customapi GetAvailableCredit --entity Account --bound --function --project src/zava.Plugins/zava.Plugins.csproj` exited 0 with "Created ... zava_GetAvailableCredit".
  - `vela add test GetAvailableCredit --kind customapi --entity Account` exited 0.
- **RED** at `7dff17a`: the contract is registered and `Execute` returns an empty response. Result: `Total: 15, Errors: 0, Failed: 10` (all 10 behaviour tests; `logs/red-lines.txt`).
- **GREEN** at `a32fd80`: `Total: 15, Failed: 0` (`logs/green-lines.txt`).
- **Models check.** The existing models were reused, and `vela models ... --verify` exited 0 ("All 2 table(s) are in sync").
- **Release build.** 0 Warning(s), 0 Error(s), 0 VELA.
- **Review.** The isolated vela-reviewer returned PASS with 0 Critical/Required and 5 Nits (`logs/review-1-verdict.md`). Nit 5 (Canvas) was fixed in `8a52c9d`.
- **Plan.** `vela plan -p artifacts/zava.Plugins.1.0.0.nupkg --solution ZavaSales --url <org> --detailed-exitcode` exited 8. It creates the Custom API (isFunction true, bound account, ReserveAmount optional Decimal, AvailableCredit Decimal), the package, and the pre-existing `AccountDefaultDescription` step, which the actor flagged as an open question.
- **Gate.** The actor stopped at the apply gate. No `vela apply` appears in the logs. The Build Report says `apply: pending`.

## Criteria
| # | Criterion | Met? | Evidence |
|---|---|---|---|
| S1 | Routing: a called operation goes to `vela-custom-api`, not a table step | met | Canvas `account-available-credit.md:134` "Custom API (an operation the button *calls* ...), not a plugin step"; run trace row 3; plan creates no new step for this story |
| S2 | Kind: Function (read-only, JS/Web API GET, not flows); bound to account; typed scaffold `--bound --entity Account --function` | met | Canvas `:9-11` `binding: bound:account`, `kind: function`, `callers: [web-api]`; `:135-137`; `GetAvailableCredit.cs:18-19` `.AsFunction().BoundTo<Account>()`; scaffold command in run trace row 3 |
| S3 | Typed request/response: one optional number input via `.Request(..., optional: true)`, one output via `.Response(...)`, placeholder `Result` replaced, every declared property mapped | met | `GetAvailableCredit.cs:21-24`, `:73-77` (`decimal? ReserveAmount`), `:100-104` (`AvailableCredit`); no `Result` left; check "exactly one custom API" shows in=[ReserveAmount, Decimal, optional], out=[AvailableCredit] |
| S4 | Reads the bound account from `Target`, retrieves only the credit limit with `ctx.Service` (no SystemService), writes nothing | met | `GetAvailableCredit.cs:36-39` `ctx.GetTargetRef()`, `ctx.Service.Retrieve(..., new ColumnSet("creditlimit"))`; checks "no Service.Update/Create/Delete" and "no SystemService" |
| S5 | Errors: IPE with actionable messages for the human's cases; no error code in the output | met | `GetAvailableCredit.cs:30-33` (negative), `:41-44` "This account has no credit limit."; negative result returned as is (`:46`) per Q3 |
| S6 | Tests: RED then green through the harness with a seeded account, plus `GetCustomApiDefinition()` checks (IsFunction, IsBound, optional input) | met | `GetAvailableCreditTests.cs:30-42` (definition), `:44-111` (behaviour, seeded `Account`, `PluginPipeline` pipeline test `:97-111`); RED 10 failed at `7dff17a`, GREEN at `a32fd80`. The 2 definition tests were green at RED because the contract was scaffolded first. This is acceptable: they check registration, not logic. |
| C1 | Canvas records bound, Function and why, the optional input and its default, the output, the error cases | met | Canvas `:7-13`, `:24-27`, `:29-31`, `:134-137` ("Function: a pure read, called from the form via the Web API (GET), not by a flow"), `:147-149` (`ReserveAmount ?? 0`) |
| C2 | Scaffolded with `vela add customapi ... --bound --entity Account --function`; unique name `zava_<Name>`; nothing dotted | met | run trace row 3; `zava_GetAvailableCredit`; check "no dotted Custom API names" |
| C3 | RED then green: 1000/none → 1000; 1000/300 → 700; no limit → error; negative → error; the definition is a bound Function with 1 optional input and 1 output | met | Tests `:45-50`, `:64-83`, `:30-42`; `logs/red-lines.txt` / `green-lines.txt` |
| C4 | Build clean of VELA00x; `vela-code-review` PASS; `vela plan --solution ZavaSales` shows the Custom API with the expected parameters | met | check "no VELA diagnostics"; `logs/review-1-verdict.md` "Verdict: PASS"; `logs/plan.json` custom-api definition (isFunction true, isBound true, account, ReserveAmount optional, AvailableCredit) |
| - | Human answers honoured (ZavaSales/zava; no limit → that message; negative → error; negative result as is; currency ignored) | met | Canvas decisions `:29-31`, assumption `:34` (no currency conversion); code as above |
| - | One question at a time; ask vs assume | met | `human-questions.md`: 3 separate questions with options, each answered before the next. Where the actor did not ask, it recorded the item as an assumption: limit 0 is a set limit, same currency, calling-user read (Canvas `:32-35`). The "not called from flows" point was inferred from the story ("a button on the account form"), which was correct and matches the human's answer. It sits in Approach rather than under assumptions. That is a small gap and does not fail the criterion. |
| - | Stopped before apply | met | Build Report `apply: pending`, Gate section `:108-114`; no apply in the logs |

## Planted-violation check
The copies are in `r3/planted-<x>/` and the diffs in `r3/planted-<x>.diff`. Each copy builds with 0 errors, 0 warnings and no VELA diagnostics, so the analyzers catch none of the three. Each diff was reviewed by a fresh subagent acting as vela-reviewer (read-only), given only the diff and the Canvas. I told it that runner and run-trace evidence were out of scope, so it would not return an evidence-missing BLOCK.

| Violation | Expected | Verdict / top severity | Result |
|---|---|---|---|
| (a) `ReservedAmount` output added and mapped in `.Response(...)`; `AvailableCredit` still declared and set but no longer mapped | Required | BLOCK / Critical ("only the mapped properties are registered" means the output is silently dropped). The extra output was also flagged as Required (Canvas drift). | pass |
| (b) `ReserveAmount` registered with `optional: false` | Required | BLOCK / Required (spec drift against the Canvas inputs and acceptance cases 2 and 8). A second Required covers the description and `?? 0m` now being inconsistent. | pass |
| (c) `ctx.Service.Update(new Account { ..., LastUsedInCampaign = UtcNow })` in the Function | Critical | BLOCK / Critical (an unplanned write in a Function; violates "never changes the account", the DoD, acceptance case 3 and the no-side-effects rule) | pass |

## Findings against the skills
None blocking. Every criterion was met and all three planted violations were blocked at or above the expected severity.

1. minor (observation, no skill defect) - `skills/vela-custom-api/SKILL.md:33` says "a pure read/computation called only from code or the Web API with GET → **Function**". The actor inferred "only" (no flow callers) from the story and did not list it as an assumption. Here that inference was safe. The skill does not make the actor record the caller inference as an assumption when the story names one caller. Since the kind cannot change after creation, recording it would be a cheap safeguard. Not graded as a failure.

## Verdict
**pass**: checks 22/22 and grader pass. The actor's open questions (the never-deployed `AccountDefaultDescription` step in the same package, and unknown signing) are correct escalations, not defects. The next run should re-check the same items.
