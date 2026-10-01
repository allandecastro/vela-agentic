---
scenario: debug-filter-miss
date: 2026-10-02
verdict: pass
campaign: 2026-10-02
run: 3/3
checks: pass
grader: pass
model: claude-opus-5-5
vela_cli: 0.21.4
framework: 0.29.11
runner: "campaign actor + separate grader"
---

## Check summary
checks.json: 10/10 passed, 0 failed (build ok, no VELA diagnostics, tests re-run green total=3 failed=0,
step registered Update account PreOperation/Synchronous filter=['description'], exactly 1 authored step,
repro uses PluginPipeline).

## Loop outcome
- `vela version` -> `vela 0.21.4` (exit 0); branch `fix/account-description-filter` off `main` 0aefad2.
- Baseline suite green 1/1 (shipped `Execute` test ignores `FilterOn`).
- Commits: 6ec3f22 Canvas -> 2c10ab3 RED repro tests -> 15fdfc3 one-line fix -> 4d2d711 / dd37f61 docs.
- RED: mono xunit.console 2.9.2 `-parallel none`, exit 1, `Total: 3, Errors: 0, Failed: 2` (evidence/red.txt).
  Grader re-ran it independently on a clone at 2c10ab3: same 2 FAIL, `Total: 3, Failed: 2`.
- GREEN: `Total: 3, Errors: 0, Failed: 0` (evidence/green.txt); Release build 0 warnings / 0 errors.
- Isolated vela-reviewer: PASS, 0 Critical / 0 Required / 7 Nits (docs/vela-builds/account-description-filter-fix.review.md).
- Package built via `dotnet build -c Release`; `vela plan` skipped - no org, exact command recorded; no `vela apply`.

## Criteria
| # | Criterion | Met? | Evidence |
|---|-----------|------|----------|
| M1 | Reproduce first: harness test updating only `description`, RED for the right reason | met | AccountNormalizeDescriptionTests.cs `Description_only_update_fires_and_saves_normalised_description` (PluginPipeline, update with only Description); red.txt `Assert.Single() Failure: The collection was empty` (step never fired = filter excludes description); commit 2c10ab3 precedes fix 15fdfc3; grader reproduced RED |
| M2 | Hypothesis from the registration, checked against dataverse-gotchas; no trial-and-error, no org mutation | met | Build Report "What was built"/Approach: `FilterOn(e => e.Name)` vs handler on Description; "Dataverse only fires an Update step when a filtering attribute is in the request" (= gotchas line 27); single fix commit; no apply/org call |
| M3 | Fix the single cause, red goes green, nothing else changes; `vela inspect` recorded | met | evidence/diff.txt: only `.FilterOn(e => e.Name)` -> `.FilterOn(e => e.Description)` in src; checks "exactly 1 authored step", filter=['description']; Build Report records `vela inspect -p artifacts/zava.Plugins.1.0.0.nupkg --interactive --json` |
| S1 | Failing repro written and seen RED before any code change | met | git order 2c10ab3 (tests) -> 15fdfc3 (fix); red.txt Failed: 2; grader re-run at 2c10ab3 |
| S2 | One-line fix; repro and existing suite green | met | diff.txt 1 line in src; green.txt Total 3 Failed 0; checks "tests re-run green (>= 2)" |
| S3 | Explanation names the gotcha and the evidence; no "it seems" without output | met | Build Report Approach + Evidence section quote runner lines; no "seems/probably" (grep); "should" only in expected post-apply outcomes |
| S4 | Trace-log ask says where + which fields; no reading the org around the CLI | met | Canvas open_questions: Power Apps -> Advanced settings -> Settings -> Plug-in Trace Log, enable via System Settings -> Customization, fields listed (type name, message, entity, stage/mode, depth, correlation id, exception, message block); no org access in logs |

## Planted-violation results
Not applicable: the scenario has no "Planted-violation check" section.

## Findings against the skills
None. (Actor-side observations, not skill defects: Canvas front-matter `reuse: add-step:...` is an odd
label for a fix of an existing step; the second acceptance case "name-only update does not fire" is an
extra behavioural assertion consistent with the scenario's expected fix.)

## Verdict
pass - checks 10/10 and every criterion met with artifact evidence; RED independently reproduced. Next run
re-checks that the repro still uses PluginPipeline and that the fix stays a single line.
