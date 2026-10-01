---
scenario: debug-filter-miss
date: 2026-10-02
verdict: pass
campaign: 2026-10-02
run: 1/3
checks: pass
grader: pass
model: claude-opus-5-5
vela_cli: 0.21.4
framework: 0.29.11
runner: "campaign actor + separate grader"
---

## Check summary
`checks.json`: **10/10 passed**, `pass: true`. No failed checks. Highlights: build succeeds, no VELA
diagnostics, tests re-run green (total=3 failed=0), exactly 1 authored step
`Update account PreOperation/Synchronous filter=['description']`, tests contain `PluginPipeline`
(the repro exercises the registration).

## Loop outcome
- `vela version` -> `vela 0.21.4` (Build Report run trace row 1; grader's installed `vela version` also prints `vela 0.21.4`).
- Baseline: Release build 0 warn / 0 err; shipped `Execute` test 1/1 green while the bug was live.
- RED commit `d2699c4` (tests only, 2 `PluginPipeline` tests). **Grader re-ran RED independently** (clone at
  d2699c4, `dotnet build -c Release` 0 warnings / 0 errors, mono xunit 2.9.2 `-parallel none`):
  `Total: 3, Errors: 0, Failed: 2` - `Editing_only_description_fires_step_and_saves_normalised_value`
  (`Assert.Single() Failure: The collection was empty`) and `Editing_only_name_does_not_fire_step`
  (`Assert.Empty() Failure: Collection was not empty`). Both fail for the filter reason.
- Fix commit `6808a55`: 1 line, `.FilterOn(e => e.Name)` -> `.FilterOn(e => e.Description)`. Grader re-ran at
  6808a55: `Total: 3, Errors: 0, Failed: 0`. `git diff 554bbc5 HEAD -- src tests` shows only that line + the
  test additions.
- Canvas `58612f3`, isolated reviewer PASS (0 Critical / 0 Required / 3 Nits, verbatim in
  `docs/vela-builds/account-description-filter-fix.review.md`), package rebuilt (sha256 recorded), `vela plan`
  skipped (no org) with exact command; `vela inspect` command recorded; no `apply`.

## Criteria
| # | Criterion | Met? | Evidence |
|---|-----------|------|----------|
| M1 | Reproduce first: harness test updating only `description`, expecting normalised value, RED for the right reason | met | `tests/.../AccountNormalizeDescriptionTests.cs:23-37` (`PluginPipeline`, `Update` with only `Description`, asserts single execution + `"Hello world"`); commit d2699c4 tests-only; grader-reproduced RED `Assert.Single() Failure: The collection was empty` (step did not fire) |
| M2 | Hypothesis from the registration, checked against `dataverse-gotchas.md`; no trial-and-error, no org mutation | met | Build Report `:53-57` cites `RegisterPluginSteps()` `.FilterOn(e => e.Name)` and gotcha "filtering attribute excludes the changed attribute" (matches `references/dataverse-gotchas.md:27`); git history has a single fix commit; no apply / no org access |
| M3 | Fix the single cause; red goes green; nothing else changes; `vela inspect` recorded | met | commit 6808a55 `1 insertion(+), 1 deletion(-)`; grader GREEN 3/3; checks "step registered ... filter=['description']", "exactly 1 authored step(s)"; Build Report `:105-106` `vela inspect -p artifacts/zava.Plugins.1.0.0.nupkg <connection>` |
| 1 | Failing repro test written and seen RED before any code change | met | commit order d2699c4 (tests) -> 6808a55 (fix); grader re-ran RED at d2699c4 (2 failed / 3) |
| 2 | One-line fix; repro and existing suite green | met | 6808a55 diff stat 1+/1-; checks "tests re-run green (>= 2)" total=3 failed=0; grader 3/3 at 6808a55 |
| 3 | Explanation names the gotcha and the evidence; no "it seems" without output | met | Build Report `:53-57`, `:78-82` (gotcha + why the `Execute` test hid it), Evidence `:88-93` with verbatim runner lines; no "seems/probably" in docs; the only "should" (`:106`, actor report `:29`) states the expected output of a not-yet-run command, labelled as such |
| 4 | Trace Log request says where + which fields; no reading the org around the CLI | met | Build Report `:108-115`: location (Power Apps -> Advanced settings -> Plug-in Trace Log / PRT), how to enable (System Settings -> Customization -> Exception/All), fields to paste (type name, message, primary entity, stage/mode, depth, correlation id, exception details, message block), expected result; no Web API / org reads in the work |
| - | Stop before apply | met | Build Report `status: awaiting-apply`, `apply: pending`, `plan_preview: skipped(no-org)`; Gate section `:137-142` |
| - | Quality gate (green, analyzers clean, review) | met | checks "no VELA diagnostics"; review file verdict PASS, no Critical/Required |

## Planted-violation results
The scenario has no "Planted-violation check" section - none applied.

## Findings against the skills
None. The skills (`vela-debug-plugin` evidence table incl. `vela inspect` + Plug-in Trace Log "where / enable /
paste" guidance at `skills/vela-debug-plugin/SKILL.md:25-46,70-71`; `dataverse-gotchas.md:27-29` filtering
gotcha; `PluginPipeline` honouring `FilterOn` in the harness reference) led the actor straight to the
registration-level repro, single-line fix and correct no-org recording. No rediscovery or workaround visible.

## Verdict
pass - checks 10/10 and every scenario criterion met; RED and GREEN independently reproduced by the grader.
Next run must re-check: the repro goes through `PluginPipeline` (not `Execute`), the fix stays one line, and
the trace-log request keeps where / enable / fields.
