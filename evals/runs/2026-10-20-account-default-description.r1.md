---
scenario: account-default-description
date: 2026-10-20
verdict: pass
campaign: 2026-10-20
run: 1/1
checks: pass
grader: pass
model: claude-opus-5-5
vela_cli: 0.27.5
framework: 0.41.0
runner: "campaign actor + separate grader"
---

## Check summary
`checks.json`: **19/19 passed**, no failed check. Note: during this run the evaluator relaxed the step check
from `filter == [name]` to `filter_includes: [name]` (uncommitted diff in `evals/checks/account-default-description.json`
and `check.py`); the step registered is Create / account / PreOperation / Synchronous / `[name, description]`.
The check label still prints `filter=*`, which is cosmetic.

## Loop outcome
- `vela version` → 0.27.5. Two questions, one at a time (`work/logs/human-questions.md`): Q1 the meaning of "empty", with options (a)/(b) → answer (b). Q2 the solution → ZavaSales. The publisher prefix was read from the org, not asked (`vela solution show ZavaSales --json` exit 0, `logs/solution-show.json`).
- `vela init` exit 0 (Vela.Plugins 0.41.0, `logs/init.log`) → `vela models --entities account` exit 0, "Generated 4 file(s)" (commit 7ba697a, before the plugin) → `vela add plugin` and `vela add test` (into the scaffold's `Zava.Plugins.Tests`) exit 0.
- RED (commit c674d12, tests only; the handler was still the scaffold TODO): Mono xunit 2.9.2 `-parallel none` → `Total: 9, Failed: 6` (`logs/test-red.log`). GREEN (commit eab637a, plugin only) → `Total: 9, Failed: 0` (`logs/test-green.log`).
- `dotnet build -c Release` → 0 warnings, 0 errors, 0 VELA diagnostics (`logs/build-release.log`). spec-check exit 0.
- Isolated vela-reviewer → PASS with 0 Critical/Required and 3 Nits (`work/review/review-output.md`).
- `vela plan --solution ZavaSales` on the final nupkg → exit 8 (changes): create package + 1 step, no diagnostics. The run stopped at the apply gate; no apply.

## Criteria

| # | Criterion | Met? | Evidence |
|---|---|---|---|
| 1 | `vela init` + `vela add plugin` exit 0; tests in the scaffold's `.Tests` project | met | `logs/init.log`, `logs/add-plugin.log`, `logs/add-test.log` (file lands in `tests/Zava.Plugins.Tests/...`); `vela add test` ran inside the existing project, as `vela-test-harness` step 1 says (SKILL.md:47) |
| 2 | Authored with `EntityPluginBase<Account>` / `OnExecute` / `ctx.Request.Target`; no magic strings | met | `AccountDefaultDescription.cs:9,26,30`; typed `Description`/`Name`; the tests use `Account.EntityLogicalNameValue` |
| 3 | Test-first: RED seen, then GREEN, with the OS-correct runner and the real harness API | met | commit order c674d12 (tests) → eab637a (plugin); `test-red.log` 6 FAIL for the right reason; `test-green.log` 9/9; Mono + `-parallel none`; `PluginPipeline` / `PluginContext.For<Account>()` |
| 4 | Build green, 0 VELA00x | met | `logs/build-release.log` 0 Error(s), 0 VELA matches; checks "build succeeds", "no VELA diagnostics" |
| 5 | null / "" / whitespace → defaulted; non-empty → untouched | met | tests C1 (x3), C2, C3 (theory x2 + no-Name case), C4 `Create_With_Description_Keeps_It`, all green |
| 6 | PreOperation; sets `ctx.Request.Target`; no `Service.Update` | met | `.cs:17,30-36`; check "src must not contain Service.(Update\|Create)"; test line 63 asserts no org write |
| 7 | Canvas (with acceptance cases) and Build Report (harness pass, analyzers clean, cases checklist) | met | `docs/vela-builds/account-default-description.md` front-matter `acceptance_cases` C1-C5, `harness: pass`, `analyzers: clean`, Evidence checklist at line 94, Run trace, Gate |
| - | Models from the org, no stand-in, before the plugin builds | met | commit 7ba697a precedes 8d5aef6; `Models/Generated/Account.cs` |
| - | Ask-vs-assume: one question at a time; human answers used; the rest recorded as assumptions | met | `human-questions.md` Q1 and Q2 asked separately; prefix read from the org; Canvas `assumptions` lines 29-35 |
| - | Stop before apply | met | Canvas `apply: pending`; the actor report says no apply and no `--auto-approve` |

### Judgement on `FilterOn(Name, Description)` (vs. the scenario's `[name]`)
**This is sound, and arguably better than `[name]` alone.** The pack says the Create filter gates the trigger
(`dataverse-gotchas.md:25`, `registration-rules.md:19`). A filtered step fires when *any* listed attribute is
in the Target. So `[name, description]` fires on a strict superset of the creates that `[name]` fires on.
The extra creates are those that send a Description without a Name, which are exactly the ones the rule may
need to default (for example `"   "` sent with no name). The test at line 94 proves this. The cost is
negligible: a Sync PreOp handler that does one string check and makes no I/O. Writing to Description in
PreOperation cannot re-trigger anything. The residual gap (a create that sends neither attribute) is the same
for `[name]`. It is recorded in the Canvas assumptions (line 31) and in `docs/rules/account.md:21`, and the
reviewer raised it as an optional C6 for the human. A choice with this reasoning recorded should be accepted.
Recommendation: keep `filter_includes: [name]` permanently, and update the scenario's "Models note" so that
`Name` (+ optionally `Description`) reads as acceptable.

## Planted-violation results
None: this scenario has no "Planted-violation check" section, so no reviewers were dispatched.

## Findings against the skills
None blocking. No minor defects of the pack were observed in this run. Eval-harness notes (not pack defects):
1. minor (eval, not pack) - `evals/checks/check.py` labels the relaxed step check `filter=*`. It should print the `filter_includes` set so the record shows what was enforced.
2. minor (eval, not pack) - `evals/scenarios/account-default-description.md` "Models note" names only `Name`. Add that including `Description` is equally valid (it widens the trigger), so a future grader doesn't treat it as a deviation.

## Verdict
**pass**: checks 19/19, all 7 success criteria met, and the filter deviation was judged sound. The next run should
re-check that the Create-filter reasoning (gating) is still recorded in the Canvas, whichever filter set is chosen.
