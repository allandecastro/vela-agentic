---
scenario: debug-filter-miss
date: 2026-10-13
verdict: pass
campaign: 2026-10-13
run: 2/3
checks: pass
grader: pass
model: claude-opus-5-5
vela_cli: 0.25.0
framework: 0.34.0
runner: "campaign actor + separate grader"
---

## Check summary
`checks.json`: **14/14 passed**, `pass: true`. No failed checks. Notable: step registered as
Update/account/PreOperation/Sync with filter `['description']`; exactly 1 authored step; tests re-run green
(total=5, failed=0); repro uses `PluginPipeline`; read-only `vela plan` runs with no demo operation.

## Loop outcome
- `vela version` → `vela 0.25.0` (Build Report run trace #1).
- Baseline build + Mono xunit `-parallel none`: 1/1 green (the shipped `Execute` test, which ignores `FilterOn`).
- RED commit `a9f6ca8` (tests + Canvas only, no `src/` change): `Total: 5, Errors: 0, Failed: 4` (`logs/test-red.log:32`).
- Fix commit `8ea7b97`: one line, `.FilterOn(e => e.Name)` → `.FilterOn(e => e.Description)` (only diff under `src/`).
- GREEN: `Total: 5, Errors: 0, Failed: 0` (`logs/test-green.log:7`); build 0 warnings / 0 errors.
- Review: isolated `vela-reviewer` subagent, PASS, 0 Critical / 0 Required / 3 Nits (`logs/review-output.md`).
- `vela solution show DescNorm` exit 4 (guessed name) → `vela solution show ZavaSales` exit 0, prefix `zava`.
- `vela inspect` (dev org) exit 0; `vela plan --solution ZavaSales` exit 8 (create package + create step, filter
  `description`, diagnostics `[]`). No `vela apply`. Build Report `status: awaiting-apply`.

## Criteria
| Criterion | Met? | Evidence |
| --- | --- | --- |
| Reproduce first: harness test updating only `description`, expects normalised value, RED for the right reason | met | `AccountNormalizeDescriptionFilterTests.cs:24-37` (PluginPipeline, Description-only update, expects "Hello world"); `logs/test-red.log:13` `Assert.Single() Failure: The collection was empty` = step never fired (filter excludes description); commit `a9f6ca8` precedes fix `8ea7b97` and touches no `src/` |
| Hypothesis from the registration, checked against `dataverse-gotchas.md`; no trial-and-error, no org mutation | met | Build Report `## A - Approach` lines 53-55 cites `RegisterPluginSteps()` and the gotcha "Create/Update step never triggers on the change you expect" (`skills/*/references/dataverse-gotchas.md:28`); single fix commit; only read-only CLI commands in run trace |
| Fix the single cause; red → green; nothing else changes | met | `git diff f55bec9..HEAD -- src` = one line (`AccountNormalizeDescription.cs:16`); green 5/5; check "exactly 1 authored step(s)" |
| Customer org unreachable: `vela inspect`/`vela logs` recorded as confirming commands; trace-log request says where/what | met | Build Report lines 141-160: customer-org `vela plan`/`vela inspect --solution` commands, `vela logs --type ... --message Update --entity account --since 7d --full --json`, Trace Log location (Power Apps → Advanced settings → Settings → Plug-in Trace Log, logging setting) and fields to paste |
| SC1 Failing repro written and seen RED before any code change | met | commit order + `logs/test-red.log` (Failed: 4) |
| SC2 One-line fix; repro and existing suite green | met | diff above; `logs/test-green.log:7` Total 5 Failed 0; checks "tests re-run green" |
| SC3 Explanation names the gotcha and evidence; no "it seems" | met | Build Report `## A`, `## What was built`, `## Evidence` (test output, inspect stepKey/filter, plan output); no hedged claims |
| SC4 Trace-log ask says where and which fields; no reading the org around the CLI | met | Build Report lines 153-160; all org access via `vela solution show` / `inspect` / `plan` |

## Planted-violation results
The scenario has no "Planted-violation check" section; none applied.

## Findings against the skills
1. minor - `skills/vela-apply/SKILL.md:56` says "**Confirm the target solution (read-only):** `vela solution show
   <uniquename> --json <connection>`" but does not say where `<uniquename>` comes from (the Canvas / the human).
   The actor guessed `DescNorm` (the repo name), got exit 4 on `solution show` and on `plan`, and only then asked
   the coordinator (run trace #3, #10). Harmless here, but the step should say: take the solution from the
   Canvas, or ask the human; never infer it from the repo/solution-file name.

(Per the evaluator note, no Create-filter report is counted; the actor made none.)

## Fixes
- none yet

## Verdict
pass - checks 14/14 and every criterion met with artifact evidence. Next run re-checks that the solution
uniquename is asked for (or taken from the Canvas) rather than guessed.
