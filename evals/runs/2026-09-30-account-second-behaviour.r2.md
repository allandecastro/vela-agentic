---
scenario: account-second-behaviour
date: 2026-09-30
verdict: pass
campaign: 2026-09-30
run: 2/3
checks: pass
grader: pass
model: claude-opus-5-5
vela_cli: 0.21.0
framework: 0.29.3
runner: "campaign actor + separate grader"
---

This is a re-grade against the scenario as corrected on 2026-09-30. The DRY criterion now accepts one shared private helper plus one constant when both steps are in the same plugin. The earlier grading is in `run-record.superseded.md`. Its verdict is not reused here, but its RED reproduction and planted-violation results are reused and cited.

## Check summary
`checks.json` passed **16/16**, with no failed check. The key results:
- The build is clean, with no VELA diagnostics.
- The tests re-ran green: total 9, failed 0.
- Create and Update on account are both PreOperation/Synchronous.
- The Update step's filter is `['description']`.
- There are exactly 2 authored steps.
- There is no `Update`/`Create` write-back.
- `Created via Vela plugin` appears in exactly one file under `src/`.

## Loop outcome
- `vela version` returned `vela 0.21.0` (Canvas Run trace, row 1).
- The Canvas was committed first (1a49ef9).
- `vela add step AccountDefaultDescription --entity Account --message Update ...` exited 0. The actor then aligned the step to PreOperation, `FilterOn(e => e.Description)` and `IUpdatePreContext` (1318559).
- RED tests were committed (e5e04fb). RED was reproduced by the earlier grader at e5e04fb with Mono xunit.console `-parallel none`: `Total: 9, Errors: 0, Failed: 4`.
- The implementation was committed (dc6c8cc). GREEN is 9/9, confirmed by the check re-run.
- Review: an isolated vela-reviewer returned PASS with 0 Critical, 0 Required and 3 Nits, after a first BLOCK caused by a diff placeholder in the prompt.
- `vela models` and `vela plan` were skipped (no org), with the exact commands recorded. `apply` was not run. Status: awaiting-apply.

## Criteria

| # | Criterion | Met? | Evidence |
|---|-----------|------|----------|
| D1 | Reuse vs new: `vela add step` on the existing plugin, not a hand-created class | met | Canvas `reuse: add-step:AccountDefaultDescription` (l.20). Approach l.57-59. Run trace row 3 shows the `vela add step` command with exit 0. Commit 1318559 is the scaffold output. The check "exactly 2 authored step(s)" passed. |
| D2 | DRY: the defaulting logic is defined once and shared by both paths (helper + const in one plugin is acceptable) | met | `AccountDefaultDescription.cs:14` has `const DefaultDescription`. `:49-55` has `private static ApplyDefaultIfEmpty`, called from `:38` (Update) and `:45` (Create). The check "Created via Vela plugin in exactly one place" passed. |
| D3 | Sync PreOperation, set on `ctx.Request.Target` | met | `AccountDefaultDescription.cs:25-30` and `:38`. Check "step registered: Update account PreOperation/Synchronous". The Canvas Approach (l.54-56) gives the reason: in-transaction data shaping, one write, no re-trigger. |
| D4 | `FilterOn(e => e.Description)` on the Update step | met | `AccountDefaultDescription.cs:28`. The check shows filter `['description']`. |
| S1 | The Canvas Approach/Structure records the reuse (`add step`), the service decision, and Sync with a reason | met | Reuse and Sync with a reason are in Approach l.53-59. The service decision is in Structure l.62-64 ("No service ... one private helper + one `const` ... (DRY)") and in front-matter `service: none` (l.21). |
| S2 | No duplicated defaulting logic; one definition used by Create and Update; the Canvas records the decision with a correct reason | met | See D2. The Canvas reason is that both handlers are in one plugin and share a one-line rule, so a helper plus a const gives DRY without service ceremony. The corrected rubric names this as the right shape. |
| S3 | Test-first: RED acceptance tests (cleared → re-defaulted; real value → untouched) before the implementation, green after | met | Commit order is e5e04fb (tests) → dc6c8cc (implementation). RED (4 of 9 failed) was reproduced independently in the superseded record. GREEN comes from the check "tests re-run green" (9/0). Tests: `AccountDefaultDescriptionTests.cs:42-45` (null, empty, whitespace, untouched) and `:47-74` (pipeline: not fired, single execution). |
| S4 | `vela-code-review` PASS: the SOLID/DRY axis confirms no duplication, and the spec axis confirms the reuse decision was honoured | met (caveat) | Canvas l.119-124: PASS, 0 Critical/Required, 3 Nits. Canvas front-matter `review: pass`. Caveat: the PASS came from re-sending the diff to the same reviewer after a placeholder BLOCK, not from a fresh dispatch, and no raw reviewer transcript is kept in `work/`. The recorded outcome is consistent with what a reviewer applying the checklist would return for this diff. |

## Planted-violation check
These results are reused from `run-record.superseded.md` and were not re-run. The actor's code and Canvas are unchanged since then, and the planted diffs (`planted-a.diff`, `planted-b.diff`, `planted-c.diff`) and clones (`planted-a/`, `planted-b/`, `planted-c/`) are still in this folder. Each clone built with 0 errors and 0 VELA diagnostics. A fresh read-only reviewer subagent received only the diff and the Canvas.

| Violation | Expected | Reviewer verdict | Result |
|-----------|----------|------------------|--------|
| (a) Update defaulting logic copy-pasted into a second class, with the literal duplicated | BLOCK, Required | BLOCK, Required (DRY: duplicates `ApplyDefaultIfEmpty`) | pass |
| (b) A hand-created plugin class for the Update step instead of `vela add step` | BLOCK, Required | BLOCK, Required (goes against the Canvas reuse decision; "never hand-create the class") | pass |
| (c) The Update step registered `.PostOperation().Async()` | BLOCK, Critical | BLOCK, Critical (the Target edit is lost and the default never persists), plus Required for Canvas drift | pass |

All 3 planted violations were blocked at the expected severity or higher.

## Findings against the skills
1. minor - The service rule is worded inconsistently, and the pack never states the boundary between a helper and a service that this scenario now relies on.
   - `references/registration-rules.md:77` (and its copies) says "Do not extract a service for a one-line, **single-use** operation".
   - `skills/vela-plan-review/SKILL.md:42` says only "don't extract for a one-liner".
   - `references/review-checklist.md:77` says "no service extracted for a trivial one-liner".
   - `skills/vela-plugin-authoring/SKILL.md:64` says "Do not extract a service for a trivial one-liner".

   The actor reached the right shape here, but none of these documents says the rule the corrected scenario uses: a private helper for logic shared across the steps of one plugin, and `vela add service` for logic shared across plugins. The "single-use" qualifier could still push a future agent the wrong way. The pack should state that boundary once and use the same wording in all four places.
2. minor - `skills/vela-code-review/SKILL.md:54` says "After a fix, dispatch a **fresh** reviewer on the new diff". It does not cover a BLOCK caused by the dispatcher's own malformed prompt, such as an unsubstituted diff placeholder. The actor re-sent the diff to the same reviewer. The skill should say that any re-review goes to a fresh reviewer, and that the dispatcher must check the pasted diff is non-empty before dispatching.
3. minor - `skills/vela-code-review/SKILL.md:51-52` does not ask for the reviewer's raw findings to be kept in the Build Report or in the work tree. Only the actor's summary survives (Canvas l.119-124), so the "Reviewed" claim cannot be fully audited.

## Fixes
- None yet (grader run).

## Verdict
**pass.** The checks pass (16/16), every criterion in the corrected scenario is met, and all 3 planted violations are blocked at the expected severity.

Notes for the evaluator (not skill defects):
- Success criterion 1 in the scenario still says "the shared service decision". It should say "the code-sharing (helper vs service) decision" to match the corrected DRY rule.
- `checks.json` reports "Create account ... filter=None" as ok, but its detail shows `FilteringAttributes: ["name"]` (baseline `FilterOn(e => e.Name)` on Create). The check's filter comparison for Create looks lax.

Next run must re-check that the review PASS comes from a fresh dispatch.
