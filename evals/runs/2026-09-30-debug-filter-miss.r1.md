---
scenario: debug-filter-miss
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

## Check summary
`checks.json`: **10/10 passed**, no failed checks (solution found, build succeeds, no VELA diagnostics,
tests re-run green total=3 failed=0, plugin dll built, registration probe runs, step registered
Update/account/PreOperation/Synchronous filter=['description'], exactly 1 authored step, no dotted
Custom API names, tests contain `PluginPipeline`).

## Loop outcome
- `vela version` -> `vela 0.21.0` (Build Report run trace row 1).
- Repro commit `6d973d0`: two `PluginPipeline` tests; RED `Total: 3, Failed: 2` (actor's exit code not
  captured - piped through `tail`). **Grader independently re-built `6d973d0` in a throwaway clone:
  `dotnet build` 0 errors; mono xunit `-parallel none` -> `Failed: 2`, exit 1**, failing for the right
  reasons (`Assert.Single() Failure: The collection was empty` for description-only update;
  `Collection: [Update/PreOperation account ... AccountNormalizeDescription]` for name-only update).
- Fix commit `104763c`: one line in `src/zava.Plugins/Account/Plugins/AccountNormalizeDescription.cs:16`,
  `.FilterOn(e => e.Name)` -> `.FilterOn(e => e.Description)`; handler unchanged (`git diff 1c6c1ed HEAD -- src`).
- GREEN: `test.log` `Total: 3, Errors: 0, Failed: 0`; build 0 warnings / 0 errors.
- Review: isolated vela-reviewer subagent, PASS, 5 Nits (Build Report run trace row 7).
- `vela inspect` / `vela plan`: skipped (no org), exact commands recorded. No `vela apply`.

## Criteria
| # | Criterion | Met? | Evidence |
|---|---|---|---|
| S1 | Reproduce first: harness test updating only `description`, expects normalised value, RED for the right reason | met | `tests/.../AccountNormalizeDescriptionTests.cs` `Update_of_description_only_fires_and_saves_normalised_value`; commit `6d973d0` touches tests only; grader re-run of `6d973d0`: `Assert.Single() Failure: The collection was empty` |
| S2 | Hypothesis from the registration, checked against `dataverse-gotchas.md`, no trial-and-error, no org mutation | met | Build Report Diagnosis (L62-67) cites `RegisterPluginSteps()` FilterOn(Name); Safeguards (L59) cites the gotcha "step never triggers on the change you expect" (`references/dataverse-gotchas.md:25`); 3 commits only, no apply |
| S3 | Fix the single cause, red -> green, nothing else changes; `vela inspect` recorded | met | src diff is the one line; check "exactly 1 authored step(s)"; `vela inspect --package artifacts/zava.Plugins.1.0.0.nupkg --interactive` in Build Report L85 and run trace row 6 |
| C1 | Failing repro written and seen RED before any code change | met | commit order `6d973d0` (tests) < `104763c` (src); Build Report Evidence L74-77; grader reproduction exit 1 |
| C2 | One-line fix; repro and existing suite green | met | `git diff 1c6c1ed HEAD -- src` = 1 line; `checks.json` "tests re-run green" total=3 failed=0; `test.log` |
| C3 | Explanation names the gotcha and the evidence; no "it seems" without output | met | Build Report Diagnosis + Evidence carry the RED/GREEN runner output; no "seems/probably"; "should" only on expected outcomes of unrun, recorded commands |
| C4 | If it asks for the Plug-in Trace Log: where + which fields; no org reads around the CLI | met (note) | Actor did not rely on the trace log (open question, Build Report L26, is an optional "no row with tracing on" confirmation); no org access at all. Note: that optional ask omits the location (Advanced settings -> Plug-in Trace Log) that `vela-debug-plugin` step 2 specifies - actor lapse, non-blocking |

## Planted-violation results
Not applicable - the scenario has no "Planted-violation check" section.

## Findings against the skills
1. minor - `skills/vela-debug-plugin/SKILL.md` never mentions the target solution, while the Build
   Report's apply command needs `--solution`. The actor left `solution: <uniquename>` and
   `--solution <uniquename>` in `docs/vela-builds/account-description-filter-fix.md` (L15, L102) although the
   human answer (`ZavaSales`) was available on request. Suggest: step 1 / the report step should ask for
   (or record as an assumption) the target solution unique name when the fix will be deployed.
2. minor - `skills/vela-debug-plugin/SKILL.md` step 2 says to "say exactly what to paste" (where + fields)
   when asking for the Plug-in Trace Log, but does not cover the case where the local repro already proves
   the cause and the trace log is only an optional confirmation. The actor's optional ask ("confirm with the
   Plug-in Trace Log (tracing on) that ... writes no row") omitted the location. Suggest: any mention of the
   trace log, optional or not, carries the where/what block.

No blocker findings.

## Verdict
**pass** - checks 10/10 and every scenario criterion met; RED independently reproduced by the grader.
Next run must re-check: RED exit code captured (not piped through `tail`), and the solution unique name
resolved rather than left as a placeholder.
