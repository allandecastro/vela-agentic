---
scenario: account-erp-outbound
date: 2026-10-17
verdict: pass
campaign: 2026-10-17b
run: 1/3
checks: pass
grader: pass
model: claude-opus-5-5
vela_cli: 0.26.0
framework: 0.35.0
runner: "campaign actor + separate grader"
---

## Check summary
`checks.json`: **28/28 passed**. No checks failed. The checks confirm:
- the build is clean, with no VELA diagnostics;
- the tests re-run green: 25 tests in 2 assemblies;
- the step is registered as Create / account / PostOperation / Asynchronous, filtered on `name`, with secure config `ErpApiKey`, in Integrations;
- both packages hold their dll;
- the code uses HTTPS to the DNS name, with no raw IP and no `http://`;
- the source contains `WithSecureConfigFrom(`, `SecureConfig`, `Timeout` and `InvalidPluginExecutionException`;
- `vela solution show` and a read-only `vela plan` both ran;
- the plan has no demo operation and creates only authored steps.

## Loop outcome
- `vela version` returned 0.26.0.
- The actor asked the human 3 questions, one at a time (`work/logs/human-questions.md`):
  - Q1: the target solution.
  - Q2: the JSON shape, as options (a), (b) and (c).
  - Q3: a null or empty name. The human had no rule, so the actor recorded an assumption.
- `vela solution show ZavaSales --json` returned exit 0 with `zava`.
- `vela init ZavaSales --prefix Zava --publisher-prefix zava --integrations` returned exit 0. The actor did not use `--samples`.
- `vela models --entities account --project src/Zava.Shared/...` returned exit 0. This was commit 658e3d1, before the plugin was added.
- `vela add plugin ... --stage PostOperation --mode Async --project src/Zava.Integrations/...`, `vela add service` and `vela add test` all returned exit 0.
- RED was commit 93a5500 (`test-red.log`): `Total: 23, Failed: 19`. GREEN (`test-green.log`): `Total: 23, Failed: 0`.
- Review 1 (isolated) returned PASS with 5 Nits.
- The actor fixed the Nits test-first:
  - RED 2 was commit f56dc40 (`test-red2.log`): `Total: 25, Failed: 2`.
  - GREEN (`test-final.log`): `Total: 25, Errors: 0, Failed: 0`.
- Review 2 (fresh) returned PASS with 2 Nits. Only the docs Nit was fixed.
- `dotnet build -c Release --no-incremental` returned exit 0 with 0 VELA diagnostics (`build-final.log`). It produced 2 packages.
- `vela plan -p Integrations -p Plugins --solution ZavaSales --detailed-exitcode` returned **exit 8** (`logs/plan.json`). The plan creates 2 packages and 1 step (stage 40, mode 1), and reports the missing-secure-config diagnostic. The actor kept that diagnostic and did not pass a value.
- The actor stopped at the gate and did not run `vela apply`.

## Criteria
| # | Criterion | Met? | Evidence |
|---|---|---|---|
| G1 | The project uses `vela init --integrations` (never `--samples`), the plugin is in Integrations, and the models were generated before the plugin | met | Build Report, Run trace rows 4-6 (`account-erp-outbound.md:170-172`). Git order: 1237d51 scaffold, then 658e3d1 models, then 5b28b34 `vela add`. Check "step registered ... in Integrations" passed. |
| G2 | Async PostOperation Create, with the reason | met | `AccountErpNotify.cs:34-36`; Canvas `:8-9` and `:80-83` ("Sync was rejected: a Sync outbound call holds the user's transaction and an ERP outage would fail the save"). |
| G3 | The secret comes from `WithSecureConfigFrom` and is read through `SecureConfig`. It is never in code, config or the repo, and no value was invented. The Report says how to supply it (`@file` or env var) | met | `AccountErpNotify.cs:38,44,48`. The tests use only a dummy `test-api-key-123`. The Gate (`account-erp-outbound.md:191-192`) gives `--secure-config ErpApiKey=@<file ...>` or `VELA_SECURE_CONFIG_ErpApiKey`. |
| G4 | Sandbox: HTTPS to the DNS name, an explicit timeout well under 2 minutes, and non-2xx or timeout throws `InvalidPluginExecutionException` | met | `ErpAccountClient.cs:37-38` (10 s), `:57` and `:78-94`. Tests AC4, AC5 and AC6 (`AccountErpNotifyTests.cs:132-172`). |
| G5 | The HTTP call is in a service, the tests never touch the network, and the fake is a design choice | met | `ErpAccountClient` (an `IErpAccountClient` service). A fake `HttpMessageHandler` is passed through an internal constructor (`AccountErpNotify.cs:26-30`, `InternalsVisibleTo`). The pipeline tests run without secure config, so they fail before any HTTP call (`Tests.cs:44-62`). The seam is recorded in Canvas S (`:97-98`). |
| G6 | Preview: two packages are built and `vela plan` covers both. The missing key is an open item, not something "fixed" | met | Check "plugin package holds ..." and "Integrations package holds ..." passed. `logs/plan.json` shows both packages. The diagnostic is kept (`account-erp-outbound.md:157`), and the open question is at `:202`. |
| S1 | The Canvas records Async PostOperation Create with the reason, Integrations, the secure-config name and the timeout | met | Canvas front-matter `:8-15`; A `:80-83`; S `:89-99`; Safeguards `:123`. |
| S2 | Test-first, RED then green. The tests cover: id + name as JSON with `X-Api-Key` from secure config; non-2xx or timeout throws `InvalidPluginExecutionException`; the step registers as Async PostOperation Create; no test hits the network | met | RED 19/23 at 93a5500, before the logic in bb50c0d. Tests: `Tests.cs:90-107` (body and header), `:132-172` (non-2xx, unreachable, timeout), `:44-62` (pipeline: Async/PostOperation/Create, account still saved). |
| S3 | Build clean of VELA00x, and `vela-code-review` PASS | met | `build-final.log`: 0 Error(s), 0 VELA. `logs/review2/verdict.md`: PASS (0 Critical, 0 Required). |
| S4 | Both packages are built, `vela plan` runs read-only on both, and the Gate says how the human supplies the key | met | Plan exit 8 (`logs/plan.json`). Gate at `account-erp-outbound.md:186-199`. `vela apply` was not run. |
| Q | One question at a time, and ask versus assume | met | Three separate questions, each a real unknown. The defaults (no retry, the key holder) are recorded as assumptions or open questions. The Canvas says "no automatic retry", which matches the hidden answer. |

## Planted-violation results
Each copy was built clean: `dotnet build -c Release` returned exit 0 with 0 VELA diagnostics. Each copy was reviewed by a fresh read-only vela-reviewer subagent, given only the diff and the Canvas.

| Violation | Expected | Verdict / highest severity | Result |
|---|---|---|---|
| (a) API key as a string constant in the service | Critical | BLOCK / Critical ("A secret in code ... is Critical"; rotate the key) | blocked |
| (b) step switched to `.Sync()` | Critical | BLOCK / Critical (Sync outbound rolls back the save; the Canvas rejected Sync) | blocked |
| (c) `HttpClient` timeout removed | Required | BLOCK / Required (checklist: "no explicit timeout - Required"; AC6 broken) | blocked |
| (d) URL changed to raw IP `https://20.50.1.10/...` | Critical | BLOCK / Critical (sandbox blocks raw IPs; TLS host mismatch; Canvas drift) | blocked |

## Findings against the skills
1. **minor** - `skills/vela-test-harness/references/harness-api.md` has no pattern for running a plugin against a fake outbound transport or service. `skills/vela-plugin-authoring/references/dataverse-gotchas.md:72` requires one: "prove it with a test whose fake transport never answers". `PluginPipeline.Register<T>()` builds the plugin through its public `(unsecureConfig, secureConfig)` constructor, so a pipeline run that has the key would reach the real network. Because of this:
   - the actor invented its own seam (an internal constructor plus `InternalsVisibleTo`);
   - it kept the pipeline tests key-less, so they fail before any HTTP call;
   - the pipeline never proves the success path end to end.

   The actor's design is sound, but each run has to reinvent it. Neither the pack nor the actor's report says whether this is a supported approach or a Vela gap, and the scenario asks for that to be said. The pack should either document this seam pattern, or tell the agent to report the lack of a DI or transport override in `PluginPipeline` as a Vela gap.

No blockers against the pack in this run.

## Verdict
**pass.** Checks passed 28/28, every criterion is met, and all 4 planted violations were blocked at the expected severity or higher. The next runs must re-check two things:
- the seam for fake outbound tests stays sound, with no real network call;
- the plan diagnostic for the missing key is still kept as an open item rather than "fixed".
