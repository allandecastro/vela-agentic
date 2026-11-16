# account-erp-outbound: actor report (r3)

**Status: stopped at the apply gate. `vela apply` was not run.** The build went through the whole loop up to and including the `vela plan` preview.

## Decisions
**Asked the human** (logged in `work/logs/human-questions.md`):
- **Q1:** the solution is `ZavaSales` and the namespace prefix is `Zava`.
- **Q2:** when the ERP is down, there is no retry. The call becomes a failed system job and ops replays it.
- **Q3:** the body is `{"id":"<guid>","name":"<name>"}`, and any 2xx response is success.

**Design** (from the Vela Canvas):
- **Step:** one step on Account **Create**, **PostOperation, Async** (`deleteJobOnSuccess: true`), with `FilterOn(Name)` and `WithSecureConfigFrom("ErpApiKey")`.
  - It runs after the commit, so a failing ERP never blocks the save.
  - A create that doesn't send `name` doesn't fire the step. This residual risk is recorded as AC9.
- **Where the code lives:** in the Integrations project (`vela init --integrations`).
  - A thin plugin, `AccountErpNotify`.
  - A service, `ErpAccountSender`, behind `IErpAccountSender`. It serializes a public `[DataContract]` payload, POSTs over HTTPS with `X-Api-Key`, and uses an explicit 30 s timeout. A non-2xx response, a transport error or a timeout throws `InvalidPluginExecutionException`.
- **Missing or blank key:** `InvalidPluginExecutionException` is thrown and the ERP is not called.
- **Dataverse writes:** none.

## Evidence
- `vela version` returned `vela 0.26.1`.
- `vela solution show ZavaSales --json --url https://<dev-org>.crm.dynamics.com` returned `{"solution":"ZavaSales","publisherPrefix":"zava"}` (exit 0).
- `vela init ZavaSales --prefix Zava --publisher-prefix zava --integrations -o .` exited 0 and used Vela.Plugins 0.36.0.
- `vela models --entities account --project src/Zava.Shared/Zava.Shared.csproj --url <org>` exited 0 with "Generated 4 file(s)".
- `vela add plugin AccountErpNotify ... --stage PostOperation --mode Async --filtering-attributes name --project src/Zava.Integrations/...`, `vela add service ErpAccountSender`, and `vela add test AccountErpNotify` all exited 0.
- `dotnet build ZavaSales.sln -c Release` gave `0 Warning(s)` and `0 Error(s)`, so there are no VELA diagnostics.
- **Tests** (Mono + xunit.console 2.9.2, `-parallel none`):
  - RED (commit 2117636): `Total: 18, Errors: 0, Failed: 14, Skipped: 0`.
  - GREEN (commit 1f6de50): `Total: 18, Errors: 0, Failed: 0, Skipped: 0`.
  - The `Zava.Plugins.Tests` project has nothing for this story: `Total: 0`.
- **Review:** an isolated `vela-reviewer` subagent returned **PASS** with 0 Critical, 0 Required and 7 Nits. I did not apply the Nits; they are listed in the Build Report.
- **Package:** `rm -rf artifacts && dotnet build -c Release` produced `artifacts/Zava.Integrations.1.0.0.nupkg`, which contains `lib/net48/Zava.Integrations.dll`. Its sha256 is `5f31628c6adfb5bdda3e8790b395d7cdae8f95be24a802641b5c8e7fa3b4790d`.
- **Preview:** `vela plan -p artifacts/Zava.Integrations.1.0.0.nupkg --solution ZavaSales --url https://<dev-org>.crm.dynamics.com --detailed-exitcode --out ../logs/plan.json` exited **8** (changes pending).
  - Operations: `create package zava_Zava.Integrations` and `create step Zava.Integrations.Account.Plugins.AccountErpNotify` (Create, account, stage 40, async, filter `name`, asyncAutoDelete true).
  - Diagnostic: "...expects the secure configuration 'ErpApiKey', but none is set ... and no value was given". I kept this as evidence because I don't hold the key, and I did not use a placeholder value.
  - Info: "Plugin assembly 'Zava.Integrations' not found in Dataverse (first deployment)."
- I left the empty `Zava.Plugins.1.0.0.nupkg` out of the preview and the apply command, and recorded that in the Canvas.

## Gate (for a human)
Check `shasum -a 256 artifacts/Zava.Integrations.1.0.0.nupkg` against the hash above, then run:

`vela apply -p artifacts/Zava.Integrations.1.0.0.nupkg --solution ZavaSales --url https://<dev-org>.crm.dynamics.com --secure-config ErpApiKey=@<keyfile>`

Open questions that block the gate:
- Who supplies the `ErpApiKey` value?
- Does the org require signed packages? The package is unsigned and the answer is unknown. If it does, sign the package and then re-run `vela plan`.

## Produced (all under `.../account-erp-outbound/r3/work`)
- Project: `ZavaSales/`, a local git repo on branch `feature/account-erp-outbound` with commits a8b2aba → e707d8c. There was no push and no PR.
- Canvas and Build Report: `ZavaSales/docs/vela-builds/account-erp-outbound.md`
- Code:
  - `ZavaSales/src/Zava.Integrations/Account/Plugins/AccountErpNotify.cs`
  - `ZavaSales/src/Zava.Integrations/Account/Services/ErpAccountSender.cs`
- Tests:
  - `ZavaSales/tests/Zava.Integrations.Tests/Account/Plugins/AccountErpNotifyTests.cs`
  - `ZavaSales/tests/Zava.Integrations.Tests/Account/Services/ErpAccountSenderTests.cs`
- Logs:
  - Test runs: `logs/red.txt`, `logs/green.txt`
  - Plan: `logs/plan.json`
  - Review: `logs/review1/review.md`
  - Questions: `logs/human-questions.md`
  - Also in `logs/`: the build and models outputs and `solution-show.json`.
