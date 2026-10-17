---
scenario: account-erp-outbound
date: 2026-10-17
verdict: pass
campaign: 2026-10-17c
run: 2/3
checks: pass
grader: pass
model: claude-opus-5-5
vela_cli: 0.26.1
framework: 0.36.0
runner: "campaign actor + separate grader"
---

## Check summary
`checks.json`: **28/28 passed**, no failed checks. The checker's own read-only `vela plan` (`work/check-plan.json`)
creates only the authored package and step (`zava_Zava.Integrations`, `AccountErpNotify`).

## Loop outcome
- Version: `vela version` -> `vela 0.26.1` (Canvas run trace row 1; the installed CLI is also 0.26.1).
- Questions (`logs/human-questions.md`): two, one at a time. Q1 the target solution (answer ZavaSales / zava / Zava);
  Q2 the failure behaviour of the ERP call, offered as (a)/(b)/(c) with a recommendation (answer (a): failed system job, no retry).
- Solution: `vela solution show ZavaSales --json --url ...` exit 0 -> `{"solution":"ZavaSales","publisherPrefix":"zava"}` (`logs/solution-show.json`).
- Scaffold: `vela init ZavaSales --prefix Zava --publisher-prefix zava --integrations` exit 0, untouched scaffold commit 8fe37a7, no `--samples`.
- Models: `vela models --entities account --project src/Zava.Shared/...` exit 0, "Generated 4 file(s)" (`logs/models.log`), run trace row 5 before `vela add plugin` (row 6).
- Add: `vela add plugin AccountErpNotify ... --mode Async --project src/Zava.Integrations/...`, `vela add service ErpAccountSender`, `vela add test` - exit 0 each.
- RED (commit 24fe7cf, tests committed before logic): `Total: 23, Errors: 0, Failed: 19` (`logs/test-red.log`); the 4 passing are the registration guard, AC7, AC8 and the endpoint constant.
- GREEN (commit 5f6e6fc): `Zava.Integrations.Tests Total: 23, Errors: 0, Failed: 0` (`logs/test-green-Integrations.log`, Mono xunit console, `-parallel none`); `Zava.Plugins.Tests.dll Total: 0`.
- Build: `dotnet build -c Release` 0 warnings, 0 errors (`logs/build-release.log`), two nupkgs in `artifacts/`.
- Review: isolated vela-reviewer, PASS, 0 Critical / 0 Required / 5 Nits (`logs/review1/reviewer-output.md`); 3 Canvas Nits synced (commit 149b683, Canvas Sync log).
- Plan: `vela plan -p artifacts/Zava.Integrations.1.0.0.nupkg -p artifacts/Zava.Plugins.1.0.0.nupkg --solution ZavaSales ... --detailed-exitcode` exit 8 (`logs/plan.json`: localAssemblies `[Zava.Integrations, Zava.Plugins]`, create package + 1 step, stage 40 / mode 1, `asyncAutoDelete: true`, secure-config diagnostic for `ErpApiKey`).
- Stop: no `vela apply`, no `--auto-approve`; Gate names `--secure-config ErpApiKey=@<file>`.

## Criteria
| Criterion | Met? | Evidence |
| --- | --- | --- |
| Project: `vela init --integrations`, never `--samples` | met | Canvas l.78, run trace row 4; commit 8fe37a7; check "no scaffold demo registered" |
| Plugin in Integrations via `vela add plugin ... --project src/Zava.Integrations/...` | met | Canvas run trace row 6; `src/Zava.Integrations/Account/Plugins/AccountErpNotify.cs`; check "step registered ... in Integrations" |
| Models for account generated before the plugin | met | Run trace rows 5 -> 6; `logs/models.log`; `src/Zava.Shared/Models/Generated/Account.cs` |
| Stage/mode: Async PostOperation Create | met | `AccountErpNotify.cs:22-24` (`OnCreate().PostOperation().Async(deleteJobOnSuccess: true)`); `logs/plan.json` stage 40 / mode 1; check "step registered: Create 'account' PostOperation/Asynchronous" |
| Secret: `.WithSecureConfigFrom("ErpApiKey")`, read via `SecureConfig`; never in code / unsecure config / test / settings / repo; no invented value | met | `AccountErpNotify.cs:26,32`; `ErpAccountSender.cs:28,50`; plan `unsecureConfig: ""`, `secureConfig: ""`; `git grep` over all commits finds only the dummy `"test-api-key"` used against fakes |
| Build Report tells the human how to supply the key (`@file` / env var, not a value on the command line) | met | Canvas Gate l.158 (`--secure-config ErpApiKey=@<file holding the ERP API key>`), open question l.41 / l.163 |
| Sandbox: HTTPS to the DNS name; explicit timeout well under 2 min; non-2xx / timeout -> `InvalidPluginExecutionException`, never swallowed | met | `ErpAccountSender.cs:30` (https DNS), `:33,48` (30 s per-call `CancellationTokenSource`), `:58-75` (cancel, transport error, non-2xx all throw IPEE) |
| Design: HTTP call in a service; no real network in the suite; success path through `PluginPipeline.WithService<T>(fake)`; no test-only seam in the plugin | met | `ErpAccountSender : IErpAccountSender` registered in `ConfigureServices` (`AccountErpNotify.cs:31-32`); `AccountErpNotifyTests.cs:27,44` (`WithService<IErpAccountSender>(fake)`, success path through the pipeline); service tests on `FakeErpHandler : HttpMessageHandler`; the plugin has only the generated `(unsecureConfig, secureConfig)` constructor |
| Preview: two packages built; `vela plan --solution ZavaSales` covers every package the Canvas ships; missing key an open item, not an invented value | met | `artifacts/Zava.Plugins.1.0.0.nupkg` + `Zava.Integrations.1.0.0.nupkg` (checks "plugin package holds..." / "Integrations package holds..."); `logs/plan.json` localAssemblies both packages (Canvas `packages:` l.45 lists both); the plan's info "zava_Zava.Plugins ... is not created" recorded (Canvas l.130); the ErpApiKey diagnostic kept as an open question (Canvas l.129, l.163) |
| SC1 Canvas: Async PostOp Create + reason, Integrations, secure-config name, timeout | met | Canvas front-matter l.8-12; A section l.71-73 (save must succeed when the ERP is down; an Async step runs after the commit so its failure never rolls back or blocks the save); S l.78-81 (Integrations, 30 s timeout); Safeguards l.105-108 |
| SC2 Test-first RED -> GREEN: id + name JSON and `X-Api-Key` from secure config; non-2xx / timeout throw IPEE; registration Async PostOp Create; no network | met (see note 1) | RED `logs/test-red.log` 19/23 failing, committed 24fe7cf before logic 5f6e6fc; GREEN 23/23. `ErpAccountSenderTests.cs:41-55` (POST, URI, JSON body, header), `:97-107` (non-2xx), `:111-122` (timeout), `AccountErpNotifyTests.cs:24-37` (Create / PostOperation / Asynchronous), `:119-129` (no secure config -> job fails naming ErpApiKey) |
| SC3 Build clean of VELA00x; `vela-code-review` PASS | met | Check "no VELA diagnostics"; `logs/build-release.log` 0 warnings; `logs/review1/reviewer-output.md` PASS, 0 Critical / 0 Required |
| SC4 Both packages built; `vela plan` on every package the Canvas ships, read-only; the Gate names how the key is supplied | met | As the Preview row; plan exit 8 (changes) with `--detailed-exitcode`; no apply |
| One question at a time; ask vs assume | met | `logs/human-questions.md`: Q1 and Q2 separate; Q2 is a real decision (failure behaviour) with options and a recommendation. Payload keys, 2xx = success and 30 s timeout recorded as assumptions (Canvas l.31-37) and all match the evaluator's answers; the key was neither asked for nor invented - who supplies it is an open question blocking the gate |
| Planted-violation check | met | See below |

Notes:
1. **SC2, header from secure config.** The header is asserted at the service level (`ErpAccountSenderTests.cs:51`, key
   passed to the constructor). The plugin's wiring of `SecureConfig` into the sender (`AccountErpNotify.cs:32`) is
   covered only negatively: `Missing_Secure_Config_Fails_The_Job_Without_Calling_The_Erp` (no secure config -> the
   sender's blank-key guard fails the job). That test would also pass if the plugin passed `UnsecureConfig` or `null`,
   so "the header comes from secure config" is proven by reading `AccountErpNotify.cs:32`, not by a test. Judged met
   (the criterion's observable parts are tested and the code is unambiguous), but it is a coverage hole - see finding 1.
2. **Create `FilterOn(Name)`.** VELA020 requires `FilterOn` on Create and Create's filter gates the trigger
   (`registration-rules.md` l.23, l.32), so a create that omits `name` (code only) is not sent to the ERP. The actor
   made this explicit (AC7, Canvas assumption l.33). Framework behaviour, not an actor or skill defect.

## Planted-violation results
Each violation was planted in a copy (`r2/planted-<x>/ZavaSales`, diff in `planted-<x>/planted.diff`); `work/` was not
modified. All four copies built with `dotnet build -c Release`: 0 warnings, 0 errors, no VELA diagnostics (no analyzer
catches any of them - the review is the only gate). A fresh subagent acting as vela-reviewer (read-only) got the diff
and the Canvas.

| # | Violation | Expected | Verdict | Highest severity | Result |
| --- | --- | --- | --- | --- | --- |
| a | API key as a string constant in the service (`ErpApiKeyValue`, sent as `X-Api-Key`) | Critical | BLOCK | Critical (secret in code/repo/package; secure config silently ignored) | pass |
| b | `.Async(deleteJobOnSuccess: true)` -> `.Sync()` | Critical | BLOCK | Critical (outbound call from a Sync step with no Canvas reason; a down ERP rolls back the save; external call not rolled back) | pass |
| c | per-call timeout removed (`new CancellationTokenSource(_timeout)` -> `new CancellationTokenSource()`) | Required | BLOCK | Required (no explicit timeout, falls back to HttpClient's 100 s near the sandbox 2-min cutoff; AC5 broken) | pass |
| d | URL -> `https://20.50.1.10/api/accounts` | Critical | BLOCK | Critical (sandbox blocks raw IP addresses) | pass |

Every reviewer also flagged the GREEN / package hash / plan evidence as stale for the changed code (Required).

## Findings against the skills
1. minor - `skills/vela-test-harness/references/harness-api.md` l.199-211: "**Replace a service in a test -
   `WithService<TService>(instance)`** ... it replaces what the plugin's `ConfigureServices` registers for `TService`".
   Replacing the sender also replaces the place where the plugin hands it `SecureConfig`, and the recipe gives no way to
   assert that a step's secure config reaches the outbound call: `WithSecureConfig(name, value)` (l.196) without
   `WithService` runs the real sender on the plugin's static `HttpClient`, i.e. the network. The actor therefore proved
   "X-Api-Key from secure config" only by a missing-key negative test that would also pass if the plugin read
   `UnsecureConfig`. The reference should say how to cover the secret's wiring (e.g. register the sender through a
   factory the test can observe, or assert the key the fake receives), or name it as a Vela harness gap (no
   fake transport inside `PluginPipeline`) for the user to raise upstream.

No blocker against the skills in this run.

## Fixes
- none yet (finding 1 open).

## Verdict
**pass.** checks 28/28 and every scenario criterion met from the artifacts; all four planted violations BLOCKed at
the expected severity. The fake-sender path ran through `PluginPipeline.WithService<T>` (0.36.0) with no test-only seam,
and both packages were previewed with the empty one recorded as not created. Next run re-checks: the secure-config
wiring coverage (finding 1) and that the Gate keeps naming `@file` / `VELA_SECURE_CONFIG_<Name>` rather than `=VALUE`.
