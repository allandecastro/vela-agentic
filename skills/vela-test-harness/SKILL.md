---
name: vela-test-harness
description: Use when a Vela plugin's behaviour needs proving without a real Dataverse org, including writing the failing (RED) tests before implementation and reproducing a reported bug as a failing test.
compatibility: "vela CLI >= 0.26.0 (Vela.Plugins / Vela.Testing >= 0.35.0); dotnet SDK."
---

# Verify with the Vela.Testing harness

> Paths like `references/<file>.md` in this skill are relative to **this skill's folder** (the
> directory containing this `SKILL.md`), not to the project you are working in.

Prove plugin behaviour locally with **`Vela.Testing`** - no real org. This is the verification
gate: nothing proceeds to deploy until the harness is green.

**Read `references/harness-api.md` before writing a test.** It has the verbatim API; the notes
below are the workflow.

## When to use

- **Before** authoring logic - test-first: write the failing tests for the acceptance cases,
  then implement to green (`vela-plugin-authoring`).
- To reproduce a reported bug as a failing test before fixing it.

## Coverage (mandatory - no happy-path-only)

Write a case for each, drawn from the Vela Canvas's acceptance cases:
- the **primary behaviour** from the story;
- for a **transformation** (upper-case, trim, normalise...), one case per input class: already in the
  target form, fully not, and **mixed** (e.g. `abc` / `ABC` / `aBc-1`);
- each **edge** the spec implies (empty / null / invalid / boundary) - for text, `""`, `null` and
  whitespace-only are three cases;
- each **applicable gotcha** (`references/dataverse-gotchas.md`): image present, filtering
  attribute, Associate/Disassociate relationship scope, bulk `*Multiple`, async step (runs after the
  commit; a failure lands in `AsyncStepFailures`, not thrown);
- on **Update**: a column **not sent** vs a column **cleared** (sent as null) - they are different
  (`ctx.Request.Target` only holds the columns that were sent). For a column that can't be cleared
  (e.g. `statecode`), test "sent with the same value" instead.
- negative pipeline cases - **both** "sent with the same value" and "cleared" - each assert the step **ran** (`ExecutionLog`,
  `HandlerInvoked`) and left the value alone - otherwise it also passes with a broken trigger. A "does
  not fire" case asserts `Assert.Empty(p.ExecutionLog)` (filter not matched), or `HandlerInvoked == false`
  for a step the pipeline skipped (out of `ForRelationship` scope, depth guard) - plus the effect.
A single happy-path test does not satisfy the gate.

**Pick the runner by what the case proves** (`references/harness-api.md`): `PluginContext...Execute`
for what the handler does; **`PluginPipeline`** for whether the step fires at all, what is saved, images
and async steps - `Execute` ignores `FilterOn`, the registered stage/mode and the registered images, so a
"does not fire" case written with it passes and proves nothing.

## Process

Announce: `Using vela-test-harness to <purpose>`.

1. Ensure a `.Tests` project references `Vela.Testing` (`vela init` scaffolds one unless `--no-tests`).
   Add a test class with `vela add test <Name> --kind plugin --entity <Entity> --message <M>`, run
   **inside the test project**. After `vela add step`, run it again with the new message: it **completes the
   existing class** with the new step's tests (vela >= 0.26, verified) - no `--force`, which would overwrite. It generates a `PluginPipeline` test that the step fired
   (`Assert.Contains(pipeline.ExecutionLog, e => e.PluginTypeName == ... && e.Message == "<M>")`) and a
   skipped "read back what the plugin wrote" stub: give the filtered column a real value, replace the
   `todo_*` placeholders (Associate: the real relationship), then un-skip and fill the stub. A Custom API
   (`--kind customapi`) gets a unique-name test and a skipped execution test - set its inputs, remove `Skip`.
2. Write the test using the **real** shape (see `references/harness-api.md`):
   ```csharp
   var crm = new InMemoryOrganizationService();
   var target = new Account { Id = Guid.NewGuid() };
   PluginContext.For<Account>()
       .WithTarget(target)
       .WithOrganizationService(crm)
       .Execute(new AccountDefaultDescription(string.Empty, string.Empty));
   // assert by reading records back from crm
   ```
   `Execute(new X(string.Empty, string.Empty))` or `.Execute<X>()` (both work since 0.33.0). Do **not**
   chain a trigger for a single-step plugin - it auto-derives; for a multi-step plugin state the message
   of the step under test (`.OnUpdate()`), and add `.Stage(...)` only when several steps share it.
3. Write the full **Coverage** set above (not just the happy path).
4. **RED first (mandatory):** run the tests before implementing and confirm the behaviour cases
   **fail** for the right reason. Guard / no-op cases ("already normal", "null → untouched",
   "does not fire") may pass before any code exists - that is expected; list which ones in the
   report. **Commit the RED tests on their own** (before any logic) so RED is provable from the git
   history. Only then hand off to `vela-plugin-authoring` to implement to green.
5. Run with the **OS-correct runner** (see `references/harness-api.md`):
   - Windows: `dotnet test <path>.Tests.csproj -c Release`.
   - macOS/Linux: `dotnet test` cannot host net48 - build, then
     `mono ~/.nuget/packages/xunit.runner.console/2.9.2/tools/net472/xunit.console.exe
     tests/<P>.Plugins.Tests/bin/Release/net48/<P>.Plugins.Tests.dll -parallel none`.
     Run each test assembly (`<P>.Integrations.Tests` too, when the project has one).

## Rationalizations (excuse → rebuttal)

- "It builds, that's enough." → A green build proves nothing about behaviour. The harness is
  the evidence.
- "`Execute` passed, so the step fires." → `Execute` runs the handler whatever the registration says
  (filter, stage, mode, images). Prove firing and saving with `PluginPipeline`.
- "`dotnet test` failed, the tests are broken." → On macOS/Linux `dotnet test` can't host
  net48 at all. Use the Mono runner. And a Mono `segv` without `-parallel none` is an
  environment crash, not a test failure.
- "I'll test it on the org." → The org is for `apply`, gated. Prove it locally first.

## Red flags

- Claiming success from `dotnet build` alone, or from a partial/crashed test run.
- Restating a trigger on a single-step plugin, or no message on a multi-step one.
- Keeping the generated "fires" test as the only assertion, or leaving `Does_What_It_Should` skipped.
- A "step does not fire" / filtering-attribute case written with `Execute` instead of `PluginPipeline`.
- Reporting a Mono native segv (missing `-parallel none`) as a test failure.

## Verification

- The tests were seen to **fail first** (RED), then pass after implementation.
- The runner reports **all green** - paste the summary line and name the runner used - and the
  green cases match the declared acceptance cases.
- The **authored code** (your plugin + your tests) is **clean of analyzer (VELA00x) violations**
  (part of the quality gate). Without all three, the loop does not proceed to `vela plan`/`apply`.
