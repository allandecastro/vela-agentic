---
_description: "The vela-models skill: generates typed models from the org, checks them for drift, and generates role classes"
---

# vela-models

This page describes `vela-models`, the skill that generates the typed models a plugin uses. It is for developers who
need to know when the agent reads the org and where the models land.

## When it triggers

When a plugin needs a table or column that is not yet in the generated models, or when committed models must be
checked against the org.

## What it does

`vela models` connects to Dataverse and reads metadata only. The skill:

- Always passes a scope (`--entities`, `--solution`, `--custom-apis`, ...): the CLI refuses to generate every table.
- Generates into the Shared project with `--project src/<Prefix>.Shared/<Prefix>.Shared.csproj`.
- Generates the security roles a story depends on with `--roles`, using role names from the human.
- Checks drift with `--verify` (exit `5` means drift) before a preview that depends on roles.
- Probes whether a table exists before building a case on it, and reads the output text, not only the exit code.

```bash
vela models --entities account,contact --project src/Zava.Shared/Zava.Shared.csproj --overwrite --url https://<org>.crm.dynamics.com
```

Success is the "Generated N file(s)" line. See [Early-bound models](../../guides/models.md).

## Connection

The agent connects headless: `--url` with an `az login` session, a connection string or a client secret from the
environment. `-i` only with a human at a browser. Without an org, the only route is `--from-solution` with an
exported solution zip. A failed connection (exit `6`) is recorded with the command and the model step stops.

## What it never does

- Hand-write or hand-edit a model, including a "stand-in" when the org is unreachable.
- Generate into the Plugins project or the current directory.
- Guess a role name.

Source: [`skills/vela-models/SKILL.md`](https://github.com/allandecastro/vela-agentic/blob/v0.6.0/skills/vela-models/SKILL.md).
