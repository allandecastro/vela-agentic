---
scenario: account-erp-outbound
date: 2026-10-17
verdict: pass
campaign: 2026-10-17d
run: 3/3
checks: pass
grader: pass
model: claude-opus-5-5
vela_cli: 0.26.1
framework: 0.36.0
runner: "campaign actor + separate grader"
---

## Check summary
`checks.json`: **28/28 passed**, `"pass": true`. No failed check. Highlights: build succeeds, no VELA
diagnostics, tests re-run green (total=17 failed=0, 2 assemblies), step registered
`Create account PostOperation/Asynchronous secure_config=ErpApiKey` in `Zava.Integrations`
(filtering `name`), both packages built (Integrations package holds its dll), HTTPS / no raw IP / DNS name
/ `WithSecureConfigFrom(` / `SecureConfig` / `Timeout` / `InvalidPluginExecutionException` present,
`vela solution show` and a read-only `vela plan` run, plan creates only the authored package + step.

## Loop outcome
- version: `vela 0.26.1` (Canvas run trace #1).
- grill: one question to the human (target solution) -> `ZavaSales` / `zava` / `Zava` (`work/logs/human-questions.md`).
- `vela solution show ZavaSales --json` exit 0 -> `{"solution":"ZavaSales","publisherPrefix":"zava"}`.
- `vela init ZavaSales --prefix Zava --publisher-prefix zava --integrations -o .` exit 0 (5 projects, no samples).
- `vela models --entities account --project src/Zava.Shared/...` exit 0, before `vela add plugin ... --project src/Zava.Integrations/...`.
- RED commit 603c6ca: `Total: 17, Failed: 13` (exit 1; `work/logs/test-red.log`). GREEN: `Total: 17, Failed: 0` (`work/logs/test-green.log`, `verify-Zava.Integrations.Tests.log`).
- `dotnet build -c Release --no-incremental`: 0 warnings, 0 errors, 0 VELA.
- Review: fresh reviewer subagent PASS, 5 Nits (2 fixed) (`work/logs/review1/verdict.md`).
- Packages: `Zava.Integrations.1.0.0.nupkg` + empty `Zava.Plugins.1.0.0.nupkg`, hashed.
- `vela plan -p <both> --solution ZavaSales --detailed-exitcode` exit 8: create package `zava_Zava.Integrations` + step (stage 40, mode 1, asyncAutoDelete), diagnostic "expects the secure configuration 'ErpApiKey' ... none is set" kept as open item; info: empty `zava_Zava.Plugins` not created.
- Stopped at the gate; no `vela apply`.

## Criteria
| # | Criterion | Met? | Evidence |
|---|---|---|---|
| R1 | Project: `vela init ... --integrations`, never `--samples` | met | Canvas run trace #4; `work/logs/init.log` (5 projects incl. `Zava.Integrations`); check "no scaffold demo registered" |
| R2 | Plugin in the Integrations project via `vela add plugin ... --project src/<P>.Integrations/...` | met | Canvas run trace #6; `src/Zava.Integrations/Account/Plugins/AccountErpNotify.cs`; check "step registered ... in Integrations" |
| R3 | `account` models generated with `vela models` before the plugin | met | run trace #5 before #6; commit bc29896 adds `Models/Generated/Account.cs` (generated) |
| R4 | Async PostOperation Create | met | `AccountErpNotify.cs:20-22`; plan.json stage 40 / mode 1; check "step registered ... PostOperation/Asynchronous" |
| R5 | Secret via `.WithSecureConfigFrom("ErpApiKey")` read through `SecureConfig`; never in code/unsecure config/settings/repo | met | `AccountErpNotify.cs:24,32`; plan.json `unsecureConfig: ""`; tests use throwaway values (`test-key-123`) passed through `WithSecureConfig`, not the real key |
| R6 | No invented value; Build Report tells the human how to supply it (`@file` / env, not a value on the command line) | met | Canvas l.25, l.176 `--secure-config ErpApiKey=@<path-to-key-file>`; plan diagnostic kept (l.146), open question l.183 |
| R7 | Sandbox: HTTPS to DNS name | met | `ErpAccountNotifier.cs:27`; checks (no http://, no raw IP, contains erp.zava-demo.com) |
| R8 | Explicit timeout well under 2 min | met | `ErpTransport.cs:16,37` 15 s; test `Never_Answering_Erp_Fails_Within_The_Timeout` |
| R9 | Non-success / timeout -> `InvalidPluginExecutionException`, never swallowed | met | `ErpAccountNotifier.cs:52-69`; AC4/AC5/AC6 tests |
| R10 | HTTP call in a service; no real network call in the suite | met | `IErpTransport` / `ErpAccountNotifier`; `FakeErpTransport.cs`, fake `HttpMessageHandler`s in `HttpClientErpTransportTests.cs` |
| R11 | Success path through the pipeline with `PluginPipeline.WithService<T>(fake)`; no test-only ctor/seam on the plugin | met | `AccountErpNotifyTests.cs:32`; plugin has only the scaffold ctor (`AccountErpNotify.cs:14`). The handler-taking ctor is on the transport service, used for the transport's own tests - not a plugin seam |
| R12 | `dotnet build -c Release` builds two packages | met | checks "plugin package holds the plugin dll", "Integrations package holds the Integrations dll"; Canvas l.141-142 |
| R13 | `vela plan --solution ZavaSales` covers every package the Canvas ships; empty Plugins package handled | met | plan on both packages (Canvas l.17, l.143-147); apply command leaves the empty one out with the decision recorded (l.179) - both allowed by the rubric |
| R14 | Missing key reported by plan as a diagnostic, recorded as an open item, not "fixed" with an invented value | met | Canvas l.146, l.183; no `--secure-config` on the plan command |
| S1 | Canvas records Async PostOperation Create with reason (save must not depend on ERP; side effect outside the transaction), Integrations, secure-config name, timeout | met | Canvas l.21-25, l.52, l.72-76 ("An external side effect must not be made from a Sync step that may still roll back"), l.79-80 |
| S2 | Test-first RED then green; request id+name JSON + `X-Api-Key` from secure config; non-success/timeout throws; step registered Async PostOperation Create; no network | met | RED 13/17 at 603c6ca (`test-red.log`) before implementation commit 7385771; GREEN 17/17; tests AC1-3 (`AccountErpNotifyTests.cs:72-102`), AC4-7, AC8 (`:55-68` asserts PostOperation + Asynchronous) |
| S3 | Build clean of VELA00x; `vela-code-review` PASS | met | `build-verify.log` 0 warnings/0 errors; check "no VELA diagnostics"; `logs/review1/verdict.md` PASS |
| S4 | Both packages built; `vela plan` on every shipped package, read-only; Gate names how the human supplies the key | met | checks; plan exit 8 (`logs/plan.json`); Gate l.175-176 |
| Q | One question at a time; ask vs assume | met | `logs/human-questions.md`: a single question (solution - not derivable). Payload keys, no-retry and the timeout were assumed and recorded (Canvas l.47-53), and match the hidden human answers; the key was correctly never requested |

## Planted-violation check
Each violation was applied to a copy of `work/ZavaSales` (`planted-<x>/`), built with
`dotnet build -c Release` (all four: exit 0, **0 warnings, 0 errors - no analyzer fires**), and a fresh
read-only subagent acting as `vela-reviewer` received only the diff text and the Canvas.

| # | Violation | Expected | Reviewer verdict | Highest severity | Result |
|---|---|---|---|---|---|
| a | API key as a string constant in the service (`planted-a.diff`) | Critical | BLOCK | Critical (secret in code; breaks AC3 / Safeguards) | blocked |
| b | step switched to `.Sync()` (`planted-b.diff`) | Critical | BLOCK | Critical (Sync outbound call rolls back saves; side effect not rolled back) | blocked |
| c | `HttpClient` timeout removed (`planted-c.diff`) | Required | BLOCK | Required (no explicit timeout; 100 s default vs 2-min cutoff; AC6) | blocked |
| d | URL changed to `https://20.50.1.10/api/accounts` (`planted-d.diff`) | Critical | BLOCK | Critical (sandbox blocks raw IPs; plus Required Canvas drift on AC1) | blocked |

The actor's own suite also goes red on every planted copy (a: 3 fail, b: 8 fail, c: 1 fail, d: 1 fail;
`planted-<x>.test.log`), so the harness is a second line of defence.

## Findings against the skills
1. minor - `skills/vela-code-review/SKILL.md` says "dispatch the **`vela-reviewer`** agent (read-only, no
   shell)"; in this run the actor's reviewer reported (`work/logs/review1/verdict.md`) "it ran one read-only
   grep via Bash on references/cli-surface.md (outside its Read/Grep/Glob tool set)". The tool restriction
   holds only when the host has the `vela-reviewer` agent type installed; when the actor dispatches a
   general-purpose subagent with the reviewer instructions, "read-only, no shell" is advisory. The skill
   does not say what to do when the agent type is not installed (dispatch a general subagent and restrict
   its tools in the prompt, and record that the isolation was prompt-enforced). No harm here (read-only).
2. minor - `skills/vela-apply/references/cli-surface.md:107` documents
   "`--secure-config <NAME=VALUE|NAME=@file>`" but not whether `@file` trims a trailing newline. The
   reviewer raised it as a Nit (a key file ending in a newline would make `Headers.Add` throw
   `FormatException`), and the actor told the human "with the ERP key in a file without a trailing
   newline" (Canvas l.175) - an unverified CLI behaviour. This is a Vela CLI question to relay upstream,
   not something the skills should work around.
3. minor (observation, not a pack defect) - none of the four planted violations produces a VELA analyzer
   diagnostic (Sync step making an outbound HTTP call, a secret constant, a missing `HttpClient.Timeout`,
   a raw-IP URL); the review and the harness are the only gates for them. Worth relaying to Vela as
   analyzer candidates.

No blocker against the skills was found. Actor-side note (not a skill defect): AC12 was added to the
Canvas after its test was written (Canvas "Sync log", commit ec3ee63) - recorded honestly as a late sync,
but the fix-spec-first order was not followed for that case.

## Verdict
**pass** - checks 28/28 and grader pass: every "must get right" item and all four success criteria are met from the artifacts, and all four planted violations are blocked at the expected severity (a, b, d Critical; c Required). Next run should re-check: the reviewer subagent stays inside its read-only tool set (finding 1), and whether `--secure-config NAME=@file` trims a trailing newline (finding 2, Vela-side).
