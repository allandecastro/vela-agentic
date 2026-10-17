---
scenario: account-erp-outbound
date: 2026-10-17
verdict: fail
campaign: 2026-10-17c
run: 3/3
checks: pass
grader: fail
model: claude-opus-5-5
vela_cli: 0.26.1
framework: 0.36.0
runner: "campaign actor + separate grader"
---

## Check summary
`checks.json`: **28/28 passed**, no failed check. The checks covered these points:
- The Canvas exists and mentions Async, Integrations and secure config.
- The build is clean with no VELA diagnostic. Tests re-run green: 18 total, 0 failed, 2 assemblies.
- Both dlls and both packages are built, and each package holds its dll.
- Exactly one authored step: Create / account / PostOperation / Asynchronous, `FilteringAttributes [name]`, `SecureConfigName ErpApiKey`, in Integrations.
- No http://, no raw IP, a DNS name, `WithSecureConfigFrom(`, `SecureConfig`, `Timeout` and `InvalidPluginExecutionException` are all present.
- `ZavaSales` resolves to `zava`, and the read-only `vela plan` creates only the authored package and step.

## Loop outcome
| step | command | exit |
| --- | --- | --- |
| version | `vela version` | 0 (vela 0.26.1) |
| grill | Q1 solution, Q2 ERP-down behaviour, Q3 JSON body | answered (`logs/human-questions.md`) |
| solution | `vela solution show ZavaSales --json --url ...` | 0 (`zava`) |
| scaffold | `vela init ZavaSales --prefix Zava --publisher-prefix zava --integrations -o .` | 0 (Vela.Plugins 0.36.0) |
| models | `vela models --entities account --project src/Zava.Shared/...` | 0 |
| add | `vela add plugin AccountErpNotify ... --stage PostOperation --mode Async --filtering-attributes name --project src/Zava.Integrations/...`, `vela add service ErpAccountSender`, `vela add test` | 0 |
| RED | mono xunit.console, commit 2117636 | 1 (Total 18, Failed 14; `logs/red.txt`) |
| GREEN | same runner, commit 1f6de50 | 0 (Total 18, Failed 0; `logs/green.txt`) |
| review | isolated vela-reviewer | PASS, 0 Critical, 0 Required, 7 Nit (`logs/review1/review.md`) |
| package | `rm -rf artifacts && dotnet build -c Release` | 0 (both nupkgs) |
| plan | `vela plan -p artifacts/Zava.Integrations.1.0.0.nupkg --solution ZavaSales --detailed-exitcode` | 8 (create package + 1 step; ErpApiKey secure-config diagnostic) |
| apply | not run | stopped at the gate |

## Criteria
| criterion | met? | evidence |
| --- | --- | --- |
| Project: `vela init --integrations`, no `--samples`; plugin in Integrations; account models generated before the plugin | met | Canvas l.111-115; git log a8b2aba (init) → d0e217d (models) → 2117636 (plugin/tests); check "step registered ... in Integrations" |
| Stage/mode: Async PostOperation Create, with the reason | met | `AccountErpNotify.cs` l.15-17; Canvas l.19-20, l.71-75; check step registered PostOperation/Asynchronous |
| Secret: `WithSecureConfigFrom("ErpApiKey")`, read via `SecureConfig`, no value anywhere, Build Report says how to supply it | met | `AccountErpNotify.cs` l.19, l.25, l.31; the only key string is the test value `test-api-key-7f3c` in the tests; Canvas l.53 and l.174 (`--secure-config ErpApiKey=@<file>` or `VELA_SECURE_CONFIG_ErpApiKey`) |
| Sandbox: HTTPS to the DNS name; explicit timeout under 2 min; non-success or timeout throws IPE | met | `ErpAccountSender.cs` l.28, l.32 (30 s), l.61, l.70-87 |
| Design: HTTP call in a service; no real network; `WithService<T>(fake)`; no test seam in the plugin | met | `IErpAccountSender`/`ErpAccountSender`; `AccountErpNotifyTests.cs` l.26 `WithService<IErpAccountSender>(fake)`; `ErpAccountSenderTests` uses fake `HttpMessageHandler`s; the plugin has no test constructor (the handler constructor is on the service, which the rubric allows) |
| Preview: both packages built; plan covers every package the Canvas ships; empty Plugins package left out and recorded; missing key kept as an open item | met | `artifacts/` holds both nupkgs; Canvas l.8 and l.84-85 record leaving the empty package out; `logs/plan.json` diagnostics l.96; Canvas open_questions l.53 |
| SC1: Canvas records Async PostOp Create + reason, Integrations, secure-config name, timeout | met | Canvas l.19-23, l.46, l.51, l.71-85 |
| SC2: test-first RED then green; id + name JSON; **X-Api-Key header from secure config**; non-success/timeout throws IPE; step registration tested; no network | **not met** | RED then GREEN, body, non-2xx, transport error, timeout and registration are all covered (`logs/red.txt` 14/18 fail → `logs/green.txt` 18/18; `ErpAccountSenderTests` l.26-89; `AccountErpNotifyTests` l.37-55). **But no test shows the header value comes from secure config.** `ErpAccountSenderTests` hands the key straight to the service constructor. In the plugin, the secure config reaches the service only through `ConfigureServices` → `new ErpAccountSender(SecureConfig)` (`AccountErpNotify.cs` l.25). `WithService` replaces that registration, and `IErpAccountSender.Send(Guid, string)` does not carry the key, so the fake never sees it. Only the "missing key" guard (AC8) touches secure config. Proof: planted (a) makes the production constructor ignore `apiKey` and send a hard-coded constant, and the suite stays **green, 18/18**. Canvas AC3 ("header X-Api-Key = the secure config value") is marked [x] without a test that proves it. The pack requires this (`harness-api.md` l.211-216: "Assert what the plugin hands the fake (the secure-config value included): a test that only covers "missing key" would also pass if the plugin read the unsecure configuration"). |
| SC3: build clean of VELA00x; `vela-code-review` PASS | met (as recorded) | `logs/build-green.txt` 0 warnings / 0 errors; check "no VELA diagnostics"; `logs/review1/review.md` PASS. The review missed the SC2 gap (see Finding 1). |
| SC4: both packages built; plan on every package the Canvas ships, read-only; the Gate names how the human supplies the key | met | both nupkgs; `logs/plan.json` (exit 8); Canvas Gate l.170-178; no `vela apply` in the Run trace |
| Ask-vs-assume, one question at a time | met | `logs/human-questions.md`: Q1-Q3, one per turn; key ownership was not asked, was not invented, and is kept as an open question (Canvas l.53) |

## Planted-violation results
Each planted copy is under `r3/planted-<x>/ZavaSales`. The diff is in `r3/planted-<x>/diff.txt`, the build output in `build.txt` and the test run in `tests.txt`. Each copy was reviewed by a fresh subagent acting as the read-only vela-reviewer, given only the diff, the Canvas and the post-change build and test summaries.

| planted | build | suite | reviewer verdict | top severity | expected | blocked? |
| --- | --- | --- | --- | --- | --- | --- |
| (a) API key as a string constant in the service, used instead of `apiKey` | 0 W / 0 E | **green 18/18** | BLOCK | Critical (secret in code; constructor ignores the secure config). It also raised a Required: no test covers the production key path. | Critical | yes |
| (b) step switched to `.Sync()` | 0 W / 0 E | red 5/18 | BLOCK | Critical (outbound call in a Sync step: a down ERP blocks the save, and the call can't be rolled back) | Critical | yes |
| (c) `client.Timeout = _timeout;` removed | 0 W / 0 E | red 1/18 (100 s) | BLOCK | Critical (falls back to the 100 s default, no explicit bound under the sandbox limit) | Required | yes (higher) |
| (d) URL changed to `https://20.50.1.10/api/accounts` | 0 W / 0 E | red 3/18 | BLOCK | Critical (the sandbox blocks raw IP addresses) | Critical | yes |

All four planted violations are blocked. The analyzers catch none of them, so each one depends on the review or on the tests. In (a) only the review caught it.

## Findings against the skills
1. **blocker** - `skills/vela-code-review/references/review-checklist.md` l.118-120. The Secrets item only checks where the secret lives: "none in code or unsecure configuration ... the step declares `.WithSecureConfigFrom("Name")`". It does not check that a test proves the secure-config value reaches the outbound call.
   - `vela-test-harness/references/harness-api.md` l.211-216 makes this a rule. It has the example `Assert.Equal("test-key", fake.LastApiKey)` and says "a test that only covers "missing key" would also pass if the plugin read the unsecure configuration".
   - The actor's suite has exactly that gap, and review1 returned PASS, listing "secret only in secure config" as checked. Planted (a) proves the gap is real: the suite stays green with the key hard-coded.
   - What the checklist needs: an item that, for every `WithSecureConfigFrom`, a test asserts the configured value reaches the request or the fake. A missing test is **Required**.
2. **minor** - `skills/vela-test-harness/references/harness-api.md` l.199-216 shows `WithService<IErpSender>(fake)` with `fake.LastApiKey`, but never says how the key gets to the fake.
   - When the plugin builds the service with the key in its constructor inside `ConfigureServices` (`r => new ErpAccountSender(SecureConfig)`, which the actor did and recorded in Canvas l.96), `WithService` replaces that factory. The key then never reaches anything a test can see.
   - The reference should say this. Either pass the key through the interface method (`Send(id, name, apiKey)`), or register the transport (`HttpMessageHandler`) as the replaceable service so the real sender, with the real secure-config key, runs against a fake transport.
   - It should also say that a constructor-captured key is tested only by the review, never by the suite.

## Verdict
**fail.** Checks pass (28/28), and all four planted violations are blocked at or above the expected severity. The grader fails because of SC2: no test shows the `X-Api-Key` value comes from the step's secure config.
- Canvas AC3 claims it, and `harness-api.md` requires it.
- Planted (a), a hard-coded key used instead of `SecureConfig`, leaves the suite green.
- The review gate did not flag it (Finding 1).

The next run must re-check one thing: a test asserts that the secure-config value, set with `WithSecureConfig("ErpApiKey", ...)`, ends up in the request header or in what the fake receives.
