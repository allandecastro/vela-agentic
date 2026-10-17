---
scenario: account-delete-guard
date: 2026-10-17
verdict: pass
campaign: 2026-10-17c
run: 1/3
checks: pass
grader: pass
model: claude-opus-5-5
vela_cli: 0.26.2
framework: 0.37.0
runner: "campaign actor + separate grader"
---

## Loop outcome
- version: `vela version` -> 0.26.2. This is from the Build Report run trace (row 1). The installed CLI also reports 0.26.2.
- solution: `vela solution show ZavaSales --json` -> `{"solution":"ZavaSales","publisherPrefix":"zava"}` (exit 0).
- challenge: the actor asked the human one question (Q1, security context). The human answered "skills' default", and the actor used `ctx.Service`, recorded as an assumption.
- scaffold: `vela add plugin AccountDeleteGuard --entity Account --message Delete --stage PreValidation --mode Sync` (exit 0). `vela add test` (exit 0).
- model: `vela models --entities account,contact --verify` -> in sync (exit 0). The existing models were reused.
- RED: `Total: 11, Errors: 0, Failed: 3`. The 3 blocking cases failed with "No exception was thrown" (`logs/test-red.log`).
- GREEN: first run 12/12, final run 13/13 (`logs/test-green.log`).
- RED probes after review 1: OrderBy removed -> `Failed: 2`; unnamed substitution removed -> `Failed: 1`.
- review: review 1 BLOCK (1 Required, the name ordering was not falsifiable) -> fixed. Review 2 PASS with 5 Nits (`logs/review2/verdict.md`).
- preview: `dotnet build -c Release` -> 0 errors, 0 warnings. The package is `artifacts/zava.Plugins.1.0.0.nupkg`.
- plan: `vela plan --solution ZavaSales --detailed-exitcode` -> exit 8. It creates the package, the baseline step and the AccountDeleteGuard step (Delete, account, stage 10, mode 0). Diagnostics: none.
- apply: not run. The run stopped at the apply gate.

## Checks
23/23 passed (`checks.json`), none failed.

## Criteria

| # | Criterion | Met? | Evidence |
|---|---|---|---|
| R1 | Registration: Delete of account, Sync PreValidation, scaffolded with `vela add plugin ... --message Delete` | met | `AccountDeleteGuard.cs:22-24`; check "step registered: Delete 'account' PreValidation/Synchronous"; Build Report row 4 |
| R2 | Target is an EntityReference; the check reads the contacts, not the target's columns | met | `AccountDeleteGuard.cs:31` (`ctx.Request.Target.Id`); Canvas `images: []` |
| R3 | Typed query `Query.For<Contact>()`, ParentCustomerId + StateCode == Active, `ctx.Service`, minimal columns, no logical-name strings | met | `AccountDeleteGuard.cs:33-37,51-53` (`Select(c => c.FullName)`, `Top(5)`, `CountScalar`); checks "typed query", "StateCode", "no QueryExpression/GetAttributeValue" |
| R4 | `InvalidPluginExecutionException` with an actionable message (count; deal with the contacts first) | met | `AccountDeleteGuard.cs:48,63-65`: "...still has N active contact(s): ... Reassign these contacts to another account or deactivate them, then delete the account again." |
| R5 | Tests RED then GREEN through `PluginPipeline`: blocks with an active contact; passes with none or only inactive ones; another account's contact does not count | met | `AccountDeleteGuardTests.cs:51,145,158,171` use `p.Service.Delete`; `logs/test-red.log` (Failed: 3); `logs/test-green.log` (13/13) |
| S1 | Canvas: Delete, PreValidation, Sync with the reason; the error message; what "active" means | met | `docs/vela-builds/account-delete-guard.md:7-9`; A (l.67-71) gives the reason; O (l.81-84) the message; assumption l.33 "active = statecode == Active" |
| S2 | Typed query, no `QueryExpression` or logical-name strings in plugin code | met | `AccountDeleteGuard.cs` (whole file); the corresponding check passed |
| S3 | RED then GREEN; review PASS; `vela plan --solution ZavaSales` shows the new Delete step; no apply | met | RED/GREEN logs; `logs/review2/verdict.md` PASS; `logs/plan.json` operation `create step ...AccountDeleteGuard` (Delete, stage 10, mode 0); no apply in the run trace; Build Report `apply: pending` |
| H1 | One question at a time; ask vs assume | met | `logs/human-questions.md`: a single question (Q1). It gave both options and their consequences, and the default is recorded as an assumption. "Active" and the message wording were assumed, recorded (Canvas l.32-38), and match the evaluator's human answers |
| H2 | Target solution and prefix | met | `vela solution show` -> ZavaSales / zava; Canvas l.14-15 |

## Planted-violation check
Each planted violation was applied in a copy (`r1/planted-<x>/ZavaSales`, `work/` untouched) and built. A fresh subagent then reviewed it read-only as `vela-reviewer`. It was given the diff, the Canvas and the build summary. RED/GREEN lines were withheld, and the reviewer was told not to raise an "evidence missing" finding.

| Plant | Change | Build | Reviewer verdict | Expected | Result |
|---|---|---|---|---|---|
| a | Step made Async. `.PreValidation().Sync()` -> `.PostOperation().Async()`, handler moved to `IDeletePostContext<Account>` | 0 err / 0 warn | **BLOCK**, Critical: Async PostOperation cannot block the delete; it runs after the commit and the cascade | Critical | pass |
| b | `StateCode == Active` condition removed | 0 err / 0 warn | **BLOCK**, Critical: inactive contacts now block; Canvas drift that misbehaves on a live org. Also Required: prove the inactive tests go RED | Required | pass (higher) |
| c | Query rewritten as `QueryExpression` with logical-name strings and `GetAttributeValue` | 0 err / 0 warn | **BLOCK**, 3 Required: logical-name strings and a magic `0`; unbounded RetrieveMultiple (count capped at 5,000); Canvas drift | Required | pass |

Note on plant (a): `.PreValidation().Async()` does not compile (`CS1061`: `ISyncMode<IDeletePreValidationConfig<Account>>` has no `Async`). Keeping PreValidation with a PostOperation handler gives `VELA015`. Vela prevents an Async PreValidation step at compile time, so the closest legal plant is PostOperation Async.

## Findings
None against the skill pack. Every criterion and every planted violation came out as the skills prescribe.

Observations (not pack defects, for the user to relay to Vela if wanted):
- Vela itself: the build reports 0 warnings for plant (c). No analyzer flags `new QueryExpression("contact")` or `GetAttributeValue<string>("fullname")` when typed models exist, so only review (and the eval's grep check) enforces "typed query". This is a possible analyzer gap, not a skill defect.
- Actor quality: Build Report open question 3 points out that "deactivate them" leads the org's `contact_customer_accounts` cascade to remove those contacts once the delete goes through. This is a real product question, raised correctly rather than assumed.

## Fixes
- none needed

## Verdict
pass. Checks passed 23/23, every criterion was met, and all 3 planted violations were blocked (a Critical, b Critical, c Required). The next run should re-check that the RED evidence names the failing tests verbatim, and that the plan is run on the final package (this run: sha256 recorded, plan after the last code change).
