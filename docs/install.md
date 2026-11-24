---
_description: "Install the pack in Claude Code or GitHub Copilot CLI, and the tools it needs"
---

# Install

This page explains how to install Vela Agentic in Claude Code or GitHub Copilot CLI, or the skills alone in another
host, and what must be on the machine before a run. It is for the developer who sets up the assistant.

## Prerequisites

| Need | Why | How |
| --- | --- | --- |
| The `vela` CLI | Every step goes through it. | `dotnet tool install --global Vela.Cli`. See [Install Vela](../getting-started/install.md). |
| The .NET SDK the CLI needs | Builds, tests and the review's `spec-check` script. | The version is in [`references/cli-surface.md`](https://github.com/allandecastro/vela-agentic/blob/v0.6.0/references/cli-surface.md). |
| A test runner | Tests run before any deploy. | `dotnet test` on Windows; Mono and the xUnit console runner on macOS and Linux. See [Testing](../guides/testing.md). |
| A Dataverse development environment | `vela models`, `vela solution show` and `vela plan` read it. | An unmanaged solution and its publisher must exist. Vela does not create them. |
| `git`, and the GitHub CLI `gh` | The agent commits each step and opens a draft pull request. | Signed in to the repository the project lives in. |

The Vela versions a release of the pack is verified against are in its
[`references/cli-surface.md`](https://github.com/allandecastro/vela-agentic/blob/v0.6.0/references/cli-surface.md). At session start the
optional [hook](hooks.md) compares the installed CLI with that version. An older CLI: run `vela update`.

### Connect without a browser

An agent often runs without a screen, so `vela ... -i` (browser sign-in) only works with a human at the machine.
For a headless run, use `--url` with an `az login` session or a managed identity, a connection string, or a client
secret read from the environment. See [Authentication](../configuration/authentication.md). Never put a secret on a
command line.

## Claude Code

```text
/plugin marketplace add allandecastro/vela-agentic
/plugin install vela
```

The plugin loads the skills, the two agents and the [deploy guard](hooks.md).

## GitHub Copilot CLI

```bash
copilot plugin marketplace add allandecastro/vela-agentic
copilot plugin install vela@vela-agentic
copilot plugin list
```

The last command shows what loaded. The deploy guard needs a one-time check on Copilot: ask the agent to run
`vela apply -p x.nupkg` and confirm the hook blocks it. See [The deploy guard](hooks.md).

> [!NOTE]
> VS Code Copilot Chat has no hooks. There, the skills still stop before `vela apply`, but no hook enforces it.

## Skills only, in any host

A host that reads the [Agent Skills](https://agentskills.io) format can install the skills alone:

```bash
gh skill preview allandecastro/vela-agentic
gh skill install allandecastro/vela-agentic
```

Each skill carries a copy of the references it cites, so it works once installed. The agents and the hook are not
part of a skills-only install.

## First run

Give `vela-builder` a user story, for example:

```text
When an account is created, default its description to "New customer".
```

The agent plans, scaffolds, tests, implements, reviews and previews the change, then stops at the deploy gate with
a Build Report and the `vela apply` command for you to run. See [The build loop](build-loop.md).

## Update

The plugin publishes a patch on every change to the pack. Update it with your host's plugin update command, and
keep the CLI current with `vela update`.
