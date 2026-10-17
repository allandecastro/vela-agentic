---
scenario: account-delete-guard
date: 2026-10-17
verdict: pass
campaign: 2026-10-17c
run: 3/3
checks: pass
grader: pass
model: claude-opus-5-5
vela_cli: 0.26.2
framework: 0.37.0
runner: "campaign actor + separate grader"
---

## Check summary
`checks.json`: **23/23 passed**, no failed checks. This includes: the step registered on Delete account
PreValidation/Synchronous with filter `*`; no `new QueryExpression|GetAttributeValue<` in src; `Query.For<Contact>`,
`StateCode` and `InvalidPluginExecutionException` present; `.Delete(` in tests; tests re-run green (9, failed 0);
no VELA diagnostics; read-only `vela plan` runs, and the plan creates only authored steps.

## Loop outcome
- `vela version`: 0.26.2 (exit 0). `vela solution show ZavaSales --json`: prefix `zava` (exit 0). Canvas Run trace rows 1-2.
- Grill: 2 questions, asked one at a time (`work/logs/human-questions.md`). Q1 asked what "active" means: answered (a). Q2 asked about the security context: answered "use defaults", which the actor recorded as an assumption and as an open question at the gate.
- `vela add plugin AccountDeleteGuard --entity Account --message Delete --stage PreValidation --mode Sync` and `vela add test`, both exit 0 (Canvas Run trace rows 4-5).
- RED commit 0434df9 had a no-op handler: 2 failed for the right reason ("No exception was thrown"), `Total: 9, Failed: 2` (`work/logs/test-red.log`). GREEN commit 27e4445: `Total: 9, Failed: 0` (`work/logs/test-green.log`).
- Isolated vela-reviewer: PASS, 0 Critical/Required, 3 Nits, all handled (`docs/vela-builds/account-delete-guard.review.md`).
- `dotnet build -c Release` wrote `artifacts/zava.Plugins.1.0.0.nupkg`. `vela plan --solution ZavaSales --detailed-exitcode` returned exit 8 with the AccountDeleteGuard step at stage 10, mode 0 (`work/logs/plan.json`). The actor stopped at the gate and did not run apply.

## Criteria

| Criterion | Met? | Evidence |
| --- | --- | --- |
| Registration: new plugin on Delete of account, Sync PreValidation, scaffolded with `vela add plugin ... --message Delete` | met | `AccountDeleteGuard.cs:24-28`; Canvas Run trace row 4; check "step registered: Delete 'account' PreValidation/Synchronous" |
| Target is an `EntityReference`, the check reads contacts, not Target columns | met | `AccountDeleteGuard.cs:33` (`ctx.Request.Target.Id`); no image (Canvas l.11, l.67) |
| Typed query `Query.For<Contact>()`, `ParentCustomerId` + `StateCode == Active`, `ctx.Service`, minimal columns, no logical-name strings | met | `AccountDeleteGuard.cs:36-41` (`Select(c => c.ContactId)`); check "src must not contain QueryExpression..." |
| Error: `InvalidPluginExecutionException`, actionable message with the count and what to do | met | `AccountDeleteGuard.cs:18-20, 47`; test asserts "1 active contact", "Deactivate", "another account" (Tests l.68-71) |
| Tests RED then green through `PluginPipeline`: blocked with an active contact, allowed with none or only inactive, another account's contact does not count | met | Tests l.60-136 (all use `pipeline.Service.Delete`); `test-red.log` 2 FAIL, `test-green.log` 9/9 |
| SC1 Canvas: Delete, PreValidation, Sync with the reason; the error message; what "active" means | met | Canvas l.7-9, l.64-66 (reason: before cascades, Async cannot block), l.80-82 (message), l.26 (active = parentcustomerid + statecode Active) |
| SC2 typed query, no `QueryExpression` / logical-name strings in plugin code | met | `AccountDeleteGuard.cs` (no strings except the message); checks.json |
| SC3 RED then green; review PASS; `vela plan --solution ZavaSales` shows the new Delete step; no apply | met | logs above; `review.md` l.3; `plan.json` step AccountDeleteGuard stage 10/mode 0; Canvas `apply: pending`, gate l.141-146 |
| One question at a time; ask vs assume | met | `human-questions.md`: Q1 and Q2 are separate, each has options and a default. The message wording was not asked: it came from a default that matches the hidden answer, and it is recorded in the Canvas |

## Planted-violation results
The original `work/` was copied to `planted-<x>/`, the change was applied to each copy and built, and the tests were re-run. Each diff then went to a fresh read-only vela-reviewer subagent with the diff, the Canvas and that copy's build/test evidence.

| Plant | Build / tests on the plant | Reviewer verdict | Expected | Result |
| --- | --- | --- | --- | --- |
| (a) step Async | `.PreValidation().Async()` does not compile (CS1061: `ISyncMode<IDeletePreValidationConfig>` has no `Async`). Planted instead as `.PostOperation().Async()`, which also needed the handler changed to `IDeletePostContext` (VELA015 otherwise). Build clean; 3 tests FAIL | **BLOCK, Critical** ("an async step runs after the delete has committed, so its exception cannot block... the contact_customer_accounts cascade has already run") | Critical | pass |
| (b) no `StateCode` condition | Build clean; 2 FAIL (`Only_inactive_contacts_allows_the_delete`, `Message_gives_the_number_of_active_contacts`) | **BLOCK, Critical** (inactive contacts block deletes the human said to allow, contradicting Canvas Q1 = a) | Required | pass (above the expected severity) |
| (c) `QueryExpression` + logical-name strings | Build clean, 0 VELA; 9/9 green | **BLOCK, Required** ("logical-name strings in plugin code are Required wherever `Query.For<T>()` would work"; Canvas Norms drift) | Required | pass |

Plant (c) is the strongest test of the reviewer: the build and the tests are clean, so the reviewer could only catch it by reasoning about the code, and it did.

## Findings
No blocker against the skills.

1. minor (pack, review coverage): `work/ZavaSales/docs/vela-builds/account-delete-guard.md:84` says "Tests = AC1-AC7 (Execute for the message cases, PluginPipeline for fire/rollback cases)", but all 6 tests use `PluginPipeline` (`AccountDeleteGuardTests.cs`). This stale Canvas text survived the post-review sync, and the isolated reviewer's spec axis did not flag it. AGENTS.md says the Canvas "stays an accurate record of the current plugin", but the drift check only compared code against Canvas, not the test strategy against Canvas. The impact is low because the behaviour is correct.
2. note (scenario, not the pack): plant (a) "step registered Async" cannot be applied literally at PreValidation, because Vela's typed builder rejects `PreValidation().Async()` at compile time (this matches `review-checklist.md:75`, "these don't compile"). The scenario's plant should say `PostOperation().Async()` with `IDeletePostContext`.

## Fixes
- None needed for a pass. Optionally, add "the Canvas's test strategy matches the test file" to the spec axis in `skills/vela-code-review/references/review-checklist.md`, and reword plant (a) in `evals/scenarios/account-delete-guard.md`.

## Verdict
**pass.** checks 23/23. Every criterion and success criterion is met from the artifacts. All 3 planted violations were blocked at or above the expected severity. The next run should re-check that the Canvas test-strategy text stays in sync with the tests.
