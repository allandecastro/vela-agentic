---
scenario: account-second-behaviour
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
`checks.json`: **20/20 passed**, no failed checks. These include: the Create PreOperation/Sync step with filter [name], the Update PreOperation/Sync step with filter [description], exactly 2 authored steps, a test re-run green (11 tests), no VELA diagnostics, the literal "Created via Vela plugin" in exactly one place in `src/`, no `Service.Update/Create` write-back, and a read-only `vela plan` that creates only the authored steps.

## Loop outcome
- `vela version` → 0.25.0. `vela solution show ZavaSales` → prefix `zava` (exit 0).
- Canvas committed first (4e280eb).
- `vela add step AccountDefaultDescription --message Update --stage PreOperation --mode Sync --filtering-attributes description` (exit 0). The RED tests were committed with that scaffold (07873ec). RED run: 11 total, 3 failed (AC1-AC3), exit 1.
- Implementation (e2c9e72): GREEN 11/11 (mono xunit `-parallel none`). `dotnet build -c Release --no-incremental`: 0 errors, no VELA diagnostics.
- An isolated `vela-reviewer` subagent returned PASS with 0 Critical, 0 Required and 2 Nits. Both Nits were addressed in the Build Report (8fc7d1c).
- Release build → `artifacts/zava.Plugins.1.0.0.nupkg`, dll checked and sha256 recorded. `vela plan` exited 8 (changes): package + 2 steps. The actor stopped at the apply gate and did not run `apply`.

## Criteria
| Criterion | Met? | Evidence |
| --- | --- | --- |
| Reuse vs new: `vela add step` on the existing plugin, not a hand-created class | met | Run trace step 4 in `docs/vela-builds/account-description-cleared-on-update.md:119`. Commit 07873ec adds the scaffolded `RegisterStep().OnUpdate()...Handle(HandleUpdate)` + TODO stub to `AccountDefaultDescription.cs`. Canvas `reuse: add-step:AccountDefaultDescription` (l.10). |
| DRY: defaulting defined once, shared by Create and Update | met | `src/zava.Plugins/Account/Plugins/AccountDefaultDescription.cs:15` (one constant) and `:57-66` (`ApplyDefaultIfEmpty`). It is called from `:44` (Update) and `:53` (Create). Check "src contains /Created via Vela plugin/" finds 1 file. |
| Sync PreOperation, set on `ctx.Request.Target` | met | `AccountDefaultDescription.cs:26-31, 36`. Check "step registered: Update 'account' PreOperation/Synchronous". No write-back (check passes). |
| Filtering: `FilterOn(e => e.Description)` on Update | met | `AccountDefaultDescription.cs:29`. Check filter=['description']. |
| SC1: Canvas Approach/Structure record reuse (`add step`), how the rule is shared, Sync with a reason | met | Canvas l.63-72: Approach "Sync because the user must see the default immediately in the same save... Reuse: `vela add step`". Structure "No service: ... a private helper + a private constant (DRY)". `decisions` l.25-29. |
| SC2: no duplicated logic; one definition; Canvas records the decision with a correct reason | met | As in the DRY row. Canvas l.71 gives "a one-line rule shared by two steps of one plugin" as the reason against a service, which matches the corrected rubric. The test file's own `Default` constant is a test expectation, not logic. |
| SC3: test-first, RED (cleared → re-defaulted; real value → untouched) then GREEN | met | `work/review/evidence.txt`: RED at 07873ec, 3 failures, each named with its actual value (null / "" / "   "). The guard cases AC4/AC5 already passed (expected, since they are no-op cases). GREEN at e2c9e72, 11/11. Commit order: canvas → RED → impl. Tests: `tests/.../AccountDefaultDescriptionUpdateTests.cs:39-85`. The check re-ran them green. |
| SC4: `vela-code-review` PASS; DRY axis confirms no duplication; spec axis confirms reuse honoured | met | `docs/vela-builds/account-description-cleared-on-update.review.md`. Fresh isolated subagent. Standards axis: "thin handlers + shared private helper/constant (DRY)". Spec axis: "reuse via vela add step". |
| Stop before apply | met | Canvas `apply: pending`, Gate section l.130-134. No `apply` in the run trace. |

## Planted-violation results
Each variant was copied from `work/ZavaSales` to `planted-<x>/` and built with `dotnet build -c Release --no-incremental`: exit 0, no VELA diagnostics (only NuGet audit warnings). Each was then reviewed by a fresh read-only subagent acting as `vela-reviewer`, given only the original → planted diff and the Canvas.

| Plant | Change | Expected | Reviewer verdict | Result |
| --- | --- | --- | --- | --- |
| (a) DRY | New `AccountDescriptionUpdateRule` class with a copied null/whitespace check and its own `"Created via Vela plugin"` constant; Update calls it, Create keeps the private helper | BLOCK, Required | **BLOCK**: Required (rule + literal duplicated across steps), Required (code drifts from the Canvas's shared-helper decision), Nit | pass |
| (b) hand-created class | Update step removed from `AccountDefaultDescription`; a hand-written `AccountDescriptionOnUpdate : EntityPluginBase<Account>` registers it and calls the helper, now made `internal static` | BLOCK, Required | **BLOCK**: Required (hand-created class, not `vela add`, against the Canvas reuse decision; the tests no longer target it), Required (cross-plugin static helper instead of private helper/service), Nit | pass |
| (c) Async | Update `.PreOperation().Sync()` → `.PostOperation().Async()`, handler typed `IUpdatePostContext<Account>`. `PreOperation().Async()` does not compile in Vela, so the compilable Async form was used | BLOCK, Critical | **BLOCK**: Critical (Target edit lost in Async PostOperation, so AC1-AC3 fail live), Required (Canvas drift), Required (Async wrong for in-save shaping) | pass |

The actor's own harness also catches (c): `planted-c` runs at 5/11 failed.

## Findings against the skills
None blocking, and no minor defects in the pack were attributable to this run.

Observations, not counted against the pack:
1. Vela gap, not a pack defect, for the user to relay to the Vela repo. In plant (c), **VELA018** did not fire, even though an Async step's handler writes to the Target. The write goes through a private static helper (`ApplyDefaultIfEmpty(target)`), so the analyzer appears to look only at direct writes inside the handler body. `skills/vela-code-review/references/review-checklist.md:90` tags this item `[analyzer: VELA018 ...]`, and the reviewer agent is told that analyzer-tagged items "hold when the pasted build output is clean". In this run the reviewer still caught it, so it did not lead to a miss.
2. The actor kept "whitespace-only = cleared" as a flagged assumption and open question rather than asking the reachable human. `skills/vela-plan-review/SKILL.md:96-100` ("With a human reachable, such a rule is **asked**") was added in 6a81f20 (2026-10-13 17:44), after this run had reached its RED commit (17:41), so the actor did not have that text. The assumption also follows the existing Create rule and matches the evaluator's human answer. Already addressed in the pack.

## Verdict
**pass**: checks 20/20, every criterion met, and all three planted violations blocked at the expected severity or higher. The next run should re-check that, with the 6a81f20 rule in place, the actor asks about whitespace-only.
