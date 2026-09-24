# vela-agentic

The agentic layer for [Vela](https://github.com/allandecastro/vela): portable **Agent
Skills** and **agents** that let an AI assistant build, model, apply, and debug Vela
Dataverse plugins by driving the `vela` CLI.

Targets both **Claude Code** and **GitHub Copilot** from a single source of truth.

## How it is organised

```
skills/            Source of truth — portable Agent Skills (SKILL.md), used by Claude Code directly
agents/            Source of truth — agent / persona definitions
AGENTS.md          Source of truth — durable rules every agent follows

.claude-plugin/    Claude Code distribution: plugin marketplace + plugin manifest
.github/           GitHub Copilot distribution: skills, chat modes, instructions (GENERATED)
scripts/           sync-copilot.mjs regenerates .github/ from the source of truth
```

Edit `skills/`, `agents/`, and `AGENTS.md`. Then regenerate the Copilot surface:

```bash
node scripts/sync-copilot.mjs
```

The `.github/` tree is generated — do not edit it by hand.

## Using it with Claude Code

Add this repository as a plugin marketplace, then install the `vela` plugin:

```
/plugin marketplace add allandecastro/vela-agentic
/plugin install vela
```

## Using it with GitHub Copilot

The `.github/skills/`, `.github/chatmodes/`, and `.github/copilot-instructions.md`
files are discovered by Copilot. Copy them into a consuming repository, or reference
them from your Copilot configuration.

## Compatibility

Each skill declares a **minimum `vela` CLI version** in its `SKILL.md`. The skills
target the CLI's public command surface — the stable, versioned contract — and discover
exact flags at runtime via `vela --help`. See `ROADMAP.md` for the compatibility policy.

## Licence

MIT — see [LICENSE](LICENSE).
