---
scenario: account-deactivate-cascade
date: 2026-10-18
verdict: pass
campaign: 2026-10-18d
run: 1/1
checks: pass
grader: pass
model: claude-opus-5-5
vela_cli: 0.27.1
framework: 0.39.0
runner: "campaign actor + separate grader"
---

## Check summary
`checks.json`: **25/25 passed**, `pass: true`. No failed checks. Key ones: step registered
`Update account PostOperation/Synchronous filter=['statecode']`; no step on SetState / SetStateDynamicEntity;
`Query.For<Contact>` present; no `SystemService`; no `new QueryExpression|GetAttributeValue<`;
`StateCodeOptionSet.Inactive` present; tests contain `new SetStateRequest`; re-run green 17/17; read-only
`vela plan` runs and creates only authored steps.

## Loop outcome
- `vela version` -> 0.27.1 (logs/run-trace.md:3); `vela solution show ZavaSales --json` exit 0 -> prefix `zava`.
- Grill: Q1 (which contacts) and Q2 (security context) asked one at a time (logs/human-questions.md:3-14).
- Canvas + ACC-002 committed (edc2970) -> `vela add plugin|service|test` exit 0 (90e3278) -> RED tests (92f2ca3).
- RED: `Total: 17, Errors: 0, Failed: 9` (logs/test-red.log, 9 named `[FAIL]` lines) -> GREEN at 8bd324f `Total: 17, Failed: 0` (logs/test-green.log).
- `dotnet build -c Release --no-incremental` 0 warnings / 0 errors / 0 VELA; spec-check 0 failures.
- Fresh vela-reviewer: PASS, 3 Nits (logs/review1/reviewer-output.md).
- `dotnet build -c Release` -> `artifacts/zava.Plugins.1.0.0.nupkg`; `vela plan --solution ZavaSales --detailed-exitcode` exit 8: create package, create step AccountDeactivateCascade (Update, account, stage 40, mode 0 Sync, filter [statecode], preImage [statecode]), create step AccountDefaultDescription (baseline, never applied) (logs/plan.json).
- No `vela apply` run; Build Report stops at the gate (Canvas:145-148).

## Criteria
| Criterion | Met? | Evidence |
| --- | --- | --- |
| Message: Update on account filtered on statecode, not SetState | met | AccountDeactivateCascade.cs:16-19 (`OnUpdate().FilterOn(e => e.StateCode)`); checks "no step on SetState", "no step on SetStateDynamicEntity"; plan.json filteringAttributes [statecode] |
| Transition: act only when new state is Inactive | met | AccountDeactivateCascade.cs:31-36 (`Target.StateCode == Inactive && PreImage.StateCode != Inactive`); tests C8, C9 |
| Stage/mode: Sync PostOperation | met | AccountDeactivateCascade.cs:17-18; check "step registered ... PostOperation/Synchronous"; plan.json stage 40 mode 0 |
| Typed query `Query.For<Contact>()`, writes StateCode + StatusCode via ctx.Service, no SystemService | met | AccountContactDeactivation.cs:27-40; plugin :26 injects `IOrganizationService` (= ctx.Service); check "src must not contain SystemService" |
| Tests via PluginPipeline: Update deactivates; SetStateRequest does too; reactivation does nothing; other account untouched | met (C8 weak, see finding 2) | AccountDeactivateCascadeTests.cs C1 :59, C2 :76 (`SetStateRequest`), C8 :159, C4 :106 |
| SC1 Canvas: Update + statecode filter and why not SetState; Sync PostOperation and why; transition | met | Canvas:7-10, :40 + :101 (VELA022: Update covers SetStateRequest), :71-73 (PostOp: other records; Sync: same transaction, rollback), :37, :90 |
| SC2 Typed query; no logical-name strings in plugin code | met | AccountContactDeactivation.cs:27-31; plugin/service use generated members only; check "no new QueryExpression/GetAttributeValue" |
| SC3 RED then green; review PASS; `vela plan --solution ZavaSales` shows the Update step; no apply | met | test-red.log (9 FAIL) -> test-green.log (0 FAIL), commits 92f2ca3 -> 8bd324f; reviewer-output.md PASS; plan.json op `create step AccountDeactivateCascade`; no apply in run-trace / Canvas `apply: pending` |
| One question at a time | met | human-questions.md: Q1 and Q2 each a single multiple-choice decision |
| Ask vs assume | met with reservation (finding 1) | Timing (Sync) and reactivation were assumed, not asked; both match the human's evaluator answers and are recorded as assumptions to confirm (Canvas:36, :38, :153) |

## Planted-violation results
Each planted copy built clean (0 errors / 0 warnings); a fresh subagent acting as vela-reviewer got only the diff and the Canvas.

| Planted | Expected | Reviewer verdict | Highest severity | Result |
| --- | --- | --- | --- | --- |
| (a) transition guard removed (planted-a) | BLOCK, Critical | BLOCK | Critical (reactivation deactivates contacts; C9 violated) | pass |
| (b) service wired to `context.SystemService`, no Canvas reason (planted-b) | BLOCK, Required | BLOCK | Critical (privilege escalation, breaks C10; also Canvas drift) | pass |
| (c) `.Sync()` -> `.Async()` (planted-c) | BLOCK, Required | BLOCK | Critical (all-or-nothing / C10 broken, Canvas drift) | pass |

Supplementary (grader): the actor's own suite on each planted copy - (a) 1 fail (C9 `Resending_inactive_on_an_inactive_account_does_not_cascade`), (b) 1 fail (C10), (c) 1 fail (C10). Every violation is caught by a test too.

## Findings against the skills
1. minor - `skills/vela-plan-review/SKILL.md:37` says "**Approach - Sync vs Async:** default Sync; justify Async.", while `skills/vela-grill/SKILL.md:34` lists "Timing: Sync ... or Async ... State each consequence in the question." as a business question to ask. The actor followed the plan-review default and never asked Timing (nor whether reactivation should cascade, a Trigger edge that changes acceptance case C8). It then recorded the Q2 answer as covering "Security context and other open points" (Canvas:33), although Q2 asked only about security. The outcome matched the human's answers here, but the two skills disagree on whether Timing is a default or a human decision. Say in one place when Sync is a platform default and when it must be asked, e.g. "ask when a failure would roll back a user action".
2. minor - nothing in `skills/vela-test-harness` / the review checklist makes a "does nothing" case seed state that the forbidden behaviour would change. ACC-002/C8 (AccountDeactivateCascadeTests.cs:159-170) reactivates an account whose contact is already **inactive**, so it passes with or without the transition guard. Only C9 caught planted (a). The planted-(a) reviewer flagged this; the actor's own review did not. Add one line: a negative case must seed the state the bug would change (here, an active contact on reactivation).

No blocker findings.

## Fixes
- none yet

## Verdict
**pass** - checks 25/25 and every scenario criterion is met from the artifacts; all three planted violations are blocked at Critical (expected Critical / Required / Required). The next run must re-check: whether Timing is asked or defaulted, and a reactivation test with an active contact.
