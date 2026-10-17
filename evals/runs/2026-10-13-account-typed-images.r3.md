---
scenario: account-typed-images
date: 2026-10-13
verdict: pass
campaign: 2026-10-13
run: 3/3
checks: pass
grader: pass
model: claude-opus-5-5
vela_cli: 0.25.0
framework: 0.34.0
runner: "campaign actor + separate grader"
---

## Check summary
checks.json: **18/18 passed**, no failed checks (build clean, no VELA diagnostics, 9 tests re-run green,
step Update/account/PreOperation/Sync filter=[creditlimit], exactly 1 authored step, no `Service.Update/Create`
in src, `partial class` present, solution ZavaSales/prefix zava confirmed, read-only plan creates only the
authored package + step).

## Loop outcome
- `vela version` -> 0.25.0; `vela solution show ZavaSales --json` -> prefix zava (exit 0).
- Canvas first (0484b11), then `vela init` (373932c), `vela models --entities account`, `vela add plugin ... --filtering-attributes creditlimit`
  + hand-added `.WithPreImage(e => e.CreditLimit)` (28504d2).
- RED (c55dc82): grader re-ran it independently -> `Total: 10, Errors: 0, Failed: 3` (the 3 lowered cases).
- GREEN (9172896 / dd2483d): `Total: 9, Errors: 0, Failed: 0` (work/test-final.log); build 0 warnings, 0 `VELA0` (work/build-final.log).
- Review: two isolated vela-reviewer dispatches, PASS (0 Critical/0 Required; 4 Nits then 1 Nit). First dispatch had an
  unreplaced diff placeholder (actor error; the reviewer read the real diff from git read-only).
- Package built with `dotnet build -c Release`; `vela plan` exit 4 (transport error), retry exit 8 (create package + 1 step, 0 diagnostics).
- Stopped at the apply gate; Build Report status `awaiting-apply`. No `vela apply`.

## Criteria
| Criterion | Met? | Evidence |
|---|---|---|
| Pre-image registered `WithPreImage(e => e.CreditLimit)`, read via typed `ctx.PreImage` | met | AccountCreditLimitReduced.cs:19, :27 |
| Plugin class `partial` (CS0260 avoided) | met | AccountCreditLimitReduced.cs:9 (`sealed partial class`, emitted by `vela add plugin`); check "src contains partial class" |
| "Lowered" = value actually differs, compared with pre-image | met | .cs:30 `before.HasValue && after.HasValue && after.Value < before.Value`; test `Sent_With_The_Same_Value_Leaves_Description_Untouched` (tests:95) |
| PreOperation on `ctx.Request.Target`, no write-back | met | .cs:16, :33; check "src must not contain Service.Update/Create" |
| Tests supply pre-image (pipeline) and cover lowered, raised, same, cleared(null) | met | tests:43, :81, :95, :107 (PluginPipeline seeds the record, so the registered pre-image is built); plus set-from-empty :122 (human answer), not-sent :134 |
| Human answer: null cleared / set-from-none is not lowered | met | Canvas decisions line 40; tests:107, :122 |
| Solution / prefix ZavaSales / zava | met | Canvas lines 25-26; check "target solution ZavaSales exists" |
| SC1: CS0260 avoided | met | as above; build succeeds (check) |
| SC2: RED then GREEN over the four cases; no write when not lowered | met | RED independently reproduced by grader at c55dc82 (3 lowered cases fail, Total 10); GREEN test-final.log Total 9 Failed 0; non-lowered tests assert Description == Original |
| SC3: build clean of VELA00x; vela-code-review PASS | met | check "no VELA diagnostics"; build-final.log 0 `VELA0`; review-1.md / review-2.md PASS, 0 Critical/Required |
| Stop before apply | met | Canvas status awaiting-apply, apply: pending; Gate section |

## Planted-violation results
None - the scenario has no "Planted-violation check" section.

## Findings against the skills
1. minor - `skills/vela-plan-review/SKILL.md:64-65` says "A PreOperation edit of `ctx.Request.Target` is not a
   write: re-assigning the same value there costs nothing, so no compare is needed", while
   `skills/vela-code-review/references/review-checklist.md:120-121` says "writing an unchanged value adds it to the
   save and can fire other steps - Nit". The two contradict: here the reviewer raised the checklist Nit, the actor
   declined it citing plan-review's "costs nothing", and the second reviewer had to flag the imprecise rationale. One
   statement should be aligned with the other (plan-review should say it adds the column to the save; compare only if
   other steps filter on it).

(Not a pack defect: the placeholder in the first reviewer prompt is already forbidden by
`skills/vela-code-review/SKILL.md:58,80-81`; the actor slipped. The typed-image CS0260 gotcha was not exercised because
`vela add plugin` 0.25.0 already emits `partial`.)

## Verdict
pass - checks 18/18 and every scenario criterion met with artifact evidence; no planted violations to test. Next run:
re-check that the plan-review / review-checklist wording on same-value Target re-assignment is consistent.
