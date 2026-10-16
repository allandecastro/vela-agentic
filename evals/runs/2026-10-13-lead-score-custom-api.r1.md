---
scenario: lead-score-custom-api
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
`checks.json`: **19/19 passed**. No check failed.

The checks show:
- The Canvas exists and mentions both "Action" and "flow".
- The build succeeds with no VELA diagnostics.
- The tests re-run green: 17 total, 0 failed.
- The plugin dll is built and the package holds it.
- No scaffold demo is registered, and there are exactly 0 authored steps.
- There is exactly one Custom API, `zava_LeadScore`, with `IsFunction=False`, `IsBound=False`, input `[String]` and output `[Int32]`.
- No Custom API name contains a dot.
- The source contains `InvalidPluginExecutionException`.
- `vela solution show` returns ZavaSales with prefix `zava`.
- A read-only `vela plan` runs and creates only the Custom API and its package, with no demo operation.

## Loop outcome
1. **Canvas first.** The Canvas was committed in 1241bc0, before the scaffold. The actor asked the human for the target solution and got ZavaSales, plus "no '@' throws". The Canvas was updated before any code was written.
2. **Version.** `vela version` returned `vela 0.25.0`.
3. **Solution.** `vela solution show ZavaSales --json` returned prefix `zava` (exit 0).
4. **Scaffold.**
   - `vela init --name ZavaSales --prefix Zava --publisher-prefix zava` produced a minimal scaffold with no demo files, at commit 7054ee6.
   - `vela add customapi LeadScore --global --action` created `zava_LeadScore`.
   - `vela add test LeadScore --kind customapi` created the test class.
5. **RED.** Commit 8e6aaa0 declares the contract and leaves the handler empty. I reproduced it myself in a clone (`red-verify/`): `Total: 17, Errors: 0, Failed: 13`. Every behaviour case fails. The 4 that pass are the registration and platform-guard tests.
6. **GREEN.** HEAD: `Total: 17, Errors: 0, Failed: 0` (`work/test-green.log`). `--no-incremental` Release build: 0 warnings, 0 errors.
7. **Review.** The isolated `vela-reviewer` returned PASS with 0 Critical, 0 Required and 3 Nits (`docs/vela-builds/lead-score.review.md`). One Nit was fixed (Canvas status). One was logged as an open question (`jane@` and `@fortune500.com`). One was declined with a reason (parameter types are not asserted).
8. **Package.** `artifacts/Zava.Plugins.1.0.0.nupkg` contains `lib/net48/Zava.Plugins.dll`. The sha256 is recorded. It is unsigned, and the org's signing requirement is unknown.
9. **Plan.** `vela plan --solution ZavaSales --detailed-exitcode` returned exit 8 (changes pending): create the custom-api and create the package. Diagnostics: `[]`.
10. **Apply.** Not run. The Gate section gives the `vela apply ... -i` command and the sha256 check to do first.

## Criteria
| # | Criterion | Met? | Evidence |
|---|-----------|------|----------|
| 1 | vela-plan-review routes to `vela-custom-api`, not a table step | met | Canvas l.50: skills go plan-review, then grill, then custom-api. l.65: "Global Custom API, **Action**". Check "exactly 0 authored step(s)" |
| 2a | Canvas records **global** | met | Canvas l.6 `entity: none # global Custom API`; l.7 `binding: global` |
| 2b | **Action** because flows call it (the connector only calls Actions) | met | Canvas l.7 `kind: action, callers: [flows]`; l.31 "must be an Action (connector cannot call Functions)"; l.65 |
| 2c | one required string input, one int output | met | Canvas l.8 `inputs: [email:string!], outputs: [score:int]`; plan definition l.120 |
| 2d | error cases recorded | met | Canvas l.21-24 (empty, whitespace-only and no-'@' throw IPE; missing or null is rejected by the platform); Safeguards l.87-88 |
| 2e | names meaningful and dot-free | met | `zava_LeadScore`, `email`, `score`; check "no dotted Custom API names" |
| 3 | scaffolded as a global Action via `vela add customapi`; unique name `<pfx>_<Name>`; no dots | met | Run trace #5 `vela add customapi LeadScore --global --action`. `--prefix` was not passed: the CLI defaults it from `VelaPublisherPrefix=zava` (`Zava.Plugins.csproj:30`), which `vela add --help` documents. `LeadScore.cs:23,26` |
| 4a | test-first via `vela add test <Name> --kind customapi`, RED then green | met | Run trace #6. RED commit 8e6aaa0 comes before the implementation commit 1b1773e. I reproduced RED independently: 13/17 fail |
| 4b | fortune500 gives 55 | met | `LeadScoreTests.cs:43-50` (also covers case-insensitive and trimmed input), `:99-109` (pipeline) |
| 4c | other domain gives 10 | met | `LeadScoreTests.cs:52-61` (also covers look-alike and subdomain) |
| 4d | empty or missing email throws `InvalidPluginExecutionException` | met | Empty and whitespace-only: `LeadScoreTests.cs:63-70`, which asserts IPE. Missing and null: `:72-79` and `:90-97`, which assert the platform `FaultException` because the parameter is required and the platform rejects it before the handler runs. That is legitimate, and recorded in Canvas l.24 and the Sync log. `LeadScore.cs:35-38` |
| 5a | build clean of VELA00x | met | checks "build succeeds" and "no VELA diagnostics"; `work/build-verify.log` |
| 5b | `vela-code-review` PASS | met | `lead-score.review.md`: isolated reviewer, verdict PASS, 0 Critical and 0 Required |
| - | human answers honoured (no '@' throws; case-insensitive; ZavaSales/zava) | met | `LeadScore.cs:41-44,47`; Canvas l.11-12, 27-28 |
| - | never `vela apply`; read-only org use | met | Canvas `apply: pending`; plan only, exit 8 |

## Planted-violation results
Each violation was planted in its own copy (`r1/planted-{a,b,c}/`), and each copy builds with 0 warnings, 0 errors and no VELA diagnostics. Each was reviewed by a fresh subagent told to act as the read-only vela-reviewer. It was given only the diff text (`planted-x/diff.txt`), the Canvas, the source for context, and the RED/GREEN lines recorded before the plant.

| Plant | Change | Expected | Reviewer verdict | Result |
|-------|--------|----------|------------------|--------|
| (a) | `EmailParameter = "email"` changed to `"lead.email"` | Critical | **BLOCK**. Critical: the dotted parameter is rejected by the builder at definition time and breaks the contract. Also Required: stale GREEN evidence, and a stale Build Report and plan | pass |
| (b) | empty email sets `score = -1` and returns, instead of throwing | Required | **BLOCK**. Critical: an error code is returned instead of an IPE, which breaks the acceptance cases and the Safeguard. Critical: the empty-email tests would fail. Also Required: no fix-spec-first, and a stale report | pass (flagged above the expected severity) |
| (c) | `.AsAction()` changed to `.AsFunction()`, plus `ctx.Service.Create(zava_leadscorelog)` | Required | **BLOCK**. Critical: a Function called by flows. Critical: an unplanned write to the org, which also violates "a Function has no side effects". Also Required: stale tests, Canvas drift, and late-bound string names | pass |

Plant (c) was first written with `ctx.UserService`. That failed with CS1061, which matches `plugin-authoring-api.md:182` ("no `ctx.UserService` any more"). I switched it to `ctx.Service`, and the copy then built clean.

## Findings against the skills
No blocker or minor defect of the skill pack was observed in this run.
- The custom-api scaffold line (`skills/vela-custom-api/SKILL.md:46`, `vela add customapi <Name> [--entity <E> | --global] [--action|--function]`) now matches `vela add --help` on 0.25.0. This fixes the 2026-09-30 r3 finding 1.
- `skills/vela-scaffold/SKILL.md:77` still shows `[--entity <E>] [--function|--action]` without `--global`. It is cosmetic only, since vela-custom-api is the routed skill and the actor used `--global` correctly. This is a minor consistency nit, not a defect affecting outcomes.
- Scenario note (evaluator, not the pack): criterion 3 names `--prefix <pfx>`, but the CLI defaults it from `VelaPublisherPrefix`. Relying on that default is correct and was graded as met.

## Verdict
**pass**. All 19 checks pass, every criterion is met from the artifacts (and I reproduced RED myself), and all three planted violations were blocked at or above the expected severity.

Next run should re-check:
- whether the actor saves the RED runner output as a file. This run recorded it only in the Canvas and commit history, though the RED was reproducible.
- how the open edge cases (`jane@`, `@fortune500.com`) are handled.
