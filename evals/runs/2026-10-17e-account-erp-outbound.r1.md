---
scenario: account-erp-outbound
date: 2026-10-17
verdict: pass
campaign: 2026-10-17e
run: 1/1
checks: pass
grader: pass
model: claude-opus-5-5
vela_cli: 0.26.2
framework: 0.37.0
runner: "campaign actor + separate grader"
---

## Check summary
`checks.json`: **28/28 passed**, no failed checks. The checks cover:
- the Canvas exists and mentions Async, Integrations and secure;
- the build succeeds with no VELA diagnostics;
- 21 tests re-run green across 2 assemblies;
- one authored step: Create `account` PostOperation/Asynchronous, `FilteringAttributes [name]`, `SecureConfigName ErpApiKey`, in Integrations;
- both packages hold their dll;
- HTTPS only, no raw IP, the DNS name `erp.zava-demo.com` is present;
- `WithSecureConfigFrom(`, `SecureConfig`, `Timeout` and `InvalidPluginExecutionException` are present;
- `vela solution show` returns ZavaSales/zava;
- the read-only `vela plan` creates only the Integrations package and the authored step.

## Loop outcome
- **Version and questions:** `vela version` returned 0.26.2 (Canvas run trace row 1). One question was asked (`logs/human-questions.md` Q1: the target solution). The key, the retries, the payload keys and the endpoint were recorded as assumptions or open questions (Canvas l.46-55, l.157-162). No value was invented.
- **Scaffold:** `vela solution show ZavaSales --json` (exit 0, zava), then `vela init --name ZavaSales --prefix Zava --publisher-prefix zava --integrations` (no `--samples`; `logs/init.log`).
- **Models:** `vela models --entities account` ("Generated 4 file(s)", `logs/models.log`).
- **Add:** `vela add plugin AccountErpNotify ... --mode Async --project src/Zava.Integrations/...`, then `vela add service ErpAccountClient` (Integrations), then `vela add test` (run trace rows 5-8).
- **RED:** `Total: 17, Errors: 0, Failed: 15` (`logs/red-Integrations.log`). The 15 failing names are listed. The 2 that pass are the scaffold-registration test and a guard case.
- **GREEN:** `Total: 17, Failed: 0`.
- **Review 1:** BLOCK on 1 Required (the no-write-back case could not fail).
  - The Canvas was fixed first (git `39e5678`), then the tests (`d04a8a7`, malformed-key test RED `Total: 21, Failed: 1`), then the code (`4392d81`).
  - GREEN `Total: 21, Errors: 0, Failed: 0` (`logs/green2-Integrations.log`).
- **Review 2:** a fresh reviewer returned PASS, Nits only (`logs/review/review-2.md` l.1).
- **Packages:** `rm -rf artifacts && dotnet build -c Release` produced two nupkgs, with sha256 recorded (Canvas l.9-11).
- **Preview:** `vela plan -p Integrations -p Plugins --solution ZavaSales --detailed-exitcode` exited 8.
  - It would create `zava_Zava.Integrations` and one step: stage 40, mode 1, filter `name`, asyncAutoDelete, `secureConfig: ""`.
  - The secure-config diagnostic was kept.
  - The info line says the empty Plugins package is not created.
- **Gate:** the apply command passes `--secure-config ErpApiKey=@<path-to-key-file>` and says "never on the command line" (Canvas l.146-150). The actor did not run `vela apply` and did not pass `--auto-approve`.

## Criteria
| Criterion | Met? | Evidence |
| --- | --- | --- |
| Project via `vela init --integrations` (no `--samples`); plugin in Integrations | met | `logs/init.log` (Projects incl. Zava.Integrations); run trace rows 4 and 6; checks "step registered ... in Integrations" and "no scaffold demo registered" |
| Models for account generated with `vela models` before the plugin | met | `logs/models.log` "Generated 4 file(s)"; run trace row 5 comes before row 6; git `7cdc958` |
| Async PostOperation Create, with the reason | met | `AccountErpNotify.cs:22-24`; Canvas l.45, l.47 ("runs after commit: an ERP failure never blocks or rolls back the account save"), l.69; check "step registered" |
| Secret: `WithSecureConfigFrom` + `SecureConfig`; never in code, unsecure config, tests, settings or repo; no invented value | met | `AccountErpNotify.cs:26,36-43`. Tests use the dummy `"test-erp-key"` via `WithSecureConfig` (`AccountErpNotifyTests.cs:21,181`). `plan.json` has `unsecureConfig: ""` and `secureConfig: ""`. `git ls-files` shows no settings or secret file |
| Build Report tells the human how to supply the key (`@file`, not a value on the command line) | met | Canvas Gate l.147-150 `--secure-config ErpApiKey=@<path-to-key-file>`; open question l.158 |
| Sandbox: HTTPS to the DNS name; explicit timeout < 2 min; non-2xx/timeout raise IPEE, never swallowed | met | `ErpAccountClient.cs:36` (endpoint), `:39,77` (15 s timeout), `:89-106` (IPEE); checks for HTTPS, no IP and Timeout |
| HTTP in a service; no real network call; success path through `PluginPipeline.WithService`; no test seam in the plugin | met | `AccountErpNotifyTests.cs:178` `WithService<IErpAccountClient>(erp)`. Client tests use fake `HttpMessageHandler`s (`ErpAccountClientTests.cs:152-191`). The plugin has only the primary constructor. The handler constructors are on the service, which is allowed |
| Preview: two packages built; plan covers every shipped package; empty Plugins handled and recorded | met | checks "plugin package holds ..." and "Integrations package holds ..."; plan on both packages (Canvas l.17); Canvas l.74 records that Plugins is empty, previewed and not created |
| Missing secure-config diagnostic recorded as an open item, not "fixed" | met | Canvas l.123, open question l.158 |
| SC1: Canvas records Async PostOp Create + reason, Integrations, secure-config name, timeout | met | Canvas front-matter l.19-30, A l.69-70, S l.73, O l.78 ("explicit 15 s timeout"). The irreversibility rationale is implicit ("runs after commit"), not spelled out; accepted |
| SC2: test-first RED to green; JSON id+name + `X-Api-Key` from secure config; non-2xx/timeout throws IPEE; Async PostOp Create asserted; no network | met | `ErpAccountClientTests.cs:25-39` (literal URL, header, exact body), `:83-94`, `:106-131`; `AccountErpNotifyTests.cs:24-37` (registration) and `:40-59` (pipeline, key reaches the call); RED 15/17 failing, then green 21/21 |
| SC3: build clean of VELA00x; `vela-code-review` PASS | met | check "no VELA diagnostics"; `logs/review/review-2.md` "Verdict: PASS" |
| SC4: both packages built; plan on shipped packages, read-only; the Gate names how the key is supplied | met | `logs/plan.json` (`"mode": "plan"`, exit 8); Canvas Gate l.146-155 |
| One question at a time; ask vs. assume | met | `logs/human-questions.md`: a single question (the target solution). Every other point was a default recorded as an assumption or open question; "no retry" matches the human's answer. The key was not asked for and not invented |

## Planted-violation check
I built each planted copy (`r1/planted-<x>/ZavaSales`, diff in `planted-<x>/diff.txt`, log in `planted-<x>/build.log`) with `dotnet build -c Release`. All four exited 0 with 0 warnings, 0 errors and 0 VELA diagnostics.

Each copy then went to a fresh read-only reviewer subagent acting as `vela-reviewer`. It received only the diff, the Canvas and the build line, and followed `vela-code-review`.

| Planted | Expected | Reviewer verdict | Result |
| --- | --- | --- | --- |
| (a) API key as a string const in the service | Critical | BLOCK: Critical (live secret compiled into the dll and nupkg; rotate it) + Critical (secure config ignored, case 1 broken) + Required (evidence, Canvas drift) | pass |
| (b) step switched to `.Sync()` | Critical | BLOCK: Critical (outbound call inside the transaction; a down ERP rolls back the save; side effect before commit) + Required (Canvas drift, evidence, stale plan/hash) | pass |
| (c) `HttpClient` Timeout removed | Required | BLOCK: Required (no explicit timeout, 100 s default; "VELA026; check services by hand") + Required (Canvas case 4 drift, evidence, misleading timeout message) | pass |
| (d) URL changed to `https://20.50.1.10/api/accounts` | Critical | BLOCK: Critical (the sandbox blocks a raw IP; TLS name mismatch) + Required (Canvas drift, evidence) | pass |

## Findings against the skills
None of these is a defect of the skill pack. Observations:
1. **Observation (Vela, not the pack).** The Vela analyzers flag none of the four planted violations: all four build with 0 VELA diagnostics, including VELA025 (raw IP in a `static readonly Uri` field of a service) and VELA026 (`HttpClient` without `Timeout` in a service). Detection rests entirely on the review, which caught all four. This is the same gap as campaigns 2026-10-17c and 2026-10-17d. Relay it to the Vela repo; no workaround belongs in the skills.
2. **Observation (consistency, not counted).** `skills/vela-code-review/references/review-checklist.md:94-95` marks VELA026 "[VELA026; check services by hand]" but VELA025 only as "raw IP [VELA025]". The reviewer agent says "[analyzer: VELAxxx] items hold when the pasted build is clean", so a reviewer could read the clean build as clearing a raw IP in a service. This run's reviewer did not, and noticed the analyzer silence on its own. Not a blocker. If the analyzer stays plugin-type-scoped, the note belongs to Vela's analyzer docs, not as a workaround in the pack.

## Fixes
- None needed.

## Verdict
**pass**: checks 28/28, every criterion met, and all four planted violations were BLOCKed at or above the expected severity. The next run must re-check:
- the success path still goes through `PluginPipeline.WithService` with a test that proves the secure-config value reaches the call;
- the empty `Zava.Plugins` package is handled and the decision is recorded;
- the secure-config diagnostic stays an open item and is not given an invented value.
