---
scenario: account-multi-step
date: 2026-09-28
verdict: pass
vela_cli: 0.19.6
framework: 0.28.2
runner: fresh subagent, local, no org, iteration 2
---

## Loop outcome
Baseline (depends_on: account-default-description), used as setup:
- Challenge: Canvas `docs/vela-builds/account-default-description.md` (Create, PreOperation, Sync, filter name, new-plugin).
- Scaffold: `vela init ZavaSales --prefix zava -o .` exit 0; `dotnet build` 0 errors / 4 VELA013 (demo tests only); demos removed (git rm), rebuild 0 warn / 0 err; `vela add plugin AccountDefaultDescription --entity Account --message Create --filtering-attributes Name --project src/zava.Plugins/zava.Plugins.csproj` exit 0 (`FilterOn(e => e.Name)`, PostOperation -> changed to PreOperation + `ICreatePreContext`).
- Model: skipped, no org (`vela models --entities account --out src/zava.Shared/Models/Generated --overwrite -i`); `Description` STAND-IN added.
- Test RED: `vela add test AccountDefaultDescription --kind plugin --entity Account --project tests/...` exit 0; mono xunit `Total: 4, Errors: 0, Failed: 3` (non-empty-untouched guard passes).
- Implement/verify: `Total: 4, Errors: 0, Failed: 0, Skipped: 0`; build -c Release 0 warn / 0 err.
- Review: self-review PASS (1 Nit: stand-in). Package: dll present in `artifacts/zava.Plugins.1.0.0.nupkg`. Plan: skipped (no org). Build Report written.

Scenario (account-multi-step):
- Challenge: Canvas `docs/vela-builds/account-number-uppercase.md`, `reuse: add-step:AccountDefaultDescription`, `steps:` list with the Update step (PreOperation, Sync, filter [name], pre-image accountnumber, handler HandleUpdate).
- Scaffold: `vela add step AccountDefaultDescription --entity Account --message Update --project src/zava.Plugins/zava.Plugins.csproj` exit 0 -> `.PostOperation().Sync().FilterOn(e => e.Id /* TODO ... */).Handle(HandleUpdate)` + `HandleUpdate(IUpdatePostContext<Account>)`, exactly as `plugin-authoring-api.md` says.
- Build: `AccountDefaultDescription.cs(25,34): error VELA001: 'Id' is not a Dataverse column; a Vela column selector must target a generated early-bound column property` (1 Error). Fixed: `FilterOn(e => e.Name)`, `.PreOperation()`, `IUpdatePreContext`, `WithPreImage(e => e.AccountNumber)`, `partial`. Rebuild 0 warn / 0 err. `HandleUpdate` and `OnExecute` kept.
- Model: skipped, no org (same command); `AccountNumber` STAND-IN added.
- Unchanged Create tests against the now multi-step plugin: `Failed: 4`, `Plugin '...AccountDefaultDescription' has no registered step matching message 'Update'.` (as harness-api.md predicts) -> restated with `.OnCreate().Stage(PluginStages.PreOperation)`.
- Test RED: `zava.Plugins.Tests  Total: 10, Errors: 0, Failed: 3, Skipped: 0` (pre-image->upper Actual null; sent->upper Actual "xy-9"; pipeline Actual "ab-12"). Guards + Create pass pre-code, as expected.
- Implement/verify: `zava.Plugins.Tests  Total: 10, Errors: 0, Failed: 0, Skipped: 0` (mono + xunit.console 2.9.2, `-parallel none`), exit 0; `dotnet build ZavaSales.sln -c Release` exit 0, `0 Warning(s) 0 Error(s)`. Filter mutation (FilterOn -> AccountNumber) -> `Failed: 2` (does-not-fire + pipeline), reverted.
- Review: isolated `vela-reviewer` subagent (diff text + Canvas only) -> **PASS**, 0 Critical / 0 Required / 5 Nits.
- Package: `dotnet build ZavaSales.sln -c Release` exit 0; `lib/net462/zava.Plugins.dll` in nupkg; sha256 3a95fc96...a270. Sign: not signed (no cert). Plan: skipped (no org), would run `vela plan -p artifacts/zava.Plugins.1.0.0.nupkg --interactive --out plan.json`. Apply: not run. Draft PR: skipped (eval).

## Success criteria / "must get right" checklist
- Reuse via `vela add step AccountDefaultDescription --entity Account --message Update`: yes (exit 0; not a new plugin, not hand-written).
- Generated handler `HandleUpdate` kept, `OnExecute` kept for Create: yes (diff shows neither renamed).
- Placeholder `FilterOn(e => e.Id /* TODO */)` fails with VELA001, replaced by `e => e.Name`: yes (error line above; then 0 errors).
- Stage PreOperation on `ctx.Request.Target`: yes (`.PreOperation()`, `IUpdatePreContext`, `target.AccountNumber = ...`; no `UserService` write; tests assert `Assert.Empty(crm.GetAll("account"))`).
- Harness states the trigger in every Execute test; Create tests updated and green: yes (`.OnCreate()` / `.OnUpdate()` + `.Stage(PluginStages.PreOperation)`; pipeline tests derive it from the real write).
- SC1 Canvas records `reuse: add-step:AccountDefaultDescription` and the Update step: yes.
- SC2 VELA001 first, then green with no VELA00x in authored code: yes.
- SC3 RED then green: name changed -> uppercased (Execute + pipeline); name unchanged/not sent -> step not run (PluginPipeline, `Assert.Empty(p.ExecutionLog)`); Create cases pass: yes.
- SC4 `vela-code-review` PASS: yes (isolated reviewer).

## Findings
No blockers. A literal reading of the skills got every "must get right" item right, with no need to rediscover the API.

Skill defects (minor):
1. minor - `agents/vela-builder.agent.md` said "create the feature branch before Scaffold, and open the PR as a draft as soon as the Vela Canvas exists (right after Challenge, step 3)". `build-report-template.md` said the Canvas is "committed in the target project under `docs/vela-builds/<slug>.md`". For a new solution there is no project or repo before `vela init`, which creates the nested `<Name>/` folder. `vela-code-review` step 1 instead says "`git init` + commit right after scaffolding". What happened: the Canvas was drafted in scratch `docs/`, then `git init` ran after `vela init` (the scaffold was committed on `main`, then the branch was created) and the Canvas was copied in. Correct path: for a new solution, state "`vela init` first, then `git init`, commit the scaffold, branch, and move the Canvas into `<Name>/docs/vela-builds/`". Or allow the repo root above the solution folder.
2. minor - `skills/vela-scaffold/SKILL.md` step 6 said "`vela init` adds demo plugins and Custom APIs (an Account create step that creates a task, `Ping`, ...) and their tests ... Delete them". It does not list where they are. The actual demos: `src/zava.Plugins/{Account,Contact,GlobalCustomApis}` (including the `AccountMessageReference` cheat-sheet and 2 services), `src/zava.Integrations/{Account,Contact,GlobalCustomApis}`, `src/zava.Shared/Services/{I,}GreetingService.cs`, and `tests/*/{Account,Contact,GlobalCustomApis,Security}`. After removal, `artifacts/zava.Integrations.1.0.0.nupkg` is still built: it has no plugin types, but it ships `zava.Integrations.dll` and dependencies. Both `vela init`'s own "Next steps" (`vela plan --packages-dir artifacts ...`) and `vela-apply` step 5 (`or --packages-dir artifacts`) would pick it up. Correct path: list the demo paths; recommend `vela init --no-integrations` (or deleting that project) when the Canvas needs no integrations; preview with `-p artifacts/<prefix>.Plugins.<ver>.nupkg`.
3. minor - `skills/vela-test-harness/references/harness-api.md` said "For a MULTI-step plugin only, state it: .OnUpdate().Stage(...).Mode(...)". The argument types are not given. What actually exists (Vela.Testing.xml 0.28.2): `Stage(Vela.Constants.PluginStages)`, `Mode(Vela.Steps.ExecutionMode)`, `Sync()`, `Async()`. `.Mode(...)` was not needed: `.OnCreate().Stage(PluginStages.PreOperation)` alone matched. `WithPreImage` is listed with no signature; it is `WithPreImage(TEntity, string alias)`, and the default alias fed the typed `ctx.PreImage`. Correct text: `.OnUpdate().Stage(PluginStages.PreOperation)` (`using Vela.Constants;`), add `.Async()` only for an Async step, and `.WithPreImage(new Account { ... })` for an image.
4. minor - `skills/vela-plan-review/references/build-report-template.md` showed a multi-step `steps:` example with only `{message, stage, mode, filter}`. It has no per-step `images`/`handler` keys, although the top-level `images:` disappears in that form. What happened: `images: [pre: accountnumber]` and `handler:` were added per step (the agent's own choice). Correct path: show `images` and `handler` in the `steps:` example.
5. minor - `skills/vela-apply/SKILL.md` said "same package means **same sha256**" and "Preview last". It does not say that any Release build of the **test** project also rebuilds the plugin project, and `RefreshPluginPackage` + `Deterministic=false`/`1.0.*` then regenerate `artifacts/zava.Plugins.1.0.0.nupkg` with a new hash. Observed: 8530328536b1... -> 02ab94fef83d... after `dotnet build tests/zava.Plugins.Tests/... -c Release`. Correct path: state that the package build is the last build of any kind (tests included), and take the hash and run `plan` after it.
6. minor - review-gate gaps, raised by the isolated reviewer and confirmed from `agents/vela-reviewer.agent.md` + `review-checklist.md`:
   - (a) The checklist asks that each case "has a passing test", but the reviewer has no shell and the dispatch contract passes only the diff and the Canvas. Also pass the runner summary and build line, or reword the check.
   - (b) `vela add step` handlers are `Handle<Message>`, but the SRP line names only `OnExecute`.
   - (c) There is no rule on a reused plugin whose class name no longer describes its job (here `AccountDefaultDescription` now also uppercases the account number). Renaming changes the registered type.
   - (d) There is no entry for a PreOperation edit that adds an unchanged column to the Target (Nit 2).
   - (e) There is no Spec-axis prompt for "changes" (value differs) vs "sent" (filtering-attribute semantics). This run handled it as a Canvas assumption.

Environment / agent-side (not skill defects):
7. env - The scaffold's files are CRLF. A Python read/write in the agent normalised `Account.cs` to LF (a 98-line diff), and the agent restored CRLF with perl. Recommend preserving line endings when editing scaffolded or generated files.
8. env - The agent shell is zsh, so `${PIPESTATUS[0]}` printed nothing. The RED run's exit code was not captured and is recorded in the trace as "not captured", not guessed. Later runs captured exit codes directly (`exit=0`).

## Fixes
- none yet (this run is the input for the next iteration).

## Verdict
**pass**. There is no blocking finding: every "What the skills must get right" item and all 4 success criteria are met with evidence (VELA001 seen then fixed; RED 3/10 -> GREEN 10/10 on mono xunit `-parallel none`; 0 VELA00x; isolated review PASS). The next run must re-check findings 1, 2 and 5 (repo/Canvas ordering for a new solution; demo inventory + Integrations package in `--packages-dir`; package hash stability vs test builds) and the harness trigger/image signatures (3).
