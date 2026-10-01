---
scenario: debug-filter-miss
date: 2026-10-02
verdict: pass
campaign: 2026-10-02
run: 2/3
checks: pass
grader: pass
model: claude-opus-5-5
vela_cli: 0.21.4
framework: 0.29.11
runner: "campaign actor + separate grader"
---

## Check summary
checks.json: **10/10 passed**, `pass: true`. No failed checks. Among them: build ok, no VELA diagnostics,
tests re-run green (total=3 failed=0), exactly 1 authored step, step registered
`Update account PreOperation/Synchronous filter=['description']`, and the tests contain `PluginPipeline`.

## Loop outcome
- `vela version` gave vela 0.21.4 (Canvas Run trace row 1).
- Baseline Mono xunit `-parallel none`: 1/1 green. The shipped Execute test ignores FilterOn.
- 0b81a5b (tests only): RED with `Total: 3, Failed: 2`. The grader **reproduced this independently** by
  cloning, checking out 0b81a5b, building and running xunit.console:
  - `Editing_only_the_description_fires_the_step...` failed with `Assert.Single() Failure: The collection was empty`.
  - `Editing_only_the_name_does_not_fire_the_step` also failed.
- a33c9f1: a one-line fix, `FilterOn(e => e.Name)` became `FilterOn(e => e.Description)`. GREEN with 3/3.
- `dotnet build -c Release --no-incremental`: 0 warnings, 0 errors.
- The isolated vela-reviewer returned PASS with 0 Critical and 0 Required. It raised 4 Nits, all handled.
- Package built with sha256 recorded. `vela plan`: skipped, no org, with the exact command recorded.
- `vela apply` was never run.

## Criteria
| Criterion | Met? | Evidence |
|---|---|---|
| Reproduce first: a harness test updating only `description` expects the normalised value and fails RED for the right reason | met | `git show 0b81a5b` holds the tests only and leaves the src untouched. The repro uses `PluginPipeline` and `p.Service.Update(new Account{Id, Description=...})`. It fails with "collection was empty", which means the step never fired. Grader re-ran it and got the same result. |
| Hypothesis from the registration, checked against the gotcha; no trial-and-error; no org mutation | met | Canvas `docs/vela-builds/account-description-filter-fix.md` L50-54 and L71-74 name the root cause: the filtering attribute is `Name` while the handler reads `Description`, and Execute ignores FilterOn. There is a single fix commit and no other edits. No org was touched. |
| Fix the single cause; red goes green; nothing else changes | met | The a33c9f1 diff is 1 line. `git diff 2625460 HEAD --stat` shows the src change, the tests and the docs, nothing more. checks.json: filter=['description'], 1 step, 3/3 green. |
| No org: `vela inspect` recorded as the confirming command | met | Canvas L28 (open_questions) and L103 (Gate step 2) give the exact `vela inspect -p ... --connection-string ... --out inspect.json`. |
| SC1: failing repro written and seen RED before any code change | met | Commit order is 0b81a5b (tests) then a33c9f1 (fix). Canvas L80 records the RED evidence, and the grader re-ran it. |
| SC2: one-line fix; repro + existing suite green | met | a33c9f1 diff. checks.json "tests re-run green (>= 2)" gives total=3, failed=0. |
| SC3: explanation names the gotcha and the evidence; no hedging without output | met | Canvas L71-80 names the filtering-attribute gotcha and cites the runner summary lines for RED and GREEN. No "it seems" wording. |
| SC4: trace log request says where + which fields; no reading the org around the CLI | met | Canvas L104-107 gives where (Advanced settings, Plug-in Trace Log), how to enable it, and the fields to paste: type name, message, entity, stage/mode, depth, correlation id, exception, and message block. No Web API calls were made. |

## Planted-violation results
The scenario has no "Planted-violation check" section. Not applicable.

## Findings against the skills
None blocking. Observations only:
1. minor (actor slip, not a pack defect) - `skills/vela-apply/SKILL.md` L62-63 says "No org available → record
   `skipped - no org` and the exact command". The actor still ran `vela plan -p ... --out plan.json` with no
   connection. It exited 2 ("Missing Dataverse auth"), contacted nothing and left the package hash unchanged.
   The skill text is clear, so no skill change is needed.
2. minor (observation) - The fix replaces the `Name` filter rather than adding `Description` to it. The pack
   handled this correctly: the decision is recorded as `by: agent` (Canvas L21) and raised as an open question.
   This matches the human answer ("exactly what the plugin already does, only when Description is edited").

## Verdict
**pass**. All 10 checks passed, every criterion is met, and the RED repro was independently reproduced by
the grader. Next run must re-check that the repro goes through `PluginPipeline` (not `Execute`) and that
`vela inspect` plus the Trace Log request with where and which fields are recorded when there is no org.
