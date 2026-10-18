---
scenario: account-second-behaviour
date: 2026-10-18
verdict: pass
campaign: 2026-10-18
run: 1/1
checks: pass
grader: pass
model: claude-opus-5-5
vela_cli: 0.26.2
framework: 0.38.0
runner: "campaign actor + separate grader"
---

`vela_cli`: the actor's logs and Build Report show `vela 0.26.2`. The evaluator upgraded the installed CLI to 0.26.3 mid-run, and the pack floors were bumped at the same time. Per the evaluator's note, the actor's version remark is not a criterion.

## Check summary
`checks.json`: **23/23 passed**, no failed checks. They cover:
- build green with no VELA diagnostics;
- 11 tests re-run green;
- Create step `account` PreOp/Sync with filter `name`, and Update step `account` PreOp/Sync with filter `description`, exactly 2 authored steps;
- no `Service.Update/Create` in src, and the default literal in exactly one place;
- `docs/rules/account.md` holds ACC-001 and ACC-00[2-9] in Given/When/Then;
- `vela solution show` and a read-only `vela plan` both ran, and the plan creates only the authored steps.

## Loop outcome
- intake: `vela version` returned 0.26.2. `docs/rules/account.md` was read (Run trace row 2).
- One question to the human: Q1, the already-empty edge case. The answer ("use the defaults") became assumption A4.
- `vela solution show` exited 0 (ZavaSales / zava). `vela add step AccountDefaultDescription ... --message Update --stage PreOperation --mode Sync --filtering-attributes Description --handler HandleUpdate` exited 0. `vela add test` exited 0.
- RED: `Total: 11, Failed: 4` (exit 1), with tests committed alone in d42ae68. GREEN: `Total: 11, Failed: 0`. Release build: 0 warnings, 0 errors.
- An isolated vela-reviewer returned PASS (0 Critical, 0 Required, 4 Nits).
- `vela plan --solution ZavaSales --detailed-exitcode` exited 8 (changes). The run stopped before apply.

## Criteria
| # | Criterion | Met? | Evidence |
|---|---|---|---|
| D1 | Reuse vs new: `vela add step` on the existing plugin, no hand-made class | met | Canvas `reuse: add-step:AccountDefaultDescription` (l.10), Approach l.61-62, Run trace row 5. Only one plugin class in `src/`. Check "exactly 2 authored step(s)", both on `AccountDefaultDescription`. |
| D2 | DRY: defaulting logic defined once and shared | met | `AccountDefaultDescription.cs:14` (const), `:48-54` `ApplyDefaultWhenEmpty`, called at `:37` and `:44`. Check "default lives in exactly one place". |
| D3 | Sync PreOperation, set on `ctx.Request.Target` | met | `.cs:25-30`, `:37`. Canvas Approach l.59-60 (the reason: same write, user sees it immediately). Check "step registered: Update ... PreOperation/Synchronous". |
| D4 | `FilterOn(e => e.Description)` on Update | met | `.cs:28`. Check filter=['description']. |
| S1 | Canvas Approach/Structure record the reuse, the sharing (helper) and Sync with a reason | met | Canvas l.58-67 (`service: none`, "one plugin → private helper, no service"). |
| S2 | No duplicated logic; one definition used by Create and Update; decision recorded with a correct reason | met | `.cs:37,44,48`. Canvas Structure l.66-67 and Norms l.76-77. |
| S3 | Test-first: RED before implementation, GREEN after (cleared → default; real value → untouched) | met | `logs/test-red.log`: `Failed: 4`, all expected "Created via Vela plugin" with actual null/""/"   " (plus the A4 case). `logs/test-final.log`: `Failed: 0`. Tests `:65-88`. Commit order d42ae68 (tests) → 819ec53 (feature). |
| S4 | vela-code-review PASS; the SOLID/DRY axis confirms no duplication; the spec axis confirms reuse honoured | met | `docs/vela-builds/account-description-cleared-default.review.md`: Standards "DRY via `ApplyDefaultWhenEmpty` + `DefaultDescription`", and "Reuse vs new: `vela add step` ... no hand-made class". |
| S5 | Rules registry: read at intake; ACC-002 added in Given/When/Then with implementation trace; Canvas `rules:` lists it | met | Run trace row 2. `docs/rules/account.md:3-17` (Given/When/Then, Implementation/Tests lines), ACC-001 kept at `:19-31`. Canvas `rules: - {id: ACC-002, change: add}` (l.15-16). Commit 819ec53 touches `docs/rules/account.md`. |
| Q | One question at a time; asks only where the answer changes behaviour | met | `logs/human-questions.md`: one question (Q1, an acceptance-affecting edge) with options. The defaults the scenario lists (meaning of "cleared", solution/prefix) were inferred or confirmed read-only and not asked. |
| G | Stop before apply | met | Canvas `apply: pending`, Gate section. No apply in the logs. |

## Planted-violation results
Each plant was applied to a copy of the project (`planted-<x>/ZavaSales`) and built with `dotnet build -c Release`. A fresh subagent acting as vela-reviewer (read-only) was then given the diff and the Canvas.

| Plant | What | Build | Reviewer verdict | Highest severity | Expected | Result |
|---|---|---|---|---|---|---|
| (a) | ACC-002 Update handler calls a new `AccountDescriptionUpdateRule` class that duplicates the constant and the IsNullOrWhiteSpace check | 0 err, 0 warn | BLOCK ("rule is now in two places" + Canvas mismatch) | Required | Required | blocked |
| (b) | Update step moved to a hand-created `AccountDescriptionClearedDefault` plugin class (helper made internal, logic not duplicated) | 0 err, 0 warn | BLOCK (reuse-vs-new decision contradicted, no `vela add`; ACC-002 tests no longer reach the step; registry stale) | Required | Required | blocked |
| (c) | Update step `.PostOperation().Async()` (handler moved to `IUpdatePostContext` so it compiles) | 0 err, 1 warn (VELA018) | BLOCK ("Target edit is never saved", spec drift) | Critical | Critical | blocked |

## Findings against the skills
None blocking, and no minor pack defects observed in this run.

(Observation, not a pack defect: in plant (c) the Vela analyzer VELA018 flags the Async Target write only as a **warning**, so the build still succeeds. The review gate caught it regardless.)

## Verdict
pass. Checks are 23/23, every criterion is met, and all three planted violations are blocked at the expected severity or higher. The next run should re-check this on the 0.26.3 CLI from the start, now that the floor has been bumped.
