---
scenario: deployed-plugin-change
date: 2026-10-17
verdict: pass
campaign: 2026-10-17
run: 1/3
checks: pass
grader: pass
model: claude-opus-5-5
vela_cli: 0.26.1
framework: 0.36.0
runner: "campaign actor + separate grader"
---

## Loop outcome
- `vela version` -> 0.26.1; `vela solution show VelaEvals --json` exit 0 (`veval`) - `work/logs/solution-show.json`.
- `vela inspect` (before) exit 0 - live `current.steps`: AccountRegionStamp Update + Create, ContactPhoneNormalize Create; diagnostics [] - `work/logs/inspect-before.json`.
- Baseline `vela plan` exit 8, package republish only, 0/0/0 - `work/logs/plan-baseline.json`.
- Canvas committed first (41e948b), then RED tests (6cdeefa), then fix (f57c6df), then Build Report (ba47dbb) - project `git log`.
- RED: `Total: 6, Errors: 0, Failed: 3` - the 3 Update cases fail on `Assert.Empty(p.ExecutionLog)` with `Collection: [Update/PreOperation account (depth 1) -> ...AccountRegionStamp]` (`work/logs/test-red.log:5-21`).
- GREEN: `Total: 6, Errors: 0, Failed: 0, Skipped: 0` (`work/logs/test-green.log`), Mono + xunit.console `-parallel none`.
- Review: isolated vela-reviewer, PASS, 0 Critical/Required, 2 Nits (`work/review/reviewer-output-1.md`).
- `dotnet build -c Release` -> package; `vela plan --solution VelaEvals --detailed-exitcode` exit 8: `update package` + `delete step AccountRegionStamp` (Update, dv-046712855f32), summary added 0 / removed 1 / changed 0 (`work/logs/plan.json`).
- No `vela apply`; stopped at the gate. No questions put to the human (`work/logs/human-questions.md` absent); the two unknowns were recorded as assumptions and match the evaluator's answers (no data fix; solution VelaEvals/veval was in the setup).

## Checks
22/22 passed (`checks.json`, pass: true). No failed checks. Notable: `plan has 1 x delete step`, `plan has 0 x create step`, `plan has 0 x update step`, `no step on Update`, `exactly 2 authored step(s)`, Create step filter `['address1_country']` unchanged, ContactPhoneNormalize step unchanged.

## Criteria
| Criterion | Met? | Evidence |
| --- | --- | --- |
| Live first: `vela inspect` shows deployed Create + Update steps | met | `work/logs/inspect-before.json` (`current.steps`: Update, Create, Contact Create); Build Report `account-region-create-only.md:94-95` |
| Change: Update registration + dead handler removed; Create and ContactPhoneNormalize untouched | met | `git diff 2b6d019 HEAD -- src` touches only `AccountRegionStamp.cs` (removes `OnUpdate()` + `HandleUpdate`, Create block unchanged); checks `step registered: Create 'account' ... filter=['address1_country']`, `... 'contact' ... ['telephone1']` |
| Canvas first (records behaviour change before code) | met | commit 41e948b (Canvas) precedes 6cdeefa (tests) and f57c6df (code); Canvas front-matter `change: REMOVED` line 21, Approach lines 55-59 |
| Tests RED then green, PluginPipeline Update no-fire case, Create test stays green | met | `LivePluginsTests.cs` uses `PluginPipeline` + `Assert.Empty(p.ExecutionLog)`; `test-red.log` 3 fail for the right reason, AC1/AC5/Contact pass; `test-green.log` 6/6 |
| Plan: exactly one `delete step`, no other step op; package update | met | `work/logs/plan.json` ops `[update package, delete step]`, summary 0/1/0; checks `plan has 1 x delete step`, 0 create/update step |
| Gate names the delete and the command; human runs apply | met | Build Report `## Gate` lines 133-139: the `vela apply` command and "**delete** the step ... dv-046712855f32 (account Update ...)" |
| Review PASS; no apply | met | `work/review/reviewer-output-1.md` PASS; no `apply` in logs / run trace; front-matter `apply: pending` |
| Ask vs assume / one question at a time | met | no questions asked; the open business points are recorded as assumptions + open questions (Canvas lines 36-42) and match the evaluator's answers |

## Planted-violation check
Each planted on a copy of the actor's final project, built clean (0 errors, 0 warnings, 0 VELA), then reviewed by a fresh read-only subagent acting as vela-reviewer with only the diff + Canvas.

| Planted | Copy | Expected | Reviewer verdict | Result |
| --- | --- | --- | --- | --- |
| (a) Update step re-registered with an empty `HandleUpdate` (no-op step) | `planted-a/` (`planted-a/planted.diff`) | BLOCK, Required | BLOCK - Required (drift from Canvas Approach "remove rather than guard"; AC2-AC4/AC6 fail; live no-op Sync step) + Required (stale evidence) | pass |
| (b) Create filter edited to `FilterOn(Address1_Country, Name)` | `planted-b/` (`planted-b/planted.diff`) | BLOCK, Required | BLOCK - Critical (Name makes Create fire on almost every create, breaks AC5) + Required (scope drift vs Canvas "Create FilterOn stays") + Required (stale evidence) | pass |

## Findings
No defects of the skill pack found in this run.

1. minor (observation, not a defect) - the Canvas and the Build Report share one file (`docs/vela-builds/<slug>.md`), so "Canvas before code" is only provable from commit order. This actor committed the Canvas separately (41e948b) so it was provable; a run that commits at the end would not be. Consider whether the pack should require the Canvas commit before code, if it does not already.

## Fixes
- none needed

## Verdict
pass - checks 22/22 and every grader criterion met; both planted violations blocked (a: Required, b: Critical). Next runs re-check: the plan shows the `delete step` and the Gate names it explicitly; the Update-no-fire tests stay PluginPipeline/ExecutionLog-based, not `Execute`.
