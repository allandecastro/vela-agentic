---
superseded_by: 2026-09-30-account-second-behaviour.r2.md   # rubric corrected mid-campaign; kept for transparency
scenario: account-second-behaviour
date: 2026-09-30
verdict: fail
run: 2/3
checks: pass
grader: fail
model: claude-opus-5-5
vela_cli: 0.21.0
framework: 0.29.3
runner: "campaign actor + separate grader"
---

## Check summary
`checks.json`: **16/16 passed**, no failed check. Checks included: the Canvas exists and mentions reuse, the build is clean with no VELA diagnostics, the tests re-run green (total 9, failed 0), Create and Update are both PreOperation/Synchronous with the Update filter `['description']`, there are exactly 2 authored steps, no write-back, and the default literal appears in exactly one place.

## Loop outcome
- `vela version` returned 0.21.0 (Canvas Run trace, row 1).
- Canvas committed first: 1a49ef9.
- `vela add step AccountDefaultDescription --entity Account --message Update` exited 0. The actor then aligned it to PreOperation, `FilterOn(e => e.Description)` and `IUpdatePreContext` (1318559).
- RED tests committed: e5e04fb. **The grader re-ran RED**: a clone checked out at e5e04fb and run with Mono xunit.console `-parallel none` gave `Total: 9, Errors: 0, Failed: 4`. The 4 failures are the Update null, empty, whitespace and pipeline cases.
- Implementation committed: dc6c8cc. GREEN is 9/9 (actor's evidence, confirmed by the check re-run).
- Review: an isolated vela-reviewer returned PASS with 0 Critical, 0 Required and 3 Nits. The first dispatch returned BLOCK because the prompt held a diff placeholder; the diff was then re-sent to the same reviewer.
- `vela models` and `vela plan` were skipped because there is no org; the exact commands are recorded. `apply` was not run. Status: awaiting-apply.

## Criteria

| # | Criterion | Met? | Evidence |
|---|-----------|------|----------|
| D1 | Reuse vs new: use `vela add step` on the existing plugin, not a hand-created class | met | Canvas `reuse: add-step:AccountDefaultDescription` (l.20), Approach l.57-59, Run trace row 3. Commit 1318559 is the `add step` output. |
| D2 | DRY / service: extract a service (`vela add service`) reused by both steps | **not met** | Canvas `service: none` (l.21). Structure l.63-64: "No service ... one private helper + one `const` ... instead of a service (ceremony for a one-liner)". `AccountDefaultDescription.cs:49-55` has a `private static ApplyDefaultIfEmpty`. The logic is not duplicated, but no service was extracted. |
| D3 | Sync PreOperation, set on `ctx.Request.Target` | met | `AccountDefaultDescription.cs:25-30`, `:38`. Check "step registered: Update account PreOperation/Synchronous". Canvas Approach l.54-56 gives the reason. |
| D4 | `FilterOn(e => e.Description)` on the Update step | met | `AccountDefaultDescription.cs:28`. Check filter=['description']. |
| S1 | Canvas Approach/Structure record reuse (`add step`), the **shared service decision**, and Sync with a reason | **not met** (partial) | Reuse and Sync-with-reason are recorded (Approach l.54-59). The recorded structure decision is "no service", which is the opposite of the expected shared service. |
| S2 | No duplicated defaulting logic; **a single service** reused by the Create and Update paths | **not met** (partial) | There is no duplication: one helper and one const, and check "Created via Vela plugin in exactly one place" passed. There is no service: `src/` has no Services folder and no `vela add service` in the Run trace. |
| S3 | Test-first: RED acceptance tests (cleared → re-defaulted, real value → untouched) before the implementation, green after | met | Commit order e5e04fb (tests) → dc6c8cc (impl). The grader reproduced RED (4 failed of 9). GREEN 9/9 comes from the check "tests re-run green". Tests are at `AccountDefaultDescriptionTests.cs:42-74`. |
| S4 | `vela-code-review` PASS: the SOLID/DRY axis confirms no duplication, the spec axis confirms reuse was honoured | met (caveat) | Canvas l.119-124: PASS, 0 Critical/Required. The reviewer judged a private helper to be DRY and did not question the missing service, which is consistent with the pack's own checklist. Caveat: the PASS came from re-sending to the same reviewer after the placeholder BLOCK, not from a fresh dispatch. No raw reviewer transcript is in `work/`. |

## Planted-violation check
Each violation was applied to a clone of the actor's HEAD under `planted-<x>/` and built (0 errors, 0 VELA diagnostics in all three). A fresh subagent acting as vela-reviewer (read-only) then received only the diff and the Canvas.

| Violation | Expected | Reviewer verdict | Result |
|-----------|----------|------------------|--------|
| (a) Update-path defaulting logic copy-pasted into a second class (`AccountDescriptionUpdateDefaulter`, literal duplicated) | BLOCK, Required | **BLOCK**, Required: "duplicates `AccountDefaultDescription.cs:49-55` ... checklist rates logic duplicated between the steps of one plugin as Required". Also Required: Canvas drift and missing evidence. | pass |
| (b) Hand-created plugin class `AccountDescriptionCleared` carrying the Update step instead of `vela add step` | BLOCK, Required | **BLOCK**, Required: "new plugin class ... goes against the Canvas's reuse decision ... looks hand-created ... 'Never hand-create the class'". Also Required: the Update tests would break and there is no evidence. | pass |
| (c) Update step registered `.PostOperation().Async()` | BLOCK, Critical | **BLOCK**, Critical: "Target edit in a PostOperation Async step is lost, so the Update default never persists". Also Required: drift from the Canvas Sync decision. | pass |

All 3 planted violations were blocked at the expected severity or higher.

## Findings against the skills
1. **blocker** - The pack's service guidance contradicts this scenario's expected decision, and it is worded inconsistently across files.
   - `references/registration-rules.md:77` says "Do not extract a service for a one-line, **single-use** operation".
   - `skills/vela-plan-review/SKILL.md:42` says only "don't extract for a one-liner".
   - `references/review-checklist.md:77` says "no service extracted for a trivial one-liner".
   - `skills/vela-plugin-authoring/SKILL.md:64` says "Do not extract a service for a trivial one-liner".

   The defaulting rule here is a one-liner used by **two** steps. The "single-use" qualifier from registration-rules would point to a service, but it is dropped in the plan-review skill and the review checklist, which are the documents the actor and reviewer actually apply. The actor cited exactly that reasoning ("ceremony for a one-liner", Canvas l.64) and chose a private helper. The reviewer then passed it.

   Either the pack must say that logic reused by two or more steps or plugins earns `vela add service` even when it is short, and carry "single-use" consistently into plan-review, plugin-authoring and review-checklist. Or the scenario's criteria (D2, S1, S2) should accept a shared private helper inside one multi-step plugin. As written, the pack steers agents away from the scenario's pass condition.
2. minor - `skills/vela-code-review/SKILL.md:54` says "After a fix, dispatch a **fresh** reviewer on the new diff". It does not say what to do when the reviewer BLOCKs because the dispatcher's prompt was malformed (the diff placeholder was not substituted). The actor re-sent the diff to the same reviewer, so the recorded PASS is not from a clean fresh context. The skill should say: any re-review, including after a dispatch error, goes to a fresh reviewer. It should also say to check that the pasted diff is non-empty before dispatching.
3. minor - `skills/vela-code-review/SKILL.md:51-52` asks for the diff text to be pasted into the reviewer prompt, but it does not ask for the reviewer's raw output to be kept in `work/` or in the Build Report. Only the actor's summary of the findings survives (Canvas l.119-124). This makes the "Reviewed" claim hard to audit.

## Fixes
- None yet (grader run).

## Verdict
**fail.** Checks pass (16/16), and all planted violations are blocked. The grader fails the run on S1 and S2 (and decision D2): no shared service was extracted. The actor followed the pack's "don't extract for a one-liner" rule, so the root cause is finding 1, a conflict between the skills and the scenario, not a mistake by the actor.

Next run must re-check: once finding 1 is resolved in either the pack or the scenario, confirm the Canvas's Structure decision and the code agree with it. Confirm the review PASS comes from a fresh dispatch.
