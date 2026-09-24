---
name: vela-test-harness
description: Use to prove a Vela plugin works WITHOUT a real Dataverse org, using the Vela.Testing harness (PluginContext + InMemoryOrganizationService) run via the OS-correct runner. This is the verification gate before any deploy.
---

# Verify with the Vela.Testing harness

Prove plugin behaviour locally with **`Vela.Testing`** — no real org. This is the verification
gate: nothing proceeds to deploy until the harness is green.

**Read `references/harness-api.md` before writing a test.** It has the verbatim API; the notes
below are the workflow.

## When to use

- After authoring logic, to prove it before `vela plan`/`apply`.
- To reproduce a reported bug as a failing test before fixing it.

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
   `.OnUpdate().Stage().Mode()` for a single-step plugin — it auto-derives.
3. Cover the story's behaviour plus a case for each applicable gotcha (image present,
   filtering attribute, association matching).
4. Run with the **OS-correct runner** (see `references/harness-api.md`):
   - Windows: `dotnet test <path>.Tests.csproj -c Release`.
   - macOS/Linux: `dotnet test` cannot run net462 — build, then
     `mono .../xunit.console.exe <dll> -parallel none`.
5. Red→green when fixing a bug: see it fail first, then pass.

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
- Reporting a Mono native segv (missing `-parallel none`) as a test failure.

## Verification

- The test runner reports all green — **paste the summary line** and name the runner used.
  Without it, the loop does not proceed to `vela plan`/`apply`.
