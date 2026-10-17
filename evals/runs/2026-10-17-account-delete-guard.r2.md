---
scenario: account-delete-guard
date: 2026-10-17
verdict: pass
campaign: 2026-10-17
run: 2/3
checks: pass
grader: pass
model: claude-opus-5-5
vela_cli: 0.26.1
framework: 0.36.0
runner: "campaign actor + separate grader"
---

## Check summary
`checks.json`: **23/23 passed**, none failed. The checks confirmed:
- the step is registered as Delete/account PreValidation/Synchronous;
- the code uses a typed query with `Query.For<Contact>` and `StateCode`, with no `QueryExpression` or `GetAttributeValue`;
- it throws `InvalidPluginExecutionException`;
- the tests go through `.Delete(`;
- the tests re-ran green (9 total, 0 failed);
- there are no VELA diagnostics;
- the plan creates only the authored steps.

## Loop outcome
- `vela version` returned 0.26.1. `vela solution show ZavaSales --json` exited 0 with prefix `zava`.
- The actor asked the human two questions, one at a time (`work/logs/human-questions.md`):
  - Q1: which contacts count, plus confirming that "active" means Status = Active.
  - Q2: the security context. The answer was "use the defaults", so the actor used calling-user reads and recorded that as an assumption.
- The Canvas was committed in 1b1e3d1, before any code.
- `vela add plugin AccountDeleteGuard --message Delete --stage PreValidation --mode Sync` and `vela add test` both exited 0.
- RED (6d7801c): `Total: 9, Errors: 0, Failed: 2`. The two blocking cases failed with "No exception was thrown" (`work/logs/test-red.log`).
- GREEN (e28805b), run with mono xunit `-parallel none`: `Total: 9, Errors: 0, Failed: 0` (`work/logs/test-green.log`).
- The Release build had 0 warnings, 0 errors and no VELA diagnostics.
- An isolated vela-reviewer returned **PASS** with 0 Critical, 0 Required and 5 Nits (`work/logs/review1/reviewer-output.md`).
- `vela plan --solution ZavaSales --detailed-exitcode` exited 8 (changes pending). It creates the package plus the steps AccountDeleteGuard (Delete, stage 10, Sync) and AccountDefaultDescription (baseline) (`work/logs/plan.json`).
  - The plan's rank-collision diagnostic comes from the VelaEvals fixture and is not a criterion here.
- No apply was run. The actor stopped at the gate.

## Criteria
| Criterion | Met? | Evidence |
| --- | --- | --- |
| Registration: new plugin, Delete of account, Sync PreValidation, scaffolded via `vela add plugin ... --message Delete` | met | `AccountDeleteGuard.cs:26-30`; Canvas l.107; check "step registered: Delete 'account' PreValidation/Synchronous" |
| Target is an `EntityReference`; the check reads contacts, not the target's columns | met | `AccountDeleteGuard.cs:35` uses only `ctx.Request.Target.Id`; Canvas l.12, l.59 |
| Typed query `Query.For<Contact>()` with `ParentCustomerId` + `StateCode == Active`, via `ctx.Service`, few columns, no logical-name strings | met | `AccountDeleteGuard.cs:39,45-51,57-59` (CountScalar on ContactId; Select FullName only); checks for the typed query, `StateCode` and no QueryExpression |
| `InvalidPluginExecutionException` with an actionable message (count + deactivate/move first) | met | `AccountDeleteGuard.cs:54,69-70`; matches the human's expected answer |
| Tests RED then green via `PluginPipeline`: blocks with an active contact; succeeds with none or only inactive; another account's contact does not count | met | `AccountDeleteGuardTests.cs:38,72,84,99`; test-red.log (2 FAIL), test-green.log (0 failed) |
| SC1 Canvas: Delete, PreValidation, Sync with the reason; the error message; what "active" means | met | Canvas l.8-10, l.63-66 (reason), l.110-112 (message), l.28 (active = statecode Active) |
| SC2 Typed query, no `QueryExpression` or logical-name strings in plugin code | met | check "src must not contain QueryExpression/GetAttributeValue"; source read (Canvas l.27 names `parentcustomerid` only in prose) |
| SC3 RED then green; review PASS; plan shows the new Delete step; no apply | met | test logs; reviewer-output.md PASS; plan.json op `create step AccountDeleteGuard` (Delete, stage 10, mode 0); Gate section, no apply in the trace |
| One question at a time; ask vs assume | met | human-questions.md: Q1 and Q2 asked separately. Unanswered points (security default, message wording) were recorded as assumptions (Canvas l.30-32) |

## Planted-violation results
Each violation was applied to a copy in `planted-<x>/ZavaSales` and built. A fresh subagent acting as the vela-reviewer (read-only) then reviewed the diff against the Canvas.

| Violation | Build | Verdict | Severity | Expected | Result |
| --- | --- | --- | --- | --- | --- |
| (a) step Async | `.PreValidation().Async()` does not compile (CS1061: the fluent API only offers Async at PostOp), so I planted the legal `.PostOperation().Async()` plus `IDeletePostContext` instead, which built clean | BLOCK | Critical (an async step cannot cancel the delete, and by PostOp the cascade has already run) | Critical | blocked |
| (b) `StateCode` condition removed | built clean | BLOCK | Critical (spec drift: inactive contacts would block, which breaks an acceptance case) | Required | blocked (at a higher severity than required) |
| (c) `QueryExpression` with logical-name strings | built clean | BLOCK | Required (string-built query and `GetAttributeValue`, plus an unbounded RetrieveMultiple) | Required | blocked |

## Findings against the skills
None. The pack produced a correct Delete guard with Sync PreValidation, a typed query, an actionable message and full edge tests. On the security context, `skills/vela-plan-review/SKILL.md` says "the plugin reads and writes as the step's user (`ctx.Service`) by default". The actor followed that default and recorded the hidden-contact cascade risk as an open question.

Scenario note, not a pack defect: planted violation (a) as written ("registered Async" at PreValidation) is now a compile error in Vela.Plugins 0.36.0. The scenario should say "PostOperation Async" so the violation builds.

## Verdict
**Pass.** Checks are 23/23, every criterion is met, and all three planted violations were blocked at the expected severity or higher. The next run should re-check that the reviewer still gives the Required/Critical drift finding for (b).
