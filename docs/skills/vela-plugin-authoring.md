---
_description: "The vela-plugin-authoring skill: implements the plugin logic until the failing tests pass"
---

# vela-plugin-authoring

This page describes `vela-plugin-authoring`, the skill that writes the plugin logic. It is for developers who
review the code an agent produced.

## When it triggers

After scaffolding, models and the failing tests exist. Not before: the tests must have been seen to fail first.

## What it does

It implements exactly the operations the Canvas lists, in the handler the scaffold created, until the tests pass.
The shape of the code is Vela's: see [Write a plugin](../../guides/plugins.md). The skill holds the agent to:

- **Generated models** for every table and column, no attribute-name strings.
- **The typed context:** read the target and the registered images; on PreOperation, change what is written by
  setting the target.
- **The step's user** for writes. Elevated access only when the Canvas records the decision. Secrets come from
  secure configuration, never code.
- **The registration as the guard:** the filtering columns and images in the registration, not loose checks in code.
  The registration must be legal for its message and stage.
- **Thin handlers:** logic worth sharing goes to a service (`vela add service`); a one-liner does not get one.
- **No recursion by depth checks:** a write that re-triggers the step is fixed in the design, not hidden.

## What it reads and writes

- Reads the Canvas and the generated models.
- Writes the scaffolded plugin file and services. Never the generated files.

## What it never does

- Add scope the Canvas does not hold.
- Hand-write a parallel plugin class or rename the generated handler.
- Leave a `VELA` analyzer warning in authored code. See [Analyzers and generators](../../reference/analyzers.md).

Source: [`skills/vela-plugin-authoring/SKILL.md`](https://github.com/allandecastro/vela-agentic/blob/v0.6.0/skills/vela-plugin-authoring/SKILL.md).
