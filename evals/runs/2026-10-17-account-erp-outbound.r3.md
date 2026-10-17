---
scenario: account-erp-outbound
date: 2026-10-17
verdict: fail
campaign: 2026-10-17
run: 3/3
checks: pass
grader: fail
model: claude-opus-5-5
vela_cli: 0.26.0
framework: 0.35.0
runner: "campaign actor + separate grader"
---

## Check summary
`checks.json`: **28/28 passed**, no failed checks. These include: the step registered as Create account
PostOperation/Asynchronous with secure_config in Integrations; both packages hold their dll; HTTPS only;
no raw IP; DNS name; `WithSecureConfigFrom(`; `SecureConfig`; `Timeout`; `InvalidPluginExecutionException`;
a read-only `vela plan` runs; and the plan creates only authored steps.

## Loop outcome
- `vela version` gave 0.26.0.
- Q1-Q4 went to the human one at a time (`work/logs/human-questions.md`).
- `vela solution show ZavaSales --json` exited 0 and returned `zava`.
- `vela init ZavaSales --prefix Zava --publisher-prefix zava --integrations -o .` exited 0 (Vela.Plugins 0.35.0, no `--samples`).
- `vela models --entities account --project src/Zava.Shared/...` exited 0.
- `vela add plugin AccountErpNotify ... --mode Async ... --project src/Zava.Integrations/...`, `vela add service ErpAccountClient` and `vela add test` all exited 0.
- The RED commit 364086e ran 30 tests with 27 failed (`logs/test-red.log`). The GREEN commit 2f064e7 ran 30 with 0 failed (`logs/test-green.log`, `logs/test-final.log`).
- `dotnet build -c Release` finished with 0 warnings and 0 errors and produced 2 nupkgs.
- The isolated reviewer returned PASS with 5 Nits (`logs/review-1.md`).
- `vela plan` on both packages exited 8 (`logs/plan.json`), and on Integrations alone also exited 8. The only diagnostic is "secure config ErpApiKey not supplied", recorded as expected.
- The run stopped at the apply gate, and its gate command uses `--secure-config ErpApiKey=@<file>`.

## Criteria
| Criterion | Met? | Evidence |
| --- | --- | --- |
| Project: `vela init --integrations`, not `--samples` | met | `logs/init.log`; Canvas run trace row 4 |
| Plugin in the Integrations project via `vela add ... --project src/Zava.Integrations/...` | met | Canvas line 142; `src/Zava.Integrations/Account/Plugins/AccountErpNotify.cs`; check "step registered ... in Integrations" |
| Models for account generated before the plugin | met | Canvas run trace rows 5→6; commit b30f36f; `logs/models.log` |
| Async PostOperation Create, with the reason | met | `AccountErpNotify.cs:39-41`; Canvas A section lines 77-80 (save never blocked; side effect not rolled back); plan definition stage 40 / mode 1 |
| Secret: `.WithSecureConfigFrom("ErpApiKey")` and read via `SecureConfig`; no value in code, tests, settings or repo; no invented value | met | `AccountErpNotify.cs:35,43`. Tests use a dummy `"test-api-key-123"` for the fake transport only. Plan `secureConfig: ""` |
| Build Report tells the human how to supply the key (`@file` / env var, not a literal) | met | Canvas lines 26, 128-129, 209 (`--secure-config ErpApiKey=@<file holding the key>`) |
| Sandbox: HTTPS to the DNS name, explicit timeout well under 2 min, non-2xx and timeout throw `InvalidPluginExecutionException` (never swallowed) | met | `ErpAccountClient.cs:25,30,39,60-77` (20 s) |
| Design: HTTP in a service; no real network in the suite; fake transport; any gap reported | met | `ErpAccountClient` service; `TestDoubles/FakeErpTransport.cs` (HttpMessageHandler). Pipeline tests run without secure config, so they fail before any HTTP call. The gap that PluginPipeline cannot inject a transport is reported in the actor report "Gaps noticed" |
| Preview: both packages built; `vela plan --solution ZavaSales` covers both; missing key recorded as an open item, not invented | met | `artifacts/Zava.Plugins.1.0.0.nupkg` and `Zava.Integrations.1.0.0.nupkg`; `logs/plan.json` (localAssemblies Zava.Integrations + Zava.Plugins); Canvas lines 176-178 |
| SC1 Canvas records Async PostOp Create + reason, Integrations, secure-config name, timeout | met | Canvas frontmatter lines 18-27; A/S sections |
| SC2 Test-first RED→green: id+name JSON, X-Api-Key from secure config, non-2xx/timeout throw, step registration test, no network | met | `AccountErpNotifyTests.cs` (AC1/AC2 through the handler, AC8 pipeline Create/PostOp/Async); `ErpAccountClientTests.cs` (AC3-AC6, AC11); RED 27/30 → GREEN 30/30 |
| SC3 Build clean of VELA00x; `vela-code-review` PASS | met | check "no VELA diagnostics"; `logs/build-release.log` 0 warnings; `logs/review-1.md` PASS |
| SC4 Both packages built; `vela plan` on both, read-only; Gate names how the human supplies the key | met | `logs/plan.json`; Canvas Gate line 209 |
| One question at a time; asks rather than assumes | met | `logs/human-questions.md`: Q1-Q4 each single and closed-option. The key was never asked for or invented. The nameless-account default is recorded as A1 |
| Planted-violation check | **not met** | (d) was blocked at Required, but Critical was expected (see below) |

## Planted-violation results
Each violation was planted in a copy of the project (`r3/planted-<x>/ZavaSales`). Each copy built with 0 warnings, 0 errors and no VELA diagnostic. A fresh vela-reviewer subagent then reviewed the diff (`planted-<x>/planted.diff`, -U10) against the Canvas.

| # | Violation | Expected | Reviewer verdict | Highest severity | Result |
| --- | --- | --- | --- | --- | --- |
| a | API key as a string constant in the service | Critical | BLOCK | Critical (secret in code, review-checklist Secrets) | pass |
| b | Step switched to `.Sync()` | Critical | BLOCK | Critical (a down ERP rolls back the save; external call not rolled back) | pass |
| c | `HttpClient` timeout removed | Required | BLOCK | Required (no explicit timeout; AC5 test would be red) | pass |
| d | URL changed to `https://20.50.1.10/api/accounts` | Critical | BLOCK | **Required** ("the review checklist (Outbound calls) ... rates a breach as Required") | **fail** (below the expected severity) |

## Findings against the skills
1. **blocker** - `skills/vela-code-review/references/review-checklist.md:121-122` says "**Outbound calls:** HTTPS to a DNS name (no raw IP), an explicit timeout, from an Async step unless the Canvas records why it must be Sync - **Required**."
   - **What happened:** this one bullet gives a single severity to three different defects. A raw IP and a Sync outbound step both "will fail or misbehave on a live org", which line 12 defines as **Critical**.
   - The reviewer for planted (d) followed the bullet literally and graded the raw IP **Required**, even though it said itself that "on the org every async job would fail".
   - The reviewer for (b) reached Critical only through the general "misbehaves on a live org" rule, so the outcome depends on which rule the reviewer weighs.
   - **Correct:** split the bullet into three severities:
     - raw IP (sandbox blocks it, the call never happens): Critical
     - Sync outbound step with no Canvas reason: Critical
     - missing explicit timeout: Required
2. minor - `skills/vela-code-review/references/dataverse-gotchas.md:70-71` says the Integrations project "references `System.Net.Http`".
   - **What happened:** that holds for `<P>.Integrations`. The actor found that the scaffolded `<P>.Integrations.Tests` does not reference it, and had to add `System.Net.Http`, `System.Runtime.Serialization` and `System.Xml.Linq` to write an `HttpMessageHandler` fake.
   - This is a Vela scaffold gap for the user to relay. The pack could note it in `vela-test-harness` so the step is expected, not discovered.
   - Not a gate defect.
3. minor (Vela gap, correctly reported, not a pack defect) - Vela.Testing `PluginPipeline` constructs the plugin from its `(unsecure, secure)` constructor and has no transport or service injection.
   - **What happened:** the actor used an internal constructor seam plus "no secure config in pipeline tests" so that pipeline tests fail before any HTTP call.
   - This is the scenario's expected "say so in the report" outcome.

## Verdict
**fail.** checks pass (28/28). The actor met every scenario criterion. The grader fails the run on the planted-violation check, because (d) raw IP was blocked only at **Required** instead of **Critical**. The cause is the severity in the pack's review checklist (finding 1), not the actor. The next run must re-check (d) and (b) after the Outbound-calls severities are split.
