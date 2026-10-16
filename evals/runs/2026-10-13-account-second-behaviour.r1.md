---
scenario: account-second-behaviour
date: 2026-10-13
verdict: pass
campaign: 2026-10-13
run: 1/3
checks: pass
grader: pass
model: claude-opus-5-5
vela_cli: 0.25.0
framework: 0.34.0
runner: "campaign actor + separate grader"
---

## Check summary
`checks.json`: **20/20 passed**, no failed checks. Highlights: build is clean with no VELA diagnostics. 9/9 tests re-run green. Two authored steps are registered: Create (PreOp Sync, filter name) and Update (PreOp Sync, filter description). There is no write-back (`Service.Update/Create`). The default literal appears in exactly one file. The read-only `vela plan` creates only the authored steps.

## Loop outcome
- Canvas commit 8bb094d, then `vela add step AccountDefaultDescription --message Update --stage PreOperation --mode Sync --filtering-attributes Description` (aca109b, exit 0).
- `vela add test` exit 2 (the file already exists), so the tests were added to the existing class.
- RED commit 8130854 (`Total: 9, Failed: 3`, test-red.log), then GREEN 90522e4 (`Total: 9, Failed: 0`, test-green.log).
- The Canvas was synced (02c6448), the isolated `vela-reviewer` returned PASS with 1 Nit, and the Build Report was written (ab67e5b).
- Release build, then `vela plan` (exit 8, 0 diagnostics). Stopped at the apply gate.

## Criteria
| # | Criterion | Met? | Evidence |
|---|---|---|---|
| D1 | Reuse via `vela add step`, not a hand-created class | met | Canvas `reuse: add-step:AccountDefaultDescription` (l.27), Approach l.67-68, run trace #4. Git commit aca109b is the scaffold step. |
| D2 | DRY: defaulting logic defined once, shared by Create and Update | met | `AccountDefaultDescription.cs:15` (single constant) and `:53-62` (`ApplyDefaultIfEmpty`), used at `:39` (Update) and `:49` (Create). Check "default lives in exactly one place". |
| D3 | Sync PreOperation, set on `ctx.Request.Target` | met | `.cs:26-31`, `:36-39`. Check for the Update PreOperation/Synchronous step. No write-back (check). |
| D4 | `FilterOn(e => e.Description)` on the Update step | met | `.cs:29`. Check shows filter `['description']`. Test `Update_without_description_does_not_fire`. |
| S1 | Canvas Approach/Structure record the reuse, how the rule is shared, and Sync with a reason | met | Approach l.62-68 ("Sync because the user must see the default immediately after save"; reuse rationale). Structure l.70-75 (private constant + helper, "no service - a one-line rule used by one plugin"). |
| S2 | No duplicated logic, and the Canvas records the decision with a correct reason | met | As D2. Canvas Structure l.72-74 and Norms l.102. The reason matches the rubric (helper within one plugin; a service only across plugins). |
| S3 | Test-first: RED acceptance tests (cleared → defaulted; real value → untouched) before the implementation, green after | met | Commit order 8130854 (tests) before 90522e4 (feat). test-red.log `Total: 9, Errors: 0, Failed: 3`, failing on the null/""/whitespace rows. test-green.log `Failed: 0`. Tests file l.51-85 cover cleared → default and new value → untouched. |
| S4 | `vela-code-review` PASS: SOLID/DRY axis no duplication; spec axis confirms the reuse | met | `work/review/reviewer-verdict.md`: an isolated fresh subagent. "Standards axis: clean (... single constant + private helper ...)". "Spec axis: clean (registration = Canvas ...)". PASS, 1 Nit. |

## Planted-violation results
Each plant was a copy of `work/ZavaSales` in `planted-<x>/`. Each built with 0 errors and **no VELA diagnostics**. Each was reviewed by a fresh read-only subagent acting as `vela-reviewer`, given only `planted-<x>/planted.diff` and the Canvas.

| Plant | Change | Expected | Reviewer verdict | Pass? |
|---|---|---|---|---|
| (a) | Update handler calls a new `AccountDescriptionUpdateRules` class holding a copy of the constant and the IsNullOrWhiteSpace rule | BLOCK ≥ Required | **BLOCK**, Required: "the default rule and its text now exist in two places (DRY)". Also Required: Canvas drift and stale evidence. | pass |
| (b) | Update step moved into a hand-written `AccountDescriptionReapplyOnClear` plugin class (no `vela add`); helper made `internal` | BLOCK ≥ Required | **BLOCK**, Required: the reuse decision was not honoured (Canvas drift); "the new class appears to be hand-written"; a cross-plugin helper should be a service; stale evidence. | pass |
| (c) | Update step `.PostOperation().Async()` with `IUpdatePostContext`, still editing the Target | BLOCK at Critical | **BLOCK**, Critical: "A change to `ctx.Request.Target` in a PostOperation or Async step is never saved". Required: Canvas drift. | pass |

## Findings against the skills
1. minor - `skills/vela-test-harness/SKILL.md` step 1 says "Add a test class with `vela add test <Name> --kind plugin --entity <Entity> --message <M>`". It does not cover adding a step to a plugin that already has a test class. The actor ran it, got exit 2 ("File already exists ... Use --force to overwrite"), and correctly added the tests to the existing class by hand instead of using `--force`, which would have overwritten the baseline tests. The skill should say: for a second step on an existing plugin, extend the existing test class, and never use `--force` on it.

Not a pack defect, noted for the user (Vela side):
- Plant (c) built with **no VELA analyzer diagnostic**, even though a PostOperation Async step edits `ctx.Request.Target`. The edit goes through a static helper (`ApplyDefaultIfEmpty(target)`). Only the review caught it, which matches the reviewer's remark "VELA018 may not have seen it". This may be an analyzer blind spot in Vela, not a skill defect.

Not counted: the actor assumed A1 (whitespace-only = cleared) instead of asking. That is precedent from the baseline Create story's acceptance case ("whitespace Description -> defaulted"), and it matches the human answer. The pack rule "edge values ... are asked" (6a81f20) landed in the middle of this run (17:44 on 2026-10-13).

## Verdict
**pass**. Checks 20/20. Every scenario decision and success criterion is met from the artifacts. All three planted violations were blocked at the expected severity or higher. The next run should re-check that the actor asks rather than assumes edge values now that 6a81f20 is in place.
