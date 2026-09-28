---
scenario: bulk-update-multiple
date: 2026-09-29
verdict: fail
vela_cli: 0.21.0
framework: 0.29.3
runner: fresh subagent, local, no org
---

## Loop outcome
- Intake/Plan/Challenge (vela-plan-review): Canvas drafted outside the project. Message = **UpdateMultiple**,
  PreOperation, Sync, FilterOn(Name), new plugin, no service. Reason: one execution per batch, and Dataverse
  merges the Update/UpdateMultiple pipelines on standard tables, so no Update step is added for the same logic.
  Flagged assumptions: `--prefix tbd` placeholder (blocks apply), merged pipeline, Trim semantics.
- Scaffold: `vela init AccountBulk --prefix tbd --no-integrations --no-console -o <scratch>` exit 0 (resolved
  Vela.Plugins 0.29.3). `git init` + baseline commit, feature branch, 18 demo files removed.
  `dotnet build` 0 warn / 0 err. `vela add plugin AccountBulkNameTrim --entity Account --message UpdateMultiple
  --filtering-attributes Name` exit 0: generated `OnUpdateMultiple().PostOperation()` + `IUpdateMultiplePostContext`,
  edited to PreOperation / `IUpdateMultiplePreContext`, build clean.
- Model: skipped (no org). Would run: `vela models --entities account --out src/tbd.Shared/Models/Generated --overwrite --url <org>`.
  `Account.Name` is in the scaffold model, so no stand-in was needed.
- Test RED: `vela add test AccountBulkNameTrim --kind plugin --entity Account` exit 0. The 7 tests use `.OnMessage("UpdateMultiple")
  .Stage(PluginStages.PreOperation).WithTargets(...)`. Mono xunit 2.9.2 `-parallel none` gave `Total: 7, Errors: 0, Failed: 6`
  (exit 1). The guard `Handler_makes_no_per_record_write` passed, as expected.
- Canvas sync: added 2 PluginPipeline cases (runtime-shaped plain `Entity` targets saved; single Update also fires).
  RED against the stashed stub gave `Total: 9, Errors: 0, Failed: 8`.
- Implement: loop over `ctx.Request.Targets.Entities`, `ToEntity<Account>()` typed view, trim when changed. No org write.
- Verify: `dotnet build AccountBulk.sln -c Release --no-incremental` gave 0 Warning(s), 0 Error(s), no VELA. GREEN gave
  `Total: 9, Errors: 0, Failed: 0, Skipped: 0` (exit 0).
- Review: isolated vela-reviewer subagent returned **PASS** with 4 Nits (guard case not marked in the DoD; placeholder step
  description; unused `using Vela.Constants`; models not verified against an org).
- Package: `dotnet build -c Release` with artifacts cleared produced `tbd.Plugins.1.0.0.nupkg`, which contains `lib/net462/tbd.Plugins.dll`,
  sha256 `98203226143bf0f94e2e5a34ccaf3fdb747f0c15b9261fec491096ea18b0db1b`. `vela plan -p artifacts/tbd.Plugins.1.0.0.nupkg
  --url <org> --out plan.json` was skipped (no org). Build Report committed at `docs/vela-builds/account-bulk-name-trim.md`.
  Stopped at the apply gate. Draft PR skipped (eval).

### Scenario checks
- Message choice recorded with reason: **yes**. It came from the agent's own Dataverse knowledge, not from the pack (finding 3).
- Bulk surface: iterates the batch and edits each target in PreOperation, with no per-record `Update`. **Yes**, but the API had
  to be rediscovered (finding 2).
- Tests use `.OnMessage("UpdateMultiple")` + `WithTargets(...)` and cover several spaced records, a record with no name,
  and a mixed batch. **Yes**, but the reference's stage/mode recipe had to be changed (finding 1).
- Success criteria 1-3 are met: Canvas decision, RED then GREEN with no per-record write, build clean, review PASS. The verdict is
  still **fail** because the pack did not lead there by itself: findings 1-3 are blockers.

## Findings
1. **blocker**: `skills/vela-test-harness/references/harness-api.md` (same text in every copy) says: "use
   `.OnMessage("UpdateMultiple")` with `.Stage(PluginStages.PostOperation).Async()` and seed the batch via `WithTargets(...)`".
   - **What happened:** used as written against a PreOperation step, it throws:
     `InvalidPluginExecutionException : Plugin 'tbd.Plugins.Account.Plugins.AccountBulkNameTrim' has no registered step matching message 'UpdateMultiple'.`
   - **Why it matters:** it also steers the author toward PostOperation/Async, where target edits are lost (a Critical per
     review-checklist).
   - **Correct recipe:** state the stage the step is registered with: `.OnMessage("UpdateMultiple").Stage(PluginStages.PreOperation)`.
     For a single-step plugin, `.WithTargets(...)` alone also works: the trigger auto-derives, and the probe trimmed with no trigger stated.
2. **blocker**: `skills/vela-plugin-authoring/references/plugin-authoring-api.md` says "Context type per message:
   `ICreatePostContext<T>` / `ICreatePreContext<T>`, and the same for Update/Delete". It also says to prefer `ctx.Request.Target`,
   and that `GetTargets` (bulk) remains only for `ILocalPluginContext` handlers.
   - **What's missing:** nothing on the bulk handler. `vela add plugin --message UpdateMultiple` generates `IUpdateMultiplePostContext<Account>`, and on
     that context `ctx.Request` is the **untyped SDK `Microsoft.Xrm.Sdk.Messages.UpdateMultipleRequest`**. There is no `Target`, and
     `Targets.Entities` holds plain `Entity` objects. `ctx.BulkTargets` (an `EntityCollection`, null when not bulk) also exists.
   - **How it was found:** from `Vela.Plugins.xml` and a compile probe (`error CS0029: Cannot implicitly convert type
     'Microsoft.Xrm.Sdk.Messages.UpdateMultipleRequest' to 'int'`).
   - **Correct API:** `foreach (var e in ctx.Request.Targets.Entities) { var a = e.ToEntity<Account>(); a.Name = ...; }`.
     `ToEntity` shares the attribute collection, so the typed edit reaches the live target. This was verified with `PluginPipeline`
     and plain `Entity` targets: the saved value is trimmed.
   - **Also document:** `IUpdateMultiplePreContext` / `ICreateMultiplePreContext` and "no per-record Update in the loop".
3. **blocker**: the scenario lists `gotchas_exercised: [bulk-multiple, bulk-targets, per-record-vs-bulk]`, but `references/dataverse-gotchas.md`
   has **no bulk entry**.
   - `vela-plan-review` SKILL.md only asks "Create vs Update vs *Multiple?" with no decision rule.
   - The `registration-rules.md` legal matrix has no CreateMultiple/UpdateMultiple rows.
   - The merged-pipeline fact is missing: an Update step runs per record of an UpdateMultiple, an UpdateMultiple step runs for a single
     Update on standard tables, elastic tables are not merged, so don't register both.
   - The framework's own XML doc on `PluginMessages.UpdateMultiple` states it ("Dataverse also runs single Update steps per row").
   - The harness `PluginPipeline` confirms it: a single `Service.Update` fired the UpdateMultiple step (`ExecutionLog` count 1, name saved trimmed).
   - **Fix:** add a bulk gotcha (per-batch vs per-record, merged pipelines, no per-record write, FilterOn semantics on a batch), plus
     the *Multiple rows in the matrix and a decision rule in plan-review.
4. minor: `harness-api.md` doesn't document these (all verified here):
   - `WithTargets(params T[])` keeps the passed instances, so asserting on them works.
   - `PluginPipeline` supports bulk: `pipeline.Service.Execute(new UpdateMultipleRequest { Targets = ... })` runs the step once
     (`run.Message == "UpdateMultiple"`, `Stage PreOperation`) and persists the edit.
   - A single `Update` also fires an UpdateMultiple step.
   - Without the pipeline recipe, the "saved value" and "merged pipeline" assumptions can't be tested. They were added after
     GREEN, and RED was re-proven with the implementation stashed.
5. minor: `skills/vela-code-review/references/review-checklist.md` has no bulk-specific checks: a per-record `Update`/`Execute` inside the batch loop,
   an Update and an UpdateMultiple step registered for the same logic, or a typed copy whose edit doesn't reach the target. The
   reviewer covered these from general knowledge.
6. minor: `vela-scaffold` step 5's generic rewrite (`I<Message>PostContext<E>` → `I<Message>PreContext<E>`) worked for
   `IUpdateMultiplePostContext` → `IUpdateMultiplePreContext`, but *Multiple isn't named. One line would confirm it.

### Environment (not skill findings)
- `vela init` resolved Vela.Plugins/Vela.Testing **0.29.3** (the pack verified 0.29.1). There was no incompatibility.
- zsh reads a bare `=====` as `=`-expansion (`echo =====` fails). This was the agent's own shell usage.

## Fixes
- none yet (eval run)

## Verdict
**fail.** The build reached a correct, reviewed (PASS), green, analyzer-clean result, but only after the recipe was changed
(finding 1), the bulk API was rediscovered (finding 2), and the message decision rested on knowledge the pack doesn't carry
(finding 3). The next run must re-check:
- plan-review/gotchas give the UpdateMultiple-vs-Update rule;
- plugin-authoring-api documents `ctx.Request.Targets` / `BulkTargets` with a typed edit pattern;
- the harness bulk recipe matches the step's stage and includes a PluginPipeline bulk case.

## Fixes

Fixed in this PR: harness bulk recipe (stage of the registered step, WithTargets, pipeline UpdateMultipleRequest), bulk handler shape (ctx.Request.Targets + ToEntity<T>), merged-pipeline gotcha, registration rows, review checks.
