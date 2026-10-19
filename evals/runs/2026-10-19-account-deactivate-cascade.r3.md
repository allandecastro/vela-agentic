---
scenario: account-deactivate-cascade
date: 2026-10-19
verdict: pass
campaign: 2026-10-19
run: 3/3
checks: pass
grader: pass
model: claude-opus-5-5
vela_cli: 0.27.3
framework: 0.40.0
runner: "campaign actor + separate grader"
---

## Check summary
`checks.json`: **25/25 passed**, no failed check. Among them:
- step registered Update `account` PostOperation/Synchronous, filter `['statecode']`
- no SetState / SetStateDynamicEntity step
- no `QueryExpression` / `GetAttributeValue` and no `SystemService` in `src`
- `Query.For<Contact>` and `StateCodeOptionSet.Inactive` present
- the tests contain `new SetStateRequest`
- re-run tests green (11/11)
- 0 VELA diagnostics
- the read-only `vela plan` creates only the authored steps

## Loop outcome
| Step | What the actor did | Exit |
|---|---|---|
| version | `vela version` -> `vela 0.27.3` | 0 |
| solution | `vela solution show ZavaSales --json` -> `{"solution":"ZavaSales","publisherPrefix":"zava"}` | 0 |
| challenge | asked Q1-Q4 one at a time (`work/logs/human-questions.md`); Canvas + rule ACC-002 committed as 4fad413 | - |
| scaffold | `vela add plugin AccountDeactivateCascade ... --stage PostOperation --mode Sync --filtering-attributes StateCode`, then `vela add test` | 0 / 0 |
| RED | commit 622efb1; `Total: 11, Errors: 0, Failed: 4` (C1-C4) (`work/logs/test-red.log`) | 1 |
| GREEN | `Total: 11, Errors: 0, Failed: 0, Skipped: 0` (`work/logs/test-green.log`) | 0 |
| build | Release build: 0 warnings, 0 errors, 0 VELA | 0 |
| spec-check | 0 failures | 0 |
| review | isolated vela-reviewer: PASS, 3 Nits (`work/logs/review1/reviewer-output.md`) | - |
| plan | `vela plan -p artifacts/zava.Plugins.1.0.0.nupkg --solution ZavaSales --detailed-exitcode` -> create the package and 2 steps (`work/logs/plan.json`) | 8 (changes) |
| apply | not run; the Build Report stops at the gate (Canvas line 161) | - |

## Criteria
| Criterion | Met? | Evidence |
|---|---|---|
| Message: Update on account filtered on statecode, not SetState | met | `AccountDeactivateCascade.cs:15-18` (`OnUpdate()...FilterOn(e => e.StateCode)`). Checks "step registered ... filter=['statecode']" and "no step on SetState". Plan step: Update, `[statecode]`. |
| Transition: act only when the new state is Inactive | met | `AccountDeactivateCascade.cs:28-33`: Target Inactive, and the pre-image is not Inactive. Tests C6 (reactivation) and C7 (inactive re-sent). |
| Sync PostOperation, contact writes in the same transaction | met | `.cs:16-17`. Canvas line 69-71 gives the reason (Q2, all-or-nothing). The C4 test proves the account stays active when a contact write fails (`Tests.cs:124-147`). |
| Typed query `Query.For<Contact>()`; StateCode + StatusCode Inactive through `ctx.Service`; no SystemService | met | `.cs:35-50`. Checks "no SystemService" and "Query.For<Contact>". |
| Tests RED then green through PluginPipeline: Update, SetStateRequest, reactivation no-op, other account untouched | met | `Tests.cs` C1 (79), C2 SetStateRequest (93), C6 (163), C3 (112). RED log 4 failed, GREEN 0 failed. |
| SC1: Canvas has Update + statecode filter and why not SetState, Sync PostOp and why, the transition | met | Canvas front-matter lines 7-10. Approach lines 69-72. Line 37 (SetState fires Update, VELA022). Line 100 ("no SetState step (VELA022)"). Line 36 (transition). |
| SC2: typed query, no logical-name strings in plugin code | met | The plugin file has no string literals except the description and trace text. The `QueryExpression|GetAttributeValue` check passed. |
| SC3: RED then green; review PASS; `vela plan --solution ZavaSales` shows the new Update step; no apply | met | test-red/test-green logs; `reviewer-output.md` PASS; `logs/plan.json` creates step AccountDeactivateCascade (Update, stage 40, mode 0, filter statecode). No apply ran (only Build Report text mentions it). |
| One question at a time / ask vs assume | met | `human-questions.md`: Q1-Q4 asked separately, each with options and a recommendation. The Q3 "defaults" answer is recorded as an assumption (Canvas line 34). The status reason was assumed to be Inactive and recorded (line 35); it matches the human's answer. |

## Planted-violation results
I made each violation in `planted-<x>/`, a copy of `work/ZavaSales`, and built it: 0 errors, 0 warnings, 0 VELA. A fresh general-purpose subagent acting as the read-only vela-reviewer received only the diff and the Canvas. It was told to judge the change itself and not to block on missing RED/GREEN evidence.

| Violation | Expected | Verdict | Highest severity | Pass? |
|---|---|---|---|---|
| (a) transition guard removed (`planted-a.diff`) | Critical | BLOCK | Critical: reactivation deactivates contacts (C6/Q4), plus C7; Required: Canvas drift, unused pre-image | pass |
| (b) contact query/writes moved to `ctx.SystemService` (`planted-b.diff`) | Required | BLOCK | Critical: breaks C4, privilege escalation against Q3; Required: SystemService without a Canvas reason (checklist item quoted) | pass |
| (c) `.Sync()` changed to `.Async()` (`planted-c.diff`) | Required | BLOCK | Critical: no rollback, which breaks Q2/C4; Required: Canvas still says Sync | pass |

## Findings against the skills
No blocker and no minor defect in the skill pack was observed in this run. Notes only, none of them graded:
1. Note (eval method, not the pack): `agents/vela-reviewer.agent.md` says a review with missing RED/GREEN lines must "**BLOCK** with a Required 'evidence missing' finding". A planted-violation review fed only the diff and the Canvas would therefore block trivially. The grader prompt had to tell the reviewer to ignore missing evidence. A future grader template should say this explicitly, or pass the RED/GREEN lines along.
2. Note (actor, not the pack): the C4 assertion was tightened after GREEN (commit 3be2bc4). RED for the stronger assertion was argued ("no exception was thrown", which `test-red.log:6` confirms) but not re-run. This is acceptable because it is the same case and the RED failure mode is unchanged.

## Verdict
**pass**: checks 25/25, every criterion met, and all 3 planted violations blocked at or above the expected severity. The next run should re-check that the Canvas keeps stating "why not SetState" explicitly. This run did so in short form (lines 37 and 100).
