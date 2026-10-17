---
scenario: account-second-behaviour
date: 2026-10-13
verdict: fail
campaign: 2026-10-13
run: 2/3
checks: pass
grader: fail
model: claude-opus-5-5
vela_cli: 0.25.0
framework: 0.34.0
runner: "campaign actor + separate grader"
---

## Check summary
`checks.json`: **20/20 passed**, no failed check. The checks cover: the Canvas exists and records the
reuse; the build passes with no VELA diagnostics; the tests re-run green (9 tests, 0 failed); exactly 2
authored steps (Create PreOp/Sync filter `name`; Update PreOp/Sync filter `description`); no `Service.Update`
write-back; the default string appears in only one src file; the solution exists; a read-only `vela plan`
creates only the authored steps.

## Loop outcome
- `vela version` returned 0.25.0. `vela solution show ZavaSales` returned prefix `zava`.
- The Canvas was committed first (8e34951).
- `vela add step AccountDefaultDescription --message Update --stage PreOperation --mode Sync --filtering-attributes Description` exited 0.
- `vela add test` exited 2 ("File already exists"), so the tests were extended by hand.
- RED (1942e08): `Total: 9, Errors: 0, Failed: 3`. The failing tests were the three `Cleared_description_on_update_is_reapplied` cases, and the handler at that commit was the scaffold TODO.
- GREEN (1131be0): `Total: 9, Failed: 0`. Runner: mono + xunit.console `-parallel none`.
- An isolated reviewer returned PASS (0 Critical, 0 Required, 3 Nits).
- Release build, then `vela plan` exited 8 (changes: package + 2 steps, `diagnostics: []`).
- The run stopped at the gate. Nothing was applied.

## Criteria

| # | Criterion | Met? | Evidence |
|---|-----------|------|----------|
| D1 | Reuse vs new: `vela add step` on the existing plugin, not a hand-created class | met | Canvas `account-description-reapply.md:21` `reuse: add-step:AccountDefaultDescription`, `:60-61`, `:99`. The run trace (step 4) shows the command with exit 0. Check "exactly 2 authored step(s)". |
| D2 | DRY: the defaulting logic is defined once and shared by both paths (helper + constant, or a service) | **not met** | `AccountDefaultDescription.cs:12` holds one constant, but the rule itself is written twice: `:35-38` `if (... string.IsNullOrWhiteSpace(target.Description)) { ... target.Description = DefaultDescription; }` and `:47-50` `if (string.IsNullOrWhiteSpace(target.Description)) { target.Description = DefaultDescription; }`. The Canvas `:67-69` rejects the helper on purpose: "No shared helper: the Update check adds 'Description was sent' (`Contains`) ... so a helper would hide the difference". That reason is wrong. The `Contains` guard can stay in `HandleUpdate` and wrap a shared `ApplyDefaultIfEmpty(target)`. Only the string is shared. The definition of "cleared" (null/""/whitespace) and the assignment are copy-pasted. The scenario names "a shared private helper + a single constant" as the right shape. The `checks.json` DRY check only greps the literal string, so it cannot see this. |
| D3 | Sync PreOperation, set on `ctx.Request.Target`, with a reason | met | Canvas `:56-59` ("Sync because the user must see the default in the same transaction"). Code `:24-25`, `:33-38`. Check "step registered: Update ... PreOperation/Synchronous". |
| D4 | Filtering: `FilterOn(e => e.Description)` gates the Update | met | `AccountDefaultDescription.cs:26`. Test `Update_without_description_does_not_fire` (`ExecutionLog` empty). Plan filter is `description`. |
| SC1 | Canvas Approach/Structure records the reuse, how the rule is shared, and Sync with a reason | met | Canvas A `:55-61`, S `:63-69`. The record exists. Its correctness is judged under SC2. |
| SC2 | No duplicated defaulting logic. One definition is used by both paths, and the Canvas records the decision with a correct reason | **not met** | See D2. The reason recorded in the Canvas does not hold. |
| SC3 | Test-first: RED acceptance tests before implementation, green after | met | `logs/test-red.log`: Failed 3 (`Cleared_description_on_update_is_reapplied` ×3, "Strings differ"). `git show 1942e08` has the handler as a TODO only. `logs/test-green.log`: Total 9, Failed 0. The "changed to a real value → untouched" case is covered by `Non_empty_description_on_update_is_untouched`. It passed during RED, as a guard. |
| SC4 | `vela-code-review` PASS; the SOLID/DRY axis confirms no duplication; the spec axis confirms the reuse decision | **not met** | `account-description-reapply.review.md` returns PASS, and its SOLID/DRY line reads "not sharing a helper is reasonable and recorded". `review-checklist.md:93` makes "duplicated logic ... between the steps of one plugin" **Required**. The duplicated empty-check and assignment went unflagged, so the DRY axis did not confirm that duplication is absent. The spec-axis reuse check is fine. |

Note: D2/SC2 is a judgement call. The duplication is two lines and the constant is shared. Under the
scenario's wording ("defined once ... not copy-pasted"; "helper + constant") and the checklist's own
Required rule, it is still not a clean pass.

## Planted-violation results
Each violation was applied to a copy (`planted-<x>/`) and built with `dotnet build -c Release`: 0 errors, no VELA
diagnostics. A fresh subagent then reviewed it as vela-reviewer, read-only, with only the diff and the Canvas.

| Planted | Expected | Reviewer verdict | Pass? |
|---------|----------|------------------|-------|
| (a) defaulting logic and constant copy-pasted into a second class (`Account/Services/AccountDescriptionReapplier.cs`) | BLOCK ≥ Required | **BLOCK**: Required (the default is declared twice, a DRY violation between the steps of one plugin), plus Required (a service extracted for a one-liner, contradicting the Canvas) | pass |
| (b) hand-created plugin class `AccountDescriptionReapply` instead of `vela add step` | BLOCK ≥ Required | **BLOCK** - Required (hand-created plugin class, no `vela add plugin`/`add step` in the Run trace, contradicts Canvas `reuse: add-step`; stale plan) | pass |
| (c) Update step registered `.PostOperation().Async()` (`IUpdatePostContext`) | BLOCK at Critical | **BLOCK**: Critical (the Async Target edit is lost and the default is never saved), Required (drift from the Canvas), Required (the tests no longer match) | pass |

Planted (c) also exposed a Vela gap. **VELA018 did not fire.** The handler writes through a local alias
(`var target = ctx.Request.Target; target.Description = ...`). A probe copy that writes
`ctx.Request.Target.Description = ...` directly does raise VELA018. The analyzer misses the aliased form,
which is the pattern the scaffold and the pack's own examples use. Per the house rule, this is to be relayed to
the Vela repo, not worked around in the skills.

## Findings against the skills
1. **blocker**: `skills/vela-plan-review/references/registration-rules.md:101-102` says "Logic shared by the steps of **one** plugin → a private helper (+ constant)". `skills/vela-plugin-authoring/SKILL.md:62` says "steps of one plugin share a private helper". Neither text says what counts as "the logic" when the steps differ by a guard. The actor read "+ constant" as optional, and kept only the constant. It recorded a wrong reason ("a helper would hide the difference"). The reviewer accepted it ("not sharing a helper is reasonable and recorded"), even though `review-checklist.md:93` makes duplication between steps Required. Fix: make it explicit that the rule (the condition + the assignment) is shared, and that sharing only the constant is not DRY. Also say that a per-step guard (e.g. `Contains`) stays in the handler and wraps the shared helper. Add the same example to the checklist's SOLID/DRY item so the reviewer flags "constant shared, condition copy-pasted".
2. minor: `skills/vela-code-review/references/review-checklist.md:89-90` tags the Async-Target-edit item `[analyzer: VELA018 ...]`. `agents/vela-reviewer.agent.md` tells the reviewer that items marked [analyzer] "hold when the pasted build output is clean - spend the review on what the build cannot see". VELA018 misses a write through a local alias of `ctx.Request.Target` (see planted (c)). A reviewer that trusts the tag would skip a Critical. This time the fresh reviewer caught it anyway. Fix: keep the Async-Target item as a manual check, not one covered by the analyzer, until the Vela gap is fixed. The gap itself is to be reported to the Vela repo.

## Verdict
**fail.** `checks.json` passes 20/20, and every planted violation is blocked at the expected severity (a: Required, b: Required, c: Critical). The grader fails the run on
D2/SC2 (the defaulting rule is copy-pasted between the two handlers; only the string is shared, for a recorded reason
that does not hold) and SC4 (the review passed that duplication). The next run must re-check that one shared helper,
plus the constant, is called by both handlers, and that the reviewer flags a constant-only "DRY".
