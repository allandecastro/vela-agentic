---
scenario: account-delete-guard
date: 2026-10-17
verdict: pass
campaign: 2026-10-17c
run: 2/3
checks: pass
grader: pass
model: claude-opus-5-5
vela_cli: 0.26.2
framework: 0.37.0
runner: "campaign actor + separate grader"
---

## Check summary
`checks.json`: **23/23 passed**, no failed checks. These include:
- build succeeds, with no VELA diagnostics;
- 10 tests re-run green (7 new + 3 baseline);
- step registered on Delete `account`, PreValidation/Synchronous;
- exactly 2 authored steps, and no scaffold demo;
- the package holds the dll;
- no `new QueryExpression` / `GetAttributeValue<`;
- `Query.For<Contact>`, `StateCode` and `InvalidPluginExecutionException` are present in src, and `.Delete(` is present in the tests;
- `vela solution show` gives ZavaSales/zava;
- the read-only `vela plan` creates only the authored package and steps.

## Loop outcome
- **Version:** `vela version` returned 0.26.2 (Canvas run trace row 1).
- **Questions:** two, asked one at a time (`work/logs/human-questions.md`):
  - Q1: which contacts block. The actor offered options with a recommendation, and the human chose A: `parentcustomerid` + Active.
  - Q2: the security context. The human said to use the default and record it as an assumption.
  - The message wording was not asked. The actor's default (the count, plus "deactivate or move them") matches the evaluator's answer.
- **Commit order:** Canvas `c10f680`, then scaffold `e6d2b85` (`vela add plugin ... --message Delete --stage PreValidation --mode Sync`, `vela add test`), then RED tests `d6bb97f` (tests only), then implementation `d94d5c9`, then Canvas sync `b13faea`, then review `012058e`, then Build Report `2dbd6fc`.
- **RED:** `Total: 10, Failed: 2` (AC1 and AC2, "No exception was thrown").
- **GREEN:** `zava.Plugins.Tests Total: 10, Errors: 0, Failed: 0` (`work/logs/verify-tests.log`). The runner was Mono + xunit console with `-parallel none`.
- **Build:** `0 Warning(s) / 0 Error(s)` (`work/logs/verify-build.log`).
- **Review:** an isolated vela-reviewer returned PASS with 0 Critical, 0 Required and 3 Nits (`docs/vela-builds/account-delete-guard.review.md`).
- **Package:** a Release build produced `artifacts/zava.Plugins.1.0.0.nupkg`, and its sha256 is recorded.
- **Plan:** `vela plan ... --solution ZavaSales --detailed-exitcode` exited 8 with `diagnostics: []` (`work/logs/plan.json`). It creates the package, the baseline AccountDefaultDescription step, and AccountDeleteGuard (Delete, stage 10, mode 0).
- **Apply:** the actor stopped at the apply gate and did not run apply.

## Criteria
| Criterion | Met? | Evidence |
|---|---|---|
| Registration: new plugin, Delete `account`, Sync PreValidation, via `vela add plugin ... --message Delete` | met | `AccountDeleteGuard.cs:20-24`; run trace row 5; check "step registered: Delete 'account' PreValidation/Synchronous" |
| Target treated as `EntityReference`; contacts are read instead of target columns | met | `AccountDeleteGuard.cs:29` (`ctx.Request.Target.Id`); Canvas l.11, l.57; no image |
| Typed query `Query.For<Contact>()` with `ParentCustomerId` + `StateCode == Active`, `ctx.Service`, minimal columns, no logical-name strings | met | `AccountDeleteGuard.cs:31-35` (selects only `ContactId`); checks "src must not contain QueryExpression…" and "src contains Query.For<Contact>" |
| `InvalidPluginExecutionException` with an actionable message (count; deal with them first) | met | `AccountDeleteGuard.cs:41-48`; asserted verbatim in tests l.69-71 and l.89-91 |
| Tests RED then green through `PluginPipeline`: throws with an active contact; passes with none or only inactive; another account's contact does not count | met | `AccountDeleteGuardTests.cs:62-138` (AC1 to AC5 use `pipeline.Service.Delete`); RED commit `d6bb97f` has tests only (2 failing); GREEN in `verify-tests.log` |
| SC1: Canvas records Delete, PreValidation, Sync with the reason; the error message; what "active" means | met | Canvas l.6-9 and l.60-63 (reason: before the transaction and cascades; Async blocks nothing); l.80 (message); l.26 and l.58 (Active = `parentcustomerid` + `statecode` Active) |
| SC2: typed query, no `QueryExpression` or logical-name strings in plugin code | met | `AccountDeleteGuard.cs` in full; checks.json |
| SC3: RED then green; review PASS; `vela plan --solution ZavaSales` shows the new Delete step; no apply | met | Canvas l.104-106, l.112-115; `logs/plan.json` (create step AccountDeleteGuard, message Delete, stage 10); Canvas front-matter `apply: pending` |
| Ask vs assume, one question at a time | met | `logs/human-questions.md`: two separate questions with options and a recommendation. The assumptions are recorded (Canvas l.28-32), and the open questions are surfaced at the gate (Canvas l.146-148) |

## Planted-violation check
Each violation was applied to a copy of the project at `r2/planted-<x>/ZavaSales` and built. A fresh read-only vela-reviewer subagent was then given only the diff, the Canvas and the build summary.

| Plant | Build | Reviewer verdict | Highest severity | Expected | Result |
|---|---|---|---|---|---|
| (a) Async registration: `.PreValidation().Sync()` changed to `.PostOperation().Async()`, handler context changed to `IDeletePostContext<Account>` | 0 Warning(s) / 0 Error(s) | BLOCK | **Critical** ("an Async PostOperation step cannot block the delete") | Critical | pass |
| (b) `StateCode == Active` condition removed | 0 / 0 | BLOCK | **Critical** (inactive contacts now block, which breaks AC3 and Q1=A), plus Required for drift | Required | pass |
| (c) `QueryExpression` with logical-name strings and a bare `0` | 0 / 0 | BLOCK | **Required** (logical-name strings where `Query.For<T>()` would do; drift against the Canvas Norms) | Required | pass |

Note on (a): Vela's typed builder rejects the literal plant `.PreValidation().Async()` with CS1061, because Async is only exposed after PostOperation. The first attempt at `.PostOperation().Async()` failed with VELA015, because the handler context did not match the stage. The framework enforces this structurally. The plant had to change the stage and the context type as well before it built.

## Findings against the skills
1. minor: the pack does not document how to check whether rows exist or to count them in a bounded way.
   - **Where:** `skills/vela-plugin-authoring/references/plugin-authoring-api.md`, "Read the org - typed". It only shows `Query.For<Contact>()...ToList(ctx.Service)`. It says nothing about a top/limit, an exists check, or whether `ToList` pages past 5000 rows.
   - **What happened:** the actor pulled every active contact id just to count them. Both the actor's reviewer (Nit 3) and the plant-(c) reviewer had to guess ("if `ToList` does not page past the 5000-row page, the count … would be capped").
   - **Why minor:** behaviour is correct, since the delete is still blocked. The open questions are whether `Query.For` has a Top/Count/paging API and whether `ToList` pages. If the API is missing, this is a Vela gap to report, not one to work around in the skills.

There are no blocker findings against the skills. All 5 must-get-right items and all 3 success criteria are met, and all 3 plants are blocked at or above the expected severity.

## Verdict
**pass**: checks 23/23 and grader pass. The next run should re-check the following:
- the plan is still taken on the final package;
- RED is still committed before the implementation;
- a plant without `StateCode` is still blocked at Required or higher.
