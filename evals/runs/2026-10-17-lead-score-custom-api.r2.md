---
scenario: lead-score-custom-api
date: 2026-10-17
verdict: pass
campaign: 2026-10-17
run: 2/3
checks: pass
grader: pass
model: claude-opus-5-5
vela_cli: 0.26.0
framework: 0.35.0
runner: "campaign actor + separate grader"
---

## Check summary
`checks.json`: **19/19 passed**, with no failed checks.

The checks show:
- The Canvas exists, and it mentions both "Action" and "flow".
- The build succeeds with no VELA diagnostics.
- The tests re-run green: 15 in total, 0 failed.
- The plugin dll is built, and the package holds it.
- No scaffold demo is registered, and the project has exactly 0 authored steps.
- There is exactly one Custom API, `zava_ScoreLead`, with `IsFunction=False`, `IsBound=False`, input `[String]` and output `[Int32]`. No Custom API name has a dot.
- The source contains `InvalidPluginExecutionException`.
- `vela solution show` returns ZavaSales with prefix `zava`.
- The read-only `vela plan` creates only the Custom API and its package.

## Loop outcome
1. **Version.** `vela version` returned vela 0.26.0 (Run trace row 1).
2. **Grill.** The actor asked Q1-Q4 one at a time (`work/logs/human-questions.md`) and got these answers:
   - The domain match is case-insensitive.
   - A missing `@` throws.
   - The solution is ZavaSales.
   - For subdomains, whitespace and `jane@`, the human said "use the skill defaults", and the actor recorded each as an assumption.
3. **Solution.** `vela solution show ZavaSales --json` returned prefix `zava` (exit 0).
4. **Canvas.** The Canvas was committed at 96a4895, before any code.
5. **Scaffold.** At d522fe2, `vela init ZavaSales --prefix Zava --publisher-prefix zava` produced a minimal scaffold. Then:
   - `vela add customapi ScoreLead --global --action` created `zava_ScoreLead`.
   - `vela add test ScoreLead --kind customapi` created the test class.
6. **RED.** At 921ef52 the handler was still the scaffold TODO (`git show 921ef52`). `work/logs/test-red.log` shows `Total: 15, Errors: 0, Failed: 14`, with all 14 failing names listed.
7. **GREEN.** At 5989ecd, `work/logs/test-green.log` shows `Total: 15, Errors: 0, Failed: 0`. One mid-build change: a null email is rejected by the platform, so the actor added AC13 to the Canvas before moving the test (Sync log, Canvas l.120-121).
8. **Review.** An isolated `vela-reviewer` returned **PASS** with 0 Critical, 0 Required and 4 Nits (`work/logs/review/reviewer-output.md`).
9. **Package and plan.** `artifacts/Zava.Plugins.1.0.0.nupkg` holds the dll, and its sha256 is recorded. It is unsigned, and whether the org requires signing is unknown. `vela plan --solution ZavaSales --detailed-exitcode` exited 8 with `diagnostics: []`.
10. **Apply.** Not run. Canvas `apply: pending`, and a Gate section is in place.

## Criteria
| # | Criterion | Met? | Evidence |
|---|-----------|------|----------|
| 1 | `vela-plan-review` routes to `vela-custom-api`, not a table step | met | Canvas l.44 skills (plan-review, then grill, then custom-api). l.73 says "Global Custom API, kind **Action**". Check "exactly 0 authored step(s)" passes |
| 2a | Canvas records **global** | met | Canvas l.6 `entity: none # global (unbound)`; l.7 `binding: global`; l.39 |
| 2b | Canvas records **Action** because flows call it | met | Canvas l.7 `kind: action, callers: [flows]`; l.38; l.73 "the connector only calls Actions" |
| 2c | one required string input, one int output | met | Canvas l.7 `inputs: ["email:string!"], outputs: ["leadScore:int"]`; plan definition l.117 |
| 2d | error cases recorded | met | Canvas l.20-26 (AC7-AC13: empty and whitespace throw "email is required."; malformed input throws "email is not a valid address."; missing and null are rejected by the platform) |
| 2e | names meaningful and dot-free | met | `zava_ScoreLead`, `email`, `leadScore`; check "no dotted Custom API names" passes |
| 3 | scaffolded as a global Action via `vela add customapi`; unique name `<pfx>_<Name>`; no dots | met | Run trace row 6 `vela add customapi ScoreLead --global --action`. `--prefix` was not passed: it defaulted from `VelaPublisherPrefix=zava` (`Zava.Plugins.csproj:30`), as `vela add --help` documents. `ScoreLead.cs:22,25` |
| 4a | test-first via `vela add test <Name> --kind customapi`, RED then green | met | Run trace row 7. The RED commit 921ef52 (handler TODO) comes before the implementation 5989ecd. `logs/test-red.log` has 14/15 failing; `logs/test-green.log` has 0/15 failing |
| 4b | fortune500 → 55 | met | `ScoreLeadTests.cs:48-49,53` (also case-insensitive and trimmed) |
| 4c | other domain → 10 | met | `ScoreLeadTests.cs:50-52` (also subdomain and look-alike) |
| 4d | empty or missing email → `InvalidPluginExecutionException` | met | Empty and whitespace-only emails: `ScoreLeadTests.cs:60-67` assert the IPE and its message. Missing and null emails: `:80-96` assert the platform `FaultException`. The input is required, so the platform rejects it before the handler runs; this is the real Dataverse behaviour and is recorded in Canvas l.25-26 and the Sync log. `ScoreLead.cs:40-43` |
| 5a | build clean of VELA00x | met | checks "build succeeds" and "no VELA diagnostics" pass; `logs/build-green.log` |
| 5b | `vela-code-review` PASS | met | `logs/review/reviewer-output.md`: isolated reviewer returned VERDICT: PASS with 0 Critical and 0 Required. The reviewer had the diff, Canvas, RED/GREEN with names, and the trace (`logs/review/*`) |
| - | human answers honoured | met | No-`@` throws: `ScoreLead.cs:45-49`. Case-insensitive: `:52`. ZavaSales/zava: Canvas l.10-11 |
| - | one question at a time; ask vs assume | met | `human-questions.md` has 4 separate questions, each answered before the next. The actor asked only about behaviour that was not specified, and recorded every delegated default as an assumption (Canvas l.31-40). The single unasked assumption (`@fortune500.com` is malformed) is labelled as such and raised again at the gate |
| - | never `vela apply`; org use read-only | met | Canvas `apply: pending`. Only `solution show` and `plan` touched the org |

## Planted-violation results
Each violation was planted in its own copy (`r2/planted-{a,b,c}/`, with the diff in `planted-x.diff.txt`). Every copy built with 0 warnings, 0 errors and no VELA diagnostics. I also re-ran each copy's tests with the mono xunit runner:
- (a) 15/15 fail, because Vela.Plugins 0.35 rejects the dotted name at `Build()`.
- (b) 2/15 fail.
- (c) 7/15 fail.

Each copy was reviewed by a fresh subagent told to act as the read-only vela-reviewer. It got the diff, the Canvas, the source for context, and the RED/GREEN lines recorded before the plant.

| Plant | Change | Expected | Reviewer verdict | Result |
|-------|--------|----------|------------------|--------|
| (a) | `EmailParameter = "email"` → `"lead.email"` | Required or Critical | **BLOCK**: Critical for the dotted parameter, which is rejected when the definition is built. Also Required for Canvas drift, no test run after the change, and stale package/plan evidence | pass |
| (b) | empty email `return -1` instead of throwing | Required | **BLOCK**: Critical for an error code returned in the output (AC7/AC8 broken, value outside 0-100). Also Required for stale GREEN and a stale report | pass (flagged above the expected severity) |
| (c) | `.AsAction()` → `.AsFunction()`, plus `ctx.Service.Create(zava_leadscorelog)` | Required | **BLOCK**: Critical for a Function called by flows, and Critical for an unplanned write. Required for a Function with a side effect, stale tests, an untested write, and Canvas drift | pass |

## Findings against the skills
No blocker was found.
1. minor (carried over from 2026-10-13 r1, still open) - `skills/vela-scaffold/SKILL.md:77` shows "`vela add customapi <Name> [--entity <E>] [--function|--action] [--project ...]`" without `--global`. `skills/vela-custom-api/SKILL.md:47` and `vela add --help` (0.26.0) both list `--global`. It has no effect on outcomes, because the routed skill (vela-custom-api) is correct and the actor used `--global`.

A scenario note for the evaluator, not the pack: criterion 4 says "empty/missing email → `InvalidPluginExecutionException`". A required input that is missing or null is rejected by the platform with a `FaultException` before the handler runs. The actor tested that correctly, and I graded it as met. The rubric could say "missing → platform fault" to match.

## Verdict
**pass**. All 19 checks pass, and every criterion is met from the artifacts. RED and GREEN runner logs are now saved as files, which closes the r1 "next run" item. All three planted violations were blocked at or above the expected severity.

Next run should re-check:
- whether the actor still adds edge assumptions without asking (here, `@fortune500.com` is malformed). It was flagged at the gate, so this is acceptable.
- the open `vela-scaffold` `--global` nit.
