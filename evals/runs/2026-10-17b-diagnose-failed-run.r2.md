---
scenario: diagnose-failed-run
date: 2026-10-17
verdict: pass
campaign: 2026-10-17b
run: 2/3
checks: pass
grader: pass
model: claude-opus-5-5
vela_cli: 0.26.1
framework: 0.36.0
runner: "campaign actor + separate grader"
---

## Loop outcome
- Meta scenario (diagnosing-vela): no org, no `vela` command expected or run by the actor.
- The actor announced "Using diagnosing-vela to analyse the run" (`work/findings.md:3`) and diagnosed against `work/pack`.
- It reconstructed the run from the Build Report's Run trace (`findings.md:8-13`). It then reproduced the gap in `work/experiment`, with the run's own source and tests on Vela.Plugins/Vela.Testing 0.36.0 and Mono xunit:
  - a hard-coded-key mutant keeps all 18 tests green (`work/logs/mutant-hardcoded-key.txt`: `Total: 18, Errors: 0, Failed: 0`);
  - a transport-only `WithService<HttpMessageHandler>` + `WithSecureConfig` wiring test fails on the mutant (`work/logs/wiring-test.txt`: `Expected: "key-from-secure-config-91a"`, `Actual: "HARDCODED-PROD-KEY-123"`).
- It wrote 5 numbered findings (4 blocker, 1 minor) and the verdict "Not ready" with ordered fixes.
- Human questions: none asked. There is no `work/logs/human-questions.md`; the only one is the original run's, under `work/run/logs/`. Nothing in the task needed the human.
- vela_cli is the diagnosed run's version: `vela 0.26.1` in `run/.../account-erp-outbound.md:153` (installed: 0.26.2). framework is the run's Build Report `framework: 0.36.0`, which matches `experiment/Exp.csproj:14`.
- Evaluator note: the run was interrupted once by an API usage limit and resumed. This is not a criterion.

## Checks
5/5 passed (`checks.json`, `"pass": true`): review-checklist, harness-api, WithService, secure-config and blocker mentions. No failed checks.

## Criteria
| Criterion | Met? | Evidence |
|---|---|---|
| diagnosing-vela followed: the run is reconstructed from the Run trace and logs | met | `findings.md:8-29` cites the Run trace sequence, commit ids, `AccountErpNotify.cs:25`, the test files and Canvas AC3. Its reviewer quotes match `run/logs/review1/review.md:5,12`. |
| Each finding: file in `pack/` + quote + what the agent did + correct path + severity | met | Findings 1-5 (`findings.md:62-182`) each have **What it says** (quote), **What happened / What the agent did**, **Correct path** and a severity. Quotes checked against the pack: `harness-api.md:197-209`, `review-checklist.md:21-25,116-118`, `vela-test-harness/SKILL.md:24-42,109-110`, `vela-plan-review/SKILL.md:46-52,87-91`, `plugin-authoring-api.md:224-228`, `vela-plugin-authoring/SKILL.md:49-50`, `vela-reviewer.agent.md:30-31`. All verbatim. |
| A verdict closes the list | met | `findings.md:189-194`: "Not ready", fixes ordered 1,2 → 4 → 3,5, a new eval proposed. |
| Cause 1: checklist Secrets item is static only, no test-proof requirement (blocker) | met | Finding 4 (blocker), `findings.md:133-157`: "the Secrets item is a static check". The fix adds a Required finding for when "replacing `SecureConfig` with a literal ... would leave every test green". |
| Cause 2: `WithService` recipe; the key captured in the `ConfigureServices` factory never reaches the fake | met | Finding 1 (blocker), `findings.md:62-94`: faking the whole service "leaves the `ConfigureServices` factory untested, and the factory is the only place configuration (`SecureConfig`) enters"; "End to end" is false. Verified by the mutant run. |
| Skill defects separated from environment issues; no finding without file + quote | met | `findings.md:184-187` "Not a finding / environment" (Mono runner, absent org, plan diagnostic). Every finding has a file and a quote. |
| Does not blame the model where the literal text allowed it | met | `findings.md:13` "No step was skipped. The defect sits in what the skills told each step to prove". Finding 1 says "the agent did exactly this". Finding 2: "the 18 tests covered every listed class". |
| Verdict: not ready + top fixes | met | `findings.md:189-194`. |
| One question at a time / ask vs assume | met (n/a) | No questions were asked. The task was fully specified; nothing behaviour-changing was assumed. |

## Planted-violation results
None. The scenario has no "Planted-violation check" section.

## Findings against the skills
None blocking, and no minor defect of the pack was exposed by this run. `diagnosing-vela` as written (announce, Run-trace-first reconstruction, file + quote + correct path + severity, environment split, verdict) produced a complete diagnosis. Both expected causes were found, plus three adjacent real gaps (test-harness Coverage, plan-review acceptance cases, plugin-authoring DI recipe) that the next iteration should check.

## Verdict
**pass.** Checks are 5/5 and every grader criterion is met. Next run: re-check that the actor quotes the pack copy verbatim with line numbers and keeps the severities (checklist Secrets = blocker).
