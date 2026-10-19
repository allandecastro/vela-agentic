---
scenario: account-erp-outbound
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

## Check summary
checks.json: **29/29 passed**, no failed check.

## Loop outcome
- `vela version` -> vela 0.27.5. Three questions were asked one at a time (solution, whether the URL differs per environment, failure policy). See `work/logs/human-questions.md` Q1-Q3.
- `vela solution show ZavaSales` exited 0 (prefix zava). `vela init ... --integrations` exited 0. `vela models --entities account` exited 0. `vela add plugin/service/test` into Zava.Integrations exited 0.
- RED: 12 of 14 failed, exit 1. The 2 registration guards already passed because the registration was scaffolded. GREEN: 14 of 14, exit 0 (mono xunit `-parallel none`).
- `dotnet build -c Release` gave 0 warnings and 0 errors. spec-check gave 0 failures. The isolated vela-reviewer returned PASS with 0 Critical, 0 Required and 6 Nits.
- `vela plan` covered both packages and exited 8. It creates the package plus 1 Async step, raises an `ErpApiKey` secure-config diagnostic that is kept as an open item, and leaves the Plugins package empty and not created. The run stopped at the apply gate.

## Criteria
| Criterion | Met? | Evidence |
| --- | --- | --- |
| Project: `--integrations`, not `--samples`; plugin in Integrations; models before plugin | met | Canvas run trace rows 4-6 (`account-erp-outbound.md:141-143`). Check "step registered ... in Integrations". Check "no scaffold demo registered". |
| Async PostOperation Create, with the reason | met | `AccountErpNotify.cs:24-26`. Canvas A (`:70-71`). Check "step registered: Create 'account' PostOperation/Asynchronous". |
| Secret: `WithSecureConfigFrom` + `SecureConfig`, never in the repo, no invented value, the Report says how to supply it | met | `AccountErpNotify.cs:28,38`. Tests use the dummy value `"test-key"` through `WithSecureConfig`, not a real key. Gate `:158` gives `--secure-config ErpApiKey=@<keyfile>`, and the plan diagnostic is kept (`:126-128`). |
| Sandbox: HTTPS DNS name, explicit timeout under 2 min, failures throw IPEE | met | `ErpAccountClient.cs:34,40` (30 s). `:104-109` enforces https. `:80-97` turns a timeout, an unreachable ERP or a non-2xx answer into IPEE. Checks for the HTTPS, raw-IP, Timeout and IPEE patterns. |
| Design: HTTP in a service; no real network; success path through `PluginPipeline.WithService<T>(fake)`; no test seam in the plugin | met | `AccountErpNotifyTests.cs:125` (`WithService<IErpAccountClient>(fake)`). The client tests use a fake `HttpMessageHandler`. The handler-taking constructor sits on the service, not the plugin. |
| Preview: two packages built; plan covers the packages the Canvas ships; missing key is an open item | met | Checks "plugin package holds ..." and "Integrations package holds ...". Canvas `:54,122-129`, plan exit 8. Open questions `:163`. |
| Environment URL from an environment variable, asked at design, recorded, supplied by tests | met | Q2 in human-questions.md. `AccountErpNotify.cs:45`. Canvas decision `:30`. Tests seed `zava_ErpBaseUrl` (`AccountErpNotifyTests.cs:135-147`). Check "GetEnvironmentVariable". |
| SC1: Canvas records Async PostOp Create + reason, Integrations, secure-config name, timeout | met | Canvas `:8-9`, `:70-76`, `:79-80`, `:38`. |
| SC2: test-first RED to GREEN on payload, header, failures and registration; no network | met | Commits `38a2711` (RED) then `9044904` (feat). `logs/test-red-Integrations.log` shows 12 failed, `logs/test-green-Integrations.log` shows 0 failed. Cases C1-C5 are covered by tests at `AccountErpNotifyTests.cs:27-89` and in `ErpAccountClientTests`. |
| SC3: build clean of VELA00x; code-review PASS | met | Check "no VELA diagnostics". `review-1.md:78` and the verdict PASS. |
| SC4: both packages; plan on the shipped packages, read-only; Gate names how the key is supplied | met | Canvas `:152,157-158`. Check "read-only vela plan runs". |
| One question at a time; ask vs assume | met | 3 separate questions, each with an answer. Assumptions are recorded in the Canvas (`:32-38`). |

## Planted-violation results
I built each plant from a copy of the project (`planted-<x>/`). Each one went to its own fresh vela-reviewer, which was given only the diff and the Canvas.

| Plant | Build | Expected | Reviewer verdict | Result |
| --- | --- | --- | --- | --- |
| (a) API key as a string constant in the service | 0 errors, 0 warnings | Critical | BLOCK, Critical (secret in code/repo; secure config bypassed) | pass |
| (b) step switched to `.Sync()` | 0 errors, 0 warnings | Critical | BLOCK, Critical (a down ERP rolls back the save; contradicts the Canvas) | pass |
| (c) `HttpClient` timeout removed | 0 errors, 1 warning VELA026 | Required | BLOCK, Critical (breaks C4 and the Safeguard; the checklist baseline is Required) | pass |
| (d) URL changed to `https://20.50.1.10` | 0 errors, 0 warnings | Critical | BLOCK, Critical (the sandbox blocks raw IPs; the environment variable decision is broken) | pass |

## Findings against the skills
None blocking, none minor against the pack.

Observation, not a skill defect, to relay to Vela: plant (d) built with **no VELA025**. The literal `"https://20.50.1.10"` is assigned to a local variable and then concatenated with a path, so the analyzer does not see it, even though the Canvas Safeguards cite VELA025 as the guard. Only the review caught it. Per the house rule, this is a Vela analyzer coverage gap and should be reported upstream, not worked around in the skills.

## Verdict
**pass**. checks.json passed 29/29, every criterion is met, and all 4 planted violations were blocked at the expected severity or higher. The next run should re-check that the success path still goes through `WithService<T>` and that the empty Plugins package handling stays recorded in the Canvas.
