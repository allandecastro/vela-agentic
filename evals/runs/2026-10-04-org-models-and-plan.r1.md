---
scenario: org-models-and-plan
date: 2026-10-04
verdict: pass
campaign: 2026-10-04
run: 1/3
checks: pass
grader: pass
model: claude-opus-5-5
vela_cli: 0.22.0
framework: 0.30.0
runner: "campaign actor + separate grader"
---

## Check summary
`checks.json`: **17/17 passed**, no failed check. Covered: the Canvas exists, the build succeeds with no VELA diagnostics, the tests re-run green (19 total, 0 failed), the plugin dll is built and is in the nupkg, no scaffold demo is registered, the step is `Update account PreOperation/Synchronous filter=['accountnumber']`, src has no `UserService.Update/Create` write-back, the tests use `PluginPipeline`, the models were generated from the org (4 files), a read-only `vela plan` re-runs, and the plan has no demo operation and creates only authored steps.

## Loop outcome
- `vela version` returned 0.22.0 (`review/evidence.txt:13`).
- `vela init --prefix veval --no-integrations --no-console` ran, followed by the base commit 89da204. The demos were removed in 68a1054.
- `vela add plugin` (Create) and `vela add step` (Update) both exited 0.
- `vela models --entities account --url ...` exited 0 with "Generated 4 file(s) into .../veval.Shared/Models/Generated (namespace veval.Shared.Models.Generated)" (`logs/models.log`). It ran in commit 49d996c. No later commit touches `Models/Generated`.
- RED at 6db84f7: 19 total, 8 failed (`logs/test-red.log`). GREEN at 3888b6d: 19 total, 0 failed (`logs/test-green.log`). The build had 0 warnings and 0 errors.
- The isolated vela-reviewer returned PASS with 0 Critical, 0 Required and 7 Nits (`docs/vela-builds/account-number-uppercase.review.md`).
- The package was built with `dotnet build -c Release`. Its sha256 `ea19faa6...` matches the file on disk at grading time.
- `vela plan -p ... --url ... --out logs/plan.json` exited 0: 2 create-step operations and 1 diagnostic.
- The actor stopped at the gate. There is no `vela apply` anywhere.

## Criteria

| Criterion | Met? | Evidence |
| --- | --- | --- |
| Real models, no stand-in: `vela models` into `<Prefix>.Shared/Models/Generated`, "Generated N file(s)" confirmed, never hand-edited | met | `logs/models.log`; check "models generated from the org"; git history shows Generated touched only in 49d996c; `Account.cs:55` has `AccountNumber`. `--namespace` was passed explicitly instead of inferred, and it resolves to the same in-project namespace. |
| Scaffold for the org: `--prefix veval`, `--no-integrations`, demos removed | met | Build Report run trace row 3; commit 68a1054; check "no scaffold demo registered" |
| PreOperation on `ctx.Request.Target`, `FilterOn(e => e.AccountNumber)` | met | `AccountNumberUpperCasePlugin.cs:20-28,34-40`; check "step registered ..." |
| Create + Update reading flagged (accepted per Human answers) | met | Canvas `assumptions` line 34; `open_questions` / Open questions line 149 |
| Real preview on the final package; operations contain only this plugin's steps; no demo operation | met | `logs/plan.json` lists 2 operations, both `veval...AccountNumberUpperCasePlugin`; checks "plan has no demo operation" and "plan creates only authored steps"; the package hash was unchanged after the plan |
| Every diagnostic read: "assembly not found" explained, rank collision explained, not "fixed" | met | Build Report line 118 explains "not found in Dataverse" as expected on a first deploy. Neither `logs/plan.json` nor `check-plan.json` has a rank-collision diagnostic, so there was none to explain (the gotcha was not exercised in this run). |
| Optional: `models --verify` exits 0 | not run (optional) | No verify log |
| SC1: models generated via `vela models`; build clean of VELA00x | met | `logs/models.log`; check "no VELA diagnostics"; `logs/build-green.log` |
| SC2: RED then GREEN for lower→upper, mixed→upper, already upper→no change, not sent→no fire (`PluginPipeline`) | met | Tests lines 44-56 and 89-101 (lower, mixed, already upper) and 145-157 (`Pipeline_Update_AccountNumberNotSent_StepDoesNotFire`, empty `ExecutionLog`); RED 8/19 failed, then GREEN 19/19 |
| SC3: `vela-code-review` PASS | met | `account-number-uppercase.review.md`: "VERDICT: PASS", 0 Critical/Required |
| SC4: `plan.json` in the Build Report with operations and diagnostics interpreted; Gate hands `vela apply -p <pkg> --solution VelaEvals --url ...` and a hash check | met | Build Report lines 115-118 and 140-145 (shasum check and the exact apply command) |
| SC5: no write to the org | met | Only `models` and `plan` were run against the org (run trace); plan notes say "nothing was written"; no apply or `--auto-approve` in any log |

## Planted-violation results
The scenario has no "Planted-violation check" section, so none were applied.

## Findings against the skills
None blocking. Notes:
1. minor (not a pack defect, recorded for the next run): the scenario lists the gotcha `managed-rank-collision`, but the dev org produced no rank-collision diagnostic for account Create/Update at `executionOrder: 1`. This run did not exercise the "explain, don't fix" path. Later runs, or a scenario tweak, need to confirm it.
2. minor (actor-side, not a pack defect): the Build Report "What was built" line 105 shortens the `vela models` command and drops the `--namespace/--out/--overwrite` that the run trace (row 6) records. The review dispositions say the Contact.cs deletion is in "run trace step 5", but it is in row 6. These are cosmetic inconsistencies.

## Verdict
**pass**. All 17 checks pass, every criterion is met from the artifacts, and there were no planted violations. Next run: re-check the rank-collision diagnostic handling if the org surfaces one, and optionally `vela models --verify`.
