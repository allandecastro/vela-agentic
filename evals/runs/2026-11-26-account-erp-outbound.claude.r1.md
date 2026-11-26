---
scenario: account-erp-outbound
date: 2026-11-26
verdict: pass
campaign: 2026-11-26
run: 1/1
checks: pass
grader: pass
model: claude-opus-5-5
vela_cli: 0.34.0
framework: 0.45.0
runner: "campaign actor + separate grader"
mutation: "15/21, 1 missing test"
---

## Check summary
`checks.json`: **29/29 passed**, no failed check. Highlights: step registered `Create account PostOperation/Asynchronous`
filter `[name]`, secure config `ErpApiKey`, in `Zava.Integrations`; exactly 1 authored step; both packages built
(`zava_Zava.Plugins`, `zava_Zava.Integrations`); no `http://`, no raw IP, no ERP URL constant in `src`; `WithSecureConfigFrom`,
`SecureConfig`, `Timeout`, `InvalidPluginExecutionException`, `GetEnvironmentVariable` present; tests re-run green
(total 20, 2 assemblies); read-only `vela plan` runs and creates only the authored package + step.

## Loop outcome
- intake: `vela version` 0 -> 0.34.0 (trace #1).
- challenge: 5 questions, one per message (logs/human-questions.md Q1-Q5); Canvas + rule ACC-001 + ADR 0001 committed 863bde6.
- scaffold: `vela solution show ZavaSales --json` 0; `vela init ZavaSales ... --integrations` 0 (trace #5).
- model: `vela models --entities account,environmentvariabledefinition,environmentvariablevalue --project src/Zava.Shared/...` 0 (trace #7-8), before `vela add plugin ... --project src/Zava.Integrations/Zava.Integrations.csproj` 0 (trace #9).
- RED 1: Total 16, Failed 13 (logs/red-Zava.Integrations.Tests.dll.log); GREEN 16/16.
- review r1: BLOCK (1 Required: runtime base URL not checked https). Fixed spec-first (c00def2 amendments C12/C13 -> 0306825 RED Total 20 Failed 4 (logs/red2.log) -> eedbb76 fix).
- GREEN 2: Total 20, Failed 0 (logs/green2-Zava.Integrations.Tests.dll.log); spec-check 0 failure(s) (logs/spec-check3.log).
- review r2: PASS, 0 Critical/Required, 4 Nits (.vela-runs/account-erp-outbound/review.md).
- package: `dotnet build -c Release` 0 Warning(s) 0 Error(s), two nupkgs (logs/build-release.log).
- plan: `vela plan -p artifacts/zava_Zava.Integrations.1.0.0.nupkg --solution ZavaSales ... --detailed-exitcode` exit 8 (changes), diagnostic "expects the secure configuration 'ErpApiKey', but none is set" kept as a gate item.
- gate: Build Report `status: awaiting-apply`; no `vela apply`.

## Criteria

| Criterion | Met? | Evidence |
| --- | --- | --- |
| Project: `vela init --integrations`, never `--samples` | met | trace.md #5; check "no scaffold demo registered" |
| Plugin in the Integrations project via `vela add ... --project src/<P>.Integrations` | met | trace.md #9; check "step registered ... in Integrations" |
| Models for `account` via `vela models` before the plugin | met | trace.md #7-8 before #9; commit 7f7ef9e |
| Async PostOperation Create with the reason | met | AccountPlugin.cs:22-24; Canvas README.md:83-84 (save never waits, failure never rolls it back, external side effect not in a Sync step) |
| Secret via `.WithSecureConfigFrom("ErpApiKey")` + `SecureConfig`; never in code/config/repo; no invented value | met | AccountPlugin.cs:26,50-64; tests use a fake `test-key-123` only; plan diagnostic kept (README.md:137-138) |
| Build Report says how the human supplies the key (`--secure-config Name=@file`) | met | README.md:151 (`--secure-config ErpApiKey=@<file holding the key>`), :160 |
| Sandbox: HTTPS to a DNS name | met | URL from env var, https enforced at runtime (AccountPlugin.cs:44, C12) |
| Explicit timeout well under 2 min | met | ErpAccountClient.cs:33,52 (10 s); C4 proves it against a never-answering transport (ErpAccountClientTests.cs:15-30) |
| Non-success / timeout -> `InvalidPluginExecutionException`, not swallowed | met | ErpAccountClient.cs:63-81; C2/C3/C4 tests |
| HTTP call in a service; no real network call; fake via `PluginPipeline.WithService<T>` | met | ErpAccountClient + ProjectServices.cs:24; AccountPluginTests.cs:263 `WithService<IErpAccountClient>(...)` over `FakeErpHandler`; no test-only seam in the plugin |
| Env-specific URL from `ctx.GetEnvironmentVariable`, asked at design, in Canvas, tests supply it | met | human-questions.md Q4; AccountPlugin.cs:37 (`TryGetEnvironmentVariable`); Canvas `environment_variables`, decisions; tests seed the variable (AccountPluginTests.cs:270-283) |
| Preview: two packages built; plan on every package the Canvas ships; empty Plugins package's exclusion recorded | met | build-release.log (2 packages); Canvas `packages:` + README.md:76,93-94,135 |
| Plan read-only; missing secure config recorded as open item, not "fixed" | met | README.md:137-138,160 |
| SC1 Canvas records Async PostOp Create + reason, Integrations, secure-config name, timeout | met | README.md:9,13,16,47,83-86 |
| SC2 Test-first RED->green: id+name JSON + `X-Api-Key`; non-success/timeout throws; step Async PostOp Create; no network | met | RED logs (13/16 failing, then 4/20); C1 `Created_Account_Is_Posted_...` asserts body + key; C2/C3/C4; `Fires_On_Create_PostOperation` asserts stage + mode through the pipeline |
| SC3 Build clean of VELA00x; `vela-code-review` PASS | met | build-release.log 0 Warning(s); review.md round 2 "Verdict: PASS" |
| SC4 Both packages built; `vela plan` on shipped package(s), read-only; Gate names how the key is supplied | met | see Preview rows; README.md:151 |
| One question at a time / ask vs assume | met | Q1-Q5 asked sequentially, each with a proposed default; timeout and Name edge recorded as assumptions after the human deferred (README.md:47-49) |

## Planted-violation check
Each violation applied to a copy (`planted-<x>/`, diffs in `planted-<x>.diff`), built in Release, then reviewed by a fresh
general-purpose subagent acting as `agents/vela-reviewer.agent.md` with the skills read from the worktree, given only the diff and the Canvas.

| # | Violation | Build | Reviewer verdict | Expected | Result |
| --- | --- | --- | --- | --- | --- |
| a | API key as a string constant in `ErpAccountClient` (`private const string ErpApiKey = "zk_live_..."`, sent in `X-Api-Key`) | 0 warnings, 0 VELA | BLOCK, **Critical** (secret in code; also Required: the secure-config value no longer reaches the header, C1) | Critical | blocked |
| b | `.Async(deleteJobOnSuccess: true)` -> `.Sync()` | 0 warnings, 0 VELA | BLOCK, **Critical** (outbound call from a Sync step without a Canvas reason: a down ERP rolls back the save; also Required: contradicts ADR 0001) | Critical | blocked |
| c | `{ Timeout = _timeout }` removed | 1 warning VELA026 | BLOCK, **Required** (no explicit timeout, VELA026; contradicts ADR 0001 and C4) | Required | blocked |
| d | URL -> `"https://20.50.1.10/api/accounts"` in the client | 0 warnings, **0 VELA** (VELA025 did not fire on the literal inside `Uri.TryCreate`) | BLOCK, **Critical** (raw IP, sandbox blocks it; also Required: env-specific URL as a constant) | Critical | blocked |

4/4 blocked at the expected severity or higher. Vela note for the user (not a pack defect): VELA025 missed a raw-IP
literal passed to `Uri.TryCreate(...)` (planted-d build: 0 VELA diagnostics); the review caught it and named the analyzer miss.

## Mutation triage
15 killed / 21 valid (2 invalid), score 0.71.

| Survivor | Verdict | Reason |
| --- | --- | --- |
| AccountPlugin.cs:37 `\|\|` -> `&&` | equivalent | an empty / missing value then fails at the https check (line 44), whose message also names `zava_ErpBaseUrl`; C8 behaviour (job fails naming the variable, nothing sent) is unchanged, only the text differs |
| AccountPlugin.cs:57 `>= 0` -> `> 0` | **missing test** | a key that **starts** with a line break (e.g. `"\nkey"`, what a file with a leading newline gives) passes the guard and `Headers.Add` throws `FormatException`, not an `InvalidPluginExecutionException` naming `ErpApiKey` - breaks ACC-001/C13. The C13 theory (AccountPluginTests.cs:240-241) has the break only at index > 0 |
| ErpAccountClient.cs:44 `\|\|` -> `&&` | equivalent | duplicate of the plugin's https guard (AccountPlugin.cs:44), which always throws first; reviewer r2 Nit #1 already flagged the duplicate as untested |
| ErpAccountClient.cs:46 drop throw | equivalent | same guard, unreachable through the plugin |
| ErpAccountClient.cs:52 `disposeHandler: true` -> `false` | equivalent | no declared behaviour changes (resource hygiene only; the fake handler's Dispose is a no-op) |
| ErpAccountClient.cs:61 `ConfigureAwait(false)` -> `true` | equivalent | no synchronization context in the sandbox or the harness |

The missing test is a boundary miss (index 0) on a review-driven amendment case; it goes against `vela-plugin-testing` only weakly (the skill does ask for boundary values; the actor picked two interior positions).

## Vela.Plugins 0.45.0 dependency (scoped `IDisposable` disposal)
Nothing in the output depends on it. `ProjectServices.cs:24` registers `AddScoped<IErpAccountClient>(_ => new ErpAccountClient(...))`:
a **new** instance per execution, and `ErpAccountClient` is **not** `IDisposable`; each call builds and disposes its own
`HttpClient` (ErpAccountClient.cs:52). No static instance anywhere. The tests hand `WithService<IErpAccountClient>(new ErpAccountClient(...))`
one non-disposable instance per pipeline; the only `IDisposable` (`FakeErpHandler`) is not a registered service and overrides
`Dispose` as a no-op on purpose (FakeErpHandler.cs:70-73). Both reviewer rounds checked this explicitly ("new non-disposable client
each time, with no static field").

## Findings against the skills
1. minor - `skills/vela-code-review/SKILL.md:49-50` says "A finding on a rule's text in `docs/rules/` is not fixed in the build: it goes to the Gate as an open item for the human", while `references/build-report-template.md` allows "a **review-driven amendment** (a new case id, a corrected sentence) listed in the Canvas `amendments:`". Round 1 deferred the rule-text Nit because of the first sentence; round 2 called the conflict out. The two must say the same thing (e.g. "except a review-driven amendment, listed in `amendments:`").
2. minor - `skills/vela-code-review/scripts/spec-check.cs:87` parses `^amendments:[ \t]*(\[...\]|(\r?\n[ \t]*-.*)+)`: a trailing YAML comment after `amendments:` (`amendments:   # ...`) makes the list unparsed and spec-check fails (trace.md #19). Either accept `[ \t]*(#.*)?` or say in the template that the key takes no comment.
3. minor (environment, not a skill line) - the round-1 reviewer read the installed plugin cache (`~/.claude/plugins/cache/vela-agentic/vela/0.1.7/...`) and wrongly reported `vela-plugin-testing` as non-existent (review.md r1 #5, closed in r2). The actor dispatched an installed reviewer that can lag the pack under test; the campaign should make the actor dispatch the reviewer from the pack under test.
4. minor - mutation survivor AccountPlugin.cs:57: the C13 boundary (line break at index 0) is untested; `vela-plugin-testing` could name "the first and last position" when a case rejects a character in a string.

## Verdict
**pass** - checks 29/29 and every criterion met; 4/4 planted violations blocked at the expected severity. No blocker
against the skills; four minor findings (a rule-text conflict between vela-code-review and the build-report template,
spec-check's fragile `amendments:` regex, an installed reviewer copy lagging the pack under test, one boundary-case
missing test). Nothing depends on the Vela.Plugins 0.45.0 scoped-`IDisposable` change (the factory returns a new,
non-disposable client per execution). Next run re-checks: VELA025 on a raw IP inside `Uri.TryCreate` (Vela side), and
that the actor's reviewer is the pack-under-test copy.
