---
superseded_by: 2026-09-30-account-second-behaviour.r1.md   # rubric corrected mid-campaign; kept for transparency
scenario: account-second-behaviour
date: 2026-09-30
verdict: fail
run: 1/3
checks: pass
grader: fail
model: claude-opus-5-5
vela_cli: 0.21.0
framework: 0.29.3
runner: "campaign actor + separate grader"
---

## Check summary
`checks.json`: **16/16 passed**, no failed checks. Build is clean, there are no VELA diagnostics, tests re-run green 9/9, and exactly 2 steps are registered: Create PreOp/Sync, and Update PreOp/Sync with filter `description`. There is no `UserService.Update` and `Created via Vela plugin` appears exactly once.

Evaluator-side note (not a skill defect): the check is labelled `Create ... filter=None`, but the probe shows `FilteringAttributes: ["name"]`. It passed because `evals/checks/account-second-behaviour.json` gives no `filter` for the Create step, so the label misstates what was checked.

## Loop outcome
- `vela version` returned 0.21.0.
- A Canvas was committed (cb0eae7).
- `vela add step AccountDefaultDescription --entity Account --message Update` exited 0. The scaffold's PostOperation, `IUpdatePostContext` and `e => e.Id` were aligned to PreOp/Sync/`FilterOn(Description)`.
- `vela models` was skipped (no org) and the command recorded.
- RED: 4/9 failing, recorded with test names in the Canvas.
- Implementation used a shared private helper and a const.
- GREEN: 9/9 (`work/test-green.log`).
- Build: 0 warnings / 0 errors (`work/build-verify.log`).
- Fresh reviewer: PASS with 6 Nits.
- Package built (sha recorded), unsigned.
- `vela plan` skipped (no org) with the exact command recorded. Stopped at the apply gate and did not run `vela apply`.

## Criteria

| # | Criterion (scenario) | Met? | Evidence |
|---|---|---|---|
| D1 | Reuse vs new: `vela add step` on the existing plugin, not a hand-made class | met | Canvas `reuse: add-step:AccountDefaultDescription` (docs/vela-builds/account-description-cleared-on-update.md:10), A - Approach :63-64, Run trace row 3. The code has a single class with 2 steps (AccountDefaultDescription.cs:15-27). |
| D2 | DRY / service: a **service** (`vela add service`) reused by both steps | **not met** | Canvas `service: none` (:11) and S - Structure :70-71 ("one private helper + constant (DRY). No service (a one-line rule, single use)"). `src/zava.Plugins/Account/Services/` and `src/zava.Shared/Services/` are empty. The logic is **not duplicated** (one `ApplyDefaultDescription`, AccountDefaultDescription.cs:45-51, called at :34 and :41), but no service was extracted, which is what the scenario requires. The Canvas's "single use" is also inaccurate: the helper has two call sites. |
| D3 | Sync PreOperation with a reason, set on `ctx.Request.Target` | met | AccountDefaultDescription.cs:22-24 and :34. Canvas A :60-62 ("Sync because the effect must be in the same transaction"). Check `step registered: Update account PreOperation/Synchronous`. |
| D4 | `FilterOn(e => e.Description)` on Update | met | AccountDefaultDescription.cs:25. Check filter=['description']. |
| S1 | Canvas Approach/Structure record reuse (`add step`), the shared-service decision, and Sync with a reason | partially met | Reuse and Sync are recorded with reasons. The service decision is recorded, but it was resolved as "no service", contrary to the scenario's expected decision (see D2). |
| S2 | No duplicated defaulting logic; **a single service** reused by Create and Update | **not met** | No duplication (the require_src check shows exactly 1 occurrence of the default). However, the reuse is a private helper, not a service. |
| S3 | Test-first: RED (cleared → re-defaulted; real value → untouched) then green | met | Canvas Evidence :115-120 lists RED `Failed: 4` with test names verbatim and actual values. GREEN is in `work/test-green.log` (`Total: 9 ... Failed: 0`). Tests: AccountDefaultDescriptionTests.cs:42-45 cover null, '', whitespace and real value; :48-77 are pipeline tests. **Grader reproduction:** the baseline plugin (76a82bf) run with the final tests gives `Total: 9, Failed: 5` (`r1/red-repro`), so the tests are genuinely RED before implementation. Caveat: no raw RED log was saved, and tests and implementation are in one commit (9eeaba2). |
| S4 | `vela-code-review` PASS; SOLID/DRY axis confirms no duplication; spec axis confirms reuse honoured | met (weak evidence) | The Build Report (:123-129) records a fresh-reviewer PASS with 6 Nits, none of them about duplication or reuse. The per-axis conclusions are not recorded verbatim. The actor also reports that the first reviewer prompt was sent with a placeholder instead of the diff and had to be re-sent. |

## Planted-violation results
Each violation was applied to a copy of the actor's project (`r1/planted-a|b|c`), which built with 0 warnings and 0 errors. A fresh subagent acting as `vela-reviewer` (read-only) was given only the change diff (`r1/planted-<x>.diff`, baseline 76a82bf → planted, `src/`) and the Canvas.

| Violation | Expected | Reviewer verdict | Result |
|---|---|---|---|
| (a) Defaulting logic copy-pasted into a second class (`AccountDescriptionUpdateRule`, a duplicate const and check, called from `HandleUpdate`) | BLOCK ≥ Required | **BLOCK**, Required: "duplicated logic between the two steps of one plugin", plus Required Canvas drift | pass |
| (b) Hand-created plugin class `AccountDescriptionOnUpdate` carrying the Update step instead of `vela add step` | BLOCK ≥ Required | **BLOCK**, Required: "the class was created by hand, which the registration rules forbid", reuse decision contradicted; also Required for the untested registration and evidence mismatch | pass |
| (c) Update step registered `.PostOperation().Async()` | BLOCK at Critical | **BLOCK**, **Critical**: "changes to `ctx.Request.Target` are never saved", plus Required for spec/Approach drift and Sync-vs-Async. The harness also caught it: 5/9 fail. | pass |

All three planted violations were blocked at the expected severity.

## Findings against the skills
1. **blocker** - The service rule in the skills contradicts the scenario's required service outcome.
   - `skills/vela-plan-review/SKILL.md:41-42`: "Real/reusable logic → a service (`vela add service`) injected via DI; reuse an existing one; don't extract for a one-liner."
   - `references/registration-rules.md:77-78`: "Do not extract a service for a one-line, single-use operation - that is ceremony, not design."
   - `skills/vela-code-review/references/review-checklist.md:75-78`: "real logic in a service where it earns it ... no service extracted for a trivial one-liner."
   - What happened: the actor followed the letter of these rules. It treated `IsNullOrWhiteSpace → default` as a one-liner, shared it through a private helper inside the one multi-step plugin, and recorded `service: none`. The fresh reviewer accepted this as DRY.
   - The pack never says whether logic shared by **two steps of the same plugin** (reusable, but not single-use) must become a service, or whether a private helper satisfies DRY. The scenario requires `vela add service`.
   - Fix, one or the other:
     - Make the rule decide this case explicitly. For example: "logic used by more than one step/handler → `vela add service`, even if short", with the reviewer flagging a helper in its place.
     - Or relax the scenario to "one shared implementation (private helper or service)".
   - Until then, this criterion is decided by the model's reading of "one-liner", not by the pack.
2. minor - `references/registration-rules.md:77` ties "one-line" to "single-use", but the actor's Canvas (S - Structure) says "No service (a one-line rule, single use)" for a helper with two call sites.
   - Neither the plan-review self-grill nor the reviewer caught that the "single use" premise was false.
   - The plan-review / review checklist could ask for the call-site count when the Canvas justifies not extracting a service.
3. minor - `skills/vela-code-review` does not require the reviewer's verdict to be persisted per axis, or verbatim, in the Build Report. The report only has a PASS and a Nit list.
   - The actor's first reviewer dispatch went out with a placeholder instead of the diff (actor-report "Process slip").
   - Nothing in the pack caught that, apart from the actor noticing.
   - Suggestion: the review skill should require the dispatcher to check that the prompt contains the diff text before dispatching. It should also record per axis: spec PASS/BLOCK and standards PASS/BLOCK.

## Verdict
**fail.** Checks pass (16/16) and all three planted violations are blocked. However, the grader fails the scenario's DRY/service criterion (D2/S2) and gives S1 only partially: no service was extracted, only a private helper. The behaviour, registration, test-first discipline and apply-gate stop are all correct.

The next run must re-check whether the pack drives the agent to `vela add service` (or whether the scenario is relaxed), and that the Canvas records the service decision with a truthful call-site count.
