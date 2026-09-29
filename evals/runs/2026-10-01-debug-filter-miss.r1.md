---
scenario: debug-filter-miss
date: 2026-10-01
verdict: pass
campaign: 2026-10-01
run: 1/3
checks: pass
grader: pass
model: claude-opus-5-5
vela_cli: 0.21.0
framework: 0.29.11
runner: "campaign actor + separate grader"
---

## Check summary
`checks.json`: **10/10 passed**, no failed checks. The step is registered as Update account PreOperation/Synchronous
with filter `['description']`. There is exactly 1 authored step. The tests re-run green (3/3), and the tests
contain `PluginPipeline`.

## Loop outcome
- `vela version` returned 0.21.0 (Build Report run trace #1).
- The baseline build exited 0. The repro commit `c4736dc` added 2 `PluginPipeline` tests. RED: mono xunit.console `-parallel none`
  exited 1 with `Failed: 2` (`evidence/red.txt`).
- The fix commit `aac1901` changes one line (`FilterOn(e => e.Name)` -> `FilterOn(e => e.Description)`). GREEN: `Total: 3, Failed: 0`
  (`evidence/green.txt`).
- The Release build has 0 warnings and 0 errors. The isolated vela-reviewer returned PASS (0 Critical/Required, 3 pre-existing Nits).
- The package was built and its sha256 recorded. `vela plan` and `vela inspect` were recorded but not run (no org). The run stopped at the apply gate.

## Criteria
| # | Criterion | Met? | Evidence |
|---|---|---|---|
| M1 | Reproduce first: a harness test that updates only `description`, expects the normalised value, and fails for the right reason | met | `AccountNormalizeDescriptionTests.cs` (commit c4736dc) `Pipeline_description_only_update_fires_and_saves_normalised_value` sends only Description and expects "Hello world". RED output is `Assert.Single() Failure: The collection was empty`: the step did not fire, which is the filter cause (`evidence/red.txt`). |
| M2 | Hypothesis comes from the registration and is checked against dataverse-gotchas; no trial-and-error, no org mutation | met | Build Report `docs/vela-builds/fix-description-filter.md` L48-50 reasons from `RegisterStep()...FilterOn(e => e.Name)`. Git history is test commit -> single fix commit, with no intermediate edits. No org was touched. |
| M3 | Fix the single cause, red goes green, nothing else changes; `vela inspect` recorded | met | `git show aac1901`: 1 file, +1/-1. Branch diff vs main has only the plugin line, the tests and the Build Report. Build Report L91-92 and Gate step 5 record `vela inspect -p artifacts/zava.Plugins.1.0.0.nupkg -i`. |
| S1 | Failing repro test written and seen RED before any code change | met | Commit order c4736dc (test) -> aac1901 (fix). `evidence/red.txt` shows exit 1 before the fix. |
| S2 | One-line fix; repro and existing suite green | met | aac1901 has 1 insertion and 1 deletion. `evidence/green.txt` shows Total 3, Failed 0. checks: `tests re-run green` total=3 failed=0. |
| S3 | Explanation names the gotcha and the evidence; no "it seems" without output | met | Build Report L48-50 and L70-72 state "filtering attributes gate the trigger ... never runs the step". They cite RED/GREEN output lines (L82-85) and explain why the shipped `Execute` test missed it (L75-77). There is no hedged claim. |
| S4 | If the Trace Log is requested, it says where and which fields; the org is not read around the CLI | met (n/a) | No org, so no trace was requested. The report says that on a live org there would be "no Plug-in Trace Log row at all" (L71-72). No Web API or other org access was made. |

## Planted-violation results
The scenario has no "Planted-violation check" section, so none were run.

## Findings against the skills
None blocking. The skill pack drove this scenario correctly:
- `skills/vela-debug-plugin/SKILL.md` step 3 says to "use `PluginPipeline` - `PluginContext...Execute` runs the handler
  regardless of `FilterOn`". The actor followed it, and it is the reason the repro was RED for the right reason.
- Step 7 says "only that cause". The fix diff was one line, and the reviewer's Nits were recorded as follow-ups instead of being applied.

1. minor - The actor left the solution unique name as an open question in the Build Report
   (`solution: unknown`, L24) instead of asking the human during the run, where the answer would have been `ZavaSales`. The apply gate
   still stopped correctly, and `vela-debug-plugin` does not require the solution. This is an observation, not a clear skill defect.

## Verdict
**Pass.** checks 10/10, and every scenario criterion is met from the artifacts. The next run must re-check that the repro uses
`PluginPipeline` and is RED because the step did not fire, and that the fix diff stays at one line.
