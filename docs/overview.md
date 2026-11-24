---
_description: "What Vela Agentic is, what it does, and what it never does"
---

# Overview

This page explains what Vela Agentic is, how it relates to Vela, and the limits it keeps. Read it before you
install the pack or hand a story to an agent.

## What it is

Vela Agentic is a pack of 11 [Agent Skills](https://agentskills.io) and two agents for AI coding assistants. One
source serves Claude Code and GitHub Copilot. A skill is a `SKILL.md` file the assistant loads when a task matches
its description. An agent is a role with its own instructions and tools.

- **Skills** teach one step each: planning, scaffolding, models, tests, implementation, review, preview and
  debugging. See [Skills](skills/index.md).
- **[vela-builder](vela-builder.md)** drives a user story through the whole loop.
- **[vela-reviewer](vela-reviewer.md)** reviews the change with a fresh context and read-only tools.
- **[The deploy guard](hooks.md)** is an optional hook, run by the host, that blocks `vela apply` without approval.

## What it does

From a user story, the assistant:

1. Plans the change and pressure-tests the plan, and asks the human only what is theirs to decide.
2. Writes the acceptance cases as business rules, then failing tests for them.
3. Implements the plugin until the tests pass, with no analyzer violation.
4. Has the change reviewed by `vela-reviewer`.
5. Packages the plugin and previews the deployment with `vela plan`.
6. Stops at the deploy gate with a Build Report that holds the evidence and the exact `vela apply` command.

Each claim needs its evidence: the build summary, the test runner's summary line, the review findings, the
`vela plan` output and exit code. The [build loop](build-loop.md) describes each step.

## How it uses Vela

The pack drives Vela only through the public `vela` CLI. It confirms flags with `vela <command> --help` at run
time and does not call Vela's internal APIs or the Dataverse Web API around the CLI. For what each command does,
see [The vela CLI](../guides/cli-overview.md).

A gap in Vela is reported to Vela, not worked around in the skills.

## What it never does

- Run `vela apply` or pass `--auto-approve` unless a human authorized it for that run.
- Treat "ship it", an approved review or a merged pull request as approval to write to an org.
- Edit generated files, such as the models under `Models/Generated/`.
- Change the business rules in `docs/rules/` during the build. A failing regression test means the code is wrong.
- Guess a solution name, a publisher prefix or a security role. It reads them or asks.
- Add AI attribution to commits or pull requests.

## Status

The pack is in preview and developed alongside Vela. Releases are tagged `vX.Y.0`, one per section of the
[roadmap](https://github.com/allandecastro/vela-agentic/blob/v0.6.0/ROADMAP.md). The Vela version a release is
verified against is recorded in
[`references/cli-surface.md`](https://github.com/allandecastro/vela-agentic/blob/v0.6.0/references/cli-surface.md).
