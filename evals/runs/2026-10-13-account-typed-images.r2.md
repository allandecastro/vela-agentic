---
scenario: account-typed-images
date: 2026-10-13
verdict: pass
campaign: 2026-10-13
run: 2/3
checks: pass
grader: pass
model: claude-opus-5-5
vela_cli: 0.25.0
framework: 0.34.0
runner: campaign actor + separate grader
---

## Check summary
`checks.json`: **18/18 passed**, no failed checks (build, no VELA diagnostics, tests re-run green total=9,
step Update/account/PreOperation/Sync filter `creditlimit`, exactly 1 authored step, `partial class` present,
no `Service.Update/Create` in src, package holds the dll, solution ZavaSales/zava, read-only plan creates only
the authored package + step).

## Loop outcome
- `vela solution show ZavaSales --json` exit 0 (publisherPrefix zava) -> `vela init` exit 0 -> `vela models --entities account` exit 0
  -> `vela add plugin ... --stage PreOperation --mode Sync --filtering-attributes creditlimit` exit 0 -> `vela add test` exit 0.
- RED (commit 3aec263): Mono xunit.console `-parallel none` exit 1, `Total: 9, Errors: 0, Failed: 3` (the 3 "lowered" cases) - `work/test-red.log:37`.
- GREEN (8750201): `Total: 9, Errors: 0, Failed: 0` - `work/test-green.log:7`; build `0 Warning(s) 0 Error(s)` - `work/build-green.log:12-13`.
- Review: self-review (subagent dispatch refused, concurrent limit - the pack's documented fallback, labelled) PASS, 0 Critical / 0 Required / 3 Nits.
- `dotnet build -c Release` -> `artifacts/Zava.Plugins.1.0.0.nupkg` (dll inside, sha256 recorded) -> `vela plan --detailed-exitcode` exit 8 (create package + 1 step, diagnostics []).
- Stopped at the apply gate; `vela apply` not run.

## Criteria
| Criterion | Met? | Evidence |
| --- | --- | --- |
| Pre-image registered `WithPreImage(e => e.CreditLimit)`, read via typed `ctx.PreImage` | met | `src/Zava.Plugins/Account/Plugins/AccountCreditLimitReduced.cs:19,28`; plan JSON pre-image `PreImage` [creditlimit] |
| Plugin class is `partial` (CS0260 avoided) | met | `AccountCreditLimitReduced.cs:9` `public sealed partial class`; check "src contains partial class"; build 0 errors |
| "Lowered" = value actually differs; same value sent does nothing | met | `AccountCreditLimitReduced.cs:30` (`after >= before` -> return); test `Same_Value_Sent_Leaves_Description` asserts step ran and Description untouched |
| PreOperation on `ctx.Request.Target`, no write-back | met | `AccountCreditLimitReduced.cs:16,36`; check "src must not contain Service.Update/Create" ok; step check PreOperation/Synchronous |
| Tests supply the pre-image (pipeline) and cover lowered, raised, same, cleared | met | `AccountCreditLimitReducedTests.cs` - PluginPipeline seeds the record so the pipeline builds the pre-image; `Lowered_Sets_Description`, `Raised_Leaves_Description`, `Same_Value_Sent_Leaves_Description`, `Cleared_Leaves_Description` (+ to-zero, overwrite, set-from-empty, not-sent) |
| Null semantics per human answer (cleared / set-from-none is not lowered) | met | `AccountCreditLimitReduced.cs:30` null guards; tests `Cleared_Leaves_Description`, `Set_From_Empty_Leaves_Description`; Canvas decisions line 28 |
| Solution / prefix ZavaSales / zava | met | Canvas lines 14-15; check "target solution ZavaSales exists" |
| SC1: CS0260 avoided by `partial` | met | as above (the `vela add plugin` scaffold already emits `partial`, see git show 3aec263) |
| SC2: RED then GREEN over the four cases; no write when not lowered | met | `test-red.log:5,15,25,37` (3 lowered cases fail for the right reason); `test-green.log:7`; negative cases assert Original Description |
| SC3: build clean of VELA00x; `vela-code-review` PASS | met | `build-green.log:12-13`, check "no VELA diagnostics"; `docs/vela-builds/account-credit-limit-reduced.review.md` verdict PASS (self-review, labelled, both axes covered, reasonable Nits incl. cross-currency edge) |
| Canvas / Build Report, stop before apply | met | `docs/vela-builds/account-credit-limit-reduced.md` (status awaiting-apply, plan evidence, hash, gate section) |

## Planted-violation results
None - the scenario has no "Planted-violation check" section.

## Findings against the skills
None blocking; no minor skill defects observed.

Observation (scenario, not the pack): `vela add plugin` (Vela.Plugins 0.34.0) already emits `public sealed partial class`
(git show 3aec263), so the `typed-image-partial-cs0260` gotcha is avoided by the CLI template rather than exercised by
the skills; the scenario no longer tests whether the skills teach it.

## Verdict
pass - checks 18/18 and every criterion met. Next run should re-check that the RED step fails the "lowered" cases for the
behavioural reason (not a compile error) and that the same-value case asserts the step actually ran.
