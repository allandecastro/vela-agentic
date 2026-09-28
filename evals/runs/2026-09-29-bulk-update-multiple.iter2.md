---
scenario: bulk-update-multiple
date: 2026-09-29
verdict: pass
vela_cli: 0.21.0
framework: 0.29.3
runner: "fresh subagent, local, no org, iteration 2"
---

## Loop outcome
- version: `vela version` -> `vela 0.21.0`, exit 0 (dotnet 10.0.302, Mono 6.14.1).
- intake/challenge (vela-plan-review): Canvas drafted before scaffolding (`canvas-draft.md`). Message
  decision recorded with its reason: **UpdateMultiple, PreOperation, Sync, FilterOn(Name), not also Update**
  (one execution per batch; merged pipelines mean single Updates also reach it -> assumption A1; registering
  both would run twice). Assumptions A1-A3 + open question (publisher prefix/solution unknown -> `--prefix tbd`,
  apply blocked) flagged; continued (unattended).
- scaffold: `vela init BulkAccounts --prefix tbd -o . --no-integrations --no-console` exit 0 ("Scaffolding
  against Vela.Plugins 0.29.3"); `git init` + commit untouched scaffold (review base); branch; demos per the
  vela-scaffold list removed + Canvas moved to `docs/vela-builds/account-bulk-name-trim.md`.
  `vela add plugin AccountNameTrim --entity Account --message UpdateMultiple --filtering-attributes Name` exit 0
  -> `.PostOperation()` / `IUpdateMultiplePostContext<Account>`, `FilterOn(e => e.Name)` (correct casing);
  edited to `.PreOperation()` / `IUpdateMultiplePreContext<Account>` (CRLF kept). `dotnet build` 0 errors 0 warnings.
- model: skipped (no org). Would run: `vela models --entities account --out src/tbd.Shared/Models/Generated --overwrite --url <org>`.
  `Account.Name` already in the scaffold model -> no stand-in needed.
- test RED (vela-test-harness): `vela add test AccountNameTrim --kind plugin --entity Account` exit 0; replaced by
  AC1-AC10 (AC1-AC7 `PluginContext.For<Account>().WithTargets(...).WithOrganizationService(crm).Execute(plugin)`,
  AC8-AC10 `PluginPipeline` with `Service.Execute(new UpdateMultipleRequest{...})` / `Service.Update`).
  `mono ~/.nuget/packages/xunit.runner.console/2.9.2/tools/net462/xunit.console.exe .../tbd.Plugins.Tests.dll -parallel none`
  exit 1: `Total: 10, Errors: 0, Failed: 6` - AC1, AC3, AC5, AC6, AC8, AC10 failed on untrimmed values
  (e.g. `Expected: "Contoso" Actual: "  Contoso "`); AC2/AC4/AC7/AC9 (guard/no-op) passed, as the skill predicts.
- implement (vela-plugin-authoring): `foreach (var entity in ctx.Request.Targets.Entities) { var account =
  entity.ToEntity<Account>(); if (account.Name == null) continue; var t = account.Name.Trim(); account.Name =
  t.Length == 0 ? null : t; }` - no `Update` calls; the recipe in plugin-authoring-api.md worked verbatim.
- verify: same mono command exit 0: `Total: 10, Errors: 0, Failed: 0, Skipped: 0`;
  `dotnet build BulkAccounts.sln -c Release --no-incremental` -> `0 Warning(s) 0 Error(s)`, 0 VELA lines.
- review (vela-code-review): fresh subagent acting as vela-reviewer, given diff text + Canvas + verbatim RED/GREEN
  + Run trace -> **PASS**, 0 Critical / 0 Required / 9 Nits.
- package (vela-apply): `rm -rf artifacts; dotnet build BulkAccounts.sln -c Release` exit 0 ->
  `artifacts/tbd.Plugins.1.0.0.nupkg` (`lib/net462/tbd.Plugins.dll` present), sha256
  `fb8e355c6f686e9d54857fbd80ee814d4202c4f62597ab2a5d8a8c363e2be6df`, unsigned.
- plan: skipped (no org). Would run: `vela plan -p artifacts/tbd.Plugins.1.0.0.nupkg --url <org> --out plan.json`.
- apply gate: Build Report written into `docs/vela-builds/account-bulk-name-trim.md` (kind vela-build), stopped.
  `vela apply` never run. Draft PR skipped (eval).

## Scenario checks
- Message choice recorded with reason (Canvas A section + decisions + A1): yes.
- Bulk surface: handler iterates `ctx.Request.Targets.Entities`, edits each in PreOperation, no per-record
  `Update` (AC7: seeded rows unchanged; AC8: `Assert.Single(ExecutionLog)` - no re-entry): yes.
- Tests: batch supplied with `WithTargets(...)` (the trigger auto-derived for the single-step plugin, as
  harness-api.md says - `.OnMessage("UpdateMultiple")` not needed); cases several-with-spaces (AC1), no name
  (AC2), mixed batch (AC3) present: yes.
- Success criteria: 1 Canvas decision + reason - yes; 2 RED then GREEN on batch cases, no per-record write - yes;
  3 build clean of VELA00x + review PASS - yes.

## Findings
No blockers. The skills' bulk recipe (message choice, handler shape, `WithTargets`, `UpdateMultipleRequest`
through the pipeline) worked as written, without rediscovering the API.

1. minor - `skills/vela-test-harness/references/harness-api.md` warns that the `vela add test` output is
   "meaningless for Associate" but says nothing for bulk. `vela add test AccountNameTrim --kind plugin --entity Account`
   on an UpdateMultiple plugin generates `.WithTarget(target)`; run against the correct bulk handler it fails:
   `Microsoft.Xrm.Sdk.InvalidPluginExecutionException : Unhandled exception in plugin 'tbd.Plugins.Account.Plugins.AccountNameTrim': NullReferenceException`
   (`ctx.Request.Targets` is null with `WithTarget`). Correct: for `*Multiple` replace the generated test with
   `.WithTargets(...)` (and state it next to the Associate note).
2. minor - `skills/*/references/dataverse-gotchas.md` / `harness-api.md` (bulk): how `FilterOn` gates a
   **mixed** batch (some targets carry the filtered column, some don't) is not documented; only the all-or-none case
   was provable from the skills (AC9). The handler must tolerate targets without the column; the skills should say
   so and recommend a mixed-batch pipeline test (reviewer point C).
3. minor - `skills/vela-plan-review/SKILL.md` "**Bulk:** `*Multiple` vs single-record message - one of them, never
   both ... record why" does not prompt the consequence that a story scoped to bulk ("when updated this way")
   **cannot** be limited to bulk: an UpdateMultiple step also runs for single Updates (proved by AC10). I recorded
   it as assumption A1; the bullet should require it as a human-confirmation item at the gate (reviewer F).
4. minor - `skills/vela-code-review/references/` does not bundle `plugin-authoring-api.md`, where the only
   statement that `ToEntity<Account>()` shares the attribute collection lives; the isolated reviewer could not
   verify the handler's core mechanism from its own bundle (reviewer D). Also from the reviewer: `review-checklist.md`
   rates a per-record write in a bulk handler Required while the same write is a Critical recursion case (A); its
   lost-edit rule names only `ctx.Request.Target`, not `Targets` (B); no Canvas status value is defined for the review
   stage (G).
5. minor - `harness-api.md` "`WithTargets(params T[])` keeps your instances" - no note that typed instances do not
   exercise the late-bound `Entity` targets a live org passes (reviewer E / Nit 4).
6. minor - the scaffolded UpdateMultiple plugin's TODO comment still says "For a Create/Update message, read the typed
   record with ctx.GetTarget<Account>()"; plugin-authoring-api.md already says to ignore it, so no deviation - but the
   bulk context gets a single-record hint.

### Environment (not skill findings)
- `vela-reviewer` is not an available subagent type in this host: dispatched a general-purpose subagent told to act
  as it; its read-only boundary was by instruction only, and it reported one read-only `grep` via shell.
- zsh: `echo =====` fails (`=` expansion) - my own command, not a skill issue.

## Fixes
- none yet (findings feed the next iteration).

## Verdict
**pass** - no blocking finding: Canvas decision + reason, RED (6 fail) -> GREEN 10/10 on Mono/xunit, build 0 VELA,
isolated review PASS, package built + hashed, plan skipped (no org), stopped before apply. Next run should re-check
findings 1-3 (bulk `vela add test` shape, mixed-batch filtering, bulk-scope confirmation at the gate).
