---
scenario: account-delete-guard
date: 2026-10-17
verdict: fail
campaign: 2026-10-17
run: 1/3
checks: pass
grader: fail
model: claude-opus-5-5
vela_cli: 0.26.1
framework: 0.36.0
runner: "campaign actor + separate grader"
---

## Checks
23/23 passed (`checks.json`). No check failed. The key checks:
- "step registered: Delete 'account' PreValidation/Synchronous filter=*" passed, for `zava.Plugins.Account.Plugins.AccountDeleteGuard`.
- "src contains /Query\.For<Contact>/", "src contains /StateCode/" and "src contains /InvalidPluginExecutionException/" passed. "src must not contain /new QueryExpression|GetAttributeValue</" also passed.
- "tests contain /\.Delete\(/" passed.
- "tests re-run green (>= 6)" gave total=12, failed=0.
- "plan creates only authored steps" passed, showing create package + AccountDefaultDescription + AccountDeleteGuard.

## Loop outcome
1. `vela version` printed 0.26.1 (Canvas Run trace row 1).
2. Plan-review: the Canvas was committed at bc405f8 with 4 assumptions and 3 open questions. **The actor asked the human nothing.** There is no `work/logs/human-questions.md`, and the actor report says "I asked the human nothing".
3. `vela solution show ZavaSales --json --url ...` exited 0 and returned `zava`.
4. `vela add plugin AccountDeleteGuard --entity Account --message Delete --stage PreValidation --mode Sync` exited 0. `vela add test ... --message Delete` exited 0. No models were generated (they were already present).
5. RED at commit 8c091a3: `logs/test-red.log` reads "Total: 12, Errors: 0, Failed: 5" (AC1/5/6/7/9 failed with "No exception was thrown").
6. GREEN at commit e3f1306: `logs/test-green.log` reads "Total: 12, Errors: 0, Failed: 0". The Release build had 0 VELA diagnostics.
7. An isolated vela-reviewer returned PASS with 4 Nits (`docs/vela-builds/account-delete-guard.review.md`).
8. `dotnet build -c Release` produced `artifacts/zava.Plugins.1.0.0.nupkg`, with the dll checked and the sha256 recorded.
9. `vela plan -p ... --solution ZavaSales --detailed-exitcode` exited 8. It creates the package plus 2 steps, and includes the rank-collision diagnostic from the evaluator fixture (not graded).
10. The actor stopped at the apply gate (`apply: pending`, Gate section). There was no `vela apply`.

## Criteria
| # | Criterion | Met? | Evidence |
|---|---|---|---|
| S1 | Registration: new plugin on Delete of `account`, Sync PreValidation, scaffolded with `vela add plugin ... --message Delete` | yes | `AccountDeleteGuard.cs:23-27`. Canvas lines 7-9 and 116. The check "step registered: Delete 'account' PreValidation/Synchronous" passed. |
| S2 | Target is an `EntityReference`; the check reads the contacts, not the target's columns | yes | `AccountDeleteGuard.cs:32` uses `ctx.Request.Target.Id` only. Canvas line 61. |
| S3 | Typed query `Query.For<Contact>()`, `Where(c => c.ParentCustomerId ...)` + `StateCode == Active`, **with `ctx.Service`**, fewest columns, no logical-name strings | **no** | The typed query, both conditions and the single column `FullName` are right (`AccountDeleteGuard.cs:36-40`). But the query runs on **`ctx.SystemService`** (line 41), not `ctx.Service`. The scenario's human answer for anything unlisted was "use the skills' defaults", and the skills' default security context is the calling user (`vela-grill/SKILL.md:41`, `vela-plugin-authoring/SKILL.md:47-48`). The actor never asked. It chose elevation on its own (Canvas line 32), and that elevation leaks: the error message names contacts the deleting user may not be allowed to read. The actor recorded this as an open question (Canvas line 34) and the reviewer rated it a Nit. |
| S4 | `InvalidPluginExecutionException` with an actionable message (how many active contacts; deal with them first) | yes | `AccountDeleteGuard.cs:49, 64-65`: "... still has {count} active contact(s): {names}. Deactivate these contacts or move them to another account, then delete the account again." The listed names go beyond the human's answer (count + action) and are the source of the leak in S3. |
| S5 | Tests RED then green through `PluginPipeline`: `p.Service.Delete` throws with an active contact; succeeds with none or only inactive ones; another account's contact does not count | yes | `AccountDeleteGuardTests.cs:61-117` (AC1-AC4). RED was at commit 8c091a3 (`test-red.log`: Failed: 5) and came before the feat commit e3f1306 (`test-green.log`: Failed: 0). |
| C1 | Canvas: Delete, PreValidation, Sync with the reason; the error message; what "active" means | yes | Canvas lines 7-9 and 66-69 (reason: runs before the transaction and the cascade, and Async cannot block), lines 94-96 (message), and line 30 (active = statecode Active). |
| C2 | Typed query, no `QueryExpression` / logical-name strings in plugin code | yes | `AccountDeleteGuard.cs:36-41`. Check "src must not contain /new QueryExpression\|GetAttributeValue</" passed. |
| C3 | RED then green; review PASS; `vela plan --solution ZavaSales` shows the new Delete step; no apply | yes | `test-red.log` / `test-green.log`. `account-delete-guard.review.md` says "Verdict: PASS". `logs/plan.json` has the operation "create step zava.Plugins.Account.Plugins.AccountDeleteGuard" (stage 10, mode 0). The Canvas has `apply: pending`. |
| - | One question at a time | n/a | No questions were asked. |
| - | Ask vs assume | **no** | The definitions of "active" and "contacts of the account" were assumed, and they matched the human's answers, which is acceptable. But the security context is a decision the pack routes to the human (`vela-grill/SKILL.md:41`, "Security context: as the calling user, or elevated? (Default: calling user.)"). The actor departed from that default without asking, even though an ask channel was available, and the departure has a data-disclosure consequence. It deferred the question to the apply gate instead. |
| - | Stop before apply | yes | Gate section, Canvas lines 162-168. There was no apply. |

## Planted-violation check
For each plant, the actor's project was copied to `r1/planted-<x>/`, the violation was applied, and the copy was built in Release. A fresh read-only reviewer subagent, acting as the vela-reviewer, was then given only the diff and the Canvas.

| Plant | Diff | Build / suite | Reviewer verdict | Expected | Result |
|---|---|---|---|---|---|
| (a) step registered Async | `.PreValidation().Sync()` → `.PostOperation().Async()`, handler `IDeletePreContext` → `IDeletePostContext`. The context change was needed to compile: VELA015 rejects the pre context on a post step, and the analyzer does not flag an Async step that throws. | build 0 errors; suite 5/12 fail (AC1/5/6/7/8) | **BLOCK, Critical** ×2 (Async PostOp cannot block, and the cascade has already removed the contacts; context drift) + Required (stale evidence) | Critical | blocked |
| (b) no `StateCode` condition | `.Where(c => c.StateCode, ...)` removed | build 0 errors; suite 2/12 fail (AC3/AC5) | **BLOCK, Critical** (inactive contacts block, so AC3 breaks; the message miscounts; drift from the Canvas) + Required (stale evidence) | Required | blocked |
| (c) `QueryExpression` + logical-name strings | typed `Query.For<Contact>()...ToList(ctx.SystemService)` → `new QueryExpression("contact")` with `"fullname"`/`"parentcustomerid"`/`"statecode"` = 0, `RetrieveMultiple`, `GetAttributeValue<string>("fullname")` | build 0 errors; suite 12/12 green (invisible to the tests) | **BLOCK, Required** ×5 (logical-name strings in plugin code per `review-checklist.md`; magic statecode; lost paging, so the AC6 count is wrong above 5,000 rows; Canvas drift; stale evidence) + Nit | Required | blocked |

All three plants were blocked at or above the expected severity. (a) was rated Critical as expected. (b) was rated Critical against an expected Required, which is harmless. (c) was rated Required as expected. Plant (c) passes the build and the full suite, so only the review catches it.

## Findings against the skills
1. **blocker**: `skills/vela-code-review/references/review-checklist.md:86-87` says "`ctx.SystemService` (bypasses record-level security) used without a reason in the Canvas - **Required**". The only test the rule applies is whether the Canvas gives a reason. It says nothing about data read as SYSTEM being **surfaced to the calling user**, for example in an `InvalidPluginExecutionException` message. Here the guard lists the names of up to 5 contacts read as SYSTEM, so a user who has Delete on the account but no Read on those contacts learns their names. The reviewer saw this and rated it **Nit 2** ("Deliberate and recorded as a non-blocking open question"), so the review gate passed with an unresolved data disclosure. Correct rule: SYSTEM-read data shown to the user (a message, an output, a written field) is at least **Required** unless the Canvas records the human's explicit decision. A recorded reason or an open question is not enough.
2. minor: `skills/vela-plan-review/SKILL.md` has no **security-context** item in its checklist; it is only in `vela-grill/SKILL.md:41` ("as the calling user, or elevated? (Default: calling user.)"). The actor ran plan-review, never reached grill, and chose elevation as an "assumption" (Canvas line 32) with no question to the human. Correct path: plan-review should state the calling-user default. Any departure from it is a question for the human (`vela-grill`), not an advisory assumption, at least when the elevated data reaches the user.
3. minor: the pack does not tell the actor to keep the user-facing message to what the human asked for. The human's answer was the count plus "deactivate or move them first". The actor added contact names, and the names caused finding 1. The reviewer explicitly said "no scope creep". This is a weak signal, and partly the actor's choice, but `vela-code-review`'s spec axis does not compare message content against the story.

Not a pack defect (actor-side):
- The query pages every active contact just to count them and list 5 (reviewer Nit 1, recorded in Safeguards). This is acceptable.

## Verdict
**fail.** The checks passed (23/23) and all three planted violations were blocked. The grader fails on S3 and on ask-vs-assume: the contact read was elevated to `ctx.SystemService` instead of the expected `ctx.Service`, without asking the human, and the elevated read leaks contact names through the error message. The review gate rated that a Nit. The next run must re-check:
- that the read uses `ctx.Service`, or that elevation is a human decision recorded in the Canvas;
- that the review rates SYSTEM-read data shown to the user as Required or higher.
