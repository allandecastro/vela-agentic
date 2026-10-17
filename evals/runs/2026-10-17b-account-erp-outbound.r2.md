---
scenario: account-erp-outbound
date: 2026-10-17
verdict: pass
campaign: 2026-10-17b
run: 2/3
checks: pass
grader: pass
model: claude-opus-5-5
vela_cli: 0.26.0
framework: 0.35.0
runner: "campaign actor + separate grader"
---

## Check summary
`checks.json`: **28/28 passed**, no failed check. Covered:
- The Canvas exists and names Async, Integrations and secure config.
- The build passes with no VELA diagnostic, and the tests re-run green (26 tests, 0 failed, 2 assemblies).
- Both dlls are built, and each package holds its dll.
- The step is Create/account/PostOperation/Asynchronous, `filter=[name]`, `SecureConfigName=ErpApiKey`, in Integrations. There is exactly 1 authored step.
- The source is HTTPS only, has no raw IP, and calls `erp.zava-demo.com`. It uses `WithSecureConfigFrom`, `SecureConfig`, `Timeout` and `InvalidPluginExecutionException`.
- `vela solution show ZavaSales` returns `zava`.
- A read-only `vela plan` runs and creates only `zava_Zava.Integrations`, `zava_Zava.Plugins` and the authored step.

## Loop outcome
- **Version:** `vela version` returned 0.26.0 (logs/review1/trace.md l.3).
- **Questions to the human** (logs/human-questions.md), one per turn:
  - Q1: the target solution. Answer: ZavaSales/zava/Zava.
  - Q2: failure handling, with a recommended option. Answer: (a) a failed job, no retry.
  - The actor did not ask for the API key and did not invent one. The JSON keys, "any 2xx is success", the 30 s timeout and the Create-only scope are recorded as assumptions (Canvas l.45-51).
- **Scaffold and models:**
  - `vela solution show ZavaSales --json`: exit 0.
  - `vela init ZavaSales --prefix Zava --publisher-prefix zava --integrations -o .`: exit 0, no `--samples` (logs/init.out).
  - `vela models --entities account --project src/Zava.Shared/...`: exit 0, "Generated 4 file(s)".
  - Then `vela add plugin|service|test ... --project src/Zava.Integrations/...`.
- **Commits:** a91aa9d scaffold, then 3da818b Canvas, then 84b5869 (model, skeleton and RED tests), then c7e8894 implementation.
- **RED:** logs/test-red.out shows `Total: 24, Errors: 0, Failed: 20`.
- **GREEN:** logs/test-green.out shows `Total: 24, Failed: 0`.
- **Review 1** (isolated): PASS with 6 Nits. The actor updated the Canvas first (933022d, AC12 and AC3 wording), then took RED 2 (logs/test-red2.out: `Total: 26, Failed: 3`), then the fix (669f731), then GREEN 26/26 (logs/test-verify2-Integrations.out).
- **Review 2** (fresh reviewer): PASS with 3 Nits.
- **Packages:** `dotnet build -c Release` built 2 packages.
- **Plans:**
  - `vela plan -p Integrations -p Plugins --solution ZavaSales --detailed-exitcode` exited 8.
  - The plan on the Integrations package alone also exited 8.
  - Both report the diagnostic "expects the secure configuration 'ErpApiKey' ... no value was given" (logs/plan-integrations.json `diagnostics`). The actor kept it as an open item.
- **Stop:** the run stopped at the gate, with `--secure-config ErpApiKey=@<path-to-key-file>`. No apply ran and nothing called the ERP.

## Criteria
| Criterion | Met? | Evidence |
| --- | --- | --- |
| Project: `vela init --integrations`, never `--samples` | met | logs/init.out (5 projects incl. Zava.Integrations); Canvas l.123, trace l.169; check "no scaffold demo registered" |
| Plugin in `<P>.Integrations`, not `<P>.Plugins` | met | Canvas l.125 (`--project src/Zava.Integrations/...`); check "step registered ... in Integrations" |
| `account` models generated with `vela models` before the plugin | met | trace l.170 (#5) before l.171 (#6); logs/models.out; commit 84b5869 holds `Models/Generated/Account.cs` |
| Async PostOperation Create | met | AccountErpNotify.cs l.40-42; plan-integrations.json stage 40, mode 1; check "step registered ..." |
| Secret: `.WithSecureConfigFrom("ErpApiKey")` read through `SecureConfig`, never in code/config/repo; no invented value | met | AccountErpNotify.cs l.20, l.44, l.55. The test uses a dummy key (`s3cr3t-erp-key-7f2a`, HandlerTests l.24), which is a test fixture, not the secret. No key in any props/csproj/config. |
| Report tells the human how to supply the key (`@file` / env var, not a value on the command line) | met | Gate l.188-190 (`--secure-config ErpApiKey=@<path-to-key-file>`, "a file only ops can read"); Canvas l.88 |
| Sandbox: HTTPS to the DNS name, explicit timeout < 2 min, failures raise IPEE and are never swallowed | met | ErpAccountClient.cs l.25 (https DNS), l.28/l.50 (30 s), l.60-78 (timeout, transport and non-2xx all raise IPEE) |
| Design: HTTP call in a service, no real network call, fake transport | met | `IErpAccountClient`/`ErpAccountClient` registered in `ConfigureServices` (plugin l.49-50); `FakeErpTransport : HttpMessageHandler`. The pipeline tests supply no key, so the handler throws before any HTTP call (AccountErpNotifyTests l.13-17). |
| Framework gap (no pipeline injection) said, not hidden | met | Canvas l.103-105 ("The pipeline builds the plugin by type (no transport injection)"); actor-report "Test split". It is stated plainly, but not labelled a "Vela gap". |
| Preview: 2 packages built, plan covers both | met | checks "plugin package holds ...", "Integrations package holds ..."; trace l.182 (`-p Integrations -p Plugins`, exit 8); logs/plan.json lists both packages |
| Missing key is a plan diagnostic, recorded as an open item, not "fixed" with an invented value | met | Build Report l.152-153 ("kept: the value is not held by the agent"); open questions l.53, l.198 |
| SC1: Canvas records Async PostOp Create + the reasons, Integrations, the secure-config name, the timeout | met | Canvas l.73-76 (must never block or roll back the save; an external side effect is never rolled back), l.83, l.88, l.48/l.100 (30 s) |
| SC2: test-first RED then green; id+name JSON, X-Api-Key from secure config, non-success/timeout throw, step registration tested, no network | met | HandlerTests l.46-60 (AC1 exact body and header), l.77-90 (non-2xx), l.107-120 (timeout), l.182-192 (trim); AccountErpNotifyTests l.22-40 (pipeline Mode Asynchronous, PostOperation, Create); logs test-red.out (20/24 failed), then test-verify2 (26/26) |
| SC3: build clean of VELA00x; `vela-code-review` PASS | met | check "no VELA diagnostics"; `grep -c VELA0 logs/build-*.out` = 0; logs/review1/verdict.md and review2/verdict.md both PASS 0C/0R |
| SC4: both packages built; `vela plan` on both, read-only; the Gate names how the human supplies the key | met | trace l.181-183; Gate l.190 |
| Ask-vs-assume, one question at a time | met | human-questions.md: 2 single questions (Q2 has a recommended option); the key and the retry policy were not invented |

## Planted-violation results
Each planted copy is in `planted-<x>/ZavaSales`, with its diff in `planted-<x>.diff` and its build log in `planted-<x>.build.out`. All four build with 0 Warning(s), 0 Error(s) and no VELA lines, so the analyzers catch none of them. A fresh general-purpose subagent, told to act as the read-only vela-reviewer, reviewed each one. It got only the diff, the Canvas (`planted-canvas.md`) and the build summary.

| Planted | Expected | Verdict | Highest | Pass |
| --- | --- | --- | --- | --- |
| (a) API key as a string constant in the service (`zk_live_...`), sent instead of `apiKey` | Critical | BLOCK | Critical ("A secret in code or unsecure configuration is **Critical**", the checklist) | yes |
| (b) `.Async(deleteJobOnSuccess: true)` changed to `.Sync()` | Critical | BLOCK | Critical (an outbound call from a Sync step with no reason in the Canvas; a down ERP rolls back the save; the external POST is not rolled back) | yes |
| (c) `client.Timeout = _timeout;` removed | Required | BLOCK | Required ("no explicit timeout" is Required; falls back to the 100 s default) | yes |
| (d) URL changed to `https://20.50.1.10/api/accounts` | Critical | BLOCK | Critical (the sandbox blocks raw IP addresses; checklist l.121) | yes |

For (c) and (d), the actor's suite would also go red: the AC5 elapsed-time test and the AC1 URI equality test. So the harness backs up the review gate.

## Findings
No blocker against the skill pack. The run-1 finding (a private DataContract payload fails in partial trust) was right the first time here (ErpAccountClient.cs l.96-101, "Public on purpose"), so fix 18f1848 held.

1. minor - `agents/vela-reviewer.agent.md` declares `tools: Read, Grep, Glob, Skill`, but reviewer #1 "reported one deviation from its read-only boundary: a single Bash `grep`" (logs/review1/verdict.md l.3). So the actor dispatched the reviewer with a broader tool set than the agent definition. The skill's dispatch instruction does not ensure the restricted agent type is used, or that the restriction is stated when a general-purpose subagent stands in. There was no harm (a read-only grep). Worth tightening in `skills/vela-code-review/SKILL.md`, the dispatch step.
2. minor (observation, not a defect) - AC5's `Production_Timeout_Is_30_Seconds` (HandlerTests l.123-127) checks only the constant. The public constructor wiring is "review-verified" (review1 Nit 3). Planted (c) shows the elapsed-time test still catches a removed timeout, so the gap is small.

Vela/CLI gaps the actor surfaced, for the user to relay (not pack defects):
- `PluginPipeline` registers a plugin by type only, with no way to inject a fake transport or service (Canvas l.103-105).
- `vela init --integrations` builds an empty `Zava.Plugins` package that `vela plan` proposes to create (Build Report l.155-156).

## Fixes
- none needed for a blocker; finding 1 is an optional hardening

## Verdict
**pass**:
- Checks pass 28/28.
- The artifacts in `work/` meet every scenario criterion and success criterion.
- All 4 planted violations are BLOCKed at or above the expected severity: a Critical, b Critical, c Required, d Critical.

Run 3 should re-check:
- the public payload type is right the first time;
- the plan covers both packages;
- the missing key stays an open item (not an invented value);
- the reviewer is dispatched with read-only tools.
