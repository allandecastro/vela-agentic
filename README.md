# vela-agentic

The agentic layer for [Vela](https://github.com/allandecastro/vela): portable **Agent
Skills** and **agents** that let an AI assistant build, model, apply, and debug Vela
Dataverse plugins by driving the `vela` CLI.

Targets both **Claude Code** and **GitHub Copilot** from a single source of truth.

## How it is organised

```
skills/            Source of truth — portable Agent Skills (SKILL.md), used by Claude Code directly
  Model-invoked (auto):   using-vela, vela-plugin-authoring, vela-test-harness,
                          vela-plan-review, writing-vela-skills, diagnosing-vela,
                          vela-scaffold, vela-models, vela-apply, vela-debug-plugin
  User-invoked (/cmd):    vela-grill  (and the build loop / apply as commands)
agents/            Source of truth — vela-builder (the gated build loop)
references/        Verbatim, grounded knowledge: cli-surface, plugin-authoring-api,
                   harness-api, dataverse-gotchas, build-report-template
evals/             Loop engineering — pressure scenarios + protocol (TDD for the skills)
AGENTS.md          Source of truth — durable rules + the build loop

.claude-plugin/    Claude Code distribution: plugin marketplace + plugin manifest
.github/           GitHub Copilot distribution: skills, chat modes, instructions (GENERATED)
scripts/           sync-copilot.mjs regenerates .github/ from the source of truth
```

## The build loop

`vela-builder` takes a user story and drives it through: Intake → Plan → **Challenge**
(self-grill, advisory gate) → Scaffold → Model → Implement → Verify (build + harness +
`vela plan`) → **🚧 apply gate** (human approves) → Report. It emits a **Plan artifact** at the
front and a **Build Report** at the end (committed under `docs/vela-builds/` and used as the PR
body). The org is only ever touched at `vela apply`, which a human runs.

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
