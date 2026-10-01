---
scenario: account-second-behaviour
date: 2026-10-02
verdict: pass
campaign: 2026-10-02
run: 1/3
checks: pass
grader: pass
model: claude-opus-5-5
vela_cli: 0.21.4
framework: 0.29.11
runner: "campaign actor + separate grader"
---

## Check summary
`checks.json`: **16/16 passed**, no failed checks. These include: build succeeds, no VELA diagnostics, tests re-run green (10 total, 0 failed), Update account PreOperation/Synchronous filter=['description'], exactly 2 authored steps, no `UserService.Update/Create`, and the default literal in exactly one source file.

## Loop outcome
- `vela version` returned 0.21.4.
- The Canvas was committed first (fd45302). It already contained `reuse: add-step:AccountDefaultDescription`, `service: none` and the Sync PreOperation reason.
- `vela add step AccountDefaultDescription --entity Account --message Update --stage PreOperation --mode Sync --filtering-attributes Description` exited 0 (027df03).
- MODEL was skipped because there is no org (stand-in recorded).
- RED commit bbac263: `Total: 10, Failed: 4` (evidence/red.txt, red-lines.txt).
- Implement commit e01f632 (shared helper and constant).
- GREEN `Total: 10, Failed: 0` (evidence/green.txt).
- Isolated vela-reviewer: PASS, 0 Critical/Required, 4 Nits (docs/vela-builds/account-description-cleared-on-update.review.md).
- Package `artifacts/zava.Plugins.1.0.0.nupkg` contains the dll. `vela plan` was skipped (no org) and the exact command is recorded.
- The run stopped at the apply gate and did not run `apply`.

## Criteria

| Criterion | Met? | Evidence |
|---|---|---|
| Reuse: `vela add step` on the existing plugin, not a hand-created class | met | Commit 027df03 diff is the scaffold-shaped insertion (TODO stub `HandleUpdate`). Run trace row 3 shows `vela add step ...` exit 0. Canvas line 22 has `reuse: add-step:AccountDefaultDescription`. |
| DRY: defaulting logic defined once and shared by Create and Update | met | `AccountDefaultDescription.cs:11` declares `const DefaultDescription`. Both `OnExecute` (:42) and `HandleUpdate` (:35) call `ApplyDefaultIfEmpty` (:46-52). Check "src contains /Created via Vela plugin/" matches one file only. |
| Sync PreOperation, set on `ctx.Request.Target` | met | `AccountDefaultDescription.cs:22-27,35`. The check shows Update PreOperation/Synchronous. |
| Filtering `FilterOn(e => e.Description)` | met | `AccountDefaultDescription.cs:25`. The check shows filter=['description']. A pipeline test proves the step does not fire when Description is not sent (tests :55-63). |
| SC1: Canvas Approach/Structure record the reuse, the sharing approach, and Sync with a reason | met | Canvas A (lines 63-68) gives the reason "Sync because the effect is same-record data shaping the caller should see on save" and states `vela add step`. Canvas S (71-75) records the private helper + const and why there is no service. |
| SC2: no duplicated logic, one definition, decision recorded with a correct reason | met | Same code evidence as the DRY row. Canvas S says "one-liner shared by the two steps of one plugin -> a private helper"; front-matter `service: none` carries the same reason. |
| SC3: test-first, RED before implementation, GREEN after (cleared → defaulted; real value → untouched) | met | The RED commit bbac263 precedes implementation commit e01f632. evidence/red-lines.txt shows 4 FAIL on the cleared cases. `Update_non_empty_is_untouched` and `Update_with_new_description_fires_and_saves_it` cover "real value untouched". evidence/green.txt shows 10/10. |
| SC4: `vela-code-review` PASS, with the DRY axis confirming no duplication and the spec axis confirming reuse | met | review.md: spec axis says "reuse via `vela add step`". Standards axis says "DRY const + private helper (no service) per registration-rules". Verdict PASS. |

## Planted-violation results
Each planted copy was built from the actor's project at `planted-<x>/ZavaSales`. All three built with 0 errors and 0 warnings, so no analyzer catches any of them. Each review went to a fresh general-purpose subagent acting as vela-reviewer, given the work→planted diff (`planted-<x>/planted.diff`), the Canvas, the RED/GREEN lines and the Run trace.

| Planted | Expected | Reviewer verdict | Result |
|---|---|---|---|
| (a) Defaulting logic copy-pasted into a new `AccountUpdateDescriptionDefaulter` class with its own literal; Update calls it | BLOCK, Required | BLOCK. Required: "Logic is duplicated (DRY/SOLID)" and duplicated literal; plus Canvas drift | pass |
| (b) Update step moved to a hand-written plugin class `AccountDescriptionOnUpdate`, calling the now-`internal` helper | BLOCK, Required | BLOCK. Required: "hand-created ... forbids ('Never hand-create the class')", drift from `reuse: add-step`, cross-plugin sharing without a service | pass |
| (c) Update step registered Async. `PreOperation().Async()` does not compile, so it was planted as `PostOperation().Async()` with `IUpdatePostContext` and still edits Target | BLOCK, Critical | BLOCK. Critical: "changing `ctx.Request.Target` in a PostOperation or Async step saves nothing", plus departure from the Canvas Sync/PreOperation | pass |

Every planted review also raised a Required "evidence predates this diff" finding. That finding comes from how the diffs were planted. It does not decide any verdict, because each review also returned the expected substantive blocker.

## Findings against the skills
No blocker or minor defects in the skill pack were found in this run. The skills led the actor to the right shape:
- `add step` reuse
- a private helper and const rather than a service
- Sync PreOperation on Target
- `FilterOn`
- RED before GREEN
- an isolated review

Observations that are not defects of the pack:
1. Not a pack defect (Vela framework/analyzer gap, to relay upstream): a PostOperation/Async Update handler that only edits `ctx.Request.Target` builds with 0 VELA diagnostics, even though the edit is silently lost. Only the review catches it. The compile-time block on `PreOperation().Async()` covers the illegal combination but not this one.
2. Not a pack defect (CLI): the `vela add step` scaffold emits no `.WithDescription(...)`, and its TODO stub says "read the record via ctx.Request.Target". The actor added the description by hand.

## Verdict
**pass**: checks 16/16, all 8 criteria met, and all 3 planted violations blocked at the expected severity or higher. The next run should re-check that the RED stage still fails on the cleared cases and that the literal stays in one place.
