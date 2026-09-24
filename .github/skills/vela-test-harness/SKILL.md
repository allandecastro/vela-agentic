---
name: vela-test-harness
description: Use to prove a Vela plugin works WITHOUT a real Dataverse org, using the Vela.Testing harness (PluginContext / PluginPipeline) run via dotnet test. This is the verification gate before any deploy.
---

# Verify with the Vela.Testing harness

Prove plugin behaviour locally with the **`Vela.Testing`** package — no real org needed.
This is the verification gate: nothing proceeds to deploy until the harness is green.

## When to use

- After authoring logic, to prove it before `vela plan`/`apply`.
- To reproduce a reported bug as a failing test before fixing it.

## Process

Announce: `Using vela-test-harness to <purpose>`.

1. Ensure a `.Tests` project references `Vela.Testing` (scaffold includes one by default;
   otherwise `vela add test <Name> --kind plugin`).
2. Write a test. Single-plugin fluent style:
   ```csharp
   var result = PluginContext.For<Account>()
       .OnUpdate()
       .Stage(PluginStages.PostOperation)
       .Mode(ExecutionMode.Synchronous)
       .WithPreImage(new Account { /* prior values */ })
       .WithTarget(new Account { Name = "Zava" })
       .Execute<AccountPostUpdate>();
   ```
   For custom APIs / message-only plugins: `PluginContext.ForMessage("vela_DoThing")` with
   `WithInputParameter` / `WithOutputParameter`. For multi-step cascades, use
   `PluginPipeline.FromAssemblyOf<T>()`, `Register<TPlugin>()`, `Seed(...)`, then write
   through `pipeline.Service` and inspect `pipeline.ExecutionLog`.
3. Cover the real behaviour from the spec, and add a case for each gotcha that applies
   (image present, filtering attribute, association matching).
4. Run: `dotnet test <path-to>.Tests.csproj`.
5. Red→green: if fixing a bug, see the test fail first, then pass.

## Rationalizations (excuse → rebuttal)

- "It builds, that's enough." → A green build proves nothing about behaviour. The harness is
  the evidence.
- "I'll test it directly on the org." → The harness is faster, free, and side-effect-free.
  Prove it locally first; the org is for `apply`, gated.
- "One happy-path test is fine." → Add the edge the spec implies and the gotcha cases.

## Red flags

- Claiming success from `dotnet build` alone.
- No test for the specific behaviour the story asked for.
- Stale NuGet cache: purge `vela.testing` under `~/.nuget` if you built against an old package.

## Verification

- `dotnet test` reports all green — **paste the summary line**. This is the gate; without it
  the loop does not proceed to `vela plan`/`apply`.
