---
_description: "The vela-reviewer agent: an isolated, read-only review of a plugin change on spec and standards"
---

# vela-reviewer

This page describes `vela-reviewer`, the agent that reviews a change before the apply gate. It is for developers
who want to know what the review checks and why it runs apart from the builder.

## What it does

The reviewer starts with a fresh context: it never sees the build's session history, so it does not share the
author's blind spots. It follows [vela-code-review](skills/vela-code-review.md) and reviews on two axes, separately:

- **Spec:** every Canvas case implemented and tested, the right message, stage and mode, the edges handled, no scope
  creep.
- **Standards:** the intent of the Vela analyzers, Dataverse pitfalls, registration legality, SOLID and DRY, and the
  Sync or Async fit. See [Analyzers and generators](../reference/analyzers.md).

It also reads the project's ADRs that the diff touches; code that contradicts one is a Required finding.

## What it is given

The diff, the Canvas, the RED and GREEN test output with the failing test names, the build's diagnostic lines, the
`spec-check` output and the run trace, pasted into its prompt. Missing evidence is a BLOCK with a Required finding
that names it. A re-review after a fix receives only the fix diff, the findings to close and the new test output.

## What it returns

Findings, most severe first, as `severity - file:line - what - why - suggested fix`, with severity Critical,
Required or Nit, then a verdict: **PASS** (no Critical or Required) or **BLOCK**. On PASS it lists the Canvas
decisions it checked. The builder saves the output verbatim in `.vela-runs/<slug>/review.md`.

## What it never does

It has read-only tools (`Read`, `Grep`, `Glob`, `Skill`): no shell, no edit, no build, no deploy. It does not fix
code or dispatch other agents, and it never reports an item the checklist labels Critical or Required at a lower
severity.

Source: [`agents/vela-reviewer.agent.md`](https://github.com/allandecastro/vela-agentic/blob/v0.6.0/agents/vela-reviewer.agent.md).
