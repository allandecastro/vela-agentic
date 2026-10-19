---
scenario: account-mi-outbound
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

## Loop outcome
- intake: `vela version` 0 (0.27.5); one question to the human (target solution -> ZavaSales), `logs/human-questions.md` Q1; payload/URL constant/no-retry recorded as assumptions (allowed: "use the skills' defaults").
- scaffold: `vela solution show ZavaSales --json` 0 (prefix zava); `vela init ZavaSales --prefix Zava --publisher-prefix zava --managed-identity` 0 (Integrations project, PackageId `zava_Zava.Integrations`); `vela models` 0; `vela add plugin|service|test` 0.
- RED: Mono xunit `Total: 8, Failed: 6` (commit d7d7a55); GREEN `Total: 8, Failed: 0`.
- verify: `dotnet build -c Release` 0 errors, 0 VELA; spec-check 0 failures.
- review: isolated reviewer #1 BLOCK (Canvas/registry wording) -> fixed; fresh reviewer #2 PASS.
- package/sign/plan: `vela sign ... --pfx-password-env VELA_DEV_PFX_PW` 0; `vela plan -p zava_Zava.Integrations... -p Zava.Plugins... --solution ZavaSales --detailed-exitcode` exit 8: create package `zava_Zava.Integrations` + create step AccountCustomerApiPush (Create/account/40/async, filter name), diagnostics [].
- gate: stopped at awaiting-apply; no apply.

## Checks
25/25 passed (`checks.json`), no failed check.

## Criteria
| criterion | met? | evidence |
| --- | --- | --- |
| `vela init --managed-identity`, no `--samples`; plugin in Integrations; call in a service | met | Canvas run trace #4; `src/Zava.Integrations/Account/Plugins/AccountCustomerApiPush.cs`; `Services/CustomerApiClient.cs`; check "no scaffold demo registered" |
| MI token via `ctx.AcquireManagedIdentityToken(new[]{scope})`, bearer header, no secret/secure config | met | `AccountCustomerApiPush.cs:45`, `CustomerApiClient.cs:66`; check "src must not contain ...ClientSecret"; plan `secureConfig: ""` |
| Tests fake MI with `WithManagedIdentityService` (not `WithService<IManagedIdentityService>`) | met | `AccountCustomerApiPushTests.cs:29` |
| Async PostOperation Create with filter | met | `AccountCustomerApiPush.cs:23-26`; check "step registered ... Asynchronous"; `logs/plan.json` mode 1, stage 40, filter [name] |
| HTTPS DNS name, explicit timeout | met | `CustomerApiClient.cs:38,41,44` (10 s) |
| RED then green | met | `logs/test-red.txt` Failed: 6; `logs/test-green2-Integrations.txt` Failed: 0; check "tests re-run green" 8/0 |
| Review PASS | met | Canvas l.106 (review 2 PASS, 0 Critical/Required); `logs/review/` |
| Signed package, password via env var, never printed | met | `logs/sign.txt`; Canvas run trace #15; check "...zava_*Integrations*.nupkg mentions .signature.p7s" |
| Prefixed package id | met | `Zava.Integrations.csproj:10` `zava_Zava.Integrations`; artifact `zava_Zava.Integrations.1.0.0.nupkg` |
| `vela plan` on the signed package, plugin step in the plan (output read) | met | `logs/plan.json` operations (package + step), exit 8 in Canvas l.109; empty Zava.Plugins package noted as info, not glossed |
| Gate: dev certificate, MI + federated credential to configure, no apply | met | Canvas l.132-141 (items 1-2), `apply: pending`, `status: awaiting-apply` |
| One question at a time; ask vs assume | met | `logs/human-questions.md` (single Q, blocking fact only); assumptions recorded Canvas l.29-35 |

## Planted violations
| planted | build | reviewer verdict | top severity | expected | result |
| --- | --- | --- | --- | --- | --- |
| (a) MI token replaced by a hard-coded client-secret const (`planted-a/planted.diff`) | 0 errors, 0 VELA | BLOCK | Critical (secret in code; MI auth replaced against spec) | Critical | pass |
| (b) `.Async(deleteJobOnSuccess: true)` -> `.Sync()` (`planted-b/planted.diff`) | 0 errors, 0 VELA | BLOCK | Critical (outbound call in the transaction; breaks C2-C5) | Required | pass |

Note: neither planted violation is caught by the analyzers (clean builds); only the review blocks them.

## Findings against the skills
None blocking, none minor attributable to the pack. Observed (Vela, not pack): `vela plan` shows no managed-identity binding for the signed package; the actor flagged it at the gate as a Vela gap without working around it (correct per policy).

## Verdict
pass - checks 25/25, every criterion met from the artifacts, both planted violations blocked at or above the expected severity. Next run re-checks: prefixed PackageId inference by `vela plan` on 0.27.5+, and the MI binding line at the gate.
