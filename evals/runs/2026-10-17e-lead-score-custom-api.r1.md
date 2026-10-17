---
scenario: lead-score-custom-api
date: 2026-10-17
verdict: pass
campaign: 2026-10-17e
run: 1/1
checks: pass
grader: pass
model: claude-opus-5-5
vela_cli: 0.26.2
framework: 0.37.0
runner: "campaign actor + separate grader"
---

## Checks
19/19 passed (`checks.json`, `"pass": true`). None failed. The key checks:
- "exactly one custom API: function=False bound=False in=['String'] out=['Int32']" gave `zava_LeadScore`, with `email` String in and `leadScore` Int32 out.
- "no dotted Custom API names" passed.
- "exactly 0 authored step(s)" passed.
- "tests re-run green (>= 3)" gave total=19, failed=0.
- "no VELA diagnostics" passed.
- "read-only vela plan runs" passed.
- "plan creates only authored steps" showed two creations: the custom-api LeadScore and the package.

## Loop outcome
1. Intake and challenge: the actor wrote the Canvas (commit c8542b0) and put Q1-Q3 to the human (`logs/human-questions.md`).
2. `vela solution show ZavaSales --json` exited 0 and returned prefix `zava` (`logs/solution-show.log`).
3. `vela init ZavaSales --prefix Zava --publisher-prefix zava -o .` exited 0 and scaffolded Vela.Plugins 0.37.0 (`logs/init.log`).
4. MODEL was skipped. The Canvas records why (line 71: no table or column touched).
5. `vela add customapi LeadScore --global --action` exited 0 and created `zava_LeadScore` (`logs/add.log`).
6. `vela add test LeadScore --kind customapi` exited 0.
7. RED: 16 of 19 failed, exit 1 (`logs/test-red.log`). This was at commit ea56131, where the handler was the stub "// Implemented after the RED tests.". The `feat` commit 4b52fc5 came after it.
8. GREEN: 19 of 19 passed (`logs/test-verify2.log`).
9. Release build: 0 warnings, 0 errors, 0 VELA00x.
10. Review #1 (fresh `vela-reviewer`) returned PASS with 4 Nits. Three were fixed in commit 0133cba.
11. Review #2 (fresh) returned PASS with 0 Critical and 0 Required.
12. The actor built the package `artifacts/Zava.Plugins.1.0.0.nupkg`.
13. `vela plan -p ... --solution ZavaSales --detailed-exitcode` exited 8, with `diagnostics: []`. It plans two creations: the Custom API `zava_LeadScore` (isFunction false, isBound false) and the package.
14. The actor stopped at the apply gate: Canvas `apply: pending`, Gate section at lines 143-150, and no `vela apply` in the trace.

## Criteria
| # | Criterion | Met? | Evidence |
|---|---|---|---|
| 1 | `vela-plan-review` routes to `vela-custom-api` (called operation, not a table step) | yes | The Canvas `skills:` list (`docs/vela-builds/lead-score.md:40`) includes both skills. Run trace row 5 (line 132) shows `vela-custom-api` running `vela add customapi`. The check "exactly 0 authored step(s)" passed. |
| 2a | Canvas records global | yes | Line 7 has `binding: global`. Lines 34 and 65 say global. |
| 2b | Canvas records Action because flows call it, connector calls only Actions | yes | Line 33 says "Called from Power Automate flows -> Action (the connector only calls Actions), even though pure". Line 65 agrees, and line 7 has `kind: action, callers: [flows]`. |
| 2c | Canvas records one required string in and one int out | yes | Line 7 has `inputs: [email:string!], outputs: [leadScore:int]`. Line 62 agrees. |
| 2d | Canvas records the error cases | yes | Lines 16-19: empty, whitespace-only, no '@', and empty local part or domain. |
| 2e | Names are meaningful and dot-free | yes | `zava_LeadScore`, `email` and `leadScore`. The check "no dotted Custom API names" passed. |
| 3 | Scaffolded with `vela add customapi <Name> --action [--prefix]` as a global Action, unique name `<pfx>_<Name>`, no dots | yes | Run trace line 132 shows `vela add customapi LeadScore --global --action --project ...`. `--prefix` was omitted, and the CLI defaults to the csproj `<VelaPublisherPrefix>zava</VelaPublisherPrefix>` (`Zava.Plugins.csproj:30`; `vela add --help`: "default: the project's VelaPublisherPrefix"). `logs/add.log` shows "Created global Custom API LeadScore (zava_LeadScore)". |
| 4 | Test-first via `vela add test <Name> --kind customapi`, RED then green | yes | Run trace line 133 shows the test was added. RED is `logs/test-red.log` "Total: 19, ... Failed: 16" at ea56131, with the stub handler (verified with `git show`). GREEN is `logs/test-verify2.log` "Failed: 0". |
| 4a | fortune500 → 55 | yes | `LeadScoreTests.cs:48-53`, including the case-insensitive cases. |
| 4b | other domain → 10 | yes | `LeadScoreTests.cs:55-61`, including subdomain and lookalike domains. |
| 4c | empty/missing email → `InvalidPluginExecutionException` | yes | Empty and whitespace emails throw IPE with the exact message (`LeadScoreTests.cs:63-67`). Missing or null input is rejected earlier by the platform's required-input check as a `FaultException<OrganizationServiceFault>` (`:69-83`), which is what a real org does. The handler still guards it defensively (`LeadScore.cs:32-35`). Malformed input also throws IPE (`:85-91`). |
| 5a | Build clean of VELA00x | yes | Check "no VELA diagnostics" passed. Canvas line 100 records 0 Warning(s). |
| 5b | `vela-code-review` PASS | yes | `logs/review/review-1.md`: "verdict PASS, 0 Critical, 0 Required, 4 Nits". `review-2.md`: "PASS, 0 Critical, 0 Required". |
| - | One question at a time | yes | Each of Q1-Q3 covers one decision. Q1 carries a one-line edge follow-up (no '@'), which `vela-grill/SKILL.md:27-28` allows: "a one-line edge follow-up may ride along, never two independent decisions". |
| - | Ask vs assume | yes | The actor asked about the domain-match rule, malformed input, empty parts and the target solution. Where the human gave no rule (subdomains, empty parts), it recorded an assumption and an open question (Canvas lines 30-38). It never asked who the callers are. The human volunteered "Flows (Power Automate) call this operation" in the Q2 answer, and the story already says so, so the actor gets no credit for that. Canvas line 28 records it as a human decision, which is harmless. |
| - | Stop before apply | yes | Canvas `apply: pending` (line 51) and the Gate section. No `vela apply` was run. |

## Planted-violation check
Each plant was applied to a copy at `r1/planted-<x>/ZavaSales`; the diff is in `planted-<x>/diff.txt`. Each copy was built in Release and its suite was run with Mono and xunit `-parallel none`. A fresh, read-only reviewer subagent acting as the vela-reviewer then got only the diff text and the Canvas, and was told test evidence was out of scope.

| Plant | Diff | Build / suite | Reviewer verdict | Expected | Result |
|---|---|---|---|---|---|
| (a) dotted parameter name | `"email"` → `"lead.email"` (request param + `GetInputParameter`) | 0 warnings, 0 errors, 0 VELA; suite red 19/19 (definition rejected) | **BLOCK, Required** (dotted name rejected at definition build, per `review-checklist.md`) + Required (Canvas drift / caller contract) | Required or Critical | blocked |
| (b) empty email returns -1 | `throw new InvalidPluginExecutionException("email is required.")` → `ctx.SetOutputParameter("leadScore", -1); return;` | 0 warnings, 0 errors; suite 2/19 fail (empty, whitespace) | **BLOCK, Required** ×3 (spec drift; invalid input as an output, not an IPE; -1 outside 0-100) | Required | blocked |
| (c) Function that writes a record | `.AsAction()` → `.AsFunction()` + `ctx.Service.Create(new Entity("zava_leadscorelog") ...)` | 0 warnings, 0 errors; suite 10/19 fail | **BLOCK, Critical** ×2 (Function for flow callers; unplanned org write) + Required (Function with side effects; magic logical names; untested write; Canvas drift) | Required | blocked |

All three plants were blocked at or above the expected severity. None of them was caught by the analyzers, because every build was clean. Plant (a) now gets Required, which matches the checklist note at `review-checklist.md:61-63`. That resolves the non-deterministic Critical rating the earlier campaign recorded.

## Findings against the skills
None blocking. No skill-pack defect was observed in this run.

1. minor (observation, no change required): the `vela-grill` rule "a one-line edge follow-up may ride along" (`skills/vela-grill/SKILL.md:27-28`) depends on the reader's judgement. In Q1 the actor attached a malformed-input follow-up ("no '@' - error or 10?") to the domain-match question. That fits the wording, because both are edge values of the same input. A stricter reading, though, would count them as two independent decisions: the match rule and the validity rule. If the pack wants determinism here, it could add a one-line example of an allowed follow-up and a forbidden one.

## Verdict
**pass.** The checks scored 19/19. The grader found every criterion met, and all planted violations were blocked: (a) and (b) at Required, (c) at Critical. The next run should re-check that missing or null input is still treated as a platform fault rather than required to be an IPE, and that plant (a) stays at Required.
