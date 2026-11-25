<p align="center">
  <img src="branding/vela-chevron.svg" alt="Vela" width="120" height="120" />
</p>

<h1 align="center">Vela Agentic</h1>

<p align="center">
  <strong>Agent Skills and agents that turn a user story into a tested, reviewed Dataverse plugin,<br/>
  by driving the <a href="https://github.com/allandecastro/vela">Vela</a> CLI. Autonomous up to a human-approved deploy.</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/license-MIT-green?style=for-the-badge" alt="License: MIT" />
  <a href="https://github.com/allandecastro/vela-agentic/actions/workflows/ci.yml?query=branch%3Amain"><img src="https://github.com/allandecastro/vela-agentic/actions/workflows/ci.yml/badge.svg?branch=main" alt="CI" /></a>
  <a href="https://www.nuget.org/packages/Vela.Cli"><img src="https://img.shields.io/nuget/v/Vela.Cli?logo=nuget&label=Vela.Cli" alt="Vela.Cli on NuGet" /></a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Agent_Skills-SKILL.md-000000?style=for-the-badge" alt="Agent Skills" />
  <img src="https://img.shields.io/badge/Claude_Code-plugin-CC785C?style=for-the-badge" alt="Claude Code" />
  <img src="https://img.shields.io/badge/GitHub_Copilot-plugin-24292F?style=for-the-badge&logo=github&logoColor=white" alt="GitHub Copilot" />
  <img src="https://img.shields.io/badge/Microsoft_Dataverse-107C10?style=for-the-badge&logo=microsoft&logoColor=white" alt="Microsoft Dataverse" />
</p>

Vela Agentic is the AI layer of [Vela](https://github.com/allandecastro/vela): Agent Skills and two agents that drive
the `vela` CLI to build, test, review and preview Dataverse plugins, and stop before anything is written to an org.

> **Status** - Public preview, actively developed alongside Vela: until 1.0 a minor release may break
> compatibility. Releases are tagged `vX.Y.0`
> ([`RELEASING.md`](RELEASING.md)) and every merge to `main` publishes a patch; the Vela version the pack is
> verified against is recorded in [`references/cli-surface.md`](references/cli-surface.md).

## Documentation

The user documentation is the **AI agents** section of the Vela docs site:
[allandecastro.github.io/vela/agents](https://allandecastro.github.io/vela/agents/) (live once Vela publishes the
section from a pinned tag). Its source is [`docs/`](docs/): the build loop, the Vela Canvas and Build Report, one
page per skill and agent, the deploy guard, the project files the pack uses, how the pack is tested, and a FAQ.

For Vela itself, see the [Vela documentation](https://allandecastro.github.io/vela/) and
[`llms.txt`](https://allandecastro.github.io/vela/llms.txt) for agents. Changes are listed in
[`CHANGELOG.md`](CHANGELOG.md); plans and follow-ups are [issues](https://github.com/allandecastro/vela-agentic/issues).

## What it does

**Vela Agentic** is a pack of 11 [Agent Skills](https://agentskills.io) and two agents for AI coding
assistants (Claude Code and GitHub Copilot, from one source). From a user story, the assistant:

1. **Plans** the story and pressure-tests it, asking the human only what is theirs to decide.
2. **Writes failing tests first**, then the code that makes them pass.
3. **Reviews** the change with an isolated reviewer agent.
4. **Previews** the deployment with a read-only `vela plan`.
5. **Stops** and hands over a Build Report. A human runs the deploy.

Everything goes through the public `vela` CLI. The pack never reaches into Vela's internals and never
writes to an org on its own.

## Install

Prerequisites: the `vela` CLI (`dotnet tool install --global Vela.Cli`) and the .NET SDK it needs, a Dataverse
development environment for the steps that read the org, and a test runner (`dotnet test` on Windows; Mono and the
xUnit console runner on macOS and Linux). Details: [`docs/install.md`](docs/install.md).

Claude Code:

```text
/plugin marketplace add allandecastro/vela-agentic
/plugin install vela
```

GitHub Copilot CLI:

```bash
copilot plugin marketplace add allandecastro/vela-agentic
copilot plugin install vela@vela-agentic
```

Skills only, any host:

```bash
gh skill preview allandecastro/vela-agentic   # inspect first
gh skill install allandecastro/vela-agentic
```

Then give `vela-builder` a user story, for example: *When an account is created, default its description to "New
customer".* It stops at the deploy gate with a Build Report and the exact `vela apply` command for you to run.

## Skills

| Skill | What it does |
| --- | --- |
| `using-vela` | Entry point: the build loop and the rules every step follows |
| `vela-plan-review` | Pressure-tests the plan and fills the Vela Canvas |
| `vela-grill` | Interviews the human when a story is too ambiguous to build (also `/vela-grill`) |
| `vela-scaffold` | Creates a solution or component with `vela init` and `vela add` |
| `vela-models` | Generates typed models from the org, or checks them for drift |
| `vela-plugin-testing` | Writes the failing tests with `Vela.Testing` and runs them |
| `vela-plugin-authoring` | Implements the plugin until the tests pass |
| `vela-custom-api` | Designs, tests and implements a Custom API |
| `vela-code-review` | Reviews the change against the spec and the standards |
| `vela-apply` | Packages, signs if needed, previews with `vela plan`, stops at the deploy gate |
| `vela-debug-plugin` | Diagnoses a plugin that does not fire or misbehaves |

The agents: **`vela-builder`** drives a story through the whole loop; **`vela-reviewer`** is read-only and starts
with a fresh context.

## Contributing

1. Follow [`.claude/skills/pack-writing-skills/SKILL.md`](.claude/skills/pack-writing-skills/SKILL.md): a change to
   what an agent does ships with the eval that would have caught the problem. The maintainer skills
   (`pack-writing-skills`, `pack-diagnosing-runs`: a run turned into line-level findings against the skills)
   live in `.claude/skills/`, loaded when you work in this repo and never shipped with the pack.
2. Edit the sources (`skills/`, `agents/`, `references/`, `AGENTS.md`), then regenerate with
   `node scripts/sync-copilot.mjs`.
3. A change to what a user sees updates its page in [`docs/`](docs/) (and `docs/toc.yml` for a new page).
4. Run `sh scripts/check.sh` before pushing: lint, docs check, configs, shell syntax, guard tests, secret scan and
   generated files in sync. To run it on every push: `git config core.hooksPath .githooks`.

CI runs the same check, the `spec-check` tests and gitleaks on every pull request.

## Acknowledgments

Built for [Vela](https://github.com/allandecastro/vela). Skill format from the open
[Agent Skills](https://agentskills.io) standard (`SKILL.md`, `AGENTS.md`).

---

<p align="center">
  Crafted with ❤️ and AI by Allan De Castro
</p>

<p align="center">
  License: <a href="LICENSE">MIT</a>
</p>
