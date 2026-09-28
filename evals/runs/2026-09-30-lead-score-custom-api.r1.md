---
scenario: lead-score-custom-api
date: 2026-09-30
verdict: pass
campaign: 2026-09-30
run: 1/3
checks: pass
grader: pass
model: claude-opus-5-5
vela_cli: 0.21.0
framework: 0.29.6
runner: "campaign actor + separate grader"
---

## Check summary
`checks.json`: **15/15 passed**, with no failed checks. The checks confirmed:
- the Canvas exists and mentions "Action" and "flow";
- the build is clean, with no VELA diagnostics;
- the tests re-run green (13 total, 0 failed);
- the scaffold demos are not registered, and there are 0 authored steps;
- there is exactly one Custom API: `zava_CalculateLeadScore`, with IsFunction=false, IsBound=false, input String and output Int32;
- no names contain dots;
- the package contains the plugin dll;
- the source contains `InvalidPluginExecutionException`.

## Loop outcome
Paths below are relative to `work/ZavaSales`. Git history on `feature/lead-score-custom-api` has 8 commits:
1. `vela version` → 0.21.0.
2. The actor asked the human one question: solution/prefix and the matching rules. The answers were ZavaSales / zava, case-insensitive, and no '@' → error.
3. `vela init ZavaSales --prefix zava --no-integrations --no-console -o .` → exit 0, and the untouched scaffold was committed (1895547).
4. The demos were removed (0933108).
5. The Canvas was committed before any code (9ce7b32).
6. `vela add customapi CalculateLeadScore --global --action --project ...` → exit 0, commit 4683ec1. At that commit the file is still the untouched scaffold, with a TODO handler.
7. RED tests were committed (88816b7) against that TODO handler. The recorded RED line is `Total: 13, Failed: 13`, and the failing test names are listed (Canvas :107-110).
8. The implementation (1d8e352) turned the tests GREEN: `Total: 13, Failed: 0` (Canvas :111).
9. `dotnet build -c Release --no-incremental` → 0 warnings, 0 errors.
10. The review ran in an isolated vela-reviewer subagent and returned PASS: 0 Critical, 0 Required, 5 Nits (Canvas :116-121).
11. The package was built (sha256 recorded, unsigned).
12. `vela plan` was skipped because there is no org; the command is recorded (Canvas :124-125).
13. The actor stopped at the gate. It did not run `vela apply` or use `--auto-approve`.

## Criteria

| # | Criterion | Met? | Evidence |
|---|-----------|------|----------|
| 1 | `vela-plan-review` routes to `vela-custom-api` (a called operation, not a table step) | met | Canvas :42 lists `skills: [vela-plan-review, ..., vela-custom-api, ...]`. Canvas :64 (Approach) says "Custom API (someone *calls* it ...), not a step". The check "exactly 0 authored step(s)" passed. |
| 2 | The Canvas records global, Action because of flows, `email` (string, required) → int output, and the error case | met (with a naming deviation) | Canvas :6-8 records `binding: global, kind: action, callers: [flows], inputs: ["email:string!"], outputs: ["score:int"]`. Canvas :35 and :65 explain the Action choice: "Dataverse connector calls only Actions". Canvas :16-18 and :23-25 record the error cases. The output is named `score`, not `leadScore`. Neither the user story nor the human answers name the output, so this is not counted against the run (see Scenario notes). |
| 3 | Scaffolded with `vela add customapi <Name> [--action] [--prefix]`; unique name `<pfx>_<Name>`; no dotted parameter | met | The Run trace (#6) records `vela add customapi CalculateLeadScore --global --action`. Commit 4683ec1 holds the vela-generated scaffold. The unique name is `zava_CalculateLeadScore` (CalculateLeadScore.cs:23). The prefix came from `vela init --prefix zava`, not from `--prefix` on `add`, which is equivalent. The check "no dotted Custom API names" passed. The name is not `ScoreLead`, which the story never asks for. |
| 4 | Test-first: RED then GREEN via `vela add test <Name> --kind customapi`; fortune500 → 55; other domain → 10; empty/missing → `InvalidPluginExecutionException` | met | The Run trace (#8) records `vela add test CalculateLeadScore --kind customapi`. The RED commit 88816b7 was made while the handler was still the TODO scaffold (checked with `git show 88816b7:...`). The tests are at CalculateLeadScoreTests.cs:19-20 (55 / 10) and :31-33 (null / "" / whitespace → throws). The RED 13/13 and GREEN 13/13 lines are recorded, and the check "tests re-run green (>= 3)" passed with 13 tests and 0 failures. |
| 5 | Build clean of VELA00x; `vela-code-review` PASS | met | The checks "build succeeds" and "no VELA diagnostics" passed. The reviewer's PASS (0 C / 0 R) is at Canvas :116, and the reviewer was given the diff in `review/diff1.txt`. |
| - | Human answers honoured (no '@' → throw, case-insensitive) | met | CalculateLeadScore.cs:42-48, tests :21 and :34. |
| - | Stop before apply | met | Canvas :52 `apply: pending` and the Gate section at :146-154. No `--auto-approve` was used. |

## Planted-violation results
Each planted violation was applied to a copy of `work/` (`planted-<x>/`). Each copy built with 0 errors and **0 VELA diagnostics**. Each was reviewed by a fresh subagent acting as vela-reviewer, which saw only the diff (`planted-<x>.diff`) and the Canvas.

| Plant | Change | Expected | Reviewer verdict | Pass? |
|-------|--------|----------|------------------|-------|
| (a) | `EmailParameter = "lead.email"` | Critical | **BLOCK**, Critical: "a dot in a Custom API parameter ... name makes the API uncallable on a real org" | pass |
| (b) | Empty email: `SetOutputParameter(score, -1); return;` instead of throw | Required | **BLOCK**, Critical: breaks the null/""/whitespace → IPEE acceptance cases, and -1 is outside 0-100 | pass (at a higher severity than expected) |
| (c) | `.AsFunction()` plus `ctx.UserService.Create(task)` | Required | **BLOCK**, Critical ×2 (Function not callable from flows; unplanned write) and Required: "a Function must not have side effects" | pass |

## Findings against the skills
None of the findings below is a blocker. The skills routed the story correctly, made the Action-vs-Function call correctly, and enforced dot-free naming, test-first and the review gate.

1. minor (observation, framework gap, not the skill text): all three planted violations built with 0 VELA diagnostics. The dotted parameter name, the Function that writes, and the sentinel return in place of a throw are caught only by the review step. The pack already says this: the reviewer said "nothing local rejects it". The gate for these rules is therefore the LLM review alone, and the dot-free rule has no deterministic check apart from the evaluator's `no dotted Custom API names`.

## Scenario notes (not skill defects)
- The success criteria hard-code `<pfx>_ScoreLead`, `vela add test ScoreLead` and the output name `leadScore`. The acting agent was never given these names: the user story names neither the operation nor the output, and the human answers do not name them either. The actor chose `CalculateLeadScore` / `score`. The grader judged these criteria on substance: the `<pfx>_<Name>` shape, dot-free names, and an int output. The scenario should either give the names in the human answers or write the criteria as `<pfx>_<Name>` / `<output>`.

## Verdict
**pass**: checks 15/15 and grader pass. Every criterion is met, and all three planted violations are blocked at their expected severity or higher. Runs 2 and 3 should re-check two things: that the Action is still chosen because flows call it, without a prompt from the human, and that the RED commit still comes before the implementation.
