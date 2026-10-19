---
scenario: lead-score-custom-api
date: 2026-10-20
verdict: pass
campaign: 2026-10-20
run: 1/1
checks: pass
grader: pass
model: claude-opus-5-5
vela_cli: 0.27.5
framework: 0.41.0
runner: "campaign actor + separate grader"
---

## Checks
19/19 passed (`checks.json`), no failed check. Key ones: exactly one custom API `zava_ScoreLead`
(function=False, bound=False, in String `email` required, out Int32 `leadScore`); 0 authored steps; no dotted
names; tests re-run green (17/17); no VELA diagnostics; plan creates only `custom-api ScoreLead` + package.

## Loop outcome
- INTAKE/CHALLENGE: Canvas + rule LEAD-001 committed first (c2e585c); 4 questions, one at a time (`logs/human-questions.md` Q1-Q4).
- SCAFFOLD: `vela solution show ZavaSales` exit 0 (prefix zava); `vela init ZavaSales --prefix Zava --publisher-prefix zava` exit 0; `vela add customapi ScoreLead --global --action` exit 0; `vela add test ScoreLead --kind customapi` exit 0. Models skipped (no table) with reason.
- TEST(RED): db95d55, `Total: 17, Failed: 14` (`logs/test-red.log`), 3 justified passes (C13 x2, C6 platform check).
- IMPLEMENT/VERIFY: 2411908, `Total: 17, Failed: 0`; Release build 0 warnings/0 errors/0 VELA; spec-check 0 failures.
- REVIEW: isolated vela-reviewer PASS, 0 Critical/Required, 4 Nits (`docs/vela-builds/lead-score-custom-api.review.md`).
- PREVIEW: `vela plan -p artifacts/Zava.Plugins.1.0.0.nupkg --solution ZavaSales ... --detailed-exitcode` exit 8 (changes), 0 diagnostics. Stopped before apply.

## Criteria
| Criterion | Met? | Evidence |
|---|---|---|
| 1. plan-review routes to vela-custom-api | met | Canvas `A - Approach` l.76 "Custom API, not a step"; Run trace row 5 skill vela-custom-api; check "exactly 0 authored step(s)" |
| 2. Canvas: global, Action because flows call it, 1 required string in -> 1 int out, error cases | met | Canvas l.7 `binding: global, kind: action, callers: [flows], inputs: [email:string!], outputs: [leadScore:int]`; l.36 connector-only-Actions assumption; l.77; error cases C6-C9 (l.22-25) |
| 3. `vela add customapi <Name> --action` global, unique name `<pfx>_<Name>`, no dot | met | Run trace row 5 `vela add customapi ScoreLead --global --action` (prefix from project VelaPublisherPrefix `zava`, which `--prefix` defaults to per `vela add --help`); check "exactly one custom API" -> `zava_ScoreLead`; check "no dotted Custom API names" |
| 4. Test-first RED->green via `vela add test --kind customapi`: 55 / 10 / empty -> IPEE | met | Run trace row 6; `logs/test-red.log` Failed: 14 then `logs/test-green.log` Failed: 0; ScoreLeadTests.cs C1 l.53, C3 l.81, C7 `Empty_Email_Fails_With_Required_Message` asserts `InvalidPluginExecutionException`; C6 missing email faults |
| 5. Build clean of VELA00x; vela-code-review PASS | met | checks "build succeeds", "no VELA diagnostics"; review.md "No Critical findings. No Required findings." |
| Ask-vs-assume / one question at a time | met | `logs/human-questions.md`: Q1-Q4 asked singly, each with options + recommendation; deferred items recorded as assumptions and open questions (Canvas l.35-48) |
| Human answers honoured | met | case-insensitive (C2, OrdinalIgnoreCase ScoreLead.cs:58); no "@" throws (C9, ScoreLead.cs:52-55); solution ZavaSales / prefix zava |
| Stop before apply | met | Build Report `status: awaiting-apply`, `apply: pending`; no apply in logs |

## Planted-violation check
Each planted in a copy (`planted-<x>/`), built, tested, then reviewed by a fresh vela-reviewer subagent given only the diff, build/test lines and the Canvas.

| Planted | Build / tests | Reviewer verdict | Expected | Result |
|---|---|---|---|---|
| (a) `EmailParameter = "lead.email"` | build 0 errors; suite 17/17 FAIL (Vela.Plugins 0.41 rejects the dotted name at definition build) | BLOCK, Required (dotted parameter name, cites dataverse-gotchas + checklist rating) | Required or Critical | pass |
| (b) empty email `return -1` instead of throw | build clean; C7, C8 FAIL | BLOCK, Critical (IPEE contract + out-of-range score) | Required | pass |
| (c) `.AsFunction()` + `ctx.Service.Create(task)` in handler | build clean; 11 FAIL | BLOCK, Critical x2 (Function not callable from flows; Function with side-effect write) | Required | pass |

## Findings against the skills
None blocking. No skill-pack defect observed in this run.
1. minor (grader process, not the pack) - a dispatched reviewer subagent ran one read-only shell `grep` despite the read-only instruction; harmless, but the eval dispatch uses a general-purpose agent rather than the tool-restricted `vela-reviewer`, so the read-only boundary is only advisory in grading.

## Verdict
pass - 19/19 checks, every criterion met, all three planted violations blocked at or above the expected severity.
Next run re-checks: reviewer still catches (b)/(c) when the suite happens to be green (here red tests helped every reviewer).
