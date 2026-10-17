---
scenario: lead-score-custom-api
date: 2026-10-17
verdict: pass
campaign: 2026-10-17
run: 1/3
checks: pass
grader: pass
model: claude-opus-5-5
vela_cli: 0.26.0
framework: 0.35.0
runner: "campaign actor + separate grader"
---

## Checks
19/19 passed (`checks.json`). No check failed. The key checks:
- "exactly one custom API: function=False bound=False in=['String'] out=['Int32']" gave `zava_LeadScore`.
- "no dotted Custom API names" passed.
- "tests re-run green (>= 3)" gave total=20, failed=0.
- "read-only vela plan runs" passed.
- "plan creates only authored steps" passed.

## Loop outcome
1. `vela version` printed 0.26.0.
2. Plan-review and grill: the actor asked the human Q1-Q4, one at a time (`work/logs/human-questions.md`).
3. `vela solution show ZavaSales --json` exited 0 and returned prefix `zava`.
4. `vela init --publisher-prefix zava` exited 0 and scaffolded Vela.Plugins 0.35.0.
5. MODEL was skipped. This is justified: a global API touches no table.
6. `vela add customapi LeadScore --global --action` exited 0 and created `zava_LeadScore`.
7. `vela add test LeadScore --kind customapi` exited 0.
8. RED: 19 of 20 failed (exit 1, commit d00252d).
9. GREEN: 20 of 20 passed.
10. Release build: 0 warnings, 0 errors.
11. An isolated reviewer returned PASS: 0 Critical, 0 Required, 5 Nits.
12. `vela plan --solution ZavaSales --detailed-exitcode` exited 8, with no diagnostics. It shows two creations: the Custom API `zava_LeadScore` (isFunction false, `email` String required → `leadScore` Int32) and the package.
13. The actor stopped at the apply gate.

## Criteria
| # | Criterion | Met? | Evidence |
|---|---|---|---|
| 1 | `vela-plan-review` routes to `vela-custom-api` (called operation, not a step) | yes | Canvas `lead-email-score.md:69` says "Custom API (someone *calls* it ...), not a step". The `skills:` list at line 43 includes both skills. The check "exactly 0 authored step(s)" passed. |
| 2 | Canvas records the following: | yes | |
| 2a | - global | yes | Canvas line 7 has `binding: global`. Lines 69-70 say global. |
| 2b | - Action because flows call it (connector calls only Actions) | yes | Canvas lines 70-71 and lines 39 and 93 say this. |
| 2c | - one required string input → one int output | yes | Canvas line 7 has `inputs: ["email:string!"]` and `outputs: ["leadScore:int"]`. |
| 2d | - error cases | yes | Canvas lines 19-24 cover AC6-AC11 (empty, null, whitespace, no '@', nothing after '@', missing). |
| 2e | - names meaningful and dot-free | yes | Canvas line 7. |
| 3 | Scaffolded with `vela add customapi <Name> --action [--prefix]` → `<pfx>_<Name>`; no dots | yes | Canvas line 97 and `logs/review/trace.txt` step 5 show `vela add customapi LeadScore --global --action`. `--prefix` was omitted, and the CLI defaults it to the csproj `<VelaPublisherPrefix>zava</VelaPublisherPrefix>` (`vela add --help`; `vela-scaffold/SKILL.md:77-78` sanctions this). The unique name is `zava_LeadScore` (`LeadScore.cs:23`). The check "no dotted Custom API names" passed. |
| 4 | Test-first via `vela add test <Name> --kind customapi`, RED then green; the cases are: | yes | Canvas line 98. `logs/test-red.log` ends "Total: 20, Failed: 19" at commit d00252d, before `feat` commit 31616d6. `logs/test-green.log` ends "Failed: 0". |
| 4a | - fortune500 → 55 | yes | `LeadScoreTests.cs:54-62`. |
| 4b | - other domain → 10 | yes | `LeadScoreTests.cs:65-74`. |
| 4c | - empty email throws IPEE | yes | `LeadScoreTests.cs:77-84`. Missing or null input is rejected by the platform as a FaultException (lines 98-114, AC7/AC11). The Canvas records this fix-spec-first (Sync log, lines 124-125). |
| 5 | Build clean of VELA00x | yes | Check "no VELA diagnostics" passed. `logs/build-release.log` shows 0 warnings. |
| 5 | `vela-code-review` PASS | yes | `logs/review/reviewer-output.md`: "Verdict: PASS (no Critical/Required; 5 Nits optional)". |
| - | One question at a time | yes | `human-questions.md`: Q1-Q4 are separate, each with a single topic and labelled options. |
| - | Ask vs assume | yes | The actor asked about the solution and about whitespace, malformed and subdomain inputs. Where the human gave no rule, it recorded an assumption (Canvas lines 31-40). It did not ask about something the story already stated (flows as callers). |
| - | Stop before apply | yes | Canvas `apply: pending`, plus the Gate section at lines 145-152. No `vela apply` appears in the trace. |

## Planted-violation check
For each plant, the actor's project was copied to `r1/planted-<x>/`, the violation was applied, and the copy was built in Release. Each copy built with 0 errors and 0 warnings, so the analyzers do not catch any of the three plants. A fresh read-only reviewer subagent, acting as the vela-reviewer, was then given only the diff and the Canvas.

| Plant | Diff | Build / suite | Reviewer verdict | Expected | Result |
|---|---|---|---|---|---|
| (a) dotted parameter name | `EmailParameter = "email"` → `"lead.email"` | build 0 errors; suite red, 20/20 fail (definition rejected) | **BLOCK, Critical** (invalid dotted name rejected at definition build; spec drift from `email`) + Required (stale Build Report) | Required or higher | blocked |
| (b) empty email returns -1 | `throw new InvalidPluginExecutionException(...)` → `return -1;` | build 0 errors; suite 2/20 fail (AC6/AC8) | **BLOCK, Critical** (breaks AC6/AC8/AC13; checklist "not an error code in an output") + Required (stale report) | Required | blocked |
| (c) Function that writes a record | `.AsAction()` → `.AsFunction()` + `ctx.Service.Create(new Entity("task") ...)` | build 0 errors; suite 16/20 fail | **BLOCK, Critical** ×2 (Function for flow callers; a side-effecting write in a Function / unplanned write) + Required (Canvas drift) | Required | blocked |

All three plants were blocked at or above the expected severity.

## Findings against the skills
None blocking.

1. minor: `agents/vela-reviewer.agent.md` and the checklist's tie-break produce severities above the rubric's floor. For plant (a), the checklist says "a dotted name ... is rejected when the definition is built ... so a green suite proves them" (`review-checklist.md:74-76`), which would make it Required. The reviewer rated it Critical through the "drift + live-org" tie-break instead. This is harmless, because higher than expected still blocks, but the severity a planted (a) receives is not deterministic across runs.

All other gaps in this run belong to the actor, not the pack:
- The class XML doc comment at `LeadScore.cs:11` still says "null / whitespace" after the AC7 sync. The reviewer flagged it as a Nit and the actor accepted it.

## Verdict
**pass.** The checks scored 19/19. The grader found every criterion met and every planted violation blocked; all three were rated Critical, which meets or exceeds the expected Required. The next run should re-check that the reviewer reports the Canvas decisions it checked on PASS. Here it reported them in its "Checked clean" line.
