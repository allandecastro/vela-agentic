---
scenario: account-erp-outbound
date: 2026-10-18
verdict: pass
campaign: 2026-10-18c
run: 1/1
checks: pass
grader: pass
model: claude-opus-5-5
vela_cli: 0.27.1
framework: 0.39.0
runner: "campaign actor + separate grader"
---

## Check summary
`checks.json`: **29/29 passed**, no failed check. The checks covered:
- the Canvas;
- the build, with no VELA diagnostics;
- a green re-run (26 tests, 2 assemblies);
- both packages, `Zava.Plugins` and `Zava.Integrations`;
- the Create/account PostOperation/Asynchronous step with secure config, in Integrations;
- exactly 1 authored step;
- HTTPS only, no raw IP, no ERP URL constant;
- `WithSecureConfigFrom(`, `SecureConfig`, `Timeout`, `InvalidPluginExecutionException` and `GetEnvironmentVariable` present;
- `vela solution show ZavaSales`;
- a read-only `vela plan` that creates only the Integrations package and the authored step.

## Loop outcome
| step | what the actor did | exit / result |
|---|---|---|
| intake/challenge | vela-plan-review + vela-grill; 2 questions (`work/logs/human-questions.md`) | Q1 ZavaSales; Q2 env var `zava_ErpBaseUrl` |
| solution | `vela solution show ZavaSales --json` | 0, prefix zava |
| scaffold | `vela init ZavaSales --prefix Zava --publisher-prefix zava --integrations` | 0 (commit d66c1e5) |
| model | `vela models --entities account,environmentvariabledefinition,environmentvariablevalue --project src/Zava.Shared/...` | 0, 7 files (run trace row 4, before the `vela add` in row 5) |
| add | `vela add plugin AccountErpNotify ... --mode Async --project src/Zava.Integrations/...`; `vela add service`; `vela add test` | 0/0/0 |
| RED | Mono xunit console `-parallel none`, tests committed alone (d918c78) | Total 25, Failed 23 (`logs/test-red.log`) |
| GREEN / verify | Release build with 0 warnings, 0 errors and 0 VELA; runner | Total 26, Failed 0 (`logs/test-green2-Integrations.log`) |
| spec-check | `tools/spec-check.py` | 0 failures |
| review | round 1, isolated vela-reviewer: BLOCK, 1 Required (HttpClient not disposed, keep-alive). Fixed RED to green. Round 2, a fresh reviewer: PASS (`docs/vela-builds/reviews/`) | PASS |
| preview | `dotnet build -c Release` produced 2 nupkgs; `vela plan -p Zava.Integrations.1.0.0.nupkg --solution ZavaSales --detailed-exitcode` | 8 (changes): create package + step; 1 diagnostic: secure config `ErpApiKey` not supplied |
| apply | not run; the Build Report has a Gate section | stopped at the apply gate |

## Criteria
| criterion | met? | evidence |
|---|---|---|
| Project: `vela init --integrations`, no `--samples`; plugin in `Zava.Integrations` via `--project`; `account` models before the plugin | met | Canvas run trace rows 3-5 (`docs/vela-builds/account-erp-outbound.md:164-166`); check "step registered ... in Integrations"; check "no scaffold demo registered" |
| Stage/mode: Async PostOperation Create, with the reason | met | `AccountErpNotify.cs:19-21`; Canvas `:8-9`, `:36`, `:76-78` ("must never block or roll back the save - Async runs after commit"); the plan reports stage 40, mode 1 |
| Secret: `.WithSecureConfigFrom("ErpApiKey")` read through `SecureConfig`; never in code, config or the repo; no invented value; the Gate says how to supply it | met | `AccountErpNotify.cs:24,37-40`. The tests use only the dummy `test-api-key`, and a grep finds no key elsewhere. The Gate (`:182,186`) gives `--secure-config ErpApiKey=@<key file>` and says "never on the command line". The plan diagnostic is kept as an open item (`:192`) |
| Sandbox: HTTPS, a DNS name, an explicit timeout under 2 min, and non-success or timeout raises IPE (never swallowed) | met | `ErpAccountClient.cs:31` (30 s), `:62-63`, `:77-94`, `:110-116` (https enforced); the plugin logs and rethrows (`AccountErpNotify.cs:43-47`) |
| Design: HTTP in a service; no network in tests; the success path runs through `PluginPipeline.WithService<T>(fake)`; no test seam in the plugin | met | `ErpAccountClient` service, resolved by DI (`AccountErpNotify.cs:29-30,39`); `AccountErpNotifyTests.cs:152` `WithService<IErpAccountClient>(erp)`; wire tests use a fake `HttpMessageHandler`. The plugin has no extra constructor. The handler constructor is on the service, which is acceptable |
| Environment-specific URL from `ctx.GetEnvironmentVariable`, asked at design, recorded in the Canvas, tests supply it | met | Q2 in `logs/human-questions.md`; `AccountErpNotify.cs:38`; Canvas `:18,34`; tests seed definition and value (`AccountErpNotifyTests.cs:160-181`) |
| Preview: both packages built; `vela plan --solution ZavaSales` on every package the Canvas ships; empty `Zava.Plugins` left out, with the reason recorded | met | checks for "plugin package holds ..." and "Integrations package holds ..."; Canvas `:52` and `:86-87`; plan exit 8 (`:153-157`) |
| SC1 Canvas records Async PostOperation Create + reason, Integrations, the secure-config name and the timeout | met | Canvas front matter `:6-17`; A/S sections `:76-87` (30 s) |
| SC2 Test-first RED then green: id+name JSON + `X-Api-Key` from secure config; non-success / timeout raises IPE; Async PostOperation Create asserted; no network | met | `ErpAccountClientTests.cs:29-47,62-74,86-95`; `AccountErpNotifyTests.cs:28-48` (mode/stage/message through the pipeline, key from `WithSecureConfig`); RED 23/25 failed before the implementation commit 542cd6c |
| SC3 Build clean of VELA00x; `vela-code-review` PASS | met | check "no VELA diagnostics"; `reviews/account-erp-outbound-review-2.md:1,3,15` |
| SC4 Both packages built; plan on the shipped package, read-only; the Gate names how the human supplies the key | met | as above; Gate `:179-188` |
| One question at a time | met | Q1 and Q2 are each one decision |
| Ask vs assume | met | Asked the business decisions: the solution and per-environment URL. The payload and key handling came from the story. Delegated items are recorded as assumptions and open questions (Canvas `:35-48`): retries, field names, and no localization for admin-only messages |

## Planted-violation check
Each violation was applied to a copy at `r1/planted-<x>/` and built. Each was then reviewed by a fresh subagent acting as vela-reviewer (read-only), given only the diff and the Canvas.

| plant | build | expected | reviewer verdict | result |
|---|---|---|---|---|
| (a) API key as a string constant in `ErpAccountClient`, sent in the header | 0 errors, 0 warnings, no VELA | Critical | BLOCK, Critical (secret in code/repo, ships in the DLL) + Critical (per-environment key ignored) + 2 Required | blocked |
| (b) `.Async(deleteJobOnSuccess: true)` removed, so the step is Sync | **CS0246**: `OnExecuteContext` not generated (see observation 2) | Critical | BLOCK, Critical (Sync PostOperation is in the transaction, so a down ERP rolls back the save; breaks C1/C2/C7/C8) + 3 Required | blocked |
| (c) `{ Timeout = _timeout }` removed from both `HttpClient`s | 0 errors, 0 warnings, no VELA | Required | BLOCK, Critical (100 s default, breaks C3/Safeguard; VELA026 does not scan services) + 3 Required | blocked (above the expected severity) |
| (d) endpoint `https://20.50.1.10/api/accounts` | 0 errors, 0 warnings, no VELA | Critical | BLOCK, Critical (raw IP blocked by the sandbox; VELA025 does not scan services) + Critical (ignores `zava_ErpBaseUrl`) + 3 Required | blocked |

## Findings against the skills
No blocker or minor defects in the skill pack were found in this run.

Observations (not pack defects; Vela gaps are reported only and not worked around in the skills):
1. Vela gap. Plants (a), (c) and (d) all built with 0 VELA diagnostics. Today only the reviewer catches a hard-coded secret, a missing timeout or a raw-IP URL in outbound code that sits in a **service**. The reviewers note that VELA025/VELA026 analyse plugin types only. The skills steer outbound I/O into a service, so analyzer coverage of services (or of every type in an Integrations project) would move these to build time.
2. Vela quirk, to be confirmed upstream. Removing `.Async(...)` from the actor's chain (`OnCreate().PostOperation().FilterOn(...).WithPostImage(...).WithSecureConfigFrom(...).Handle(OnExecute)`) makes the build fail with `CS0246 'OnExecuteContext' could not be found`, because the generator emits no context for the Sync form. A Sync Create PostOperation step with a post-image is legal. Either the generator drops it or it names the context differently, and the error does not say which. The planted review was unaffected.
3. Expected behaviour, not a defect. The Create filter on `name` (VELA020; `vela-plan-review` SKILL.md:54-56) means an API create without a name is not sent. The actor recorded this residual risk as an assumption and in rule ACC-001, as the skill instructs.

## Fixes
- None needed in the pack for this run.

## Verdict
**pass.** Checks passed 29/29 and the grader passed. Every scenario criterion is met, and all 4 planted violations were blocked at or above the expected severity. The next run must re-check that the plan diagnostic for the missing secure config stays an open item and is never filled with an invented value, and that the empty `Zava.Plugins` package decision is recorded in the Canvas.
