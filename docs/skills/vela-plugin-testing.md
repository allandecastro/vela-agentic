---
_description: "The vela-plugin-testing skill: failing tests first with PluginPipeline, full coverage of the acceptance cases"
---

# vela-plugin-testing

This page describes `vela-plugin-testing`, the skill that proves a plugin's behaviour without an org. It is for
developers who read the tests an agent wrote and want to know what coverage to expect.

## When it triggers

Before the plugin logic is written (tests first), after implementation to verify, and to reproduce a reported bug
as a failing test.

## What it does

It writes the tests with `Vela.Testing` and runs them with `PluginPipeline`, the harness that runs the registration
as Dataverse does: filters, images, ranks, cascades and async steps. See [Testing](../../guides/testing.md).

1. Fills the test class `vela add test` generates, then writes one test per acceptance case.
2. Runs them and sees them **fail** for the right reason before any logic exists. The failing tests are committed
   alone, so the order is visible in git.
3. After implementation, runs the full suite with the runner for the OS: `dotnet test` on Windows, Mono with the
   xUnit console runner and `-parallel none` on macOS and Linux.

### Coverage

A happy-path-only suite blocks the gate. The skill requires a case for the primary behaviour, each edge (empty,
null, whitespace, boundary), each pitfall that applies (images, filtering columns, relationship scope, bulk
messages, async steps), and on Update both "column not sent" and "column cleared". A "does nothing" case seeds the
state a bug would change, and a query test seeds a row the filter must exclude.

### Each test cites its case

Every test carries the id of the rule case it proves, as a `Case` trait (for example `ACC-002/C1`). A test without a
case id, or with an id missing from `docs/rules/`, fails `spec-check` at review.

## What it reads and writes

- Reads the Canvas acceptance cases and `docs/rules/<table>.md`.
- Writes the test project's test classes.

## What it never does

- Write tests after the code, or claim success from a build or a partial run.
- Change or delete an existing test whose rule the story does not change. A failing regression test means the code
  is wrong.
- Encode a known harness difference from Dataverse in a test. See [Limitations](../../reference/limitations.md).

Source: [`skills/vela-plugin-testing/SKILL.md`](https://github.com/allandecastro/vela-agentic/blob/v0.6.0/skills/vela-plugin-testing/SKILL.md).
