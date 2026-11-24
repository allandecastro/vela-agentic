---
_description: "The vela-plan-review skill: challenges the plan, writes the rules and fills the Vela Canvas before any code"
---

# vela-plan-review

This page describes `vela-plan-review`, the skill that challenges the agent's own plan before any code is written.
It is for developers who read the Canvas it produces and answer its questions.

## When it triggers

Right after a user story has been interpreted, before scaffolding.

## What it does

It interrogates the plan until every branch is resolved, recorded as an assumption, or asked:

- **Is code the right tool?** Who may create, read, update or delete rows is a matter for security roles, not a
  plugin. Such a story gets no plugin: the role changes are recorded for the human. See
  [Security roles and privileges](https://learn.microsoft.com/power-platform/admin/security-roles-privileges).
- **The registration:** plugin step or Custom API; message, stage and mode; filtering columns and images;
  recursion; bulk messages; association.
- **The approach:** Sync or Async, reuse an existing plugin or add a new one, a service or not, an outbound call in
  the Integrations project.
- **Platform services:** localized messages, environment variables, cache, security context. See
  [Write a plugin](../../guides/plugins.md).
- **The acceptance cases:** written as Given / When / Then, including each edge and each pitfall that applies.

It then fills the [Vela Canvas](../build-loop.md), writes the story's rules in `docs/rules/` and commits both before
any code. The plan gate is advisory: the agent flags its assumptions and continues.

## What it reads and writes

- Reads `docs/rules/<table>.md` for each table involved, the ADRs in `docs/adr/` that touch the story, and
  `PROJECT.md` for the solution and publisher prefix.
- Writes the Canvas in `docs/features/<slug>/README.md`, the story's rules in `docs/rules/`, and a new ADR when the
  story raises an architecture decision no ADR covers.

## What it never does

- Overwrite a rule the story contradicts without asking whether the new rule replaces it.
- Decide a business question alone. With a human reachable, it is asked as its own numbered question
  ([vela-grill](vela-grill.md)). With none reachable, the agent stops after the Canvas with `status: blocked`.
- Add behaviour the story or the human did not ask for. A provided draft is material to reuse, not spec.

Source: [`skills/vela-plan-review/SKILL.md`](https://github.com/allandecastro/vela-agentic/blob/v0.6.0/skills/vela-plan-review/SKILL.md).
