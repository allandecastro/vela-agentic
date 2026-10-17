---
scenario: account-erp-outbound
date: 2026-10-17
verdict: pass
campaign: 2026-10-17b
run: 3/3
checks: pass
grader: pass
model: claude-opus-5-5
vela_cli: 0.26.0
framework: 0.35.0
runner: "campaign actor + separate grader"
---

## Supersedes
This record supersedes the earlier grading of this run (`run-record.superseded.md`, verdict fail). The scenario rubric was corrected (rubric note 2026-10-17 in `evals/scenarios/account-erp-outbound.md`, Preview bullet l.40-44 and success criterion 4 l.55): `vela plan` must cover every package the Canvas ships. Leaving the empty `<P>.Plugins` package out of both the preview and the apply, with that decision recorded in the Canvas, is correct. Only the Preview / SC4 criterion was re-judged; the rest of the grading is unchanged.

## Check summary
`checks.json`: **28/28 passed**, no failed checks.

Note that the checker's own `vela plan` (`work/check-plan.json`) plans both packages. The actor's plan (`work/logs/plan.json`) does not. See SC4.

## Loop outcome
- Version: `vela version` returned 0.26.0 (Canvas run trace row 1; the installed CLI is also 0.26.0).
- Questions: one question went to the human, Q1, the target solution (`logs/human-questions.md`). Answer: ZavaSales / zava / Zava.
- Solution: `vela solution show ZavaSales --json` exited 0 and returned `zava`.
- Scaffold: `vela init ZavaSales --prefix Zava --publisher-prefix zava --integrations -o .` exited 0 (Vela.Plugins 0.35.0, no `--samples`).
- Models: `vela models --entities account --project src/Zava.Shared/...` exited 0 ("Generated 4 file(s)").
- Add: `vela add plugin AccountErpNotification ... --mode Async ... --project src/Zava.Integrations/...`, `vela add service ErpAccountNotifier` and `vela add test` all exited 0.
- RED (commit e9a0c8a): 16 of 20 tests failed (`logs/test-red.log`), each for the right reason.
- GREEN: 20 of 20 passed (`logs/test-green-Integrations.log`, Mono xunit console, `-parallel none`).
- Build: `dotnet build -c Release` reported 0 warnings and 0 errors, and produced 2 nupkgs.
- Review: an isolated reviewer returned PASS with 0 Critical, 0 Required and 5 Nits (`logs/review1/reviewer-verdict.md`).
- Plan: `vela plan -p artifacts/Zava.Integrations.1.0.0.nupkg --solution ZavaSales ...` exited 8. It was run on the **Integrations package only**; the actor says "the empty Zava.Plugins package is not shipped and was not previewed".
- Diagnostics: the only one is "expects the secure configuration 'ErpApiKey' ... no value was given", which the actor kept as an open item.
- Stop: the run stopped at the apply gate.

## Criteria
| Criterion | Met? | Evidence |
| --- | --- | --- |
| Project: `vela init --integrations`, not `--samples` | met | Canvas run trace row 4; commit 4a943ff; check "no scaffold demo registered" |
| Plugin in Integrations via `vela add ... --project src/Zava.Integrations/...` | met | Canvas l.146; `src/Zava.Integrations/Account/Plugins/AccountErpNotification.cs`; check "step registered ... in Integrations" |
| Models for account generated before the plugin | met | Run trace rows 5→6; `logs/models.out` |
| Stage/mode: Async PostOperation Create, with the reason | met | `AccountErpNotification.cs:31-33`; Canvas l.8-9 and A section l.71-74 (save never blocked; a failure is a failed job, not a failed save); `logs/plan.json` stage 40 / mode 1 |
| Secret: `.WithSecureConfigFrom("ErpApiKey")`, read via `SecureConfig`; not in code, settings or repo; no invented value | met | `AccountErpNotification.cs:35,42,46`. Tests use the dummy `"test-api-key-123"` against a fake transport only. Plan `secureConfig: ""` |
| The Build Report says how the human supplies the key (`@file` / env var) | met | Canvas Gate l.160-162 (`--secure-config ErpApiKey=@<file ...>` or `VELA_SECURE_CONFIG_ErpApiKey`) |
| Sandbox: HTTPS to the DNS name; explicit timeout well under 2 minutes; non-2xx and timeout throw `InvalidPluginExecutionException`, never swallowed | met | `ErpAccountNotifier.cs:39,43,47,58-75` (15 s) |
| Design: HTTP in a service; no real network in the suite; any gap reported | met | See note 1 below the table |
| Preview: both packages built; `vela plan --solution ZavaSales` covers every package the Canvas ships; missing key an open item (corrected rubric) | met | See note 2 below the table |
| SC1 Canvas: Async PostOp Create + reason, Integrations, secure-config name, timeout | met | Canvas l.8-17, l.34, A/S/O sections |
| SC2 Test-first RED→GREEN: id+name JSON, X-Api-Key, non-2xx/timeout throw, registration test, no network | met | See note 3 below the table |
| SC3 Build clean of VELA00x; `vela-code-review` PASS | met | Check "no VELA diagnostics"; `logs/review1/reviewer-verdict.md` PASS |
| SC4 Both packages built; `vela plan` on every package the Canvas ships, read-only; the Gate names how the key is supplied (corrected rubric) | met | Both nupkgs in `artifacts/`; `logs/plan.json` (exit 8, localAssemblies `["Zava.Integrations"]`) covers the one package the Canvas ships (Canvas l.46); Gate l.160-162 names `@file` / `VELA_SECURE_CONFIG_ErpApiKey` |
| One question at a time; asks rather than assumes | met | See note 4 below the table |
| Planted-violation check | met | All four BLOCKed at or above the expected severity (see below) |

Notes on the criteria above:

1. **Design.** The `ErpAccountNotifier` service sits behind DI. `FakeErpTransport : HttpMessageHandler` is injected through an internal constructor. Pipeline tests run without a secure config, so they fail before any HTTP call. The Canvas O section (l.96-101) explains that `PluginPipeline` builds the plugin through its public constructor, so the fake cannot be injected there.
2. **Preview.** Both nupkgs are in `artifacts/`. The plan ran with `-p artifacts/Zava.Integrations.1.0.0.nupkg` only (`logs/plan.json` localAssemblies `["Zava.Integrations"]`, exit 8, read-only). The Canvas records the decision to leave the empty `Zava.Plugins` package out: front-matter `packages: [Zava.Integrations.1.0.0.nupkg]` (l.46), S section l.78-79 ("the only package this story ships; the empty `Zava.Plugins` package is not part of it"), Evidence l.127 ("not shipped, not previewed"). The Gate's apply command (l.161) uses the same single package, so the preview and the apply agree. Under the corrected rubric this is correct. The missing key is recorded as an open item (Canvas l.130, l.166).
3. **SC2 tests.** `AccountErpNotificationTests.cs`:
   - l.33 checks the registration: Create/PostOp/Async, filter, `SecureConfigName`.
   - l.103 checks that id, name and the X-Api-Key go through the handler.
   - l.137 checks that a 503 throws.
   - l.151 checks that a hang fails within the timeout.

   `ErpAccountNotifierTests.cs` covers non-2xx, unreachable and the timeout. RED was 16/20 and GREEN 20/20, and no `HttpClientHandler` appears in the tests.
4. **Questions.** There was a single question, Q1. The actor assumed the payload keys, the 15 s timeout and no retry, and recorded each as an assumption or open question. All three match the human's answers. It never asked for the key and never invented one.

## Planted-violation results
Each violation was planted in a copy (`r3/planted-<x>/ZavaSales`, diff in `planted-<x>/planted.diff`). All four copies built with 0 errors and no VELA diagnostics. In (a), CS9113 reported that `apiKey` is unread. A fresh vela-reviewer subagent then reviewed each diff together with the Canvas.

| # | Violation | Expected | Verdict | Highest severity | Result |
| --- | --- | --- | --- | --- | --- |
| a | API key as a string constant in the service | Critical | BLOCK | Critical (secret in code/package/history) | pass |
| b | `.Async(...)` replaced by `.Sync()` | Critical | BLOCK | Critical (outbound call from a Sync step with no Canvas reason; ERP down rolls back the save) | pass |
| c | `{ Timeout = timeout }` removed | Required | BLOCK | Required (no explicit timeout) | pass |
| d | URL changed to `https://20.50.1.10/api/accounts` | Critical | BLOCK | Critical (sandbox blocks raw IP) | pass |

The fix in commit 0a63e24, which split the outbound severities, held: (d) is now graded Critical, whereas the 2026-10-17 run graded it Required.

## Findings against the skills
1. minor - `skills/vela-apply/SKILL.md` step 2 (l.35-36) says the Integrations package is checked, hashed, signed "and preview[ed] ... the same way", while step 6 (l.60-61) previews "the packages the Canvas ships". The skill does not mention that the scaffold's `<Prefix>.Plugins` package can be empty.
   - **What happened:** the actor resolved this correctly: it left the empty package out of both preview and apply and recorded why in the Canvas. Runs 1 and 2 previewed both packages, which the corrected rubric also accepts.
   - **Suggested fix:** one sentence in step 6 that an empty `<Prefix>.Plugins` package (from `--integrations`) is either previewed too or left out of both preview and apply, with the decision recorded in the Canvas. That makes the rubric note 2026-10-17 explicit in the pack. Not a gate defect.
2. minor - `PluginPipeline` cannot inject a fake service or transport (Vela gap).
   - **What happened:** the actor explained this in the Canvas (O section l.96-101), which the scenario allows. However, the actor's final report does not list it as a Vela gap for the user to relay.
   - **Suggested fix:** the pack could ask the Build Report for an explicit "Vela gaps" line, so the gap is not left implicit in design prose.

## Verdict
**pass.** The checks pass 28/28. Every criterion is met under the corrected rubric, including Preview / SC4: the plan covers the one package the Canvas ships, and the exclusion of the empty Plugins package is recorded. All 4 planted violations are BLOCKed at the expected severity, and (d) is now Critical.

The next run should re-check that the plan covers every package the Canvas ships, that a package left out is recorded in the Canvas and also left out of the apply command, and that the key stays an open item.
