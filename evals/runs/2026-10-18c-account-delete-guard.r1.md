---
scenario: account-delete-guard
date: 2026-10-18
verdict: pass
campaign: 2026-10-18c
run: 1/1
checks: pass
grader: pass
model: claude-opus-5-5
vela_cli: 0.27.1
framework: 0.39.0
runner: "campaign actor + separate grader"
---

## Check summary
`checks.json`: **23/23 passed**, no failed check. The checks covered the Delete/account PreValidation/Synchronous step, a typed `Query.For<Contact>`, `StateCode`, `BusinessError(`, a `.Delete(` call in the tests, a 9/9 green re-run, no VELA diagnostics, and a read-only plan that creates only the authored steps.

## Loop outcome
| step | what the actor did | exit / result |
|---|---|---|
| intake/challenge | vela-plan-review + vela-grill; 3 questions (`work/logs/human-questions.md`) | Q1 A, Q2 B (en+fr dictionary), Q3 "skill defaults" |
| version | `vela version` | 0, vela 0.27.1 |
| scaffold | `vela solution show ZavaSales --json` | 0, prefix zava |
| model | `vela models --verify --entities account,contact` | 0, in sync |
| scaffold | `vela add plugin AccountDeleteGuard --message Delete --stage PreValidation --mode Sync`; `vela add test` | 0 / 0 |
| RED | xunit console (Mono, `-parallel none`) | Total 9, Failed 2 (C1, C5: "No exception was thrown"), `logs/test-red.log` |
| implement / verify | `dotnet build -c Release` 0/0/0 VELA; GREEN Total 9, Failed 0 (`logs/test-green.log`); a mutation probe on C6 | 0 |
| spec-check | `tools/spec-check.py` | 0 failures |
| review | fresh vela-reviewer | PASS, 0 Critical / 0 Required / 3 Nits (`logs/review-r1.md`) |
| preview | Release build -> nupkg -> `vela plan --solution ZavaSales --detailed-exitcode` | 8 (changes): create package + AccountDefaultDescription + AccountDeleteGuard (stage 10, Sync) |
| apply | not run; Build Report gate section | stopped at the apply gate |

## Criteria
| criterion | met? | evidence |
|---|---|---|
| Registration: Delete account, Sync PreValidation, scaffolded with `vela add plugin ... --message Delete` | met | `AccountDeleteGuard.cs:19-21`; check "step registered: Delete 'account' PreValidation/Synchronous"; Canvas Run trace row 5 |
| Target is an EntityReference; the check reads contacts, not target columns | met | `AccountDeleteGuard.cs:37` (`ctx.Request.Target.Id` only); Canvas `images: []` |
| Typed query (`Query.For<Contact>`, `ParentCustomerId`, `StateCode == Active`), `ctx.Service`, minimal columns, no logical-name strings | met | `AccountDeleteGuard.cs:40-43` (`CountScalar(ctx.Service, c => c.ContactId)`); checks for "no QueryExpression/GetAttributeValue<" and `Query.For<Contact>` |
| Error: IPE with an actionable message (count, deal with the contacts first) | met | `AccountDeleteGuard.cs:30,49`; the test asserts `InvalidPluginExecutionException` with the exact text (`AccountDeleteGuardTests.cs:62-64`) |
| Tests RED then green through PluginPipeline: throws with an active contact; succeeds with none / only inactive; another account's contact does not count | met | C1-C5 at `AccountDeleteGuardTests.cs:52-125` use `p.Service.Delete`; commit order 719abfc (tests) before 03c1cc5 (logic); `logs/test-red.log` Failed 2, then `logs/test-green.log` Failed 0 |
| Localized message: `ctx.BusinessError("KEY", ...)`, source registered in `ConfigureServices`, en + fr, a test asserts the message | met | `AccountDeleteGuard.cs:26-32,49`; C1 asserts English, C5 asserts French (`AccountDeleteGuardTests.cs:64,123`); asked at design (Q2) |
| SC1 Canvas: Delete, PreValidation, Sync with reason; the error message; what "active" means | met | `docs/vela-builds/account-delete-guard.md:7-9,28,34,73-74`; rule ACC-002 in `docs/rules/account.md:3-25` |
| SC2 typed query, no QueryExpression / logical-name strings in plugin code | met | as above; checks pass |
| SC3 RED then green; review PASS; `vela plan --solution ZavaSales` shows the new Delete step; no apply | met | logs above; `logs/plan.json` op `create step AccountDeleteGuard` (stage 10, mode 0); apply pending (Build Report `apply: pending`) |
| Ask vs assume | met | asked the business decisions: contact scope, "active", the message language/source, the security context. Read the solution prefix with `vela solution show` instead of asking. The delegated defaults are recorded as assumptions (Canvas lines 31-38) |
| One question at a time | partly | Q1 and Q2 are each one decision plus a ride-along. Q3 bundles two independent decisions: the security context and the French wording. `vela-grill` SKILL.md:28 forbids this ("never two independent decisions"). This is actor drift, not a skill defect, and it did not change the outcome |

## Planted-violation check
Each violation was applied to a copy at `r1/planted-<x>/` and built (all three: `0 Error(s)`, `0 Warning(s)`, no VELA diagnostics). Each was then reviewed by a fresh vela-reviewer subagent that received only the diff and the Canvas.

| plant | expected | reviewer verdict | result |
|---|---|---|---|
| (a) `.PreValidation().Sync()` -> `.PostOperation().Async()` | Critical | BLOCK, Critical (Async runs after commit, so it cannot block, and the cascade has already run) + Required drift + Required evidence missing | blocked |
| (b) `StateCode == Active` condition removed | Required | BLOCK, Critical (inactive contacts block; contradicts Q1/C2) + Required evidence missing | blocked |
| (c) `QueryExpression("contact")` with logical-name strings, `RetrieveMultiple(...).Entities.Count` | Required | BLOCK, Required (logical-name strings / Canvas N drift) + Required unbounded RetrieveMultiple + Required evidence missing | blocked |

## Findings against the skills
No blocker or minor defects in the skill pack were found in this run.

Observations (not pack defects, so no change to the skills):
1. The actor reported that the `raw.githubusercontent.com/allandecastro/vela/main/docs/...` links return 404. The pack already fixed this at HEAD (e339e72): `grep raw.githubusercontent skills agents AGENTS.md` returns nothing. Nothing more to do.
2. Vela gap, reported only and not to be worked around in the skills: plants (a) and (c) both built with 0 VELA diagnostics.
   - (a) is a Delete PostOperation Async step whose only purpose is to throw a BusinessError.
   - (c) is `new QueryExpression("contact")` with logical-name strings in plugin code.
   - Today only the reviewer catches either one. An analyzer for "BusinessError thrown in an Async step" and one for "string-built query where a typed model exists" would move them to build time.

## Fixes
- none needed in the pack for this run.

## Verdict
**pass**: checks 23/23 and the grader passed. Every scenario criterion is met and all 3 planted violations were blocked at or above the expected severity. The next run must re-check that vela-grill keeps independent decisions in separate questions; Q3 here bundled the security context with the French wording.
