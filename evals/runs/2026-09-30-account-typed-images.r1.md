---
scenario: account-typed-images
date: 2026-09-30
verdict: pass
campaign: 2026-09-30
run: 1/3
checks: pass
grader: pass
model: claude-opus-5-5
vela_cli: 0.21.0
framework: 0.29.4
runner: "campaign actor + separate grader"
---

## Loop outcome
- Challenge: asked the human what "lowered" means and which solution/prefix to use. Answer: (a) a real drop only; ZavaSales / zava. Recorded in the Canvas `decisions`.
- Scaffold: the first `vela init` (default core 0.29.6) quietly floated to Vela 1.0.0 (NU1603), so the actor discarded it. It then ran `vela init --name ZavaSales --prefix zava --no-integrations --no-console --core-version 0.29.4` (exit 0), removed the demos and ran `vela add plugin ... --message Update --filtering-attributes CreditLimit` (exit 0).
- Model: no org, so the actor added `CreditLimit` and `Description` to `Account.cs` as a no-org stand-in labelled `// STAND-IN for vela-models`. This is the path `vela-plugin-authoring` step 2 sanctions.
- RED: commit `7bca6bb`, 9 tests, 4 failed. **The grader reproduced this** by cloning `7bca6bb`: `Total: 9, Errors: 0, Failed: 4` (AC1, AC7, AC8, AC9).
- GREEN: 9/9 with mono xunit.console `-parallel none`. `checks.json` re-ran them independently: total=9, failed=0.
- Review: an isolated vela-reviewer returned PASS with 0 Critical/Required and 5 Nits (Build Report lines 116-121).
- Package built. `vela plan` was skipped (no org) and the exact command is recorded. The actor stopped at the apply gate and did not run `apply`.

## Deterministic checks
14/14 passed; no failed check.

## Criteria

| # | Criterion | Met? | Evidence |
|---|---|---|---|
| S1 | Pre-image comes from `WithPreImage(e => e.CreditLimit)` and is read through typed `ctx.PreImage` | met | `AccountCreditLimitReduced.cs:18` `.WithPreImage(e => e.CreditLimit)`; `:32` `ctx.PreImage?.CreditLimit` |
| S2 | Plugin class is `partial` (CS0260 avoided) | met | `AccountCreditLimitReduced.cs:10` `public sealed partial class`; check "src contains /partial\s+class/" ok; build 0 errors |
| S3 | "Lowered" means the value actually differs: the sent value is compared with the pre-image | met | `:33` `newLimit.Value >= previousLimit.Value` → return; AC3 same-value test (`Tests.cs:51-55`); Canvas Safeguards line 94-95 |
| S4 | Stage is PreOperation and the write goes to `ctx.Request.Target` | met | `:15` `.PreOperation()`, `:41` `target.Description = ...`; check "step registered: Update account PreOperation/Synchronous filter=['creditlimit']"; check "no UserService.Update/Create" ok |
| S5 | Tests supply the pre-image and cover lowered, raised, same value and cleared (null) | met | `Tests.cs:28-32` `.WithPreImage(preImage)` plus pipeline tests AC6/8/9; AC1 lowered, AC2 raised, AC3 same, AC5 cleared (null sent), AC4 set-from-empty |
| H | Human answer: null or set-from-empty is not "lowered" | met | `:33` null guards; AC4 and AC5 assert description untouched |
| H | Solution / prefix is ZavaSales / zava | met | Canvas lines 24-25; `zava.Plugins`; apply command carries `--solution ZavaSales` |
| C1 | CS0260 avoided through `partial` | met | same as S2 |
| C2 | RED then GREEN over the four cases, with no write when the value did not go down | met | RED reproduced by the grader at `7bca6bb` (4 fail; the four-case set includes AC1). GREEN: `checks.json` "tests re-run green (>= 4)" total=9 failed=0. No-write cases AC2, AC3, AC4 and AC5 assert `!Contains("description")` |
| C3 | Build clean of VELA00x, and `vela-code-review` PASS | met | checks "build succeeds" and "no VELA diagnostics" ok; Build Report lines 116-121: PASS, 0 Critical/Required |

## Planted-violation results
The scenario has no "Planted-violation check" section, so none were applied.

## Findings against the skills
1. minor - `skills/vela-scaffold/SKILL.md:126-128` says: "The **baseline scaffold build fails right after `vela init`** (an incompatible auto-resolved framework version): pin a known-good core with `vela init --core-version <v>`". In this run the default scaffold pinned Vela 0.29.6, which is not on nuget.org. NuGet silently resolved 1.0.0 with warning NU1603, and the baseline build **did not fail**. The red flag only fires on a failure, so it would not have caught this. The actor noticed NU1603 on its own and re-scaffolded with `--core-version 0.29.4`. Suggested fix: extend the red flag to "baseline restore warns NU1603 / resolves a different Vela.Plugins version than pinned", and tell the agent to check the resolved version, not only the build exit code.

## Fixes
- none yet (grader does not edit the pack)

## Verdict
**pass.** Checks passed 14/14. Every scenario criterion is met from the artifacts, and the grader reproduced RED independently. There were no planted violations to test. Next run re-checks: `partial` is still added without prompting, the AC3 same-value case is present, and the scaffold framework version is verified to have resolved as pinned.
