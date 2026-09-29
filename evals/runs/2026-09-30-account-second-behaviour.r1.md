---
scenario: account-second-behaviour
date: 2026-09-30
verdict: pass
campaign: 2026-09-30
run: 1/3
checks: pass
grader: pass
model: claude-opus-5-5
vela_cli: 0.21.0
framework: 0.29.3
runner: "campaign actor + separate grader"
---

Re-grade against the DRY criterion as corrected on 2026-09-30: one definition (a helper plus a constant, or a service) shared by Create and Update. A service is required only when the logic is shared across plugins. The earlier grading, which judged against the old "must be a service" criterion, is kept in `run-record.superseded.md`. Its verdict was not reused.

## Check summary
`checks.json`: **16/16 passed**. No checks failed.
- The build is clean and there are no VELA diagnostics.
- Tests re-ran green: 9/9.
- Exactly 2 authored steps are registered:
  - Create on account: PreOperation, Synchronous.
  - Update on account: PreOperation, Synchronous, filter `['description']`.
- The source has no `UserService.Update/Create`.
- `Created via Vela plugin` appears in exactly one source file.

Evaluator note (not a skill defect): the check is labelled `Create ... filter=None`, but the probe shows `FilteringAttributes: ["name"]` (the baseline's `FilterOn(e => e.Name)`). The check passes because `evals/checks/account-second-behaviour.json` sets no filter for Create, so the label overstates what was checked.

## Loop outcome
- `vela version`: 0.21.0, exit 0.
- Canvas committed (cb0eae7).
- `vela add step AccountDefaultDescription --entity Account --message Update`: exit 0. The scaffold emitted PostOperation, `IUpdatePostContext` and `FilterOn(e => e.Id)`. The actor aligned these to PreOperation, Sync and `FilterOn(e => e.Description)`.
- `vela models`: skipped because there is no org. The command is recorded.
- RED: 4/9 failed. The test names and actual values are in the Canvas.
- Implementation: a shared private helper plus a constant (commit 9eeaba2).
- GREEN: 9/9 (`work/test-green.log`). Build: 0 warnings, 0 errors (`work/build-verify.log`).
- Fresh reviewer: PASS with 6 Nits.
- Package built with its sha256 recorded. It is unsigned.
- `vela plan`: skipped because there is no org. The exact command is recorded.
- Stopped at the apply gate. `vela apply` was not run.

## Criteria

| # | Criterion | Met? | Evidence |
|---|---|---|---|
| D1 | Reuse vs new: `vela add step` on the existing plugin, not a hand-made class | met | Canvas `reuse: add-step:AccountDefaultDescription` (`work/ZavaSales/docs/vela-builds/account-description-cleared-on-update.md:10`), A - Approach :62-64, Run trace row 3 (exit 0). The code is one class with 2 `RegisterStep()` calls (`src/zava.Plugins/Account/Plugins/AccountDefaultDescription.cs:15-27`). The grader's fresh reviewer confirms the diff edits the existing file and adds no new class. |
| D2 | DRY: defaulting logic defined once and shared; a helper plus a constant is acceptable within one plugin | met | `private const string DefaultDescription` (AccountDefaultDescription.cs:11) and `private static void ApplyDefaultDescription(Account target)` (:45-51). It is called from `OnExecute` (Create, :41) and `HandleUpdate` (Update, :34). The check `src contains /Created via Vela plugin/` finds exactly 1 file. |
| D3 | Sync PreOperation, set on `ctx.Request.Target`, with a reason | met | AccountDefaultDescription.cs:22-24, :30 (`IUpdatePreContext<Account>`), :34. Canvas A :60-62 gives the reason: "part of the same write, no second Update ... Sync because the effect must be in the same transaction". Check `step registered: Update account PreOperation/Synchronous`. |
| D4 | `FilterOn(e => e.Description)` on Update | met | AccountDefaultDescription.cs:25. Check `filter=['description']`. Canvas Safeguards :97. |
| S1 | Canvas Approach/Structure record the reuse (`add step`), the shared-logic/service decision, and Sync with a reason | met | Approach :59-65 records reuse and Sync with reasons. Structure :67-71 records "shared by both handlers through one private helper + constant (DRY). No service (a one-line rule, single use)". Front-matter has `service: none` (:11). |
| S2 | No duplicated logic; one definition used by both paths; the Canvas records the decision with a correct reason | met (minor wording caveat) | See D2. The reasoning (one-line rule, no service needed, helper shared within one plugin) matches the corrected rubric. Caveat: "single use" is loose, because the helper has two call sites, although both are in one plugin. See finding 2. |
| S3 | Test-first: RED acceptance tests (cleared → re-defaulted; real value → untouched), then green | met | Canvas Evidence :115-120 records `Total: 9, Failed: 4`, naming each failing test and its actual value. GREEN is in `work/test-green.log` (`Total: 9, Errors: 0, Failed: 0, Skipped: 0`). The acceptance list :14-21 covers null, '', whitespace, non-empty untouched, not-sent does not fire, and no recursion. Independent reproduction (`r1/red-repro`, kept from the earlier grading): the baseline plugin with the final tests gives `Total: 9, Failed: 5`, so the tests are genuinely RED without the implementation. Caveat: no raw RED log was saved, and the tests and the code share one commit. |
| S4 | `vela-code-review` PASS; SOLID/DRY axis confirms no duplication; spec axis confirms reuse honoured | met | The actor's Build Report :123-129 records a fresh-reviewer PASS with 6 Nits, but no per-axis text. To close that gap, the grader dispatched a new fresh `vela-reviewer`, given only `work/review-diff.patch` and the Canvas. It returned: spec PASS, standards PASS, 0 Critical/Required, 7 Nits. It found no duplication (one helper at :45-51 plus the constant at :11, called at :34 and :41). It found the reuse decision honoured (the existing file was extended; the Run trace shows `vela add step`). It confirmed Sync/PreOperation/FilterOn(Description). |

## Planted-violation results
The planted copies (`r1/planted-a|b|c`, diffs `r1/planted-<x>.diff`) and their results come from the earlier grading, as permitted. Each planted copy built with 0 warnings and 0 errors. Each was reviewed by a fresh read-only `vela-reviewer` subagent given only the diff and the Canvas. These violations do not depend on the corrected criterion: a copy-paste into a second class is a DRY violation under both the old and new wording.

| Violation | Expected | Reviewer verdict | Result |
|---|---|---|---|
| (a) Defaulting logic copy-pasted into a second class (`AccountDescriptionUpdateRule`: duplicate constant and check, called from `HandleUpdate`) | BLOCK ≥ Required | BLOCK, Required: duplicated logic between the two steps; also Canvas drift | pass |
| (b) Hand-created plugin class `AccountDescriptionOnUpdate` instead of `vela add step` | BLOCK ≥ Required | BLOCK, Required: a hand-created class contradicts the reuse decision; also untested registration and evidence mismatch | pass |
| (c) Update step `.PostOperation().Async()` (`IUpdatePostContext`) | BLOCK at Critical | BLOCK, **Critical**: the `ctx.Request.Target` edit is never saved; also Required spec/Approach drift. The harness also fails 5/9. | pass |

All three planted violations are blocked at the expected severity or higher.

## Findings against the skills
1. minor - The service rule is still worded in a way that could read as "requires a service" for logic shared by two steps.
   - `references/registration-rules.md:75-78` says: "real logic in a service when it is reusable or worth testing in isolation ... Do not extract a service for a one-line, single-use operation".
   - `skills/vela-plan-review/SKILL.md:41-42` says: "Real/reusable logic → a service (`vela add service`) ...; don't extract for a one-liner."
   - Logic shared by two steps of one plugin is "reusable" but not cross-plugin. The corrected scenario says a private helper is right there and a service is needed only across plugins. The pack does not say that explicitly.
   - This run chose correctly, and the reviewer agreed. Stating "shared within one plugin → private helper + const; shared across plugins → service" in both places would make the outcome depend on the pack rather than on how the model reads "reusable".
2. minor - `references/registration-rules.md:77` pairs "one-line" with "single-use". The actor's Canvas (S - Structure :71) justifies "No service (a one-line rule, single use)" for a helper with two call sites.
   - Neither the plan-review self-grill nor the reviewer questioned that inaccurate premise.
   - The checklist could ask the author to state the call sites (count, and same or different plugin) when justifying not extracting a service.
3. minor - `skills/vela-code-review` does not require the Build Report to hold the reviewer's per-axis verdicts (spec PASS/BLOCK, standards PASS/BLOCK) or its DRY/reuse conclusions. The actor's report records only "PASS" and a list of Nits, so the grader had to re-dispatch a reviewer to evidence S4.
   - Also, the actor's first reviewer dispatch went out with a placeholder instead of the diff ("Process slip" in the actor report). Nothing in the pack caught this.
   - Suggestion: have the dispatcher check that the prompt contains the diff text before dispatching, and record the per-axis verdicts.
4. minor (scaffold/CLI, not the skills) - `vela add step ... --message Update` emits PostOperation, `IUpdatePostContext` and `FilterOn(e => e.Id)`. For a "set a value on the record being written" behaviour the agent must correct all three. The skills led the actor to do this, as recorded in the Canvas "What was built" :103-106. The fix is flagged for the CLI's defaults and needs no skill change.

## Verdict
**pass.** Checks pass 16/16. Every criterion is met under the corrected rubric:
- The step is reused via `vela add step`.
- The logic is defined once, as a helper plus a constant shared by Create and Update.
- The Update step is Sync PreOperation on Target with FilterOn(Description).
- RED then GREEN is evidenced and independently reproduced.
- Review PASS is confirmed per axis by a fresh reviewer.

All three planted violations are blocked at the required severity.

The next runs should re-check two things:
- that the Canvas justification for not using a service is accurate about call sites (finding 2);
- that the review verdict is persisted per axis (finding 3).
