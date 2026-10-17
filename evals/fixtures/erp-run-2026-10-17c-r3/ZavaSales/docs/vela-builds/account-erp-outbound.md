---
kind: vela-build
slug: account-erp-outbound
date: 2026-10-17
status: awaiting-apply     # Canvas never human-approved beyond the grill answers; no apply has run
vela_cli: 0.26.1
framework: 0.36.0
packages: [Zava.Integrations.1.0.0.nupkg]   # Zava.Plugins.1.0.0.nupkg is empty (nothing of this story) - left out of preview and apply
package_sha256: 5f31628c6adfb5bdda3e8790b395d7cdae8f95be24a802641b5c8e7fa3b4790d
signed: unknown            # no certificate held by the agent; whether the org requires signing is an open question
harness: pass
analyzers: clean
review: pass
plan_preview: changes
plan_command: "vela plan -p artifacts/Zava.Integrations.1.0.0.nupkg --solution ZavaSales --url https://dyn-premium-dev.crm.dynamics.com --detailed-exitcode --out ../logs/plan.json"
apply: pending
entity: account
message: Create
stage: PostOperation       # needs the new record id; the outbound call happens after the save
mode: Asynchronous         # Async(deleteJobOnSuccess: true): ERP down never blocks the save; a failure stays as a failed system job
filtering_attributes: [Name]
images: []
secure_config: ErpApiKey   # WithSecureConfigFrom("ErpApiKey") - the X-Api-Key value, supplied by the deployer at apply
reuse: new-plugin          # AccountErpNotify (Integrations project) - no Account plugin exists
service: new:ErpAccountSender   # IErpAccountSender in the Integrations project: the HTTP call
solution: ZavaSales
publisher_prefix: zava     # confirmed: `vela solution show ZavaSales --json` -> {"solution":"ZavaSales","publisherPrefix":"zava"} (exit 0)
namespace_prefix: Zava
acceptance_cases:
  - "AC1 Create of an account with a name -> the step fires once (pipeline: Create, PostOperation, Asynchronous) and sends the ERP the new account's id and name"
  - "AC2 the ERP call fails (sender throws) -> the account is still saved; the failure is recorded as a failed async job (AsyncStepFailures), not thrown to the caller"
  - "AC3 the request is POST https://erp.zava-demo.com/api/accounts, Content-Type application/json, header X-Api-Key = the secure config value, body {\"id\":\"<guid, lower-case hyphenated>\",\"name\":\"<name>\"}"
  - "AC4 the ERP answers non-2xx (500, 401) -> InvalidPluginExecutionException naming the status code (failed system job)"
  - "AC5 the ERP is unreachable (transport error) -> InvalidPluginExecutionException (failed system job)"
  - "AC6 the ERP never answers -> the call fails with InvalidPluginExecutionException within the configured timeout (explicit, 30 s in production), not the 100 s default"
  - "AC7 a name with quotes, backslash and non-ASCII characters -> the body is valid JSON that parses back to the same name"
  - "AC8 the secure config ErpApiKey is missing/blank -> InvalidPluginExecutionException, no HTTP call; the account is still saved"
  - "AC9 a Create that does not send name -> the step does not fire (Create filter gate, residual risk below)"
  - "AC10 an Update of the account (name changed) -> the step does not fire (Create only)"
  - "AC11 the API key never appears in the trace output"
decisions:
  - {by: human, what: "target solution ZavaSales (publisher prefix zava), namespace prefix Zava"}
  - {by: human, what: "ERP down/error -> no retry: the call fails once and stays as a failed system job; ops replays it"}
  - {by: human, what: "body is {\"id\": \"<account guid>\", \"name\": \"<account name>\"}; success = any 2xx"}
assumptions:
  - "Async PostOperation runs after the commit, so a failed call never rolls back or blocks the account save (registration-rules)."
  - "Create filtering attributes gate the trigger (pack: verified live). Account name is business-required, so every UI/form create sends it; an API create that omits name is not sent to the ERP (residual risk, AC9)."
  - "The name sent is the one in the Create request (ctx.Request.Target.Name); a null name sent explicitly is serialised as JSON null."
  - "Id = ctx.PrimaryEntityId (the created record's id), formatted Guid.ToString(\"D\") (lower-case hyphenated)."
  - "Payload serialised with DataContractJsonSerializer over a PUBLIC [DataContract] type (sandbox partial trust - gotcha)."
  - "Timeout 30 s: explicit, well under the 2-minute sandbox limit."
open_questions:
  - "Who supplies the ErpApiKey secure-config value at apply (`--secure-config ErpApiKey=@<file>` or VELA_SECURE_CONFIG_ErpApiKey)? The agent does not hold it - blocks the apply gate."
  - "Does the dev org require signed plugin packages? (signed: unknown - unsigned; a human signs before apply if required, then re-plans)"
skills: [vela-plan-review, vela-grill, vela-scaffold, vela-models, vela-test-harness, vela-plugin-authoring, vela-code-review, vela-apply]
---

## R - Requirements & DoD
"When an Account is created, tell our ERP about it: POST the account's id and name as JSON to
`https://erp.zava-demo.com/api/accounts`. The ERP authenticates calls with an API key sent in the
`X-Api-Key` header. If the ERP is down, people must still be able to save accounts."

DoD: AC1-AC11 are harness tests, green; analyzers clean; review PASS; `vela plan --solution ZavaSales`
preview on the final package(s). No test reaches the network.

## E - Entities
account: `accountid` (read - the created id), `name` (read from the Create target). No column is written;
no Dataverse write at all.

## A - Approach
Create, **PostOperation, Async** (`Async(deleteJobOnSuccess: true)`): the call is external and slow-ish,
and the story requires the save to succeed when the ERP is down - Async runs after the commit, so a
failure becomes a failed system job and never undoes or blocks the save (human decision: no retry, ops
replays failed jobs). PostOperation because the new id exists only after the create. New plugin: no
Account plugin exists in this new solution.

## S - Structure
`vela init --integrations`: the outbound code lives in `src/Zava.Integrations` (own package
`Zava.Integrations.<ver>.nupkg`). Plugin `AccountErpNotify` (`vela add plugin` into the Integrations
project) - thin handler: guard the secure config, resolve `IErpAccountSender`, send (id, name).
Service `ErpAccountSender` (`vela add service`, Integrations project): builds the JSON, POSTs with
`X-Api-Key`, explicit timeout, maps non-2xx / transport error / timeout to `InvalidPluginExecutionException`.
It takes an `HttpMessageHandler` so tests use a fake transport. Models: `account` generated into
`src/Zava.Shared`. The `Zava.Plugins` package stays empty (nothing of this story in it): it is left out of the
preview and the apply command (`vela plan` does not create an empty package).

## O - Operations
```
RegisterStep().OnCreate().PostOperation().Async(deleteJobOnSuccess: true)
    .FilterOn(e => e.Name)
    .WithSecureConfigFrom("ErpApiKey")
    .WithDescription("Sends the new account (id, name) to the ERP.")
    .Handle(OnExecute);
OnExecute: if SecureConfig blank -> throw IPE; ctx.GetRequiredService<IErpAccountSender>()
           .Send(ctx.PrimaryEntityId, ctx.Request.Target.Name); trace id (never the key).
ConfigureServices: AddScoped<IErpAccountSender>(r => new ErpAccountSender(SecureConfig)).
```
Tests: pipeline tests with `WithService<IErpAccountSender>(fake)` + `WithSecureConfig("ErpApiKey", ...)`
(AC1, AC2, AC8, AC9, AC10, AC11); `ErpAccountSender` against a fake `HttpMessageHandler` (AC3-AC7).

## N - Norms
Namespace `Zava.Integrations.Account.*`; generated naming kept (`OnExecute`). Thin handler, HTTP logic in
the service (SRP); no mutable fields; `InvalidPluginExecutionException` only; secret only in secure config.

## S - Safeguards
Legal: Create PostOperation Async, no images, FilterOn Name (VELA020). HTTPS to a DNS name, explicit
timeout, public payload type, no secret in code/unsecure config/trace. No Dataverse write -> no recursion.
Never `vela apply` - stop at the gate; the ErpApiKey value is supplied by the deployer.

## What was built
- Commands: `vela init ZavaSales --prefix Zava --publisher-prefix zava --integrations -o .`;
  `vela models --entities account --project src/Zava.Shared/Zava.Shared.csproj --url <org>`;
  `vela add plugin AccountErpNotify --entity Account --message Create --stage PostOperation --mode Async --filtering-attributes name --project src/Zava.Integrations/Zava.Integrations.csproj`;
  `vela add service ErpAccountSender --entity Account --project src/Zava.Integrations/Zava.Integrations.csproj`;
  `vela add test AccountErpNotify --kind plugin --entity Account --message Create` (in tests/Zava.Integrations.Tests).
- `src/Zava.Integrations/Account/Plugins/AccountErpNotify.cs` - Create / PostOperation / Async(deleteJobOnSuccess) /
  FilterOn(Name) / WithSecureConfigFrom("ErpApiKey"); OnExecute guards the key, resolves `IErpAccountSender`, sends
  (`ctx.PrimaryEntityId`, `ctx.Request.Target.Name`). No Dataverse write.
- `src/Zava.Integrations/Account/Services/ErpAccountSender.cs` - DataContractJsonSerializer over public
  `ErpAccountPayload`; POST with `X-Api-Key`; 30 s timeout; non-2xx / transport error / timeout ->
  `InvalidPluginExecutionException`.
- Tests: `tests/Zava.Integrations.Tests/Account/Plugins/AccountErpNotifyTests.cs` (pipeline, fake sender via
  `WithService`), `tests/Zava.Integrations.Tests/Account/Services/ErpAccountSenderTests.cs` (fake `HttpMessageHandler`).

## Evidence
- `dotnet build ZavaSales.sln -c Release`: `0 Warning(s)` `0 Error(s)` (no VELA diagnostic, nothing suppressed).
- Harness (Mono + xunit.console 2.9.2, `-parallel none`): RED `Total: 18, Errors: 0, Failed: 14, Skipped: 0`
  (commit 2117636) -> GREEN `Total: 18, Errors: 0, Failed: 0, Skipped: 0` (commit 1f6de50). Zava.Plugins.Tests: `Total: 0`.
  Passed before implementation (guard cases, expected): AC9, AC10, AC11, AC6 constant.
- Acceptance cases: [x] AC1 [x] AC2 [x] AC3 [x] AC4 [x] AC5 [x] AC6 [x] AC7 [x] AC8 [x] AC9 [x] AC10 [x] AC11
- Code review: isolated `vela-reviewer` subagent - **PASS**, 0 Critical / 0 Required, 7 Nits (verbatim in
  `logs/review1/review.md` of the run): (1) trim the API key / map a header FormatException to IPE; (2) keep the
  TaskCanceledException as inner exception; (3) assert no key in the trace on the failure paths too; (4) AC7 parses
  with the same serializer; (5) the "null name -> JSON null" assumption is untested; (6) Canvas status; (7) unused
  `using System.Linq`. Nits not applied in this run (non-blocking; any code change would need re-test, re-review and re-plan).
- Solution: `vela solution show ZavaSales --json` -> `{"solution":"ZavaSales","publisherPrefix":"zava"}` (exit 0).
- Package: `artifacts/Zava.Integrations.1.0.0.nupkg` (holds `lib/net48/Zava.Integrations.dll` + `Zava.Shared.dll`) ·
  sha256 `5f31628c6adfb5bdda3e8790b395d7cdae8f95be24a802641b5c8e7fa3b4790d` · unsigned (signed: unknown).
- `vela plan` (exit **8**, changes): operations - `create package zava_Zava.Integrations`; `create step
  Zava.Integrations.Account.Plugins.AccountErpNotify` (Create, account, stage 40, mode 1 async, filtering
  `name`, asyncAutoDelete true, no images). diagnostics - "Step 'Zava.Integrations.Account.Plugins.AccountErpNotify:stepkey:dv-bf29ed0d8c04'
  expects the secure configuration 'ErpApiKey', but none is set in the environment and no value was given; pass
  --secure-config ErpApiKey=VALUE (or set VELA_SECURE_CONFIG_ErpApiKey)." (kept as evidence: the agent does not hold
  the key). info - "Plugin assembly 'Zava.Integrations' not found in Dataverse (first deployment)."

## Sync log
- Canvas Structure: the production `ErpAccountSender(apiKey)` uses a per-call `HttpClient` that owns (and disposes)
  its default handler; the test constructor takes a caller-owned `HttpMessageHandler`. Behaviour unchanged.

## Run trace
| # | step | skill | command | exit | verdict |
|---|------|-------|---------|------|---------|
| 1 | version | using-vela | `vela version` | 0 | vela 0.26.1 |
| 2 | grill | vela-grill | Q1-Q3 to the human (solution, ERP-down behaviour, JSON body) | - | answered |
| 3 | solution | vela-scaffold | `vela solution show ZavaSales --json --url https://dyn-premium-dev.crm.dynamics.com` | 0 | {"solution":"ZavaSales","publisherPrefix":"zava"} |
| 4 | scaffold | vela-scaffold | `vela init ZavaSales --prefix Zava --publisher-prefix zava --integrations -o .` | 0 | 11 files, Vela.Plugins 0.36.0 |
| 5 | model | vela-models | `vela models --entities account --project src/Zava.Shared/Zava.Shared.csproj --url https://dyn-premium-dev.crm.dynamics.com` | 0 | Generated 4 file(s) |
| 6 | add | vela-scaffold | `vela add plugin AccountErpNotify --entity Account --message Create --stage PostOperation --mode Async --filtering-attributes name --project src/Zava.Integrations/Zava.Integrations.csproj` | 0 | Created plugin |
| 7 | add | vela-scaffold | `vela add service ErpAccountSender --entity Account --project src/Zava.Integrations/Zava.Integrations.csproj` | 0 | Created service |
| 8 | add | vela-scaffold | `vela add test AccountErpNotify --kind plugin --entity Account --message Create --project Zava.Integrations.Tests.csproj` | 0 | Created test |
| 9 | build | vela-test-harness | `dotnet build ZavaSales.sln -c Release` | 0 | 0 Warning(s) 0 Error(s) |
| 10 | test-red | vela-test-harness | `mono ~/.nuget/packages/xunit.runner.console/2.9.2/tools/net472/xunit.console.exe tests/Zava.Integrations.Tests/bin/Release/net48/Zava.Integrations.Tests.dll -parallel none` | 1 | RED 14/18 fail (expected) |
| 11 | build | vela-plugin-authoring | `dotnet build ZavaSales.sln -c Release` | 0 | 0 Warning(s) 0 Error(s) |
| 12 | verify | vela-test-harness | same mono runner, Zava.Integrations.Tests.dll | 0 | GREEN 18/18 |
| 13 | verify | vela-test-harness | same mono runner, Zava.Plugins.Tests.dll | 0 | Total: 0 |
| 14 | review | vela-code-review | isolated vela-reviewer subagent on `git diff a8b2aba...HEAD` | - | PASS, 7 Nits |
| 15 | package | vela-apply | `rm -rf artifacts && dotnet build ZavaSales.sln -c Release` (dll checked with `unzip -l`) | 0 | Zava.Integrations.1.0.0.nupkg sha256 5f31628c...4790d |
| 16 | plan | vela-apply | `vela plan -p artifacts/Zava.Integrations.1.0.0.nupkg --solution ZavaSales --url https://dyn-premium-dev.crm.dynamics.com --detailed-exitcode --out ../logs/plan.json` | 8 | changes: create package + 1 step; secure-config diagnostic |

## Gate - human approval required
Not applied. After `shasum -a 256 artifacts/Zava.Integrations.1.0.0.nupkg` matches
`5f31628c6adfb5bdda3e8790b395d7cdae8f95be24a802641b5c8e7fa3b4790d` (and after signing + re-plan, if the org requires
signed packages), a human runs:
`vela apply -p artifacts/Zava.Integrations.1.0.0.nupkg --solution ZavaSales --url https://dyn-premium-dev.crm.dynamics.com --secure-config ErpApiKey=@<file holding the key>`
- this will: create plugin package `zava_Zava.Integrations` and the step `AccountErpNotify` (Create of account,
PostOperation, Async, auto-delete on success, filtering `name`, secure config ErpApiKey), both added to ZavaSales.
`Zava.Plugins.1.0.0.nupkg` is deliberately not in the command (empty package). Exit `7` = partial apply (fix, re-run);
`5` = not converged - both reported, never "done".

## Open questions (block the gate)
- Who supplies the `ErpApiKey` value at apply, and how (`--secure-config ErpApiKey=@<file>` or `VELA_SECURE_CONFIG_ErpApiKey`)?
- Does the org require signed plugin packages? If yes, sign this package, then re-run `vela plan` on the signed file.
