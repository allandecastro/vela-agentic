---
name: vela-test-harness
description: Use when a Vela plugin's behaviour needs proving without a real Dataverse org, including writing the failing (RED) tests before implementation and reproducing a reported bug as a failing test.
compatibility: "vela CLI >= 0.21.0 (Vela.Plugins >= 0.29.1); dotnet SDK."
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
- each **edge** the spec implies (empty / null / invalid / boundary);
- each **applicable gotcha** (`references/dataverse-gotchas.md`): image present, filtering
  attribute, Associate/Disassociate matching, bulk `*Multiple`;
- on **Update**: a column **not sent** vs a column **cleared** (sent as null) - they are different
  (`ctx.Request.Target` only holds the columns that were sent). For a column that can't be cleared
  (e.g. `statecode`), test "sent with the same value" instead.
A single happy-path test does not satisfy the gate.

**Pick the runner by what the case proves** (`references/harness-api.md`): `PluginContext...Execute`
for what the handler does; **`PluginPipeline`** for whether the step fires at all - `Execute`
ignores `FilterOn`, so a "does not fire" case written with it passes and proves nothing.

## Process

Announce: `Using vela-test-harness to <purpose>`.

1. Ensure a `.Tests` project references `Vela.Testing` (the scaffold includes one; else
   `vela add test <Name> --kind plugin --entity <Entity>`).
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
   Pass a **plugin instance** to `Execute(...)` (there is no `.Execute<T>()`). Do **not** chain
   `.OnUpdate().Stage().Mode()` for a single-step plugin - it auto-derives.
3. Write the full **Coverage** set above (not just the happy path).
4. **RED first (mandatory):** run the tests before implementing and confirm the behaviour cases
   **fail** for the right reason. Guard / no-op cases ("already normal", "null → untouched",
   "does not fire") may pass before any code exists - that is expected; list which ones in the
   report. Only then hand off to `vela-plugin-authoring` to implement to green.
5. Run with the **OS-correct runner** (see `references/harness-api.md`):
   - Windows: `dotnet test <path>.Tests.csproj -c Release`.
   - macOS/Linux: `dotnet test` cannot run net462 - build, then
     `mono .../xunit.console.exe <dll> -parallel none`.

## Rationalizations (excuse → rebuttal)

- "It builds, that's enough." → A green build proves nothing about behaviour. The harness is
  the evidence.
- "`.Execute<MyPlugin>()` should work." → It doesn't exist. Pass an instance:
  `.Execute(new MyPlugin(string.Empty, string.Empty))`.
- "`dotnet test` failed, the tests are broken." → On macOS/Linux `dotnet test` can't host
  net462 at all. Use the Mono runner. And a Mono `segv` without `-parallel none` is an
  environment crash, not a test failure.
- "I'll test it on the org." → The org is for `apply`, gated. Prove it locally first.

## Red flags

- Claiming success from `dotnet build` alone, or from a partial/crashed test run.
- Using `.Execute<T>()`, or restating `.OnUpdate().Stage().Mode()` on a single-step plugin.
- A "step does not fire" / filtering-attribute case written with `Execute` instead of `PluginPipeline`.
- Reporting a Mono native segv (missing `-parallel none`) as a test failure.

## Verification

- The tests were seen to **fail first** (RED), then pass after implementation.
- The runner reports **all green** - paste the summary line and name the runner used - and the
  green cases match the declared acceptance cases.
- The **authored code** (your plugin + your tests) is **clean of analyzer (VELA00x) violations**
  (part of the quality gate). The scaffold's demo files may carry cosmetic VELA013 - clean or
  remove them for a real project; don't let a demo warning hide a real one in your code.
  Without all three, the loop does not proceed to `vela plan`/`apply`.
