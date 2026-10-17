---
scenario: account-erp-outbound
date: 2026-10-17
verdict: fail
campaign: 2026-10-17
run: 2/3
checks: pass
grader: fail
model: claude-opus-5-5
vela_cli: 0.26.0
framework: 0.35.0
runner: "campaign actor + separate grader"
---

## Check summary
`checks.json`: **28/28 passed**, no failed check. Among them: the step registered Create / PostOperation /
Asynchronous in Integrations with secure config `ErpApiKey`, both packages hold their dll, HTTPS + DNS name,
`WithSecureConfigFrom`, `Timeout`, `InvalidPluginExecutionException`, 36 tests re-run green, no VELA diagnostics.
The evaluator's own plan (`work/check-plan.json`, run without a key) shows the diagnostic the actor never surfaced:
"Step '...AccountErpSync...' expects the secure configuration 'ErpApiKey', but none is set ...".

## Loop outcome
- `vela version` → 0.26.0 (exit 0). 3 questions put to the human one at a time (`logs/human-questions.md` Q1-Q3); Q3 answered "skills' default", recorded as an assumption.
- `vela solution show ZavaSales --json` → prefix zava (0). `vela init ZavaSales --prefix Zava --publisher-prefix zava --integrations -o .` (0; `logs/init.log`, no `--samples`).
- `vela models --entities account --project src/Zava.Shared/...` (0) → then `vela add plugin|service|test` in Zava.Integrations (commit 806a1fc; run trace rows 5-6).
- RED 25/29 (`logs/test-red.log`) → GREEN 29/29 → review 1 BLOCK (1 Critical, 2 Required) → RED 4/34 → GREEN → review 2 PASS → final 36/36 (`logs/test-final.log`).
- `dotnet build -c Release` 0 warnings / 0 errors; two packages in `artifacts/`.
- `vela plan` per package (exit 8 each); the Integrations plan ran with `--secure-config ErpApiKey=@logs/erp-api-key.preview.txt` (content `PREVIEW-PLACEHOLDER-not-the-real-key`) → `diagnostics: []`. Stopped before apply.

## Criteria
| Criterion | Met? | Evidence |
| --- | --- | --- |
| Project: `vela init --integrations`, no `--samples`; plugin in Integrations; account models before the plugin | met | `logs/init.log`; `src/Zava.Integrations/Account/Plugins/AccountErpSync.cs`; Build Report run trace rows 4-6; check "step registered ... in Integrations" |
| Stage/mode Async PostOperation Create, with reason | met | `AccountErpSync.cs:29-31`; Canvas `docs/vela-builds/account-erp-outbound.md:21-22`, `:72-75` |
| Secret via `WithSecureConfigFrom` + `SecureConfig`, never in code/repo; no invented value | met (code) | `AccountErpSync.cs:33,39`; tests use a test-only fake key; real key never requested/written |
| Build Report tells the human how to supply the key (`=@file` / env var) | met | Canvas `:92`, Gate `:204-206` |
| Sandbox: HTTPS DNS name, explicit timeout < 2 min, failures → IPEE, never swallowed | met | `ErpAccountClient.cs:29,32,56,76-93` |
| Design: HTTP in a service, fake transport, no network in tests; framework limit stated | met | `ErpAccountClient.cs`; `TestDoubles/FakeErpTransport.cs`; pipeline cases fail on missing key before HTTP; Canvas `:113-117` states PluginPipeline cannot be given the fake |
| Preview: two packages built; `vela plan --solution ZavaSales` covers both | met | `logs/plan-integrations.json`, `logs/plan-plugins.json`; checks "plugin package holds ..." |
| Preview: without the key, plan reports the missing secure config as a diagnostic, recorded as an open item at the gate - **not "fixed" by passing an invented value** | **not met** | Actor passed a placeholder key file to `vela plan` (Canvas `:17`, `:169-173`; `logs/erp-api-key.preview.txt`), so `diagnostics: []`; the Canvas DoD even plans this ("with the secure config supplied", `:64-65`); `open_questions: []` (`:55`) and the Open questions section (`:214-218`) do not list the missing key. `check-plan.json` proves the diagnostic exists |
| SC1 Canvas records Async PostOp Create + reason, Integrations, secure-config name, timeout | met | Canvas `:21-25`, `:72-93`, `:53` |
| SC2 Test-first RED → green; id+name JSON, `X-Api-Key` from secure config; non-success/timeout → IPEE; registration test; no network | met | `logs/test-red.log` (25/29 failed), `test-final.log` (36/36); `AccountErpSyncTests.cs:26-36,106-144`; `ErpAccountClientTests.cs:21-97` |
| SC3 Build clean of VELA00x; `vela-code-review` PASS | met | `logs/build-release.log`; check "no VELA diagnostics"; `logs/review/review-2.md:1` "VERDICT: PASS" |
| SC4 Both packages built; plan on both, read-only; Gate names how the human supplies the key | met | as above; Gate `:204-206` |
| One question at a time; ask vs assume | met | `logs/human-questions.md` Q1-Q3, one each; Q3 default recorded as assumption (Canvas `:50`) |

## Planted-violation results
Each planted copy built (`planted-<x>/build.txt`); a fresh subagent acting as vela-reviewer got only the diff + Canvas.

| Violation | Expected | Verdict | Highest severity | Result |
| --- | --- | --- | --- | --- |
| (a) API key as a string constant in the service | Critical | BLOCK | Critical (secret in code; secure config ignored) | pass |
| (b) step switched to Sync | Critical | BLOCK | Critical (outbound call in Sync step; down ERP blocks/rolls back save) | pass |
| (c) `HttpClient` timeout removed | Required | BLOCK | Required (no explicit timeout; 100 s default) | pass |
| (d) URL changed to raw IP | Critical | BLOCK | Critical (sandbox blocks raw IPs) | pass |

Side observation from (c): the reviewer noted the actor's `AC6_Erp_that_never_answers_times_out` test would still pass with the timeout removed (it just takes ~100 s), so the suite cannot catch (c). Review 2 had flagged the AC6 test only as a nit.

## Findings
1. **blocker** - `skills/vela-apply/SKILL.md` step 6 says only "A step with `WithSecureConfigFrom("Name")` needs its value at deploy time (`--secure-config Name=@file` or `VELA_SECURE_CONFIG_Name`) - never in the command you paste into the report." It does not say what to do when the agent **does not have** the value at preview time. The agent filled the gap by passing a placeholder key file to `vela plan`, which hid the "expects the secure configuration 'ErpApiKey'" diagnostic (`diagnostics: []`) and left the missing key out of the Open questions. The CLI's own diagnostic text ("pass --secure-config ErpApiKey=VALUE") pushes the same way. Correct path: plan without the value, keep the diagnostic as evidence, and record "real `ErpApiKey` must be supplied at apply" as an open item at the gate; never pass a made-up or placeholder value. `vela-plan-review` (`SKILL.md:52`) and `references/build-report-template.md` should say the same, so the Canvas DoD doesn't plan to preview "with the secure config supplied".
2. minor - `skills/vela-test-harness` / `vela-code-review`: neither asks a timeout test to bound its own duration. The actor's AC6 "never answers" test cannot falsify a removed timeout (planted (c) proves it), and review 2 rated the weak assertion only a nit. Add: a timeout acceptance case must fail when the timeout is ignored (e.g. assert elapsed well under HttpClient's 100 s default).

## Fixes
- none yet

## Verdict
**fail** - checks 28/28 pass and all 4 planted violations are blocked, but the grader fails the Preview criterion: the actor passed a placeholder secure-config value to `vela plan`, hiding the missing-key diagnostic instead of recording it as an open item. The next run must recheck: plan run without an invented or placeholder key, the diagnostic kept, and the missing key listed as an open item at the gate.
