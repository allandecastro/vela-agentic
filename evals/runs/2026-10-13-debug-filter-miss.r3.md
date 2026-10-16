---
scenario: debug-filter-miss
date: 2026-10-13
verdict: pass
campaign: 2026-10-13
run: 3/3
checks: pass
grader: pass
model: claude-opus-5-5
vela_cli: 0.25.0
framework: 0.34.0
runner: "campaign actor + separate grader"
---

## Check summary
`checks.json`: **14/14 passed**, 0 failed (build, no VELA diagnostics, tests re-run green total=3, step
registered Update/account/PreOperation/Sync filter=['description'], exactly 1 authored step, repro uses
PluginPipeline, ZavaSales exists, read-only plan runs, plan has no demo operation, plan creates only authored steps).

## Loop outcome
- `vela version` -> 0.25.0 (Build Report run trace #1; the installed CLI is now 0.25.1).
- Baseline build + mono xunit `-parallel none`: Total 1, Failed 0 (the shipped `Execute` test hides the bug).
- Commit 6afd1a4: Canvas + two PluginPipeline repro tests. RED: `logs/test-red.txt` - `Total: 3, Failed: 2`
  (`Assert.Single() Failure: The collection was empty` for the description-only update; name-only update fired).
- Commit a834dab: one-line fix `FilterOn(e => e.Name)` -> `FilterOn(e => e.Description)` (1 insertion, 1 deletion).
- GREEN: `logs/test-green.txt` - `Total: 3, Errors: 0, Failed: 0`; build 0 warnings / 0 errors.
- Isolated vela-reviewer: PASS, 0 Critical/Required, 3 Nits (`docs/vela-builds/account-description-filter-fix.review.md`).
- `dotnet build -c Release` -> `artifacts/zava.Plugins.1.0.0.nupkg`; `vela solution show ZavaSales` -> prefix zava;
  `vela plan ... --solution ZavaSales --url <dev> --detailed-exitcode` -> exit 8, create package + 1 step filter `description`.
- Stopped at the apply gate; no `vela apply`, no org mutation.

## Criteria
| Criterion | Met? | Evidence |
| --- | --- | --- |
| Reproduce first: harness test updates only `description`, expects normalised value, RED for the right reason | met | `AccountNormalizeDescriptionTests.cs:22-37` (PluginPipeline, Update with Description only); `logs/test-red.txt` "Assert.Single() Failure: The collection was empty" = the step did not fire; committed in 6afd1a4 before fix a834dab |
| Hypothesis from the registration, checked against dataverse-gotchas; no trial-and-error, no org mutation | met | Build Report `## A - Approach` (l.55-59) cites the registration and the gotcha "Create/Update step never triggers on the change you expect" (`dataverse-gotchas.md:28`); only read-only `solution show` / `plan` used |
| Fix the single cause, red -> green, nothing else changes | met | `git show a834dab`: 1 file, 1+/1- at `AccountNormalizeDescription.cs:16`; `logs/test-green.txt` 3/3; check "exactly 1 authored step(s)"; TODO / step description deliberately left as follow-ups |
| Customer org unreachable: `vela inspect` / `vela logs` recorded as confirming commands; trace-log request says where and what | met | Build Report Gate l.141-151: `vela inspect -p ... --solution ZavaSales --url <customer-org>` (flags verified against `vela inspect --help`) with expected `name` filter, then `vela plan`; trace log path (Power Apps -> Advanced settings -> Plug-in Trace Log / PRT, enable logging) and fields to paste |
| SC1 Failing repro written and seen RED before any code change | met | commit order 6afd1a4 (tests) -> a834dab (fix); `logs/test-red.txt` |
| SC2 One-line fix; repro and existing suite green | met | a834dab 1+/1-; `logs/test-green.txt` Total 3, Failed 0 (incl. existing `Handler_normalises_description`); checks "tests re-run green" |
| SC3 Explanation names the gotcha and the evidence; no "it seems" | met | Build Report `## What was built` + `## Evidence` quote RED/GREEN output, plan output, solution show; no hedging language |
| SC4 Trace-log request says where and which fields; no reading the org around the CLI | met | Gate l.147-151; only `vela` commands touched the org |

## Planted-violation results
The scenario has no "Planted-violation check" section; none applied.

## Findings against the skills
1. minor - `skills/vela-apply/SKILL.md` (gate: the apply reuses the plan's connection) combined with
   `skills/vela-debug-plugin/SKILL.md` (no rule for "the bug is in an org you cannot reach; preview on a proxy org").
   The Build Report Gate (l.138) offers `vela apply -p ... --solution ZavaSales --url https://dyn-premium-dev.crm.dynamics.com`
   as "the previewed target", although the dev org is the read-only proxy where the plugin was never deployed, and the
   fix belongs in the customer org. The actor did add the correct customer-org inspect -> plan -> apply sequence below it,
   but the first apply command a human sees deploys to the wrong environment. The debug skill should say: when the
   failing org is unreachable, the gate's apply targets that org (after its own plan), and a proxy-org plan is evidence
   only, not an apply target.
2. minor - `skills/vela-debug-plugin/SKILL.md` gives no step for the target solution when the debug project does not
   name one; the actor guessed `vela solution show DescNorm` (exit 4) and a plan without `--solution` (exit 4) before
   asking. Read-only and harmless, but two wasted org calls; the skill could tell the agent to ask for (or read from the
   project) the solution before the first `solution show`.

Not counted (per evaluator notes): none applicable - the actor did not report a Create-filter Vela gap.

## Verdict
pass - checks 14/14 and every criterion met with artifact evidence. Next run re-checks that the gate's apply command
targets the org that has the bug when a proxy org was used for the preview.
