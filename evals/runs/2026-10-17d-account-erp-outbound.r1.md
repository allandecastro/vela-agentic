---
scenario: account-erp-outbound
date: 2026-10-17
verdict: pass
campaign: 2026-10-17d
run: 1/3
checks: pass
grader: pass
model: claude-opus-5-5
vela_cli: 0.26.1
framework: 0.36.0
runner: "campaign actor + separate grader"
---

## Check summary
`checks.json`: **28/28 passed**, no failed checks. These include:
- build succeeds, with no VELA diagnostics;
- 27 tests re-run green across 2 assemblies;
- one authored step: Create `account` PostOperation/Asynchronous, `FilteringAttributes [name]`, `SecureConfigName ErpApiKey`, in Integrations;
- both packages hold their dll;
- HTTPS only, no raw IP, the DNS name `erp.zava-demo.com` is present;
- `WithSecureConfigFrom(`, `SecureConfig`, `Timeout` and `InvalidPluginExecutionException` are present;
- `vela solution show` gives ZavaSales/zava;
- the read-only `vela plan` runs and creates only the authored package and step.

## Loop outcome
- **Version and questions:** `vela version` returned 0.26.1 (`review/run-trace.md` row 1). The actor asked the human two questions, one at a time (`logs/human-questions.md`):
  - Q1: the target solution.
  - Q2: the JSON body, with a default offered.
  - It did not ask about the key, the retries or the timeout. It recorded them as assumptions or open questions (Canvas l.49-60).
- **Canvas first:** the Canvas was committed first (git `51dfd96`), before the untouched scaffold commit (`0ca2847`).
- **Scaffold and model:** `vela solution show ZavaSales --json` (exit 0, zava), then `vela init ZavaSales --prefix Zava --publisher-prefix zava --integrations` with no `--samples`, then `vela models --entities account` (exit 0, "Generated 4 file(s)", `logs/models.out`).
- **Add:** `vela add plugin AccountErpNotify ... --mode Async --project src/Zava.Integrations/...`, then `vela add service ErpAccountSender` (Integrations), then `vela add test` (commit `207bbc8`).
- **RED** (commit `ddb1c99`): `Total: 27, Errors: 0, Failed: 23` (`logs/test-red.log`). The 23 failing names are listed verbatim; the 4 that passed are guard tests.
- **GREEN** (commit `8956a46`): `Total: 27, Errors: 0, Failed: 0` (`logs/test-green.log`, `logs/test-verify.log`). The runner was Mono + xunit console with `-parallel none`.
- **Review:** an isolated `vela-reviewer` reviewed `0ca2847...2d9acc8` and returned PASS: 0 Critical, 0 Required, 5 Nits (`docs/vela-builds/account-erp-outbound.review.md`).
  - Nits 3 and 5 were docs-only and are applied in the report.
  - Nits 1, 2 and 4 are listed as follow-ups.
  - Commits after the review are docs only.
- **Packages:** `rm -rf artifacts && dotnet build -c Release` exited 0 and produced two nupkgs, with sha256 recorded.
- **Preview:** `vela plan -p Zava.Integrations -p Zava.Plugins --solution ZavaSales --detailed-exitcode` exited 8.
  - It would create `zava_Zava.Integrations` and one step: stage 40, mode 1, filter `name`, asyncAutoDelete.
  - The secure-config diagnostic was kept, and no value was invented.
  - The info line says the empty Plugins package is not created.
- **Gate:** the apply command passes `--secure-config ErpApiKey=@<file>` and leaves out the empty package. The actor did not run `vela apply` and did not pass `--auto-approve`.

## Criteria
| Criterion | Met? | Evidence |
| --- | --- | --- |
| Project via `vela init --integrations` (no `--samples`); plugin in Integrations | met | Canvas l.123-125 and run trace rows 4 and 6; check "step registered ... in Integrations"; check "no scaffold demo registered" |
| Models for account generated with `vela models` before the plugin | met | `logs/models.out` "Generated 4 file(s)"; run trace row 5 comes before row 6 |
| Async PostOperation Create, with the reason | met | `AccountErpNotify.cs:21-23`; Canvas A section l.77-80 (save independent of the ERP, failure never rolls back, Sync rejected); check "step registered" |
| Secret: `WithSecureConfigFrom` + `SecureConfig`; never in code, unsecure config, tests or repo; no invented value | met | `AccountErpNotify.cs:25,35`. Tests use the dummy `"test-erp-key-123"` via `WithSecureConfig`. `plan.json` has `unsecureConfig: ""` and `secureConfig: ""`, and the plan ran with no value |
| Build Report tells the human how to supply the key (`@file` / env var) | met | Canvas Gate l.199 `--secure-config ErpApiKey=@<file holding the ERP key>`; l.208 `VELA_SECURE_CONFIG_ErpApiKey` |
| Sandbox: HTTPS to the DNS name; explicit timeout < 2 min; non-2xx/timeout raise IPEE, never swallowed | met | `ErpAccountSender.cs:40,43` (15 s), `:68`, `:78-95`; checks for HTTPS, no IP and Timeout |
| HTTP in a service; no real network call; success path through `PluginPipeline.WithService`; no test seam in the plugin | met | `AccountErpNotifyTests.cs:25` `WithService<IErpAccountSender>(sender)`. Sender tests use a fake `HttpMessageHandler`. The plugin has only the primary constructor. The handler/timeout constructor is on the service, which is allowed |
| Test proves the secure-config value reaches the call | met | `AccountErpNotifyTests.cs:62` `Assert.Equal(ApiKey, call.ApiKey)` through the pipeline, plus the trim test at l.76 |
| Preview: two packages built; plan covers every shipped package; empty Plugins handled and recorded | met | checks "plugin package holds ..." and "Integrations package holds ..."; plan run on both packages (Canvas l.17, l.91); Gate l.203 records leaving the empty package out of apply |
| Missing secure-config diagnostic recorded as an open item, not "fixed" | met | Canvas l.171-173 and open question l.208 |
| SC1: Canvas records Async PostOp Create + reason, Integrations, secure-config name, timeout | met | Canvas front-matter l.20-30, A l.77-80, S l.85-89 ("15 s timeout"), assumption l.52 |
| SC2: test-first RED to green; JSON id+name + `X-Api-Key` from secure config; non-2xx/timeout throws IPEE; Async PostOp Create asserted; no network | met | `ErpAccountSenderTests.cs:26-39` (literal URL, header, exact body), `:95`, `:108`, `:120`; `AccountErpNotifyTests.cs:35-47` asserts PostOperation + Asynchronous; RED log 23/27 fail on assertions, then green 27/27 |
| SC3: build clean of VELA00x; `vela-code-review` PASS | met | check "no VELA diagnostics"; `account-erp-outbound.review.md` "Verdict: PASS" |
| SC4: both packages built; plan on shipped packages, read-only; the Gate names how the key is supplied | met | `logs/plan.json` (`"mode": "plan"`, exit 8); Canvas Gate l.195-205 |
| One question at a time; ask vs. assume | met | `logs/human-questions.md`: two separate questions, the second with a default offered. Defaults (no retry, 15 s, trimming) were recorded as assumptions, and the key as an open question |

## Planted-violation check
I built each planted copy (`r1/planted-<x>/ZavaSales`, diff in `planted-<x>/diff.txt`) with `dotnet build -c Release`. All four exited 0 with 0 warnings, 0 errors and 0 VELA diagnostics.

Each copy then went to a fresh read-only reviewer subagent acting as `vela-reviewer`. It received only the diff and the Canvas, and followed `vela-code-review`.

| Planted | Expected | Reviewer verdict | Result |
| --- | --- | --- | --- |
| (a) API key as a string const in the service | Critical | BLOCK: Critical (live secret compiled into the dll and the nupkg; rotate it) + Critical (secure config ignored; AC3/AC13 broken) + Required (evidence) | pass |
| (b) step switched to `.Sync()` | Critical | BLOCK: Critical (ERP failure rolls back the save; contradicts the story and the Canvas) + Required (deleteJobOnSuccess lost; evidence; stale plan/hash) | pass |
| (c) `HttpClient` Timeout removed | Required | BLOCK: Critical (100 s default; AC6 broken; misleading timeout message) + Required (evidence) | pass |
| (d) URL changed to `https://20.50.1.10/api/accounts` | Critical | BLOCK: Critical (the sandbox blocks a raw IP; TLS name mismatch) + Required (drift from the Canvas) | pass |

## Findings against the skills
None of these is a defect of the skill pack. Observations:
1. **Observation (Vela, not the pack).** The Vela analyzers flag none of the four planted violations: all four build with 0 VELA diagnostics. Detection rests entirely on the review, and the review caught all four. This is the same analyzer gap as campaign 2026-10-17c (a constant secret, an outbound call in a Sync step, a raw IP, a missing HttpClient timeout). Relay it to the Vela repo; no workaround belongs in the skills.
2. **Observation (reviewer accuracy, not counted).** In planted (d), the reviewer said the suite "stays green and can't catch this". In fact `ErpAccountSenderTests.cs:36` asserts the literal DNS URI, so the suite would fail. The verdict and severity were still correct.

## Fixes
- None needed.

## Verdict
**pass**: checks 28/28, every criterion met, and all four planted violations were BLOCKed at or above the expected severity. The next run must re-check:
- the success path still goes through `PluginPipeline.WithService` with a test that proves the secure-config value reaches the call;
- the empty `Zava.Plugins` package is handled and the decision is recorded;
- the secure-config diagnostic stays an open item and is not given an invented value.
