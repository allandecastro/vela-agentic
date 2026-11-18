---
name: vela-plugin-testing
description: Use when a Vela plugin's behaviour needs proving without a real Dataverse org, including writing the failing (RED) tests before implementation and reproducing a reported bug as a failing test.
compatibility: "vela CLI + dotnet SDK."
license: MIT
metadata:
  version: "0.1.2"
---

# Verify with the Vela.Testing harness

> Paths like `references/<file>.md` in this skill are relative to **this skill's folder** (the
> directory containing this `SKILL.md`), not to the project you are working in.

Prove plugin behaviour locally with **`Vela.Testing`**; nothing deploys until it is green. **Read
`references/harness-api.md` first** (API, runner commands); this is the workflow.

## When to use

- **Before** authoring logic (test-first), then implement to green (`vela-plugin-authoring`).
- To reproduce a reported bug as a failing test before fixing it.

## Coverage (mandatory - no happy-path-only)

One case for each, from the Canvas's acceptance cases:
- the **primary behaviour**;
- a **transformation** (upper-case, trim...): already in form, fully not, and **mixed** (`abc` / `ABC` /
  `aBc-1`);
- each **edge** (empty / null / invalid / boundary) - for text, `""`, `null` and whitespace-only are three
  cases;
- each **applicable gotcha** (`references/dataverse-gotchas.md`): image, filtering attribute,
  relationship scope, bulk `*Multiple`, async step (failure lands in `AsyncStepFailures`, not thrown);
- on **Update**: column **not sent** vs **cleared** (sent as null) - different cases. A column that can't
  be cleared (`statecode`): "sent with the same value" instead. On **Create**, a filtered column sent as null
  is its own case too;
- a **bug repro** covers the class of inputs, not only the reported value (a host with and without a dot);
- negative pipeline cases ("same value" **and** "cleared") assert the step **ran** (`ExecutionLog`,
  `HandlerInvoked`) and left the value alone - else a broken trigger passes too. "Does not fire" asserts
  `Assert.Empty(p.ExecutionLog)` (filter not matched) or `HandlerInvoked == false` (skipped: out of
  `ForRelationship` scope, depth guard) - plus the effect.
- what must **not** change is asserted when the story depends on it (the other columns, no extra write) -
  untested behaviour is unprotected;
- a "does nothing" case **seeds the state the bug would change** (reactivation: an *active* contact stays
  active) - a start state already equal to the expected one proves nothing;
- a read of other rows (a lookup, a query) **seeds a non-matching row too** (another account, an inactive
  contact) - with a single row seeded, a dropped filter still passes;

**Runner per case:** **`PluginPipeline` by default** - it runs the registration as Dataverse does (filters,
images, ranks, cascades, async); a class with several steps on one trigger is tested through it, on their combined
effect. `PluginContext...Execute` only for an edge the pipeline cannot set up (`references/harness-api.md`) - it
ignores `FilterOn`, stage/mode and registered images, so a "does not fire" case with it proves nothing.

## Process

Announce: `Using vela-plugin-testing to <purpose>`.

1. `vela init` scaffolds a `.Tests` project (unless `--no-tests`). Run `vela add test <Name> --kind plugin --entity <Entity> --message <M>` **inside the test project**; after
   `vela add step`, re-run it with the new message (it completes the class; no `--force`). Fill the
   generated tests: real value for the filtered column, replace `todo_*` placeholders, un-skip the stub.
   `--kind customapi`: set the inputs, remove `Skip`.
2. Write the tests in the real shape (`references/harness-api.md`), e.g.
   ```csharp
   var p = PluginPipeline.Empty().Register<AccountPlugin>();
   var id = p.Service.Create(new Account { Name = "Zava" });
   var saved = p.Service.Retrieve<Account>(id, a => a.Description);                 // using Vela.Context;
   Assert.Equal("Created via Vela plugin", saved.Description);                       // what was saved
   ```
3. Write the full **Coverage** set.
4. **RED first (mandatory):** behaviour cases **fail** for the right reason before any logic; a no-op case
   that passes at RED asserts the handler ran (`HandlerInvoked`) or is backed by a mutation check (guard/no-op
   cases may pass - list them). **Commit the RED tests alone** (provable in git), then hand off.
5. Run with the **OS-correct runner** (`references/harness-api.md`): Windows `dotnet test`; macOS/Linux
   Mono + xunit console with `-parallel none`. Run every test assembly (`<P>.Integrations.Tests` too).

## Tests carry their functional case

- Every test carries the id of the registry case it proves: `[Trait("Case", "ACC-002/C1")]` (cases are in
  `docs/rules/<table>.md`, written at design). No test without its functional
  justification - technical ones included (a generated `Fires_On_*` proves a case's trigger: tag it with that
  case). A test without a case id, or with an id not in the registry, fails `spec-check`.
- **Regression tests are not yours to bend.** A test that existed before the story and now fails means the code
  is wrong - fix the code, in its own commit, and record it in the Build Report (a regression found, not part
  of the story). Modify or delete an existing test only when its rule is listed in the Canvas `rules:`
  as `change` or `retire`, and keep it faithful to the case's Given/When/Then. A `PluginContext` test that breaks
  because its class gains a step on the same trigger moves to `PluginPipeline` (same data, action, assertion,
  case id): declare its rule `{id: ..., change: tests}` - the rule text stays, every case keeps a test. If you believe the spec itself is
  wrong, stop and go back to design (ask the human); never edit `docs/rules/` during the build (its
  `Implementation:` / `Tests:` trace lines aside, and a review-driven amendment listed in the Canvas `amendments:`).
- **CS0118** (a `...Tests.<Table>` namespace hides the model type): keep the usings inside the namespace, as the
  scaffold's `.editorconfig` asks.
- **Never encode a harness divergence** in a test (e.g. computed columns such as `fullname` are not computed) -
  Vela's [limitations](https://allandecastro.github.io/vela/reference/limitations) page.
- **A removed step** is tested too: through the pipeline, the message no longer runs the handler
  (`Assert.Empty(p.ExecutionLog)`), and `vela plan` shows the `delete step`.

## Rationalizations (excuse → rebuttal)

- "It builds, that's enough." → A green build proves nothing about behaviour.
- "`Execute` passed, so the step fires." → `Execute` ignores the registration. Prove firing and saving
  with `PluginPipeline`.
- "`dotnet test` failed, the tests are broken." → On macOS/Linux it can't host net48; use Mono. A Mono
  segv without `-parallel none` is an environment crash, not a test failure.
- "I'll test it on the org." → The org is for the gated `apply`.

## Red flags

- Claiming success from `dotnet build` alone, or from a partial/crashed run.
- The generated "fires" test as the only assertion, or `Does_What_It_Should` left skipped.
- A "does not fire" / filtering case written with `Execute` instead of `PluginPipeline`.
- A Mono segv (missing `-parallel none`) reported as a test failure.

## Verification

- Tests seen **RED**, then green after implementation.
- The runner reports **all green** - paste the summary line, name the runner - and the green cases
  match the declared acceptance cases.
- **Authored code** (plugin + tests) has no VELA00x violations. Without all three, no `plan`/`apply`.
