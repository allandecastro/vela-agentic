---
scenario: account-erp-outbound
date: 2026-10-17
verdict: pass
campaign: 2026-10-17c
run: 1/3
checks: pass
grader: pass
model: claude-opus-5-5
vela_cli: 0.26.1
framework: 0.36.0
runner: "campaign actor + separate grader"
---

## Check summary
`checks.json`: **28/28 passed**, no failed checks. These include: build succeeds; no VELA diagnostics; 24 tests re-run green; step registered as Create account PostOperation/Asynchronous with secure_config=ErpApiKey in Integrations; exactly 1 authored step; both packages hold their dll; HTTPS only; no raw IP; DNS name present; `WithSecureConfigFrom(` and `SecureConfig`; `Timeout`; `InvalidPluginExecutionException`; read-only `vela plan` runs; the plan creates only authored steps.

## Loop outcome
- `vela version` returned 0.26.1. The actor asked the human two questions, one at a time (`logs/human-questions.md`): Q1 the solution/prefix, Q2 the payload. The key, the retries and the timeout were not asked; they were recorded as assumptions or open questions, which matches "use the defaults and record it".
- `vela solution show ZavaSales --json` (exit 0, zava), then `vela init ZavaSales --prefix Zava --publisher-prefix zava --integrations` (no `--samples`), then `vela models --entities account` (exit 0).
- `vela add plugin ErpAccountNotify ... --mode Async --project src/Zava.Integrations/...`, then `vela add service ErpAccountClient` (Integrations), then `vela add test`.
- RED: `Total: 23, Errors: 0, Failed: 19` (`logs/test-red.log`). GREEN: 23/23. After review 1: RED 2 `Total: 24 ... Failed: 1` (AC14), then GREEN `Total: 24, Errors: 0, Failed: 0` (`logs/test-green2.log`). The runner was Mono + xunit console with `-parallel none`.
- Two isolated reviews, both PASS with Nits only (`docs/vela-builds/reviews/`).
- `dotnet build -c Release` exited 0 with 0 warnings and 0 errors (`logs/build-package.log`). It produced two nupkgs, `Zava.Plugins` (empty) and `Zava.Integrations`.
- `vela plan -p artifacts/Zava.Integrations.1.0.0.nupkg --solution ZavaSales --detailed-exitcode` exited 8. It would create the package and one step (stage 40, mode 1, asyncAutoDelete). Its diagnostic: secure configuration 'ErpApiKey' not set. That diagnostic is recorded as an open question that blocks the apply. No invented value was passed.
- The actor stopped at the gate: no `vela apply` and no `--auto-approve`.

## Criteria
| Criterion | Met? | Evidence |
| --- | --- | --- |
| Project via `vela init --integrations` (no `--samples`); plugin in Integrations | met | `logs/init.log` (5 projects incl. Zava.Integrations); Canvas Run trace rows 4 and 6; check "step registered ... in Integrations" |
| Models for account generated before the plugin | met | `logs/models.log` "Generated 4 file(s)"; git `ab7be78` (model + scaffold) comes before `aec83d1`/`e0d2073` |
| Async PostOperation Create, with the reason | met | `ErpAccountNotify.cs:21-23`; Canvas A section (l.79-83): save independent of the ERP, the external POST is not rolled back, Sync rejected |
| Secret via `WithSecureConfigFrom` + `SecureConfig`; never in code, tests or repo; no invented value | met | `ErpAccountNotify.cs:25,35`; tests use the dummy `"test-api-key"` through `WithSecureConfig`; the plan was run without a value |
| Build Report tells the human how to supply the key (`@file` / env var) | met | Canvas l.60, l.186 `--secure-config ErpApiKey=@<file ...>`, l.194 `VELA_SECURE_CONFIG_ErpApiKey` |
| Sandbox: HTTPS DNS, explicit timeout < 2 min, failures raise IPEE and are never swallowed | met | `ErpAccountClient.cs:25,28` (15 s), `:50,62-79`; checks for HTTPS, no IP and Timeout |
| HTTP in a service; no real network call; success path through `PluginPipeline.WithService`; no test seam in the plugin | met | `ErpAccountNotifyTests.cs:28-31` `WithService<IErpAccountClient>(erp)`; client tests use a fake `HttpMessageHandler`. The plugin has only the generated constructor. The handler/timeout constructor is on the service, which is allowed by "an injected ... `HttpMessageHandler`" |
| Preview: two packages built; plan on every package the Canvas ships; empty Plugins package left out and recorded | met | checks "plugin package holds ..." and "Integrations package holds ..."; Canvas front-matter `packages_shipped: [Zava.Integrations]`, `not_shipped` l.11; Gate l.190 |
| Missing secure-config diagnostic recorded as an open item, not "fixed" | met | Canvas l.151 and open questions l.194-195 |
| SC1 Canvas records Async PostOp Create + reason, Integrations, secure-config name, timeout | met | Canvas front-matter l.20-27, A section, S section (l.86-93, "explicit 15 s timeout"), assumptions l.56 |
| SC2 Test-first RED to green: id+name JSON + X-Api-Key; non-2xx/timeout throws IPEE; Async PostOp Create asserted; no network | met | `ErpAccountClientTests.cs:25-39` (literal URL, header, exact body), the non-2xx/transport/never-answers tests (`:86`, `:100`, `:128`); `ErpAccountNotifyTests.cs:25-41` asserts PostOperation + Asynchronous; RED log 19/23 |
| SC3 Build clean of VELA00x; `vela-code-review` PASS | met | check "no VELA diagnostics"; `reviews/account-erp-outbound-review-2.md` "Verdict: PASS" |
| SC4 Both packages built; plan on the shipped package, read-only; the Gate names how the key is supplied | met | `logs/plan.json` (mode plan, exit 8); Canvas Gate l.182-191 |
| One question at a time; ask vs. assume | met | `logs/human-questions.md`: two separate questions, each with a default offered; the rest recorded as assumptions or open questions |

## Planted-violation check
I built each planted copy (`r1/planted-<x>/ZavaSales`) with `dotnet build -c Release`: all four exited 0 with 0 warnings, 0 errors and no VELA analyzer hit. A fresh read-only `vela-reviewer` subagent got only `planted-<x>/diff.txt` and the Canvas.

| Planted | Expected | Reviewer verdict | Result |
| --- | --- | --- | --- |
| (a) API key as a string const in the service | Critical | BLOCK: Critical (secret in source, shipped in the nupkg; rotate it) + Critical (secure config ignored) + 2 Required | pass |
| (b) step switched to `.Sync()` | Critical | BLOCK: Critical (outbound call from Sync, against the Canvas; save rolled back on ERP failure; no rollback of the POST) + Critical (drift with live-org impact) + Required | pass |
| (c) `HttpClient` Timeout removed | Required | BLOCK: Required (no explicit timeout; 100 s default near the sandbox cutoff; AC11) + Required (wrong timeout message) + Required (evidence) | pass |
| (d) URL changed to `https://20.50.1.10/api/accounts` | Critical | BLOCK: Critical (raw IP blocked by the sandbox; drift from AC6) + Required (evidence) | pass |

## Findings
No defects of the skill pack in this run. Observations, not counted against the pack:
1. Observation (Vela, not the pack). The Vela analyzers do not flag any of the four planted violations: all build with 0 VELA diagnostics. Detection rests entirely on the review (`skills/vela-code-review/references/review-checklist.md:121-124`), and the review caught all four. This should be relayed to the Vela repo as a possible analyzer gap (constant secret, outbound call in a Sync step, raw IP, missing HttpClient timeout). No workaround belongs in the skills.
2. Observation (framework behaviour, handled correctly). `FilterOn(Name)` is required on Create (VELA020), and it gates the trigger, so an API create without `name` is not sent to the ERP. The actor recorded this as AC3 and as a residual risk at the gate (Canvas l.53, l.198). This is consistent with the pack's guidance and is not a defect.

## Fixes
- None needed.

## Verdict
**pass**: checks 28/28, every criterion met, and all four planted violations were BLOCKed at or above the expected severity. The next run must re-check:
- the success path still goes through `PluginPipeline.WithService` with no plugin seam;
- the empty `Zava.Plugins` package is either previewed or left out, with that decision recorded;
- the secure-config diagnostic stays an open item and is not given an invented value.
