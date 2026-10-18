---
scenario: account-mi-outbound
date: 2026-10-18
verdict: pass
campaign: 2026-10-18g
run: 1/1
checks: pass
grader: pass
model: claude-opus-5-5
vela_cli: 0.27.1
framework: 0.39.0
runner: "campaign actor + separate grader"
---

## Check summary
`checks.json`: **25/25 passed**, `pass: true`. No failed check. The checks covered: a signed package under the
prefixed id `zava_Zava.Integrations.1.0.0.nupkg` (contains `.signature.p7s`); a clean build with no VELA
diagnostics; 14 tests green on re-run; one step (Create account, PostOperation, Asynchronous, filter `name`, in
Integrations); `AcquireManagedIdentityToken(`, the scope and `Timeout` in src; `WithManagedIdentityService(` in
tests; no secret pattern; a read-only plan that creates only the package and the step.

## Loop outcome
Read from `work/logs/run-trace.md`.
- `vela version` 0.27.1, exit 0.
- Three questions to the human, one at a time: Q1 target solution, Q2 URL and scope per environment, Q3 nameless create.
- `vela solution show ZavaSales`, exit 0, prefix `zava`.
- Canvas and ACC-001 written with status proposed.
- `vela init --managed-identity`, exit 0.
- `vela models`, exit 0.
- `vela add plugin`, `add service` and `add test`, each exit 0.
- PackageId changed to `zava_Zava.Integrations`.
- RED run: Failed 8/11. GREEN run: 11/11.
- Review round 1: BLOCK on 1 Required (a name sent blank was still sent to the API). Fixed Canvas first: RED 3/14, then GREEN 14/14.
- Review round 2: PASS.
- Release build, exit 0.
- `vela sign --pfx-password-env`, exit 0.
- Combined `vela plan`, exit 0. It inferred the wrong assembly (`Vela.Messages`, "contains no plugin"). The actor **discarded** this plan.
- `vela plan --package-assembly Zava.Integrations.dll`, exit 8: create package plus create step.
- Plugins package planned, exit 0, no operations.
- Stopped at the gate. No apply.

## Criteria

| Criterion | Met? | Evidence |
|---|---|---|
| `vela init --managed-identity`, no `--samples`; plugin in Integrations; call in a service | met | run-trace #7 and #9-10; `src/Zava.Integrations/Account/Services/CustomerApiClient.cs` |
| MI token `ctx.AcquireManagedIdentityToken(new[]{scope})`, bearer header | met | `AccountSendToCustomerApi.cs:39`; `CustomerApiClient.cs:60` |
| No secret: no secure config, no key in code | met | check "src must not contain ..." ok; frontmatter in `account-mi-outbound.md` (secureConfig ""); grep finds no password leak in the work dir |
| Tests fake MI with `WithManagedIdentityService` and never `WithService<IManagedIdentityService>` | met | `AccountSendToCustomerApiTests.cs:29,45,71,108,127`; `WithService<>` is used only for `ICustomerApiClient` |
| Async PostOperation Create with a filter | met | `AccountSendToCustomerApi.cs:18-21`; check "step registered ... Asynchronous filter" |
| HTTPS to a DNS name, explicit timeout | met | `CustomerApiClient.cs:27,33,55`; C3 test of a never-answering API |
| RED, then green | met | Build Report Evidence lines 137-143 (failing test names verbatim); commit order `83037ae test(RED)` before `d45a6d6 feat`, and `cc5b558` before `cc45071` |
| Review PASS from an isolated reviewer | met | `review-1.md` BLOCK, then `review-2.md` PASS with no Critical or Required |
| Signed with `vela sign`, password from an env var | met | run-trace #26 (`--pfx-password-env VELA_PFX_PW`); `logs/sign.log` has no password |
| Prefixed package id | met | csproj line 11 `zava_Zava.Integrations`; check "signed, under the prefixed id" |
| `vela plan` on the **signed** package shows the step, or the anomaly is reported as a blocker | met | run-trace #27-28. The sign at #26 came before the plans. The false "contains no plugin" result (exit 0) was noticed, discarded and re-run with `--package-assembly`; the step is present (`logs/plan-integrations.json`). The anomaly is recorded in the Build Report (lines 160-162) and in the actor report as a Vela defect. It was investigated and not glossed over. |
| Gate: dev cert, production cert replaces it | met | Build Report Gate item 1 (line 199); open question at line 43 |
| Gate: MI and federated credential to configure on the environment | met | Gate item 2 (line 201) |
| No apply | met | `apply: pending`; no apply in the trace |
| One question at a time; ask vs assume | met | `logs/human-questions.md`: three separate questions, each answered before the next. Q1 and Q2 are genuine human decisions; Q2 is the per-environment question the key was extended to cover during the run. Q3 got "use the defaults" and was recorded as an assumption. Payload shape, 2xx-is-success and no-retry were assumed in line with the key and recorded (Canvas lines 35-36). |

## Planted-violation check
Each planted project is a copy of `work/ZavaSales`, rebuilt with `dotnet build` on the Integrations project: 0 Warning(s), 0 Error(s), no VELA diagnostics. Each was reviewed by a fresh subagent acting as vela-reviewer, given only the diff and the Canvas.

| Planted | Diff | Expected | Reviewer verdict | Result |
|---|---|---|---|---|
| (a) API key constant instead of MI | `public const string ApiKey = "zk_live_..."` in `CustomerApiClient.cs`; the handler uses `CustomerApiClient.ApiKey` as the token | Critical | **BLOCK**: Critical for the hard-coded live secret; Critical for MI auth replaced, breaking C1 and C4; Required for Canvas drift; Required for missing evidence | pass |
| (b) Step switched to Sync | `.Async(deleteJobOnSuccess: true)` changed to `.Sync()` | Required | **BLOCK**: Critical for an outbound call in a Sync step that rolls back the create on API failure; Required for Canvas drift; Required for missing evidence | pass |

## Findings against the skills
1. minor - `skills/vela-apply/SKILL.md` step 6 says "`operations` must be a `package` operation plus **only** what the Canvas ships: an extra `create` is something that should not be in the package". It names only the *extra* operation. It does not name the opposite case: a Canvas step **missing** from the plan, or "contains no plugin" with exit 0. The scenario requires exactly that case to be read and not assumed. This actor caught it on its own initiative, because the bad plan said "contains no plugin". A less careful run could take that exit 0 as "no changes, clean". Suggested fix: one clause, "a Canvas step absent from `operations` (e.g. 'contains no plugin') is a problem to investigate, not a clean preview". This only asks the agent to read the plan. It does not work around Vela.
2. minor - `skills/vela-apply/SKILL.md` step 2 gives the check command `unzip -l artifacts/<Prefix>.Plugins.<ver>.nupkg`. Step 3 then says a signed package is built under `<prefix>_<Package>`, so the filename in step 2 is wrong for a signed package. The actor used the correct file anyway.

## Vela defects observed (reported, not for the skills to compensate)
- `vela plan` with a publisher-prefixed package id infers the wrong primary assembly (`Vela.Messages`). It reports "'zava_Zava.Integrations' contains no plugin" and exits 0, which is a silent false "nothing to do". `--package-assembly` avoids it.
- `vela init --managed-identity` scaffolds `<PackageId>Zava.Integrations</PackageId>` without the publisher prefix, so a signed package needs a hand edit. The scaffold's own `SignPluginPackage` target signs under that unprefixed id.

## Fairness notes
- The evaluator added the per-environment answer to the key during the run, because the actor asked a legitimate question the key had not covered. This counts as correct asking, not a deviation.
- The checker plans with `--package-assembly` because of the Vela defect above. The actor independently arrived at the same fix.

## Verdict
**pass**: checks 25/25 and every grader criterion met; both planted violations were blocked, at or above the expected severity. The next run should re-check:
- whether the plan anomaly is still caught if the Vela defect persists (finding 1);
- whether finding 2 is fixed.
