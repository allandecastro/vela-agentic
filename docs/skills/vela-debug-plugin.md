---
_description: "The vela-debug-plugin skill: reproduces a plugin fault as a failing test before any fix"
---

# vela-debug-plugin

This page describes `vela-debug-plugin`, the skill that diagnoses a plugin that misbehaves. It is for the person who
reports the fault and may be asked for evidence from the org.

## When it triggers

When a plugin does not fire, fires on the wrong message or table, throws, or produces unexpected results.

## What it does

It follows reproduce, minimize, hypothesize, instrument, fix, regression-test. No failing repro, no fix.

1. **Bug or change?** It finds the rule in `docs/rules/` the behaviour falls under. Code that breaks the rule is a
   bug. Code that follows it while the human wants otherwise is a change request, which goes back to design first.
2. **Runtime evidence.** With a connection it reads the trace itself with `vela logs` (read-only; `--jobs` for a
   failed async step). Without one it asks the human for the Plug-in Trace Log rows and says where to find them and
   which fields. See
   [Tracing and logging](https://learn.microsoft.com/power-apps/developer/data-platform/logging-tracing). No trace
   row at all, with tracing on, points at the registration rather than the handler.
3. **Reproduce locally** with a failing `PluginPipeline` test, which runs the registration, so filters, cascades
   and recursion reproduce. See [Testing](../../guides/testing.md).
4. **Hypothesize** from the registration and the evidence: a filter missing the changed column, a missing image, the
   wrong stage, an association scoped to another relationship.
5. **Commit** the Canvas and the repro tests first, then **fix** only the most likely cause in its own commit.
6. **Back to the loop:** review with [vela-code-review](vela-code-review.md), preview with
   [vela-apply](vela-apply.md), and stop at the gate.

## What it reads and writes

- Reads the registration code, `docs/rules/`, and with a connection `vela logs`, `vela inspect` and `vela plan`.
- Writes a small-story Canvas, the repro tests, the fix and the Build Report.

## What it never does

- Change the org while diagnosing, or call the Web API around the CLI.
- Change code before a failing repro exists, or fix more than the cause.
- Hide recursion with a depth check.
- Guess the solution name.

See also [Troubleshooting](../../guides/troubleshooting.md) for Vela's own errors.

Source: [`skills/vela-debug-plugin/SKILL.md`](https://github.com/allandecastro/vela-agentic/blob/v0.6.0/skills/vela-debug-plugin/SKILL.md).
