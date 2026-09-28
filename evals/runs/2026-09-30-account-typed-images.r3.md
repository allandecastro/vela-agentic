---
scenario: account-typed-images
date: 2026-09-30
verdict: pass
campaign: 2026-09-30
run: 3/3
checks: pass
grader: pass
model: claude-opus-5-5
vela_cli: 0.21.0
framework: 0.29.6
runner: "campaign actor + separate grader"
---

## Checks
`checks.json`: **14/14 passed**, no failed checks. These include: the build succeeds, there are no VELA diagnostics, the tests re-run green (13 of them), and exactly one step is registered: Update account PreOperation/Synchronous with filter `['creditlimit']`. The source has no `UserService.Update/Create`, and it contains `partial class`.

## Loop outcome
- Version: `vela 0.21.0` (Canvas run trace #1; the grader re-ran it and got `vela 0.21.0`).
- Challenge (vela-plan-review / vela-grill): the actor asked the human about solution/prefix and the "cleared" semantics. The answers match the evaluator's (ZavaSales/zava; cleared and empty->value are not lowered). Canvas lines 28-31.
- Scaffold: `vela init ZavaSales --prefix zava -o . --no-integrations --no-console`, exit 0, Vela.Plugins 0.29.6. The demos were removed in commit 6ad8e36.
- Models: skipped (no org). The model has labelled `// STAND-IN for vela-models (no org)` properties (`src/zava.Shared/Models/Generated/Account.cs:46,54`).
- Add plugin/test: both exit 0. The plugin was realigned to PreOperation, the pre-image and `partial` (commit fe4fdfd).
- RED (commit 61dd614): **independently reproduced by the grader** on a clone at that commit. The build has 0 errors and 0 warnings. Result: `Total: 13, Errors: 0, Failed: 5`. The 5 "set Description" cases fail; the guard cases pass.
- GREEN: `checks.json` "tests re-run green (>= 4)": total=13, failed=0.
- Review: an isolated vela-reviewer returned PASS: 0 Critical, 0 Required, 6 Nits (Canvas lines 106-112).
- Package: `artifacts/zava.Plugins.1.0.0.nupkg`. `vela plan` was skipped (no org) and the exact command is recorded. The actor stopped at the apply gate, and `vela apply` was never run.

## Criteria
| Criterion | Met? | Evidence |
|---|---|---|
| Pre-image registered with `WithPreImage(e => e.CreditLimit)` | yes | `AccountCreditLimitReducedPlugin.cs:20` |
| Old value read through typed `ctx.PreImage` | yes | `AccountCreditLimitReducedPlugin.cs:29` `ctx.PreImage?.CreditLimit` |
| Plugin class `partial` | yes | `AccountCreditLimitReducedPlugin.cs:10` `public sealed partial class`; check "src contains partial class" |
| "Lowered" = value actually differs (sent vs pre-image; same value is a no-op) | yes | `.cs:30` `newLimit.Value >= previousLimit.Value` returns; tests `SentWithSameValue_*` (tests:71), `Pipeline_SameValue_*` (tests:121) |
| PreOperation on `ctx.Request.Target` | yes | `.cs:17,36`; check "step registered ... PreOperation/Synchronous"; check "no UserService.Update/Create"; test `Lowered_WritesNothingExtraToTheOrg` asserts `crm.GetAll("account")` is empty (tests:59) |
| Tests supply the pre-image (`WithPreImage` / pipeline) | yes | tests:168 `.WithPreImage(preImage)`, tests:54; `PluginPipeline.Seed` at tests:175-178 |
| Tests cover lowered, raised, same, cleared (null) | yes | tests:23, 63, 71, 79 (+ pipeline variants 97-140; empty->value 87) |
| Human answer: cleared / set-where-none are not lowered | yes | `.cs:30` null guards; tests:79, 87; Canvas decisions lines 29-30 |
| Human answer: solution/prefix ZavaSales/zava | yes | Canvas lines 14-15; `zava.Plugins` project |
| SC1: CS0260 avoided by `partial` | yes | `partial` present at every commit from fe4fdfd on; build 0 errors (checks "build succeeds") |
| SC2: RED then GREEN over the four cases; no write when not lowered | yes | RED reproduced by the grader (5/13 fail, including all "lowered" cases); GREEN 13/13 (checks); raised/same/cleared assert Description untouched, and PreOp does no org write |
| SC3: build clean of VELA00x; `vela-code-review` PASS | yes | check "no VELA diagnostics"; Canvas lines 106-112 (review findings list: PASS, 0 Critical/Required) |

## Planted-violation results
The scenario has no "Planted-violation check" section, so nothing was planted.

## Findings against the skills
1. minor - The `vela-test-harness` guidance has no rule that negative **pipeline** cases must also assert the step fired. `Pipeline_SameValue_DescriptionUnchanged` and `Pipeline_Cleared_DescriptionUnchanged` (tests:121-140) assert only that the Description is unchanged. If the filter or registration were broken, they would still pass vacuously. The reviewer flagged this only as a Nit. Suggested fix: in `harness-api.md`, require `Assert.Single(p.ExecutionLog)` on every "fires but no-op" pipeline case, because that is what proves the "same value is still sent" gotcha.
2. minor (recurring from the 2026-09-29 run, finding 9) - The reviewer again raised comparing `Money.Value` without `transactioncurrencyid` as a Nit, and `review-checklist.md` still has no item for Money comparisons across currencies. So the handling depends on the reviewer's luck, not on the checklist.
3. minor (recurring, finding 7 of 2026-09-29) - `vela add plugin` still scaffolds a template without the pre-image or `partial`, and a manual "realign" was needed (actor commit fe4fdfd). The actor handled it, but `vela-scaffold` step 5 still doesn't say that the Canvas image and `partial` are applied at scaffold time.

No blocker findings.

## Verdict
**pass**. Checks: 14/14 pass. The grader found every criterion met; the RED phase was independently reproduced; there were no planted violations to test. The next run must re-check that negative pipeline cases assert the step fired (finding 1).
