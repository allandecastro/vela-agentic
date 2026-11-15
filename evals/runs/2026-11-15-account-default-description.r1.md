---
scenario: account-default-description
date: 2026-11-15
verdict: pass
campaign: 2026-11-15
run: 1/1
checks: pass
grader: pass
model: claude-opus-5-5
vela_cli: 0.29.0
framework: 0.42.0
runner: "campaign actor + separate grader"
---

## Check summary
19/19 deterministic checks passed (`checks.json`, `"pass": true`). No failed checks.

## Loop outcome
- intake: `vela version` -> 0.29.0, exit 0 (trace row 1)
- challenge: vela-plan-review then vela-grill, 2 questions asked one at a time (`logs/human-questions.md` Q1 empty-meaning, Q2 target solution), both answered
- scaffold: `vela solution show ZavaSales --json` exit 0; `vela init ... --solution ZavaSales` exit 0 (minimal); `vela models --entities account` exit 0; `vela add plugin AccountPlugin ... --handler OnDescriptionDefault` exit 0; `vela add test AccountPlugin` (inside the scaffold's tests project) exit 0
- RED: Mono xunit.console `-parallel none`, exit 1, Total 7 / Failed 4 (C1 x2, C2, C3; Expected "Created via Vela plugin", Actual null) - `logs/test-red.log`, commit a5e6a47 precedes implementation commit ee4746f
- GREEN: same runner, exit 0, Total 7 / Failed 0 - `logs/test-green.log`
- verify: `dotnet build -c Release` 0 Warning(s) 0 Error(s); spec-check 0 failure(s)
- review: isolated vela-reviewer PASS, 0 Critical / 0 Required, 4 Nits (`.vela-runs/.../review.md`)
- preview: package `artifacts/zava_Zava.Plugins.1.0.0.nupkg`; `vela plan --solution ZavaSales --detailed-exitcode` exit 8 (changes: create package + create step); stopped before apply

## Criteria
| # | Criterion | Met? | Evidence |
|---|---|---|---|
| 1 | `vela init` + `vela add plugin` exit 0 per vela-scaffold; tests in the scaffold's `.Tests` project | met | trace.md rows 5, 7, 8 (exit 0); commit 245131c has `tests/Zava.Plugins.Tests/Zava.Plugins.Tests.csproj`; `vela add test` only added a file into that project (as `skills/vela-test-harness/SKILL.md:50` directs), no new test project |
| 2 | Real authoring surface (`EntityPluginBase`, Target), no magic strings where a model exists | met | `AccountPlugin.cs`: `EntityPluginBase<Account>`, `RegisterStep().OnCreate()...Handle(OnDescriptionDefault)`, `ctx.Request.Target`, typed `target.Description`, `FilterOn(e => e.Name)`; behaviour-named handler replaces `OnExecute` per CLI 0.29 |
| 3 | Test-first: RED seen, then GREEN, OS-correct runner, real harness API | met | `logs/test-red.log` "Total: 7, Errors: 0, Failed: 4"; `logs/test-green.log` "Failed: 0"; Mono + `-parallel none` (trace rows 10, 12); `PluginPipeline` used; git order a5e6a47 (tests) -> ee4746f (impl) |
| 4 | `dotnet build` green, no VELA00x | met | `logs/build-release.log` 0 Warning(s) 0 Error(s); checks "build succeeds", "no VELA diagnostics" |
| 5 | null/whitespace -> defaulted; non-empty -> untouched | met | tests C1 (not sent + null), C2 (""), C3 ("   "), C4 ("  Key account " kept exactly, step asserted to have run); checks "tests re-run green (>= 3)" total=7 failed=0 |
| 6 | PreOperation, sets on `ctx.Request.Target`, no `Service.Update` | met | `AccountPlugin.cs` `.PreOperation()`, `target.Description = DefaultDescription`; check "step registered: Create 'account' PreOperation/Synchronous filter=includes ['name']"; check "src must not contain Service.(Update|Create)" ok |
| 7 | Canvas with acceptance cases + Build Report (harness pass + analyzers clean + cases checklist) | met | `docs/features/account-default-description/README.md`: front-matter `acceptance_cases` C1-C5, `harness: pass`, `analyzers: clean`, Evidence section with [x] checklist, Gate section; check "canvas exists", "canvas mentions 'PreOperation'" |
| - | "What the skills must get right": filtering-attributes gotcha | met | `FilterOn(e => e.Name)` on Create, residual risk recorded in Canvas assumptions and rules registry |
| - | "What the skills must get right": model-before-implement | met | `vela models --entities account` (trace row 6) before `vela add plugin`; generated `Account.cs`, no hand-written stand-in |
| - | Ask-vs-assume / one question at a time | met | `logs/human-questions.md`: Q1 and Q2 separate, each with options/recommendation; both match the evaluator answers; other choices recorded as assumptions |
| - | Stop before apply | met | Build Report `apply: pending`, no apply in trace; plan exit 8 recorded |

## Planted-violation results
The scenario has no "Planted-violation check" section - nothing to plant.

## Findings against the skills
1. minor - the `vela add test` template (Vela CLI, not the pack) seeds a read-back helper with `new Microsoft.Xrm.Sdk.Query.ColumnSet(true)`; the actor copied it into `Saved(...)` and the reviewer raised it as a Nit against VELA013 intent. A CLI template matter to relay to the Vela repo, not a pack defect; no pack change.
2. minor - criterion 1 wording in `evals/scenarios/account-default-description.md` ("`vela add test` only when none exists") reads as if `vela add test` were wrong when a `.Tests` project exists, while `skills/vela-test-harness/SKILL.md:50` says "Run `vela add test <Name> ...` **inside the test project**". The actor followed the skill and the result is correct; the rubric line should say "no new test project" to avoid grader ambiguity.

No blocker findings.

## Verdict
pass - 19/19 checks, every criterion met, no planted violations defined. Next run re-checks: RED before implementation on the Mono runner, FilterOn(Name) on Create, and PreOperation Target edit with no write-back.
