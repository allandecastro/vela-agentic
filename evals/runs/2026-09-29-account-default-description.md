---
scenario: account-default-description
date: 2026-09-29
verdict: pass
vela_cli: 0.19.6
framework: 0.28.2
runner: fresh subagent, local, no org
---

## Loop outcome
1. Intake/Plan/Challenge (vela-plan-review): Canvas drafted outside the project (4 acceptance cases, prefix `zava` + solution flagged as assumptions blocking apply, `--no-integrations`/`--no-console`).
2. Scaffold (vela-scaffold): `vela version` exit 0 (0.19.6); `vela init ZavaAccounts --prefix zava -o . --no-integrations --no-console` exit 0 (Vela.Plugins 0.28.2, 3 projects); git init + commit untouched scaffold (review base) + branch; 18 demo files removed; Canvas moved to `docs/vela-builds/`. `vela add plugin AccountDefaultDescriptionPlugin --entity Account --message Create --filtering-attributes name --project src/zava.Plugins/zava.Plugins.csproj` exit 0 (warned, echoed `e => e.name`, PostOperation); fixed per step 5 to `.PreOperation()`, `ICreatePreContext<Account>`, `e => e.Name`; `dotnet build` 0 errors / 0 warnings. `vela add test AccountDefaultDescriptionPlugin --kind plugin --entity Account` (in the .Tests dir) exit 0.
3. Model (vela-models): skipped, no org. Would run `vela models --entities account --out src/zava.Shared/Models/Generated --overwrite -i`. Labelled `// STAND-IN for vela-models (no org)` `Description` property added to the sealed generated `Account`.
4. Test RED (vela-test-harness): Mono + `xunit.console.exe` 2.9.2, `-parallel none`: `Total: 4, Errors: 0, Failed: 3, Skipped: 0` (null / whitespace / pipeline cases failed with Actual null or "   "; the non-empty guard case passed as expected).
5. Implement (vela-plugin-authoring): `ctx.Request.Target.Description` set in PreOperation when `IsNullOrWhiteSpace`; no `UserService` write. GREEN `Total: 4, Errors: 0, Failed: 0, Skipped: 0`, exit 0.
6. Verify: `dotnet build ZavaAccounts.sln --no-incremental` gave `0 Warning(s)`, `0 Error(s)`, `Build succeeded.` (Vela.Analyzers active, 0 VELA00x).
7. Review (vela-code-review): isolated vela-reviewer subagent, read-only, given the diff text, the Canvas and the RED/GREEN summaries. PASS, 0 Critical, 0 Required, 6 Nits. Fixed the DoD count and added a `""` case (Theory). Re-run gave `Total: 5, Errors: 0, Failed: 0, Skipped: 0`.
8. Package & preview (vela-apply): `dotnet build ZavaAccounts.sln -c Release` exit 0 → `artifacts/zava.Plugins.1.0.0.nupkg` (contains `lib/net462/zava.Plugins.dll` + `zava.Shared.dll`), sha256 `2284de22d4e23a915763afc8985faa738c31f5cd57c46c86e6429680b649950e`. Unsigned (no certificate). `vela plan` skipped, no org. Would run `vela plan -p artifacts/zava.Plugins.1.0.0.nupkg --connection-string "$DATAVERSE_CONNECTION_STRING" --out plan.json`.
9. Apply gate: Build Report written to `docs/vela-builds/account-default-description.md` (`kind: vela-build`), then stopped. `vela apply` was never run. Draft PR skipped (eval).

## Success criteria
1. init / add plugin / add test all exit 0: **met**.
2. `EntityPluginBase<Account>` / `OnExecute` / `ctx.Request.Target`; typed `Description` (stand-in); no magic strings in the plugin: **met**.
3. RED (3 fail) then GREEN on Mono + `-parallel none`, real harness API (`PluginContext.For<Account>()...Execute(instance)`, `PluginPipeline`): **met**.
4. Build green, 0 VELA00x: **met**.
5. Empty → defaulted (null, "", whitespace); non-empty → untouched: **met** (tests assert on `target` and `Assert.Empty(crm.GetAll("account"))`).
7. PreOperation, set on `ctx.Request.Target`, no `UserService.Update`: **met**.
6. Canvas with acceptance cases + Build Report (harness pass, analyzers clean, cases checklist, run trace, gate): **met**.

## Findings
1. minor - `skills/vela-scaffold/SKILL.md` step 4 "`[--filtering-attributes a,b]`" does not say to pass the **model property name** (`Name`) rather than the Dataverse logical name. I passed the logical name `name`. The CLI printed `Warning: filtering attribute 'name' may not compile. Did you mean 'Name'?` and generated `.FilterOn(e => e.name)`. Step 5 anticipates this and says to fix it by hand, so it was not a blocker, but step 4 should just say `--filtering-attributes Name` (property casing).
2. minor - the stand-in's place in the loop. `vela-plugin-authoring` step 2 owns the no-org stand-in, but that skill's "When to use" says do not start before the RED tests exist, and the RED tests cannot compile without the property. `vela-models` step 3 ("use the labelled no-org stand-in described in `vela-plugin-authoring` step 2") resolves the order: add it at MODEL. The scenario's own note points only at plugin-authoring, which reads as the IMPLEMENT step. Suggest that plugin-authoring step 2 say "done at MODEL, before RED".
3. minor - line endings. `skills/vela-code-review/SKILL.md` "the scaffold writes CRLF files, so keep CRLF when editing" is the first place CRLF is mentioned. By then I had already rewritten the plugin and test files as LF (heredoc / Write), and needed an extra commit to restore CRLF. The file `vela add plugin` generates is itself mixed (`with CRLF, LF line terminators`). The warning belongs in vela-scaffold / vela-plugin-authoring / vela-test-harness, where the edits happen.
4. minor - `harness-api.md` lists the `ExecutionLog` entry fields ("PluginTypeName, Message, Stage, Mode, EntityLogicalName, Depth") but not the entry type or the Stage/Mode types. The reviewer's Nit ("assert run.Stage/run.Mode") could not be applied without rediscovering the API, so I left it open. I used `var` rather than guess a type name.
5. minor - `build-report-template.md` says the Canvas file "grows into" the Build Report, but the Build Report front-matter omits the Canvas keys (acceptance_cases, assumptions, solution, prefix...). It is unclear whether to keep them in the front-matter or only in the `## Canvas` body. I kept both.
6. minor - `skills/vela-apply/SKILL.md` "Build it last ... then nothing else before plan" conflicts with committing the Build Report, which must record the package hash and so comes after the build. The scaffold stamps the git commit into the assembly (`AssemblyInformationalVersion 1.0.0+<sha>`). The packaged dll therefore carries commit `c1a205d`, while the branch HEAD is `d0a947c` (the docs commit), so a rebuild at HEAD gives a different hash. Harmless here, because the human applies the file after checking its hash, but the skill should say that the docs-only report commit after packaging is expected.
7. minor - review coverage (`references/review-checklist.md`, `agents/vela-reviewer.agent.md`). The reviewer is not given the run trace, so it cannot catch drift between the Canvas and the commands actually run. The Canvas Structure line named `--filtering-attributes Name` while `name` was run; I caught that myself after review. The reviewer's own feedback: the checklist has no item for Canvas self-consistency (DoD count vs `acceptance_cases`, status/date), no guidance on test strength, no check on RED evidence, and does not place an unconfirmed solution/prefix (review finding or vela-apply precondition?).
8. minor - `skills/vela-plan-review/SKILL.md` target solution & publisher: "otherwise scaffold with a flagged assumption". It gives no guidance on what placeholder to choose when there is no human and no org. I chose `zava` (the template's example), which risks looking like a real value. Suggest a visibly placeholder rule, or state that the example prefix is acceptable only when flagged.
9. minor (scenario, not skill) - the scenario's success criterion 3 says "the two acceptance-case tests", while the template's example Canvas and vela-plan-review ("every assumption that changes behaviour is also an acceptance case") lead to 3+ cases (whitespace). The criteria are also numbered 1-5, 7, 6.

No blockers. The iteration 1/2 blockers did not recur: the harness API, the Mono runner, the `EntityPluginBase`/`OnExecute` surface, the mandatory Create `FilterOn`, the no-org stand-in and `target.Id` all worked as documented without rediscovery.

### Environment
- None blocking. `xunit.runner.console/2.9.2` was already in `~/.nuget` (no csproj edit needed). `vela plan --help` prints the global page, as documented.

## Fixes
- none yet (this run).

## Verdict
pass - every success criterion met with evidence; 9 minor findings, no blocker. The next run should re-check findings 1 (filtering-attribute casing guidance), 2 (stand-in at MODEL) and 3 (CRLF warning placement).
