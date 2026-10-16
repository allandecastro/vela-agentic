---
scenario: account-typed-images
date: 2026-10-13
verdict: pass
campaign: 2026-10-13
run: 1/3
checks: pass
grader: pass
model: claude-opus-5-5
vela_cli: 0.25.0
framework: 0.34.0
runner: "campaign actor + separate grader"
---

## Check summary
`checks.json`: **18/18 passed**, no failed check. Highlights: build succeeds, no VELA diagnostics, tests re-run
green (total=9 failed=0), step registered `Update account PreOperation/Synchronous filter=['creditlimit']`, exactly 1
authored step, src contains `partial class`, no `Service.Update/Create` in src, package holds the plugin dll, read-only
`vela plan` runs and creates only authored steps.

## Loop outcome
- `vela version` -> 0.25.0 (exit 0); grill: 2 questions (clearing semantics, target solution) answered by the human.
- `vela solution show ZavaSales --json` -> `{"solution":"ZavaSales","publisherPrefix":"zava"}` (exit 0).
- `vela init` (0), `vela models --entities account` (0, 4 files), `vela add plugin ... --stage PreOperation --mode Sync --filtering-attributes creditlimit` (0), `vela add test` (0).
- RED at commit d7ec608 (empty handler): mono xunit.console `-parallel none`, `Total: 9, Failed: 3` (exit 1) - the three "lowered" cases.
- GREEN at commit 1cf9b66: `Total: 9, Failed: 0` (exit 0). `dotnet build -c Release --no-incremental`: 0 errors, 0 warnings.
- Review: isolated vela-reviewer dispatch refused (concurrent subagent limit) -> documented self-review fallback, labelled; PASS, 3 Nits.
- `dotnet build -c Release` -> `artifacts/Zava.Plugins.1.0.0.nupkg` (dll checked, sha256 recorded); `vela plan --detailed-exitcode` exit 8 (create package + 1 step, pre-image [creditlimit]). Stopped at the apply gate; no apply.

## Criteria
| Criterion | Met? | Evidence |
| --- | --- | --- |
| Pre-image via registered `WithPreImage(e => e.CreditLimit)`, read through typed `ctx.PreImage` | met | `CreditLimitReducedPlugin.cs:22` `.WithPreImage(e => e.CreditLimit)`; `:30` `ctx.PreImage.CreditLimit?.Value`; plan shows preImage [creditlimit] |
| Plugin class declared `partial` (CS0260 avoided) | met | `CreditLimitReducedPlugin.cs:12` `public sealed partial class`; check "src contains partial class"; present since scaffold (RED commit d7ec608) |
| "Lowered" = value actually differs; same value sent does nothing | met | `:33` `after.Value >= before.Value` -> return; test `Same_Value_Sent_Leaves_Description` (step runs, Description untouched) |
| PreOperation edit of `ctx.Request.Target` (no write-back) | met | `:19` `.PreOperation()`, `:40` `ctx.Request.Target.Description = ...`; check "src must not contain Service.Update/Create" ok; step check PreOperation/Synchronous |
| Tests supply the pre-image (pipeline) and cover lowered, raised, same, cleared | met | `CreditLimitReducedPluginTests.cs` uses `PluginPipeline.Register<>().Seed(...)` (pre-image built from seeded record); cases lowered (:56, :69, :80), raised (:91), same (:104), cleared (:115), null->value (:128), not sent (:139) |
| Human answers honoured (null/cleared and set-from-none not "lowered"; ZavaSales/zava) | met | `:33` null guards; Canvas decisions lines 27-28; solution/prefix lines 14-15; tests :115, :128 |
| SC1: CS0260 avoided | met | as above; build clean |
| SC2: RED then GREEN over the four cases; no write when not lowered | met | `review/red.txt` Failed: 3 at d7ec608 (handler empty, logic absent); `review/green.txt` 9/9; no-op tests assert Original description + single run |
| SC3: build clean of VELA00x; `vela-code-review` PASS | met | check "no VELA diagnostics"; Build Report lines 101-110: self-review (labelled fallback, per evaluator note) PASS, 0 Critical/Required |
| Stop before apply / plan on the final package | met | Build Report status `awaiting-apply`, plan exit 8 on the hashed package, gate section lines 144-150 |

Self-review quality: adequate. It checked the spec axis (acceptance cases, pre-image registration, filter, recursion)
and standards (no ctx.Service writes, no mutable fields, no secrets), and raised two relevant Nits (user-sent Description
overwritten in the same Update; Money compared without currency check). Nothing material was missed.

## Planted-violation results
The scenario has no "Planted-violation check" section; none were run.

## Findings against the skills
None blocking. Minor:
1. minor - the `vela add test` scaffold leaves a generic `Fires_On_Update` test (`CreditLimitReducedPluginTests.cs:46`)
   that duplicates what the acceptance cases already assert (`AssertRanOnce`). Harmless, but the test count (9) then
   exceeds the declared acceptance cases (8); `AGENTS.md` asks that "the green cases equal the declared acceptance cases".
   The pack could say whether scaffolded smoke tests should be kept or folded into the acceptance cases.
2. minor - the Canvas front-matter records `filtering_attributes: [CreditLimit]` (property name) while the
   registration/plan use the logical name `creditlimit`; `build-report-template.md` could state which form to use.

## Fixes
- none yet.

## Verdict
pass - checks 18/18 and every scenario criterion met from the artifacts. Next runs must re-check that the pre-image is
registered (not only read) and that the same-value case is covered with the step actually executing.
