---
_description: "Vela Agentic: Agent Skills and agents that build Dataverse plugins with the vela CLI and stop before deploying"
---

# AI agents

This section documents Vela Agentic, the pack of Agent Skills and agents that lets an AI coding assistant build
Dataverse plugins with Vela. It is for developers who want Claude Code or GitHub Copilot to take a user story to a
tested, reviewed and previewed plugin, and for reviewers who read what such a run produces. It assumes you know
the basics of Vela: see [Install](../getting-started/install.md) and the [Quickstart](../getting-started/quickstart.md).

## What the pack does

The pack drives the `vela` CLI. From a user story, the assistant plans the change, writes failing tests, implements
the plugin, has it reviewed by a separate read-only agent, packages it and previews the deployment with `vela plan`.
It then stops and hands over a Build Report. A human runs `vela apply`.

> [!WARNING]
> The pack never writes to a Dataverse environment on its own. `vela plan`, `vela models`, `vela solution show`,
> `vela inspect` and `vela logs` only read the org. `vela apply` is a human step.

## Start here

- [Overview](overview.md): what the pack is, what it does and what it never does.
- [Install](install.md): the plugin for Claude Code and GitHub Copilot CLI, and the prerequisites.
- [The build loop](build-loop.md): the steps from a story to the deploy gate, the Vela Canvas and the Build Report.
- [Project files](project-files.md): the files the pack reads and writes in your project.
- [Skills](skills/index.md): one page per skill.
- [vela-builder](vela-builder.md) and [vela-reviewer](vela-reviewer.md): the two agents.
- [The deploy guard](hooks.md): the optional hook that blocks `vela apply` without approval.
- [How the pack is tested](testing-the-pack.md) and the [FAQ](faq.md).

## Versions and issues

These pages describe the pack at tag `v0.6.0`. The pack has its own release cadence, separate from Vela's; its
[changelog](https://github.com/allandecastro/vela-agentic/blob/v0.6.0/CHANGELOG.md) lists what each release
changed.

> [!NOTE]
> The "Report an issue" link in the footer opens an issue on Vela. Report a problem with the skills, the agents or
> these pages at [vela-agentic issues](https://github.com/allandecastro/vela-agentic/issues).
