---
_description: "The vela-scaffold skill: creates a solution with vela init and components with vela add"
---

# vela-scaffold

This page describes `vela-scaffold`, the skill that creates a Vela solution or adds a component to one. It is for
developers who want to know what the agent generates and which choices it passes to the CLI.

## When it triggers

When a new Vela solution is needed, or a plugin, step, Custom API, service or test must be added to an existing one.

## What it does

1. Runs `vela version`.
2. Finds the target solution and publisher prefix: from `PROJECT.md` in an existing project, or with
   `vela solution show <uniquename> --json` (read-only) for a new one. An unknown solution is asked of the human.
3. For a new solution, runs `vela init` with `--prefix`, `--publisher-prefix` and `--solution`. It adds
   `--integrations` when the Canvas records an outbound call. See [Scaffold a solution](../../guides/scaffold.md).
4. Generates the models before the first plugin, through [vela-models](vela-models.md).
5. Decides reuse or new: `vela add plugin` for a new table, `vela add step` for another behaviour on a table that
   already has a plugin. See [Add a component](../../guides/add.md).
6. Passes the stage, mode, filtering columns and handler name the Canvas decided, then reads the generated
   registration against the Canvas.
7. Builds with `dotnet build -c Release` and reports the output.

```bash
vela add plugin AccountPlugin --entity Account --message Create --stage PreOperation --mode Sync \
  --filtering-attributes Name --handler OnDescriptionDefault --project src/Zava.Plugins/Zava.Plugins.csproj
```

## What it reads and writes

- Reads `PROJECT.md` and the Canvas.
- Writes the files `vela init` and `vela add` create. The scaffolded plugin file is the developer's to edit;
  generated files are not.

## What it never does

- Use `vela init --samples` or `--no-tests` for real work, or `--interactive`.
- Hand-create a plugin class, or hand-edit a generated file to make it compile.
- Guess a publisher prefix or pick the `Default` solution. With no human reachable it scaffolds with the placeholder
  `tbd`, recorded as an open question that blocks apply.
- Follow the `AGENTS.md` that `vela init` writes where it contradicts the pack.

Source: [`skills/vela-scaffold/SKILL.md`](https://github.com/allandecastro/vela-agentic/blob/v0.6.0/skills/vela-scaffold/SKILL.md).
