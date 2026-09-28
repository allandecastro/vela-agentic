---
scenario: org-models-and-plan
date: 2026-09-29
verdict: pass
vela_cli: 0.19.6
framework: 0.29.1
runner: fresh subagent, local, dev org read-only
---

## Loop outcome
- Intake/Challenge (vela-plan-review): Canvas drafted outside the project (Update / PreOperation / Sync / FilterOn AccountNumber,
  new plugin, no service, --no-integrations, solution VelaEvals, prefix veval, 6 acceptance cases). Assumptions flagged; continued.
- Scaffold: `vela init VelaEvals --prefix veval --no-integrations --no-console -o <scratch>` exit 0 (resolved Vela.Plugins 0.29.1);
  baseline `dotnet build` 0 errors, 4 demo VELA013; `git init` + commit untouched scaffold (base 4bbbad8); branch; demos removed
  (build 0 warn / 0 err); Canvas moved to `docs/vela-builds/account-number-uppercase.md`.
- Model: `vela models --entities account --out src/veval.Shared/Models/Generated --overwrite --url https://dyn-premium-dev.crm.dynamics.com`
  exit 0 -> "Generated 4 file(s) into .../src/veval.Shared/Models/Generated (namespace veval.Shared.Models.Generated)."
  `--verify` exit 0 -> "account: in sync / All 1 table(s) are in sync with the live schema." Model never hand-edited.
- `vela add plugin AccountNumberUppercasePlugin --entity Account --message Update --filtering-attributes AccountNumber` exit 0
  (generated `FilterOn(e => e.AccountNumber)` correct); edited PostOperation->PreOperation, IUpdatePostContext->IUpdatePreContext.
- `vela add test AccountNumberUppercasePlugin --kind plugin --entity Account` exit 0; 6 tests written (4 Execute, 2 PluginPipeline).
- RED (mono xunit.console 2.9.2 -parallel none) exit 1: `Total: 6, Errors: 0, Failed: 4` (lower, mixed, already-upper, pipeline-save);
  guard cases (cleared->null, not sent->no fire) passed pre-implementation as expected.
- Implement on `ctx.Request.Target`, write only when `ToUpperInvariant` differs. GREEN exit 0: `Total: 6, Errors: 0, Failed: 0, Skipped: 0`;
  `dotnet build VelaEvals.sln -c Release` 0 Warning(s) 0 Error(s).
- Review: isolated vela-reviewer subagent -> PASS, 0 Critical / 0 Required / 12 Nits.
- Package: `dotnet build VelaEvals.sln -c Release` -> artifacts/veval.Plugins.1.0.0.nupkg (contains lib/net462/veval.Plugins.dll),
  sha256 3a02907c760fdded67dd768a854686b71489241c28fd4798aa56d2737d0d536e, unsigned (no cert).
- Plan: `vela plan -p artifacts/veval.Plugins.1.0.0.nupkg --url https://dyn-premium-dev.crm.dynamics.com --out plan.json` exit 0:
  summary {added 1, removed 0, changed 0}; operations = [create step veval.Plugins.Account.Plugins.AccountNumberUppercasePlugin,
  "Exists locally but not in Dataverse."] (diff: Update/account, stage 20, mode 0, filteringAttributes [accountnumber], no images);
  diagnostics = ["Plugin assembly 'veval.Plugins' not found in Dataverse."] (first deploy - expected); no rank collision reported; no demo op.
- Gate: Build Report committed; human handed `shasum -a 256` check + `vela apply -p artifacts/veval.Plugins.1.0.0.nupkg --solution VelaEvals --url ...`.
  Stopped. No apply, no --auto-approve. Draft PR step skipped (eval).

Success criteria: 1 yes (models from org, build clean) · 2 yes (RED->GREEN, 4 named cases + cleared + recursion) · 3 yes (PASS) ·
4 yes (plan.json in Build Report, ops + diagnostics interpreted, Gate with apply command + hash check) · 5 yes (only models x2, plan x1).

## Findings
1. minor - `skills/vela-models/SKILL.md` step 3/4: "interactive `-i` for a dev org" and the example `vela models ... --overwrite -i`.
   A headless agent on a dev org needs `--url <org>` alone (DefaultAzureCredential / az login); that is only in `cli-surface.md`
   (auth rule 4), and `vela models --help` doesn't list it ("connection: --connection-string | --url + --tenant-id + --client-id + --client-secret | --interactive").
   Deviated to `--url https://dyn-premium-dev.crm.dynamics.com` (worked, exit 0). Fix: name `--url` alone in step 3 and in the example.
2. minor - `references/cli-surface.md` "Verified against: ... Vela.Plugins / Vela.Testing 0.28.2 (framework resolved by vela init)":
   `vela init` printed "Scaffolding against Vela.Plugins 0.29.1 (latest on nuget.org ...)", and the test csproj pins Vela.Testing 0.29.1.
   Everything in the pack still held on 0.29.1, but the "resolved by vela init" claim is stale. Fix: re-verify on 0.29.1 or tell the builder to pin `--core-version 0.28.2`.
3. minor - `skills/vela-scaffold/SKILL.md` step 7 "the scaffold writes **CRLF** files": `vela add plugin` wrote a mixed file
   (`file` -> "with CRLF, LF line terminators"; lines 15 `.Sync()` and 29 are LF-only; no final newline), and `vela models` writes LF-only
   (`Account.cs: Unicode text, UTF-8 text`). Fix: say "mostly CRLF; add/models output can be mixed or LF - use `git diff --ignore-cr-at-eol`".
4. minor - scenario ("the `operations` contain only this plugin's assembly/type/step") vs `cli-surface.md` plan.json shape: on a first deploy
   the real `operations` list contains **only the step** (`kind: step`); the assembly/type creation appears only as the diagnostic
   "Plugin assembly 'veval.Plugins' not found in Dataverse.", and `diff.currentAssemblies` confusingly lists `["veval.Plugins"]` too.
   Fix: document that a first-deploy plan shows step operations + the assembly-not-found diagnostic, not assembly/type operations.
5. minor - `agents/vela-reviewer.agent.md` / `skills/vela-code-review` references: the reviewer's Nit 8 said "Run `vela plan --solution VelaEvals`",
   which contradicts `vela-apply` step 5 ("plan does not tag a solution - do not pass `--solution` to it"). The reviewer's bundled references
   don't include `cli-surface.md`, so it cannot check flags. Not followed. Fix: bundle `cli-surface.md` with vela-code-review, or add that rule to the checklist.
6. minor - `references/harness-api.md` / `vela-test-harness`: scenario criterion "already upper -> no change written". In PreOperation the Target is value-identical
   either way; the harness has no documented way to observe "not written". The agent invented a trace-text assertion
   (`builder.TraceCapture.Traces`), which the reviewer flagged as brittle. Fix: document the sanctioned pattern (trace assertion, or `Target.Attributes` change tracking, or state it is not observable).
7. minor - `skills/vela-scaffold/SKILL.md` step 6 "Keep the demo *models* until `vela models` regenerates them if your code uses them": the skill is
   silent on a demo model the code does **not** use (`Models/Generated/Contact.cs`). The agent left it; the reviewer flagged it as a Nit ("looks generated when it isn't").
   Fix: "delete demo models your code doesn't use; regenerate the ones it does."
8. minor - `skills/vela-code-review/SKILL.md` step 1: only demo deletions are handed over as `--stat`. The generated model diff (`Account.cs` +1746 lines) is not covered.
   The agent gave generated files as stat + the relevant property excerpt. Fix: say how to present `Models/Generated` in the reviewer diff.
9. minor - `skills/vela-plan-review/SKILL.md` / `registration-rules.md` "It must already exist": no skill gives a read-only way to confirm the solution
   `VelaEvals` exists before the gate (`plan` takes no `--solution`). The builder relied on the scenario's statement, and the reviewer raised it as a Nit.
   Fix: give a probe (e.g. `vela models --solution VelaEvals --verify`, reading its output text) or state the check is the human's at apply.
10. minor - `vela-plan-review` grilling has no rule for a story term the scenario narrows: "set or changed" plausibly includes Create, but the scenario pins `message: Update`.
    It was recorded as an assumption plus an open question and carried to the Gate. The pack doesn't say whether that should route to `vela-grill` or can proceed.
11. minor - `skills/vela-apply/SKILL.md` step 2 ("Build it last"): the baseline Debug `dotnet build` right after `vela init` already emitted
    `artifacts/veval.Plugins.1.0.0.nupkg` **with the demos**, under the same file name as the final package. The agent `rm -rf artifacts` before the final Release build.
    Fix: mention that the scaffold build leaves a demo package in `artifacts/`; clear it before packaging.
- Not exercised: a rank collision with a Microsoft managed step. This org reported none for account Update PreOperation, so the gotcha could not be checked.

Environment issues: none. The shim, az session, mono and the xunit.console 2.9.2 runner (already in ~/.nuget) all worked.

## Fixes
- (none yet - findings feed the next iteration)

## Verdict
pass - no blocking finding. All five success criteria met with real org models and a real plan. The next run must re-check findings 1
(`--url` in vela-models), 4 (first-deploy plan shape), 5 (reviewer vs `plan --solution`) and 6 (no-change-written pattern).
