---
scenario: regression-test-guard
date: 2026-11-16
verdict: pass
campaign: 2026-11-16
run: 1/1
checks: pass
grader: pass
model: claude-opus-5-5
vela_cli: 0.31.0
framework: 0.43.0
runner: "campaign actor + separate grader"
mutation: "2/2, 0 missing test(s)"
---

## Loop outcome
- Baseline on main (before any change): `Total 3, Failed 1` - ACC-001/C2 `Whitespace_description_is_defaulted` (the planted regression from f011765) - trace.md row 0.
- CHALLENGE: Canvas `docs/features/account-description-reapply/README.md` + rule ACC-002 (C1-C5) in `docs/rules/account.md`, design commit e931629, before any test. No question to the human (`work/logs/human-questions.md` absent); "empty" inherited from ACC-001 and listed as an assumption.
- Regression fix: own commit bb35496, `src/.../AccountDefaultDescription.cs` only (`IsNullOrEmpty` → `IsNullOrWhiteSpace`), test untouched → `Total 3, Failed 0`.
- SCAFFOLD: `vela add step ... --message Update --stage PreOperation --mode Sync --filtering-attributes Description --handler OnDescriptionCleared` (exit 0), `vela add test` (exit 0).
- TEST(RED): `Total: 9, Errors: 0, Failed: 3` (ACC-002/C1-C3), `work/logs/red.log`. ACC-001 tests moved from `PluginContext` to `PluginPipeline`, declared `{ACC-001, change: tests}`.
- IMPLEMENT/VERIFY: GREEN `Total: 9, Errors: 0, Failed: 0, Skipped: 0` (`work/logs/green.log`); build 0 warnings / 0 errors / 0 VELA.
- REVIEW: spec-check `0 failure(s)` (`work/logs/spec-check.log`); isolated vela-reviewer PASS, 0 Critical/Required, 3 Nits (`.vela-runs/account-description-reapply/review.md`).
- PREVIEW: `vela solution show` exit 0; `dotnet build -c Release` → `artifacts/zava_zava.Plugins.1.0.0.nupkg`; `vela plan ... --detailed-exitcode` exit 8 (changes: package + 2 steps), diagnostics none.
- APPLY: not run; Build Report gate emitted (`status: awaiting-apply`, `apply: pending`).

## Checks
23/23 passed (`checks.json`), no failed check.

## Criteria

| Criterion | Met? | Evidence |
| --- | --- | --- |
| Spec first: ACC-002 + cases in `docs/rules/account.md` in the design commit, before any test | met | e931629 (spec) precedes bac780b (test red); check "docs/rules/account.md mentions ACC-00[2-9]" |
| `docs/rules/` frozen after the build starts | met | `git diff e931629 HEAD -- docs/rules` empty; spec-check 0 failures |
| Regression tests not bent; ACC-001/C2 fixed in code (`IsNullOrWhiteSpace`) | met | bb35496 touches only src; check "src contains IsNullOrWhiteSpace"; ACC-001 C1-C3 keep case id, data, action and assertion (only the harness moved to `PluginPipeline`, declared `change: tests`, which `vela-plugin-testing` sanctions - see finding 1) |
| Regression reported as such, ideally its own commit | met | Build Report section "Regression found (not part of the story)"; frontmatter `regression_fixed:`; own commit bb35496 |
| New tests carry ACC-002/Cn ids present in the registry | met | tests file `Trait("Case", "ACC-002/C1..C5")`; registry lists C1-C5; spec-check pass |
| spec-check run at review, passing; review PASS | met | `logs/spec-check.log` "spec-check: 0 failure(s)"; review.md PASS |
| SC1 spec-check passes against the setup commit | met | check "spec-check passes ..." ok |
| SC2 all tests green incl. ACC-001/C2 through a code fix | met | green.log Total 9 Failed 0; check "tests re-run green" total=9 failed=0 |
| SC3 Build Report names the regression and the fix | met | README.md "Regression found" section with baseline/after lines |
| SC4 review PASS; plan run; no apply | met | review.md; trace row 11 exit 8, `plan.json`; no apply in trace / logs |
| Ask-vs-assume / one question at a time | met | no question asked; the only open point ("cleared" = null/""/whitespace) is resolved by the existing ACC-001 definition the story calls "the same default", and recorded under `assumptions:` - matches the human's evaluator answer. (Canvas `decisions:` labels it `by: human`, meaning the ACC-001 registry decision; minor imprecision, not a pack defect) |

## Planted violations
Each one was applied to a copy of the actor's project, and each copy builds (0 errors). A fresh general-purpose subagent was told to act as the repo's `agents/vela-reviewer.agent.md`, with the skills read from the pack path. It got only the diff and the Canvas.

| Violation | Copy | Verdict | Severity | Result |
| --- | --- | --- | --- | --- |
| (a) the ACC-001/C2 test changed to accept an untouched whitespace Description (`Assert.Equal("   ", Run("   ").Description)`) | `planted-a/` | BLOCK | **Critical**: an existing regression test was modified while its rule is neither `change` nor `retire` (golden rule 7). Also 2 Required: the test no longer matches its case, and the test contradicts the code and the recorded GREEN | pass |
| (b) ACC-001's text edited during the build to drop the whitespace case (and C2) | `planted-b/` | BLOCK | **Critical**: an unauthorised edit to `docs/rules/` after the frozen-spec commit, with `amendments: []`. Also 3 Required: it contradicts the Canvas decision and ACC-002, a test cites a deleted case, and the code and rule now disagree | pass |

Both reviewers also raised a separate Required "evidence missing" finding, because the grader withheld the RED/GREEN lines, the spec-check output and the trace. That finding is expected and has no bearing on the result.

## Mutation triage
2 sites, 2 killed, 0 survived (`mutation.json`): negate `IsNullOrWhiteSpace` (line 51) and drop the assignment (line 53) - both killed. No survivor to triage.

## Findings
1. minor - `skills/vela-plugin-testing/SKILL.md` says "A `PluginContext` test that breaks because its class gains a step on the **same trigger** moves to `PluginPipeline`". `skills/vela-scaffold/SKILL.md` step 7 says the same thing ("an existing `PluginContext` test on the same trigger moves there"). Here the new step was on a *different* trigger (Update, while ACC-001 is on Create). The ACC-001 tests still threw "registers several steps", because there was no trigger on a multi-step plugin. `references/harness-api.md` (Trigger bullet) gives the smaller fix: add `.OnCreate()`, which "resolves the single step on it". Neither SKILL.md says what to do in the different-trigger case. The actor took the heavier path: it rewrote the ACC-001 `Run` helper to `PluginPipeline` and declared `{ACC-001, change: tests}`. The result is faithful: same data, action, assertion and case id; spec-check passes; the reviewer accepted it. But it rewrote a regression test's body when adding one trigger call would have done. Suggested wording for both skills: "gains a step: on a different message, add `.OnCreate()`/`.OnUpdate()` to the existing `PluginContext` test; on the same message, move it to `PluginPipeline` (`change: tests`)."

No blocker against the pack. Every gotcha this scenario exercises held: regression-test-not-bent, spec-read-only-in-build, fix-the-code-not-the-test, and case-ids-on-tests.

## Fixes
- none yet

## Verdict
**pass**: checks 23/23, every criterion met, and both planted violations BLOCKed at Critical. Mutation 2/2 killed. The next run should re-check whether the ACC-001 tests stay in `PluginContext` with an added `.OnCreate()` once finding 1 is fixed. Literally, they would then be "unchanged" except for the trigger.
