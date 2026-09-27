---
scenario: debug-filter-miss
date: 2026-09-28
verdict: fail
vela_cli: 0.19.6
framework: 0.28.2
runner: fresh subagent, local, no org
---

## Loop outcome

Setup (eval harness role):
- `vela version` → `vela 0.19.6` (exit 0).
- `vela init Zava --prefix zava -o .` → exit 0, "Scaffolding against Vela.Plugins 0.28.2", created `./Zava/` (6 projects, `zava.*`).
- `vela add plugin AccountNormalizeDescription --entity Account --message Update --filtering-attributes Name --project src/zava.Plugins/zava.Plugins.csproj` → exit 0. Generated `.PostOperation()` + `IUpdatePostContext<Account>` + `.FilterOn(e => e.Name)`.
- Hand-edited to PreOperation (`.PreOperation()`, `IUpdatePreContext<Account>`), handler trims/collapses `ctx.Request.Target.Description` (planted bug: `FilterOn(e => e.Name)` kept).
- `Account.Description` added to `Models/Generated/Account.cs` with `// STAND-IN for vela-models (no org)` (vela-plugin-authoring no-org rule).
- `dotnet build Zava.sln -c Release` → `0 Error(s)`, `4 Warning(s)` (all VELA013 in scaffold demo tests).
- Baseline suite (Mono + xunit console, `-parallel none`) → `zava.Plugins.Tests  Total: 9, Errors: 0, Failed: 0, Skipped: 0`.

Debug (agent role, `Using vela-debug-plugin to diagnose "When I edit the description, nothing happens"`):
1. Symptom: Update / account / (from code) PreOperation Sync; user changes only Description; expected trimmed + collapsed value; observed unchanged. No human to ask the one missing question ("Did anything error, or was the value saved unchanged?"), so continued on the no-org path.
2. Trace-log request recorded (no human) - see "Trace log request" below.
3. Repro (`Using vela-test-harness to reproduce the bug as a failing test`): `vela add test AccountNormalizeDescription --kind plugin --entity Account` (in the test project, exit 0). First repro per `harness-api.md` (`PluginContext.For<Account>().WithTarget(target{Description only}).WithOrganizationService(crm).Execute(new AccountNormalizeDescription(...))`) → **GREEN, not RED**: `Total: 1, Errors: 0, Failed: 0, Skipped: 0` (finding 1). Rewrote the repro with `PluginPipeline` (found in `~/.nuget/packages/vela.testing/0.28.2/lib/net462/Vela.Testing.xml`: "honouring filtering attributes") → **RED**:
   ```
   ...Update_of_description_only_fires_step_and_normalises_description [FAIL]
     Assert.Equal() Failure: Strings differ
     Expected: "Hello big world"
     Actual:   "  Hello    big   world  "
   === TEST EXECUTION SUMMARY ===
      zava.Plugins.Tests  Total: 2, Errors: 0, Failed: 1, Skipped: 0, Time: 0,122s
   ```
   The handler-only test (direct `Execute`) in the same run passed, so the logic is fine and the trigger is at fault.
4. Minimize: the update carries one column (`description`), the seed only `name`.
5. Hypothesize: `RegisterPluginSteps()` has `.FilterOn(e => e.Name)`; gotchas "a filtering attribute excludes the attribute that actually changed". Temporary probe (instrument, deleted afterwards) via `pipeline.ExecutionLog`:
   ```
   PROBE description-only: steps fired = 0
   PROBE name+description: steps fired = 1
   ```
   `vela inspect` not runnable (no org). Recorded for the human:
   `vela inspect -p artifacts/zava.Plugins.1.0.0.nupkg --url https://<org>.crm.dynamics.com --json` (or `--interactive`; flags confirmed with `vela --help`). Expected before fix: step "Update Account" PreOperation, filtering attributes `name`.
6. Instrument: `ctx.Trace` not usable (step never runs, and the harness trace output is not documented); used `ExecutionLog` (finding 2).
7. Fix (one line, `diff`):
   ```
   <                 .FilterOn(e => e.Name)
   >                 .FilterOn(e => e.Description)
   ```
   Added `Assert.Single(pipeline.ExecutionLog)` to the repro (fires once, no recursion).
8. Regression: `dotnet build Zava.sln -c Release` → `0 Error(s)`, `4 Warning(s)` (only VELA013 in `AccountPostCreatePluginTests.cs`, `SecurityExampleTests.cs`; none in authored files). Mono xunit console `-parallel none`:
   ```
   zava.Plugins.Tests  Total: 11, Errors: 0, Failed: 0, Skipped: 0, Time: 0,142s
   zava.Integrations.Tests  Total: 3, Errors: 0, Failed: 0, Skipped: 0, Time: 0,056s
   ```
   Recorded, not run (no org; never `apply`):
   `vela plan -p artifacts/zava.Plugins.1.0.0.nupkg --url https://<org>.crm.dynamics.com --json`, where the expected diff is that the Update Account step's filtering attributes change from `name` to `description`. Then `vela inspect` (same args) after a human-run apply.

### Trace log request (would be sent to the human)
"Please open Power Apps → Advanced settings → Settings → Plug-in Trace Log (or the Plugin Registration Tool). First check System Settings → Customization → 'Enable logging to plug-in trace log' is Exception or All. If it is off, turn it on and edit an account's Description once. Then paste, for `zava.Plugins.Account.Plugins.AccountNormalizeDescription` around that edit: type name, message, primary entity, stage/mode, depth, correlation id, exception details, message block. If there is **no row at all** for that edit, tell me that too."
(The last sentence is not in the skill: see finding 3.)

### Scenario checks
- Reproduce first, RED for the right reason: **met only after leaving the skill.** The skill's recipe gave a false green. The pipeline repro is RED because the step fired 0 times (ExecutionLog evidence).
- Hypothesis from the registration + gotchas, no trial-and-error, no org mutation: met (registration read, gotcha named, probe evidence, no org calls).
- Single-cause fix, red → green, nothing else changed: met (1-line diff; the test file is the only other change).
- `vela inspect` recorded: met (command above).
- Success criteria 1 (RED before code change): met (Failed: 1 before the diff). Criterion 2 (one-line fix, suite green): met (11/11 + 3/3). Criterion 3 (names gotcha + evidence): met. Criterion 4 (trace request says where + fields, no reading around the CLI): met.

### Hidden knowledge relied on
- At step 3, the skill's own recipe went green. Nothing in the skill says what to do then. I suspected that direct `Execute` bypasses `FilterOn`, and I searched the package's XML doc for "filter". That came from my knowledge of the planted bug, not from the skill.

## Findings

Skill defects:

1. **blocker** - `skills/vela-debug-plugin/SKILL.md` step 3 says "write a failing harness test (`vela-test-harness`, `references/harness-api.md`) ... Cascades and recursion: use `PluginPipeline`", and step 5 lists "filtering attribute excludes the changed attribute (step never fires)" as the first usual suspect. `references/harness-api.md` gives only `PluginContext.For<T>()...Execute(plugin)` for plugins and `PluginPipeline` for cascades. `vela-test-harness` Coverage asks for a "filtering attribute" case without saying how. What happened: the documented recipe runs the handler whatever `FilterOn` says. A description-only update against `FilterOn(e => e.Name)` passed: `zava.Plugins.Tests  Total: 1, Errors: 0, Failed: 0, Skipped: 0`. That is a false green, and the skill's usual suspect #1 cannot be reproduced. The API was rediscovered from `Vela.Testing.xml` ("honouring filtering attributes"). Correct path: filtering-attribute / "step never fires" repros must go through the pipeline:
   `var p = PluginPipeline.Empty().Register<AccountNormalizeDescription>().Seed(new Account { Id = id, Name = "Zava" }); p.Service.Update(new Account { Id = id, Description = "  a   b " }); Assert.Equal("a b", p.Service.Retrieve("account", id, new ColumnSet("description")).GetAttributeValue<string>("description")); Assert.Single(p.ExecutionLog);`
   Also state in harness-api/test-harness that `PluginContext...Execute` does not apply filtering attributes (so a filter-gated test there is meaningless). Add a debug-skill branch: "direct-Execute repro is green → the fault is in the trigger/registration → repro through `PluginPipeline`".
2. minor - `skills/vela-debug-plugin/SKILL.md` step 6: "add `ctx.Trace(...)` lines for the values you need, reproduce, read the message block". What happened: a step that never fires emits no trace. `harness-api.md` also does not document how to read `ctx.Trace` output in the harness. The useful instrument was `pipeline.ExecutionLog` (`steps fired = 0` vs `1`), which harness-api mentions only as "inspect `pipeline.ExecutionLog`", without its shape. Correct: document `ExecutionLog` (an ordered list of `PipelineExecutionEntry`, e.g. `.Count`) as the instrument for "did it fire?", and say how to read the trace in the harness.
3. minor - `skills/vela-debug-plugin/SKILL.md` step 2 asks for "the Plug-in Trace Log row(s) of the failing operation" with "exception details" and "message block". For a step that never fires there is no row, and the skill does not say that a missing row is itself evidence (it points at the registration/filter, and away from the code). Correct: add "No row for the operation (with tracing on) → the step did not fire: check message/entity/stage/filtering attributes with `vela inspect`."
4. minor - `skills/vela-plugin-authoring/SKILL.md` Red flags: "a written column that is also in the step's `FilterOn` (recursion)". `references/dataverse-gotchas.md` has "keep written columns out of the step's filtering attributes". The prescribed fix (`FilterOn(e => e.Description)`) puts the written column in `FilterOn`, so a literal reviewer (`vela-code-review`) would flag the correct fix. In PreOperation, editing `ctx.Request.Target` causes no second write: the pipeline test shows `Assert.Single(pipeline.ExecutionLog)` passing. Correct: scope the rule to write-backs (`ctx.UserService.Update` of the same record, PostOperation). PreOperation edits of `Target` may, and often must, filter on the column they normalise.
5. minor (setup) - `skills/vela-scaffold/references/cli-surface.md` for `add plugin`: "Generates a **single-step** plugin whose handler is `OnExecute`". `registration-rules.md` says to normalise "→ PreOperation". What happened: `vela add plugin ... --message Update` always emits `.PostOperation()` + `IUpdatePostContext<Account>`, and there is no `--stage` flag (`vela add plugin --help`). Neither skill says the stage must then be hand-changed (`.PreOperation()` + `IUpdatePreContext<Account>`), which conflicts with vela-scaffold's "Generated code must compile and apply **without hand edits**". Correct: document that `add plugin` emits PostOperation. For a same-row edit, change `.PostOperation()`→`.PreOperation()` and the context `I<Msg>PostContext`→`I<Msg>PreContext` in the authored plugin.
6. minor (setup) - `skills/vela-scaffold/SKILL.md` step 2: "`vela init <Name> [--prefix <pub>] [-o <dir>]` ... emits 6 projects under `src/` + `tests/`". What happened: `vela init Zava --prefix zava -o .` created `./Zava/src`, `./Zava/tests`, so `-o` is the parent and the solution folder is nested. The projects are lowercase `zava.*` (from the prefix), not `<Prefix>.`-cased. Correct: state that the solution lands in `<output>/<Name>/`.

Environment issues (not skill defects): none blocking. Mono + xunit console 2.9.2 with `-parallel none` worked as documented. The 4 VELA013 warnings come from scaffold demo tests, as documented.

## Fixes
- none yet (eval run only; findings 1-6 to be addressed in the pack).

## Verdict
fail: finding 1 is a blocker. Following `vela-debug-plugin` + `harness-api.md` literally produced a green "repro" of a real bug. A RED repro for the right reason needed `PluginPipeline`, which the skills reserve for cascades/recursion, and the API came from the package XML doc. The rest of the loop passed (one-line fix, suite green 11/11 + 3/3, gotcha named, trace request well-formed, no org access). The next run must re-check: the skill steers a filtering-attribute repro to `PluginPipeline` without hidden knowledge; the red flag in finding 4 no longer contradicts the fix; the no-row trace case is covered.

## Fixes (iteration 1)

f6b5aa3 (harness: Execute ignores FilterOn - PluginPipeline for fires/does-not-fire; missing trace row; ExecutionLog), add212a (recursion rule scoped to write-backs; stage edit; init nesting)

Next: re-run this scenario against the fixed skills and record iteration 2.
