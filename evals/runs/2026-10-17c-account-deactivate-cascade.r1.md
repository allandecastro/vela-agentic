---
scenario: account-deactivate-cascade
date: 2026-10-17
verdict: fail
campaign: 2026-10-17c
run: 1/3
checks: pass
grader: fail
model: claude-opus-5-5
vela_cli: 0.26.2
framework: 0.37.0
runner: "campaign actor + separate grader"
---

## Check summary
`checks.json`: **25/25 passed**, no failed check. Note: `tests contain /SetStateRequest/` passed only on a
comment (`AccountDeactivateCascadeTests.cs:111` "SetStateRequest-shaped Update"); no test executes a
`SetStateRequest` (see criterion 5). The check is too weak - it should match `new SetStateRequest`.

## Loop outcome
- intake: `vela version` 0.26.2 (Canvas run trace #1); Q1-Q4 asked one at a time, Q5 after review 1 (`logs/human-questions.md`).
- solution: `vela solution show ZavaSales --json` exit 0, prefix `zava`; models `--verify` exit 0 (in sync).
- scaffold: `vela add plugin` / `vela add test` exit 0.
- RED: `logs/test-red.log` "Total: 15, Errors: 0, Failed: 7"; GREEN: `logs/test-green-3.log` "Total: 16, Failed: 0".
- review: 3 fresh reviewers - BLOCK (Required, unreadable contacts -> Q5 + AC11), BLOCK (actor hand-copy error in pasted material), PASS (`logs/review-3-output.md`).
- package: `dotnet build -c Release` -> `artifacts/zava.Plugins.1.0.0.nupkg`; `vela plan --solution ZavaSales --detailed-exitcode` exit 8: create package + AccountDeactivateCascade (Update, stage 40, Sync, filter statecode, pre-image) + baseline AccountDefaultDescription.
- apply: not run; no `--auto-approve` anywhere in logs; Build Report status `awaiting-apply`.

## Criteria
| # | Criterion | Met? | Evidence |
|---|---|---|---|
| 1 | Update step on account filtered on `statecode`, not SetState | met | `AccountDeactivateCascade.cs:18-21`; checks "step registered: Update 'account' PostOperation/Synchronous filter=['statecode']", "no step on SetState" |
| 2 | Transition: act only when new state is Inactive; reactivation does nothing | met | `AccountDeactivateCascade.cs:33-37` (Target Inactive + pre-image not already Inactive); test `Reactivating_an_account_leaves_its_contacts_as_they_are` (tests:201) |
| 3 | Sync PostOperation, all-or-nothing | met | `.cs:19-20`; Canvas A (lines 66-68); AC8 rollback test (tests:243) |
| 4 | Typed `Query.For<Contact>()`, StateCode+StatusCode Inactive, `ctx.Service`, no SystemService | met | `.cs:41-56`; checks "src contains Query.For<Contact>", "src must not contain SystemService" |
| 5 | Tests RED->green via PluginPipeline: Update Inactive deactivates; **a `SetStateRequest` does too**; reactivation no-op; other account untouched | **not met** (SetStateRequest part) | Update/reactivation/other-account cases present (tests:98, 201, 146). The "SetStateRequest" case (tests:111-122) is an `Update` with statecode only, not a `SetStateRequest`. Grader probe (`probe-setstate/`): `p.Service.Execute(new SetStateRequest{...})` through `PluginPipeline` fires the step and passes ("Total: 1, Failed: 0") - the real test was possible |
| SC1 | Canvas: Update + statecode filter and why not SetState; Sync PostOp and why; transition | met | Canvas lines 36, 66-69, 96-97, 37 |
| SC2 | Typed query; no logical-name strings in plugin code | met | `.cs` contains no string literal logical names; check "no new QueryExpression/GetAttributeValue" |
| SC3 | RED then green; review PASS; `vela plan --solution ZavaSales` shows new Update step; no apply | met | `logs/test-red.log`, `logs/test-green-3.log`, `logs/review-3-output.md`, `logs/plan.json` op[1] create step AccountDeactivateCascade (stage 40, mode 0) |
| - | One question at a time / ask vs assume | met | `logs/human-questions.md` Q1-Q5 one each, recommended option marked; Q3/Q5 recorded as assumptions (Canvas line 35) |

Evaluator notes applied: the message-context (`IUpdatePostContext<Account>`) use with the `OnExecuteContext`
pre-image gap named (Canvas lines 100-105, 128-129, `logs/vela-gap-image-projector.txt`) is the right move,
not a defect. The plan's rank-1 collision diagnostic is with a Microsoft managed step - not a criterion.

## Planted-violation results
Fresh general-purpose subagents told to act as `vela-reviewer` (read-only), given the diff text and the Canvas. All builds 0 errors.

| # | Planted | Expected | Verdict / severity | Result |
|---|---|---|---|---|
| a | transition guard removed (`planted-a/`) | Critical | BLOCK - Critical (reactivation/re-sent Inactive deactivate contacts, breaks Q4/AC6/AC7) + 3 Required | pass |
| b | `ctx.Service.Update` -> `ctx.SystemService.Update` (`planted-b/`) | Required | BLOCK - Critical (elevation contradicts Q3/Q5, breaks AC8) + 2 Required | pass |
| c | `.Sync()` -> `.Async()` (`planted-c/`) | Required | BLOCK - Critical (contradicts Q2, breaks AC8 rollback) + 2 Required | pass |

## Findings
1. **blocker** - `skills/vela-test-harness/SKILL.md` and `skills/vela-code-review/references/review-checklist.md`
   never ask for a test that executes `SetStateRequest` when a step is triggered on `statecode`. The only
   pointer is in `references/dataverse-gotchas.md:32-34`: "`SetStateRequest` and an Update of `statecode`
   fire the Update steps ... `PluginPipeline` behaves the same." - stated as a fact, not a test obligation.
   The actor substituted a "SetStateRequest-shaped Update" (statecode-only Update, tests:111-122) and three
   reviewers passed it. Correct path: for a statecode-filtered Update step, an acceptance case that runs
   `p.Service.Execute(new SetStateRequest { EntityMoniker, State, Status })` (`using Microsoft.Crm.Sdk.Messages;`)
   and asserts the effect - verified working on Vela.Plugins 0.37.0 by the grader probe.
2. minor (Vela gap, not the pack) - Vela.Plugins 0.37.0 generated `OnExecuteContext` drops choice columns from
   the typed pre-image (`ctx.PreImage.StateCode` null); evaluator reproduced. The actor named it and used the
   message context; nothing for the pack to change. Relay to the Vela repo.
3. minor (eval check, not the pack) - check `tests contain /SetStateRequest/` matches a comment; tighten to
   `new SetStateRequest`.

Not a skill defect: review 2's BLOCK came from the actor hand-copying material although
`skills/vela-code-review/SKILL.md:30` says to write diff/Canvas/evidence to files and paste their contents; the
reviewer caught it as designed.

## Fixes
- (pending) finding 1: add the SetStateRequest acceptance case to vela-test-harness (statecode-triggered
  steps) and a matching review-checklist line.

## Verdict
**fail** - checks 25/25 pass and all three planted violations BLOCK (Critical), but the scenario's test
requirement "a `SetStateRequest` does too" is not met: no test executes `SetStateRequest`. Next run must
re-check that a real `SetStateRequest` test exists and goes RED -> green.
