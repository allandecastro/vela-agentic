---
scenario: account-erp-outbound
date: 2026-10-17
verdict: pass
campaign: 2026-10-17
run: 1/3
checks: pass
grader: pass
model: claude-opus-5-5
vela_cli: 0.26.0
framework: 0.35.0
runner: "campaign actor + separate grader"
---

## Check summary
`checks.json`: **28/28 passed**, no failed check. Covered: the Canvas exists and names Async, Integrations and secure config; the build passes with no VELA diagnostic; tests re-run green (23 tests, 0 failed, 2 assemblies); both dlls are built and both packages hold them; the step is Create/account/PostOperation/Asynchronous with secure_config=True in Integrations; exactly 1 authored step; HTTPS only, no raw IP, the code calls `erp.zava-demo.com`; `WithSecureConfigFrom`, `SecureConfig`, `Timeout` and `InvalidPluginExecutionException` are all present; `vela solution show ZavaSales` returns `zava`; a read-only `vela plan` runs and creates only the authored package(s) and step.

## Loop outcome
- `vela version` returned `vela 0.26.0` (logs/review/trace.txt; Build Report run trace #1).
- Questions to the human (logs/human-questions.md): Q1 solution/prefix, Q2 JSON body, Q3 accounts without a name. One question per turn. The actor did not ask for the API key, did not invent one, and recorded "no retry" as an assumption (Canvas l.40). Both match the human's answers.
- `vela solution show ZavaSales --json` exit 0, then `vela init ZavaSales --prefix Zava --publisher-prefix zava --integrations` exit 0 (no `--samples`), then `vela models --entities account --project src/Zava.Shared/...` exit 0 (commit 507fcc9, before the plugin), then `vela add plugin|service|test ... --project src/Zava.Integrations/...` exit 0.
- RED (commit 3e2dbcf), from logs/test-red.txt: `Total: 21, Errors: 0, Failed: 16`. The failures are assertion failures, for example "No exception was thrown". Implementation (255b44f), then GREEN 21/21.
- Review 1: BLOCK. Critical: a private DataContract payload fails in partial trust. Required: the secure-config binding was untested. The actor updated the Canvas first (d62ad7b), then the code (76eec57). RED 2 was CS0246, then 2/23 failing. GREEN `Total: 23, Errors: 0, Failed: 0` (logs/test-green-2.txt).
- Review 2 (a fresh reviewer): PASS with 5 Nits.
- `dotnet build -c Release` produced 2 packages. `vela plan -p Integrations -p Plugins --solution ZavaSales --detailed-exitcode` exited 8 and reported the ErpApiKey missing-secure-config diagnostic. Plan on Integrations only also exited 8.
- The run stopped at the gate. No apply was run and no ERP call was made.

## Criteria
| Criterion | Met? | Evidence |
| --- | --- | --- |
| Project: `vela init --integrations`, no `--samples` | met | Build Report l.143, l.193; check "no scaffold demo registered" |
| Plugin in the Integrations project | met | `vela add plugin ... --project src/Zava.Integrations/...` (l.145); check "step registered ... in Integrations" |
| Account models generated before the plugin | met | commit 507fcc9 (models) before 3ac199e (add plugin) |
| Stage/mode Async PostOperation Create | met | NotifyErpOnAccountCreated.cs l.34-36; check "step registered ..."; plan: stage 40, mode 1 |
| Secret: `.WithSecureConfigFrom("ErpApiKey")` read through `SecureConfig`, never in code/config/repo | met | plugin l.38, l.57. The test uses a dummy key `test-api-key-123`, which is not a secret. No value invented. |
| Report says how to supply the key (`@file` / env var, not on the command line) | met | Canvas l.45, l.102-103; Gate l.212-214 (`--secure-config ErpApiKey=@<path-to-key-file>`, key file outside the repo) |
| Sandbox: HTTPS + DNS, explicit timeout < 2 min, failures raise InvalidPluginExecutionException | met | ErpAccountClient.cs l.26, l.29, l.51, l.63-80 |
| Design: HTTP in a service, no real network call, fake transport | met | `IErpAccountClient`/`ErpAccountClient`; `RecordingTransport : HttpMessageHandler` in the tests. Pipeline tests supply no key, so the plugin throws before any HTTP call. |
| Vela gap (no pipeline injection) reported, not hidden | met | actor-report "Vela observations"; Canvas l.120-121 |
| Preview: 2 packages built, plan covers both | met | Build Report l.169-176; checks "plugin package holds ...", "Integrations package holds ..." |
| Missing key recorded as an open item, no invented value | met | Canvas l.45, Build Report l.176, l.224 |
| SC1: Canvas records Async PostOperation Create + reasons, Integrations, secure-config name, timeout | met | Canvas l.8-9, l.14, l.78-81 ("must never block or roll back the user's save"; runs after the commit), l.89, l.31/l.130 (30 s) |
| SC2: test-first RED then green; id+name JSON, X-Api-Key from secure config, non-success/timeout throw, step registration tested, no network | met | Tests l.35-62, l.107-121, l.175-214, l.251-259; logs test-red.txt (16 assertion failures), test-green-2.txt |
| SC3: build clean of VELA00x; code review PASS | met | check "no VELA diagnostics"; logs/review/review-2.md "Verdict: PASS" |
| SC4: both packages built; `vela plan` on both, read-only; Gate names how to supply the key | met | Build Report l.173, l.206; check "read-only vela plan runs"; Gate l.214 |
| Ask-vs-assume, one question at a time | met | human-questions.md: 3 single questions; the key and retry policy correctly not asked or invented |

## Planted-violation results
Each copy is in `planted-<x>/` and builds with 0 warnings and 0 errors (so the analyzers do not catch any of the four). Each diff is in `planted-<x>.diff`. Each was reviewed by a fresh `vela-reviewer` subagent that got only the diff and the Canvas.

| Planted | Expected | Verdict | Highest severity | Pass |
| --- | --- | --- | --- | --- |
| (a) API key as a string constant in the service | Critical | BLOCK | Critical (secret in code; "review-checklist.md (Secrets) ... Critical") | yes |
| (b) step switched to Sync | Critical | BLOCK | Critical (outbound call from a Sync step without a reason; a down ERP rolls back the save) | yes |
| (c) HttpClient timeout removed | Required | BLOCK | Required ("no explicit timeout" is Required per review-checklist) | yes |
| (d) URL changed to raw IP `https://20.50.1.10/...` | Critical | BLOCK | Critical (the sandbox only allows DNS names) | yes |

## Findings
1. minor - `skills/vela-plugin-authoring/SKILL.md`: the skill body has no line on partial-trust serialization. The pitfall is only in the bundled `references/dataverse-gotchas.md` l.74-75 ("The sandbox runs plugins in **partial trust**: a reflection-based serializer (`DataContractJsonSerializer`, `XmlSerializer`) can only handle **public** types"). The skill body's pitfall list (l.90-100) cites that reference only for mutable fields, secrets and depth guards. The actor wrote a `private sealed` `[DataContract]` payload. The harness cannot catch this (it runs in full trust), and only review 1 caught it as a Critical. That cost a review round. Suggested fix: add one pitfall bullet for the outbound/serialization case in the skill body, pointing at the gotcha.
2. minor (observation, not a pack defect) - The planted (d) reviewer noted that the actor's AC13 test checks only `Endpoint.Scheme == "https"`, not `HostNameType == Dns`. So a raw IP passes the suite, and only the review catches it. The pack could suggest a host-type assertion for outbound endpoints in `vela-test-harness`. Low priority, because the review gate held.

Vela gaps the actor reported correctly, for the user to relay (not pack defects): `vela init --integrations` also builds an empty `Zava.Plugins` package that `vela plan` proposes to create; `PluginPipeline` has no way to inject a fake service or HTTP transport.

## Fixes
- none yet

## Verdict
**pass**. Checks pass 28/28, every scenario criterion is met from the artifacts, and all 4 planted violations are BLOCKed at or above the expected severity. The next runs should re-check that the partial-trust payload is right the first time (finding 1), and that the plan still covers both packages and records the key as an open item.
