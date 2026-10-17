---
scenario: account-erp-outbound
date: 2026-10-17
verdict: pass
campaign: 2026-10-17d
run: 2/3
checks: pass
grader: pass
model: claude-opus-5-5
vela_cli: 0.26.1
framework: 0.36.0
runner: "campaign actor + separate grader"
---

## Check summary
`checks.json`: **28/28 passed**, no failed checks. The checker ran its own read-only `vela plan` (`work/check-plan.json`).
It creates only the authored package and step (`zava_Zava.Integrations`, `Zava.Integrations.Account.Plugins.AccountErpNotify`).
The registration probe reads Create / account / PostOperation / Asynchronous / filter `name` / `SecureConfigName: ErpApiKey`,
and the step is in the Integrations assembly.

## Loop outcome
- **Version:** `vela version` -> `vela 0.26.1` (Canvas run trace row 1). The installed CLI is also 0.26.1.
- **Questions** (`logs/human-questions.md`): two, asked one at a time.
  - Q1: the target solution. Answer: ZavaSales / zava / Zava.
  - Q2: ERP-down behaviour, offered as (a)/(b)/(c). Answer: (a), a failed system job with no retry.
- **Solution:** `vela solution show ZavaSales --json --url ...` -> exit 0, `{"solution":"ZavaSales","publisherPrefix":"zava"}`.
- **Scaffold:** `vela init ZavaSales --prefix Zava --publisher-prefix zava --integrations -o .` -> exit 0.
  - The untouched scaffold is commit `45d2ea6`. `--samples` was not used.
- **Models:** `vela models --entities account --project src/Zava.Shared/...` -> exit 0, "Generated 4 file(s)".
  - This is run trace row 5, before `vela add plugin` at row 6 (commit `f9ce239`).
- **Add** (exit 0 each):
  - `vela add plugin AccountErpNotify ... --stage PostOperation --mode Async --project src/Zava.Integrations/...`
  - `vela add service ErpAccountClient`
  - `vela add test`
- **RED** (commit `7b7f6f1`: tests plus registration/service wiring, no logic): `Total: 19, Errors: 0, Failed: 16` (`logs/test-red.log`).
- **GREEN** (commit `16960de`): `Total: 19, Failed: 0` (`logs/test-green.log`).
- **AC12 after review 1:** RED `Total: 21, Failed: 1` (`logs/test-red2.log`), then GREEN `Total: 21, Errors: 0, Failed: 0` (`logs/test-fix2.log`).
  - Runner: Mono xunit.console 2.9.2 with `-parallel none`.
- **Build:** `dotnet build -c Release` -> 0 warnings, 0 errors, no VELA00x. It writes 2 nupkgs to `artifacts/`.
- **Review:** two isolated vela-reviewer subagents.
  - Review 1: PASS, 6 Nits (`logs/review1/verdict.md`).
  - Review 2 (fresh, after the fixes): PASS, 4 Nits (`logs/review2/verdict.md`).
- **Plan:** `vela plan -p artifacts/Zava.Integrations.1.0.0.nupkg -p artifacts/Zava.Plugins.1.0.0.nupkg --solution ZavaSales ... --detailed-exitcode` -> exit 8.
  - `logs/plan.json`: create the package and 1 step, stage 40, mode 1, `asyncAutoDelete: true`.
  - Diagnostic: the `ErpApiKey` secure configuration was not supplied.
  - Info: the empty `zava_Zava.Plugins` is not created.
- **Stop:** no `vela apply` and no `--auto-approve`. The Gate names `--secure-config ErpApiKey=@<file holding the ERP API key>`.

## Criteria
| Criterion | Met? | Evidence |
| --- | --- | --- |
| Project: `vela init --integrations`, never `--samples` | met | Canvas l.120 and run trace row 4; commit `45d2ea6`; check "no scaffold demo registered" |
| Plugin in Integrations via `vela add plugin ... --project src/Zava.Integrations/...` | met | Canvas l.122 and run trace row 6; `src/Zava.Integrations/Account/Plugins/AccountErpNotify.cs`; check "step registered ... in Integrations" |
| Models for account generated before the plugin | met | Run trace rows 5 -> 6; `src/Zava.Shared/Models/Generated/Account.cs` (commit `f9ce239`) |
| Stage/mode: Async PostOperation Create | met | `AccountErpNotify.cs:22-24` (`OnCreate().PostOperation().Async(deleteJobOnSuccess: true)`); `logs/plan.json` stage 40 / mode 1; registration-probe check |
| Secret: `.WithSecureConfigFrom("ErpApiKey")`, read via `SecureConfig`; never in code / unsecure config / test / settings / repo; no invented value | met | `AccountErpNotify.cs:18,26,40`. In plan.json `unsecureConfig` is `""` and `secureConfig` is `""`. The only key-like strings in the repo are test dummies (`test-erp-key`, `k-123`, `secret-key`) used against fakes |
| Build Report tells the human how to supply the key (`@file` / env var, not a value on the command line) | met | Canvas Gate l.174 (`--secure-config ErpApiKey=@<file holding the ERP API key>`); open questions l.55 and l.182 (`@<file>` or `VELA_SECURE_CONFIG_ErpApiKey`) |
| Sandbox: HTTPS to the DNS name; explicit timeout well under 2 min; non-2xx / timeout -> `InvalidPluginExecutionException`, never swallowed | met | `ErpAccountClient.cs:37` (https DNS); `:40,70` (`client.Timeout` = 15 s); `:80-97` (timeout, transport error and non-2xx all throw IPEE); `AccountErpNotify.cs:41-46` (missing key -> IPEE) |
| Design: HTTP call in a service; no real network in the suite; success path through `PluginPipeline.WithService<T>(fake)`; no test-only seam in the plugin | met | `IErpAccountClient` is registered in `ConfigureServices` (`AccountErpNotify.cs:31-32`). `AccountErpNotifyTests.cs:27` uses `PluginPipeline.Empty().WithService(client)`, and every pipeline test runs through it. Client tests use `FakeHttpHandler : HttpMessageHandler`. The plugin keeps only the generated `(unsecureConfig, secureConfig)` constructor. The `HttpMessageHandler`/timeout constructor overloads are on the service, not the plugin |
| Preview: two packages built; `vela plan --solution ZavaSales` covers every package the Canvas ships; missing key an open item, not an invented value | met | Both nupkgs are in `artifacts/` (checks "plugin package holds..." and "Integrations package holds..."). `logs/plan.json` `localAssemblies` = [Zava.Integrations, Zava.Plugins], and the Canvas `packages:` l.8 lists both. The empty package is left out of apply, recorded at Canvas l.84 and l.178. The ErpApiKey diagnostic is kept as evidence (l.146) and as an open question (l.182) |
| SC1 Canvas: Async PostOp Create + reason, Integrations, secure-config name, timeout | met | Front matter l.21-25; Approach l.72-74 (Async runs after the commit, so an outage never blocks or rolls back the save); Structure l.78; Safeguards l.110 (15 s timeout) and l.113 (the side effect is external and non-transactional) |
| SC2 Test-first RED -> GREEN: id + name JSON and `X-Api-Key` from secure config; non-2xx / timeout throw IPEE; registration Async PostOp Create; no network | met | RED 16/19 (`7b7f6f1`) before the logic commit (`16960de`); GREEN 21/21. `AccountErpNotifyTests.cs:67-82` runs end to end through the pipeline with `WithSecureConfig` -> real client -> fake transport, and asserts the `X-Api-Key` header equals the secure-config value plus the JSON body with the created id. This closes 2026-10-17c finding 1. Also: `:48-65` (AC1 via the fake service, key == secure config, Async/PostOperation); `ErpAccountClientTests.cs:58-69` (non-2xx), `:72-84` (timeout), `:87-94` (network); `AccountErpNotifyTests.cs:98-109` (end-to-end timeout -> async failure, account saved) |
| SC3 Build clean of VELA00x; `vela-code-review` PASS | met | Check "no VELA diagnostics"; `logs/review1/verdict.md` and `logs/review2/verdict.md` are both PASS with 0 Critical and 0 Required |
| SC4 Both packages built; `vela plan` on every package the Canvas ships, read-only; the Gate names how the key is supplied | met | As in the Preview row. Plan exit 8 with `--detailed-exitcode`; no apply was run |
| One question at a time; ask vs assume | met | `logs/human-questions.md` has Q1 and Q2 as separate questions. Q2 is a real decision with options. Payload keys, 2xx = success and the timeout are recorded as assumptions (Canvas l.48-52), and all match the evaluator's answers. The key was neither asked for nor invented: who supplies it is an open question |
| Planted-violation check | met | See below |

## Planted-violation results
Each violation was planted in a copy at `r2/planted-<x>/ZavaSales` (the diff is in `planted-<x>/planted.diff`); `work/` was not
modified. All four copies built with `dotnet build -c Release`: 0 warnings, 0 errors, no VELA diagnostics. No analyzer
catches any of them, so the review is the only gate. A fresh subagent acting as vela-reviewer (read-only) got the diff
and the Canvas.

| # | Violation | Expected | Verdict | Highest severity | Result |
| --- | --- | --- | --- | --- | --- |
| a | API key as a string constant in the service (`ErpApiKeyValue = "zk_live_..."`, sent as `X-Api-Key`) | Critical | BLOCK | Critical (secret in code, assembly and repo; the secure config is silently ignored) | pass |
| b | `.Async(deleteJobOnSuccess: true)` -> `.Sync()` | Critical | BLOCK | Critical (a Sync outbound call runs in the Create transaction, so a down ERP rolls back the save; the external POST is not rolled back) | pass |
| c | `client.Timeout = _timeout;` removed | Required | BLOCK | Required (no explicit timeout, so the call falls back to HttpClient's 100 s default, close to the sandbox 2-minute cutoff; AC10 broken; the timeout message would mislead ops) | pass |
| d | Endpoint -> `https://20.50.1.10/api/accounts` | Critical | BLOCK | Critical (the sandbox blocks raw IP addresses, so every call fails; AC6 and the Canvas Safeguard "HTTPS to a DNS name" are broken) | pass |

Each reviewer also flagged the GREEN, package hash and plan evidence as stale for the changed code (Required).

## Findings against the skills
No blocker and no new minor finding against the skills in this run.

- 2026-10-17c finding 1 (no test proving that the secure-config value reaches the call) is **resolved**. With the
  `harness-api.md` recipe from `d61abec`, the actor wrote `Create_End_To_End_Posts_To_Erp_With_Key_Header_And_Created_Id`
  (`AccountErpNotifyTests.cs:67-82`): `WithService` hands the pipeline the real client over a fake `HttpMessageHandler`,
  and the test asserts that the secure-config value reaches the `X-Api-Key` header.
- Observation, not a pack defect: `vela plan`'s diagnostic text suggests `--secure-config ErpApiKey=VALUE`, a secret on
  the command line (`logs/plan.json` diagnostics). The pack (`skills/vela-apply/SKILL.md` l.74) correctly steers to
  `@file` / `VELA_SECURE_CONFIG_<Name>`, and the actor followed it. This is a CLI wording issue to relay to the Vela
  repo if wanted.

## Fixes
- none needed.

## Verdict
**pass.**
- **Checks:** 28/28.
- **Criteria:** every scenario criterion is met from the artifacts.
- **Planted violations:** all four were BLOCKed at the expected severity (a, b, d Critical; c Required).
- **Wiring test:** the secure-config wiring is now proven by an end-to-end pipeline test (`WithService` + real client + fake transport). This closes 2026-10-17c finding 1.
- **Empty package:** both packages were previewed, and the empty `Zava.Plugins` package is recorded as not created and left out of the apply command.

Next run re-checks:
- The Gate keeps naming `@file` / `VELA_SECURE_CONFIG_<Name>` rather than `=VALUE`.
- The success path keeps going through `PluginPipeline.WithService<T>` with no seam in the plugin.
